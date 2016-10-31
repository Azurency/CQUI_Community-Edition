print("Better Trade Screen loaded")

-- ===========================================================================
--	SETTINGS
-- ===========================================================================

local colorTradeCivilizationHeader = true
local tintTradeRouteEntry = true
local alignTradeYields = true
local showNoBenefitsString = true
local groupByPlayers = false				-- This setting only applies to all available routes tab

-- Advanced Settings
-- Color Settings for Trade Civ Header
local backdropDarkerColorOffset = 40		-- Higher for a darker color
local backdropDarkerColorOpacity = 205		-- Value ranges from 0 (transparent) to 255 (fully opaque)
local backdropBrighterColorOffset = 7 		-- Higher for a brighter color
local backdropBrighterColorOpacity = 205	-- Value ranges from 0 (transparent) to 255 (fully opaque)

-- Color Settings for Route Entry
local tintColorOffset = 75					-- Higher for brighter, and lower for darker. Can go negative.
local tintColorOpacity = 150				-- Value ranges from 0 (transparent) to 255 (fully opaque)

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
local DATA_ICON_PREFIX:string = "ICON_";

local TRADE_TABS:table = {
	MY_ROUTES			= 0;
	ROUTES_TO_CITIES	= 1;
	AVAILABLE_ROUTES	= 2;
};

local m_currentTab:number;

local SORT_FUNCTIONS_ID:table = {
	FOOD = 1,
	PRODUCTION = 2,
	GOLD = 3,
	SCIENCE = 4,
	CULTURE = 5,
	FAITH = 6,
	TURNS_TO_COMPLETE = 7
}

local SORT_ASCENDING = 1
local SORT_DESCENDING = -1

-- ===========================================================================
--	VARIABLES
-- ===========================================================================

local m_RouteInstanceIM:table			= InstanceManager:new("RouteInstance", "Top", Controls.BodyStack);
local m_HeaderInstanceIM:table			= InstanceManager:new("HeaderInstance", "Top", Controls.BodyStack);
local m_SimpleButtonInstanceIM:table	= InstanceManager:new("SimpleButtonInstance", "Top", Controls.BodyStack);

local m_AnimSupport:table; -- AnimSidePanelSupport

-- Stores filter list and tracks the currently selected list
local m_filterList:table = {};
local m_filterCount:number = 0;
local m_filterSelected:number = 1;

local m_TradeUnitIndex:number 			= 0;
local m_TradeUnitList:table 			= {};
local m_LastTradeRoute:number			= -1;

local m_TradeRouteCounter:number		= 0;

-- Stores the sort settings. Default is ascending in turns to complete trade route
local m_CurrentSortByID					= 7;
local m_CurrentSortByOrder				= SORT_ASCENDING;
local m_CompareFunctionByID	= {};

m_CompareFunctionByID[SORT_FUNCTIONS_ID.FOOD]				= function(a, b) return compareByFood(a, b) end;
m_CompareFunctionByID[SORT_FUNCTIONS_ID.PRODUCTION]			= function(a, b) return compareByProduction(a, b) end;
m_CompareFunctionByID[SORT_FUNCTIONS_ID.GOLD]				= function(a, b) return compareByGold(a, b) end;
m_CompareFunctionByID[SORT_FUNCTIONS_ID.SCIENCE]			= function(a, b) return compareByScience(a, b) end;
m_CompareFunctionByID[SORT_FUNCTIONS_ID.CULTURE]			= function(a, b) return compareByCulture(a, b) end;
m_CompareFunctionByID[SORT_FUNCTIONS_ID.FAITH]				= function(a, b) return compareByFaith(a, b) end;
m_CompareFunctionByID[SORT_FUNCTIONS_ID.TURNS_TO_COMPLETE]	= function(a, b) return compareByTurnsToComplete(a, b) end;

-- Safety checks for settings
backdropDarkerColorOpacity = Clamp(backdropDarkerColorOpacity, 0, 255);
backdropBrighterColorOpacity = Clamp(backdropBrighterColorOpacity, 0, 255);
tintColorOpacity = Clamp(tintColorOpacity, 0, 255);

