echo "Pin Plymouth's device scale so the unlock screen stays centred on HiDPI panels"

# plymouthd halves the window size the theme centres with on panels above
# ~192 DPI. The packaged plymouthd.conf pins DeviceScale=1, and the file is
# also copied into the initramfs. The package may already have written the
# config before this runs, so rebuild every time: a rebuild that failed is
# then retried, because this migration exits non-zero until it succeeds.

conf=${OMARCHY_PLYMOUTHD_CONF:-/etc/plymouth/plymouthd.conf}

# Only a DeviceScale inside [Daemon] counts; the same key elsewhere is ignored.
daemon_has_device_scale() {
  awk '
    /^[[:space:]]*\[/ { in_daemon = (tolower($0) ~ /^[[:space:]]*\[daemon\][[:space:]]*$/) }
    in_daemon && /^[[:space:]]*[Dd][Ee][Vv][Ii][Cc][Ee][Ss][Cc][Aa][Ll][Ee][[:space:]]*=/ { found = 1 }
    END { exit !found }
  ' "$1"
}

# Directories holding the images the rebuild writes: the ESP (UKIs) and /boot.
boot_image_dirs() {
  local esp
  if [[ -n ${OMARCHY_BOOT_IMAGE_DIRS:-} ]]; then
    echo "$OMARCHY_BOOT_IMAGE_DIRS"
    return
  fi
  esp=$(sed -n 's/^ESP_PATH=["'\'']\?\([^"'\'']*\).*/\1/p' /etc/default/limine 2>/dev/null | tail -n 1)
  echo "${esp:-/boot} /boot"
}

if [[ -f $conf ]]; then
  if ! daemon_has_device_scale "$conf"; then
    tmp=$(mktemp)
    awk '
      { print }
      !done && tolower($0) ~ /^[[:space:]]*\[daemon\][[:space:]]*$/ { print "DeviceScale=1"; done = 1 }
      END { if (!done) print "\n[Daemon]\nDeviceScale=1" }
    ' "$conf" >"$tmp"
    sudo cp "$tmp" "$conf"
    rm -f "$tmp"
  fi

  stamp=$(mktemp)

  if omarchy-cmd-present limine-mkinitcpio; then
    sudo limine-mkinitcpio
  else
    sudo mkinitcpio -P
  fi

  # limine-mkinitcpio carries on past an image it could not build and still
  # exits 0. Done means a boot image was written after the rebuild started;
  # otherwise the migration stays pending and the next update retries it.
  rebuilt=$(sudo find $(boot_image_dirs) -maxdepth 4 -type f \( -name '*.img' -o -name '*.efi' \) -newer "$stamp" 2>/dev/null | head -n 1)
  rm -f "$stamp"
  if [[ -z $rebuilt ]]; then
    echo "The rebuild wrote no boot image, so Plymouth keeps its old device scale; rerun omarchy-migrate after fixing the image build." >&2
    exit 1
  fi
fi
