;All context switching functionality is here.

EXTERN sm$intTOS


swapTaskData:
;Saves the current tasks information and sets the task information for a 
; new task. Is called with interrupts turned off!
;Input: ecx = Task number to switch to.
;       dword [dCurTask], qword [pCurTask] -> Current task identifiers.
;Output: ecx set as current task.
;Must be called on a safe to use stack.
    mov ebp, ecx    ;Save the task number in ebp!

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
;-----------------------------------------------------------------
;-----------------NEW TASK IS SWAPPED TO BELOW-----------------
;-----------------------------------------------------------------
;Set the new task as the current active task
    mov dword [dCurTask], ebp  ;Store the task number
    mov ecx, ebp  
    call getPtdaPtr ;Get ptr in rdi to the current PTDA table
    mov rbx, rdi
    mov qword [pCurTask], rbx           ;Setup internal data properly!

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


taskSwitch:
;Called always with interrupts turned off!
    xchg qword [pCurTask], rbx  ;Get the ptr to the current session. Save rbx.
    mov qword [rbx + ptda.qRSP], rsp
    lea rsp, qword [rbx + ptda.boS] ;Point rsp to where to store regs
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

;Here we sleep the current task and choose the next task.
;If the task needed to be put to sleep for a period of time, then 
; we have already set the sleep information in the ptda before coming
; here.
    call chooseNextTask
    call swapTaskData

    mov rbx, qword [pCurTask]
    lea rsp, qword [rbx + ptda.sRegsTbl + 8]    ;Skip reloading the flags here!
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
    mov rsp, qword [rbx + ptda.qRSP]
    push qword [rbx + ptda.sRegsTbl]    ;Reload the flags once we have switched stacks!
    xchg qword [pCurTask], rbx  ;Now swap things back  
    popfq   ;Pop flags back right at the end :)
    return

chooseNextTask:
;Makes a choice of the next task. For now, its the next task,
; unless the SM has been signalled through the keyboard. Furthermore, 
; no task switch is enacted if we are in a critical section!
    return