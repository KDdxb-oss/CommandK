# CommandK

Superhuman-style command palette for macOS window management (yabai + skhd).

Press **⌘K**, type what you want, Enter runs it. Arrow keys move the selection. Every shortcut is listed. Change keybindings in Settings (gear, or type “settings”).

## Install

```
make install
```

Requires [yabai](https://github.com/asmvik/yabai) and [skhd](https://github.com/asmvik/skhd).

## Use

- **⌘K** — open / close CommandK
- **↑ / ↓** — select a command
- **Enter** — run
- **Esc** — dismiss
- **Gear** or type `settings` — edit shortcuts

Config: `~/.config/CommandK/commands.json`  
Generated binds: `~/.skhdrc`
