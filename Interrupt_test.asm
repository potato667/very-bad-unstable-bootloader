BITS 64

START_64BITS:LIDT[IDT64_TABLE]
             JMP $

;MOV IDT64_ISR, SOMETHING
;MOV IDT64_FLAGS, SOMETHING

;NEXT: TRY TO GET THE DIVIDE BY ZERO INTERRUPT WORKING

IDT64_START: DW             IDT64_ISR & 0FFFFH
             DW                     GDT64_CODE
             DB                            00H
             DB                    IDT64_FLAGS
             DW (IDT64_ISR >> 16) &     0FFFFH
             DD (IDT64_ISR >> 32) & 0FFFFFFFFH
             DD                            00H
IDT64_TABLE: DW            $ - IDT64_START - 1
             DQ                    IDT64_START
IDT64_FLAGS: DB                            00H
IDT64_ISR:   DB                            00H
