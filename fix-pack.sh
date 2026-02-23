#!/usr/bin/env bash
#
# fix-pack.sh — Fix broken Silicon Labs EFR32MG24 CMSIS-Pack for pyocd
#
# The SiliconLabs.GeckoPlatform_EFR32MG24_DFP v2025.6.2 pack has a bug:
# all memory regions have start=0x00000000 size=0x00000000, causing pyocd
# to fail with "Memory regions must have a non-zero length."
#
# This script patches the PDSC inside the .pack ZIP with correct values:
#   Flash: 0x08000000 (size varies by part: 1536KB/1024KB/768KB)
#   RAM:   0x20000000, 256KB
#
# Run this after: pyocd pack install efr32mg24b220f1536im48

set -euo pipefail

PACK_DIR="$HOME/.local/share/cmsis-pack-manager/SiliconLabs/GeckoPlatform_EFR32MG24_DFP"
PACK_FILE="$PACK_DIR/2025.6.2.pack"
INDEX_FILE="$HOME/.local/share/cmsis-pack-manager/index.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ ! -f "$PACK_FILE" ]; then
    echo -e "${RED}Pack file not found: $PACK_FILE${NC}"
    echo "Install it first: pyocd pack install efr32mg24b220f1536im48"
    exit 1
fi

echo -e "${YELLOW}Fixing EFR32MG24 CMSIS-Pack memory regions...${NC}"

# Extract PDSC from pack
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

PDSC_NAME="SiliconLabs.GeckoPlatform_EFR32MG24_DFP.pdsc"
unzip -o "$PACK_FILE" "$PDSC_NAME" -d "$TMPDIR" > /dev/null

# Check if fix is needed
if ! grep -q 'id="IROM1".*size="0x00000000"' "$TMPDIR/$PDSC_NAME"; then
    echo -e "${GREEN}Pack already patched, no fix needed.${NC}"
    exit 0
fi

# Patch the PDSC: fix IROM1, IRAM1, and flash algorithm addresses/sizes
sed -i \
  -e 's|id="IROM1".*start="0x00000000".*size="0x00000000".*startup="1".*default="1"|id="IROM1"                start="0x08000000"  size="0x00180000"  startup="1"   default="1"|g' \
  -e 's|id="IRAM1".*start="0x00000000".*size="0x00000000".*init.*="0".*default="1"|id="IRAM1"                start="0x20000000"  size="0x00040000"  init   ="0"   default="1"|g' \
  -e 's|name="Flash/GECKOS2C3.FLM".*start="0x00000000".*size="0x00000000"|name="Flash/GECKOS2C3.FLM"  start="0x08000000"  size="0x00180000"|g' \
  -e 's|name="Flash/FlashGECKOS2C3.flash".*start="0x00000000".*size="0x00000000"|name="Flash/FlashGECKOS2C3.flash"  start="0x08000000"  size="0x00180000"|g' \
  "$TMPDIR/$PDSC_NAME"

# Update the pack ZIP
cd "$TMPDIR"
zip "$PACK_FILE" "$PDSC_NAME" > /dev/null
echo -e "${GREEN}Patched PDSC inside .pack file${NC}"

# Also fix index.json cache
if [ -f "$INDEX_FILE" ]; then
    python3 -c "
import json, sys

with open('$INDEX_FILE') as f:
    data = json.load(f)

count = 0
for key, entry in data.items():
    if 'EFR32MG24' not in key:
        continue
    mems = entry.get('memories', {})
    algos = entry.get('algorithms', [])
    flash_size = 0x00180000
    if 'F1024' in key:
        flash_size = 0x00100000
    elif 'F768' in key:
        flash_size = 0x000C0000
    if 'IROM1' in mems and mems['IROM1']['size'] == 0:
        mems['IROM1']['start'] = 0x08000000
        mems['IROM1']['size'] = flash_size
        count += 1
    if 'IRAM1' in mems and mems['IRAM1']['size'] == 0:
        mems['IRAM1']['start'] = 0x20000000
        mems['IRAM1']['size'] = 0x00040000
    for algo in algos:
        if algo['size'] == 0:
            algo['start'] = 0x08000000
            algo['size'] = flash_size

with open('$INDEX_FILE', 'w') as f:
    json.dump(data, f, indent=2)
print(f'Fixed {count} entries in index.json')
"
fi

echo -e "${GREEN}Done! Pack is now fixed.${NC}"
echo "Test with: pyocd commander --target efr32mg24b220f1536im48 --frequency 1000000 --command halt --command status --command exit"
