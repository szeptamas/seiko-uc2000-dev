; Seiko UC-2000
; Tiny Flappy-style game, first hardware-test draft
;
; Controls:
;   START/STOP SELECT starts/restarts
;   START/STOP SELECT makes the bird flap
;   MODE toggles sound on the title screen
;
; Display model:
;   Text-mode 4x10 playfield using character cells.
;   The bird is a race-the-beam pseudo-sprite at columns 0-1.
;   The pipe advances through column pairs 8-9, 6-7, 4-5, 2-3, 0-1.
;   Collision is checked only at 0-1.

        ##define birdY RA0
        ##define pipeStep RA1
        ##define gapY RA2
        ##define gameFlags RA3
        ##define scoreL RA4
        ##define topScore RA5
        ##define birdState RA6
        ##define flashCount RA7

        ##define scoreT RC0
        ##define scoreH RC1
        ##define topScoreT RC2
        ##define topScoreH RC3
        ##define birdMotion RC4

        ##define buttonsState RB0
        ##define delayOuter RB1
        ##define delayInner RB2
        ##define delayRepeat RB3

        ##define soundOff 0
        ##define settingsInitA 1
        ##define settingsInitB 2
        ##define settingsInitC 3

        ##define btnMode 3
        ##define btnStart 1

        ##define clearScreen 0x7D
        ##define resetScanline 0x7F
        ##define print5RAMBytes 0xBD0 - 5
        ##define print6RAMBytes 0xBD0 - 6
        ##define print10RAMBytes 0xBD0 - 10
        ##define clearCurrentBank 0x8F2

        ##define tremoloOn 0b0100
        ##define tremoloOff 0b0010
        ##define beep 0b0001

        jmp start
        jmp start
        jmp 0x11A
        jmp 0x109
        jmp 0x0E0
        jmp start
        jmp start
        jmp start
        jmp start
        jmp 0x2A9
        jmp 0x307
        jmp 0x39C
        jmp 0x09B
        jmp draw
        ret

strTitle:
        db 'F','l','a','p','p','y','B','i','r','d'
strByLion:
        db ' ','b','y',' ','L','i','o','n',' ',' '
strStart:
        db 'P','l','a','y',':','S','T','A','R','T'
strSoundOn:
        db 'S','N','D','O','N',':','M','O','D','E'
strSoundOff:
        db 'S','N','D','O','F','F',':','M','O','D'
strGameOver:
        db 'G','A','M','E',' ','O','V','E','R',' '
strScore:
        db 'S','c','o','r','e',':'
strTop:
        db 'T','o','p',':',' ',' '

birdSpriteNormal:
        db 0xE1,0x44, 0x31,0x4A, 0x36,0x22, 0x47,0x29, 0xDA,0xE5, 0x66,0x9B, 0x5D,0x44
birdSpriteUp:
        db 0x00,0x42, 0xFC,0xFC, 0x21,0x7F, 0x7E,0x29, 0xDA,0x21, 0x6B,0x66, 0x47,0x46
birdSpriteDown:
        db 0x7E,0x25, 0x35,0x21, 0x62,0x22, 0x7E,0x29, 0x24,0x26, 0x34,0xFB, 0x71,0x44
birdSpriteDead:
        db 0x28,0x4C, 0x00,0x00, 0x32,0x35, 0x32,0x35, 0x6B,0x30, 0x2F,0xFB, 0x47,0x32
birdSpriteNormalRev:
        db 0x5D,0x44, 0x66,0x9B, 0xDA,0xE5, 0x47,0x29, 0x36,0x22, 0x31,0x4A, 0xE1,0x44
birdSpriteUpRev:
        db 0x47,0x46, 0x6B,0x66, 0xDA,0x21, 0x7E,0x29, 0x21,0x7F, 0xFC,0xFC, 0x00,0x42
birdSpriteDownRev:
        db 0x71,0x44, 0x34,0xFB, 0x24,0x26, 0x7E,0x29, 0x62,0x22, 0x35,0x21, 0x7E,0x25
birdSpriteDeadRev:
        db 0x47,0x32, 0x2F,0xFB, 0x6B,0x30, 0x32,0x35, 0x32,0x35, 0x00,0x00, 0x28,0x4C

start:
        stlia clearScreen
        outi SR7, 0
        outi SR13, 0
        outi SR15, tremoloOff
        lcrb B3
        larb B0
        btjr gameFlags, settingsInitA, start_check_init_b
        jmp start_init_settings
