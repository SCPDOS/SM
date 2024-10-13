;Process and thread management routines live here

doSleepMgmt:
;Decrements the sleep counter for each sleeping ptda on the sleep list
; and removes entries from the list if they have finished their sleep.
    push rdi
    push rsi
    xor esi, esi    ;Zero the "previous" pointer
    mov rdi, qword [sleepPtr]
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
;Here take the ptda out of the sleep list.
    push rax
    mov rax, qword [rdi + ptda.pNSlepPtda]    ;Get the next PTDA ptr in rax
    test rsi, rsi   ;Are we replacing the first ptda in the list?
    jnz .noHead
    mov qword [sleepPtr], rax ;If so, put the link into the head
    mov rdi, rax    ;Move rdi to the new head of the list
    pop rax
    jmp short .lp   ;And go again!
.noHead:
    mov qword [rsi + ptda.pNSlepPtda], rax ;Else in the ptda
    pop rax
.gotoNext:
    mov rsi, rdi    ;Make the current ptda the anchor
    mov rdi, qword [rdi + ptda.pNSlepPtda]    ;Get the next ptda
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