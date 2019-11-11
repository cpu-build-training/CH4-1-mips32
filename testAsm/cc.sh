# cross compile
CC_PREFIX=mipsel-linux-gnu-
${CC_PREFIX}as -EB inst_rom.S -o a.o
# ${CC_PREFIX}ld -EB --gc-section --oformat binary a.o -o a.elf 
# ${CC_PREFIX}ld -EB -T ram.ld a.o -o a.elf
${CC_PREFIX}ld -EB a.o -o a.elf
${CC_PREFIX}readelf -S a.elf 
${CC_PREFIX}objcopy --only-section=.text a.elf a.text -O verilog

sed -i '1d' ./a.text
sed -i 's/ //g' ./a.text
sed -i 's_\(.\{8\}\)_\1\n_g' a.text
# ${CC_PREFIX}objcopy -O binary a.elf a.bin