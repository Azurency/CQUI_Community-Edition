print("Better Trade Screen loaded")

-- ===========================================================================
--	SETTINGS
-- ===========================================================================

local alignTradeYields = true
local showNoBenefitsString = false
local showSortOrdersPermanently = false
local hideTradingPostIcon = false

-- Color Settings for Headers
local colorCityPlayerHeader = true
local backdropGridColorOffset = 20
local backdropGridColorOpacity = 140
local backdropColorOffset = -20
local backdropColorOpacity = 40
local labelColorOffset = -27
local labelColorOpacity = 255

-- Color Settings for Route Entry
local hideHeaderOpaqueBackdrop = false
local tintTradeRouteEntry = true
local tintColorOffset = 80					-- Higher for brighter, and lower for darker. Can go negative.
local tintColorOpacity = 205				-- Value ranges from 0 (transparent) to 255 (fully opaque)
local tintLabelColorOffset = 10
local tintLabelColorOpacity = 210

-- ===========================================================================
--	INCLUDES
-- ===========================================================================

include("AnimSidePanelSupport");
include("InstanceManager");
include("SupportFunctions");
include("TradeSupport");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

local RELOAD_CACHE_ID:string = "TradeOverview"; -- Must be unique (usually the same as the file name)
local OUTSIDE_SUPPORT_CACHE_ID:string = "TradeOverviewSupport";
local DATA_ICON_PREFIX:string = "ICON_";

local TRADE_TABS:table = {
	MY_ROUTES			= 0;
	ROUTES_TO_CITIES	= 1;
	AVAILABLE_ROUTES	= 2;
};

local GROUP_BY_SETTINGS:table = {
	NONE 				= 1;
	ORIGIN				= 2;
	DESTINATION			= 3;
};


local SORT_BY_ID:table = {
	FOOD = 1;
	PRODUCTION = 2;
	GOLD = 3;
	SCIENCE = 4;
	CULTURE = 5;
	FAITH = 6;
	TURNS_TO_COMPLETE = 7;
}

local SORT_ASCENDING = 1
local SORT_DESCENDING = 2

local GROUP_DESTINATION_ROUTE_SHOW_COUNT:number = 2;
local GROUP_ORIGIN_ROUTE_SHOW_COUNT:number = 4;
local GROUP_NONE_ROUTE_SHOW_COUNT:number = 100;

local m_shiftDown:boolean = false;
local m_ctrlDown:boolean = false;

-- ===========================================================================
--	VARIABLES
-- ===========================================================================

local m_RouteInstanceIM:table			= InstanceManager:new("RouteInstance", "Top", Controls.BodyStack);
local m_HeaderInstanceIM:table			= InstanceManager:new("HeaderInstance", "Top", Controls.BodyStack);
local m_SimpleButtonInstanceIM:table	= InstanceManager:new("SimpleButtonInstance", "Top", Controls.BodyStack);

local m_AnimSupport:table; -- AnimSidePanelSupport

local m_currentTab:number;

-- Stores filter list and tracks the currently selected list
local m_filterList:table = {};
local m_filterCount:number = 0;
local m_filterSelected:number = 1;

local m_groupBySelected:number = 1;
local m_groupByList:table = {};

local m_cityRouteLimitExclusionList:table = {};

-- Variables used for cycle trade units function
local m_TradeUnitIndex:number = 0;
local m_CurrentCyclingUnitsTradeRoute:number = -1;
local m_DisplayedTradeRoutes:number = 0;

local m_AvailableTradeRoutes:table = {};
local m_LocalPlayerRunningRoutes:table = {};

local m_HasBuiltTradeRouteTable:boolean	= false;
local m_LastTurnBuiltTradeRouteTable:number = -1;
local m_LastTurnUpdatedMyRoutes:number = -1;

local m_GroupShowAll:boolean = false;

-- Stores the sort settings.
local m_SortBySettings = {};
local m_GroupSortBySettings = {};

-- Default is ascending in turns to complete trade route
m_SortBySettings[1] = {
	SortByID = SORT_BY_ID.TURNS_TO_COMPLETE;
	SortOrder = SORT_ASCENDING;
};

-- Default is ascending in turns to complete trade route
m_GroupSortBySettings[1] = {
	SortByID = SORT_BY_ID.GOLD;
	SortOrder = SORT_DESCENDING;
};

local m_CompareFunctionByID	= {};

m_CompareFunctionByID[SORT_BY_ID.FOOD]				= function(a, b) return CompareByFood(a, b) end;
m_CompareFunctionByID[SORT_BY_ID.PRODUCTION]		= function(a, b) return CompareByProduction(a, b) end;
m_CompareFunctionByID[SORT_BY_ID.GOLD]				= function(a, b) return CompareByGold(a, b) end;
m_CompareFunctionByID[SORT_BY_ID.SCIENCE]			= function(a, b) return CompareByScience(a, b) end;
m_CompareFunctionByID[SORT_BY_ID.CULTURE]			= function(a, b) return CompareByCulture(a, b) end;
m_CompareFunctionByID[SORT_BY_ID.FAITH]				= function(a, b) return CompareByFaith(a, b) end;
m_CompareFunctionByID[SORT_BY_ID.TURNS_TO_COMPLETE]	= function(a, b) return CompareByTurnsToComplete(a, b) end;

-- Finds and adds all possible trade routes
function RebuildAvailableTradeRoutesTable()
	print ("Rebuilding Trade Routes table");
	m_AvailableTradeRoutes = {};

	local sourceCities:table = Players[Game.GetLocalPlayer()]:GetCities();
	local players:table = Game:GetPlayers();
	local tradeManager:table = Game.GetTradeManager();

	print("Group setting: " .. m_groupByList[m_groupBySelected].groupByString);

	-- Build tables differently for group settings
	if m_groupByList[m_groupBySelected].groupByID == GROUP_BY_SETTINGS.ORIGIN then
		for i, sourceCity in sourceCities:Members() do
			m_AvailableTradeRoutes[i] = {};
			local hasTradeRoute = false
			for j, destinationPlayer in ipairs(players) do
				local destinationCities:table = destinationPlayer:GetCities();				
				for k, destinationCity in destinationCities:Members() do
					-- Can we trade with this city / civ
					if tradeManager:CanStartRoute(sourceCity:GetOwner(), sourceCity:GetID(), destinationCity:GetOwner(), destinationCity:GetID()) then
						hasTradeRoute = true
						-- Create the trade route entry
						local tradeRoute = { 
							OriginCityPlayer 		= Game.GetLocalPlayer(), 
							OriginCityID 			= sourceCity:GetID(), 
							DestinationCityPlayer 	= destinationPlayer:GetID(), 
							DestinationCityID 		= destinationCity:GetID()
						};

						table.insert(m_AvailableTradeRoutes[i], tradeRoute);
					end
				end
			end

			-- Remove entry if no trade route existed
			if not hasTradeRoute then
				table.remove(m_AvailableTradeRoutes, i);
			end
		end
	elseif m_groupByList[m_groupBySelected].groupByID == GROUP_BY_SETTINGS.DESTINATION then
		local destinationCityCounter:number = 0;
		for i, destinationPlayer in ipairs(players) do
			local destinationCities:table = destinationPlayer:GetCities();				
			for j, destinationCity in destinationCities:Members() do
				local hasTradeRoute = false
				destinationCityCounter = destinationCityCounter + 1;
				m_AvailableTradeRoutes[destinationCityCounter] = {};
				for k, sourceCity in sourceCities:Members() do
					-- Can we trade with this city / civ
					if tradeManager:CanStartRoute(sourceCity:GetOwner(), sourceCity:GetID(), destinationCity:GetOwner(), destinationCity:GetID()) then
						hasTradeRoute = true
						-- Create the trade route entry
						local tradeRoute = { 
							OriginCityPlayer 		= Game.GetLocalPlayer(), 
							OriginCityID 			= sourceCity:GetID(), 
							DestinationCityPlayer 	= destinationPlayer:GetID(), 
							DestinationCityID 		= destinationCity:GetID()
						};
						table.insert(m_AvailableTradeRoutes[destinationCityCounter], tradeRoute);
					end
				end

				-- Remove entry if no trade route existed
				if not hasTradeRoute then
					table.remove(m_AvailableTradeRoutes, destinationCityCounter);
					destinationCityCounter = destinationCityCounter - 1;
				end
			end
		end
	else
		for i, sourceCity in sourceCities:Members() do
			for j, destinationPlayer in ipairs(players) do
				local destinationCities:table = destinationPlayer:GetCities();				
				for k, destinationCity in destinationCities:Members() do
					-- Can we trade with this city / civ
					if tradeManager:CanStartRoute(sourceCity:GetOwner(), sourceCity:GetID(), destinationCity:GetOwner(), destinationCity:GetID()) then
						-- Create the trade route entry
						local tradeRoute = { 
							OriginCityPlayer 		= Game.GetLocalPlayer(), 
							OriginCityID 			= sourceCity:GetID(), 
							DestinationCityPlayer 	= destinationPlayer:GetID(), 
							DestinationCityID 		= destinationCity:GetID()
						};

						table.insert(m_AvailableTradeRoutes, tradeRoute);
					end
				end
			end
		end
	end

	m_HasBuiltTradeRouteTable = true;
	m_LastTurnBuiltTradeRouteTable = Game.GetCurrentGameTurn();
end

function Refresh()
	PreRefresh();

	RefreshGroupByPulldown();
	RefreshFilters();
	RefreshSortBar();

	-- Dont rebuild if the turn has not advanced
	if Game.GetCurrentGameTurn() > m_LastTurnBuiltTradeRouteTable then
		print("Trade Route table last built on: " .. m_LastTurnBuiltTradeRouteTable .. ". Current game turn: " .. Game.GetCurrentGameTurn());
		RebuildAvailableTradeRoutesTable();
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
--	Tab functions
-- ===========================================================================

