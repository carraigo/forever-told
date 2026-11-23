# How Forever Told works

Forever Told is a plain WoW addon: Lua files loaded in TOC order, sharing one namespace table (`ns`). There are no libraries. This page is for anyone changing the code.

## Loading

`ForeverTold.toc` and `ForeverTold_Vanilla.toc` are identical (a test checks): WoW Forever and Classic Era both read one of them. Files load in this order:

| Folder | What's in it |
|---|---|
| `Core` | `Data.lua` (flavour text, deeds, milestones), `Util.lua` (`ns.U`: secret-value-safe helpers, formatting), `Core.lua` (saved data, upgrades, events, settings, slash commands, the journal), `Diagnostics.lua` (bug report, profiler, self-test, blocked-call catcher) |
| `Features` | What the addon tracks: fellowship, recaps, deeds, grudges, places, foes, the bounty board and guild channel, the guild chronicle, backups, the epitaph, the Hall of Heroes, and what's new |
| `UI` | `Skin.lua` (the widget kit), wanted posters, the window, pop-ups, the minimap button and the game Options page |
| `Pages` | One file per page of the window, each registering itself in `ns.Pages` |

## Events

One frame in `Core.lua` registers every event any file asked for with `ns.On(event, fn)`, at `ADDON_LOADED`, after the saved data is ready. Each listener runs through `ns.Guard(where, fn, ...)`: an error is written to the error log and the other listeners still run. `COMBAT_LOG_EVENT_UNFILTERED` is only registered where `issecretvalue` doesn't exist (Classic Era): on WoW Forever even registering it raises the "blocked functionality" popup.

Features talk to each other with `ns.Emit(name, ...)` / `ns.Listen(name, fn)` (level, loot, boss, quest, deed, epitaph), so the journal, the atlas and the chronicle don't call each other directly.

Slash words live in `ns.Commands` (`ns.Commands.bug = function(rest) ... end`); `/told <page>` opens a page; settings flip by their `slash` word from `ns.SETTINGS`.

## Secret values

WoW Forever hides some answers from addons in dungeons ("secret values"): even testing one with `if` is an error. Ask the game through `U.Ask(fn, ...)`, `U.Is` and `U.IsNot`, which return nothing when any answer is secret, and check event arguments with `U.issecret` before using them.

## Saved data

- `ForeverToldDB` (per character): the journal and everything tracked. `Core.lua` lists its tables (`TABLES`) and counters (`VALUES`), filled in on load.
- `ForeverToldAccountDB` (account): the Hall of Heroes, the error log, the profiler switch and the last version seen.

Upgrades are the `MIGRATIONS` list in `Core.lua`. `DB.version` counts how many have run, so each runs once per character, in order. Add new ones to the end; never reorder or remove one.

## The guild channel

Prefix `FTold1`, `GUILD` only, fields split by `~`. `Features/Bounty.lua` documents every message and owns sending: a queue that sends a burst of 8, then about one a second, and puts a message the game holds back (`Enum.SendAddonMessageResult` throttled) back at the front to try again. Other features add message kinds through `ns.GuildHandlers[kind]` and send with `ns.GuildSend`. WoW Forever names senders `Name Surname`; they're stored as `Name-Surname`.

A hello (`H`) at login asks guildies for their bounties and the chronicle news since you were last online; the answer (`I`) says they run Forever Told too. Both carry the sender's version (1.3.0 on), for the newer-version notice.

## The window

`UI/Window.lua` builds the window once, on first open. `ns.Refresh()` asks for a redraw: it waits for the next frame and redraws once however often it's called, so a burst of guild messages costs one redraw. `ns.RefreshNow()` redraws straight away (opening, switching pages). The window's `OnUpdate` only runs while it's fading in or a redraw from typing or resizing is waiting, and stops itself after.

Lists are `S.List` from `UI/Skin.lua`: rows are pooled and reused, so a 5,000-entry journal stays light.

## Diagnostics

- `/told errors`: the error log (`ns.LogError`), one line per distinct error with a count. Errors not seen for two weeks are dropped at login. `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN` for Forever Told go in it too. Each error still goes to the game's error handler (or BugSack).
- `/told bug`: everything above plus version, client, memory, load times, saved data sizes and the guild channel, in a box to copy.
- `/told perf on|off|reset`: while on, `ns.Guard` times every listener and guild handler. Off, `ns.Guard` is a plain `pcall`.
- `/told selftest`: the game functions each feature needs, the saved data, and every page building its rows.

## Tests

`tests/stubs.lua` stands in for the WoW API, just enough to load the addon outside the game: frames record what they're told, `C_Timer.After` runs at once, and `NOWT` is the game clock. `tests/run.lua` loads the files in TOC order, fires fake events and checks what was saved, sent and shown. `tests/speed.lua` builds a long-played character and a busy guild and fails when a page, a login burst or the bug report passes its limit.

```
luacheck .
lua5.1 tests/run.lua
lua5.1 tests/speed.lua
```

GitHub Actions run all three on every push (`.github/workflows/tests.yml`), and the tests on LuaJIT too.

## Releasing

1. Bump `## Version:` in both TOCs, add a `## vX.Y.Z` section at the top of `CHANGELOG.md` and an entry at the top of `ns.NOTES` in `Features/News.lua`. The tests fail until all three agree.
2. Merge to `main`, then tag: `git tag vX.Y.Z && git push origin vX.Y.Z`.
3. `.github/workflows/release.yml` runs the tests, checks both TOCs carry the tag's version, zips only what the game loads into `ForeverTold-vX.Y.Z.zip`, and makes a GitHub release with every changelog section since the last tag. A tag with a dash (`v1.4.0-beta.1`) makes a pre-release. `.pkgmeta` lets the CurseForge packager build the same zip.
