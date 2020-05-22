-- ===========================================================================
-- Base File
-- ===========================================================================
include("PlotToolTip_Expansion2");

include("plottooltip_CQUI.lua");

-- ===========================================================================
--  CQUI modified GetDetails functiton
--  Re-arrrange the tooltip informations (https://github.com/CQUI-Org/cqui/issues/232)
--  Complete override for Expansion2 to integrate new landscape feature and climate related changes
--  This builds the tool-tip using table.insert as the mechanism for each line
-- ===========================================================================
function GetDetails(data)
  local details = {};

  --Civilization and city ownership line
  if(data.Owner ~= nil) then

    local szOwnerString;

    local pPlayerConfig = PlayerConfigurations[data.Owner];
    if (pPlayerConfig ~= nil) then
      szOwnerString = Locale.Lookup(pPlayerConfig:GetCivilizationShortDescription());
    end

    if (szOwnerString == nil or string.len(szOwnerString) == 0) then
      szOwnerString = Locale.Lookup("LOC_TOOLTIP_PLAYER_ID", data.Owner);
    end

    local pPlayer = Players[data.Owner];
    if(GameConfiguration:IsAnyMultiplayer() and pPlayer:IsHuman()) then
      szOwnerString = szOwnerString .. " (" .. Locale.Lookup(pPlayerConfig:GetPlayerName()) .. ")";
    end

    --CQUI Remove City Owner if it's a city state as civ name is the same as city owner name
    local szOwnerString2 = Locale.Lookup("LOC_TOOLTIP_CITY_OWNER",szOwnerString, data.OwningCityName);
    if (pPlayer:IsMajor() == false) then
      local cutoff1, cutoff2 = string.find(szOwnerString2,"(",1,true);
      szOwnerString2 = string.sub(szOwnerString2,1,cutoff1-1);
    end

    table.insert(details,szOwnerString2);
  end

  -- Next line: the terrain (with feature if it has one)
  local szTerrainString;

  if (data.IsLake) then
    szTerrainString = Locale.Lookup("LOC_TOOLTIP_LAKE");
  else
    szTerrainString = Locale.Lookup(data.TerrainTypeName);
  end

  if(data.FeatureType ~= nil) then
    local szFeatureString = Locale.Lookup(GameInfo.Features[data.FeatureType].Name);
    local localPlayer = Players[Game.GetLocalPlayer()];
    local addCivicName = GameInfo.Features[data.FeatureType].AddCivic;
    
    if (localPlayer ~= nil and addCivicName ~= nil) then
      local civicIndex = GameInfo.Civics[addCivicName].Index;
      if (localPlayer:GetCulture():HasCivic(civicIndex)) then
          local szAdditionalString;
        if (not data.FeatureAdded) then
          szAdditionalString = Locale.Lookup("LOC_TOOLTIP_PLOT_WOODS_OLD_GROWTH");
        else
          szAdditionalString = Locale.Lookup("LOC_TOOLTIP_PLOT_WOODS_SECONDARY");
        end

        szFeatureString = szFeatureString .. " " .. szAdditionalString;
      end
    end

    szTerrainString = szTerrainString.."/ ".. szFeatureString;
  end

  -- If there's a river on this plot, add that info as well
  if (data.IsRiver and data.RiverNames) then
    szTerrainString = szTerrainString.."/ "..Locale.Lookup("LOC_RIVER_TOOLTIP_STRING", data.RiverNames);
  end

  -- Insert the line about the terrain
  table.insert(details, szTerrainString);

  -- Next sets of data are short checks, should be obvious what's happening
  if (data.IsVolcano == true) then
    local szVolcanoString = Locale.Lookup("LOC_VOLCANO_TOOLTIP_STRING", data.VolcanoName);
    if (data.Erupting) then
      szVolcanoString = szVolcanoString .. " " .. Locale.Lookup("LOC_VOLCANO_ERUPTING_STRING");
    elseif (data.Active) then
      szVolcanoString = szVolcanoString .. " " .. Locale.Lookup("LOC_VOLCANO_ACTIVE_STRING");
    end

    table.insert(details, szVolcanoString);
  end

  if (data.TerritoryName ~= nil) then
    table.insert(details, Locale.Lookup(data.TerritoryName));
  end

  if (data.Storm ~= -1) then
    table.insert(details, Locale.Lookup(GameInfo.RandomEvents[data.Storm].Name));
  end

  if (data.Drought ~= -1) then
    table.insert(details, Locale.Lookup("LOC_DROUGHT_TOOLTIP_STRING", GameInfo.RandomEvents[data.Drought].Name, data.DroughtTurns));
  end

  if(data.NationalPark ~= "") then
    table.insert(details, data.NationalPark);
  end

  -- Add Resource Information if there exists one
  if(data.ResourceType ~= nil) then
    --if it's a resource that requires a tech to improve, let the player know that in the tooltip
    local resourceType = data.ResourceType;
    local resource = GameInfo.Resources[resourceType];
    local resourceHash = GameInfo.Resources[resourceType].Hash;
    local resourceColor;

    if (resource.ResourceClassType ~= nil) then
      if (resource.ResourceClassType == "RESOURCECLASS_BONUS") then
        resourceColor = "GoldDark";
      elseif (resource.ResourceClassType == "RESOURCECLASS_LUXURY") then
        resourceColor = "Civ6Purple";
      elseif (resource.ResourceClassType == "RESOURCECLASS_STRATEGIC") then
        resourceColor = "Civ6Red";
      end
    end

    --Color code the resource text if they have a color. For example, antiquity sites don't have a color
    local resourceString;
    if (resourceColor ~= nil) then
      resourceString = "[ICON_"..resourceType.. "] " .. "[COLOR:"..resourceColor.."]"..Locale.Lookup(resource.Name).."[ENDCOLOR]";
    else
      resourceString = "[ICON_"..resourceType.. "] " .. Locale.Lookup(resource.Name);
    end

    local resourceTechType;
    local terrainType = data.TerrainType;
    local featureType = data.FeatureType;
    local valid_feature = false;
    local valid_terrain = false;

    -- Are there any improvements that specifically require this resource?
    for row in GameInfo.Improvement_ValidResources() do
      if (row.ResourceType == resourceType) then
        -- Found one!  Now...can it be constructed on this terrain/feature
        local improvementType = row.ImprovementType;
        local has_feature = false;
        for inner_row in GameInfo.Improvement_ValidFeatures() do
          if(inner_row.ImprovementType == improvementType) then
            has_feature = true;
            if(inner_row.FeatureType == featureType) then
              valid_feature = true;
            end
          end
        end

        valid_feature = not has_feature or valid_feature;
        local has_terrain = false;
        for inner_row in GameInfo.Improvement_ValidTerrains() do
          if(inner_row.ImprovementType == improvementType) then
            has_terrain = true;
            if(inner_row.TerrainType == terrainType) then
              valid_terrain = true;
            end
          end
        end

        valid_terrain = not has_terrain or valid_terrain;

        -- If terrain is coast, then only sea-things are valid... otherwise only land
        if( GameInfo.Terrains[terrainType].TerrainType  == "TERRAIN_COAST") then
          if ("DOMAIN_SEA" == GameInfo.Improvements[improvementType].Domain) then
            valid_terrain = true;
          elseif ("DOMAIN_LAND" == GameInfo.Improvements[improvementType].Domain) then
            valid_terrain = false;
          end
        else
          if ("DOMAIN_SEA" == GameInfo.Improvements[improvementType].Domain) then
            valid_terrain = false;
          elseif ("DOMAIN_LAND" == GameInfo.Improvements[improvementType].Domain) then
            valid_terrain = true;
          end
        end

        if(valid_feature == true and valid_terrain == true) then
          resourceTechType = GameInfo.Improvements[improvementType].PrereqTech;
          break; -- for loop
        end
      end
    end -- for loop

    -- Only show the resource if the player has the acquired the tech to make it visible
    local localPlayer = Players[Game.GetLocalPlayer()];
    if (localPlayer ~= nil) then
      local playerResources = localPlayer:GetResources();
      if(playerResources:IsResourceVisible(resourceHash)) then
        if (resourceTechType ~= nil and valid_feature == true and valid_terrain == true) then
          local playerTechs  = localPlayer:GetTechs();
          local techType = GameInfo.Technologies[resourceTechType];
          if (techType ~= nil and not playerTechs:HasTech(techType.Index)) then
            resourceString = resourceString .. "[COLOR:Civ6Red]  ( " .. Locale.Lookup("LOC_TOOLTIP_REQUIRES") .. " " .. Locale.Lookup(techType.Name) .. ")[ENDCOLOR]";
          end
        end

        table.insert(details, resourceString);
      end
    end
  end -- if ResourceType is not nil

  table.insert(details, "------------------");

  -- ROUTE TILE - CQUI Modified Doesn't display movement cost if route movement exists
  local szMoveString;
  if (data.IsRoute and not data.Impassable) then
    local routeInfo = GameInfo.Routes[data.RouteType];
    if (routeInfo ~= nil and routeInfo.MovementCost ~= nil and routeInfo.Name ~= nil) then
      if(data.RoutePillaged) then
        szMoveString = Locale.Lookup("LOC_TOOLTIP_ROUTE_MOVEMENT_PILLAGED", routeInfo.MovementCost, routeInfo.Name);
      else
        szMoveString = Locale.Lookup("LOC_TOOLTIP_ROUTE_MOVEMENT", routeInfo.MovementCost, routeInfo.Name);
      end

      szMoveString = szMoveString.. "[ICON_Movement]";
    end
  elseif (not data.Impassable and data.MovementCost > 0) then
    szMoveString = Locale.Lookup("LOC_TOOLTIP_MOVEMENT_COST", data.MovementCost).. "[ICON_Movement]";
  end

  if (szMoveString ~=nil) then
    table.insert(details,szMoveString);
  end

  -- Defense modifier
  if (data.DefenseModifier ~= 0) then
    table.insert(details, Locale.Lookup("LOC_TOOLTIP_DEFENSE_MODIFIER", data.DefenseModifier).. "[ICON_STRENGTH]");
  end

  -- Appeal
  local feature = nil;
  if (data.FeatureType ~= nil) then
      feature = GameInfo.Features[data.FeatureType];
  end

  if ((data.FeatureType ~= nil and feature.NaturalWonder) or not data.IsWater) then
    local strAppealDescriptor;
    for row in GameInfo.AppealHousingChanges() do
      local iMinimumValue = row.MinimumValue;
      local szDescription = row.Description;
      if (data.Appeal >= iMinimumValue) then
        strAppealDescriptor = Locale.Lookup(szDescription);
        break;
      end
    end

    if(strAppealDescriptor) then
      table.insert(details, Locale.Lookup("LOC_TOOLTIP_APPEAL", strAppealDescriptor, data.Appeal));
    end
  end

  -- Do not include ('none') continent line unless continent plot. #35955
  if (data.Continent ~= nil) then
    table.insert(details, Locale.Lookup("LOC_TOOLTIP_CONTINENT", GameInfo.Continents[data.Continent].Description));
  end

  -- Conditional display based on tile type

  -- WONDER TILE
  if(data.WonderType ~= nil) then
    table.insert(details, "------------------");
    if (data.WonderComplete == true) then
      table.insert(details, Locale.Lookup(GameInfo.Buildings[data.WonderType].Name));
    else
      table.insert(details, Locale.Lookup(GameInfo.Buildings[data.WonderType].Name) .. " " .. Locale.Lookup("LOC_TOOLTIP_PLOT_CONSTRUCTION_TEXT"));
    end
  end

  --CQUI Use this table to set up a better order of listing the yields... ie Food before Production
  local CQUIYields = {};

  -- Fill in the next set of info based on whether it's a city, district, or other tile
  -- CITY TILE
  if(data.IsCity == true and data.DistrictType ~= nil) then
    table.insert(details, "------------------");
    table.insert(details, Locale.Lookup(GameInfo.Districts[data.DistrictType].Name))

    for yieldType, v in pairs(data.Yields) do
      local yield = GameInfo.Yields[yieldType].Name;
      local yieldicon = GameInfo.Yields[yieldType].IconString;
      local str = tostring(v) .. Locale.Lookup(yieldicon) .. Locale.Lookup(yield);
      table.insert(CQUIYields,1,str);
    end

    for i, v in ipairs(CQUIYields) do
      table.insert(details,v);
    end

    if(data.ResourceType ~= nil and data.DistrictType ~= nil) then
      local localPlayer = Players[Game.GetLocalPlayer()];
      if (localPlayer ~= nil) then
        local playerResources = localPlayer:GetResources();
        if(playerResources:IsResourceVisible(resourceHash)) then
          local resourceTechType = GameInfo.Resources[data.ResourceType].PrereqTech;
          if (resourceTechType ~= nil) then
            local playerTechs   = localPlayer:GetTechs();
            local techType = GameInfo.Technologies[resourceTechType];
            if (techType ~= nil and playerTechs:HasTech(techType.Index)) then
              local kConsumption:table = GameInfo.Resource_Consumption[data.ResourceType];  
              if (kConsumption ~= nil) then
                if (kConsumption.Accumulate) then
                  local iExtraction = kConsumption.ImprovedExtractionRate;
                  if (iExtraction > 0) then
                    local resourceName:string = GameInfo.Resources[data.ResourceType].Name;
                    local resourceIcon:string = "[ICON_" .. data.ResourceType .. "]";
                    table.insert(details, Locale.Lookup("LOC_RESOURCE_ACCUMULATION_EXISTING_IMPROVEMENT", iExtraction, resourceIcon, resourceName));
                  end
                end
              end
            end
          end -- resourceTechType ~= nil

          table.insert(details, resourceString);
        end -- isResourceVisible
      end -- localPlayer ~= nil
    end -- data.ResourceType and data.DistrictType are not nil

  -- DISTRICT TILE
  elseif(data.DistrictID ~= -1 and data.DistrictType ~= nil) then
    if (not GameInfo.Districts[data.DistrictType].InternalOnly) then  --Ignore 'Wonder' districts
      -- Plot yields (ie. from Specialists)
      if (data.Yields ~= nil) then
        if (table.count(data.Yields) > 0) then
          table.insert(details, "------------------");
          table.insert(details, Locale.Lookup("LOC_PEDIA_CONCEPTS_PAGE_CITIES_9_CHAPTER_CONTENT_TITLE")); -- "Specialists", text lock :'()
        end

        for yieldType, v in pairs(data.Yields) do
          local yield = GameInfo.Yields[yieldType].Name;
          local yieldicon = GameInfo.Yields[yieldType].IconString;
          local str = tostring(v) .. Locale.Lookup(yieldicon) .. Locale.Lookup(yield);
          table.insert(details, str);
        end
      end

      -- Inherent district yields
      local sDistrictName :string = Locale.Lookup(Locale.Lookup(GameInfo.Districts[data.DistrictType].Name));
      if (data.DistrictPillaged) then
        sDistrictName = sDistrictName .. " " .. Locale.Lookup("LOC_TOOLTIP_PLOT_PILLAGED_TEXT");
      elseif (not data.DistrictComplete) then
        sDistrictName = sDistrictName .. " " .. Locale.Lookup("LOC_TOOLTIP_PLOT_CONSTRUCTION_TEXT");
      end

      table.insert(details, "------------------");
      table.insert(details, sDistrictName);

      -- List the yields from this district tile
      if (data.DistrictYields ~= nil) then
        for yieldType, v in pairs(data.DistrictYields) do
          local yield = GameInfo.Yields[yieldType].Name;
          local yieldicon = GameInfo.Yields[yieldType].IconString;
          local str = tostring(v) .. Locale.Lookup(yieldicon) .. Locale.Lookup(yield);
          table.insert(details, str);
        end
      end

      -- If there exists a resource under this district tile then show its info (if the player has that tech)
      if(data.ResourceType ~= nil and data.DistrictType ~= nil) then
        local localPlayer = Players[Game.GetLocalPlayer()];
        if (localPlayer ~= nil) then
          local playerResources = localPlayer:GetResources();
          if(playerResources:IsResourceVisible(resourceHash)) then
            local resourceTechType = GameInfo.Resources[data.ResourceType].PrereqTech;
            if (resourceTechType ~= nil) then
              local playerTechs = localPlayer:GetTechs();
              local techType = GameInfo.Technologies[resourceTechType];
              if (techType ~= nil and playerTechs:HasTech(techType.Index)) then
                local kConsumption:table = GameInfo.Resource_Consumption[data.ResourceType];    
                if (kConsumption ~= nil) then
                  if (kConsumption.Accumulate) then
                    local iExtraction = kConsumption.ImprovedExtractionRate;
                    if (iExtraction > 0) then
                      local resourceName:string = GameInfo.Resources[data.ResourceType].Name;
                      local resourceIcon:string = "[ICON_" .. data.ResourceType .. "]";
                      table.insert(details, Locale.Lookup("LOC_RESOURCE_ACCUMULATION_EXISTING_IMPROVEMENT", iExtraction, resourceIcon, resourceName));
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

  -- OTHER TILE (Not city, not district)
  else
    table.insert(details, "------------------");
    if(data.ImprovementType ~= nil) then
      local improvementStr = Locale.Lookup(GameInfo.Improvements[data.ImprovementType].Name);
      if (data.ImprovementPillaged) then
        improvementStr = improvementStr .. " " .. Locale.Lookup("LOC_TOOLTIP_PLOT_PILLAGED_TEXT");
      end
      table.insert(details, improvementStr)
    end

    for yieldType, v in pairs(data.Yields) do
      local yield = GameInfo.Yields[yieldType].Name;
      local yieldicon = GameInfo.Yields[yieldType].IconString;
      local str = tostring(v) .. Locale.Lookup(yieldicon) .. Locale.Lookup(yield);
      if (yieldType == "YIELD_FOOD" or yieldType == "YIELD_PRODUCTION") then
        table.insert(CQUIYields,1,str);
      else
        table.insert(CQUIYields,str);
      end
    end

    -- list the tile yields
    for i, v in ipairs(CQUIYields) do
      table.insert(details,v);
    end

    -- if there's a strategic resource and there's an improvement over it show the per-turn accumulation
    if(data.ResourceType ~= nil and data.ImprovementType ~= nil) then
      local localPlayer = Players[Game.GetLocalPlayer()];

      if (localPlayer ~= nil) then
        local playerResources = localPlayer:GetResources();
        if(playerResources:IsResourceVisible(resourceHash)) then
          local resourceTechType = GameInfo.Resources[data.ResourceType].PrereqTech;
          if (resourceTechType ~= nil) then
            local playerTechs   = localPlayer:GetTechs();
            local techType = GameInfo.Technologies[resourceTechType];
            if (techType ~= nil and playerTechs:HasTech(techType.Index)) then
              local kConsumption:table = GameInfo.Resource_Consumption[data.ResourceType];  
              if (kConsumption ~= nil and kConsumption.Accumulate) then
                local iExtraction = kConsumption.ImprovedExtractionRate;
                if (iExtraction > 0) then
                  local resourceName:string = GameInfo.Resources[data.ResourceType].Name;
                  local resourceIcon:string = "[ICON_" .. data.ResourceType .. "]";
                  table.insert(details, Locale.Lookup("LOC_RESOURCE_ACCUMULATION_EXISTING_IMPROVEMENT", iExtraction, resourceIcon, resourceName));
                end
              end
            end
          end
        end
      end
    end
  end

  -- if tile is impassable, add that line
  if(data.Impassable == true) then
    table.insert(details, Locale.Lookup("LOC_TOOLTIP_PLOT_IMPASSABLE_TEXT"));
  end

  -- NATURAL WONDER TILE
  if(data.FeatureType ~= nil) then
    if(feature.NaturalWonder) then
      table.insert(details, "------------------");
      table.insert(details, Locale.Lookup(feature.Description));
    end
  end

  -- For districts, city center show all building info including Great Works
  -- For wonders, just show Great Work info
  if (data.IsCity or data.WonderType ~= nil or data.DistrictID ~= -1) then
    if(data.BuildingNames ~= nil and table.count(data.BuildingNames) > 0) then
      local cityBuildings = data.OwnerCity:GetBuildings();
      if (data.WonderType == nil) then
        table.insert(details, Locale.Lookup("LOC_TOOLTIP_PLOT_BUILDINGS_TEXT"));
      end

      local greatWorksSection: table = {};
      for i, v in ipairs(data.BuildingNames) do
        if (data.WonderType == nil) then
          if (data.BuildingsPillaged[i]) then
            table.insert(details, "- " .. Locale.Lookup(v) .. " " .. Locale.Lookup("LOC_TOOLTIP_PLOT_PILLAGED_TEXT"));
          else
            table.insert(details, "- " .. Locale.Lookup(v));
          end
        end

        local iSlots = cityBuildings:GetNumGreatWorkSlots(data.BuildingTypes[i]);
        for j = 0, iSlots - 1, 1 do
          local greatWorkIndex:number = cityBuildings:GetGreatWorkInSlot(data.BuildingTypes[i], j);
          if (greatWorkIndex ~= -1) then
            local greatWorkType:number = cityBuildings:GetGreatWorkTypeFromIndex(greatWorkIndex)
            table.insert(greatWorksSection, "  * " .. Locale.Lookup(GameInfo.GreatWorks[greatWorkType].Name));
          end
        end
      end

      if #greatWorksSection > 0 then
        for i, v in ipairs(greatWorksSection) do
          table.insert(details, v);
        end
      end
    end
  end

  -- Show number of civilians working here
  if (data.Owner == Game.GetLocalPlayer() and data.Workers > 0) then
    table.insert(details, Locale.Lookup("LOC_TOOLTIP_PLOT_WORKED_TEXT", data.Workers));
  end

  if (data.Fallout > 0) then
    table.insert(details, Locale.Lookup("LOC_TOOLTIP_PLOT_CONTAMINATED_TEXT", data.Fallout));
  end

  if (data.CoastalLowland ~= -1) then
    local szDetailsText = "";
    if (data.CoastalLowland == 0) then
      szDetailsText = Locale.Lookup("LOC_COASTAL_LOWLAND_1M_NAME");
    elseif (data.CoastalLowland == 1) then
      szDetailsText = Locale.Lookup("LOC_COASTAL_LOWLAND_2M_NAME");
    elseif (data.CoastalLowland == 2) then
      szDetailsText = Locale.Lookup("LOC_COASTAL_LOWLAND_3M_NAME");
    end

    if (data.Submerged) then
      szDetailsText = szDetailsText .. " " .. Locale.Lookup ("LOC_COASTAL_LOWLAND_SUBMERGED");
    elseif (data.Flooded) then
      szDetailsText = szDetailsText .. " " .. Locale.Lookup ("LOC_COASTAL_LOWLAND_FLOODED");
    end

    table.insert(details, szDetailsText);
  end

  return details;
end