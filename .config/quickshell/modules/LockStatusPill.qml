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

        RowLayout {
            visible: battery.battPresent
            spacing: 1

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter
                radius: 4.5
                color: theme.surface

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * battery.battLevel
                    radius: 4.5
                    color: theme.text
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: 1
                        text: "!"
                        font.family: theme.fontFace
                        font.pixelSize: 12
                        visible: battery.battLevel <= 0.2 && !battery.battCharging
                        color: theme.accent
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: 1
                        text: "󱐋"
                        font.family: theme.fontFace
                        font.pixelSize: 12
                        visible: battery.battCharging
                        color: theme.accent
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        font.family: theme.fontFace
                        font.pixelSize: 12
                        font.bold: true
                        text: Math.round(battery.battLevel * 100)
                        color: theme.accent
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 2
                Layout.preferredHeight: 6
                Layout.alignment: Qt.AlignVCenter
                radius: 1
                color: battery.battLevel >= 0.98 ? theme.text : theme.surface
            }
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
                cursorShape: Qt.PointingHandCursor
                onClicked: root.powerClicked()
            }
        }
    }
}
