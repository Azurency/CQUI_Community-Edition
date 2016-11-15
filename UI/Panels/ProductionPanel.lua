-- ===========================================================================
--  Production Panel / Purchase Panel
-- ===========================================================================

include( "ToolTipHelper" ); 
include( "InstanceManager" );
include( "TabSupport" );
include( "Civ6Common" );
include( "SupportFunctions" );
include( "AdjacencyBonusSupport");

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

-- ===========================================================================
--  Members
-- ===========================================================================

local m_listIM      = InstanceManager:new( "NestedList",  "Top", Controls.ProductionList );

local m_productionTab;  -- Additional tracking of the tab control data so that we can select between graphical tabs and label tabs
local m_purchaseTab;
local m_faithTab;
local m_maxProductionSize :number = 0;
local m_maxPurchaseSize   :number = 0;
local m_isQueueMode     :boolean = false;
local m_TypeNames     :table  = {};
local m_kClickedInstance;
local prodBuildingList;
local prodWonderList;
local prodUnitList;
local prodDistrictList;
local prodProjectList;
local purchBuildingList;
local purchGoldBuildingList;
local purchFaithBuildingList;
local purchUnitList;
local purchGoldUnitList
local purchFaithUnitList

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
  m_kClickedInstance = instance;
  instance.HeaderOn:SetHide(false);   
  instance.Header:SetHide(true);      
  instance.List:SetHide(false);     
  instance.ListSlide:SetSizeY(instance.List:GetSizeY());
  instance.ListAlpha:SetSizeY(instance.List:GetSizeY());
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

  local building      :table    = GameInfo.Buildings[buildingEntry.Type];
  local bNeedsPlacement :boolean  = building.RequiresPlacement;

  

  local pBuildQueue = city:GetBuildQueue();
  if (pBuildQueue:HasBeenPlaced(buildingEntry.Hash)) then
    bNeedsPlacement = false;
  end

  -- Does the building need to be placed?
  if ( bNeedsPlacement ) then     
    -- If so, set the placement mode
    local tParameters = {}; 
    tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = buildingEntry.Hash;
    tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
    UI.SetInterfaceMode(InterfaceModeTypes.BUILDING_PLACEMENT, tParameters);
  else
    -- If not, add it to the queue.
    local tParameters = {}; 
    tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = buildingEntry.Hash;  
    tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
    CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
        UI.PlaySound("Confirm_Production");
  end
end

-- ===========================================================================
function ZoneDistrict(city, districtEntry)
  
  local district      :table    = GameInfo.Districts[districtEntry.Type];
  local bNeedsPlacement :boolean  = district.RequiresPlacement;
  local pBuildQueue   :table    = city:GetBuildQueue();

  if (pBuildQueue:HasBeenPlaced(districtEntry.Hash)) then
    bNeedsPlacement = false;
  end

  -- Almost all districts need to be placed, but just in case let's check anyway
  if (bNeedsPlacement ) then      
    -- If so, set the placement mode
    local tParameters = {}; 
    tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Hash;
    tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
    UI.SetInterfaceMode(InterfaceModeTypes.DISTRICT_PLACEMENT, tParameters);
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
    else
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index;  
    end
  else
    tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = purchaseType;
  end
  CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters);
  UI.PlaySound("Purchase_With_Gold");
end

