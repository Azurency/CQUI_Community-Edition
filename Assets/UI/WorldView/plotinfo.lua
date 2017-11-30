-- ===========================================================================
--  Plot information
--  Handles: plot purchasing, resources, etc...
-- ===========================================================================
include("InstanceManager");
include("AdjacencyBonusSupport");
include("SupportFunctions");
include("Civ6Common"); -- AutoSizeGridButton
include("CitySupport");

-- ===========================================================================
--  CONSTANTS
-- ===========================================================================
local PADDING_SWAP_BUTTON   :number = 24;
local KEY_PLOT_PURCHASE     :string = "PLOT_PURCHASE";
local KEY_CITIZEN_MANAGEMENT  :string = "CITIZEN_MANAGEMENT";
local KEY_DISTRICT_PLACEMENT  :string = "DISTRICT_PLACEMENT";
local KEY_SWAP_TILE_OWNER   :string = "SWAP_TILE_OWNER";
local YIELD_NUMBER_VARIATION  :string = "Yield_Variation_";
local YIELD_VARIATION_MANY    :string = "Yield_Variation_Many";
local YIELD_VARIATION_MAP   :table = {
  YIELD_FOOD      = "Yield_Food_",
  YIELD_PRODUCTION  = "Yield_Production_",
  YIELD_GOLD      = "Yield_Gold_",
  YIELD_SCIENCE   = "Yield_Science_",
  YIELD_CULTURE   = "Yield_Culture_",
  YIELD_FAITH     = "Yield_Faith_",
};
local CITY_CENTER_DISTRICT_INDEX = GameInfo.Districts["DISTRICT_CITY_CENTER"].Index;

-- ===========================================================================
--  MEMBERS
-- ===========================================================================
local m_PlotIM        :table = InstanceManager:new( "InfoInstance", "Anchor", Controls.PlotInfoContainer );
local m_uiWorldMap      :table = {};
local m_uiPurchase      :table = {};  -- Purchase plots showing
local m_uiCitizens      :table = {};  -- Citizens showing
local m_uiSwapTiles     :table = {};  -- Swap tiles showing
local m_kLensMask     :table = {};  -- IDs of lenses that are not mask shadowed

-- CQUI Members
local CQUI_WorkIconSize: number = 48;
local CQUI_WorkIconAlpha = .60;
local CQUI_SmartWorkIcon: boolean = true;
local CQUI_SmartWorkIconSize: number = 64;
local CQUI_SmartWorkIconAlpha = .45;
local CQUI_isMouseDragging = false;
local CQUI_hasMouseDragged = false;

function CQUI_OnSettingsUpdate()
  CQUI_WorkIconSize = GameConfiguration.GetValue("CQUI_WorkIconSize");
  CQUI_WorkIconAlpha = GameConfiguration.GetValue("CQUI_WorkIconAlpha") / 100;
  CQUI_SmartWorkIcon = GameConfiguration.GetValue("CQUI_SmartWorkIcon");
  CQUI_SmartWorkIconSize = GameConfiguration.GetValue("CQUI_SmartWorkIconSize");
  CQUI_SmartWorkIconAlpha = GameConfiguration.GetValue("CQUI_SmartWorkIconAlpha") / 100;
end

-- ===========================================================================
function OnClickCitizen( plotId:number )

  local pSelectedCity :table = UI.GetHeadSelectedCity();
  local kPlot     :table = Map.GetPlotByIndex(plotId);
  local tParameters :table = {};
  tParameters[CityCommandTypes.PARAM_MANAGE_CITIZEN] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_MANAGE_CITIZEN);
  tParameters[CityCommandTypes.PARAM_X] = kPlot:GetX();
  tParameters[CityCommandTypes.PARAM_Y] = kPlot:GetY();

  local tResults :table = CityManager.RequestCommand( pSelectedCity, CityCommandTypes.MANAGE, tParameters );
  return true;
end

-- ===========================================================================
function OnClickSwapTile( plotId:number )
  local pSelectedCity :table = UI.GetHeadSelectedCity();
  local kPlot     :table = Map.GetPlotByIndex(plotId);
  local tParameters :table = {};
  tParameters[CityCommandTypes.PARAM_SWAP_TILE_OWNER] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_SWAP_TILE_OWNER);
  tParameters[CityCommandTypes.PARAM_X] = kPlot:GetX();
  tParameters[CityCommandTypes.PARAM_Y] = kPlot:GetY();

  local tResults :table = CityManager.RequestCommand( pSelectedCity, CityCommandTypes.SWAP_TILE_OWNER, tParameters );

  -- CQUI update citizens, data and real housing for both cities
  CQUI_UpdateCitiesCitizensWhenSwapTiles(pSelectedCity);    -- CQUI update citizens and data for a city that is a new tile owner
  local pCity = Cities.GetPlotPurchaseCity(kPlot);    -- CQUI a city that was a previous tile owner
  CQUI_UpdateCitiesCitizensWhenSwapTiles(pCity);    -- CQUI update citizens and data for a city that was a previous tile owner
  return true;
end

