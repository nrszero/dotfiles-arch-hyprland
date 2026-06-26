import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Wayland
import Quickshell.Io

PopupWindow {
    id: root

    required property var theme

    anchor.edges: Edges.Bottom
    anchor.margins.top: 6

    implicitWidth: 400
    implicitHeight: 500
    visible: false
    color: "transparent"

    HoverHandler { id: popupHover }

    Timer {
        id: hideTimer
        interval: 3000
        repeat: false
        onTriggered: root.visible = false
    }

    function updateHover() {
        if (!popupHover) return
        if (popupHover.hovered) {
            hideTimer.stop()
        } else {
            hideTimer.restart()
        }
    }

    Connections { 
        target: popupHover
        function onHoveredChanged() { updateHover() }
    }

    ListModel { id: bindsModel }

    // Fetch live binds directly from Hyprland
    Process {
        id: fetchBinds
        command: ["hyprctl", "binds", "-j"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                bindsModel.clear();
                try {
                    let data = JSON.parse(this.text.trim());
                    
                    for (let i = 0; i < data.length; i++) {
                        let b = data[i];
                        
                        // Skip empty keys (usually mouse binds)
                        if (b.key === "") continue; 

                        // Decode Hyprland's bitwise modmask
                        let mods = [];
                        if (b.modmask & 64) mods.push("SUPER");
                        if (b.modmask & 4) mods.push("CTRL");
                        if (b.modmask & 8) mods.push("ALT");
                        if (b.modmask & 1) mods.push("SHIFT");

                        let modStr = mods.length > 0 ? mods.join(" + ") + " + " : "";
                        let keyStr = b.key.toUpperCase();

                        let actionArg = b.arg;
                        if (actionArg.length > 40) {
                            actionArg = actionArg.substring(0, 40) + "..."; 
                        }

                        // --- THE MAGIC: Check for the Description ---
                        let hasDesc = (b.description !== undefined && b.description !== "");

                        bindsModel.append({
                            triggerText: modStr + keyStr,
                            // If a description exists, make it the main title. If not, use the dispatcher.
                            mainTitle: hasDesc ? b.description : b.dispatcher,
                        });
                    }
                } catch (e) {
                    console.error("Failed to parse hyprctl binds: " + e);
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            hideTimer.stop();
            fetchBinds.running = true; 
            Qt.callLater(updateHover);
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        color: theme.background
        radius: theme.radius
        border.width: theme.borderWidth
        border.color: theme.borderColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Header
            Text {
                text: "Shortcuts"
                color: theme.text
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeMd
                font.bold: true
                Layout.fillWidth: true
            }

            // Scrollable List
            ListView {
                id: bindsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: bindsModel
                
                ScrollBar.vertical: ScrollBar {
                    active: bindsList.moving || bindsList.flicking
                    policy: ScrollBar.AsNeeded
                }

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 44 // Slightly taller to fit the text comfortably
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        spacing: 12

                        // Left: The Keyboard Shortcut
                        Rectangle {
                            Layout.preferredHeight: 28
                            Layout.preferredWidth: shortcutText.implicitWidth + 16
                            color: theme.surface
                            radius: 4
                            border.color: theme.borderColor
                            border.width: 1
                            
                            Text {
                                id: shortcutText
                                anchors.centerIn: parent
                                text: model.triggerText
                                color: theme.accent
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeSm
                                font.bold: true
                            }
                        }

                        // Right: Description
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            
                            // Displays Description (or dispatcher if no description)
                            Text {
                                text: model.mainTitle
                                color: theme.text
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeSm
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }
}
