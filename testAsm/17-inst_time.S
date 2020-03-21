    .org 0x0
    .set noat
    .set noreorder
    .set nomacro
    .global _start
_start:
    # 因为低地址有异常处理例程
    ori $1, $0, 0x100 # $1 = 0x100
    jr $1
    nop

    # 中断处理例程，在其中将 $2 寄存器的值加 1，这样便于观察时钟是否发生
    # 另外，增加 Compare 的值，以清除时钟中断，同时设置下一次时钟中断发生的时间
    .org 0x20

    addi $2, $2, 0x1    # $2 +=1

    mfc0 $1, $11, 0x0   # 读取 Compare 的值
    addi $1, $1, 20    # $1 +=20
    mtc0 $1, $11, 0x0   # save to Compare
    eret
    nop

    # init Compare
    .org 0x100
    ori $2, $0, 0x0
    ori $1, $0, 0x20
    mtc0 $1, $11, 0x0   # 初始化 Compare 寄存器的值 100

    lui $1, 0x1000
    ori $1, $1, 0x401 
    mtc0 $1, $12, 0x0   # Status == 0x10000401 表示使能时钟中断

_loop:
    j _loop
    nop