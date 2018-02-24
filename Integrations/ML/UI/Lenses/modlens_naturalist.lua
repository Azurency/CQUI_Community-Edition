include("LensSupport")

local LENS_NAME = "ML_NATURALIST"
local ML_LENS_LAYER = LensLayers.HEX_COLORING_APPEAL_LEVEL

-- ===========================================================================
-- Naturalist Lens Support
-- ===========================================================================

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
-- Exported functions
-- ===========================================================================

local function OnGetColorPlotTable()
  -- Code credit: @pspjuth
  local localPlayer:number = Game.GetLocalPlayer();
  local localPlayerVis:table = PlayersVisibility[localPlayer];
  
  local parkPlotColor:number = UI.GetColorValue("COLOR_PARK_NATURALIST_LENS");
  local OkColor:number = UI.GetColorValue("COLOR_OK_NATURALIST_LENS");
  local FixableColor:number = UI.GetColorValue("COLOR_FIXABLE_NATURALIST_LENS");
  
  local colorPlot = {}
  colorPlot[OkColor] = {}
  colorPlot[FixableColor] = {}
  
  -- Get plots that can be made into National Parks without any changes
  local rawParkPlots:table = Game.GetNationalParks():GetPossibleParkTiles(localPlayer);
  local tiles:table = {};
  
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
        table.insert(colorPlot[OkColor], i)
      elseif tiles[i].Level == 2 then
        -- print("fix", i)
        table.insert(colorPlot[FixableColor], i)
      end
    end
  end
  
  colorPlot[parkPlotColor] = rawParkPlots
  
  return colorPlot
end

--[[
local function ShowNaturalistLens()
  LuaEvents.MinimapPanel_SetActiveModLens(LENS_NAME)
  UILens.ToggleLayerOn(ML_LENS_LAYER)
end

local function ClearNaturalistLens()
  if UILens.IsLayerOn(ML_LENS_LAYER) then
    UILens.ToggleLayerOff(ML_LENS_LAYER);
  end
  LuaEvents.MinimapPanel_SetActiveModLens("NONE");
end

local function OnInitialize()
  -- Nothing to do
end
]]
  
local NaturalistLensEntry = {
  LensButtonText = "LOC_HUD_NATURALIST_LENS",
  LensButtonTooltip = "LOC_HUD_NATURALIST_LENS_TOOLTIP",
  Initialize = nil,
  GetColorPlotTable = OnGetColorPlotTable
}

-- minimappanel.lua
if g_ModLenses ~= nil then
  g_ModLenses[LENS_NAME] = NaturalistLensEntry
end

-- modallenspanel.lua
if g_ModLensModalPanel ~= nil then
  g_ModLensModalPanel[LENS_NAME] = {}
  g_ModLensModalPanel[LENS_NAME].LensTextKey = "LOC_HUD_NATURALIST_LENS"
  g_ModLensModalPanel[LENS_NAME].Legend = {
    {"LOC_TOOLTIP_NATURALIST_LENS_NPARK", UI.GetColorValue("COLOR_PARK_NATURALIST_LENS")},
    {"LOC_TOOLTIP_NATURALIST_LENS_OK", UI.GetColorValue("COLOR_OK_NATURALIST_LENS")},
    {"LOC_TOOLTIP_NATURALIST_LENS_FIXABLE", UI.GetColorValue("COLOR_FIXABLE_NATURALIST_LENS")}
  }
end
  