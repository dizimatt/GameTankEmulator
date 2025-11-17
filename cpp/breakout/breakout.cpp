// ====================================================================
// BREAKOUT for Game Tank
// A classic brick-breaking game ported from 6502 assembly to C++
// ====================================================================
//
// Controls:
//   LEFT/RIGHT - Move paddle
//   A - Launch ball (when on paddle)
//
// Gameplay:
//   - Break all bricks to win
//   - Don't let the ball fall off the bottom
//   - 3 lives to start
// ====================================================================

#include "gametank.h"

// Game constants
#define PADDLE_WIDTH    24
#define PADDLE_HEIGHT   4
#define PADDLE_Y        115
#define PADDLE_SPEED    2

#define BALL_SIZE       3
#define BALL_SPEED_X    2
#define BALL_SPEED_Y    2

#define BRICK_WIDTH     15
#define BRICK_HEIGHT    6
#define BRICK_ROWS      6
#define BRICK_COLS      8
#define BRICK_START_X   4
#define BRICK_START_Y   10
#define BRICK_SPACING_X 16
#define BRICK_SPACING_Y 7

#define TOTAL_BRICKS    (BRICK_ROWS * BRICK_COLS)

// Brick structure (4 bytes per brick)
struct Brick {
    uint8_t x;          // X position
    uint8_t y;          // Y position
    uint8_t color;      // Color/type (1-6)
    uint8_t active;     // Active flag (0 = destroyed, 1 = active)
};

// Global game state variables
volatile uint8_t did_vsync = 0;
uint8_t bank_mirror;
uint8_t dma_mirror;
uint8_t frame_count;

uint8_t paddle_x;
uint8_t ball_x;
uint8_t ball_y;
int8_t ball_vx;         // Signed velocity X
int8_t ball_vy;         // Signed velocity Y
uint8_t ball_state;     // 0 = on paddle, 1 = active

uint8_t input_buffer;
uint8_t prev_input;

uint16_t score;
uint8_t lives;
uint8_t bricks_left;

// Brick array - 48 bricks (6 rows × 8 columns)
Brick bricks[TOTAL_BRICKS];

// ====================================================================
// Forward declarations
// ====================================================================
void init_game();
void init_bricks();
void read_input();
void update_game();
void update_paddle();
void update_ball();
void draw_game();
void draw_bricks();
void draw_paddle();
void draw_ball();
void draw_hud();
uint8_t get_brick_color(uint8_t color_index);

// ====================================================================
// NMI Interrupt Handler - Called on VSync
// ====================================================================
void nmi_handler() __attribute__((interrupt));
void nmi_handler() {
    did_vsync = 1;
}

// ====================================================================
// IRQ Interrupt Handler - Called when DMA blit completes
// ====================================================================
void irq_handler() __attribute__((interrupt));
void irq_handler() {
    // Nothing to do for now
}

// ====================================================================
// Main entry point
// ====================================================================
int main() {
    // Disable interrupts during setup
    __asm__ volatile("sei");

    // Initialize DMA flags
    dma_mirror = DMA_ENABLE | NOTILE | BLIT_IRQ;
    DMA_FLAGS = dma_mirror;

    // Initialize bank flags
    bank_mirror = VRAMBANK2 | CLIP_X | CLIP_Y;
    BANK_FLAGS = bank_mirror;

    // Initialize game state
    init_game();

    // Enable interrupts
    __asm__ volatile("cli");

    // Main game loop
    while (1) {
        // Clear the screen to black
        clear_screen();

        // Read controller input
        read_input();

        // Update game logic
        update_game();

        // Draw game elements
        draw_game();

        // Wait for VSync
        wait_vsync();

        // Swap framebuffers
        swap_buffers();

        // Increment frame counter
        frame_count++;
    }

    return 0;
}

// ====================================================================
// INIT GAME - Initialize all game variables
// ====================================================================
void init_game() {
    // Initialize paddle
    paddle_x = (SCREEN_WIDTH - PADDLE_WIDTH) / 2;

    // Initialize ball on paddle
    ball_state = 0;     // Ball starts on paddle
    ball_vx = 0;
    ball_vy = 0;
    ball_x = (SCREEN_WIDTH - BALL_SIZE) / 2;
    ball_y = PADDLE_Y - BALL_SIZE - 1;

    // Initialize score and lives
    score = 0;
    lives = 3;

    // Initialize frame counter
    frame_count = 0;
    did_vsync = 0;

    // Initialize input
    input_buffer = 0;
    prev_input = 0;

    // Initialize bricks
    init_bricks();
}

