local addonName, ns = ...

-- Encore
--
-- Two small helps for enchanters. Repeat.lua puts the same enchant on the
-- same item again without stopping at the "replace the existing enchant?"
-- prompt each time. Disenchant.lua lists what in the bags could be
-- disenchanted, and works through the ticked ones a press at a time.
--
-- Everything hangs off the private table the client hands every file in
-- the addon (ns). The only globals are the saved data, the slash command,
-- the key bindings' labels and the named buttons and window.

ns.name = addonName
ns.TITLE = "Encore"

local frame = CreateFrame("Frame")
local handlers = {}

--- Calls handler(...) with the event's payload whenever the client fires it.
---@param event string
---@param handler fun(...)
function ns.OnEvent(event, handler)
    if not handlers[event] then
        handlers[event] = {}
        frame:RegisterEvent(event)
    end
    table.insert(handlers[event], handler)
end

-- Unit events for the player alone come through a frame of their own, so
-- the casts of everyone nearby never reach the handlers.
local playerFrame = CreateFrame("Frame")
local playerHandlers = {}

--- Like ns.OnEvent, for a unit event about the player. The handler gets
--- the payload after the unit.
---@param event string
---@param handler fun(...)
function ns.OnPlayerEvent(event, handler)
    if not playerHandlers[event] then
        playerHandlers[event] = {}
        playerFrame:RegisterUnitEvent(event, "player")
    end
    table.insert(playerHandlers[event], handler)
end

playerFrame:SetScript("OnEvent", function(_, event, _, ...)
    for _, handler in ipairs(playerHandlers[event]) do
        handler(...)
    end
end)

frame:SetScript("OnEvent", function(_, event, ...)
    for _, handler in ipairs(handlers[event]) do
        handler(...)
    end
end)

--- A value the client may hand back as secret is treated as unknown.
function ns.Readable(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name ~= addonName then
        return
    end

    EncoreDB = EncoreDB or {}

    -- Items unticked in the disenchant list, by item GUID, so they stay
    -- unticked the next time it opens.
    EncoreDB.kept = EncoreDB.kept or {}

    -- Left over from a build that had a repeat count and two options.
    EncoreDB.count, EncoreDB.answerPrompt, EncoreDB.stopWhenNoSkill = nil, nil, nil

    ns.settings = EncoreDB
end)
