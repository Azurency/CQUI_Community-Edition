-- Copyright 2016-2018, Firaxis Games
include( "InstanceManager" );

-- ===========================================================================
--  MODDED LENS (by Astog)
-- ===========================================================================
g_ModLenses = {} -- Populated by ModLens_*.lua scripts
include( "ModLens_", true )

local m_LensButtonIM:table = InstanceManager:new("LensButtonInstance", "LensButton", Controls.LensToggleStack)
local m_CurrentModdedLensOn:string = nil

-- Settler Lens Variables
local m_AltSettlerLensOn:boolean = false;

-- Non-standard lenses
local m_AttackRange : number = UILens.CreateLensLayerHash("Attack_Range");
local m_MovementZoneOfControl : number = UILens.CreateLensLayerHash("Movement_Zone_Of_Control");
local m_HexColoringGreatPeople : number = UILens.CreateLensLayerHash("Hex_Coloring_Great_People");
local m_MapHexMask : number = UILens.CreateLensLayerHash("Map_Hex_Mask");

-- ===========================================================================
--  CONSTANTS
-- ===========================================================================
local MINIMAP_COLLAPSED_OFFSETY     :number = -180;
local LENS_PANEL_OFFSET             :number = 50;
local MINIMAP_BACKING_PADDING_SIZEY :number = 54;
local MAP_OPTIONS_PADDING           :number = 80;

-- ===========================================================================
--  GLOBALS
-- ===========================================================================
g_shouldCloseLensMenu = true;    -- Controls when the Lens menu should be closed.
g_ContinentsCache = {};

g_HexColoringContinent = UILens.CreateLensLayerHash("Hex_Coloring_Continent");

-- ===========================================================================
--  MEMBERS
-- ===========================================================================
--local m_OptionsButtonManager= InstanceManager:new( "MiniMapOptionButtonInstance", "Top",      Controls.OptionsStack );
local m_LensButtonIM            :table = InstanceManager:new("LensButtonInstance", "LensButton", Controls.LensToggleStack);
local m_MapOptionIM             :table = InstanceManager:new("MapOptionInstance", "ToggleButton", Controls.MapOptionsStack);

local m_OptionButtons           :table = {};    -- option buttons indexed by buttonName.
local iZoomIncrement            :number = 2;
local m_isCollapsed             :boolean= false;
local m_ContinentsCreated       :boolean=false;
local m_MiniMap_xmloffsety      :number = 0;
local m_kFlyoutControlIds       :table = { "MapOptions", "Lens", "MapPinList", "MapSearch" };   -- Name of controls that are the backing for "flyout" menus.

local m_ToggleReligionLensId    = Input.GetActionId("LensReligion");
local m_ToggleContinentLensId   = Input.GetActionId("LensContinent");
local m_ToggleAppealLensId      = Input.GetActionId("LensAppeal");
local m_ToggleSettlerLensId     = Input.GetActionId("LensSettler");
local m_ToggleGovernmentLensId  = Input.GetActionId("LensGovernment");
local m_TogglePoliticalLensId   = Input.GetActionId("LensPolitical");
local m_ToggleTourismLensId     = Input.GetActionId("LensTourism");
local m_ToggleEmpireLensId      = Input.GetActionId("LensEmpire");
local m_Toggle2DViewId          = Input.GetActionId("Toggle2DView");

local m_OpenMapSearchId         = Input.GetActionId("OpenMapSearch");

local m_isMouseDragEnabled      :boolean = true; -- Can the camera be moved by dragging on the minimap?
local m_isMouseDragging         :boolean = false; -- Was LMB clicked inside the minimap, and has not been released yet?
local m_hasMouseDragged         :boolean = false; -- Has there been any movements since m_isMouseDragging became true?
local m_wasMouseInMinimap       :boolean = false; -- Was the mouse over the minimap the last time we checked?

local m_HexColoringReligion : number = UILens.CreateLensLayerHash("Hex_Coloring_Religion");
local m_HexColoringAppeal : number = UILens.CreateLensLayerHash("Hex_Coloring_Appeal_Level");
local m_HexColoringGovernment : number = UILens.CreateLensLayerHash("Hex_Coloring_Government");
local m_HexColoringOwningCiv : number = UILens.CreateLensLayerHash("Hex_Coloring_Owning_Civ");
local m_HexColoringWaterAvail : number = UILens.CreateLensLayerHash("Hex_Coloring_Water_Availablity");
local m_TouristTokens : number = UILens.CreateLensLayerHash("Tourist_Tokens");

-- ===========================================================================
--  FUNCTIONS
-- ===========================================================================

function CQUI_ToggleYieldIcons()
  UserConfiguration.ShowMapYield(GameConfiguration.GetValue("CQUI_ToggleYieldsOnLoad"));
  RestoreYieldIcons();
end

-- ===========================================================================
function GetContinentsCache()
  if g_ContinentsCache == nil then
    g_ContinentsCache = Map.GetContinentsInUse();
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
function CreateLensToggleButton(szText, szToolTip, pCallback, bChecked)
  local szLocalizedText = Locale.Lookup(szText);
  local szLocalizedToolTip = Locale.Lookup(szToolTip);

  local pInstance = m_LensButtonIM:GetInstance();
  pInstance.LensButton:GetTextButton():SetText(szLocalizedText);
  pInstance.LensButton:SetToolTipString(szLocalizedToolTip);
  pInstance.LensButton:RegisterCallback(Mouse.eLClick, pCallback);
  pInstance.LensButton:SetCheck(bChecked);
  return pInstance;
end

-- ===========================================================================
function CreateMapOptionButton(szText, szToolTip, pCallback, bChecked)
  local szLocalizedText = Locale.Lookup(szText);
  local szLocalizedToolTip = Locale.Lookup(szToolTip);

  local pInstance = m_MapOptionIM:GetInstance();
  pInstance.ToggleButton:GetTextButton():SetText(szLocalizedText);
  pInstance.ToggleButton:SetToolTipString(szLocalizedToolTip);
  pInstance.ToggleButton:RegisterCallback(Mouse.eLClick, pCallback);
  pInstance.ToggleButton:SetCheck(bChecked);
  return pInstance;
end

