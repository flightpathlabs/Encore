local _, ns = ...

-- The slash command and the key bindings' labels.
--
-- Nothing needs setting up, so there's no Options page.

-- The bindings themselves are in Bindings.xml. Each presses one of the
-- buttons; the disenchant one only acts while its window is open.
_G["BINDING_NAME_CLICK EncoreRepeatButton:LeftButton"] = "Enchant, skip confirm"
_G["BINDING_NAME_CLICK EncoreDisenchantButton:LeftButton"] = "Disenchant the next item"

SLASH_ENCORE1 = "/encore"
SlashCmdList.ENCORE = function()
    ns.ToggleDisenchant()
end
