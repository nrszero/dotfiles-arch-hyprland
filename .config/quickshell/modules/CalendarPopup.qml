import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Wayland

PopupWindow {
    id: root

    required property var theme
    
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.margins.left: -6

    implicitWidth: 320
    implicitHeight: 420
    visible: false
    color: "transparent"

    HoverHandler { id: popupHover }

    Timer {
        id: hideTimer
        interval: 3000
        repeat: false
        onTriggered: root.visible = false
    }

    Connections { 
        target: popupHover
        function onHoveredChanged() { 
            if (popupHover.hovered) hideTimer.stop()
            else hideTimer.restart()
        }
    }

    // --- Live Time & Date Properties ---
    property string timeString: ""
    property string dateString: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let d = new Date()
            // Formats: "10:45:30 AM" and "Saturday, June 27"
            timeString = Qt.formatTime(d, "h:mm:ss AP")
            dateString = Qt.formatDate(d, "dddd, MMMM d")
        }
    }

    // --- Calendar Logic ---
    property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    property var dayNames: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    property int currentMonth: new Date().getMonth()
    property int currentYear: new Date().getFullYear()
    
    // Static references to "today" to highlight the correct box
    property int todayDate: new Date().getDate()
    property int thisMonth: new Date().getMonth()
    property int thisYear: new Date().getFullYear()

    ListModel { id: daysModel }

    function getDaysInMonth(month, year) {
        return new Date(year, month + 1, 0).getDate()
    }

    function getFirstDayOfMonth(month, year) {
        return new Date(year, month, 1).getDay()
    }

    function updateCalendar() {
        daysModel.clear()
        let daysInMonth = getDaysInMonth(currentMonth, currentYear)
        let firstDay = getFirstDayOfMonth(currentMonth, currentYear)
        let daysInPrevMonth = getDaysInMonth(currentMonth - 1, currentYear)

        // Previous month filler days (dimmed)
        for (let i = firstDay - 1; i >= 0; i--) {
            daysModel.append({ dayNumber: daysInPrevMonth - i, isCurrentMonth: false, isToday: false })
        }
        // Current month days
        for (let i = 1; i <= daysInMonth; i++) {
            let isTod = (i === todayDate && currentMonth === thisMonth && currentYear === thisYear)
            daysModel.append({ dayNumber: i, isCurrentMonth: true, isToday: isTod })
        }
        // Next month filler days (dimmed)
        let remaining = 42 - daysModel.count // 6 rows of 7
        for (let i = 1; i <= remaining; i++) {
            daysModel.append({ dayNumber: i, isCurrentMonth: false, isToday: false })
        }
    }

    function prevMonth() {
        if (currentMonth === 0) { currentMonth = 11; currentYear-- } 
        else { currentMonth-- }
        updateCalendar()
    }

    function nextMonth() {
        if (currentMonth === 11) { currentMonth = 0; currentYear++ } 
        else { currentMonth++ }
        updateCalendar()
    }

    onVisibleChanged: {
        if (visible) {
            hideTimer.stop()
            // Reset to current real-world month every time it opens
            currentMonth = thisMonth
            currentYear = thisYear
            updateCalendar()
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        color: theme.background
        radius: theme.radius
        border.width: theme.borderWidth
        border.color: theme.borderColor
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ---------------------------------------------------------
            // Top Section: Live Clock & Date
            // ---------------------------------------------------------
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: root.timeString
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: 32 // Massive font for the clock
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: root.dateString
                    color: theme.accent
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 2
                color: theme.borderColor
                opacity: 0.5
            }

            // ---------------------------------------------------------
            // Calendar Header: Month/Year and Navigation
            // ---------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "󰅁" // Left arrow icon
                    color: prevHover.hovered ? theme.accent : theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeLg
                    HoverHandler { id: prevHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: prevMonth()
                    }
                }

                Text {
                    text: monthNames[currentMonth] + " " + currentYear
                    color: theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeMd
                    font.bold: true
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "󰅂" // Right arrow icon
                    color: nextHover.hovered ? theme.accent : theme.text
                    font.family: theme.fontFace
                    font.pixelSize: theme.fontSizeLg
                    HoverHandler { id: nextHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: nextMonth()
                    }
                }
            }

            // ---------------------------------------------------------
            // Calendar Grid: Days of Week
            // ---------------------------------------------------------
            GridLayout {
                columns: 7
                columnSpacing: 6
                rowSpacing: 6
                Layout.alignment: Qt.AlignHCenter

                // Header Row (Su Mo Tu We...)
                Repeater {
                    model: root.dayNames
                    Text {
                        text: modelData
                        color: theme.subText
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeSm
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.preferredWidth: 32
                    }
                }

                // Grid Body (The Dates)
                Repeater {
                    model: daysModel
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 16 // Makes it a perfect circle
                        
                        // Highlight today with the accent color
                        color: isToday ? theme.accent : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: dayNumber
                            // Inverse text color if today is highlighted. Dim if previous/next month.
                            color: isToday ? theme.text : (isCurrentMonth ? theme.text : theme.subText)
                            font.family: theme.fontFace
                            font.pixelSize: theme.fontSizeSm
                            font.bold: isToday
                        }
                    }
                }
            }
            
            Item { Layout.fillHeight: true } // Bottom spacer
        }
    }
}
