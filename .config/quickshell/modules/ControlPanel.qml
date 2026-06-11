import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris

Item {
    id: root
    required property var screenModel
    required property var notifModel
    required property var theme

    PowerButton {
        id: powerPopup
        screenModel: root.screenModel
        theme: root.theme
    }

    PanelWindow {
        id: controlPanel
        screen: root.screenModel
            
        // --- CONFIGURATION ---
        implicitWidth: 360
        visible: false
        
        // Float over everything (including fullscreen apps if you want)
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore

        // --- ANCHORING (Right Side) ---
        anchors {top: true; right: true; bottom: true;}

        color: "transparent" // Background color

        // --- SHORTCUT LOGIC ---
        GlobalShortcut {
            name: "togglePanel" // <--- Unique name for this panel
            onPressedChanged: {
                if (pressed) {
                    // Toggle only on focused monitor
                    if (Hyprland.focusedMonitor.name === root.screenModel.name) {
                        controlPanel.visible = !controlPanel.visible
                    } else {
                        controlPanel.visible = false
                    }
                }
            }
        }
        
        Timer {
            interval: 5000 // 5 Seconds
            // Only run if visible AND mouse is NOT hovering
            running: controlPanel.visible && !mainMouseArea.containsMouse
            repeat: false
            onTriggered: controlPanel.visible = false
        }


        // --- REUSABLE CARD COMPONENT ---
        component Card: Rectangle {
            color: theme.surface
            radius: theme.radius
            border.width: 1
            border.color: Qt.rgba(1,1,1, 0.05) // Very subtle highlight
        }

        // --- MAIN BACKGROUND ---
        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            color: theme.background
            radius: theme.radius
            border.width: theme.borderWidth
            border.color: theme.borderColor

            MouseArea {
                id: mainMouseArea
                anchors.fill: parent
                hoverEnabled: true
            }
            
            // --- CONTENT ---
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: theme.padding
                spacing: theme.padding 

                // --- HEADER: Clock, Battery and Power ---
                RowLayout {
                    Layout.fillWidth: true
                    
                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: Qt.formatTime(new Date(), "HH:mm")
                            color: theme.text
                            font.family: theme.fontFace
                            font.pixelSize: 32
                            font.bold: true
                        }
                        Text {
                            text: Qt.formatDate(new Date(), "dddd, MMMM d")
                            color: theme.accent
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
                        }
                    }
                                        
                    Item { Layout.fillWidth: true }

                    // 2. BATTERY BADGE (The "Power Cluster")
                    Rectangle {
                        visible: battery.battPresent
                        
                        Layout.preferredHeight: 40 
                        implicitWidth: battRow.implicitWidth + 30 
                        
                        color: theme.surface 
                        radius: theme.radius

                        RowLayout {
                            id: battRow
                            anchors.centerIn: parent
                            spacing: 8
                            
                            // Percentage
                            Text {
                                text: Math.round(battery.battLevel * 100) + "%"
                                color: theme.text
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeSm
                                font.bold: true
                            }

                            // Icon
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
                                    if (battery.battLevel > 0.1) return "󰁻";
                                    if (battery.battLevel > 0.05) return "󰁺";
                                    return "󰂃"
                                }
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeXl
                                color: theme.text 
                            }
                        }

                        BatteryProc {
                            id: battery
                        }
                    }

                    // --- POWER BUTTON ---
                    Button {
                        background: Rectangle { 
                            color: parent.hovered ? theme.accent : theme.surface
                            radius: theme.radius
                            implicitWidth: 40; implicitHeight: 40;
                        }
                        
                        contentItem: Text {
                            text: "󰐥"
                            color: theme.text
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeXl
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            controlPanel.visible = false // Optional: hide side panel
                            powerPopup.visible = true    // Show the popup
                        }

                        MouseArea {
                            id: powerMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        } 
                    }
                }

                
                // --- TILES ROW (Network & Bluetooth) ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    // Network Card
                    Card {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 80
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            
                            Text { 
                                text: {
                                    switch(network.connectionState) {
                                        case 1: return "󰱓"; // Connected (Ethernet)
                                        case 2: return "󰲝"; // Connecting (Same icon, different color)
                                        default: return "󰅛"; // Disconnected (Ethernet with X)
                                    }
                                }
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeXl
                                color: theme.accent
                                Layout.alignment: Qt.AlignCenter
                            }
                            
                            Text { text: "Ethernet"; font.family: theme.fontFace; font.pixelSize: theme.fontSizeMd; color: theme.text; }
                        }
                        
                        NetworkWidget {
                            id: network
                            interfaceName: "enp15s0"
                        }
                    }

                    // Bluetooth Card
                    Card {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 80
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - 20 // Margin for the list text
                            spacing: 2

                            // --- 1. ICON (Always Top) ---
                            Text { 
                                text: "󰂯"
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeXl 
                                // Blue if connected, Grey if off
                                color: Bluetooth.devices.values.some(d => d.connected) ? theme.accent : theme.subText
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // --- 2. LABEL (Always Below Icon) ---
                            Text { 
                                text: "Bluetooth" // Static label like "Ethernet"
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeMd
                                color: theme.text
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // --- 3. DEVICE LIST (Below Label) ---
                            ListView {
                                // Only show if we have connected devices
                                visible: Bluetooth.devices.values.some(d => d.connected)
                                
                                Layout.fillWidth: true
                                // Calculate height automatically based on items, but cap it so it doesn't overflow
                                Layout.preferredHeight: Math.min(count * 15, 30) 
                                
                                clip: true
                                interactive: false // Disable scrolling for a static look
                                
                                model: Bluetooth.devices.values.filter(d => d.connected)

                                delegate: RowLayout {
                                    width: ListView.view.width
                                    spacing: 5
                                    
                                    // Spacers to center the row content
                                    Item { Layout.fillWidth: true } 

                                    // Device Name
                                    Text { 
                                        text: modelData.name
                                        color: theme.subText
                                        font.family: theme.fontFace
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: 80 // Truncate long names
                                    }

                                    // Battery Percentage
                                    Text {
                                        visible: modelData.battery >= 0
                                        text: Math.round(modelData.battery * 100) + "%"
                                        color: modelData.battery < 0.2 ? theme.urgent : theme.success
                                        font.family: theme.fontFace
                                        font.pixelSize: 10
                                    }

                                    Item { Layout.fillWidth: true }
                                }
                            }
                        }
                    }
                }

               // RowLayout {
               //     Layout.fillWidth: true
               //     spacing: 10
               //     
               //     // New Card
               //     Card {
               //         Layout.fillWidth: true
               //         Layout.preferredHeight: 80
               //     
               //     }
               // }
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // --- VOLUME SLIDER CARD ---
                    Card {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60

                        PwObjectTracker {
                            objects: [ Pipewire.defaultAudioSink ]
                        } 

                        RowLayout {
                            anchors.fill: parent
                            Layout.fillWidth: true
                            anchors.margins: 10
                            spacing: 10

                            Text {
                                text: (Pipewire.defaultAudioSink?.audio.muted) ? "" : ""
                                color: theme.text
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeXl
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
                                }
                            }
                             
                            // Custom Slider
                            Rectangle {
                                Layout.fillWidth: true
                                height: 6
                                radius: 3
                                color: Qt.darker(theme.surface, 1.5)
                                
                                property var vol: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio.volume : 0

                                Rectangle {
                                    width: parent.width * parent.vol
                                    height: parent.height
                                    radius: 3
                                    color: theme.accent
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onPositionChanged: (mouse) => {
                                        if(Pipewire.defaultAudioSink) 
                                            Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                                    }
                                    onClicked: (mouse) => {
                                        if(Pipewire.defaultAudioSink) 
                                            Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                                    }
                                }
                            }
                        
                            Text {
                                text: Math.floor((Pipewire.defaultAudioSink?.audio.volume ?? 0) * 100) + "%"
                                color: theme.subText
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeMd
                                Layout.preferredWidth: 30
                            }  
                        }
                    }
 
                    // --- MICROPHONE SLIDER CARD ---
                    Card {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60

                        // Track the Microphone (Source)
                        PwObjectTracker { objects: [ Pipewire.defaultAudioSource ] }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            // Mic Toggle
                            Text {
                                text: (Pipewire.defaultAudioSource?.audio.muted) ? "󰍭" : "󰍬"
                                color: (Pipewire.defaultAudioSource?.audio.muted) ? theme.urgent : theme.text
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeXl
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted
                                }
                            }

                            // Mic Volume Slider
                            Rectangle {
                                Layout.fillWidth: true; height: 6; radius: 3
                                color: Qt.darker(theme.surface, 1.5)
                                
                                property var vol: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio.volume : 0

                                Rectangle {
                                    width: parent.width * parent.vol
                                    height: parent.height
                                    radius: 3
                                    color: theme.accent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onPositionChanged: (mouse) => { 
                                        if(Pipewire.defaultAudioSource) 
                                            Pipewire.defaultAudioSource.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                                    }
                                    onClicked: (mouse) => { 
                                        if(Pipewire.defaultAudioSource) 
                                            Pipewire.defaultAudioSource.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                                    }
                                }
                            }

                            // Percentage
                            Text {
                                text: Math.floor((Pipewire.defaultAudioSource?.audio.volume ?? 0) * 100) + "%"
                                color: theme.subText
                                font.family: theme.fontFace
                                font.pixelSize: theme.fontSizeMd
                                Layout.preferredWidth: 30
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }        
                }

                // --- MEDIA PLAYER CARD ---
                Card {
                    id: mediaCard
                    Layout.fillWidth: true
                    
                    // Hide if no player is found
                    visible: Mpris.players.values.length > 0
                    
                    // Animate height when appearing/disappearing
                    Layout.preferredHeight: visible ? 100 : 0
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: 200 } }
                    clip: true // Cut off content during animation
                    
                    Component.onCompleted:{
                        var players = Mpris.players.values
                        var check = Mpris.players.values.length

                        console.log("Players Check:", check)
                        console.log("Players Values", players)
                        console.log("isPlaying:", players[0].isPlaying)
                        console.log("playbackState:", players[0].playbackState)
                        console.log("currentPlayer:", currentPlayer)
                    }
                                        
                    ListView {
                        id: mediaList
                        anchors.fill: parent
                        model: Mpris.players.values
                        orientation: ListView.Horizontal
                        snapMode: ListView.SnapOneItem
                        highlightRangeMode: ListView.StrictlyEnforceRange
                        boundsBehavior: Flickable.StopAtBounds

                        function jumpToPlaying() {
                            var players = Mpris.players.values
                            for (var i = 0; i < players.length; i++) {
                                // User defined variable: MprisPlaybackState
                                if (players[i].playbackState === MprisPlaybackState.Playing) {
                                    currentIndex = i
                                    return
                                }
                            }
                        }
                        
                        Component.onCompleted: jumpToPlaying()
                        onCountChanged: jumpToPlaying()
                        onVisibleChanged: if (visible) jumpToPlaying()

                        delegate: Item {
                            width: ListView.view.width
                            height: ListView.view.height
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 12

                                // 1. ALBUM ART
                                Rectangle {
                                    width: 80
                                    height: 80
                                    color: Qt.rgba(0,0,0, 0.2)
                                    radius: theme.radius - 4
                                    clip: true
                                    
                                    Image {
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        source: modelData.trackArtUrl || ""
                                        visible: status === Image.Ready
                                    }
                                    
                                    // Fallback Icon if no art
                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        font.family: theme.fontFace
                                        font.pixelSize: 32
                                        color: theme.subText
                                        visible: parent.children[0].status !== Image.Ready
                                    }
                                }

                                // 2. INFO & CONTROLS
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 2

                                    // Title
                                    Text {
                                        text: modelData.trackTitle || "Unknown Title"
                                        color: theme.text
                                        font.family: theme.fontFace
                                        font.bold: true
                                        font.pixelSize: theme.fontSizeMd
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    // Artist
                                    Text {
                                        text: modelData.trackArtist || "Unknown Artist"
                                        color: theme.subText
                                        font.family: theme.fontFace
                                        font.pixelSize: theme.fontSizeSm
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    
                                    Item { Layout.fillHeight: true } // Spacer

                                    // Controls
                                    RowLayout {
                                        spacing: 20
                                        Layout.alignment: Qt.AlignLeft

                                        // PREVIOUS
                                        Text {
                                            text: "󰒮"
                                            color: prevArea.pressed ? theme.accent : theme.text
                                            font.family: theme.fontFace
                                            font.pixelSize: theme.fontSizeXl
                                            MouseArea {
                                                id: prevArea
                                                anchors.fill: parent
                                                onClicked: modelData.previous()
                                            }
                                        }

                                        // PLAY / PAUSE
                                        Rectangle {
                                            width: 32; height: 32
                                            radius: 16
                                            color: "transparent"
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: (modelData.playbackState === MprisPlaybackState.Playing) ? "󰏤" : "󰐊"
                                                color: theme.text
                                                font.family: theme.fontFace
                                                font.pixelSize: theme.fontSizeXl
                                            }
                                            MouseArea {
                                                id: ppArea
                                                anchors.fill: parent
                                                onClicked: modelData.togglePlaying()
                                            }
                                        }

                                        // NEXT
                                        Text {
                                            text: "󰒭"
                                            color: nextArea.pressed ? theme.accent : theme.text
                                            font.family: theme.fontFace
                                            font.pixelSize: theme.fontSizeXl
                                            MouseArea {
                                                id: nextArea
                                                anchors.fill: parent
                                                onClicked: modelData.next()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Optional: Page Indicator (Dots) if > 1 player
                    PageIndicator {
                        id: indicator
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: 4
                        count: mediaList.count
                        currentIndex: mediaList.currentIndex // The ListView is the first child
                        visible: count > 1
                        
                        delegate: Rectangle {
                            width: 6; height: 6; radius: 3
                            color: index === indicator.currentIndex ? theme.accent : theme.subText
                            opacity: index === indicator.currentIndex ? 1.0 : 0.3
                        }
                    }

                }

                // Separator
                Rectangle { Layout.fillWidth: true; height: 2; color: theme.accent; opacity: 0.2 }

                // NOTIFICATION LIST
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    
                    Text { 
                        text: "Notifications"
                        color: theme.text
                        font.bold: true
                        font.pixelSize: theme.fontSizeMd
                    }

                    Item { Layout.fillWidth: true } // Spacer

                    // Clear All Button (Trash Icon)
                    Button {
                        // Only show if there are notifications
                        visible: root.notifModel.count > 0
                        
                        background: null
                        contentItem: Text {
                            id: clearIcon
                            text: "" // Trash Icon (Nerd Font)
                            color: theme.subText
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeMd
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            
                            // Turn Red on Hover
                            onEntered: clearIcon.color = theme.urgent
                            onExited: clearIcon.color = theme.subText
                            
                            onClicked: {
                                // Iterate backwards to remove all safely
                                for (var i = root.notifModel.count - 1; i >= 0; i--) {
                                    shellRoot.dismissNotification(i)
                                }
                            }
                        }
                    }
                }

                // If empty
                Text {
                    visible: root.notifModel.count === 0
                    text: "No new notifications"
                    color: theme.subText
                    font.italic: true
                }

                // The List
                ListView {
                    id: notifList
                    model: root.notifModel
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8
                    clip: true

                    delegate: Card {
                        width: notifList.width
                        height: 80
                        color: theme.surface
                        
                        ColumnLayout {
                            id: contentCol
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2
                            
                            RowLayout {
                                Layout.fillWidth: true

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
                            
                                    // Fallback text if the image fails to load
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
                                    font.pixelSize: theme.fontSizeMd
                                    color: theme.text
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                // Time Label
                                Text {
                                    text: model.time
                                    font.pixelSize: theme.fontSizeSm
                                    color: theme.text
                                }

                                // Dismiss button
                                Button {
                                    text: "✕"
                                    background: null
                                    contentItem: Text { text: "✕"; color: theme.urgent }
                                    
                                    MouseArea {
                                        id: dismissMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: shellRoot.dismissNotification(index)
                                    }
                                }
                            }  
                                    
                            Text {
                                text: model.body
                                color: theme.subText
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                                font.pixelSize: theme.fontSizeSm
                                elide: Text.ElideRight      
                                maximumLineCount: 2
                            }
                        } 
                    }
                }

                // Item { Layout.fillHeight: true } // Bottom Spacer
            }
        }
    }
}    

