-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_CQUI_View = View;

-- ===========================================================================
-- CQUI Members
-- ===========================================================================

-- ===========================================================================
--  CQUI modified GetDetails functiton
--  Re-arrrange the tooltip informations (https://github.com/CQUI-Org/cqui/issues/232)
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

  local szTerrainString;
  if (data.IsLake) then
    szTerrainString=Locale.Lookup("LOC_TOOLTIP_LAKE");
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
    --table.insert(details, szFeatureString);
  end

  if (data.IsRiver == true) then
    szTerrainString = szTerrainString.."/ "..Locale.Lookup("LOC_TOOLTIP_RIVER");
  end
  table.insert(details, szTerrainString);


  if(data.NationalPark ~= "") then
    table.insert(details, data.NationalPark);
  end

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
        -- Found one!  Now.  Can it be constructed on this terrain/feature
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
          break;
        end
      end
    end
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
  end

  table.insert(details, "------------------");

  --[[
  -- Movement cost
  if (not data.Impassable and data.MovementCost > 0) then
    table.insert(details, Locale.Lookup("LOC_TOOLTIP_MOVEMENT_COST", data.MovementCost));
  end
  ]]

  -- ROUTE TILE - CQUI Modified Doesn't display movement cost if route movement exists
  local szMoveString: string;
  if (data.IsRoute) then
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
    --szMoveString = szMoveString:gsub("%d+%s",": [ICON_Movement]",1);
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

  -- CITY TILE
  if(data.IsCity == true and data.DistrictType ~= nil) then

    table.insert(details, "------------------");

    table.insert(details, Locale.Lookup(GameInfo.Districts[data.DistrictType].Name))

    for yieldType, v in pairs(data.Yields) do
      local yield = GameInfo.Yields[yieldType].Name;
      local yieldicon = GameInfo.Yields[yieldType].IconString;
      local str = tostring(v) .. Locale.Lookup(yieldicon) .. Locale.Lookup(yield);
      table.insert(CQUIYields,1,str);
      --table.insert(details, str);
    end
    for i, v in ipairs(CQUIYields) do
      table.insert(details,v);
    end
    --if(data.Buildings ~= nil and table.count(data.Buildings) > 0) then
    --  table.insert(details, "Buildings: ");

    --  for i, v in ipairs(data.Buildings) do
    --    table.insert(details, "  " .. Locale.Lookup(v));
    --  end
    --end

    --if(data.Constructions ~= nil and table.count(data.Constructions) > 0) then
    --  table.insert(details, "UnderConstruction: ");
    --
    --  for i, v in ipairs(data.Constructions) do
    --    table.insert(details, "  " .. Locale.Lookup(v));
    --  end
    --end

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
      if (data.DistrictYields ~= nil) then
        for yieldType, v in pairs(data.DistrictYields) do
          local yield = GameInfo.Yields[yieldType].Name;
          local yieldicon = GameInfo.Yields[yieldType].IconString;
          local str = tostring(v) .. Locale.Lookup(yieldicon) .. Locale.Lookup(yield);
          table.insert(details, str);
        end
      end
    end

  -- IMPASSABLE TILE
  elseif(data.Impassable == true) then
    table.insert(details, Locale.Lookup("LOC_TOOLTIP_PLOT_IMPASSABLE_TEXT"));

  -- OTHER TILE
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
      --table.insert(details, str);
      end
    end
    for i, v in ipairs(CQUIYields) do
      table.insert(details,v);
    end
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

  return details;
end

-- ===========================================================================
--  CQUI modified View functiton
--  Hide Plotname (https://github.com/CQUI-Org/cqui/issues/232)
-- ===========================================================================
function View(data:table, bIsUpdate:boolean)
  BASE_CQUI_View(data, bIsUpdate);

  Controls.PlotName:SetHide(true)
end

function Initialize()
  Controls.TooltipMain:SetSpeed(8);  -- CQUI : tooltip spawn faster
end
Initialize();