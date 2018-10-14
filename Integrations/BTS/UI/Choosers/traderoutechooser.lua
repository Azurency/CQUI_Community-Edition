-- ===========================================================================
--  Settings
-- ===========================================================================

local showSortOrdersPermanently = false
local RoutePanelBaseOffsetX = 8;
local RoutePanelScrollPanelExtraOffset = 9;

-- ===========================================================================
--  INCLUDES and Local Functions
-- ===========================================================================

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

local L_Lookup = Locale.Lookup
local L_Upper = Locale.ToUpper

local M_LCick = Mouse.eLClick
local M_Enter = Mouse.eMouseEnter
local M_RClick = Mouse.eRClick

-- ===========================================================================
--  VARIABLES
-- ===========================================================================

local m_RouteChoiceIM           : table = InstanceManager:new("RouteChoiceInstance", "Top", Controls.RouteChoiceStack);
local m_originCity              : table = nil;  -- City where the trade route will begin
local m_destinationCity         : table = nil;  -- City where the trade route will end, nil if none selected

-- These can be set by other contexts to have a route selected automatically after the chooser opens
local m_postOpenSelectPlayerID:number = -1;
local m_postOpenSelectCityID:number = -1;

local m_AvailableTradeRoutes:table = {}; -- Filtered and unfiltered lists of possible routes
local m_TradeRoutes:table = {} -- Routes showm, this is the filtered and sorted
local m_TurnBuiltRouteTable:number = -1;
local m_LastTrader:number = -1;
local m_RebuildAvailableRoutes:boolean = true;

-- Stores filter list and tracks the currently selected list
local m_filterList:table = {};
local m_filterCount:number = 0;
local m_filterSelected:number = 1;

local m_shiftDown:boolean = false;

-- Stores the sort settings.
local m_SortBySettings:table = {};
local m_SortSettingsChanged:boolean = true;

local m_FilterSettingsChanged:boolean = true;

local m_SkipNextOpen:boolean = false;

-- Default is ascending in turns to complete trade route
m_SortBySettings[1] = {
  SortByID = SORT_BY_ID.TURNS_TO_COMPLETE,
  SortOrder = SORT_ASCENDING
};

-- ===========================================================================
--  CQUI
-- ===========================================================================

function CQUI_OnSettingsUpdate()
  showSortOrdersPermanently = GameConfiguration.GetValue("CQUI_TraderShowSortOrder");

  -- Don't call refresh here, since CQUI panel and trade route chooser can't be open simultaneously.
end

-- ===========================================================================
--  Refresh functions
-- ===========================================================================
function Refresh()
  local selectedUnit:table = UI.GetHeadSelectedUnit();
  if selectedUnit == nil then
    Close();
    return;
  end

  m_originCity = Cities.GetCityInPlot(selectedUnit:GetX(), selectedUnit:GetY());
  if m_originCity == nil then
    Close();
    return;
  end

  -- Rebuild if turn has advanced or unit has changed
  if m_LastTrader ~= selectedUnit:GetID() or m_TurnBuiltRouteTable < Game.GetCurrentGameTurn() then
    m_LastTrader = selectedUnit:GetID()
    -- Rebuild and re-sort
    m_RebuildAvailableRoutes = true
  else
    m_RebuildAvailableRoutes = false
  end

  -- Handle post open (ie TradeOverview) calls
  if m_postOpenSelectPlayerID ~= -1 and m_postOpenSelectCityID ~= -1 then
    print_debug("Selecting", m_postOpenSelectCityID)
    local pPlayer = Players[m_postOpenSelectPlayerID]
    m_destinationCity = pPlayer:GetCities():FindID(m_postOpenSelectCityID)
    RealizeLookAtDestinationCity();

    -- Reset values
    m_postOpenSelectPlayerID = -1;
    m_postOpenSelectCityID = -1;
  end

  RefreshHeader();
  RefreshTopPanel();
  RefreshSortBar();
  RefreshChooserPanel();
end

function RefreshHeader()
  if m_originCity then
    Controls.Header_OriginText:SetText(L_Lookup("LOC_ROUTECHOOSER_TO_DESTINATION", L_Upper(m_originCity:GetName())));
  end
end

