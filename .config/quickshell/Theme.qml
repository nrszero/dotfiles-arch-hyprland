import QtQuick
import Quickshell
import QtCore
import Quickshell.Io

Item {
    id: theme

    // --- COLORS (Nord Palette) ---
    property color background: "#33242933" // Dark grey with transparency
    property color surface:    "#333b4252" // Lighter grey for "Cards"
    property color text:       "#eceff4"   // White-ish text
    property color subText:    "#d8dee9"   // Slightly dimmer text
    property color accent:     "#5e81ac"   // Cyan/Blue accent
    property color urgent:     "#bf616a"   // Red for errors/power
    property color success:    "#a3be8c"   // Green
    property color borderColor: "#1a88c0d0" // Subtle border for glass look
    property url wallpaper: ""

    // --- GEOMETRY ---
    property int radius: 12        // A bit sharper looks more "tech" than 15
    property int spacing: 10
    property int padding: 12
    property int borderWidth: 2

    // --- FONTS ---
    property string fontFace: "JetBrainsMono Nerd Font"
    property int fontSizeSm: 12
    property int fontSizeMd: 16
    property int fontSizeLg: 18
    property int fontSizeXl: 24
    property int fontSizeXXl: 30

    // --- DYNAMIC THEMING ---
    FileView {
        id: walColors
        path: StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.cache/wal/colors.json"
        
        // Tells Quickshell to monitor the file for updates
        watchChanges: true 

        // Pull the new data when Pywal overwrites the file
        onFileChanged: reload() 

        onLoaded: {
            try {
                let pywal = JSON.parse(text())

                let parseHex = function(hexStr, alpha) {
                    let r = parseInt(hexStr.slice(1, 3), 16) / 255.0
                    let g = parseInt(hexStr.slice(3, 5), 16) / 255.0
                    let b = parseInt(hexStr.slice(5, 7), 16) / 255.0
                    return Qt.rgba(r, g, b, alpha)
                }

                theme.text    = pywal.special.foreground
                theme.subText = pywal.special.foreground
                theme.accent  = pywal.colors.color2
                theme.urgent  = pywal.colors.color2
                theme.success = pywal.colors.color2
                theme.borderColor = parseHex(pywal.colors.color6, 0.20)
                theme.background = parseHex(pywal.special.background, 0.20)
                theme.surface    = parseHex(pywal.colors.color0, 0.40)
                theme.wallpaper  = pywal.wallpaper ? ("file://" + pywal.wallpaper) : ""
                
            } catch(e) {
                console.log("[Theme] Failed to parse Pywal colors.json", e)
            }
        }
    }
}
