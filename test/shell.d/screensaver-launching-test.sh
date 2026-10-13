#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin"
# Another window holds focus, as it does between the launcher focusing a monitor and its screensaver mapping.
printf '#!/bin/bash\n[[ $1 == activewindow ]] && echo "{\\"class\\":\\"other\\"}"\n' >"$tmpdir/bin/hyprctl"
printf '#!/bin/bash\nexit 0\n' >"$tmpdir/bin/pgrep"
printf '#!/bin/bash\nsleep 5\n' >"$tmpdir/bin/ttfx"
printf '#!/bin/bash\nprintf "%%s\\n" "$*" >>"$TEST_DIR/pkill"\n' >"$tmpdir/bin/pkill"
chmod +x "$tmpdir/bin/"*

run_watchdog() {
  # stdin stays open and silent, so the only way out is the focus check.
  { sleep 4 | PATH="$tmpdir/bin:$PATH" TEST_DIR="$tmpdir" XDG_RUNTIME_DIR="$tmpdir" timeout -s KILL 2.5 "$ROOT/bin/omarchy-screensaver" >/dev/null 2>&1; } 2>/dev/null || true
}

touch "$tmpdir/omarchy-screensaver-launching"
run_watchdog
[[ -e $tmpdir/pkill ]] && fail "a screensaver stays up while the launcher is still moving focus between monitors" "$(<"$tmpdir/pkill")"
pass "a screensaver stays up while the launcher is still moving focus between monitors"

rm "$tmpdir/omarchy-screensaver-launching"
run_watchdog
[[ -e $tmpdir/pkill ]] || fail "a screensaver still closes when focus is lost after the launch" "no pkill"
pass "a screensaver still closes when focus is lost after the launch"
