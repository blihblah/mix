
;; Simple sound effects.

Sound_TimerBonusStart:
    ld a, 13 ;; SOUND 13, 4
    ld e, 4
    call WRTPSG

    ld e, 10000 MOD 256 ;; SOUND 11, 10000 % 256
    ld a, 11
    call WRTPSG

    ld e, 10000 / 256 ;; SOUND 12, 10000 / 256
    ld a, 12
    call WRTPSG

    ld a, 8
    ld e, 8
    call WRTPSG

    ld a, %10111110
    ld e, 7
    call WRTPSG
    ret



Sound_TimerBonusDown:
    ;; A = timer done
    ld b, a
    rlca
    rlca
    rlca
    and %11111000
    ld e, a
    ld a, 0
    call WRTPSG

    ld a, b
    rrca
    rrca
    rrca
    rrca
    rrca
    and %00000111
    ld e, a
    ld a, 1
    call WRTPSG

    ld a, 8
    ld e, 8
    call WRTPSG

    ret


Sound_Silence:
    ld e, %10111111
    ld a, 7
    call WRTPSG

    ld e, 0
    ld a, 8
    call WRTPSG
    ret


PlaySound:
        ;; Basically,
        ;; LD HL, SOUND_CRASH
        ;; Call PlaySound
        ;; HL contains the effect data.
        ld a, (hl)
        cp -1
        ret z
        cp 128
        jp nc, .delay

        inc hl
        ld e, (hl)
        inc hl
        push hl
        call WRTPSG
        pop hl
        jp PlaySound

	.delay:
	    neg
	    ld b, a
	    dec b
    .delayLoop:
	    call WaitForBlank
	    djnz .delayLoop
	    inc hl
	    jp PlaySound



SOUND_THUD:
    DB 0, 100
    DB 1, 0
    DB 7, %10110111
    DB 11, 200
    DB 12, 10
    DB 8, 24
    DB 13, 0
    DB -1

SOUND_THUD_2:
    DB 8,24
    DB 0, 100
    DB 1, 15
    DB 7, %10110110
    DB 11, 200
    DB 12, 20
    DB 13, 0
    DB -1

SOUND_VERY_LONG_THUD:
    DB 8, 24
    DB 0, 100
    DB 1, 15
    DB 7, %10110110
    DB 11, 200
    DB 12, 255
    DB 8, 24
    DB 13, 0
    DB -10
    DB -1

SOUND_SHORT_HIGHER_THUD:
    DB 8, 24
    DB 0, 255
    DB 1, 10
    DB 7, %10110110
    DB 11, 200
    DB 12, 20
    DB 13, 0
    DB -1

SOUND_CLAIMED:
    DB 8, 24
    DB 0, 255
    DB 1, 0
    DB 2, 255
    DB 3, 0

    DB 7, %10110110
    DB 11, 200
    DB 12, 20
    DB 13, 0
    DB -1

SOUND_LEVEL_CLEAR:
    DB 8, 24
    DB 7, %10111000
    DB 11, $88
    DB 12, $13

    ; o4 c4r8, e4r8, g4r8
    DB 0, $ac,  1, $1
    DB 2, $53,  3, $1
    DB 4, $1d,  5, $1
    DB 13, 0
    DB -10

    ; o4 c4r8, e4r8, g4r8

    DB 0, $ac,  1, $1
    DB 2, $53,  3, $1
    DB 4, $1d,  5, $1
    DB 13, 0
    DB -10


    ; o4 g2, b2, o5d2
    DB 11, $4c
    DB 12, $1d

    DB 0, $1d,  1, $1
    DB 2, $e3,  0, $1
    DB 4, $be,  5, $0
    DB 13, 0

    DB -40
    DB -1