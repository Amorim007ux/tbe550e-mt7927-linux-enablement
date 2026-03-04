#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
KREL="$(uname -r)"
KEY_DIR="${KEY_DIR:-/root/mt7927-mok}"

DRY_RUN=0
FORCE=0
INSTALL_DEPS=0
SKIP_FIRMWARE=0
SKIP_WIFI=0
SKIP_BT=0
SKIP_BOOT_HARDENING=0
ASSUME_YES=0

SUPPORTED_KERNEL_RE='^6\.17\.'
SUPPORTED_WIFI_PCI_RE='14c3:(7927|6639)'
KNOWN_BT_USB_ID='0489:e116'

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  SUDO=()
else
  SUDO=(sudo)
fi

log() { printf '[quick-install] %s\n' "$*"; }
warn() { printf '[quick-install][warn] %s\n' "$*" >&2; }
die() { printf '[quick-install][error] %s\n' "$*" >&2; exit 1; }

run_cmd() {
  if (( DRY_RUN )); then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

write_root_file() {
  local dest="$1"
  local mode="$2"
  local tmp
  tmp="$(mktemp)"
  cat > "$tmp"
  if (( DRY_RUN )); then
    log "Would write $dest (mode $mode)"
    rm -f "$tmp"
    return 0
  fi
  "${SUDO[@]}" install -m "$mode" "$tmp" "$dest"
  rm -f "$tmp"
}

usage() {
  cat <<'EOF'
Usage: quick_install.sh [options]

Options:
  --install-deps         Install required apt packages.
  --assume-yes           Pass -y to apt operations.
  --skip-firmware        Skip firmware download/install.
  --skip-wifi            Skip Wi-Fi module build/install.
  --skip-bt              Skip Bluetooth module build/install.
  --skip-boot-hardening  Skip initramfs + xHCI boot hardening setup.
  --key-dir <dir>        MOK key directory (default: /root/mt7927-mok).
  --force                Continue on unsupported kernel/hardware checks.
  --dry-run              Print actions without changing the system.
  -h, --help             Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-deps) INSTALL_DEPS=1 ;;
    --assume-yes) ASSUME_YES=1 ;;
    --skip-firmware) SKIP_FIRMWARE=1 ;;
    --skip-wifi) SKIP_WIFI=1 ;;
    --skip-bt) SKIP_BT=1 ;;
    --skip-boot-hardening) SKIP_BOOT_HARDENING=1 ;;
    --key-dir)
      shift
      [[ $# -gt 0 ]] || die "--key-dir requires a value"
      KEY_DIR="$1"
      ;;
    --force) FORCE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1 (use --help)"
      ;;
  esac
  shift
done

[[ -x "$SCRIPT_DIR/install_firmware_from_asus_zip.sh" ]] || die "Missing script: install_firmware_from_asus_zip.sh"
[[ -x "$SCRIPT_DIR/install_mt7927_bt_firmware_links.sh" ]] || die "Missing script: install_mt7927_bt_firmware_links.sh"
[[ -x "$SCRIPT_DIR/build_install_mt7927_modules.sh" ]] || die "Missing script: build_install_mt7927_modules.sh"
[[ -x "$SCRIPT_DIR/build_install_mt7927_bt_modules.sh" ]] || die "Missing script: build_install_mt7927_bt_modules.sh"
[[ -f "$REPO_ROOT/patches/mt6639-wifi-init.patch" ]] || die "Missing patch: mt6639-wifi-init.patch"
[[ -f "$REPO_ROOT/patches/mt6639-wifi-dma.patch" ]] || die "Missing patch: mt6639-wifi-dma.patch"
[[ -f "$REPO_ROOT/patches/mt6639-band-idx.patch" ]] || die "Missing patch: mt6639-band-idx.patch"
[[ -f "$REPO_ROOT/patches/mt6639-bt-6.19.patch" ]] || die "Missing patch: mt6639-bt-6.19.patch"

if [[ ! "$KREL" =~ $SUPPORTED_KERNEL_RE ]]; then
  if (( FORCE )); then
    warn "Kernel '$KREL' is outside tested range (expected 6.17.x), continuing due to --force."
  else
    die "Kernel '$KREL' is outside tested range (expected 6.17.x). Re-run with --force to continue."
  fi
fi

WIFI_PCI_PRESENT=0
if lspci -n 2>/dev/null | grep -Eiq "$SUPPORTED_WIFI_PCI_RE"; then
  WIFI_PCI_PRESENT=1
fi
if (( ! WIFI_PCI_PRESENT )); then
  if (( FORCE )); then
    warn "No tested MT7927/MT6639 PCI ID found, continuing due to --force."
  else
    die "No tested MT7927/MT6639 PCI ID found in lspci output. Re-run with --force if this is expected."
  fi
fi

if ! lsusb 2>/dev/null | grep -Eiq "$KNOWN_BT_USB_ID"; then
  warn "Bluetooth USB ID $KNOWN_BT_USB_ID not visible right now; installation can still proceed."
fi

if command -v mokutil >/dev/null 2>&1; then
  if mokutil --sb-state 2>/dev/null | grep -qi 'enabled'; then
    if [[ ! -f "$KEY_DIR/MOK.priv" || ! -f "$KEY_DIR/MOK.der" ]]; then
      warn "Secure Boot appears enabled but no signing key found under $KEY_DIR; modules may fail to load."
    fi
  fi
fi

if (( INSTALL_DEPS )); then
  log "Installing prerequisites via apt."
  APT_FLAGS=()
  if (( ASSUME_YES )); then
    APT_FLAGS=(-y)
  fi
  run_cmd "${SUDO[@]}" apt update
  run_cmd "${SUDO[@]}" apt install "${APT_FLAGS[@]}" \
    build-essential \
    linux-source-6.17.0 \
    "linux-headers-$KREL" \
    flex bison libelf-dev libssl-dev \
    kmod python3 ripgrep
fi

if (( ! SKIP_FIRMWARE )); then
  log "Installing Wi-Fi/Bluetooth firmware payloads."
  run_cmd "${SUDO[@]}" "$SCRIPT_DIR/install_firmware_from_asus_zip.sh"
  run_cmd "${SUDO[@]}" "$SCRIPT_DIR/install_mt7927_bt_firmware_links.sh"
fi

if (( ! SKIP_WIFI )); then
  log "Building/installing patched Wi-Fi modules."
  run_cmd "${SUDO[@]}" env KEY_DIR="$KEY_DIR" "$SCRIPT_DIR/build_install_mt7927_modules.sh"
fi

if (( ! SKIP_BT )); then
  log "Building/installing patched Bluetooth modules."
  run_cmd "${SUDO[@]}" env KEY_DIR="$KEY_DIR" "$SCRIPT_DIR/build_install_mt7927_bt_modules.sh"
fi

if (( ! SKIP_BOOT_HARDENING )); then
  log "Applying boot hardening for Bluetooth enumeration stability."

  write_root_file /etc/modules-load.d/mt7927.conf 0644 <<'EOF'
mt7925e
btmtk
btusb
EOF

  run_cmd "${SUDO[@]}" sh -c "grep -qxF mt7925e /etc/initramfs-tools/modules || echo mt7925e >> /etc/initramfs-tools/modules"

  write_root_file /etc/initramfs-tools/hooks/mt6639-bt-firmware 0755 <<'EOF'
#!/bin/sh
set -e

PREREQ=""
prereqs() { echo "$PREREQ"; }
case "$1" in
  prereqs) prereqs; exit 0 ;;
