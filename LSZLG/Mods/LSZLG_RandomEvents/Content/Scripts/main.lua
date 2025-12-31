-- main.lua
-- Engine for the Random Events mod.

-- Load required libraries and events
local json = require("Libs.json")
local NewDay = require("events.NewDay")
local GameMessageBox = require("ShowGameMessageBox")

-- Configuration
local EVENTS_CONFIG_PATH = "Mods/LSZLG_RandomEvents/Content/events.json"

-- Function to read and parse the events configuration file
local function loadEvents()
    local file, err = io.open(EVENTS_CONFIG_PATH, "r")
    if not file then
        logError("FATAL: Could not open events config file at: " .. EVENTS_CONFIG_PATH .. " Error: " .. tostring(err))
        return nil
    end
    local content = file:read("*a")
    file:close()
    
    local ok, data = pcall(json.decode, content)
    if not ok then
        logError("FATAL: Could not parse events.json. Error: " .. tostring(data))
        return nil
    end
    return data.events
end

-- Function to apply the effects of a chosen event
local function applyEventEffects(event)
    if not event.effects then
        return
    end

    for _, effect in ipairs(event.effects) do
        if effect.type == "modifyMapObject" then
            local numObjects = GAME:getNumMapObjects()
            for i = 0, numObjects - 1 do
                local objectConfig = GAME:getMapObject(i)
                if objectConfig and objectConfig.type == effect.target then
                    local newConfig = objectConfig:clone()
                    newConfig[effect.property] = effect.value
                    GAME:setMapObject(i, newConfig)
                end
            end
        elseif effect.type == "modifyPlayerBonus" then
            local players = GAME:getPlayers()
            for _, playerId in ipairs(players) do
                local player = GAME:getPlayer(playerId)
                if player then
                    if effect.operation == "add" then
                        local currentValue = player.bonuses[effect.property] or 0
                        player.bonuses[effect.property] = currentValue + effect.value
                    end
                end
            end
        end
    end
end

-- Main handler for the NewDay event
local function onNewDay(event)
    -- Only run on the first day
    if GAME:getDay() ~= 1 or DATA.randomEventChosen then
        return
    end
    DATA.randomEventChosen = true

    -- Load events from JSON
    local events = loadEvents()
    if not events or #events == 0 then
        logError("No events loaded. Mod will do nothing.")
        return
    end

    -- Select a random event
    local chosenEvent = events[math.random(1, #events)]

    -- Show a message to the player
    local message = "{\\H3_FONT_BIG}" .. chosenEvent.name .. "\n\n" .. chosenEvent.description
    GameMessageBox.show(message)

    -- Apply the event's effects
    applyEventEffects(chosenEvent)
    
    logError("Random Event Triggered: " .. chosenEvent.name)
end

-- Subscribe to the event
NewDay.subscribeAfter(EVENT_BUS, onNewDay)
