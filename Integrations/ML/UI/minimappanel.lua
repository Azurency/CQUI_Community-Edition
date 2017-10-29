-- ===========================================================================
--  MINIMAP PANEL
-- ===========================================================================
include( "InstanceManager" );
include( "Civ6Common.lua" ); -- GetCivilizationUniqueTraits, GetLeaderUniqueTraits
include( "SupportFunctions" );
--include( "TradeSupport" )

-- ===========================================================================
--  CONSTANTS
-- ===========================================================================
local MINIMAP_COLLAPSED_OFFSETY :number = -180;
local LENS_PANEL_OFFSET:number = 50;
local MINIMAP_BACKING_PADDING_SIZEY:number = 60;

-- Used to control ModalLensPanel.lua
local MODDED_LENS_ID:table = {
  NONE = 0;
  APPEAL = 1;
  BUILDER = 2;
  ARCHAEOLOGIST = 3;
  BARBARIAN = 4;
  CITY_OVERLAP = 5;
  RESOURCE = 6;
  WONDER = 7;
  ADJACENCY_YIELD = 8;
  SCOUT = 9;
  NATURALIST = 10;
  CUSTOM = 11;
};

-- Different from above, since it uses a government lens, instead of appeal
local AREA_LENS_ID:table = {
  NONE = 0;
  GOVERNMENT = 1;
  CITIZEN_MANAGEMENT = 2;
}

-- Should the builder lens auto apply, when a builder is selected.
local AUTO_APPLY_BUILDER_LENS:boolean = true;

-- Should the archaeologist lens auto apply, when a archaeologist is selected.
local AUTO_APPLY_ARCHEOLOGIST_LENS:boolean = true

-- Should the scout lens auto apply, when a scout/ranger is selected.
local AUTO_APPLY_SCOUT_LENS:boolean = true;

-- Show citizen management when managing citizens
local SHOW_CITIZEN_MANAGEMENT_INSCREEN:boolean = true;

-- Highlight nothing to do (red plots) in builder lens
local SHOW_NOTHING_TODO_IN_BUILDER_LENS:boolean = true;

-- Highlight generic (white plots) in builder lens
local SHOW_GENERIC_PLOTS_IN_BUILDER_LENS:boolean = true;

local CITY_WORK_RANGE:number = 3;

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
local m_Toggle2DViewId          = Input.GetActionId("Toggle2DView");

local m_isMouseDragEnabled      :boolean = true; -- Can the camera be moved by dragging on the minimap?
local m_isMouseDragging         :boolean = false; -- Was LMB clicked inside the minimap, and has not been released yet?
local m_hasMouseDragged         :boolean = false; -- Has there been any movements since m_isMouseDragging became true?
local m_wasMouseInMinimap       :boolean = false; -- Was the mouse over the minimap the last time we checked?

local m_CurrentModdedLensOn     :number  = MODDED_LENS_ID.NONE;
local m_CurrentAreaLensOn       :number  = AREA_LENS_ID.NONE;

local m_CustomLens_PlotsAndColors:table = {}

-- Resource Lens Specific Vars
local ResourcesToHide:table = {};
local ResourceCategoryToHide:table = {};

local m_CityOverlapRange:number = 6;

local m_CurrentCursorPlotID:number = -1;

-- Citizen management lens variables
local m_CitizenManagementOn:boolean = false;
local m_FullClearAreaLens:boolean = true;
local m_tAreaPlotsColored:table = {}

-- Settler Lens Variables
local m_CtrlDown:boolean = false;

local CQUI_MapSize = 512;
local CQUI_MapImageScaler = 0.5;

local CQUI_MapBackingXSizeDiff = 27;
local CQUI_MapBackingYSizeDiff = 54;

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
  local size = GameConfiguration.GetValue("CQUI_MinimapSize");
  if size ~= nil then
  CQUI_MapSize = size
  else
  print_debug("Using previous minimap size")
  end

  --Cycles the minimap after resizing
  local xSize = CQUI_MapSize
  local ySize = CQUI_MapSize * CQUI_MapImageScaler
  Controls.MinimapContainer:SetSizeVal(xSize, ySize);
  Controls.MinimapImage:SetSizeVal(xSize, ySize);
  Controls.MinimapBacking:SetSizeVal(xSize + CQUI_MapBackingXSizeDiff, ySize + CQUI_MapBackingYSizeDiff);
  -- Controls.CollapseAnim:SetEndVal(0, Controls.MinimapImage:GetOffsetY() + Controls.MinimapImage:GetSizeY());

  --Squeezes the map buttons if extra space is needed
  if(CQUI_MapSize < 256) then
  Controls.OptionsStack:SetPadding(-7);
  else
  Controls.OptionsStack:SetPadding(-3);
  end
end

