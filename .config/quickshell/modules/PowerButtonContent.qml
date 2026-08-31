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

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    { title: "Lock", subtitle: "Lock the session", icon: "󰌾", command: ["bash", "-c", "~/.config/quickshell/lock.sh"] },
                    { title: "Logout", subtitle: "Exit Hyprland", icon: "󰍃", command: ["bash", "-c", "hyprctl dispatch 'hl.dsp.exit()'"] },
                    { title: "Suspend", subtitle: "Sleep the machine", icon: "󰤄", command: ["systemctl", "suspend"] },
                    { title: "Reboot", subtitle: "Restart the machine", icon: "󰜉", command: ["systemctl", "reboot"] },
                    { title: "Shutdown", subtitle: "Power off the machine", icon: "󰐥", command: ["systemctl", "poweroff"] }
                ]

                delegate: Button {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    background: Rectangle {
                        color: parent.hovered ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
                        radius: theme.radius
                        border.width: theme.borderWidth
                        border.color: parent.hovered ? theme.accent : "transparent"
                    }
                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 16

                        Text {
                            text: modelData.icon
                            Layout.preferredWidth: 28
                            horizontalAlignment: Text.AlignHCenter
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeXl
                            color: theme.text
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: modelData.title
                                color: theme.text
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeSm
                                font.bold: true
                                horizontalAlignment: Text.AlignLeft
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.subtitle
                                color: theme.subText
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeSm
                                horizontalAlignment: Text.AlignLeft
                            }
                        }
                    }
                    onClicked: {
                        Quickshell.execDetached(modelData.command)
                        targetWindow.visible = false
                    }
                }
            }
        }


    }
}
