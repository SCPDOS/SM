    EXTERN bseg_start
    EXTERN bseg_len
    GLOBAL ep

;Init code for Session Manager.
ep:  ;Entry Point for SM
    mov eax, 3000h  ;Get version number
    int 21h
    cmp al, 1   ;If the major number is 1 or below
    jbe proceedBss
    lea rdx, bvStr
exitBad:
;Bad exits in init jump here
    mov eax, 0900h
    int 21h
    mov eax, 4CFFh
    int 21h
proceedBss:
;Clean the BSS
    lea rdi, bseg_start
    mov ecx, bseg_len
    xor eax, eax
    rep stosb
;Check that STDIO is not redirected from the standard console device.
;This can be an AUX driver, the test for MCON compliance occurs below!
;If it is, exit complaining!
    xor ebx, ebx    ;STDIN
    mov eax, 4400h  ;Get Hdl info
    int 21h
    mov ebx, edx    ;Save the returned word in bx
    lea rdx, noIOCTLStr
    jc exitBad
    lea rdx, noStdinStr
    and ebx, 81h    ;Save bits 7 and 0 (Char dev and STDIN device)
    cmp ebx, 81h
    jne exitBad

    mov ebx, 1      ;STDOUT
    mov eax, 4400h  ;Get Hdl info
    int 21h
    mov ebx, edx    ;Save the returned word in bx
    lea rdx, noIOCTLStr
    jc exitBad
    lea rdx, noStdoutStr
    and ebx, 82h    ;Save bits 7 and 1 (Char dev and STDOUT device)
    cmp ebx, 82h
    jne exitBad
;XCHG ptrs with MCON, driver specific IOCTL call
    xor esi, esi
    xor edi, edi
    push rsi        ;Push two 0's onto the stack to allocate struc on stack
    push rsi
    mov rdx, rsp    ;Allocated structure on the stack
    mov word [rdx + mScrCap.wVer], 0100h
    mov word [rdx + mScrCap.wLen], mScrCap_size
    mov word [rdx + mScrCap.wMagic], magicCode
    lea rbx, DosSesHlp
    mov qword [rdx + mScrCap.qHlpPtr], rbx
    mov eax, 440Ch
    xor ebx, ebx    ;CON handle (STDIN)!
    mov ecx, 0310h  ;CON + Reports capacities!
    int 21h
    jnc mConOk
    lea rdx, noConStr
    jmp exitBad
mConOk:
    mov rbx, qword [rdx + mScrCap.qHlpPtr]
    mov qword [pConIOCtl], rbx ;Store the help pointer
    movzx ebx, byte [rdx + mScrCap.bScrNum]
    mov eax, 8      ;Maximum supported, 8 screens
    cmp ebx, eax
    cmova ebx, eax  ;Maximum supported session number is 7
    dec ebx         ;Turn into an index
    mov dword [dMaxSesIndx], ebx   ;Store the max session number index.
;Restore the stack now!
    pop rsi  
    pop rsi
    test ebx, ebx   ;If only one session possible, fail to start!
    jnz screensOk    ;Else, we know we have enough screens to proceed usefully!
;If not enough screens, indicate we are aborting!
    lea rdx, noScreenStr
    jmp exitBad
screensOk:
;Get the size of the SDA to know how big a psda actually is.
;    breakpoint
    mov eax, 5D06h
    int 21h
    mov qword [pDosSda], rsi
    mov dword [dSdaLen], ecx    ;Save the larger value :)
    add ecx, psda_size
    mov dword [dPsdaLen], ecx   ;Save the max length of a psda.
    mov eax, ecx
    inc ebx     ;Add 1 to get number of sessions 
    mul ebx     ;Multiply number of sessions by the size of psda
    add eax, 0Fh
    shr eax, 4  ;Round result up by a paragraph, turn into number of paragraphs
    mov ebx, eax    ;Put number of paragraphs into ebx
    mov eax, 4800h
    int 21h
    jnc spaceOk
    lea rdx, noMemStr
