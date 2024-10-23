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
;Save the PSP pointer for the Session (DOS) Manager
    mov qword [pDosMgrPsp], r8
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
    lea rbx, devHlp
    mov qword [rdx + mScrCap.pDevHlp], rbx
    mov eax, 440Ch
    xor ebx, ebx    ;CON handle (STDIN)!
    mov ecx, 0340h  ;CON + Reports capacities!
    int 21h
    jnc mConOk
    lea rdx, noConStr
    jmp exitBad
mConOk:
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
;Now we set the maximum number of tasks
    mov dword [dMaxTask], MAX_TASK
;Get the size of the SDA to know how big a pcb actually is.
    mov eax, 5D06h
    int 21h
    mov qword [pDosSda], rsi
    mov dword [dSdaLen], ecx   
    mov dword [dSdaLenMin], edx
    add ecx, pcb_size
;Round up the pcb size to a 16-byte boundary.
    add ecx, 0Fh
    shr ecx, 4
    shl ecx, 4
    mov dword [dPcbLen], ecx   ;Save the max length of a pcb.
;Now lets allocate a soth for pcbs
    mov eax, ecx    
    mov ebx, dword [dMaxTask]   ;Get the maximum number of tasks
    mul ebx     ;Multiply size of pcb with max number of tasks.

    add eax, soth_size  ;Add the SOTH header size too
    add eax, 0Fh    ;Round result up by a paragraph
    shr eax, 4      ;Turn into number of paragraphs
    mov ebx, eax
    mov eax, 4800h
    int 21h
    jnc spaceOk
    lea rdx, noMemStr
exitMcon:
    mov eax, 440Ch  ;Generic IOCTL
    mov ecx, 0348h  ;Deinstall mtask capabilities from CON
    int 21h
    jmp exitBad
spaceOk:
    push rax        ;Save the pointer to the allocated block!
    mov rdi, rax    ;Clear the space we just allocated!
    shl ebx, 4
    mov ecx, ebx  ;Get the number of bytes we allocated
    xor eax, eax
    rep stosb
    pop rdi         ;Get back the allocated block pointer!
;Now setup the SOTH with the right flags!
    mov qword [rdi + soth.pNextSoth], -1    ;End of chain marker!
    mov ecx, dword [dMaxTask]
    mov dword [rdi + soth.dNumEntry], ecx   ;This table saves all tasks.
    mov word [rdi + soth.wObjType], OBJ_PCB ;We use this for PCBs
    mov ecx, dword [dPcbLen]
    mov word [rdi + soth.wObjectSz], cx     ;This is the object size
    mov qword [pObjTblHdr], rdi ;Save the pointer to the first object table here
;Now set up the PCB Table information
    mov qword [pPcbTbl], rdi    ;Store ptr to the first pcb soth here
    add rdi, soth_size          ;Go to the first entry here
    mov byte [rdi + pcb.bPcbInUse], -1  ;Set to allocated
    mov qword [pCurPtda], rdi ;The session manager is the current task
    mov dword [hCurPtda], SM_SESSION
;Now copy the SDA over and the DOS state as things stand. rsi -> DOS SDA
    lea rdi, qword [rdi + pcb.sPtda + ptda.sdaCopy]
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

;Now we spawn each task one by one.
;After each spawn, we copy the SDA into the pcb for that task.
;This way, each task has the right current psp, dta, drive and dos state.
;After each spawn, pull the rax value from the child stack, replacing
; it with the rip value to start program execution. 
;Place 0202h flags, PSPptr in r8 and r9 and rax in rax on the register stack.

;Prepare the sda copy pointer
    mov ecx, 1      ;Goto the first pcb 
    call getPcbPtr  ;Get the ptr in rdi

    sub rsp, loadProg_size  ;Make space for the loadprog structure
    mov rbp, rsp
    mov ecx, 1  ;Start counting task numbers from 1
;Now setup the loadProgBlock on the stack
    xor eax, eax
    mov qword [rbp + loadProg.pEnv], rax    ;Copy the parent environment!
    lea rax, cmdTail
    mov qword [rbp + loadProg.pCmdLine], rax
    lea rax, qword [r8 + psp.fcb1]
    mov qword [rbp + loadProg.pfcb1], rax
    lea rax, qword [r8 + psp.fcb2]
    mov qword [rbp + loadProg.pfcb2], rax
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
;rdi points to the pcb for this task
    lea rax, i22hHdlr
    mov qword [rdi + pcb.pInt22h], rax
    mov eax, 3523h  ;Get the default Int 23h handler!
    int 21h
    mov qword [rdi + pcb.pInt23h], rbx
    mov eax, 3524h  ;Get the default Int 24h handler!
    int 21h
    mov qword [rdi + pcb.pInt24h], rbx
    lea rbx, interruptExit
    mov qword [rdi + pcb.pInt2Eh], rbx
;   breakpoint
    mov rbx, qword [rbp + loadProg.initRSP]
    mov qword [rdi + pcb.sPtda + ptda.qRSP], rbx ;Store the Stack value!
    mov rax, qword [rbp + loadProg.initRIP] 
    xchg rax, qword [rbx]   ;Swap the RIP value with the FCB words on the stack!
    mov qword [rdi + pcb.sPtda + ptda.sRegsTbl + 15*8], rax ;rax on regstack!
    mov eax, 5100h  ;Get Current PSP in rbx
    int 21h
    mov qword [rdi + pcb.sPtda + ptda.sRegsTbl + 7*8], rbx  ;PSP ptr @ r9
    mov qword [rdi + pcb.sPtda + ptda.sRegsTbl + 8*8], rbx  ;PSP ptr @ r8
    mov qword [rdi + pcb.sPtda + ptda.sRegsTbl], 0202h      ;Flags!
