; SPECIAL THANKS TO:
; IQON
; GOOGLE0101
; GLORIOUSCOW
; FOR ALL OF THEIR HELP AND SUPPORT!

; OS IN USE:
; -WINDOWS

; SOFTWARE NEEDED:
; -OBJCOPY
; -TYPE
; -QEMU
; -NASM
; -GCC
; -LD

; COMPILE "nasm Boot.asm -f bin -o Boot.bin"
;         "nasm Kernel.asm -f bin -o Kernel.bin"
;         "type Boot.bin Kernel.bin > OS.bin"

; ASM & C "gcc -c Kernel_C.c -o Kernel_C.o -ffreestanding -nostdlib -fno-pie -fno-pic -m32"
;         "nasm Kernel_Entry.asm -f win32 -o Kernel_Entry.o"
;         "ld -T NUL -o kernel.tmp -Ttext 0x4000 Kernel_Entry.o Kernel_C.o"
;         "objcopy -O binary -j .text  kernel.tmp kernel_Full.bin"
;         "type Boot.bin kernel_Full.bin > OS_Copy.bin"

; RUN     "qemu-system-x86_64 OS.bin"
; RUN DBG "qemu-system-x86_64 -monitor stdio -d int -no-reboot OS.bin"

; BOOTLOADER FEATURES:-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-PAGING, FILE SYSTEM AND VESA BIOS EXTENTIONS ARE LEFT FOR STAGE 2-=-=-=-=-=-=
; [X]DRIVE CHECK-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]HANG ROUTINES-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]A20-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]32BIT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]64BIT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]SECTOR INITIALIZATION-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]MULTI-SECTORS-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]OLD BIOS PATCHES=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]STAGE 2 BOOTLOADER=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]MOVING TO THE KERNEL=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



[ORG 0x7C00] ;=-=-=-=-=-=-=-=-CODE LOCATION IE BOOTLOADERS START IN 0x7C00-=-=-=-=-=-=-=-=
BITS 16 ;-=-=-=-=-=-=-=-=-=-=-=THE CODE EXECUTED HERE IS 16 BIT CODE-=-=-=-=-=-=-=-=-=-=-=

;-=-=-=-=-=-=-=-=-=-=CLEARING SEGMENT REGISTERS FOR PREDICTABLE VALUES-=-=-=-=-=-=-=-=-=-=
CLI ;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=CLEAR THE INTERRUPT VALUE-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
CLD ;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=CLEAR DIRECTION FLAGS-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

JMP 0:ENTRY ;-=-=-=-=-=-=-=-=-=-=-=-=CLEAR THE CS SEGMENT REGISTER-=-=-=-=-=-=-=-=-=-=-=-=
ENTRY:

XOR AX,                AX ;-=-=-=-=-=-=CLEAR THE OTHER SEGMENT REGISTER VALUES-=-=-=-=-=-=
MOV SS,                AX ;<|
MOV DS,                AX ;<|
MOV ES,                AX ;<|
MOV GS,                AX ;<|
MOV [BOOT_DRIVE],      DL ;-=-=-=-=-=-=-=-=SETTING THE BOOT DRIVE REGISTER-=-=-=-=-=-=-=-=
MOV SP,         SP_OFFSET ;-=-=-=-=-=-=-=SETTING UP THE STACK POINTER OFFSET-=-=-=-=-=-=-=
JMP         STAGE2_OFFSET ;-=-=-=-=-=-=-=-=-=-=-=BOOTING STARTS HERE-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-DEFINED VARIABLES-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
STAGE2_OFFSET EQU  0x2000 ;-=KERNEL CODE PLACEMENT / POSITION IN MEMORY IE: [ORG 0x2000]-=
SP_OFFSET     EQU  0x7C00 ;-=-=-=-=-=-=-STACK POINTER OFFSET (START POSITION)=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-BOOTING ESSENTIAL-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
TIMES 510 - ($ - $$) DB 0 ;-=PAD OUT THE REST OF THE BOOTLOADER WITH 0'S UNTIL 510 BYTES-=
DW 0xAA55 ;=-=-=-=-=-=-=-A BIOS SIGNATURE TO SIGNAL THAT THIS IS A BOOT FILE-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
