local _, ns = ...

-- The Repeat button in the Professions window.
--
-- Pick an enchant and the item to put it on in the window as usual, type
-- how many casts you want into the box beside Repeat, and press Repeat
-- once for each cast. Each press casts the enchant on that item and, when
-- the item already carries an enchant, says Yes to the prompt asking
-- whether to replace it.
--
-- Why a press for every cast: the game wants a real key press or click
-- for each one. An addon that casts by itself on a timer is exactly what
-- that rule is there to stop, so this doesn't try.
--
-- Why nothing here calls the craft functions: casting is the window's own
-- business, and calling those functions from addon code taints the
-- client's crafting path. SkillUp Forever found that out the hard way
-- (potions refused until a /reload). So Repeat is a secure button that
-- runs a two-line macro:
--
--   /click EncoreCastButton     presses the window's own Enchant button
--   /click EncoreAnswerButton   presses Yes on the replace prompt, if this
--                               same press opened one
--
-- Both are hidden secure buttons pointed at Blizzard's buttons just before
-- the press goes through, so the client casts and answers as its own code.
-- The prompt is only ever answered when it opened because of a Repeat
-- press, never one the player brought up some other way.

-- The prompt the game raises before the window's enchant slot replaces an
-- enchant. REPLACE_ENCHANT is left out on purpose: that one comes from an
-- enchant or kit put on by hand with the cursor, which is never ours.
local REPLACE_PROMPT = "REPLACE_TRADESKILL_ENCHANT"

-- If the prompt turns up a moment after the press rather than during it,
-- it still counts as that press's own for this long, in seconds, and the
-- next press answers it.
local PROMPT_GRACE = 2

-- How long a "why the run ended" note stays beside the button, in seconds.
local NOTE_TIME = 10

local CAST_LINE = "/click EncoreCastButton"
local ANSWER_LINE = "/click EncoreAnswerButton"

local page -- the Professions window's crafting page, once it has loaded
local row, countBox, countLabel, status, repeatButton

-- The run in progress, or nil:
--   recipeID, itemGUID   what is being repeated
--   total, left          casts asked for, and casts still to go
--   castGUID             the cast underway, while there is one
local run

-- Why the last run ended, while that is still worth showing:
--   short   beside the button
--   long    in the button's tooltip
local note, noteToken

local pressing = false -- between a Repeat press's PreClick and PostClick
local lastPress = 0
local promptWhich -- a replace prompt that a Repeat press opened

local Refresh

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

local function SetNote(short, long)
    note = { short = short, long = long }
    local token = {}
    noteToken = token
    C_Timer.After(NOTE_TIME, function()
        if noteToken == token then
            note = nil
            Refresh()
        end
    end)
end

local function Finish(short, long)
    run = nil
    promptWhich = nil
    if short then
        SetNote(short, long)
    end
end

--- What the window has picked, if it's something to repeat: an enchant
--- and a single item to put it on. A stack of something (vellum, say) is
--- left to the window's own Enchant All button.
---@return number? recipeID
---@return string? itemGUID
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
    return recipe.recipeID, item:GetItemGUID()
end

--- Why the run should end before another cast, or nil to carry on.
---@return string? short
---@return string? long
local function StopReason()
    if run.left <= 0 then
        return ("All %d done"):format(run.total)
    end

    if ns.Readable(C_TradeSkillUI.GetCraftableCount(run.recipeID)) == 0 then
        return "Out of materials", "You don't have the materials for another cast."
    end

    if ns.settings.stopWhenNoSkill then
        local profession = C_TradeSkillUI.GetProfessionInfoByRecipeID(run.recipeID)
        local level = ns.Readable(profession.skillLevel)
        local cap = ns.Readable(profession.maxSkillLevel)
        if level and cap and cap > 0 and level >= cap then
            return "At the skill cap",
                ("%s is at %d of %d. Train the next rank to keep going."):format(
                    profession.professionName,
                    level,
                    cap
                )
        end

        local recipe = C_TradeSkillUI.GetRecipeInfo(run.recipeID)
        local grey = Enum.TradeskillRelativeDifficulty.Trivial
        if recipe and recipe.relativeDifficulty == grey then
            return "No more skill-ups",
                "This enchant has turned grey, so it won't raise your skill."
        end
    end

    if not page.CreateButton:IsEnabled() then
        return "Can't cast it now",
            "The window's Enchant button is greyed out. Point at it to see why."
    end
    return nil
