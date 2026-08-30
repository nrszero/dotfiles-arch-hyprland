import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Io
import "./modules"

ShellRoot {
    id: root

    Scope {
        id: lockContext
        
        property string currentText: ""
        property bool unlockInProgress: false
        property bool showFailure: false
        property bool maxTries: false
        property bool screensBlanked: false
        property bool blankInputArmed: false

        signal unlocked()

        function poke() {
            screensBlanked = false
            blankInputArmed = false
            blankTimer.restart()
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
            poke()
        }

        function tryUnlock() {
            if (currentText.trim() === "") return
            unlockInProgress = true
            maxTries = false
            pam.start()
        }
        
        PamContext {
            id: pam
            configDirectory: "/etc/pam.d"
            config: "quickshell"

            onPamMessage: {
                console.log("[PAM] Message:", pam.message, "responseRequired:", pam.responseRequired)
                
                // Intercept the pam_faillock text warning to flag the lockout
                if (pam.message && pam.message.includes("locked")) {
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
                } else if (result === PamResult.Failed) {
                    lockContext.currentText = ""
                    
                    // Only show standard failure if the account hasn't been flagged as locked
                    if (!lockContext.maxTries) {
                        lockContext.showFailure = true
                    }
                    
                    lockContext.unlockInProgress = false
                }
            }
        }
    }
    
    WlSessionLock {
        id: lock
        locked: true

        WlSessionLockSurface {
            id: lockSurface

            property bool wakeArmed: false

            Timer {
                interval: 3000
                running: true
                repeat: false
                onTriggered: lockSurface.wakeArmed = true
            }

            FileView {
                path: "/var/tmp/qs-wake"
                watchChanges: true
                onTextChanged: {
                    if (!lockSurface.wakeArmed)
                        return
                    if (uiLoader.item && uiLoader.item.refreshAfterWake)
                        uiLoader.item.refreshAfterWake()
                }
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
