import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "hyprvibe.memory"

  property string memoryText: "— GB"
  property string memoryTooltip: "Memory"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: memProc
    command: ["bash", "-c", "awk '/MemTotal:/ {total=$2} /MemAvailable:/ {avail=$2} /SwapTotal:/ {stotal=$2} /SwapFree:/ {sfree=$2} END {used=(total-avail)/(1024*1024); tot=total/(1024*1024); sused=(stotal-sfree)/(1024*1024); stot=stotal/(1024*1024); printf \"%.1f GB|Used: %.1fG / %.1fG\\nSwap: %.1fG / %.1fG\\n\", used, used, tot, sused, stot}' /proc/meminfo"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var str = text.trim()
        var pipeIdx = str.indexOf("|")
        if (pipeIdx !== -1) {
          root.memoryText = str.substring(0, pipeIdx).trim()
          root.memoryTooltip = str.substring(pipeIdx + 1).trim()
        }
      }
    }
  }

  Timer {
    interval: 3000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      if (!memProc.running) {
        memProc.running = true
      }
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.memoryText
    tooltipText: root.memoryTooltip
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