-- Show My Routes Tab
function ViewMyRoutes()
	m_DisplayedTradeRoutes = 0;

	-- Update Tabs
	SetMyRoutesTabSelected(true);
	SetRoutesToCitiesTabSelected(false);
	SetAvailableRoutesTabSelected(false);
	
	-- Update Header
	local playerTrade	:table	= Players[Game.GetLocalPlayer()]:GetTrade();
	local routesActive	:number = playerTrade:GetNumOutgoingRoutes();
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

	-- Check for consistency
	CheckConsistencyWithMyRunningRoutes( m_LocalPlayerRunningRoutes );

	if routesActive > 0 then
		-- Gather data and apply filter
		local routesSortedByPlayer:table = {};
		for i,route in ipairs(m_LocalPlayerRunningRoutes) do
			if m_filterList[m_filterSelected].FilterFunction and m_filterList[m_filterSelected].FilterFunction(Players[route.DestinationCityPlayer]) then
				-- Make sure we have a table for each destination player
				if routesSortedByPlayer[route.DestinationCityPlayer] == nil then
					routesSortedByPlayer[route.DestinationCityPlayer] = {};
				end

				table.insert(routesSortedByPlayer[route.DestinationCityPlayer], route);
			end
		end

		-- Add routes to local player cities
		if routesSortedByPlayer[Game.GetLocalPlayer()] ~= nil then
			CreatePlayerHeader(Players[Game.GetLocalPlayer()]);

			SortTradeRoutes(routesSortedByPlayer[Game.GetLocalPlayer()]);

			for i,route in ipairs(routesSortedByPlayer[Game.GetLocalPlayer()]) do
				AddRouteFromRouteInfo(route);
			end
		end

		-- Add routes to other civs
		local haveAddedCityStateHeader:boolean = false;
		for playerID,routes in pairs(routesSortedByPlayer) do
			if playerID ~= Game.GetLocalPlayer() then
				SortTradeRoutes ( routes );

				-- Skip City States as these are added below
				local playerInfluence:table = Players[playerID]:GetInfluence();
				if not playerInfluence:CanReceiveInfluence() then
					CreatePlayerHeader(Players[playerID]);

					for i,route in ipairs(routes) do
						AddRouteFromRouteInfo(route);
					end
				else
					-- Add city state routes
					if not haveAddedCityStateHeader then
						haveAddedCityStateHeader = true;
						CreateCityStateHeader();
					end

					for i,route in ipairs(routes) do
						AddRouteFromRouteInfo(route);
					end
				end
			end
		end
	end

	-- Determine how many unused routes we have
	local unusedRoutes	:number = routesCapacity - routesActive;
	if unusedRoutes > 0 then
		CreateUnusedRoutesHeader();

		local idleTradeUnits:table = GetIdleTradeUnits(Game.GetLocalPlayer());

		-- Assign idle trade units to unused routes
		for i=1,unusedRoutes,1 do
			if #idleTradeUnits > 0 then
				-- Add button to choose a route for this trader
				AddChooseRouteButton(idleTradeUnits[1]);
				table.remove(idleTradeUnits, 1);
			else
				-- Add button to produce new trade unit
				AddProduceTradeUnitButton();
			end
		end
	end
end

-- Show Routes To My Cities Tab
function ViewRoutesToCities()
	m_DisplayedTradeRoutes = 0;

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
		SortTradeRoutes( routes )

		for i,route in ipairs(routes) do
			AddRouteFromRouteInfo(route);
		end
	end
end

-- Show Available Routes Tab
function ViewAvailableRoutes()
	m_DisplayedTradeRoutes = 0;

	-- Update Tabs
	SetMyRoutesTabSelected(false);
	SetRoutesToCitiesTabSelected(false);
	SetAvailableRoutesTabSelected(true);

	-- Update Header
	Controls.HeaderLabel:SetText(Locale.ToUpper("LOC_TRADE_OVERVIEW_AVAILABLE_ROUTES"));
	Controls.ActiveRoutesLabel:SetHide(true);

	-- Safety check if table is built
	if not m_HasBuiltTradeRouteTable then
		print ("Trade Route table was not built. Building one now");
		RebuildAvailableTradeRoutesTable();
	end

	if m_groupByList[m_groupBySelected].groupByID ~= GROUP_BY_SETTINGS.NONE then
		-- Sort and filter the routes within each group
		local filteredAndSortedRoutes:table = {};
		for i, groupedRoutes in ipairs(m_AvailableTradeRoutes) do
			local filteredRoutes:table = FilterTradeRoutes(groupedRoutes);

			if tablelength(filteredRoutes) > 0 then
				SortTradeRoutes(filteredRoutes);
				table.insert(filteredAndSortedRoutes, filteredRoutes);
			end
		end

		-- Sort the order of groups
		SortGroupedRoutes(filteredAndSortedRoutes);

		for i, filteredSortedRoutes in ipairs(filteredAndSortedRoutes) do
			if m_groupByList[m_groupBySelected].groupByID == GROUP_BY_SETTINGS.ORIGIN then
				local originPlayer:table = Players[filteredSortedRoutes[1].OriginCityPlayer];
				local originCity:table = originPlayer:GetCities():FindID(filteredSortedRoutes[1].OriginCityID);

				local routeCount:number = tablelength(filteredSortedRoutes);

				if routeCount > 0 then
					-- Find if the city is in exclusion list
					local originCityEntry:table = {
						OwnerID = originPlayer:GetID(),
						CityID = originCity:GetID()
					};

					local cityExclusionIndex = findIndex(m_cityRouteLimitExclusionList, originCityEntry, CompareCityEntries);

					if (cityExclusionIndex > 0) then
						CreateCityHeader(originCity, routeCount, routeCount);
						AddRoutesFromTable(filteredSortedRoutes);
					else
						if not m_GroupShowAll then
							CreateCityHeader(originCity, math.min(GROUP_ORIGIN_ROUTE_SHOW_COUNT, routeCount), routeCount);
							AddRoutesFromTable(filteredSortedRoutes, GROUP_ORIGIN_ROUTE_SHOW_COUNT);
						else
							-- If showing all, add city to exclusion list, and display all
							table.insert(m_cityRouteLimitExclusionList, originCityEntry);
							CreateCityHeader(originCity, routeCount, routeCount);
							AddRoutesFromTable(filteredSortedRoutes);
						end
					end
				end
			elseif m_groupByList[m_groupBySelected].groupByID == GROUP_BY_SETTINGS.DESTINATION then
				local destinationPlayer:table = Players[filteredSortedRoutes[1].DestinationCityPlayer];
				local destinationCity:table = destinationPlayer:GetCities():FindID(filteredSortedRoutes[1].DestinationCityID);

				local routeCount:number = tablelength(filteredSortedRoutes);

				if routeCount > 0 then
					-- Find if the city is in exclusion list
					local destinationCityEntry:table = {
						OwnerID = destinationPlayer:GetID(),
						CityID = destinationCity:GetID()
					};

					local cityExclusionIndex = findIndex(m_cityRouteLimitExclusionList, destinationCityEntry, CompareCityEntries);

					if (cityExclusionIndex > 0) then
						CreateCityHeader(destinationCity, routeCount, routeCount);
						AddRoutesFromTable(filteredSortedRoutes);
					else
						if m_GroupShowAll then
							-- If showing all, add city to exclusion list, and display all
							table.insert(m_cityRouteLimitExclusionList, destinationCityEntry);
							CreateCityHeader(destinationCity, routeCount, routeCount);
							AddRoutesFromTable(filteredSortedRoutes);
						else
							CreateCityHeader(destinationCity, math.min(GROUP_DESTINATION_ROUTE_SHOW_COUNT, routeCount), routeCount);
							AddRoutesFromTable(filteredSortedRoutes, GROUP_DESTINATION_ROUTE_SHOW_COUNT);
						end
					end
				end
			end
		end
	else
		local filteredRoutes:table = FilterTradeRoutes(m_AvailableTradeRoutes);

		if tablelength(filteredRoutes) > 0 then
			SortTradeRoutes(filteredRoutes);
			AddRoutesFromTable(filteredRoutes, GROUP_NONE_ROUTE_SHOW_COUNT);
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

-- ===========================================================================
--	Route Instance Creators
-- ===========================================================================

function AddChooseRouteButton( tradeUnit:table )
	local simpleButtonInstance:table = m_SimpleButtonInstanceIM:GetInstance();
	simpleButtonInstance.GridButton:SetText(Locale.Lookup("LOC_TRADE_OVERVIEW_CHOOSE_ROUTE"));
	simpleButtonInstance.GridButton:RegisterCallback( Mouse.eLClick, 
		function()
			SelectUnit( tradeUnit );
		end
	);
end

function AddProduceTradeUnitButton()
	local simpleButtonInstance:table = m_SimpleButtonInstanceIM:GetInstance();
	simpleButtonInstance.GridButton:SetText(Locale.Lookup("LOC_TRADE_OVERVIEW_PRODUCE_TRADE_UNIT"));
	simpleButtonInstance.GridButton:SetDisabled(true);
end

function AddRoutesFromTable ( tradeRoutes:table, showCount:number )
	for index, tradeRoute in ipairs(tradeRoutes) do
		if showCount then
			if index <= showCount then
				AddRouteFromRouteInfo(tradeRoute);
			end
		else
			AddRouteFromRouteInfo(tradeRoute);
		end
	end
end

function AddRouteFromRouteInfo( routeInfo:table )
	local originPlayer:table = Players[routeInfo.OriginCityPlayer];
	local originCity:table = originPlayer:GetCities():FindID(routeInfo.OriginCityID);

	local destinationPlayer:table = Players[routeInfo.DestinationCityPlayer];
	local destinationCity:table = destinationPlayer:GetCities():FindID(routeInfo.DestinationCityID);

	AddRoute(originPlayer, originCity, destinationPlayer, destinationCity, routeInfo.TraderUnitID, routeInfo.TurnsRemaining, routeInfo.AddedFromCheck);
end

