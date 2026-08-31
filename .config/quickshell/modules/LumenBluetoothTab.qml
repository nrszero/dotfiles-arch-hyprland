import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Bluetooth

Item {
    id: root

    required property var theme
    property string query: ""
    property bool tabActive: false
    property int selectedIndex: 0
    property int deviceStateRev: 0
    property var adapter: Bluetooth.defaultAdapter

    readonly property int itemCount: listModel.values ? listModel.values.length : 0
    readonly property string statusText: {
        if (root.adapter && root.adapter.discovering)
            return "scanning"
        const n = itemCount
        return n + (n === 1 ? " device" : " devices")
    }

    onTabActiveChanged: {
        if (!root.adapter)
            return
        if (tabActive) {
            refreshDevices()
        } else {
            root.adapter.discovering = false
            root.adapter.discoverable = false
        }
    }

    onQueryChanged: resetSelection()

    function cancelPending() {
        return false
    }

    function refreshDevices() {
        deviceStateRev++
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
        if (item.kind === "scan") {
            if (!root.adapter)
                return
            root.adapter.discovering = !root.adapter.discovering
            root.adapter.discoverable = root.adapter.discovering
            return
        }
        const dev = item.device
        if (!dev)
            return
        if (item.kind === "connected")
            dev.connected = false
        else if (item.kind === "paired")
            dev.connected = true
        else if (item.kind === "unpaired")
            dev.pair()
        refreshDevices()
    }

    function forgetSelected() {
        const item = currentItem()
        if (!item || !item.canForget || !item.device)
            return
        item.device.forget()
        refreshDevices()
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
        const discovering = !!(root.adapter && root.adapter.discovering)
        if (root.adapter && matches("scan")) {
            rows.push({
                key: "scan",
                kind: "scan",
                title: discovering ? "Stop Scan" : "Scan",
                subtitle: discovering ? "Looking for nearby devices" : "Find nearby devices",
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
                    subtitle: deviceDetails(d, "connected"),
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
                subtitle: deviceDetails(d, "paired"),
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
                subtitle: deviceDetails(d, "unpaired"),
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
            const _ = root.deviceStateRev
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
                    color: modelData.accent ? theme.success : theme.text
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
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.device)
                                modelData.device.connected = false
                            root.refreshDevices()
                        }
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
                        onClicked: {
                            if (modelData.device)
                                modelData.device.forget()
                            root.refreshDevices()
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.selectedIndex = index
                    root.activateSelected()
                }
            }
        }
    }
}
