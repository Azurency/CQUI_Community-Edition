-- ===========================================================================
--	ReportScreen
--	All the data
--
-- ===========================================================================
include("CitySupport");
include("Civ6Common");
include("InstanceManager");
include("SupportFunctions");
include("TabSupport");


-- ===========================================================================
--	DEBUG
--	Toggle these for temporary debugging help.
-- ===========================================================================
local m_debugFullHeight				:boolean = true;		-- (false) if the screen area should resize to full height of the available space.
local m_debugNumResourcesStrategic	:number = 0;			-- (0) number of extra strategics to show for screen testing.
local m_debugNumBonuses				:number = 0;			-- (0) number of extra bonuses to show for screen testing.
local m_debugNumResourcesLuxuries	:number = 0;			-- (0) number of extra luxuries to show for screen testing.


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local DARKEN_CITY_INCOME_AREA_ADDITIONAL_Y		:number = 6;
local DATA_FIELD_SELECTION						:string = "Selection";
local SIZE_HEIGHT_BOTTOM_YIELDS					:number = 135;
local SIZE_HEIGHT_PADDING_BOTTOM_ADJUST			:number = 85;	-- (Total Y - (scroll area + THIS PADDING)) = bottom area
local INDENT_STRING								:string = "        ";

-- Mapping of unit type to cost.
local UnitCostMap:table = {};
do
  for row in GameInfo.Units() do
    UnitCostMap[row.UnitType] = row.Maintenance;
  end
end

-- !! Added function to sort out tables for units
local bUnits = { group = {}, parent = {}, type = "" }

