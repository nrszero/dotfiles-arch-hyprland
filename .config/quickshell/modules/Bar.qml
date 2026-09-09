//@ pragma UseQApplication
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris

PanelWindow {
    id: root
    screen: screenModel
    
    required property var screenModel
    required property var theme
    required property var notifModel
    required property var dismissNotification   // function(index) from shell
    required property var networkWidget
    required property var battery
    required property bool barVisible
    
    readonly property int wsPerMonitor: 5
    function localIndexOf(id) {
        const n = root.wsPerMonitor
        let idx = Number(id) % n
        if (idx === 0)
            idx = n
        return idx
    }
    property var hMonitor: {
        if (!Hyprland.monitors || !Hyprland.monitors.values || !root.screenModel) return null;
        // Guard: screenModel may temporarily be a placeholder during output changes.
        const smName = root.screenModel && root.screenModel.name;
        if (!smName || smName === "FALLBACK") return null;
        for (let m of Hyprland.monitors.values) {
            if (m.name === smName) {
                return m;
            }    
        }
        return null;
    }
    readonly property int layoutIndex: {
        const _m = root.hMonitor
        if (!Hyprland.monitors || !Hyprland.monitors.values || !_m)
            return 0
        const list = []
        for (let m of Hyprland.monitors.values) {
            if (m && m.name)
                list.push(m)
        }
        list.sort((a, b) => {
            if (a.x !== b.x)
                return a.x - b.x
            if (a.y !== b.y)
                return a.y - b.y
            return String(a.name).localeCompare(String(b.name))
        })
        for (let i = 0; i < list.length; i++) {
            if (list[i].name === _m.name)
                return i
        }
        return 0
    }
    property bool hasFullscreen: false
    property bool isInteractive: barHover.hovered ||
                                 networkPopup.visible ||
                                 bluetoothPopup.visible ||
                                 volumePopup.visible ||
                                 powerButtonPopup.visible ||
                                 calendarPopup.visible ||
                                 notifCenter.visible ||
                                 nowPlayingPopup.visible ||
                                 batteryPopup.visible

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

    Item {
        id: topEdgeHit
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 10
    }

    mask: Region {
        regions: [
            Region { item: mainLayout },
            Region { item: topEdgeHit }
        ]
    }

    HoverHandler {
        id: barHover
    }

    Component.onCompleted: {
        Hyprland.refreshWorkspaces()
        fsCheckTimer.restart()
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
            powerButtonPopup, calendarPopup, notifCenter,
            nowPlayingPopup, batteryPopup
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
                id: npPill
                theme: root.theme
                onClicked: root.togglePopup(nowPlayingPopup)
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
                    model: root.wsPerMonitor
                    delegate: Rectangle {
                        width: isActive ? 28 : 22
                        height: 22
                        radius: theme.radius
 
                        property int localId: index + 1
                        property int wsId: root.layoutIndex * root.wsPerMonitor + localId
                        property bool isActive: {
                            const aw = root.hMonitor && root.hMonitor.activeWorkspace
                            if (!aw)
                                return false
                            if (aw.id === wsId)
                                return true
                            return root.localIndexOf(aw.id) === localId
                        }
                        property bool hasWindows: {
                            if (!Hyprland.toplevels.values) return false
                            for (let t of Hyprland.toplevels.values) {
                                if (!t.workspace)
                                    continue
                                if (t.workspace.id === wsId)
                                    return true
                                const onThis = root.hMonitor && t.monitor && t.monitor.name === root.hMonitor.name
                                if (onThis && root.localIndexOf(t.workspace.id) === localId)
                                    return true
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
                            text: localId
                            visible: isActive || hasWindows
                        }
                    
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const mon = root.hMonitor && root.hMonitor.name
                                if (mon)
                                    Hyprland.dispatch(`hl.dsp.focus({ monitor = "${mon}" })`)
                                Hyprland.dispatch(`hl.dsp.focus({ workspace = ${wsId}, on_current_monitor = true })`)
                            }
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
                                anchors.centerIn: parent; width: 22; height: 22
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
                id: rightBarMod
                implicitWidth: statusRow.implicitWidth + 16
                
                RowLayout {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: theme.spacing
                    
                    Text {
                        id: batteryIcon
                        visible: battery.battPresent
                        text: battery.icon
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeXl
                        color: battery.iconColor(theme)

                        HoverHandler { id: batteryIconHover }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePopup(batteryPopup)
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
                        visible: Bluetooth.defaultAdapter
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
    CalendarPopup {
        id: calendarPopup
        anchor.item: timePillBox
        theme: root.theme
    }
    NowPlayingPopup {
        id: nowPlayingPopup
        anchor.item: npPill
        theme: root.theme
        currentIndex: npPill.currentIndex

        // Catch the signal and safely rotate the Pill's index
        onRequestPlayerChange: (step) => {
            let len = Mpris.players.values.length;
            if (len > 0) {
                // The math ensures we loop cleanly backwards and forwards
                npPill.currentIndex = (npPill.currentIndex + step + len) % len;
            }
        }
    }
    BatteryPopup {
        id: batteryPopup
        anchor.item: rightBarMod
        theme: root.theme
        battery: root.battery
    }
    VolumePopup {
        id: volumePopup
        anchor.item: rightBarMod
        theme: root.theme
    }
    NetworkPopup {
        id: networkPopup
        anchor.item: rightBarMod
        theme: root.theme
        networkWidget: root.networkWidget
    }
    BluetoothPopup {
        id: bluetoothPopup
        anchor.item: rightBarMod
        theme: root.theme
    }    
    NotificationCenter {
        id: notifCenter
        anchor.item: rightBarMod
        notifModel: root.notifModel
        theme: root.theme
        dismissNotification: root.dismissNotification
    }
    PowerButtonPopup {
        id: powerButtonPopup
        anchor.item: rightBarMod
        theme: root.theme
    }
}
