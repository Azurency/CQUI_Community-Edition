include("civ6common")

local BACKDROP_DARKER_OFFSET = -85
local BACKDROP_DARKER_OPACITY = 238
local BACKDROP_BRIGHTER_OFFSET = 90
local BACKDROP_BRIGHTER_OPACITY = 250

local Game = Game
local Players = Players
local Events = Events

local ipairs = ipairs
local pairs = pairs

local L_Lookup = Locale.Lookup

-- ===========================================================================
--  Local Constants
-- ===========================================================================

SORT_BY_ID = {
  FOOD = 1,
  PRODUCTION = 2,
  GOLD = 3,
  SCIENCE = 4,
  CULTURE = 5,
  FAITH = 6,
  TURNS_TO_COMPLETE = 7,
  ORIGIN_NAME = 8,
  DESTINATION_NAME = 9
}

SORT_ASCENDING = 1;
SORT_DESCENDING = 2;

-- Yield constants
FOOD_INDEX = GameInfo.Yields["YIELD_FOOD"].Index;
PRODUCTION_INDEX = GameInfo.Yields["YIELD_PRODUCTION"].Index;
GOLD_INDEX = GameInfo.Yields["YIELD_GOLD"].Index;
SCIENCE_INDEX = GameInfo.Yields["YIELD_SCIENCE"].Index;
CULTURE_INDEX = GameInfo.Yields["YIELD_CULTURE"].Index;
FAITH_INDEX = GameInfo.Yields["YIELD_FAITH"].Index;

START_INDEX = FOOD_INDEX;
END_INDEX = FAITH_INDEX;

-- Build lookup table for icons
ICON_LOOKUP = {}
ICON_LOOKUP[FOOD_INDEX] = "[ICON_Food]"
ICON_LOOKUP[PRODUCTION_INDEX] = "[ICON_Production]"
ICON_LOOKUP[GOLD_INDEX] = "[ICON_Gold]"
ICON_LOOKUP[SCIENCE_INDEX] = "[ICON_Science]"
ICON_LOOKUP[CULTURE_INDEX] = "[ICON_Culture]"
ICON_LOOKUP[FAITH_INDEX] = "[ICON_Faith]"

-- Build lookup table for score functions
ScoreFunctionByID = {}
ScoreFunctionByID[SORT_BY_ID.FOOD]                = function(a) return GetYieldForOriginCity(FOOD_INDEX, a, true) end
ScoreFunctionByID[SORT_BY_ID.PRODUCTION]          = function(a) return GetYieldForOriginCity(PRODUCTION_INDEX, a, true) end
ScoreFunctionByID[SORT_BY_ID.GOLD]                = function(a) return GetYieldForOriginCity(GOLD_INDEX, a, true) end
ScoreFunctionByID[SORT_BY_ID.SCIENCE]             = function(a) return GetYieldForOriginCity(SCIENCE_INDEX, a, true) end
ScoreFunctionByID[SORT_BY_ID.CULTURE]             = function(a) return GetYieldForOriginCity(CULTURE_INDEX, a, true) end
ScoreFunctionByID[SORT_BY_ID.FAITH]               = function(a) return GetYieldForOriginCity(FAITH_INDEX, a, true) end
ScoreFunctionByID[SORT_BY_ID.TURNS_TO_COMPLETE]   = function(a) return GetTurnsToComplete(a, true) end
ScoreFunctionByID[SORT_BY_ID.ORIGIN_NAME]         = function(a) return GetOriginCityName(a) end
ScoreFunctionByID[SORT_BY_ID.DESTINATION_NAME]    = function(a) return GetDestinationCityName(a) end

-- ===========================================================================
--  Variables
-- ===========================================================================

local m_LocalPlayerRunningRoutes    :table  = {};   -- Tracks local players active routes (turns remaining)
local m_TradersAutomatedSettings    :table  = {};   -- Tracks traders, and if they are automated
local m_Cache                       :table  = {};   -- Cache for all route info

-- local debug_func_calls:number = 0;
-- local debug_total_calls:number = 0;

-- ===========================================================================
--  Trader Route tracker - Tracks active routes, turns remaining
-- ===========================================================================

function GetLocalPlayerRunningRoutes()
  CheckConsistencyWithMyRunningRoutes(m_LocalPlayerRunningRoutes);

  return m_LocalPlayerRunningRoutes;
end

function GetLastRouteForTrader( traderID:number )
  -- @Astog NOTE: As of Summer 2017 patch, base game added code to get this info
  -- Commenting my modded code
  -- LoadTraderAutomatedInfo();

  -- if m_TradersAutomatedSettings[traderID] ~= nil then
  --     return m_TradersAutomatedSettings[traderID].LastRouteInfo;
  -- end

  local pTrader = Players[Game.GetLocalPlayer()]:GetUnits():FindID(traderID)
  local trade:table = pTrader:GetTrade();
  local prevOriginComponentID:table = trade:GetLastOriginTradeCityComponentID();
  local prevDestComponentID:table = trade:GetLastDestinationTradeCityComponentID();

  -- Make sure the entries are valid. Return nil if not
  if pTrader ~= nil and prevOriginComponentID.player ~= nil and prevOriginComponentID.player ~= -1 and
      prevOriginComponentID.id ~= nil and prevOriginComponentID.id ~= -1 and
      prevDestComponentID.player ~= nil and prevDestComponentID.player ~= -1 and
      prevDestComponentID.id ~= nil and prevDestComponentID.id ~= -1 then

    local routeInfo = {
      OriginCityPlayer = prevOriginComponentID.player,
      OriginCityID = prevOriginComponentID.id,
      DestinationCityPlayer = prevDestComponentID.player,
      DestinationCityID = prevDestComponentID.id
    };
    return routeInfo
  end
  return nil
end

-- Adds the route turns remaining to the table, if it does not exist already
function AddRouteWithTurnsRemaining( routeInfo:table, routesTable:table)
  -- print("Adding route: " .. GetTradeRouteString(routeInfo));

  local routeIndex = findIndex(routesTable, routeInfo, CheckRouteEquality);
  if routeIndex == -1 then
    local tradePathLength, tripsToDestination, turnsToCompleteRoute = GetRouteInfo(routeInfo);

    -- Build entry
    local routeEntry:table = {
      OriginCityPlayer        = routeInfo.OriginCityPlayer;
      OriginCityID            = routeInfo.OriginCityID;
      DestinationCityPlayer   = routeInfo.DestinationCityPlayer;
      DestinationCityID       = routeInfo.DestinationCityID;
      TraderUnitID            = routeInfo.TraderUnitID;
      TurnsRemaining          = turnsToCompleteRoute;
    };

    -- Append entry
    table.insert(routesTable, routeEntry);
    SaveRunningRoutesInfo();
  else
    print_debug("AddRouteWithTurnsRemaining: Route already exists in table.");
  end
end

-- Decrements routes present. Removes those that completed
function UpdateRoutesWithTurnsRemaining( routesTable:table )
  for i=1, #routesTable do
    if routesTable[i].TurnsRemaining ~= nil then
      routesTable[i].TurnsRemaining = routesTable[i].TurnsRemaining - 1;
      print_debug("Updated route " .. GetTradeRouteString(routesTable[i]) .. " with turns remaining " .. routesTable[i].TurnsRemaining)
    end
  end

  SaveRunningRoutesInfo();
end

