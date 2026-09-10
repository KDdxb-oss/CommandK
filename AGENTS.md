# CommandK

macOS command palette for yabai/skhd. One user: the machine owner.

## Stack

Swift + AppKit. Build with `make build`. Install with `make install` (copies to `~/.config/CommandK`, writes `~/.skhdrc`, reloads skhd).

## Layout

- `Sources/App.swift` — palette + settings windows
- `Sources/Config.swift` — load/save `commands.json`, generate skhdrc
- `Sources/Keys.swift` — NSEvent ↔ skhd bind ↔ glyph
- `Resources/commands.json` — default command list
- `scripts/wm` — yabai helpers (layout, scratchpad, lock)

## Rules

- `commands.json` is the source of truth for shortcuts. Never hand-edit `~/.skhdrc`.
- Keep ⌘K reserved (passthrough Superhuman + Linear).
- Verify by launching the app and driving ⌘K, arrows, and Settings — `make build` passing is not enough.
