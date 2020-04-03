include("InstanceManager");
include("SupportFunctions");
include("CivilizationIcon");
include("LoyaltySupport");

--CQUI Members
local CQUI_ShowCityDetailAdvisor :boolean = false;

function CQUI_OnSettingsUpdate()
  CQUI_ShowCityDetailAdvisor = GameConfiguration.GetValue("CQUI_ShowCityDetailAdvisor") == 1
end
LuaEvents.CQUI_SettingsUpdate.Add(CQUI_OnSettingsUpdate);
LuaEvents.CQUI_SettingsInitialized.Add(CQUI_OnSettingsUpdate);

local m_kPopulationGraphIM:table = InstanceManager:new( "PopulationGraphInstance",	"Top", Controls.PopulationGraphStack );
local m_kIdentityBreakdownIM:table = InstanceManager:new( "CulturalIdentityLineInstance",	"Top", Controls.IdentityBreakdownStack );
local m_kPlayerPresenceBreakdownIM:table = InstanceManager:new( "InfluenceLineInstance",	"Top", Controls.InfluenceStack );
-- ===========================================================================
function OnRefresh()
	if ContextPtr:IsHidden() then
		return;
	end
	
	local localPlayerID = Game.GetLocalPlayer();
	local pPlayer = Players[localPlayerID];
	if (pPlayer == nil) then
		return;
	end
	local pCity = UI.GetHeadSelectedCity();
	if (pCity == nil) then
		return;
	end

	local pPlayerConfig = PlayerConfigurations[localPlayerID];
	local kPlayerGovernors = pPlayer:GetGovernors();
	local pCulturalIdentity = pCity:GetCulturalIdentity();
	
	-- Gather cultural identity data
	local conversionOutcome = pCulturalIdentity:GetConversionOutcome();
	local turnsToConversion = pCulturalIdentity:GetTurnsToConversion();
	
	--[[
	-- Keep track of native and total populations
	local nativePopulation = 0;
	local totalPopulation = 0;
	local populationGraphTooltip:string = "";

	m_kPopulationGraphIM:ResetInstances();

	-- Add populations to population graph
	for _, identity in pairs(identitiesInCity) do
		-- Add a newline if this isn't the first entry
		if populationGraphTooltip ~= "" then
			populationGraphTooltip = populationGraphTooltip .. "[NEWLINE]";
		end

		-- Cache the native population
		if identity.Player == Game.GetLocalPlayer() then
			nativePopulation = identity.NumCitizens;
		end

		populationGraphTooltip = AddCivToPopulationGraph(identity.Player, identity.NumCitizens, populationGraphTooltip);
		
		-- Add to total population
		totalPopulation = totalPopulation + identity.NumCitizens;
	end

	-- Set population graph tooltip
	Controls.PopulationGraphContainer:DoAutoSize();
	Controls.PopulationGraphContainer:SetToolTipString(populationGraphTooltip);

	-- Update native vs total population count
	Controls.NativePopulationCount:SetText(tostring(nativePopulation));
	Controls.TotalPopulationCount:SetText(tostring(totalPopulation));

	local pPlayerConfig = PlayerConfigurations[Game.GetLocalPlayer()];
	local civID:number = pPlayerConfig:GetCivilizationTypeID();
	local civAdjective:string = GameInfo.Civilizations[civID].Adjective;
	Controls.NativePopulationName:SetText(Locale.Lookup(civAdjective));
	--]]

	-- Loyalty
	local currentLoyalty = pCulturalIdentity:GetLoyalty();
	local maxLoyalty = pCulturalIdentity:GetMaxLoyalty();
	Controls.CurrentLoyalty:SetText(Locale.Lookup("LOC_CULTURAL_IDENTITY_LOYALTY", Round(currentLoyalty, 1)));
	Controls.MaxLoyalty:SetText(Locale.Lookup("LOC_CULTURAL_IDENTITY_TOTAL_LOYALTY", maxLoyalty));

	local loyaltyLevel = pCulturalIdentity:GetLoyaltyLevel();
	local loyaltyLevelName = GameInfo.LoyaltyLevels[loyaltyLevel].Name;
	Controls.LoyaltyStatus:LocalizeAndSetText(loyaltyLevelName);

	-- Determine which pressure font icon to use
	local loyaltyPerTurn:number = pCulturalIdentity:GetLoyaltyPerTurn();
	local loyaltyFontIcon:string = loyaltyPerTurn >= 0 and "[ICON_PressureUp]" or "[ICON_PressureDown]";

	local loyalStatusTooltip:string = GetLoyaltyStatusTooltip(pCity);
	local loyaltyPercent:number = currentLoyalty / maxLoyalty;
	local loyaltyFillToolTip:string = Locale.Lookup("LOC_LOYALTY_STATUS_TT", loyaltyFontIcon, Round(currentLoyalty,1), maxLoyalty, loyalStatusTooltip);
	Controls.LoyaltyFill:SetToolTipString(loyaltyFillToolTip);
	Controls.LoyaltyFill:SetPercent(loyaltyPercent);

	-- Update loyalty percentage string
	Controls.LoyaltyPressureIcon:SetToolTipString(GetLoyaltyPressureIconTooltip(loyaltyPerTurn, localPlayerID));
	Controls.LoyaltyPressureIcon:SetText(loyaltyFontIcon);

	local potentialNewOwner = pCulturalIdentity:GetPotentialTransferPlayer();
	if potentialNewOwner ~= -1 then
		local ownerController = CivilizationIcon:AttachInstance(Controls.CivilizationOwner);
		ownerController:UpdateIconFromPlayerID(localPlayerID);

		local ownerCivIconTooltip:string = Locale.Lookup("LOC_LOYALTY_CITY_IS_LOYAL_TO_TT", Locale.Lookup(pPlayerConfig:GetCivilizationDescription()));
		Controls.CivilizationOwner.CivIconBacking:SetToolTipString(ownerCivIconTooltip);

		local rivalController = CivilizationIcon:AttachInstance(Controls.CivilizationRival);
		rivalController:UpdateIconFromPlayerID(potentialNewOwner);

		local pNewOwnerConfig = PlayerConfigurations[potentialNewOwner];
		local newOwnerCivIconTooltip:string = Locale.Lookup("LOC_LOYALTY_CITY_IS_LOYAL_TO_TT", Locale.Lookup(pNewOwnerConfig:GetCivilizationDescription()));
		Controls.CivilizationRival.CivIconBacking:SetToolTipString(newOwnerCivIconTooltip);
	else
		Controls.CivilizationOwner.CivIconBacking:SetHide(true);
		Controls.CivilizationRival.CivIconBacking:SetHide(true);
	end

	-- Identity Strengths and Sources
	m_kIdentityBreakdownIM:ResetInstances();
	local pressureBreakdown:table = pCulturalIdentity:GetIdentitySourcesDetailedBreakdown();
	for _,innerTable in ipairs(pressureBreakdown) do
		local scoreSource, scoreValue = next(innerTable);
		if (scoreValue > 0) then
			local lineInstance = m_kIdentityBreakdownIM:GetInstance();
			lineInstance.LineTitle:SetText(scoreSource);
			lineInstance.LineValue:SetText(Round(scoreValue, 1));
		elseif (scoreValue < 0) then
			local lineInstance = m_kIdentityBreakdownIM:GetInstance();
			lineInstance.LineTitle:SetText("[COLOR_RED]" .. scoreSource .. "[ENDCOLOR]");
			lineInstance.LineValue:SetText("[COLOR_RED]" .. Round(scoreValue, 1) .. "[ENDCOLOR]");
		end
	end

	--Final, Total Line
	local totalLineInstance = m_kIdentityBreakdownIM:GetInstance();
	totalLineInstance.LineTitle:SetText(Locale.Lookup("LOC_CULTURAL_IDENTITY_LOYALTY_LINE"));
	totalLineInstance.LineValue:SetText(Locale.Lookup(pCulturalIdentity:GetLoyaltyPerTurnStatus()) .. " " .. Round(pCulturalIdentity:GetLoyaltyPerTurn(), 1));
	Controls.IdentityBreakdownStack:CalculateSize();
	Controls.BreakdownBox:SetSizeY(Controls.IdentityBreakdownStack:GetSizeY() + 15);
	totalLineInstance.Top:SetColor(RGBAValuesToABGRHex(.3, .3, .3, .85));

	-- Identity Totals
	if (loyaltyLevel < 3) then
		local growthReduction = (GameInfo.LoyaltyLevels[loyaltyLevel].GrowthChange * 100);
		local yieldPercentage = (GameInfo.LoyaltyLevels[loyaltyLevel].YieldChange * 100);
		Controls.CulturalIdentityEffectLabel:SetText(Locale.Lookup("LOC_LOYALTY_GROWTH_AND_YIELD_EFFECTS_TEXT", growthReduction, yieldPercentage));
	else
		Controls.CulturalIdentityEffectLabel:SetText(Locale.Lookup("LOC_LOYALTY_EFFECT_NONE"));
	end

	Controls.CulturalIdentityEffectBox:SetSizeY(Controls.CulturalIdentityEffectLabel:GetSizeY() + 15);

	-- Loyalty Advisor
    Controls.CulturalIdentityAdvice:SetText(pCity:GetLoyaltyAdvice());
    -- AZURENCY : hide the advisor if option is disabled
    Controls.CulturalIdentityAdvisor:SetHide( CQUI_ShowCityDetailAdvisor == false );

	--Diplomatic Presence
	local identitiesInCity = pCulturalIdentity:GetPlayerIdentitiesInCity();
	m_kPlayerPresenceBreakdownIM:ResetInstances();
	if next(identitiesInCity) == nil then
		Controls.DiplomaticInfluenceHeader:SetHide(true);
		Controls.InfluenceBox:SetHide(true);
	else
		Controls.DiplomaticInfluenceHeader:SetHide(false);
		Controls.InfluenceBox:SetHide(false);
		table.sort(identitiesInCity, function(left, right)
			return left.IdentityTotal > right.IdentityTotal;
		end);

		for i, playerPresence in ipairs(identitiesInCity) do
			local instance = m_kPlayerPresenceBreakdownIM:GetInstance();
			local pPlayerConfig = PlayerConfigurations[playerPresence.Player];
			local civName = Locale.Lookup(pPlayerConfig:GetCivilizationDescription());
			local lineVal = (i == 1 and "[ICON_Bolt] " or "") .. playerPresence.IdentityTotal;
			instance.LineTitle:SetText(civName);
			instance.LineValue:SetText(lineVal);

			local civIconManager = CivilizationIcon:AttachInstance(instance.CivilizationIcon);
			civIconManager:UpdateIconFromPlayerID(playerPresence.Player);
		end
	end
	Controls.InfluenceStack:CalculateSize();
	Controls.InfluenceBox:SetSizeY(Controls.InfluenceStack:GetSizeY() + 20);

	-- Update Assigned Governor data
	local pAssignedGovernor = pCity:GetAssignedGovernor();
	if (pAssignedGovernor ~= nil) then
		local eGovernorType = pAssignedGovernor:GetType();
		local governorDefinition = GameInfo.Governors[eGovernorType];

		local governorName = pAssignedGovernor:GetName();
		local governorTitle = governorDefinition.Title;
		local governorEffects = governorDefinition.Description;
		local bIsEstablished = pAssignedGovernor:IsEstablished();
		local iTurnsOnSite = pAssignedGovernor:GetTurnsOnSite();
		local iBaseTurnsToEstablish = pAssignedGovernor:GetTurnsToEstablish();
		local iTurnsUntilEstablished = iBaseTurnsToEstablish - iTurnsOnSite;

		Controls.GovernorIcon:SetHide(false);
		Controls.GovernorIcon:SetIcon("ICON_" .. governorDefinition.GovernorType);
		Controls.GovernorName:SetText(Locale.Lookup(governorName));
		Controls.GovernorTitle:SetText(Locale.Lookup(governorTitle));
		Controls.GovernorEffects:SetText(Locale.Lookup(governorEffects));

		if (bIsEstablished) then
			Controls.GovernorEstablishmentText:SetText(Locale.Lookup("LOC_HUD_CITY_GOVERNOR_ESTABLISHED"));
			Controls.TurnsOnSite:SetHide(true);
		else
			Controls.GovernorEstablishmentText:SetText(Locale.Lookup("LOC_GOVERNORS_SCREEN_GOVERNOR_TRANSITIONING_TO"));
			Controls.TurnsOnSite:SetText(Locale.Lookup("LOC_HUD_CITY_GOVERNOR_TURNS", iTurnsUntilEstablished));
			local percent = 100;
			if (iBaseTurnsToEstablish ~= 0) then
				percent = iTurnsOnSite / iBaseTurnsToEstablish;
			end
			Controls.TurnsOnSite:SetHide(false);
		end
	else
		Controls.GovernorIcon:SetHide(true);
		Controls.GovernorName:SetText("");
		Controls.GovernorTitle:SetText(Locale.Lookup("LOC_HUD_CITY_NO_GOVERNOR"));
		Controls.GovernorEffects:SetText(Locale.Lookup("LOC_HUD_CITY_NO_GOVERNOR_EFFECT"));
		Controls.GovernorEstablishmentText:SetText("");
		Controls.TurnsOnSite:SetHide(true);
	end

	Controls.TabStack:CalculateSize();
