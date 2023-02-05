; COMPILE "nasm Boot.asm -f bin -o Boot.bin"
;         "nasm Kernel.asm -f bin -o Kernel.bin"
;         "type Boot.bin Kernel.bin > OS.bin"
; RUN     "qemu-system-i386  OS.bin"

BITS 16
[ORG 0x7c00]

CODE_SEG      EQU GDT_CODE - GDT_START
DATA_SEG      EQU GDT_DATA - GDT_START
KERNEL_OFFSET EQU               0x2000

MOV [BOOT_DRIVE],     DL
MOV           BP,  9000h
MOV           SP,     BP

CALL INIT_KERNEL
CALL   A20_CHECK

JMP $
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-FUNCTION SPECIFIC PRINTS
OUTPUT:          MOV AH, 0Eh
.AGAIN:          LODSB
                 CMP AL, 0
                 JE  .EXIT
                 INT 10h
                 JMP .AGAIN
 .EXIT:          RET

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
     MOV  DH,             2 ; DH -> NUM SECTORS
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
     MOV SI, DISK_ERROR
     CALL DISK_ERR_OUT
     RET

     SECT_ERR:
     MOV  SI, SECTOR_ERROR
     CALL SECT_ERR_OUT
     RET

     DISK_LOOP:
     JMP $

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
     JC   A20_EXIT_CHECK
     MOV  AX, 1
     RET

A20_EXIT_CHECK:
     POP  SI
     POP  DI
     POP  ES
     POP  DS
     POPF
     MOV  SI, A20_SUCCESS
     CALL A20_EXIT_OUT
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

BITS 32 ;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-SECOND STAGE

A20_STATE:
     PUSHAD
     MOV  EDI , 112345h
     MOV  ESI , 012345h
     MOV [ESI],      ESI
     MOV [EDI],      EDI
     CMPSD
     POPAD
     JNE A20_ON
     RET

A20_OFF:
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
     CALL 0:KERNEL_OFFSET ; STARTS THE LINKED KERNEL THAT HAS A HEADER OF [ORG 0x2000] ; OTHER VALUES CAUSE A TGC FATAL ERROR IN QEMU FOR SOME REASON
     JMP $

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
DRIVE_LOADED    DB 'DRIVE_ON '  , 0
DISK_ERROR      DB 'DISK_ERR '  , 0
SECTOR_ERROR    DB 'SECT_ERR '  , 0
A20_SUCCESS     DB 'A20_LOAD '  , 0
A20_STATE_ON    DB 'A20_ON '    , 0
A20_STATE_OFF   DB 'A20_OFF '   , 0
GDT_SUCCESS     DB 'GDT_LOAD '  , 0
GDT_STATE_ON    DB 'GDT_ON '    , 0
REBOOTING       DB 'REBOOT '    , 0

TIMES 510-($-$$) DB 0
DW 0xAA55
