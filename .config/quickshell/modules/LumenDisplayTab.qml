import Quickshell
import Quickshell.Hyprland
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
    property var drafts: []
    property bool dragging: false
    property bool applying: false
    property string persistHint: ""
    property bool yieldForAuth: false
    property bool dirty: false

    readonly property var visibleDrafts: {
        const q = (root.query || "").trim().toLowerCase()
        const list = root.drafts || []
        if (!q)
            return list
        return list.filter(d => ((d.name || "") + " " + (d.description || "")).toLowerCase().indexOf(q) >= 0)
    }
    readonly property int itemCount: visibleDrafts.length
    readonly property var selectedDraft: {
        const list = visibleDrafts
        if (selectedIndex < 0 || selectedIndex >= list.length)
            return null
        return list[selectedIndex]
    }
    readonly property string statusText: {
        if (persistHint)
            return persistHint
        const n = itemCount
        return n + (n === 1 ? " display" : " displays")
    }

    onQueryChanged: resetSelection()

    onTabActiveChanged: {
        if (tabActive) {
            persistHint = ""
            if (!root.dirty) {
                Hyprland.refreshMonitors()
                Qt.callLater(syncFromHyprland)
            }
            ipcRefresh.restart()
        } else {
            ipcRefresh.stop()
        }
    }

    Timer {
        id: ipcRefresh
        interval: 180
        repeat: false
        onTriggered: {
            if (root.dirty)
                return
            Hyprland.refreshMonitors()
            Qt.callLater(root.syncFromHyprland)
        }
    }

    function cancelPending() {
        return false
    }

    function resync() {
        Hyprland.refreshMonitors()
        Qt.callLater(root.syncFromHyprland)
        ipcRefresh.restart()
    }

    function resetSelection() {
        selectedIndex = 0
    }

    function moveSelection(delta) {
        const count = itemCount
        if (count <= 0) {
            selectedIndex = 0
            return
        }
        selectedIndex = (selectedIndex + delta + count) % count
    }

    function activateSelected() {
        applyChanges()
    }

    function handleKey(event) {
        if (event.key === Qt.Key_BracketLeft) {
            moveSelection(-1)
            return true
        }
        if (event.key === Qt.Key_BracketRight) {
            moveSelection(1)
            return true
        }
        if (event.key === Qt.Key_Left) {
            nudgeSelected(-1, 0)
            return true
        }
        if (event.key === Qt.Key_Right) {
            nudgeSelected(1, 0)
            return true
        }
        if (event.key === Qt.Key_Up) {
            nudgeSelected(0, -1)
            return true
        }
        if (event.key === Qt.Key_Down) {
            nudgeSelected(0, 1)
            return true
        }
        return false
    }

    function parseMode(s) {
        const m = String(s || "").match(/^(\d+)x(\d+)@([\d.]+)/)
        if (!m)
            return null
        return { w: +m[1], h: +m[2], hz: +m[3] }
    }

    function formatHz(hz) {
        const r = Math.round(hz)
        if (Math.abs(hz - r) < 0.51)
            return String(r)
        return String(Math.round(hz * 100) / 100)
    }

    function modeString(w, h, hz) {
        return w + "x" + h + "@" + formatHz(hz)
    }

    function bestMode(modes) {
        if (!modes || modes.length === 0)
            return null
        let best = modes[0]
        for (let i = 1; i < modes.length; i++) {
            const m = modes[i]
            const area = m.w * m.h
            const bestArea = best.w * best.h
            if (area > bestArea || (area === bestArea && m.hz > best.hz))
                best = m
        }
        return best
    }

    function highestRrMode(modes) {
        if (!modes || modes.length === 0)
            return null
        let best = modes[0]
        for (let i = 1; i < modes.length; i++) {
            const m = modes[i]
            const area = m.w * m.h
            const bestArea = best.w * best.h
            if (m.hz > best.hz || (m.hz === best.hz && area > bestArea))
                best = m
        }
        return best
    }

    function modesMatch(a, w, h, hz) {
        return !!(a && a.w === w && a.h === h && Math.abs(a.hz - hz) < 0.6)
    }

    function nearestMode(modes, w, h, hz) {
        if (!modes || modes.length === 0)
            return { w: w, h: h, hz: hz }
        let same = null
        let sameDiff = Infinity
        let any = null
        let anyScore = Infinity
        for (let i = 0; i < modes.length; i++) {
            const m = modes[i]
            const dHz = Math.abs(m.hz - hz)
            const dRes = Math.abs(m.w - w) + Math.abs(m.h - h)
            const score = dRes * 1000 + dHz
            if (score < anyScore) {
                anyScore = score
                any = m
            }
            if (m.w === w && m.h === h && dHz < sameDiff) {
                sameDiff = dHz
                same = m
            }
        }
        return same || any || { w: w, h: h, hz: hz }
    }

    function bitdepthOf(ipc) {
        if (ipc.bitDepth === 10 || ipc.bitdepth === 10)
            return 10
        const fmt = String(ipc.currentFormat || "")
        if (fmt.indexOf("101010") >= 0 || fmt.indexOf("2101010") >= 0)
            return 10
        return 8
    }

    // Hyprland allows only one predefined mode. Prefer highrr/highres when they
    // describe the selected mode; otherwise write an explicit WxH@Hz.
    function modeKeyword(w, h, hz, modes) {
        const highrr = highestRrMode(modes)
        const highres = bestMode(modes)
        if (modesMatch(highrr, w, h, hz))
            return "highrr"
        if (modesMatch(highres, w, h, hz))
            return "highres"
        return modeString(w, h, hz)
    }

    function layoutSize(w, h, scale) {
        const s = scale > 0 ? scale : 1
        return { lw: Math.max(1, Math.round(w / s)), lh: Math.max(1, Math.round(h / s)) }
    }

    function ipcOf(mon) {
        return mon && mon.lastIpcObject ? mon.lastIpcObject : {}
    }

    function modesFor(mon) {
        const ipc = ipcOf(mon)
        const raw = ipc.availableModes
        const out = []
        const seen = {}
        const n = raw && raw.length !== undefined ? raw.length : 0
        for (let i = 0; i < n; i++) {
            const p = parseMode(raw[i])
            if (!p)
                continue
            const key = p.w + "x" + p.h + "@" + formatHz(p.hz)
            if (seen[key])
                continue
            seen[key] = true
            out.push({ w: p.w, h: p.h, hz: p.hz, label: key })
        }
        if (out.length === 0 && mon) {
            const hz = ipc.refreshRate || 60
            out.push({
                w: mon.width,
                h: mon.height,
                hz: hz,
                label: modeString(mon.width, mon.height, hz)
            })
        }
        return out
    }

    function draftFromMonitor(mon) {
        const ipc = ipcOf(mon)
        const scale = mon.scale > 0 ? mon.scale : 1
        const modes = modesFor(mon)
        const cur = nearestMode(modes, mon.width || 0, mon.height || 0, Number(ipc.refreshRate) || 60)
        const sz = layoutSize(cur.w, cur.h, scale)
        return {
            name: mon.name,
            description: mon.description || ipc.description || "",
            x: mon.x || 0,
            y: mon.y || 0,
            width: cur.w,
            height: cur.h,
            hz: cur.hz,
            scale: scale,
            bitdepth: bitdepthOf(ipc),
            lw: sz.lw,
            lh: sz.lh,
            mode: modeKeyword(cur.w, cur.h, cur.hz, modes),
            modes: modes
        }
    }

    function syncFromHyprland() {
        if (root.dragging || root.applying)
            return
        if (!Hyprland.monitors || !Hyprland.monitors.values)
            return
        const next = []
        for (let m of Hyprland.monitors.values) {
            if (m && m.name)
                next.push(draftFromMonitor(m))
        }
        next.sort((a, b) => {
            if (a.x !== b.x)
                return a.x - b.x
            if (a.y !== b.y)
                return a.y - b.y
            return String(a.name).localeCompare(String(b.name))
        })
        const selName = selectedDraft ? selectedDraft.name : ""
        root.drafts = next
        if (selName) {
            for (let i = 0; i < visibleDrafts.length; i++) {
                if (visibleDrafts[i].name === selName) {
                    selectedIndex = i
                    break
                }
            }
        }
    }

    function overlaps(x, y, w, h, others) {
        for (let i = 0; i < others.length; i++) {
            const o = others[i]
            if (x < o.x + o.lw && x + w > o.x && y < o.y + o.lh && y + h > o.y)
                return true
        }
        return false
    }

    function snapCandidates(d, others) {
        const cands = [{ x: 0, y: 0 }]
        for (let i = 0; i < others.length; i++) {
            const o = others[i]
            cands.push({ x: o.x + o.lw, y: o.y })
            cands.push({ x: o.x + o.lw, y: o.y + o.lh - d.lh })
            cands.push({ x: o.x - d.lw, y: o.y })
            cands.push({ x: o.x - d.lw, y: o.y + o.lh - d.lh })
            cands.push({ x: o.x, y: o.y + o.lh })
            cands.push({ x: o.x + o.lw - d.lw, y: o.y + o.lh })
            cands.push({ x: o.x, y: o.y - d.lh })
            cands.push({ x: o.x + o.lw - d.lw, y: o.y - d.lh })
        }
        return cands
    }

    function snapTo(d, x, y, others) {
        const cands = snapCandidates(d, others)
        let best = { x: Math.round(x), y: Math.round(y), dist: Infinity }
        for (let i = 0; i < cands.length; i++) {
            const c = cands[i]
            if (overlaps(c.x, c.y, d.lw, d.lh, others))
                continue
            const dist = Math.hypot(c.x - x, c.y - y)
            if (dist < best.dist)
                best = { x: Math.round(c.x), y: Math.round(c.y), dist: dist }
        }
        if (best.dist === Infinity)
            return { x: 0, y: 0 }
        return { x: best.x, y: best.y }
    }

    function normalize(list) {
        if (!list.length)
            return list
        let minX = Infinity
        let minY = Infinity
        for (let i = 0; i < list.length; i++) {
            minX = Math.min(minX, list[i].x)
            minY = Math.min(minY, list[i].y)
        }
        if (minX === 0 && minY === 0)
            return list
        return list.map(d => Object.assign({}, d, { x: d.x - minX, y: d.y - minY }))
    }

    function replaceDraft(name, patch) {
        const next = []
        for (let i = 0; i < root.drafts.length; i++) {
            const d = root.drafts[i]
            next.push(d.name === name ? Object.assign({}, d, patch) : d)
        }
        root.drafts = normalize(next)
        root.dirty = true
    }

    function othersOf(name) {
        return root.drafts.filter(d => d.name !== name)
    }

    function nudgeSelected(dx, dy) {
        const d = selectedDraft
        if (!d)
            return
        const others = othersOf(d.name)
        const cands = snapCandidates(d, others)
        let best = null
        let bestDist = Infinity
        for (let i = 0; i < cands.length; i++) {
            const c = cands[i]
            if (overlaps(c.x, c.y, d.lw, d.lh, others))
                continue
            const mx = c.x - d.x
            const my = c.y - d.y
            if (dx !== 0 && mx * dx <= 0)
                continue
            if (dy !== 0 && my * dy <= 0)
                continue
            if (Math.abs(mx) < 1 && Math.abs(my) < 1)
                continue
            const dist = Math.hypot(mx, my)
            if (dist < bestDist) {
                bestDist = dist
                best = c
            }
        }
        if (!best)
            return
        replaceDraft(d.name, { x: best.x, y: best.y })
    }

    function setSelectedMode(w, h, hz) {
        const d = selectedDraft
        if (!d)
            return
        const sz = layoutSize(w, h, d.scale)
        replaceDraft(d.name, {
            width: w,
            height: h,
            hz: hz,
            lw: sz.lw,
            lh: sz.lh,
            mode: modeKeyword(w, h, hz, d.modes)
        })
    }

    function setSelectedScale(scale) {
        const d = selectedDraft
        if (!d)
            return
        const sz = layoutSize(d.width, d.height, scale)
        replaceDraft(d.name, { scale: scale, lw: sz.lw, lh: sz.lh })
    }

    function setSelectedBitdepth(bit) {
        const d = selectedDraft
        if (!d)
            return
        replaceDraft(d.name, { bitdepth: bit })
    }

    function luaEscape(s) {
        return String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
    }

    function generateLua() {
        const list = root.drafts.slice().sort((a, b) => {
            if (a.x !== b.x)
                return a.x - b.x
            if (a.y !== b.y)
                return a.y - b.y
            return String(a.name).localeCompare(String(b.name))
        })
        const lines = ["return {"]
        for (let i = 0; i < list.length; i++) {
            const d = list[i]
            lines.push("    { name = \"" + luaEscape(d.name) + "\", mode = \"" + luaEscape(d.mode)
                + "\", position = \"" + d.x + "x" + d.y + "\", scale = " + d.scale
                + ", bitdepth = " + d.bitdepth + " },")
        }
        lines.push("}")
        return lines.join("\n") + "\n"
    }

    function applyChanges() {
        if (!root.dirty || root.drafts.length === 0)
            return
        applyLive()
        persistNow()
    }

    function applyLive() {
        const parts = []
        for (let i = 0; i < root.drafts.length; i++) {
            const d = root.drafts[i]
            parts.push("hl.monitor({ output = \"" + d.name + "\", mode = \"" + d.mode
                + "\", position = \"" + d.x + "x" + d.y + "\", scale = " + d.scale
                + ", bitdepth = " + d.bitdepth + ", disabled = false })")
        }
        if (parts.length === 0)
            return
        root.applying = true
        applyProc.running = false
        applyProc.command = ["hyprctl", "eval", parts.join("; ")]
        Qt.callLater(() => { applyProc.running = true })
    }

    function persistNow() {
        const lua = generateLua()
        persistFile.setText(lua)
        root.yieldForAuth = true
        persistStart.restart()
    }

    Timer {
        id: persistStart
        interval: 80
        repeat: false
        onTriggered: {
            const p = String(persistFile.path || "").replace("file://", "")
            persistHint = "saving…"
            persistProc.command = ["sh", "-c", "pkexec /etc/greetd/lumen-write-monitors.sh < \"" + p + "\""]
            persistProc.running = false
            Qt.callLater(() => { persistProc.running = true })
        }
    }

    function uniqueResolutions(d) {
        if (!d || !d.modes)
            return []
        const seen = {}
        const out = []
        for (let i = 0; i < d.modes.length; i++) {
            const m = d.modes[i]
            const key = m.w + "x" + m.h
            if (seen[key])
                continue
            seen[key] = true
            out.push(key)
        }
        out.sort((a, b) => {
            const aa = a.split("x")
            const bb = b.split("x")
            return (+bb[0] * +bb[1]) - (+aa[0] * +aa[1])
        })
        return out
    }

    function hzForRes(d, res) {
        if (!d || !d.modes)
            return []
        const parts = String(res).split("x")
        const w = +parts[0]
        const h = +parts[1]
        const out = []
        const seen = {}
        for (let i = 0; i < d.modes.length; i++) {
            const m = d.modes[i]
            if (m.w !== w || m.h !== h)
                continue
            const label = formatHz(m.hz)
            if (seen[label])
                continue
            seen[label] = true
            out.push({ label: label, hz: m.hz })
        }
        out.sort((a, b) => b.hz - a.hz)
        return out
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!root.tabActive || root.dirty)
                return
            if (event.name === "monitoradded" || event.name === "monitorremoved" || event.name === "configreloaded") {
                Hyprland.refreshMonitors()
                Qt.callLater(root.syncFromHyprland)
            }
        }
    }

    FileView {
        id: persistFile
        path: StandardPaths.writableLocation(StandardPaths.GenericCacheLocation) + "/lumen-monitors.lua"
        onLoadFailed: {}
    }

    Process {
        id: applyProc
        running: false
        onRunningChanged: {
            if (!running)
                Qt.callLater(() => {
                    root.applying = false
                    if (!root.dirty) {
                        Hyprland.refreshMonitors()
                        Qt.callLater(root.syncFromHyprland)
                    }
                })
        }
    }

    Process {
        id: persistProc
        running: false
        command: ["true"]
        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: persistErr
        }
        onRunningChanged: {
            if (running)
                return
            const err = persistErr.text ? persistErr.text.trim() : ""
            if (err) {
                root.persistHint = "save failed"
            } else {
                root.dirty = false
                root.persistHint = "saved"
            }
            root.yieldForAuth = false
            if (!err)
                root.resync()
            persistHintClear.restart()
        }
    }

    Timer {
        id: persistHintClear
        interval: 1800
        repeat: false
        onTriggered: root.persistHint = ""
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Item {
            id: canvas
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            readonly property var fit: {
                const list = root.drafts
                const pad = 20
                if (!list || list.length === 0)
                    return { scale: 0.1, originX: 0, originY: 0, pad: pad }
                let minX = Infinity
                let minY = Infinity
                let maxX = -Infinity
                let maxY = -Infinity
                for (let i = 0; i < list.length; i++) {
                    const d = list[i]
                    minX = Math.min(minX, d.x)
                    minY = Math.min(minY, d.y)
                    maxX = Math.max(maxX, d.x + d.lw)
                    maxY = Math.max(maxY, d.y + d.lh)
                }
                const bw = Math.max(1, maxX - minX)
                const bh = Math.max(1, maxY - minY)
                const sx = (width - pad * 2) / bw
                const sy = (height - pad * 2) / bh
                return {
                    scale: Math.max(0.04, Math.min(sx, sy, 0.35)),
                    originX: minX,
                    originY: minY,
                    pad: pad
                }
            }

            function layoutToCanvasX(x) {
                return fit.pad + (x - fit.originX) * fit.scale
            }
            function layoutToCanvasY(y) {
                return fit.pad + (y - fit.originY) * fit.scale
            }
            function canvasToLayoutX(cx) {
                return fit.originX + (cx - fit.pad) / fit.scale
            }
            function canvasToLayoutY(cy) {
                return fit.originY + (cy - fit.pad) / fit.scale
            }

            ScriptModel {
                id: draftModel
                objectProp: "name"
                values: root.drafts
            }

            Repeater {
                model: draftModel

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool isSelected: root.selectedDraft && root.selectedDraft.name === modelData.name
                    width: Math.max(48, modelData.lw * canvas.fit.scale)
                    height: Math.max(32, modelData.lh * canvas.fit.scale)
                    radius: theme.radius
                    color: isSelected ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.35) : theme.surface
                    border.width: theme.borderWidth
                    border.color: isSelected ? theme.accent : theme.borderColor
                    z: dragArea.drag.active ? 10 : 1

                    Binding on x {
                        when: !dragArea.drag.active
                        value: canvas.layoutToCanvasX(modelData.x)
                    }
                    Binding on y {
                        when: !dragArea.drag.active
                        value: canvas.layoutToCanvasY(modelData.y)
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        width: parent.width - 8

                        Text {
                            width: parent.width
                            text: modelData.name
                            color: theme.text
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
                            font.bold: true
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            width: parent.width
                            text: modelData.width + "×" + modelData.height
                            color: theme.subText
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        cursorShape: Qt.SizeAllCursor
                        drag.target: parent
                        onPressed: {
                            root.dragging = true
                            for (let i = 0; i < root.visibleDrafts.length; i++) {
                                if (root.visibleDrafts[i].name === modelData.name) {
                                    root.selectedIndex = i
                                    break
                                }
                            }
                        }
                        onReleased: {
                            const lx = canvas.canvasToLayoutX(parent.x)
                            const ly = canvas.canvasToLayoutY(parent.y)
                            const others = root.othersOf(modelData.name)
                            const snapped = root.snapTo(modelData, lx, ly, others)
                            root.dragging = false
                            root.replaceDraft(modelData.name, { x: snapped.x, y: snapped.y })
                        }
                    }
                }
            }

            Text {
                visible: root.itemCount === 0
                anchors.centerIn: parent
                text: "No monitors"
                color: theme.subText
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeSm
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: detailsCol.implicitHeight + 16
            radius: theme.radius
            color: theme.surface
            border.width: theme.borderWidth
            border.color: theme.borderColor
            visible: !!root.selectedDraft

            ColumnLayout {
                id: detailsCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: {
                        const d = root.selectedDraft
                        if (!d)
                            return ""
                        return d.description ? d.name + "  ·  " + d.description : d.name
                    }
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeSm
                    font.bold: true
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    DisplayCombo {
                        Layout.fillWidth: true
                        label: "Res"
                        model: root.uniqueResolutions(root.selectedDraft)
                        shownValue: root.selectedDraft ? (root.selectedDraft.width + "x" + root.selectedDraft.height) : ""
                        onPicked: (value) => {
                            const d = root.selectedDraft
                            if (!d)
                                return
                            const parts = String(value).split("x")
                            const w = +parts[0]
                            const h = +parts[1]
                            const hzList = root.hzForRes(d, value)
                            const hz = hzList.length ? hzList[0].hz : d.hz
                            root.setSelectedMode(w, h, hz)
                        }
                    }

                    DisplayCombo {
                        Layout.preferredWidth: 110
                        label: "Hz"
                        model: {
                            const d = root.selectedDraft
                            if (!d)
                                return []
                            const list = root.hzForRes(d, d.width + "x" + d.height)
                            const labels = []
                            for (let i = 0; i < list.length; i++)
                                labels.push(list[i].label)
                            return labels
                        }
                        shownValue: root.selectedDraft ? root.formatHz(root.selectedDraft.hz) : ""
                        onPicked: (value) => {
                            const d = root.selectedDraft
                            if (!d)
                                return
                            const list = root.hzForRes(d, d.width + "x" + d.height)
                            for (let i = 0; i < list.length; i++) {
                                if (list[i].label === value) {
                                    root.setSelectedMode(d.width, d.height, list[i].hz)
                                    return
                                }
                            }
                        }
                    }

                    DisplayCombo {
                        Layout.preferredWidth: 90
                        label: "Bit"
                        model: ["8", "10"]
                        shownValue: root.selectedDraft ? String(root.selectedDraft.bitdepth) : "8"
                        onPicked: (value) => root.setSelectedBitdepth(+value)
                    }

                    DisplayCombo {
                        Layout.preferredWidth: 90
                        label: "Scale"
                        model: ["1", "1.25", "1.5", "1.75", "2"]
                        shownValue: root.selectedDraft ? String(root.selectedDraft.scale) : "1"
                        onPicked: (value) => root.setSelectedScale(+value)
                    }

                    Rectangle {
                        Layout.preferredWidth: applyLabel.implicitWidth + 20
                        Layout.preferredHeight: 36
                        radius: theme.radius
                        color: root.dirty ? theme.accent : theme.background
                        border.width: theme.borderWidth
                        border.color: root.dirty ? "transparent" : theme.borderColor
                        opacity: root.dirty ? 1 : 0.55

                        Text {
                            id: applyLabel
                            anchors.centerIn: parent
                            text: root.persistHint === "saving…" ? "Saving" : "Apply"
                            color: theme.text
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.dirty && root.persistHint !== "saving…"
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.applyChanges()
                        }
                    }
                }
            }
        }
    }

    component DisplayCombo: ComboBox {
        id: cb
        required property string label
        property string shownValue: ""
        signal picked(string value)

        Layout.preferredHeight: 36
        font.family: theme.fontFace
        font.pixelSize: theme.fontSizeSm
        currentIndex: {
            const v = String(cb.shownValue || "")
            const m = cb.model
            if (!m)
                return -1
            for (let i = 0; i < m.length; i++) {
                if (String(m[i]) === v)
                    return i
            }
            return -1
        }
        onActivated: (i) => {
            if (i < 0 || i >= count)
                return
            const v = model[i]
            if (v !== undefined)
                cb.picked(String(v))
        }

        background: Rectangle {
            color: theme.background
            radius: theme.radius
            border.width: theme.borderWidth
            border.color: cb.popup.visible ? theme.accent : "transparent"
        }
        contentItem: Text {
            text: cb.label + "  " + (cb.shownValue || "")
            color: theme.text
            font: cb.font
            verticalAlignment: Text.AlignVCenter
            leftPadding: 8
            rightPadding: 8
            elide: Text.ElideRight
        }
        delegate: ItemDelegate {
            required property var modelData
            required property int index
            width: cb.width
            height: 28
            highlighted: cb.highlightedIndex === index
            background: Rectangle {
                color: highlighted ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : "transparent"
                radius: theme.radius
            }
            contentItem: Text {
                text: String(modelData)
                color: theme.text
                font: cb.font
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                leftPadding: 8
            }
        }
        popup: Popup {
            y: cb.height + 4
            width: cb.width
            padding: 4
            background: Rectangle {
                color: theme.background
                radius: theme.radius
                border.width: theme.borderWidth
                border.color: theme.borderColor
            }
            contentItem: ListView {
                clip: true
                implicitHeight: Math.min(200, contentHeight)
                model: cb.delegateModel
                currentIndex: cb.highlightedIndex
            }
        }
    }
}
