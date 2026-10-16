import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "hyprvibe.media"

  property string playbackState: "Pause" // "Play", "Pause", "Stop"
  property string songTitle: ""
  property string songArtist: ""
  property string songFile: ""
  readonly property bool isPlaying: playbackState === "Play"
  readonly property string currentTooltip: {
    if (songTitle !== "") {
      return songArtist !== "" ? (songTitle + " — " + songArtist) : songTitle
    }
    if (songFile !== "") return songFile
    if (playbackState === "Stop") return "MPD Stopped"
    return "MPD"
  }

  implicitWidth: row.implicitWidth
  implicitHeight: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal

  Process {
    id: statusProc
    command: ["bash", "-c", "rmpc status 2>/dev/null; echo '---'; rmpc song 2>/dev/null"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var str = text.trim()
        if (!str) {
          root.playbackState = "Stop"
          return
        }
        var parts = str.split("---")
        if (parts.length >= 1) {
          try {
            var statusJson = JSON.parse(parts[0].trim())
            if (statusJson && statusJson.state) {
              root.playbackState = statusJson.state
            }
          } catch (e) {
            root.playbackState = "Stop"
          }
        }
        if (parts.length >= 2) {
          try {
            var songJson = JSON.parse(parts[1].trim())
            if (songJson) {
              root.songFile = songJson.file || ""
              if (songJson.metadata) {
                root.songTitle = songJson.metadata.title || ""
                root.songArtist = songJson.metadata.artist || ""
              } else {
                root.songTitle = ""
                root.songArtist = ""
              }
            }
          } catch (e2) {
            root.songTitle = ""
            root.songArtist = ""
          }
        }
      }
    }
  }

  Timer {
    interval: 1500
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      if (!statusProc.running) {
        statusProc.running = true
      }
    }
  }

  function triggerAction(action) {
    if (action === "prev") {
      Quickshell.execDetached(["rmpc", "prev"])
    } else if (action === "toggle") {
      root.playbackState = root.isPlaying ? "Pause" : "Play"
      Quickshell.execDetached(["rmpc", "togglepause"])
    } else if (action === "next") {
      Quickshell.execDetached(["rmpc", "next"])
    }
    statusTimer.restart()
  }

  Timer {
    id: statusTimer
    interval: 200
    repeat: false
    onTriggered: {
      statusProc.running = false
      statusProc.running = true
    }
  }

  RowLayout {
    id: row
    anchors.fill: parent
    spacing: 0

    WidgetButton {
      id: prevBtn
      bar: root.bar
      text: "󰒮"
      foreground: ThemeColor.muted
      tooltipText: root.currentTooltip
      fontSize: Style.font.body
      horizontalMargin: 4
      verticalPadding: 2
      fixedHeight: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal
      onPressed: function() { root.triggerAction("prev") }
    }

    WidgetButton {
      id: toggleBtn
      bar: root.bar
      text: root.isPlaying ? "󰏤" : "󰐊"
      foreground: ThemeColor.muted
      tooltipText: root.currentTooltip
      fontSize: Style.font.body
      horizontalMargin: 4
      verticalPadding: 2
      fixedHeight: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal
      onPressed: function() { root.triggerAction("toggle") }
    }

    WidgetButton {
      id: nextBtn
      bar: root.bar
      text: "󰒭"
      foreground: ThemeColor.muted
      tooltipText: root.currentTooltip
      fontSize: Style.font.body
      horizontalMargin: 4
      verticalPadding: 2
      fixedHeight: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal
      onPressed: function() { root.triggerAction("next") }
    }

    Text {
      id: sep
      text: "|"
      color: ThemeColor.muted
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      Layout.alignment: Qt.AlignVCenter
      Layout.leftMargin: 6
      Layout.rightMargin: 8
    }
  }
}
