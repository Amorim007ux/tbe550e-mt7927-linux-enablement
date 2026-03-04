#!/usr/bin/env bash
set -euo pipefail

echo "Kernel: $(uname -r)"
echo
lspci -nnk -s 04:00.0
echo
ip -br link | rg -i 'wlp|wlan|enp42s0|enx' || true
echo
nmcli device status
echo
dmesg -T | rg -i 'mt7925e|mt6639|firmware|patch semaphore|hardware init|wlp' | tail -n 60 || true
echo
nmcli -f IN-USE,SSID,SIGNAL,SECURITY,BARS device wifi list ifname wlp4s0 | sed -n '1,30p' || true
