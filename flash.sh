#!/usr/bin/env bash
#
# flash.sh — Flash firmware to Seeed Studio XIAO MG24 via built-in CMSIS-DAP
#
# Usage:
#   ./flash.sh <firmware.hex|firmware.bin>
#   ./flash.sh Blink_MG24.hex
#   ./flash.sh xiao_mg24_zigbee_ncp_8.0.3.0_sw_flow_115200.gbl
#
# For .bin files, the flash base address 0x08000000 is used automatically.
# For .hex files, addresses are embedded in the file.
# For .gbl (Gecko Bootloader) files, see notes below.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="efr32mg24b220f1536im48"
FLASH_BASE="0x08000000"
SWD_FREQ="1000000"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <firmware_file>"
    echo ""
    echo "Supported formats:"
    echo "  .hex  — Intel HEX (addresses embedded in file)"
    echo "  .bin  — Raw binary (flashed at ${FLASH_BASE})"
    echo "  .gbl  — Gecko Bootloader image (requires bootloader present)"
    echo ""
    echo "Examples:"
    echo "  $0 Blink_MG24.hex"
    echo "  $0 firmware.bin"
    exit 1
}

check_deps() {
    if ! command -v pyocd &>/dev/null; then
        echo -e "${RED}Error: pyocd not found. Install with: pipx install pyocd${NC}"
        exit 1
    fi
}

check_probe() {
    echo -e "${YELLOW}Detecting debug probe...${NC}"
    local probes
    probes=$(pyocd list --probes 2>&1)
    if echo "$probes" | grep -qi "no available"; then
        echo -e "${RED}No debug probe detected!${NC}"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Is the XIAO MG24 plugged in via USB?"
        echo "  2. Install udev rules (run once):"
        echo "       sudo cp ${SCRIPT_DIR}/70-xiao-mg24.rules /etc/udev/rules.d/"
        echo "       sudo udevadm control --reload-rules"
        echo "       sudo udevadm trigger"
        echo "     Then re-plug the device."
        echo "  3. Check: lsusb | grep 2886:0062"
        exit 1
    fi
    echo -e "${GREEN}Probe found:${NC}"
    echo "$probes"
}

check_pack() {
    local installed
    installed=$(pyocd pack find "$TARGET" 2>&1 | grep -i "true" || true)
    if [ -z "$installed" ]; then
        echo -e "${YELLOW}Installing CMSIS-Pack for ${TARGET}...${NC}"
        pyocd pack install "$TARGET"
    fi
}

flash_firmware() {
    local firmware="$1"
    local ext="${firmware##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

    echo -e "${YELLOW}Flashing: ${firmware}${NC}"
    echo -e "${YELLOW}Target:   ${TARGET}${NC}"

    case "$ext" in
        hex)
            pyocd flash \
                --target "$TARGET" \
                --frequency "$SWD_FREQ" \
                --erase sector \
                --format hex \
                "$firmware"
            ;;
        bin)
            pyocd flash \
                --target "$TARGET" \
                --frequency "$SWD_FREQ" \
                --erase sector \
                --base-address "$FLASH_BASE" \
                --format bin \
                "$firmware"
            ;;
        gbl)
            echo -e "${YELLOW}Note: .gbl files are Gecko Bootloader update images.${NC}"
            echo "They are meant to be loaded via the bootloader (UART/OTA), not raw-flashed."
            echo "Attempting raw flash — this will only work if you know what you're doing."
            echo ""
            pyocd flash \
                --target "$TARGET" \
                --frequency "$SWD_FREQ" \
                --erase sector \
                --base-address "$FLASH_BASE" \
                --format bin \
                "$firmware"
            ;;
        *)
            echo -e "${RED}Unsupported file format: .${ext}${NC}"
            echo "Use .hex, .bin, or .gbl"
            exit 1
            ;;
    esac

    echo ""
    echo -e "${GREEN}Flash complete!${NC}"
}

reset_target() {
    echo -e "${YELLOW}Resetting target...${NC}"
    pyocd reset --target "$TARGET" --frequency "$SWD_FREQ"
    echo -e "${GREEN}Target reset. Firmware should be running.${NC}"
}

# --- Main ---

if [ $# -lt 1 ]; then
    usage
fi

FIRMWARE="$1"
if [ ! -f "$FIRMWARE" ]; then
    echo -e "${RED}Error: File not found: ${FIRMWARE}${NC}"
    exit 1
fi

check_deps
check_probe
check_pack
flash_firmware "$FIRMWARE"
reset_target
