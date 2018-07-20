-- ===========================================================================
--  Production Panel / Purchase Panel
-- ===========================================================================

include( "ToolTipHelper" );
include( "InstanceManager" );
include( "TabSupport" );
include( "Civ6Common" );
include( "SupportFunctions" );
include( "AdjacencyBonusSupport");
include( "DragSupport" );
include( "CitySupport" );

-- ===========================================================================
--  Constants
-- ===========================================================================
local RELOAD_CACHE_ID :string = "ProductionPanel";
local COLOR_LOW_OPACITY :number = 0x3fffffff;
local HEADER_Y      :number = 41;
local WINDOW_HEADER_Y :number = 150;
local TOPBAR_Y      :number = 28;
local SEPARATOR_Y   :number = 20;
local BUTTON_Y      :number = 32;
local DISABLED_PADDING_Y:number = 10;
local TEXTURE_BASE        :string = "UnitFlagBase";
local TEXTURE_CIVILIAN      :string = "UnitFlagCivilian";
local TEXTURE_RELIGION			:string = "UnitFlagReligion";
local TEXTURE_EMBARK      :string = "UnitFlagEmbark";
local TEXTURE_FORTIFY     :string = "UnitFlagFortify";
local TEXTURE_NAVAL       :string = "UnitFlagNaval";
local TEXTURE_SUPPORT     :string = "UnitFlagSupport";
local TEXTURE_TRADE       :string = "UnitFlagTrade";
local BUILDING_IM_PREFIX    :string = "buildingListingIM_";
local BUILDING_DRAWER_PREFIX  :string = "buildingDrawer_";
local ICON_PREFIX       :string = "ICON_";
local LISTMODE          :table  = {PRODUCTION = 1, PURCHASE_GOLD = 2, PURCHASE_FAITH=3};
local EXTENDED_BUTTON_HEIGHT = 60;
local DEFAULT_BUTTON_HEIGHT = 48;
local DROP_OVERLAP_REQUIRED   :number = 0.5;
local PRODUCTION_TYPE :table = {
    BUILDING  = 1,
    UNIT    = 2,
    CORPS   = 3,
    ARMY    = 4,
    PLACED    = 5,
    PROJECT   = 6
};

--CQUI Members
local CQUI_INSTANCE_Y :number = 32;
local CQUI_ProductionQueue :boolean = true;
local CQUI_ShowProductionRecommendations :boolean = false;
function CQUI_OnSettingsUpdate()
  CQUI_INSTANCE_Y = GameConfiguration.GetValue("CQUI_ProductionItemHeight");
  CQUI_ProductionQueue = GameConfiguration.GetValue("CQUI_ProductionQueue");
  CQUI_ShowProductionRecommendations = GameConfiguration.GetValue("CQUI_ShowProductionRecommendations") == 1
  if(not CQUI_ProductionQueue) then
    ResetAllCityQueues();
    Controls.QueueAlphaIn:SetHide(true);
  else
    Controls.QueueAlphaIn:SetHide(false);
    Refresh();
  end
end
LuaEvents.CQUI_SettingsUpdate.Add(CQUI_OnSettingsUpdate);
LuaEvents.CQUI_SettingsInitialized.Add(CQUI_OnSettingsUpdate);

-- AZURENCY : BeliefModifiers indexed by their BeliefType
local CQUI_BeliefModifiers = {}
for mod in GameInfo.BeliefModifiers() do
  CQUI_BeliefModifiers[mod.BeliefType] = mod
end
-- AZURENCY : MutuallyExclusiveBuildings indexed by their Building Type
local CQUI_MutuallyExclusiveBuildings = {}
for meb in GameInfo.MutuallyExclusiveBuildings() do
  CQUI_MutuallyExclusiveBuildings[meb.Building] = meb
end

-- ===========================================================================
--  Members
-- ===========================================================================

local m_queueIM     = InstanceManager:new( "UnnestedList",  "Top", Controls.ProductionQueueList );
-- local CQUI_previousProductionHash :table = {};
-- local CQUI_currentProductionHash :table = {};

local m_listIM      = InstanceManager:new( "NestedList",  "Top", Controls.ProductionList );


local m_productionTab;  -- Additional tracking of the tab control data so that we can select between graphical tabs and label tabs
local m_purchaseTab;
local m_faithTab;
local m_maxProductionSize :number = 0;
local m_maxPurchaseSize   :number = 0;
local m_isQueueMode     :boolean = false;
local m_TypeNames     :table  = {};
local m_kClickedInstance;
local m_isCONTROLpressed  :boolean = false;
local prodBuildingList;
local prodWonderList;
local prodUnitList;
local prodDistrictList;
local prodProjectList;
local purchGoldDistrictList;
local purchFaithDistrictList;
local purchGoldBuildingList;
local purchFaithBuildingList;
local purchGoldUnitList;
local purchFaithUnitList;

local showDisabled :boolean = true;
local m_recommendedItems:table;

--local prodAlreadyStarting :boolean = false;

-- ====================CQUI Cityview==========================================

  function CQUI_OnCityviewEnabled()
    Open();
  end

  function CQUI_OnCityviewDisabled()
    Close();
  end

  LuaEvents.CQUI_ProductionPanel_CityviewEnable.Add( CQUI_OnCityviewEnabled);
  LuaEvents.CQUI_ProductionPanel_CityviewDisable.Add( CQUI_OnCityviewDisabled);
  Events.CityMadePurchase.Add( function() Refresh(); end)

-- ===========================================================================
function toint(n)
    local s = tostring(n)
    local i, j = s:find('%.')
    if i then
        return tonumber(s:sub(1, i-1))
    else
        return n
    end
end

-- Production Queue
local nextDistrictSkipToFront = false;
local showStandaloneQueueWindow = true;
local _, screenHeight = UIManager:GetScreenSizeVal();
local quickRefresh = true;
local m_kProductionQueueDropAreas = {}; -- Required by drag and drop system
local lastProductionCompletePerCity = {};
local mutuallyExclusiveBuildings = {};
hstructure DropAreaStruct -- Lua based struct (required copy from DragSupport)
  x   : number
  y   : number
  width : number
  height  : number
  control : table
  id    : number  -- (optional, extra info/ID)
end

------------------------------------------------------------------------------
-- Collapsible List Handling
------------------------------------------------------------------------------
function OnCollapseTheList()
  m_kClickedInstance.List:SetHide(true);
  m_kClickedInstance.ListSlide:SetSizeY(0);
  m_kClickedInstance.ListAlpha:SetSizeY(0);
  Controls.PauseCollapseList:SetToBeginning();
  m_kClickedInstance.ListSlide:SetToBeginning();
  m_kClickedInstance.ListAlpha:SetToBeginning();
  Controls.ProductionList:CalculateSize();
  Controls.ProductionList:ReprocessAnchoring();
  Controls.ProductionListScroll:CalculateInternalSize();
end

-- ===========================================================================
function OnCollapse(instance:table)
  m_kClickedInstance = instance;
  instance.ListSlide:Reverse();
  instance.ListAlpha:Reverse();
  instance.ListSlide:SetSpeed(15.0);
  instance.ListAlpha:SetSpeed(15.0);
  instance.ListSlide:Play();
  instance.ListAlpha:Play();
  instance.HeaderOn:SetHide(true);
  instance.Header:SetHide(false);
  Controls.PauseCollapseList:Play();  --By doing this we can delay collapsing the list until the "out" sequence has finished playing
end

-- ===========================================================================
function OnExpand(instance:table)
  if(quickRefresh) then
    instance.ListSlide:SetSpeed(100);
    instance.ListAlpha:SetSpeed(100);
  else
    instance.ListSlide:SetSpeed(3.5);
    instance.ListAlpha:SetSpeed(4);
  end

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
  Controls.ProductionList:CalculateSize();
  Controls.ProductionList:ReprocessAnchoring();
  Controls.ProductionListScroll:CalculateInternalSize();
  UI.SetInterfaceMode(InterfaceModeTypes.CITY_MANAGEMENT);
end

