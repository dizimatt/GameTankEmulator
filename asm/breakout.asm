; ====================================================================
; BREAKOUT for Game Tank
; A classic brick-breaking game in 6502 assembly
; ====================================================================
;
; Controls:
;   LEFT/RIGHT - Move paddle
;   A - Launch ball (when on paddle)
;
; Gameplay:
;   - Break all bricks to win
;   - Don't let the ball fall off the bottom
;   - 3 lives to start
; ====================================================================

; Hardware register addresses
DMA_VX          = $4000
DMA_VY          = $4001
DMA_GX          = $4002
DMA_GY          = $4003
DMA_WIDTH       = $4004
DMA_HEIGHT      = $4005
DMA_Status      = $4006
DMA_Color       = $4007

Bank_Flags      = $2005
DMA_Flags       = $2007
GamePad1        = $2008
GamePad2        = $2009

; DMA_Flags bit definitions
DMA_ENABLE      = %00000001
VID_OUT_PAGE2   = %00000010
VNMI_ENABLE     = %00000100
COLORFILL       = %00001000
NOTILE          = %00010000
MAP_FRAMEBUFFER = %00100000
BLIT_IRQ        = %01000000
TRANSPARENCY    = %10000000

; Bank_Flags bit definitions
VRAMBANK2       = %00001000
CLIP_X          = %00010000
CLIP_Y          = %00100000

; Color definitions (HHHSSBBB)
HUE_GREEN       = $00
HUE_YELLOW      = $20
HUE_ORANGE      = $40
HUE_RED         = $60
HUE_MAGENTA     = $80
HUE_INDIGO      = $A0
HUE_BLUE        = $C0
HUE_CYAN        = $E0

SAT_NONE        = $00
SAT_SOME        = $08
SAT_MORE        = $10
SAT_FULL        = $18

; Game constants
PADDLE_WIDTH    = 24
PADDLE_HEIGHT   = 4
PADDLE_Y        = 115
PADDLE_SPEED    = 2

BALL_SIZE       = 3
BALL_SPEED_X    = 2
BALL_SPEED_Y    = 2

BRICK_WIDTH     = 15
BRICK_HEIGHT    = 6
BRICK_ROWS      = 6
BRICK_COLS      = 8
BRICK_START_X   = 4
BRICK_START_Y   = 10
BRICK_SPACING_X = 16
BRICK_SPACING_Y = 7

SCREEN_WIDTH    = 128
SCREEN_HEIGHT   = 128

; Input button masks
BTN_RIGHT       = %00000001
BTN_LEFT        = %00000010
BTN_DOWN        = %00000100
BTN_UP          = %00001000
BTN_A           = %00010000
BTN_B           = %00100000

; Zero page variables
did_vsync       = $00
bank_mirror     = $01
dma_mirror      = $02
frame_count     = $03

paddle_x        = $04
ball_x          = $05
ball_y          = $06
ball_vx         = $07    ; Velocity X (signed)
ball_vy         = $08    ; Velocity Y (signed)
ball_state      = $09    ; 0 = on paddle, 1 = active

input_buffer    = $0A
prev_input      = $0B

score_lo        = $0C
score_hi        = $0D
lives           = $0E
bricks_left     = $0F

temp1           = $10
temp2           = $11
temp3           = $12
temp4           = $13

brick_x         = $14
brick_y         = $15
brick_idx       = $16
check_x         = $17
check_y         = $18

; Brick array - 48 bricks (6 rows × 8 columns)
; Each brick: 0 = destroyed, 1-7 = color/active
bricks          = $0100  ; 48 bytes at $0100-$012F

; ====================================================================
; RESET - Program entry point
; ====================================================================
.org $E000

RESET:
    ; Disable interrupts during setup
    SEI

    ; Initialize stack pointer
    LDX #$FF
    TXS

    ; Clear decimal mode
    CLD

    ; Initialize DMA flags
    LDA #(DMA_ENABLE | NOTILE | BLIT_IRQ)
    STA dma_mirror
    STA DMA_Flags

    ; Initialize bank flags
    LDA #(VRAMBANK2 | CLIP_X | CLIP_Y)
    STA bank_mirror
    STA Bank_Flags

    ; Initialize game state
    JSR InitGame

    ; Enable interrupts
    CLI

    ; Fall through to main loop

