import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool connected: false
  property string sceneName: ""
  property var scenes: []
  property bool streaming: false
  property bool recording: false
  property bool muted: false
  property string error: ""

  readonly property string bridgePath: {
    var url = Qt.resolvedUrl("bin/obs-bridge").toString()
    return url.indexOf("file://") === 0 ? url.substring(7) : url
  }

  function send(payload) {
    if (!bridge.running)
      return "offline"
    bridge.write(JSON.stringify(payload) + "\n")
    return "ok"
  }

  function scene(n) {
    return send({ op: "scene", n: String(n) })
  }

  function setScene(name) {
    return send({ op: "setScene", name: String(name) })
  }

  function toggleStream() {
    return send({ op: "toggleStream" })
  }

  function toggleRecord() {
    return send({ op: "toggleRecord" })
  }

  function toggleMute() {
    return send({ op: "toggleMute" })
  }

  function refresh() {
    return send({ op: "refresh" })
  }

  function nextScene() {
    if (!scenes || scenes.length === 0)
      return "offline"
    var index = scenes.indexOf(sceneName)
    var next = index < 0 ? 0 : (index + 1) % scenes.length
    return setScene(scenes[next])
  }

  function applyState(payload) {
    connected = payload.connected === true
    sceneName = payload.scene ? String(payload.scene) : ""
    scenes = Array.isArray(payload.scenes) ? payload.scenes : []
    streaming = payload.streaming === true
    recording = payload.recording === true
    muted = payload.muted === true
    error = payload.error ? String(payload.error) : ""
  }

  function statusJson() {
    return JSON.stringify({
      connected: connected,
      scene: sceneName,
      scenes: scenes,
      streaming: streaming,
      recording: recording,
      muted: muted,
      error: error
    })
  }

  Process {
    id: bridge
    running: true
    stdinEnabled: true
    command: ["python3", "-u", root.bridgePath]
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var payload = JSON.parse(line)
        } catch (e) {
          return
        }
        if (payload && payload.event === "state")
          root.applyState(payload)
      }
    }
    stderr: SplitParser {
      onRead: function(line) {
        console.warn("omastreamer:", line)
      }
    }
    onExited: restartDelay.restart()
  }

  Timer {
    id: restartDelay
    interval: 1200
    repeat: false
    onTriggered: {
      if (!bridge.running)
        bridge.running = true
    }
  }

  IpcHandler {
    target: "omastreamer"

    function scene(n: string): string {
      return root.scene(n)
    }

    function setScene(name: string): string {
      return root.setScene(name)
    }

    function next(): string {
      return root.nextScene()
    }

    function toggleStream(): string {
      return root.toggleStream()
    }

    function toggleRecord(): string {
      return root.toggleRecord()
    }

    function toggleMute(): string {
      return root.toggleMute()
    }

    function refresh(): string {
      return root.refresh()
    }

    function status(): string {
      return root.statusJson()
    }
  }
}
