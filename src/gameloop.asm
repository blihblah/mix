C_INITIAL_LIVES: EQU 3


TitleScreen:
    ;call ResetDisplay
    call ResetScore
    call RedrawHighscore

    ;; Display the title screen and the prompt to press fire to start.

    call DisplayTitle
    call WaitForFire
    call HideMainArea
    call StartNewGame
    ;call DisplayGameField
    call PrepareGameField
    call Gameloop
    jp TitleScreen

INIT_HIGHSCORE: DB 0, 0, 0, 0, 1, 0, 0


WaitForFire:
    .waitForRelease:
        call ReadTrigger
        and a
        jp nz, .waitForRelease

    .waitForFire:
        call ReadTrigger
        and a
        jp z, .waitForFire

    .waitForSecondRelease:
        call ReadTrigger
        and a
        jp nz, .waitForSecondRelease

        ret


StartNewGame:
    ;; Initialize basic things
        ld a, C_INITIAL_LIVES
        ld (LIVES), a
        ld a, 0
        ld bc, 7
        ld de, SCORE_ADD + 1
        ld hl, SCORE_ADD
        ld (hl), a
        ldir
        ld a, 1
        ld (LEVEL), a
        ;call ResetDisplay
        call PrepareGameField
        call ResetScore
        call RedrawHighscore
        call InitRound  ;; Check this order.
        call UpdateScore
        call UpdateLives
        ret



InitGame:
        ld de, HIGHSCORE
        ld hl, INIT_HIGHSCORE
        ld bc, 7
        ldir

        ld a, STATE_MENU

        ld (GAME_STATE), a

        call PrepareScreenFirstTime

        jp TitleScreen


Gameloop:
        ld a, (GAME_STATE)
        cp STATE_MENU
        ret z


        ld a, (IS_PAL)
        and a
        jp nz, .skipDelay
        ld a, (FRAMECOUNTER)
        inc a
        cp 6
        jp nz, .skipDelayNTSC
        xor a
        ld (FRAMECOUNTER), a
        jp .notClearedByPaintThreshold


    .skipDelayNTSC:
        ld (FRAMECOUNTER), a
    .skipDelay:

        call ControlPlayer
        call MoveEnemies
        call RenderMainSprites
        call UpdateTimer

        ld a, (GAME_STATE)
        cp STATE_START_DYING
        jp z, .playerDying
        cp STATE_LEVEL_CLEARED_ENEMY_LOST
        jp z, .levelWonEnemyLost

        ;; Check if level is cleared
        ;; TODO: Reset the carry flag!
        ld hl, (PAINTED_AREA)
        ex de, hl
        ld hl, (LEVEL_CLEAR_THRESHOLD)
        ld a, h
        cp d
        jp c, .levelClear
        jp nz, .notClearedByPaintThreshold

        ld a, l
        cp e
        jp c, .levelClear
        jp z, .levelClear

    .notClearedByPaintThreshold:
        call WaitForBlank
        jp Gameloop

    .playerDying:
        ;; TODO: Animations.
        ;; Reset enemy locations
        ;; Reset the player location
        ;; TODO Finish
        call PlayerDies
        jp Gameloop

    .levelWonEnemyLost:
        ;; TODO Finish
        call WaitForBlank
        ld hl, SOUND_THUD_2
        call PlaySound

        ;; Animate the death.
        ld ix, (DEFEATED_ENEMY)
        ld a, SPRITE_MAIN_ENEMY_DYING_1
        ld (ix + 2), a
        call RenderMainSprites
        ld b, 10
        call DelayBFrames

        ld ix, (DEFEATED_ENEMY)
        ld a, SPRITE_MAIN_ENEMY_DYING_2
        ld (ix + 2), a
        call RenderMainSprites
        ld b, 10
        call DelayBFrames

        ld ix, (DEFEATED_ENEMY)
        ld a, SPRITE_MAIN_ENEMY_DYING_3
        ld (ix + 2), a
        call RenderMainSprites
        ld b, 10
        call DelayBFrames

        ld ix, (DEFEATED_ENEMY)
        ld a, SPRITE_MAIN_ENEMY_DYING_4
        ld (ix + 2), a
        call RenderMainSprites
        ld b, 20
        call DelayBFrames


        ld a, 2
        ld (SCORING_FACTOR), a

        ld hl, (PAINTED_AREA)
        ld (OLD_PAINTED_AREA), hl

        ld hl, 30976 ;; Full screen
        ld (PAINTED_AREA), hl
        ;; Give the player points.
        call GainScoreFromPainting


    .levelClear:
        ;; Level cleared!
        ;; TODO: Bonuses
        call ClearSpritesNotTimer

        ld hl, SOUND_LEVEL_CLEAR
        call PlaySound

        ld b, 50
        call DelayBFrames


        call LevelEndAnimations
        ld hl, LEVEL
        inc (hl)
        call WaitForBlank
        call ClearRAM
        call PrepareGameField
        call TraceOutline
        call RepaintVRAM

        call InitRound
        jp Gameloop

DelayBFrames:
        call WaitForBlank
        djnz DelayBFrames
        ret

