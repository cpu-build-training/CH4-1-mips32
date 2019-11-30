    .org 0x0
    .set noat
    .set noreorder
    .set nomacro
    .global _start

_start:
    ori $1, $0, 0x0001  # (1) $1 = 0x1
    j   0x20            # 0x20 -> pc
    ori $1, $0, 0x0002  # (2) $1 = 0x2, is a delayslot instruct
    ori $1, $0, 0x1111
    ori $1, $0, 0x1100

    .org 0x20
    ori $1, $0, 0x0003  # (3) $1 = 0x3
    jal 0x40            # 0x40 -> pc, $31 == 0x2c
    div $zero, $31, $1  # (4) $31 = 0x2c, $1 = 0x3, delayslot inst
                        # HI = 0x2, LO = 0xe

    ori $1, $0, 0x0005  # (6) $1 = 0x5
    ori $1, $0, 0x0006  # (7) $1 = 0x6
    j   0x60            # 0x60 -> pc
    nop

    .org 0x40
    jalr $2, $31        # $31 == 0x2c, 0x2c -> pc, $2 = 0x48
    or   $1, $2, $0     # (5) $1 = 0x48, delayslot inst

    ori $1, $0, 0x0009  # (10) $1 = 0x9
    ori $1, $0, 0x000a  # (11) $1 = 0xa
    j   0x80            # 0x80 -> pc
    nop

    .org  0x60
    ori $1, $0, 0x0007  # (8) $1 = 0x7
    jr  $2              # $2 == 0x48, 0x48 -> pc
    ori $1, $0, 0x0008  # (9) $1 = 0x8  delayslot inst
    ori $1, $0, 0x1111
    ori $1, $0, 0x1100  

    .org 0x80
    nop

_loop:
    j _loop
    nop
