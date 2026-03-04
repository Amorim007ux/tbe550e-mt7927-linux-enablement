# MT7927 Linux Enablement

Reliable bring-up for MediaTek MT7927 Wi-Fi + Bluetooth on Linux when stock kernels do not fully support the combo chipset out of the box.

## Scope
This repository provides:
- kernel patchsets for MT6639/MT7927 behavior in `mt76` and Bluetooth drivers
- build/install scripts for patched Wi-Fi and Bluetooth modules
- firmware extraction/install tooling from vendor package payloads
- a boot hardening pattern for stable Bluetooth enumeration
- validation and rollback runbooks

## Tested Matrix
- Distribution: Ubuntu 25.10
- Kernel: `6.17.0-14-generic`
- Retail adapter (tested): TP-Link Archer TBE550E PCIe Adapter (BE9300, Wi-Fi 7 + Bluetooth 5.4)
- Wi-Fi chipset: MediaTek MT7927 (MT6639 family), PCI ID `14c3:7927`
- Wi-Fi subsystem: Foxconn `105b:e104`
- Bluetooth function (combo device): Foxconn / Hon Hai Wireless_Device, USB ID `0489:e116`

This workflow is kernel-version sensitive. If kernel internals change, patch refresh may be required.

## Repository Layout
- `patches/`
  - Wi-Fi + Bluetooth patchsets
- `scripts/`
  - firmware install/extract
  - module build/install
  - rollback and verification
  - GitHub hardening automation (`scripts/github/`)
- `docs/`
  - operational runbooks and validation logs
- `.github/`
  - CI workflow
  - issue templates
  - PR template
  - CODEOWNERS

## Quick Start
From repository root:

0. One-liner (recommended happy path)
```bash
sudo ./scripts/quick_install.sh --install-deps --assume-yes
```

Then reboot and validate:
```bash
./scripts/verify_mt7927.sh
lsusb | grep -i 0489:e116
hciconfig -a
bluetoothctl list
```

Advanced flags:
- `--dry-run` to preview actions only
- `--force` to continue on non-tested kernel/hardware checks
- `--skip-boot-hardening` if you want manual service/hook setup
- `--key-dir /path/to/mok` for Secure Boot module signing material

Manual flow (same steps, explicit):

1. Install prerequisites
```bash
sudo apt update
sudo apt install -y \
  build-essential \
  linux-source-6.17.0 \
  linux-headers-$(uname -r) \
  flex bison libelf-dev libssl-dev \
  kmod python3 ripgrep
```

2. Install firmware payloads
```bash
sudo ./scripts/install_firmware_from_asus_zip.sh
sudo ./scripts/install_mt7927_bt_firmware_links.sh
```

3. Build/install patched Wi-Fi and Bluetooth modules
```bash
sudo ./scripts/build_install_mt7927_modules.sh
sudo ./scripts/build_install_mt7927_bt_modules.sh
```

4. Apply boot hardening (recommended)
- follow `docs/BOOT_SEQUENCE.md`

5. Reboot and verify
```bash
./scripts/verify_mt7927.sh
lsusb | grep -i 0489:e116
hciconfig -a
bluetoothctl list
```

## Testing Strategy
Use this sequence before publishing changes:

1. Static checks
```bash
bash -n scripts/quick_install.sh
bash -n scripts/build_install_mt7927_modules.sh
bash -n scripts/build_install_mt7927_bt_modules.sh
./scripts/test_quick_install_mock.sh
```

2. Dry-run installer
```bash
./scripts/quick_install.sh --dry-run --install-deps
```

3. Real install
```bash
sudo ./scripts/quick_install.sh --install-deps --assume-yes
sudo reboot
```

4. Post-reboot validation
```bash
./scripts/verify_mt7927.sh
nmcli device status
lsusb | grep -i 0489:e116
hciconfig -a
```

5. Rollback test (recommended once)
```bash
sudo ./scripts/rollback_stock_mt76.sh
sudo rm -rf /lib/modules/$(uname -r)/updates/mt7927-patch/bluetooth
sudo depmod -a
sudo reboot
```

## Secure Boot
If Secure Boot is enabled, unsigned out-of-tree modules will not load.

Both build scripts support signing with:
- `KEY_DIR` env var (default: `/root/mt7927-mok`)
- expected files: `MOK.priv` and `MOK.der`

Example:
```bash
sudo KEY_DIR=/root/mt7927-mok ./build_install_mt7927_modules.sh
sudo KEY_DIR=/root/mt7927-mok ./build_install_mt7927_bt_modules.sh
```

MOK enrollment still must be completed in firmware UI after reboot.

## Reference Outcome
- patched Wi-Fi stack binds to MT7927
- firmware loads from `/lib/firmware/mediatek/mt7927/`
- Wi-Fi interface appears and connects
- patched `btusb` + `btmtk` load
- `hci0` reaches `UP RUNNING`
- boot hardening recovers early Bluetooth races

See `docs/FINAL_VALIDATION.md` for the captured validation snapshot.

## Rollback
```bash
sudo ./scripts/rollback_stock_mt76.sh
# Optional BT cleanup:
# sudo rm -rf /lib/modules/$(uname -r)/updates/mt7927-patch/bluetooth
# sudo depmod -a
```

## Project Hygiene
- License: `MIT` (`LICENSE`)
- Contribution process: `CONTRIBUTING.md`
- Security policy: `SECURITY.md`
- Support expectations: `SUPPORT.md`
- Maintainer list: `CONTRIBUTORS.md`
- GitHub hardening guide: `docs/GITHUB_SETUP.md`

## No Warranty / Liability
This repository is provided as-is, without warranty.
Applying low-level driver and firmware changes can break networking, Bluetooth, suspend/resume, or boot behavior.
Use at your own risk.

## Known Caveats
- Out-of-tree workaround.
- May require patch refresh after kernel updates.
- Some platforms need xHCI post-boot rebind for stable Bluetooth init.