-- ===========================================================================
function RefreshMinimapOptions()
  if GameCapabilities.HasCapability("CAPABILITY_DISPLAY_MINIMAP_YIELDS") then
    Controls.ToggleYieldsButton:SetCheck(UserConfiguration.ShowMapYield());
  else
    Controls.ToggleYieldsButton:SetHide(true);
  end

  if GameCapabilities.HasCapability("CAPABILITY_DISPLAY_MINIMAP_RESOURCES") then
    Controls.ToggleResourcesButton:SetCheck(UserConfiguration.ShowMapResources());
  else
    Controls.ToggleResourcesButton:SetHide(true);
  end
  Controls.ToggleGridButton:SetCheck(UserConfiguration.ShowMapGrid());
end

-- ===========================================================================
function ToggleMapOptionsList()
  if Controls.MapOptionsPanel:IsHidden() then
    RefreshMinimapOptions();
  end
  Controls.MapOptionsPanel:SetHide( not Controls.MapOptionsPanel:IsHidden() );
  Controls.MapOptionsPanel:SetSizeY(Controls.MapOptionsStack:GetSizeY() + MAP_OPTIONS_PADDING);
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
    Controls.ContinentLensButton:SetHide(not GameCapabilities.HasCapability("CAPABILITY_LENS_CONTINENT"));
    Controls.EmpireLensButton:SetHide(not GameCapabilities.HasCapability("CAPABILITY_LENS_EMPIRE"));
    Controls.LensToggleStack:CalculateSize();

    -- Astog: Disable increasing size of panel, since now we have a scrollbar
    -- Controls.LensPanel:SetSizeY(Controls.LensToggleStack:GetSizeY() + LENS_PANEL_OFFSET);
  end
end

-- ===========================================================
function CloseLensList()
  g_shouldCloseLensMenu = true;
  Controls.ReligionLensButton:SetCheck(false);
  Controls.ContinentLensButton:SetCheck(false);
  Controls.AppealLensButton:SetCheck(false);
  Controls.GovernmentLensButton:SetCheck(false);
  Controls.WaterLensButton:SetCheck(false);
  Controls.OwnerLensButton:SetCheck(false);
  Controls.TourismLensButton:SetCheck(false);
  Controls.EmpireLensButton:SetCheck(false);

  -- Begin Astog Mod --------------------------------------------------------------------------------------------------
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
  -- End Astog Mod ------------------------------------------------------------------------------------------------

  local uiCurrInterfaceMode:number = UI.GetInterfaceMode();
  if uiCurrInterfaceMode == InterfaceModeTypes.VIEW_MODAL_LENS then
    UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
  end
end

------------------------------------------------------------------------------
function ToggleMapPinMode()
  Controls.MapPinListPanel:SetHide( not Controls.MapPinListPanel:IsHidden() );
  RealizeFlyouts(Controls.MapPinListPanel);
  Controls.MapPinListButton:SetSelected( not Controls.MapPinListPanel:IsHidden() );
end

-- ===========================================================================
function ToggleMapSearchPanel()
  Controls.MapSearchPanel:SetHide( not Controls.MapSearchPanel:IsHidden() );
  RealizeFlyouts(Controls.MapSearchPanel);
  Controls.MapSearchButton:SetSelected( not Controls.MapSearchPanel:IsHidden() );
end

-- ===========================================================================
function OnMapSearchPanelVisibilityChanged()
  if (Controls.MapSearchPanel:IsHidden()) then
    LuaEvents.MapSearch_PanelClosed();
  else
    LuaEvents.MapSearch_PanelOpened();
  end
end

-- ===========================================================================
function ToggleResourceIcons()
  local bOldValue :boolean = UserConfiguration.ShowMapResources();
  UserConfiguration.ShowMapResources( not bOldValue );

  local bOther = UserConfiguration.ShowMapGrid();
end

-- ===========================================================================
function RestoreYieldIcons()
  if UserConfiguration.ShowMapYield() then
  -- M4A FIX: This should be PlotInfo ShowYieldIcons
    LuaEvents.PlotInfo_ShowYieldIcons();
  else
    LuaEvents.PlotInfo_HideYieldIcons();
  end
end

-- ===========================================================================
function ToggleYieldIcons()
  local showMapYield:boolean = not UserConfiguration.ShowMapYield();
  UserConfiguration.ShowMapYield( showMapYield );

  RestoreYieldIcons();
end

-- ===========================================================================
function ToggleReligionLens()
  if Controls.ReligionLensButton:IsChecked() then
    UILens.SetActive("Religion");
    RefreshInterfaceMode();
  else
    g_shouldCloseLensMenu = false; --When toggling the lens off, shouldn't close the menu.
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
    g_shouldCloseLensMenu = false;
    if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
  end
end

-- ===========================================================================
function ToggleAppealLens()
  if Controls.AppealLensButton:IsChecked() then

    -- Begin Astog Mod --------------------------------------------------------------------------------------------------
    SetActiveModdedLens("VANILLA_APPEAL");

    -- Check if the appeal lens is already active. Needed to clear any modded lens
    if UILens.IsLayerOn(m_HexColoringAppeal) then
      -- Unapply the appeal lens, so it can be cleared from the screen
      UILens.SetActive("Default");
    end
    -- End Astog Mod ------------------------------------------------------------------------------------------------

    UILens.SetActive("Appeal");
    RefreshInterfaceMode();
  else
    g_shouldCloseLensMenu = false;
    if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
  end
end

-- ===========================================================================
function ToggleWaterLens()
  if Controls.WaterLensButton:IsChecked() then
    UILens.SetActive("WaterAvailability");
    RefreshInterfaceMode();
  else
    g_shouldCloseLensMenu = false;
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
    g_shouldCloseLensMenu = false;
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
    g_shouldCloseLensMenu = false;
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
    g_shouldCloseLensMenu = false;
    if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
  end
end

-- ===========================================================================
function ToggleEmpireLens()
  if Controls.EmpireLensButton:IsChecked() then
    UILens.SetActive("EmpireDetails");
    RefreshInterfaceMode();
  else
    g_shouldCloseLensMenu = false;
    if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
  end
end

