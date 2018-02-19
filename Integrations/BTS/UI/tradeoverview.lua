-- ===========================================================================
--  SETTINGS
-- ===========================================================================

local showSortOrdersPermanently = false
local addDividerBetweenGroups = true
local hideTradingPostIcon = false

-- Color Settings for Headers
local colorCityPlayerHeader = true
local backdropGridColorOffset = 20
local backdropGridColorOpacity = 140
local backdropColorOffset = -15
local backdropColorOpacity = 55
local labelColorOffset = -27
local labelColorOpacity = 255

-- Color Settings for Route Entry
local tintRouteEntry = false
local tintColorOffset = 80
local tintColorOpacity = 205

-- ===========================================================================
--  INCLUDES and Local Optimizations
-- ===========================================================================

include("AnimSidePanelSupport");
include("PopupDialogSupport");
include("InstanceManager");
include("SupportFunctions");
include("TradeSupport");
include("civ6common");

local Game = Game
local Players = Players
local ContextPtr = ContextPtr
local Events = Events

local ipairs = ipairs
local pairs = pairs
local tinsert = table.insert
local tcount = table.count
local tremove = table.remove

local L_Lookup = Locale.Lookup
local L_Upper = Locale.ToUpper

local M_LCick = Mouse.eLClick
local M_Enter = Mouse.eMouseEnter
local M_RClick = Mouse.eRClick

-- ===========================================================================
--  CONSTANTS
-- ===========================================================================

local RELOAD_CACHE_ID:string = "TradeOverview"; -- Must be unique (usually the same as the file name)
local OUTSIDE_SUPPORT_CACHE_ID:string = "TradeOverviewSupport";
local DATA_ICON_PREFIX:string = "ICON_";

local TRADE_TABS:table = {
  MY_ROUTES           = 0;
  ROUTES_TO_CITIES    = 1;
  AVAILABLE_ROUTES    = 2;
};

local GROUP_BY_SETTINGS:table = {
  NONE                = 1;
  ORIGIN              = 2;
  DESTINATION         = 3;

  -- Special group by's (these get converted to sort settings in OnGroupBySelected)
  ORIGIN_AZ           = 4;
  ORIGIN_ZA           = 5;
  DESTINATION_AZ      = 6;
  DESTINATION_ZA      = 7;
};

local SEMI_EXPAND_SETTINGS:table = {};
SEMI_EXPAND_SETTINGS[GROUP_BY_SETTINGS.ORIGIN] = 4;
SEMI_EXPAND_SETTINGS[GROUP_BY_SETTINGS.DESTINATION] = 2;

local BASE_TOURISM_MODIFIER = GlobalParameters.TOURISM_TRADE_ROUTE_BONUS;

-- ===========================================================================
--  VARIABLES
-- ===========================================================================
local m_RouteInstanceIM:table           = InstanceManager:new("RouteInstance", "Top", Controls.BodyStack);
local m_HeaderInstanceIM:table          = InstanceManager:new("HeaderInstance", "Top", Controls.BodyStack);
local m_SimpleButtonInstanceIM:table    = InstanceManager:new("SimpleButtonInstance", "Top", Controls.BodyStack);
local m_DividerInstanceIM:table         = InstanceManager:new("SectionDividerInstance", "Top", Controls.BodyStack);

local m_AnimSupport:table; -- AnimSidePanelSupport

local m_currentTab:number = TRADE_TABS.MY_ROUTES;

local m_shiftDown:boolean = false;
local m_ctrlDown:boolean = false;
local m_sortCallRefresh:boolean = false;

-- Trade Routes Tables
local m_AvailableTradeRoutes:table = {};        -- Stores all available routes
local m_FinalTradeRoutes:table = {};            -- Filter version of above
local m_AvailableGroupedRoutes:table = {};      -- Grouped version of routes. Built from above

local m_AvailableTraders:table = {};            -- Indexed by the city id, value stored is the unit id
local m_TurnUpdatedTraders:number = -1;

-- Stores filter list and tracks the currently selected list
local m_filterList:table = {};
local m_filterCount:number = 0;
local m_filterSelected:number = 1;

local m_groupBySelected:number = GROUP_BY_SETTINGS.DESTINATION;
local m_groupByList:table = {};

local m_GroupExpandAll:boolean = false;
local m_GroupCollapseAll:boolean = false;

local m_GroupsFullyExpanded:table = {};
local m_GroupsFullyCollapsed:table = {};

local m_HasBuiltTradeRouteTable:boolean = false;
local m_LastTurnBuiltTradeRouteTable:number = -1;
local m_SortSettingsChanged:boolean = true;
local m_GroupSettingsChanged:boolean = true;
local m_FilterSettingsChanged:boolean = true;

-- Stores the sort settings.
local m_InGroupSortBySettings = {}; -- Stores the setting each group will have within it. Applicable when routes are grouped
local m_GroupSortBySettings = {}; -- Stores the overall group sort setting. This is used, when routes are NOT grouped

-- Default sort setting = Smart descending gold, ie second level is lowest turns consumed
m_GroupSortBySettings[1] = {
  SortByID = SORT_BY_ID.GOLD,
  SortOrder = SORT_DESCENDING
}
m_InGroupSortBySettings[1] = {
  SortByID = SORT_BY_ID.GOLD,
  SortOrder = SORT_DESCENDING
}
m_InGroupSortBySettings[2] = {
  SortByID = SORT_BY_ID.TURNS_TO_COMPLETE,
  SortOrder = SORT_ASCENDING
}

local m_dividerCount = 0

-- ===========================================================================
--  CQUI
-- ===========================================================================

function CQUI_OnSettingsUpdate()
  showSortOrdersPermanently = GameConfiguration.GetValue("CQUI_TraderShowSortOrder");
  addDividerBetweenGroups = GameConfiguration.GetValue("CQUI_TraderAddDivider");

  Refresh()
end

-- ===========================================================================
--  Refresh functions
-- ===========================================================================

-- Finds and adds all possible trade routes
function RebuildAvailableTradeRoutesTable()
  print_debug ("Rebuilding Trade Routes table");
  m_AvailableTradeRoutes = {};

  local sourcePlayerID = Game.GetLocalPlayer();
  local sourceCities:table = Players[sourcePlayerID]:GetCities();
  local players:table = Game.GetPlayers{ Alive=true };
  local destinationCitiesID:table = {};
  local tradeManager:table = Game.GetTradeManager();

  for _, sourceCity in sourceCities:Members() do
    local sourceCityID:number = sourceCity:GetID();
    for _, destinationPlayer in ipairs(players) do
      local destinationPlayerID:number = destinationPlayer:GetID()
      -- Check for war, met, etc
      if CanPossiblyTradeWithPlayer(sourcePlayerID, destinationPlayerID) then
        for _, destinationCity in destinationPlayer:GetCities():Members() do
          local destinationCityID:number = destinationCity:GetID();
          if tradeManager:CanStartRoute(sourcePlayerID, sourceCityID, destinationPlayerID, destinationCityID) then
            -- Create the trade route entry
            local tradeRoute = {
              OriginCityPlayer        = sourcePlayerID,
              OriginCityID            = sourceCityID,
              DestinationCityPlayer   = destinationPlayerID,
              DestinationCityID       = destinationCityID
            };

            tinsert(m_AvailableTradeRoutes, tradeRoute);
          end
        end
      end
    end
  end

  print_debug("Total routes = " .. tcount(m_AvailableTradeRoutes))

  m_HasBuiltTradeRouteTable = true;
  m_LastTurnBuiltTradeRouteTable = Game.GetCurrentGameTurn();
end

function RebuildAvailableTraders()
  print_debug("Building available traders")
  local playerID = Game.GetLocalPlayer()
  local pPlayer = Players[playerID]
  local pPlayerUnits = pPlayer:GetUnits()
  m_AvailableTraders = {}

  for i, pUnit in pPlayerUnits:Members() do
    local unitInfo:table = GameInfo.Units[pUnit:GetUnitType()];
    local unitID:number = pUnit:GetID();
    if unitInfo.MakeTradeRoute == true and (not pUnit:HasPendingOperations()) then
      local pCity = Cities.GetCityInPlot(pUnit:GetX(), pUnit:GetY());
      if pCity ~= nil then
        local cityID = pCity:GetID()

        -- Make entry if none exists
        if m_AvailableTraders[cityID] == nil then
          m_AvailableTraders[cityID] = {}
        end

        -- Append unit into the entry
        tinsert(m_AvailableTraders[cityID], unitID)
      end
    end
  end

  m_TurnUpdatedTraders = Game.GetCurrentGameTurn()
end

function Refresh()
  local time1 = Automation.GetTime();
  print_debug("Refresh start")
  PreRefresh();

  RefreshGroupByPulldown();
  RefreshFilters();
  RefreshSortBar();

  if m_TurnUpdatedTraders < Game.GetCurrentGameTurn() then
    RebuildAvailableTraders()
  end

  if m_currentTab == TRADE_TABS.MY_ROUTES then
    ViewMyRoutes();
  elseif m_currentTab == TRADE_TABS.ROUTES_TO_CITIES then
    ViewRoutesToCities();
  elseif m_currentTab == TRADE_TABS.AVAILABLE_ROUTES then
    ViewAvailableRoutes();
  else
    ViewMyRoutes();
  end

  PostRefresh();
  local time2 = Automation.GetTime()
  print_debug(string.format("Time taken to refresh: %.4f sec(s)", time2-time1))
end

function PreRefresh()
  -- Reset Stack
  m_RouteInstanceIM:ResetInstances();
  m_HeaderInstanceIM:ResetInstances();
  m_SimpleButtonInstanceIM:ResetInstances();
  m_DividerInstanceIM:ResetInstances();
  m_dividerCount = 0
end

function PostRefresh()
  -- Calculate Stack Sizes
  local time1 = Automation.GetTime()
  Controls.HeaderStack:CalculateSize();
  Controls.HeaderStack:ReprocessAnchoring();
  Controls.BodyScrollPanel:CalculateSize();
  Controls.BodyScrollPanel:ReprocessAnchoring();
  Controls.BodyScrollPanel:CalculateInternalSize();
  local time2 = Automation.GetTime()
  print_debug(string.format("Time to calculate stack sizes: %.4f sec(s)", time2-time1))
end

-- ===========================================================================
--  Tab functions
-- ===========================================================================

