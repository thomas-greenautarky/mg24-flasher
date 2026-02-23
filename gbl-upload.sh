#!/usr/bin/env bash
#
# gbl-upload.sh — Upload .gbl firmware via serial using universal-silabs-flasher
#
# This uses the Gecko Bootloader's EZSP/CPC protocol to enter bootloader mode
# and upload .gbl firmware updates over serial.
#
# Prerequisites:
#   - A supported application must already be running (EZSP, CPC, or Spinel)
#   - If the board is running bare firmware (e.g. Blink), use flash.sh instead
#
# Usage:
#   ./gbl-upload.sh <firmware.gbl> [serial_port]
#
# Examples:
#   ./gbl-upload.sh xiao_mg24_zigbee_ncp_8.0.3.0_sw_flow_115200.gbl
#   ./gbl-upload.sh xiao_mg24_bootloader_2.5.3_BL_PC00.gbl /dev/ttyACM0

set -euo pipefail

DEFAULT_PORT="/dev/ttyACM0"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <firmware.gbl> [serial_port]"
    echo ""
    echo "Upload .gbl firmware via serial (requires EZSP/CPC/Spinel app running)"
    echo ""
    echo "Arguments:"
    echo "  firmware.gbl   Path to the .gbl firmware file"
    echo "  serial_port    Serial port (default: ${DEFAULT_PORT})"
    echo ""
    echo "If the board is running bare firmware (Blink, etc), use flash.sh instead."
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

GBL_FILE="$1"
PORT="${2:-$DEFAULT_PORT}"

if [ ! -f "$GBL_FILE" ]; then
    echo -e "${RED}Error: File not found: ${GBL_FILE}${NC}"
    exit 1
fi

if [ ! -c "$PORT" ]; then
    echo -e "${RED}Error: Serial port not found: ${PORT}${NC}"
    echo "Is the XIAO MG24 plugged in? Check: ls /dev/ttyACM*"
    exit 1
fi

if ! command -v universal-silabs-flasher &>/dev/null; then
    echo -e "${RED}Error: universal-silabs-flasher not found${NC}"
    echo "Install with: pipx install universal-silabs-flasher"
    exit 1
fi

echo "=== XIAO MG24 GBL Upload ==="
echo "  File: $GBL_FILE"
echo "  Port: $PORT"
echo ""

# Show GBL metadata
echo -e "${YELLOW}Firmware metadata:${NC}"
universal-silabs-flasher dump-gbl-metadata --firmware "$GBL_FILE" 2>&1 | grep -v "^2026"
echo ""

# Flash
echo -e "${YELLOW}Flashing...${NC}"
universal-silabs-flasher \
    --device "$PORT" \
    flash \
    --firmware "$GBL_FILE" \
    --allow-cross-flashing

echo ""
echo -e "${GREEN}Done!${NC}"

# Verify
echo ""
echo -e "${YELLOW}Verifying...${NC}"
universal-silabs-flasher --device "$PORT" probe 2>&1 | grep -E "Detected|version"
