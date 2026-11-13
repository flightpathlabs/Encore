local _, ns = ...

-- Encore's page in the game's Options window, the slash command, and the
-- key binding's label.
--
-- Nothing needs setting up. These are only for people who'd rather answer
-- the replace prompt themselves, or keep going after the skill-ups stop.

local PREFIX = "Encore_"

local category

local function AddCheckbox(key, label, tooltip)
    local setting = Settings.RegisterAddOnSetting(
        category,
        PREFIX .. key,
        key,
        ns.settings,
        Settings.VarType.Boolean,
        label,
        ns.DEFAULT_SETTINGS[key]
    )
    Settings.SetOnValueChangedCallback(PREFIX .. key, ns.RefreshRepeat)
    Settings.CreateCheckbox(category, setting, tooltip)
end

ns.OnEvent("PLAYER_LOGIN", function()
    category = Settings.RegisterVerticalLayoutCategory(ns.TITLE)

    AddCheckbox(
        "answerPrompt",
        "Answer the replace prompt",
        "When the item already has an enchant, the game asks whether to replace it. "
            .. "With this on, the press that casts also says Yes. With it off, the next "
            .. "press says Yes."
    )
    AddCheckbox(
        "stopWhenNoSkill",
        "Stop when the skill-ups stop",
        "End the run when the enchant turns grey or Enchanting reaches the cap for "
            .. "your rank. Running out of materials always ends it."
    )

    Settings.RegisterAddOnCategory(category)
end)

-- The binding itself is in Bindings.xml. It presses the Repeat button, so
-- it works whenever that button is showing.
_G["BINDING_NAME_CLICK EncoreRepeatButton:LeftButton"] = "Repeat the enchant"

SLASH_ENCORE1 = "/encore"
SlashCmdList.ENCORE = function(message)
    if strtrim(message or ""):lower() == "stop" then
        ns.StopRepeat()
        return
    end
    Settings.OpenToCategory(category:GetID())
end
