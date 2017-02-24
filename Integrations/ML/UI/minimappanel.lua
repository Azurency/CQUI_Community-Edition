-- ===========================================================================
--  MINIMAP PANEL
-- ===========================================================================
include( "InstanceManager" );
include( "Civ6Common.lua" );    -- GetCivilizationUniqueTraits, GetLeaderUniqueTraits
include( "SupportFunctions" );

-- ===========================================================================
--  CONSTANTS
-- ===========================================================================
local MINIMAP_COLLAPSED_OFFSETY :number = -180;

-- Used to control ModalLensPanel.lua
local MODDED_LENS_ID:table = {
  NONE = 0;
  APPEAL = 1;
  BUILDER = 2;
  ARCHAEOLOGIST = 3;
  BARBARIAN = 4;
  CITY_OVERLAP6 = 5;
  CITY_OVERLAP9 = 6;
  RESOURCE = 7;
  WONDER = 8;
  ADJACENCY_YIELD = 9;
  SCOUT = 10;
};

-- Should the builder lens auto apply, when a builder is selected.
local AUTO_APPLY_BUILDER_LENS:boolean = true;

-- Should the archeologist lens auto apply, when a archeologist is selected.
local AUTO_APPLY_ARCHEOLOGIST_LENS:boolean = true

-- Should the scout lens auto apply, when a scout/ranger is selected.
local AUTO_APPLY_SCOUT_LENS:boolean = true;

local m_isModdedMouseFeatureEnabled = true;

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

local m_shouldCloseLensMenu     :boolean = true;    -- Controls when the Lens menu should be closed.

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


local m_isMouseDragEnabled      :boolean = true; -- Can the camera be moved by dragging on the minimap?
local m_isMouseDragging         :boolean = false; -- Was LMB clicked inside the minimap, and has not been released yet?
local m_hasMouseDragged         :boolean = false; -- Has there been any movements since m_isMouseDragging became true?
local m_wasMouseInMinimap       :boolean = false; -- Was the mouse over the minimap the last time we checked?

local CQUI_MapSize = 512;

local m_CurrentModdedLensOn     :number  = MODDED_LENS_ID.NONE;
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

function CQUI_UpdateMinimapSize()
  CQUI_MapSize = GameConfiguration.GetValue("CQUI_MinimapSize");

  --Cycles the minimap after resizing
  if(Controls.MinimapImage:GetSizeX() ~= CQUI_MapSize) then
    Controls.MinimapImage:SetSizeVal(CQUI_MapSize, CQUI_MapSize / 2);
    Controls.CollapseAnim:SetEndVal(0, Controls.MinimapImage:GetOffsetY() + Controls.MinimapImage:GetSizeY() -25);
    Controls.CollapseAnim:SetProgress(1);
    m_isCollapsed = true;
    OnCollapseToggle();
    --Squeezes the map buttons if extra space is needed
    if(CQUI_MapSize < 256) then
      Controls.OptionsStack:SetPadding(-7);
    else
      Controls.OptionsStack:SetPadding(-3);
    end
  end
end

function CQUI_OnSettingsUpdate()
  AUTO_APPLY_ARCHEOLOGIST_LENS = GameConfiguration.GetValue("CQUI_AutoapplyArchaeologistLens");
  AUTO_APPLY_BUILDER_LENS = GameConfiguration.GetValue("CQUI_AutoapplyBuilderLens");
  AUTO_APPLY_SCOUT_LENS = GameConfiguration.GetValue("CQUI_AutoapplyScoutLens");

  --Cycles the minimap after resizing
  CQUI_UpdateMinimapSize();
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
    local panelId = id.."Panel";    -- e.g LenPanel, MapOptionPanel, etc...
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
    return;   -- If target control is hidden, ignore the rest.
  end
  for _,id in ipairs(m_kFlyoutControlIds) do
    local panelId = id.."Panel";    -- e.g LenPanel, MapOptionPanel, etc...
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

function RefreshMinimapOptions()
  Controls.ToggleYieldsButton:SetCheck(UserConfiguration.ShowMapYield());
  Controls.ToggleGridButton:SetCheck(bGridOn);
  Controls.ToggleResourcesButton:SetCheck(UserConfiguration.ShowMapResources());
end

-- ===========================================================================
function ToggleMapOptionsList()
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
    m_shouldCloseLensMenu = true;
    Controls.ReligionLensButton:SetCheck(false);
    Controls.ContinentLensButton:SetCheck(false);
    Controls.AppealLensButton:SetCheck(false);
    Controls.GovernmentLensButton:SetCheck(false);
    Controls.WaterLensButton:SetCheck(false);
    Controls.OwnerLensButton:SetCheck(false);
    Controls.TourismLensButton:SetCheck(false);

    -- Modded lens
    Controls.ScoutLensButton:SetCheck(false);
    Controls.AdjacencyYieldLensButton:SetCheck(false);
    Controls.WonderLensButton:SetCheck(false);
    Controls.ResourceLensButton:SetCheck(false);
    Controls.BarbarianLensButton:SetCheck(false);
    Controls.CityOverlap9LensButton:SetCheck(false);
    Controls.CityOverlap6LensButton:SetCheck(false);
    Controls.ArchaeologistLensButton:SetCheck(false);
    Controls.BuilderLensButton:SetCheck(false);
    if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
  end
end

------------------------------------------------------------------------------
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
    Controls.ToggleYieldsButton:SetCheck(true);
  else
    LuaEvents.MinimapPanel_HideYieldIcons();
    Controls.ToggleYieldsButton:SetCheck(false);
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
    SetActiveModdedLens(MODDED_LENS_ID.APPEAL);

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
    SetActiveModdedLens(MODDED_LENS_ID.NONE);
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
-- Modded lenses
-- ===========================================================================
-- ===========================================================================
function ToggleBuilderLens()
  if Controls.BuilderLensButton:IsChecked() then
    SetActiveModdedLens(MODDED_LENS_ID.BUILDER);

    -- Check if the appeal lens is already active
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
    SetActiveModdedLens(MODDED_LENS_ID.NONE);
  end
end

-- ===========================================================================
function ToggleArchaeologistLens()
  if Controls.ArchaeologistLensButton:IsChecked() then
    SetActiveModdedLens(MODDED_LENS_ID.ARCHAEOLOGIST);

    -- Check if the appeal lens is already active
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
    SetActiveModdedLens(MODDED_LENS_ID.NONE);
  end
end

-- ===========================================================================
function ToggleCityOverlap6Lens()
  if Controls.CityOverlap6LensButton:IsChecked() then
    SetActiveModdedLens(MODDED_LENS_ID.CITY_OVERLAP6);

    -- Check if the appeal lens is already active
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
    SetActiveModdedLens(MODDED_LENS_ID.NONE);
  end
end

-- ===========================================================================
function ToggleCityOverlap9Lens()
  if Controls.CityOverlap9LensButton:IsChecked() then
    SetActiveModdedLens(MODDED_LENS_ID.CITY_OVERLAP9);

    -- Check if the appeal lens is already active
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
    SetActiveModdedLens(MODDED_LENS_ID.NONE);
  end
end

-- ===========================================================================
function ToggleBarbarianLens()
  if Controls.BarbarianLensButton:IsChecked() then
    SetActiveModdedLens(MODDED_LENS_ID.BARBARIAN);

    -- Check if the appeal lens is already active
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
    SetActiveModdedLens(MODDED_LENS_ID.NONE);
  end
end

-- ===========================================================================
function ToggleResourceLens()
  if Controls.ResourceLensButton:IsChecked() then
    SetActiveModdedLens(MODDED_LENS_ID.RESOURCE);

    -- Check if the appeal lens is already active
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
    SetActiveModdedLens(MODDED_LENS_ID.NONE);
  end
end

-- ===========================================================================
function ToggleWonderLens()
  if Controls.WonderLensButton:IsChecked() then
    SetActiveModdedLens(MODDED_LENS_ID.WONDER);

    -- Check if the appeal lens is already active
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
    SetActiveModdedLens(MODDED_LENS_ID.NONE);
  end
end

-- ===========================================================================
function ToggleAdjacencyYieldLens()
  if Controls.AdjacencyYieldLensButton:IsChecked() then
    SetActiveModdedLens(MODDED_LENS_ID.ADJACENCY_YIELD);

    -- Check if the appeal lens is already active
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
    SetActiveModdedLens(MODDED_LENS_ID.NONE);
  end
end

