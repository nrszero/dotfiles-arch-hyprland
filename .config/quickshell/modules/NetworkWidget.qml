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
    property int liveWatchers: 0
    readonly property bool live: liveWatchers > 0
    
    // 0: Disconnected/Error, 1: Connected, 2: Connecting
    property int connectionState: 0
    property string rawOutput: ""
    
    property ListModel wifiModel: ListModel {}
    property bool isScanning: false
    property bool isWifiActiveRoute: false
    property string currentWifiSsid: ""
    property int currentWifiSignal: 0
    property var savedWifiNames: ({})
    property int savedWifiRevision: 0
    property string pendingOp: ""
    property string pendingTarget: ""
    property string lastError: ""
    readonly property bool isBusy: pendingOp !== ""

    function watch() {
        liveWatchers++
        if (liveWatchers === 1) {
            refreshStatus()
            forceScan()
            refreshSaved()
        }
    }

    function unwatch() {
        liveWatchers = Math.max(0, liveWatchers - 1)
    }

    function clearError() {
        lastError = ""
    }

    function operationLabel(operation) {
        switch (operation || pendingOp) {
        case "connect": return "Connecting"
        case "disconnect": return "Disconnecting"
        case "forget": return "Forgetting"
        default: return "Working"
        }
    }

    function isPendingTarget(target, operation) {
        return isBusy && pendingTarget === target && (!operation || pendingOp === operation)
    }

    function errorDetail(stdoutText, stderrText) {
        const text = String(stderrText || stdoutText || "").trim()
        if (text === "")
            return ""
        const lines = text.split("\n")
        return lines[lines.length - 1].replace(/^Error:\s*/i, "").trim()
    }

    function operationError(operation, stdoutText, stderrText) {
        const detail = errorDetail(stdoutText, stderrText)
        const lower = detail.toLowerCase()

        if (operation === "connect") {
            if (/802-11-wireless-security\.psk.*invalid|psk.*property is invalid|invalid.*psk/.test(lower))
                return "That Wi-Fi password is not valid. Enter 8–63 characters."
            if (/secrets were required|no secrets|wrong password|incorrect password|invalid.*password|password.*invalid/.test(lower))
                return "Incorrect Wi-Fi password. Check it and try again."
            if (/network could not be found|no network with ssid|not available/.test(lower))
                return "That Wi-Fi network is no longer available. Scan and try again."
            if (/activation failed|failed to activate|connection attempt timed out/.test(lower))
                return "Could not connect to " + (pendingTarget || "the Wi-Fi network")
                    + ". Check the password and signal, then try again."
        }

        if (detail === "")
            return operationLabel(operation) + " failed"
        return operationLabel(operation) + " failed: "
            + detail.replace(/^Connection activation failed:\s*/i, "")
    }

    function reportBackgroundError(summary, stdoutText, stderrText) {
        if (!live || lastError !== "")
            return
        const detail = errorDetail(stdoutText, stderrText)
        lastError = detail === "" ? summary : summary + ": " + detail
    }

    function isSavedWifi(ssid) {
        const _rev = savedWifiRevision
        return !!(ssid && root.savedWifiNames[ssid])
    }

    function savedWifiId(ssid) {
        const _rev = savedWifiRevision
        return (ssid && root.savedWifiNames[ssid]) ? root.savedWifiNames[ssid] : ""
    }

    // Layout sizing - adopt the size of the icon text
    implicitWidth: 30
    implicitHeight: 30
    
    // -------------------------------------------------------------------------
    // Backend Logic: Auto-Detect Interfaces
    // -------------------------------------------------------------------------
    Process {
        id: ethDetector
        command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE d | grep ethernet | head -n 1 | cut -d: -f1"]
        running: true
        stdout: StdioCollector {
            id: ethDetectorOut
            onStreamFinished: {
                const eth = this.text.trim();
                if (eth !== "") {
                    root.interfaceName = eth;
                    // Trigger an immediate check once found
                    nmcliCmd.running = true;
                }
            }
        }
        stderr: StdioCollector { id: ethDetectorErr }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.reportBackgroundError("Could not detect the Ethernet interface",
                                           ethDetectorOut.text, ethDetectorErr.text)
        }
    }

    Process {
        id: wifiDetector
        command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE d | grep wifi | head -n 1 | cut -d: -f1"]
        running: true
        stdout: StdioCollector {
            id: wifiDetectorOut
            onStreamFinished: {
                const wifi = this.text.trim();
                if (wifi !== "") {
                    root.wifiInterfaceName = wifi;
                    wifiActiveCmd.running = true;
                    routeCheckCmd.running = true;
                    if (root.live) {
                        wifiScanCmd.running = true;
                        savedWifiCmd.running = true;
                    }
                }
            }
        }
        stderr: StdioCollector { id: wifiDetectorErr }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.reportBackgroundError("Could not detect the Wi-Fi interface",
                                           wifiDetectorOut.text, wifiDetectorErr.text)
        }
    }

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
            id: ethernetStatusOut
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
        stderr: StdioCollector { id: ethernetStatusErr }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.reportBackgroundError("Could not refresh Ethernet status",
                                           ethernetStatusOut.text, ethernetStatusErr.text)
        }
    }
    
    // -------------------------------------------------------------------------
    // Backend Logic: Wi-Fi Active Connection Polling
    // -------------------------------------------------------------------------
    Process {
        id: wifiActiveCmd
        // FIX: using -g gets ONLY the value, removing the "GENERAL.CONNECTION:" prefix
        command: ["nmcli", "-g", "GENERAL.CONNECTION", "device", "show", root.wifiInterfaceName]
        running: false

        stdout: StdioCollector {
            id: wifiActiveOut
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
        stderr: StdioCollector { id: wifiActiveErr }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.reportBackgroundError("Could not refresh Wi-Fi status",
                                           wifiActiveOut.text, wifiActiveErr.text)
        }
    }
    
    // -------------------------------------------------------------------------
    // Backend Logic: Check Default Route (Active vs Inactive)
    // -------------------------------------------------------------------------
    Process {
        id: routeCheckCmd
        // Using 'ip route' is the standard, most reliable way to check kernel routing
        command: ["ip", "route", "show", "default"]
        running: false

        stdout: StdioCollector {
            id: routeCheckOut
            onStreamFinished: {
                const output = this.text.trim();
                let isActive = false;
                
                if (output.length > 0) {
                    const lines = output.split("\n");
                    
                    // The first line is the primary default route (lowest metric)
                    const primaryRoute = lines[0].trim();
                    const parts = primaryRoute.split(/\s+/); // Split by spaces
                    
                    const devIndex = parts.indexOf("dev");
                    
                    // Check if 'dev' exists in the string and the next word is our interface
                    if (devIndex !== -1 && parts[devIndex + 1] === root.wifiInterfaceName) {
                        isActive = true;
                    }
                }
                
                root.isWifiActiveRoute = isActive;
            }
        }
        stderr: StdioCollector { id: routeCheckErr }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.reportBackgroundError("Could not refresh the default route",
                                           routeCheckOut.text, routeCheckErr.text)
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

        stdout: StdioCollector { id: wifiScanOut }
        stderr: StdioCollector { id: wifiScanErr }
        onExited: (exitCode, exitStatus) => {
            root.isScanning = false
            if (exitCode === 0)
                root.applyWifiScan(wifiScanOut.text)
            else
                root.reportBackgroundError("Wi-Fi scan failed",
                                           wifiScanOut.text, wifiScanErr.text)
        }
    }

    function splitTerse(line) {
        const fields = []
        let field = ""
        let escaped = false
        for (let i = 0; i < line.length; i++) {
            const ch = line[i]
            if (escaped) {
                field += ch
                escaped = false
            } else if (ch === "\\") {
                escaped = true
            } else if (ch === ":") {
                fields.push(field)
                field = ""
            } else {
                field += ch
            }
        }
        if (escaped)
            field += "\\"
        fields.push(field)
        return fields
    }

    function applyWifiScan(output) {
        const networks = {}
        const lines = String(output || "").trim().split("\n")
        let activeSignal = 0

        for (let i = 0; i < lines.length; i++) {
            if (lines[i] === "")
                continue
            const parts = splitTerse(lines[i])
            if (parts.length < 4 || parts[0] === "")
                continue

            const ssid = parts[0]
            const signalLevel = parseInt(parts[1], 10) || 0
            const inUse = parts[3] === "*"
            if (inUse)
                activeSignal = signalLevel

            if (!networks[ssid] || inUse
                    || (!networks[ssid].inUse && signalLevel > networks[ssid].signal)) {
                networks[ssid] = {
                    ssid: ssid,
                    signal: signalLevel,
                    security: parts[2],
                    inUse: inUse || !!(networks[ssid] && networks[ssid].inUse)
                }
            }
        }

        const rows = []
        for (const key in networks)
            rows.push(networks[key])
        rows.sort((a, b) => (b.inUse ? 1000 : b.signal) - (a.inUse ? 1000 : a.signal))

        wifiModel.clear()
        for (let i = 0; i < rows.length; i++)
            wifiModel.append(rows[i])
        currentWifiSignal = activeSignal
    }

    // -------------------------------------------------------------------------
    // Backend Logic: Wi-Fi Connecting & Disconnecting
    // -------------------------------------------------------------------------
    Process {
        id: savedWifiCmd
        command: ["nmcli", "-t", "-f", "NAME,TYPE,TIMESTAMP", "connection", "show"]
        running: false

        stdout: StdioCollector { id: savedWifiOut }
        stderr: StdioCollector { id: savedWifiErr }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.applySavedWifi(savedWifiOut.text)
            else
                root.reportBackgroundError("Could not refresh saved Wi-Fi networks",
                                           savedWifiOut.text, savedWifiErr.text)
        }
    }

    function applySavedWifi(output) {
        const names = {}
        const lines = String(output || "").trim().split("\n")
        for (let i = 0; i < lines.length; i++) {
            if (lines[i] === "")
                continue
            const parts = splitTerse(lines[i])
            if (parts.length < 3 || (parts[1] !== "802-11-wireless" && parts[1] !== "wifi"))
                continue
            const timestamp = parseInt(parts[2], 10) || 0
            if (parts[0] !== "" && timestamp > 0)
                names[parts[0]] = parts[0]
        }
        savedWifiNames = names
        savedWifiRevision++
    }

    Process {
        id: wifiUpCmd
        property string targetId: ""
        command: ["nmcli", "connection", "up", "id", targetId]
        running: false
        stdout: StdioCollector { id: wifiUpOut }
        stderr: StdioCollector { id: wifiUpErr }
        onExited: (exitCode, exitStatus) =>
            root.operationExited("connect", exitCode, wifiUpOut.text, wifiUpErr.text)
    }

    Process {
        id: wifiConnectCmd
        property string targetSsid: ""
        property string password: ""
        
        command: password === "" 
                 ? ["nmcli", "dev", "wifi", "connect", targetSsid] 
                 : ["nmcli", "dev", "wifi", "connect", targetSsid, "password", password]
        running: false
        stdout: StdioCollector { id: wifiConnectOut }
        stderr: StdioCollector { id: wifiConnectErr }
        onExited: (exitCode, exitStatus) =>
            root.operationExited("connect", exitCode, wifiConnectOut.text, wifiConnectErr.text)
    }
    
    Process {
        id: wifiDisconnectCmd
        command: ["nmcli", "device", "disconnect", root.wifiInterfaceName]
        running: false
        stdout: StdioCollector { id: wifiDisconnectOut }
        stderr: StdioCollector { id: wifiDisconnectErr }
        onExited: (exitCode, exitStatus) =>
            root.operationExited("disconnect", exitCode,
                                 wifiDisconnectOut.text, wifiDisconnectErr.text)
    }
    
    Process {
        id: wifiForgetCmd
        property string targetId: ""
        command: ["nmcli", "connection", "delete", targetId]
        running: false
        stdout: StdioCollector { id: wifiForgetOut }
        stderr: StdioCollector { id: wifiForgetErr }
        onExited: (exitCode, exitStatus) =>
            root.operationExited("forget", exitCode, wifiForgetOut.text, wifiForgetErr.text)
    }
    
    function connectToWifi(ssid, password) {
        if (!beginOperation("connect", ssid))
            return false
        if ((password === undefined || password === "") && root.savedWifiId(ssid) !== "") {
            wifiUpCmd.targetId = root.savedWifiId(ssid);
            wifiUpCmd.running = true;
            return true;
        }
        wifiConnectCmd.targetSsid = ssid;
        wifiConnectCmd.password = password;
        wifiConnectCmd.running = true;
        return true
    }
    
    function disconnectWifi() {
        if (!beginOperation("disconnect", root.currentWifiSsid || root.wifiInterfaceName))
            return false
        wifiDisconnectCmd.running = true;
        return true
    }
    
    function forgetWifi(ssid) {
        const id = (ssid && root.savedWifiId(ssid) !== "") ? root.savedWifiId(ssid) : (ssid || root.currentWifiSsid)
        if (!id) {
            lastError = "No saved Wi-Fi network was selected"
            return false
        }
        if (!beginOperation("forget", ssid || root.currentWifiSsid || id))
            return false
        wifiForgetCmd.targetId = id
        wifiForgetCmd.running = true
        return true
    }

    function beginOperation(operation, target) {
        if (isBusy) {
            lastError = operationLabel() + " is already in progress"
            return false
        }
        clearError()
        pendingOp = operation
        pendingTarget = target || ""
        operationTimeout.restart()
        return true
    }

    function operationExited(operation, exitCode, stdoutText, stderrText) {
        if (pendingOp !== operation)
            return

        operationTimeout.stop()
        if (exitCode !== 0) {
            console.warn("[NetworkWidget]", operation, "failed:",
                         String(stderrText || stdoutText || "").trim())
            lastError = operationError(operation, stdoutText, stderrText)
        }

        const completedOperation = pendingOp
        pendingOp = ""
        pendingTarget = ""
        refreshStatus()
        if (completedOperation === "connect" || completedOperation === "forget")
            refreshSaved()
        forceScan()
        followupRefresh.restart()
    }
    
    function forceScan() {
        if (wifiInterfaceName !== "" && !wifiScanCmd.running)
            wifiScanCmd.running = true
    }

    function refreshStatus() {
        if (interfaceName === "" && !ethDetector.running)
            ethDetector.running = true
        if (wifiInterfaceName === "" && !wifiDetector.running)
            wifiDetector.running = true
        if (interfaceName !== "" && !nmcliCmd.running)
            nmcliCmd.running = true
        if (wifiInterfaceName !== "" && !wifiActiveCmd.running)
            wifiActiveCmd.running = true
        if (wifiInterfaceName !== "" && !routeCheckCmd.running)
            routeCheckCmd.running = true
    }

    function refreshSaved() {
        if (wifiInterfaceName !== "" && !savedWifiCmd.running)
            savedWifiCmd.running = true
    }

    function operationTimedOut() {
        const operation = pendingOp
        if (operation === "")
            return

        if (wifiUpCmd.running)
            wifiUpCmd.running = false
        if (wifiConnectCmd.running)
            wifiConnectCmd.running = false
        if (wifiDisconnectCmd.running)
            wifiDisconnectCmd.running = false
        if (wifiForgetCmd.running)
            wifiForgetCmd.running = false

        lastError = operationLabel(operation) + " timed out"
        pendingOp = ""
        pendingTarget = ""
        refreshStatus()
        if (operation === "connect" || operation === "forget")
            refreshSaved()
        forceScan()
        followupRefresh.restart()
    }

    Timer {
        interval: root.live ? 3000 : 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshStatus()
    }

    Timer {
        interval: 10000
        running: root.live
        repeat: true
        onTriggered: root.forceScan()
    }

    Timer {
        interval: 30000
        running: root.live
        repeat: true
        onTriggered: root.refreshSaved()
    }

    Timer {
        interval: root.live ? 10000 : 60000
        running: root.interfaceName === "" || root.wifiInterfaceName === ""
        repeat: true
        onTriggered: root.refreshStatus()
    }

    Timer {
        id: operationTimeout
        interval: 15000
        repeat: false
        onTriggered: root.operationTimedOut()
    }

    Timer {
        id: followupRefresh
        interval: 1500
        repeat: false
        onTriggered: {
            root.refreshStatus()
            if (root.live)
                root.forceScan()
        }
    }
}
