local LENS_NAME = "ML_ADJYIELD"
local ML_LENS_LAYER = LensLayers.HEX_COLORING_APPEAL_LEVEL

-- ===========================================================================
-- AdjYield Lens Support
-- ===========================================================================

local function clamp(val, min, max)
  if val < min then
    return min
  elseif val > max then
    return max
  end
  return val
end

-- ===========================================================================
-- Exported functions
-- ===========================================================================

local function OnGetColorPlotTable()
  local mapWidth, mapHeight = Map.GetGridSize();
  local localPlayer   :number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];
  
  local colorPlot = {}
  for i = 1, 8 do
    colorPlot[UI.GetColorValue("COLOR_GRADIENT8_" .. tostring(i))] = {}
  end
  
  for i = 0, (mapWidth * mapHeight) - 1, 1 do
    local pPlot:table = Map.GetPlotByIndex(i);
    if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) and pPlot:GetOwner() == localPlayer then
      if plotHasDistrict(pPlot) and (not pPlot:IsCity()) and (not plotHasWonder(pPlot)) then
        local pPlayer = Players[localPlayer];
        local districtID = pPlot:GetDistrictID()
        local pDistrict = pPlayer:GetDistricts():FindID(districtID);
        local pCity = pDistrict:GetCity();
        -- Get adjacency yield
        local iBonus = 0
        for yieldInfo in GameInfo.Yields() do
          iBonus = iBonus + pPlot:GetAdjacencyYield(localPlayer, pCity:GetID(), pPlot:GetDistrictType(), yieldInfo.Index);
          -- Don't break here, calculate net-yield
        end
        local colorKey:string = "COLOR_GRADIENT8_" .. tostring(clamp(iBonus,0,7)+1)
        -- print("Adding " .. tostring(i) .. " to " .. colorKey)
        table.insert(colorPlot[UI.GetColorValue(colorKey)], i)
      end
    end
  end
  
  return colorPlot
end

--[[
local function ShowAdjYieldLens()
  LuaEvents.MinimapPanel_SetActiveModLens(LENS_NAME)
  UILens.ToggleLayerOn(ML_LENS_LAYER)
end

local function ClearAdjYieldLens()
  if UILens.IsLayerOn(ML_LENS_LAYER) then
    UILens.ToggleLayerOff(ML_LENS_LAYER);
  end
  LuaEvents.MinimapPanel_SetActiveModLens("NONE");
end

local function OnInitialize()
  -- Nothing to do
end
]]
  
local AdjYieldLensEntry = {
  LensButtonText = "LOC_HUD_ADJYIELD_LENS",
  LensButtonTooltip = "LOC_HUD_ADJYIELD_LENS_TOOLTIP",
  Initialize = nil,
  GetColorPlotTable = OnGetColorPlotTable
}

-- minimappanel.lua
if g_ModLenses ~= nil then
  g_ModLenses[LENS_NAME] = AdjYieldLensEntry
end

-- modallenspanel.lua
if g_ModLensModalPanel ~= nil then
  g_ModLensModalPanel[LENS_NAME] = {}
  g_ModLensModalPanel[LENS_NAME].Legend = {}
  g_ModLensModalPanel[LENS_NAME].LensTextKey = "LOC_HUD_ADJYIELD_LENS"
  for i = 1, 8 do
    local params:table = {
      "LOC_HUD_REPORTS_TAB_YIELDS",
      UI.GetColorValue("COLOR_GRADIENT8_" .. tostring(i)),
      nil,  -- bonus icon
      "+ " .. tostring(i-1)  -- bonus value
    }
    table.insert(g_ModLensModalPanel[LENS_NAME].Legend, params)
  end
end
  