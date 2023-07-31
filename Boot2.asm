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

; ASM & C "gcc -c Boot_C.c -o Boot_C.o -ffreestanding -nostdlib -fno-pie -fno-pic -m32"
;         "nasm Boot_Entry.asm -f win32 -o Boot_Entry.o"
;         "ld -T NUL -o Boot.tmp -Ttext 0x20000 Boot_Entry.o Boot_C.o"
;         "objcopy -O binary -j .text  Boot.tmp Boot_Full.bin"
;         "type Boot_1.bin Boot_Full.bin > Boot_2.bin"

; RUN     "qemu-system-x86_64 CruiseOS.bin"
; RUN DBG "qemu-system-x86_64 -monitor stdio -d int -no-reboot CruiseOS.bin"

; BOOTLOADER FEATURES:-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]DRIVE CHECK-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]HANG ROUTINES-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]A20-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]32BIT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]64BIT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]SECTOR INITIALIZATION-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]MULTI-SECTORS-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [X]OLD BIOS PATCHES=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]PAGING=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]FILE SYSTEM-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]VESA BIOS EXTENTIONS=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; [-]STAGE 3 BOOTLOADER=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



[ORG 0x7C00] ;=-=-=-=-=-=-=-=-CODE LOCATION IE BOOTLOADERS START IN 0x7C00-=-=-=-=-=-=-=-=
BITS 16 ;-=-=-=-=-=-=-=-=-=-=-=THE CODE EXECUTED HERE IS 16 BIT CODE-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-DEFINED VARIABLES-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
STAGE3_OFFSET EQU 0x20000 ;-=-=-=CODE PLACEMENT / POSITION IN MEMORY IE:[ORG 0x2000]-=-=-=
ESP_OFFSET    EQU 0x90000 ;-=-=-=-=-=-=32BIT VERSION OF THE SP_OFFSET REGISTER-=-=-=-=-=-=
AMT_OF_SECTS  EQU       1 ;HOW MANY SECTORS HAVE BEEN INITIALIZED, EACH CONTAINS 512 BYTES
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=SUBROUTINES=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-HANG FUNCTION-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-LEAVE A DISCRIPTIVE MESSAGE OF WHAT THE ERROR IS AND IS CAUSED BY-=-=-=-=-=-=
HANG_ROUTINE:  CALL               OUTPUT ;-=-=-=-=OUTPUT TEXT FROM THE SI REGISTER-=-=-=-=
        HANG:  CLI                       ;-=-=-=-=-=-=-=-=CLEAR INTERRUPTS-=-=-=-=-=-=-=-=
               HLT                       ;-=-=-=-=-=-=-=-=-HALT PROCESSOR=-=-=-=-=-=-=-=-=
               JMP                  HANG ;-RESTART THE ROUTINE IF AN INTERRUPT IS STARTED=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-PRINT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
OUTPUT:        MOV    AH,            0EH ;-=-=-=-=-=-=SET AH TO SPECIFY OUTPUT-=-=-=-=-=-=
.AGAIN:        LODSB                     ;-=-=-=-=-=INCREMENTING THE SI REGISTER-=-=-=-=-=
               CMP    AL,              0 ;-=-=-=-=-=ARE THERE ZERO LETTERS LEFT?-=-=-=-=-=
               JE                  .EXIT ;-=-=-=-=-=-=IF YES, EXIT THE ROUTINE-=-=-=-=-=-=
               INT                   10H ;-=-=-=IF NO, THEN PRINT THE CURRENT LETTER-=-=-=
               JMP                .AGAIN ;-=-=-=-=-=-=REPEAT THE ROUTINE AGAIN-=-=-=-=-=-=
.EXIT:         RET                       ;-=-=-=-RETURN TO THE FUNCTION THAT CALLED=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=BOOTLOADING=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-=-=STARTING BY SETTING UP THE NEEDED REGISTERS=-=-=-=-=-=-=-=-=-=-=-=
INIT_BOOT:     MOV    BX,   KERNEL_OFFSET ;-=-=-=-=-=-=-=-=BX: DESTINATION-=-=-=-=-=-=-=-=
               MOV    DH,    AMT_OF_SECTS ;-=-=-=-=-=-=-=-=DH: SECTOR NUMS-=-=-=-=-=-=-=-=
               MOV    DL,    [BOOT_DRIVE] ;-=-=-=-=-=-=-=-=DL:       DRIVE-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=SETTING UP AND CHECKING THE DRIVE VARIABLES=-=-=-=-=-=-=-=-=-=-=-=
               PUSH                    DX
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
;=-CHECKING AND ENABLING A20 FOR USING OVER 1MB, EVEN BYTES AND PROTECTED MODE (32 BITS)-=
               IN     AL,             92H
               TEST   AL,               2
               JNZ          BITS32_SWITCH
               OR     AL,               2
               AND    AL,            0FEH
               OUT   92H,              AL
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-INITIALIZING AND SWITCHING TO 32BITS (PROTECTED MODE)-=-=-=-=-=-=-=-=-=
BITS32_SWITCH: IN     AL,            0EEH ;-=-=-=-=-=-=-=-=ENABLE A20 LINE-=-=-=-=-=-=-=-=
               CLI                        ;-=-=-=-=-=-=-=CLEARING INTERRUPTS-=-=-=-=-=-=-=
               LGDT         [GDT32_TABLE] ;-=-=-=LOADING UP THE PREDEFINED GDT TABLE-=-=-=
               MOV   EAX,             CR0 ;-=-=-=-=-=-=-=-=-=-=-=???-=-=-=-=-=-=-=-=-=-=-=
               OR    EAX,              1H ;-=-=-=-=-=-=-=-=-=-=-=???-=-=-=-=-=-=-=-=-=-=-=
               MOV   CR0,             EAX ;-=-=-=-=-=-=-=-=-=-=-=???-=-=-=-=-=-=-=-=-=-=-=
               MOV    AX,              16 ;-=SETTING UP SEGMENT REGISTERS FOR 32BIT CODE-=
               MOV    DS,              AX ;<|
               MOV    SS,              AX ;<|
               MOV    ES,              AX ;<|
               MOV    FS,              AX ;<|
               MOV    GS,              AX ;<|
               JMP          8:INIT_32BITS ;=-=-=-=-=-=-=MOVING TO 32BIT CODE-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



