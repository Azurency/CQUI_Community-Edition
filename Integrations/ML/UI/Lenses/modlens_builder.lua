include("LensSupport")

local LENS_NAME = "ML_BUILDER"
local ML_LENS_LAYER = LensLayers.HEX_COLORING_APPEAL_LEVEL

-- Should the builder lens auto apply, when a builder is selected.
local AUTO_APPLY_BUILDER_LENS:boolean = true

-- CQUI
local function CQUI_OnSettingsUpdate()
  AUTO_APPLY_BUILDER_LENS = GameConfiguration.GetValue("CQUI_AutoapplyBuilderLens");
end

-- ===========================================================================
-- Builder Lens Support
-- ===========================================================================

local function isAncientClassicalWonder(wonderTypeID)
  -- print("Checking wonder " .. wonderTypeID .. " if ancient or classical")
  
  for row in GameInfo.Buildings() do
    if row.Index == wonderTypeID then
      -- Make hash, and get era
      if row.PrereqTech ~= nil then
        prereqTechHash = DB.MakeHash(row.PrereqTech);
        eraType = GameInfo.Technologies[prereqTechHash].EraType;
      elseif row.PrereqCivic ~= nil then
        prereqCivicHash = DB.MakeHash(row.PrereqCivic);
        eraType = GameInfo.Civics[prereqCivicHash].EraType;
      else
        -- Wonder has no prereq
        return true;
      end
      
      -- print("Era = " .. eraType);
      
      if eraType == nil then
        -- print("Could not find era for wonder " .. wonderTypeID)
        return true
      elseif eraType == "ERA_ANCIENT" or eraType == "ERA_CLASSICAL" then
        return true;
      end
    end
  end
  
  return false;
end

local function playerCanRemoveFeature(playerID, plotIndex)
  local pPlot = Map.GetPlotByIndex(plotIndex)
  local pPlayer = Players[playerID];
  local featureInfo = GameInfo.Features[pPlot:GetFeatureType()]
  
  if featureInfo ~= nil then
    if not featureInfo.Removable then return false; end
    
    -- Check for remove tech
    if featureInfo.RemoveTech ~= nil then
      local tech = GameInfo.Technologies[featureInfo.RemoveTech]
      local playerTech:table = pPlayer:GetTechs();
      if tech ~= nil  then
        return playerTech:HasTech(tech.Index);
      else
        return false;
      end
    else
      return true;
    end
  end
  
  return false;
end

local function BuilderCanConstruct(improvementInfo)
  for improvementBuildUnits in GameInfo.Improvement_ValidBuildUnits() do
    if improvementBuildUnits ~= nil and improvementBuildUnits.ImprovementType == improvementInfo.ImprovementType and
    improvementBuildUnits.UnitType == "UNIT_BUILDER" then
      return true
    end
  end
  
  return false
end

