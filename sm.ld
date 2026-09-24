/*Linker script for DOS*/

alignment = __section_alignment__;
alignMask = alignment - 1;

loadAddress = (SIZEOF_HEADERS + alignMask) & ~alignMask;

SECTIONS {

    sm$text loadAddress : {
        ./bin/sm.obj(cseg)
    }

    sm$data ALIGN(alignment) : {
        ./bin/sm.obj(dseg)
    }

    .text : {
        /**/
    }

    sm$bss ALIGN(alignment) (NOLOAD) : {
        ./bin/sm.obj(bseg)
    }

    sm$stack ALIGN(alignment) (NOLOAD) : {
        ./bin/sm.obj(sseg$int)
        sm$intTOS = .;
        /*Put the interrupt stack lower than that shell stack!*/
        ./bin/sm.obj(sseg$shl)
        sm$shlTOS = .;
    }
}