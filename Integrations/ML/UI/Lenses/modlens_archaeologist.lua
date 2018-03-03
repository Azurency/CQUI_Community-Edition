local LENS_NAME = "ML_ARCHAEOLOGIST"
local ML_LENS_LAYER = LensLayers.HEX_COLORING_APPEAL_LEVEL

-- Should the archaeologist lens auto apply, when a archaeologist is selected.
local AUTO_APPLY_ARCHEOLOGIST_LENS:boolean = true

-- CQUI
local function CQUI_OnSettingsUpdate()
  AUTO_APPLY_ARCHEOLOGIST_LENS = GameConfiguration.GetValue("CQUI_AutoapplyArchaeologistLens");
end

-- ===========================================================================
-- Archaeologist Lens Support
-- ===========================================================================

local function plotHasAnitquitySite(plot)
  local resourceInfo = GameInfo.Resources[plot:GetResourceType()];
  if resourceInfo ~= nil and resourceInfo.ResourceType == "RESOURCE_ANTIQUITY_SITE" then
    return true;
  end
  return false
end

local function plotHasShipwreck(plot)
  local resourceInfo = GameInfo.Resources[plot:GetResourceType()];
  if resourceInfo ~= nil and resourceInfo.ResourceType == "RESOURCE_SHIPWRECK" then
    return true;
  end
  return false
end

-- ===========================================================================
-- Exported functions
-- ===========================================================================

local function OnGetColorPlotTable()
  local mapWidth, mapHeight = Map.GetGridSize();
  local localPlayer   :number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];
  
  local AntiquityColor = UI.GetColorValue("COLOR_ARTIFACT_ARCH_LENS");
  local ShipwreckColor = UI.GetColorValue("COLOR_SHIPWRECK_ARCH_LENS");
  local colorPlot = {}
  colorPlot[AntiquityColor] = {}
  colorPlot[ShipwreckColor] = {}
  
  for i = 0, (mapWidth * mapHeight) - 1, 1 do
    local pPlot:table = Map.GetPlotByIndex(i);
    
    if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) and playerHasDiscoveredResource(localPlayer, i) then
      if plotHasAnitquitySite(pPlot) then
        table.insert(colorPlot[AntiquityColor], i)
      elseif plotHasShipwreck(pPlot) then
        table.insert(colorPlot[ShipwreckColor], i)
      end
    end
  end
  
  return colorPlot
end

-- Called when an archaeologist is selected
local function ShowArchaeologistLens()
  LuaEvents.MinimapPanel_SetActiveModLens(LENS_NAME)
  UILens.ToggleLayerOn(ML_LENS_LAYER)
end

local function ClearArchaeologistLens()
  if UILens.IsLayerOn(ML_LENS_LAYER) then
    UILens.ToggleLayerOff(ML_LENS_LAYER);
  end
  LuaEvents.MinimapPanel_SetActiveModLens("NONE");
end

local function OnUnitSelectionChanged( playerID:number, unitID:number, hexI:number, hexJ:number, hexK:number, bSelected:boolean, bEditable:boolean )
  if playerID == Game.GetLocalPlayer() then
    local unitType = GetUnitType(playerID, unitID);
    if unitType then
      if bSelected then
        if unitType == "UNIT_ARCHAEOLOGIST" and AUTO_APPLY_ARCHEOLOGIST_LENS then
          ShowArchaeologistLens();
        end
        -- Deselection
      else
        if unitType == "UNIT_ARCHAEOLOGIST" and AUTO_APPLY_ARCHEOLOGIST_LENS then
          ClearArchaeologistLens();
        end
      end
    end
  end
end

local function OnUnitRemovedFromMap( playerID: number, unitID : number )
  local localPlayer = Game.GetLocalPlayer()
  local lens = {}
  LuaEvents.MinimapPanel_GetActiveModLens(lens)
  if playerID == localPlayer then
    if lens[1] == LENS_NAME and AUTO_APPLY_ARCHEOLOGIST_LENS then
      ClearArchaeologistLens();
    end
  end
end

-- For modded lens during multiplayer. Might need to test this further
function OnUnitCaptured( currentUnitOwner, unit, owningPlayer, capturingPlayer )
  local localPlayer = Game.GetLocalPlayer()
  if owningPlayer == localPlayer then
    local unitType = GetUnitType(owningPlayer, unitID)
    if unitType and unitType == "UNIT_ARCHAEOLOGIST" and AUTO_APPLY_ARCHEOLOGIST_LENS then
      ClearArchaeologistLens();
    end
  end
end

local function OnInitialize()
  Events.UnitSelectionChanged.Add( OnUnitSelectionChanged );
  Events.UnitRemovedFromMap.Add( OnUnitRemovedFromMap );
  Events.UnitCaptured.Add( OnUnitCaptured );

  -- CQUI Handlers
  LuaEvents.CQUI_SettingsUpdate.Add( CQUI_OnSettingsUpdate );
  Events.LoadScreenClose.Add( CQUI_OnSettingsUpdate ); -- Astog: Update settings when load screen close
end

local ArchaeologistLensEntry = {
  LensButtonText = "LOC_HUD_ARCHAEOLOGIST_LENS",
  LensButtonTooltip = "LOC_HUD_ARCHAEOLOGIST_LENS_TOOLTIP",
  Initialize = OnInitialize,
  GetColorPlotTable = OnGetColorPlotTable
}

-- minimappanel.lua
if g_ModLenses ~= nil then
  g_ModLenses[LENS_NAME] = ArchaeologistLensEntry
end

-- modallenspanel.lua
if g_ModLensModalPanel ~= nil then
  g_ModLensModalPanel[LENS_NAME] = {}
  g_ModLensModalPanel[LENS_NAME].LensTextKey = "LOC_HUD_ARCHAEOLOGIST_LENS"
  g_ModLensModalPanel[LENS_NAME].Legend = {
    {"LOC_TOOLTIP_ARCHAEOLOGIST_LENS_ARTIFACT",     UI.GetColorValue("COLOR_ARTIFACT_ARCH_LENS")},
    {"LOC_TOOLTIP_ARCHAEOLOGIST_LENS_SHIPWRECK",    UI.GetColorValue("COLOR_SHIPWRECK_ARCH_LENS")}
  }
end
