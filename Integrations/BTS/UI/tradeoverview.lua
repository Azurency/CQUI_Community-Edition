-- ===========================================================================
--  SETTINGS
-- ===========================================================================

local alignTradeYields = true
local showNoBenefitsString = false
local showSortOrdersPermanently = false
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
local tintColorOffset = 80
local tintColorOpacity = 205

-- ===========================================================================
--  INCLUDES
-- ===========================================================================

include("AnimSidePanelSupport");
include("PopupDialogSupport");
include("InstanceManager");
include("SupportFunctions");
include("TradeSupport");

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
};

local SORT_BY_ID:table = GetSortByIdConstants();
local SORT_ASCENDING = GetSortAscendingIdConstant();
local SORT_DESCENDING = GetSortDescendingIdConstant();

local SEMI_EXPAND_SETTINGS:table = {};
SEMI_EXPAND_SETTINGS[GROUP_BY_SETTINGS.ORIGIN] = 4;
SEMI_EXPAND_SETTINGS[GROUP_BY_SETTINGS.DESTINATION] = 2;

-- ===========================================================================
--  VARIABLES
-- ===========================================================================
local m_RouteInstanceIM:table           = InstanceManager:new("RouteInstance", "Top", Controls.BodyStack);
local m_HeaderInstanceIM:table          = InstanceManager:new("HeaderInstance", "Top", Controls.BodyStack);
local m_SimpleButtonInstanceIM:table    = InstanceManager:new("SimpleButtonInstance", "Top", Controls.BodyStack);

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
local m_SortBySettings = {};
local m_GroupSortBySettings = {};

local preRefreshClock = 0;

-- ===========================================================================
--  Refresh functions
-- ===========================================================================