-- ===========================================================================
function OnClickPurchasePlot( plotId:number )

  -- AZURENCY : if we're dragging, don't purchase
  if CQUI_isMouseDragging and CQUI_hasMouseDragged then
    return
  end

  local isUsingDistrictPlacementFilter :boolean = (UI.GetInterfaceMode() == InterfaceModeTypes.DISTRICT_PLACEMENT);
  local isUsingBuildingPlacementFilter :boolean = (UI.GetInterfaceMode() == InterfaceModeTypes.BUILDING_PLACEMENT);
  local kPlot :table = Map.GetPlotByIndex(plotId);

  local tParameters = {};
  tParameters[CityCommandTypes.PARAM_PLOT_PURCHASE] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_PLOT_PURCHASE);
  tParameters[CityCommandTypes.PARAM_X] = kPlot:GetX();
  tParameters[CityCommandTypes.PARAM_Y] = kPlot:GetY();

  local pSelectedCity = UI.GetHeadSelectedCity();
  if pSelectedCity ~= nil then
    if (CityManager.CanStartCommand( pSelectedCity, CityCommandTypes.PURCHASE, tParameters)) then
      CityManager.RequestCommand( pSelectedCity, CityCommandTypes.PURCHASE, tParameters);
      UI.PlaySound("Purchase_Tile");
    end
  else
    if not isUsingDistrictPlacementFilter and not isUsingBuildingPlacementFilter then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
  end

  -- NOTE: Plot changes may not have occured yet; so if staying in this mode
  --     after a plot puchase (e.g., buying plot for district placement)
  --     you must wait for the event raised from the gamecore before figuring
  --     out which plots need a display.

  OnClickCitizen();    -- CQUI update selected city citizens and data
  return true;
end

-- ===========================================================================
--  Animation of coin rotating finished, either stop (if mouse is gone)
--  or spin it again if mouse is still on top of it.
-- ===========================================================================
function OnSpinningCoinAnimDone( pControl:table )
  if pControl:HasMouseOver() then
    pControl:SetToBeginning();
    pControl:Play();
  else
    pControl:Stop();
  end
end

-- ===========================================================================
function OnSpinningCoinAnimMouseEnter( pControl:table )
  if pControl:IsStopped() then
    pControl:SetToBeginning();
  end
  pControl:Play();
end