function CQUI_OnSettingsUpdate()
  AUTO_APPLY_ARCHEOLOGIST_LENS = GameConfiguration.GetValue("CQUI_AutoapplyArchaeologistLens");
  AUTO_APPLY_BUILDER_LENS = GameConfiguration.GetValue("CQUI_AutoapplyBuilderLens");
  AUTO_APPLY_SCOUT_LENS = GameConfiguration.GetValue("CQUI_AutoapplyScoutLens");
  SHOW_CITIZEN_MANAGEMENT_INSCREEN = GameConfiguration.GetValue("CQUI_ShowCityMangeAreaInScreen");
  SHOW_NOTHING_TODO_IN_BUILDER_LENS = GameConfiguration.GetValue("CQUI_ShowNothingToDoBuilderLens");
  SHOW_GENERIC_PLOTS_IN_BUILDER_LENS = GameConfiguration.GetValue("CQUI_ShowGenericBuilderLens");

  --Cycles the minimap after resizing
  CQUI_UpdateMinimapSize();
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
  Controls.LensChooserList:CalculateSize();
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
    Controls.CityOverlapLensButton:SetCheck(false);
    Controls.ArchaeologistLensButton:SetCheck(false);
    Controls.BuilderLensButton:SetCheck(false);
    Controls.NaturalistLensButton:SetCheck(false);

    -- Side Menus
    Controls.ResourceLensOptionsPanel:SetHide(true);
    Controls.OverlapLensOptionsPanel:SetHide(true);

    if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
  else
    Controls.ReligionLensButton:SetHide(not GameCapabilities.HasCapability("CAPABILITY_LENS_RELIGION"));
    Controls.AppealLensButton:SetHide(not GameCapabilities.HasCapability("CAPABILITY_LENS_APPEAL"));
    Controls.GovernmentLensButton:SetHide(not GameCapabilities.HasCapability("CAPABILITY_LENS_GOVERNMENT"));
    Controls.WaterLensButton:SetHide(not GameCapabilities.HasCapability("CAPABILITY_LENS_SETTLER"));
    Controls.TourismLensButton:SetHide(not GameCapabilities.HasCapability("CAPABILITY_LENS_TOURISM"));
    -- Controls.LensToggleStack:CalculateSize();

    -- Don't call this otherwise the panel is ridiculously long
    -- Controls.LensPanel:SetSizeY(Controls.LensToggleStack:GetSizeY() + LENS_PANEL_OFFSET);
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
    SetActiveAreaLens(AREA_LENS_ID.GOVERNMENT);

    -- Check if the gov lens is already active. Needed to clear any gov lens
    if UILens.IsLayerOn(LensLayers.HEX_COLORING_GOVERNMENT) then
      -- Unapply the appeal lens, so it can be cleared from the screen
      UILens.SetActive("Default");
    end

    UILens.SetActive("Government");
    RefreshInterfaceMode();
  else
    m_shouldCloseLensMenu = false;
    if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
    SetActiveAreaLens(AREA_LENS_ID.NONE);
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
function ToggleCityOverlapLens()
  if Controls.CityOverlapLensButton:IsChecked() then
    SetActiveModdedLens(MODDED_LENS_ID.CITY_OVERLAP);

    -- Check if the appeal lens is already active
    if UILens.IsLayerOn(LensLayers.HEX_COLORING_APPEAL_LEVEL) then
      -- Unapply the appeal lens, so it can be cleared from the screen
      UILens.SetActive("Default");
    end

    UILens.SetActive("Appeal");

    RefreshInterfaceMode();
    Controls.OverlapLensOptionsPanel:SetHide(false);
  else
    m_shouldCloseLensMenu = false;
    if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
    Controls.OverlapLensOptionsPanel:SetHide(true);
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

    RefreshResourcePicker();
    RefreshInterfaceMode();

    Controls.ResourceLensOptionsPanel:SetHide(false);
  else
    m_shouldCloseLensMenu = false;
    if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
    Controls.ResourceLensOptionsPanel:SetHide(true);
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
function ToggleNaturalistLens()
  if Controls.NaturalistLensButton:IsChecked() then
    SetActiveModdedLens(MODDED_LENS_ID.NATURALIST);

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
-- Remaining MINIMAP
-- Resize functions, callbacks, etc
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
    Controls.ExpandAnim:SetEndVal(0, -Controls.MinimapContainer:GetOffsetY() - Controls.MinimapContainer:GetSizeY());
    Controls.ExpandAnim:SetToBeginning();
    Controls.ExpandAnim:Play();
    Controls.CompassArm:SetPercent(.25);
  else
    UI.PlaySound("Minimap_Closed");
    Controls.ExpandButton:SetHide( false );
    Controls.CollapseButton:SetHide( true );
    Controls.Pause:Play();
    Controls.CollapseAnim:SetEndVal(0, Controls.MinimapContainer:GetOffsetY() + Controls.MinimapContainer:GetSizeY());
    Controls.CollapseAnim:SetToBeginning();
    Controls.CollapseAnim:Play();
    Controls.CompassArm:SetPercent(.5);
  end
  m_isCollapsed = not m_isCollapsed;
end

-- ===========================================================================
function OnMinimapImageSizeChanged()
  ResizeBacking();
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

  Controls.ResourceLensOptionsPanel:SetHide(true);
  Controls.OverlapLensOptionsPanel:SetHide(true);
end

-- ===========================================================================
function OnLensLayerOn( layerNum:number )
  if layerNum == LensLayers.HEX_COLORING_RELIGION then
    UI.PlaySound("UI_Lens_Overlay_On");
    UILens.SetDesaturation(1.0);
  elseif layerNum == LensLayers.HEX_COLORING_APPEAL_LEVEL then
    if m_CurrentModdedLensOn == MODDED_LENS_ID.APPEAL then
      SetAppealHexes();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.BUILDER then
      SetBuilderLensHexes();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.ARCHAEOLOGIST then
      SetArchaeologistLens();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.CITY_OVERLAP then
      SetCityOverlapLens();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.BARBARIAN then
      SetBarbarianLens();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.RESOURCE then
      SetResourceLens();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.WONDER then
      SetWonderLens();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.ADJACENCY_YIELD then
      SetAdjacencyYieldLens();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.SCOUT then
      SetScoutLens();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.NATURALIST then
      SetNaturalistLens();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.CUSTOM then
      SetCustomLens();
    end
    UI.PlaySound("UI_Lens_Overlay_On");
  elseif layerNum == LensLayers.HEX_COLORING_GOVERNMENT then
    if m_CurrentAreaLensOn == AREA_LENS_ID.GOVERNMENT then
      SetGovernmentHexes();
      UI.PlaySound("UI_Lens_Overlay_On");
    -- else Extra Area Lenses go here
    end
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
  if layerNum == LensLayers.HEX_COLORING_RELIGION then
    UILens.SetDesaturation(0.0);

  elseif (layerNum == LensLayers.HEX_COLORING_CONTINENT or
      layerNum == LensLayers.HEX_COLORING_OWING_CIV) then
    UI.PlaySound("UI_Lens_Overlay_Off");

  -- Clear Modded Lens (Appeal lens included)
  elseif layerNum == LensLayers.HEX_COLORING_APPEAL_LEVEL then
    UILens.ClearLayerHexes( LensLayers.MAP_HEX_MASK );
    if UI.GetInterfaceMode() ~= InterfaceModeTypes.VIEW_MODAL_LENS or (UI.GetHeadSelectedUnit() == nil) then
      UILens.ClearLayerHexes(LensLayers.HEX_COLORING_APPEAL_LEVEL);
    end
    UI.PlaySound("UI_Lens_Overlay_Off");

  -- Clear Area Lens (Government lens included)
  elseif layerNum == LensLayers.HEX_COLORING_GOVERNMENT then
    UILens.ClearLayerHexes( LensLayers.MAP_HEX_MASK );
    if UI.GetInterfaceMode() ~= InterfaceModeTypes.VIEW_MODAL_LENS or (UI.GetHeadSelectedUnit() == nil) then
      UILens.ClearLayerHexes(LensLayers.HEX_COLORING_GOVERNMENT);
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
  if (not m_CtrlDown) or UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
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
        local visibleCityPlots:table = Map.GetCityPlots():GetVisiblePurchasedPlots(pCity);

        if(table.count(visibleCityPlots) > 0) then
          UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_GOVERNMENT, localPlayer, visibleCityPlots, GovernmentColor );
        end
      end
    end
  end

  m_FullClearAreaLens = true;
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

      -- NATIONAL PARK
      --------------------------------------
      elseif pPlot:IsNationalPark() then
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

      -- HILL - MINE
      --------------------------------------
      elseif plotHasImprovableHill(pPlot) then
        if plotNextToBuffingWonder(pPlot) then
          table.insert(recomFeatureHexes, i)
        else
          table.insert(hillHexes, i);
        end

      -- GENERIC TILE
      --------------------------------------
      elseif plotCanHaveImprovement(localPlayer, i) then
        if plotNextToBuffingWonder(pPlot) then
          table.insert(recomFeatureHexes, i)
        elseif plotCanHaveFarm(plot) then
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
  if SHOW_GENERIC_PLOTS_IN_BUILDER_LENS and table.count(genericHexes) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, genericHexes, GenericColor );
  end
  if SHOW_NOTHING_TODO_IN_BUILDER_LENS and table.count(unworkableHexes) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, unworkableHexes, NothingColor );
  end
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
function SetCityOverlapLens()
  -- print("Show City Overlap 6 lens")
  local mapWidth, mapHeight = Map.GetGridSize();
  local localPlayer   :number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];

  local plotEntries       :table = {};
  local numCityEntries    :table = {};
  local localPlayerCities = Players[localPlayer]:GetCities()

  for i = 0, (mapWidth * mapHeight) - 1, 1 do
    local pPlot:table = Map.GetPlotByIndex(i);

    if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) then
      if pPlot:GetOwner() == localPlayer or Controls.ShowLensOutsideBorder:IsChecked() then
        local numCities = 0;
        for _, pCity in localPlayerCities:Members() do
          if Map.GetPlotDistance(pPlot:GetX(), pPlot:GetY(), pCity:GetX(), pCity:GetY()) <= m_CityOverlapRange then
            numCities = numCities + 1;
          end
        end

        if numCities > 0 then
          numCities = Clamp(numCities, 1, 8);

          table.insert(plotEntries, i);
          table.insert(numCityEntries, numCities);
        end
      end
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

