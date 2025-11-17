// ====================================================================
// GameTank Hardware Abstraction Layer
// Hardware register definitions and helper functions
// ====================================================================

#ifndef GAMETANK_H
#define GAMETANK_H

#include <stdint.h>

// Hardware register addresses (volatile to prevent optimization)
#define DMA_VX          (*(volatile uint8_t*)0x4000)
#define DMA_VY          (*(volatile uint8_t*)0x4001)
#define DMA_GX          (*(volatile uint8_t*)0x4002)
#define DMA_GY          (*(volatile uint8_t*)0x4003)
#define DMA_WIDTH       (*(volatile uint8_t*)0x4004)
#define DMA_HEIGHT      (*(volatile uint8_t*)0x4005)
#define DMA_STATUS      (*(volatile uint8_t*)0x4006)
#define DMA_COLOR       (*(volatile uint8_t*)0x4007)

#define BANK_FLAGS      (*(volatile uint8_t*)0x2005)
#define DMA_FLAGS       (*(volatile uint8_t*)0x2007)
#define GAMEPAD1        (*(volatile uint8_t*)0x2008)
#define GAMEPAD2        (*(volatile uint8_t*)0x2009)

// DMA_FLAGS bit definitions
#define DMA_ENABLE      0x01
#define VID_OUT_PAGE2   0x02
#define VNMI_ENABLE     0x04
#define COLORFILL       0x08
#define NOTILE          0x10
#define MAP_FRAMEBUFFER 0x20
#define BLIT_IRQ        0x40
#define TRANSPARENCY    0x80

// BANK_FLAGS bit definitions
#define VRAMBANK2       0x08
#define CLIP_X          0x10
#define CLIP_Y          0x20

// Color definitions (HHHSSBBB format)
#define HUE_GREEN       0x00
#define HUE_YELLOW      0x20
#define HUE_ORANGE      0x40
#define HUE_RED         0x60
#define HUE_MAGENTA     0x80
#define HUE_INDIGO      0xA0
#define HUE_BLUE        0xC0
#define HUE_CYAN        0xE0

#define SAT_NONE        0x00
#define SAT_SOME        0x08
#define SAT_MORE        0x10
#define SAT_FULL        0x18

// Input button masks
#define BTN_RIGHT       0x01
#define BTN_LEFT        0x02
#define BTN_DOWN        0x04
#define BTN_UP          0x08
#define BTN_A           0x10
#define BTN_B           0x20

// Screen dimensions
#define SCREEN_WIDTH    128
#define SCREEN_HEIGHT   128

// Global state variables
extern volatile uint8_t did_vsync;
extern uint8_t bank_mirror;
extern uint8_t dma_mirror;

// Wait for DMA blit to complete
inline void wait_blit() {
    __asm__ volatile("wai");
}

// Wait for vertical sync
inline void wait_vsync() {
    while (did_vsync == 0);
    did_vsync = 0;
}

// Swap framebuffers for double buffering
inline void swap_buffers() {
    // Toggle VRAMBANK2 in bank flags
    bank_mirror ^= VRAMBANK2;
    BANK_FLAGS = bank_mirror;

    // Toggle VID_OUT_PAGE2 in DMA flags
    dma_mirror ^= VID_OUT_PAGE2;
    DMA_FLAGS = dma_mirror;
}

// Draw a colored rectangle
inline void draw_rect(uint8_t x, uint8_t y, uint8_t width, uint8_t height, uint8_t color) {
    DMA_FLAGS = dma_mirror | COLORFILL;
    DMA_VX = x;
    DMA_VY = y;
    DMA_WIDTH = width;
    DMA_HEIGHT = height;
    DMA_COLOR = ~color;  // Invert color for DMA
    DMA_STATUS = 1;
    wait_blit();
}

// Clear screen to black
inline void clear_screen() {
    draw_rect(0, 0, 127, 127, 8);  // Black (low brightness)
}

#endif // GAMETANK_H
