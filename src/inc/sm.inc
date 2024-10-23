;Structures and equates for DOSMGR

SM_SESSION  equ 0       ;Session number for Session Manager
MAX_TASK    equ 32      ;Maximum of 32 tasks (0-31)
MAX_SCHED   equ 31      ;Maximum Schedule number (31)
NUM_SCHED   equ MAX_SCHED + 1   ;Number of schedules

;Critical Lock
struc critLock
    .dCount     dd ?    ;When this is zero, the lock is free
    .pOwnerPcb  dq ?    ;Ptr to the owner of the lock!
endstruc

;System Object Table header
struc soth  
    .pNextSoth  dq ?    ;Ptr to the next soth (-1 means end of chain)
    .dNumEntry  dd ?    ;Number of entries in this SOTH
    .wObjType   dw ?    ;Type of object stored in the table
    .wObjectSz  dw ?    ;Size of the objects stored in this table
endstruc

OBJ_HDL     equ 0   ;A handle table header
OBJ_PCB     equ 1   ;A PCB table header
OBJ_PTDA    equ 2   ;A PTDA table header

;Schedule head, no lock as in a multiprocessor system we have a schedule
; block per processor and don't share threads (for simplicity, for now).
; We can introduce an atomic xfer system later.
struc schedHead
    .dNumEntry  dd ?    ;Number of entries in this schedule
    .pSchedHead dq ?    ;Ptr to next ptda in schedule to be executed
    .pSchedTail dq ?    ;Ptr to last ptda in schedule
endstruc



;Per-task (thread) data area, keeps task (thread) state, including the 
; entries modified by the scheduler!
struc ptda 
;The following variable IS ONLY touched by the scheduler.
;It is meaningless w/o a schedule lock!
    .pNSchdPtda dq ?   ;Points to the next ptda in the schedule
;Here begins the actual PTDA.
    .pPcb       dq ?    ;Ptr to the owning pcb (process)
    .pNProcPtda dq ?    ;Ptr to the next ptda owned by the process
    .bState     db ?    ;State of the thread
;Sleep and Blocking States
    .bSleepStat db ?    ;If set, sleep can be interrupted
    .pNSlepPtda dq ?    ;Ptr to the next ptda in the sleep chain
    .dSleepLen  dd ?    ;Sleep length in ~ms, 0 mean indefinite
    .dAwakeCode dd ?    ;Non-zero codes indicating why task was woken up
    .qEventId   dq ?    ;ID to check for block/run calls.
;Register storage
    .qRSP       dq ?    ;RSP on task switch
    .sRegsTbl   dq 16 dup (?)   ;Register storage location
    .boS:
    ;alignb 16
    ;.pFPUState  dq 512 dup (?)  ;Extended state storage
;Per-process DOS state
    .sdaCopy:           ;Copy of the DOS sda for this session when not active
endstruc

;Thread awakening states. Used to indicate why a thread was brought out of 
; waiting to a standby/ready state
AWAKE_NORMAL        equ 0   ;Normal task awake code
AWAKE_TIMEOUT       equ 1   ;Task was awoken by timeout
AWAKE_INTER         equ 2   ;Task was interrupted
AWAKE_STARVING      equ 3   ;Awoken by scheduler because system was starving

;Thread states
THREAD_INIT         equ 0   ;When we allocate the thread block.
;When we allocate a thread block, we clear the struct to zero hence this value
THREAD_READY        equ 1   ;Ready to run on current h/w thread.
;A thread in this state is in the ready queue for the selected priority for 
; the selected hw thread.
THREAD_RUNNING      equ 2   ;Currently running thread!
THREAD_STANDBY      equ 3   ;Next thread to run on a particular hw thrd
;Threads in STANDBY can be preempted by higher priority thread if one 
; becomes available. If this is the case the thread is returned back to ready
; and the next "second to run" thread is set to standby.
THREAD_TERMINATED   equ 4   ;Set if thread awaits reaping (a CWAIT call).
THREAD_WAITING      equ 5   ;Contains specific informaing in wait fields
;When a thread is blocked due to devblk or sleep this is the state the 
; thread is stored in. More info is set in the waiting metadata field.
THREAD_TRANSITION   equ 6   ;NOT USED, waiting for Stack to be paged in
THREAD_DEF_READY    equ 7   ;Ready to run, need to allocate to h/w thread
;Deferred ready processes are waiting to be allocated to a hw thread.
; Once a process is ready w/o a hw thread this gets set and then we 
; select a hw thread to run on. Currently there is only one. Thus this
; will only ever be seen when a process is coming out of INIT.
THREAD_GATE_WAITING equ 8   ;Waiting on a special kernel object (Crit 1/2)
;Needed to indicate that we are not in a normal wait and that this thread
; is to wait until a kernel lock is freed.

;Process control block, keeps full process state.
;Must be aligned in size to 16 bytes.
struc pcb  
    .bPcbInUse  db ?    ;Set if this PCB is allocated
;Process metadata
    .hPcb       dd ?    ;Hdl to this pcb
    .hParPcb    dd ?    ;Handle to the parent pcb
    .dCsid      dd ?    ;CSID of this task chain (id of root program)
    .hScrnNum   dd ?    ;Handle to the session (byte number of the screen)
    .wFlags     dw ?    ;Process flags
;PTDA block, refers to PTDA 0 for this process
    alignb 10h
    .sPtda      db ptda_size dup (?) ;Thread 0's PTDA
;Interrupt handles for replacing on task swap
    .pInt22h    dq ?    ;Int 22h handler on task switch
    .pInt23h    dq ?    ;Int 23h handler on task switch
    .pInt24h    dq ?    ;Int 24h handler on task switch
    .pInt2Eh    dq ?    ;Int 2Eh handler on task switch (for master CMD)
endstruc


;Communication packet with MCON

struc mScrCap  
    .wVer       dw ?    ;Upper byte, Major num (1). Lower byte, minor num (0)
    .wLen       dw ?    ;Length of structure (13 bytes)
    .bScrNum    db ?    ;Number of screens supported by driver
    .pDevHlp    dq ?    ;Pointer to the devHlp help routine
endstruc

magicCode equ 7100h ;Scancode/ASCII code of ALT+F10

DevHlp_ConsInputFilter  equ 5
DevHlp_Signal_SM        equ 7
DevHlp_ProcBlock        equ 9
DevHlp_ProcRun          equ 10
DevHlp_GetDOSVar        equ 16


;BIOS Equates go here
EOI         equ 20h
pic1cmd     equ 20h

PITbase     equ 40h
PIT0        equ PITbase
PIT1        equ PITbase + 1
PIT2        equ PITbase + 2
PITcmd      equ PITbase + 3

timerInt    equ 0F0h    ;Change if we change this in BIOS!!