-- ===========================================================================
function ShowPurchases()

  -- Only subset of plots are shown if in district placement bonus mode.
  local isUsingDistrictPlacementFilter = (UI.GetInterfaceMode() == InterfaceModeTypes.DISTRICT_PLACEMENT);
  local isUsingBuildingPlacementFilter = (UI.GetInterfaceMode() == InterfaceModeTypes.BUILDING_PLACEMENT);

  local district :table;
  if isUsingDistrictPlacementFilter then
    local districtHash :number = UI.GetInterfaceModeParameter(CityOperationTypes.PARAM_DISTRICT_TYPE);
    district = GameInfo.Districts[districtHash];
  end

  local building :table;
  if isUsingBuildingPlacementFilter then
    local buildingHash :number = UI.GetInterfaceModeParameter(CityOperationTypes.PARAM_BUILDING_TYPE);
    building = GameInfo.Buildings[buildingHash];
  end

  local pSelectedCity :table = UI.GetHeadSelectedCity();
  if pSelectedCity == nil then
    -- Add error message here
    return;
  end

  local pCityCulture          :table  = pSelectedCity:GetCulture();
  local pNextPlotID           :number = pCityCulture:GetNextPlot();
  local TurnsUntilExpansion   :number = pCityCulture:GetTurnsUntilExpansion();

  local tParameters :table = {};
  tParameters[CityCommandTypes.PARAM_PLOT_PURCHASE] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_PLOT_PURCHASE);

  local tResults  :table = CityManager.GetCommandTargets( pSelectedCity, CityCommandTypes.PURCHASE, tParameters );
  if tResults == nil then
    -- Add error message here
    return;
  end

  m_kLensMask[KEY_PLOT_PURCHASE] = {};
  local tPlots  :table = tResults[CityCommandResults.PLOTS];
  if (tPlots ~= nil and table.count(tPlots) ~= 0) then
    local playerTreasury:table  = Players[Game.GetLocalPlayer()]:GetTreasury();
    local playerGold  :number = playerTreasury:GetGoldBalance();
    local cityGold    :table  = pSelectedCity:GetGold();

    for i,plotId in pairs(tPlots) do
      local kPlot :table = Map.GetPlotByIndex(plotId);
      if  (not isUsingDistrictPlacementFilter and not isUsingBuildingPlacementFilter) or
        (isUsingDistrictPlacementFilter and kPlot:CanHaveDistrict(district.Index, pSelectedCity:GetOwner(), pSelectedCity:GetID())) or
        (isUsingBuildingPlacementFilter and kPlot:CanHaveWonder(building.Index, pSelectedCity:GetOwner(), pSelectedCity:GetID())) then

        local index:number = kPlot:GetIndex();
        local pInstance:table = GetInstanceAt( index );
        if pInstance ~= nil then
          local goldCost = cityGold:GetPlotPurchaseCost( index );
          pInstance.PurchaseButton:SetText(tostring(goldCost));
          AutoSizeGridButton(pInstance.PurchaseButton,51,30,25,"H");
          pInstance.PurchaseButton:SetDisabled( goldCost > playerGold );
          if( goldCost > playerGold) then
            pInstance.PurchaseButton:GetTextControl():SetColorByName("TopBarValueCS");
          else
            pInstance.PurchaseButton:GetTextControl():SetColorByName("ResGoldLabelCS");
          end
          pInstance.PurchaseButton:RegisterCallback( Mouse.eLClick, function() OnClickPurchasePlot( index ); end );
          pInstance.PurchaseAnim:SetColor( (goldCost > playerGold ) and 0xbb808080 or 0xffffffff ) ;
          pInstance.PurchaseAnim:RegisterEndCallback( OnSpinningCoinAnimDone );
          if (goldCost > playerGold ) then
            pInstance.PurchaseButton:ClearMouseEnterCallback();
            pInstance.PurchaseButton:SetToolTipString( Locale.Lookup("LOC_PLOTINFO_YOU_NEED_MORE_GOLD_TO_PURCHASE", goldCost - math.floor(playerGold) ));
          else
            pInstance.PurchaseButton:RegisterMouseEnterCallback( function() OnSpinningCoinAnimMouseEnter(pInstance.PurchaseAnim); end );
            pInstance.PurchaseButton:SetToolTipString("");
          end
          pInstance.PurchaseButton:SetHide( false );
          table.insert( m_uiPurchase, pInstance );
        else
          UI.DataError("Failed to get instance for plot purchase button with index #"..tostring(kPlot:GetIndex()));
        end
        table.insert(m_kLensMask[KEY_PLOT_PURCHASE], plotId);
      end
    end
  else
    local pInstance:table = GetInstanceAt( pNextPlotID );
    if pInstance ~= nil then
      table.insert( m_uiPurchase, pInstance );
    end
  end

  if not isUsingDistrictPlacementFilter and not isUsingBuildingPlacementFilter then
    local tParameters :table = {};
    tParameters[CityCommandTypes.PARAM_PLOT_PURCHASE] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_PLOT_PURCHASE);

    -- Highlight the plots available for purchase
    local tResults :table = CityManager.GetCommandTargets( pSelectedCity, CityCommandTypes.PURCHASE, tParameters );
    if (tResults[CityCommandResults.PLOTS] ~= nil and #tResults[CityCommandResults.PLOTS] ~= 0) then

      for _,plotId in ipairs(tResults[CityCommandResults.PLOTS]) do
        table.insert(m_kLensMask[KEY_PLOT_PURCHASE], plotId);
      end

      -- Add city plots to hex table and call lens system to darken non-city / non-purchasable plots.
      local kCityPlots :table = Map.GetCityPlots():GetPurchasedPlots( pSelectedCity );
      for _,plotId in pairs(kCityPlots) do
        --table.insert(tResults[CityCommandResults.PLOTS], plotId);
        --local pInstance:table = GetInstanceAt( plotId );        -- Ensures an instance is created.  TODO: Revisit; just create one per hex?
        table.insert(m_kLensMask[KEY_PLOT_PURCHASE], plotId);
      end
    end
  end
end

-- ===========================================================================
function ShowCitizens()
  ShowSwapTiles();

  local pSelectedCity :table = UI.GetHeadSelectedCity();
  if pSelectedCity == nil then
    -- Add error message here
    return;
  end

  local tParameters :table = {};
  tParameters[CityCommandTypes.PARAM_MANAGE_CITIZEN] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_MANAGE_CITIZEN);

  local tResults  :table = CityManager.GetCommandTargets( pSelectedCity, CityCommandTypes.MANAGE, tParameters );
  if tResults == nil then
    -- Add error message here
    return;
  end

  local tPlots    :table = tResults[CityCommandResults.PLOTS];
  local tUnits    :table = tResults[CityCommandResults.CITIZENS];
  local tMaxUnits   :table = tResults[CityCommandResults.MAX_CITIZENS];
  local tLockedUnits  :table = tResults[CityCommandResults.LOCKED_CITIZENS];
  if tPlots ~= nil and (table.count(tPlots) > 0) then

    m_kLensMask[KEY_CITIZEN_MANAGEMENT] = {};

    for i,plotId in pairs(tPlots) do

      table.insert(m_kLensMask[KEY_CITIZEN_MANAGEMENT], plotId);

      local kPlot :table = Map.GetPlotByIndex(plotId);
      local index:number = kPlot:GetIndex();
      local pInstance:table = GetInstanceAt( index );

      if pInstance ~= nil and kPlot:IsCity() == false then
      local isCityCenterPlot = kPlot:GetDistrictType() == CITY_CENTER_DISTRICT_INDEX;
        table.insert( m_uiCitizens, pInstance );
        pInstance.CitizenButton:SetVoid1( index );
        pInstance.CitizenButton:RegisterCallback(Mouse.eLClick, OnClickCitizen );
        --pInstance.CitizenButton:SetHide(false);
        --pInstance.CitizenButton:SetDisabled( false );
        --pInstance.CitizenButton:SetSizeVal(48, 48);
        pInstance.CitizenButton:SetHide(isCityCenterPlot);
        pInstance.CitizenButton:SetDisabled(isCityCenterPlot);

        local numUnits:number = tUnits[i];
        local maxUnits:number = tMaxUnits[i];

        --CQUI Citizen buttons tweaks
        if(CQUI_SmartWorkIcon and numUnits >= 1) then
          pInstance.CitizenButton:SetSizeVal(CQUI_SmartWorkIconSize,CQUI_SmartWorkIconSize);
          pInstance.CitizenButton:SetAlpha(CQUI_SmartWorkIconAlpha);
        else
          pInstance.CitizenButton:SetSizeVal(CQUI_WorkIconSize,CQUI_WorkIconSize);
          pInstance.CitizenButton:SetAlpha(CQUI_WorkIconAlpha);
        end

        if(numUnits >= 1) then
          pInstance.CitizenButton:SetTextureOffsetVal(0, 256);
        else
          pInstance.CitizenButton:SetTextureOffsetVal(0, 0);
        end

        if(maxUnits > 1) then
          --[[ TODO: Add back for Patch2, wasn't in due to missing TEXT lock.
          local toolTip:string = Locale.Lookup("LOC_HUD_CITY_SPECIALISTS", numUnits, maxUnits);
          pInstance.CitizenMeterBG:SetToolTipString( toolTip );
          --]]
          pInstance.CitizenMeterBG:SetHide(false);
          pInstance.CurrentAmount:SetText(numUnits);
          pInstance.TotalAmount:SetText(maxUnits);
          pInstance.CitizenMeter:SetPercent(numUnits / maxUnits);
        else
          pInstance.CitizenMeterBG:SetHide(true);
        end
        if(tLockedUnits[i] > 0) then
          pInstance.LockedIcon:SetHide(false);
        else
          pInstance.LockedIcon:SetHide(true);
        end
      end
    end
  end
