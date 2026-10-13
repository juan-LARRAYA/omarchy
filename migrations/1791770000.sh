echo "Pin Plymouth's device scale so the unlock screen stays centred on HiDPI panels"

# plymouthd halves the window size the theme centres with on panels above
# ~192 DPI. The packaged plymouthd.conf pins DeviceScale=1, and the file is
# also copied into the initramfs. The package may already have written the
# config before this runs, so rebuild every time: a rebuild that failed is
# then retried, because this migration exits non-zero until it succeeds.

conf=${OMARCHY_PLYMOUTHD_CONF:-/etc/plymouth/plymouthd.conf}

if [[ -f $conf ]]; then
  if ! grep -Eqi '^[[:space:]]*DeviceScale[[:space:]]*=' "$conf"; then
    tmp=$(mktemp)
    awk '
      { print }
      !done && tolower($0) ~ /^[[:space:]]*\[daemon\][[:space:]]*$/ { print "DeviceScale=1"; done = 1 }
      END { if (!done) print "\n[Daemon]\nDeviceScale=1" }
    ' "$conf" >"$tmp"
    sudo cp "$tmp" "$conf"
    rm -f "$tmp"
  fi

  if omarchy-cmd-present limine-mkinitcpio; then
    sudo limine-mkinitcpio
  else
    sudo mkinitcpio -P
  fi
fi
