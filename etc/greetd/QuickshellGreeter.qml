import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Greetd
import Quickshell.Wayland
import Quickshell.Io
import QtQml

ShellRoot {
    id: root

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
                theme.surface = parseHex(pywal.colors.color0, 0.80) 
                
            } catch(e) {
                console.log("[Greeter Theme] Failed to parse Pywal colors.json", e)
            }
        }
    }

    // ---------------------------------------------------------
    // UI LAYOUT
    // ---------------------------------------------------------
    Instantiator {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: mainWin
            screen: modelData
            
            property bool isMain: modelData.x === 0

            property bool isInputReady: false
            
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            WlrLayershell.keyboardFocus: isMain ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.layer: WlrLayer.Overlay
            color: "black"
            
            property var sessionCommand: ["start-hyprland"] 

            function attemptLogin() {
                var txt = inputField.text.trim();
                if (txt === "") return;

                if (loginState.state === "username") {
                    Greetd.createSession(txt);
                } else {
                    Greetd.respond(txt);
                }
            }

            // Greetd is a singleton, so we use Connections to listen to it
            Connections {
                target: Greetd

                function onAuthMessage(message, isError, responseRequired, echo) {
                    statusText.text = message
                    statusText.color = isError ? theme.error : theme.text

                    if (responseRequired) {
                        inputField.text = ""
                        inputField.echoMode = echo ? TextInput.Normal : TextInput.Password
                        inputField.inputMethodHints = echo ? Qt.ImhNone : Qt.ImhSensitiveData
                        inputField.forceActiveFocus()
                        loginState.state = "password"
                    }
                }

                function onAuthFailure(message) {
                    statusText.text = "Login Failed: " + message
                    statusText.color = theme.error
                    loginState.state = "username"
                    inputField.text = ""
                    inputField.echoMode = TextInput.Normal
                    inputField.inputMethodHints = Qt.ImhNone
                    inputField.forceActiveFocus()
                }

                function onReadyToLaunch() {
                    statusText.text = "Success. Launching..."
                    statusText.color = theme.accent
                    // Call the singleton directly
                    Greetd.launch(sessionCommand)
                }

                function onError(error) {
                    statusText.text = "Error: " + error
                    statusText.color = theme.error
                }
            }

            // State machine to track where we are
            Item {
                id: loginState
                state: "username" // Initial state
                states: [
                    State { name: "username" },
                    State { name: "password" }
                ]
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

                    Image {
                        id: wallpaper
                        anchors.fill: parent
                        source: "file:///var/tmp/greeter-wallpaper"
                        fillMode: Image.PreserveAspectCrop

                        // Disable async loading to prevent cross-thread Wayland surface crashes
                        asynchronous: true
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
                                text: "Welcome"
                                font.pixelSize: 24
                                font.bold: true
                                color: theme.text
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // Status/Prompt Text
                            Text {
                                id: statusText
                                text: "Enter Username"
                                color: theme.text
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
                                
                                    echoMode: TextInput.Normal 
                                    Keys.onReturnPressed: attemptLogin()
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
                                text: loginState.state === "username" ? "Next" : "Login"
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 120
                                Layout.preferredHeight: 40
                                    
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
                                onClicked: attemptLogin()
                            }
                        }
                    }
                }
                
                // Clock
                Text {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 30
                    text: Qt.formatDateTime(new Date(), "hh:mm")
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
    }
}