start_check_init_b:
        btjr gameFlags, settingsInitB, start_check_init_c
        jmp start_init_settings
start_check_init_c:
        btjr gameFlags, settingsInitC, start_keep_settings
start_init_settings:
        ldi gameFlags, (1 << settingsInitA) | (1 << settingsInitB) | (1 << settingsInitC)
start_keep_settings:
        ldi topScore, 0
        ldi topScoreT, 0
        ldi topScoreH, 0
        call show_title
        jmp wait_start

wait_start:
        in buttonsState, SR7
        cpjr buttonsState, 0, wait_start_no_key
        btjr buttonsState, btnMode, wait_start_toggle_sound
        btjr buttonsState, btnStart, wait_start_do_start
        outi SR7, 0
        call wait_release
        jmp wait_start
wait_start_do_start:
        outi SR7, 0
        call wait_release
        jmp new_game
wait_start_toggle_sound:
        xori gameFlags, 1 << soundOff
        outi SR7, 0
        call show_title
        call wait_release
        jmp wait_start
wait_start_no_key:
        jmp wait_start

game_loop:
        call delay_frame
        in buttonsState, SR7
        btjr buttonsState, btnStart, do_flap
        cpjr buttonsState, 0, no_flap
        outi SR7, 0
        jmp no_flap
do_flap:
        outi SR7, 0
        cpjr birdY, 0, do_flap_set_motion
        dec birdY, birdY % 8
do_flap_set_motion:
        ldi birdState, 1
        ldi birdMotion, 1
        jmp after_gravity
no_flap:
        call update_bird_motion
        cpi birdY, 4
        jc after_gravity
        ldi birdY, 3
        jmp game_over
after_gravity:
        inc pipeStep, pipeStep % 8
        cpi pipeStep, 5
        jnz timer_check_collision
        ldi pipeStep, 0
        inc scoreL, scoreL % 8
        cpi scoreL, 10
        jnz score_inc_beep
        ldi scoreL, 0
        inc scoreT, scoreT % 8
        cpi scoreT, 10
        jnz score_inc_beep
        ldi scoreT, 0
        inc scoreH, scoreH % 8
        cpi scoreH, 10
        jnz score_inc_beep
        ldi scoreH, 0
score_inc_beep:
        call play_score_beep_if_enabled
score_inc_done:
        inc gapY, gapY % 8
        cpi gapY, 3
        jnz timer_check_collision
        ldi gapY, 1

timer_check_collision:
        cpi pipeStep, 4         ; columns 0-1, same as bird columns.
        jnz timer_draw
        call check_gap
timer_draw:
        call draw
        jmp game_loop

check_gap:
        cpjr gapY, 1, check_gap1
check_gap2:
        cpjr birdY, 1, check_gap_ok
        cpjr birdY, 2, check_gap_ok
        jmp game_over
check_gap1:
        cpjr birdY, 0, check_gap_ok
        cpjr birdY, 1, check_gap_ok
        jmp game_over
check_gap_ok:
        ret

update_bird_motion:
        cpjr birdMotion, 1, bird_motion_normal
bird_motion_down:
        ldi birdState, 2
        inc birdY, birdY % 8
        ret
bird_motion_normal:
        ldi birdState, 0
        ldi birdMotion, 2
        ret

new_game:
        ldi birdY, 1
        ldi pipeStep, 0
        ldi gapY, 1
        ldi scoreL, 0
        ldi scoreT, 0
        ldi scoreH, 0
        ldi birdMotion, 2
        ldi flashCount, 0
        ldi birdState, 0
        outi SR15, tremoloOff
        call draw
        jmp game_loop

game_over:
        cpi pipeStep, 4
        jnz game_over_flash_init
game_over_shift_pipe:
        ldi pipeStep, 3
game_over_flash_init:
        ldi birdState, 3
        ldi flashCount, 4
        btjr gameFlags, soundOff, game_over_flash_loop
        outi SR15, tremoloOn
game_over_flash_loop:
        stlia clearScreen
        call draw_pipe
        call draw_score_hud
        call draw_bird_rtb
        call delay_frame
        outi SR15, tremoloOff
        stlia clearScreen
        call draw_pipe
        call draw_score_hud
        call delay_frame
        dec flashCount, flashCount % 8
        jnz game_over_flash_loop
        outi SR15, tremoloOff
        cmp scoreH, topScoreH
        jc game_over_keep_top
        jnz game_over_set_top
        cmp scoreT, topScoreT
        jc game_over_keep_top
        jnz game_over_set_top
        cmp scoreL, topScore
        jc game_over_keep_top
