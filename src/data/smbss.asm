;Uninitialised data goes here

;Write Once variables, ALL SET UP.
pDosMgrPsp  dq ?    ;Pointer to the DOSMGR PSP
pDosSda     dq ?    ;Pointer to the DOS SDA
pPcbTbl     dq ?    ;Pointer to the Process Control Block table.
dPcbLen     dd ?    ;Length of each pcb
dSdaLen     dd ?    ;Use the longer length. Change this in the future...
dMaxSesIndx dd ?    ;Maximum screen session index! Max Session number = 7.

;The below is a temp var until we make a good routine for if the 
; top level program of a session exits
pCmdShell   dq ?    ;Pointer to the command shell to launch

;Shell to launch on sessions. 
;Read from the CMD= string in the environment or passed by cmd line argument.
inStr       db 5 dup (?)
;newShell    db 67 dup (?) 

;Dynamic variables below

;Screen Session management dataPcb
bCurScrNum  db ?    ;Contains the current screen number!
bScrnIoOk   db ?    ;Set if the screen can be IO'ed to/from! Used by CON!

bSM_Req     db ?    ;If set, the byte below indicates the requested screen
bSM_Req_Scr db ?    ;Screen number to swap to

;Thread management
dCurThread  dd ?    ;Task number. Offset into the PCB table.
pCurThread  dq ?    ;Ptr to the current thread.

;Supported Critical section locks
dosLock     db critLock_size dup (?)    ;Critical section lock
drvLock     db critLock_size dup (?)    ;Critical section lock

;Prioritised List pointers
scheduleLists:
    db 32*schedHead_size dup (?)    ;32 schedules, 0-31

sleepPtr    dq ?    ;Pointer to the head of the sleep list

pIDT:
    .limit  dw ?
    .base   dq ?

;Timer variables
bSliceCnt   db ?    ;Number of ticks since last swap
bSliceSize  db ?    ;Number of ticks in one "timeslice"
bTimerCnt   db ?    ;BIOS timer tracker (when it hits 55ms, do BIOS).
pOldTimer   dq ?