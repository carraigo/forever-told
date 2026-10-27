-- Forever Told text and display data.

local _, ns = ...

ns.FLAVOUR = {
    zone = {
        "Set foot in %s for the first time.",
        "The road led on to %s.",
        "First steps into %s.",
        "Arrived in %s, map in hand.",
    },
    dungeon = {
        "Stepped into %s with a group, blades drawn.",
        "Braved the depths of %s for the first time.",
    },
    level = {
        "Reached level %d in %s.",
        "Level %d, earned in %s.",
        "Ding! Level %d, out in %s.",
    },
    death = {
        "Fell in %s. Got back up.",
        "A rough moment in %s. The spirit healer sends their regards.",
        "Died in %s. It happens to the best of us.",
    },
    boss = {
        "Defeated %s for the first time.",
        "%s falls. The group cheers.",
        "First victory over %s.",
    },
}

ns.MILESTONE_LEVELS = {
    [10] = "Level 10. Talents are open and the real journey begins.",
    [20] = "Level 20. A seasoned adventurer now.",
    [30] = "Level 30. Halfway to legend.",
    [40] = "Level 40. Time to think about a mount.",
    [50] = "Level 50. The end of the road is in sight.",
    [60] = "LEVEL 60. The story of the climb is complete. A new one starts now.",
}

-- Chapter titles, one per ten levels, shown in the journal and on the banner.
ns.CHAPTERS = {
    [0] = "First Steps",
    [1] = "The Wider World",
    [2] = "Roads and Rivals",
    [3] = "Into the Wilds",
    [4] = "Fortune and Steel",
    [5] = "The Last Stretch",
    [6] = "Legend",
}

ns.SKILL_MILESTONES = { [75] = "Journeyman", [150] = "Expert", [225] = "Artisan", [300] = "Master" }

-- Every kind of entry: its colour, and the journal filter it belongs to.
ns.KINDS = {
    start = { colour = "c9a227", filter = "journey" },
    zone = { colour = "8fd18f", filter = "journey" },
    dungeon = { colour = "7fb2ff", filter = "journey" },
    level = { colour = "ffd100", filter = "levels" },
    quest = { colour = "e6e1d3", filter = "quests" },
    loot = { colour = "a335ee", filter = "treasure" },
    gold = { colour = "f2d37a", filter = "treasure" },
    boss = { colour = "ff8040", filter = "bosses" },
    skill = { colour = "6fb7ff", filter = "skills" },
    death = { colour = "ff6b5b", filter = "deaths" },
    note = { colour = "c7a7ff", filter = "notes" },
    fellow = { colour = "40c7eb", filter = "fellows" },
    recap = { colour = "c9a227", filter = "levels" },
    deed = { colour = "ff9d2e", filter = "deeds" },
    pvp = { colour = "e05a4c", filter = "pvp" },
    revenge = { colour = "ff4f6d", filter = "pvp" },
}

ns.FILTERS = {
    { id = "all", label = "Everything" },
    { id = "journey", label = "Places" },
    { id = "levels", label = "Levels" },
    { id = "quests", label = "Quests" },
    { id = "treasure", label = "Treasure" },
    { id = "bosses", label = "Bosses" },
    { id = "skills", label = "Skills" },
    { id = "deaths", label = "Deaths" },
    { id = "fellows", label = "Friends" },
    { id = "deeds", label = "Deeds" },
    { id = "pvp", label = "PvP" },
    { id = "notes", label = "Notes" },
}

ns.ICON = "Interface\\Icons\\INV_Misc_Book_09"
