;This is the main Session Manager "interactive" shell.

shellEntry:
    cld     ;Ensure that rep writes are the right way!
    lea rsp, STACK_END  ;Set now to internal shell stack! 
;Safe as we are cannot reenter here :)
    mov ecx, SM_SESSION
    call swapSession
    sti     ;Now reenable interrupts! We are safe to do so! 
resetScreen:            ;Now reset the screen!
    mov eax, 2          ;Driver Reset screen command!
    call qword [pConIOCtl] 
    ;And fall through to the main print loop
shellMain:
;The shell main routine prints the number of sessions,
; the program names.
;Printing the screen header!
    lea rdx, ttlStr
    call puts
    lea rdx, sessStr
    call puts
    mov edx, dword [dMaxSesIndx]    ;This is also number of USER sessions
    inc edx     ;Add 1 to include the SM session
    add dl, "0" ;Convert to ASCII char
    call putch
    call putNewline
    lea rdx, uline
    call puts
    call putNewline
;Printing the sessions.
    mov dl, "0"
    call putch
    lea rdx, colonStr
    call puts
    lea rdx, sesManStr
    call puts
    call putNewline
;Now we print the name from each session's current PSP environment pointer.
    mov ecx, 1  ;Start from this session number
.printLp:
    mov edx, ecx
    add dl, "0" 
    call putch
    lea rdx, colonStr
    call puts
    lea rdx, waitStr    ;Now print the state of the session
    call puts
    ;Now get the string to print
    call getPsdaPtr ;Get the psda ptr in rdi
    mov rdx, qword [rdi + psda.sdaCopy + sda.currentPSP]    ;Get the PSPptr
    call getProcName    ;Get the process name ptr for process of PSP in rdx
    jnc .nameFound
    lea rdx, noNameStr
    call puts
    jmp short .nextSession
.nameFound:
    mov rdi, rdx    ;Copy the ptr here to get the len of the ASCIIZ string
    push rcx        ;Save the number of the psda we are at
    mov eax, 1212h
    int 2Fh
    ;ecx now has the string length + terminating null
    ;rdx points to the ASCIIZ string
    dec ecx     ;Drop the terminating null
    mov ebx, 1  ;STDOUT
    mov eax, 4000h
    int 21h
    pop rcx     ;Get back the psda number
.nextSession:
    call putNewline
    inc ecx
    cmp dword [dMaxSesIndx], ecx   ;Keep going until dMaxSesIndx < ecx
    jae .printLp
;All printing done, now wait for input from user
    lea rdx, helpStr
    call puts
    lea rdx, promptStr
    call puts
    lea rdx, inStr
    mov word [rdx], 0002h   ;Init the buffered string
    mov eax, 0A00h  ;Await buffered input
    int 21h
    movzx ecx, byte [rdx + 2]
    cmp cl, "?"
    je resetScreen
    cmp cl, "1"
    jb badChoice
    cmp cl, "9"
    ja badChoice
    sub cl, "0"
    cmp dword [dMaxSesIndx], ecx
    jb badChoice
;Now we get ready to leave...
prepLaunch:
;Entered with cl (ecx) containing the new (valid) session number
    call swapSession
    jmp gotoSession 

badChoice:
;Beep at the user and then reset the screen, show display!
    mov dl, 07h ;Beep at the user (Do I want to do that?)
    call putch
    jmp resetScreen

;Shell handy routines
getProcName:
;Input: rdx -> PSP pointer to find the task name for!
;Output: CF=NC: rdx -> Points to ASCIIZ process name
;        CF=CY: rdx = 0, Process name not found
;
;Here we search for the double 00 and then check if it is 0001 and
; pass the ptr to the word after.
    mov rdx, qword [rdx + psp.envPtr]   ;Get the environement pointer
    cli
    push rcx
    xor ecx, ecx
    mov ecx, 7FFFh  ;Max environment size
.gep0:
    cmp word [rdx], 0   ;Zero word?
    je short .gep1
    inc rdx         ;Go to the next byte
    dec ecx
    jnz short .gep0
.gep00:
    ;Failure here if we haven't hit the double null by the end of 32Kb
    pop rcx
    xor edx, edx    ;Turn it into null pointer
    stc     ;Set CF
    jmp short .exit ;Exit reenabling the interrupts!
.gep1:
    add rdx, 2  ;Skip the double null
    cmp word [rdx], 1   ;Check if one more string in environment
    jne .gep00
    add rdx, 2  ;Skip the 0001 word. Should always clear CF
    pop rcx
    clc     ;Clear CF
.exit:
    sti
    return

swapSession:
;Saves the current session information and sets the session information for a 
; new session. Is called with interrupts turned off!
;Input: ecx = Session number to switch to.
;       dword [dCurSess], qword [pCurSess] -> Current session identifiers.
;Output: ecx set as current session.
;Must be called on a safe to use stack.
    mov ebp, ecx    ;Save the session number in ebp!

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

putch:
    mov eax, 0200h
    int 21h
    return
puts:
    mov eax, 0900h
    int 21h
    return
putNewline:
    lea rdx, newlineStr
    jmp puts
