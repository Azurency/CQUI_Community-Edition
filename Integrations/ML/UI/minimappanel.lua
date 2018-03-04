-- ===========================================================================
--  MINIMAP PANEL
-- ===========================================================================
include( "InstanceManager" );
include( "Civ6Common" );

-- ===========================================================================
--  MODDED LENS
-- ===========================================================================

g_ModLenses = {} -- Populated by ModLens_*.lua scripts
include( "modlens_", true )

local m_LensButtonIM:table = InstanceManager:new("LensButtonInstance", "LensButton", Controls.LensToggleStack)
local m_CurrentModdedLensOn:string = "NONE"

-- Settler Lens Variables
local m_SetterLensAlternateInverse:boolean = false;

-- ===========================================================================
--  CONSTANTS
-- ===========================================================================
local MINIMAP_COLLAPSED_OFFSETY     :number = -180;
local LENS_PANEL_OFFSET             :number = 50;
local MINIMAP_BACKING_PADDING_SIZEY :number = 54;

-- ===========================================================================
--  GLOBALS
-- ===========================================================================
m_shouldCloseLensMenu = true;    -- Controls when the Lens menu should be closed.

-- ===========================================================================
--  MEMBERS
-- ===========================================================================
--local m_OptionsButtonManager= InstanceManager:new( "MiniMapOptionButtonInstance", "Top",      Controls.OptionsStack );
local m_OptionButtons           :table = {};    -- option buttons indexed by buttonName.
local iZoomIncrement            :number = 2;
local m_isCollapsed             :boolean= false;
local bGridOn                   :boolean= true;
local m_ContinentsCreated       :boolean=false;
local m_MiniMap_xmloffsety      :number = 0;
local m_ContinentsCache         :table = {};
local m_kFlyoutControlIds       :table = { "MapOptions", "Lens", "MapPinList"}; -- Name of controls that are the backing for "flyout" menus.

local m_LensLayers:table = {
  LensLayers.HEX_COLORING_RELIGION,
  LensLayers.HEX_COLORING_CONTINENT,
  LensLayers.HEX_COLORING_APPEAL_LEVEL,
  LensLayers.HEX_COLORING_GOVERNMENT,
  LensLayers.HEX_COLORING_OWING_CIV,
  LensLayers.HEX_COLORING_WATER_AVAILABLITY
};

local m_ToggleReligionLensId    = Input.GetActionId("LensReligion");
local m_ToggleContinentLensId   = Input.GetActionId("LensContinent");
local m_ToggleAppealLensId      = Input.GetActionId("LensAppeal");
local m_ToggleSettlerLensId     = Input.GetActionId("LensSettler");
local m_ToggleGovernmentLensId  = Input.GetActionId("LensGovernment");
local m_TogglePoliticalLensId   = Input.GetActionId("LensPolitical");
local m_ToggleTourismLensId     = Input.GetActionId("LensTourism");
local m_Toggle2DViewId          = Input.GetActionId("Toggle2DView");

local m_isMouseDragEnabled      :boolean = true; -- Can the camera be moved by dragging on the minimap?
local m_isMouseDragging         :boolean = false; -- Was LMB clicked inside the minimap, and has not been released yet?
local m_hasMouseDragged         :boolean = false; -- Has there been any movements since m_isMouseDragging became true?
local m_wasMouseInMinimap       :boolean = false; -- Was the mouse over the minimap the last time we checked?

-- ===========================================================================
--  FUNCTIONS
-- ===========================================================================

-- CQUI Options Panel logic
function CQUI_OnToggleBindings(mode: number)
  Controls.CQUI_ToggleBindings0:SetCheck(false);
  Controls.CQUI_ToggleBindings1:SetCheck(false);
  Controls.CQUI_ToggleBindings2:SetCheck(false);
  if(mode == 0) then
  Controls.CQUI_ToggleBindings0:SetCheck(true);
  elseif(mode == 1) then
  Controls.CQUI_ToggleBindings1:SetCheck(true);
  elseif(mode == 2) then
  Controls.CQUI_ToggleBindings2:SetCheck(true);
  end
end

function CQUI_ToggleYieldIcons()
  -- CQUI: Toggle yield icons if option is enabled
  if(GameConfiguration.GetValue("CQUI_ToggleYieldsOnLoad")) then
  ToggleYieldIcons();
  end
end
-- ===========================================================================
function GetContinentsCache()
  if m_ContinentsCache == nil then
    m_ContinentsCache = Map.GetContinentsInUse();
  end
end

-- ===========================================================================
function OnZoomIn()
  UI.ZoomMap( iZoomIncrement );
end

-- ===========================================================================
function OnZoomOut()
  UI.ZoomMap( -iZoomIncrement );
end

-- ===========================================================================
function CloseAllFlyouts()
  for _,id in ipairs(m_kFlyoutControlIds) do
    local panelId = id.."Panel";        -- e.g LenPanel, MapOptionPanel, etc...
    local buttonId = id.."Button";
    if Controls[panelId] ~= nil then
      Controls[panelId]:SetHide( true );
    else
      UI.DataError("Minimap's CloseAllFlyouts() attempted to close '"..panelId.."' but the control doesn't exist in the XML.");
    end
    if Controls[buttonId] ~= nil then
      Controls[buttonId]:SetSelected( false );
    else
      UI.DataError("Minimap's CloseAllFlyouts() attempted to unselect'"..buttonId.."' but the control doesn't exist in the XML.");
    end
  end
end

-- ===========================================================================
--  Only show one "flyout" control at a time.
-- ===========================================================================
function RealizeFlyouts( pControl:table )
  if pControl:IsHidden() then
    return;     -- If target control is hidden, ignore the rest.
  end
  for _,id in ipairs(m_kFlyoutControlIds) do
    local panelId = id.."Panel";        -- e.g LenPanel, MapOptionPanel, etc...
    local buttonId = id.."Button";
    if Controls[panelId] ~= nil then
      if Controls[panelId] ~= pControl and Controls[panelId]:IsHidden()==false then
        Controls[panelId]:SetHide( true );
      end
      if Controls[panelId] ~= pControl then
        if Controls[buttonId]:IsSelected() then
          Controls[buttonId]:SetSelected( false );
        end
      else
        if not Controls[buttonId]:IsSelected() then
          Controls[buttonId]:SetSelected( true );
        end
      end
    else
      UI.DataError("Minimap's RealizeFlyouts() attempted to close '"..panelId.."' but the control doesn't exist in the XML.");
    end
  end
