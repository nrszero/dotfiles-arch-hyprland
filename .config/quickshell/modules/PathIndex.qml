import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var entries: []
    property int revision: 0
    property double lastFetch: 0
    readonly property int staleMs: 180000

    function refreshIfStale() {
        if (entries.length === 0 || (Date.now() - lastFetch) > staleMs)
            root.refresh()
    }

    function refresh() {
        if (fetch.running)
            fetch.running = false
        Qt.callLater(() => { fetch.running = true })
    }

    Process {
        id: fetch
        running: true
        command: ["bash", "-c", "IFS=':' read -ra dirs <<< \"$PATH\"; find \"${dirs[@]}\" -maxdepth 1 -type f -executable 2>/dev/null | awk -F/ '!seen[$NF]++ { print $NF \"\\t\" $0 }'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = this.text.trim()
                const lines = raw ? raw.split("\n") : []
                const list = []
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i]
                    if (!line)
                        continue
                    const tab = line.indexOf("\t")
                    if (tab < 0)
                        continue
                    const name = line.slice(0, tab)
                    const path = line.slice(tab + 1)
                    const slash = path.lastIndexOf("/")
                    list.push({
                        name: name,
                        path: path,
                        dir: slash > 0 ? path.slice(0, slash) : path
                    })
                }
                list.sort((a, b) => a.name.localeCompare(b.name))
                root.entries = list
                root.lastFetch = Date.now()
                root.revision++
            }
        }
    }
}