-- ===========================================================================
function PurchaseUnitCorps(city, unitEntry)
  local tParameters = {};
  tParameters[CityCommandTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
  tParameters[CityCommandTypes.PARAM_MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.CORPS_MILITARY_FORMATION;
  if (unitEntry.Yield == "YIELD_GOLD") then
    tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
  else
    tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index;  
  end
  CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters);
    UI.PlaySound("Purchase_With_Gold");
end

-- ===========================================================================
function PurchaseUnitArmy(city, unitEntry)
  local tParameters = {};
  tParameters[CityCommandTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
  tParameters[CityCommandTypes.PARAM_MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.ARMY_MILITARY_FORMATION;
  if (unitEntry.Yield == "YIELD_GOLD") then
    tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
  else
    tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index;  
  end
  CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters);
    UI.PlaySound("Purchase_With_Gold");
end

-- ===========================================================================
function PurchaseBuilding(city, buildingEntry, purchaseType)
  local tParameters = {};
  tParameters[CityCommandTypes.PARAM_BUILDING_TYPE] = buildingEntry.Hash;
  if(purchaseType == nil) then
    if (buildingEntry.Yield == "YIELD_GOLD") then
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
    else
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index;  
    end
  else
    tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = purchaseType;
  end
  CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters);
  UI.PlaySound("Purchase_With_Gold");
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
  if (Controls.SlideIn:IsStopped()) then      -- Need to check to make sure that we have not already begun the transition before attempting to close the panel.
    UI.PlaySound("Production_Panel_Closed");
    Controls.SlideIn:Reverse(); 
    Controls.AlphaIn:Reverse();
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
  if ContextPtr:IsHidden() then         -- The ContextPtr is only hidden as a callback to the finished SlideIn animation, so this check should be sufficient to ensure that we are not animating.
    -- Sets up proper selection AND the associated lens so it's not stuck "on".
    UI.PlaySound("Production_Panel_Open");
    LuaEvents.ProductionPanel_Open()
    Refresh();
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
    productionItem.CorpsArmyDropdownArea:SetHide(true);
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
  Controls.PauseCollapseList:Stop();
  local selectedCity  = UI.GetHeadSelectedCity();
  local CQUI_ProdTable = {}; --Keeps track of each producable item. Key is the item hash, Value is a table with three keys (time/gold/faith) representing the respective costs
  
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
    else
      CQUI_ProdTable[item.Hash]["faith"] = item.Cost;
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
      -- Check to see if this item is recommended
      --for _,hash in ipairs( m_recommendedItems) do
      --  if(item.Hash == hash.BuildItemHash) then
      --    unitListing.RecommendedIcon:SetHide(false);
      --  end
      --end

      local costStr = "";
      local costStrTT = "";
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
        costStrTT = item.TurnsLeft .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", item.TurnsLeft);
        costStr = item.TurnsLeft .. "[ICON_Turn]";

      local nameStr = Locale.Lookup("{1_Name}", item.Name);
      unitListing.LabelText:SetText(nameStr);
      unitListing.CostText:SetText(costStr);
      if(costStrTT ~= "") then
        unitListing.CostText:SetToolTipString(costStrTT);
      end
      unitListing.TrainUnit:SetToolTipString(item.ToolTip);
      unitListing.Disabled:SetToolTipString(item.ToolTip);

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
          else
            textureName = TEXTURE_CIVILIAN;
          end
        end
      end

      -- Set colors and icons for the flag instance
      unitListing.Icon:SetColor( "0xFFFFFFFF" );
      unitListing.Icon:SetIcon(ICON_PREFIX..item.Type);

      unitListing.TrainUnit:RegisterCallback( Mouse.eLClick, function()
        BuildUnit(data.City, item);
        end);

      --CQUI Productionpanel buy buttons
      unitListing.PurchaseButton:RegisterCallback( Mouse.eLClick, function()
        PurchaseUnit(data.City, item, GameInfo.Yields["YIELD_GOLD"].Index);
        end);
      if CQUI_ProdTable[item.Hash]["gold"] ~= nil then
        unitListing.PurchaseButton:SetText(CQUI_ProdTable[item.Hash]["gold"] .. "[ICON_GOLD]");
        unitListing.PurchaseButton:SetHide(false);
      else
        unitListing.PurchaseButton:SetHide(true);
      end
      unitListing.FaithPurchaseButton:RegisterCallback( Mouse.eLClick, function()
        PurchaseUnit(data.City, item, GameInfo.Yields["YIELD_FAITH"].Index);
        end);
      if CQUI_ProdTable[item.Hash]["faith"] ~= nil then
        unitListing.FaithPurchaseButton:SetText(CQUI_ProdTable[item.Hash]["faith"] .. "[ICON_FAITH]");
        unitListing.FaithPurchaseButton:SetHide(false);
      else
        unitListing.FaithPurchaseButton:SetHide(true);
      end

      unitListing.TrainUnit:RegisterCallback( Mouse.eRClick, function()
        LuaEvents.OpenCivilopedia(item.Type);
      end); 
      unitListing.TrainUnit:SetTag(UITutorialManager:GetHash(item.Type));

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
      unitListing.TrainUnit:SetDisabled(item.Disabled);
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
    local screenX, screenY:number = UIManager:GetScreenSizeVal()
  
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
      Controls.CurrentProductionCost:SetText(currentProductionInfo.Turns .. "[ICON_Turn]");
      Controls.CurrentProductionProgressString:SetText("[ICON_Production]"..currentProductionInfo.Progress.."/"..currentProductionInfo.Cost);
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

    for i, item in ipairs(data.DistrictItems) do
      local districtListing = districtList["districtListIM"]:GetInstance();
      ResetInstanceVisibility(districtListing);
      -- Check to see if this district item is one of the items that is recommended:
      --for _,hash in ipairs( m_recommendedItems) do
      --  if(item.Hash == hash.BuildItemHash) then
      --    districtListing.RecommendedIcon:SetHide(false);
      --  end
      --end

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
      else
        turnsStrTT = item.TurnsLeft .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", item.TurnsLeft);
        turnsStr = item.TurnsLeft .. "[ICON_Turn]";
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
        ZoneDistrict(data.City, item);
      end);

      districtListing.Button:RegisterCallback( Mouse.eRClick, function()
        LuaEvents.OpenCivilopedia(item.Type);
      end);

      districtListing.Root:SetTag(UITutorialManager:GetHash(item.Type));
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
      districtList.HeaderOn:RegisterCallback( Mouse.eLClick, function()
        OnCollapse(dL);         
        end);
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
      if(not buildingItem.IsWonder) then
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
          --for _,hash in ipairs( m_recommendedItems) do
          --  if(buildingItem.Hash == hash.BuildItemHash) then
          --    buildingListing.RecommendedIcon:SetHide(false);
          --  end
          --end
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
          local turnsStrTT = buildingItem.TurnsLeft .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", buildingItem.TurnsLeft);
          local turnsStr = buildingItem.TurnsLeft .. "[ICON_Turn]";
          buildingListing.CostText:SetToolTipString(turnsStrTT);
          buildingListing.CostText:SetText(turnsStr);
          buildingListing.Button:SetToolTipString(buildingItem.ToolTip);
          buildingListing.Disabled:SetToolTipString(buildingItem.ToolTip);
          buildingListing.Icon:SetIcon(ICON_PREFIX..buildingItem.Type);
          buildingListing.Button:RegisterCallback( Mouse.eLClick, function()
            BuildBuilding(data.City, buildingItem);
          end);

          buildingListing.Button:RegisterCallback( Mouse.eRClick, function()
            LuaEvents.OpenCivilopedia(buildingItem.Type);
          end);

          buildingListing.Button:SetTag(UITutorialManager:GetHash(buildingItem.Type));

          --CQUI Button binds
          buildingListing.PurchaseButton:RegisterCallback( Mouse.eLClick, function()
            PurchaseBuilding(data.City, buildingItem, GameInfo.Yields["YIELD_GOLD"].Index);
          end);
          if CQUI_ProdTable[buildingItem.Hash]["gold"] ~= nil then
            buildingListing.PurchaseButton:SetText(CQUI_ProdTable[buildingItem.Hash]["gold"] .. "[ICON_GOLD]");
            buildingListing.PurchaseButton:SetHide(false);
          else
            buildingListing.PurchaseButton:SetHide(true);
          end
          buildingListing.FaithPurchaseButton:RegisterCallback( Mouse.eLClick, function()
            PurchaseBuilding(data.City, buildingItem, GameInfo.Yields["YIELD_FAITH"].Index);
          end);
          if CQUI_ProdTable[buildingItem.Hash]["faith"] ~= nil then
            buildingListing.FaithPurchaseButton:SetText(CQUI_ProdTable[buildingItem.Hash]["faith"] .. "[ICON_FAITH]");
            buildingListing.FaithPurchaseButton:SetHide(false);
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
            buildingListing.Button:SetSizeY(BUTTON_Y);
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
        wonderListing.PurchaseButton:SetHide(true);
        wonderListing.FaithPurchaseButton:SetHide(true);
        --for _,hash in ipairs( m_recommendedItems) do
        --  if(item.Hash == hash.BuildItemHash) then
        --    wonderListing.RecommendedIcon:SetHide(false);
        --  end
        --end
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
        local turnsStrTT = item.TurnsLeft .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", item.TurnsLeft);
        local turnsStr = item.TurnsLeft .. "[ICON_Turn]";
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
          wonderListing.Button:SetSizeY(BUTTON_Y);
          wonderListing.Button:SetColor(0xffffffff);
        end
        wonderListing.Button:SetDisabled(item.Disabled);
        wonderListing.Button:RegisterCallback( Mouse.eLClick, function()
          BuildBuilding(data.City, item);
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
      wonderList.HeaderOn:RegisterCallback( Mouse.eLClick, function()
        OnCollapse(wL);         
        end);
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
      --for _,hash in ipairs( m_recommendedItems) do
      --  if(item.Hash == hash.BuildItemHash) then
      --    projectListing.RecommendedIcon:SetHide(false);
      --  end
      --end

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

      local nameStr = Locale.Lookup("{1_Name}", item.Name);
      --local turnsStr = Locale.Lookup("{1_Turns : plural 1?{1_Turns} turn; other?{1_Turns} turns;}", item.TurnsLeft);
      local turnsStr = item.TurnsLeft .. "[ICON_Turn]";
      projectListing.LabelText:SetText(nameStr);
      projectListing.CostText:SetText(turnsStr);
      projectListing.Button:SetToolTipString(item.ToolTip);
      projectListing.Disabled:SetToolTipString(item.ToolTip);
      projectListing.Icon:SetIcon(ICON_PREFIX..item.Type);
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
        AdvanceProject(data.City, item);
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

  -----------------------------------
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
function ComposeUnitCorpsStrings( sUnitName:string, sUnitDomain:string, iProdProgress:number, iCorpsCost:number )
  local tooltip :string = Locale.Lookup( sUnitName ) .. " ";
  local subtitle  :string = "";
  if sUnitDomain == "DOMAIN_SEA" then
    tooltip = tooltip .. Locale.Lookup("LOC_UNITFLAG_FLEET_SUFFIX");
    subtitle = "(" .. Locale.Lookup("LOC_HUD_UNIT_PANEL_FLEET_SUFFIX") .. ")";
  else
    tooltip = tooltip .. Locale.Lookup("LOC_UNITFLAG_CORPS_SUFFIX");
    subtitle = "(" .. Locale.Lookup("LOC_HUD_UNIT_PANEL_CORPS_SUFFIX") .. ")";
  end
  tooltip = tooltip .. "[NEWLINE]---" .. ComposeProductionCostString( iProdProgress, iCorpsCost );
  return tooltip, subtitle;
end
function ComposeUnitArmyStrings( sUnitName:string, sUnitDomain:string, iProdProgress:number, iArmyCost:number )
  local tooltip :string = Locale.Lookup( sUnitName ) .. " ";
  local subtitle  :string = "";
  if sUnitDomain == "DOMAIN_SEA" then
    tooltip = tooltip .. Locale.Lookup("LOC_UNITFLAG_ARMADA_SUFFIX");
    subtitle = "("..Locale.Lookup("LOC_HUD_UNIT_PANEL_ARMADA_SUFFIX")..")";
  else
    tooltip = tooltip .. Locale.Lookup("LOC_UNITFLAG_ARMY_SUFFIX");
    subtitle = "("..Locale.Lookup("LOC_HUD_UNIT_PANEL_ARMY_SUFFIX")..")";
  end
  tooltip = tooltip .. "[NEWLINE]---" .. ComposeProductionCostString( iProdProgress, iArmyCost );
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
    sToolTip = sToolTip .. ComposeProductionCostString( nProductionProgress, nProductionCost );
    
    local kUnit  :table = {
      Type      = row.UnitType;
      Name      = row.Name;
      ToolTip     = sToolTip;
      Hash      = row.Hash;
      Kind      = row.Kind;
      Civilian    = row.FormationClass == "FORMATION_CLASS_CIVILIAN";
      Disabled    = isDisabled;
      CantAfford    = isCantAfford,
      Yield     = sYield;
      Cost      = pCityGold:GetPurchaseCost( YIELD_TYPE, row.Hash, MilitaryFormationTypes.STANDARD_MILITARY_FORMATION );
      
      CorpsTurnsLeft  = 0;
      ArmyTurnsLeft = 0;
      Progress    = 0;
    };
    
    -- Should we present options for building Corps or Army versions?
    if results ~= nil then
      kUnit.Corps = results[CityOperationResults.CAN_TRAIN_CORPS];
      kUnit.Army = results[CityOperationResults.CAN_TRAIN_ARMY];
      
      local nProdProgress :number = pBuildQueue:GetUnitProgress( row.Index );
      if kUnit.Corps then
        local nCost = pBuildQueue:GetUnitCorpsCost( row.Index );
        kUnit.CorpsCost = pCityGold:GetPurchaseCost( YIELD_TYPE, row.Hash, MilitaryFormationTypes.CORPS_MILITARY_FORMATION );
        kUnit.CorpsTooltip, kUnit.CorpsName = ComposeUnitCorpsStrings( row.Name, row.Domain, nProdProgress, nCost );
        kUnit.CorpsDisabled = not pYieldSource:CanAfford( nCityID, row.Hash, MilitaryFormationTypes.CORPS_MILITARY_FORMATION );
        if kUnit.CorpsDisabled then
          kUnit.CorpsTooltip = kUnit.CorpsTooltip .. TXT_INSUFFIENT_YIELD;
        end
      end
      
      if kUnit.Army then
        local nCost = pBuildQueue:GetUnitArmyCost( row.Index );
        kUnit.ArmyCost  = pCityGold:GetPurchaseCost( YIELD_TYPE, row.Hash, MilitaryFormationTypes.ARMY_MILITARY_FORMATION );
        kUnit.ArmyTooltip, kUnit.ArmyName = ComposeUnitArmyStrings( row.Name, row.Domain, nProdProgress, nCost );
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
    if not pYieldSource:CanAfford( cityID, pRow.Hash ) then
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
-- ===========================================================================
function Refresh()
  local playerID  :number = Game.GetLocalPlayer();
  local pPlayer :table = Players[playerID];
  if (pPlayer == nil) then
    return;
  end

  local selectedCity  = UI.GetHeadSelectedCity();

  if (selectedCity ~= nil) then
    local cityGrowth  = selectedCity:GetGrowth();
    local cityCulture = selectedCity:GetCulture();
    local buildQueue  = selectedCity:GetBuildQueue();
    local playerTreasury= pPlayer:GetTreasury();
    local playerReligion= pPlayer:GetReligion();
    local cityGold    = selectedCity:GetGold();
    local cityBuildings = selectedCity:GetBuildings();
    local cityDistricts = selectedCity:GetDistricts();
    local cityID    = selectedCity:GetID();
    
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
      UnitPurchases   = {}
    };
    
    local currentProductionHash = buildQueue:GetCurrentProductionTypeHash();

    for row in GameInfo.Districts() do
      if row.Hash == currentProductionHash then
        new_data.CurrentProduction = row.Name;
      end
      
      local isInPanelList     :boolean = row.Hash ~= currentProductionHash and not row.InternalOnly;
      local bHasProducedDistrict  :boolean = cityDistricts:HasDistrict( row.Index );
      if isInPanelList and ( buildQueue:CanProduce( row.Hash, true ) or bHasProducedDistrict ) then
        local isCanProduceExclusion, results = buildQueue:CanProduce( row.Hash, false, true );
        local isDisabled      :boolean = not isCanProduceExclusion;
        
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
        end
        
        local allReasons      :string = ComposeFailureReasonStrings( isDisabled, results );
        local sToolTip        :string = ToolTipHelper.GetDistrictToolTip( row.Hash ) .. allReasons;
        
        local iProductionCost   :number = buildQueue:GetDistrictCost( row.Index );
        local iProductionProgress :number = buildQueue:GetDistrictProgress( row.Index );
        sToolTip = sToolTip .. ComposeProductionCostString( iProductionProgress, iProductionCost );

        table.insert( new_data.DistrictItems, {
          Type      = row.DistrictType, 
          Name      = row.Name, 
          ToolTip     = sToolTip, 
          Hash      = row.Hash, 
          Kind      = row.Kind, 
          TurnsLeft   = buildQueue:GetTurnsLeft( row.DistrictType ), 
          Disabled    = isDisabled, 
          Repair      = cityDistricts:IsPillaged( row.Index ),
          Contaminated  = cityDistricts:IsContaminated( row.Index ),
          Cost      = iProductionCost, 
          Progress    = iProductionProgress,
          HasBeenBuilt  = bHasProducedDistrict
        });
      end
    end

    for row in GameInfo.Buildings() do
      if row.Hash == currentProductionHash then
        new_data.CurrentProduction = row.Name;
      end
      
      if row.Hash ~= currentProductionHash and not row.MustPurchase and buildQueue:CanProduce( row.Hash, true ) then
        local isCanStart, results      = buildQueue:CanProduce( row.Hash, false, true );
        local isDisabled      :boolean = not isCanStart;
        local allReasons       :string = ComposeFailureReasonStrings( isDisabled, results );
        local sToolTip         :string = ToolTipHelper.GetBuildingToolTip( row.Hash, playerID, selectedCity ) .. allReasons;

        local iProductionCost   :number = buildQueue:GetBuildingCost( row.Index );
        local iProductionProgress :number = buildQueue:GetBuildingProgress( row.Index );
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
          Repair      = cityBuildings:IsPillaged( row.Index ), 
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
      end
      -- Can it be built normally?
      if row.Hash ~= currentProductionHash and not row.MustPurchase and buildQueue:CanProduce( row.Hash, true ) then
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
        
        -- Should we present options for building Corps or Army versions?
        if results ~= nil then
          if results[CityOperationResults.CAN_TRAIN_CORPS] then
            kUnit.Corps     = true;
            kUnit.CorpsCost   = buildQueue:GetUnitCorpsCost( row.Index );
            kUnit.CorpsTurnsLeft  = buildQueue:GetTurnsLeft( row.Hash, MilitaryFormationTypes.CORPS_MILITARY_FORMATION );
            kUnit.CorpsTooltip, kUnit.CorpsName = ComposeUnitCorpsStrings( row.Name, row.Domain, nProductionProgress, kUnit.CorpsCost );
          end
          if results[CityOperationResults.CAN_TRAIN_ARMY] then
            kUnit.Army      = true;
            kUnit.ArmyCost    = buildQueue:GetUnitArmyCost( row.Index );
            kUnit.ArmyTurnsLeft = buildQueue:GetTurnsLeft( row.Hash, MilitaryFormationTypes.ARMY_MILITARY_FORMATION );
            kUnit.ArmyTooltip, kUnit.ArmyName = ComposeUnitArmyStrings( row.Name, row.Domain, nProductionProgress, kUnit.ArmyCost );
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
      end
      
      if row.Hash ~= currentProductionHash and buildQueue:CanProduce( row.Hash, true ) then
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
--  Keyboard INPUT Handler
-- ===========================================================================
function KeyHandler( key:number )
  if (key == Keys.VK_ESCAPE) then Close(); return true; end
  return false;
