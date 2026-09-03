import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omastreamer"

  property bool popupOpen: false

  readonly property var streamer: bar && bar.shell ? bar.shell.serviceFor("omastreamer") : null
  readonly property bool connected: streamer ? streamer.connected : false
  readonly property string sceneName: streamer ? streamer.sceneName : ""
  readonly property var scenes: streamer && streamer.scenes ? streamer.scenes : []
  readonly property bool streaming: streamer ? streamer.streaming : false
  readonly property bool recording: streamer ? streamer.recording : false
  readonly property bool muted: streamer ? streamer.muted : false
  readonly property string error: streamer ? streamer.error : ""

  readonly property string liveLabel: {
    if (!connected)
      return root.vertical ? "󰕧" : "OBS"
    if (root.vertical)
      return recording ? "󰻂" : (streaming ? "󰻃" : "󰕧")
    var name = sceneName !== "" ? sceneName : "OBS"
    var bits = []
    if (streaming)
      bits.push("LIVE")
    if (recording)
      bits.push("REC")
    if (muted)
      bits.push("MUTE")
    return bits.length ? bits.join(" · ") + "  " + name : name
  }

  readonly property color liveColor: {
    if (!connected)
      return Color.muted
    if (streaming || recording)
      return Color.urgent
    return root.bar ? root.bar.barForeground : Color.foreground
  }

  readonly property bool opened: popupOpen

  function open() { popupOpen = true }
  function close() { popupOpen = false }
  function togglePanel() { popupOpen = !popupOpen }
  function closeForPopoutSwitch() { popupOpen = false }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.liveLabel
    foreground: root.liveColor
    useActiveColor: false
    tooltipText: root.connected
      ? (root.sceneName || "OBS") + (root.error ? "\n" + root.error : "")
      : (root.error || "OBS websocket offline")
    horizontalMargin: 8.75
    verticalPadding: 8.75

    onPressed: function(b) {
      if (b === Qt.RightButton) {
        if (root.streamer)
          root.streamer.nextScene()
      } else if (b === Qt.MiddleButton) {
        if (root.streamer)
          root.streamer.toggleMute()
      } else {
        root.togglePanel()
      }
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(280))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      width: parent.width
      spacing: Style.space(8)

      Text {
        width: parent.width
        text: root.connected ? "omastreamer" : "OBS offline"
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Text {
        width: parent.width
        visible: !root.connected
        wrapMode: Text.WordWrap
        text: root.error || "Enable Tools → WebSocket Server Settings, then restart OBS."
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Repeater {
        model: root.scenes

        Button {
          required property int index
          required property string modelData
          width: column.width
          text: (index + 1) + "  " + modelData
          selected: modelData === root.sceneName
          foreground: Color.popups.text
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          onClicked: {
            if (root.streamer)
              root.streamer.setScene(modelData)
          }
        }
      }

      Row {
        spacing: Style.space(6)
        visible: root.connected

        Button {
          text: root.streaming ? "Stop stream" : "Stream"
          active: root.streaming
          foreground: Color.popups.text
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          onClicked: if (root.streamer) root.streamer.toggleStream()
        }

        Button {
          text: root.recording ? "Stop rec" : "Record"
          active: root.recording
          foreground: Color.popups.text
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          onClicked: if (root.streamer) root.streamer.toggleRecord()
        }

        Button {
          text: root.muted ? "Unmute" : "Mute all"
          active: root.muted
          foreground: Color.popups.text
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          onClicked: if (root.streamer) root.streamer.toggleMute()
        }
      }
    }
  }
}
