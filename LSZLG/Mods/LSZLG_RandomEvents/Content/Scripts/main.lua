local NewDay = require("events.NewDay")

local function onNewDay(event)
  -- We only want this to run on the very first day of the game.
  if GAME:getDay() ~= 1 then
    return
  end

  -- Check if an event has already been chosen for this game.
  -- DATA is a persistent table that stores data for the current game.
  if DATA.randomEventChosen then
    return
  end

  -- Mark that we've chosen an event so this logic doesn't run again.
  DATA.randomEventChosen = true

  -- Randomly pick between two events. 1 = Golden Fever, 2 = Era of Abundance.
  local chosenEvent = math.random(1, 2)

  if chosenEvent == 1 then
    -- Event 1: Golden Fever - Double the income of all gold mines.
    logError("Random Event triggered: Golden Fever") -- Using logError for visibility in tests.
    
    local numObjects = GAME:getNumMapObjects()
    for i = 0, numObjects - 1 do
      local objectConfig = GAME:getMapObject(i)
      -- The ID for a gold mine in VCMI is "core:goldMine".
      if objectConfig and objectConfig.type == "core:goldMine" then
        -- To modify an object, we need to clone its configuration,
        -- change the property, and then set it back.
        local newConfig = objectConfig:clone()
        newConfig.income = 2000 -- Standard gold mine is 1000.
        GAME:setMapObject(i, newConfig)
      end
    end

  else
    -- Event 2: Era of Abundance - Double creature growth for all players.
    logError("Random Event triggered: Era of Abundance") -- Using logError for visibility in tests.

    local players = GAME:getPlayers()
    for _, playerId in ipairs(players) do
      local player = GAME:getPlayer(playerId)
      if player then
        -- Bonuses are represented as percentages. Adding 100 means +100% growth.
        local currentGrowth = player.bonuses.CREATURE_GROWTH or 0
        player.bonuses.CREATURE_GROWTH = currentGrowth + 100
      end
    end
  end
end

-- Subscribe to the onAfter event for a new day. This ensures the game state is ready.
NewDay.subscribeAfter(EVENT_BUS, onNewDay)