end

-- ===========================================================================
function RefreshMinimapOptions()
  Controls.ToggleYieldsButton:SetCheck(UserConfiguration.ShowMapYield());
  Controls.ToggleGridButton:SetCheck(bGridOn);
  Controls.ToggleResourcesButton:SetCheck(UserConfiguration.ShowMapResources());
end

-- ===========================================================================
function ToggleMapOptionsList()
  if Controls.MapOptionsPanel:IsHidden() then
    RefreshMinimapOptions();
  end
  Controls.MapOptionsPanel:SetHide( not Controls.MapOptionsPanel:IsHidden() );
  RealizeFlyouts(Controls.MapOptionsPanel);
  Controls.MapOptionsButton:SetSelected( not Controls.MapOptionsPanel:IsHidden() );
end

-- ===========================================================================
function OnToggleLensList()
  Controls.LensPanel:SetHide( not Controls.LensPanel:IsHidden() );
  RealizeFlyouts(Controls.LensPanel);
  Controls.LensButton:SetSelected( not Controls.LensPanel:IsHidden() );
  if Controls.LensPanel:IsHidden() then
    CloseLensList();
  else
    Controls.ReligionLensButton:SetHide(not GameCapabilities.HasCapability("CAPABILITY_LENS_RELIGION"));
    Controls.AppealLensButton:SetHide(not GameCapabilities.HasCapability("CAPABILITY_LENS_APPEAL"));
    Controls.GovernmentLensButton:SetHide(not GameCapabilities.HasCapability("CAPABILITY_LENS_GOVERNMENT"));
    Controls.WaterLensButton:SetHide(not GameCapabilities.HasCapability("CAPABILITY_LENS_SETTLER"));
    Controls.TourismLensButton:SetHide(not GameCapabilities.HasCapability("CAPABILITY_LENS_TOURISM"));
    Controls.LensToggleStack:CalculateSize();
    -- Controls.LensPanel:SetSizeY(Controls.LensToggleStack:GetSizeY() + LENS_PANEL_OFFSET);
  end
end

function CloseLensList()
  m_shouldCloseLensMenu = true;
  Controls.ReligionLensButton:SetCheck(false);
  Controls.ContinentLensButton:SetCheck(false);
  Controls.AppealLensButton:SetCheck(false);
  Controls.GovernmentLensButton:SetCheck(false);
  Controls.WaterLensButton:SetCheck(false);
  Controls.OwnerLensButton:SetCheck(false);
  Controls.TourismLensButton:SetCheck(false);

  -- Turn off each mod lens
  local i = 1
  local lensButtonInstance = m_LensButtonIM:GetAllocatedInstance(i)
  while lensButtonInstance ~= nil do
    lensButtonInstance.LensButton:SetCheck(false)
    i = i + 1
    lensButtonInstance = m_LensButtonIM:GetAllocatedInstance(i)
  end

  -- Hide each panel that exist for lens
  LuaEvents.ML_CloseLensPanels()

  if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
    UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
  end
end

-- ===========================================================================
function ToggleMapPinMode()
  Controls.MapPinListPanel:SetHide( not Controls.MapPinListPanel:IsHidden() );
  RealizeFlyouts(Controls.MapPinListPanel);
  Controls.MapPinListButton:SetSelected( not Controls.MapPinListPanel:IsHidden() );
end

-- ===========================================================================
function ToggleResourceIcons()
  UserConfiguration.ShowMapResources( not UserConfiguration.ShowMapResources() );
end

-- ===========================================================================
function ToggleYieldIcons()
  local showMapYield:boolean = not UserConfiguration.ShowMapYield();
  UserConfiguration.ShowMapYield( showMapYield );
  if showMapYield then
    LuaEvents.MinimapPanel_ShowYieldIcons();
  else
    LuaEvents.MinimapPanel_HideYieldIcons();
  end
end

-- ===========================================================================
function ToggleReligionLens()
  if Controls.ReligionLensButton:IsChecked() then
    UILens.SetActive("Religion");
    RefreshInterfaceMode();
  else
    m_shouldCloseLensMenu = false; --When toggling the lens off, shouldn't close the menu.
    if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
  end
end

-- ===========================================================================
function ToggleContinentLens()
  if Controls.ContinentLensButton:IsChecked() then
    UILens.SetActive("Continent");
    RefreshInterfaceMode();
  else
    m_shouldCloseLensMenu = false;
    if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
  end
end

-- ===========================================================================
function ToggleAppealLens()
  if Controls.AppealLensButton:IsChecked() then
    SetActiveModdedLens("VANILLA_APPEAL");

    -- Check if the appeal lens is already active. Needed to clear any modded lens
    if UILens.IsLayerOn(LensLayers.HEX_COLORING_APPEAL_LEVEL) then
      -- Unapply the appeal lens, so it can be cleared from the screen
      UILens.SetActive("Default");
    end

    UILens.SetActive("Appeal");
    RefreshInterfaceMode();
  else
    m_shouldCloseLensMenu = false;
    if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
    SetActiveModdedLens("NONE");
  end
end

-- ===========================================================================
function ToggleWaterLens()
  if Controls.WaterLensButton:IsChecked() then
    UILens.SetActive("WaterAvailability");
    RefreshInterfaceMode();
  else
    m_shouldCloseLensMenu = false;
    if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
  end
end

-- ===========================================================================
function ToggleGovernmentLens()
  if Controls.GovernmentLensButton:IsChecked() then
    UILens.SetActive("Government");
    RefreshInterfaceMode();
  else
    m_shouldCloseLensMenu = false;
    if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
  end
end

-- ===========================================================================
function ToggleOwnerLens()
  if Controls.OwnerLensButton:IsChecked() then
    UILens.SetActive("OwningCiv");
    RefreshInterfaceMode();
  else
    m_shouldCloseLensMenu = false;
    if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
  end
end

-- ===========================================================================
function ToggleTourismLens()
  if Controls.TourismLensButton:IsChecked() then
    UILens.SetActive("Tourism");
    RefreshInterfaceMode();
  else
    m_shouldCloseLensMenu = false;
    if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
  end
end

-- ===========================================================================
function ToggleGrid()
  bGridOn = not bGridOn;
  UI.ToggleGrid( bGridOn );
end

