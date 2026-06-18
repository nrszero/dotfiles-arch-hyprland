import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Wayland
import Quickshell.Bluetooth

PopupWindow {
    id: root

    required property var theme

    anchor.edges: Edges.Bottom
    anchor.margins.top: 6

    implicitWidth: 300
    implicitHeight: 200
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
        function onHoveredChanged() {
            console.log("[NotifCenter] popupHover hovered changed →", popupHover.hovered)
            updateHover()
        }
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
                text: "Bluetooth"
                color: theme.text
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeMd
                font.bold: true
            }
            
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: Bluetooth.devices.values
                spacing: 6
                clip: true

                delegate: RowLayout {
                    width: ListView.view.width
                    spacing: 8
                    
                    // Icon
                    Text {
                        text: modelData.connected ? "󰂯" : "󰂲"
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeLg
                        color: modelData.connected ? theme.success : theme.subText
                    }
                    
                    // Device Name
                    Text {
                        text: modelData.name || "Unknown Device"
                        color: theme.text
                        font.family: theme.fontFace
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    
                    // Battery Level (only show if available)
                    Text {
                        visible: modelData.battery >= 0
                        text: Math.round(modelData.battery * 100) + "%"
                        color: modelData.battery < 0.2 ? theme.urgent : theme.success
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeSm
                    }

                    // Connect / Disconnect Button
                    Button {
                        text: modelData.connected ? "Disconnect" : "Connect"
                        onClicked: {
                            if (modelData.connected) {
                                modelData.disconnect()
                            } else {
                                modelData.connect()
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

        }
    }
}