local function plotCanHaveImprovement(playerID, plotIndex)
  local pPlot = Map.GetPlotByIndex(plotIndex)
  local pPlayer = Players[playerID]
  
  -- Handler for a generic tile
  for improvementInfo in GameInfo.Improvements() do
    if improvementInfo ~= nil and improvementInfo.Buildable then
      
      -- Does the player the prereq techs and civis
      if BuilderCanConstruct(improvementInfo) and playerCanHave(playerID, improvementInfo) then
        local improvementValid:boolean = false;
        
        -- Check for valid feature
        for validFeatureInfo in GameInfo.Improvement_ValidFeatures() do
          if validFeatureInfo ~= nil and validFeatureInfo.ImprovementType == improvementInfo.ImprovementType then
            -- Does this plot have this feature?
            local featureInfo = GameInfo.Features[validFeatureInfo.FeatureType]
            if featureInfo ~= nil and pPlot:GetFeatureType() == featureInfo.Index then
              if playerCanHave(playerID, featureInfo) and playerCanHave(playerID, validFeatureInfo) then
                print("(feature) Plot " .. pPlot:GetIndex() .. " can have " .. improvementInfo.ImprovementType)
                improvementValid = true;
                break;
              end
            end
          end
        end
        
        -- Check for valid terrain
        if not improvementValid then
          for validTerrainInfo in GameInfo.Improvement_ValidTerrains() do
            if validTerrainInfo ~= nil and validTerrainInfo.ImprovementType == improvementInfo.ImprovementType then
              -- Does this plot have this terrain?
              local terrainInfo = GameInfo.Terrains[validTerrainInfo.TerrainType]
              if terrainInfo ~= nil and pPlot:GetTerrainType() == terrainInfo.Index then
                if playerCanHave(playerID, terrainInfo) and playerCanHave(playerID, validTerrainInfo)  then
                  print("(terrain) Plot " .. pPlot:GetIndex() .. " can have " .. improvementInfo.ImprovementType)
                  improvementValid = true;
                  break;
                end
              end
            end
          end
        end
        
        -- Check for valid resource
        if not improvementValid then
          for validResourceInfo in GameInfo.Improvement_ValidResources() do
            if validResourceInfo ~= nil and validResourceInfo.ImprovementType == improvementInfo.ImprovementType then
              -- Does this plot have this terrain?
              local resourceInfo = GameInfo.Resources[validResourceInfo.ResourceType]
              if resourceInfo ~= nil and pPlot:GetResourceType() == resourceInfo.Index then
                if playerCanHave(playerID, resourceInfo) and playerCanHave(playerID, validResourceInfo)  then
                  print("(resource) Plot " .. pPlot:GetIndex() .. " can have " .. improvementInfo.ImprovementType)
                  improvementValid = true;
                  break;
                end
              end
            end
          end
        end
        
        -- Special check for coastal requirement
        if improvementInfo.Coast and (not pPlot:IsCoastalLand()) then
          print(plotIndex .. " plot is not coastal")
          improvementValid = false;
        end
        
        if improvementValid then
          return true
        end
      end
    end
  end
  
  return false;
end

local function plotHasCorrectImprovement(plot)
  local plotIndex = plot:GetIndex()
  local playerID = Game.GetLocalPlayer()
  
  -- If the plot has a resource, and the player has discovered it, get the improvement specific to that
  if playerHasDiscoveredResource(playerID, plotIndex) then
    local resourceInfo = GameInfo.Resources[plot:GetResourceType()]
    if resourceInfo ~= nil then
      local improvementType;
      for validResourceInfo in GameInfo.Improvement_ValidResources() do
        if validResourceInfo ~= nil and validResourceInfo.ResourceType == resourceInfo.ResourceType then
          improvementType = validResourceInfo.ImprovementType;
          if improvementType ~= nil and GameInfo.Improvements[improvementType] ~= nil then
            local improvementID = GameInfo.Improvements[improvementType].RowId - 1;
            if plot:GetImprovementType() == improvementID then
              return true
            end
          end
        end
      end
    end
  else
    -- This plot has either no resource or a undiscovered resource
    -- hence assuming correct resource type
    return true
  end
  return false
end

local function plotHasRemovableFeature(plot)
  local featureInfo = GameInfo.Features[plot:GetFeatureType()];
  if featureInfo ~= nil and featureInfo.Removable then
    return true;
  end
  return false;
end

local function plotHasImprovableHill(plot)
  local terrainInfo = GameInfo.Terrains[plot:GetTerrainType()];
  local improvInfo = GameInfo.Improvements["IMPROVEMENT_MINE"];
  local playerID = Game.GetLocalPlayer()
  
  if (terrainInfo ~= nil and terrainInfo.Hills
  and playerCanHave(playerID, improvInfo)) then
    return true
  end
  return false;
end

local function plotHasImprovableWonder(plot)
  -- List of wonders that can have an improvement on them.
  local permitWonderList = {
    "FEATURE_CLIFFS_DOVER"
  }
  
  local featureInfo = GameInfo.Features[plot:GetFeatureType()];
  if featureInfo ~= nil then
    for i, wonderType in ipairs(permitWonderList) do
      if featureInfo.FeatureType == wonderType then
        return true
      end
    end
  end
  return false
end