; ====================================================================
; MAIN GAME LOOP
; ====================================================================
MainLoop:
    ; Clear the screen to black
    JSR ClearScreen

    ; Read controller input
    JSR ReadInput

    ; Update game logic
    JSR UpdateGame

    ; Draw game elements
    JSR DrawGame

    ; Wait for VSync
    JSR WaitVSync

    ; Swap framebuffers
    JSR SwapBuffers

    ; Increment frame counter
    INC frame_count

    ; Loop forever
    JMP MainLoop

; ====================================================================
; INIT GAME - Initialize all game variables
; ====================================================================
InitGame:
    ; Initialize paddle
    LDA #((SCREEN_WIDTH - PADDLE_WIDTH) / 2)
    STA paddle_x

    ; Initialize ball on paddle
    LDA #0
    STA ball_state      ; Ball starts on paddle
    STA ball_vx
    STA ball_vy
    LDA #((SCREEN_WIDTH - BALL_SIZE) / 2)
    STA ball_x
    LDA #(PADDLE_Y - BALL_SIZE - 1)
    STA ball_y

    ; Initialize score and lives
    LDA #0
    STA score_lo
    STA score_hi
    LDA #3
    STA lives

    ; Initialize frame counter
    STZ frame_count
    STZ did_vsync

    ; Initialize input
    STZ input_buffer
    STZ prev_input

    ; Initialize bricks
    JSR InitBricks

    RTS

; ====================================================================
; INIT BRICKS - Set up the brick array
; ====================================================================
InitBricks:
    LDX #0
    LDA #0
    STA bricks_left

InitBricksLoop:
    ; Calculate row (brick_idx / 8)
    TXA
    AND #$F8            ; Mask to get row start
    LSR
    LSR
    LSR                 ; Divide by 8

    ; Color based on row: 1=Red, 2=Orange, 3=Yellow, 4=Green, 5=Cyan, 6=Blue
    CLC
    ADC #1
    STA bricks,X

    ; Increment brick count
    INC bricks_left

    INX
    CPX #(BRICK_ROWS * BRICK_COLS)
    BNE InitBricksLoop

    RTS

; ====================================================================
; READ INPUT - Read gamepad state
; ====================================================================
ReadInput:
    ; Save previous input
    LDA input_buffer
    STA prev_input

    ; Reset gamepad shift register
    LDA GamePad2

    ; First read to sync
    LDA GamePad1

    ; Second read for full button state
    LDA GamePad1
    EOR #$FF            ; Invert (buttons are active-low)
    STA input_buffer

    RTS

; ====================================================================
; UPDATE GAME - Game logic
; ====================================================================
UpdateGame:
    ; Update paddle position
    JSR UpdatePaddle

    ; Update ball
    JSR UpdateBall

    RTS

; ====================================================================
; UPDATE PADDLE - Handle paddle movement
; ====================================================================
UpdatePaddle:
    LDA input_buffer

    ; Check RIGHT button
    AND #BTN_RIGHT
    BEQ CheckLeft

    ; Move paddle right
    LDA paddle_x
    CLC
    ADC #PADDLE_SPEED
    CMP #(SCREEN_WIDTH - PADDLE_WIDTH)
    BCS CheckLeft       ; Don't move if at edge
    STA paddle_x

CheckLeft:
    LDA input_buffer
    AND #BTN_LEFT
    BEQ PaddleDone

    ; Move paddle left
    LDA paddle_x
    SEC
    SBC #PADDLE_SPEED
    BCC PaddleDone      ; Don't move if at edge (underflow)
    STA paddle_x

PaddleDone:
    RTS

; ====================================================================
; UPDATE BALL - Ball physics and collision
; ====================================================================
UpdateBall:
    ; Check if ball is on paddle
    LDA ball_state
    BNE BallActive

    ; Ball on paddle - follow paddle X position
    LDA paddle_x
    CLC
    ADC #((PADDLE_WIDTH - BALL_SIZE) / 2)
    STA ball_x

    ; Check for launch (A button pressed this frame)
    LDA input_buffer
    AND #BTN_A
    BEQ BallUpdateDone

    LDA prev_input
    AND #BTN_A
    BNE BallUpdateDone  ; Button was already pressed

    ; Launch ball
    LDA #1
    STA ball_state
    LDA #BALL_SPEED_X
    STA ball_vx
    LDA #256-BALL_SPEED_Y  ; Negative (upward)
    STA ball_vy
    JMP BallUpdateDone

