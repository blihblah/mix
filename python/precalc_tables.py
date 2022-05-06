import random

"""
Precalculation routines for MIX.

"""


def as_dbs(val_list):
    rows = []
    row = []
    for v in val_list:
        row.append(v)
        if len(row) == 25:
            rows.append(row)
            row = []
    if len(row):
        rows.append(row)
    for r in rows:
        print("DB ", ', '.join(r))

def as_dws(val_list):
    rows = []
    row = []
    for v in val_list:
        row.append(v)
        if len(row) == 25:
            rows.append(row)
            row = []
    if len(row):
        rows.append(row)
    for r in rows:
        print("DW ", ', '.join(r))

def precalc():
    # Bitmasks
    bits = [2**i for i in range(0, 8)]
    bits.reverse()

    vals = []
    paintmask = []
    for k in range(256):
        c = len([i for i in bits if i & k != 0])
        vals.append(f'{c}')

        ins = False
        incl = 0
        for i in bits:
            if i & k != 0:
                ins = not ins
                incl += i

            elif ins:
                incl += i
        paintmask.append(str(incl))

    print("; Number of bits lit.")
    print("BITS_PAINTED: ")
    as_dbs(vals)

    print("; Paint mask. If we go INSIDE being 0, these tell which pixels are")
    print("; painted.")
    print("PAINT_MASK:")
    as_dbs(paintmask)


    # Now, percentage-based thresholds.
    # We look ONLY at
    # THESE START FROM 50.
    thresholds = []

    minimum = int("0417", 16) # This is the edges always painted

    base = 30976 - minimum
    for i in range(0, 101):
        lim = minimum + int(base * (i / 100))

        val = "%" + bin(lim)[2:]
        thresholds.append((i, val))
    print(";; 16-bit thresholds to compare against for level clearing.")
    print("PAINT_THRESHOLDS:")
    thresholds[0] = "%0"
    for i, val in thresholds:
        print(f"    DW {val} ; {i}%")


if __name__ == "__main__":
    precalc()


