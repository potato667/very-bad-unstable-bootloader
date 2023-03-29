GDT; SPECIAL THANKS TO:
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
;         "type Boot.bin Kernel.bin > CruiseOS.bin"

; ASM & C "gcc -c Kernel_C.c -o Kernel_C.o -ffreestanding -nostdlib -fno-pie -fno-pic -m32"
;         "nasm Kernel_Entry.asm -f win32 -o Kernel_Entry.o"
;         "ld -T NUL -o kernel.tmp -Ttext 0x2000 Kernel_Entry.o Kernel_C.o"
;         "objcopy -O binary -j .text  kernel.tmp kernel_Full.bin"
;         "type Boot.bin kernel_Full.bin > CruiseOS_Copy.bin"

; RUN     "qemu-system-i386 CruiseOS.bin"
; RUN DBG "qemu-system-i386 -monitor stdio -d int -no-reboot CruiseOS.bin"

; BOOTLOADER FEATURES:-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]DRIVE CHECK-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]HANG ROUTINES-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]A20-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]GDT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]SECTOR INITIALIZATION-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]MULTI SECTORS-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]32 BIT PROTECTED MODE-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]64 BIT LONG MODE -> NOT NOW-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]OLD BIOS PATCHES=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]FAT 32 FILESYSTEM SUPPORT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]INITIALIZING THE RTC (REAL TIME CLOCK)=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]INITIALIZING INT 33h (THE MOUSE CURSOR)-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]IDT (INTERRUPT DESCRIPTOR TABLE)=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= <|FOR THE KERNEL
; [-]ISR (INTERRUPT SERVICE ROUTINE)-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= <|
; [-]IRQ (INTERRUPT REQUEST)-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= <|
; [-]VESA BIOS EXTENTIONS=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]RESOLUTION TO 1920*1080-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]MULTI-THREADING-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]MOVING TO THE KERNEL=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



[ORG 0x7C00] ;-=-=-=-=-=-=-=-=CODE LOCATION IE BOOTLOADERS START IN 0x7C00-=-=-=-=-=-=-=-=
BITS 16 ;-=-=-=-=-=-=-=-=-=-=-=THE CODE EXECUTED HERE IS 16 BIT CODE-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;-=-=-=-=-=-=-=-=-=-=CLEARING SEGMENT REGISTERS FOR PREDICTABLE VALUES-=-=-=-=-=-=-=-=-=-=
JMP 0:ENTRY ;-=-=-=-=-=-=-=-=-=-=-=-=CLEAR THE CS SEGMENT REGISTER-=-=-=-=-=-=-=-=-=-=-=-=
ENTRY:

XOR AX,                AX ;-+-=-=-=-=-=CLEAR THE OTHER SEGMENT REGISTER VALUES-=-=-=-=-=-=
MOV SS,                AX ;<|
MOV DS,                AX ;<|
MOV ES,                AX ;<|
MOV GS,                AX ;<|
MOV [BOOT_DRIVE],      DL ;-=-=-=-=-=-=-=-=SETTING THE BOOT DRIVE REGISTER-=-=-=-=-=-=-=-=
MOV SP,         SP_OFFSET ;-=-=-=-=-=-=SETTING UP THE BOOT PLACEMENT IN MEMORY-=-=-=-=-=-=
JMP             INIT_BOOT ;-=-=-=-=-=-=-=-=-=-=-=BOOTING STARTS HERE-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=DEFINED VARIABLES-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
KERNEL_OFFSET EQU  0x2000 ;-=KERNEL CODE PLACEMENT / POSITION IN MEMORY IE: [ORG 0x2000]-=
SP_OFFSET     EQU  0x7C00 ;-=-=-=BOOTLOADER CODE PLACEMENT IN MEMORY JUST LIKE ABOVE-=-=-=
ESP_OFFSET    EQU 0x90000 ;-=-=-=-=-=-=32BIT VERSION OF THE SP_OFFSET REGISTER-=-=-=-=-=-=
AMT_OF_SECTS  EQU       1 ;HOW MANY SECTORS HAVE BEEN INITIALIZED, EACH CONTAINS 512 BYTES
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-SUBROUTINES=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=HANG FUNCTION-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;-=-=-=-=-=-=LEAVE A DISCRIPTIVE MESSAGE OF WHAT THE ERROR IS AND IS CAUSED BY-=-=-=-=-=-=
HANG_ROUTINE:  CALL               OUTPUT
        HANG:  CLI
               HLT
               JMP                  HANG
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=PRINT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
OUTPUT:        MOV    AH,            0EH
.AGAIN:        LODSB
               CMP    AL,              0
               JE                  .EXIT
               INT                   10H
               JMP                .AGAIN
 .EXIT:        RET
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-BOOTLOADING=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;-=-=-=-=-=-=-=-=-=-=-=-STARTING BY SETTING UP THE NEEDED REGISTERS=-=-=-=-=-=-=-=-=-=-=-=
INIT_BOOT:     MOV    BX,   KERNEL_OFFSET ;-=-=-=-=-=-=-=-=BX: DESTINATION-=-=-=-=-=-=-=-=
               MOV    DH,    AMT_OF_SECTS ;-=-=-=-=-=-=-=-=DH: SECTOR NUMS-=-=-=-=-=-=-=-=
               MOV    DL,    [BOOT_DRIVE] ;-=-=-=-=-=-=-=-=DL:       DRIVE-=-=-=-=-=-=-=-=
               JMP             INIT_DRIVE ;-=-=-=-=-=TO START INITIALIZING DRIVE-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;-=-=-=-=-=-=-=-=-=-=-=-SETTING UP AND CHECKING THE DRIVE VARIABLES=-=-=-=-=-=-=-=-=-=-=-=
