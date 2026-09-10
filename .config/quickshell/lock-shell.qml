import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Io
import "./modules"

ShellRoot {
    id: root

    PersistentProperties {
        id: persist
        reloadableId: "lockWake"

        property real lastWakeUnix: 0
    }

    function rebindSurfaces() {
        console.log("[Lock] Rebinding lock surfaces after wake")
        Quickshell.reload(false)
    }

    Scope {
        id: lockContext
        
        property string currentText: ""
        property bool unlockInProgress: false
        property bool showFailure: false
        property bool maxTries: false
        property bool authUnavailable: false
        property bool screensBlanked: false
        property bool blankInputArmed: false
        property bool readyWritten: false
        property bool mainIsReal: false
        property real sessionStartUnix: 0

        Component.onCompleted: sessionStartUnix = Date.now() / 1000

        signal unlocked()

        function poke() {
            screensBlanked = false
            blankInputArmed = false
            blankTimer.restart()
        }

        function markReady() {
            if (readyWritten)
                return
            readyWritten = true
            readyWriter.running = true
        }

        function noteMainReal(isReal) {
            if (isReal === mainIsReal)
                return
            mainIsReal = isReal
            if (isReal)
                readyDebounce.restart()
            else
                readyDebounce.stop()
        }

        Timer {
            id: readyDebounce
            interval: 1500
            repeat: false
            onTriggered: lockContext.markReady()
        }

        function handleHardwareWake(ts) {
            const token = ts || 0
            if (token && token <= persist.lastWakeUnix)
                return
            if (token)
                persist.lastWakeUnix = token
            console.log("[Lock] Hardware wake detected")
            poke()
            root.rebindSurfaces()
        }

        function pokeIfArmed() {
            if (screensBlanked && !blankInputArmed)
                return
            poke()
        }

        Timer {
            id: blankTimer
            interval: 150000
            running: true
            repeat: false
            onTriggered: {
                lockContext.screensBlanked = true
                lockContext.blankInputArmed = false
                blankArmTimer.restart()
            }
        }

        Timer {
            id: blankArmTimer
            interval: 750
            repeat: false
            onTriggered: lockContext.blankInputArmed = true
        }
        
        onCurrentTextChanged: {
            showFailure = false
            maxTries = false
            authUnavailable = false
            poke()
        }

        function resetAttempt() {
            unlockInProgress = false
            currentText = ""
        }

        function tryUnlock() {
            if (unlockInProgress || currentText.trim() === "")
                return

            showFailure = false
            maxTries = false
            authUnavailable = false
            unlockInProgress = true
            if (!pam.start()) {
                resetAttempt()
                authUnavailable = true
            }
        }
        
        PamContext {
            id: pam
            configDirectory: "/etc/pam.d"
            config: "quickshell"

            onPamMessage: {
                console.log("[PAM] Message:", pam.message, "responseRequired:", pam.responseRequired)
                
                if (pam.message && pam.message.toLowerCase().includes("locked")) {
                    lockContext.maxTries = true
                }

                if (pam.responseRequired) {
                    pam.respond(lockContext.currentText)
                }
            }

            onCompleted: function(result) {
                console.log("[PAM] Completed with result:", result)
                
                if (result === PamResult.Success) {
                    lockContext.unlocked()
                    return
                }

                const lockoutReported = lockContext.maxTries
                lockContext.resetAttempt()
                if (result === PamResult.MaxTries || lockoutReported)
                    lockContext.maxTries = true
                else if (result === PamResult.Failed)
                    lockContext.showFailure = true
                else
                    lockContext.authUnavailable = true
            }

            onError: function(error) {
                console.log("[PAM] Authentication service error:", error)
            }
        }

        Process {
            id: readyWriter
            running: false
            command: ["bash", "-c", "date +%s > /var/tmp/qs-lock-ready"]
        }
    }
    
    WlSessionLock {
        id: lock
        locked: true
        reloadableId: "sessionLock"

        WlSessionLockSurface {
            id: lockSurface

            property real appliedWakeUnix: 0
            property bool wakeFilePrimed: false
            readonly property string screenKey: (screen && screen.name) ? screen.name : ""
            readonly property bool screenReal: !!(screenKey && screenKey !== "FALLBACK")

            onScreenRealChanged: {
                if (screen && screen.x === 0)
                    lockContext.noteMainReal(screenReal)
                if (!screenReal)
                    return
                console.log("[Lock] Surface left FALLBACK:", screenKey, "x=" + screen.x)
                if (persist.lastWakeUnix > 0)
                    Qt.callLater(lockSurface.refreshLocal)
            }

            function refreshLocal() {
                if (uiLoader.item && uiLoader.item.refreshAfterWake)
                    uiLoader.item.refreshAfterWake()
            }

            function handleWakeFile() {
                let ts = parseInt(String(wakeFile.text()).trim(), 10)
                if (!ts)
                    return
                if (!lockSurface.wakeFilePrimed) {
                    lockSurface.wakeFilePrimed = true
                    lockSurface.appliedWakeUnix = ts
                    if (ts > lockContext.sessionStartUnix)
                        lockContext.handleHardwareWake(ts)
                    return
                }
                if (ts <= lockSurface.appliedWakeUnix)
                    return
                lockSurface.appliedWakeUnix = ts
                lockContext.handleHardwareWake(ts)
            }

            FileView {
                id: wakeFile
                path: "/var/tmp/qs-wake"
                watchChanges: true
                onLoaded: lockSurface.handleWakeFile()
                onTextChanged: lockSurface.handleWakeFile()
            }

            Timer {
                interval: 2000
                running: true
                repeat: true
                onTriggered: wakeFile.reload()
            }

            Rectangle {
                anchors.fill: parent
                color: "black"
            }

            Component {
                id: lockUIComponent
                LockScreen {
                    context: lockContext
                    targetScreen: lockSurface.screen
                }
            }

            Loader {
                id: uiLoader
                anchors.fill: parent
                active: true
                sourceComponent: lockUIComponent
            }

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                visible: lockContext.screensBlanked
                z: 1000

                onVisibleChanged: if (visible) forceActiveFocus()

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.BlankCursor
                    onPressed: lockContext.poke()
                    onPositionChanged: lockContext.pokeIfArmed()
                }

                Keys.onPressed: (event) => {
                    lockContext.poke()
                    event.accepted = true
                }
            }
        }
    }

    Connections {
        target: lockContext
        function onUnlocked() {
            lock.locked = false
            Qt.quit()
        }
    }
}