local function IsAdjYieldWonder(featureInfo)
  -- List any wonders here that provide yield bonuses, but not mentioned in Features.xml
  local specialWonderList = {
    "FEATURE_TORRES_DEL_PAINE"
  }
  
  if featureInfo ~= nil and featureInfo.NaturalWonder then
    for adjYieldInfo in GameInfo.Feature_AdjacentYields() do
      if adjYieldInfo ~= nil and adjYieldInfo.FeatureType == featureInfo.FeatureType then
        return true
      end
    end
    
    for i, featureType in ipairs(specialWonderList) do
      if featureType == featureInfo.FeatureType then
        return true
      end
    end
  end
  return false
end

local function plotNextToBuffingWonder(plot)
  for pPlot in PlotRingIterator(plot, 1, SECTOR_NONE, DIRECTION_CLOCKWISE) do
    local featureInfo = GameInfo.Features[pPlot:GetFeatureType()]
    if IsAdjYieldWonder(featureInfo) then
      return true
    end
  end
  return false
end

local function plotHasRecomFeature(plot)
  local playerID = Game.GetLocalPlayer()
  local featureInfo = GameInfo.Features[plot:GetFeatureType()]
  local farmImprovInfo = GameInfo.Improvements["IMPROVEMENT_FARM"]
  local lumberImprovInfo = GameInfo.Improvements["IMPROVEMENT_LUMBER_MILL"]
  
  if featureInfo ~= nil then
    
    -- 1. Is it a floodplain?
    if featureInfo.FeatureType == "FEATURE_FLOODPLAINS" and
    playerCanHave(playerID, farmImprovInfo) then
      return true
    end
    
    -- 2. Is it a forest next to a river?
    if featureInfo.FeatureType == "FEATURE_FOREST" and plot:IsRiver() and
    playerCanHave(playerID, lumberImprovInfo) then
      return true
    end
    
    -- 3. Is it a tile next to buffing wonder?
    if plotNextToBuffingWonder(plot) then
      return true
    end
    
    -- 4. Is it wonder, that can have an improvement?
    if plotHasImprovableWonder(plot) then
      if featureInfo.FeatureType == "FEATURE_FOREST" and
      playerCanHave(playerID, lumberImprovInfo) then
        return true
      end
      
      if plotCanHaveFarm(plot) then
        return true
      end
    end
  end
  return false
end

local function playerHasBuilderWonderModifier(playerID)
  return playerHasModifier(playerID, "MODIFIER_PLAYER_ADJUST_UNIT_WONDER_PERCENT");
end

local function playerHasBuilderDistrictModifier(playerID)
  return playerHasModifier(playerID, "MODIFIER_PLAYER_ADJUST_UNIT_DISTRICT_PERCENT");
end

-- ===========================================================================
-- Exported functions
-- ===========================================================================

