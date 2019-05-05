-- ===========================================================================
-- Base File
-- ===========================================================================
include("ProductionPanel");

-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_OnInterfaceModeChanged = OnInterfaceModeChanged
BASE_OnClose = OnClose
BASE_OnCityBannerManagerProductionToggle = OnCityBannerManagerProductionToggle
BASE_PopulateGenericItemData = PopulateGenericItemData
BASE_View = View
BASE_GetData = GetData
BASE_Refresh = Refresh
BASE_OnNotificationPanelChooseProduction = OnNotificationPanelChooseProduction
BASE_OnCityBannerManagerProductionToggle = OnCityBannerManagerProductionToggle

-- ===========================================================================
-- CQUI Members
-- ===========================================================================
local CQUI_PurchaseTable = {}; -- key = item Hash
local CQUI_ProductionQueue :boolean = true;
local CQUI_ShowProductionRecommendations :boolean = false;
local CQUI_ManagerShowing = false;

function CQUI_OnSettingsUpdate()
  CQUI_ProductionQueue = GameConfiguration.GetValue("CQUI_ProductionQueue");
  CQUI_ShowProductionRecommendations = GameConfiguration.GetValue("CQUI_ShowProductionRecommendations") == 1
  CQUI_SelectRightTab()
  Controls.CQUI_ShowManagerButton:SetHide(not CQUI_ProductionQueue);
end

function CQUI_SelectRightTab()
  if(not CQUI_ProductionQueue) then
    OnTabChangeProduction();
  else
    OnTabChangeQueue();
  end
end

function CQUI_ToogleManager()
  if CQUI_ManagerShowing then
    CQUI_ManagerShowing = false;
    OnTabChangeQueue();
  else
    CQUI_ManagerShowing = true;
    OnTabChangeManager();
  end
  Controls.CQUI_ShowManagerButton:SetSelected(CQUI_ManagerShowing);
end

function CQUI_PurchaseUnit(item, city)
  return function()
    if not item.CantAfford and not item.Disabled then
      PurchaseUnit(city, item);
    end
  end
end

function CQUI_PurchaseUnitCorps(item, city)
  return function()
    if not item.CantAfford and not item.Disabled then
      PurchaseUnitCorps(city, item);
    end
  end
end

function CQUI_PurchaseUnitArmy(item, city)
  return function()
    if not item.CantAfford and not item.Disabled then
      PurchaseUnitArmy(city, item);
    end
  end
end

function CQUI_PurchaseDistrict(item, city)
  return function()
    if not item.CantAfford and not item.Disabled then
      PurchaseDistrict(city, item);
    end
  end
end

function CQUI_PurchaseBuilding(item, city)
  return function()
    if not item.CantAfford and not item.Disabled then
      PurchaseBuilding(city, item);
    end
  end
end