-- ===========================================================================
function ToggleScoutLens()
  if Controls.ScoutLensButton:IsChecked() then
    SetActiveModdedLens(MODDED_LENS_ID.SCOUT);

    -- Check if the appeal lens is already active
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
    SetActiveModdedLens(MODDED_LENS_ID.NONE);
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
    Controls.CollapseButton:SetHide( false );
    Controls.ExpandAnim:SetEndVal(0, -Controls.MinimapImage:GetOffsetY() - Controls.MinimapImage:GetSizeY() + 25);
    Controls.ExpandAnim:SetToBeginning();
    Controls.ExpandAnim:Play();
    Controls.CompassArm:SetPercent(.25);
  else
    UI.PlaySound("Minimap_Closed");
    Controls.ExpandButton:SetHide( false );
    Controls.CollapseButton:SetHide( true );
    Controls.Pause:Play();
    Controls.CollapseAnim:SetEndVal(0, Controls.MinimapImage:GetOffsetY() + Controls.MinimapImage:GetSizeY() - 25);
    Controls.CollapseAnim:SetToBeginning();
    Controls.CollapseAnim:Play();
    Controls.CompassArm:SetPercent(.5);
  end
  m_isCollapsed = not m_isCollapsed;
end

-- ===========================================================================
function RefreshInterfaceMode()
  if UI.GetInterfaceMode() ~= InterfaceModeTypes.VIEW_MODAL_LENS then
    UI.SetInterfaceMode(InterfaceModeTypes.VIEW_MODAL_LENS);
  end
end

-- ===========================================================================
function OnLensLayerOn( layerNum:number )
  if layerNum == LensLayers.HEX_COLORING_RELIGION then
    UI.PlaySound("UI_Lens_Overlay_On");
  elseif layerNum == LensLayers.HEX_COLORING_APPEAL_LEVEL then
    local currentModdedLens = GetCurrentModdedLens();
    if currentModdedLens == MODDED_LENS_ID.APPEAL then
      SetAppealHexes();
    elseif currentModdedLens == MODDED_LENS_ID.BUILDER then
      SetBuilderLensHexes();
    elseif currentModdedLens == MODDED_LENS_ID.ARCHAEOLOGIST then
      SetArchaeologistLens();
    elseif currentModdedLens == MODDED_LENS_ID.CITY_OVERLAP6 then
      SetCityOverlapLens(6);
    elseif currentModdedLens == MODDED_LENS_ID.CITY_OVERLAP9 then
      SetCityOverlapLens(9);
    elseif currentModdedLens == MODDED_LENS_ID.BARBARIAN then
      SetBarbarianLens();
    elseif currentModdedLens == MODDED_LENS_ID.RESOURCE then
      SetResourceLens();
    elseif currentModdedLens == MODDED_LENS_ID.WONDER then
      SetWonderLens();
    elseif currentModdedLens == MODDED_LENS_ID.ADJACENCY_YIELD then
      SetAdjacencyYieldLens();
    elseif currentModdedLens == MODDED_LENS_ID.SCOUT then
      SetScoutLens();
    end
    UI.PlaySound("UI_Lens_Overlay_On");
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
  if (layerNum == LensLayers.HEX_COLORING_RELIGION or
      layerNum == LensLayers.HEX_COLORING_CONTINENT or
      layerNum == LensLayers.HEX_COLORING_GOVERNMENT or
      layerNum == LensLayers.HEX_COLORING_OWING_CIV) then
    UI.PlaySound("UI_Lens_Overlay_Off");
  elseif layerNum == LensLayers.HEX_COLORING_APPEAL_LEVEL then
    -- Only clear the water lens if we're turning off lenses altogether, but not if switching to another modal lens (Turning on another modal lens clears it already).
    -- For the modded lens
    UILens.ClearLayerHexes( LensLayers.MAP_HEX_MASK );
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
        local visibleCityPlots  :table = Map.GetCityPlots():GetVisiblePurchasedPlots(pCity);

        if(table.count(visibleCityPlots) > 0) then
          UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_OWING_CIV, localPlayer, visibleCityPlots, primaryColor );
        end
      end
    end
  end
end

-- ===========================================================================
function SetWaterHexes()
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
end

-- ===========================================================================
function SetGovernmentHexes()
  -- print("Setting government lens")
  local localPlayer : number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];
  if (localPlayerVis ~= nil) then
    local players = Game.GetPlayers();
    for i in pairs(players) do
      local cities = players[i]:GetCities();
      local culture = players[i]:GetCulture();
      local governmentId :number = culture:GetCurrentGovernment();
      local GovernmentColor;
      if(governmentId < 0) or GameInfo.Governments[governmentId] == nil then
        GovernmentColor = UI.GetColorValue("COLOR_GOVERNMENT_CITYSTATE");
        -- print("COLOR_GOVERNMENT_CITYSTATE")
      else
        GovernmentColor = UI.GetColorValue("COLOR_" ..  GameInfo.Governments[governmentId].GovernmentType);
        -- print("COLOR_" ..  GameInfo.Governments[governmentId].GovernmentType)
      end

      -- print(GovernmentColor)

      for i, pCity in cities:Members() do
        local visibleCityPlots:table = Map.GetCityPlots():GetVisiblePurchasedPlots(pCity);

        if table.count(visibleCityPlots) > 0 then
          UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_GOVERNMENT, localPlayer, visibleCityPlots, GovernmentColor );
        end
      end

      -- return
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
function SetBuilderLensHexes()
  -- Check required to work properly with hotkey.
  -- print("Highlight Builder Lens Hexes");
  local mapWidth, mapHeight = Map.GetGridSize();

  local ResourceColor:number = UI.GetColorValue("COLOR_RESOURCE_BUILDER_LENS");
  local HillColor:number = UI.GetColorValue("COLOR_HILL_BUILDER_LENS");
  local RecomFeatureColor:number = UI.GetColorValue("COLOR_RECOMFEATURE_BUILDER_LENS")
  local FeatureColor:number = UI.GetColorValue("COLOR_FEATURE_BUILDER_LENS");
  local GenericColor:number = UI.GetColorValue("COLOR_GENERIC_BUILDER_LENS");
  local NothingColor:number = UI.GetColorValue("COLOR_NOTHING_BUILDER_LENS");
  local localPlayer:number = Game.GetLocalPlayer();

  local unworkableHexes:table = {};
  local repairableHexes:table = {};
  local resourceHexes:table = {};
  local featureHexes:table = {};
  local recomFeatureHexes:table = {}
  local hillHexes:table = {};
  local genericHexes:table = {};
  local specialHexes:table = {};
  local localPlayerHexes:table = {};

  for i = 0, (mapWidth * mapHeight) - 1, 1 do
    local pPlot:table = Map.GetPlotByIndex(i);

    if pPlot:GetOwner() == Game.GetLocalPlayer() then
      table.insert(localPlayerHexes, i);

      -- IMPASSABLE
      --------------------------------------
      if pPlot:IsImpassable() then
        table.insert(unworkableHexes, i)

      -- IMPROVEMENTS
      --------------------------------------
      elseif plotHasImprovement(pPlot) then
        if pPlot:IsImprovementPillaged() then
          table.insert(repairableHexes, i);
        else
          table.insert(unworkableHexes, i);
        end

      -- NATURAL WONDER
      --------------------------------------
      elseif plotHasNaturalWonder(pPlot) then
        if plotHasImprovableWonder(pPlot) then
          table.insert(recomFeatureHexes, i)
        else
          table.insert(unworkableHexes, i)
        end

      -- PLAYER WONDER - CHINESE UA
      --------------------------------------
      elseif plotHasWonder(pPlot) then
        -- Check for a UA similiar to china's
        if playerHasBuilderWonderModifier(localPlayer) and (not pPlot:IsWonderComplete())
          and isAncientClassicalWonder(pPlot:GetWonderType()) then
            table.insert(specialHexes, i);
        else
          table.insert(unworkableHexes, i);
        end

      -- DISTRICT - AZTEC UA
      --------------------------------------
      elseif plotHasDistrict(pPlot) then
        -- Check for a UA similiar to Aztec's
        if (not pPlot:IsCity()) and (not districtComplete(localPlayer, i)) and
          playerHasBuilderDistrictModifier(localPlayer) then
            table.insert(specialHexes, i);
        else
          table.insert(unworkableHexes, i);
        end

      -- VISIBLE RESOURCE
      --------------------------------------
      elseif plotHasResource(pPlot) and playerHasDiscoveredResource(localPlayer, i) then
        -- Is the resource improvable?
        if plotResourceImprovable(pPlot) then
          table.insert(resourceHexes, i);
        else
          table.insert(unworkableHexes, i);
        end

      -- HILL
      --------------------------------------
      elseif plotHasHill(pPlot) then
        if plotNextToBuffingWonder(pPlot) then
          table.insert(recomFeatureHexes, i)
        else
          table.insert(hillHexes, i);
        end

      -- FEATURE - Note: This includes natural wonders, since wonder is also a "feature". Check Features.xml
      --------------------------------------
      elseif plotHasFeature(pPlot) then
        -- Recommended Feature
        if plotHasRecomFeature(pPlot) then
          table.insert(recomFeatureHexes, i)
        -- Harvestable feature
        elseif playerCanRemoveFeature(localPlayer, i) then
          table.insert(featureHexes, i);
        else
          table.insert(unworkableHexes, i)
        end

      -- GENERIC TILE
      --------------------------------------
      elseif plotCanHaveImprovement(localPlayer, i) then
        if plotNextToBuffingWonder(pPlot) then
          table.insert(recomFeatureHexes, i)
        else
          table.insert(genericHexes, i)
        end

      -- NOTHING TO DO
      --------------------------------------
      else
         table.insert(unworkableHexes, i)
      end
    end
  end

  -- Dim other hexes
  -- if table.count(localPlayerHexes) > 0 then
  --  UILens.SetLayerHexesArea(LensLayers.MAP_HEX_MASK, localPlayer, localPlayerHexes );
  -- end

  if table.count(repairableHexes) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, repairableHexes, ResourceColor );
  end
  if table.count(resourceHexes) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, resourceHexes, ResourceColor );
  end
  if table.count(specialHexes) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, specialHexes, ResourceColor );
  end
  if table.count(hillHexes) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, hillHexes, HillColor );
  end
  if table.count(recomFeatureHexes) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, recomFeatureHexes, RecomFeatureColor );
  end
  if table.count(featureHexes) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, featureHexes, FeatureColor );
  end
  if table.count(genericHexes) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, genericHexes, GenericColor );
  end
  if table.count(unworkableHexes) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, unworkableHexes, NothingColor );
  end