local function OnGetColorPlotTable()
  -- print("Highlight Builder Lens Hexes")
  local mapWidth, mapHeight = Map.GetGridSize()
  
  local ResourceColor:number = UI.GetColorValue("COLOR_RESOURCE_BUILDER_LENS")
  local HillColor:number = UI.GetColorValue("COLOR_HILL_BUILDER_LENS")
  local RecomFeatureColor:number = UI.GetColorValue("COLOR_RECOMFEATURE_BUILDER_LENS")
  local FeatureColor:number = UI.GetColorValue("COLOR_FEATURE_BUILDER_LENS")
  local GenericColor:number = UI.GetColorValue("COLOR_GENERIC_BUILDER_LENS")
  local NothingColor:number = UI.GetColorValue("COLOR_NOTHING_BUILDER_LENS")
  local localPlayer:number = Game.GetLocalPlayer()
  
  -- Make sure each color has its associated table
  local colorPlot = {};
  colorPlot[ResourceColor] = {}
  colorPlot[HillColor] = {}
  colorPlot[RecomFeatureColor] = {}
  colorPlot[FeatureColor] = {}
  colorPlot[GenericColor] = {}
  colorPlot[NothingColor] = {}
  
  for i = 0, (mapWidth * mapHeight) - 1, 1 do
    local pPlot:table = Map.GetPlotByIndex(i)
    
    if pPlot:GetOwner() == Game.GetLocalPlayer() then
      
      -- IMPASSABLE
      --------------------------------------
      if pPlot:IsImpassable() then
        table.insert(colorPlot[NothingColor], i)
        
      -- NATIONAL PARK
      --------------------------------------
      elseif pPlot:IsNationalPark() then
        table.insert(colorPlot[NothingColor], i)
        
      -- IMPROVEMENTS
      --------------------------------------
      elseif plotHasImprovement(pPlot) then
        if pPlot:IsImprovementPillaged() then
          table.insert(colorPlot[HillColor], i)
        elseif not plotHasCorrectImprovement(pPlot) then
          table.insert(colorPlot[ResourceColor], i)
          -- else
            -- table.insert(colorPlot[NothingColor], i)
          end
          
      -- NATURAL WONDER
      --------------------------------------
      elseif plotHasNaturalWonder(pPlot) then
        if plotHasImprovableWonder(pPlot) then
          table.insert(colorPlot[RecomFeatureColor], i)
        else
          table.insert(colorPlot[NothingColor], i)
        end
        
      -- PLAYER WONDER - CHINESE UA
      --------------------------------------
      elseif plotHasWonder(pPlot) then
        -- Check for a UA similiar to china's
        if playerHasBuilderWonderModifier(localPlayer) and (not pPlot:IsWonderComplete())
        and isAncientClassicalWonder(pPlot:GetWonderType()) then
          table.insert(colorPlot[ResourceColor], i)
        -- else
          -- table.insert(colorPlot[NothingColor], i)
        end
          
      -- DISTRICT - AZTEC UA
      --------------------------------------
      elseif plotHasDistrict(pPlot) then
        -- Check for a UA similiar to Aztec's
        if (not pPlot:IsCity()) and (not districtComplete(localPlayer, i)) and
        playerHasBuilderDistrictModifier(localPlayer) then
          table.insert(colorPlot[ResourceColor], i)
        -- else
          -- table.insert(colorPlot[NothingColor], i)
        end
        
      -- VISIBLE RESOURCE
      --------------------------------------
      elseif plotHasResource(pPlot) and playerHasDiscoveredResource(localPlayer, i) then
        -- Is the resource improvable?
        if plotResourceImprovable(pPlot) then
          table.insert(colorPlot[ResourceColor], i)
        else
          table.insert(colorPlot[NothingColor], i)
        end
        
      -- FEATURE - Note: This includes natural wonders, since wonder is also a "feature". Check Features.xml
      --------------------------------------
      elseif plotHasFeature(pPlot) then
        -- Recommended Feature
        if plotHasRecomFeature(pPlot) then
          table.insert(colorPlot[RecomFeatureColor], i)
          -- Harvestable feature
        elseif playerCanRemoveFeature(localPlayer, i) then
          table.insert(colorPlot[FeatureColor], i)
        else
          table.insert(colorPlot[NothingColor], i)
        end
        
      -- Below this we assume comman tiles that are
      -- only useful if within working range of city
      --------------------------------------
      elseif plotWithinWorkingRange(localPlayer, i)  then
        
        -- HILL - MINE
        --------------------------------------
        if plotHasImprovableHill(pPlot) then
          if plotNextToBuffingWonder(pPlot) then
            table.insert(colorPlot[RecomFeatureColor], i)
          else
            table.insert(colorPlot[HillColor], i)
          end
          
        -- GENERIC TILE
        --------------------------------------
        elseif plotCanHaveImprovement(localPlayer, i) then
          if plotNextToBuffingWonder(pPlot) then
            table.insert(colorPlot[RecomFeatureColor], i)
          --elseif plotCanHaveFarm(plot) then
          else
            table.insert(colorPlot[GenericColor], i)
          end
            
        -- NOTHING TO DO
        --------------------------------------
        else
          table.insert(colorPlot[NothingColor], i)
        end
      end
    end
  end
  
  return colorPlot
end

-- Called when a builder is selected
local function ShowBuilderLens()
  LuaEvents.MinimapPanel_SetActiveModLens(LENS_NAME)
  UILens.ToggleLayerOn(ML_LENS_LAYER)
