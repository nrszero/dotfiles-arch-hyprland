import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Io
import "./modules"
import "./"

ShellRoot {
    id: root

    Scope {
        id: lockContext
        
        property string currentText: ""
        property bool unlockInProgress: false
        property bool showFailure: false
        property bool maxTries: false
        
        signal unlocked()
        
        onCurrentTextChanged: {
            showFailure = false
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

            // Wait 1000ms for Wayland to clear, then rebuild the UI.
            // 300ms was too fast for waking up from deep sleep
            Timer {
                id: refreshTimer
                interval: 1000
                repeat: false
                onTriggered: {
                    // Defensively check if the Wayland screen actually exists yet
                    if (lockSurface.screen && lockSurface.screen.name !== "") {
                        console.log("[Quickshell] Screen is valid (" + lockSurface.screen.name + "), rebuilding UI.")
                        uiLoader.active = true
                    } else {
                        console.log("[Quickshell] Screen not ready yet, delaying VRAM refresh...")
                        // If the screen isn't ready, loop the timer until it is
                        refreshTimer.start() 
                    }
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
