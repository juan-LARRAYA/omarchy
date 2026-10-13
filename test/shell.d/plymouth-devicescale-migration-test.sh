#!/bin/bash

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

migration="$ROOT/migrations/1791770000.sh"
[[ -f $migration ]] || fail "the Plymouth DeviceScale migration exists"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Stub every privileged and initramfs command; the test never touches /etc.
stub_bin="$TMPDIR/bin"
mkdir -p "$stub_bin"
rebuild_log="$TMPDIR/rebuilds"
cat >"$stub_bin/sudo" <<'STUB'
#!/bin/bash
exec "$@"
STUB
cat >"$stub_bin/omarchy-cmd-present" <<'STUB'
#!/bin/bash
[[ $1 == limine-mkinitcpio && ${HAVE_LIMINE:-1} == 1 ]]
STUB
cat >"$stub_bin/limine-mkinitcpio" <<STUB
#!/bin/bash
echo limine >>"$rebuild_log"
[[ \${FAIL_REBUILD:-0} == 0 ]]
STUB
cat >"$stub_bin/mkinitcpio" <<STUB
#!/bin/bash
echo "mkinitcpio \$*" >>"$rebuild_log"
[[ \${FAIL_REBUILD:-0} == 0 ]]
STUB
chmod +x "$stub_bin"/*

conf="$TMPDIR/plymouthd.conf"
run_migration() {
  PATH="$stub_bin:$PATH" OMARCHY_PLYMOUTHD_CONF="$conf" bash -euo pipefail "$migration" >/dev/null
}
rebuilds() { [[ -f $rebuild_log ]] && wc -l <"$rebuild_log" || echo 0; }

# Config without the key: edited, then rebuilt
printf '[Daemon]\nTheme=omarchy\n' >"$conf"
: >"$rebuild_log"
run_migration || fail "the migration succeeds on a config without DeviceScale"
[[ $(grep -c '^DeviceScale=1$' "$conf") == 1 ]] || fail "the migration adds DeviceScale=1" "$(cat "$conf")"
grep -qx 'Theme=omarchy' "$conf" || fail "the migration keeps the existing settings"
(( $(rebuilds) == 1 )) || fail "the migration rebuilds the initramfs after editing"
pass "a config without the key is edited and rebuilt"

# Spaced section and no section at all
printf '  [Daemon]  \nTheme=omarchy\n' >"$conf"
run_migration || fail "the migration handles a spaced [Daemon] header"
grep -qx 'DeviceScale=1' "$conf" || fail "the key lands under a spaced [Daemon] header" "$(cat "$conf")"
printf 'Theme=omarchy\n' >"$conf"
run_migration || fail "the migration handles a config without [Daemon]"
grep -qx '\[Daemon\]' "$conf" && grep -qx 'DeviceScale=1' "$conf" || fail "a missing section is created" "$(cat "$conf")"
pass "section headers with spaces or missing are handled"

# Already updated config (as the package leaves it): still rebuilds, no rewrite
printf '[Daemon]\nDeviceScale = 1\nTheme=omarchy\n' >"$conf"
cp "$conf" "$TMPDIR/before"
: >"$rebuild_log"
run_migration || fail "the migration succeeds on an updated config"
cmp -s "$conf" "$TMPDIR/before" || fail "an updated config is left alone"
(( $(rebuilds) == 1 )) || fail "an updated config still gets a rebuild"
pass "an already updated config is still rebuilt"

# Rebuild failure fails the migration; the retry rebuilds again
printf '[Daemon]\nTheme=omarchy\n' >"$conf"
: >"$rebuild_log"
FAIL_REBUILD=1 run_migration && fail "a failed rebuild fails the migration"
grep -qx 'DeviceScale=1' "$conf" || fail "the edit is kept after a failed rebuild"
run_migration || fail "the retry succeeds once the rebuild works"
(( $(rebuilds) == 2 )) || fail "the retry rebuilds again" "$(cat "$rebuild_log")"
pass "a failed rebuild is retried"

# Without limine-mkinitcpio, mkinitcpio -P is used
: >"$rebuild_log"
HAVE_LIMINE=0 run_migration || fail "the mkinitcpio fallback succeeds"
grep -qx 'mkinitcpio -P' "$rebuild_log" || fail "the fallback runs mkinitcpio -P" "$(cat "$rebuild_log")"
pass "mkinitcpio -P is the fallback"