function AddRoute( originPlayer:table, originCity:table, destinationPlayer:table, destinationCity:table, traderUnitID:number, TurnsRemaining:number, AddedFromCheck:boolean )
	m_DisplayedTradeRoutes = m_DisplayedTradeRoutes + 1;

	-- print("Adding route: " .. Locale.Lookup(originCity:GetName()) .. " to " .. Locale.Lookup(destinationCity:GetName()));

	local routeInstance:table = m_RouteInstanceIM:GetInstance();
	local backColor, frontColor = UI.GetPlayerColors( destinationPlayer:GetID() );
	local darkerBackColor:number = DarkenLightenColor(backColor,(-85),238);
	local brighterBackColor:number = DarkenLightenColor(backColor,90,250);

	-- Update colors
	if tintTradeRouteEntry then

		tintBackColor = DarkenLightenColor(backColor, tintColorOffset, tintColorOpacity);
		tintFrontColor = DarkenLightenColor(frontColor, tintLabelColorOffset, tintLabelColorOpacity);

		routeInstance.GridButton:SetColor(tintBackColor);
		routeInstance.RouteLabel:SetColor(tintFrontColor);
		routeInstance.RouteLabel2:SetColor(tintFrontColor);
		routeInstance.TurnsToComplete:SetColor( frontColor );
	
		routeInstance.BannerBase:SetColor(  DarkenLightenColor(backColor,-10, 200) );
		routeInstance.BannerDarker:SetColor( darkerBackColor );
		routeInstance.BannerLighter:SetColor( brighterBackColor );

		if hideHeaderOpaqueBackdrop then
			routeInstance.BannerBase:SetHide(true);
			routeInstance.BannerDarker:SetHide(true);
			routeInstance.BannerLighter:SetHide(true);
			routeInstance.DividerLine:SetHide(false);
		else
			routeInstance.RouteLabel:SetColor(frontColor);
			routeInstance.RouteLabel2:SetColor(frontColor);

			routeInstance.BannerBase:SetHide(false);
			routeInstance.BannerDarker:SetHide(false);
			routeInstance.BannerLighter:SetHide(false);
			routeInstance.RouteLabel2:SetHide(true);
			routeInstance.DividerLine:SetHide(true);
		end
	else
		routeInstance.BannerBase:SetHide(true);
		routeInstance.BannerDarker:SetHide(true);
		routeInstance.BannerLighter:SetHide(true);
		routeInstance.RouteLabel2:SetHide(false);
	end

	-- Update Route Label
	routeInstance.RouteLabel:SetText(Locale.ToUpper(originCity:GetName()) .. " " .. Locale.ToUpper("LOC_TRADE_OVERVIEW_TO") .. " " .. Locale.ToUpper(destinationCity:GetName()));
	routeInstance.RouteLabel2:SetText(Locale.ToUpper(originCity:GetName()) .. " " .. Locale.ToUpper("LOC_TRADE_OVERVIEW_TO") .. " " .. Locale.ToUpper(destinationCity:GetName()));

	-- Update yield directional arrows
	local originBackColor, originFrontColor = UI.GetPlayerColors( originPlayer:GetID() );
	local destinationBackColor, destinationFrontColor = UI.GetPlayerColors( destinationPlayer:GetID() );
	routeInstance.OriginCivArrow:SetColor(DarkenLightenColor(originFrontColor, 30, 255));
	routeInstance.DestinationCivArrow:SetColor(DarkenLightenColor(destinationFrontColor, 30, 255));

	-- Update Route Yields
	routeInstance.OriginResourceStack:DestroyAllChildren();
	routeInstance.DestinationResourceStack:DestroyAllChildren();

	if showNoBenefitsString then
		routeInstance.OriginResourceStack:SetHide(true);
		routeInstance.DestinationResourceStack:SetHide(true);
		routeInstance.OriginNoBenefitsLabel:SetHide(false);
		routeInstance.OriginNoBenefitsLabel:SetString(Locale.Lookup(originCity:GetName()) .. " gains no benefits from this route.")
		routeInstance.DestinationNoBenefitsLabel:SetHide(false);
		routeInstance.DestinationNoBenefitsLabel:SetString(Locale.Lookup(destinationCity:GetName()) .. " gains no benefits from this route.")
	else
		routeInstance.OriginNoBenefitsLabel:SetHide(true);
		routeInstance.DestinationNoBenefitsLabel:SetHide(true);
	end

	for yieldInfo in GameInfo.Yields() do
		local originCityYieldValue = GetYieldFromCity(yieldInfo.Index, originCity, destinationCity);
		local destinationCityYieldValue = GetYieldForDestinationCity(yieldInfo.Index, originCity, destinationCity);

		local originResourceInstance:table = {};
		local destinationResourceInstance:table = {};

		if alignTradeYields then
			ContextPtr:BuildInstanceForControl( "ResourceInstance", originResourceInstance, routeInstance.OriginResourceStack );
			ContextPtr:BuildInstanceForControl( "ResourceInstance", destinationResourceInstance, routeInstance.DestinationResourceStack );
		end

		if (originCityYieldValue ~= 0 ) then
			routeInstance.OriginResourceStack:SetHide(false);

			if not alignTradeYields then
				ContextPtr:BuildInstanceForControl( "ResourceInstance", originResourceInstance, routeInstance.OriginResourceStack );
			end

			originResourceInstance.ResourceIconLabel:SetText(yieldInfo.IconString);
			originResourceInstance.ResourceValueLabel:SetText("+" .. originCityYieldValue);

			-- Set tooltip to resource name
			originResourceInstance.Top:LocalizeAndSetToolTip(yieldInfo.Name);

			-- Update Label Color
			if (yieldInfo.YieldType == "YIELD_FOOD") then
				originResourceInstance.ResourceValueLabel:SetColorByName("ResFoodLabelCS");
			elseif (yieldInfo.YieldType == "YIELD_PRODUCTION") then
				originResourceInstance.ResourceValueLabel:SetColorByName("ResProductionLabelCS");
			elseif (yieldInfo.YieldType == "YIELD_GOLD") then
				originResourceInstance.ResourceValueLabel:SetColorByName("ResGoldLabelCS");
			elseif (yieldInfo.YieldType == "YIELD_SCIENCE") then
				originResourceInstance.ResourceValueLabel:SetColorByName("ResScienceLabelCS");
			elseif (yieldInfo.YieldType == "YIELD_CULTURE") then
				originResourceInstance.ResourceValueLabel:SetColorByName("ResCultureLabelCS");
			elseif (yieldInfo.YieldType == "YIELD_FAITH") then
				originResourceInstance.ResourceValueLabel:SetColorByName("ResFaithLabelCS");
			end

			routeInstance.OriginNoBenefitsLabel:SetHide(true);

		elseif alignTradeYields then
			originResourceInstance.ResourceIconLabel:SetHide(true);
			originResourceInstance.ResourceValueLabel:SetHide(true);
		end

		if (destinationCityYieldValue ~= 0 ) then
			routeInstance.DestinationResourceStack:SetHide(false);

			if not alignTradeYields then
				ContextPtr:BuildInstanceForControl( "ResourceInstance", destinationResourceInstance, routeInstance.DestinationResourceStack );
			end
			destinationResourceInstance.ResourceIconLabel:SetText(yieldInfo.IconString);
			destinationResourceInstance.ResourceValueLabel:SetText("+" .. destinationCityYieldValue);

			-- Set tooltip to resouce name
			destinationResourceInstance.Top:LocalizeAndSetToolTip(yieldInfo.Name);

			-- Update Label Color
			if (yieldInfo.YieldType == "YIELD_FOOD") then
				destinationResourceInstance.ResourceValueLabel:SetColorByName("ResFoodLabelCS");
			elseif (yieldInfo.YieldType == "YIELD_PRODUCTION") then
				destinationResourceInstance.ResourceValueLabel:SetColorByName("ResProductionLabelCS");
			elseif (yieldInfo.YieldType == "YIELD_GOLD") then
				destinationResourceInstance.ResourceValueLabel:SetColorByName("ResGoldLabelCS");
			elseif (yieldInfo.YieldType == "YIELD_SCIENCE") then
				destinationResourceInstance.ResourceValueLabel:SetColorByName("ResScienceLabelCS");
			elseif (yieldInfo.YieldType == "YIELD_CULTURE") then
				destinationResourceInstance.ResourceValueLabel:SetColorByName("ResCultureLabelCS");
			elseif (yieldInfo.YieldType == "YIELD_FAITH") then
				destinationResourceInstance.ResourceValueLabel:SetColorByName("ResFaithLabelCS");
			end

			routeInstance.DestinationNoBenefitsLabel:SetHide(true);

		elseif alignTradeYields then
			destinationResourceInstance.ResourceIconLabel:SetHide(true);
			destinationResourceInstance.ResourceValueLabel:SetHide(true);
		end
	end

	routeInstance.OriginResourceStack:CalculateSize();
	routeInstance.DestinationResourceStack:CalculateSize();
	
	-- Update City State Quest Icon
	routeInstance.CityStateQuestIcon:SetHide(true);	
	local questTooltip	: string = Locale.Lookup("LOC_CITY_STATES_QUESTS");
	local tradeRouteQuestInfo:table = GameInfo.Quests["QUEST_SEND_TRADE_ROUTE"];
	local questsManager:table = Game.GetQuestsManager();
	
	if IsCityStateWithTradeQuest(destinationPlayer) then
		questTooltip = questTooltip .. "[NEWLINE]" .. tradeRouteQuestInfo.IconString .. questsManager:GetActiveQuestName(Game.GetLocalPlayer(), destinationCity:GetOwner(), tradeRouteQuestInfo.Index);
		routeInstance.CityStateQuestIcon:SetHide(false);
		routeInstance.CityStateQuestIcon:SetToolTipString(questTooltip);
	end

	-- Update Diplomatic Visibility
	routeInstance.VisibilityBonusGrid:SetHide(false);
	routeInstance.TourismBonusGrid:SetHide(false);

	-- Do we display the tourism or visibilty bonus? Hide them if we are showing them somewhere else, or it is a city state, or it is domestic route
	if IsCityState(originPlayer) or  IsCityState(destinationPlayer) or originPlayer:GetID() == destinationPlayer:GetID() or m_groupByList[m_groupBySelected].groupByID == GROUP_BY_SETTINGS.DESTINATION or m_currentTab ~= TRADE_TABS.AVAILABLE_ROUTES then
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
		local visibilityIndex:number = Players[Game.GetLocalPlayer()]:GetDiplomacy():GetVisibilityOn(destinationPlayer);

		-- Determine this player has a trade route with the local player
		local hasTradeRoute:boolean = false;
		local playerCities:table = destinationPlayer:GetCities();
		for i,city in playerCities:Members() do
			if city:GetTrade():HasActiveTradingPost(Game.GetLocalPlayer()) then
				hasTradeRoute = true;
			end
		end

		-- Display trade route tourism modifier
		local baseTourismModifier = GlobalParameters.TOURISM_TRADE_ROUTE_BONUS;
		local extraTourismModifier = Players[Game.GetLocalPlayer()]:GetCulture():GetExtraTradeRouteTourismModifier();
		
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

	if destinationCity:GetTrade():HasActiveTradingPost(originPlayer) then
		routeInstance.TradingPostIndicator:SetAlpha(1.0);
		routeInstance.TradingPostIndicator:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_TRADE_POST_ESTABLISHED");
	else
		routeInstance.TradingPostIndicator:SetAlpha(0.2);
		routeInstance.TradingPostIndicator:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_NO_TRADE_POST");
	end

	-- Update turns to complete route
	local tooltipString:string;
	local tradePathLength, tripsToDestination, turnsToCompleteRoute = GetRouteInfo(originCity, destinationCity);
	if m_currentTab == TRADE_TABS.MY_ROUTES then
		if AddedFromCheck then
			routeInstance.TurnsToComplete:SetText("< " .. TurnsRemaining);
			tooltipString = (	"This route will take less than " .. TurnsRemaining .. "[Icon_Turn]to complete.[NEWLINE]" .. 
								"----------------------------[NEWLINE]" ..
								"Trade Route[ICON_Movement]: " .. tradePathLength .. "[NEWLINE]" .. 
								"Trips to destination: " .. tripsToDestination );
		else
			routeInstance.TurnsToComplete:SetText(TurnsRemaining);
			tooltipString = (	"This route will take " .. TurnsRemaining .. "[Icon_Turn]to complete.[NEWLINE]" .. 
								"----------------------------[NEWLINE]" ..
								"Trade Route[ICON_Movement]: " .. tradePathLength .. "[NEWLINE]" .. 
								"Trips to destination: " .. tripsToDestination .. "[NEWLINE]" .. 
								"Route will complete in[ICON_Turn]" .. Game.GetCurrentGameTurn() + TurnsRemaining);
		end
	else
		routeInstance.TurnsToComplete:SetText(turnsToCompleteRoute);
		tooltipString = (	"Total amount of[ICON_Turn]to complete this trade route[NEWLINE]" .. 
							"----------------------------[NEWLINE]" ..
							"Trade Route[ICON_Movement]: " .. tradePathLength .. "[NEWLINE]" .. 
							"Trips to destination: " .. tripsToDestination .. "[NEWLINE]" .. 
							"If started, route will complete in[ICON_Turn]" .. Game.GetCurrentGameTurn() + turnsToCompleteRoute);
	end

	routeInstance.TurnsToComplete:SetToolTipString( tooltipString );

	-- Update Origin Civ Icon
	local originPlayerConfig:table = PlayerConfigurations[originPlayer:GetID()];
	local originPlayerIconString:string = "ICON_" .. originPlayerConfig:GetCivilizationTypeName();
	local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(originPlayerIconString, 30);
	local secondaryColor, primaryColor = UI.GetPlayerColors( originPlayer:GetID() );
	routeInstance.OriginCivIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
	routeInstance.OriginCivIcon:LocalizeAndSetToolTip( originPlayerConfig:GetCivilizationDescription() );
	routeInstance.OriginCivIcon:SetColor( primaryColor );
	routeInstance.OriginCivIconBacking:SetColor( secondaryColor );

	local destinationPlayerConfig:table = PlayerConfigurations[destinationPlayer:GetID()];
	local destinationPlayerInfluence:table = Players[destinationPlayer:GetID()]:GetInfluence();
	if not destinationPlayerInfluence:CanReceiveInfluence() then
		-- Destination Icon for Civilizations
		if destinationPlayerConfig ~= nil then
			local iconString:string = "ICON_" .. destinationPlayerConfig:GetCivilizationTypeName();
			local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconString, 30);
			routeInstance.DestinationCivIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
			routeInstance.DestinationCivIcon:LocalizeAndSetToolTip( destinationPlayerConfig:GetCivilizationDescription() );
		end

		local secondaryColor, primaryColor = UI.GetPlayerColors( destinationPlayer:GetID() );
		routeInstance.DestinationCivIcon:SetColor(primaryColor);
		routeInstance.DestinationCivIconBacking:SetColor(secondaryColor);
	else
		-- Destination Icon for City States
		if destinationPlayerConfig ~= nil then
			local secondaryColor, primaryColor = UI.GetPlayerColors( destinationPlayer:GetID() );
			local leader		:string = destinationPlayerConfig:GetLeaderTypeName();
			local leaderInfo	:table	= GameInfo.Leaders[leader];

			local iconString:string;
			if (leader == "LEADER_MINOR_CIV_SCIENTIFIC" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_SCIENTIFIC") then				
				iconString = "ICON_CITYSTATE_SCIENCE";
			elseif (leader == "LEADER_MINOR_CIV_RELIGIOUS" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_RELIGIOUS") then
				iconString = "ICON_CITYSTATE_FAITH";
			elseif (leader == "LEADER_MINOR_CIV_TRADE" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_TRADE") then
				iconString = "ICON_CITYSTATE_TRADE";
			elseif (leader == "LEADER_MINOR_CIV_CULTURAL" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_CULTURAL") then
				iconString = "ICON_CITYSTATE_CULTURE";
			elseif (leader == "LEADER_MINOR_CIV_MILITARISTIC" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_MILITARISTIC") then
				iconString = "ICON_CITYSTATE_MILITARISTIC";
			elseif (leader == "LEADER_MINOR_CIV_INDUSTRIAL" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_INDUSTRIAL") then
				iconString = "ICON_CITYSTATE_INDUSTRIAL";
			end
								
			if iconString ~= nil then
				local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconString, 30);
				routeInstance.DestinationCivIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
				routeInstance.DestinationCivIcon:SetColor(primaryColor);
				routeInstance.DestinationCivIconBacking:SetColor(secondaryColor);
				routeInstance.DestinationCivIcon:LocalizeAndSetToolTip( destinationCity:GetName() );
			end
		end
	end

	-- Add buttton hookups
	if m_currentTab == TRADE_TABS.AVAILABLE_ROUTES then
		-- Find trader unit / units and set button callback to select that unit
		local tradeUnits = {};
		local pPlayerUnits:table = Players[Game.GetLocalPlayer()]:GetUnits();
		for i, pUnit in pPlayerUnits:Members() do
			-- Ignore trade units that have a pending operation
			if not pUnit:HasPendingOperations() then
				-- Find Each Trade Unit
				local unitInfo:table = GameInfo.Units[pUnit:GetUnitType()];
				if unitInfo.MakeTradeRoute == true then
					local tradeUnitEntry:table = {
						OwnerID = pUnit:GetOwner();
						UnitID = pUnit:GetID();
					};

					table.insert(tradeUnits, tradeUnitEntry);

					-- Find if the current location of the trade unit matches the origin city
					if pUnit:GetX() == originCity:GetX() and pUnit:GetY() == originCity:GetY() then

						-- If selecting an available route, select unit and select route in route chooser
						routeInstance.GridButton:RegisterCallback( Mouse.eLClick, 
							function()
								SelectUnit( pUnit );
								LuaEvents.TradeOverview_SelectRouteFromOverview( destinationPlayer:GetID(), destinationCity:GetID() );
							end
						);
						return;
					end
				end
			end
		end

		-- Cycle through trade units on mouse click, if no local trade unit was found
		routeInstance.GridButton:RegisterCallback( Mouse.eLClick, 
			function()
				CycleTradeUnit(tradeUnits, m_DisplayedTradeRoutes, originCity);
			end
		);
	else
		if traderUnitID then
		local tradeUnit:table = originPlayer:GetUnits():FindID(traderUnitID);

		routeInstance.GridButton:RegisterCallback( Mouse.eLClick, 
			function()
				SelectUnit( tradeUnit );
			end
		);
		end
	end
end

-- ---------------------------------------------------------------------------
-- Route button hookups
-- ---------------------------------------------------------------------------
function CycleTradeUnit( tradeUnits:table, tradeRouteID:number, newOriginCity:table )

	-- Did we just start a new cycle?
	if m_CurrentCyclingUnitsTradeRoute ~= tradeRouteID then
		m_TradeUnitIndex = 1;
		m_CurrentCyclingUnitsTradeRoute = tradeRouteID;
	end

	print("Cycling units. Select unit with index: " .. m_TradeUnitIndex .. " and length: " .. tablelength(tradeUnits))
	
	local pPlayer = Players[tradeUnits[m_TradeUnitIndex].OwnerID];
	local pUnit = pPlayer:GetUnits():FindID(tradeUnits[m_TradeUnitIndex].UnitID);

	-- Open the change origin city window, and select the new city
	-- FIXME: Bug, sometimes, the choose a route opens, and you need to click again.
	-- The issue lies in when the trade unit gets selected, it auto opens the choose a route screen.
	SelectUnit( pUnit );
	LuaEvents.TradeOverview_ChangeOriginCityFromOverview( newOriginCity );

	m_TradeUnitIndex = m_TradeUnitIndex + 1;
	if m_TradeUnitIndex > tablelength(tradeUnits) then
		m_TradeUnitIndex = 1;
	end
end

-- ===========================================================================
--	Header Instance Creators
-- ===========================================================================

function CreatePlayerHeader( player:table )
	local headerInstance:table = m_HeaderInstanceIM:GetInstance();

	local pPlayerConfig:table = PlayerConfigurations[player:GetID()];
	headerInstance.HeaderLabel:SetText(Locale.ToUpper(pPlayerConfig:GetPlayerName()));

	-- If the current tab is not available routes, hide the collapse button, and trading post
	if m_currentTab ~= TRADE_TABS.AVAILABLE_ROUTES then
		headerInstance.RoutesExpand:SetHide(true);
		headerInstance.RouteCountLabel:SetHide(true);
		headerInstance.TradingPostIndicator:SetHide(true);
	end

	if colorCityPlayerHeader then
		headerInstance.CityBannerFill:SetHide(false);
		local backColor, frontColor = UI.GetPlayerColors( player:GetID() );
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

	if (player:GetID() ~=  Game.GetLocalPlayer() or m_currentTab ~= TRADE_TABS.AVAILABLE_ROUTES) and not IsCityState(player) then
		-- Determine are diplomatic visibility status
		headerInstance.TourismBonusGrid:SetHide(false);
		headerInstance.VisibilityBonusGrid:SetHide(false)
		local visibilityIndex:number = Players[Game.GetLocalPlayer()]:GetDiplomacy():GetVisibilityOn(player);

		-- Determine this player has a trade route with the local player
		local hasTradeRoute:boolean = false;
		local playerCities:table = player:GetCities();
		for i,city in playerCities:Members() do
			if city:GetTrade():HasActiveTradingPost(Game.GetLocalPlayer()) then
				hasTradeRoute = true;
			end
		end

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
		print("Not displaying vis bonuses")
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

function CreateCityHeader( city:table , currentRouteShowCount:number, totalRoutes:number )
	local headerInstance:table = m_HeaderInstanceIM:GetInstance();
	
	local playerID:number = city:GetOwner();
	local pPlayer = Players[playerID];
	headerInstance.HeaderLabel:SetText(Locale.ToUpper(city:GetName()));

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
			local visibilityIndex:number = Players[Game.GetLocalPlayer()]:GetDiplomacy():GetVisibilityOn(pPlayer);

			-- Determine this player has a trade route with the local player
			local hasTradeRoute:boolean = false;
			local playerCities:table = pPlayer:GetCities();
			for i,pCity in playerCities:Members() do
				if pCity:GetTrade():HasActiveTradingPost(Game.GetLocalPlayer()) then
					hasTradeRoute = true;
				end
			end

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

	local cityExclusionIndex = findIndex(m_cityRouteLimitExclusionList, cityEntry, CompareCityEntries);
	
	if cityExclusionIndex == -1 then
		headerInstance.RoutesExpand:SetCheck(false);
		headerInstance.RoutesExpand:SetCheckTextureOffsetVal(0,0);
	else
		headerInstance.RoutesExpand:SetCheck(true);
		headerInstance.RoutesExpand:SetCheckTextureOffsetVal(0,22);
	end


	headerInstance.RoutesExpand:RegisterCallback( Mouse.eLClick, function() OnExpandRoutes(headerInstance.RoutesExpand, city:GetOwner(), city:GetID()); end );
	headerInstance.RoutesExpand:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	if colorCityPlayerHeader then
		headerInstance.CityBannerFill:SetHide(false);
		local backColor, frontColor = UI.GetPlayerColors(playerID);
		-- local darkerBackColor = DarkenLightenColor(backColor,(-85),238);
		-- local brighterBackColor = DarkenLightenColor(backColor,90,255);
		
		headerBackColor = DarkenLightenColor(backColor, backdropColorOffset, backdropColorOpacity);
		headerFrontColor = DarkenLightenColor(frontColor, labelColorOffset, labelColorOpacity);
		gridBackColor = DarkenLightenColor(backColor, backdropGridColorOffset, backdropGridColorOpacity);
		headerInstance.CityBannerFill:SetColor( gridBackColor );
		-- headerInstance.CityBannerFill2:SetColor( darkerBackColor );
		-- headerInstance.CityBannerFill3:SetColor( brighterBackColor );
		headerInstance.HeaderLabel:SetColor(headerFrontColor);
		--headerInstance.RouteCountLabel:SetColor(frontColor);
		headerInstance.CityBannerFill:SetColor(headerBackColor);
		headerInstance.HeaderGrid:SetColor(gridBackColor);
	else
		-- Hide the colored UI elements
		headerInstance.CityBannerFill:SetHide(true);
	end
end

function OnExpandRoutes( checkbox, cityOwnerID:number, cityID:number )

	-- If expand button clicked with the expand all selected, unselect it
	if m_GroupShowAll then
		m_GroupShowAll = false;
		Controls.GroupShowAllCheckBox:SetCheck(false);
		Controls.GroupShowAllCheckBoxLabel:SetText("Expand All:");
	end

	-- For some reason the Uncheck texture does not apply, so I had to hard code the offset in. 
	-- TODO: Find a fix for this
	if (checkbox:IsChecked()) then
		Controls.GroupShowAllCheckBox:SetCheck(true);
		Controls.GroupShowAllCheckBoxLabel:SetText("Collapse All:");

		checkbox:SetCheckTextureOffsetVal(0,22);

		local cityEntry = {
			OwnerID = cityOwnerID,
			CityID = cityID
		};

		-- Only add entry if it isn't already in the list
		if findIndex(m_cityRouteLimitExclusionList, cityEntry, CompareCityEntries) == -1 then
			print("Adding " .. GetCityEntryString(cityEntry) .. " to the exclusion list");
			table.insert(m_cityRouteLimitExclusionList, cityEntry);
		else
			print("City already exists in exclusion list");
		end
	else
		checkbox:SetCheckTextureOffsetVal(0,0);

		local cityEntry = {
			OwnerID = cityOwnerID,
			CityID = cityID
		};

		local cityIndex = findIndex(m_cityRouteLimitExclusionList, cityEntry, CompareCityEntries)

		if findIndex(m_cityRouteLimitExclusionList, cityEntry, CompareCityEntries) > 0 then
			print("Removing " .. GetCityEntryString(cityEntry) .. " to the exclusion list");
			table.remove(m_cityRouteLimitExclusionList, cityIndex);

			-- If the exclusion list is empty, update the collapse all button
			if tablelength(m_cityRouteLimitExclusionList)  <= 0 then
				Controls.GroupShowAllCheckBox:SetCheck(false);
				Controls.GroupShowAllCheckBoxLabel:SetText("Expand All:");
			end
		else
			print("City does not exist in exclusion list");
		end
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
--	Group By Pulldown functions
-- ===========================================================================

function RefreshGroupByPulldown()

	-- Clear current group by entries
	Controls.OverviewGroupByPulldown:ClearEntries();
	m_groupByList = {};

	-- Build entries
	AddGroupByEntry("None", GROUP_BY_SETTINGS.NONE);
	AddGroupByEntry("Origin City", GROUP_BY_SETTINGS.ORIGIN);
	AddGroupByEntry("Destination City", GROUP_BY_SETTINGS.DESTINATION);

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
--	Filter, Filter Pulldown functions
-- ===========================================================================

function FilterTradeRoutes ( tradeRoutes:table )
	-- print("Current filter: " .. m_filterList[m_filterSelected].FilterText);
	
	local filtertedRoutes:table = {};

	for index, tradeRoute in ipairs(tradeRoutes) do
		local pPlayer = Players[tradeRoute.DestinationCityPlayer];
		if m_filterList[m_filterSelected].FilterFunction and m_filterList[m_filterSelected].FilterFunction(pPlayer) then
			table.insert(filtertedRoutes, tradeRoute);
		end
	end

	return filtertedRoutes;
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

	-- Add "My Cities" Filter
	AddFilter("My Cities", function(a) return a:GetID() == Game.GetLocalPlayer(); end);

	-- Add "Major Civs" Filter
	AddFilter("Other Major Civilizations", IsOtherMajorCiv);

	-- Add "City States" Filter
	AddFilter("City-States", IsCityState);

	-- Add "City States with Trade Quest" Filter
	AddFilter("City-States with Trade Quest", IsCityStateWithTradeQuest);

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
--	Trade Routes Sorter
-- ===========================================================================

function SortTradeRoutes( tradeRoutes:table )
	if tablelength(m_SortBySettings) > 0 then
		-- If we are grouping by none, apply sort for groups
		if m_groupBySelected == GROUP_BY_SETTINGS.NONE then
			table.sort(tradeRoutes, CompleteGroupCompareBy)
		else
			table.sort(tradeRoutes, CompleteCompareBy)
		end
	end
end

function SortGroupedRoutes( groupedRoutes:table )
	if tablelength(m_GroupSortBySettings) > 0 then
		table.sort(groupedRoutes, CompareGroupedRoutes)
	end
end

function InsertSortEntry( sortByID:number, sortOrder:number, sortSettings:table )
	local sortEntry = {
		SortByID = sortByID,
		SortOrder = sortOrder
	};

	-- Only insert if it does not exist
	local sortEntryIndex = findIndex (sortSettings, sortEntry, CompareSortEntries);
	if sortEntryIndex == -1 then
		print("Inserting " .. sortEntry.SortByID);
		table.insert(sortSettings, sortEntry);
	else
		-- If it exists, just update the sort oder
		print("Index: " .. sortEntryIndex);
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

-- ---------------------------------------------------------------------------
-- Compare functions
-- ---------------------------------------------------------------------------

-- Checks for the same ID, not the same order
function CompareSortEntries( sortEntry1:table, sortEntry2:table)
	if sortEntry1.SortByID == sortEntry2.SortByID then
		return true;
	end

	return false;
end

-- Compares the top route of passed groups
function CompareGroupedRoutes( groupedRoutes1:table, groupedRoutes2:table )
	return CompleteGroupCompareBy(groupedRoutes1[1], groupedRoutes2[1]);
end

-- Identitical to CompleteCompareBy but uses the group sort settings
function CompleteGroupCompareBy( tradeRoute1:table, tradeRoute2:table )
	for index, sortEntry in ipairs(m_GroupSortBySettings) do
		local compareFunction = m_CompareFunctionByID[sortEntry.SortByID];
		local compareResult:boolean = compareFunction(tradeRoute1, tradeRoute2);

		if compareResult then
			if (sortEntry.SortOrder == SORT_DESCENDING) then
				return false;
			else
				return true;
			end
		elseif not CheckEquality( tradeRoute1, tradeRoute2, compareFunction ) then
			if (sortEntry.SortOrder == SORT_DESCENDING) then
				return true;
			else
				return false;
			end
		end
	end

	-- If it reaches here, we used all the settings, and all of them were equal. Just return false
	return false;
end

-- Uses the list of compare functions, to make one global compare function
function CompleteCompareBy( tradeRoute1:table, tradeRoute2:table )
	for index, sortEntry in ipairs(m_SortBySettings) do
		local compareFunction = m_CompareFunctionByID[sortEntry.SortByID];
		local compareResult:boolean = compareFunction(tradeRoute1, tradeRoute2);

		if compareResult then
			if (sortEntry.SortOrder == SORT_DESCENDING) then
				return false;
			else
				return true;
			end
		elseif not CheckEquality( tradeRoute1, tradeRoute2, compareFunction ) then
			if (sortEntry.SortOrder == SORT_DESCENDING) then
				return true;
			else
				return false;
			end
		end
	end

	-- If it reaches here, we used all the settings, and all of them were equal. Just return false
	return false;
end

function CompareByFood( tradeRoute1:table, tradeRoute2:table )
	return CompareByYield (GameInfo.Yields["YIELD_FOOD"].Index, tradeRoute1, tradeRoute2);
end

function CompareByProduction( tradeRoute1:table, tradeRoute2:table )
	return CompareByYield (GameInfo.Yields["YIELD_PRODUCTION"].Index, tradeRoute1, tradeRoute2);
end

function CompareByGold( tradeRoute1:table, tradeRoute2:table )
	return CompareByYield (GameInfo.Yields["YIELD_GOLD"].Index, tradeRoute1, tradeRoute2);
end

function CompareByScience( tradeRoute1:table, tradeRoute2:table )
	return CompareByYield (GameInfo.Yields["YIELD_SCIENCE"].Index, tradeRoute1, tradeRoute2);
end

function CompareByCulture( tradeRoute1:table, tradeRoute2:table )
	return CompareByYield (GameInfo.Yields["YIELD_CULTURE"].Index, tradeRoute1, tradeRoute2);
end

function CompareByFaith( tradeRoute1:table, tradeRoute2:table )
	return CompareByYield (GameInfo.Yields["YIELD_FAITH"].Index, tradeRoute1, tradeRoute2);
end

function CompareByYield( yieldIndex:number, tradeRoute1:table, tradeRoute2:table )
	local originPlayer1:table = Players[tradeRoute1.OriginCityPlayer];
	local destinationPlayer1:table = Players[tradeRoute1.DestinationCityPlayer];
	local originCity1:table = originPlayer1:GetCities():FindID(tradeRoute1.OriginCityID);
	local destinationCity1:table = destinationPlayer1:GetCities():FindID(tradeRoute1.DestinationCityID);

	local originPlayer2:table = Players[tradeRoute2.OriginCityPlayer];
	local destinationPlayer2:table = Players[tradeRoute2.DestinationCityPlayer];
	local originCity2:table = originPlayer2:GetCities():FindID(tradeRoute2.OriginCityID);
	local destinationCity2:table = destinationPlayer2:GetCities():FindID(tradeRoute2.DestinationCityID);

	local yieldForRoute1 = GetYieldFromCity(yieldIndex, originCity1, destinationCity1);
	local yieldForRoute2 = GetYieldFromCity(yieldIndex, originCity2, destinationCity2);

	return yieldForRoute1 < yieldForRoute2;
end

function CompareByTurnsToComplete( tradeRoute1:table, tradeRoute2:table )
	if m_currentTab == TRADE_TABS.MY_ROUTES then
		return GetRouteTurnsRemaining( tradeRoute1 ) < GetRouteTurnsRemaining( tradeRoute2 );
	end

	local originPlayer1:table = Players[tradeRoute1.OriginCityPlayer];
	local destinationPlayer1:table = Players[tradeRoute1.DestinationCityPlayer];
	local originCity1:table = originPlayer1:GetCities():FindID(tradeRoute1.OriginCityID);
	local destinationCity1:table = destinationPlayer1:GetCities():FindID(tradeRoute1.DestinationCityID);

	local originPlayer2:table = Players[tradeRoute2.OriginCityPlayer];
	local destinationPlayer2:table = Players[tradeRoute2.DestinationCityPlayer];
	local originCity2:table = originPlayer2:GetCities():FindID(tradeRoute2.OriginCityID);
	local destinationCity2:table = destinationPlayer2:GetCities():FindID(tradeRoute2.DestinationCityID);

	local tradePathLength1, tripsToDestination1, turnsToCompleteRoute1 = GetRouteInfo(originCity1, destinationCity1);
	local tradePathLength2, tripsToDestination2, turnsToCompleteRoute2 = GetRouteInfo(originCity2, destinationCity2);

	return turnsToCompleteRoute1 < turnsToCompleteRoute2;
end

-- ===========================================================================
--	Sort bar functions
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
--	Applicaton level functions
-- ===========================================================================

function Open()
	m_AnimSupport.Show();
	UI.PlaySound("CityStates_Panel_Open");
	LuaEvents.TradeOverview_UpdateContextStatus(true);
end

function Close()
    if not ContextPtr:IsHidden() then
        UI.PlaySound("CityStates_Panel_Close");
    end
	m_AnimSupport.Hide();
	LuaEvents.TradeOverview_UpdateContextStatus(false);
end

-- ===========================================================================
--	General helper functions
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

function IsCityState( player:table )
	local playerInfluence:table = player:GetInfluence();
	if  playerInfluence:CanReceiveInfluence() then
		return true
	end

	return false
end

-- Checks if the player is a city state, with "Send a trade route" quest
function IsCityStateWithTradeQuest( player:table )
	local questsManager	: table = Game.GetQuestsManager();
	local questTooltip	: string = Locale.Lookup("LOC_CITY_STATES_QUESTS");
	if (questsManager ~= nil and Game.GetLocalPlayer() ~= nil) then
		local tradeRouteQuestInfo:table = GameInfo.Quests["QUEST_SEND_TRADE_ROUTE"];
		if (tradeRouteQuestInfo ~= nil) then
			if (questsManager:HasActiveQuestFromPlayer(Game.GetLocalPlayer(), player:GetID(), tradeRouteQuestInfo.Index)) then
				return true
			end
		end
	end

	return false
end

-- Checks if the player is a Major civ, other than the local player
function IsOtherMajorCiv( player:table )
	if player:IsMajor() and player:GetID() ~= Game.GetLocalPlayer() then
		return true
	end

	return false
end

-- ---------------------------------------------------------------------------
-- Trade route helper functions
-- ---------------------------------------------------------------------------
-- Returns yield for the origin city
function GetYieldFromCity( yieldIndex:number, originCity:table, destinationCity:table )
	local tradeManager = Game.GetTradeManager();

	-- From route
	local yieldValue = tradeManager:CalculateOriginYieldFromPotentialRoute(originCity:GetOwner(), originCity:GetID(), destinationCity:GetOwner(), destinationCity:GetID(), yieldIndex);
	-- From path
	yieldValue = yieldValue + tradeManager:CalculateOriginYieldFromPath(originCity:GetOwner(), originCity:GetID(), destinationCity:GetOwner(), destinationCity:GetID(), yieldIndex);
	-- From modifiers
	local resourceID = -1;
	yieldValue = yieldValue + tradeManager:CalculateOriginYieldFromModifiers(originCity:GetOwner(), originCity:GetID(), destinationCity:GetOwner(), destinationCity:GetID(), yieldIndex, resourceID);

	return yieldValue;
end

-- Returns yield for the destination city
function GetYieldForDestinationCity( yieldIndex:number, originCity:table, destinationCity:table )
	local tradeManager = Game.GetTradeManager();

	-- From route
	local yieldValue = tradeManager:CalculateDestinationYieldFromPotentialRoute(originCity:GetOwner(), originCity:GetID(), destinationCity:GetOwner(), destinationCity:GetID(), yieldIndex);
	-- From path
	yieldValue = yieldValue + tradeManager:CalculateDestinationYieldFromPath(originCity:GetOwner(), originCity:GetID(), destinationCity:GetOwner(), destinationCity:GetID(), yieldIndex);
	-- From modifiers
	local resourceID = -1;
	yieldValue = yieldValue + tradeManager:CalculateDestinationYieldFromModifiers(originCity:GetOwner(), originCity:GetID(), destinationCity:GetOwner(), destinationCity:GetID(), yieldIndex, resourceID);

	return yieldValue;
end

-- Returns length of trade path, number of trips to destination, turns to complete route
function GetRouteInfo(originCity:table, destinationCity:table)
	local eSpeed = GameConfiguration.GetGameSpeedType();
	
	if GameInfo.GameSpeeds[eSpeed] ~= nil then
		local iSpeedCostMultiplier = GameInfo.GameSpeeds[eSpeed].CostMultiplier;
		local tradeManager = Game.GetTradeManager();
		local pathPlots = tradeManager:GetTradeRoutePath(originCity:GetOwner(), originCity:GetID(), destinationCity:GetOwner(), destinationCity:GetID() );
		local tradePathLength:number = tablelength(pathPlots) - 1;
		local multiplierConstant:number = 0.1;

		local tripsToDestination = 1 + math.floor(iSpeedCostMultiplier/tradePathLength * multiplierConstant);
		
		--print("Error: Playing on an unrecognized speed. Defaulting to standard for route turns calculation");
		local turnsToCompleteRoute = (tradePathLength * 2 * tripsToDestination);
		return tradePathLength, tripsToDestination, turnsToCompleteRoute;
	else
		print("Speed type index " .. eSpeed);
		print("Error: Could not find game speed type. Defaulting to first entry in table");
		local iSpeedCostMultiplier =  GameInfo.GameSpeeds[1].CostMultiplier;
		local tradeManager = Game.GetTradeManager();
		local pathPlots = tradeManager:GetTradeRoutePath(originCity:GetOwner(), originCity:GetID(), destinationCity:GetOwner(), destinationCity:GetID() );
		local tradePathLength:number = tablelength(pathPlots) - 1;
		local multiplierConstant:number = 0.1;

		local tripsToDestination = 1 + math.floor(iSpeedCostMultiplier/tradePathLength * multiplierConstant);
		local turnsToCompleteRoute = (tradePathLength * 2 * tripsToDestination);
		return tradePathLength, tripsToDestination, turnsToCompleteRoute;
	end
end

-- Adds the route turns remaining to the table, if it does not exist already
function AddRouteWithTurnsRemaining( routeInfo:table, routesTable:table, addedFromConsistencyCheck:boolean)
	print("Adding route: " .. GetTradeRouteString(routeInfo));

	local originPlayer:table = Players[routeInfo.OriginCityPlayer];
	local originCity:table = originPlayer:GetCities():FindID(routeInfo.OriginCityID);

	local destinationPlayer:table = Players[routeInfo.DestinationCityPlayer];
	local destinationCity:table = destinationPlayer:GetCities():FindID(routeInfo.DestinationCityID);

	local tradePathLength, tripsToDestination, turnsToCompleteRoute = GetRouteInfo( originCity, destinationCity );

	local routeIndex = findIndex ( routesTable, routeInfo, CheckRouteEquality );

	if routeIndex == -1 then
		-- Build entry
		local routeEntry:table = {
			OriginCityPlayer 		= routeInfo.OriginCityPlayer;
			OriginCityID 			= routeInfo.OriginCityID;
			DestinationCityPlayer 	= routeInfo.DestinationCityPlayer;
			DestinationCityID 		= routeInfo.DestinationCityID;
			TraderUnitID 			= routeInfo.TraderUnitID;
			TurnsRemaining 			= turnsToCompleteRoute;
		};

		-- Optional flag
		if addedFromConsistencyCheck ~= nil then
			routeEntry.AddedFromCheck = addedFromConsistencyCheck;
		end

		-- Append entry
		table.insert(routesTable, routeEntry);
	else
		print("Route already exists in table.");
	end
end

-- Returns the remaining turns, if it exists in the table. Else returns -1
function GetRouteTurnsRemaining( routeInfo:table )
	local routeIndex = findIndex( m_LocalPlayerRunningRoutes, routeInfo, CheckRouteEquality );

	if routeIndex > 0 then
		return m_LocalPlayerRunningRoutes[routeIndex].TurnsRemaining;
	end

	return -1;
end

-- Decrements routes present. Removes those that completed
function UpdateRoutesWithTurnsRemaining( routesTable:table )
	local routesToDeleteIndex:table = {};

	for i, route in ipairs(routesTable) do
		if route.TurnsRemaining then
			route.TurnsRemaining = route.TurnsRemaining - 1;
			print("Updated route " .. GetTradeRouteString(route) .. " with turns remaining " .. route.TurnsRemaining)
			
			if route.TurnsRemaining <= 0 then
				table.insert(routesToDeleteIndex, i);
			end
		end
	end

	for i, index in ipairs(routesToDeleteIndex) do
		print("Removing route: " .. GetTradeRouteString(routesTable[index]));
		table.remove(routesTable, index);
	end

	m_LastTurnUpdatedMyRoutes = Game.GetCurrentGameTurn();
end

-- Checks if my running routes and the routes table are consistent with each other
function CheckConsistencyWithMyRunningRoutes( routesTable:table )
	local routesCurrentlyRunningIndices:table = {};

	local localPlayerCities:table = Players[Game.GetLocalPlayer()]:GetCities();
	for i,city in localPlayerCities:Members() do
		local outgoingRoutes = city:GetTrade():GetOutgoingRoutes();
		for j, routeInfo in ipairs(outgoingRoutes) do
			local routeIndex = findIndex( routesTable, routeInfo, CheckRouteEquality );

			-- Is the route not present?
			if routeIndex == -1 then
				-- Add it to the list, and set the optional flag
				print(GetTradeRouteString(routeInfo) .. " was not present. Adding it to the table.");
				AddRouteWithTurnsRemaining( routeInfo, routesTable, true);
				table.insert(routesCurrentlyRunningIndices, tablelength(routesTable))
			else
				-- Add flag to check later
				table.insert(routesCurrentlyRunningIndices, routeIndex)
			end
		end
	end

	-- Add all indices not present routesCurrentlyRunningIndices
	local routesNotRunningIndices = {};
	for index, route in ipairs(routesTable) do
		if findIndex(routesCurrentlyRunningIndices, index, function(a, b) return a == b; end ) == -1 then
			table.insert(routesNotRunningIndices, index);
		end
	end

	-- Delete all routes not running
	for _, index in ipairs(routesNotRunningIndices) do
		print(GetTradeRouteString(routesTable[index]) .. " is not running. Removing it from the table.");
		table.remove(routesTable, index);
	end
end

-- Finds and removes the route from the global table
function RemoveFromAvailableRoutesTable( targetRoute:table )
	if m_groupBySelected == GROUP_BY_SETTINGS.NONE then
		local targetIndex:number;

		for i, route in ipairs(m_AvailableTradeRoutes) do
			if CheckRouteEquality( route, targetRoute ) then
				targetIndex = i;
			end		
		end

		-- Remove route
		if targetIndex then
			table.remove(m_AvailableTradeRoutes, targetIndex);
		end

	-- If grouping by something, go one level deeper
	else
		local targetIndex:number;
		local targetGroupIndex:number;

		for i, groupedRoutes in ipairs(m_AvailableTradeRoutes) do
			for j, route in ipairs(groupedRoutes) do
				if CheckRouteEquality( route, targetRoute ) then
					targetIndex = j;
					targetGroupIndex = i;
				end
			end
		end

		-- Remove route
		if targetIndex then
			table.remove(m_AvailableTradeRoutes[targetGroupIndex], targetIndex);
		end
		-- If that group is empty, remove that group
		if tablelength(m_AvailableTradeRoutes[targetGroupIndex]) <= 0 then
			if targetGroupIndex then
				table.remove(m_AvailableTradeRoutes, targetGroupIndex);
			end
		end
	end
end

-- Returns a string of the route in format "[ORIGIN_CITY_NAME]-[DESTINATION_CITY_NAME]"
function GetTradeRouteString( routeInfo:table )
	local originPlayer:table = Players[routeInfo.OriginCityPlayer];
	local originCity:table = originPlayer:GetCities():FindID(routeInfo.OriginCityID);

	local destinationPlayer:table = Players[routeInfo.DestinationCityPlayer];
	local destinationCity:table = destinationPlayer:GetCities():FindID(routeInfo.DestinationCityID);


	local s:string = Locale.Lookup(originCity:GetName()) .. "-" .. Locale.Lookup(destinationCity:GetName())
	return s;
end

-- Checks if the two routes are the same (does not compare traderUnit)
function CheckRouteEquality ( tradeRoute1:table, tradeRoute2:table )
	if ( 	tradeRoute1.OriginCityPlayer == tradeRoute2.OriginCityPlayer and
			tradeRoute1.OriginCityID == tradeRoute2.OriginCityID and
			tradeRoute1.DestinationCityPlayer == tradeRoute2.DestinationCityPlayer and
			tradeRoute1.DestinationCityID == tradeRoute2.DestinationCityID ) then
		return true;
	end

	return false;
end

-- Checks equality with the passed sorting compare function
function CheckEquality( tradeRoute1:table, tradeRoute2:table, compareFunction )
	if not compareFunction(tradeRoute1, tradeRoute2) then
		if not compareFunction(tradeRoute2, tradeRoute1) then
			return true;
		end
	end

	return false;
end

-- ===========================================================================
--	Button handler functions
-- ===========================================================================

function OnOpen()
	Refresh();
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

	Refresh();
end

function OnGroupBySelected( index:number, groupByIndex:number )
	m_groupBySelected = groupByIndex;
	Controls.OverviewGroupByButton:SetText(m_groupByList[m_groupBySelected].groupByString);

	-- Have to rebuild table
	m_HasBuiltTradeRouteTable = false;
	Refresh();
end

-- ---------------------------------------------------------------------------
-- Checkbox
-- ---------------------------------------------------------------------------
function OnGroupShowAll()

	-- Dont do anything, if grouping is none
	if m_groupBySelected == GROUP_BY_SETTINGS.NONE then
		return;
	end

	m_GroupShowAll = Controls.GroupShowAllCheckBox:IsChecked();

	if not m_GroupShowAll then
		Controls.GroupShowAllCheckBoxLabel:SetText("Expand All:");
		m_cityRouteLimitExclusionList = {};
	else
		Controls.GroupShowAllCheckBoxLabel:SetText("Collapse All:");
		m_cityRouteLimitExclusionList = {};
	end
	
	Refresh();
end

-- ---------------------------------------------------------------------------
-- Sort bar insert buttons
-- ---------------------------------------------------------------------------
function OnSortByFood()
	-- If shift is not being pressed, reset sort settings
	if not m_shiftDown then
		if m_ctrlDown then
			m_SortBySettings = {};
		else
			m_GroupSortBySettings = {};
		end
	end

	-- Sort based on currently showing icon toggled
	if Controls.FoodDescArrow:IsHidden() then
		if m_ctrlDown then
			InsertSortEntry(SORT_BY_ID.FOOD, SORT_DESCENDING, m_SortBySettings);
		else
			InsertSortEntry(SORT_BY_ID.FOOD, SORT_DESCENDING, m_GroupSortBySettings);
		end
	else
		if m_ctrlDown then
			InsertSortEntry(SORT_BY_ID.FOOD, SORT_ASCENDING, m_SortBySettings);
		else
			InsertSortEntry(SORT_BY_ID.FOOD, SORT_ASCENDING, m_GroupSortBySettings);
		end
	end

	Refresh();
end

function OnSortByProduction()
	-- If shift is not being pressed, reset sort settings
	if not m_shiftDown then
		if m_ctrlDown then
			m_SortBySettings = {};
		else
			m_GroupSortBySettings = {};
		end
	end

	-- Sort based on currently showing icon toggled
	if Controls.ProductionDescArrow:IsHidden() then
		if m_ctrlDown then
			InsertSortEntry(SORT_BY_ID.PRODUCTION, SORT_DESCENDING, m_SortBySettings);
		else
			InsertSortEntry(SORT_BY_ID.PRODUCTION, SORT_DESCENDING, m_GroupSortBySettings);
		end
	else
		if m_ctrlDown then
			InsertSortEntry(SORT_BY_ID.PRODUCTION, SORT_ASCENDING, m_SortBySettings);
		else
			InsertSortEntry(SORT_BY_ID.PRODUCTION, SORT_ASCENDING, m_GroupSortBySettings);
		end
	end

	Refresh();
end

function OnSortByGold()
	-- If shift is not being pressed, reset sort settings
	if not m_shiftDown then
		if m_ctrlDown then
			m_SortBySettings = {};
		else
			m_GroupSortBySettings = {};
		end
	end

	-- Sort based on currently showing icon toggled
	if Controls.GoldDescArrow:IsHidden() then
		if m_ctrlDown then
			InsertSortEntry(SORT_BY_ID.GOLD, SORT_DESCENDING, m_SortBySettings);
		else
			InsertSortEntry(SORT_BY_ID.GOLD, SORT_DESCENDING, m_GroupSortBySettings);
		end
	else
		if m_ctrlDown then
			InsertSortEntry(SORT_BY_ID.GOLD, SORT_ASCENDING, m_SortBySettings);
		else
			InsertSortEntry(SORT_BY_ID.GOLD, SORT_ASCENDING, m_GroupSortBySettings);
		end
	end

	Refresh();
end

function OnSortByScience()
	-- If shift is not being pressed, reset sort settings
	if not m_shiftDown then
		if m_ctrlDown then
			m_SortBySettings = {};
		else
			m_GroupSortBySettings = {};
		end
	end

	-- Sort based on currently showing icon toggled
	if Controls.ScienceDescArrow:IsHidden() then
		if m_ctrlDown then
			InsertSortEntry(SORT_BY_ID.SCIENCE, SORT_DESCENDING, m_SortBySettings);
		else
			InsertSortEntry(SORT_BY_ID.SCIENCE, SORT_DESCENDING, m_GroupSortBySettings);
		end
	else
		if m_ctrlDown then
			InsertSortEntry(SORT_BY_ID.SCIENCE, SORT_ASCENDING, m_SortBySettings);
		else
			InsertSortEntry(SORT_BY_ID.SCIENCE, SORT_ASCENDING, m_GroupSortBySettings);
		end
	end

	Refresh();
end

function OnSortByCulture()
	-- If shift is not being pressed, reset sort settings
	if not m_shiftDown then
		if m_ctrlDown then
			m_SortBySettings = {};
		else
			m_GroupSortBySettings = {};
		end
	end

	-- Sort based on currently showing icon toggled
	if Controls.CultureDescArrow:IsHidden() then
		if m_ctrlDown then
			InsertSortEntry(SORT_BY_ID.CULTURE, SORT_DESCENDING, m_SortBySettings);
		else
			InsertSortEntry(SORT_BY_ID.CULTURE, SORT_DESCENDING, m_GroupSortBySettings);
		end
	else
		if m_ctrlDown then
			InsertSortEntry(SORT_BY_ID.CULTURE, SORT_ASCENDING, m_SortBySettings);
		else
			InsertSortEntry(SORT_BY_ID.CULTURE, SORT_ASCENDING, m_GroupSortBySettings);
		end
	end

	Refresh();
end

function OnSortByFaith()
	-- If shift is not being pressed, reset sort settings
	if not m_shiftDown then
		if m_ctrlDown then
			m_SortBySettings = {};
		else
			m_GroupSortBySettings = {};
		end
	end

	-- Sort based on currently showing icon toggled
	if Controls.FaithDescArrow:IsHidden() then
		if m_ctrlDown then
			InsertSortEntry(SORT_BY_ID.FAITH, SORT_DESCENDING, m_SortBySettings);
		else
			InsertSortEntry(SORT_BY_ID.FAITH, SORT_DESCENDING, m_GroupSortBySettings);
		end
	else
		if m_ctrlDown then
			InsertSortEntry(SORT_BY_ID.FAITH, SORT_ASCENDING, m_SortBySettings);
		else
			InsertSortEntry(SORT_BY_ID.FAITH, SORT_ASCENDING, m_GroupSortBySettings);
		end
	end

	Refresh();
end

function OnSortByTurnsToComplete()
	-- If shift is not being pressed, reset sort settings
	if not m_shiftDown then
		if m_ctrlDown then
			m_SortBySettings = {};
		else
			m_GroupSortBySettings = {};
		end
	end

	-- Sort based on currently showing icon toggled
	if Controls.TurnsToCompleteDescArrow:IsHidden() then
		if m_ctrlDown then
			InsertSortEntry(SORT_BY_ID.TURNS_TO_COMPLETE, SORT_DESCENDING, m_SortBySettings);
		else
			InsertSortEntry(SORT_BY_ID.TURNS_TO_COMPLETE, SORT_DESCENDING, m_GroupSortBySettings);
		end
	else
		if m_ctrlDown then
			InsertSortEntry(SORT_BY_ID.TURNS_TO_COMPLETE, SORT_ASCENDING, m_SortBySettings);
		else
			InsertSortEntry(SORT_BY_ID.TURNS_TO_COMPLETE, SORT_ASCENDING, m_GroupSortBySettings);
		end
	end

	Refresh();
end

-- ---------------------------------------------------------------------------
-- Sort bar delete buttons
-- ---------------------------------------------------------------------------
function OnNotSortByFood()
	if m_ctrlDown then
		RemoveSortEntry( SORT_BY_ID.FOOD, m_SortBySettings);
	else
		RemoveSortEntry( SORT_BY_ID.FOOD, m_GroupSortBySettings);
	end

	Refresh();
end

function OnNotSortByProduction()
	if m_ctrlDown then
		RemoveSortEntry( SORT_BY_ID.PRODUCTION, m_SortBySettings);
	else
		RemoveSortEntry( SORT_BY_ID.PRODUCTION, m_GroupSortBySettings);
	end

	Refresh();
end

function OnNotSortByGold()
	if m_ctrlDown then
		RemoveSortEntry( SORT_BY_ID.GOLD, m_SortBySettings);
	else
		RemoveSortEntry( SORT_BY_ID.GOLD, m_GroupSortBySettings);
	end

	Refresh();
end

function OnNotSortByScience()
	if m_ctrlDown then
		RemoveSortEntry( SORT_BY_ID.SCIENCE, m_SortBySettings);
	else
		RemoveSortEntry( SORT_BY_ID.SCIENCE, m_GroupSortBySettings);
	end

	Refresh();
end

function OnNotSortByCulture()
	if m_ctrlDown then
		RemoveSortEntry( SORT_BY_ID.CULTURE, m_SortBySettings);
	else
		RemoveSortEntry( SORT_BY_ID.CULTURE, m_GroupSortBySettings);
	end

	Refresh();
end

function OnNotSortByFaith()
	if m_ctrlDown then
		RemoveSortEntry( SORT_BY_ID.FAITH, m_SortBySettings);
	else
		RemoveSortEntry( SORT_BY_ID.FAITH, m_GroupSortBySettings);
	end

	Refresh();
end

function OnNotSortByTurnsToComplete()
	if m_ctrlDown then
		RemoveSortEntry( SORT_BY_ID.TURNS_TO_COMPLETE, m_SortBySettings);
	else
		RemoveSortEntry( SORT_BY_ID.TURNS_TO_COMPLETE, m_GroupSortBySettings);
	end

	Refresh();
end


-- ===========================================================================
--	Helper Utility functions
-- ===========================================================================

function tablelength(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

function reverseTable(T)
	table_length = tablelength(T);

	for i=1, math.floor(table_length / 2) do
		local tmp = T[i]
		T[i] = T[table_length - i + 1]
		T[table_length - i + 1] = tmp
	end
end

function findIndex(T, searchItem, compareFunc)
	for index, item in ipairs(T) do
		if compareFunc(item, searchItem) then
			return index;
		end
	end

	return -1;
end

-- ===========================================================================
--	LUA Event
--	Explicit close (from partial screen hooks), part of closing everything,
-- ===========================================================================

function OnCloseAllExcept( contextToStayOpen:string )
	if contextToStayOpen == ContextPtr:GetID() then return; end
	Close();
end

-- ===========================================================================
--	Game Event
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

	-- Dont call update, if game turn has not changed. Needs this check, otherwise it calls this hook
	-- even if the turn has not ended.
	if m_LastTurnUpdatedMyRoutes < Game.GetCurrentGameTurn() then
		UpdateRoutesWithTurnsRemaining( m_LocalPlayerRunningRoutes );
	end

	m_HasBuiltTradeRouteTable = false;
end

function OnLocalPlayerTurnBegin()
	-- RebuildAvailableTradeRoutesTable();
	-- UpdateRoutesWithTurnsRemaining( m_LocalPlayerRunningRoutes );
end

-- ===========================================================================
--	UI EVENTS
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
--	LUA EVENT
--	Reload support
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

function OnUnitOperationStarted( ownerID:number, unitID:number, operationID:number )
	if ownerID == Game.GetLocalPlayer() and operationID == UnitOperationTypes.MAKE_TRADE_ROUTE then
		-- Unit was just started a trade route. Find the route, and update the tables
		local localPlayerCities:table = Players[ownerID]:GetCities();
		for i,city in localPlayerCities:Members() do
			local outgoingRoutes = city:GetTrade():GetOutgoingRoutes();
			for j,route in ipairs(outgoingRoutes) do
				if route.TraderUnitID == unitID then
					-- Add it to the local players runnning routes
					AddRouteWithTurnsRemaining( route, m_LocalPlayerRunningRoutes );

					-- Remove it from the available routes
					RemoveFromAvailableRoutesTable(route);
				end
			end
		end

		-- Dont refresh, if the window is hidden
		if not ContextPtr:IsHidden() then
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
	-- Input handler
	ContextPtr:SetInputHandler( OnInputHandler, true );

	-- Control Events
	Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);
	Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.MyRoutesButton:RegisterCallback(Mouse.eLClick,			OnMyRoutesButton);
	Controls.MyRoutesButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.RoutesToCitiesButton:RegisterCallback(Mouse.eLClick,	OnRoutesToCitiesButton);
	Controls.RoutesToCitiesButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.AvailableRoutesButton:RegisterCallback(Mouse.eLClick,	OnAvailableRoutesButton);
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

	Controls.GroupShowAllCheckBox:RegisterCallback( eLClick, OnGroupShowAll );
	Controls.GroupShowAllCheckBox:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

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
	-- Events.LocalPlayerTurnBegin.Add ( OnLocalPlayerTurnBegin );
 
	-- Hot-Reload Events
	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
end
Initialize();