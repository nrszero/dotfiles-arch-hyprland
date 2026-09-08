import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var theme
    property bool inputReady: false
    property string coverText: "Press any key to unlock"
    property string buttonText: "Unlock"
    property bool buttonEnabled: true
    property string placeholderText: "Enter Password"
    property bool placeholderUrgent: false
    property int echoMode: TextInput.Password
    property int inputMethodHints: Qt.ImhSensitiveData

    property alias text: inputField.text
    property alias header: headerHost.data
    readonly property alias inputField: inputField
    readonly property alias coverItem: coverItem

    signal coverDismissed()
    signal submitted()
    signal textEdited(string value)
    signal backRequested()

    Item {
        id: coverItem
        anchors.fill: parent
        opacity: root.inputReady ? 0 : 1
        visible: opacity > 0
        enabled: !root.inputReady
        focus: visible && !root.inputReady

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        AuthCard {
            anchors.centerIn: parent
            theme: root.theme

            Text {
                anchors.centerIn: parent
                text: root.coverText
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeLg
                font.bold: true
                color: theme.text
            }
        }

        Keys.onPressed: (event) => {
            root.coverDismissed()
            event.accepted = true
        }
    }

    ColumnLayout {
        id: authColumn
        anchors.centerIn: parent
        spacing: root.theme.spacing
        opacity: root.inputReady ? 1 : 0
        visible: opacity > 0
        enabled: root.inputReady

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        AuthCard {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 350
            implicitHeight: Math.max(70, cardColumn.implicitHeight + 20)
            width: implicitWidth
            height: implicitHeight
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            theme: root.theme

            ColumnLayout {
                id: cardColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Item {
                    id: headerHost
                    Layout.fillWidth: true
                    visible: children.length > 0
                    implicitHeight: 28
                    Layout.preferredHeight: visible ? 28 : 0
                    Layout.maximumHeight: visible ? 28 : 0
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45

                    TextField {
                        id: inputField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 45
                        horizontalAlignment: TextInput.AlignHCenter
                        verticalAlignment: TextField.AlignVCenter
                        color: theme.text
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeMd
                        passwordCharacter: "\u25CF"
                        echoMode: root.echoMode
                        inputMethodHints: root.inputMethodHints
                        selectByMouse: true
                        focus: true

                        Text {
                            anchors.centerIn: parent
                            visible: inputField.text.length === 0
                            text: root.placeholderText
                            color: root.placeholderUrgent ? theme.urgent : theme.text
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeMd
                        }

                        background: Rectangle {
                            color: Qt.darker(theme.surface, 1.2)
                            border.width: theme.borderWidth
                            border.color: inputField.activeFocus ? theme.accent : "transparent"
                            radius: theme.radius
                        }

                        Component.onCompleted: cursorPosition = text.length
                        onTextEdited: root.textEdited(text)
                        Keys.onReturnPressed: root.submitted()
                        Keys.onEnterPressed: root.submitted()
                        Keys.onEscapePressed: root.backRequested()

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onPressed: (mouse) => {
                                inputField.forceActiveFocus()
                                mouse.accepted = false
                            }
                        }
                    }

                    Button {
                        text: root.buttonText
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 45
                        enabled: root.buttonEnabled && inputField.text.length > 0

                        background: Rectangle {
                            color: parent.hovered || parent.down ? theme.accent : theme.surface
                            radius: theme.radius
                            border.width: theme.borderWidth
                            border.color: theme.borderColor
                        }

                        contentItem: Text {
                            text: parent.text
                            color: theme.text
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.family: theme.fontFace
                            font.bold: true
                            font.pixelSize: theme.fontSizeMd
                        }

                        onClicked: root.submitted()
                    }
                }
            }
        }

        Keys.onEscapePressed: root.backRequested()
    }
}