function Alt_SetCityOverlapLens()
  local plotId = UI.GetCursorPlotID();
  if (not Map.IsPlot(plotId)) then
    return;
  end

  local pPlot = Map.GetPlotByIndex(plotId)
  local localPlayer = Game.GetLocalPlayer()
  local localPlayerVis:table = PlayersVisibility[localPlayer]
  local cityPlots:table = {}
  local normalPlot:table = {}

  for pAdjacencyPlot in PlotAreaSpiralIterator(pPlot, m_CityOverlapRange, SECTOR_NONE, DIRECTION_CLOCKWISE, DIRECTION_OUTWARDS, CENTRE_INCLUDE) do
    if localPlayerVis:IsRevealed(pAdjacencyPlot:GetX(), pAdjacencyPlot:GetY()) then
      if (pAdjacencyPlot:GetOwner() == localPlayer and pAdjacencyPlot:IsCity()) then
        table.insert(cityPlots, pAdjacencyPlot:GetIndex());
      else
        table.insert(normalPlot, pAdjacencyPlot:GetIndex());
      end
    end
  end

  if (table.count(cityPlots) > 0) then
    local plotColor:number = UI.GetColorValue("COLOR_GRADIENT8_1");
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, cityPlots, plotColor );
  end

  if (table.count(normalPlot) > 0) then
    local plotColor:number = UI.GetColorValue("COLOR_GRADIENT8_3");
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, normalPlot, plotColor );
  end
end

function RefreshCityOverlapLens()
  -- Assuming City Overlap lens is already applied
  UILens.ClearLayerHexes(LensLayers.HEX_COLORING_APPEAL_LEVEL);
  SetCityOverlapLens();
end

function Refresh_AltCityOverlapLens()
  UILens.ClearLayerHexes(LensLayers.HEX_COLORING_APPEAL_LEVEL);
  Alt_SetCityOverlapLens();
end

function IncreseOverlapRange()
  m_CityOverlapRange = m_CityOverlapRange + 1;
  Controls.OverlapRangeLabel:SetText(m_CityOverlapRange);
  RefreshCityOverlapLens();
end

function DecreaseOverlapRange()
  if (m_CityOverlapRange > 0) then
    m_CityOverlapRange = m_CityOverlapRange - 1;
  end
  Controls.OverlapRangeLabel:SetText(m_CityOverlapRange);
  RefreshCityOverlapLens();
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
          if not has_value(ResourceExclusionList, resourceInfo.ResourceType) and (not has_value(ResourcesToHide, resourceInfo.ResourceType)) then
            table.insert(ResourcePlots, i);
            if resourceInfo.ResourceClassType == "RESOURCECLASS_BONUS" and
                not has_value(ResourceCategoryToHide, "Bonus") then
              if plotHasImprovement(pPlot) and not pPlot:IsImprovementPillaged() then
                table.insert(ConnectedBonus, i)
              else
                table.insert(NotConnectedBonus, i)
              end
            elseif resourceInfo.ResourceClassType == "RESOURCECLASS_LUXURY" and
                not has_value(ResourceCategoryToHide, "Luxury") then
              if plotHasImprovement(pPlot) and not pPlot:IsImprovementPillaged() then
                table.insert(ConnectedLuxury, i)
              else
                table.insert(NotConnectedLuxury, i)
              end
            elseif resourceInfo.ResourceClassType == "RESOURCECLASS_STRATEGIC" and
                not has_value(ResourceCategoryToHide, "Strategic") then
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