function RefreshTopPanel()
  if m_destinationCity and m_originCity then
    local tradeRoute = {
      OriginCityPlayer        = m_originCity:GetOwner(),
      OriginCityID            = m_originCity:GetID(),
      DestinationCityPlayer   = m_destinationCity:GetOwner(),
      DestinationCityID       = m_destinationCity:GetID()
    };

    -- Update City Banner
    Controls.CityName:SetText(L_Upper(m_destinationCity:GetName()));

    local backColor, frontColor, darkerBackColor, brighterBackColor = GetPlayerColorInfo(m_destinationCity:GetOwner(), true);

    Controls.BannerBase:SetColor(backColor);
    Controls.BannerDarker:SetColor(darkerBackColor);
    Controls.BannerLighter:SetColor(brighterBackColor);
    Controls.CityName:SetColor(frontColor);

    -- Update Trading Post Icon
    if GetRouteHasTradingPost(tradeRoute, true) then
      Controls.TradingPostIcon:SetHide(false);
    else
      Controls.TradingPostIcon:SetHide(true);
    end

    -- Update City-State Quest Icon
    Controls.CityStateQuestIcon:SetHide(true);
    local questsManager : table = Game.GetQuestsManager();
    local questTooltip  : string = L_Lookup("LOC_CITY_STATES_QUESTS");
    if (questsManager ~= nil and Game.GetLocalPlayer() ~= nil) then
      local tradeRouteQuestInfo:table = GameInfo.Quests["QUEST_SEND_TRADE_ROUTE"];
      if (tradeRouteQuestInfo ~= nil) then
        if (questsManager:HasActiveQuestFromPlayer(Game.GetLocalPlayer(), m_destinationCity:GetOwner(), tradeRouteQuestInfo.Index)) then
          questTooltip = questTooltip .. "[NEWLINE]" .. tradeRouteQuestInfo.IconString .. questsManager:GetActiveQuestName(Game.GetLocalPlayer(), m_destinationCity:GetOwner(), tradeRouteQuestInfo.Index);
          Controls.CityStateQuestIcon:SetHide(false);
          Controls.CityStateQuestIcon:SetToolTipString(questTooltip);
        end
      end
    end

    -- Update turns to complete route
    local tradePathLength, tripsToDestination, turnsToCompleteRoute = GetRouteInfo(tradeRoute, true);
    Controls.TurnsToComplete:SetColor(frontColor);
    Controls.TurnsToComplete:SetText(turnsToCompleteRoute);

    -- Update Resources
    Controls.OriginResourceList:DestroyAllChildren();
    Controls.DestinationResourceList:DestroyAllChildren();

    local originYieldInstance:table = {};
    local originReceivedResources:boolean = false;
    local destinationYieldInstance:table = {};
    local destinationReceivedResources:boolean = false;

    ContextPtr:BuildInstanceForControl( "RouteYieldInstance", originYieldInstance, Controls.OriginResourceList );
    ContextPtr:BuildInstanceForControl( "RouteYieldInstance", destinationYieldInstance, Controls.DestinationResourceList );

    for yieldIndex = START_INDEX, END_INDEX do
      local originCityYieldValue = GetYieldForOriginCity(yieldIndex, tradeRoute, true);
      local destinationCityYieldValue = GetYieldForDestinationCity(yieldIndex, tradeRoute, true);

      SetRouteInstanceYields(originYieldInstance, yieldIndex, originCityYieldValue);
      SetRouteInstanceYields(destinationYieldInstance, yieldIndex, destinationCityYieldValue);

      if not originReceivedResources and originCityYieldValue > 0 then
        originReceivedResources = true
      end
      if not destinationReceivedResources and destinationCityYieldValue > 0 then
        destinationReceivedResources = true
      end
    end

    Controls.OriginResourceHeader:SetText(L_Lookup("LOC_ROUTECHOOSER_RECEIVES_RESOURCE", L_Lookup(m_originCity:GetName())));
    Controls.DestinationResourceHeader:SetText(L_Lookup("LOC_ROUTECHOOSER_RECEIVES_RESOURCE", L_Lookup(m_destinationCity:GetName())));
    local originTooltipText = ""
    local destinationTooltipText:string = "";

    -- Handle Religion pressure icons
    local destinationMajorityReligion = m_destinationCity:GetReligion():GetMajorityReligion();
    if (destinationMajorityReligion > 0) then
      local pressureValue, sourceText = GetReligiousPressureForCity(destinationMajorityReligion, m_destinationCity, true);
      if (pressureValue ~= 0) then
        if (originTooltipText ~= "") then
          originTooltipText = originTooltipText .. "[NEWLINE]";
        end
        originTooltipText = originTooltipText .. sourceText;
        AddReligiousPressureResourceEntry(GameInfo.Religions[destinationMajorityReligion], pressureValue, true, sourceText, originYieldInstance);
        originReceivedResources = true;
      end
    end
    Controls.OriginResources:SetToolTipString(originTooltipText);

    local originMajorityReligion = m_originCity:GetReligion():GetMajorityReligion();
    if (originMajorityReligion > 0) then
      local pressureValue, sourceText = GetReligiousPressureForCity(originMajorityReligion, m_originCity, false);
      if (pressureValue ~= 0) then
        if (destinationTooltipText ~= "") then
          destinationTooltipText = destinationTooltipText .. "[NEWLINE]";
        end
        destinationTooltipText = destinationTooltipText .. sourceText;
        AddReligiousPressureResourceEntry(GameInfo.Religions[originMajorityReligion], pressureValue, false, sourceText, destinationYieldInstance);
        destinationReceivedResources = true;
      end
    end
    Controls.DestinationResources:SetToolTipString(destinationTooltipText);

    if originReceivedResources then
      Controls.OriginReceivesNoBenefitsLabel:SetHide(true);
    else
      Controls.OriginReceivesNoBenefitsLabel:SetHide(false);
    end

    if destinationReceivedResources then
      Controls.DestinationReceivesNoBenefitsLabel:SetHide(true);
    else
      Controls.DestinationReceivesNoBenefitsLabel:SetHide(false);
    end

    -- Cleanup
    Controls.OriginResourceList:CalculateSize();
    Controls.OriginResourceList:ReprocessAnchoring();
    Controls.DestinationResourceList:CalculateSize();
    Controls.DestinationResourceList:ReprocessAnchoring();
    Controls.TopGrid:DoAutoSize();

    -- Show Panel
    Controls.CurrentSelectionContainer:SetHide(false);
    Controls.CurrentSelectionContainer:DoAutoSize();

    -- Hide Status Message
    Controls.StatusMessage:SetHide(true);
  else
    -- Hide Panel
    Controls.CurrentSelectionContainer:SetHide(true);

    -- Show Status Message
    Controls.StatusMessage:SetHide(false);
    Controls.StatusMessage:DoAutoSize();
  end
end