-- ===========================================================================
--  CQUI modified View functiton
--  create the list of purchasable items
-- ===========================================================================
function View(data)
  for i, item in ipairs(data.UnitPurchases) do
    if item.Yield then 
      if(CQUI_PurchaseTable[item.Hash] == nil) then
        CQUI_PurchaseTable[item.Hash] = {};
      end
      if (item.Yield == "YIELD_GOLD") then
        CQUI_PurchaseTable[item.Hash]["gold"] = item.Cost;
        CQUI_PurchaseTable[item.Hash]["goldCantAfford"] = item.CantAfford;
        CQUI_PurchaseTable[item.Hash]["goldDisabled"] = item.Disabled;
        CQUI_PurchaseTable[item.Hash]["goldCallback"] = CQUI_PurchaseUnit(item, data.City);
        if(item.Corps) then
          CQUI_PurchaseTable[item.Hash]["corpsGold"] = item.CorpsCost;
          CQUI_PurchaseTable[item.Hash]["corpsGoldDisabled"] = item.CorpsDisabled;
          CQUI_PurchaseTable[item.Hash]["corpsGoldCallback"] = CQUI_PurchaseUnitCorps(item, data.City);
        end
        if(item.Army) then
          CQUI_PurchaseTable[item.Hash]["armyGold"] = item.ArmyCost;
          CQUI_PurchaseTable[item.Hash]["armyGoldDisabled"] = item.ArmyDisabled;
          CQUI_PurchaseTable[item.Hash]["armyGoldCallback"] = CQUI_PurchaseUnitArmy(item, data.City);
        end
      else
        CQUI_PurchaseTable[item.Hash]["faith"] = item.Cost;
        CQUI_PurchaseTable[item.Hash]["faithCantAfford"] = item.CantAfford;
        CQUI_PurchaseTable[item.Hash]["faithDisabled"] = item.Disabled;
        CQUI_PurchaseTable[item.Hash]["faithCallback"] = CQUI_PurchaseUnit(item, data.City);
        if(item.Corps) then
          CQUI_PurchaseTable[item.Hash]["corpsFaith"] = item.CorpsCost;
          CQUI_PurchaseTable[item.Hash]["corpsFaithDisabled"] = item.ArmyDisabled;
          CQUI_PurchaseTable[item.Hash]["corpsFaithCallback"] = CQUI_PurchaseUnit(item, data.City);
        end
        if(item.Army) then
          CQUI_PurchaseTable[item.Hash]["armyFaith"] = item.ArmyCost;
          CQUI_PurchaseTable[item.Hash]["armyFaithDisabled"] = item.ArmyDisabled;
          CQUI_PurchaseTable[item.Hash]["armyFaithCallback"] = CQUI_PurchaseUnit(item, data.City);
        end
      end
    end
  end

  for i, item in ipairs(data.DistrictPurchases) do
    if item.Yield then 
      if(CQUI_PurchaseTable[item.Hash] == nil) then
        CQUI_PurchaseTable[item.Hash] = {};
      end
      if (item.Yield == "YIELD_GOLD") then
        CQUI_PurchaseTable[item.Hash]["goldCantAfford"] = item.CantAfford;
        CQUI_PurchaseTable[item.Hash]["goldDisabled"] = item.Disabled;
        CQUI_PurchaseTable[item.Hash]["gold"] = item.Cost;
        CQUI_PurchaseTable[item.Hash]["goldCallback"] = CQUI_PurchaseDistrict(item, data.City);
      else
        CQUI_PurchaseTable[item.Hash]["faithCantAfford"] = item.CantAfford;
        CQUI_PurchaseTable[item.Hash]["faithDisabled"] = item.Disabled;
        CQUI_PurchaseTable[item.Hash]["faith"] = item.Cost;
        CQUI_PurchaseTable[item.Hash]["faithCallback"] = CQUI_PurchaseDistrict(item, data.City);
      end
    end
  end

  for i, item in ipairs(data.BuildingPurchases) do
    if item.Yield then 
      if(CQUI_PurchaseTable[item.Hash] == nil) then
        CQUI_PurchaseTable[item.Hash] = {};
      end
      if (item.Yield == "YIELD_GOLD") then
        CQUI_PurchaseTable[item.Hash]["goldCantAfford"] = item.CantAfford;
        CQUI_PurchaseTable[item.Hash]["goldDisabled"] = item.Disabled;
        CQUI_PurchaseTable[item.Hash]["gold"] = item.Cost;
        CQUI_PurchaseTable[item.Hash]["goldCallback"] = CQUI_PurchaseBuilding(item, data.City);
      else
        CQUI_PurchaseTable[item.Hash]["faithCantAfford"] = item.CantAfford;
        CQUI_PurchaseTable[item.Hash]["faithDisabled"] = item.Disabled;
        CQUI_PurchaseTable[item.Hash]["faith"] = item.Cost;
        CQUI_PurchaseTable[item.Hash]["faithCallback"] = CQUI_PurchaseBuilding(item, data.City);
      end
    end
  end

  BASE_View(data)
end

