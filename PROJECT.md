# Seiko UC-2000

Project workspace for learning, documenting, and programming the Seiko UC-2000 programmable wristwatch and its keyboard.

## Structure

- `docs/original/` - Original scans, PDFs, manuals, photos, and source documents.
- `docs/ocr/` - OCR text extracted from original documents.
- `docs/notes/` - Human notes, corrections, translation notes, and source provenance.
- `examples/basic/` - Known-good BASIC examples from manuals or experiments.
- `examples/assembly/` - Known-good assembly examples.
- `examples/machine-code/` - Raw machine-code examples and byte listings.
- `programs/basic/` - New BASIC programs for the watch.
- `programs/asm/` - New assembly or machine-code programs for the watch.
- `tools/assembler/` - Future assembler or assembly helper tools.
- `tools/tokenizer/` - Future BASIC tokenizer or transfer-format tools.
- `tools/checksum/` - Future checksum, validation, or byte conversion tools.
- `tools/emulator-or-simulator/` - Future simulation, disassembly, or test tools.
- `tools/disassembler/` - Disassemblers and related analysis helpers.
- `tools/transmitter/` - Hardware and software used to transfer programs to the watch.
- `tools/keyboard-emulator/` - Keyboard emulation tools.
- `tools/firmware/` - Firmware images and source related to UC-2000 tooling.
- `skill/seiko-uc-2000/` - Codex skill draft for this project.

## Imported Sources

- `azya52` - Local copy imported from `C:\Users\szept\OneDrive\Dokumentumok\!Magán\!Technikai dolgok\Seiko UC-2000\azya52`.
  - Manuals and scans: `docs/original/azya52/`
  - Assembly programs and disassemblies: `examples/assembly/azya52/`
  - Binary programs and ROM extracts: `examples/machine-code/azya52/`
  - Assembler, disassembler, transmitter, keyboard emulator, and firmware tools: `tools/`

## Working Rule

Do not treat undocumented behavior as fact. When adding technical reference material, include the document source, page or section when available, and whether the information has been tested on real hardware.