function RefreshChooserPanel()
  local tradeManager:table = Game.GetTradeManager();

  -- Do we rebuild available routes?
  if m_RebuildAvailableRoutes then
    -- Reset Available routes
    m_AvailableTradeRoutes = {};

    -- Gather available routes
    local originCityPlayerID = m_originCity:GetOwner()
    local originCityID = m_originCity:GetID()
    local players:table = Game.GetPlayers{ Alive=true };
    for _, player in ipairs(players) do
      local destinationCityPlayerID = player:GetID()
      for _, city in player:GetCities():Members() do
        local destinationCityID = city:GetID()
        -- Can we start a trade route with this city?
        if tradeManager:CanStartRoute(originCityPlayerID, originCityID, destinationCityPlayerID, destinationCityID) then
          local tradeRoute = {
            OriginCityPlayer        = originCityPlayerID,
            OriginCityID            = originCityID,
            DestinationCityPlayer   = destinationCityPlayerID,
            DestinationCityID       = destinationCityID
          };

          tinsert(m_AvailableTradeRoutes, tradeRoute);
        end
      end
    end

    -- Need to re-filter and re-sort
    m_SortSettingsChanged = true
    m_FilterSettingsChanged = true

    -- Cache routes info.
    CacheEmpty()
    CacheRoutesInfo(m_AvailableTradeRoutes)

    m_TurnBuiltRouteTable = Game.GetCurrentGameTurn()
    m_RebuildAvailableRoutes = false -- done building routes
  else
    print_debug("OPT: Not rebuilding routes")
  end

  -- Update Filters
  RefreshFilters();

  -- Update Destination Choice Stack
  RefreshStack();

  -- Send Trade Route Paths to Engine
  UILens.ClearLayerHexes( LensLayers.TRADE_ROUTE );

  local DEFAULT_TINT = RGBAValuesToABGRHex(1, 1, 1, 1);
  local FADED_TINT = RGBAValuesToABGRHex(0.3, 0.3, 0.3, 1);

  -- If a city is selected, fade the other routes
  local kUnselectedColor = DEFAULT_TINT;
  if (m_destinationCity ~= nil) then kUnselectedColor = FADED_TINT; end

  -- Show all paths that aren't selected
  local pathPlots:table = {};
  for _, routeInfo in ipairs(m_TradeRoutes) do
    local destinationPlayer:table = Players[routeInfo.DestinationCityPlayer];
    local destinationCity:table = destinationPlayer:GetCities():FindID(routeInfo.DestinationCityID);

    pathPlots = tradeManager:GetTradeRoutePath(m_originCity:GetOwner(), m_originCity:GetID(), destinationCity:GetOwner(), destinationCity:GetID() );
    local kVariations:table = {};
    local lastElement:number = table.count(pathPlots);
    table.insert(kVariations, {"TradeRoute_Destination", pathPlots[lastElement]} );
    if (destinationCity ~= m_destinationCity) then
      UILens.SetLayerHexesPath( LensLayers.TRADE_ROUTE, Game.GetLocalPlayer(), pathPlots, kVariations, kUnselectedColor );
    end
  end

  -- Show the selected path last if it exists so it's on top
  if m_destinationCity ~= nil then
    pathPlots = tradeManager:GetTradeRoutePath(m_originCity:GetOwner(), m_originCity:GetID(), m_destinationCity:GetOwner(), m_destinationCity:GetID() );
    local kVariations:table = {};
    local lastElement : number = table.count(pathPlots);
    table.insert(kVariations, {"TradeRoute_Destination", pathPlots[lastElement]} );
    UILens.SetLayerHexesPath( LensLayers.TRADE_ROUTE, Game.GetLocalPlayer(), pathPlots, kVariations, DEFAULT_TINT );
  end
end

-- ===========================================================================
--  Routes stack Function
-- ===========================================================================

function RefreshStack()
  -- Reset destinations
  m_RouteChoiceIM:ResetInstances();

  local tradeManager:table = Game.GetTradeManager();

  -- Filter Destinations by active Filter
  if m_FilterSettingsChanged then
    m_TradeRoutes = FilterTradeRoutes(m_AvailableTradeRoutes);
    m_FilterSettingsChanged = false -- done filtering

    -- Filter changed, need to re-sort
    m_SortSettingsChanged = true
  else
    print_debug("OPT: Not refiltering.")
  end

  if m_SortSettingsChanged then
    m_TradeRoutes = SortTradeRoutes(m_TradeRoutes, m_SortBySettings);
    m_SortSettingsChanged = false -- done sorting
  else
    print_debug("OPT: Not resorting.")
  end

  -- for i, tradeRoute in ipairs(tradeRoutes) do
  for i=1, #m_TradeRoutes do
    AddRouteToDestinationStack(m_TradeRoutes[i]);
  end

  Controls.RouteChoiceStack:CalculateSize();
  Controls.RouteChoiceScrollPanel:CalculateSize();

  -- Adjust offset based on scroll bar
  if Controls.RouteChoiceScrollPanel:GetScrollBar():IsHidden() then
    Controls.RouteContainer:SetOffsetX(RoutePanelBaseOffsetX);
  else
    Controls.RouteContainer:SetOffsetX(RoutePanelBaseOffsetX + RoutePanelScrollPanelExtraOffset);
  end

  -- Show No Available Trade Routes message if nothing to select
  if #m_TradeRoutes > 0 then
    Controls.StatusMessage:SetText(L_Lookup("LOC_ROUTECHOOSER_SELECT_DESTINATION"));
  else
    Controls.StatusMessage:SetText(L_Lookup("LOC_ROUTECHOOSER_NO_TRADE_ROUTES"));
  end
end