LevelEndAnimations:
        ;; Count down timer for timer bonus points.

        ld a, 5
        ld (TEMP_WORD), a
        call Sound_TimerBonusStart
        ld a, (SCORING_FACTOR)
        cp 1
        jp z, .loopTimeDown
        ld a, 10
        ld (TEMP_WORD), a

        ld a, 200
        ld (TEMP_WORD + 1), a


    .loopTimeDown:
        ld hl, TIME_LEFT
        ld a, (hl)
        cp 0
        jp z, .timeOver


        ld a, (TEMP_WORD + 1)
        dec a
        ld (TEMP_WORD + 1), a

        call Sound_TimerBonusDown

        call UpdateTimer.delayTimerZero

        ld hl, SCORE_ADD

        ;ld a, 5
        ld a, (TEMP_WORD)
        ld (hl), a
        call UpdateScore
        call UpdateHighscore

        ld b, 2
        call DelayBFrames

        jp .loopTimeDown

    .timeOver:
        call Sound_Silence
        ret


;; Player dies
PlayerDies:
        ld a, (LAST_NONDRAWING_X)
        ld (PLAYER_X), a
        ld a, (LAST_NONDRAWING_Y)
        ld (PLAYER_Y), a
        ld a, STATE_NOT_DRAWING
        ld (GAME_STATE), a
        call ResetTimer


        ld a, (LIVES)
        cp 0
        jp z, .gameOver
        dec a
        ld (LIVES), a

        ld hl, SOUND_SHORT_HIGHER_THUD
        call PlaySound

        call UpdateLives

        call ResetTracers

        call RemoveUnfinishedLineVRAM
        ;call RepaintVRAM
        call RenderMainSprites

        ;; Delay as we clear the drawing part of memory
        ld bc, 24*22*8 -2
        ld hl, DRAWN_LINE
        ld a, 0
        ld (hl), a
        ld de, DRAWN_LINE + 1
        ldir

        ret
    .gameOver:

        ld hl, SOUND_VERY_LONG_THUD
        call PlaySound

        ld b, 25
        call DelayBFrames

        call ClearSprites
        call HideTimer
        call DisplayGameover
        call WaitForFire

        ld a, STATE_MENU
        ld (GAME_STATE), a
        ret


ResetTracers:
        ;; Go through all tracers and if they're not lost,
        ;; randomize their locations to give the player invulnerability time.
        ld ix, BORDER_ENEMY_1
        call .tryResetting

        ld ix, BORDER_ENEMY_2
        call .tryResetting

        ld ix, BORDER_ENEMY_3
        call .tryResetting

        ld ix, BORDER_ENEMY_4
        call .tryResetting

        ld ix, BORDER_ENEMY_5
        call .tryResetting

        ld ix, BORDER_ENEMY_6
        call .tryResetting
        ret

    .tryResetting:
        ld a, (ix + 3)
        cp ENEMY_STATE_NOT_ACTIVE
        ret z
        call TracerActions.despawnOver
        ret




HideTimer:
        ld hl, VRAM_BLOCKTABLE + 23*32 + 2
        ld a, C_BLANK_BACKGROUND
        ld bc, 20
        call FILVRM
        ret




ResetTimer:
        call HideTimer


        ld a, (LEVEL_TIME)
        ld (TIME_LEFT), a
        ld a, 1 ;TIME_FRAMES_PER_PIXEL
        ld (DELAY_TIMER), a

        ld a, (TIME_LEFT)
        ld b, a
        ld a, 168
        sub b
        rrca
        rrca
        rrca
        and %00011111
        ;dec a

        ld hl, VRAM_BLOCKTABLE + 23*32+2
        ld d, 0
        ld e, a
        add hl, de
        ld a, 20

        sub e
        ld c, a
        ld b, 0
        ld a, C_TIMER_LINE
        ;ld hl, VRAM_BLOCKTABLE + 23*32 + 2
        call FILVRM
        ld hl, VRAM_BLOCKTABLE + 23*32 + 22
        ld a, C_TIMER_END
        call WRTVRM
        ret

C_TIMER_LINE: EQU 187
C_TIMER_END: EQU 188




GainScoreFromPainting:
        ;; SCORING, check level limit.
        ld hl, (OLD_PAINTED_AREA)
        ex de, hl
        ld hl, (PAINTED_AREA)
        or a
        sbc hl, de


        ;; HL now has the new painted area

        ;; Split it in half.
        srl h
        rr l

        ;; Split it into 25%.
        srl h
        rr l

        inc hl ; Just to make sure the player gets some points.

        call WaitForBlank
        ld ix, SCORE_ADD

       ; + 0 = ones
       ; + 1 = tens
       ; + 2 = hundreds
       ; + 3 = thousands
       ; + 4 = 10000s

    .additionLoop:
        ld (TEMP_WORD), hl
        ld a, b
        ld (TEMP_WORD + 2), a


    .loop10000:
        ld de, 10000
        or a
        sbc hl, de
        jp c, .excess10000
        or a
        inc (ix + 4)
        jp .loop10000

    .excess10000:
        add hl, de

        ld de, 1000
    .loop1000:
        or a
        sbc hl, de
        jp c, .excess1000
        or a
        inc (ix + 3)
        jp .loop1000

    .excess1000:
        add hl, de
        ld de, 1000

    .loop100:
        or a
        sbc hl, de
        jp c, .excess100
        or a
        inc (ix + 2)
        jp .loop100

    .excess100:
        add hl, de
        ld a, l
        ld (ix), a

        push bc
        call UpdateScore ;; Todo: Maybe not the redraw?
        pop bc

       ; djnz .additionLoop

        call UpdateHighscore

        ret


