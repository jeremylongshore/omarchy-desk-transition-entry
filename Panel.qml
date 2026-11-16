import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
// Qt 6.12 adds its own Color type, so Omarchy's palette singleton must be
// qualified (docs/omarchy-shell.md, Theme tokens).
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.jeremylongshore.desk-transition"
  ipcTarget: "io.github.jeremylongshore.desk-transition"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool openedFromHotkey: false
  readonly property var barIdentity: hostWidget || root
  readonly property string helperPath: Model.localPath(Qt.resolvedUrl("bin/desk-transition").toString())
  property var state: ({ valid: false, monitors: [], disabled: 0 })
  property bool loaded: false
  // The keyboard row: 0 Desk, 1 Laptop, then each active output. -1 is none, so
  // Enter on a freshly opened panel applies nothing.
  property int selected: -1
  property string actionStatus: ""
  readonly property bool isAlert: false
  readonly property string label: loaded ? Model.pillText(state) : "DESK"
  readonly property string tooltip: loaded ? Model.tooltipText(state) : "Reading local display state…"

  // Every fill and outline below comes from the theme, so the cards read on a
  // light theme as well as a dark one.
  readonly property color ink: root.bar ? root.bar.foreground : Commons.Color.foreground
  readonly property color inkDim: root.bar ? Qt.darker(root.bar.foreground, 1.3) : Commons.Color.muted
  readonly property color cardFill: Style.hoverFillFor(root.ink, Commons.Color.accent)
  readonly property color cardPickedFill: Style.selectedFillFor(root.ink, Commons.Color.accent)
  readonly property color cardBorder: Style.normalBorderFor(root.ink, Commons.Color.accent)

  function open() { openedFromHotkey = false; selected = -1; controller.show(); refresh() }
  function openFromHotkey() { openedFromHotkey = true; selected = -1; controller.show(); refresh() }
  function close() { controller.hide() }
  function toggle() { if (opened) close(); else openFromHotkey() }
  function switchPanel(direction) { return bar && typeof bar.switchPanelFrom === "function" ? bar.switchPanelFrom(barIdentity, direction) : false }
  function refresh() { if (!scan.running) scan.running = true }
  function run(args) {
    if (action.running) return
    root.actionStatus = "Applying display scene…"
    action.command = [helperPath].concat(args)
    action.running = true
  }
  function activateSelected() {
    var args = Model.actionArgs(root.selected, root.state)
    if (args) root.run(args)
  }

  Process {
    id: scan
    command: [root.helperPath, "--scan"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: { var next = Model.parse(text); if (next.valid) { root.state = next; root.loaded = true; root.selected = Model.clampSelection(root.selected, Model.rowCount(next)) } } }
  }
  Process {
    id: action
    command: []
    // 0 applied, 3 nothing matched (no internal display, or no active output),
    // anything else means Hyprland did not accept the scene.
    onExited: function(code) {
      root.actionStatus = code === 0
        ? "Scene applied. Active display state refreshed."
        : (code === 3
          ? "No matching active display, so nothing changed. Active display state refreshed."
          : "Scene did not complete. Active display state refreshed.")
      root.refresh()
    }
  }
  Timer { interval: 15000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { if (root.hostWidget && typeof root.hostWidget.broadcast === "function") root.hostWidget.broadcast("refresh"); else root.refresh() }
    function desk(): void { root.run(["--desk"]) }
    function laptop(): void { root.run(["--laptop"]) }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keys
    contentWidth: panel.fittedContentWidth(Style.space(500))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        root.selected = Model.moveSelection(root.selected, Model.rowCount(root.state), dx, dy)
        if (root.selected < 2) flick.contentY = 0
      }
      onActivateRequested: root.activateSelected()

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // Scroll a keyboard-selected output row into view.
        function reveal(top, rowHeight) {
          if (top < contentY) contentY = top
          else if (top + rowHeight > contentY + height) contentY = top + rowHeight - height
        }

        Column {
          id: content
          width: parent.width
          spacing: Style.space(10)

          PanelHero {
            title: "DISPLAY SCENES"
            meta: "Arrange active outputs. Never turn one off."
            foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }
          PanelSeparator { foreground: root.bar ? root.bar.foreground : Commons.Color.foreground }

          Row {
            x: Style.space(16)
            width: parent.width - Style.space(32)
            spacing: Style.space(10)

            Rectangle {
              readonly property bool picked: root.selected === 0
              width: (parent.width - parent.spacing) / 2
              height: Style.space(138)
              color: picked ? root.cardPickedFill : root.cardFill
              border.color: picked ? Commons.Color.accent : root.cardBorder
              border.width: picked ? 2 : 1
              Accessible.role: Accessible.Button
              Accessible.name: "Apply Desk scene"
              Accessible.onPressAction: root.run(["--desk"])
              Column {
                anchors.fill: parent
                anchors.margins: Style.space(12)
                spacing: Style.space(7)
                Text { text: "DESK SCENE"; textFormat: Text.PlainText; width: parent.width; elide: Text.ElideRight; color: root.ink; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body; font.bold: true; font.letterSpacing: 1 }
                Row {
                  width: parent.width
                  height: Style.space(34)
                  spacing: Style.space(7)
                  Rectangle { width: (parent.width - parent.spacing) / 2; height: parent.height; color: "transparent"; border.color: Commons.Color.accent; border.width: 1 }
                  Rectangle { width: (parent.width - parent.spacing) / 2; height: parent.height; color: "transparent"; border.color: Commons.Color.accent; border.width: 1 }
                }
                Text { text: "Lay active displays out left to right."; textFormat: Text.PlainText; width: parent.width; wrapMode: Text.WordWrap; color: root.inkDim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall }
              }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.run(["--desk"]) }
            }

            Rectangle {
              readonly property bool picked: root.selected === 1
              width: (parent.width - parent.spacing) / 2
              height: Style.space(138)
              color: picked ? root.cardPickedFill : root.cardFill
              border.color: picked ? Commons.Color.accent : root.cardBorder
              border.width: picked ? 2 : 1
              Accessible.role: Accessible.Button
              Accessible.name: "Apply Laptop scene"
              Accessible.onPressAction: root.run(["--laptop"])
              Column {
                anchors.fill: parent
                anchors.margins: Style.space(12)
                spacing: Style.space(7)
                Text { text: "LAPTOP SCENE"; textFormat: Text.PlainText; width: parent.width; elide: Text.ElideRight; color: root.ink; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body; font.bold: true; font.letterSpacing: 1 }
                Rectangle { width: parent.width * 0.58; height: Style.space(34); color: "transparent"; border.color: root.inkDim; border.width: 1 }
                Text { text: "Focus your internal panel without disabling outputs."; textFormat: Text.PlainText; width: parent.width; wrapMode: Text.WordWrap; color: root.inkDim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall }
              }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.run(["--laptop"]) }
            }
          }

          Text {
            visible: root.actionStatus !== ""
            x: Style.space(16)
            width: parent.width - Style.space(32)
            text: root.actionStatus
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: root.ink
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            Accessible.role: Accessible.StaticText
            Accessible.name: root.actionStatus
          }

          Column {
            visible: root.loaded && root.state.monitors.length === 0
            width: parent.width
            spacing: Style.space(4)
            PanelSectionHeader { text: "WAITING FOR DISPLAYS"; leftPadding: Style.space(16); foreground: root.bar ? root.bar.foreground : Commons.Color.foreground; fontFamily: root.bar ? root.bar.fontFamily : Style.font.family }
            Text { anchors.left: parent.left; anchors.leftMargin: Style.space(16); width: parent.width - Style.space(32); text: "No active outputs were reported by Hyprland. Connect a display, then choose a scene."; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: root.bar ? Qt.darker(root.bar.foreground, 1.3) : Commons.Color.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall }
          }

          Column {
            visible: root.state.monitors.length > 0
            width: parent.width
            spacing: Style.space(4)
            PanelSectionHeader { text: root.state.monitors.length + " ACTIVE OUTPUTS"; leftPadding: Style.space(16); foreground: root.bar ? root.bar.foreground : Commons.Color.foreground; fontFamily: root.bar ? root.bar.fontFamily : Style.font.family }
            Repeater {
              model: root.state.monitors
              Rectangle {
                required property var modelData
                required property int index
                readonly property bool picked: root.selected === index + 2
                readonly property color selectedFill: root.bar ? Qt.lighter(root.bar.background, 1.12) : Qt.lighter(Commons.Color.background, 1.12)
                x: Style.space(12)
                width: content.width - Style.space(24)
                height: Style.space(34)
                radius: Style.space(3)
                color: picked ? root.cardPickedFill : (modelData.focused ? selectedFill : "transparent")
                border.color: picked ? Commons.Color.accent : (modelData.focused ? root.ink : (root.bar ? Qt.darker(root.bar.foreground, 1.7) : Qt.darker(Commons.Color.foreground, 1.7)))
                border.width: picked ? 2 : 1
                onPickedChanged: if (picked) flick.reveal(mapToItem(content, 0, 0).y, height)
                Accessible.role: Accessible.Button
                Accessible.name: "Focus " + modelData.name
                Accessible.onPressAction: root.run(["--focus", modelData.name])
                Text { anchors.left: parent.left; anchors.leftMargin: Style.space(8); anchors.right: parent.right; anchors.rightMargin: Style.space(8); anchors.verticalCenter: parent.verticalCenter; text: modelData.name + "  " + modelData.width + "×" + modelData.height + (modelData.focused ? "  · FOCUSED" : ""); textFormat: Text.PlainText; elide: Text.ElideRight; color: modelData.focused ? root.ink : root.inkDim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: modelData.focused }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.run(["--focus", modelData.name]) }
              }
            }
          }
          Rectangle {
            x: Style.space(12)
            width: parent.width - Style.space(24)
            height: Style.space(36)
            radius: Style.space(3)
            color: root.cardFill
            border.color: root.cardBorder
            border.width: 1
            Text {
              anchors.centerIn: parent
              width: parent.width - Style.space(16)
              text: Model.inventoryText(root.state, root.loaded)
              textFormat: Text.PlainText
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              color: root.ink
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              font.letterSpacing: 1
            }
            Accessible.role: Accessible.StaticText
            Accessible.name: Model.inventorySpoken(root.state, root.loaded)
          }
          Item { width: 1; height: Style.space(6) }
        }
      }
    }
  }
}
