ifndef CROSS_COMPILE
CROSS_COMPILE = mipsel-linux-gnu-
endif
CC = $(CROSS_COMPILE)as
LD = $(CROSS_COMPILE)ld
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump

OBJECTS = inst_rom.o
SOURCE = $(shell ls *.S | sort | tail -n1 | tr -d '\n')

export CROSS_COMPILE

# Rules of Compilation

all: inst_rom.data

# %.o: %.S
$(OBJECTS): $(SOURCE)
	$(CC) -EB $< -o $(OBJECTS)

inst_rom.om: ram.ld $(OBJECTS)
	$(LD) -T ram.ld -EB $(OBJECTS) -o $@

inst_rom.bin: inst_rom.om
	$(OBJCOPY) --only-section=.text -O verilog $< $@

inst_rom.data: inst_rom.bin
	cp $< $@
	sed -i '1d' $@
	sed -i 's/ //g' $@
	sed -i 's_\(.\{8\}\)_\1\n_g' $@

clean:
	rm -f *.o *.om *.bin *.data