;All DOSMGR interrupt routines go here (not SM Shell)


timerIrq:
;This is the replacement interrupt handler. 
    push rax
    inc byte [bSliceCnt]     ;Increment the slice counter
    movzx eax, byte [bSliceSize]  ;Number of ms in one timeslice
    cmp byte [bSliceCnt], al
    jne .notaskSwitch
    pop rax
    call ctxtSwap  ;Change process
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
    je critInc
    cmp ah, 81h
    je critDec
    cmp ah, 82h
    je critReset    ;We've been signalled to remove locks and is safe to do so!
    cmp ah, 84h
    je keybIntercept
    iretq

status:    ;AH=00h
    mov ah, -1
    iretq

ioblock:    ;AH=03h
;Need to check that Int 33h if disk device is not active. Temp wont do that for now!
;Else it is fine as we cannot swap in critical section and 
; all default BIOS char devices are reentrant.
;Input: rsi -> ASCIIZ string for device
    iretq

critInc:    ;AH=80h
    push rax
    inc dword [sesLock + critLock.dCount]
    cmp al, 2
    je .drvCrit
.exit:
    pop rax
    iretq
.drvCrit:
    movzx eax, word [rsi + drvHdr.attrib]
    test ax , devDrvChar
    jz .exit    ;Exit if not a char dev
    test ax, devDrvMulti
    jz .exit    ;Exit if the driver is not declared as MDOS driver
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

critDec:    ;AH=81h
;If lock is zero, exit as we would not have been deferred here.
;Else decrement the lock as it is safe to do so.
;   If lock not zero after decrement, exit.
;   Else
;       If deferred flag zero, exit.
;       Else handle deferred session swap.
    cmp dword [sesLock + critLock.dCount], 0
    jz .exit
    dec dword [sesLock + critLock.dCount]
    cmp dword [sesLock + critLock.dCount], 0
    jne .exit
    test byte [bDefFlg], -1 ;If we have a deferred call, process now!
    jz .exit
    mov byte [bDefFlg], 0   ;Clear the deferral flag and process call!
    call gotoShell
.exit:
    iretq

critReset:      ;AH=82h
    mov dword [sesLock + critLock.dCount], 0    ;Reset the value here :)
    iretq

keybIntercept:  ;AH=84h
;Do nothing as we don't need this endpoint for now!
    iretq