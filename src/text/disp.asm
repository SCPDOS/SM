;------------------------------------------------------------
;All the dispatcher functions live here.
;------------------------------------------------------------
;------------------------------------------------------------
;Default SM Int 22h Handler
;------------------------------------------------------------
;If this is ever executed, the session will enter a special 
; state where the user is prompted to type in the name of
; the program to launch in this session. 
;For now, it will simply try and relaunch a program.
;For for now, it will simply print a string and freeze.
;This will never happen as no COMMAND.COM can be exited
; with the defaults we have set up.
i22hHdlr:
    lea rdx, sesFrozStr
    mov eax, 0900h
    int 21h
.lp:
    jmp short .lp ;Enter an infinite loop

;------------------------------------------------------------
;Int 2Ah Dispatcher
;------------------------------------------------------------
i2AhDisp:
    cli ;Disable interrupts
    test ah, ah
    jz status
    cmp ah, 03h
    je ioblock
    cmp ah, 80h
    je critInc
    cmp ah, 81h
    je critDec
    cmp ah, 82h
    je critReset    ;We've been signalled to remove locks and is safe to do so!
    cmp ah, 84h
    je keybIntercept
interruptExit:  ;Used to overwrite Int 2Eh
    iretq

status:    ;AH=00h
    mov ah, -1
    iretq

ioblock:    ;AH=03h
;Need to check that Int 33h if disk device is not active. Temp wont do that for now!
;Else it is fine as we cannot swap in critical section and 
; all default BIOS char devices are reentrant.
;Input: rsi -> ASCIIZ string for device
    iretq

critInc:    ;AH=80h
    inc dword [sesLock + critLock.dCount]
    iretq

critDec:    ;AH=81h
;If lock is zero, exit as we would not have been deferred here.
;Else decrement the lock as it is safe to do so.
;   If lock not zero after decrement, exit.
;   Else
;       If deferred flag zero, exit.
;       Else handle deferred session swap.
    cmp dword [sesLock + critLock.dCount], 0
    jz .exit
    dec dword [sesLock + critLock.dCount]
    cmp dword [sesLock + critLock.dCount], 0
    jne .exit
    test byte [bDefFlg], -1 ;If we have a deferred call, process now!
    jz .exit
    mov byte [bDefFlg], 0   ;Clear the deferral flag and process call!
    call gotoShell
.exit:
    iretq

critReset:      ;AH=82h
    mov dword [sesLock + critLock.dCount], 0    ;Reset the value here :)
    iretq

keybIntercept:  ;AH=84h
;Do nothing as we don't need this endpoint for now!
    iretq

;------------------------------------------------------------
;Dos Session Help routines.
;------------------------------------------------------------
;Used by a corresponding CON driver to communicate events
; to the Session Manager.
DosSesHlp:
;Dispatcher for signals from MCON.
    cmp eax, 1
    je swapSes
    stc
    return
swapSes:
;We have been told that the magic key has been hit! Swap session unless we 
; are already in SM session.
;Entered with interrupts turned off.
    cmp dword [dCurSess], SM_SESSION    ;Don't swap session if in Session Manager.
    rete    
;We now check if we are in a lock. If we are in a lock, we defer the 
; swapping to SM until we leave all locks. 
    test dword [sesLock + critLock.dCount], -1  ;If the count is 0, proceed!
    jz gotoShell
    mov byte [bDefFlg], -1  ;Else, we set the deferred flag.
    return  ; and return to the busy session.

gotoShell:
;This routine swaps sessions to the Session Manager Shell.
;All registers are still preserved at this point except CF and ZF and CLI.
    xchg qword [pCurSess], rbx  ;Get the ptr to the current session. Save rbx.
    mov qword [rbx + psda.qRSP], rsp
    lea rsp, qword [rbx + psda.boS] ;Point rsp to where to store regs
    xchg qword [pCurSess], rbx  ;Get back the value of rbx in rbx.
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    pushfq  ;Save flags with CLI set. CLI persists on...
    jmp shellEntry  ;Goto the shell entry routine
    
gotoSession:
;We return here with interrupts deactivated again. popfq will restore flags
; with IF off.
;The only time this will not happen is on initial program load which is fine.
    mov rbx, qword [pCurSess]
    lea rsp, qword [rbx + psda.sRegsTbl + 8]    ;Skip reloading the flags here!
;We load the flags to their original state after we have switched back to the 
; application stack because we start applications with Interrupts on. Thus,
; if an interrupt occurs during the popping of the register stack, this 
; may corrupt data in the psda. Thus we only load rflags once we are on the
; application stack (which in the dangerous case, i.e. program init, is 
; always large enough to handle an interrupt... unless its a very full .COM file)!
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    xchg qword [pCurSess], rbx
    mov rsp, qword [rbx + psda.qRSP]
    push qword [rbx + psda.sRegsTbl]    ;Reload the flags once we have switched stacks!
    popfq
    xchg qword [pCurSess], rbx
    return