BITS 32 ;=-=-=-=-=-=-=-=-=-=-=-THE CODE EXECUTED HERE IS 32 BIT CODE-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=SUBROUTINES=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-==LEAVE A DISCRIPTIVE MESSAGE OF WHAT THE ERROR IS AND IS CAUSED BY-=-=-=-=-=-=
HANG_ROUTINE32:CALL              OUTPUT32
        HANG32:HLT
               JMP                 HANG32
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-PRINT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
OUTPUT32:      MOV   EDI,       [0xB8000]
.AGAIN:        LODSB
               OR     AL,              AL
               JZ                   .EXIT
               MOV    AH,               3
               STOSW
               JMP                 .AGAIN
.EXIT:         MOV [0xB8000],         EDI
               RET
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=BOOTLOADING=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-START 32BITS (PROTECTED MODE)-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
INIT_32BITS:   MOV   ESP,      ESP_OFFSET
               LGDT         [GDT64.TABLE]
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=CPUID CHECK=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
               PUSHFD
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
               JZ          HANG_ROUTINE32
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-LONG MODE AVAILABILITY CHECK-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
               MOV   EAX,       80000000H
               CPUID
               CMP   EAX,       80000001H
               MOV    SI,        NO_64BIT
               JB          HANG_ROUTINE32
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-DETECT LONG MODE-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
               MOV   EAX,       80000001H
               CPUID
               TEST  EDX,           1<<29
               MOV    SI,        NO_CPUID
               JZ          HANG_ROUTINE32
               JMP GDT64.CODE:INIT_64BITS ;-=-=-=-=-=-=-=MOVE TO 64BITS CODE-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



BITS 64 ;-=-=-=-=-=-=-=-=-=-=-=THE CODE EXECUTED HERE IS 64 BIT CODE-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=BOOTLOADING=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-START 64BITS (LONG MODE) AND MOVING TO THE KERNEL-=-=-=-=-=-=-=-=-=-=
INIT_64BITS:   JMP          STAGE3_OFFSET ;=-=-GIVING CONTROL AND MOVING TO THE KERNEL-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-VARIABLES-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-OS BOOT DRIVE-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
BOOT_DRIVE     DB                       0
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-DEBUG MESSAGE-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
DISK_ERR       DB          'DISK_ERR ', 0
SECT_ERR       DB          'SECT_ERR ', 0
NO_CPUID       DB          'NO_CPUID ', 0
NO_64BIT       DB          'NO_64BIT ', 0
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-32BIT GDT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
GDT32_START    DQ                       0
GDT32_CODE     DW                0FFFFH,0
               DB 0,10011010B,11001111B,0
GDT32_DATA     DW                0FFFFH,0
               DB 0,10010010B,11001111B,0
GDT32_TABLE    DW     $ - GDT32_START - 1
               DD             GDT32_START
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-64BIT GDT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
GDT64:
.START          EQU              $ - GDT64
                DQ                       0
.CODE           EQU              $ - GDT64
                DD                  0FFFFH
                DB 0,1<<7|1<<4|1<<3|1<<1,1<<7|1<<5|0FH,0
.DATA           EQU              $ - GDT64
                DD                  0FFFFH
                DB 0,1<<7|1<<4|1<<1,1<<7|1<<6|0FH,0
.TSS            EQU              $ - GDT64
                DD    00000068H, 00CF8900H
.TABLE          DW           $ - GDT64 - 1
                DQ                   GDT64
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-BOOTING ESSENTIAL-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
TIMES 510 - ($ - $$) DB 0 ;-=PAD OUT THE REST OF THE BOOTLOADER WITH 0'S UNTIL 510 BYTES-=
DW 0xAA55 ;=-=-=-=-=-=-=-A BIOS SIGNATURE TO SIGNAL THAT THIS IS A BOOT FILE-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
