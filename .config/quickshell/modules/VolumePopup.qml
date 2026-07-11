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
    implicitWidth: 400
    implicitHeight: 250
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
            spacing: 8
            
            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                spacing: 8

                // Accent Pill
                Rectangle {
                    width: 4
                    Layout.preferredHeight: 18 // Roughly matches the text height
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

            PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

            RowLayout {
                Layout.fillWidth: true
                
                Text {
                    text: "Output"
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeSm
                    font.bold: true
                }
                
                Item { Layout.fillWidth: true } // Spacer pushes percentage to the right
                
                // Volume Percentage readout
                Text {
                    text: Math.round((Pipewire.defaultAudioSink?.audio.volume ?? 0) * 100) + "%"
                    // Turn text urgent color if muted
                    color: Pipewire.defaultAudioSink?.audio.muted ? theme.urgent : theme.subText
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeSm
                }
            }

            // Display the actual hardware device name
            Text {
                text: Pipewire.defaultAudioSink?.description ?? "No output device"
                color: theme.subText
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeSm
                Layout.fillWidth: true
                elide: Text.ElideRight
                Layout.bottomMargin: 4
            }

            RowLayout {
                spacing: 12
                
                // Volume Icon (Dynamic based on volume level and mute state)
                Text {
                    text: Pipewire.defaultAudioSink?.audio.muted ? "" : 
                          (Pipewire.defaultAudioSink?.audio.volume ?? 0) > 0.5 ? "" : ""
                    font.pixelSize: 20
                    color: Pipewire.defaultAudioSink?.audio.muted ? theme.urgent : theme.text

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
                        // Math.min prevents the visual bar from overflowing if volume goes past 100%
                        width: parent.width * Math.min(1, (Pipewire.defaultAudioSink?.audio.volume ?? 0))
                        height: parent.height; radius: 3; 
                        color: Pipewire.defaultAudioSink?.audio.muted ? theme.urgent : theme.accent
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: (mouse) => {
                            if (pressed && Pipewire.defaultAudioSink) {
                                Pipewire.defaultAudioSink.audio.muted = false // Auto-unmute on drag
                                Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                            }
                        }
                        onClicked: (mouse) => {
                            if (Pipewire.defaultAudioSink) {
                                Pipewire.defaultAudioSink.audio.muted = false // Auto-unmute on click
                                Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                            }
                        }
                    }
                }
            }

            // Spacer between sections
            Item { Layout.fillHeight: true; Layout.minimumHeight: 8 }

            // ----------------------------------------------------------------
            // Input Section (Microphone)
            // ----------------------------------------------------------------
            PwObjectTracker { objects: [Pipewire.defaultAudioSource] }

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
                    text: Math.round((Pipewire.defaultAudioSource?.audio.volume ?? 0) * 100) + "%"
                    color: Pipewire.defaultAudioSource?.audio.muted ? theme.urgent : theme.subText
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeSm
                }
            }

            Text {
                text: Pipewire.defaultAudioSource?.description ?? "No input device"
                color: theme.subText
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeSm
                Layout.fillWidth: true
                elide: Text.ElideRight
                Layout.bottomMargin: 4
            }

            RowLayout {
                spacing: 12

                // Mic Icon
                Text {
                    text: (Pipewire.defaultAudioSource?.audio.muted) ? "󰍭" : "󰍬"
                    font.pixelSize: 20
                    color: Pipewire.defaultAudioSource?.audio.muted ? theme.urgent : theme.text

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Pipewire.defaultAudioSource)
                                Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted
                        }
                    }
                }

                // Mic Slider
                Rectangle {
                    Layout.fillWidth: true; height: 6; radius: 3
                    color: Qt.darker(theme.surface, 1.5)
                    
                    Rectangle {
                        width: parent.width * Math.min(1, (Pipewire.defaultAudioSource?.audio.volume ?? 0))
                        height: parent.height; radius: 3; 
                        color: Pipewire.defaultAudioSource?.audio.muted ? theme.urgent : theme.accent
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: (mouse) => {
                            if (pressed && Pipewire.defaultAudioSource) {
                                Pipewire.defaultAudioSource.audio.muted = false
                                Pipewire.defaultAudioSource.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                            }
                        }
                        onClicked: (mouse) => {
                            if (Pipewire.defaultAudioSource) {
                                Pipewire.defaultAudioSource.audio.muted = false
                                Pipewire.defaultAudioSource.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                            }
                        }
                    }
                }
            }
        }
    }
}
