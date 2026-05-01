    .section .text
    .globl _start

_start:
    lui  x1, 0x4          # base = 0x4000

    addi x2, x0, 1
    addi x3, x0, 2
    addi x4, x0, 3
    addi x5, x0, 4
    addi x6, x0, 0        # accumulator

# -----------------------------
# STRESS BLOCK 1: RAW hazard chain
# -----------------------------
    sw   x2, 0(x1)
    lw   x7, 0(x1)
    add  x6, x6, x7

    sw   x3, 0(x1)
    lw   x7, 0(x1)
    add  x6, x6, x7

    sw   x4, 0(x1)
    lw   x7, 0(x1)
    add  x6, x6, x7

# -----------------------------
# STRESS BLOCK 2: interleaved overwrite hazard
# -----------------------------
    sw   x2, 0(x1)
    sw   x3, 0(x1)
    lw   x7, 0(x1)        # must get x3 (not x2)
    add  x6, x6, x7

# -----------------------------
# STRESS BLOCK 3: address aliasing
# -----------------------------
    addi x8, x1, 4

    sw   x4, 0(x1)
    sw   x5, 0(x8)

    lw   x9, 0(x1)
    lw   x10, 0(x8)

    add  x6, x6, x9
    add  x6, x6, x10

# -----------------------------
# STRESS BLOCK 4: load-use + store-use mix
# -----------------------------
    sw   x6, 0(x1)
    lw   x11, 0(x1)
    addi x11, x11, 1
    sw   x11, 0(x1)
    lw   x12, 0(x1)

    add  x6, x6, x12

# -----------------------------
# STRESS BLOCK 5: tight dependency loop
# -----------------------------
    addi x13, x0, 0
    addi x14, x0, 5

loop:
    sw   x14, 0(x1)
    lw   x15, 0(x1)
    add  x13, x13, x15

    addi x14, x14, 1
    addi x5, x5, -1
    bne  x5, x0, loop

# -----------------------------
# FINAL CHECKSUM
# -----------------------------
    add  x9, x6, x13      # output register (your CPU shows x9)

hang:
    jal x0, hang
