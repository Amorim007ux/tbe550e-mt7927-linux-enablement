# Final Validation

Validation date: 2026-03-04
Status: successful

## Environment Snapshot
- Distribution: Ubuntu 25.10
- Kernel: `6.17.0-14-generic`
- Retail adapter (tested): TP-Link Archer TBE550E PCIe Adapter (BE9300, Wi-Fi 7 + Bluetooth 5.4)
- Wi-Fi chipset: MediaTek MT7927 (MT6639 family), PCI ID `14c3:7927`
- Wi-Fi subsystem: Foxconn `105b:e104`
- Bluetooth function (combo device): Foxconn / Hon Hai Wireless_Device, USB ID `0489:e116`

## Wi-Fi Validation
- Driver bound: `mt7925e` (patched stack)
- Interface present: `wlp4s0`
- NetworkManager: connected state observed
- Active scan and association: successful

## Bluetooth Validation
- Patched stack active: `btusb` + `btmtk`
- Controller: `hci0` present
- Controller state: `UP RUNNING`
- Address: valid public address (not all zeros)
- `bluetoothctl list`: controller reported as default
- Functional test: Bluetooth peripheral connected successfully

## Observed Boot Behavior
- One early firmware lookup warning may appear before post-boot recovery sequence.
- Recovery service then restores controller initialization in the same boot.

## Command Checklist Used
```bash
lspci -nnk -s 04:00.0
ip -br link
nmcli device status
lsusb | grep -i 0489:e116
hciconfig -a
bluetoothctl list
dmesg -T | rg -i 'mt7925e|mt6639|btusb|btmtk|firmware|error -110|error -71'
```
