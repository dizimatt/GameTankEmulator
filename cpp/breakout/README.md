# Breakout - C++ Port for GameTank

This is a complete C++ port of the Breakout game from the assembly version found in `asm/breakout/`. The port maintains **exact functional equivalence** with the original 6502 assembly code while providing the benefits of a higher-level language.

## Overview

This C++ implementation provides:
- **Exact same gameplay** as the assembly version
- **Same memory layout** for game state and structures
- **Identical collision detection** algorithms
- **Matching visual output** including colors and rendering

## Files

- **`gametank.h`** - Hardware abstraction layer for GameTank registers and DMA operations
- **`breakout.cpp`** - Main game code ported from assembly
- **`Makefile`** - Build configuration for WDC65C02 C compiler or CC65

## Game Features

### Controls
- **LEFT/RIGHT** - Move paddle
- **A Button** - Launch ball (when on paddle)

### Gameplay
- Break all 48 bricks arranged in 6 colorful rows
- 3 lives to start
- Don't let the ball fall off the bottom
- Each brick is worth 1 point

### Technical Details
- **Screen**: 128x128 pixels
- **Paddle**: 24x4 pixels at bottom of screen
- **Ball**: 3x3 pixels
- **Bricks**: 15x6 pixels each, 6 rows × 8 columns
- **Double buffering** for smooth rendering
- **VSync synchronization** for consistent frame rate

## Code Structure

### Hardware Abstraction (`gametank.h`)

Provides clean C++ interface to GameTank hardware:

```cpp
// Register definitions
#define DMA_VX          (*(volatile uint8_t*)0x4000)
#define GAMEPAD1        (*(volatile uint8_t*)0x2008)

// Helper functions
void draw_rect(uint8_t x, uint8_t y, uint8_t w, uint8_t h, uint8_t color);
void wait_vsync();
void swap_buffers();
```

### Brick Structure

Each brick is a 4-byte structure matching the assembly layout:

```cpp
struct Brick {
    uint8_t x;          // X position
    uint8_t y;          // Y position
    uint8_t color;      // Color/type (1-6)
    uint8_t active;     // Active flag (0 = destroyed, 1 = active)
};
```

**Total memory**: 192 bytes for 48 bricks (same as assembly version)

### Game State Variables

All global variables match the assembly version's zero-page layout:

```cpp
volatile uint8_t did_vsync;      // $00 - VSync flag
uint8_t bank_mirror;             // $01 - Bank flags mirror
uint8_t dma_mirror;              // $02 - DMA flags mirror
uint8_t paddle_x;                // $04 - Paddle X position
uint8_t ball_x, ball_y;          // $05-$06 - Ball position
int8_t ball_vx, ball_vy;         // $07-$08 - Ball velocity (signed)
// ... etc
```

## Assembly vs C++ Comparison

### Assembly Version (Original)
```asm
UpdatePaddle:
    LDA input_buffer
    AND #BTN_RIGHT
    BEQ CheckLeft
    LDA paddle_x
    CLC
    ADC #PADDLE_SPEED
    CMP #(SCREEN_WIDTH - PADDLE_WIDTH)
    BCS CheckLeft
    STA paddle_x
CheckLeft:
    ; ... etc
```

### C++ Port (This Version)
```cpp
void update_paddle() {
    if (input_buffer & BTN_RIGHT) {
        uint8_t new_x = paddle_x + PADDLE_SPEED;
        if (new_x < (SCREEN_WIDTH - PADDLE_WIDTH)) {
            paddle_x = new_x;
        }
    }
    if (input_buffer & BTN_LEFT) {
        if (paddle_x >= PADDLE_SPEED) {
            paddle_x -= PADDLE_SPEED;
        }
    }
}
```

## Key Implementation Details

### 1. Exact Collision Detection

The C++ port replicates the assembly's AABB (Axis-Aligned Bounding Box) collision:

