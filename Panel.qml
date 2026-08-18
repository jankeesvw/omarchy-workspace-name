import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
//
// It can draw the workspace indicators as well, off by default. An icon is
// only half useful on the workspace you are already on; the row of numbers is
// where you look to find the one you want. Turned on, this widget replaces
// omarchy.workspaces rather than sitting next to it, which is what keeps the
// two from ever showing different icons for the same workspace.
Panel {
  id: root

  moduleName: "jankeesvw.workspace-name"
  ipcTarget: "jankeesvw.workspace-name"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Panel is a bare Item, unlike BarWidget: these two do not come with it.
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal

  // Drawing the indicators means standing in for omarchy.workspaces, which is
  // too big a thing to switch on for someone who installed a name widget. Off
  // until asked for.
  readonly property bool showIndicators: setting("indicators", false) === true
  // An icon in place of the number keeps a button one character wide, the size
  // the stock indicators are built at. Keeping both reads as "icon 4" and has
  // to grow the button, which is a change to the shape of the bar.
  readonly property bool showNumbers: setting("numbers", false) === true

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/workspace-hud"

  property string workspaceName: ""
  property string workspaceIcon: ""

  // The icon the panel will save. Held here rather than in a field, because
  // the picker is the whole of the icon interface now.
  property string pickedIcon: ""
  readonly property int workspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
  readonly property bool hasName: workspaceName !== ""
  readonly property bool hasIcon: workspaceIcon !== ""

  // An icon alone is a perfectly good label — a workspace can be the one with
  // the terminals without also being called "terminals" — so either half is
  // enough to put the widget on the bar.
  //
  // Except when the indicators are drawn: the icon is already sitting on this
  // workspace's own button a few pixels to the left, and the same thing shown
  // twice in one bar reads as two things. There the label is the name alone.
  readonly property string labelText: {
    if (showIndicators) return workspaceName
    if (hasIcon && hasName) return workspaceIcon + "  " + workspaceName
    return hasIcon ? workspaceIcon : workspaceName
  }
  readonly property bool hasLabel: labelText !== ""

  // Brief accent flash whenever the label changes, so a workspace switch is
  // noticeable out of the corner of your eye instead of something you have to
  // read. Held back until both files have reported once: they are read
  // independently, so whichever of the two lands second would otherwise
  // flash at login for a label that was already right.
  property bool flashing: false
  property bool seenNameRead: false
  property bool seenIconRead: false
  readonly property bool seenFirstRead: seenNameRead && seenIconRead

  onLabelTextChanged: {
    if (!seenFirstRead) return
    flashing = true
    flashTimer.restart()
  }

  Timer {
    id: flashTimer
    interval: 450
    onTriggered: root.flashing = false
  }

  // Nothing to show without a name, an icon or a row of indicators, so the
  // widget takes no room at all. The layout skips a hidden child, and
  // WidgetButton hides itself on empty text, so this falls out on its own.
  implicitWidth: content.implicitWidth
  implicitHeight: content.implicitHeight

  // A small, opinionated set of icons for the things people actually keep a
  // workspace for. Brand marks are left out: a workspace is a kind of work,
  // not a logo, and a picker full of them dates fast. The exceptions are the
  // handful this bar's workspace indicators already use, so the two agree.
  // Anything outside the set still goes in the file by hand, since that is
  // the vocabulary and this is only the shortcut.
  //
  // Stored as codepoints rather than glyphs: Private Use Area characters do
  // not survive every editor and every copy-paste, and a list of them reads
  // as a column of blanks in a diff. Every one of these was checked against
  // the font Omarchy ships.
  readonly property var presetIcons: [
    0xEAC4, 0xF120, 0xE73E, 0xF040, 0xF02D, 0xF07B, 0xE69C,
    0xE8A4, 0xF01EE, 0xE217, 0xF232, 0xE820, 0xEB72, 0xF086, 0xF292,
    0xEC1B, 0xF03D, 0xF030, 0xF03E, 0xF1FC, 0xF11B, 0xF108, 0xF073,
    0xF017, 0xF002, 0xF188, 0xF080, 0xF1C0, 0xF233, 0xF0C2, 0xE712,
    0xF015, 0xF013, 0xF023, 0xF0C3, 0xF135, 0xF0F4, 0xF005, 0xEA71
  ]
  // Foreground at a given alpha, for the picker's hover and selection fills.
  function tint(alpha) {
    return Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, alpha)
  }

  // Which workspaces the row shows: one through five always, so the bar does
  // not reflow as they come and go, plus whatever else exists up to ten. Same
  // rule the stock indicators use, on purpose.
  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  readonly property var indicatorIds: showIndicators ? workspaceIds() : []

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  // Icons for the whole row. Kept apart from the focused workspace's own
  // reader below, which has to work for any id, including one past the ten
  // the row draws.
  property var indicatorIcons: ({})

  // Replaced wholesale rather than edited in place: QML only notices a var
  // property when it is assigned, so mutating the object would leave every
  // button bound to it stale.
  function setIndicatorIcon(id, glyph) {
    var next = {}
    for (var key in indicatorIcons) next[key] = indicatorIcons[key]

    if (glyph === "") delete next[id]
    else next[id] = glyph

    indicatorIcons = next
  }

  // A workspace with no icon falls back to its number, which is the whole of
  // what the stock indicators ever show. Ten reads as 0 there, so it does
  // here.
  function indicatorText(id) {
    var icon = indicatorIcons[id] || ""
    var number = id === 10 ? "0" : String(id)

    if (icon === "") return number
    return root.showNumbers ? icon + " " + number : icon
  }

  Instantiator {
    model: root.indicatorIds

    delegate: FileView {
      required property var modelData

      path: root.iconFilePath(modelData)
      watchChanges: true
      printErrors: false
      onFileChanged: reload()
      onLoaded: root.setIndicatorIcon(modelData, root.parseIcon(text().trim()))
      onLoadFailed: root.setIndicatorIcon(modelData, "")
    }
  }

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
      root.iconFilePath(root.workspaceId), root.pickedIcon]
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
    onLoaded: { root.workspaceName = text().trim(); root.seenNameRead = true }
    onLoadFailed: { root.workspaceName = ""; root.seenNameRead = true }
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
    onLoaded: { root.workspaceIcon = root.parseIcon(text().trim()); root.seenIconRead = true }
    onLoadFailed: { root.workspaceIcon = ""; root.seenIconRead = true }
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
      pickedIcon = workspaceIcon
      presets.currentIndex = -1
    }
  }

  GridLayout {
    id: content
    anchors.fill: parent
    columns: root.vertical ? 1 : root.indicatorIds.length + 1
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.indicatorIds

      Item {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: root.workspaceId === modelData

        implicitWidth: button.implicitWidth
        implicitHeight: button.implicitHeight

        // The workspace you are on is marked by a filled block behind it, the
        // way the stock indicators mark theirs, rather than by recoloring the
        // glyph. An icon is picked to be recognised, and recoloring spends the
        // one thing it was chosen for. The block sits under the icon, so both
        // survive.
        Rectangle {
          anchors.fill: parent
          anchors.topMargin: Style.space(3)
          anchors.bottomMargin: Style.space(3)
          radius: Style.cornerRadius
          color: root.tint(0.18)
          visible: parent.focused
        }

        WidgetButton {
          id: button
          anchors.fill: parent
          bar: root.bar
          text: root.indicatorText(parent.modelData)
          opacity: parent.occupied || parent.focused ? 1 : 0.5
          horizontalMargin: 6
          verticalPadding: 6
          fixedWidth: root.vertical ? root.barSize : (root.showNumbers ? -1 : Style.space(20))
          fixedHeight: root.barSize
          onPressed: function(b) { root.focusWorkspace(parent.modelData) }
        }
      }
    }

    WidgetButton {
      id: label
      bar: root.bar
      text: root.labelText
      active: root.flashing
      // Wider than a plain button: the name is prose sitting in a row of
      // single glyphs and needs the air to read as its own thing.
      horizontalMargin: 16
      verticalPadding: 6
      fixedWidth: root.vertical ? root.barSize : -1
      fixedHeight: root.barSize
      tooltipText: ""
      onPressed: function(b) { root.toggle() }
    }
  }

  // The bar draws a dash under whichever module owns the open panel, centered
  // on that module's slot. Centered on this one it lands mid-row, under a
  // workspace that has nothing to do with the panel, and only its length is
  // ours to set, never its place. A mark pointing at the wrong thing is worse
  // than no mark, so the panel registers with the bar's one-popup-at-a-time
  // coordinator under this stand-in instead of under the widget. The bar
  // compares that registration against the module to decide what to mark, so
  // it finds no match and marks nothing, while every other panel on the bar
  // still closes this one when it opens.
  QtObject {
    id: popoutKey

    readonly property bool popoutSwitchClosing: root.popoutSwitchClosing

    function close() { root.close() }
    function closeForPopoutSwitch() { root.closeForPopoutSwitch() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: label.visible ? label : content
    owner: popoutKey
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
        Keys.onDownPressed: presets.forceActiveFocus()
      }

      // The picker sets what will be saved rather than saving on the spot:
      // the panel saves both halves together on Enter, and a click that wrote
      // an icon straight to disk would make that rule a lie.
      //
      // Arrow keys walk it once it has focus. Down out of the name field
      // steps in, every move takes the icon under the cursor, and Up off the
      // top row hands focus back. Enter saves from either place. The first
      // cell is 'no icon', which is how a workspace gives one back.
      Grid {
        id: presets
        width: parent.width
        columns: 8
        spacing: Style.space(2)
        activeFocusOnTab: true

        readonly property real cell: Math.floor((width - spacing * (columns - 1)) / columns)
        // One cell more than there are icons: the first one clears.
        readonly property int count: root.presetIcons.length + 1

        // Where the keyboard cursor sits. -1 until the grid is entered, so a
        // panel opened on a workspace with a hand-typed icon does not pretend
        // one of the presets is selected.
        property int currentIndex: -1

        function glyphAt(i) {
          return i === 0 ? "" : String.fromCodePoint(root.presetIcons[i - 1])
        }

        // Moving the cursor is the choice: there is no separate confirm
        // step, so what you are pointing at is always what Enter will save.
        function moveTo(i) {
          if (i < 0 || i >= count) return
          currentIndex = i
          root.pickedIcon = glyphAt(i)
        }

        // Entering starts the cursor on the icon the workspace already has,
        // so the eye does not have to find its way back to it.
        onActiveFocusChanged: {
          if (!activeFocus) return
          if (currentIndex < 0) {
            for (var i = 0; i < count; i++) {
              if (glyphAt(i) === root.pickedIcon) { currentIndex = i; break }
            }
          }
          moveTo(currentIndex < 0 ? 0 : currentIndex)
        }

        Keys.onLeftPressed: presets.moveTo(presets.currentIndex - 1)
        Keys.onRightPressed: presets.moveTo(presets.currentIndex + 1)
        Keys.onDownPressed: presets.moveTo(presets.currentIndex + presets.columns)
        Keys.onUpPressed: {
          if (presets.currentIndex < presets.columns) nameField.forceActiveFocus()
          else presets.moveTo(presets.currentIndex - presets.columns)
        }
        Keys.onReturnPressed: root.save()
        Keys.onEnterPressed: root.save()
        Keys.onEscapePressed: root.close()

        Repeater {
          model: presets.count

          Rectangle {
            required property int index
            readonly property string glyph: presets.glyphAt(index)
            readonly property bool clears: index === 0
            readonly property bool onCursor: presets.activeFocus && presets.currentIndex === index
            readonly property bool chosen: root.pickedIcon === glyph

            width: presets.cell
            height: presets.cell
            radius: Style.cornerRadius
            color: onCursor ? root.tint(0.30)
              : (chosen ? root.tint(0.18)
              : (hover.hovered ? root.tint(0.08) : "transparent"))

            Text {
              anchors.centerIn: parent
              // The clearing cell is drawn dim: it is the way out of the row,
              // not one more thing in it.
              text: parent.clears ? "\u00d7" : parent.glyph
              color: parent.clears ? Qt.darker(root.foreground, 1.5) : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.icon
            }

            HoverHandler { id: hover }
            TapHandler { onTapped: presets.moveTo(parent.index) }
          }
        }
      }
    }
  }
}