-- Show My Routes Tab
function ViewMyRoutes()
	-- Reset Trade Route Counter
	m_TradeRouteCounter = 0;

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

	-- Gather data and sort
	local routesSortedByPlayer:table = {};
	local localPlayerCities:table = Players[Game.GetLocalPlayer()]:GetCities();
	for i,city in localPlayerCities:Members() do
		local outgoingRoutes = city:GetTrade():GetOutgoingRoutes();
		for i,route in ipairs(outgoingRoutes) do
			if m_filterList[m_filterSelected].FilterFunction and m_filterList[m_filterSelected].FilterFunction(Players[route.DestinationCityPlayer]) then
				-- Make sure we have a table for each destination player
				if routesSortedByPlayer[route.DestinationCityPlayer] == nil then
					local routes:table = {};
					routesSortedByPlayer[route.DestinationCityPlayer] = {};
				end

				table.insert(routesSortedByPlayer[route.DestinationCityPlayer], route);
			end
		end
	end

	-- Add routes to local player cities
	if routesSortedByPlayer[Game.GetLocalPlayer()] ~= nil then
		CreatePlayerHeader(Players[Game.GetLocalPlayer()]);

		sortTradeRoutes(routesSortedByPlayer[Game.GetLocalPlayer()]);

		for i,route in ipairs(routesSortedByPlayer[Game.GetLocalPlayer()]) do
			AddRouteFromRouteInfo(route);
		end
	end

	-- Add routes to other civs
	local haveAddedCityStateHeader:boolean = false;
	for playerID,routes in pairs(routesSortedByPlayer) do
		if playerID ~= Game.GetLocalPlayer() then
			sortTradeRoutes ( routes );

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
	-- Reset Trade Route Counter
	m_TradeRouteCounter = 0;

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
		sortTradeRoutes( routes )

		for i,route in ipairs(routes) do
			AddRouteFromRouteInfo(route);
		end
	end
end

-- Show Available Routes Tab
function ViewAvailableRoutes()
	-- Reset Trade Route Counter
	m_TradeRouteCounter = 0;

	local tradeRoutes = {};

	-- Update Tabs
	SetMyRoutesTabSelected(false);
	SetRoutesToCitiesTabSelected(false);
	SetAvailableRoutesTabSelected(true);

	local tradeManager:table = Game.GetTradeManager();

	-- Update Header
	Controls.HeaderLabel:SetText(Locale.ToUpper("LOC_TRADE_OVERVIEW_AVAILABLE_ROUTES"));
	Controls.ActiveRoutesLabel:SetHide(true);

	local sourceCities:table = Players[Game.GetLocalPlayer()]:GetCities();
	local players:table = Game:GetPlayers();
	local hasTradeRouteWithCityStates:boolean = false;

	for i, destinationPlayer in ipairs(players) do
		if m_filterList[m_filterSelected].FilterFunction and m_filterList[m_filterSelected].FilterFunction(destinationPlayer) then
			local hasTradeRouteWithPlayer:boolean = false
			for j, sourceCity in sourceCities:Members() do			
				local destinationCities:table = destinationPlayer:GetCities();				
				for k, destinationCity in destinationCities:Members() do
					-- Can we trade with this city / civ
					if tradeManager:CanStartRoute(sourceCity:GetOwner(), sourceCity:GetID(), destinationCity:GetOwner(), destinationCity:GetID()) then
						-- Add Civ/CityState Header
						if groupByPlayers then
							local pPlayerInfluence:table = Players[destinationPlayer:GetID()]:GetInfluence();
							if not pPlayerInfluence:CanReceiveInfluence() then
								-- If first available route with this city add a city header
								if not hasTradeRouteWithPlayer then
									hasTradeRouteWithPlayer = true;
									CreatePlayerHeader(destinationPlayer);
								end
							else
								-- If first available route to a city state then add a city state header
								if not hasTradeRouteWithCityStates then
									hasTradeRouteWithCityStates = true;
									CreateCityStateHeader();
								end
							end
						end
						
						-- Append trade route entry
						local tradeRoute = { 
							OriginCityPlayer 		= Game.GetLocalPlayer(), 
							OriginCityID 			= sourceCity:GetID(), 
							DestinationCityPlayer 	= destinationPlayer:GetID(), 
							DestinationCityID 		= destinationCity:GetID()
						};

						table.insert(tradeRoutes, tradeRoute);
					end
				end
			end

			if groupByPlayers then
				-- If not a ciy state sort table and show in UI
				local destinationPlayerInfluence:table = destinationPlayer:GetInfluence();
				if not destinationPlayerInfluence:CanReceiveInfluence() then
					sortTradeRoutes( tradeRoutes );
					AddRoutesFromTable( tradeRoutes );
					tradeRoutes = {}
				end
			end
		end
	end

	-- If you have any remaining trade routes, sort them and show in UI
	if tradeRoutes then
		sortTradeRoutes( tradeRoutes );
		AddRoutesFromTable( tradeRoutes );
	end
