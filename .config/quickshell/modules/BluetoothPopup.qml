import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Wayland
import Quickshell.Bluetooth

PopupWindow {
    id: root

    required property var theme
    property var adapter: Bluetooth.defaultAdapter

    anchor.edges: Edges.Bottom
    anchor.margins.top: 6

    implicitWidth: 400
    implicitHeight: 450
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
        } else {
            // Stop scanning and hide the PC when the popup is closed
            if (adapter) {
                adapter.discovering = false;
                adapter.discoverable = false;
            }
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
            
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Bluetooth"
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                    font.bold: true
                }

                Item { Layout.fillWidth: true }
            }

            // Connected Devices Section
            Repeater {
                model: root.adapter ? root.adapter.devices.values : []
                
                delegate: Rectangle {
                    // Magically hide if disconnected
                    visible: modelData.connected
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? 40 : 0
                    color: theme.surface
                    radius: 4
                    clip: true // Prevents contents from drawing when height is 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8
                        visible: parent.visible

                        Text {
                            text: "󰂯"
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeLg
                            color: theme.success
                        }
                        
                        Text {
                            property string mName: modelData.name || ""
                            property string mDeviceName: modelData.deviceName || ""
                            property string mAddress: modelData.address || ""

                            text: {
                                if (mName && mName !== mAddress) return mName;
                                if (mDeviceName && mDeviceName !== mAddress) return mDeviceName;
                                return mAddress + " (Resolving...)";
                            }
                            
                            color: theme.success // Styled green like active Wi-Fi
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeMd
                            font.bold: true      // Bold like active Wi-Fi
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        // Battery Indicator
                        RowLayout {
                            visible: modelData.batteryAvailable && modelData.battery >= 0
                            spacing: 1
                            
                            Rectangle {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 16
                                Layout.alignment: Qt.AlignVCenter
                                radius: 4.5
                                color: theme.background // Contrasts against the surface color

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width * modelData.battery
                                    radius: 4.5
                                    color: theme.text
                                }
                                
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 0
                                    Text {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.rightMargin: 1
                                        text: "!"
                                        font.family: theme.fontFace
                                        font.pixelSize: 12
                                        visible: modelData.battery <= 0.2
                                        color: theme.accent 
                                    }
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

                            Rectangle {
                                Layout.preferredWidth: 2
                                Layout.preferredHeight: 6
                                Layout.alignment: Qt.AlignVCenter
                                radius: 1
                                color: modelData.battery >= 0.98 ? theme.text : theme.background
                            }
                        }

                        // Forget Button
                        Button {
                            background: Rectangle {
                                color: parent.hovered ? theme.accent : theme.background
                                radius: theme.radius
                            }
                            contentItem: Text {
                                text: "Forget"
                                color: parent.parent.hovered ? theme.background : theme.text
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeSm
                            }
                            onClicked: modelData.forget()
                        }

                        // Disconnect Button 
                        Button {
                            background: Rectangle {
                                color: parent.hovered ? theme.accent : theme.background
                                radius: theme.radius
                            }
                            contentItem: Text {
                                text: "Disconnect"
                                color: parent.parent.hovered ? theme.background : theme.text
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeSm
                            }
                            onClicked: modelData.disconnect()
                        }
                    }
                }
            }

            // Available Devices Header
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                
                Text {
                    text: "Available Devices"
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                    font.bold: true
                }
                
                Item { Layout.fillWidth: true }

                // Loading / Scanning Icon
                Text {
                    text: ""
                    color: theme.subText
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                    visible: root.adapter ? root.adapter.discovering : false
                    
                    RotationAnimation on rotation {
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1000
                        running: root.adapter ? root.adapter.discovering : false
                    }
                }

                // Scan Toggle Button
                Button {
                    visible: root.adapter !== null
                    background: Rectangle {
                        color: parent.hovered ? theme.accent : theme.surface
                        radius: theme.radius
                    }
                    contentItem: Text {
                        text: (root.adapter && root.adapter.discovering) ? "Stop Scan" : "Scan"
                        color: parent.parent.hovered ? theme.background : theme.text
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeSm
                    }
                    onClicked: {
                        if (root.adapter) {
                            root.adapter.discovering = !root.adapter.discovering;
                            // Make the PC discoverable too; helps audio devices handshake
                            root.adapter.discoverable = root.adapter.discovering;
                        }
                    }
                }
            }

            // Available Devices List
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: parent.width
                    spacing: 0

                    // Paired Devices (Jumps to the top)
                    Repeater {
                        model: root.adapter ? root.adapter.devices.values : []
                        
                        delegate: Item {
                            visible: !modelData.connected && modelData.paired
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? 40 : 0 
                            clip: true

                            Rectangle {
                                width: parent.width
                                height: 36
                                color: "transparent"
                                radius: 4
                                opacity: 1.0

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        text: "󰂲"
                                        font.family: theme.fontFace
                                        font.pixelSize: theme.fontSizeLg
                                        color: theme.subText
                                    }
                                    
                                    Text {
                                        property string mName: modelData.name || ""
                                        property string mDeviceName: modelData.deviceName || ""
                                        property string mAddress: modelData.address || ""

                                        text: {
                                            if (mName && mName !== mAddress) return mName;
                                            if (mDeviceName && mDeviceName !== mAddress) return mDeviceName;
                                            return mAddress + " (Resolving...)";
                                        }
                                        
                                        color: theme.text
                                        font.family: theme.fontFace
                                        font.pixelSize: theme.fontSizeMd
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    // Forget Button
                                    Button {
                                        background: Rectangle {
                                            color: parent.hovered ? theme.accent : theme.surface
                                            radius: theme.radius
                                        }
                                        contentItem: Text {
                                            text: "Forget"
                                            color: parent.parent.hovered ? theme.background : theme.text
                                            font.family: theme.fontFace
                                            font.pixelSize: theme.fontSizeSm
                                        }
                                        onClicked: modelData.forget()
                                    }

                                    // Connect Button
                                    Button {
                                        background: Rectangle {
                                            color: parent.hovered ? theme.accent : theme.surface
                                            radius: theme.radius
                                        }
                                        contentItem: Text {
                                            text: "Connect"
                                            color: parent.parent.hovered ? theme.background : theme.text
                                            font.family: theme.fontFace
                                            font.pixelSize: theme.fontSizeSm
                                        }
                                        onClicked: modelData.connect()
                                    }
                                }
                            }
                        }
                    }

                    // Unpaired Devices (Stays at the bottom)
                    Repeater {
                        model: root.adapter ? root.adapter.devices.values : []
                        
                        delegate: Item {
                            visible: !modelData.connected && !modelData.paired
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? 40 : 0 
                            clip: true

                            Rectangle {
                                width: parent.width
                                height: 36 
                                color: "transparent"
                                radius: 4
                                opacity: 0.7

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        text: "󰂲"
                                        font.family: theme.fontFace
                                        font.pixelSize: theme.fontSizeLg
                                        color: theme.subText
                                    }
                                    
                                    Text {
                                        property string mName: modelData.name || ""
                                        property string mDeviceName: modelData.deviceName || ""
                                        property string mAddress: modelData.address || ""

                                        text: {
                                            if (mName && mName !== mAddress) return mName;
                                            if (mDeviceName && mDeviceName !== mAddress) return mDeviceName;
                                            return mAddress + " (Resolving...)";
                                        }
                                        
                                        color: theme.text
                                        font.family: theme.fontFace
                                        font.pixelSize: theme.fontSizeMd
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    // ONLY the Pair button is shown here
                                    Button {
                                        background: Rectangle {
                                            color: parent.hovered ? theme.accent : theme.surface
                                            radius: theme.radius
                                        }
                                        contentItem: Text {
                                            text: "Pair"
                                            color: parent.parent.hovered ? theme.background : theme.text
                                            font.family: theme.fontFace
                                            font.pixelSize: theme.fontSizeSm
                                        }
                                        onClicked: modelData.pair()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
