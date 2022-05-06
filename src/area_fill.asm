;; Quick(?) filler for painted area.
;;
;; Base description:
;; 1. Make a copy of VRAM (relevant parts) to RAM.
;; 2. Trace the outline from a segment
;; 3. Do a row-major scan of the memory copy and fill in the areas


DetermineScan:
        call ClearRAM
        call TraceOutline
        call RepaintVRAM
        ret


AreaClosed:
        ;; The player has finished closing an area.
        ;; First, update RAM copy of the new task area.
        call ClearRAM
        call TraceOutline
        ;; Now, we need to count how many pixels were painted.
        ;; Scan VRAM and RAM together.
        call RepaintVRAM

        ;call GainScoreFromPainting
        ret


WallToLeft:
        ld a, (TRACER_X)
        ld (PIX_X), a
        ld a, (TRACER_Y)
        ld (PIX_Y), a

    .loop:
        call IsPixelLit
        jp nz, .found
        ld a, (TRACER_X)
        dec a
        ld (TRACER_X), a
        ld (PIX_X), a
        jp .loop

    .found:
        ;; Y-coordinate will have remained the same.
        ld a, (PIX_X)
        ld (TRACER_X), a
        ret

WallToLeftRAM:
        ld a, (TRACER_X)
        ld (PIX_X), a
        ld a, (TRACER_Y)
        ld (PIX_Y), a

    .loop:
        call IsPixelLitRAM
        jp nz, .found
        ld a, (TRACER_X)
        dec a
        ld (TRACER_X), a
        ld (PIX_X), a
        jp .loop

    .found:
        ;; Y-coordinate will have remained the same.
        ld a, (PIX_X)
        ld (TRACER_X), a
        ret

WallToRightRAM:
        ld a, (TRACER_X)
        ld (PIX_X), a
        ld a, (TRACER_Y)
        ld (PIX_Y), a

    .loop:
        call IsPixelLitRAM
        jp nz, .found
        ld a, (TRACER_X)
        inc a
        ld (TRACER_X), a
        ld (PIX_X), a
        jp .loop

    .found:
        ;; Y-coordinate will have remained the same.
        ld a, (PIX_X)
        ld (TRACER_X), a
        ret


RemoveUnfinishedLineVRAM:
        ;; We need to use the DRAWN_LINE to undo the lines from VRAM.
        ;; Conveniently, this can be a slow procedure... but this could be
        ;; optimized.
        ld a, 0
        ld (PIX_X), a
        ld (PIX_Y), a
    .loop1:
        ld a, 0
        ld (PIX_X), a
    .loop2:
        call GetLineByte
        cp 0
        jp z, .nextLoop2

        ld b, a
        push bc
        call GetVRAMByte
        pop bc
        xor b
        ld (TO_VRAM), a
        call WriteVRAMByte

    .nextLoop2:
        ld a, (PIX_X)
        add a, 8
        ld (PIX_X), a
        cp 22*8 - 1
        jp c, .loop2

        ld a, (PIX_Y)
        inc a
        cp 22*8
        ret nc
        ld (PIX_Y), a
        jp .loop1



;; Step 1. Clear the RAM copy.
ClearRAM:
        ;; Clear 22x22x8 from VRAM to RAM. But let's make it easy and 24x22x8.
        ;; TODO: LDIR can be optimized by a lot:
        ;;       - open the loops
        ;;       - don't bother with the last 16 bytes per line.

        ;; This does MEMSCAN and DRAWN_LINE together, since they're together.
        ld c, 22 * 2
        ld a, 0
        ld hl, MEMSCAN
        ld de, 16
    .loopMemscanC:
        ld b, 22  ; 22 characters per row.
    .loopMemscanB:
        ld (hl), a
        inc hl
        ld (hl), a
        inc hl
        ld (hl), a
        inc hl
        ld (hl), a
        inc hl
        ld (hl), a
        inc hl
        ld (hl), a
        inc hl
        ld (hl), a
        inc hl
        ld (hl), a
        inc hl

        djnz .loopMemscanB

        add hl, de
        dec c
        jp nz, .loopMemscanC

        ;ld a, 0
        ;ld (OLD_PAINTED_AREA), a
        ;ld (OLD_PAINTED_AREA + 1), a
        ;ld (PAINTED_AREA), a
        ;ld (PAINTED_AREA + 1), a
        ret


EXITING:
        ld (MEMSCAN), a
        ld bc, 24*22*8 - 1
        ld de, MEMSCAN + 1
        ld hl, MEMSCAN
        ldir

        ld a, 0
        ld (DRAWN_LINE), a
        ld bc, 24*22*8 - 1
        ld de, DRAWN_LINE + 1
        ld hl, DRAWN_LINE
        ldir

        ld (OLD_PAINTED_AREA), a
        ld (OLD_PAINTED_AREA + 1), a
        ld (PAINTED_AREA), a
        ld (PAINTED_AREA + 1), a
        ret


