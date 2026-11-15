local _, ns = ...

-- The disenchant list.
--
-- A window listing every piece of gear in the bags that can be
-- disenchanted, each with a tick box. Untick whatever you want to keep,
-- then press Disenchant once for each item and it works down the list.
--
-- Anything that looks worth keeping starts unticked, with the reason
-- beside it: gear you've worn, gear in an equipment set, an upgrade over
-- what you're wearing, rare and epic items, and anything on Goldwise's Keep
-- list. You can still tick those; the list just won't do it for you.
--
-- As with Repeat, the game wants a press for every cast, and nothing here
-- casts from addon code. The Disenchant button is a secure button set to
-- cast Disenchant and point it at one bag slot, which the client's secure
-- button code does as its own.

local DISENCHANT = 13262

-- Gear can be disenchanted from green to purple.
local LOWEST_QUALITY = Enum.ItemQuality.Uncommon
local HIGHEST_QUALITY = Enum.ItemQuality.Epic

-- Places that take armour or weapons but never give anything when
-- disenchanted.
local NOT_DISENCHANTABLE = {
    INVTYPE_BODY = true, -- shirts
    INVTYPE_TABARD = true,
    INVTYPE_BAG = true,
    INVTYPE_QUIVER = true,
    INVTYPE_NON_EQUIP_IGNORE = true,
}

-- Where each kind of gear is worn, for "is this better than what you have
-- on". A one-handed weapon is compared with the main hand only, since not
-- every class can carry one in the other.
local SLOTS = {
    INVTYPE_HEAD = { 1 },
    INVTYPE_NECK = { 2 },
    INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16 },
    INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_SHIELD = { 17 },
    INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 },
    INVTYPE_RANGEDRIGHT = { 18 },
    INVTYPE_THROWN = { 18 },
    INVTYPE_RELIC = { 18 },
}

-- An error that arrives this soon after a press is taken to be about it.
local ERROR_WINDOW = 1

-- Errors that mean "not this item" rather than "not now", matched against
-- the client's name for the error: the item can't be disenchanted, or the
-- player's skill is too low for it.
local REFUSALS = {
    "DISENCHANT",
    "LOW_CASTLEVEL",
    "SKILL",
}

-- Any other error on the same item this many presses running is taken as
-- a refusal too, so a name missing above can't leave the button stuck
-- trying one item for ever.
local ERRORS_BEFORE_REFUSAL = 2

-- The loot window that follows a disenchant, if it opens this soon after.
local LOOT_WINDOW = 5

-- How long to wait after a bag or item event before rescanning.
local RESCAN_DELAY = 0.2

local WIDTH, HEIGHT = 420, 460
local ROW_HEIGHT = 34

local window, scrollBox, empty, summary, disenchantButton
local entries = {} -- what the list shows, in bag order

-- By item GUID: the player's own tick or untick this session, and the
-- game's reason for refusing an item.
local chosen, refused = {}, {}

-- Item IDs the last scan couldn't judge because the client hadn't loaded
-- their details yet.
local waitingFor = {}

local current -- the GUID of the item the last press went at
local pressTime = 0
local casting = false
local lootAfter = 0

local function ItemLocationOf(bag, slot)
    return ItemLocation:CreateFromBagAndSlot(bag, slot)
end

--- The item level of what's worn in an equipment slot, or 0 for nothing.
local function WornLevel(slot)
    local location = ItemLocation:CreateFromEquipmentSlot(slot)
    if not C_Item.DoesItemExist(location) then
        return 0
    end
    return C_Item.GetCurrentItemLevel(location) or 0
end

--- Whether the item's tooltip has anything in red, which is how the game
--- says you can't use it (the wrong armour type, a level too high).
local function IsRed(color)
    if not color then
        return false
    end
    local r, g, b = color:GetRGB()
    return r > 0.9 and g < 0.3 and b < 0.3
end

local function TooltipSaysUnusable(bag, slot)
    local data = C_TooltipInfo.GetBagItem(bag, slot)
    for _, line in ipairs(data and data.lines or {}) do
        if IsRed(line.leftColor) or IsRed(line.rightColor) then
            return true
        end
    end
    return false