end

-- ===========================================================================
--  UI Event
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
  local uiMsg = pInputStruct:GetMessageType();
  if uiMsg == KeyEvents.KeyUp then return KeyHandler( pInputStruct:GetKey() ); end;
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
  if(productionLabelX +  purchaseLabelX + purchaseFaithLabelX > MAX_TAB_LABEL_WIDTH) then
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

function OnCityProductionChanged()
  Refresh();
end

--
--Fix me out of here
--
local g_cowboy = false;
local g_badcowboy = false;
function OnToggleCowboy() g_cowboy = not g_cowboy; end
function OnToggleBadCowboy() g_badcowboy = not g_badcowboy; end

function FormCorps2( pInputStruct )
    local plotID = UI.GetCursorPlotID();
  if (Map.IsPlot(plotID)) then
    local plot = Map.GetPlotByIndex(plotID);
    local unitList  = Units.GetUnitsInPlotLayerID(  plot:GetX(), plot:GetY(), MapLayers.ANY );
    local pSelectedUnit = UI.GetHeadSelectedUnit();

    local tParameters :table = {};
    for i, pUnit in ipairs(unitList) do
      tParameters[UnitCommandTypes.PARAM_UNIT_PLAYER] = pUnit:GetOwner();
      tParameters[UnitCommandTypes.PARAM_UNIT_ID] = pUnit:GetID();
      if (UnitManager.CanStartCommand( pSelectedUnit, UnitCommandTypes.FORM_CORPS, tParameters)) then
        UnitManager.RequestCommand( pSelectedUnit, UnitCommandTypes.FORM_CORPS, tParameters);
      end
    end
  end           
  return true;
