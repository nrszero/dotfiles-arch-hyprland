import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

Rectangle {
    id: rootContent
    required property var theme
    required property var targetWindow

    color: theme.background
    radius: theme.radius
    border.width: theme.borderWidth
    border.color: theme.borderColor
    
    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8
        
        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            spacing: 8

            // Accent Pill
            Rectangle {
                width: 4
                Layout.preferredHeight: 18 // Roughly matches the text height
                radius: 2
                color: theme.accent 
            }

            Text {
                text: "System"
                color: theme.text
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeMd
                font.bold: true
                Layout.fillWidth: true
            }
        }

        // Button List
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            
            // Lock
            Button {
                id: lockBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                background: Rectangle {
                    color: lockBtn.hovered ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
                    radius: theme.radius
                    border.width: theme.borderWidth
                    border.color: lockBtn.hovered ? theme.accent : "transparent"
                }
                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 16

                    Text { 
                        text: "󰌾" // Lock icon
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeXl
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
                    Quickshell.execDetached(["bash", "-c", "~/.config/quickshell/lock.sh"])
                    targetWindow.visible = false
                }
            }

            // Logout
            Button {
                id: logoutBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                background: Rectangle {
                    color: logoutBtn.hovered ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
                    radius: theme.radius
                    border.width: theme.borderWidth
                    border.color: logoutBtn.hovered ? theme.accent : "transparent"
                }
                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 16

                    Text { 
                        text: "󰍃" // Logout icon
                        font.family: theme.fontFace 
                        font.pixelSize: theme.fontSizeXl 
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
                    Quickshell.execDetached(["bash", "-c", "hyprctl dispatch 'hl.dsp.exit()'"])
                    targetWindow.visible = false
                }
            }

            // Suspend
            Button {
                id: suspendBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                background: Rectangle {
                    color: suspendBtn.hovered ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
                    radius: theme.radius
                    border.width: theme.borderWidth
                    border.color: suspendBtn.hovered ? theme.accent : "transparent"
                }
                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 16

                    Text { 
                        text: "󰤄"
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeXl
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
                    Quickshell.execDetached(["systemctl", "suspend"])
                    targetWindow.visible = false
                }
            }

            // Reboot
            Button {
                id: rebootBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                background: Rectangle {
                    color: rebootBtn.hovered ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
                    radius: theme.radius
                    border.width: theme.borderWidth
                    border.color: rebootBtn.hovered ? theme.accent : "transparent"
                }
                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 16

                    Text { 
                        text: "󰜉"
                        font.family: theme.fontFace 
                        font.pixelSize: theme.fontSizeXl 
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
                    Quickshell.execDetached(["systemctl", "reboot"])
                    targetWindow.visible = false
                }
            }

            // Shutdown
            Button {
                id: shutdownBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                background: Rectangle {
                    color: shutdownBtn.hovered ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
                    radius: theme.radius
                    border.width: theme.borderWidth
                    border.color: shutdownBtn.hovered ? theme.accent : "transparent"
                }
                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 16

                    Text { 
                        text: "󰐥"
                        font.family: theme.fontFace 
                        font.pixelSize: theme.fontSizeXl 
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
                    Quickshell.execDetached(["systemctl", "poweroff"])
                    targetWindow.visible = false
                }
            }
        }


    }
}