function RefreshResourcePicker()
  print_debug("Show Resource Picker")
  local mapWidth, mapHeight = Map.GetGridSize();
  local localPlayer   :number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];

  -- Resources to exclude in the "Resource Lens"
  local ResourceExclusionList:table = {
    "RESOURCE_ANTIQUITY_SITE",
    "RESOURCE_SHIPWRECK"
  }

  local BonusResources:table = {}
  local LuxuryResources:table = {}
  local StrategicResources:table = {}

  for i = 0, (mapWidth * mapHeight) - 1, 1 do
    local pPlot:table = Map.GetPlotByIndex(i);

    if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) and playerHasDiscoveredResource(localPlayer, i) then
      local resourceType = pPlot:GetResourceType()
      if resourceType ~= nil and resourceType >= 0 then
        local resourceInfo = GameInfo.Resources[resourceType];
        if resourceInfo ~= nil then
          -- Check if resource is not in exclusion list
          if not has_value(ResourceExclusionList, resourceInfo.ResourceType) then
            if resourceInfo.ResourceClassType == "RESOURCECLASS_BONUS" then
              if not has_rInfo(BonusResources, resourceInfo.ResourceType) then
                table.insert(BonusResources, resourceInfo)
              end
            elseif resourceInfo.ResourceClassType == "RESOURCECLASS_LUXURY" then
              if not has_rInfo(LuxuryResources, resourceInfo.ResourceType) then
                table.insert(LuxuryResources, resourceInfo)
              end
            elseif resourceInfo.ResourceClassType == "RESOURCECLASS_STRATEGIC" then
              if not has_rInfo(StrategicResources, resourceInfo.ResourceType) then
                table.insert(StrategicResources, resourceInfo)
              end
            end
          end
        end
      end
    end
  end

  Controls.BonusResourcePickStack:DestroyAllChildren();
  Controls.LuxuryResourcePickStack:DestroyAllChildren();
  Controls.StrategicResourcePickStack:DestroyAllChildren();

  -- Bonus Resources
  if table.count(BonusResources) > 0 and
      not has_value(ResourceCategoryToHide, "Bonus") then
    for i, resourceInfo in ipairs(BonusResources) do
      -- print(Locale.Lookup(resourceInfo.Name))
      local resourcePickInstance:table = {};
      ContextPtr:BuildInstanceForControl( "ResourcePickEntry", resourcePickInstance, Controls.BonusResourcePickStack );
      resourcePickInstance.ResourceLabel:SetText("[ICON_" .. resourceInfo.ResourceType .. "]" .. Locale.Lookup(resourceInfo.Name));

      if has_value(ResourcesToHide, resourceInfo.ResourceType) then
        resourcePickInstance.ResourceCheckbox:SetCheck(false);
      end

      resourcePickInstance.ResourceCheckbox:RegisterCallback(Mouse.eLClick, function() HandleResourceCheckbox(resourcePickInstance, resourceInfo.ResourceType); end);
    end
  end

  -- Luxury Resources
  if table.count(LuxuryResources) > 0 and
      not has_value(ResourceCategoryToHide, "Luxury") then
    for i, resourceInfo in ipairs(LuxuryResources) do
      -- print(Locale.Lookup(resourceInfo.Name))
      local resourcePickInstance:table = {};
      ContextPtr:BuildInstanceForControl( "ResourcePickEntry", resourcePickInstance, Controls.LuxuryResourcePickStack );
      resourcePickInstance.ResourceLabel:SetText("[ICON_" .. resourceInfo.ResourceType .. "]" .. Locale.Lookup(resourceInfo.Name));

      if has_value(ResourcesToHide, resourceInfo.ResourceType) then
        resourcePickInstance.ResourceCheckbox:SetCheck(false);
      end

      resourcePickInstance.ResourceCheckbox:RegisterCallback(Mouse.eLClick, function() HandleResourceCheckbox(resourcePickInstance, resourceInfo.ResourceType); end);
    end
  end

  -- Strategic Resources
  if table.count(StrategicResources) > 0 and
      not has_value(ResourceCategoryToHide, "Strategic") then
    for i, resourceInfo in ipairs(StrategicResources) do
      -- print(Locale.Lookup(resourceInfo.Name))
      local resourcePickInstance:table = {};
      ContextPtr:BuildInstanceForControl( "ResourcePickEntry", resourcePickInstance, Controls.StrategicResourcePickStack );
      resourcePickInstance.ResourceLabel:SetText("[ICON_" .. resourceInfo.ResourceType .. "]" .. Locale.Lookup(resourceInfo.Name));

      if has_value(ResourcesToHide, resourceInfo.ResourceType) then
        resourcePickInstance.ResourceCheckbox:SetCheck(false);
      end

      resourcePickInstance.ResourceCheckbox:RegisterCallback(Mouse.eLClick, function() HandleResourceCheckbox(resourcePickInstance, resourceInfo.ResourceType); end);
    end
  end

  -- Cleanup
  Controls.BonusResourcePickStack:CalculateSize();
  Controls.LuxuryResourcePickStack:CalculateSize();
  Controls.StrategicResourcePickStack:CalculateSize();
  Controls.ResourcePickList:CalculateSize();
end

function ToggleResourceLens_Bonus()
  if not Controls.ShowBonusResource:IsChecked() then
    print_debug("Hide Bonus Resource")
    ndup_insert(ResourceCategoryToHide, "Bonus")
  else
    print_debug("Show Bonus Resource")
    find_and_remove(ResourceCategoryToHide, "Bonus");
  end

  -- Assuming resource lens is already applied
  UILens.ClearLayerHexes(LensLayers.HEX_COLORING_APPEAL_LEVEL);
  RefreshResourcePicker();
  SetResourceLens();
end

function ToggleResourceLens_Luxury()
  if not Controls.ShowLuxuryResource:IsChecked() then
    print_debug("Hide Luxury Resource")
    ndup_insert(ResourceCategoryToHide, "Luxury")
  else
    print_debug("Show Luxury Resource")
    find_and_remove(ResourceCategoryToHide, "Luxury");
  end

  -- Assuming resource lens is already applied
  UILens.ClearLayerHexes(LensLayers.HEX_COLORING_APPEAL_LEVEL);
  RefreshResourcePicker();
  SetResourceLens();
end

function ToggleResourceLens_Strategic()
  if not Controls.ShowStrategicResource:IsChecked() then
    print_debug("Hide Strategic Resource")
    ndup_insert(ResourceCategoryToHide, "Strategic")
  else
    print_debug("Show Strategic Resource")
    find_and_remove(ResourceCategoryToHide, "Strategic");
  end

  -- Assuming resource lens is already applied
  UILens.ClearLayerHexes(LensLayers.HEX_COLORING_APPEAL_LEVEL);
  RefreshResourcePicker();
  SetResourceLens();
end

function HandleResourceCheckbox(pControl, resourceType)
  if not pControl.ResourceCheckbox:IsChecked() then
    -- Don't show this resource
    if not has_value(ResourcesToHide, resourceType) then
      table.insert(ResourcesToHide, resourceType)
    end
  else
    -- Show this resource
    for i, rType in ipairs(ResourcesToHide) do
      if rType == resourceType then
        table.remove(ResourcesToHide, i)
        break
      end
    end
  end

  -- Assuming resource lens is already applied
  UILens.ClearLayerHexes(LensLayers.HEX_COLORING_APPEAL_LEVEL);
  SetResourceLens();
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

-- Called when a scout is selected
function ShowScoutLens()
  SetActiveModdedLens(MODDED_LENS_ID.SCOUT);
  UILens.ToggleLayerOn(LensLayers.HEX_COLORING_APPEAL_LEVEL);
end

