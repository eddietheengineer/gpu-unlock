#!/usr/bin/env bash
# toggle.sh — arm or disarm the gpu_unlock boot-time unlock for A/B testing.
#
#   sudo ./toggle.sh unlock [all | 0000:03:00.0[,0000:01:00.0 ...]]
#   sudo ./toggle.sh lock
#
# unlock: puts gpu_unlock.targets=... on the kernel command line, so the
#         module in the initramfs unlocks the named cards before nvidia binds.
# lock:   removes it; the module still loads but does nothing.
#
# After either: power OFF, then power back on. The unlock only runs on a
# cold card; warm reboots are not supported.
set -euo pipefail

PARAM='gpu_unlock.targets'
GREP_RE='gpu_unlock\.targets'
VAL_RE="[^[:space:]\"']*"
ADDR_RE='[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-7]'
GRUB_CONF=${GRUB_CONF:-/etc/default/grub}

die() { echo "error: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  sudo ./toggle.sh unlock [all | 0000:03:00.0[,0000:01:00.0 ...]]
  sudo ./toggle.sh lock

unlock: put gpu_unlock.targets=... on the kernel command line (default: all)
lock:   remove it; the module loads but does nothing

Addresses are full PCI names as `lspci -D` prints them. After running,
power OFF and power back on (warm reboot is not supported).
EOF
}

[[ $# -ge 1 && $# -le 2 ]] || { usage; exit 2; }
cmd=$1
[[ $EUID -eq 0 ]] || die "run as: sudo $0 $cmd"
[[ -f $GRUB_CONF ]] || die "$GRUB_CONF not found"

targets=all
case $cmd in
  unlock)
    targets=${2:-all}
    if [[ $targets != all ]]; then
      [[ $targets =~ ^($ADDR_RE)(,$ADDR_RE)*$ ]] ||
        die "bad targets '$targets' (want 'all' or comma-separated addresses like 0000:03:00.0)"
    fi
    ;;
  lock) ;;
  *) usage; exit 2 ;;
esac

initrd="/boot/initrd.img-$(uname -r)"
if [[ -f $initrd ]] && ! lsinitramfs "$initrd" 2>/dev/null | grep -q 'gpu_unlock'; then
  echo "warning: gpu_unlock is NOT in $initrd." >&2
  echo "         install the gpu-unlock packages first, or the toggle" >&2
  echo "         changes the command line but nothing runs at boot." >&2
fi

current=$(grep -oE "${GREP_RE}=${VAL_RE}" "$GRUB_CONF" | head -n1 | cut -d= -f2- || true)

case $cmd in
  lock)
    if [[ -z $current ]]; then
      echo "already locked (no $PARAM on the kernel command line)"
      exit 0
    fi
    cp -p "$GRUB_CONF" "${GRUB_CONF}.bak"
    sed -i -E "s/(^|[[:space:]\"'])${GREP_RE}=${VAL_RE}/\1/;
               /^GRUB_CMDLINE/s/[[:space:]]{2,}/ /g;
               /^GRUB_CMDLINE/s/^(GRUB_CMDLINE[A-Z_]*=\")[[:space:]]+/\1/;
               /^GRUB_CMDLINE/s/[[:space:]]+\"/\"/" "$GRUB_CONF"
    echo "locked: removed ${PARAM}=${current}"
    ;;
  unlock)
    if [[ $current == "$targets" ]]; then
      echo "already unlocked with ${PARAM}=${targets}"
      exit 0
    fi
    cp -p "$GRUB_CONF" "${GRUB_CONF}.bak"
    if [[ -n $current ]]; then
      sed -i -E "s/(^|[[:space:]\"'])${GREP_RE}=${VAL_RE}/\1${PARAM}=${targets}/" "$GRUB_CONF"
    elif grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_CONF"; then
      sed -i -E "s/^(GRUB_CMDLINE_LINUX_DEFAULT=\".*)\"[[:space:]]*$/\1 ${PARAM}=${targets}\"/" "$GRUB_CONF"
    else
      sed -i -E "s/^(GRUB_CMDLINE_LINUX=\".*)\"[[:space:]]*$/\1 ${PARAM}=${targets}\"/" "$GRUB_CONF"
    fi
    echo "unlocked: ${PARAM}=${targets}"
    ;;
esac

update-grub

echo
echo "kernel command line now:"
grep '^GRUB_CMDLINE' "$GRUB_CONF" | sed 's/^/  /'
echo
echo "Next cold boot: $([[ $cmd == lock ]] && echo LOCKED || echo UNLOCKED)."
echo "Power OFF, then power back on. Warm reboot is not supported."