esac

. /usr/share/initramfs-tools/hook-functions

copy_file firmware /lib/firmware/mediatek/mt6639/BT_RAM_CODE_MT6639_2_1_hdr.bin
EOF

  CREATE_RESCAN_SERVICE=1
  XHCI_PCI_ID="$(lspci -Dn | awk '/USB controller/ && /xHCI/ {print $1; exit}')"
  if [[ -z "$XHCI_PCI_ID" ]]; then
    if (( DRY_RUN )); then
      warn "Could not auto-detect xHCI PCI ID in dry-run; using placeholder in generated service."
      XHCI_PCI_ID="<XHCI_PCI_ID>"
    elif (( FORCE )); then
      warn "Could not auto-detect xHCI PCI ID; skipping rescan service due to --force."
      CREATE_RESCAN_SERVICE=0
    else
      die "Could not auto-detect xHCI PCI ID. Use --skip-boot-hardening or --force."
    fi
  fi

  if (( CREATE_RESCAN_SERVICE )); then
    write_root_file /etc/systemd/system/mt7927-bt-rescan.service 0644 <<EOF
[Unit]
Description=MT7927 Bluetooth USB rescan
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'sleep 5; echo $XHCI_PCI_ID > /sys/bus/pci/drivers/xhci_hcd/unbind; sleep 1; echo $XHCI_PCI_ID > /sys/bus/pci/drivers/xhci_hcd/bind'

[Install]
WantedBy=multi-user.target
EOF
    run_cmd "${SUDO[@]}" systemctl daemon-reload
    run_cmd "${SUDO[@]}" systemctl enable mt7927-bt-rescan.service
    if [[ "$XHCI_PCI_ID" == "<XHCI_PCI_ID>" ]]; then
      warn "Replace <XHCI_PCI_ID> in mt7927-bt-rescan.service before real execution."
    fi
  fi

  run_cmd "${SUDO[@]}" update-initramfs -u
fi

log "Install flow completed."
log "Next: reboot, then run: $SCRIPT_DIR/verify_mt7927.sh"
