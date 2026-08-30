import Quickshell
import QtQuick
import QtQuick.Layouts
import QtCore
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Hyprland
import "NotifPaths.js" as NotifPaths

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

    // Only show on the focused monitor, but guard against temporary FALLBACK / null states
    readonly property bool isOnFocusedMonitor: {
        const fm = Hyprland.focusedMonitor;
        return !!(fm && fm.name && root.screenModel && fm.name === root.screenModel.name);
    }
    visible: (root.notifModel.count > 0) && root.isOnFocusedMonitor
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore 

    Flickable {
        id: scrollArea
        anchors.fill: parent
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        anchors.leftMargin: 18
        anchors.rightMargin: 18
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
                    Layout.preferredHeight: model.popupVisible ? 78 : 0
                    Behavior on Layout.preferredHeight {NumberAnimation {duration: 200}}

                    color: theme.surface
                    radius: theme.radius - 2
                    border.width: 1
                    border.color: Qt.rgba(1,1,1, 0.05)
                    enabled: model.popupVisible

                    ColumnLayout {
                        id: contentCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4
                        visible: delegateRect.height > 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Image {
                                id: notifIcon
                                visible: model.icon !== ""
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                source: model.icon.toString().startsWith("/") ? "file://" + model.icon : model.icon
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

                            Text {
                                text: "✕"
                                color: theme.urgent
                                font.pixelSize: 14
                                font.bold: true

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: shellRoot.dismissNotification(index)
                                }
                            }
                        }

                        Text {
                            text: NotifPaths.linkify(model.body, StandardPaths.writableLocation(StandardPaths.HomeLocation))
                            textFormat: Text.RichText
                            color: theme.subText
                            linkColor: theme.accent
                            wrapMode: Text.WrapAnywhere
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            clip: true
                            font.pixelSize: theme.fontSizeSm
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            visible: model.body !== ""
                            onLinkActivated: (link) => {
                                const path = NotifPaths.resolve(link, StandardPaths.writableLocation(StandardPaths.HomeLocation))
                                if (path)
                                    Quickshell.execDetached(["kitty", "yazi", path])
                            }

                            HoverHandler {
                                enabled: parent.hoveredLink !== ""
                                cursorShape: Qt.PointingHandCursor
                            }
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