INIT_DRIVE:    PUSH                    DX
               MOV    AH,             02H
               MOV    AL,               1
               MOV    CL,             02H
               MOV    CH,             00H
               MOV    DH,             00H
               INT                    13H
               POP                     DX
               MOV    SI,        DISK_ERR
               JC            HANG_ROUTINE
               CMP    AL,              DH
               MOV    SI,        SECT_ERR
               JNE           HANG_ROUTINE
               JE               A20_CHECK
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;-=CHECKING AND ENABLING A20 FOR USING OVER 1MB, EVEN BYTES AND PROTECTED MODE (32 BITS)-=
A20_CHECK:     IN     AL,             92H
               TEST   AL,               2
               JNZ          BITS32_SWITCH
               OR     AL,               2
               AND    AL,            0FEH
               OUT   92H,              AL
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;-=-=-=-=-=-=-=-=-=INITIALIZING AND SWITCHING TO 32BITS (PROTECTED MODE)-=-=-=-=-=-=-=-=-=
BITS32_SWITCH: CLI
               LGDT           [GDT_TABLE] ;-=-=-=LOADING UP THE PREDEFINED GDT TABLE-=-=-=
               MOV   EAX,             CR0 ;-=-=-=-=-=-=-=-=-=-=-=???-=-=-=-=-=-=-=-=-=-=-=
               OR    EAX,              1H ;-=-=-=-=-=-=-=-=-=-=-=???-=-=-=-=-=-=-=-=-=-=-=
               MOV   CR0,             EAX ;-=-=-=-=-=-=-=-=-=-=-=???-=-=-=-=-=-=-=-=-=-=-=
               MOV    AX,              16 ;-+SETTING UP SEGMENT REGISTERS FOR 32BIT CODE-=
               MOV    DS,              AX ;<|
               MOV    SS,              AX ;<|
               MOV    ES,              AX ;<|
               MOV    FS,              AX ;<|
               MOV    GS,              AX ;<|
               JMP          8:INIT_32BITS ;=-=-=-=-=-=-=MOVING TO 32BIT CODE-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



BITS 32 ;-=-=-=-=-=-=-=-=-=-=-=THE CODE EXECUTED HERE IS 32 BIT CODE-=-=-=-=-=-=-=-=-=-=-=



;-=-=-=-=-=-=-=-=STARTING 32BITS (PROTECTED MODE) AND MOVING TO THE KERNEL-=-=-=-=-=-=-=-=
INIT_32BITS:   MOV   ESP,      ESP_OFFSET ;-=-=-=-=-=-=-=-=-=-=-=???-=-=-=-=-=-=-=-=-=-=-=
               JMP          KERNEL_OFFSET ;-=-=GIVING CONTROL AND MOVING TO THE KERNEL-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

