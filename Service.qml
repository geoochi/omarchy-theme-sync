import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  // Injected by omarchy-shell (the service loader).
  property var shell: null

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string configPath: home + "/.config/omarchy/theme-sync/config.json"
  readonly property string currentThemePath: home + "/.local/state/omarchy/current/theme.name"

  // Defaults. Any of them is overridden by ~/.config/omarchy/theme-sync/config.json.
  property string lightTheme: "catppuccin-latte"
  property string darkTheme: "tokyo-night"
  property int lightFrom: 7
  property int darkFrom: 19
  property int checkIntervalMinutes: 10

  // auto follows the schedule; light and dark pin the theme. Persisted in the
  // state directory and settable from the bar widget, IPC, or by editing the
  // file.
  property string mode: "auto"
  readonly property var knownModes: ["auto", "light", "dark"]
  readonly property string modePath: home + "/.local/state/omarchy/theme-sync/mode"

  property string currentTheme: ""
  property int lastCheckedHour: -1

  readonly property string wantedTheme: {
    if (mode === "light") return lightTheme
    if (mode === "dark") return darkTheme
    return isDaytime(lastCheckedHour) ? lightTheme : darkTheme
  }
  // Only the configured pair is switched. Anything else -- a theme picked by
  // hand, or a third theme entirely -- is left alone.
  readonly property bool managingCurrentTheme: currentTheme === lightTheme || currentTheme === darkTheme

  function isDaytime(hour) {
    return hour >= lightFrom && hour < darkFrom
  }

  function clampHour(value) {
    return Math.min(23, Math.max(0, Math.round(value)))
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  // Applies the theme the schedule asks for, and nothing else: no match, no
  // change, and at most one `omarchy-theme-set` in flight. Timer ticks pass no
  // argument and do nothing while the mode is pinned; an explicit action
  // (config saved, mode set, applyNow) passes force to sync immediately.
  function apply(force) {
    lastCheckedHour = new Date().getHours()

    if (!force) {
      if (mode !== "auto")
        return
      if (!managingCurrentTheme)
        return
    }
    if (currentTheme === wantedTheme)
      return
    if (applyProcess.running)
      return

    applyProcess.command = ["bash", "-lc", "omarchy-theme-set " + shellQuote(wantedTheme)]
    applyProcess.running = true
  }

  function setMode(value) {
    var next = String(value || "").trim().toLowerCase()
    if (knownModes.indexOf(next) === -1)
      return

    mode = next
    modeFile.setText(mode + "\n")
    apply(true)
  }

  function loadMode(raw) {
    var next = String(raw || "").trim().toLowerCase()
    if (knownModes.indexOf(next) === -1)
      return

    mode = next
    // A pinned mode is re-asserted on login; auto just syncs the schedule.
    apply(mode !== "auto")
  }

  function resetConfig() {
    lightTheme = "catppuccin-latte"
    darkTheme = "tokyo-night"
    lightFrom = 7
    darkFrom = 19
    checkIntervalMinutes = 10
    apply(true)
  }

  function loadConfig(raw) {
    var parsed = null
    try {
      parsed = JSON.parse(raw)
    } catch (e) {
      return
    }

    if (!parsed || typeof parsed !== "object")
      return

    if (typeof parsed.lightTheme === "string" && parsed.lightTheme)
      lightTheme = parsed.lightTheme
    if (typeof parsed.darkTheme === "string" && parsed.darkTheme)
      darkTheme = parsed.darkTheme
    if (typeof parsed.lightFrom === "number")
      lightFrom = clampHour(parsed.lightFrom)
    if (typeof parsed.darkFrom === "number")
      darkFrom = clampHour(parsed.darkFrom)
    if (typeof parsed.checkIntervalMinutes === "number" && parsed.checkIntervalMinutes >= 1)
      checkIntervalMinutes = Math.round(parsed.checkIntervalMinutes)

    apply(true)
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.loadConfig(text())
    // A deleted config falls back to the defaults on the next read.
    onLoadFailed: root.resetConfig()
  }

  FileView {
    id: currentThemeFile
    path: root.currentThemePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    // A theme the user sets by hand is recorded but not undone here; the next
    // timer tick is what brings the pair back into line.
    onLoaded: root.currentTheme = String(text() || "").trim()
  }

  FileView {
    id: modeFile
    path: root.modePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.loadMode(text())
  }

  Timer {
    interval: Math.max(1, root.checkIntervalMinutes) * 60000
    repeat: true
    running: true
    // Reloading here also catches a config.json written after the shell
    // started: until it exists there is nothing for watchChanges to watch.
    onTriggered: {
      configFile.reload()
      root.apply()
    }
  }

  Process {
    id: applyProcess
  }

  Component.onCompleted: root.apply()

  IpcHandler {
    target: "theme-sync"

    function status(): string {
      return JSON.stringify({
        mode: root.mode,
        currentTheme: root.currentTheme,
        wantedTheme: root.wantedTheme,
        hour: root.lastCheckedHour,
        lightTheme: root.lightTheme,
        darkTheme: root.darkTheme,
        lightFrom: root.lightFrom,
        darkFrom: root.darkFrom,
        checkIntervalMinutes: root.checkIntervalMinutes,
        managing: root.managingCurrentTheme
      })
    }

    function setMode(value: string): string {
      root.setMode(value)
      return root.mode
    }

    function cycleMode(): string {
      var order = root.knownModes
      root.setMode(order[(order.indexOf(root.mode) + 1) % order.length])
      return root.mode
    }

    function applyNow(): string {
      root.apply(true)
      return root.wantedTheme
    }

    function reload(): string {
      configFile.reload()
      currentThemeFile.reload()
      return "reloaded"
    }
  }
}
