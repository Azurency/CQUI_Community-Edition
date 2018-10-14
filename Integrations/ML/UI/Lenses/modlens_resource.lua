include("LensSupport")

local PANEL_OFFSET_Y:number = 32
local PANEL_OFFSET_X:number = -5

local LENS_NAME = "ML_RESOURCE"
local ML_LENS_LAYER = LensLayers.HEX_COLORING_APPEAL_LEVEL

-- ===========================================================================
--  Member Variables
-- ===========================================================================

local m_isOpen:boolean = false
local m_resourcesToHide:table = {};
local m_resourceCategoryToHide:table = {};

-- ===========================================================================
--  City Overlap Support functions
-- ===========================================================================

local function ShowResourceLens()
  print("Showing " .. LENS_NAME)
  LuaEvents.MinimapPanel_SetActiveModLens(LENS_NAME)
  UILens.ToggleLayerOn(ML_LENS_LAYER)
end

local function ClearResourceLens()
  print("Clearing " .. LENS_NAME)
  if UILens.IsLayerOn(ML_LENS_LAYER) then
    UILens.ToggleLayerOff(ML_LENS_LAYER);
  else
    print("Nothing to clear")
  end
  LuaEvents.MinimapPanel_SetActiveModLens("NONE");
end

function RefreshResourceLens()
  -- Assuming city overlap lens is already applied
  UILens.ClearLayerHexes(ML_LENS_LAYER)
  SetResourceLens()
end

local function clamp(val, min, max)
  if val < min then
    return min
  elseif val > max then
    return max
  end
  return val
end

-- ===========================================================================
--  Exported functions
-- ===========================================================================

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
          if not has_value(ResourceExclusionList, resourceInfo.ResourceType) and (not has_value(m_resourcesToHide, resourceInfo.ResourceType)) then
            table.insert(ResourcePlots, i);
            if resourceInfo.ResourceClassType == "RESOURCECLASS_BONUS" and
            not has_value(m_resourceCategoryToHide, "Bonus") then
              if plotHasImprovement(pPlot) and not pPlot:IsImprovementPillaged() then
                table.insert(ConnectedBonus, i)
              else
                table.insert(NotConnectedBonus, i)
              end
            elseif resourceInfo.ResourceClassType == "RESOURCECLASS_LUXURY" and
            not has_value(m_resourceCategoryToHide, "Luxury") then
              if plotHasImprovement(pPlot) and not pPlot:IsImprovementPillaged() then
                table.insert(ConnectedLuxury, i)
              else
                table.insert(NotConnectedLuxury, i)
              end
            elseif resourceInfo.ResourceClassType == "RESOURCECLASS_STRATEGIC" and
            not has_value(m_resourceCategoryToHide, "Strategic") then
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
  print("Show Resource Picker")
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
  not has_value(m_resourceCategoryToHide, "Bonus") then
    for i, resourceInfo in ipairs(BonusResources) do
      -- print(Locale.Lookup(resourceInfo.Name))
      local resourcePickInstance:table = {};
      ContextPtr:BuildInstanceForControl( "ResourcePickEntry", resourcePickInstance, Controls.BonusResourcePickStack );
      resourcePickInstance.ResourceLabel:SetText("[ICON_" .. resourceInfo.ResourceType .. "]" .. Locale.Lookup(resourceInfo.Name));
      
      if has_value(m_resourcesToHide, resourceInfo.ResourceType) then
        resourcePickInstance.ResourceCheckbox:SetCheck(false);
      end
      
      resourcePickInstance.ResourceCheckbox:RegisterCallback(Mouse.eLClick, function() HandleResourceCheckbox(resourcePickInstance, resourceInfo.ResourceType); end);
    end
  end
  
  -- Luxury Resources
  if table.count(LuxuryResources) > 0 and
  not has_value(m_resourceCategoryToHide, "Luxury") then
    for i, resourceInfo in ipairs(LuxuryResources) do
      -- print(Locale.Lookup(resourceInfo.Name))
      local resourcePickInstance:table = {};
      ContextPtr:BuildInstanceForControl( "ResourcePickEntry", resourcePickInstance, Controls.LuxuryResourcePickStack );
      resourcePickInstance.ResourceLabel:SetText("[ICON_" .. resourceInfo.ResourceType .. "]" .. Locale.Lookup(resourceInfo.Name));
      
      if has_value(m_resourcesToHide, resourceInfo.ResourceType) then
        resourcePickInstance.ResourceCheckbox:SetCheck(false);
      end
      
      resourcePickInstance.ResourceCheckbox:RegisterCallback(Mouse.eLClick, function() HandleResourceCheckbox(resourcePickInstance, resourceInfo.ResourceType); end);
    end
  end
  
  -- Strategic Resources
  if table.count(StrategicResources) > 0 and
  not has_value(m_resourceCategoryToHide, "Strategic") then
    for i, resourceInfo in ipairs(StrategicResources) do
      -- print(Locale.Lookup(resourceInfo.Name))
      local resourcePickInstance:table = {};
      ContextPtr:BuildInstanceForControl( "ResourcePickEntry", resourcePickInstance, Controls.StrategicResourcePickStack );
      resourcePickInstance.ResourceLabel:SetText("[ICON_" .. resourceInfo.ResourceType .. "]" .. Locale.Lookup(resourceInfo.Name));
      
      if has_value(m_resourcesToHide, resourceInfo.ResourceType) then
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
    print("Hide Bonus Resource")
    ndup_insert(m_resourceCategoryToHide, "Bonus")
  else
    print("Show Bonus Resource")
    find_and_remove(m_resourceCategoryToHide, "Bonus");
  end
  
  -- Assuming resource lens is already applied
  RefreshResourcePicker();
  RefreshResourceLens();