MoveEnemies:
        call TracerActions
        call MainEnemyActions

        ret


INIT_BORDER_ENEMY_1:
    DB 10*8
    DB 0
    DB DIR_WEST
    DB ENEMY_STATE_NOT_ACTIVE
    DB 0
    DB 1

INIT_BORDER_ENEMY_2:
    DB 12*8
    DB 0
    DB DIR_EAST
    DB ENEMY_STATE_NOT_ACTIVE
    DB 0
    DB 0


    ;; +0: X
    ;; +1: Y
    ;; +2: DIR
    ;; +3: STATE
    ;; +4: DELAY
    ;; +5: ROTATION DIRECTION (0=CW, 1=CCW)

INIT_ENEMY_SOLO:
    DB 22*8/2
    DB 22*8/2
    DB SPRITE_MAIN_ENEMY
    DB 12
    DB ENEMY_STATE_MOVE_NORTH
    DB 20
    ;; The second enemy is disabled.
    DB 0, 0, 0, 0, ENEMY_STATE_NOT_ACTIVE, 1

INIT_ENEMY_TWO:
    DB 22*8/4
    DB 22*8/2
    DB SPRITE_MAIN_ENEMY
    DB 12
    DB ENEMY_STATE_MOVE_SOUTH
    DB 20

    DB 3*22*8/4
    DB 22*8/2
    DB SPRITE_MAIN_ENEMY
    DB 12
    DB ENEMY_STATE_MOVE_SOUTH
    DB 20

INIT_TRACERS:
    DB 22*8/4 ;; +0: X
    DB 0 ;; +1: Y
    DB DIR_WEST ;; +2: DIR
    DB ENEMY_STATE_TRACING ;; +3: STATE
    DB 0 ;; +4: DELAY
    DB 1 ;;  +5: ROTATION DIRECTION (0=CW, 1=CCW)

    DB 3*22*8/4 ;; +0: X
    DB 0 ;; +1: Y
    DB DIR_EAST ;; +2: DIR
    DB ENEMY_STATE_TRACING ;; +3: STATE
    DB 0 ;; +4: DELAY
    DB 0 ;;  +5: ROTATION DIRECTION (0=CW, 1=CCW)

    DB 0 ;; +1: X
    DB 22*8/4 ;; +0: Y
    DB DIR_SOUTH ;; +2: DIR
    DB ENEMY_STATE_TRACING ;; +3: STATE
    DB 0 ;; +4: DELAY
    DB 1 ;;  +5: ROTATION DIRECTION (0=CW, 1=CCW)

    DB 22*8 - 2 ;; +1: X
    DB 22*8/4 ;; +0: Y
    DB DIR_SOUTH ;; +2: DIR
    DB ENEMY_STATE_TRACING ;; +3: STATE
    DB 0 ;; +4: DELAY
    DB 10 ;;  +5: ROTATION DIRECTION (0=CW, 1=CCW)

    DB 0 ;; +1: X
    DB 3*22*8/4 ;; +0: Y
    DB DIR_SOUTH ;; +2: DIR
    DB ENEMY_STATE_TRACING ;; +3: STATE
    DB 0 ;; +4: DELAY
    DB 1 ;;  +5: ROTATION DIRECTION (0=CW, 1=CCW)

    DB 22*8 - 2 ;; +1: X
    DB 3*22*8/4 ;; +0: Y
    DB DIR_SOUTH ;; +2: DIR
    DB ENEMY_STATE_TRACING ;; +3: STATE
    DB 0 ;; +4: DELAY
    DB 10 ;;  +5: ROTATION DIRECTION (0=CW, 1=CCW)



