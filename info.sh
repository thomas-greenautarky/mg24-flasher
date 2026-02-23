#!/usr/bin/env bash
#
# info.sh — Read device info from XIAO MG24 via built-in CMSIS-DAP
#

set -euo pipefail

TARGET="efr32mg24b220f1536im48"
SWD_FREQ="1000000"

echo "=== Probe Detection ==="
pyocd list --probes

echo ""
echo "=== Target Info ==="
pyocd commander \
    --target "$TARGET" \
    --frequency "$SWD_FREQ" \
    --command "halt" \
    --command "status" \
    --command "reg" \
    --command "read32 0x08000000 8" \
    --command "exit" 2>&1 || {
        echo "Failed to connect. Check udev rules and USB connection."
        exit 1
    }
