#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

run_node_test <<'JS'
const fs = require('fs')
const src = fs.readFileSync(path.join(root, 'shell/plugins/panels/monitor/Panel.qml'), 'utf8')

assert(/onReleased: function\(v\) \{ root\.selectTextSize\(Math\.round\(v\)\) \}/.test(src), 'text size slider release goes through selectTextSize')

function fn(name) {
  const m = src.match(new RegExp('^  function ' + name + '\\(.*?^  \\}', 'ms'))
  if (!m) throw new Error('missing ' + name)
  return m[0].replace(/^  function /, 'function ')
}

// Run the panel's own text-size functions against a fake root.
function select(basePx, idx, pending = -1) {
  const root = {
    textSizeStops: [9, 10, 11, 12, 14, 16, 20],
    textSizePreviewIndex: pending,
    Style: { font: { baseSize: basePx } },
    textScaleProc: { command: null, running: false },
    markReflowing() {}
  }
  const names = ['nearestTextStop', 'currentTextIndex', 'displayedTextPx', 'setTextSize', 'adjustTextSize', 'selectTextSize']
  const body = names.map(fn).join('\n')
  new Function('root', 'with (root) {' + body + '\nselectTextSize(' + idx + ') }')(root)
  return root
}

let r = select(12, 5)
assertDeepEqual(r.textScaleProc.command, ['omarchy-display-text-size', '16'], '12px to 16px runs the command')
assertEqual(r.textSizePreviewIndex, 5, '12px to 16px holds the pending stop')

r = select(13, 3)
assertDeepEqual(r.textScaleProc.command, ['omarchy-display-text-size', '12'], '13px to the 12px stop still runs the command')
assertEqual(r.textSizePreviewIndex, 3, '13px to 12px holds the pending stop')

r = select(12, 3)
assertEqual(r.textScaleProc.command, null, 'selecting the size already in effect does nothing')
assertEqual(r.textSizePreviewIndex, -1, 'selecting the size already in effect leaves no pending stop')
JS
