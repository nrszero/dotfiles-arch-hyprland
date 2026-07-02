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

    implicitWidth: 400
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
                text: "Bluetooth"
                color: theme.text
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeMd
                font.bold: true
            }

            // Bluetooth List
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: Bluetooth.devices.values
                spacing: 4
                clip: true

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 36
                    color: modelData.connected ? theme.surface : "transparent"
                    radius: 4

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
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

                        // Battery
                        RowLayout {
                            visible: modelData.battery >= 0
                            spacing: 1 // Tight spacing between the battery body and the tip
                            
                            // Main Battery Body
                            Rectangle {
                                id: batteryProgress
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 16
                                Layout.alignment: Qt.AlignVCenter
                                radius: 4.5
                                
                                // Track Color (The empty part of the battery)
                                color: theme.surface

                                // The Solid Fill Level
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width * modelData.battery
                                    radius: 4.5
                                    color: theme.text;
                                }
                                
                                // The Inner Text & Icon
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 0

                                    // Low Battery
                                    Text {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.rightMargin: 1
                                        text: "!"
                                        font.family: theme.fontFace
                                        font.pixelSize: 12
                                        visible: {
                                            if (modelData.battery <= 0.2) {
                                                return true
                                            }
                                            return false
                                        } 

                                        // Cuts out of the solid fill
                                        color: theme.accent 
                                    }

                                    // Percentage Text
                                    Text {
                                        Layout.alignment: Qt.AlignVCenter
                                        font.family: theme.fontFace
                                        font.pixelSize: 12
                                        font.bold: true
                                        text: Math.round(modelData.battery * 100)
                                        color: theme.accent
                                    }
                                }
                            }

                            // Battery Tip (The positive terminal nub)
                            Rectangle {
                                Layout.preferredWidth: 2
                                Layout.preferredHeight: 6
                                Layout.alignment: Qt.AlignVCenter
                                radius: 1
                                
                                // If full, color it with the fill. Otherwise, use the track color.
                                color: {
                                    if (modelData.battery >= 0.98) {
                                        return theme.text;
                                    }

                                    return theme.surface;
                                }
                            }
                        } 

                        // Connect / Disconnect Button
                        Button {
                            background: Rectangle {
                                color: parent.hovered ? theme.accent : theme.surface
                                radius: theme.radius
                            }

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
            }

            Item { Layout.fillHeight: true }

        }
    }
}