function AddRouteToDestinationStack(routeInfo:table)
  local cityEntry:table = m_RouteChoiceIM:GetInstance();

  local destinationPlayer:table = Players[routeInfo.DestinationCityPlayer];
  local destinationCity:table = destinationPlayer:GetCities():FindID(routeInfo.DestinationCityID);
  local originPlayer:table = Players[routeInfo.OriginCityPlayer];
  local originCity:table = originPlayer:GetCities():FindID(routeInfo.OriginCityID);

  -- Update Selector Brace
  if m_destinationCity ~= nil and destinationCity:GetName() == m_destinationCity:GetName() then
    cityEntry.SelectorBrace:SetHide(false);
    cityEntry.Button:SetTextureOffsetVal(0, 76*1)
  else
    cityEntry.SelectorBrace:SetHide(true);
    cityEntry.Button:SetTextureOffsetVal(0, 76*0)
  end

  -- Setup city banner
  cityEntry.CityName:SetText(L_Upper(destinationCity:GetName()));

  local backColor, frontColor, darkerBackColor, brighterBackColor = GetPlayerColorInfo(routeInfo.DestinationCityPlayer, true);

  cityEntry.BannerBase:SetColor(backColor);
  cityEntry.BannerDarker:SetColor(darkerBackColor);
  cityEntry.BannerLighter:SetColor(brighterBackColor);
  cityEntry.CityName:SetColor(frontColor);

  -- Update Trading Post Icon
  if GetRouteHasTradingPost(routeInfo, true) then
    cityEntry.TradingPostIcon:SetHide(false);
  else
    cityEntry.TradingPostIcon:SetHide(true);
  end

  -- Update City-State Quest Icon
  cityEntry.CityStateQuestIcon:SetHide(true);
  local questsManager : table = Game.GetQuestsManager();
  local questTooltip  : string = L_Lookup("LOC_CITY_STATES_QUESTS");
  if (questsManager ~= nil and Game.GetLocalPlayer() ~= nil) then
    local tradeRouteQuestInfo:table = GameInfo.Quests["QUEST_SEND_TRADE_ROUTE"];
    if (tradeRouteQuestInfo ~= nil) then
      if (questsManager:HasActiveQuestFromPlayer(routeInfo.OriginCityPlayer, routeInfo.DestinationCityPlayer, tradeRouteQuestInfo.Index)) then
        questTooltip = questTooltip .. "[NEWLINE]" .. tradeRouteQuestInfo.IconString .. questsManager:GetActiveQuestName(Game.GetLocalPlayer(), routeInfo.DestinationCityPlayer, tradeRouteQuestInfo.Index);
        cityEntry.CityStateQuestIcon:SetHide(false);
        cityEntry.CityStateQuestIcon:SetToolTipString(questTooltip);
      end
    end
  end

  local tradePathLength, tripsToDestination, turnsToCompleteRoute = GetRouteInfo(routeInfo, true);
  tooltipString = (   L_Lookup("LOC_TRADE_TURNS_REMAINING_HELP_TOOLTIP") .. "[NEWLINE]" ..
            L_Lookup("LOC_TRADE_TURNS_REMAINING_TOOLTIP_BREAKER") .. "[NEWLINE]" ..
            L_Lookup("LOC_TRADE_TURNS_REMAINING_ROUTE_LENGTH_TOOLTIP", tradePathLength) .. "[NEWLINE]" ..
            L_Lookup("LOC_TRADE_TURNS_REMAINING_TRIPS_COUNT_TOOLTIP", tripsToDestination) .. "[NEWLINE]" ..
            L_Lookup("LOC_TRADE_TURNS_REMAINING_TURN_COMPLETION_ALT_TOOLTIP", turnsToCompleteRoute, (Game.GetCurrentGameTurn() + turnsToCompleteRoute)) );

  cityEntry.TurnsToComplete:SetText(turnsToCompleteRoute);
  cityEntry.TurnsToComplete:SetToolTipString( tooltipString );
  cityEntry.TurnsToComplete:SetColor( frontColor );

  -- Setup resources
  local tooltipText = "";
  cityEntry.ResourceList:DestroyAllChildren();

  local originYieldInstance:table = {};
  local destinationYieldInstance:table = {};
  ContextPtr:BuildInstanceForControl( "RouteYieldInstance", originYieldInstance, cityEntry.ResourceList );
  ContextPtr:BuildInstanceForControl( "RouteYieldInstance", destinationYieldInstance, cityEntry.ResourceList );

  for yieldIndex = START_INDEX, END_INDEX do
    -- Don't used a cache call here, since we need more info for the tooltip
    local originYieldValue, sourceText = GetYieldForCity(yieldIndex, destinationCity, true);
    -- Normal cached call here
    local destinationYieldValue = GetYieldForDestinationCity(yieldIndex, routeInfo, true);

    if originYieldValue > 0 then
      if (tooltipText ~= "" and originYieldValue > 0) then
        tooltipText = tooltipText .. "[NEWLINE]";
      end
      tooltipText = tooltipText .. sourceText;
    end

    SetRouteInstanceYields(originYieldInstance, yieldIndex, originYieldValue)
    SetRouteInstanceYields(destinationYieldInstance, yieldIndex, destinationYieldValue)
  end

  local destinationMajorityReligion = destinationCity:GetReligion():GetMajorityReligion();
  if (destinationMajorityReligion > 0) then
    local pressureValue, sourceText = GetReligiousPressureForCity(destinationMajorityReligion, destinationCity, true);
    if (pressureValue ~= 0) then
      if (tooltipText ~= "") then
        tooltipText = tooltipText .. "[NEWLINE]";
      end
      tooltipText = tooltipText .. sourceText;
      AddReligiousPressureResourceEntry(GameInfo.Religions[destinationMajorityReligion], pressureValue, true, sourceText, originYieldInstance);
    end
  end

  local originMajorityReligion = originCity:GetReligion():GetMajorityReligion();
  if (originMajorityReligion > 0) then
    local pressureValue, sourceText = GetReligiousPressureForCity(originMajorityReligion, destinationCity, false);
    if (pressureValue ~= 0) then
      if (tooltipText ~= "") then
        tooltipText = tooltipText .. "[NEWLINE]";
      end
      tooltipText = tooltipText .. sourceText;
      AddReligiousPressureResourceEntry(GameInfo.Religions[originMajorityReligion], pressureValue, false, sourceText, destinationYieldInstance);
    end
  end

  -- Cleanup
  cityEntry.ResourceList:CalculateSize();
  cityEntry.ResourceList:ReprocessAnchoring();

  cityEntry.Button:SetToolTipString(tooltipText);

  -- Setup callback
  cityEntry.Button:SetVoids(routeInfo.DestinationCityPlayer, routeInfo.DestinationCityID);
  cityEntry.Button:RegisterCallback( M_LCick, OnTradeRouteSelected );
end

-- ---------------------------------------------------------------------------
-- Route button helpers
-- ---------------------------------------------------------------------------

-- ===========================================================================
function SetRouteInstanceYields(yieldsInstance, yieldIndex, yieldValue)
  local iconString, text = FormatYieldText(yieldIndex, yieldValue);

  if (yieldIndex == FOOD_INDEX) then
    yieldsInstance.YieldFoodLabel:SetText(text .. iconString);
  elseif (yieldIndex == PRODUCTION_INDEX) then
    yieldsInstance.YieldProductionLabel:SetText(text .. iconString);
  elseif (yieldIndex == GOLD_INDEX) then
    yieldsInstance.YieldGoldLabel:SetText(text .. iconString);
  elseif (yieldIndex == SCIENCE_INDEX) then
    yieldsInstance.YieldScienceLabel:SetText(text .. iconString);
  elseif (yieldIndex == CULTURE_INDEX) then
    yieldsInstance.YieldCultureLabel:SetText(text .. iconString);
  elseif (yieldIndex == FAITH_INDEX) then
    yieldsInstance.YieldFaithLabel:SetText(text .. iconString);
  end