-- ===========================================================================
function SetNaturalistLens()
  print_debug("Show Naturalist lens")
  local localPlayer:number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];

  local parkPlotColor:number = UI.GetColorValue("COLOR_PARK_NATURALIST_LENS");
  local OkColor:number = UI.GetColorValue("COLOR_OK_NATURALIST_LENS");
  local FixableColor:number = UI.GetColorValue("COLOR_FIXABLE_NATURALIST_LENS");

  local fixableHexes:table = {};
  local okHexes:table = {};
  local tiles:table = {};

  -- Get plots that can be made into National Parks without any changes
  local rawParkPlots:table = Game.GetNationalParks():GetPossibleParkTiles(localPlayer);

  -- Collect individual tile data
  local mapWidth, mapHeight = Map.GetGridSize();
  for plotIndex = 0, (mapWidth * mapHeight) - 1, 1 do
    local pPlot:table = Map.GetPlotByIndex(plotIndex);
    if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) then
      local data =  {
        X     = pPlot:GetX();
        Y     = pPlot:GetY();
        Level = 0;
        Cities = nil;
        Use   = false;
      };

      -- Level 3 = OK
      -- Level 2 = Fixable
      -- Level 1 = Semifixable

      -- Base requirements
      if plotHasNaturalWonder(pPlot) then
        data.Level = 3;

      elseif pPlot:IsMountain() then
        data.Level = 3;

      -- Appeal charming or better
      elseif pPlot:GetAppeal() >= 2 then
        data.Level = 3;

      -- Check for fixable plots by doing something to increase appeal
      elseif pPlot:GetAppeal() >= 1 then
        -- Removable unappealing feature
        local featureInfo = GameInfo.Features[pPlot:GetFeatureType()]
        if featureInfo ~= nil then
          local featureType = featureInfo.FeatureType
          if featureType == "FEATURE_JUNGLE" or featureType == "FEATURE_MARSH" then
            data.Level = 2;
          end
        end

        -- TODO - Check for plantable forest?
      end

      -- An improvement can be removed, downgrade to fixable
      if data.Level > 2 and plotHasImprovement(pPlot) then
        data.Level = 2;
      end

      -- If not owned by any player
      if pPlot:GetOwner() ~= Game.GetLocalPlayer() then
        if data.Level > 2 then
          data.Level = 2;
        end
      end

      -- Blocking changes
      if plotHasWonder(pPlot) then
        data.Level = 0;
      elseif plotHasDistrict(pPlot) then -- also checks for cities (city district)
        data.Level = 0;
      elseif pPlot:IsNationalPark() then
        data.Level = 0;
      end

      -- Only keep relevant tiles and those that have cities in range
      if data.Level > 0 then
        data.Cities = GetCitiesWithinWorkingRange(localPlayer, plotIndex)
        if table.count(data.Cities) > 0 then
          -- print(plotIndex, unpack(data.Cities))
          tiles[plotIndex] = data;
        end
      end
    end
  end

  -- Mark those that are interesting
  -- They must belong to a diamond where all four are at least semifixable.
  for i1, data in pairs(tiles) do
    -- Get the four plots for the vertical diamond
    local p1:table = Map.GetPlot(data.X, data.Y)
    local p2:table = Map.GetPlot(data.X + data.Y % 2 - 1, data.Y + 1);
    local p3:table = Map.GetPlot(data.X + data.Y % 2, data.Y + 1);
    local p4:table = Map.GetPlot(data.X, data.Y + 2);

    -- All four must exist
    if p1 ~= nil and p2 ~= nil and p3 ~= nil and p4 ~= nil then
      local i2 = p2:GetIndex();
      local i3 = p3:GetIndex();
      local i4 = p4:GetIndex();
      -- All three calculated diamond plots should have data
      if tiles[i2] ~= nil and tiles[i3] ~= nil and tiles[i4] ~= nil then

        -- Make sure the four plots have some common city in range
        local commonCities12 = get_common_values(tiles[i1].Cities, tiles[i2].Cities)
        local commonCities34 = get_common_values(tiles[i3].Cities, tiles[i4].Cities)
        local netCommonCities = get_common_values(commonCities12, commonCities34)

        if table.count(netCommonCities) > 0 then
          -- Use these plots only if they passable
          if not tiles[i1].Use and not p1:IsImpassable() then
            tiles[i1].Use = true;
          end
          if not tiles[i2].Use and not p2:IsImpassable() then
            tiles[i2].Use = true;
          end
          if not tiles[i3].Use and not p3:IsImpassable() then
            tiles[i3].Use = true;
          end
          if not tiles[i4].Use and not p4:IsImpassable() then
            tiles[i4].Use = true;
          end
        end
      end
    end
  end

  -- Extract info. Don't use plots that exist in rawParkPlots
  for i, data in pairs(tiles) do
    if tiles[i].Use and not has_value(rawParkPlots, i) then
      if tiles[i].Level == 3 then
        -- print("ok", i)
        table.insert(okHexes, i)
      elseif tiles[i].Level == 2 then
        -- print("fix", i)
        table.insert(fixableHexes, i)
      end
    end
  end

  if table.count(fixableHexes) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, fixableHexes, FixableColor );
  end
  if table.count(okHexes) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, okHexes, OkColor );
  end
  if table.count(rawParkPlots) > 0 then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, rawParkPlots, parkPlotColor );
  end
end

-- Returns a table of cities that are within working range of the plot
function  GetCitiesWithinWorkingRange(playerID:number, plotIndex:number)
  local localPlayerCities = Players[playerID]:GetCities()
  local pPlot = Map.GetPlotByIndex(plotIndex)
  local plotX = pPlot:GetX()
  local plotY = pPlot:GetY()

  local tCities = {}
  for _, pCity in localPlayerCities:Members() do
    if Map.GetPlotDistance(plotX, plotY, pCity:GetX(), pCity:GetY()) <= CITY_WORK_RANGE then
      table.insert(tCities, pCity:GetID())
    end
  end
  return tCities
end

-- ===========================================================================
function ShowCitizenManagementArea(cityID)
  print_debug("Showing city manage area for " .. cityID)
  SetActiveAreaLens(AREA_LENS_ID.CITIZEN_MANAGEMENT)
  UILens.ToggleLayerOn(LensLayers.HEX_COLORING_GOVERNMENT)

  local pCity:table;
  local localPlayer = Game.GetLocalPlayer()

  if (cityID ~= nil) then
    pCity = Players[localPlayer]:GetCities():FindID(cityID);
  else
    local pPlot = Map.GetPlotByIndex(m_CurrentCursorPlotID)
    if pPlot:IsCity() and pPlot:GetOwner() == Game.GetLocalPlayer() then
      pCity = CityManager.GetCityAt(pPlot:GetX(), pPlot:GetY());
    end
  end

  if pCity ~= nil then
    print_debug("Show citizens for " .. Locale.Lookup(pCity:GetName()))
    m_tAreaPlotsColored = {}

    local tParameters:table = {};
    local cityPlotID = Map.GetPlot(pCity:GetX(), pCity:GetY()):GetIndex()
    tParameters[CityCommandTypes.PARAM_MANAGE_CITIZEN] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_MANAGE_CITIZEN);

    local tWorkingPlots:table = {}  -- Plots worked by unlocked citizens
    local tLockedPlots:table = {}   -- Plots worked by locked citizes

    -- Get city plot and citizens info
    local tResults:table = CityManager.GetCommandTargets(pCity, CityCommandTypes.MANAGE, tParameters);
    if tResults == nil then
      print("ERROR : Could not find plots")
      return
    end

    local tPlots:table = tResults[CityCommandResults.PLOTS];
    local tUnits:table = tResults[CityCommandResults.CITIZENS];
    local tLockedUnits:table = tResults[CityCommandResults.LOCKED_CITIZENS];

    if tPlots ~= nil then
      for i, plotID in ipairs(tPlots) do
        table.insert(m_tAreaPlotsColored, plotID);
        if (tLockedUnits[i] > 0 or cityPlotID == plotID) then
          table.insert(tLockedPlots, plotID);
        elseif (tUnits[i] > 0) then
          table.insert(tWorkingPlots, plotID);
        end
      end
    end

    local workingColor:number = UI.GetColorValue("COLOR_CITY_PLOT_WORKING");
    local lockedColor:number = UI.GetColorValue("COLOR_CITY_PLOT_LOCKED");

    if #tWorkingPlots > 0 then
      UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_GOVERNMENT, localPlayer, tWorkingPlots, workingColor );
    end

    if #tLockedPlots > 0 then
      UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_GOVERNMENT, localPlayer, tLockedPlots, lockedColor );
    end

    m_CitizenManagementOn = true;
  end
end

function RefreshCitizenManagementArea(cityID)
  ClearAreaLens();
  ShowCitizenManagementArea(cityID);
end