-- ===========================================================================
function ToggleGrid()
  local bOldState :boolean = UserConfiguration.ShowMapGrid();
  UserConfiguration.ShowMapGrid( not bOldState  );
  local bNewState :boolean = UserConfiguration.ShowMapGrid();
  UI.ToggleGrid( not bOldState );
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
function ShowFullscreenMap()
  UI.PlaySound("Play_UI_Click");
  UI.SetInterfaceMode(InterfaceModeTypes.FULLSCREEN_MAP);
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
end

-- ===========================================================================
function OnMinimapImageSizeChanged()
  ResizeBacking();
  LuaEvents.ML_ReoffsetPanels()
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

  -- Begin Astog Mod --------------------------------------------------------------------------------------------------
  -- clear unit non-standard layers
  -- do this if no unit is selected, since these lenses are applied on unit selection, so control should be in SelectedUnit.lua
  if UI.GetHeadSelectedUnit() == nil then
    -- CQUI (Azurency) : Fix clearing of m_AttackRange lenses while in this STIKE mode
    if (UI.GetInterfaceMode() ~= InterfaceModeTypes.CITY_RANGE_ATTACK and UI.GetInterfaceMode() ~= InterfaceModeTypes.DISTRICT_RANGE_ATTACK) then
      UILens.ClearLayerHexes(m_AttackRange);
    end
    UILens.ClearLayerHexes(m_AttackRange);
    UILens.ClearLayerHexes(m_HexColoringGreatPeople);
    UILens.ClearLayerHexes(m_MovementZoneOfControl);
  end
  -- End Astog Mod ------------------------------------------------------------------------------------------------

  if layerNum == m_HexColoringReligion then
    UI.PlaySound("UI_Lens_Overlay_On");
    UILens.SetDesaturation(1.0);

  -- Begin Astog Mod --------------------------------------------------------------------------------------------------
  elseif layerNum == m_HexColoringAppeal then
    if m_CurrentModdedLensOn == "VANILLA_APPEAL" then
      SetAppealHexes();
    else
      SetModLens();
    end
    UI.PlaySound("UI_Lens_Overlay_On");
  -- End Astog Mod ------------------------------------------------------------------------------------------------

  elseif layerNum == m_HexColoringGovernment then
    SetGovernmentHexes();
    UI.PlaySound("UI_Lens_Overlay_On");
  elseif layerNum == m_HexColoringOwningCiv then
    SetOwningCivHexes();
    UI.PlaySound("UI_Lens_Overlay_On");
  elseif layerNum == g_HexColoringContinent then
    SetContinentHexes();
    UI.PlaySound("UI_Lens_Overlay_On");
  elseif layerNum == m_HexColoringWaterAvail then
    SetWaterHexes();
    UI.PlaySound("UI_Lens_Overlay_On");
  elseif layerNum == m_TouristTokens then
    UI.PlaySound("UI_Lens_Overlay_On");
  end
end

-- ===========================================================================
function OnLensLayerOff( layerNum:number )
  -- Begin Astog Modification  --------------------------------------------------------------------------------------------------
  -- clear unit non-standard layers
  -- do this if no unit is selected, since these lenses are applied on unit selection, so control should be in SelectedUnit.lua
  if UI.GetHeadSelectedUnit() == nil then
    -- CQUI (Azurency) : Fix clearing of m_AttackRange lenses while in this STIKE mode
    if (UI.GetInterfaceMode() ~= InterfaceModeTypes.CITY_RANGE_ATTACK and UI.GetInterfaceMode() ~= InterfaceModeTypes.DISTRICT_RANGE_ATTACK) then
      UILens.ClearLayerHexes(m_AttackRange);
    end
    UILens.ClearLayerHexes(m_AttackRange);
    UILens.ClearLayerHexes(m_HexColoringGreatPeople);
    UILens.ClearLayerHexes(m_MovementZoneOfControl);
  end

  -- print("OnLensLayerOff", layerNum)
  if (layerNum == m_HexColoringReligion       or
    layerNum == g_HexColoringContinent      or
    layerNum == m_HexColoringGovernment     or
    layerNum == m_HexColoringOwningCiv)     then
    UI.PlaySound("UI_Lens_Overlay_Off");

    -- Clear Modded Lens (Appeal lens included)
  elseif layerNum == m_HexColoringAppeal then
    UILens.ClearLayerHexes( m_MapHexMask );
    if UI.GetInterfaceMode() ~= InterfaceModeTypes.VIEW_MODAL_LENS or (UI.GetHeadSelectedUnit() == nil) then
      UILens.ClearLayerHexes(m_HexColoringAppeal);
    end
    UI.PlaySound("UI_Lens_Overlay_Off");
    -- End Astog Modification ------------------------------------------------------------------------------------------------

  elseif layerNum == m_HexColoringWaterAvail then
    -- Only clear the water lens if we're turning off lenses altogether, but not if switching to another modal lens (Turning on another modal lens clears it already).
    if UI.GetInterfaceMode() ~= InterfaceModeTypes.VIEW_MODAL_LENS or (UI.GetHeadSelectedUnit() == nil) then
      UILens.ClearLayerHexes(m_HexColoringWaterAvail);
    end
    UI.PlaySound("UI_Lens_Overlay_Off");
  end

  if (layerNum == m_HexColoringReligion) then
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
function OnUserOptionsActivated()
  RestoreYieldIcons();
end

-- ===========================================================================
function SetOwningCivHexes()
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
          UILens.SetLayerHexesColoredArea( m_HexColoringOwningCiv, localPlayer, plots, primaryColor );
        end
      end
    end
  end
end

