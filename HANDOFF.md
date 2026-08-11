# Pasty, handoff

Private repo. macOS clipboard manager. Forked from `momenbasel/pesty` (MIT), then
detached and renamed.

## What this app is now

One board. There are no pinboards, no tabs, no second list.

- Every card carries its own pin glyph in the header. One click toggles it.
- Right click a card gives **Pin** / **Unpin** in the context menu.
- Pinned cards sit at the head of the single board in a manual order.
- Reordering is click driven. Hover a pinned card and two chevrons appear in the
  footer, or use **Move Left** / **Move Right** in the context menu. There is no
  drag and drop anywhere and none is needed.
- **One click on any card pastes it into the app you came from.** No double
  click, no Return. Return still works for the keyboard path.
- Pinned cards are never trimmed by the history limit and survive Clear Unpinned.

## Keyboard

| Key | Action |
| --- | --- |
| `Cmd Shift V` | open Pasty (configurable) |
| `Cmd 1` … `Cmd 9` | paste that card |
| `Cmd P` | pin or unpin the highlighted card |
| `Cmd Option ←` / `→` | move a pinned card along |
| `←` `→` `↑` `↓` | move the highlight |
| `Return` | paste the highlighted card |
| `Cmd Delete` | delete the highlighted card |
| `Esc` | clear search, then close |
| any character | types straight into search |

## Data model

`ClipboardStore.items` is a single `[ClipItem]`. **Array order is display
order.** Pinned items occupy the head in the user's manual order, unpinned follow
in recency order. `normalize()` enforces that invariant and is called after every
structural change.

`ClipItem.pinned` is a plain `Bool`. `ClipItem` has a hand written
`init(from:)` using `decodeIfPresent` for every key, because the synthesized
decoder throws on a missing key and an older `store.json` has no `pinned` field.
Losing the whole history to a decode throw is the trap that init prevents.

### Migration, both directions covered

1. **Old store shape.** `Snapshot` decodes `items` if present. If not, it reads
   the legacy `history` + `pinboards` arrays, turns every pinboard card into a
   pinned card in board order, then appends history, skipping content duplicates.
   Nothing the user saved to a board is lost.
2. **Old folder name.** `adoptLegacyDirectoryIfNeeded()` copies
   `~/Library/Application Support/Pesty` to `.../Pasty` on first run if the new
   folder does not exist yet. Copy, not move, so the old build still works if he
   rolls back.

## Renaming, what changed

- Bundle id `com.greycorelabs.pesty` → **`com.mantraproductions.pasty`**.
- `Sources/Pesty` → `Sources/Pasty`, product and binary `Pasty`.
- Application Support folder `Pesty` → `Pasty`.

**Trap:** the bundle id is what macOS keys Accessibility permission and
`UserDefaults` on. After the rename the app is a new identity to the system, so
the Accessibility grant must be given again and settings start at defaults. This
is expected and only happens once.

## Install

`brew tap markoboskoauroville/pasty && brew install --HEAD pasty`

The formula builds from source, which means brew clones this private repo using
whatever git credential is already configured. `gh auth login` once and it works.

**Trap, cost one round trip.** A Homebrew *formula* installs into the Cellar and
has no `App` stanza, so nothing lands in Finder. Only a *cask* installs into
Applications, and a cask needs a signed downloadable artifact, which a
build-from-source private repo does not have. The formula's `post_install` now
links `opt_prefix/Pasty.app` into `/Applications`, falling back to
`~/Applications`. `opt_prefix` is stable across upgrades so the link never goes
stale. Do not "fix" this by converting to a cask without first producing signed
release artifacts.

**Accessibility is lost on every upgrade.** The binary is built locally and not
signed with a Developer ID, so its cdhash changes with each build and macOS
invalidates the Accessibility grant. Toggle Pasty off and on in System Settings,
Privacy and Security, Accessibility after each upgrade. The only real fix is a
Developer ID signature.

`./pasty.sh` is the fallback single file installer with the standard menu. It
targets `/Applications` when writable, otherwise `~/Applications`.

## Open

- No signed release. `release.yml` still expects Developer ID and notarization
  secrets that this repo does not have, so tagging `v*` will fail until those are
  set or the workflow is removed. `ci.yml` builds on every push and is the real
  check.
- `docs/` is the inherited landing page. Renamed but not rewritten.
- Upstream is not a fork link any more. To pull changes:
  `git remote add upstream https://github.com/momenbasel/pesty.git`
