-- ===========================================================================
-- World Icon Manager
-- Handles showing world icons (e.g., resources) on the map.
-- May be moved to PlotInfo.lua
-- ===========================================================================

include( "InstanceManager" );
include( "SupportFunctions" );

local KEY_CURRENT_ICON_INFO :string = "currentIcon";
local KEY_PREVIOUS_ICON_INFO :string = "prevIcon";
local KEY_PLOT_INDEX :string = "plotIndex";

local g_InstanceManager :table = InstanceManager:new( "IconSetInstance", "Anchor", Controls.IconContainer );
local g_MapIcons :table = {};
local m_kUntouchedPlots :table = {}; -- Used to prevent multiple calls to mess with animation start for a plot change
local m_isShowResources :boolean = UserConfiguration.ShowMapResources();
local m_isShowRecommendations :boolean = true;

local m_techsThatUnlockResources : table = {};
local m_civicsThatUnlockResources : table = {};
local m_techsThatUnlockImprovements : table = {};

-- Stores a list of plot indexes currently showing improvement recommendations
-- Used to efficiently clear improvement recommendations
local m_RecommendedImprovementPlots :table = {};

-- Stores a list of plot indexes currently showing settlement recommendations
-- Used to efficiently clear settlement recommendations
local m_RecommendedSettlementPlots :table = {};

local CQUI_ResourceIconStyle = 1;

-- ===========================================================================
function GetStartingPlotPlayer( pPlot )
  local x = pPlot:GetX();
  local y = pPlot:GetY();

  for i = 0, GameDefines.MAX_PLAYERS-1 do
    local playerConfig = PlayerConfigurations[i];
    if (playerConfig:IsInUse()) then
      local location = playerConfig:GetStartingPosition();
      if (location.x == x and location.y == y) then
        return i;
      end
    end
  end

  return -1;
end

-- ===========================================================================
-- Animation Callback
-- The new icon state is done fading in, set the texture it on the
-- non-animating control and clear out the animating control.
-- ===========================================================================
function OnEndFade( pInstance:table )
  local pCurrentIconInfo = pInstance[KEY_CURRENT_ICON_INFO];
  if (pCurrentIconInfo ~= nil) then
    local textureOffsetX:number = pCurrentIconInfo.textureOffsetX;
    local textureOffsetY:number = pCurrentIconInfo.textureOffsetY;
    local textureSheet:string = pCurrentIconInfo.textureSheet;
    pInstance.ResourceIcon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
    pInstance.ResourceIcon:SetHide( not m_isShowResources );
    --pInstance.NextResourceIcon:UnloadTexture();
    pInstance.NextResourceIcon:SetHide( true );
    m_kUntouchedPlots[pInstance[KEY_PLOT_INDEX]] = nil;
  end
end