-- Show My Routes Tab
function ViewMyRoutes()

  -- Update Tabs
  SetMyRoutesTabSelected(true);
  SetRoutesToCitiesTabSelected(false);
  SetAvailableRoutesTabSelected(false);

  local localPlayerID = Game.GetLocalPlayer();
  if (localPlayerID == -1) then
    return;
  end

  -- Update Header
  local playerTrade   :table  = Players[localPlayerID]:GetTrade();
  local routesActive  :number = playerTrade:GetNumOutgoingRoutes();
  local routesCapacity:number = playerTrade:GetOutgoingRouteCapacity();
  Controls.HeaderLabel:SetText(L_Upper("LOC_TRADE_OVERVIEW_MY_ROUTES"));
  Controls.ActiveRoutesLabel:SetHide(false);

  -- If our active routes exceed our route capacity then color active route number red
  local routesActiveText:string = ""
  if routesActive > routesCapacity then
    routesActiveText = "[COLOR_RED]" .. tostring(routesActive) .. "[ENDCOLOR]";
  else
    routesActiveText = tostring(routesActive);
  end
  Controls.ActiveRoutesLabel:SetText(L_Lookup("LOC_TRADE_OVERVIEW_ACTIVE_ROUTES", routesActiveText, routesCapacity));

  local localPlayerRunningRoutes:table = GetLocalPlayerRunningRoutes();

  -- Gather data and apply filter
  local routesSortedByPlayer:table = {};
  for _, route in ipairs(localPlayerRunningRoutes) do
    if m_filterList[m_filterSelected].FilterFunction and m_filterList[m_filterSelected].FilterFunction(Players[route.DestinationCityPlayer]) then
      -- Make sure we have a table for each destination player
      if routesSortedByPlayer[route.DestinationCityPlayer] == nil then
        routesSortedByPlayer[route.DestinationCityPlayer] = {};
      end

      tinsert(routesSortedByPlayer[route.DestinationCityPlayer], route);
    end
  end

  -- Add routes to local player cities
  if routesSortedByPlayer[localPlayerID] ~= nil then
    CreatePlayerHeader(Players[localPlayerID]);

    routesSortedByPlayer[localPlayerID] = SortTradeRoutes(routesSortedByPlayer[localPlayerID], m_GroupSortBySettings);

    for _, route in ipairs(routesSortedByPlayer[localPlayerID]) do
      AddRouteInstanceFromRouteInfo(route);
    end
  end

  -- Add routes to other civs
  local haveAddedCityStateHeader:boolean = false;
  for playerID, routes in pairs(routesSortedByPlayer) do
    if playerID ~= localPlayerID then
      routes = SortTradeRoutes(routes, m_GroupSortBySettings);

      -- Skip City States as these are added below
      local playerInfluence:table = Players[playerID]:GetInfluence();
      if not playerInfluence:CanReceiveInfluence() then
        CreatePlayerHeader(Players[playerID]);

        for _, route in ipairs(routes) do
          AddRouteInstanceFromRouteInfo(route);
        end
      else
        -- Add city state routes
        if not haveAddedCityStateHeader then
          haveAddedCityStateHeader = true;
          CreateCityStateHeader();
        end

        for _, route in ipairs(routes) do
          AddRouteInstanceFromRouteInfo(route);
        end
      end
    end
  end

  -- Determine how many unused routes we have
  local unusedRoutes  :number = routesCapacity - routesActive;
  if unusedRoutes > 0 then
    CreateUnusedRoutesHeader();

    local idleTradeUnits:table = GetIdleTradeUnits(localPlayerID);

    -- Assign idle trade units to unused routes
    for i=1, unusedRoutes, 1 do
      if #idleTradeUnits > 0 then
        -- Add button to choose a route for this trader
        AddChooseRouteButtonInstance(idleTradeUnits[1]);
        tremove(idleTradeUnits, 1);
      else
        -- Add button to produce new trade unit
        AddProduceTradeUnitButtonInstance();
      end
    end
  end
end

-- Show Routes To My Cities Tab
function ViewRoutesToCities()

  -- Update Tabs
  SetMyRoutesTabSelected(false);
  SetRoutesToCitiesTabSelected(true);
  SetAvailableRoutesTabSelected(false);

  -- Update Header
  Controls.HeaderLabel:SetText(L_Upper("LOC_TRADE_OVERVIEW_ROUTES_TO_MY_CITIES"));
  Controls.ActiveRoutesLabel:SetHide(true);

  -- Gather data
  local routesSortedByPlayer:table = {};
  local players = Game.GetPlayers{ Alive=true };
  for _, player in ipairs(players) do
    -- Don't show domestic routes
    if player:GetID() ~= Game.GetLocalPlayer() then
      if m_filterList[m_filterSelected].FilterFunction and m_filterList[m_filterSelected].FilterFunction(player) then
        for _, city in player:GetCities():Members() do
          local outgoingRoutes = city:GetTrade():GetOutgoingRoutes();
          for _, route in ipairs(outgoingRoutes) do
            -- Make sure the destination city is owned by the local player
            if route.DestinationCityPlayer == Game.GetLocalPlayer() then
              -- Make sure we have a table for each destination player
              if routesSortedByPlayer[route.OriginCityPlayer] == nil then
                routesSortedByPlayer[route.OriginCityPlayer] = {};
              end

              tinsert(routesSortedByPlayer[route.OriginCityPlayer], route);
            end
          end
        end
      end
    end
  end

  -- Add routes to stack
  for playerID, routes in pairs(routesSortedByPlayer) do
    CreatePlayerHeader(Players[playerID]);

    -- Sort the routes
    routes = SortTradeRoutes(routes, m_GroupSortBySettings);

    for _, route in ipairs(routes) do
      AddRouteInstanceFromRouteInfo(route);
    end
  end
end

-- Show Available Routes Tab
-- Note: There is a lot OPT prints and time information calculated
-- This is just for logging purposes and don't affect the logic in any way
function ViewAvailableRoutes()

  -- Update Tabs
  SetMyRoutesTabSelected(false);
  SetRoutesToCitiesTabSelected(false);
  SetAvailableRoutesTabSelected(true);

  local localPlayerID = Game.GetLocalPlayer();
  if (localPlayerID == -1) then
    return;
  end

  local time1, time2;

  -- Update Header
  Controls.HeaderLabel:SetText(L_Upper("LOC_TRADE_OVERVIEW_AVAILABLE_ROUTES"));
  Controls.ActiveRoutesLabel:SetHide(true);

  -- Dont rebuild if the turn has not advanced
  if (not m_HasBuiltTradeRouteTable) or Game.GetCurrentGameTurn() > m_LastTurnBuiltTradeRouteTable then
    time1 = Automation.GetTime()
    RebuildAvailableTradeRoutesTable();
    time2 = Automation.GetTime()
    print_debug(string.format("Time taken to build routes: %.4f sec(s)", time2-time1))

    -- Cache routes info.
    time1 = Automation.GetTime()
    CacheEmpty();
    if CacheRoutesInfo(m_AvailableTradeRoutes) then
      time2 = Automation.GetTime()
      print_debug(string.format("Time taken to cache: %.4f sec(s)", time2-time1))
    end

    -- Just rebuilt base routes table. need to do everything again
    m_SortSettingsChanged = true;
    m_FilterSettingsChanged = true;
    m_GroupSettingsChanged = true;
  else
    print_debug("Trade Route table last built on: " .. m_LastTurnBuiltTradeRouteTable .. ". Current game turn: " .. Game.GetCurrentGameTurn());
    print_debug("OPT: Not Rebuilding or recaching routes table")
  end

  -- Filter the routes here. This allows for max improvement in speed if a filter is selected
  if m_FilterSettingsChanged then
    time1 = Automation.GetTime()
    m_FinalTradeRoutes = FilterTradeRoutes(m_AvailableTradeRoutes);
    time2 = Automation.GetTime()
    print_debug(string.format("Time taken to filter: %.4f sec(s)", time2-time1))

    -- Need to regroup routes (some groups could dissapear because of filter)
    m_GroupSettingsChanged = true
  else
    print_debug("OPT: Not refiltering routes")
  end

  -- Sort and display the routes
  if not GroupSettingIsNone(m_groupBySelected) then
    -- Group routes. Use the filtered list of routes
    if m_GroupSettingsChanged then
      time1 = Automation.GetTime()
      m_AvailableGroupedRoutes = GroupRoutes(m_FinalTradeRoutes, m_groupByList[m_groupBySelected].groupByID)
      time2 = Automation.GetTime()
      print_debug(string.format("Time taken to group: %.4f sec(s)", time2-time1))

      -- Need to resort to show correct order
      m_SortSettingsChanged = true
    else
      print_debug("OPT: Not regrouping routes")
    end

    -- Sort within each group, and then sort groups
    if m_SortSettingsChanged then
      -- Sort within each group
      time1 = Automation.GetTime()
      for i=1, #m_AvailableGroupedRoutes do
        m_AvailableGroupedRoutes[i] = SortTradeRoutes(m_AvailableGroupedRoutes[i], m_InGroupSortBySettings)
      end
      time2 = Automation.GetTime()
      print_debug(string.format("Time taken to within group sort: %.4f sec(s)", time2-time1))

      -- Sort the order of groups. You need to do this AFTER each group has been sorted
      time1 = Automation.GetTime()
      m_AvailableGroupedRoutes = SortGroupedRoutes(m_AvailableGroupedRoutes, m_GroupSortBySettings);
      time2 = Automation.GetTime()
      print_debug(string.format("Time taken to group sort: %.4f sec(s)", time2-time1))
    else
      print_debug("OPT: Not resorting within and of groups")
    end

    -- Show the groups
    for i=1, #m_AvailableGroupedRoutes do
      if m_groupByList[m_groupBySelected].groupByID == GROUP_BY_SETTINGS.ORIGIN then
        local originPlayer:table = Players[m_AvailableGroupedRoutes[i][1].OriginCityPlayer];
        local originCity:table = originPlayer:GetCities():FindID(m_AvailableGroupedRoutes[i][1].OriginCityID);

        DisplayGroup(m_AvailableGroupedRoutes[i], originCity);
      elseif m_groupByList[m_groupBySelected].groupByID == GROUP_BY_SETTINGS.DESTINATION then
        local destinationPlayer:table = Players[m_AvailableGroupedRoutes[i][1].DestinationCityPlayer];
        local destinationCity:table = destinationPlayer:GetCities():FindID(m_AvailableGroupedRoutes[i][1].DestinationCityID);

        DisplayGroup(m_AvailableGroupedRoutes[i], destinationCity);
      end
    end
  else
    if m_FinalTradeRoutes ~= nil then
      if m_SortSettingsChanged or m_GroupSettingsChanged then
        time1 = Automation.GetTime()
        m_FinalTradeRoutes = SortTradeRoutes(m_FinalTradeRoutes, m_GroupSortBySettings);
        time2 = Automation.GetTime()
        print_debug(string.format("Time taken to sort: %.4f sec(s)", time2-time1))
      else
        print_debug("OPT: Not resorting routes")
      end
      AddRouteInstancesFromTable(m_FinalTradeRoutes);
    end
  end

  -- Everything is done if it reaches here
  m_SortSettingsChanged = false;
  m_FilterSettingsChanged = false;
  m_GroupSettingsChanged = false;
end

function DisplayGroup(routesTable:table, city:table)
  -- dump(routesTable[1])

  local routeCount:number = #routesTable;
  if routeCount > 0 then
    -- Find if the city is in exclusion list
    local cityEntry:table = {
      OwnerID = city:GetOwner(),
      CityID = city:GetID()
    };

    local groupExpandIndex = findIndex(m_GroupsFullyExpanded, cityEntry, CompareCityEntries);
    local groupCollapseIndex = findIndex(m_GroupsFullyCollapsed, cityEntry, CompareCityEntries);

    -- print(L_Lookup(city:GetName()) .. ": " .. groupExpandIndex .. " " .. groupCollapseIndex )
    if (groupExpandIndex > 0) then
      CreateCityHeader(city, routeCount, routeCount, "");
      AddRouteInstancesFromTable(routesTable);
    elseif (groupCollapseIndex > 0) then
      CreateCityHeader(city, 0, routeCount, GetCityHeaderTooltipString(routesTable[1]));
      AddRouteInstancesFromTable(routesTable, 0);
    else
      if m_GroupExpandAll then
        -- If showing all, add city to expand list, and display all
        tinsert(m_GroupsFullyExpanded, cityEntry);
        CreateCityHeader(city, routeCount, routeCount, "");
        AddRouteInstancesFromTable(routesTable);
      elseif m_GroupCollapseAll then
        -- If hiding all, add city to collapse list, and hide it
        tinsert(m_GroupsFullyCollapsed, cityEntry);
        CreateCityHeader(city, 0, routeCount, GetCityHeaderTooltipString(routesTable[1]));
        AddRouteInstancesFromTable(routesTable, 0);
      else
        CreateCityHeader(city, math.min(SEMI_EXPAND_SETTINGS[m_groupBySelected], routeCount), routeCount, "");
        AddRouteInstancesFromTable(routesTable, SEMI_EXPAND_SETTINGS[m_groupBySelected]);
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Tab UI Helpers
-- ---------------------------------------------------------------------------
function SetMyRoutesTabSelected( isSelected:boolean )
  Controls.MyRoutesButton:SetSelected(isSelected);
  Controls.MyRoutesTabLabel:SetHide(isSelected);
  Controls.MyRoutesSelected:SetHide(not isSelected);
  Controls.MyRoutesSelectedArrow:SetHide(not isSelected);
  Controls.MyRoutesTabSelectedLabel:SetHide(not isSelected);
end