end

-- ===========================================================================
function GetReligiousPressureForCity(religionIndex:number, destinationCity:table, forOriginCity:boolean)
  local pressureValue = 0;
  local pressureIconString = "";
  local cityName = "";
  local tradeManager = Game.GetTradeManager();

  if m_originCity == nil or destinationCity == nil then
    return 0, "";
  end

  if (forOriginCity) then
    pressureValue = tradeManager:CalculateOriginReligiousPressureFromPotentialRoute(m_originCity:GetOwner(), m_originCity:GetID(), destinationCity:GetOwner(), destinationCity:GetID(), religionIndex);
    pressureIconString = "[ICON_PressureLeft]";
    cityName = destinationCity:GetName();
  else
    pressureValue = tradeManager:CalculateDestinationReligiousPressureFromPotentialRoute(m_originCity:GetOwner(), m_originCity:GetID(), destinationCity:GetOwner(), destinationCity:GetID(), religionIndex);
    pressureIconString = "[ICON_PressureRight]";
    cityName = m_originCity:GetName();
  end
  local sourceText = Locale.Lookup("LOC_ROUTECHOOSER_RELIGIOUS_PRESSURE_SOURCE_MAJORITY_RELIGION", pressureValue, pressureIconString, Game.GetReligion():GetName(religionIndex), cityName);
  return pressureValue, sourceText;
end

-- ===========================================================================
function AddReligiousPressureResourceEntry(religionInfo:table, pressureValue:number, forOriginCity:boolean, sourceText:string, instanceControl:table)
  -- local entryInstance:table = {};
  -- ContextPtr:BuildInstanceForControl( "ReligionPressureEntryInstance", entryInstance, stackControl );
  instanceControl.RouteReligionContainer:SetHide(false);

  local religionColor = UI.GetColorValue(religionInfo.Color);
  local religionName = Game.GetReligion():GetName(religionInfo.Index);
  instanceControl.ReligionIcon:SetIcon("ICON_" .. religionInfo.ReligionType);
  instanceControl.ReligionIcon:SetColor(religionColor);
  instanceControl.ReligionIconBacking:SetColor(religionColor);
  instanceControl.ReligionIconBacking:SetToolTipString(religionName);

  local icon:string, text:string = FormatReligiousPressureText(religionInfo, pressureValue, forOriginCity);
  instanceControl.ResourceEntryText:SetText(text);
  -- instanceControl.RouteReligionContainer:CalculateSize();
  -- instanceControl.RouteReligionContainer:ReprocessAnchoring();
end

-- ===========================================================================
function FormatReligiousPressureText(religionInfo, pressureValue, forOriginCity:boolean)
  local text:string = "";

  local iconString = "";
  if (religionInfo ~= nil) then
    if (forOriginCity) then
      iconString = "[ICON_PressureLeft]";
    else
      iconString = "[ICON_PressureRight]";
    end
  end

  if (pressureValue >= 0) then
    text = text .. "+";
  end

  text = text .. pressureValue;
  return iconString, text;
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

  for index, tradeRoute in ipairs(tradeRoutes) do
    local pPlayer = Players[tradeRoute.DestinationCityPlayer];
    if m_filterList[m_filterSelected].FilterFunction and m_filterList[m_filterSelected].FilterFunction(pPlayer) then
      tinsert(filtertedRoutes, tradeRoute);
    end
  end

  return filtertedRoutes;
end

-- ---------------------------------------------------------------------------
-- Filter pulldown functions
-- ---------------------------------------------------------------------------
function RefreshFilters()
  -- Clear current filters
  Controls.DestinationFilterPulldown:ClearEntries();
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
  for index, pPlayer in ipairs(players) do
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
  for index, filter in ipairs(m_filterList) do
    AddFilterEntry(index);
  end

  -- Select first filter
  Controls.FilterButton:SetText(m_filterList[m_filterSelected].FilterText);

  -- Calculate Internals
  Controls.DestinationFilterPulldown:CalculateInternals();

  UpdateFilterArrow();
end

function AddFilter( filterName:string, filterFunction )
  -- Make sure we don't add duplicate filters
  for index, filter in ipairs(m_filterList) do
    if filter.FilterText == filterName then
      return;
    end
  end

  m_filterCount = m_filterCount + 1;
  m_filterList[m_filterCount] = {FilterText=filterName, FilterFunction=filterFunction};
end

function AddFilterEntry( filterIndex:number )
  local filterEntry:table = {};
  Controls.DestinationFilterPulldown:BuildEntry( "FilterEntry", filterEntry );
  filterEntry.Button:SetText(m_filterList[filterIndex].FilterText);
  filterEntry.Button:SetVoids(i, filterIndex);
end

function UpdateFilterArrow()
  if Controls.DestinationFilterPulldown:IsOpen() then
    Controls.PulldownOpenedArrow:SetHide(true);
    Controls.PulldownClosedArrow:SetHide(false);
  else
    Controls.PulldownOpenedArrow:SetHide(false);
    Controls.PulldownClosedArrow:SetHide(true);
  end
end

function OnFilterSelected( index:number, filterIndex:number )
  m_filterSelected = filterIndex;
  Controls.FilterButton:SetText(m_filterList[m_filterSelected].FilterText);

  m_FilterSettingsChanged = true
  Refresh();
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
  RefreshSortButtons( m_SortBySettings );

  if showSortOrdersPermanently or m_shiftDown then
    -- Hide the order texts
    HideSortOrderLabels();
    -- Show them based on current settings
    ShowSortOrderLabels();
  end
end

function ShowSortOrderLabels()
  -- Refresh and show sort orders
  RefreshSortOrderLabels( m_SortBySettings );
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
  for index, sortEntry in ipairs(sortSettings) do
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
  for index, sortEntry in ipairs(sortSettings) do
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
--  General Helper functions
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Trade route helper functions
-- ---------------------------------------------------------------------------

