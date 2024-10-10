;Uninitialised data goes here

;Write Once variables, ALL SET UP.
pDosMgrPsp  dq ?    ;Pointer to the DOSMGR PSP
pDosSda     dq ?    ;Pointer to the DOS SDA
pPtdaTbl    dq ?    ;Pointer to the Per-Task data area table.
dPtdaLen    dd ?    ;Length of each ptda
dSdaLen     dd ?    ;Use the longer length. Change this in the future...
dMaxSesIndx dd ?    ;Maximum screen session index! Max Session number = 7.
pConIOCtl   dq ?    ;Ptr to the direct Console IOCtl routine

;The below is a temp var until we make a good routine for if the 
; top level program of a session exits
pCmdShell   dq ?    ;Pointer to the command shell to launch

;Dynamic variables below

;Screen Session management dataPtda
bScrnIoOk   db ?    ;Set if the screen can be IO'ed to/from! Used by CON!

bSM_Req     db ?    ;If set, the byte below indicates the requested screen
bSM_Req_Scr db ?    ;Scrren number to swap to

;Task management
dCurTask    dd ?    ;Task number. Offset into the PTDA table.
pCurTask    dq ?    ;Ptr to the current task PTDA

;Supported Critical section locks
dosLock     db critLock_size dup (?)    ;Critical section lock
drvLock     db critLock_size dup (?)    ;Critical section lock

;Shell to launch on sessions. 
;Read from the CMD= string in the environment or passed by cmd line argument.
inStr       db 5 dup (?)
;newShell    db 67 dup (?) 

pIDT:
    .limit  dw ?
    .base   dq ?

;Timer variables
    bSliceCnt   db ?    ;Number of ticks since last swap
    bSliceSize  db ?    ;Number of ticks in one "timeslice"
    bTimerCnt   db ?    ;BIOS timer tracker (when it hits 55ms, do BIOS).
    pOldTimer   dq ?