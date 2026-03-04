#!/usr/bin/env bash
set -euo pipefail

KREL="$(uname -r)"
KSRC_TAR="/usr/src/linux-source-6.17.0.tar.bz2"
WORK="/usr/src/mt7927-bt-build"
PATCH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/patches/mt6639-bt-6.19.patch"
DST="/lib/modules/$KREL/updates/mt7927-patch/bluetooth"
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

cd "$WORK/linux-source-6.17.0"
sudo patch -p1 < "$PATCH"

make -C /lib/modules/$KREL/build M=$PWD/drivers/bluetooth modules -j"$(nproc)"

sudo mkdir -p "$DST"
sudo install -m 0644 drivers/bluetooth/btusb.ko "$DST/"
sudo install -m 0644 drivers/bluetooth/btmtk.ko "$DST/"

if [[ -x "$SIGN" && -f "$KEY_PRIV" && -f "$KEY_DER" ]]; then
  sudo "$SIGN" sha256 "$KEY_PRIV" "$KEY_DER" "$DST/btusb.ko"
  sudo "$SIGN" sha256 "$KEY_PRIV" "$KEY_DER" "$DST/btmtk.ko"
fi

sudo depmod -a

echo "Patched btusb/btmtk installed. Reboot recommended before test."