-------------------------------------------------------------------------------
function SetResourceIcon( pInstance:table, pPlot, type, state)
  local resourceInfo = GameInfo.Resources[type];
  if (pPlot and resourceInfo ~= nil) then
    local resourceType:string = resourceInfo.ResourceType;
    local featureType :string;
    local terrainType :string;

    local feature = GameInfo.Features[pPlot:GetFeatureType()];
    if(feature) then
      featureType = feature.FeatureType;
    end

    local terrain = GameInfo.Terrains[pPlot:GetTerrainType()];
    if(terrain) then
      terrainType = terrain.TerrainType;
    end

    local iconName = "ICON_" .. resourceType;
    if (state == RevealedState.REVEALED) then
      iconName = iconName .. "_FOW";
    end
    local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName, 64);
    if (textureSheet ~= nil) then
      pInstance[KEY_PREVIOUS_ICON_INFO] = DeepCopy( pInstance[KEY_CURRENT_ICON_INFO] );
      if pInstance[KEY_PREVIOUS_ICON_INFO] ~= nil then
        pInstance.ResourceIcon:SetTexture( pInstance[KEY_PREVIOUS_ICON_INFO].textureOffsetX, pInstance[KEY_PREVIOUS_ICON_INFO].textureOffsetY, pInstance[KEY_PREVIOUS_ICON_INFO].textureSheet );
        pInstance.ResourceIcon:SetHide( not m_isShowResources );
      else
        pInstance.ResourceIcon:SetHide( true );
      end
      pInstance.NextResourceIcon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
      pInstance.NextResourceIcon:SetHide( false );
      pInstance[KEY_CURRENT_ICON_INFO] = {
        textureOffsetX = textureOffsetX,
        textureOffsetY = textureOffsetY,
        textureSheet = textureSheet
      }
      pInstance.AlphaAnim:SetHide(false);
      pInstance.AlphaAnim:SetToBeginning();
      pInstance.AlphaAnim:Play();

      -- Add some tooltip information about the resource
      local toolTipItems:table = {};
      table.insert(toolTipItems, Locale.Lookup(resourceInfo.Name));
      if (resourceInfo.ResourceClassType == "RESOURCECLASS_BONUS") then
        table.insert(toolTipItems, Locale.Lookup("LOC_TOOLTIP_BONUS_RESOURCE"));
      elseif (resourceInfo.ResourceClassType == "RESOURCECLASS_LUXURY") then
        table.insert(toolTipItems, Locale.Lookup("LOC_TOOLTIP_LUXURY_RESOURCE"));
      elseif (resourceInfo.ResourceClassType == "RESOURCECLASS_STRATEGIC") then
        table.insert(toolTipItems, Locale.Lookup("LOC_TOOLTIP_STRATEGIC_RESOURCE"));
      elseif (resourceInfo.ResourceClassType == "RESOURCECLASS_ARTIFACT") then
        table.insert(toolTipItems, Locale.Lookup("LOC_TOOLTIP_ARTIFACT_RESOURCE"));
        table.insert(toolTipItems, Locale.Lookup("LOC_TOOLTIP_ARTIFACT_RESOURCE_DETAILS"));
      end

      local tValidImprovements:table = {}
      for row in GameInfo.Improvement_ValidResources() do
        if (row.ResourceType == resourceType) then
          if( GameInfo.Terrains[terrainType].TerrainType   == "TERRAIN_COAST") then
            if ("DOMAIN_SEA" == GameInfo.Improvements[ row.ImprovementType].Domain) then
              table.insert(tValidImprovements, row.ImprovementType);
            elseif ("DOMAIN_LAND" == GameInfo.Improvements[ row.ImprovementType].Domain) then
              valid_domain = false;
            end
          else
            if ("DOMAIN_SEA" == GameInfo.Improvements[ row.ImprovementType].Domain) then
              valid_domain = false;
            elseif ("DOMAIN_LAND" == GameInfo.Improvements[ row.ImprovementType].Domain) then
              table.insert(tValidImprovements, row.ImprovementType);
            end
          end
        end
      end

      local resourceTechType;
      local resourceCivicType;
      if (table.count(tValidImprovements) > 0) then
        if (table.count(tValidImprovements) > 1) then
          for i, improvement in ipairs(tValidImprovements) do
            local improvementType = improvement;

            local has_feature = false;
            valid_feature = false;
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
            valid_terrain = false;
            for inner_row in GameInfo.Improvement_ValidTerrains() do
              if(inner_row.ImprovementType == improvementType) then
                has_terrain = true;
                if(inner_row.TerrainType == terrainType) then
                  valid_terrain = true;
                end
              end
            end
            valid_terrain = not has_terrain or valid_terrain;

            if(valid_feature == true and valid_terrain == true) then
              resourceTechType = GameInfo.Improvements[improvementType].PrereqTech;
              resourceCivicType = GameInfo.Improvements[improvementType].PrereqCivic;
              break;
            end
          end
        else
          local improvementType = tValidImprovements[1];
          resourceTechType = GameInfo.Improvements[improvementType].PrereqTech;
          resourceCivicType = GameInfo.Improvements[improvementType].PrereqCivic;
        end
      end

      if (resourceTechType ~= nil) then
        local localPlayer = Players[Game.GetLocalPlayer()];
        if (localPlayer ~= nil) then
          local playerTechs = localPlayer:GetTechs();
          local techType = GameInfo.Technologies[resourceTechType];
          if (techType ~= nil and not playerTechs:HasTech(techType.Index)) then
            table.insert(toolTipItems,"[COLOR:Civ6Red](".. Locale.Lookup("LOC_TOOLTIP_REQUIRES") .. " " .. Locale.Lookup(techType.Name) .. ")[ENDCOLOR]");
          end
        end
      end

      if (resourceCivicType ~= nil) then
        local localPlayer = Players[Game.GetLocalPlayer()];
        if (localPlayer ~= nil) then
          local playerCulture = localPlayer:GetCulture();
          local civicType = GameInfo.Civics[resourceCivicType];
          if (civicType ~= nil and not playerCulture:HasCivic(civicType.Index)) then
            table.insert(toolTipItems,"[COLOR:Civ6Red](".. Locale.Lookup("LOC_TOOLTIP_REQUIRES") .. " " .. Locale.Lookup(civicType.Name) .. ")[ENDCOLOR]");
          end
        end
      end

      table.insert(toolTipItems, resourceString)
      pInstance.ResourceIcon:SetToolTipString(table.concat(toolTipItems, "[NEWLINE]"));

      --CQUI: Improved resource icon dimming/hiding

      if(pPlot:GetOwner() == Game.GetLocalPlayer()) then --Only affects plots we own
        local CQUI_ICON_LOW_OPACITY :number = 0x77ffffff;

        if CQUI_ResourceIconStyle == 0 then
          local white :number = 0xffffffff;
          pInstance.ResourceIcon:SetColor(white);
        elseif CQUI_ResourceIconStyle == 1 then
          if CQUI_IsResourceOptimalImproved(resourceInfo, pPlot) then
            pInstance.ResourceIcon:SetColor(CQUI_ICON_LOW_OPACITY);
          else
            pInstance.ResourceIcon:SetColor(nil);
          end
        elseif CQUI_ResourceIconStyle == 2 then
          if CQUI_IsResourceOptimalImproved(resourceInfo, pPlot) then
            local no_color :number = 0x00ffffff;
            pInstance.ResourceIcon:SetColor(no_color);
          else
            pInstance.ResourceIcon:SetColor(nil);
          end
        end
      end
    end
  end
