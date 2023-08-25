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
;         "ld -T NUL -o kernel.tmp -Ttext 0x2000 Kernel_Entry.o Kernel_C.o"
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
CLC ;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-CLEARING THE CARRY FLAG=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
XOR    AX,             AX ;-+-=-=-=-=-=CLEAR THE OTHER SEGMENT REGISTER VALUES-=-=-=-=-=-=
MOV    SS,             AX ;<|-=-=-NOTE: XOR AX, AX IS USED SINCE THE BELOW DON'T WORK=-=-=
MOV    DS,             AX ;<|-=-=-=-=-XOR SEGMENT REGISTER, SAME SEGMENT REGISTER=-=-=-=-=
MOV    ES,             AX ;<|-=-=-=-=-=-=-=-=-=-MOV SEGMENT REGISTER, 0=-=-=-=-=-=-=-=-=-=
MOV    [BOOT_DRIVE],   DL ;-=-=-=-=-=-=-=-=SETTING THE BOOT DRIVE REGISTER-=-=-=-=-=-=-=-=
MOV    SP,      SP_OFFSET ;-=-=-=-=-=-=-=SETTING UP THE STACK POINTER OFFSET-=-=-=-=-=-=-=
JMP           0:INIT_BOOT ;-=-=-=-=-=-=-=-=-=-=-=BOOTING STARTS HERE-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=^-------------->CLEARING THE CS FLAG-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-DEFINED VARIABLES-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
KERNEL_OFFSET EQU  0x2000 ;-=KERNEL CODE PLACEMENT / POSITION IN MEMORY IE: [ORG 0x2000]-=
SP_OFFSET     EQU  0x7C00 ;-=-=-=-=-STACK POINTER OFFSET (WHERE THE STACK STARTS)=-=-=-=-=
ESP_OFFSET    EQU 0x90000 ;-=-=-=-=32BIT VERSION OF SP_OFFSET (FOR PROTECTED MODE)-=-=-=-=
AMT_OF_SECTS  EQU       1 ;HOW MANY SECTORS ARE TO BE INITIALIZED, EACH CONTAINS 512 BYTES
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=SUBROUTINES=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-HANG FUNCTION-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-LEAVE A DISCRIPTIVE MESSAGE OF WHAT THE ERROR IS AND IS CAUSED BY-=-=-=-=-=-=
HANG_ROUTINE:  CALL                OUTPUT ;-=-=-=-OUTPUTS TEXT FROM THE SI REGISTER=-=-=-=
.HANG:         CLI                        ;-=-=-=-=-=-=-=-CLEARS INTERRUPTS=-=-=-=-=-=-=-=
               HLT                        ;-=-=-=-=-=-=-=-=HALTS PROCESSOR-=-=-=-=-=-=-=-=
               JMP                  .HANG ;RESTART THE ROUTINE IF AN INTERRUPT IS DETECTED
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-PRINT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
OUTPUT:        MOV    AH,             0EH ;-=-=-=-=-SET AH TO SPECIFY OUTPUT MODE=-=-=-=-=
.AGAIN:        LODSB                      ;-=-=-=-=INCREMENT THE SI REGISTER INDEX-=-=-=-=
               CMP    AL,             00H ;-=-=-=-IS THE INDEX SHOWING A ZERO (END)=-=-=-=
               JE                   .EXIT ;-=-=-=-=-=-=IF YES EXIT THE ROUTINE-=-=-=-=-=-=
               INT                    10H ;-=-=-=IF NO THEN PRINT THE CURRENT LETTER-=-=-=
               JMP                 .AGAIN ;-=-=-=-=-=-REPEATS THE ROUTINE AGAIN=-=-=-=-=-=