function TradeRouteSelected( cityOwner:number, cityID:number )
  local player:table = Players[cityOwner];
  if player then
    local pCity:table = player:GetCities():FindID(cityID);
    if pCity ~= nil then
      m_destinationCity = pCity;
    else
      error("Unable to find city '".. tostring(cityID).."' for creating a trade route.");
    end
  end

  Refresh();
end

function GetYieldForCity(yieldIndex:number, city:table, originCity:boolean)
  local tradeManager = Game.GetTradeManager();
  local yieldInfo = GameInfo.Yields[yieldIndex];
  local totalValue = 0;
  local partialValue = 0;
  local sourceText = "";

  -- From route
  if (originCity) then
    partialValue = tradeManager:CalculateOriginYieldFromPotentialRoute(m_originCity:GetOwner(), m_originCity:GetID(), city:GetOwner(), city:GetID(), yieldIndex);
  else
    partialValue = tradeManager:CalculateDestinationYieldFromPotentialRoute(m_originCity:GetOwner(), m_originCity:GetID(), city:GetOwner(), city:GetID(), yieldIndex);
  end
  totalValue = totalValue + partialValue;
  if (partialValue > 0 and yieldInfo ~= nil) then
    if (sourceText ~= "") then
      sourceText = sourceText .. "[NEWLINE]";
    end
    sourceText = sourceText .. L_Lookup("LOC_ROUTECHOOSER_YIELD_SOURCE_DISTRICTS", partialValue, yieldInfo.IconString, yieldInfo.Name, city:GetName());
  end
  -- From path
  if (originCity) then
    partialValue = tradeManager:CalculateOriginYieldFromPath(m_originCity:GetOwner(), m_originCity:GetID(), city:GetOwner(), city:GetID(), yieldIndex);
  else
    partialValue = tradeManager:CalculateDestinationYieldFromPath(m_originCity:GetOwner(), m_originCity:GetID(), city:GetOwner(), city:GetID(), yieldIndex);
  end
  totalValue = totalValue + partialValue;
  if (partialValue > 0 and yieldInfo ~= nil) then
    if (sourceText ~= "") then
      sourceText = sourceText .. "[NEWLINE]";
    end
    sourceText = sourceText .. L_Lookup("LOC_ROUTECHOOSER_YIELD_SOURCE_TRADING_POSTS", partialValue, yieldInfo.IconString, yieldInfo.Name);
  end
  -- From modifiers
  local resourceID = -1;
  if (originCity) then
    partialValue = tradeManager:CalculateOriginYieldFromModifiers(m_originCity:GetOwner(), m_originCity:GetID(), city:GetOwner(), city:GetID(), yieldIndex, resourceID);
  else
    partialValue = tradeManager:CalculateDestinationYieldFromModifiers(m_originCity:GetOwner(), m_originCity:GetID(), city:GetOwner(), city:GetID(), yieldIndex, resourceID);
  end
  totalValue = totalValue + partialValue;
  if (partialValue > 0 and yieldInfo ~= nil) then
    if (sourceText ~= "") then
      sourceText = sourceText .. "[NEWLINE]";
    end
    sourceText = sourceText .. L_Lookup("LOC_ROUTECHOOSER_YIELD_SOURCE_BONUSES", partialValue, yieldInfo.IconString, yieldInfo.Name);
  end

  return totalValue, sourceText;
end

-- ===========================================================================
--  Look at the plot of the destination city.
--  Not always done when selected, as sometimes the TradeOverview will be
--  open and it's going to perform it's own lookat.
-- ===========================================================================
function RealizeLookAtDestinationCity()
  if m_destinationCity == nil then
    UI.DataError("TradeRouteChooser cannot look at a NIL destination.");
    return;
  end

  local locX      :number = m_destinationCity:GetX();
  local locY      :number = m_destinationCity:GetY();
  local screenXOff:number = 0.6;

  -- Change offset if the TradeOveriew (exists and) is open as well.
  local pContextControl:table = ContextPtr:LookUpControl("/InGame/TradeOverview");
  if pContextControl == nil then
    UI.DataError("Cannot determine if partial screen \"/InGame/TradeOverview\" is visible because it wasn't found at that path.");
  elseif not pContextControl:IsHidden() then
    screenXOff = 0.42;
  end

  UI.LookAtPlotScreenPosition( locX, locY, screenXOff, 0.5 ); -- Look at 60% over from left side of screen
end

-- ===========================================================================
--  UI Button Callback
-- ===========================================================================
function OnTradeRouteSelected( cityOwner:number, cityID:number )
  TradeRouteSelected( cityOwner, cityID );
  RealizeLookAtDestinationCity();

  LuaEvents.TradeRouteChooser_RouteConsidered();
end

function OnRepeatRouteCheckbox()
  if not Controls.RepeatRouteCheckbox:IsChecked() then
    Controls.FromTopSortEntryCheckbox:SetCheck(false);
  end
end

function OnFromTopSortEntryCheckbox()
  -- FromTopSortEntryCheckbox is tied to RepeatRouteCheckbox
  if Controls.FromTopSortEntryCheckbox:IsChecked() then
    Controls.RepeatRouteCheckbox:SetCheck(true);
  end
end

function RequestTradeRoute()
  local selectedUnit = UI.GetHeadSelectedUnit();
  if m_destinationCity and selectedUnit then
    local operationParams = {};
    operationParams[UnitOperationTypes.PARAM_X0] = m_destinationCity:GetX();
    operationParams[UnitOperationTypes.PARAM_Y0] = m_destinationCity:GetY();
    operationParams[UnitOperationTypes.PARAM_X1] = selectedUnit:GetX();
    operationParams[UnitOperationTypes.PARAM_Y1] = selectedUnit:GetY();
    if (UnitManager.CanStartOperation(selectedUnit, UnitOperationTypes.MAKE_TRADE_ROUTE, nil, operationParams)) then
      UnitManager.RequestOperation(selectedUnit, UnitOperationTypes.MAKE_TRADE_ROUTE, operationParams);
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
      UI.PlaySound("START_TRADE_ROUTE");

      -- Automated Handlers
      if Controls.RepeatRouteCheckbox:IsChecked() and Controls.FromTopSortEntryCheckbox:IsChecked() then
        AutomateTrader(selectedUnit:GetID(), true, m_SortBySettings);
      elseif Controls.RepeatRouteCheckbox:IsChecked() then
        AutomateTrader(selectedUnit:GetID(), true);
      else
        AutomateTrader(selectedUnit:GetID(), false);
      end
    end

    return true;
  end

  return false;
