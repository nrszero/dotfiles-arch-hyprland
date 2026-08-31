import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    required property var theme
    required property var networkWidget
    property string query: ""
    property bool tabActive: false
    property int selectedIndex: 0
    property string selectedSsid: ""
    property bool requiresPassword: false
    signal requestSearchFocus()
    signal unhandledKey(var event)

    readonly property bool passwordOpen: selectedSsid !== "" && requiresPassword
    readonly property int itemCount: listModel.values ? listModel.values.length : 0
    readonly property string statusText: {
        if (networkWidget && networkWidget.isScanning)
            return "scanning"
        const n = itemCount
        return n + (n === 1 ? " network" : " networks")
    }

    onTabActiveChanged: {
        if (tabActive && networkWidget && networkWidget.forceScan)
            networkWidget.forceScan()
        else
            cancelPending()
    }

    onQueryChanged: resetSelection()

    function cancelPending() {
        if (!passwordOpen)
            return false
        selectedSsid = ""
        requiresPassword = false
        passwordInput.text = ""
        requestSearchFocus()
        return true
    }

    function resetSelection() {
        selectedIndex = 0
        Qt.callLater(() => {
            if (listView.count > 0)
                listView.positionViewAtBeginning()
        })
    }

    function moveSelection(delta) {
        const count = itemCount
        if (count <= 0) {
            selectedIndex = 0
            return
        }
        selectedIndex = (selectedIndex + delta + count) % count
        listView.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    function currentItem() {
        const items = listModel.values
        if (!items || selectedIndex < 0 || selectedIndex >= items.length)
            return null
        return items[selectedIndex]
    }

    function activateSelected() {
        const item = currentItem()
        if (!item)
            return
        if (item.kind === "ethernet")
            return
        if (item.kind === "current") {
            networkWidget.disconnectWifi()
            return
        }
        if (item.inUse && item.ssid === networkWidget.currentWifiSsid)
            return
        selectedSsid = item.ssid
        requiresPassword = !networkWidget.isSavedWifi(item.ssid)
            && item.security !== "" && item.security !== "--"
        if (!requiresPassword) {
            networkWidget.connectToWifi(item.ssid, "")
            selectedSsid = ""
        } else {
            passwordInput.text = ""
            Qt.callLater(() => passwordInput.forceActiveFocus())
        }
    }

    function forgetSelected() {
        const item = currentItem()
        if (!item || !item.canForget)
            return
        networkWidget.forgetWifi(item.ssid)
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Delete) {
            if ((root.query || "").trim() !== "")
                return false
            forgetSelected()
            return true
        }
        return false
    }

    function submitPassword() {
        if (!passwordOpen)
            return
        networkWidget.connectToWifi(selectedSsid, passwordInput.text)
        passwordInput.text = ""
        selectedSsid = ""
        requiresPassword = false
        requestSearchFocus()
    }

    function getWifiIcon(signal) {
        if (signal > 80) return "󰤨"
        if (signal > 60) return "󰤥"
        if (signal > 40) return "󰤢"
        if (signal > 20) return "󰤟"
        return "󰤯"
    }

    function signalLabel(signal) {
        if (signal > 80) return "Excellent"
        if (signal > 60) return "Good"
        if (signal > 40) return "Fair"
        if (signal > 20) return "Weak"
        return "No signal"
    }

    function matches(text) {
        const needle = (root.query || "").trim().toLowerCase()
        if (!needle)
            return true
        return ("" + (text || "")).toLowerCase().indexOf(needle) >= 0
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

    function buildRows() {
        const rows = []
        if (!networkWidget)
            return rows

        if (matches("ethernet") || matches("wired")) {
            rows.push({
                key: "eth",
                kind: "ethernet",
                title: "Ethernet",
                subtitle: ethernetDetails(),
                icon: "󰈀",
                ssid: "",
                security: "",
                inUse: networkWidget.connectionState === 1,
                canForget: false,
                accent: networkWidget.connectionState === 1,
                urgent: networkWidget.connectionState === 2
            })
        }

        const current = networkWidget.currentWifiSsid
        if (current !== "" && matches(current)) {
            rows.push({
                key: "current:" + current,
                kind: "current",
                title: current,
                subtitle: activeWifiDetails(),
                icon: getWifiIcon(networkWidget.currentWifiSignal),
                ssid: current,
                security: "",
                inUse: true,
                canForget: true,
                accent: true,
                urgent: false
            })
        }

        const model = networkWidget.wifiModel
        if (model) {
            for (let i = 0; i < model.count; i++) {
                const row = model.get(i)
                if (!row || !row.ssid)
                    continue
                if (row.ssid === current)
                    continue
                if (!matches(row.ssid))
                    continue
                rows.push({
                    key: "wifi:" + row.ssid,
                    kind: "wifi",
                    title: row.ssid,
                    subtitle: wifiDetails(row.ssid, row.signal, row.security, row.inUse),
                    icon: getWifiIcon(row.signal),
                    ssid: row.ssid,
                    security: row.security || "",
                    inUse: !!row.inUse,
                    canForget: networkWidget.isSavedWifi(row.ssid),
                    accent: false,
                    urgent: false
                })
            }
        }
        return rows
    }

    ScriptModel {
        id: listModel
        objectProp: "key"
        values: {
            const _q = root.query
            const _scan = networkWidget ? networkWidget.isScanning : false
            const _state = networkWidget ? networkWidget.connectionState : 0
            const _ssid = networkWidget ? networkWidget.currentWifiSsid : ""
            const _sig = networkWidget ? networkWidget.currentWifiSignal : 0
            const _route = networkWidget ? networkWidget.isWifiActiveRoute : false
            const _rev = networkWidget ? networkWidget.savedWifiRevision : 0
            const _count = networkWidget && networkWidget.wifiModel ? networkWidget.wifiModel.count : 0
            return root.buildRows()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: listModel
            currentIndex: root.selectedIndex
            keyNavigationWraps: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                active: listView.moving || listView.flicking
                policy: ScrollBar.AsNeeded
            }

            onCountChanged: {
                if (root.selectedIndex >= count)
                    root.resetSelection()
            }

            delegate: Rectangle {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 52
                radius: theme.radius
                color: index === root.selectedIndex ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
                border.width: theme.borderWidth
                border.color: index === root.selectedIndex ? theme.accent : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        text: modelData.icon
                        color: modelData.urgent ? theme.urgent : (modelData.accent ? theme.success : theme.text)
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeXl
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: modelData.title
                            color: modelData.urgent ? theme.urgent : (modelData.accent ? theme.success : theme.text)
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.subtitle
                            color: theme.subText
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        visible: modelData.canForget
                        text: ""
                        color: forgetMouse.containsMouse ? theme.urgent : theme.subText
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeMd

                        MouseArea {
                            id: forgetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: networkWidget.forgetWifi(modelData.ssid)
                        }
                    }

                    Text {
                        visible: modelData.kind === "current"
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

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    cursorShape: modelData.kind === "ethernet" ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                        root.selectedIndex = index
                        root.activateSelected()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.passwordOpen
            spacing: 8

            TextField {
                id: passwordInput
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                placeholderText: "Password for " + root.selectedSsid
                placeholderTextColor: theme.subText
                echoMode: TextInput.Password
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeSm
                color: theme.text
                background: Rectangle {
                    color: theme.surface
                    border.width: theme.borderWidth
                    border.color: passwordInput.activeFocus ? theme.accent : "transparent"
                    radius: theme.radius
                }
                onAccepted: root.submitPassword()
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        root.cancelPending()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        event.accepted = false
                    } else {
                        root.unhandledKey(event)
                    }
                }
            }

            Rectangle {
                Layout.preferredHeight: 40
                implicitWidth: connectLabel.implicitWidth + 20
                radius: theme.radius
                color: connectMouse.containsMouse ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
                border.width: theme.borderWidth
                border.color: connectMouse.containsMouse ? theme.accent : "transparent"

                Text {
                    id: connectLabel
                    anchors.centerIn: parent
                    text: "Connect"
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeSm
                }

                MouseArea {
                    id: connectMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.submitPassword()
                }
            }
        }
    }
}
