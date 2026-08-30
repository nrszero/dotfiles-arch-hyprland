import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var binds: []
    property int revision: 0

    function refresh() {
        if (fetch.running)
            fetch.running = false
        Qt.callLater(() => { fetch.running = true })
    }

    Process {
        id: fetch
        running: true
        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                const list = []
                try {
                    const raw = this.text.trim()
                    if (!raw)
                        return
                    const data = JSON.parse(raw)
                    for (let i = 0; i < data.length; i++) {
                        const b = data[i]
                        if (!b || b.key === "" || b.key === undefined || b.key === null)
                            continue

                        const mods = []
                        if (b.modmask & 64)
                            mods.push("SUPER")
                        if (b.modmask & 4)
                            mods.push("CTRL")
                        if (b.modmask & 8)
                            mods.push("ALT")
                        if (b.modmask & 1)
                            mods.push("SHIFT")

                        const modStr = mods.length > 0 ? mods.join(" + ") + " + " : ""
                        const keyStr = ("" + b.key).toUpperCase()
                        const hasDesc = b.description !== undefined && b.description !== ""

                        list.push({
                            ordinal: i,
                            triggerText: modStr + keyStr,
                            mainTitle: hasDesc ? b.description : (b.dispatcher || ""),
                            dispatcher: b.dispatcher || "",
                            arg: b.arg || ""
                        })
                    }
                } catch (e) {
                    console.error("Failed to parse hyprctl binds: " + e)
                }
                root.binds = list
                root.revision++
            }
        }
    }
}