end

-- ===========================================================================
function SetMyRoutesTabSelected( isSelected:boolean )
	Controls.MyRoutesButton:SetSelected(isSelected);
	Controls.MyRoutesTabLabel:SetHide(isSelected);
	Controls.MyRoutesSelectedArrow:SetHide(not isSelected);
	Controls.MyRoutesTabSelectedLabel:SetHide(not isSelected);
end

-- ===========================================================================
function SetRoutesToCitiesTabSelected( isSelected:boolean )
	Controls.RoutesToCitiesButton:SetSelected(isSelected);
	Controls.RoutesToCitiesTabLabel:SetHide(isSelected);
	Controls.RoutesToCitiesSelectedArrow:SetHide(not isSelected);
	Controls.RoutesToCitiesTabSelectedLabel:SetHide(not isSelected);
end

-- ===========================================================================
function SetAvailableRoutesTabSelected( isSelected:boolean )
	Controls.AvailableRoutesButton:SetSelected(isSelected);
	Controls.AvailableRoutesTabLabel:SetHide(isSelected);
	Controls.AvailableRoutesSelectedArrow:SetHide(not isSelected);
	Controls.AvailableRoutesTabSelectedLabel:SetHide(not isSelected);
end

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

-- ===========================================================================
function AddProduceTradeUnitButton()
	local simpleButtonInstance:table = m_SimpleButtonInstanceIM:GetInstance();
	simpleButtonInstance.GridButton:SetText(Locale.Lookup("LOC_TRADE_OVERVIEW_PRODUCE_TRADE_UNIT"));
	simpleButtonInstance.GridButton:SetDisabled(true);
end

-- ===========================================================================
function AddRoutesFromTable ( tradeRoutes:table )
	for index, route in ipairs(tradeRoutes) do
		AddRouteFromRouteInfo(route);
	end
end

-- ===========================================================================
function AddRouteFromRouteInfo(routeInfo:table)
	local originPlayer:table = Players[routeInfo.OriginCityPlayer];
	local originCity:table = originPlayer:GetCities():FindID(routeInfo.OriginCityID);

	local destinationPlayer:table = Players[routeInfo.DestinationCityPlayer];
	local destinationCity:table = destinationPlayer:GetCities():FindID(routeInfo.DestinationCityID);

	AddRoute(originPlayer, originCity, destinationPlayer, destinationCity);
end

-- ===========================================================================
function AddRoute(originPlayer:table, originCity:table, destinationPlayer:table, destinationCity:table)
	m_TradeRouteCounter = m_TradeRouteCounter + 1;

	-- print("Adding route: " .. Locale.Lookup(originCity:GetName()) .. " to " .. Locale.Lookup(destinationCity:GetName()));

	local routeInstance:table = m_RouteInstanceIM:GetInstance();

	if tintTradeRouteEntry then
		local backColor, frontColor = UI.GetPlayerColors( destinationPlayer:GetID() );

		backColor = DarkenLightenColor(backColor, tintColorOffset, tintColorOpacity);
		frontColor = DarkenLightenColor(frontColor, tintColorOffset, tintColorOpacity);

		local destinationPlayerInfluence:table = destinationPlayer:GetInfluence();
		if destinationPlayerInfluence:CanReceiveInfluence() then
			routeInstance.GridButton:SetColor(frontColor);
		else
			routeInstance.GridButton:SetColor(backColor);
		end
	end

	-- Update Route Label
	routeInstance.RouteLabel:SetText(Locale.ToUpper(originCity:GetName()) .. " " .. Locale.ToUpper("LOC_TRADE_OVERVIEW_TO") .. " " .. Locale.ToUpper(destinationCity:GetName()));

	-- Update Arrows
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
	
	if isCityStateWithTradeQuest(destinationPlayer) then
		questTooltip = questTooltip .. "[NEWLINE]" .. tradeRouteQuestInfo.IconString .. questsManager:GetActiveQuestName(Game.GetLocalPlayer(), destinationCity:GetOwner(), tradeRouteQuestInfo.Index);
		routeInstance.CityStateQuestIcon:SetHide(false);
		routeInstance.CityStateQuestIcon:SetToolTipString(questTooltip);
	end

	-- Update Diplomatic Visibility
	routeInstance.VisibilityBonusGrid:SetHide(false);
	routeInstance.TourismBonusGrid:SetHide(false);

	-- Do we have player headers or is it a local trade route
	if groupByPlayers or isCityState(destinationPlayer) or originPlayer:GetID() == destinationPlayer:GetID() then
		routeInstance.VisibilityBonusGrid:SetHide(true);
		routeInstance.TourismBonusGrid:SetHide(true);
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
	if destinationCity:GetTrade():HasActiveTradingPost(originPlayer) then
		routeInstance.TradingPostIndicator:SetAlpha(1.0);
		routeInstance.TradingPostIndicator:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_TRADE_POST_ESTABLISHED");
	else
		routeInstance.TradingPostIndicator:SetAlpha(0.2);
		routeInstance.TradingPostIndicator:LocalizeAndSetToolTip("LOC_TRADE_OVERVIEW_TOOLTIP_NO_TRADE_POST");
	end

	-- Update distance to city
	local distanceToDestination:number = Map.GetPlotDistance(originCity:GetX(), originCity:GetY(), destinationCity:GetX(), destinationCity:GetY());
	routeInstance.RouteDistance:SetText(distanceToDestination);

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
					table.insert(tradeUnits, pUnit);

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
				-- Close the select route overview, if open
				LuaEvents.TradeOverview_CloseRouteFromOverview();
				cycleTradeUnit(tradeUnits, m_TradeRouteCounter, originCity);
			end
		);
	end
