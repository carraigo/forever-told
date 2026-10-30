## v1.1

**New**
- Hall of Heroes: a new page listing every character you've played with Forever Told, with their level, chapter, zone, quests, deeds and time played, plus totals for your whole account. Fallen Hardcore characters keep their epitaph stone here, and clicking one shows it in full. Shift-click a character to remove it. `/told heroes` opens it.
- Ten new deeds (45 in all): Thousand Cuts, Ten Thousand Cuts, Bestiary, Tables Turned, Giant Slayer, Eastern Kingdoms Explorer, Kalimdor Explorer, Homebody, In the Chronicles and Heroes All. Any you've already earned are granted quietly on your first login.

**Changes**
- The Chronicle page is now called Guild Chronicles.

## v1.0

**New**
- Guild Chronicle: a new page with one feed for your guild. Guildies running Forever Told share every 10th level (and 60), epic loot, first dungeon runs, deeds and Hardcore deaths, grouped by day. Online guildies fill in what you missed when you log in, and the last 30 days are kept. Turn sharing off in Settings or with `/told milestones`.
- Deadliest foes on the Stats page: what killed you most, monster or player, with a nemesis card for your top killer.
- Foes slain on the Stats page: the foes you've slain the most, total kills, how many different kinds, and your toughest kill. A "Foes slain" tile replaces Places.
- Atlas: completion for each continent ("Eastern Kingdoms · 18 of 34 zones") with the zones still to explore greyed out.
- Atlas: hover a zone for its story: when and at what level you arrived, time spent there, quests, foes slain, deaths and ganks.
- Atlas: tiles for your favourite place, where you've done the most quests and the deadliest zone.

**Changes**
- Dungeons you ran before v1.0 won't be announced in the chronicle.
- Kills and time per zone only start counting from v1.0.

## v0.9

**New**
- Backups: export your whole journal as a text code from Settings or `/told export`, and import it with `/told import` to restore it or carry it over to another character.
- Hardcore epitaph (Classic Era): when a Hardcore character dies, the journal closes with a final line and a memorial stone showing where you fell, to what, and everything you did along the way. `/told epitaph` shows it, or how it would read today.
- Wanted posters now age: fresh for a week, then worn, then weathered after three weeks, with stains, a torn pin hole and a curled corner.

**Under the hood**
- Files are sorted into folders: Core, Features, UI and Pages, with each page in its own file.
- Saved-data upgrades run once per character instead of on every login.
- Automated tests ship with the source.

## v0.8.3

**Fixes**
- Wanted posters: you can now type a custom gold reward straight away. Enter pins or updates the poster in one step.

**Changes**
- Grudges, revenge, wanted posters and bounties no longer appear in your journal. They have their own home on the Grudges page, so your journal stays your story.
- Any old grudge lines are tidied out of your journal the next time you log in.
- The journal's PvP filter has been removed, since it's no longer needed.
