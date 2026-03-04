# Runbook

End-to-end operator guide for MT7927 bring-up, validation, and rollback.

## Hardware Naming (This Repo)
- Retail adapter (tested): TP-Link Archer TBE550E PCIe Adapter (BE9300, Wi-Fi 7 + Bluetooth 5.4)
- Wi-Fi chipset: MediaTek MT7927 (MT6639 family), PCI ID `14c3:7927`
- Wi-Fi subsystem: Foxconn `105b:e104`
- Bluetooth function: Foxconn / Hon Hai Wireless_Device, USB ID `0489:e116`

## 0) Fast Path (One Command)
From repo root:

```bash
sudo ./scripts/quick_install.sh --install-deps --assume-yes
```

Then reboot and continue with section 6 (Validation).

## 1) Prerequisites
Run from Ubuntu host shell:

```bash
sudo apt update
sudo apt install -y \
  build-essential \
  linux-source-6.17.0 \
  linux-headers-$(uname -r) \
  flex bison libelf-dev libssl-dev \
  kmod python3 ripgrep
```

## 2) Firmware Install
From repo scripts directory:

```bash
cd <repo-root>/scripts
sudo ./install_firmware_from_asus_zip.sh
sudo ./install_mt7927_bt_firmware_links.sh
```

Expected artifacts:
- `/lib/firmware/mediatek/mt7927/WIFI_MT6639_PATCH_MCU_2_1_hdr.bin`
- `/lib/firmware/mediatek/mt7927/WIFI_RAM_CODE_MT6639_2_1.bin`
- `/lib/firmware/mediatek/mt6639/BT_RAM_CODE_MT6639_2_1_hdr.bin`

## 3) Build and Install Patched Modules

```bash
cd <repo-root>/scripts
sudo ./build_install_mt7927_modules.sh
sudo ./build_install_mt7927_bt_modules.sh
```

If Secure Boot is enabled and you already have an enrolled MOK key:

```bash
sudo KEY_DIR=/root/mt7927-mok ./build_install_mt7927_modules.sh
sudo KEY_DIR=/root/mt7927-mok ./build_install_mt7927_bt_modules.sh
```

## 4) Apply Boot Hardening
Apply the sequence from `docs/BOOT_SEQUENCE.md`.

This is strongly recommended for systems where Bluetooth enumeration is inconsistent across boots.

## 5) Reboot
Perform a reboot after module installation and boot hardening.

If Bluetooth was previously wedged, prefer a full cold reboot.

## 6) Validation

```bash
cd <repo-root>/scripts
./verify_mt7927.sh
```

Additional checks:

```bash
lspci -nnk -s 04:00.0
ip -br link
nmcli device status
lsusb | grep -i 0489:e116
hciconfig -a
bluetoothctl list
```

Success criteria:
- Wi-Fi driver bound to MT7927 (`mt7925e` in use)
- Wi-Fi interface is present and can scan/connect
- Bluetooth controller exists and reaches `UP RUNNING`

## 7) Kernel Upgrade Procedure
After any kernel change:
1. Reinstall matching headers and source package.
2. Re-run module build/install scripts.
3. Reboot and re-validate.

## 8) Rollback

```bash
cd <repo-root>/scripts
sudo ./rollback_stock_mt76.sh
```

Optional Bluetooth rollback:

```bash
sudo rm -rf /lib/modules/$(uname -r)/updates/mt7927-patch/bluetooth
sudo depmod -a
sudo reboot
```

## 9) Fast Triage
If Wi-Fi is missing:
- check `lspci -nnk -s 04:00.0`
- check firmware files under `/lib/firmware/mediatek/mt7927/`
- check `dmesg -T | rg -i 'mt7925e|firmware|patch semaphore|timeout'`

If Bluetooth is missing:
- check `lsusb | grep -i 0489:e116`
- check `dmesg -T | rg -i 'btusb|btmtk|mt6639|firmware|error -110|error -71'`
- verify boot hardening service is enabled/runs

## 10) Installer Test Flow
1. `bash -n scripts/quick_install.sh`
2. `./scripts/quick_install.sh --dry-run --install-deps`
3. `sudo ./scripts/quick_install.sh --install-deps --assume-yes`
4. reboot
5. run section 6 validation commands
