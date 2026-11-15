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
-- The named buttons and window are made through CreateFrame, which
-- luacheck can't see.
globals = {
    "SlashCmdList",
    "UISpecialFrames",

    -- Ours
    "EncoreDB",
    "SLASH_ENCORE1",
}

read_globals = {
    -- Lua extensions the client adds
    "strtrim",

    -- Client constants
    "Enum",
    "BACKPACK_CONTAINER",
    "NUM_BAG_SLOTS",
    "NORMAL_FONT_COLOR",
    "RED_FONT_COLOR",

    -- Blizzard's shared Lua helpers
    "ButtonFrameTemplate_HidePortrait",
    "CreateDataProvider",
    "CreateScrollBoxListLinearView",
    "EventUtil",
    "GameTooltip_AddNormalLine",
    "GameTooltip_Hide",
    "GameTooltip_SetTitle",
    "ItemLocation",
    "ScrollBoxConstants",
    "ScrollUtil",
    "StaticPopup_Visible",
    "hooksecurefunc",

    -- Frames and widgets
    "CreateFrame",
    "UIParent",
    "GameTooltip",
    "ProfessionsFrame",
    "UIErrorsFrame",

    -- Namespaced API
    "C_Container",
    "C_EquipmentSet",
    "C_Item",
    "C_SpellBook",
    "C_Timer",
    "C_TooltipInfo",
    "C_TradeSkillUI",

    -- Loose API functions
    "GetGameMessageInfo",
    "GetInventoryItemLink",
    "GetNumLootItems",
    "GetTime",
    "InCombatLockdown",
    "LootSlot",
    "UnitCastingInfo",
    "issecretvalue",
}
