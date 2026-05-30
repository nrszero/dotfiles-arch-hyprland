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

    function dismissNotification(index) {
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
    
    Variants {
        model: Quickshell.screens
        delegate: Component {

            Item {
                id: wrapper
                required property var modelData

                NotificationPopup {
                    screenModel: wrapper.modelData
                    notifModel: sharedNotifList
                    theme: appTheme
                }

                ControlPanel {
                    screenModel: wrapper.modelData
                    notifModel: sharedNotifList
                    theme: appTheme
                }
                
                Bar {
                    screenModel: wrapper.modelData
                    theme: appTheme
                }
            }
        }
    }
}