end

-- ===========================================================================
function sortTradeRoutes( tradeRoutes:table )
	if m_CurrentSortByID ~= 0 then
		local compareFunction = m_CompareFunctionByID[m_CurrentSortByID];
		table.sort(tradeRoutes, compareFunction)

		if m_CurrentSortByOrder == SORT_DESCENDING then
			reverseTable(tradeRoutes);
		end
	end
end

-- ===========================================================================
function getTradeRouteString( tradeRoute:table )
	local originPlayer:table = Players[routeInfo.OriginCityPlayer];
	local originCity:table = originPlayer:GetCities():FindID(routeInfo.OriginCityID);

	local destinationPlayer:table = Players[routeInfo.DestinationCityPlayer];
	local destinationCity:table = destinationPlayer:GetCities():FindID(routeInfo.DestinationCityID);


	local s:string = Locale.Lookup(originCity:GetName()) .. "-" .. Locale.Lookup(destinationCity:GetName())
	return s;
end

-- ===========================================================================
function compareByFood( tradeRoute1:table, tradeRoute2:table )
	return compareByYield (GameInfo.Yields["YIELD_FOOD"].Index, tradeRoute1, tradeRoute2);
end

-- ===========================================================================
function compareByProduction( tradeRoute1:table, tradeRoute2:table )
	return compareByYield (GameInfo.Yields["YIELD_PRODUCTION"].Index, tradeRoute1, tradeRoute2);
end

-- ===========================================================================
function compareByGold( tradeRoute1:table, tradeRoute2:table )
	return compareByYield (GameInfo.Yields["YIELD_GOLD"].Index, tradeRoute1, tradeRoute2);
end

-- ===========================================================================
function compareByScience( tradeRoute1:table, tradeRoute2:table )
	return compareByYield (GameInfo.Yields["YIELD_SCIENCE"].Index, tradeRoute1, tradeRoute2);
end

-- ===========================================================================
function compareByCulture( tradeRoute1:table, tradeRoute2:table )
	return compareByYield (GameInfo.Yields["YIELD_CULTURE"].Index, tradeRoute1, tradeRoute2);
end

-- ===========================================================================
function compareByFaith( tradeRoute1:table, tradeRoute2:table )
	return compareByYield (GameInfo.Yields["YIELD_FAITH"].Index, tradeRoute1, tradeRoute2);
end

-- ===========================================================================
function compareByYield( yieldIndex:number, tradeRoute1:table, tradeRoute2:table )
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