-- ===========================================================================
function Toggle2DView()
  if (UserConfiguration.GetValue("RenderViewIsLocked") ~= true) then
    if (UI.GetWorldRenderView() == WorldRenderView.VIEW_2D) then
      UI.SetWorldRenderView( WorldRenderView.VIEW_3D );
      Controls.SwitcherImage:SetTextureOffsetVal(0,0);
      UI.PlaySound("Set_View_3D");
    else
      UI.SetWorldRenderView( WorldRenderView.VIEW_2D );
      Controls.SwitcherImage:SetTextureOffsetVal(0,24);
      UI.PlaySound("Set_View_2D");
    end
    UI.PlaySound("Stop_Unit_Movement_Master");
  end
end

-- ===========================================================================
function OnPauseEnd()
  Controls.ExpandAnim:SetToBeginning();
end

-- ===========================================================================
function OnCollapseToggle()
  if ( m_isCollapsed ) then
    UI.PlaySound("Minimap_Open");
    Controls.ExpandButton:SetHide( true );
    Controls.ExpandAnim:SetEndVal(0, -Controls.MinimapContainer:GetOffsetY() - Controls.MinimapContainer:GetSizeY());
    Controls.ExpandAnim:SetToBeginning();
    Controls.ExpandAnim:Play();
    Controls.CompassArm:SetPercent(.25);
  else
    UI.PlaySound("Minimap_Closed");
    Controls.ExpandButton:SetHide( false );
    Controls.Pause:Play();
    Controls.CollapseAnim:SetEndVal(0, Controls.MinimapContainer:GetOffsetY() + Controls.MinimapContainer:GetSizeY());
    Controls.CollapseAnim:SetToBeginning();
    Controls.CollapseAnim:Play();
    Controls.CompassArm:SetPercent(.5);
  end
  m_isCollapsed = not m_isCollapsed;
  LuaEvents.ModLens_ReoffsetPanels( OnReoffsetPanel );
end

-- ===========================================================================
function OnMinimapImageSizeChanged()
  ResizeBacking();
  LuaEvents.ModLens_ReoffsetPanels( OnReoffsetPanel );
end

-- ===========================================================================
function ResizeBacking()
  Controls.MinimapBacking:SetSizeY(Controls.MinimapImage:GetSizeY() + MINIMAP_BACKING_PADDING_SIZEY);

  -- if the minimap is collapsed, shift it accordingly
  if ( m_isCollapsed ) then
    Controls.Pause:Play();
    Controls.CollapseAnim:SetEndVal(0, Controls.MinimapContainer:GetOffsetY() + Controls.MinimapContainer:GetSizeY());
    Controls.CollapseAnim:SetToEnd();
  end
end

-- ===========================================================================
function RefreshInterfaceMode()
  if UI.GetInterfaceMode() ~= InterfaceModeTypes.VIEW_MODAL_LENS then
    UI.SetInterfaceMode(InterfaceModeTypes.VIEW_MODAL_LENS);
  end
end

-- ===========================================================================
function OnLensLayerOn( layerNum:number )
  -- print("On: " .. layerNum)
  if layerNum == LensLayers.HEX_COLORING_RELIGION then
    UI.PlaySound("UI_Lens_Overlay_On");
    UILens.SetDesaturation(1.0);
  elseif layerNum == LensLayers.HEX_COLORING_APPEAL_LEVEL then
    if m_CurrentModdedLensOn == "VANILLA_APPEAL" then
      SetAppealHexes();
      UI.PlaySound("UI_Lens_Overlay_On");
    elseif m_CurrentModdedLensOn ~= "ML_CUSTOM" and m_CurrentModdedLensOn ~= "NONE" then
      SetModLens();
      UI.PlaySound("UI_Lens_Overlay_On");
    end
  elseif layerNum == LensLayers.HEX_COLORING_GOVERNMENT then
    SetGovernmentHexes();
    UI.PlaySound("UI_Lens_Overlay_On");
  elseif layerNum == LensLayers.HEX_COLORING_OWING_CIV then
    SetOwingCivHexes();
    UI.PlaySound("UI_Lens_Overlay_On");
  elseif layerNum == LensLayers.HEX_COLORING_CONTINENT then
    SetContinentHexes();
    UI.PlaySound("UI_Lens_Overlay_On");
  elseif layerNum == LensLayers.HEX_COLORING_WATER_AVAILABLITY then
    SetWaterHexes();
    UI.PlaySound("UI_Lens_Overlay_On");
  elseif layerNum == LensLayers.TOURIST_TOKENS then
    UI.PlaySound("UI_Lens_Overlay_On");
  end
end

-- ===========================================================================
function OnLensLayerOff( layerNum:number )
  -- print("Off: " .. layerNum)
  if (layerNum == LensLayers.HEX_COLORING_RELIGION or
      layerNum == LensLayers.HEX_COLORING_CONTINENT or
      layerNum == LensLayers.HEX_COLORING_GOVERNMENT or
      layerNum == LensLayers.HEX_COLORING_OWING_CIV) then
    UI.PlaySound("UI_Lens_Overlay_Off");

  -- Clear Modded Lens (Appeal lens included)
  elseif layerNum == LensLayers.HEX_COLORING_APPEAL_LEVEL then
    -- UILens.ClearLayerHexes( LensLayers.MAP_HEX_MASK );
    if UI.GetInterfaceMode() ~= InterfaceModeTypes.VIEW_MODAL_LENS or (UI.GetHeadSelectedUnit() == nil) then
      UILens.ClearLayerHexes(LensLayers.HEX_COLORING_APPEAL_LEVEL);
    end
    UI.PlaySound("UI_Lens_Overlay_Off");

  elseif layerNum == LensLayers.HEX_COLORING_WATER_AVAILABLITY then
    -- Only clear the water lens if we're turning off lenses altogether, but not if switching to another modal lens (Turning on another modal lens clears it already).
    if UI.GetInterfaceMode() ~= InterfaceModeTypes.VIEW_MODAL_LENS or (UI.GetHeadSelectedUnit() == nil) then
      UILens.ClearLayerHexes(LensLayers.HEX_COLORING_WATER_AVAILABLITY);
    end
    UI.PlaySound("UI_Lens_Overlay_Off");
  end

  if (layerNum == LensLayers.HEX_COLORING_RELIGION) then
    UILens.SetDesaturation(0.0);
  end
end