game_over_set_top:
        mov topScoreH, scoreH
        mov topScoreT, scoreT
        mov topScore, scoreL
game_over_keep_top:
        stlia clearScreen
        plai 0
        psai strGameOver
        call print10RAMBytes
        plai 10
        psai strScore
        call print6RAMBytes
        call print_score
        plai 20
        psai strTop
        call print6RAMBytes
        call print_top_score
        plai 30
        psai strStart
        call print10RAMBytes
        stlia resetScanline
        outi SR7, 0
        call wait_release
        jmp wait_start

delay_frame:
        ldi delayRepeat, 5
delay_repeat_loop:
        ldi delayOuter, 15
delay_outer_loop:
        ldi delayInner, 15
delay_inner_loop:
        dec delayInner, delayInner % 8
        jnz delay_inner_loop
        dec delayOuter, delayOuter % 8
        jnz delay_outer_loop
        dec delayRepeat, delayRepeat % 8
        jnz delay_repeat_loop
        ret

wait_release:
        in buttonsState, SR8
        cpjr buttonsState, 0, wait_release_done
        outi SR7, 0
        jmp wait_release
wait_release_done:
        outi SR7, 0
        ret

play_beep_if_enabled:
        btjr gameFlags, soundOff, play_beep_if_enabled_skip
        outi SR15, beep
play_beep_if_enabled_skip:
        ret

play_score_beep_if_enabled:
        btjr gameFlags, soundOff, play_score_beep_if_enabled_skip
        outi SR15, beep
        call delay_sound_gap
        outi SR15, beep
play_score_beep_if_enabled_skip:
        ret

delay_sound_gap:
        ldi delayOuter, 3
delay_sound_gap_outer:
        ldi delayInner, 15
delay_sound_gap_inner:
        dec delayInner, delayInner % 8
        jnz delay_sound_gap_inner
        dec delayOuter, delayOuter % 8
        jnz delay_sound_gap_outer
        ret

show_title:
        stlia clearScreen
        plai 0
        psai strTitle
        call print10RAMBytes
        plai 10
        psai strByLion
        call print10RAMBytes
        plai 20
        psai strStart
        call print10RAMBytes
        plai 30
        btjr gameFlags, soundOff, show_title_sound_off
        psai strSoundOn
        call print10RAMBytes
        stlia resetScanline
        ret
show_title_sound_off:
        psai strSoundOff
        call print10RAMBytes
        stlia resetScanline
        ret

print_score:
        cpi scoreH, 0
        jz print_score_h_blank
        mov delayOuter, scoreH
        call print_digit_delay_outer
        jmp print_score_tens
print_score_h_blank:
        stli ' '
print_score_tens:
        cpi scoreH, 0
        jnz print_score_t_digit
        cpi scoreT, 0
        jz print_score_t_blank
print_score_t_digit:
        mov delayOuter, scoreT
        call print_digit_delay_outer
        jmp print_score_units
print_score_t_blank:
        stli ' '
print_score_units:
        mov delayOuter, scoreL
        jmp print_digit_delay_outer

print_top_score:
        cpi topScoreH, 0
        jz print_top_h_blank
        mov delayOuter, topScoreH
        call print_digit_delay_outer
        jmp print_top_tens
print_top_h_blank:
        stli ' '
print_top_tens:
        cpi topScoreH, 0
        jnz print_top_t_digit
        cpi topScoreT, 0
        jz print_top_t_blank
print_top_t_digit:
        mov delayOuter, topScoreT
        call print_digit_delay_outer
        jmp print_top_units
print_top_t_blank:
        stli ' '
print_top_units:
        mov delayOuter, topScore
        jmp print_digit_delay_outer

print_digit_delay_outer:
        cpi delayOuter, 0
        jz print_digit0
        cpi delayOuter, 1
        jz print_digit1
        cpi delayOuter, 2
        jz print_digit2
        cpi delayOuter, 3
        jz print_digit3
        cpi delayOuter, 4
        jz print_digit4
        cpi delayOuter, 5
        jz print_digit5
        cpi delayOuter, 6
        jz print_digit6
        cpi delayOuter, 7
        jz print_digit7
        cpi delayOuter, 8
        jz print_digit8
        jmp print_digit9
