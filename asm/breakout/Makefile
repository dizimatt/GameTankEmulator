# Makefile for Breakout Game
# Usage: make -f Makefile.breakout

ASM = vasm6502_oldstyle
AFLAGS = -dotdir -wdc02 -Fbin

breakout.gtr: breakout.asm
	$(ASM) $(AFLAGS) -o $@ $<

clean:
	rm -f breakout.gtr

.PHONY: clean