-- ===========================================================================
function compareByTurnsToComplete( tradeRoute1:table, tradeRoute2:table )
	local originPlayer1:table = Players[tradeRoute1.OriginCityPlayer];
	local destinationPlayer1:table = Players[tradeRoute1.DestinationCityPlayer];
	local originCity1:table = originPlayer1:GetCities():FindID(tradeRoute1.OriginCityID);
	local destinationCity1:table = destinationPlayer1:GetCities():FindID(tradeRoute1.DestinationCityID);

	local originPlayer2:table = Players[tradeRoute2.OriginCityPlayer];
	local destinationPlayer2:table = Players[tradeRoute2.DestinationCityPlayer];
	local originCity2:table = originPlayer2:GetCities():FindID(tradeRoute2.OriginCityID);
	local destinationCity2:table = destinationPlayer2:GetCities():FindID(tradeRoute2.DestinationCityID);

	local distanceToDestination1:number = Map.GetPlotDistance(originCity1:GetX(), originCity1:GetY(), destinationCity1:GetX(), destinationCity1:GetY());
	local distanceToDestination2:number = Map.GetPlotDistance(originCity2:GetX(), originCity2:GetY(), destinationCity2:GetX(), destinationCity2:GetY());

	return distanceToDestination1 < distanceToDestination2;
end

-- ===========================================================================
function cycleTradeUnit( tradeUnits:table, tradeRouteID:number, newOriginCity:table )

	if m_LastTradeRoute ~= tradeRouteID then
		m_TradeUnitIndex = 1;
		m_LastTradeRoute = tradeRouteID;
	end

	print("Cycling units. Select unit with index: " .. m_TradeUnitIndex .. " and length: " .. tablelength(tradeUnits))
	SelectUnit( tradeUnits[m_TradeUnitIndex] );
	LuaEvents.TradeOverview_ChangeOriginCityFromOverview( newOriginCity );

	-- Open the change origin city window, and select the new city
	m_TradeUnitIndex = m_TradeUnitIndex + 1;
	if m_TradeUnitIndex > tablelength(tradeUnits) then
		m_TradeUnitIndex = 1;
	end
end

-- ===========================================================================
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
	AddFilter("Other Major Civilizations", isOtherMajorCiv);

	-- Add "City States" Filter
	AddFilter("City-States", isCityState);

	-- Add "City States with Trade Quest" Filter
	AddFilter("City-States with Trade Quest", isCityStateWithTradeQuest);

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

-- ===========================================================================
function AddFilter(filterName:string, filterFunction)
	-- Make sure we don't add duplicate filters
	for index, filter in ipairs(m_filterList) do
		if filter.FilterText == filterName then
			return;
		end
	end

	m_filterCount = m_filterCount + 1;
	m_filterList[m_filterCount] = {FilterText=filterName, FilterFunction=filterFunction};
end

-- ===========================================================================
function AddFilterEntry(filterIndex:number)
	local filterEntry:table = {};
	Controls.OverviewDestinationFilterPulldown:BuildEntry( "OverviewFilterEntry", filterEntry );
	filterEntry.Button:SetText(m_filterList[filterIndex].FilterText);
	filterEntry.Button:SetVoids(i, filterIndex);
end

-- ===========================================================================
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
function Refresh()
	PreRefresh();

	RefreshFilters();
	RefreshSortBar();

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

-- ===========================================================================
function PreRefresh()
	-- Reset Stack
	m_RouteInstanceIM:ResetInstances();
	m_HeaderInstanceIM:ResetInstances();
	m_SimpleButtonInstanceIM:ResetInstances();
end

-- ===========================================================================
function PostRefresh()
	-- Calculate Stack Sizess
	Controls.HeaderStack:CalculateSize();
	Controls.HeaderStack:ReprocessAnchoring();
	Controls.BodyScrollPanel:CalculateSize();
	Controls.BodyScrollPanel:ReprocessAnchoring();
	Controls.BodyScrollPanel:CalculateInternalSize();
end

