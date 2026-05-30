import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root
    
    // We need the screen info to show up on the correct monitor
    required property var screenModel 
    required property var theme

    screen: screenModel
    visible: false
    
    // Fullscreen Dimmer
    anchors {top: true; bottom: true; left: true; right: true;}
    WlrLayershell.layer: WlrLayer.Overlay
    color: "transparent" // Semi-transparent black

    // Close on click outside
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Process { id: sysCmd }

    // Centered Menu Box
    Rectangle {
        width: 400; height: 150
        anchors.centerIn: parent
        color: theme.background
        radius: theme.radius

        // Block clicks from closing the window
        MouseArea { anchors.fill: parent }

        RowLayout {
            anchors.centerIn: parent
            spacing: 20

            // Helper component for the 3 buttons
            component ActionBtn: Button {
                id: control
                Layout.preferredWidth: 100
                Layout.preferredHeight: 100
                
                background: Rectangle {
                    color: parent.hovered ? theme.accent : theme.surface
                    radius: theme.radius
                    
                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
                
                contentItem: ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 5
                    Text { 
                        text: control.text.split("|")[0]; font.pixelSize: 48; 
                        color: theme.text; Layout.alignment: Qt.AlignHCenter 
                    }
                    Text { 
                        text: control.text.split("|")[1]; font.pixelSize: 14; 
                        color: theme.subText; Layout.alignment: Qt.AlignHCenter 
                    }
                }
            }

            ActionBtn {
                text: "󰤄|Suspend"
                onClicked: { 
                    sysCmd.command = ["systemctl", "suspend"]; sysCmd.running = true
                    root.visible = false
                }
            }
            
            ActionBtn {
                text: "󰜉|Reboot"
                onClicked: { 
                    sysCmd.command = ["systemctl", "reboot"]; sysCmd.running = true 
                }
            }

            ActionBtn {
                text: "⏻|Shutdown"
                onClicked: { 
                    sysCmd.command = ["systemctl", "poweroff"]; sysCmd.running = true 
                }
            }
        }
    }
}
