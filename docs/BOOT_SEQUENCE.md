# Boot Sequence Hardening

This sequence improves boot reliability for MT7927 combo cards when Bluetooth firmware handshake races occur early in boot.

## Overview
Hardening consists of:
1. preloading critical modules
2. ensuring Bluetooth firmware is available in initramfs
3. triggering one controlled xHCI unbind/rebind after boot

## 1) Module Preload
Create `/etc/modules-load.d/mt7927.conf`:

```text
mt7925e
btmtk
btusb
```

## 2) Initramfs Module Inclusion
Append to `/etc/initramfs-tools/modules`:

```text
mt7925e
```

## 3) Initramfs Firmware Hook
Create `/etc/initramfs-tools/hooks/mt6639-bt-firmware`:

```bash
#!/bin/sh
set -e

PREREQ=""
prereqs() { echo "$PREREQ"; }
case "$1" in
  prereqs) prereqs; exit 0 ;;
esac

. /usr/share/initramfs-tools/hook-functions

copy_file firmware /lib/firmware/mediatek/mt6639/BT_RAM_CODE_MT6639_2_1_hdr.bin
```

Then make it executable:

```bash
sudo chmod 755 /etc/initramfs-tools/hooks/mt6639-bt-firmware
```

## 4) xHCI Rebind Service
Identify target xHCI controller first (machine-specific PCI address):

```bash
lspci -nn | rg -i 'usb.*xhci'
```

Create `/etc/systemd/system/mt7927-bt-rescan.service`:

```ini
[Unit]
Description=MT7927 Bluetooth USB rescan
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'sleep 5; echo <XHCI_PCI_ID> > /sys/bus/pci/drivers/xhci_hcd/unbind; sleep 1; echo <XHCI_PCI_ID> > /sys/bus/pci/drivers/xhci_hcd/bind'

[Install]
WantedBy=multi-user.target
```

Replace `<XHCI_PCI_ID>` with your actual controller ID.

Enable service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable mt7927-bt-rescan.service
```

## 5) Regenerate Initramfs and Reboot

```bash
sudo update-initramfs -u
sudo reboot
```

## 6) Verify Service Health

```bash
systemctl status mt7927-bt-rescan.service
journalctl -u mt7927-bt-rescan.service -b
```

Expected behavior:
- service runs once after boot
- Bluetooth USB device appears
- `hci0` becomes available and stable
