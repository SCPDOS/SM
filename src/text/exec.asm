;This file contains all the exec extensions. It contains the callback for 
; registering tasks using DOS to do the EXE unpacking.

launchTask:
;Entered whilst in 21h/4Bh EXEC. We use this to create a PCB and 
; the first PDTA for this process. 
;On entry: rbp -> The EXEC frame
;       If bSubFunc = 4 (bg task):
;           ecx = mode of termination
;               = 00 -> Upon terminating, leave task in Zombie mode
;                       awaiting for a task to read it's return code
;               = 01 -> Upon terminating, discard all resources allocated
;                       to the task.
;               > 01 -> Error code, unknown function (01h).
;On return: CF=NC: PCB and PDTA set up.
;           CF=CY: Cancel setup (error code in already setup in DOS and eax)
; In the event an error occurs, we need to reverse the global DOS state 
; modifications made by our call in DOS to createPSP. This means change 
; currentPSP in the SDA and Int 22h/23h/24h. Set currentDTA to default PSP + 80h.
; We define some additional error codes such as NO_MORE_PDTA_SLOTS.

    return

terminateTask:
    return