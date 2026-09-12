import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Wayland

PopupWindow {
    id: root
    required property var theme
    required property var battery

    anchor.edges: Edges.Bottom | Edges.Right
    anchor.margins.right: -6
    anchor.margins.top: 6
    implicitWidth: 360
    implicitHeight: card.implicitHeight + 12
    visible: false
    color: "transparent"

    HoverHandler { id: popupHover }

    Timer {
        id: hideTimer
        interval: 3000
        repeat: false
        onTriggered: root.visible = false
    }

    function updateHover() {
        if (!popupHover)
            return
        if (popupHover.hovered)
            hideTimer.stop()
        else
            hideTimer.restart()
    }

    function fmt(n, digits, unit) {
        if (n < 0 || !isFinite(n))
            return "—"
        return n.toFixed(digits) + unit
    }

    Connections {
        target: popupHover
        function onHoveredChanged() { updateHover() }
    }

    Connections {
        target: battery
        function onBattPresentChanged() {
            if (!battery.battPresent)
                root.visible = false
        }
    }

    onVisibleChanged: {
        if (visible) {
            if (battery && battery.watch)
                battery.watch()
            hideTimer.stop()
            Qt.callLater(updateHover)
        } else if (battery && battery.unwatch) {
            battery.unwatch()
        }
    }

    Component.onDestruction: {
        if (visible && battery && battery.unwatch)
            battery.unwatch()
    }

    Rectangle {
        id: card
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        implicitHeight: contentColumn.implicitHeight + 24
        color: theme.background
        radius: theme.radius
        border.width: theme.borderWidth
        border.color: theme.borderColor

        ColumnLayout {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 4
                    Layout.preferredHeight: 18
                    radius: 2
                    color: theme.accent
                }

                Text {
                    text: "Battery"
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                    font.bold: true
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: battery.icon
                    color: battery.iconColor(theme)
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeXXl
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: battery.battPct + "%"
                        color: theme.text
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeLg
                        font.bold: true
                    }

                    Text {
                        text: {
                            const time = battery.timeLabel()
                            return time ? battery.statusLabel() + " · " + time : battery.statusLabel()
                        }
                        color: theme.subText
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeSm
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 8
                radius: theme.radius
                color: Qt.darker(theme.surface, 1.5)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, battery.battLevel))
                    height: parent.height
                    radius: 3
                    color: battery.iconColor(theme)
                }
            }

            Repeater {
                model: {
                    const _w = battery.powerW
                    const _v = battery.voltageV
                    const _now = battery.energyNowWh
                    const _full = battery.energyFullWh
                    const _h = battery.health
                    const _c = battery.battCycles
                    const _profile = battery.profileLabel()
                    return [
                        { label: "Power profile", value: _profile || "—" },
                        { label: "Power draw", value: root.fmt(_w, 1, " W") },
                        { label: "Voltage", value: root.fmt(_v, 2, " V") },
                        { label: "Capacity", value: _now >= 0 && _full >= 0
                            ? _now.toFixed(1) + " / " + _full.toFixed(1) + " Wh" : "—" },
                        { label: "Health", value: _h >= 0 ? Math.round(_h * 100) + "%" : "—" },
                        { label: "Cycles", value: _c >= 0 ? "" + _c : "—" },
                        { label: "Technology", value: battery.battTech || "—" },
                        { label: "Model", value: battery.battModel || battery.battName || "—" }
                    ]
                }

                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: modelData.label
                        color: theme.subText
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeSm
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: modelData.value
                        color: theme.text
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeSm
                        font.bold: true
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignRight
                        Layout.maximumWidth: 200
                    }
                }
            }
        }
    }
}
