include("LensSupport")

local LENS_NAME = "ML_WONDER"
local ML_LENS_LAYER = LensLayers.HEX_COLORING_APPEAL_LEVEL

-- ===========================================================================
-- Wonder Lens Support
-- ===========================================================================

-- ===========================================================================
-- Exported functions
-- ===========================================================================

local function OnGetColorPlotTable()
  local mapWidth, mapHeight = Map.GetGridSize();
  local localPlayer   :number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];
  
  local NaturalWonderColor  :number = UI.GetColorValue("COLOR_NATURAL_WONDER_LENS");
  local PlayerWonderColor   :number = UI.GetColorValue("COLOR_PLAYER_WONDER_LENS");
  local colorPlot:table = {};
  colorPlot[NaturalWonderColor] = {}
  colorPlot[PlayerWonderColor] = {}
  
  for i = 0, (mapWidth * mapHeight) - 1, 1 do
    local pPlot:table = Map.GetPlotByIndex(i);
    if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) then
      -- check for player wonder.
      if plotHasWonder(pPlot) then
        table.insert(colorPlot[PlayerWonderColor], i);
      else
        -- Check for natural wonder
        local featureInfo = GameInfo.Features[pPlot:GetFeatureType()];
        if featureInfo ~= nil and featureInfo.NaturalWonder then
          table.insert(colorPlot[NaturalWonderColor], i)
        end
      end
    end
  end
  
  return colorPlot
end

--[[
local function ShowWonderLens()
  LuaEvents.MinimapPanel_SetActiveModLens(LENS_NAME)
  UILens.ToggleLayerOn(ML_LENS_LAYER)
end

local function ClearWonderLens()
  if UILens.IsLayerOn(ML_LENS_LAYER) then
    UILens.ToggleLayerOff(ML_LENS_LAYER);
  end
  LuaEvents.MinimapPanel_SetActiveModLens("NONE");
end

local function OnInitialize()
  -- Nothing to do
end
]]

local WonderLensEntry = {
  LensButtonText = "LOC_HUD_WONDER_LENS",
  LensButtonTooltip = "LOC_HUD_WONDER_LENS_TOOLTIP",
  Initialize = nil,
  GetColorPlotTable = OnGetColorPlotTable
}

-- minimappanel.lua
if g_ModLenses ~= nil then
  g_ModLenses[LENS_NAME] = WonderLensEntry
end

-- modallenspanel.lua
if g_ModLensModalPanel ~= nil then
  g_ModLensModalPanel[LENS_NAME] = {}
  g_ModLensModalPanel[LENS_NAME].LensTextKey = "LOC_HUD_WONDER_LENS"
  g_ModLensModalPanel[LENS_NAME].Legend = {
    {"LOC_TOOLTIP_WONDER_LENS_NWONDER", UI.GetColorValue("COLOR_NATURAL_WONDER_LENS")},
    {"LOC_TOOLTIP_RESOURCE_LENS_PWONDER", UI.GetColorValue("COLOR_PLAYER_WONDER_LENS")}
  }
end
  