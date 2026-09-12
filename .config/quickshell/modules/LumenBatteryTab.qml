import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    required property var theme
    required property var battery
    property string query: ""
    property bool tabActive: false
    property int selectedIndex: 0

    readonly property int itemCount: listModel.values ? listModel.values.length : 0

    onQueryChanged: resetSelection()

    onTabActiveChanged: {
        if (!battery)
            return
        if (tabActive) {
            if (battery.watch)
                battery.watch()
        } else if (battery.unwatch) {
            battery.unwatch()
        }
    }

    Component.onDestruction: {
        if (tabActive && battery && battery.unwatch)
            battery.unwatch()
    }

    function cancelPending() {
        return false
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
    }

    function handleKey(event) {
        return false
    }

    function matches(text) {
        const needle = (root.query || "").trim().toLowerCase()
        if (!needle)
            return true
        return ("" + (text || "")).toLowerCase().indexOf(needle) >= 0
    }

    function fmt(n, digits, unit) {
        if (n < 0 || !isFinite(n))
            return "—"
        return n.toFixed(digits) + unit
    }

    function buildRows() {
        const b = root.battery
        if (!b || !b.battPresent)
            return []

        const time = b.timeLabel()
        const rows = []
        if (matches("battery") || matches("charge") || matches("%") || matches(b.statusLabel()) || matches(time) || !(root.query || "").trim()) {
            rows.push({
                key: "summary",
                kind: "summary",
                title: b.battPct + "%",
                subtitle: time ? b.statusLabel() + " · " + time : b.statusLabel()
            })
        }

        const stats = [
            { key: "profile", title: "Power profile", subtitle: b.profileLabel() || "—" },
            { key: "power", title: "Power draw", subtitle: fmt(b.powerW, 1, " W") },
            { key: "voltage", title: "Voltage", subtitle: fmt(b.voltageV, 2, " V") },
            { key: "capacity", title: "Capacity", subtitle: b.energyNowWh >= 0 && b.energyFullWh >= 0
                ? b.energyNowWh.toFixed(1) + " / " + b.energyFullWh.toFixed(1) + " Wh" : "—" },
            { key: "design", title: "Design capacity", subtitle: b.energyDesignWh >= 0
                ? b.energyDesignWh.toFixed(1) + " Wh" : "—" },
            { key: "health", title: "Health", subtitle: b.health >= 0 ? Math.round(b.health * 100) + "%" : "—" },
            { key: "cycles", title: "Cycles", subtitle: b.battCycles >= 0 ? "" + b.battCycles : "—" },
            { key: "tech", title: "Technology", subtitle: b.battTech || "—" },
            { key: "model", title: "Model", subtitle: b.battModel || b.battName || "—" }
        ]

        for (let i = 0; i < stats.length; i++) {
            const s = stats[i]
            if (!matches(s.title) && !matches(s.subtitle) && !matches(s.key))
                continue
            s.kind = "stat"
            rows.push(s)
        }
        return rows
    }

    ScriptModel {
        id: listModel
        objectProp: "key"
        values: {
            const _q = root.query
            const _p = root.battery ? root.battery.battPresent : false
            const _lvl = root.battery ? root.battery.battLevel : 0
            const _st = root.battery ? root.battery.battStatus : ""
            const _w = root.battery ? root.battery.powerW : -1
            const _profile = root.battery ? root.battery.powerProfile : ""
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
            readonly property bool selected: root.selectedIndex === index
            width: ListView.view.width
            height: modelData.kind === "summary" ? 92 : 52
            radius: theme.radius
            color: selected ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
            border.width: theme.borderWidth
            border.color: selected ? theme.accent : "transparent"

            ColumnLayout {
                visible: modelData.kind === "summary"
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: root.battery.icon
                        color: root.battery.iconColor(theme)
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeXXl
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: modelData.title
                            color: theme.text
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeLg
                            font.bold: true
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
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 8
                    radius: theme.radius
                    color: Qt.darker(theme.surface, 1.5)

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, root.battery.battLevel))
                        height: parent.height
                        radius: 3
                        color: root.battery.iconColor(theme)
                    }
                }
            }

            RowLayout {
                visible: modelData.kind === "stat"
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 16

                Text {
                    Layout.fillWidth: true
                    text: modelData.title
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeSm
                    font.bold: true
                }

                Text {
                    text: modelData.subtitle
                    color: theme.subText
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeSm
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectedIndex = index
            }
        }
    }
}
