import QtQuick

Row {
    id: root
    spacing: 20

    property color surfaceColor
    property color textColor
    property color accentColor
    property color errorColor
    property color borderColor
    property string fontFamily

    // REBOOT Text Button (ALL CAPS, foreground color, accent on hover, bold)
    Item {
        width: rebootText.implicitWidth + 6
        height: rebootText.implicitHeight + 6

        Text {
            id: rebootText
            anchors.centerIn: parent
            text: "REBOOT"
            font.family: root.fontFamily
            font.pixelSize: 17
            font.bold: true
            font.letterSpacing: 1.5
            color: rebootArea.containsMouse ? root.accentColor : root.textColor
            renderType: Text.NativeRendering
        }

        MouseArea {
            id: rebootArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sddm.reboot()
        }
    }

    // Vertical Separator (foreground color, bigger)
    Rectangle {
        width: 2
        height: 22
        anchors.verticalCenter: parent.verticalCenter
        color: root.textColor
        opacity: 0.6
    }

    // SHUTDOWN Text Button (ALL CAPS, foreground color normally, red errorColor on hover, bold)
    Item {
        width: shutdownText.implicitWidth + 6
        height: shutdownText.implicitHeight + 6

        Text {
            id: shutdownText
            anchors.centerIn: parent
            text: "SHUTDOWN"
            font.family: root.fontFamily
            font.pixelSize: 17
            font.bold: true
            font.letterSpacing: 1.5
            color: shutdownArea.containsMouse ? root.errorColor : root.textColor
            renderType: Text.NativeRendering
        }

        MouseArea {
            id: shutdownArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sddm.powerOff()
        }
    }
}
