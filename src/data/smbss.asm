;Uninitialised data goes here

;Write Once variables, ALL SET UP.
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
bDefFlg     db ?    ;If set, defered session swap flag set! 

;Task management
dCurTask    dd ?    ;Task number. Offset into the PTDA table.
pCurTask    dq ?    ;Ptr to the current task PTDA
sesLock     db critLock_size dup (?)    ;Critical section lock

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