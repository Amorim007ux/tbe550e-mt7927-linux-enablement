#!/usr/bin/env bash
set -euo pipefail

# Expects MT6639 blob at /lib/firmware/mediatek/mt6639/BT_RAM_CODE_MT6639_2_1_hdr.bin

SRC="/lib/firmware/mediatek/mt6639/BT_RAM_CODE_MT6639_2_1_hdr.bin"
if [[ ! -f "$SRC" ]]; then
  echo "Missing $SRC"
  exit 1
fi

sudo mkdir -p /lib/firmware/mediatek /lib/firmware/mediatek/mt7925 /lib/firmware/mediatek/mt7927

sudo cp -f "$SRC" /lib/firmware/mediatek/BT_RAM_CODE_MT6639_2_1_hdr.bin
sudo cp -f "$SRC" /lib/firmware/mediatek/mt7925/BT_RAM_CODE_MT6639_2_1_hdr.bin
sudo cp -f "$SRC" /lib/firmware/mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin

sudo ln -sfn /lib/firmware/mediatek/BT_RAM_CODE_MT6639_2_1_hdr.bin /lib/firmware/mediatek/BT_RAM_CODE_MT7927_2_1_hdr.bin
sudo ln -sfn /lib/firmware/mediatek/BT_RAM_CODE_MT6639_2_1_hdr.bin /lib/firmware/mediatek/BT_RAM_CODE_MT7925_2_1_hdr.bin
sudo ln -sfn /lib/firmware/mediatek/mt7925/BT_RAM_CODE_MT6639_2_1_hdr.bin /lib/firmware/mediatek/mt7925/BT_RAM_CODE_MT7927_2_1_hdr.bin
sudo ln -sfn /lib/firmware/mediatek/mt7925/BT_RAM_CODE_MT6639_2_1_hdr.bin /lib/firmware/mediatek/mt7925/BT_RAM_CODE_MT7925_2_1_hdr.bin
sudo ln -sfn /lib/firmware/mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin /lib/firmware/mediatek/mt7927/BT_RAM_CODE_MT7927_2_1_hdr.bin
sudo ln -sfn /lib/firmware/mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin /lib/firmware/mediatek/mt7927/BT_RAM_CODE_MT7925_2_1_hdr.bin

echo "Bluetooth firmware compatibility links installed."
