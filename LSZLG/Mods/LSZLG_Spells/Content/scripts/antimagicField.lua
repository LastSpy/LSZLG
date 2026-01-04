--[[
    antimagicField.lua
    Logic for the Anti-Magic Field spell.
--]]

-- Load required engine components
local events = {
    BattleStarted = require("events.BattleStarted"),
    BattleSpellCast = require("events.BattleSpellCast"),
    CreatureMoved = require("events.CreatureMoved"),
    BeforeBattleSpellCast = require("events.BeforeBattleSpellCast"),
    BattleRoundStarted = require("events.BattleRoundStarted")
}
local consts = {
    Skill = require("natives.Skill"),
    Bonus = require("natives.Bonus")
}

-- Use a local table for battle-specific data. This is cleaner than using the global DATA table.
local battleState = {
    antiMagicFields = {}
}

-- Handler to reset state at the beginning of each battle
local function onBattleStarted(event)
    battleState.antiMagicFields = {}
end

-- Hexagonal distance calculation
local function getHexDistance(hexA, hexB)
    local d_col = math.abs(hexA.x - hexB.x)
    local d_row = math.abs(hexA.y - hexB.y)
    return d_col + math.max(0, (d_row - d_col) / 2)
end

-- Get all hexes within a given radius from a center hex
local function getHexesInRadius(centerHex, radius)
    local affectedHexes = {}
    local battleSize = BATTLE:getBattlefieldSize()

    for x = 0, battleSize.width - 1 do
        for y = 0, battleSize.height - 1 do
            local currentHex = {x = x, y = y}
            if getHexDistance(centerHex, currentHex) < radius then
                table.insert(affectedHexes, currentHex)
            end
        end
    end
    return affectedHexes
end

-- Check if a specific hex is inside any active anti-magic field
local function isHexInAnyField(targetHex)
    for _, field in ipairs(battleState.antiMagicFields) do
        for _, hex in ipairs(field.hexes) do
            if hex.x == targetHex.x and hex.y == targetHex.y then
                return true
            end
        end
    end
    return false
end

-- Apply or remove the spell immunity bonus
local function updateCreatureImmunity(creature)
    local creatureHex = creature:getHex()
    local bonusType = consts.Bonus.SPELL_IMMUNITY
    
    if isHexInAnyField(creatureHex) then
        if not creature:hasBonus(bonusType) then
            creature:addBonus(bonusType)
        end
    else
        if creature:hasBonus(bonusType) then
            creature:removeBonus(bonusType)
        end
    end
end

-- Handler for when the spell is initially cast
local function onSpellCast(event)
    if event.spellId ~= "antimagicField" then return end

    local caster = event.caster
    local power = caster:getSpellPower()
    -- getSkillLevel returns a NUMBER: 0 = none, 1 = basic, 2 = advanced, 3 = expert
    local waterMagicLevel = caster:getSkillLevel(consts.Skill.WATER_MAGIC)
    
    -- Calculate duration
    local duration = 1 + math.ceil(power / 2)

    -- Calculate radius based on Water Magic skill
    local radius = 2
    if waterMagicLevel == 2 then -- Advanced
        radius = 3
    elseif waterMagicLevel == 3 then -- Expert
        radius = 4
    end

    -- Determine target hex
    local targetHex = event.targetHex
    if waterMagicLevel == 0 then -- None
        local battleSize = BATTLE:getBattlefieldSize()
        targetHex = {
            x = math.random(0, battleSize.width - 1),
            y = math.random(0, battleSize.height - 1)
        }
    end

    -- Create the field
    local newField = {
        casterId = caster:getId(),
        duration = duration,
        hexes = getHexesInRadius(targetHex, radius)
    }
    table.insert(battleState.antiMagicFields, newField)

    -- Apply effect to all creatures currently in the field
    for _, creature in ipairs(BATTLE:getActiveCreatures()) do
        updateCreatureImmunity(creature)
    end
end

-- Handler for creature movement
local function onCreatureMoved(event)
    for _, creature in ipairs(BATTLE:getActiveCreatures()) do
        updateCreatureImmunity(creature)
    end
end

-- Handler to block spells cast into the field
local function onBeforeSpellCast(event)
    if isHexInAnyField(event.targetHex) then
        return false -- Cancel the spell
    end
end

-- Handler for the start of a new battle round
local function onRoundStarted(event)
    local remainingFields = {}
    
    for _, field in ipairs(battleState.antiMagicFields) do
        field.duration = field.duration - 1
        if field.duration > 0 then
            table.insert(remainingFields, field)
        end
    end
    
    battleState.antiMagicFields = remainingFields
    
    -- Update immunity for all creatures, as some fields may have expired
    for _, creature in ipairs(BATTLE:getActiveCreatures()) do
        updateCreatureImmunity(creature)
    end
end


-- Subscribe all handlers to the corresponding events
events.BattleStarted.subscribeAfter(EVENT_BUS, onBattleStarted)
events.BattleSpellCast.subscribeAfter(EVENT_BUS, onSpellCast)
events.CreatureMoved.subscribeAfter(EVENT_BUS, onCreatureMoved)
events.BeforeBattleSpellCast.subscribeBefore(EVENT_BUS, onBeforeSpellCast)
events.BattleRoundStarted.subscribeAfter(EVENT_BUS, onRoundStarted)