-- ===========================================================================
function SetDefaultWaterHexes()
  local FullWaterPlots:table = {};
  local CoastalWaterPlots:table = {};
  local NoWaterPlots:table = {};
  local NoSettlePlots:table = {};

  UILens.ClearLayerHexes(m_HexColoringWaterAvail);
  FullWaterPlots, CoastalWaterPlots, NoWaterPlots, NoSettlePlots = Map.GetContinentPlotsWaterAvailability();

  local BreathtakingColor :number = UI.GetColorValue("COLOR_BREATHTAKING_APPEAL");
  local CharmingColor     :number = UI.GetColorValue("COLOR_CHARMING_APPEAL");
  local AverageColor      :number = UI.GetColorValue("COLOR_AVERAGE_APPEAL");
  local DisgustingColor   :number = UI.GetColorValue("COLOR_DISGUSTING_APPEAL");
  local localPlayer       :number = Game.GetLocalPlayer();

  if(table.count(FullWaterPlots) > 0) then
    UILens.SetLayerHexesColoredArea( m_HexColoringWaterAvail, localPlayer, FullWaterPlots, BreathtakingColor );
  end
  if(table.count(CoastalWaterPlots) > 0) then
    UILens.SetLayerHexesColoredArea( m_HexColoringWaterAvail, localPlayer, CoastalWaterPlots, CharmingColor );
  end
  if(table.count(NoWaterPlots) > 0) then
    UILens.SetLayerHexesColoredArea( m_HexColoringWaterAvail, localPlayer, NoWaterPlots, AverageColor );
  end
  if(table.count(NoSettlePlots) > 0) then
    UILens.SetLayerHexesColoredArea( m_HexColoringWaterAvail, localPlayer, NoSettlePlots, DisgustingColor );
  end
end

-- Begin Astog --------------------------------------------------------------------------------------------------
function SetWaterHexes()
  if (not m_CtrlDown) then
    --print("default")
    SetDefaultWaterHexes()
  else
    --print("alt")
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

  local pPlot:table = Map.GetPlotByIndex(plotId)
  local localPlayer:number = Game.GetLocalPlayer();
  local pPlayer:table = Players[localPlayer]
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
      if plotWithinWorkingRange(pPlayer, pRangePlot) then
        table.insert(tOverlapPlots, plotID)

      elseif pRangePlot:IsImpassable() then
        table.insert(tUnusablePlots, plotID)

      elseif pRangePlot:IsOwned() and pRangePlot:GetOwner() ~= localPlayer then
        table.insert(tUnusablePlots, plotID)

      elseif plotHasResource(pRangePlot) and
        playerHasDiscoveredResource(pPlayer, pRangePlot) then

        table.insert(tResourcePlots, plotID)
      else
        table.insert(tRegularPlots, plotID)
      end
    end
  end

  if #tOverlapPlots > 0 then
    UILens.SetLayerHexesColoredArea( m_HexColoringWaterAvail, localPlayer, tOverlapPlots, iOverlapColor );
  end

  if #tUnusablePlots > 0 then
    UILens.SetLayerHexesColoredArea( m_HexColoringWaterAvail, localPlayer, tUnusablePlots, iUnusableColor );
  end

  if #tResourcePlots > 0 then
    UILens.SetLayerHexesColoredArea( m_HexColoringWaterAvail, localPlayer, tResourcePlots, iResourceColor );
  end

  if #tRegularPlots  > 0 then
    UILens.SetLayerHexesColoredArea( m_HexColoringWaterAvail, localPlayer, tRegularPlots, iRegularColor );
  end
end

-- ===========================================================
function RefreshSettlerLens()
  UILens.ClearLayerHexes(m_HexColoringWaterAvail)
  SetWaterHexes()
end

-- Checks to see if settler lens should be reapplied
function RecheckSettlerLens()
  local selectedUnit = UI.GetHeadSelectedUnit()
  if (selectedUnit ~= nil) then
    local unitType = getUnitType(selectedUnit);
    if (unitType == "UNIT_SETTLER") then
      RefreshSettlerLens()
      return
    end
  end

  if UILens.IsLayerOn( m_HexColoringWaterAvail ) then
    UILens.ToggleLayerOff( m_HexColoringWaterAvail );
  end
end
-- End Astog Update ------------------------------------------------------------------------------------------------

-- ===========================================================================
function SetGovernmentHexes()
  local localPlayer : number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];
  if (localPlayerVis ~= nil) then
    local players = Game.GetPlayers();
    for i, player in ipairs(players) do
      local pCities           :table = players[i]:GetCities();
      local pCulture          :table = player:GetCulture();
      local governmentId      :number = pCulture:GetCurrentGovernment();
      local governmentColor   :number;

      if pCulture:IsInAnarchy() then
        governmentColor = UI.GetColorValue("COLOR_CLEAR");
      else
        if(governmentId < 0) then
          governmentColor = UI.GetColorValue("COLOR_GOVERNMENT_CITYSTATE");
        else
          local GovType:string = GameInfo.Governments[governmentId].GovernmentType;
          governmentColor = UI.GetColorValue("COLOR_"..GovType);
        end
      end

      for _, pCity in pCities:Members() do
        local plots:table = Map.GetCityPlots():GetPurchasedPlots(pCity);

        if(table.count(plots) > 0) then
          UILens.SetLayerHexesColoredArea( m_HexColoringGovernment, localPlayer, plots, governmentColor );
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
    UILens.SetLayerHexesColoredArea( m_HexColoringAppeal, localPlayer, BreathtakingPlots, BreathtakingColor );
  end
  if(table.count(CharmingPlots) > 0) then
    UILens.SetLayerHexesColoredArea( m_HexColoringAppeal, localPlayer, CharmingPlots, CharmingColor );
  end
  if(table.count(AveragePlots) > 0) then
    UILens.SetLayerHexesColoredArea( m_HexColoringAppeal, localPlayer, AveragePlots, AverageColor );
  end
  if(table.count(UninvitingPlots) > 0) then
    UILens.SetLayerHexesColoredArea( m_HexColoringAppeal, localPlayer, UninvitingPlots, UninvitingColor );
  end
  if(table.count(DisgustingPlots) > 0) then
    UILens.SetLayerHexesColoredArea( m_HexColoringAppeal, localPlayer, DisgustingPlots, DisgustingColor );
  end

end

