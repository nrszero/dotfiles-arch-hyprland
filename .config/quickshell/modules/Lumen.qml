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
    required property string chip
    required property string query
    required property var setChip
    required property var setQuery
    required property PathIndex pathStore
    required property BindIndex bindStore
    required property var notifModel
    required property var dismissNotification
    required property var networkWidget

    signal closeRequested()

    readonly property bool isOnFocusedMonitor: {
        const fm = Hyprland.focusedMonitor
        return !!(fm && fm.name && root.screenModel && fm.name === root.screenModel.name)
    }

    property var history: ({})
    property var calcHistory: []
    property bool keepCalcHistory: false
    property int selectedIndex: 0

    readonly property var parsedQuery: parseQuery(query)
    readonly property bool isMathQuery: parsedQuery.filter === "calc" || isMathText(parsedQuery.needle)
    readonly property string mathExpression: parsedQuery.filter === "calc" ? parsedQuery.needle : parsedQuery.needle
    readonly property bool showingCalc: isMathQuery || (keepCalcHistory && query.trim() === "")
    readonly property var chipOrder: ["all", "apps", "cli", "binds", "power", "networks", "bluetooth", "audio", "notifs", "display", "wallpaper"]
    readonly property var systemChips: ["networks", "bluetooth", "audio", "notifs", "power", "display", "wallpaper"]
    readonly property var jumpTabs: [
        { label: "Networks", value: "networks", icon: "󰖩" },
        { label: "Bluetooth", value: "bluetooth", icon: "󰂯" },
        { label: "Audio", value: "audio", icon: "󰕾" },
        { label: "Notifs", value: "notifs", icon: "󰂚" },
        { label: "Display", value: "display", icon: "󰍹" },
        { label: "Wallpaper", value: "wallpaper", icon: "󰸉" }
    ]
    readonly property bool showingSystemTab: !showingCalc && systemChips.indexOf(parsedQuery.filter) >= 0
    readonly property bool showAllHints: parsedQuery.filter === "all" && !showingCalc
    readonly property var activeTab: {
        switch (parsedQuery.filter) {
        case "networks": return networkTab
        case "bluetooth": return bluetoothTab
        case "audio": return audioTab
        case "notifs": return notifTab
        case "power": return powerTab
        case "display": return displayTab
        case "wallpaper": return wallpaperTab
        default: return null
        }
    }

    screen: screenModel
    visible: lumenVisible && isOnFocusedMonitor && !displayTab.yieldForAuth
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
        const wantPower = filter === "all"

        if (wantApps && DesktopEntries.applications) {
            const apps = [...(DesktopEntries.applications.values || [])]
            for (let i = 0; i < apps.length; i++) {
                const e = apps[i]
                if (!e || !e.name)
                    continue
                const key = "app:" + (e.id || e.name)
                const fields = [e.name, e.genericName || ""]
                if (!isSteamGameShortcut(e))
                    fields.push(e.comment || "")
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
                    ordinal: b.ordinal,
                    command: []
                })
            }
        }

        if (wantPower && needle && powerTab && powerTab.actions) {
            const acts = powerTab.actions
            for (let i = 0; i < acts.length; i++) {
                const a = acts[i]
                const key = "power:" + a.key
                const s = bestScore([a.title, a.subtitle, a.key], needle)
                if (s <= 0)
                    continue
                items.push({
                    key: key,
                    kind: "power",
                    title: a.title,
                    subtitle: a.subtitle,
                    iconName: a.icon,
                    appId: "",
                    triggerText: "",
                    cliPath: "",
                    dispatcher: "",
                    arg: "",
                    score: s,
                    recency: 0,
                    command: a.command
                })
            }
        }

        if (filter === "all" && needle) {
            const tabs = root.jumpTabs
            for (let i = 0; i < tabs.length; i++) {
                const t = tabs[i]
                const s = bestScore([t.label, t.value], needle)
                if (s <= 0)
                    continue
                items.push({
                    key: "tab:" + t.value,
                    kind: "tab",
                    title: t.label,
                    subtitle: "Open " + t.label + " tab",
                    iconName: t.icon,
                    appId: "",
                    triggerText: "",
                    cliPath: "",
                    dispatcher: "",
                    arg: "",
                    chip: t.value,
                    score: s + 8,
                    recency: 0,
                    command: []
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
        if (showingSystemTab && activeTab)
            activeTab.resetSelection()
        Qt.callLater(() => {
            if (resultsView.count > 0)
                resultsView.positionViewAtBeginning()
        })
    }

    function moveSelection(delta) {
        if (root.showingSystemTab && root.activeTab) {
            root.activeTab.moveSelection(delta)
            return
        }
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
        root.setChip(chipOrder[next])
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
        root.setQuery("")
        root.resetSelection()
        searchField.forceActiveFocus()
    }

    function commandHasSteamUrl(cmd) {
        for (let i = 0; i < cmd.length; i++) {
            if (("" + cmd[i]).indexOf("steam://") === 0)
                return true
        }
        return false
    }

    function isSteamGameShortcut(entry) {
        const cmd = (entry && entry.command) || []
        for (let i = 0; i < cmd.length; i++) {
            const a = ("" + cmd[i]).toLowerCase()
            if (a.indexOf("steam://rungameid") >= 0 || a.indexOf("steam://run/") >= 0)
                return true
        }
        return false
    }

    function isSteamClient(entry, cmd) {
        const id = ("" + (entry.id || "")).toLowerCase()
        if (id === "steam" || id === "steam-native" || id === "com.valvesoftware.steam")
            return true
        for (let i = 0; i < cmd.length; i++) {
            const a = ("" + cmd[i]).toLowerCase()
            if (a.indexOf("steam://rungameid") >= 0 || a.indexOf("steam://run/") >= 0)
                return false
        }
        if (("" + (entry.name || "")).toLowerCase() !== "steam" || !cmd.length)
            return false
        const bin = ("" + cmd[0]).toLowerCase()
        return bin === "steam" || bin.endsWith("/steam") || bin.indexOf("com.valvesoftware.steam") >= 0
    }

    function withSteamClientUrl(cmd) {
        // Bare `steam` resumes the last steam://rungameid; open the library instead.
        if (!commandHasSteamUrl(cmd))
            cmd.push("steam://open/games")
        return cmd
    }

    function launchApp(item, inTerminal) {
        const entry = item.appId ? DesktopEntries.byId(item.appId) : DesktopEntries.heuristicLookup(item.title)
        if (!entry) {
            console.error("Lumen: desktop entry not found for " + item.title)
            return
        }
        const parts = []
        const src = entry.command || []
        for (let i = 0; i < src.length; i++)
            parts.push(src[i])
        if (isSteamClient(entry, parts))
            withSteamClientUrl(parts)
        const cmd = (inTerminal || entry.runInTerminal) ? ["kitty", "-e"].concat(parts) : parts
        Quickshell.execDetached({
            command: cmd,
            workingDirectory: entry.workingDirectory || ""
        })
        recordHistory(item.key)
        root.close()
    }

    function launchCli(item, inTerminal) {
        if (!item.cliPath)
            return
        const base = (item.title || item.cliPath || "").split("/").pop()
        let cmd = inTerminal ? ["kitty", "-e", item.cliPath] : [item.cliPath]
        if (base === "steam")
            cmd = withSteamClientUrl(cmd)
        Quickshell.execDetached(cmd)
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
        if (root.showingSystemTab && root.activeTab) {
            root.activeTab.activateSelected()
            return
        }
        if (root.showingCalc) {
            const calcItem = selectedCalcItem()
            if (calcItem && calcItem.live === false) {
                root.setQuery(calcItem.expression)
                root.resetSelection()
                searchField.forceActiveFocus()
                return
            }
            if (root.isMathQuery && calc.result)
                commitCalc()
            return
        }
        const rows = filtered.values
        const item = (rows && selectedIndex >= 0 && selectedIndex < rows.length) ? rows[selectedIndex] : null
        if (!item)
            return
        if (item.kind === "bind")
            return
        if (item.kind === "tab")
            openJumpTab(item)
        else if (item.kind === "app")
            launchApp(item, inTerminal)
        else if (item.kind === "cli")
            launchCli(item, inTerminal)
        else if (item.kind === "power" && item.command)
            launchPower(item)
    }

    function launchPower(item) {
        if (!item.command)
            return
        Quickshell.execDetached(item.command)
        root.close()
    }

    function openJumpTab(item) {
        if (!item || !item.chip)
            return
        root.setChip(item.chip)
        root.keepCalcHistory = false
        root.setQuery("")
        root.resetSelection()
        searchField.forceActiveFocus()
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            if (root.showingSystemTab && root.activeTab && root.activeTab.cancelPending()) {
                searchField.forceActiveFocus()
                event.accepted = true
                return
            }
            root.close()
            event.accepted = true
        } else if (root.showingSystemTab && root.activeTab && root.activeTab.handleKey(event)) {
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

    property bool resumeAfterAuth: false

    onVisibleChanged: {
        if (visible) {
            if (root.resumeAfterAuth) {
                root.resumeAfterAuth = false
                root.setChip("display")
                Qt.callLater(() => {
                    if (displayTab && displayTab.resync)
                        displayTab.resync()
                    searchField.forceActiveFocus()
                })
                return
            }
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
        width: 720
        height: 520
        color: theme.background
        radius: theme.radius
        border.width: theme.borderWidth
        border.color: theme.borderColor

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (networkTab.passwordOpen)
                    return
                searchField.forceActiveFocus()
            }
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
                        root.setQuery(text)
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
                Layout.preferredHeight: 28
                Layout.maximumHeight: 28
                spacing: 6

                Flickable {
                    id: chipFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: Math.max(width, chipRow.implicitWidth)
                    contentHeight: height
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    function scrollChipIntoView(value) {
                        for (let i = 0; i < chipRepeater.count; i++) {
                            const it = chipRepeater.itemAt(i)
                            if (!it || it.isDivider || !it.modelData || it.modelData.value !== value)
                                continue
                            const pad = 6
                            const left = it.x - pad
                            const right = it.x + it.width + pad
                            const viewLeft = contentX
                            const viewRight = contentX + width
                            if (left < viewLeft)
                                contentX = Math.max(0, left)
                            else if (right > viewRight)
                                contentX = Math.max(0, Math.min(Math.max(0, contentWidth - width), right - width))
                            return
                        }
                    }

                    Row {
                        id: chipRow
                        spacing: 6
                        height: chipFlick.height

                        Repeater {
                            id: chipRepeater
                            model: [
                                { label: "All", value: "all", searchable: true },
                                { label: "Apps", value: "apps", searchable: true },
                                { label: "CLI", value: "cli", searchable: true },
                                { label: "Binds", value: "binds", searchable: true },
                                { label: "Power", value: "power", searchable: true },
                                { divider: true },
                                { label: "Networks", value: "networks", searchable: false },
                                { label: "Bluetooth", value: "bluetooth", searchable: false },
                                { label: "Audio", value: "audio", searchable: false },
                                { label: "Notifs", value: "notifs", searchable: false },
                                { label: "Display", value: "display", searchable: false },
                                { label: "Wallpaper", value: "wallpaper", searchable: false }
                            ]

                            delegate: Item {
                                required property var modelData
                                readonly property bool isDivider: !!modelData.divider
                                readonly property bool selected: !isDivider && root.chip === modelData.value
                                readonly property bool searchable: !isDivider && !!modelData.searchable
                                height: chipRow.height
                                implicitWidth: isDivider ? 9 : chipText.implicitWidth + 16
                                width: implicitWidth

                                Rectangle {
                                    visible: isDivider
                                    width: 1
                                    height: 16
                                    anchors.centerIn: parent
                                    color: theme.borderColor
                                }

                                Rectangle {
                                    visible: !isDivider
                                    anchors.fill: parent
                                    radius: theme.radius
                                    color: selected ? theme.accent : theme.surface
                                    border.width: searchable && !selected ? theme.borderWidth : 0
                                    border.color: searchable && !selected ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.55) : "transparent"

                                    Text {
                                        id: chipText
                                        anchors.centerIn: parent
                                        text: modelData.label || ""
                                        color: selected || searchable ? theme.text : theme.subText
                                        font.family: theme.fontFace
                                        font.pixelSize: theme.fontSizeSm
                                        font.bold: selected
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.setChip(modelData.value)
                                            root.keepCalcHistory = false
                                            root.resetSelection()
                                            searchField.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: (event) => {
                            const maxX = Math.max(0, chipFlick.contentWidth - chipFlick.width)
                            if (maxX <= 0)
                                return
                            const dx = event.pixelDelta.x !== 0
                                ? event.pixelDelta.x
                                : ((event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y) / 8)
                            chipFlick.contentX = Math.max(0, Math.min(maxX, chipFlick.contentX - dx))
                            event.accepted = true
                        }
                    }

                    Connections {
                        target: root
                        function onChipChanged() {
                            Qt.callLater(() => chipFlick.scrollChipIntoView(root.chip))
                        }
                    }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: {
                    if (!root.showingSystemTab)
                        return 0
                    switch (root.parsedQuery.filter) {
                    case "networks": return 1
                    case "bluetooth": return 2
                    case "audio": return 3
                    case "notifs": return 4
                    case "power": return 5
                    case "display": return 6
                    case "wallpaper": return 7
                    default: return 0
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
                                visible: modelData.kind === "app" || modelData.kind === "cli" || modelData.kind === "power" || modelData.kind === "tab"

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

                                Text {
                                    anchors.centerIn: parent
                                    visible: modelData.kind === "power" || modelData.kind === "tab"
                                    text: modelData.iconName || ""
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
                                visible: modelData.kind === "app" || modelData.kind === "cli" || modelData.kind === "bind" || modelData.kind === "power" || modelData.kind === "tab"
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

                            Text {
                                visible: root.showAllHints && (modelData.kind === "app" || modelData.kind === "cli" || modelData.kind === "power" || modelData.kind === "bind" || modelData.kind === "tab")
                                text: modelData.kind === "cli" ? "⇧↵" : (modelData.kind === "bind" ? "view" : "↵")
                                color: modelData.kind === "bind" ? theme.subText : theme.accent
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeSm
                                font.bold: modelData.kind !== "bind"
                                font.italic: modelData.kind === "bind"
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

                LumenNetworkTab {
                    id: networkTab
                    theme: root.theme
                    networkWidget: root.networkWidget
                    query: root.parsedQuery.needle
                    tabActive: root.visible && root.showingSystemTab && root.parsedQuery.filter === "networks"
                    onUnhandledKey: (event) => root.handleKey(event)
                    onRequestSearchFocus: searchField.forceActiveFocus()
                }

                LumenBluetoothTab {
                    id: bluetoothTab
                    theme: root.theme
                    query: root.parsedQuery.needle
                    tabActive: root.visible && root.showingSystemTab && root.parsedQuery.filter === "bluetooth"
                }

                LumenAudioTab {
                    id: audioTab
                    theme: root.theme
                    query: root.parsedQuery.needle
                    tabActive: root.visible && root.showingSystemTab && root.parsedQuery.filter === "audio"
                }

                LumenNotifTab {
                    id: notifTab
                    theme: root.theme
                    notifModel: root.notifModel
                    dismissNotification: root.dismissNotification
                    query: root.parsedQuery.needle
                    tabActive: root.visible && root.showingSystemTab && root.parsedQuery.filter === "notifs"
                }

                LumenPowerTab {
                    id: powerTab
                    theme: root.theme
                    query: root.parsedQuery.needle
                    tabActive: root.visible && root.showingSystemTab && root.parsedQuery.filter === "power"
                    onCloseRequested: root.close()
                }

                LumenDisplayTab {
                    id: displayTab
                    theme: root.theme
                    query: root.parsedQuery.needle
                    tabActive: root.visible && root.showingSystemTab && root.parsedQuery.filter === "display"
                    onYieldForAuthChanged: {
                        if (yieldForAuth)
                            root.resumeAfterAuth = true
                    }
                }

                LumenWallpaperTab {
                    id: wallpaperTab
                    theme: root.theme
                    query: root.parsedQuery.needle
                    tabActive: root.visible && root.showingSystemTab && root.parsedQuery.filter === "wallpaper"
                }
            }

            Text {
                Layout.fillWidth: true
                text: {
                    if (root.showingCalc)
                        return "↑↓ move    ↵ save    tab filter    esc close"
                    if (root.parsedQuery.filter === "networks")
                        return "↑↓ move    ↵ connect    del forget    tab filter    esc close"
                    if (root.parsedQuery.filter === "bluetooth")
                        return "↑↓ move    ↵ connect    del forget    tab filter    esc close"
                    if (root.parsedQuery.filter === "audio")
                        return "↑↓ move    ←→ volume    ↵ mute/select    tab filter    esc close"
                    if (root.parsedQuery.filter === "notifs")
                        return "↑↓ move    ↵ dismiss    del dismiss    tab filter    esc close"
                    if (root.parsedQuery.filter === "power")
                        return "↑↓ move    ↵ run    tab filter    esc close"
                    if (root.parsedQuery.filter === "display")
                        return "←→↑↓ move    [ ] select    ↵ apply    tab filter    esc close"
                    if (root.parsedQuery.filter === "wallpaper")
                        return "↑↓ move    ↵ select    ←→ interval    tab filter    esc close"
                    if (root.parsedQuery.filter === "binds")
                        return "↑↓ move    tab filter    esc close"
                    return "↑↓ move    ↵ launch    ⇧↵ terminal    tab filter    esc close"
                }
                color: theme.subText
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeSm
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
