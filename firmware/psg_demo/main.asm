; PSG demo program executed from Block RAM at 2000h.

PSG_ADDR: equ 0A0h
PSG_DATA: equ 0A1h
LED_PORT: equ 0B0h

        org 02000h

start:
        ; Stage 3: execution reached the RAM application.
        ld a, 008h
        out (LED_PORT), a

        ; Enable tone A/B/C and disable noise A/B/C.
        ld a, 7
        out (PSG_ADDR), a
        ld a, 038h
        out (PSG_DATA), a

        ; Tone A: period 0193h, approximately C4.
        ld a, 0
        out (PSG_ADDR), a
        ld a, 093h
        out (PSG_DATA), a
        ld a, 1
        out (PSG_ADDR), a
        ld a, 1
        out (PSG_DATA), a

        ; Tone B: period 0140h, approximately E4.
        ld a, 2
        out (PSG_ADDR), a
        ld a, 040h
        out (PSG_DATA), a
        ld a, 3
        out (PSG_ADDR), a
        ld a, 1
        out (PSG_DATA), a

        ; Tone C: period 010Dh, approximately G4.
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

        ; Stage 4: all PSG registers were initialized.
        ld a, 004h
        out (LED_PORT), a

        ; Keep register 8 selected and toggle channel A volume.
        ld a, 8
        out (PSG_ADDR), a
        ld d, 15
        ld e, 2
volume_loop:
        ld a, d
        out (PSG_DATA), a
        ; Stage 5: alternate LED1/LED0 in the continuous RAM loop.
        ld a, e
        out (LED_PORT), a
        xor 3
        ld e, a
        ld a, d
        xor 7
        ld d, a
        ; About 0.25 seconds at 3.375 MHz; no stack access is needed.
        ld bc, 08000h
delay_loop:
        dec bc
        ld a, b
        or c
        jr nz, delay_loop
        jr volume_loop
