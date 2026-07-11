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
    
    property int totalWorkspaces: 6
    property var hMonitor: {
        if (!Hyprland.monitors || !Hyprland.monitors.values || !root.screenModel) return null;
        for (let m of Hyprland.monitors.values) {
            if (m.name === root.screenModel.name) {
                return m;
            }    
        }
        return null;
    }
    property int monitorIndex: hMonitor ? hMonitor.id : 0
    property int baseWs: monitorIndex
    property bool hasFullscreen: false
    property bool isInteractive: barHover.hovered ||
                                 networkPopup.visible ||
                                 bluetoothPopup.visible ||
                                 volumePopup.visible ||
                                 powerButtonPopup.visible ||
                                 shortcutsPopup.visible ||
                                 calendarPopup.visible ||
                                 notifCenter.visible

    signal interactionStarted()
    signal interactionEnded()
    
    onIsInteractiveChanged: {
        if (isInteractive) {
            root.interactionStarted()
        } else {
            root.interactionEnded()
        }
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: (barVisible && !hasFullscreen) ? implicitHeight : 0
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        regions: [
            Region { item: mainLayout }
        ]
    }

    HoverHandler {
        id: barHover
    }

    Component.onCompleted: {
        Hyprland.refreshWorkspaces()
        updateTotalWorkspaces()
        fsCheckTimer.restart()
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
    
    function checkFullscreen() {
        if (!hMonitor || !hMonitor.activeWorkspace) {
            hasFullscreen = false;
            return;
        }
        
        // Quickshell natively tracks this! No looping required.
        hasFullscreen = hMonitor.activeWorkspace.hasFullscreen;
    }
    
    function togglePopup(target) {
        let popups = [
            networkPopup, bluetoothPopup, volumePopup, 
            powerButtonPopup, shortcutsPopup, calendarPopup, notifCenter
        ]
        
        for (let p of popups) {
            if (p !== target) p.visible = false
        }
        target.visible = !target.visible
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
    
    Timer {
        id: fsCheckTimer
        interval: 50
        repeat: false
        onTriggered: checkFullscreen()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "workspace" || event.name === "createworkspace" ||
                event.name === "destroyworkspace" || event.name === "focusedmon") {
                Hyprland.refreshWorkspaces()
                updateTotalWorkspaces()
                fsCheckTimer.restart()
            } else if (event.name === "configreloaded") {
                reloadTimer.restart()
            } else if (event.name === "fullscreen") {
                // Whenever a window changes state, moves, or closes, update the variable
                fsCheckTimer.restart() 
            }
        }
    }

    anchors {top: true; left: true; right: true; }
    implicitHeight: 50
    visible: barVisible && !hasFullscreen
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

    Item {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 10
        
        // LEFT SIDE
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft
            spacing: theme.spacing

            // Time Pill
            BarModule {
                id: timePillBox
                implicitWidth: timeText.implicitWidth + 20

                Text {
                    id: timeText
                    anchors.centerIn: parent
                    text: Qt.formatTime(new Date(), "h:mm AP")
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                    font.bold: true
                }
                
                HoverHandler { id: timeHover }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.togglePopup(calendarPopup)
                }

                // Update the clock every second so minutes change on time
                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: timeText.text = Qt.formatTime(new Date(), "h:mm AP")
                }
            }

            // Now Playing Pill (separate component)
            NowPlayingPill {
                theme: root.theme
            }
        }
        
        // CENTER
        BarModule {
            id: workspaceGroup
            anchors.centerIn: parent
            implicitWidth: workspaceRow.implicitWidth + 20

            Row {
                id: workspaceRow
                anchors.centerIn: parent
                spacing: theme.spacing
                
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
            anchors.left: workspaceGroup.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            sourceComponent: BarModule {
                visible: trayRepeater.count > 0
                implicitWidth: systemTrayRow.implicitWidth + 20
                Row {
                    id: systemTrayRow
                    anchors.centerIn: parent
                    spacing: theme.spacing
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

        // RIGHT SIDE
        RowLayout {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: theme.spacing
            
            BarModule {
                implicitWidth: statusRow.implicitWidth + 16
                
                RowLayout {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: theme.spacing
                    
                    // Battery
                    RowLayout {
                        visible: battery.battPresent
                        spacing: 1 // Tight spacing between the battery body and the tip
                        
                        // Main Battery Body
                        Rectangle {
                            id: batteryProgress
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 16
                            Layout.alignment: Qt.AlignVCenter
                            radius: 4.5
                            
                            // Track Color (The empty part of the battery)
                            color: theme.surface

                            // The Solid Fill Level
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: parent.width * battery.battLevel
                                radius: 4.5
                                color: theme.text;
                            }
                            
                            // The Inner Text & Icon
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 0

                                // Low Battery
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.rightMargin: 1
                                    text: "!"
                                    font.family: theme.fontFace
                                    font.pixelSize: 12
                                    visible: {
                                        if (battery.battLevel <= 0.2 && !battery.battCharging) {
                                            return true
                                        }
                                        return false
                                    } 

                                    // Cuts out of the solid fill
                                    color: theme.accent 
                                }

                                // Charging Bolt Icon
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.rightMargin: 1
                                    text: "󱐋"
                                    font.family: theme.fontFace
                                    font.pixelSize: 12
                                    visible: battery.battCharging
                                    // Cuts out of the solid fill
                                    color: theme.accent 
                                }
                                
                                // Percentage Text
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    font.family: theme.fontFace
                                    font.pixelSize: 12
                                    font.bold: true
                                    text: Math.round(battery.battLevel * 100)
                                    color: theme.accent
                                }
                            }
                        }

                        // Battery Tip (The positive terminal nub)
                        Rectangle {
                            Layout.preferredWidth: 2
                            Layout.preferredHeight: 6
                            Layout.alignment: Qt.AlignVCenter
                            radius: 1
                            
                            // If full, color it with the fill. Otherwise, use the track color.
                            color: {
                                if (battery.battLevel >= 0.98) {
                                    return theme.text;
                                }

                                return theme.surface;
                            }
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
                            onClicked: root.togglePopup(volumePopup)
                        }
                    }

                    // Network
                    Text {
                        id: networkIcon
                        text: networkWidget.isWifiActiveRoute ? "󰤥" : "󰈀"
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeXl
                        color: networkWidget.connectionState === 1 ? theme.accent :
                               networkWidget.connectionState === 2 ? theme.urgent :
                               networkWidget.currentWifiSsid !== "" ? theme.accent : theme.text 
                        
                        HoverHandler { id: networkIconHover }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePopup(networkPopup)
                        }
                    }

                    // Bluetooth
                    Text {
                        id: bluetoothIcon
                        text: "󰂯"
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeXl
                        color: Bluetooth.devices.values.some(d => d.connected) ? theme.accent : theme.text

                        HoverHandler { id: bluetoothIconHover }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePopup(bluetoothPopup)
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
                            onClicked: root.togglePopup(notifCenter)
                        }
                    }
                    
                    // Shortcuts Trigger
                    Text {
                        id: shortcutsIcon
                        text: "󰌌"
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeXl
                        color: theme.text
                        
                        HoverHandler { id: shortcutsIconHover }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePopup(shortcutsPopup)
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
                            onClicked: root.togglePopup(powerButtonPopup)
                        }
                    }
                }
            }
        }

    }
 
    // === POPUPS ===    
    NetworkPopup {
        id: networkPopup
        anchor.item: networkIcon
        theme: root.theme
        networkWidget: networkWidget
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
    
    ShortcutsPopup {
        id: shortcutsPopup
        anchor.item: shortcutsIcon
        theme: root.theme
    }
    
    CalendarPopup {
        id: calendarPopup
        anchor.item: timePillBox
        theme: root.theme
    }
    
    NotificationCenter {
        id: notifCenter
        anchor.item: notifBellIcon
        notifModel: root.notifModel
        theme: root.theme
        dismissNotification: root.dismissNotification
    }

    // === PROCESS'S ===
    NetworkWidget {
        id: networkWidget
    }
}