// ====================================================================
// INIT BRICKS - Set up the brick array with struct data
// ====================================================================
void init_bricks() {
    bricks_left = 0;

    for (uint8_t idx = 0; idx < TOTAL_BRICKS; idx++) {
        // Calculate row and column
        uint8_t row = idx / 8;          // idx >> 3
        uint8_t col = idx & 0x07;       // idx & 7

        // Calculate X position: column * BRICK_SPACING_X + BRICK_START_X
        bricks[idx].x = (col << 4) + BRICK_START_X;  // col * 16 + 4

        // Calculate Y position: row * BRICK_SPACING_Y + BRICK_START_Y
        bricks[idx].y = (row * 7) + BRICK_START_Y;

        // Calculate color based on row: 1=Red, 2=Orange, 3=Yellow, 4=Green, 5=Cyan, 6=Blue
        bricks[idx].color = row + 1;

        // Set as active
        bricks[idx].active = 1;

        // Increment brick count
        bricks_left++;
    }
}

// ====================================================================
// READ INPUT - Read gamepad state
// ====================================================================
void read_input() {
    // Save previous input
    prev_input = input_buffer;

    // Reset gamepad shift register
    (void)GAMEPAD2;

    // First read to sync
    (void)GAMEPAD1;

    // Second read for full button state
    input_buffer = GAMEPAD1 ^ 0xFF;  // Invert (buttons are active-low)
}

// ====================================================================
// UPDATE GAME - Game logic
// ====================================================================
void update_game() {
    update_paddle();
    update_ball();
}

// ====================================================================
// UPDATE PADDLE - Handle paddle movement
// ====================================================================
void update_paddle() {
    // Check RIGHT button
    if (input_buffer & BTN_RIGHT) {
        // Move paddle right
        uint8_t new_x = paddle_x + PADDLE_SPEED;
        if (new_x < (SCREEN_WIDTH - PADDLE_WIDTH)) {
            paddle_x = new_x;
        }
    }

    // Check LEFT button
    if (input_buffer & BTN_LEFT) {
        // Move paddle left
        if (paddle_x >= PADDLE_SPEED) {
            paddle_x -= PADDLE_SPEED;
        }
    }
}

