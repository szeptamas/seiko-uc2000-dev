# Flappy Bird Draft

Minimal Seiko UC-2000 Flappy-style game intended as a first hardware-test build.

## Controls

- `START/STOP SELECT` starts from the title screen.
- `MODE` toggles sound on the title screen.
- `START/STOP SELECT` flaps upward during the game.
- Other buttons are ignored during the game.

## Design Constraints

- Target size: under 2048 bytes.
- Uses text-mode character cells for the playfield.
- Uses Platformer-style race-the-beam rendering for the bird sprite.
- The bird is built from small bitmap tables, not from a single fixed character.
- Runs as a self-contained polling loop from external RAM, rather than returning to the firmware button handlers.
- Bird position is fixed at columns 0-1.
- Pipe column pairs advance through 8-9, 6-7, 4-5, 2-3, and 0-1.
- Collision is checked when the pipe reaches 0-1.
- Game over screen shows `GAME OVER`, current score, top score, and restart hint.
- Top score is kept in RAM while the program keeps running.

## Transfer Note

The expected output is `flappy.bin`. The known PC/Arduino transfer path sends up to 8 pages of 256 bytes, so this program must remain at or below 2048 bytes.

## Baseline

Saved baseline snapshot:

- `baseline-v1/flappy-base-v1.asm`
- `baseline-v1/flappy-base-v1.bin`
- `baseline-v1/README.md`

Saved current snapshot:

- `snapshot-2026-05-06/flappy-snapshot-2026-05-06.asm`
- `snapshot-2026-05-06/flappy-snapshot-2026-05-06.bin`
- `snapshot-2026-05-06/flappy-snapshot-2026-05-06.ram`
- `snapshot-2026-05-06/README.md`

Saved pre-tuning snapshot:

- `snapshot-2026-05-06-pre-tuning/flappy-snapshot-2026-05-06-pre-tuning.asm`
- `snapshot-2026-05-06-pre-tuning/flappy-snapshot-2026-05-06-pre-tuning.bin`
- `snapshot-2026-05-06-pre-tuning/flappy-snapshot-2026-05-06-pre-tuning.ram`
- `snapshot-2026-05-06-pre-tuning/README.md`

## Current Build

- 2-cell wide, 7-line race-the-beam bird sprite
- state-based bird motion: flap rise, short apex, then continuous fall
- bird shape simplified from MegaCrash's CC0 16x16 asset pack and the provided monochrome references
- primary pipe plus optional second pipe for variable spacing
- 3-digit score and top score
- double point beep, speed-up triple beep, and classic-style death sting approximation with title-screen sound toggle
- sound on/off state is preserved while the RAM program remains loaded
- scrolling title text: `Created by Lion in 2026 (github.com/szeptamas) for the legendary Seiko UC-2000 programmable wristwatch. Thanks to azya52!`
- score-based speed increase with a capped top speed
- 3 gap patterns: top-only, centered, bottom-only
- second pipe can be absent, so pipe spacing is less repetitive
- short death blink before the game over screen