-- ===========================================================================
--  CQUI modified GetData functiton
--  add religious units to the unit list
-- ===========================================================================
function GetData()
  local new_data = BASE_GetData()

	local pSelectedCity:table = UI.GetHeadSelectedCity();
	if pSelectedCity == nil then
		Close();
		return nil;
	end

	local buildQueue	= pSelectedCity:GetBuildQueue();

  for row in GameInfo.Units() do
    if row.MustPurchase and buildQueue:CanProduce( row.Hash, true ) and row.PurchaseYield == "YIELD_FAITH" then
      local isCanProduceExclusion, results	 = buildQueue:CanProduce( row.Hash, false, true );
      local isDisabled				:boolean = row.MustPurchase;
      local sAllReasons				 :string = ComposeFailureReasonStrings( isDisabled, results );
      local sToolTip					 :string = ToolTipHelper.GetUnitToolTip( row.Hash, MilitaryFormationTypes.STANDARD_MILITARY_FORMATION, buildQueue ) .. sAllReasons;

      local nProductionCost		:number = buildQueue:GetUnitCost( row.Index );
      local nProductionProgress	:number = buildQueue:GetUnitProgress( row.Index );
      sToolTip = sToolTip .. ComposeProductionCostString( nProductionProgress, nProductionCost );
        
      local kUnit :table = {
        Type				= row.UnitType, 
        Name				= row.Name, 
        ToolTip				= sToolTip, 
        Hash				= row.Hash, 
        Kind				= row.Kind, 
        TurnsLeft			= buildQueue:GetTurnsLeft( row.Hash ), 
        Disabled			= isDisabled, 
        Civilian			= row.FormationClass == "FORMATION_CLASS_CIVILIAN",
        Cost				= nProductionCost, 
        Progress			= nProductionProgress, 
        Corps				= false,
        CorpsCost			= 0,
        CorpsTurnsLeft		= 1,
        CorpsTooltip		= "",
        CorpsName			= "",
        Army				= false,
        ArmyCost			= 0,
        ArmyTurnsLeft		= 1,
        ArmyTooltip			= "",
        ArmyName			= "",
        ReligiousStrength	= row.ReligiousStrength,
        IsCurrentProduction = row.Hash == m_CurrentProductionHash
      };
        
      table.insert(new_data.UnitItems, kUnit );
    end
  end

  return new_data
end