;; Step 2. Trace the outline in RAM.
TraceOutline:
        ld a, (MAIN_ENEMY_1 + 1)
        and %11111110 ; Make sure the X-coordinate is EVEN.
        ld (TRACER_X), a
        ld a, (MAIN_ENEMY_1)
        and %11111110 ; Make sure the Y-coordinate is EVEN.
        ld (TRACER_Y), a
        ;; Shoot a beam to the left to find a point on the edge.
        call WallToLeft
        ld a, DIR_NORTH
        ld (SCAN_DIR), a

        ;; Main loop for scanning the outline.
        ;; Look 90 degrees clockwise from the previous direction, and if it was
        ;; painted in VRAM, accept change to that direction.
        ;; Otherwise, try the next directions in counter-clockwise order from
        ;; that.
        ;; The result is that we trace the outline in clockwise direction.

        ld a, (TRACER_X)
        ld (TRACER_START), a
        ld a, (TRACER_Y)
        ld (TRACER_START + 1), a


    .scan:
        ld a, (SCAN_DIR)
        cp 0
        jp z, .scanEast  ;; The direction to scan is one clockwise from
                         ;; direction
        dec a
        jp z, .scanSouth
        dec a
        jp z, .scanWest
        jp .scanNorth

    .scanNorth:
        ;; First, scan north.
        ld a, (TRACER_Y)
        dec a
        ld (PIX_Y), a
        ld a, (TRACER_X)
        ld (PIX_X), a
        call IsPixelLit
        jp nz, .turnNorth

    .scanWest:
        ld a, (TRACER_Y)
        ld (PIX_Y), a
        ld a, (TRACER_X)
        dec a
        ld (PIX_X), a
        call IsPixelLit
        jp nz, .turnWest

    .scanSouth:
        ld a, (TRACER_Y)
        inc a
        ld (PIX_Y), a
        ld a, (TRACER_X)
        ld (PIX_X), a
        call IsPixelLit
        jp nz, .turnSouth

    .scanEast:
        ld a, (TRACER_Y)
        ld (PIX_Y), a
        ld a, (TRACER_X)
        inc a
        ld (PIX_X), a
        call IsPixelLit
        jp nz, .turnEast
        jp .scanNorth

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

        ;; Update scanning direction.
        ld (SCAN_DIR), a
        ;; Write in-memory to PIX_X, PIX_Y.
        call UpdateRAM

        ;; Then reapply diff to PIX_X, PIX_Y.

        ld a, (TRACER_X)
        ld b, a
        ld a, (PIX_X)
        sub b
        add a, a
        add a, b
        ld (PIX_X), a
        ld (TRACER_X), a

        ld a, (TRACER_Y)
        ld b, a
        ld a, (PIX_Y)
        sub b
        add a, a
        add a, b
        ld (PIX_Y), a
        ld (TRACER_Y), a

        ;; Check if the item is already lit, if yes, then quit.

        ld a, (TRACER_X)
        ld b, a
        ld a, (TRACER_START)
        cp b
        jp nz, .notYetLooped
        ld a, (TRACER_Y)
        ld b, a
        ld a, (TRACER_START + 1)
        cp b
        jp nz, .notYetLooped
        call UpdateRAM
        ret

    .notYetLooped:
        ;; Otherwise apply to in-memory copy.
        call UpdateRAM
        ;; And then continue.
        jp .scan




