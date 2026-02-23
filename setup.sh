#!/usr/bin/env bash
#
# setup.sh — One-time setup for XIAO MG24 flashing toolchain
#
# What this does:
#   1. Checks/installs pyocd via pipx
#   2. Installs the EFR32MG24 CMSIS-Pack
#   3. Patches the broken pack (Silicon Labs bug: zero-length memory regions)
#   4. Installs udev rules for CMSIS-DAP access (requires sudo)
#   5. Verifies the probe connection
#
# Usage:
#   ./setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="efr32mg24b220f1536im48"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== XIAO MG24 Toolchain Setup ==="
echo ""

# Step 1: pyocd
echo -e "${YELLOW}[1/5] Checking pyocd...${NC}"
if command -v pyocd &>/dev/null; then
    echo -e "${GREEN}  pyocd $(pyocd --version) already installed${NC}"
else
    echo "  Installing pyocd..."
    pipx install pyocd
    echo -e "${GREEN}  pyocd installed${NC}"
fi

# Step 2: CMSIS-Pack
echo -e "${YELLOW}[2/5] Checking CMSIS-Pack...${NC}"
if pyocd pack find "$TARGET" 2>&1 | grep -qi "true"; then
    echo -e "${GREEN}  Pack already installed${NC}"
else
    echo "  Installing pack..."
    pyocd pack install "$TARGET"
    echo -e "${GREEN}  Pack installed${NC}"
fi

# Step 3: Fix pack
echo -e "${YELLOW}[3/5] Patching CMSIS-Pack (Silicon Labs zero-length memory bug)...${NC}"
"$SCRIPT_DIR/fix-pack.sh"

# Step 4: udev rules
echo -e "${YELLOW}[4/5] Installing udev rules...${NC}"
"$SCRIPT_DIR/setup-udev.sh"

# Step 5: Verify
echo ""
echo -e "${YELLOW}[5/5] Verifying probe connection...${NC}"
echo "  (If this fails, re-plug the XIAO MG24 and run: pyocd list --probes)"
echo ""
pyocd list --probes 2>&1 || true

echo ""
echo -e "${GREEN}=== Setup complete ===${NC}"
echo ""
echo "Next steps:"
echo "  Flash firmware:  $SCRIPT_DIR/flash.sh <firmware.hex>"
echo "  Device info:     $SCRIPT_DIR/info.sh"
echo "  Example:         $SCRIPT_DIR/flash.sh $SCRIPT_DIR/Blink_MG24.hex"