end

-- ---------------------------------------------------------------------------
-- Sort bar insert buttons
-- ---------------------------------------------------------------------------

function OnGeneralSortBy(descArrowControl, sortByID)
  -- If shift is not being pressed, reset sort settings
  if not m_shiftDown then
    m_SortBySettings = {};
  end

  -- Sort based on currently showing icon toggled
  if descArrowControl:IsHidden() then
    InsertSortEntry(sortByID, SORT_DESCENDING, m_SortBySettings);
  else
    InsertSortEntry(sortByID, SORT_ASCENDING, m_SortBySettings);
  end

  m_SortSettingsChanged = true
  Refresh();
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
function OnGeneralNotSortBy(sortByID)
  RemoveSortEntry(sortByID, m_SortBySettings);

  m_SortSettingsChanged = true
  Refresh();
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
--  Rise/Hide and refresh Trade UI
-- ===========================================================================
function OnInterfaceModeChanged( oldMode:number, newMode:number )
  if (oldMode == InterfaceModeTypes.MAKE_TRADE_ROUTE) then
    Close();
  end
  if (newMode == InterfaceModeTypes.MAKE_TRADE_ROUTE) then
    Open();
  end
end

function OnClose()
  Close();

  if UI.GetInterfaceMode() == InterfaceModeTypes.MAKE_TRADE_ROUTE then
    UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
  end
end

function Close()
  LuaEvents.TradeRouteChooser_SetTradeUnitStatus("");
  ContextPtr:SetHide(true);

  if UILens.IsLensActive("TradeRoute") then
    -- Make sure to switch back to default lens
    UILens.SetActive("Default");
  end
end

function Open()
  LuaEvents.TradeRouteChooser_SetTradeUnitStatus("LOC_HUD_UNIT_PANEL_CHOOSING_TRADE_ROUTE");

  ContextPtr:SetHide(false);
  m_destinationCity = nil;
  Controls.RepeatRouteCheckbox:SetCheck(false);
  Controls.FromTopSortEntryCheckbox:SetCheck(false);

  -- Play Open Animation
  Controls.RouteChooserSlideAnim:SetToBeginning();
  Controls.RouteChooserSlideAnim:Play();

  -- Switch to TradeRoute Lens
  UILens.SetActive("TradeRoute");

  LuaEvents.TradeRouteChooser_Open();

  local selectedUnit:table = UI.GetHeadSelectedUnit();
  local selectedUnitID:number = selectedUnit:GetID();

  -- Select last route if one exists
  local lastRoute:table = GetLastRouteForTrader(selectedUnitID);
  if lastRoute ~= nil then
    print_debug("Last route for trader " .. selectedUnitID .. ": " .. GetTradeRouteString(lastRoute));
    originCity = Cities.GetCityInPlot(selectedUnit:GetX(), selectedUnit:GetY());

    -- Don't select the route, if trader was transferred
    if lastRoute.OriginCityID ~= originCity:GetID() then
      print_debug("Trader was transferred. Not selecting the last route")
    elseif IsRoutePossible(originCity:GetOwner(), originCity:GetID(), lastRoute.DestinationCityPlayer, DestinationCityID) then
      local destinationPlayer:table = Players[lastRoute.DestinationCityPlayer];
      m_destinationCity = destinationPlayer:GetCities():FindID(lastRoute.DestinationCityID);
    else
      print_debug("Route is no longer valid.");
    end
  else
    print_debug("No last route was found for trader " .. selectedUnitID);
  end

  Refresh();
end

function CheckNeedsToOpen()
  if m_SkipNextOpen then
    m_SkipNextOpen = false
    return
  end

  local selectedUnit:table = UI.GetHeadSelectedUnit();
  if selectedUnit ~= nil then
    local selectedUnitInfo:table = GameInfo.Units[selectedUnit:GetUnitType()];
    if selectedUnitInfo ~= nil and selectedUnitInfo.MakeTradeRoute == true then
      local activityType:number = UnitManager.GetActivityType(selectedUnit);
      if activityType == ActivityTypes.ACTIVITY_AWAKE and selectedUnit:GetMovesRemaining() > 0 then
        -- If we're open and this is a trade unit then just refresh
        if not ContextPtr:IsHidden() then
          Refresh();
        else
          UI.SetInterfaceMode(InterfaceModeTypes.MAKE_TRADE_ROUTE);
        end

        -- Early out so we don't call Close()
        return;
      end
    end
  end

  -- If we're open and this unit is not a trade unit then close
  if not ContextPtr:IsHidden() then
    Close();
  end
end

function OnSkipNextOpen()
  m_SkipNextOpen = true
end

-- ===========================================================================
--  UI Events
-- ===========================================================================
function OnInit( isReload:boolean )
  if isReload then
    LuaEvents.GameDebug_GetValues( "TradeRouteChooser" );
  end
end

function OnShutdown()
  -- Cache values for hotloading...
  LuaEvents.GameDebug_AddValue("TradeRouteChooser", "filterIndex", m_filterSelected );
  LuaEvents.GameDebug_AddValue("TradeRouteChooser", "destinationCity", m_destinationCity );
end

-- ===========================================================================
--  LUA Event
--  Set cached values back after a hotload.
-- ===========================================================================s
function OnGameDebugReturn( context:string, contextTable:table )
  if context ~= "TradeRouteChooser" then
    return;
  end

  if contextTable["filterIndex"] ~= nil then
    m_filterSelected = contextTable["filterIndex"];
  end
  if contextTable["destinationCity"] ~= nil then
    m_destinationCity = contextTable["destinationCity"];
  end

  Refresh();
