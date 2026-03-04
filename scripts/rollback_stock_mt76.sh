#!/usr/bin/env bash
set -euo pipefail

KREL="$(uname -r)"
PATCH_DIR="/lib/modules/$KREL/updates/mt7927-patch"

sudo modprobe -r mt7925e mt7925_common mt792x_lib mt76_connac_lib mt76 2>/dev/null || true
sudo rm -rf "$PATCH_DIR"
sudo depmod -a
sudo modprobe mt7925e || true

echo "Rolled back patched modules. Reboot recommended."
