import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

// Workspace name: shows the name and the icon given to the current workspace,
// and lets you set them.
//
// The widget takes up no room at all until a workspace has one or the other,
// so a bar with this in it looks untouched until you start using it.
//
// Names and icons live one per file in $XDG_STATE_HOME/workspace-hud/<id> and
// <id>.icon, plain text, no daemon and no database. Anything else on the
// system can read the current name with a cat, and writing one from a script
// is a redirect. Both files are watched, so the bar picks that up without
// being told.
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
  property string workspaceIcon: ""
  readonly property int workspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
  readonly property bool hasName: workspaceName !== ""
  readonly property bool hasIcon: workspaceIcon !== ""

  // An icon alone is a perfectly good label — a workspace can be the one with
  // the terminals without also being called "terminals" — so either half is
  // enough to put the widget on the bar.
  readonly property string labelText: {
    if (hasIcon && hasName) return workspaceIcon + "  " + workspaceName
    return hasIcon ? workspaceIcon : workspaceName
  }
  readonly property bool hasLabel: labelText !== ""

  // Brief accent flash whenever the label changes, so a workspace switch is
  // noticeable out of the corner of your eye instead of something you have to
  // read. Skipped on the very first read, which would otherwise flash at
  // login for no reason.
  property bool flashing: false
  property bool seenFirstRead: false

  onLabelTextChanged: {
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

  // Nothing to show without a name or an icon, so the widget takes no room.
  implicitWidth: hasLabel ? label.implicitWidth + Style.space(16) : 0
  implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

  function nameFilePath(id) {
    return root.stateDir + "/" + id
  }

  function iconFilePath(id) {
    return root.stateDir + "/" + id + ".icon"
  }

  // An icon can be given as the glyph itself or as its codepoint, because
  // those are the two forms you are likely to have one in: a Nerd Font glyph
  // can be pasted but not typed, and `echo f121 > 3.icon` is the kind of
  // redirect the name file already invites.
  //
  // The first character is taken with codePointAt rather than by indexing:
  // an icon outside the BMP (the Material Design set, U+F0000 and up) is a
  // surrogate pair, and half of one draws as tofu.
  function parseIcon(raw) {
    var value = String(raw || "").trim()
    if (value === "") return ""

    var hex = value.match(/^(?:u\+|0x|\\u)?([0-9a-f]{4,6})$/i)
    if (hex) {
      var cp = parseInt(hex[1], 16)
      if (cp > 0 && cp <= 0x10FFFF) return String.fromCodePoint(cp)
    }

    return String.fromCodePoint(value.codePointAt(0))
  }

  function save() {
    // Each value is passed as an argument rather than spliced into the script,
    // so a name with a quote or a backtick in it stays a name.
    writeProc.command = ["sh", "-c",
      'mkdir -p -- "$(dirname -- "$1")"; ' +
      'if [ -n "$2" ]; then printf "%s\\n" "$2" > "$1"; else rm -f -- "$1"; fi; ' +
      'if [ -n "$4" ]; then printf "%s\\n" "$4" > "$3"; else rm -f -- "$3"; fi',
      "sh",
      root.nameFilePath(root.workspaceId), nameField.text.trim(),
      root.iconFilePath(root.workspaceId), root.parseIcon(iconField.text)]
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

  // The icon file, on exactly the same terms as the name file. Parsed on read
  // as well as on write, so a codepoint dropped in from a script shows up as
  // the glyph rather than as four literal characters.
  FileView {
    id: iconFileView
    path: root.workspaceId > 0 ? root.iconFilePath(root.workspaceId) : ""
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.workspaceIcon = root.parseIcon(text().trim())
    onLoadFailed: root.workspaceIcon = ""
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
      iconField.text = workspaceIcon
      nameField.text = workspaceName
      nameField.selectAll()
    }
  }

  WidgetButton {
    id: label
    anchors.fill: parent
    bar: root.bar
    visible: root.hasLabel
    text: root.labelText
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

      // The icon row previews what was typed next to the field, because a
      // codepoint is unreadable and a pasted glyph is easy to get wrong —
      // neither tells you what you are about to save until you see it drawn.
      Row {
        width: parent.width
        spacing: Style.space(8)

        TextField {
          id: iconField
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - Style.space(28) - Style.space(8)
          placeholderText: "Icon: paste a glyph or type f121"
          foreground: root.foreground
          verticalPadding: Style.space(4)
          onAccepted: root.save()
          Keys.onEscapePressed: root.close()
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(28)
          text: root.parseIcon(iconField.text)
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.icon
          horizontalAlignment: Text.AlignHCenter
        }
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