InitRound:
        ld a, 1
        ld (SCORING_FACTOR), a
        ld a, 0
        ld (CURRENT_COVERAGE), a

        call SceneStatsToIX


        ;; Copy the level backgrounds.
        ld de, LEVEL_BACKGROUNDS
        ld a, (ix + 5)
        ld h, 0
        ld l, a
        add hl, hl
        add hl, hl
        add hl, hl
        add hl, de

        ld bc, 8
        ld de, CURRENT_LEVEL_BACKGROUND
        ldir




        ;; Player's location and constant stuff.
        ld a, 22*8 / 2
        ld (PLAYER_X), a
        ld a, 22*8 - 2
        ld (PLAYER_Y), a

        ;; Set the paint threshold
        ld a, (ix)

        ld (GOAL_COVERAGE), a

        ld h, 0
        ld l, a
        add hl, hl ;; Two bytes per percent.
        ld de, PAINT_THRESHOLDS
        add hl, de
        ld a, (hl)
        inc hl
        ld b, (hl)
        ld hl, LEVEL_CLEAR_THRESHOLD
        ld (hl), a
        inc hl
        ld (hl), b

        ;; At least one main enemy always.
        ld hl, INIT_ENEMY_SOLO
        ld a, (ix + 2)
        cp 1
        jp z, .initMainEnemies
        ld hl, INIT_ENEMY_TWO

    .initMainEnemies:
        ld de, MAIN_ENEMY_1
        ld bc, 2 * C_LEN_MAIN_ENEMY
        ldir


        ;; Now, init the tracers.

        ;; First, wipe everything clean.
        ld bc, 6 * C_LEN_BORDER_ENEMY - 1
        ld de, BORDER_ENEMY_1 + 1
        ld hl, BORDER_ENEMY_1
        ld a, ENEMY_STATE_NOT_ACTIVE
        ld (hl), a
        ldir

        ;; Second, copy the initials of only those that we need.
        ld a, (ix + 1)
        ld b, a
        rlca
        add a, b
        rlca
        ld b, 0
        ld c, a
        ld hl, INIT_TRACERS
        ld de, BORDER_ENEMY_1
        ldir


        ;; TODO: Init the rest -- speed and timer
        ld a, (ix + 4)
        ld (LEVEL_TIME), a


        call ResetTimer

        ;; TODO: Redraw the timer line at the bottom!
        call UpdateTimer
        call UpdateScene
        call UpdateScore

        ;; TODO: Initialize the edge enemies
        ld a, STATE_NOT_DRAWING
        ld (GAME_STATE), a


        call ResetDisplayForGame
        call DetermineScan
        call UpdateCoverages

        ret




ClearSprites:
        ;; Hide all sprites.
        ld b, 16
        ld a, 200
        ld (SPRITE_VALS), a
        ld (SPRITE_VALS + 1), a
        ld (SPRITE_VALS + 2), a
        ld (SPRITE_VALS + 3), a

    .loop:
        push bc
        ld a, b
        dec a

        call CALATR
        ld bc, 4
        ex de, hl
        ld hl, SPRITE_VALS
        call LDIRVM

        pop bc
        djnz .loop
        ret

ClearSpritesNotTimer:
        ;; Hide all sprites.
        ld b, 16
        ld a, 200
        ld (SPRITE_VALS), a
        ld (SPRITE_VALS + 1), a
        ld (SPRITE_VALS + 2), a
        ld (SPRITE_VALS + 3), a

    .loop:
        push bc
        ld a, b

        call CALATR
        ld bc, 4
        ex de, hl
        ld hl, SPRITE_VALS
        call LDIRVM

        pop bc
        djnz .loop
        ret