function spairs( t, order )
    local keys = {}

    for k in pairs(t) do keys[#keys+1] = k end

    if order then
      table.sort(keys, function(a,b) return order(t, a, b) end)
    else
      table.sort(keys)
    end

    local i = 0
    return function()
      i = i + 1
      if keys[i] then
        return keys[i], t[keys[i]]
      end
    end
  end
-- !! end of function

-- ===========================================================================
--	VARIABLES
-- ===========================================================================

m_simpleIM = InstanceManager:new("SimpleInstance",			"Top",		Controls.Stack);				-- Non-Collapsable, simple
m_tabIM = InstanceManager:new("TabInstance",				"Button",	Controls.TabContainer);
local m_groupIM				      :table = InstanceManager:new("GroupInstance",			"Top",		Controls.Stack);				-- Collapsable
local m_bonusResourcesIM	  :table = InstanceManager:new("ResourceAmountInstance",	"Info",		Controls.BonusResources);
local m_luxuryResourcesIM	  :table = InstanceManager:new("ResourceAmountInstance",	"Info",		Controls.LuxuryResources);
local m_strategicResourcesIM:table = InstanceManager:new("ResourceAmountInstance",	"Info",		Controls.StrategicResources);

m_tabs = nil;
m_kCityData = nil;
local m_kCityTotalData	:table = nil;
local m_kUnitData			  :table = nil;	-- TODO: Show units by promotion class
local m_kResourceData		:table = nil;
local m_kDealData			  :table = nil;
local m_uiGroups			  :table = nil;	-- Track the groups on-screen for collapse all action.

local m_isCollapsing		:boolean = true;

-- !! new variables
local m_kCultureData	  :table = nil;
local m_kCurrentDeals	  :table = nil;
-- !!

-- Remember last tab variable: ARISTOS
local m_kCurrentTab = 1
-- !!

local CQUI_HousingFromImprovementsTable :table = {};

-- ===========================================================================
--	Single exit point for display
-- ===========================================================================
function Close()
	if not ContextPtr:IsHidden() then
		UI.PlaySound("UI_Screen_Close");
	end

  UIManager:DequeuePopup(ContextPtr);
end


-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnCloseButton()
  Close();
end

-- ===========================================================================
--	Single entry point for display
-- ===========================================================================
function Open()
  UIManager:QueuePopup( ContextPtr, PopupPriority.Normal );
  Controls.ScreenAnimIn:SetToBeginning();
  Controls.ScreenAnimIn:Play();
  UI.PlaySound("UI_Screen_Open");

  -- !! new line to add new variables
  -- m_kCityData, m_kCityTotalData, m_kResourceData, m_kUnitData, m_kDealData = GetData();
  m_kCityData, m_kCityTotalData, m_kResourceData, m_kUnitData, m_kDealData, m_kCultureData, m_kCurrentDeals = GetData();

  -- To remember the last opened tab when the report is re-opened: ARISTOS
  m_tabs.SelectTab( m_kCurrentTab );
end

-- ===========================================================================
--	LUA Events
--	Opened via the top panel
-- ===========================================================================
function OnTopOpenReportsScreen()
  Open();
end

-- ===========================================================================
--	LUA Events
--	Closed via the top panel
-- ===========================================================================
function OnTopCloseReportsScreen()
  Close();
end

-- ===========================================================================
--	UI Callback
--	Collapse all the things!
-- ===========================================================================
function OnCollapseAllButton()
  if m_uiGroups == nil or table.count(m_uiGroups) == 0 then
    return;
  end

  for i,instance in ipairs( m_uiGroups ) do
    if instance["isCollapsed"] ~= m_isCollapsing then
      instance["isCollapsed"] = m_isCollapsing;
      instance.CollapseAnim:Reverse();
      RealizeGroup( instance );
    end
  end
  Controls.CollapseAll:LocalizeAndSetText(m_isCollapsing and "LOC_HUD_REPORTS_EXPAND_ALL" or "LOC_HUD_REPORTS_COLLAPSE_ALL");
  m_isCollapsing = not m_isCollapsing;
end

-- ===========================================================================
--	Populate with all data required for any/all report tabs.
-- ===========================================================================
function GetData()
  local kResources	:table = {};
  local kCityData		:table = {};
  local kCityTotalData:table = {
    Income	= {},
    Expenses= {},
    Net		= {},
    Treasury= {}
  };
  local kUnitData		:table = {};


  kCityTotalData.Income[YieldTypes.CULTURE]	= 0;
  kCityTotalData.Income[YieldTypes.FAITH]		= 0;
  kCityTotalData.Income[YieldTypes.FOOD]		= 0;
  kCityTotalData.Income[YieldTypes.GOLD]		= 0;
  kCityTotalData.Income[YieldTypes.PRODUCTION]= 0;
  kCityTotalData.Income[YieldTypes.SCIENCE]	= 0;
  kCityTotalData.Income["TOURISM"]			= 0;
  kCityTotalData.Expenses[YieldTypes.GOLD]	= 0;

  local playerID	:number = Game.GetLocalPlayer();
  if playerID == PlayerTypes.NONE then
    UI.DataError("Unable to get valid playerID for report screen.");
    return;
  end

  local player	:table  = Players[playerID];
  local pCulture	:table	= player:GetCulture();
  local pTreasury	:table	= player:GetTreasury();
  local pReligion	:table	= player:GetReligion();
  local pScience	:table	= player:GetTechs();
  local pResources:table	= player:GetResources();

  -- ==========================
  -- !! this will use the m_kUnitData to fill out player's unit info
  -- ==========================
  local group_name : string = "default"

  kUnitData["Unit_Expenses"] = {}
  kUnitData["Unit_Report"] = {}

  for _, unit in player:GetUnits():Members() do
    local unitInfo : table = GameInfo.Units[unit:GetUnitType()]
    local unitGreatPerson = unit:GetGreatPerson()

    if GameInfo.GreatPersonClasses[unitGreatPerson:GetClass()] then group_name = "GREAT_PERSON"
    elseif unitInfo.MakeTradeRoute == true then group_name = "TRADER"
    elseif GameInfo.Units[unitInfo.UnitType].Spy == true then group_name = "SPY"
    elseif unit:GetReligiousStrength() > 0 then group_name = "RELIGIOUS"
    elseif unit:GetCombat() == 0 and unit:GetRangedCombat() == 0 then group_name = "CIVILIAN"
    elseif unitInfo.Domain == "DOMAIN_LAND" then group_name = "MILITARY_LAND"
    elseif unitInfo.Domain == "DOMAIN_AIR" then group_name = "MILITARY_AIR"
    elseif unitInfo.Domain == "DOMAIN_SEA" then group_name = "MILITARY_SEA"
    end

    if kUnitData["Unit_Report"][group_name] == nil then
      if group_name == "GREAT_PERSON" then
        kUnitData["Unit_Report"][group_name] = { Name = Locale.Lookup("LOC_SLOT_GREAT_PERSON_NAME"), ID = 6, func = group_great, Header = "UnitsGreatPeopleHeaderInstance", Entry = "UnitsGreatPeopleEntryInstance", units = {} }
      elseif group_name == "SPY" then
        kUnitData["Unit_Report"][group_name] = { Name = Locale.Lookup("LOC_UNIT_SPY_NAME"), ID = 8, func = group_spy, Header = "UnitsSpyHeaderInstance", Entry = "UnitsSpyEntryInstance", units = {} }
      elseif group_name == "RELIGIOUS" then
        kUnitData["Unit_Report"][group_name] = { Name = Locale.Lookup("LOC_HUD_CITY_RELIGION"), ID = 5, func = group_religious, Header = "UnitsReligiousHeaderInstance", Entry = "UnitsReligiousEntryInstance", units = {} }
      elseif group_name == "TRADER" then
        kUnitData["Unit_Report"][group_name] = { Name = Locale.Lookup("LOC_UNIT_TRADER_NAME"), ID = 7, func = group_trader, Header = "UnitsTraderHeaderInstance", Entry = "UnitsTraderEntryInstance", units = {} }
      elseif group_name == "MILITARY_LAND" then
        kUnitData["Unit_Report"][group_name] = { Name = Locale.Lookup("LOC_UNITS_MILITARY_LAND"), ID = 1, func = group_military,  Header = "UnitsMilitaryHeaderInstance", Entry = "UnitsMilitaryEntryInstance", units = {} }
      elseif group_name == "MILITARY_AIR" then
        kUnitData["Unit_Report"][group_name] = { Name = Locale.Lookup("LOC_UNITS_MILITARY_AIR"), ID = 3, func = group_military, Header = "UnitsMilitaryHeaderInstance", Entry = "UnitsMilitaryEntryInstance", units = {} }
      elseif group_name == "MILITARY_SEA" then
        kUnitData["Unit_Report"][group_name] = { Name = Locale.Lookup("LOC_UNITS_MILITARY_SEA"), ID = 2, func = group_military, Header = "UnitsMilitaryHeaderInstance", Entry = "UnitsMilitaryEntryInstance", units = {} }
      else
        kUnitData["Unit_Report"][group_name] = { Name = (Locale.Lookup("LOC_FORMATION_CLASS_CIVILIAN_NAME") .. " / " .. Locale.Lookup("LOC_FORMATION_CLASS_SUPPORT_NAME")), ID = 4, func = group_civilian, Header = "UnitsCivilianHeaderInstance", Entry = "UnitsCivilianEntryInstance", units = {} }
      end
    end

    table.insert( kUnitData["Unit_Report"][group_name].units, unit )

    if kUnitData["Unit_Expenses"][unitInfo.UnitType] == nil then
      kUnitData["Unit_Expenses"][unitInfo.UnitType] = { Name = Locale.Lookup( unitInfo.Name ), Amount = 0, Cost = unitInfo.Maintenance }
    end

    kUnitData["Unit_Expenses"][unitInfo.UnitType].Amount = kUnitData["Unit_Expenses"][unitInfo.UnitType].Amount + 1
  end
  -- ==========================
  -- !! end of edit
  -- ==========================

  local pCities = player:GetCities();
  for i, pCity in pCities:Members() do
    local cityName	:string = pCity:GetName();

    -- Big calls, obtain city data and add report specific fields to it.
    local data		:table	= GetCityData( pCity );
    data.Resources			= GetCityResourceData( pCity );					-- Add more data (not in CitySupport)
    data.WorkedTileYields	= GetWorkedTileYieldData( pCity, pCulture );	-- Add more data (not in CitySupport)

    -- Add to totals.
    kCityTotalData.Income[YieldTypes.CULTURE]	= kCityTotalData.Income[YieldTypes.CULTURE] + data.CulturePerTurn;
    kCityTotalData.Income[YieldTypes.FAITH]		= kCityTotalData.Income[YieldTypes.FAITH] + data.FaithPerTurn;
    kCityTotalData.Income[YieldTypes.FOOD]		= kCityTotalData.Income[YieldTypes.FOOD] + data.FoodPerTurn;
    kCityTotalData.Income[YieldTypes.GOLD]		= kCityTotalData.Income[YieldTypes.GOLD] + data.GoldPerTurn;
    kCityTotalData.Income[YieldTypes.PRODUCTION]= kCityTotalData.Income[YieldTypes.PRODUCTION] + data.ProductionPerTurn;
    kCityTotalData.Income[YieldTypes.SCIENCE]	= kCityTotalData.Income[YieldTypes.SCIENCE] + data.SciencePerTurn;
    kCityTotalData.Income["TOURISM"]			= kCityTotalData.Income["TOURISM"] + data.WorkedTileYields["TOURISM"];

    kCityData[cityName] = data;

    -- Add outgoing route data
    data.OutgoingRoutes = pCity:GetTrade():GetOutgoingRoutes();

    -- Add resources
    if m_debugNumResourcesStrategic > 0 or m_debugNumResourcesLuxuries > 0 or m_debugNumBonuses > 0 then
      for debugRes=1,m_debugNumResourcesStrategic,1 do
        kResources[debugRes] = {
          CityList	= { CityName="Kangaroo", Amount=(10+debugRes) },
          Icon		= "[ICON_"..GameInfo.Resources[debugRes].ResourceType.."]",
          IsStrategic	= true,
          IsLuxury	= false,
          IsBonus		= false,
          Total		= 88
        };
      end
      for debugRes=1,m_debugNumResourcesLuxuries,1 do
        kResources[debugRes] = {
          CityList	= { CityName="Kangaroo", Amount=(10+debugRes) },
          Icon		= "[ICON_"..GameInfo.Resources[debugRes].ResourceType.."]",
          IsStrategic	= false,
          IsLuxury	= true,
          IsBonus		= false,
          Total		= 88
        };
      end
      for debugRes=1,m_debugNumBonuses,1 do
        kResources[debugRes] = {
          CityList	= { CityName="Kangaroo", Amount=(10+debugRes) },
          Icon		= "[ICON_"..GameInfo.Resources[debugRes].ResourceType.."]",
          IsStrategic	= false,
          IsLuxury	= false,
          IsBonus		= true,
          Total		= 88
        };
      end
    end

    for eResourceType,amount in pairs(data.Resources) do
      AddResourceData(kResources, eResourceType, cityName, "LOC_HUD_REPORTS_TRADE_OWNED", amount);
    end
  end

  kCityTotalData.Expenses[YieldTypes.GOLD] = pTreasury:GetTotalMaintenance();

  -- NET = Income - Expense
  kCityTotalData.Net[YieldTypes.GOLD]			= kCityTotalData.Income[YieldTypes.GOLD] - kCityTotalData.Expenses[YieldTypes.GOLD];
  kCityTotalData.Net[YieldTypes.FAITH]		= kCityTotalData.Income[YieldTypes.FAITH];

  -- Treasury
  kCityTotalData.Treasury[YieldTypes.CULTURE]		= Round( pCulture:GetCultureYield(), 0 );
  kCityTotalData.Treasury[YieldTypes.FAITH]		= Round( pReligion:GetFaithBalance(), 0 );
  kCityTotalData.Treasury[YieldTypes.GOLD]		= Round( pTreasury:GetGoldBalance(), 0 );
  kCityTotalData.Treasury[YieldTypes.SCIENCE]		= Round( pScience:GetScienceYield(), 0 );
  kCityTotalData.Treasury["TOURISM"]				= Round( kCityTotalData.Income["TOURISM"], 0 );


  -- Units (TODO: Group units by promotion class and determine total maintenance cost)
  local MaintenanceDiscountPerUnit:number = pTreasury:GetMaintDiscountPerUnit();
  local pUnits :table = player:GetUnits();
  for i, pUnit in pUnits:Members() do
    local pUnitInfo:table = GameInfo.Units[pUnit:GetUnitType()];
    local TotalMaintenanceAfterDiscount:number = pUnitInfo.Maintenance - MaintenanceDiscountPerUnit;
    if TotalMaintenanceAfterDiscount > 0 then
      if kUnitData[pUnitInfo.UnitType] == nil then
        local UnitEntry:table = {};
        UnitEntry.Name = pUnitInfo.Name;
        UnitEntry.Count = 1;
        UnitEntry.Maintenance = TotalMaintenanceAfterDiscount;
        kUnitData[pUnitInfo.UnitType] = UnitEntry;
      else
        kUnitData[pUnitInfo.UnitType].Count = kUnitData[pUnitInfo.UnitType].Count + 1;
        kUnitData[pUnitInfo.UnitType].Maintenance = kUnitData[pUnitInfo.UnitType].Maintenance + TotalMaintenanceAfterDiscount;
      end
    end
  end

  -- =================================================================
  -- Current Deals Info (didn't wanna mess with diplomatic deal data
  -- below, maybe later
  -- =================================================================
  local kCurrentDeals : table = {}
  local kPlayers : table = PlayerManager.GetAliveMajors()
  local iTotal = 0

  for _, pOtherPlayer in ipairs( kPlayers ) do
    local otherID:number = pOtherPlayer:GetID()
    if  otherID ~= playerID then

      local pPlayerConfig	:table = PlayerConfigurations[otherID]
      local pDeals		:table = DealManager.GetPlayerDeals( playerID, otherID )

      if pDeals ~= nil then

        for i, pDeal in ipairs( pDeals ) do
          iTotal = iTotal + 1

          local Receiving : table = { Agreements = {}, Gold = {}, Resources = {} }
          local Sending : table = { Agreements = {}, Gold = {}, Resources = {} }

          Receiving.Resources = pDeal:FindItemsByType( DealItemTypes.RESOURCES, DealItemSubTypes.NONE, otherID )
          Receiving.Gold = pDeal:FindItemsByType( DealItemTypes.GOLD, DealItemSubTypes.NONE, otherID )
          Receiving.Agreements = pDeal:FindItemsByType( DealItemTypes.AGREEMENTS, DealItemSubTypes.NONE, otherID )

          Sending.Resources = pDeal:FindItemsByType( DealItemTypes.RESOURCES, DealItemSubTypes.NONE, playerID )
          Sending.Gold = pDeal:FindItemsByType( DealItemTypes.GOLD, DealItemSubTypes.NONE, playerID )
          Sending.Agreements = pDeal:FindItemsByType( DealItemTypes.AGREEMENTS, DealItemSubTypes.NONE, playerID )

          kCurrentDeals[iTotal] =
          {
            WithCivilization = Locale.Lookup( pPlayerConfig:GetCivilizationDescription() ),
            EndTurn = 0,
            Receiving = {},
            Sending = {}
          }

          local iDeal = 0

          for pReceivingName, pReceivingGroup in pairs( Receiving ) do
            for _, pDealItem in ipairs( pReceivingGroup ) do

              iDeal = iDeal + 1

              kCurrentDeals[iTotal].EndTurn = pDealItem:GetEndTurn()
              kCurrentDeals[iTotal].Receiving[iDeal] = { Amount = pDealItem:GetAmount() }

              local deal = kCurrentDeals[iTotal].Receiving[iDeal]

              if pReceivingName == "Agreements" then
                deal.Name = pDealItem:GetSubTypeNameID()
              elseif pReceivingName == "Gold" then
                deal.Name = deal.Amount .. " " .. Locale.Lookup("LOC_DIPLOMACY_DEAL_GOLD_PER_TURN")
                deal.Icon = "[ICON_GOLD]"
                --!! ARISTOS: To add Diplo Deal Amounts to the total tally of Gold!
                kCityTotalData.Income[YieldTypes.GOLD] = kCityTotalData.Income[YieldTypes.GOLD] + deal.Amount;
                kCityTotalData.Net[YieldTypes.GOLD] = kCityTotalData.Net[YieldTypes.GOLD] + deal.Amount;
              else
                if deal.Amount > 1 then
                  deal.Name = pDealItem:GetValueTypeNameID() .. "(" .. deal.Amount .. ")"
                else
                  deal.Name = pDealItem:GetValueTypeNameID()
                end
                deal.Icon = "[ICON_" .. pDealItem:GetValueTypeID() .. "]"
              end

              deal.Name = Locale.Lookup( deal.Name )
            end
          end

          iDeal = 0

          for pSendingName, pSendingGroup in pairs( Sending ) do
            for _, pDealItem in ipairs( pSendingGroup ) do

              iDeal = iDeal + 1

              kCurrentDeals[iTotal].EndTurn = pDealItem:GetEndTurn()
              kCurrentDeals[iTotal].Sending[iDeal] = { Amount = pDealItem:GetAmount() }

              local deal = kCurrentDeals[iTotal].Sending[iDeal]

              if pSendingName == "Agreements" then
                deal.Name = pDealItem:GetSubTypeNameID()
              elseif pSendingName == "Gold" then
                deal.Name = deal.Amount .. " " .. Locale.Lookup("LOC_DIPLOMACY_DEAL_GOLD_PER_TURN")
                deal.Icon = "[ICON_GOLD]"
                --!! ARISTOS: To add Diplo Deal Amounts to the total tally of Gold!
                --!! Diplo deal expenses are already calculated in total maintenance!! Gotta love Firaxis... :]
                -- kCityTotalData.Net[YieldTypes.GOLD] = kCityTotalData.Net[YieldTypes.GOLD] - deal.Amount;
              else
                if deal.Amount > 1 then
                  deal.Name = pDealItem:GetValueTypeNameID() .. "(" .. deal.Amount .. ")"
                else
                  deal.Name = pDealItem:GetValueTypeNameID()
                end
                deal.Icon = "[ICON_" .. pDealItem:GetValueTypeID() .. "]"
              end

              deal.Name = Locale.Lookup( deal.Name )
            end
          end
        end
      end
    end
  end

  -- =================================================================

  local kDealData	:table = {};
  local kPlayers	:table = PlayerManager.GetAliveMajors();
  for _, pOtherPlayer in ipairs(kPlayers) do
    local otherID:number = pOtherPlayer:GetID();
		local currentGameTurn = Game.GetCurrentGameTurn();
    if  otherID ~= playerID then

      local pPlayerConfig	:table = PlayerConfigurations[otherID];
      local pDeals		:table = DealManager.GetPlayerDeals(playerID, otherID);

      if pDeals ~= nil then
        for i,pDeal in ipairs(pDeals) do
            -- Add outgoing gold deals
            local pOutgoingDeal :table	= pDeal:FindItemsByType(DealItemTypes.GOLD, DealItemSubTypes.NONE, playerID);
            if pOutgoingDeal ~= nil then
              for i,pDealItem in ipairs(pOutgoingDeal) do
                local duration		:number = pDealItem:GetDuration();
                local remainingTurns:number = duration - (currentGameTurn - pDealItem:GetEnactedTurn());
                if duration ~= 0 then
                  local gold :number = pDealItem:GetAmount();
                  table.insert( kDealData, {
                    Type		= DealItemTypes.GOLD,
                    Amount		= gold,
                    Duration	= remainingTurns,
                    IsOutgoing	= true,
                    PlayerID	= otherID,
                    Name		= Locale.Lookup( pPlayerConfig:GetCivilizationDescription() )
                  });
                end
              end
            end

            -- Add outgoing resource deals
            pOutgoingDeal = pDeal:FindItemsByType(DealItemTypes.RESOURCES, DealItemSubTypes.NONE, playerID);
            if pOutgoingDeal ~= nil then
              for i,pDealItem in ipairs(pOutgoingDeal) do
                local duration		:number = pDealItem:GetDuration();
							local remainingTurns:number = duration - (currentGameTurn - pDealItem:GetEnactedTurn());
                if duration ~= 0 then
                  local amount		:number = pDealItem:GetAmount();
                  local resourceType	:number = pDealItem:GetValueType();
                  table.insert( kDealData, {
                    Type			= DealItemTypes.RESOURCES,
                    ResourceType	= resourceType,
                    Amount			= amount,
									Duration		= remainingTurns,
                    IsOutgoing		= true,
                    PlayerID		= otherID,
                    Name			= Locale.Lookup( pPlayerConfig:GetCivilizationDescription() )
                  });

								local entryString:string = Locale.Lookup("LOC_HUD_REPORTS_ROW_DIPLOMATIC_DEALS") .. " (" .. Locale.Lookup(pPlayerConfig:GetPlayerName()) .. " " .. Locale.Lookup("LOC_REPORTS_NUMBER_OF_TURNS", remainingTurns) .. ")";
                  AddResourceData(kResources, resourceType, entryString, "LOC_HUD_REPORTS_TRADE_EXPORTED", -1 * amount);
                end
              end
            end

            -- Add incoming gold deals
            local pIncomingDeal :table = pDeal:FindItemsByType(DealItemTypes.GOLD, DealItemSubTypes.NONE, otherID);
            if pIncomingDeal ~= nil then
              for i,pDealItem in ipairs(pIncomingDeal) do
                local duration		:number = pDealItem:GetDuration();
							local remainingTurns:number = duration - (currentGameTurn - pDealItem:GetEnactedTurn());
                if duration ~= 0 then
                  local gold :number = pDealItem:GetAmount()
                  table.insert( kDealData, {
                    Type		= DealItemTypes.GOLD;
                    Amount		= gold,
									Duration	= remainingTurns,
                    IsOutgoing	= false,
                    PlayerID	= otherID,
                    Name		= Locale.Lookup( pPlayerConfig:GetCivilizationDescription() )
                  });
                end
              end
            end

            -- Add incoming resource deals
            pIncomingDeal = pDeal:FindItemsByType(DealItemTypes.RESOURCES, DealItemSubTypes.NONE, otherID);
            if pIncomingDeal ~= nil then
              for i,pDealItem in ipairs(pIncomingDeal) do
                local duration		:number = pDealItem:GetDuration();
                if duration ~= 0 then
                  local amount		:number = pDealItem:GetAmount();
                  local resourceType	:number = pDealItem:GetValueType();
								local remainingTurns:number = duration - (currentGameTurn - pDealItem:GetEnactedTurn());
                  table.insert( kDealData, {
                    Type			= DealItemTypes.RESOURCES,
                    ResourceType	= resourceType,
                    Amount			= amount,
									Duration		= remainingTurns,
                    IsOutgoing		= false,
                    PlayerID		= otherID,
                    Name			= Locale.Lookup( pPlayerConfig:GetCivilizationDescription() )
                  });

								local entryString:string = Locale.Lookup("LOC_HUD_REPORTS_ROW_DIPLOMATIC_DEALS") .. " (" .. Locale.Lookup(pPlayerConfig:GetPlayerName()) .. " " .. Locale.Lookup("LOC_REPORTS_NUMBER_OF_TURNS", remainingTurns) .. ")";
                  AddResourceData(kResources, resourceType, entryString, "LOC_HUD_REPORTS_TRADE_IMPORTED", amount);
                end
              end
            end
        end
      end

    end
  end

  -- Add resources provided by city states
  for i, pMinorPlayer in ipairs(PlayerManager.GetAliveMinors()) do
    local pMinorPlayerInfluence:table = pMinorPlayer:GetInfluence();
    if pMinorPlayerInfluence ~= nil then
      local suzerainID:number = pMinorPlayerInfluence:GetSuzerain();
      if suzerainID == playerID then
        for row in GameInfo.Resources() do
          local resourceAmount:number =  pMinorPlayer:GetResources():GetExportedResourceAmount(row.Index);
          if resourceAmount > 0 then
            local pMinorPlayerConfig:table = PlayerConfigurations[pMinorPlayer:GetID()];
            local entryString:string = Locale.Lookup("LOC_HUD_REPORTS_CITY_STATE") .. " (" .. Locale.Lookup(pMinorPlayerConfig:GetPlayerName()) .. ")";
            AddResourceData(kResources, row.Index, entryString, "LOC_CITY_STATES_SUZERAIN", resourceAmount);
          end
        end
      end
    end
  end

  -- Assume that resources not yet accounted for have come from Great People
  if pResources then
    for row in GameInfo.Resources() do
      local internalResourceAmount:number = pResources:GetResourceAmount(row.Index);
      if (internalResourceAmount > 0) then
        if (kResources[row.Index] ~= nil) then
          if (internalResourceAmount > kResources[row.Index].Total) then
            AddResourceData(kResources, row.Index, "LOC_GOVT_FILTER_GREAT_PERSON", "-", internalResourceAmount - kResources[row.Index].Total);
          end
        else
          AddResourceData(kResources, row.Index, "LOC_GOVT_FILTER_GREAT_PERSON", "-", internalResourceAmount);
        end
      end
    end
  end

  -- !! changed
  --return kCityData, kCityTotalData, kResources, kUnitData, kDealData;
  return kCityData, kCityTotalData, kResources, kUnitData, kDealData, pCulture, kCurrentDeals
end

-- ===========================================================================
function AddResourceData( kResources:table, eResourceType:number, EntryString:string, ControlString:string, InAmount:number)
  local kResource :table = GameInfo.Resources[eResourceType];

	--Artifacts need to be excluded because while TECHNICALLY a resource, they do nothing to contribute in a way that is relevant to any other resource 
	--or screen. So... exclusion.
	if kResource.ResourceClassType == "RESOURCECLASS_ARTIFACT" then
		return;
	end

  if kResources[eResourceType] == nil then
    kResources[eResourceType] = {
      EntryList	= {},
      Icon		= "[ICON_"..kResource.ResourceType.."]",
      IsStrategic	= kResource.ResourceClassType == "RESOURCECLASS_STRATEGIC",
      IsLuxury	= GameInfo.Resources[eResourceType].ResourceClassType == "RESOURCECLASS_LUXURY",
      IsBonus		= GameInfo.Resources[eResourceType].ResourceClassType == "RESOURCECLASS_BONUS",
      Total		= 0
    };
  end

  table.insert( kResources[eResourceType].EntryList,
  {
    EntryText	= EntryString,
    ControlText = ControlString,
    Amount		= InAmount,
  });

  kResources[eResourceType].Total = kResources[eResourceType].Total + InAmount;
end

-- ===========================================================================
--	Obtain the total resources for a given city.
-- ===========================================================================
function GetCityResourceData( pCity:table )

  -- Loop through all the plots for a given city; tallying the resource amount.
  local kResources : table = {};
  local cityPlots : table = Map.GetCityPlots():GetPurchasedPlots(pCity)
  for _, plotID in ipairs(cityPlots) do
    local plot			: table = Map.GetPlotByIndex(plotID)
    local plotX			: number = plot:GetX()
    local plotY			: number = plot:GetY()
    local eResourceType : number = plot:GetResourceType();

    -- TODO: Account for trade/diplomacy resources.
    if eResourceType ~= -1 and Players[pCity:GetOwner()]:GetResources():IsResourceExtractableAt(plot) then
      if kResources[eResourceType] == nil then
        kResources[eResourceType] = 1;
      else
        kResources[eResourceType] = kResources[eResourceType] + 1;
      end
    end
  end
  return kResources;
end

-- ===========================================================================
--	Obtain the yields from the worked plots
-- ===========================================================================
function GetWorkedTileYieldData( pCity:table, pCulture:table )

  -- Loop through all the plots for a given city; tallying the resource amount.
  local kYields : table = {
    YIELD_PRODUCTION= 0,
    YIELD_FOOD		= 0,
    YIELD_GOLD		= 0,
    YIELD_FAITH		= 0,
    YIELD_SCIENCE	= 0,
    YIELD_CULTURE	= 0,
    TOURISM			= 0,
  };
  local cityPlots : table = Map.GetCityPlots():GetPurchasedPlots(pCity);
  local pCitizens	: table = pCity:GetCitizens();
  for _, plotID in ipairs(cityPlots) do
    local plot	: table = Map.GetPlotByIndex(plotID);
    local x		: number = plot:GetX();
    local y		: number = plot:GetY();
    isPlotWorked = pCitizens:IsPlotWorked(x,y);
    if isPlotWorked then
      for row in GameInfo.Yields() do
        kYields[row.YieldType] = kYields[row.YieldType] + plot:GetYield(row.Index);
      end
    end

    -- Support tourism.
    -- Not a common yield, and only exposure from game core is based off
    -- of the plot so the sum is easily shown, but it's not possible to
    -- show how individual buildings contribute... yet.
    kYields["TOURISM"] = kYields["TOURISM"] + pCulture:GetTourismAt( plotID );
  end
  return kYields;
end



-- ===========================================================================
--	Set a group to it's proper collapse/open state
--	Set + - in group row
-- ===========================================================================
function RealizeGroup( instance:table )
  local v :number = (instance["isCollapsed"]==false and instance.RowExpandCheck:GetSizeY() or 0);
  instance.RowExpandCheck:SetTextureOffsetVal(0, v);

  instance.ContentStack:CalculateSize();
  instance.CollapseScroll:CalculateSize();

  local groupHeight	:number = instance.ContentStack:GetSizeY();
  instance.CollapseAnim:SetBeginVal(0, -(groupHeight - instance["CollapsePadding"]));
  instance.CollapseScroll:SetSizeY( groupHeight );

  instance.Top:ReprocessAnchoring();
end

-- ===========================================================================
--	Callback
--	Expand or contract a group based on its existing state.
-- ===========================================================================
function OnToggleCollapseGroup( instance:table )
  instance["isCollapsed"] = not instance["isCollapsed"];
  instance.CollapseAnim:Reverse();
  RealizeGroup( instance );
end

-- ===========================================================================
--	Toggle a group expanding / collapsing
--	instance,	A group instance.
-- ===========================================================================
function OnAnimGroupCollapse( instance:table)
    -- Helper
  function lerp(y1:number,y2:number,x:number)
    return y1 + (y2-y1)*x;
  end
  local groupHeight	:number = instance.ContentStack:GetSizeY();
  local collapseHeight:number = instance["CollapsePadding"]~=nil and instance["CollapsePadding"] or 0;
  local startY		:number = instance["isCollapsed"]==true  and groupHeight or collapseHeight;
  local endY			:number = instance["isCollapsed"]==false and groupHeight or collapseHeight;
  local progress		:number = instance.CollapseAnim:GetProgress();
  local sizeY			:number = lerp(startY,endY,progress);

  instance.CollapseScroll:SetSizeY( sizeY );
  instance.ContentStack:ReprocessAnchoring();
  instance.Top:ReprocessAnchoring()

  Controls.Stack:CalculateSize();
  Controls.Scroll:CalculateSize();
end


-- ===========================================================================
function SetGroupCollapsePadding( instance:table, amount:number )
  instance["CollapsePadding"] = amount;
end


-- ===========================================================================
function ResetTabForNewPageContent()
  m_uiGroups = {};
  m_simpleIM:ResetInstances();
  m_groupIM:ResetInstances();
  m_isCollapsing = true;
  Controls.CollapseAll:LocalizeAndSetText("LOC_HUD_REPORTS_COLLAPSE_ALL");
  Controls.Scroll:SetScrollValue( 0 );
end


-- ===========================================================================
--	Instantiate a new collapsable row (group) holder & wire it up.
--	ARGS:	(optional) isCollapsed
--	RETURNS: New group instance
-- ===========================================================================
function NewCollapsibleGroupInstance( isCollapsed:boolean )
  if isCollapsed == nil then
    isCollapsed = false;
  end
  local instance:table = m_groupIM:GetInstance();
  instance.ContentStack:DestroyAllChildren();
  instance["isCollapsed"]		= isCollapsed;
  instance["CollapsePadding"] = nil;				-- reset any prior collapse padding

  -- !! added
  instance["Children"] = {}
  instance["Descend"] = false
  -- !!

  instance.CollapseAnim:SetToBeginning();
  if isCollapsed == false then
    instance.CollapseAnim:SetToEnd();
  end

  instance.RowHeaderButton:RegisterCallback( Mouse.eLClick, function() OnToggleCollapseGroup(instance); end );
    instance.RowHeaderButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

  instance.CollapseAnim:RegisterAnimCallback(               function() OnAnimGroupCollapse( instance ); end );

  table.insert( m_uiGroups, instance );

  return instance;
end


-- ===========================================================================
--	debug - Create a test page.
-- ===========================================================================
function ViewTestPage()

  ResetTabForNewPageContent();

  local instance:table = NewCollapsibleGroupInstance();
  instance.RowHeaderButton:SetText( "Test City Icon 1" );
  instance.Top:SetID("foo");

  local pHeaderInstance:table = {}
  ContextPtr:BuildInstanceForControl( "CityIncomeHeaderInstance", pHeaderInstance, instance.ContentStack ) ;

  local pCityInstance:table = {};
  ContextPtr:BuildInstanceForControl( "CityIncomeInstance", pCityInstance, instance.ContentStack ) ;

  for i=1,3,1 do
    local pLineItemInstance:table = {};
    ContextPtr:BuildInstanceForControl("CityIncomeLineItemInstance", pLineItemInstance, pCityInstance.LineItemStack );
  end

  local pFooterInstance:table = {};
  ContextPtr:BuildInstanceForControl("CityIncomeFooterInstance", pFooterInstance, instance.ContentStack  );

  SetGroupCollapsePadding(instance, pFooterInstance.Top:GetSizeY() );
  RealizeGroup( instance );

  Controls.BottomYieldTotals:SetHide( true );
  Controls.BottomResourceTotals:SetHide( true );
  Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - (Controls.BottomYieldTotals:GetSizeY() + SIZE_HEIGHT_PADDING_BOTTOM_ADJUST ) );
