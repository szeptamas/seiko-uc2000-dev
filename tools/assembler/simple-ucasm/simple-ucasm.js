#!/usr/bin/env node
const fs = require("fs");
const path = require("path");

const START_ADDR = 0x1800;

const REG = {
  B0: 0, B1: 1, B2: 2, B3: 3,
  RA0: 0, RA1: 1, RA2: 2, RA3: 3, RA4: 4, RA5: 5, RA6: 6, RA7: 7,
  RB0: 8, RB1: 9, RB2: 10, RB3: 11, RB4: 12, RB5: 13, RB6: 14, RB7: 15,
  RC0: 16, RC1: 17, RC2: 18, RC3: 19, RC4: 20, RC5: 21, RC6: 22, RC7: 23,
  RD0: 24, RD1: 25, RD2: 26, RD3: 27, RD4: 28, RD5: 29, RD6: 30, RD7: 31,
};
for (let i = 0; i < 16; i++) REG[`SR${i}`] = i;

const BUILTIN_DEFS = {
  OS_CLRCB: 0x8F2,
  OS_PRINT0: 0xBD0,
};

function usage() {
  console.error("Usage: node simple-ucasm.js -o output.bin input.asm");
  process.exit(1);
}

let outFile = null;
let inFile = null;
for (let i = 2; i < process.argv.length; i++) {
  if (process.argv[i] === "-o") outFile = process.argv[++i];
  else inFile = process.argv[i];
}
if (!outFile || !inFile) usage();

function stripComment(line) {
  let inQuote = false;
  for (let i = 0; i < line.length; i++) {
    if (line[i] === "'") inQuote = !inQuote;
    if (!inQuote && line[i] === ";") return line.slice(0, i);
  }
  return line;
}

const source = fs.readFileSync(inFile, "utf8").split(/\r?\n/);
const defs = { ...REG, ...BUILTIN_DEFS };
const labels = {};
const lines = [];

function splitArgs(text) {
  const args = [];
  let cur = "";
  let inQuote = false;
  for (const ch of text) {
    if (ch === "'") inQuote = !inQuote;
    if (ch === "," && !inQuote) {
      args.push(cur.trim());
      cur = "";
    } else {
      cur += ch;
    }
  }
  if (cur.trim()) args.push(cur.trim());
  return args;
}

function evalExpr(expr, pc = 0) {
  let out = expr.trim();
  out = out.replace(/\$PC/g, String(pc));
  out = out.replace(/'([^']*)'/g, (_, s) => {
    if (s.length !== 1) throw new Error(`Only single-character literals are supported: '${s}'`);
    return String(s.charCodeAt(0));
  });
  out = out.replace(/\b[A-Za-z_][A-Za-z0-9_]*\b/g, (name) => {
    if (Object.prototype.hasOwnProperty.call(defs, name)) return String(defs[name]);
    if (Object.prototype.hasOwnProperty.call(labels, name)) return String(labels[name]);
    return name;
  });
  if (!/^[0-9xa-fA-FbB+\-*/%&|^<>() \t]+$/.test(out)) {
    throw new Error(`Unknown symbol or unsafe expression: ${expr}`);
  }
  return Function(`"use strict"; return (${out});`)() | 0;
}

function define(name, expr) {
  defs[name] = evalExpr(expr);
}