RepaintVRAM:

        ;; OR:
        ;; Keep track of total area, at first (22*8-1)*4 ?
        ;; Then scan the remaining area.
        ;; Recall the length of the drawn line.
        ;; Then compute the change in the remaining area.
        ;; Update to VRAM.

        ;; Housekeeping for the remaining area.
        ld hl, (PAINTED_AREA)
        ld (OLD_PAINTED_AREA), hl
        ld hl, 0
        ld (PAINTED_AREA), hl

        ld a, 255
        ld (TOPMOST_WITH_FREE), a


        ;; Scan RAM.
        ld a, 1
        ld (PIX_Y), a
        ld a, 0
        ld (PIX_X), a

    .loop_Y:
        ld a, (PIX_Y)
        cp 22*8
        jp nc, .done_Y_loop
        ld a, $ff
        ld (PAINTAND), a

        ld b, 22 ; ??

        ;; Get the masks for this row.
        ld a, (PIX_Y)
        and 7
        ld e, a
        ld d, 0
        ld hl, CURRENT_LEVEL_BACKGROUND
        add hl, de
        ld de, ODD_SHADE
        ldd  ;; Copy ODD_SHADE
        ldd  ;; Copy EVEN_SHADE

        ;; Handle bottom rows differently.
        ld a, (PIX_Y)
        cp 22*8-1
        jp nz, .dealtWithBottom
        ld a, $ff
        ld (ODD_SHADE), a



    .dealtWithBottom:
        xor a
        ld (PIX_X), a
        ld a, 1
        ld (INSIDE), a ;; We are NOT inside.

    .loop_X:
        call GetRAMByte
        ld (ODD_FOR_SHADING), a
        ld b, a
        push bc
        ;; Go a step lower
        ld hl, PIX_Y
        inc (hl)
        call GetRAMByte
        ld (EVEN_FOR_SHADING), a
        pop bc
        ld c, a

        ;; Return back to the above level.
        ;ld hl, PIX_Y
        ;dec (hl)


        ;; NOW: B = odd byte, C = even byte



        ;; Read the odd-index row byte.
        ld a, (INSIDE)
        and a
        jp z, .oddOutside

        ;; We start inside the "painted" region.
        ;; Number of new pixels painted:
        ;; Odd row:
        ;; 0001010
        ;; 0001110 paintmask
        ;; 1110001 NOT paintmask, new pixels to count
        ;; 1111011 (NOT paintmask) OR byte, what to paint

        ld hl, PAINT_MASK
        ld d, 0
        ld e, b
        add hl, de
        ld a, (hl)
        cpl
        ld (ODD_COUNT), a
        ld e, a
        or b
        ld (ODD_PAINT), a

        ;; Even row:
        ;; 0001010       Paintmask     0001110
        ;; 1101010       NOT paintmask 1110001
        ;; -------
        ;; 0010001
        ;; BITS_PAINTED[
        ;;     (NOT PAINT_MASK[
        ;;         oddByte
        ;;      ])           #
        ;;      AND NOT evenByte         # If they're still free here, paint.
        ;; ]

        ; To paint: same as above OR parillinen tavu
        or c
        ld (EVEN_PAINT), a

        ;; New: ODD_COUNT AND (NOT EVEN_BYTE)
        ld a, c
        cpl  ;; NOT EVEN_BYTE
        and e
        ld (EVEN_COUNT), a
        jp .handleBytepair

    .oddOutside:
        ;; Odd row:
        ;; 0001010
        ;; 0001110 paintmask, what to paint
        ;; 0000100 paintmask XOR byte, new pixels to count
        ;;

        ld e, b
        ld d, 0
        ld hl, PAINT_MASK
        add hl, de
        ld a, (hl) ;; Paintmask
        ld (ODD_PAINT), a
        ld e, a
        xor b
        ld (ODD_COUNT), a ;; Unnecessary?!

        ;; Even row:
        ;; 00001010
        ;; 00000100
        ;;
        ;; 11101010
        ;; =>
        ;; 11101110 to paint
        ;; 00000100 to count == odd count AND NOT evenbyte

        ld a, e
        or c
        ld (EVEN_PAINT), a
        ld a, c
        cpl
        and e
        jp .handleBytePair





    .handleBytepair:
        ;; Update (INSIDE) for the next pair of bytes
        ld hl, BITS_PAINTED
        ld e, b
        add hl, de
        ld a, (hl)
        ld hl, INSIDE
        add a, (hl) ;; Add the old parity
        and 1 ;; Modulo 2.
        ld (INSIDE), a

        ;; Write VRAM.
        ld a, (EVEN_PAINT)
        and a
        jp z, .pastEvenPaint

        ;; Apply the XOR mask.
        ld b, a
        ld a, (EVEN_SHADE)
        and b
        ld b, a
        ld a, (EVEN_FOR_SHADING)
        or b

        ld (TO_VRAM), a

        ld a, (PIX_X)

        and a
        call z, .resetFirst

        cp 21*8
        jp nz, .notLastEven
        ld a, (TO_VRAM)
        OR 1
        ld (TO_VRAM), a

    .notLastEven:
        call WriteVRAMByte

    .pastEvenPaint:
        ld hl, PIX_Y
        dec (hl)
        ld a, (ODD_PAINT)
        and a
        jp z, .pastOddPaint

        ;; Apply the XOR mask.
        ld b, a
        ld a, (ODD_SHADE)
        and b
        ld b, a
        ld a, (ODD_FOR_SHADING)
        or b

        ld (TO_VRAM), a

        ld a, (PIX_X)
        and a
        call z, .resetFirst
        cp 21*8
        jp nz, .notLastOdd
        ld a, (TO_VRAM)
        OR 1
        ld (TO_VRAM), a

    .notLastOdd:
        call WriteVRAMByte

    .pastOddPaint:
        ;;
        ld a, (ODD_PAINT)
        ld hl, BITS_PAINTED
        ld d, 0
        ld e, a
        add hl, de
        ld a, (hl)
        ld b, a ;; B has the number of bits painted on odd byte

        ld a, (EVEN_PAINT)
        ld hl, BITS_PAINTED
        ld e, a
        add hl, de
        ld a, b

        add a, (hl) ;; A should have the SUM of # of painted bits.

        ld e, a
        ld hl, (PAINTED_AREA)
        add hl, de
        ld (PAINTED_AREA), hl

        ;; Use this to track if some bit was left unpainted.
        ld a, (PAINTAND)
        ld b, a
        ld a, (ODD_PAINT)
        and b
        ld (PAINTAND), a


        ld b, 8
        ld a, (PIX_X)
        add a, b
        ld (PIX_X), a
        cp 22*8
        jp c, .loop_X


        ld a, (PAINTAND)
        cp $ff
        jp z, .nextY
        ld a, (PIX_Y)
        ld (LOWEST_WITH_FREE), a
        ld a, (TOPMOST_WITH_FREE)
        cp $ff
        jp nz, .nextY
        ld a, (PIX_Y)
        ld (TOPMOST_WITH_FREE), a



    .nextY:
        ld a, (PIX_Y)
        add a, 2
        ld (PIX_Y), a
        jp .loop_Y


    .done_Y_loop:
        ;; TODO: Finish paint ops.
        ret

    .resetFirst:
        ld a, (TO_VRAM)
        OR %10000000
        ld (TO_VRAM), a
        ret




