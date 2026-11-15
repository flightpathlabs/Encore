local _, ns = ...

-- The "Enchant, skip confirm" button in the Professions window.
--
-- Levelling Enchanting often means putting the same enchant on the same
-- item over and over, and every cast after the first stops to ask whether
-- to replace the enchant already there. This button sits beside the
-- window's own Enchant button and does both in one press: it casts, and
-- says Yes to that prompt.
--
-- It's still one press per cast. The game wants a real key press or click
-- for each one, and an addon that casts by itself is exactly what that
-- rule is there to stop.
--
-- Nothing here calls the craft functions either: casting is the window's
-- own business, and calling those functions from addon code taints the
-- client's crafting path (SkillUp Forever found potions refused until a
-- /reload). So the button is a secure button that runs a two-line macro:
--
--   /click EncoreCastButton     presses the window's own Enchant button
--   /click EncoreAnswerButton   presses Yes on the replace prompt, if this
--                               same press opened one
--
-- Both are hidden secure buttons pointed at Blizzard's buttons just before
-- the press goes through, so the client casts and answers as its own code.
-- The prompt is only ever answered when this button's press opened it,
-- never one the player brought up some other way.

-- The prompt the game raises before the window's enchant slot replaces an
-- enchant. REPLACE_ENCHANT is left out on purpose: that one comes from an
-- enchant or kit put on by hand with the cursor, which is never ours.
local REPLACE_PROMPT = "REPLACE_TRADESKILL_ENCHANT"

-- If the prompt turns up a moment after the press rather than during it,
-- it still counts as that press's own for this long, in seconds, and the
-- next press answers it.
local PROMPT_GRACE = 2

local LABEL = "Enchant, skip confirm"

local CAST_LINE = "/click EncoreCastButton"
local ANSWER_LINE = "/click EncoreAnswerButton"

local page -- the Professions window's crafting page, once it has loaded
local skipButton

local castGUID -- the enchant this button cast, while it's underway
local pressing = false -- between a press's PreClick and PostClick
local lastPress = 0
local promptWhich -- a replace prompt that one of this button's presses opened

--- A hidden secure button that presses whichever button its "clickbutton"
--- attribute names. The macro reaches it by its global name.
local function CreateClicker(name)
    local button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    button:SetAttribute("type", "click")
    -- /click sends a button-up press. Forever acts on key-down by default
    -- (ActionButtonUseKeyDown), so without this the press would be ignored.
    button:SetAttribute("useOnKeyDown", false)
    button:RegisterForClicks("AnyUp")
    return button
end

local castButton = CreateClicker("EncoreCastButton")
local answerButton = CreateClicker("EncoreAnswerButton")

--- The enchant the window has picked, if it's going on a single item. A
--- stack of something (vellum, say) is left to the window's own Enchant All.
---@return number? recipeID
local function Selection()
    if not (page and page:IsVisible() and page.CreateButton:IsShown()) then
        return nil
    end

    local form = page.SchematicForm
    local recipe = form:GetRecipeInfo()
    local transaction = form:GetTransaction()
    if not (recipe and transaction) then
        return nil
    end
    if not transaction:IsRecipeType(Enum.TradeskillRecipeType.Enchant) then
        return nil
    end

    local item = transaction:GetEnchantAllocation()
    if not item or item:IsStackable() then
        return nil
    end
    return recipe.recipeID
end

local function Refresh()
    -- The button is secure, so it's left alone during a fight. Leaving
    -- combat refreshes it.
    if not skipButton or InCombatLockdown() then
        return
    end
    skipButton:SetShown(Selection() ~= nil)
    skipButton:SetEnabled(page.CreateButton:IsEnabled())
end

--- Points the answer button at the Yes button of a replace prompt that's
--- showing, or at nothing.
local function ArmAnswer(which)
    local _, dialog = StaticPopup_Visible(which)
    local yes = dialog and dialog.ButtonContainer and dialog.ButtonContainer.Button1
    answerButton:SetAttribute("clickbutton", yes)
end

