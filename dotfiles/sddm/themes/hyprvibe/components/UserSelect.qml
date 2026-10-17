import QtQuick

Item {
    id: root
    width: parent ? parent.width : 200
    height: 44
    z: popup.visible ? 100 : 10

    property var model: userModel
    property int currentIndex: {
        if (!model || model.rowCount() === 0) return 0
        if (model.lastIndex !== undefined && model.lastIndex >= 0 && model.lastIndex < model.rowCount())
            return model.lastIndex
        if (model.lastUser) {
            for (var i = 0; i < model.rowCount(); i++) {
                if (getUserName(i) === model.lastUser) return i
            }
        }
        return 0
    }

    function getUserName(idx) {
        if (!model || idx < 0 || idx >= model.rowCount()) return ""
        var mi = model.index(idx, 0)
        return String(model.data(mi, 257) || model.data(mi, Qt.UserRole + 1) || "")
    }

    function getInvertedIndex(visualIdx) {
        if (!model || model.rowCount() === 0) return 0
        return model.rowCount() - 1 - visualIdx
    }

    // Only show actual username (no people names)
    readonly property string currentUserName: getUserName(currentIndex)
    readonly property string currentDisplayName: currentUserName

    readonly property bool isOpen: popup.visible
    function toggle() { popup.visible = !popup.visible }
    function open() { popup.visible = true }
    function close() { popup.visible = false }

    property color surfaceColor
    property color textColor
    property color accentColor
    property color mutedColor
    property color borderColor
    property string fontFamily

    // Box with 1px border, no background change on hover, both icon & text hover to accent
    Rectangle {
        id: headerBox
        anchors.fill: parent
        radius: 0
        color: "transparent"
        border.width: 1
        border.color: headerArea.containsMouse || popup.visible ? root.accentColor : root.borderColor

        Row {
            anchors.centerIn: parent
            width: Math.min(parent.width - 16, implicitWidth)
            spacing: 8

            // Icon: hovers to accent
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                font.family: root.fontFamily
                font.pixelSize: 16
                color: headerArea.containsMouse ? root.accentColor : root.textColor
            }

            // Username: hovers to accent, elides if long
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, headerBox.width - 50)
                text: root.currentUserName
                font.family: root.fontFamily
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
                color: headerArea.containsMouse ? root.accentColor : root.textColor
                renderType: Text.NativeRendering
            }
        }

        MouseArea {
            id: headerArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggle()
        }
    }

    // Dropdown User List Popup (opens UPWARDS, sequence inverted with selected nearest to box)
    Rectangle {
        id: popup
        visible: false
        width: parent.width
        height: Math.min(Math.max(1, (root.model ? root.model.rowCount() : 1)) * 38 + 2, 160)
        anchors.bottom: headerBox.top
        anchors.bottomMargin: 4
        anchors.left: headerBox.left
        radius: 0
        color: root.surfaceColor
        border.color: root.accentColor
        border.width: 1
        clip: true

        ListView {
            id: userList
            anchors.fill: parent
            anchors.margins: 1
            model: root.model
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: itemRect
                width: userList.width
                height: 38
                radius: 0
                color: "transparent"

                readonly property int modelIdx: root.getInvertedIndex(index)
                readonly property color itemStateColor: itemArea.containsMouse ? root.accentColor : (modelIdx === root.currentIndex ? root.textColor : root.mutedColor)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelIdx === root.currentIndex ? "●" : "○"
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        color: itemRect.itemStateColor
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 34
                        text: String(root.getUserName(modelIdx) || ("user" + modelIdx))
                        font.family: root.fontFamily
                        font.pixelSize: 14
                        font.bold: modelIdx === root.currentIndex
                        elide: Text.ElideRight
                        color: itemRect.itemStateColor
                        renderType: Text.NativeRendering
                    }
                }

                MouseArea {
                    id: itemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.currentIndex = modelIdx
                        root.close()
                    }
                }
            }
        }
    }
}