print_digit0:
        stli '0'
        ret
print_digit1:
        stli '1'
        ret
print_digit2:
        stli '2'
        ret
print_digit3:
        stli '3'
        ret
print_digit4:
        stli '4'
        ret
print_digit5:
        stli '5'
        ret
print_digit6:
        stli '6'
        ret
print_digit7:
        stli '7'
        ret
print_digit8:
        stli '8'
        ret
print_digit9:
        stli '9'
        ret

draw:
        stlia clearScreen
        call draw_pipe
        jmp draw_score_hud_playing

draw_score_hud_playing:
        stlia resetScanline
        call print_score_hud
        stlia resetScanline
        jmp draw_bird_rtb

draw_score_hud:
        stlia resetScanline
        call print_score_hud
        stlia resetScanline
        ret

print_score_hud:
        cpi scoreH, 0
        jz print_score_hud_check_tens
        plai 7
        mov delayOuter, scoreH
        call print_digit_delay_outer
        mov delayOuter, scoreT
        call print_digit_delay_outer
        mov delayOuter, scoreL
        jmp print_digit_delay_outer
print_score_hud_check_tens:
        cpi scoreT, 0
        jz print_score_hud_units
        plai 8
        mov delayOuter, scoreT
        call print_digit_delay_outer
        mov delayOuter, scoreL
        jmp print_digit_delay_outer
print_score_hud_units:
        plai 9
        mov delayOuter, scoreL
        jmp print_digit_delay_outer

draw_bird_rtb:
        cpjr birdY, 0, draw_bird_rtb0
        cpjr birdY, 1, draw_bird_rtb1_j
        cpjr birdY, 2, draw_bird_rtb2_j
        jmp draw_bird_rtb3
draw_bird_rtb1_j:
        jmp draw_bird_rtb1
draw_bird_rtb2_j:
        jmp draw_bird_rtb2

select_bird_sprite_top:
        cpjr birdState, 0, select_bird_sprite_normal
        cpjr birdState, 1, select_bird_sprite_up
        cpjr birdState, 2, select_bird_sprite_down
        psai birdSpriteDead
        ret
select_bird_sprite_normal:
        psai birdSpriteNormal
        ret
select_bird_sprite_up:
        psai birdSpriteUp
        ret
select_bird_sprite_down:
        psai birdSpriteDown
        ret

select_bird_sprite_bottom:
        cpjr birdState, 0, select_bird_sprite_bottom_normal
        cpjr birdState, 1, select_bird_sprite_bottom_up
        cpjr birdState, 2, select_bird_sprite_bottom_down
        psai birdSpriteDeadRev
        ret
select_bird_sprite_bottom_normal:
        psai birdSpriteNormalRev
        ret
select_bird_sprite_bottom_up:
        psai birdSpriteUpRev
        ret
select_bird_sprite_bottom_down:
        psai birdSpriteDownRev
        ret

draw_bird_rtb0:
        call select_bird_sprite_top
        plai 0
        stls
        stls
        stlia resetScanline
        plai 0
        stls
        stls
        cpi RB0, 0
        plai 0
        stls
        stls
        cpi RB0, 0
        plai 0
        stls
        stls
        cpi RB0, 0
        plai 0
        stls
        stls
        cpi RB0, 0
        plai 0
        stls
        stls
        cpi RB0, 0
        plai 0
        stls
        stls
        cpi RB0, 0
        ret

draw_bird_rtb1:
        call select_bird_sprite_top
        plai 10
        stls
        stls
        stlia resetScanline
        ldi delayInner, 15
draw_bird_rtb1_wait:
        dec delayInner, delayInner % 8
        jnz draw_bird_rtb1_wait
        cpi RB0, 0
        plai 10
        stls
        stls
        cpi RB0, 0
        plai 10
        stls
        stls
        cpi RB0, 0
        plai 10
        stls
        stls
        cpi RB0, 0
        plai 10
        stls
        stls
        cpi RB0, 0
        plai 10
        stls
        stls
        cpi RB0, 0
        plai 10
        stls
        stls
        cpi RB0, 0
        ret

draw_bird_rtb2:
        call select_bird_sprite_bottom
        plai 20
        stls
        stls
        stlia resetScanline
        ldi delayInner, 15
draw_bird_rtb2_wait1:
        dec delayInner, delayInner % 8
        jnz draw_bird_rtb2_wait1
        ldi delayInner, 15