RenderMainSprites:

        ;ld a, (FRAMECOUNTER)
        ;and 1
        jp .even

		ld a, SPRITE_PLAYER ;; Pattern
		ld (SPRITE_VALS + 2), a
		ld a, 1
		call CALATR
		ex de, hl
		ld a, 8 ;; Colour
		ld (SPRITE_VALS + 3), a
		ld a, (PLAYER_Y)
		ld (SPRITE_VALS), a
		ld a, (PLAYER_X)
		ld (SPRITE_VALS + 1), a
		ld hl, SPRITE_VALS
		ld bc, 4
		call LDIRVM

		ld a, 9
		call CALATR
		ex de, hl
		ld hl, MAIN_ENEMY_1
		ld bc, 4
		call LDIRVM

		ld a, 8
		call CALATR
		ex de, hl
		ld hl, MAIN_ENEMY_2
		ld bc, 4
		call LDIRVM



    .borderEnemies2:
		;; Render border enemies

		ld a, 7
		ld hl, TEMP_WORD
		ld (hl), a

		ld ix, BORDER_ENEMY_1
		call .renderTracer

		inc (hl)
		ld ix, BORDER_ENEMY_2
		call .renderTracer

		inc (hl)
		ld ix, BORDER_ENEMY_3
		call .renderTracer

		inc (hl)
		ld ix, BORDER_ENEMY_4
		call .renderTracer

		inc (hl)
		ld ix, BORDER_ENEMY_5
		call .renderTracer

		inc (hl)
		ld ix, BORDER_ENEMY_6
		call .renderTracer
		ret

    .even:
		ld a, SPRITE_PLAYER ;; Pattern
		ld (SPRITE_VALS + 2), a
		ld a, 1
		call CALATR
		ex de, hl
		ld a, 8 ;; Colour
		ld (SPRITE_VALS + 3), a
		ld a, (PLAYER_Y)
		ld (SPRITE_VALS), a
		ld a, (PLAYER_X)
		ld (SPRITE_VALS + 1), a
		ld hl, SPRITE_VALS
		ld bc, 4
		call LDIRVM

		ld a, 2
		call CALATR
		ex de, hl
		ld hl, MAIN_ENEMY_1
		ld bc, 4
		call LDIRVM

		ld a, 3
		call CALATR
		ex de, hl
		ld hl, MAIN_ENEMY_2
		ld bc, 4
		call LDIRVM



    .borderEnemies:
		;; Render border enemies

		ld a, 4
		ld hl, TEMP_WORD
		ld (hl), a

		ld ix, BORDER_ENEMY_1
		call .renderTracer

		inc (hl)
		ld ix, BORDER_ENEMY_2
		call .renderTracer

		inc (hl)
		ld ix, BORDER_ENEMY_3
		call .renderTracer

		inc (hl)
		ld ix, BORDER_ENEMY_4
		call .renderTracer

		inc (hl)
		ld ix, BORDER_ENEMY_5
		call .renderTracer

		inc (hl)
		ld ix, BORDER_ENEMY_6
		call .renderTracer
		ret


    .tracerDespawning:
        ld a, (ix + 4)
        cp 50
        jp c, .tracerDespawned
        cp 75
        jp c, .tracerDespawningLate
        ld a, SPRITE_TRACER_DESPAWN_1
		ld (SPRITE_VALS + 2), a
		ld a, 10
		ld (SPRITE_VALS + 3), a
		jp .writeTracerData
    .tracerDespawningLate:
        ld a, SPRITE_TRACER_DESPAWN_2
		ld (SPRITE_VALS + 2), a
		ld a, 11
		ld (SPRITE_VALS + 3), a
		jp .writeTracerData


    .tracerDespawned:
        ld a, SPRITE_EMPTY
		ld (SPRITE_VALS + 2), a
		ld a, 14
		ld (SPRITE_VALS + 3), a
		jp .writeTracerData


    .tracerRespawning:
        ld a, (ix + 4)
        cp 25
        jp c, .tracerRespawningLate
        ld a, SPRITE_TRACER_RESPAWN_1
		ld (SPRITE_VALS + 2), a
		ld a, 10
		ld (SPRITE_VALS + 3), a
		jp .writeTracerData

    .tracerRespawningLate:
        ld a, SPRITE_TRACER_RESPAWN_2
		ld (SPRITE_VALS + 2), a
		ld a, 9
		ld (SPRITE_VALS + 3), a
		jp .writeTracerData


    .renderTracer:
        ld a, (ix + 3)
        cp ENEMY_STATE_NOT_ACTIVE
        ret z

        cp ENEMY_STATE_DESPAWNING
        jp z, .tracerDespawning
        cp ENEMY_STATE_RESPAWNING
        jp z, .tracerRespawning

        ld a, (ix + 2)
        inc a

        add a, a
        add a, a
        ;rlca
        ;rlca
		ld (SPRITE_VALS + 2), a
		ld a, 8
		ld (SPRITE_VALS + 3), a


    .writeTracerData:
		ld a, (hl)
		push hl
		call CALATR
		ex de, hl
		ld a, (ix + 0)
		ld (SPRITE_VALS + 1), a
		ld a, (ix + 1)
		ld (SPRITE_VALS), a
		ld hl, SPRITE_VALS
		ld bc, 4
		call LDIRVM
		pop hl
		ret

ResetScore:
    ;; Set the current score to zero.
        ld hl, SCORE
        ld b, 8
        ld a, 0
    .loop:
        ld (hl), a
        inc hl
        djnz .loop
        ret

UpdateHighscore:
        ld iy, SCORE + 6
        ld ix, HIGHSCORE + 6

        ld b, 7
    .loop:
        ld a, (iy)
        ld c, (ix)
        cp c
        ret c
        jp nz, .better
        dec iy
        dec ix

        djnz .loop

    .better:
        ld bc, 7
        ld de, HIGHSCORE
        ld hl, SCORE
        ldir
        call RedrawHighscore
        ret



RedrawHighscore:
        ld de, HISCORETABLE_IND
        ld hl, HIGHSCORE
        call RenderScoreDEHL
        ret

UpdateScore:
        ld ix, SCORE_ADD
        ld iy, SCORE
        ld b, 8
    .loop:
        ;; Add what is added and what is already there.
        ld a, (ix)
        ld c, (iy)
        add a, c
        ld c, 0
        ld (ix), c ;; Done adding.
        ld (iy), a ;; Storing new value to SCORE.
    .loopInTens:
        cp 10
        jp c, .nextDigit
        inc (iy + 1)
        sub 10
        ld (iy), a
        jp .loopInTens

    .nextDigit:
        inc ix
        inc iy
        djnz .loop

        ld de, SCORETABLE_IND
        ld hl, SCORE
        call RenderScoreDEHL
        ret


;        ld b, 7
;        ld de, SCORETABLE_IND
;        ld hl, SCORE
;    .printDigit:
;        ld a, (hl)
;        ex de, hl
;        add a, C_DIGIT_ZERO
;        call WRTVRM
;        dec hl
;        ex de, hl
;        inc hl
;        djnz .printDigit
;        ret

RenderScoreDEHL:
    ; DE = VRAM address
    ; HL = memory
        ld b, 7
    .printDigit:
        ld a, (hl)
        ex de, hl
        add a, C_DIGIT_ZERO
        call WRTVRM
        dec hl
        ex de, hl
        inc hl
        djnz .printDigit
        ret


