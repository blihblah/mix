import gfxconvert

def convert_sprite(infname, outfname):

    #defchars, output = gfxconvert.create_charset(infname, orientation="vertical", redundancy=True)

    output = gfxconvert.create_sprites(infname, orientation="horizontal")

    colour = (15 << 4) + 12
    patterns = []
    for p in output:
        patterns.append(gfxconvert.to_byte(p, 15))

    print("Sprite output length", len(patterns))


    with open(outfname, 'wb') as f:
        barr = bytes(patterns)
        f.write(barr)


def convert_no_compression(infname, outfname_base):
    patterns, colours = gfxconvert.convert_no_compression(infname)

    outname_pts = outfname_base + "_rle_pattern.bin"
    outname_clr = outfname_base + "_rle_colour.bin"

    with open(outname_clr, 'wb') as f:
        barr = bytes(gfxconvert.rle_encode_sequence(colours))
        f.write(barr)
        print("Colour length", len(barr))

    with open(outname_pts, 'wb') as f:
        barr = bytes(gfxconvert.rle_encode_sequence(patterns))
        f.write(barr)
        print("Pattern length", len(barr))


def convert_extrachars(infname, outfname_base):
    defchars, output = gfxconvert.create_charset(infname, orientation="horizontal", redundancy=False)
    ccoding, patterns = gfxconvert.rle_encode_graphics(defchars)

    outname = outfname_base + ".bin"

    base_offset = 176
    unpacked_scr = []
    for y in range(8):
        for x in range(8):
            unpacked_scr.append(output[(x, y)] + base_offset)
        print(unpacked_scr[-8:])


    with open(outname, 'wb') as f:
        barr = bytes(patterns)
        f.write(barr)
        print("Pattern length", len(patterns))

    outname = outfname_base + "_colours.bin"
    with open(outname, 'wb') as f:
        barr = bytes(ccoding)
        f.write(barr)

    print("Distinct patterns", len(patterns))


def convert_fullscreen(infname, outfname_base):
    by_segment = gfxconvert.create_fullscreen(infname)
    total_screen = []
    #print("STARTING TO PRODUCE TITLE SCREEN:", infname)
    for area, val_d in sorted(by_segment.items()):
        defchars = val_d['chars']
        output = val_d['charmap']
        ccoding, patterns = gfxconvert.rle_encode_graphics(defchars)

        unpacked_scr = []
        for y in range(8):
            for x in range(32):
                unpacked_scr.append(output[(x, y)])
        total_screen.extend(unpacked_scr)

        outname = outfname_base + "_{}.bin".format(area)

        with open(outname, 'wb') as f:
            barr = bytes(patterns)
            f.write(barr)

        outname = outfname_base + "_{}_colours.bin".format(area)
        with open(outname, 'wb') as f:
            barr = bytes(ccoding)
            f.write(barr)

    outname = outfname_base + "_chars.bin".format(area)
    with open(outname, 'wb') as f:
        barr = bytes(total_screen)
        f.write(barr)

if __name__ == "__main__":
    convert_sprite("../resources/mix_sprites.png", "../src/incbin/sprites.bin")
    convert_extrachars("../resources/mix_sidepanel_top.png", "../src/incbin/extra_gameplaychars_1")
    convert_extrachars("../resources/mix_sidepanel_mid.png", "../src/incbin/extra_gameplaychars_2")
    convert_extrachars("../resources/mix_sidepanel_btm.png", "../src/incbin/extra_gameplaychars_3")

    convert_no_compression("../resources/mix_title_top.png", "../src/incbin/title_top")
    convert_no_compression("../resources/mix_title_mid.png",
                           "../src/incbin/title_mid")
    convert_no_compression("../resources/mix_title_btm.png",
                           "../src/incbin/title_btm")

    convert_no_compression("../resources/mix_gameover_top.png", "../src/incbin/gameover_top")
    convert_no_compression("../resources/mix_gameover_mid.png",
                           "../src/incbin/gameover_mid")
    convert_no_compression("../resources/mix_gameover_btm.png",
                           "../src/incbin/gameover_btm")


