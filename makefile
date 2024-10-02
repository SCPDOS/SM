#!/bin/sh

ASM     := nasm
BINUTIL := x86_64-w64-mingw32
LINKER  := ${BINUTIL}-ld 
OBJCOPY := ${BINUTIL}-objcopy

LD_FLAGS := -T ./sm.ld --entry=ep --no-check-sections --section-alignment=0x10 --file-alignment=0x10 --image-base=0x0 -Map=./lst/sm.map


all:
	$(MAKE) assemble
	$(MAKE) link
	$(MAKE) clean

assemble:
	${ASM} ./src/sm.asm -o ./bin/sm.obj -f win64 -l ./lst/sm.lst -O0v

link:
	${LINKER} ${LD_FLAGS} -o ./bin/sm.exe

clean:
	rm ./bin/*.obj 