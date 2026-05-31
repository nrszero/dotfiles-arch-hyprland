import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root
    // --- BATTERY LOGIC (Manual Polling) ---
    property bool battPresent: false
    property real battLevel: 0
    property bool battCharging: false

    Process {
        id: battProc
        // Try to read capacity and status. 2>/dev/null hides errors if file missing.
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null; cat /sys/class/power_supply/BAT0/status 2>/dev/null"]
        running: true // Run once on startup
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n")
                if (lines.length >= 2) {
                    // We found a battery!
                    root.battPresent = true
                    root.battLevel = parseInt(lines[0]) / 100.0
                    root.battCharging = (lines[1] === "Charging")
                } else {
                    // No battery found (Desktop)
                    root.battPresent = false
                }
            }
        }
    }

    // Poll every 5 seconds
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: battProc.running = true
    }
}
