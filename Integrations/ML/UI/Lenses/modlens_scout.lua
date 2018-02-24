local LENS_NAME = "ML_SCOUT"
local ML_LENS_LAYER = LensLayers.HEX_COLORING_APPEAL_LEVEL

-- Should the scout lens auto apply, when a scout/ranger is selected.
local AUTO_APPLY_SCOUT_LENS:boolean = true

-- CQUI
local function CQUI_OnSettingsUpdate()
  AUTO_APPLY_SCOUT_LENS = GameConfiguration.GetValue("CQUI_AutoapplyScoutLens");
end

-- ===========================================================================
-- Scout Lens Support
-- ===========================================================================

local function plotHasGoodyHut(plot)
  local improvementInfo = GameInfo.Improvements[plot:GetImprovementType()];
  if improvementInfo ~= nil and improvementInfo.ImprovementType == "IMPROVEMENT_GOODY_HUT" then
    return true;
  end
  return false;
end

-- ===========================================================================
-- Exported functions
-- ===========================================================================

local function OnGetColorPlotTable()
  -- print("Show scout lens")
  local mapWidth, mapHeight = Map.GetGridSize();
  local localPlayer   :number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];
  
  local GoodyHutColor   :number = UI.GetColorValue("COLOR_GHUT_SCOUT_LENS");
  local colorPlot = {}
  colorPlot[GoodyHutColor] = {}
  
  for i = 0, (mapWidth * mapHeight) - 1, 1 do
    local pPlot:table = Map.GetPlotByIndex(i);
    if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) then
      if plotHasGoodyHut(pPlot) then
        table.insert(colorPlot[GoodyHutColor], i)
      end
    end
  end
  
  return colorPlot
end

-- Called when a scout is selected
local function ShowScoutLens()
  LuaEvents.MinimapPanel_SetActiveModLens(LENS_NAME)
  UILens.ToggleLayerOn(ML_LENS_LAYER)
end

local function ClearScoutLens()
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
        if unitType == "UNIT_SCOUT" and AUTO_APPLY_SCOUT_LENS then
          ShowScoutLens();
        end
        -- Deselection
      else
        if unitType == "UNIT_SCOUT" and AUTO_APPLY_SCOUT_LENS then
          ClearScoutLens();
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
    if lens[1] == LENS_NAME and AUTO_APPLY_SCOUT_LENS then
      ClearScoutLens();
    end
  end
end

local function OnInitialize()
  Events.UnitSelectionChanged.Add( OnUnitSelectionChanged );
  Events.UnitRemovedFromMap.Add( OnUnitRemovedFromMap );

  -- CQUI Handlers
  LuaEvents.CQUI_SettingsUpdate.Add( CQUI_OnSettingsUpdate );
  Events.LoadScreenClose.Add( CQUI_OnSettingsUpdate ); -- Astog: Update settings when load screen close
end

local ScoutLensEntry = {
  LensButtonText = "LOC_HUD_SCOUT_LENS",
  LensButtonTooltip = "LOC_HUD_SCOUT_LENS_TOOLTIP",
  Initialize = OnInitialize,
  GetColorPlotTable = OnGetColorPlotTable
}

-- minimappanel.lua
if g_ModLenses ~= nil then
  g_ModLenses[LENS_NAME] = ScoutLensEntry
end

-- modallenspanel.lua
if g_ModLensModalPanel ~= nil then
  g_ModLensModalPanel[LENS_NAME] = {}
  g_ModLensModalPanel[LENS_NAME].LensTextKey = "LOC_HUD_SCOUT_LENS"
  g_ModLensModalPanel[LENS_NAME].Legend = {
    {"LOC_TOOLTIP_SCOUT_LENS_GHUT", UI.GetColorValue("COLOR_GHUT_SCOUT_LENS")}
  }
end
