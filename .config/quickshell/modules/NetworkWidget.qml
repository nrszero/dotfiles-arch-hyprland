// NetworkWidget.qml
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    
    // -------------------------------------------------------------------------
    // API Properties
    // -------------------------------------------------------------------------
    // The interface to monitor, as requested: enp15s0
    property string interfaceName: ""
    property string wifiInterfaceName: ""
    property int pollInterval: 10000
    
    // 0: Disconnected/Error, 1: Connected, 2: Connecting
    property int connectionState: 0
    property string rawOutput: ""
    
    property ListModel wifiModel: ListModel {}
    property bool isScanning: false
    property bool isWifiActiveRoute: false
    property string currentWifiSsid: ""
    property int currentWifiSignal: 0

    // Layout sizing - adopt the size of the icon text
    implicitWidth: 30
    implicitHeight: 30

    // -------------------------------------------------------------------------
    // Backend Logic: Ethernet Polling
    // -------------------------------------------------------------------------
    Process {
        id: nmcliCmd
        // Use the -g flag to get only the state field
        // Use list format to prevent shell injection
        command: ["nmcli", "-g", "GENERAL.STATE", "device", "show", root.interfaceName]
        
        // Start stopped; the Timer controls the lifecycle
        running: false

        // Capture stdout when the process exits
        stdout: StdioCollector {
            onStreamFinished: {
                // Store raw text for debugging
                root.rawOutput = this.text.trim()
                const out = root.rawOutput.toLowerCase()
                
                if (out.indexOf("connected")!== -1 && out.indexOf("disconnected") === -1) {
                    root.connectionState = 1 // Connected
                } else if (out.indexOf("connecting")!== -1 || out.indexOf("config")!== -1) {
                    root.connectionState = 2 // Connecting
                } else {
                    root.connectionState = 0 // Disconnected
                }
            }
        }
    }
    
    // -------------------------------------------------------------------------
    // Backend Logic: Wi-Fi Active Connection Polling (NEW)
    // -------------------------------------------------------------------------
    Process {
        id: wifiActiveCmd
        // FIX: using -g gets ONLY the value, removing the "GENERAL.CONNECTION:" prefix
        command: ["nmcli", "-g", "GENERAL.CONNECTION", "device", "show", root.wifiInterfaceName]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const activeConn = this.text.trim();
                // NetworkManager returns "--" if disconnected, or nothing if interface is down
                if (activeConn === "" || activeConn === "--") {
                    root.currentWifiSsid = "";
                } else {
                    root.currentWifiSsid = activeConn;
                }
            }
        }
    }
    
    // -------------------------------------------------------------------------
    // Backend Logic: Check Default Route (Active vs Inactive)
    // -------------------------------------------------------------------------
    Process {
        id: routeCheckCmd
        command: ["nmcli", "-t", "-f", "DEVICE,DEFAULT", "dev"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                let isActive = false;
                
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split(":");
                    // parts[0] is the interface (wlp14s0), parts[1] is yes/no
                    if (parts.length >= 2 && parts[0] === root.wifiInterfaceName && parts[1] === "yes") {
                        isActive = true;
                        break;
                    }
                }
                root.isWifiActiveRoute = isActive;
            }
        }
    }

    // -------------------------------------------------------------------------
    // Backend Logic: Wi-Fi Scanning
    // -------------------------------------------------------------------------
    Process {
        id: wifiScanCmd
        // -t (terse) makes it colon-separated. 
        // -f requests specific fields: SSID, Signal %, Security protocols, In-Use (*)
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,IN-USE", "dev", "wifi", "list"]
        running: false
        
        onRunningChanged: root.isScanning = running

        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiModel.clear();
                root.currentWifiSignal = 0;

                const lines = this.text.trim().split("\n");
                let networks = {};
                
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i] === "") continue;
                    
                    // Split by colon (Note: this naive split struggles if an SSID contains a literal colon)
                    const parts = lines[i].split(":");
                    if (parts.length >= 4) {
                        const ssid = parts[0];
                        if (ssid === "") continue;
                        
                        const signalLevel = parseInt(parts[1]);
                        const inUse = (parts[3] === "*");

                        if (inUse) {
                            root.currentWifiSignal = signalLevel;
                        }
                        
                        // If we haven't seen this SSID yet, save it
                        if (!networks[ssid]) {
                            networks[ssid] = {
                                ssid: ssid,
                                signal: signalLevel,
                                security: parts[2],
                                inUse: inUse
                            };
                        } else {
                            // If we already saw this SSID, update it ONLY IF this specific AP is the active one,
                            // or if it's not active but has a stronger signal than the one we previously saved.
                            if (inUse) {
                                networks[ssid].inUse = true;
                                networks[ssid].signal = signalLevel;
                                networks[ssid].security = parts[2];
                            } else if (!networks[ssid].inUse && signalLevel > networks[ssid].signal) {
                                networks[ssid].signal = signalLevel;
                                networks[ssid].security = parts[2];
                            }
                        }
                    }
                }

                // Push the filtered, prioritized networks to the UI model
                for (let key in networks) {
                    root.wifiModel.append(networks[key]);
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Backend Logic: Wi-Fi Connecting & Disconnecting
    // -------------------------------------------------------------------------
    Process {
        id: wifiConnectCmd
        property string targetSsid: ""
        property string password: ""
        
        command: password === "" 
                 ? ["nmcli", "dev", "wifi", "connect", targetSsid] 
                 : ["nmcli", "dev", "wifi", "connect", targetSsid, "password", password]
        running: false
        
        // Force a rescan when the connection attempt finishes
        onRunningChanged: if (!running) forceScan()
    }
    
    Process {
        id: wifiDisconnectCmd
        command: ["nmcli", "device", "disconnect", root.wifiInterfaceName]
        running: false
        
        // Force a rescan when the disconnect finishes
        onRunningChanged: if (!running) forceScan()
    }
    
    Process {
        id: wifiForgetCmd
        command: ["nmcli", "connection", "delete", root.currentWifiSsid]
        running: false

        // Force a rescan when the network is forgotten
        onRunningChanged: if (!running) forceScan()
    }
    
    function connectToWifi(ssid, password) {
        wifiConnectCmd.targetSsid = ssid;
        wifiConnectCmd.password = password;
        wifiConnectCmd.running = true;
    }
    
    function disconnectWifi() {
        wifiDisconnectCmd.running = true;
    }
    
    function forgetWifi() {
        wifiForgetCmd.running = true;
    }
    
    function forceScan() {
        if (!wifiScanCmd.running) wifiScanCmd.running = true;
        if (!wifiActiveCmd.running) wifiActiveCmd.running = true;
    }

    Timer {
        id: ticker
        interval: root.pollInterval
        running: true
        repeat: true
        triggeredOnStart: true // Update immediately on load
        
        onTriggered: {
            // Only start if the previous process has finished.
            // This prevents a pile-up of zombie processes if nmcli hangs.
            if (!nmcliCmd.running) nmcliCmd.running = true;
            if (!wifiScanCmd.running) wifiScanCmd.running = true;
            if (!wifiActiveCmd.running) wifiActiveCmd.running = true;
            if (!routeCheckCmd.running) routeCheckCmd.running = true;
        }
    }
}