end

-- !! sort features for income

local sort : table = { by = "CityName", descend = true }

local function sortFunction( t, a, b )
  if sort.by == "TourismPerTurn" then
    if sort.descend then
      return t[b].WorkedTileYields["TOURISM"] < t[a].WorkedTileYields["TOURISM"]
    else
      return t[b].WorkedTileYields["TOURISM"] > t[a].WorkedTileYields["TOURISM"]
    end
  else
    if sort.descend then
      return t[b][sort.by] < t[a][sort.by]
    else
      return t[b][sort.by] > t[a][sort.by]
    end
  end

end

local function sortBy( name, instance )

  if name == sort.by then
    sort.descend = not sort.descend
  else
    sort.by = name
    sort.descend = true
  end

  local i = 0;
  for _,kCityData in spairs( m_kCityData, sortFunction ) do
    i = i + 1
    local cityInstance = instance.Children[i]
    yieldsCityFields(kCityData,cityInstance)
  end

end

function cityincome_fields( kCityData, pCityInstance )

  pCityInstance.CityName:SetText( Locale.Lookup( kCityData.CityName ) );

  -- Current Production
  local kCurrentProduction:table = kCityData.ProductionQueue[1];
  pCityInstance.CurrentProduction:SetHide( kCurrentProduction == nil );

  if kCurrentProduction ~= nil then
    local tooltip:string = Locale.Lookup(kCurrentProduction.Name);

    if kCurrentProduction.Description ~= nil then
      tooltip = tooltip .. "[NEWLINE]" .. Locale.Lookup(kCurrentProduction.Description);
    end

    pCityInstance.CurrentProduction:SetToolTipString( tooltip )

    if kCurrentProduction.Icon then
      pCityInstance.CityBannerBackground:SetHide( false );
      pCityInstance.CurrentProduction:SetIcon( kCurrentProduction.Icon );
      pCityInstance.CityProductionMeter:SetPercent( kCurrentProduction.PercentComplete );
      pCityInstance.CityProductionNextTurn:SetPercent( kCurrentProduction.PercentCompleteNextTurn );
      pCityInstance.ProductionBorder:SetHide( kCurrentProduction.Type == ProductionType.DISTRICT );
    else
      pCityInstance.CityBannerBackground:SetHide( true );
    end
  end

  pCityInstance.Production:SetText( toPlusMinusString(kCityData.ProductionPerTurn) );
  pCityInstance.Food:SetText( toPlusMinusString(kCityData.FoodPerTurn) );
  pCityInstance.Gold:SetText( toPlusMinusString(kCityData.GoldPerTurn) );
  pCityInstance.Faith:SetText( toPlusMinusString(kCityData.FaithPerTurn) );
  pCityInstance.Science:SetText( toPlusMinusString(kCityData.SciencePerTurn) );
  pCityInstance.Culture:SetText( toPlusMinusString(kCityData.CulturePerTurn) );
  pCityInstance.Tourism:SetText( toPlusMinusString(kCityData.WorkedTileYields["TOURISM"]) );

  if not Controls.CityBuildingsCheckbox:IsSelected() then
    -- Compute tiles worked by setting to total and subtracting all the things...

    for i,kDistrict in ipairs(kCityData.BuildingsAndDistricts) do
      for i,kBuilding in ipairs(kDistrict.Buildings) do
        local pLineItemInstance:table = {};
        ContextPtr:BuildInstanceForControl("CityIncomeLineItemInstance", pLineItemInstance, pCityInstance.LineItemStack );
        pLineItemInstance.LineItemName:SetText( kBuilding.Name );

        pLineItemInstance.Production:SetText( toPlusMinusNoneString(kBuilding.ProductionPerTurn) );
        pLineItemInstance.Food:SetText( toPlusMinusNoneString(kBuilding.FoodPerTurn) );
        pLineItemInstance.Gold:SetText( toPlusMinusNoneString(kBuilding.GoldPerTurn) );
        pLineItemInstance.Faith:SetText( toPlusMinusNoneString(kBuilding.FaithPerTurn) );
        pLineItemInstance.Science:SetText( toPlusMinusNoneString(kBuilding.SciencePerTurn) );
        pLineItemInstance.Culture:SetText( toPlusMinusNoneString(kBuilding.CulturePerTurn) );

      end
    end

    local pLineItemInstance:table = {};
    ContextPtr:BuildInstanceForControl("CityIncomeLineItemInstance", pLineItemInstance, pCityInstance.LineItemStack );
    pLineItemInstance.LineItemName:SetText( Locale.Lookup("LOC_HUD_REPORTS_WORKED_TILES") );
    pLineItemInstance.Production:SetText( toPlusMinusNoneString(kCityData.WorkedTileYields["YIELD_PRODUCTION"]) );
    pLineItemInstance.Food:SetText( toPlusMinusNoneString(kCityData.WorkedTileYields["YIELD_FOOD"]) );
    pLineItemInstance.Gold:SetText( toPlusMinusNoneString(kCityData.WorkedTileYields["YIELD_GOLD"]) );
    pLineItemInstance.Faith:SetText( toPlusMinusNoneString(kCityData.WorkedTileYields["YIELD_FAITH"]) );
    pLineItemInstance.Science:SetText( toPlusMinusNoneString(kCityData.WorkedTileYields["YIELD_SCIENCE"]) );
    pLineItemInstance.Culture:SetText( toPlusMinusNoneString(kCityData.WorkedTileYields["YIELD_CULTURE"]) );

    local iYieldPercent = (Round(1 + (kCityData.HappinessNonFoodYieldModifier/100), 2)*.1);
    pLineItemInstance = {};
    ContextPtr:BuildInstanceForControl("CityIncomeLineItemInstance", pLineItemInstance, pCityInstance.LineItemStack );
    pLineItemInstance.LineItemName:SetText( Locale.Lookup("LOC_HUD_REPORTS_HEADER_AMENITIES") );
    pLineItemInstance.Production:SetText( toPlusMinusNoneString((kCityData.WorkedTileYields["YIELD_PRODUCTION"] * iYieldPercent) ) );
    pLineItemInstance.Food:SetText( "" );
    pLineItemInstance.Gold:SetText( toPlusMinusNoneString((kCityData.WorkedTileYields["YIELD_GOLD"] * iYieldPercent)) );
    pLineItemInstance.Faith:SetText( toPlusMinusNoneString((kCityData.WorkedTileYields["YIELD_FAITH"] * iYieldPercent)) );
    pLineItemInstance.Science:SetText( toPlusMinusNoneString((kCityData.WorkedTileYields["YIELD_SCIENCE"] * iYieldPercent)) );
    pLineItemInstance.Culture:SetText( toPlusMinusNoneString((kCityData.WorkedTileYields["YIELD_CULTURE"] * iYieldPercent)) );
  end