end

-- ===========================================================================
function ShowSwapTiles()
  local pSelectedCity :table = UI.GetHeadSelectedCity();
  if pSelectedCity == nil then
    -- Add error message here
    return;
  end

  local tParameters :table = {};
  tParameters[CityCommandTypes.PARAM_SWAP_TILE_OWNER] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_SWAP_TILE_OWNER);

  local tResults  :table = CityManager.GetCommandTargets( pSelectedCity, CityCommandTypes.SWAP_TILE_OWNER, tParameters );
  if tResults == nil then
    -- Add error message here
    return;
  end

  local tPlots    :table = tResults[CityCommandResults.PLOTS];
  if tPlots ~= nil and (table.count(tPlots) > 0) then

    m_kLensMask[KEY_SWAP_TILE_OWNER] = {};

    for i,plotId in pairs(tPlots) do

      table.insert(m_kLensMask[KEY_SWAP_TILE_OWNER], plotId);

      local kPlot :table = Map.GetPlotByIndex(plotId);
      local index:number = kPlot:GetIndex();
      local pInstance:table = GetInstanceAt( index );
      if pInstance ~= nil then
        table.insert( m_uiSwapTiles, pInstance );

        pInstance.SwapTileOwnerButton:SetVoid1(index);
        pInstance.SwapTileOwnerButton:RegisterCallback(Mouse.eLClick, OnClickSwapTile);

        pInstance.SwapTileOwnerButton:SetHide(false);
        pInstance.SwapTileOwnerButton:SetSizeX(pInstance.SwapLabel:GetSizeX() + PADDING_SWAP_BUTTON);
      end
    end
  end
end

-- ===========================================================================
--  Yield Icons
-- ===========================================================================

-- ===========================================================================
function GetPlotYields(plotId:number, yields:table)

  local plot:table= Map.GetPlotByIndex(plotId);

  -- Do not show plot yields for districts
  local districtType = plot:GetDistrictType();
  if districtType ~= -1 and districtType ~= CITY_CENTER_DISTRICT_INDEX then
    return;
  end

  for row in GameInfo.Yields() do
    local yieldAmt:number = plot:GetYield(row.Index);
    if yieldAmt > 0 then
      local clampedYieldAmount:number = yieldAmt > 5 and 5 or yieldAmt;
      local yieldType:string = YIELD_VARIATION_MAP[row.YieldType] .. clampedYieldAmount;
      local plots:table = yields[yieldType];
      if plots == nil then
        plots = { data = {}, variations = {}, yieldType=row.YieldType };
        yields[yieldType] = plots;
      end
      table.insert(plots.data, plotId);

      -- Variations are used to overlay a number from 6 - 12 on top of largest yield icon (5)
      if yieldAmt > 5 then
        if yieldAmt > 11 then
          table.insert(plots.variations, { YIELD_VARIATION_MANY, plotId });
        else
          table.insert(plots.variations, { YIELD_NUMBER_VARIATION .. yieldAmt, plotId });
        end
      end
    end
  end
end

-- ===========================================================================
function UpdateYieldIcons(yields:table)

  -- Events are sent per yield type, not per hex
  for row in GameInfo.Yields() do
    for key, plots in pairs(yields) do
      if plots.yieldType == row.YieldType then
        -- When using the WorldBuilder playerID is -1 so pass in 0 as a valid playerID
        if GameConfiguration.IsWorldBuilderEditor() then
          UILens.SetLayerHexesArea(LensLayers.YIELD_ICONS, 0, plots.data, plots.variations, key);
        else
          UILens.SetLayerHexesArea(LensLayers.YIELD_ICONS, Game.GetLocalPlayer(), plots.data, plots.variations, key);
        end
      end
    end
  end
end

-- ===========================================================================
function InitYieldIcons()

  local yields:table = {};
  local count:number = Map.GetPlotCount();

  for plotId:number = 0, count-1, 1 do
    GetPlotYields(plotId, yields);
  end

  UpdateYieldIcons(yields);
