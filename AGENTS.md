# Repository instructions

## Tang Primer 20K programming safety

- Always detect the connected FPGA before programming:

  ```sh
  openFPGALoader --detect
  ```

- For volatile SRAM testing, use this exact command and **never add `--reset`**:

  ```sh
  openFPGALoader --write-sram -b tangprimer20k impl/pnr/project.fs
  ```

- `openFPGALoader --reset` resets the FPGA **after** the operation. After an
  SRAM load this discards the newly loaded configuration and reloads the old
  bitstream from Flash, making hardware appear unchanged even though the load
  log reached 100% and printed `DONE`.
- Do not use `--reset` together with `--write-sram` in this repository.
- Pressing S0 is safe after an SRAM load because S0 is implemented as the
  design's active-low reset input on T10; it resets the Z80 SoC without
  intentionally reconfiguring the FPGA.
- Flash programming is persistent and is a separate, consequential operation.
  Do not use `--write-flash` unless the user explicitly asks for persistent
  Flash programming.
- A 100%/`DONE` transfer log confirms only the transfer. Confirm the expected
  LED or audio behavior on the physical board before reporting hardware
  success.

## Current hardware debug convention

- Z80 I/O port `B0h`, bits 5 through 0, drives Dock LEDs 5 through 0.
- The diagnostic firmware briefly shows LED5, LED4, LED3, then LED2 as it
  passes boot, RAM test, RAM application entry, and PSG initialization.
- LED1 and LED0 alternating continuously confirms execution of the RAM-resident
  Z80 main loop.