-- ===========================================================================
-- Create Player Header Instance
function CreatePlayerHeader(player:table)
	local headerInstance:table = m_HeaderInstanceIM:GetInstance();

	local pPlayerConfig:table = PlayerConfigurations[player:GetID()];
	headerInstance.HeaderLabel:SetText(Locale.ToUpper(pPlayerConfig:GetPlayerName()));

	if colorTradeCivilizationHeader then
		headerInstance.BannerDarker:SetHide(false);

		local backColor, frontColor = UI.GetPlayerColors( player:GetID() );
		local darkerBackColor:number = DarkenLightenColor(backColor, -backdropDarkerColorOffset, backdropDarkerColorOpacity);
		local brighterBackColor:number = DarkenLightenColor(backColor, backdropBrighterColorOffset, backdropBrighterColorOpacity);
		local brighterFrontColor:number = DarkenLightenColor(frontColor, -10, 235);

		headerInstance.HeaderLabel:SetColor(brighterFrontColor);
		headerInstance.HeaderGrid:SetColor(brighterBackColor);
		headerInstance.BannerDarker:SetColor(darkerBackColor);
	else
		-- Hide the colored UI elements
		headerInstance.BannerDarker:SetHide(true);
	end

	if player:GetID() ~=  Players[Game.GetLocalPlayer()]:GetID() then
		-- Determine are diplomatic visibility status
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
		headerInstance.TourismBonusGrid:SetHide(true);
		headerInstance.VisibilityBonusGrid:SetHide(true);
	end
end

-- Create City State Header Instance
function CreateCityStateHeader()
	local headerInstance:table = m_HeaderInstanceIM:GetInstance();
	
	headerInstance.BannerDarker:SetHide(true);
	
	-- Reset Color for city states
	headerInstance.HeaderGrid:SetColor(0xFF666666);

	headerInstance.HeaderLabel:SetColorByName("Beige");
	headerInstance.HeaderLabel:SetText(Locale.ToUpper("LOC_TRADE_OVERVIEW_CITY_STATES"));

	headerInstance.VisibilityBonusGrid:SetHide(true);
	headerInstance.TourismBonusGrid:SetHide(true);
	headerInstance.BannerDarker:SetHide(true);
end

-- Create Unused Routes Header Instance
function CreateUnusedRoutesHeader()
	local headerInstance:table = m_HeaderInstanceIM:GetInstance();

	headerInstance.HeaderLabel:SetText(Locale.ToUpper("LOC_TRADE_OVERVIEW_UNUSED_ROUTES"));

	headerInstance.VisibilityBonusGrid:SetHide(true);
	headerInstance.TourismBonusGrid:SetHide(true);
end

-- ===========================================================================
function isCityState( player:table )
	local playerInfluence:table = player:GetInfluence();
	if  playerInfluence:CanReceiveInfluence() then
		return true
	end

	return false
end

function isCityStateWithTradeQuest( player:table )
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

-- ===========================================================================
function isOtherMajorCiv( player:table )
	if player:IsMajor() and player:GetID() ~= Game.GetLocalPlayer() then
		return true
	end

	return false
end

-- ===========================================================================
function GetYieldFromCity(yieldIndex:number, originCity:table, destinationCity:table)
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

-- ===========================================================================
function GetYieldForDestinationCity(yieldIndex:number, originCity:table, destinationCity:table)
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

-- ===========================================================================
function RefreshSortBar()
	-- Hide all arrows
	resetSortBar();

	-- Set arrows based on current settings
	if m_CurrentSortByID == 0 then
		m_CurrentSortByOrder = 0
	elseif m_CurrentSortByID == SORT_FUNCTIONS_ID.FOOD then
		setSortArrow(Controls.FoodAscArrow, Controls.FoodDescArrow, m_CurrentSortByOrder)
	elseif m_CurrentSortByID == SORT_FUNCTIONS_ID.PRODUCTION then
		setSortArrow(Controls.ProductionAscArrow, Controls.ProductionDescArrow, m_CurrentSortByOrder)
	elseif m_CurrentSortByID == SORT_FUNCTIONS_ID.GOLD then
		setSortArrow(Controls.GoldAscArrow, Controls.GoldDescArrow, m_CurrentSortByOrder)
	elseif m_CurrentSortByID == SORT_FUNCTIONS_ID.SCIENCE then
		setSortArrow(Controls.ScienceAscArrow, Controls.ScienceDescArrow, m_CurrentSortByOrder)
	elseif m_CurrentSortByID == SORT_FUNCTIONS_ID.CULTURE then
		setSortArrow(Controls.CultureAscArrow, Controls.CultureDescArrow, m_CurrentSortByOrder)
	elseif m_CurrentSortByID == SORT_FUNCTIONS_ID.FAITH then
		setSortArrow(Controls.FaithAscArrow, Controls.FaithDescArrow, m_CurrentSortByOrder)
	elseif m_CurrentSortByID == SORT_FUNCTIONS_ID.TURNS_TO_COMPLETE then
		setSortArrow(Controls.TurnsToCompleteAscArrow, Controls.TurnsToCompleteDescArrow, m_CurrentSortByOrder)
	end
