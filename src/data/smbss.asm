;Uninitialised data goes here

;Write Once variables, ALL SET UP.
pDosSda     dq ?    ;Pointer to the DOS SDA
pPsdaTbl    dq ?    ;Pointer to the Per-Session data area table
dPsdaLen    dd ?    ;Length of each psda
dSdaLen     dd ?    ;Use the longer length. Change this in the future...
dMaxSesIndx dd ?    ;Maximum session index! Max Session number = 7
pConIOCtl   dq ?    ;Ptr to the direct Console IOCtl routine

;The below is a temp var until we make a good routine for if the 
; top level program of a session exits
pCmdShell   dq ?    ;Pointer to the command shell to launch

;Session management data
dCurSess    dd ?    ;Offset into psda tbl.
pCurSess    dq ?    ;Ptr to current session. if equal to pPsdaTbl then in SM.
sesLock     db critLock_size dup (?)    ;Critical section lock
bDefFlg     db ?    ;If set, defered session swap flag set! 


;Shell to launch on sessions. 
;Read from the CMD= string in the environment or passed by cmd line argument.
inStr       db 5 dup (?)
;newShell    db 67 dup (?) 

pIDT:
    .limit  dw ?
    .base   dq ?