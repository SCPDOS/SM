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
    je signalSM      
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
    ;Here if the magic code was encounted.
    push rax
    xor eax, eax    ;Magic code requests a swap to screen zero!
    call signalSM
    pop rax
    return

signalSM:
;Entered with al = Suggested screen number. If bigger than maxsesindex, error!
;Passes the data to the SM "reciever" handler and then preempts by setting SM
; thread 0 to standby. We need to keep a pointer to this thread PTDA
    push rax
    movzx eax, al
    cmp dword [dMaxSesIndx], eax
    pop rax
    retb    ;Exit with Carry Set!
    pushfq
    cli 
    test byte [bSM_Req], -1 ;If its set, dont set again!
    jnz .exit
    mov byte [bSM_Req], -1  ;Set the bit
    mov byte [bSM_Req_Scr], al   ;Suggest swapping to screen zero!
.exit:
    popfq
    return