.EXIT:         RET                        ;-=-=-=RETURNS TO THE FUNCTION THAT CALLED-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=BOOTLOADING=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-=-=STARTING BY SETTING UP THE NEEDED REGISTERS=-=-=-=-=-=-=-=-=-=-=-=
INIT_BOOT:     MOV    AX,           0002H ;-SET AH TO VIDEO MODE AND AL TO VIDEO FUNCTION=
               INT                    10H ;-=-=THIS INTERRUPT IS RESPONSIBLE FOR VIDEO-=-=
               MOV    BX,   KERNEL_OFFSET ;-=-=BX = DESTINATION TO LOAD IN MEMORY(RAM)-=-=
               MOV    DL,    [BOOT_DRIVE] ;-=-=-=-=-=-=-=-=DL = DRIVE TYPE-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=SETTING UP AND CHECKING THE DRIVE VARIABLES=-=-=-=-=-=-=-=-=-=-=-=
               ;PUSH                    DX ;-=-=-=-=-=-=-=-=-=-=SAVE DX-=-=-=-=-=-=-=-=-=-=
               MOV    AX,           0201H ;-AH = 2H(DISK)|AL = 1H(SECTORS AMOUNT TO READ)=
               MOV    CX,           0002H ;-=-=-=-CH = 0H(CYLANDER)|CL = 2H(SECTOR)=-=-=-=
               MOV    DH,             00H ;-=-=-=-=-=-=-=HEAD (TODO(USE DX))-=-=-=-=-=-=-=
               INT                    13H ;-=-=-=-=-=-=-DISK ACCESS INTERRUPT=-=-=-=-=-=-=
               ;POP                     DX ;-=-=-=-=-=-=-=-=-=RESTORES DX-=-=-=-=-=-=-=-=-=
               MOV    DH,    AMT_OF_SECTS ;-=-=DH = AMMOUNT OF SECTORS(512 BYTES EACH)-=-=
               MOV    SI,        DISK_ERR ;MOVE TEXT TO SI, PRINTING WILL TARGET THIS TEXT
               JC            HANG_ROUTINE ;IF THE CARRY FLAG IS SET, THERE IS A DISK ERROR
               CMP    AL,              DH ;-=-=-=-=-COMPARES 'A' LOW AND 'D' HIGH=-=-=-=-=
               MOV    SI,        SECT_ERR ;MOVE TEXT TO SI, PRINTING WILL TARGET THIS TEXT
               JNE           HANG_ROUTINE ;-=NOT EQUAL?, THERE IS A SECTOR READING ERROR-=
;=-CHECKING AND ENABLING A20 FOR USING OVER 1MB, EVEN BYTES AND PROTECTED MODE (32 BITS)-=
               IN     AL,             92H ;-READ FROM PORT 92H AND SET 'AL' TO THAT VALUE=
               OR     AL,             02H ;-SET THE A20 BIT BY DOING A LOGICAL OR TO 'AL'=
               OUT   92H,              AL ;WRITES TO PORT 92H BY 'AL' WITH THE A20 BIT SET
;=-=-=-=-=-=-=-=-=-INITIALIZING AND SWITCHING TO 32BITS (PROTECTED MODE)-=-=-=-=-=-=-=-=-=
               CLI                        ;-=-=-=-=-=-=-=CLEARING INTERRUPTS-=-=-=-=-=-=-=
               LGDT         [GDT32_TABLE] ;-=-=LOAD THE PREDEFINED GDT FOR 32 BIT CODE-=-=
               MOV   EAX,             CR0 ;-=-=-=CRO CAN'T BE USED WITH AN IMMEDIATE-=-=-=
               OR     AL,             01H ;-=SET THE PROTECTION ENABLE BIT IN CR0 VIA AL-=
               MOV   CR0,             EAX ;-=-=-=-=-=-MOVES THE BIT BACK TO CR0=-=-=-=-=-=
               JMP GDT32_CODE:INIT_32BITS ;=-=-=-=-=-=-=MOVING TO 32BIT CODE-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=^----->SETTING THE CS FLAG TO SUPPORT 32BIT CODE-=-=-=-=-=-=-=-=-=