-- ===========================================================================
function SetContinentHexes()
  local ContinentColor:number = UI.GetColorValueFromHexLiteral(0x02000000);
  GetContinentsCache();
  local localPlayerVis:table = PlayersVisibility[Game.GetLocalPlayer()];
  if (localPlayerVis ~= nil) then

    local kContinentColors:table = {};
    for loopNum, ContinentID in ipairs(g_ContinentsCache) do
      local visibleContinentPlots:table = Map.GetVisibleContinentPlots(ContinentID);
      ContinentColor = UI.GetColorValue("COLOR_" .. GameInfo.Continents[ loopNum-1 ].ContinentType);
      if(table.count(visibleContinentPlots) > 0) then
        UILens.SetLayerHexesColoredArea( g_HexColoringContinent, loopNum-1, visibleContinentPlots, ContinentColor );
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

  if m_ToggleReligionLensId ~= nil and (actionId == m_ToggleReligionLensId) and GameCapabilities.HasCapability("CAPABILITY_LENS_RELIGION") then
    LensPanelHotkeyControl( Controls.ReligionLensButton );
    ToggleReligionLens();
    UI.PlaySound("Play_UI_Click");
  end
  if m_ToggleContinentLensId ~= nil and (actionId == m_ToggleContinentLensId) and GameCapabilities.HasCapability("CAPABILITY_LENS_CONTINENT") then
    LensPanelHotkeyControl( Controls.ContinentLensButton );
    ToggleContinentLens();
    UI.PlaySound("Play_UI_Click");
  end
  if m_ToggleAppealLensId ~= nil and (actionId == m_ToggleAppealLensId) and GameCapabilities.HasCapability("CAPABILITY_LENS_APPEAL") then
    LensPanelHotkeyControl( Controls.AppealLensButton );
    ToggleAppealLens();
    UI.PlaySound("Play_UI_Click");
  end
  if m_ToggleSettlerLensId ~= nil and (actionId == m_ToggleSettlerLensId) and GameCapabilities.HasCapability("CAPABILITY_LENS_SETTLER") then
    LensPanelHotkeyControl( Controls.WaterLensButton );
    ToggleWaterLens();
    UI.PlaySound("Play_UI_Click");
  end
  if m_ToggleGovernmentLensId ~= nil and (actionId == m_ToggleGovernmentLensId) and GameCapabilities.HasCapability("CAPABILITY_LENS_GOVERNMENT") then
    LensPanelHotkeyControl( Controls.GovernmentLensButton );
    ToggleGovernmentLens();
    UI.PlaySound("Play_UI_Click");
  end
  if m_TogglePoliticalLensId ~= nil and (actionId == m_TogglePoliticalLensId) then
    LensPanelHotkeyControl( Controls.OwnerLensButton );
    ToggleOwnerLens();
    UI.PlaySound("Play_UI_Click");
  end
  if m_ToggleTourismLensId ~= nil and (actionId == m_ToggleTourismLensId) and GameCapabilities.HasCapability("CAPABILITY_LENS_TOURISM") then
    LensPanelHotkeyControl( Controls.TourismLensButton );
    ToggleTourismLens();
    UI.PlaySound("Play_UI_Click");
  end
  if m_ToggleEmpireLensId ~= nil and (actionId == m_ToggleEmpireLensId) and GameCapabilities.HasCapability("CAPABILITY_LENS_EMPIRE") then
    LensPanelHotkeyControl( Controls.EmpireLensButton );
    ToggleEmpireLens();
    UI.PlaySound("Play_UI_Click");
  end
  if m_Toggle2DViewId ~= nil and (actionId == m_Toggle2DViewId) then
    UI.PlaySound("Play_UI_Click");
    Toggle2DView();
  end
  if m_OpenMapSearchId ~= nil and (actionId == m_OpenMapSearchId) then
    UI.PlaySound("Play_UI_Click");

    if Controls.MapSearchPanel:IsHidden() then
      Controls.MapSearchPanel:SetHide(false);
      RealizeFlyouts(Controls.MapSearchPanel);
    end

    -- Take focus
    LuaEvents.MapSearch_PanelOpened();
  end
end

-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnInterfaceModeChanged(eOldMode:number, eNewMode:number)
  --and eNewMode ~= InterfaceModeTypes.VIEW_MODAL_LENS
  if eOldMode == InterfaceModeTypes.VIEW_MODAL_LENS then
    if not Controls.LensPanel:IsHidden() then
      if g_shouldCloseLensMenu then --If player turns off the lens from the menu, do not close the menu
        Controls.LensPanel:SetHide( true );
        RealizeFlyouts(Controls.LensPanel);
        Controls.LensButton:SetSelected( false );
      end
      g_shouldCloseLensMenu = true; --Reset variable so the menu can be closed by selecting a unit/city
      Controls.ReligionLensButton:SetCheck(false);
      Controls.ContinentLensButton:SetCheck(false);
      Controls.AppealLensButton:SetCheck(false);
      Controls.GovernmentLensButton:SetCheck(false);
      Controls.WaterLensButton:SetCheck(false);
      Controls.OwnerLensButton:SetCheck(false);
      Controls.TourismLensButton:SetCheck(false);
      Controls.EmpireLensButton:SetCheck(false);

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
        if UILens.IsLayerOn( m_HexColoringAppeal ) then
          UILens.ToggleLayerOff( m_HexColoringAppeal );
        end
        SetActiveModdedLens("NONE")
      end

      -- clear any non-standard layers
      UILens.ClearLayerHexes(m_AttackRange);
      UILens.ClearLayerHexes(m_HexColoringGreatPeople);
      UILens.ClearLayerHexes(m_MovementZoneOfControl);

      LuaEvents.ML_CloseLensPanels()
    end
  end
end

-- ===========================================================
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

-- ===========================================================
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