-- Checks if routes running in game and the routesTable are consistent with each other
function CheckConsistencyWithMyRunningRoutes( routesTable:table )
  -- Build currently running routes
  local routesCurrentlyRunning:table = {};
  local localPlayerCities:table = Players[Game.GetLocalPlayer()]:GetCities();
  for _, city in localPlayerCities:Members() do
    local outgoingRoutes = city:GetTrade():GetOutgoingRoutes();
    for _, routeInfo in ipairs(outgoingRoutes) do
      table.insert(routesCurrentlyRunning, routeInfo);
    end
  end

  -- Add all routes in routesCurrentlyRunning table that are not in routesTable
  for _, route in ipairs(routesCurrentlyRunning) do
    local routeIndex = findIndex(routesTable, route, CheckRouteEquality);

    -- Is the route not present?
    if routeIndex == -1 then
      -- Add it to the list
      print_debug(GetTradeRouteString(route) .. " was not present. Adding it to the table.");
      AddRouteWithTurnsRemaining(route, routesTable, true);
    end
  end

  -- Remove all routes in routesTable, that are not in routesCurrentlyRunning.
  -- Manually control the indices, so that you can iterate over the table while deleting items within it
  local i = 1;
  while i <= table.count(routesTable) do
    local routeIndex = findIndex( routesCurrentlyRunning, routesTable[i], CheckRouteEquality );

    -- Is the route not present?
    if routeIndex == -1 then
      print_debug("Route " .. GetTradeRouteString(routesTable[i]) .. " is no longer running. Removing it.");
      table.remove(routesTable, i)
    else
      i = i + 1
    end
  end

  SaveRunningRoutesInfo();
end

function SaveRunningRoutesInfo()
  -- Dump active routes info
  -- print("Saving running routes info in PlayerConfig database")
  local dataDump = DataDumper(m_LocalPlayerRunningRoutes, "localPlayerRunningRoutes");
  -- print(dataDump);
  PlayerConfigurations[Game.GetLocalPlayer()]:SetValue("BTS_LocalPlayerRunningRotues", dataDump);
end

function LoadRunningRoutesInfo()
  local localPlayerID = Game.GetLocalPlayer();
  if(PlayerConfigurations[localPlayerID]:GetValue("BTS_LocalPlayerRunningRotues") ~= nil) then
    -- print("Retrieving previous routes PlayerConfig database")
    local dataDump = PlayerConfigurations[localPlayerID]:GetValue("BTS_LocalPlayerRunningRotues");
    -- print(dataDump);
    loadstring(dataDump)();
    m_LocalPlayerRunningRoutes = localPlayerRunningRoutes;
  else
    print_debug("No running route data was found, on load.")
  end

  -- Check for consistency
  CheckConsistencyWithMyRunningRoutes(m_LocalPlayerRunningRoutes);
end

-- ---------------------------------------------------------------------------
-- Game event hookups (Local to this file)
-- ---------------------------------------------------------------------------

local function TradeSupportTracker_OnUnitOperationStarted(ownerID:number, unitID:number, operationID:number)
  if ownerID == Game.GetLocalPlayer() and operationID == UnitOperationTypes.MAKE_TRADE_ROUTE then
    -- Unit was just started a trade route. Find the route, and update the tables
    local localPlayerCities:table = Players[ownerID]:GetCities();
    for _, city in localPlayerCities:Members() do
      local outgoingRoutes = city:GetTrade():GetOutgoingRoutes();
      for _, route in ipairs(outgoingRoutes) do
        if route.TraderUnitID == unitID then
          -- Add it to the local players runnning routes
          print_debug("Route just started. Adding Route: " .. GetTradeRouteString(route));
          AddRouteWithTurnsRemaining( route, m_LocalPlayerRunningRoutes );
          return
        end
      end
    end
  end
end

-- Removes trader from currently running routes, when it completes
local function TradeSupportTracker_OnUnitOperationsCleared(ownerID:number, unitID:number, operationID:number)
  if ownerID == Game.GetLocalPlayer() then
    local pPlayer:table = Players[ownerID];
    local pUnit:table = pPlayer:GetUnits():FindID(unitID);

    if pUnit ~= nil then
      local unitInfo:table = GameInfo.Units[pUnit:GetUnitType()];
      if unitInfo ~= nil and unitInfo.MakeTradeRoute then
        LoadTraderAutomatedInfo();

        -- Remove entry from local players running routes
        for _, route in ipairs(m_LocalPlayerRunningRoutes) do
          if route.TraderUnitID == unitID then
            if m_TradersAutomatedSettings[unitID] == nil then
              print_debug("Couldn't find trader automated info. Creating one.")
              m_TradersAutomatedSettings[unitID] = { IsAutomated=false };
            end

            -- Add it to the last route info for trader
            -- @Astog NOTE: As of Summer 2017 patch, this got added in vanilla code, hence commenting this modded code
            -- m_TradersAutomatedSettings[unitID].LastRouteInfo = route;
            -- SaveTraderAutomatedInfo();

            print_debug("Removing route " .. GetTradeRouteString(route) .. " from currently running, since it completed.");

            -- Remove route from currrently running routes
            RemoveRouteFromTable(route, m_LocalPlayerRunningRoutes, false);
            SaveRunningRoutesInfo()
            return
          end
        end
      end
    end
  end
end

local function TradeSupportTracker_OnPlayerTurnActivated( playerID:number, isFirstTime:boolean )
  if playerID == Game.GetLocalPlayer() and isFirstTime then
    UpdateRoutesWithTurnsRemaining(m_LocalPlayerRunningRoutes);
  end
end

-- ===========================================================================
--  Trader Route Automater - Auto renew, last route
-- ===========================================================================

function AutomateTrader(traderID:number, isAutomated:boolean, sortSettings:table)
  LoadTraderAutomatedInfo();

  if m_TradersAutomatedSettings[traderID] == nil then
    m_TradersAutomatedSettings[traderID] = {}
  end

  m_TradersAutomatedSettings[traderID].IsAutomated = isAutomated

  if sortSettings ~= nil and table.count(sortSettings) > 0 then
    print_debug("Automate trader " .. traderID .. " with top route.")
    m_TradersAutomatedSettings[traderID].SortSettings = sortSettings
  else
    print_debug("Automate trader " .. traderID)
  end

  SaveTraderAutomatedInfo();
end

function CancelAutomatedTrader(traderID:number)
  print_debug("Cancelling automation for trader " .. traderID);

  LoadTraderAutomatedInfo();

  if m_TradersAutomatedSettings[traderID] ~= nil then
    m_TradersAutomatedSettings[traderID].IsAutomated = false;
    m_TradersAutomatedSettings[traderID].SortSettings = nil;

    SaveTraderAutomatedInfo();
  else
    print("Error: Could not find automated trader info");
  end
end

