;------------------------------------------------------------
;All the DOSMGR dispatcher functions live here.
;------------------------------------------------------------

EXTERN sm$intTOS
;------------------------------------------------------------
;Int 2Ah Dispatcher
;------------------------------------------------------------
i2FhDisp:
    cmp ah, SM_SIG_2F  ;Session manager
    jne .chain
    test al, al ;Install check?
    jnz .exit   ;Anything else is just a plain exit!
    mov al, -1  ;Indicate we are installed!
.exit:
    iretq
.chain:
    jmp qword [oldInt2Fh]   ;Chain to the next handler


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

    lea rsp, sm$intTOS  ;Get the top of interrupt stack
    cld     ;Ensure that rep writes are now the right way!
    mov ecx, SM_SESSION
    call swapSession
    jmp shellEntry  ;Goto the shell entry routine
    
gotoSession:
;Enter with ecx = new session number.
;This starts working on the shell's stack. That is ok.
    cli         ;Turn off interrupts again.
    lea rsp, sm$intTOS  ;Get the top of interrupt stack
    call swapSession

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
    xchg qword [pCurSess], rbx  ;Now swap things back  
    popfq   ;Pop flags back right at the end :)
    return

swapSession:
;Saves the current session information and sets the session information for a 
; new session. Is called with interrupts turned off!
;Input: ecx = Session number to switch to.
;       dword [dCurSess], qword [pCurSess] -> Current session identifiers.
;Output: ecx set as current session.
;Must be called on a safe to use stack.
    mov ebp, ecx    ;Save the session number in ebp!

    lea rdi, pCurSess
    mov rdi, qword [pCurSess]
    push rdi    ;Save the CurSess pointer for use later!
    lea rdi, qword [rdi + psda.sdaCopy] ;Point rdi to the sda space
    mov rsi, qword [pDosSda]
    mov ecx, dword [dSdaLen]
    rep movsb   ;Transfer over the SDA
    pop rdi
;Save the current Int 22h, 23h and 24h handlers in the paused sessions' PSDA.
    mov eax, 22h
    call getIntVector
    mov qword [rdi + psda.pInt22h], rbx
    mov eax, 23h
    call getIntVector
    mov qword [rdi + psda.pInt23h], rbx
    mov eax, 24h
    call getIntVector
    mov qword [rdi + psda.pInt24h], rbx
    mov eax, 2Eh
    call getIntVector
    mov qword [rdi + psda.pInt2Eh], rbx
;-----------------------------------------------------------------
;-----------------NEW SESSION IS SWAPPED TO BELOW-----------------
;-----------------------------------------------------------------
;Set the new session as the current active session
    mov dword [dCurSess], ebp  ;Store the session number
    mov ecx, ebp  
    call getPsdaPtr ;Get ptr in rdi to the current PSDA table
    mov rbx, rdi
    mov qword [pCurSess], rbx           ;Setup internal data properly!

;Set the SDA to the new session's SDA. 
    lea rsi, qword [rbx + psda.sdaCopy] ;Point rdi to the sda space
    mov rdi, qword [pDosSda]
    mov ecx, dword [dSdaLen]
    rep movsb   ;Transfer over the SDA

;Set the new sessions' DOS interrupt handlers.
    mov rdx, qword [rbx + psda.pInt2Eh]
    mov eax, 2Eh
    call setIntVector    
    mov rdx, qword [rbx + psda.pInt24h]
    mov eax, 24h
    call setIntVector
    mov rdx, qword [rbx + psda.pInt23h]
    mov eax, 23h
    call setIntVector
    mov rdx, qword [rbx + psda.pInt22h]
    mov eax, 22h
    call setIntVector 

;Now swap the screen to new sessions' screen!
    mov ebx, ebp        ;Put the session number in bl
    mov eax, 1          ;Swap screen command!
    call qword [pConIOCtl] ;Set the screen to the number in bl

    return

getIntVector:
;Called with:
;Interrupts Off!
; al = Interrupt number
;Returns: 
; rbx -> Ptr to interrupt handler
    sidt [pIDT]    ;Get the current IDT base pointer
    movzx eax, al
    shl rax, 4h     ;Multiply IDT entry number by 16 (Size of IDT entry)
    add rax, qword [pIDT.base]    
    xor ebx, ebx
    mov ebx, dword [rax + 8]    ;Get bits 63...32
    shl rbx, 10h    ;Push the high dword high
    mov bx, word [rax + 6]      ;Get bits 31...16
    shl rbx, 10h    ;Push word 2 into posiiton
    mov bx, word [rax]          ;Get bits 15...0
    return

setIntVector:
;Called with:
;Interrupts Off!
;   rdx = Pointer to interrupt handler
;   al = Interrupt number
    sidt [pIDT]    ;Get the current IDT base pointer
    movzx eax, al
    shl rax, 4h     ;Multiply IDT entry number by 16 (Size of IDT entry)
    add rax, qword [pIDT.base]    
    mov word [rax], dx  ;Get low word into offset 15...0
    shr rdx, 10h    ;Bring next word low
    mov word [rax + 6], dx  ;Get low word into offset 31...16
    shr rdx, 10h    ;Bring last dword low
    mov dword [rax + 8], edx
    return

getPsdaPtr:
;Input: ecx = Number of the psda to get the pointer of!
;Output: rdi -> PSDA requested
    mov rdi, qword [pPsdaTbl]
    test ecx, ecx   ;Pick off the case where session number is 0.
    retz
    push rax
    push rcx
    mov eax, dword [dPsdaLen]
    mul ecx 
    add rdi, rax
    pop rcx
    pop rax
    return