exitMcon:
    mov eax, 3  ;Signal to uninstall ourselves from MCON
    call qword [pConIOCtl] ;Deinstall our help pointer from the MCON 
    jmp exitBad
spaceOk:
    push rax        ;Save the pointer to the allocated block!
    mov rdi, rax    ;Clear the space we just allocated!
    shl ebx, 4
    mov ecx, ebx  ;Get the number of bytes we allocated
    xor eax, eax
    rep stosb
    pop rdi         ;Get back the allocated block pointer!
    mov qword [pPsdaTbl], rdi    ;Store the pointer to the psdaTbl here
    mov qword [pCurSess], rdi    ;The session manager is the current session
    mov dword [dCurSess], SM_SESSION
;Now copy the SDA over and the DOS state as things stand. rsi -> DOS SDA
;    breakpoint
    lea rdi, qword [rdi + psda.sdaCopy]
    mov ecx, dword [dSdaLen]
    rep movsb   ;Copy over the SDA as it stands now, in peacetime!

;Now launch dMaxSesIndx copies of COMMAND.COM.
    mov eax, 1900h  ;Get in AL the current drive (0=A, ...)
    int 21h
    add al, "A"
    mov byte [dfltShell], al    
    mov byte [dfltShell2], al   ;Store on the backup shell too
    xor ecx, ecx    ;Default search attributes
    lea rdx, dfltShell
    mov eax, 4E00h  ;Find First
    int 21h
    jnc .shellFnd
    lea rdx, dfltShell2
    mov eax, 4E00h  ;Find First
    int 21h
    jnc .shellFnd
    lea rdx, noCmdStr
    jmp exitMcon
.shellFnd:
    mov qword [pCmdShell], rdx    ;Save the string to the program to spawn

;Setup this Int 22h. If the COMMAND.COM of a session exits, then 
; this handler is executed. COMMAND.COM when loaded as /P will override 
; this in both the IDT and in its own PSP so this is very much for any
; early accidents. Eventually, will replace this with a routine that 
; tries to launch a new instance of the program specified in the sm.ini 
; config file.
    lea rdx, i22hHdlr   ;Install the tmp Int 22h handler!
    mov eax, 2522h
    int 21h

    lea rdx, interruptExit  
    mov eax, 252Eh  ;Eliminate any COMMAND.COM hook that might be present!
    int 21h

;Now we spawn each session one by one.
;After each spawn, we copy the SDA into the psda for that session.
;This way, each session has the right current psp, dta, drive and dos state.
;After each spawn, pull the rax value from the child stack, replacing
; it with the rip value to start program execution. 
;Place 0202h flags, PSPptr in r8 and r9 and rax in rax on the register stack.

;Prepare the sda copy pointer
;    breakpoint
    mov rdi, qword [pPsdaTbl]
    mov ecx, dword [dPsdaLen]
    add rdi, rcx    ;Go to the first user session PSDA

    sub rsp, loadProg_size  ;Make space for the loadprog structure
    mov rbp, rsp
    mov ecx, dword [dMaxSesIndx]
;Now setup the loadProgBlock on the stack
    xor eax, eax
    mov qword [rbp + loadProg.pEnv], rax    ;Copy the parent environment!
    lea rax, cmdTail
    mov qword [rbp + loadProg.pCmdLine], rax
    lea rax, qword [r8 + psp.fcb1]
    mov qword [rbp + loadProg.pfcb1], rax
    lea rax, qword [r8 + psp.fcb2]
    mov qword [rbp + loadProg.pfcb2], rax
;   breakpoint
loadLp:
    xor eax, eax
    mov qword [rbp + loadProg.initRSP], rax ;Reset the return values to 0
    mov qword [rbp + loadProg.initRIP], rax
    mov rdx, qword [pCmdShell]
    mov rbx, rbp
    mov eax, 4B01h
    int 21h
    jnc .loadOk