end

function Refresh()
    if not row then
        return
    end

    local recipeID, itemGUID = Selection()

    -- A run belongs to one enchant on one item. Picking anything else, or
    -- closing the window, ends it without fuss.
    if run and (run.recipeID ~= recipeID or run.itemGUID ~= itemGUID) then
        Finish()
    end

    if run and not run.castGUID then
        local short, long = StopReason()
        if short then
            Finish(short, long)
        end
    end

    -- The row holds a secure button, so it's left alone during a fight.
    -- Leaving combat refreshes it.
    if InCombatLockdown() then
        return
    end

    row:SetShown(recipeID ~= nil)
    local text = run and ("%d of %d left"):format(run.left, run.total) or note and note.short
    status:SetText(text or "")
    status:SetShown(text ~= nil)
    countBox:SetShown(text == nil)
    countLabel:SetShown(text == nil)
    repeatButton:SetText(run and "Enchant again" or "Repeat")
end

local function SavedCount()
    local count = tonumber(countBox:GetText()) or ns.settings.count
    count = math.max(1, math.min(ns.MAX_COUNT, math.floor(count)))
    ns.settings.count = count
    return count
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

    -- A prompt from an earlier press that's still waiting: it arrived a
    -- moment late, or answering in the same press is turned off. This press
    -- answers it, and that lets the cast go ahead.
    if promptWhich and StaticPopup_Visible(promptWhich) then
        ArmAnswer(promptWhich)
        self:SetAttribute("*macrotext1", ANSWER_LINE)
        pressing = true
        return
    end
    promptWhich = nil

    local recipeID, itemGUID = Selection()
    if not recipeID then
        return
    end

    if run and (run.recipeID ~= recipeID or run.itemGUID ~= itemGUID) then
        Finish()
    end

    if run and run.castGUID then
        if UnitCastingInfo("player") then
            -- Still casting the last one.
            return
        end
        -- The cast ended without saying so (a lone STOP, say). Don't let
        -- that leave the button stuck.
        run.castGUID = nil
    end

    if not run then
        local count = SavedCount()
        note = nil
        run = {
            recipeID = recipeID,
            itemGUID = itemGUID,
            total = count,
            left = count,
        }
    end

    local short, long = StopReason()
    if short then
        Finish(short, long)
        Refresh()
        return
    end

    castButton:SetAttribute("clickbutton", page.CreateButton)
    local macro = CAST_LINE
    if ns.settings.answerPrompt then
        macro = CAST_LINE .. "\n" .. ANSWER_LINE
    end
    self:SetAttribute("*macrotext1", macro)
    pressing = true
    lastPress = GetTime()
    Refresh()
end

local function PostClick(self, mouseButton)
    pressing = false
    if not InCombatLockdown() then
        self:SetAttribute("*macrotext1", nil)
        castButton:SetAttribute("clickbutton", nil)
        answerButton:SetAttribute("clickbutton", nil)
    end

    if mouseButton == "RightButton" and run then
        Finish("Stopped")
    end
    Refresh()
end

-- The replace prompt opens from inside the window's own Enchant button
-- press, between the macro's two lines. Arming the answer button here is
-- what lets the second line say Yes to it.
hooksecurefunc("StaticPopup_Show", function(which)
    if not (which == REPLACE_PROMPT and run) then
        return
    end
    if not pressing and GetTime() - lastPress > PROMPT_GRACE then
        return
    end

    promptWhich = which
    if pressing and ns.settings.answerPrompt and not InCombatLockdown() then
        ArmAnswer(which)
    end
end)

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if run then
        GameTooltip_SetTitle(GameTooltip, ("%d of %d left"):format(run.left, run.total))
        GameTooltip_AddNormalLine(GameTooltip, "Press for the next cast.")
        GameTooltip_AddNormalLine(GameTooltip, "Right-click to stop.")
    elseif note then
        GameTooltip_SetTitle(GameTooltip, note.short)
        if note.long then
            GameTooltip_AddNormalLine(GameTooltip, note.long)
        end
        GameTooltip_AddNormalLine(GameTooltip, "Press to start again.")
    else
        GameTooltip_SetTitle(GameTooltip, "Repeat this enchant")
        GameTooltip_AddNormalLine(
            GameTooltip,
            "Casts it on the chosen item once per press, as many times as the box says."
        )
        if ns.settings.answerPrompt then
            GameTooltip_AddNormalLine(
                GameTooltip,
                "If the item already has an enchant, the same press says Yes to replacing it."
            )
        end
        if ns.settings.stopWhenNoSkill then
            GameTooltip_AddNormalLine(
                GameTooltip,
                "Stops when the enchant turns grey or you run out of materials."
            )
        end
    end
    GameTooltip:Show()
