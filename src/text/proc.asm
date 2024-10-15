;Process and thread management routines live here

doSleepMgmt:
;Decrements the sleep counter for each sleeping ptda on the sleep list
; and removes entries from the list if they have finished their sleep.
    push rdi
    push rsi
    xor esi, esi    ;Zero the "previous" pointer
    mov rdi, qword [pHdSlpList]
.lp:
    test rdi, rdi
    jz .exit
    cmp dword [rdi + ptda.dSleepLen], 0      ;A never awaken task?
    je .gotoNext
    dec dword [rdi + ptda.dSleepLen]
    jnz .gotoNext
;Start by awakening the task.
    and word [rdi + ptda.wFlags], ~(THREAD_SLEEP | THREAD_LIGHT_SLEEP)
    or word [rdi + ptda.wFlags], THREAD_ALIVE
;Now set that this task is being awoken due to timeout wakeup
    mov dword [rdi + ptda.dAwakeCode], AWAKE_TIMEOUT
    call remFromSleepList   ;Remove ptda in rdi from sleep list
    jmp short .lp
.gotoNext:
    mov rsi, rdi    ;Make the current ptda the anchor
    mov rdi, qword [rdi + ptda.pNSlepPtda]    ;Get the next ptda
    jmp short .lp
.exit:
    pop rsi
    pop rdi
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
    mov rdi, qword [pCurPtda]
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
    mov rsi, qword [pHdSlpList]   ;Get the old head of the list
    mov qword [pHdSlpList], rdi   ;Place us at the head of the list
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
    push rsi
    push rdi
    pushfq
    cli     ;No int when doing this (figure something better)
    xor eax, eax    ;Zero our counter of awoken tasks
    xor esi, esi    ;Zero the "previous" pointer
    mov rdi, qword [pHdSlpList]
.lp:
    test rdi, rdi
    jz .exit
    cmp qword [rdi + ptda.qEventId], rbx
    jne .gotoNext
;Awaken this task normally.
    and word [rbp + ptda.wFlags], ~(THREAD_SLEEP | THREAD_LIGHT_SLEEP)
    or word [rbp + ptda.wFlags], THREAD_ALIVE
    mov dword [rbp + ptda.dAwakeCode], AWAKE_NORMAL
    inc eax     ;Increment the counter
    call remFromSleepList   ;Remove ptda in rdi from sleep list
    jmp short .lp
.gotoNext:
    mov rsi, rdi    ;Now make current ptda the prevptr
    mov rdi, qword [rdi + ptda.pNSlepPtda]    ;Get the next ptda
    jmp short .lp
.exit:
    popfq
    pop rdi
    pop rsi
    test eax, eax   ;Set ZF if appropriate
    return

remFromSleepList:
;Removes the ptda in rdi out of the sleep list!
;Input: rdi -> ptda to be removed from sleeplist
;       rsi -> 0 if head of the sleeplist or previous ptda in list
;Now take the ptda out of the sleep list.
    push rdx
    xor edx, edx    ;Set rdx to the nullptr
    xchg rdx, qword [rdi + ptda.pNSlepPtda] ;and swap nullptr with nextptr
    mov rdi, rdx    ;Get the nextptr in rdi
    pop rdx
    test rsi, rsi   ;Are we replacing the first ptda in the list?
    jnz .noHead
    mov qword [pHdSlpList], rdi ;If so, put the link into the head
    return
.noHead:
;Else store nextptr in prevptda nexptr
    mov qword [rsi + ptda.pNSlepPtda], rdi
    return

fatalHalt:
;This is the handler if a fatal error occurs where we need to halt the 
; machine. We call DOS as we don't need to preserve anything since we 
; freeze the machine. 
;Input: rdx -> String to print.
    push rdx
    lea rdx, fatalStr
    call .outStr
    pop rdx
    call .outStr
    lea rdx, sysHltStr
    call .outStr
;
;Here provide a regdump of the system registers (and possibly stack?). 
;
    cli
.deadLp:
    jmp short .deadLp
.outStr:
    mov eax, 0900h
    int 21h
    return