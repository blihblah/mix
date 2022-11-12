VRAM_BLOCKTABLE: EQU $1800
VRAM_COLOUR_1: EQU $2000
VRAM_COLOUR_2: EQU $2800
VRAM_COLOUR_3: EQU $3000
VRAM_PATTERN_1: EQU $0000
VRAM_PATTERN_2: EQU $0800
VRAM_PATTERN_3: EQU $1000


PLAYING_AREA_BYTES: EQU 22*8*8

FIRST_SIDEBAR_CHAR: EQU 176
SIDEBAR_CHARS: EQU 255 - FIRST_SIDEBAR_CHAR

SPENT_TIMERBAR: EQU FIRST_SIDEBAR_CHAR


TITLE_COLOURS_1:
    INCBIN "incbin/title_top_rle_colour.bin"
TITLE_PATTERN_1:
    INCBIN "incbin/title_top_rle_pattern.bin"

TITLE_COLOURS_2:
    INCBIN "incbin/title_mid_rle_colour.bin"
TITLE_PATTERN_2:
    INCBIN "incbin/title_mid_rle_pattern.bin"

TITLE_COLOURS_3:
    INCBIN "incbin/title_btm_rle_colour.bin"
TITLE_PATTERN_3:
    INCBIN "incbin/title_btm_rle_pattern.bin"


GAMEOVER_COLOURS_1:
    INCBIN "incbin/gameover_top_rle_colour.bin"
GAMEOVER_PATTERN_1:
    INCBIN "incbin/gameover_top_rle_pattern.bin"

GAMEOVER_COLOURS_2:
    INCBIN "incbin/gameover_mid_rle_colour.bin"
GAMEOVER_PATTERN_2:
    INCBIN "incbin/gameover_mid_rle_pattern.bin"

GAMEOVER_COLOURS_3:
    INCBIN "incbin/gameover_btm_rle_colour.bin"
GAMEOVER_PATTERN_3:
    INCBIN "incbin/gameover_btm_rle_pattern.bin"


FillLastChar:
        ld a, 0
        ld bc, 8
        ld hl, VRAM_PATTERN_1 + 255*8
        call LDIRVM

        ld a, $11
        ld bc, 8
        ld hl, VRAM_COLOUR_1 + 255*8
        call LDIRVM

        ld a, 0
        ld bc, 8
        ld hl, VRAM_PATTERN_2 + 255*8
        call LDIRVM

        ld a, $11
        ld bc, 8
        ld hl, VRAM_COLOUR_2 + 255*8
        call LDIRVM

        ld a, 0
        ld bc, 8
        ld hl, VRAM_PATTERN_3 + 255*8
        call LDIRVM

        ld a, $11
        ld bc, 8
        ld hl, VRAM_COLOUR_3 + 255*8
        call LDIRVM
        ret

C_BLACK_EMPTY: EQU 255

HideMainArea:
        ld a, 7
        ld b, 7+8+7
        ld hl, VRAM_BLOCKTABLE + 32 + 1
    .loop:
        push bc
        push hl
        push hl
        pop hl
        ld a, 255
        ld bc, 22
        call FILVRM
        pop hl
        ld de, 32
        add hl, de
        pop bc
        djnz .loop

        ret


RedrawMainArea:
        ld hl, GAME_SCREEN_INIT + 33
        ld (TEMP_WORD + 2), hl
        ld hl, VRAM_BLOCKTABLE + 32 + 1
        ld (TEMP_WORD), hl
        ld b, 7+8+7
    .loop1:
        push bc
        ld hl, (TEMP_WORD)
        ex de, hl
        ld hl, (TEMP_WORD + 2)
        ld bc, 22
        call LDIRVM

        ld hl, (TEMP_WORD)
        ld de, 32
        add hl, de
        ld (TEMP_WORD), hl

        ld hl, (TEMP_WORD + 2)
        add hl, de
        ld (TEMP_WORD + 2), hl

        pop bc
        djnz .loop1
        ret




DisplayGameover:
        call WaitForBlank
        call HideMainArea
        ld de, GAMEOVER_PATTERN_1
        ld hl, VRAM_PATTERN_1
        call LoadRLE2VRAM
        ld de, GAMEOVER_COLOURS_1
        ld hl, VRAM_COLOUR_1
        call LoadRLE2VRAM

        ld de, GAMEOVER_PATTERN_2
        ld hl, VRAM_PATTERN_2
        call LoadRLE2VRAM
        ld de, GAMEOVER_COLOURS_2
        ld hl, VRAM_COLOUR_2
        call LoadRLE2VRAM

        ld de, GAMEOVER_PATTERN_3
        ld hl, VRAM_PATTERN_3
        call LoadRLE2VRAM
        ld de, GAMEOVER_COLOURS_3
        ld hl, VRAM_COLOUR_3
        call LoadRLE2VRAM

        call WaitForBlank
        call RedrawMainArea
        ret

