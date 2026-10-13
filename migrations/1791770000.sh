echo "Pin Plymouth's device scale so the unlock screen stays centred on HiDPI panels"

# plymouthd halves the window size the theme centres with on panels above
# ~192 DPI. The packaged plymouthd.conf now pins DeviceScale=1; the file is
# also copied into the initramfs, so existing installs need it written and the
# initramfs rebuilt for the LUKS prompt to change.

if [[ -f /etc/plymouth/plymouthd.conf ]] && ! grep -qs '^DeviceScale=' /etc/plymouth/plymouthd.conf; then
  sudo sed -i '/^\[Daemon\]/a DeviceScale=1' /etc/plymouth/plymouthd.conf

  if omarchy-cmd-present limine-mkinitcpio; then
    sudo limine-mkinitcpio
  else
    sudo mkinitcpio -P
  fi
fi