end

--local localPlayer = Players[Game.GetLocalPlayer()];
--if (localPlayer ~= nil) then
--  local playerTechs = localPlayer:GetTechs();
--  local techType = GameInfo.Technologies[resourceTechType];
--  if (techType ~= nil and not playerTechs:HasTech(techType.Index)) then
--    table.insert(toolTipItems,"[COLOR:Civ6Red](".. Locale.Lookup("LOC_TOOLTIP_REQUIRES") .. " " .. Locale.Lookup(techType.Name) .. ")[ENDCOLOR]");
--  end
--end

function AutoFormCorps(pCity, unitHash)
end

function BuildUnit2(pCity, unitHash)
  local tParameters = {}; 
  tParameters[CityOperationTypes.PARAM_UNIT_TYPE] = unitHash;
  tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
  CityManager.RequestOperation(pCity, CityOperationTypes.BUILD, tParameters);
end

function TryFormCorp(pSelectedUnit, unitList)
  for i, pUnit in ipairs(unitList) do
    tParameters[UnitCommandTypes.PARAM_UNIT_PLAYER] = pUnit:GetOwner();
    tParameters[UnitCommandTypes.PARAM_UNIT_ID] = pUnit:GetID();
    if (UnitManager.CanStartCommand( pSelectedUnit, UnitCommandTypes.FORM_CORPS, tParameters)) then
      UnitManager.RequestCommand( pSelectedUnit, UnitCommandTypes.FORM_CORPS, tParameters);
      return true;
    end
  end
  return false;
