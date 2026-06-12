import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQml

Item {
    id: root
    required property var context
    required property string screenName

    property bool isMain: screenName === "HDMI-A-1"

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
    
    // Clear input + refocus after failed attempt
    Connections {
        target: context
        function onShowFailureChanged() {
            if (context.showFailure && isMain) {
                inputField.text = ""
                inputField.forceActiveFocus()
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    // Master
    Item {
        anchors.fill: parent
        visible: isMain

        // Wallpaper        
        Item {
            anchors.fill: parent
            clip: true                    // This usually kills the white border

            // Wallpaper
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
        
        // Auto-focus input when the surface appears
        Timer {
            interval: 80
            running: true
            repeat: false
            onTriggered: {
                if (isMain) inputField.forceActiveFocus()
            }
        }
        
        // CENTERED LOCK CARD
        Rectangle {
            anchors.fill: parent
            color: "transparent"

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
                    width: parent.width * 0.8

                    Text {
                        text: "Locked"
                        font.pixelSize: 24
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

                    // Input Field
                    Rectangle {
                        Layout.fillWidth: true
                        height: 45
                        color: Qt.darker(theme.surface, 1.2)
                        radius: theme.radius
                        border.color: inputField.activeFocus ? theme.accent : "transparent"
                        border.width: 2

                        TextInput {
                            id: inputField
                            anchors.fill: parent
                            anchors.margins: 15
                            verticalAlignment: TextInput.AlignVCenter
                            color: theme.text
                            font.pixelSize: theme.fontSize
                            selectByMouse: true
                            echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhSensitiveData
                            focus: isMain

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

                    Button {
                        text: "Unlock"
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 130
                        Layout.preferredHeight: 40
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
                            font.pixelSize: 16
                        }
                        onClicked: context.tryUnlock()
                    }
                }
            }
        }

        // Clock
        Text {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 30
            text: Qt.formatTime(new Date(), "hh:mm")
            font.pixelSize: 64
            color: theme.text
            opacity: 0.8

            Timer {
                interval: 1000; running: true; repeat: true
                onTriggered: parent.text = Qt.formatTime(new Date(), "hh:mm")
            }
        }
    }
}