-- ===========================================================
function OnInputHandler( pInputStruct:table )
  local msg = pInputStruct:GetMessageType();

  -- Astog Modification Begin -------------------------------------------------
  if pInputStruct:GetKey() == Keys.VK_CONTROL then
    if msg == KeyEvents.KeyDown then
      if not m_AltSettlerLensOn and UILens.IsLayerOn(m_HexColoringWaterAvail) then
        --print("ctrl down")
        m_CurrentCursorPlotID = -1;
        m_CtrlDown = true
        m_AltSettlerLensOn = true
      end
    elseif msg == KeyEvents.KeyUp then
      m_CurrentCursorPlotID = -1;
      m_CtrlDown = false
    end
  end

  HandleMouseForModdedLens()
  -- Astog Modification End ---------------------------------------------------

  -- Catch ctrl+f
  if pInputStruct:GetKey() == Keys.F and pInputStruct:IsControlDown() then
    -- Open the search panel if it is not already open
    if Controls.MapSearchPanel:IsHidden() then
      Controls.MapSearchPanel:SetHide(false);
      RealizeFlyouts(Controls.MapSearchPanel);
    end

    -- Take focus
    LuaEvents.MapSearch_PanelOpened();
    return true;
  end

  -- Skip all handling when dragging is disabled or the minimap is collapsed
  if m_isMouseDragEnabled and not m_isCollapsed then
    -- Enable drag on LMB down
    if (msg == MouseEvents.LButtonDown or msg == MouseEvents.PointerDown) then
      local minix, miniy = GetMinimapMouseCoords( pInputStruct:GetX(), pInputStruct:GetY() );
      if IsMouseInMinimap( minix, miniy ) then
        m_isMouseDragging = true; -- Potential drag is in process
        m_hasMouseDragged = false; -- There has been no actual dragging yet
        LuaEvents.WorldInput_DragMapBegin(); -- Alert luathings that a drag is about to go down
        return true; -- Consume event
      end

      -- Disable drag on LMB up (but only if mouse was previously dragging)
    elseif m_isMouseDragging and (msg == MouseEvents.LButtonUp or msg == MouseEvents.PointerUp) then
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
    elseif m_isMouseDragging and (msg == MouseEvents.MouseMove or msg == MouseEvents.PointerUpdate) then
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

      -- Update tooltip as the mouse is moved over the minimap
    elseif (msg == MouseEvents.MouseMove or msg == MouseEvents.PointerUpdate) and not UI.IsFullscreenMapEnabled() then
      local ePlayer : number = Game.GetLocalPlayer();
      local pPlayerVis:table = PlayersVisibility[ePlayer];

      local minix, miniy = GetMinimapMouseCoords( pInputStruct:GetX(), pInputStruct:GetY() );
      if (pPlayerVis ~= nil and IsMouseInMinimap(minix, miniy)) then
        local wx, wy = TranslateMinimapToWorld(minix, miniy);
        local plotX, plotY = UI.GetPlotCoordFromWorld(wx, wy);
        local pPlot = Map.GetPlot(plotX, plotY);
        if (pPlot ~= nil) then
          local plotID = Map.GetPlotIndex(plotX, plotY);
          if pPlayerVis:IsRevealed(plotID) then
            local eOwner = pPlot:GetOwner();
            local pPlayerConfig = PlayerConfigurations[eOwner];
            if (pPlayerConfig ~= nil) then
              local szOwnerString = Locale.Lookup(pPlayerConfig:GetCivilizationShortDescription());

              if (szOwnerString == nil or string.len(szOwnerString) == 0) then
                szOwnerString = Locale.Lookup("LOC_TOOLTIP_PLAYER_ID", eOwner);
              end

              local pPlayer = Players[eOwner];
              if(GameConfiguration:IsAnyMultiplayer() and pPlayer:IsHuman()) then
                szOwnerString = szOwnerString .. " (" .. Locale.Lookup(pPlayerConfig:GetPlayerName()) .. ")";
              end

              local szOwner = Locale.Lookup("LOC_HUD_MINIMAP_OWNER_TOOLTIP", szOwnerString);
              Controls.MinimapImage:SetToolTipString(szOwner);
            else
              local pTooltipString = Locale.Lookup("LOC_MINIMAP_UNCLAIMED_TOOLTIP");
              Controls.MinimapImage:SetToolTipString(pTooltipString);
            end
          else
            local pTooltipString = Locale.Lookup("LOC_MINIMAP_FOG_OF_WAR_TOOLTIP");
            Controls.MinimapImage:SetToolTipString(pTooltipString);
          end
        end
      end
    end

    -- TODO the letterbox background should block mouse input
  end

  local uiMsg = pInputStruct:GetMessageType();
  if uiMsg == KeyEvents.KeyUp and pInputStruct:GetKey() == Keys.VK_ESCAPE and not Controls.LensPanel:IsHidden() then
    OnToggleLensList();
    return true;
  end

  return false;
end

-- ===========================================================
function OnTutorial_DisableMapDrag( isDisabled:boolean )
  m_isMouseDragEnabled = not isDisabled;
  if isDisabled then
    m_isMouseDragging = false;
    m_hasMouseDragged = false;
    m_wasMouseInMinimap = false;
  end
end

-- ===========================================================
function OnTutorial_SwitchToWorldView()
  Controls.SwitcherImage:SetTextureOffsetVal(0,0);
end

-- ===========================================================
function OnShutdown()
  LuaEvents.Tutorial_SwitchToWorldView.Remove( OnTutorial_SwitchToWorldView );
  LuaEvents.Tutorial_DisableMapDrag.Remove( OnTutorial_DisableMapDrag );
  LuaEvents.NotificationPanel_ShowContinentLens.Remove(OnToggleContinentLensExternal);

  m_LensButtonIM:ResetInstances();
  m_MapOptionIM:ResetInstances();
end

-- force the settler lens off when a city is added (this shouldn't happen, but it's a failsafe)
function OnCityAddedToMap(playerID, cityID, x, y)
  if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
    UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
  end

  UILens.ClearLayerHexes(m_HexColoringWaterAvail);
end

-- ===========================================================================
--  Modded Lens Support (by Astog)
-- ===========================================================================
function SetModLens()
  if m_CurrentModdedLensOn ~= nil and m_CurrentModdedLensOn ~= "NONE" and
    g_ModLenses[m_CurrentModdedLensOn] ~= nil then
    -- print("Highlighting " .. m_CurrentModdedLensOn .. " hexes")
    local getPlotColorFn = g_ModLenses[m_CurrentModdedLensOn].GetColorPlotTable
    local funNonStandard = g_ModLenses[m_CurrentModdedLensOn].NonStandardFunction
    if getPlotColorFn ~= nil then
      SetModLensHexes(getPlotColorFn())
    elseif funNonStandard ~= nil then
      funNonStandard()
    else
      print("ERROR: SetModLens - No Plot Color Function")
    end
  else
    print("ERROR: SetModLens - Given lens has no entry")
  end
end

