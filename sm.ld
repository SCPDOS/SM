/*Linker script for DOS*/

/*Order of module linkage: TOP -> OEMINIT -> SYSINIT -> DOS -> Drivers -> EOF*/


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
        ./bin/sm.obj(sseg)
    }
}