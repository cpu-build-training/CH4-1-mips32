ifndef CROSS_COMPILE
CROSS_COMPILE = mipsel-linux-gnu-
endif
CC = $(CROSS_COMPILE)as
LD = $(CROSS_COMPILE)ld
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump
V := @

OBJECTS = inst_rom.o
SOURCE = $(shell ls *.S | sort -nr | head -n1 | tr -d '\n')

export CROSS_COMPILE

all: inst_rom.data

# strip all the comment, now we can write chinese character in .S file.
inst_rom.Ss: $(SOURCE)
	$(V)sed -e 's/#.*//' $< > $@

$(OBJECTS): inst_rom.Ss
	$(V)$(CC) -mips32 $< -o $(OBJECTS)

inst_rom.om: ram.ld $(OBJECTS)
	$(V)$(LD) -T ram.ld $(OBJECTS) -o $@

inst_rom.bin: inst_rom.om
	$(V)$(OBJCOPY) --only-section=.text -O verilog $< $@

inst_rom.data: inst_rom.bin
	$(V)cp $< $@
	$(V)sed -i '1d' $@
	$(V)sed -i 's/ //g' $@
	$(V)sed -i 's_\(.\{8\}\)_\1\n_g' $@
	$(V)sed -i '/^\s*$$/d' $@

clean:
	$(V)rm -f *.o *.om *.bin *.data *.Ss