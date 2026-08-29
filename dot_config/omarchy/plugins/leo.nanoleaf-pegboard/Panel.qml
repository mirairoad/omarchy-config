import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar widget for the Nanoleaf Pegboard Desk Dock.
//
// This is a thin face over the `nanoleaf-pegboard` CLI — every click shells out
// to the same commands a user would type, and every command answers with the
// resulting state, so the panel repaints from the daemon's truth rather than
// guessing. The only optimistic update is the brightness slider, which has to
// track the drag.
Panel {
  id: root
  moduleName: "leo.nanoleaf-pegboard"
  ipcTarget: moduleName

  // ---- Mirrored from `nanoleaf-pegboard status --json` ----
  property bool daemonRunning: false
  property bool deviceConnected: false
  property bool lit: false
  property int brightness: 0
  property string ledColor: "#000000"
  property string mode: "solid"
  property real waveSpeed: 1.0
  property bool loaded: false

  // While a slider drag is in flight the daemon lags the knob; show the knob.
  property int pendingBrightness: -1

  property var palette: []

  readonly property string cli: root.setting("command", "nanoleaf-pegboard")
  readonly property int pollMs: Math.max(500, root.setting("pollMs", 4000))
  readonly property int scrollStep: Math.max(1, root.setting("scrollStep", 5))
  readonly property bool hideWhenUnplugged: root.setting("hideWhenUnplugged", false) === true
  // Off by default: see the onPressed comment below.
  readonly property bool extraMouseButtons: root.setting("extraMouseButtons", false) === true

  readonly property bool waving: root.mode === "wave"
  readonly property bool usable: root.daemonRunning && root.deviceConnected
  readonly property int shownBrightness: root.pendingBrightness >= 0 ? root.pendingBrightness : root.brightness

  // Material Design Icons from the Nerd Font: lightbulb, lightbulb-on, waves.
  readonly property string barGlyph: !root.lit || !root.usable ? "󰌵" : (root.waving ? "󰞍" : "󰛨")

  readonly property string statusLine: {
    if (!root.daemonRunning) return "Driver not running"
    if (!root.deviceConnected) return "Dock not connected"
    if (!root.lit) return "Off"
    return root.shownBrightness + "% · " + (root.waving ? "Wave" : "Solid")
  }

  // ---- Talking to the CLI ----

  function refresh() {
    statusProc.running = false
    statusProc.running = true
  }

  // Fire a CLI command and re-read state when it exits. Restarting the process
  // rather than queueing is fine here: the calls are single-digit milliseconds
  // and a burst only ever means "the last click wins", which is what a menu
  // should do anyway.
  function run(args) {
    actionProc.running = false
    actionProc.command = [root.cli].concat(args)
    actionProc.running = true
  }

  function applyStatus(text) {
    root.loaded = true
    var parsed
    try {
      parsed = JSON.parse(text)
    } catch (e) {
      root.daemonRunning = false
      return
    }
    root.daemonRunning = parsed.running === true
    root.deviceConnected = parsed.connected === true
    if (!root.daemonRunning) return
    root.lit = parsed.on === true
    root.brightness = parsed.brightness || 0
    root.ledColor = parsed.color || "#000000"
    root.mode = parsed.mode || "solid"
    root.waveSpeed = parsed.wave_speed || 1.0
    root.pendingBrightness = -1
  }

  // `nanoleaf-pegboard colors` prints "name  #rrggbb" per line. Reading the
  // swatches from the CLI keeps one palette definition in the Rust side.
  function applyPalette(text) {
    var swatches = []
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].trim().split(/\s+/)
      if (parts.length === 2 && parts[1].charAt(0) === "#")
        swatches.push({ name: parts[0], hex: parts[1] })
    }
    root.palette = swatches
  }

  Process {
    id: statusProc
    command: [root.cli, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
    // A missing binary is indistinguishable from a dead daemon as far as the
    // widget is concerned: nothing to control either way.
    onExited: function(code) { if (code !== 0) root.daemonRunning = false; root.loaded = true }
  }

  Process {
    id: paletteProc
    command: [root.cli, "colors"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyPalette(text)
    }
  }

  Process {
    id: actionProc
    onExited: root.refresh()
  }

  // Debounce slider drags so one gesture is not a hundred process spawns.
  Timer {
    id: brightnessCommit
    interval: 70
    onTriggered: if (root.pendingBrightness >= 0) root.run(["brightness", String(root.pendingBrightness)])
  }

  function previewBrightness(value) {
    root.pendingBrightness = Math.round(value)
    brightnessCommit.restart()
  }

  function commitBrightness(value) {
    brightnessCommit.stop()
    root.pendingBrightness = Math.round(value)
    root.run(["brightness", String(root.pendingBrightness)])
  }

  Component.onCompleted: {
    paletteProc.running = true
    root.refresh()
  }

  // Poll slowly in the bar so the icon stays honest, quickly while open so the
  // panel reflects changes made from the CLI in another terminal.
  Timer {
    interval: root.opened ? 1000 : root.pollMs
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  onOpenedChanged: if (root.opened) root.refresh()

  visible: !root.hideWhenUnplugged || !root.loaded || root.usable
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: visible ? button.implicitHeight : 0

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barGlyph
    // Dim rather than hide when there is nothing to talk to, so the icon does
    // not shuffle the bar layout every time the dock is unplugged.
    dimmed: !root.usable
    tooltipText: root.opened ? "" : "Pegboard · " + root.statusLine

    // Right- and middle-click shortcuts are opt-in (`extraMouseButtons`).
    //
    // On Qt 6.11.2, a right-click that QML does not consume makes Qt synthesize
    // a QContextMenuEvent, and QQuickDeliveryAgentPrivate::contextMenuTargets
    // then calls mapToScene on an item that is already gone — segfaulting the
    // whole shell. WidgetButton's MouseArea does accept the right button, so
    // this widget is probably not on that path, but "probably" is not worth a
    // dead bar for a shortcut the menu already offers. Scroll is unaffected:
    // wheel events never go through context-menu synthesis.
    onPressed: function(b) {
      if (b === Qt.RightButton || b === Qt.MiddleButton) {
        if (!root.extraMouseButtons) return
        root.run(b === Qt.RightButton ? ["toggle"] : ["wave", "toggle"])
        return
      }
      root.toggle()
    }

    onWheelMoved: function(delta) {
      if (!root.usable) return
      root.run([(delta > 0 ? "+" : "-") + root.scrollStep])
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // ---------- Hero: state at a glance, plus the master switch ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroText.implicitHeight, heroSwitch.implicitHeight)

          Text {
            id: heroIcon
            text: root.barGlyph
            color: root.usable && root.lit ? root.ledColor : Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: 200 } }
          }

          Column {
            id: heroText
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(12)
            anchors.right: heroSwitch.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Pegboard"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.statusLine.toUpperCase()
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          ToggleSwitch {
            id: heroSwitch
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.lit
            onToggled: root.run(["toggle"])
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ---------- Brightness ----------
        Item {
          width: parent.width
          implicitHeight: brightnessHeader.implicitHeight

          PanelSectionHeader {
            id: brightnessHeader
            text: "Brightness"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            anchors.left: parent.left
          }

          Text {
            text: root.shownBrightness + "%"
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.right: parent.right
            anchors.baseline: brightnessHeader.baseline
          }
        }

        PanelSlider {
          width: parent.width
          bar: root.bar
          minimum: 0
          maximum: 100
          step: 5
          integer: true
          value: root.shownBrightness
          onMoved: function(value) { root.previewBrightness(value) }
          onReleased: function(value) { root.commitBrightness(value) }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ---------- Preset colors ----------
        PanelSectionHeader {
          text: "Color"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        Grid {
          id: swatches
          width: parent.width
          columns: 7
          spacing: Style.space(6)

          readonly property real cell: Math.floor((width - spacing * (columns - 1)) / columns)

          Repeater {
            model: root.palette

            Rectangle {
              required property var modelData

              width: swatches.cell
              height: swatches.cell
              radius: Style.cornerRadius > 0 ? Math.max(3, Style.cornerRadius) : 0
              color: modelData.hex
              // The active swatch gets a ring in the bar foreground so it reads
              // against both light and dark presets.
              border.width: root.ledColor.toLowerCase() === modelData.hex.toLowerCase() && !root.waving ? 2 : 0
              border.color: root.bar.foreground
              opacity: swatchMouse.containsMouse ? 1.0 : 0.88

              Behavior on opacity { NumberAnimation { duration: 120 } }

              MouseArea {
                id: swatchMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.run(["color", modelData.name])
                onEntered: root.bar.showTooltip(parent, modelData.name)
                onExited: root.bar.hideTooltip(parent)
              }
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ---------- Effects and lifecycle ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(waveButton.implicitHeight, quitButton.implicitHeight)

          Button {
            id: waveButton
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰞍"
            text: "Wave"
            selected: root.waving
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onClicked: root.run(["wave", "toggle"])
          }

          Button {
            id: quitButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰐥"
            text: "Quit"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            tooltipText: "Stop the driver — the dock falls back to its built-in animation"
            onClicked: {
              root.close()
              root.run(["quit"])
            }
          }
        }
      }
    }
  }
}
