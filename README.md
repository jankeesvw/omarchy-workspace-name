# Workspace name

An [Omarchy](https://omarchy.org) bar widget that gives the current workspace a
name and an icon, and lets you set both.

![The widget in the bar: switching workspaces, and renaming one](demo.gif)

Hyprland workspaces are numbered, and a number tells you where you are but not
what you were doing there. This widget puts a short label next to the workspace
indicators: `invoicing`, `bug #4412`, `reading`. Switch workspaces and the label
follows.

A workspace can also carry an icon, on its own or in front of the name. An icon
alone is often enough — a workspace can be the one with the terminals without
also being called "terminals" — and it reads faster in the corner of your eye
than a word does.

Until a workspace has a name or an icon the widget takes up no room at all, so
a bar with this in it looks untouched until you start using it.

## Install

```bash
omarchy plugin add https://github.com/jankeesvw/omarchy-workspace-name.git --enable
```

The widget lands in the left section of the bar by default. Move it with
`omarchy bar move`, or from the bar's own settings panel.

## Remove

```bash
omarchy plugin remove jankeesvw.workspace-name
```

That takes the widget out of the bar and deletes the plugin. The names and
icons you gave your workspaces are yours, not the plugin's, so they stay in
`$XDG_STATE_HOME/workspace-hud/`. Delete that directory if you want them gone
too.

## Use

Click the label to open the panel. It holds a name field and, under it, a grid
of icons. Fill in either, both, or neither, then press Enter to save. An empty
name clears the name, the first cell of the grid (`×`) clears the icon, and
clearing both makes the widget disappear again. Escape closes without saving.

The panel opens on the name, because renaming is what you came for on most
days. Press Down to step into the grid and walk it with the arrow keys. Every
move takes the icon under the cursor, so what you are pointing at is always
what Enter will save. The icon the workspace already has is where the cursor
starts and stays highlighted, Up off the top row hands focus back to the name,
and clicking a cell does the same as walking onto it.

The grid holds what a workspace is usually for: shells and editors, mail and
chat, media, infrastructure. Brand marks are mostly left out, since a
workspace is a kind of work rather than a logo. For anything the grid does not
have, write the file directly. That takes a codepoint as readily as the glyph,
which is covered below.

Since a workspace with no name and no icon shows nothing, there is nothing to
click on the first one you want to label, so bind a key to open the panel:

```lua
-- ~/.config/hypr/bindings.lua
o.bind(hyper .. "R", "Workspace name", "omarchy-shell shell toggle jankeesvw.workspace-name")
```

That is the way in, and it stays the faster way once names are everywhere.

## Drawing the indicators too

The widget can draw the row of workspace buttons as well. It is off until you
ask for it, in the widget's entry in `~/.config/omarchy/shell.json`:

```json
{ "id": "jankeesvw.workspace-name", "indicators": true }
```

Each button carries the workspace's icon where one is set and its number where
none is, and clicking one focuses that workspace. It stands in for the
`omarchy.workspaces` widget rather than sitting beside it, so take that one out
of the bar first.

An icon standing in for the number keeps a button one character wide, which is
the width the stock indicators are built at, so nothing about the shape of the
bar changes. Set `"numbers": true` to show both instead. That reads as `icon 4`
and grows every button to fit.

The reason to want this: an icon on the workspace you are already standing on
is only half useful, since the row of numbers is where you look to find the one
you want. Feeding the row and the label from the same file is what keeps them
from ever disagreeing.

## Where names and icons are stored

One plain-text file per workspace, in `$XDG_STATE_HOME/workspace-hud/<id>`,
and the icon beside it in `<id>.icon` (usually `~/.local/state/workspace-hud/1`
and `1.icon`, and so on). No daemon, no database.

That means other tooling can join in. Reading the name of workspace 3 is a
`cat`:

```bash
cat ~/.local/state/workspace-hud/3
```

And setting one is a redirect. The file is watched, so the bar picks up the
change without being told:

```bash
echo "deploying" > ~/.local/state/workspace-hud/3
```

Icons work the same way, and the file accepts a codepoint as readily as the
glyph itself — which is what makes them scriptable at all, since a Private Use
Area character is awkward to get into a shell command and impossible to read
back in a diff:

```bash
echo f120 > ~/.local/state/workspace-hud/3.icon
```

Which is handy for scripts: a build wrapper can label the workspace it is
running in, and clear the label when it finishes.

Names are not remembered across reboots any longer than the state directory
is; nothing prunes them, so a name stays on a workspace until you clear it.

## Where the icons come from

The font. There is nothing icon-specific in the widget: it draws a character,
and if the bar's font has that character you get a picture instead of a box.

That works because Omarchy's bar uses a **Nerd Font** — an ordinary monospace
face patched to carry whole icon sets (Font Awesome, Material Design,
Devicons, Octicons, Seti-UI) in Unicode's Private Use Area. An icon is
literally a character, which is why `echo f120 > 3.icon` is enough to set one.

**Recommended: whatever Nerd Font your bar already uses.** Omarchy ships
[JetBrainsMono Nerd Font](https://www.nerdfonts.com/font-downloads) and the
grid above was checked glyph by glyph against it, so the presets are safe out
of the box. Any other Nerd Font works too; only the coverage changes.

To go beyond the grid, search [the Nerd Fonts cheat
sheet](https://www.nerdfonts.com/cheat-sheet) by name and take the codepoint.
Check it before you rely on it, because the cheat sheet describes the whole
Nerd Fonts collection and your build may be a subset:

```bash
fc-list ":charset=f121" family    # empty means your font does not have it
```

If it comes back empty, you are not stuck: the toolkit falls back to any other
installed font that does have the codepoint. Installing a font that carries the
icon is enough — nothing has to be configured. The one case fallback cannot fix
is a codepoint your main font already uses for something else, since the main
font wins; there you would have to change the bar's font rather than add one.

## Requirements

Omarchy with `omarchy-shell` (the Quickshell-based bar) and Hyprland. Nothing
else: no extra packages, no helper scripts.

## License

MIT