end

function CQUI_IsResourceOptimalImproved(resourceInfo, pPlot)
  if table.count(resourceInfo.ImprovementCollection) > 0 then
    for _, improvement in ipairs(resourceInfo.ImprovementCollection) do
      local optimalTileImprovement = improvement.ImprovementType; --Represents the tile improvement that utilizes the resource most effectively
      local tileImprovement = GameInfo.Improvements[pPlot:GetImprovementType()]; --Can be nil if there is no tile improvement

      --If the tile improvement isn't nil, find the ImprovementType value
      if (tileImprovement ~= nil) then
        tileImprovement = tileImprovement.ImprovementType;
      end

      if tileImprovement == optimalTileImprovement then
        return true
      end
    end
  end
  return false;
end

-------------------------------------------------------------------------------
function UnloadResourceIconAt(plotIndex)
  local pInstance = g_MapIcons[plotIndex];
  if (pInstance ~= nil) then
    pInstance.NextResourceIcon:UnloadTexture();
    pInstance.NextResourceIcon:SetHide( true );
    pInstance.AlphaAnim:SetHide( true );
    pInstance.ResourceIcon:UnloadTexture();
    pInstance.ResourceIcon:SetHide( true );
  end
end

-------------------------------------------------------------------------------
function UnloadRecommendationIconAt(plotIndex)
  local pInstance = g_MapIcons[plotIndex];
  if (pInstance ~= nil) then
    pInstance.RecommendationIconTexture:UnloadTexture();
    pInstance.RecommendationIcon:SetHide( true );
  end