end

function ClearModdedLens()
  UILens.ClearLayerHexes( LensLayers.MAP_HEX_MASK );
  if UILens.IsLayerOn( LensLayers.HEX_COLORING_APPEAL_LEVEL ) then
    UILens.ToggleLayerOff( LensLayers.HEX_COLORING_APPEAL_LEVEL );
  end
  SetActiveModdedLens(MODDED_LENS_ID.NONE);
end

function ClearBuilderLensHexes()
  -- print("Clear Builder Lens Hexes");
  ClearModdedLens();
end

-- Called when a builder is selected
function ShowBuilderLens()
  -- UILens.SetActive("Default");
  SetActiveModdedLens(MODDED_LENS_ID.BUILDER);
  UILens.ToggleLayerOn(LensLayers.HEX_COLORING_APPEAL_LEVEL);
end

-- ===========================================================================
function SetArchaeologistLens()
  -- print("Show archeologist lens")
  local mapWidth, mapHeight = Map.GetGridSize();
  local localPlayer   :number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];

  local artifactPlots     :table = {};
  local antiquityPlots    :table = {};
  local shipwreckPlots    :table = {};

  local AntiquityColor = UI.GetColorValue("COLOR_ARTIFACT_ARCH_LENS");
  local ShipwreckColor = UI.GetColorValue("COLOR_SHIPWRECK_ARCH_LENS");

  for i = 0, (mapWidth * mapHeight) - 1, 1 do
    local pPlot:table = Map.GetPlotByIndex(i);

    if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) and playerHasDiscoveredResource(localPlayer, i) then
      if plotHasAnitquitySite(pPlot) then
        table.insert(artifactPlots, i);
        table.insert(antiquityPlots, i);
      elseif plotHasShipwreck(pPlot) then
        table.insert(shipwreckPlots, i);
        table.insert(antiquityPlots, i);
      end
    end
  end

  -- Dim hexes that are not artifacts or shipwrecks
  -- if table.count(antiquityPlots) > 0 then
  --  UILens.SetLayerHexesArea(LensLayers.MAP_HEX_MASK, localPlayer, antiquityPlots );
  -- end

  if table.count(artifactPlots) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, artifactPlots, AntiquityColor );
  end
  if table.count(shipwreckPlots) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, shipwreckPlots, ShipwreckColor );
  end
end

function ClearArchaeologistLens()
  -- print("Clear Archaeologist Lens Hexes");
  ClearModdedLens();
end

-- Called when a archeologist is selected
function ShowArchaeologistLens()
  SetActiveModdedLens(MODDED_LENS_ID.ARCHAEOLOGIST);
  UILens.ToggleLayerOn(LensLayers.HEX_COLORING_APPEAL_LEVEL);
end

-- ===========================================================================
function SetCityOverlapLens(range)
  -- print("Show City Overlap 6 lens")
  local mapWidth, mapHeight = Map.GetGridSize();
  local localPlayer   :number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];

  local plotEntries       :table = {};
  local numCityEntries    :table = {};

  for i = 0, (mapWidth * mapHeight) - 1, 1 do
    local pPlot:table = Map.GetPlotByIndex(i);

    if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) then
      -- if pPlot:GetOwner() == localPlayer then
        local numCities = 0;
        -- get cities that in range of this hex.
        local localPlayerCities = Players[localPlayer]:GetCities()
        for i, pCity in localPlayerCities:Members() do
          if pCity ~= nil and pCity:GetOwner() == localPlayer then
            local pCityPlot = Map.GetPlot(pCity:GetX(), pCity:GetY())
            if Map.GetPlotDistance(pPlot:GetX(), pPlot:GetY(), pCityPlot:GetX(), pCityPlot:GetY()) <= range then
              numCities = numCities + 1;
            end
          end
        end

        if numCities > 0 then
          numCities = Clamp(numCities, 1, 8);

          table.insert(plotEntries, i);
          table.insert(numCityEntries, numCities);
        end
      -- end
    end
  end

  -- Dim hexes that are not encapments.
  -- if table.count(plotEntries) > 0 then
  --  UILens.SetLayerHexesArea( LensLayers.MAP_HEX_MASK, localPlayer, plotEntries );
  -- end

  for i = 1, #plotEntries, 1 do
    local colorLookup:string = "COLOR_GRADIENT8_" .. tostring(numCityEntries[i]);
    local color:number = UI.GetColorValue(colorLookup);
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, {plotEntries[i]}, color );
  end
end

-- ===========================================================================
function SetBarbarianLens()
  -- print("Show archeologist lens")
  local mapWidth, mapHeight = Map.GetGridSize();
  local localPlayer   :number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];

  local BarbarianColor = UI.GetColorValue("COLOR_BARBARIAN_BARB_LENS");
  local barbPlots:table = {};
  local barbAdjacent:table = {};

  for i = 0, (mapWidth * mapHeight) - 1, 1 do
    local pPlot:table = Map.GetPlotByIndex(i);

    if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) and plotHasBarbCamp(pPlot) then
      table.insert(barbPlots, i);
      table.insert(barbAdjacent, i);

      -- for pAdjacencyPlot in PlotRingIterator(pPlot, 1, SECTOR_NONE, DIRECTION_CLOCKWISE) do
      --  table.insert(barbAdjacent, pAdjacencyPlot:GetIndex());
      -- end
    end
  end

  -- Dim hexes that are not encapments
  -- if table.count(barbAdjacent) > 0 then
  --  UILens.SetLayerHexesArea( LensLayers.MAP_HEX_MASK, localPlayer, barbAdjacent );
  -- end

  if table.count(barbPlots) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, barbPlots, BarbarianColor );
  end
end

