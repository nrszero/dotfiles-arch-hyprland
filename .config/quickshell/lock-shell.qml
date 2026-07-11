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

            // Wait 300ms for Wayland to clear, then rebuild the UI
            Timer {
                id: refreshTimer
                interval: 300
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
