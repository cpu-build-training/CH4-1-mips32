    .org 0x0
    .set noat
    .set noreorder
    .set nomacro
    .global _start
_start:
    # 因为低地址有异常处理例程，所以处理器启动后，就立即转移到 0x100 处
    ori $1, $0, 0x100          # $1 = 0x100
    jr $1                    # pc <- 0x100
nop

    # 系统调用异常处理例程
    .org 0x40
    ori $1, $0, 0x8000  # $1 = 0x00008000
    ori $1, $0, 0x9000  # $1 = 0x00009000
    mfc0 $1, $14, 0x0   # EPC -> $1 = 0x0000010c
    addi $1, $1, 0x4    # $1 += 4  == 0x00000110
    mtc0 $1, $14, 0x0   # EPC+4 -> EPC
    eret
    nop

    # 主程序，在其中调用 syscall，从而引起系统调用异常
    .org 0x100
    ori $1, $0, 0x1000  # $1 = 0x1000
    sw $1, 0x0100($0)   # $1 -> MEM[0x100] #[0x100] = 0x00001000
    
    mthi $1             # $1 -> HI, HI = 0x00001000

    syscall             # 调用 syscall

    lw $1, 0x0100($0)   # MEM[0x100] -> $1, $1 = 0x00001000

    mfhi $2             # HI -> $2, $2 = 0x00001000

_loop:
    j _loop
    nop