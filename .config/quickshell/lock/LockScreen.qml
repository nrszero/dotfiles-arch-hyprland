import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io

import "." as Root

Rectangle {
    id: root

    required property var context

    color: "transparent"
    
    QtObject {
        id: theme
        property color surface: "#33000000"
        property color text: "#ccd8dee9"
        property color accent: "#cc5e81ac"
        property color error: "#bf616a"
        property color borderColor: "#3388c0d0"

        property int fontSize: 16
        property int radius: 15
        property int borderWidth: 2
    }

    FileView {
        id: greeterColors
        
        // Point directly to the globally readable mirror
        path: "/var/tmp/greeter-colors.json"
        
        watchChanges: false 
        onFileChanged: reload() 

        onLoaded: {
            try {
                let pywal = JSON.parse(text())
                
                let parseHex = function(hexStr, alpha) {
                    let r = parseInt(hexStr.slice(1, 3), 16) / 255.0
                    let g = parseInt(hexStr.slice(3, 5), 16) / 255.0
                    let b = parseInt(hexStr.slice(5, 7), 16) / 255.0
                    return Qt.rgba(r, g, b, alpha)
                }

                // Map Pywal colors to the greeter theme properties
                theme.text   = pywal.special.foreground
                theme.accent = pywal.colors.color4
                theme.error  = pywal.colors.color1
                theme.borderColor = pywal.colors.color10
                theme.surface = parseHex(pywal.colors.color0, 0.40) 
                
            } catch(e) {
                console.log("[Greeter Theme] Failed to parse Pywal colors.json", e)
            }
        }
    }

    Item {
        anchors.fill: parent
        clip: true                    // This usually kills the white border

        Image {
            id: wallpaper
            anchors.fill: parent
            anchors.margins: -30
            source: "file:///var/tmp/greeter-wallpaper"
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true

            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 42
                blur: 0.6
                brightness: -0.12
                saturation: 0.88
            }
        }
    }

    // Light dark overlay (keep this)
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.18
    }

    // ==================== CENTERED LOCK CARD ====================
    Rectangle {
        width: 400
        height: 300
        anchors.centerIn: parent

        color: theme.surface
        border.width: theme.borderWidth
        border.color: theme.borderColor
        radius: theme.radius

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 20
            width: parent.width * 0.82

            Text {
                text: "Locked"
                font.pixelSize: 26
                font.bold: true
                color: theme.text
                Layout.alignment: Qt.AlignHCenter
            }

            // Status / Prompt
            Text {
                id: statusText
                text: context.showFailure ? "Incorrect password" : "Enter Password"
                color: context.showFailure ? theme.error : theme.text
                font.pixelSize: theme.fontSize
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            // Password Input Field (styled like your greeter)
            Rectangle {
                Layout.fillWidth: true
                height: 48
                color: Qt.darker(theme.surface, 1.15)
                radius: theme.radius
                border.color: inputField.activeFocus ? theme.accent : "transparent"
                border.width: 2

                TextInput {
                    id: inputField
                    anchors.fill: parent
                    anchors.margins: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: theme.text
                    font.pixelSize: theme.fontSize
                    selectByMouse: true
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData
                    focus: true

                    // Sync with context
                    onTextChanged: context.currentText = text

                    // Submit on Enter
                    Keys.onReturnPressed: context.tryUnlock()

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onPressed: (mouse) => {
                            inputField.forceActiveFocus()
                            mouse.accepted = false
                        }
                    }
                }
            }

            // Unlock Button
            Button {
                text: "Unlock"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 130
                Layout.preferredHeight: 42
                enabled: !context.unlockInProgress && inputField.text.length > 0

                background: Rectangle {
                    color: parent.hovered || parent.down ? theme.accent : theme.surface
                    radius: theme.radius
                    border.width: 1
                    border.color: theme.borderColor
                }

                contentItem: Text {
                    text: parent.text
                    color: theme.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.bold: true
                    font.pixelSize: 15
                }

                onClicked: context.tryUnlock()
            }
        }
    }

    // ==================== CLOCK (bottom right of each monitor) ====================
    Text {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 32
        text: Qt.formatTime(new Date(), "hh:mm")
        font.pixelSize: 56
        color: theme.text
        opacity: 0.85

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: parent.text = Qt.formatTime(new Date(), "hh:mm")
        }
    }

    // Auto-focus input when the surface appears
    Timer {
        interval: 80
        running: true
        repeat: false
        onTriggered: inputField.forceActiveFocus()
    }

    // Clear input + refocus after failed attempt
    Connections {
        target: context
        function onShowFailureChanged() {
            if (context.showFailure) {
                inputField.text = ""
                inputField.forceActiveFocus()
            }
        }
    }
}