.badLoad:
    lea rdx, noExecStr
    ;Here we have to unwind the programs, set Int 22h in each PSP 
    ; to an appropriate loaction, copy the SDA into DOS, and call EXIT.
    ;For now, we cause a memory leak and proceed.
    mov rbx, r8     ;Move SM PSP pointer int rbx
    mov eax, 5000h  ;Reset the current PSP back to SM
    int 21h
    jmp exitMcon
.loadOk:
;rdi points to the psda for this session
    lea rax, i22hHdlr
    mov qword [rdi + psda.pInt22h], rax
    mov eax, 3523h  ;Get the default Int 23h handler!
    int 21h
    mov qword [rdi + psda.pInt23h], rbx
    mov eax, 3524h  ;Get the default Int 24h handler!
    int 21h
    mov qword [rdi + psda.pInt24h], rbx
    lea rbx, interruptExit
    mov qword [rdi + psda.pInt2Eh], rbx
;   breakpoint
    mov rbx, qword [rbp + loadProg.initRSP]
    mov qword [rdi + psda.qRSP], rbx ;Store the Stack value!
    mov rax, qword [rbp + loadProg.initRIP] 
    xchg rax, qword [rbx]   ;Swap the RIP value with the FCB words on the stack!
    mov qword [rdi + psda.sRegsTbl + 15*8], rax ;Store rax @ rax on regstack!
    mov eax, 5100h  ;Get Current PSP in rbx
    int 21h
    mov qword [rdi + psda.sRegsTbl + 7*8], rbx  ;Store PSP ptr @ r9 on regstack!
    mov qword [rdi + psda.sRegsTbl + 8*8], rbx  ;Store PSP ptr @ r8 on regstack!
    mov qword [rdi + psda.sRegsTbl], 0202h      ;Store default flags on regstack!
;Now copy the SDA into the psda SDA
    push rcx
    mov rsi, qword [pDosSda]
    lea rdi, qword [rdi + psda.sdaCopy]
    mov ecx, dword [dSdaLen]
    rep movsb   ;rdi now points to the next psda
    pop rcx
;Now reset the PSP back so that each process is a proper child of SM!
    mov eax, 5000h  ;Set current PSP
    mov rbx, r8
    int 21h
    dec ecx
    jnz loadLp

    add rsp, loadProg_size  ;Reclaim the allocation in the end

;Set ourselves to be our own parent now!
    mov qword [r8 + psp.parentPtr], r8
;Setup the default int 22h and int 23h of the SM in the PSP since we are our
; own Parent. No need to set the interrupt vectors, thats done on entry to the 
; shell.
    mov rsi, qword [pPsdaTbl]   ;Get the PSDA table entry of SM
    lea rdx, i22hShell
    mov qword [r8 + psp.oldInt22h], rdx
    mov qword [rsi + psda.pInt22h], rdx
    lea rdx, i23hHdlr
    mov qword [r8 + psp.oldInt23h], rdx
    mov qword [rsi + psda.pInt23h], rdx
    lea rdx, i24hHdlr
    mov qword [r8 + psp.oldInt24h], rdx
    mov qword [rsi + psda.pInt24h], rdx

;Now setup the Int 2Ah infrastructure.
    lea rdx, i2AhDisp
    mov eax, 252Ah
    int 21h
;Patch the DOS kernel to call Int 2Ah correctly.
;Go in reverse from rsi which points to the DOS SDA
    mov rsi, qword [pDosSda]
    lea rbx, qword [rsi - 1]
    mov rdi, qword [rbx - 8]
    mov byte [rdi], 050h    ;Change from RET to PUSH RAX
    mov rdi, qword [rbx - 16]
    mov byte [rdi], 050h    ;Change from RET to PUSH RAX
    mov rdi, qword [rbx - 24]
    mov byte [rdi], 050h    ;Change from RET to PUSH RAX
    mov rdi, qword [rbx - 32]
    mov byte [rdi], 050h    ;Change from RET to PUSH RAX
;Now we are ready to jump!
    mov ecx, 1 ;Start with task 1
    jmp gotoSession
