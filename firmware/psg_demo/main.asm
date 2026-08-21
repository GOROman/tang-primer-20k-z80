; Dual-PSG demo program executed from Block RAM at 2000h.
; PSG1 plays an A-minor 1980s electro progression.
; PSG2 plays a detuned, envelope-shaped melody, noise rhythm, and cowbell.

PSG1_ADDR: equ 0A0h
PSG1_DATA: equ 0A1h
PSG2_ADDR: equ 0A2h
PSG2_DATA: equ 0A3h
LED_PORT:  equ 0B0h
DBG_PC_L:  equ 0C0h
DBG_PC_H:  equ 0C1h
DBG_A:     equ 0C2h
DBG_F:     equ 0C3h
DBG_B:     equ 0C4h
DBG_C:     equ 0C5h
DBG_D:     equ 0C6h
DBG_E:     equ 0C7h
DBG_H:     equ 0C8h
DBG_L:     equ 0C9h
DBG_SP_L:  equ 0CAh
DBG_SP_H:  equ 0CBh

        org 02000h

start:
        ; Stage 3: execution reached the RAM application.
        ld a, 008h
        out (LED_PORT), a

        ; PSG1: all three tone channels, no noise.
        ld a, 7
        out (PSG1_ADDR), a
        ld a, 038h
        out (PSG1_DATA), a
        ld a, 8
        out (PSG1_ADDR), a
        ld a, 7
        out (PSG1_DATA), a
        ld a, 9
        out (PSG1_ADDR), a
        ld a, 6
        out (PSG1_DATA), a
        ld a, 10
        out (PSG1_ADDR), a
        ld a, 6
        out (PSG1_DATA), a

        ; PSG2: Tone A/B for detuned melody, Noise C for rhythm.
        ; Mixer 1Ch = Tone A/B on, Tone C off, Noise A/B off, Noise C on.
        ld a, 7
        out (PSG2_ADDR), a
        ld a, 01Ch
        out (PSG2_DATA), a

        ; Melody A/B use the shared hardware envelope.
        ld a, 8
        out (PSG2_ADDR), a
        ld a, 010h
        out (PSG2_DATA), a
        ld a, 9
        out (PSG2_ADDR), a
        ld a, 010h
        out (PSG2_DATA), a
        ld a, 10
        out (PSG2_ADDR), a
        xor a
        out (PSG2_DATA), a

        ; Repeating triangle envelope (shape 0Eh), retriggered every note.
        ; The tone carrier remains PSG square wave; only amplitude is shaped.
        ld a, 11
        out (PSG2_ADDR), a
        xor a
        out (PSG2_DATA), a
        ld a, 12
        out (PSG2_ADDR), a
        ld a, 1
        out (PSG2_DATA), a

        ; Stage 4: both PSGs initialized. E toggles LED1/LED0 per beat.
        ld a, 004h
        out (LED_PORT), a
        ld e, 2

electro_loop:
        ld hl, electro_am1
        call set_chord
        call play_bar_cowbell
        ld hl, electro_f1
        call set_chord
        call play_bar
        ld hl, electro_c1
        call set_chord
        call play_bar
        ld hl, electro_g1
        call set_chord
        call play_bar
        ld hl, electro_am2
        call set_chord
        call play_bar
        ld hl, electro_f2
        call set_chord
        call play_bar
        ld hl, electro_c2
        call set_chord
        call play_bar
        ld hl, electro_g2
        call set_chord
        call play_bar
        jr electro_loop

; Write six bytes from HL to PSG1 tone-period registers 0 through 5.
; HL then points at eight melody/noise/drum steps for play_bar.
set_chord:
        ld b, 0
set_chord_loop:
        ld a, b
        out (PSG1_ADDR), a
        ld a, (hl)
        out (PSG1_DATA), a
        inc hl
        inc b
        ld a, b
        cp 6
        jr nz, set_chord_loop
        ret

play_bar:
        ; Eight driving steps. Each table entry is melody period,
        ; noise period, then drum volume.
        call play_step
        call play_step
        call play_step
        call play_step
        call play_step
        call play_step
        call play_step
        call play_step
        ret

; Add one metallic accent inside the first Am bar of each progression loop.
play_bar_cowbell:
        call play_step
        call play_step
        call cowbell_hit
        call play_step
        call play_step
        call play_step
        call play_step
        call play_step
        call play_step
        ret

play_step:
        call set_detuned_melody
        ld a, (hl)
        inc hl
        ld b, (hl)
        inc hl
        call noise_hit
        ret

