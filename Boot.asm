; SPECIAL THANKS TO:
; IQON
; GOOGLE0101
; GLORIOUSCOW
; FOR ALL OF THEIR HELP AND SUPPORT!

; SOFTWARE NEEDED:
; -QEMU
; -NASM
; -GCC

; COMPILE "nasm Boot.asm -f bin -o Boot.bin"
;         "nasm Kernel.asm -f bin -o Kernel.bin"
;         "type Boot.bin Kernel.bin > CruiseOS.bin"

; ASM & C "gcc -c Kernel_C.c -o Kernel_C.o -ffreestanding -no-stdlib -fno-pie -fno-pic -m32"
;         "nasm Kernel_Entry.asm -o Kernel_Entry.o"
;         "ld Kernel_C.o Kernel_Entry.o -o Kernel_C_Full.o -melf_i386" ; REMEMBER TO SET THE KERNEL LOCATION IN HERE
;         "objcopy -O binary Kernel_C_Full.elf Kernel_C_Full.bin"

; RUN     "qemu-system-i386 CruiseOS.bin"
; RUN DBG "qemu-system-i386 -monitor stdio -d int -no-reboot CruiseOS.bin"

; BOOTLOADER FEATURES:-=-=-=-=-=-=-=-=-=-=-=-=
; [X]DRIVE CHECK-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]HANG ROUTINES-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]A20-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]GDT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]32 BIT PROTECTED MODE-=-=-=-=-=-=-=-=-=-=
; [-]64 BIT LONG MODE -> NOT NOW-=-=-=-=-=-=-=
; [-]OLD BIOS PATCHES=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]FAT 32 FILESYSTEM SUPPORT-=-=-=-=-=-=-=-=
; [-]INITIALIZING THE RTC (REAL TIME CLOCK)=-=
; [-]INITIALIZING INT 33h (THE MOUSE CURSOR)-=
; [-]IDT (INTERRUPT DESCRIPTOR TABLE)=-=-=-=-=
; [-]ISR (INTERRUPT SERVICE ROUTINE)-=-=-=-=-=
; [-]VESA BIOS EXTENTIONS=-=-=-=-=-=-=-=-=-=-=
; [-]RESOLUTION TO 1920*1080-=-=-=-=-=-=-=-=-=
; [-]MULTI-THREADING-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]KERNEL ABI (APPLICATION BINARY INTERFACE)
; [X]MOVING TO THE KERNEL=-=-=-=-=-=-=-=-=-=-=

[ORG 0x7C00];-=-=-=-=-=-=-=-=CODE LOCATION IE: BOOTLOADERS START IN 0x7C00-=-=-=-=-=-=-=-=
BITS 16;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;-=-=-=-=-=-=-=-=-=-=CLEAR CS SEGMENT REGISTER FOR A PREDICTABLE VALUE-=-=-=-=-=-=-=-=-=-=
JMP 0:ENTRY
ENTRY:

KERNEL_OFFSET EQU  0x2000 ;-=KERNEL CODE PLACEMENT / POSITION IN MEMORY IE: [ORG 0x2000]-=
SP_OFFSET     EQU  0x7C00 ;-=-=-=BOOTLOADER CODE PLACEMENT IN MEMORY JUST LIKE ABOVE-=-=-=
ESP_OFFSET    EQU 0x90000 ;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=???-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
AMT_OF_SECTS  EQU       1 ;HOW MANY SECTORS HAVE BEEN INITIALIZED, EACH CONTAINS 512 BYTES

;-=-=-=-=-=-=-=CLEAR THE OTHER LEFT SEGMENT REGISTERS FOR PREDICTABLE VALUES-=-=-=-=-=-=-=
XOR AX,                AX
MOV SS,                AX
MOV DS,                AX
MOV ES,                AX
MOV GS,                AX
MOV [BOOT_DRIVE],      DL
MOV SP,         SP_OFFSET

