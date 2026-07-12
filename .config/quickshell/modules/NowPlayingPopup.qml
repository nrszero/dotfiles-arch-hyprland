import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Wayland

PopupWindow {
    id: root
    required property var theme
    property int currentIndex: 0 // We'll bind this to the Pill's currentIndex
    
    signal requestPlayerChange(int step)

    // Dynamically grab the player based on the index
    property var activePlayer: Mpris.players.values.length > currentIndex ? Mpris.players.values[currentIndex] : null

    anchor.edges: Edges.Bottom | Edges.Left
    anchor.margins.left: -6
    implicitWidth: 400
    implicitHeight: 220
    visible: false
    color: "transparent"
    grabFocus: true

    HoverHandler { id: popupHover }

    Timer {
        id: hideTimer
        interval: 3000
        repeat: false
        onTriggered: root.visible = false
    }

    Timer {
        interval: 1000
        repeat: true
        running: activePlayer?.playbackState === MprisPlaybackState.Playing
        onTriggered: activePlayer?.positionChanged()
    }

    function updateHover() {
        if (!popupHover) return
        if (popupHover.hovered) hideTimer.stop()
        else hideTimer.restart()
    }

    Connections { 
        target: popupHover
        function onHoveredChanged() { updateHover() } 
    }

    onVisibleChanged: if (visible) { hideTimer.stop(); Qt.callLater(updateHover) }
    
    // Helper to format Quickshell's MPRIS seconds into mm:ss
    function formatTime(sec) {
        if (!sec || sec < 0) return "0:00"
        let totalSeconds = Math.floor(sec)
        let minutes = Math.floor(totalSeconds / 60)
        let seconds = totalSeconds % 60
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

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
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Accent Pill
                Rectangle {
                    width: 4
                    Layout.preferredHeight: 18
                    radius: 2
                    color: theme.accent 
                }

                Text {
                    text: "Now Playing"
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                    font.bold: true
                }

                // Spacer pushes the controls to the far right
                Item { Layout.fillWidth: true }

                // Display the current Player Name (e.g. Spotify, Firefox)
                Text {
                    text: activePlayer ? activePlayer.identity : ""
                    color: theme.subText
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeSm
                    visible: Mpris.players.values.length > 1
                }

                // Cycle Previous Source
                Text {
                    visible: Mpris.players.values.length > 1
                    text: "󰒮"
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                    color: prevSourceHover.hovered ? theme.text : theme.subText

                    HoverHandler { id: prevSourceHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestPlayerChange(-1) // Triggers the signal
                    }
                }

                // Cycle Next Source
                Text {
                    visible: Mpris.players.values.length > 1
                    text: "󰒭"
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                    color: nextSourceHover.hovered ? theme.text : theme.subText

                    HoverHandler { id: nextSourceHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestPlayerChange(1) // Triggers the signal
                    }
                }
            }

            // Main Info Area (Art + Text)
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Large Album Art
                Rectangle {
                    width: 64
                    height: 64
                    radius: 6
                    color: Qt.rgba(0, 0, 0, 0.3)
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: activePlayer?.trackArtUrl || ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: theme.fontFace
                        font.pixelSize: 24
                        color: theme.subText
                        visible: parent.children[0].status !== Image.Ready
                    }
                }

                // Title & Artist
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: activePlayer?.trackTitle || "Unknown Track"
                        color: theme.text
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeMd
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: activePlayer?.trackArtist || "Unknown Artist"
                        color: theme.subText
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeSm
                        elide: Text.ElideRight
                    }
                }
            }

            // Progress Bar & Timestamps
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Current Time
                Text {
                    text: root.formatTime(activePlayer?.position)
                    color: theme.subText
                    font.family: theme.fontFace
                    font.pixelSize: 11
                }

                // Interactive Slider
                Rectangle {
                    id: trackSlider
                    Layout.fillWidth: true
                    height: 8
                    radius: 4
                    color: Qt.darker(theme.surface, 1.5)
                    
                    // The filled portion
                    Rectangle {
                        property double progress: (activePlayer && activePlayer.length > 0) ? (activePlayer.position / activePlayer.length) : 0
                        width: parent.width * Math.max(0, Math.min(1, progress))
                        height: parent.height
                        radius: 4
                        color: theme.accent
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: activePlayer?.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                        
                        function seekToMouse(mouse) {
                            if (activePlayer && activePlayer.canSeek && activePlayer.length > 0) {
                                let targetPos = (mouse.x / width) * activePlayer.length
                                activePlayer.position = Math.max(0, Math.min(activePlayer.length, targetPos))
                            }
                        }

                        onPositionChanged: (mouse) => { if (pressed) seekToMouse(mouse) }
                        onClicked: (mouse) => seekToMouse(mouse)
                    }
                }

                // Total Time
                Text {
                    text: root.formatTime(activePlayer?.length)
                    color: theme.subText
                    font.family: theme.fontFace
                    font.pixelSize: 11
                }
            }

            // Media Controls (Larger for Popup)
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 24

                // Previous
                Text {
                    text: "󰒮" // using standard NerdFont icon mappings, adjust if you prefer your exact glyphs
                    font.family: theme.fontFace
                    font.pixelSize: 22
                    color: prevHover.hovered ? theme.text : theme.subText
                    visible: activePlayer?.canGoPrevious ?? false

                    HoverHandler { id: prevHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: activePlayer?.previous()
                    }
                }

                // Play / Pause
                Text {
                    text: activePlayer?.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
                    font.family: theme.fontFace
                    font.pixelSize: 32
                    color: playHover.hovered ? theme.accent : theme.text

                    HoverHandler { id: playHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: activePlayer?.togglePlaying()
                    }
                }

                // Next
                Text {
                    text: "󰒭"
                    font.family: theme.fontFace
                    font.pixelSize: 22
                    color: nextHover.hovered ? theme.text : theme.subText
                    visible: activePlayer?.canGoNext ?? false

                    HoverHandler { id: nextHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: activePlayer?.next()
                    }
                }
            }
        }
    }
}