BITS 32 ;=-=-=-=-=-=-=-=-=-=-=-THE CODE EXECUTED HERE IS 32 BIT CODE-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=SUBROUTINES=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-==LEAVE A DISCRIPTIVE MESSAGE OF WHAT THE ERROR IS AND IS CAUSED BY-=-=-=-=-=-=
HANG_ROUTINE32:CALL              OUTPUT32 ;-=-=-=-OUTPUT TEXT FROM THE ESI REGISTER=-=-=-=
.HANG32:       HLT                        ;-=-=-=-=-=-=-=-=HALTS PROCESSOR-=-=-=-=-=-=-=-=
               JMP                .HANG32 ;RESTART THE ROUTINE IF AN INTERRUPT IS DETECTED
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-PRINT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
OUTPUT32:      MOV   EDI,       [0xB8000] ;SPECIFY THE VIDEO MODE ADDRESS:IN THIS CASE VGA
.AGAIN:        LODSB                      ;-=-=-=-=INCREMENT THE SI REGISTER INDEX-=-=-=-=
               CMP    AL,             00H ;-=-=-=-IS THE INDEX SHOWING A ZERO (END)=-=-=-=
               JE                   .EXIT ;-=-=-=-=-=-=IF YES EXIT THE ROUTINE-=-=-=-=-=-=
               MOV    AH,             03H ;-=-=-=IF NO THEN PRINT THE CURRENT LETTER-=-=-=
               STOSW                      ;-=-=-=-=-=-=-=STORE THE NEXT BYTE-=-=-=-=-=-=-=
               JMP                 .AGAIN ;-=-=-=-=-=-=-REPEAT THE SUBROUTINE=-=-=-=-=-=-=
.EXIT:         MOV [0xB8000],         EDI ;-=-WRITES THE DATA TO THE VIDEO MODE ADDRESS=-=
               RET                        ;-=-=-=RETURNS TO THE FUNCTION THAT CALLED-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=BOOTLOADING=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-START 32BITS (PROTECTED MODE)-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
INIT_32BITS:   MOV    AX,      GDT32_DATA ;-=SETTING UP SEGMENT REGISTERS FOR 32BIT CODE-=
               MOV    DS,              AX ;<|
               MOV    SS,              AX ;<|
               MOV    ES,              AX ;<|
               MOV    FS,              AX ;<|
               MOV    GS,              AX ;<|
               MOV   ESP,      ESP_OFFSET ;-=-=-=-=-=-=-=32BIT STACK POINTER-=-=-=-=-=-=-=
               LGDT         [GDT64_TABLE] ;-=-=LOAD THE PREDEFINED GDT FOR 64 BIT CODE-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=CPUID CHECK=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
               PUSHFD                     ;-=-=-PUSHES ALL EFLAGS ON TOP OF THE STACK=-=-=
               POP                    EAX ;-=-=-=-=-=RESTORES EAX FROM THE STACK-=-=-=-=-=
               MOV   ECX,             EAX ;-=-=-=KEEP A COPY OF EAX ON ECX FOR LATER-=-=-=
               XOR   EAX,       00200000H ;1<<21<-TRYING TO FLIP BIT 21 TO CHECK FOR CPUID
               PUSH                   EAX ;-=-=-=-COPY EAX TO FLAGS USING THE STACK=-=-=-=
               POPFD                      ;-=-=NOW POP THE EFLAGS AFTER DOING PUSH EAX-=-=
               PUSHFD                     ;-=-=-=-=-=-=-=PUSH THE EFLAGS NOW-=-=-=-=-=-=-=
               POP                    EAX ;-=-=-=-=-=FLAGS ARE NOW COPIED TO EAX-=-=-=-=-=
               PUSH                   ECX ;-=-=-=RESTORE OLD FLAGS, TO COMPARE TO 21-=-=-=
               POPFD                      ;-=-=-=-=-=POPS THE REST OF THE EFLAGS-=-=-=-=-=
               XOR   EAX,             ECX ;LOGICAL XOR ON EAX,ECX SEEING IF THEY ARE EQUAL
               MOV   ESI,        NO_CPUID ;-=LOADING THE 'NO_CPUID' ERROR MESSAGE TO ESI-=
               JZ          HANG_ROUTINE32 ;ZERO MEANS THEY ARE EQUAL, SO STOPS THE PROGRAM
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=CHECKS LONG MODE AVAILABILITY-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
               MOV   EAX,       80000000H ;-=-=-=-=-=-=SETS EAX TO 80000000H-=-=-=-=-=-=-=
               CPUID                      ;-=-=-=-=CPU'S PROPERTIES IDENTIFICATION-=-=-=-=
               CMP   EAX,       80000001H ;-=-=-=CHECK IF EAX IS LESS THAN 80000001H-=-=-=
               MOV   ESI,        NO_64BIT ;-=LOADING THE 'NO_64BIT' ERROR MESSAGE TO ESI-=
               JB          HANG_ROUTINE32 ;-=STOPS THE PROGRAM IF EAX IS BELOW 80000001H-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-DETECTS LONG MODE(LM/64 BIT MODE)-=-=-=-=-=-=-=-=-=-=-=-=-=-=
               MOV   EAX,       80000001H ;-=-=-=-=-=-=SETS EAX TO 80000001H-=-=-=-=-=-=-=
               CPUID                      ;-=-=-=-=CPU'S PROPERTIES IDENTIFICATION-=-=-=-=
               TEST  EDX,       20000000H ;1<<29<-TEST IF THE LM BIT(BIT 29) IS SET IN EDX
               MOV   ESI,        NO_CPUID ;-=LOADING THE 'NO_CPUID' ERROR MESSAGE TO ESI-=
               JZ          HANG_ROUTINE32;-=STOPS THE PROGRAM IF EDX DOESN'T HAVE BIT 29-=
               JMP GDT64_CODE:INIT_64BITS ;-=-=-IF ALL GOES WELL, MOVE TO 64BITS CODE=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



