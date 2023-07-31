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
;         "nasm Boot2.asm -f bin -o Boot2.bin"
;         "type Boot.bin Boot2.bin > Boot_1.bin"

; RUN     "qemu-system-x86_64 Boot_1.bin"
; RUN DBG "qemu-system-x86_64 -monitor stdio -d int -no-reboot Boot_1.bin"



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
