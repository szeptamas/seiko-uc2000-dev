$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

& "C:\Python313\python.exe" ".\main.py" `
  -rom ".\assets\UC2000.rom" `
  -ext ".\assets\flappy.ram" `
  -face ".\assets\uc2000.svg" `
  -pc "0xC00"
