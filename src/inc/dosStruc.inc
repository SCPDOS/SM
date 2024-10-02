;Structures and equates coming from DOS

;Load program structure
struc loadProg
    .pEnv       resq 1  ;Ptr to environment block (or 0 => copy parent env)
    .pCmdLine   resq 1  ;Ptr to the command line to be placed at PSP + 80h
    .pfcb1      resq 1  ;Ptr to the first FCB (parsed argument 1)
    .pfcb2      resq 1  ;Ptr to the second FCB  (parsed argument 2)
    .initRSP    resq 1  ;Return the start value for rsp
    .initRIP    resq 1  ;Return the entry point for the task
endstruc

;Sysvars struct
drvHdr_size equ 022h
struc sysVars
    .dpbHeadPtr  dq ?    
    .sftHeadPtr  dq ?    
    .clockPtr    dq ?    
    .vConPtr     dq ?
    .maxBytesSec dw ?    
    .bufHeadPtr  dq ?    
    .cdsHeadPtr  dq ?    
    .fcbsHeadPtr dq ?    
    .numSafeSFCB dw ?    
    .numPhysVol  db ?    
    .lastdrvNum  db ?
    .numBuffers  db ?
    .nulDevHdr   db drvHdr_size dup (?)
    .numJoinDrv  db ?    
    .numFiles    db ?   
; ---- dosMgrHooks and fun stuff ----
    .dosMgrPresent  db ?    ;Clear if no mgr, else set to -1
    .launchTask     dq ?    ;Registers a new task
    .terminateTask  dq ?    ;Called to tell the MGR that this task is ending
endstruc

struc sda
;Only the fields that we care about are here. These live in the 
; "always swap" portion of the SDA
;We only really care about inDOS, errorLevel and currentPSP
    .critErrFlag db ?  ;Critical error flag, set on entry to Int 24h x
    .inDOS       db ?  ;Inc on each DOS call, dec when leaving x
    .errorDrv    db ?  ;Drive on which error occured or FFh x
    .errorLocus  db ?  ;Where the error took place  
    .errorExCde  dw ?  ;Extended Error Code
    .errorAction db ?  ;Suggested action for error  
    .errorClass  db ?  ;Error Class
    .xInt24RDI   dq ?  ;Preserved rdi across a critical error
    .currentDTA  dq ?  ;Address of the current DTA x
    .currentPSP  dq ?  ;Address of current PSP x

    .xInt23hRSP  dq ?  ;Saves RSP across an Int 23h call
    .errorLevel  dw ?  ;Last return code returned by Int 21h/4Ch x
    ;Upper byte: 0=Normal, 1=Abort Occured, 2=CtrlC, 3=TSR 41h/31h
    ;Lower byte: User Specified
    .currentDrv  db ?  ;Default drive x
    .breakFlag   db ?  ;If set, check for CTRL+C on all DOS calls x
endstruc

dfltJFTsize equ 20  ;Default size of PSP JFT
struc psp
    .return     db 2 dup (?)  ;Should always be CDh 20h, same place as DOS
    .allocSize  dd ?  ;Number of paras in init alloc or when exiting as TSR.
                dd ?  ;Reserved 4 bytes
    .oldInt22h  dq ?  ;Int 22h pointer on overlay load
    .oldInt23h  dq ?  ;Int 23h pointer on overlay load
    .oldInt24h  dq ?  ;Int 24h pointer on overlay load
    .parentPtr  dq ?  ;Pointer to parent process PSP
;If jftSize > 20, then the QWORD at .jobFileTbl becomes a pointer
; to the actual in use JFT and the other 12 bytes are left undefined.
;If jftSize < 20 (DOS will never set it so), then it is considered as 20
;If the user tries to reduce handle count to 20 or less, then the PSP JFT is 
; always used and jftSize.
    .externalJFTPtr:    ;Ptr to external JFT array (first byte AFTER MCB)
    .jobFileTbl db dfltJFTsize dup (?) ;Main File handle array, JFT
    .envPtr     dq ?  ;Pointer to the environment
    .rspPtr     dq ?  ;Pointer to rsp on entry to Int 21h
    .jftSize    dw ?  ;JFT array size, 20 => PSP JFT in use
    .unixEntry  db 3 dup (?)  ;Must always be CDh 21h CBh, same place as DOS
    .prevPSP    dq ?  ;Pointer to the previous PSP in chain (used by SHARE)
                db ?  ;Reserved byte
