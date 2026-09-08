import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore

Item {
    id: root

    required property var theme
    property string query: ""
    property bool tabActive: false
    property int selectedIndex: 0
    property bool showFolders: false
    property bool showWallpapers: false
    property bool auto: true
    property bool shuffle: true
    property string folder: ""
    property string wallpaper: ""
    property int interval: 600
    property var folders: []
    property var images: []
    property int statusRev: 0

    readonly property string ctl: "/etc/awww/wallpaper-ctl.sh"
    readonly property var intervalOptions: [60, 300, 600, 900, 1800, 3600]
    readonly property int itemCount: listModel.values ? listModel.values.length : 0
    readonly property string statusText: {
        if (!root.folder)
            return "no folder"
        if (root.auto)
            return root.folder + " · auto"
        return root.folder + " · pinned"
    }

    onQueryChanged: resetSelection()

    onTabActiveChanged: {
        if (tabActive) {
            refreshStatus()
        } else {
            showFolders = false
            showWallpapers = false
        }
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

    function runCtl(args) {
        Quickshell.execDetached([root.ctl].concat(args))
    }

    function refreshStatus() {
        if (statusProc.running)
            statusProc.running = false
        Qt.callLater(() => {
            statusProc.running = true
        })
    }

    function formatInterval(seconds) {
        const s = Number(seconds) || 0
        if (s >= 3600 && s % 3600 === 0) {
            const h = s / 3600
            return h + (h === 1 ? " hour" : " hours")
        }
        if (s >= 60 && s % 60 === 0) {
            const m = s / 60
            return m + (m === 1 ? " minute" : " minutes")
        }
        return s + " seconds"
    }

    function basename(path) {
        const p = "" + (path || "")
        const i = p.lastIndexOf("/")
        return i >= 0 ? p.slice(i + 1) : p
    }

    function cycleInterval(delta) {
        const opts = root.intervalOptions
        let i = opts.indexOf(root.interval)
        if (i < 0) {
            i = 2
            for (let n = 0; n < opts.length; n++) {
                if (opts[n] >= root.interval) {
                    i = n
                    break
                }
            }
        }
        i = (i + delta + opts.length) % opts.length
        runCtl(["set", "interval", String(opts[i])])
    }

    function activateSelected() {
        const item = currentItem()
        if (!item)
            return
        if (item.kind === "auto") {
            runCtl(["set", "auto", root.auto ? "0" : "1"])
            return
        }
        if (item.kind === "shuffle") {
            runCtl(["set", "shuffle", root.shuffle ? "0" : "1"])
            return
        }
        if (item.kind === "interval") {
            cycleInterval(1)
            return
        }
        if (item.kind === "header") {
            if (item.group === "folders")
                showFolders = !showFolders
            else
                showWallpapers = !showWallpapers
            return
        }
        if (item.kind === "folder") {
            runCtl(["set", "folder", item.name])
            return
        }
        if (item.kind === "wallpaper") {
            runCtl(["set", "wallpaper", item.path])
        }
    }

    function handleKey(event) {
        const item = currentItem()
        if (!item || item.kind !== "interval")
            return false
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Minus) {
            cycleInterval(-1)
            return true
        }
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
            cycleInterval(1)
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
        const needle = (root.query || "").trim()
        const folderList = root.folders || []
        const imageList = root.images || []

        if (matches("auto") || matches("change") || !needle) {
            rows.push({
                key: "auto",
                kind: "auto",
                title: "Auto-change",
                subtitle: root.auto ? "Rotate through the selected folder" : "Keep a single wallpaper",
                current: root.auto
            })
        }
        if (matches("shuffle") || matches("random") || !needle) {
            rows.push({
                key: "shuffle",
                kind: "shuffle",
                title: "Shuffle",
                subtitle: root.shuffle ? "Random order" : "Alphabetical order",
                current: root.shuffle
            })
        }
        if (matches("interval") || matches("timer") || matches("minute") || !needle) {
            rows.push({
                key: "interval",
                kind: "interval",
                title: "Interval",
                subtitle: root.auto ? "Every " + formatInterval(root.interval) : "Used when auto-change is on",
                current: false
            })
        }

        const folderMatches = []
        for (let i = 0; i < folderList.length; i++) {
            const name = folderList[i]
            if (matches(name) || matches("folder"))
                folderMatches.push(name)
        }
        if (matches("folder") || !needle) {
            rows.push({
                key: "header:folders",
                kind: "header",
                group: "folders",
                title: showFolders ? "Hide folders" : "Show folders",
                subtitle: root.folder || "No folder selected",
                current: false
            })
        }
        if (showFolders || needle) {
            for (let i = 0; i < folderMatches.length; i++) {
                const name = folderMatches[i]
                rows.push({
                    key: "folder:" + name,
                    kind: "folder",
                    name: name,
                    title: name,
                    subtitle: name === root.folder ? "Selected folder" : "Wallpaper folder",
                    current: name === root.folder
                })
            }
        }

        const imageMatches = []
        for (let i = 0; i < imageList.length; i++) {
            const path = imageList[i]
            const name = basename(path)
            if (matches(name) || matches("wallpaper") || matches("image"))
                imageMatches.push(path)
        }
        if (matches("wallpaper") || matches("image") || !needle) {
            const n = imageList.length
            rows.push({
                key: "header:wallpapers",
                kind: "header",
                group: "wallpapers",
                title: showWallpapers ? "Hide wallpapers" : "Show wallpapers",
                subtitle: root.wallpaper ? basename(root.wallpaper) : (n + (n === 1 ? " image" : " images")),
                current: false
            })
        }
        if (showWallpapers || needle) {
            for (let i = 0; i < imageMatches.length; i++) {
                const path = imageMatches[i]
                const name = basename(path)
                rows.push({
                    key: "image:" + path,
                    kind: "wallpaper",
                    path: path,
                    title: name,
                    subtitle: path === root.wallpaper ? "Current wallpaper" : "Set as wallpaper",
                    current: path === root.wallpaper
                })
            }
        }
        return rows
    }

    FileView {
        id: stateFile
        path: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/awww/state.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            if (root.tabActive)
                root.refreshStatus()
        }
        onLoadFailed: {
            if (root.tabActive)
                root.refreshStatus()
        }
    }

    Process {
        id: statusProc
        running: false
        command: [root.ctl, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = this.text.trim()
                if (!raw)
                    return
                try {
                    const data = JSON.parse(raw)
                    root.auto = !!data.auto
                    root.shuffle = !!data.shuffle
                    root.folder = data.folder || ""
                    root.wallpaper = data.wallpaper || ""
                    root.interval = Number(data.interval) || 600
                    root.folders = data.folders || []
                    root.images = data.images || []
                    root.statusRev++
                } catch (e) {
                }
            }
        }
    }

    ScriptModel {
        id: listModel
        objectProp: "key"
        values: {
            const _q = root.query
            const _auto = root.auto
            const _shuffle = root.shuffle
            const _folder = root.folder
            const _wallpaper = root.wallpaper
            const _interval = root.interval
            const _folders = root.folders
            const _images = root.images
            const _showF = root.showFolders
            const _showW = root.showWallpapers
            const _rev = root.statusRev
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
            readonly property bool isToggle: modelData.kind === "auto" || modelData.kind === "shuffle"
            readonly property bool isHeader: modelData.kind === "header"
            readonly property bool isWallpaper: modelData.kind === "wallpaper"

            width: ListView.view.width
            height: 52
            radius: theme.radius
            color: selected ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
            border.width: theme.borderWidth
            border.color: selected || modelData.current ? theme.accent : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10

                Item {
                    Layout.preferredWidth: isWallpaper ? 40 : 28
                    Layout.preferredHeight: isWallpaper ? 40 : 28

                    Image {
                        visible: isWallpaper
                        anchors.fill: parent
                        clip: true
                        source: isWallpaper && modelData.path ? ("file://" + modelData.path) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize.width: 80
                        sourceSize.height: 80
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !isWallpaper
                        text: {
                            if (modelData.kind === "auto")
                                return "󰑐"
                            if (modelData.kind === "shuffle")
                                return "󰒟"
                            if (modelData.kind === "interval")
                                return "󰔛"
                            if (modelData.kind === "header" && modelData.group === "folders")
                                return "󰉋"
                            if (modelData.kind === "header")
                                return "󰋩"
                            if (modelData.kind === "folder")
                                return modelData.current ? "󰉋" : "󰉖"
                            return "󰋩"
                        }
                        color: modelData.current ? theme.accent : theme.text
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeXl
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: modelData.title
                        color: modelData.current ? theme.accent : theme.text
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
                    visible: isToggle
                    text: modelData.current ? "On" : "Off"
                    color: modelData.current ? theme.accent : theme.subText
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeSm
                    font.bold: modelData.current
                }

                Text {
                    visible: modelData.kind === "interval"
                    text: root.formatInterval(root.interval)
                    color: theme.accent
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeSm
                    font.bold: true
                }

                Text {
                    visible: isHeader
                    text: (modelData.group === "folders" ? root.showFolders : root.showWallpapers) ? "󰅃" : "󰅀"
                    color: theme.subText
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
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
