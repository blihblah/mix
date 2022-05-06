;; Enemy movement code



HIGH_END_LIMIT: EQU 22 * 8 - 11
; WAS: 22 * 8 - 16


MainEnemyActions:
        ;; IX + 0 = Y
        ;; IX + 1 = X
        ;; IX + 2 = pattern (constant?)
        ;; IX + 3 = colour (constant?)
        ;; IX + 4 = state
        ;; IX + 5 = state counter

        ld ix, MAIN_ENEMY_1
        call .mainEnemyAction

        ld ix, MAIN_ENEMY_2
        ld a, (ix+4)
        cp ENEMY_STATE_NOT_ACTIVE
        ret z
        call .mainEnemyAction
        ret

    .mainEnemyAction:
        ;; Has the enemy been wiped out?
        ld a, (ix + 0)
        ld (PIX_Y), a
        ld a, (ix + 1)
        ld (PIX_X), a
        call IsPixelLit
        ;jp nz, .enemyDestroyed

        ld a, (ix + 0)
        ld (TRACER_Y), a
        ld a, (ix + 1)
        ld (TRACER_X), a

        ld a, (ix + 4)
        sub a, 4
        jp z, .tryMovingNorth
        dec a
        jp z, .tryMovingEast
        dec a
        jp z, .tryMovingSouth
        dec a
        jp z, .tryMovingWest
        dec a
        jp z, .tryMovingNorthEast
        dec a
        jp z, .tryMovingSouthEast
        dec a
        jp z, .tryMovingSouthWest

        jp z, .tryMovingNorthWest

    .tryMovingNorth:
        ld a, (ix + 0)
        cp 9
        jp c, .movementFails
        sub 2
        ld (TRACER_Y), a
        jp .checkCollision


    .tryMovingEast:
        ld a, (ix + 1)
        cp HIGH_END_LIMIT
        jp nc, .movementFails
        add a,2
        ld (TRACER_X), a
        jp .checkCollision

    .tryMovingWest:
        ld a, (ix + 1)
        cp 9
        jp c, .movementFails
        sub 2
        ld (TRACER_X), a
        jp .checkCollision

    .tryMovingSouth:
        ld a, (ix + 0)
        cp HIGH_END_LIMIT
        jp nc, .movementFails
        add a,2
        ld (TRACER_Y), a
        jp .checkCollision

    .tryMovingNorthEast:
        ld a, (ix + 0)
        cp 9
        jp c, .movementFails
        sub 2
        ld (TRACER_Y), a
        ld a, (ix + 1)
        cp HIGH_END_LIMIT
        jp nc, .movementFails
        add a,2
        ld (TRACER_X), a
        jp .checkCollision
    .tryMovingNorthWest:
        ld a, (ix + 0)
        cp 9
        jp c, .movementFails
        sub 2
        ld (TRACER_Y), a
        ld a, (ix + 1)
        cp 9
        jp c, .movementFails
        sub 2
        ld (TRACER_X), a
        jp .checkCollision

    .tryMovingSouthEast:
        ld a, (ix + 0)
        cp HIGH_END_LIMIT
        jp nc, .movementFails
        add a,2
        ld (TRACER_Y), a
        ld a, (ix + 1)
        cp HIGH_END_LIMIT
        jp nc, .movementFails
        add a,2
        ld (TRACER_X), a
        jp .checkCollision

    .tryMovingSouthWest:
        ld a, (ix + 0)
        cp HIGH_END_LIMIT
        jp nc, .movementFails
        add a,2
        ld (TRACER_Y), a

        ld a, (ix + 1)
        cp 9
        jp c, .movementFails
        sub 2
        ld (TRACER_X), a

        jp .checkCollision





    .checkCollision:
        ;; Can we move to this pixel? == is it unlit in RAM?
        ld a, (TRACER_X)
        ld (PIX_X), a
        ld a, (TRACER_Y)
        ld (PIX_Y), a
        call IsPixelLitRAM_BB
        jp nz, .movementFails
        ;; Update the enemy coordinate.
        ld a, (TRACER_X)
        ld (ix + 1), a
        ld a, (TRACER_Y)
        ld (ix), a

    .checkPlayerCollision: ;; Check if the player's line collides with the
        ;; enemy.

        ;; Use the DRAWN_LINE buffer for this purpose.

        ;; The enemy may occupy up to 3x3 characters.
        ;; We may need to check up to 16 rows * 3 columns of VRAM = a lot.
        ;; Let's ignore all odd rows.

        ;; TEMP_WORD     = loop counter
        ;; TEMP_WORD + 1 = used mask (left and right columns)
        ;; TEMP_WORD + 2 = topmost Y row
        ;; TEMP_WORD +

        call .isErrorSpot

        ld a, (TRACER_Y)
        and %11111110
        sub a, 8 ;; We need to look at even rows.
        ld (TEMP_WORD + 2), a

        ld a, (TRACER_X)
        sub a, 8
        ld (PIX_X), a
        and 7
        ld e, a
        ld d, 0
        ld hl, BITMASK_LEFT
        add hl, de
        ld a, (hl)   ;; First column mask
        ld (TEMP_WORD + 1), a ;; Used mask.

        ;; Init loop
        ld a, 8
        ld (TEMP_WORD), a
        ld a, (TEMP_WORD + 2)
        ld (PIX_Y), a

    .columnOne:
        call GetLineByte
        ld b, a
        ld a, (TEMP_WORD + 1)
        and b
        jp nz, .playerDies

        ;; Next odd line
        ld a, (PIX_Y)
        add a, 2
        ld (PIX_Y), a

        ld a, (TEMP_WORD)
        dec a
        ld (TEMP_WORD), a
        jp nz, .columnOne


        ;; Prepare for the next round
        ld a, (PIX_X)
        add a, 8
        ld (PIX_X), a
        ld a, 8
        ld (TEMP_WORD), a

        ;; Reset Y value
        ld a, (TEMP_WORD + 2)
        ld (PIX_Y), a
        ld a, 8
        ld (TEMP_WORD), a


    .columnTwo:
        call GetLineByte
        ld b, $ff
        and b
        jp nz, .playerDies

        ;; Next odd line
        ld a, (PIX_Y)
        add a, 2
        ld (PIX_Y), a

        ld a, (TEMP_WORD)
        dec a
        ld (TEMP_WORD), a
        jp nz, .columnTwo

        ;; Prepare for the last column.

        ld a, (PIX_X)
        add a, 8
        ld (PIX_X), a
        and 7
        ld e, a
        ld d, 0
        ld hl, BITMASK_RIGHT
        add hl, de
        ld a, (hl)   ;; First column mask
        ld (TEMP_WORD + 1), a ;; Used mask.

        ;; Init loop
        ld a, (TEMP_WORD + 2)
        ld (PIX_Y), a
        ld a, 8
        ld (TEMP_WORD), a


    .columnThree:
        call GetLineByte
        ld b, a
        ld a, (TEMP_WORD + 1)
        and b
        jp nz, .playerDies

        ;; Next odd line
        ld a, (PIX_Y)
        add a, 2
        ld (PIX_Y), a

        ld a, (TEMP_WORD)
        dec a
        ld (TEMP_WORD), a
        jp nz, .columnThree

        ;; Hooray, the player didn't die!

        ;; Now, is the enemy's movement over?
        ld a, (ix + 5)
        dec a
        cp 0
        jp z, .movementFails
        ld (ix + 5), a

        ret


    .playerDies:
        ;; TODO
        ld a, STATE_START_DYING
        ld (GAME_STATE), a
        ret

    .isErrorSpot:
        ld a, (ix)
        cp $80
        ret nz
        ld a, (ix + 1)
        cp $9e
        ret nz
        nop
        ret

    .movementFails:
        ;; Choose at random a new direction to move in.
        call RandomNumber
        ld a, (Rng + 1)
        ld b, a
        and %111
        add a, 4
        ld (ix + 4), a
        ;; Choose at random the distance to move.
        ld a, b
        rra
        rra
        rra
        and %00011111
        add a, 16
        ld (ix + 5), a
        ret ;; TODO: Do we need to check for player death here as well?


    .enemyDestroyed:
        ld a, STATE_LEVEL_CLEARED_ENEMY_LOST
        ld (DEFEATED_ENEMY), ix
        ld (GAME_STATE), a

        ret


