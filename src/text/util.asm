;Misc utility functions go here

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


getPcbPtr:
;Input: ecx = Number of the pcb to get the pointer of!
;Output: rdi -> PCB requested
    mov rdi, qword [pPcbTbl]
    test ecx, ecx   ;Pick off the case where session number is 0.
    retz
    push rax
    push rcx
    mov eax, dword [dPcbLen]
    mul ecx 
    add rdi, rax
    pop rcx
    pop rax
    return

getThreadPtr:
;Input: rdi -> PCB to get the thread pointer to
;Output: rbp -> Primary (foreground) ptda of the process
    lea rbp, qword [rdi + pcb.sPtda]
    return

getSchedHeadPtr:
;Gets a pointer to your desired schedule.
;Input: al = Number of the schedule you desire (0-31)
    push rax
    push rbx
    mov ebx, 31
    sub ebx, eax    ;Get the reverse order schedule number in ebx
    mov eax, schedHead_size
    mul ebx 
    lea rsi, scheduleLists
    add rsi, rax
    pop rbx
    pop rax
    return 

getScheduleLock:
;Will attempt to get the lock for a schedule head. Will spin on it
; until it can get it. 
;Input: rsi -> Schedule head to obtain lock for.
    push rax
    push rbx
    xor ebx, ebx
    dec ebx     ;Make into -1
.lp:
    xor eax, eax    ;Set/Reset al to zero
    ;If var = al, move bl (-1) into the lock. Else mov var into al.
    lock cmpxchg byte [rsi + schedHead.bLock], bl
    jnz .lp     ;If the var was not 0, check again!
    pop rbx
    pop rax
    return


releaseScheduleLock:
    mov byte [rsi + schedHead.bLock], 0
    return