end

function ReverseTable(t)
    local reversedTable = {}
    local itemCount = #t
    for k, v in ipairs(t) do
        reversedTable[itemCount + 1 - k] = v
    end
    return reversedTable
end

function OnCityProductionCompleted( playerID:number, cityID:number)
  if (playerID ~= Game.GetLocalPlayer()) then return end;

  local pPlayer = Players[ playerID ];
  if (pPlayer == nil) then return end;
  
  local pCity = pPlayer:GetCities():FindID(cityID);
  if (pCity == nil) then return end;

  --unit_type 33
  if (g_cowboy) then
    BuildUnit2(pCity, 1462612590);
  end

  if (g_badcowboy) then
    --CityManager.GetCity(player, id);
    local unitList  = Units.GetUnitsInPlotLayerID( pCity:GetX(), pCity:GetY(), MapLayers.ANY );
    --local rUnitList = ReverseTable(unitList);
    for i, pUnit in ipairs(unitList) do
      if (pUnit ~= nil and pUnit:GetUnitType() == 33) then
        UnitManager.RequestCommand( pUnit, UnitCommandTypes.DELETE );
      end
    end
  end
  --if unitList[0] == nil then return end;
  --local pSelectedUnit:table = unitList[0];

  --print(pSelectedUnit);
  --print("first ttrying form corp "..pSelectedUnit);
  --while(TryFormCorp(pSelectedUnit, unitList)) do
  --  print("trying form corp "..pSelectedUnit);
  --  local unitList  = Units.GetUnitsInPlotLayerID(  pCity:GetX(), pCity:GetY(), MapLayers.ANY );
  --  if unitList[0] == nil then return end;
  --  pSelectedUnit = unitList[0];
  --end

  --for i, pUnit in ipairs(unitList) do
  --  for i2, pUnit2 in ipairs(unitList) do
  --    tParameters[UnitCommandTypes.PARAM_UNIT_PLAYER] = pUnit:GetOwner();
  --    tParameters[UnitCommandTypes.PARAM_UNIT_ID] = pUnit:GetID();
  --    if (UnitManager.CanStartCommand( pUnit2, UnitCommandTypes.FORM_CORPS, tParameters)) then
  --      UnitManager.RequestCommand( pUnit2, UnitCommandTypes.FORM_CORPS, tParameters);
  --    end
  --  end
  --end
  --for key,value in pairs(pCity) do
  --    print("found member " .. key);
  --end

  --Horseman 1462612590
  --AutoFormCorps(pCity, 1462612590);