end

-- !! yeh

-- ===========================================================================
--	Tab Callback
-- ===========================================================================
function yieldsCityFields( kCityData, pCityInstance )
  TruncateStringWithTooltip(pCityInstance.CityName, 230, Locale.Lookup(kCityData.CityName)); 

  --Great works
  local greatWorks:table = GetGreatWorksForCity(kCityData.City);

  -- Current Production
  local kCurrentProduction:table = kCityData.ProductionQueue[1];
  pCityInstance.CurrentProduction:SetHide( kCurrentProduction == nil );
  if kCurrentProduction ~= nil then
    local tooltip:string = Locale.Lookup(kCurrentProduction.Name);
    if kCurrentProduction.Description ~= nil then
      tooltip = tooltip .. "[NEWLINE]" .. Locale.Lookup(kCurrentProduction.Description);
    end
    pCityInstance.CurrentProduction:SetToolTipString( tooltip )

    if kCurrentProduction.Icon then
      pCityInstance.CityBannerBackground:SetHide( false );
      pCityInstance.CurrentProduction:SetIcon( kCurrentProduction.Icon );
      pCityInstance.CityProductionMeter:SetPercent( kCurrentProduction.PercentComplete );
      pCityInstance.CityProductionNextTurn:SetPercent( kCurrentProduction.PercentCompleteNextTurn );
      pCityInstance.ProductionBorder:SetHide( kCurrentProduction.Type == ProductionType.DISTRICT );
    else
      pCityInstance.CityBannerBackground:SetHide( true );
    end
  end

  pCityInstance.Production:SetText( toPlusMinusString(kCityData.ProductionPerTurn) );
  pCityInstance.Food:SetText( toPlusMinusString(kCityData.FoodPerTurn) );
  pCityInstance.Gold:SetText( toPlusMinusString(kCityData.GoldPerTurn) );
  pCityInstance.Faith:SetText( toPlusMinusString(kCityData.FaithPerTurn) );
  pCityInstance.Science:SetText( toPlusMinusString(kCityData.SciencePerTurn) );
  pCityInstance.Culture:SetText( toPlusMinusString(kCityData.CulturePerTurn) );
  pCityInstance.Tourism:SetText( toPlusMinusString(kCityData.WorkedTileYields["TOURISM"]) );

  if not Controls.CityBuildingsCheckbox:IsSelected() then
  -- Compute tiles worked by setting to total and subtracting all the things...
  -- AZURENCY : clear buildings yield detail stack
  pCityInstance.LineItemStack:DestroyAllChildren();

  for i,kDistrict in ipairs(kCityData.BuildingsAndDistricts) do
    --District line item
    local districtInstance = CreatLineItemInstance( pCityInstance, 
                            kDistrict.Name,
                            kDistrict.Production,
                            kDistrict.Gold,
                            kDistrict.Food,
                            kDistrict.Science,
                            kDistrict.Culture,
                            kDistrict.Faith);
    districtInstance.DistrictIcon:SetHide(false);
    districtInstance.DistrictIcon:SetIcon(kDistrict.Icon);

    function HasValidAdjacencyBonus(adjacencyTable:table)
      for _, yield in pairs(adjacencyTable) do
        if yield ~= 0 then
          return true;
        end
      end
      return false;
    end

    --Adjacency
    if HasValidAdjacencyBonus(kDistrict.AdjacencyBonus) then
      CreatLineItemInstance(  pCityInstance,
                  INDENT_STRING .. Locale.Lookup("LOC_HUD_REPORTS_ADJACENCY_BONUS"),
                  kDistrict.AdjacencyBonus.Production,
                  kDistrict.AdjacencyBonus.Gold,
                  kDistrict.AdjacencyBonus.Food,
                  kDistrict.AdjacencyBonus.Science,
                  kDistrict.AdjacencyBonus.Culture,
                  kDistrict.AdjacencyBonus.Faith);
    end

    
    for i,kBuilding in ipairs(kDistrict.Buildings) do
      CreatLineItemInstance(  pCityInstance,
                  INDENT_STRING ..  kBuilding.Name,
                  kBuilding.ProductionPerTurn,
                  kBuilding.GoldPerTurn,
                  kBuilding.FoodPerTurn,
                  kBuilding.SciencePerTurn,
                  kBuilding.CulturePerTurn,
                  kBuilding.FaithPerTurn);

      --Add great works
      if greatWorks[kBuilding.Type] ~= nil then
        --Add our line items!
        for _, kGreatWork in ipairs(greatWorks[kBuilding.Type]) do
          local pLineItemInstance = CreatLineItemInstance(  pCityInstance, INDENT_STRING .. INDENT_STRING ..  Locale.Lookup(kGreatWork.Name), 0, 0, 0,  0, 0, 0);
          for _, yield in ipairs(kGreatWork.YieldChanges) do
            if (yield.YieldType == "YIELD_FOOD") then
              pLineItemInstance.Food:SetText( toPlusMinusNoneString(yield.YieldChange) );
            elseif (yield.YieldType == "YIELD_PRODUCTION") then
              pLineItemInstance.Production:SetText( toPlusMinusNoneString(yield.YieldChange) );
            elseif (yield.YieldType == "YIELD_GOLD") then
              pLineItemInstance.Gold:SetText( toPlusMinusNoneString(yield.YieldChange) );
            elseif (yield.YieldType == "YIELD_SCIENCE") then
              pLineItemInstance.Science:SetText( toPlusMinusNoneString(yield.YieldChange) );
            elseif (yield.YieldType == "YIELD_CULTURE") then
              pLineItemInstance.Culture:SetText( toPlusMinusNoneString(yield.YieldChange) );
            elseif (yield.YieldType == "YIELD_FAITH") then
              pLineItemInstance.Faith:SetText( toPlusMinusNoneString(yield.YieldChange) );
            end
          end
        end
      end

    end
  end

  -- Display wonder yields
  if kCityData.Wonders then
    for _, wonder in ipairs(kCityData.Wonders) do
      if wonder.Yields[1] ~= nil or greatWorks[wonder.Type] ~= nil then
      -- Assign yields to the line item
        local pLineItemInstance:table = CreatLineItemInstance(pCityInstance, wonder.Name, 0, 0, 0, 0, 0, 0);
        for _, yield in ipairs(wonder.Yields) do
          if (yield.YieldType == "YIELD_FOOD") then
            pLineItemInstance.Food:SetText( toPlusMinusNoneString(yield.YieldChange) );
          elseif (yield.YieldType == "YIELD_PRODUCTION") then
            pLineItemInstance.Production:SetText( toPlusMinusNoneString(yield.YieldChange) );
          elseif (yield.YieldType == "YIELD_GOLD") then
            pLineItemInstance.Gold:SetText( toPlusMinusNoneString(yield.YieldChange) );
          elseif (yield.YieldType == "YIELD_SCIENCE") then
            pLineItemInstance.Science:SetText( toPlusMinusNoneString(yield.YieldChange) );
          elseif (yield.YieldType == "YIELD_CULTURE") then
            pLineItemInstance.Culture:SetText( toPlusMinusNoneString(yield.YieldChange) );
          elseif (yield.YieldType == "YIELD_FAITH") then
            pLineItemInstance.Faith:SetText( toPlusMinusNoneString(yield.YieldChange) );
          end
        end
      end

      --Add great works
      if greatWorks[wonder.Type] ~= nil then
        --Add our line items!
        for _, kGreatWork in ipairs(greatWorks[wonder.Type]) do
          local pLineItemInstance = CreatLineItemInstance(  pCityInstance, INDENT_STRING ..  Locale.Lookup(kGreatWork.Name), 0, 0, 0, 0, 0, 0);
          for _, yield in ipairs(kGreatWork.YieldChanges) do
          if (yield.YieldType == "YIELD_FOOD") then
            pLineItemInstance.Food:SetText( toPlusMinusNoneString(yield.YieldChange) );
          elseif (yield.YieldType == "YIELD_PRODUCTION") then
            pLineItemInstance.Production:SetText( toPlusMinusNoneString(yield.YieldChange) );
          elseif (yield.YieldType == "YIELD_GOLD") then
            pLineItemInstance.Gold:SetText( toPlusMinusNoneString(yield.YieldChange) );
          elseif (yield.YieldType == "YIELD_SCIENCE") then
            pLineItemInstance.Science:SetText( toPlusMinusNoneString(yield.YieldChange) );
          elseif (yield.YieldType == "YIELD_CULTURE") then
            pLineItemInstance.Culture:SetText( toPlusMinusNoneString(yield.YieldChange) );
          elseif (yield.YieldType == "YIELD_FAITH") then
            pLineItemInstance.Faith:SetText( toPlusMinusNoneString(yield.YieldChange) );
          end
        end
      end
    end
  end
  end

  -- Display route yields
  if kCityData.OutgoingRoutes then
    for i,route in ipairs(kCityData.OutgoingRoutes) do
      if route ~= nil then
        if route.OriginYields then
          -- Find destination city
          local pDestPlayer:table = Players[route.DestinationCityPlayer];
          local pDestPlayerCities:table = pDestPlayer:GetCities();
          local pDestCity:table = pDestPlayerCities:FindID(route.DestinationCityID);

          --Assign yields to the line item
          local pLineItemInstance:table = CreatLineItemInstance(pCityInstance, Locale.Lookup("LOC_HUD_REPORTS_TRADE_WITH", Locale.Lookup(pDestCity:GetName())), 0, 0, 0, 0, 0, 0);
          for j,yield in ipairs(route.OriginYields) do
            local yieldInfo = GameInfo.Yields[yield.YieldIndex];
            if yieldInfo then
              if (yieldInfo.YieldType == "YIELD_FOOD") then
                pLineItemInstance.Food:SetText( toPlusMinusNoneString(yield.Amount) );
              elseif (yieldInfo.YieldType == "YIELD_PRODUCTION") then
                pLineItemInstance.Production:SetText( toPlusMinusNoneString(yield.Amount) );
              elseif (yieldInfo.YieldType == "YIELD_GOLD") then
                pLineItemInstance.Gold:SetText( toPlusMinusNoneString(yield.Amount) );
              elseif (yieldInfo.YieldType == "YIELD_SCIENCE") then
                pLineItemInstance.Science:SetText( toPlusMinusNoneString(yield.Amount) );
              elseif (yieldInfo.YieldType == "YIELD_CULTURE") then
                pLineItemInstance.Culture:SetText( toPlusMinusNoneString(yield.Amount) );
              elseif (yieldInfo.YieldType == "YIELD_FAITH") then
                pLineItemInstance.Faith:SetText( toPlusMinusNoneString(yield.Amount) );
              end
            end
          end
        end
      end
    end
  end

  --Worked Tiles
  CreatLineItemInstance(  pCityInstance,
              Locale.Lookup("LOC_HUD_REPORTS_WORKED_TILES"),
              kCityData.WorkedTileYields["YIELD_PRODUCTION"],
              kCityData.WorkedTileYields["YIELD_GOLD"],
              kCityData.WorkedTileYields["YIELD_FOOD"],
              kCityData.WorkedTileYields["YIELD_SCIENCE"],
              kCityData.WorkedTileYields["YIELD_CULTURE"],
              kCityData.WorkedTileYields["YIELD_FAITH"]);

  local iYieldPercent = (Round(1 + (kCityData.HappinessNonFoodYieldModifier/100), 2)*.1);
  CreatLineItemInstance(  pCityInstance,
              Locale.Lookup("LOC_HUD_REPORTS_HEADER_AMENITIES"),
              kCityData.WorkedTileYields["YIELD_PRODUCTION"] * iYieldPercent,
              kCityData.WorkedTileYields["YIELD_GOLD"] * iYieldPercent,
              0,
              kCityData.WorkedTileYields["YIELD_SCIENCE"] * iYieldPercent,
              kCityData.WorkedTileYields["YIELD_CULTURE"] * iYieldPercent,
              kCityData.WorkedTileYields["YIELD_FAITH"] * iYieldPercent);

  local populationToCultureScale:number = GameInfo.GlobalParameters["CULTURE_PERCENTAGE_YIELD_PER_POP"].Value / 100;
  CreatLineItemInstance(  pCityInstance,
              Locale.Lookup("LOC_HUD_CITY_POPULATION"),
              0,
              0,
              0,
              0,
              kCityData["Population"] * populationToCultureScale, 
              0);

  pCityInstance.LineItemStack:CalculateSize();
  pCityInstance.Darken:SetSizeY( pCityInstance.LineItemStack:GetSizeY() + DARKEN_CITY_INCOME_AREA_ADDITIONAL_Y );
  pCityInstance.Top:ReprocessAnchoring();
  end
