fname "mix.rom"

org $4000,$7fff

db	41h,42h
dw	start,0,0,0,0,0,0



;; TODO:


;; Unfinished:
;;    - vary sprite order based on frame.
;;    - timer bar redrawing doesn't quite work
;;    - diagonal main enemy movement
;;    - slow down the player
;;    - main enemy AI: have them rotate unless they hit a wall
;;    - sound effects
;;      + tracer goes poof
;;      + main enemy goes poof
;;      + timer bonus
;;      + player dies
;;      + game over
;;      - in-game beeps and boops?
;;    + scene number cap

;;    + 60/50HZ support, check if game is too slow for 60Hz with all enemies!
;;    + title screen and proper game over
;;    + timer running out doesn't result in death?
;;    + update coverage% and goal%
;;    + double main enemies -- stack them vertically
;;    + more score for splitting the main enemies
;;      + full level score?
;;    + area score to 1/4 +1 of painted area? Now 1/2.





;; 1. Player movement
;;    + render the player sprite
;;    - move player slower, but with higher fluidity?
;; 2. Enemy (center)
;;    + render the enemy
;;    + enemy mobility
;;      + fix player's line detection
;;      - make movement more interesting?
;;      - multiple different enemies?
;; 3. Region painting
;;    + player can draw the new line
;;    + enemy can detect new line and kill the player
;;    + compute % of coverage
;; 4. Border enemies
;;    + movement
;;    + respawning
;;    + can kill the player
;;    + turn by direction
;;    - colour by rotation
;;    + despawn, respawn animation
;; 5. Base gameplay
;;    + timer
;;    - slow down the player
;;    + lives
;;    - scoring
;;      + display
;;      + earn score from enemies
;;      + earn score from painting
;;      - earn more score when splitting the main enemies
;;    + levels
;;    - rudimentary sound effects
;;    + difficulty progression
;; - Graphics
;;    + Fix timer graphics
;;    - Fix level clearing, don't do unnecessary copying (do it CLEANLY)
;;    - Fix timer reset (redraw only as many lines as needed for timer)
;;    - Add flickering to enemies
;; 6. Background scoring - optional
;;    - render custom background image mask
;;    - render custom background rastering
;; 7. Title screen
;;    - any distinct game options?
;; 8. Optimize
;;    + do not paint to VRAM empty bytes when repainting
;;    - start painting from topmost previous free line
;;    - finish painting at the lowest previous free line
;;    - faster painting process

; BIOS Constants
FORCLR: equ $F3E9
BAKCLR: equ $F3EA
BDRCLR: equ $F3EB
CLIKSW: equ $f3db

CHGCLR: equ $0062
CHGMOD: equ $005F
LINL32: equ $F3AF

WRTPSG: equ $0093
WRTVDP: equ $0047
WRTVRM: equ $004D ; Write to VRAM, A=value, HL=address
RDVRM: equ $004A  ; Read from VRAM, A <- value, HL = address
LDIRVM: equ $005C ; Block transfer from memory to VRAM;
                  ; BC = block length, HL = mem start, DE = start VRAM
LDIRMV: equ $0059
FILVRM: equ $0056
VDP1_MIRROR: equ $F3E0

GTSTCK: equ $00D5
GTTRIG: equ $00D8
CALPAT: equ $0084
CALATR: equ $0087

ENASLT:   equ  024h
RSLREG:   equ 0138h
EXPTBL:	equ	0FCC1h

HKEY: equ $FD9F

KEYS: equ $FBE5

;; From :
;; https://www.msx.org/wiki/Develop_a_program_in_cartridge_ROM
PageSize:	equ	$4000	; 16kB
Seg_P8000_SW:	equ	07000h	; Segment switch for page 8000h-BFFFh (ASCII16k)


;; This should fit in 32KB...


start:
	;; Code lifted from Transball
	;; https://github.com/santiontanon/transballmsx
    di
    im 1
    ld sp, $F380    ;; initialize the stack
    ld a, $C9       ;; clear the interrupts
    ld (HKEY), a
    ei
	call Set32KSlot
	call InitializeProgram
	call StartInterrupts

    di ;; Necessary?
    ld sp, $F380    ;; initialize the stack
    ei
    jp MainLoop

Set32KSlot:
;; By ARTRAG, https://www.msx.org/forum/msx-talk/development/memory-pages-again
	call RSLREG
	rrca
	rrca
	and 3
	ld c,a
	add a,0xC1
	ld l,a
	ld h,0xFC
	ld a,(hl)
	and 080h
	or c
	ld c,a
	inc l
	inc l
	inc l
	inc l
	ld a,(hl)
	and 0x0C
	or c           ; in A the rom slotvar
	ld h,080h
	jp ENASLT


InitializeProgram:
	call $00CC ; Disable function key display.
	ld a, 14
	ld (FORCLR), a
	ld a, 1
	ld (BAKCLR), a
	ld (BDRCLR), a
	call CHGCLR
	ld a,2      ; Change screen mode
    call CHGMOD
	ld bc, $e201 ;; Should allow 16x16 sprites.
    call WRTVDP
	ld a, 0
	ld (CLIKSW), a
	ret


;; MAIN GAMEPLAY

MainLoop:
    call InitSprites
    call DetectRefreshSpeed
    jp InitGame

INCLUDE "gameloop.asm"
INCLUDE "sound.asm"
INCLUDE "init_screen.asm"
INCLUDE "area_fill.asm"
INCLUDE "shared.asm"
INCLUDE "enemy.asm"


endadr: ds ((($-1)/$4000)+1)*$4000-$


