import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "michael.brain"
  ipcTarget: "brain-capture"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  property string payload: ""
  property var recent: []
  property var files: []
  property string message: "Files, links and notes → ~/Brain/raw"
  readonly property string helper: Qt.resolvedUrl("../../../desktop/bin/brain-capture").toString().replace(/^file:\/\//, "")
  function refresh() { if (!listing.running) listing.running = true }
  function submit(clipboard) {
    if (capture.running) return
    capture.command = [helper]
    root.payload = JSON.stringify({text: input.text, files: files, clipboard: clipboard})
    capture.stdinEnabled = true
    capture.running = true
  }
  onOpenedChanged: if (opened) { refresh(); input.forceActiveFocus() }
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰧑"
    tooltipText: "Capture to Brain"
    onPressed: root.toggle()
  }
  IpcHandler {
    target: "brain-input"
    function submit(text: string): void { input.text = text; root.submit(false) }
    function status(): string { return root.message }
  }
  Process {
    id: listing
    command: [root.helper, "history"]
    stdout: StdioCollector { onStreamFinished: { try { root.recent = JSON.parse(text) } catch (e) { root.message = String(e) } } }
  }
  Process {
    id: capture
    stdinEnabled: true
    onStarted: { write(root.payload); stdinEnabled = false }
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var result = JSON.parse(text)
          root.message = result.ok ? (result.duplicate ? "Already captured" : "Saved · queued for processing") : result.error
          if (result.ok) { input.clear(); root.files = [] }
        } catch (e) { root.message = "Capture failed: " + String(e) }
        root.refresh()
      }
    }
  }
  Timer { interval: 3000; repeat: true; running: root.opened; onTriggered: root.refresh() }
  PopupCard {
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: 470
    contentHeight: 455
    ColumnLayout {
      anchors.fill: parent
      spacing: 10
      Text { text: "Capture to Brain"; color: Color.popups.text; font.pixelSize: 22; font.bold: true }
      ScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: 130
        TextArea {
          id: input
          placeholderText: "Type or paste text and links…"
          background: Rectangle { color: "#252535"; radius: 6; border.color: "#45455a" }
          placeholderTextColor: "#9399b2"
          wrapMode: TextEdit.Wrap
          color: Color.popups.text
          selectByMouse: true
          Keys.onPressed: event => {
            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Return) { root.submit(false); event.accepted = true }
          }
        }
      }
      Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 36
        color: drop.containsDrag ? "#4489b4fa" : "#2289b4fa"; radius: 6
        Text { anchors.centerIn: parent; text: root.files.length ? root.files.length + " attached · drop more files here" : "Drop files or links here"; color: Color.popups.text }
        DropArea {
          id: drop; anchors.fill: parent
          onDropped: event => {
            if (event.hasUrls) root.files = root.files.concat(event.urls.map(u => String(u)))
            else if (event.hasText) input.insert(input.length, event.text)
            event.acceptProposedAction()
          }
        }
      }
      RowLayout {
        Button { text: "Paste clipboard"; enabled: !capture.running; onClicked: root.submit(true) }
        Button { text: capture.running ? "Saving…" : "Submit"; enabled: !capture.running; onClicked: root.submit(false) }
      }
      Text { Layout.fillWidth: true; text: root.message; color: Color.popups.text; elide: Text.ElideRight }
      Text { text: "Last 5 captures"; color: Color.popups.text; font.bold: true }
      Repeater {
        model: root.recent
        Text {
          required property var modelData
          Layout.fillWidth: true
          text: modelData.title + " · " + modelData.status
          color: Color.popups.text
          elide: Text.ElideRight
          font.pixelSize: 12
        }
      }
      Item { Layout.fillHeight: true }
    }
  }
}
