local LENS_NAME = "ML_BARBARIAN"
local ML_LENS_LAYER = LensLayers.HEX_COLORING_APPEAL_LEVEL

-- ===========================================================================
-- Barbarian Lens Support
-- ===========================================================================

local function plotHasBarbCamp(plot)
    local improvementInfo = GameInfo.Improvements[plot:GetImprovementType()];
    if improvementInfo ~= nil and improvementInfo.ImprovementType == "IMPROVEMENT_BARBARIAN_CAMP" then
        return true;
    end
    return false;
end

-- ===========================================================================
-- Exported functions
-- ===========================================================================

local function OnGetColorPlotTable()
    local mapWidth, mapHeight = Map.GetGridSize();
    local localPlayer   :number = Game.GetLocalPlayer();
    local localPlayerVis:table = PlayersVisibility[localPlayer];

    local BarbarianColor = UI.GetColorValue("COLOR_BARBARIAN_BARB_LENS");
    local colorPlot:table = {};
    colorPlot[BarbarianColor] = {}

    for i = 0, (mapWidth * mapHeight) - 1, 1 do
        local pPlot:table = Map.GetPlotByIndex(i);
        if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) and plotHasBarbCamp(pPlot) then
            table.insert(colorPlot[BarbarianColor], i);
        end
    end

    return colorPlot
end

--[[
local function ShowBarbarianLens()
    LuaEvents.MinimapPanel_SetActiveModLens(LENS_NAME)
    UILens.ToggleLayerOn(ML_LENS_LAYER)
end

local function ClearBarbarianLens()
    if UILens.IsLayerOn(ML_LENS_LAYER) then
        UILens.ToggleLayerOff(ML_LENS_LAYER);
    end
    LuaEvents.MinimapPanel_SetActiveModLens("NONE");
end

local function OnInitialize()
    -- Nothing to do
end
]]

local BarbarianLensEntry = {
    LensButtonText = "LOC_HUD_BARBARIAN_LENS",
    LensButtonTooltip = "LOC_HUD_BARBARIAN_LENS_TOOLTIP",
    Initialize = nil,
    GetColorPlotTable = OnGetColorPlotTable
}

-- minimappanel.lua
if g_ModLenses ~= nil then
    g_ModLenses[LENS_NAME] = BarbarianLensEntry
end

-- modallenspanel.lua
if g_ModLensModalPanel ~= nil then
    g_ModLensModalPanel[LENS_NAME] = {}
    g_ModLensModalPanel[LENS_NAME].LensTextKey = "LOC_HUD_BARBARIAN_LENS"
    g_ModLensModalPanel[LENS_NAME].Legend = {
        {"LOC_TOOLTIP_BARBARIAN_LENS_ENCAPMENT", UI.GetColorValue("COLOR_BARBARIAN_BARB_LENS")}
    }
end
