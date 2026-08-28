import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
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
  readonly property string helperPath: Qt.resolvedUrl("bin/desk-transition").toString().replace(/^file:\/\//, "")
  property var state: ({ valid: false, monitors: [] })
  property bool loaded: false
  readonly property bool isAlert: false
  readonly property string label: loaded ? Model.pillText(state) : "DESK"
  readonly property string tooltip: loaded ? Model.tooltipText(state) : "Reading local display state…"

  function open() { openedFromHotkey = false; controller.show(); refresh() }
  function openFromHotkey() { openedFromHotkey = true; controller.show(); refresh() }
  function close() { controller.hide() }
  function toggle() { if (opened) close(); else openFromHotkey() }
  function switchPanel(direction) { return bar && typeof bar.switchPanelFrom === "function" ? bar.switchPanelFrom(barIdentity, direction) : false }
  function refresh() { if (!scan.running) scan.running = true }
  function run(args) { if (!action.running) { action.command = [helperPath].concat(args); action.running = true } }

  Process {
    id: scan
    command: [root.helperPath, "--scan"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: { var next = Model.parse(text); if (next.valid) { root.state = next; root.loaded = true } } }
  }
  Process { id: action; command: []; onExited: root.refresh() }
  Timer { interval: 15000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { if (root.hostWidget && typeof root.hostWidget.broadcast === "function") root.hostWidget.broadcast("refresh"); else root.refresh() }
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

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: content
          width: parent.width
          spacing: Style.space(10)

          PanelHero {
            title: "DISPLAY SCENES"
            meta: "Arrange active outputs. Never turn one off."
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }
          PanelSeparator { foreground: root.bar ? root.bar.foreground : Color.foreground }

          Row {
            x: Style.space(16)
            width: parent.width - Style.space(32)
            spacing: Style.space(10)

            Rectangle {
              width: (parent.width - parent.spacing) / 2
              height: Style.space(138)
              color: "#151b25"
              border.color: "#5b94d6"
              border.width: 1
              Column {
                anchors.fill: parent
                anchors.margins: Style.space(12)
                spacing: Style.space(7)
                Text { text: "DESK SCENE"; textFormat: Text.PlainText; width: parent.width; elide: Text.ElideRight; color: root.bar ? root.bar.foreground : Color.foreground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body; font.bold: true; font.letterSpacing: 1 }
                Row {
                  width: parent.width
                  height: Style.space(34)
                  spacing: Style.space(7)
                  Rectangle { width: (parent.width - parent.spacing) / 2; height: parent.height; color: "transparent"; border.color: "#7aa9df"; border.width: 1 }
                  Rectangle { width: (parent.width - parent.spacing) / 2; height: parent.height; color: "transparent"; border.color: "#7aa9df"; border.width: 1 }
                }
                Text { text: "Lay active displays out left to right."; textFormat: Text.PlainText; width: parent.width; wrapMode: Text.WordWrap; color: root.bar ? Qt.darker(root.bar.foreground, 1.3) : Color.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall }
              }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.run(["--desk"]) }
            }

            Rectangle {
              width: (parent.width - parent.spacing) / 2
              height: Style.space(138)
              color: "#151b25"
              border.color: "#7a9b7a"
              border.width: 1
              Column {
                anchors.fill: parent
                anchors.margins: Style.space(12)
                spacing: Style.space(7)
                Text { text: "LAPTOP SCENE"; textFormat: Text.PlainText; width: parent.width; elide: Text.ElideRight; color: root.bar ? root.bar.foreground : Color.foreground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body; font.bold: true; font.letterSpacing: 1 }
                Rectangle { width: parent.width * 0.58; height: Style.space(34); color: "transparent"; border.color: "#9fc29f"; border.width: 1 }
                Text { text: "Focus your internal panel without disabling outputs."; textFormat: Text.PlainText; width: parent.width; wrapMode: Text.WordWrap; color: root.bar ? Qt.darker(root.bar.foreground, 1.3) : Color.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall }
              }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.run(["--laptop"]) }
            }
          }

          Column {
            visible: root.loaded && root.state.monitors.length === 0
            width: parent.width
            spacing: Style.space(4)
            PanelSectionHeader { text: "WAITING FOR DISPLAYS"; leftPadding: Style.space(16); foreground: root.bar ? root.bar.foreground : Color.foreground; fontFamily: root.bar ? root.bar.fontFamily : Style.font.family }
            Text { anchors.left: parent.left; anchors.leftMargin: Style.space(16); width: parent.width - Style.space(32); text: "No active outputs were reported by Hyprland. Connect a display, then choose a scene."; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: root.bar ? Qt.darker(root.bar.foreground, 1.3) : Color.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall }
          }

          Column {
            visible: root.state.monitors.length > 0
            width: parent.width
            spacing: Style.space(4)
            PanelSectionHeader { text: root.state.monitors.length + " ACTIVE OUTPUTS"; leftPadding: Style.space(16); foreground: root.bar ? root.bar.foreground : Color.foreground; fontFamily: root.bar ? root.bar.fontFamily : Style.font.family }
            Repeater {
              model: root.state.monitors
              Item {
                required property var modelData
                width: content.width
                height: Style.space(28)
                Text { anchors.left: parent.left; anchors.leftMargin: Style.space(16); anchors.verticalCenter: parent.verticalCenter; text: modelData.name + "  " + modelData.width + "×" + modelData.height + (modelData.focused ? "  · FOCUSED" : ""); textFormat: Text.PlainText; width: parent.width - Style.space(32); elide: Text.ElideRight; color: modelData.focused ? (root.bar ? root.bar.foreground : Color.foreground) : (root.bar ? Qt.darker(root.bar.foreground, 1.3) : Color.muted); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.run(["--focus", modelData.name]) }
              }
            }
          }
          Item { width: 1; height: Style.space(6) }
        }
      }
    }
  }
}
