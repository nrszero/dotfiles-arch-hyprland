//@ pragma UseQApplication
import Quickshell
import QtQuick
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Hyprland
import "./modules"
import "./"

Scope {
    id: shellRoot

    // Initialize the Theme globally for this scope
    Theme { id: appTheme }

    //-----NOTIFICATIONS-----
    property var activeNotifications: [] // Saves notification to RAM so it doesn't garbage collect
    
    ListModel {
        id: sharedNotifList
    }

    property var dismissNotification: function(index) {
        if (index >= 0 && index < sharedNotifList.count) {
            activeNotifications.splice(index, 1) // Remove from memory
            sharedNotifList.remove(index)        // Remove from UI
        }
    }

    NotificationServer {
        id: notifServer
        bodySupported: true
        bodyHyperlinksSupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        
        // Force the server to listen (crucial for v0.2.1)
        //inhibited: false 

        onNotification: (n) => {
            activeNotifications.push(n)

            console.log("Captured summary:", n.summary + " Captured image:", n.image + " Captured body:", n.body )

            // Manually save the data so it persists
            sharedNotifList.append({
                "summary": n.summary,
                "body": n.body,
                "icon": n.image || "", // Handle empty icons.
                "time": new Date().toLocaleTimeString(),
                "popupVisible": true,
                "refIndex": activeNotifications.length - 1 // Track where it is in the array
            })
        }
    }

    //-----END NOTIFICATIONS-----
    
    // Persistent user-controlled bar visibility (toggled with SUPER + Tab)
    property bool persistentBarsVisible: true

    // Temporary "peek" visibility (auto-triggered on workspace changes)
    property bool temporaryBarVisible: false
    
    // Effective visibility used by all Bar instances
    readonly property bool barsVisible: persistentBarsVisible || temporaryBarVisible
    
    property int activeInteractions: 0

    onActiveInteractionsChanged: {
        if (activeInteractions > 0) {
            barPeekTimer.stop()
            if (!persistentBarsVisible) {
                temporaryBarVisible = true // Ensure it stays open while interacting
            }
        } else {
            // No longer interacting, start the fade-out timer
            if (!persistentBarsVisible && temporaryBarVisible) {
                barPeekTimer.restart()
            }
        }
    }

    function registerInteraction() {
        activeInteractions++
    }

    function unregisterInteraction() {
        activeInteractions = Math.max(0, activeInteractions - 1)
    }

    // 3-second auto-hide timer for temporary peeks
    Timer {
        id: barPeekTimer
        interval: 3000
        repeat: false
        onTriggered: temporaryBarVisible = false
    }

    // Show bar temporarily for 3 seconds (does nothing if persistent bar is enabled)
    function peekBarTemporarily() {
        if (persistentBarsVisible) return
        temporaryBarVisible = true
        if (activeInteractions === 0) { 
            barPeekTimer.restart()
        }
    }

    GlobalShortcut {
        name: "toggleBar"
        onPressedChanged: {
            if (pressed) {
                persistentBarsVisible = !persistentBarsVisible
                if (persistentBarsVisible) {
                    temporaryBarVisible = false
                    barPeekTimer.stop()
                } else {
                    // If toggled off but the user is currently hovering, keep it temporarily open
                    if (activeInteractions > 0) {
                        temporaryBarVisible = true
                    } else {
                        temporaryBarVisible = false
                    }
                }
            }
        }
    }
    
    // Automatically peek the bar briefly whenever workspace changes
    // (this covers SUPER+1..6, SUPER+arrows, clicking workspaces, etc.)
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "workspace" ||
            event.name === "createworkspace" || event.name === "destroyworkspace") {
                peekBarTemporarily()
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {

            Item {
                id: wrapper
                required property var modelData

                // Guard against placeholder / FALLBACK / empty screens that appear dpms
                readonly property bool isRealScreen: !!(modelData && modelData.name && modelData.name !== "FALLBACK")

                Loader {
                    active: wrapper.isRealScreen
                    sourceComponent: Item {
                        NotificationPopup {
                            screenModel: wrapper.modelData
                            notifModel: sharedNotifList
                            theme: appTheme
                        }

                        Bar {
                            screenModel: wrapper.modelData
                            theme: appTheme
                            notifModel: sharedNotifList
                            dismissNotification: shellRoot.dismissNotification
                            barVisible: shellRoot.barsVisible
                            
                            onInteractionStarted: shellRoot.registerInteraction()
                            onInteractionEnded: shellRoot.unregisterInteraction()

                            // Failsafe: Unregister if a monitor disconnects while hovered
                            Component.onDestruction: {
                                shellRoot.unregisterInteraction()
                            }
                        }
                    }
                }
            }
        }
    }
}