-- ===========================================================================
function OnToggleContinentLensExternal()
  if Controls.LensPanel:IsHidden() then
    Controls.LensPanel:SetHide(false);
    RealizeFlyouts(Controls.LensPanel);
    Controls.LensButton:SetSelected(true);
  end
  if not Controls.ContinentLensButton:IsChecked() then
    Controls.ContinentLensButton:SetCheck(true);
    UILens.SetActive("Continent");
    RefreshInterfaceMode();
  end
end

-- ===========================================================================
--  Engine EVENT
--  Local player changed; likely a hotseat game
-- ===========================================================================
function OnLocalPlayerChanged( eLocalPlayer:number , ePrevLocalPlayer:number )
  if eLocalPlayer == -1 then
    return;
  end
  CloseAllFlyouts();
end

-- ===========================================================================
function SetOwingCivHexes()
  local localPlayer : number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];
  if (localPlayerVis ~= nil) then
    local players = Game.GetPlayers();
    for i, player in ipairs(players) do
      local cities = players[i]:GetCities();
      local primaryColor, secondaryColor = UI.GetPlayerColors( player:GetID() );

      for _, pCity in cities:Members() do
        local plots :table = Map.GetCityPlots():GetPurchasedPlots(pCity);

        if(table.count(plots) > 0) then
          UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_OWING_CIV, localPlayer, plots, primaryColor );
        end
      end
    end
  end
end

-- ===========================================================================
function SetWaterHexes()
  local ctrlDown = m_CtrlDown
  if m_SetterLensAlternateInverse then
    ctrlDown = not ctrlDown
  end

  if (not ctrlDown) or UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
    local FullWaterPlots:table = {};
    local CoastalWaterPlots:table = {};
    local NoWaterPlots:table = {};
    local NoSettlePlots:table = {};

    UILens.ClearLayerHexes(LensLayers.HEX_COLORING_WATER_AVAILABLITY);
    FullWaterPlots, CoastalWaterPlots, NoWaterPlots, NoSettlePlots = Map.GetContinentPlotsWaterAvailability();

    local BreathtakingColor :number = UI.GetColorValue("COLOR_BREATHTAKING_APPEAL");
    local CharmingColor     :number = UI.GetColorValue("COLOR_CHARMING_APPEAL");
    local AverageColor      :number = UI.GetColorValue("COLOR_AVERAGE_APPEAL");
    local DisgustingColor   :number = UI.GetColorValue("COLOR_DISGUSTING_APPEAL");
    local localPlayer       :number = Game.GetLocalPlayer();

    if(table.count(FullWaterPlots) > 0) then
      UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_WATER_AVAILABLITY, localPlayer, FullWaterPlots, BreathtakingColor );
    end
    if(table.count(CoastalWaterPlots) > 0) then
      UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_WATER_AVAILABLITY, localPlayer, CoastalWaterPlots, CharmingColor );
    end
    if(table.count(NoWaterPlots) > 0) then
      UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_WATER_AVAILABLITY, localPlayer, NoWaterPlots, AverageColor );
    end
    if(table.count(NoSettlePlots) > 0) then
      UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_WATER_AVAILABLITY, localPlayer, NoSettlePlots, DisgustingColor );
    end

  else -- A settler is selected, show alternate highlighting
    SetSettlerLens()
  end
end

function SetSettlerLens()
  -- If cursor is not on a plot, don't do anything
  local plotId = UI.GetCursorPlotID();

  -- If Modal Panel, or cursor is not on a plot, show normal Water Hexes
  if (not Map.IsPlot(plotId)) then
    return
  end

  local pPlot = Map.GetPlotByIndex(plotId)
  local localPlayer:number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];
  local localPlayerCities = Players[localPlayer]:GetCities()

  local tNonDimPlots:table = {}
  local tUnusablePlots:table = {}
  local tOverlapPlots:table = {}
  local tResourcePlots:table = {}
  local tRegularPlots:table = {}

  local iUnusableColor:number = UI.GetColorValue("COLOR_ALT_SETTLER_UNUSABLE");
  local iOverlapColor:number = UI.GetColorValue("COLOR_ALT_SETTLER_OVERLAP");
  local iResourceColor:number = UI.GetColorValue("COLOR_ALT_SETTLER_RESOURCE");
  local iRegularColor:number = UI.GetColorValue("COLOR_ALT_SETTLER_REGULAR");

  for pRangePlot in PlotAreaSpiralIterator(pPlot, CITY_WORK_RANGE,
      SECTOR_NONE, DIRECTION_CLOCKWISE, DIRECTION_OUTWARDS, CENTRE_INCLUDE) do

    local plotX = pRangePlot:GetX()
    local plotY = pRangePlot:GetY()
    local plotID = pRangePlot:GetIndex()
    if localPlayerVis:IsRevealed(plotX, plotY) then

      table.insert(tNonDimPlots, plotID)
      if plotWithinWorkingRange(localPlayer, plotID) then
        table.insert(tOverlapPlots, plotID)

      elseif pRangePlot:IsImpassable() then
        table.insert(tUnusablePlots, plotID)

      elseif pRangePlot:IsOwned() and pRangePlot:GetOwner() ~= localPlayer then
        table.insert(tUnusablePlots, plotID)

      elseif plotHasResource(pRangePlot) and
          playerHasDiscoveredResource(localPlayer, plotID) then

        table.insert(tResourcePlots, plotID)
      else
        table.insert(tRegularPlots, plotID)
      end
    end
  end

  -- Alt_HighlightPlots(tNonDimPlots)

  if #tOverlapPlots > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_WATER_AVAILABLITY, localPlayer, tOverlapPlots, iOverlapColor );
  end

  if #tUnusablePlots > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_WATER_AVAILABLITY, localPlayer, tUnusablePlots, iUnusableColor );
  end

  if #tResourcePlots > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_WATER_AVAILABLITY, localPlayer, tResourcePlots, iResourceColor );
  end

  if #tRegularPlots  > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_WATER_AVAILABLITY, localPlayer, tRegularPlots, iRegularColor );
  end
end

function RefreshSettlerLens()
  ClearSettlerLens()
  UILens.ToggleLayerOn( LensLayers.HEX_COLORING_WATER_AVAILABLITY );
end