-- Finds and adds all possible trade routes
function RebuildAvailableTradeRoutesTable()
    print ("Rebuilding Trade Routes table");

    local preRefreshClock = os.clock();

    m_AvailableTradeRoutes = {};

    local sourcePlayerID = Game.GetLocalPlayer();
    local sourceCities:table = Players[sourcePlayerID]:GetCities();
    local players:table = Game:GetPlayers();
    local tradeManager:table = Game.GetTradeManager();

    for _, sourceCity in sourceCities:Members() do
        local sourceCityID:number = sourceCity:GetID();
        for _, destinationPlayer in ipairs(players) do
            local destinationPlayerID:number = destinationPlayer:GetID()
            -- Check for war, met, etc
            if CanPossiblyTradeWithPlayer(sourcePlayerID, destinationPlayerID) then
                local destinationCities:table = destinationPlayer:GetCities();
                for _, destinationCity in destinationCities:Members() do
                    local destinationCityID:number = destinationCity:GetID();
                    -- Can we trade with this city / civ
                    if tradeManager:CanStartRoute(sourcePlayerID, sourceCityID, destinationPlayerID, destinationCityID) then
                        -- Create the trade route entry
                        local tradeRoute = {
                            OriginCityPlayer        = sourcePlayerID,
                            OriginCityID            = sourceCityID,
                            DestinationCityPlayer   = destinationPlayerID,
                            DestinationCityID       = destinationCityID
                        };

                        m_AvailableTradeRoutes[#m_AvailableTradeRoutes + 1] = tradeRoute;
                    end
                end
            end
        end
    end
    print("Total routes = " .. #m_AvailableTradeRoutes)

    m_HasBuiltTradeRouteTable = true;
    m_LastTurnBuiltTradeRouteTable = Game.GetCurrentGameTurn();
end

function RebuildAvailableTraders()
    print("Building available traders")
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
                if m_AvailableTraders[cityID] == nil then m_AvailableTraders[cityID] = {} end

                -- Append unit into the entry
                table.insert(m_AvailableTraders[cityID], unitID)
            end
        end
    end

    m_TurnUpdatedTraders = Game.GetCurrentGameTurn()
end

function Refresh()
    preRefreshClock = os.clock();
    print("Refresh start")
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

    print("Time taken to refresh: " .. (os.clock() - preRefreshClock) .. " secs");
end

function PreRefresh()
    -- Reset Stack
    m_RouteInstanceIM:ResetInstances();
    m_HeaderInstanceIM:ResetInstances();
    m_SimpleButtonInstanceIM:ResetInstances();
end

function PostRefresh()
    -- Calculate Stack Sizess
    Controls.HeaderStack:CalculateSize();
    Controls.HeaderStack:ReprocessAnchoring();
    Controls.BodyScrollPanel:CalculateSize();
    Controls.BodyScrollPanel:ReprocessAnchoring();
    Controls.BodyScrollPanel:CalculateInternalSize();
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
    Controls.HeaderLabel:SetText(Locale.ToUpper("LOC_TRADE_OVERVIEW_MY_ROUTES"));
    Controls.ActiveRoutesLabel:SetHide(false);

    -- If our active routes exceed our route capacity then color active route number red
    local routesActiveText:string = ""
    if routesActive > routesCapacity then
        routesActiveText = "[COLOR_RED]" .. tostring(routesActive) .. "[ENDCOLOR]";
    else
        routesActiveText = tostring(routesActive);
    end
    Controls.ActiveRoutesLabel:SetText(Locale.Lookup("LOC_TRADE_OVERVIEW_ACTIVE_ROUTES", routesActiveText, routesCapacity));

    local localPlayerRunningRoutes:table = GetLocalPlayerRunningRoutes();

    -- Gather data and apply filter
    local routesSortedByPlayer:table = {};
    for i,route in ipairs(localPlayerRunningRoutes) do
        if m_filterList[m_filterSelected].FilterFunction and m_filterList[m_filterSelected].FilterFunction(Players[route.DestinationCityPlayer]) then
            -- Make sure we have a table for each destination player
            if routesSortedByPlayer[route.DestinationCityPlayer] == nil then
                routesSortedByPlayer[route.DestinationCityPlayer] = {};
            end

            table.insert(routesSortedByPlayer[route.DestinationCityPlayer], route);
        end
    end

    -- Add routes to local player cities
    if routesSortedByPlayer[localPlayerID] ~= nil then
        CreatePlayerHeader(Players[localPlayerID]);

        SortTradeRoutes(routesSortedByPlayer[localPlayerID], m_GroupSortBySettings);

        for i,route in ipairs(routesSortedByPlayer[localPlayerID]) do
            AddRouteInstanceFromRouteInfo(route);
        end
    end

    -- Add routes to other civs
    local haveAddedCityStateHeader:boolean = false;
    for playerID,routes in pairs(routesSortedByPlayer) do
        if playerID ~= localPlayerID then
            SortTradeRoutes(routes, m_GroupSortBySettings);

            -- Skip City States as these are added below
            local playerInfluence:table = Players[playerID]:GetInfluence();
            if not playerInfluence:CanReceiveInfluence() then
                CreatePlayerHeader(Players[playerID]);

                for i,route in ipairs(routes) do
                    AddRouteInstanceFromRouteInfo(route);
                end
            else
                -- Add city state routes
                if not haveAddedCityStateHeader then
                    haveAddedCityStateHeader = true;
                    CreateCityStateHeader();
                end

                for i,route in ipairs(routes) do
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
        for i=1,unusedRoutes,1 do
            if #idleTradeUnits > 0 then
                -- Add button to choose a route for this trader
                AddChooseRouteButtonInstance(idleTradeUnits[1]);
                table.remove(idleTradeUnits, 1);
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
    Controls.HeaderLabel:SetText(Locale.ToUpper("LOC_TRADE_OVERVIEW_ROUTES_TO_MY_CITIES"));
    Controls.ActiveRoutesLabel:SetHide(true);

    -- Gather data
    local routesSortedByPlayer:table = {};
    local players = Game.GetPlayers();
    for i, player in ipairs(players) do
        if m_filterList[m_filterSelected].FilterFunction and m_filterList[m_filterSelected].FilterFunction(player) then
            local playerCities:table = player:GetCities();
            for i,city in playerCities:Members() do
                local outgoingRoutes = city:GetTrade():GetOutgoingRoutes();
                for i,route in ipairs(outgoingRoutes) do
                    -- Check that the destination city owner is the local palyer
                    local isDestinationOwnedByLocalPlayer:boolean = false;
                    if route.DestinationCityPlayer == Game.GetLocalPlayer() then
                        isDestinationOwnedByLocalPlayer = true;
                    end

                    if isDestinationOwnedByLocalPlayer then
                        -- Make sure we have a table for each destination player
                        if routesSortedByPlayer[route.OriginCityPlayer] == nil then
                            local routes:table = {};
                            routesSortedByPlayer[route.OriginCityPlayer] = {};
                        end

                        table.insert(routesSortedByPlayer[route.OriginCityPlayer], route);
                    end
                end
            end
        end
    end

    -- Add routes to stack
    for playerID,routes in pairs(routesSortedByPlayer) do
        CreatePlayerHeader(Players[playerID]);

        -- Sort the routes
        SortTradeRoutes(routes, m_GroupSortBySettings);

        for i,route in ipairs(routes) do
            AddRouteInstanceFromRouteInfo(route);
        end
    end
end

-- Show Available Routes Tab
function ViewAvailableRoutes()

    -- Update Tabs
    SetMyRoutesTabSelected(false);
    SetRoutesToCitiesTabSelected(false);
    SetAvailableRoutesTabSelected(true);

    local localPlayerID = Game.GetLocalPlayer();
    if (localPlayerID == -1) then
        return;
    end

    -- Update Header
    Controls.HeaderLabel:SetText(Locale.ToUpper("LOC_TRADE_OVERVIEW_AVAILABLE_ROUTES"));
    Controls.ActiveRoutesLabel:SetHide(true);

    -- Dont rebuild if the turn has not advanced
    if (not m_HasBuiltTradeRouteTable) or Game.GetCurrentGameTurn() > m_LastTurnBuiltTradeRouteTable then
        RebuildAvailableTradeRoutesTable();
        print("Time taken to build routes: " .. (os.clock()- preRefreshClock) .. " sec(s)");

        -- Cache routes info.
        CacheEmpty();
        if CacheRoutesInfo(m_AvailableTradeRoutes) then
            print("Time taken till cache: " .. (os.clock() - preRefreshClock) .. " sec(s)")
        end

        -- Just rebuilt base routes table. need to do everything again
        m_SortSettingsChanged = true;
        m_FilterSettingsChanged = true;
        m_GroupSettingsChanged = true;
    else
        print("Trade Route table last built on: " .. m_LastTurnBuiltTradeRouteTable .. ". Current game turn: " .. Game.GetCurrentGameTurn());
        print("OPT: Not Rebuilding or recaching routes table")
    end

    -- Filter the routes
    if m_FilterSettingsChanged then
        m_FinalTradeRoutes = FilterTradeRoutes(m_AvailableTradeRoutes);
        print("Time taken till filter: " .. (os.clock() - preRefreshClock) .. " sec(s)")

        -- Need to regroup routes
        m_GroupSettingsChanged = true
    else
        print("OPT: Not refiltering routes")
    end

    -- Sort and display the routes
    if m_groupByList[m_groupBySelected].groupByID ~= GROUP_BY_SETTINGS.NONE then
        -- Group routes. Use the filtered list of routes
        if m_GroupSettingsChanged then
            -- Group from the filtered routes
            m_AvailableGroupedRoutes = GroupRoutes(m_FinalTradeRoutes, m_groupByList[m_groupBySelected].groupByID)
            print("Time taken till group: " .. (os.clock() - preRefreshClock) .. " sec(s)")

            -- Need to resort
            m_SortSettingsChanged = true
        else
            print("OPT: Not regrouping routes")
        end

        -- Sort within each group, and then sort groups
        if m_SortSettingsChanged then
            -- Sort within each group
            for i=1, #m_AvailableGroupedRoutes do
                SortTradeRoutes(m_AvailableGroupedRoutes[i], m_SortBySettings)
            end
            print("Time taken till within group sort: " .. (os.clock() - preRefreshClock) .. " sec(s)")

            -- Sort the order of groups. You need to do this AFTER each group has been sorted
            SortGroupedRoutes(m_AvailableGroupedRoutes, m_GroupSortBySettings);
            print("Time taken till group sort: " .. (os.clock()- preRefreshClock) .. " sec(s)");
        else
            print("OPT: Not resorting within and of groups")
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
                SortTradeRoutes(m_FinalTradeRoutes, m_GroupSortBySettings);
                print("Time taken till sort: " .. (os.clock() - preRefreshClock) .. " sec(s)")
            else
                print("OPT: Not resorting routes")
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

        -- print(Locale.Lookup(city:GetName()) .. ": " .. groupExpandIndex .. " " .. groupCollapseIndex )
        if (groupExpandIndex > 0) then
            CreateCityHeader(city, routeCount, routeCount, "");
            AddRouteInstancesFromTable(routesTable);
        elseif (groupCollapseIndex > 0) then
            CreateCityHeader(city, 0, routeCount, GetCityHeaderTooltipString(routesTable[1]));
            AddRouteInstancesFromTable(routesTable, 0);
        else
            if m_GroupExpandAll then
                -- If showing all, add city to expand list, and display all
                table.insert(m_GroupsFullyExpanded, cityEntry);
                CreateCityHeader(city, routeCount, routeCount, "");
                AddRouteInstancesFromTable(routesTable);
            elseif m_GroupCollapseAll then
                -- If hiding all, add city to collapse list, and hide it
                table.insert(m_GroupsFullyCollapsed, cityEntry);
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
    Controls.MyRoutesSelectedArrow:SetHide(not isSelected);
    Controls.MyRoutesTabSelectedLabel:SetHide(not isSelected);
end

function SetRoutesToCitiesTabSelected( isSelected:boolean )
    Controls.RoutesToCitiesButton:SetSelected(isSelected);
    Controls.RoutesToCitiesTabLabel:SetHide(isSelected);
    Controls.RoutesToCitiesSelectedArrow:SetHide(not isSelected);
    Controls.RoutesToCitiesTabSelectedLabel:SetHide(not isSelected);
end

function SetAvailableRoutesTabSelected( isSelected:boolean )
    Controls.AvailableRoutesButton:SetSelected(isSelected);
    Controls.AvailableRoutesTabLabel:SetHide(isSelected);
    Controls.AvailableRoutesSelectedArrow:SetHide(not isSelected);
    Controls.AvailableRoutesTabSelectedLabel:SetHide(not isSelected);
end

function GetCityHeaderTooltipString( routeInfo:table )
    return "Top Route: " .. GetTradeRouteString(routeInfo) .. "[NEWLINE]" .. Locale.Lookup("LOC_TRADE_TURNS_REMAINING_TOOLTIP_BREAKER")
                .. "[NEWLINE]" .. GetTradeRouteYieldString(routeInfo);
end

-- ===========================================================================
--  Route Instance Creators
-- ===========================================================================

function AddChooseRouteButtonInstance( tradeUnit:table )
    local simpleButtonInstance:table = m_SimpleButtonInstanceIM:GetInstance();
    simpleButtonInstance.GridButton:SetText(Locale.Lookup("LOC_TRADE_OVERVIEW_CHOOSE_ROUTE"));
    simpleButtonInstance.GridButton:RegisterCallback( Mouse.eLClick,
        function()
            SelectUnit( tradeUnit );
        end
    );
end

function AddProduceTradeUnitButtonInstance()
    local simpleButtonInstance:table = m_SimpleButtonInstanceIM:GetInstance();
    simpleButtonInstance.GridButton:SetText(Locale.Lookup("LOC_TRADE_OVERVIEW_PRODUCE_TRADE_UNIT"));
    simpleButtonInstance.GridButton:SetDisabled(true);
end

function AddRouteInstancesFromTable( tradeRoutes:table, showCount:number )
    if showCount then
        local len = math.min(showCount, #tradeRoutes)
        for i=1, len do
            AddRouteInstanceFromRouteInfo(tradeRoutes[i]);
        end
    else
        for i=1, #tradeRoutes do
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
    routeInstance.GridButton:SetColor(tintBackColor);
    routeInstance.TurnsToComplete:SetColor(destinationFrontColor);
    routeInstance.BannerBase:SetColor(destinationBackColor);
    routeInstance.BannerDarker:SetColor(darkerBackColor);
    routeInstance.BannerLighter:SetColor(brighterBackColor);
    routeInstance.RouteLabel:SetColor(destinationFrontColor);

    -- Update Route Label
    routeInstance.RouteLabel:SetText(Locale.ToUpper(originCity:GetName()) .. " " .. Locale.ToUpper("LOC_TRADE_OVERVIEW_TO") .. " " .. Locale.ToUpper(destinationCity:GetName()));

    -- Update yield directional arrows
    routeInstance.OriginCivArrow:SetColor(originFrontColor);
    routeInstance.DestinationCivArrow:SetColor(destinationFrontColor);

    routeInstance.ResourceStack:DestroyAllChildren();

    local originYieldInstance:table = {};
    local destinationYieldInstance:table = {};
    ContextPtr:BuildInstanceForControl( "RouteYieldInstance", originYieldInstance, routeInstance.ResourceStack );
    ContextPtr:BuildInstanceForControl( "RouteYieldInstance", destinationYieldInstance, routeInstance.ResourceStack );

    for yieldInfo in GameInfo.Yields() do
        local originCityYieldValue = GetYieldForOriginCity(yieldInfo.Index, routeInfo, true);
        local destinationCityYieldValue = GetYieldForDestinationCity(yieldInfo.Index, routeInfo, true);

        SetRouteInstanceYields(originYieldInstance, yieldInfo, originCityYieldValue);
        SetRouteInstanceYields(destinationYieldInstance, yieldInfo, destinationCityYieldValue);
    end

    routeInstance.ResourceStack:CalculateSize();

    -- Update City State Quest Icon
    routeInstance.CityStateQuestIcon:SetHide(true);
    local questTooltip  : string = Locale.Lookup("LOC_CITY_STATES_QUESTS");
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
        local baseTourismModifier = GlobalParameters.TOURISM_TRADE_ROUTE_BONUS;
        local extraTourismModifier = originPlayer:GetCulture():GetExtraTradeRouteTourismModifier();

        -- TODO: Use LOC_TRADE_OVERVIEW_TOURISM_BONUS when we can update the text
        routeInstance.TourismBonusPercentage:SetText("+" .. Locale.ToPercent((baseTourismModifier + extraTourismModifier)/100));

        if hasTradeRoute then
            routeInstance.TourismBonusPercentage:SetColorByName("TradeOverviewTextCS");
            routeInstance.TourismBonusIcon:SetTexture(0,0,"Tourism_VisitingSmall");
            routeInstance.TourismBonusGrid:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_TOURISM_BONUS");

            routeInstance.VisibilityBonusIcon:SetTexture("Diplomacy_VisibilityIcons");
            routeInstance.VisibilityBonusIcon:SetVisState(math.min(math.max(visibilityIndex - 1, 0), 3));
            routeInstance.VisibilityBonusGrid:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_DIPLOMATIC_VIS_BONUS");
        else
            routeInstance.TourismBonusPercentage:SetColorByName("TradeOverviewTextDisabledCS");
            routeInstance.TourismBonusIcon:SetTexture(0,0,"Tourism_VisitingSmallGrey");
            routeInstance.TourismBonusGrid:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_NO_TOURISM_BONUS");

            routeInstance.VisibilityBonusIcon:SetTexture("Diplomacy_VisibilityIconsGrey");
            routeInstance.VisibilityBonusIcon:SetVisState(math.min(math.max(visibilityIndex, 0), 3));
            routeInstance.VisibilityBonusGrid:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_NO_DIPLOMATIC_VIS_BONUS");
        end
    end

    -- Update Trading Post Icon
    if m_groupBySelected == GROUP_BY_SETTINGS.NONE or m_groupBySelected == GROUP_BY_SETTINGS.ORIGIN then
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
        tooltipString = (   Locale.Lookup("LOC_TRADE_TURNS_REMAINING_ALT_HELP_TOOLTIP", routeInfo.TurnsRemaining) .. "[NEWLINE]" ..
                            Locale.Lookup("LOC_TRADE_TURNS_REMAINING_TOOLTIP_BREAKER") .. "[NEWLINE]" ..
                            Locale.Lookup("LOC_TRADE_TURNS_REMAINING_ROUTE_LENGTH_TOOLTIP", tradePathLength) .. "[NEWLINE]" ..
                            Locale.Lookup("LOC_TRADE_TURNS_REMAINING_TRIPS_COUNT_TOOLTIP", tripsToDestination) .. "[NEWLINE]" ..
                            Locale.Lookup("LOC_TRADE_TURNS_REMAINING_TURN_COMPLETION_TOOLTIP", (Game.GetCurrentGameTurn() + routeInfo.TurnsRemaining)) );
    elseif m_currentTab == TRADE_TABS.ROUTES_TO_CITIES then
        routeInstance.TurnsToComplete:SetText(turnsToCompleteRoute);
        tooltipString = (   Locale.Lookup("LOC_TRADE_TURNS_REMAINING_HELP_TOOLTIP") .. "[NEWLINE]" ..
                            Locale.Lookup("LOC_TRADE_TURNS_REMAINING_TOOLTIP_BREAKER") .. "[NEWLINE]" ..
                            Locale.Lookup("LOC_TRADE_TURNS_REMAINING_ROUTE_LENGTH_TOOLTIP", tradePathLength) .. "[NEWLINE]" ..
                            Locale.Lookup("LOC_TRADE_TURNS_REMAINING_TRIPS_COUNT_TOOLTIP", tripsToDestination) );
    else
        routeInstance.TurnsToComplete:SetText(turnsToCompleteRoute);
        tooltipString = (   Locale.Lookup("LOC_TRADE_TURNS_REMAINING_HELP_TOOLTIP") .. "[NEWLINE]" ..
                            Locale.Lookup("LOC_TRADE_TURNS_REMAINING_TOOLTIP_BREAKER") .. "[NEWLINE]" ..
                            Locale.Lookup("LOC_TRADE_TURNS_REMAINING_ROUTE_LENGTH_TOOLTIP", tradePathLength) .. "[NEWLINE]" ..
                            Locale.Lookup("LOC_TRADE_TURNS_REMAINING_TRIPS_COUNT_TOOLTIP", tripsToDestination) .. "[NEWLINE]" ..
                            Locale.Lookup("LOC_TRADE_TURNS_REMAINING_TURN_COMPLETION_ALT_TOOLTIP", turnsToCompleteRoute, (Game.GetCurrentGameTurn() + turnsToCompleteRoute)) );
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

    -- Hide the cancel automation button
    routeInstance.CancelAutomation:SetHide(true);

    -- Should we display the cancel automation?
    if m_currentTab == TRADE_TABS.MY_ROUTES and routeInfo.TraderUnitID ~= nil then
        if IsTraderAutomated(routeInfo.TraderUnitID) then
            -- Unhide the cancel automation
            routeInstance.CancelAutomation:SetHide(false);
            -- Add button callback
            routeInstance.CancelAutomation:RegisterCallback( Mouse.eLClick,
                function()
                    CancelAutomatedTrader(routeInfo.TraderUnitID);
                    Refresh();
                end
            );
        end
    end

    local tradeUnit:table = originPlayer:GetUnits():FindID(routeInfo.TraderUnitID);
    if routeInfo.TraderUnitID then
        routeInstance.GridButton:RegisterCallback( Mouse.eLClick,
            function()
                SelectUnit(tradeUnit);
            end
        );
    -- Add button hookups for only this tab
    elseif m_currentTab == TRADE_TABS.AVAILABLE_ROUTES then
        -- Check if we have free traders
        if m_AvailableTraders[routeInfo.OriginCityID] ~= nil and table.count(m_AvailableTraders[routeInfo.OriginCityID]) > 0 then
            -- Get first trader
            local traderID = m_AvailableTraders[routeInfo.OriginCityID][1]
            local tradeUnit:table = originPlayer:GetUnits():FindID(traderID);
            routeInstance.GridButton:RegisterCallback( Mouse.eLClick,
                function()
                    SelectFreeTrader(tradeUnit, routeInfo.DestinationCityPlayer, routeInfo.DestinationCityID);
                end
            );
        else -- Cycle through all traders
          if tradeUnit then
            local co = coroutine.create(
                function()
                    while true do -- Infinitely cycle
                        for cityID in pairs(m_AvailableTraders) do
                            for i in pairs(m_AvailableTraders[cityID]) do
                                local traderID = m_AvailableTraders[cityID][i]
                                local tradeUnit:table = originPlayer:GetUnits():FindID(traderID);
                                TransferTraderTo(tradeUnit, originCity)
                                coroutine.yield()
                            end
                        end
                    end
                end
            );

            routeInstance.GridButton:RegisterCallback( Mouse.eLClick,
                function()
                    CycleTraders(co)
                end
            );
          end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Route button helpers
-- ---------------------------------------------------------------------------

function SetRouteInstanceYields(yieldsInstance, yieldInfo, yieldValue)
    local iconString, text = FormatYieldText(yieldInfo, yieldValue);
    if yieldValue == 0 then
        iconString = "";
        text = "";
    end

    if (yieldInfo.YieldType == "YIELD_FOOD") then
        yieldsInstance.YieldFoodLabel:SetText(text .. iconString);
    elseif (yieldInfo.YieldType == "YIELD_PRODUCTION") then
        yieldsInstance.YieldProductionLabel:SetText(text .. iconString);
    elseif (yieldInfo.YieldType == "YIELD_GOLD") then
        yieldsInstance.YieldGoldLabel:SetText(text .. iconString);
    elseif (yieldInfo.YieldType == "YIELD_SCIENCE") then
        yieldsInstance.YieldScienceLabel:SetText(text .. iconString);
    elseif (yieldInfo.YieldType == "YIELD_CULTURE") then
        yieldsInstance.YieldCultureLabel:SetText(text .. iconString);
    elseif (yieldInfo.YieldType == "YIELD_FAITH") then
        yieldsInstance.YieldFaithLabel:SetText(text .. iconString);
    end
end

-- ===========================================================================
--  Header Instance Creators
-- ===========================================================================

function CreatePlayerHeader( player:table )
    local headerInstance:table = m_HeaderInstanceIM:GetInstance();
    local playerID = player:GetID()
    local pPlayerConfig:table = PlayerConfigurations[playerID];
    headerInstance.HeaderLabel:SetText(Locale.ToUpper(pPlayerConfig:GetPlayerName()));

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
        local baseTourismModifier = GlobalParameters.TOURISM_TRADE_ROUTE_BONUS;
        local extraTourismModifier = Players[Game.GetLocalPlayer()]:GetCulture():GetExtraTradeRouteTourismModifier();
        -- TODO: Use LOC_TRADE_OVERVIEW_TOURISM_BONUS when we can update the text
        headerInstance.TourismBonusPercentage:SetText("+" .. Locale.ToPercent((baseTourismModifier + extraTourismModifier)/100));

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
    headerInstance.HeaderLabel:SetText(Locale.ToUpper("LOC_TRADE_OVERVIEW_CITY_STATES"));

    headerInstance.VisibilityBonusGrid:SetHide(true);
    headerInstance.TourismBonusGrid:SetHide(true);
end

function CreateUnusedRoutesHeader()
    local headerInstance:table = m_HeaderInstanceIM:GetInstance();

    headerInstance.HeaderLabel:SetText(Locale.ToUpper("LOC_TRADE_OVERVIEW_UNUSED_ROUTES"));

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
    local headerInstance:table = m_HeaderInstanceIM:GetInstance();
    local playerID:number = city:GetOwner();
    local pPlayer = Players[playerID];

    headerInstance.HeaderLabel:SetText(Locale.ToUpper(city:GetName()));

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
            local baseTourismModifier = GlobalParameters.TOURISM_TRADE_ROUTE_BONUS;
            local extraTourismModifier = Players[Game.GetLocalPlayer()]:GetCulture():GetExtraTradeRouteTourismModifier();

            -- TODO: Use LOC_TRADE_OVERVIEW_TOURISM_BONUS when we can update the text
            headerInstance.TourismBonusPercentage:SetText("+" .. Locale.ToPercent((baseTourismModifier + extraTourismModifier)/100));

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


    headerInstance.RoutesExpand:RegisterCallback( Mouse.eLClick, function() OnExpandRoutes(headerInstance.RoutesExpand, city:GetOwner(), city:GetID()); end );
    headerInstance.RoutesExpand:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
    headerInstance.RoutesExpand:RegisterCallback( Mouse.eRClick, function() OnCollapseRoutes(headerInstance.RoutesExpand, city:GetOwner(), city:GetID()); end );
    headerInstance.RoutesExpand:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

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
            print("Adding " .. GetCityEntryString(cityEntry) .. " to the exclusion list");
            table.insert(m_GroupsFullyExpanded, cityEntry);
        else
            print("City already exists in exclusion list");
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
            print("Removing " .. GetCityEntryString(cityEntry) .. " to the exclusion list");
            table.remove(m_GroupsFullyExpanded, cityIndex);
        else
            print("City does not exist in exclusion list");
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
        table.remove(m_GroupsFullyExpanded, cityIndex);
    end

    -- Add city to Groups collapsed list, if it does not exist
    cityIndex = findIndex(m_GroupsFullyCollapsed, cityEntry, CompareCityEntries)
    if cityIndex == -1 then
        table.insert(m_GroupsFullyCollapsed, cityEntry);
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

    return Locale.Lookup(pCity:GetName());
end

-- ===========================================================================
--  Trade Route Tracker
-- ===========================================================================
-- ---------------------------------------------------------------------------
-- Trader Route history tracker
-- ---------------------------------------------------------------------------
function UpdateRouteHistoryForTrader(routeInfo:table, routesTable:table)
    if routeInfo.TraderUnitID ~= nil then
        print("Updating trader " .. routeInfo.TraderUnitID .. " with route history: " .. GetTradeRouteString(routeInfo));
        routesTable[routeInfo.TraderUnitID] = routeInfo;
    else
        print("Could not find the trader unit")
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
    AddGroupByEntry(Locale.Lookup("LOC_CITY_STATES_NONE"), GROUP_BY_SETTINGS.NONE);
    AddGroupByEntry(Locale.Lookup("LOC_TRADE_OVERVIEW_ORIGIN"), GROUP_BY_SETTINGS.ORIGIN);
    AddGroupByEntry(Locale.Lookup("LOC_TRADE_OVERVIEW_DESTINATION"), GROUP_BY_SETTINGS.DESTINATION);

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

    table.insert(m_groupByList, entry);

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

    for index, tradeRoute in ipairs(tradeRoutes) do
        local pPlayer = Players[tradeRoute.DestinationCityPlayer];
        if m_filterList[m_filterSelected].FilterFunction and m_filterList[m_filterSelected].FilterFunction(pPlayer) then
            table.insert(filtertedRoutes, tradeRoute);
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
    AddFilter(Locale.Lookup("LOC_ROUTECHOOSER_FILTER_ALL"), function(a) return true; end);

    -- Add "International Routes" Filter
    AddFilter(Locale.Lookup("LOC_TRADE_FILTER_INTERNATIONAL_ROUTES_TEXT") , IsOtherCiv);

    -- Add "City States with Trade Quest" Filter
    AddFilter(Locale.Lookup("LOC_TRADE_FILTER_CS_WITH_QUEST_TOOLTIP"), IsCityStateWithTradeQuest);

    -- Add Local Player Filter
    local localPlayerConfig:table = PlayerConfigurations[Game.GetLocalPlayer()];
    local localPlayerName = Locale.Lookup(GameInfo.Civilizations[localPlayerConfig:GetCivilizationTypeID()].Name);
    AddFilter(localPlayerName, function(a) return a:GetID() == Game.GetLocalPlayer(); end);

    -- Add Filters by Civ
    local players:table = Game.GetPlayers();
    for index, pPlayer in ipairs(players) do
        if pPlayer and pPlayer:IsAlive() and pPlayer:IsMajor() then

            -- Has the local player met the civ?
            if pPlayer:GetDiplomacy():HasMet(Game.GetLocalPlayer()) then
                local playerConfig:table = PlayerConfigurations[pPlayer:GetID()];
                local name = Locale.Lookup(GameInfo.Civilizations[playerConfig:GetCivilizationTypeID()].Name);
                AddFilter(name, function(a) return a:GetID() == pPlayer:GetID() end);
            end
        end
    end

    -- Add "City States" Filter
    AddFilter(Locale.Lookup("LOC_HUD_REPORTS_CITY_STATE"), IsCityState);

    -- Add filters to pulldown
    for index, filter in ipairs(m_filterList) do
        AddFilterEntry(index);
    end

    -- Select first filter
    Controls.OverviewFilterButton:SetText(m_filterList[m_filterSelected].FilterText);

    -- Calculate Internals
    Controls.OverviewDestinationFilterPulldown:CalculateInternals();

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
    print("Group setting: " .. m_groupByList[m_groupBySelected].groupByString);

    if groupSetting == GROUP_BY_SETTINGS.NONE then return routesTable end

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
        print("OPT: Not sorting groups")
        return
    end

    if #sortSettings > 0 then
        table.sort(groupedRoutes, CompareGroups)
    end
end

-- Compares the first route of passed groups
function CompareGroups( groupedRoutes1:table, groupedRoutes2:table )
    if groupedRoutes1 == nil or groupedRoutes2 == nil then
        -- print("Error: Passed group was nil");
        return false;
    end

    return CompleteCompareBy(groupedRoutes1[1], groupedRoutes2[1], m_GroupSortBySettings);
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
        RefreshSortButtons( m_SortBySettings );
    else
        RefreshSortButtons( m_GroupSortBySettings );
    end

    if showSortOrdersPermanently or m_shiftDown then
        -- Hide the order texts
        HideSortOrderLabels();
        -- Show them based on current settings
        ShowSortOrderLabels();
    end
end

function ShowSortOrderLabels()
    -- Refresh and show sort orders
    if m_ctrlDown then
        RefreshSortOrderLabels( m_SortBySettings );
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
    m_SortBySettings = {};
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
    if UI.GetHeadSelectedUnit() ~= unit and localPlayer ~= -1 and localPlayer == unit:GetOwner() then
        UI.DeselectAllUnits();
        UI.DeselectAllCities();
        UI.SelectUnit( unit );
        LuaEvents.TradeOverview_SelectRouteFromOverview(destinationCityOwnerID, destinationCityID)
    elseif localPlayer ~= -1 and localPlayer == unit:GetOwner() then
        -- The unit is already selected, call open panel
        LuaEvents.TradeOverview_SelectRouteFromOverview(destinationCityOwnerID, destinationCityID)
    end
    UI.LookAtPlotScreenPosition( unit:GetX(), unit:GetY(), 0.42, 0.5 );
end

function CycleTraders(co)
    coroutine.resume(co)
end

function TransferTraderTo( unit:table, transferCity:table )
    SelectUnit(unit)
    LuaEvents.TradeOverview_ChangeOriginCityFromOverview(transferCity)
end

function RemoveTrader( traderID )
    for cityID in pairs(m_AvailableTraders) do
        for i in pairs(m_AvailableTraders[cityID]) do
            -- Remove trader
            if m_AvailableTraders[cityID][i] == traderID then
                print("Removing trader " .. traderID .. " from available traders.")
                table.remove(m_AvailableTraders[cityID], i)

                -- Check if for that city no traders exist
                if table.count(m_AvailableTraders[cityID]) <= 0 then
                    table.remove(m_AvailableTraders, cityID)
                end

                return -- return here since nothing else is left to do
            end
        end
    end

    print("Could not find trader " .. traderID)
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
    if m_groupBySelected == GROUP_BY_SETTINGS.NONE then
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
    if m_groupBySelected == GROUP_BY_SETTINGS.NONE then
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

function OnGeneralSortBy(sortDescArrow, sortByID)
    m_SortSettingsChanged = true;
    -- If shift is not being pressed, reset sort settings
    if not m_shiftDown then
        if not m_ctrlDown then
            m_GroupSortBySettings = {};
        end
        m_SortBySettings = {};
    end

    RemoveSortEntry(SORT_BY_ID.TURNS_TO_COMPLETE, m_SortBySettings);

    -- Sort based on currently showing icon toggled
    if sortDescArrow:IsHidden() then
        if not m_ctrlDown then
            InsertSortEntry(sortByID, SORT_DESCENDING, m_GroupSortBySettings);
        end
        InsertSortEntry(sortByID, SORT_DESCENDING, m_SortBySettings);
    else
        if not m_ctrlDown then
            InsertSortEntry(sortByID, SORT_ASCENDING, m_GroupSortBySettings);
        end
        InsertSortEntry(sortByID, SORT_ASCENDING, m_SortBySettings);
    end

    InsertSortEntry(SORT_BY_ID.TURNS_TO_COMPLETE, SORT_ASCENDING, m_SortBySettings);

    RefreshSortBar();
    -- Dont call refresh while shift is held
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

function OnGeneralNotSortBy(sortByID)
    m_SortSettingsChanged = true;
    if not m_ctrlDown then
        RemoveSortEntry( sortByID, m_GroupSortBySettings);
    end
    RemoveSortEntry( sortByID, m_SortBySettings);

    RefreshSortBar();
    -- Dont call refresh while shift is held
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

        if ownerID == Game.GetLocalPlayer() and operationID == UnitOperationTypes.MAKE_TRADE_ROUTE then
            -- Unit was just started a trade route. Find the route, and update the tables
            local localPlayerCities:table = Players[ownerID]:GetCities();
            for i,city in localPlayerCities:Members() do
                local outgoingRoutes = city:GetTrade():GetOutgoingRoutes();
                for j,route in ipairs(outgoingRoutes) do
                    if route.TraderUnitID == unitID then
                        -- Remove it from the available routes
                        if m_groupByList[m_groupBySelected].groupByID ~= GROUP_BY_SETTINGS.NONE then
                            RemoveRouteFromTable(route, m_AvailableGroupedRoutes, true);
                        else
                            RemoveRouteFromTable(route, m_AvailableTradeRoutes, false);
                        end
                    end
                end
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

function Initialize()
    print("Initializing BTS Trade Overview");

    -- Initialize tracker
    TradeSupportTracker_Initialize();

    -- Input handler
    ContextPtr:SetInputHandler( OnInputHandler, true );

    -- Control Events
    Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);
    Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
    Controls.MyRoutesButton:RegisterCallback(Mouse.eLClick,         OnMyRoutesButton);
    Controls.MyRoutesButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
    Controls.RoutesToCitiesButton:RegisterCallback(Mouse.eLClick,   OnRoutesToCitiesButton);
    Controls.RoutesToCitiesButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
    Controls.AvailableRoutesButton:RegisterCallback(Mouse.eLClick,  OnAvailableRoutesButton);
    Controls.AvailableRoutesButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
    -- Control events - sort bar
    Controls.FoodSortButton:RegisterCallback( Mouse.eLClick, OnSortByFood);
    Controls.FoodSortButton:RegisterCallback( Mouse.eRClick, OnNotSortByFood);
    Controls.FoodSortButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

    Controls.ProductionSortButton:RegisterCallback( Mouse.eLClick, OnSortByProduction);
    Controls.ProductionSortButton:RegisterCallback( Mouse.eRClick, OnNotSortByProduction);
    Controls.ProductionSortButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

    Controls.GoldSortButton:RegisterCallback( Mouse.eLClick, OnSortByGold);
    Controls.GoldSortButton:RegisterCallback( Mouse.eRClick, OnNotSortByGold);
    Controls.GoldSortButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

    Controls.ScienceSortButton:RegisterCallback( Mouse.eLClick, OnSortByScience);
    Controls.ScienceSortButton:RegisterCallback( Mouse.eRClick, OnNotSortByScience);
    Controls.ScienceSortButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

    Controls.CultureSortButton:RegisterCallback( Mouse.eLClick, OnSortByCulture);
    Controls.CultureSortButton:RegisterCallback( Mouse.eRClick, OnNotSortByCulture);
    Controls.CultureSortButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

    Controls.FaithSortButton:RegisterCallback( Mouse.eLClick, OnSortByFaith);
    Controls.FaithSortButton:RegisterCallback( Mouse.eRClick, OnNotSortByFaith);
    Controls.FaithSortButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

    Controls.TurnsToCompleteSortButton:RegisterCallback( Mouse.eLClick, OnSortByTurnsToComplete);
    Controls.TurnsToCompleteSortButton:RegisterCallback( Mouse.eRClick, OnNotSortByTurnsToComplete);
    Controls.TurnsToCompleteSortButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

    --Filter Pulldown
    Controls.OverviewFilterButton:RegisterCallback( eLClick, UpdateFilterArrow );
    Controls.OverviewDestinationFilterPulldown:RegisterSelectionCallback( OnFilterSelected );
    -- Group By Pulldown
    Controls.OverviewGroupByButton:RegisterCallback( eLClick, UpdateGroupByArrow );
    Controls.OverviewGroupByPulldown:RegisterSelectionCallback( OnGroupBySelected );

    Controls.GroupExpandAllCheckBox:RegisterCallback( eLClick, OnGroupExpandAll );
    Controls.GroupExpandAllCheckBox:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

    Controls.GroupCollapseAllCheckBox:RegisterCallback( eLClick, OnGroupCollapseAll );
    Controls.GroupCollapseAllCheckBox:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

    -- Lua Events
    LuaEvents.PartialScreenHooks_OpenTradeOverview.Add( OnOpen );
    LuaEvents.PartialScreenHooks_CloseTradeOverview.Add( OnClose );
    LuaEvents.PartialScreenHooks_CloseAllExcept.Add( OnCloseAllExcept );

    -- Animation Controller
    m_AnimSupport = CreateScreenAnimation(Controls.SlideAnim);

    -- Rundown / Screen Events
    Events.SystemUpdateUI.Add(m_AnimSupport.OnUpdateUI);

    Controls.Title:SetText(Locale.Lookup("LOC_TRADE_OVERVIEW_TITLE"));

    -- Game Engine Events
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
