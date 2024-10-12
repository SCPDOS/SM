;Structures and equates for DOSMGR

SM_SESSION  equ 0       ;Session number for Session Manager

;Critical Lock
struc critLock
    .dCount     dd ?    ;When this is zero, the lock is free
    .pOwnerPdta dq ?    ;Ptr to the owner of the lock!
endstruc

;Systen Object Table header
struc soth  
    .pNextSoth  dq ?    ;Pointer to the next soth
    .dSize      dd ?    ;Size of the soth
    .wObjType   dw ?    ;Type of object stored in the table
    .wObjectSz  dw ?    ;Size of the objects stored in this table
endstruc
    OBJ_PROCESS equ 1
    OBJ_THREAD  equ 2

;Schedule head, used to protect the schedules from multiple processors 
; simultaneously modifying the list in a multiprocessor system.
struc schedHead
    .bLock      db ?    ;Set if this schedule is locked (no writes)
    .qFirstTsb  dq ?    ;Points to the head of the schedule
endstruc

;Thread Scheduling block, basic unit of the scheduler.
struc tsb 
    .pNextTsb   dq ?    ;Change this to handle. 
    .wThrdStat  dw ?    ;State of the thread in the schedule
endstruc

;Thread Control block, keeps thread state 
struc tcb 
    .sTsb       db tsb_size dup (?) ;Thread's schedule block
    .wFlags     dw ?    ;Flags for the Thread Control Block
;Sleep and Blocking States
    .dSleepLen  dd ?    ;Sleep length in ~ms, 0 mean indefinite
    .dAwakeCode dd ?    ;Non-zero codes indicating why task was woken up
    .qEventId   dq ?    ;ID to check for block/run calls.
;Register storage
    .qRSP       dq ?    ;RSP on task switch
    .sRegsTbl   dq 16 dup (?)   ;Register storage location
    .boS:
    ;alignb 16
    ;.pFPUState  dq 512 dup (?)  ;Extended state storage
endstruc

;Per-Task Data Area, keeps full process state.
;Must be aligned in size to 16 bytes.
struc ptda  
;Process metadata
    .hScrnNum   dd ?    ;Handle to the session (byte number of the screen)
    .hPtda      dd ?    ;Hdl to this ptda, currently just an offset
    .wFlags     dw ?    ;Task flags
;Thread conrol block, will be replaced to a ptr to the main thread tcb.
    alignb 16h
    .sTcb       db tcb_size dup (?) ;Thread's schedule block
;Interrupt handles for replacing on task swap
    .pInt22h    dq ?    ;Int 22h handler on task switch
    .pInt23h    dq ?    ;Int 23h handler on task switch
    .pInt24h    dq ?    ;Int 24h handler on task switch
    .pInt2Eh    dq ?    ;Int 2Eh handler on task switch (for master CMD)
;Per-process DOS state
    .sdaCopy:           ;Copy of the DOS sda for this session when not active
endstruc

ptda_sleep      equ 1   ;Timed sleep
ptda_block      equ 2   ;Blocked thread
ptda_interrupt  equ 4   ;Interruptable sleep

struc mScrCap   ;Communication packet with MCON
    .wVer       dw ?    ;Upper byte, Major num (1). Lower byte, minor num (0)
    .wLen       dw ?    ;Length of structure (13 bytes)
    .bScrNum    db ?    ;Number of screens supported by driver
    .pDevHlp    dq ?    ;Pointer to the devHlp help routine
endstruc

magicCode equ 7100h ;Scancode/ASCII code of ALT+F10

DevHlp_ConsInputFilter  equ 5
DevHlp_Signal_SM        equ 7
DevHlp_ProcBlock        equ 9
DevHlp_ProcRun          equ 10
DevHlp_GetDOSVar        equ 16


;BIOS Equates go here
EOI         equ 20h
pic1cmd     equ 20h

PITbase     equ 40h
PIT0        equ PITbase
PIT1        equ PITbase + 1
PIT2        equ PITbase + 2
PITcmd      equ PITbase + 3

timerInt    equ 0F0h    ;Change if we change this in BIOS!!