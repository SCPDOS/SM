;All context switching functionality is here.

EXTERN sm$intTOS


awakenNewTask:
;Sets the DOS and DOSMGR state for the new task to run.
;Input: ecx = Task number (handle) to switch to.
;Output: ecx set as current task.


;Set the SDA to the new tasks' SDA. 
    lea rsi, qword [rbx + pcb.sdaCopy] ;Point rdi to the sda space
    mov rdi, qword [pDosSda]
    mov ecx, dword [dSdaLen]
    rep movsb   ;Transfer over the SDA

;Set the new tasks' DOS interrupt handlers.
    mov rdx, qword [rbx + pcb.pInt2Eh]
    mov eax, 2Eh
    call setIntVector    
    mov rdx, qword [rbx + pcb.pInt24h]
    mov eax, 24h
    call setIntVector
    mov rdx, qword [rbx + pcb.pInt23h]
    mov eax, 23h
    call setIntVector
    mov rdx, qword [rbx + pcb.pInt22h]
    mov eax, 22h
    call setIntVector 

;Now set the CON writing ok var if this task is on the same screen!
    mov byte [bScrnIoOk], 0 ;Denote output not ok
    mov rdi, qword [pCurPtda]    ;Get the thread ptr
    mov rdi, qword [rdi + ptda.pPcb]    ;Get ptr to the owner pcb.
    mov eax, dword [rdi + pcb.hScrnNum] ;Get the process screen number
    cmp byte [bCurScrNum], al
    retne
    dec byte [bScrnIoOk]    ;Denote output ok!
    return

sleepCurrentTask:
;Puts the current task on ice, saves all of its relevant state in 
; the pcb and then returns to the caller.
    mov rdi, qword [pCurPtda]
    push rdi    ;Save the CurTask pointer for use later!
    lea rdi, qword [rdi + pcb.sdaCopy] ;Point rdi to the sda space
    mov rsi, qword [pDosSda]
    mov ecx, dword [dSdaLen]
    rep movsb   ;Transfer over the SDA
    pop rdi
;Save the current Int 22h, 23h and 24h handlers in the paused tasks' PCB.
    mov eax, 22h
    call getIntVector
    mov qword [rdi + pcb.pInt22h], rbx
    mov eax, 23h
    call getIntVector
    mov qword [rdi + pcb.pInt23h], rbx
    mov eax, 24h
    call getIntVector
    mov qword [rdi + pcb.pInt24h], rbx
    mov eax, 2Eh
    call getIntVector
    mov qword [rdi + pcb.pInt2Eh], rbx
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
    mov rdi, qword [pCurPtda]
    mov eax, dword [drvLock + critLock.dCount]
    test eax, eax
    jz .noDrvLock   ;Not owned, proceed!
    cmp rdi, qword [drvLock + critLock.pOwnerPcb]
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
;rdi points to the current task.

;End by setting the new task and signalling procrun on this
    mov dword [hCurPtda], ecx  ;Store the task number 
    call getPcbPtr ;Get ptr in rdi to the current PCB table
    mov rbx, rdi
    mov qword [pCurPtda], rbx           ;Setup internal data properly!
    return


taskSwitch:
;Called always with interrupts turned off!
;If a task needed to be put to sleep for a period of time, then 
; we have already set the sleep information in the pcb before coming
; here.
    xchg qword [pCurPtda], rbx  ;Get the ptr to the current session. Save rbx.
    mov qword [rbx + pcb.sPtda + ptda.qRSP], rsp
    lea rsp, qword [rbx + pcb.sPtda + ptda.boS] ;Point rsp to where to store regs
    xchg qword [pCurPtda], rbx  ;Get back the value of rbx in rbx.
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

    mov rbx, qword [pCurPtda]
;Skip reloading the flags here!
    lea rsp, qword [rbx + pcb.sPtda + ptda.sRegsTbl + 8]
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
    xchg qword [pCurPtda], rbx
    mov rsp, qword [rbx + pcb.sPtda + ptda.qRSP]
;Reload the flags once we have switched stacks!
    push qword [rbx + pcb.sPtda + ptda.sRegsTbl]
    xchg qword [pCurPtda], rbx  ;Now swap things back  
    popfq   ;Pop flags back right at the end :)
    return