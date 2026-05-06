---
name: seiko-uc-2000
description: Use when helping with Seiko UC-2000 programmable wristwatch work: writing or explaining BASIC programs, assembly, machine code, memory maps, keyboard transfer workflows, tooling, or documentation extraction for the watch.
---

# Seiko UC-2000

Use this skill for programming and reverse-engineering work related to the Seiko UC-2000 wristwatch and its keyboard.

## Source Discipline

- Treat project documents as the source of truth.
- Prefer verified information from `docs/original/`, OCR from `docs/ocr/`, and curated notes from `docs/notes/`.
- If a detail is inferred, label it as inferred.
- If a detail is unverified on real hardware, label it as untested.
- Do not invent opcodes, memory addresses, syntax, transfer formats, or limits.

## Reference Loading

Load only the reference file needed for the current task:

- `references/basic.md` - BASIC syntax, commands, program structure, examples, limits.
- `references/assembly.md` - Assembly language conventions, registers, flags, addressing, examples.
- `references/opcodes.md` - Opcode table, byte encodings, instruction timing if known.
- `references/memory-map.md` - RAM, ROM, variables, display, I/O, stack, system areas.
- `references/keyboard-interface.md` - Keyboard behavior, entry workflow, special keys, editing.
- `references/program-transfer.md` - Program entry, storage, transfer, checksum, encoding workflows.
- `references/hardware-notes.md` - CPU, display, battery, connectors, electrical notes.
- `references/source-index.md` - Document inventory and provenance.

## Workflow

1. Identify whether the task is BASIC, assembly, machine code, tooling, or documentation extraction.
2. Read the smallest relevant reference file first.
3. If the reference is incomplete, inspect `docs/original/`, `docs/ocr/`, and `docs/notes/`.
4. When writing a program, include assumptions and target input method.
5. When creating tooling, add small fixtures from known-good examples before broad automation.
6. When updating references, include source provenance and tested status.

## Output Preferences

- For BASIC programs, provide a numbered listing if the watch requires line numbers.
- For assembly, include labels, comments, and a byte listing only when the encoding is known.
- For machine code, include addresses, bytes, and a concise explanation.
- For uncertainty, use `TODO(source)` rather than guessing.