end

function CQUI_ResetYieldIcons(yieldIDs:table)

  local yields:table = {};
  local count:number = Map.GetPlotCount();

  for i, plotId in ipairs(yieldIDs) do
    GetPlotYields(plotId, yields);
  end

  UpdateYieldIcons(yields);
end

-- ===========================================================================
local m_PlotYieldsChanged = {};
function OnPlotYieldChanged(x, y)

  local plot:table = Map.GetPlot(x,y);
  if plot ~= nil then
    table.insert(m_PlotYieldsChanged, plot:GetIndex());
  end
end

-- ===========================================================================
function OnMapYieldsChanged()

  if m_PlotYieldsChanged == nil or #m_PlotYieldsChanged == 0 then
    return;
  end

  local bCityPlotYieldsShown:boolean = UILens.IsLayerOn( LensLayers.CITY_YIELDS );
  if bCityPlotYieldsShown then
    HideCityYields();
  end

  local yields:table = {};

  for i, plotId in ipairs(m_PlotYieldsChanged) do
    GetPlotYields(plotId, yields);
  end

  UILens.ClearHexes(LensLayers.YIELD_ICONS, m_PlotYieldsChanged);
  UpdateYieldIcons(yields);

  m_PlotYieldsChanged = {};

  if bCityPlotYieldsShown then
    ShowCityYields();
  end
end

-- ===========================================================================
function OnDistrictAddedToMap( playerID: number, districtID : number, cityID :number, districtX : number, districtY : number, districtType:number )

  if districtType ~= CITY_CENTER_DISTRICT_INDEX then
    OnPlotYieldChanged(districtX, districtY);
    OnMapYieldsChanged();
    -- UI.DeselectAllCities();

    -- CQUI update citizens, data and real housing for close cities within 4 tiles when city founded
    -- we use it only to update real housing for a city that loses a 3rd radius tile to a city that is founded within 4 tiles
  elseif playerID == Game.GetLocalPlayer() then
    local kCity = CityManager.GetCity(playerID, cityID);
    CQUI_UpdateCloseCitiesCitizensWhenCityFounded(kCity);
  end
end

-- ===========================================================================
function OnBuildingAddedToMap( plotX:number, plotY:number, buildingType:number, misc1, misc2, misc3 )
end

-- ===========================================================================
function OnDistrictRemovedFromMap( playerID: number, districtID : number, cityID :number, districtX : number, districtY : number, districtType:number )

  if districtType ~= CITY_CENTER_DISTRICT_INDEX then
    OnPlotYieldChanged(districtX, districtY);
    OnMapYieldsChanged();
  end
end

-- ===========================================================================
--  Debug Stress Test
-- ===========================================================================
function DebugStressTest()
  -- Create a lot of instances
  local MAX_X:number = 128; --128
  local MAX_Y:number = 60;  --80
  local sizex,sizey  = UIManager:GetScreenSizeVal();
  sizex = math.floor(sizex / MAX_X);
  sizey = math.floor(sizey / MAX_Y);
  for y= 0, MAX_Y, 1 do
    for x= 0, MAX_X, 1 do
      local pInst:table = {};
      ContextPtr:BuildInstance("DebugPixelInstance",pInst);
      pInst.Pixel:SetOffsetVal(x*sizex,y*sizey);
      pInst.Pixel:SetSizeVal(sizex,sizey);
      pInst.Pixel:SetColor( RGBAValuesToABGRHex( (x/MAX_X), (y/MAX_Y), ((x+y)%2), 0.5) );
    end
  end
end

-- ===========================================================================
function HideCitizens()
  HideSwapTiles();

  for _,kInstance in ipairs(m_uiCitizens) do
    kInstance.CitizenButton:SetHide( true );
    kInstance.CitizenMeterBG:SetHide( true );
    kInstance.LockedIcon:SetHide( true );
  end
  m_uiCitizens = {};

  UILens.ClearLayerHexes( LensLayers.CITIZEN_MANAGEMENT );
  m_kLensMask[KEY_CITIZEN_MANAGEMENT] = nil;
end

-- ===========================================================================
function HideSwapTiles()
  for _,kInstance in ipairs(m_uiSwapTiles) do
    kInstance.SwapTileOwnerButton:SetHide( true );
  end
  m_uiSwapTiles = {};

  m_kLensMask[KEY_SWAP_TILE_OWNER] = nil;
end

-- ===========================================================================
function HidePurchases()
  for _,pInstance in ipairs(m_uiPurchase) do
    pInstance.PurchaseButton:SetHide( true );
    pInstance.CQUI_NextPlotButton:SetHide( true );
    -- NOTE: This plot can't be returned to the instnace manager
    -- (ReleaseInstance) unless the local cached version in (m_uiWorldMap)
    -- is removed too; which is only safe if NOTHING else utilizing this
    -- plot info instance.
  end
  m_uiPurchase = {};

  UILens.ClearLayerHexes( LensLayers.PURCHASE_PLOT );
  m_kLensMask[KEY_PLOT_PURCHASE] = nil;
end

-- ===========================================================================
function ShowYieldIcons()
  UILens.ToggleLayerOn( LensLayers.YIELD_ICONS );
end

-- ===========================================================================
function HideYieldIcons()
  UILens.ToggleLayerOff( LensLayers.YIELD_ICONS );