end
--
--
--
--print(GameInfo.Technologies[0]);
--for key,value in pairs(GameInfo.Technologies) do
--    print("found member " .. key);
--end

function Initialize()
  
  Controls.PauseCollapseList:Stop();
  Controls.PauseDismissWindow:Stop(); 
  --CreateCorrectTabs();
  Resize();

  --Controls.HideDisabled:RegisterCallback( Mouse.eLClick, ShowHideDisabled);
  --AutoSizeGridButton(Controls.HideDisabled,45,24,20,"H");
  -- ===== Event listeners =====

  Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);
  Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.PauseCollapseList:RegisterEndCallback( OnCollapseTheList );
  Controls.PauseDismissWindow:RegisterEndCallback( OnHide );
  ContextPtr:SetInitHandler( OnInit  );
  ContextPtr:SetInputHandler( OnInputHandler, true );
  ContextPtr:SetShutdown( OnShutdown );

  Events.CitySelectionChanged.Add( OnCitySelectionChanged );
  Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
  Events.UnitSelectionChanged.Add( OnUnitSelectionChanged );
  Events.LocalPlayerChanged.Add( OnLocalPlayerChanged );    
  
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
  LuaEvents.Tutorial_ProductionOpen.Add( OnTutorialProductionOpen );  
  
  Events.CityWorkerChanged.Add(Refresh);
  Events.CityProductionChanged.Add( OnCityProductionChanged );
  Events.CityProductionCompleted.Add(OnCityProductionCompleted);

  LuaEvents.QUI_Option_ToggleCowboy.Add( OnToggleCowboy );
  LuaEvents.QUI_Option_ToggleBadCowboy.Add( OnToggleBadCowboy );
end
Initialize();

