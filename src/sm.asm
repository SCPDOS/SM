[DEFAULT REL]
BITS 64
%include "./src/inc/sm.inc"
%include "./src/inc/dosStruc.inc"
%include "./src/inc/drvStruc.inc"
%include "./src/inc/dosMacro.mac"

Segment cseg code private align=16
%include "./src/text/init.asm"
%include "./src/text/disp.asm"
%include "./src/text/int.asm"
%include "./src/text/switch.asm"
%include "./src/text/util.asm"
%include "./src/text/shell.asm"

Segment dseg data private align=16
%include "./src/data/smdata.asm"

Segment bseg bss public align=16
%include "./src/data/smbss.asm"

Segment sseg$int bss stack align=16
;This is the interrupt handlers' default stack. Only used during 
; session swaps so it is ok (Interrupts are off).
    dq 20h dup (?)   ;32 qword stack is fine for this!
Segment sseg$shl bss stack align=16
    dq 200h dup (?)  ;Total 4K stack is fine