end

-------------------------------------------------------------------------------
function GetInstanceAt(plotIndex)
  local pInstance = g_MapIcons[plotIndex];
  if (pInstance == nil) then
    pInstance = g_InstanceManager:GetInstance();
    g_MapIcons[plotIndex] = pInstance;
    local worldX, worldY = UI.GridToWorld( plotIndex );
    pInstance.Anchor:SetWorldPositionVal( worldX, worldY-10.0, 0.0 );
    -- Do not unload the texture on the ResourceIcon itself, it may remove the only instance to be animated in.
    pInstance.ResourceIcon:SetHide( true );
    -- Do not show/start the AlphaAnim, it should not run if there is only the recommendation icon in the hex
    pInstance.AlphaAnim:SetHide( true );
    pInstance.RecommendationIconTexture:UnloadTexture();
    pInstance.RecommendationIcon:SetHide( true );
    pInstance.AlphaAnim:RegisterEndCallback( function() OnEndFade(pInstance); end );
    pInstance[KEY_PLOT_INDEX] = plotIndex;
  end
  return pInstance;
end

-------------------------------------------------------------------------------
function GetInstanceAllocatedAt(plotIndex)
  return g_MapIcons[plotIndex];
end

-------------------------------------------------------------------------------
function ReleaseInstanceAt(plotIndex)
  local pInstance = g_MapIcons[plotIndex];
  if (pInstance ~= nil) then
    pInstance.ResourceIcon:UnloadTexture();
    pInstance.RecommendationIconTexture:UnloadTexture();
    g_InstanceManager:ReleaseInstance( pInstance );
    g_MapIcons[plotIndex] = nil;
  end
end

-------------------------------------------------------------------------------
function GetNonEmptyAt(plotIndex, state)

  local eObserverID = Game.GetLocalObserver();
  local pLocalPlayerVis = PlayerVisibilityManager.GetPlayerVisibility(eObserverID);
  if (pLocalPlayerVis ~= nil) then
    local pInstance = nil;

    local pPlot = Map.GetPlotByIndex(plotIndex);
    -- Have a Resource?
    local eResource = pLocalPlayerVis:GetLayerValue(VisibilityLayerTypes.RESOURCES, plotIndex);
    local bHideResource = ( pPlot ~= nil and ( pPlot:GetDistrictType() > 0 or pPlot:IsCity() ) );
    if (eResource ~= nil and eResource ~= -1 and not bHideResource ) then
      pInstance = GetInstanceAt(plotIndex);
      SetResourceIcon(pInstance, pPlot, eResource, state);
    else
      UnloadResourceIconAt(plotIndex);
    end

    if (pPlot) then
      -- Starting plot?
      if pPlot:IsStartingPlot() and WorldBuilder.IsActive() then
        pInstance = GetInstanceAt(plotIndex);
        pInstance.RecommendationIconTexture:SetTexture( IconManager:FindIconAtlas("ICON_UNITOPERATION_FOUND_CITY", 43) );
        local iPlayer = GetStartingPlotPlayer( pPlot );
        if (iPlayer >= 0) then
          pInstance.RecommendationIconText:SetText( tostring(iPlayer) );
          pInstance.RecommendationIconText:SetHide( false );
        else
          pInstance.RecommendationIconText:SetHide( true );
        end
      else
        UnloadRecommendationIconAt(plotIndex);
      end
    end
    return pInstance;
  end
end

-------------------------------------------------------------------------------
function RemoveAll(plotIndex)
  ReleaseInstanceAt(plotIndex);
end

