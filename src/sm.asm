[DEFAULT REL]
BITS 64
%include "./src/inc/sm.inc"
%include "./src/inc/dosStruc.inc"
%include "./src/inc/dosMacro.mac"

Segment cseg code private align=16
%include "./src/text/init.asm"
%include "./src/text/disp.asm"
%include "./src/text/shell.asm"

Segment dseg data private align=16
%include "./src/data/smdata.asm"

Segment bseg bss public align=16
%include "./src/data/smbss.asm"

Segment sseg bss stack align=16
    dq 200h dup (?)  ;4K stack is fine
STACK_END: