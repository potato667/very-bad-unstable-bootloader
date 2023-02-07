;SPECIAL THANKS TO:
; -GOOGLE0101
; -GLORIOUSCOW
; -IQON
; FOR ALL OF THEIR HELP AND SUPPORT :D

; SOFTWARE NEEDED:
; -QEMU
; -NASM
; -GCC

; COMPILE "nasm Boot.asm -f bin -o Boot.bin"
;         "nasm Kernel.asm -f bin -o Kernel.bin"
;         "type Boot.bin Kernel.bin > CruiseOS.bin"

; ASM & C "gcc -c Kernel.c -o Kernel.o"
;         "nasm Kernel_Entry.asm -o Kernel_Entry.o"
;         "ld Kernel.o Kernel_Entry.o -o elf"

; RUN     "qemu-system-i386 CruiseOS.bin"

; BOOTLOADER FEATURES:
; [X]DRIVE CHECK
; [-]HANG ROUTINES
; [X]A20
; [X]GDT
; [X]32 BIT PROTECTED MODE
; [-]64 BIT LONG MODE
; [-]FAT 32 FILESYSTEM SUPPORT
; [-]INITIALIZING THE RTC (REAL TIME CLOCK)
; [-]INITIALIZING INT 33h (THE MOUSE CURSOR)
; [-]IDT (INTERRUPT DESCRIPTOR TABLE)
; [-]ISR (INTERRUPT SERVICE ROUTINE)
; [-]KERNEL ABI (APPLICATION BINARY INTERFACE)
; [X]MOVING TO THE KERNEL

; REPLACE ALL MOV REGISTER, 0 TO XOR REGISTER, REGISTER, SINCE IT IS FASTER

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-16 BIT SEGMENT
BITS 16 ; TO CALL OR JMP FROM ONE CODE SEGMENT TO ANOTHER, USE 'CODE_SEG:' BEFORE THE FUNCTION NAME
[ORG 0x7c00] ; WHERE THE CODE IS LOCATED, BOOTLOADERS ARE USUALLY IN 0x7c00

CODE_SEG      EQU GDT_CODE - GDT_START
DATA_SEG      EQU GDT_DATA - GDT_START
KERNEL_OFFSET EQU               0x2000 ; WHERE THE KERNEL WILL BE PLACED, FOR EXAMPLE [ORG 0x2000]

MOV [BOOT_DRIVE], DL
MOV SP, 0x7c00

CALL   INIT_KERNEL
CALL     A20_CHECK
CALL BITS32_SWITCH

;JMP $ ; FOR LOOPING (TRYING TO REPLACE LOOPING WITH HANG ROUTINES)
;MOV SI, BOOT_ERR
;CALL ERR_OUTPUT

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-HANG ROUTINE
HANG_ROUTINE: ; USE AFTER LEAVING A DISCRIPTIVE MESSAGE OF WHAT THE ERROR IS
     CLI
     HLT
     JMP HANG_ROUTINE

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-FUNCTION SPECIFIC PRINTS
OUTPUT:          MOV AH, 0Eh
.AGAIN:          LODSB
                 CMP AL, 0
                 JE  .EXIT
                 INT 10h
                 JMP .AGAIN
 .EXIT:          RET

;ERR_OUTPUT:      MOV AH, 0Eh
;    .AGAIN:      LODSB
;                 CMP AL, 0
;                 JE  .EXIT
;                 INT 10h
;                 JMP .AGAIN
;     .EXIT:      CALL HANG_ROUTINE

DISK_ERR_OUT:    MOV AH, 0Eh
      .AGAIN:    LODSB
                 CMP AL, 0
                 JE  .EXIT
                 INT 10h
                 JMP .AGAIN
       .EXIT:    JMP CODE_SEG:DISK_LOOP

SECT_ERR_OUT:    MOV AH, 0Eh
      .AGAIN:    LODSB
                 CMP AL, 0
                 JE  .EXIT
                 INT 10h
                 JMP .AGAIN
       .EXIT:    JMP CODE_SEG:DISK_LOOP

A20_ON_OUT:      MOV AH, 0Eh
    .AGAIN:      LODSB
                 CMP AL, 0
                 JE  .EXIT
                 INT 10h
                 JMP .AGAIN
     .EXIT:      JMP CODE_SEG:BITS32_SWITCH

GDT_SUCCESS_OUT: MOV AH, 0Eh
         .AGAIN: LODSB
                 CMP AL, 0
                 JE  .EXIT
                 INT 10h
                 JMP .AGAIN
          .EXIT: JMP CODE_SEG:INIT_32BITS

A20_EXIT_OUT:    MOV AH, 0Eh
      .AGAIN:    LODSB
                 CMP AL, 0
                 JE  .EXIT
                 INT 10h
                 JMP .AGAIN
       .EXIT:    JMP CODE_SEG:A20_STATE

INIT_32BITS_OUT: MOV AH, 0Eh
         .AGAIN: LODSB
                 CMP AL, 0
                 JE  .EXIT
                 INT 10h
                 JMP .AGAIN
          .EXIT: JMP CODE_SEG:BEGIN_32BIT

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-BOOTLOADING
INIT_KERNEL:
     MOV  BX, KERNEL_OFFSET ; BX -> DESTINATION
     MOV  DH,             2 ; DH -> NUM SECTORS (WHEN SET TO 2 THE KERNEL LOADS, WHEN SET TO 1 A20 SUCCESS MESSAGE LOADS)
     MOV  DL,  [BOOT_DRIVE] ; DL ->        DISK
     MOV  SI,     KERN_INIT
     CALL            OUTPUT
     CALL        INIT_DRIVE
     RET

