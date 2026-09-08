import QtQuick
import qs.Ui
import Quickshell.Io

BarWidget {
  id: root
  property string hostname: "…"
  Process {
    command: ["sh", "-c", "$HOME/.config/desktop/bin/machine-hostname"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.hostname = text.trim() }
  }
  moduleName: "omarchy.menu"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󱁏 " + root.hostname
    horizontalMargin: 12
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.RightButton) root.bar.run("xdg-terminal-exec")
      else root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
    }
  }
}