;Make sure to save the screen number and process information!
    mov dword [rdi + pcb.hScrnNum], ecx     ;Save the screen number of task!
    mov dword [rdi + pcb.hPcb], ecx ;This is also the count of the task!
    mov dword [rdi + pcb.hParPcb], ecx 
    mov dword [rdi + pcb.dCsid], ecx 
    mov byte [rdi + pcb.bPcbInUse], -1  ;Set to allocated

;Now copy the SDA into the pcb SDA
    push rcx
    mov rsi, qword [pDosSda]
    lea rdi, qword [rdi + pcb.sPtda + ptda.sdaCopy]
    mov ecx, dword [dSdaLen]
    rep movsb   ;rdi now points to the next pcb
    pop rcx
;Now reset the PSP back so that each process is a proper child of SM!
    mov eax, 5000h  ;Set current PSP
    mov rbx, r8
    int 21h
    inc ecx
    cmp ecx, dword [dMaxSesIndx]
    jbe loadLp

    add rsp, loadProg_size  ;Reclaim the allocation in the end

;Set ourselves to be our own parent now!
    mov qword [r8 + psp.parentPtr], r8
;Setup the default int 22h and int 23h of the SM in the PSP since we are our
; own Parent. No need to set the interrupt vectors, thats done on entry to the 
; shell.
    xor ecx, ecx    ;SM Hdl
    call getPcbPtr  ;Get the ptr in rdi 
    mov rsi, rdi    ;Move ptr to rsi

    lea rdx, i22hShell
    mov qword [r8 + psp.oldInt22h], rdx
    mov qword [rsi + pcb.pInt22h], rdx
    lea rdx, i23hHdlr
    mov qword [r8 + psp.oldInt23h], rdx
    mov qword [rsi + pcb.pInt23h], rdx
    lea rdx, i24hHdlr
    mov qword [r8 + psp.oldInt24h], rdx
    mov qword [rsi + pcb.pInt24h], rdx
;Now we gotta setup RIP, RSP, flags and regs for the Session Manager
    lea rdx, sm$shlTOS
    mov qword [rsi + pcb.sPtda + ptda.qRSP], rdx
    lea rdx, shellMain  ;We enter at shellMain (interrupts on, and rsp ok)
    mov qword [rsi + pcb.sPtda + ptda.sRegsTbl + 15*8], rdx ;Set RIP
    mov qword [rsi + pcb.sPtda + ptda.sRegsTbl + 7*8], r9  ;PSP ptr @ r9
    mov qword [rsi + pcb.sPtda + ptda.sRegsTbl + 8*8], r8  ;PSP ptr @ r8
    mov qword [rsi + pcb.sPtda + ptda.sRegsTbl], 0202h     ;flags

;Now put every task into middle priority list (schedule 15)!
    mov al, 15
    call getSchedHeadPtr    ;Get the schedhead ptr in rsi
;Now add all the tasks's we've just created to this list
    xor ecx, ecx
    call getPcbPtr     ;Get pcb pointer in rdi for task 0
    call getRootPtdaPtr  ;Get ptr to the first ptda of rdi in rbp
    inc dword [rsi + schedHead.dNumEntry]
    mov qword [rsi + schedHead.pSchedHead], rbp ;This is the head
    mov qword [rsi + schedHead.pSchedTail], rbp ;Tis also the tail!
schedLp:
    inc ecx
    cmp ecx, dword [dMaxSesIndx]    ;We start by launching this amount of tasks.
    ja schedExit
    call getPcbPtr     ;Get pcb pointer in rdi for task ecx
    call getRootPtdaPtr   ;Get ptr to the first ptda of rdi in rbp
    mov rdi, qword [rsi + schedHead.pSchedTail] ;Get the last entry in the sched
    mov qword [rdi + ptda.pNSlepPtda], rbp    ;rbp comes after this 
    mov qword [rsi + schedHead.pSchedTail], rbp ;This ptda is the new last ptda
    inc dword [rsi + schedHead.dNumEntry]       ;Added a new element to schedule
    jmp short schedLp
schedExit:

    jmp short i2ahJmp   ;Skip the timer stuff
;Now setup the timer infrastructure for the timer interrupt.
;Start by replacing the old timer interrupt with our better one.
    cli         ;Start by ensuring interrupts are off!
    mov eax, 3500h | timerInt  ;Get ptr to timer interrupt in rbx
    int 21h
    mov qword [pOldTimer], rbx
    lea rdx, timerIrq ;Get the pointer to the new handler
    mov eax, 2500h | timerInt  ;Set ptr for timer interrupt
    int 21h

;Now we set the timer to trigger and interrupt every ms.
    mov al, 36h     ;Channel 0, same settings as BIOS
    out PITcmd, al
 
    mov eax, 1193   ;Divisor to get frequency of 1000.15Hz
    out PIT0, al    ;Set low byte of PIT reload value
    mov al, ah      ;ax = high 8 bits of reload value
    out PIT0, al    
i2ahJmp:
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

;
; TMP TMP TMP TMP TMP TMP TMP TMP
;
    lea rdx, errorStr
    mov eax, 0900h
    int 21h
lp:
    jmp short lp
errorStr db "Session Manager not ready yet. System halted!"
;
; TMP TMP TMP TMP TMP TMP TMP TMP
;

;Actual exit code below
    sti         ;Ensure we return interrupts on!
    mov ecx, 1  ;Start COMMAND.COM on screen 1
    jmp swapScreen
