import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    required property var theme
    property string query: ""
    property bool tabActive: false
    property int selectedIndex: 0

    signal closeRequested()

    readonly property int itemCount: listModel.values ? listModel.values.length : 0
    readonly property string statusText: {
        const n = itemCount
        return n + (n === 1 ? " action" : " actions")
    }

    readonly property var actions: [
        { key: "lock", title: "Lock", subtitle: "Lock the session", icon: "󰌾", command: ["bash", "-c", "~/.config/quickshell/lock.sh"] },
        { key: "logout", title: "Logout", subtitle: "Exit Hyprland", icon: "󰍃", command: ["bash", "-c", "hyprctl dispatch 'hl.dsp.exit()'"] },
        { key: "suspend", title: "Suspend", subtitle: "Sleep the machine", icon: "󰤄", command: ["systemctl", "suspend"] },
        { key: "reboot", title: "Reboot", subtitle: "Restart the machine", icon: "󰜉", command: ["systemctl", "reboot"] },
        { key: "shutdown", title: "Shutdown", subtitle: "Power off the machine", icon: "󰐥", command: ["systemctl", "poweroff"] }
    ]

    onQueryChanged: resetSelection()

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
        const item = currentItem()
        if (!item || !item.command)
            return
        Quickshell.execDetached(item.command)
        root.closeRequested()
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

    function buildRows() {
        const rows = []
        for (let i = 0; i < actions.length; i++) {
            const a = actions[i]
            if (!matches(a.title) && !matches(a.subtitle) && !matches(a.key))
                continue
            rows.push(a)
        }
        return rows
    }

    ScriptModel {
        id: listModel
        objectProp: "key"
        values: {
            const _q = root.query
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
                spacing: 16

                Text {
                    text: modelData.icon
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeXl
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: modelData.title
                        color: theme.text
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
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.selectedIndex = index
                    root.activateSelected()
                }
            }
        }
    }
}
