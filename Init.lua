local addonName, ns = ...

-- Encore
--
-- Enchanters level the profession by putting the same enchant on the same
-- item over and over. The Professions window already casts each one; what
-- it doesn't do is count them, stop at the right moment, or spare you the
-- "replace the existing enchant?" prompt every time. That's all this adds.
--
-- Everything hangs off the private table the client hands every file in
-- the addon (ns). The only globals are the saved settings, the slash
-- command, the key binding's label and the named buttons in Repeat.lua.

ns.name = addonName
ns.TITLE = "Encore"

ns.DEFAULT_SETTINGS = {
    -- How many casts a run is, as last typed into the box.
    count = 10,

    -- Say Yes to the replace prompt in the same press that cast the enchant.
    answerPrompt = true,

    -- End the run once the enchant can't raise the skill any more.
    stopWhenNoSkill = true,
}

ns.MAX_COUNT = 999

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
    for key, value in pairs(ns.DEFAULT_SETTINGS) do
        if EncoreDB[key] == nil then
            EncoreDB[key] = value
        end
    end
    ns.settings = EncoreDB
end)
