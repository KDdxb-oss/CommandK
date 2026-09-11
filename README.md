# CommandK

Superhuman-style command palette for macOS window management, built on
[yabai](https://github.com/koekeishiya/yabai) + [skhd](https://github.com/koekeishiya/skhd).

Press **⌘K**, type what you want, hit Enter. Plus built-in **Magnet-style
window snapping** (halves and thirds) driven entirely from the keyboard.

- `Sources/App.swift` — palette + settings UI (AppKit)
- `Sources/Config.swift` — load/save `commands.json`, generate `~/.skhdrc`
- `Sources/Keys.swift` — key event ↔ skhd bind ↔ key glyph
- `Sources/main.swift` — entry point (`--write-skhdrc`, `--settings`)
- `Resources/commands.json` — default command list
- `scripts/wm` — yabai helpers (`snap`, scratchpad, layout, lock, …)

## Requirements

| Tool | Why | Install |
| --- | --- | --- |
| macOS 14 (Sonoma) or later | AppKit + SF Symbols | — |
| Xcode Command Line Tools | `swiftc` to build | `xcode-select --install` |
| [Homebrew](https://brew.sh) | installs the deps below | see brew.sh |
| [yabai](https://github.com/koekeishiya/yabai) | window movement/snapping | `brew install koekeishiya/formulae/yabai` |
| [skhd](https://github.com/koekeishiya/skhd) | global hotkeys | `brew install koekeishiya/formulae/skhd` |
| `jq` | `scripts/wm` parses yabai JSON | `brew install jq` |

## Setup on a new Mac

```sh
git clone https://github.com/KDdxb-oss/CommandK.git
cd CommandK
make bootstrap      # installs yabai, skhd, jq via Homebrew
```

`make bootstrap` ends by printing the remaining steps. In full:

1. **Grant Accessibility.** System Settings → Privacy & Security → Accessibility:
   enable **skhd** and **yabai** (and your terminal, so builds can run).
   Without this, neither hotkeys nor window control will work.

2. **Load yabai's scripting addition** (recommended for full window control):

   ```sh
   sudo yabai --install-sa
   sudo yabai --load-sa
   ```

   If you restart yabai often, add `yabai -m signal --add event=dock_did_restart action="sudo yabai --load-sa"`
   to `~/.yabairc`.

3. **Start the services:**

   ```sh
   brew services start skhd
   brew services start yabai
   ```

4. **Install CommandK:**

   ```sh
   make install
   ```

   This builds the app, copies it to `~/.config/CommandK/CommandK.app`, writes
   `~/.skhdrc`, reloads skhd, and registers yabai rules. It only seeds
   `~/.config/CommandK/commands.json` the first time, so re-running `make install`
   will **not** overwrite your shortcuts.

5. **Verify:** press **⌘K**. The palette should appear.

## Using CommandK

- **⌘K** — open / close the palette
- **↑ / ↓** — move the selection
- **Enter** — run the selected command
- **Esc** — dismiss
- **Gear** (top-right) or **⌘,** — open Settings to rebind shortcuts

## Window snapping (Magnet-style)

Works on the focused window. If the window is tiled, `scripts/wm snap` makes it
float first, then positions it with a yabai grid, so it is repeatable.

| Shortcut | Action |
| --- | --- |
| `⇧⌘<` | Left half |
| `⇧⌘>` | Right half |
| `⌘L` | Left third |
| `⇧⌘:` | Center third |
| `⌘'` | Right third |

Each is a normal palette command, so you can re-bind or re-order them in Settings.

## Customizing commands

The palette reads commands from `~/.config/CommandK/commands.json`. Edit it in
Settings (recommended) or by hand, then run:

```sh
~/.config/CommandK/CommandK.app/Contents/MacOS/CommandK --write-skhdrc
```

That regenerates `~/.skhdrc` and reloads skhd. Each entry looks like:

```json
{
  "id": "snap-left-half",
  "title": "Left half",
  "bind": "shift + cmd - 0x2B",
  "command": "~/.config/CommandK/wm snap left-half",
  "aliases": ["magnet left", "tile left"],
  "icon": "rectangle.lefthalf.inset.filled",
  "rank": 1.0
}
```

- `bind` uses skhd syntax (`cmd - l`, `shift + cmd - 0x2B`). Empty string = palette-only.
- `command` is any shell command (run with `zsh -lc`).
- `icon` is an SF Symbol name; `rank` controls default ordering.

> **⌘K is reserved** (passthrough to Superhuman + Linear) and is always owned by the launcher.

## Developing

```sh
make build     # builds build/CommandK.app
make install   # build + deploy to ~/.config/CommandK + reload skhd
./build/CommandK.app/Contents/MacOS/CommandK --settings   # open settings only
```

`scripts/wm` subcommands: `snap <preset>`, `scratch-toggle`, `scratch-add`,
`gaps`, `opacity`, `layout`, `group`, `close-all`, `lock`, `system`.

Verify changes by launching the app and actually driving ⌘K, the arrows, and
Settings — a passing `make build` is not enough.

## Troubleshooting

- **`yabai-msg: failed to connect to socket`** — yabai isn't running:
  `yabai --start-service` (or `brew services start yabai`).
- **Hotkeys do nothing** — skhd lacks Accessibility permission, or needs a
  reload: `skhd --reload`. Check `skhd --version` and the service status.
- **Snapping does nothing** — the focused app may be excluded from yabai, or
  yabai lacks Accessibility. Test with `yabai -m query --windows --window`.
- **Gaps look wrong** — snapping respects your yabai `window_gap`/padding. Toggle
  them with the `gaps` helper.

## Uninstall

```sh
killall CommandK 2>/dev/null
rm -rf ~/.config/CommandK
# remove the binds you no longer want from ~/.skhdrc, then:
skhd --reload
brew services stop skhd yabai
```
