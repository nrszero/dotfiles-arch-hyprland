import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io

Item {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    property int deviceStateRev: 0
    property int liveWatchers: 0
    readonly property bool live: liveWatchers > 0

    property string pendingOp: ""
    property string pendingAddress: ""
    property string pendingPath: ""
    property var pendingDevice: null
    property var pendingAdapter: null
    property bool transitionSeen: false
    property bool expectedDiscovery: false
    property bool ownsDiscovery: false
    property var ownedAdapter: null
    property int stopAttempts: 0
    property bool awaitingLateDiscovery: false
    property string lastError: ""

    readonly property bool isBusy: pendingOp !== ""
    readonly property bool isScanning: !!(adapter && adapter.discovering)
    readonly property bool ownedAdapterScanning: !!(ownedAdapter && ownedAdapter.discovering)

    function watch() {
        liveWatchers++
        refreshDevices()
    }

    function unwatch() {
        liveWatchers = Math.max(0, liveWatchers - 1)
        stopOwnedDiscoveryIfIdle()
    }

    function stopOwnedDiscoveryIfIdle() {
        if (live || isBusy || !ownsDiscovery || !ownedAdapter)
            return
        if (!ownedAdapter.discovering) {
            if (awaitingLateDiscovery)
                return
            ownsDiscovery = false
            ownedAdapter = null
            stopAttempts = 0
            refreshDevices()
            return
        }
        if (stopAttempts >= 2)
            return

        stopAttempts++
        expectedDiscovery = false
        if (!begin("scan-stop", null, 5000, ownedAdapter))
            return
        ownedAdapter.discovering = false
        Qt.callLater(root.checkPending)
    }

    function refreshDevices() {
        deviceStateRev++
    }

    function clearError() {
        lastError = ""
    }

    function addressOf(device) {
        return device && device.address ? String(device.address) : ""
    }

    function isPending(device, operation) {
        if (!isBusy || addressOf(device) !== pendingAddress)
            return false
        return !operation || pendingOp === operation
    }

    function operationLabel(operation) {
        switch (operation || pendingOp) {
        case "pair": return "Pairing"
        case "connect": return "Connecting"
        case "disconnect": return "Disconnecting"
        case "forget": return "Forgetting"
        case "scan-start": return "Starting scan"
        case "scan-stop": return "Stopping scan"
        default: return "Working"
        }
    }

    function rejectBusy() {
        lastError = operationLabel() + " is already in progress"
        return false
    }

    function begin(operation, device, timeoutMs, operationAdapter) {
        if (isBusy)
            return rejectBusy()

        clearError()
        pendingOp = operation
        pendingDevice = device || null
        pendingAdapter = operationAdapter || null
        pendingAddress = addressOf(device)
        pendingPath = device && device.dbusPath ? String(device.dbusPath) : ""
        transitionSeen = false
        operationTimeout.interval = timeoutMs
        operationTimeout.restart()
        refreshDevices()
        return true
    }

    function finish(errorMessage) {
        operationTimeout.stop()
        if (errorMessage)
            lastError = errorMessage
        pendingOp = ""
        pendingAddress = ""
        pendingPath = ""
        pendingDevice = null
        pendingAdapter = null
        transitionSeen = false
        refreshDevices()
        Qt.callLater(root.stopOwnedDiscoveryIfIdle)
    }

    function pendingDeviceExists() {
        const devices = Bluetooth.devices && Bluetooth.devices.values
            ? Bluetooth.devices.values : []
        for (let i = 0; i < devices.length; i++) {
            const device = devices[i]
            if (!device)
                continue
            if (pendingPath !== "" && device.dbusPath === pendingPath)
                return true
            if (pendingPath === "" && pendingAddress !== "" && device.address === pendingAddress)
                return true
        }
        return false
    }

    function observeTransition() {
        const device = pendingDevice
        if (!device)
            return
        if (pendingOp === "connect" && device.state === BluetoothDeviceState.Connecting)
            transitionSeen = true
        else if (pendingOp === "disconnect" && device.state === BluetoothDeviceState.Disconnecting)
            transitionSeen = true
    }

    function pendingSucceeded() {
        const device = pendingDevice
        switch (pendingOp) {
        case "pair":
            return !!(device && device.paired && !pairProc.running)
        case "connect":
            return !!(device && device.connected && !pairProc.running)
        case "disconnect":
            return !!(device && !device.connected)
        case "forget":
            return !pendingDeviceExists() || !!(device && !device.paired && !device.connected)
        case "scan-start":
        case "scan-stop":
            return !!pendingAdapter && pendingAdapter.discovering === expectedDiscovery
        default:
            return false
        }
    }

    function pendingFailure() {
        const device = pendingDevice
        if (!device || !transitionSeen)
            return ""
        if (pendingOp === "connect" && device.state === BluetoothDeviceState.Disconnected)
            return "Could not connect to the Bluetooth device"
        if (pendingOp === "disconnect" && device.state === BluetoothDeviceState.Connected)
            return "Could not disconnect the Bluetooth device"
        return ""
    }

    function checkPending() {
        if (!isBusy) {
            refreshDevices()
            return
        }

        observeTransition()
        if (pendingSucceeded()) {
            if (pendingOp === "pair" && pendingDevice) {
                continueWithConnection(pendingDevice)
                return
            }
            if (pendingOp === "scan-stop" && pendingAdapter === ownedAdapter) {
                ownsDiscovery = false
                ownedAdapter = null
                stopAttempts = 0
            }
            finish("")
            return
        }

        const failure = pendingFailure()
        if (failure !== "") {
            finish(failure)
            return
        }
        refreshDevices()
    }

    function continueWithConnection(device) {
        operationTimeout.stop()
        device.trusted = true

        if (device.connected) {
            finish("")
            return
        }

        pendingOp = "connect"
        transitionSeen = false
        operationTimeout.interval = 15000
        operationTimeout.restart()
        refreshDevices()

        try {
            device.connect()
            Qt.callLater(root.checkPending)
        } catch (error) {
            finish("Connecting after pairing failed: " + error)
        }
    }

    function runDeviceOperation(operation, device) {
        if (!device) {
            lastError = "Bluetooth device is no longer available"
            return false
        }

        const timeoutMs = operation === "pair" ? 30000 : 15000
        if (!begin(operation, device, timeoutMs, null))
            return false

        try {
            if (operation === "connect")
                device.connect()
            else if (operation === "disconnect")
                device.disconnect()
            else if (operation === "forget")
                device.forget()
            Qt.callLater(root.checkPending)
            return true
        } catch (error) {
            finish(operationLabel(operation) + " failed: " + error)
            return false
        }
    }

    function pair(device) {
        if (device && device.paired) {
            refreshDevices()
            return true
        }
        if (!device) {
            lastError = "Bluetooth device is no longer available"
            return false
        }
        if (!begin("pair", device, 70000, null))
            return false

        pairProc.targetAddress = addressOf(device)
        pairProc.commandSent = false
        pairProc.pairSucceeded = false
        pairProc.connectionSent = false
        pairProc.connectionSucceeded = false
        pairProc.quitSent = false
        pairProc.command = ["bluetoothctl", "--agent", "auto"]
        pairProc.running = true
        return true
    }

    function connectDevice(device) {
        if (device && device.connected) {
            refreshDevices()
            return true
        }
        return runDeviceOperation("connect", device)
    }

    function disconnectDevice(device) {
        if (device && !device.connected) {
            refreshDevices()
            return true
        }
        return runDeviceOperation("disconnect", device)
    }

    function forget(device) {
        if (device && !device.paired && !device.connected) {
            refreshDevices()
            return true
        }
        return runDeviceOperation("forget", device)
    }

    function toggleScan() {
        if (!adapter) {
            lastError = "No Bluetooth adapter is available"
            return false
        }
        if (isBusy)
            return rejectBusy()

        lateScanGuard.stop()
        awaitingLateDiscovery = false
        expectedDiscovery = !adapter.discovering
        const operation = expectedDiscovery ? "scan-start" : "scan-stop"
        const targetAdapter = adapter
        if (!begin(operation, null, 5000, targetAdapter))
            return false

        if (expectedDiscovery) {
            ownsDiscovery = true
            ownedAdapter = targetAdapter
            stopAttempts = 0
        } else if (ownedAdapter === targetAdapter) {
            stopAttempts = 1
        }
        targetAdapter.discovering = expectedDiscovery
        Qt.callLater(root.checkPending)
        return true
    }

    function pairingError(output) {
        const cleanOutput = String(output || "").replace(/\x1b\[[0-9;]*m/g, "")
        if (/Authentication(?:Rejected|Failed)|Authentication (?:Rejected|Failed)/i.test(cleanOutput))
            return "Pairing was rejected. Put the device in pairing mode and try again."
        if (/not available|not found/i.test(cleanOutput))
            return "The Bluetooth device is no longer available. Scan again and retry."

        const lines = cleanOutput.trim().split("\n")
        for (let i = lines.length - 1; i >= 0; i--) {
            const line = lines[i].trim()
            if (/failed|authentication|rejected|not available/i.test(line))
                return line.replace(/^Failed to pair:\s*/i, "Pairing failed: ")
        }
        return "Pairing failed. Put the device in pairing mode and try again."
    }

    function connectionError(output) {
        const cleanOutput = String(output || "").replace(/\x1b\[[0-9;]*m/g, "")
        const lines = cleanOutput.trim().split("\n")
        for (let i = lines.length - 1; i >= 0; i--) {
            const line = lines[i].trim()
            if (/failed to connect|connection failed/i.test(line))
                return line.replace(/^Failed to connect:\s*/i, "Connecting after pairing failed: ")
        }
        return "The headset paired successfully, but could not connect."
    }

    function handlePairOutput(output) {
        if ((pendingOp !== "pair" && pendingOp !== "connect")
                || pendingAddress !== pairProc.targetAddress)
            return

        const cleanOutput = String(output || "").replace(/\x1b\[[0-9;]*m/g, "")
        if (!pairProc.commandSent && /Agent registered/i.test(cleanOutput)) {
            pairProc.commandSent = true
            pairProc.write("pair " + pairProc.targetAddress + "\n")
        }

        if (!pairProc.pairSucceeded && /Pairing successful/i.test(cleanOutput)) {
            pairProc.pairSucceeded = true
            pendingOp = "connect"
            transitionSeen = false
            operationTimeout.interval = 25000
            operationTimeout.restart()
            if (pendingDevice)
                pendingDevice.trusted = true
            pairProc.write("trust " + pairProc.targetAddress + "\n")
            postPairConnectTimer.restart()
            refreshDevices()
        } else if (pairProc.pairSucceeded
                   && !pairProc.connectionSucceeded
                   && /Connection successful/i.test(cleanOutput)) {
            pairProc.connectionSucceeded = true
            if (!pairProc.quitSent) {
                pairProc.quitSent = true
                pairProc.write("quit\n")
            }
        } else if (!pairProc.quitSent
                   && /Failed to pair|Failed to connect|Device .* not available/i.test(cleanOutput)) {
            pairProc.quitSent = true
            pairProc.write("quit\n")
        }
    }

    Process {
        id: pairProc
        property string targetAddress: ""
        property bool commandSent: false
        property bool pairSucceeded: false
        property bool connectionSent: false
        property bool connectionSucceeded: false
        property bool quitSent: false
        running: false
        stdinEnabled: true
        stdout: StdioCollector {
            id: pairStdout
            waitForEnd: false
            onDataChanged: root.handlePairOutput(text)
        }
        stderr: StdioCollector {
            id: pairStderr
            waitForEnd: false
        }

        onExited: {
            if ((root.pendingOp !== "pair" && root.pendingOp !== "connect")
                    || root.pendingAddress !== targetAddress)
                return

            const output = pairStdout.text + "\n" + pairStderr.text
            if (connectionSucceeded
                    || (root.pendingDevice && root.pendingDevice.connected)) {
                root.finish("")
                return
            }
            if (pairSucceeded)
                return root.finish(root.connectionError(output))
            root.finish(root.pairingError(output))
        }
    }

    Timer {
        id: postPairConnectTimer
        interval: 750
        repeat: false
        onTriggered: {
            if (root.pendingOp !== "connect" || !pairProc.running
                    || pairProc.connectionSent)
                return
            pairProc.connectionSent = true
            pairProc.write("connect " + pairProc.targetAddress + "\n")
        }
    }

    Timer {
        id: operationTimeout
        repeat: false
        onTriggered: {
            let message = root.operationLabel() + " timed out"
            if ((root.pendingOp === "pair" || root.pendingOp === "connect")
                    && pairProc.running) {
                const output = pairStdout.text + "\n" + pairStderr.text
                console.warn("[BluetoothActions] Bluetooth operation timed out:", output)
                message = root.pendingOp === "connect"
                    ? "The headset paired, but connecting timed out."
                    : pairProc.commandSent
                        ? "The headset did not complete pairing before BlueZ's 60-second deadline."
                        : "Could not start the Bluetooth pairing agent."
                pairProc.running = false
            }
            if (root.pendingOp === "scan-start") {
                root.awaitingLateDiscovery = true
                lateScanGuard.restart()
            }
            root.finish(message)
        }
    }

    Timer {
        id: lateScanGuard
        interval: 30000
        repeat: false
        onTriggered: {
            root.awaitingLateDiscovery = false
            root.ownsDiscovery = false
            root.ownedAdapter = null
            root.stopAttempts = 0
        }
    }

    Timer {
        interval: (root.isBusy || root.isScanning || root.ownedAdapterScanning) ? 1000 : 3000
        running: root.live || root.isBusy || root.ownedAdapterScanning
        repeat: true
        onTriggered: root.checkPending()
    }

    Connections {
        target: root.pendingDevice
        ignoreUnknownSignals: true
        function onConnectedChanged() { root.checkPending() }
        function onPairedChanged() { root.checkPending() }
        function onPairingChanged() { root.checkPending() }
        function onStateChanged() { root.checkPending() }
    }

    Connections {
        target: root.pendingAdapter
        ignoreUnknownSignals: true
        function onDiscoveringChanged() {
            root.checkPending()
        }
    }

    Connections {
        target: root.ownedAdapter
        ignoreUnknownSignals: true
        function onDiscoveringChanged() {
            if (root.ownsDiscovery && root.ownedAdapter && root.ownedAdapter.discovering) {
                root.awaitingLateDiscovery = false
                lateScanGuard.stop()
            }
            root.stopOwnedDiscoveryIfIdle()
        }
    }

    Connections {
        target: root.adapter
        ignoreUnknownSignals: true
        function onDevicesChanged() { root.refreshDevices() }
    }

    Connections {
        target: Bluetooth.devices
        ignoreUnknownSignals: true
        function onValuesChanged() { root.refreshDevices() }
    }
}