DisplayTitle:
        call WaitForBlank
        call HideMainArea
        ld de, TITLE_PATTERN_1
        ld hl, VRAM_PATTERN_1
        call LoadRLE2VRAM
        ld de, TITLE_COLOURS_1
        ld hl, VRAM_COLOUR_1
        call LoadRLE2VRAM

        ld de, TITLE_PATTERN_2
        ld hl, VRAM_PATTERN_2
        call LoadRLE2VRAM
        ld de, TITLE_COLOURS_2
        ld hl, VRAM_COLOUR_2
        call LoadRLE2VRAM


        ld de, TITLE_PATTERN_3
        ld hl, VRAM_PATTERN_3
        call LoadRLE2VRAM
        ld de, TITLE_COLOURS_3
        ld hl, VRAM_COLOUR_3
        call LoadRLE2VRAM
        call WaitForBlank

        call RedrawMainArea
        call WaitForBlank
        ret


PrepareGameField: ;; SHOULD BE CALLED WHEN PREPARING THE GAME AFTER TITLE.

        ;; First, clear the colours.
        ld bc, PLAYING_AREA_BYTES
        ld a, $f1
        ld hl, VRAM_COLOUR_1
        call FILVRM

        ld bc, PLAYING_AREA_BYTES
        ld a, $f1
        ld hl, VRAM_COLOUR_2
        call FILVRM

        ld bc, PLAYING_AREA_BYTES
        ld a, $f1
        ld hl, VRAM_COLOUR_3
        call FILVRM
        ret


PrepareScreenFirstTime:
        ;; Resets the character map section in VRAM for game.
        ld bc, 256*3
        ld hl, GAME_SCREEN_INIT
        ld de, VRAM_BLOCKTABLE
        call LDIRVM

    ;; Load the sidebar GFX.
    ;; Colours..
        ld de, GAME_GFX_COLOURS_1
        ld hl, VRAM_COLOUR_1 + FIRST_SIDEBAR_CHAR * 8
        call LoadRLE2VRAM
        ld de, GAME_GFX_COLOURS_2
        ld hl, VRAM_COLOUR_2 + FIRST_SIDEBAR_CHAR * 8
        call LoadRLE2VRAM
        ld de, GAME_GFX_COLOURS_3
        ld hl, VRAM_COLOUR_3 + FIRST_SIDEBAR_CHAR * 8
        call LoadRLE2VRAM

    ;; Patterns...
        ld hl, GAME_GFX_PATTERNS_1
        ld de, VRAM_PATTERN_1 + FIRST_SIDEBAR_CHAR * 8
        ld bc, SIDEBAR_CHARS * 8
        call LDIRVM

        ld hl, GAME_GFX_PATTERNS_2
        ld de, VRAM_PATTERN_2 + FIRST_SIDEBAR_CHAR * 8
        ld bc, SIDEBAR_CHARS * 8
        call LDIRVM

        ld hl, GAME_GFX_PATTERNS_3
        ld de, VRAM_PATTERN_3 + FIRST_SIDEBAR_CHAR * 8
        ld bc, SIDEBAR_CHARS * 8
        call LDIRVM
        ret

ResetDisplayForGame:

        call HideMainArea

        call PrepareGameField

        call ResetGameFieldForGame
        call RedrawMainArea
        ret

ResetGameFieldForGame:
        ;; Clear the map characters

        ld hl, VRAM_PATTERN_1
        ld bc, 22*8*8
        ld a, 0
        call FILVRM
        ld hl, VRAM_PATTERN_2
        ld bc, 22*8*8
        ld a, 0
        call FILVRM
        ld hl, VRAM_PATTERN_3
        ld bc, 22*8*8
        ld a, 0
        call FILVRM

        ;; Now, draw the border.
        ;; Let's do sides first.
        ld a, %10000000
        ld hl, VRAM_PATTERN_1
        call .fillSeries
        ld a, %10000000
        ld hl, VRAM_PATTERN_2
        call .fillSeries
        ld a, %10000000
        ld hl, VRAM_PATTERN_3
        call .fillSeries

        ld a, %00000011
        ld hl, VRAM_PATTERN_1 + 21*8
        call .fillSeries
        ld a, %00000011
        ld hl, VRAM_PATTERN_2 + 21*8
        call .fillSeries
        ld a, %00000011
        ld hl, VRAM_PATTERN_3 + 21*8
        call .fillSeries

        ;; Now, the top border
        ld b, 22
        ld hl, VRAM_PATTERN_1
        ld de, 8
    .loopTopRow:
        ld a, $ff
        call WRTVRM
        add hl, de
        djnz .loopTopRow

        ;; And the bottom border.
        ld b, 22
        ld hl, VRAM_PATTERN_3 + 6*22*8 + 6 ;; Seventh row, first character, seventh byte
        ld de, 7
    .loopBottomRow:
        ld a, $ff
        call WRTVRM
        inc hl
        ld a, $ff
        call WRTVRM
        add hl, de
        djnz .loopBottomRow

        ret

    ;; ------

    .fillSeries:
        ld (LOOPVAR), a
        ld b, 8
        ld c, 8
    .loopFillSeries:
        ld a, (LOOPVAR)
        call WRTVRM

        inc hl
        djnz .loopFillSeries
        ld a, c
        dec a
        ret z ;; Last character?

        ld de, 21*8
        add hl, de
        ld c, a
        ld b, 8
        jp .loopFillSeries





