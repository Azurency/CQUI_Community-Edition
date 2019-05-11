-- ===========================================================================
-- Base File
-- ===========================================================================
include("DistrictPlotIconManager");

function Initialize()
  LuaEvents.CQUI_DistrictPlotIconManager_ClearEveything.Add(ClearEveything);
  LuaEvents.CQUI_Realize2dArtForDistrictPlacement.Add(Realize2dArtForDistrictPlacement);
end
Initialize();