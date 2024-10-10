;All DOSMGR interrupt routines go here (not SM Shell)


timerIrq:
;This is the replacement interrupt handler. 
    cli
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
;Enter with interrupts off! This is to prevent race conditions on waits!
    cli ;Disable interrupts
    test ah, ah
    jz status
    cmp ah, 03h
    je ioblock
    cmp ah, 80h
    je enterCriticalSection
    cmp ah, 81h
    je leaveCriticalSection
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
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
; CAVEAT CAVEAT CAVEAT CAVEAT CAVEAT CAVEAT CAVEAT CAVEAT CAVEAT CAVEAT 
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
;In what follows, DOS and Driver critical section refers to 
; interruptable and uninterruptable critical section respectively.
;Uninterruptable critical sections behave specially in that they assume
; that they are always being called before a driver request UNLESS
; either RBX or RSI are null pointers, in which case the special driver
; handling is skipped.
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
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
    test al, al
    jz .exit
    cmp ax, 2
    ja .exit
    lea rax, drvLock
    lea rdi, dosLock
    cmove rdi, rax  ;Move the drvlock into rdi if al = 2
    je .drvCrit     ;And go to the driver special handling code.
;Else, we are a DOS critical section, go straight to the lock code
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
    call taskSwitch ;Else, put the calling task on ice for one cycle.
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
;If either rsi or rbx are NULL then we assume this is a non-driver 
; request for an uninterruptable critical section.
    test rsi, rsi
    jz .lockMain
    test rbx, rbx
    jz .lockMain
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
;This is a kludge as DOS is not multitasking so of course will not 
; do this for us :) It is the only reasonable way of communicating 
; the screen number of the task making the request to the driver.
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

leaveCriticalSection:    ;AH=81h
;If the calling task owns the lock, decrements the lock
    push rax
    push rdi
    test al, al ;If 0, exit
    jz .exit
    cmp al, 2
    ja .exit    ;If above 2, exit
    lea rdi, dosLock
    lea rax, drvLock
    cmove rdi, rax  ;Swap rdi to drvLock if AL=2
    cmp dword [rdi + critLock.dCount], 0    ;If lock is free, exit!
    je .exit
    mov rax, qword [pCurTask]   ;Else, check we own the lock
    cmp qword [rdi + critLock.pOwnerPdta], rax
    jne .exit   ;If we don't own the lock, exit!
    dec dword [rdi + critLock.dCount]   ;Else, decrement the lock!
.exit:
    pop rdi
    pop rax
    iretq

deleteCriticalSection:      ;AH=82h
;Will clear any critical sections OWNED by the task that is trying to 
; enter the lock! Else, this function will do nothing.
    push rax
    push rdi
    mov rax, qword [pCurTask]
    lea rdi, dosLock
    call .clearLock
    lea rdi, drvLock
    call .clearLock
    pop rdi
    pop rax
    iretq
.clearLock:
    test dword [rdi + critLock.dCount], -1    ;Is this lock allocated?
    retz    ;If this lock is free, exit! 
    cmp qword [rdi + critLock.pOwnerPdta], rax  ;Else, do we own it?
    retne   ;If not, exit!
    mov dword [rdi + critLock.dCount], 0    ;Else, free it!
    return


releaseTimeslice:  ;AH=84h
;Intercepts the keyboard and releases the timeslice for the task that enters.
    call taskSwitch
    iretq