GAME_SCREEN_INIT:
    DB 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 212, 216, 183, 183, 183, 183, 183, 183, 183, 183, 183
    DB 176, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,                                 217, 184, 185, 186, 187, 188, 189, 190, 191
    DB 176, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43,                       217, 192, 193, 194, 195, 196, 197, 198, 191
    DB 176, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65,                       217, 199, 200, 201, 202, 203, 204, 190, 191
    DB 176, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87,                       217, 205, 206, 207, 208, 209, 210, 211, 191
    DB 176, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109,             215, 182, 182, 182, 182, 182, 182, 182, 182
    DB 176, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 214, 177, 178, 179, 180, 213, 213, 213, 213
    DB 176, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 176, 176, 176, 176, 176, 176, 176, 176, 176

    DB 176, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,                                 176, 176, 176, 176, 176, 176, 176, 176, 176
    DB 176, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43,                       176, 188, 189, 190, 208, 191, 192, 193, 194
    DB 176, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65,                       176, 177, 177, 195, 176, 177, 177, 195, 176
    DB 176, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87,                       176, 176, 176, 176, 176, 176, 176, 176, 176
    DB 176, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109,             209, 196, 197, 198, 199, 200, 208, 208, 208
    DB 176, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 176, 176, 176, 176, 176, 176, 176, 176, 176
    DB 176, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 176, 176, 176, 176, 176, 176, 176, 176, 176
    DB 176, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 209, 196, 201, 202, 203, 200, 208, 208, 208

    DB 176, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,                                 176, 176, 176, 176, 176, 176, 176, 176, 176
    DB 176, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43,                       176, 176, 176, 176, 176, 176, 176, 176, 176
    DB 176, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65,                       213, 195, 196, 197, 198, 199, 199, 199, 199
    DB 176, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87,                       176, 176, 176, 176, 176, 176, 176, 176, 176
    DB 176, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109,             176, 176, 176, 176, 176, 176, 176, 176, 176
    DB 176, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 176, 176, 176, 176, 176, 176, 176, 176, 176
    DB 176, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 176, 200, 201, 202, 203, 203, 204, 205, 206
    DB 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 176, 207, 208, 209, 210, 210, 210, 211, 212


InitSprites:
	;; Loads all sprites used in the game.
	ld a, 0
	ld (LOOPVAR), a ;; Temporary use.
  .nextSprite:
	; Copy the sprites.
	ld a, (LOOPVAR)
	call CALPAT
	ex de, hl
	ld hl, SPRITE_GFX
	ld bc, 32
	ld a, (LOOPVAR)

  .startWhile:
	cp 0
	jp z, .endWhile
	add hl, bc
	dec a
	jp .startWhile

  .endWhile:
	CALL LDIRVM
	ld a, (LOOPVAR)
	inc a
	ld (LOOPVAR), a
	cp _NO_OF_SPRITES
	jp nz, .nextSprite
	ret

LoadRLE2VRAM:
	;; Unpack RLE-encoded data to VRAM.
	;; Pairs of [len][value] entries;
	;; ends when len=0.
	;; Used just to display something like the full screens (such as the title
	;; screen)
  .loop:
	ld a, (de) ;; Count
	and a
	ret z
	ld c, a
	ld b, 0
	inc de
	ld a, (de) ;; Colour.
	inc de
	push de
	push bc
	push hl
	call FILVRM
	pop hl
	pop bc
	pop de
	add hl, bc
	jp .loop


_NO_OF_SPRITES: EQU 19
SPRITE_GFX:
    INCBIN "incbin/sprites.bin"

GAME_GFX_PATTERNS_1:
    INCBIN "incbin/extra_gameplaychars_1.bin"
GAME_GFX_COLOURS_1:
    INCBIN "incbin/extra_gameplaychars_1_colours.bin"
GAME_GFX_PATTERNS_2:
    INCBIN "incbin/extra_gameplaychars_2.bin"
GAME_GFX_COLOURS_2:
    INCBIN "incbin/extra_gameplaychars_2_colours.bin"
GAME_GFX_PATTERNS_3:
    INCBIN "incbin/extra_gameplaychars_3.bin"
GAME_GFX_COLOURS_3:
    INCBIN "incbin/extra_gameplaychars_3_colours.bin"