end

--- Whether the main hand holds a two-handed weapon, which leaves the off
--- hand empty on purpose.
local function WieldingTwoHander()
    local link = GetInventoryItemLink("player", 16)
    local equipLoc = link and select(4, C_Item.GetItemInfoInstant(link))
    return equipLoc == "INVTYPE_2HWEAPON"
end

local function IsUpgrade(bag, slot, itemID, link, equipLoc)
    -- ItemTree weighs stats for the player's class, which beats an item
    -- level compare. Its answer, when it gives one, stands: that includes
    -- "never an upgrade" when its gear advice is turned off.
    local itemTree = rawget(_G, "ItemTreeAPI")
    if itemTree and itemTree.GetItemFacts then
        local facts = itemTree.GetItemFacts(itemID, link)
        local gear = facts and facts.keep and facts.keep.gear
        if gear then
            return gear.upgrade == true and not gear.off
        end
    end

    local slots = SLOTS[equipLoc]
    if not slots or TooltipSaysUnusable(bag, slot) then
        return false
    end
    local level = C_Item.GetCurrentItemLevel(ItemLocationOf(bag, slot)) or 0
    for _, equipped in ipairs(slots) do
        local skip = equipped == 17 and WieldingTwoHander()
        if not skip and level > WornLevel(equipped) then
            return true
        end
    end
    return false
end

local function IsKeptInGoldwise(itemID, link)
    local goldwise = rawget(_G, "GoldwiseAPI")
    if not (goldwise and goldwise.IsKept) then
        return false
    end
    local ok, kept = pcall(goldwise.IsKept, link or itemID)
    return ok and kept == true
end

local function EquipmentSetItems()
    local items = {}
    for _, setID in ipairs(C_EquipmentSet.GetEquipmentSetIDs() or {}) do
        for _, itemID in pairs(C_EquipmentSet.GetItemIDs(setID) or {}) do
            items[itemID] = true
        end
    end
    return items
end

--- Why an item deserves a second look before it goes, as short phrases.
local function Reasons(bag, slot, info, equipLoc, bindType, inSets)
    local reasons = {}
    if inSets[info.itemID] then
        table.insert(reasons, "In an equipment set")
    end
    -- Bind-on-equip gear only becomes soulbound by being put on.
    if bindType == Enum.ItemBind.OnEquip and info.isBound then
        table.insert(reasons, "You've worn it")
    end
    if IsUpgrade(bag, slot, info.itemID, info.hyperlink, equipLoc) then
        table.insert(reasons, "Better than what you wear")
    end
    if info.quality == Enum.ItemQuality.Epic then
        table.insert(reasons, "Epic")
    elseif info.quality == Enum.ItemQuality.Rare then
        table.insert(reasons, "Rare")
    end
    if IsKeptInGoldwise(info.itemID, info.hyperlink) then
        table.insert(reasons, "On your Goldwise Keep list")
    end
    return reasons
end

--- Reads the bags afresh. What the player ticked or unticked, and what the
--- game refused, is kept by item GUID, so it survives every rescan.
local function Scan()
    local inSets = EquipmentSetItems()
    entries = {}
    waitingFor = {}
    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local quality = info and info.quality
            if quality and quality >= LOWEST_QUALITY and quality <= HIGHEST_QUALITY then
                local _, _, _, _, _, _, _, _, equipLoc, _, _, classID, _, bindType =
                    C_Item.GetItemInfo(info.hyperlink)
                local isGear = classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor
                if not classID then
                    -- The client hasn't loaded this item's details yet.
                    -- GET_ITEM_INFO_RECEIVED brings us back for it.
                    waitingFor[info.itemID] = true
                elseif isGear and equipLoc ~= "" and not NOT_DISENCHANTABLE[equipLoc] then
                    local guid = C_Item.GetItemGUID(ItemLocationOf(bag, slot))
                    local reasons = Reasons(bag, slot, info, equipLoc, bindType, inSets)
                    local ticked = chosen[guid]
                    if ticked == nil then
                        ticked = #reasons == 0 and not ns.settings.kept[guid]
                    end
                    table.insert(entries, {
                        bag = bag,
                        slot = slot,
                        guid = guid,
                        link = info.hyperlink,
                        icon = info.iconFileID,
                        reasons = reasons,
                        ticked = ticked,
                        refused = refused[guid],
                    })
                end
            end
        end
    end
