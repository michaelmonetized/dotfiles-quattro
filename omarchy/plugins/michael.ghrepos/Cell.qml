import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
Rectangle {
    id: cell
    property string text: ""
    property string tooltip: ""
    property string url: ""
    property color ink: Color.popups.text
    property bool bold: false
    signal activated()
    property bool centered: false
    property bool sortable: false
    property int textSize: 13
    readonly property bool actionable: url !== "" || sortable
    height: 56
    color: mouse.containsMouse && actionable ? Qt.rgba(0.5,0.6,0.8,0.12) : "transparent"
    radius: 4
    Text {
        anchors.fill: parent; anchors.margins: 12
        text: cell.text; color: cell.ink; font.family: Style.font.family
        font.pixelSize: cell.textSize; font.bold: cell.bold
        horizontalAlignment: cell.centered ? Text.AlignHCenter : Text.AlignLeft
        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
    }
    MouseArea {
        id: mouse; anchors.fill: parent; hoverEnabled: true
        cursorShape: cell.actionable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: { if (!cell.actionable) return; if (cell.url) Qt.openUrlExternally(cell.url); cell.activated() }
    }
    Controls.ToolTip.visible: mouse.containsMouse && tooltip !== ""
    Controls.ToolTip.text: tooltip
    Controls.ToolTip.delay: 350
}