end

-- ===========================================================================
function OnTabStackSizeChanged()
	-- Manually resize the context to fit the child stack
	ContextPtr:SetSizeX(Controls.TabStack:GetSizeX());
	ContextPtr:SetSizeY(Controls.TabStack:GetSizeY());
end

-- ===========================================================================
function AddCivToPopulationGraph( playerID:number, populationCount:number, tooltip:string )
	local secondaryColor, primaryColor = UI.GetPlayerColors( playerID );
	for var=1, populationCount, 1 do
		local instance:table = m_kPopulationGraphIM:GetInstance();
		instance.Top:SetColor(secondaryColor);
	end

	local playerConfig:table = PlayerConfigurations[playerID];
	if playerConfig then
		local civID:number = playerConfig:GetCivilizationTypeID();
		local civAdjective:string = GameInfo.Civilizations[civID].Adjective;
		tooltip = tooltip .. Locale.Lookup("LOC_HUD_CITY_POPULATION_GRAPH_TOOLTIP", populationCount, Locale.Lookup(civAdjective));
	end

	return tooltip;
end

-- ===========================================================================
function OnToggleLoyaltyPanel(pCity:table)
	if (pCity ~= nil) then
		UI.LookAtPlot(pCity:GetX(), pCity:GetY());
		UI.SelectCity(pCity);
		LuaEvents.CityPanel_ToggleOverviewLoyalty();
	end
end

-- ===========================================================================
function Initialize()
	LuaEvents.CityPanelTabRefresh.Add(OnRefresh);
	Events.GovernorAssigned.Add( OnRefresh );
	Events.GovernorChanged.Add( OnRefresh );
	Events.CitySelectionChanged.Add( OnRefresh );
	Events.CityLoyaltyChanged.Add( OnRefresh );

	LuaEvents.CityPanelCulture_ToggleLoyalty.Add( OnToggleLoyaltyPanel );

	Controls.TabStack:RegisterSizeChanged( OnTabStackSizeChanged );
end
Initialize();