function SetRoutesToCitiesTabSelected( isSelected:boolean )
  Controls.RoutesToCitiesButton:SetSelected(isSelected);
  Controls.RoutesToCitiesTabLabel:SetHide(isSelected);
  Controls.RoutesToCitiesSelected:SetHide(not isSelected);
  Controls.RoutesToCitiesSelectedArrow:SetHide(not isSelected);
  Controls.RoutesToCitiesTabSelectedLabel:SetHide(not isSelected);
end

function SetAvailableRoutesTabSelected( isSelected:boolean )
  Controls.AvailableRoutesButton:SetSelected(isSelected);
  Controls.AvailableRoutesTabLabel:SetHide(isSelected);
  Controls.AvailableRoutesSelected:SetHide(not isSelected);
  Controls.AvailableRoutesSelectedArrow:SetHide(not isSelected);
  Controls.AvailableRoutesTabSelectedLabel:SetHide(not isSelected);
end

function GetCityHeaderTooltipString( routeInfo:table )
  return "Top Route: " .. GetTradeRouteString(routeInfo) .. "[NEWLINE]" .. L_Lookup("LOC_TRADE_TURNS_REMAINING_TOOLTIP_BREAKER")
         .. "[NEWLINE]" .. GetTradeRouteYieldString(routeInfo);
end

-- ===========================================================================
--  Route Instance Creators
-- ===========================================================================

function AddChooseRouteButtonInstance( tradeUnit:table )
  local simpleButtonInstance:table = m_SimpleButtonInstanceIM:GetInstance();
  simpleButtonInstance.GridButton:SetText(L_Lookup("LOC_TRADE_OVERVIEW_CHOOSE_ROUTE"));
  simpleButtonInstance.GridButton:SetDisabled(false);
  simpleButtonInstance.GridButton:RegisterCallback( M_LCick,
    function()
      SelectUnit( tradeUnit );
    end
  );
end

function AddProduceTradeUnitButtonInstance()
  local simpleButtonInstance:table = m_SimpleButtonInstanceIM:GetInstance();
  simpleButtonInstance.GridButton:SetText(L_Lookup("LOC_TRADE_OVERVIEW_PRODUCE_TRADE_UNIT"));
  simpleButtonInstance.GridButton:SetDisabled(true);
end

