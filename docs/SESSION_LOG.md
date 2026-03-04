# Session Log

Chronological implementation summary for the validated MT7927 bring-up.

## Phase 1: Baseline Diagnosis
- Hardware confirmed present on PCI/USB buses.
- Stock kernel exposed `mt7925e` but lacked working MT7927 bring-up.
- No usable Wi-Fi interface was created initially.

## Phase 2: Early Attempts (Unsuccessful)
- Added MT7927 PCI ID mapping in the stock driver path.
- Module could bind, but firmware initialization failed with timeouts and patch semaphore errors.
- Alternate mapping and ASPM tuning did not resolve initialization failure.

## Phase 3: Secure Boot Path
- Secure Boot constraints identified.
- Local MOK keypair used to sign patched modules.
- MOK enrollment completed so custom modules could load under Secure Boot.

## Phase 4: Wi-Fi Breakthrough
- Applied MT6639/MT7927 Wi-Fi patchset:
  - `mt6639-wifi-init.patch`
  - `mt6639-wifi-dma.patch`
  - `mt6639-band-idx.patch`
- Rebuilt and installed patched `mt76` stack.
- New errors identified missing MT6639 firmware files.

## Phase 5: Firmware Resolution
- Downloaded vendor package and extracted `mtkwlan.dat`.
- Extracted required blobs:
  - `WIFI_MT6639_PATCH_MCU_2_1_hdr.bin`
  - `WIFI_RAM_CODE_MT6639_2_1.bin`
  - `BT_RAM_CODE_MT6639_2_1_hdr.bin`
- Installed Wi-Fi firmware to `/lib/firmware/mediatek/mt7927/`.

Result:
- driver auto-binds to device
- Wi-Fi interface appears
- scan and association succeed

## Phase 6: Bluetooth Enablement
- Built and installed patched `btusb` + `btmtk` using `mt6639-bt-6.19.patch`.
- Installed BT firmware and compatibility links.
- Observed partial initialization followed by USB-level instability on some boots.

## Phase 7: Boot Hardening
Applied hardening to stabilize boot behavior:
- module preload via `/etc/modules-load.d/mt7927.conf`
- initramfs firmware hook for MT6639 BT blob
- one-shot xHCI unbind/rebind service after boot

## Final Validated State
- Wi-Fi and Bluetooth both operational.
- `hci0` reaches `UP RUNNING` with valid address.
- Bluetooth peripheral connectivity verified.

## Remaining Caveat
A transient early firmware warning may still appear before recovery logic runs.
The controller recovers in the same boot after hardening sequence executes.
