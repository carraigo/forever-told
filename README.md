<p align="center"><img src="media/ForeverTold-logo-book.png" width="200" alt="Forever Told"></p>

# Forever Told

### *Your story, forever told.*

Forever Told writes your adventure down as you play. Every new zone, every level, every boss and every friend goes into a living journal, grouped into chapters as you climb to 60.

And when someone wrongs you, Forever Told never forgets. Grudges get their own page, away from your story. Keep a grudge list, pin **wanted posters** with a gold reward, and share a **bounty board** with your guild so that anyone can take your revenge for you.

Made for **WoW Forever** and **Classic Era / Hardcore**. It uses no combat data on Forever, so it works within the Midnight addon restrictions.

---

## ✒️ The Journal

- **Automatic entries:** first visits, dungeons, level-ups, quest milestones, epic (or rare) loot, gold milestones, profession ranks, first boss kills and deaths, each with a bit of flavour text.
- **Chapters:** your story is split into seven named chapters, from *First Steps* to *Legend*, one for every ten levels.
- **Chapter recaps:** at levels 10, 20, 30 and so on, the chapter you just finished is summed up: new places, quests, dungeon runs, bosses, friends, deeds, deaths and time played.
- **Your own notes:** add a line whenever something memorable happens.
- **Filters and search:** show only places, levels, loot and so on, newest or oldest first, and search any page.
- **Level-up moments:** a slim banner (held until combat ends) and an automatic screenshot every time you ding.

## 🤝 Fellowship

Everyone you've grouped with is remembered: when and where you first met, and how many groups, dungeon runs and boss kills you've shared. Your closest companion sits at the top.

## 🏅 Deeds

35 home-made, vanilla-flavoured badges, from *Hogger Hunter* and *Saddle Up* to *Eastern Kingdoms Delver*, *Survivor* (level 20 without dying), *Sweet Revenge* and *Guild Enforcer*. Progress bars show how close you are to each one.

## ⚔️ Grudges & Revenge

- **Grudge list:** every player who kills you, with their class, level, guild, where they were last seen, and a running score of your revenge against their kills.
- **Sweet revenge:** kill them back and the score updates: *"Sweet revenge on Stabby! Score: 2 to 3."*
- **Nemesis nearby:** a red warning when someone on your list shows up on your nameplates, target or mouseover.
- **Rivalry map:** which zones you get ganked in, where you hit back, and what time of day it happens.

## 📜 Wanted Posters

- Click any grudge to open a parchment **WANTED** poster: portrait, crimes, last seen and reward.
- Set a reward of **none, 1g, 5g, 10g or any amount you like**, then pin it to your guild's board.
- **Share** takes a clean screenshot of just the poster, ready to post on Discord.
- **Posters age:** fresh for the first week, then worn and yellowed, and after three weeks properly weathered, with stains, a torn pin hole and a curled corner. Old grudges stand out at a glance.

## 🏹 Guild Bounty Board

- Guildies running Forever Told share their open grudges automatically.
- **Poster wall:** every guild bounty as a mini poster on wood, highest reward first. Collected ones get a red **AVENGED** stamp.
- **Collect a bounty:** kill anyone on the board and everyone who posted them is avenged: *"Bob avenged you: Stabby is down."*
- **Witness reports:** spot a wanted player and your guild sees *"last seen in Tarren Mill, 3 minutes ago by Bob."*
- **Rewards:** addons can't move gold, so rewards are promises. The poster tracks who owes whom, and the person who posted it marks it paid once they've traded or mailed the gold.

## 📖 Guild Chronicle

A page with one feed for the whole guild. Guildies running Forever Told share their big moments, grouped by day:

- **Every 10th level, and 60**, with time played, quests and places when someone finishes the journey.
- **Epic loot**, and where it dropped.
- **First runs of each dungeon**, with who came along.
- **Deeds earned**, and **Hardcore deaths** with their epitaph.

When you log in, online guildies fill in what you missed. The chronicle keeps the last 30 days, and sharing can be turned off in Settings.

