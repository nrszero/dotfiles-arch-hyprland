//@ pragma UseQApplication
import Quickshell
import QtQuick
import QtQuick 2.0
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

PanelWindow {
    id: root
    required property var screenModel
    required property var theme

    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrLayershell.KeyboardFocus.OnDemand 

    mask: Region {
        // By default, regions combine (Union), so this creates a mask that covers BOTH the workspaces AND the tray.
        regions: [
            // 1. The Workspace Box
            Region { item: workspaceGroup },
            Region { item: trayLoader.item }
        ]
    }

    property var hMonitor: {
        if (!Hyprland.monitors || !Hyprland.monitors.values) return null;
        for (let m of Hyprland.monitors.values) {
            if (m.name === root.screenModel.name) {
                console.log(`[Bar] Matched Monitor: ${m.name} with ID: ${m.id}`);
                return m;
            }    
        }
        console.log(`[Bar] WARNING: No matching Hyprland monitor found for ${root.screenModel.name}`);
        return null;
    }
    
    GlobalShortcut {
        name: "toggleBar" // This name identifies the action
        onPressedChanged: {
            console.log("Focused Monitor: ", Hyprland.focusedMonitor.name + " Screen Model: ", root.screenModel.name)

            if (pressed) {
                if (Hyprland.focusedMonitor.name === root.screenModel.name) {
                    root.visible = true
                    console.log("[Bar] Toggled Visible. Monitor Index:", monitorIndex, "BaseWs:", baseWs)
                }
                else {
                    root.visible = false
                }
            }
        }
    }
    
    // === DYNAMIC WORKSPACES (fully reactive - matches WORKSPACES variable) ===
    Component.onCompleted: {
        Hyprland.refreshWorkspaces()
        console.log("[Bar] Initial refreshWorkspaces() called - total workspaces:", 
                    Hyprland.workspaces.values ? Hyprland.workspaces.values.length : 0)
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.event === "workspace" ||
                event.event === "createworkspace" ||
                event.event === "destroyworkspace" ||
                event.event === "focusedmon") {
                Hyprland.refreshWorkspaces()
                console.log("[Bar] Raw event triggered refresh:", event.event)
            }
        }
    }

    property int monitorIndex: hMonitor ? hMonitor.id : 0
    // property int baseWs: monitorIndex * 10
    property int baseWs: monitorIndex

    anchors {top: true; left: true; right: true; }
    height: 50
    visible: false
    color: "transparent"
     
    HoverHandler {
        id: panelHover
        onPointChanged: {
            if (root.visible) hideTimer.restart()
        }
    }
    
    Timer {
        id: hideTimer
        interval: 5000    
        running: root.visible
        repeat: false
        onTriggered: {
            if (panelHover.hovered) {
                console.log("[Bar] Mouse detected, extending timer...")
                hideTimer.restart()
            } 
            else {
                console.log("[Bar] Timeout reached, hiding panel.")
                root.visible = false
            } 
        }
    }

    // --- REUSABLE COMPONENT: "Module Background" ---
    component BarModule: Rectangle {
        color: theme.background
        radius: theme.radius
        border.width: theme.borderWidth
        border.color: theme.borderColor
        height: 36 // Fixed height for all modules
        Layout.alignment: Qt.AlignVCenter
    }

    // --- MAIN BAR ---
    RowLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 10
        spacing: theme.spacing

        Item { Layout.fillWidth: true }                
        
        // --- WORKSPACE BORDERED BOX ---
        BarModule {
            id: workspaceGroup
            implicitWidth: workspaceRow.implicitWidth + 20

            Row {
                id: workspaceRow
                anchors.centerIn: parent
                spacing: 6
                
                // --- STANDARD WORKSPACES ---
                Repeater {
                    model: Hyprland.workspaces
                    delegate: Rectangle {
                        width: isActive ? 28 : 22
                        height: 22
                        radius: theme.radius
 
                        property int wsId: index + 1
                        // property int wsId: index + 1 + root.baseWs
                        
                        property bool isActive: {
                            if (!Hyprland.focusedWorkspace) return false;
                            if (Hyprland.focusedWorkspace.id === wsId) {
                                return true;
                            }
                            return false;
                        }
                        property bool hasWindows: {
                            if (!Hyprland.toplevels.values) return false;
                            let found = false;
                            
                            for (let toplevel of Hyprland.toplevels.values) {
                                if (toplevel.workspace && toplevel.workspace.id === wsId) {
                                    found = true;
                                    break;
                                }
                            }
                            return found;
                        }		

                        color: isActive ? theme.accent : (hasWindows ? theme.surface : "transparent")
                        border.width: isActive || hasWindows ? 0 : 1
                        border.color: isActive || hasWindows ? "transparent" : Qt.rgba(1,1,1, 0.1)
                        
                        Behavior on width { NumberAnimation { duration: 200 } }
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Text {
                            anchors.centerIn: parent
                            color: isActive ? theme.text : theme.subText
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
                            font.bold: isActive
                            text: index + 1
                            visible: isActive || hasWindows
                        }
                    
                        MouseArea {
                            id: wsMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                console.log(`[Click] Dispatching workspace ${parent.wsId}`);
                                Hyprland.dispatch("split-workspace " + (index + 1).toString())
                            }
                        }
                    }
                }
            }
        }
        
        Loader {
            id: trayLoader
            active: root.visible
            Layout.alignment: Qt.AlignCenter

            sourceComponent: BarModule {
                id: systemTrayGroup
                visible: trayRepeater.count > 0
                implicitWidth: systemTrayRow.implicitWidth + 20

                // This is the container for your tray icons
                Row {
                    id: systemTrayRow
                    anchors.centerIn: parent
                    spacing: 8 // Space between icons
                    
                    // The Repeater creates an item for every app in the tray
                    Repeater {
                        // SystemTray.items is the list of active tray apps
                        id: trayRepeater
                        model: SystemTray.items

                        delegate: Rectangle {
                            width: 22
                            height: 22
                            color: "transparent" // Background color
                            radius: theme.radius
                            
                            QsMenuAnchor {
                                id: menuAnchor
                                anchor.item: sysTrayIcon
                            }

                            // The icon image:
                            Image {
                                id: sysTrayIcon
                                visible: modelData.icon !== ""
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                source: modelData.icon
                                fillMode: Image.PreserveAspectFit
                            }
                            
                            Component.onCompleted: {
                                console.log("System Tray Icon: ", modelData.icon)
                            }

                            // Handle mouse clicks
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        modelData.activate() // Left click activates the app window
                                    } else if (mouse.button === Qt.RightButton) {
                                        if (modelData.hasMenu) {
                                            menuAnchor.menu = modelData.menu
                                            menuAnchor.open() // Ask Quickshell to render the popup
                                        } else {
                                            // Fallback for apps that use right-click for "secondary activation" instead of a menu
                                            modelData.secondaryActivate()
                                        }    
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }
    }
}
     