```cpp
// Check X overlap
if (ball_x + BALL_SIZE <= bricks[idx].x ||
    bricks[idx].x + BRICK_WIDTH <= ball_x) {
    continue;  // No collision
}
```

### 2. Signed Velocity

Ball velocity uses `int8_t` for signed 8-bit values:
```cpp
int8_t ball_vx;  // Can be negative (left) or positive (right)
int8_t ball_vy;  // Can be negative (up) or positive (down)
```

In assembly, this was: `LDA #256-BALL_SPEED_Y` for negative values.

### 3. Hardware Direct Access

Hardware registers are accessed via volatile pointers:
```cpp
#define DMA_VX (*(volatile uint8_t*)0x4000)
DMA_VX = ball_x;  // Direct hardware write
```

The `volatile` keyword prevents compiler optimization that might break hardware interaction.

### 4. Interrupt Handlers

C++ interrupt handlers use GCC attributes:
```cpp
void nmi_handler() __attribute__((interrupt));
void nmi_handler() {
    did_vsync = 1;
}
```

### 5. Wait Instructions

Assembly `WAI` instruction is replicated with inline assembly:
```cpp
inline void wait_blit() {
    __asm__ volatile("wai");
}
```

## Compilation Requirements

This code requires a C compiler for the WDC 65C02 processor:

### Option 1: WDC C Compiler (Commercial)
```bash
wdc816cc -mt -ml -wl -HT -L -Pentry_point=0xE000 -o breakout.gtr breakout.cpp
```

### Option 2: CC65 (Open Source)
```bash
cl65 -t none -O --config gametank.cfg -o breakout.gtr breakout.cpp
```

**Note**: CC65 requires a custom linker configuration file (`gametank.cfg`) to properly map memory segments.

## Memory Map

The compiled ROM should match this layout:

| Address Range | Usage |
|---------------|-------|
| `$0000-$00FF` | Zero page (global variables) |
| `$0100-$01FF` | Stack |
| `$0200-$1FFF` | BSS/Data (brick array, etc.) |
| `$E000-$FFF9` | Code (program) |
| `$FFFA-$FFFB` | NMI vector |
| `$FFFC-$FFFD` | RESET vector |
| `$FFFE-$FFFF` | IRQ vector |

## Differences from Assembly

While functionally equivalent, the C++ version offers:

### Advantages:
- ✅ **More readable** - Clearer logic flow
- ✅ **Type safety** - Compile-time type checking
- ✅ **Easier to modify** - Add features without complex register management
- ✅ **Portable concepts** - Logic can be adapted to other platforms
- ✅ **Better tooling** - IDE support, debugging, etc.

### Trade-offs:
- ⚠️ **Larger code** - C compiler generates more instructions than hand-optimized assembly
- ⚠️ **Less control** - Compiler decides instruction selection and optimization
- ⚠️ **Potentially slower** - May not use zero-page addressing as efficiently

## Testing

To test this port:

1. **Compile** the code using an appropriate 65C02 C compiler
2. **Load** the resulting `breakout.gtr` file into the GameTank emulator
3. **Verify** gameplay matches the assembly version:
   - Paddle movement responds correctly
   - Ball launches and bounces properly
   - Brick collision detection works
   - Lives decrement when ball falls
   - Score increments when bricks are destroyed

## Future Enhancements

The C++ structure makes it easy to add:
- Multiple ball speeds based on paddle hit position
- Power-ups and special bricks
- Sound effects (using GameTank audio processor)
- Multiple levels with different brick patterns
- Score display using sprite-based numbers
- Particle effects for brick destruction

## Related Files

- **Assembly version**: `../../asm/breakout/breakout.asm`
- **Assembly Makefile**: `../../asm/breakout/Makefile`
- **Assembly README**: `../../asm/breakout/README.md`

## License

Same license as the original assembly version and the GameTank emulator project.

## Credits

- **Original Assembly Version**: Created for GameTank
- **C++ Port**: Direct translation maintaining exact functionality
- **GameTank Platform**: Hardware design and emulator
