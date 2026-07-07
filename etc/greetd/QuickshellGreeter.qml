import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Greetd
import Quickshell.Wayland
import Quickshell.Io
import QtQml
import "./modules"

ShellRoot {
    id: root
    
    property Theme appTheme: Theme { id: theme }
 
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
            
            function togglePopup(target) {
                let popups = [
                    lockPowerButtonPopup
                ]
                
                for (let p of popups) {
                    if (p !== target) p.visible = false
                }
                target.visible = !target.visible
            }

            // Greetd is a singleton, so we use Connections to listen to it
            Connections {
                id: context
                target: Greetd
                
                property bool showFailure: false

                function onAuthMessage(message, isError, responseRequired, echo) {
                    context.showFailure = false
                    
                    if (responseRequired) {
                        inputField.text = ""
                        inputField.echoMode = echo ? TextInput.Normal : TextInput.Password
                        inputField.inputMethodHints = echo ? Qt.ImhNone : Qt.ImhSensitiveData
                        inputField.forceActiveFocus()
                        loginState.state = "password"
                    }
                }

                function onAuthFailure(message) {
                    context.showFailure = true

                    loginState.state = "username"
                    inputField.text = ""
                    inputField.echoMode = TextInput.Normal
                    inputField.inputMethodHints = Qt.ImhNone
                    inputField.forceActiveFocus()
                }

                function onReadyToLaunch() {
                    context.showFailure = false

                    // Call the singleton directly
                    Greetd.launch(sessionCommand)
                }

                function onError(error) {
                    context.showFailure = true
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
            
            component BarModule: Rectangle {
                color: theme.background
                radius: theme.radius
                border.width: theme.borderWidth
                border.color: theme.borderColor
                height: 36
                Layout.alignment: Qt.AlignVCenter
            }

            BatteryProc { id: battery }

            // Wallpaper
            Item {
                anchors.fill: parent
                clip: true

                Image {
                    id: wallpaper
                    anchors.fill: parent
                    source: isMain ? "file:///var/tmp/greeter-wallpaper" : ""
                    fillMode: Image.PreserveAspectCrop

                    // Disable async loading to prevent cross-thread Wayland surface crashes
                    asynchronous: true
                    cache: false
                    smooth: true
                }

                // Light dark overlay (keep this)
                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: 0.5
                }
            }

            // Master
            Item {
                id: content
                anchors.fill: parent
                anchors.margins: 10
                visible: isMain

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

                // LEFT SIDE
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignLeft
                    spacing: theme.spacing

                    // Time Pill
                    BarModule {
                        id: timePillBox
                        implicitWidth: timeText.implicitWidth + 20

                        Text {
                            id: timeText
                            anchors.centerIn: parent
                            text: Qt.formatTime(new Date(), "h:mm AP")
                            color: theme.text
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeMd
                            font.bold: true
                        }
                        
                        // Update the clock every second so minutes change on time
                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: timeText.text = Qt.formatTime(new Date(), "h:mm AP")
                        }
                    }
                }
                
                // CENTER
                BarModule {
                    id: infoBar
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: infoText.implicitWidth + 20

                    Text {
                        id: infoText
                        anchors.centerIn: parent
                        text: "󰌾 Locked"
                        color: theme.text
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeMd
                        font.bold: true
                    }
                }
                
                // RIGHT SIDE
                RowLayout {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    spacing: theme.spacing
                    
                    BarModule {
                        implicitWidth: statusRow.implicitWidth + 16
                        
                        RowLayout {
                            id: statusRow
                            anchors.centerIn: parent
                            spacing: theme.spacing
                            
                            // Battery
                            RowLayout {
                                visible: battery.battPresent
                                spacing: 1 // Tight spacing between the battery body and the tip
                                
                                // Main Battery Body
                                Rectangle {
                                    id: batteryProgress
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 16
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 4.5
                                    
                                    // Track Color (The empty part of the battery)
                                    color: theme.surface

                                    // The Solid Fill Level
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: parent.width * battery.battLevel
                                        radius: 4.5
                                        color: theme.text;
                                    }
                                    
                                    // The Inner Text & Icon
                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 0

                                        // Low Battery
                                        Text {
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.rightMargin: 1
                                            text: "!"
                                            font.family: theme.fontFace
                                            font.pixelSize: 12
                                            visible: {
                                                if (battery.battLevel <= 0.2 && !battery.battCharging) {
                                                    return true
                                                }
                                                return false
                                            } 

                                            // Cuts out of the solid fill
                                            color: theme.accent 
                                        }

                                        // Charging Bolt Icon
                                        Text {
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.rightMargin: 1
                                            text: "󱐋"
                                            font.family: theme.fontFace
                                            font.pixelSize: 12
                                            visible: battery.battCharging
                                            // Cuts out of the solid fill
                                            color: theme.accent 
                                        }
                                        
                                        // Percentage Text
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

                                // Battery Tip (The positive terminal nub)
                                Rectangle {
                                    Layout.preferredWidth: 2
                                    Layout.preferredHeight: 6
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 1
                                    
                                    // If full, color it with the fill. Otherwise, use the track color.
                                    color: {
                                        if (battery.battLevel >= 0.98) {
                                            return theme.text;
                                        }

                                        return theme.surface;
                                    }
                                }
                            }
                            
                            // Network
                            Text {
                                id: networkIcon
                                text: networkWidget.isWifiActiveRoute ? "󰤥" : "󰈀"
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeXl
                                color: networkWidget.connectionState === 1 ? theme.accent :
                                       networkWidget.connectionState === 2 ? theme.urgent :
                                       networkWidget.currentWifiSsid !== "" ? theme.accent : theme.text 
                            }

                            // Power
                            Text {
                                id: powerIcon
                                text: "󰐥"
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeXl
                                color: theme.text
                                HoverHandler { id: powerIconHover }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mainWin.togglePopup(lockPowerButtonPopup)
                                }
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
                        width: 300
                        height: 70
                        anchors.centerIn: parent

                        color: theme.surface
                        border.width: theme.borderWidth
                        border.color: theme.borderColor
                        radius: theme.radius

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10

                            // Input Field
                            TextField {
                                id: inputField
                                
                                // Looks
                                Layout.fillWidth: true
                                Layout.preferredHeight: 45
                                horizontalAlignment: TextInput.AlignHCenter
                                verticalAlignment: TextField.AlignVCenter
                                color: theme.text
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeMd
                                passwordCharacter: "\u25CF"
                                Text {
                                    anchors.centerIn: parent
                                    visible: inputField.text.length === 0
                                    text: context.showFailure ? "Incorrect Login" : (loginState.state === "username" ? "Enter Username" : "Enter Password")
                                    color: context.showFailure ? theme.urgent : theme.text
                                    font.pixelSize: theme.fontSizeMd
                                }
                                background: Rectangle {
                                    color: Qt.darker(theme.surface, 1.2)
                                    border.color: inputField.activeFocus ? theme.accent : "transparent"
                                    radius: theme.radius
                                } 
                                echoMode: TextInput.Normal 

                                // Function
                                selectByMouse: true
                                focus: true
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
                            
                            Button {
                                text: loginState.state === "username" ? "Next" : "Login"
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 40
                                    
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
                                    font.bold: true
                                    font.pixelSize: 16
                                }    
                                onClicked: attemptLogin()
                            }
                        }
                    }
                }    
            }

            // === POPUPS ===    
            Popup {
                id: lockPowerButtonPopup
                x: mainWin.width - width - 10
                y: 50
                width: 400
                height: 200
                padding: 0
                
                // Bypasses Qt's default background styling completely
                background: Item {} 

                // Forces Qt to use your UI as the actual content container
                contentItem: PowerButtonContent {
                    anchors.fill: parent
                    theme: root.appTheme
                    targetWindow: lockPowerButtonPopup
                }
            }
            
            // === PROCESS'S ===
            Process {
                id: ethDetector
                command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE d | grep ethernet | head -n 1 | cut -d: -f1"]
                running: true
            }

            Process {
                id: wifiDetector
                command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE d | grep wifi | head -n 1 | cut -d: -f1"]
                running: true
            }

            NetworkWidget {
                id: networkWidget
                interfaceName: ethDetector.stdout ? ethDetector.stdout.trim() : "enp15s0"
                wifiInterfaceName: wifiDetector.stdout ? wifiDetector.stdout.trim() : "wlp14s0"
            }
        }
    }
}
