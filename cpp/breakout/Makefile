# Makefile for Breakout C++ Port for GameTank
# Requires WDC65C02 C++ compiler or compatible toolchain

# Target ROM file
TARGET = breakout.gtr

# Source files
SOURCES = breakout.cpp

# Compiler settings for WDC65C02
CC = wdc816cc
CXX = wdc816cc
CXXFLAGS = -mt -ml -wl
LDFLAGS = -HT -L -Pentry_point=0xE000

# Alternative: Using cc65 toolchain
# CC = cl65
# CXX = cl65
# CXXFLAGS = -t none -O
# LDFLAGS = --config gametank.cfg -o $(TARGET)

# Build rules
all: $(TARGET)

$(TARGET): $(SOURCES) gametank.h
	@echo "Building Breakout C++ port for GameTank..."
	@echo "Note: This Makefile assumes a WDC65C02 C compiler is installed."
	@echo "Adjust CC, CXX, and flags as needed for your toolchain."
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $(SOURCES)

clean:
	rm -f $(TARGET) *.o *.obj *.lst

.PHONY: all clean

# Notes for compilation:
#
# This code is designed to be compiled for the WDC 65C02 processor.
# You will need an appropriate C compiler for the 65C02 architecture.
#
# Options include:
# 1. WDC C Compiler (wdc816cc) - Commercial
# 2. CC65 (cc65) - Open source C compiler for 6502 family
#
# For CC65, you would need to create a custom linker configuration
# file (gametank.cfg) that maps:
# - CODE segment to ROM area (0xE000-0xFFFF for 8K ROM)
# - DATA/BSS segments to RAM area (0x0000-0x1FFF)
# - Interrupt vectors at 0xFFFA-0xFFFF
#
# Memory map requirements:
# - Zero page variables: 0x0000-0x00FF
# - Stack: 0x0100-0x01FF
# - BSS/DATA: 0x0200-0x1FFF (avoid 0x0200-0x04FD if using zlib6502)
# - Code: 0xE000-0xFFF9 (for 8K ROM)
# - Vectors: 0xFFFA-0xFFFF (NMI, RESET, IRQ)
