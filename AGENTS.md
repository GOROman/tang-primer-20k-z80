# Repository instructions

## Tang Primer 20K programming safety

## Default remote verification and build flow

- Run the full SoC simulation and Gowin synthesis/place-and-route on the Mac
  Studio over SSH. Do not run these heavy jobs locally unless the remote host
  is unavailable and the user explicitly agrees to the fallback.
- The default remote host is `mac-studio.local`, and the disposable work tree
  is `/tmp/tang-primer-20k-z80-remote`.
- Use `make remote-sim` for the full simulation and `make remote-build` for the
  FPGA build. A successful remote build must fetch `impl/pnr/project.fs` and
  `impl/pnr/project.rpt.txt` back into this checkout.
- The normal end-to-end command is `make remote-deploy`: remote simulation,
  remote build, local artifact recovery, local FPGA detection, then volatile
  SRAM programming.
- Keep the FPGA programmer local because the Tang Primer 20K is connected to
  this MacBook. Never attempt FPGA programming on the Mac Studio.
- Record the recovered bitstream SHA-256 before or after programming, and keep
  simulation/build/transfer/hardware-observation results distinct.

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