-- ===========================================================================
function SetResourceLens()
  -- print("Show Resource lens")
  local mapWidth, mapHeight = Map.GetGridSize();
  local localPlayer   :number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];

  local LuxConnectedColor   :number = UI.GetColorValue("COLOR_LUXCONNECTED_RES_LENS");
  local StratConnectedColor :number = UI.GetColorValue("COLOR_STRATCONNECTED_RES_LENS");
  local BonusConnectedColor :number = UI.GetColorValue("COLOR_BONUSCONNECTED_RES_LENS");
  local LuxNConnectedColor  :number = UI.GetColorValue("COLOR_LUXNCONNECTED_RES_LENS");
  local StratNConnectedColor  :number = UI.GetColorValue("COLOR_STRATNCONNECTED_RES_LENS");
  local BonusNConnectedColor  :number = UI.GetColorValue("COLOR_BONUSNCONNECTED_RES_LENS");

  -- Resources to exclude in the "Resource Lens"
  local ResourceExclusionList:table = {
    "RESOURCE_ANTIQUITY_SITE",
    "RESOURCE_SHIPWRECK"
  }

  local ConnectedLuxury       = {};
  local ConnectedStrategic    = {};
  local ConnectedBonus        = {};
  local NotConnectedLuxury    = {};
  local NotConnectedStrategic = {};
  local NotConnectedBonus     = {};
  local ResourcePlots         = {};

  for i = 0, (mapWidth * mapHeight) - 1, 1 do
    local pPlot:table = Map.GetPlotByIndex(i);

    if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) and playerHasDiscoveredResource(localPlayer, i) then
      local resourceType = pPlot:GetResourceType()
      if resourceType ~= nil and resourceType >= 0 then
        local resourceInfo = GameInfo.Resources[resourceType];
        if resourceInfo ~= nil then

          -- Check if resource is not in exclusion list
          local resourceToExclude:boolean = false;
          for i, rType in ipairs(ResourceExclusionList) do
            if resourceInfo.ResourceType == rType then
              resourceToExclude = true;
              break
            end
          end

          if not resourceToExclude then
            table.insert(ResourcePlots, i);
            if resourceInfo.ResourceClassType == "RESOURCECLASS_BONUS" then
              if plotHasImprovement(pPlot) and not pPlot:IsImprovementPillaged() then
                table.insert(ConnectedBonus, i)
              else
                table.insert(NotConnectedBonus, i)
              end
            elseif resourceInfo.ResourceClassType == "RESOURCECLASS_LUXURY" then
              if plotHasImprovement(pPlot) and not pPlot:IsImprovementPillaged() then
                table.insert(ConnectedLuxury, i)
              else
                table.insert(NotConnectedLuxury, i)
              end
            elseif resourceInfo.ResourceClassType == "RESOURCECLASS_STRATEGIC" then
              if plotHasImprovement(pPlot) and not pPlot:IsImprovementPillaged() then
                table.insert(ConnectedStrategic, i)
              else
                table.insert(NotConnectedStrategic, i)
              end
            end
          end
        end
      end
    end
  end

  -- Dim other hexes
  -- if table.count(ResourcePlots) > 0 then
  --  UILens.SetLayerHexesArea( LensLayers.MAP_HEX_MASK, localPlayer, ResourcePlots );
  -- end

  if table.count(ConnectedLuxury) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, ConnectedLuxury, LuxConnectedColor );
  end
  if table.count(ConnectedStrategic) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, ConnectedStrategic, StratConnectedColor );
  end
  if table.count(ConnectedBonus) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, ConnectedBonus, BonusConnectedColor );
  end
  if table.count(NotConnectedLuxury) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, NotConnectedLuxury, LuxNConnectedColor );
  end
  if table.count(NotConnectedStrategic) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, NotConnectedStrategic, StratNConnectedColor );
  end
  if table.count(NotConnectedBonus) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, NotConnectedBonus, BonusNConnectedColor );
  end
end

-- ===========================================================================
function SetWonderLens()
  -- print("Show wonder lens")
  local mapWidth, mapHeight = Map.GetGridSize();
  local localPlayer   :number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];

  local NaturalWonderColor  :number = UI.GetColorValue("COLOR_NATURAL_WONDER_LENS");
  local PlayerWonderColor   :number = UI.GetColorValue("COLOR_PLAYER_WONDER_LENS");

  local naturalWonderPlots  :table = {};
  local playerWonderPlots   :table = {};

  for i = 0, (mapWidth * mapHeight) - 1, 1 do
    local pPlot:table = Map.GetPlotByIndex(i);

    if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) then
      -- check for player wonder.
      if plotHasWonder(pPlot) then
        table.insert(playerWonderPlots, i);
      else
        -- Check for natural wonder
        local featureInfo = GameInfo.Features[pPlot:GetFeatureType()];
        if featureInfo ~= nil and featureInfo.NaturalWonder then
          table.insert(naturalWonderPlots, i)
        end
      end
    end
  end

  -- Dim hexes that are not encapments
  -- if table.count(barbAdjacent) > 0 then
  --  UILens.SetLayerHexesArea( LensLayers.MAP_HEX_MASK, localPlayer, barbAdjacent );
  -- end

  if table.count(naturalWonderPlots) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, naturalWonderPlots, NaturalWonderColor );
  end
  if table.count(playerWonderPlots) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, playerWonderPlots, PlayerWonderColor );
  end
end

-- ===========================================================================
function SetAdjacencyYieldLens()
  -- print("Show adjacency yield lens")
  local mapWidth, mapHeight = Map.GetGridSize();
  local localPlayer   :number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];

  local districtPlots   :table = {};
  local districtAdjYield  :table = {};

  for i = 0, (mapWidth * mapHeight) - 1, 1 do
    local pPlot:table = Map.GetPlotByIndex(i);

    if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) and pPlot:GetOwner() == localPlayer then
      if plotHasDistrict(pPlot) and (not pPlot:IsCity()) and (not plotHasWonder(pPlot)) then
        local pPlayer = Players[localPlayer];
        local districtID = pPlot:GetDistrictID()
        local pDistrict = pPlayer:GetDistricts():FindID(districtID);
        local pCity = pDistrict:GetCity();
        local hadAdjacency:boolean = false;
        -- Get adjacency yield
        for yieldInfo in GameInfo.Yields() do
          iBonus = pPlot:GetAdjacencyYield(localPlayer, pCity:GetID(), pPlot:GetDistrictType(), yieldInfo.Index);
          if iBonus > 0 then
            table.insert(districtPlots, i)
            table.insert(districtAdjYield, iBonus)
            hadAdjacency = true
            -- print("Yield " .. yieldInfo.YieldType .. " bonus " .. iBonus);
            break;
          end
        end

        if not hadAdjacency then
          table.insert(districtPlots, i)
          table.insert(districtAdjYield, 0)
        end
      end
    end
  end

  -- Dim hexes that are not encapments
  -- if table.count(barbAdjacent) > 0 then
  --  UILens.SetLayerHexesArea( LensLayers.MAP_HEX_MASK, localPlayer, barbAdjacent );
  -- end

  for i = 1, #districtPlots, 1 do
    local colorLookup:string = "COLOR_GRADIENT8_" .. tostring(Clamp(districtAdjYield[i], 0, 7) + 1);  -- Gradient goes from 1 - 8
    local color:number = UI.GetColorValue(colorLookup);
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, {districtPlots[i]}, color );
  end
end

-- ===========================================================================
function SetScoutLens()
  -- print("Show scout lens")
  local mapWidth, mapHeight = Map.GetGridSize();
  local localPlayer   :number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];

  local GoodyHutColor   :number = UI.GetColorValue("COLOR_GHUT_SCOUT_LENS");

  local goodyHutPlots   :table = {};

  for i = 0, (mapWidth * mapHeight) - 1, 1 do
    local pPlot:table = Map.GetPlotByIndex(i);

    if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) then
      -- check for player wonder. It has to be complete
      if plotHasGoodyHut(pPlot) then
        table.insert(goodyHutPlots, i);
      end
    end
  end

  -- Dim hexes that are not encapments
  -- if table.count(barbAdjacent) > 0 then
  --  UILens.SetLayerHexesArea( LensLayers.MAP_HEX_MASK, localPlayer, barbAdjacent );
  -- end

  if table.count(goodyHutPlots) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, goodyHutPlots, GoodyHutColor );
  end
end

function ClearScoutLens()
  -- print("Clear Scout Lens Hexes");
  ClearModdedLens();
end

-- Called when a archeologist is selected
function ShowScoutLens()
  SetActiveModdedLens(MODDED_LENS_ID.SCOUT);
  UILens.ToggleLayerOn(LensLayers.HEX_COLORING_APPEAL_LEVEL);
end

-- Helper functions ===========================================================
function SetActiveModdedLens(lensID)
  m_CurrentModdedLensOn = lensID;
  LuaEvents.MinimapPanel_ModdedLensOn(lensID);
  -- local dataDump = DataDumper(m_CurrentModdedLensOn, "currentModdedLensOn", true);
  -- print("Set: " .. dataDump);
  -- PlayerConfigurations[Game.GetLocalPlayer()]:SetValue("ModdedLens_CurrentModdedLensOn", dataDump);
end

