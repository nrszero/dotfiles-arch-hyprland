import Quickshell
import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: root

    property var sinks: []
    property var sources: []
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    function nodeLabel(node) {
        if (!node)
            return ""
        return node.nickname || node.description || node.name || "Unknown device"
    }

    function isCurrentSink(node) {
        return !!(node && root.sink && node.id === root.sink.id)
    }

    function isCurrentSource(node) {
        return !!(node && root.source && node.id === root.source.id)
    }

    function setSink(node) {
        if (node)
            Pipewire.preferredDefaultAudioSink = node
    }

    function setSource(node) {
        if (node)
            Pipewire.preferredDefaultAudioSource = node
    }

    function refresh() {
        const outs = []
        const ins = []
        const nodes = Pipewire.nodes ? [...Pipewire.nodes.values] : []
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i]
            if (!n || n.isStream)
                continue
            if (n.isSink)
                outs.push(n)
            else if (n.audio)
                ins.push(n)
        }
        root.sinks = outs
        root.sources = ins
    }

    Component.onCompleted: refresh()

    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { root.refresh() }
    }

    PwObjectTracker {
        objects: {
            const list = []
            if (root.sink)
                list.push(root.sink)
            if (root.source)
                list.push(root.source)
            for (let i = 0; i < root.sinks.length; i++)
                list.push(root.sinks[i])
            for (let i = 0; i < root.sources.length; i++)
                list.push(root.sources[i])
            return list
        }
    }
}
