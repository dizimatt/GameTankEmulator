# Breakout for Game Tank

A classic brick-breaking arcade game written in 6502 assembly for the Game Tank console.

## Game Description

Breakout is a classic arcade game where you control a paddle at the bottom of the screen to bounce a ball and break all the bricks at the top. Don't let the ball fall off the bottom or you'll lose a life!

### Features

- **6 rows of colored bricks** (48 total)
- **Paddle movement** with left/right controls
- **Ball physics** with wall and paddle bouncing
- **Brick collision detection** - ball destroys bricks on contact
- **Score tracking** - points for each brick destroyed
- **Lives system** - 3 lives to start
- **Color-coded brick rows** (Red, Orange, Yellow, Green, Cyan, Blue)
- **Visual HUD** showing remaining lives

### Controls

| Button | Action |
|--------|--------|
| **LEFT** | Move paddle left |
| **RIGHT** | Move paddle right |
| **A Button** | Launch ball (when ball is on paddle) |

Keyboard mapping (on emulator):
- Arrow keys: D-pad
- Z: A button
- X: B button
- C: C button
- Enter: Start

## Technical Details

### Memory Usage

- **ROM Size**: 8KB (will be mapped to $E000-$FFFF)
- **RAM Usage**:
  - Zero page: $00-$18 (game variables)
  - Brick array: $0100-$012F (48 bytes for brick state)
  - Stack: $0100-$01FF (standard 6502 stack)

### Game Constants

```
Paddle: 24×4 pixels, Red color
Ball: 3×3 pixels, White
Bricks: 15×6 pixels each
Brick Grid: 8 columns × 6 rows
Screen: 128×128 pixels
```

### Graphics System

The game uses the Game Tank's DMA blitter in **COLORFILL** mode to draw solid colored rectangles:
- Double-buffered rendering for smooth animation
- VSync synchronization for 60 FPS
- No sprite data needed - all graphics are procedural rectangles

### Physics

- **Ball Speed**: 2 pixels per frame in X and Y directions
- **Paddle Speed**: 2 pixels per frame
- **Collision Detection**: Simple AABB (axis-aligned bounding box) collision
- **Ball Bounce**: Velocity reversal on wall/paddle/brick contact

## Building the Game

### Prerequisites

You need the [VASM assembler](http://sun.hasenbraten.de/vasm/) for WDC65C02:

1. Download VASM from http://sun.hasenbraten.de/vasm/
2. Build the `vasm6502_oldstyle` executable
3. Add it to your PATH

### Compilation

```bash
# From the asm/ directory:
make -f Makefile.breakout

# Or manually:
vasm6502_oldstyle -dotdir -wdc02 -Fbin -o breakout.gtr breakout.asm
```

This will produce `breakout.gtr` - a Game Tank ROM file.

### Running on Emulator

```bash
# From the GameTankEmulator directory:
./GameTankEmulator breakout.gtr

# Or drag and drop breakout.gtr onto the emulator executable
```

## Gameplay

1. **Start**: When the game begins, the ball sits on the paddle
2. **Launch**: Press A button to launch the ball upward
3. **Break Bricks**: The ball will bounce off bricks, destroying them
4. **Keep Bouncing**: Use the paddle to prevent the ball from falling
5. **Win**: Destroy all 48 bricks
6. **Lose**: If the ball falls off the bottom, you lose a life
7. **Game Over**: When all 3 lives are lost

### Scoring

- Each brick destroyed: +1 point
- Maximum possible score: 48 points (all bricks)

## Code Architecture

### Main Sections

1. **Hardware Definitions** ($E000+)
   - Register addresses and bit flags
   - Color constants
   - Game constants

2. **Game Variables** (Zero Page)
   - Paddle position
   - Ball position and velocity
   - Game state (lives, score, brick count)

3. **Initialization** (RESET)
   - Set up DMA and graphics system
   - Initialize game state
   - Initialize brick array

4. **Main Loop**
   - Clear screen
   - Read input
   - Update game logic
   - Draw all elements
   - Wait for VSync
   - Swap framebuffers

5. **Game Logic Routines**
   - `UpdatePaddle`: Handle paddle movement
   - `UpdateBall`: Ball physics and collision detection
   - `InitBricks`: Set up brick array
   - `GetBrickPosition`: Calculate brick X,Y from index

6. **Drawing Routines**
   - `DrawBricks`: Render all active bricks
   - `DrawPaddle`: Render player paddle
   - `DrawBall`: Render ball
   - `DrawHUD`: Draw lives indicator
   - `ClearScreen`: Fill screen with black

7. **Interrupt Handlers**
   - `NMI`: VSync interrupt (sets flag)
   - `IRQ`: DMA completion interrupt

### Collision Detection Algorithm

The game uses simple rectangular collision detection:

1. **Wall Collision**: Check if ball X/Y exceeds screen bounds
2. **Paddle Collision**: Check if ball rectangle overlaps paddle rectangle
3. **Brick Collision**:
   - Only check bricks in the brick area (Y coordinate check)
   - Iterate through all 48 bricks
   - For each active brick, check rectangle overlap
   - Destroy brick on collision and reverse ball Y velocity

### Double-Buffering

The game uses two framebuffers to avoid screen tearing:

1. **Page 1** and **Page 2** framebuffers
2. While one is being displayed, draw to the other
3. On VSync, swap which buffer is displayed
4. Achieved via `VRAMBANK2` and `VID_OUT_PAGE2` flags

## Customization Ideas

You can modify these constants to change gameplay:

```asm
; Make paddle faster/slower
PADDLE_SPEED    = 2     ; Try 1-4

; Make ball faster/slower
BALL_SPEED_X    = 2     ; Try 1-3
BALL_SPEED_Y    = 2     ; Try 1-3

; Change brick layout
BRICK_ROWS      = 6     ; Try 4-8
BRICK_COLS      = 8     ; Try 6-10

; Change paddle size
PADDLE_WIDTH    = 24    ; Try 16-32
```

## Known Limitations

1. **No sound effects** - Audio system not implemented (would require separate audio coprocessor code)
2. **Simple physics** - Ball velocity doesn't change based on paddle hit location
3. **No ball spin** - Ball always bounces at same angle
4. **Fixed difficulty** - Ball speed doesn't increase
5. **No power-ups** - No special bricks or paddle enhancements
6. **Simple graphics** - No sprites, just colored rectangles

## Future Enhancements

Possible improvements:

- [ ] Add audio using the audio coprocessor
- [ ] Variable ball angle based on paddle hit position
- [ ] Multiple balls power-up
- [ ] Paddle size power-ups
- [ ] Animated brick destruction
- [ ] High score persistence (if save RAM available)
- [ ] Multiple levels with different layouts
- [ ] Particle effects for brick explosions

## License

This game is released as a demonstration of Game Tank programming. Feel free to modify, learn from, and build upon this code.

## Credits

Written as a tutorial example for the Game Tank console.

For more information about Game Tank:
- Emulator: https://github.com/clydeshaffer/GameTankEmulator
- Hardware: https://gametank.zone/

## Technical Reference

For detailed information about Game Tank hardware and programming:
- See `/asm/Tutorial/` directory for more examples
- See `README.md` in the main repository
- Hardware registers documented in `src/gte.cpp` and `src/blitter.h`
