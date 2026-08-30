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

    screen: screenModel
    visible: previewVisible && isOnFocusedMonitor
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; left: true; right: true }
    margins.top: 4
    implicitHeight: cardRow.implicitHeight + 16
    mask: Region { item: cardRow }

    readonly property int totalWorkspaces: {
        let maxId = 6
        if (!Hyprland.workspaces || !Hyprland.workspaces.values)
            return maxId
        for (let ws of Hyprland.workspaces.values) {
            if (ws && ws.id > maxId)
                maxId = ws.id
        }
        return maxId
    }

    Row {
        id: cardRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8
        spacing: root.cardGap

        Repeater {
            model: root.totalWorkspaces

            delegate: ClippingRectangle {
                id: card
                required property int index
                readonly property int wsId: index + 1
                readonly property var workspace: {
                    const list = Hyprland.workspaces ? Hyprland.workspaces.values : null
                    if (!list)
                        return null
                    for (let ws of list) {
                        if (ws && ws.id === wsId)
                            return ws
                    }
                    return null
                }
                readonly property var mon: workspace && workspace.monitor ? workspace.monitor : null
                readonly property bool isActive: !!(Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId)
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
                border.width: (isActive || hovered) ? 2 : 1
                border.color: isActive ? theme.accent : (hovered ? theme.text : Qt.rgba(1, 1, 1, 0.18))

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
                            readonly property bool hasGeom: at && sz && at.length >= 2 && sz.length >= 2 && sz[0] > 0 && sz[1] > 0
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
                    border.width: (card.isActive || card.hasWindows) ? 0 : 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)

                    Text {
                        anchors.centerIn: parent
                        text: card.wsId
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
                    onClicked: Hyprland.dispatch(`hl.dsp.focus({workspace = ${card.wsId}})`)
                }
            }
        }
    }
}