;; RAM

org $c800 ;; These are the variables' positions in RAM.

LOOPVAR: RB 1 ;; Generic spot.

LATEST_VDP_INTERRUPT: RB 1
LATEST_MAIN_STEP: RB 1
PLAYER_DIR: RB 1
PLAYER_X: RB 1
PLAYER_Y: RB 1
LAST_NONDRAWING_X: RB 1
LAST_NONDRAWING_Y: RB 1

PIX_X: RB 1
PIX_Y: RB 1
TO_VRAM: RB 1

TRACER_X: RB 1
TRACER_Y: RB 1
SCAN_DIR: RB 1

C_LEN_BORDER_ENEMY: EQU 6
C_LEN_MAIN_ENEMY: EQU 6

BORDER_ENEMY_1:
    ;; +0: X
    ;; +1: Y
    ;; +2: DIR
    ;; +3: STATE
    ;; +4: DELAY
    ;; +5: ROTATION DIRECTION (0=CW, 1=CCW)
    RB C_LEN_BORDER_ENEMY

BORDER_ENEMY_2:
    RB C_LEN_BORDER_ENEMY

BORDER_ENEMY_3:
    RB C_LEN_BORDER_ENEMY

BORDER_ENEMY_4:
    RB C_LEN_BORDER_ENEMY

BORDER_ENEMY_5:
    RB C_LEN_BORDER_ENEMY

BORDER_ENEMY_6:
    RB C_LEN_BORDER_ENEMY


MAIN_ENEMY_1:
    ;; +0: Y
    ;; +1: X
    ;; +2: pattern
    ;; +3: colour
    ;; +4: state
    ;; +5: delay
    RB C_LEN_MAIN_ENEMY

MAIN_ENEMY_2:
    RB C_LEN_MAIN_ENEMY


CURRENT_COVERAGE: RB 1
GOAL_COVERAGE: RB 1

SPRITE_VALS: RB 4

PAINTED_AREA: RB 2
OLD_PAINTED_AREA: RB 2
LEVEL_CLEAR_THRESHOLD: RB 2
TOPMOST_WITH_FREE: RB 1
LOWEST_WITH_FREE: RB 1
PAINTAND: RB 1

INSIDE: RB 1
ODD_COUNT: RB 1
EVEN_COUNT: RB 1
ODD_PAINT: RB 1
EVEN_PAINT: RB 1


ODD_FOR_SHADING: RB 1
EVEN_FOR_SHADING: RB 1

;; These two need to be adjacent!
MEMSCAN: RB 24*22*8 ;; This is the RAM copy of the memory.
DRAWN_LINE: RB 24*22*8 ;; This is a RAM copy of the memory but with only the
;; player's drawn line here.

;; 8 digits to show, ninth for carry in adding SCORE_ADD and SCORE.
SCORE_ADD: RB 9
HIGHSCORE: RB 9
SCORE: RB 9

LIVES: RB 1
LEVEL: RB 1
TIME_LEFT: RB 1
DELAY_TIMER: RB 1
LEVEL_TIME: RB 1
SCORING_FACTOR: RB 1
IS_PAL: RB 1
FRAMECOUNTER: RB 1


TIME_FRAMES_PER_PIXEL: EQU 15


DIR_NORTH: EQU 0
DIR_EAST: EQU 1
DIR_SOUTH: EQU 2
DIR_WEST: EQU 3





STATE_MENU: EQU 0
STATE_NOT_DRAWING: EQU 1
STATE_DRAWING: EQU 2
STATE_START_DYING: EQU 3
STATE_DYING: EQU 4
STATE_RESPAWNING: EQU 5
STATE_LEVEL_CLEARED_THRESHOLD: EQU 6
STATE_LEVEL_CLEARED_ENEMY_LOST: EQU 7

GAME_STATE: RB 1  ;; 0 = game not on. 1 = player not drawing. 2 = player drawing

TEMP_WORD: RB 4
TRACER_START: RB 2
DEFEATED_ENEMY: RB 2
PLAYER_MOVED: RB 1


CURRENT_LEVEL_BACKGROUND: RB 8

EVEN_SHADE: RB 1 ;; ORDER MATTERS.
ODD_SHADE:  RB 1


; Random number generator
Rng: RB 2

    SPRITE_PLAYER: EQU 0
    SPRITE_TRACER_UP:      EQU 1*4
    SPRITE_TRACER_RIGHT:   EQU 2*4
    SPRITE_TRACER_DOWN:    EQU 3*4
    SPRITE_TRACER_LEFT:    EQU 4*4
    SPRITE_MAIN_ENEMY:     EQU 5*4
    SPRITE_TIMER:          EQU 6*4
    SPRITE_TRACER_DESPAWN_1: EQU 7*4
    SPRITE_TRACER_DESPAWN_2: EQU 8*4
    SPRITE_TRACER_RESPAWN_1: EQU 9*4
    SPRITE_TRACER_RESPAWN_2: EQU 10*4
    SPRITE_EMPTY: EQU 11*4
    SPRITE_MAIN_ENEMY_DYING_1: EQU 12*4
    SPRITE_MAIN_ENEMY_DYING_2: EQU 13*4
    SPRITE_MAIN_ENEMY_DYING_3: EQU 14*4
    SPRITE_MAIN_ENEMY_DYING_4: EQU 15*4
    SPRITE_PLAYER_DYING_1: EQU 16 * 4
    SPRITE_PLAYER_DYING_2: EQU 17 * 4
    SPRITE_PLAYER_DYING_3: EQU 18 * 4