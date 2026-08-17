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

Click the label to open the panel. It has two fields: an icon and a name. Fill
in either, both, or neither — press Enter to save. Emptying a field clears that
half, and clearing both makes the widget disappear again. Escape closes without
saving.

The icon field takes the two forms you are likely to have an icon in: **paste
the glyph**, or type its **codepoint** (`f121`, `U+F121`, `0xF121`). Both are
needed — a Nerd Font glyph cannot be typed and a codepoint cannot be read — so
the preview beside the field shows what is about to be saved.

Since a workspace with no name and no icon shows nothing, there is nothing to
click on the first one you want to label, so bind a key to open the panel:

```lua
-- ~/.config/hypr/bindings.lua
o.bind(hyper .. "R", "Workspace name", "omarchy-shell shell toggle jankeesvw.workspace-name")
```

That is the way in, and it stays the faster way once names are everywhere.

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

## Requirements

Omarchy with `omarchy-shell` (the Quickshell-based bar) and Hyprland. Nothing
else: no extra packages, no helper scripts.

## License

MIT
