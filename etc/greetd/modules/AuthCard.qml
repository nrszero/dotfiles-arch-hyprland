import QtQuick

Rectangle {
    required property var theme

    width: 350
    height: 70
    color: theme.surface
    radius: theme.radius
    border.width: theme.borderWidth
    border.color: theme.borderColor
}
