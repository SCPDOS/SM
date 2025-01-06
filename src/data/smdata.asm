
cmdStr      db "CMD="   ;String to search for in the environment
dfltShell   db "A:\COMMAND.COM",0 ;Default session shell string
dfltShell2  db "A:\DOS\COMMAND.COM",0    ;Str2 is str1 not present
cmdTail     db 10, "/P /E:2048",CR   ;Default command tail, ensure an environment!


;Static Error Strings 
bvStr       db "Error 0001: Invalid DOS Version.",CR,LF,"$"
noConStr    db "Error 0002: Invalid Console Driver",CR,LF,"$"
noScreenStr db "Error 0003: Not enough screens",CR,LF,"$"
noMemStr    db "Error 0004: Not enough memory to start Session Manager",CR,LF,"$"
noCmdStr    db "Error 0005: Default command interpreter not found",CR,LF,"$"
noExecStr   db "Error 0006: Unable to start up session",CR,LF,
            db "            It is recommended you restart your machine...",CR,LF,"$"
noIOCTLStr  db "Error 0007: Generic IOCTL error",CR,LF,"$"
noStdinStr  db "Error 0008: STDIN Redirected from CON device",CR,LF,"$"
noStdoutStr db "Error 0009: STDOUT Redirected from CON device",CR,LF,"$"
alrInstStr  db "Error 0010: Session Manager already installed",CR,LF,"$"

sesFrozStr  db CR,LF,"Session Frozen",CR,LF,"$"

;Shell Strings
newlineStr  db CR,LF,"$"
uline       db 80 dup ("-"),"$"
sessStr     db 9 dup (SPC), "Current Sessions", 29 dup (SPC)
numSesStr   db "Number of sessions"
colonStr    db ": $"

promptStr   db "Enter your desired session number...> $"
helpStr     db CR,LF,LF,"Strike ? to reset the screen",CR,LF,"$"
;Session default process names
waitStr     db "[Wait] $"
deadStr     db "[Exit] $"
sesManStr   db "[Run]  SCP/DOS Session Manager Shell$"
noNameStr   db        "SESSION SHELL (COMMAND.COM ?)$"
ttlStr      db 28 dup (SPC), "SCP/DOS Session Manager",CR,LF,LF,"$"