; Load one melody period from HL. PSG2 Channel B is period +2 for detune.
set_detuned_melody:
        ld d, (hl)
        inc hl
        ld c, (hl)
        inc hl

        ld a, 0
        out (PSG2_ADDR), a
        ld a, d
        out (PSG2_DATA), a
        ld a, 1
        out (PSG2_ADDR), a
        ld a, c
        out (PSG2_DATA), a

        ld a, 2
        out (PSG2_ADDR), a
        ld a, d
        add a, 2
        out (PSG2_DATA), a
        ld a, 3
        out (PSG2_ADDR), a
        ld a, c
        adc a, 0
        out (PSG2_DATA), a

        ; Restart the decay envelope for this note.
        ld a, 13
        out (PSG2_ADDR), a
        ld a, 00Eh
        out (PSG2_DATA), a
        ret

; A = noise period, B = drum volume. Pulse PSG2 Noise C, then mute it.
noise_hit:
        push af
        ld a, 6
        out (PSG2_ADDR), a
        pop af
        out (PSG2_DATA), a

        ld a, 10
        out (PSG2_ADDR), a
        ld a, b
        out (PSG2_DATA), a

        ; Stage 5: alternate LED1/LED0 on every rhythm beat.
        ld a, e
        out (LED_PORT), a
        xor 3
        ld e, a
        call debug_snapshot
        call delay_hit

        ld a, 10
        out (PSG2_ADDR), a
        xor a
        out (PSG2_DATA), a
        call delay_beat
        ret

; TR-808-style cowbell approximation using PSG tone generators only.
; With the 1.6875 MHz PSG reference, periods 00C3h and 0084h produce
; approximately 541 Hz and 799 Hz. Their non-harmonic square-wave mixture
; creates the metallic beat; manual volume steps provide a short decay.
cowbell_hit:
        ld a, 0
        out (PSG2_ADDR), a
        ld a, 0C3h
        out (PSG2_DATA), a
        ld a, 1
        out (PSG2_ADDR), a
        xor a
        out (PSG2_DATA), a

        ld a, 2
        out (PSG2_ADDR), a
        ld a, 084h
        out (PSG2_DATA), a
        ld a, 3
        out (PSG2_ADDR), a
        xor a
        out (PSG2_DATA), a

        ld a, 8
        out (PSG2_ADDR), a
        ld a, 0Fh
        out (PSG2_DATA), a
        ld a, 9
        out (PSG2_ADDR), a
        ld a, 0Dh
        out (PSG2_DATA), a
        call delay_cowbell

        ld a, 8
        out (PSG2_ADDR), a
        ld a, 09h
        out (PSG2_DATA), a
        ld a, 9
        out (PSG2_ADDR), a
        ld a, 07h
        out (PSG2_DATA), a
        call delay_cowbell

        ld a, 8
        out (PSG2_ADDR), a
        ld a, 04h
        out (PSG2_DATA), a
        ld a, 9
        out (PSG2_ADDR), a
        ld a, 03h
        out (PSG2_DATA), a
        call delay_cowbell

        ; Restore envelope-controlled melody volumes for the next step.
        ld a, 8
        out (PSG2_ADDR), a
        ld a, 010h
        out (PSG2_DATA), a
        ld a, 9
        out (PSG2_ADDR), a
        ld a, 010h
        out (PSG2_DATA), a
        ret

; Publish a coherent register snapshot without changing the caller state.
; PC is the return address of this CALL; SP is the caller's pre-CALL value.
debug_snapshot:
        push af
        push bc
        push de
        push hl

        ; Return address is eight bytes above the four saved register pairs.
        ld hl, 8
        add hl, sp
        ld e, (hl)
        inc hl
        ld d, (hl)
        ld a, e
        out (DBG_PC_L), a
        ld a, d
        out (DBG_PC_H), a

        ; The caller's SP is ten bytes above the current SP.
        ld hl, 10
        add hl, sp
        ld a, l
        out (DBG_SP_L), a
        ld a, h
        out (DBG_SP_H), a

        pop hl
        ld a, h
        out (DBG_H), a
        ld a, l
        out (DBG_L), a

        pop de
        ld a, d
        out (DBG_D), a
        ld a, e
        out (DBG_E), a

        pop bc
        ld a, b
        out (DBG_B), a
        ld a, c
        out (DBG_C), a

        ; Extract A/F through BC, then restore both AF and BC exactly.
        pop af
        push bc
        push af
        pop bc
        ld a, b
        out (DBG_A), a
        ld a, c
        out (DBG_F), a
        push bc
        pop af
        pop bc
        ret

delay_hit:
        ld bc, 0400h
delay_hit_loop:
        dec bc
        ld a, b
        or c
        jr nz, delay_hit_loop
        ret

delay_beat:
        ld bc, 03400h
delay_beat_loop:
        dec bc
        ld a, b
        or c
        jr nz, delay_beat_loop
        ret

delay_cowbell:
        ld bc, 0180h
delay_cowbell_loop:
        dec bc
        ld a, b
        or c
        jr nz, delay_cowbell_loop
        ret

