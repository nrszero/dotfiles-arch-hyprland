import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Greetd
import Quickshell.Wayland
import Quickshell.Io
import QtQml
import "./modules"

ShellRoot {
    id: root

    property Theme appTheme: Theme { id: theme }
    property var sessionCommand: ["start-hyprland"]
    property var userList: []
    property string lastUser: ""

    function persistLastUser(name) {
        const user = (name || "").trim()
        if (!user)
            return
        lastUserFile.setText(user)
        lastUserFile.waitForJob()
    }

    FileView {
        id: lastUserFile
        path: "/var/tmp/greeter-last-user"
        watchChanges: false
        printErrors: false
        onLoaded: {
            root.lastUser = (text() || "").trim()
        }
        onLoadFailed: root.lastUser = ""
    }

    Process {
        id: userFetch
        running: true
        command: ["bash", "-c", "getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $1 != \"nobody\" { print $1 }'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = this.text.trim()
                const lines = raw ? raw.split("\n") : []
                const list = []
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i])
                        list.push(lines[i])
                }
                list.sort((a, b) => a.localeCompare(b))
                root.userList = list
            }
        }
    }

    Instantiator {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: mainWin
            screen: modelData

            property bool isMain: modelData.x === 0
            property bool isInputReady: false
            property string selectedUser: ""
            property bool userTouched: false
            property string pendingPassword: ""
            property string pendingUsername: ""

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            WlrLayershell.keyboardFocus: isMain ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.layer: WlrLayer.Overlay
            color: "black"

            readonly property bool otherMode: selectedUser === ""
            readonly property bool askingUsername: otherMode && loginState.state === "username"

            function applyDefaultUser() {
                if (userTouched)
                    return
                if (root.userList.indexOf(root.lastUser) !== -1)
                    selectedUser = root.lastUser
                else if (root.userList.length === 1)
                    selectedUser = root.userList[0]
                else
                    selectedUser = ""
            }

            function selectUser(name) {
                userTouched = true
                if (Greetd.state !== GreetdState.Inactive && Greetd.state !== GreetdState.Launched)
                    Greetd.cancelSession()
                pendingPassword = ""
                pendingUsername = ""
                context.clearFeedback()
                loginState.state = "username"
                selectedUser = name
                authStage.text = ""
                authStage.inputField.forceActiveFocus()
            }

            function attemptLogin() {
                const txt = authStage.text.trim()
                if (txt === "")
                    return

                context.clearFeedback()
                if (!otherMode) {
                    if (loginState.state === "username") {
                        pendingPassword = txt
                        pendingUsername = selectedUser
                        Greetd.createSession(selectedUser)
                    } else {
                        Greetd.respond(txt)
                    }
                    return
                }

                if (loginState.state === "username") {
                    pendingUsername = txt
                    Greetd.createSession(txt)
                } else {
                    Greetd.respond(txt)
                }
            }

            function togglePopup(target) {
                let popups = [lockPowerButtonPopup]
                for (let p of popups) {
                    if (p !== target)
                        p.visible = false
                }
                target.visible = !target.visible
            }

            onIsMainChanged: applyDefaultUser()
            Component.onCompleted: applyDefaultUser()
            Connections {
                target: root
                function onUserListChanged() { mainWin.applyDefaultUser() }
                function onLastUserChanged() { mainWin.applyDefaultUser() }
            }

            Connections {
                id: context
                target: Greetd
                enabled: isMain

                property bool showFailure: false
                property bool showLockout: false

                function clearFeedback() {
                    showFailure = false
                    showLockout = false
                }

                function onAuthMessage(message, isError, responseRequired, echo) {
                    console.log("[GREETD] Message:", message, "responseRequired:", responseRequired)
                    context.showFailure = false

                    if (responseRequired) {
                        loginState.state = "password"
                        if (mainWin.pendingPassword !== "") {
                            const pw = mainWin.pendingPassword
                            mainWin.pendingPassword = ""
                            Greetd.respond(pw)
                        } else {
                            authStage.text = ""
                            authStage.inputField.forceActiveFocus()
                        }
                    } else if ((message || "").toLowerCase().includes("locked")) {
                        context.showLockout = true
                    }
                }

                function onAuthFailure(message) {
                    console.log("[GREETD] Failed with message:", message)
                    mainWin.pendingPassword = ""
                    context.showFailure = !context.showLockout

                    loginState.state = "username"
                    authStage.text = ""
                    authStage.inputField.forceActiveFocus()
                }

                function onReadyToLaunch() {
                    context.clearFeedback()
                    root.persistLastUser(Greetd.user || mainWin.pendingUsername || mainWin.selectedUser)
                    Greetd.launch(root.sessionCommand)
                }

                function onError(error) {
                    mainWin.pendingPassword = ""
                    context.showLockout = false
                    context.showFailure = true
                    loginState.state = "username"
                    authStage.text = ""
                    authStage.inputField.forceActiveFocus()
                }
            }

            Item {
                id: loginState
                state: "username"
                states: [
                    State { name: "username" },
                    State { name: "password" }
                ]
            }

            BatteryProc { id: battery }

            Item {
                anchors.fill: parent
                clip: true

                Image {
                    id: wallpaper
                    anchors.fill: parent
                    source: isMain ? "file:///var/tmp/live-wallpaper" : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: 0.5
                }
            }

            Item {
                id: content
                anchors.fill: parent
                anchors.margins: 10
                visible: isMain

                Timer {
                    interval: 500
                    running: isMain && content.visible
                    repeat: true
                    onTriggered: {
                        if (!content.visible)
                            return
                        if (!isInputReady && !authStage.coverItem.activeFocus)
                            authStage.coverItem.forceActiveFocus()
                        else if (isInputReady && !authStage.inputField.activeFocus)
                            authStage.inputField.forceActiveFocus()
                    }
                }

                AuthPill {
                    theme: root.appTheme
                    implicitWidth: timeText.implicitWidth + 20

                    Text {
                        id: timeText
                        anchors.centerIn: parent
                        text: Qt.formatTime(new Date(), "h:mm AP")
                        color: theme.text
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeMd
                        font.bold: true
                    }

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: timeText.text = Qt.formatTime(new Date(), "h:mm AP")
                    }
                }

                AuthPill {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    theme: root.appTheme
                    implicitWidth: infoText.implicitWidth + 20

                    Text {
                        id: infoText
                        anchors.centerIn: parent
                        text: "󰍂 Sign in"
                        color: theme.text
                        font.family: theme.fontFace
                        font.pixelSize: theme.fontSizeMd
                        font.bold: true
                    }
                }

                LockStatusPill {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    theme: root.appTheme
                    battery: battery
                    networkWidget: networkWidget
                    onPowerClicked: mainWin.togglePopup(lockPowerButtonPopup)
                }

                AuthStage {
                    id: authStage
                    anchors.fill: parent
                    theme: root.appTheme
                    inputReady: mainWin.isInputReady
                    coverText: "Press any key to sign in"
                    buttonText: mainWin.askingUsername ? "Next" : "Login"
                    placeholderText: {
                        if (context.showFailure)
                            return "Incorrect Password"
                        if (context.showLockout)
                            return "Account Temporarily Locked"
                        if (mainWin.askingUsername)
                            return "Enter Username"
                        return "Enter Password"
                    }
                    placeholderUrgent: context.showFailure || context.showLockout
                    echoMode: mainWin.askingUsername ? TextInput.Normal : TextInput.Password
                    inputMethodHints: mainWin.askingUsername ? Qt.ImhNone : Qt.ImhSensitiveData
                    onCoverDismissed: {
                        console.log("[Greeter] Cover dismissed via keyboard.")
                        mainWin.isInputReady = true
                    }
                    onSubmitted: mainWin.attemptLogin()
                    onBackRequested: {
                        if (Greetd.state !== GreetdState.Inactive && Greetd.state !== GreetdState.Launched)
                            Greetd.cancelSession()
                        mainWin.pendingPassword = ""
                        mainWin.pendingUsername = ""
                        context.clearFeedback()
                        loginState.state = "username"
                        authStage.text = ""
                        mainWin.isInputReady = false
                    }

                    header: [
                        AuthUserRow {
                            theme: root.appTheme
                            users: root.userList
                            selectedUser: mainWin.selectedUser
                            onUserSelected: (user) => mainWin.selectUser(user)
                        }
                    ]
                }
            }

            Popup {
                id: lockPowerButtonPopup
                x: mainWin.width - width - 10
                y: 50
                width: 400
                height: 260
                padding: 0
                background: Item {}

                contentItem: PowerButtonContent {
                    anchors.fill: parent
                    theme: root.appTheme
                    targetWindow: lockPowerButtonPopup
                }
            }

            NetworkWidget {
                id: networkWidget
            }
        }
    }
}
