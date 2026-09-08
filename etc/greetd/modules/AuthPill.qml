import QtQuick
import QtQuick.Layouts

Rectangle {
    required property var theme

    color: theme.background
    radius: theme.radius
    border.width: theme.borderWidth
    border.color: theme.borderColor
    height: 36
    Layout.alignment: Qt.AlignVCenter
}
