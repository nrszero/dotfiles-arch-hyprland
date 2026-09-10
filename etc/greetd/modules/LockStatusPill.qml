import QtQuick
import QtQuick.Layouts

AuthPill {
    id: root
    required property var battery
    required property var networkWidget

    signal powerClicked()

    implicitWidth: statusRow.implicitWidth + 16

    RowLayout {
        id: statusRow
        anchors.centerIn: parent
        spacing: theme.spacing

        Text {
            visible: battery.battPresent
            text: battery.icon
            font.family: theme.fontFace
            font.pixelSize: theme.fontSizeXl
            color: battery.iconColor(theme)
        }

        Text {
            text: networkWidget.isWifiActiveRoute ? "󰤥" : "󰈀"
            font.family: theme.fontFace
            font.pixelSize: theme.fontSizeXl
            color: networkWidget.connectionState === 1 ? theme.accent :
                   networkWidget.connectionState === 2 ? theme.urgent :
                   networkWidget.currentWifiSsid !== "" ? theme.accent : theme.text
        }

        Text {
            text: "󰐥"
            font.family: theme.fontFace
            font.pixelSize: theme.fontSizeXl
            color: theme.text

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.powerClicked()
            }
        }
    }
}