function Alt_HighlightPlots(plotIndices)
  UILens.SetLayerHexesArea( LensLayers.MAP_HEX_MASK, Game.GetLocalPlayer(), plotIndices );

  -- UILens.ToggleLayerOn(LensLayers.HEX_COLORING_ATTACK);
  -- UILens.SetLayerHexesArea(LensLayers.HEX_COLORING_ATTACK, Game.GetLocalPlayer(), plotIndices);
end

function Alt_ClearHighlightedPlots()
  UILens.ClearLayerHexes( LensLayers.MAP_HEX_MASK );
  -- UILens.ToggleLayerOff(LensLayers.HEX_COLORING_ATTACK);
end

function GetCurrentModdedLens()
  -- local localPlayerID = Game.GetLocalPlayer();
  -- if(PlayerConfigurations[localPlayerID]:GetValue("ModdedLens_CurrentModdedLensOn") ~= nil) then
  --  local dataDump = PlayerConfigurations[localPlayerID]:GetValue("ModdedLens_CurrentModdedLensOn");
   -- print("Get: " .. dataDump);
  --  loadstring(dataDump)();
  --  m_CurrentModdedLensOn = currentModdedLensOn;
  -- else
   -- print("No modded lens data was found.")
  -- end
  return m_CurrentModdedLensOn;
end

function plotHasImprovement(plot)
  return plot:GetImprovementType() ~= -1;
end

function plotHasResource(plot)
  return plot:GetResourceType() ~= -1;
end

function plotHasFeature(plot)
  return plot:GetFeatureType() ~= -1;
end

function plotHasRemovableFeature(plot)
  local featureInfo = GameInfo.Features[plot:GetFeatureType()];
  if featureInfo ~= nil and featureInfo.Removable then
    return true;
  end
  return false;
end

function plotHasHill(plot)
  local terrainInfo = GameInfo.Terrains[plot:GetTerrainType()];
  if terrainInfo ~= nil and terrainInfo.Hills then
    return true
  end
  return false;
end

function plotHasWonder(plot)
  return plot:GetWonderType() ~= -1;
end

function plotHasDistrict(plot)
  return plot:GetDistrictType() ~= -1;
end

function plotHasNaturalWonder(plot)
  local featureInfo = GameInfo.Features[plot:GetFeatureType()];
  if featureInfo ~= nil and featureInfo.NaturalWonder then
    return true
  end
  return false
end

function plotHasImprovableWonder(plot)
  -- List of wonders that can have an improvement on them.
  local permitWonderList = {
    "FEATURE_CLIFFS_DOVER"
  }

  local featureInfo = GameInfo.Features[plot:GetFeatureType()];
  if featureInfo ~= nil then
    for i, wonderType in ipairs(permitWonderList) do
      if featureInfo.FeatureType == wonderType then
        return true
      end
    end
  end
  return false
end

function IsAdjYieldWonder(featureInfo)
  -- List any wonders here that provide yield bonuses, but not mentioned in Features.xml
  local specialWonderList = {
    "FEATURE_TORRES_DEL_PAINE"
  }

  if featureInfo ~= nil and featureInfo.NaturalWonder then
    for adjYieldInfo in GameInfo.Feature_AdjacentYields() do
      if adjYieldInfo ~= nil and adjYieldInfo.FeatureType == featureInfo.FeatureType then
        return true
      end
    end

    for i, featureType in ipairs(specialWonderList) do
      if featureType == featureInfo.FeatureType then
        return true
      end
    end
  end

  return false
end

function plotNextToBuffingWonder(plot)
  for pPlot in PlotRingIterator(plot, 1, SECTOR_NONE, DIRECTION_CLOCKWISE) do
    local featureInfo = GameInfo.Features[pPlot:GetFeatureType()]
    if IsAdjYieldWonder(featureInfo) then
      return true
    end
  end

  return false
end

function plotHasRecomFeature(plot)
  local featureInfo = GameInfo.Features[plot:GetFeatureType()]
  if featureInfo ~= nil then

    -- 1. Is it a floodplain?
    if featureInfo.FeatureType == "FEATURE_FLOODPLAINS" then
      return true
    end

    -- 2. Is it a forest next to a river?
    if featureInfo.FeatureType == "FEATURE_FOREST" and plot:IsRiver() then
      return true
    end

    -- 3. Is it a tile next to buffing wonder?
    if plotNextToBuffingWonder(plot) then
      return true
    end

    -- 4. Is it wonder, that can have an improvement?
    if plotHasImprovableWonder(plot) then
      return true
    end

  end

  return false
end

function plotHasAnitquitySite(plot)
  local resourceInfo = GameInfo.Resources[plot:GetResourceType()];
  if resourceInfo ~= nil and resourceInfo.ResourceType == "RESOURCE_ANTIQUITY_SITE" then
    return true;
  end

  return false
end

function plotHasShipwreck(plot)
  local resourceInfo = GameInfo.Resources[plot:GetResourceType()];
  if resourceInfo ~= nil and resourceInfo.ResourceType == "RESOURCE_SHIPWRECK" then
    return true;
  end
  return false
end

function plotHasBarbCamp(plot)
  local improvementInfo = GameInfo.Improvements[plot:GetImprovementType()];
  if improvementInfo ~= nil and improvementInfo.ImprovementType == "IMPROVEMENT_BARBARIAN_CAMP" then
    return true;
  end
  return false;
end

function plotHasGoodyHut(plot)
  local improvementInfo = GameInfo.Improvements[plot:GetImprovementType()];
  if improvementInfo ~= nil and improvementInfo.ImprovementType == "IMPROVEMENT_GOODY_HUT" then
    return true;
  end
  return false;
end

function plotResourceImprovable(plot)
  local plotIndex = plot:GetIndex()
  local playerID = Game.GetLocalPlayer()

  -- If the plot has a resource, and the player has discovered it, get the improvement specific to that
  if playerHasDiscoveredResource(playerID, plotIndex) then
    local resourceInfo = GameInfo.Resources[plot:GetResourceType()]
    if resourceInfo ~= nil then
      local improvementType;
      for validResourceInfo in GameInfo.Improvement_ValidResources() do
        if validResourceInfo ~= nil and validResourceInfo.ResourceType == resourceInfo.ResourceType then
          improvementType = validResourceInfo.ImprovementType;
          break
        end
      end

      if improvementType ~= nil then
        local improvementInfo = GameInfo.Improvements[improvementType];
        -- print("Plot " .. plotIndex .. " possibly can have " .. improvementType)
        return playerCanHave(playerID, improvementInfo);
      end
    end
  end

  return false
end

function playerCanRemoveFeature(playerID, plotIndex)
  local pPlot = Map.GetPlotByIndex(plotIndex)
  local pPlayer = Players[playerID];
  local featureInfo = GameInfo.Features[pPlot:GetFeatureType()]

  if featureInfo ~= nil then
    if not featureInfo.Removable then return false; end

    -- Check for remove tech
    if featureInfo.RemoveTech ~= nil then
      local tech = GameInfo.Technologies[featureInfo.RemoveTech]
      local playerTech:table = pPlayer:GetTechs();
      if tech ~= nil  then
        return playerTech:HasTech(tech.Index);
      else
        return false;
      end
    else
      return true;
    end
  end

  return false;
end

function BuilderCanConstruct(improvementInfo)
  for improvementBuildUnits in GameInfo.Improvement_ValidBuildUnits() do
    if improvementBuildUnits ~= nil and improvementBuildUnits.ImprovementType == improvementInfo.ImprovementType and
      improvementBuildUnits.UnitType == "UNIT_BUILDER" then
        return true
    end
  end

  return false
end

