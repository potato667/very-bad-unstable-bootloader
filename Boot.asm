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

; ASM & C "gcc -c Kernel.c -o Kernel.o"
;         "nasm Kernel_Entry.asm -o Kernel_Entry.o"
;         "ld Kernel.o Kernel_Entry.o -o elf"

; RUN     "qemu-system-i386 CruiseOS.bin"
; RUN DBG "qemu-system-i386 -monitor stdio -d int -no-reboot CruiseOS.bin"

; BOOTLOADER FEATURES:
; [X]DRIVE CHECK
; [X]HANG ROUTINES
; [X]A20
; [X]GDT
; [X]32 BIT PROTECTED MODE
; [-]64 BIT LONG MODE
; [-]OLD BIOS PATCHES
; [-]FAT 32 FILESYSTEM SUPPORT
; [-]INITIALIZING THE RTC (REAL TIME CLOCK)
; [-]INITIALIZING INT 33h (THE MOUSE CURSOR)
; [-]IDT (INTERRUPT DESCRIPTOR TABLE)
; [-]ISR (INTERRUPT SERVICE ROUTINE)
; [-]VESA BIOS EXTENTIONS
; [-]RESOLUTION TO 1920*1080
; [-]MULTI-THREADING
; [-]KERNEL ABI (APPLICATION BINARY INTERFACE)
; [X]MOVING TO THE KERNEL

; REPLACE ALL MOV REGISTER, 0 TO XOR REGISTER, REGISTER, SINCE IT IS FASTER

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-16 BIT SEGMENT
BITS 16 ; TO CALL OR JMP FROM ONE CODE SEGMENT TO ANOTHER, USE '0:' BEFORE THE FUNCTION NAME
[ORG 0x7c00] ; WHERE THE CODE IS LOCATED, BOOTLOADERS ARE USUALLY IN 0x7c00

;JMP 0:ENTRY
;ENTRY:

KERNEL_OFFSET EQU 0x2000 ; WHERE THE KERNEL WILL BE PLACED, FOR EXAMPLE [ORG 0x2000]

XOR           AX,     AX
MOV           SS,     AX
MOV           DS,     AX
MOV           ES,     AX
MOV           GS,     AX
MOV [BOOT_DRIVE],     DL
MOV           SP, 0x7c00

JMP 0:INIT_KERNEL

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-HANG ROUTINE
HANG_ROUTINE: CALL OUTPUT; USE AFTER LEAVING A DISCRIPTIVE MESSAGE OF WHAT THE ERROR IS
        HANG: CLI
              HLT
              JMP HANG

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-PRINT
OUTPUT: MOV AH, 0Eh
.AGAIN: LODSB
        CMP AL,   0
        JE    .EXIT
        INT     10h
        JMP  .AGAIN
 .EXIT: RET

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-BOOTLOADING
INIT_KERNEL: MOV  BX, KERNEL_OFFSET ; BX: DESTINATION
             MOV  DH,             1 ; DH: SECTOR NUMS
             MOV  DL,  [BOOT_DRIVE] ; DL:        DISK
             JMP        INIT_DRIVE

INIT_DRIVE: PUSHA
            PUSH DX
            MOV  AH,      02h
            MOV  AL,        1
            MOV  CL,      02h
            MOV  CH,      00h
            MOV  DH,      00h
            INT           13h
            ; CAN I PUT POP DX HERE?
            MOV  SI, DISK_ERR
            JC   HANG_ROUTINE
            POP  DX
            CMP  AL,       DH
            MOV  SI, SECT_ERR
            JNE  HANG_ROUTINE
            JMP  A20_CHECK

A20_CHECK: POPA
           IN    AL, 0x92
           TEST  AL,    2
           JNZ  A20_STATE
           OR    AL,    2
           AND   AL, 0xFE
           OUT 0x92,   AL

BITS32_SWITCH: CLI
               LGDT [GDT_TABLE]
               MOV  EAX,    CR0
               OR   EAX,     1h
               MOV  CR0,    EAX
               MOV   AX,     16
               MOV   DS,     AX
               MOV   SS,     AX
               MOV   ES,     AX
               MOV   FS,     AX
               MOV   GS,     AX
               JMP  8:INIT_32BITS

A20_STATE: IN   AL, 0x92
           TEST AL,    2
           JNZ  BITS32_SWITCH
           MOV  SI, A20_STATE_OFF
           JMP  HANG_ROUTINE

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-32 BIT SEGMENT
BITS 32

INIT_32BITS: MOV  EBP, 90000h
             MOV  ESP,    EBP
             JMP  BEGIN_32BIT

BEGIN_32BIT: CALL KERNEL_OFFSET
             JMP $

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-VARIABLES
BOOT_DRIVE    DB 0
DISK_ERR      DB 'DISK_ERR ', 0
SECT_ERR      DB 'SECT_ERR ', 0
A20_STATE_OFF DB 'A20_OFF ' , 0
BOOT_ERR      DB 'BOOT_ERR ', 0
GDT_TABLE:    DW GDT_END - GDT_START - 1
              DD GDT_START
GDT_START:    DQ       0x0
GDT_CODE:     DW    0xffff
              DW       0x0
              DB       0x0
              DB 10011010b
              DB 11001111b
              DB       0x0
GDT_DATA:     DW    0xffff
              DW       0x0
              DB       0x0
              DB 10010010b
              DB 11001111b
              DB       0x0
GDT_END:

TIMES 510-($-$$) DB 0
DW 0xAA55 ; BOOT SIGNATURE