UpdateLives:
        ld hl, LIVES_STACK_IND
        ld b, 7
    .loop:
        ld a, (LIVES)
        cp b
        jp nc, .drawIcon
        ld a, C_BLANK_BACKGROUND
    .render:
        call WRTVRM
        dec hl
        djnz .loop
        ret
    .drawIcon:
        ld a, C_LIFE_ICON
        jp .render

UpdateScene:
        ld hl, SCENE_IND
        ld a, (LEVEL)
        ld b, 0
    .loopTens:
        cp 10
        jp c, .done
        sub 10
        inc b
        jp .loopTens
    .done:
        add a, C_DIGIT_ZERO
        call WRTVRM
        ld a, b
        add a, C_DIGIT_ZERO
        dec hl
        call WRTVRM
        ret





C_BLANK_BACKGROUND: EQU 176
C_DIGIT_ZERO: EQU 177
SCORETABLE_IND: EQU VRAM_BLOCKTABLE + 16*32 + 30
HISCORETABLE_IND: EQU VRAM_BLOCKTABLE + 19*32+30
LIVES_STACK_IND: EQU VRAM_BLOCKTABLE + 7*32 + 30
SCENE_IND: EQU VRAM_BLOCKTABLE + 13*32 + 30
C_LIFE_ICON: EQU 181





EternalLoop:
    jp EternalLoop


ReadTrigger:
    ld a, 0
    call GTTRIG
    cp 0
    ret nz
    ld a, 1
    call GTTRIG
    ret

ReadDirection:
    ld a, 0
    call GTSTCK
    cp 0
    ret nz
    ld a, 1
    call GTSTCK
    ret



CheckIsMainEnemyOutside:
    ;; This should be called ONLY right after a paint, because this is a slow
    ;; operation.
        ld ix, MAIN_ENEMY_1
        call .scanOneEnemy
        ld ix, MAIN_ENEMY_2
        ld a, (ix + 4)
        cp ENEMY_STATE_NOT_ACTIVE
        ret z
        call .scanOneEnemy
        ret

    .scanOneEnemy:

        ld a, (ix + 1)
        ld (PIX_X), a
        ld b, a
        inc b ;; We need to check the PIX_X = 0 as well.
        ld a, (ix)
        or 1 ;; Force to look at an odd row.
        ld (PIX_Y), a
        ld c, 0

    .loop:
        push bc
        call IsPixelLitRAM
        jp nz, .counted
        pop bc
        ld hl, PIX_X
        dec (hl)
        djnz .loop

    .endLoop:
        ld a, c
        and 1
        ret nz ;; outside
        jp MainEnemyActions.enemyDestroyed



    .counted:
        pop bc
        inc c
        ld hl, PIX_X
        dec (hl)
        djnz .loop
        jp .endLoop




ControlPlayer:
    ;; Read direction, check if can be moved there, check if fire pressed.

        ; Uncomment these to make the player move at half the speed the enemies
        ; move.
        ;ld a, (PLAYER_MOVED)
        ;cp 0
        ;jp z, .playerCanMove
        ;xor a
        ;ld (PLAYER_MOVED), a
        ;ret



    .playerCanMove:

    ;; Remember, 2px steps!

        ld a, (GAME_STATE)
        cp 1
        jp z, .notDrawing

    .drawing: ;; The player is now drawing a new line.
        call ReadDirection
        ld (PLAYER_DIR), a

        ;; Ignore diagonal directions and not moving anywhere.
        bit 0, a
        jp z, .delayingDrawing
        cp 0
        jp z, .delayingDrawing

        ;; See if the step in the movement direction is not painted ;
        ;; if not, we can draw there.
        call UpdatePlayerStepToPix
        call IsPixelLit
        jp z, .canMove

        call IsPixelLitRAM
        jp nz, .closeGap
        ;; Would loop, cannot move.
        jp .delayingDrawing

    .canMove:
        ; Okay, we can draw. Paint both the next step and the one after it.
        call PsetVRAM
        call PsetLineRAM
        call UpdatePlayerMoveToPix
        call PsetVRAM
        call PsetLineRAM
        call UpdatePlayerMove
        ;; TODO:
        ;; - update line length counter etc.
        ret


    .closeGap:
        ; The player closes off the area.
        ;
        ; Finish closing off an area.
        call .canMove
        ; Now, fill it in.
        ld a, STATE_NOT_DRAWING
        ld (GAME_STATE), a

        ld hl, SOUND_CLAIMED
        call PlaySound


        call AreaClosed
        call GainScoreFromPainting
        call UpdateCoverages

        call CheckIsMainEnemyOutside
        ret


    .notDrawing: ;; The player is not currently drawing a new line.
        ld a, (PLAYER_X)
        ld (LAST_NONDRAWING_X), a
        ld a, (PLAYER_Y)
        ld (LAST_NONDRAWING_Y), a
        call ReadTrigger
        and a
        jp nz, .canStartDrawing

        call ReadDirection
        and a
        ret z
        ld (PLAYER_DIR), a

        ;; RAM depicts where the player can move => we can use that to mask
        ;; where the player moves.
        call UpdatePlayerMoveToPix
        call IsPixelLitRAM_BB
        jp nz, .acceptMove
        ;; The player is not doing anything.
        ret

    .acceptMove: ;; Move without painting.
        ;; Just change the player's position.
        call UpdatePlayerMove
        ld a, 1
        ld (PLAYER_MOVED), a
        ret

    .canStartDrawing:
        call ReadDirection
        and a
        ret z ;; Not moving.
        ld (PLAYER_DIR), a

        call UpdatePlayerMoveToPix
        ;; If we move where RAM copy is on, don't start drawing but move.
        call IsPixelLitRAM_BB
        jp nz, .acceptMove

        ;; If we move where VRAM copy is on, don't move or start drawing.
        call IsPixelLit_BBTrue ;; Outside border sets nz
        ret nz
        ;; If we move where VRAM copy is off, start drawing.
        ;; (This is also the last option left.)

        ld a, STATE_DRAWING
        ld (GAME_STATE), a

        call PsetVRAM
        call PsetLineRAM
        call UpdatePlayerStepToPix
        call PsetVRAM
        call PsetLineRAM
        call UpdatePlayerMove
        ret



    .delayingDrawing:
        ;; TODO. Increase delay!
        ret



