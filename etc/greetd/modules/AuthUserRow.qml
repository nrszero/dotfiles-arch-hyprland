import QtQuick

Item {
    id: root

    required property var theme
    property var users: []
    property string selectedUser: ""

    signal userSelected(string user)

    implicitHeight: 28
    anchors.fill: parent

    ListModel {
        id: chipModel
    }

    function rebuildModel() {
        chipModel.clear()
        for (let i = 0; i < root.users.length; i++)
            chipModel.append({ label: root.users[i], userName: root.users[i] })
        chipModel.append({ label: "Other", userName: "" })
    }

    onUsersChanged: rebuildModel()
    Component.onCompleted: rebuildModel()

    Flickable {
        id: chipFlick
        anchors.fill: parent
        clip: true
        contentWidth: Math.max(width, chipRow.implicitWidth)
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds

        Row {
            id: chipRow
            spacing: 6
            height: chipFlick.height
            x: Math.max(0, (chipFlick.width - implicitWidth) / 2)

            Repeater {
                model: chipModel

                delegate: Item {
                    required property string label
                    required property string userName
                    readonly property bool selected: root.selectedUser === userName

                    height: chipRow.height
                    implicitWidth: chipText.implicitWidth + 16
                    width: implicitWidth

                    Rectangle {
                        anchors.fill: parent
                        radius: root.theme.radius
                        color: selected ? root.theme.accent : Qt.darker(root.theme.surface, 1.2)
                        border.width: selected ? 0 : root.theme.borderWidth
                        border.color: selected ? "transparent" : Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.55)

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: label
                            color: root.theme.text
                            font.family: root.theme.fontFace
                            font.pixelSize: root.theme.fontSizeSm
                            font.bold: selected
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.userSelected(userName)
                        }
                    }
                }
            }
        }
    }
}
