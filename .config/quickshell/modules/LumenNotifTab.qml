import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import "NotifPaths.js" as NotifPaths

Item {
    id: root

    required property var theme
    required property var notifModel
    required property var dismissNotification
    property string query: ""
    property bool tabActive: false
    property int selectedIndex: 0

    readonly property int itemCount: listModel.values ? listModel.values.length : 0
    readonly property string statusText: {
        const n = notifModel ? notifModel.count : 0
        if (n <= 0)
            return "empty"
        return n + " new"
    }

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

    function clearAll() {
        if (!notifModel)
            return
        for (let i = notifModel.count - 1; i >= 0; i--)
            dismissNotification(i)
        resetSelection()
    }

    function activateSelected() {
        const item = currentItem()
        if (!item)
            return
        if (item.kind === "clear") {
            clearAll()
            return
        }
        if (item.kind === "notif")
            dismissNotification(item.notifIndex)
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Delete) {
            if ((root.query || "").trim() !== "")
                return false
            activateSelected()
            return true
        }
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
        if (!notifModel || notifModel.count === 0)
            return rows

        if (matches("clear")) {
            rows.push({
                key: "clear",
                kind: "clear",
                title: "Clear all",
                subtitle: "Dismiss every notification",
                body: "",
                time: "",
                icon: "",
                notifIndex: -1
            })
        }

        for (let i = 0; i < notifModel.count; i++) {
            const n = notifModel.get(i)
            if (!n)
                continue
            if (!matches(n.summary) && !matches(n.body))
                continue
            rows.push({
                key: "notif:" + i + ":" + (n.summary || "") + ":" + (n.time || ""),
                kind: "notif",
                title: n.summary || "Notification",
                subtitle: n.time || "",
                body: n.body || "",
                time: n.time || "",
                icon: n.icon || "",
                notifIndex: i
            })
        }
        return rows
    }

    ScriptModel {
        id: listModel
        objectProp: "key"
        values: {
            const _q = root.query
            const _count = notifModel ? notifModel.count : 0
            return root.buildRows()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        Text {
            visible: !notifModel || notifModel.count === 0
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            text: "No new notifications"
            color: theme.subText
            font.italic: true
            font.family: theme.fontFace
            font.pixelSize: theme.fontSizeSm
            horizontalAlignment: Text.AlignHCenter
        }

        ListView {
            id: listView
            visible: notifModel && notifModel.count > 0
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
                height: modelData.kind === "clear" ? 52 : 78
                radius: theme.radius
                color: index === root.selectedIndex ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
                border.width: theme.borderWidth
                border.color: index === root.selectedIndex ? theme.accent : "transparent"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            visible: modelData.kind === "clear"
                            text: ""
                            color: theme.urgent
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeXl
                        }

                        Image {
                            visible: modelData.kind === "notif" && modelData.icon !== ""
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            source: modelData.icon && modelData.icon.toString().startsWith("/")
                                ? "file://" + modelData.icon
                                : modelData.icon
                            fillMode: Image.PreserveAspectFit
                            cache: true
                            asynchronous: true
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    color: theme.text
                                    font.family: theme.fontFace
                                    font.pixelSize: modelData.kind === "clear" ? theme.fontSizeSm : theme.fontSizeMd
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: modelData.time !== ""
                                    text: modelData.time
                                    color: theme.subText
                                    font.family: theme.fontFace
                                    font.pixelSize: theme.fontSizeSm
                                }
                            }

                            Text {
                                visible: modelData.kind === "clear"
                                Layout.fillWidth: true
                                text: modelData.subtitle
                                color: theme.subText
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeSm
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            visible: modelData.kind === "notif"
                            text: "✕"
                            color: theme.urgent
                            font.pixelSize: 14
                            font.bold: true

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dismissNotification(modelData.notifIndex)
                            }
                        }
                    }

                    Text {
                        visible: modelData.kind === "notif" && modelData.body !== ""
                        text: NotifPaths.linkify(modelData.body || "", StandardPaths.writableLocation(StandardPaths.HomeLocation))
                        textFormat: Text.RichText
                        color: theme.subText
                        linkColor: theme.accent
                        wrapMode: Text.WrapAnywhere
                        Layout.fillWidth: true
                        clip: true
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeSm
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        onLinkActivated: (link) => {
                            const path = NotifPaths.resolve(link, StandardPaths.writableLocation(StandardPaths.HomeLocation))
                            if (path)
                                Quickshell.execDetached(["kitty", "yazi", path])
                        }

                        HoverHandler {
                            enabled: parent.hoveredLink !== ""
                            cursorShape: Qt.PointingHandCursor
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
}