end

-- ===========================================================================
function ShowCityYields()

  local yields:table = {};
  local plots:table = AggregateLensHexes({ KEY_PLOT_PURCHASE, KEY_CITIZEN_MANAGEMENT, KEY_DISTRICT_PLACEMENT, KEY_SWAP_TILE_OWNER });

  for _, plotId in ipairs(plots) do
    local plot:table = Map.GetPlotByIndex(plotId);
    for row in GameInfo.Yields() do
      local yieldAmt:number = plot:GetYield(row.Index);
      if yieldAmt > 0 then
        table.insert(yields, plotId);
      end
    end
  end

  UILens.SetLayerHexesArea(LensLayers.CITY_YIELDS, Game.GetLocalPlayer(), yields);
end

-- ===========================================================================
function HideCityYields()
  UILens.ClearLayerHexes( LensLayers.CITY_YIELDS );
end

-- ===========================================================================
-- Refresh displayed plots for city yields
function RefreshCityYieldsPlotList()
  if UILens.IsLayerOn( LensLayers.CITY_YIELDS ) then
    HideCityYields();
    ShowCityYields();
  end
end

-- ===========================================================================
-- Refresh displayed purchase plots
function RefreshPurchasePlots()
  if UILens.IsLayerOn( LensLayers.PURCHASE_PLOT ) then
    HidePurchases();    -- Out with the old
    ShowPurchases();    -- In with the new
    RealizeShadowMask();
  end
end

-- ===========================================================================
-- Refresh displayed plot workers
function RefreshCitizenManagement()
  if UILens.IsLayerOn( LensLayers.CITIZEN_MANAGEMENT ) then
    HideCitizens();
    ShowCitizens();
    RealizeShadowMask();
  end
end

-- ===========================================================================
--  Obtain an existing instance of plot info or allocate one if it doesn't
--  already exist.
--  plotIndex Game engine index of the plot
-- ===========================================================================
function GetInstanceAt( plotIndex:number )
  local pInstance:table = m_uiWorldMap[plotIndex];
  if pInstance == nil then
    pInstance = m_PlotIM:GetInstance();
    m_uiWorldMap[plotIndex] = pInstance;
    local worldX:number, worldY:number = UI.GridToWorld( plotIndex );
    pInstance.Anchor:SetWorldPositionVal( worldX, worldY, 20 );
    pInstance.Anchor:SetHide( false );
  end
  return pInstance;
end

-- ===========================================================================
function ReleaseInstanceAt( plotIndex:number)
  local pInstance :table = m_uiWorldMap[plotIndex];
  if pInstance ~= nil then
    pInstance.Anchor:SetHide( true );
    -- m_AdjacentPlotIconIM:ReleaseInstance( pInstance );
    m_uiWorldMap[plotIndex] = nil;
  end
end

-- ===========================================================================
--  Clear all graphics and all district yield icons for all layers.
-- ===========================================================================
function ClearEverything()
  for key,pInstance in pairs(m_uiWorldMap) do
    pInstance.Anchor:SetHide( true );
    m_PlotIM:ReleaseInstance( pInstance );
    m_uiWorldMap[key] = nil;
  end

  HideYieldIcons();
end

-- ===========================================================================
--  Add/remove plot anchors based on visibility to the player/observer.
-- ===========================================================================
function Rebuild()
  -- This is unneccessary and causes some significant late game hangs

  --local eObserverID   :number = Game.GetLocalObserver();
  --local pLocalPlayerVis :table = PlayerVisibilityManager.GetPlayerVisibility(eObserverID);
  --if(pLocalPlayerVis ~= nil) then
    --local iCount  :number  = Map.GetPlotCount();
    --for plotIndex :number = 0, iCount-1, 1 do
--
      --local visibilityType:number = pLocalPlayerVis:GetState(plotIndex);
      --if (visibilityType == RevealedState.HIDDEN) then
        --ReleaseInstanceAt(plotIndex);
      --else
        --if (visibilityType == RevealedState.REVEALED) then
          ----ChangeToMidFog(plotIndex); -- Add back once plotInfo controls all
          --GetInstanceAt( plotIndex );
        --else
          --if (visibilityType == RevealedState.VISIBLE) then
            ----ChangeToVisible(plotIndex); -- Add back once plotInfo controls all
            --GetInstanceAt( plotIndex );
          --end
        --end
      --end
    --end
  --end
end


-- ===========================================================================
--  UI Event
--  Generate information for every plot
-- ===========================================================================
function OnInit( isHotload:boolean )
  -- Note MAP does not return accurate coordinates when this first is called,
  -- due to async loading... best to wait until player change event to populate.
  if isHotload then
    Rebuild();
  else
    InitYieldIcons();
  end
end


-- ===========================================================================
--  UI Event
--  Handle the UI shutting down.
-- ===========================================================================
function OnShutdown()
  ClearEverything();
  m_PlotIM:DestroyInstances();
end

-- ===========================================================================
--  Gamecore Event
--  Player just made a plot purchase
-- ===========================================================================
function OnCityMadePurchase(owner:number, cityID:number, plotX:number, plotY:number, purchaseType, objectType)
  if owner ~= Game.GetLocalPlayer() then
    return;
  end

  -- If the lens layer isn't on, the city grew naturally.
  RefreshPurchasePlots();
  RefreshCityYieldsPlotList();
