[ORG 0x7C00]
BITS 16

JMP 0:ENTRY
ENTRY:

XOR AX,                AX
MOV SS,                AX
MOV DS,                AX
MOV ES,                AX
MOV GS,                AX
MOV [BOOT_DRIVE],      DL
MOV SP,         SP_OFFSET
JMP             INIT_BOOT

KERNEL_OFFSET EQU  0x2000
SP_OFFSET     EQU  0x7C00
AMT_OF_SECTS  EQU       1

HANG_ROUTINE:  CALL               OUTPUT
        HANG:  CLI
               HLT
               JMP                  HANG

OUTPUT:        MOV    AH,            0EH
.AGAIN:        LODSB
               CMP    AL,              0
               JE                  .EXIT
               INT                   10H
               JMP                .AGAIN
 .EXIT:        RET

INIT_BOOT:     MOV    BX,   KERNEL_OFFSET
               MOV    DH,    AMT_OF_SECTS
               MOV    DL,    [BOOT_DRIVE]
               JMP             INIT_DRIVE
               
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

A20_CHECK:     JNZ          BITS32_SWITCH
 
BITS32_SWITCH: CLI
               LGDT           [GDT_TABLE]
               OR    EAX,              1H
               MOV   CR0,             EAX
               MOV    AX,              16
               MOV    DS,              AX
               MOV    SS,              AX
               MOV    ES,              AX
               MOV    FS,              AX
               MOV    GS,              AX
               JMP          8:INIT_32BITS
               
BITS 32

INIT_32BITS:   JMP          KERNEL_OFFSET
               
BOOT_DRIVE     DB                       0
DISK_ERR       DB          'DISK_ERR ', 0
SECT_ERR       DB          'SECT_ERR ', 0
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

TIMES 510 - ($ - $$) DB 0
DW 0xAA55
