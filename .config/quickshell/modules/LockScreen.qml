import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Item {
    id: root
    required property var context
    required property var targetScreen
    
    property QtObject theme: QtObject {
        // --- COLORS (Nord Palette) ---
        property color background: "#33242933" // Dark grey with transparency
        property color surface:    "#333b4252" // Lighter grey for "Cards"
        property color text:       "#eceff4"   // White-ish text
        property color subText:    "#d8dee9"   // Slightly dimmer text
        property color accent:     "#5e81ac"   // Cyan/Blue accent
        property color urgent:     "#bf616a"   // Red for errors/power
        property color success:    "#a3be8c"   // Green
        property color borderColor: "#1a88c0d0" // Subtle border for glass look

        // --- GEOMETRY ---
        property int radius: 12        // A bit sharper looks more "tech" than 15
        property int spacing: 10
        property int padding: 12
        property int borderWidth: 2

        // --- FONTS ---
        property string fontFace: "JetBrainsMono Nerd Font"
        property int fontSizeSm: 12
        property int fontSizeMd: 16
        property int fontSizeLg: 18
        property int fontSizeXl: 24
        property int fontSizeXXl: 30
    }
    
    // --- DYNAMIC THEMING ---
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

                theme.text    = pywal.special.foreground
                theme.subText = pywal.special.foreground
                theme.accent  = pywal.colors.color2
                theme.urgent  = pywal.colors.color2
                theme.success = pywal.colors.color2
                theme.borderColor = parseHex(pywal.colors.color6, 0.20)
                theme.background = parseHex(pywal.special.background, 0.60)
                theme.surface    = parseHex(pywal.colors.color0, 0.80)

            } catch(e) {
                console.log("[LockScreen Theme] Failed to parse Pywal colors.json", e)
            }
        }
    }

    readonly property bool screenValid: !!(targetScreen && targetScreen.name && targetScreen.name !== "" && targetScreen.name !== "FALLBACK")

    // Strict: True ONLY when Wayland confirms this is definitely the main screen
    readonly property bool isMain: !!(screenValid && targetScreen && targetScreen.x === 0)
    
    // Tracks if the user has dismissed the cover
    property bool isInputReady: false

    function refreshAfterWake() {
        if (!screenValid) {
            console.log("[LockScreen] Ignoring wake refresh, screen is not a real output")
            return
        }
        console.log("[LockScreen] Reloading wallpaper after wake on", targetScreen.name)
        wallpaper.source = ""
        wallpaper.source = isMain ? "file:///var/tmp/greeter-wallpaper" : ""
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

    onIsMainChanged: {
        if (isMain)
            warpTimer.restart()
        else
            warpTimer.stop()
    }

    Timer {
        id: warpTimer
        interval: 250
        repeat: false
        onTriggered: {
            if (!isMain || !screenValid)
                return
            const name = targetScreen.name
            if (!name || name === "FALLBACK")
                return
            console.log("[LockScreen] Delayed warp firing for monitor:", name)
            Hyprland.dispatch(`hl.dsp.focus({ monitor = "${name}" })`)
        }
    }
        
    Rectangle {
        anchors.fill: parent
        color: "black"
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
            running: isMain && content.visible && !context.screensBlanked
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
                            onClicked: root.togglePopup(lockPowerButtonPopup)
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
                width: 350
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
                context.poke()
                event.accepted = true
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
                width: 350
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
                            text: {
                                if (context.showFailure) return "Incorrect Password"
                                if (context.maxTries) return "Locked Account (10 min)"
                                return "Enter Password"
                            }
                            color: (context.showFailure || context.maxTries) ? theme.urgent : theme.text
                            font.pixelSize: theme.fontSizeMd
                        }
                        background: Rectangle {
                            color: Qt.darker(theme.surface, 1.2)
                            border.width: theme.borderWidth
                            border.color: inputField.activeFocus ? theme.accent : "transparent"
                            radius: theme.radius
                        }                                                        
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData

                        // Function
                        selectByMouse: true
                        focus: true
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

                    Button {
                        text: "Unlock"
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 45
                        enabled: !context.unlockInProgress && inputField.text.length > 0

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
                        onClicked: context.tryUnlock()
                    }
                }
            }
        }
    }

    // === POPUPS ===    
    Popup {
        id: lockPowerButtonPopup
        x: root.width - width - 10
        y: 50
        width: 400
        height: 320
        padding: 0

        background: Rectangle { color: "transparent" }

        PowerButtonContent {
            anchors.fill: parent
            theme: root.theme
            targetWindow: lockPowerButtonPopup
        } 
    }
    
    // === PROCESS'S ===
    NetworkWidget {
        id: networkWidget
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        visible: context.screensBlanked
        z: 10000

        onVisibleChanged: {
            if (visible)
                lockPowerButtonPopup.visible = false
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.BlankCursor
            onPressed: context.poke()
            onPositionChanged: context.pokeIfArmed()
        }
    }
}