-- ===========================================================================
function SetModLensHexes(colorPlot:table)
  if colorPlot ~= nil and table.count(colorPlot) > 0 then
    -- UILens.ClearLayerHexes(m_HexColoringAppeal);
    local localPlayer = Game.GetLocalPlayer()
    for color, plots in pairs(colorPlot) do
      if table.count(plots) > 0 then
        -- print("Showing " .. table.count(plots) .. " plots with color " .. color)
        UILens.SetLayerHexesColoredArea( m_HexColoringAppeal, localPlayer, plots, color);
      end
    end
  else
    print("ERROR: SetModLensHexes - Invalid colorPlot table")
  end
end

-- ===========================================================================
function SetActiveModdedLens(lensName:string)
  m_CurrentModdedLensOn = lensName
  LuaEvents.MinimapPanel_ModdedLensOn(lensName)
end

-- ===========================================================================
function GetActiveModdedLens(returnLens:table)
  returnLens[1] = m_CurrentModdedLensOn
end

-- ===========================================================================
function GetLensPanelOffsets(offsets:table)
  local y = Controls.MinimapContainer:GetSizeY() + Controls.MinimapContainer:GetOffsetY()
  if m_isCollapsed then
    y = y - Controls.MinimapContainer:GetSizeY()
  end

  offsets.Y = y
  offsets.X = Controls.LensPanel:GetSizeX() + Controls.LensPanel:GetOffsetX()
end

-- ===========================================================================
function ToggleModLens(buttonControl:table, lensName:string)
  if buttonControl:IsChecked() then
    SetActiveModdedLens(lensName);

    -- Check if the appeal lens is already active. Needed to clear any modded lens
    if UILens.IsLayerOn(m_HexColoringAppeal) then
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
    g_shouldCloseLensMenu = false;
    if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end

    LuaEvents.ML_CloseLensPanels()
    SetActiveModdedLens("NONE");
  end
end

-- ===========================================================================
function InitLens(lensName, modLens)
  print("InitLens - Adding ModLens: " .. lensName)
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

-- ===========================================================================
function AddLensEntry(lensKey:string, lensEntry:table)
  g_ModLenses[lensKey] = lensEntry
  InitLens(lensKey, lensEntry)
end

-- ===========================================================================
function InitializeModLens()
  print("Initializing " .. table.count(g_ModLenses) .. " lenses")
  -- sort here
  local sortedModLenses:table = {}
  for lensName, modLens in pairs(g_ModLenses) do
    table.insert(sortedModLenses, { SortOrder = modLens.SortOrder, Name = lensName, Lens = modLens } )
  end

  table.sort(sortedModLenses, function(a,b) return (a.SortOrder and a.SortOrder or 999) < (b.SortOrder and b.SortOrder or 999) end)
  -- initilize sorted
  for _,modLens in ipairs(sortedModLenses) do
    InitLens(modLens.Name, modLens.Lens)
  end
end

-- ===========================================================================
function HandleMouseForModdedLens()
  if not m_isMouseDragging then
    LuaEvents.ML_HandleMouse()

    -- If the alternate settler lens is on, check for plot change, or clear it
    if m_AltSettlerLensOn then
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
      local selectedUnit = UI.GetHeadSelectedUnit()

      if m_CtrlDown then
        RefreshSettlerLens()
      elseif UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
        RefreshSettlerLens()
        m_AltSettlerLensOn = false
      else
        RecheckSettlerLens()
        m_AltSettlerLensOn = false
      end
    end
  end
end

