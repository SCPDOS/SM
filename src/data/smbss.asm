;Uninitialised data goes here

;Write Once variables, ALL SET UP.
pDosMgrPsp  dq ?    ;Pointer to the DOSMGR PSP
pDosSda     dq ?    ;Pointer to the DOS SDA
dSdaLenMin  dd ?    ;Length of SDA that needs to be swapped if not in DOS.
dSdaLen     dd ?    ;Full SDA length
pPcbTbl     dq ?    ;Ptr to the first PCB SOTH.
dPcbLen     dd ?    ;Length of each pcb
dMaxTask    dd ?    ;Var version of MAX_TASK
dMaxSesIndx dd ?    ;Maximum screen session index! Max Session number = 7.

;The below is a temp var until we make a good routine for if the 
; top level program of a session exits
pCmdShell   dq ?    ;Pointer to the command shell to launch

;Shell to launch on sessions. 
;Read from the CMD= string in the environment or passed by cmd line argument.
inStr       db 5 dup (?)
;newShell    db 67 dup (?) 

;Dynamic variables below

;Screen Session management data
bCurScrNum  db ?    ;Contains the current screen number!
bScrnIoOk   db ?    ;Set if the screen can be IO'ed to/from! Used by CON!

bSM_Req     db ?    ;If set, the byte below indicates the requested screen
bSM_Req_Scr db ?    ;Screen number to swap to

;Thread management
hCurPtda    dd ?    ;Current Thread Handle
pCurPtda    dq ?    ;Ptr to the current thread ptda.

;Supported Critical section locks
dosLock     db critLock_size dup (?)    ;Critical section lock
drvLock     db critLock_size dup (?)    ;Critical section lock

;List pointers
pObjTblHdr  dq ?    ;Pointer to the first system object table.
;The sleep list is a linked list of PDTAs
pHdSlpList  dq ?    ;Ptr to the head of the sleep list (of PDTAs)

schedBlk:   ;The schedule list block
    db NUM_SCHED*schedHead_size dup (?)

;BIOS related stuff
pIDT:
    .limit  dw ?
    .base   dq ?

;Timer variables
bSliceCnt   db ?    ;Number of ticks since last swap
bSliceSize  db ?    ;Number of ticks in one "timeslice"
bTimerCnt   db ?    ;BIOS timer tracker (when it hits 55ms, do BIOS).
pOldTimer   dq ?