import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

Rectangle {
    id: root
    required property var theme

    visible: Mpris.players.values.length > 0
    color: theme.surface
    radius: theme.radius
    border.width: theme.borderWidth
    border.color: theme.borderColor

    // Static width - consistent size on the bar
    implicitHeight: 36
    implicitWidth: 260

    property int currentIndex: 0
    property int playerCount: Mpris.players.values.length
    onPlayerCountChanged: {
        if (playerCount === 0) {
            currentIndex = 0
        } else if (currentIndex >= playerCount) {
            currentIndex = playerCount - 1
        }
    }

    signal clicked()

    RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 10
        
        MouseArea {
            Layout.fillWidth: true
            Layout.fillHeight: true
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: root.clicked()
            
            RowLayout {
                anchors.fill: parent
                spacing: 10
                
                // Small Album Art
                Rectangle {
                    width: 24
                    height: 24
                    radius: 4
                    color: Qt.rgba(0, 0, 0, 0.3)
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: Mpris.players.values[currentIndex]?.trackArtUrl || ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: theme.fontFace
                        font.pixelSize: 13
                        color: theme.subText
                        visible: parent.children[0].status !== Image.Ready
                    }
                }
                
                // Track Info
                Item {
                    id: marqueeContainer
                    Layout.fillWidth: true
                    clip: true // Hides the overflowing text
                    implicitHeight: trackInfoRow.implicitHeight

                    // Using a standard Row (not RowLayout) so it naturally stretches 
                    // to the full un-elided width of the text for us to measure.
                    Row {
                        id: trackInfoRow
                        spacing: 4

                        // Bold, bright track title
                        Text {
                            text: Mpris.players.values[root.currentIndex]?.trackTitle || "Unknown Track"
                            color: theme.text
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
                            font.bold: true
                            
                            // Reset scroll position instantly when the song changes
                            onTextChanged: trackInfoRow.x = 0 
                        }

                        // Dimmed artist name
                        Text {
                            text: Mpris.players.values[root.currentIndex]?.trackArtist ? "— " + Mpris.players.values[root.currentIndex].trackArtist : ""
                            color: theme.subText 
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
                        }

                        // The Marquee Animation
                        SequentialAnimation on x {
                            id: marqueeAnim
                            loops: Animation.Infinite
                            
                            // Only animate if the text is physically wider than the container
                            running: trackInfoRow.implicitWidth > marqueeContainer.width && marqueeContainer.width > 0

                            // Snap back to 0 if the animation stops (e.g., song changes to a short title)
                            onRunningChanged: {
                                if (!running) trackInfoRow.x = 0
                            }

                            PauseAnimation { duration: 2000 } // Wait 2 seconds before scrolling
                            
                            NumberAnimation {
                                from: 0
                                to: marqueeContainer.width - trackInfoRow.implicitWidth
                                // Dynamic speed: ~30ms per pixel of overflow so long titles don't scroll too fast
                                duration: Math.max(0, trackInfoRow.implicitWidth - marqueeContainer.width) * 30
                            }
                            
                            PauseAnimation { duration: 2000 } // Wait 2 seconds at the end
                            
                            PropertyAction { value: 0 } // Snap instantly back to the start
                        }
                    }
                }
            }
        }

        // Media Controls
        RowLayout {
            spacing: 4

            // Cycle Previous Player
            Text {
                id: prevBtn
                visible: Mpris.players.values.length > 1
                Layout.preferredWidth: 8
                horizontalAlignment: Text.AlignHCenter
                text: "󰒮"
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeMd
                // Rests dim, lights up on hover
                color: prevHover.hovered ? theme.text : theme.subText

                HoverHandler { id: prevHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentIndex = (root.currentIndex - 1 + Mpris.players.values.length) % Mpris.players.values.length
                }
            }

            // Play / Pause
            Text {
                id: playBtn
                Layout.preferredWidth: 20 // Locks the width so changing the icon doesn't shift the layout
                horizontalAlignment: Text.AlignHCenter // Centers the icon perfectly in the locked box
                text: Mpris.players.values[root.currentIndex]?.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeLg
                // Rests bright, shifts to accent on hover
                color: playHover.hovered ? theme.accent : theme.text

                HoverHandler { id: playHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Mpris.players.values[root.currentIndex]?.togglePlaying()
                }
            }

            // Cycle Next Player
            Text {
                id: nextBtn
                visible: Mpris.players.values.length > 1
                Layout.preferredWidth: 8
                horizontalAlignment: Text.AlignHCenter
                text: "󰒭"
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeMd
                color: nextHover.hovered ? theme.text : theme.subText

                HoverHandler { id: nextHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentIndex = (root.currentIndex + 1) % Mpris.players.values.length
                }
            }
        }
    }
}