UpdateRAM:
        ;; Byte offset: (Y / 8) * 24 * 8
        ld a, (PIX_Y)
        and %11111000
        ld h, 0
        ld l, a
        ld d, 0
        ld e, a
        add hl, hl ;; %10
        add hl, de ;; %11
        add hl, hl ;; %110
        add hl, hl ;; %1100
        add hl, hl ;; %11000
        ld a, (PIX_Y)
        and %00000111
        ;; D still holds 0.
        ld e, a
        add hl, de ;; Adds the last Y-offset.

        ld de, MEMSCAN
        add hl, de ;; Now points to the memory scan start.

        ld a, (PIX_X)
        ld b, a
        ;; PIX_X % 8 -> get bitmask
        ;; (PIX_X / 8) * 8 -> add to Y-offset
        and %11111000
        ld d, 0
        ld e, a
        add hl, de
        ld c, (hl) ;; Get the old value to C
        push hl
        ld hl, BITMASKS
        ld a, b
        and %00000111
        ld e, a
        add hl, de ;; Point to correct bit mask
        ld a, (hl)
        or c
        pop hl
        ld (hl), a
        ret


PsetLineRAM:
        ;; Byte offset: (Y / 8) * 24 * 8
        ld a, (PIX_Y)
        and %11111000
        ld h, 0
        ld l, a
        ld d, 0
        ld e, a
        add hl, hl ;; %10
        add hl, de ;; %11
        add hl, hl ;; %110
        add hl, hl ;; %1100
        add hl, hl ;; %11000
        ld a, (PIX_Y)
        and %00000111
        ;; D still holds 0.
        ld e, a
        add hl, de ;; Adds the last Y-offset.

        ld de, DRAWN_LINE
        add hl, de ;; Now points to the memory scan start.

        ld a, (PIX_X)
        ld b, a
        ;; PIX_X % 8 -> get bitmask
        ;; (PIX_X / 8) * 8 -> add to Y-offset
        and %11111000
        ld d, 0
        ld e, a
        add hl, de
        ld c, (hl) ;; Get the old value to C
        push hl
        ld hl, BITMASKS
        ld a, b
        and %00000111
        ld e, a
        add hl, de ;; Point to correct bit mask
        ld a, (hl)
        or c
        pop hl
        ld (hl), a
        ret












BLOCK_LIMIT_1: EQU 7*8
BLOCK_LIMIT_2: EQU BLOCK_LIMIT_1 + 8*8
BLOCK_LIMIT_3: EQU BLOCK_LIMIT_2 + 8*8

PsetVRAM:
        ld a, (PIX_Y)
        cp BLOCK_LIMIT_1
        jp c, .top_third
        cp BLOCK_LIMIT_2
        jp nc, .bottom_third

        ld hl, VRAM_PATTERN_2 ;; VRAM address for mid-8

        sub 56 ;;
        jp .y_done

    .top_third:
        ld hl, VRAM_PATTERN_1 ;; VRAM address for top-8
        jp .y_done

    .bottom_third:
        ld hl, VRAM_PATTERN_3 ;; VRAM address for bottom-8
        sub 120
        ; jp .y_done

    .y_done:
        ;; Now, A has the "Y offset" within the block
        ld b, a
        push hl

        ; 22 * 8 * floor(y/8)
        ; = 22 * (y and %11111000)
        and %11111000
        ld h, 0
        ld l, a
        ld d, 0
        ld e, a

        add hl, hl ; 10
        add hl, hl ; 100
        add hl, de ; 101
        add hl, hl ; 1010
        add hl, de ; 1011
        add hl, hl ; 10110
        ld a, b
        and %00000111
        ld e, a

        add hl, de

        ex de, hl
        pop hl

        ;; Get back to HL the block offset
        add hl, de ;; HL now has the block offset + Y offset.


        ;; Next, calculate the X offset. Just reset last three bits.
        ld a, (PIX_X)
        ld c, a
        and %11111000
        ;; X is max 23*8 = 184, and Y offset is max 64 => max value is 248.
        ld d, 0
        ld e, a
        add hl, de ;; Now HL will have the correct VRAM address to load.
        push hl
        call RDVRM
        ld b, a
        ld a, c
        and %00000111
        ld hl, BITMASKS
        ld d, 0
        ld e, a
        add hl, de
        ld a, (hl)
        or b
        pop hl
        call WRTVRM
        ret