end

local function ClearBuilderLens()
  -- print("Clearing builder lens")
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
        if unitType == "UNIT_BUILDER" and AUTO_APPLY_BUILDER_LENS then
          ShowBuilderLens();
        end
        -- Deselection
      else
        if unitType == "UNIT_BUILDER" and AUTO_APPLY_BUILDER_LENS then
          ClearBuilderLens();
        end
      end
    end
  end
end

local function OnUnitChargesChanged( playerID: number, unitID : number, newCharges : number, oldCharges : number )
  local localPlayer = Game.GetLocalPlayer()
  if playerID == localPlayer then
    local unitType = GetUnitType(playerID, unitID)
    if unitType and unitType == "UNIT_BUILDER" and AUTO_APPLY_BUILDER_LENS then
      if newCharges == 0 then
        ClearBuilderLens();
      end
    end
  end
end

-- Multiplayer support for simultaneous turn captured builder
local function OnUnitCaptured( currentUnitOwner, unit, owningPlayer, capturingPlayer )
  local localPlayer = Game.GetLocalPlayer()
  if owningPlayer == localPlayer then
    local unitType = GetUnitType(owningPlayer, unitID)
    if unitType and unitType == "UNIT_BUILDER" and AUTO_APPLY_BUILDER_LENS then
      ClearBuilderLens();
    end
  end
end

local function OnUnitRemovedFromMap( playerID: number, unitID : number )
  local localPlayer = Game.GetLocalPlayer()
  local lens = {}
  LuaEvents.MinimapPanel_GetActiveModLens(lens)
  if playerID == localPlayer then
    if lens[1] == LENS_NAME and AUTO_APPLY_BUILDER_LENS then
      ClearBuilderLens();
    end
  end
end

local function OnInitialize()
  Events.UnitSelectionChanged.Add( OnUnitSelectionChanged );
  Events.UnitCaptured.Add( OnUnitCaptured );
  Events.UnitChargesChanged.Add( OnUnitChargesChanged );
  Events.UnitRemovedFromMap.Add( OnUnitRemovedFromMap );

  -- CQUI Handlers
  LuaEvents.CQUI_SettingsUpdate.Add( CQUI_OnSettingsUpdate );
  Events.LoadScreenClose.Add( CQUI_OnSettingsUpdate ); -- Astog: Update settings when load screen close
end

local BuilderLensEntry = {
  LensButtonText = "LOC_HUD_BUILDER_LENS",
  LensButtonTooltip = "LOC_HUD_BUILDER_LENS_TOOLTIP",
  Initialize = OnInitialize,
  GetColorPlotTable = OnGetColorPlotTable
}

-- minimappanel.lua
if g_ModLenses ~= nil then
  g_ModLenses[LENS_NAME] = BuilderLensEntry
end

-- modallenspanel.lua
if g_ModLensModalPanel ~= nil then
  g_ModLensModalPanel[LENS_NAME] = {}
  g_ModLensModalPanel[LENS_NAME].LensTextKey = "LOC_HUD_BUILDER_LENS"
  g_ModLensModalPanel[LENS_NAME].Legend = {
    {"LOC_TOOLTIP_BUILDER_LENS_IMP",        UI.GetColorValue("COLOR_RESOURCE_BUILDER_LENS")},
    {"LOC_TOOLTIP_RECOMFEATURE_LENS_HILL",  UI.GetColorValue("COLOR_RECOMFEATURE_BUILDER_LENS")},
    {"LOC_TOOLTIP_BUILDER_LENS_HILL",       UI.GetColorValue("COLOR_HILL_BUILDER_LENS")},
    {"LOC_TOOLTIP_BUILDER_LENS_FEATURE",    UI.GetColorValue("COLOR_FEATURE_BUILDER_LENS")},
    {"LOC_TOOLTIP_BUILDER_LENS_GENERIC",    UI.GetColorValue("COLOR_GENERIC_BUILDER_LENS")},
    {"LOC_TOOLTIP_BUILDER_LENS_NOTHING",    UI.GetColorValue("COLOR_NOTHING_BUILDER_LENS")}
  }
end