-------------------------------------------------------------------------------
function ChangeToMidFog(plotIndex)
  local pIconSet = GetNonEmptyAt(plotIndex, RevealedState.REVEALED);

  if (pIconSet ~= nil) then
    pIconSet.NextResourceIcon:SetHide( (not m_isShowResources) or (not pIconSet.ResourceIcon:HasTexture()) );
    pIconSet.RecommendationIcon:SetHide( (not m_isShowRecommendations) or (not pIconSet.RecommendationIconTexture:HasTexture()) );
    pIconSet.IconStack:CalculateSize();
    pIconSet.IconStack:ReprocessAnchoring();
  end
end

-------------------------------------------------------------------------------
function ChangeToVisible(plotIndex)

  local pIconSet = GetNonEmptyAt(plotIndex, RevealedState.VISIBLE);

  if (pIconSet ~= nil) then
    pIconSet.NextResourceIcon:SetHide( (not m_isShowResources) or (not pIconSet.ResourceIcon:HasTexture()) );
    pIconSet.RecommendationIcon:SetHide( (not m_isShowRecommendations) or (not pIconSet.RecommendationIconTexture:HasTexture()) );
    pIconSet.IconStack:CalculateSize();
    pIconSet.IconStack:ReprocessAnchoring();
  end
end

-------------------------------------------------------------------------------
function Rebuild()

  local eObserverID = Game.GetLocalObserver();
  local pLocalPlayerVis = PlayerVisibilityManager.GetPlayerVisibility(eObserverID);

  if (pLocalPlayerVis ~= nil) then
    local iCount = Map.GetPlotCount();
    for plotIndex = 0, iCount-1, 1 do

      local visibilityType = pLocalPlayerVis:GetState(plotIndex);
      if (visibilityType == RevealedState.HIDDEN) then
        RemoveAll(plotIndex);
      else
        if (visibilityType == RevealedState.REVEALED) then
          ChangeToMidFog(plotIndex);
        else
          if (visibilityType == RevealedState.VISIBLE) then
            ChangeToVisible(plotIndex);
          end
        end
      end
    end
  end
end

function OnResearchCompleted( player:number, tech:number, isCanceled:boolean)
  if player == Game.GetLocalPlayer() then
    for i, techType in ipairs(m_techsThatUnlockResources) do
      if (techType == GameInfo.Technologies[tech].TechnologyType) then
        Rebuild();
      end
    end

    for i, techType in ipairs(m_techsThatUnlockImprovements) do
      if (techType == GameInfo.Technologies[tech].TechnologyType) then
        Rebuild();
        break;
      end
    end
  end
end

function OnCivicCompleted( player:number, civic:number, isCanceled:boolean)
  if player == Game.GetLocalPlayer() then
    for i, civicType in ipairs(m_civicsThatUnlockResources) do
      if (civicType == GameInfo.Civics[civic].CivicType) then
        Rebuild();
      end
    end
  end
end

-------------------------------------------------------------------------------
function OnResourceVisibilityChanged(x, y, resourceType, visibilityType)

  -- Don't use the 'untouched' version because events this can break depending on the order the events come in.
  local plotIndex:number = GetPlotIndex(x, y);
  if plotIndex == -1 then
    return;
  end

  if (visibilityType == RevealedState.HIDDEN) then
    UnloadResourceIconAt(plotIndex);
  else
    if (visibilityType == RevealedState.REVEALED) then
      ChangeToMidFog(plotIndex);
    else
      if (visibilityType == RevealedState.VISIBLE) then
        ChangeToVisible(plotIndex);
      end
    end
  end
end

function OnResourceRemovedFromMap(x, y, resourceType )
  OnResourceVisibilityChanged(x, y, resourceType, RevealedState.HIDDEN );
end