IsPixelLit_BB:
        ;; Check also the bounding box.
        ld a, (PIX_Y)
        cp 22*8 - 1
        jp nc, .invalid
        ld a, (PIX_X)
        cp 22*8 - 1
        jp nc, .invalid
        jp IsPixelLit
    .invalid:
        and 0 ;; Just to set Z-bit off
        ret


IsPixelLit_BBTrue:
        ;; Check also the bounding box.
        ld a, (PIX_Y)
        cp 22*8 - 1
        jp nc, .invalid
        ld a, (PIX_X)
        cp 22*8 - 1
        jp nc, .invalid
        jp IsPixelLit
    .invalid:
        and a ;; Sets Z bit on.
        ret

IsPixelLit:
        ld a, (PIX_Y)
        cp BLOCK_LIMIT_1
        jp c, .top_third
        cp BLOCK_LIMIT_2
        jp nc, .bottom_third

        ld hl, VRAM_PATTERN_2 ;; VRAM address for mid-8

        sub 56 ;;
        jp .y_done

    .top_third:
        ld hl, VRAM_PATTERN_1 ;; VRAM address for top-8
        jp .y_done

    .bottom_third:
        ld hl, VRAM_PATTERN_3 ;; VRAM address for bottom-8
        sub 120
        ; jp .y_done

    .y_done:
        ;; Now, A has the "Y offset" within the block
        ld b, a
        push hl

        ; 22 * 8 * floor(y/8)
        ; = 22 * (y and %11111000)
        and %11111000
        ld h, 0
        ld l, a
        ld d, 0
        ld e, a

        add hl, hl ; 10
        add hl, hl ; 100
        add hl, de ; 101
        add hl, hl ; 1010
        add hl, de ; 1011
        add hl, hl ; 10110
        ld a, b
        and %00000111
        ld e, a

        add hl, de

        ex de, hl
        pop hl

        ;; Get back to HL the block offset
        add hl, de ;; HL now has the block offset + Y offset.


        ;; Next, calculate the X offset. Just reset last three bits.
        ld a, (PIX_X)
        ld c, a
        and %11111000
        ;; X is max 23*8 = 184, and Y offset is max 64 => max value is 248.
        ld d, 0
        ld e, a
        add hl, de ;; Now HL will have the correct VRAM address to load.

        call RDVRM
        ld b, a
        ld a, c
        and %00000111
        ld hl, BITMASKS
        ld d, 0
        ld e, a
        add hl, de
        ld a, (hl)

        and b
        ;; Now, if Z-flag is on, then the bit was not set.
        ret



IsPixelLitRAM_BB:
        ;; Check also the bounding box.
        ld a, (PIX_Y)
        cp 22*8 - 1
        jp nc, .invalid
        ld a, (PIX_X)
        cp 22*8 - 1
        jp nc, .invalid
        jp IsPixelLitRAM
    .invalid:
        and 0 ;; Just to set Z-bit off
        ret

IsPixelLitRAM:
        ;; Byte offset: (Y / 8) * 24 * 8
        ld a, (PIX_Y)
        and %11111000
        ld h, 0
        ld l, a
        ld d, 0
        ld e, a
        add hl, hl ;; %10
        add hl, de ;; %11
        add hl, hl ;; %110
        add hl, hl ;; %1100
        add hl, hl ;; %11000

        ld de, MEMSCAN
        add hl, de ;; Now points to the memory scan start.
        ld d, 0
        ld a, (PIX_Y)
        and %00000111
        ld e, a
        add hl, de
        ;; HL now has the Y offset.


        ld a, (PIX_X)
        ld c, a
        and %11111000
        ld d, 0
        ld e, a
        add hl, de ;; Add full-char X-offset
        ld b, (hl)
        ld a, c
        and %00000111
        ld hl, BITMASKS
        ld d, 0
        ld e, a
        add hl, de
        ld a, (hl)

        and b
        ;; Now, if Z-flag is on, then the bit was not set.
        ret

