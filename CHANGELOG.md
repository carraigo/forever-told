## v0.9

**New**
- Backups: export your whole journal as a text code from Settings or `/told export`, and import it with `/told import` to restore it or carry it over to another character.
- Hardcore epitaph (Classic Era): when a Hardcore character dies, the journal closes with a final line and a memorial stone showing where you fell, to what, and everything you did along the way. `/told epitaph` shows it, or how it would read today.
- Wanted posters now age: fresh for a week, then worn, then weathered after three weeks, with stains, a torn pin hole and a curled corner.

**Under the hood**
- Each page now lives in its own file.
- Saved-data upgrades run once per character instead of on every login.
- Automated tests ship with the source.

## v0.8.3

**Fixes**
- Wanted posters: you can now type a custom gold reward straight away. Enter pins or updates the poster in one step.

**Changes**
- Grudges, revenge, wanted posters and bounties no longer appear in your journal. They have their own home on the Grudges page, so your journal stays your story.
- Any old grudge lines are tidied out of your journal the next time you log in.
- The journal's PvP filter has been removed, since it's no longer needed.
