    .org 0x0
    .set noat
    .set noreorder
    .set nomacro
    .global _start
_start:
    ori $1, $0, 0xf # $1 = 0xf
    mtc0 $1, $11, 0x0 # 0xf -> CP0.Compare
    
    lui $1, 0x1000
    ori $1, $1, 0x401   # $1 = 0x10000401
    mtc0 $1, $12, 0x0   # 0x10000401 -> CP0.Status
    mfc0 $2, $12, 0x0   # $2 -> 0x10000401

_loop:
    j _loop
    nop