BITMASK_LEFT:
    DB %11111111
    DB %01111111
    DB %00111111
    DB %00011111
    DB %00001111
    DB %00000111
    DB %00000011
    DB %00000001

BITMASK_RIGHT:
    DB %00000000
    DB %10000000
    DB %11000000
    DB %11100000
    DB %11110000
    DB %11111000
    DB %11111100
    DB %11111110


TracerActions:
        ;; IX + 0 = X
        ;; IX + 1 = Y
        ;; IX + 2 = DIR
        ;; IX + 3 = ENEMY_STATUS
        ;; IX + 4 = Delay


        ld ix, BORDER_ENEMY_1
        call .tracerAction
        ld ix, BORDER_ENEMY_2
        call .tracerAction
        ld ix, BORDER_ENEMY_3
        call .tracerAction
        ld ix, BORDER_ENEMY_4
        call .tracerAction
        ld ix, BORDER_ENEMY_5
        call .tracerAction
        ld ix, BORDER_ENEMY_6
        call .tracerAction

        ret
    .tracerAction:
        ld a, (ix+3)
        cp 0
        ret z
        dec a
        jp z, TracerMovement
        dec a
        jp z, .despawning
        dec a
        jp .respawning

    .despawning:
        ld a, (ix + 4)
        dec a
        jp z, .despawnOver
        ld (ix + 4), a
        ret
    .despawnOver:
        ld a, 50
        ld (ix + 4), a
        ld a, ENEMY_STATE_RESPAWNING
        ld (ix + 3), a
        jp .relocateRespawn ;; Go determine where to respawn


    .respawning:
        ld a, (ix + 4)
        dec a
        jp z, .respawnOver
        ld (ix + 4), a

        ld a, (ix)
        ld (PIX_X), a
        ld a, (ix + 1)
        ld (PIX_Y), a
        call IsPixelLitRAM
        ret nz

        ;; The respawn point has been lost. Reassign the spawn.
        jp .despawnOver

    .respawnOver:
        ld a, 50
        ld (ix + 4), a
        ld a, ENEMY_STATE_TRACING
        ld (ix + 3), a

        ;; TODO: Determine the enemy location!
        ret

    .continueDespawning:
        ld a, (ix + 4)
        dec a
        ld (ix + 4), a
        ret nz ;; Continues...
        ld a, TRACING_RESPAWN_DELAY
        ld (ix + 4), a
        ld a, ENEMY_STATE_RESPAWNING
        ld (ix + 3), a
    .relocateRespawn:
        call RandomNumber
        ld a, (TOPMOST_WITH_FREE)
        ld c, a
        ld a, (LOWEST_WITH_FREE)
        ld d, a
        sub c ;; A has now the number of possible rows.
        ld e, a
        ld a, (Rng + 1)
    .loopUntilModuloFits:
        cp e
        jp c, .loopModuloOver
        sub e
        jp .loopUntilModuloFits
    .loopModuloOver:
        add a, c ;; Now A has the line on which to place the enemy.
        and %11111110 ;; Make the row an even one.
        ;; This is safe, because topmost with free is odd, but above it
        ;; is a line with horizontal lines.
        ld (ix + 1), a
        ;; Now, find where to place.
        ld (TRACER_Y), a
        ld a, (ix + 5)
        cp 0
        jp z, .scanFromLeft
        ld a, 0
        ld (TRACER_X), a
        call WallToRightRAM
        ld a, (TRACER_X)
        ld (ix + 0), a
        ld a, DIR_SOUTH
        ld (ix + 2), a
        ret
    .scanFromLeft:
        ld a, 22*8 - 1
        ld (TRACER_X), a
        call WallToLeftRAM
        ld a, (TRACER_X)
        ld (ix + 0), a
        ld a, DIR_SOUTH
        ld (ix + 2), a
        ret
    .continueRespawning:
        ld a, (ix + 4)
        dec a
        ld (ix + 4), a
        ret nz ;; Continues...
        ld a, ENEMY_STATE_TRACING
        ld (ix + 3), a
        ret


