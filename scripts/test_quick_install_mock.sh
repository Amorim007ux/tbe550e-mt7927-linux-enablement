#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$SCRIPT_DIR/quick_install.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
MOCKBIN="$TMPDIR/mockbin"
mkdir -p "$MOCKBIN"

cat > "$MOCKBIN/uname" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-r" ]]; then
  echo "${MOCK_UNAME_R:-6.17.0-14-generic}"
else
  /usr/bin/uname "$@"
fi
EOF

cat > "$MOCKBIN/lspci" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -n)
    if [[ -v MOCK_LSPCI_N ]]; then
      printf '%s\n' "$MOCK_LSPCI_N"
    else
      printf '%s\n' '04:00.0 0280: 14c3:7927'
    fi
    ;;
  -Dn)
    if [[ -v MOCK_LSPCI_DN ]]; then
      printf '%s\n' "$MOCK_LSPCI_DN"
    else
      printf '%s\n' '0000:00:14.0 USB controller: Intel Corporation xHCI Host Controller'
    fi
    ;;
  *)
    if [[ -v MOCK_LSPCI ]]; then
      printf '%s\n' "$MOCK_LSPCI"
    else
      printf '%s\n' '04:00.0 Network controller: MEDIATEK Corp. Device 7927'
    fi
    ;;
esac
EOF

cat > "$MOCKBIN/lsusb" <<'EOF'
#!/usr/bin/env bash
if [[ -v MOCK_LSUSB ]]; then
  printf '%s\n' "$MOCK_LSUSB"
else
  printf '%s\n' 'Bus 001 Device 002: ID 0489:e116 Foxconn / Hon Hai'
fi
EOF

cat > "$MOCKBIN/mokutil" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--sb-state" ]]; then
  echo "${MOCK_SB_STATE:-SecureBoot disabled}"
  exit 0
fi
exit 0
EOF

chmod +x "$MOCKBIN"/*

TOTAL=0
FAILED=0
LAST_OUT=""
LAST_RC=0

reset_mocks() {
  export MOCK_UNAME_R="6.17.0-14-generic"
  export MOCK_LSPCI_N="04:00.0 0280: 14c3:7927"
  export MOCK_LSPCI_DN="0000:00:14.0 USB controller: Intel Corporation xHCI Host Controller"
  export MOCK_LSUSB="Bus 001 Device 002: ID 0489:e116 Foxconn / Hon Hai"
  export MOCK_SB_STATE="SecureBoot disabled"
}

run_case() {
  local name="$1"
  local expected_rc="$2"
  shift 2
  TOTAL=$((TOTAL + 1))
  LAST_OUT="$TMPDIR/${name}.out"
  set +e
  PATH="$MOCKBIN:/usr/bin:/bin" "$TARGET" "$@" >"$LAST_OUT" 2>&1
  LAST_RC=$?
  set -e
  if [[ "$LAST_RC" -ne "$expected_rc" ]]; then
    echo "[FAIL] $name: expected rc=$expected_rc got rc=$LAST_RC"
    sed -n '1,140p' "$LAST_OUT"
    FAILED=$((FAILED + 1))
  else
    echo "[PASS] $name"
  fi
}

assert_contains() {
  local name="$1"
  local pattern="$2"
  if ! grep -Fq "$pattern" "$LAST_OUT"; then
    echo "[FAIL] $name: missing pattern: $pattern"
    sed -n '1,140p' "$LAST_OUT"
    FAILED=$((FAILED + 1))
  fi
}

assert_not_contains() {
  local name="$1"
  local pattern="$2"
  if grep -Fq "$pattern" "$LAST_OUT"; then
    echo "[FAIL] $name: unexpected pattern: $pattern"
    sed -n '1,140p' "$LAST_OUT"
    FAILED=$((FAILED + 1))
  fi
}

reset_mocks
run_case help 0 --help
assert_contains help "Usage: quick_install.sh"

reset_mocks
run_case unknown_option 1 --nope
assert_contains unknown_option "Unknown option"

reset_mocks
export MOCK_UNAME_R="6.18.1-custom"
run_case unsupported_kernel 1 --dry-run --skip-firmware --skip-wifi --skip-bt --skip-boot-hardening
assert_contains unsupported_kernel "outside tested range"

reset_mocks
export MOCK_UNAME_R="6.18.1-custom"
run_case unsupported_kernel_force 0 --force --dry-run --skip-firmware --skip-wifi --skip-bt --skip-boot-hardening
assert_contains unsupported_kernel_force "continuing due to --force"

reset_mocks
export MOCK_LSPCI_N="00:00.0 0600: 8086:1234"
run_case missing_wifi_no_force 1 --dry-run --skip-firmware --skip-wifi --skip-bt --skip-boot-hardening
assert_contains missing_wifi_no_force "No tested MT7927/MT6639 PCI ID found"

reset_mocks
export MOCK_LSPCI_N="00:00.0 0600: 8086:1234"
run_case missing_wifi_force 0 --force --dry-run --skip-firmware --skip-wifi --skip-bt --skip-boot-hardening
assert_contains missing_wifi_force "continuing due to --force"

reset_mocks
export MOCK_SB_STATE="SecureBoot enabled"
run_case secureboot_warn_no_key 0 --dry-run --skip-firmware --skip-wifi --skip-bt --skip-boot-hardening --key-dir /tmp/nonexistent-mok
assert_contains secureboot_warn_no_key "Secure Boot appears enabled but no signing key found"

reset_mocks
export MOCK_LSPCI_DN="0000:00:14.0 USB controller: Intel Corporation EHCI Host Controller"
run_case xhci_missing_dryrun 0 --dry-run --skip-firmware --skip-wifi --skip-bt
assert_contains xhci_missing_dryrun "Could not auto-detect xHCI PCI ID in dry-run"
assert_contains xhci_missing_dryrun "Replace <XHCI_PCI_ID>"

reset_mocks
run_case xhci_present_dryrun 0 --dry-run --skip-firmware --skip-wifi --skip-bt
assert_contains xhci_present_dryrun "Would write /etc/systemd/system/mt7927-bt-rescan.service"
assert_not_contains xhci_present_dryrun "Could not auto-detect xHCI PCI ID in dry-run"

reset_mocks
run_case install_deps_assume_yes 0 --dry-run --install-deps --assume-yes --skip-firmware --skip-wifi --skip-bt --skip-boot-hardening
assert_contains install_deps_assume_yes "apt install -y"

reset_mocks
run_case install_deps_no_yes 0 --dry-run --install-deps --skip-firmware --skip-wifi --skip-bt --skip-boot-hardening
assert_not_contains install_deps_no_yes "apt install -y"
assert_contains install_deps_no_yes "apt install"

reset_mocks
run_case keydir_propagation 0 --dry-run --skip-firmware --skip-bt --skip-boot-hardening --key-dir /tmp/custom-mok
assert_contains keydir_propagation "env KEY_DIR=/tmp/custom-mok"

reset_mocks
run_case all_skipped 0 --dry-run --skip-firmware --skip-wifi --skip-bt --skip-boot-hardening
assert_not_contains all_skipped "Installing Wi-Fi/Bluetooth firmware payloads"
assert_not_contains all_skipped "Building/installing patched Wi-Fi modules"
assert_not_contains all_skipped "Building/installing patched Bluetooth modules"
assert_not_contains all_skipped "Applying boot hardening"

echo "Total cases: $TOTAL"
if [[ "$FAILED" -ne 0 ]]; then
  echo "Failures: $FAILED"
  exit 1
fi
echo "All mocked quick_install tests passed."