end

local function Build()
    page = ProfessionsFrame.CraftingPage

    -- The window's own Enchant All button and count box sit here for a
    -- recipe that can be made in batches. They're hidden for an enchant on
    -- a single item, which is the only time this row shows.
    row = CreateFrame("Frame", nil, page)
    row:SetSize(270, 26)
    row:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -100, 5)
    row:Hide()

    repeatButton = CreateFrame(
        "Button",
        "EncoreRepeatButton",
        row,
        "SharedButtonSmallTemplate,SecureActionButtonTemplate"
    )
    repeatButton:SetSize(120, 22)
    repeatButton:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    repeatButton:SetText("Repeat")
    repeatButton:SetAttribute("*type1", "macro")
    -- Act on release for a click, a key binding and /click alike, so one
    -- press is always exactly one go.
    repeatButton:SetAttribute("useOnKeyDown", false)
    repeatButton:RegisterForClicks("AnyUp")
    repeatButton:SetScript("PreClick", PreClick)
    repeatButton:SetScript("PostClick", PostClick)
    repeatButton:SetScript("OnEnter", ShowTooltip)
    repeatButton:SetScript("OnLeave", GameTooltip_Hide)

    countBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    countBox:SetSize(36, 20)
    countBox:SetPoint("RIGHT", repeatButton, "LEFT", -12, 0)
    countBox:SetAutoFocus(false)
    countBox:SetNumeric(true)
    countBox:SetMaxLetters(3)
    countBox:SetJustifyH("CENTER")
    countBox:SetText(tostring(ns.settings.count))
    countBox:SetScript("OnEnterPressed", countBox.ClearFocus)
    -- Tidies whatever was typed into a count the run can use.
    countBox:HookScript("OnEditFocusLost", function(self)
        self:SetText(tostring(SavedCount()))
    end)

    countLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countLabel:SetPoint("RIGHT", countBox, "LEFT", -8, 0)
    countLabel:SetText("Casts")

    status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("RIGHT", repeatButton, "LEFT", -10, 0)
    status:SetJustifyH("RIGHT")
    status:SetWidth(130)
    status:SetMaxLines(1)
    status:Hide()

    -- ValidateControls is where the window decides what its own buttons
    -- show, on every change of recipe, item, bags or skill. Following it
    -- keeps this row in step without watching all of that separately.
    hooksecurefunc(page, "ValidateControls", Refresh)
    page:HookScript("OnShow", Refresh)

    Refresh()
end

ns.OnEvent("PLAYER_LOGIN", function()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", Build)
end)

-- The client can hand these payloads over as secret values; ns.Readable
-- turns those into nil, which never matches, so such a cast is ignored.

ns.OnPlayerEvent("UNIT_SPELLCAST_START", function(castGUID, spellID)
    if run and ns.Readable(spellID) == run.recipeID then
        run.castGUID = ns.Readable(castGUID)
        Refresh()
    end
end)

ns.OnPlayerEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, spellID)
    if run and ns.Readable(spellID) == run.recipeID then
        run.left = run.left - 1
        run.castGUID = nil
        promptWhich = nil
        Refresh()
    end
end)

-- A cast that didn't land. STOP isn't watched: it can arrive just before
-- SUCCEEDED, and checking whether to stop in that gap would judge the run
-- before its last cast was counted.
local function CastFailed(castGUID)
    if run and run.castGUID and ns.Readable(castGUID) == run.castGUID then
        run.castGUID = nil
        Refresh()
    end
end

ns.OnPlayerEvent("UNIT_SPELLCAST_FAILED", CastFailed)
ns.OnPlayerEvent("UNIT_SPELLCAST_INTERRUPTED", CastFailed)

ns.OnEvent("TRADE_SKILL_CLOSE", function()
    Finish()
    note = nil
    Refresh()
end)

ns.OnEvent("PLAYER_REGEN_ENABLED", function()
    Refresh()
end)

function ns.RefreshRepeat()
    Refresh()
end

function ns.StopRepeat()
    if run then
        Finish("Stopped")
        Refresh()
    end
end
