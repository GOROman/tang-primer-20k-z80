; PSG demo program executed from Block RAM at 2000h.
; Plays C - Am - F - G with a four-beat noise rhythm.

PSG_ADDR: equ 0A0h
PSG_DATA: equ 0A1h
LED_PORT: equ 0B0h

        org 02000h

start:
        ; Stage 3: execution reached the RAM application.
        ld a, 008h
        out (LED_PORT), a

        ; Enable Tone A/B/C and disable Noise A/B/C between drum hits.
        ld a, 7
        out (PSG_ADDR), a
        ld a, 038h
        out (PSG_DATA), a

        ; Base chord volumes. Channel A also carries each noise hit.
        ld a, 8
        out (PSG_ADDR), a
        ld a, 10
        out (PSG_DATA), a
        ld a, 9
        out (PSG_ADDR), a
        ld a, 9
        out (PSG_DATA), a
        ld a, 10
        out (PSG_ADDR), a
        ld a, 9
        out (PSG_DATA), a

        ; Stage 4: PSG initialization completed.
        ld a, 004h
        out (LED_PORT), a
        ld e, 2

progression_loop:
        ld hl, chord_c
        call set_chord
        call play_bar

        ld hl, chord_am
        call set_chord
        call play_bar

        ld hl, chord_f
        call set_chord
        call play_bar

        ld hl, chord_g
        call set_chord
        call play_bar
        jr progression_loop

; Write six bytes from HL to PSG tone-period registers 0 through 5.
set_chord:
        ld b, 0
set_chord_loop:
        ld a, b
        out (PSG_ADDR), a
        ld a, (hl)
        out (PSG_DATA), a
        inc hl
        inc b
        ld a, b
        cp 6
        jr nz, set_chord_loop
        ret

; Four noise hits per chord. Beat 1 is brighter and louder.
play_bar:
        call noise_accent
        call noise_tick
        call noise_tick
        call noise_tick
        ret

noise_accent:
        ld a, 5
        call noise_hit
        ret

noise_tick:
        ld a, 12
        call noise_hit
        ret

; A = noise period. Temporarily mix noise into Channel A, then restore tone.
noise_hit:
        push af
        ld a, 6
        out (PSG_ADDR), a
        pop af
        out (PSG_DATA), a

        ; 30h enables noise only on A while leaving all three tones enabled.
        ld a, 7
        out (PSG_ADDR), a
        ld a, 030h
        out (PSG_DATA), a

        ld a, 8
        out (PSG_ADDR), a
        ld a, 13
        out (PSG_DATA), a

        ; Stage 5: alternate LED1/LED0 on every rhythm beat.
        ld a, e
        out (LED_PORT), a
        xor 3
        ld e, a
        call delay_hit

        ; Disable noise again and return Channel A to its chord volume.
        ld a, 7
        out (PSG_ADDR), a
        ld a, 038h
        out (PSG_DATA), a
        ld a, 8
        out (PSG_ADDR), a
        ld a, 10
        out (PSG_DATA), a
        call delay_beat
        ret

delay_hit:
        ld bc, 0800h
delay_hit_loop:
        dec bc
        ld a, b
        or c
        jr nz, delay_hit_loop
        ret

delay_beat:
        ld bc, 07000h
delay_beat_loop:
        dec bc
        ld a, b
        or c
        jr nz, delay_beat_loop
        ret

; Tone periods at a 1.6875 MHz PSG clock: C - Am - F - G.
chord_c:
        db 093h, 01h, 040h, 01h, 00Dh, 01h ; C4 E4 G4
chord_am:
        db 0DFh, 01h, 093h, 01h, 040h, 01h ; A3 C4 E4
chord_f:
        db 05Ch, 02h, 0DFh, 01h, 093h, 01h ; F3 A3 C4
chord_g:
        db 01Ah, 02h, 0C4h, 01h, 067h, 01h ; G3 B3 D4
