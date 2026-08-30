import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string expression: ""
    property string result: ""

    onExpressionChanged: {
        if (!expression) {
            debounce.stop()
            result = ""
            return
        }
        debounce.restart()
    }

    Timer {
        id: debounce
        interval: 150
        repeat: false
        onTriggered: {
            qalc.running = false
            qalc.command = ["qalc", "-t", "--", root.expression]
            qalc.running = true
        }
    }

    Process {
        id: qalc
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.result = text.trim()
            }
        }
    }
}