function ClearSettlerLens()
  -- Alt_ClearHighlightedPlots()

  if UILens.IsLayerOn( LensLayers.HEX_COLORING_WATER_AVAILABLITY ) then
    UILens.ToggleLayerOff( LensLayers.HEX_COLORING_WATER_AVAILABLITY );
  end
end

-- Checks to see if settler lens should be reapplied
function RecheckSettlerLens()
  local selectedUnit = UI.GetHeadSelectedUnit()
  if (selectedUnit ~= nil) then
    local unitType = GetUnitType(selectedUnit:GetOwner(), selectedUnit:GetID());
    if (unitType == "UNIT_SETTLER") then
      RefreshSettlerLens()
      return
    end
  end

  ClearSettlerLens()
end

-- ===========================================================================
function SetGovernmentHexes()
  local localPlayer : number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];
  if (localPlayerVis ~= nil) then
    local players = Game.GetPlayers();
    for i, player in ipairs(players) do
      local cities = players[i]:GetCities();
      local culture = player:GetCulture();
      local governmentId :number = culture:GetCurrentGovernment();
      local GovernmentColor;

      if culture:IsInAnarchy() then
        GovernmentColor = UI.GetColorValue("COLOR_CLEAR");
      else
        if(governmentId < 0) then
          GovernmentColor = UI.GetColorValue("COLOR_GOVERNMENT_CITYSTATE");
        else
          GovernmentColor = UI.GetColorValue("COLOR_" ..  GameInfo.Governments[governmentId].GovernmentType);
        end
      end

      for _, pCity in cities:Members() do
        local plots:table = Map.GetCityPlots():GetPurchasedPlots(pCity);

        if(table.count(plots) > 0) then
          UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_GOVERNMENT, localPlayer, plots, GovernmentColor );
        end
      end
    end
  end
end

-- ===========================================================================
function SetAppealHexes()
  local BreathtakingPlots:table = {};
  local CharmingPlots:table = {};
  local AveragePlots:table = {};
  local UninvitingPlots:table = {};
  local DisgustingPlots:table = {};

  BreathtakingPlots, CharmingPlots, AveragePlots, UninvitingPlots, DisgustingPlots = Map.GetContinentPlotsAppeal();

  local BreathtakingColor :number = UI.GetColorValue("COLOR_BREATHTAKING_APPEAL");
  local CharmingColor     :number = UI.GetColorValue("COLOR_CHARMING_APPEAL");
  local AverageColor      :number = UI.GetColorValue("COLOR_AVERAGE_APPEAL");
  local UninvitingColor   :number = UI.GetColorValue("COLOR_UNINVITING_APPEAL");
  local DisgustingColor   :number = UI.GetColorValue("COLOR_DISGUSTING_APPEAL");
  local localPlayer       :number = Game.GetLocalPlayer();

  if(table.count(BreathtakingPlots) > 0) then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, BreathtakingPlots, BreathtakingColor );
  end
  if(table.count(CharmingPlots) > 0) then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, CharmingPlots, CharmingColor );
  end
  if(table.count(AveragePlots) > 0) then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, AveragePlots, AverageColor );
  end
  if(table.count(UninvitingPlots) > 0) then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, UninvitingPlots, UninvitingColor );
  end
  if(table.count(DisgustingPlots) > 0) then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, DisgustingPlots, DisgustingColor );
  end
end

-- ===========================================================================
function SetContinentHexes()
  local ContinentColor:number = 0x02000000;
  GetContinentsCache();
  local localPlayerVis:table = PlayersVisibility[Game.GetLocalPlayer()];
  if (localPlayerVis ~= nil) then

    local kContinentColors:table = {};
    for loopNum, ContinentID in ipairs(m_ContinentsCache) do
      local visibleContinentPlots:table = Map.GetVisibleContinentPlots(ContinentID);
      ContinentColor = UI.GetColorValue("COLOR_" .. GameInfo.Continents[ loopNum-1 ].ContinentType);
      if(table.count(visibleContinentPlots) > 0) then
        UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_CONTINENT, loopNum-1, visibleContinentPlots, ContinentColor );
        kContinentColors[ContinentID] = ContinentColor;
      end
    end
    LuaEvents.MinimapPanel_AddContinentColorPair( kContinentColors );
  end
end

-- ===========================================================================
--  Support function for Hotkey Event
-- ===========================================================================
function LensPanelHotkeyControl( pControl:table )
  if Controls.LensPanel:IsHidden() then
    Controls.LensPanel:SetHide(false);
    RealizeFlyouts(Controls.LensPanel);
    Controls.LensButton:SetSelected(true);
  elseif (not Controls.LensPanel:IsHidden()) and pControl:IsChecked() then
    Controls.LensPanel:SetHide(true);
    Controls.LensButton:SetSelected(false);
  end
  pControl:SetCheck( not pControl:IsChecked() );
end

-- ===========================================================================
--  Input Hotkey Event
-- ===========================================================================
function OnInputActionTriggered( actionId )
  -- dont show panel if there is no local player
  if (Game.GetLocalPlayer() == -1) then
    return;
  end

  if UI.GetInterfaceMode() == InterfaceModeTypes.DISTRICT_PLACEMENT then
    return;
  end

  if m_ToggleReligionLensId ~= nil and (actionId == m_ToggleReligionLensId) then
    LensPanelHotkeyControl( Controls.ReligionLensButton );
    ToggleReligionLens();
    UI.PlaySound("Play_UI_Click");
  end
  if m_ToggleContinentLensId ~= nil and (actionId == m_ToggleContinentLensId) then
    LensPanelHotkeyControl( Controls.ContinentLensButton );
    ToggleContinentLens();
    UI.PlaySound("Play_UI_Click");
  end
  if m_ToggleAppealLensId ~= nil and (actionId == m_ToggleAppealLensId) then
    LensPanelHotkeyControl( Controls.AppealLensButton );
    ToggleAppealLens();
    UI.PlaySound("Play_UI_Click");
  end
  if m_ToggleSettlerLensId ~= nil and (actionId == m_ToggleSettlerLensId) then
    LensPanelHotkeyControl( Controls.WaterLensButton );
    ToggleWaterLens();
    UI.PlaySound("Play_UI_Click");
  end
  if m_ToggleGovernmentLensId ~= nil and (actionId == m_ToggleGovernmentLensId) then
    LensPanelHotkeyControl( Controls.GovernmentLensButton );
    ToggleGovernmentLens();
    UI.PlaySound("Play_UI_Click");
  end
  if m_TogglePoliticalLensId ~= nil and (actionId == m_TogglePoliticalLensId) then
    LensPanelHotkeyControl( Controls.OwnerLensButton );
    ToggleOwnerLens();
    UI.PlaySound("Play_UI_Click");
  end
  if m_ToggleTourismLensId ~= nil and (actionId == m_ToggleTourismLensId) then
    LensPanelHotkeyControl( Controls.TourismLensButton );
    ToggleTourismLens();
    UI.PlaySound("Play_UI_Click");
  end
  if m_Toggle2DViewId ~= nil and (actionId == m_Toggle2DViewId) then
    UI.PlaySound("Play_UI_Click");
    Toggle2DView();
  end