-------------------------------------------------------------------------------
function OnResourceChanged(x, y, resourceType)

  local eObserverID = Game.GetLocalObserver();
  local pLocalPlayerVis = PlayerVisibilityManager.GetPlayerVisibility(eObserverID);
  if (pLocalPlayerVis ~= nil) then

    local visibilityType = pLocalPlayerVis:GetState(x, y);

    -- Don't use the 'untouched' version because events this can break depending on the order the events come in.
    local plotIndex:number = GetPlotIndex(x, y);
    if plotIndex == -1 then
      return;
    end

    if (visibilityType == RevealedState.HIDDEN) then
      UnloadResourceIconAt(plotIndex);
    else
      if (visibilityType == RevealedState.REVEALED) then
        ChangeToMidFog(plotIndex);
      else
        if (visibilityType == RevealedState.VISIBLE) then
          ChangeToVisible(plotIndex);
        end
      end
    end

  end
end

-------------------------------------------------------------------------------
function OnPlotVisibilityChanged(x, y, visibilityType)

  -- Don't use the 'untouched' version because events this can break depending on the order the events come in.
  local plotIndex:number = GetPlotIndex(x, y);
  if plotIndex == -1 then
    return;
  end

  if (visibilityType == RevealedState.HIDDEN) then
    RemoveAll(plotIndex);
  else
    if (visibilityType == RevealedState.REVEALED) then
      ChangeToMidFog(plotIndex);
    else
      if (visibilityType == RevealedState.VISIBLE) then
        ChangeToVisible(plotIndex);
      end
    end
  end
end

-- ===========================================================================
function OnCityAddedToMap(playerID, cityID, x, y)
  local plotIndex:number = GetPlotIndex(x, y);
  if plotIndex ~= -1 then
    -- This is a bit tricky, but the reason we have to use ReleaseInstanceAt
    -- instead of UnloadResourceIconAt is this callback is called after the
    -- visibility changed callbacks for this tile. The animation to fade from
    -- the FOW icon to the new icon has begun, and once it ends, will become the
    -- current icon. ReleaseInstanceAt clears the icon entirely, so the animation
    -- won't make the icon reappear a second after the city has been founded
    ReleaseInstanceAt(plotIndex);
  end
end

-- ===========================================================================
function OnPlotMarkersChanged(x, y)

  -- The marker for a plot has changed.
  local eObserverID = Game.GetLocalObserver();
  local pLocalPlayerVis = PlayerVisibilityManager.GetPlayerVisibility(eObserverID);
  if (pLocalPlayerVis ~= nil) then

    local visibilityType = pLocalPlayerVis:GetState(x, y);
    local plotIndex :number = GetUntouchPlotIndex(x, y);
    if plotIndex == -1 then
      return;
    end

    if (visibilityType == RevealedState.REVEALED) then
      ChangeToMidFog(plotIndex);
    else
      if (visibilityType == RevealedState.VISIBLE) then
        ChangeToVisible(plotIndex);
      end
    end
  end
end

-- ===========================================================================
-- Returns the plot # for a given set of coordinates or returns -1 if
-- it has already been handed out this turn.
-- ===========================================================================
function GetUntouchPlotIndex(x,y)
  local plotIndex :number = Map.GetPlotIndex(x, y);
  if WorldBuilder.IsActive() then
    return plotIndex;
  else
    local gameTurn :number = Game.GetCurrentGameTurn();
    if m_kUntouchedPlots[plotIndex] == nil or m_kUntouchedPlots[plotIndex] ~= gameTurn then
      m_kUntouchedPlots[plotIndex] = gameTurn;
      return plotIndex;
    end

    return -1;
  end
end

-- ===========================================================================
-- Returns the plot # for a given set of coordinates.
-- ===========================================================================
function GetPlotIndex(x,y)
  local plotIndex :number = Map.GetPlotIndex(x, y);
  return plotIndex;
end

----------------------------------------------------------------
function OnLocalPlayerChanged( eLocalPlayer:number , ePrevLocalPlayer:number )
  ClearImprovementRecommendations();
  for key, pIconSet in pairs(g_MapIcons) do
    if (pIconSet ~= nil) then
      g_InstanceManager:ReleaseInstance( pIconSet );
      g_MapIcons[key] = nil;
    end
  end
  m_kUntouchedPlots = {};