INIT_DRIVE:
     PUSHA
     PUSH DX
     MOV  AH, 02h
     MOV  AL,   1
     MOV  CL, 02h
     MOV  CH, 00h
     MOV  DH, 00h
     INT  13h
     JC   DISK_ERR
     POP  DX
     CMP  AL,   DH
     JNE  SECT_ERR
     POPA
     MOV  SI, DRIVE_LOADED
     CALL OUTPUT
     RET

     DISK_ERR:
          ;MOV SI, DISK_ERR
          ;CALL ERR_OUTPUT
          MOV SI, DISK_ERROR
          CALL DISK_ERR_OUT
          RET

     SECT_ERR:
          ;MOV SI, SECTOR_ERR
          ;CALL ERR_OUTPUT
          MOV  SI, SECTOR_ERROR
          CALL SECT_ERR_OUT
          RET

     DISK_LOOP: JMP $ ; THIS FUNCTION SHOULD BE REMOVED

A20_CHECK:
     PUSHF
     PUSH DS
     PUSH ES
     PUSH DI
     PUSH SI
     CLI
     XOR  AX,    AX
     MOV  ES,    AX
     NOT  AX
     MOV  DS,    AX
     MOV  DI, 0500h
     MOV  SI, 0510h
     MOV  AL, BYTE[ES:DI]
     PUSH AX
     MOV  AL, BYTE[DS:SI]
     PUSH AX
     MOV  BYTE[ES:DI], 0x00
     MOV  BYTE[DS:SI], 0xFF
     CMP  BYTE[ES:DI], 0xFF
     POP  AX
     MOV  BYTE[DS:SI],   AL
     POP  AX
     MOV  BYTE[ES:DI],   AL
     MOV  AX, 0
     POP  SI
     POP  DI
     POP  ES
     POP  DS
     POPF
     MOV  SI, A20_SUCCESS
     CALL A20_EXIT_OUT
     ;MOV  AX, 1 ; IS THAT EVEN ESSENTIAL?
     RET

BITS32_SWITCH:
     CLI
     LGDT [GDT_TABLE]
     MOV  EAX, CR0
     OR   EAX, 1h
     MOV  CR0, EAX
     MOV  SI, GDT_SUCCESS
     CALL GDT_SUCCESS_OUT
     RET

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-32 BIT SEGMENT
BITS 32

A20_STATE:
     PUSHAD
     MOV  EDI , 112345h
     MOV  ESI , 012345h
     MOV [ESI],      ESI
     MOV [EDI],      EDI
     CMPSD
     POPAD
     ;JNE A20_ON
     JE  A20_OFF
     RET

     A20_OFF:
          ;MOV SI, A20_STATE_OFF
          ;CALL ERR_OUTPUT
          MOV  SI, A20_STATE_OFF
          CALL CODE_SEG:OUTPUT
          RET

     A20_ON:
          MOV  SI, A20_STATE_ON
          CALL CODE_SEG:A20_ON_OUT
          RET

INIT_32BITS:
     MOV   AX, DATA_SEG
     MOV   DS,       AX
     MOV   SS,       AX
     MOV   ES,       AX
     MOV   FS,       AX
     MOV   GS,       AX
     MOV  EBP,   90000h
     MOV  ESP,      EBP
     MOV   SI, GDT_STATE_ON
     CALL CODE_SEG:INIT_32BITS_OUT
     RET

BEGIN_32BIT:
     CALL CODE_SEG:KERNEL_OFFSET ; GIVES CONTROL THE LINKED KERNEL THAT HAS A HEADER OF [ORG 0x2000]
                                 ; OTHER VALUES CAUSE A TGC FATAL ERROR IN QEMU FOR SOME REASON
     JMP $ ; LOOP JUST INCASE THE KERNEL DOES A RETURN, SHOULD BE REPLACED WITH A HANG ROUTINE
     ;MOV SI, KERN_ERR
     ;CALL ERR_OUTPUT

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-VARIABLES
GDT_TABLE:
     DW GDT_END - GDT_START - 1
     DD GDT_START
GDT_START:
     DQ       0x0
GDT_CODE:
     DW    0xffff
     DW       0x0
     DB       0x0
     DB 10011010b
     DB 11001111b
     DB       0x0
GDT_DATA:
     DW    0xffff
     DW       0x0
     DB       0x0
     DB 10010010b
     DB 11001111b
     DB       0x0
GDT_END:

BOOT_DRIVE      DB 0
KERN_INIT       DB 'KERN_INIT ' , 0
KERN_ERR        DB 'KERN_ERR '  , 0
DRIVE_LOADED    DB 'DRIVE_ON '  , 0
DISK_ERROR      DB 'DISK_ERR '  , 0
SECTOR_ERROR    DB 'SECT_ERR '  , 0
A20_SUCCESS     DB 'A20_LOAD '  , 0
A20_STATE_ON    DB 'A20_ON '    , 0
A20_STATE_OFF   DB 'A20_OFF '   , 0
GDT_SUCCESS     DB 'GDT_LOAD '  , 0
GDT_STATE_ON    DB 'GDT_ON '    , 0
BOOT_ERR        DB 'BOOT_ERR '  , 0

TIMES 510-($-$$) DB 0
DW 0xAA55 ; BOOT SIGNATURE
