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

    RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 6

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

        // Previous (only if multiple players)
        Text {
            visible: Mpris.players.values.length > 1
            text: "󰒮"
            font.family: theme.fontFace
            font.pixelSize: theme.fontSizeMd
            color: theme.subText

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: currentIndex = (currentIndex - 1 + Mpris.players.values.length) % Mpris.players.values.length
            }
        }

        // Track Info (will elide if too long)
        Text {
            Layout.fillWidth: true
            text: {
                let player = Mpris.players.values[currentIndex]
                if (!player) return ""
                let title = player.trackTitle || "Unknown Track"
                let artist = player.trackArtist || ""
                return artist ? `${title} — ${artist}` : title
            }
            color: theme.text
            font.family: theme.fontFace
            font.pixelSize: theme.fontSizeSm
            elide: Text.ElideRight
        }

        // Play / Pause
        Text {
            text: Mpris.players.values[currentIndex]?.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
            font.family: theme.fontFace
            font.pixelSize: theme.fontSizeLg
            color: theme.accent

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Mpris.players.values[currentIndex]?.togglePlaying()
            }
        }

        // Next (only if multiple players)
        Text {
            visible: Mpris.players.values.length > 1
            text: "󰒭"
            font.family: theme.fontFace
            font.pixelSize: theme.fontSizeMd
            color: theme.subText

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: currentIndex = (currentIndex + 1) % Mpris.players.values.length
            }
        }
    }
}
