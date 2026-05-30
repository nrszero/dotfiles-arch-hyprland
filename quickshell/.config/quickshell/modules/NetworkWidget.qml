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
    
    // Polling interval in milliseconds - 10 seconds
    property int pollInterval: 10000
    
    // Internal state tracking
    // 0: Disconnected/Error, 1: Connected, 2: Connecting
    property int connectionState: 0
    property string rawOutput: ""

    // Layout sizing - adopt the size of the icon text
    implicitWidth: 30
    implicitHeight: 30

    // -------------------------------------------------------------------------
    // Backend Logic: Process & Timer
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
                
                // Parse the output
                // Expected format: "100 (connected)" or "20 (unavailable)"
                
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

    Timer {
        id: ticker
        interval: root.pollInterval
        running: true
        repeat: true
        triggeredOnStart: true // Update immediately on load
        
        onTriggered: {
            // Concurrency Control:
            // Only start if the previous process has finished.
            // This prevents a pile-up of zombie processes if nmcli hangs.
            if (!nmcliCmd.running) {
                nmcliCmd.running = true
            }
        }
    }
}
