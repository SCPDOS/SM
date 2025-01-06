;Structures and equates for SM.EXE

SM_SESSION  equ 0       ;Session number for Session Manager
SM_SIG_2F   equ 0Ah     ;Session Manager multiplex number

;Critical Lock
struc critLock
    .dCount dd ?    ;When this is zero, the lock is free
endstruc


struc psda  ;Per-Session Data Area
    .pInt22h    dq ?    ;Int 22h handler on session switch
    .pInt23h    dq ?    ;Int 23h handler on session switch
    .pInt24h    dq ?    ;Int 24h handler on session switch
    .pInt2Eh    dq ?    ;Int 2Eh handler on session switch (for master CMD)
    .qRSP       dq ?    ;RSP on session switch
    .sRegsTbl   dq 16 dup (?)   ;Register storage location
    .boS:
;    alignb 16
;    .pFPUState  dq 512 dup (?)  ;Extended state storage
    .sdaCopy:           ;Copy of the DOS sda for this session when not active
endstruc


struc mScrCap   ;Communication packet with MCON
    .wVer       dw ?    ;Upper byte, Major num (1). Lower byte, minor num (0)
    .wLen       dw ?    ;Length of structure (15 bytes)
    .wMagic     dw ?    ;Magic key combo (scancode/ASCII)
    .bScrNum    db ?    ;Number of screens supported by driver
    .qHlpPtr    dq ?    ;Pointer to the mCon help routine
endstruc
magicCode equ 7100h ;Scancode/ASCII code of ALT+F10