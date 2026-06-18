import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Wayland

PopupWindow {
    id: root

    required property var theme

    anchor.edges: Edges.Bottom
    anchor.margins.top: 6

    implicitWidth: 280
    implicitHeight: 160
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
        if (!popupHover) return;
        
        if (popupHover.hovered) {
            hideTimer.stop()
        } else {
            hideTimer.restart()
        }
    }

    Connections {
        target: popupHover
        function onHoveredChanged() { updateHover() }
    }

    onVisibleChanged: {
        if (visible) {
            hideTimer.stop()
            Qt.callLater(updateHover)
        }
    }

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

            Text {
                text: "Network"
                color: theme.text
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeMd
                font.bold: true
            }
            
            // Current connection state (using NetworkWidget logic)
            RowLayout {
                spacing: 8
                Text {
                    text: networkWidget.connectionState === 1 ? "󰈀 Connected" :
                          networkWidget.connectionState === 2 ? "󰈀 Connecting..." : "󰅛 Disconnected"
                    color: networkWidget.connectionState === 1 ? theme.success :
                           networkWidget.connectionState === 2 ? theme.accent : theme.urgent
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                }
            }

            // Future WiFi section placeholder
            Text {
                text: "WiFi networks (coming soon)"
                color: theme.subText
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeSm
            }

            Item { Layout.fillHeight: true }
        }

        NetworkWidget {
            id: networkWidget
            interfaceName: "enp15s0"
        }
    }
}
