;This is the main Session Manager "interactive" shell.

    EXTERN sm$shlTOS

shellEntry:
;This is the entry stub into the SM shell!
    lea rsp, sm$shlTOS  ;Set now to internal shell stack! 
    sti     ;Now reenable interrupts! We are safe to do so! 
;And fall through to the main print loop
shellMain:
;The shell main routine prints the number of sessions,
; the program names.
    call resetScreen
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
    call getPtdaPtr ;Get the ptda ptr in rdi
    mov rdx, qword [rdi + ptda.sdaCopy + sda.currentPSP]    ;Get the PSPptr
    call getProcName    ;Get the process name ptr for process of PSP in rdx
    jnc .nameFound
    lea rdx, noNameStr
    call puts
    jmp short .nextSession
.nameFound:
    mov rdi, rdx    ;Copy the ptr here to get the len of the ASCIIZ string
    push rcx        ;Save the number of the ptda we are at
    mov eax, 1212h
    int 2Fh
    ;ecx now has the string length + terminating null
    ;rdx points to the ASCIIZ string
    dec ecx     ;Drop the terminating null
    mov ebx, 1  ;STDOUT
    mov eax, 4000h
    int 21h
    pop rcx     ;Get back the ptda number
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
    je shellMain
    cmp cl, "1"
    jb badChoice
    cmp cl, "9"
    ja badChoice
    sub cl, "0"
    cmp dword [dMaxSesIndx], ecx
    jb badChoice
;
; TMP TMP TMP TMP TMP TMP TMP TMP TMP
;
    jmp short $ - 2 
;
; TMP TMP TMP TMP TMP TMP TMP TMP TMP
;

badChoice:
;Beep at the user and then reset the screen, show display!
    mov dl, 07h ;Beep at the user (Do I want to do that?)
    call putch
    jmp shellMain
resetScreen:            ;Now reset the screen!
    mov eax, 2          ;Driver Reset screen command!
    call qword [pConIOCtl]
    return 

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

i22hShell:
;Simply reset the screen and print the info again!
    jmp shellMain

i23hHdlr:
;Default i23 handler, relaunch the shell.
;Not doing so will reenter the call on a newline...
    stc
    ret 8
i24hHdlr:
    mov al, 3   ;Always FAIL
interruptExit:  ;Used to overwrite Int 2Eh
    iretq


swapConSession:
;Signals via DOS IOCTL to the multitasking console to enact the 
; task switch!
    return
;    mov rdi, qword [pCurTask]
;    mov ebx, dword [rdi + ptda.hScrnNum]   ;Put the screen number in bl
;    mov eax, 1          ;Swap screen command!
;    call qword [pConIOCtl] ;Set the screen to the number in bl
;    return