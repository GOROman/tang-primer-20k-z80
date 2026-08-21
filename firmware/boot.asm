; Tang Primer 20K Z80 + PSG boot ROM
; Assemble at 0000h. The checked-in boot.hex contains these bytes.

PSG_ADDR equ 0A0h
PSG_DATA equ 0A1h
LED_PORT equ 0B0h

        org 0000h
        di
        ld sp, 0FFFFh

        ld hl, 02000h
        ld (hl), 055h
        ld a, (hl)
        cp 055h
        jr nz, ram_fail

        ld a, 1
        out (LED_PORT), a

        ; Enable tone A/B/C and disable noise A/B/C.
        ld a, 7
        out (PSG_ADDR), a
        ld a, 038h
        out (PSG_DATA), a

        ; Tone A: period 0193h
        ld a, 0
        out (PSG_ADDR), a
        ld a, 093h
        out (PSG_DATA), a
        ld a, 1
        out (PSG_ADDR), a
        ld a, 1
        out (PSG_DATA), a

        ; Tone B: period 0140h
        ld a, 2
        out (PSG_ADDR), a
        ld a, 040h
        out (PSG_DATA), a
        ld a, 3
        out (PSG_ADDR), a
        ld a, 1
        out (PSG_DATA), a

        ; Tone C: period 010Dh
        ld a, 4
        out (PSG_ADDR), a
        ld a, 00Dh
        out (PSG_DATA), a
        ld a, 5
        out (PSG_ADDR), a
        ld a, 1
        out (PSG_DATA), a

        ; Set channel volumes.
        ld a, 8
        out (PSG_ADDR), a
        ld a, 15
        out (PSG_DATA), a
        ld a, 9
        out (PSG_ADDR), a
        ld a, 12
        out (PSG_DATA), a
        ld a, 10
        out (PSG_ADDR), a
        ld a, 12
        out (PSG_DATA), a

        ; Keep register 8 selected and toggle channel A volume.
        ld a, 8
        out (PSG_ADDR), a
        ld a, 15
volume_loop:
        out (PSG_DATA), a
        xor 7
        push af
        ld bc, 0
delay_loop:
        dec bc
        ld a, b
        or c
        jr nz, delay_loop
        pop af
        jr volume_loop

ram_fail:
        xor a
        out (LED_PORT), a
        ld a, 8
        out (PSG_ADDR), a
        xor a
        out (PSG_DATA), a
        jr ram_fail
