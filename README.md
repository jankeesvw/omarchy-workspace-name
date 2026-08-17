# Workspace name

An [Omarchy](https://omarchy.org) bar widget that gives the current workspace a
name, and lets you type a new one.

Hyprland workspaces are numbered, and a number tells you where you are but not
what you were doing there. This widget puts a short label next to the workspace
indicators: `invoicing`, `bug #4412`, `reading`. Switch workspaces and the label
follows.

Until a workspace has a name the widget takes up no room at all, so a bar with
this in it looks untouched until you start using it.

## Install

```bash
omarchy plugin add https://github.com/jankeesvw/omarchy-workspace-name.git --enable
```

The widget lands in the left section of the bar by default. Move it with
`omarchy bar move`, or from the bar's own settings panel.

## Use

Click the label to open the panel, type a name, press Enter. An empty name
clears it and the widget disappears again. Escape closes without saving.

Since a workspace with no name shows nothing, there is nothing to click on the
first one you want to label — so bind a key to open the panel:

```lua
-- ~/.config/hypr/bindings.lua
o.bind(hyper .. "R", "Workspace name", "omarchy-shell shell toggle jankeesvw.workspace-name")
```

That is the way in, and it stays the faster way once names are everywhere.

## Where names are stored

One plain-text file per workspace, in `$XDG_STATE_HOME/workspace-hud/<id>`
(usually `~/.local/state/workspace-hud/1`, `.../2`, and so on). No daemon, no
database.

That means other tooling can join in. Reading the name of workspace 3 is a
`cat`:

```bash
cat ~/.local/state/workspace-hud/3
```

And setting one is a redirect — the directory is watched, so the bar picks up
the change without being told:

```bash
echo "deploying" > ~/.local/state/workspace-hud/3
```

Which is handy for scripts: a build wrapper can label the workspace it is
running in, and clear the label when it finishes.

Names are not remembered across reboots any longer than the state directory
is; nothing prunes them, so a name stays on a workspace until you clear it.

## Requirements

Omarchy with `omarchy-shell` (the Quickshell-based bar) and Hyprland. Nothing
else — no extra packages, no helper scripts.

## License

MIT
