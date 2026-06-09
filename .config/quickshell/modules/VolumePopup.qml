import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Quickshell.Wayland

PopupWindow {
    id: root
    required property var theme

    anchor.edges: Edges.Bottom
    anchor.margins.top: 6
    width: 320
    height: 120
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

    onVisibleChanged: if (visible) { hideTimer.stop(); Qt.callLater(updateHover) }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        color: theme.background
        radius: theme.radius
        border.width: theme.borderWidth
        border.color: theme.borderColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // Volume
            RowLayout {
                PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
                
                // Volume Icon (click to mute/unmute)
                Text {
                    text: (Pipewire.defaultAudioSink?.audio.muted) ? "" : ""
                    font.pixelSize: 20
                    color: theme.text

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Pipewire.defaultAudioSink)
                                Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
                        }
                    }
                }

                // Volume Slider
                Rectangle {
                    Layout.fillWidth: true; height: 6; radius: 3
                    color: Qt.darker(theme.surface, 1.5)
                    Rectangle {
                        width: parent.width * (Pipewire.defaultAudioSink?.audio.volume ?? 0)
                        height: parent.height; radius: 3; color: theme.accent
                    }
                    MouseArea {
                        anchors.fill: parent
                        onPositionChanged: (mouse) => {
                            if (Pipewire.defaultAudioSink)
                                Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                        }
                        onClicked: (mouse) => {
                            if (Pipewire.defaultAudioSink)
                                Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                        }

                    }
                }
            }

            // Microphone
            RowLayout {
                PwObjectTracker { objects: [Pipewire.defaultAudioSource] }

                // Mic Icon (click to mute/unmute)
                Text {
                    text: (Pipewire.defaultAudioSource?.audio.muted) ? "󰍭" : "󰍬"
                    font.pixelSize: 20
                    color: theme.text

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Pipewire.defaultAudioSource)
                                Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: 6; radius: 3
                    color: Qt.darker(theme.surface, 1.5)
                    Rectangle {
                        width: parent.width * (Pipewire.defaultAudioSource?.audio.volume ?? 0)
                        height: parent.height; radius: 3; color: theme.accent
                    }
                    MouseArea {
                        anchors.fill: parent
                        onPositionChanged: (mouse) => {
                            if (Pipewire.defaultAudioSource)
                                Pipewire.defaultAudioSource.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                        }
                        onClicked: (mouse) => {
                            if (Pipewire.defaultAudioSource)
                                Pipewire.defaultAudioSource.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                        }
                    }
                }
            }
        }
    }
}