end

function ToggleResourceLens_Luxury()
  if not Controls.ShowLuxuryResource:IsChecked() then
    print("Hide Luxury Resource")
    ndup_insert(m_resourceCategoryToHide, "Luxury")
  else
    print("Show Luxury Resource")
    find_and_remove(m_resourceCategoryToHide, "Luxury");
  end
  
  -- Assuming resource lens is already applied
  RefreshResourcePicker();
  RefreshResourceLens();
end

function ToggleResourceLens_Strategic()
  if not Controls.ShowStrategicResource:IsChecked() then
    print("Hide Strategic Resource")
    ndup_insert(m_resourceCategoryToHide, "Strategic")
  else
    print("Show Strategic Resource")
    find_and_remove(m_resourceCategoryToHide, "Strategic");
  end
  
  -- Assuming resource lens is already applied
  RefreshResourcePicker();
  RefreshResourceLens();
end

function HandleResourceCheckbox(pControl, resourceType)
  if not pControl.ResourceCheckbox:IsChecked() then
    -- Don't show this resource
    if not has_value(m_resourcesToHide, resourceType) then
      table.insert(m_resourcesToHide, resourceType)
    end
  else
    -- Show this resource
    for i, rType in ipairs(m_resourcesToHide) do
      if rType == resourceType then
        table.remove(m_resourcesToHide, i)
        break
      end
    end
  end
  
  -- Assuming resource lens is already applied
  RefreshResourceLens();
end

-- ===========================================================================
--  UI Controls
-- ===========================================================================

local function Open()
  Controls.ResourceLensOptionsPanel:SetHide(false)
  m_isOpen = true
  RefreshResourcePicker()  -- Recall this to apply options properly
end

local function Close()
  Controls.ResourceLensOptionsPanel:SetHide(true)
  m_isOpen = false
end

local function TogglePanel()
  if m_isOpen then
    Close()
  else
    Open()
  end
end

local function OnReoffsetPanel()
  -- Get size and offsets for minimap panel
  local offsets = {}
  LuaEvents.MinimapPanel_GetLensPanelOffsets(offsets)
  Controls.ResourceLensOptionsPanel:SetOffsetY(offsets.Y + PANEL_OFFSET_Y)
  Controls.ResourceLensOptionsPanel:SetOffsetX(offsets.X + PANEL_OFFSET_X)
end

-- ===========================================================================
--  Game Engine Events
-- ===========================================================================

