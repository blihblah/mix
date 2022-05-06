WaitForBlank:
	;; Wait for the next VDP blank. Probably could be done
	;; smarter.
	push bc
  .syncLoop:
	ld a, (LATEST_MAIN_STEP)
	ld b, a
  .waitForVDPSync:
	ld a, (LATEST_VDP_INTERRUPT)
	cp b
	jp z, .waitForVDPSync ;; Loop until vblank
	ld (LATEST_MAIN_STEP), a
	pop bc
	ret


StartInterrupts:
	ld hl, VideoInterruptHandler
	ld a, $c3
	di
	ld (HKEY), a
	ld (HKEY + 1), hl
	ei
	ret

VideoInterruptHandler:
	;;
	ld b, a
	ld a, (LATEST_VDP_INTERRUPT)
	inc a
	ld (LATEST_VDP_INTERRUPT), a
	ld a, b
	ret

DetectRefreshSpeed:
	ld a, 1
	ld (IS_PAL), a
	call CheckIf60Hz
	cp 1
	ret nz
	ld a, 0
	ld (IS_PAL), a
	ret

;;
;; returns 1 in a and clears z flag if vdp is 60Hz
;;
CheckIf60Hz:
    di
    in a,($99)
    nop
    nop
    nop
  .vdpSync:
    in a,($99)
    and 0x80
    jr z, .vdpSync
    ld      hl,$900
  .vdpLoop:
    dec hl
    ld a,h
    or l
    jr nz, .vdpLoop

    in a,($99)
    rlca
    and 1
    ei
    ret