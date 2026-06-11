import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam

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
            Lock.LockScreen {
                anchors.fill: parent
                context: lockContext
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
