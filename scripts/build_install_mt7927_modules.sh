#!/usr/bin/env bash
set -euo pipefail

KREL="$(uname -r)"
KSRC_TAR="/usr/src/linux-source-6.17.0.tar.bz2"
WORK="/usr/src/mt7927-dkms-build"
SRC="$WORK/linux-source-6.17.0/drivers/net/wireless/mediatek/mt76"
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH_DIR="$REPO_DIR/patches"
DST="/lib/modules/$KREL/updates/mt7927-patch"
SIGN="/usr/src/linux-headers-$KREL/scripts/sign-file"
KEY_DIR="${KEY_DIR:-/root/mt7927-mok}"
KEY_PRIV="$KEY_DIR/MOK.priv"
KEY_DER="$KEY_DIR/MOK.der"

if [[ ! -f "$KSRC_TAR" ]]; then
  echo "Missing $KSRC_TAR (install linux-source-6.17.0)"
  exit 1
fi

sudo rm -rf "$WORK"
sudo mkdir -p "$WORK"
sudo tar -xf "$KSRC_TAR" -C "$WORK"

cd "$SRC"
sudo patch -p1 < "$PATCH_DIR/mt6639-wifi-init.patch"
sudo patch -p1 < "$PATCH_DIR/mt6639-wifi-dma.patch"
sudo patch -p6 < "$PATCH_DIR/mt6639-band-idx.patch"

cd "$WORK/linux-source-6.17.0"
make -C /lib/modules/$KREL/build M=$PWD/drivers/net/wireless/mediatek/mt76 modules -j"$(nproc)"

sudo mkdir -p "$DST/mt7925"
sudo install -m 0644 "$SRC/mt76.ko" "$DST/"
sudo install -m 0644 "$SRC/mt76-connac-lib.ko" "$DST/"
sudo install -m 0644 "$SRC/mt792x-lib.ko" "$DST/"
sudo install -m 0644 "$SRC/mt7925/mt7925-common.ko" "$DST/mt7925/"
sudo install -m 0644 "$SRC/mt7925/mt7925e.ko" "$DST/mt7925/"

if [[ -f "$KEY_PRIV" && -f "$KEY_DER" && -x "$SIGN" ]]; then
  for f in "$DST/mt76.ko" "$DST/mt76-connac-lib.ko" "$DST/mt792x-lib.ko" "$DST/mt7925/mt7925-common.ko" "$DST/mt7925/mt7925e.ko"; do
    sudo "$SIGN" sha256 "$KEY_PRIV" "$KEY_DER" "$f"
  done
else
  echo "Signing assets not found; modules installed unsigned."
fi

sudo depmod -a
sudo modprobe -r mt7921e mt7921_common mt7925e mt7925_common mt792x_lib mt76_connac_lib mt76 2>/dev/null || true
sudo modprobe mt7925e

echo "Patched modules installed and loaded."
