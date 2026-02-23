# MG24 Flasher

Linux toolchain for flashing the [Seeed Studio XIAO MG24](https://wiki.seeedstudio.com/xiao_mg24_getting_started/) (Silicon Labs EFR32MG24).

No external debug probe needed -- the XIAO MG24 has a built-in CMSIS-DAP interface over USB.

## Why this exists

The official [Seeed Debug Mate guide](https://wiki.seeedstudio.com/xiao_debug_mate_debug/) provides a custom OpenOCD for flashing the MG24, but the `XIAO_MG24_Mac_Linux_OpenOCD-v0.12.0` binary in the download package is **macOS-only** (Mach-O x86_64). The standard [xpack-openocd](https://github.com/xpack-dev-tools/openocd-xpack) lacks the `efm32s2` flash driver required for Series 2 Silicon Labs chips.

This project uses **[pyocd](https://pyocd.io/)** for SWD flashing and **[universal-silabs-flasher](https://github.com/NabuCasa/universal-silabs-flasher)** for serial `.gbl` firmware updates instead. It also includes a workaround for a bug in the official Silicon Labs CMSIS-Pack.

## Hardware

| | |
|---|---|
| **Board** | Seeed Studio XIAO MG24 (Sense) |
| **Chip** | Silicon Labs EFR32MG24 -- ARM Cortex-M33 @ 78MHz |
| **Flash** | 1536KB (base `0x08000000`) |
| **RAM** | 256KB (base `0x20000000`) |
| **Debug** | Built-in CMSIS-DAP via USB |
| **USB ID** | `2886:0062` |

## Quick start

```bash
git clone https://github.com/thomas-greenautarky/mg24-flasher.git
cd mg24-flasher
./setup.sh                   # install pyocd, CMSIS-Pack, udev rules
./flash.sh Blink_MG24.hex   # flash the blink example via SWD
```

## Two flashing methods

### 1. SWD via pyocd -- `flash.sh`

Flashes `.hex` or `.bin` files directly to flash memory through the built-in CMSIS-DAP debug probe. Works regardless of what firmware is running -- even on a bricked board.

```bash
./flash.sh Blink_MG24.hex
./flash.sh firmware.bin
```

### 2. Serial via universal-silabs-flasher -- `gbl-upload.sh`

Uploads `.gbl` (Gecko Bootloader) images over serial. **Requires** a compatible application already running on the chip (EZSP, CPC, or Spinel). The tool talks to the running app, reboots it into the Gecko Bootloader, and transfers the `.gbl` via XMODEM.

```bash
./gbl-upload.sh xiao_mg24_zigbee_ncp_8.0.3.0_sw_flow_115200.gbl
```

> If the board is running bare firmware (e.g. Blink), `.gbl` upload won't work. Use `flash.sh` instead.

## Setup

### Prerequisites

```bash
sudo apt install pipx lrzsz picocom
pipx install pyocd
pipx install universal-silabs-flasher
```

### Install CMSIS-Pack and apply fix

```bash
pyocd pack install efr32mg24b220f1536im48
./fix-pack.sh
```

### Install udev rules

```bash
./setup-udev.sh    # requires sudo
```

Then **re-plug** the XIAO MG24.

### Verify

```bash
pyocd list --probes
./info.sh
```

Or just run `./setup.sh` which does all of the above in one go.

## Flash memory layout

```
0x08000000 +-----------------+
           | Gecko Bootloader| (24KB)
0x08006000 +-----------------+
           | Application     | (Zigbee NCP, Blink, etc.)
           |                 |
0x08180000 +-----------------+ (end of 1536KB flash)
```

The Gecko Bootloader occupies the first 24KB. Application firmware (`.hex` files like `Blink_MG24.hex`) starts at `0x08006000`. The `flash.sh` script uses sector erase to preserve the bootloader when flashing.

## Flashing Zigbee NCP from scratch

The Zigbee NCP firmware is distributed as a `.gbl` file, which is a Gecko Bootloader container format. Serial `.gbl` upload only works when a compatible app (EZSP/CPC) is already running.

To flash the Zigbee NCP onto a board running non-EZSP firmware (like Blink), use the pre-extracted raw binary via SWD:

```bash
./flash.sh xiao_mg24_zigbee_ncp_8.0.3.0_sw_flow_115200.bin
```

Then verify:

```bash
universal-silabs-flasher --device /dev/ttyACM0 probe
# Expected: Detected ApplicationType.EZSP, version '8.0.3.0 build 581'
```

Once EZSP is running, future updates can use `./gbl-upload.sh`.

## Included firmware

| File | Description | Method |
|------|-------------|--------|
| `Blink_MG24.hex` | LED blink example | `flash.sh` |
| `xiao_mg24_zigbee_ncp_8.0.3.0_sw_flow_115200.gbl` | Zigbee NCP (EZSP, 115200, sw flow) | `gbl-upload.sh` |
| `xiao_mg24_zigbee_ncp_8.0.3.0_sw_flow_115200.bin` | Zigbee NCP (extracted raw binary) | `flash.sh` |
| `xiao_mg24_bootloader_2.5.3_BL_PC00.gbl` | Gecko Bootloader v2.5.3 | `gbl-upload.sh` |

## Scripts

| Script | Description |
|--------|-------------|
| `setup.sh` | One-time setup: pyocd, CMSIS-Pack, pack fix, udev rules |
| `flash.sh <file>` | Flash `.hex`/`.bin` via SWD (CMSIS-DAP) |
| `gbl-upload.sh <file>` | Upload `.gbl` via serial (needs EZSP/CPC running) |
| `info.sh` | Read device info, registers, and flash content via SWD |
| `fix-pack.sh` | Patch broken CMSIS-Pack (run once after pack install) |
| `setup-udev.sh` | Install udev rules for non-root access (run once) |

## Known issues and workarounds

### Silicon Labs CMSIS-Pack bug

The official CMSIS-Pack (`SiliconLabs.GeckoPlatform_EFR32MG24_DFP v2025.6.2`) ships with **all memory regions set to zero** for every EFR32MG24 device:

```xml
<memory id="IROM1" start="0x00000000" size="0x00000000" />
<memory id="IRAM1" start="0x00000000" size="0x00000000" />
```

This causes pyocd to crash with `"Memory regions must have a non-zero length"`. The `fix-pack.sh` script patches the PDSC inside the `.pack` ZIP and the `index.json` cache with the correct values.

### Chip erase timeout

The MG24's chip erase via pyocd times out. All scripts use `--erase sector` instead, which works reliably.

### XIAO MG24 bootloader has no UART menu

Unlike typical Gecko Bootloader configurations, the XIAO MG24's stock bootloader does **not** expose a UART XMODEM menu. You cannot enter bootloader mode by sending a carriage return over serial. The bootloader is a storage bootloader designed for Arduino IDE uploads. Serial `.gbl` updates work only through `universal-silabs-flasher`, which uses the EZSP/CPC protocol to trigger a reboot into the bootloader.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `Memory regions must have a non-zero length` | Run `./fix-pack.sh` |
| `No available debug probes` | Run `./setup-udev.sh`, then re-plug the board |
| `flash erase all timed out` | Scripts use sector erase by default |
| LED not responding after flash | Unplug and re-plug USB for a power cycle |
| `Failed to probe running application type` | Board is running non-EZSP firmware -- use `flash.sh` instead of `gbl-upload.sh` |

### Serial console

```bash
picocom -b 115200 /dev/ttyACM0
```

## References

- [Seeed XIAO MG24 Getting Started](https://wiki.seeedstudio.com/xiao_mg24_getting_started/)
- [Seeed Debug Mate Guide](https://wiki.seeedstudio.com/xiao_debug_mate_debug/)
- [pyocd](https://pyocd.io/)
- [universal-silabs-flasher](https://github.com/NabuCasa/universal-silabs-flasher)
- [Silicon Labs Gecko Bootloader User Guide (GSDK 4.0+)](https://www.silabs.com/documents/public/user-guides/ug489-gecko-bootloader-user-guide-gsdk-4.pdf)
- [Silicon Labs EFR32MG24](https://www.silabs.com/wireless/zigbee/efr32mg24-series-2-socs)

## Background: how this project came together

This toolchain was built by working through a chain of problems, each requiring a different workaround.

### Attempt 1: OpenOCD (Seeed wiki) -- failed on Linux

The [Seeed Debug Mate guide](https://wiki.seeedstudio.com/xiao_debug_mate_debug/) provides a custom OpenOCD package (`XIAO_MG24_Mac_Linux_OpenOCD-v0.12.0`) with the `efm32s2` flash driver needed for Series 2 Silicon Labs chips. The custom target config `efm32s2_g23.cfg` sets the correct flash base address (`0x08000000`) and uses the `efm32s2` flash bank driver.

**Problem:** The Linux/Mac binary in the download is actually a **macOS Mach-O x86_64 executable** -- it simply doesn't run on Linux. The standard [xpack-openocd](https://github.com/xpack-dev-tools/openocd-xpack) only includes the `efm32` driver (Series 0/1), not `efm32s2` (Series 2).

### Attempt 2: pyocd with CMSIS-Pack -- broken pack from Silicon Labs

Pivoted to [pyocd](https://pyocd.io/), which supports the MG24 via CMSIS-Packs. Installed the pack:

```bash
pyocd pack install efr32mg24b220f1536im48
```

**Problem:** Every connection attempt crashed with `"Memory regions must have a non-zero length"`. Investigation revealed the **Silicon Labs CMSIS-Pack (`GeckoPlatform_EFR32MG24_DFP v2025.6.2`) has a bug** -- all 41 EFR32MG24 device entries have zero-length memory regions:

```xml
<memory id="IROM1" start="0x00000000" size="0x00000000" />
<memory id="IRAM1" start="0x00000000" size="0x00000000" />
```

**Fix:** Patched the PDSC file inside the `.pack` ZIP with correct values (flash at `0x08000000` / 1536KB, RAM at `0x20000000` / 256KB). Initially patched only the loose `.pdsc` and `index.json` -- didn't work because pyocd reads from the `.pack` ZIP directly. Had to patch the PDSC **inside the ZIP** to fix it. This is what `fix-pack.sh` does.

### Attempt 3: SWD connection -- worked with workarounds

After the pack fix, pyocd could connect to the MG24 via CMSIS-DAP. Two additional issues:

- **Chip erase timed out** after 240 seconds. Switched to **sector erase** (`--erase sector`), which completes in ~28 seconds.
- **udev rules** were needed -- the CMSIS-DAP HID interface (`/dev/hidraw*`) was root-only (`crw-------`). Added udev rules for USB ID `2886:0062`.

### Flashing Blink_MG24.hex -- worked

Flashed successfully at 33.6 kB/s. The `.hex` file starts at `0x08006000` (not `0x08000000`) because the first 24KB is reserved for the Gecko Bootloader. The LED didn't blink initially -- needed a `pyocd commander` reset-halt-go cycle or a USB power cycle to properly restart.

### Attempt 4: .gbl upload over serial -- bootloader has no UART mode

Tried three approaches to upload `.gbl` files via serial:

1. **UART XMODEM** (the standard Gecko Bootloader method) -- Sent carriage returns to `/dev/ttyACM0` at 115200 baud after reset. **No bootloader menu appeared.** The XIAO MG24's stock Gecko Bootloader doesn't have UART communication enabled -- it's configured as a storage bootloader for Arduino IDE.

2. **universal-silabs-flasher with baudrate reset** -- The tool cycles through baud rates to trigger bootloader mode. **Failed** because the Blink firmware doesn't speak any recognized protocol (EZSP, CPC, Spinel), so the tool can't establish communication to trigger a reboot.

3. **pyocd reset + immediate serial probe** -- Reset via SWD, then immediately tried to catch the bootloader over serial. **Failed** -- the bootloader jumps to the app too fast and doesn't listen on UART.

### Solution: extract binary from .gbl, flash via SWD

The `.gbl` format is a Gecko Bootloader container with (in this case) raw program data at specific flash addresses. Parsed the GBL file structure, extracted the raw binary data for the Zigbee NCP firmware, and saved it as a `.bin` file with the correct base address (`0x08006000`).

Flashed the extracted binary via pyocd/SWD. After reset, `universal-silabs-flasher` detected **EZSP 8.0.3.0 build 581** running at 115200 baud. With the Zigbee NCP running, future `.gbl` updates now work over serial via `./gbl-upload.sh`.

### Summary

| Approach | Result | Notes |
|----------|--------|-------|
| Seeed custom OpenOCD | Failed | macOS binary, doesn't run on Linux |
| xpack-openocd | Failed | Missing `efm32s2` flash driver |
| pyocd + CMSIS-Pack | Failed initially | Silicon Labs pack has zero-length memory bug |
| pyocd + patched pack | **Works** | `fix-pack.sh` patches the `.pack` ZIP |
| SWD flash `.hex`/`.bin` | **Works** | Sector erase at 1MHz, ~33 kB/s |
| UART XMODEM bootloader | Failed | Not enabled on XIAO MG24 |
| universal-silabs-flasher `.gbl` | **Works** | Only when EZSP/CPC app is already running |
| Extract `.bin` from `.gbl` + SWD | **Works** | For initial Zigbee NCP install from scratch |

## License

Scripts and documentation are provided as-is. Firmware files are from Seeed Studio / Silicon Labs / NabuCasa.
