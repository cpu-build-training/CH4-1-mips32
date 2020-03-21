    .org 0x0
    .set noat
    .set noreorder
    .global _start
_start:
    # 因为低地址有异常处理例程，所以处理器启动后，就立即转移到 0x100 处
    ori $1, $0, 0x100 # $1 = 0x100
    jr $1               # pc <- 0x100
    nop

    # 自陷异常的处理例程，在其中设置寄存器 $1 的值
    .org 0x40
    ori $1, $0, 0xf0f0  # $1 = 0x0000f0f0
    ori $1, $0, 0xffff  # $1 = 0x0000ffff
    ori $1, $0, 0x0f0f  # $1 = 0x00000f0f

    mfc0 $4, $14, 0x0   # EPC -> $4
    addi $4, $4, 0x4    # $4 += 4
    mtc0 $4, $14, 0x0   # $4 -> EPC
    
    eret
    nop


    .org 0x100
    ori $1, $0, 0x1000   # $1 = 0x00001000   / 0x100
    ori $2, $0, 0x1000   # $2 = 0x00001000   / 0x104
    teq $1, $2          # trap               / 0x108

    ori $1, $0, 0x2000   # $1 = 0x00002000   / 0x10c
    tne $1, $2           # trap

    ori $1, $0, 0x3000   # $1 = 0x00003000
    teqi $1, 0x3000      # trap

    ori $1, $0, 0x4000    # $1 = 0x00004000
    tnei $1, 0x2000       # trap

    ori $1, $0, 0x5000   
    tge $1, $2             

    ori $1, $0, 0x6000
    tgei $1, 0x4000

    ori $1, $0, 0x7000
    tgeiu $1, 0x7000

    ori $1, $0, 0x8000
    tgeu $1, $2

    ori $1, $0, 0x9000
    tlt $1, $2            # no trap

    ori $1, $0, 0xa000
    tlti $1, 0x9000         # no trap

    ori $1, $0, 0xb000
    tltiu $1, 0xb000

    ori $1, $0, 0xc000
    tltu $2, $1   

    ori $1, $0, 0xd000      # $1 = 0x0000d0000

_loop:
    j _loop
    nop