JMP             INIT_BOOT

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=HANG FUNCTION-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;-=-=-=-=-=-=LEAVE A DISCRIPTIVE MESSAGE OF WHAT THE ERROR IS AND IS CAUSED BY-=-=-=-=-=-=
HANG_ROUTINE:  CALL               OUTPUT
        HANG:  CLI
               HLT
               JMP                  HANG

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=PRINT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
OUTPUT:        MOV   AH,             0EH
.AGAIN:        LODSB
               CMP   AL,               0
               JE                  .EXIT
               INT                   10H
               JMP                .AGAIN
 .EXIT:        RET

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-BOOTLOADING=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;-=-=-=-=-=-=-=-=-=-=-=-STARTING BY SETTING UP THE NEEDED REGISTERS=-=-=-=-=-=-=-=-=-=-=-=
INIT_BOOT:     MOV   BX,    KERNEL_OFFSET ;-=-=-=-=-=-=-=-=BX: DESTINATION-=-=-=-=-=-=-=-=
               MOV   DH,     AMT_OF_SECTS ;-=-=-=-=-=-=-=-=DH: SECTOR NUMS-=-=-=-=-=-=-=-=
               MOV   DL,     [BOOT_DRIVE] ;-=-=-=-=-=-=-=-=DL:    DRIVE   -=-=-=-=-=-=-=-=
               JMP             INIT_DRIVE

;-=-=-=-=-=-=-=-=-=-=-=-SETTING UP AND CHECKING THE DRIVE VARIABLES=-=-=-=-=-=-=-=-=-=-=-=
INIT_DRIVE:    PUSH  DX
               MOV   AH,              02H
               MOV   AL,                1
               MOV   CL,              02H
               MOV   CH,              00H
               MOV   DH,              00H
               INT                    13H
               POP                     DX
               MOV   SI,         DISK_ERR
               JC            HANG_ROUTINE
               CMP   AL,               DH
               MOV   SI,         SECT_ERR
               JNE           HANG_ROUTINE
               JMP              A20_CHECK

;-=CHECKING AND ENABLING A20 FOR USING OVER 1MB, EVEN BYTES AND PROTECTED MODE (32 BITS)-=
A20_CHECK:     IN    AL,              92H
               TEST  AL,                2
               JNZ          BITS32_SWITCH
               OR    AL,                2
               AND   AL,             0xFE
               OUT  92H,               AL

;-=-=-=-=-=-=-=-=-=INITIALIZING AND SWITCHING TO 32BITS (PROTECTED MODE)-=-=-=-=-=-=-=-=-=
BITS32_SWITCH: CLI
               LGDT           [GDT_TABLE];-=-=-=-=LOADING THE PREDEFINED GDT TABLE-=-=-=-=
               MOV   EAX,             CR0
               OR    EAX,              1H
               MOV   CR0,             EAX
               MOV    AX,              16
               MOV    DS,              AX
               MOV    SS,              AX
               MOV    ES,              AX
               MOV    FS,              AX
               MOV    GS,              AX
               JMP          8:INIT_32BITS;-=-=-=-=-=-=-=MOVING TO 32BIT CODE-=-=-=-=-=-=-=

BITS 32;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;-=-=-=-=-=-=-=-=STARTING 32BITS (PROTECTED MODE) AND MOVING TO THE KERNEL-=-=-=-=-=-=-=-=
INIT_32BITS:   MOV   ESP,      ESP_OFFSET;-=-=-=-=-=-=-=-=-=-=-=????-=-=-=-=-=-=-=-=-=-=-=
               JMP          KERNEL_OFFSET;-=-=GIVING CONTROL THEN MOVING TO THE KERNEL-=-=

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=VARIABLES-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
BOOT_DRIVE     DB                       0
DISK_ERR       DB          'DISK_ERR ', 0
SECT_ERR       DB          'SECT_ERR ', 0
A20_STATE_OFF  DB           'A20_OFF ', 0
BOOT_ERR       DB          'BOOT_ERR ', 0
GDT_START      DQ                      0H
GDT_CODE       DW                  0xFFFF
               DW                      0H
               DB                      0H
               DB               10011010B
               DB               11001111B
               DB                      0H
GDT_DATA       DW                  0xFFFF
               DW                      0H
               DB                      0H
               DB               10010010B
               DB               11001111B
               DB                      0H
GDT_TABLE      DW GDT_END - GDT_START - 1
               DD               GDT_START
GDT_END        DB                       0

;-=-=-=PAD OUT THE REST OF THE BOOTLOADER MEMORY WITH 0'S UNTIL 510 BYTES ARE FILLED-=-=-=
TIMES 510 - ($ - $$) DB 0
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=BOOT SIGN-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
DW 0xAA55
