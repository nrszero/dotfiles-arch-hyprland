import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQml

Item {
    id: root
    required property var context
    required property var targetScreen 

    // Strict: True ONLY when Wayland confirms this is definitely the main screen
    property bool isMain: !!(targetScreen && targetScreen.x === 0)
    
    // Tracks if the user has dismissed the cover
    property bool isInputReady: false

    onIsMainChanged: {
        // Use the native Hyprland module to dispatch the command
        if (isMain && targetScreen && targetScreen.name) {
            console.log("[LockScreen] Screen recognized, starting 250ms warp delay...")
            warpTimer.restart()
        }
    }

    // Delayed timer to let hardware interrupts and DPMS settle before warping the mouse
    Timer {
        id: warpTimer
        interval: 250 // 250 milliseconds
        repeat: false
        onTriggered: {
            if (isMain && targetScreen && targetScreen.name) {
                console.log("[LockScreen] Delayed warp firing for monitor:", targetScreen.name)
                Hyprland.dispatch(`hl.dsp.focus({ monitor = "${targetScreen.name}" })`)
            }
        }
    }

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
    
    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    // Master
    Item {
        id: content
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
                source: isMain ? "file:///var/tmp/greeter-wallpaper" : ""
                fillMode: Image.PreserveAspectCrop

                // Disable async loading to prevent cross-thread Wayland surface crashes
                asynchronous: false
                cache: false
                smooth: true
            }
        }

        // Light dark overlay (keep this)
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.6
        }
        
        // Auto-focus intelligently targets the cover or the input
        Timer {
            interval: 500
            running: isMain && content.visible
            repeat: true
            onTriggered: {
                if (content.visible) {
                    if (!isInputReady && !coverItem.activeFocus) {
                        coverItem.forceActiveFocus()
                    } else if (isInputReady && !inputField.activeFocus) {
                        inputField.forceActiveFocus()
                    }
                }
            }
        }

        // THE SCREEN COVER
        Item {
            id: coverItem
            anchors.fill: parent
            visible: isMain && !isInputReady
            
            // Allow this item to capture the broken Wayland keystroke
            focus: visible

            Rectangle {
                width: 300
                height: 70
                anchors.centerIn: parent
                
                // Hooking into your Pywal theme for a seamless look
                color: theme.surface
                border.width: theme.borderWidth
                border.color: theme.borderColor
                radius: theme.radius

                Text {
                    anchors.centerIn: parent
                    text: "Press any key to unlock"
                    font.pixelSize: 18
                    font.bold: true
                    color: theme.text
                }
            }

            Keys.onPressed: (event) => {
                console.log("[LockScreen] Cover dismissed via keyboard.")
                isInputReady = true
                event.accepted = true // Prevent the corrupted modifier state from passing through
            }
        }

        // CENTERED LOCK CARD
        Rectangle {
            anchors.fill: parent
            color: "transparent"

            // Hide the actual password card until the cover is gone
            opacity: (isMain && isInputReady) ? 1.0 : 0.0
            visible: isMain && isInputReady
            enabled: isInputReady

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
                            focus: true

                            echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhSensitiveData
                            text: context.currentText
                            onTextEdited: context.currentText = text
                            Keys.onReturnPressed: context.tryUnlock()
                            Component.onCompleted: cursorPosition = text.length

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
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 40
                        enabled: !context.unlockInProgress && inputField.text.length > 0

                        background: Rectangle {
                            color: parent.hovered || parent.down ? theme.accent : theme.surface
                            radius: theme.radius
                            border.width: 2
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
