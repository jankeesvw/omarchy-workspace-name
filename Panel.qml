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


  // A small, opinionated set of icons for the things people actually keep a
  // workspace for, so the common case is a click rather than a trip to the
  // Nerd Fonts cheat sheet. Anything outside it still goes in the field by
  // hand — the grid is a shortcut, not the vocabulary.
  //
  // Stored as codepoints rather than glyphs: Private Use Area characters do
  // not survive every editor and every copy-paste, and a list of them reads
  // as a column of blanks in a diff. Every one of these was checked against
  // the font Omarchy ships.
  readonly property var presetIcons: [
    0xF120, 0xF121, 0xE73C, 0xE74E, 0xE7BA, 0xF1D3, 0xF09B, 0xF296,
    0xF268, 0xF269, 0xF086, 0xF198, 0xF066F, 0xF099, 0xF0E0, 0xF292,
    0xF001, 0xF1BC, 0xF03D, 0xF11B, 0xF1B6, 0xF030, 0xF03E, 0xF1FC,
    0xF07B, 0xF02D, 0xF040, 0xF073, 0xF017, 0xF002, 0xF188, 0xF080,
    0xF1C0, 0xF233, 0xF0C2, 0xE7B0, 0xF17C, 0xF179, 0xF17A, 0xF17B,
    0xF015, 0xF013, 0xF023, 0xF0C3, 0xF135, 0xF0F4, 0xF005, 0xF04B
  ]

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
          placeholderText: "Icon, or pick one below"
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


      // The picker sets the field rather than saving on the spot: the panel
      // saves both halves together on Enter, and a click that wrote one of
      // them straight to disk would make that rule a lie.
      Grid {
        id: presets
        width: parent.width
        columns: 8
        spacing: Style.space(2)

        readonly property real cell: Math.floor((width - spacing * (columns - 1)) / columns)

        Repeater {
          model: root.presetIcons

          Rectangle {
            required property var modelData
            readonly property string glyph: String.fromCodePoint(modelData)

            width: presets.cell
            height: presets.cell
            radius: Style.cornerRadius
            color: iconField.text === glyph
              ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
              : (hover.hovered ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) : "transparent")

            Text {
              anchors.centerIn: parent
              text: parent.glyph
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.icon
            }

            HoverHandler { id: hover }
            TapHandler { onTapped: iconField.text = parent.glyph }
          }
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
