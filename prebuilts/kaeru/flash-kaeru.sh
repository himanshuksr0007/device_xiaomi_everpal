#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${SCRIPT_DIR}/Kaeru.bin"
EXPECTED_SIZE=1606448
EXPECTED_SHA256="D91D0A3A23409079F365DBC43C8B2C8798C423B13C41C051863BB53F8D3A6E05"
ALLOWED_VARIANTS="evergo everpal"
FORCE=0
for arg in "$@"; do
  case "${arg}" in
    --force) FORCE=1 ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--force]"
      echo "  Flashes Kaeru.bin to lk_a and lk_b. --force skips variant check."
      exit 0
      ;;
    *)
      echo "Unknown arg: ${arg}" >&2
      exit 1
      ;;
  esac
done
die() { echo "ERROR: $*" >&2; exit 1; }
[ -f "${BIN}" ] || die "missing ${BIN}"
ACTUAL_SIZE="$(wc -c < "${BIN}" | tr -d ' ')"
[ "${ACTUAL_SIZE}" = "${EXPECTED_SIZE}" ] || die "size mismatch: got ${ACTUAL_SIZE}, want ${EXPECTED_SIZE}. Refusing."
command -v sha256sum >/dev/null 2>&1 || die "sha256sum not found"
ACTUAL_SHA256="$(sha256sum "${BIN}" | awk '{print $1}')"
[ "${ACTUAL_SHA256}" = "${EXPECTED_SHA256}" ] || die "sha256 mismatch: got ${ACTUAL_SHA256}. Refusing."
command -v fastboot >/dev/null 2>&1 || die "fastboot not in PATH. For first install use BROM mode (mtkclient/SP Flash), see kaeru.mk."
[ -n "$(fastboot devices)" ] || die "no device in fastboot. Reboot to bootloader first."
UNLOCK_STATE="$(fastboot getvar unlocked 2>&1 | tr '[:upper:]' '[:lower:]' || true)"
case "${UNLOCK_STATE}" in
  *unlocked:\ yes*)
    ;;
  *)
    echo "Device does not report 'unlocked: yes':" >&2
    echo "${UNLOCK_STATE}" >&2
    die "unlock the bootloader AND seccfg first (BROM via mtkclient/penumbra, see kaeru.mk), then re-run. Refusing to flash."
    ;;
esac
PRODUCT="$(fastboot getvar product 2>&1 | tr '[:upper:]' '[:lower:]' || true)"
if [ "${FORCE}" -eq 0 ]; then
  MATCH=0
  for v in ${ALLOWED_VARIANTS}; do
    case "${PRODUCT}" in
      *"${v}"*) MATCH=1 ;;
    esac
  done
  if [ "${MATCH}" -eq 0 ]; then
    echo "Detected product info: ${PRODUCT}" >&2
    die "variant check failed (want evergo/everpal, this build is evergo-only). Pass --force to override at your own risk."
  fi
else
  echo "WARNING: --force given, variant check skipped." >&2
fi
echo "This will flash:"
echo "  ${BIN}"
echo "  -> lk_a"
echo "  -> lk_b"
echo "It will NOT touch preloader, seccfg, nvram, tee, or any other partition."
echo "Backup your stock lk_a/lk_b first. Battery >50%. seccfg must already be unlocked."
printf "Type YES to continue: "
read -r CONFIRM
[ "${CONFIRM}" = "YES" ] || die "aborted."
fastboot flash lk_a "${BIN}"
fastboot flash lk_b "${BIN}"
echo "Done. Reboot with: fastboot reboot"
echo "Verify from bootloader: fastboot getvar version-bootloader (and kaeru-version if exposed)."
