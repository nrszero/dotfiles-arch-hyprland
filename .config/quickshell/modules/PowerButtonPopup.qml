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

    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        color: theme.background
        radius: theme.radius
        border.width: theme.borderWidth
        border.color: theme.borderColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            
            // Header
            Text {
                text: "System"
                color: theme.text
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeMd
                font.bold: true
                Layout.fillWidth: true
            }

            // Button List
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                
                // Lock
                Button {
                    id: lockBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    background: Rectangle {
                        color: lockBtn.hovered ? theme.accent : theme.surface
                        radius: theme.radius
                    }
                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 16

                        Text { 
                            text: "󰌾" // Lock icon
                            font.family: theme.fontFace
                            font.pixelSize: 20
                            color: theme.text
                        }
                        Text { 
                            text: "Lock"
                            font.family: theme.fontFace
                            font.pixelSize: 12
                            color: theme.subText
                            Layout.fillWidth: true
                        }
                    }
                    onClicked: {
                        // We wrap the script in bash -c so it properly expands the ~ to your home folder
                        sysCmd.command = ["bash", "-c", "~/.config/quickshell/lock/lock.sh"]
                        sysCmd.running = true
                        root.visible = false
                    }
                }

                // Logout
                Button {
                    id: logoutBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    background: Rectangle {
                        color: logoutBtn.hovered ? theme.accent : theme.surface
                        radius: theme.radius
                    }
                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 16

                        Text { 
                            text: "󰍃" // Logout icon
                            font.family: theme.fontFace 
                            font.pixelSize: 20 
                            color: theme.text 
                        }
                        Text { 
                            text: "Logout"
                            font.family: theme.fontFace 
                            font.pixelSize: 12
                            color: theme.subText 
                            Layout.fillWidth: true
                        }
                    }
                    onClicked: {
                        sysCmd.command = ["hyprctl", "dispatch", "exit"]
                        sysCmd.running = true
                        root.visible = false
                    }
                }

                // Suspend
                Button {
                    id: suspendBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    background: Rectangle {
                        color: parent.hovered ? theme.accent : theme.surface
                        radius: theme.radius
                    }
                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 16

                        Text { 
                            text: "󰤄"
                            font.family: theme.fontFace
                            font.pixelSize: 20
                            color: theme.text
                        }
                        Text { 
                            text: "Suspend"
                            font.family: theme.fontFace
                            font.pixelSize: 12
                            color: theme.subText
                            Layout.fillWidth: true
                        }
                    }
                    onClicked: {
                        sysCmd.command = ["systemctl", "suspend"]
                        sysCmd.running = true
                        root.visible = false
                    }
                }

                // Reboot
                Button {
                    id: rebootBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    background: Rectangle {
                        color: parent.hovered ? theme.accent : theme.surface
                        radius: theme.radius
                    }
                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 16

                        Text { 
                            text: "󰜉"
                            font.family: theme.fontFace 
                            font.pixelSize: 20 
                            color: theme.text
                        }
                        Text { 
                            text: "Reboot"
                            font.family: theme.fontFace 
                            font.pixelSize: 12
                            color: theme.subText 
                            Layout.fillWidth: true 
                        }
                    }
                    onClicked: {
                        sysCmd.command = ["systemctl", "reboot"]
                        sysCmd.running = true
                        root.visible = false
                    }
                }

                // Shutdown
                Button {
                    id: shutdownBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    background: Rectangle {
                        color: parent.hovered ? theme.accent : theme.surface
                        radius: theme.radius
                    }
                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 16

                        Text { 
                            text: "⏻"
                            font.family: theme.fontFace 
                            font.pixelSize: 20 
                            color: theme.text 
                        }
                        Text { 
                            text: "Shutdown"
                            font.family: theme.fontFace 
                            font.pixelSize: 12
                            color: theme.subText 
                            Layout.fillWidth: true 
                        }
                    }
                    onClicked: {
                        sysCmd.command = ["systemctl", "poweroff"]
                        sysCmd.running = true
                        root.visible = false
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