function plotCanHaveImprovement(playerID, plotIndex)
  local pPlot = Map.GetPlotByIndex(plotIndex)
  local pPlayer = Players[playerID]

  -- Handler for a generic tile
  for improvementInfo in GameInfo.Improvements() do
    if improvementInfo ~= nil and improvementInfo.Buildable then

      -- Does the player the prereq techs and civis
      if BuilderCanConstruct(improvementInfo) and playerCanHave(playerID, improvementInfo) then
        local improvementValid:boolean = false;

        -- Check for valid feature
        for validFeatureInfo in GameInfo.Improvement_ValidFeatures() do
          if validFeatureInfo ~= nil and validFeatureInfo.ImprovementType == improvementInfo.ImprovementType then
            -- Does this plot have this feature?
            local featureInfo = GameInfo.Features[validFeatureInfo.FeatureType]
            if featureInfo ~= nil and pPlot:GetFeatureType() == featureInfo.Index then
              if playerCanHave(playerID, featureInfo) and playerCanHave(playerID, validFeatureInfo) then
                print("(feature) Plot " .. pPlot:GetIndex() .. " can have " .. improvementInfo.ImprovementType)
                improvementValid = true;
                break;
              end
            end
          end
        end

        -- Check for valid terrain
        if not improvementValid then
          for validTerrainInfo in GameInfo.Improvement_ValidTerrains() do
            if validTerrainInfo ~= nil and validTerrainInfo.ImprovementType == improvementInfo.ImprovementType then
              -- Does this plot have this terrain?
              local terrainInfo = GameInfo.Terrains[validTerrainInfo.TerrainType]
              if terrainInfo ~= nil and pPlot:GetTerrainType() == terrainInfo.Index then
                if playerCanHave(playerID, terrainInfo) and playerCanHave(playerID, validTerrainInfo)  then
                  print("(terrain) Plot " .. pPlot:GetIndex() .. " can have " .. improvementInfo.ImprovementType)
                  improvementValid = true;
                  break;
                end
              end
            end
          end
        end

        -- Check for valid resource
        if not improvementValid then
          for validResourceInfo in GameInfo.Improvement_ValidResources() do
            if validResourceInfo ~= nil and validResourceInfo.ImprovementType == improvementInfo.ImprovementType then
              -- Does this plot have this terrain?
              local resourceInfo = GameInfo.Resources[validResourceInfo.ResourceType]
              if resourceInfo ~= nil and pPlot:GetResourceType() == resourceInfo.Index then
                if playerCanHave(playerID, resourceInfo) and playerCanHave(playerID, validResourceInfo)  then
                  print("(resource) Plot " .. pPlot:GetIndex() .. " can have " .. improvementInfo.ImprovementType)
                  improvementValid = true;
                  break;
                end
              end
            end
          end
        end

        -- Special check for coastal requirement
        if improvementInfo.Coast and (not pPlot:IsCoastalLand()) then
          print(plotIndex .. " plot is not coastal")
          improvementValid = false;
        end

        if improvementValid then
          return true
        end
      end
    end
  end

  return false;
end

-- General function to check if the player has xmlEntry.PrereqTech and xmlEntry.PrereqTech
-- Also handles unique traits, and bonuses received from city states
function playerCanHave(playerID, xmlEntry)
  if xmlEntry == nil then return false; end;

  local pPlayer = Players[playerID]
  if xmlEntry.PrereqTech ~= nil then
    local playerTech:table = pPlayer:GetTechs();
    local tech = GameInfo.Technologies[xmlEntry.PrereqTech]
    if tech ~= nil and (not playerTech:HasTech(tech.Index)) then
      -- print("Player does not have " .. tech.TechnologyType)
      return false;
    end
  end

  -- Does the player have the prereq civic if one exists
  if xmlEntry.PrereqCivic ~= nil then
    local playerCulture = pPlayer:GetCulture();
    local civic = GameInfo.Civics[xmlEntry.PrereqCivic]
    if civic ~= nil and (not playerCulture:HasCivic(civic.Index)) then
      -- print("Player does not have " .. civic.CivicType)
      return false;
    end
  end

  -- Is it a Unique thing to a player/civ
  if xmlEntry.TraitType ~= nil then
    -- print(xmlEntry.TraitType)
    local civilizationType = PlayerConfigurations[playerID]:GetCivilizationTypeName()
    local leaderType = PlayerConfigurations[playerID]:GetLeaderTypeName()
    local isSuzerain:boolean = false;

    -- Special handler for city state traits.
    local spitResult = Split(xmlEntry.TraitType, "_");
    if spitResult[1] == "MINOR" then
      local traitLeaderType;
      for traitInfo in GameInfo.LeaderTraits() do
        if traitInfo.TraitType == xmlEntry.TraitType then
          traitLeaderType = traitInfo.LeaderType
          break
        end
      end

      if traitLeaderType ~= nil then
        -- print("traitLeaderType " .. traitLeaderType)
        local traitLeaderID;

        -- See if this city state is present in the game
        for minorID in ipairs(PlayerManager.GetAliveMinorIDs()) do
          local minorLeaderType = PlayerConfigurations[minorID]:GetLeaderTypeName()
          if minorLeaderType == traitLeaderType then
            traitLeaderID = minorID;
            break;
          end
        end

        if traitLeaderID ~= nil then
          -- Found the player in the game. Is the suzerain the player
          if playerID ~= Players[traitLeaderID]:GetInfluence():GetSuzerain() then
            -- print("Player is not the suzerain of " .. minorLeaderType)
            return false
          else
            return true;
          end
        else
          -- print(traitLeaderType .. " is not in this game")
          return false;
        end
      end
    end

    for traitInfo in GameInfo.CivilizationTraits() do
      if traitInfo.TraitType == xmlEntry.TraitType then
        if traitInfo.CivilizationType ~= nil then
          if civilizationType ~= traitInfo.CivilizationType then
            -- print(civilizationType .. " ~= " .. traitInfo.CivilizationType)
            return false
          end
        end
      end
    end

    for traitInfo in GameInfo.LeaderTraits() do
      if traitInfo.TraitType == xmlEntry.TraitType then
        if traitInfo.LeaderType ~= nil then
          if leaderType ~= traitInfo.LeaderType then
            -- print(civilizationType .. " ~= " .. traitInfo.LeaderType)
            return false
          end
        end
      end
    end

  end

  return true;
end

function playerHasBuilderWonderModifier(playerID)
  -- Get civ, and leader type name
  local civTypeName = PlayerConfigurations[playerID]:GetCivilizationTypeName();
  local leaderTypeName = PlayerConfigurations[playerID]:GetLeaderTypeName();

  local civUA = GetCivilizationUniqueTraits(civTypeName);
  local leaderUA = GetLeaderUniqueTraits(leaderTypeName);

  for _, item in ipairs(civUA) do
    local traitModifier = GameInfo.TraitModifiers[item.Hash];
    -- dump(traitModifier);

    -- Not hashed, so find the modifier id
    for row in GameInfo.Modifiers() do
      if row.ModifierId == GameInfo.TraitModifiers[item.Hash].ModifierId then
        -- dump(row);

        if row.ModifierType == "MODIFIER_PLAYER_ADJUST_UNIT_WONDER_PERCENT" then
          -- print("Player has a modifier for wonder")
          return true;
        end
      end
    end
  end

  for _, item in ipairs(leaderUA) do
    local traitModifier = GameInfo.TraitModifiers[item.Hash];
    -- dump(traitModifier);

    -- Not hashed, so find the modifier id
    for row in GameInfo.Modifiers() do
      if row.ModifierId == GameInfo.TraitModifiers[item.Hash].ModifierId then
        -- dump(row);

        if row.ModifierType == "MODIFIER_PLAYER_ADJUST_UNIT_WONDER_PERCENT" then
          -- print("Player has a modifier for wonder")
          return true;
        end
      end
    end
  end
end

function playerHasBuilderDistrictModifier(playerID)
  -- Get civ, and leader
  local civTypeName = PlayerConfigurations[playerID]:GetCivilizationTypeName();
  local leaderTypeName = PlayerConfigurations[playerID]:GetLeaderTypeName();

  local civUA = GetCivilizationUniqueTraits(civTypeName);
  local leaderUA = GetLeaderUniqueTraits(leaderTypeName);

  for _, item in ipairs(civUA) do
    local traitModifier = GameInfo.TraitModifiers[item.Hash];
    -- dump(traitModifier);

    -- Not hashed, so find the modifier id
    for row in GameInfo.Modifiers() do
      if row.ModifierId == GameInfo.TraitModifiers[item.Hash].ModifierId then
        -- dump(row);

        if row.ModifierType == "MODIFIER_PLAYER_ADJUST_UNIT_DISTRICT_PERCENT" then
          -- print("Player has a modifier for district")
          return true;
        end
      end
    end
  end

  for _, item in ipairs(leaderUA) do
    local traitModifier = GameInfo.TraitModifiers[item.Hash];
    -- dump(traitModifier);

    -- Not hashed, so find the modifier id
    for row in GameInfo.Modifiers() do
      if row.ModifierId == GameInfo.TraitModifiers[item.Hash].ModifierId then
        -- dump(row);

        if row.ModifierType == "MODIFIER_PLAYER_ADJUST_UNIT_DISTRICT_PERCENT" then
          -- print("Player has a modifier for district")
          return true;
        end
      end
    end
  end
end