UpdatePlayerMove:
        ld hl, DELTAS_STEP
        ld d, 0
        ld a, (PLAYER_DIR)
        sla a
        ld e, a
        add hl, de
        ld a, (PLAYER_X)
        add a, (hl)
        ld (PLAYER_X), a
        ld a, (PLAYER_Y)
        inc hl
        add a, (hl)
        ld (PLAYER_Y), a

        ld a, 1
        ld (PLAYER_MOVED), a

        ret




UpdatePlayerMoveToPix:
        ld hl, DELTAS_PIX
        ld d, 0
        ld a, (PLAYER_DIR)
        sla a
        ld e, a
        add hl, de
        ld a, (PLAYER_X)
        add a, (hl)
        ld (PIX_X), a
        ld a, (PLAYER_Y)
        inc hl
        add a, (hl)
        ld (PIX_Y), a
        ret

UpdatePlayerStepToPix:
        ld hl, DELTAS_STEP
        ld d, 0
        ld a, (PLAYER_DIR)
        sla a
        ld e, a
        add hl, de
        ld a, (PLAYER_X)
        add a, (hl)
        ld (PIX_X), a
        ld a, (PLAYER_Y)
        inc hl
        add a, (hl)
        ld (PIX_Y), a
        ret


DELTAS_STEP: DB 0, 0,  0, -2, 0, 0,  2, 0, 0, 0,  0, 2, 0, 0,  -2, 0, 0, 0
DELTAS_PIX:  DB 0, 0,  0, -1, 0, 0,  1, 0, 0, 0,  0, 1, 0, 0,  -1, 0, 0, 0


UpdateCoverages:
        ld hl, (PAINTED_AREA)
        ex de, hl
        ld hl, PAINT_THRESHOLDS
        inc hl
        ld b, 0
    .loopOne: ;; Compare the most significant.
        ld a, (hl) ;; More significant byte
        cp d
        jp z, .prepLoopTwo
        jp nc, .limitExceeded

        inc hl
        inc hl
        inc b
        jp .loopOne


    .prepLoopTwo:
        dec hl
        ld a, (hl)
        cp e
        jp z, .limitFound
        jp nc, .limitExceeded
        jp .limitFound

    .limitExceeded:
        dec b
    .limitFound:
        ld a, b
        ld (CURRENT_COVERAGE), a

        ld hl, CURRENT_COVERAGE_IND
        ld a, (CURRENT_COVERAGE)
        call UpdateTwoDigit
        ld hl, GOAL_COVERAGE_IND
        ld a, (GOAL_COVERAGE)
        call UpdateTwoDigit
        ret



UpdateTwoDigit:
        ld b, 0
    .loopTens:
        cp 10
        jp c, .done
        sub 10
        inc b
        jp .loopTens
    .done:
        add a, C_DIGIT_ZERO
        call WRTVRM
        ld a, b
        add a, C_DIGIT_ZERO
        dec hl
        call WRTVRM
        ret


CURRENT_COVERAGE_IND: EQU VRAM_BLOCKTABLE + 10 * 32 + 25
GOAL_COVERAGE_IND: EQU VRAM_BLOCKTABLE + 10 * 32 + 29



UpdateTimer:
        ld a, (DELAY_TIMER)
        dec a
        jp z, .delayTimerZero
        ld (DELAY_TIMER), a
        ret
    .delayTimerZero:
        ld a, TIME_FRAMES_PER_PIXEL
        ld (DELAY_TIMER), a
        ld a, (TIME_LEFT)
        dec a
        jp z, .timeOver
        ld (TIME_LEFT), a
        ld b, a

        ;; Move timer sprite.
        ld a, 168
        sub a, b
        push af
        ld (SPRITE_VALS + 1), a ;;
        ld a, 183
        ld (SPRITE_VALS), a
        ld a, SPRITE_TIMER
        ld (SPRITE_VALS + 2), a
        ld a, 4
        ld (SPRITE_VALS + 3), a
        ld a, 0
        call CALATR
        ex de, hl
        ld hl, SPRITE_VALS
        ld bc, 4
        call LDIRVM

        pop bc
        ld a, %00000111 ;; Is it divisible by 8?
        and b
        ret nz
        ;; Okay, we need to change the display byte.
        ld hl, VRAM_BLOCKTABLE + 23*32 + 1 ;; +1 because the sprite shape
        ld a, b
        rrca
        rrca
        rrca
        and %00011111
        ld d, 0
        ld e, a
        add hl, de ;; This should get the character right
        ld a, SPENT_TIMERBAR
        call WRTVRM
        ret

    .timeOver:
        ld (TIME_LEFT), a
        ld a, STATE_START_DYING
        ld (GAME_STATE), a
        ret


