local LENS_NAME = "CQUI_CITIZEN_MANAGEMENT"
local ML_LENS_LAYER = UILens.CreateLensLayerHash("Hex_Coloring_Appeal_Level")

local m_cityID :number = -1;

-- ===========================================================================
-- Exported functions
-- ===========================================================================

function OnGetColorPlotTable()
  local playerID:number = Game.GetLocalPlayer();
  local pCity:table = Players[playerID]:GetCities():FindID(m_cityID);
  local colorPlot:table = {};

  if pCity ~= nil then
    --print("Show citizens for " .. Locale.Lookup(pCity:GetName()));

    local tParameters:table = {};
    local cityPlotID = Map.GetPlot(pCity:GetX(), pCity:GetY()):GetIndex();
    tParameters[CityCommandTypes.PARAM_MANAGE_CITIZEN] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_MANAGE_CITIZEN);

    local workingColor:number = UI.GetColorValue("COLOR_CITY_PLOT_WORKING");
    local lockedColor:number = UI.GetColorValue("COLOR_CITY_PLOT_LOCKED");
    colorPlot[workingColor] = {};
    colorPlot[lockedColor] = {};

    -- Get city plot and citizens info
    local tResults:table = CityManager.GetCommandTargets(pCity, CityCommandTypes.MANAGE, tParameters);
    if tResults == nil then
      print("ERROR : Could not find plots");
      return;
    end

    local tPlots:table = tResults[CityCommandResults.PLOTS];
    local tUnits:table = tResults[CityCommandResults.CITIZENS];
    local tLockedUnits:table = tResults[CityCommandResults.LOCKED_CITIZENS];

    if tPlots ~= nil and table.count(tPlots) > 0 then
      for i, plotID in ipairs(tPlots) do
        if (tLockedUnits[i] > 0 or cityPlotID == plotID) then
          table.insert(colorPlot[lockedColor], plotID);
        elseif (tUnits[i] > 0) then
          table.insert(colorPlot[workingColor], plotID);
        end
      end
    end

    -- Next culture expansion plot, show it only if not in city panel
    if UI.GetHeadSelectedCity() == nil then
      local pCityCulture:table  = pCity:GetCulture();
      local culturePlotColor:number = UI.GetColorValue(0.890, 0.431, 0.862);
      if pCityCulture ~= nil then
        local pNextPlotID:number = pCityCulture:GetNextPlot();
        if pNextPlotID ~= nil and Map.IsPlot(pNextPlotID) then
          colorPlot[culturePlotColor] = {pNextPlotID};
        end
      end
    end
  end
  
  return colorPlot;
end

-- ===========================================================================
function ShowCitizenManagementLens(cityID:number)
  m_cityID = cityID;
  LuaEvents.MinimapPanel_SetActiveModLens(LENS_NAME);
  UILens.ToggleLayerOn(ML_LENS_LAYER);
end

-- ===========================================================================
function ClearCitizenManagementLens()
  if UILens.IsLayerOn(ML_LENS_LAYER) then
    UILens.ToggleLayerOff(ML_LENS_LAYER);
  end
  LuaEvents.MinimapPanel_SetActiveModLens("NONE");
  m_cityID = -1;
end

-- ===========================================================================
function RefreshCitizenManagementLens(cityID:number)
  ClearCitizenManagementLens();
  ShowCitizenManagementLens(cityID);
end

local function OnInitialize()
  -- CQUI Handlers
  LuaEvents.CQUI_ShowCitizenManagement.Add( ShowCitizenManagementLens );
  LuaEvents.CQUI_RefreshCitizenManagement.Add( RefreshCitizenManagementLens );
  LuaEvents.CQUI_ClearCitizenManagement.Add( ClearCitizenManagementLens );
end

local CitizenManagementEntry = {
  Initialize = OnInitialize,
  GetColorPlotTable = OnGetColorPlotTable
}

-- minimappanel.lua
if g_ModLenses ~= nil then
  g_ModLenses[LENS_NAME] = CitizenManagementEntry
end