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
    screen: screenModel
    required property var screenModel
    required property var theme
    required property var notifModel
    required property var dismissNotification   // function(index) from shell
    required property bool barVisible

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: barVisible ? height : 0
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.keyboardFocus: KeyboardFocus.OnDemand

    mask: Region {
        regions: [
            Region { item: mainLayout }
        ]
    }

    property var hMonitor: {
        if (!Hyprland.monitors || !Hyprland.monitors.values || !root.screenModel) return null;
        for (let m of Hyprland.monitors.values) {
            if (m.name === root.screenModel.name) {
                return m;
            }    
        }
        return null;
    }
    
    property int totalWorkspaces: 6

    Component.onCompleted: {
        Hyprland.refreshWorkspaces()
        updateTotalWorkspaces()
    }

    function updateTotalWorkspaces() {
        if (!Hyprland.workspaces || !Hyprland.workspaces.values) {
            totalWorkspaces = 6
            return
        }
        let maxId = 0
        for (let ws of Hyprland.workspaces.values) {
            if (ws && ws.id > 0 && ws.id > maxId) maxId = ws.id
        }
        totalWorkspaces = maxId > 0 ? maxId : 6
    }
    
    Timer {
        id: reloadTimer
        interval: 250
        repeat: false
        onTriggered: {
            Hyprland.refreshWorkspaces()
            updateTotalWorkspaces()
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "workspace" || event.name === "createworkspace" ||
                event.name === "destroyworkspace" || event.name === "focusedmon") {
                Hyprland.refreshWorkspaces()
                updateTotalWorkspaces()
            } else if (event.name === "configreloaded") {
                reloadTimer.restart()
            }
        }
    }
    
    property int monitorIndex: hMonitor ? hMonitor.id : 0
    property int baseWs: monitorIndex

    anchors {top: true; left: true; right: true; }
    height: 50
    visible: barVisible
    color: "transparent"
     
    component BarModule: Rectangle {
        color: theme.background
        radius: theme.radius
        border.width: theme.borderWidth
        border.color: theme.borderColor
        height: 36
        Layout.alignment: Qt.AlignVCenter
    }

    BatteryProc { id: battery }

    RowLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 10
        spacing: theme.spacing
        
        // LEFT SIDE
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft
            spacing: 8

            // Time Pill
            BarModule {
                implicitWidth: timeText.implicitWidth + 20

                Text {
                    id: timeText
                    anchors.centerIn: parent
                    text: Qt.formatTime(new Date(), "HH:mm")
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                    font.bold: true
                }

                // Update the clock every second so minutes change on time
                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: timeText.text = Qt.formatTime(new Date(), "HH:mm")
                }
            }

            // Now Playing Pill (separate component)
            NowPlayingPill {
                theme: root.theme
            }
        }
        
        Item { Layout.fillWidth: true }

        // CENTER
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.leftMargin: -145
            spacing: 8

            BarModule {
                id: workspaceGroup
                implicitWidth: workspaceRow.implicitWidth + 20

                Row {
                    id: workspaceRow
                    anchors.centerIn: parent
                    spacing: 6
                    
                    Repeater {
                        model: root.totalWorkspaces
                        delegate: Rectangle {
                            width: isActive ? 28 : 22
                            height: 22
                            radius: theme.radius
     
                            property int wsId: index + 1
                            property bool isActive: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId
                            property bool hasWindows: {
                                if (!Hyprland.toplevels.values) return false
                                for (let t of Hyprland.toplevels.values) {
                                    if (t.workspace && t.workspace.id === wsId) return true
                                }
                                return false
                            }

                            color: isActive ? theme.accent : (hasWindows ? theme.surface : "transparent")
                            border.width: (isActive || hasWindows) ? 0 : 1
                            border.color: Qt.rgba(1,1,1, 0.1)
                            
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
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Hyprland.dispatch(`hl.dsp.focus({workspace = ${index + 1}})`)
                            }
                        }
                    }
                }
            }
            
            Loader {
                id: trayLoader
                active: root.visible
                sourceComponent: BarModule {
                    visible: trayRepeater.count > 0
                    implicitWidth: systemTrayRow.implicitWidth + 20
                    Row {
                        id: systemTrayRow
                        anchors.centerIn: parent
                        spacing: 8
                        Repeater {
                            id: trayRepeater
                            model: SystemTray.items
                            delegate: Rectangle {
                                width: 22; height: 22; color: "transparent"; radius: theme.radius
                                QsMenuAnchor { id: menuAnchor; anchor.item: sysTrayIcon }
                                Image {
                                    id: sysTrayIcon
                                    visible: modelData.icon !== ""
                                    anchors.centerIn: parent; width: 18; height: 18
                                    source: modelData.icon; fillMode: Image.PreserveAspectFit
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.LeftButton) modelData.activate()
                                        else if (modelData.hasMenu) { menuAnchor.menu = modelData.menu; menuAnchor.open() }
                                        else modelData.secondaryActivate()
                                    }
                                }
                            }
                        }
                    }
                }
            }

        }
        
        Item { Layout.fillWidth: true }

        // RIGHT SIDE
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            spacing: 8
            
            BarModule {
                implicitWidth: statusRow.implicitWidth + 16
                
                RowLayout {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 8
                    
                    // Battery
                    RowLayout {
                        visible: battery.battPresent
                        spacing: 3
                        Text {
                            text: {
                                if (battery.battCharging) return "󰂄";
                                if (battery.battLevel > 0.9) return "󰁹";
                                if (battery.battLevel > 0.8) return "󰂂";
                                if (battery.battLevel > 0.7) return "󰂁";
                                if (battery.battLevel > 0.6) return "󰂀";
                                if (battery.battLevel > 0.5) return "󰁿";
                                if (battery.battLevel > 0.4) return "󰁾";
                                if (battery.battLevel > 0.3) return "󰁽";
                                if (battery.battLevel > 0.2) return "󰁼";
                                return "󰁺";
                            }
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeLg
                            color: theme.text
                        }
                        Text {
                            text: Math.round(battery.battLevel * 100) + "%"
                            color: theme.subText
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
                            font.bold: true
                        }
                    }
                    
                    // Volume Icon
                    Text {
                        id: volumeIcon
                        text: (Pipewire.defaultAudioSink?.audio.muted) ? "" : ""
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeXl
                        color: theme.text

                        HoverHandler { id: volumeIconHover }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                networkPopup.visible = false
                                bluetoothPopup.visible = false
                                notifCenter.visible = false
                                powerButtonPopup.visible = false
                                volumePopup.visible = !volumePopup.visible
                            }
                        }
                    }

                    // Network
                    Text {
                        id: networkIcon
                        text: "󰈀"
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeXl
                        color: theme.accent

                        HoverHandler { id: networkIconHover }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                bluetoothPopup.visible = false
                                notifCenter.visible = false
                                volumePopup.visible = false
                                powerButtonPopup.visible = false
                                networkPopup.visible = !networkPopup.visible
                            }
                        }
                    }

                    // Bluetooth
                    Text {
                        id: bluetoothIcon
                        text: "󰂯"
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeXl
                        color: Bluetooth.devices.values.some(d => d.connected) ? theme.accent : theme.subText
                        
                        HoverHandler { id: bluetoothIconHover }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                networkPopup.visible = false
                                notifCenter.visible = false
                                powerButtonPopup.visible = false
                                volumePopup.visible = false
                                bluetoothPopup.visible = !bluetoothPopup.visible
                            }
                        }
                    }

                    // Notifications Bell + Badge
                    Item {
                        id: notifBellContainer
                        width: 26; height: 26
                        
                        HoverHandler { id: notifIconHover }

                        Text {
                            id: notifBellIcon
                            anchors.centerIn: parent
                            text: "󰂚"
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeXl
                            color: theme.text
                        }

                        Rectangle {
                            visible: notifModel && notifModel.count > 0
                            anchors.top: parent.top; anchors.right: parent.right
                            width: 15; height: 15; radius: 7.5
                            color: theme.urgent
                            Text {
                                anchors.centerIn: parent
                                text: notifModel ? notifModel.count : ""
                                color: theme.text
                                font.family: theme.fontFace
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                networkPopup.visible = false
                                bluetoothPopup.visible = false
                                volumePopup.visible = false
                                powerButtonPopup.visible = false
                                notifCenter.visible = !notifCenter.visible
                            }
                        }
                    }

                    // Power
                    Text {
                        id: powerIcon
                        text: "󰐥"
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeXl
                        color: theme.text
                        HoverHandler { id: powerIconHover }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                networkPopup.visible = false
                                bluetoothPopup.visible = false
                                notifCenter.visible = false
                                volumePopup.visible = false
                                powerButtonPopup.visible = !powerButtonPopup.visible
                            }
                        }
                    }
                }
            }
        }

    }

    // === DROPDOWNS ===

    NetworkPopup {
        id: networkPopup
        anchor.item: networkIcon
        theme: root.theme
    }

    BluetoothPopup {
        id: bluetoothPopup
        anchor.item: bluetoothIcon
        theme: root.theme
    }
    
    VolumePopup {
        id: volumePopup
        anchor.item: volumeIcon
        theme: root.theme
    }
    
    PowerButtonPopup {
        id: powerButtonPopup
        anchor.item: powerIcon
        theme: root.theme
    }
  
    NotificationCenter {
        id: notifCenter
        anchor.item: notifBellIcon
        notifModel: root.notifModel
        theme: root.theme
        dismissNotification: root.dismissNotification
    }
}