-- ===========================================================================
function SetCustomLens()
  local localPlayer = Game.GetLocalPlayer()
  for i, plot_color in ipairs(m_CustomLens_PlotsAndColors) do
    -- print(i .. " layer")
    local color:number = plot_color.Color;
    local plots:table = plot_color.Plots;

    if table.count(plots) > 0 then
      -- print("Apply Lens")
      -- dump(plots)
      UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_APPEAL_LEVEL, localPlayer, plots, color );
    end
  end
end

function ApplyCustomLens(plot_color_table)
  SetActiveModdedLens(MODDED_LENS_ID.CUSTOM);

  -- Check if the appeal lens is already active
  if UILens.IsLayerOn(LensLayers.HEX_COLORING_APPEAL_LEVEL) then
    -- Unapply the appeal lens, so it can be cleared from the screen
    UILens.ToggleLayerOff(LensLayers.HEX_COLORING_APPEAL_LEVEL);
  end

  UILens.ToggleLayerOn(LensLayers.HEX_COLORING_APPEAL_LEVEL);

  m_CustomLens_PlotsAndColors = plot_color_table
end

function ClearCustomLens()
  ClearModdedLens();

  if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
    UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
  end
end

-- ===========================================================================
function OnApplyModdedLens(moddedLensID, showModalPanel:boolean)
  if showModalPanel then
    SetActiveModdedLens(moddedLensID);

    -- Check if the appeal lens is already active
    if UILens.IsLayerOn(LensLayers.HEX_COLORING_APPEAL_LEVEL) then
      -- Unapply the appeal lens, so it can be cleared from the screen
      UILens.SetActive("Default");
    end

    UILens.SetActive("Appeal");

    RefreshInterfaceMode();
  else
    SetActiveModdedLens(moddedLensID);
    UI.ToggleLayerOn(LensLayers.HEX_COLORING_APPEAL_LEVEL)
  end
end

function OnClearModdedLens(showedModalPanel:boolean)
  ClearModdedLens()

  if showedModalPanel and UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
    UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
  end
end

-- Modded lens helper functions ===========================================================
function ClearModdedLens()
  UILens.ClearLayerHexes( LensLayers.MAP_HEX_MASK );
  if UILens.IsLayerOn( LensLayers.HEX_COLORING_APPEAL_LEVEL ) then
    UILens.ToggleLayerOff( LensLayers.HEX_COLORING_APPEAL_LEVEL );
  end
  SetActiveModdedLens(MODDED_LENS_ID.NONE);
end

function ClearAreaLens()
  print_debug("Clearing area lens")

  -- Because of engine limitations, clear previous color of tiles
  local neutralColor:number = UI.GetColorValue("COLOR_AREA_LENS_NEUTRAL");
  local localPlayer:number = Game.GetLocalPlayer();

  if m_FullClearAreaLens then
    local players = Game.GetPlayers();
    for _, player in ipairs(players) do
      local cities = player:GetCities();
      for _, pCity in cities:Members() do
        local visibleCityPlots:table = Map.GetCityPlots():GetVisiblePurchasedPlots(pCity);
        if #visibleCityPlots > 0 then
          UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_GOVERNMENT, localPlayer, visibleCityPlots, neutralColor );
        end
      end
    end
  elseif (table.count(m_tAreaPlotsColored) > 0) then
    UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_GOVERNMENT, localPlayer, m_tAreaPlotsColored, neutralColor );
    m_tAreaPlotsColored = {}
  end

  -- UILens.ClearLayerHexes( LensLayers.MAP_HEX_MASK );
  if UILens.IsLayerOn( LensLayers.HEX_COLORING_GOVERNMENT ) then
    UILens.ToggleLayerOff( LensLayers.HEX_COLORING_GOVERNMENT );
  end

  SetActiveAreaLens(MODDED_LENS_ID.NONE);

  m_FullClearAreaLens = false;
end

function SetActiveModdedLens(lensID)
  m_CurrentModdedLensOn = lensID;
  LuaEvents.MinimapPanel_ModdedLensOn(lensID);
end

function SetActiveAreaLens(lensID)
  m_CurrentAreaLensOn = lensID;
  LuaEvents.MinimapPanel_AreaLensOn(lensID);
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

    -- Handler for City Overlap lens
    if (m_CurrentModdedLensOn == MODDED_LENS_ID.CITY_OVERLAP) then
      if (Controls.OverlapLensMouseRange:IsChecked()) then
        Refresh_AltCityOverlapLens();
      end
    end

    -- Handler for alternate settler lens
    if m_CtrlDown then
      if selectedUnit ~= nil then
        local unitType = GetUnitType(selectedUnit:GetOwner(), selectedUnit:GetID());
        if unitType == "UNIT_SETTLER" then
          RefreshSettlerLens();
        else
          print_debug(unitType)
        end

      -- Clear Settler lens, if not in modal screen
      elseif UI.GetInterfaceMode() ~= InterfaceModeTypes.VIEW_MODAL_LENS then

        ClearSettlerLens();
      end
    end
  end
end

-- ===========================================================================
--  Utility/Helper Functions
-- ===========================================================================

function plotWithinWorkingRange(playerID, plotIndex)
  local localPlayerCities = Players[playerID]:GetCities()
  local pPlot = Map.GetPlotByIndex(plotIndex)
  local plotX = pPlot:GetX()
  local plotY = pPlot:GetY()

  for _, pCity in localPlayerCities:Members() do
    if Map.GetPlotDistance(plotX, plotY, pCity:GetX(), pCity:GetY()) <= CITY_WORK_RANGE then
      return true
    end
  end
  return false
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

function plotHasImprovableHill(plot)
  local terrainInfo = GameInfo.Terrains[plot:GetTerrainType()];
  local improvInfo = GameInfo.Improvements["IMPROVEMENT_MINE"];
  local playerID = Game.GetLocalPlayer()

  if (terrainInfo ~= nil and terrainInfo.Hills
      and playerCanHave(playerID, improvInfo)) then
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
  local playerID = Game.GetLocalPlayer()
  local featureInfo = GameInfo.Features[plot:GetFeatureType()]
  local farmImprovInfo = GameInfo.Improvements["IMPROVEMENT_FARM"]
  local lumberImprovInfo = GameInfo.Improvements["IMPROVEMENT_LUMBER_MILL"]

  if featureInfo ~= nil then

    -- 1. Is it a floodplain?
    if featureInfo.FeatureType == "FEATURE_FLOODPLAINS" and
        playerCanHave(playerID, farmImprovInfo) then
      return true
    end

    -- 2. Is it a forest next to a river?
    if featureInfo.FeatureType == "FEATURE_FOREST" and plot:IsRiver() and
        playerCanHave(playerID, lumberImprovInfo) then
      return true
    end

    -- 3. Is it a tile next to buffing wonder?
    if plotNextToBuffingWonder(plot) then
      return true
    end

    -- 4. Is it wonder, that can have an improvement?
    if plotHasImprovableWonder(plot) then
      if featureInfo.FeatureType == "FEATURE_FOREST" and
          playerCanHave(playerID, lumberImprovInfo) then
        return true
      end

      if plotCanHaveFarm(plot) then
        return true
      end
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