BITS 64 ;=-=-=-=-=-=-=-=-=-=-=-THE CODE EXECUTED HERE IS 64 BIT CODE-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-NO SUBROUTINES NEEDED-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=BOOTLOADING=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-START 64BITS (LONG MODE) AND MOVING TO THE KERNEL-=-=-=-=-=-=-=-=-=-=
INIT_64BITS:  CLI                         ;-=-=-=-=-CLEAR INTERRUPTS JUST IN CASE=-=-=-=-=
              MOV   AX,        GDT64_DATA ;-=SETTING UP SEGMENT REGISTERS FOR 32BIT CODE-=
              MOV   DS,                AX ;<|
              MOV   ES,                AX ;<|
              MOV   FS,                AX ;<|
              MOV   GS,                AX ;<|
              MOV   SS,                AX ;<|
              JMP    $                    ;INIFINITE LOOP UNTIL THE KERNEL TRIPLE FAULT GETS PATCHED
              ;JMP           KERNEL_OFFSET ;=-=-GIVING CONTROL AND MOVING TO THE KERNEL-=-=<--TRIPLE FAULT
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
GDT32_CODE     EQU        $ - GDT32_START ;SPECIFY CODE ADDRESS, WILL BE SET AS CS SEGMENT
               DW                0FFFFH,0
               DB           0,09AH,0CFH,0
GDT32_DATA     EQU        $ - GDT32_START ;SPECIFY THE DATA ADDRESS, TO SET OTHER SEGMENTS
               DW                0FFFFH,0
               DB           0,092H,0CFH,0
GDT32_TABLE    DW         $-GDT32_START-1 ;TO LOAD A GDT, DATA NEEDS TO BE GIVEN TO 'LGDT'
               DD             GDT32_START ;=STORE ENTRY'S ADDRESS IN A 32 BIT DOUBLE WORD=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-64BIT GDT-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
GDT64_START    DQ                       0
GDT64_CODE     EQU        $ - GDT64_START ;SPECIFY CODE ADDRESS, WILL BE SET AS CS SEGMENT
               DD               0000FFFFH
               DD               00AF9A00H
GDT64_DATA     EQU        $ - GDT64_START ;SPECIFY THE DATA ADDRESS, TO SET OTHER SEGMENTS
               DD               0000FFFFH
               DD               00AF9200H
GDT64_TABLE    DW         $-GDT64_START-1 ;TO LOAD A GDT, DATA NEEDS TO BE GIVEN TO 'LGDT'
               DQ             GDT64_START ;=-STORE ENTRY'S ADDRESS IN A 64 BIT QUAD WORD-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-BOOTING ESSENTIAL-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
TIMES 510 - ($ - $$) DB 0 ;-=PAD OUT THE REST OF THE BOOTLOADER WITH 0'S UNTIL 510 BYTES-=
DW 0xAA55 ;=-=-=-=-=-=-=-A BIOS SIGNATURE TO SIGNAL THAT THIS IS A BOOT FILE-=-=-=-=-=-=-=
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
