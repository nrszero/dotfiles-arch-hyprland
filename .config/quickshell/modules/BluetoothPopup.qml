import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Wayland
import Quickshell.Bluetooth

PopupWindow {
    id: root

    required property var theme
    required property var bluetoothActions
    readonly property var adapter: bluetoothActions ? bluetoothActions.adapter : null
    property bool watching: false

    function refreshDevices() {
        bluetoothActions.refreshDevices()
    }

    ScriptModel {
        id: connectedModel
        values: {
            const _ = root.bluetoothActions.deviceStateRev
            if (!root.adapter)
                return []
            return [...root.adapter.devices.values].filter(d => d.connected)
        }
    }

    ScriptModel {
        id: pairedModel
        values: {
            const _ = root.bluetoothActions.deviceStateRev
            if (!root.adapter)
                return []
            return [...root.adapter.devices.values].filter(d => !d.connected && d.paired)
        }
    }

    ScriptModel {
        id: unpairedModel
        values: {
            const _ = root.bluetoothActions.deviceStateRev
            if (!root.adapter)
                return []
            return [...root.adapter.devices.values].filter(d => !d.connected && !d.paired)
        }
    }

    anchor.edges: Edges.Bottom | Edges.Right
    anchor.margins.right: -6
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

    function deviceLabel(dev) {
        const name = dev.name || ""
        const deviceName = dev.deviceName || ""
        const address = dev.address || ""
        if (name && name !== address)
            return name
        if (deviceName && deviceName !== address)
            return deviceName
        return address ? address + " (Resolving...)" : "Unknown device"
    }

    function deviceDetails(dev, kind) {
        const parts = []
        if (kind === "connected")
            parts.push("Connected")
        if (kind === "connected" || kind === "paired")
            parts.push("Saved")
        if (kind === "unpaired")
            parts.push("Not saved")
        if (dev.batteryAvailable && dev.battery >= 0)
            parts.push(Math.round(dev.battery * 100) + "%")
        if (dev.trusted)
            parts.push("Trusted")
        const label = deviceLabel(dev)
        if (kind === "unpaired" && dev.address && label.indexOf(dev.address) === -1)
            parts.push(dev.address)
        return parts.join(" · ")
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
            if (!watching) {
                watching = true
                bluetoothActions.watch()
            }
            hideTimer.stop()
            refreshDevices()
            Qt.callLater(updateHover)
        } else if (watching) {
            watching = false
            bluetoothActions.unwatch()
        }
    }

    Component.onDestruction: {
        if (watching) {
            watching = false
            bluetoothActions.unwatch()
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
                    text: "Bluetooth"
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                    font.bold: true
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                visible: root.bluetoothActions.lastError !== ""
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? errorRow.implicitHeight + 16 : 0
                color: Qt.rgba(theme.urgent.r, theme.urgent.g, theme.urgent.b, 0.18)
                radius: theme.radius
                border.width: theme.borderWidth
                border.color: theme.urgent

                RowLayout {
                    id: errorRow
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: root.bluetoothActions.lastError
                        color: theme.text
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeSm
                        wrapMode: Text.Wrap
                    }

                    Button {
                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }
                        background: Rectangle {
                            color: parent.hovered ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
                            radius: theme.radius
                            border.width: theme.borderWidth
                            border.color: parent.hovered ? theme.accent : "transparent"
                        }
                        contentItem: Text {
                            text: "Dismiss"
                            color: theme.text
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
                        }
                        onClicked: root.bluetoothActions.clearError()
                    }
                }
            }

            // Connected Devices Section
            Repeater {
                model: connectedModel
                
                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    color: theme.surface
                    radius: theme.radius
                    clip: true // Prevents contents from drawing when height is 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10
                        visible: parent.visible

                        Text {
                            text: "󰂯"
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeXl
                            color: theme.success
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: deviceLabel(modelData)
                                color: theme.success
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeSm
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.bluetoothActions.isPending(modelData)
                                    ? root.bluetoothActions.operationLabel() + "…"
                                    : deviceDetails(modelData, "connected")
                                color: theme.subText
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeSm
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: ""
                            color: connectedForgetMouse.containsMouse ? theme.urgent : theme.subText
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeMd
                            MouseArea {
                                id: connectedForgetMouse
                                anchors.fill: parent
                                enabled: !root.bluetoothActions.isBusy
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.bluetoothActions.forget(modelData)
                            }
                        }

                        Text {
                            text: "󰂲"
                            color: connectedDisconnectMouse.containsMouse ? theme.urgent : theme.subText
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeMd
                            MouseArea {
                                id: connectedDisconnectMouse
                                anchors.fill: parent
                                enabled: !root.bluetoothActions.isBusy
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.bluetoothActions.disconnectDevice(modelData)
                            }
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
                    enabled: !root.bluetoothActions.isBusy
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                    background: Rectangle {
                        color: parent.hovered ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
                        radius: theme.radius
                        border.width: theme.borderWidth
                        border.color: parent.hovered ? theme.accent : "transparent"
                    }
                    contentItem: Text {
                        text: root.bluetoothActions.pendingOp === "scan-start" ? "Starting…" :
                              root.bluetoothActions.pendingOp === "scan-stop" ? "Stopping…" :
                              (root.adapter && root.adapter.discovering) ? "Stop Scan" : "Scan"
                        color: theme.text
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeSm
                    }
                    onClicked: root.bluetoothActions.toggleScan()
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
                    spacing: 6

                    // Paired Devices (Jumps to the top)
                    Repeater {
                        model: pairedModel
                        
                        delegate: Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            clip: true

                            Rectangle {
                                width: parent.width
                                height: 52
                                color: pairedMouse.containsMouse ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
                                radius: theme.radius
                                border.width: theme.borderWidth
                                border.color: pairedMouse.containsMouse ? theme.accent : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Text {
                                        text: "󰂲"
                                        font.family: theme.fontFace
                                        font.pixelSize: theme.fontSizeXl
                                        color: theme.subText
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: deviceLabel(modelData)
                                            color: theme.text
                                            font.family: theme.fontFace
                                            font.pixelSize: theme.fontSizeSm
                                            font.bold: true
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: root.bluetoothActions.isPending(modelData)
                                                ? root.bluetoothActions.operationLabel() + "…"
                                                : deviceDetails(modelData, "paired")
                                            color: theme.subText
                                            font.family: theme.fontFace
                                            font.pixelSize: theme.fontSizeSm
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        text: ""
                                        color: pairedForgetMouse.containsMouse ? theme.urgent : theme.subText
                                        font.family: theme.fontFace
                                        font.pixelSize: theme.fontSizeMd
                                    }
                                }

                                MouseArea {
                                    id: pairedMouse
                                    anchors.fill: parent
                                    enabled: !root.bluetoothActions.isBusy
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.bluetoothActions.connectDevice(modelData)
                                }

                                MouseArea {
                                    id: pairedForgetMouse
                                    z: 1
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    height: 24
                                    enabled: !root.bluetoothActions.isBusy
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.bluetoothActions.forget(modelData)
                                }
                            }
                        }
                    }

                    // Unpaired Devices (Stays at the bottom)
                    Repeater {
                        model: unpairedModel
                        
                        delegate: Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            clip: true

                            Rectangle {
                                width: parent.width
                                height: 52
                                color: unpairedMouse.containsMouse ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
                                radius: theme.radius
                                border.width: theme.borderWidth
                                border.color: unpairedMouse.containsMouse ? theme.accent : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Text {
                                        text: "󰂲"
                                        font.family: theme.fontFace
                                        font.pixelSize: theme.fontSizeXl
                                        color: theme.subText
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: deviceLabel(modelData)
                                            color: theme.text
                                            font.family: theme.fontFace
                                            font.pixelSize: theme.fontSizeSm
                                            font.bold: true
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: root.bluetoothActions.isPending(modelData)
                                                ? root.bluetoothActions.operationLabel() + "…"
                                                : deviceDetails(modelData, "unpaired")
                                            color: theme.subText
                                            font.family: theme.fontFace
                                            font.pixelSize: theme.fontSizeSm
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                MouseArea {
                                    id: unpairedMouse
                                    anchors.fill: parent
                                    enabled: !root.bluetoothActions.isBusy
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.bluetoothActions.pair(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