GetRAMByte:

        ;; Byte offset: (Y / 8) * 24 * 8
        ld a, (PIX_Y)
        and %11111000
        ld h, 0
        ld l, a
        ld d, 0
        ld e, a
        add hl, hl ;; %10
        add hl, de ;; %11
        add hl, hl ;; %110
        add hl, hl ;; %1100
        add hl, hl ;; %11000

        ld de, MEMSCAN
        add hl, de ;; Now points to the memory scan start.
        ld d, 0
        ld a, (PIX_Y)
        and %00000111
        ld e, a
        add hl, de
        ;; HL now has the Y offset.


        ld a, (PIX_X)
        ld c, a
        and %11111000
        ld d, 0
        ld e, a
        add hl, de ;; Add full-char X-offset
        ld a, (hl)
        ret

GetLineByte:

        ;; Byte offset: (Y / 8) * 24 * 8
        ld a, (PIX_Y)
        and %11111000
        ld h, 0
        ld l, a
        ld d, 0
        ld e, a
        add hl, hl ;; %10
        add hl, de ;; %11
        add hl, hl ;; %110
        add hl, hl ;; %1100
        add hl, hl ;; %11000

        ld de, DRAWN_LINE
        add hl, de ;; Now points to the memory scan start.
        ld d, 0
        ld a, (PIX_Y)
        and %00000111
        ld e, a
        add hl, de
        ;; HL now has the Y offset.


        ld a, (PIX_X)
        ld c, a
        and %11111000
        ld d, 0
        ld e, a
        add hl, de ;; Add full-char X-offset
        ld a, (hl)
        ret

GetVRAMByte:
        ld a, (PIX_Y)
        cp BLOCK_LIMIT_1
        jp c, .top_third
        cp BLOCK_LIMIT_2
        jp nc, .bottom_third

        ld hl, VRAM_PATTERN_2 ;; VRAM address for mid-8

        sub 56 ;;
        jp .y_done

    .top_third:
        ld hl, VRAM_PATTERN_1 ;; VRAM address for top-8
        jp .y_done

    .bottom_third:
        ld hl, VRAM_PATTERN_3 ;; VRAM address for bottom-8
        sub 120
        ; jp .y_done

    .y_done:
        ;; Now, A has the "Y offset" within the block
        ld b, a
        push hl

        ; 22 * 8 * floor(y/8)
        ; = 22 * (y and %11111000)
        and %11111000
        ld h, 0
        ld l, a
        ld d, 0
        ld e, a

        add hl, hl ; 10
        add hl, hl ; 100
        add hl, de ; 101
        add hl, hl ; 1010
        add hl, de ; 1011
        add hl, hl ; 10110
        ld a, b
        and %00000111
        ld e, a

        add hl, de

        ex de, hl
        pop hl

        ;; Get back to HL the block offset
        add hl, de ;; HL now has the block offset + Y offset.


        ;; Next, calculate the X offset. Just reset last three bits.
        ld a, (PIX_X)
        ld c, a
        and %11111000
        ;; X is max 23*8 = 184, and Y offset is max 64 => max value is 248.
        ld d, 0
        ld e, a
        add hl, de ;; Now HL will have the correct VRAM address to load.
        call RDVRM
        ret

WriteVRAMByte:
        ld a, (PIX_Y)
        cp BLOCK_LIMIT_1
        jp c, .top_third
        cp BLOCK_LIMIT_2
        jp nc, .bottom_third

        ld hl, VRAM_PATTERN_2 ;; VRAM address for mid-8

        sub 56 ;;
        jp .y_done

    .top_third:
        ld hl, VRAM_PATTERN_1 ;; VRAM address for top-8
        jp .y_done

    .bottom_third:
        ld hl, VRAM_PATTERN_3 ;; VRAM address for bottom-8
        sub 120
        ; jp .y_done

    .y_done:
        ;; Now, A has the "Y offset" within the block
        ld b, a
        push hl

        ; 22 * 8 * floor(y/8)
        ; = 22 * (y and %11111000)
        and %11111000
        ld h, 0
        ld l, a
        ld d, 0
        ld e, a

        add hl, hl ; 10
        add hl, hl ; 100
        add hl, de ; 101
        add hl, hl ; 1010
        add hl, de ; 1011
        add hl, hl ; 10110
        ld a, b
        and %00000111
        ld e, a

        add hl, de

        ex de, hl
        pop hl

        ;; Get back to HL the block offset
        add hl, de ;; HL now has the block offset + Y offset.


        ;; Next, calculate the X offset. Just reset last three bits.
        ld a, (PIX_X)
        ld c, a
        and %11111000
        ;; X is max 23*8 = 184, and Y offset is max 64 => max value is 248.
        ld d, 0
        ld e, a
        add hl, de ;; Now HL will have the correct VRAM address to load.
        ld a, (TO_VRAM)
        call WRTVRM
        ret


