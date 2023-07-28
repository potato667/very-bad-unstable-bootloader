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
; [X]DRIVE CHECK-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]HANG ROUTINES-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]A20-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]GDT32-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]GDT64-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]SECTOR INITIALIZATION-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]MULTI-SECTORS-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]32 BIT PROTECTED MODE-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]64 BITS LONG MODE-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]OLD BIOS PATCHES=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]FAT 32 FILESYSTEM SUPPORT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]INITIALIZING THE MOUSE CURSOR-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]VESA BIOS EXTENTIONS=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]CHANGE THE SCREEN RESOLUTION TO 1920*1080-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
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
.EXIT:         RET
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
               LGDT           [GDT32_TABLE] ;-=-=-=LOADING UP THE PREDEFINED GDT TABLE-=-=-=
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



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-SUBROUTINES=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;-=-=-=-=-=-=LEAVE A DISCRIPTIVE MESSAGE OF WHAT THE ERROR IS AND IS CAUSED BY-=-=-=-=-=-=
HANG_ROUTINE32:CALL             OUTPUT32
        HANG32:HLT
               JMP                HANG32
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=PRINT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
OUTPUT32:      MOV   EDI,      [0xB8000]
.AGAIN:        LODSB
               OR     AL,             AL
               JZ                  .EXIT
               MOV    AH,              3
               STOSW
               JMP                .AGAIN
.EXIT:         MOV [0xB8000],        EDI
               RET



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-BOOTLOADING=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=START 32BITS (PROTECTED MODE)-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
INIT_32BITS:   MOV   ESP,      ESP_OFFSET
               LGDT         [GDT64_TABLE]
               PUSHFD ; CPUID CHECK START
               POP                    EAX
               MOV   ECX,             EAX
               XOR   EAX,           1<<21
               PUSH                   EAX
               POPFD
               PUSHFD
               POP                    EAX
               PUSH                   ECX
               POPFD
               XOR   EAX,             ECX
               MOV    SI,        NO_CPUID
               JZ          HANG_ROUTINE32 ; CPUID CHECK END
               MOV   EAX,       80000000H ; LONG MODE AVAILABILITY CHECK START
               CPUID
               CMP   EAX,       80000001H
               MOV    SI,        NO_64BIT
               JB          HANG_ROUTINE32 ; LONG MODE AVAILABILITY CHECK END
               MOV   EAX,       80000001H ; DETECT LONG MODE START
               CPUID
               TEST  EDX,           1<<29
               JZ          HANG_ROUTINE32 ; DETECT LONG MODE END
               MOV   EAX,             CR0 ; DISABLE OLD PAGING START
               AND   EAX, 01111111111111111111111111111111B
               MOV   CR0,             EAX ; DISABLE OLD PAGING END
               MOV   EDI,          0x1000 ; CLEAR PAGING TABLES START
               MOV   CR3,             EDI
               XOR   EAX,             EAX
               MOV   ECX,            4096
               REP                  STOSD
               MOV   EDI,             CR3 ; CLEAR PAGING TABLES END
               MOV DWORD [EDI],    0x2003
               ADD   EDI,          0x1000
               MOV DWORD [EDI],    0x3003
               ADD   EDI,          0x1000
               MOV DWORD [EDI],    0x4003
               ADD   EDI,          0x1000
               MOV   EBX,      0x00000003
               MOV   ECX,             512
    .SET_ENTRY:MOV DWORD [EDI],       EBX
               ADD   EBX,          0x1000
               ADD   EDI,               8
               LOOP            .SET_ENTRY
               MOV   EAX,             CR4
               OR    EAX,            1<<5
               MOV   CR4,             EAX
               ; FUTURE OF X86_64 THE PML5 (NOT IMPLEMENTED YET)
               MOV   ECX,      0xC0000080
               RDMSR
               OR    EAX,            1<<8
               WRMSR
               MOV   EAX,             CR0
               OR    EAX,           1<<31
               JMP         HANG_ROUTINE32 ; <---- DEBUG
               MOV   CR0,             EAX ; <---- TRIPLE FAULT
               JMP GDT64_CODE:INIT_64BITS ;-=-=-=-=-=-=-=MOVE TO 64BITS CODE-=-=-=-=-=-=-=
                           ;^TRIPLE FAULT
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-SUBROUTINES=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



BITS 64 ;-=-=-=-=-=-=-=-=-=-=-=THE CODE EXECUTED HERE IS 64 BIT CODE-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-SUBROUTINES=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;-=-=-=-=-=-=LEAVE A DISCRIPTIVE MESSAGE OF WHAT THE ERROR IS AND IS CAUSED BY-=-=-=-=-=-=
HANG_ROUTINE64:CALL             OUTPUT64
        HANG64:HLT
               JMP                HANG64
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=PRINT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
OUTPUT64:      MOV   EDI,      [0xB8000]
.AGAIN:        LODSB
               OR     AL,             AL
               JZ                  .EXIT
               MOV    AH,              3
               STOSW
               JMP                .AGAIN
.EXIT:         MOV [0xB8000],        EDI
               RET
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-BOOTLOADING=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;-=-=-=-=-=-=-=-=-=-=START 64BITS (LONG MODE) AND MOVING TO THE KERNEL-=-=-=-=-=-=-=-=-=-=
INIT_64BITS:   ;MOV    AX,      GDT64_DATA
               ;MOV    DS,              AX
               ;MOV    ES,              AX
               ;MOV    FS,              AX
               ;MOV    GS,              AX
               ;MOV    SS,              AX
               ;MOV   EDI,         0xB8000
               ;MOV   RAX, 0x1F201F201F201F20
               ;MOV   ECX,             500
               ;REP                  STOSQ
              ;MOV    SI,        NO_64BIT
               JMP          KERNEL_OFFSET ;-=-=GIVING CONTROL AND MOVING TO THE KERNEL-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=VARIABLES-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



BOOT_DRIVE     DB                       0
DISK_ERR       DB          'DISK_ERR ', 0
SECT_ERR       DB          'SECT_ERR ', 0
NO_CPUID       DB          'NO_CPUID ', 0
NO_64BIT       DB          'NO_64BIT ', 0

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=32BIT GDT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
GDT32_START    DQ                       0
GDT32_CODE     DW                0FFFFH,0
               DB 0,10011010B,11001111B,0
GDT32_DATA     DW                0FFFFH,0
               DB 0,10010010B,11001111B,0
GDT32_TABLE    DW     $ - GDT32_START - 1
               DD             GDT32_START
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=64BIT GDT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
GDT64_START    DQ                       0
GDT64_CODE     DD                       0
               DB 0,10011000B,00100000B,0
GDT64_DATA     DD                       0
               DB 0,10010000B,00000000B,0
GDT64_TABLE    DW     $ - GDT64_START - 1
               DD             GDT64_START
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=BOOTING ESSENTIAL-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
TIMES 510 - ($ - $$) DB 0 ;-=PAD OUT THE REST OF THE BOOTLOADER WITH 0'S UNTIL 510 BYTES-=
DW 0xAA55 ;-=-=-=-=-=-=-=A BIOS SIGNATURE TO SIGNAL THAT THIS IS A BOOT FILE-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

