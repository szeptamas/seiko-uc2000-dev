; Seiko UC-2000
; Tiny Flappy-style game, first hardware-test draft
;
; Controls:
;   Any key starts/restarts
;   TRANSMIT makes the bird flap
;
; Display model:
;   Text-mode 4x10 playfield using character cells.
;   The bird is fixed at column 1. The pipe advances through columns
;   9, 7, 5, 3, 1. Collision is checked only at column 1.

        ##define birdY RA0
        ##define pipeStep RA1
        ##define gapY RA2
        ##define gameState RA3
        ##define scoreL RA4
        ##define topScore RA5
        ##define birdFrame RA6

        ##define buttonsState RB0
        ##define delayOuter RB1
        ##define delayInner RB2
        ##define delayRepeat RB3

        ##define clearScreen 0x7D
        ##define resetScanline 0x7F
        ##define print5RAMBytes 0xBD0 - 5
        ##define print6RAMBytes 0xBD0 - 6
        ##define print10RAMBytes 0xBD0 - 10
        ##define clearCurrentBank 0x8F2

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

start:
        stlia clearScreen
        outi SR7, 0
        outi SR13, 0
        lcrb B3
        larb B0
        call show_title
        jmp wait_start

wait_start:
        in buttonsState, SR7
        cpjr buttonsState, 0, wait_start_no_key
        outi SR7, 0
        jmp new_game
wait_start_no_key:
        jmp wait_start

game_loop:
        call delay_frame
        inc birdFrame, birdFrame % 8
        cpi birdFrame, 3
        jnz bird_frame_ok
        ldi birdFrame, 0
bird_frame_ok:
        in buttonsState, SR7
        btjr buttonsState, 2, do_flap
        cpjr buttonsState, 0, no_flap
        outi SR7, 0
        jmp no_flap
do_flap:
        outi SR7, 0
        ldi birdFrame, 0
        cpjr birdY, 0, flap_done
        dec birdY, birdY % 8
flap_done:
        jmp after_gravity
no_flap:
        inc birdY, birdY % 8
        cpi birdY, 4
        jnc game_over
after_gravity:

        inc pipeStep, pipeStep % 8
        cpi pipeStep, 5
        jnz timer_check_collision
        ldi pipeStep, 0
        inc scoreL, scoreL % 8
        inc gapY, gapY % 8
        cpi gapY, 3
        jnz timer_check_collision
        ldi gapY, 1

timer_check_collision:
        cpi pipeStep, 4         ; column 1, same as bird column.
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

new_game:
        ldi birdY, 1
        ldi pipeStep, 0
        ldi gapY, 1
        ldi scoreL, 0
        ldi birdFrame, 0
        ldi gameState, 1
        call draw
        jmp game_loop

game_over:
        ldi gameState, 2
        cmp scoreL, topScore
        jc game_over_keep_top
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

show_title:
        stlia clearScreen
        plai 10
        psai strTitle
        call print10RAMBytes
        plai 20
        psai strStart
        call print10RAMBytes
        plai 30
        psai strFlap
        call print10RAMBytes
        stlia resetScanline
        ret

print_score:
        cpi scoreL, 0
        jz print_score0
        cpi scoreL, 1
        jz print_score1
        cpi scoreL, 2
        jz print_score2
        cpi scoreL, 3
        jz print_score3
        cpi scoreL, 4
        jz print_score4
        cpi scoreL, 5
        jz print_score5
        cpi scoreL, 6
        jz print_score6
        cpi scoreL, 7
        jz print_score7
        cpi scoreL, 8
        jz print_score8
        jmp print_score9
print_score0:
        stli '0'
        ret
print_score1:
        stli '1'
        ret
print_score2:
        stli '2'
        ret
print_score3:
        stli '3'
        ret
print_score4:
        stli '4'
        ret
print_score5:
        stli '5'
        ret
print_score6:
        stli '6'
        ret
print_score7:
        stli '7'
        ret
print_score8:
        stli '8'
        ret
print_score9:
        stli '9'
        ret

print_top_score:
        cpjr topScore, 0, print_top_score0
        cpjr topScore, 1, print_top_score1
        cpjr topScore, 2, print_top_score2
        cpjr topScore, 3, print_top_score3
        cpi topScore, 4
        jz print_top_score4
        cpi topScore, 5
        jz print_top_score5
        cpi topScore, 6
        jz print_top_score6
        cpi topScore, 7
        jz print_top_score7
        cpi topScore, 8
        jz print_top_score8
        jmp print_top_score9
print_top_score0:
        stli '0'
        ret
print_top_score1:
        stli '1'
        ret
print_top_score2:
        stli '2'
        ret
print_top_score3:
        stli '3'
        ret
print_top_score4:
        stli '4'
        ret
print_top_score5:
        stli '5'
        ret
print_top_score6:
        stli '6'
        ret
print_top_score7:
        stli '7'
        ret
print_top_score8:
        stli '8'
        ret
print_top_score9:
        stli '9'
        ret

draw:
        cpjr gameState, 1, draw_playing
        ret
draw_playing:
        stlia clearScreen
        call draw_pipe
        call draw_bird
        stlia resetScanline
        ret

draw_bird:
        cpjr birdY, 0, draw_bird0
        cpjr birdY, 1, draw_bird1
        cpjr birdY, 2, draw_bird2
draw_bird3:
        plai 31
        call draw_bird_char
        ret
draw_bird2:
        plai 21
        call draw_bird_char
        ret
draw_bird1:
        plai 11
        call draw_bird_char
        ret
draw_bird0:
        plai 1
        call draw_bird_char
        ret

draw_bird_char:
        cpjr birdFrame, 0, draw_bird_char0
        cpjr birdFrame, 1, draw_bird_char1
        stli 0x98
        ret
draw_bird_char1:
        stli 0x99
        ret
draw_bird_char0:
        stli 0x97
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
        plai 9
        stli 0xFF
        plai 39
        stli 0xFF
        ret
draw_pipe9_gap1:
        plai 29
        stli 0xFF
        plai 39
        stli 0xFF
        ret

draw_pipe7:
        cpjr gapY, 1, draw_pipe7_gap1
        plai 7
        stli 0xFF
        plai 37
        stli 0xFF
        ret
draw_pipe7_gap1:
        plai 27
        stli 0xFF
        plai 37
        stli 0xFF
        ret

draw_pipe5:
        cpjr gapY, 1, draw_pipe5_gap1
        plai 5
        stli 0xFF
        plai 35
        stli 0xFF
        ret
draw_pipe5_gap1:
        plai 25
        stli 0xFF
        plai 35
        stli 0xFF
        ret

draw_pipe3:
        cpjr gapY, 1, draw_pipe3_gap1
        plai 3
        stli 0xFF
        plai 33
        stli 0xFF
        ret
draw_pipe3_gap1:
        plai 23
        stli 0xFF
        plai 33
        stli 0xFF
        ret

draw_pipe1:
        cpjr gapY, 1, draw_pipe1_gap1
        plai 1
        stli 0xFF
        plai 31
        stli 0xFF
        ret
draw_pipe1_gap1:
        plai 21
        stli 0xFF
        plai 31
        stli 0xFF
        ret

strTitle:
        db 'F','L','A','P','P','Y',' ','U','C','2'
strStart:
        db 'S','T','A','R','T',' ','A','N','Y',' '
strFlap:
        db 'F','L','A','P',' ','T','R','N','S','M'
strGameOver:
        db 'G','A','M','E',' ','O','V','E','R',' '
strScore:
        db 'S','C','O','R','E',' '
strTop:
        db 'T','O','P',' ',' ',' '
