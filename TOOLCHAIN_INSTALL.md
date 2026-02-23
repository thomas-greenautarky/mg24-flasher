# XIAO MG24 Toolchain Installation Guide

Toolchain setup for flashing the Seeed Studio XIAO MG24 (EFR32MG24) on Linux.

## Hardware

- **Board**: Seeed Studio XIAO MG24 (Sense)
- **Chip**: Silicon Labs EFR32MG24 (Cortex-M33, 1536KB flash, 256KB RAM)
- **Debug**: Built-in CMSIS-DAP via USB (no external debug probe needed)
- **USB ID**: `2886:0062`
- **Flash base**: `0x08000000` (bootloader), `0x08006000` (application)

## Quick Start

```bash
cd ~/workspace/MG24
./setup.sh                   # one-time setup
./flash.sh Blink_MG24.hex   # flash via SWD
```

## Two Flashing Methods

### 1. SWD via pyocd (`flash.sh`)

Flashes `.hex` or `.bin` files directly to flash memory via the built-in CMSIS-DAP
debug probe. Works with any firmware state — even a bricked board.

```bash
./flash.sh Blink_MG24.hex
./flash.sh firmware.bin
```

### 2. Serial via universal-silabs-flasher (`gbl-upload.sh`)

Uploads `.gbl` (Gecko Bootloader) update images over serial. **Requires** a
compatible application already running (EZSP, CPC, or Spinel). The tool talks to
the running app, reboots into the Gecko Bootloader, and transfers the `.gbl` via
XMODEM.

```bash
./gbl-upload.sh xiao_mg24_zigbee_ncp_8.0.3.0_sw_flow_115200.gbl
```

If the board is running bare firmware (e.g. Blink), `.gbl` upload won't work — use
`flash.sh` instead.

## Setup

### 1. Install tools

```bash
sudo apt install pipx lrzsz picocom
pipx install pyocd
pipx install universal-silabs-flasher
```

### 2. Install CMSIS-Pack and fix it

```bash
pyocd pack install efr32mg24b220f1536im48
./fix-pack.sh    # patches broken Silicon Labs pack (see below)
```

### 3. Install udev rules

```bash
./setup-udev.sh    # requires sudo, then re-plug the board
```

### 4. Verify

```bash
pyocd list --probes
./info.sh
```

## CMSIS-Pack Bug

The Silicon Labs CMSIS-Pack (`GeckoPlatform_EFR32MG24_DFP v2025.6.2`) has a bug:
all EFR32MG24 device entries have zero-length memory regions in the PDSC:

```xml
<memory id="IROM1" start="0x00000000" size="0x00000000" />
```

This causes pyocd to crash with `"Memory regions must have a non-zero length"`.
The `fix-pack.sh` script patches the `.pack` ZIP with correct values:
- Flash: `0x08000000`, 1536KB
- RAM: `0x20000000`, 256KB

## Why not OpenOCD?

The Seeed [Debug Mate wiki](https://wiki.seeedstudio.com/xiao_debug_mate_debug/)
provides a custom OpenOCD with the `efm32s2` flash driver. However, the
`XIAO_MG24_Mac_Linux_OpenOCD-v0.12.0` binary in the download is **macOS-only**
(Mach-O x86_64). The standard xpack-openocd lacks the `efm32s2` driver.

## Firmware Files

| File | Description | Flash method |
|------|-------------|--------------|
| `Blink_MG24.hex` | Blink LED example | `flash.sh` (SWD) |
| `xiao_mg24_zigbee_ncp_8.0.3.0_sw_flow_115200.gbl` | Zigbee NCP (EZSP, 115200 baud, sw flow) | `gbl-upload.sh` or extract+`flash.sh` |
| `xiao_mg24_zigbee_ncp_8.0.3.0_sw_flow_115200.bin` | Zigbee NCP (extracted raw binary) | `flash.sh` at `0x08006000` |
| `xiao_mg24_bootloader_2.5.3_BL_PC00.gbl` | Gecko Bootloader update | `gbl-upload.sh` |

### Flash memory layout

```
0x08000000 +-----------------+
           | Gecko Bootloader| (24KB)
0x08006000 +-----------------+
           | Application     | (Zigbee NCP, Blink, etc.)
           |                 |
0x08180000 +-----------------+ (end of 1536KB flash)
```

### Flashing Zigbee NCP from scratch

If the board is running non-EZSP firmware (like Blink), `.gbl` serial upload
won't work. Flash the extracted `.bin` via SWD instead:

```bash
pyocd flash --target efr32mg24b220f1536im48 --frequency 1000000 \
  --erase sector --base-address 0x08006000 --format bin \
  xiao_mg24_zigbee_ncp_8.0.3.0_sw_flow_115200.bin
pyocd reset --target efr32mg24b220f1536im48 --frequency 1000000
```

Then verify: `universal-silabs-flasher --device /dev/ttyACM0 probe`

## Scripts

| Script | Description |
|--------|-------------|
| `setup.sh` | Full setup: pyocd, pack, fix, udev, verify |
| `flash.sh <file>` | Flash .hex/.bin via SWD (CMSIS-DAP) |
| `gbl-upload.sh <file>` | Upload .gbl via serial (needs EZSP/CPC running) |
| `info.sh` | Read device info via SWD |
| `fix-pack.sh` | Patch broken CMSIS-Pack (run once) |
| `setup-udev.sh` | Install udev rules (run once, needs sudo) |

## Troubleshooting

| Error | Fix |
|-------|-----|
| `Memory regions must have a non-zero length` | Run `./fix-pack.sh` |
| `No available debug probes` | Run `./setup-udev.sh`, re-plug board |
| `flash erase all timed out` | Use `--erase sector` (default in flash.sh) |
| LED not blinking after flash | Unplug/re-plug USB for power cycle |
| `Failed to probe running application type` | Board running non-EZSP firmware, use `flash.sh` |
| Serial console | `picocom -b 115200 /dev/ttyACM0` |

## References

- [Seeed XIAO MG24 Getting Started](https://wiki.seeedstudio.com/xiao_mg24_getting_started/)
- [Seeed Debug Mate Guide](https://wiki.seeedstudio.com/xiao_debug_mate_debug/)
- [pyocd Documentation](https://pyocd.io/)
- [universal-silabs-flasher](https://github.com/NabuCasa/universal-silabs-flasher)
- [Silicon Labs Gecko Bootloader User Guide](https://www.silabs.com/documents/public/user-guides/ug489-gecko-bootloader-user-guide-gsdk-4.pdf)