end

local function Ticked()
    local list = {}
    for _, entry in ipairs(entries) do
        if entry.ticked then
            table.insert(list, entry)
        end
    end
    return list
end

local function Redraw()
    if not (window and window:IsShown()) then
        return
    end
    scrollBox:SetDataProvider(CreateDataProvider(entries), ScrollBoxConstants.RetainScrollPosition)
    empty:SetShown(#entries == 0)

    local count = #Ticked()
    if #entries == 0 then
        summary:SetText("")
    elseif count == 0 then
        summary:SetText("Nothing ticked")
    else
        summary:SetText(("%d of %d ticked"):format(count, #entries))
    end
    disenchantButton:SetText(
        count > 0 and ("Disenchant next (%d left)"):format(count) or "Disenchant next"
    )
    if not InCombatLockdown() then
        disenchantButton:SetEnabled(count > 0)
    end
end

local function Refresh()
    if window and window:IsShown() then
        Scan()
        Redraw()
    end
end

-- Bag and item events come in bursts. Rescan once, a moment after the
-- last of them.
local refreshToken
local function RefreshSoon()
    if not (window and window:IsShown()) then
        return
    end
    local token = {}
    refreshToken = token
    C_Timer.After(RESCAN_DELAY, function()
        if refreshToken == token then
            Refresh()
        end
    end)
end

local function SetTicked(entry, ticked)
    entry.ticked = ticked
    entry.refused = nil
    chosen[entry.guid] = ticked
    refused[entry.guid] = nil
    -- Unticking is remembered for next time; ticking forgets it again.
    ns.settings.kept[entry.guid] = (not ticked) or nil
    Redraw()
end

local function FillRow(row, entry)
    row.entry = entry
    row.check:SetChecked(entry.ticked)
    row.icon:SetTexture(entry.icon)
    row.name:SetText(entry.link)
    row.name:SetAlpha(entry.ticked and 1 or 0.6)
    row.icon:SetDesaturated(not entry.ticked)

    local note = entry.refused or table.concat(entry.reasons, ", ")
    row.note:SetText(note)
    if entry.refused then
        row.note:SetTextColor(RED_FONT_COLOR:GetRGB())
    else
        row.note:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
    end
end

local function CreateRow(row)
    row:SetHeight(ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetSize(24, 24)
    row.check:SetPoint("LEFT", 2, 0)
    row.check:SetScript("OnClick", function(self)
        SetTicked(row.entry, self:GetChecked())
    end)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(26, 26)
    row.icon:SetPoint("LEFT", row.check, "RIGHT", 4, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
    row.name:SetPoint("RIGHT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetMaxLines(1)

    row.note = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.note:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 0)
    row.note:SetPoint("RIGHT", -6, 0)
    row.note:SetJustifyH("LEFT")
    row.note:SetMaxLines(1)

    -- A click anywhere on the row flips its tick, like the box itself.
    row:SetScript("OnClick", function(self)
        SetTicked(self.entry, not self.entry.ticked)
    end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(self.entry.bag, self.entry.slot)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row.created = true
end

--- The first ticked item still where the list last saw it.
local function NextEntry()
    for _, entry in ipairs(Ticked()) do
        local location = ItemLocationOf(entry.bag, entry.slot)
        if C_Item.DoesItemExist(location) and C_Item.GetItemGUID(location) == entry.guid then
            if not C_Item.IsLocked(location) then
                return entry
            end
        end
    end
    return nil
end

-- Points the secure button at the next item just before the press goes
-- through. PostClick clears it again, so a press this can't vouch for (in
-- combat, say) casts nothing.
local queued = false -- this press was pointed at an item

local function PreClick(self, mouseButton)
    queued = false
    -- The list only acts while it's open, so the key binding can never
    -- work from a list the player isn't looking at.
    if InCombatLockdown() or mouseButton ~= "LeftButton" or not window:IsShown() then
        return
    end
    if casting then
        if UnitCastingInfo("player") then
            return
        end
        -- The cast ended without saying so. Don't let that stick.
        casting = false
    end
    local entry = NextEntry()
    if not entry then
        return
    end
    current = entry.guid
    pressTime = GetTime()
    queued = true
    self:SetAttribute("*spell1", DISENCHANT)
    self:SetAttribute("*target-bag1", entry.bag)
    self:SetAttribute("*target-slot1", entry.slot)
end

local function PostClick(self)
    if InCombatLockdown() or not queued then
        return
    end
    queued = false
    self:SetAttribute("*spell1", nil)
    self:SetAttribute("*target-bag1", nil)
    self:SetAttribute("*target-slot1", nil)

    -- If the game turned the item down, it can leave the glowing
    -- targeting hand behind. Put it away.
    if SpellIsTargeting() then
        SpellStopTargeting()
    end
end

local function IsRefusal(errorType)
    local name = ns.Readable(errorType) and GetGameMessageInfo(errorType)
    if type(name) ~= "string" then
        return false
    end
    for _, pattern in ipairs(REFUSALS) do
        if name:find(pattern, 1, true) then
            return true
        end
    end
    return false
end

--- Unticks the item the last press went at and shows the game's reason
--- beside it, so the next press moves on. Held through rescans, but not
--- remembered for next time: more skill may fix it.
local function Refuse(message)
    chosen[current] = false
    refused[current] = message
    for _, entry in ipairs(entries) do
        if entry.guid == current then
            entry.ticked = false
            entry.refused = message
        end
    end
    current = nil
    Redraw()
end

local function CreateWindow()
    window = CreateFrame("Frame", "EncoreDisenchantWindow", UIParent, "ButtonFrameTemplate")
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER", 0, 40)
    window:SetFrameStrata("HIGH")
    window:SetTitle("Disenchant")
    ButtonFrameTemplate_HidePortrait(window)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:Hide()
    table.insert(UISpecialFrames, "EncoreDisenchantWindow")

    local intro = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    intro:SetPoint("TOPLEFT", 16, -32)
    intro:SetPoint("RIGHT", -16, 0)
    intro:SetJustifyH("LEFT")
    intro:SetText(
        "Untick anything you want to keep. Then press Disenchant once for each item. "
            .. "Anything that looks worth keeping starts unticked."
    )

    local inset = window.Inset
    inset:ClearAllPoints()
    inset:SetPoint("TOPLEFT", 8, -72)
    inset:SetPoint("BOTTOMRIGHT", -6, 28)

    scrollBox = CreateFrame("Frame", nil, inset, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", 4, -4)
    scrollBox:SetPoint("BOTTOMRIGHT", -20, 4)
    local scrollBar = CreateFrame("EventFrame", nil, inset, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, -2)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 2)

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Button", function(row, entry)
        if not row.created then
            CreateRow(row)
        end
        FillRow(row, entry)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

    empty = inset:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("CENTER")
    empty:SetText("Nothing in your bags to disenchant.")

    summary = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    summary:SetPoint("BOTTOMLEFT", 14, 8)

    disenchantButton = CreateFrame(
        "Button",
        "EncoreDisenchantButton",
        window,
        "UIPanelButtonTemplate,SecureActionButtonTemplate"
    )
    disenchantButton:SetSize(190, 22)
    disenchantButton:SetPoint("BOTTOMRIGHT", -6, 4)
    disenchantButton:SetAttribute("*type1", "spell")
    disenchantButton:SetAttribute("useOnKeyDown", false)
    disenchantButton:RegisterForClicks("AnyUp")
    disenchantButton:SetScript("PreClick", PreClick)
    disenchantButton:SetScript("PostClick", PostClick)

    window:SetScript("OnShow", Refresh)
end

--- Opens the list, or closes it if it's open.
function ns.ToggleDisenchant()
    if InCombatLockdown() then
        return
    end
    if not C_SpellBook.IsSpellKnown(DISENCHANT) then
        UIErrorsFrame:AddExternalErrorMessage("You need Enchanting to disenchant.")
        return
    end
    if not window then
        CreateWindow()
    end
    window:SetShown(not window:IsShown())
end

-- A small button on the Professions window while Enchanting is open.
local function AddProfessionsButton()
    local page = ProfessionsFrame.CraftingPage
    local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    button:SetSize(130, 22)
    button:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -38)
    button:SetText("Disenchant All...")
    button:SetScript("OnClick", ns.ToggleDisenchant)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip_SetTitle(GameTooltip, "Disenchant from your bags")
        GameTooltip_AddNormalLine(GameTooltip, "Lists what you can disenchant, to pick from.")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    local function Update()
        local profession = C_TradeSkillUI.GetBaseProfessionInfo()
        button:SetShown(profession and profession.profession == Enum.Profession.Enchanting or false)
    end
    page:HookScript("OnShow", Update)
    ns.OnEvent("TRADE_SKILL_LIST_UPDATE", Update)
    Update()
end

ns.OnEvent("PLAYER_LOGIN", function()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", AddProfessionsButton)
end)

ns.OnEvent("BAG_UPDATE_DELAYED", RefreshSoon)
ns.OnEvent("PLAYER_EQUIPMENT_CHANGED", RefreshSoon)
ns.OnEvent("EQUIPMENT_SETS_CHANGED", RefreshSoon)

-- Every item lookup by any addon fires this, so only the items the last
-- scan was waiting on lead to another.
ns.OnEvent("GET_ITEM_INFO_RECEIVED", function(itemID, success)
    if success and waitingFor[itemID] then
        waitingFor[itemID] = nil
        RefreshSoon()
    end
end)

-- The window holds a secure button, so once a fight starts it can't be
-- hidden (Escape included) without the game objecting. Disenchanting isn't
-- something to do mid-fight anyway, so it closes as the fight begins.
ns.OnEvent("PLAYER_REGEN_DISABLED", function()
    if window and window:IsShown() then
        window:Hide()
    end
end)

ns.OnEvent("PLAYER_REGEN_ENABLED", Redraw)

-- The game refusing an item (too little skill, say) shows up as an error
-- straight after the press, often before or without a failed cast: an
-- item turned down at the targeting step never starts casting at all. So
-- the error alone decides. A "not now" error (moving, mounted, already
-- casting) leaves the item ticked for another go, unless it keeps coming.
local errorsFor, errorCount = nil, 0

ns.OnEvent("UI_ERROR_MESSAGE", function(errorType, message)
    if not current or casting or GetTime() - pressTime > ERROR_WINDOW then
        return
    end
    if errorsFor ~= current then
        errorsFor, errorCount = current, 0
    end
    errorCount = errorCount + 1
    if IsRefusal(errorType) or errorCount >= ERRORS_BEFORE_REFUSAL then
        errorsFor, errorCount = nil, 0
        Refuse(ns.Readable(message) or "The game wouldn't disenchant this.")
    end
end)

ns.OnPlayerEvent("UNIT_SPELLCAST_START", function(_, spellID)
    if ns.Readable(spellID) == DISENCHANT then
        casting = true
    end
end)

ns.OnPlayerEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, spellID)
    if ns.Readable(spellID) == DISENCHANT then
        casting = false
        current = nil
        lootAfter = GetTime()
    end
end)

local function CastEnded(_, spellID)
    if ns.Readable(spellID) == DISENCHANT then
        casting = false
    end
end

ns.OnPlayerEvent("UNIT_SPELLCAST_FAILED", CastEnded)
ns.OnPlayerEvent("UNIT_SPELLCAST_INTERRUPTED", CastEnded)

-- Takes the dust and essences from the loot window a disenchant opens, so
-- it never sits in the way of the next press. With the game's auto loot on
-- there's nothing to do.
ns.OnEvent("LOOT_READY", function(autoLoot)
    if autoLoot or GetTime() - lootAfter > LOOT_WINDOW then
        return
    end
    lootAfter = 0
    for slot = GetNumLootItems(), 1, -1 do
        LootSlot(slot)
    end
end)
