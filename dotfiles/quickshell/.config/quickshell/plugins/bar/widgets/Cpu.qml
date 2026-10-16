import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "hyprvibe.cpu"

  property string cpuFrequency: "— GHz"
  property string cpuUsage: "0%"
  property real prevTotal: 0
  property real prevIdle: 0

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: cpuProc
    command: ["bash", "-c", "awk '/cpu MHz/ {sum+=$4; count++} END {if (count>0) printf \"%.1f GHz\\n\", sum/count/1000}' /proc/cpuinfo; head -n1 /proc/stat"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = text.trim().split("\n")
        if (lines.length >= 1 && lines[0].indexOf("GHz") !== -1) {
          root.cpuFrequency = lines[0].trim()
        }
        if (lines.length >= 2) {
          var parts = lines[1].trim().split(/\s+/)
          var user = Number(parts[1]) || 0
          var nice = Number(parts[2]) || 0
          var sys = Number(parts[3]) || 0
          var idle = Number(parts[4]) || 0
          var iowait = Number(parts[5]) || 0
          var irq = Number(parts[6]) || 0
          var softirq = Number(parts[7]) || 0
          var steal = Number(parts[8]) || 0
          var total = user + nice + sys + idle + iowait + irq + softirq + steal
          var idleAll = idle + iowait
          if (root.prevTotal > 0 && total > root.prevTotal) {
            var diffTotal = total - root.prevTotal
            var diffIdle = idleAll - root.prevIdle
            var usage = Math.round(((diffTotal - diffIdle) / diffTotal) * 100)
            root.cpuUsage = Math.max(0, Math.min(100, usage)) + "%"
          }
          root.prevTotal = total
          root.prevIdle = idleAll
        }
      }
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      if (!cpuProc.running) {
        cpuProc.running = true
      }
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.cpuFrequency
    tooltipText: "Usage: " + root.cpuUsage
    fontBold: false
    fontSize: Style.font.body
    horizontalMargin: 8
    verticalPadding: 2
    fixedHeight: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal

    onPressed: function() {
      Quickshell.execDetached(["bash", "-c", "${TERMINAL:-foot} -e btop"])
    }
  }
}