function AddRouteInstancesFromTable( tradeRoutes:table, showCount:number )
  if showCount then
    local len = math.min(showCount, #tradeRoutes)
    for i=1, len do
      AddRouteInstanceFromRouteInfo(tradeRoutes[i]);
    end
  else
    local tTime = Automation.GetTime();
    for i=1, #tradeRoutes do
      if (tTime + 1 < Automation.GetTime()) then
        print_debug("+1 sec ... " .. i)
        tTime = Automation.GetTime()
      end
      AddRouteInstanceFromRouteInfo(tradeRoutes[i]);
    end
  end
end

function AddRouteInstanceFromRouteInfo( routeInfo:table )
  -- Get all the info, to build the route
  local originPlayer:table = Players[routeInfo.OriginCityPlayer];
  local originCity:table = originPlayer:GetCities():FindID(routeInfo.OriginCityID);
  local destinationPlayer:table = Players[routeInfo.DestinationCityPlayer];
  local destinationCity:table = destinationPlayer:GetCities():FindID(routeInfo.DestinationCityID);

  local routeInstance:table = m_RouteInstanceIM:GetInstance();

  local destinationBackColor, destinationFrontColor, darkerBackColor, brighterBackColor = GetPlayerColorInfo(routeInfo.DestinationCityPlayer, true);
  local originBackColor, originFrontColor = GetPlayerColorInfo(routeInfo.OriginCityPlayer, true);
  local tintBackColor = DarkenLightenColor(destinationBackColor, tintColorOffset, tintColorOpacity);

  -- Update colors
  if tintRouteEntry then
    routeInstance.GridButton:SetColor(tintBackColor);
  end

  routeInstance.TurnsToComplete:SetColor(destinationFrontColor);
  routeInstance.BannerBase:SetColor(destinationBackColor);
  routeInstance.BannerDarker:SetColor(darkerBackColor);
  routeInstance.BannerLighter:SetColor(brighterBackColor);
  routeInstance.RouteLabel:SetColor(destinationFrontColor);

  -- Update Route Label
  routeInstance.RouteLabel:SetText(L_Upper(originCity:GetName()) .. " " .. L_Upper("LOC_TRADE_OVERVIEW_TO") .. " " .. L_Upper(destinationCity:GetName()));

  -- Update yield directional arrows
  routeInstance.OriginCivArrow:SetColor(originFrontColor);
  routeInstance.DestinationCivArrow:SetColor(destinationFrontColor);


  SetOriginRouteInstanceYields(routeInstance, routeInfo)
  if GetNetYieldForDestinationCity(routeInfo, true) > 0 then
    print_debug(GetTradeRouteString(routeInfo), "has destination has yield")
    routeInstance.DestinationYields:SetHide(false);
    SetDestinationRouteInstanceYields(routeInstance, routeInfo)
  else
    routeInstance.DestinationYields:SetHide(true);
  end

  -- Update City State Quest Icon
  routeInstance.CityStateQuestIcon:SetHide(true);
  local questTooltip  : string = L_Lookup("LOC_CITY_STATES_QUESTS");
  local tradeRouteQuestInfo:table = GameInfo.Quests["QUEST_SEND_TRADE_ROUTE"];
  local questsManager:table = Game.GetQuestsManager();

  if IsCityStateWithTradeQuest(destinationPlayer) then
    questTooltip = questTooltip .. "[NEWLINE]" .. tradeRouteQuestInfo.IconString .. questsManager:GetActiveQuestName(routeInfo.OriginCityPlayer, routeInfo.DestinationCityPlayer, tradeRouteQuestInfo.Index);
    routeInstance.CityStateQuestIcon:SetHide(false);
    routeInstance.CityStateQuestIcon:SetToolTipString(questTooltip);
  end

  -- Update Diplomatic Visibility
  routeInstance.VisibilityBonusGrid:SetHide(false);
  routeInstance.TourismBonusGrid:SetHide(false);

  -- TODO - Can we make this simpler?
  -- Do we display the tourism or visibilty bonus? Hide them if we are showing them somewhere else, or it is a city state, or it is domestic route
  if IsCityState(destinationPlayer) or routeInfo.OriginCityPlayer == routeInfo.DestinationCityPlayer
    or m_groupByList[m_groupBySelected].groupByID == GROUP_BY_SETTINGS.DESTINATION or m_currentTab ~= TRADE_TABS.AVAILABLE_ROUTES then

    routeInstance.VisibilityBonusGrid:SetHide(true);
    routeInstance.TourismBonusGrid:SetHide(true);

    -- Also hide the trading post if grouping by destination (will be shown in the header)
    if m_groupByList[m_groupBySelected].groupByID == GROUP_BY_SETTINGS.DESTINATION then
      routeInstance.TradingPostIndicator:SetHide(true);
    elseif not hideTradingPostIcon then
      routeInstance.TradingPostIndicator:SetHide(false);
    end
  else
    -- Determine are diplomatic visibility status
    local visibilityIndex:number = GetVisibilityIndex(routeInfo.DestinationCityPlayer, true)

    -- Determine this player has a trade route with the local player
    local hasTradeRoute:boolean = GetHasActiveRoute(routeInfo.DestinationCityPlayer, true)

    -- Display trade route tourism modifier
    local extraTourismModifier = originPlayer:GetCulture():GetExtraTradeRouteTourismModifier();

    -- TODO: Use LOC_TRADE_OVERVIEW_TOURISM_BONUS when we can update the text
    routeInstance.TourismBonusPercentage:SetText("+" .. Locale.ToPercent((BASE_TOURISM_MODIFIER + extraTourismModifier)/100));

    if hasTradeRoute then
      routeInstance.TourismBonusPercentage:SetColorByName("TradeOverviewTextCS");
      routeInstance.TourismBonusIcon:SetTexture(0,0,"Tourism_VisitingSmall");
      routeInstance.TourismBonusGrid:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_TOURISM_BONUS");

      routeInstance.VisibilityBonusIcon:SetTexture("Diplomacy_VisibilityIcons");
      routeInstance.VisibilityBonusIcon:SetVisState(Clamp(visibilityIndex - 1, 0, 3));
      routeInstance.VisibilityBonusGrid:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_DIPLOMATIC_VIS_BONUS");
    else
      routeInstance.TourismBonusPercentage:SetColorByName("TradeOverviewTextDisabledCS");
      routeInstance.TourismBonusIcon:SetTexture(0,0,"Tourism_VisitingSmallGrey");
      routeInstance.TourismBonusGrid:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_NO_TOURISM_BONUS");

      routeInstance.VisibilityBonusIcon:SetTexture("Diplomacy_VisibilityIconsGrey");
      routeInstance.VisibilityBonusIcon:SetVisState(Clamp(visibilityIndex, 0, 3));
      routeInstance.VisibilityBonusGrid:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_NO_DIPLOMATIC_VIS_BONUS");
    end
  end

  -- Update Trading Post Icon
  if GroupSettingIsNone(m_groupBySelected) or m_groupBySelected == GROUP_BY_SETTINGS.ORIGIN then
    routeInstance.TradingPostIndicator:SetHide(false);
  else
    routeInstance.TradingPostIndicator:SetHide(true);
  end

  if GetRouteHasTradingPost(routeInfo, true) then
    routeInstance.TradingPostIndicator:SetAlpha(1.0);
    routeInstance.TradingPostIndicator:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_TRADE_POST_ESTABLISHED");
  else
    routeInstance.TradingPostIndicator:SetAlpha(0.2);
    routeInstance.TradingPostIndicator:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_NO_TRADE_POST");
  end

  -- Update turns to complete route
  local tooltipString:string;
  local tradePathLength, tripsToDestination, turnsToCompleteRoute = GetRouteInfo(routeInfo, true);
  if routeInfo.TurnsRemaining ~= nil then
    routeInstance.TurnsToComplete:SetText(routeInfo.TurnsRemaining);
    tooltipString = (   L_Lookup("LOC_TRADE_TURNS_REMAINING_ALT_HELP_TOOLTIP", routeInfo.TurnsRemaining) .. "[NEWLINE]" ..
              L_Lookup("LOC_TRADE_TURNS_REMAINING_TOOLTIP_BREAKER") .. "[NEWLINE]" ..
              L_Lookup("LOC_TRADE_TURNS_REMAINING_ROUTE_LENGTH_TOOLTIP", tradePathLength) .. "[NEWLINE]" ..
              L_Lookup("LOC_TRADE_TURNS_REMAINING_TRIPS_COUNT_TOOLTIP", tripsToDestination) .. "[NEWLINE]" ..
              L_Lookup("LOC_TRADE_TURNS_REMAINING_TURN_COMPLETION_TOOLTIP", (Game.GetCurrentGameTurn() + routeInfo.TurnsRemaining)) );

  elseif m_currentTab == TRADE_TABS.ROUTES_TO_CITIES then
    routeInstance.TurnsToComplete:SetText(turnsToCompleteRoute);
    tooltipString = (   L_Lookup("LOC_TRADE_TURNS_REMAINING_HELP_TOOLTIP") .. "[NEWLINE]" ..
              L_Lookup("LOC_TRADE_TURNS_REMAINING_TOOLTIP_BREAKER") .. "[NEWLINE]" ..
              L_Lookup("LOC_TRADE_TURNS_REMAINING_ROUTE_LENGTH_TOOLTIP", tradePathLength) .. "[NEWLINE]" ..
              L_Lookup("LOC_TRADE_TURNS_REMAINING_TRIPS_COUNT_TOOLTIP", tripsToDestination) );
  else
    routeInstance.TurnsToComplete:SetText(turnsToCompleteRoute);
    tooltipString = (   L_Lookup("LOC_TRADE_TURNS_REMAINING_HELP_TOOLTIP") .. "[NEWLINE]" ..
              L_Lookup("LOC_TRADE_TURNS_REMAINING_TOOLTIP_BREAKER") .. "[NEWLINE]" ..
              L_Lookup("LOC_TRADE_TURNS_REMAINING_ROUTE_LENGTH_TOOLTIP", tradePathLength) .. "[NEWLINE]" ..
              L_Lookup("LOC_TRADE_TURNS_REMAINING_TRIPS_COUNT_TOOLTIP", tripsToDestination) .. "[NEWLINE]" ..
              L_Lookup("LOC_TRADE_TURNS_REMAINING_TURN_COMPLETION_ALT_TOOLTIP", turnsToCompleteRoute, (Game.GetCurrentGameTurn() + turnsToCompleteRoute)) );
  end

  routeInstance.TurnsToComplete:SetToolTipString( tooltipString );

  local originTextureOffsetX, originTextureOffsetY, originTextureSheet, originTooltip = GetPlayerIconInfo(routeInfo.OriginCityPlayer, true)
  local destinationTextureOffsetX, destinationTextureOffsetY, destinationTextureSheet, destinationTooltip = GetPlayerIconInfo(routeInfo.DestinationCityPlayer, true)

  -- Origin Civ Icon
  routeInstance.OriginCivIcon:SetTexture(originTextureOffsetX, originTextureOffsetY, originTextureSheet);
  routeInstance.OriginCivIcon:LocalizeAndSetToolTip(originTooltip);
  routeInstance.OriginCivIcon:SetColor(originFrontColor);
  routeInstance.OriginCivIconBacking:SetColor(originBackColor);

  -- Destination Civ Icon
  routeInstance.DestinationCivIcon:SetTexture(destinationTextureOffsetX, destinationTextureOffsetY, destinationTextureSheet);
  routeInstance.DestinationCivIcon:SetColor(destinationFrontColor);
  routeInstance.DestinationCivIconBacking:SetColor(destinationBackColor);
  routeInstance.DestinationCivIcon:LocalizeAndSetToolTip(destinationTooltip);

  -- Hide the cancel automation button by default
  routeInstance.CancelAutomation:SetHide(true);

  -- Should we display the cancel automation?
  if m_currentTab == TRADE_TABS.MY_ROUTES and routeInfo.TraderUnitID ~= nil then
    if IsTraderAutomated(routeInfo.TraderUnitID) then
      -- Unhide the cancel automation
      routeInstance.CancelAutomation:SetHide(false);
      -- Add button callback
      routeInstance.CancelAutomation:RegisterCallback( M_LCick,
        function()
          CancelAutomatedTrader(routeInfo.TraderUnitID);
          Refresh();
        end
      );
    end
  end

  if routeInfo.TraderUnitID then
    local tradeUnit:table = originPlayer:GetUnits():FindID(routeInfo.TraderUnitID);
    routeInstance.GridButton:RegisterCallback( M_LCick,
      function()
        SelectUnit(tradeUnit);
      end
    );
  -- Add button hookups for only this tab
  elseif m_currentTab == TRADE_TABS.AVAILABLE_ROUTES and m_AvailableTraders ~= nil and tcount(m_AvailableTraders) > 0 then
    -- Check if we have free trader in that city
    if m_AvailableTraders[routeInfo.OriginCityID] ~= nil and tcount(m_AvailableTraders[routeInfo.OriginCityID]) > 0 then
      -- Get first trader
      local traderID = m_AvailableTraders[routeInfo.OriginCityID][1]
      local tradeUnit:table = originPlayer:GetUnits():FindID(traderID);
      routeInstance.GridButton:RegisterCallback( M_LCick,
        function()
          SelectFreeTrader(tradeUnit, routeInfo.DestinationCityPlayer, routeInfo.DestinationCityID);
        end
      );
    else -- Cycle through all free traders and open transfer-to screen for them
      local co = coroutine.create(
        function()
          while true do -- Infinitely cycle
            -- Do we have traders to cycle between?
            if CountTraders(m_AvailableTraders) > 0 then
              for cityID in pairs(m_AvailableTraders) do
                for i in pairs(m_AvailableTraders[cityID]) do
                  local traderID = m_AvailableTraders[cityID][i]
                  local tradeUnit:table = originPlayer:GetUnits():FindID(traderID);
                  print_debug("Calling transfer from " .. cityID)
                  TransferTraderTo(tradeUnit, originCity)
                  coroutine.yield()
                end
              end
            else
              print_debug("Backup 2 yield")
              coroutine.yield() -- gauranteed yield to prevent infinite cycle bug
            end
          end
        end
      );

      routeInstance.GridButton:RegisterCallback( M_LCick,
        function()
          CycleTraders(co)
        end
      );
    end
  end
end

-- ---------------------------------------------------------------------------
-- Route button helpers
-- ---------------------------------------------------------------------------

function SetOriginRouteInstanceYields(routeInstance, routeInfo)
  local yieldTexts = {}
  for yieldIndex = START_INDEX, END_INDEX do
    local yieldAmount = GetYieldForOriginCity(yieldIndex, routeInfo, true)
    local iconString, text = FormatYieldText(yieldIndex, yieldAmount)
    yieldTexts[yieldIndex] = text .. iconString
  end
  routeInstance.OriginYieldFoodLabel:SetText(yieldTexts[FOOD_INDEX])
  routeInstance.OriginYieldProductionLabel:SetText(yieldTexts[PRODUCTION_INDEX])
  routeInstance.OriginYieldGoldLabel:SetText(yieldTexts[GOLD_INDEX])
  routeInstance.OriginYieldScienceLabel:SetText(yieldTexts[SCIENCE_INDEX])
  routeInstance.OriginYieldCultureLabel:SetText(yieldTexts[CULTURE_INDEX])
  routeInstance.OriginYieldFaithLabel:SetText(yieldTexts[FAITH_INDEX])
end

function SetDestinationRouteInstanceYields(routeInstance, routeInfo)
  local yieldTexts = {}
  for yieldIndex = START_INDEX, END_INDEX do
    local yieldAmount = GetYieldForDestinationCity(yieldIndex, routeInfo, true)
    local iconString, text = FormatYieldText(yieldIndex, yieldAmount)
    yieldTexts[yieldIndex] = text .. iconString
  end
  routeInstance.DestinationYieldFoodLabel:SetText(yieldTexts[FOOD_INDEX])
  routeInstance.DestinationYieldProductionLabel:SetText(yieldTexts[PRODUCTION_INDEX])
  routeInstance.DestinationYieldGoldLabel:SetText(yieldTexts[GOLD_INDEX])
  routeInstance.DestinationYieldScienceLabel:SetText(yieldTexts[SCIENCE_INDEX])
  routeInstance.DestinationYieldCultureLabel:SetText(yieldTexts[CULTURE_INDEX])
  routeInstance.DestinationYieldFaithLabel:SetText(yieldTexts[FAITH_INDEX])
end

-- ===========================================================================
--  Header Instance Creators
-- ===========================================================================

function CreateSectionDivider()
  if not addDividerBetweenGroups then
    return
  end

  if m_dividerCount > 0 then
    local dividerInstance:table = m_DividerInstanceIM:GetInstance();
  end
  m_dividerCount = m_dividerCount + 1
end

function CreatePlayerHeader( player:table )
  CreateSectionDivider()

  local headerInstance:table = m_HeaderInstanceIM:GetInstance();
  local playerID = player:GetID()
  local pPlayerConfig:table = PlayerConfigurations[playerID];
  headerInstance.HeaderLabel:SetText(L_Upper(pPlayerConfig:GetPlayerName()));

  -- If the current tab is not available routes, hide the collapse button, and trading post
  if m_currentTab ~= TRADE_TABS.AVAILABLE_ROUTES then
    headerInstance.RoutesExpand:SetHide(true);
    headerInstance.RouteCountLabel:SetHide(true);
    headerInstance.TradingPostIndicator:SetHide(true);
  end

  if colorCityPlayerHeader then
    headerInstance.CityBannerFill:SetHide(false);
    local backColor, frontColor = GetPlayerColorInfo(playerID, true);
    headerBackColor = DarkenLightenColor(backColor, backdropColorOffset, backdropColorOpacity);
    headerFrontColor = DarkenLightenColor(frontColor, labelColorOffset, labelColorOpacity);
    gridBackColor = DarkenLightenColor(backColor, backdropGridColorOffset, backdropGridColorOpacity);

    headerInstance.CityBannerFill:SetColor( headerBackColor );

    headerInstance.HeaderLabel:SetColor(headerFrontColor);
    headerInstance.HeaderGrid:SetColor(gridBackColor);
  else
    -- Hide the colored UI elements
    headerInstance.CityBannerFill:SetHide(true);
  end

  -- If not local player or a city state
  if (playerID ~=  Game.GetLocalPlayer() and (not IsCityState(player))) then
    -- Determine are diplomatic visibility status
    headerInstance.TourismBonusGrid:SetHide(false);
    headerInstance.VisibilityBonusGrid:SetHide(false)
    local visibilityIndex:number = GetVisibilityIndex(playerID, true)

    -- Determine this player has a trade route with the local player
    local hasTradeRoute:boolean = GetHasActiveRoute(playerID, true)

    -- Display trade route tourism modifier
    local extraTourismModifier = Players[Game.GetLocalPlayer()]:GetCulture():GetExtraTradeRouteTourismModifier();
    -- TODO: Use LOC_TRADE_OVERVIEW_TOURISM_BONUS when we can update the text
    headerInstance.TourismBonusPercentage:SetText("+" .. Locale.ToPercent((BASE_TOURISM_MODIFIER + extraTourismModifier)/100));

    if hasTradeRoute then
      headerInstance.TourismBonusPercentage:SetColorByName("TradeOverviewTextCS");
      headerInstance.TourismBonusIcon:SetTexture(0,0,"Tourism_VisitingSmall");
      headerInstance.TourismBonusGrid:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_TOURISM_BONUS");

      headerInstance.VisibilityBonusIcon:SetTexture("Diplomacy_VisibilityIcons");
      headerInstance.VisibilityBonusIcon:SetVisState(math.min(math.max(visibilityIndex - 1, 0), 3));
      headerInstance.VisibilityBonusGrid:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_DIPLOMATIC_VIS_BONUS");
    else
      headerInstance.TourismBonusPercentage:SetColorByName("TradeOverviewTextDisabledCS");
      headerInstance.TourismBonusIcon:SetTexture(0,0,"Tourism_VisitingSmallGrey");
      headerInstance.TourismBonusGrid:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_NO_TOURISM_BONUS");

      headerInstance.VisibilityBonusIcon:SetTexture("Diplomacy_VisibilityIconsGrey");
      headerInstance.VisibilityBonusIcon:SetVisState(math.min(math.max(visibilityIndex, 0), 3));
      headerInstance.VisibilityBonusGrid:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_NO_DIPLOMATIC_VIS_BONUS");
    end
  else
    -- print("Not displaying vis bonuses")
    headerInstance.TourismBonusGrid:SetHide(true);
    headerInstance.VisibilityBonusGrid:SetHide(true);
  end
end

function CreateCityStateHeader()
  CreateSectionDivider()

  local headerInstance:table = m_HeaderInstanceIM:GetInstance();

  -- If the current tab is not available routes, hide the collapse button, and trading post
  if m_currentTab ~= TRADE_TABS.AVAILABLE_ROUTES then
    headerInstance.RoutesExpand:SetHide(true);
    headerInstance.RouteCountLabel:SetHide(true);
    headerInstance.TradingPostIndicator:SetHide(true);
  end

  -- Reset Color for city states
  headerInstance.HeaderGrid:SetColor(0xFF666666);
  headerInstance.CityBannerFill:SetHide(true);

  headerInstance.HeaderLabel:SetColorByName("Beige");
  headerInstance.HeaderLabel:SetText(L_Upper("LOC_TRADE_OVERVIEW_CITY_STATES"));

  headerInstance.VisibilityBonusGrid:SetHide(true);
  headerInstance.TourismBonusGrid:SetHide(true);
end

function CreateUnusedRoutesHeader()
  CreateSectionDivider()

  local headerInstance:table = m_HeaderInstanceIM:GetInstance();

  headerInstance.HeaderLabel:SetText(L_Upper("LOC_TRADE_OVERVIEW_UNUSED_ROUTES"));

  -- Reset Color for city states
  headerInstance.HeaderGrid:SetColor(0xFF666666);
  headerInstance.CityBannerFill:SetHide(true);

  headerInstance.HeaderLabel:SetColorByName("Beige");

  headerInstance.RoutesExpand:SetHide(true);
  headerInstance.RouteCountLabel:SetHide(true);
  headerInstance.TradingPostIndicator:SetHide(true);
  headerInstance.VisibilityBonusGrid:SetHide(true);
  headerInstance.TourismBonusGrid:SetHide(true);
end

function CreateCityHeader( city:table , currentRouteShowCount:number, totalRoutes:number, tooltipString:string )
  CreateSectionDivider()

  local headerInstance:table = m_HeaderInstanceIM:GetInstance();
  local playerID:number = city:GetOwner();
  local pPlayer = Players[playerID];

  headerInstance.HeaderLabel:SetText(L_Upper(city:GetName()));

  if tooltipString ~= nil then
    headerInstance.HeaderGrid:SetToolTipString(tooltipString);
  end

  if m_currentTab == TRADE_TABS.AVAILABLE_ROUTES then
    headerInstance.RoutesExpand:SetHide(false);
    headerInstance.RouteCountLabel:SetHide(false);
    headerInstance.TradingPostIndicator:SetHide(false);
  end

  headerInstance.RouteCountLabel:SetText(currentRouteShowCount .. " / " .. totalRoutes);

  -- If grouping by destination, show and refresh bonuses
  if m_groupByList[m_groupBySelected].groupByID == GROUP_BY_SETTINGS.DESTINATION then
    -- Update Trading Post Icon
    headerInstance.TradingPostIndicator:SetHide(false);

    if city:GetTrade():HasActiveTradingPost(Players[Game.GetLocalPlayer()]) then
      headerInstance.TradingPostIndicator:SetAlpha(1.0);
      headerInstance.TradingPostIndicator:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_TRADE_POST_ESTABLISHED");
    else
      headerInstance.TradingPostIndicator:SetAlpha(0.2);
      headerInstance.TradingPostIndicator:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_NO_TRADE_POST");
    end

    -- Update Diplomatic Visibility
    headerInstance.VisibilityBonusGrid:SetHide(false);
    headerInstance.TourismBonusGrid:SetHide(false);

    -- Do we display the tourism or visibilty bonus? Hide them if it is a city state, or it is domestic route
    if IsCityState(pPlayer) or pPlayer:GetID() == Game.GetLocalPlayer() then
      headerInstance.VisibilityBonusGrid:SetHide(true);
      headerInstance.TourismBonusGrid:SetHide(true);
    else
      -- Determine are diplomatic visibility status
      local visibilityIndex:number = GetVisibilityIndex(playerID, true)

      -- Determine this player has a trade route with the local player
      local hasTradeRoute:boolean = GetHasActiveRoute(playerID, true)

      -- Display trade route tourism modifier
      local extraTourismModifier = Players[Game.GetLocalPlayer()]:GetCulture():GetExtraTradeRouteTourismModifier();

      -- TODO: Use LOC_TRADE_OVERVIEW_TOURISM_BONUS when we can update the text
      headerInstance.TourismBonusPercentage:SetText("+" .. Locale.ToPercent((BASE_TOURISM_MODIFIER + extraTourismModifier)/100));

      if hasTradeRoute then
        headerInstance.TourismBonusPercentage:SetColorByName("TradeOverviewTextCS");
        headerInstance.TourismBonusIcon:SetTexture(0,0,"Tourism_VisitingSmall");
        headerInstance.TourismBonusGrid:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_TOURISM_BONUS");

        headerInstance.VisibilityBonusIcon:SetTexture("Diplomacy_VisibilityIcons");
        headerInstance.VisibilityBonusIcon:SetVisState(math.min(math.max(visibilityIndex - 1, 0), 3));
        headerInstance.VisibilityBonusGrid:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_DIPLOMATIC_VIS_BONUS");
      else
        headerInstance.TourismBonusPercentage:SetColorByName("TradeOverviewTextDisabledCS");
        headerInstance.TourismBonusIcon:SetTexture(0,0,"Tourism_VisitingSmallGrey");
        headerInstance.TourismBonusGrid:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_NO_TOURISM_BONUS");

        headerInstance.VisibilityBonusIcon:SetTexture("Diplomacy_VisibilityIconsGrey");
        headerInstance.VisibilityBonusIcon:SetVisState(math.min(math.max(visibilityIndex, 0), 3));
        headerInstance.VisibilityBonusGrid:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_NO_DIPLOMATIC_VIS_BONUS");
      end
    end
  else
    headerInstance.TourismBonusGrid:SetHide(true);
    headerInstance.VisibilityBonusGrid:SetHide(true);
    headerInstance.TradingPostIndicator:SetHide(true);
  end

  local cityEntry:table = {
    OwnerID = playerID,
    CityID = city:GetID()
  };

  local cityExclusionIndex = findIndex(m_GroupsFullyExpanded, cityEntry, CompareCityEntries);

  if cityExclusionIndex == -1 then
    headerInstance.RoutesExpand:SetCheck(false);
    headerInstance.RoutesExpand:SetCheckTextureOffsetVal(0,0);
  else
    headerInstance.RoutesExpand:SetCheck(true);
    headerInstance.RoutesExpand:SetCheckTextureOffsetVal(0,22);
  end


  headerInstance.RoutesExpand:RegisterCallback( M_LCick, function() OnExpandRoutes(headerInstance.RoutesExpand, city:GetOwner(), city:GetID()); end );
  headerInstance.RoutesExpand:RegisterCallback( M_Enter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  headerInstance.RoutesExpand:RegisterCallback( M_RClick, function() OnCollapseRoutes(headerInstance.RoutesExpand, city:GetOwner(), city:GetID()); end );
  headerInstance.RoutesExpand:RegisterCallback( M_Enter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

  if colorCityPlayerHeader then
    headerInstance.CityBannerFill:SetHide(false);
    local backColor, frontColor = GetPlayerColorInfo(playerID, true);

    headerBackColor = DarkenLightenColor(backColor, backdropColorOffset, backdropColorOpacity);
    headerFrontColor = DarkenLightenColor(frontColor, labelColorOffset, labelColorOpacity);
    gridBackColor = DarkenLightenColor(backColor, backdropGridColorOffset, backdropGridColorOpacity);

    headerInstance.HeaderLabel:SetColor(headerFrontColor);
    headerInstance.CityBannerFill:SetColor(headerBackColor);
    headerInstance.HeaderGrid:SetColor(gridBackColor);
  else
    -- Hide the colored UI elements
    headerInstance.CityBannerFill:SetHide(true);
  end
end

function OnExpandRoutes( checkbox, cityOwnerID:number, cityID:number )
  if m_GroupCollapseAll then
    m_GroupCollapseAll = false;
    Controls.GroupCollapseAllCheckBox:SetCheck(false);
  end

  -- For some reason the Uncheck texture does not apply, so I had to hard code the offset in.
  -- TODO: Find a fix for this
  if (checkbox:IsChecked()) then
    checkbox:SetCheckTextureOffsetVal(0,22);

    local cityEntry = {
      OwnerID = cityOwnerID,
      CityID = cityID
    };

    -- Only add entry if it isn't already in the list
    if findIndex(m_GroupsFullyExpanded, cityEntry, CompareCityEntries) == -1 then
      print_debug("Adding " .. GetCityEntryString(cityEntry) .. " to the exclusion list");
      tinsert(m_GroupsFullyExpanded, cityEntry);
    else
      print_debug("City already exists in exclusion list");
    end
  else
    if m_GroupExpandAll then
      m_GroupExpandAll = false;
      Controls.GroupExpandAllCheckBox:SetCheck(false);
    end

    checkbox:SetCheckTextureOffsetVal(0,0);

    local cityEntry = {
      OwnerID = cityOwnerID,
      CityID = cityID
    };

    local cityIndex = findIndex(m_GroupsFullyExpanded, cityEntry, CompareCityEntries)

    if findIndex(m_GroupsFullyExpanded, cityEntry, CompareCityEntries) > 0 then
      print_debug("Removing " .. GetCityEntryString(cityEntry) .. " to the exclusion list");
      tremove(m_GroupsFullyExpanded, cityIndex);
    else
      print_debug("City does not exist in exclusion list");
    end
  end

  Refresh();
end

function OnCollapseRoutes( checkbox, cityOwnerID:number, cityID:number )
  if m_GroupExpandAll then
    m_GroupExpandAll = false;
    Controls.GroupExpandAllCheckBox:SetCheck(false);
  end

  checkbox:SetCheck(false);
  checkbox:SetCheckTextureOffsetVal(0,0);

  -- Check if city is in Groups expanded list
  local cityEntry = {
      OwnerID = cityOwnerID,
      CityID = cityID
    };

  local cityIndex = findIndex(m_GroupsFullyExpanded, cityEntry, CompareCityEntries)

  -- Remove from fully expanded
  if cityIndex > 0 then
    tremove(m_GroupsFullyExpanded, cityIndex);
  end

  -- Add city to Groups collapsed list, if it does not exist
  cityIndex = findIndex(m_GroupsFullyCollapsed, cityEntry, CompareCityEntries)
  if cityIndex == -1 then
    tinsert(m_GroupsFullyCollapsed, cityEntry);
  end

  Refresh();
end

function CompareCityEntries( cityEntry1:table, cityEntry2:table )
  if (cityEntry1.OwnerID == cityEntry2.OwnerID) then
    if (cityEntry1.CityID == cityEntry2.CityID) then
      return true;
    end
  end

  return false;
end

function GetCityEntryString( cityEntry:table )
  local pPlayer:table = Players[cityEntry.OwnerID];
  local pCity:table = pPlayer:GetCities():FindID(cityEntry.CityID);

  return L_Lookup(pCity:GetName());
end

-- ===========================================================================
--  Trade Route Tracker
-- ===========================================================================
-- ---------------------------------------------------------------------------
-- Trader Route history tracker
-- ---------------------------------------------------------------------------
function UpdateRouteHistoryForTrader(routeInfo:table, routesTable:table)
  if routeInfo.TraderUnitID ~= nil then
    print_debug("Updating trader " .. routeInfo.TraderUnitID .. " with route history: " .. GetTradeRouteString(routeInfo));
    routesTable[routeInfo.TraderUnitID] = routeInfo;
  else
    print_debug("Could not find the trader unit")
  end
end

-- ===========================================================================
--  Group By Pulldown functions
-- ===========================================================================

function RefreshGroupByPulldown()

  -- Clear current group by entries
  Controls.OverviewGroupByPulldown:ClearEntries();
  m_groupByList = {};

  -- Build entries
  AddGroupByEntry(L_Lookup("LOC_CITY_STATES_NONE"), GROUP_BY_SETTINGS.NONE);
  AddGroupByEntry(L_Lookup("LOC_TRADE_OVERVIEW_ORIGIN"), GROUP_BY_SETTINGS.ORIGIN);
  AddGroupByEntry(L_Lookup("LOC_TRADE_OVERVIEW_DESTINATION"), GROUP_BY_SETTINGS.DESTINATION);
  AddGroupByEntry(L_Lookup("LOC_TRADE_OVERVIEW_ORIGIN_AZ"), GROUP_BY_SETTINGS.ORIGIN_AZ);
  AddGroupByEntry(L_Lookup("LOC_TRADE_OVERVIEW_ORIGIN_ZA"), GROUP_BY_SETTINGS.ORIGIN_ZA);
  AddGroupByEntry(L_Lookup("LOC_TRADE_OVERVIEW_DESTINATION_AZ"), GROUP_BY_SETTINGS.DESTINATION_AZ);
  AddGroupByEntry(L_Lookup("LOC_TRADE_OVERVIEW_DESTINATION_ZA"), GROUP_BY_SETTINGS.DESTINATION_ZA);

  -- Calculate Internals
  Controls.OverviewGroupByPulldown:CalculateInternals();

  Controls.OverviewGroupByButton:SetText(m_groupByList[m_groupBySelected].groupByString);

  UpdateGroupByArrow();
end

function AddGroupByEntry( text:string, id:number )
  local entry:table = {
    groupByString = text,
    groupByID = id
  };

  m_groupByList[id] = entry;

  AddPulldownEntry(text, id);
end

function AddPulldownEntry( pulldownText:string, index:number )
  local groupByPulldownEntry:table = {};
  Controls.OverviewGroupByPulldown:BuildEntry( "OverviewGroupByEntry", groupByPulldownEntry );

  groupByPulldownEntry.Button:SetText(pulldownText);
  groupByPulldownEntry.Button:SetVoids(i, index);
end

function UpdateGroupByArrow()
  if Controls.OverviewGroupByPulldown:IsOpen() then
    Controls.OverviewGroupByPulldownOpenedArrow:SetHide(true);
    Controls.OverviewGroupByPulldownClosedArrow:SetHide(false);
  else
    Controls.OverviewGroupByPulldownOpenedArrow:SetHide(false);
    Controls.OverviewGroupByPulldownClosedArrow:SetHide(true);
  end
end

-- Helper method to check if the group setting selected is none
function GroupSettingIsNone(groupSetting)
  if groupSetting == GROUP_BY_SETTINGS.NONE
      or groupSetting == GROUP_BY_SETTINGS.ORIGIN_AZ
      or groupSetting == GROUP_BY_SETTINGS.ORIGIN_ZA
      or groupSetting == GROUP_BY_SETTINGS.DESTINATION_AZ
      or groupSetting == GROUP_BY_SETTINGS.DESTINATION_ZA then
    return true
  end
  return false
end

-- ===========================================================================
--  Filter, Filter Pulldown functions
-- ===========================================================================

function FilterTradeRoutes ( tradeRoutes:table )
  -- print("Current filter: " .. m_filterList[m_filterSelected].FilterText);
  if m_filterSelected == 1 then
    return tradeRoutes;
  end

  local filtertedRoutes:table = {};
  local hasEntry:boolean = false

  for _, tradeRoute in ipairs(tradeRoutes) do
    local pPlayer = Players[tradeRoute.DestinationCityPlayer];
    if m_filterList[m_filterSelected].FilterFunction and m_filterList[m_filterSelected].FilterFunction(pPlayer) then
      tinsert(filtertedRoutes, tradeRoute);
      hasEntry = true
    end
  end

  if hasEntry then
    return filtertedRoutes;
  else
    return nil
  end
end

-- ---------------------------------------------------------------------------
-- Filter pulldown functions
-- ---------------------------------------------------------------------------
function RefreshFilters()

  -- Clear current filters
  Controls.OverviewDestinationFilterPulldown:ClearEntries();
  m_filterList = {};
  m_filterCount = 0;

  -- Add "All" Filter
  AddFilter(L_Lookup("LOC_ROUTECHOOSER_FILTER_ALL"), function(a) return true; end);

  -- Add "International Routes" Filter
  AddFilter(L_Lookup("LOC_TRADE_FILTER_INTERNATIONAL_ROUTES_TEXT") , IsOtherCiv);

  -- Add "City States with Trade Quest" Filter
  AddFilter(L_Lookup("LOC_TRADE_FILTER_CS_WITH_QUEST_TOOLTIP"), IsCityStateWithTradeQuest);

  -- Add Local Player Filter
  local localPlayerConfig:table = PlayerConfigurations[Game.GetLocalPlayer()];
  local localPlayerName = L_Lookup(GameInfo.Civilizations[localPlayerConfig:GetCivilizationTypeID()].Name);
  AddFilter(localPlayerName, function(a) return a:GetID() == Game.GetLocalPlayer(); end);

  -- Add Filters by Civ
  local players:table = Game.GetPlayers();
  for _, pPlayer in ipairs(players) do
    if pPlayer and pPlayer:IsAlive() and pPlayer:IsMajor() then

      -- Has the local player met the civ?
      if pPlayer:GetDiplomacy():HasMet(Game.GetLocalPlayer()) then
        local playerConfig:table = PlayerConfigurations[pPlayer:GetID()];
        local name = L_Lookup(GameInfo.Civilizations[playerConfig:GetCivilizationTypeID()].Name);
        AddFilter(name, function(a) return a:GetID() == pPlayer:GetID() end);
      end
    end
  end

  -- Add "City States" Filter
  AddFilter(L_Lookup("LOC_HUD_REPORTS_CITY_STATE"), IsCityState);

  -- Add filters to pulldown
  for filter in pairs(m_filterList) do
    AddFilterEntry(filter);
  end

  -- Select first filter
  Controls.OverviewFilterButton:SetText(m_filterList[m_filterSelected].FilterText);

  -- Calculate Internals
  Controls.OverviewDestinationFilterPulldown:CalculateInternals();

  UpdateFilterArrow();
end

function AddFilter( filterName:string, filterFunction )
  -- Make sure we don't add duplicate filters
  for _, filter in ipairs(m_filterList) do
    if filter.FilterText == filterName then
      return;
    end
  end

  m_filterCount = m_filterCount + 1;
  m_filterList[m_filterCount] = {FilterText=filterName, FilterFunction=filterFunction};
end

function AddFilterEntry( filterIndex:number )
  local filterEntry:table = {};
  Controls.OverviewDestinationFilterPulldown:BuildEntry( "OverviewFilterEntry", filterEntry );
  filterEntry.Button:SetText(m_filterList[filterIndex].FilterText);
  filterEntry.Button:SetVoids(i, filterIndex);
end

function UpdateFilterArrow()
  if Controls.OverviewDestinationFilterPulldown:IsOpen() then
    Controls.OverviewFilterPulldownOpenedArrow:SetHide(true);
    Controls.OverviewFilterPulldownClosedArrow:SetHide(false);
  else
    Controls.OverviewFilterPulldownOpenedArrow:SetHide(false);
    Controls.OverviewFilterPulldownClosedArrow:SetHide(true);
  end
end

-- ===========================================================================
--  Grouped Routes Function
-- ===========================================================================
-- Returns the grouped routes version based on the passed group setting
function GroupRoutes( routesTable, groupSetting )
  print_debug("Group setting: " .. m_groupByList[m_groupBySelected].groupByString);

  if GroupSettingIsNone(groupSetting) then
    return routesTable
  end

  local returnRoutesTable:table = {}
  local groupCount:number = 1
  local groupKey:table = {}

  for i=1, #routesTable do
    -- Cant use contor key here since we DONT want a unique key for every route
    local key:string;
    if groupSetting == GROUP_BY_SETTINGS.ORIGIN then
      key = tostring(routesTable[i].OriginCityPlayer) .. "_" .. tostring(routesTable[i].OriginCityID)
    elseif groupSetting == GROUP_BY_SETTINGS.DESTINATION then
      key = tostring(routesTable[i].DestinationCityPlayer) .. "_" .. tostring(routesTable[i].DestinationCityID)
    else
      print("Error: Unknown group setting.")
      return routesTable;
    end

    local index = groupCount;
    if groupKey[key] == nil then
      groupKey[key] = groupCount
      groupCount = groupCount + 1;
    else
      index = groupKey[key]
    end

    if returnRoutesTable[index] == nil then
      returnRoutesTable[index] = {}
    end

    -- print("Inserting " .. GetTradeRouteString(route) .. " in " .. index)
    returnRoutesTable[index][#(returnRoutesTable[index]) + 1] = routesTable[i]
  end
  return returnRoutesTable;
end

-- Gets top route from each group and sorts them based on that
function SortGroupedRoutes( groupedRoutes:table, sortSettings:table, sortSettingsChanged:boolean )
  if (sortSettingsChanged ~= nil and (not sortSettingsChanged)) then
    print_debug("OPT: Not sorting groups")
    return groupedRoutes
  end

  -- Get scores for the top routes, sort them
  local routeScores = {}
  for index=1, #groupedRoutes do
    routeScores[index] = { id = index, score = ScoreRoute(groupedRoutes[index][1], sortSettings)}
  end
  table.sort(routeScores, function(a, b) return ScoreComp(a, b, sortSettings) end )

  -- Build new table based on these sorted scores
  local routes = {}
  for i, scoreInfo in ipairs(routeScores) do
    routes[i] = groupedRoutes[scoreInfo.id]
  end
  return routes

  -- if #sortSettings > 0 then
  --     table.sort(groupedRoutes, CompareGroups)
  -- end
end

-- ===========================================================================
--  Sort bar functions
-- ===========================================================================

-- Hides all the ascending/descending arrows
function ResetSortBar()
  Controls.FoodDescArrow:SetHide(true);
  Controls.ProductionDescArrow:SetHide(true);
  Controls.GoldDescArrow:SetHide(true);
  Controls.ScienceDescArrow:SetHide(true);
  Controls.CultureDescArrow:SetHide(true);
  Controls.FaithDescArrow:SetHide(true);
  Controls.TurnsToCompleteDescArrow:SetHide(true);

  Controls.FoodAscArrow:SetHide(true);
  Controls.ProductionAscArrow:SetHide(true);
  Controls.GoldAscArrow:SetHide(true);
  Controls.ScienceAscArrow:SetHide(true);
  Controls.CultureAscArrow:SetHide(true);
  Controls.FaithAscArrow:SetHide(true);
  Controls.TurnsToCompleteAscArrow:SetHide(true);
end

function RefreshSortBar()
  if m_ctrlDown then
    RefreshSortButtons( m_InGroupSortBySettings );
  else
    RefreshSortButtons( m_GroupSortBySettings );
  end

  HideSortOrderLabels();
  if showSortOrdersPermanently or m_shiftDown then
    ShowSortOrderLabels();
  end
end

function ShowSortOrderLabels()
  -- Refresh and show sort orders
  if m_ctrlDown then
    RefreshSortOrderLabels( m_InGroupSortBySettings );
  else
    RefreshSortOrderLabels( m_GroupSortBySettings );
  end
end

function HideSortOrderLabels()
  Controls.FoodSortOrder:SetHide(true);
  Controls.ProductionSortOrder:SetHide(true);
  Controls.GoldSortOrder:SetHide(true);
  Controls.ScienceSortOrder:SetHide(true);
  Controls.CultureSortOrder:SetHide(true);
  Controls.FaithSortOrder:SetHide(true);
  Controls.TurnsToCompleteSortOrder:SetHide(true);
end

-- Shows and hides arrows based on the passed sort order
function SetSortArrow( ascArrow:table, descArrow:table, sortOrder:number )
  if sortOrder == SORT_ASCENDING then
    descArrow:SetHide(true);
    ascArrow:SetHide(false);
  else
    descArrow:SetHide(false);
    ascArrow:SetHide(true);
  end
end

function RefreshSortButtons( sortSettings:table )
  -- Hide all arrows
  ResetSortBar();

  -- Set disabled color
  Controls.FoodSortButton:SetColorByName("ButtonDisabledCS");
  Controls.ProductionSortButton:SetColorByName("ButtonDisabledCS");
  Controls.GoldSortButton:SetColorByName("ButtonDisabledCS");
  Controls.ScienceSortButton:SetColorByName("ButtonDisabledCS");
  Controls.CultureSortButton:SetColorByName("ButtonDisabledCS");
  Controls.FaithSortButton:SetColorByName("ButtonDisabledCS");
  Controls.TurnsToCompleteSortButton:SetColorByName("ButtonDisabledCS");

  -- Go through settings and display arrows
  for _, sortEntry in ipairs(sortSettings) do
    if sortEntry.SortByID == SORT_BY_ID.FOOD then
      SetSortArrow(Controls.FoodAscArrow, Controls.FoodDescArrow, sortEntry.SortOrder)
      Controls.FoodSortButton:SetColorByName("ButtonCS");
    elseif sortEntry.SortByID == SORT_BY_ID.PRODUCTION then
      SetSortArrow(Controls.ProductionAscArrow, Controls.ProductionDescArrow, sortEntry.SortOrder)
      Controls.ProductionSortButton:SetColorByName("ButtonCS");
    elseif sortEntry.SortByID == SORT_BY_ID.GOLD then
      SetSortArrow(Controls.GoldAscArrow, Controls.GoldDescArrow, sortEntry.SortOrder)
      Controls.GoldSortButton:SetColorByName("ButtonCS");
    elseif sortEntry.SortByID == SORT_BY_ID.SCIENCE then
      SetSortArrow(Controls.ScienceAscArrow, Controls.ScienceDescArrow, sortEntry.SortOrder)
      Controls.ScienceSortButton:SetColorByName("ButtonCS");
    elseif sortEntry.SortByID == SORT_BY_ID.CULTURE then
      SetSortArrow(Controls.CultureAscArrow, Controls.CultureDescArrow, sortEntry.SortOrder)
      Controls.CultureSortButton:SetColorByName("ButtonCS");
    elseif sortEntry.SortByID == SORT_BY_ID.FAITH then
      SetSortArrow(Controls.FaithAscArrow, Controls.FaithDescArrow, sortEntry.SortOrder)
      Controls.FaithSortButton:SetColorByName("ButtonCS");
    elseif sortEntry.SortByID == SORT_BY_ID.TURNS_TO_COMPLETE then
      SetSortArrow(Controls.TurnsToCompleteAscArrow, Controls.TurnsToCompleteDescArrow, sortEntry.SortOrder)
      Controls.TurnsToCompleteSortButton:SetColorByName("ButtonCS");
    end
  end
end

function RefreshSortOrderLabels( sortSettings:table )
  for _, sortEntry in ipairs(sortSettings) do
    if sortEntry.SortByID == SORT_BY_ID.FOOD then
      Controls.FoodSortOrder:SetHide(false);
      Controls.FoodSortOrder:SetText(index);
      Controls.FoodSortOrder:SetColorByName("ResFoodLabelCS");
    elseif sortEntry.SortByID == SORT_BY_ID.PRODUCTION then
      Controls.ProductionSortOrder:SetHide(false);
      Controls.ProductionSortOrder:SetText(index);
      Controls.ProductionSortOrder:SetColorByName("ResProductionLabelCS");
    elseif sortEntry.SortByID == SORT_BY_ID.GOLD then
      Controls.GoldSortOrder:SetHide(false);
      Controls.GoldSortOrder:SetText(index);
      Controls.GoldSortOrder:SetColorByName("ResGoldLabelCS");
    elseif sortEntry.SortByID == SORT_BY_ID.SCIENCE then
      Controls.ScienceSortOrder:SetHide(false);
      Controls.ScienceSortOrder:SetText(index);
      Controls.ScienceSortOrder:SetColorByName("ResScienceLabelCS");
    elseif sortEntry.SortByID == SORT_BY_ID.CULTURE then
      Controls.CultureSortOrder:SetHide(false);
      Controls.CultureSortOrder:SetText(index);
      Controls.CultureSortOrder:SetColorByName("ResCultureLabelCS");
    elseif sortEntry.SortByID == SORT_BY_ID.FAITH then
      Controls.FaithSortOrder:SetHide(false);
      Controls.FaithSortOrder:SetText(index);
      Controls.FaithSortOrder:SetColorByName("ResFaithLabelCS");
    elseif sortEntry.SortByID == SORT_BY_ID.TURNS_TO_COMPLETE then
      Controls.TurnsToCompleteSortOrder:SetHide(false);
      Controls.TurnsToCompleteSortOrder:SetText(index);
    end
  end
end

-- ===========================================================================
--  Applicaton level functions
-- ===========================================================================

function Open()
  -- dont show panel if there is no local player
  local localPlayerID = Game.GetLocalPlayer();
  if (localPlayerID == -1) then
    return
  end

  m_AnimSupport.Show();
  UI.PlaySound("CityStates_Panel_Open");
  Refresh();
end

function Close()
  if not ContextPtr:IsHidden() then
    UI.PlaySound("CityStates_Panel_Close");
  end

  m_AnimSupport.Hide();

  -- Reset sort settings
  m_InGroupSortBySettings = {};
  m_GroupSortBySettings = {};

  -- Reset tab
  m_currentTab = TRADE_TABS.MY_ROUTES;

  -- Reset filter
  m_filterSelected = 1;
end

-- ===========================================================================
--  General helper functions
-- ===========================================================================

function SelectUnit( unit:table )
  local localPlayer = Game.GetLocalPlayer();
  if UI.GetHeadSelectedUnit() ~= unit and localPlayer ~= -1 and localPlayer == unit:GetOwner() then
    UI.DeselectAllUnits();
    UI.DeselectAllCities();
    UI.SelectUnit( unit );
  end
  UI.LookAtPlotScreenPosition( unit:GetX(), unit:GetY(), 0.42, 0.5 );
end

function SelectFreeTrader( unit:table, destinationCityOwnerID:number, destinationCityID:number )
  local localPlayer = Game.GetLocalPlayer();
  if localPlayer == -1 or localPlayer ~= unit:GetOwner() then
    return
  end

  local selectedUnit:table = UI.GetHeadSelectedUnit();
  if selectedUnit == nil or selectedUnit:GetID() ~= unit:GetID() then
    UI.DeselectAllUnits();
    UI.DeselectAllCities();

    -- Don't open screen on unit selection
    LuaEvents.TradeRouteChooser_SkipOpen()
    UI.SelectUnit( unit );

    -- Open screen after new destination info is passed
    LuaEvents.TradeOverview_SelectRouteFromOverview(destinationCityOwnerID, destinationCityID)
  else
    LuaEvents.TradeOverview_SelectRouteFromOverview(destinationCityOwnerID, destinationCityID)
  end
end

function CycleTraders(co)
  if CountTraders(m_AvailableTraders) > 0 then
    coroutine.resume(co)
  else
    print_debug("No Trader available")
  end
end

function TransferTraderTo( unit:table, transferCity:table )
  -- Don't open screen on unit selection
  LuaEvents.TradeRouteChooser_SkipOpen()
  SelectUnit(unit)

  LuaEvents.TradeOverview_ChangeOriginCityFromOverview(transferCity)
end

-- Prevents nill entries being counted as "traders"
function CountTraders( traders )
  local count = 0
  if traders ~= nil then
    for cityID in pairs(traders) do
      if traders[cityID] ~= nil then
        for i in pairs(traders[cityID]) do
          if traders[cityID][i] ~= nil then
            count = count + 1
          end
        end
      end
    end
  end
  return count
end

function RemoveTrader( traderID )
  for cityID in pairs(m_AvailableTraders) do
    for i in pairs(m_AvailableTraders[cityID]) do
      -- Remove trader
      if m_AvailableTraders[cityID][i] == traderID then
        print_debug("Removing trader " .. traderID .. " from available traders.")
        tremove(m_AvailableTraders[cityID], i)

        -- Check if for that city has no traders. Remove the city entry if it does
        if table_nnill_count(m_AvailableTraders[cityID]) <= 0 then
          print_debug("Removing city " .. cityID)
          tremove(m_AvailableTraders, cityID)
        end

        return -- return here since nothing else is left to do
      end
    end
  end

  print("ERROR : Could not find trader " .. traderID)
end

-- ===========================================================================
--  Button handler functions
-- ===========================================================================

function OnOpen()
  Open();
end

function OnClose()
  Close();
end

-- ---------------------------------------------------------------------------
-- Tab buttons
-- ---------------------------------------------------------------------------
function OnMyRoutesButton()
  m_currentTab = TRADE_TABS.MY_ROUTES;
  Refresh();
end

function OnRoutesToCitiesButton()
  m_currentTab = TRADE_TABS.ROUTES_TO_CITIES;
  Refresh();
end

function OnAvailableRoutesButton()
  m_currentTab = TRADE_TABS.AVAILABLE_ROUTES;
  Refresh();
end

-- ---------------------------------------------------------------------------
-- Pulldowns
-- ---------------------------------------------------------------------------
function OnFilterSelected( index:number, filterIndex:number )
  m_filterSelected = filterIndex;
  Controls.OverviewFilterButton:SetText(m_filterList[m_filterSelected].FilterText);

  m_FilterSettingsChanged = true;
  Refresh();
end

function OnGroupBySelected( index:number, groupByIndex:number )
  -- Insert sort entry specific to the group setting
  if GROUP_BY_SETTINGS.ORIGIN_AZ == groupByIndex then
    m_GroupSortBySettings = {}
    InsertSortEntry(SORT_BY_ID.ORIGIN_NAME, SORT_ASCENDING, m_GroupSortBySettings)
  elseif GROUP_BY_SETTINGS.ORIGIN_ZA == groupByIndex then
    m_GroupSortBySettings = {}
    InsertSortEntry(SORT_BY_ID.ORIGIN_NAME, SORT_DESCENDING, m_GroupSortBySettings)
  elseif GROUP_BY_SETTINGS.DESTINATION_AZ == groupByIndex then
    m_GroupSortBySettings = {}
    InsertSortEntry(SORT_BY_ID.DESTINATION_NAME, SORT_ASCENDING, m_GroupSortBySettings)
  elseif GROUP_BY_SETTINGS.DESTINATION_ZA == groupByIndex then
    m_GroupSortBySettings = {}
    InsertSortEntry(SORT_BY_ID.DESTINATION_NAME, SORT_DESCENDING, m_GroupSortBySettings)
  end

  m_groupBySelected = groupByIndex;
  Controls.OverviewGroupByButton:SetText(m_groupByList[m_groupBySelected].groupByString);

  -- Have to rebuild table
  m_GroupSettingsChanged = true;
  Refresh();
end

-- ---------------------------------------------------------------------------
-- Checkbox
-- ---------------------------------------------------------------------------
function OnGroupExpandAll()
  m_GroupExpandAll = false;
  m_GroupCollapseAll = false;

  Controls.GroupCollapseAllCheckBox:SetCheck(false);

  -- Dont do anything, if grouping is none
  if GroupSettingIsNone(m_groupBySelected) then
    return;
  end

  if Controls.GroupExpandAllCheckBox:IsChecked() then
    m_GroupsFullyCollapsed = {};
    m_GroupExpandAll = true;
  end

  Refresh();
end

function OnGroupCollapseAll()
  m_GroupExpandAll = false;
  m_GroupCollapseAll = false;

  Controls.GroupExpandAllCheckBox:SetCheck(false);

  -- Dont do anything, if grouping is none
  if GroupSettingIsNone(m_groupBySelected) then
    return;
  end

  if Controls.GroupCollapseAllCheckBox:IsChecked() then
    m_GroupsFullyExpanded = {};
    m_GroupCollapseAll = true;
  end

  Refresh();
end

-- ---------------------------------------------------------------------------
-- Sort bar insert buttons
-- ---------------------------------------------------------------------------

-- General method to handle a sort button. Kind of a mess, especially with handling of different features with key presses. In short:
-- SHIFT    = Clear previous valuse
-- CTRL     = Add to m_InGroupSortBySettings
-- No CTRL  = Add to m_GroupSortBySettings and m_InGroupSortBySettings
-- By default the ascending sort by turns is always added (since these routes could be hidden in groups)
function OnGeneralSortBy(sortDescArrow, sortByID)
  m_SortSettingsChanged = true;
  -- If shift is not being pressed, reset sort settings
  if not m_shiftDown then
    if not m_ctrlDown then
      m_GroupSortBySettings = {};
    end
    m_InGroupSortBySettings = {};
  end

  -- Remove sort by turns ascending to be added later
  RemoveSortEntry(SORT_BY_ID.TURNS_TO_COMPLETE, m_InGroupSortBySettings);

  -- Sort based on currently showing icon toggled
  if sortDescArrow:IsHidden() then
    if not m_ctrlDown then
      InsertSortEntry(sortByID, SORT_DESCENDING, m_GroupSortBySettings);
    end
    InsertSortEntry(sortByID, SORT_DESCENDING, m_InGroupSortBySettings);
  else
    if not m_ctrlDown then
      InsertSortEntry(sortByID, SORT_ASCENDING, m_GroupSortBySettings);
    end
    InsertSortEntry(sortByID, SORT_ASCENDING, m_InGroupSortBySettings);
  end

  InsertSortEntry(SORT_BY_ID.TURNS_TO_COMPLETE, SORT_ASCENDING, m_InGroupSortBySettings);

  RefreshSortBar();
  -- OPT: Dont call refresh while shift is held
  if not m_shiftDown then
    Refresh();
  else
    m_sortCallRefresh = true;
  end
end

function OnSortByFood()
  OnGeneralSortBy(Controls.FoodDescArrow, SORT_BY_ID.FOOD)
end

function OnSortByProduction()
  OnGeneralSortBy(Controls.ProductionDescArrow, SORT_BY_ID.PRODUCTION)
end

function OnSortByGold()
  OnGeneralSortBy(Controls.GoldDescArrow, SORT_BY_ID.GOLD)
end

function OnSortByScience()
  OnGeneralSortBy(Controls.ScienceDescArrow, SORT_BY_ID.SCIENCE)
end

function OnSortByCulture()
  OnGeneralSortBy(Controls.CultureDescArrow, SORT_BY_ID.CULTURE)
end

function OnSortByFaith()
  OnGeneralSortBy(Controls.FaithDescArrow, SORT_BY_ID.FAITH)
end

function OnSortByTurnsToComplete()
  OnGeneralSortBy(Controls.TurnsToCompleteDescArrow, SORT_BY_ID.TURNS_TO_COMPLETE)
end

-- ---------------------------------------------------------------------------
-- Sort bar delete buttons
-- ---------------------------------------------------------------------------

-- General method to remove sort button.
-- CTRL     = Remove from m_InGroupSortBySettings
-- No CTRL  = Remove from m_GroupSortBySettings and m_InGroupSortBySettings
function OnGeneralNotSortBy(sortByID)
  m_SortSettingsChanged = true;
  if not m_ctrlDown then
    RemoveSortEntry( sortByID, m_GroupSortBySettings);
  end
  RemoveSortEntry( sortByID, m_InGroupSortBySettings);

  RefreshSortBar();
  -- OPT: Dont call refresh while shift is held
  if not m_shiftDown then
    Refresh();
  else
    m_sortCallRefresh = true;
  end
end

function OnNotSortByFood()
  OnGeneralNotSortBy(SORT_BY_ID.FOOD)
end

function OnNotSortByProduction()
  OnGeneralNotSortBy(SORT_BY_ID.PRODUCTION)
end

function OnNotSortByGold()
  OnGeneralNotSortBy(SORT_BY_ID.GOLD)
end

function OnNotSortByScience()
  OnGeneralNotSortBy(SORT_BY_ID.SCIENCE)
end

function OnNotSortByCulture()
  OnGeneralNotSortBy(SORT_BY_ID.CULTURE)
end

function OnNotSortByFaith()
  OnGeneralNotSortBy(SORT_BY_ID.FAITH)
end

function OnNotSortByTurnsToComplete()
  OnGeneralNotSortBy(SORT_BY_ID.TURNS_TO_COMPLETE)
end

-- ===========================================================================
--  LUA Event
--  Explicit close (from partial screen hooks), part of closing everything,
-- ===========================================================================

function OnCloseAllExcept( contextToStayOpen:string )
  if contextToStayOpen == ContextPtr:GetID() then return; end
  Close();
end

-- ===========================================================================
--  Game Event
-- ===========================================================================
--  City was selected so close route chooser
function OnCitySelectionChanged(owner, ID, i, j, k, bSelected, bEditable)
  if not ContextPtr:IsHidden() and owner == Game.GetLocalPlayer() then
    OnClose();
  end
end

function OnInterfaceModeChanged( eOldMode:number, eNewMode:number )
  if eNewMode == InterfaceModeTypes.VIEW_MODAL_LENS then
    Close();
  end
end

function OnLocalPlayerTurnEnd()
  if(GameConfiguration.IsHotseat()) then
    Close();
  end

  m_HasBuiltTradeRouteTable = false;

  -- Clear cache and tables to keep memory used low
  CacheEmpty();
  m_AvailableTradeRoutes = nil;
  m_FinalTradeRoutes = nil;
  m_AvailableGroupedRoutes = nil;
end

function OnUnitOperationStarted( ownerID:number, unitID:number, operationID:number )
  -- Don't do anything for non local players
  if ownerID ~= Game.GetLocalPlayer() then return end

  if m_HasBuiltTradeRouteTable then
    -- Remove unit from available traders
    RemoveTrader(unitID)
    local foundRoute:boolean = false

    if operationID == UnitOperationTypes.MAKE_TRADE_ROUTE then
      -- Unit was just started a trade route. Find the route, and update the tables
      local localPlayerCities:table = Players[ownerID]:GetCities();
      for _, city in localPlayerCities:Members() do
        local outgoingRoutes = city:GetTrade():GetOutgoingRoutes();
        for _, route in ipairs(outgoingRoutes) do
          if route.TraderUnitID == unitID then
            print_debug("Found route...")
            -- Remove it from the available routes
            RemoveRouteFromTable(route, m_AvailableGroupedRoutes, not GroupSettingIsNone(m_groupBySelected));
            foundRoute = true
            break
          end
        end
      end

      if not foundRoute then
        print("ERROR : Route not found!!")
        return
      end

      -- Dont refresh, if the window is hidden
      if not ContextPtr:IsHidden() then
        Refresh();
      end
    end
  end
end

-- ===========================================================================
--  UI EVENTS
-- ===========================================================================

function OnInit( isReload:boolean )
  if isReload then
    LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
  end
end

function OnShutdown()
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isHidden", ContextPtr:IsHidden());
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "currentTab", m_currentTab);
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "filterSelected", m_filterSelected);
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "groupBySelected", m_groupBySelected);
end

-- ---------------------------------------------------------------------------
-- Input handlers.
-- ---------------------------------------------------------------------------
function KeyDownHandler( key:number )
  if key == Keys.VK_SHIFT then
    m_shiftDown = true;
    if not showSortOrdersPermanently then
      ShowSortOrderLabels();
    end
    -- let it fall through
  end
  if key == Keys.VK_CONTROL then
    m_ctrlDown = true;
    RefreshSortBar();
  end
  return false;
end

function KeyUpHandler( key:number )
  if key == Keys.VK_SHIFT then
    m_shiftDown = false;

    if m_sortCallRefresh then
      Refresh();
      m_sortCallRefresh = false;
    end

    if not showSortOrdersPermanently then
      HideSortOrderLabels();
    end
    -- let it fall through
  end
  if key == Keys.VK_CONTROL then
    m_ctrlDown = false;
    RefreshSortBar();
  end
  if key == Keys.VK_ESCAPE then
    Close();
    return true;
  end
  if key == Keys.VK_RETURN then
    -- Don't let enter propigate or it will hit action panel which will raise a screen (potentially this one again) tied to the action.
    return true;
  end
  return false;
end

function OnInputHandler( pInputStruct:table )
  -- Call the animation input handler
  -- m_AnimSupport.OnInputHandler ( pInputStruct );

  local uiMsg = pInputStruct:GetMessageType();
  if uiMsg == KeyEvents.KeyDown then return KeyDownHandler( pInputStruct:GetKey() ); end
  if uiMsg == KeyEvents.KeyUp then return KeyUpHandler( pInputStruct:GetKey() ); end
  return false;
end

-- ===========================================================================
--  LUA EVENT
--  Reload support
-- ===========================================================================

function OnGameDebugReturn( context:string, contextTable:table )
  if context == RELOAD_CACHE_ID then
    if contextTable["isHidden"] ~= nil and not contextTable["isHidden"] then
      Open();
    end
    -- TODO: Add reload support for sort bar
    if contextTable["filterSelected"] ~= nil then
      m_filterSelected = contextTable["filterSelected"];
      Refresh();
    end
    if contextTable["currentTab"] ~= nil then
      m_currentTab = contextTable["currentTab"];
      Refresh();
    end
    if contextTable["groupBySelected"] ~= nil then
      m_groupBySelected = contextTable["groupBySelected"];

      -- Have to rebuild table
      m_HasBuiltTradeRouteTable = false;
      Refresh();
    end
  end
end

function OnPolicyChanged( ePlayer )
  if m_AnimSupport.IsVisible() and ePlayer == Game.GetLocalPlayer() then
    Refresh();
  end
end

-- ===========================================================================
--  Setup
-- ===========================================================================

function InitButton(control, callbackLClick, callbackRClick)
  control:RegisterCallback(M_LCick, callbackLClick)
  if callbackRClick ~= nil then
    control:RegisterCallback(M_RClick, callbackRClick)
  end
  control:RegisterCallback( M_Enter, function() UI.PlaySound("Main_Menu_Mouse_Over") end)
end

function Initialize()
  print("Initializing BTS Trade Overview");

  -- Initialize tracker
  TradeSupportTracker_Initialize();

  -- CQUI Handlers
  LuaEvents.CQUI_SettingsUpdate.Add( CQUI_OnSettingsUpdate );

  -- Input handler
  ContextPtr:SetInputHandler( OnInputHandler, true );

  -- Control Events
  InitButton(Controls.CloseButton, OnClose)
  InitButton(Controls.MyRoutesButton, OnMyRoutesButton)
  InitButton(Controls.RoutesToCitiesButton, OnRoutesToCitiesButton)
  InitButton(Controls.AvailableRoutesButton, OnAvailableRoutesButton)

  -- Control events - sort bar
  InitButton(Controls.FoodSortButton, OnSortByFood, OnNotSortByFood)
  InitButton(Controls.ProductionSortButton, OnSortByProduction, OnNotSortByProduction)
  InitButton(Controls.GoldSortButton, OnSortByGold, OnNotSortByGold)
  InitButton(Controls.ScienceSortButton, OnSortByScience, OnNotSortByScience)
  InitButton(Controls.CultureSortButton, OnSortByCulture, OnNotSortByCulture)
  InitButton(Controls.FaithSortButton, OnSortByFaith, OnNotSortByFaith)
  InitButton(Controls.TurnsToCompleteSortButton, OnSortByTurnsToComplete, OnNotSortByTurnsToComplete)

  --Filter Pulldown
  Controls.OverviewFilterButton:RegisterCallback( eLClick, UpdateFilterArrow );
  Controls.OverviewDestinationFilterPulldown:RegisterSelectionCallback( OnFilterSelected );

  -- Group By Pulldown
  Controls.OverviewGroupByButton:RegisterCallback( eLClick, UpdateGroupByArrow );
  Controls.OverviewGroupByPulldown:RegisterSelectionCallback( OnGroupBySelected );

  InitButton(Controls.GroupExpandAllCheckBox, OnGroupExpandAll)
  InitButton(Controls.GroupCollapseAllCheckBox, OnGroupCollapseAll)

  -- Lua Events
  LuaEvents.PartialScreenHooks_OpenTradeOverview.Add( OnOpen );
  LuaEvents.PartialScreenHooks_CloseTradeOverview.Add( OnClose );
  LuaEvents.PartialScreenHooks_CloseAllExcept.Add( OnCloseAllExcept );

  -- Animation Controller
  m_AnimSupport = CreateScreenAnimation(Controls.SlideAnim);

  -- Rundown / Screen Events
  Events.SystemUpdateUI.Add(m_AnimSupport.OnUpdateUI);

  Controls.Title:SetText(L_Lookup("LOC_TRADE_OVERVIEW_TITLE"));

  -- Game Engine Events
  Events.CitySelectionChanged.Add( OnCitySelectionChanged );
  Events.UnitOperationStarted.Add( OnUnitOperationStarted );
  Events.GovernmentPolicyChanged.Add( OnPolicyChanged );
  Events.GovernmentPolicyObsoleted.Add( OnPolicyChanged );
  Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );
  Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );

  -- Hot-Reload Events
  ContextPtr:SetInitHandler(OnInit);
  ContextPtr:SetShutdown(OnShutdown);
  LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
end
Initialize();
