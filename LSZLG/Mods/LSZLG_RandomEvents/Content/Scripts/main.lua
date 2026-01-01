-- main.lua (Version 3.0 - Final Path Correction)
logError("<<<<< LSZLG_RandomEvents main.lua script started execution >>>>>")

-- Load libraries. Path is relative to this script's location (Content/Scripts/).
logError("Loading libraries...")
local json = require("Libs.json")
local NewDay = require("events.NewDay")
local GameMessageBox = require("ShowGameMessageBox")
logError("Libraries loaded successfully.")

-- Define the full, static path to the events file from the VCMI user data root.
-- This path corresponds to the final file structure.
local EVENTS_CONFIG_PATH = "Mods/LSZLG_RandomEvents/Content/events.json"

-- Function to read and parse the events configuration file
local function loadEvents()
    logError("Attempting to load events config from: '" .. EVENTS_CONFIG_PATH .. "'")
    local file, err = io.open(EVENTS_CONFIG_PATH, "r")
    if not file then
        logError("FATAL: Could not open events.json! Error: " .. tostring(err))
        logError("Please ensure the file exists at the specified path relative to your VCMI user data directory.")
        return nil
    end
    local content = file:read("*a")
    file:close()
    
    local ok, data = pcall(json.decode, content)
    if not ok then
        logError("FATAL: Could not parse events.json. Error: " .. tostring(data))
        return nil
    end
    
    logError("Successfully loaded and parsed events.json. Found " .. #data.events .. " events.")
    return data.events
end

-- Function to apply the effects of a chosen event
local function applyEventEffects(event)
    if not event.effects or #event.effects == 0 then
        logError("No effects found for event: " .. event.name)
        return
    end

    logError("Applying " .. #event.effects .. " effect(s) for event: " .. event.name)
    for _, effect in ipairs(event.effects) do
        if effect.type == "modifyMapObject" then
            logError("Applying effect: modifyMapObject for target " .. effect.target)
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
            logError("Applying effect: modifyPlayerBonus for target " .. effect.target)
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
    if GAME:getDay() ~= 1 or DATA.randomEventChosen then
        return
    end
    DATA.randomEventChosen = true
    logError("Random Events Mod: Triggered on Day 1.")

    local events = loadEvents()
    if not events or #events == 0 then
        return
    end

    local chosenEvent = events[math.random(1, #events)]
    logError("Randomly selected event: " .. chosenEvent.name)

    local message = "{\\H3_FONT_BIG}" .. chosenEvent.name .. "\n\n" .. chosenEvent.description
    GameMessageBox.show(message)

    applyEventEffects(chosenEvent)
end

-- Subscribe to the event
NewDay.subscribeAfter(EVENT_BUS, onNewDay)
logError("Random Events Mod initialized and subscribed to NewDay event.")
