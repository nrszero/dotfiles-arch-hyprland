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
    grabFocus: selectedSsid !== "" && requiresPassword

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

    function signalLabel(signal) {
        if (signal > 80) return "Excellent"
        if (signal > 60) return "Good"
        if (signal > 40) return "Fair"
        if (signal > 20) return "Weak"
        return "No signal"
    }

    function wifiDetails(ssid, signal, security, inUse) {
        const parts = []
        if (inUse && ssid === networkWidget.currentWifiSsid)
            parts.push(networkWidget.isWifiActiveRoute ? "Connected" : "Inactive")
        if (networkWidget.isSavedWifi(ssid))
            parts.push("Saved")
        parts.push(!security || security === "--" ? "Open" : security)
        parts.push(signalLabel(signal))
        return parts.join(" · ")
    }

    function ethernetDetails() {
        if (networkWidget.connectionState === 1)
            return "Connected · Wired"
        if (networkWidget.connectionState === 2)
            return "Connecting · Wired"
        return "Disconnected · Wired"
    }

    function activeWifiDetails() {
        const parts = []
        parts.push(networkWidget.isWifiActiveRoute ? "Connected" : "Inactive")
        if (networkWidget.isSavedWifi(networkWidget.currentWifiSsid))
            parts.push("Saved")
        if (networkWidget.currentWifiSignal > 0)
            parts.push(signalLabel(networkWidget.currentWifiSignal))
        return parts.join(" · ")
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
                height: 52
                color: theme.surface
                radius: theme.radius

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        text: "󰈀"
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeXl
                        color: networkWidget.connectionState === 1 ? theme.accent :
                               networkWidget.connectionState === 2 ? theme.urgent : theme.text
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Ethernet"
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
                            font.bold: true
                            color: networkWidget.connectionState === 1 ? theme.accent :
                                   networkWidget.connectionState === 2 ? theme.urgent : theme.text
                        }

                        Text {
                            text: ethernetDetails()
                            color: theme.subText
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
   
            // Active Wi-Fi Connection
            Rectangle {
                Layout.fillWidth: true
                height: 52
                color: theme.surface
                radius: theme.radius
                visible: networkWidget.currentWifiSsid !== ""
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        text: getWifiIcon(networkWidget.currentWifiSignal)
                        color: theme.success
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeXl
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: networkWidget.currentWifiSsid
                            color: theme.success
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: {
                                const _ = networkWidget.savedWifiRevision
                                return activeWifiDetails()
                            }
                            color: theme.subText
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        text: ""
                        color: forgetMouse.containsMouse ? theme.urgent : theme.subText
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeMd
                        MouseArea {
                            id: forgetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: networkWidget.forgetWifi()
                        }
                    }

                    Text {
                        text: "󰤭"
                        color: disconnectMouse.containsMouse ? theme.urgent : theme.subText
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeMd
                        MouseArea {
                            id: disconnectMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: networkWidget.disconnectWifi()
                        }
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
                spacing: 6
                model: networkWidget.wifiModel

                delegate: Rectangle {
                    readonly property bool highlighted: rowMouse.containsMouse || root.selectedSsid === model.ssid
                    readonly property bool canForget: {
                        const _ = networkWidget.savedWifiRevision
                        return networkWidget.isSavedWifi(model.ssid)
                            && model.ssid !== networkWidget.currentWifiSsid
                    }
                    width: ListView.view.width
                    height: 52
                    color: highlighted ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
                    radius: theme.radius
                    border.width: theme.borderWidth
                    border.color: highlighted ? theme.accent : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            text: getWifiIcon(model.signal)
                            color: theme.text
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeXl
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: model.ssid
                                color: theme.text
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeSm
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: {
                                    const _ = networkWidget.savedWifiRevision
                                    return wifiDetails(model.ssid, model.signal, model.security, model.inUse)
                                }
                                color: theme.subText
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeSm
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            visible: canForget
                            text: ""
                            color: listForgetMouse.containsMouse ? theme.urgent : theme.subText
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeMd
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (model.inUse && model.ssid === networkWidget.currentWifiSsid)
                                return
                            root.selectedSsid = model.ssid;
                            root.requiresPassword = !networkWidget.isSavedWifi(model.ssid)
                                && model.security !== "" && model.security !== "--";
                            
                            if (!root.requiresPassword) {
                                networkWidget.connectToWifi(model.ssid, "");
                                root.selectedSsid = ""; 
                            } else {
                                passwordInput.forceActiveFocus();
                            }
                        }
                    }

                    MouseArea {
                        id: listForgetMouse
                        z: 1
                        visible: canForget
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 24
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: networkWidget.forgetWifi(model.ssid)
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
                            color: parent.hovered ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
                            radius: theme.radius
                            border.width: theme.borderWidth
                            border.color: parent.hovered ? theme.accent : "transparent"
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
