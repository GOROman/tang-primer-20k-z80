; Tang Primer 20K Z80 boot ROM
; Assembled at 0000h. Tests RAM away from the application, then jumps to it.

LED_PORT: equ 0B0h
APP_ENTRY: equ 02000h
RAM_TEST_ADDR: equ 0FF00h

        org 0000h
        di
        ld sp, 0FFFFh

        ld hl, RAM_TEST_ADDR
        ld (hl), 055h
        ld a, (hl)
        cp 055h
        jr nz, ram_fail

        ld (hl), 0AAh
        ld a, (hl)
        cp 0AAh
        jr nz, ram_fail

        jp APP_ENTRY

ram_fail:
        xor a
        out (LED_PORT), a
        jr ram_fail
