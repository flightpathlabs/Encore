-- Luacheck configuration for Encore.
-- Run from the addon's folder:  luacheck .
--
-- There is no maintained luacheck "std" for the 12.x / Forever API, so we
-- list the globals we actually touch. A typo in an API name then shows up
-- as a lint warning instead of a nil error in game.

std = "lua51"
max_line_length = 100
max_string_line_length = false
max_comment_line_length = 100
codes = true

exclude_files = {
    "Libs/**",
    ".release/**",
}

ignore = {
    "212/self", -- unused "self" on script handlers is normal
}

-- The only globals Encore creates: its saved settings and slash command.
-- The named buttons are made through CreateFrame, which luacheck can't see.
globals = {
    "SlashCmdList",

    -- Ours
    "EncoreDB",
    "SLASH_ENCORE1",
}

read_globals = {
    -- Lua extensions the client adds
    "strtrim",

    -- Client constants
    "Enum",

    -- Blizzard's shared Lua helpers
    "EventUtil",
    "GameTooltip_AddNormalLine",
    "GameTooltip_Hide",
    "GameTooltip_SetTitle",
    "StaticPopup_Visible",
    "hooksecurefunc",

    -- Frames and widgets
    "CreateFrame",
    "UIParent",
    "GameTooltip",
    "ProfessionsFrame",
    "Settings",

    -- Namespaced API
    "C_TradeSkillUI",
    "C_Timer",

    -- Loose API functions
    "GetTime",
    "InCombatLockdown",
    "UnitCastingInfo",
    "issecretvalue",
}
