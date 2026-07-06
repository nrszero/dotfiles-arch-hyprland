import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Wayland
import Quickshell.Io

PopupWindow {
    id: root
    required property var theme

    anchor.edges: Edges.Bottom
    anchor.margins.top: 6
    implicitWidth: 400
    implicitHeight: 320
    visible: false
    color: "transparent"

    HoverHandler { id: popupHover }

    Timer {
        id: hideTimer
        interval: 3000
        repeat: false
        onTriggered: root.visible = false
    }

    function updateHover() {
        if (!popupHover) return
        if (popupHover.hovered) {
            hideTimer.stop()
        } else {
            hideTimer.restart()
        }
    }

    Connections { 
        target: popupHover
        function onHoveredChanged() {
            updateHover()
        }
    }

    onVisibleChanged: if (visible) { hideTimer.stop(); Qt.callLater(updateHover) }

    Process { id: sysCmd }

    PowerButtonContent {
        anchors.fill: parent
        anchors.margins: 6
        theme: root.theme
    }
}