end

-- ===========================================================================
function setSortArrow( ascArrow:table, descArrow:table, sortOrder:number)
	if sortOrder == SORT_ASCENDING then
		descArrow:SetHide(true);
		ascArrow:SetHide(false);
	else
		descArrow:SetHide(false);
		ascArrow:SetHide(true);
	end
end

-- ===========================================================================
function resetSortBar()
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

-- ===========================================================================
function Open()
	m_AnimSupport.Show();
	UI.PlaySound("CityStates_Panel_Open");
end

-- ===========================================================================
function Close()	
    if not ContextPtr:IsHidden() then
        UI.PlaySound("CityStates_Panel_Close");
    end
	m_AnimSupport.Hide();
end

-- ===========================================================================
function OnOpen()
	Refresh();
	Open();
end

-- ===========================================================================
function OnMyRoutesButton()
	m_currentTab = TRADE_TABS.MY_ROUTES;
	Refresh();
end

-- ===========================================================================
function OnRoutesToCitiesButton()
	m_currentTab = TRADE_TABS.ROUTES_TO_CITIES;
	Refresh();
end

-- ===========================================================================
function OnAvailableRoutesButton()
	m_currentTab = TRADE_TABS.AVAILABLE_ROUTES;
	Refresh();
end

-- ===========================================================================
function OnClose()
	Close();
end

-- ===========================================================================
function OnFilterSelected(index:number, filterIndex:number)
	m_filterSelected = filterIndex;
	Controls.OverviewFilterButton:SetText(m_filterList[m_filterSelected].FilterText);

	Refresh();
end

-- ===========================================================================
function OnSortByFood()

	-- Sort based on currently showing icon toggled
	if Controls.FoodDescArrow:IsHidden() then
		m_CurrentSortByOrder = SORT_DESCENDING;
	else
		m_CurrentSortByOrder = SORT_ASCENDING;
	end

	m_CurrentSortByID = SORT_FUNCTIONS_ID.FOOD;

	Refresh();
end

-- ===========================================================================
function OnSortByProduction()

	-- Sort based on currently showing icon toggled
	if Controls.ProductionDescArrow:IsHidden() then
		m_CurrentSortByOrder = SORT_DESCENDING;
	else
		m_CurrentSortByOrder = SORT_ASCENDING;
	end

	m_CurrentSortByID = SORT_FUNCTIONS_ID.PRODUCTION;

	Refresh();
end

-- ===========================================================================
function OnSortByGold()

	-- Sort based on currently showing icon toggled
	if Controls.GoldDescArrow:IsHidden() then
		m_CurrentSortByOrder = SORT_DESCENDING;
	else
		m_CurrentSortByOrder = SORT_ASCENDING;
	end

	m_CurrentSortByID = SORT_FUNCTIONS_ID.GOLD;

	Refresh();
end

-- ===========================================================================
function OnSortByScience()

	-- Sort based on currently showing icon toggled
	if Controls.ScienceDescArrow:IsHidden() then
		m_CurrentSortByOrder = SORT_DESCENDING;
	else
		m_CurrentSortByOrder = SORT_ASCENDING;
	end

	m_CurrentSortByID = SORT_FUNCTIONS_ID.SCIENCE;

	Refresh();
end

-- ===========================================================================
function OnSortByCulture()

	-- Sort based on currently showing icon toggled
	if Controls.CultureDescArrow:IsHidden() then
		m_CurrentSortByOrder = SORT_DESCENDING;
	else
		m_CurrentSortByOrder = SORT_ASCENDING;
	end

	m_CurrentSortByID = SORT_FUNCTIONS_ID.CULTURE;

	Refresh();
end

-- ===========================================================================
function OnSortByFaith()

	-- Sort based on currently showing icon toggled
	if Controls.FaithDescArrow:IsHidden() then
		m_CurrentSortByOrder = SORT_DESCENDING;
	else
		m_CurrentSortByOrder = SORT_ASCENDING;
	end

	m_CurrentSortByID = SORT_FUNCTIONS_ID.FAITH;

	Refresh();
end

-- ===========================================================================
function OnSortByTurnsToComplete()

	-- Sort based on currently showing icon toggled
	if Controls.TurnsToCompleteDescArrow:IsHidden() then
		m_CurrentSortByOrder = SORT_DESCENDING;
	else
		m_CurrentSortByOrder = SORT_ASCENDING;
	end

	m_CurrentSortByID = SORT_FUNCTIONS_ID.TURNS_TO_COMPLETE;

	Refresh();