-- ===========================================================================
-- Placement/Selection
-- ===========================================================================
function BuildUnit(city, unitEntry)
  local tParameters = {};
  tParameters[CityOperationTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
  tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
  CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
    UI.PlaySound("Confirm_Production");
end

-- ===========================================================================
function BuildUnitCorps(city, unitEntry)
  local tParameters = {};
  tParameters[CityOperationTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
  tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
  tParameters[CityOperationTypes.MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.CORPS_MILITARY_FORMATION;
  CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
    UI.PlaySound("Confirm_Production");
end

-- ===========================================================================
function BuildUnitArmy(city, unitEntry)
  local tParameters = {};
  tParameters[CityOperationTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
  tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
  tParameters[CityOperationTypes.MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.ARMY_MILITARY_FORMATION;
  CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
  UI.PlaySound("Confirm_Production");
  Refresh();
end

-- ===========================================================================
function BuildBuilding(city, buildingEntry)
  local building      :table    = GameInfo.Buildings[buildingEntry.Hash];

  local bNeedsPlacement :boolean  = building.RequiresPlacement;

  local pBuildQueue = city:GetBuildQueue();
  if (pBuildQueue:HasBeenPlaced(buildingEntry.Hash)) then
    bNeedsPlacement = false;
  end


  if(not pBuildQueue:CanProduce(buildingEntry.Hash, true)) then
    -- For one reason or another we can't produce this, so remove it
    RemoveFromQueue(city, 1, true);
    BuildFirstQueued(city);
    return;
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
    --If we were already placing something, quickly pop into selection mode, signalling to CQUI cityview code that placement was interrupted and resetting the view
    if(UI.GetInterfaceMode() == InterfaceModeTypes.BUILDING_PLACEMENT or UI.GetInterfaceMode() == InterfaceModeTypes.DISTRICT_PLACEMENT) then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    else
      local tParameters = {};
      tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = buildingEntry.Hash;
      tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
      UI.SetInterfaceMode(InterfaceModeTypes.BUILDING_PLACEMENT, tParameters);
    end
  else
    local tParameters = {};
    tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = buildingEntry.Hash;
    tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
    CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
    UI.PlaySound("Confirm_Production");
  end
end

-- ===========================================================================
function ZoneDistrict(city, districtEntry)

  local district      :table    = GameInfo.Districts[districtEntry.Hash];
  local bNeedsPlacement :boolean  = district.RequiresPlacement;
  local pBuildQueue   :table    = city:GetBuildQueue();

  if (pBuildQueue:HasBeenPlaced(districtEntry.Hash)) then
    bNeedsPlacement = false;
  end

  -- Almost all districts need to be placed, but just in case let's check anyway
  if (bNeedsPlacement ) then
    if(UI.GetInterfaceMode() == InterfaceModeTypes.DISTRICT_PLACEMENT or UI.GetInterfaceMode() ==InterfaceModeTypes.BUILDING_PLACEMENT) then
      UI.SetInterfaceMode(InterfaceModeTypes.CITY_MANAGEMENT);
    else
      -- If so, set the placement mode
      local tParameters = {};
      tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Hash;
      tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
      UI.SetInterfaceMode(InterfaceModeTypes.DISTRICT_PLACEMENT, tParameters);
    end
  else
    -- If not, add it to the queue.
    local tParameters = {};
    tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Hash;
    tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
    CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
        UI.PlaySound("Confirm_Production");
  end
end

-- ===========================================================================
function AdvanceProject(city, projectEntry)
  local tParameters = {};
  tParameters[CityOperationTypes.PARAM_PROJECT_TYPE] = projectEntry.Hash;
  tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
  CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
  UI.PlaySound("Confirm_Production");
end

-- ===========================================================================
function PurchaseUnit(city, unitEntry, purchaseType)
  local tParameters = {};
  tParameters[CityCommandTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
  tParameters[CityCommandTypes.PARAM_MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.STANDARD_MILITARY_FORMATION;
  if (purchaseType == nil) then
    if (unitEntry.Yield == "YIELD_GOLD") then
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
    UI.PlaySound("Purchase_With_Gold");
    else
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index;
    UI.PlaySound("Purchase_With_Faith");
    end
  else
    tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = purchaseType;
  end
  CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters);
end

-- ===========================================================================
function PurchaseUnitCorps(city, unitEntry, purchaseType)
  local tParameters = {};
  tParameters[CityCommandTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
  tParameters[CityCommandTypes.PARAM_MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.CORPS_MILITARY_FORMATION;
  if (purchaseType == nil) then
    if (unitEntry.Yield == "YIELD_GOLD") then
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
    UI.PlaySound("Purchase_With_Gold");
    else
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index;
    UI.PlaySound("Purchase_With_Faith");
    end
  else
    tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = purchaseType;
  end
  CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters);
end

-- ===========================================================================
function PurchaseUnitArmy(city, unitEntry, purchaseType)
  local tParameters = {};
  tParameters[CityCommandTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
  tParameters[CityCommandTypes.PARAM_MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.ARMY_MILITARY_FORMATION;
  if (purchaseType == nil) then
    if (unitEntry.Yield == "YIELD_GOLD") then
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
    UI.PlaySound("Purchase_With_Gold");
    else
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index;
    UI.PlaySound("Purchase_With_Faith");
    end
  else
    tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = purchaseType;
  end
  CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters);
end

-- ===========================================================================
function PurchaseBuilding(city, buildingEntry, purchaseType)
  local tParameters = {};
  tParameters[CityCommandTypes.PARAM_BUILDING_TYPE] = buildingEntry.Hash;
  if(purchaseType == nil) then
    if (buildingEntry.Yield == "YIELD_GOLD") then
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
    UI.PlaySound("Purchase_With_Gold");
    else
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index;
    UI.PlaySound("Purchase_With_Faith");
    end
  else
    tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = purchaseType;
  end
  CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters);
end

-- ===========================================================================
function PurchaseDistrict(city, districtEntry)
  local district			:table		= GameInfo.Districts[districtEntry.Type];
  local bNeedsPlacement	:boolean	= district.RequiresPlacement;
  local pBuildQueue		:table		= city:GetBuildQueue();

  if (pBuildQueue:HasBeenPlaced(districtEntry.Hash)) then
    bNeedsPlacement = false;
  end

  -- Almost all districts need to be placed, but just in case let's check anyway
  if (bNeedsPlacement ) then			
    -- If so, set the placement mode
    local tParameters = {}; 
    tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Hash;
    tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
    UI.SetInterfaceMode(InterfaceModeTypes.DISTRICT_PLACEMENT, tParameters);
  else
    -- If not, add it to the queue.
    local tParameters = {}; 
    tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Hash;
    tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;  
    CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters);
    UI.PlaySound("Purchase_With_Gold");
  end
end

-- ===========================================================================
--  GAME Event
--  City was selected.
-- ===========================================================================
function OnCitySelectionChanged( owner:number, cityID:number, i, j, k, isSelected:boolean, isEditable:boolean)
  local localPlayerId:number = Game.GetLocalPlayer();
  if owner == localPlayerId and isSelected then
    -- Already open then populate with newly selected city's data...
    if (ContextPtr:IsHidden() == false) and Controls.PauseDismissWindow:IsStopped() and Controls.AlphaIn:IsStopped() then
    Refresh();
    end
  end
end

-- ===========================================================================
--  GAME Event
--  eOldMode, mode the engine was formally in
--  eNewMode, new mode the engine has just changed to
-- ===========================================================================
function OnInterfaceModeChanged( eOldMode:number, eNewMode:number )
end

-- ===========================================================================
--  GAME Event
--  Unit was selected (impossible for a production panel to be up; close it
-- ===========================================================================
function OnUnitSelectionChanged( playerID : number, unitID : number, hexI : number, hexJ : number, hexK : number, bSelected : boolean, bEditable : boolean )
  local localPlayer = Game.GetLocalPlayer();
  if playerID == localPlayer then
    -- If a unit is selected and this is showing; hide it.
    local pSelectedUnit:table = UI.GetHeadSelectedUnit();
    if pSelectedUnit ~= nil and not ContextPtr:IsHidden() then
      OnHide();
    end
  end
end

-- ===========================================================================
--  Actual closing function, may have been called via click, keyboard input,
--  or an external system call.
-- ===========================================================================
function Close()
  if (not Controls.SlideIn:IsReversing()) then      -- Need to check to make sure that we have not already begun the transition before attempting to close the panel.
    UI.PlaySound("Production_Panel_Closed");
    Controls.SlideIn:Reverse();
    Controls.AlphaIn:Reverse();

    if(showStandaloneQueueWindow) then
      Controls.QueueSlideIn:Reverse();
      Controls.QueueAlphaIn:Reverse();
    else
      Controls.QueueAlphaIn:SetAlpha(0);
    end

    Controls.PauseDismissWindow:Play();
    LuaEvents.ProductionPanel_Close();
  end
end

-- ===========================================================================
--  Close via click
function OnClose()
  LuaEvents.CQUI_CityPanel_CityviewDisable();
end

-- ===========================================================================
--  Open the panel
-- ===========================================================================
function Open()
  if ContextPtr:IsHidden() or Controls.SlideIn:IsReversing() then         -- The ContextPtr is only hidden as a callback to the finished SlideIn animation, so this check should be sufficient to ensure that we are not animating.
    -- Sets up proper selection AND the associated lens so it's not stuck "on".
    UI.PlaySound("Production_Panel_Open");
    Controls.PauseDismissWindow:SetToBeginning() -- AZURENCY : fix the callback that hide the pannel to be called during the Openning animation
    LuaEvents.ProductionPanel_Open();
    Refresh();
    ContextPtr:SetHide(false);
    Controls.ProductionListScroll:SetScrollValue(0);

    -- Size the panel to the maximum Y value of the expanded content
    Controls.AlphaIn:SetToBeginning();
    Controls.SlideIn:SetToBeginning();
    Controls.AlphaIn:Play();
    Controls.SlideIn:Play();

    if(showStandaloneQueueWindow) then
      Controls.QueueAlphaIn:SetToBeginning();
      Controls.QueueSlideIn:SetToBeginning();
      Controls.QueueAlphaIn:Play();
      Controls.QueueSlideIn:Play();
      ResizeQueueWindow();
    end
  end
end

-- ===========================================================================
function OnHide()
  ContextPtr:SetHide(true);
  Controls.PauseDismissWindow:SetToBeginning();
end


-- ===========================================================================
--  Initialize, Refresh, Populate, View
--  Update the layout based on the view model
-- ===========================================================================
function View(data)
  local selectedCity  = UI.GetHeadSelectedCity();
  -- Get the hashes for the top three recommended items
  m_recommendedItems = selectedCity:GetCityAI():GetBuildRecommendations();

  -- TODO there is a ton of duplicated code between producing, buying with gold, and buying with faith
  -- there is also a ton of duplicated code between districts, buildings, units, wonders, etc
  -- I think this could be a prime candidate for a refactor if there is time, currently, care must
  -- be taken to copy any changes in several places to keep it functioning consistently
  
  -- These need to be cleared out before the PopulateLists() calls
  prodBuildingList       = nil;
  prodWonderList         = nil;
  prodUnitList           = nil;
  prodDistrictList       = nil;
  prodProjectList        = nil;
  purchGoldDistrictList  = nil;
  purchFaithDistrictList = nil;
  purchGoldBuildingList  = nil;
  purchFaithBuildingList = nil;
  purchGoldUnitList      = nil;
  purchFaithUnitList     = nil;
  
  PopulateList(data, m_listIM);

  if( prodDistrictList ~= nil) then
    OnExpand(prodDistrictList);
  end
  if( prodWonderList ~= nil) then
    OnExpand(prodWonderList);
  end
  if(prodUnitList ~= nil) then
    OnExpand(prodUnitList);
  end
  if(prodProjectList ~= nil) then
    OnExpand(prodProjectList);
  end
  if( purchFaithBuildingList ~= nil) then
    OnExpand(purchFaithBuildingList);
  end
  if( purchGoldBuildingList ~= nil) then
    OnExpand(purchGoldBuildingList);
  end
  if( purchFaithUnitList ~= nil ) then
    OnExpand(purchFaithUnitList);
  end
  if( purchGoldUnitList ~= nil) then
    OnExpand(purchGoldUnitList);
  end
  if (purchGoldDistrictList ~= nil) then
    OnExpand(purchGoldDistrictList);
  end
  if (purchFaithDistrictList ~= nil) then
    OnExpand(purchFaithDistrictList);
  end
end

function ResetInstanceVisibility(productionItem: table)
  if (productionItem.ArmyCorpsDrawer ~= nil) then
    productionItem.ArmyCorpsDrawer:SetHide(true);
    productionItem.CorpsArmyArrow:SetSelected(true);
    productionItem.CorpsRecommendedIcon:SetHide(true);
    productionItem.CorpsButtonContainer:SetHide(true);
    productionItem.CorpsDisabled:SetHide(true);
    productionItem.ArmyRecommendedIcon:SetHide(true);
    productionItem.ArmyButtonContainer:SetHide(true);
    productionItem.ArmyDisabled:SetHide(true);
  end
  if (productionItem.BuildingDrawer ~= nil) then
    productionItem.BuildingDrawer:SetHide(true);
    productionItem.CompletedArea:SetHide(true);
  end
  productionItem.RecommendedIcon:SetHide(true);
  productionItem.Disabled:SetHide(true);
end
-- ===========================================================================

--CQUI modified function, puts everything in 1 unified list instead of 3
function PopulateList(data, listIM)
  listIM:ResetInstances();
  local districtList;
  local buildingList;
  local wonderList;
  local projectList;
  local unitList;
  local queueList;
  Controls.PauseCollapseList:Stop();
  local selectedCity  = UI.GetHeadSelectedCity();
  local pBuildings = selectedCity:GetBuildings();
  local cityID = selectedCity:GetID();
  local productionQueueTableKey = FindProductionQueueKey(cityID, selectedCity:GetOwner())
  local cityData = GetCityData(selectedCity);
  local localPlayer = Players[Game.GetLocalPlayer()];
  local CQUI_ProdTable = {}; --Keeps track of each producable item. Key is the item hash, Value is a table with three keys (time/gold/faith) representing the respective costs
  local CQUI_PlayerGold = Players[Game.GetLocalPlayer()]:GetTreasury():GetGoldBalance();
  local CQUI_PlayerFaith = Players[Game.GetLocalPlayer()]:GetReligion():GetFaithBalance();

  -- Populate Units ------------------------
  unitList = listIM:GetInstance();
  unitList.Header:SetText(Locale.ToUpper(Locale.Lookup("LOC_TECH_FILTER_UNITS")));
  unitList.HeaderOn:SetText(Locale.ToUpper(Locale.Lookup("LOC_TECH_FILTER_UNITS")));
  local uL = unitList;
  if ( unitList.unitListIM ~= nil ) then
    unitList.unitListIM:ResetInstances();
  else
    unitList.unitListIM = InstanceManager:new( "UnitListInstance", "Root", unitList.List);
  end
  if ( unitList.civilianListIM ~= nil ) then
    unitList.civilianListIM:ResetInstances();
  else
    unitList.civilianListIM = InstanceManager:new( "CivilianListInstance",  "Root", unitList.List);
  end

  local unitData = data.UnitItems;
  local unitPurchaseData = data.UnitPurchases;

  for i, item in ipairs(unitPurchaseData) do
    if(CQUI_ProdTable[item.Hash] == nil) then
      CQUI_ProdTable[item.Hash] = {};
    end
    if (item.Yield == "YIELD_GOLD") then
      CQUI_ProdTable[item.Hash]["gold"] = item.Cost;
      if(item.Corps) then
        CQUI_ProdTable[item.Hash]["corpsGold"] = item.CorpsCost;
      end
      if(item.Army) then
        CQUI_ProdTable[item.Hash]["armyGold"] = item.ArmyCost;
      end
    else
      CQUI_ProdTable[item.Hash]["faith"] = item.Cost;
      if(item.Corps) then
        CQUI_ProdTable[item.Hash]["corpsFaith"] = item.CorpsCost;
      end
      if(item.Army) then
        CQUI_ProdTable[item.Hash]["armyFaith"] = item.ArmyCost;
      end
    end
  end
  for i, item in ipairs(unitData) do
      if(CQUI_ProdTable[item.Hash] == nil) then
        CQUI_ProdTable[item.Hash] = {};
      end
      CQUI_ProdTable[item.Hash]["time"] = item.TurnsLeft;
      local unitListing;
      if (item.Civilian) then
        unitListing = unitList["civilianListIM"]:GetInstance();
      else
        unitListing = unitList["unitListIM"]:GetInstance();
      end
      ResetInstanceVisibility(unitListing);
      unitListing.ButtonContainer:SetSizeY(CQUI_INSTANCE_Y);
      -- Check to see if this item is recommended
      if CQUI_ShowProductionRecommendations then
        for _,hash in ipairs( m_recommendedItems) do
          if(item.Hash == hash.BuildItemHash) then
            unitListing.RecommendedIcon:SetHide(false);
          end
        end
      end

      local costStr = "";
      local costStrTT = "";

      -- ProductionQueue: We need to check that there isn't already one of these in the queue
      if(prodQueue[productionQueueTableKey][1] and prodQueue[productionQueueTableKey][1].entry.Hash == item.Hash) then
          item.TurnsLeft = math.ceil(item.Cost / cityData.ProductionPerTurn);
          item.Progress = 0;
      end

      -- Production meter progress for parent unit
      if(item.Progress > 0) then
        unitListing.ProductionProgressArea:SetHide(false);
        local unitProgress = item.Progress/item.Cost;
        if (unitProgress < 1) then
          unitListing.ProductionProgress:SetPercent(unitProgress);
        else
          unitListing.ProductionProgressArea:SetHide(true);
        end
      else
        unitListing.ProductionProgressArea:SetHide(true);
      end
      local numberOfTurns = item.TurnsLeft;
      if numberOfTurns == -1 then
        numberOfTurns = "999+";
        costStrTT = Locale.Lookup("LOC_HUD_CITY_WILL_NOT_COMPLETE");
      else
        costStrTT = numberOfTurns .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", item.TurnsLeft);
      end
      costStr = numberOfTurns .. "[ICON_Turn]";

      -- PQ: Check if we already have max spies including queued
      if(item.Hash == GameInfo.Units["UNIT_SPY"].Hash) then
        local localDiplomacy = localPlayer:GetDiplomacy();
        local spyCap = localDiplomacy:GetSpyCapacity();
        local numberOfSpies = 0;

        -- Count our spies
        local localPlayerUnits:table = localPlayer:GetUnits();
        for i, unit in localPlayerUnits:Members() do
          local unitInfo:table = GameInfo.Units[unit:GetUnitType()];
          if unitInfo.Spy then
            numberOfSpies = numberOfSpies + 1;
          end
        end

        -- Loop through all players to see if they have any of our captured spies
        local players:table = Game.GetPlayers();
        for i, player in ipairs(players) do
          local playerDiplomacy:table = player:GetDiplomacy();
          local numCapturedSpies:number = playerDiplomacy:GetNumSpiesCaptured();
          for i=0,numCapturedSpies-1,1 do
            local spyInfo:table = playerDiplomacy:GetNthCapturedSpy(player:GetID(), i);
            if spyInfo and spyInfo.OwningPlayer == Game.GetLocalPlayer() then
              numberOfSpies = numberOfSpies + 1;
            end
          end
        end

        -- Count travelling spies
        if localDiplomacy then
          local numSpiesOffMap:number = localDiplomacy:GetNumSpiesOffMap();
          for i=0,numSpiesOffMap-1,1 do
            local spyOffMapInfo:table = localDiplomacy:GetNthOffMapSpy(Game.GetLocalPlayer(), i);
            if spyOffMapInfo and spyOffMapInfo.ReturnTurn ~= -1 then
              numberOfSpies = numberOfSpies + 1;
            end
          end
        end

          if(spyCap > numberOfSpies) then
            for _,city in pairs(prodQueue) do
            for _,qi in pairs(city) do
              if(qi.entry.Hash == item.Hash) then
                numberOfSpies = numberOfSpies + 1;
              end
            end
          end
          if(numberOfSpies >= spyCap) then
            item.Disabled = true;
            -- No existing localization string for "Need more spy slots" so we'll just gray it out
            -- item.ToolTip = item.ToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup("???");
          end
          end
      end

      -- PQ: Check if we already have max traders queued
      if(item.Hash == GameInfo.Units["UNIT_TRADER"].Hash) then
        local playerTrade :table  = localPlayer:GetTrade();
        local routesActive  :number = playerTrade:GetNumOutgoingRoutes();
        local routesCapacity:number = playerTrade:GetOutgoingRouteCapacity();
        local routesQueued  :number = 0;

        if(routesCapacity >= routesActive) then
          for _,city in pairs(prodQueue) do
            for _,qi in pairs(city) do
              if(qi.entry.Hash == item.Hash) then
                routesQueued = routesQueued + 1;
              end
            end
          end
          if(routesActive + routesQueued >= routesCapacity) then
            item.Disabled = true;
            if(not string.find(item.ToolTip, "[COLOR:Red]")) then
              item.ToolTip = item.ToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup("LOC_UNIT_TRAIN_FULL_TRADE_ROUTE_CAPACITY");
            end
          end
        end
      end

      local nameStr = Locale.Lookup("{1_Name}", item.Name);
      unitListing.LabelText:SetText(nameStr);
      unitListing.CostText:SetText(costStr);
      if(costStrTT ~= "") then
        unitListing.CostText:SetToolTipString(costStrTT);
      end
      unitListing.TrainUnit:SetToolTipString(item.ToolTip);
      unitListing.Disabled:SetToolTipString(item.ToolTip);

      -- Show/hide religion indicator icon
      if unitListing.ReligionIcon then
        local showReligionIcon:boolean = false;

        if item.ReligiousStrength and item.ReligiousStrength > 0 then
          if unitListing.ReligionIcon then
            local religionType = data.City:GetReligion():GetMajorityReligion();
            if religionType > 0 then
              local religion:table = GameInfo.Religions[religionType];
              local religionIcon:string = "ICON_" .. religion.ReligionType;
              local religionColor:number = UI.GetColorValue(religion.Color);
              local religionName:string = Game.GetReligion():GetName(religion.Index);

              unitListing.ReligionIcon:SetIcon(religionIcon);
              unitListing.ReligionIcon:SetColor(religionColor);
              unitListing.ReligionIcon:LocalizeAndSetToolTip(religionName);
              unitListing.ReligionIcon:SetHide(false);
              showReligionIcon = true;
            end
          end
        end

        unitListing.ReligionIcon:SetHide(not showReligionIcon);
      end

      -- Set Icon color and backing
      local textureName = TEXTURE_BASE;
      if item.Type ~= -1 then
        if (GameInfo.Units[item.Type].Combat ~= 0 or GameInfo.Units[item.Type].RangedCombat ~= 0) then    -- Need a simpler what to test if the unit is a combat unit or not.
          if "DOMAIN_SEA" == GameInfo.Units[item.Type].Domain then
            textureName = TEXTURE_NAVAL;
          else
            textureName =  TEXTURE_BASE;
          end
        else
          if GameInfo.Units[item.Type].MakeTradeRoute then
            textureName = TEXTURE_TRADE;
          elseif "FORMATION_CLASS_SUPPORT" == GameInfo.Units[item.Type].FormationClass then
            textureName = TEXTURE_SUPPORT;
          elseif item.ReligiousStrength > 0 then
            textureName = TEXTURE_RELIGION;
          else
            textureName = TEXTURE_CIVILIAN;
          end
        end
      end

      -- Set colors and icons for the flag instance
      unitListing.Icon:SetColor( "0xFFFFFFFF" );
      unitListing.Icon:SetIcon(ICON_PREFIX..item.Type);

      unitListing.TrainUnit:RegisterCallback( Mouse.eLClick, function()
        QueueUnit(data.City, item, (m_isCONTROLpressed or not CQUI_ProductionQueue));
      end);

      unitListing.TrainUnit:RegisterCallback( Mouse.eMClick, function()
          QueueUnit(data.City, item, true);
          RecenterCameraToSelectedCity();
      end);

      --CQUI Productionpanel buy buttons
      unitListing.PurchaseButton:RegisterCallback( Mouse.eLClick, function()
        -- Check if city can spawn unit
        if data.City:GetGold():CanPlaceUnit(item.Hash) then
          PurchaseUnit(data.City, item, GameInfo.Yields["YIELD_GOLD"].Index);
        else
          unitListing.TrainUnit:SetToolTipString(Locale.Lookup("LOC_BUILDING_CONSTRUCT_NO_SUITABLE_LOCATION"));
        end
        end);
      if CQUI_ProdTable[item.Hash]["gold"] ~= nil then
        unitListing.PurchaseButton:SetText(CQUI_ProdTable[item.Hash]["gold"] .. "[ICON_GOLD]");
        unitListing.PurchaseButton:SetHide(false);
        unitListing.PurchaseButton:SetDisabled(CQUI_PlayerGold < CQUI_ProdTable[item.Hash]["gold"]);
        if (CQUI_PlayerGold < CQUI_ProdTable[item.Hash]["gold"] or not data.City:GetGold():CanPlaceUnit(item.Hash)) then
          unitListing.PurchaseButton:SetColor(0xDD3366FF);
        else
          unitListing.PurchaseButton:SetColor(0xFFF38FFF);
        end
      else
        unitListing.PurchaseButton:SetHide(true);
      end
      unitListing.FaithPurchaseButton:RegisterCallback( Mouse.eLClick, function()
        if data.City:GetGold():CanPlaceUnit(item.Hash) then
          PurchaseUnit(data.City, item, GameInfo.Yields["YIELD_FAITH"].Index);
        else
          unitListing.TrainUnit:SetToolTipString(Locale.Lookup("LOC_BUILDING_CONSTRUCT_NO_SUITABLE_LOCATION"));
        end
      end);
      if CQUI_ProdTable[item.Hash]["faith"] ~= nil then
        unitListing.FaithPurchaseButton:SetText(CQUI_ProdTable[item.Hash]["faith"] .. "[ICON_FAITH]");
        unitListing.FaithPurchaseButton:SetHide(false);
        unitListing.FaithPurchaseButton:SetDisabled(CQUI_PlayerFaith < CQUI_ProdTable[item.Hash]["faith"]);
        if (CQUI_PlayerFaith < CQUI_ProdTable[item.Hash]["faith"] or not data.City:GetGold():CanPlaceUnit(item.Hash)) then
          unitListing.FaithPurchaseButton:SetColor(0xDD3366FF);
        else
          unitListing.FaithPurchaseButton:SetColor(0xFFF38FFF);
        end
      else
        unitListing.FaithPurchaseButton:SetHide(true);
      end
      unitListing.TrainUnit:RegisterCallback( Mouse.eMouseEnter,  function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
      unitListing.TrainUnit:RegisterCallback( Mouse.eRClick, function()
        LuaEvents.OpenCivilopedia(item.Type);
      end);
      unitListing.TrainUnit:SetTag(UITutorialManager:GetHash(item.Type));

      -- Change ToolTip back to item description
      unitListing.PurchaseButton:RegisterCallback( Mouse.eMouseExit, function() unitListing.TrainUnit:SetToolTipString(item.ToolTip); end);
      unitListing.FaithPurchaseButton:RegisterCallback( Mouse.eMouseExit, function() unitListing.TrainUnit:SetToolTipString(item.ToolTip); end);

      -- Controls for training unit corps and armies.
      -- Want a special text string for this!! #NEW TEXT #LOCALIZATION - "You can only directly build corps and armies once you have constructed a military academy."
      -- LOC_UNIT_TRAIN_NEED_MILITARY_ACADEMY
      if item.Corps or item.Army then
        unitListing.ArmyCorpsDrawer:SetOffsetY(CQUI_INSTANCE_Y - 2);
        unitListing.CorpsButtonContainer:SetSizeY(CQUI_INSTANCE_Y);
        unitListing.CorpsPurchaseButton:SetSizeY(CQUI_INSTANCE_Y - 9);
        unitListing.CorpsFaithPurchaseButton:SetSizeY(CQUI_INSTANCE_Y - 9);
        unitListing.ArmyButtonContainer:SetSizeY(CQUI_INSTANCE_Y);
        unitListing.ArmyPurchaseButton:SetSizeY(CQUI_INSTANCE_Y - 9);
        unitListing.ArmyFaithPurchaseButton:SetSizeY(CQUI_INSTANCE_Y - 9);
        unitListing.CorpsArmyDropdownButton:RegisterCallback( Mouse.eLClick, function()
          local isExpanded = unitListing.CorpsArmyArrow:IsSelected();
          unitListing.CorpsArmyArrow:SetSelected(not isExpanded);
          unitListing.ArmyCorpsDrawer:SetHide(not isExpanded);
          unitList.List:CalculateSize();
          unitList.List:ReprocessAnchoring();
          unitList.Top:CalculateSize();
          unitList.Top:ReprocessAnchoring();
          Controls.ProductionList:CalculateSize();
          Controls.ProductionListScroll:CalculateSize();
        end);
        unitListing.CorpsArmyDropdownButton:SetHide(false);
      elseif (not item.Civilian) then
        unitListing.CorpsArmyDropdownButton:SetHide(true);
      end

      if item.Corps then
        -- Check to see if this item is recommended
        if CQUI_ShowProductionRecommendations then
          for _,hash in ipairs( m_recommendedItems) do
            if(item.Hash == hash.BuildItemHash) then
              unitListing.CorpsRecommendedIcon:SetHide(false);
            end
          end
        end
        unitListing.CorpsButtonContainer:SetHide(false);
        -- Production meter progress for corps unit

        -- ProductionQueue: We need to check that there isn't already one of these in the queue
        if(IsHashInQueue(selectedCity, item.Hash)) then
          item.CorpsTurnsLeft = math.ceil(item.CorpsCost / cityData.ProductionPerTurn);
          item.Progress = 0;
        end

        if(item.Progress > 0) then
          unitListing.ProductionCorpsProgressArea:SetHide(false);
          local unitProgress = item.Progress/item.CorpsCost;
          if (unitProgress < 1) then
            unitListing.ProductionCorpsProgress:SetPercent(unitProgress);
          else
            unitListing.ProductionCorpsProgressArea:SetHide(true);
          end
        else
          unitListing.ProductionCorpsProgressArea:SetHide(true);
        end
        local turnsStr = item.CorpsTurnsLeft .. "[ICON_Turn]";
        local turnsStrTT = item.CorpsTurnsLeft .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", item.CorpsTurnsLeft);
        unitListing.CorpsCostText:SetText(turnsStr);
        unitListing.CorpsCostText:SetToolTipString(turnsStrTT);
        --CQUI Button binds
        if(CQUI_ProdTable[item.Hash]["corpsGold"] ~= nil) then
          unitListing.CorpsPurchaseButton:SetText(CQUI_ProdTable[item.Hash]["corpsGold"] .. "[ICON_GOLD]");
          unitListing.CorpsPurchaseButton:SetHide(false);
          unitListing.CorpsPurchaseButton:SetDisabled(CQUI_PlayerGold < CQUI_ProdTable[item.Hash]["corpsGold"]);
          if (CQUI_PlayerGold < CQUI_ProdTable[item.Hash]["corpsGold"] or not data.City:GetGold():CanPlaceUnit(item.Hash)) then
            unitListing.CorpsPurchaseButton:SetColor(0xDD3366FF);
          else
            unitListing.CorpsPurchaseButton:SetColor(0xFFF38FFF);
          end
        else
          unitListing.CorpsPurchaseButton:SetHide(true);
        end
        if(CQUI_ProdTable[item.Hash]["corpsFaith"] ~= nil) then
          unitListing.CorpsFaithPurchaseButton:SetText(CQUI_ProdTable[item.Hash]["corpsFaith"] .. "[ICON_FAITH]");
          unitListing.CorpsFaithPurchaseButton:SetHide(false);
          unitListing.CorpsFaithPurchaseButton:SetDisabled(CQUI_PlayerFaith < CQUI_ProdTable[item.Hash]["corpsFaith"]);
          if (CQUI_PlayerFaith < CQUI_ProdTable[item.Hash]["corpsFaith"] or not data.City:GetGold():CanPlaceUnit(item.Hash)) then
            unitListing.CorpsFaithPurchaseButton:SetColor(0xDD3366FF);
          else
            unitListing.CorpsFaithPurchaseButton:SetColor(0xFFF38FFF);
          end
        else
          unitListing.CorpsFaithPurchaseButton:SetHide(true);
        end

        unitListing.CorpsLabelIcon:SetText(item.CorpsName);
        unitListing.TrainCorpsButton:SetToolTipString(item.CorpsTooltip);
        unitListing.CorpsDisabled:SetToolTipString(item.CorpsTooltip);
        unitListing.TrainCorpsButton:RegisterCallback( Mouse.eLClick, function()
          QueueUnitCorps(data.City, item, not CQUI_ProductionQueue);
        end);

        unitListing.TrainCorpsButton:RegisterCallback( Mouse.eMClick, function()
          QueueUnitCorps(data.City, item, true);
          RecenterCameraToSelectedCity();
        end);

        unitListing.CorpsPurchaseButton:RegisterCallback( Mouse.eLClick, function()
          if data.City:GetGold():CanPlaceUnit(item.Hash) then
            PurchaseUnitCorps(data.City, item, GameInfo.Yields["YIELD_GOLD"].Index);
          else
            unitListing.TrainUnit:SetToolTipString(Locale.Lookup("LOC_BUILDING_CONSTRUCT_NO_SUITABLE_LOCATION"));
          end
        end);
        unitListing.CorpsFaithPurchaseButton:RegisterCallback( Mouse.eLClick, function()
          if data.City:GetGold():CanPlaceUnit(item.Hash) then
            PurchaseUnitCorps(data.City, item, GameInfo.Yields["YIELD_FAITH"].Index);
          else
            unitListing.TrainUnit:SetToolTipString(Locale.Lookup("LOC_BUILDING_CONSTRUCT_NO_SUITABLE_LOCATION"));
          end
        end);

        unitListing.CorpsPurchaseButton:RegisterCallback( Mouse.eMouseExit, function() unitListing.TrainUnit:SetToolTipString(item.ToolTip); end);
        unitListing.CorpsFaithPurchaseButton:RegisterCallback( Mouse.eMouseExit, function() unitListing.TrainUnit:SetToolTipString(item.ToolTip); end);
      end
      if item.Army then
        -- Check to see if this item is recommended
        if CQUI_ShowProductionRecommendations then
          for _,hash in ipairs( m_recommendedItems) do
            if(item.Hash == hash.BuildItemHash) then
              unitListing.ArmyRecommendedIcon:SetHide(false);
            end
          end
        end
        unitListing.ArmyButtonContainer:SetHide(false);

        -- ProductionQueue: We need to check that there isn't already one of these in the queue
        if(IsHashInQueue(selectedCity, item.Hash)) then
          item.ArmyTurnsLeft = math.ceil(item.ArmyCost / cityData.ProductionPerTurn);
          item.Progress = 0;
        end

        if(item.Progress > 0) then
          unitListing.ProductionArmyProgressArea:SetHide(false);
          local unitProgress = item.Progress/item.ArmyCost;
          unitListing.ProductionArmyProgress:SetPercent(unitProgress);
          if (unitProgress < 1) then
            unitListing.ProductionArmyProgress:SetPercent(unitProgress);
          else
            unitListing.ProductionArmyProgressArea:SetHide(true);
          end
        else
          unitListing.ProductionArmyProgressArea:SetHide(true);
        end
        local turnsStrTT:string = "";
        local turnsStr:string = "";
        local numberOfTurns = item.ArmyTurnsLeft;
        if numberOfTurns == -1 then
          numberOfTurns = "999+";
          turnsStrTT = Locale.Lookup("LOC_HUD_CITY_WILL_NOT_COMPLETE");
        else
          turnsStrTT = numberOfTurns .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", item.ArmyTurnsLeft);
        end
        turnsStr = numberOfTurns .. "[ICON_Turn]";
        unitListing.ArmyCostText:SetText(turnsStr);
        unitListing.ArmyCostText:SetToolTipString(turnsStrTT);
        --CQUI Button binds
        if(CQUI_ProdTable[item.Hash]["armyGold"] ~= nil) then
          unitListing.ArmyPurchaseButton:SetText(CQUI_ProdTable[item.Hash]["armyGold"] .. "[ICON_GOLD]");
          unitListing.ArmyPurchaseButton:SetHide(false);
          unitListing.ArmyPurchaseButton:SetDisabled(CQUI_PlayerGold < CQUI_ProdTable[item.Hash]["armyGold"]);
          if (CQUI_PlayerGold < CQUI_ProdTable[item.Hash]["armyGold"] or not data.City:GetGold():CanPlaceUnit(item.Hash)) then
            unitListing.ArmyPurchaseButton:SetColor(0xDD3366FF);
          else
            unitListing.ArmyPurchaseButton:SetColor(0xFFF38FFF);
          end
        else
          unitListing.ArmyPurchaseButton:SetHide(true);
        end
        if(CQUI_ProdTable[item.Hash]["armyFaith"] ~= nil) then
          unitListing.ArmyFaithPurchaseButton:SetText(CQUI_ProdTable[item.Hash]["armyFaith"] .. "[ICON_FAITH]");
          unitListing.ArmyFaithPurchaseButton:SetHide(false);
          unitListing.ArmyFaithPurchaseButton:SetDisabled(CQUI_PlayerFaith < CQUI_ProdTable[item.Hash]["armyFaith"]);
          if (CQUI_PlayerFaith < CQUI_ProdTable[item.Hash]["armyFaith"] or not data.City:GetGold():CanPlaceUnit(item.Hash)) then
            unitListing.ArmyFaithPurchaseButton:SetColor(0xDD3366FF);
          else
            unitListing.ArmyFaithPurchaseButton:SetColor(0xFFF38FFF);
          end
        else
          unitListing.ArmyFaithPurchaseButton:SetHide(true);
        end

        unitListing.ArmyLabelIcon:SetText(item.ArmyName);
        unitListing.TrainArmyButton:SetToolTipString(item.ArmyTooltip);
        unitListing.ArmyDisabled:SetToolTipString(item.ArmyTooltip);
        unitListing.TrainArmyButton:RegisterCallback( Mouse.eLClick, function()
          QueueUnitArmy(data.City, item, not CQUI_ProductionQueue);
        end);

        unitListing.TrainArmyButton:RegisterCallback( Mouse.eMClick, function()
          QueueUnitArmy(data.City, item, true);
          RecenterCameraToSelectedCity();
        end);

        unitListing.ArmyPurchaseButton:RegisterCallback( Mouse.eLClick, function()
          if data.City:GetGold():CanPlaceUnit(item.Hash) then
            PurchaseUnitArmy(data.City, item, GameInfo.Yields["YIELD_GOLD"].Index);
          else
            unitListing.TrainUnit:SetToolTipString(Locale.Lookup("LOC_BUILDING_CONSTRUCT_NO_SUITABLE_LOCATION"));
          end
        end);

        unitListing.ArmyFaithPurchaseButton:RegisterCallback( Mouse.eLClick, function()
          if data.City:GetGold():CanPlaceUnit(item.Hash) then
            PurchaseUnitArmy(data.City, item, GameInfo.Yields["YIELD_FAITH"].Index);
          else
            unitListing.TrainUnit:SetToolTipString(Locale.Lookup("LOC_BUILDING_CONSTRUCT_NO_SUITABLE_LOCATION"));
          end
        end);

        unitListing.ArmyPurchaseButton:RegisterCallback( Mouse.eMouseExit, function() unitListing.TrainUnit:SetToolTipString(item.ToolTip); end);
        unitListing.ArmyFaithPurchaseButton:RegisterCallback( Mouse.eMouseExit, function() unitListing.TrainUnit:SetToolTipString(item.ToolTip); end);
      end

      -- Handle if the item is disabled
      if (item.Disabled) then
        if(showDisabled) then
          unitListing.Disabled:SetHide(false);
          unitListing.PurchaseButton:SetHide(true);
          unitListing.FaithPurchaseButton:SetHide(true);
          unitListing.TrainUnit:SetColor(COLOR_LOW_OPACITY);
        else
          unitListing.TrainUnit:SetHide(true);
        end
      else
        unitListing.TrainUnit:SetHide(false);
        unitListing.Disabled:SetHide(true);
        unitListing.TrainUnit:SetColor(0xffffffff);
      end
      unitListing.TrainUnit:SetDisabled(item.Disabled or item.MustPurchase);
  end
  -- end iteration through units
  unitList.List:CalculateSize();
  unitList.List:ReprocessAnchoring();
  if (unitList.List:GetSizeY()==0) then
    unitList.Top:SetHide(true);
  else
    m_maxProductionSize = m_maxProductionSize + HEADER_Y + SEPARATOR_Y;
    unitList.Header:RegisterCallback( Mouse.eLClick, function()
      OnExpand(uL);
      end);
    unitList.HeaderOn:RegisterCallback( Mouse.eLClick, function()
      OnCollapse(uL);
      end);
  end

  prodUnitList = uL;

    -- Populate Current Item
    local buildQueue  = selectedCity:GetBuildQueue();
    local productionHash = 0;
    local completedStr = "";
    local currentProductionHash = buildQueue:GetCurrentProductionTypeHash();
    local previousProductionHash = buildQueue:GetPreviousProductionTypeHash();

    -- if CQUI_previousProductionHash[selectedCity:GetID()] ~= nil then
      -- previousProductionHash = CQUI_previousProductionHash[selectedCity:GetID()];
    -- end

    local screenX, screenY:number = UIManager:GetScreenSizeVal();

    if( currentProductionHash == 0 and previousProductionHash == 0 ) then
      Controls.CurrentProductionArea:SetHide(true);
      Controls.ProductionListScroll:CalculateSize();
      completedStr = "";
    else
      Controls.CurrentProductionArea:SetHide(false);
      Controls.ProductionListScroll:CalculateSize();
      if( currentProductionHash == 0 ) then
        productionHash = previousProductionHash;
        completedStr = " " .. Locale.ToUpper(Locale.Lookup("LOC_TECH_KEY_COMPLETED"));
        Controls.CurrentProductionMeter:SetHide(true);
        Controls.CurrentProductionCost:SetHide(true);
        Controls.CurrentProductionName:SetOffsetVal(0,0);
        Controls.CurrentProductionName:SetWrapWidth(300);
      else
        productionHash = currentProductionHash;
        completedStr = ""
        Controls.CurrentProductionMeter:SetHide(false);
        Controls.CurrentProductionCost:SetHide(false);
        Controls.CurrentProductionName:SetOffsetVal(-58,0);
        Controls.CurrentProductionName:SetWrapWidth(190);
      end
    end

    local currentProductionInfo       :table = GetProductionInfoOfCity( data.City, productionHash );

    if (currentProductionInfo.Icon ~= nil) then
      Controls.CurrentProductionName:SetText(Locale.ToUpper(Locale.Lookup(currentProductionInfo.Name))..completedStr);
      Controls.CurrentProductionProgress:SetPercent(currentProductionInfo.PercentComplete);
      Controls.CurrentProductionProgress:SetShadowPercent(currentProductionInfo.PercentCompleteNextTurn);
      if(currentProductionInfo.Tooltip ~= nil) then
        Controls.CurrentProductionName:SetToolTipString(Locale.Lookup(currentProductionInfo.Tooltip));
      else
        Controls.CurrentProductionName:SetToolTipString();
      end
      local numberOfTurns = currentProductionInfo.Turns;
      if numberOfTurns == -1 then
        numberOfTurns = "999+";
      end;
      Controls.CurrentProductionCost:SetText(numberOfTurns .. "[ICON_Turn]");
      Controls.CurrentProductionProgressString:SetText("[ICON_Production]"..currentProductionInfo.Progress.."/"..currentProductionInfo.Cost);
    end

    -- AZURENCY : add gold purchases for districts (fall 2017)
    for i, item in ipairs(data.DistrictPurchases) do
      if(CQUI_ProdTable[item.Hash] == nil) then
        CQUI_ProdTable[item.Hash] = {};
      end
      if (item.Yield == "YIELD_GOLD") then
        CQUI_ProdTable[item.Hash]["gold"] = item.Cost;
      else
        CQUI_ProdTable[item.Hash]["faith"] = item.Cost;
      end
    end

    -- Populate Districts ------------------------ CANNOT purchase districts
    districtList = listIM:GetInstance();
    districtList.Header:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_DISTRICTS_BUILDINGS")));
    districtList.HeaderOn:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_DISTRICTS_BUILDINGS")));
    local dL = districtList;  -- Due to lambda capture, we need to copy this for callback
    if ( districtList.districtListIM ~= nil ) then
      districtList.districtListIM:ResetInstances();
    else
      districtList.districtListIM = InstanceManager:new( "DistrictListInstance", "Root", districtList.List);
    end

    -- In the interest of performance, we're keeping the instances that we created and resetting the data.
    -- This requires a little bit of footwork to remember the instances that have been modified and to manually reset them.
    for _,type in ipairs(m_TypeNames) do
      if ( districtList[BUILDING_IM_PREFIX..type] ~= nil) then    --Reset the states for the building instance managers
        districtList[BUILDING_IM_PREFIX..type]:ResetInstances();
      end
      if ( districtList[BUILDING_DRAWER_PREFIX..type] ~= nil) then  --Reset the states of the drawers
        districtList[BUILDING_DRAWER_PREFIX..type]:SetHide(true);
      end
    end
    m_TypeNames = {};

    for i, item in ipairs(data.DistrictItems) do
      if(GameInfo.Districts[item.Hash].RequiresPopulation and cityData.DistrictsNum < cityData.DistrictsPossibleNum) then
        if(GetNumDistrictsInCityQueue(selectedCity) + cityData.DistrictsNum >= cityData.DistrictsPossibleNum) then
          item.Disabled = true;
          if(not string.find(item.ToolTip, "COLOR:Red")) then
            item.ToolTip = item.ToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup("LOC_DISTRICT_ZONE_POPULATION_TOO_LOW_SHORT", cityData.DistrictsPossibleNum * 3 + 1);
          end
        end
      end

      local districtListing = districtList["districtListIM"]:GetInstance();
      districtListing.ButtonContainer:SetSizeY(CQUI_INSTANCE_Y);
      districtListing.BuildingDrawer:SetOffsetY(CQUI_INSTANCE_Y);
      ResetInstanceVisibility(districtListing);
      if(CQUI_ProdTable[item.Hash] == nil) then
        CQUI_ProdTable[item.Hash] = {};
      end
      -- Check to see if this district item is one of the items that is recommended:
      if CQUI_ShowProductionRecommendations then
        for _,hash in ipairs( m_recommendedItems) do
          if(item.Hash == hash.BuildItemHash) then
            districtListing.RecommendedIcon:SetHide(false);
          end
        end
      end

      local nameStr = Locale.Lookup("{1_Name}", item.Name);
      if (item.Repair) then
        nameStr = nameStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_ITEM_REPAIR");
      end
      if (item.Contaminated) then
        nameStr = nameStr .. Locale.Lookup("LOC_PRODUCTION_ITEM_DECONTAMINATE");
      end
      districtListing.LabelText:SetText(nameStr);

      local turnsStrTT:string = "";
      local turnsStr:string = "";

      if(item.HasBeenBuilt and GameInfo.Districts[item.Type].OnePerCity == true and not item.Repair and not item.Contaminated) then
        turnsStrTT = Locale.Lookup("LOC_HUD_CITY_DISTRICT_BUILT_TT");
        turnsStr = "[ICON_Checkmark]";
        districtListing.RecommendedIcon:SetHide(true);            -- CQUI: Remove production recommendations
      else 
        if item.TurnsLeft then
          local numberOfTurns = item.TurnsLeft;
          if numberOfTurns == -1 then
            numberOfTurns = "999+";
            turnsStrTT = Locale.Lookup("LOC_HUD_CITY_WILL_NOT_COMPLETE");
          else
            turnsStrTT = numberOfTurns .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", item.TurnsLeft);
          end
          turnsStr = numberOfTurns .. "[ICON_Turn]";
        end
      end

      if(item.Progress > 0) then
        districtListing.ProductionProgressArea:SetHide(false);
        local districtProgress = item.Progress/item.Cost;
        if (districtProgress < 1) then
          districtListing.ProductionProgress:SetPercent(districtProgress);
        else
          districtListing.ProductionProgressArea:SetHide(true);
        end
      else
        districtListing.ProductionProgressArea:SetHide(true);
      end

      districtListing.CostText:SetToolTipString(turnsStrTT);
      districtListing.CostText:SetText(turnsStr);
      districtListing.Button:SetToolTipString(item.ToolTip);
      districtListing.Disabled:SetToolTipString(item.ToolTip);
      districtListing.Icon:SetIcon(ICON_PREFIX..item.Type);

      local districtType = item.Type;
      -- Check to see if this is a unique district that will be substituted for another kind of district
      if(GameInfo.DistrictReplaces[item.Type] ~= nil) then
        districtType =  GameInfo.DistrictReplaces[item.Type].ReplacesDistrictType;
      end
      local uniqueBuildingIMName = BUILDING_IM_PREFIX..districtType;
      local uniqueBuildingAreaName = BUILDING_DRAWER_PREFIX..districtType;

      table.insert(m_TypeNames, districtType);
      districtList[uniqueBuildingIMName] = InstanceManager:new( "BuildingListInstance", "Root", districtListing.BuildingStack);
      districtList[uniqueBuildingAreaName] = districtListing.BuildingDrawer;
      districtListing.CompletedArea:SetHide(true);

      if (item.Disabled) then
        if(item.HasBeenBuilt) then
          turnsStrTT = Locale.Lookup("LOC_HUD_CITY_DISTRICT_BUILT_TT");
          turnsStr = "[ICON_Checkmark]";
          districtListing.CompletedArea:SetHide(false);
          districtListing.Disabled:SetHide(true);
        else
          if(showDisabled) then
            districtListing.Disabled:SetHide(false);
            districtListing.Button:SetColor(COLOR_LOW_OPACITY);
          else
            districtListing.Root:SetHide(true);
          end
        end
      else
        districtListing.Root:SetHide(false);
        districtListing.Disabled:SetHide(true);
        districtListing.Button:SetColor(0xFFFFFFFF);
      end
      districtListing.Button:SetDisabled(item.Disabled);
      districtListing.Button:RegisterCallback( Mouse.eLClick, function()
        if(m_isCONTROLpressed or not CQUI_ProductionQueue) then
          nextDistrictSkipToFront = true;
        else
          nextDistrictSkipToFront = false;
        end
        QueueDistrict(data.City, item, nextDistrictSkipToFront);
      end);

      districtListing.Button:RegisterCallback( Mouse.eMClick, function()
        nextDistrictSkipToFront = true;
        QueueDistrict(data.City, item, true);
        RecenterCameraToSelectedCity();
      end);

      districtListing.Button:RegisterCallback( Mouse.eRClick, function()
        LuaEvents.OpenCivilopedia(item.Type);
      end);

      districtListing.Root:SetTag(UITutorialManager:GetHash(item.Type));

      --CQUI Button binds
      districtListing.PurchaseButton:RegisterCallback( Mouse.eLClick, function()
        PurchaseDistrict(data.City, item);
      end);
      if CQUI_ProdTable[item.Hash]["gold"] ~= nil then
        districtListing.PurchaseButton:SetText(CQUI_ProdTable[item.Hash]["gold"] .. "[ICON_GOLD]");
        districtListing.PurchaseButton:SetHide(false);
        districtListing.PurchaseButton:SetDisabled(CQUI_PlayerGold < CQUI_ProdTable[item.Hash]["gold"]);
        if (CQUI_PlayerGold < CQUI_ProdTable[item.Hash]["gold"]) then
          districtListing.PurchaseButton:SetColor(0xDD3366FF);
        else
          districtListing.PurchaseButton:SetColor(0xFFF38FFF);
        end
      else
        districtListing.PurchaseButton:SetHide(true);
      end
      districtListing.FaithPurchaseButton:RegisterCallback( Mouse.eLClick, function()
        PurchaseBuilding(data.City, item, GameInfo.Yields["YIELD_FAITH"].Index);
      end);
      if CQUI_ProdTable[item.Hash]["faith"] ~= nil then
        districtListing.FaithPurchaseButton:SetText(CQUI_ProdTable[item.Hash]["faith"] .. "[ICON_FAITH]");
        districtListing.FaithPurchaseButton:SetHide(false);
        districtListing.FaithPurchaseButton:SetDisabled(CQUI_PlayerFaith < CQUI_ProdTable[item.Hash]["faith"]);
        if (CQUI_PlayerFaith < CQUI_ProdTable[item.Hash]["faith"]) then
          districtListing.FaithPurchaseButton:SetColor(0xDD3366FF);
        else
          districtListing.FaithPurchaseButton:SetColor(0xFFF38FFF);
        end
      else
        districtListing.FaithPurchaseButton:SetHide(true);
      end
    end


    districtList.List:CalculateSize();
    districtList.List:ReprocessAnchoring();

    if (districtList.List:GetSizeY()==0) then
      districtList.Top:SetHide(true);
    else
      m_maxProductionSize = m_maxProductionSize + HEADER_Y + SEPARATOR_Y;
      districtList.Header:RegisterCallback( Mouse.eLClick, function()
        OnExpand(dL);
        end);
      districtList.Header:RegisterCallback( Mouse.eMouseEnter,  function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
      districtList.HeaderOn:RegisterCallback( Mouse.eLClick, function()
        OnCollapse(dL);
        end);
      districtList.HeaderOn:RegisterCallback( Mouse.eMouseEnter,  function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
    end

    prodDistrictList = dL;

    for i, item in ipairs(data.BuildingPurchases) do
      if(CQUI_ProdTable[item.Hash] == nil) then
        CQUI_ProdTable[item.Hash] = {};
      end
      if (item.Yield == "YIELD_GOLD") then
        CQUI_ProdTable[item.Hash]["gold"] = item.Cost;
      else
        CQUI_ProdTable[item.Hash]["faith"] = item.Cost;
      end
    end


    -- Populate Nested Buildings -----------------

    for i, buildingItem in ipairs(data.BuildingItems) do
      local displayItem = true;

      -- PQ: Check if this building is mutually exclusive with another
      -- if(CQUI_MutuallyExclusiveBuildings[buildingItem.Type]) then
      --   meb = CQUI_MutuallyExclusiveBuildings[buildingItem.Type].MutuallyExclusiveBuilding
      --   if(IsBuildingInQueue(selectedCity, GameInfo.Buildings[CQUI_MutuallyExclusiveBuildings[buildingItem.Type].MutuallyExclusiveBuilding].Hash) or pBuildings:HasBuilding(GameInfo.Buildings[CQUI_MutuallyExclusiveBuildings[buildingItem.Type].MutuallyExclusiveBuilding].Index)) then
      --     displayItem = false;
      --     -- -- Concatenanting two fragments is not loc friendly.  This needs to change.
      --     -- buildingItem.ToolTip = buildingItem.ToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup("LOC_UI_PEDIA_EXCLUSIVE_WITH");
      --     -- buildingItem.ToolTip = buildingItem.ToolTip .. " " .. Locale.Lookup(GameInfo.Buildings[GameInfo.MutuallyExclusiveBuildings[buildingItem.Hash].MutuallyExclusiveBuilding].Name);
      --   end
      -- end

      -- PQ: Check if this building is mutually exclusive with another
      if(mutuallyExclusiveBuildings[buildingItem.Type]) then
        for mutuallyExclusiveBuilding in GameInfo.MutuallyExclusiveBuildings() do
          if(mutuallyExclusiveBuilding.Building == buildingItem.Type) then
            if(IsBuildingInQueue(selectedCity, GameInfo.Buildings[mutuallyExclusiveBuilding.MutuallyExclusiveBuilding].Hash) or pBuildings:HasBuilding(GameInfo.Buildings[mutuallyExclusiveBuilding.MutuallyExclusiveBuilding].Index)) then
              displayItem = false;
            end
          elseif(mutuallyExclusiveBuilding.MutuallyExclusiveBuilding == buildingItem.Type) then
            if(IsBuildingInQueue(selectedCity, GameInfo.Buildings[mutuallyExclusiveBuilding.Building].Hash) or pBuildings:HasBuilding(GameInfo.Buildings[mutuallyExclusiveBuilding.Building].Index)) then
              displayItem = false;
            end
          end
        end
      end

      if(buildingItem.Hash == GameInfo.Buildings["BUILDING_PALACE"].Hash) then
        displayItem = false;
      end

      if(not buildingItem.IsWonder and not IsBuildingInQueue(selectedCity, buildingItem.Hash) and displayItem) then
        local uniqueDrawerName = BUILDING_DRAWER_PREFIX..buildingItem.PrereqDistrict;
        local uniqueIMName = BUILDING_IM_PREFIX..buildingItem.PrereqDistrict;
        if (districtList[uniqueIMName] ~= nil) then
          local buildingListing = districtList[uniqueIMName]:GetInstance();
          ResetInstanceVisibility(buildingListing);
          if(CQUI_ProdTable[buildingItem.Hash] == nil) then
            CQUI_ProdTable[buildingItem.Hash] = {};
          end
          CQUI_ProdTable[buildingItem.Hash]["time"] = buildingItem.TurnsLeft;
          -- Check to see if this is one of the recommended items
          if CQUI_ShowProductionRecommendations then
            for _,hash in ipairs( m_recommendedItems) do
              if(buildingItem.Hash == hash.BuildItemHash) then
                buildingListing.RecommendedIcon:SetHide(false);
              end
            end
          end
          buildingListing.Root:SetSizeX(305);
          buildingListing.Button:SetSizeX(305);
          local districtBuildingAreaControl = districtList[uniqueDrawerName];
          districtBuildingAreaControl:SetHide(false);

          --Fill the meter if there is any progress, hide it if not
          if(buildingItem.Progress > 0) then
            buildingListing.ProductionProgressArea:SetHide(false);
            local buildingProgress = buildingItem.Progress/buildingItem.Cost;
            if (buildingProgress < 1) then
              buildingListing.ProductionProgress:SetPercent(buildingProgress);
            else
              buildingListing.ProductionProgressArea:SetHide(true);
            end
          else
            buildingListing.ProductionProgressArea:SetHide(true);
          end

          local nameStr = Locale.Lookup("{1_Name}", buildingItem.Name);
          if (buildingItem.Repair) then
            nameStr = nameStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_ITEM_REPAIR");
          end
          buildingListing.LabelText:SetText(nameStr);
          local turnsStrTT:string = "";
          local turnsStr:string = "";
          local numberOfTurns = buildingItem.TurnsLeft;
          if numberOfTurns == -1 then
            numberOfTurns = "999+";
            turnsStrTT = Locale.Lookup("LOC_HUD_CITY_WILL_NOT_COMPLETE");
          else
            turnsStrTT = numberOfTurns .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", buildingItem.TurnsLeft);
          end
          turnsStr = numberOfTurns .. "[ICON_Turn]";
          buildingListing.CostText:SetToolTipString(turnsStrTT);
          buildingListing.CostText:SetText(turnsStr);
          buildingListing.Button:SetToolTipString(buildingItem.ToolTip);
          buildingListing.Disabled:SetToolTipString(buildingItem.ToolTip);
          buildingListing.Icon:SetIcon(ICON_PREFIX..buildingItem.Type);
          buildingListing.Button:RegisterCallback( Mouse.eLClick, function()
            QueueBuilding(data.City, buildingItem, not CQUI_ProductionQueue);
          end);

          buildingListing.Button:RegisterCallback( Mouse.eMClick, function()
            QueueBuilding(data.City, buildingItem, true);
            RecenterCameraToSelectedCity();
          end);


          buildingListing.Button:RegisterCallback( Mouse.eRClick, function()
            LuaEvents.OpenCivilopedia(buildingItem.Type);
          end);
          buildingListing.Button:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

          buildingListing.Button:SetTag(UITutorialManager:GetHash(buildingItem.Type));

          --CQUI Button binds
          buildingListing.PurchaseButton:RegisterCallback( Mouse.eLClick, function()
            PurchaseBuilding(data.City, buildingItem, GameInfo.Yields["YIELD_GOLD"].Index);
          end);
          if CQUI_ProdTable[buildingItem.Hash]["gold"] ~= nil then
            buildingListing.PurchaseButton:SetText(CQUI_ProdTable[buildingItem.Hash]["gold"] .. "[ICON_GOLD]");
            buildingListing.PurchaseButton:SetHide(false);
            buildingListing.PurchaseButton:SetDisabled(CQUI_PlayerGold < CQUI_ProdTable[buildingItem.Hash]["gold"]);
            if (CQUI_PlayerGold < CQUI_ProdTable[buildingItem.Hash]["gold"]) then
              buildingListing.PurchaseButton:SetColor(0xDD3366FF);
            else
              buildingListing.PurchaseButton:SetColor(0xFFF38FFF);
            end
          else
            buildingListing.PurchaseButton:SetHide(true);
          end
          buildingListing.FaithPurchaseButton:RegisterCallback( Mouse.eLClick, function()
            PurchaseBuilding(data.City, buildingItem, GameInfo.Yields["YIELD_FAITH"].Index);
          end);
          if CQUI_ProdTable[buildingItem.Hash]["faith"] ~= nil then
            buildingListing.FaithPurchaseButton:SetText(CQUI_ProdTable[buildingItem.Hash]["faith"] .. "[ICON_FAITH]");
            buildingListing.FaithPurchaseButton:SetHide(false);
            buildingListing.FaithPurchaseButton:SetDisabled(CQUI_PlayerFaith < CQUI_ProdTable[buildingItem.Hash]["faith"]);
            if (CQUI_PlayerFaith < CQUI_ProdTable[buildingItem.Hash]["faith"]) then
              buildingListing.FaithPurchaseButton:SetColor(0xDD3366FF);
            else
              buildingListing.FaithPurchaseButton:SetColor(0xFFF38FFF);
            end
          else
            buildingListing.FaithPurchaseButton:SetHide(true);
          end
          if (buildingItem.Disabled) then
            if(showDisabled) then
              buildingListing.Disabled:SetHide(false);
              buildingListing.Button:SetColor(COLOR_LOW_OPACITY);
              buildingListing.PurchaseButton:SetHide(true);
              buildingListing.FaithPurchaseButton:SetHide(true);
            else
              buildingListing.Button:SetHide(true);
            end
          else
            buildingListing.Button:SetHide(false);
            buildingListing.Disabled:SetHide(true);
            buildingListing.ButtonContainer:SetSizeY(CQUI_INSTANCE_Y);
            buildingListing.Button:SetSizeY(CQUI_INSTANCE_Y);
            buildingListing.Button:SetColor(0xffffffff);
          end
          buildingListing.Button:SetDisabled(buildingItem.Disabled);
        end
      end
    end

    -- Populate Wonders ------------------------ CANNOT purchase wonders
    wonderList = listIM:GetInstance();
    wonderList.Header:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_CITY_WONDERS")));
    wonderList.HeaderOn:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_CITY_WONDERS")));
    local wL = wonderList;
    if ( wonderList.wonderListIM ~= nil ) then
      wonderList.wonderListIM:ResetInstances();
    else
      wonderList.wonderListIM = InstanceManager:new( "BuildingListInstance", "Root", wonderList.List);
    end

    for i, item in ipairs(data.BuildingItems) do
      if(item.IsWonder) then
        local wonderListing = wonderList["wonderListIM"]:GetInstance();
        ResetInstanceVisibility(wonderListing);
        wonderListing.ButtonContainer:SetSizeY(CQUI_INSTANCE_Y);
        wonderListing.Button:SetSizeY(CQUI_INSTANCE_Y);
        wonderListing.PurchaseButton:SetHide(true);
        wonderListing.FaithPurchaseButton:SetHide(true);
        if CQUI_ShowProductionRecommendations then
          for _,hash in ipairs( m_recommendedItems) do
            if(item.Hash == hash.BuildItemHash) then
              wonderListing.RecommendedIcon:SetHide(false);
            end
          end
        end
        local nameStr = Locale.Lookup("{1_Name}", item.Name);
        if (item.Repair) then
          nameStr = nameStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_ITEM_REPAIR");
        end
        wonderListing.LabelText:SetText(nameStr);

        if(item.Progress > 0) then
          wonderListing.ProductionProgressArea:SetHide(false);
          local wonderProgress = item.Progress/item.Cost;
          if (wonderProgress < 1) then
            wonderListing.ProductionProgress:SetPercent(wonderProgress);
          else
            wonderListing.ProductionProgressArea:SetHide(true);
          end
        else
          wonderListing.ProductionProgressArea:SetHide(true);
        end
        local turnsStrTT:string = "";
        local turnsStr:string = "";
        local numberOfTurns = item.TurnsLeft;
        if numberOfTurns == -1 then
          numberOfTurns = "999+";
          turnsStrTT = Locale.Lookup("LOC_HUD_CITY_WILL_NOT_COMPLETE");
        else
          turnsStrTT = numberOfTurns .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", item.TurnsLeft);
        end
        turnsStr = numberOfTurns .. "[ICON_Turn]";
        wonderListing.CostText:SetText(turnsStr);
        wonderListing.CostText:SetToolTipString(turnsStrTT);
        wonderListing.Button:SetToolTipString(item.ToolTip);
        wonderListing.Disabled:SetToolTipString(item.ToolTip);
        wonderListing.Icon:SetIcon(ICON_PREFIX..item.Type);
        if (item.Disabled) then
          if(showDisabled) then
            wonderListing.Disabled:SetHide(false);
            wonderListing.Button:SetColor(COLOR_LOW_OPACITY);
          else
            wonderListing.Button:SetHide(true);
          end
        else
          wonderListing.Button:SetHide(false);
          wonderListing.Disabled:SetHide(true);
          wonderListing.Button:SetColor(0xffffffff);
        end
        wonderListing.Button:SetDisabled(item.Disabled);
        wonderListing.Button:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
        wonderListing.Button:RegisterCallback( Mouse.eLClick, function()
          --BuildBuilding(data.City, item);
          QueueBuilding(data.City, item, not CQUI_ProductionQueue)
        end);

        wonderListing.Button:RegisterCallback( Mouse.eRClick, function()
          LuaEvents.OpenCivilopedia(item.Type);
        end);

        wonderListing.Button:SetTag(UITutorialManager:GetHash(item.Type));
      end
    end

    wonderList.List:CalculateSize();
    wonderList.List:ReprocessAnchoring();

    if (wonderList.List:GetSizeY()==0) then
      wonderList.Top:SetHide(true);
    else
      m_maxProductionSize = m_maxProductionSize + HEADER_Y + SEPARATOR_Y;
      wonderList.Header:RegisterCallback( Mouse.eLClick, function()
        OnExpand(wL);
        end);
      wonderList.Header:RegisterCallback( Mouse.eMouseEnter,  function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
      wonderList.HeaderOn:RegisterCallback( Mouse.eLClick, function()
        OnCollapse(wL);
        end);
      wonderList.HeaderOn:RegisterCallback( Mouse.eMouseEnter,  function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
    end
    prodWonderList = wL;

    -- Populate Projects ------------------------
    projectList = listIM:GetInstance();
    projectList.Header:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_PROJECTS")));
    projectList.HeaderOn:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_PROJECTS")));
    local pL = projectList;
    if ( projectList.projectListIM ~= nil ) then
      projectList.projectListIM:ResetInstances();
    else
      projectList.projectListIM = InstanceManager:new( "ProjectListInstance", "Root", projectList.List);
    end

    for i, item in ipairs(data.ProjectItems) do
      local projectListing = projectList.projectListIM:GetInstance();
      ResetInstanceVisibility(projectListing);
      -- Check to see if this item is recommended
      if CQUI_ShowProductionRecommendations then
        for _,hash in ipairs( m_recommendedItems) do
          if(item.Hash == hash.BuildItemHash) then
            projectListing.RecommendedIcon:SetHide(false);
          end
        end
      end

      -- ProductionQueue: We need to check that there isn't already one of these in the queue
      if(IsHashInQueue(selectedCity, item.Hash)) then
        item.TurnsLeft = math.ceil(item.Cost / cityData.ProductionPerTurn);
        item.Progress = 0;
      end

      -- Production meter progress for project
      if(item.Progress > 0) then
        projectListing.ProductionProgressArea:SetHide(false);
        local projectProgress = item.Progress/item.Cost;
        if (projectProgress < 1) then
          projectListing.ProductionProgress:SetPercent(projectProgress);
        else
          projectListing.ProductionProgressArea:SetHide(true);
        end
      else
        projectListing.ProductionProgressArea:SetHide(true);
      end
      local numberOfTurns = item.TurnsLeft;
      if numberOfTurns == -1 then
        numberOfTurns = "999+";
      end;
      local nameStr = Locale.Lookup("{1_Name}", item.Name);
      local turnsStr = numberOfTurns .. "[ICON_Turn]";
      projectListing.LabelText:SetText(nameStr);
      projectListing.CostText:SetText(turnsStr);
      projectListing.Button:SetToolTipString(item.ToolTip);
      projectListing.Disabled:SetToolTipString(item.ToolTip);
      projectListing.Icon:SetIcon(ICON_PREFIX..item.Type);
      projectListing.ButtonContainer:SetSizeY(CQUI_INSTANCE_Y);
      if (item.Disabled) then
        if(showDisabled) then
          projectListing.Disabled:SetHide(false);
          projectListing.Button:SetColor(COLOR_LOW_OPACITY);
        else
          projectListing.Button:SetHide(true);
        end
      else
        projectListing.Button:SetHide(false);
        projectListing.Disabled:SetHide(true);
        projectListing.Button:SetColor(0xffffffff);
      end
      projectListing.Button:SetDisabled(item.Disabled);
      projectListing.Button:RegisterCallback( Mouse.eLClick, function()
          QueueProject(data.City, item, not CQUI_ProductionQueue);
      end);

      projectListing.Button:RegisterCallback( Mouse.eMClick, function()
        QueueProject(data.City, item, true);
        RecenterCameraToSelectedCity();
      end);

      projectListing.Button:RegisterCallback( Mouse.eRClick, function()
        LuaEvents.OpenCivilopedia(item.Type);
      end);

      projectListing.Button:SetTag(UITutorialManager:GetHash(item.Type));
    end


    projectList.List:CalculateSize();
    projectList.List:ReprocessAnchoring();

    if (projectList.List:GetSizeY()==0) then
      projectList.Top:SetHide(true);
    else
      m_maxProductionSize = m_maxProductionSize + HEADER_Y + SEPARATOR_Y;
      projectList.Header:RegisterCallback( Mouse.eLClick, function()
        OnExpand(pL);
        end);
      projectList.HeaderOn:RegisterCallback( Mouse.eLClick, function()
        OnCollapse(pL);
        end);
    end

    prodProjectList = pL;

  --===================================================================================================================
    ------------------------------------------ Populate the Production Queue --------------------------------------------
    --===================================================================================================================
    m_queueIM:ResetInstances();

    if(#prodQueue[productionQueueTableKey] > 0) then
      queueList = m_queueIM:GetInstance();

      if (queueList.queueListIM ~= nil) then
        queueList.queueListIM:ResetInstances();
      else
        queueList.queueListIM = InstanceManager:new( "QueueListInstance", "Root", queueList.List);
      end

      local itemEncountered = {};

      for i, qi in pairs(prodQueue[productionQueueTableKey]) do
        local queueListing = queueList["queueListIM"]:GetInstance();
        ResetInstanceVisibility(queueListing);
        queueListing.ProductionProgressArea:SetHide(true);

        if(qi.entry) then
          local info = GetProductionInfoOfCity(selectedCity, qi.entry.Hash);
          local turnsText = info.Turns;

          if(itemEncountered[qi.entry.Hash]) then
            turnsText = math.ceil(info.Cost / cityData.ProductionPerTurn);
          else
            if(info.Progress > 0) then
              queueListing.ProductionProgressArea:SetHide(false);

              local progress = info.Progress/info.Cost;
              if (progress < 1) then
                queueListing.ProductionProgress:SetPercent(progress);
              else
                queueListing.ProductionProgressArea:SetHide(true);
              end
            end
          end

          local suffix = "";

          if(GameInfo.Units[qi.entry.Hash]) then
            local unitDef = GameInfo.Units[qi.entry.Hash];
            local cost = 0;

            if(prodQueue[productionQueueTableKey][i].type == PRODUCTION_TYPE.CORPS) then
              cost = qi.entry.CorpsCost;
              if(unitDef.Domain == "DOMAIN_SEA") then
                suffix = " " .. Locale.Lookup("LOC_UNITFLAG_FLEET_SUFFIX");
              else
                suffix = " " .. Locale.Lookup("LOC_UNITFLAG_CORPS_SUFFIX");
              end
            elseif(qi.type == PRODUCTION_TYPE.ARMY) then
              cost = qi.entry.ArmyCost;
              if(unitDef.Domain == "DOMAIN_SEA") then
                suffix = " " .. Locale.Lookup("LOC_UNITFLAG_ARMADA_SUFFIX");
              else
                suffix = " " .. Locale.Lookup("LOC_UNITFLAG_ARMY_SUFFIX");
              end
            elseif(qi.type == PRODUCTION_TYPE.UNIT) then
              cost = qi.entry.Cost;
            end

            if(itemEncountered[qi.entry.Hash] and info.Progress ~= 0) then
              turnsText = math.ceil(cost / cityData.ProductionPerTurn);
              local percentPerTurn = info.PercentCompleteNextTurn - info.PercentComplete;
              if(info.PercentCompleteNextTurn < 1) then
                turnsText = math.ceil(1/percentPerTurn);
              else
                turnsText = "~" .. turnsText;
              end
            else
              turnsText = info.Turns;
              local progress = info.Progress / cost;
              if (progress < 1) then
                queueListing.ProductionProgress:SetPercent(progress);
              end
            end
          end

          if(qi.entry.Repair) then suffix = " (" .. Locale.Lookup("LOC_UNITOPERATION_REPAIR_DESCRIPTION") .. ")" end

          queueListing.LabelText:SetText(Locale.Lookup(qi.entry.Name) .. suffix);
          queueListing.Icon:SetIcon(info.Icon)
          queueListing.CostText:SetText(turnsText .. "[ICON_Turn]");
          if(i == 1) then queueListing.Active:SetHide(false); end

          itemEncountered[qi.entry.Hash] = true;
        end

        -- EVENT HANDLERS --
        queueListing.Button:RegisterCallback( Mouse.eRClick, function()
          if(CanRemoveFromQueue(selectedCity, i)) then
            if(RemoveFromQueue(selectedCity, i)) then
              if(i == 1) then
                BuildFirstQueued(selectedCity);
              else
                Refresh();
              end
            end
          end
        end);

        queueListing.Button:RegisterCallback( Mouse.eMouseEnter, function()
          if(not UILens.IsLayerOn( LensLayers.DISTRICTS ) and qi.plotID > -1) then
            UILens.SetAdjacencyBonusDistict(qi.plotID, "Placement_Valid", {})
          end
        end);

        queueListing.Button:RegisterCallback( Mouse.eMouseExit, function()
          if(not UILens.IsLayerOn( LensLayers.DISTRICTS )) then
            UILens.ClearLayerHexes( LensLayers.DISTRICTS );
          end
        end);

        queueListing.Button:RegisterCallback( Mouse.eLDblClick, function()
          MoveQueueIndex(selectedCity, i, 1);
          BuildFirstQueued(selectedCity);
        end);

        queueListing.Button:RegisterCallback( Mouse.eMClick, function()
          MoveQueueIndex(selectedCity, i, 1);
          BuildFirstQueued(selectedCity);
          RecenterCameraToSelectedCity();
        end);

        queueListing.Draggable:RegisterCallback( Drag.eDown, function(dragStruct) OnDownInQueue(dragStruct, queueListing, i); end );
        queueListing.Draggable:RegisterCallback( Drag.eDrop, function(dragStruct) OnDropInQueue(dragStruct, queueListing, i); end );

        BuildProductionQueueDropArea( queueListing.Button,  i,  "QUEUE_"..i );
      end

      -- AZURENCY : fix the size auto not properly changing (fall 2017, it changes after)
      queueList.List:CalculateSize();
      queueList.ListSlide:SetSizeY(queueList.List:GetSizeY())
      queueList.ListAlpha:SetSizeY(queueList.List:GetSizeY())
    end

  m_maxProductionSize = m_maxProductionSize + districtList.List:GetSizeY() + unitList.List:GetSizeY() + projectList.List:GetSizeY();

  -- DEBUG %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  --for _,data in ipairs( m_recommendedItems) do
  --  if(GameInfo.Types[data.BuildItemHash].Type ~= nil) then
  --    print("Hash = ".. GameInfo.Types[data.BuildItemHash].Type);
  --  else
  --    print("Invalid hash received = " .. data.BuildItemHash);
  --  end
  --end
  -- DEBUG %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end

function OnLocalPlayerChanged()
  Refresh();
end

function OnTechCivicCompleted (ePlayer:number)
  local localPlayer = Game.GetLocalPlayer();
  --print("Tech / Civic Completed:" .. ePlayer);
  if localPlayer ~= -1 and localPlayer == ePlayer then
    CheckAndReplaceAllQueuesForUpgrades();
    Refresh();
  end
end

function OnPlayerTurnActivated(player, isFirstTimeThisTurn)
  if (isFirstTimeThisTurn and Game.GetLocalPlayer() == player) then
    -- Maybe only refresh if there was any upgrades OPTIMIZATION!!!
    CheckAndReplaceAllQueuesForUpgrades();
    Refresh();
    lastProductionCompletePerCity = {};
  end
end

-- Returns ( allReasons:string )
function ComposeFailureReasonStrings( isDisabled:boolean, results:table )
  if isDisabled and results ~= nil then
    -- Are there any failure reasons?
    local pFailureReasons : table = results[CityCommandResults.FAILURE_REASONS];
    if pFailureReasons ~= nil and table.count( pFailureReasons ) > 0 then
      -- Collect them all!
      local allReasons : string = "";
      for i,v in ipairs(pFailureReasons) do
        allReasons = allReasons .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup(v) .. "[ENDCOLOR]";
      end
      return allReasons;
    end
  end
  return "";
end
function ComposeProductionCostString( iProductionProgress:number, iProductionCost:number)
  -- Show production progress only if there is progress present
  if iProductionCost ~= 0 then
    local TXT_COST      :string = Locale.Lookup( "LOC_HUD_PRODUCTION_COST" );
    local TXT_PRODUCTION  :string = Locale.Lookup( "LOC_HUD_PRODUCTION" );
    local costString    :string = tostring(iProductionCost);

    if iProductionProgress > 0 then -- Only show fraction if build progress has been made.
      costString = tostring(iProductionProgress) .. "/" .. costString;
    end
    return "[NEWLINE][NEWLINE]" .. TXT_COST .. ": " .. costString .. " [ICON_Production] " .. TXT_PRODUCTION;
  end
  return "";
end
-- Returns ( tooltip:string, subtitle:string )
function ComposeUnitCorpsStrings( unit:table, iProdProgress:number, pBuildQueue )

  local tooltip:string = ToolTipHelper.GetUnitToolTip( unit.Hash, MilitaryFormationTypes.CORPS_MILITARY_FORMATION, pBuildQueue );

  local subtitle  :string = "";
  if sUnitDomain == "DOMAIN_SEA" then
    subtitle = "(" .. Locale.Lookup("LOC_HUD_UNIT_PANEL_FLEET_SUFFIX") .. ")";
  else
    subtitle = "(" .. Locale.Lookup("LOC_HUD_UNIT_PANEL_CORPS_SUFFIX") .. ")";
  end
  tooltip = tooltip .. ComposeProductionCostString( iProdProgress, pBuildQueue:GetUnitCorpsCost( unit.Index ) );
  return tooltip, subtitle;
end
function ComposeUnitArmyStrings( unit:table, iProdProgress:number, pBuildQueue )

  local tooltip:string = ToolTipHelper.GetUnitToolTip( unit.Hash, MilitaryFormationTypes.ARMY_MILITARY_FORMATION, pBuildQueue );

  local subtitle  :string = "";
  if sUnitDomain == "DOMAIN_SEA" then
    subtitle = "("..Locale.Lookup("LOC_HUD_UNIT_PANEL_ARMADA_SUFFIX")..")";
  else
    subtitle = "("..Locale.Lookup("LOC_HUD_UNIT_PANEL_ARMY_SUFFIX")..")";
  end
  tooltip = tooltip .. ComposeProductionCostString( iProdProgress, pBuildQueue:GetUnitArmyCost( unit.Index ) );
  return tooltip, subtitle;
end

-- Returns ( isPurchaseable:boolean, kEntry:table )
function ComposeUnitForPurchase( row:table, pCity:table, sYield:string, pYieldSource:table, sCantAffordKey:string )
  local YIELD_TYPE  :number = GameInfo.Yields[sYield].Index;

  -- Should we display this option to the player?
  local tParameters = {};
  tParameters[CityCommandTypes.PARAM_UNIT_TYPE] = row.Hash;
  tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = YIELD_TYPE;
  if CityManager.CanStartCommand( pCity, CityCommandTypes.PURCHASE, true, tParameters, false ) then
    local isCanStart, results      = CityManager.CanStartCommand( pCity, CityCommandTypes.PURCHASE, false, tParameters, true );
    local isDisabled      :boolean = not isCanStart;
    local allReasons       :string = ComposeFailureReasonStrings( isDisabled, results );
    local sToolTip         :string = ToolTipHelper.GetUnitToolTip( row.Hash ) .. allReasons;
    local isCantAfford      :boolean = false;
    --print ( "UnitBuy ", row.UnitType,isCanStart );

    -- Collect some constants so we don't need to keep calling out to get them.
    local nCityID       :number = pCity:GetID();
    local pCityGold        :table = pCity:GetGold();
    local TXT_INSUFFIENT_YIELD  :string = "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup( sCantAffordKey ) .. "[ENDCOLOR]";

    -- Affordability check
    if not pYieldSource:CanAfford( nCityID, row.Hash ) then
      sToolTip = sToolTip .. TXT_INSUFFIENT_YIELD;
      isDisabled = true;
      isCantAfford = true;
    end

    local pBuildQueue     :table  = pCity:GetBuildQueue();
    local nProductionCost   :number = pBuildQueue:GetUnitCost( row.Index );
    local nProductionProgress :number = pBuildQueue:GetUnitProgress( row.Index );
    sToolTip = sToolTip .. "[NEWLINE]---" .. ComposeProductionCostString( nProductionProgress, nProductionCost );

    local kUnit  :table = {
      Type       = row.UnitType;
      Name       = row.Name;
      ToolTip    = sToolTip;
      Hash       = row.Hash;
      Kind       = row.Kind;
      Civilian   = row.FormationClass == "FORMATION_CLASS_CIVILIAN";
      Disabled   = isDisabled;
      CantAfford = isCantAfford,
      Yield      = sYield;
      Cost       = pCityGold:GetPurchaseCost( YIELD_TYPE, row.Hash, MilitaryFormationTypes.STANDARD_MILITARY_FORMATION );
      ReligiousStrength	= row.ReligiousStrength;

      CorpsTurnsLeft = 0;
      ArmyTurnsLeft  = 0;
      Progress       = 0;
    };

    -- Should we present options for building Corps or Army versions?
    if results ~= nil then
      kUnit.Corps = results[CityOperationResults.CAN_TRAIN_CORPS];
      kUnit.Army = results[CityOperationResults.CAN_TRAIN_ARMY];

      local nProdProgress :number = pBuildQueue:GetUnitProgress( row.Index );
      if kUnit.Corps then
        kUnit.CorpsCost = pCityGold:GetPurchaseCost( YIELD_TYPE, row.Hash, MilitaryFormationTypes.CORPS_MILITARY_FORMATION );
        kUnit.CorpsTooltip, kUnit.CorpsName = ComposeUnitCorpsStrings( row, nProdProgress, pBuildQueue );
        kUnit.CorpsDisabled = not pYieldSource:CanAfford( nCityID, row.Hash, MilitaryFormationTypes.CORPS_MILITARY_FORMATION );
        if kUnit.CorpsDisabled then
          kUnit.CorpsTooltip = kUnit.CorpsTooltip .. TXT_INSUFFIENT_YIELD;
        end
      end

      if kUnit.Army then
        kUnit.ArmyCost  = pCityGold:GetPurchaseCost( YIELD_TYPE, row.Hash, MilitaryFormationTypes.ARMY_MILITARY_FORMATION );
        kUnit.ArmyTooltip, kUnit.ArmyName = ComposeUnitArmyStrings( row, nProdProgress, pBuildQueue );
        kUnit.ArmyDisabled = not pYieldSource:CanAfford( nCityID, row.Hash, MilitaryFormationTypes.ARMY_MILITARY_FORMATION );
        if kUnit.ArmyDisabled then
          kUnit.ArmyTooltip = kUnit.ArmyTooltip .. TXT_INSUFFIENT_YIELD;
        end
      end
    end

    return true, kUnit;
  end
  return false, nil;
end
function ComposeBldgForPurchase( pRow:table, pCity:table, sYield:string, pYieldSource:table, sCantAffordKey:string )
  local YIELD_TYPE  :number = GameInfo.Yields[sYield].Index;

  local tParameters = {};
  tParameters[CityCommandTypes.PARAM_BUILDING_TYPE] = pRow.Hash;
  tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = YIELD_TYPE;
  if CityManager.CanStartCommand( pCity, CityCommandTypes.PURCHASE, true, tParameters, false ) then
    local isCanStart, pResults     = CityManager.CanStartCommand( pCity, CityCommandTypes.PURCHASE, false, tParameters, true );
    local isDisabled    :boolean = not isCanStart;
    local sAllReasons    :string = ComposeFailureReasonStrings( isDisabled, pResults );
    local sToolTip       :string = ToolTipHelper.GetBuildingToolTip( pRow.Hash, playerID, pCity ) .. sAllReasons;
    local isCantAfford    :boolean = false;

    -- Affordability check
    if not pYieldSource:CanAfford( pCity:GetID(), pRow.Hash ) then
      sToolTip = sToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup(sCantAffordKey) .. "[ENDCOLOR]";
      isDisabled = true;
      isCantAfford = true;
    end

    local pBuildQueue     :table  = pCity:GetBuildQueue();
    local iProductionCost   :number = pBuildQueue:GetBuildingCost( pRow.Index );
    local iProductionProgress :number = pBuildQueue:GetBuildingProgress( pRow.Index );
    sToolTip = sToolTip .. ComposeProductionCostString( iProductionProgress, iProductionCost );

    local kBuilding :table = {
      Type      = pRow.BuildingType,
      Name      = pRow.Name,
      ToolTip     = sToolTip,
      Hash      = pRow.Hash,
      Kind      = pRow.Kind,
      Disabled    = isDisabled,
      CantAfford    = isCantAfford,
      Cost      = pCity:GetGold():GetPurchaseCost( YIELD_TYPE, pRow.Hash ),
      Yield     = sYield
    };
    return true, kBuilding;
  end
  return false, nil;
end

function ComposeDistrictForPurchase( pRow:table, pCity:table, sYield:string, pYieldSource:table, sCantAffordKey:string )
  local YIELD_TYPE 	:number = GameInfo.Yields[sYield].Index;
  
  local tParameters = {};
  tParameters[CityCommandTypes.PARAM_DISTRICT_TYPE] = pRow.Hash;
  tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = YIELD_TYPE;
  if CityManager.CanStartCommand( pCity, CityCommandTypes.PURCHASE, true, tParameters, false ) then
    local isCanStart, pResults		 = CityManager.CanStartCommand( pCity, CityCommandTypes.PURCHASE, false, tParameters, true );
    local isDisabled		:boolean = not isCanStart;
    local sAllReasons		:string = ComposeFailureReasonStrings( isDisabled, pResults );
    local sToolTip 			:string = ToolTipHelper.GetDistrictToolTip( pRow.Hash ) .. sAllReasons;
    local isCantAfford		:boolean = false;
    
    -- Affordability check
    if not pYieldSource:CanAfford( pCity:GetID(), pRow.Hash ) then
      sToolTip = sToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup(sCantAffordKey) .. "[ENDCOLOR]";
      isDisabled = true;
      isCantAfford = true;
    end
    
    local pBuildQueue			:table  = pCity:GetBuildQueue();
    local iProductionCost		:number = pBuildQueue:GetDistrictCost( pRow.Index );
    local iProductionProgress	:number = pBuildQueue:GetDistrictProgress( pRow.Index );
    sToolTip = sToolTip .. ComposeProductionCostString( iProductionProgress, iProductionCost );
    
    local kDistrict :table = {
      Type			= pRow.DistrictType,
      Name			= pRow.Name, 
      ToolTip			= sToolTip, 
      Hash			= pRow.Hash, 
      Kind			= pRow.Kind, 
      Disabled		= isDisabled, 
      CantAfford		= isCantAfford,
      Cost			= pCity:GetGold():GetPurchaseCost( YIELD_TYPE, pRow.Hash ),  
      Yield			= sYield
    };
    return true, kDistrict;
  end
  return false, nil;
end

-- ===========================================================================
function Refresh()
  local playerID  :number = Game.GetLocalPlayer();
  local pPlayer :table = Players[playerID];
  if (pPlayer == nil) then
    return;
  end

  local selectedCity  = UI.GetHeadSelectedCity();

  if (selectedCity ~= nil) then
    local cityOwner = selectedCity:GetOwner();
    if (cityOwner == playerID) then
    local cityGrowth  = selectedCity:GetGrowth();
    local cityCulture = selectedCity:GetCulture();
    local buildQueue  = selectedCity:GetBuildQueue();
    local playerTreasury= pPlayer:GetTreasury();
    local playerReligion= pPlayer:GetReligion();
    local cityGold    = selectedCity:GetGold();
    local cityBuildings = selectedCity:GetBuildings();
    local cityDistricts = selectedCity:GetDistricts();
    local cityID    = selectedCity:GetID();
    local cityData    = GetCityData(selectedCity);
    local cityPlot    = Map.GetPlot(selectedCity:GetX(), selectedCity:GetY());
  local productionQueueTableKey = FindProductionQueueKey(cityID, selectedCity:GetOwner())

    if(not prodQueue[productionQueueTableKey]) then prodQueue[productionQueueTableKey] = {}; end
    CheckAndReplaceQueueForUpgrades(selectedCity);

    local new_data = {
      City        = selectedCity,
      Population      = selectedCity:GetPopulation(),
      Owner       = selectedCity:GetOwner(),
      Damage        = pPlayer:GetDistricts():FindID( selectedCity:GetDistrictID() ):GetDamage(),
      TurnsUntilGrowth  = cityGrowth:GetTurnsUntilGrowth(),
      CurrentTurnsLeft  = buildQueue:GetTurnsLeft(),
      FoodSurplus     = cityGrowth:GetFoodSurplus(),
      CulturePerTurn    = cityCulture:GetCultureYield(),
      TurnsUntilExpansion = cityCulture:GetTurnsUntilExpansion(),
      DistrictItems   = {},
      BuildingItems   = {},
      UnitItems     = {},
      ProjectItems    = {},
      BuildingPurchases = {},
      UnitPurchases   = {},
      DistrictPurchases	= {},
    };

    local currentProductionHash = buildQueue:GetCurrentProductionTypeHash();
    -- CQUI_currentProductionHash[cityID] = currentProductionHash;
    -- GameConfiguration.SetValue("CQUI_currentProductionHash" .. cityID, CQUI_currentProductionHash[cityID]);

    --Must do districts before buildings
    for row in GameInfo.Districts() do
      if row.Hash == currentProductionHash then
        new_data.CurrentProduction = row.Name;

        if(GameInfo.DistrictReplaces[row.DistrictType] ~= nil) then
          new_data.CurrentProductionType = GameInfo.DistrictReplaces[row.DistrictType].ReplacesDistrictType;
        else
          new_data.CurrentProductionType = row.DistrictType;
        end
      end

      local isInPanelList     :boolean = not row.InternalOnly;
      local bHasProducedDistrict  :boolean = cityDistricts:HasDistrict( row.Index );
      local isInQueue       :boolean = IsHashInQueue( selectedCity, row.Hash );
      local turnsLeft       :number  = buildQueue:GetTurnsLeft( row.DistrictType );

        local isComplete      :boolean = false;

        local pDistricts    :table = selectedCity:GetDistricts();
        for _, pCityDistrict in pDistricts:Members() do

          if row.Index == pCityDistrict:GetType() then
            if pCityDistrict:IsComplete() then
              isComplete = true
              --print("District complete");
              break;
            end
          end
        end

      if (isInPanelList or isInQueue) and ( buildQueue:CanProduce( row.Hash, true ) or bHasProducedDistrict or isInQueue ) then
        local isCanProduceExclusion, results = buildQueue:CanProduce( row.Hash, false, true );
        local isDisabled      :boolean = not isCanProduceExclusion;

        if(isInQueue) then
          bHasProducedDistrict = true;
          turnsLeft = nil;
          isDisabled = true;
        end

        -- If at least one valid plot is found where the district can be built, consider it buildable.
        local plots :table = GetCityRelatedPlotIndexesDistrictsAlternative( selectedCity, row.Hash );
        if plots == nil or table.count(plots) == 0 then
          -- No plots available for district. Has player had already started building it?
          local isPlotAllocated :boolean = false;
          local pDistricts    :table = selectedCity:GetDistricts();
          for _, pCityDistrict in pDistricts:Members() do
            if row.Index == pCityDistrict:GetType() then
              isPlotAllocated = true;
              break;
            end
          end
          -- If not, this district can't be built. Guarantee that isDisabled is set.
          if not isPlotAllocated then
            isDisabled = true;
          end
        elseif isDisabled and results ~= nil then
          -- TODO this should probably be handled in the exposure, for example:
          -- BuildQueue::CanProduce(nDistrictHash, bExclusionTest, bReturnResults, bAllowPurchasingPlots)
          local pFailureReasons : table = results[CityCommandResults.FAILURE_REASONS];
          if pFailureReasons ~= nil and table.count( pFailureReasons ) > 0 then
            -- There are available plots to purchase, it could still be available
            isDisabled = false;
            for i,v in ipairs(pFailureReasons) do
              -- If its disabled for another reason, keep it disabled
              if v ~= "LOC_DISTRICT_ZONE_NO_SUITABLE_LOCATION" then
                isDisabled = true;
                break;
              end
            end
          end
        end

        local allReasons      :string = ComposeFailureReasonStrings( isDisabled, results );
        local sToolTip        :string = ToolTipHelper.GetToolTip(row.DistrictType, Game.GetLocalPlayer()) .. allReasons;

        local iProductionCost   :number = buildQueue:GetDistrictCost( row.Index );
        local iProductionProgress :number = buildQueue:GetDistrictProgress( row.Index );
        sToolTip = sToolTip .. ComposeProductionCostString( iProductionProgress, iProductionCost );

        table.insert( new_data.DistrictItems, {
          Type      = row.DistrictType,
          Name      = row.Name,
          ToolTip     = sToolTip,
          Hash      = row.Hash,
          Kind      = row.Kind,
          TurnsLeft   = turnsLeft,
          Disabled    = isDisabled,
          Repair      = cityDistricts:IsPillaged( row.Hash ),
          Contaminated  = cityDistricts:IsContaminated( row.Index ),
          Cost      = iProductionCost,
          Progress    = iProductionProgress,
          HasBeenBuilt  = bHasProducedDistrict,
          DistrictComplete = isComplete
        });
      end

      -- Can it be purchased with gold?
      local isAllowed, kDistrict = ComposeDistrictForPurchase( row, selectedCity, "YIELD_GOLD", playerTreasury, "LOC_BUILDING_INSUFFICIENT_FUNDS" );
      if isAllowed then
        table.insert( new_data.DistrictPurchases, kDistrict );
      end
      
    end

    --Must do buildings after districts
    for row in GameInfo.Buildings() do
      if row.Hash == currentProductionHash then
        new_data.CurrentProduction = row.Name;
        new_data.CurrentProductionType= row.BuildingType;
      end

      -- PQ: Determine if we have requirements in the queue
      local hasPrereqTech = row.PrereqTech == nil;
      local hasPrereqCivic = row.PrereqCivic == nil;
      local isPrereqDistrictInQueue = false;
      local disabledTooltip = nil;
      local doShow = true;

      if(not row.IsWonder) then
        local prereqTech = GameInfo.Technologies[row.PrereqTech];
        local prereqCivic = GameInfo.Civics[row.PrereqCivic];
        local prereqDistrict = GameInfo.Districts[row.PrereqDistrict];

        if(prereqTech and pPlayer:GetTechs():HasTech(prereqTech.Index)) then hasPrereqTech = true; end
        if(prereqCivic and pPlayer:GetCulture():HasCivic(prereqCivic.Index)) then hasPrereqCivic = true; end
        if((prereqDistrict and IsHashInQueue( selectedCity, prereqDistrict.Hash)) or cityDistricts:HasDistrict(prereqDistrict.Index, true)) then
          isPrereqDistrictInQueue = true;

          if(not IsHashInQueue( selectedCity, prereqDistrict.Hash )) then
            if(cityDistricts:IsPillaged(prereqDistrict.Index)) then
              disabledTooltip = Locale.Lookup("LOC_BUILDING_CONSTRUCT_DISTRICT_IS_PILLAGED");
            elseif(cityDistricts:IsContaminated(prereqDistrict.Index)) then
              disabledTooltip = Locale.Lookup("LOC_BUILDING_CONSTRUCT_DISTRICT_IS_CONTAMINATED");
            end
          end
        end

        if(not isPrereqDistrictInQueue) then
          for replacesRow in GameInfo.DistrictReplaces() do
            if(row.PrereqDistrict == replacesRow.ReplacesDistrictType) then
              local replacementDistrict = GameInfo.Districts[replacesRow.CivUniqueDistrictType];
              if((replacementDistrict and IsHashInQueue( selectedCity, replacementDistrict.Hash)) or cityDistricts:HasDistrict(replacementDistrict.Index, true)) then
                isPrereqDistrictInQueue = true;

                if(not IsHashInQueue( selectedCity, replacementDistrict.Hash )) then
                  if(cityDistricts:IsPillaged(replacementDistrict.Index)) then
                    disabledTooltip = Locale.Lookup("LOC_BUILDING_CONSTRUCT_DISTRICT_IS_PILLAGED");
                  elseif(cityDistricts:IsContaminated(replacementDistrict.Index)) then
                    disabledTooltip = Locale.Lookup("LOC_BUILDING_CONSTRUCT_DISTRICT_IS_CONTAMINATED");
                  end
                end
              end
              break;
            end
          end
        end

        if(not isPrereqDistrictInQueue) then
          local canBuild, reasons = buildQueue:CanProduce(row.BuildingType, false, true);
          if(not canBuild and reasons) then
            local pFailureReasons = reasons[CityCommandResults.FAILURE_REASONS];
            if pFailureReasons ~= nil and table.count( pFailureReasons ) > 0 then
              for i,v in ipairs(pFailureReasons) do
                if(Locale.Lookup("LOC_BUILDING_CONSTRUCT_IS_OCCUPIED") == v) then
                  disabledTooltip = Locale.Lookup("LOC_BUILDING_CONSTRUCT_IS_OCCUPIED");
                end
              end
            end
          end
        end

        -- Check for building prereqs
        for prereqRow in GameInfo.BuildingPrereqs() do
          if(prereqRow.Building == row.BuildingType) then
            local prereqInQueue = false;
            for replaceRow in GameInfo.BuildingReplaces() do
              if(replaceRow.ReplacesBuildingType == prereqRow.PrereqBuilding and IsHashInQueue(selectedCity, GameInfo.Buildings[replaceRow.CivUniqueBuildingType].Hash)) then
                prereqInQueue = true;
                break;
              end
            end

            if(prereqInQueue or IsHashInQueue(selectedCity, GameInfo.Buildings[prereqRow.PrereqBuilding].Hash)) then
              prereqInQueue = true;
              doShow = true;

              -- Check for buildings enabled by dominant religious beliefs
              if(GameInfo.Buildings[row.Hash].EnabledByReligion) then
                doShow = false;

                if ((table.count(cityData.Religions) > 1) or (cityData.PantheonBelief > -1)) then
                  local modifierIDs = {};

                  if cityData.PantheonBelief > -1 then
                    table.insert(modifierIDs, CQUI_BeliefModifiers[GameInfo.Beliefs[cityData.PantheonBelief].BeliefType].ModifierID);
                  end
                  if (table.count(cityData.Religions) > 0) then
                    for _, beliefIndex in ipairs(cityData.BeliefsOfDominantReligion) do
                      local beliefmod = CQUI_BeliefModifiers[GameInfo.Beliefs[beliefIndex].BeliefType];
                      if(beliefmod) then table.insert(modifierIDs, beliefmod.ModifierID); end
                    end
                  end

                  if(#modifierIDs > 0) then
                    for i=#modifierIDs, 1, -1 do
                      if(string.find(modifierIDs[i], "ALLOW_")) then
                        modifierIDs[i] = string.gsub(modifierIDs[i], "ALLOW", "BUILDING");
                        if(row.BuildingType == string.gsub(modifierIDs[i], "ALLOW", "BUILDING")) then
                          doShow = true;
                        end
                      end
                    end
                  end
                end
              end
              break;
            end

            if(not prereqInQueue) then doShow = false; end
            
          end
        end

        local civTypeName = PlayerConfigurations[playerID]:GetCivilizationTypeName();

        -- Check for unique buildings
        for replaceRow in GameInfo.BuildingReplaces() do
          if(replaceRow.CivUniqueBuildingType == row.BuildingType) then
            local traitName = "TRAIT_CIVILIZATION_" .. row.BuildingType;
            local isCorrectCiv = false;

            for traitRow in GameInfo.CivilizationTraits() do
              if(traitRow.TraitType == traitName and traitRow.CivilizationType == civTypeName) then
                isCorrectCiv = true;
                break;
              end
            end

            if(not isCorrectCiv) then doShow = false; end
          end

          if(replaceRow.ReplacesBuildingType == row.BuildingType) then
            local traitName = "TRAIT_CIVILIZATION_" .. replaceRow.CivUniqueBuildingType;
            local isCorrectCiv = false;

            for traitRow in GameInfo.CivilizationTraits() do
              if(traitRow.TraitType == traitName and traitRow.CivilizationType == civTypeName) then
                isCorrectCiv = true;
                break;
              end
            end

            if(isCorrectCiv) then doShow = false; end
          end
        end

        -- Check for river adjacency requirement
        if (row.RequiresAdjacentRiver and not cityPlot:IsRiver()) then
          doShow = false;
        end

        -- Check for wall obsolescence
        -- CQUI change: checks if the civil engineering civic exists at all before checking against it. We assume that walls never become obsolete if the civil engineering tech doesn't exist
        if(row.OuterDefenseHitPoints and GameInfo.Civics["CIVIC_CIVIL_ENGINEERING"] and pPlayer:GetCulture():HasCivic(GameInfo.Civics["CIVIC_CIVIL_ENGINEERING"].Index)) then
          doShow = false;
        end

        -- Check for internal only buildings
        if(row.InternalOnly) then doShow = false end

        -- AZURENCY : update from original kblease/ProductionQueue repo
        -- Check that the player has a government of an adequate tier
        if(row.GovernmentTierRequirement) then
          local eSelectedPlayerGovernmentId:number = pPlayer:GetCulture():GetCurrentGovernment();
            if eSelectedPlayerGovernmentId ~= -1 then
              local selectedPlayerGovernment = GameInfo.Governments[eSelectedPlayerGovernmentId];
              if(selectedPlayerGovernment.Tier) then
                local eSelectedPlayerGovernmentTier:number = tonumber(string.sub(selectedPlayerGovernment.Tier, 5));
                local buildingGovernmentTierRequirement:number = tonumber(string.sub(row.GovernmentTierRequirement, 5));

                if(eSelectedPlayerGovernmentTier < buildingGovernmentTierRequirement) then
                  doShow = false;
                end
              else
                doShow = false;
              end
            else
              doShow = false;
          end
        end

        -- Check if it's been built already
        if(hasPrereqTech and hasPrereqCivic and isPrereqDistrictInQueue and doShow) then
          for _, district in ipairs(cityData.BuildingsAndDistricts) do
            if district.isBuilt then
              local match = false;

              for _,building in ipairs(district.Buildings) do
                if(building.Name == Locale.Lookup(row.Name)) then
                  if(building.isBuilt and not building.isPillaged) then
                    doShow = false;
                  else
                    doShow = true;
                  end

                  match = true;
                  break;
                end
              end

              if(match) then break; end
            end
          end
        else
          doShow = false;
        end
      end

      if ( not row.MustPurchase or cityBuildings:IsPillaged(row.Hash) ) and ( buildQueue:CanProduce( row.Hash, true ) or (doShow and not row.IsWonder) ) then
        local isCanStart, results      = buildQueue:CanProduce( row.Hash, false, true );
        local isDisabled      :boolean = false; --not isCanStart;

        -- AZURENCY : check if the building is occupied by an enemy
        if(not isCanStart and results) then
          local pFailureReasons = results[CityCommandResults.FAILURE_REASONS];
          if pFailureReasons ~= nil and table.count( pFailureReasons ) > 0 then
            for i,v in pairs(pFailureReasons) do
              if(Locale.Lookup("LOC_BUILDING_CONSTRUCT_IS_OCCUPIED") == v) then
                disabledTooltip = Locale.Lookup("LOC_BUILDING_CONSTRUCT_IS_OCCUPIED");
              end
            end
          end
        end

        if(row.IsWonder or not doShow) then
          isDisabled = not isCanStart;
        end

        if(row.IsWonder and IsHashInQueue(selectedCity, row.Hash)) then
          isDisabled = true
        end

        local allReasons       :string = ComposeFailureReasonStrings( isDisabled, results );
        local sToolTip         :string = ToolTipHelper.GetBuildingToolTip( row.Hash, playerID, selectedCity ) .. allReasons;

        local iProductionCost   :number = buildQueue:GetBuildingCost( row.Index );
        local iProductionProgress :number = buildQueue:GetBuildingProgress( row.Index );

        if(disabledTooltip) then
          isDisabled = true;
          if(not string.find(sToolTip, "COLOR:Red")) then
            sToolTip = sToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. disabledTooltip .. "[ENDCOLOR]";
          end
        end

        sToolTip = sToolTip .. ComposeProductionCostString( iProductionProgress, iProductionCost );

        local iPrereqDistrict = "";
        if row.PrereqDistrict ~= nil then
          iPrereqDistrict = row.PrereqDistrict;
        end

        table.insert( new_data.BuildingItems, {
          Type      = row.BuildingType,
          Name      = row.Name,
          ToolTip     = sToolTip,
          Hash      = row.Hash,
          Kind      = row.Kind,
          TurnsLeft   = buildQueue:GetTurnsLeft( row.Hash ),
          Disabled    = isDisabled,
          Repair      = cityBuildings:IsPillaged( row.Hash ),
          Cost      = iProductionCost,
          Progress    = iProductionProgress,
          IsWonder    = row.IsWonder,
          PrereqDistrict  = iPrereqDistrict }
        );
      end

      -- Can it be purchased with gold?
      if row.PurchaseYield == "YIELD_GOLD" then
        local isAllowed, kBldg = ComposeBldgForPurchase( row, selectedCity, "YIELD_GOLD", playerTreasury, "LOC_BUILDING_INSUFFICIENT_FUNDS" );
        if isAllowed then
          table.insert( new_data.BuildingPurchases, kBldg );
        end
      end
      -- Can it be purchased with faith?
      if row.PurchaseYield == "YIELD_FAITH" or cityGold:IsBuildingFaithPurchaseEnabled( row.Hash ) then
        local isAllowed, kBldg = ComposeBldgForPurchase( row, selectedCity, "YIELD_FAITH", playerReligion, "LOC_BUILDING_INSUFFICIENT_FAITH" );
        if isAllowed then
          table.insert( new_data.BuildingPurchases, kBldg );
        end
      end
    end

    for row in GameInfo.Units() do
      if row.Hash == currentProductionHash then
        new_data.CurrentProduction = row.Name;
        new_data.CurrentProductionType = row.UnitType;
      end
      -- Can it be built normally?
      if buildQueue:CanProduce( row.Hash, true ) then
        local isCanProduceExclusion, results   = buildQueue:CanProduce( row.Hash, false, true );
        local isDisabled        :boolean = not isCanProduceExclusion;
        local sAllReasons        :string = ComposeFailureReasonStrings( isDisabled, results );
        local sToolTip           :string = ToolTipHelper.GetUnitToolTip( row.Hash ) .. sAllReasons;

        local nProductionCost   :number = buildQueue:GetUnitCost( row.Index );
        local nProductionProgress :number = buildQueue:GetUnitProgress( row.Index );
        sToolTip = sToolTip .. ComposeProductionCostString( nProductionProgress, nProductionCost );

        local kUnit :table = {
          Type      = row.UnitType,
          Name      = row.Name,
          ToolTip     = sToolTip,
          Hash      = row.Hash,
          Kind      = row.Kind,
          TurnsLeft   = buildQueue:GetTurnsLeft( row.Hash ),
          Disabled    = isDisabled,
          Civilian    = row.FormationClass == "FORMATION_CLASS_CIVILIAN",
          Cost      = nProductionCost,
          MustPurchase = row.MustPurchase,
          Progress    = nProductionProgress,
          Corps     = false,
          CorpsCost   = 0,
          CorpsTurnsLeft  = 1,
          CorpsTooltip  = "",
          CorpsName   = "",
          Army      = false,
          ArmyCost    = 0,
          ArmyTurnsLeft = 1,
          ArmyTooltip   = "",
          ArmyName    = "",
          ReligiousStrength	= row.ReligiousStrength
        };

        -- Should we present options for building Corps or Army versions?
        if results ~= nil then
          if results[CityOperationResults.CAN_TRAIN_CORPS] then
            kUnit.Corps     = true;
            kUnit.CorpsCost   = buildQueue:GetUnitCorpsCost( row.Index );
            kUnit.CorpsTurnsLeft  = buildQueue:GetTurnsLeft( row.Hash, MilitaryFormationTypes.CORPS_MILITARY_FORMATION );
            kUnit.CorpsTooltip, kUnit.CorpsName = ComposeUnitCorpsStrings( row, nProductionProgress, buildQueue );
          end
          if results[CityOperationResults.CAN_TRAIN_ARMY] then
            kUnit.Army      = true;
            kUnit.ArmyCost    = buildQueue:GetUnitArmyCost( row.Index );
            kUnit.ArmyTurnsLeft = buildQueue:GetTurnsLeft( row.Hash, MilitaryFormationTypes.ARMY_MILITARY_FORMATION );
            kUnit.ArmyTooltip, kUnit.ArmyName = ComposeUnitArmyStrings( row, nProductionProgress, buildQueue );
          end
        end

        table.insert(new_data.UnitItems, kUnit );
      end

      -- Can it be purchased with gold?
      if row.PurchaseYield == "YIELD_GOLD" then
        local isAllowed, kUnit = ComposeUnitForPurchase( row, selectedCity, "YIELD_GOLD", playerTreasury, "LOC_BUILDING_INSUFFICIENT_FUNDS" );
        if isAllowed then
          table.insert( new_data.UnitPurchases, kUnit );
        end
      end
      -- Can it be purchased with faith?
      if row.PurchaseYield == "YIELD_FAITH" or cityGold:IsUnitFaithPurchaseEnabled( row.Hash ) then
        local isAllowed, kUnit = ComposeUnitForPurchase( row, selectedCity, "YIELD_FAITH", playerReligion, "LOC_BUILDING_INSUFFICIENT_FAITH" );
        if isAllowed then
          table.insert( new_data.UnitPurchases, kUnit );
        end
      end
    end

    for row in GameInfo.Projects() do
      if row.Hash == currentProductionHash then
        new_data.CurrentProduction = row.Name;
        new_data.CurrentProductionType = row.ProjectType;
      end

      if buildQueue:CanProduce( row.Hash, true ) and not (row.MaxPlayerInstances and IsHashInAnyQueue(row.Hash)) then
        local isCanProduceExclusion, results = buildQueue:CanProduce( row.Hash, false, true );
        local isDisabled      :boolean = not isCanProduceExclusion;


        local allReasons    :string = ComposeFailureReasonStrings( isDisabled, results );
        local sToolTip      :string = ToolTipHelper.GetProjectToolTip( row.Hash ) .. allReasons;

        local iProductionCost   :number = buildQueue:GetProjectCost( row.Index );
        local iProductionProgress :number = buildQueue:GetProjectProgress( row.Index );
        sToolTip = sToolTip .. ComposeProductionCostString( iProductionProgress, iProductionCost );

        table.insert(new_data.ProjectItems, {
          Type      = row.ProjectType,
          Name      = row.Name,
          ToolTip     = sToolTip,
          Hash      = row.Hash,
          Kind      = row.Kind,
          TurnsLeft   = buildQueue:GetTurnsLeft( row.ProjectType ),
          Disabled    = isDisabled,
          Cost      = iProductionCost,
          Progress    = iProductionProgress
        });
      end
    end


    View(new_data);
    ResizeQueueWindow();
    SaveQueues();
  end
  end
end

-- ===========================================================================
function ShowHideDisabled()
  --Controls.HideDisabled:SetSelected(showDisabled);
  showDisabled = not showDisabled;
  Refresh();
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnCityPanelChooseProduction()
  if (ContextPtr:IsHidden()) then
    Refresh();
  end
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnNotificationPanelChooseProduction()
    if ContextPtr:IsHidden() then
      Open();

  --else                                --TESTING TO SEE IF THIS FIXES OUR TUTORIAL BUG.
  --  if Controls.PauseDismissWindow:IsStopped() then
  --    Close();
  --  else
  --    Controls.PauseDismissWindow:Stop();
  --    Open();
  --  end
  end
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnCityPanelChoosePurchase()
  if (ContextPtr:IsHidden()) then
    Refresh();
  end
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnCityPanelChoosePurchaseFaith()
  if (ContextPtr:IsHidden()) then
    Refresh();
  end
end

-- ===========================================================================
--  LUA Event
--  Outside source is signaling production should be closed if open.
-- ===========================================================================
function OnProductionClose()
  if not ContextPtr:IsHidden() then
    Close();
  end
end

-- ===========================================================================
--  LUA Event
--  Production opened from city banner (anchored to world view)
-- ===========================================================================
function OnCityBannerManagerProductionToggle()
  m_isQueueMode = false;
  if(ContextPtr:IsHidden()) then
    Open();
  else
  end
end

-- ===========================================================================
--  LUA Event
--  Production opened from city information panel
-- ===========================================================================
function OnCityPanelProductionOpen()
  m_isQueueMode = false;
  Open();
end

-- ===========================================================================
--  LUA Event
--  Production opened from city information panel - Purchase with faith check
-- ===========================================================================
function OnCityPanelPurchaseFaithOpen()
  m_isQueueMode = false;
  Open();
end

-- ===========================================================================
--  LUA Event
--  Production opened from city information panel - Purchase with gold check
-- ===========================================================================
function OnCityPanelPurchaseGoldOpen()
  m_isQueueMode = false;
  Open();
end
-- ===========================================================================
--  LUA Event
--  Production opened from a placement
-- ===========================================================================
function OnStrategicViewMapPlacementProductionOpen()
  m_isQueueMode = false;
  Open();
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnTutorialProductionOpen()
  m_isQueueMode = false;
  Open();
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnProductionOpenForQueue()
  m_isQueueMode = true;
  Open();
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnCityPanelPurchasePlot()
  Close();
end

-- ===========================================================================
--  LUA Event
--  Set cached values back after a hotload.
-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
  if context ~= RELOAD_CACHE_ID then return; end
  m_isQueueMode = contextTable["m_isQueueMode"];
  local isHidden:boolean = contextTable["isHidden"];
  if not isHidden then
    Refresh();
  end
end

-- ===========================================================================
--  Keyboard INPUT UP Handler
-- ===========================================================================
function KeyUpHandler( key:number )
  if (key == Keys.VK_ESCAPE) then Close(); return true; end
  if (key == Keys.VK_CONTROL) then m_isCONTROLpressed = false; return true; end
  return false;
end

-- ===========================================================================
--  Keyboard INPUT Down Handler
-- ===========================================================================
function KeyDownHandler( key:number )
  if (key == Keys.VK_CONTROL) then m_isCONTROLpressed = true; return true; end
  return false;
end

-- ===========================================================================
--  UI Event
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
  local uiMsg = pInputStruct:GetMessageType();
  if uiMsg == KeyEvents.KeyUp then return KeyUpHandler( pInputStruct:GetKey() ); end;
  if uiMsg == KeyEvents.KeyDown then return KeyDownHandler( pInputStruct:GetKey() ); end;
  return false;
end

-- ===========================================================================
--  UI Event
-- ===========================================================================
function OnInit( isReload:boolean )
  if isReload then
    LuaEvents.GameDebug_GetValues( RELOAD_CACHE_ID );
  end
end

-- ===========================================================================
--  UI Event
-- ===========================================================================
function OnShutdown()
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID,  "m_isQueueMode", m_isQueueMode );
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID,  "prodQueue", prodQueue );
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID,  "isHidden",    ContextPtr:IsHidden() );
end


-- ===========================================================================
-- ===========================================================================
function Resize()
  --local contentSize = (m_maxProductionSize > m_maxPurchaseSize) and m_maxProductionSize or m_maxPurchaseSize;
  --contentSize = contentSize + WINDOW_HEADER_Y;
  --local w,h = UIManager:GetScreenSizeVal();
  --local maxAllowable = h - Controls.Window:GetOffsetY() - TOPBAR_Y;
  --local panelSizeY = (contentSize < maxAllowable) and contentSize or maxAllowable;
  --Controls.Window:SetSizeY(panelSizeY);
  --Controls.ProductionListScroll:SetSizeY(panelSizeY-Controls.WindowContent:GetOffsetY());
  --Controls.PurchaseListScroll:SetSizeY(panelSizeY-Controls.WindowContent:GetOffsetY());
  --Controls.DropShadow:SetSizeY(panelSizeY+100);
end

-- ===========================================================================
-- ===========================================================================
function CreateCorrectTabs()
  local MAX_TAB_LABEL_WIDTH = 273;
  local productionLabelX = Controls.ProductionTab:GetTextControl():GetSizeX();
  local purchaseLabelX = Controls.PurchaseTab:GetTextControl():GetSizeX();
  local purchaseFaithLabelX = Controls.PurchaseFaithTab:GetTextControl():GetSizeX();
  local tabAnimControl;
  local tabArrowControl;
  local tabSizeX;
  local tabSizeY;
  Controls.MiniProductionTab:SetHide(true);
  Controls.MiniPurchaseTab:SetHide(true);
  Controls.MiniPurchaseFaithTab:SetHide(true);
  Controls.ProductionTab:SetHide(true);
  Controls.PurchaseTab:SetHide(true);
  Controls.PurchaseFaithTab:SetHide(true);
  Controls.MiniTabAnim:SetHide(true);
  Controls.MiniTabArrow:SetHide(true);
  Controls.TabAnim:SetHide(true);
  Controls.TabArrow:SetHide(true);
  
  local labelWidth = productionLabelX + purchaseLabelX;
  if GameCapabilities.HasCapability("CAPABILITY_FAITH") then 
    labelWidth = labelWidth + purchaseFaithLabelX;
  end
  if(labelWidth > MAX_TAB_LABEL_WIDTH) then
    tabSizeX = 44;
    tabSizeY = 44;
    Controls.MiniProductionTab:SetHide(false);
    Controls.MiniPurchaseTab:SetHide(false);
    Controls.MiniPurchaseFaithTab:SetHide(false);
    Controls.MiniTabAnim:SetHide(false);
    Controls.MiniTabArrow:SetHide(false);
    m_productionTab = Controls.MiniProductionTab;
    m_purchaseTab = Controls.MiniPurchaseTab;
    m_faithTab    = Controls.MiniPurchaseFaithTab;
    tabAnimControl  = Controls.MiniTabAnim;
    tabArrowControl = Controls.MiniTabArrow;
  else
    tabSizeX = 42;
    tabSizeY = 34;
    Controls.ProductionTab:SetHide(false);
    Controls.PurchaseTab:SetHide(false);
    Controls.PurchaseFaithTab:SetHide(false);
    Controls.TabAnim:SetHide(false);
    Controls.TabArrow:SetHide(false);
    m_productionTab = Controls.ProductionTab;
    m_purchaseTab = Controls.PurchaseTab;
    m_faithTab    = Controls.PurchaseFaithTab;
    tabAnimControl  = Controls.TabAnim;
    tabArrowControl = Controls.TabArrow;
  end
end


--- =========================================================================================================
--  ====================================== PRODUCTION QUEUE MOD FUNCTIONS ===================================
--- =========================================================================================================

--- =======================================================================================================
--  === Production event handlers
--- =======================================================================================================

--- ===========================================================================
--  Fires when a city's current production changes
--- ===========================================================================
function OnCityProductionChanged(playerID:number, cityID:number)
  local localPlayerID = Game.GetLocalPlayer();

  if (not CQUI_ProductionQueue) then --If production queue is disabled, clear out the queue
    ResetSelectedCityQueue();
  else
    if (playerID == localPlayerID) then
    Refresh();
  end
  end
  -- CQUI_previousProductionHash[cityID] = CQUI_currentProductionHash[cityID];
  -- GameConfiguration.SetValue("CQUI_previousProductionHash" .. cityID, CQUI_previousProductionHash[cityID]);
end

function OnCityProductionUpdated( ownerPlayerID:number, cityID:number, eProductionType, eProductionObject)
  if(ownerPlayerID ~= Game.GetLocalPlayer()) then return end
  lastProductionCompletePerCity[cityID] = nil;
end

--- ===========================================================================
--  Fires when a city's production is completed
--  Note: This seems to sometimes fire more than once for a turn
--- ===========================================================================
function OnCityProductionCompleted(playerID, cityID, orderType, unitType, canceled, typeModifier)
  if (playerID ~= Game.GetLocalPlayer()) then return end;

  local pPlayer = Players[ playerID ];
  if (pPlayer == nil) then return end;

  local pCity = pPlayer:GetCities():FindID(cityID);
  if (pCity == nil) then return end;

  local currentTurn = Game.GetCurrentGameTurn();

  local productionQueueTableKey = FindProductionQueueKey(cityID, pCity:GetOwner())

  -- Only one item can be produced per turn per city
  if(lastProductionCompletePerCity[cityID] and lastProductionCompletePerCity[cityID] == currentTurn) then
    return;
  end

  if(prodQueue[productionQueueTableKey] and prodQueue[productionQueueTableKey][1]) then
    -- Check that the production is actually completed
    local productionInfo = GetProductionInfoOfCity(pCity, prodQueue[productionQueueTableKey][1].entry.Hash);
    local pDistricts = pCity:GetDistricts();
    local pBuildings = pCity:GetBuildings();
    local isComplete = false;

    if(prodQueue[productionQueueTableKey][1].type == PRODUCTION_TYPE.BUILDING or prodQueue[productionQueueTableKey][1].type == PRODUCTION_TYPE.PLACED) then
      if(GameInfo.Districts[prodQueue[productionQueueTableKey][1].entry.Hash] and pDistricts:HasDistrict(GameInfo.Districts[prodQueue[productionQueueTableKey][1].entry.Hash].Index, true)) then
        isComplete = true;
      elseif(GameInfo.Buildings[prodQueue[productionQueueTableKey][1].entry.Hash] and pBuildings:HasBuilding(GameInfo.Buildings[prodQueue[productionQueueTableKey][1].entry.Hash].Index)) then
        -- AZURENCY : Fix faith buying with repaired item in queue
        if not pBuildings:IsPillaged(prodQueue[productionQueueTableKey][1].entry.Hash) then
          isComplete = true;
        end
      elseif(productionInfo.PercentComplete >= 1) then
        isComplete = true;
      end

      if(not isComplete) then
        return;
      end
    end

    -- PQ: Experimental
    local productionType = prodQueue[productionQueueTableKey][1].type;
    if(orderType == 0) then
      if(productionType == PRODUCTION_TYPE.UNIT or productionType == PRODUCTION_TYPE.CORPS or productionType == PRODUCTION_TYPE.ARMY) then
        if(GameInfo.Units[prodQueue[productionQueueTableKey][1].entry.Hash].Index == unitType) then
          isComplete = true;
        end
      end
    elseif(orderType == 1) then
      -- Building/wonder
      if(productionType == PRODUCTION_TYPE.BUILDING or productionType == PRODUCTION_TYPE.PLACED) then
        local buildingInfo = GameInfo.Buildings[prodQueue[productionQueueTableKey][1].entry.Hash];
        if(buildingInfo and buildingInfo.Index == unitType) then
          isComplete = true;
        end
      end

        -- Check if this building is in our queue at all
      if(not isComplete and IsHashInQueue(pCity, GameInfo.Buildings[unitType].Hash)) then
        local removeIndex = GetIndexOfHashInQueue(pCity, GameInfo.Buildings[unitType].Hash);
        RemoveFromQueue(pCity, removeIndex, true);

        if(removeIndex == 1) then
          BuildFirstQueued(pCity);
        else
          Refresh();
        end

        SaveQueues();
        return;
      end
    elseif(orderType == 2) then
      -- District
      if(productionType == PRODUCTION_TYPE.PLACED) then
        local districtInfo = GameInfo.Districts[prodQueue[productionQueueTableKey][1].entry.Hash];
        if(districtInfo and districtInfo.Index == unitType) then
          isComplete = true;
        end
      end
    elseif(orderType == 3) then
      -- Project
      if(productionType == PRODUCTION_TYPE.PROJECT) then
        local projectInfo = GameInfo.Projects[prodQueue[productionQueueTableKey][1].entry.Hash];
        if(projectInfo and projectInfo.Index == unitType) then
          isComplete = true;
        end
      end
    end

    if(not isComplete) then
      print("ERROR : Non matching orderType and/or unitType");
      Refresh();
      return;
    end

    table.remove(prodQueue[productionQueueTableKey], 1);
    if(#prodQueue[productionQueueTableKey] > 0) then
      BuildFirstQueued(pCity);
    end

    lastProductionCompletePerCity[cityID] = currentTurn;
    SaveQueues();
  end
end


--- =======================================================================================================
--  === Load/Save
--- =======================================================================================================

--- ==========================================================================
--  Updates the PlayerConfiguration with all ProductionQueue data
--- ==========================================================================
function SaveQueues()
  PlayerConfigurations[Game.GetLocalPlayer()]:SetValue("ZenProductionQueue", DataDumper(prodQueue, "prodQueue"));
end

--- ==========================================================================
--  Finds production queue key based on player and current city id
--  Desirable improvement : Refactor to use local player ID as a key to the table of cities instead
--                          of mixing all cities in one queue.
--                          At the moment only allow 1000 cities per active local player.
--- ==========================================================================
function FindProductionQueueKey(cityID:number, localPlayerID:number)
  return cityID * 1000 + localPlayerID;
end

--- ==========================================================================
--  Loads ProductionQueue data from PlayerConfiguration, and populates the
--  queue with current production information if saved info not present
--- ==========================================================================
function LoadQueues()
  local localPlayerID = Game.GetLocalPlayer();
  if(PlayerConfigurations[localPlayerID]:GetValue("ZenProductionQueue") ~= nil) then
    loadstring(PlayerConfigurations[localPlayerID]:GetValue("ZenProductionQueue"))();
  end

  if(not prodQueue) then
    prodQueue = {};
  end

  local player = Players[localPlayerID];
  local cities = player:GetCities();

  for j, city in cities:Members() do
    local cityID = city:GetID();
    local buildQueue = city:GetBuildQueue();
    local currentProductionHash = buildQueue:GetCurrentProductionTypeHash();
    local plotID = -1;
  local productionQueueTableKey = FindProductionQueueKey(cityID, city:GetOwner());

    if(not prodQueue[productionQueueTableKey]) then
      prodQueue[productionQueueTableKey] = {};
    end

    if(not prodQueue[productionQueueTableKey][1] and currentProductionHash ~= 0) then
      -- Determine the type of the item
      local currentType = 0;
      local productionInfo = GetProductionInfoOfCity(city, currentProductionHash);
      productionInfo.Hash = currentProductionHash;

      if(productionInfo.Type == "UNIT") then
        currentType = buildQueue:GetCurrentProductionTypeModifier() + 2;
      elseif(productionInfo.Type == "BUILDING") then
        if(GameInfo.Buildings[currentProductionHash].MaxWorldInstances == 1) then
          currentType = PRODUCTION_TYPE.PLACED;

          local pCityBuildings  :table = city:GetBuildings();
          local kCityPlots    :table = Map.GetCityPlots():GetPurchasedPlots( city );
          if (kCityPlots ~= nil) then
            for _,plot in pairs(kCityPlots) do
              local kPlot:table =  Map.GetPlotByIndex(plot);
              local wonderType = kPlot:GetWonderType();
              if(wonderType ~= -1 and GameInfo.Buildings[wonderType].BuildingType == GameInfo.Buildings[currentProductionHash].BuildingType) then
                plotID = plot;
              end
            end
          end
        else
          currentType = PRODUCTION_TYPE.BUILDING;
        end
      elseif(productionInfo.Type == "DISTRICT") then
        currentType = PRODUCTION_TYPE.PLACED;
      elseif(productionInfo.Type == "PROJECT") then
        currentType = PRODUCTION_TYPE.PROJECT;
      end

      if(currentType == 0) then
        print("ERROR : Could not find production type for hash: " .. currentProductionHash);
      end

      prodQueue[productionQueueTableKey][1] = {
        entry=productionInfo,
        type=currentType,
        plotID=plotID
      }

    elseif(currentProductionHash == 0) then
    end
  end

  for building in GameInfo.MutuallyExclusiveBuildings() do
    mutuallyExclusiveBuildings[building.Building] = 1;
  end
end


--- =======================================================================================================
--  === Queue information
--- =======================================================================================================

--- ===========================================================================
--  Checks if there is a specific building hash in a city's Production Queue
--- ===========================================================================
function IsBuildingInQueue(city, buildingHash)
  local cityID = city:GetID();
  local productionQueueTableKey = FindProductionQueueKey(cityID, city:GetOwner())

  if(prodQueue and #prodQueue[productionQueueTableKey] > 0) then
    for _, qi in pairs(prodQueue[productionQueueTableKey]) do
      if(qi.entry and qi.entry.Hash == buildingHash) then
        if(qi.type == PRODUCTION_TYPE.BUILDING or qi.type == PRODUCTION_TYPE.PLACED) then
          return true;
        end
      end
    end
  end
  return false;
end

--- ===========================================================================
--  Checks if there is a specific wonder hash in all Production Queues
--- ===========================================================================
function IsWonderInQueue(wonderHash)
  for _,city in pairs(prodQueue) do
    for _, qi in pairs(city) do
      if(qi.entry and qi.entry.Hash == wonderHash) then
        if(qi.type == PRODUCTION_TYPE.PLACED) then
          return true;
        end
      end
    end
  end
  return false;
end

--- ===========================================================================
--  Checks if there is a specific hash in all Production Queues
--- ===========================================================================
function IsHashInAnyQueue(hash)
  for _,city in pairs(prodQueue) do
    for _, qi in pairs(city) do
      if(qi.entry and qi.entry.Hash == hash) then
        return true;
      end
    end
  end
  return false;
end

--- ===========================================================================
--  Checks if there is a specific item hash in a city's Production Queue
--- ===========================================================================
function IsHashInQueue(city, hash)
  local cityID = city:GetID();
  local productionQueueTableKey = FindProductionQueueKey(cityID, city:GetOwner())

  if(prodQueue and #prodQueue[productionQueueTableKey] > 0) then
    for i, qi in pairs(prodQueue[productionQueueTableKey]) do
      if(qi.entry and qi.entry.Hash == hash) then
        return true;
      end
    end
  end
  return false;
end

--- ===========================================================================
--  Returns the first instance of a hash in a city's Production Queue
--- ===========================================================================
function GetIndexOfHashInQueue(city, hash)
  local cityID = city:GetID();
  local productionQueueTableKey = FindProductionQueueKey(cityID, city:GetOwner())

  if(prodQueue and #prodQueue[productionQueueTableKey] > 0) then
    for i, qi in pairs(prodQueue[productionQueueTableKey]) do
      if(qi.entry and qi.entry.Hash == hash) then
        return i;
      end
    end
  end
  return nil;
end

--- ===========================================================================
--  Get the total number of districts (requiring population)
--  in a city's Production Queue still requiring placement
--- ===========================================================================
function GetNumDistrictsInCityQueue(city)
  local numDistricts = 0;
  local cityID = city:GetID();
  local pBuildQueue = city:GetBuildQueue();
  local productionQueueTableKey = FindProductionQueueKey(cityID, city:GetOwner())

  if(#prodQueue[productionQueueTableKey] > 0) then
    for _,qi in pairs(prodQueue[productionQueueTableKey]) do
      if(GameInfo.Districts[qi.entry.Hash] and GameInfo.Districts[qi.entry.Hash].RequiresPopulation) then
        if (not pBuildQueue:HasBeenPlaced(qi.entry.Hash)) then
          numDistricts = numDistricts + 1;
        end
      end
    end
  end

  return numDistricts;
end

--- =============================================================================
--  [Doing it this way is ridiculous and hacky but I am tired; Please forgive me]
--  Checks the Production Queue for matching reserved plots
--- =============================================================================
GameInfo.Districts['DISTRICT_CITY_CENTER'].IsPlotValid = function(pCity, plotID)
  local cityID = pCity:GetID();
  local productionQueueTableKey = FindProductionQueueKey(cityID, pCity:GetOwner())

  if(#prodQueue[productionQueueTableKey] > 0) then
    for j,item in ipairs(prodQueue[productionQueueTableKey]) do
      if(item.plotID == plotID) then
        return false;
      end
    end
  end
  return true;
end


--- =======================================================================================================
--  === Drag and Drop
--- =======================================================================================================

--- ==========================================================================
--  Creates a valid drop area for the queue item drag and drop system
--- ==========================================================================
function BuildProductionQueueDropArea( control:table, num:number, label:string )
  AddDropArea( control, num, m_kProductionQueueDropAreas );
end

--- ===========================================================================
--  Fires when picking up an item in the Production Queue
--- ===========================================================================
function OnDownInQueue( dragStruct:table, queueListing:table, index:number )
  UI.PlaySound("Play_UI_Click");
end

--- ===========================================================================
--  Fires when dropping an item in the Production Queue
--- ===========================================================================
function OnDropInQueue( dragStruct:table, queueListing:table, index:number )
  local dragControl:table     = dragStruct:GetControl();
  local x:number,y:number     = dragControl:GetScreenOffset();
  local width:number,height:number= dragControl:GetSizeVal();
  local dropArea:DropAreaStruct = GetDropArea(x,y,width,height,m_kProductionQueueDropAreas);

  if dropArea ~= nil and dropArea.id ~= index then
    local city = UI.GetHeadSelectedCity();
    local cityID = city:GetID();

    MoveQueueIndex(city, index, dropArea.id);
    dragControl:StopSnapBack();
    if(index == 1 or dropArea.id == 1) then
      BuildFirstQueued(city);
    else
      Refresh();
    end
  end
end

--- =======================================================================================================
--  === Queueing/Building
--- =======================================================================================================

--- ==========================================================================
--  Adds unit of given type to the Production Queue and builds it if requested
--- ==========================================================================
function QueueUnitOfType(city, unitEntry, unitType, skipToFront)
  local cityID = city:GetID();
  local productionQueueTableKey = FindProductionQueueKey(cityID, city:GetOwner())
  local index = 1;

  if(not prodQueue[productionQueueTableKey]) then prodQueue[productionQueueTableKey] = {}; end
  if(not skipToFront) then index = #prodQueue[productionQueueTableKey] + 1; end

  table.insert(prodQueue[productionQueueTableKey], index, {
    entry=unitEntry,
    type=unitType,
    plotID=-1
    });

  if(#prodQueue[productionQueueTableKey] == 1 or skipToFront) then
    BuildFirstQueued(city);
  else
    Refresh();
  end

    UI.PlaySound("Confirm_Production");
end

--- ==========================================================================
--  Adds unit to the Production Queue and builds if requested
--- ==========================================================================
function QueueUnit(city, unitEntry, skipToFront)
  QueueUnitOfType(city, unitEntry, PRODUCTION_TYPE.UNIT, skipToFront);
end

--- ==========================================================================
--  Adds corps to the Production Queue and builds if requested
--- ==========================================================================
function QueueUnitCorps(city, unitEntry, skipToFront)
  QueueUnitOfType(city, unitEntry, PRODUCTION_TYPE.CORPS, skipToFront);
end

--- ==========================================================================
--  Adds army to the Production Queue and builds if requested
--- ==========================================================================
function QueueUnitArmy(city, unitEntry, skipToFront)
  QueueUnitOfType(city, unitEntry, PRODUCTION_TYPE.ARMY, skipToFront);
end

--- ==========================================================================
--  Adds building to the Production Queue and builds if requested
--- ==========================================================================
function QueueBuilding(city, buildingEntry, skipToFront)
  local building      :table    = GameInfo.Buildings[buildingEntry.Type];
  local bNeedsPlacement :boolean  = building.RequiresPlacement;
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

  -- UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);

  if (bNeedsPlacement) then
    local tParameters = {};
    tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = buildingEntry.Hash;
    tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
    UI.SetInterfaceMode(InterfaceModeTypes.BUILDING_PLACEMENT, tParameters);
  else
    local cityID = city:GetID();
  local productionQueueTableKey = FindProductionQueueKey(cityID, city:GetOwner())
    local plotID = -1;
    local buildingType = PRODUCTION_TYPE.BUILDING;

    if(not prodQueue[productionQueueTableKey]) then
      prodQueue[productionQueueTableKey] = {};
    end

    if(building.RequiresPlacement) then
      local pCityBuildings  :table = city:GetBuildings();
      local kCityPlots    :table = Map.GetCityPlots():GetPurchasedPlots( city );
      if (kCityPlots ~= nil) then
        for _,plot in pairs(kCityPlots) do
          local kPlot:table =  Map.GetPlotByIndex(plot);
          local wonderType = kPlot:GetWonderType();
          if(wonderType ~= -1 and GameInfo.Buildings[wonderType].BuildingType == building.BuildingType) then
            plotID = plot;
            buildingType = PRODUCTION_TYPE.PLACED;
          end
        end
      end
    end

    table.insert(prodQueue[productionQueueTableKey], {
      entry=buildingEntry,
      type=buildingType,
      plotID=plotID
      });

    if(skipToFront) then
      if(MoveQueueIndex(city, #prodQueue[productionQueueTableKey], 1) ~= 0) then
        Refresh();
      else
        BuildFirstQueued(city);
      end
    elseif(#prodQueue[productionQueueTableKey] == 1) then
      BuildFirstQueued(city);
    else
      Refresh();
    end

        UI.PlaySound("Confirm_Production");
  end
end

--- ==========================================================================
--  Adds district to the Production Queue and builds if requested
--- ==========================================================================
function QueueDistrict(city, districtEntry, skipToFront)
  -- UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);

  local district      :table    = GameInfo.Districts[districtEntry.Type];
  local bNeedsPlacement :boolean  = district.RequiresPlacement;
  local pBuildQueue   :table    = city:GetBuildQueue();

  if (pBuildQueue:HasBeenPlaced(districtEntry.Hash)) then
    bNeedsPlacement = false;
  end

  if (bNeedsPlacement) then
    --If we were already placing something, quickly pop into selection mode, signalling to CQUI cityview code that placement was interrupted and resetting the view
    if(UI.GetInterfaceMode() == InterfaceModeTypes.BUILDING_PLACEMENT or UI.GetInterfaceMode() == InterfaceModeTypes.DISTRICT_PLACEMENT) then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    else
      local tParameters = {};
      tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Hash;
      tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
      UI.SetInterfaceMode(InterfaceModeTypes.DISTRICT_PLACEMENT, tParameters);
    end
  else
    local tParameters = {};
    tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Hash;
    tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;

    local cityID = city:GetID();
  local productionQueueTableKey = FindProductionQueueKey(cityID, city:GetOwner());

    if(not prodQueue[productionQueueTableKey]) then
      prodQueue[productionQueueTableKey] = {};
    end

    local index = 1;
    if(not skipToFront) then index = #prodQueue[productionQueueTableKey] + 1; end

    table.insert(prodQueue[productionQueueTableKey], index, {
      entry=districtEntry,
      type=PRODUCTION_TYPE.PLACED,
      plotID=-1,
      tParameters=tParameters
      });

    if(#prodQueue[productionQueueTableKey] == 1 or skipToFront) then
      BuildFirstQueued(city);
    else
      Refresh();
    end
    UI.PlaySound("Confirm_Production");
  end
end

--- ==========================================================================
--  Adds project to the Production Queue and builds if requested
--- ==========================================================================
function QueueProject(city, projectEntry, skipToFront)
  local cityID = city:GetID();
  local productionQueueTableKey = FindProductionQueueKey(cityID, city:GetOwner());

  if(not prodQueue[productionQueueTableKey]) then
    prodQueue[productionQueueTableKey] = {};
  end

  local index = 1;
  if(not skipToFront) then index = #prodQueue[productionQueueTableKey] + 1; end

  table.insert(prodQueue[productionQueueTableKey], index, {
    entry=projectEntry,
    type=PRODUCTION_TYPE.PROJECT,
    plotID=-1
    });

  if(#prodQueue[productionQueueTableKey] == 1 or skipToFront) then
      BuildFirstQueued(city);
  else
    Refresh();
  end

    UI.PlaySound("Confirm_Production");
end

--- ===========================================================================
--  Check if removing an index would result in an empty queue
--- ===========================================================================
function CanRemoveFromQueue(city, index)
  local cityID = city:GetID();
  local productionQueueTableKey = FindProductionQueueKey(cityID, city:GetOwner());
  local totalItemsToRemove = 1;

  if(prodQueue[productionQueueTableKey] and #prodQueue[productionQueueTableKey] > 1 and prodQueue[productionQueueTableKey][index]) then
    local destIndex = MoveQueueIndex(city, index, #prodQueue[productionQueueTableKey], true);
    if(destIndex > 0) then
      totalItemsToRemove = totalItemsToRemove + 1;
      CanRemoveFromQueue(city, destIndex + 1);
    end
  end

  if(totalItemsToRemove == #prodQueue[productionQueueTableKey]) then
    return false;
  else
    return true;
  end
end

--- ===========================================================================
--  Remove a specific index from a city's Production Queue
--- ===========================================================================
function RemoveFromQueue(city, index, force)
  local cityID = city:GetID();
  local productionQueueTableKey = FindProductionQueueKey(cityID, city:GetOwner());

  if(prodQueue[productionQueueTableKey] and (#prodQueue[productionQueueTableKey] > 1 or force) and prodQueue[productionQueueTableKey][index]) then
    local destIndex = MoveQueueIndex(city, index, #prodQueue[productionQueueTableKey]);
    if(destIndex > 0) then
      -- There was a conflict
      RemoveFromQueue(city, destIndex + 1);
      table.remove(prodQueue[productionQueueTableKey], destIndex);
    else
      table.remove(prodQueue[productionQueueTableKey], #prodQueue[productionQueueTableKey]);
    end
    return true;
  end
  return false;
end

--- ==========================================================================
--  Directly requests the city to build a placed district/wonder using
--  tParameters provided from the StrategicView callback event
--- ==========================================================================
function BuildPlaced(city, tParameters)
  -- Check if we still have enough population for a district we're about to place
  local districtHash = tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE];
  if(districtHash) then
    local pCityDistricts = city:GetDistricts();
    local numDistricts = pCityDistricts:GetNumZonedDistrictsRequiringPopulation();
    local numPossibleDistricts = pCityDistricts:GetNumAllowedDistrictsRequiringPopulation();

    if(GameInfo.Districts[districtHash] and GameInfo.Districts[districtHash].RequiresPopulation and numDistricts <= numPossibleDistricts) then
      if(GetNumDistrictsInCityQueue(city) + numDistricts > numPossibleDistricts) then
        RemoveFromQueue(city, 1);
        BuildFirstQueued(city);
        return;
      end
    end
  end

  CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
end

--- ==========================================================================
--  Builds the first item in the Production Queue
--- ==========================================================================
function BuildFirstQueued(pCity)
  local cityID = pCity:GetID();
  local productionQueueTableKey = FindProductionQueueKey(cityID, pCity:GetOwner())

  if(prodQueue[productionQueueTableKey][1]) then
    if(prodQueue[productionQueueTableKey][1].type == PRODUCTION_TYPE.BUILDING) then
      BuildBuilding(pCity, prodQueue[productionQueueTableKey][1].entry);
    elseif(prodQueue[productionQueueTableKey][1].type == PRODUCTION_TYPE.UNIT) then
      BuildUnit(pCity, prodQueue[productionQueueTableKey][1].entry);
    elseif(prodQueue[productionQueueTableKey][1].type == PRODUCTION_TYPE.ARMY) then
      BuildUnitArmy(pCity, prodQueue[productionQueueTableKey][1].entry);
    elseif(prodQueue[productionQueueTableKey][1].type == PRODUCTION_TYPE.CORPS) then
      BuildUnitCorps(pCity, prodQueue[productionQueueTableKey][1].entry);
    elseif(prodQueue[productionQueueTableKey][1].type == PRODUCTION_TYPE.PLACED) then
      if(not prodQueue[productionQueueTableKey][1].tParameters) then
        if(GameInfo.Buildings[prodQueue[productionQueueTableKey][1].entry.Hash]) then
          BuildBuilding(pCity, prodQueue[productionQueueTableKey][1].entry);
        else
          ZoneDistrict(pCity, prodQueue[productionQueueTableKey][1].entry);
        end
      else
        BuildPlaced(pCity, prodQueue[productionQueueTableKey][1].tParameters);
      end
    elseif(prodQueue[productionQueueTableKey][1].type == PRODUCTION_TYPE.PROJECT) then
      AdvanceProject(pCity, prodQueue[productionQueueTableKey][1].entry);
    end
  else
    Refresh();
  end
end

--- ============================================================================
--  Lua Event
--  This is fired when a district or wonder plot has been selected and confirmed
--- ============================================================================
function OnStrategicViewMapPlacementProductionClose(tProductionQueueParameters)
  local cityID = tProductionQueueParameters.pSelectedCity:GetID();
  local entry = GetProductionInfoOfCity(tProductionQueueParameters.pSelectedCity, tProductionQueueParameters.buildingHash);
  entry.Hash = tProductionQueueParameters.buildingHash;
  local productionQueueTableKey = FindProductionQueueKey(cityID, tProductionQueueParameters.pSelectedCity:GetOwner())

  if(not prodQueue[productionQueueTableKey]) then prodQueue[productionQueueTableKey] = {}; end

  local index = 1;
  if(not nextDistrictSkipToFront) then index = #prodQueue[productionQueueTableKey] + 1; end

  table.insert(prodQueue[productionQueueTableKey], index, {
    entry=entry,
    type=PRODUCTION_TYPE.PLACED,
    plotID=tProductionQueueParameters.plotId,
    tParameters=tProductionQueueParameters.tParameters
    });

  if(nextDistrictSkipToFront or #prodQueue[productionQueueTableKey] == 1) then BuildFirstQueued(tProductionQueueParameters.pSelectedCity); end
  Refresh();
  UI.PlaySound("Confirm_Production");
end

--- ===========================================================================
--  Move a city's queue item from one index to another
--- ===========================================================================
function MoveQueueIndex(city, sourceIndex, destIndex, noMove)
  local cityID = city:GetID();
  local direction = -1;
  local actualDest = 0;
  local productionQueueTableKey = FindProductionQueueKey(cityID, city:GetOwner())

  local sourceInfo = prodQueue[productionQueueTableKey][sourceIndex];

  if(sourceIndex < destIndex) then direction = 1; end
  for i=sourceIndex, math.max(destIndex-direction, 1), direction do
    -- Each time we swap, we need to check that there isn't a prereq that would break
    if(sourceInfo.type == PRODUCTION_TYPE.BUILDING and prodQueue[productionQueueTableKey][i+direction].type == PRODUCTION_TYPE.PLACED) then
      local buildingInfo = GameInfo.Buildings[sourceInfo.entry.Hash];
      if(buildingInfo and buildingInfo.PrereqDistrict) then
        local districtInfo = GameInfo.Districts[prodQueue[productionQueueTableKey][i+direction].entry.Hash];
        if(districtInfo and (districtInfo.DistrictType == buildingInfo.PrereqDistrict or (GameInfo.DistrictReplaces[prodQueue[productionQueueTableKey][i+direction].entry.Hash] and GameInfo.DistrictReplaces[prodQueue[productionQueueTableKey][i+direction].entry.Hash].ReplacesDistrictType == buildingInfo.PrereqDistrict))) then
          actualDest = i;
          break;
        end
      end
    elseif(sourceInfo.type == PRODUCTION_TYPE.PLACED and prodQueue[productionQueueTableKey][i+direction].type == PRODUCTION_TYPE.BUILDING) then
      local buildingInfo = GameInfo.Buildings[prodQueue[productionQueueTableKey][i+direction].entry.Hash];
      local districtInfo = GameInfo.Districts[sourceInfo.entry.Hash];

      if(buildingInfo and buildingInfo.PrereqDistrict) then
        if(districtInfo and (districtInfo.DistrictType == buildingInfo.PrereqDistrict or (GameInfo.DistrictReplaces[sourceInfo.entry.Hash] and GameInfo.DistrictReplaces[sourceInfo.entry.Hash].ReplacesDistrictType == buildingInfo.PrereqDistrict))) then
          actualDest = i;
          break;
        end
      end
    elseif(sourceInfo.type == PRODUCTION_TYPE.BUILDING and prodQueue[productionQueueTableKey][i+direction].type == PRODUCTION_TYPE.BUILDING) then
      local destInfo = GameInfo.Buildings[prodQueue[productionQueueTableKey][i+direction].entry.Hash];
      local sourceBuildingInfo = GameInfo.Buildings[sourceInfo.entry.Hash];

      if(GameInfo.BuildingReplaces[destInfo.BuildingType]) then
        destInfo = GameInfo.Buildings[GameInfo.BuildingReplaces[destInfo.BuildingType].ReplacesBuildingType];
      end

      if(GameInfo.BuildingReplaces[sourceBuildingInfo.BuildingType]) then
        sourceBuildingInfo = GameInfo.Buildings[GameInfo.BuildingReplaces[sourceBuildingInfo.BuildingType].ReplacesBuildingType];
      end

      local halt = false;

      for prereqRow in GameInfo.BuildingPrereqs() do
        if(prereqRow.Building == sourceBuildingInfo.BuildingType) then
          if(destInfo.BuildingType == prereqRow.PrereqBuilding) then
            halt = true;
            actualDest = i;
            break;
          end
        end

        if(prereqRow.PrereqBuilding == sourceBuildingInfo.BuildingType) then
          if(destInfo.BuildingType == prereqRow.Building) then
            halt = true;
            actualDest = i;
            break;
          end
        end
      end

      if(halt == true) then break; end
    end

    if(not noMove) then
      prodQueue[productionQueueTableKey][i], prodQueue[productionQueueTableKey][i+direction] = prodQueue[productionQueueTableKey][i+direction], prodQueue[productionQueueTableKey][i];
    end
  end

  return actualDest;
end

--- ===========================================================================
--  Check the entire queue for mandatory item upgrades
--- ===========================================================================
function CheckAndReplaceAllQueuesForUpgrades()
  local localPlayerId:number = Game.GetLocalPlayer();
  local player = Players[localPlayerId];

  if(player == nil) then
    return;
  end

  local cities = player:GetCities();

  for j, city in cities:Members() do
    CheckAndReplaceQueueForUpgrades(city);
  end
end

--- ===========================================================================
--  Check a city's queue for items that must be upgraded or removed
--  as per tech/civic knowledge
--- ===========================================================================
function CheckAndReplaceQueueForUpgrades(city)
  local playerID = Game.GetLocalPlayer();
  local pPlayer = Players[playerID];
  local pTech = pPlayer:GetTechs();
  local pCulture = pPlayer:GetCulture();
  local buildQueue = city:GetBuildQueue();
  local cityID = city:GetID();
  local productionQueueTableKey = FindProductionQueueKey(cityID, city:GetOwner());
  local pBuildings = city:GetBuildings();
  local pDistricts = city:GetDistricts();
  local civTypeName = PlayerConfigurations[playerID]:GetCivilizationTypeName();
  local removeUnits = {};

  if(not prodQueue[productionQueueTableKey]) then prodQueue[productionQueueTableKey] = {} end

  for i, qi in pairs(prodQueue[productionQueueTableKey]) do
    if(qi.type == PRODUCTION_TYPE.UNIT or qi.type == PRODUCTION_TYPE.CORPS or qi.type == PRODUCTION_TYPE.ARMY) then
      local unitUpgrades = GameInfo.UnitUpgrades[qi.entry.Hash];
      if(unitUpgrades) then
        local upgradeUnit = GameInfo.Units[unitUpgrades.UpgradeUnit];

        -- Check for unique units
        for unitReplaces in GameInfo.UnitReplaces() do
          if(unitReplaces.ReplacesUnitType == unitUpgrades.UpgradeUnit) then
            local match = false;

            for civTraits in GameInfo.CivilizationTraits() do
              if(civTraits.TraitType == "TRAIT_CIVILIZATION_" .. unitReplaces.CivUniqueUnitType and civTraits.CivilizationType == civTypeName) then
                upgradeUnit = GameInfo.Units[unitReplaces.CivUniqueUnitType];
                match = true;
                break;
              end
            end

            if(match) then break; end
          end
        end

        if(upgradeUnit) then
          local canUpgrade = true;

          if(upgradeUnit.PrereqTech and not pTech:HasTech(GameInfo.Technologies[upgradeUnit.PrereqTech].Index)) then
            canUpgrade = false;
          end
          if(upgradeUnit.PrereqCivic and not pCulture:HasCivic(GameInfo.Civics[upgradeUnit.PrereqCivic].Index)) then
            canUpgrade = false;
          end

          local canBuildOldUnit = buildQueue:CanProduce( qi.entry.Hash, true );
          local canBuildNewUnit = buildQueue:CanProduce( upgradeUnit.Hash, false, true );

          -- Only auto replace if we CAN'T queue the old unit
          if(not canBuildOldUnit and canUpgrade and canBuildNewUnit) then
            local isCanProduceExclusion, results   = buildQueue:CanProduce( upgradeUnit.Hash, false, true );
            local isDisabled        :boolean = not isCanProduceExclusion;
            local sAllReasons        :string = ComposeFailureReasonStrings( isDisabled, results );
            local sToolTip           :string = ToolTipHelper.GetUnitToolTip( upgradeUnit.Hash ) .. sAllReasons;

            local nProductionCost   :number = buildQueue:GetUnitCost( upgradeUnit.Index );
            local nProductionProgress :number = buildQueue:GetUnitProgress( upgradeUnit.Index );
            sToolTip = sToolTip .. ComposeProductionCostString( nProductionProgress, nProductionCost );

            prodQueue[productionQueueTableKey ][i].entry = {
              Type      = upgradeUnit.UnitType,
              Name      = upgradeUnit.Name,
              ToolTip     = sToolTip,
              Hash      = upgradeUnit.Hash,
              Kind      = upgradeUnit.Kind,
              TurnsLeft   = buildQueue:GetTurnsLeft( upgradeUnit.Hash ),
              Disabled    = isDisabled,
              Civilian    = upgradeUnit.FormationClass == "FORMATION_CLASS_CIVILIAN",
              Cost      = nProductionCost,
              Progress    = nProductionProgress,
              Corps     = false,
              CorpsCost   = 0,
              CorpsTurnsLeft  = 1,
              CorpsTooltip  = "",
              CorpsName   = "",
              Army      = false,
              ArmyCost    = 0,
              ArmyTurnsLeft = 1,
              ArmyTooltip   = "",
              ArmyName    = ""
            };

            if results ~= nil then
              if results[CityOperationResults.CAN_TRAIN_CORPS] then
                kUnit.Corps     = true;
                kUnit.CorpsCost   = buildQueue:GetUnitCorpsCost( upgradeUnit.Index );
                kUnit.CorpsTurnsLeft  = buildQueue:GetTurnsLeft( upgradeUnit.Hash, MilitaryFormationTypes.CORPS_MILITARY_FORMATION );
                kUnit.CorpsTooltip, kUnit.CorpsName = ComposeUnitCorpsStrings( upgradeUnit.Name, upgradeUnit.Domain, nProductionProgress, kUnit.CorpsCost );
              end
              if results[CityOperationResults.CAN_TRAIN_ARMY] then
                kUnit.Army      = true;
                kUnit.ArmyCost    = buildQueue:GetUnitArmyCost( upgradeUnit.Index );
                kUnit.ArmyTurnsLeft = buildQueue:GetTurnsLeft( upgradeUnit.Hash, MilitaryFormationTypes.ARMY_MILITARY_FORMATION );
                kUnit.ArmyTooltip, kUnit.ArmyName = ComposeUnitArmyStrings( upgradeUnit.Name, upgradeUnit.Domain, nProductionProgress, kUnit.ArmyCost );
              end
            end

            BuildFirstQueued(city);
          elseif(not canBuildOldUnit and canUpgrade and not canBuildNewUnit) then
            -- Can't build the old or new unit. Probably missing a resource. Remove from queue.
            table.insert(removeUnits, i);
          end
        end
      else
        local canBuildUnit = buildQueue:CanProduce( qi.entry.Hash, false, true );
        if(not canBuildUnit) then
          table.insert(removeUnits, i);
        end
      end
    elseif(qi.type == PRODUCTION_TYPE.BUILDING or qi.type == PRODUCTION_TYPE.PLACED) then
      if(qi.entry.Repair == true and GameInfo.Buildings[qi.entry.Hash]) then
        local isPillaged = pBuildings:IsPillaged(GameInfo.Buildings[qi.entry.Hash].Index);
        if(not isPillaged) then
          -- Repair complete, remove from queue
          table.insert(removeUnits, i);
        end
      end

      -- Check if a queued wonder is still available
      if(GameInfo.Buildings[qi.entry.Hash] and GameInfo.Buildings[qi.entry.Hash].MaxWorldInstances == 1) then
        if(not buildQueue:CanProduce(qi.entry.Hash, true)) then
          table.insert(removeUnits, i);
        elseif(not IsCityPlotValidForWonderPlacement(city, qi.plotID, GameInfo.Buildings[qi.entry.Hash]) and not buildQueue:HasBeenPlaced(qi.entry.Hash)) then
          table.insert(removeUnits, i);
        end
      end

      -- AZURENCY : check if district required is pillaged and not in queue
      if (GameInfo.Buildings[qi.entry.Hash]) then
        if GameInfo.Buildings[qi.entry.Hash].PrereqDistrict then
          prereqDistrict = GameInfo.Districts[GameInfo.Buildings[qi.entry.Hash].PrereqDistrict]
          if pDistricts:IsPillaged(prereqDistrict.Index) and not IsHashInQueue(city, prereqDistrict.Hash) then
            table.insert(removeUnits, i);
          end
        end
      end

      -- AZURENCY : check if the building is occupied by an enemy
     isCanStart,results = buildQueue:CanProduce( qi.entry.Hash, false, true );
     if(not isCanStart and results) then
        local pFailureReasons = results[CityCommandResults.FAILURE_REASONS];
        if pFailureReasons ~= nil and table.count( pFailureReasons ) > 0 then
         for a,b in pairs(pFailureReasons) do
           if(Locale.Lookup("LOC_BUILDING_CONSTRUCT_IS_OCCUPIED") == b) then
             table.insert(removeUnits, i);
           end
         end
        end
      end
    end
  end

  if (#removeUnits == #prodQueue[productionQueueTableKey ]) and (#removeUnits > 0) then

      prodQueue[productionQueueTableKey ] = {};
      removeUnits = {};
      BuildFirstQueued(city);
      LuaEvents.UpdateBanner(playerID, cityID);

      print_debug("Entire Queue Wiped");
  end

  if (#removeUnits > 0) then
    for i=#removeUnits, 1, -1 do
      local success = RemoveFromQueue(city, removeUnits[i], true);

      if success then
        print_debug("Removing Item: " .. i);
      end

      if(success and removeUnits[i] == 1) then
        BuildFirstQueued(city);
      end
    end
  end
end

function IsCityPlotValidForWonderPlacement(city, plotID, wonder)
  if(not plotID or plotID == -1) then return true end
  if Map.GetPlotByIndex(plotID):CanHaveWonder(wonder.Index, city:GetOwner(), city:GetID()) then
    return true;
  else
    return false;
  end
end

--- =======================================================================================================
--  === UI handling
--- =======================================================================================================

--- ==========================================================================
--  Resize the Production Queue window to fit the items
--- ==========================================================================
function ResizeQueueWindow()
  Controls.ProductionQueueList:CalculateSize();
  Controls.ProductionQueueListScroll:CalculateInternalSize();
  local windowHeight = math.min(math.max(Controls.ProductionQueueList:GetSizeY()+42, 74), screenHeight-300);
  Controls.QueueWindow:SetSizeY(windowHeight);
  Controls.ProductionQueueListScroll:CalculateSize();
end

--- ==========================================================================
--  Slide-in/hide the Production Queue panel
--- ==========================================================================
function CloseQueueWindow()
  Controls.QueueSlideIn:Reverse();
  Controls.QueueWindowToggleDirection:SetText("<");
end

--- ==========================================================================
--  Slide-out/show the Production Queue panel
--- ==========================================================================
function OpenQueueWindow()
  Controls.QueueSlideIn:SetToBeginning();
  Controls.QueueSlideIn:Play();
  Controls.QueueWindowToggleDirection:SetText(">");
end

--- ==========================================================================
--  Toggle the visibility of the Production Queue panel
--- ==========================================================================
function ToggleQueueWindow()
  showStandaloneQueueWindow = not showStandaloneQueueWindow;

  if(showStandaloneQueueWindow) then
    OpenQueueWindow();
  else
    CloseQueueWindow();
  end
end

--- ===============================================================================
--  Control Event
--  Fires when the production panel has finished fading in
--  Use this to, if it is toggled off, delay showing the Production Queue panel
--  (and therefore toggle tab) unitl after the production panel is there to
--  cover it up
--- ===============================================================================
function OnPanelFadeInComplete()
  if(not showStandaloneQueueWindow) then
    Controls.QueueAlphaIn:Play();
  end
end

--- ===========================================================================
--  Recenter the camera over the selected city
--  This is here for the sake of middle mouse clicking on a production item
--  which ordinarily recenters the map to the cursor position
--- ===========================================================================
function RecenterCameraToSelectedCity()
  local kCity:table = UI.GetHeadSelectedCity();
  UI.LookAtPlot( kCity:GetX(), kCity:GetY() );
end

function ResetCityQueue(cityID, player)
  if (not player) then
    player = Players[Game.GetLocalPlayer()];
  end
  if(not player) then return end
  local city = player:GetCities():FindID(cityID);

  if(not city) then return end

  local buildQueue = city:GetBuildQueue();
  local currentProductionHash = buildQueue:GetCurrentProductionTypeHash();
  local plotID = -1;
  local productionQueueTableKey = FindProductionQueueKey(cityID, city:GetOwner())

  if(prodQueue[productionQueueTableKey ]) then prodQueue[productionQueueTableKey ] = {}; end

  if(currentProductionHash ~= 0) then
    -- Determine the type of the item
    local currentType = 0;
    local productionInfo = GetProductionInfoOfCity(city, currentProductionHash);
    productionInfo.Hash = currentProductionHash;

    if(productionInfo.Type == "UNIT") then
      currentType = buildQueue:GetCurrentProductionTypeModifier() + 2;
    elseif(productionInfo.Type == "BUILDING") then
      if(GameInfo.Buildings[currentProductionHash].MaxWorldInstances == 1) then
        currentType = PRODUCTION_TYPE.PLACED;

        local pCityBuildings  :table = city:GetBuildings();
        local kCityPlots    :table = Map.GetCityPlots():GetPurchasedPlots( city );
        if (kCityPlots ~= nil) then
          for _,plot in pairs(kCityPlots) do
            local kPlot:table =  Map.GetPlotByIndex(plot);
            local wonderType = kPlot:GetWonderType();
            if(wonderType ~= -1 and GameInfo.Buildings[wonderType].BuildingType == GameInfo.Buildings[currentProductionHash].BuildingType) then
              plotID = plot;
            end
          end
        end
      else
        currentType = PRODUCTION_TYPE.BUILDING;
      end
    elseif(productionInfo.Type == "DISTRICT") then
      currentType = PRODUCTION_TYPE.PLACED;
    elseif(productionInfo.Type == "PROJECT") then
      currentType = PRODUCTION_TYPE.PROJECT;
    end

    if(currentType == 0) then
      print("ERROR : Could not find production type for hash: " .. currentProductionHash);
    end

    prodQueue[productionQueueTableKey][1] = {
      entry=productionInfo,
      type=currentType,
      plotID=plotID
    }
  end
end

function ResetAllCityQueues()
  local player = Players[Game.GetLocalPlayer()];
  if(not player) then return end

  for _,x in player:GetCities():Members() do
    ResetCityQueue(x:GetID(), player);
  end

  Refresh();
end

function ResetSelectedCityQueue()
  local selectedCity = UI.GetHeadSelectedCity();
  if(not selectedCity) then return end

  local cityID = selectedCity:GetID();
  if(not cityID) then return end

  ResetCityQueue(cityID);

  Refresh();
end
--- =========================================================================================================
--- =========================================================================================================
--- =========================================================================================================

function ReverseTable(t)
    local reversedTable = {}
    local itemCount = #t
    for k, v in ipairs(t) do
        reversedTable[itemCount + 1 - k] = v
    end
    return reversedTable
end

function Initialize()

  LoadQueues();
  Controls.PauseCollapseList:Stop();
  Controls.PauseDismissWindow:Stop();
  --CreateCorrectTabs();
  Resize();
  SetDropOverlap( DROP_OVERLAP_REQUIRED );

  --Controls.HideDisabled:RegisterCallback( Mouse.eLClick, ShowHideDisabled);
  --AutoSizeGridButton(Controls.HideDisabled,45,24,20,"H");
  -- ===== Event listeners =====

  Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);
  Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.PauseCollapseList:RegisterEndCallback( OnCollapseTheList );
  Controls.PauseDismissWindow:RegisterEndCallback( OnHide );
  Controls.QueueWindowToggle:RegisterCallback(Mouse.eLClick, ToggleQueueWindow);
  Controls.AlphaIn:RegisterEndCallback( OnPanelFadeInComplete )
  Controls.QueueWindowReset:RegisterCallback(Mouse.eLClick, ResetSelectedCityQueue);

  ContextPtr:SetInitHandler( OnInit  );
  ContextPtr:SetInputHandler( OnInputHandler, true );
  ContextPtr:SetShutdown( OnShutdown );

  Events.CitySelectionChanged.Add( OnCitySelectionChanged );
  Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
  Events.UnitSelectionChanged.Add( OnUnitSelectionChanged );
  Events.LocalPlayerChanged.Add( OnLocalPlayerChanged );
  Events.PlayerTurnActivated.Add( OnPlayerTurnActivated );
  Events.ResearchCompleted.Add(OnTechCivicCompleted);
  Events.CivicCompleted.Add(OnTechCivicCompleted);


  LuaEvents.CityBannerManager_ProductionToggle.Add( OnCityBannerManagerProductionToggle );
  LuaEvents.CityPanel_ChooseProduction.Add( OnCityPanelChooseProduction );
  LuaEvents.CityPanel_ChoosePurchase.Add( OnCityPanelChoosePurchase );
  LuaEvents.CityPanel_ProductionClose.Add( OnProductionClose );
  LuaEvents.CityPanel_ProductionOpen.Add( OnCityPanelProductionOpen );
  LuaEvents.CityPanel_PurchaseGoldOpen.Add( OnCityPanelPurchaseGoldOpen );
  LuaEvents.CityPanel_PurchaseFaithOpen.Add( OnCityPanelPurchaseFaithOpen );
  LuaEvents.CityPanel_ProductionOpenForQueue.Add( OnProductionOpenForQueue );
  LuaEvents.CityPanel_PurchasePlot.Add( OnCityPanelPurchasePlot );
  LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );
  LuaEvents.NotificationPanel_ChooseProduction.Add( OnNotificationPanelChooseProduction );
  LuaEvents.StrageticView_MapPlacement_ProductionOpen.Add( OnStrategicViewMapPlacementProductionOpen );
  LuaEvents.StrageticView_MapPlacement_ProductionClose.Add( OnStrategicViewMapPlacementProductionClose );
  LuaEvents.Tutorial_ProductionOpen.Add( OnTutorialProductionOpen );

  Events.CityProductionChanged.Add( OnCityProductionChanged );
  Events.CityProductionCompleted.Add(OnCityProductionCompleted);
  Events.CityProductionUpdated.Add(OnCityProductionUpdated);

  -- CQUI Update production panel
  Events.CityWorkerChanged.Add(function() if not ContextPtr:IsHidden() and Controls.SlideIn:GetOffsetX() == 0 then Refresh() end end);
  Events.CityFocusChanged.Add(Refresh);

  -- CQUI Setting Controls
  PopulateCheckBox(Controls.CQUI_ProductionQueueCheckbox, "CQUI_ProductionQueue");
  RegisterControl(Controls.CQUI_ProductionQueueCheckbox, "CQUI_ProductionQueue", UpdateCheckbox);

  -- CQUI Loading Previous Turn items
  -- ===================================================================
  -- local ePlayer :number = Game.GetLocalPlayer();
  -- local kPlayer         = Players[ePlayer];
  -- local cities          = kPlayer:GetCities();
  -- local cityCount       = cities:GetCount();

  -- if GameConfiguration.IsSavedGame() then

    -- for i=0,cityCount-1 do
      -- CQUI_currentProductionHash[i] = GameConfiguration.GetValue("CQUI_currentProductionHash" .. i);
    -- end

    -- for i=0,cityCount-1 do
      -- CQUI_previousProductionHash[i] = GameConfiguration.GetValue("CQUI_previousProductionHash" .. i);
    -- end

  -- end
  -- ===================================================================




end
Initialize();
