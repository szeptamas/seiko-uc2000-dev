# Flappy Bird for Seiko UC-2000

`Flappy Bird` is an assembly game for the Seiko UC-2000 watch family.

This directory contains:

- `flappy.asm` - current source
- `flappy.bin` - current assembled program binary
- `flappy.ram` - emulator-ready external RAM image
- `build` - one-line build command
- `pixelgraphics.xlsx` - sprite planning sheet
- `baseline-v1/` - saved early baseline
- `snapshot-2026-05-06/` - saved intermediate snapshot
- `snapshot-2026-05-06-pre-tuning/` - saved gameplay state before later tuning

## Current Controls

Title screen:

- `START/STOP SELECT` - start game
- `MODE` - toggle sound

In game:

- `START/STOP SELECT` - flap

Game over screen:

- `START/STOP SELECT` - restart immediately
- `MODE` - return to title screen

## Current Features

- 2-cell-wide, 7-line race-the-beam bird sprite
- text-mode playfield with custom sprite rendering
- primary pipe plus optional secondary pipe
- variable pipe spacing
- 3 pipe gap patterns: top-only, centered, bottom-only
- 3-digit score and top score
- score-based speed increase with capped maximum speed
- title-screen scroll text
- title-screen sound toggle
- sound state preserved while the RAM program remains loaded
- death blink animation and death sound pattern

## Important Constraints

- target platform: Seiko UC-2000 external RAM program
- hard size limit: about `2048 bytes`
- current `flappy.bin` size must stay under that limit
- the game uses a polling loop and does not return to the stock firmware handlers during play
- rendering is based on text mode plus timing tricks, not full graphics mode

## Build

From this directory:

```powershell
node ../../tools/assembler/simple-ucasm/simple-ucasm.js -o flappy.bin flappy.asm
```

Equivalent helper file:

```text
build
```

After rebuilding, refresh the emulator RAM image:

```powershell
Copy-Item -Force .\flappy.bin .\flappy.ram
Copy-Item -Force .\flappy.bin ..\..\tools\emulator-or-simulator\Emulator2000\assets\flappy.ram
```

## Run in the Emulator

The repository includes a vendored copy of `Emulator2000`:

- `tools/emulator-or-simulator/Emulator2000/`

Run script:

- `tools/emulator-or-simulator/Emulator2000/run-flappy.ps1`

Current script behavior:

- starts `main.py`
- loads `assets/UC2000.rom`
- loads `assets/flappy.ram`
- uses the UC-2000 face SVG
- starts execution at `0xC00`

If needed, install the GUI dependency first:

```powershell
C:\Python313\python.exe -m pip install PyQt6
```

Then run:

```powershell
cd ..\..\tools\emulator-or-simulator\Emulator2000
.\run-flappy.ps1
```

## Transfer to Real Hardware

Expected output for transfer:

- `flappy.bin`

Known practical transfer path used in this project:

1. build `flappy.bin`
2. copy it to a phone or transfer workstation
3. use an external sender / keyboard-emulator workflow for UC-2000 transfer

The binary must remain within the known external-memory transfer limit:

- `8 pages * 256 bytes = 2048 bytes`

## Notes on the Implementation

- the bird is not a single character glyph; it is drawn from sprite byte tables
- bottom-half bird rendering uses separate reversed sprite tables
- the emulator and the real watch have a very shallow call stack, so control flow is intentionally flat in many places
- some repeated instructions in the sprite drawing code are timing fillers and are intentional

## Scroll Text

Current title scroll text:

```text
Created by Lion in 2026 (github.com/szeptamas) for the legendary Seiko UC-2000 programmable wristwatch. Thanks to azya52!
```

## History Snapshots

Saved development checkpoints:

- `baseline-v1/`
- `snapshot-2026-05-06/`
- `snapshot-2026-05-06-pre-tuning/`

These are archival reference states. The live build is always:

- `flappy.asm`
- `flappy.bin`
- `flappy.ram`