function FindTopRoute(originPlayerID:number, originCityID:number, sortSettings:table)
  local tradeManager:table = Game.GetTradeManager();
  local tradeRoutes:table = {};
  local players:table = Game.GetPlayers{ Alive=true };

  -- Build list of trade routes
  for _, player in ipairs(players) do
    local playerID = player:GetID()
    if CanPossiblyTradeWithPlayer(originPlayerID,  playerID) then
      for _, city in player:GetCities():Members() do
        local cityID = city:GetID()
        -- Can we start a trade route with this city?
        if tradeManager:CanStartRoute(originPlayerID, originCityID, playerID, cityID) then
          local routeInfo = {
            OriginCityPlayer        = originPlayerID,
            OriginCityID            = originCityID,
            DestinationCityPlayer   = playerID,
            DestinationCityID       = cityID
          };

          tradeRoutes[#tradeRoutes + 1] = routeInfo;
        end
      end
    end
  end

  -- Get the top route based on the settings saved when the route was begun. NOTE - Will have cache misses here.
  return GetTopRouteFromSortSettings( tradeRoutes, sortSettings);
end

function RenewTradeRoutes()
  local renewedRoute:boolean = false;

  -- Load the automated settings, (so that changes from TradeOverview.lua reach here)
  LoadTraderAutomatedInfo();

  local pPlayerUnits:table = Players[Game.GetLocalPlayer()]:GetUnits();
  for _, pUnit in pPlayerUnits:Members() do
    local unitInfo:table = GameInfo.Units[pUnit:GetUnitType()];
    local unitID:number = pUnit:GetID();

    -- Check if it is a free trader
    if unitInfo.MakeTradeRoute == true and (not pUnit:HasPendingOperations()) then
      if m_TradersAutomatedSettings[unitID] ~= nil and m_TradersAutomatedSettings[unitID].IsAutomated then
        local tradeManager:table = Game.GetTradeManager();
        local originCity:table = Cities.GetCityInPlot(pUnit:GetX(), pUnit:GetY());

        local originPlayerID = originCity:GetOwner()
        local originCityID = originCity:GetID()
        local destinationPlayerID:number;
        local destinationCityID:number;

        if m_TradersAutomatedSettings[unitID].SortSettings ~= nil and table.count(m_TradersAutomatedSettings[unitID].SortSettings) > 0 then
          print_debug("Picking from top sort entry");

          -- Get destination based on the top entry
          local topRoute = FindTopRoute(originPlayerID, originCityID, m_TradersAutomatedSettings[unitID].SortSettings)
          destinationPlayerID = topRoute.DestinationCityPlayer
          destinationCityID = topRoute.DestinationCityID
        else
          print_debug("Picking last route");

          local lastRouteInfo = GetLastRouteForTrader(unitID)
          if lastRouteInfo ~= nil then
            destinationPlayerID = lastRouteInfo.DestinationCityPlayer
            destinationCityID = lastRouteInfo.DestinationCityID
          end
        end

        if tradeManager:CanStartRoute(originPlayerID, originCityID, destinationPlayerID, destinationCityID) then
          local destinationPlayer = Players[destinationPlayerID]
          local destinationCity = destinationPlayer:GetCities():FindID(destinationCityID)

          local operationParams = {};
          operationParams[UnitOperationTypes.PARAM_X0] = destinationCity:GetX();
          operationParams[UnitOperationTypes.PARAM_Y0] = destinationCity:GetY();
          operationParams[UnitOperationTypes.PARAM_X1] = originCity:GetX();
          operationParams[UnitOperationTypes.PARAM_Y1] = originCity:GetY();

          if (UnitManager.CanStartOperation(pUnit, UnitOperationTypes.MAKE_TRADE_ROUTE, nil, operationParams)) then
            print_debug("Trader " .. unitID .. " renewed its trade route to " .. L_Lookup(destinationCity:GetName()));
            -- TODO: Send notification for renewing routes
            UnitManager.RequestOperation(pUnit, UnitOperationTypes.MAKE_TRADE_ROUTE, operationParams);
            renewedRoute = true
          else
            print("ERROR : Could not start a route");
          end
        else
          print("ERROR : Could not renew a route. Missing route info, or the destination is no longer a valid trade route destination.");
        end
      end
    end
  end

  -- Play sound, if a route was renewed.
  -- Done here to ensure the sound was only played once, if multiple traders were automated
  if renewedRoute then
    UI.PlaySound("START_TRADE_ROUTE");
    SaveTraderAutomatedInfo()
  end
end

function IsTraderAutomated(traderID:number)
  LoadTraderAutomatedInfo();

  if m_TradersAutomatedSettings[traderID] ~= nil then
    return m_TradersAutomatedSettings[traderID].IsAutomated;
  end

  return false;
end

function SaveTraderAutomatedInfo()
  -- Dump active routes info
  local localPlayerID = Game.GetLocalPlayer();
  -- print("Saving Trader Automated info in PlayerConfig database")
  local dataDump = DataDumper(m_TradersAutomatedSettings, "traderAutomatedSettings");
  -- print(dataDump);
  PlayerConfigurations[localPlayerID]:SetValue("BTS_TraderAutomatedSettings", dataDump);
end

function LoadTraderAutomatedInfo()
  local localPlayerID = Game.GetLocalPlayer();
  if(PlayerConfigurations[localPlayerID]:GetValue("BTS_TraderAutomatedSettings") ~= nil) then
    -- print("Retrieving trader automated settings from PlayerConfig database")
    local dataDump = PlayerConfigurations[localPlayerID]:GetValue("BTS_TraderAutomatedSettings");
    -- print(dataDump);
    loadstring(dataDump)();
    m_TradersAutomatedSettings = traderAutomatedSettings;
  else
    print("ERROR : No running route data was found, on load.")
  end
end

-- ---------------------------------------------------------------------------
-- Game event hookups (Local to this file)
-- ---------------------------------------------------------------------------

local function TradeSupportAutomater_OnPlayerTurnActivated( playerID:number, isFirstTime:boolean )
  if playerID == Game.GetLocalPlayer() and isFirstTime then
    RenewTradeRoutes();
  end
end

-- ===========================================================================
--  Cache Functions
-- ===========================================================================
function CacheRoutesInfo(tRoutes)
  if m_Cache.TurnBuilt ~= nil and m_Cache.TurnBuilt >= Game.GetCurrentGameTurn() then
    print_debug("OPT: Cache table already upto date")
    return false
  else
    print_debug("Caching routes")
    -- for i, routeInfo in ipairs(tRoutes) do
    for i=1, #tRoutes do
      CacheRoute(tRoutes[i])
      CachePlayer(tRoutes[i].DestinationCityPlayer)
    end
    m_Cache.TurnBuilt = Game.GetCurrentGameTurn()
    return true
  end
end

function CacheRoute(routeInfo)
  local key:string = GetRouteKey(routeInfo);
  -- print("Key for " .. GetTradeRouteString(routeInfo) .. " is " .. key)

  m_Cache[key] = {}

  -------------------------------------------------
  -- Yields
  -------------------------------------------------
  m_Cache[key].Yields = {}
  local netOriginYield:number = 0
  local netDestinationYield:number = 0
  for yieldIndex = START_INDEX, END_INDEX do
    local originYield = GetYieldForOriginCity(yieldIndex, routeInfo)
    local destinationYield = GetYieldForDestinationCity(yieldIndex, routeInfo)

    m_Cache[key].Yields[yieldIndex] = {
      Origin = originYield,
      Destination = destinationYield
    }

    netOriginYield = netOriginYield + originYield
    netDestinationYield = netDestinationYield + destinationYield
  end

  -------------------------------------------------
  -- Net Yields
  -------------------------------------------------
  m_Cache[key].NetOriginYield = netOriginYield
  m_Cache[key].NetDestinationYield = netDestinationYield

  -------------------------------------------------
  -- Trading Post
  -------------------------------------------------
  m_Cache[key].HasTradingPost = GetRouteHasTradingPost(routeInfo)

  -------------------------------------------------
  -- Advanced Info - Length, trips, turns
  -------------------------------------------------
  local tradePathLength, tripsToDestination, turnsToCompleteRoute = GetAdvancedRouteInfo(routeInfo);
  m_Cache[key].TurnsToCompleteRoute = turnsToCompleteRoute;
  m_Cache[key].TripsToDestination = tripsToDestination;
  m_Cache[key].TradePathLength = tradePathLength;

  -------------------------------------------------
  -- Turn Built
  -------------------------------------------------
  m_Cache[key].TurnBuilt = Game.GetCurrentGameTurn()

  -- print("KEY == " .. key)
  -- dump(m_Cache[key])
end

function CachePlayer(playerID)
  -- Make entry if none exists
  if m_Cache.Players == nil then m_Cache.Players = {} end

  if m_Cache.Players[playerID] == nil then

    m_Cache.Players[playerID] = {}

    -------------------------------------------------
    -- Active Route
    -------------------------------------------------
    m_Cache.Players[playerID].HasActiveRoute = GetHasActiveRoute(playerID);

    -------------------------------------------------
    -- Visibility Index
    -------------------------------------------------
    m_Cache.Players[playerID].VisibilityIndex = GetVisibilityIndex(playerID);

    -------------------------------------------------
    -- Icons, colors
    -------------------------------------------------
    local textureOffsetX, textureOffsetY, textureSheet, tooltip = GetPlayerIconInfo(playerID)
    local backColor, frontColor, darkerBackColor, brighterBackColor = GetPlayerColorInfo(playerID)

    m_Cache.Players[playerID].Icon = { textureOffsetX, textureOffsetY, textureSheet, tooltip }
    m_Cache.Players[playerID].Colors = { backColor, frontColor, darkerBackColor, brighterBackColor }

    -------------------------------------------------
    m_Cache.Players[playerID].TurnBuilt = Game.GetCurrentGameTurn()
  end
end

function CacheEmpty()
  -- If cache has entry TurnBuilt then the cache is built
  if m_Cache.TurnBuilt ~= nil then
    print_debug("CACHE Emptying")
    m_Cache = {}
  end
end

function GetRouteKey(routeInfo)
  return routeInfo.OriginCityPlayer .. "_" .. routeInfo.OriginCityID .. "_" ..
        routeInfo.DestinationCityPlayer .. "_" .. routeInfo.DestinationCityID;
end

function CacheKeyToRouteInfo(cacheKey)
  -- print("key: " .. cacheKey)
  local ids = Split(cacheKey, "_", 4) -- At max 4 entries should only exist
  local routeInfo = {
    OriginCityPlayer = tonumber(ids[1]),
    OriginCityID = tonumber(ids[2]),
    DestinationCityPlayer = tonumber(ids[3]),
    DestinationCityID = tonumber(ids[4])
  }

  -- dump(routeInfo)
  return routeInfo
end

-- ---------------------------------------------------------------------------
-- Cache lookups
-- ---------------------------------------------------------------------------

function Cached_GetYieldForOriginCity(yieldIndex:number, routeCacheKey:string)
  local cacheEntry = m_Cache[routeCacheKey]
  if cacheEntry ~= nil then
    -- print("CACHE HIT for " .. routeCacheKey)
    return cacheEntry.Yields[yieldIndex].Origin
  else
    print_debug("CACHE MISS for " .. routeCacheKey)
    CacheRoute(CacheKeyToRouteInfo(routeCacheKey));
    return m_Cache[routeCacheKey].Yields[yieldIndex].Origin
  end
end

function Cached_GetYieldForDestinationCity(yieldIndex:number, routeCacheKey:string)
  local cacheEntry = m_Cache[routeCacheKey]
  if cacheEntry ~= nil then
    -- print("CACHE HIT for " .. routeCacheKey)
    return cacheEntry.Yields[yieldIndex].Destination
  else
    print_debug("CACHE MISS for " .. routeCacheKey)
    CacheRoute(CacheKeyToRouteInfo(routeCacheKey));
    return m_Cache[routeCacheKey].Yields[yieldIndex].Destination
  end
end

function Cached_GetTurnsToComplete(routeCacheKey:string)
  if m_Cache[routeCacheKey] ~= nil then
    -- print("CACHE HIT for " .. routeCacheKey)
    return m_Cache[routeCacheKey].TurnsToCompleteRoute
  else
    print_debug("CACHE MISS for " .. routeCacheKey)
    CacheRoute(CacheKeyToRouteInfo(routeCacheKey));
    return m_Cache[routeCacheKey].TurnsToCompleteRoute
  end
end

-- ===========================================================================
--  Trade Route Sorter
-- ===========================================================================

-- This requires sort settings table passed.
function SortTradeRoutes( tradeRoutes:table, sortSettings:table)
  if table.count(sortSettings) > 0 then
    -- Score all routes based on sort settings, sort them
    local routeScores = ScoreRoutes(tradeRoutes, sortSettings)
    table.sort(routeScores, function(a, b) return ScoreComp(a, b, sortSettings) end )

    -- Build new table based on these sorted scores
    local routes = {}
    for i, scoreInfo in ipairs(routeScores) do
      routes[i] = tradeRoutes[scoreInfo.id]
    end
    return routes
  end

  -- No sort settings, return original array
  return tradeRoutes

  -- print("Total func calls: " .. debug_func_calls)
  -- debug_total_calls = debug_total_calls + debug_func_calls
  -- print("Total calls: " .. debug_total_calls)
  -- debug_func_calls = 0;
end

function GetTopRouteFromSortSettings( tradeRoutes:table, sortSettings:table )
  if sortSettings ~= nil and table.count(sortSettings) > 0 then
    local routeScores = ScoreRoutes(tradeRoutes, sortSettings)
    local minScoreInfo = GetMinEntry(routeScores, function(a, b) return ScoreComp(a, b, sortSettings) end )

    return tradeRoutes[minScoreInfo.id]
  end

  -- if no sort settings, return top entry
  return tradeRoutes[1];
end

-- ---------------------------------------------------------------------------
-- Score Route functions
-- ---------------------------------------------------------------------------

function ScoreRoutes( tradeRoutes:table, sortSettings:table )
  local scores = {}
  for index=1, #tradeRoutes do
    scores[index] = { id = index, score = ScoreRoute(tradeRoutes[index], sortSettings)}
  end
  return scores
end

function ScoreRoute( routeInfo:table, sortSettings:table )
  local score = {}
  for _, sortSetting in ipairs(sortSettings) do
    local scoreFunction = ScoreFunctionByID[sortSetting.SortByID];
    local val = scoreFunction(routeInfo)

    -- Change the sign, if in descending order. EX: (-)5 < (-)2
    if sortSetting.SortOrder == SORT_DESCENDING then
      -- Handle if val is string
      if type(val) == "string" then
        val = invert_string(val)
      else
        val = val * -1
      end
    end
    score[#score + 1] = val
  end

  -- Add final score, ie net yield
  score[#score + 1] = GetNetYieldForOriginCity(routeInfo, true)
  return score
end

function ScoreComp( scoreInfo1, scoreInfo2, sortSettings )
  local score1 = scoreInfo1.score
  local score2 = scoreInfo2.score
  if #score1 ~= #score2 then
    print("ERROR : scores unequal in length")
    return false
  end

  -- Last score is the net yield, it will not have a matching sortSetting
  for i=1, #score1-1 do
    if score1[i] < score2[i] then
      return true
    elseif score1[i] > score2[i] then
      return false
    end
  end

  return score1[#score1] > score2[#score1] -- Descending order of net yield
end

-- ---------------------------------------------------------------------------
-- Sort Entries functions
-- ---------------------------------------------------------------------------

function InsertSortEntry( sortByID:number, sortOrder:number, sortSettings:table )
  local sortEntry = {
    SortByID = sortByID,
    SortOrder = sortOrder
  };

  -- Only insert if it does not exist
  local sortEntryIndex = findIndex (sortSettings, sortEntry, CompareSortEntries);
  if sortEntryIndex == -1 then
    -- print("Inserting " .. sortEntry.SortByID);
    table.insert(sortSettings, sortEntry);
  else
    -- If it exists, just update the sort oder
    -- print("Index: " .. sortEntryIndex);
    sortSettings[sortEntryIndex].SortOrder = sortOrder;
  end
end

function RemoveSortEntry( sortByID:number, sortSettings:table  )
  local sortEntry = {
    SortByID = sortByID,
    SortOrder = sortOrder
  };

  -- Only delete if it exists
  local sortEntryIndex:number = findIndex(sortSettings, sortEntry, CompareSortEntries);

  if (sortEntryIndex > 0) then
    table.remove(sortSettings, sortEntryIndex);
  end
end

-- Checks for the same ID, not the same order
function CompareSortEntries( sortEntry1:table, sortEntry2:table)
  if sortEntry1.SortByID == sortEntry2.SortByID then
    return true;
  end

  return false;
end

-- ===========================================================================
--  Getter functions
-- ===========================================================================
-- Get idle Trade Units by Player ID
function GetIdleTradeUnits( playerID:number )
  local idleTradeUnits:table = {};

  -- Loop through the Players units
  local localPlayerUnits:table = Players[playerID]:GetUnits();
  for i,unit in localPlayerUnits:Members() do

    -- Find any trade units
    local unitInfo:table = GameInfo.Units[unit:GetUnitType()];
    if unitInfo.MakeTradeRoute then
      local doestradeUnitHasRoute:boolean = false;

      -- Determine if those trade units are busy by checking outgoing routes from the players cities
      local localPlayerCities:table = Players[playerID]:GetCities();
      for _, city in localPlayerCities:Members() do
        local routes = city:GetTrade():GetOutgoingRoutes();
        for _, route in ipairs(routes) do
          if route.TraderUnitID == unit:GetID() then
            doestradeUnitHasRoute = true;
          end
        end
      end

      -- If this trade unit isn't attached to an outgoing route then they are idle
      if not doestradeUnitHasRoute then
        table.insert(idleTradeUnits, unit);
      end
    end
  end

  return idleTradeUnits;
end

-- Returns a string of the route in format "[ORIGIN_CITY_NAME]-[DESTINATION_CITY_NAME]"
function GetTradeRouteString( routeInfo:table )
  local originCityName:string = "[NOT_FOUND]";
  local destinationCityName:string = "[NOT_FOUND]";

  local originPlayer:table = Players[routeInfo.OriginCityPlayer];
  if originPlayer ~= nil then
    local originCity:table = originPlayer:GetCities():FindID(routeInfo.OriginCityID);
    if originCity ~= nil then
      originCityName = L_Lookup(originCity:GetName());
    else
      print("Error : CITY", routeInfo.OriginCityID, "NOT FOUND")
    end
  else
    print("Error : PLAYER", routeInfo.OriginCityPlayer, "NOT FOUND")
  end

  local destinationPlayer:table = Players[routeInfo.DestinationCityPlayer];
  if destinationPlayer ~= nil then
    local destinationCity:table = destinationPlayer:GetCities():FindID(routeInfo.DestinationCityID);
    if destinationCity ~= nil then
      destinationCityName = L_Lookup(destinationCity:GetName());
    else
      print("Error : CITY", routeInfo.DestinationCityID, "NOT FOUND")
    end
  else
    print("Error : PLAYER", routeInfo.DestinationCityPlayer, "NOT FOUND")
  end

  return originCityName .. "-" .. destinationCityName;
end

function GetTradeRouteYieldString( routeInfo:table )
  local returnString:string = "";
  local originPlayer:table = Players[routeInfo.OriginCityPlayer];
  local originCity:table = originPlayer:GetCities():FindID(routeInfo.OriginCityID);

  local destinationPlayer:table = Players[routeInfo.DestinationCityPlayer];
  local destinationCity:table = destinationPlayer:GetCities():FindID(routeInfo.DestinationCityID);


  for yieldIndex = START_INDEX, END_INDEX do
    local originCityYieldValue = GetYieldForOriginCity(yieldIndex, routeInfo, true);
    -- Skip if yield is not more than 0
    if originCityYieldValue > 0 then
      local iconString, text = FormatYieldText(yieldIndex, originCityYieldValue);

      if (yieldIndex == FOOD_INDEX) then
        returnString = returnString .. text .. iconString .. " ";
      elseif (yieldIndex == PRODUCTION_INDEX) then
        returnString = returnString .. text .. iconString .. " ";
      elseif (yieldIndex == GOLD_INDEX) then
        returnString = returnString .. text .. iconString .. " ";
      elseif (yieldIndex == SCIENCE_INDEX) then
        returnString = returnString .. text .. iconString .. " ";
      elseif (yieldIndex == CULTURE_INDEX) then
        returnString = returnString .. text .. iconString .. " ";
      elseif (yieldIndex == FAITH_INDEX) then
        returnString = returnString .. text .. iconString;
      end
    end
  end

  return returnString;
end

-- Returns length of trade path, number of trips to destination, turns to complete route
function GetAdvancedRouteInfo(routeInfo)
  local eSpeed = GameConfiguration.GetGameSpeedType();

  if GameInfo.GameSpeeds[eSpeed] ~= nil then
    local iSpeedCostMultiplier = GameInfo.GameSpeeds[eSpeed].CostMultiplier;
    local tradeManager = Game.GetTradeManager();
    local pathPlots = tradeManager:GetTradeRoutePath(routeInfo.OriginCityPlayer, routeInfo.OriginCityID, routeInfo.DestinationCityPlayer, routeInfo.DestinationCityID);
    local tradePathLength:number = table.count(pathPlots) - 1;
    local multiplierConstant:number = 0.1;

    local tripsToDestination = 1 + math.floor(iSpeedCostMultiplier/tradePathLength * multiplierConstant);

    --print("Error: Playing on an unrecognized speed. Defaulting to standard for route turns calculation");
    local turnsToCompleteRoute = (tradePathLength * 2 * tripsToDestination);
    return tradePathLength, tripsToDestination, turnsToCompleteRoute;
  else
    print_debug("Speed type index " .. eSpeed);
    print("Error: Could not find game speed type. Defaulting to first entry in table");
    local iSpeedCostMultiplier =  GameInfo.GameSpeeds[1].CostMultiplier;
    local tradeManager = Game.GetTradeManager();
    local pathPlots = tradeManager:GetTradeRoutePath(routeInfo.OriginCityPlayer, routeInfo.OriginCityID, routeInfo.DestinationCityPlayer, routeInfo.DestinationCityID);
    local tradePathLength:number = table.count(pathPlots) - 1;
    local multiplierConstant:number = 0.1;

    local tripsToDestination = 1 + math.floor(iSpeedCostMultiplier/tradePathLength * multiplierConstant);
    local turnsToCompleteRoute = (tradePathLength * 2 * tripsToDestination);
    return tradePathLength, tripsToDestination, turnsToCompleteRoute;
  end
end

-- ---------------------------------------------------------------------------
-- Trade Route Getters
-- ---------------------------------------------------------------------------

function GetOriginCityName( routeInfo:table )
  -- TODO - Maybe implement cache for this?
  local pPlayer = Players[routeInfo.OriginCityPlayer]
  local pCity = pPlayer:GetCities():FindID(routeInfo.OriginCityID)
  return L_Lookup(pCity:GetName()) -- How does lua compare localized text?
end

function GetDestinationCityName( routeInfo:table )
  -- TODO - Maybe implement cache for this?
  local pPlayer = Players[routeInfo.DestinationCityPlayer]
  local pCity = pPlayer:GetCities():FindID(routeInfo.DestinationCityID)
  return L_Lookup(pCity:GetName()) -- How does lua compare localized text?
end

-- Returns yield for the origin city
function GetYieldForOriginCity( yieldIndex:number, routeInfo:table, checkCache)
  if checkCache then
    local key:string = GetRouteKey(routeInfo)
    return Cached_GetYieldForOriginCity(yieldIndex, key)
  else
    local tradeManager = Game.GetTradeManager();

    -- From route
    local yieldValue = tradeManager:CalculateOriginYieldFromPotentialRoute(routeInfo.OriginCityPlayer, routeInfo.OriginCityID, routeInfo.DestinationCityPlayer, routeInfo.DestinationCityID, yieldIndex);

    -- From path only if yield is gold. Trading posts add only gold.
    if yieldIndex == GameInfo.Yields["YIELD_GOLD"].Index then
      yieldValue = yieldValue + tradeManager:CalculateOriginYieldFromPath(routeInfo.OriginCityPlayer, routeInfo.OriginCityID, routeInfo.DestinationCityPlayer, routeInfo.DestinationCityID, yieldIndex);
    end

    -- From modifiers
    local resourceID = -1;
    yieldValue = yieldValue + tradeManager:CalculateOriginYieldFromModifiers(routeInfo.OriginCityPlayer, routeInfo.OriginCityID, routeInfo.DestinationCityPlayer, routeInfo.DestinationCityID, yieldIndex, resourceID);

    return yieldValue;
  end
end

-- Returns yield for the destination city
function GetYieldForDestinationCity( yieldIndex:number, routeInfo:table, checkCache )
  if checkCache then
    local key:string = GetRouteKey(routeInfo)
    return Cached_GetYieldForDestinationCity(yieldIndex, key)
  else
    local tradeManager = Game.GetTradeManager();

    -- From route
    local yieldValue = tradeManager:CalculateDestinationYieldFromPotentialRoute(routeInfo.OriginCityPlayer, routeInfo.OriginCityID, routeInfo.DestinationCityPlayer, routeInfo.DestinationCityID, yieldIndex);
    -- From path
    yieldValue = yieldValue + tradeManager:CalculateDestinationYieldFromPath(routeInfo.OriginCityPlayer, routeInfo.OriginCityID, routeInfo.DestinationCityPlayer, routeInfo.DestinationCityID, yieldIndex);
    -- From modifiers
    local resourceID = -1;
    yieldValue = yieldValue + tradeManager:CalculateDestinationYieldFromModifiers(routeInfo.OriginCityPlayer, routeInfo.OriginCityID, routeInfo.DestinationCityPlayer, routeInfo.DestinationCityID, yieldIndex, resourceID);

    return yieldValue;
  end
end

function GetNetYieldForOriginCity( routeInfo, checkCache )
  if checkCache then
    local key:string = GetRouteKey(routeInfo)
    if m_Cache[key] ~= nil then
      -- print("CACHE HIT for " .. GetTradeRouteString(routeInfo))
      return m_Cache[key].NetOriginYield
    else
      print_debug("CACHE MISS for " .. GetTradeRouteString(routeInfo))
      CacheRoute(routeInfo);
      return m_Cache[key].NetOriginYield
    end
  else
    local netYield:number = 0
    for iI = START_INDEX, END_INDEX do
      -- Dont check cache here
      netYield = netYield + GetYieldForOriginCity(iI, routeInfo)
    end
    return netYield
  end
end

function GetNetYieldForDestinationCity( routeInfo, checkCache )
  if checkCache then
    local key:string = GetRouteKey(routeInfo)
    if m_Cache[key] ~= nil then
      -- print("CACHE HIT for " .. GetTradeRouteString(routeInfo))
      return m_Cache[key].NetDestinationYield
    else
      print_debug("CACHE MISS for " .. GetTradeRouteString(routeInfo))
      CacheRoute(routeInfo);
      return m_Cache[key].NetDestinationYield
    end
  else
    local netYield:number = 0
    for iI = START_INDEX, END_INDEX do
      -- Dont check cache here
      netYield = netYield + GetYieldForDestinationCity(iI, routeInfo)
    end
    return netYield
  end
end

function GetTurnsToComplete(routeInfo, checkCache)
  if checkCache then
    local key = GetRouteKey(routeInfo)
    if m_Cache[key] ~= nil then
      -- print("CACHE HIT for " .. GetTradeRouteString(routeInfo))
      return m_Cache[key].TurnsToCompleteRoute
    else
      print_debug("CACHE MISS for " .. GetTradeRouteString(routeInfo))
      CacheRoute(routeInfo);
      return m_Cache[key].TurnsToCompleteRoute
    end
  else
    local tradePathLength, tripsToDestination, turnsToCompleteRoute = GetAdvancedRouteInfo(routeInfo);
    return turnsToCompleteRoute
  end
end

function GetRouteInfo(routeInfo, checkCache)
  if checkCache then
    local key = GetRouteKey(routeInfo)
    if m_Cache[key] ~= nil then
      -- print("CACHE HIT for " .. GetTradeRouteString(routeInfo))
      return m_Cache[key].TradePathLength, m_Cache[key].TripsToDestination, m_Cache[key].TurnsToCompleteRoute
    else
      print_debug("CACHE MISS for " .. GetTradeRouteString(routeInfo))
      CacheRoute(routeInfo)
      return m_Cache[key].TradePathLength, m_Cache[key].TripsToDestination, m_Cache[key].TurnsToCompleteRoute
    end
  else
    return GetAdvancedRouteInfo(routeInfo)
  end
end

function GetRouteHasTradingPost(routeInfo, checkCache)
  if checkCache then
    local key = GetRouteKey(routeInfo)
    if m_Cache[key] ~= nil then
      -- print("CACHE HIT for " .. GetTradeRouteString(routeInfo))
      return m_Cache[key].HasTradingPost
    else
      print_debug("CACHE MISS for " .. GetTradeRouteString(routeInfo))
      CacheRoute(routeInfo)
      return m_Cache[key].HasTradingPost
    end
  else
    local destinationPlayer:table = Players[routeInfo.DestinationCityPlayer];
    local destinationCity:table = destinationPlayer:GetCities():FindID(routeInfo.DestinationCityID);

    return destinationCity:GetTrade():HasActiveTradingPost(routeInfo.OriginCityPlayer)
  end
end

function GetHasActiveRoute(playerID, checkCache)
  if checkCache then
    if m_Cache.Players ~= nil and m_Cache.Players[playerID] ~= nil then
      -- print("CACHE HIT for player " .. playerID)
      return m_Cache.Players[playerID].HasActiveRoute
    else
      print_debug("CACHE MISS for player " .. playerID)
      CachePlayer(playerID)
      return m_Cache.Players[playerID].HasActiveRoute
    end
  else
    local pPlayer:table = Players[playerID];
    local playerCities:table = pPlayer:GetCities();
    for _, city in playerCities:Members() do
      if city:GetTrade():HasActiveTradingPost(Game.GetLocalPlayer()) then
        return true
      end
    end
    return false
  end
end

function GetVisibilityIndex(playerID, checkCache)
  if checkCache then
    if m_Cache.Players ~= nil and m_Cache.Players[playerID] ~= nil then
      -- print("CACHE HIT for player " .. playerID)
      return m_Cache.Players[playerID].VisibilityIndex
    else
      print_debug("CACHE MISS for player " .. playerID)
      CachePlayer(playerID)
      return m_Cache.Players[playerID].VisibilityIndex
    end
  else
    return Players[Game.GetLocalPlayer()]:GetDiplomacy():GetVisibilityOn(playerID);
  end
end

function GetPlayerIconInfo(playerID, checkCache)
  if checkCache then
    if m_Cache.Players ~= nil and m_Cache.Players[playerID] ~= nil then
      -- print("CACHE HIT for player " .. playerID)
      return unpack(m_Cache.Players[playerID].Icon)
    else
      print_debug("CACHE MISS for player " .. playerID)
      CachePlayer(playerID)
      return unpack(m_Cache.Players[playerID].Icon)
    end
  else
    local pPlayer = Players[playerID];
    local playerConfig:table = PlayerConfigurations[playerID];
    local playerInfluence:table = pPlayer:GetInfluence();
    local playerIconString:string;
    if playerConfig ~= nil then
      if not playerInfluence:CanReceiveInfluence() then
        -- Civilizations
        playerIconString = "ICON_" .. playerConfig:GetCivilizationTypeName();
      else
        -- City States
        local leader:string = playerConfig:GetLeaderTypeName();
        local leaderInfo:table  = GameInfo.Leaders[leader];

        if (leader == "LEADER_MINOR_CIV_SCIENTIFIC" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_SCIENTIFIC") then
          playerIconString = "ICON_CITYSTATE_SCIENCE";
        elseif (leader == "LEADER_MINOR_CIV_RELIGIOUS" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_RELIGIOUS") then
          playerIconString = "ICON_CITYSTATE_FAITH";
        elseif (leader == "LEADER_MINOR_CIV_TRADE" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_TRADE") then
          playerIconString = "ICON_CITYSTATE_TRADE";
        elseif (leader == "LEADER_MINOR_CIV_CULTURAL" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_CULTURAL") then
          playerIconString = "ICON_CITYSTATE_CULTURE";
        elseif (leader == "LEADER_MINOR_CIV_MILITARISTIC" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_MILITARISTIC") then
          playerIconString = "ICON_CITYSTATE_MILITARISTIC";
        elseif (leader == "LEADER_MINOR_CIV_INDUSTRIAL" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_INDUSTRIAL") then
          playerIconString = "ICON_CITYSTATE_INDUSTRIAL";
        end
      end

      local playerDescription:string = playerConfig:GetCivilizationDescription();
      local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(playerIconString, 30)

      return textureOffsetX, textureOffsetY, textureSheet, playerDescription;
    end
  end
end

function GetPlayerColorInfo(playerID, checkCache)
  if checkCache then
    if m_Cache.Players ~= nil and m_Cache.Players[playerID] ~= nil then
      -- print("CACHE HIT for player " .. playerID)
      return unpack(m_Cache.Players[playerID].Colors)
    else
      print_debug("CACHE MISS for player " .. playerID)
      CachePlayer(playerID)
      return unpack(m_Cache.Players[playerID].Colors)
    end
  else
    local backColor, frontColor = UI.GetPlayerColors(playerID)
    local darkerBackColor = DarkenLightenColor(backColor, BACKDROP_DARKER_OFFSET, BACKDROP_DARKER_OPACITY);
    local brighterBackColor = DarkenLightenColor(backColor, BACKDROP_BRIGHTER_OFFSET, BACKDROP_BRIGHTER_OPACITY);

    return backColor, frontColor, darkerBackColor, brighterBackColor
  end
end

-- ===========================================================================
--  General Helper functions
-- ===========================================================================

-- Simple check to seeif player1 and player2 can possibly have a trade route.
function CanPossiblyTradeWithPlayer(player1, player2)
  if player1 == player2 then return true; end

  local pPlayer1 = Players[player1];
  local pPlayer1Diplomacy = pPlayer1:GetDiplomacy();
  local pPlayer2 = Players[player2]

  if pPlayer2:IsAlive() and pPlayer1Diplomacy:HasMet(player2) then
    if not pPlayer1Diplomacy:IsAtWarWith(player2) then
      return true;
    end
  end

  return false;
end

function IsRoutePossible(originCityPlayerID, originCityID, destinationCityPlayerID, destinationCityID)
  local tradeManager:table = Game.GetTradeManager();

  return tradeManager:CanStartRoute(originCityPlayerID, originCityID, destinationCityPlayerID, destinationCityID);
end

function FormatYieldText(yieldIndex, yieldAmount)
  if yieldAmount == 0 then
    return "", ""
  end

  local iconString:string = ICON_LOOKUP[yieldIndex]

  local text:string;
  if yieldAmount > 0 then
    text = "+";
  else
    text = "-";
  end
  text = text .. yieldAmount;

  return iconString, text;
end

-- Finds and removes routeToDelete from routeTable
function RemoveRouteFromTable( routeToDelete:table , routeTable:table, isGrouped:boolean )
  -- If grouping by something, go one level deeper
  if isGrouped then
    print_debug("Routes grouped")
    local targetIndex:number = -1;
    local targetGroupIndex:number = -1;

    for i, groupedRoutes in ipairs(routeTable) do
      for j, route in ipairs(groupedRoutes) do
        if CheckRouteEquality( route, routeToDelete ) then
          targetIndex = j;
          targetGroupIndex = i;
          break
        end
      end
    end

    -- Remove route
    if targetIndex ~= -1 and targetGroupIndex ~= -1 then
      print_debug("REMOVING ROUTE")
      table.remove(routeTable[targetGroupIndex], targetIndex);

      -- If that group is empty, remove that group
      if table.count(routeTable[targetGroupIndex]) <= 0 then
        table.remove(routeTable, targetGroupIndex);
      end
    else
      print("Error : COULD NOT FIND ROUTE")
    end
  else
    print_debug("Routes not grouped")

    -- Find and remove route
    local targetIndex:number = findIndex(routeTable, routeToDelete, CheckRouteEquality)
    if targetIndex ~= -1 then
      print_debug("REMOVING ROUTE")
      table.remove(routeTable, targetIndex);
    else
      print("Error : COULD NOT FIND ROUTE")
    end
  end
end

-- Checks if the two routes are the same (does not compare traderUnit)
function CheckRouteEquality ( tradeRoute1:table, tradeRoute2:table )
  if (    tradeRoute1.OriginCityPlayer == tradeRoute2.OriginCityPlayer and
      tradeRoute1.OriginCityID == tradeRoute2.OriginCityID and
      tradeRoute1.DestinationCityPlayer == tradeRoute2.DestinationCityPlayer and
      tradeRoute1.DestinationCityID == tradeRoute2.DestinationCityID ) then
    return true;
  end

  return false;
end

function IsCityState( player:table )
  local playerInfluence:table = player:GetInfluence();
  if  playerInfluence:CanReceiveInfluence() then
    return true
  end

  return false
end

-- Checks if the player is a city state, with "Send a trade route" quest
function IsCityStateWithTradeQuest( player:table )
  local questsManager:table = Game.GetQuestsManager();
  local localPlayer = Game.GetLocalPlayer()
  if (questsManager ~= nil and localPlayer ~= nil) then
    local tradeRouteQuestInfo:table = GameInfo.Quests["QUEST_SEND_TRADE_ROUTE"];
    if (tradeRouteQuestInfo ~= nil) then
      if (questsManager:HasActiveQuestFromPlayer(localPlayer, player:GetID(), tradeRouteQuestInfo.Index)) then
        return true
      end
    end
  end

  return false
end

-- Checks if the player is a civ, other than the local player
function IsOtherCiv( player:table )
  if player:GetID() ~= Game.GetLocalPlayer() then
    return true
  end

  return false
end

-- ===========================================================================
--  Helper Utility functions
-- ===========================================================================

-- Converts 'A' -> 'Z' || 'Z' -> 'A'
function invert_string(s:string)
  s = s:upper()
  print_debug("org: " .. s)
  local newS:string = ""
  for i=1, s:len() do
    newS = newS .. string.char(invert_char_code(s:byte(i)))
  end
  print_debug("inv: " .. newS)
  return newS
end

function invert_char_code(code:number)
  local delta = string.byte("Z", 1) - code
  return delta + string.byte("A", 1)
end

function table_nnill_count(T:table)
  local count = 0
  for k in pairs(T) do
    if T[k] ~= nil then
      count = count + 1
    end
  end
  return count
end

function findIndex(T, searchItem, compareFunc)
  for index, item in ipairs(T) do
    if compareFunc(item, searchItem) then
      return index;
    end
  end

  return -1;
end

function GetMinEntry(searchTable, compareFunc)
  local minIndex = 1
  for index=1, #searchTable do
    if not compareFunc(searchTable[minIndex], searchTable[index]) then
      minIndex = index;
    end
  end
  return searchTable[minIndex], minIndex
end

-- ========== START OF DataDumper.lua =================
--[[ DataDumper.lua
  Copyright (c) 2007 Olivetti-Engineering SA

  Permission is hereby granted, free of charge, to any person
  obtaining a copy of this software and associated documentation
  files (the "Software"), to deal in the Software without
  restriction, including without limitation the rights to use,
  copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the
  Software is furnished to do so, subject to the following
  conditions:

  The above copyright notice and this permission notice shall be
  included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
  OTHER DEALINGS IN THE SOFTWARE.
  ]]

  function dump(...)
  print(DataDumper(...), "\n---")
  end

  local dumplua_closure = [[
  local closures = {}
  local function closure(t)
  closures[#closures+1] = t
  t[1] = assert(loadstring(t[1]))
  return t[1]
  end

  for _,t in pairs(closures) do
  for i = 2,#t do
    debug.setupvalue(t[1], i-1, t[i])
  end
  end
  ]]

  local lua_reserved_keywords = {
  'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for',
  'function', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat',
  'return', 'then', 'true', 'until', 'while' }

  local function keys(t)
  local res = {}
  local oktypes = { stringstring = true, numbernumber = true }
  local function cmpfct(a,b)
    if oktypes[type(a)..type(b)] then
    return a < b
    else
    return type(a) < type(b)
    end
  end
  for k in pairs(t) do
    res[#res+1] = k
  end
  table.sort(res, cmpfct)
  return res
  end

  local c_functions = {}
  for _,lib in pairs{'_G', 'string', 'table', 'math',
    'io', 'os', 'coroutine', 'package', 'debug'} do
  local t = {}
  lib = lib .. "."
  if lib == "_G." then lib = "" end
  for k,v in pairs(t) do
    if type(v) == 'function' and not pcall(string.dump, v) then
    c_functions[v] = lib..k
    end
  end
  end

  function DataDumper(value, varname, fastmode, ident)
  local defined, dumplua = {}
  -- Local variables for speed optimization
  local string_format, type, string_dump, string_rep =
      string.format, type, string.dump, string.rep
  local tostring, pairs, table_concat =
      tostring, pairs, table.concat
  local keycache, strvalcache, out, closure_cnt = {}, {}, {}, 0
  setmetatable(strvalcache, {__index = function(t,value)
    local res = string_format('%q', value)
    t[value] = res
    return res
  end})
  local fcts = {
    string = function(value) return strvalcache[value] end,
    number = function(value) return value end,
    boolean = function(value) return tostring(value) end,
    ['nil'] = function(value) return 'nil' end,
    ['function'] = function(value)
    return string_format("loadstring(%q)", string_dump(value))
    end,
    userdata = function() error("Cannot dump userdata") end,
    thread = function() error("Cannot dump threads") end,
  }
  local function test_defined(value, path)
    if defined[value] then
    if path:match("^getmetatable.*%)$") then
      out[#out+1] = string_format("s%s, %s)\n", path:sub(2,-2), defined[value])
    else
      out[#out+1] = path .. " = " .. defined[value] .. "\n"
    end
    return true
    end
    defined[value] = path
  end
  local function make_key(t, key)
    local s
    if type(key) == 'string' and key:match('^[_%a][_%w]*$') then
    s = key .. "="
    else
    s = "[" .. dumplua(key, 0) .. "]="
    end
    t[key] = s
    return s
  end
  for _,k in ipairs(lua_reserved_keywords) do
    keycache[k] = '["'..k..'"] = '
  end
  if fastmode then
    fcts.table = function (value)
    -- Table value
    local numidx = 1
    out[#out+1] = "{"
    for key,val in pairs(value) do
      if key == numidx then
      numidx = numidx + 1
      else
      out[#out+1] = keycache[key]
      end
      local str = dumplua(val)
      out[#out+1] = str..","
    end
    if string.sub(out[#out], -1) == "," then
      out[#out] = string.sub(out[#out], 1, -2);
    end
    out[#out+1] = "}"
    return ""
    end
  else
    fcts.table = function (value, ident, path)
    if test_defined(value, path) then return "nil" end
    -- Table value
    local sep, str, numidx, totallen = " ", {}, 1, 0
    local meta, metastr = getmetatable(value)
    if meta then
      ident = ident + 1
      metastr = dumplua(meta, ident, "getmetatable("..path..")")
      totallen = totallen + #metastr + 16
    end
    for _,key in pairs(keys(value)) do
      local val = value[key]
      local s = ""
      local subpath = path or ""
      if key == numidx then
      subpath = subpath .. "[" .. numidx .. "]"
      numidx = numidx + 1
      else
      s = keycache[key]
      if not s:match "^%[" then subpath = subpath .. "." end
      subpath = subpath .. s:gsub("%s*=%s*$","")
      end
      s = s .. dumplua(val, ident+1, subpath)
      str[#str+1] = s
      totallen = totallen + #s + 2
    end
    if totallen > 80 then
      sep = "\n" .. string_rep("  ", ident+1)
    end
    str = "{"..sep..table_concat(str, ","..sep).." "..sep:sub(1,-3).."}"
    if meta then
      sep = sep:sub(1,-3)
      return "setmetatable("..sep..str..","..sep..metastr..sep:sub(1,-3)..")"
    end
    return str
    end
    fcts['function'] = function (value, ident, path)
    if test_defined(value, path) then return "nil" end
    if c_functions[value] then
      return c_functions[value]
    elseif debug == nil or debug.getupvalue(value, 1) == nil then
      return string_format("loadstring(%q)", string_dump(value))
    end
    closure_cnt = closure_cnt + 1
    local res = {string.dump(value)}
    for i = 1,math.huge do
      local name, v = debug.getupvalue(value,i)
      if name == nil then break end
      res[i+1] = v
    end
    return "closure " .. dumplua(res, ident, "closures["..closure_cnt.."]")
    end
  end
  function dumplua(value, ident, path)
    return fcts[type(value)](value, ident, path)
  end
  if varname == nil then
    varname = ""
  elseif varname:match("^[%a_][%w_]*$") then
    varname = varname .. " = "
  end
  if fastmode then
    setmetatable(keycache, {__index = make_key })
    out[1] = varname
    table.insert(out,dumplua(value, 0))
    return table.concat(out)
  else
    setmetatable(keycache, {__index = make_key })
    local items = {}
    for i=1,10 do items[i] = '' end
    items[3] = dumplua(value, ident or 0, "t")
    if closure_cnt > 0 then
    items[1], items[6] = dumplua_closure:match("(.*\n)\n(.*)")
    out[#out+1] = ""
    end
    if #out > 0 then
    items[2], items[4] = "local t = ", "\n"
    items[5] = table.concat(out)
    items[7] = varname .. "t"
    else
    items[2] = varname
    end
    return table.concat(items)
  end
  end
-- ========== END OF DataDumper.lua =================

-- ===========================================================================
--  Event handlers
-- ===========================================================================

function TradeSupportTracker_Initialize()
  print("Initializing BTS Trade Support Tracker");

  -- Load Previous Routes
  LoadRunningRoutesInfo();

  Events.UnitOperationStarted.Add( TradeSupportTracker_OnUnitOperationStarted );
  Events.UnitOperationsCleared.Add( TradeSupportTracker_OnUnitOperationsCleared );
  Events.PlayerTurnActivated.Add( TradeSupportTracker_OnPlayerTurnActivated );
end

function TradeSupportAutomater_Initialize()
  print("Initializing BTS Trade Support Automater");

  -- Load previous automated settings
  LoadTraderAutomatedInfo();

  Events.PlayerTurnActivated.Add( TradeSupportAutomater_OnPlayerTurnActivated );
end