C_LEVEL_CAP: EQU 17

SceneStatsToIX:
        ld a, (LEVEL)
        dec a
        cp C_LEVEL_CAP
        jp c, .allOk

        ld a, C_LEVEL_CAP ;; The last stage will repeat.

    .allOk:
        add a, a
        add a, a
        add a, a
        ld l, a
        ld h, 0
        ld de, SCENE_STATS
        add hl, de
        push hl
        pop ix
        ret



SCENE_STATS_ORIG:
    ;; Threshold, tracers, main enemies, speed level, timer, BG, 0, 0
    DB        70,       1,            1,           1,   168,  0, 0, 0
    DB        70,       2,            1,           1,   168,  1, 0, 0
    DB        75,       2,            2,           1,   168,  2, 0, 0
    DB        75,       3,            2,           1,   168,  3, 0, 0
    DB        75,       3,            2,           1,   168,  0, 0, 0

    DB        77,       3,            2,           1,   168,  1, 0, 0
    DB        77,       3,            2,           1,   168,  2, 0, 0
    DB        77,       4,            2,           1,   168,  3, 0, 0
    DB        77,       4,            2,           1,   168,  4, 0, 0
    DB        80,       4,            2,           1,   168,  5, 0, 0

    DB        80,       4,            2,           1,   168,  1, 0, 0
    DB        80,       5,            2,           1,   168,  2, 0, 0
    DB        80,       5,            2,           1,   168,  3, 0, 0
    DB        85,       5,            2,           1,   168,  4, 0, 0
    DB        85,       5,            2,           1,   168,  5, 0, 0

    DB        85,       5,            2,           1,   168,  6, 0, 0
    DB        85,       5,            2,           1,   168,  7, 0, 0
    DB        90,       5,            2,           1,   168,  8, 0, 0

SCENE_STATS:
    ;; Threshold, tracers, main enemies, speed level, timer, BG, 0, 0
    DB        70,       1,            1,           1,   168,  0, 0, 0
    DB        70,       2,            1,           1,   168,  1, 0, 0
    DB        75,       2,            2,           1,   168,  2, 0, 0
    DB        75,       3,            2,           1,   168,  3, 0, 0
    DB        75,       3,            2,           1,   168,  4, 0, 0

    DB        77,       3,            2,           1,   168,  0, 0, 0
    DB        77,       3,            2,           1,   168,  1, 0, 0
    DB        77,       4,            2,           1,   168,  2, 0, 0
    DB        77,       4,            2,           1,   168,  3, 0, 0
    DB        80,       4,            2,           1,   168,  4, 0, 0

    DB        80,       4,            2,           1,   168,  0, 0, 0
    DB        80,       5,            2,           1,   168,  1, 0, 0
    DB        80,       5,            2,           1,   168,  2, 0, 0
    DB        85,       5,            2,           1,   168,  3, 0, 0
    DB        85,       5,            2,           1,   168,  4, 0, 0

    DB        85,       5,            2,           1,   168,  0, 0, 0
    DB        85,       5,            2,           1,   168,  1, 0, 0
    DB        90,       5,            2,           1,   168,  2, 0, 0

SCENE_STATS_NEW:
    ;; Threshold, tracers, main enemies, speed level, timer, BG, 0, 0
    DB        70,       1,            1,           1,   168,  2, 0, 0
    DB        70,       2,            1,           1,   168,  2, 0, 0
    DB        75,       2,            2,           1,   168,  2, 0, 0
    DB        75,       3,            2,           1,   168,  2, 0, 0
    DB        75,       3,            2,           1,   168,  2, 0, 0

    DB        77,       3,            2,           1,   168,  2, 0, 0
    DB        77,       3,            2,           1,   168,  2, 0, 0
    DB        77,       4,            2,           1,   168,  2, 0, 0
    DB        77,       4,            2,           1,   168,  2, 0, 0
    DB        80,       4,            2,           1,   168,  2, 0, 0

    DB        80,       4,            2,           1,   168,  2, 0, 0
    DB        80,       5,            2,           1,   168,  2, 0, 0
    DB        80,       5,            2,           1,   168,  2, 0, 0
    DB        85,       5,            2,           1,   168,  2, 0, 0
    DB        85,       5,            2,           1,   168,  2, 0, 0

    DB        85,       5,            2,           1,   168,  2, 0, 0
    DB        85,       5,            2,           1,   168,  2, 0, 0
    DB        90,       5,            2,           1,   168,  2, 0, 0





