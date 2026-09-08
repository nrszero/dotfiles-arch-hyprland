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
        property color background: "#33242933"
        property color surface: "#333b4252"
        property color text: "#eceff4"
        property color subText: "#d8dee9"
        property color accent: "#5e81ac"
        property color urgent: "#bf616a"
        property color success: "#a3be8c"
        property color borderColor: "#1a88c0d0"
        property int radius: 12
        property int spacing: 10
        property int padding: 12
        property int borderWidth: 2
        property string fontFace: "JetBrainsMono Nerd Font"
        property int fontSizeSm: 12
        property int fontSizeMd: 16
        property int fontSizeLg: 18
        property int fontSizeXl: 24
        property int fontSizeXXl: 30
    }

    FileView {
        id: greeterColors
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

                theme.text = pywal.special.foreground
                theme.subText = pywal.special.foreground
                theme.accent = pywal.colors.color2
                theme.success = pywal.colors.color2
                theme.borderColor = parseHex(pywal.colors.color6, 0.20)
                theme.background = parseHex(pywal.special.background, 0.60)
                theme.surface = parseHex(pywal.colors.color0, 0.80)
            } catch (e) {
                console.log("[LockScreen Theme] Failed to parse Pywal colors.json", e)
            }
        }
    }

    readonly property bool screenValid: !!(targetScreen && targetScreen.name && targetScreen.name !== "" && targetScreen.name !== "FALLBACK")
    readonly property bool isMain: !!(screenValid && targetScreen && targetScreen.x === 0)
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
        let popups = [lockPowerButtonPopup]
        for (let p of popups) {
            if (p !== target)
                p.visible = false
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

    BatteryProc { id: battery }

    Item {
        anchors.fill: parent
        clip: true

        Image {
            id: wallpaper
            anchors.fill: parent
            source: isMain ? "file:///var/tmp/greeter-wallpaper" : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: false
            smooth: true
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.5
        }
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: 10
        visible: isMain

        Timer {
            interval: 500
            running: isMain && content.visible && !context.screensBlanked
            repeat: true
            onTriggered: {
                if (!content.visible)
                    return
                if (!isInputReady && !authStage.coverItem.activeFocus)
                    authStage.coverItem.forceActiveFocus()
                else if (isInputReady && !authStage.inputField.activeFocus)
                    authStage.inputField.forceActiveFocus()
            }
        }

        AuthPill {
            id: timePillBox
            theme: root.theme
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

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: timeText.text = Qt.formatTime(new Date(), "h:mm AP")
            }
        }

        AuthPill {
            id: infoBar
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            theme: root.theme
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

        LockStatusPill {
            anchors.top: parent.top
            anchors.right: parent.right
            theme: root.theme
            battery: battery
            networkWidget: networkWidget
            onPowerClicked: root.togglePopup(lockPowerButtonPopup)
        }

        AuthStage {
            id: authStage
            anchors.fill: parent
            theme: root.theme
            inputReady: root.isInputReady
            coverText: "Press any key to unlock"
            buttonText: "Unlock"
            buttonEnabled: !context.unlockInProgress
            placeholderText: {
                if (context.showFailure)
                    return "Incorrect Password"
                if (context.maxTries)
                    return "Locked Account (10 min)"
                return "Enter Password"
            }
            placeholderUrgent: context.showFailure || context.maxTries
            echoMode: TextInput.Password
            inputMethodHints: Qt.ImhSensitiveData
            text: context.currentText
            onTextEdited: context.currentText = value
            onCoverDismissed: {
                console.log("[LockScreen] Cover dismissed via keyboard.")
                root.isInputReady = true
                context.poke()
            }
            onSubmitted: context.tryUnlock()
            onBackRequested: {
                context.currentText = ""
                root.isInputReady = false
            }
        }
    }

    Popup {
        id: lockPowerButtonPopup
        x: root.width - width - 10
        y: 50
        width: 400
        height: 360
        padding: 0
        background: Rectangle { color: "transparent" }

        PowerButtonContent {
            anchors.fill: parent
            theme: root.theme
            targetWindow: lockPowerButtonPopup
        }
    }

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