end

-- ===========================================================================
--  GAME Event
--  City was selected so close route chooser
-- ===========================================================================
function OnCitySelectionChanged(owner, ID, i, j, k, bSelected, bEditable)
  if not ContextPtr:IsHidden() and owner == Game.GetLocalPlayer() then
    OnClose();
  end
end

-- ===========================================================================
--  GAME Event
--  Unit was selected so close route chooser
-- ===========================================================================
function OnUnitSelectionChanged( playerID:number, unitID:number, hexI:number, hexJ:number, hexK:number, bSelected:boolean, bEditable:boolean )

  -- Make sure we're the local player and not observing
  if playerID ~= Game.GetLocalPlayer() or playerID == -1 then
    return;
  end

  -- Don't call open/close if TradeOverview is open (needed to make TradeOriginChooser open from TradeOverview)
  -- local pContextControl:table = ContextPtr:LookUpControl("/InGame/TradeOverview");
  -- if pContextControl == nil then
  --     print("Cannot determine if partial screen \"/InGame/TradeOverview\" is visible because it wasn't found at that path.");
  -- elseif not pContextControl:IsHidden() then
  --     print("Trade Overview Panel is open. Not opening Make Trade Route screen.")
  --     return
  -- end

  -- If this is a de-selection event then close
  if not bSelected then
    OnClose();
    return;
  end

  CheckNeedsToOpen()
end

function OnLocalPlayerTurnEnd()
  if(GameConfiguration.IsHotseat()) then
    OnClose();
  end

  -- Clear cache to keep memory used low
  CacheEmpty()
end

function OnUnitActivityChanged( playerID :number, unitID :number, eActivityType :number)
  -- Make sure we're the local player and not observing
  if playerID ~= Game.GetLocalPlayer() or playerID == -1 then
    return;
  end

  CheckNeedsToOpen();
end

function OnPolicyChanged( ePlayer )
  if not ContextPtr:IsHidden() and ePlayer == Game.GetLocalPlayer() then
    Refresh();
  end
end

-- ===========================================================================
--  Input
--  UI Event Handler
-- ===========================================================================
function KeyDownHandler( key:number )
  if key == Keys.VK_SHIFT then
    m_shiftDown = true;
    if not showSortOrdersPermanently then
      ShowSortOrderLabels();
    end
    -- let it fall through
  end
  return false;
end

function KeyUpHandler( key:number )
  if key == Keys.VK_SHIFT then
    m_shiftDown = false;
    if not showSortOrdersPermanently then
      HideSortOrderLabels();
    end
    -- let it fall through
  end
  if key == Keys.VK_RETURN then
    if m_destinationCity then
      RequestTradeRoute();
    end
    -- Dont let it fall through
    return true;
  end
  if key == Keys.VK_ESCAPE then
    OnClose();
    -- AZURENCY : on ESC also unselect the unit
    --return true;
  end
  return false;
end

function OnInputHandler( pInputStruct:table )
  local uiMsg = pInputStruct:GetMessageType();
  if uiMsg == KeyEvents.KeyDown then return KeyDownHandler( pInputStruct:GetKey() ); end
  if uiMsg == KeyEvents.KeyUp then return KeyUpHandler( pInputStruct:GetKey() ); end
  return false;
end

-- ===========================================================================
function OnSelectRouteFromOverview( destinationOwnerID:number, destinationCityID:number )
  m_postOpenSelectPlayerID = destinationOwnerID;
  m_postOpenSelectCityID = destinationCityID;

  CheckNeedsToOpen()
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
  print("Initializing BTS Trade Route Chooser");

  TradeSupportAutomater_Initialize();

  -- CQUI Handlers
  LuaEvents.CQUI_SettingsUpdate.Add( CQUI_OnSettingsUpdate );

  -- Context Events
  ContextPtr:SetInitHandler( OnInit );
  ContextPtr:SetShutdown( OnShutdown );
  ContextPtr:SetInputHandler( OnInputHandler, true );

  -- Lua Events
  LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );

  -- Context Events
  LuaEvents.TradeRouteChooser_SkipOpen.Add( OnSkipNextOpen )
  LuaEvents.TradeOverview_SelectRouteFromOverview.Add( OnSelectRouteFromOverview );
  LuaEvents.TradeRouteChooser_Close.Add( OnClose )

  -- Game Engine Events
  Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
  Events.CitySelectionChanged.Add( OnCitySelectionChanged );
  Events.UnitSelectionChanged.Add( OnUnitSelectionChanged );
  Events.UnitActivityChanged.Add( OnUnitActivityChanged );
  Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );
  Events.GovernmentPolicyChanged.Add( OnPolicyChanged );
  Events.GovernmentPolicyObsoleted.Add( OnPolicyChanged );

  -- Control Events
  InitButton(Controls.BeginRouteButton, RequestTradeRoute)
  InitButton(Controls.Header_CloseButton, OnClose )

  -- Filter
  Controls.FilterButton:RegisterCallback( eLClick, UpdateFilterArrow );
  Controls.DestinationFilterPulldown:RegisterSelectionCallback( OnFilterSelected );

  -- Control events - checkboxes
  InitButton(Controls.RepeatRouteCheckbox, OnRepeatRouteCheckbox );
  InitButton(Controls.FromTopSortEntryCheckbox, OnFromTopSortEntryCheckbox );


  -- Control events - sort bar
  InitButton(Controls.FoodSortButton, OnSortByFood, OnNotSortByFood)
  InitButton(Controls.ProductionSortButton, OnSortByProduction, OnNotSortByProduction)
  InitButton(Controls.GoldSortButton, OnSortByGold, OnNotSortByGold)
  InitButton(Controls.ScienceSortButton, OnSortByScience, OnNotSortByScience)
  InitButton(Controls.CultureSortButton, OnSortByCulture, OnNotSortByCulture)
  InitButton(Controls.FaithSortButton, OnSortByFaith, OnNotSortByFaith)
  InitButton(Controls.TurnsToCompleteSortButton, OnSortByTurnsToComplete, OnNotSortByTurnsToComplete)
end
Initialize();