-- Runs before the secure press. Everything it decides goes into the
-- button's macro, which is cleared again after every press, so a press
-- this can't vouch for (in combat, say) does nothing at all.
local function PreClick(self, mouseButton)
    if InCombatLockdown() or mouseButton ~= "LeftButton" then
        return
    end

    -- A prompt from an earlier press that's still waiting, because it
    -- arrived a moment late: this press answers it, and the cast goes on.
    if promptWhich and StaticPopup_Visible(promptWhich) then
        ArmAnswer(promptWhich)
        self:SetAttribute("*macrotext1", ANSWER_LINE)
        pressing = true
        return
    end
    promptWhich = nil

    if not Selection() then
        return
    end

    if castGUID then
        if UnitCastingInfo("player") then
            -- Still casting the last one.
            return
        end
        -- The cast ended without saying so. Don't let that stick.
        castGUID = nil
    end

    castButton:SetAttribute("clickbutton", page.CreateButton)
    self:SetAttribute("*macrotext1", CAST_LINE .. "\n" .. ANSWER_LINE)
    pressing = true
    lastPress = GetTime()
end

local function PostClick(self)
    pressing = false
    if not InCombatLockdown() then
        self:SetAttribute("*macrotext1", nil)
        castButton:SetAttribute("clickbutton", nil)
        answerButton:SetAttribute("clickbutton", nil)
    end
end

-- The replace prompt opens from inside the window's own Enchant button
-- press, between the macro's two lines. Arming the answer button here is
-- what lets the second line say Yes to it.
hooksecurefunc("StaticPopup_Show", function(which)
    if which ~= REPLACE_PROMPT then
        return
    end
    if not pressing and GetTime() - lastPress > PROMPT_GRACE then
        return
    end

    promptWhich = which
    if pressing and not InCombatLockdown() then
        ArmAnswer(which)
    end
end)

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip_SetTitle(GameTooltip, LABEL)
    GameTooltip_AddNormalLine(
        GameTooltip,
        "Casts the enchant on the chosen item, and if it already has an enchant, "
            .. "says Yes to replacing it, all in one press."
    )
    GameTooltip_AddNormalLine(
        GameTooltip,
        "Press once for each cast. You can bind a key to it under Options > Keybindings > Encore."
    )
    GameTooltip:Show()
end

local function Build()
    page = ProfessionsFrame.CraftingPage

    -- The window's own Enchant All button and count box sit here for a
    -- recipe that can be made in batches. They're hidden for an enchant on
    -- a single item, which is the only time this button shows.
    skipButton = CreateFrame(
        "Button",
        "EncoreRepeatButton",
        page,
        "SharedButtonSmallTemplate,SecureActionButtonTemplate"
    )
    skipButton:SetSize(150, 22)
    skipButton:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -100, 7)
    skipButton:SetText(LABEL)
    skipButton:SetAttribute("*type1", "macro")
    -- Act on release for a click, a key binding and /click alike, whatever
    -- the game's ActionButtonUseKeyDown says, so one press is always
    -- exactly one go.
    skipButton:SetAttribute("useOnKeyDown", false)
    skipButton:RegisterForClicks("AnyUp")
    skipButton:SetScript("PreClick", PreClick)
    skipButton:SetScript("PostClick", PostClick)
    skipButton:SetScript("OnEnter", ShowTooltip)
    skipButton:SetScript("OnLeave", GameTooltip_Hide)
    skipButton:Hide()

    -- ValidateControls is where the window decides what its own buttons
    -- show, on every change of recipe, item, bags or skill. Following it
    -- keeps this button in step without watching all of that separately.
    hooksecurefunc(page, "ValidateControls", Refresh)
    page:HookScript("OnShow", Refresh)

    Refresh()
end

ns.OnEvent("PLAYER_LOGIN", function()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", Build)
end)

-- The client can hand these payloads over as secret values; ns.Readable
-- turns those into nil, which never matches, so such a cast is ignored.

ns.OnPlayerEvent("UNIT_SPELLCAST_START", function(guid, spellID)
    if pressing or GetTime() - lastPress < PROMPT_GRACE then
        local recipeID = Selection()
        if recipeID and ns.Readable(spellID) == recipeID then
            castGUID = ns.Readable(guid)
        end
    end
end)

local function CastEnded(guid)
    if castGUID and ns.Readable(guid) == castGUID then
        castGUID = nil
        promptWhich = nil
    end
end

ns.OnPlayerEvent("UNIT_SPELLCAST_SUCCEEDED", CastEnded)
ns.OnPlayerEvent("UNIT_SPELLCAST_FAILED", CastEnded)
ns.OnPlayerEvent("UNIT_SPELLCAST_INTERRUPTED", CastEnded)
ns.OnPlayerEvent("UNIT_SPELLCAST_STOP", CastEnded)

ns.OnEvent("PLAYER_REGEN_ENABLED", Refresh)
