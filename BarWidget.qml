import QtQuick
import Quickshell
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.geoochi.theme-sync"

  readonly property var syncService: bar?.shell?.serviceFor("io.github.geoochi.theme-sync")
  readonly property string mode: syncService ? syncService.mode : "auto"
  readonly property string glyph: mode === "light" ? "󰖙" : mode === "dark" ? "󰖔" : "󰍵"
  readonly property string label: mode === "light" ? "Light" : mode === "dark" ? "Dark" : "Auto"

  function cycleMode() {
    var order = ["auto", "light", "dark"]
    var next = order[(order.indexOf(root.mode) + 1) % order.length]
    if (root.syncService)
      root.syncService.setMode(next)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph + " " + root.label
    tooltipText: "Theme Sync: " + root.label + " — click to switch"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton)
        root.cycleMode()
    }
  }
}
