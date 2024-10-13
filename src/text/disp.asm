;------------------------------------------------------------
;All the DOSMGR dispatcher functions live here.
;------------------------------------------------------------


;------------------------------------------------------------
;               DevHelp routines.
;------------------------------------------------------------
;Used by multitasking drivers to communicate events to DOS.
devHlp:
;Dispatcher for devHlp.
;Function number passed in edx
    cmp edx, DevHlp_ConsInputFilter
    je consInputFilter  
    cmp edx, DevHlp_Signal_SM
    je swapSes      
    cmp edx, DevHlp_ProcBlock
    je procBlock    
    cmp edx, DevHlp_ProcRun
    je procRun      
    cmp edx, DevHlp_GetDOSVar
    je getDosVar    
    stc
    return
getDosVar:
;Currently only recognise one var, eax = 0, ebx = any, ecx = 1
;Returns the pointer to the var/array in rax
    test eax, eax
    jz .getScrnIo
.exitBad:
    stc
    return
.getScrnIo:
    cmp ecx, 1  ;Is the var length one?
    jne .exitBad
    lea rax, bScrnIoOk  ;Else return the pointer (and CF=NC!)
    return
consInputFilter:
;Checks if the char is to be added to the internal buffer or not!
;Currently only checks for the magic code for SM invokation.
;Input: ax=SC/ASCII char pair
;Output: ZF=NZ: char pair should be added to the internal buffer
;        ZF=ZE: char pair should NOT be added to the internal buffer
    cmp ax, magicCode   ;If the magic char, do not add to internal buffer
    retne
    ;Here if the magic code was encounted.
    push rax
    xor eax, eax    ;Magic code requests a swap to screen zero!
    call swapSes
    pop rax
    return

swapSes:
;Entered with al = Suggested screen number. If bigger than maxsesindex, error!
    push rax
    movzx eax, al
    cmp dword [dMaxSesIndx], eax
    pop rax
    retb    ;Exit with Carry Set!
    pushfq
    cli 
    test byte [bSM_Req], -1 ;If its set, dont set again!
    jnz .exit
    mov byte [bSM_Req], -1  ;Set the bit
    mov byte [bSM_Req_Scr], al   ;Suggest swapping to screen zero!
.exit:
    popfq
    return

procBlock:
;Tells DOS to put this thread of execution for this task to sleep!
;Called with interrupts turned off.
;When called, use the following sequence:
; CLI
; while (condition)
;   prockBlock(eventId)
;Interrupts are turned off to prevent a race condition with procRun.
;
;Can only be called from a multitasking driver that declares itself so as
; these tasks don't enter the driver critical section.

;Talks about the current procedure only!
;On entry: Interrupts are off. rbx = Event identifier. ecx = Timeout interval.
;           If dh != 0, the sleep can be awakened prematurely.
;On exit: Interrupts are on.
;   eax = Awake code.
;   CF=NC -> Event wakeup (i.e. procrun called on event id)
;   CF=CY -> Unusual wakeup,
;       ZF=ZE -> Timeout wakeup
;       ZF=NZ -> Someone (probably scheduler) woke up this task prematurely
    push rsi
    push rdi
    mov rdi, qword [pCurThread]
;Start by indicating that the thread can go to sleep.
    or word [rdi + ptda.wFlags], THREAD_SLEEP
    and word [rdi + ptda.wFlags], ~THREAD_ALIVE
    test dh, dh
    jz .noInt
    or word [rdi + ptda.wFlags], THREAD_LIGHT_SLEEP
.noInt:
;Now set the event id and the length for the sleep 
    mov qword [rdi + ptda.qEventId], rbx
    mov dword [rdi + ptda.dSleepLen], ecx
    mov rsi, qword [sleepPtr]   ;Get the old head of the list
    mov qword [sleepPtr], rdi   ;Place us at the head of the list
    mov qword [rdi + ptda.pNSlepPtda], rsi    ;Make the old head the next second
    call taskSwitch             ;And now we swap tasks!
    mov eax, dword [rdi + ptda.dAwakeCode] 
    test eax, eax
    jz .exit
    cmp eax, AWAKE_TIMEOUT  ;Set zero flag if we were awoken due to timeout
    stc
.exit:
    sti
    pop rdi
    pop rsi
    return

procRun:
;We go through each queue and find every single thread block.
;On entry:  rbx = Event id to awaken tasks on.
;On exit:   eax = Count of processes woken up. If zero, ZF=ZE.
    push rdi
    mov 
    pop rdi
    return