; Each entry: PSG1 chord (6 bytes), then eight 4-byte steps:
; melody period (little endian), noise period, drum volume.
; Electro progression: Am - F - C - G, repeated with octave inversions.
electro_c1:
        db 093h,01h, 040h,01h, 00Dh,01h ; C4 E4 G4
        db 040h,01h, 01Fh,0Fh ; E4, kick
        db 00Dh,01h, 002h,05h ; G4, closed hat
        db 0CAh,00h, 008h,0Ch ; C5, snare
        db 00Dh,01h, 002h,04h ; G4, closed hat
        db 0A0h,00h, 01Fh,0Eh ; E5, kick
        db 0B4h,00h, 002h,05h ; D5, closed hat
        db 0CAh,00h, 008h,0Ch ; C5, snare
        db 00Dh,01h, 004h,08h ; G4, open hat
electro_g1:
        db 0C4h,01h, 067h,01h, 00Dh,01h ; B3 D4 G4
        db 067h,01h, 01Fh,0Fh ; D4
        db 00Dh,01h, 002h,05h ; G4
        db 0E2h,00h, 008h,0Ch ; B4
        db 0B4h,00h, 002h,04h ; D5
        db 086h,00h, 01Fh,0Eh ; G5
        db 0B4h,00h, 002h,05h ; D5
        db 0E2h,00h, 008h,0Ch ; B4
        db 00Dh,01h, 004h,08h ; G4
electro_am1:
        db 0DFh,01h, 093h,01h, 040h,01h ; A3 C4 E4
        db 0F0h,00h, 01Fh,0Fh ; A4
        db 0CAh,00h, 002h,05h ; C5
        db 0A0h,00h, 008h,0Ch ; E5
        db 0CAh,00h, 002h,04h ; C5
        db 078h,00h, 01Fh,0Eh ; A5
        db 0A0h,00h, 002h,05h ; E5
        db 0CAh,00h, 008h,0Ch ; C5
        db 0E2h,00h, 004h,08h ; B4
electro_am2:
        db 040h,01h, 0F0h,00h, 0CAh,00h ; E4 A4 C5
        db 0A0h,00h, 01Fh,0Fh ; E5
        db 0CAh,00h, 002h,05h ; C5
        db 0F0h,00h, 008h,0Ch ; A4
        db 0CAh,00h, 002h,04h ; C5
        db 0A0h,00h, 01Fh,0Eh ; E5
        db 0CAh,00h, 002h,05h ; C5
        db 0E2h,00h, 008h,0Ch ; B4
        db 0F0h,00h, 004h,08h ; A4
electro_f1:
        db 0DFh,01h, 093h,01h, 02Eh,01h ; A3 C4 F4
        db 02Eh,01h, 01Fh,0Fh ; F4
        db 0F0h,00h, 002h,05h ; A4
        db 0CAh,00h, 008h,0Ch ; C5
        db 097h,00h, 002h,04h ; F5
        db 0A0h,00h, 01Fh,0Eh ; E5
        db 0CAh,00h, 002h,05h ; C5
        db 0F0h,00h, 008h,0Ch ; A4
        db 0CAh,00h, 004h,08h ; C5
electro_c2:
        db 01Ah,02h, 093h,01h, 040h,01h ; G3 C4 E4
        db 00Dh,01h, 01Fh,0Fh ; G4
        db 0CAh,00h, 002h,05h ; C5
        db 0A0h,00h, 008h,0Ch ; E5
        db 086h,00h, 002h,04h ; G5
        db 0A0h,00h, 01Fh,0Eh ; E5
        db 0CAh,00h, 002h,05h ; C5
        db 00Dh,01h, 008h,0Ch ; G4
        db 040h,01h, 004h,08h ; E4
electro_f2:
        db 05Ch,02h, 0DFh,01h, 093h,01h ; F3 A3 C4
        db 0F0h,00h, 01Fh,0Fh ; A4
        db 0CAh,00h, 002h,05h ; C5
        db 097h,00h, 008h,0Ch ; F5
        db 0CAh,00h, 002h,04h ; C5
        db 0F0h,00h, 01Fh,0Eh ; A4
        db 00Dh,01h, 002h,05h ; G4
        db 02Eh,01h, 008h,0Ch ; F4
        db 0CAh,00h, 004h,08h ; C5
electro_g2:
        db 01Ah,02h, 0C4h,01h, 067h,01h ; G3 B3 D4
        db 0E2h,00h, 01Fh,0Fh ; B4
        db 0B4h,00h, 002h,05h ; D5
        db 086h,00h, 008h,0Ch ; G5
        db 0B4h,00h, 002h,04h ; D5
        db 0E2h,00h, 01Fh,0Eh ; B4
        db 0F0h,00h, 002h,05h ; A4
        db 00Dh,01h, 008h,0Ch ; G4
        db 0B4h,00h, 004h,08h ; D5
