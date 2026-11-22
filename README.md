# Session Restore for Omarchy

Save your open windows before a reboot, get them back on your workspaces after
the next boot — including terminal working directories and, if you use herdr,
your resumed AI agent sessions.

Built for the dual-boot workflow: reboot into another OS, boot back into
Omarchy, and pick up where you left off.

## What it does

- **Save** captures every open window: its launch command (rebuilt from
  `/proc/<pid>/cmdline`), workspace, floating state, and — for terminals —
  the shell's working directory.
- **Restore** runs automatically when the Omarchy shell starts after login
  and relaunches each window silently onto its saved workspace, without
  stealing focus. Terminals start back in their saved directories.
- **Agent resume** (optional): if a herdr server was running at save time, the
  restore waits for herdr to come back and restarts `claude --continue` in the
  matching pane, so your Claude Code conversation resumes by itself.
- The saved manifest is locked and consumed after one restore, so a boot (or
  a shell restart) never double-launches anything.
- **Workspace presets**: save just the apps on one workspace under a name, and
  reopen them whenever you like, where they were saved or on the workspace
  you're on. Presets are kept, not consumed, and apps already open on the
  target workspace aren't launched twice. See
  [Workspace presets](#workspace-presets).

> This is a fork of
> [wbarakat/omarchy-session-restore](https://github.com/wbarakat/omarchy-session-restore)
> that adds workspace presets. It uses its own plugin id,
> `io.github.aledlewis.session-restore`, so don't install both.

## Install

```bash
omarchy plugin add https://github.com/AledLewis/omarchy-session-restore.git --enable
```

The plugin's `service` entry point runs the restore at shell startup. Saving
is manual (see Usage) until you add the optional menu integration below.

**Menu integration (recommended):** merge
`extensions/omarchy-menu-snippet.jsonc` into
`~/.config/omarchy/extensions/omarchy-menu.jsonc` and run
`omarchy menu refresh`. This adds a "Save Session" row to the System menu and
makes Reboot and Shutdown save the session automatically first. This step
edits your menu config, so it is deliberately manual — the plugin never
changes your configuration by itself.

<details>
<summary>Manual install without the plugin system</summary>

```bash
git clone https://github.com/AledLewis/omarchy-session-restore.git
cd omarchy-session-restore
./install.sh
```

This copies the scripts to `~/.local/bin` and installs a `post-boot` hook
instead of the shell service. In the menu snippet, replace the plugin paths
with `~/.local/bin/...`. Use either the plugin or the manual install, not
both.

</details>

## Usage

```bash
~/.config/omarchy/plugins/io.github.aledlewis.session-restore/bin/omarchy-session-save
# preview what a restore would launch:
~/.config/omarchy/plugins/io.github.aledlewis.session-restore/bin/omarchy-session-restore --dry-run
```

With the menu integration installed, saving is automatic: reboot or shut down
from the Omarchy menu and the session is snapshotted first. On the next boot
into Omarchy everything relaunches within a few seconds of login.

State lives in `~/.local/state/omarchy/`:

- `session.json` — the window manifest (renamed to `.restored` after use)
- `herdr-agents.json` — agent panes to resume (also consumed after use)
- `session.lock` — guards against concurrent restores
- `session-restore.log` — timestamped save, window launch, and agent resume results
- `workspaces/<name>.json` — saved workspace presets
- `locks/` — per-preset restore locks

## Workspace presets

A preset is a snapshot of the apps on one workspace: each window's launch
command, floating state and, for terminals, the shell's directory. It never
touches the boot session above.

```bash
bin=~/.config/omarchy/plugins/io.github.aledlewis.session-restore/bin

$bin/omarchy-workspace-save work            # save the current workspace as "work"
$bin/omarchy-workspace-save notes --workspace 3

$bin/omarchy-workspace-restore work         # reopen on the workspace it came from
$bin/omarchy-workspace-restore work --here  # ...or on the one you're on
$bin/omarchy-workspace-restore work --to 7  # ...or on workspace 7
$bin/omarchy-workspace-restore work --dry-run
$bin/omarchy-workspace-restore --list

$bin/omarchy-workspace-delete work          # forget the preset; closes nothing
```

Without a name, each command asks in the Omarchy menu. Save asks for a name
(blank uses the workspace number) and replaces a preset of the same name.
Restore and delete show a picker of saved presets. From the menu or a
keybinding, the result comes back as a notification.

**Onto an empty workspace, the layout comes back exactly.** Hyprland doesn't
report its tiling tree, but a dwindle layout is always a series of straight
cuts, so `omarchy-workspace-layout` works the splits out from the saved window
rectangles. It then rebuilds them one window at a time: it focuses the window
that holds a region, tells Hyprland which side the next window goes on, waits
for that window to appear, and sets the split ratio. Floating windows are put
back at their saved size and position. You'll see the workspace while it's
being built (about a second for terminals; longer for a slow app). If an app
never opens a window, for example because it only allows one, it's left out
and the layout closes up around it.

`--dry-run` prints the split tree it would build:

```
split left | right, ratio 1.3005
  foot in ~/projects/site
  split top / bottom, ratio 0.6992
    foot in ~/projects/site
    firefox
```

**Onto a workspace that already has windows** (or with `--no-layout`, or on a
scrolling/floating workspace) the apps are launched in the background and
Hyprland tiles them as they arrive. This is safe to repeat: an app whose
window class already has a window on the target workspace is skipped, once
per open window. Two terminals saved and one open means one gets launched.

Every browser window on a workspace is saved, even though a browser runs them
all in one process. Launching the browser again while it's running adds a
window, but a new, empty one: tabs aren't restored.

The menu snippet adds a **Workspaces** submenu with all four actions. For
keys, these follow Omarchy's own save/restore pair (Super+Alt+Home saves a
window width, Super+Home restores it) and its number-key pattern. Add to
`~/.config/hypr/bindings.lua`:

```lua
local ws_bin = os.getenv("HOME") .. "/.config/omarchy/plugins/io.github.aledlewis.session-restore/bin/"
o.bind("SUPER + ALT + End", "Save workspace", ws_bin .. "omarchy-workspace-save")
o.bind("SUPER + End", "Restore workspace", ws_bin .. "omarchy-workspace-restore")
o.bind("SUPER + SHIFT + End", "Restore workspace here", ws_bin .. "omarchy-workspace-restore --here")

-- Super+Ctrl+N restores the save named "N" (the default name when saving workspace N) onto workspace N.
for n = 1, 10 do
  o.bind("SUPER + CTRL + code:" .. (n + 9), "Restore saved workspace " .. n,
    ws_bin .. "omarchy-workspace-restore " .. n .. " --to " .. n)
end
```

These are free in a stock Omarchy install; check yours with `hyprctl binds`.

## Removal

```bash
omarchy plugin remove io.github.aledlewis.session-restore
```

Then remove the menu entries you added to
`~/.config/omarchy/extensions/omarchy-menu.jsonc` (if any) and, optionally,
the state files: `rm -rf ~/.local/state/omarchy/session.json* ~/.local/state/omarchy/herdr-agents.json* ~/.local/state/omarchy/session.lock ~/.local/state/omarchy/session-restore.log ~/.local/state/omarchy/workspaces ~/.local/state/omarchy/locks`

For a manual install, additionally delete the three `omarchy-session-*`
scripts from `~/.local/bin` and
`~/.config/omarchy/hooks/post-boot.d/10-session-restore`.

## Requirements and dependencies

- Omarchy (Quattro) with Hyprland **0.56+** — the restore dispatches through
  the Lua API: `hl.dispatch(hl.dsp.exec_cmd(...))`
- `jq` and `flock` (both ship with Omarchy / util-linux)
- `python3` (standard library only) for exact workspace layouts
- Optional: herdr for agent resume; `notify-send` for save feedback

No sudo, no network access, no external downloads. The plugin only reads
`hyprctl` output and `/proc`, and writes state under `~/.local/state/omarchy/`.

## Limitations

This is best-effort relaunch, not process freezing — only hibernation can
preserve actual application state across a reboot:

- Apps reopen fresh. Browsers and editors restore their own sessions if they
  are configured to; unsaved work is gone.
- Windows sharing one process (e.g. several Chromium windows or web apps)
  collapse to a single relaunch entry.
- Scratchpad/special workspaces are skipped.
- Only `claude` agents get a resume flag in herdr; other agent kinds start
  fresh.
- Saves triggered outside the menu (plain `systemctl reboot`) require running
  `omarchy-session-save` manually first.

## License

MIT, as the original. Session save and restore by Waleed
([wbarakat/omarchy-session-restore](https://github.com/wbarakat/omarchy-session-restore));
workspace presets, layout restore and fixes by Aled Lewis. See [LICENSE](LICENSE).
