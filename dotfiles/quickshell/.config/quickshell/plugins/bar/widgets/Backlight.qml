import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "hyprvibe.backlight"

  property int percent: 40
  property int targetPercent: 40
  readonly property var icons: ["󰃚", "󰃛", "󰃜", "󰃞", "󰃟", "󰃠"]
  readonly property string currentIcon: {
    var p = Math.max(0, Math.min(100, percent))
    var idx = Math.min(icons.length - 1, Math.max(0, Math.floor((p / 100) * (icons.length - 1))))
    return icons[idx]
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Timer {
    id: syncHoldoffTimer
    interval: 800
    repeat: false
    onTriggered: {
      if (!blProc.running) {
        blProc.running = true
      }
    }
  }

  Process {
    id: blProc
    command: ["brightnessctl", "-m", "info"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parts = text.trim().split(",")
        if (parts.length >= 4) {
          var num = parseInt(parts[3].replace("%", ""), 10)
          if (!isNaN(num) && !syncHoldoffTimer.running) {
            root.percent = num
            root.targetPercent = num
          }
        }
      }
    }
  }

  Timer {
    interval: 5000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      if (!syncHoldoffTimer.running && !blProc.running) {
        blProc.running = true
      }
    }
  }

  function adjustBrightness(delta) {
    var step = 1
    var next = Math.max(1, Math.min(100, root.targetPercent + (delta > 0 ? step : -step)))
    root.targetPercent = next
    root.percent = next
    syncHoldoffTimer.restart()
    Quickshell.execDetached(["brightnessctl", "set", root.targetPercent + "%"])
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    fontSize: 16
    text: root.currentIcon
    tooltipText: "Brightness: " + root.percent + "%"

    onWheelMoved: function(delta) {
      root.adjustBrightness(delta)
    }

    onPressed: function(b) {
      if (b === Qt.LeftButton) {
        root.adjustBrightness(1)
      } else if (b === Qt.RightButton) {
        root.adjustBrightness(-1)
      }
    }
  }
}
