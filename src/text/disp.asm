;------------------------------------------------------------
;All the DOSMGR dispatcher functions live here.
;------------------------------------------------------------


;------------------------------------------------------------
;               DevHelp routines.
;------------------------------------------------------------
;Used by a corresponding CON driver to communicate events
; to the DOS manager.
DosSesHlp:
;Dispatcher for signals from MCON.
;These signals will change to correspond to the multitasking values in edx
    cmp eax, 1
    je swapSes      ;Signal_SM
    cmp eax, 2
    je procBlock    ;ProcBlock
    cmp eax, 3
    je procRun      ;ProcRun
    stc
    return
swapSes:
;We have been told that the magic key has been hit! Swap session unless we 
; are already in SM session.
;Entered with interrupts turned off.
    cmp dword [dCurTask], SM_SESSION    ;Don't swap session if in Session Manager.
    rete    
;We now check if we are in a lock. If we are in a lock, we defer the 
; swapping to SM until we leave all locks. 
    test dword [sesLock + critLock.dCount], -1  ;If the count is 0, proceed!
    jz gotoShell
    mov byte [bDefFlg], -1  ;Else, we set the deferred flag.
    return  ; and return to the busy session.

procBlock:
;Called with interrupts turned off. Tells DOS to put this task to sleep!
;Frees any locks associated to this task, but notes the 
    return
procRun:
    return