draw_bird_rtb2_wait2:
        dec delayInner, delayInner % 8
        jnz draw_bird_rtb2_wait2
        ldi delayInner, 15
draw_bird_rtb2_wait3:
        dec delayInner, delayInner % 8
        jnz draw_bird_rtb2_wait3
        cpi RB0, 0
        cpi RB0, 0
        cpi RB0, 0
        cpi RB0, 0
        cpi RB0, 0
        plai 20
        stls
        stls
        cpi RB0, 0
        plai 20
        stls
        stls
        cpi RB0, 0
        plai 20
        stls
        stls
        cpi RB0, 0
        plai 20
        stls
        stls
        cpi RB0, 0
        plai 20
        stls
        stls
        cpi RB0, 0
        plai 20
        stls
        stls
        cpi RB0, 0
        ret

draw_bird_rtb3:
        call select_bird_sprite_bottom
        plai 30
        stls
        stls
        stlia resetScanline
        ldi delayInner, 15
draw_bird_rtb3_wait1:
        dec delayInner, delayInner % 8
        jnz draw_bird_rtb3_wait1
        ldi delayInner, 15
draw_bird_rtb3_wait2:
        dec delayInner, delayInner % 8
        jnz draw_bird_rtb3_wait2
        cpi RB0, 0
        cpi RB0, 0
        cpi RB0, 0
        cpi RB0, 0
        plai 30
        stls
        stls
        cpi RB0, 0
        plai 30
        stls
        stls
        cpi RB0, 0
        plai 30
        stls
        stls
        cpi RB0, 0
        plai 30
        stls
        stls
        cpi RB0, 0
        plai 30
        stls
        stls
        cpi RB0, 0
        plai 30
        stls
        stls
        cpi RB0, 0
        ret

draw_pipe:
        cpjr pipeStep, 0, draw_pipe9_j
        cpjr pipeStep, 1, draw_pipe7_j
        cpjr pipeStep, 2, draw_pipe5_j
        cpjr pipeStep, 3, draw_pipe3_j
        jmp draw_pipe1
draw_pipe9_j:
        jmp draw_pipe9
draw_pipe7_j:
        jmp draw_pipe7
draw_pipe5_j:
        jmp draw_pipe5
draw_pipe3_j:
        jmp draw_pipe3

draw_pipe9:
        cpjr gapY, 1, draw_pipe9_gap1
        plai 8
        stli 0xFF
        plai 9
        stli 0xFF
        plai 38
        stli 0xFF
        plai 39
        stli 0xFF
        ret
draw_pipe9_gap1:
        plai 28
        stli 0xFF
        plai 29
        stli 0xFF
        plai 38
        stli 0xFF
        plai 39
        stli 0xFF
        ret

draw_pipe7:
        cpjr gapY, 1, draw_pipe7_gap1
        plai 6
        stli 0xFF
        plai 7
        stli 0xFF
        plai 36
        stli 0xFF
        plai 37
        stli 0xFF
        ret
draw_pipe7_gap1:
        plai 26
        stli 0xFF
        plai 27
        stli 0xFF
        plai 36
        stli 0xFF
        plai 37
        stli 0xFF
        ret

draw_pipe5:
        cpjr gapY, 1, draw_pipe5_gap1
        plai 4
        stli 0xFF
        plai 5
        stli 0xFF
        plai 34
        stli 0xFF
        plai 35
        stli 0xFF
        ret
draw_pipe5_gap1:
        plai 24
        stli 0xFF
        plai 25
        stli 0xFF
        plai 34
        stli 0xFF
        plai 35
        stli 0xFF
        ret

draw_pipe3:
        cpjr gapY, 1, draw_pipe3_gap1
        plai 2
        stli 0xFF
        plai 3
        stli 0xFF
        plai 32
        stli 0xFF
        plai 33
        stli 0xFF
        ret
draw_pipe3_gap1:
        plai 22
        stli 0xFF
        plai 23
        stli 0xFF
        plai 32
        stli 0xFF
        plai 33
        stli 0xFF
        ret

draw_pipe1:
        cpjr gapY, 1, draw_pipe1_gap1
        plai 0
        stli 0xFF
        plai 1
        stli 0xFF
        plai 30
        stli 0xFF
        plai 31
        stli 0xFF
        ret
draw_pipe1_gap1:
        plai 20
        stli 0xFF
        plai 21
        stli 0xFF
        plai 30
        stli 0xFF
        plai 31
        stli 0xFF
        ret