BITS64_SWITCH: PUSHFD
               POP                    EAX
               MOV   ECX,             EAX
               XOR   EAX,           1<<21
               PUSH                   EAX
               POPFD
               PUSHFD
               POP                    EAX
               PUSH                   ECX
               POPFD
               XOR               EAX, ECX
               JZ                .NOCPUID
               RET
               MOV   EAX,       80000000H
               CPUID
               CMP   EAX,       80000001H
               JB             .NOLONGMODE
               MOV   EAX,       80000001H
               CPUID
               TEST  EDX,           1<<29
               JZ             .NOLONGMODE
               MOV   EAX,             CR0
               AND   EAX, 01111111111111111111111111111111B
               MOV   CR0,             EAX
               MOV   EDI,           1000H
               MOV   CR3,             EDI
               XOR   EAX,             EAX
               MOV   ECX,            4096
               REP   STOSD
               MOV   EDI,             CR3
               MOV   DWORD [EDI],   2003H
               ADD   EDI,           1000H
               MOV   DWORD [EDI],   3003H
               ADD   EDI,           1000H
               MOV   DWORD [EDI],   4003H
               ADD   EDI,           1000H
               MOV   EBX,       00000003H
               MOV   ECX,             512
.SET_ENTRY:    MOV   DWORD [EDI],     EBX
               ADD   EBX,           1000H
               ADD   EDI,               8
               LOOP            .SET_ENTRY
               MOV   EAX,             CR4
               OR    EAX,            1<<5
               MOV   CR4,             EAX
               MOV   EAX,              7H
               XOR   ECX,             ECX
               CPUID
               TEST  ECX,         (1<<16)
               JNZ        .5_LEVEL_PAGING
               MOV   EAX,             CR4
               OR    EAX,         (1<<12)
               MOV   CR4,             EAX
               MOV   ECX,       C0000080H
               RDMSR
               OR    EAX,            1<<8
               WRMSR
               MOV   EAX,             CR0
               OR    EAX,      1<<31|1<<0
               MOV   CR0,             EAX
               MOV   ECX,       C0000080H
               RDMSR
               OR    EAX,            1<<8
               WRMSR
               MOV   EAX,             CR0
               OR    EAX,           1<<31
               MOV   CR0,             EAX
               LGDT       [GDT.GDT64_PTR]
               JMP   GDT.CODE:INIT_64BITS

[BITS 64]

INIT_64BITS:   CLI
               MOV    AX,  GDT.GDT64_DATA
               MOV    DS,              AX
               MOV    ES,              AX
               MOV    FS,              AX
               MOV    GS,              AX
               MOV    SS,              AX
               MOV   EDI,          B8000H
               MOV   RAX, 1F201F201F201F20H
               MOV   ECX,             500
               REP                  STOSQ
               HLT

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=VARIABLES-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
BOOT_DRIVE     DB                       0
DISK_ERR       DB          'DISK_ERR ', 0
SECT_ERR       DB          'SECT_ERR ', 0

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=32BIT GDT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
GDT_START      DQ                       0
GDT_CODE       DW                  0FFFFH
               DW                       0
               DB                       0
               DB               10011010B
               DB               11001111B
               DB                       0
GDT_DATA       DW                  0FFFFH
               DW                       0
               DB                       0
               DB               10010010B
               DB               11001111B
               DB                       0
GDT_TABLE      DW GDT_END - GDT_START - 1
               DD               GDT_START
GDT_END        DB                       0

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=64BIT GDT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
GDT:
GDT64_NULL:    EQU                $ - GDT
               DQ                       0
GDT64_CODE:    EQU                $ - GDT
               DD                  0FFFFH
               DB                       0
               DB     1<<7|1<<4|1<<3|1<<4
               DB          1<<7|1<<5| 0FH
               DB                       0
GDT64_DATA:    EQU                $ - GDT
               DD                  0FFFFH
               DB                       0
               DB          1<<7|1<<4|1<<4
               DB          1<<7|1<<6| 0FH
               DB                       0
GDT64_TSS:     EQU                $ - GDT
               DD               00000068H
               DD               00CF8900H
GDT64_PTR:     DW             $ - GDT - 1
               DQ                     GDT
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=BOOTING ESSENTIAL-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
TIMES 510 - ($ - $$) DB 0 ;-=PAD OUT THE REST OF THE BOOTLOADER WITH 0'S UNTIL 510 BYTES-=
DW 0xAA55 ;-=-=-=-=-=-=-=A BIOS SIGNATURE TO SIGNAL THAT THIS IS A BOOT FILE-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
