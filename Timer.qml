import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Timer: countdown timers and alarms, modelled on xfce4-timer-plugin.
//
//   left click    open the panel
//
// Time field accepts minutes ("5"), "90s", "1h30m", "1:30:00" (h:m:s) or a
// clock time with "@" ("@7:30" = next 07:30 alarm). Each timer can pause,
// restart, repeat, and run a command when it finishes. Timers are kept in
// ~/.local/state/podmod101.timer/timers.json with absolute end times, so
// they survive shell restarts.
Panel {
  id: root
  moduleName: "podmod101.timer"
  ipcTarget: "podmod101.timer"

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/podmod101.timer"
  readonly property string sound: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"

  // { id, name, command, duration (s), repeat, state: running|paused|done,
  //   endsAt (ms, running), left (s, paused) }
  property var timers: []
  property double now: Date.now()
  property string error: ""
  property bool loaded: false

  readonly property color foreground: Color.popups.text
  readonly property color dim: Qt.darker(foreground, 1.4)

  function remaining(t) {
    if (t.state === "running") return Math.max(0, Math.ceil((t.endsAt - now) / 1000))
    if (t.state === "paused") return t.left
    return 0
  }

  function format(sec) {
    var h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60
    var pad = function(n) { return (n < 10 ? "0" : "") + n }
    return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : pad(m) + ":" + pad(s)
  }

  // Seconds from "5", "90s", "1h30m", "1:30:00" or "@7:30"; -1 if unreadable.
  function parseTime(raw) {
    var text = raw.trim().toLowerCase()
    var m
    if ((m = /^@(\d{1,2}):(\d{2})$/.exec(text))) {
      var h = parseInt(m[1]), min = parseInt(m[2])
      if (h > 23 || min > 59) return -1
      var at = new Date()
      at.setHours(h, min, 0, 0)
      if (at.getTime() <= Date.now()) at.setDate(at.getDate() + 1)
      return Math.round((at.getTime() - Date.now()) / 1000)
    }
    if ((m = /^(\d+):(\d{1,2})(?::(\d{1,2}))?$/.exec(text)))
      return m[3] === undefined ? parseInt(m[1]) * 60 + parseInt(m[2])
                                : parseInt(m[1]) * 3600 + parseInt(m[2]) * 60 + parseInt(m[3])
    if ((m = /^(?:(\d+)h)?\s*(?:(\d+)m)?\s*(?:(\d+)s)?$/.exec(text)) && text !== "")
      return (parseInt(m[1] || 0)) * 3600 + (parseInt(m[2] || 0)) * 60 + parseInt(m[3] || 0)
    if (/^\d+$/.test(text)) return parseInt(text) * 60
    return -1
  }

  function describe(sec) {
    if (sec % 3600 === 0) return sec / 3600 + "h"
    if (sec % 60 === 0) return sec / 60 + "m"
    return format(sec)
  }

  function save() {
    store.setText(JSON.stringify(root.timers))
  }

  function add(raw, name, command) {
    var sec = parseTime(raw)
    if (sec <= 0) { error = "Try 5, 90s, 1h30m, 1:30:00 or @7:30"; return false }
    error = ""
    var list = timers.slice()
    list.push({
      id: String(Date.now()) + Math.floor(Math.random() * 1000),
      name: name.trim() !== "" ? name.trim() : describe(sec),
      command: command.trim(),
      duration: sec,
      repeat: false,
      state: "running",
      endsAt: Date.now() + sec * 1000,
      left: sec
    })
    timers = list
    now = Date.now()
    save()
    return true
  }

  function update(id, fn) {
    timers = timers.map(function(t) {
      if (t.id !== id) return t
      var copy = Object.assign({}, t)
      fn(copy)
      return copy
    })
    now = Date.now()
    save()
  }

  function pause(id) {
    update(id, function(t) {
      t.left = Math.max(0, Math.ceil((t.endsAt - Date.now()) / 1000))
      t.state = "paused"
    })
  }

  function resume(id) {
    update(id, function(t) {
      t.endsAt = Date.now() + t.left * 1000
      t.state = "running"
    })
  }

  function restart(id) {
    update(id, function(t) {
      t.endsAt = Date.now() + t.duration * 1000
      t.left = t.duration
      t.state = "running"
    })
  }

  function toggleRepeat(id) { update(id, function(t) { t.repeat = !t.repeat }) }

  function remove(id) {
    timers = timers.filter(function(t) { return t.id !== id })
    save()
  }

  function clearDone() {
    timers = timers.filter(function(t) { return t.state !== "done" })
    save()
  }

  function fire(t) {
    Quickshell.execDetached(["notify-send", "-u", "critical", "-i", "alarm-symbolic", "-a", "Timer",
                             "Time is up", t.name])
    Quickshell.execDetached(["pw-play", sound])
    if (t.command !== "") Quickshell.execDetached(["sh", "-c", t.command])
  }

  // Expire anything past its end time; repeating timers start over.
  function tick() {
    now = Date.now()
    var changed = false
    var next = timers.map(function(t) {
      if (t.state !== "running" || t.endsAt > now) return t
      changed = true
      fire(t)
      var copy = Object.assign({}, t)
      if (t.repeat) copy.endsAt = now + t.duration * 1000
      else copy.state = "done"
      return copy
    })
    if (changed) { timers = next; save() }
  }

  readonly property var soonest: {
    var best = null
    for (var i = 0; i < timers.length; i++) {
      var t = timers[i]
      if (t.state === "done") continue
      if (best === null || (t.state === "running" && (best.state !== "running" || remaining(t) < remaining(best)))) best = t
    }
    return best
  }
  readonly property int doneCount: timers.filter(function(t) { return t.state === "done" }).length
  readonly property bool anyRunning: timers.some(function(t) { return t.state === "running" })

  readonly property string label: soonest ? format(remaining(soonest)) : ""

  Component.onCompleted: {
    Quickshell.execDetached(["mkdir", "-p", stateDir])
    store.reload()
  }

  FileView {
    id: store
    path: root.stateDir + "/timers.json"
    printErrors: false
    onLoaded: {
      try {
        var list = JSON.parse(text())
        if (Array.isArray(list)) root.timers = list
      } catch (e) {}
      root.loaded = true
      root.tick()
    }
    onLoadFailed: root.loaded = true
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.anyRunning
    triggeredOnStart: true
    onTriggered: root.tick()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: String.fromCodePoint(root.doneCount > 0 ? 0xF0026 : 0xF13AB)
    labelText: root.bar && root.bar.vertical ? "" : root.label
    active: root.anyRunning || root.doneCount > 0
    // BarIconButton paints the label past its fixed slot, so widen the slot
    // to fit it or the text overlaps the neighbouring widget.
    fixedWidth: labelText === "" ? slotSize
      : Math.max(slotSize, canvasSize + labelMetrics.advanceWidth + Style.space(12))
    tooltipText: root.soonest ? root.soonest.name + " · " + root.format(root.remaining(root.soonest)) : "Timer"
    onPressed: function(b) { root.toggle() }
  }

  TextMetrics {
    id: labelMetrics
    font.family: button.fontFamily
    font.pixelSize: button.fontSize
    text: button.labelText
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: column
          width: scroller.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "TIMER"
            foreground: root.foreground
          }

          // ---------- Presets ----------
          Row {
            id: presets
            width: parent.width
            spacing: Style.space(8)

            Repeater {
              model: ["1", "5", "10", "15", "30"]

              Button {
                required property string modelData
                width: (presets.width - presets.spacing * 4) / 5
                text: modelData + "m"
                bordered: true
                foreground: root.foreground
                onClicked: root.add(modelData, nameField.text, commandField.text)
              }
            }
          }

          // ---------- New timer ----------
          Row {
            width: parent.width
            spacing: Style.space(8)

            TextField {
              id: timeField
              width: parent.width - startButton.width - parent.spacing
              placeholderText: "5, 90s, 1h30m, @7:30"
              foreground: root.foreground
              onAccepted: startButton.clicked()
              onTextChanged: root.error = ""
            }

            Button {
              id: startButton
              iconText: String.fromCodePoint(0xF040A)
              tooltipText: "Start"
              bordered: true
              foreground: root.foreground
              onClicked: if (root.add(timeField.text, nameField.text, commandField.text)) timeField.text = ""
            }
          }

          TextField {
            id: nameField
            width: parent.width
            placeholderText: "Name (optional)"
            foreground: root.foreground
            onAccepted: startButton.clicked()
          }

          TextField {
            id: commandField
            width: parent.width
            placeholderText: "Command to run when done (optional)"
            foreground: root.foreground
            onAccepted: startButton.clicked()
          }

          Text {
            visible: root.error !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: root.error
            color: Color.urgent
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          // ---------- Timers ----------
          PanelSeparator { visible: root.timers.length > 0 }

          Column {
            visible: root.timers.length > 0
            width: parent.width
            spacing: Style.space(8)

            Repeater {
              model: root.timers

              Item {
                id: row
                required property var modelData
                readonly property bool done: modelData.state === "done"
                width: parent.width
                height: Math.max(info.implicitHeight, controls.implicitHeight)

                Column {
                  id: info
                  anchors.left: parent.left
                  anchors.right: controls.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    width: parent.width
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: row.modelData.name
                    color: root.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: row.done ? "Finished"
                        : root.format(root.remaining(row.modelData)) + (row.modelData.state === "paused" ? " · paused" : "")
                    color: row.done ? Color.urgent : root.dim
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                  }
                }

                Row {
                  id: controls
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)

                  Button {
                    visible: !row.done
                    iconText: String.fromCodePoint(row.modelData.state === "running" ? 0xF03E4 : 0xF040A)
                    tooltipText: row.modelData.state === "running" ? "Pause" : "Resume"
                    foreground: root.foreground
                    onClicked: row.modelData.state === "running" ? root.pause(row.modelData.id) : root.resume(row.modelData.id)
                  }

                  Button {
                    iconText: String.fromCodePoint(0xF0450)
                    tooltipText: "Restart"
                    foreground: root.foreground
                    onClicked: root.restart(row.modelData.id)
                  }

                  Button {
                    iconText: String.fromCodePoint(0xF0456)
                    tooltipText: row.modelData.repeat ? "Repeating" : "Repeat"
                    selected: row.modelData.repeat
                    foreground: root.foreground
                    onClicked: root.toggleRepeat(row.modelData.id)
                  }

                  Button {
                    iconText: String.fromCodePoint(0xF0156)
                    tooltipText: "Remove"
                    foreground: root.foreground
                    onClicked: root.remove(row.modelData.id)
                  }
                }
              }
            }
          }

          Button {
            visible: root.doneCount > 0
            width: parent.width
            text: "Clear finished"
            bordered: true
            foreground: root.foreground
            onClicked: root.clearDone()
          }
        }
      }
    }
  }
}