BallActive:
    ; Update ball X position
    LDA ball_x
    CLC
    ADC ball_vx
    STA ball_x

    ; Check left wall collision
    LDA ball_x
    BEQ BallBounceX

    ; Check right wall collision
    CLC
    ADC #BALL_SIZE
    CMP #SCREEN_WIDTH
    BCS BallBounceX
    JMP CheckBallY

BallBounceX:
    ; Reverse X velocity
    LDA ball_vx
    EOR #$FF
    CLC
    ADC #1
    STA ball_vx

    ; Adjust position to be in bounds
    LDA ball_x
    BEQ FixRightWall
    ; Hit left wall
    LDA #1
    STA ball_x
    JMP CheckBallY

FixRightWall:
    LDA #(SCREEN_WIDTH - BALL_SIZE - 1)
    STA ball_x

CheckBallY:
    ; Update ball Y position
    LDA ball_y
    CLC
    ADC ball_vy
    STA ball_y

    ; Check top wall collision
    LDA ball_y
    CMP #8
    BCS CheckBottom
    LDA #8
    STA ball_y

BallBounceY:
    ; Reverse Y velocity
    LDA ball_vy
    EOR #$FF
    CLC
    ADC #1
    STA ball_vy
    JMP CheckPaddleCollision

CheckBottom:
    ; Check if ball fell off bottom
    LDA ball_y
    CMP #(SCREEN_HEIGHT - 2)
    BCC CheckPaddleCollision

    ; Ball lost - reset to paddle
    DEC lives
    LDA #0
    STA ball_state
    LDA #((SCREEN_WIDTH - BALL_SIZE) / 2)
    STA ball_x
    LDA #(PADDLE_Y - BALL_SIZE - 1)
    STA ball_y
    STZ ball_vx
    STZ ball_vy
    JMP BallUpdateDone

