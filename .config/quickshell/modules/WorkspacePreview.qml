import Quickshell
import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

PanelWindow {
    id: root

    required property var screenModel
    required property var theme
    required property bool previewVisible
    required property bool barVisible

    readonly property bool isOnFocusedMonitor: {
        const fm = Hyprland.focusedMonitor
        return !!(fm && fm.name && root.screenModel && fm.name === root.screenModel.name)
    }

    readonly property int cardWidth: 220
    readonly property int cardGap: theme.spacing
    readonly property int wsPerMonitor: 5

    screen: screenModel
    visible: previewVisible && isOnFocusedMonitor
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    mask: Region { item: stage }

    readonly property var sortedMonitors: {
        const mons = []
        const vals = Hyprland.monitors ? Hyprland.monitors.values : null
        const n = vals ? vals.length : 0
        for (let i = 0; i < n; i++) {
            const m = vals[i]
            if (m && m.name && m.name !== "FALLBACK")
                mons.push(m)
        }
        mons.sort((a, b) => {
            if (a.x !== b.x)
                return a.x - b.x
            if (a.y !== b.y)
                return a.y - b.y
            return String(a.name).localeCompare(String(b.name))
        })
        return mons
    }

    function localIndexOf(id) {
        const n = root.wsPerMonitor
        let idx = Number(id) % n
        if (idx === 0)
            idx = n
        return idx
    }

    function workspaceOnMonitor(mon, localId, layoutIndex) {
        const list = Hyprland.workspaces ? Hyprland.workspaces.values : null
        if (!list)
            return null
        const gid = layoutIndex * root.wsPerMonitor + localId
        let byId = null
        let byMon = null
        const n = list.length
        for (let i = 0; i < n; i++) {
            const ws = list[i]
            if (!ws || Number(ws.id) <= 0)
                continue
            if (Number(ws.id) === gid)
                byId = ws
            if (mon && ws.monitor && ws.monitor.name === mon.name && root.localIndexOf(ws.id) === localId)
                byMon = ws
        }
        return byId || byMon
    }

    function monitorLabel(mon) {
        const name = mon && mon.name ? String(mon.name) : ""
        const res = (mon && mon.width > 0 && mon.height > 0) ? (mon.width + "×" + mon.height) : ""
        if (name && res)
            return name + "  ·  " + res
        return name || res
    }

    ScriptModel {
        id: monModel
        objectProp: "name"
        values: {
            const _mons = Hyprland.monitors ? Hyprland.monitors.values : []
            const _ws = Hyprland.workspaces ? Hyprland.workspaces.values : []
            const mons = root.sortedMonitors
            const rows = []
            for (let i = 0; i < mons.length; i++) {
                rows.push({
                    name: mons[i].name,
                    layoutIndex: i
                })
            }
            return rows
        }
    }

    Item {
        id: stage
        anchors.centerIn: parent
        width: cardRow.implicitWidth
        height: cardRow.implicitHeight

        Row {
            id: cardRow
            spacing: root.cardGap * 2

            Repeater {
                model: monModel

                delegate: Rectangle {
                    id: group
                    required property var modelData
                    readonly property string monName: modelData.name
                    readonly property int layoutIndex: modelData.layoutIndex
                    readonly property var mon: {
                        const vals = Hyprland.monitors ? Hyprland.monitors.values : null
                        const n = vals ? vals.length : 0
                        for (let i = 0; i < n; i++) {
                            if (vals[i] && vals[i].name === group.monName)
                                return vals[i]
                        }
                        return null
                    }
                    readonly property bool isFocusedMon: {
                        const fm = Hyprland.focusedMonitor
                        return !!(fm && group.mon && fm.name === group.mon.name)
                    }
                    readonly property string monLabel: root.monitorLabel(group.mon)

                    implicitWidth: groupCol.implicitWidth + theme.padding * 2
                    implicitHeight: groupCol.implicitHeight + theme.padding * 2
                    color: theme.background
                    radius: theme.radius
                    border.width: theme.borderWidth
                    border.color: isFocusedMon ? theme.accent : theme.borderColor

                    Column {
                        id: groupCol
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            width: groupRow.implicitWidth
                            text: group.monLabel
                            color: group.isFocusedMon ? theme.accent : theme.text
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Row {
                            id: groupRow
                            spacing: root.cardGap

                            Repeater {
                                model: root.wsPerMonitor

                                delegate: ClippingRectangle {
                                    id: card
                                    required property int index
                                    readonly property int localId: index + 1
                                    readonly property int wsId: group.layoutIndex * root.wsPerMonitor + localId
                                    readonly property var workspace: root.workspaceOnMonitor(group.mon, card.localId, group.layoutIndex)
                                    readonly property var mon: workspace && workspace.monitor ? workspace.monitor : group.mon
                                    readonly property bool isActive: {
                                        const fw = Hyprland.focusedWorkspace
                                        if (!fw)
                                            return false
                                        if (Number(fw.id) === card.wsId)
                                            return true
                                        const onThis = fw.monitor && group.mon && fw.monitor.name === group.mon.name
                                        return !!(onThis && root.localIndexOf(fw.id) === card.localId)
                                    }
                                    readonly property bool hasWindows: {
                                        if (!workspace || !workspace.toplevels || !workspace.toplevels.values)
                                            return false
                                        return workspace.toplevels.values.length > 0
                                    }
                                    readonly property bool hovered: cardHover.hovered
                                    readonly property int monW: mon && mon.width > 0 ? mon.width : 2560
                                    readonly property int monH: mon && mon.height > 0 ? mon.height : 1440

                                    width: root.cardWidth
                                    height: Math.round(width * monH / monW)
                                    radius: theme.radius
                                    color: theme.background
                                    border.width: theme.borderWidth
                                    border.color: isActive ? theme.accent : (hovered ? theme.text : theme.borderColor)

                                    Behavior on border.color { ColorAnimation { duration: 120 } }

                                    Image {
                                        anchors.fill: parent
                                        source: theme.wallpaper
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Qt.rgba(0, 0, 0, card.hasWindows ? 0.12 : 0.40)
                                    }

                                    Item {
                                        id: desktop
                                        anchors.fill: parent
                                        clip: true

                                        Repeater {
                                            model: card.workspace ? card.workspace.toplevels : 0

                                            delegate: Item {
                                                id: win
                                                required property var modelData

                                                readonly property var ipc: modelData.lastIpcObject || {}
                                                readonly property var at: ipc.at
                                                readonly property var sz: ipc.size
                                                readonly property bool hasGeom: !!(at && sz && at.length >= 2 && sz.length >= 2 && sz[0] > 0 && sz[1] > 0)
                                                readonly property int originX: card.mon ? card.mon.x : 0
                                                readonly property int originY: card.mon ? card.mon.y : 0

                                                visible: hasGeom
                                                x: hasGeom ? (at[0] - originX) / card.monW * desktop.width : 0
                                                y: hasGeom ? (at[1] - originY) / card.monH * desktop.height : 0
                                                width: hasGeom ? sz[0] / card.monW * desktop.width : 0
                                                height: hasGeom ? sz[1] / card.monH * desktop.height : 0

                                                ScreencopyView {
                                                    anchors.fill: parent
                                                    captureSource: modelData.wayland
                                                    live: root.visible
                                                    paintCursor: false
                                                    constraintSize: Qt.size(win.width, win.height)
                                                }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    visible: !modelData.wayland
                                                    color: theme.surface
                                                    radius: 2
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 6
                                        width: card.isActive ? 28 : 22
                                        height: 22
                                        radius: theme.radius
                                        color: card.isActive ? theme.accent : (card.hasWindows ? theme.surface : Qt.rgba(0, 0, 0, 0.45))
                                        border.width: (card.isActive || card.hasWindows) ? 0 : theme.borderWidth
                                        border.color: theme.borderColor

                                        Text {
                                            anchors.centerIn: parent
                                            text: card.localId
                                            color: card.isActive ? theme.text : theme.subText
                                            font.family: theme.fontFace
                                            font.pixelSize: theme.fontSizeSm
                                            font.bold: card.isActive
                                        }
                                    }

                                    HoverHandler { id: cardHover }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const mon = group.mon && group.mon.name
                                            if (mon)
                                                Hyprland.dispatch(`hl.dsp.focus({ monitor = "${mon}" })`)
                                            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${card.wsId}, on_current_monitor = true })`)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