local function OnLensLayerOn(layerNum:number)
  if layerNum == ML_LENS_LAYER then
    local lens = {}
    LuaEvents.MinimapPanel_GetActiveModLens(lens);
    if lens[1] == LENS_NAME then
      SetResourceLens()
    end
  end
end

local function ChangeContainer()
  -- Change the parent to /InGame/HUD container so that it hides correcty during diplomacy, etc
  local hudContainer = ContextPtr:LookUpControl("/InGame/HUD")
  Controls.ResourceLensOptionsPanel:ChangeParent(hudContainer)
end

local function OnInit(isReload:boolean)
  if isReload then
    ChangeContainer()
  end
end

local function OnShutdown()
  -- Destroy the container manually
  local hudContainer = ContextPtr:LookUpControl("/InGame/HUD")
  if hudContainer ~= nil then
    hudContainer:DestroyChild(Controls.ResourceLensOptionsPanel)
  end
end

-- ===========================================================================
--  Init
-- ===========================================================================

-- minimappanel.lua
local ResourceLensEntry = {
  LensButtonText = "LOC_HUD_RESOURCE_LENS",
  LensButtonTooltip = "LOC_HUD_RESOURCE_LENS_TOOLTIP",
  Initialize = nil,
  OnToggle = TogglePanel,
  GetColorPlotTable = nil  -- Don't pass a function here since we will have our own trigger
}
  
-- modallenspanel.lua
local ResourceLensModalPanelEntry = {}
ResourceLensModalPanelEntry.LensTextKey = "LOC_HUD_RESOURCE_LENS"
ResourceLensModalPanelEntry.Legend = {
  {"LOC_TOOLTIP_RESOURCE_LENS_LUXURY",        UI.GetColorValue("COLOR_LUXCONNECTED_RES_LENS")},
  {"LOC_TOOLTIP_RESOURCE_LENS_NLUXURY",       UI.GetColorValue("COLOR_LUXNCONNECTED_RES_LENS")},
  {"LOC_TOOLTIP_RESOURCE_LENS_BONUS",         UI.GetColorValue("COLOR_BONUSCONNECTED_RES_LENS")},
  {"LOC_TOOLTIP_RESOURCE_LENS_NBONUS",        UI.GetColorValue("COLOR_BONUSNCONNECTED_RES_LENS")},
  {"LOC_TOOLTIP_RESOURCE_LENS_STRATEGIC",     UI.GetColorValue("COLOR_STRATCONNECTED_RES_LENS")},
  {"LOC_TOOLTIP_RESOURCE_LENS_NSTRATEGIC",    UI.GetColorValue("COLOR_STRATNCONNECTED_RES_LENS")}
}

-- Don't import this into g_ModLenses, since this for the UI (ie not lens)
local function Initialize()
  print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
  print("           Resource Panel")
  print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
  Close()
  OnReoffsetPanel()
  
  ContextPtr:SetInitHandler( OnInit )
  ContextPtr:SetShutdown( OnShutdown )
  ContextPtr:SetInputHandler( OnInputHandler, true );
  
  Events.LoadScreenClose.Add(
    function()
      ChangeContainer()
      LuaEvents.MinimapPanel_AddLensEntry(LENS_NAME, ResourceLensEntry);
      LuaEvents.ModalLensPanel_AddLensEntry(LENS_NAME, ResourceLensModalPanelEntry);
    end
  )
  Events.LensLayerOn.Add( OnLensLayerOn );
  
  -- Resource Lens Setting
  Controls.ShowBonusResource:RegisterCallback( Mouse.eLClick, ToggleResourceLens_Bonus );
  Controls.ShowLuxuryResource:RegisterCallback( Mouse.eLClick, ToggleResourceLens_Luxury );
  Controls.ShowStrategicResource:RegisterCallback( Mouse.eLClick, ToggleResourceLens_Strategic );
  
  LuaEvents.ModLens_ReoffsetPanels.Add( OnReoffsetPanel );
  LuaEvents.ML_CloseLensPanels.Add( Close );
end

Initialize()
