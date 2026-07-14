import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Wayland

PopupWindow {
    id: root

    required property var theme
    required property var networkWidget

    anchor.edges: Edges.Bottom | Edges.Right
    anchor.margins.right: -6
    anchor.margins.top: 6

    implicitWidth: 400
    implicitHeight: 450
    visible: false
    color: "transparent"
    grabFocus: true

    HoverHandler { id: popupHover }
    
    // Track the currently selected network for the password prompt
    property string selectedSsid: ""
    property bool requiresPassword: false

    Timer {
        id: hideTimer
        interval: 3000
        repeat: false
        onTriggered: {
            // Don't auto-hide if the user is typing a password
            if (!passwordInput.activeFocus) {
                root.visible = false
            }
        }
    }

    function updateHover() {
        if (!popupHover) return;
        if (popupHover.hovered || passwordInput.activeFocus) {
            hideTimer.stop()
        } else {
            hideTimer.restart()
        }
    }
    
    function getWifiIcon(signal) {
        if (signal > 80) return "󰤨"; // Excellent
        if (signal > 60) return "󰤥"; // Good
        if (signal > 40) return "󰤢"; // Fair
        if (signal > 20) return "󰤟"; // Weak
        return "󰤯"; // None
    }

    Connections {
        target: popupHover
        function onHoveredChanged() { updateHover() }
    }

    onVisibleChanged: {
        if (visible) {
            hideTimer.stop()
            networkWidget.forceScan()
            Qt.callLater(updateHover)
        } else {
            // Reset state when closed
            selectedSsid = ""
            passwordInput.text = ""
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
                    text: "Networks"
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                    font.bold: true
                    Layout.fillWidth: true
                }
            }
                        
            // Current Ethernet connection state
            Rectangle {
                Layout.fillWidth: true
                height: 40
                color: theme.surface
                radius: 4

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: "󰈀 Ethernet"
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeMd
                        color: networkWidget.connectionState === 1 ? theme.accent :
                               networkWidget.connectionState === 2 ? theme.urgent : theme.text
                    }

                    Text {
                        text: networkWidget.connectionState === 1 ? "(Connected)" :
                              networkWidget.connectionState === 2 ? "(Connecting...)" : "(Disconnected)"
                        color: theme.subText
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeSm
                    }

                    Item { Layout.fillWidth: true }

                }
            }
   
            // Active Wi-Fi Connection
            Rectangle {
                Layout.fillWidth: true
                height: 40
                color: theme.surface // Subtle background for the active connection
                radius: 4
                visible: networkWidget.currentWifiSsid !== ""
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: getWifiIcon(networkWidget.currentWifiSignal)
                        color: theme.success
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeMd
                    }

                    Text {
                        text: networkWidget.currentWifiSsid
                        color: theme.success
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeMd
                        elide: Text.ElideRight
                        font.bold: true
                    }

                    Text {
                        text: networkWidget.isWifiActiveRoute ? "(Connected)" : "(Inactive)"
                        color: theme.subText
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeSm
                    }

                    Item { Layout.fillWidth: true }
                    
                    // Forget Button
                    Button {
                        background: Rectangle {
                            color: parent.hovered ? theme.accent : theme.surface
                            radius: theme.radius
                        }
                        contentItem: Text {
                            text: ""
                            color: parent.parent.hovered ? theme.background : theme.text
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeMd
                        }
                        onClicked: networkWidget.forgetWifi()
                    }

                    // Disconnect Button
                    Button {
                        background: Rectangle {
                            color: parent.hovered ? theme.accent : theme.surface
                            radius: theme.radius
                        }
                        contentItem: Text {
                            text: "󰤭"
                            color: parent.parent.hovered ? theme.background : theme.text
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeMd
                        }
                        onClicked: networkWidget.disconnectWifi()
                    }
                }
            }
            
            // Wi-Fi Header & Loading Icon
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                
                Text {
                    text: "Available Networks"
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                    font.bold: true
                }
                
                Item { Layout.fillWidth: true }

                // Show a loading indicator if scanning
                Text {
                    text: "" // Replace with your preferred refresh/spin icon
                    color: theme.subText
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                    visible: networkWidget.isScanning
                    
                    RotationAnimation on rotation {
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1000
                        running: networkWidget.isScanning
                    }
                }
            }

            // Wi-Fi List
            ListView {
                id: wifiList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: networkWidget.wifiModel

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 36
                    color: root.selectedSsid === model.ssid ? theme.accent : "transparent"
                    radius: 4
                    opacity: model.inUse ? 1.0 : 0.8

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8

                        Text {
                            text: getWifiIcon(model.signal)
                            color: root.selectedSsid === model.ssid ? theme.background : theme.text
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeMd
                        }

                        Text {
                            text: model.ssid
                            color: root.selectedSsid === model.ssid ? theme.background : theme.text
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeMd
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: model.security !== "" && model.security !== "--" ? "" : "" // Lock icon
                            color: root.selectedSsid === model.ssid ? theme.background : theme.subText
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (model.inUse) return; // Already connected
                            root.selectedSsid = model.ssid;
                            root.requiresPassword = (model.security !== "" && model.security !== "--");
                            
                            if (!root.requiresPassword) {
                                // Connect immediately if open network
                                networkWidget.connectToWifi(model.ssid, "");
                                root.selectedSsid = ""; 
                            } else {
                                passwordInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // Password Input Box (Hidden unless a secured network is selected)
            RowLayout {
                Layout.fillWidth: true
                visible: root.selectedSsid !== "" && root.requiresPassword

                TextField {
                    id: passwordInput
                    Layout.fillWidth: true
                    placeholderText: "Password for " + root.selectedSsid
                    echoMode: TextInput.Password
                    font.family: theme.fontFace
                    color: theme.text
                    background: Rectangle {
                        color: "transparent"
                        border.color: theme.borderColor
                        radius: theme.radius
                    }
                    
                    onAccepted: {
                        networkWidget.connectToWifi(root.selectedSsid, passwordInput.text);
                        passwordInput.text = "";
                        root.selectedSsid = "";
                    }
                }

                Button {
                    background: Rectangle {
                            color: parent.hovered ? theme.accent : theme.surface
                            radius: theme.radius
                    }

                    text: "Connect"
                    onClicked: {
                        networkWidget.connectToWifi(root.selectedSsid, passwordInput.text);
                        passwordInput.text = "";
                        root.selectedSsid = "";
                    }
                }
            }
        }
    }
}
