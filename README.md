### [Download the latest build](https://github.com/markoboskoauroville/Pasty/releases/latest)

# Pasty

A clipboard manager for macOS. One board, pins in place.

Forked from [momenbasel/pesty](https://github.com/momenbasel/pesty) (MIT), then
detached and reworked around a single unified board.

## What is different from the original

The original kept pinned clips in separate named pinboards behind their own tabs.
Pasty removes that idea entirely.

- **One board.** No tabs, no second list, no switching.
- **A pin on every card.** One click on the pin glyph holds a clip at the front.
- **Right click gives Pin and Unpin**, alongside Paste, Copy and Delete.
- **Reorder by clicking.** Hover a pinned card and two chevrons appear, or use
  Move Left and Move Right in the context menu. No drag and drop.
- **One click pastes.** Click any card and it goes straight into the app you were
  in a moment ago. No double click, no Return.
- Pinned cards ignore the history limit and survive Clear Unpinned.

## Keys

| Key | Action |
| --- | --- |
| `Cmd Ctrl A` | open Pasty |
| `Cmd 1` … `Cmd 9` | paste that card |
| `Cmd P` | pin or unpin the highlighted card |
| `Cmd Option ←` / `→` | move a pinned card along |
| `Return` | paste the highlighted card |
| `Esc` | clear search, then close |

Typing anything with the bar open searches immediately.

## Install

Homebrew:

```
brew tap markoboskoauroville/pasty
brew install --HEAD pasty
```

Or the single file installer, which asks nothing and takes one keypress:

```
./pasty.sh
```

Both build from source and put `Pasty.app` in your Applications folder.

Pasty is a menu bar app with no Dock icon. Open it once from Applications, then
reach it with `Cmd Ctrl A` or the clipboard icon in the menu bar.

One click pasting needs Accessibility permission, which macOS asks for on first
use. Because the app is built locally and not signed with a Developer ID, macOS
forgets that grant whenever the binary changes, so switch Pasty off and on again
in System Settings, Privacy and Security, Accessibility after an upgrade.

## Build by hand

```
swift build -c release
VERSION=1.0.0 BUILD=1 ./scripts/build_app.sh
```

## Licence

MIT, inherited from the upstream project.