end

-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnInterfaceModeChanged(eOldMode:number, eNewMode:number)
  --and eNewMode ~= InterfaceModeTypes.VIEW_MODAL_LENS
  if eOldMode == InterfaceModeTypes.VIEW_MODAL_LENS then
    if not Controls.LensPanel:IsHidden() then
      if m_shouldCloseLensMenu then --If player turns off the lens from the menu, do not close the menu
        Controls.LensPanel:SetHide( true );
        RealizeFlyouts(Controls.LensPanel);
        Controls.LensButton:SetSelected( false );
      end
      m_shouldCloseLensMenu = true; --Reset variable so the menu can be closed by selecting a unit/city
      Controls.ReligionLensButton:SetCheck(false);
      Controls.ContinentLensButton:SetCheck(false);
      Controls.AppealLensButton:SetCheck(false);
      Controls.GovernmentLensButton:SetCheck(false);
      Controls.WaterLensButton:SetCheck(false);
      Controls.OwnerLensButton:SetCheck(false);
      Controls.TourismLensButton:SetCheck(false);

      -- Toggle each mod lens
      local i = 1
      local lensButtonInstance = m_LensButtonIM:GetAllocatedInstance(i)
      while lensButtonInstance ~= nil do
        lensButtonInstance.LensButton:SetCheck(false)
        i = i + 1
        lensButtonInstance = m_LensButtonIM:GetAllocatedInstance(i)
      end

      -- If any modded lens is active clear it
      if m_CurrentModdedLensOn ~= "NONE" then
        if UILens.IsLayerOn( LensLayers.HEX_COLORING_APPEAL_LEVEL ) then
          UILens.ToggleLayerOff( LensLayers.HEX_COLORING_APPEAL_LEVEL );
        end
        SetActiveModdedLens("NONE")
      end

      LuaEvents.ML_CloseLensPanels()
    end
  end
end

function GetMinimapMouseCoords( mousex:number, mousey:number )
  local topLeftX, topLeftY = Controls.MinimapImage:GetScreenOffset();

  -- normalized 0-1, relative to map
  local minix = mousex - topLeftX;
  local miniy = mousey - topLeftY;
  minix = minix / Controls.MinimapImage:GetSizeX();
  miniy = miniy / Controls.MinimapImage:GetSizeY();

  return minix, miniy;
end

function IsMouseInMinimap( minix:number, miniy:number )
  return minix >= 0 and minix <= 1 and miniy >= 0 and miniy <= 1;
end

function TranslateMinimapToWorld( minix:number, miniy:number )
  local mapMinX, mapMinY, mapMaxX, mapMaxY = UI.GetMinimapWorldRect();

  -- Clamp coords to minimap.
  minix = math.min( 1, math.max( 0, minix ) );
  miniy = math.min( 1, math.max( 0, miniy ) );

  --TODO: max-min probably wont work for rects that cross world wrap! -KS
  local wx = mapMinX + (mapMaxX-mapMinX) * minix;
  local wy = mapMinY + (mapMaxY-mapMinY) * (1 - miniy);

  return wx, wy;
end

function OnInputHandler( pInputStruct:table )
  local msg = pInputStruct:GetMessageType();
  if pInputStruct:GetKey() == Keys.VK_CONTROL then
    if msg == KeyEvents.KeyDown then
      m_CtrlDown = true

      -- Reset cursor plot to recalculate HandleMouseForModdedLens
      m_CurrentCursorPlotID = -1;
      RecheckSettlerLens()
    elseif msg == KeyEvents.KeyUp then
      m_CtrlDown = false
      RecheckSettlerLens()
    end
  end

  HandleMouseForModdedLens(pInputStruct:GetX(), pInputStruct:GetY())

  -- Skip all handling when dragging is disabled or the minimap is collapsed
  if m_isMouseDragEnabled and not m_isCollapsed then
    local msg = pInputStruct:GetMessageType( );

    -- Enable drag on LMB down
    if msg == MouseEvents.LButtonDown then
      local minix, miniy = GetMinimapMouseCoords( pInputStruct:GetX(), pInputStruct:GetY() );
      if IsMouseInMinimap( minix, miniy ) then
        m_isMouseDragging = true; -- Potential drag is in process
        m_hasMouseDragged = false; -- There has been no actual dragging yet
        LuaEvents.WorldInput_DragMapBegin(); -- Alert luathings that a drag is about to go down
        return true; -- Consume event
      end

    -- Disable drag on LMB up (but only if mouse was previously dragging)
    elseif msg == MouseEvents.LButtonUp and m_isMouseDragging then
      m_isMouseDragging = false;
      -- In case of no actual drag occurring, perform camera jump.
      if not m_hasMouseDragged then
        local minix, miniy = GetMinimapMouseCoords( pInputStruct:GetX(), pInputStruct:GetY() );
        local wx, wy = TranslateMinimapToWorld( minix, miniy );
        UI.LookAtPosition( wx, wy );
      end

      LuaEvents.WorldInput_DragMapEnd(); -- Alert luathings that the drag has stopped
      return true;

    -- Move camera if dragging, mouse moves, and mouse is over minimap.
    elseif msg == MouseEvents.MouseMove and m_isMouseDragging then
      local minix, miniy = GetMinimapMouseCoords( pInputStruct:GetX(), pInputStruct:GetY() );
      local isMouseInMinimap = IsMouseInMinimap( minix, miniy );

      -- Catches entering, exiting, and moving within the minimap.
      -- Clamping in TranslateMinimapToWorld guarantees OOB input is treated correctly.
      if m_wasMouseInMinimap or isMouseInMinimap then
        m_hasMouseDragged = true;
        local wx, wy = TranslateMinimapToWorld( minix, miniy );
        UI.FocusMap( wx, wy );
      end
      m_wasMouseInMinimap = isMouseInMinimap
      return isMouseInMinimap; -- Only consume event if it's inside the minimap.

    end

    -- TODO the letterbox background should block mouse input
  end
  return false;