-- Uses same logic as the icon manager (returns true, if the resource icon is being displayed on the map)
function playerHasDiscoveredResource(playerID, plotIndex)
  local eObserverID = Game.GetLocalObserver();
  local pLocalPlayerVis = PlayerVisibilityManager.GetPlayerVisibility(eObserverID);

  local pPlot = Map.GetPlotByIndex(plotIndex);
  -- Have a Resource?
  local eResource = pLocalPlayerVis:GetLayerValue(VisibilityLayerTypes.RESOURCES, plotIndex);
  local bHideResource = ( pPlot ~= nil and ( pPlot:GetDistrictType() > 0 or pPlot:IsCity() ) );
  if (eResource ~= nil and eResource ~= -1 and not bHideResource ) then
    return true;
  end

  return false;
end

-- Tells if the district on this plot is complete or not
function districtComplete(playerID, plotIndex)
  local pPlayer = Players[playerID];
  local pPlot = Map.GetPlotByIndex(plotIndex);
  local districtID = pPlot:GetDistrictID();

  if districtID ~= nil and districtID >= 0 then
    local pDistrict = pPlayer:GetDistricts():FindID(districtID);
    if pDistrict ~= nil then
      return pDistrict:IsComplete()
    end
  end

  return false;
end

function isAncientClassicalWonder(wonderTypeID)
  -- print("Checking wonder " .. wonderTypeID .. " if ancient or classical")

  for row in GameInfo.Buildings() do
    if row.Index == wonderTypeID then
      -- Make hash, and get era
      if row.PrereqTech ~= nil then
        prereqTechHash = DB.MakeHash(row.PrereqTech);
        eraType = GameInfo.Technologies[prereqTechHash].EraType;
      elseif row.PrereqCivic ~= nil then
        prereqCivicHash = DB.MakeHash(row.PrereqCivic);
        eraType = GameInfo.Civics[prereqCivicHash].EraType;
      else
        -- Wonder has no prereq
        return true;
      end

      -- print("Era = " .. eraType);

      if eraType == nil then
        -- print("Could not find era for wonder " .. wonderTypeID)
        return true
      elseif eraType == "ERA_ANCIENT" or eraType == "ERA_CLASSICAL" then
        return true;
      end
    end
  end

  return false;
end

function GetUnitType( playerID: number, unitID : number )
  if( playerID == Game.GetLocalPlayer() ) then
    local pPlayer   :table = Players[playerID];
    local pUnit     :table = pPlayer:GetUnits():FindID(unitID);
    if pUnit ~= nil then
      return GameInfo.Units[pUnit:GetUnitType()].UnitType;
    end
  end
  return nil;
end

--------------------------------------------
-- Plot Iterator, Author: whoward69; URL: https://forums.civfanatics.com/threads/border-and-area-plot-iterators.474634/
  -- convert funcs odd-r offset to axial. URL: http://www.redblobgames.com/grids/hexagons/
  -- here grid == offset; hex == axial
  function ToHexFromGrid(grid)
    local hex = {
      x = grid.x - (grid.y - (grid.y % 2)) / 2;
      y = grid.y;
    }
    return hex
  end
  function ToGridFromHex(hex_x, hex_y)
    local grid = {
      x = hex_x + (hex_y - (hex_y % 2)) / 2;
      y = hex_y;
    }
    return grid.x, grid.y
  end

  SECTOR_NONE = nil
  SECTOR_NORTH = 1
  SECTOR_NORTHEAST = 2
  SECTOR_SOUTHEAST = 3
  SECTOR_SOUTH = 4
  SECTOR_SOUTHWEST = 5
  SECTOR_NORTHWEST = 6

  DIRECTION_CLOCKWISE = false
  DIRECTION_ANTICLOCKWISE = true

  DIRECTION_OUTWARDS = false
  DIRECTION_INWARDS = true

  CENTRE_INCLUDE = true
  CENTRE_EXCLUDE = false

  function PlotRingIterator(pPlot, r, sector, anticlock)
    -- print(string.format("PlotRingIterator((%i, %i), r=%i, s=%i, d=%s)", pPlot:GetX(), pPlot:GetY(), r, (sector or SECTOR_NORTH), (anticlock and "rev" or "fwd")))
    -- The important thing to remember with hex-coordinates is that x+y+z = 0
    -- so we never actually need to store z as we can always calculate it as -(x+y)
    -- See http://keekerdc.com/2011/03/hexagon-grids-coordinate-systems-and-distance-calculations/

    if (pPlot ~= nil and r > 0) then
      local hex = ToHexFromGrid({x=pPlot:GetX(), y=pPlot:GetY()})
      local x, y = hex.x, hex.y

      -- Along the North edge of the hex (x-r, y+r, z) to (x, y+r, z-r)
      local function north(x, y, r, i) return {x=x-r+i, y=y+r} end
      -- Along the North-East edge (x, y+r, z-r) to (x+r, y, z-r)
      local function northeast(x, y, r, i) return {x=x+i, y=y+r-i} end
      -- Along the South-East edge (x+r, y, z-r) to (x+r, y-r, z)
      local function southeast(x, y, r, i) return {x=x+r, y=y-i} end
      -- Along the South edge (x+r, y-r, z) to (x, y-r, z+r)
      local function south(x, y, r, i) return {x=x+r-i, y=y-r} end
      -- Along the South-West edge (x, y-r, z+r) to (x-r, y, z+r)
      local function southwest(x, y, r, i) return {x=x-i, y=y-r+i} end
      -- Along the North-West edge (x-r, y, z+r) to (x-r, y+r, z)
      local function northwest(x, y, r, i) return {x=x-r, y=y+i} end

      local side = {north, northeast, southeast, south, southwest, northwest}
      if (sector) then
        for i=(anticlock and 1 or 2), sector, 1 do
          table.insert(side, table.remove(side, 1))
        end
      end

      -- This coroutine walks the edges of the hex centered on pPlot at radius r
      local next = coroutine.create(function ()
        if (anticlock) then
          for s=6, 1, -1 do
            for i=r, 1, -1 do
              coroutine.yield(side[s](x, y, r, i))
            end
          end
        else
          for s=1, 6, 1 do
            for i=0, r-1, 1 do
              coroutine.yield(side[s](x, y, r, i))
            end
          end
        end

        return nil
      end)

      -- This function returns the next edge plot in the sequence, ignoring those that fall off the edges of the map
      return function ()
        local pEdgePlot = nil
        local success, hex = coroutine.resume(next)
        -- if (hex ~= nil) then print(string.format("hex(%i, %i, %i)", hex.x, hex.y, -1 * (hex.x+hex.y))) else print("hex(nil)") end

        while (success and hex ~= nil and pEdgePlot == nil) do
          pEdgePlot = Map.GetPlot(ToGridFromHex(hex.x, hex.y))
          if (pEdgePlot == nil) then success, hex = coroutine.resume(next) end
        end

        return success and pEdgePlot or nil
      end
    else
      -- Iterators have to return a function, so return a function that returns nil
      return function () return nil end
    end
  end


  function PlotAreaSpiralIterator(pPlot, r, sector, anticlock, inwards, centre)
    -- print(string.format("PlotAreaSpiralIterator((%i, %i), r=%i, s=%i, d=%s, w=%s, c=%s)", pPlot:GetX(), pPlot:GetY(), r, (sector or SECTOR_NORTH), (anticlock and "rev" or "fwd"), (inwards and "in" or "out"), (centre and "yes" or "no")))
    -- This coroutine walks each ring in sequence
    local next = coroutine.create(function ()
      if (centre and not inwards) then
        coroutine.yield(pPlot)
      end

      if (inwards) then
        for i=r, 1, -1 do
          for pEdgePlot in PlotRingIterator(pPlot, i, sector, anticlock) do
            coroutine.yield(pEdgePlot)
          end
        end
      else
        for i=1, r, 1 do
          for pEdgePlot in PlotRingIterator(pPlot, i, sector, anticlock) do
            coroutine.yield(pEdgePlot)
          end
        end
      end

      if (centre and inwards) then
        coroutine.yield(pPlot)
      end

      return nil
    end)

    -- This function returns the next plot in the sequence
    return function ()
      local success, pAreaPlot = coroutine.resume(next)
      return success and pAreaPlot or nil
    end
  end