;The below are in the same place as in DOS.
    .cmdLineArgPtr: ;Symbol for future use
    .fcb1       db 16 dup (?)  ;First FCB,    argument 1 
    .fcb2       db 20 dup (?)  ;Second FCB,   argument 2
    .dta:   ;Pointer to the default DTA in the PSP
    .parmList   db ?   ;Number of characters in command tail
    .progTail   db 127 dup (?) ;Default DTA/Program tail
endstruc

struc callerFrame
    .rax    dq ?  ;Bottom of frame, pointer to rax saved in oldRSP
    .rbx    dq ?    
    .rcx    dq ?
    .rdx    dq ?
    .rsi    dq ?
    .rdi    dq ?
    .rbp    dq ?
    .r8     dq ?  ;To be removed if truly not needed
    .r9     dq ?
;Pushed by Processor when invoked via Interrupt
    .rip    dq ?
    .cs     dq ?
    .flags  dq ?
    .rsp    dq ?
    .ss     dq ?
endstruc

execLoadGo  equ 0
execLoad    equ 1
execInvld   equ 2
execOverlay equ 3
execBkgrnd  equ 4

struc execFrame
    .oldRBP     dq ?  
    .bSubFunc   dq ?  ;Subfunction number
    .wProgHdl   dq ?  ;File handle number for executable file
    .wNameLen   dq ?  ;Needs to be less than 64 but welp
    .pParam     dq ?  ;Parameter list pointer
    .pProgname  dq ?  ;Ptr to ASCIIZ program name

    .pEnvBase   dq ?  ;Ptr to new Environment block, NOT THE MCB FOR ENV BLK
    .pPSPBase   dq ?  ;Ptr to new PSP base address
    .pProgBase  dq ?  ;Ptr to Prog. Base addr., ALIGNED FOR FIRST EXE SECTION
    .dProgSize  dq ?  ;Program size is saved here, PSP included.
    .dCOFFhdr   dq ?  ;Offset in file to COFF header. Set to 0 for COM
    .bSegCount  dq ?  ;Count of segments loaded into memory
    .wCOFFChars dq ?  ;Save the COFF characteristics in here
.pProgEP:   ;Program EP, recycle this qword
    .wNumSeg    dq ?  ;Number of segments, consider reusing NameLen
    .dFilePtr   dq ?  ;Keep of track of where in file we are
    .qRelocVal  dq ?  ;Used when computing relocations, Rebasing factor
endstruc

;MISC ASCII control chars
NUL equ 00h ;^@         | ASCII Null
ETX equ 03h ;^C         | ASCII Break (End of Text)
ACK equ 06h ;^F         | ASCII Acknowledgement
BEL equ 07h ;^G         | ASCII Bell
BSP equ 08h ;^H         | ASCII Backspace
TAB equ 09h ;^I         | ASCII Horizontal Tab
LF  equ 0Ah ;^J         | ASCII Line Feed
CR  equ 0Dh ;^M         | ASCII Carriage Return
DLE equ 10h ;^P         | ASCII Data Link End (Toggle Print Echo)
DC3 equ 13h ;^S         | ASCII Device Control 3 (Toggle Scroll Lock)
DC4 equ 14h ;^T         | ASCII Device Control 4
NAK equ 15h ;^U         | ASCII Negative Acknowledgement
CMD equ 16h ;^V         | EDLIN COMMAND CHAR
ETB equ 17h ;^W         | ASCII End of Transmission Block
EOF equ 1Ah ;^Z         | ASCII Substitute character (End of File)
ESC equ 1Bh ;           | ASCII Escape char, used for ANSI.SYS
SPC equ 20h ;Printable  | ASCII Space
;This last one is NEVER printed with a caret as it is a console control char
DEL equ 7Fh ;^?         | ASCII Rubout (Del char and dec cursor)

asciiCaret  equ 20h ;Used to check which chars need to be printed with caret
asciiMask   equ asciiCaret - 1  ;Turn into a bitmask

;Extended Ascii Codes
eF1     equ 3Bh ;F1 second byte
eF2     equ 3Ch ;F2 second byte
eF3     equ 3Dh ;F3 second byte
eF4     equ 3Eh ;F4 second byte
eF5     equ 3Fh ;F5 second byte
eF6     equ 40h ;F6 second byte
eF7     equ 41h ;F7 second byte
eCursL  equ 4Bh ;Cursor Left second byte
eCursR  equ 4Dh ;Cursor Right second byte
eIns    equ 52h ;Insert second byte
eDel    equ 53h ;DEL second byte (not necessarily delete key)