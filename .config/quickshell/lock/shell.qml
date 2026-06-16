import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Io

import "." as Lock

ShellRoot {
    id: root

    Scope {
        id: lockContext

        property string currentText: ""
        property bool unlockInProgress: false
        property bool showFailure: false
        
        signal unlocked()

        onCurrentTextChanged: showFailure = false

        function tryUnlock() {
            if (currentText.trim() === "") return
            unlockInProgress = true
            pam.start()
        }
        
        PamContext {
            id: pam

            // Explicitly use the system quickshell PAM service we created
            configDirectory: "/etc/pam.d"
            config: "quickshell"

            onPamMessage: (message, responseRequired, echo) => {
                console.log("[PAM] Message:", message, "responseRequired:", this.responseRequired)
                if (this.responseRequired) {
                    pam.respond(lockContext.currentText)
                }
            }

            onCompleted: result => {
                console.log("[PAM] Completed with result:", result)
                if (result === PamResult.Success) {
                    lockContext.unlocked()
                } else {
                    console.log("[PAM] Genuine authentication failure.")
                    lockContext.currentText = ""
                    lockContext.showFailure = true
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
            
            property bool isArmed: true
            
            Timer {
                interval: 2000
                running: true
                repeat: false
                onTriggered: lockSurface.isArmed = true
            }

            // Listen for the wake signal from hypridle
            FileView {
                path: "/var/tmp/qs-wake"
                watchChanges: true
                onTextChanged: {
                    if (!lockSurface.isArmed) return;

                    console.log("[Quickshell] Hardware wake detected, forcing VRAM refresh...")
                    uiLoader.active = false
                    refreshTimer.restart()
                }
            }

            // Wait 50ms for Wayland to clear, then rebuild the UI
            Timer {
                id: refreshTimer
                interval: 50
                repeat: false
                onTriggered: uiLoader.active = true
            }
            
            Rectangle {
                anchors.fill: parent
                color: "black"
            }

            Component {
                id: lockUIComponent
                Lock.LockScreen {
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