-- End of iterator code --------------------

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

      -- Modded lens
      Controls.ScoutLensButton:SetCheck(false);
      Controls.AdjacencyYieldLensButton:SetCheck(false);
      Controls.WonderLensButton:SetCheck(false);
      Controls.ResourceLensButton:SetCheck(false);
      Controls.BarbarianLensButton:SetCheck(false);
      Controls.CityOverlap9LensButton:SetCheck(false);
      Controls.CityOverlap6LensButton:SetCheck(false);
      Controls.ArchaeologistLensButton:SetCheck(false);
      Controls.BuilderLensButton:SetCheck(false);

      if GetCurrentModdedLens() ~= MODDED_LENS_ID.NONE then
        ClearModdedLens()
      end
    end
  end
end

-- For modded lens on unit selection
function OnUnitSelectionChanged( playerID:number, unitID:number, hexI:number, hexJ:number, hexK:number, bSelected:boolean, bEditable:boolean )
  if playerID == Game.GetLocalPlayer() then
    local unitType = GetUnitType(playerID, unitID);
    if unitType then
      if bSelected then
        if unitType == "UNIT_BUILDER" and AUTO_APPLY_BUILDER_LENS then
          ShowBuilderLens();
        elseif unitType == "UNIT_ARCHAEOLOGIST" and AUTO_APPLY_ARCHEOLOGIST_LENS then
          ShowArchaeologistLens();
        elseif (unitType == "UNIT_SCOUT" or unitType == "UNIT_RANGER") and AUTO_APPLY_SCOUT_LENS then
          ShowScoutLens();
        end
      -- Deselection
      else
        if unitType == "UNIT_BUILDER" and AUTO_APPLY_BUILDER_LENS then
          ClearBuilderLensHexes();
        elseif unitType == "UNIT_ARCHAEOLOGIST" and AUTO_APPLY_ARCHEOLOGIST_LENS then
          ClearArchaeologistLens();
        elseif (unitType == "UNIT_SCOUT" or unitType == "UNIT_RANGER") and AUTO_APPLY_SCOUT_LENS then
          ClearScoutLens();
        end
      end
    end
  end
end

-- For builder lens
function OnUnitChargesChanged( playerID: number, unitID : number, newCharges : number, oldCharges : number )
  local localPlayer = Game.GetLocalPlayer()

  if playerID == localPlayer then
    local unitType = GetUnitType(playerID, unitID)

    if unitType and unitType == "UNIT_BUILDER" then
      if newCharges == 0 then
        ClearBuilderLensHexes();
      end
    end
  end
end

-- For modded lens during multiplayer. Might need to test this further
function OnUnitCaptured( currentUnitOwner, unit, owningPlayer, capturingPlayer )
  local localPlayer = Game.GetLocalPlayer()

  if owningPlayer == localPlayer then
    local unitType = GetUnitType(owningPlayer, unitID)

    if unitType and unitType == "UNIT_BUILDER" then
      ClearBuilderLensHexes();
    elseif unitType and unitType == "UNIT_ARCHAEOLOGIST" then
      ClearArchaeologistLens();
    end
  end
end

-- For modded lens on unit deletion
function OnUnitRemovedFromMap( playerID: number, unitID : number )
  local localPlayer = Game.GetLocalPlayer()

  if playerID == localPlayer then
    currentModdedLens = GetCurrentModdedLens();
    if currentModdedLens == MODDED_LENS_ID.BUILDER then
      ClearBuilderLensHexes();
    elseif currentModdedLens == MODDED_LENS_ID.ARCHAEOLOGIST then
      ClearArchaeologistLens();
    elseif currentModdedLens == MODDED_LENS_ID.SCOUT then
      ClearScoutLens();
    end
  end
end

-- To update the scout lens, when a scout/ranger moves
function OnUnitMoved( playerID:number, unitID:number )
  if playerID == Game.GetLocalPlayer() then
    local unitType = GetUnitType(playerID, unitID);
    local currentModdedLens = GetCurrentModdedLens();
    if (unitType == "UNIT_SCOUT" or unitType == "UNIT_RANGER") and AUTO_APPLY_SCOUT_LENS then
      -- Refresh the scout lens, if already applied. Need this check so scout lens
      -- does not apply when a scout is currently under a operation
      if currentModdedLens == MODDED_LENS_ID.SCOUT then
        ClearScoutLens();
        ShowScoutLens();
      end
    end
  end
end

function HandleMouseForModdedLens( mousex:number, mousey:number )
  -- Don't do anything if mouse is dragging
  if not m_isMouseDragging then
    local plotId = UI.GetCursorPlotID();
    if (not Map.IsPlot(plotId)) then
      return;
    end

    local pPlot = Map.GetPlotByIndex(plotId)

    -- Handle for different lenses
    if UILens.IsLayerOn(LensLayers.HEX_COLORING_WATER_AVAILABLITY) then
      -- Alt_ClearHighlightedPlots();
      -- local highlightPlot:table = {}
      -- for pAdjacencyPlot in PlotAreaSpiralIterator(pPlot, 3, SECTOR_NONE, DIRECTION_CLOCKWISE, DIRECTION_OUTWARDS, CENTRE_INCLUDE) do
      --  table.insert(highlightPlot, pAdjacencyPlot:GetIndex())
      -- end

      -- Alt_HighlightPlots(highlightPlot);
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
    if msg == MouseEvents.RButtonDown then
      local minix, miniy = GetMinimapMouseCoords( pInputStruct:GetX(), pInputStruct:GetY() );
      if IsMouseInMinimap( minix, miniy ) then
        return true
      end
    end
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
-- INITIALIZATION
-- ===========================================================================
function Initialize()
  m_MiniMap_xmloffsety = Controls.MiniMap:GetOffsetY();
  m_ContinentsCache = Map.GetContinentsInUse();
  UI.SetMinimapImageControl(Controls.MinimapImage);
  Controls.LensChooserList:CalculateSize();

  ContextPtr:SetInputHandler( OnInputHandler, true );
  ContextPtr:SetShutdown( OnShutdown );

  Controls.LensPanel:ChangeParent(Controls.LensButton);
  Controls.MapOptionsPanel:ChangeParent(Controls.MapOptionsButton);
  Controls.ToggleResourcesButton:SetCheck( UserConfiguration.ShowMapResources() );
  Controls.ToggleYieldsButton:SetCheck( UserConfiguration.ShowMapYield() );

  -- Modded lens
  Controls.ScoutLensButton:RegisterCallback( Mouse.eLClick, ToggleScoutLens );
  Controls.AdjacencyYieldLensButton:RegisterCallback( Mouse.eLClick, ToggleAdjacencyYieldLens );
  Controls.WonderLensButton:RegisterCallback( Mouse.eLClick, ToggleWonderLens );
  Controls.ResourceLensButton:RegisterCallback( Mouse.eLClick, ToggleResourceLens );
  Controls.BarbarianLensButton:RegisterCallback( Mouse.eLClick, ToggleBarbarianLens );
  Controls.CityOverlap9LensButton:RegisterCallback( Mouse.eLClick, ToggleCityOverlap9Lens );
  Controls.CityOverlap6LensButton:RegisterCallback( Mouse.eLClick, ToggleCityOverlap6Lens );
  Controls.ArchaeologistLensButton:RegisterCallback( Mouse.eLClick, ToggleArchaeologistLens );
  Controls.BuilderLensButton:RegisterCallback( Mouse.eLClick, ToggleBuilderLens );

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

  LuaEvents.NotificationPanel_ShowContinentLens.Add(OnToggleContinentLensExternal);
  LuaEvents.Tutorial_DisableMapDrag.Add( OnTutorial_DisableMapDrag );
  LuaEvents.Tutorial_SwitchToWorldView.Add( OnTutorial_SwitchToWorldView );

  -- For modded lenses
  Events.UnitSelectionChanged.Add( OnUnitSelectionChanged );
  Events.UnitCaptured.Add( OnUnitCaptured );
  Events.UnitChargesChanged.Add( OnUnitChargesChanged );
  Events.UnitRemovedFromMap.Add( OnUnitRemovedFromMap );
  Events.UnitMoved.Add( OnUnitMoved );

  -- CQUI Handlers
  LuaEvents.CQUI_Option_ToggleBindings.Add( CQUI_OnToggleBindings );
  LuaEvents.CQUI_Option_ToggleYields.Add( ToggleYieldIcons );
  LuaEvents.CQUI_SettingsUpdate.Add( CQUI_OnSettingsUpdate );
  LuaEvents.CQUI_SettingsInitialized.Add( CQUI_UpdateMinimapSize );

  -- CQUI: Toggle yield icons if option is enabled
  if(GameConfiguration.GetValue("CQUI_ToggleYieldsOnLoad")) then
    print("test");
    ToggleYieldIcons();
  end
end
Initialize();