BITMASKS: DB 128, 64, 32, 16, 8, 4, 2, 1

; Number of bits lit.
BITS_PAINTED:
DB  0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4, 1, 2, 2, 3, 2, 3, 3, 4, 2
DB  3, 3, 4, 3, 4, 4, 5, 1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5, 2, 3
DB  3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6, 1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3
DB  4, 3, 4, 4, 5, 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6, 2, 3, 3, 4
DB  3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6, 3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5
DB  6, 6, 7, 1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5, 2, 3, 3, 4, 3, 4
DB  4, 5, 3, 4, 4, 5, 4, 5, 5, 6, 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5
DB  6, 3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7, 2, 3, 3, 4, 3, 4, 4, 5
DB  3, 4, 4, 5, 4, 5, 5, 6, 3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7, 3
DB  4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7, 4, 5, 5, 6, 5, 6, 6, 7, 5, 6
DB  6, 7, 6, 7, 7, 8
; Paint mask. If we go INSIDE being 0, these tell which pixels are
; painted.
PAINT_MASK:
DB  0, 1, 3, 3, 7, 7, 6, 7, 15, 15, 14, 15, 12, 13, 15, 15, 31, 31, 30, 31, 28, 29, 31, 31, 24
DB  25, 27, 27, 31, 31, 30, 31, 63, 63, 62, 63, 60, 61, 63, 63, 56, 57, 59, 59, 63, 63, 62, 63, 48, 49
DB  51, 51, 55, 55, 54, 55, 63, 63, 62, 63, 60, 61, 63, 63, 127, 127, 126, 127, 124, 125, 127, 127, 120, 121, 123
DB  123, 127, 127, 126, 127, 112, 113, 115, 115, 119, 119, 118, 119, 127, 127, 126, 127, 124, 125, 127, 127, 96, 97, 99, 99
DB  103, 103, 102, 103, 111, 111, 110, 111, 108, 109, 111, 111, 127, 127, 126, 127, 124, 125, 127, 127, 120, 121, 123, 123, 127
DB  127, 126, 127, 255, 255, 254, 255, 252, 253, 255, 255, 248, 249, 251, 251, 255, 255, 254, 255, 240, 241, 243, 243, 247, 247
DB  246, 247, 255, 255, 254, 255, 252, 253, 255, 255, 224, 225, 227, 227, 231, 231, 230, 231, 239, 239, 238, 239, 236, 237, 239
DB  239, 255, 255, 254, 255, 252, 253, 255, 255, 248, 249, 251, 251, 255, 255, 254, 255, 192, 193, 195, 195, 199, 199, 198, 199
DB  207, 207, 206, 207, 204, 205, 207, 207, 223, 223, 222, 223, 220, 221, 223, 223, 216, 217, 219, 219, 223, 223, 222, 223, 255
DB  255, 254, 255, 252, 253, 255, 255, 248, 249, 251, 251, 255, 255, 254, 255, 240, 241, 243, 243, 247, 247, 246, 247, 255, 255
DB  254, 255, 252, 253, 255, 255