end

----------------------------------------------------------------
function OnUserOptionChanged(eOptionSet, hOptionKey, iNewOptionValue)

  local bChangedValue = UserConfiguration.ShowMapResources();
  if (bChangedValue ~= m_isShowResources) then
    m_isShowResources = bChangedValue;

    for _, pIconSet in pairs(g_MapIcons) do
      pIconSet.ResourceIcon:SetHide( (not m_isShowResources) or (not pIconSet.ResourceIcon:HasTexture()) );
      pIconSet.IconStack:CalculateSize();
      pIconSet.IconStack:ReprocessAnchoring();
    end
  end
end
----------------------------------------------------------------
-- Handle the UI shutting down.
function OnShutdown()
  g_MapIcons = {};
  g_InstanceManager:DestroyInstances();
end

-- ===========================================================================
function OnContextInitialize(bHotload : boolean)
  -- The context just loaded, is it a hotload?
  if (bHotload == true) then
    Rebuild();
  end
end

-- ===========================================================================
function OnBeginWonderReveal()
  ContextPtr:SetHide( true );
end

-- ===========================================================================
function OnEndWonderReveal()
  ContextPtr:SetHide( false );
end

-- ===========================================================================
function ClearImprovementRecommendations()
  -- Hide previous recommendations
  for i,plotIndex in ipairs(m_RecommendedImprovementPlots) do
    local pRecommendedPlotInstance = GetInstanceAt(plotIndex);
    pRecommendedPlotInstance.ImprovementRecommendationBackground:SetHide(true);
  end

  -- Clear table
  m_RecommendedImprovementPlots = {};
end

-- ===========================================================================
function AddImprovementRecommendationsForCity( pCity:table, pSelectedUnit:table )
  do return end;

  local pCityAI:table = pCity:GetCityAI();
  if pCityAI then
    local recommendList:table = pCityAI:GetImprovementRecommendationsForBuilder(pSelectedUnit:GetComponentID());
    for key,value in pairs(recommendList) do
      local pRecommendedPlotInstance = GetInstanceAt(value.ImprovementLocation);

      -- Get improvement info
      local pImprovementInfo:table = GameInfo.Improvements[value.ImprovementHash];

      -- Update icon
      local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(pImprovementInfo.Icon, 38);
      pRecommendedPlotInstance.ImprovementRecommendationIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);

      -- Update tooltip
      pRecommendedPlotInstance.ImprovementRecommendationIcon:SetToolTipString(Locale.Lookup("LOC_TOOLTIP_IMPROVEMENT_RECOMMENDATION", pImprovementInfo.Name));

      -- Show recommendation and add to list for clean up later
      pRecommendedPlotInstance.ImprovementRecommendationBackground:SetHide(false);
      table.insert(m_RecommendedImprovementPlots, value.ImprovementLocation);
    end
  end
end

-- ===========================================================================
function ClearSettlementRecommendations()
  -- Hide previous recommendations
  for i,plotIndex in ipairs(m_RecommendedSettlementPlots) do
    local pRecommendedPlotInstance = GetInstanceAt(plotIndex);
    pRecommendedPlotInstance.ImprovementRecommendationBackground:SetHide(true);
  end

  -- Clear table
  m_RecommendedSettlementPlots = {};
end

-- ===========================================================================
function AddSettlementRecommendations()
  local pLocalPlayer:table = Players[Game.GetLocalPlayer()];
  if pLocalPlayer then
    local pGrandAI:table = pLocalPlayer:GetGrandStrategicAI();
    if pGrandAI then
      local pSettlementRecommendations:table = pGrandAI:GetSettlementRecommendations();
      for key,value in pairs(pSettlementRecommendations) do
        local pRecommendedPlotInstance = GetInstanceAt(value.SettlingLocation);

        -- Update icon
        local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas("ICON_UNITOPERATION_FOUND_CITY", 38);
        pRecommendedPlotInstance.ImprovementRecommendationIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);

        -- Update tooltip
        pRecommendedPlotInstance.ImprovementRecommendationIcon:SetToolTipString(Locale.Lookup("LOC_TOOLTIP_SETTLEMENT_RECOMMENDATION"));

        -- Show recommendation and add to list for clean up later
        pRecommendedPlotInstance.ImprovementRecommendationBackground:SetHide(false);
        table.insert(m_RecommendedSettlementPlots, value.SettlingLocation);
      end
    end
  end