end

function ViewYieldsPage()

  ResetTabForNewPageContent();

  -- Remember this tab when report is next opened: ARISTOS
  m_kCurrentTab = 1;

  Controls.CityBuildingsCheckbox:SetHide( false )
  local pPlayer:table = Players[Game.GetLocalPlayer()];

  local instance:table = nil;
  local cityInstance:table = nil;
  cityInstance = NewCollapsibleGroupInstance();
  cityInstance.RowHeaderButton:SetText( Locale.Lookup("LOC_HUD_REPORTS_ROW_CITY_INCOME") );
  cityInstance.RowHeaderLabel:SetHide( true )

  local pHeaderInstance:table = {}
  ContextPtr:BuildInstanceForControl( "CityIncomeHeaderInstance", pHeaderInstance, cityInstance.ContentStack ) ;

  --instance.Children = {}

  pHeaderInstance.CityNameButton:RegisterCallback( Mouse.eLClick, function() sortBy( "CityName", cityInstance ) end )
  pHeaderInstance.ProductionButton:RegisterCallback( Mouse.eLClick, function() sortBy( "ProductionPerTurn", cityInstance ) end )
  pHeaderInstance.FoodButton:RegisterCallback( Mouse.eLClick, function() sortBy( "FoodPerTurn", cityInstance ) end )
  pHeaderInstance.GoldButton:RegisterCallback( Mouse.eLClick, function() sortBy( "GoldPerTurn", cityInstance ) end )
  pHeaderInstance.FaithButton:RegisterCallback( Mouse.eLClick, function() sortBy( "FaithPerTurn", cityInstance ) end )
  pHeaderInstance.ScienceButton:RegisterCallback( Mouse.eLClick, function() sortBy( "SciencePerTurn", cityInstance ) end )
  pHeaderInstance.CultureButton:RegisterCallback( Mouse.eLClick, function() sortBy( "CulturePerTurn", cityInstance ) end )
  pHeaderInstance.TourismButton:RegisterCallback( Mouse.eLClick, function() sortBy( "TourismPerTurn", cityInstance ) end )

  local goldCityTotal   :number = 0;
  local faithCityTotal  :number = 0;
  local scienceCityTotal  :number = 0;
  local cultureCityTotal  :number = 0;
  local tourismCityTotal  :number = 0;

  -- ========== City Income ==========

	function CreatLineItemInstance(cityInstance:table, name:string, production:number, gold:number, food:number, science:number, culture:number, faith:number)
		local lineInstance:table = {};
		ContextPtr:BuildInstanceForControl("CityIncomeLineItemInstance", lineInstance, cityInstance.LineItemStack );
		TruncateStringWithTooltipClean(lineInstance.LineItemName, 160, name);
		lineInstance.Production:SetText( toPlusMinusNoneString(production));
		lineInstance.Food:SetText( toPlusMinusNoneString(food));
		lineInstance.Gold:SetText( toPlusMinusNoneString(gold));
		lineInstance.Faith:SetText( toPlusMinusNoneString(faith));
		lineInstance.Science:SetText( toPlusMinusNoneString(science));
		lineInstance.Culture:SetText( toPlusMinusNoneString(culture));

		return lineInstance;
	end

	for cityName,kCityData in spairs( m_kCityData, function( t, a, b ) return sortFunction( t, a, b ) end ) do
    local pCityInstance:table = {};
    ContextPtr:BuildInstanceForControl( "CityIncomeInstance", pCityInstance, cityInstance.ContentStack ) ;
    table.insert(cityInstance.Children, pCityInstance)
    yieldsCityFields(kCityData,pCityInstance)
    -- Add to all cities totals
    goldCityTotal = goldCityTotal + kCityData.GoldPerTurn;
    faithCityTotal  = faithCityTotal + kCityData.FaithPerTurn;
    scienceCityTotal= scienceCityTotal + kCityData.SciencePerTurn;
    cultureCityTotal= cultureCityTotal + kCityData.CulturePerTurn;
    tourismCityTotal= tourismCityTotal + kCityData.WorkedTileYields["TOURISM"];
  end

  local pFooterInstance:table = {};
  ContextPtr:BuildInstanceForControl("CityIncomeFooterInstance", pFooterInstance, cityInstance.ContentStack  );
  pFooterInstance.Gold:SetText( "[Icon_GOLD]"..toPlusMinusString(goldCityTotal) );
  pFooterInstance.Faith:SetText( "[Icon_FAITH]"..toPlusMinusString(faithCityTotal) );
  pFooterInstance.Science:SetText( "[Icon_SCIENCE]"..toPlusMinusString(scienceCityTotal) );
  pFooterInstance.Culture:SetText( "[Icon_CULTURE]"..toPlusMinusString(cultureCityTotal) );
  pFooterInstance.Tourism:SetText( "[Icon_TOURISM]"..toPlusMinusString(tourismCityTotal) );

  SetGroupCollapsePadding(cityInstance, pFooterInstance.Top:GetSizeY() );
  RealizeGroup( cityInstance );


  -- ========== Building Expenses ==========

  instance = NewCollapsibleGroupInstance();
  instance.RowHeaderButton:SetText( Locale.Lookup("LOC_HUD_REPORTS_ROW_BUILDING_EXPENSES") );
  instance.RowHeaderLabel:SetHide( true )

  local pHeader:table = {};
  ContextPtr:BuildInstanceForControl( "BuildingExpensesHeaderInstance", pHeader, instance.ContentStack ) ;

  local iTotalBuildingMaintenance :number = 0;
  for cityName,kCityData in pairs(m_kCityData) do
    for _,kBuilding in ipairs(kCityData.Buildings) do
      if kBuilding.Maintenance > 0 then
        local pBuildingInstance:table = {};
        ContextPtr:BuildInstanceForControl( "BuildingExpensesEntryInstance", pBuildingInstance, instance.ContentStack ) ;
        TruncateStringWithTooltip(pBuildingInstance.CityName, 224, Locale.Lookup(cityName)); 
        pBuildingInstance.BuildingName:SetText( Locale.Lookup(kBuilding.Name) );
				pBuildingInstance.Gold:SetText( "-"..tostring(kBuilding.Maintenance));
        iTotalBuildingMaintenance = iTotalBuildingMaintenance - kBuilding.Maintenance;
      end
    end


    -- Adds district costs to expenses !!
    -- don't count city center
    -- District maintenance isn't factored into the expense screen ( but is factored into maintenance )
    -- This helps rectify that by adding up all the districts in a city, -1 for city center
    -- Tooltip shows districts have a -1 gpt cost, not sure if this goes up or if its different for other districts or
    -- later eras

    local iNumDistricts : number = 0

    -- Can't find/figure out how to find district type, so i'll do it myself
    -- this goes through the districts and adds the maintenance if not pillaged/being built
    for _,kBuilding in ipairs(kCityData.BuildingsAndDistricts) do
      if kBuilding.isBuilt then
        for i = 1, #GameInfo.Districts do
          if kBuilding.Name == Locale.Lookup( GameInfo.Districts[i].Name ) and GameInfo.Districts[i].Maintenance > 0 then
            local pBuildingInstance:table = {};
            ContextPtr:BuildInstanceForControl( "BuildingExpensesEntryInstance", pBuildingInstance, instance.ContentStack );
            TruncateStringWithTooltip(pBuildingInstance.CityName, 224, Locale.Lookup(cityName)); 
            pBuildingInstance.BuildingName:SetText( Locale.Lookup( GameInfo.Districts[i].Name ) );
            pBuildingInstance.Gold:SetText( "-" .. tostring( GameInfo.Districts[i].Maintenance ) );
            iTotalBuildingMaintenance = iTotalBuildingMaintenance - GameInfo.Districts[i].Maintenance;
            break;
          end
        end
      end
    end
  end
  local pBuildingFooterInstance:table = {};
  ContextPtr:BuildInstanceForControl( "GoldFooterInstance", pBuildingFooterInstance, instance.ContentStack ) ;
  pBuildingFooterInstance.Gold:SetText("[ICON_Gold]"..tostring(iTotalBuildingMaintenance) );

  SetGroupCollapsePadding(instance, pBuildingFooterInstance.Top:GetSizeY() );
  RealizeGroup( instance );

  -- ========== !! Unit Expenses ==========
  if GameCapabilities.HasCapability("CAPABILITY_REPORTS_UNIT_EXPENSES") then
    instance = NewCollapsibleGroupInstance();
    instance.RowHeaderButton:SetText( Locale.Lookup( Locale.Lookup("LOC_HUD_REPORTS_ROW_UNIT_EXPENSES") ) );
    instance.RowHeaderLabel:SetHide( true )

    local pHeader:table = {};
    ContextPtr:BuildInstanceForControl( "UnitExpensesHeaderInstance", pHeader, instance.ContentStack ) ;

    local iTotalUnitMaintenance : number = 0
    local conscript_levee : number = 0

    iTotalUnitMaintenance = 0

    local numSlots : number = m_kCultureData:GetNumPolicySlots()

    for i = 0, numSlots - 1, 1 do
      local iPolicyId	:number = m_kCultureData:GetSlotPolicy(i);
      if iPolicyId ~= -1 then
        if GameInfo.Policies[iPolicyId].PolicyType == "POLICY_CONSCRIPTION" then
          conscript_levee = 1
        elseif GameInfo.Policies[iPolicyId].PolicyType == "POLICY_LEVEE_EN_MASSE" then
          conscript_levee = 2
        end
      end
    end

    for _, kUnitGroup in pairs( m_kUnitData["Unit_Expenses"] ) do
      if kUnitGroup.Cost - conscript_levee > 0 then
        local pUnitInstance:table = {}
        ContextPtr:BuildInstanceForControl( "UnitExpensesEntryInstance", pUnitInstance, instance.ContentStack )
        pUnitInstance.UnitName:SetText( kUnitGroup.Name )
        pUnitInstance.Gold:SetText( "-"..tostring( kUnitGroup.Amount * ( kUnitGroup.Cost - conscript_levee ) ) )
        iTotalUnitMaintenance = iTotalUnitMaintenance - kUnitGroup.Amount * ( kUnitGroup.Cost - conscript_levee )
      end
    end

    local pBuildingFooterInstance : table = {};
    ContextPtr:BuildInstanceForControl( "GoldFooterInstance", pBuildingFooterInstance, instance.ContentStack ) ;
    pBuildingFooterInstance.Gold:SetText( "[ICON_Gold]" .. tostring( iTotalUnitMaintenance ) );

    SetGroupCollapsePadding(instance, pBuildingFooterInstance.Top:GetSizeY() );
    RealizeGroup( instance );
  end
  -- Unit Expense END!!


  -- ========== Diplomatic Deals Income and Expenses ==========
  -- ARISTOS: A precise Diplomatic Deals Gold Yields report

  
  if GameCapabilities.HasCapability("CAPABILITY_REPORTS_DIPLOMATIC_DEALS") then 

    instance = NewCollapsibleGroupInstance();
    instance.RowHeaderButton:SetText( Locale.Lookup("LOC_HUD_REPORTS_ROW_DIPLOMATIC_DEALS") );
    instance.RowHeaderLabel:SetHide( true )

    local pHeader:table = {};
    ContextPtr:BuildInstanceForControl( "DealHeaderInstance", pHeader, instance.ContentStack ) ;

    local iTotalDealGold :number = 0;
    for i,kDeal in ipairs(m_kCurrentDeals) do
      local ending = kDeal.EndTurn - Game.GetCurrentGameTurn()

      for i, pDealItem in pairs( kDeal.Sending ) do
        if pDealItem.Icon == "[ICON_GOLD]" then
          local pDealInstance:table = {};
          ContextPtr:BuildInstanceForControl( "DealEntryInstance", pDealInstance, instance.ContentStack ) ;

          pDealInstance.Civilization:SetText( kDeal.WithCivilization );
          pDealInstance.Duration:SetText( tostring(ending) .. "[ICON_Turn]" );
          pDealInstance.Gold:SetText( "-"..tostring(pDealItem.Amount) );
          iTotalDealGold = iTotalDealGold - pDealItem.Amount;
        end
      end

      for i, pDealItem in pairs( kDeal.Receiving ) do
        if pDealItem.Icon == "[ICON_GOLD]" then
          local pDealInstance:table = {};
          ContextPtr:BuildInstanceForControl( "DealEntryInstance", pDealInstance, instance.ContentStack ) ;

          pDealInstance.Civilization:SetText( kDeal.WithCivilization );
          pDealInstance.Duration:SetText( tostring(ending) .. "[ICON_Turn]" );
          pDealInstance.Gold:SetText( "+"..tostring(pDealItem.Amount) );
          iTotalDealGold = iTotalDealGold + pDealItem.Amount;
        end
      end
    end
    
    local pDealFooterInstance:table = {};		
    ContextPtr:BuildInstanceForControl( "GoldFooterInstance", pDealFooterInstance, instance.ContentStack ) ;		
    pDealFooterInstance.Gold:SetText("[ICON_Gold]"..tostring(iTotalDealGold) );
    
    SetGroupCollapsePadding(instance, pDealFooterInstance.Top:GetSizeY() );
    RealizeGroup( instance );
  end

  -- END ARISTOS Diplomatic Deals


  -- ========== TOTALS ==========

  Controls.Stack:CalculateSize();
  Controls.Scroll:CalculateSize();

	-- Totals at the bottom [Definitive values]
	local localPlayer = Players[Game.GetLocalPlayer()];
	--Gold
	local playerTreasury:table	= localPlayer:GetTreasury();
	Controls.GoldIncome:SetText( toPlusMinusNoneString( playerTreasury:GetGoldYield() ));
	Controls.GoldExpense:SetText( toPlusMinusNoneString( -playerTreasury:GetTotalMaintenance() ));	-- Flip that value!
	Controls.GoldNet:SetText( toPlusMinusNoneString( playerTreasury:GetGoldYield() - playerTreasury:GetTotalMaintenance() ));
	Controls.GoldBalance:SetText( m_kCityTotalData.Treasury[YieldTypes.GOLD] );

	
	--Faith
	local playerReligion:table	= localPlayer:GetReligion();
	Controls.FaithIncome:SetText( toPlusMinusNoneString(playerReligion:GetFaithYield()));
	Controls.FaithNet:SetText( toPlusMinusNoneString(playerReligion:GetFaithYield()));
  Controls.FaithBalance:SetText( m_kCityTotalData.Treasury[YieldTypes.FAITH] );

	--Science
	local playerTechnology:table	= localPlayer:GetTechs();
	Controls.ScienceIncome:SetText( toPlusMinusNoneString(playerTechnology:GetScienceYield()));
  Controls.ScienceBalance:SetText( m_kCityTotalData.Treasury[YieldTypes.SCIENCE] );
	
	--Culture
	local playerCulture:table	= localPlayer:GetCulture();
	Controls.CultureIncome:SetText(toPlusMinusNoneString(playerCulture:GetCultureYield()));
	Controls.CultureBalance:SetText(m_kCityTotalData.Treasury[YieldTypes.CULTURE] );
	
	--Tourism. We don't talk about this one much.
	Controls.TourismIncome:SetText( toPlusMinusNoneString( m_kCityTotalData.Income["TOURISM"] ));	
  Controls.TourismBalance:SetText( m_kCityTotalData.Treasury["TOURISM"] );

  Controls.CollapseAll:SetHide(false);
  Controls.BottomYieldTotals:SetHide( false );
  Controls.BottomYieldTotals:SetSizeY( SIZE_HEIGHT_BOTTOM_YIELDS );
  Controls.BottomResourceTotals:SetHide( true );
  Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - (Controls.BottomYieldTotals:GetSizeY() + SIZE_HEIGHT_PADDING_BOTTOM_ADJUST ) );
