;All DOSMGR interrupt routines go here (not SM Shell)


timerIrq:
;This is the replacement interrupt handler. 
    push rax
    inc byte [bSliceCnt]     ;Increment the slice counter
    movzx eax, byte [bSliceSize]  ;Number of ms in one timeslice
    cmp byte [bSliceCnt], al
    jne .notaskSwitch
    pop rax
    call taskSwitch  ;Change process
    push rax
    mov byte [bSliceCnt], 0  ;Reset timer
.notaskSwitch:
    inc byte [bTimerCnt] ;Increment the BIOS timer tracker
    cmp byte [bTimerCnt], 55 ;Every 55ms trigger the old timer interrupt
    je .callBIOSTimer ;Else, just exit normally
    ;Else, tell the PIT to relax
    mov al, EOI
    out pic1cmd, al
    pop rax
.exit:
    iretq
.callBIOSTimer:
    pop rax
    mov byte [bTimerCnt], 0  ;Reset the hw counter tracker
    jmp qword [pOldTimer]    ;Jump to the old timer


;------------------------------------------------------------
;Int 2Ah Dispatcher
;------------------------------------------------------------
i2AhDisp:
    cli ;Disable interrupts
    test ah, ah
    jz status
    cmp ah, 03h
    je ioblock
    cmp ah, 80h
    je enterCriticalSection
    cmp ah, 81h
    je endCriticalSection
    cmp ah, 82h
    je deleteCriticalSection
    cmp ah, 84h
    je releaseTimeslice
    iretq

status:    ;AH=00h
    mov ah, -1
    iretq

ioblock:    ;AH=03h
;Since singletasking DevDrvIO is properly protected through critical sections
; we only need to ensure that access to devices via BIOS calls, Int 25h 
; and Int 26h have not been interrupted. This can be done by hooking, placing a
; flag and incrementing the flag each time we enter and exit, then checking 
; if that flag is high for that device. 
;Input: rsi -> ASCIIZ string for device
    iretq

enterCriticalSection:    ;AH=80h
;If this is called for a DOS critical section, attempts to give the 
; lock to the caller. If it cannot, the task is swapped until it gets its
; next quantum. If it can, the lock is allocated to it.
;
;SPECIAL CASE: If called for a Driver critical section, and the driver
; is normal DOS driver, then it acts as in the case of the DOS critical
; section. However, in the case of the driver having the undocumented
; multitasking bit set, then the driver will not give the lock to the 
; task as it is understood that the driver is capable of handling
; concurrent threads within it. Furthermore, if the driver is the 
; CON driver, and the request is a READ, WRITE or WRITE/VERIFY 
; then the session number (screen number) handle is placed in the 
; ioReqPkt.strtsc of the packet.
    push rax
    push rdi
    lea rax, dosLock
    lea rdi, drvLock
    cmp al, 1
    cmove rdi, rax  ;Move the DOS lock ptr into rdi, else keep drvLock
    je .lockMain    ;If a DOS critical section, go straight to the lock code
    cmp al, 2       ;Is this a driver critical section?
    je .drvCrit     ;If so, go to the driver special handling code.
    jmp short .exit       ;Else, just exit!
.lockMain:
;Entered with rdi -> Lock to check
    mov rax, qword [pCurTask]   ;Get the ptr to the current task
    cmp dword [rdi + critLock.dCount], 0    ;If the lock is free, take it!
    jne .noGive
    mov qword [rdi + critLock.pOwnerPdta], rax  ;Set yourself as owner!
    jmp short .incCount
.noGive:
    cmp qword [rdi + critLock.pOwnerPdta], rax
    je .incCount    ;If we own the lock, increment the count!
    call taskSwitch
    jmp short .lockMain     ;Try obtain the lock again!
.incCount:
    inc dword [rdi + critLock.dCount]   ;Increment the entry count!
.exit:
    pop rdi
    pop rax
    iretq
.drvCrit:
;Entered with:
;rdi -> Driver lock object
;rsi -> Driver header
;rbx -> Request packet
    movzx eax, word [rsi + drvHdr.attrib]
    test ax, devDrvMulti
    jz .lockMain   ;If not a multitasking driver, try grab the lock!
;We reach the code below if we are entering an interruptable driver.
;In this case, we do not wait on the lock and proceed as normal.
    test ax , devDrvChar
    jz .exit    ;Exit if not a char dev
    and ax, devDrvConIn | devDrvConOut
    jz .exit    ;If neither bit set, exit
    ;Here if this is either a MDOS CON In or CON Out device. 
    ;If request is read/write, place current task's screen number 
    ; in the ioReqPkt.strtsc field (we zxtend the byte to qword).
    movzx eax, byte [rbx + drvReqHdr.cmdcde]
    cmp eax, drvREAD
    je .ioReq
    cmp eax, drvWRITE
    je .ioReq
    cmp eax, drvWRITEVERIFY
    jne .exit
.ioReq:
    mov rax, qword [pCurTask]
    mov eax, dword [rax + ptda.hScrnNum]
    mov dword [rbx + ioReqPkt.strtsc], eax
    jmp short .exit

endCriticalSection:    ;AH=81h
;Simply derements the appropriate lock count towards zero. 
; If it is zero, don't decrement!
    push rdi
    cmp al, 1
    je .dos
    cmp al, 2
    jne .exit
;Because Driver locks may not be given due to a multitasking driver
; we must check if we have a driver lock call that the returning 
; task owns the lock. Else, we simply ignore the lock call!
    mov rdi, qword [pCurTask]
    cmp qword [drvLock + critLock.pOwnerPdta], rdi
    jne .exit
;Else, this task owns the lock, proceed to decrement the count!
    lea rdi, drvLock
    jmp short .cmn
.dos:
    lea rdi, dosLock
.cmn:
    cmp dword [rdi + critLock.dCount], 0
    je .exit
    dec dword [rdi + critLock.dCount]
.exit:
    pop rdi
    iretq

deleteCriticalSection:      ;AH=82h
;Once threading is introduced, where threads share a copy of the SDA, this
; unit will operate as commented out below!
    iretq
;    push rax
;.lp:
;    cmp qword [dosLock + critLock.dCount], 0    ;Is lock free? Proceed if so!
;    je .exit
;;If the task calling this function owns the lock, proceed.
;;Else, put the task to sleep!
;    mov rax, qword [pCurTask]
;    cmp qword [dosLock + critLock.pOwnerPdta], rax
;    je .exit
;    call taskSwitch
;    jmp short .lp
;.exit:
;    pop rax
;    iretq

releaseTimeslice:  ;AH=84h
;Intercepts the keyboard and releases the timeslice for the task that enters.
    iretq