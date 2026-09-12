import Quickshell
import QtQuick
import Quickshell.Io

Item {
    id: root

    property bool battPresent: false
    property real battLevel: 0
    property bool battCharging: false
    property string battStatus: ""
    property string battName: ""
    property string battModel: ""
    property string battTech: ""
    property int battCycles: -1
    property real energyNowWh: -1
    property real energyFullWh: -1
    property real energyDesignWh: -1
    property real voltageV: -1
    property real powerW: -1
    property real health: -1
    property real hoursLeft: -1
    property string powerProfile: ""

    readonly property int battPct: Math.round(battLevel * 100)
    readonly property int battStep: Math.min(10, Math.max(0, Math.round(battPct / 10)))
    readonly property var idleIcons: [
        0xF008E, 0xF007A, 0xF007B, 0xF007C, 0xF007D,
        0xF007E, 0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079
    ]
    readonly property var chargeIcons: [
        0xF089F, 0xF089C, 0xF0086, 0xF0087, 0xF0088,
        0xF089D, 0xF0089, 0xF089E, 0xF008A, 0xF008B, 0xF0085
    ]

    readonly property string icon: String.fromCodePoint(
        battCharging ? chargeIcons[battStep] : idleIcons[battStep]
    )

    function iconColor(theme) {
        if (battPct <= 20 && !battCharging)
            return theme.urgent
        if (battCharging)
            return theme.accent
        return theme.text
    }

    function statusLabel() {
        if (battCharging)
            return "Charging"
        if (battStatus === "Full")
            return "Full"
        if (battStatus === "Not charging")
            return "Not charging"
        if (battStatus === "Discharging")
            return "Discharging"
        return battStatus || "Unknown"
    }

    function formatHours(h) {
        if (h < 0 || !isFinite(h))
            return ""
        const totalMin = Math.max(0, Math.round(h * 60))
        const hrs = Math.floor(totalMin / 60)
        const mins = totalMin % 60
        if (hrs <= 0)
            return mins + "m"
        if (mins === 0)
            return hrs + "h"
        return hrs + "h " + mins + "m"
    }

    function timeLabel() {
        if (battStatus === "Full")
            return "Fully charged"
        const span = formatHours(hoursLeft)
        if (!span)
            return ""
        return battCharging ? span + " until full" : span + " remaining"
    }

    function profileLabel() {
        switch (powerProfile) {
        case "performance":
            return "Performance"
        case "balanced":
            return "Balanced"
        case "power-saver":
            return "Power saver"
        default:
            return powerProfile
        }
    }

    property int liveWatchers: 0
    readonly property bool live: liveWatchers > 0

    function watch() {
        liveWatchers++
    }

    function unwatch() {
        liveWatchers = Math.max(0, liveWatchers - 1)
    }

    function refresh() {
        if (battProc.running)
            battProc.running = false
        battProc.running = true
        if (profileProc.running)
            profileProc.running = false
        profileProc.running = true
    }

    onLiveChanged: {
        refresh()
        pollTimer.restart()
    }

    function parseNum(v) {
        if (v === undefined || v === null || v === "")
            return NaN
        const n = Number(v)
        return isFinite(n) ? n : NaN
    }

    function applyFields(f) {
        if (f.PRESENT !== "1") {
            root.battPresent = false
            root.battLevel = 0
            root.battCharging = false
            root.battStatus = ""
            root.battName = ""
            root.battModel = ""
            root.battTech = ""
            root.battCycles = -1
            root.energyNowWh = -1
            root.energyFullWh = -1
            root.energyDesignWh = -1
            root.voltageV = -1
            root.powerW = -1
            root.health = -1
            root.hoursLeft = -1
            return
        }

        const cap = parseNum(f.CAPACITY)
        const status = f.STATUS || ""
        const energyNow = parseNum(f.ENERGY_NOW)
        const energyFull = parseNum(f.ENERGY_FULL)
        const energyDesign = parseNum(f.ENERGY_DESIGN)
        const chargeNow = parseNum(f.CHARGE_NOW)
        const chargeFull = parseNum(f.CHARGE_FULL)
        const chargeDesign = parseNum(f.CHARGE_DESIGN)
        const voltage = parseNum(f.VOLTAGE)
        const current = parseNum(f.CURRENT)
        const power = parseNum(f.POWER)
        const cycles = parseNum(f.CYCLES)

        root.battPresent = true
        root.battStatus = status
        root.battCharging = status === "Charging"
        root.battName = f.NAME || ""
        root.battTech = f.TECH || ""
        const maker = f.MANUFACTURER || ""
        const model = f.MODEL || ""
        root.battModel = [maker, model].filter(s => s).join(" ")
        root.battCycles = (isFinite(cycles) && cycles > 0) ? Math.round(cycles) : -1
        root.battLevel = isFinite(cap) ? Math.max(0, Math.min(1, cap / 100)) : 0

        const nowWh = isFinite(energyNow) ? energyNow / 1e6
            : (isFinite(chargeNow) && isFinite(voltage) ? (chargeNow * voltage) / 1e12 : NaN)
        const fullWh = isFinite(energyFull) ? energyFull / 1e6
            : (isFinite(chargeFull) && isFinite(voltage) ? (chargeFull * voltage) / 1e12 : NaN)
        const designWh = isFinite(energyDesign) ? energyDesign / 1e6
            : (isFinite(chargeDesign) && isFinite(voltage) ? (chargeDesign * voltage) / 1e12 : NaN)

        root.energyNowWh = isFinite(nowWh) ? nowWh : -1
        root.energyFullWh = isFinite(fullWh) ? fullWh : -1
        root.energyDesignWh = isFinite(designWh) ? designWh : -1
        root.voltageV = isFinite(voltage) ? voltage / 1e6 : -1

        let watts = isFinite(power) ? power / 1e6 : NaN
        if (!isFinite(watts) && isFinite(voltage) && isFinite(current))
            watts = (voltage * current) / 1e12
        root.powerW = isFinite(watts) ? Math.abs(watts) : -1

        if (isFinite(fullWh) && isFinite(designWh) && designWh > 0)
            root.health = Math.max(0, Math.min(1.2, fullWh / designWh))
        else if (isFinite(chargeFull) && isFinite(chargeDesign) && chargeDesign > 0)
            root.health = Math.max(0, Math.min(1.2, chargeFull / chargeDesign))
        else
            root.health = -1

        if (status === "Full") {
            root.hoursLeft = 0
        } else if (isFinite(watts) && watts > 0.05) {
            if (root.battCharging && isFinite(fullWh) && isFinite(nowWh))
                root.hoursLeft = Math.max(0, (fullWh - nowWh) / watts)
            else if (!root.battCharging && isFinite(nowWh))
                root.hoursLeft = Math.max(0, nowWh / watts)
            else
                root.hoursLeft = -1
        } else {
            root.hoursLeft = -1
        }
    }

    Process {
        id: battProc
        command: ["sh", "-c",
            "pick=\"\"; " +
            "for d in /sys/class/power_supply/*; do " +
            "[ -f \"$d/type\" ] || continue; " +
            "[ \"$(cat \"$d/type\" 2>/dev/null)\" = Battery ] || continue; " +
            "name=$(basename \"$d\"); " +
            "scope=$(cat \"$d/scope\" 2>/dev/null || true); " +
            "if [ \"$scope\" = System ]; then pick=\"$d\"; break; fi; " +
            "case \"$name\" in BAT*|CMB*|BATTERY*|battery*) pick=\"$d\"; break ;; esac; " +
            "[ -n \"$pick\" ] || pick=\"$d\"; " +
            "done; " +
            "if [ -z \"$pick\" ] || [ ! -d \"$pick\" ]; then printf 'PRESENT=0\\n'; exit 0; fi; " +
            "readf() { cat \"$pick/$1\" 2>/dev/null | tr -d '\\n' || true; }; " +
            "printf 'PRESENT=1\\n'; " +
            "printf 'NAME=%s\\n' \"$(basename \"$pick\")\"; " +
            "printf 'STATUS=%s\\n' \"$(readf status)\"; " +
            "printf 'CAPACITY=%s\\n' \"$(readf capacity)\"; " +
            "printf 'ENERGY_NOW=%s\\n' \"$(readf energy_now)\"; " +
            "printf 'ENERGY_FULL=%s\\n' \"$(readf energy_full)\"; " +
            "printf 'ENERGY_DESIGN=%s\\n' \"$(readf energy_full_design)\"; " +
            "printf 'CHARGE_NOW=%s\\n' \"$(readf charge_now)\"; " +
            "printf 'CHARGE_FULL=%s\\n' \"$(readf charge_full)\"; " +
            "printf 'CHARGE_DESIGN=%s\\n' \"$(readf charge_full_design)\"; " +
            "printf 'VOLTAGE=%s\\n' \"$(readf voltage_now)\"; " +
            "printf 'CURRENT=%s\\n' \"$(readf current_now)\"; " +
            "printf 'POWER=%s\\n' \"$(readf power_now)\"; " +
            "printf 'CYCLES=%s\\n' \"$(readf cycle_count)\"; " +
            "printf 'TECH=%s\\n' \"$(readf technology)\"; " +
            "printf 'MANUFACTURER=%s\\n' \"$(readf manufacturer)\"; " +
            "printf 'MODEL=%s\\n' \"$(readf model_name)\""
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = {}
                const lines = text.trim().split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i]
                    const eq = line.indexOf("=")
                    if (eq < 0)
                        continue
                    fields[line.slice(0, eq)] = line.slice(eq + 1)
                }
                root.applyFields(fields)
            }
        }
    }

    Process {
        id: profileProc
        command: ["sh", "-c",
            "p=$(busctl get-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles ActiveProfile 2>/dev/null) " +
            "|| p=$(busctl get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile 2>/dev/null) " +
            "|| true; " +
            "printf '%s\\n' \"$p\""
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const quoted = text.trim().match(/"([^"]+)"/)
                root.powerProfile = quoted ? quoted[1] : ""
            }
        }
    }

    Timer {
        id: pollTimer
        interval: root.live ? 1000 : 15000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