end


-- ===========================================================================
--	Tab Callback
-- ===========================================================================
function ViewResourcesPage()

  ResetTabForNewPageContent();

  -- Remember this tab when report is next opened: ARISTOS
  m_kCurrentTab = 2;

  -- ARISTOS: Hide the checkbox if not in Yields tab
  Controls.CityBuildingsCheckbox:SetHide( true );

  local strategicResources:string = "";
  local luxuryResources	:string = "";
  local kBonuses			:table	= {};
  local kLuxuries			:table	= {};
  local kStrategics		:table	= {};


  for eResourceType,kSingleResourceData in pairs(m_kResourceData) do

    --!!ARISTOS: Only display list of selected resource types, according to checkboxes
    if (kSingleResourceData.IsStrategic and Controls.StrategicCheckbox:IsSelected()) or
      (kSingleResourceData.IsLuxury and Controls.LuxuryCheckbox:IsSelected()) or
      (kSingleResourceData.IsBonus and Controls.BonusCheckbox:IsSelected()) then

      local instance:table = NewCollapsibleGroupInstance();

      local kResource :table = GameInfo.Resources[eResourceType];
      instance.RowHeaderButton:SetText(  kSingleResourceData.Icon..Locale.Lookup( kResource.Name ) );
      instance.RowHeaderLabel:SetHide( true )

      local pHeaderInstance:table = {};
      ContextPtr:BuildInstanceForControl( "ResourcesHeaderInstance", pHeaderInstance, instance.ContentStack ) ;

      local kResourceEntries:table = kSingleResourceData.EntryList;
      for i,kEntry in ipairs(kResourceEntries) do
        local pEntryInstance:table = {};
        ContextPtr:BuildInstanceForControl( "ResourcesEntryInstance", pEntryInstance, instance.ContentStack ) ;
        pEntryInstance.CityName:SetText( Locale.Lookup(kEntry.EntryText) );
        pEntryInstance.Control:SetText( Locale.Lookup(kEntry.ControlText) );
        pEntryInstance.Amount:SetText( (kEntry.Amount<=0) and tostring(kEntry.Amount) or "+"..tostring(kEntry.Amount) );
      end

      local pFooterInstance:table = {};
      ContextPtr:BuildInstanceForControl( "ResourcesFooterInstance", pFooterInstance, instance.ContentStack ) ;
      pFooterInstance.Amount:SetText( tostring(kSingleResourceData.Total) );

      -- Show how many of this resource are being allocated to what cities
      local localPlayerID = Game.GetLocalPlayer();
      local localPlayer = Players[localPlayerID];
      local citiesProvidedTo: table = localPlayer:GetResources():GetResourceAllocationCities(GameInfo.Resources[kResource.ResourceType].Index);
      local numCitiesProvidingTo: number = table.count(citiesProvidedTo);
      if (numCitiesProvidingTo > 0) then
        pFooterInstance.AmenitiesContainer:SetHide(false);
        pFooterInstance.Amenities:SetText("[ICON_Amenities][ICON_GoingTo]"..numCitiesProvidingTo.." "..Locale.Lookup("LOC_PEDIA_CONCEPTS_PAGEGROUP_CITIES_NAME"));
        local amenitiesTooltip: string = "";
        local playerCities = localPlayer:GetCities();
        for i,city in ipairs(citiesProvidedTo) do
          local cityName = Locale.Lookup(playerCities:FindID(city.CityID):GetName());
          if i ~=1 then
            amenitiesTooltip = amenitiesTooltip.. "[NEWLINE]";
          end
          amenitiesTooltip = amenitiesTooltip.. city.AllocationAmount.." [ICON_".. kResource.ResourceType.."] [Icon_GoingTo] " ..cityName;
        end
        pFooterInstance.Amenities:SetToolTipString(amenitiesTooltip);
      else
        pFooterInstance.AmenitiesContainer:SetHide(true);
      end
      SetGroupCollapsePadding(instance, pFooterInstance.Top:GetSizeY() );
      RealizeGroup( instance );
    end

    if kSingleResourceData.IsStrategic then
      --strategicResources = strategicResources .. kSingleResourceData.Icon .. tostring( kSingleResourceData.Total );
      table.insert(kStrategics, kSingleResourceData.Icon .. tostring( kSingleResourceData.Total ) );
    elseif kSingleResourceData.IsLuxury then
      --luxuryResources = luxuryResources .. kSingleResourceData.Icon .. tostring( kSingleResourceData.Total );
      table.insert(kLuxuries, kSingleResourceData.Icon .. tostring( kSingleResourceData.Total ) );
    else
      table.insert(kBonuses, kSingleResourceData.Icon .. tostring( kSingleResourceData.Total ) );
    end

    --SetGroupCollapsePadding(instance, pFooterInstance.Top:GetSizeY() );
    --RealizeGroup( instance );
  end

  m_strategicResourcesIM:ResetInstances();
  for i,v in ipairs(kStrategics) do
    local resourceInstance:table = m_strategicResourcesIM:GetInstance();
    resourceInstance.Info:SetText( v );
  end
  Controls.StrategicResources:CalculateSize();
  Controls.StrategicGrid:ReprocessAnchoring();

  m_bonusResourcesIM:ResetInstances();
  for i,v in ipairs(kBonuses) do
    local resourceInstance:table = m_bonusResourcesIM:GetInstance();
    resourceInstance.Info:SetText( v );
  end
  Controls.BonusResources:CalculateSize();
  Controls.BonusGrid:ReprocessAnchoring();

  m_luxuryResourcesIM:ResetInstances();
  for i,v in ipairs(kLuxuries) do
    local resourceInstance:table = m_luxuryResourcesIM:GetInstance();
    resourceInstance.Info:SetText( v );
  end

  Controls.LuxuryResources:CalculateSize();
  Controls.LuxuryResources:ReprocessAnchoring();
  Controls.LuxuryGrid:ReprocessAnchoring();

  Controls.Stack:CalculateSize();
  Controls.Scroll:CalculateSize();

  Controls.CollapseAll:SetHide(false);
  Controls.BottomYieldTotals:SetHide( true );
  Controls.BottomResourceTotals:SetHide( false );
  Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - (Controls.BottomResourceTotals:GetSizeY() + SIZE_HEIGHT_PADDING_BOTTOM_ADJUST ) );
end

-- ===========================================================================
--	Tab Callback
-- ===========================================================================
function city_fields( kCityData, pCityInstance )

  TruncateStringWithTooltip(pCityInstance.CityName, 130, Locale.Lookup(kCityData.CityName)); 
  pCityInstance.Population:SetText( tostring(kCityData.Population) );

		if kCityData.HousingMultiplier == 0 or kCityData.Occupied then
    status = "LOC_HUD_REPORTS_STATUS_HALTED";
  elseif kCityData.HousingMultiplier <= 0.5 then
    status = "LOC_HUD_REPORTS_STATUS_SLOWED";
  else
    status = "LOC_HUD_REPORTS_STATUS_NORMAL";
  end

  pCityInstance.GrowthRateStatus:SetText( Locale.Lookup(status) );

  -- CQUI get real housing from improvements value
  local kCityID = kCityData.City:GetID();
  local CQUI_HousingFromImprovements = CQUI_HousingFromImprovementsTable[kCityID];
  pCityInstance.Housing:SetText( tostring( kCityData.Housing - kCityData.HousingFromImprovements + CQUI_HousingFromImprovements ) );    -- CQUI calculate real housing
  pCityInstance.Amenities:SetText( tostring(kCityData.AmenitiesNum).." / "..tostring(kCityData.AmenitiesRequiredNum) );

  local happinessText:string = Locale.Lookup( GameInfo.Happinesses[kCityData.Happiness].Name );
  pCityInstance.CitizenHappiness:SetText( happinessText );

  local warWearyValue:number = kCityData.AmenitiesLostFromWarWeariness;
  pCityInstance.WarWeariness:SetText( (warWearyValue==0) and "0" or "-"..tostring(warWearyValue) );

  local statusText:string = kCityData.IsUnderSiege and Locale.Lookup("LOC_HUD_REPORTS_STATUS_UNDER_SEIGE") or Locale.Lookup("LOC_HUD_REPORTS_STATUS_NORMAL");
  TruncateStringWithTooltip(pCityInstance.Status, 80, statusText); 
    
  pCityInstance.Strength:SetText( tostring(kCityData.Defense) );
  pCityInstance.Damage:SetText( tostring(kCityData.Damage) );

end

function ViewCityStatusPage()

  ResetTabForNewPageContent()

  -- Remember this tab when report is next opened: ARISTOS
  m_kCurrentTab = 3;

  -- ARISTOS: Hide the checkbox if not in Yields tab
  Controls.CityBuildingsCheckbox:SetHide( true );

  local instance:table = m_simpleIM:GetInstance()
  instance.Top:DestroyAllChildren()

  instance.Children = {}
  instance.Descend = false

  local pHeaderInstance:table = {}
  ContextPtr:BuildInstanceForControl( "CityStatusHeaderInstance", pHeaderInstance, instance.Top )

  pHeaderInstance.CityNameButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "name", instance ) end )
  pHeaderInstance.CityPopulationButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "pop", instance ) end )
  pHeaderInstance.CityHousingButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "house", instance ) end )
  pHeaderInstance.CityGrowthButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "growth", instance ) end )
  pHeaderInstance.CityAmenitiesButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "amen", instance ) end )
  pHeaderInstance.CityHappinessButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "happy", instance ) end )
  pHeaderInstance.CityWarButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "war", instance ) end )
  pHeaderInstance.CityStatusButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "status", instance ) end )
  pHeaderInstance.CityStrengthButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "str", instance ) end )
  pHeaderInstance.CityDamageButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "dam", instance ) end )

  --
  for cityName,kCityData in pairs( m_kCityData ) do

    local pCityInstance:table = {}

    ContextPtr:BuildInstanceForControl( "CityStatusEntryInstance", pCityInstance, instance.Top )
    table.insert( instance.Children, pCityInstance )

    city_fields( kCityData, pCityInstance )

  end

  Controls.Stack:CalculateSize();
  Controls.Scroll:CalculateSize();

  Controls.CollapseAll:SetHide(true);
  Controls.BottomYieldTotals:SetHide( true );
  Controls.BottomResourceTotals:SetHide( true );
  Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - 88);
end

function sort_cities( type, instance )

  local i = 0

  for _, kCityData in spairs( m_kCityData, function( t, a, b ) return city_sortFunction( instance.Descend, type, t, a, b ); end ) do
    i = i + 1
    local cityInstance = instance.Children[i]

    city_fields( kCityData, cityInstance )
  end

end

function city_sortFunction( descend, type, t, a, b )

  local aCity = 0
  local bCity = 0

  if type == "name" then
    aCity = Locale.Lookup( t[a].CityName )
    bCity = Locale.Lookup( t[b].CityName )
  elseif type == "pop" then
    aCity = t[a].Population
    bCity = t[b].Population
  elseif type == "house" then
    aCity = t[a].Housing
    bCity = t[b].Housing
  elseif type == "amen" then
    aCity = t[a].AmenitiesNum
    bCity = t[b].AmenitiesNum
  elseif type == "happy" then
    aCity = t[a].Happiness
    bCity = t[b].Happiness
  elseif type == "growth" then
    aCity = t[a].HousingMultiplier
    bCity = t[b].HousingMultiplier
  elseif type == "war" then
    aCity = t[a].AmenitiesLostFromWarWeariness
    bCity = t[b].AmenitiesLostFromWarWeariness
  elseif type == "status" then
    if t[a].IsUnderSiege == false then aCity = 10 else aCity = 20 end
    if t[b].IsUnderSiege == false then bCity = 10 else bCity = 20 end
  elseif type == "str" then
    aCity = t[a].Defense
    bCity = t[b].Defense
  elseif type == "dam" then
    aCity = t[a].Damage
    bCity = t[b].Damage
  end

  if descend then return bCity > aCity else return bCity < aCity end

