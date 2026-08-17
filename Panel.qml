import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

// Workspace name: shows the name given to the current workspace, and lets you
// set it.
//
// The widget takes up no room at all until a workspace has a name, so a bar
// with this in it looks untouched until you start using it.
//
// Names live one per file in $XDG_STATE_HOME/workspace-hud/<id>, plain text,
// no daemon and no database. Anything else on the system can read the current
// name with a cat, and writing one from a script is a redirect — the directory
// is watched, so the bar picks that up without being told.
Panel {
  id: root

  moduleName: "jankeesvw.workspace-name"
  ipcTarget: "jankeesvw.workspace-name"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Panel is a bare Item, unlike BarWidget: these two do not come with it.
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/workspace-hud"

  property string workspaceName: ""
  readonly property int workspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
  readonly property bool hasName: workspaceName !== ""

  // Brief accent flash whenever the name changes, so a workspace switch is
  // noticeable out of the corner of your eye instead of something you have to
  // read. Skipped on the very first read, which would otherwise flash at
  // login for no reason.
  property bool flashing: false
  property bool seenFirstRead: false

  onWorkspaceNameChanged: {
    if (!seenFirstRead) {
      seenFirstRead = true
      return
    }
    flashing = true
    flashTimer.restart()
  }

  Timer {
    id: flashTimer
    interval: 450
    onTriggered: root.flashing = false
  }

  // Nothing to show without a name, so the widget takes no room at all.
  implicitWidth: hasName ? label.implicitWidth + Style.space(16) : 0
  implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

  function nameFilePath(id) {
    return root.stateDir + "/" + id
  }

  function save() {
    // The name is passed as an argument rather than spliced into the script,
    // so a name with a quote or a backtick in it stays a name.
    writeProc.command = ["sh", "-c",
      'mkdir -p -- "$(dirname -- "$1")"; ' +
      'if [ -n "$2" ]; then printf "%s\\n" "$2" > "$1"; else rm -f -- "$1"; fi',
      "sh", root.nameFilePath(root.workspaceId), nameField.text.trim()]
    writeProc.running = true
    close()
  }

  Process {
    id: writeProc
  }

  // The name file for the focused workspace. Changing `path` on a workspace
  // switch reloads it, which is why nothing here listens to Hyprland for a
  // redraw. Watched as well, so a name written by anything else on the system
  // lands in the bar without being told about it. An absent file is the normal
  // case, not an error: a workspace simply has no name yet.
  FileView {
    id: nameFileView
    path: root.workspaceId > 0 ? root.nameFilePath(root.workspaceId) : ""
    watchChanges: true
    printErrors: false
    // text() is stale inside the change signal, so go around through reload()
    // and read it in onLoaded.
    onFileChanged: reload()
    onLoaded: root.workspaceName = text().trim()
    onLoadFailed: root.workspaceName = ""
  }

  // FileView only watches a file it can resolve, and it cannot create the
  // directory the first name will be written into. Do that once at startup.
  Process {
    id: ensureStateDir
    running: true
    command: ["sh", "-c", 'mkdir -p -- "$1"', "sh", root.stateDir]
  }

  onOpenedChanged: {
    if (opened) {
      nameField.text = workspaceName
      nameField.selectAll()
    }
  }

  WidgetButton {
    id: label
    anchors.fill: parent
    bar: root.bar
    visible: root.hasName
    text: root.workspaceName
    active: root.flashing
    horizontalMargin: 8
    verticalPadding: 6
    fixedWidth: root.vertical ? root.barSize : -1
    fixedHeight: root.barSize
    tooltipText: ""
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: label
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: nameField
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(6)

      PanelSectionHeader {
        width: parent.width
        text: "WORKSPACE " + root.workspaceId
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      TextField {
        id: nameField
        width: parent.width
        placeholderText: "Name, leave empty to clear"
        foreground: root.foreground
        verticalPadding: Style.space(4)
        onAccepted: root.save()
        Keys.onEscapePressed: root.close()
      }
    }
  }
}