-- TODO: Check for valid feature
function plotCanHaveFarm(plot)
  local farmImprovInfo = GameInfo.Improvements["IMPROVEMENT_FARM"]
  if not playerCanHave(playerID, farmImprovInfo) then
    return false;
  end

  local validTerrain:boolean = false;
  local playerID = Game.GetLocalPlayer()

  for improvTerrainInfo in GameInfo.Improvement_ValidTerrains() do
    if (improvTerrainInfo.ImprovementType == "IMPROVEMENT_FARM"
        and playerCanHave(playerID, improvTerrainInfo)) then
      return true;
    end
  end
  return false
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
                print_debug("(feature) Plot " .. pPlot:GetIndex() .. " can have " .. improvementInfo.ImprovementType)
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
                  print_debug("(terrain) Plot " .. pPlot:GetIndex() .. " can have " .. improvementInfo.ImprovementType)
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
                  print_debug("(resource) Plot " .. pPlot:GetIndex() .. " can have " .. improvementInfo.ImprovementType)
                  improvementValid = true;
                  break;
                end
              end
            end
          end
        end

        -- Special check for coastal requirement
        if improvementInfo.Coast and (not pPlot:IsCoastalLand()) then
          print_debug(plotIndex .. " plot is not coastal")
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
      if traitInfo.TraitType == xmlEntry.TraitType and
          traitInfo.CivilizationType ~= nil and
          civilizationType ~= traitInfo.CivilizationType then
        -- print(civilizationType .. " ~= " .. traitInfo.CivilizationType)
        return false
      end
    end

    for traitInfo in GameInfo.LeaderTraits() do
      if traitInfo.TraitType == xmlEntry.TraitType and
          traitInfo.LeaderType ~= nil and
          leaderType ~= traitInfo.LeaderType then
        -- print(civilizationType .. " ~= " .. traitInfo.LeaderType)
        return false
      end
    end

  end

  return true;
end

function playerHasBuilderWonderModifier(playerID)
  return playerHasModifier(playerID, "MODIFIER_PLAYER_ADJUST_UNIT_WONDER_PERCENT");
end

function playerHasBuilderDistrictModifier(playerID)
  return playerHasModifier(playerID, "MODIFIER_PLAYER_ADJUST_UNIT_DISTRICT_PERCENT");
end

function playerHasModifier(playerID, modifierType)
  -- Get civ, and leader
  local civTypeName = PlayerConfigurations[playerID]:GetCivilizationTypeName();
  local leaderTypeName = PlayerConfigurations[playerID]:GetLeaderTypeName();

  local civUA = GetCivilizationUniqueTraits(civTypeName);
  local leaderUA = GetLeaderUniqueTraits(leaderTypeName);

  for _, item in ipairs(civUA) do
    local traitType = civUA[1].TraitType
    -- print("Trait type: " .. traitType)

    -- Find the modifier ID
    local modifierID;
    for row in GameInfo.TraitModifiers() do
      if row.TraitType == traitType then
        local modifierID = row.ModifierId;

        -- Find the matching modifier type
        if modifierID ~= nil then
          -- print("Modifier ID: " .. modifierID)
          for row in GameInfo.Modifiers() do
            if row.ModifierId == modifierID and row.ModifierType == modifierType then
              -- print("Player has a modifier for district")
              return true;
            end
          end
        end
      end
    end
  end

  for _, item in ipairs(leaderUA) do
    local traitType = leaderUA[1].TraitType
    -- print("Trait type: " .. traitType)

    -- Find the modifier ID
    local modifierID;
    for row in GameInfo.TraitModifiers() do
      if row.TraitType == traitType then
        local modifierID = row.ModifierId;

        -- Find the matching modifier type
        if modifierID ~= nil then
          -- print("Modifier ID: " .. modifierID)
          for row in GameInfo.Modifiers() do
            if row.ModifierId == modifierID and row.ModifierType == modifierType then
              -- print("Player has a modifier for district")
              return true;
            end
          end
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

function has_value (tab, val)
  for _, value in ipairs (tab) do
    if value == val then
      return true
    end
  end
  return false
end

function has_rInfo (tab, val)
  for _, value in ipairs (tab) do
    if value.ResourceType == val then
      return true
    end
  end
  return false
end

function find_and_remove(tab, val)
  for i, item in ipairs(tab) do
    if item == val then
      table.remove(tab, i);
      return
    end
  end
end

function ndup_insert(tab, val)
  if not has_value(tab, val) then
    table.insert(tab, val);
  end
end

function get_common_values(tab1, tab2)
  local common_table = {}
  for _, value1 in ipairs (tab1) do
    for _, value2 in ipairs (tab2) do
      if value1 == value2 then
        table.insert(common_table, value1)
      end
    end
  end
  return common_table
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
  -- dont show panel if there is no local player
  if (Game.GetLocalPlayer() == -1) then
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

  if SHOW_CITIZEN_MANAGEMENT_INSCREEN then
    if eOldMode == InterfaceModeTypes.CITY_MANAGEMENT then
      ClearAreaLens()
      m_CitizenManagementOn = false
    end

    if eNewMode == InterfaceModeTypes.CITY_MANAGEMENT then
      local selectedCity = UI.GetHeadSelectedCity();
      if (selectedCity ~= nil) then
        RefreshCitizenManagementArea(selectedCity:GetID())
      end
    end
  end

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
      Controls.CityOverlapLensButton:SetCheck(false);
      Controls.ArchaeologistLensButton:SetCheck(false);
      Controls.BuilderLensButton:SetCheck(false);
      Controls.NaturalistLensButton:SetCheck(false);

      -- Side Menus
      Controls.ResourceLensOptionsPanel:SetHide(true);
      Controls.OverlapLensOptionsPanel:SetHide(true);

      if m_CurrentModdedLensOn ~= MODDED_LENS_ID.NONE then
        ClearModdedLens()
      end

      if m_CurrentAreaLensOn ~= AREA_LENS_ID.NONE then
        ClearAreaLens()
      end
    end
  end
end

function OnCitySelectionChanged(owner, ID, i, j, k, bSelected, bEditable)
  if owner ~= Game.GetLocalPlayer() then
    return
  end

  if SHOW_CITIZEN_MANAGEMENT_INSCREEN then
    if bSelected and m_CurrentAreaLensOn == AREA_LENS_ID.CITIZEN_MANAGEMENT then
      RefreshCitizenManagementArea(ID)
    end
  end
end

function OnCityWorkerChanged(ownerPlayerID:number, cityID:number)
  if SHOW_CITIZEN_MANAGEMENT_INSCREEN and ownerPlayerID == Game.GetLocalPlayer() and
      m_CurrentAreaLensOn == AREA_LENS_ID.CITIZEN_MANAGEMENT then
    RefreshCitizenManagementArea(cityID)
  end
end

