import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.Pipewire
import Quickshell.Wayland

PopupWindow {
    id: root
    required property var theme

    anchor.edges: Edges.Bottom | Edges.Right
    anchor.margins.right: -6
    anchor.margins.top: 6
    implicitWidth: 400
    implicitHeight: card.implicitHeight + 12
    visible: false
    color: "transparent"

    property bool showOutputDevices: false
    property bool showInputDevices: false

    HoverHandler { id: popupHover }

    AudioDevices { id: devices }

    Timer {
        id: hideTimer
        interval: 3000
        repeat: false
        onTriggered: root.visible = false
    }

    function updateHover() {
        if (!popupHover) return
        
        if (popupHover.hovered) hideTimer.stop()
        else hideTimer.restart()
    }

    Connections { 
        target: popupHover
        function onHoveredChanged() {
            updateHover()
        } 
    }

    onVisibleChanged: {
        if (visible) {
            hideTimer.stop()
            Qt.callLater(updateHover)
        } else {
            showOutputDevices = false
            showInputDevices = false
        }
    }

    function setVolume(node, ratio) {
        if (!node || !node.audio)
            return
        node.audio.muted = false
        node.audio.volume = Math.max(0, Math.min(1, ratio))
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
            spacing: 8
            
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                spacing: 8

                Rectangle {
                    width: 4
                    Layout.preferredHeight: 18
                    radius: 2
                    color: theme.accent 
                }

                Text {
                    text: "Audio"
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                    font.bold: true
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                
                Text {
                    text: "Output"
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeSm
                    font.bold: true
                }
                
                Item { Layout.fillWidth: true }
                
                Text {
                    text: Math.round((devices.sink?.audio.volume ?? 0) * 100) + "%"
                    color: devices.sink?.audio.muted ? theme.urgent : theme.subText
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeSm
                }
            }

            Text {
                text: devices.nodeLabel(devices.sink) || "No output device"
                color: theme.subText
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeSm
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            RowLayout {
                spacing: 12
                
                Text {
                    text: devices.sink?.audio.muted ? "" : 
                          (devices.sink?.audio.volume ?? 0) > 0.5 ? "" : ""
                    font.pixelSize: 20
                    color: devices.sink?.audio.muted ? theme.urgent : theme.text

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (devices.sink)
                                devices.sink.audio.muted = !devices.sink.audio.muted
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: 8; radius: theme.radius
                    color: Qt.darker(theme.surface, 1.5)
                    
                    Rectangle {
                        width: parent.width * Math.min(1, (devices.sink?.audio.volume ?? 0))
                        height: parent.height; radius: 3; 
                        color: devices.sink?.audio.muted ? theme.urgent : theme.accent
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: (mouse) => {
                            if (pressed)
                                root.setVolume(devices.sink, mouse.x / width)
                        }
                        onClicked: (mouse) => root.setVolume(devices.sink, mouse.x / width)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: theme.radius
                color: outToggleMouse.containsMouse ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
                border.width: theme.borderWidth
                border.color: outToggleMouse.containsMouse ? theme.accent : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: root.showOutputDevices ? "Hide output devices" : "Show output devices"
                        color: theme.text
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeSm
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Text {
                        text: devices.sinks.length + (devices.sinks.length === 1 ? " device" : " devices")
                        color: theme.subText
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeSm
                    }

                    Text {
                        text: root.showOutputDevices ? "󰅃" : "󰅀"
                        color: theme.subText
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeMd
                    }
                }

                MouseArea {
                    id: outToggleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showOutputDevices = !root.showOutputDevices
                }
            }

            ColumnLayout {
                visible: root.showOutputDevices
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: devices.sinks
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool current: devices.isCurrentSink(modelData)
                        readonly property bool highlighted: rowMouse.containsMouse || current
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: theme.radius
                        color: highlighted ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
                        border.width: theme.borderWidth
                        border.color: highlighted ? theme.accent : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: ""
                                color: current ? theme.success : theme.subText
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeMd
                            }

                            Text {
                                Layout.fillWidth: true
                                text: devices.nodeLabel(modelData)
                                color: current ? theme.success : theme.text
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeSm
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: devices.setSink(modelData)
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 4 }

            RowLayout {
                Layout.fillWidth: true
                
                Text {
                    text: "Input"
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeSm
                    font.bold: true
                }
                
                Item { Layout.fillWidth: true } 
                
                Text {
                    text: Math.round((devices.source?.audio.volume ?? 0) * 100) + "%"
                    color: devices.source?.audio.muted ? theme.urgent : theme.subText
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeSm
                }
            }

            Text {
                text: devices.nodeLabel(devices.source) || "No input device"
                color: theme.subText
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeSm
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            RowLayout {
                spacing: 12

                Text {
                    text: (devices.source?.audio.muted) ? "󰍭" : "󰍬"
                    font.pixelSize: 20
                    color: devices.source?.audio.muted ? theme.urgent : theme.text

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (devices.source)
                                devices.source.audio.muted = !devices.source.audio.muted
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: 8; radius: theme.radius
                    color: Qt.darker(theme.surface, 1.5)
                    
                    Rectangle {
                        width: parent.width * Math.min(1, (devices.source?.audio.volume ?? 0))
                        height: parent.height; radius: 3; 
                        color: devices.source?.audio.muted ? theme.urgent : theme.accent
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: (mouse) => {
                            if (pressed)
                                root.setVolume(devices.source, mouse.x / width)
                        }
                        onClicked: (mouse) => root.setVolume(devices.source, mouse.x / width)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: theme.radius
                color: inToggleMouse.containsMouse ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
                border.width: theme.borderWidth
                border.color: inToggleMouse.containsMouse ? theme.accent : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: root.showInputDevices ? "Hide input devices" : "Show input devices"
                        color: theme.text
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeSm
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Text {
                        text: devices.sources.length + (devices.sources.length === 1 ? " device" : " devices")
                        color: theme.subText
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeSm
                    }

                    Text {
                        text: root.showInputDevices ? "󰅃" : "󰅀"
                        color: theme.subText
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeMd
                    }
                }

                MouseArea {
                    id: inToggleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showInputDevices = !root.showInputDevices
                }
            }

            ColumnLayout {
                visible: root.showInputDevices
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: devices.sources
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool current: devices.isCurrentSource(modelData)
                        readonly property bool highlighted: srcMouse.containsMouse || current
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: theme.radius
                        color: highlighted ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28) : theme.surface
                        border.width: theme.borderWidth
                        border.color: highlighted ? theme.accent : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: "󰍬"
                                color: current ? theme.success : theme.subText
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeMd
                            }

                            Text {
                                Layout.fillWidth: true
                                text: devices.nodeLabel(modelData)
                                color: current ? theme.success : theme.text
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeSm
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: srcMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: devices.setSource(modelData)
                        }
                    }
                }
            }
        }
    }
}
