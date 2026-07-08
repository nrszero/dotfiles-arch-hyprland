import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Hyprland

PanelWindow {
    id: root
    required property var screenModel
    required property var notifModel
    required property var theme

    screen: root.screenModel

    anchors { top: true; right: true; }
    margins.top: 37
    implicitWidth: 400
    implicitHeight: Math.min(root.screenModel ? root.screenModel.height : 1080, notifCol.implicitHeight + 20)

    visible: (root.notifModel.count > 0) && 
             (Hyprland.focusedMonitor.name === root.screenModel.name)
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore 

    Flickable {
        id: scrollArea
        anchors.fill: parent
        anchors.margins: 10
        contentHeight: notifCol.implicitHeight
        interactive: contentHeight > height
        clip: true // Ensure text doesn't flow outside the window bounds

        ColumnLayout {
            id: notifCol
            width: parent.width
            spacing: 10
            clip: true
            
            Repeater {
                model: root.notifModel

                delegate: Rectangle {
                    id: delegateRect

                    Layout.fillWidth: true
                    visible: model.popupVisible
                    Layout.preferredHeight: model.popupVisible ? (contentCol.implicitHeight + 20) : 0
                    Behavior on Layout.preferredHeight {NumberAnimation {duration: 200}}
                    
                    color: theme.background
                    radius: theme.radius

                    enabled: model.popupVisible

                    ColumnLayout {
                        id: contentCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        visible: delegateRect.height > 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            
                            // Icon
                            Image {
                                id: notifIcon
                                visible: model.icon !== ""
                                Layout.leftMargin: 5
                                source: model.icon.toString().startsWith("/") ? "file://" + model.icon : model.icon
                                Layout.preferredWidth: 32; Layout.preferredHeight: 32
                                fillMode: Image.PreserveAspectFit                                
                                cache: true // DO NOT CHANGE!
                                asynchronous: true

                                // Optional: Add a fallback text if the image fails to load
                                Text {
                                    anchors.centerIn: parent 
                                    text: "🛈"
                                    color: theme.urgent
                                    visible: parent.status === Image.Error || parent.status === Image.Null
                                } 
                            }

                            // Title
                            Text {
                                text: model.summary 
                                font.bold: true
                                font.pixelSize: 14
                                color: theme.text
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            // Close Button
                            Button {
                                background: Rectangle { 
                                    color: "transparent"
                                    
                                    MouseArea {
                                        id: dismissMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                    }
                                }

                                contentItem: Text { text: "✕"; color: theme.urgent; font.bold: true }
                                // Remove from the shared list by index
                                onClicked: {
                                    shellRoot.dismissNotification(index)
                                    //root.notifModel.remove(index)

                                }                                
                            }
                        }

                        // Body
                        Text {
                            text: model.body 
                            color: theme.text
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            maximumLineCount: 3
                            visible: text !== ""
                        }
                    }

                    // 10 Seconds to hide popup
                    Timer {
                        interval: 10000
                        running: true
                        onTriggered: model.popupVisible = false
                    }
                }
            }
        }
    }    
}
