; Tang Primer 20K Z80 boot ROM
; Assembled at 0000h. Tests RAM away from the application, then jumps to it.

LED_PORT: equ 0B0h
APP_ENTRY: equ 02000h
RAM_TEST_ADDR: equ 0FF00h

        org 0000h
        di
        ld sp, 0FFFFh

        ; Stage 1: Z80 started from boot ROM.
        ld a, 020h
        out (LED_PORT), a

        ld hl, RAM_TEST_ADDR
        ld (hl), 055h
        ld a, (hl)
        cp 055h
        jr nz, ram_fail

        ld (hl), 0AAh
        ld a, (hl)
        cp 0AAh
        jr nz, ram_fail

        ; Stage 2: RAM read/write test passed.
        ld a, 010h
        out (LED_PORT), a

        jp APP_ENTRY

ram_fail:
        ; LED0 remains lit on RAM failure.
        ld a, 001h
        out (LED_PORT), a
        jr ram_fail