end

function unit_sortFunction( descend, type, t, a, b )

  local aUnit = 0
  local bUnit = 0

  if type == "type" then
    aUnit = UnitManager.GetTypeName( t[a] )
    bUnit = UnitManager.GetTypeName( t[b] )
  elseif type == "name" then
    aUnit = Locale.Lookup( t[a]:GetName() )
    bUnit = Locale.Lookup( t[b]:GetName() )
  elseif type == "status" then
    aUnit = UnitManager.GetActivityType( t[a] )
    bUnit = UnitManager.GetActivityType( t[b] )
  elseif type == "level" then
    aUnit = t[a]:GetExperience():GetLevel()
    bUnit = t[b]:GetExperience():GetLevel()
  elseif type == "exp" then
    aUnit = t[a]:GetExperience():GetExperiencePoints()
    bUnit = t[b]:GetExperience():GetExperiencePoints()
  elseif type == "health" then
    aUnit = t[a]:GetMaxDamage() - t[a]:GetDamage()
    bUnit = t[b]:GetMaxDamage() - t[b]:GetDamage()
  elseif type == "move" then
    if ( t[a]:GetFormationUnitCount() > 1 ) then
      aUnit = t[a]:GetFormationMovesRemaining()
    else
      aUnit = t[a]:GetMovesRemaining()
    end

    if ( t[b]:GetFormationUnitCount() > 1 ) then
      bUnit = t[b]:GetFormationMovesRemaining()
    else
      bUnit = t[b]:GetMovesRemaining()
    end
  elseif type == "charge" then
    aUnit = t[a]:GetBuildCharges()
    bUnit = t[b]:GetBuildCharges()
  elseif type == "yield" then
    aUnit = t[a].yields
    bUnit = t[b].yields
  elseif type == "route" then
    aUnit = t[a].route
    bUnit = t[b].route
  elseif type == "class" then
    aUnit = t[a]:GetGreatPerson():GetClass()
    bUnit = t[b]:GetGreatPerson():GetClass()
  elseif type == "strength" then
    aUnit = t[a]:GetReligiousStrength()
    bUnit = t[b]:GetReligiousStrength()
  elseif type == "spread" then
    aUnit = t[a]:GetSpreadCharges()
    bUnit = t[b]:GetSpreadCharges()
  elseif type == "mission" then
    aUnit = t[a].mission
    bUnit = t[b].mission
  elseif type == "turns" then
    aUnit = t[a].turns
    bUnit = t[b].turns
  end

  if descend then return bUnit > aUnit else return bUnit < aUnit end

end

function sort_units( type, group, parent )

  local i = 0
  local unit_group = m_kUnitData["Unit_Report"][group]

  for _, unit in spairs( unit_group.units, function( t, a, b ) return unit_sortFunction( parent.Descend, type, t, a, b ) end ) do
    i = i + 1
    local unitInstance = parent.Children[i]

    common_unit_fields( unit, unitInstance )
    if unit_group.func then unit_group.func( unit, unitInstance, group, parent, type ) end

    unitInstance.LookAtButton:RegisterCallback( Mouse.eLClick, function() Close(); UI.LookAtPlot( unit:GetX( ), unit:GetY( ) ); UI.SelectUnit( unit ); end )
    unitInstance.LookAtButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound( "Main_Menu_Mouse_Over" ); end )
  end

end

function common_unit_fields( unit, unitInstance )

  if unitInstance.Formation then unitInstance.Formation:SetHide( true ) end

  local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas( "ICON_" .. UnitManager.GetTypeName( unit ), 32 )
  unitInstance.UnitType:SetTexture( textureOffsetX, textureOffsetY, textureSheet )
  unitInstance.UnitType:SetToolTipString( Locale.Lookup( GameInfo.Units[UnitManager.GetTypeName( unit )].Name ) )

  unitInstance.UnitName:SetText( Locale.Lookup( unit:GetName() ) )

  if ( unit:GetFormationUnitCount() > 1 ) then
    unitInstance.UnitMove:SetText( tostring( unit:GetFormationMovesRemaining() ) .. "/" .. tostring( unit:GetFormationMaxMoves() ) )
    unitInstance.Formation:SetHide( false )
  elseif unitInstance.UnitMove then
    unitInstance.UnitMove:SetText( tostring( unit:GetMovesRemaining() ) .. "/" .. tostring( unit:GetMaxMoves() ) )
  end

  -- adds the status icon
  local activityType:number = UnitManager.GetActivityType( unit )

  unitInstance.UnitStatus:SetHide( false )

  if activityType == ActivityTypes.ACTIVITY_SLEEP then
    local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas( "ICON_STATS_SLEEP", 22 )
    unitInstance.UnitStatus:SetTexture( textureOffsetX, textureOffsetY, textureSheet )
  elseif activityType == ActivityTypes.ACTIVITY_HOLD then
    local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas( "ICON_STATS_SKIP", 22 )
    unitInstance.UnitStatus:SetTexture( textureOffsetX, textureOffsetY, textureSheet )
  elseif activityType ~= ActivityTypes.ACTIVITY_AWAKE and unit:GetFortifyTurns() > 0 then
    local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas( "ICON_DEFENSE", 22 )
    unitInstance.UnitStatus:SetTexture( textureOffsetX, textureOffsetY, textureSheet )
  else
    -- just use a random icon for sorting purposes
    local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas( "ICON_STATS_SPREADCHARGES", 22 )
    unitInstance.UnitStatus:SetTexture( textureOffsetX, textureOffsetY, textureSheet )
    unitInstance.UnitStatus:SetHide( true )
  end

end

function group_military( unit, unitInstance, group, parent, type )

  local unitExp : table = unit:GetExperience()

  unitInstance.Promotion:SetHide( true )
  unitInstance.Upgrade:SetHide( true )

  if ( unit:GetMilitaryFormation() == MilitaryFormationTypes.CORPS_FORMATION ) then
    unitInstance.UnitName:SetText( Locale.Lookup( unit:GetName() ) .. " " .. "[ICON_Corps]" )
  elseif ( unit:GetMilitaryFormation() == MilitaryFormationTypes.ARMY_FORMATION ) then
    unitInstance.UnitName:SetText( Locale.Lookup( unit:GetName() ) .. " " .. "[ICON_Army]" )
  end

  unitInstance.UnitLevel:SetText( tostring( unitExp:GetLevel() ) )

  unitInstance.UnitExp:SetText( tostring( unitExp:GetExperiencePoints() ) .. "/" .. tostring( unitExp:GetExperienceForNextLevel() ) )

  local bCanStart, tResults = UnitManager.CanStartCommand( unit, UnitCommandTypes.PROMOTE, true, true );

  if ( bCanStart and tResults ) then
    unitInstance.Promotion:SetHide( false )
    local tPromotions = tResults[UnitCommandResults.PROMOTIONS];
    unitInstance.Promotion:RegisterCallback( Mouse.eLClick, function() bUnits.group = group; bUnits.parent = parent; bUnits.type = type; LuaEvents.Report_PromoteUnit( unit ); end )
  end

  unitInstance.UnitHealth:SetText( tostring( unit:GetMaxDamage() - unit:GetDamage() ) .. "/" .. tostring( unit:GetMaxDamage() ) )

  --ARISTOS: a "looser" test for the Upgrade action, to be able to show the disabled arrow if Upgrade is not possible
  local bCanStart = UnitManager.CanStartCommand( unit, UnitCommandTypes.UPGRADE, true);

  if ( bCanStart ) then
    unitInstance.Upgrade:SetHide( false )
    --ARISTOS: Now we "really" test if we can Upgrade the unit!
    local bCanStartNow, tResults = UnitManager.CanStartCommand( unit, UnitCommandTypes.UPGRADE, false, true);
    unitInstance.Upgrade:SetDisabled(not bCanStartNow);
    unitInstance.Upgrade:SetAlpha((not bCanStartNow and 0.5) or 1 ); --ARISTOS: dim if not upgradeable
    unitInstance.Upgrade:RegisterCallback( Mouse.eLClick, function() bUnits.group = group; bUnits.parent = parent; bUnits.type = type; UnitManager.RequestCommand( unit, UnitCommandTypes.UPGRADE ); end )
    if (tResults ~= nil) then
      local upgradeUnitName = GameInfo.Units[tResults[UnitOperationResults.UNIT_TYPE]].Name;
      local toolTipString	= Locale.Lookup( "LOC_UNITOPERATION_UPGRADE_DESCRIPTION" );
      toolTipString = toolTipString .. " " .. Locale.Lookup(upgradeUnitName);
      local upgradeCost = unit:GetUpgradeCost();

      if (upgradeCost ~= nil) then
        toolTipString = toolTipString .. ": " .. upgradeCost .. " " .. Locale.Lookup("LOC_TOP_PANEL_GOLD");
      end

      toolTipString = Locale.Lookup( "LOC_UNITOPERATION_UPGRADE_INFO", upgradeUnitName, upgradeCost );

      if (tResults[UnitOperationResults.FAILURE_REASONS] ~= nil) then
        -- Add the reason(s) to the tool tip
        for i,v in ipairs(tResults[UnitOperationResults.FAILURE_REASONS]) do
          toolTipString = toolTipString .. "[NEWLINE]" .. "[COLOR:Red]" .. Locale.Lookup(v) .. "[ENDCOLOR]";
        end
      end

      unitInstance.Upgrade:SetToolTipString( toolTipString )
    end
  end

end

function group_civilian( unit, unitInstance, group, parent, type )

  unitInstance.UnitCharges:SetText( tostring( unit:GetBuildCharges() ) )

end

function group_great( unit, unitInstance, group, parent, type )

  unitInstance.UnitClass:SetText( Locale.Lookup( GameInfo.GreatPersonClasses[unit:GetGreatPerson():GetClass()].Name ) )

end

function group_religious( unit, unitInstance, group, parent, type )

  unitInstance.UnitSpreads:SetText( unit:GetSpreadCharges() )
  unitInstance.UnitStrength:SetText( unit:GetReligiousStrength() )

end

function group_spy( unit, unitInstance, group, parent, type )

  local operationType : number = unit:GetSpyOperation();

  unitInstance.UnitOperation:SetText( "None" )
  unitInstance.UnitTurns:SetText( "0" )
  unit.mission = "None"
  unit.turns = 0

  if ( operationType ~= -1 ) then
    -- Mission Name
    local operationInfo:table = GameInfo.UnitOperations[operationType];
    unitInstance.UnitOperation:SetText( Locale.Lookup( operationInfo.Description ) )

    -- Turns Remaining
    unitInstance.UnitTurns:SetText( Locale.Lookup( "LOC_UNITPANEL_ESPIONAGE_MORE_TURNS", unit:GetSpyOperationEndTurn() - Game.GetCurrentGameTurn() ) )

    unit.mission = Locale.Lookup( operationInfo.Description )
    unit.turns = unit:GetSpyOperationEndTurn() - Game.GetCurrentGameTurn()
  end

end

function group_trader( unit, unitInstance, group, parent, type )

  local owningPlayer:table = Players[unit:GetOwner()];
  local cities:table = owningPlayer:GetCities();
  local yieldtype : table = { ["YIELD_FOOD"] = "[ICON_Food]",
                ["YIELD_PRODUCTION"] = "[ICON_Production]",
                ["YIELD_GOLD"] = "[ICON_Gold]",
                ["YIELD_SCIENCE"] = "[ICON_Science]",
                ["YIELD_CULTURE"] = "[ICON_Culture]",
                ["YIELD_FAITH"] = "[ICON_Faith]"
                      }
  local yields : string = ""

  unitInstance.UnitYields:SetText( Locale.Lookup("LOC_CITY_STATES_NONE") )
  unitInstance.UnitRoute:SetText( Locale.Lookup("LOC_CITY_STATES_NONE") )
  unit.yields = "No Yields"
  unit.route = "No Route"

  for _, city in cities:Members() do
    local outgoingRoutes:table = city:GetTrade():GetOutgoingRoutes();

    for i,route in ipairs(outgoingRoutes) do
      if unit:GetID() == route.TraderUnitID then
        -- Find origin city
        local originCity:table = cities:FindID(route.OriginCityID);

        -- Find destination city
        local destinationPlayer:table = Players[route.DestinationCityPlayer];
        local destinationCities:table = destinationPlayer:GetCities();
        local destinationCity:table = destinationCities:FindID(route.DestinationCityID);

        -- Set origin to destination name
        if originCity and destinationCity then
          unitInstance.UnitRoute:SetText( Locale.Lookup("LOC_HUD_UNIT_PANEL_TRADE_ROUTE_NAME", originCity:GetName(), destinationCity:GetName()) )
          unit.route = Locale.Lookup("LOC_HUD_UNIT_PANEL_TRADE_ROUTE_NAME", originCity:GetName(), destinationCity:GetName())
        end

        for j, yieldInfo in pairs( route.OriginYields ) do
          if yieldInfo.Amount > 0 then
            local yieldDetails:table = GameInfo.Yields[yieldInfo.YieldIndex];
            yields = yields .. yieldtype[yieldDetails.YieldType] .. "+" .. yieldInfo.Amount
            unitInstance.UnitYields:SetText( yields )
            unit.yields = yields
          end
        end
      end
    end
  end

end

