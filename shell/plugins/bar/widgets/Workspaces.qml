import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  function workspaceNeedsAttention(workspace) {
    if (!workspace || !workspace.toplevels) return false
    try {
      var values = workspace.toplevels.values
      if (!values || values.length === 0) return false
      for (var i = 0; i < values.length; i++) {
        var toplevel = values[i]
        if (!toplevel) continue
        // Check for urgent flag (Hyprland standard)
        if (toplevel.urgent === true) return true
        // Check for demandsAttention flag (Wayland standard)
        if (toplevel.demandsAttention === true) return true
        // Some WMs use a string "urgent" instead of boolean
        if (toplevel.urgent === "true" || toplevel.urgent === "1") return true
      }
    } catch (e) {
      // If any property access fails, log and return false
      console.warn("Error checking workspace attention:", e)
    }
    return false
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        readonly property bool needsAttention: workspace !== null && root.workspaceNeedsAttention(workspace)
        readonly property real baseOpacity: occupied || focused ? 1 : 0.5
        readonly property bool shouldFlash: needsAttention && !focused

        id: workspaceButton
        bar: root.bar
        text: focused ? "\uDB85\uDCFB" : (modelData === 10 ? "0" : String(modelData))
        opacity: shouldFlash ? _flashOpacity : baseOpacity
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }

        // Flash opacity property - starts at base opacity value
        property real _flashOpacity: baseOpacity

        // Animation: smooth pulse effect when workspace needs attention
        // Uses SequentialAnimation for fade in/out cycle
        SequentialAnimation {
          id: flashAnimation
          running: shouldFlash
          loops: Animation.Infinite
          PropertyAnimation {
            target: workspaceButton
            property: "_flashOpacity"
            from: baseOpacity
            to: 0.4
            duration: 400
            easing.type: Easing.InOutQuad
          }
          PropertyAnimation {
            target: workspaceButton
            property: "_flashOpacity"
            from: 0.4
            to: baseOpacity
            duration: 400
            easing.type: Easing.InOutQuad
          }
        }

        // Reset flash opacity when flash state changes to false
        // This ensures smooth transition when flashing stops
        onShouldFlashChanged: {
          if (!shouldFlash) {
            _flashOpacity = baseOpacity
            flashAnimation.stop()
          } else if (shouldFlash && !flashAnimation.running) {
            _flashOpacity = baseOpacity
            flashAnimation.start()
          }
        }
      }
    }
  }
}
