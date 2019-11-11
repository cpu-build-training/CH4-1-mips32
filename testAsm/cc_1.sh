CC_PREFIX=mipsel-linux-gnu-
# 教程中给出的编译链接方式
${CC_PREFIX}as -mips32 inst_rom.S -o inst_rom.o
${CC_PREFIX}ld -T ram.ld inst_rom.o -o inst_rom.om
${CC_PREFIX}objcopy -O bianry inst_rom.om inst_rom.bin

# 其实跟我自己摸索的差不多，反而在现在的 mips 交叉编译环境上效果不太好