-- ===========================================================================
--  CQUI modified PopulateGenericItemData functiton
--  add gold and faith purchase in the same list
-- ===========================================================================
function PopulateGenericItemData( kInstance:table, kItem:table )
  BASE_PopulateGenericItemData(kInstance, kItem);

  local notEnoughGoldColor = UI.GetColorValueFromHexLiteral(0xFF222258);
  local purchaseButtonPadding = 15;

  -- CQUI show recommandations check
	if not CQUI_ShowProductionRecommendations then
    kInstance.RecommendedIcon:SetHide(true);
  end

  -- CQUI Reset the color
  if kInstance.PurchaseButton then
    kInstance.PurchaseButton:GetTextControl():SetColor(UI.GetColorValueFromHexLiteral(0xFFFFFFFF));
  end
  if kInstance.CorpsPurchaseButton then
    kInstance.CorpsPurchaseButton:GetTextControl():SetColor(UI.GetColorValueFromHexLiteral(0xFFFFFFFF));
  end
  if kInstance.ArmyPurchaseButton then
    kInstance.ArmyPurchaseButton:GetTextControl():SetColor(UI.GetColorValueFromHexLiteral(0xFFFFFFFF));
  end
  if kInstance.FaithPurchaseButton then
    kInstance.FaithPurchaseButton:GetTextControl():SetColor(UI.GetColorValueFromHexLiteral(0xFFFFFFFF));
  end
  if kInstance.CorpsFaithPurchaseButton then
    kInstance.CorpsFaithPurchaseButton:GetTextControl():SetColor(UI.GetColorValueFromHexLiteral(0xFFFFFFFF));
  end
  if kInstance.ArmyFaithPurchaseButton then
    kInstance.ArmyFaithPurchaseButton:GetTextControl():SetColor(UI.GetColorValueFromHexLiteral(0xFFFFFFFF));
  end
  
  -- Gold purchase button for building, district and units
  if kInstance.PurchaseButton then
    if CQUI_PurchaseTable[kItem.Hash] and CQUI_PurchaseTable[kItem.Hash]["gold"] then
      kInstance.PurchaseButton:SetText(CQUI_PurchaseTable[kItem.Hash]["gold"] .. "[ICON_GOLD]");
      kInstance.PurchaseButton:SetSizeX(kInstance.PurchaseButton:GetTextControl():GetSizeX() + purchaseButtonPadding);
      kInstance.PurchaseButton:SetColor(UI.GetColorValueFromHexLiteral(0xFFF38FFF));
      kInstance.PurchaseButton:SetHide(false);
      kInstance.PurchaseButton:SetDisabled(false);
      kInstance.PurchaseButton:RegisterCallback(Mouse.eLClick, CQUI_PurchaseTable[kItem.Hash]["goldCallback"]);
      
      if CQUI_PurchaseTable[kItem.Hash]["goldCantAfford"] or CQUI_PurchaseTable[kItem.Hash]["goldDisabled"] then
        kInstance.PurchaseButton:SetDisabled(true);
        kInstance.PurchaseButton:SetColor(UI.GetColorValueFromHexLiteral(0xDD3366FF));
      end

      if CQUI_PurchaseTable[kItem.Hash]["goldCantAfford"] then
        kInstance.PurchaseButton:GetTextControl():SetColor(notEnoughGoldColor);
      end
    else
      kInstance.PurchaseButton:SetHide(true);
    end
  end

  -- Special case for Corps gold purchase button
  if kInstance.CorpsPurchaseButton then
    if CQUI_PurchaseTable[kItem.Hash] and CQUI_PurchaseTable[kItem.Hash]["corpsGold"] then
      kInstance.CorpsPurchaseButton:SetHide(false);
      kInstance.CorpsPurchaseButton:SetDisabled(false);
      kInstance.CorpsPurchaseButton:SetText(CQUI_PurchaseTable[kItem.Hash]["corpsGold"] .. "[ICON_GOLD]");
      kInstance.CorpsPurchaseButton:SetSizeX(kInstance.CorpsPurchaseButton:GetTextControl():GetSizeX() + purchaseButtonPadding);
      kInstance.CorpsPurchaseButton:RegisterCallback(Mouse.eLClick, CQUI_PurchaseTable[kItem.Hash]["corpsGoldCallback"]);

      if CQUI_PurchaseTable[kItem.Hash]["corpsGoldDisabled"] then
        kInstance.CorpsPurchaseButton:SetDisabled(true);
        kInstance.CorpsPurchaseButton:SetColor(UI.GetColorValueFromHexLiteral(0xDD3366FF));
        kInstance.CorpsPurchaseButton:GetTextControl():SetColor(notEnoughGoldColor);
      end
    else
      kInstance.CorpsPurchaseButton:SetHide(true);
    end
  end

  -- Special case for Army gold purchase button
  if kInstance.ArmyPurchaseButton then
    if CQUI_PurchaseTable[kItem.Hash] and CQUI_PurchaseTable[kItem.Hash]["armyGold"] then
      kInstance.ArmyPurchaseButton:SetHide(false);
      kInstance.ArmyPurchaseButton:SetDisabled(false);
      kInstance.ArmyPurchaseButton:SetText(CQUI_PurchaseTable[kItem.Hash]["armyGold"] .. "[ICON_GOLD]");
      kInstance.ArmyPurchaseButton:SetSizeX(kInstance.ArmyPurchaseButton:GetTextControl():GetSizeX() + purchaseButtonPadding);
      kInstance.ArmyPurchaseButton:RegisterCallback(Mouse.eLClick, CQUI_PurchaseTable[kItem.Hash]["armyGoldCallback"]);

      if CQUI_PurchaseTable[kItem.Hash]["armyGoldDisabled"] then
        kInstance.ArmyPurchaseButton:SetDisabled(true);
        kInstance.ArmyPurchaseButton:SetColor(UI.GetColorValueFromHexLiteral(0xDD3366FF));
        kInstance.ArmyPurchaseButton:GetTextControl():SetColor(notEnoughGoldColor);
      end
    else
      kInstance.ArmyPurchaseButton:SetHide(true);
    end
  end

  -- Faith purchase button for building, district and units
  if kInstance.FaithPurchaseButton then
    if CQUI_PurchaseTable[kItem.Hash] and CQUI_PurchaseTable[kItem.Hash]["faith"] then
      kInstance.FaithPurchaseButton:SetText(CQUI_PurchaseTable[kItem.Hash]["faith"] .. "[ICON_FAITH]");
      kInstance.FaithPurchaseButton:SetSizeX(kInstance.FaithPurchaseButton:GetTextControl():GetSizeX() + purchaseButtonPadding);
      kInstance.FaithPurchaseButton:SetColor(UI.GetColorValueFromHexLiteral(0xFFF38FFF));
      kInstance.FaithPurchaseButton:SetHide(false);
      kInstance.FaithPurchaseButton:SetDisabled(false);
      kInstance.FaithPurchaseButton:RegisterCallback(Mouse.eLClick, CQUI_PurchaseTable[kItem.Hash]["faithCallback"]);
      
      if CQUI_PurchaseTable[kItem.Hash]["faithCantAfford"] or CQUI_PurchaseTable[kItem.Hash]["faithDisabled"] then
        kInstance.FaithPurchaseButton:SetDisabled(true);
        kInstance.FaithPurchaseButton:SetColor(UI.GetColorValueFromHexLiteral(0xDD3366FF));
      end

      if CQUI_PurchaseTable[kItem.Hash]["faithCantAfford"] then
        kInstance.FaithPurchaseButton:GetTextControl():SetColor(notEnoughGoldColor);
      end
    else
      kInstance.FaithPurchaseButton:SetHide(true);
    end
  end

  -- Special case for Corps faith purchase button
  if kInstance.CorpsFaithPurchaseButton then
    if CQUI_PurchaseTable[kItem.Hash] and CQUI_PurchaseTable[kItem.Hash]["corpsFaith"] then
      kInstance.CorpsFaithPurchaseButton:SetHide(false);
      kInstance.CorpsFaithPurchaseButton:SetDisabled(false);
      kInstance.CorpsFaithPurchaseButton:SetText(CQUI_PurchaseTable[kItem.Hash]["corpsFaith"] .. "[ICON_GOLD]");
      kInstance.CorpsFaithPurchaseButton:SetSizeX(kInstance.CorpsFaithPurchaseButton:GetTextControl():GetSizeX() + purchaseButtonPadding);
      kInstance.CorpsFaithPurchaseButton:RegisterCallback(Mouse.eLClick, CQUI_PurchaseTable[kItem.Hash]["corpsFaithCallback"]);

      if CQUI_PurchaseTable[kItem.Hash]["corpsFaithDisabled"] then
        kInstance.CorpsFaithPurchaseButton:SetDisabled(true);
        kInstance.CorpsFaithPurchaseButton:SetColor(UI.GetColorValueFromHexLiteral(0xDD3366FF));
        kInstance.CorpsFaithPurchaseButton:GetTextControl():SetColor(notEnoughGoldColor);
      end
    else
      kInstance.CorpsFaithPurchaseButton:SetHide(true);
    end
  end

  -- Special case for Army faith purchase button
  if kInstance.ArmyFaithPurchaseButton then
    if CQUI_PurchaseTable[kItem.Hash] and CQUI_PurchaseTable[kItem.Hash]["armyFaith"] then
      kInstance.ArmyFaithPurchaseButton:SetHide(false);
      kInstance.ArmyFaithPurchaseButton:SetDisabled(false);
      kInstance.ArmyFaithPurchaseButton:SetText(CQUI_PurchaseTable[kItem.Hash]["armyFaith"] .. "[ICON_GOLD]");
      kInstance.ArmyFaithPurchaseButton:SetSizeX(kInstance.ArmyFaithPurchaseButton:GetTextControl():GetSizeX() + purchaseButtonPadding);
      kInstance.ArmyFaithPurchaseButton:RegisterCallback(Mouse.eLClick, CQUI_PurchaseTable[kItem.Hash]["armyFaithCallback"]);

      if CQUI_PurchaseTable[kItem.Hash]["armyFaithDisabled"] then
        kInstance.ArmyFaithPurchaseButton:SetDisabled(true);
        kInstance.ArmyFaithPurchaseButton:SetColor(UI.GetColorValueFromHexLiteral(0xDD3366FF));
        kInstance.ArmyFaithPurchaseButton:GetTextControl():SetColor(notEnoughGoldColor);
      end
    else
      kInstance.ArmyFaithPurchaseButton:SetHide(true);
    end
  end
