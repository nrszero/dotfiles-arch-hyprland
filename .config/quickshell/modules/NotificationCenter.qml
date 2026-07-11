import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Wayland
import Quickshell.Hyprland

PopupWindow {
    id: root

    required property var notifModel
    required property var theme
    required property var dismissNotification   // function(index) provided by shell

    anchor.edges: Edges.Bottom
    anchor.margins.top: 6

    implicitWidth: 400
    implicitHeight: Math.min(400, contentColumn.implicitHeight + 40) 
    visible: false
    color: "transparent"

    HoverHandler { id: popupHover }

    Timer {
        id: hideTimer
        interval: 3000
        repeat: false
        onTriggered: {
            console.log("[NotifCenter] hideTimer triggered → hiding popup")
            root.visible = false
        }
    }

    function updateHover() {
        if (!popupHover) {
            console.log("[NotifCenter] updateHover ERROR: popupHover is ", iconHover)
            return
        }
        
        console.log("[NotifCenter] updateHover called | popup hovered:", popupHover.hovered)

        if (popupHover.hovered) {
            hideTimer.stop()
            console.log("[NotifCenter] → Timer stopped (still hovered)")
        } else {
            hideTimer.restart()
            console.log("[NotifCenter] → Timer restarted (mouse left area)")
        }
    }

    Connections {
        target: popupHover
        function onHoveredChanged() { 
            console.log("[NotifCenter] popupHover hovered changed →", popupHover.hovered)
            updateHover() 
        }
    }
    
    onVisibleChanged: {
        if (visible) {
            hideTimer.stop()
            Qt.callLater(updateHover)
        }
    }

    Rectangle {
        id: background
        anchors.fill: parent
        anchors.margins: 6
        color: theme.background
        radius: theme.radius
        border.width: theme.borderWidth
        border.color: theme.borderColor

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // Header
            RowLayout {
                Layout.fillWidth: true
                
                // Accent Pill
                Rectangle {
                    width: 4
                    Layout.preferredHeight: 18 // Roughly matches the text height
                    radius: 2
                    color: theme.accent 
                }

                Text {
                    text: "Notifications"
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                // Count
                Text {
                    visible: notifModel && notifModel.count > 0
                    text: notifModel ? notifModel.count + " new" : ""
                    color: theme.subText
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeSm
                }

                // Clear All Button
                Button {
                    visible: notifModel && notifModel.count > 0
                    background: null
                    contentItem: Text {
                        id: clearIcon
                        text: ""
                        color: theme.subText
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeMd
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onEntered: clearIcon.color = theme.urgent
                        onExited: clearIcon.color = theme.subText

                        onClicked: {
                            if (!notifModel) return
                            // Clear from the end to avoid index shifting
                            for (var i = notifModel.count - 1; i >= 0; i--) {
                                dismissNotification(i)
                            }
                            root.visible = false
                        }
                    }
                }
            }

            // Empty state
            Text {
                visible: !notifModel || notifModel.count === 0
                text: "No new notifications"
                color: theme.subText
                font.italic: true
                font.family: theme.fontFace
                font.pixelSize: theme.fontSizeSm
                Layout.alignment: Qt.AlignHCenter
            }

            // Notification List
            ListView {
                id: notifList
                visible: root.notifModel && root.notifModel.count > 0
                Layout.fillWidth: true
                //Layout.fillHeight: true
                Layout.preferredHeight: Math.min(340, contentHeight)
                Layout.maximumHeight: 340
                clip: true
                spacing: 8
                model: root.notifModel

                delegate: Rectangle {
                    id: delegateRect
                    width: notifList.width
                    height: 78
                    color: theme.surface
                    radius: theme.radius - 2
                    border.width: 1
                    border.color: Qt.rgba(1,1,1, 0.05)

                    ColumnLayout {
                        id: contentCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // Icon
                            Image {
                                id: notifIcon
                                visible: model.icon !== ""
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                source: model.icon.toString().startsWith("/") 
                                    ? "file://" + model.icon 
                                    : model.icon
                                fillMode: Image.PreserveAspectFit
                                cache: true
                                asynchronous: true

                                Text {
                                    anchors.centerIn: parent
                                    text: "🛈"
                                    color: theme.urgent
                                    visible: parent.status === Image.Error || parent.status === Image.Null
                                }
                            }

                            // Summary + Time
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: model.summary || "Notification"
                                        font.bold: true
                                        font.pixelSize: theme.fontSizeMd
                                        color: theme.text
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: model.time || ""
                                        font.pixelSize: theme.fontSizeSm
                                        color: theme.subText
                                    }
                                }
                            }

                            // Dismiss X
                            Text {
                                text: "✕"
                                color: theme.urgent
                                font.pixelSize: 14
                                font.bold: true

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: dismissNotification(index)
                                }
                            }
                        }

                        // Body
                        Text {
                            text: model.body || ""
                            color: theme.subText
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                            font.pixelSize: theme.fontSizeSm
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            visible: text !== ""
                        }
                    }
                }
            }
        }
    }
}
