## v1.2.0

**New**
- Forever Told keeps its own error log. WoW Forever doesn't save Lua errors anywhere, so now when part of Forever Told goes wrong it writes the error down (one line per error, with a count, version and character), tells you once in chat, and carries on with everything else. Type `/told errors` to see them, or `/told errors clear` to empty the log. Errors still go to the game's error display or BugSack as before.

**Fixes**
- Dungeon runs from before 1.1.5 move to the right dungeon. Runs that were counted under the zone outside the door (Orgrimmar for Ragefire Chasm, Silverpine Forest for Shadowfang Keep, the cave outside Wailing Caverns) are moved to the dungeon, once, as long as you've only been in one dungeon with its door there. Your total number of runs doesn't change.
- Stats page: fastest and slowest level now count from level 10, so the minutes-long early levels don't always win "fastest".

## v1.1.6

**Fixes**
- No more grudges against your own group or guild. If a party member, raid member or guildie turns on you for a moment (Arugal's Curse in Shadowfang Keep, a mind control) and you die, it isn't counted as a gank and no wanted poster goes up. Grudges an older version made against guildies are forgiven at login, and their posters come down from the guild's boards.
- Your own wanted posters no longer echo back onto your bounty board as if someone else had posted them.
- The Hall of Heroes keeps your last real zone instead of saying "somewhere unknown" when you log out mid-loading screen.

**New**
- Forgive a grudge: right-click it on the Grudges page, or type `/told forgive <name>`. The grudge is forgotten and your wanted poster comes down from the guild's boards.

## v1.1.5

**Fixes**
- WoW Forever: you no longer show up as one of your own guildies. WoW Forever sends guild messages as "Name Surname", so Forever Told didn't recognise its own messages coming back, listed you on the Guild Chronicles page, answered your own hello and sent all your news to the guild twice. Guildies saved under "Name Surname" are tidied up too, so nobody is counted twice.
- Dungeons are now filed under the dungeon's own name. On the loading screen in, the game could still name the zone outside, so Ragefire Chasm runs counted as Orgrimmar and time spent in Wailing Caverns went to the cave outside. A dungeon first noted as an ordinary zone is marked as a dungeon on your next visit, or straight away if you've killed a boss there.
- "somewhere unknown" is no longer saved as a place you've discovered, and is removed from your atlas and places count.

## v1.1.4

**Fixes**
- WoW Forever: no more stream of Lua errors in dungeons ("Foes.lua:79: attempt to perform boolean test on local 'yes' (a secret boolean value)"). Inside instances the game keeps some answers secret from addons, such as who an enemy is targeting. Forever Told now checks every answer before using it and treats a secret one as "don't know". The same fix covers grudge tracking, nemesis alerts, group members, famous kills and boss kills.

## v1.1.3

**Fixes**
- Guild Chronicles: guildies running Forever Told now show up as soon as they log in, not only once they've had a milestone. The page lists who else keeps a journal, with their level, and counts them in "Guildies keeping a journal".
- Guild Chronicles: logging in now catches up on everything guildies did while you were away. Before, your own newest milestone hid any of theirs from before it.
- Guild messages are paced to about one a second after a short burst, so the game no longer drops them when a guildie logs in and everyone replies at once.
- If the game hasn't said you're in a guild yet 10 seconds after login, Forever Told tries again instead of staying quiet all session.

**New**
- `/told guild` says hello to your guild and shows whether the guild channel is working: messages sent and heard, and which guildies run Forever Told.

## v1.1.2

**Fixes**
- WoW Forever: no more "blocked functionality" (Ignore / Disable) popup at login. Forever Told no longer asks for the combat log there, since WoW Forever doesn't share it with addons. Classic Era still uses it.

## v1.1.1

**Fixes**
- Hall of Heroes: the page no longer shows a Lua error when a character in the hall has no zone saved.

**Under the hood**
- The automated tests now run on Lua 5.1, the version the game uses, as well as 5.4.

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