end

-- ===========================================================================
--  CQUI modified BuildBuilding function : removed the InterfaceMode change
-- ===========================================================================
function BuildBuilding(city, buildingEntry)
	if CheckQueueItemSelected() then
		return;
	end

	local building			:table		= GameInfo.Buildings[buildingEntry.Type];
	local bNeedsPlacement	:boolean	= building.RequiresPlacement;

	-- UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);

	local pBuildQueue = city:GetBuildQueue();
	if (pBuildQueue:HasBeenPlaced(buildingEntry.Hash)) then
		bNeedsPlacement = false;
	end

	-- If it's a Wonder and the city already has the building then it doesn't need to be replaced.
	if (bNeedsPlacement) then
		local cityBuildings = city:GetBuildings();
		if (cityBuildings:HasBuilding(buildingEntry.Hash)) then
			bNeedsPlacement = false;
		end
	end

	-- Does the building need to be placed?
	if ( bNeedsPlacement ) then			
		-- If so, set the placement mode
		local tParameters = {}; 
		tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = buildingEntry.Hash;
		GetBuildInsertMode(tParameters);
		UI.SetInterfaceMode(InterfaceModeTypes.BUILDING_PLACEMENT, tParameters);
		Close();
	else
		-- If not, add it to the queue.
		local tParameters = {}; 
		tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = buildingEntry.Hash;  
		GetBuildInsertMode(tParameters);
		CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
    UI.PlaySound("Confirm_Production");
		CloseAfterNewProduction();
	end
