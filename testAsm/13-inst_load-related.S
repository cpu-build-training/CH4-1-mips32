.org 0x0
.set noat
.set noreorder
.set nomacro
.global _start
_start:
    ori $1, $0, 0x1234      # $1 = 0x00001234
    sw  $1, 0x0($0)         # [0x0] = 0x00001234

    ori $2, $0, 0x1234      # $2 = 0x00001234
    ori $1, $0, 0x0         # $1 = 0x00000000

    lw $1, 0x0($0)          # $1 = 0x00000000

    beq $1, $2, label      
    nop

    ori $1, $0, 0x4567
    nop

label:
    ori $1, $0, 0x89ab      # $1 = 0x000089ab
    nop

