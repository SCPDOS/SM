;All context switching functionality is here.

EXTERN sm$intTOS


awakenNewTask:
;Sets the DOS and DOSMGR state for the new task to run.
;Input: ecx = Task number (handle) to switch to.
;Output: ecx set as current task.


;Set the SDA to the new tasks' SDA. 
    lea rsi, qword [rbx + ptda.sdaCopy] ;Point rdi to the sda space
    mov rdi, qword [pDosSda]
    mov ecx, dword [dSdaLen]
    rep movsb   ;Transfer over the SDA

;Set the new tasks' DOS interrupt handlers.
    mov rdx, qword [rbx + ptda.pInt2Eh]
    mov eax, 2Eh
    call setIntVector    
    mov rdx, qword [rbx + ptda.pInt24h]
    mov eax, 24h
    call setIntVector
    mov rdx, qword [rbx + ptda.pInt23h]
    mov eax, 23h
    call setIntVector
    mov rdx, qword [rbx + ptda.pInt22h]
    mov eax, 22h
    call setIntVector 
    return

sleepCurrentTask:
;Puts the current task on ice, saves all of its relevant state in 
; the PDTA and then returns to the caller.
    mov rdi, qword [pCurTask]
    push rdi    ;Save the CurTask pointer for use later!
    lea rdi, qword [rdi + ptda.sdaCopy] ;Point rdi to the sda space
    mov rsi, qword [pDosSda]
    mov ecx, dword [dSdaLen]
    rep movsb   ;Transfer over the SDA
    pop rdi
;Save the current Int 22h, 23h and 24h handlers in the paused tasks' PTDA.
    mov eax, 22h
    call getIntVector
    mov qword [rdi + ptda.pInt22h], rbx
    mov eax, 23h
    call getIntVector
    mov qword [rdi + ptda.pInt23h], rbx
    mov eax, 24h
    call getIntVector
    mov qword [rdi + ptda.pInt24h], rbx
    mov eax, 2Eh
    call getIntVector
    mov qword [rdi + ptda.pInt2Eh], rbx
    return

chooseNextTask:
;Makes a choice of the next task. For now, its the next task,
; unless the SM has been signalled through the keyboard. Furthermore, 
; no task switch is enacted if we are in a critical section!

;NOTE!! A task that owns a driver critical section (02h) MUST NOT be 
; interrupted. This is because the driver expects to have full control
; over the hardware and will not be happy if someone else tries to 
; do something whilst waiting for a new timeslice. A driver 
; can communicate that it is interruptable by setting the new multitasking
; bit in the header. Then Int 2Ah will no allocate the lock to it.
;A task that owns a DOS critical section (01h) can be interrupted.

;Start by checking that we don't own the uninterruptable lock. If
; we do, exit! We should never be in a situation where it is allocated 
; and we don't own it here.
    mov rdi, qword [pCurTask]
    mov eax, dword [drvLock + critLock.dCount]
    test eax, eax
    jz .noDrvLock   ;Not owned, proceed!
    cmp rdi, qword [drvLock + critLock.pOwnerPdta]
    rete    ;Return if they are equal!
    lea rdx, badLockStr
    jmp fatalHalt
.noDrvLock:
    return   ;TMPTMP: Keep current task!
;Now we know we don't own the uninterruptable lock, we choose a task
; to swap to. Check if the Screen Manager has told us what to swap to.
; If it hasn't, we check if the task screen is the same as the current 
; screen. If it isnt, swap to the task on that screen. Else, swap
; to the next task that isn't asleep. If all tasks are asleep then 
; pick the next task and wait on it.

;End by setting the new task and signalling procrun on this
    mov dword [dCurTask], ecx  ;Store the task number 
    call getPtdaPtr ;Get ptr in rdi to the current PTDA table
    mov rbx, rdi
    mov qword [pCurTask], rbx           ;Setup internal data properly!
    return


taskSwitch:
;Called always with interrupts turned off!
;If a task needed to be put to sleep for a period of time, then 
; we have already set the sleep information in the ptda before coming
; here.
    xchg qword [pCurTask], rbx  ;Get the ptr to the current session. Save rbx.
    mov qword [rbx + ptda.sTcb + tcb.qRSP], rsp
    lea rsp, qword [rbx + ptda.sTcb + tcb.boS] ;Point rsp to where to store regs
    xchg qword [pCurTask], rbx  ;Get back the value of rbx in rbx.
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
    pushfq
    cld ;Ensure all writes occur in the right way.
    lea rsp, sm$intTOS  ;Now go to the interrupt stack

    call sleepCurrentTask
    call chooseNextTask     ;Sets the task variables for the new task
    call awakenNewTask

    mov rbx, qword [pCurTask]
;Skip reloading the flags here!
    lea rsp, qword [rbx + ptda.sTcb + tcb.sRegsTbl + 8]
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
    xchg qword [pCurTask], rbx
    mov rsp, qword [rbx + ptda.sTcb + tcb.qRSP]
;Reload the flags once we have switched stacks!
    push qword [rbx + ptda.sTcb + tcb.sRegsTbl]
    xchg qword [pCurTask], rbx  ;Now swap things back  
    popfq   ;Pop flags back right at the end :)
    return

doSleepMgmt:
;Decrements the sleep counter for each sleeping tcb on the sleep list
; and removes entries from the list if they have finished their sleep.
    push rdi
    push rsi
    xor esi, esi    ;Zero the pointer
    mov rdi, qword [sleepPtr]
.lp:
    test rdi, rdi
    jz .exit
    cmp dword [rdi + tcb.dSleepLen], 0      ;A never awaken task?
    je .gotoNext
    dec dword [rdi + tcb.dSleepLen]
    jnz .gotoNext
;Here take the tcb out of the sleep list
    push rax
    mov rax, qword [rdi + tcb.pNSlepTcb]
    test rsi, rsi   ;Is rdi the first tcb in the list?
    jnz .noHead
    mov qword [sleepPtr], rax ;If so, put the link into the head
    mov rdi, rax
    pop rax
    jmp short .lp
.noHead:
    mov qword [rsi + tcb.pNSlepTcb], rax ;Else in the tcb
    pop rax
.gotoNext:
    mov rsi, rdi    ;Make the current tcb the anchor
    mov rdi, qword [rdi + tcb.pNSlepTcb]    ;Get the next tcb
    jmp short .lp
.exit:
    pop rsi
    pop rdi
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