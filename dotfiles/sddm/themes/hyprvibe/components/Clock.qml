import QtQuick

Column {
    id: root
    spacing: 8

    property string timeFormat: "hh:mm"
    property string dateFormat: "dddd, d MMMM yyyy"
    property color textColor
    property color mutedColor
    property string fontFamily

    property date currentDate: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentDate = new Date()
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(root.currentDate, root.timeFormat)
        font.family: root.fontFamily
        font.pixelSize: 64
        font.bold: true
        color: root.textColor
        renderType: Text.NativeRendering
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(root.currentDate, root.dateFormat)
        font.family: root.fontFamily
        font.pixelSize: 18
        color: root.mutedColor
        renderType: Text.NativeRendering
    }
}
