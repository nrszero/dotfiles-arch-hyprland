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

    implicitWidth: 320
    implicitHeight: 120
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

    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        color: theme.background
        radius: theme.radius
        border.width: theme.borderWidth
        border.color: theme.borderColor

        RowLayout {
            anchors.centerIn: parent
            spacing: 16

            // Suspend
            Button {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 80
                background: Rectangle {
                    color: parent.hovered ? theme.accent : theme.surface
                    radius: theme.radius
                }
                contentItem: ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "󰤄"; font.pixelSize: 32; color: theme.text; Layout.alignment: Qt.AlignHCenter }
                    Text { text: "Suspend"; font.pixelSize: 12; color: theme.subText; Layout.alignment: Qt.AlignHCenter }
                }
                onClicked: {
                    sysCmd.command = ["systemctl", "suspend"]
                    sysCmd.running = true
                    root.visible = false
                }
            }

            // Reboot
            Button {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 80
                background: Rectangle {
                    color: parent.hovered ? theme.accent : theme.surface
                    radius: theme.radius
                }
                contentItem: ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "󰜉"; font.pixelSize: 32; color: theme.text; Layout.alignment: Qt.AlignHCenter }
                    Text { text: "Reboot"; font.pixelSize: 12; color: theme.subText; Layout.alignment: Qt.AlignHCenter }
                }
                onClicked: {
                    sysCmd.command = ["systemctl", "reboot"]
                    sysCmd.running = true
                    root.visible = false
                }
            }

            // Shutdown
            Button {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 80
                background: Rectangle {
                    color: parent.hovered ? theme.accent : theme.surface
                    radius: theme.radius
                }
                contentItem: ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "⏻"; font.pixelSize: 32; color: theme.text; Layout.alignment: Qt.AlignHCenter }
                    Text { text: "Shutdown"; font.pixelSize: 12; color: theme.subText; Layout.alignment: Qt.AlignHCenter }
                }
                onClicked: {
                    sysCmd.command = ["systemctl", "poweroff"]
                    sysCmd.running = true
                    root.visible = false
                }
            }
        }
    }
}