;; 16-bit thresholds to compare against for level clearing.
PAINT_THRESHOLDS:
    DW %00000000000 ; 0%
    DW %10101000010 ; 1%
    DW %11001101101 ; 2%
    DW %11110011000 ; 3%
    DW %100011000100 ; 4%
    DW %100111101111 ; 5%
    DW %101100011010 ; 6%
    DW %110001000110 ; 7%
    DW %110101110001 ; 8%
    DW %111010011100 ; 9%
    DW %111111000111 ; 10%
    DW %1000011110011 ; 11%
    DW %1001000011110 ; 12%
    DW %1001101001001 ; 13%
    DW %1010001110101 ; 14%
    DW %1010110100000 ; 15%
    DW %1011011001011 ; 16%
    DW %1011111110110 ; 17%
    DW %1100100100010 ; 18%
    DW %1101001001101 ; 19%
    DW %1101101111000 ; 20%
    DW %1110010100100 ; 21%
    DW %1110111001111 ; 22%
    DW %1111011111010 ; 23%
    DW %10000000100101 ; 24%
    DW %10000101010001 ; 25%
    DW %10001001111100 ; 26%
    DW %10001110100111 ; 27%
    DW %10010011010011 ; 28%
    DW %10010111111110 ; 29%
    DW %10011100101001 ; 30%
    DW %10100001010100 ; 31%
    DW %10100110000000 ; 32%
    DW %10101010101011 ; 33%
    DW %10101111010110 ; 34%
    DW %10110100000010 ; 35%
    DW %10111000101101 ; 36%
    DW %10111101011000 ; 37%
    DW %11000010000100 ; 38%
    DW %11000110101111 ; 39%
    DW %11001011011010 ; 40%
    DW %11010000000101 ; 41%
    DW %11010100110001 ; 42%
    DW %11011001011100 ; 43%
    DW %11011110000111 ; 44%
    DW %11100010110011 ; 45%
    DW %11100111011110 ; 46%
    DW %11101100001001 ; 47%
    DW %11110000110100 ; 48%
    DW %11110101100000 ; 49%
    DW %11111010001011 ; 50%
    DW %11111110110110 ; 51%
    DW %100000011100010 ; 52%
    DW %100001000001101 ; 53%
    DW %100001100111000 ; 54%
    DW %100010001100011 ; 55%
    DW %100010110001111 ; 56%
    DW %100011010111010 ; 57%
    DW %100011111100101 ; 58%
    DW %100100100010001 ; 59%
    DW %100101000111100 ; 60%
    DW %100101101100111 ; 61%
    DW %100110010010010 ; 62%
    DW %100110110111110 ; 63%
    DW %100111011101001 ; 64%
    DW %101000000010100 ; 65%
    DW %101000101000000 ; 66%
    DW %101001001101011 ; 67%
    DW %101001110010110 ; 68%
    DW %101010011000010 ; 69%
    DW %101010111101101 ; 70%
    DW %101011100011000 ; 71%
    DW %101100001000011 ; 72%
    DW %101100101101111 ; 73%
    DW %101101010011010 ; 74%
    DW %101101111000101 ; 75%
    DW %101110011110001 ; 76%
    DW %101111000011100 ; 77%
    DW %101111101000111 ; 78%
    DW %110000001110010 ; 79%
    DW %110000110011110 ; 80%
    DW %110001011001001 ; 81%
    DW %110001111110100 ; 82%
    DW %110010100100000 ; 83%
    DW %110011001001011 ; 84%
    DW %110011101110110 ; 85%
    DW %110100010100001 ; 86%
    DW %110100111001101 ; 87%
    DW %110101011111000 ; 88%
    DW %110110000100011 ; 89%
    DW %110110101001111 ; 90%
    DW %110111001111010 ; 91%
    DW %110111110100101 ; 92%
    DW %111000011010000 ; 93%
    DW %111000111111100 ; 94%
    DW %111001100100111 ; 95%
    DW %111010001010010 ; 96%
    DW %111010101111110 ; 97%
    DW %111011010101001 ; 98%
    DW %111011111010100 ; 99%
    DW %111100100000000 ; 100%



LEVEL_BACKGROUNDS:

DB %01010101
DB %10101010
DB %01010101
DB %10101010
DB %01010101
DB %10101010
DB %01010101
DB %10101010

DB %01010101
DB %11101110
DB %01010101
DB %10111011
DB %01010101
DB %11101110
DB %01010101
DB %10111010

DB %11010101
DB %11101010
DB %01110101
DB %10111010
DB %01011101
DB %10101110
DB %01010111
DB %10101011


DB %01010101
DB %11101010
DB %01010101
DB %11111010
DB %01011101
DB %10101010
DB %11011111
DB %11101010

DB %01110111
DB %11101110
DB %01011101
DB %10111011
DB %01110111
DB %11101110
DB %11011101
DB %10111010

DB %01010111
DB %10101110
DB %01011101
DB %10111010
DB %01110101
DB %11101010
DB %11010101
DB %10101010

DB %01010101
DB %10101010
DB %01010101
DB %10101010
DB %01010101
DB %10101010
DB %01010101
DB %10101010

DB %01010101
DB %10101010
DB %01010101
DB %10101010
DB %01010101
DB %10101010
DB %01010101
DB %10101010



DB %01110111
DB %10111011
DB %11011101
DB %10111011
DB %11011101
DB %10111011
DB %11011101
DB %11101110

DB %11111111
DB %11111111
DB %11111111
DB %11111111
DB %11111111
DB %11111111
DB %11111111
DB %11111111

DB %10110000
DB %01011000
DB %00101100
DB %00010110
DB %00001011
DB %10000101
DB %11000010
DB %01100001

DB %11011011
DB %11011100
DB %00101111
DB %11000111
DB %11110000
DB %00111011
DB %11011011
DB %11011011

DB %11110000
DB %10010110
DB %10010110
DB %11110000
DB %00001111
DB %01101001
DB %01101001
DB %00001111

DB %11001000
DB %01110100
DB %00101110
DB %00010011
DB %11001000
DB %01110100
DB %00101110
DB %00010011

DB %11111101
DB %11011111
DB %11011111
DB %00000111
DB %11011101
DB %11011101
DB %01110000
DB %11111101


DB %00000000
DB %00000000
DB %00000000
DB %00000000
DB %00000000
DB %00000000
DB %00000000
DB %00000000