-- ===========================================================================
--	!! Start of Deals Report Page
-- ===========================================================================
function ViewDealsPage()

  ResetTabForNewPageContent();

  -- Remember this tab when report is next opened: ARISTOS
  m_kCurrentTab = 4;

  -- ARISTOS: Hide the checkbox if not in Yields tab
  Controls.CityBuildingsCheckbox:SetHide( true );

  for j, pDeal in spairs( m_kCurrentDeals, function( t, a, b ) return t[b].EndTurn > t[a].EndTurn end ) do
    local ending = pDeal.EndTurn - Game.GetCurrentGameTurn()
    local turns = "turns"
    if ending == 1 then turns = "turn" end

    local instance : table = NewCollapsibleGroupInstance()

    instance.RowHeaderButton:SetText( Locale.Lookup("LOC_HUD_REPORTS_TRADE_DEAL_WITH", pDeal.WithCivilization) )
    instance.RowHeaderLabel:SetText(  Locale.Lookup("LOC_ESPIONAGEPANEL_PANEL_TURNS") .. ": " .. ending .. "[ICON_Turn]" .. " (" .. pDeal.EndTurn .. ")" )
    instance.RowHeaderLabel:SetHide( false )

    local dealHeaderInstance : table = {}
    ContextPtr:BuildInstanceForControl( "DealsHeader", dealHeaderInstance, instance.ContentStack )

    local iSlots = #pDeal.Sending

    if iSlots < #pDeal.Receiving then iSlots = #pDeal.Receiving end

    for i = 1, iSlots do
      local dealInstance : table = {}
      ContextPtr:BuildInstanceForControl( "DealsInstance", dealInstance, instance.ContentStack )
      table.insert( instance.Children, dealInstance )
    end

    for i, pDealItem in pairs( pDeal.Sending ) do
      if pDealItem.Icon then
        instance.Children[i].Outgoing:SetText( pDealItem.Icon .. " " .. pDealItem.Name )
      else
        instance.Children[i].Outgoing:SetText( pDealItem.Name )
      end
    end

    for i, pDealItem in pairs( pDeal.Receiving ) do
      if pDealItem.Icon then
        instance.Children[i].Incoming:SetText( pDealItem.Icon .. " " .. pDealItem.Name )
      else
        instance.Children[i].Incoming:SetText( pDealItem.Name )
      end
    end

    local pFooterInstance:table = {}
    ContextPtr:BuildInstanceForControl( "DealsFooterInstance", pFooterInstance, instance.ContentStack )
    pFooterInstance.Outgoing:SetText( Locale.Lookup("LOC_HUD_REPORTS_TOTALS") .. " " .. #pDeal.Sending )
    pFooterInstance.Incoming:SetText( Locale.Lookup("LOC_HUD_REPORTS_TOTALS") .. " " .. #pDeal.Receiving )

    SetGroupCollapsePadding( instance, pFooterInstance.Top:GetSizeY() )
    RealizeGroup( instance );
  end

  Controls.Stack:CalculateSize();
  Controls.Scroll:CalculateSize();

  Controls.CollapseAll:SetHide(true); -- same as on other pages
  Controls.BottomYieldTotals:SetHide( true )
  Controls.BottomResourceTotals:SetHide( true )
  Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - 88 )

end

-- ===========================================================================
--	!! Start of Unit Report Page
-- ===========================================================================
function ViewUnitsPage()

  ResetTabForNewPageContent();

  -- Remember this tab when report is next opened: ARISTOS
  m_kCurrentTab = 5;

  -- ARISTOS: Hide the checkbox if not in Yields tab
  Controls.CityBuildingsCheckbox:SetHide( true );

  for iUnitGroup, kUnitGroup in spairs( m_kUnitData["Unit_Report"], function( t, a, b ) return t[b].ID > t[a].ID end ) do
    local instance : table = NewCollapsibleGroupInstance()

    instance.RowHeaderButton:SetText( kUnitGroup.Name )
    instance.RowHeaderLabel:SetHide( true )

    local pHeaderInstance:table = {}
    ContextPtr:BuildInstanceForControl( kUnitGroup.Header, pHeaderInstance, instance.ContentStack )

    if pHeaderInstance.UnitTypeButton then pHeaderInstance.UnitTypeButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_units( "type", iUnitGroup, instance ) end ) end
    if pHeaderInstance.UnitNameButton then pHeaderInstance.UnitNameButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_units( "name", iUnitGroup, instance ) end ) end
    if pHeaderInstance.UnitStatusButton then pHeaderInstance.UnitStatusButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_units( "status", iUnitGroup, instance ) end ) end
    if pHeaderInstance.UnitLevelButton then pHeaderInstance.UnitLevelButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_units( "level", iUnitGroup, instance ) end ) end
    if pHeaderInstance.UnitExpButton then pHeaderInstance.UnitExpButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_units( "exp", iUnitGroup, instance ) end ) end
    if pHeaderInstance.UnitHealthButton then pHeaderInstance.UnitHealthButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_units( "health", iUnitGroup, instance ) end ) end
    if pHeaderInstance.UnitMoveButton then pHeaderInstance.UnitMoveButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_units( "move", iUnitGroup, instance ) end ) end
    if pHeaderInstance.UnitChargeButton then pHeaderInstance.UnitChargeButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_units( "charge", iUnitGroup, instance ) end ) end
    if pHeaderInstance.UnitYieldButton then pHeaderInstance.UnitYieldButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_units( "yield", iUnitGroup, instance ) end ) end
    if pHeaderInstance.UnitRouteButton then pHeaderInstance.UnitRouteButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_units( "route", iUnitGroup, instance ) end ) end
    if pHeaderInstance.UnitClassButton then pHeaderInstance.UnitClassButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_units( "class", iUnitGroup, instance ) end ) end
    if pHeaderInstance.UnitStrengthButton then pHeaderInstance.UnitStrengthButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_units( "strength", iUnitGroup, instance ) end ) end
    if pHeaderInstance.UnitSpreadButton then pHeaderInstance.UnitSpreadButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_units( "spread", iUnitGroup, instance ) end ) end

    for i, unit in ipairs( kUnitGroup.units ) do
      local unitInstance:table = {}
      table.insert( instance.Children, unitInstance )

      ContextPtr:BuildInstanceForControl( kUnitGroup.Entry, unitInstance, instance.ContentStack )

      common_unit_fields( unit, unitInstance )

      if kUnitGroup.func then kUnitGroup.func( unit, unitInstance, iUnitGroup, instance ) end

      -- allows you to select a unit and zoom to them
      unitInstance.LookAtButton:RegisterCallback( Mouse.eLClick, function() Close(); UI.LookAtPlot( unit:GetX( ), unit:GetY( ) ); UI.SelectUnit( unit ); end )
      unitInstance.LookAtButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound( "Main_Menu_Mouse_Over" ); end )
    end

    local pFooterInstance:table = {}
    ContextPtr:BuildInstanceForControl( "UnitsFooterInstance", pFooterInstance, instance.ContentStack )
    pFooterInstance.Amount:SetText( tostring( #kUnitGroup.units ) )

    SetGroupCollapsePadding( instance, pFooterInstance.Top:GetSizeY() )
    RealizeGroup( instance )
  end

  Controls.Stack:CalculateSize();
  Controls.Scroll:CalculateSize();

  Controls.CollapseAll:SetHide(true); -- same as on other pages
  Controls.BottomYieldTotals:SetHide( true )
  Controls.BottomResourceTotals:SetHide( true )
  Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - 88 )


end

-- ===========================================================================
--	!! End of Unit Report Page
-- ===========================================================================

-- ===========================================================================
--
-- ===========================================================================
function AddTabSection( name:string, populateCallback:ifunction )
  local kTab		:table				= m_tabIM:GetInstance();
  kTab.Button[DATA_FIELD_SELECTION]	= kTab.Selection;

  local callback	:ifunction	= function()
    if m_tabs.prevSelectedControl ~= nil then
      m_tabs.prevSelectedControl[DATA_FIELD_SELECTION]:SetHide(true);
    end
    kTab.Selection:SetHide(false);
    populateCallback();
  end

  kTab.Button:GetTextControl():SetText( Locale.Lookup(name) );
  kTab.Button:SetSizeToText( 40, 20 );
    kTab.Button:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

  m_tabs.AddTab( kTab.Button, callback );
end


-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
  local uiMsg :number = pInputStruct:GetMessageType();
  if uiMsg == KeyEvents.KeyUp then
    local uiKey = pInputStruct:GetKey();
    if uiKey == Keys.VK_ESCAPE then
      if ContextPtr:IsHidden()==false then
        Close();
        return true;
      end
    end
  end
  return false;
end


-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnInit( isReload:boolean )
  if isReload then
    if ContextPtr:IsHidden()==false then
      Open();
    end
  end
  m_tabs.AddAnimDeco(Controls.TabAnim, Controls.TabArrow);
end


-- ===========================================================================
function Resize()
  local topPanelSizeY:number = 30;

  if m_debugFullHeight then
    x,y = UIManager:GetScreenSizeVal();
    Controls.Main:SetSizeY( y - topPanelSizeY );
    Controls.Main:SetOffsetY( topPanelSizeY * 0.5 );
  end
end

-- ===========================================================================
--
-- ===========================================================================

function OnToggleCityBuildings()
  local isChecked = Controls.CityBuildingsCheckbox:IsSelected();
  Controls.CityBuildingsCheckbox:SetSelected( not isChecked );
  ViewYieldsPage();
end

-- ===========================================================================
--ARISTOS: Toggles for different resources in Resources tab
function OnToggleStrategic()
  local isChecked = Controls.StrategicCheckbox:IsSelected();
  Controls.StrategicCheckbox:SetSelected( not isChecked );
  ViewResourcesPage();
end

function OnToggleLuxury()
  local isChecked = Controls.LuxuryCheckbox:IsSelected();
  Controls.LuxuryCheckbox:SetSelected( not isChecked );
  ViewResourcesPage();
end

function OnToggleBonus()
  local isChecked = Controls.BonusCheckbox:IsSelected();
  Controls.BonusCheckbox:SetSelected( not isChecked );
  ViewResourcesPage();
end
--ARISTOS: End resources toggle

-- ===========================================================================
--CQUI get real housing from improvements
function CQUI_HousingFromImprovementsTableInsert (pCityID, CQUI_HousingFromImprovements)
  CQUI_HousingFromImprovementsTable[pCityID] = CQUI_HousingFromImprovements;
end

function OnLoadScreenClose()
  -- Add Icon to Launchbar
  local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas("ICON_CIVIC_FUTURE_CIVIC" ,38);
  local reportsButtonInfo = {
    -- ICON TEXTURE
    IconTexture = {
      OffsetX = textureOffsetX;
      OffsetY = textureOffsetY;
      Sheet = textureSheet;
    };

    -- BUTTON TEXTURE
    BaseTexture = {
      OffsetX = 4;
      OffsetY = 245;
      Sheet = "LaunchBar_Hook_CultureButton";

      -- Offset to have when hovering
      HoverOffsetX = 4;
      HoverOffsetY = 5;
    };

    -- BUTTON INFO
    Callback = Open;
    Tooltip = Locale.Lookup("LOC_HUD_REPORTS_VIEW_REPORTS");
  }

  LuaEvents.LaunchBar_AddIcon(reportsButtonInfo);
end

-- ===========================================================================
function Initialize()

  Resize();

  m_tabs = CreateTabs( Controls.TabContainer, 42, 34, 0xFF331D05 );
  --AddTabSection( "Test",								ViewTestPage );			--TRONSTER debug
  --AddTabSection( "Test2",								ViewTestPage );			--TRONSTER debug
  AddTabSection( "LOC_HUD_REPORTS_TAB_YIELDS",		ViewYieldsPage );
  AddTabSection( "LOC_HUD_REPORTS_TAB_RESOURCES",	ViewResourcesPage );
  AddTabSection( "LOC_HUD_REPORTS_TAB_CITY_STATUS",	ViewCityStatusPage );
  AddTabSection( "LOC_HUD_REPORTS_TAB_CURRENT_DEALS", ViewDealsPage );
  AddTabSection( "LOC_UNIT_NAME",						ViewUnitsPage );

  m_tabs.SameSizedTabs(0);
  m_tabs.CenterAlignTabs(-10);

  -- UI Callbacks
  ContextPtr:SetInitHandler( OnInit );
  ContextPtr:SetInputHandler( OnInputHandler, true );
  ContextPtr:SetRefreshHandler( function() if bUnits.group then m_kCityData, m_kCityTotalData, m_kResourceData, m_kUnitData, m_kDealData, m_kCultureData, m_kCurrentDeals = GetData(); sort_units( bUnits.type, bUnits.group, bUnits.parent ); end; end )

  Events.UnitPromoted.Add( function() LuaEvents.UnitPanel_HideUnitPromotion(); ContextPtr:RequestRefresh() end )
  Events.UnitUpgraded.Add( function() ContextPtr:RequestRefresh() end )
  Events.LoadScreenClose.Add( OnLoadScreenClose );

  Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnCloseButton );
  Controls.CloseButton:RegisterCallback(	Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.CollapseAll:RegisterCallback( Mouse.eLClick, OnCollapseAllButton );
  Controls.CollapseAll:RegisterCallback(	Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

  Controls.CityBuildingsCheckbox:RegisterCallback( Mouse.eLClick, OnToggleCityBuildings )
  Controls.CityBuildingsCheckbox:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end )

  --ARISTOS: Resources toggle
  Controls.LuxuryCheckbox:RegisterCallback( Mouse.eLClick, OnToggleLuxury );
  Controls.LuxuryCheckbox:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end );
  Controls.LuxuryCheckbox:SetSelected( true );

  Controls.StrategicCheckbox:RegisterCallback( Mouse.eLClick, OnToggleStrategic );
  Controls.StrategicCheckbox:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end );
  Controls.StrategicCheckbox:SetSelected( true );

  Controls.BonusCheckbox:RegisterCallback( Mouse.eLClick, OnToggleBonus );
  Controls.BonusCheckbox:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end );
  Controls.BonusCheckbox:SetSelected( true );

  -- Events
  LuaEvents.TopPanel_OpenReportsScreen.Add( OnTopOpenReportsScreen );
  LuaEvents.TopPanel_CloseReportsScreen.Add( OnTopCloseReportsScreen );
  LuaEvents.CQUI_RealHousingFromImprovementsCalculated.Add(CQUI_HousingFromImprovementsTableInsert);    --CQUI get real housing from improvements values
end
Initialize();