TracerMovement:
        ld a, (ix + 0)
        ld (TRACER_X), a
        ld (PIX_X), a

        ld a, (ix + 1)
        ld (TRACER_Y), a
        ld (PIX_Y), a

        call IsPixelLitRAM
        jp z, .enemyOutsideBorder ;; Enemy dropped off, prepare to respawn

        ;; Main loop for scanning the outline.
        ;; Look 90 degrees clockwise from the previous direction, and if it was
        ;; painted in VRAM, accept change to that direction.
        ;; Otherwise, try the next directions in counter-clockwise order from
        ;; that.
        ;; The result is that we trace the outline in clockwise direction.

        call .checkCollisionWithPlayer

        ld a, (ix + 5)
        cp 1
        jp z, .scanCCW


    .scanCW:
        ld a, (ix + 2)
        cp 0
        jp z, .scanCWEast  ;; The direction to scan is one clockwise from
                         ;; direction
        dec a
        jp z, .scanCWSouth
        dec a
        jp z, .scanCWWest
        jp .scanCWNorth

    .scanCWNorth:
        ;; First, scan north.
        ld a, (TRACER_Y)
        dec a
        ld (PIX_Y), a
        ld a, (TRACER_X)
        ld (PIX_X), a
        call IsPixelLitRAM_BB
        jp nz, .turnNorth

    .scanCWWest:
        ld a, (TRACER_Y)
        ld (PIX_Y), a
        ld a, (TRACER_X)
        dec a
        ld (PIX_X), a
        call IsPixelLitRAM_BB
        jp nz, .turnWest

    .scanCWSouth:
        ld a, (TRACER_Y)
        inc a
        ld (PIX_Y), a
        ld a, (TRACER_X)
        ld (PIX_X), a
        call IsPixelLitRAM_BB
        jp nz, .turnSouth

    .scanCWEast:
        ld a, (TRACER_Y)
        ld (PIX_Y), a
        ld a, (TRACER_X)
        inc a
        ld (PIX_X), a
        call IsPixelLitRAM_BB
        jp nz, .turnEast
        jp .scanCWNorth

    .scanCCW:
        ld a, (ix + 2)
        cp 0
        jp z, .scanCCWWest  ;; The direction to scan is one clockwise from
                         ;; direction
        dec a
        jp z, .scanCCWNorth
        dec a
        jp z, .scanCCWEast
        jp .scanCCWSouth

    .scanCCWSouth:
        ld a, (TRACER_Y)
        inc a
        ld (PIX_Y), a
        ld a, (TRACER_X)
        ld (PIX_X), a
        call IsPixelLitRAM_BB
        jp nz, .turnSouth

    .scanCCWWest:
        ld a, (TRACER_Y)
        ld (PIX_Y), a
        ld a, (TRACER_X)
        dec a
        ld (PIX_X), a
        call IsPixelLitRAM_BB
        jp nz, .turnWest

    .scanCCWNorth:
        ;; First, scan north.
        ld a, (TRACER_Y)
        dec a
        ld (PIX_Y), a
        ld a, (TRACER_X)
        ld (PIX_X), a
        call IsPixelLitRAM_BB
        jp nz, .turnNorth

    .scanCCWEast:
        ld a, (TRACER_Y)
        ld (PIX_Y), a
        ld a, (TRACER_X)
        inc a
        ld (PIX_X), a
        call IsPixelLitRAM_BB
        jp nz, .turnEast
        jp .scanCCWSouth

    .turnSouth:
        ld a, DIR_SOUTH
        jp .turned
    .turnWest:
        ld a, DIR_WEST
        jp .turned
    .turnNorth:
        ld a, DIR_NORTH
        jp .turned
    .turnEast:
        ld a, DIR_EAST
        jp .turned


    .turned:
        ;; Update the RAM copy. We look at the turns only every other pixel,
        ;; so we need to turn on TWO pixels now.
        ;; If the second pixel is already lit, then we've actually already
        ;; completed the round.

        ;; Update direction.
        ld (ix+2), a
        ld a, (TRACER_X)
        ld (ix + 0), a
        ld a, (TRACER_Y)
        ld (ix + 1), a

        call .checkCollisionWithPlayer


        ;; Then reapply diff to PIX_X, PIX_Y.

        ld a, (TRACER_X)
        ld b, a
        ld a, (PIX_X)
        sub b
        add a, a
        add a, b
        ld (ix + 0), a

        ld a, (TRACER_Y)
        ld b, a
        ld a, (PIX_Y)
        sub b
        add a, a
        add a, b
        ld (ix + 1), a

        call .checkCollisionWithPlayer

        ret

    .checkCollisionWithPlayer:
        ld hl, (PLAYER_X) ;; H => player Y, L => pla yer X
        ld a, (ix + 0)
        cp l
        ret nz
        ld a, (ix + 1)
        cp h
        ret nz
        ;; Player hit, will die.
        ld a, STATE_START_DYING
        ld (GAME_STATE), a
        ret

    .enemyOutsideBorder:
        ld a, ENEMY_STATE_DESPAWNING
        ld (ix + 3), a
        ld a, TRACING_DESPAWN_DELAY
        ld (ix + 4), a

        ld a, 5
        ld (SCORE_ADD + 1), a
        ;; This will ruin IX and IY, but those shouldn't be needed after this.

        ld hl, SOUND_THUD
        call PlaySound

        call UpdateScore
        call UpdateHighscore

        ret



