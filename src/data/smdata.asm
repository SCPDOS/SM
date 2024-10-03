
cmdStr      db "CMD="   ;String to search for in the environment
dfltShell   db "A:\COMMAND.COM",0 ;Default session shell string
dfltShell2  db "A:\DOS\COMMAND.COM",0    ;Str2 is str1 not present
cmdTail     db 10, "/P /E:2048",CR   ;Default command tail


;Static Error Strings 
bvStr       db "Error 0001: Invalid DOS Version.",CR,LF,"$"
noConStr    db "Error 0002: Invalid Console Driver",CR,LF,"$"
noScreenStr db "Error 0003: Not enough screens",CR,LF,"$"
noMemStr    db "Error 0004: Not enough memory to start Session Manager",CR,LF,"$"
noCmdStr    db "Error 0005: Default command interpreter not found",CR,LF,"$"
noExecStr   db "Error 0006: Unable to start up session",CR,LF,
            db "            It is recommended you restart your machine...",CR,LF,"$"

sesFrozStr  db CR,LF,"Session Frozen",CR,LF,"$"

;Shell Strings
newlineStr  db CR,LF,"$"
uline       db 80 dup ("-"),"$"
numSesStr   db "Number of sessions"
colonStr    db ": $"
sessStr     db "Current Sessions:",CR,LF,"$"
promptStr   db "Enter your desired session number...> $"
helpStr     db CR,LF,LF,"Strike ? to reset the screen",CR,LF,"$"
;Session default process names
waitStr     db "[Wait] $"
deadStr     db "[Exit] $"
sesManStr   db "[Run]  SCP/DOS Session Manager Shell$"
noNameStr   db        "SESSION SHELL (COMMAND.COM ?)$"
ttlStr      db 28 dup (SPC), "SCP/DOS Session Manager",CR,LF,LF,"$"