function cleanedLines() {
  for (let lineNo = 0; lineNo < source.length; lineNo++) {
    let text = stripComment(source[lineNo]).trim();
    if (!text) continue;
    const def = text.match(/^##define\s+([A-Za-z_][A-Za-z0-9_]*)\s+(.+)$/);
    if (def) {
      define(def[1], def[2]);
      continue;
    }
    lines.push({ lineNo: lineNo + 1, text });
  }
}

function instructionSize(text, pc) {
  const lower = text.toLowerCase();
  if (lower.startsWith("db ")) return splitArgs(text.slice(3)).length;
  return (pc % 2) + 2;
}

function parseLabels() {
  let pc = 0;
  for (const line of lines) {
    let text = line.text;
    const label = text.match(/^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$/);
    if (label) {
      labels[label[1]] = pc;
      text = label[2].trim();
      line.text = text;
      if (!text) continue;
    }
    pc += instructionSize(text, pc);
  }
}

const words = [];
let pc = 0;
function emitByte(v) {
  if (v < 0 || v > 0xff) throw new Error(`Byte out of range: ${v}`);
  words.push(v & 0xff);
  pc++;
}
function alignEven() {
  if (pc % 2) emitByte(0);
}
function emitWord(w) {
  alignEven();
  words.push((w >> 8) & 0xff, w & 0xff);
  pc += 2;
}
function chk(v, bits, what) {
  if (v < 0 || v >= (1 << bits)) throw new Error(`${what} out of range for ${bits} bits: ${v}`);
}
function pcFrom(target) {
  return (target + START_ADDR) / 2;
}
function rel5(target) {
  let tmp = target;
  if (target > 31) tmp = (target - pc) / 2 - 1;
  chk(tmp, 5, "relative branch");
  return tmp & 0x1f;
}

function op0(op) { emitWord(op); }
function op1_23(op, r) { chk(r, 2, "register page"); emitWord(op | (r << 3)); }
function op1_55(op, r) { chk(r, 5, "register"); emitWord(op | (r << 5)); }
function op1_8(op, r) {
  chk(r, 8, "immediate");
  emitWord(op | ((r & 0xf0) << 2) | ((r & 0x08) << 2) | (r & 0x07));
}
function op2(op, r1, r2) { chk(r1, 5, "register"); chk(r2, 5, "register"); emitWord(op | (r1 << 5) | r2); }
function op2_541(op, r, i) { chk(r, 5, "register"); chk(i, 4, "immediate"); emitWord(op | (r << 5) | (i << 1)); }
function op2_425(op, d, i) { chk(d, 5, "register"); chk(i, 4, "immediate"); emitWord(op | (i << 6) | d); }
function op2_523(op, r, mode, i) { chk(r, 5, "register"); chk(i, 3, "bit"); emitWord(op | (r << 5) | (mode << 3) | i); }
function opJ10(op, target) { const p = target & 0x3ff; chk(p, 10, "jump target"); emitWord(op | p); }
function opJ12(op, target) { const p = target; chk(p, 12, "jump target"); emitWord(op | p); }
function opJ3(op, r, i, target) { chk(r, 5, "register"); chk(i, 2, "compare immediate"); emitWord(op | (i << 10) | (r << 5) | rel5(target)); }

function assembleLine(line) {
  const text = line.text;
  if (!text) return;
  const m = text.match(/^([A-Za-z]+)\s*(.*)$/);
  if (!m) throw new Error(`Line ${line.lineNo}: cannot parse '${text}'`);
  const ins = m[1].toUpperCase();
  const rawArgs = splitArgs(m[2] || "");
  const args = rawArgs.map((a) => evalExpr(a, pc));
  const isBareLabel = (a) => /^[A-Za-z_][A-Za-z0-9_]*$/.test(a.trim()) &&
    Object.prototype.hasOwnProperty.call(labels, a.trim());
  const jumpArg = (index) => isBareLabel(rawArgs[index]) ? pcFrom(labels[rawArgs[index].trim()]) : args[index];

  try {
    switch (ins) {
      case "DB": for (const b of args) emitByte(b); break;
      case "JMP": opJ12(0xC000, jumpArg(0)); break;
      case "CALL": opJ12(0xA000, jumpArg(0)); break;
      case "RET": op0(0xB000); break;
      case "JZ": opJ10(0xD000, jumpArg(0)); break;
      case "JNZ": opJ10(0xD400, jumpArg(0)); break;
      case "JC": opJ10(0xD800, jumpArg(0)); break;
      case "JNC": opJ10(0xDC00, jumpArg(0)); break;
      case "CPJR": opJ3(0xF000, args[0], args[1], args[2]); break;
      case "BTJR": opJ3(0xE000, args[0], args[1], args[2]); break;
      case "LCRB": op1_23(0x3C00, args[0]); break;
      case "LARB": op1_23(0x3E00, args[0]); break;
      case "ANDI": op2_541(0x4000, args[0], args[1]); break;
      case "ORI": op2_541(0x4400, args[0], args[1]); break;
      case "XORI": op2_541(0x4800, args[0], args[1]); break;
      case "ADD": op2(0x0000, args[0], args[1]); break;
      case "ADM": op2(0x2000, args[0], args[1]); break;
      case "CMP": op2(0x3000, args[0], args[1]); break;
      case "IN": op2(0x5400, args[0], args[1]); break;
      case "MOV": op2(0x8000, args[0], args[1]); break;
      case "LDI": op2_541(0x8800, args[0], args[1]); break;
      case "CPI": op2_541(0x3800, args[0], args[1]); break;
      case "INC": op2_523(0x4C00, args[0], 0, args[1]); break;
      case "INCB": op2_523(0x4C00, args[0], 1, args[1]); break;
      case "DEC": op2_523(0x4C00, args[0], 2, args[1]); break;
      case "DECB": op2_523(0x4C00, args[0], 3, args[1]); break;
      case "OUTI": op2_425(0x5C00, args[0], args[1]); break;
      case "PSAM": op2_523(0x6000, args[0], 0, args[1]); break;
      case "STSM": op2_523(0x6400, args[0], 0, args[1]); break;
      case "LDSM": op2_523(0x6400, args[0], 1, args[1]); break;
      case "PLAI": op1_8(0x7800, args[0]); break;
      case "PSAI": opJ10(0x7000, args[0]); break;
      case "STLS": op0(0x7C00); break;
      case "STLSA": op1_8(0x7C08, args[0]); break;
      case "STLI": op1_8(0x7C10, args[0]); break;
      case "STLIA": op1_8(0x7C18, args[0]); break;
      case "STL": op1_55(0x6C00, args[0]); break;
      default: throw new Error(`Unsupported instruction '${ins}'`);
    }
  } catch (err) {
    throw new Error(`Line ${line.lineNo}: ${err.message}`);
  }
}

cleanedLines();
parseLabels();
for (const line of lines) assembleLine(line);

fs.mkdirSync(path.dirname(outFile), { recursive: true });
fs.writeFileSync(outFile, Buffer.from(words));
console.log(`Translate OK!`);
console.log(`Result file size ${words.length}B`);
