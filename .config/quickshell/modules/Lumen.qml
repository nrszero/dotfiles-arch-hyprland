import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore

PanelWindow {
    id: root

    required property var screenModel
    required property var theme
    required property bool lumenVisible
    required property PathIndex pathStore
    required property BindIndex bindStore

    signal closeRequested()

    readonly property bool isOnFocusedMonitor: {
        const fm = Hyprland.focusedMonitor
        return !!(fm && fm.name && root.screenModel && fm.name === root.screenModel.name)
    }

    property string query: ""
    property string chip: "all"
    property var history: ({})
    property var calcHistory: []
    property bool keepCalcHistory: false
    property int selectedIndex: 0

    readonly property var parsedQuery: parseQuery(query)
    readonly property bool isMathQuery: parsedQuery.filter === "calc" || isMathText(parsedQuery.needle)
    readonly property string mathExpression: parsedQuery.filter === "calc" ? parsedQuery.needle : parsedQuery.needle
    readonly property bool showingCalc: isMathQuery || (keepCalcHistory && query.trim() === "")
    readonly property var chipOrder: ["all", "apps", "cli", "binds"]

    screen: screenModel
    visible: lumenVisible && isOnFocusedMonitor
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    mask: Region { item: card }

    function close() {
        root.closeRequested()
    }

    function parseQuery(q) {
        const t = (q || "").trim()
        if (t.startsWith("="))
            return { filter: "calc", needle: t.slice(1).trim() }
        if (t.startsWith(">"))
            return { filter: "cli", needle: t.slice(1).trim() }
        if (t.startsWith("#"))
            return { filter: "binds", needle: t.slice(1).trim() }
        return { filter: root.chip, needle: t }
    }

    function isMathText(s) {
        if (!s)
            return false
        if (!/\d/.test(s))
            return false
        if (!/[+\-*/^%()]/.test(s))
            return false
        return /^[\d\s+\-*/().,%^eE]+$/.test(s)
    }

    function scoreMatch(hay, needle) {
        if (!needle)
            return 1
        if (!hay)
            return 0
        const h = ("" + hay).toLowerCase()
        const n = needle.toLowerCase()
        if (h === n)
            return 100
        if (h.startsWith(n))
            return 80
        if (h.indexOf(n) >= 0)
            return 50
        return 0
    }

    function bestScore(fields, needle) {
        let best = 0
        for (let i = 0; i < fields.length; i++)
            best = Math.max(best, scoreMatch(fields[i], needle))
        return best
    }

    function recencyBoost(key) {
        const t = root.history[key]
        if (!t)
            return 0
        const age = Date.now() - t
        const day = 86400000
        if (age < day)
            return 15
        if (age < 7 * day)
            return 8
        return 3
    }

    function buildResults() {
        const parsed = parseQuery(root.query)
        const needle = parsed.needle
        const filter = parsed.filter
        if (filter === "calc")
            return []

        const items = []
        const wantApps = filter === "all" || filter === "apps"
        const wantCli = filter === "all" || filter === "cli"
        const wantBinds = filter === "all" || filter === "binds"

        if (wantApps && DesktopEntries.applications) {
            const apps = [...(DesktopEntries.applications.values || [])]
            for (let i = 0; i < apps.length; i++) {
                const e = apps[i]
                if (!e || !e.name)
                    continue
                const key = "app:" + (e.id || e.name)
                const fields = [e.name, e.genericName || "", e.comment || ""]
                if (e.keywords) {
                    for (let k = 0; k < e.keywords.length; k++)
                        fields.push(e.keywords[k])
                }
                const s = needle ? bestScore(fields, needle) : 1
                if (s <= 0)
                    continue
                items.push({
                    key: key,
                    kind: "app",
                    title: e.name,
                    subtitle: e.genericName || e.comment || "",
                    iconName: e.icon || "",
                    appId: e.id || "",
                    triggerText: "",
                    cliPath: "",
                    dispatcher: "",
                    arg: "",
                    score: s + recencyBoost(key),
                    recency: root.history[key] || 0
                })
            }
        }

        if (wantCli && root.pathStore && root.pathStore.entries) {
            const ents = root.pathStore.entries
            for (let i = 0; i < ents.length; i++) {
                const e = ents[i]
                if (!needle && filter === "all")
                    continue
                const key = "cli:" + e.name
                const s = needle ? bestScore([e.name], needle) : 1
                if (s <= 0)
                    continue
                items.push({
                    key: key,
                    kind: "cli",
                    title: e.name,
                    subtitle: e.dir || e.path,
                    iconName: "",
                    appId: "",
                    triggerText: "",
                    cliPath: e.path,
                    dispatcher: "",
                    arg: "",
                    score: s + recencyBoost(key),
                    recency: root.history[key] || 0
                })
            }
        }

        if (wantBinds && root.bindStore && root.bindStore.binds) {
            const binds = root.bindStore.binds
            for (let i = 0; i < binds.length; i++) {
                const b = binds[i]
                if (!needle && filter === "all")
                    continue
                const key = "bind:" + b.triggerText + ":" + b.mainTitle
                const s = needle ? bestScore([b.triggerText, b.mainTitle, b.dispatcher, b.arg], needle) : 1
                if (s <= 0)
                    continue
                items.push({
                    key: key,
                    kind: "bind",
                    title: b.mainTitle,
                    subtitle: "",
                    iconName: "",
                    appId: "",
                    triggerText: b.triggerText,
                    cliPath: "",
                    dispatcher: b.dispatcher,
                    arg: b.arg,
                    score: s,
                    recency: 0,
                    ordinal: b.ordinal
                })
            }
        }

        items.sort((a, b) => {
            if (filter === "binds" && !needle)
                return (a.ordinal || 0) - (b.ordinal || 0)
            if (b.score !== a.score)
                return b.score - a.score
            if ((b.recency || 0) !== (a.recency || 0))
                return (b.recency || 0) - (a.recency || 0)
            if (a.kind === "bind" && b.kind === "bind")
                return (a.ordinal || 0) - (b.ordinal || 0)
            return a.title.localeCompare(b.title)
        })
        return items
    }

    function recordHistory(key) {
        const h = Object.assign({}, root.history)
        h[key] = Date.now()
        const keys = Object.keys(h)
        if (keys.length > 200) {
            keys.sort((a, b) => h[a] - h[b])
            for (let i = 0; i < keys.length - 200; i++)
                delete h[keys[i]]
        }
        root.history = h
        historyFile.setText(JSON.stringify(h))
    }

    function resetSelection() {
        selectedIndex = 0
        Qt.callLater(() => {
            if (resultsView.count > 0)
                resultsView.positionViewAtBeginning()
        })
    }

    function moveSelection(delta) {
        const count = resultsView.count
        if (count <= 0) {
            selectedIndex = 0
            return
        }
        selectedIndex = (selectedIndex + delta + count) % count
        resultsView.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    function cycleChip(delta) {
        const i = chipOrder.indexOf(root.chip)
        const next = (i + delta + chipOrder.length) % chipOrder.length
        root.chip = chipOrder[next]
        root.keepCalcHistory = false
        root.resetSelection()
    }

    function copyResult() {
        if (!calc.result)
            return
        clipHelper.text = calc.result
        clipHelper.selectAll()
        clipHelper.copy()
    }

    function calcRows() {
        const rows = []
        if (root.isMathQuery && root.mathExpression) {
            rows.push({
                key: "live:" + root.mathExpression,
                kind: "calc",
                live: true,
                expression: root.mathExpression,
                result: calc.result || "…"
            })
        }
        const hist = root.calcHistory
        for (let i = hist.length - 1; i >= 0; i--) {
            const h = hist[i]
            rows.push({
                key: "hist:" + i + ":" + h.expression + "=" + h.result,
                kind: "calc",
                live: false,
                expression: h.expression,
                result: h.result
            })
        }
        return rows
    }

    function commitCalc() {
        const expr = root.mathExpression
        const res = calc.result
        if (!expr || !res || res === "…")
            return
        const next = root.calcHistory.slice()
        next.push({ expression: expr, result: res })
        root.calcHistory = next
        root.keepCalcHistory = true
        copyResult()
        root.query = ""
        root.resetSelection()
        searchField.forceActiveFocus()
    }

    function launchApp(item, inTerminal) {
        const entry = item.appId ? DesktopEntries.byId(item.appId) : DesktopEntries.heuristicLookup(item.title)
        if (!entry) {
            console.error("Lumen: desktop entry not found for " + item.title)
            return
        }
        if (inTerminal || entry.runInTerminal) {
            const cmd = ["kitty", "-e"]
            const parts = entry.command || []
            for (let i = 0; i < parts.length; i++)
                cmd.push(parts[i])
            Quickshell.execDetached({
                command: cmd,
                workingDirectory: entry.workingDirectory || ""
            })
        } else {
            entry.execute()
        }
        recordHistory(item.key)
        root.close()
    }

    function launchCli(item, inTerminal) {
        if (!item.cliPath)
            return
        if (inTerminal)
            Quickshell.execDetached(["kitty", "-e", item.cliPath])
        else
            Quickshell.execDetached([item.cliPath])
        recordHistory(item.key)
        searchField.forceActiveFocus()
    }

    function selectedCalcItem() {
        const rows = root.calcRows()
        if (selectedIndex < 0 || selectedIndex >= rows.length)
            return null
        return rows[selectedIndex]
    }

    function activateSelected(inTerminal) {
        if (root.showingCalc) {
            const calcItem = selectedCalcItem()
            if (calcItem && calcItem.live === false) {
                root.query = calcItem.expression
                root.resetSelection()
                searchField.forceActiveFocus()
                return
            }
            if (root.isMathQuery && calc.result)
                commitCalc()
            return
        }
        let item = null
        if (resultsView.currentItem && resultsView.currentItem.modelData)
            item = resultsView.currentItem.modelData
        else if (filtered.values && selectedIndex >= 0 && selectedIndex < filtered.values.length)
            item = filtered.values[selectedIndex]
        if (!item)
            return
        if (item.kind === "bind")
            return
        if (item.kind === "app")
            launchApp(item, inTerminal)
        else if (item.kind === "cli")
            launchCli(item, inTerminal)
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            root.close()
            event.accepted = true
        } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier))) {
            moveSelection(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier))) {
            moveSelection(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            activateSelected(!!(event.modifiers & Qt.ShiftModifier))
            event.accepted = true
        } else if (event.key === Qt.Key_Tab) {
            cycleChip(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Backtab) {
            cycleChip(-1)
            event.accepted = true
        }
    }

    onVisibleChanged: {
        if (visible) {
            query = ""
            chip = "all"
            selectedIndex = 0
            keepCalcHistory = false
            if (pathStore && pathStore.refreshIfStale)
                pathStore.refreshIfStale()
            if (bindStore && bindStore.refresh)
                bindStore.refresh()
            Qt.callLater(() => searchField.forceActiveFocus())
        }
    }

    FileView {
        id: historyFile
        path: StandardPaths.writableLocation(StandardPaths.GenericCacheLocation) + "/lumen-history.json"

        onLoaded: {
            try {
                root.history = JSON.parse(text() || "{}")
            } catch (e) {
                root.history = {}
            }
        }

        onLoadFailed: root.history = {}
    }

    LumenCalc {
        id: calc
        expression: (root.visible && root.isMathQuery) ? root.mathExpression : ""
    }

    ScriptModel {
        id: filtered
        objectProp: "key"
        values: {
            const _q = root.query
            const _chip = root.chip
            const _hist = root.history
            const _pathRev = root.pathStore ? root.pathStore.revision : 0
            const _bindRev = root.bindStore ? root.bindStore.revision : 0
            const _apps = DesktopEntries.applications ? DesktopEntries.applications.values : []
            const _path = root.pathStore ? root.pathStore.entries : []
            const _binds = root.bindStore ? root.bindStore.binds : []
            return root.buildResults()
        }
    }

    ScriptModel {
        id: calcModel
        objectProp: "key"
        values: {
            const _expr = root.mathExpression
            const _live = calc.result
            const _hist = root.calcHistory
            const _show = root.showingCalc
            return root.calcRows()
        }
    }

    TextEdit {
        id: clipHelper
        visible: false
        width: 0
        height: 0
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 640
        height: 520
        color: theme.background
        radius: theme.radius
        border.width: theme.borderWidth
        border.color: theme.borderColor

        MouseArea {
            anchors.fill: parent
            onClicked: searchField.forceActiveFocus()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: theme.padding
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    focus: true
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                    placeholderText: "Search"
                    placeholderTextColor: theme.subText
                    leftPadding: 12
                    rightPadding: prefixHint.implicitWidth + 20
                    selectByMouse: true
                    text: root.query
                    background: Rectangle {
                        color: theme.surface
                        border.width: theme.borderWidth
                        border.color: searchField.activeFocus ? theme.accent : "transparent"
                        radius: theme.radius
                    }

                    Text {
                        id: prefixHint
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "= calc   > cli   # binds"
                        color: theme.subText
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeSm
                    }
                    onTextChanged: {
                        root.query = text
                        root.resetSelection()
                    }
                    Keys.onPressed: (event) => root.handleKey(event)
                }

                Rectangle {
                    visible: root.isMathQuery && calc.result !== ""
                    Layout.preferredHeight: 45
                    Layout.preferredWidth: Math.min(180, calcLabel.implicitWidth + 20)
                    color: theme.surface
                    radius: theme.radius
                    border.width: theme.borderWidth
                    border.color: theme.accent

                    Text {
                        id: calcLabel
                        anchors.centerIn: parent
                        width: parent.width - 16
                        text: calc.result
                        color: theme.accent
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeMd
                        font.bold: true
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        { label: "All", value: "all" },
                        { label: "Apps", value: "apps" },
                        { label: "CLI", value: "cli" },
                        { label: "Binds", value: "binds" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool selected: root.chip === modelData.value
                        implicitHeight: 28
                        implicitWidth: chipText.implicitWidth + 16
                        radius: theme.radius
                        color: selected ? theme.accent : theme.surface

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: modelData.label
                            color: theme.text
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
                            font.bold: selected
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.chip = modelData.value
                                root.keepCalcHistory = false
                                root.resetSelection()
                                searchField.forceActiveFocus()
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: {
                        if (root.showingCalc) {
                            const n = root.calcHistory.length
                            return n + (n === 1 ? " saved" : " saved")
                        }
                        const n = filtered.values ? filtered.values.length : 0
                        return n + (n === 1 ? " result" : " results")
                    }
                    color: theme.subText
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeSm
                }
            }

            ListView {
                    id: resultsView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: root.showingCalc ? calcModel : filtered
                    currentIndex: root.selectedIndex
                    keyNavigationWraps: true
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        active: resultsView.moving || resultsView.flicking
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
                        border.color: {
                            if (modelData.kind === "calc" && modelData.live)
                                return theme.accent
                            return index === root.selectedIndex ? theme.accent : "transparent"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            RowLayout {
                                visible: modelData.kind === "calc"
                                Layout.fillWidth: true
                                spacing: 10

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.expression || ""
                                    color: theme.subText
                                    font.family: theme.fontFace
                                    font.pixelSize: theme.fontSizeSm
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: modelData.result || ""
                                    color: theme.accent
                                    font.family: theme.fontFace
                                    font.pixelSize: modelData.live ? theme.fontSizeLg : theme.fontSizeMd
                                    font.bold: true
                                }
                            }

                            Item {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                visible: modelData.kind === "app" || modelData.kind === "cli"

                                IconImage {
                                    id: appIcon
                                    anchors.fill: parent
                                    visible: modelData.kind === "app" && source !== ""
                                    implicitSize: 28
                                    source: modelData.kind === "app" && modelData.iconName !== "" ? Quickshell.iconPath(modelData.iconName, true) : ""
                                    asynchronous: true
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: modelData.kind === "app" && appIcon.source === ""
                                    text: modelData.title ? modelData.title.charAt(0) : "?"
                                    color: theme.accent
                                    font.family: theme.fontFace
                                    font.pixelSize: theme.fontSizeMd
                                    font.bold: true
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: modelData.kind === "cli"
                                    text: "󰆍"
                                    color: theme.accent
                                    font.family: theme.fontFace
                                    font.pixelSize: theme.fontSizeLg
                                }
                            }

                            Text {
                                visible: modelData.kind === "bind"
                                text: modelData.triggerText
                                color: theme.accent
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeSm
                                font.bold: true
                            }

                            ColumnLayout {
                                visible: modelData.kind === "app" || modelData.kind === "cli" || modelData.kind === "bind"
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
                                    visible: modelData.subtitle !== ""
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
                                if (modelData.kind === "calc") {
                                    searchField.forceActiveFocus()
                                    return
                                }
                                root.activateSelected(false)
                            }
                        }
                    }
                }

            Text {
                Layout.fillWidth: true
                text: root.showingCalc
                    ? "↑↓ move    ↵ save    tab filter    esc close"
                    : "↑↓ move    ↵ launch    ⇧↵ terminal    tab filter    esc close"
                color: theme.subText
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeSm
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