-- ===========================================================================
function LateInitialize()
  print_debug("ENTRY: Replacement MinimapPanel - LateInitialize");
  m_MiniMap_xmloffsety = Controls.MiniMap:GetOffsetY();
  g_ContinentsCache = Map.GetContinentsInUse();

  m_HexColoringReligion = UILens.CreateLensLayerHash("Hex_Coloring_Religion");
  m_HexColoringAppeal = UILens.CreateLensLayerHash("Hex_Coloring_Appeal_Level");
  m_HexColoringGovernment = UILens.CreateLensLayerHash("Hex_Coloring_Government");
  m_HexColoringOwningCiv = UILens.CreateLensLayerHash("Hex_Coloring_Owning_Civ");
  g_HexColoringContinent = UILens.CreateLensLayerHash("Hex_Coloring_Continent");
  m_HexColoringWaterAvail = UILens.CreateLensLayerHash("Hex_Coloring_Water_Availablity");
  m_TouristTokens = UILens.CreateLensLayerHash("Tourist_Tokens");

  Controls.MinimapImage:RegisterSizeChanged( OnMinimapImageSizeChanged );
  UI.SetMinimapImageControl( Controls.MinimapImage );

  -- Context / Control callbacks
  ContextPtr:SetShutdown( OnShutdown );

  Controls.MapSearchPanel:RegisterWhenHidden( OnMapSearchPanelVisibilityChanged );
  Controls.MapSearchPanel:RegisterWhenShown( OnMapSearchPanelVisibilityChanged );

  Controls.AppealLensButton:RegisterCallback( Mouse.eLClick, ToggleAppealLens );
  Controls.ContinentLensButton:RegisterCallback( Mouse.eLClick, ToggleContinentLens );
  Controls.CollapseButton:RegisterCallback( Mouse.eLClick, OnCollapseToggle );
  Controls.CollapseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.ExpandButton:RegisterCallback( Mouse.eLClick, OnCollapseToggle );
  Controls.ExpandButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.GovernmentLensButton:RegisterCallback( Mouse.eLClick, ToggleGovernmentLens );

  if GameConfiguration.IsWorldBuilderEditor() then
    Controls.MapPinListButton:SetDisabled(true);
    Controls.MapPinListButton:SetHide(true);
    Controls.FullscreenMapButton:SetDisabled(false);
    Controls.FullscreenMapButton:SetHide(false);
    Controls.FullscreenMapButton:RegisterCallback( Mouse.eLClick, ShowFullscreenMap );
    Controls.FullscreenMapButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
    Controls.MapSearchButton:SetDisabled(true);
    Controls.MapSearchButton:SetHide(true);
    Controls.ToggleResourcesButton:SetHide(true);
    Controls.ToggleYieldsButton:SetHide(true);
  else
    Controls.MapPinListButton:SetDisabled(false);
    Controls.MapPinListButton:SetHide(false);
    Controls.FullscreenMapButton:SetDisabled(false);
    Controls.FullscreenMapButton:SetHide(false);
    Controls.MapSearchButton:SetDisabled(false);
    Controls.MapSearchButton:SetHide(false);
    Controls.MapPinListButton:RegisterCallback( Mouse.eLClick, ToggleMapPinMode );
    Controls.MapPinListButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
    Controls.FullscreenMapButton:RegisterCallback( Mouse.eLClick, ShowFullscreenMap );
    Controls.FullscreenMapButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
    Controls.MapSearchButton:RegisterCallback( Mouse.eLClick, ToggleMapSearchPanel );
    Controls.MapSearchButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
    Controls.ToggleResourcesButton:SetHide(false);
    Controls.ToggleYieldsButton:SetHide(false);
  end

  Controls.MapOptionsButton:RegisterCallback( Mouse.eLClick, ToggleMapOptionsList );
  Controls.MapOptionsButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.MapOptionsButton:SetHide(false);
  Controls.LensButton:RegisterCallback( Mouse.eLClick, OnToggleLensList );
  Controls.LensButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.OwnerLensButton:RegisterCallback( Mouse.eLClick, ToggleOwnerLens );
  Controls.TourismLensButton:RegisterCallback( Mouse.eLClick, ToggleTourismLens );
  Controls.EmpireLensButton:RegisterCallback( Mouse.eLClick, ToggleEmpireLens );
  Controls.Pause:RegisterEndCallback( OnPauseEnd );
  Controls.ReligionLensButton:RegisterCallback( Mouse.eLClick, ToggleReligionLens );
  Controls.StrategicSwitcherButton:RegisterCallback( Mouse.eLClick, Toggle2DView );
  Controls.StrategicSwitcherButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.ToggleGridButton:RegisterCallback( Mouse.eLClick, ToggleGrid );
  Controls.ToggleResourcesButton:RegisterCallback( Mouse.eLClick, ToggleResourceIcons );
  Controls.ToggleYieldsButton:RegisterCallback( Mouse.eLClick, ToggleYieldIcons );
  Controls.WaterLensButton:RegisterCallback( Mouse.eLClick, ToggleWaterLens );

  -- Begin CQUI Mod ------------------------------------------------------------------------------------
  -- Requires the CQUI Database and CQUICommon files have been loaded before this (<LoadOrder>)
  -- CQUI Options Button
  Controls.CQUI_OptionsButton:RegisterCallback( Mouse.eLClick, function() LuaEvents.CQUI_ToggleSettings() end);
  Controls.CQUI_OptionsButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end)  
  -- CQUI Handlers
  LuaEvents.CQUI_Option_ToggleYields.Add( ToggleYieldIcons );
  LuaEvents.CQUI_SettingsInitialized.Add( CQUI_ToggleYieldIcons );
  -- End CQUI Mod ------------------------------------------------------------------------------------

  -- Game Events
  Events.InputActionTriggered.Add( OnInputActionTriggered );
  Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
  Events.LensLayerOn.Add( OnLensLayerOn );
  Events.LensLayerOff.Add( OnLensLayerOff );
  Events.LocalPlayerChanged.Add( OnLocalPlayerChanged );
  Events.UserOptionsActivated.Add( OnUserOptionsActivated );

  Events.CityAddedToMap.Add( OnCityAddedToMap );
end

-- ===========================================================================
function OnInit( isReload:boolean )
  LateInitialize();
end

-- ===========================================================
function CloseAllLenses()
  if not Controls.LensPanel:IsHidden() then
    OnToggleLensList();
  end
end

-- ===========================================================================
-- INITIALIZATION
-- ===========================================================================
function Initialize()
  print_debug("ENTRY: Replacement MinimapPanel - Initialize");
  ContextPtr:SetInitHandler( OnInit );
  ContextPtr:SetInputHandler( OnInputHandler, true );

  Controls.LensPanel:ChangeParent(Controls.LensButton);
  Controls.MapOptionsPanel:ChangeParent(Controls.MapOptionsButton);
  Controls.ToggleResourcesButton:SetCheck( UserConfiguration.ShowMapResources() );
  Controls.ToggleYieldsButton:SetCheck( UserConfiguration.ShowMapYield() );

  -- Hide buttons not needed for the world builder
  if GameConfiguration.IsWorldBuilderEditor() then
    Controls.LensButton:SetHide(true);
    Controls.MapPinListButton:SetHide(true);
    Controls.StrategicSwitcherButton:SetHide(true);
    Controls.OptionsStack:ReprocessAnchoring();
  end

  -- Make sure the StrategicSwitcherButton has the correct image when the game starts in StrategicView
  if UI.GetWorldRenderView() == WorldRenderView.VIEW_2D then
    Controls.SwitcherImage:SetTextureOffsetVal(0,24);
  end

  LuaEvents.NotificationPanel_ShowContinentLens.Add(OnToggleContinentLensExternal);
  LuaEvents.Tutorial_DisableMapDrag.Add( OnTutorial_DisableMapDrag );
  LuaEvents.Tutorial_SwitchToWorldView.Add( OnTutorial_SwitchToWorldView );
  LuaEvents.MinimapPanel_ToggleGrid.Add( ToggleGrid );
  LuaEvents.MinimapPanel_RefreshMinimapOptions.Add( RefreshMinimapOptions );
  LuaEvents.MinimapPanel_CloseAllLenses.Add( CloseAllLenses );
  LuaEvents.CityPanelOverview_Opened.Add( 
    function()
        if not Controls.LensPanel:IsHidden() then
            OnToggleLensList();
        end
    end );

  -- Begin Astog Mod --------------------------------------------------------------------------------------------------

  -- Mod Lens Support
  LuaEvents.MinimapPanel_SetActiveModLens.Add( SetActiveModdedLens );
  LuaEvents.MinimapPanel_GetActiveModLens.Add( GetActiveModdedLens );
  LuaEvents.MinimapPanel_GetLensPanelOffsets.Add( GetLensPanelOffsets );
  LuaEvents.MinimapPanel_AddLensEntry.Add( AddLensEntry );
  InitializeModLens()

  -- End Astog Mod ------------------------------------------------------------------------------------------------
end
Initialize();
