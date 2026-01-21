#!/bin/bash
#
# Start VM and run a command, then exit
# Usage: ./vm/run.sh "command to run"
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

CMD="$1"

if [[ -z "$CMD" ]]; then
    echo "Usage: $0 \"command to run\""
    echo "Example: $0 \"/apps/compile-project.sh\""
    exit 1
fi

# Write command to a file that rcS will pick up
echo "$CMD" > "$PROJECT_DIR/apps/.autorun"

# Run the VM (it will execute the command and exit)
GUI="${GUI:-0}" "$SCRIPT_DIR/mac_startup_in_qemu.sh"

# Clean up
rm -f "$PROJECT_DIR/apps/.autorun"
