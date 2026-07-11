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
        anchors.fill: parent
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
            spacing: 8
            
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
                    Quickshell.execDetached(["systemctl", "suspend"])
                    targetWindow.visible = false
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
                    Quickshell.execDetached(["systemctl", "reboot"])
                    targetWindow.visible = false
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
                    Quickshell.execDetached(["systemctl", "poweroff"])
                    targetWindow.visible = false
                }
            }
        }


    }
}