end

-- ===========================================================================
function OnUnitSelectionChanged(player, unitId, locationX, locationY, locationZ, isSelected, isEditable)
  ClearImprovementRecommendations();
  ClearSettlementRecommendations();

  -- Are we a builder?
  local pSelectedUnit:table = UI.GetHeadSelectedUnit();
  if pSelectedUnit then
    if pSelectedUnit:GetBuildCharges() > 0 then
      -- If we're within a city then look for any recommended improvements
      local pPlot = Map.GetPlotIndex(pSelectedUnit:GetX(), pSelectedUnit:GetY());
      local pCity:table = Cities.GetPlotPurchaseCity(pPlot);
      if pCity and pCity:GetOwner() == player then
        AddImprovementRecommendationsForCity(pCity, pSelectedUnit);
      end
    elseif GameInfo.Units[pSelectedUnit:GetUnitType()].FoundCity then
      -- Add settlement recommendations if we're a settler
      AddSettlementRecommendations();
    end
  end
end

-- ===========================================================================
-- register the settings callback
function CQUI_GetSettingsValues()
  CQUI_ResourceIconStyle = GameConfiguration.GetValue("CQUI_ResourceDimmingStyle");
end

function CQUI_OnIconStyleSettingsUpdate()
  CQUI_GetSettingsValues()
  --print("resource icon style global setting: ", CQUI_ResourceIconStyle);
  Rebuild();
end
LuaEvents.CQUI_SettingsUpdate.Add( CQUI_OnIconStyleSettingsUpdate );
LuaEvents.CQUI_SettingsInitialized.Add(CQUI_GetSettingsValues);


-- ===========================================================================
function Initialize()

  ContextPtr:SetInitHandler(OnContextInitialize);
  ContextPtr:SetShutdown( OnShutdown );

  Events.BeginWonderReveal.Add( OnBeginWonderReveal );
  Events.EndWonderReveal.Add( OnEndWonderReveal );
  Events.LocalPlayerChanged.Add(OnLocalPlayerChanged);
  Events.CityAddedToMap.Add(OnCityAddedToMap);
  Events.ResourceVisibilityChanged.Add(OnResourceVisibilityChanged);
  Events.ResourceAddedToMap.Add(OnResourceChanged);
  Events.ResourceRemovedFromMap.Add(OnResourceRemovedFromMap);
  Events.ImprovementAddedToMap.Add( OnResourceChanged );
  Events.PlotVisibilityChanged.Add(OnPlotVisibilityChanged);
  Events.PlotMarkerChanged.Add(OnPlotMarkersChanged);
  Events.UnitSelectionChanged.Add( OnUnitSelectionChanged );
  Events.UserOptionChanged.Add(OnUserOptionChanged);
  Events.ResearchCompleted.Add(OnResearchCompleted);
  Events.CivicCompleted.Add(OnCivicCompleted);

  for row in GameInfo.Resources() do
    if row.PrereqTech ~= nil then
      table.insert(m_techsThatUnlockResources, row.PrereqTech);
    end
    if row.PrereqCivic~= nil then
      table.insert(m_civicsThatUnlockResources, row.PrereqCivic);
    end
  end

  for row in GameInfo.Improvements() do
    if (row.PrereqTech ~= nil) then
      table.insert(m_techsThatUnlockImprovements, row.PrereqTech);
    end
  end

end
Initialize();