end

function OnTutorial_DisableMapDrag( isDisabled:boolean )
  m_isMouseDragEnabled = not isDisabled;
  if isDisabled then
    m_isMouseDragging = false;
    m_hasMouseDragged = false;
    m_wasMouseInMinimap = false;
  end
end

function OnTutorial_SwitchToWorldView()
  Controls.SwitcherImage:SetTextureOffsetVal(0,0);
end

function OnShutdown()
  LuaEvents.Tutorial_SwitchToWorldView.Remove( OnTutorial_SwitchToWorldView );
  LuaEvents.Tutorial_DisableMapDrag.Remove( OnTutorial_DisableMapDrag );
  LuaEvents.NotificationPanel_ShowContinentLens.Remove(OnToggleContinentLensExternal);
end

-- ===========================================================================
--  Modded Lens Support
-- ===========================================================================
function SetModLens()
  if m_CurrentModdedLensOn ~= nil and m_CurrentModdedLensOn ~= "NONE" and
      g_ModLenses[m_CurrentModdedLensOn] ~= nil then
    print_debug("Highlighting " .. m_CurrentModdedLensOn .. " hexes")
    local getPlotColorFn = g_ModLenses[m_CurrentModdedLensOn].GetColorPlotTable
    if getPlotColorFn ~= nil then
      SetModLensHexes(getPlotColorFn())
    else
      print_debug("ERROR: No Plot Color Function")
    end
  else
    print_debug("ERROR: Given lens has no entry")
  end
end

function SetModLensHexes(colorPlot:table)
  -- UILens.ClearLayerHexes(LensLayers.HEX_COLORING_APPEAL_LEVEL);
  local localPlayer = Game.GetLocalPlayer()
  for color, plots in pairs(colorPlot) do
    if table.count(plots) > 0 then
      print_debug("Showing " .. table.count(plots) .. " plots with color " .. color)
      UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, plots, color);
    end
  end
end

function OnApplyCustomLens(colorPlot:table)
  if UILens.IsLayerOn(LensLayers.HEX_COLORING_APPEAL_LEVEL) then
    UILens.ClearLayerHexes(LensLayers.HEX_COLORING_APPEAL_LEVEL)
  else
    SetActiveModdedLens("ML_CUSTOM")
    UILens.ToggleLayerOn(LensLayers.HEX_COLORING_APPEAL_LEVEL)
  end
  -- print("Toggling on")
  SetModLensHexes(colorPlot)
end

function OnClearCustomLens()
  if UILens.IsLayerOn(LensLayers.HEX_COLORING_APPEAL_LEVEL) then
    -- print("Toggling off")
    UILens.ToggleLayerOff(LensLayers.HEX_COLORING_APPEAL_LEVEL)
  end
  SetActiveModdedLens("NONE")
end

function SetActiveModdedLens(lensName:string)
  m_CurrentModdedLensOn = lensName
  -- LuaEvents.MinimapPanel_ModdedLensOn(lensName)
end

function GetActiveModdedLens(returnLens:table)
  returnLens[1] = m_CurrentModdedLensOn
end

function GetLensPanelOffsets(offsets:table)
  local y = Controls.MinimapContainer:GetSizeY() + Controls.MinimapContainer:GetOffsetY()
  if m_isCollapsed then
    y = y - Controls.MinimapContainer:GetSizeY()
  end
  offsets.Y = y
  offsets.X = Controls.LensPanel:GetSizeX() + Controls.LensPanel:GetOffsetX()
end

function ToggleModLens(buttonControl:table, lensName:string)
  if buttonControl:IsChecked() then
    SetActiveModdedLens(lensName);

    -- Check if the appeal lens is already active. Needed to clear any modded lens
    if UILens.IsLayerOn(LensLayers.HEX_COLORING_APPEAL_LEVEL) then
      -- Unapply the appeal lens, so it can be cleared from the screen
      UILens.SetActive("Default");
    end

    LuaEvents.ML_CloseLensPanels()
    if g_ModLenses[lensName].OnToggle ~= nil then
      -- print("Toggling....")
      g_ModLenses[lensName].OnToggle()
    end
    UILens.SetActive("Appeal");
    RefreshInterfaceMode();
  else
    m_shouldCloseLensMenu = false;
    if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
    LuaEvents.ML_CloseLensPanels()
    SetActiveModdedLens("NONE");
  end
end

function InitLens(lensName, modLens)
  print("Adding ModLens: " .. lensName)
  if modLens.Initialize ~= nil then
    modLens.Initialize()
  end

  -- Add this lens to button stack
  local modLensToggle = m_LensButtonIM:GetInstance();
  local pLensButton = modLensToggle.LensButton:GetTextButton()
  local pToolTip = Locale.Lookup(modLens.LensButtonTooltip)
  pLensButton:LocalizeAndSetText(modLens.LensButtonText)
  modLensToggle.LensButton:SetToolTipString(pToolTip)
  modLensToggle.LensButton:RegisterCallback(Mouse.eLClick,
    function()
      ToggleModLens(modLensToggle.LensButton, lensName);
    end
  )
end

function AddLensEntry(lensKey:string, lensEntry:table)
  g_ModLenses[lensKey] = lensEntry
  InitLens(lensKey, lensEntry)
end

function InitializeModLens()
  print("Initializing " .. table.count(g_ModLenses) .. " lenses")
  for lensName, modLens in pairs(g_ModLenses) do
    InitLens(lensName, modLens)
  end
end