## 🪦 Hardcore epitaph

On a Classic Era **Hardcore** character, death is the end of the story. The journal closes with a final line, and a memorial stone sums up the journey: where you fell and to what, how long you adventured, and everything you did along the way. `/told epitaph` shows it, or on a living character, how it would read today.

## 💾 Backups

Export your whole journal as a text code from Settings (or `/told export`) and keep it somewhere safe. Import it to restore a lost journal, or to carry your story over to another character.

## 🗺️ Atlas & 📊 Stats

- **Atlas:** how much of each continent you've explored (*Eastern Kingdoms · 18 of 34 zones*), with the zones still to explore greyed out. Hover a zone for its story: the level and date you arrived, time spent, quests, foes slain, deaths and ganks there. Tiles show your favourite place, where you've done the most quests and the deadliest zone, plus dungeons and bosses defeated.
- **Stats:** your **deadliest foes**, monster or player, with a nemesis card for your top killer, the **foes you've slain the most**, your toughest kill, time played, fastest and slowest levels, a time-per-level chart, most gold held, bounties collected, and a breakdown of every chapter.

## 🎨 A modern interface

A flat, dark window with sidebar navigation, card-style lists, hover details and stat tiles, instead of Blizzard's stock frames. It can be resized and moved, remembers where you left it, and has a scale setting. A minimap button (draggable) and an entry in the addon compartment are included.

---

## Installing

1. Download the latest release (or **Code → Download ZIP** on this page).
2. Put the files in a folder named exactly `ForeverTold` inside your AddOns folder, for example `World of Warcraft\_classic_era_\Interface\AddOns\ForeverTold\`. `ForeverTold.toc` should sit directly inside it.
3. Restart the game, or type `/reload`, and type `/told`.

## Commands

| Command | What it does |
|---|---|
| `/told` | Open or close the journal (or click the minimap book) |
| `/told grudges` · `bounties` · `wanted` · `rivals` | Jump to a Grudges view |
| `/told fellowship` · `deeds` · `chronicle` · `atlas` · `stats` · `settings` | Open a page |
| `/told note <text>` | Add your own line to the journal |
| `/told recent` | Print the last ten entries to chat |
| `/told export` · `import` | Back up your story, or bring one back |
| `/told epitaph` | Show the Hardcore memorial stone |
| `/told alerts` · `bounty` · `milestones` · `shots` · `banner` · `time` · `rare` · `minimap` | Turn a setting on or off |

`/forevertold` works too.

## Good to know

- **Who killed you:** Classic Era gives addons the combat log, so the killer is exact. WoW Forever closes it, so Forever Told blames whichever enemy was targeting you in your last 15 seconds, and marks it as a best guess.
- **Foes slain** are counted from the "dies, you gain experience" message, so grey enemies that give no experience aren't counted.
- **Guild features** only work with guildies who also run Forever Told. Bounty sharing, witness reports and the chronicle can be turned off in Settings.
- **Time per level** asks the game for `/played` once per login, so you'll see that line in chat once. You can turn it off.
- All data is saved **per character**.

## Project layout

| Folder | What's in it |
|---|---|
| `Core` | Saved data, upgrades, settings, slash commands and the journal itself |
| `Features` | What the addon tracks: fellowship, deeds, recaps, grudges, places, foes, bounties, the guild chronicle, backups and the epitaph |
| `UI` | The widget kit, main window, pop-ups, minimap button and wanted posters |
| `Pages` | One file per page of the journal window |
| `tests` | Automated tests (not shipped in the addon) |
| `media` | Logos for CurseForge and this page (not shipped) |

## Running the tests

The tests load the addon outside the game with stand-in WoW functions and play fake events at it. With Lua 5.4 installed, from the repository root:

```
lua tests/run.lua
```

GitHub runs them on every push too.

---

**Author:** SMUGDUCK

*Found a bug or have an idea? Open an issue on this repository. Red error text from BugSack helps a lot.*