// ====================================================================
// UPDATE BALL - Ball physics and collision
// ====================================================================
void update_ball() {
    // Check if ball is on paddle
    if (ball_state == 0) {
        // Ball on paddle - follow paddle X position
        ball_x = paddle_x + ((PADDLE_WIDTH - BALL_SIZE) / 2);

        // Check for launch (A button pressed this frame)
        if ((input_buffer & BTN_A) && !(prev_input & BTN_A)) {
            // Launch ball
            ball_state = 1;
            ball_vx = BALL_SPEED_X;
            ball_vy = -BALL_SPEED_Y;  // Negative (upward)
        }
        return;
    }

    // Ball is active - update position
    ball_x += ball_vx;
    ball_y += ball_vy;

    // Check left wall collision
    if (ball_x == 0) {
        ball_vx = -ball_vx;
        ball_x = 1;
    }
    // Check right wall collision
    else if (ball_x + BALL_SIZE >= SCREEN_WIDTH) {
        ball_vx = -ball_vx;
        ball_x = SCREEN_WIDTH - BALL_SIZE - 1;
    }

    // Check top wall collision
    if (ball_y < 8) {
        ball_vy = -ball_vy;
        ball_y = 8;
    }
    // Check bottom (ball lost)
    else if (ball_y >= SCREEN_HEIGHT - 2) {
        // Ball lost - reset to paddle
        lives--;
        ball_state = 0;
        ball_x = (SCREEN_WIDTH - BALL_SIZE) / 2;
        ball_y = PADDLE_Y - BALL_SIZE - 1;
        ball_vx = 0;
        ball_vy = 0;
        return;
    }

    // Check paddle collision
    if (ball_y >= PADDLE_Y - BALL_SIZE && ball_y < PADDLE_Y + PADDLE_HEIGHT) {
        // Check X overlap
        if (ball_x + BALL_SIZE > paddle_x && paddle_x + PADDLE_WIDTH > ball_x) {
            // Collision with paddle!
            if (ball_y < PADDLE_Y) {
                // Position ball above paddle
                ball_y = PADDLE_Y - BALL_SIZE - 1;

                // Reverse Y velocity (bounce up)
                if (ball_vy > 0) {
                    ball_vy = -ball_vy;
                }

                // Ensure ball is moving horizontally
                if (ball_vx == 0) {
                    ball_vx = BALL_SPEED_X;
                }
            }
        }
    }

    // Check brick collision
    // Only check bricks if ball is in brick area
    if (ball_y < BRICK_START_Y || ball_y >= BRICK_START_Y + (BRICK_ROWS * BRICK_SPACING_Y) + BRICK_HEIGHT) {
        return;
    }

    // Check all bricks
    for (uint8_t idx = 0; idx < TOTAL_BRICKS; idx++) {
        // Skip destroyed bricks
        if (!bricks[idx].active) {
            continue;
        }

        // Check X overlap
        if (ball_x + BALL_SIZE <= bricks[idx].x || bricks[idx].x + BRICK_WIDTH <= ball_x) {
            continue;
        }

        // Check Y overlap
        if (ball_y + BALL_SIZE <= bricks[idx].y || bricks[idx].y + BRICK_HEIGHT <= ball_y) {
            continue;
        }

        // Collision detected!
        bricks[idx].active = 0;

        // Reverse ball Y velocity
        ball_vy = -ball_vy;

        // Increment score
        score++;

        // Decrement brick count
        bricks_left--;

        // Only hit one brick per frame
        break;
    }
}

// ====================================================================
// DRAW GAME - Render all game elements
// ====================================================================
void draw_game() {
    draw_bricks();
    draw_paddle();
    draw_ball();
    draw_hud();
}

// ====================================================================
// GET BRICK COLOR - Map brick color index to actual color value
// ====================================================================
uint8_t get_brick_color(uint8_t color_index) {
    switch (color_index) {
        case 1: return HUE_RED | SAT_FULL | 4;
        case 2: return HUE_ORANGE | SAT_FULL | 4;
        case 3: return HUE_YELLOW | SAT_FULL | 4;
        case 4: return HUE_GREEN | SAT_FULL | 4;
        case 5: return HUE_CYAN | SAT_FULL | 4;
        case 6: return HUE_BLUE | SAT_FULL | 4;
        default: return HUE_BLUE | SAT_FULL | 4;
    }
}

// ====================================================================
// DRAW BRICKS - Draw all active bricks
// ====================================================================
void draw_bricks() {
    for (uint8_t idx = 0; idx < TOTAL_BRICKS; idx++) {
        // Check if brick is active
        if (!bricks[idx].active) {
            continue;
        }

        // Get brick color
        uint8_t color = get_brick_color(bricks[idx].color);

        // Draw brick
        draw_rect(bricks[idx].x, bricks[idx].y, BRICK_WIDTH, BRICK_HEIGHT, color);
    }
}

// ====================================================================
// DRAW PADDLE - Draw the player paddle
// ====================================================================
void draw_paddle() {
    uint8_t color = HUE_RED | SAT_FULL | 5;
    draw_rect(paddle_x, PADDLE_Y, PADDLE_WIDTH, PADDLE_HEIGHT, color);
}

// ====================================================================
// DRAW BALL - Draw the ball
// ====================================================================
void draw_ball() {
    uint8_t color = HUE_GREEN | SAT_NONE | 7;  // White
    draw_rect(ball_x, ball_y, BALL_SIZE, BALL_SIZE, color);
}

// ====================================================================
// DRAW HUD - Draw lives and score indicators
// ====================================================================
void draw_hud() {
    // Draw lives as small rectangles in top-left
    uint8_t color = HUE_RED | SAT_FULL | 5;
    uint8_t x_pos = 2;

    for (uint8_t i = 0; i < lives; i++) {
        draw_rect(x_pos, 2, 3, 3, color);
        x_pos += 5;
    }
}
