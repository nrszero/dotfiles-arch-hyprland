import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.Pipewire

Item {
    id: root

    required property var theme
    property string query: ""
    property bool tabActive: false
    property int selectedIndex: 0
    property bool showOutputDevices: false
    property bool showInputDevices: false

    readonly property int itemCount: listModel.values ? listModel.values.length : 0
    readonly property var sink: devices.sink
    readonly property var source: devices.source
    readonly property string statusText: {
        if (sink && sink.audio && sink.audio.muted)
            return "muted"
        return Math.round((sink && sink.audio ? sink.audio.volume : 0) * 100) + "%"
    }

    AudioDevices { id: devices }

    onQueryChanged: resetSelection()

    onTabActiveChanged: {
        if (!tabActive) {
            showOutputDevices = false
            showInputDevices = false
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

    function streamNode(stream) {
        return stream === "output" ? sink : source
    }

    function activateSelected() {
        const item = currentItem()
        if (!item)
            return
        if (item.kind === "toggle") {
            if (item.stream === "output")
                showOutputDevices = !showOutputDevices
            else
                showInputDevices = !showInputDevices
            return
        }
        if (item.kind === "device") {
            if (item.stream === "output")
                devices.setSink(item.node)
            else
                devices.setSource(item.node)
            return
        }
        const node = streamNode(item.stream)
        if (node && node.audio)
            node.audio.muted = !node.audio.muted
    }

    function adjustSelected(step) {
        const item = currentItem()
        const stream = item ? item.stream : "output"
        const node = streamNode(stream)
        if (!node || !node.audio)
            return
        node.audio.muted = false
        node.audio.volume = Math.max(0, Math.min(1, (node.audio.volume ?? 0) + step))
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Minus) {
            adjustSelected(-0.05)
            return true
        }
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
            adjustSelected(0.05)
            return true
        }
        return false
    }

    function setVolume(node, ratio) {
        if (!node || !node.audio)
            return
        node.audio.muted = false
        node.audio.volume = Math.max(0, Math.min(1, ratio))
    }

    function volumeIcon(stream, muted, vol) {
        if (stream === "output") {
            if (muted)
                return ""
            return vol > 0.5 ? "" : ""
        }
        return muted ? "󰍭" : "󰍬"
    }

    function matches(text) {
        const needle = (root.query || "").trim().toLowerCase()
        if (!needle)
            return true
        return ("" + (text || "")).toLowerCase().indexOf(needle) >= 0
    }

    function buildRows() {
        const rows = []
        if (matches("output") || matches("volume") || !(root.query || "").trim()) {
            rows.push({
                key: "vol:output",
                kind: "volume",
                stream: "output",
                title: "Output",
                subtitle: devices.nodeLabel(sink) || "No output device",
                node: null,
                current: false
            })
        }
        if (matches("devices") || matches("output") || !(root.query || "").trim()) {
            const n = devices.sinks.length
            rows.push({
                key: "toggle:output",
                kind: "toggle",
                stream: "output",
                title: showOutputDevices ? "Hide output devices" : "Show output devices",
                subtitle: n + (n === 1 ? " device" : " devices"),
                node: null,
                current: false
            })
        }
        if (showOutputDevices) {
            for (let i = 0; i < devices.sinks.length; i++) {
                const n = devices.sinks[i]
                const label = devices.nodeLabel(n)
                if (!matches(label) && !matches("output"))
                    continue
                rows.push({
                    key: "sink:" + n.id,
                    kind: "device",
                    stream: "output",
                    title: label,
                    subtitle: devices.isCurrentSink(n) ? "Selected output" : "Output device",
                    node: n,
                    current: devices.isCurrentSink(n)
                })
            }
        }
        if (matches("input") || matches("mic") || matches("volume") || !(root.query || "").trim()) {
            rows.push({
                key: "vol:input",
                kind: "volume",
                stream: "input",
                title: "Input",
                subtitle: devices.nodeLabel(source) || "No input device",
                node: null,
                current: false
            })
        }
        if (matches("devices") || matches("input") || matches("mic") || !(root.query || "").trim()) {
            const n = devices.sources.length
            rows.push({
                key: "toggle:input",
                kind: "toggle",
                stream: "input",
                title: showInputDevices ? "Hide input devices" : "Show input devices",
                subtitle: n + (n === 1 ? " device" : " devices"),
                node: null,
                current: false
            })
        }
        if (showInputDevices) {
            for (let i = 0; i < devices.sources.length; i++) {
                const n = devices.sources[i]
                const label = devices.nodeLabel(n)
                if (!matches(label) && !matches("input") && !matches("mic"))
                    continue
                rows.push({
                    key: "source:" + n.id,
                    kind: "device",
                    stream: "input",
                    title: label,
                    subtitle: devices.isCurrentSource(n) ? "Selected input" : "Input device",
                    node: n,
                    current: devices.isCurrentSource(n)
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
            const _sinks = devices.sinks
            const _sources = devices.sources
            const _sink = devices.sink
            const _source = devices.source
            const _outOpen = root.showOutputDevices
            const _inOpen = root.showInputDevices
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
            readonly property var volNode: modelData.kind === "volume" ? root.streamNode(modelData.stream) : null
            readonly property bool muted: !!(volNode && volNode.audio && volNode.audio.muted)
            readonly property real vol: volNode && volNode.audio ? (volNode.audio.volume ?? 0) : 0

            width: ListView.view.width
            height: modelData.kind === "volume" ? 88 : 52
            radius: theme.radius
            color: selected ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
            border.width: theme.borderWidth
            border.color: selected || modelData.current ? theme.accent : "transparent"

            ColumnLayout {
                visible: modelData.kind === "volume"
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: root.volumeIcon(modelData.stream, muted, vol)
                        color: muted ? theme.urgent : theme.text
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeXl

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedIndex = index
                                if (volNode && volNode.audio)
                                    volNode.audio.muted = !volNode.audio.muted
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: modelData.title
                            color: theme.text
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
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

                    Text {
                        text: Math.round(vol * 100) + "%"
                        color: muted ? theme.urgent : theme.subText
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeSm
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 8
                    radius: theme.radius
                    color: Qt.darker(theme.surface, 1.5)

                    Rectangle {
                        width: parent.width * Math.min(1, vol)
                        height: parent.height
                        radius: 3
                        color: muted ? theme.urgent : theme.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: root.selectedIndex = index
                        onPositionChanged: (mouse) => {
                            if (pressed)
                                root.setVolume(volNode, mouse.x / width)
                        }
                        onClicked: (mouse) => root.setVolume(volNode, mouse.x / width)
                    }
                }
            }

            RowLayout {
                visible: modelData.kind === "toggle"
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10

                Text {
                    text: modelData.stream === "output" ? "" : "󰍬"
                    color: theme.subText
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

                Text {
                    text: (modelData.stream === "output" ? root.showOutputDevices : root.showInputDevices) ? "󰅃" : "󰅀"
                    color: theme.subText
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                }
            }

            RowLayout {
                visible: modelData.kind === "device"
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10

                Text {
                    text: modelData.stream === "output" ? "" : "󰍬"
                    color: modelData.current ? theme.success : theme.subText
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeXl
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: modelData.title
                        color: modelData.current ? theme.success : theme.text
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
                z: -1
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.selectedIndex = index
                    if (modelData.kind === "device" || modelData.kind === "toggle")
                        root.activateSelected()
                }
            }
        }
    }
}