end

-- ===========================================================================
function tablelength(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

-- ===========================================================================
function reverseTable(T)
	table_length = tablelength(T);

	for i=1, math.floor(table_length / 2) do
		local tmp = T[i]
		T[i] = T[table_length - i + 1]
		T[table_length - i + 1] = tmp
	end
end

-- ===========================================================================
--	LUA Event
--	Explicit close (from partial screen hooks), part of closing everything,
-- ===========================================================================
function OnCloseAllExcept( contextToStayOpen:string )
	if contextToStayOpen == ContextPtr:GetID() then return; end
	Close();
end

------------------------------------------------------------------------------------------------
function OnLocalPlayerTurnEnd()
	if(GameConfiguration.IsHotseat()) then
		Close();
	end
end

-- ===========================================================================
--	Game Event
-- ===========================================================================
function OnInterfaceModeChanged(eOldMode:number, eNewMode:number)
	if eNewMode == InterfaceModeTypes.VIEW_MODAL_LENS then
		Close();
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isHidden", ContextPtr:IsHidden());
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "currentTab", m_currentTab);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "currentSortSetting", m_CurrentSortByID);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "currentSortOrder", m_CurrentSortByOrder);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "filterSelected", m_filterSelected) ;
end

-- ===========================================================================
--	LUA EVENT
--	Reload support
-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
	if context == RELOAD_CACHE_ID then
		if contextTable["isHidden"] ~= nil and not contextTable["isHidden"] then			
			Open();
		end
		if contextTable["currentSortSetting"] ~= nil then
			if contextTable["currentSortOrder"] ~= nil then
				m_CurrentSortByID = contextTable["currentSortSetting"]
				m_CurrentSortByOrder = contextTable["currentSortOrder"]
				RefreshSortBar();
			end
		end
		if contextTable["filterSelected"] ~= nil then
			m_filterSelected = contextTable["filterSelected"];
			RefreshFilters();
		end
		if contextTable["currentTab"] ~= nil then
			m_currentTab = contextTable["currentTab"];
			Refresh();
		end
	end
end

-- ===========================================================================
function OnUnitOperationStarted(ownerID:number, unitID:number, operationID:number)
	if m_AnimSupport.IsVisible() and operationID == UnitOperationTypes.MAKE_TRADE_ROUTE then
		Refresh();
	end
end

-- ===========================================================================
function OnPolicyChanged( ePlayer )
	if m_AnimSupport.IsVisible() and ePlayer == Game.GetLocalPlayer() then
		Refresh();
	end
end

-- ===========================================================================
function Initialize()

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
	Controls.FoodSortButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ProductionSortButton:RegisterCallback( Mouse.eLClick, OnSortByProduction);
	Controls.ProductionSortButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.GoldSortButton:RegisterCallback( Mouse.eLClick, OnSortByGold);
	Controls.GoldSortButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ScienceSortButton:RegisterCallback( Mouse.eLClick, OnSortByScience);
	Controls.ScienceSortButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.CultureSortButton:RegisterCallback( Mouse.eLClick, OnSortByCulture);
	Controls.CultureSortButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.FaithSortButton:RegisterCallback( Mouse.eLClick, OnSortByFaith);
	Controls.FaithSortButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.TurnsToCompleteSortButton:RegisterCallback( Mouse.eLClick, OnSortByTurnsToComplete);
	Controls.TurnsToCompleteSortButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	--Filter Pulldown
	Controls.OverviewFilterButton:RegisterCallback( eLClick, UpdateFilterArrow );
	Controls.OverviewDestinationFilterPulldown:RegisterSelectionCallback( OnFilterSelected );

	-- Lua Events
	LuaEvents.PartialScreenHooks_OpenTradeOverview.Add( OnOpen );
	LuaEvents.PartialScreenHooks_CloseTradeOverview.Add( OnClose );
	LuaEvents.PartialScreenHooks_CloseAllExcept.Add( OnCloseAllExcept );

	-- Animation Controller
	m_AnimSupport = CreateScreenAnimation(Controls.SlideAnim);

	-- Rundown / Screen Events
	Events.SystemUpdateUI.Add(m_AnimSupport.OnUpdateUI);
	ContextPtr:SetInputHandler(m_AnimSupport.OnInputHandler, true);

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