function OnCityMadePurchase(owner:number, cityID:number, plotX:number, plotY:number, purchaseType, objectType)
  if SHOW_CITIZEN_MANAGEMENT_INSCREEN and owner == Game.GetLocalPlayer() and
      m_CurrentAreaLensOn == AREA_LENS_ID.CITIZEN_MANAGEMENT and
      purchaseType == EventSubTypes.PLOT then

    -- Add plot so that the plot is properly cleared
    table.insert(m_tAreaPlotsColored, Map.GetPlotIndex(plotX, plotY))
    RefreshCitizenManagementArea(cityID)
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
        elseif (unitType == "UNIT_SETTLER") then
          ClearSettlerLens();
        end
      end
    end

    -- If unit is selected and citizen management area was on, turn on selection interface mode.
    -- Lens will cleared in the OnInterfaceModeChanged event
    if SHOW_CITIZEN_MANAGEMENT_INSCREEN and m_CurrentAreaLensOn == AREA_LENS_ID.CITIZEN_MANAGEMENT then
      -- AZURENCY : fix weird behavior when a unit was selected and the citybanner mouse hover state
      --UI.SetInterfaceMode(InterfaceModeTypes.SELECTION)
      ClearAreaLens()
      m_CitizenManagementOn = false
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
    if m_CurrentModdedLensOn == MODDED_LENS_ID.BUILDER then
      ClearBuilderLensHexes();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.ARCHAEOLOGIST then
      ClearArchaeologistLens();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.SCOUT then
      ClearScoutLens();
    end
  end
end

-- To update the scout lens, when a scout/ranger moves
function OnUnitMoved( playerID:number, unitID:number )
  if playerID == Game.GetLocalPlayer() then
    local unitType = GetUnitType(playerID, unitID);
    if (unitType == "UNIT_SCOUT" or unitType == "UNIT_RANGER") and AUTO_APPLY_SCOUT_LENS then
      -- Refresh the scout lens, if already applied. Need this check so scout lens
      -- does not apply when a scout is currently under a operation
      if m_CurrentModdedLensOn == MODDED_LENS_ID.SCOUT then
        ClearScoutLens();
        ShowScoutLens();
      end
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
    elseif msg == KeyEvents.KeyUp then
      m_CtrlDown = false

      RecheckSettlerLens()
    end
  end

  HandleMouseForModdedLens(pInputStruct:GetX(), pInputStruct:GetY())

  -- Skip all other handling when dragging is disabled or the minimap is collapsed
  if m_isMouseDragEnabled and not m_isCollapsed then

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

    -- Consume mouse right click if mouse is on minimap.
    elseif msg == MouseEvents.RButtonDown or msg == MouseEvents.RButtonUp then
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

  -- Check for function nil for backward compatibiliy. @Summer Patch 2017
  if Controls.MinimapImage.RegisterSizeChanged ~= nil then
    Controls.MinimapImage:RegisterSizeChanged( OnMinimapImageSizeChanged );
  end
  UI.SetMinimapImageControl(Controls.MinimapImage);
  Controls.LensChooserList:CalculateSize();

  ContextPtr:SetInputHandler( OnInputHandler, true );
  ContextPtr:SetShutdown( OnShutdown );

  Controls.LensPanel:ChangeParent(Controls.LensButton);
  Controls.MapOptionsPanel:ChangeParent(Controls.MapOptionsButton);
  Controls.ToggleResourcesButton:SetCheck( UserConfiguration.ShowMapResources() );
  Controls.ToggleYieldsButton:SetCheck( UserConfiguration.ShowMapYield() );

  -- Modded lens
  Controls.BuilderLensButton:RegisterCallback( Mouse.eLClick, ToggleBuilderLens );
  Controls.ArchaeologistLensButton:RegisterCallback( Mouse.eLClick, ToggleArchaeologistLens );
  Controls.CityOverlapLensButton:RegisterCallback( Mouse.eLClick, ToggleCityOverlapLens );
  Controls.BarbarianLensButton:RegisterCallback( Mouse.eLClick, ToggleBarbarianLens );
  Controls.ResourceLensButton:RegisterCallback( Mouse.eLClick, ToggleResourceLens );
  Controls.WonderLensButton:RegisterCallback( Mouse.eLClick, ToggleWonderLens );
  Controls.AdjacencyYieldLensButton:RegisterCallback( Mouse.eLClick, ToggleAdjacencyYieldLens );
  Controls.ScoutLensButton:RegisterCallback( Mouse.eLClick, ToggleScoutLens );
  Controls.NaturalistLensButton:RegisterCallback( Mouse.eLClick, ToggleNaturalistLens );

  -- Resource Lens Picker
  Controls.ShowBonusResource:RegisterCallback( Mouse.eLClick, ToggleResourceLens_Bonus );
  Controls.ShowLuxuryResource:RegisterCallback( Mouse.eLClick, ToggleResourceLens_Luxury );
  Controls.ShowStrategicResource:RegisterCallback( Mouse.eLClick, ToggleResourceLens_Strategic );

  -- City Overlap Lens Setting
  Controls.ShowLensOutsideBorder:RegisterCallback( Mouse.eLClick, RefreshCityOverlapLens );
  Controls.OverlapRangeUp:RegisterCallback( Mouse.eLClick, IncreseOverlapRange );
  Controls.OverlapRangeDown:RegisterCallback( Mouse.eLClick, DecreaseOverlapRange );
  Controls.OverlapLensMouseNone:RegisterCallback( Mouse.eLClick, RefreshCityOverlapLens );

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

  LuaEvents.NotificationPanel_ShowContinentLens.Add(OnToggleContinentLensExternal);
  LuaEvents.Tutorial_DisableMapDrag.Add( OnTutorial_DisableMapDrag );
  LuaEvents.Tutorial_SwitchToWorldView.Add( OnTutorial_SwitchToWorldView );
  LuaEvents.MinimapPanel_ToggleGrid.Add( ToggleGrid );
  LuaEvents.MinimapPanel_RefreshMinimapOptions.Add( RefreshMinimapOptions );

  -- For modded lenses
  Events.CitySelectionChanged.Add( OnCitySelectionChanged );
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
  LuaEvents.CQUI_SettingsInitialized.Add( CQUI_ToggleYieldIcons );
  Events.LoadScreenClose.Add( CQUI_OnSettingsUpdate ); -- Astog: Update settings when load screen close
  -- CQUI_OnSettingsUpdate()

  -- For Area Lens
  Events.CityWorkerChanged.Add( OnCityWorkerChanged );
  Events.CityMadePurchase.Add( OnCityMadePurchase );

  -- External Lens Controls
  LuaEvents.Lens_ApplyCustomLens.Add( ApplyCustomLens );
  LuaEvents.Lens_ClearCustomLens.Add( ClearCustomLens );
  LuaEvents.Lens_ApplyModdedLens.Add( OnApplyModdedLens );
  LuaEvents.Lens_ClearModdedLens.Add( OnClearModdedLens );
  LuaEvents.Area_ShowCitizenManagement.Add( ShowCitizenManagementArea );
  LuaEvents.Area_RefreshCitizenManagement.Add( RefreshCitizenManagementArea );
  LuaEvents.Area_ClearCitizenManagement.Add( ClearAreaLens );
end
Initialize();
