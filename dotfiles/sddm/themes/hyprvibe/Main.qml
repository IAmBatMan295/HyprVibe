import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Effects
import SddmComponents 2.0
import "components" as Components

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: root.surfaceColor

    // Configuration directly from theme.conf
    readonly property string bgSource: config.background
    readonly property real blurAmount: Math.min(1.0, Math.max(0.0, Number(config.blurRadius) / 100.0))
    readonly property color accentColor: config.accentColor
    readonly property color surfaceColor: config.surfaceColor
    readonly property color textColor: config.textColor
    readonly property color mutedColor: config.mutedColor
    readonly property color errorColor: config.errorColor
    readonly property color borderColor: config.borderColor
    readonly property string fontFamily: config.fontFamily

    property bool loginFailed: false

    Connections {
        target: sddm
        function onLoginFailed() {
            root.loginFailed = true
            passwordInput.text = ""
            passwordInput.focus = true
            shakeAnim.start()
        }
        function onLoginSucceeded() {
            root.loginFailed = false
        }
    }

    Connections {
        target: userSelect
        function onIsOpenChanged() {
            if (userSelect.isOpen) sessionSelect.close()
        }
    }

    Connections {
        target: sessionSelect
        function onIsOpenChanged() {
            if (sessionSelect.isOpen) userSelect.close()
        }
    }

    // Background Image
    Image {
        id: bgImage
        anchors.fill: parent
        source: root.bgSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: false
    }

    // Realtime MultiEffect Blur
    MultiEffect {
        id: bgBlur
        anchors.fill: bgImage
        source: bgImage
        blurEnabled: true
        blur: root.blurAmount
        blurMax: 48
        brightness: -0.15
        contrast: 0.05
    }

    // Scrim overlay for readability
    Rectangle {
        anchors.fill: parent
        color: "#0a0a0f"
        opacity: 0.35
    }

    // Dismiss popups when clicking outside
    MouseArea {
        anchors.fill: parent
        z: 5
        enabled: userSelect.isOpen || sessionSelect.isOpen
        onClicked: {
            userSelect.close()
            sessionSelect.close()
        }
    }

    // Centered Authentication Card (enlarged, translucent with blur, 2px accent border)
    Rectangle {
        id: authCard
        z: 10
        width: 520
        height: cardLayout.implicitHeight + 84
        anchors.centerIn: parent
        radius: 0
        color: Qt.rgba(root.surfaceColor.r, root.surfaceColor.g, root.surfaceColor.b, 0.70)
        border.color: root.accentColor
        border.width: 2

        Column {
            id: cardLayout
            anchors.centerIn: parent
            width: parent.width - 70
            spacing: 28

            // Clock & Date (enlarged fonts)
            Components.Clock {
                anchors.horizontalCenter: parent.horizontalCenter
                textColor: root.textColor
                mutedColor: root.mutedColor
                fontFamily: root.fontFamily
            }

            // User & Session Selectors (side by side, perfectly aligned to password box width)
            Row {
                id: selectorsRow
                width: parent.width
                spacing: 14
                z: (userSelect.isOpen || sessionSelect.isOpen) ? 100 : 5

                Components.UserSelect {
                    id: userSelect
                    width: Math.floor((selectorsRow.width - selectorsRow.spacing) / 2)
                    model: userModel
                    surfaceColor: root.surfaceColor
                    textColor: root.textColor
                    accentColor: root.accentColor
                    mutedColor: root.mutedColor
                    borderColor: root.borderColor
                    fontFamily: root.fontFamily
                }

                Components.SessionSelect {
                    id: sessionSelect
                    width: Math.floor((selectorsRow.width - selectorsRow.spacing) / 2)
                    model: sessionModel
                    surfaceColor: root.surfaceColor
                    textColor: root.textColor
                    accentColor: root.accentColor
                    mutedColor: root.mutedColor
                    borderColor: root.borderColor
                    fontFamily: root.fontFamily
                }
            }

            // Password Input Box (middle-adjusted, bold font, muted 2px border)
            Item {
                id: inputContainer
                width: parent.width
                height: 58
                anchors.horizontalCenter: parent.horizontalCenter

                property bool showPassword: false

                Rectangle {
                    id: inputFrame
                    anchors.fill: parent
                    radius: 0
                    color: "transparent"
                    border.width: 2
                    border.color: root.loginFailed ? root.errorColor : (passwordInput.activeFocus ? root.accentColor : root.mutedColor)

                    Behavior on border.color {
                        ColorAnimation { duration: 150 }
                    }

                    // Left-anchored Lock Icon (muted, foreground on hover)
                    Text {
                        id: lockIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        font.family: root.fontFamily
                        font.pixelSize: 20
                        color: lockArea.containsMouse ? root.textColor : root.mutedColor

                        MouseArea {
                            id: lockArea
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }

                    // Middle-adjusted Password Input (bold font, text spawns from dead center)
                    TextInput {
                        id: passwordInput
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 130
                        horizontalAlignment: TextInput.AlignHCenter
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: inputContainer.showPassword ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        font.family: root.fontFamily
                        font.pixelSize: 20
                        font.bold: true
                        color: root.textColor
                        selectionColor: root.accentColor
                        selectedTextColor: root.surfaceColor
                        clip: true
                        focus: true

                        onTextChanged: {
                            if (root.loginFailed) root.loginFailed = false
                        }

                        Keys.onReturnPressed: root.submitLogin()
                        Keys.onEnterPressed: root.submitLogin()
                    }

                    // Right-anchored Actions (Eye Toggle & Submit Arrow)
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        // Eye reveal password icon button (muted, foreground on hover)
                        Item {
                            id: eyeBtn
                            width: 28
                            height: 28

                            Text {
                                anchors.centerIn: parent
                                text: inputContainer.showPassword ? "󰈈" : "󰈉"
                                font.family: root.fontFamily
                                font.pixelSize: 20
                                color: eyeArea.containsMouse ? root.textColor : root.mutedColor
                            }

                            MouseArea {
                                id: eyeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: inputContainer.showPassword = !inputContainer.showPassword
                            }
                        }

                        // Submit Button (muted, foreground on hover)
                        Item {
                            id: submitBtn
                            width: 28
                            height: 28

                            Text {
                                anchors.centerIn: parent
                                text: "󰁔"
                                font.family: root.fontFamily
                                font.pixelSize: 20
                                color: submitArea.containsMouse ? root.textColor : root.mutedColor
                            }

                            MouseArea {
                                id: submitArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.submitLogin()
                            }
                        }
                    }
                }

                // Shake Animation on Failed Login
                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: inputContainer; property: "x"; from: 0; to: -10; duration: 50; easing.type: Easing.OutQuad }
                    NumberAnimation { target: inputContainer; property: "x"; from: -10; to: 10; duration: 50; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: inputContainer; property: "x"; from: 10; to: -6; duration: 50; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: inputContainer; property: "x"; from: -6; to: 6; duration: 50; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: inputContainer; property: "x"; from: 6; to: 0; duration: 50; easing.type: Easing.OutQuad }
                }
            }

            // Error feedback
            Text {
                id: errorText
                visible: root.loginFailed
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Authentication failed. Try again."
                font.family: root.fontFamily
                font.pixelSize: 13
                color: root.errorColor
                renderType: Text.NativeRendering
            }
        }
    }

    // Action Buttons (Bottom Right, ALL CAPS bold text, separator, bigger)
    Components.ActionButtons {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 38
        surfaceColor: root.surfaceColor
        textColor: root.textColor
        accentColor: root.accentColor
        errorColor: root.errorColor
        borderColor: root.borderColor
        fontFamily: root.fontFamily
    }

    function submitLogin() {
        if (!userSelect.currentUserName) return
        sddm.login(userSelect.currentUserName, passwordInput.text, sessionSelect.currentIndex)
    }

    Component.onCompleted: {
        passwordInput.forceActiveFocus()
    }
}
