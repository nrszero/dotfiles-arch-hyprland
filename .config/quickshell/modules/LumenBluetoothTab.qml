import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Bluetooth

Item {
    id: root

    required property var theme
    required property var bluetoothActions
    property string query: ""
    property bool tabActive: false
    property int selectedIndex: 0
    property bool watching: false
    readonly property var adapter: bluetoothActions ? bluetoothActions.adapter : null

    readonly property int itemCount: listModel.values ? listModel.values.length : 0
    readonly property string statusText: {
        if (root.bluetoothActions.lastError !== "")
            return root.bluetoothActions.lastError
        if (root.bluetoothActions.isBusy)
            return root.bluetoothActions.operationLabel() + "…"
        if (root.adapter && root.adapter.discovering)
            return "scanning"
        const n = itemCount
        return n + (n === 1 ? " device" : " devices")
    }

    onTabActiveChanged: {
        if (tabActive) {
            if (!watching) {
                watching = true
                bluetoothActions.watch()
            }
            refreshDevices()
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

    onQueryChanged: resetSelection()

    function cancelPending() {
        return false
    }

    function refreshDevices() {
        bluetoothActions.refreshDevices()
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
        if (item.kind === "error") {
            root.bluetoothActions.clearError()
            return
        }
        if (item.kind === "scan") {
            root.bluetoothActions.toggleScan()
            return
        }
        if (root.bluetoothActions.isBusy)
            return
        const dev = item.device
        if (!dev)
            return
        if (item.kind === "connected")
            root.bluetoothActions.disconnectDevice(dev)
        else if (item.kind === "paired")
            root.bluetoothActions.connectDevice(dev)
        else if (item.kind === "unpaired")
            root.bluetoothActions.pair(dev)
    }

    function forgetSelected() {
        const item = currentItem()
        if (!item || !item.canForget || !item.device || root.bluetoothActions.isBusy)
            return
        root.bluetoothActions.forget(item.device)
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

    function matches(text) {
        const needle = (root.query || "").trim().toLowerCase()
        if (!needle)
            return true
        return ("" + (text || "")).toLowerCase().indexOf(needle) >= 0
    }

    function buildRows() {
        const rows = []
        if (root.bluetoothActions.lastError !== "") {
            rows.push({
                key: "error",
                kind: "error",
                title: "Bluetooth error",
                subtitle: root.bluetoothActions.lastError,
                icon: "",
                device: null,
                canForget: false,
                accent: false
            })
        }

        const discovering = !!(root.adapter && root.adapter.discovering)
        if (root.adapter && matches("scan")) {
            rows.push({
                key: "scan",
                kind: "scan",
                title: root.bluetoothActions.pendingOp === "scan-start" ? "Starting scan…" :
                       root.bluetoothActions.pendingOp === "scan-stop" ? "Stopping scan…" :
                       discovering ? "Stop Scan" : "Scan",
                subtitle: root.bluetoothActions.pendingOp === "scan-start" ||
                          root.bluetoothActions.pendingOp === "scan-stop"
                    ? "Waiting for the Bluetooth adapter"
                    : discovering ? "Looking for nearby devices" : "Find nearby devices",
                icon: "",
                device: null,
                canForget: false,
                accent: discovering
            })
        }

        if (!root.adapter)
            return rows

        const devices = [...root.adapter.devices.values]
        for (let i = 0; i < devices.length; i++) {
            const d = devices[i]
            if (!d)
                continue
            const label = deviceLabel(d)
            if (!matches(label) && !matches(d.address || ""))
                continue
            if (d.connected) {
                rows.push({
                    key: "connected:" + (d.address || label),
                    kind: "connected",
                    title: label,
                    subtitle: root.bluetoothActions.isPending(d)
                        ? root.bluetoothActions.operationLabel() + "…"
                        : deviceDetails(d, "connected"),
                    icon: "󰂯",
                    device: d,
                    canForget: true,
                    accent: true
                })
            }
        }
        for (let i = 0; i < devices.length; i++) {
            const d = devices[i]
            if (!d || d.connected || !d.paired)
                continue
            const label = deviceLabel(d)
            if (!matches(label) && !matches(d.address || ""))
                continue
            rows.push({
                key: "paired:" + (d.address || label),
                kind: "paired",
                title: label,
                subtitle: root.bluetoothActions.isPending(d)
                    ? root.bluetoothActions.operationLabel() + "…"
                    : deviceDetails(d, "paired"),
                icon: "󰂲",
                device: d,
                canForget: true,
                accent: false
            })
        }
        for (let i = 0; i < devices.length; i++) {
            const d = devices[i]
            if (!d || d.connected || d.paired)
                continue
            const label = deviceLabel(d)
            if (!matches(label) && !matches(d.address || ""))
                continue
            rows.push({
                key: "unpaired:" + (d.address || label),
                kind: "unpaired",
                title: label,
                subtitle: root.bluetoothActions.isPending(d)
                    ? root.bluetoothActions.operationLabel() + "…"
                    : deviceDetails(d, "unpaired"),
                icon: "󰂲",
                device: d,
                canForget: false,
                accent: false
            })
        }
        return rows
    }

    ScriptModel {
        id: listModel
        objectProp: "key"
        values: {
            const _ = root.bluetoothActions.deviceStateRev
            const _error = root.bluetoothActions.lastError
            const _pending = root.bluetoothActions.pendingOp
            const _pendingAddress = root.bluetoothActions.pendingAddress
            const _q = root.query
            const _disc = root.adapter ? root.adapter.discovering : false
            const _devs = root.adapter && root.adapter.devices ? root.adapter.devices.values : []
            return root.buildRows()
        }
    }

    ListView {
        id: listView
        anchors.fill: parent
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
                    id: rowIcon
                    text: modelData.icon
                    color: modelData.kind === "error" ? theme.urgent :
                           modelData.accent ? theme.success : theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeXl

                    RotationAnimation on rotation {
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1000
                        running: modelData.kind === "scan" && root.adapter && root.adapter.discovering
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: modelData.title
                        color: modelData.accent ? theme.success : theme.text
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
                    visible: modelData.kind === "connected"
                    text: "󰂲"
                    color: disconnectMouse.containsMouse ? theme.urgent : theme.subText
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd

                    MouseArea {
                        id: disconnectMouse
                        anchors.fill: parent
                        enabled: !root.bluetoothActions.isBusy
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.bluetoothActions.disconnectDevice(modelData.device)
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
                        enabled: !root.bluetoothActions.isBusy
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.bluetoothActions.forget(modelData.device)
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                enabled: modelData.kind === "error" || !root.bluetoothActions.isBusy
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.selectedIndex = index
                    root.activateSelected()
                }
            }
        }
    }
}