function HandleMouseForModdedLens( mousex:number, mousey:number )
  -- Don't do anything if mouse is dragging
  if not m_isMouseDragging then
    -- Get plot under cursor
    local plotId = UI.GetCursorPlotID();
    if (not Map.IsPlot(plotId)) then
      return;
    end

    -- If the cursor plot has not changed don't refresh
    if (m_CurrentCursorPlotID == plotId) then
      return
    end

    m_CurrentCursorPlotID = plotId

    local pPlot = Map.GetPlotByIndex(m_CurrentCursorPlotID)
    local selectedCity = UI.GetHeadSelectedCity()
    local selectedUnit = UI.GetHeadSelectedUnit()

    -- Handler for alternate settler lens
    local ctrlDown = m_CtrlDown
    if m_SetterLensAlternateInverse then
      ctrlDown = not ctrlDown
    end

    if ctrlDown then
      if selectedUnit ~= nil then
        local unitType = GetUnitType(selectedUnit:GetOwner(), selectedUnit:GetID());
        if unitType == "UNIT_SETTLER" then
          RefreshSettlerLens();
        -- else
        --     print(unitType)
        end

      -- Clear Settler lens, if not in modal screen
      elseif UI.GetInterfaceMode() ~= InterfaceModeTypes.VIEW_MODAL_LENS then

        ClearSettlerLens();
      end
    end
  end
end

-- ===========================================================================
-- INITIALIZATION
-- ===========================================================================

function Initialize()
  m_MiniMap_xmloffsety = Controls.MiniMap:GetOffsetY();
  m_ContinentsCache = Map.GetContinentsInUse();

  Controls.MinimapImage:RegisterSizeChanged( OnMinimapImageSizeChanged );
  UI.SetMinimapImageControl( Controls.MinimapImage );

  ContextPtr:SetInputHandler( OnInputHandler, true );
  ContextPtr:SetShutdown( OnShutdown );

  Controls.LensPanel:ChangeParent(Controls.LensButton);
  Controls.MapOptionsPanel:ChangeParent(Controls.MapOptionsButton);
  Controls.ToggleResourcesButton:SetCheck( UserConfiguration.ShowMapResources() );
  Controls.ToggleYieldsButton:SetCheck( UserConfiguration.ShowMapYield() );

  Controls.AppealLensButton:RegisterCallback( Mouse.eLClick, ToggleAppealLens );
  Controls.ContinentLensButton:RegisterCallback( Mouse.eLClick, ToggleContinentLens );
  Controls.CollapseButton:RegisterCallback( Mouse.eLClick, OnCollapseToggle );
  Controls.CollapseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.ExpandButton:RegisterCallback( Mouse.eLClick, OnCollapseToggle );
  Controls.ExpandButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.GovernmentLensButton:RegisterCallback( Mouse.eLClick, ToggleGovernmentLens );
  Controls.LensButton:RegisterCallback( Mouse.eLClick, OnToggleLensList );
  Controls.LensButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.MapOptionsButton:RegisterCallback( Mouse.eLClick, ToggleMapOptionsList );
  Controls.MapOptionsButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.MapPinListButton:RegisterCallback( Mouse.eLClick, ToggleMapPinMode );
  Controls.MapPinListButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.OwnerLensButton:RegisterCallback( Mouse.eLClick, ToggleOwnerLens );
  Controls.TourismLensButton:RegisterCallback( Mouse.eLClick, ToggleTourismLens );
  Controls.Pause:RegisterEndCallback( OnPauseEnd );
  Controls.ReligionLensButton:RegisterCallback( Mouse.eLClick, ToggleReligionLens );
  Controls.StrategicSwitcherButton:RegisterCallback( Mouse.eLClick, Toggle2DView );
  Controls.StrategicSwitcherButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.ToggleGridButton:RegisterCallback( Mouse.eLClick, ToggleGrid );
  Controls.ToggleResourcesButton:RegisterCallback( Mouse.eLClick, ToggleResourceIcons );
  Controls.ToggleYieldsButton:RegisterCallback( Mouse.eLClick, ToggleYieldIcons );
  Controls.WaterLensButton:RegisterCallback( Mouse.eLClick, ToggleWaterLens );

  -- Hide buttons not needed for the world builder
  if GameConfiguration.IsWorldBuilderEditor() then
    Controls.LensButton:SetHide(true);
    Controls.MapPinListButton:SetHide(true);
    Controls.StrategicSwitcherButton:SetHide(true);
    Controls.OptionsStack:ReprocessAnchoring();
  end

  --CQUI Options Button
  Controls.CQUI_OptionsButton:RegisterCallback( Mouse.eLClick, function() LuaEvents.CQUI_ToggleSettings() end);
  Controls.CQUI_OptionsButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

  -- Make sure the StrategicSwitcherButton has the correct image when the game starts in StrategicView
  if UI.GetWorldRenderView() == WorldRenderView.VIEW_2D then
    Controls.SwitcherImage:SetTextureOffsetVal(0,24);
  end

  Events.InputActionTriggered.Add( OnInputActionTriggered );
  Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
  Events.LensLayerOn.Add( OnLensLayerOn );
  Events.LensLayerOff.Add( OnLensLayerOff );
  Events.LocalPlayerChanged.Add( OnLocalPlayerChanged );
  Events.LoadScreenClose.Add(
    function()
      -- AZURENCY : already done in LoadScreen.lua OnActivateButtonClicked()
      --UILens.SetActive("Default");
    end
  )

  LuaEvents.NotificationPanel_ShowContinentLens.Add(OnToggleContinentLensExternal);
  LuaEvents.Tutorial_DisableMapDrag.Add( OnTutorial_DisableMapDrag );
  LuaEvents.Tutorial_SwitchToWorldView.Add( OnTutorial_SwitchToWorldView );
  LuaEvents.MinimapPanel_ToggleGrid.Add( ToggleGrid );
  LuaEvents.MinimapPanel_RefreshMinimapOptions.Add( RefreshMinimapOptions );

  -- CQUI Handlers
  LuaEvents.CQUI_Option_ToggleBindings.Add( CQUI_OnToggleBindings );
  LuaEvents.CQUI_Option_ToggleYields.Add( ToggleYieldIcons );
  LuaEvents.CQUI_SettingsInitialized.Add( CQUI_ToggleYieldIcons );

  -- Mod Lens Support
  LuaEvents.MinimapPanel_SetActiveModLens.Add( SetActiveModdedLens );
  LuaEvents.MinimapPanel_GetActiveModLens.Add( GetActiveModdedLens );
  LuaEvents.MinimapPanel_GetLensPanelOffsets.Add( GetLensPanelOffsets );
  LuaEvents.MinimapPanel_ApplyCustomLens.Add( OnApplyCustomLens );
  LuaEvents.MinimapPanel_ClearCustomLens.Add( OnClearCustomLens );
  LuaEvents.MinimapPanel_AddLensEntry.Add( AddLensEntry );
  InitializeModLens()
end
Initialize();