end

-- ===========================================================================
--  Gamecore Event
-- ===========================================================================
function OnCitySelectionChanged(owner:number, ID:number, i:number, j:number, k:number, bSelected:boolean, bEditable:boolean)
  if owner == Game.GetLocalPlayer() then

    RefreshPurchasePlots();
    RefreshCitizenManagement();
    RefreshCityYieldsPlotList();

    print_debug("PlotInfo::OnCitySelectionChanged",owner, ID, i, j, k, bSelected, bEditable);   --??TRON debug
  end
end

-- ===========================================================================
--  Gamecore Event
-- ===========================================================================
function OnCityWorkerChanged( owner:number, cityID:number, plotX:number, plotY:number )
  if owner == Game.GetLocalPlayer() then
    RefreshCitizenManagement();
    LuaEvents.PlotInfo_UpdatePlotTooltip(true);
  end
end

-- ===========================================================================
--  Gamecore Event
-- ===========================================================================
function OnCityTileOwnershipChanged(owner:number, cityID:number)
  if owner == Game.GetLocalPlayer() then
    RefreshPurchasePlots();
    RefreshCitizenManagement();
  end
end

-- ===========================================================================
--  Determine if the camera tilt should be on/off
-- ===========================================================================
function RealizeTilt()
  if  UILens.IsLayerOn(LensLayers.PURCHASE_PLOT) or
    UILens.IsLayerOn(LensLayers.CITIZEN_MANAGEMENT) then
    if not UI.IsFixedTiltModeOn() then
      UI.SetFixedTiltMode( true );
    end
  else
    if UI.IsFixedTiltModeOn() then
      UI.SetFixedTiltMode( false );
    end
  end
end


-- ===========================================================================
--  Send to the lens system any hexes that shouldn't be darkened
-- ===========================================================================
function RealizeShadowMask()
  -- No IDs, clear
  if table.count(m_kLensMask) < 1 then
    m_kLensMask = {};
    UILens.ClearLayerHexes( LensLayers.MAP_HEX_MASK );
    return;
  end

  local kNotToMask:table = AggregateLensHexes({ KEY_PLOT_PURCHASE, KEY_CITIZEN_MANAGEMENT, KEY_DISTRICT_PLACEMENT, KEY_SWAP_TILE_OWNER });

  UILens.ClearLayerHexes( LensLayers.MAP_HEX_MASK );
  UILens.SetLayerHexesArea( LensLayers.MAP_HEX_MASK, Game.GetLocalPlayer(), kNotToMask );
end

-- ===========================================================================
--  Combine all contents of a table containing sub-tables into a single
--  table of values.
-- ===========================================================================
function AggregateLensHexes(keys:table)
  local results:table = {};
  for _,key in ipairs(keys) do
    if m_kLensMask[key] ~= nil then
      for i=1,table.count(m_kLensMask[key]),1 do
        table.insert( results, m_kLensMask[key][i] );
      end
    end
  end
  return CQUI_RemoveDuplicates(results);
end