end

-- ===========================================================================
--  CQUI modified Close functiton
--  Add a check to see if we're placing something down (no need to close)
--  Changed the condition of closing (not IsReversing)
-- ===========================================================================
function Close()
  if UI.GetInterfaceMode() == InterfaceModeTypes.BUILDING_PLACEMENT or UI.GetInterfaceMode() == InterfaceModeTypes.DISTRICT_PLACEMENT then
    return;
  end

  if (not Controls.SlideIn:IsReversing()) then      -- Need to check to make sure that we have not already begun the transition before attempting to close the panel.
    UI.PlaySound("Production_Panel_Closed");
    Controls.SlideIn:Reverse();
    Controls.AlphaIn:Reverse();
    Controls.PauseDismissWindow:Play();
    LuaEvents.ProductionPanel_CloseManager();
    LuaEvents.ProductionPanel_Close();
  end
end

-- ===========================================================================
--  CQUI modified OnExpand function : fixed slide speed and list size
-- ===========================================================================
function OnExpand(instance:table)
  instance.ListSlide:SetSpeed(100); -- CQUI : fix the sliding time

  m_kClickedInstance = instance;
  instance.HeaderOn:SetHide(false);
  instance.Header:SetHide(true);
  instance.List:SetHide(false);
  -- CQUI : fix the list flickering when it's refreshed
  --instance.ListSlide:SetSizeY(instance.List:GetSizeY());
  --instance.ListAlpha:SetSizeY(instance.List:GetSizeY());
  instance.ListSlide:SetToBeginning();
  instance.ListAlpha:SetToBeginning();
  instance.ListSlide:Play();
  instance.ListAlpha:Play();
  -- CQUI : Don't touch the interface Mode
  --UI.SetInterfaceMode(InterfaceModeTypes.CITY_MANAGEMENT);
end

-- ===========================================================================
--  CQUI modified Refresh function : reset the CQUI_PurchaseTable
-- ===========================================================================
function Refresh()
  CQUI_PurchaseTable = {};

  BASE_Refresh()
end

