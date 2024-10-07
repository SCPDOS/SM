/*Linker script for DOS*/

SECTIONS {
    .text : {

    }

    sm$text 0x0 : {
        ./bin/sm.obj(cseg)
    }

    sm$data BLOCK(16) : {
        ./bin/sm.obj(dseg)
    }

    sm$bss (NOLOAD) : {
        bseg_start = . ;
        ./bin/sm.obj(bseg)
        bseg_end = . ;
        bseg_len = bseg_end - bseg_start;
    }

    sm$stack (NOLOAD) : {
        ./bin/sm.obj(sseg$int)
        sm$intTOS = .;
        /*Put the interrupt stack lower than that shell stack!*/
        ./bin/sm.obj(sseg$shl)
        sm$shlTOS = .;
    }
}