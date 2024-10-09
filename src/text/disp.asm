;------------------------------------------------------------
;All the DOSMGR dispatcher functions live here.
;------------------------------------------------------------


;------------------------------------------------------------
;               DevHelp routines.
;------------------------------------------------------------
;Used by multitasking drivers to communicate events to DOS.
devHlp:
;Dispatcher for devHlp.
;Function number passed in edx
    cmp edx, DevHlp_ConsInputFilter
    je consInputFilter  
    cmp edx, DevHlp_Signal_SM
    je swapSes      
    cmp edx, DevHlp_ProcBlock
    je procBlock    
    cmp edx, DevHlp_ProcRun
    je procRun      
    cmp edx, DevHlp_GetDOSVar
    je getDosVar    
    stc
    return
getDosVar:
;Currently only recognise one var, eax = 0, ebx = any, ecx = 1
;Returns the pointer to the var/array in rax
    test eax, eax
    jz .getScrnIo
.exitBad:
    stc
    return
.getScrnIo:
    cmp ecx, 1  ;Is the var length one?
    jne .exitBad
    lea rax, bScrnIoOk  ;Else return the pointer (and CF=NC!)
    return
consInputFilter:
;Checks if the char is to be added to the internal buffer or not!
;Currently only checks for the magic code for SM invokation.
;Input: ax=SC/ASCII char pair
;Output: ZF=NZ: char pair should be added to the internal buffer
;        ZF=ZE: char pair should NOT be added to the internal buffer
    cmp ax, magicCode   ;If the magic char, do not add to internal buffer
    retne
    ;Here if the magic code was encounted. Suggest we swap to screen 0
    pushfq
    cli 
    test byte [bSM_Req], -1 ;If its set, dont set again!
    jnz .exit
    mov byte [bSM_Req], -1  ;Set the bit
    mov byte [bSM_Req_Scr], 0   ;Suggest swapping to screen zero!
.exit:
    popfq
    return

swapSes:
    return

procBlock:
;Tells DOS to put this thread of execution for this task to sleep!
;Called with interrupts turned off.
;When called, use the following sequence:
; CLI
; while (condition)
;   prockBlock(eventId)
;Interrupts are turned off to prevent a race condition with procRun.
;
;Can only be called from a multitasking driver that declares itself so as
; these tasks don't enter the driver critical section.
    return
procRun:
    return