-- ===========================================================================
--  CQUI modified Open function
-- ===========================================================================
function Open()
  if ContextPtr:IsHidden() or Controls.SlideIn:IsReversing() then         -- The ContextPtr is only hidden as a callback to the finished SlideIn animation, so this check should be sufficient to ensure that we are not animating.
    -- Sets up proper selection AND the associated lens so it's not stuck "on".
    UI.PlaySound("Production_Panel_Open");
    Controls.PauseDismissWindow:SetToBeginning(); -- AZURENCY : fix the callback that hide the pannel to be called during the Openning animation
    LuaEvents.ProductionPanel_Open();
    Refresh();
    CQUI_SelectRightTab();
    ContextPtr:SetHide(false);
    Controls.ProductionListScroll:SetScrollValue(0);

    -- Size the panel to the maximum Y value of the expanded content
    Controls.AlphaIn:SetToBeginning();
    Controls.SlideIn:SetToBeginning();
    Controls.AlphaIn:Play();
    Controls.SlideIn:Play();
  end
end

-- ===========================================================================
--  CQUI modified OnClose via click
-- ===========================================================================
function OnClose()
  LuaEvents.CQUI_CityPanel_CityviewDisable();
end

-- ===========================================================================
--	CQUI modified CloseAfterNewProduction
-- ===========================================================================
function CloseAfterNewProduction()
  return;
end

-- ===========================================================================
--	CQUI modified OnCityBannerManagerProductionToggle
-- ===========================================================================
function OnCityBannerManagerProductionToggle()
  if(ContextPtr:IsHidden()) then
    Open();
    m_tabs.SelectTab(m_productionTab);
  end
end

-- ===========================================================================
--	CQUI modified OnNotificationPanelChooseProduction : Removed tab selection
-- ===========================================================================
function OnNotificationPanelChooseProduction()
	if ContextPtr:IsHidden() then
		Open();
		--m_tabs.SelectTab(m_productionTab);
	end
end

-- ===========================================================================
--	CQUI modified OnCityBannerManagerProductionToggle : Removed tab selection
-- ===========================================================================
function OnCityBannerManagerProductionToggle()
	if(ContextPtr:IsHidden()) then
		Open();
		--m_tabs.SelectTab(m_productionTab);
	else
		Close();
	end
end

-- ===========================================================================
--  CQUI Cityview
-- ===========================================================================
function CQUI_OnCityviewEnabled()
  Open();
end

function CQUI_OnCityviewDisabled()
  Close();
end

-- ===========================================================================
--  CQUI modified OnInterfaceModeChanged
-- ===========================================================================
function OnInterfaceModeChanged( eOldMode:number, eNewMode:number )
  return;
end

-- ===========================================================================
--  CQUI modified CreateCorrectTabs : no need for tabs, one unified list
-- ===========================================================================
function CreateCorrectTabs()
end

function Initialize()
  Events.InterfaceModeChanged.Remove( BASE_OnInterfaceModeChanged );
  Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
  Events.CityMadePurchase.Add( function() Refresh(); end);

  LuaEvents.CityBannerManager_ProductionToggle.Remove( BASE_OnCityBannerManagerProductionToggle );
  LuaEvents.CityBannerManager_ProductionToggle.Add( OnCityBannerManagerProductionToggle );

  LuaEvents.NotificationPanel_ChooseProduction.Remove( BASE_OnNotificationPanelChooseProduction );
  LuaEvents.NotificationPanel_ChooseProduction.Add( OnNotificationPanelChooseProduction );

  LuaEvents.CityBannerManager_ProductionToggle.Remove( BASE_OnCityBannerManagerProductionToggle );
  LuaEvents.CityBannerManager_ProductionToggle.Add( OnCityBannerManagerProductionToggle );

  Controls.CloseButton:ClearCallback(Mouse.eLClick);
  Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);
  Controls.CQUI_ShowManagerButton:RegisterCallback(Mouse.eLClick, CQUI_ToogleManager);
  
  LuaEvents.CQUI_ProductionPanel_CityviewEnable.Add( CQUI_OnCityviewEnabled);
  LuaEvents.CQUI_ProductionPanel_CityviewDisable.Add( CQUI_OnCityviewDisabled);
  LuaEvents.CQUI_SettingsUpdate.Add(CQUI_OnSettingsUpdate);
  LuaEvents.CQUI_SettingsInitialized.Add(CQUI_OnSettingsUpdate);
end
Initialize();