TRACING_DESPAWN_DELAY: EQU 100
TRACING_RESPAWN_DELAY: EQU 50

ENEMY_STATE_NOT_ACTIVE: EQU 0
ENEMY_STATE_TRACING: EQU 1
ENEMY_STATE_DESPAWNING: EQU 2
ENEMY_STATE_RESPAWNING: EQU 3

ENEMY_STATE_MOVE_NORTH: EQU 4
ENEMY_STATE_MOVE_EAST: EQU 5
ENEMY_STATE_MOVE_SOUTH: EQU 6
ENEMY_STATE_MOVE_WEST: EQU 7
ENEMY_STATE_MOVE_NE: EQU 8
ENEMY_STATE_MOVE_SE: EQU 9
ENEMY_STATE_MOVE_SW: EQU 10
ENEMY_STATE_MOVE_NW: EQU 11

RandomNumber:
	;; Produces a random integer. Doesn't work quite as it should, but hopefully well enough.
	;; Let's try:
	;; 	a, c, m = 132, 63, 131
	;;  x_(i+1) = (a * x_(i) + c ) % m

	push af
	push bc
	push de
	push hl
	push ix
	push iy

	ld hl, (Rng)

	;; Multiply by A.
	;; HL has the original value.

	ld a, 97 ;; Factor
	;; DE has the product
	ld de, 0

  .loop1:
    sra a
	jp nc, .noAdd
	ld b, a
	ld a, d
	ld a, l
	add a, e
	ld e, a
	ld a, d
	adc a, h
	ld d, a
	ld a, b
  .noAdd:
    add hl, hl
	cp 0
	jp nz, .loop1

	;; Move product to IY and add C (63)
    ld hl, 2
	add hl, de

	;; Now, modulo 256? Let's not.
	ld (Rng), hl

	pop iy
	pop ix
	pop hl
	pop de
	pop bc
	pop af
	ret