--Takes a table with duplicates and returns a new table without duplicates. Credit to vogomatix at stask exchange for the code
function CQUI_RemoveDuplicates(i:table)
  local hash = {};
  local o = {};
  for _,v in ipairs(i) do
    if (not hash[v]) then
        o[#o+1] = v;
        hash[v] = true;
    end
  end
  return o;
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnAddDistrictPlacementShadowHexes( kHexes:table )
  m_kLensMask[KEY_DISTRICT_PLACEMENT] = kHexes;
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnClearDistrictPlacementShadowHexes()
  m_kLensMask[KEY_DISTRICT_PLACEMENT] = nil;
end


-- ===========================================================================
--  Gamecore Event
--  Called once per layer that is turned on when a new lens is activated,
--  or when a player explicitly turns off the layer from the "player" lens.
-- ===========================================================================
function OnLensLayerOn( layerNum:number )
  if layerNum == LensLayers.CITIZEN_MANAGEMENT then
    ShowCitizens();
    RealizeShadowMask();
    --RealizeTilt();
    RefreshCityYieldsPlotList();
  elseif layerNum == LensLayers.PURCHASE_PLOT then
    ShowPurchases();
    RealizeShadowMask();
    --RealizeTilt();
    RefreshCityYieldsPlotList();
  elseif layerNum == LensLayers.CITY_YIELDS then
    ShowCityYields();
  end
end

-- ===========================================================================
--  Gamecore Event
--  Called once per layer that is turned on when a new lens is deactivated,
--  or when a player explicitly turns off the layer from the "player" lens.
-- ===========================================================================
function OnLensLayerOff( layerNum:number )
  if  layerNum == LensLayers.CITIZEN_MANAGEMENT then
    HideCitizens();
    RealizeShadowMask();
    --RealizeTilt();
    RefreshCityYieldsPlotList();
  elseif  layerNum == LensLayers.PURCHASE_PLOT then
    HidePurchases();
    RealizeShadowMask();
    --RealizeTilt();
    RefreshCityYieldsPlotList();
  elseif layerNum == LensLayers.CITY_YIELDS then
    HideCityYields();
  end
end


-- ===========================================================================
--  Gamecore Event
-- ===========================================================================
function OnLocalPlayerTurnBegin()
  m_kLensMask = {};   -- clear all entries
  RealizeShadowMask();
end

-- ===========================================================================
function OnPlayerTurnActivated( ePlayer:number, isFirstTimeThisTurn:boolean )
  if ePlayer == Game.GetLocalPlayer() then
    Rebuild();
  end
end


function KeyHandler( key:number )
  if key == Keys.VK_TAB then
    UILens.ClearLayerHexes( LensLayers.MAP_HEX_MASK );   -- ??TRON debug clear
    return true;
  end
  return false;
end

function OnInputHandler( pInputStruct:table )
  local uiMsg = pInputStruct:GetMessageType();
  if (uiMsg == KeyEvents.KeyUp) then return KeyHandler( pInputStruct:GetKey() ); end;

  -- AZURENCY : added drag awareness to handle the clic/drag on purchase button (from minimap.lua)
  -- Enable drag on LMB down
  if uiMsg == MouseEvents.LButtonDown then
    CQUI_isMouseDragging = true; -- Potential drag is in process
    CQUI_hasMouseDragged = false; -- There has been no actual dragging yet
    return false;
  -- Disable drag on LMB up (but only if mouse was previously dragging)
  elseif uiMsg == MouseEvents.LButtonUp and CQUI_isMouseDragging then
    CQUI_isMouseDragging = false;
    return false;
  -- If the mouse move and is dragging, it has dragged
  elseif uiMsg == MouseEvents.MouseMove and CQUI_isMouseDragging then
    CQUI_hasMouseDragged = true;
    return false;
  end

  return false;
end

-- ===========================================================================
-- CQUI update citizens, data and real housing for both cities when swap tiles
function CQUI_UpdateCitiesCitizensWhenSwapTiles(pCity)

  CityManager.RequestCommand(pCity, CityCommandTypes.SET_FOCUS, nil);

  local pCityID = pCity:GetID();
  LuaEvents.CQUI_CityInfoUpdated(pCityID);
end

-- ===========================================================================
-- CQUI update citizens, data and real housing for close cities within 4 tiles when city founded
-- we use it only to update real housing for a city that loses a 3rd radius tile to a city that is founded within 4 tiles
function CQUI_UpdateCloseCitiesCitizensWhenCityFounded(kCity)

  local m_pCity:table = Players[Game.GetLocalPlayer()]:GetCities();
  for i, pCity in m_pCity:Members() do
    if Map.GetPlotDistance(kCity:GetX(), kCity:GetY(), pCity:GetX(), pCity:GetY()) == 4 then
      CityManager.RequestCommand(pCity, CityCommandTypes.SET_FOCUS, nil);

      local pCityID = pCity:GetID();
      LuaEvents.CQUI_CityInfoUpdated(pCityID);
    end
  end
end

-- ===========================================================================
--
-- ===========================================================================
function Initialize()
  --  EVENT LISTENERS
  ContextPtr:SetInitHandler( OnInit );
  ContextPtr:SetInputHandler( OnInputHandler, true );
  ContextPtr:SetShutdown( OnShutdown );

  Events.CityMadePurchase.Add(    OnCityMadePurchase );
  Events.CitySelectionChanged.Add(  OnCitySelectionChanged );
  Events.CityWorkerChanged.Add(   OnCityWorkerChanged );
  Events.CityFocusChanged.Add(    OnCityWorkerChanged);
  Events.CityTileOwnershipChanged.Add(OnCityTileOwnershipChanged);
  Events.LensLayerOn.Add(       OnLensLayerOn );
  Events.LensLayerOff.Add(      OnLensLayerOff );
  Events.LocalPlayerTurnBegin.Add(  OnLocalPlayerTurnBegin );
  Events.PlayerTurnActivated.Add(   OnPlayerTurnActivated );
  Events.PlotYieldChanged.Add(        OnPlotYieldChanged );
  Events.MapYieldsChanged.Add(        OnMapYieldsChanged );
  Events.DistrictAddedToMap.Add(      OnDistrictAddedToMap );
  Events.DistrictRemovedFromMap.Add(  OnDistrictRemovedFromMap );
  Events.BuildingAddedToMap.Add(    OnBuildingAddedToMap );

  LuaEvents.StrategicView_MapPlacement_AddDistrictPlacementShadowHexes.Add( OnAddDistrictPlacementShadowHexes );
  LuaEvents.StrategicView_MapPlacement_ClearDistrictPlacementShadowHexes.Add( OnClearDistrictPlacementShadowHexes );
  LuaEvents.MinimapPanel_ShowYieldIcons.Add( ShowYieldIcons );
  LuaEvents.MinimapPanel_HideYieldIcons.Add( HideYieldIcons );
  LuaEvents.Tutorial_ShowYieldIcons.Add( ShowYieldIcons );
  LuaEvents.Tutorial_HideYieldIcons.Add( HideYieldIcons );

  if( UserConfiguration.ShowMapYield() ) then
    ShowYieldIcons();
  end

  LuaEvents.CQUI_ResetYieldIcons.Add( CQUI_ResetYieldIcons );
  LuaEvents.CQUI_SettingsUpdate.Add( CQUI_OnSettingsUpdate );
  LuaEvents.CQUI_SettingsInitialized.Add( CQUI_OnSettingsUpdate );

end
Initialize();
