#!/usr/bin/env bash
#
# setup-udev.sh — Install udev rules for XIAO MG24 CMSIS-DAP access
#
# Run once after first connecting the board. Requires sudo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULES_FILE="70-xiao-mg24.rules"

if [ ! -f "${SCRIPT_DIR}/${RULES_FILE}" ]; then
    echo "Error: ${RULES_FILE} not found in ${SCRIPT_DIR}"
    exit 1
fi

echo "Installing udev rules..."
sudo cp "${SCRIPT_DIR}/${RULES_FILE}" /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "Done. Re-plug the XIAO MG24 for rules to take effect."
echo "Verify with: pyocd list --probes"