CheckPaddleCollision:
    ; Check if ball is at paddle Y level
    LDA ball_y
    CMP #(PADDLE_Y - BALL_SIZE)
    BCC CheckBrickCollision
    CMP #(PADDLE_Y + PADDLE_HEIGHT)
    BCS CheckBrickCollision

    ; Check if ball X overlaps paddle X
    LDA ball_x
    CLC
    ADC #BALL_SIZE
    CMP paddle_x
    BCC CheckBrickCollision  ; Ball right edge < paddle left

    LDA paddle_x
    CLC
    ADC #PADDLE_WIDTH
    CMP ball_x
    BCC CheckBrickCollision  ; Paddle right edge < ball left

    ; Collision with paddle!
    LDA ball_y
    CMP #PADDLE_Y
    BCS CheckBrickCollision  ; Already below paddle

    ; Position ball above paddle
    LDA #(PADDLE_Y - BALL_SIZE - 1)
    STA ball_y

    ; Reverse Y velocity (bounce up)
    LDA ball_vy
    BMI CheckBrickCollision  ; Already going up
    EOR #$FF
    CLC
    ADC #1
    STA ball_vy

    ; Adjust X velocity based on where ball hit paddle
    ; (Simple: just ensure it's moving)
    LDA ball_vx
    BNE CheckBrickCollision
    LDA #BALL_SPEED_X
    STA ball_vx

CheckBrickCollision:
    ; Only check bricks if ball is in brick area
    LDA ball_y
    CMP #BRICK_START_Y
    BCC BallUpdateDone
    CMP #(BRICK_START_Y + (BRICK_ROWS * BRICK_SPACING_Y) + BRICK_HEIGHT)
    BCS BallUpdateDone

    ; Check all bricks
    LDX #0
BrickCheckLoop:
    ; Skip destroyed bricks
    LDA bricks,X
    BEQ NextBrick

    ; Calculate brick position
    STX brick_idx
    JSR GetBrickPosition

    ; Check X overlap
    LDA ball_x
    CLC
    ADC #BALL_SIZE
    CMP brick_x
    BCC NextBrick       ; Ball right < brick left

    LDA brick_x
    CLC
    ADC #BRICK_WIDTH
    CMP ball_x
    BCC NextBrick       ; Brick right < ball left

    ; Check Y overlap
    LDA ball_y
    CLC
    ADC #BALL_SIZE
    CMP brick_y
    BCC NextBrick       ; Ball bottom < brick top

    LDA brick_y
    CLC
    ADC #BRICK_HEIGHT
    CMP ball_y
    BCC NextBrick       ; Brick bottom < ball top

    ; Collision detected!
    LDX brick_idx
    LDA #0
    STA bricks,X        ; Destroy brick

    ; Reverse ball Y velocity
    LDA ball_vy
    EOR #$FF
    CLC
    ADC #1
    STA ball_vy

    ; Increment score
    INC score_lo
    BNE ScoreOK
    INC score_hi
ScoreOK:

    ; Decrement brick count
    DEC bricks_left

    JMP BallUpdateDone  ; Only hit one brick per frame

NextBrick:
    LDX brick_idx
    INX
    CPX #(BRICK_ROWS * BRICK_COLS)
    BNE BrickCheckLoop

BallUpdateDone:
    RTS

; ====================================================================
; GET BRICK POSITION - Calculate X,Y from brick index
; Input: brick_idx = brick array index
; Output: brick_x, brick_y
; ====================================================================
GetBrickPosition:
    ; Get row (index / 8)
    LDA brick_idx
    LSR
    LSR
    LSR                 ; Divide by 8
    STA temp1           ; temp1 = row

    ; Calculate Y position
    LDA temp1
    STA temp2
    ASL                 ; * 2
    ADC temp2           ; * 3
    ASL                 ; * 6
    ADC temp2           ; * 7 (BRICK_SPACING_Y)
    CLC
    ADC #BRICK_START_Y
    STA brick_y

    ; Get column (index & 7)
    LDA brick_idx
    AND #$07
    STA temp1           ; temp1 = column

    ; Calculate X position (column * BRICK_SPACING_X + BRICK_START_X)
    ASL                 ; * 2
    ASL                 ; * 4
    ASL                 ; * 8
    ASL                 ; * 16
    CLC
    ADC #BRICK_START_X
    STA brick_x

    RTS

; ====================================================================
; DRAW GAME - Render all game elements
; ====================================================================
DrawGame:
    ; Draw bricks
    JSR DrawBricks

    ; Draw paddle
    JSR DrawPaddle

    ; Draw ball
    JSR DrawBall

    ; Draw HUD (lives, score)
    JSR DrawHUD

    RTS

; ====================================================================
; DRAW BRICKS - Draw all active bricks
; ====================================================================
DrawBricks:
    LDX #0
DrawBricksLoop:
    ; Check if brick is active
    LDA bricks,X
    BEQ SkipBrick

    ; Save brick index
    STX brick_idx

    ; Get brick position
    JSR GetBrickPosition

    ; Get brick color based on row
    LDX brick_idx
    LDA bricks,X

    ; Map brick value to color
    CMP #1
    BNE TryOrange
    LDA #(HUE_RED | SAT_FULL | 4)
    JMP DrawThisBrick

TryOrange:
    CMP #2
    BNE TryYellow
    LDA #(HUE_ORANGE | SAT_FULL | 4)
    JMP DrawThisBrick

TryYellow:
    CMP #3
    BNE TryGreen
    LDA #(HUE_YELLOW | SAT_FULL | 4)
    JMP DrawThisBrick

TryGreen:
    CMP #4
    BNE TryCyan
    LDA #(HUE_GREEN | SAT_FULL | 4)
    JMP DrawThisBrick

TryCyan:
    CMP #5
    BNE TryBlue
    LDA #(HUE_CYAN | SAT_FULL | 4)
    JMP DrawThisBrick

TryBlue:
    LDA #(HUE_BLUE | SAT_FULL | 4)

DrawThisBrick:
    STA temp1

    ; Set up colored rectangle
    LDA dma_mirror
    ORA #COLORFILL
    STA DMA_Flags

    LDA brick_x
    STA DMA_VX
    LDA brick_y
    STA DMA_VY

    LDA #BRICK_WIDTH
    STA DMA_WIDTH
    LDA #BRICK_HEIGHT
    STA DMA_HEIGHT

    LDA temp1
    EOR #$FF            ; Invert color for DMA
    STA DMA_Color

    LDA #1
    STA DMA_Status
    WAI                 ; Wait for blit to complete

SkipBrick:
    LDX brick_idx
    INX
    CPX #(BRICK_ROWS * BRICK_COLS)
    BNE DrawBricksLoop

    RTS

; ====================================================================
; DRAW PADDLE - Draw the player paddle
; ====================================================================
DrawPaddle:
    ; Set up colored rectangle
    LDA dma_mirror
    ORA #COLORFILL
    STA DMA_Flags

    LDA paddle_x
    STA DMA_VX
    LDA #PADDLE_Y
    STA DMA_VY

    LDA #PADDLE_WIDTH
    STA DMA_WIDTH
    LDA #PADDLE_HEIGHT
    STA DMA_HEIGHT

    LDA #(HUE_RED | SAT_FULL | 5)
    EOR #$FF
    STA DMA_Color

    LDA #1
    STA DMA_Status
    WAI

    RTS

; ====================================================================
; DRAW BALL - Draw the ball
; ====================================================================
DrawBall:
    ; Set up colored rectangle
    LDA dma_mirror
    ORA #COLORFILL
    STA DMA_Flags

    LDA ball_x
    STA DMA_VX
    LDA ball_y
    STA DMA_VY

    LDA #BALL_SIZE
    STA DMA_WIDTH
    STA DMA_HEIGHT

    LDA #(HUE_GREEN | SAT_NONE | 7)  ; White
    EOR #$FF
    STA DMA_Color

    LDA #1
    STA DMA_Status
    WAI

    RTS

; ====================================================================
; DRAW HUD - Draw lives and score indicators
; ====================================================================
DrawHUD:
    ; Draw lives as small rectangles in top-left
    LDX lives
    BEQ NoLives

    LDA #2
    STA temp1           ; X position for life indicator

DrawLifeLoop:
    LDA dma_mirror
    ORA #COLORFILL
    STA DMA_Flags

    LDA temp1
    STA DMA_VX
    LDA #2
    STA DMA_VY

    LDA #3
    STA DMA_WIDTH
    LDA #3
    STA DMA_HEIGHT

    LDA #(HUE_RED | SAT_FULL | 5)
    EOR #$FF
    STA DMA_Color

    LDA #1
    STA DMA_Status
    WAI

    ; Move to next life position
    LDA temp1
    CLC
    ADC #5
    STA temp1

    DEX
    BNE DrawLifeLoop

NoLives:
    RTS

; ====================================================================
; CLEAR SCREEN - Fill screen with black
; ====================================================================
ClearScreen:
    LDA dma_mirror
    ORA #COLORFILL
    STA DMA_Flags

    STZ DMA_VX
    STZ DMA_VY

    LDA #127
    STA DMA_WIDTH
    STA DMA_HEIGHT

    LDA #8              ; Black (low brightness)
    EOR #$FF
    STA DMA_Color

    LDA #1
    STA DMA_Status
    WAI

    RTS

; ====================================================================
; WAIT VSYNC - Wait for vertical sync
; ====================================================================
WaitVSync:
    LDA did_vsync
    BEQ WaitVSync
    STZ did_vsync
    RTS

; ====================================================================
; SWAP BUFFERS - Swap display and draw framebuffers
; ====================================================================
SwapBuffers:
    ; Toggle VRAMBANK2 in bank flags
    LDA bank_mirror
    EOR #VRAMBANK2
    STA bank_mirror
    STA Bank_Flags

    ; Toggle VID_OUT_PAGE2 in DMA flags
    LDA dma_mirror
    EOR #VID_OUT_PAGE2
    STA dma_mirror
    STA DMA_Flags

    RTS

; ====================================================================
; INTERRUPTS
; ====================================================================

; NMI - Called on VSync
NMI:
    PHA
    LDA #1
    STA did_vsync
    PLA
    RTI

; IRQ - Called when DMA blit completes
IRQ:
    RTI

; ====================================================================
; INTERRUPT VECTORS
; ====================================================================
.org $FFFA
.dw NMI         ; NMI vector
.dw RESET       ; Reset vector
.dw IRQ         ; IRQ vector
