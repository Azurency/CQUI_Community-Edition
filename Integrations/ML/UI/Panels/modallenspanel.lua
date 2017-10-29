-- Provides info about currently active Modal Lens

include( "InstanceManager" );
include( "Civ6Common");

-- Similiar to MinimapPanel.lua to control modded lenses
-- Used to control ModalLensPanel.lua
local MODDED_LENS_ID:table = {
  NONE = 0;
  APPEAL = 1;
  BUILDER = 2;
  ARCHAEOLOGIST = 3;
  BARBARIAN = 4;
  CITY_OVERLAP = 5;
  RESOURCE = 6;
  WONDER = 7;
  ADJACENCY_YIELD = 8;
  SCOUT = 9;
  NATURALIST = 10;
  CUSTOM = 11;
};

-- Different from above, since it uses a government lens, instead of appeal
local AREA_LENS_ID:table = {
  NONE = 0;
  GOVERNMENT = 1;
  CITIZEN_MANAGEMENT = 2;
}

local m_KeyStackIM:table = InstanceManager:new( "KeyEntry", "KeyColorImage", Controls.KeyStack );
local m_ContinentColorList:table = {};
local m_CurrentModdedLensOn = MODDED_LENS_ID.NONE;
local m_CurrentAreaLensOn = AREA_LENS_ID.NONE;

--============================================================================
function Close()
  --ContextPtr:SetHide(true);
  UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
end

--============================================================================
function ShowAppealLensKey()
  m_KeyStackIM: ResetInstances();

  -- Breathtaking
  AddKeyEntry("LOC_TOOLTIP_APPEAL_BREATHTAKING", UI.GetColorValue("COLOR_BREATHTAKING_APPEAL"));

  -- Charming
  AddKeyEntry("LOC_TOOLTIP_APPEAL_CHARMING", UI.GetColorValue("COLOR_CHARMING_APPEAL"));

  -- Average
  AddKeyEntry("LOC_TOOLTIP_APPEAL_AVERAGE", UI.GetColorValue("COLOR_AVERAGE_APPEAL"));

  -- Uninviting
  AddKeyEntry("LOC_TOOLTIP_APPEAL_UNINVITING", UI.GetColorValue("COLOR_UNINVITING_APPEAL"));

  -- Disgusting
  AddKeyEntry("LOC_TOOLTIP_APPEAL_DISGUSTING", UI.GetColorValue("COLOR_DISGUSTING_APPEAL"));

  Controls.KeyPanel:SetHide(false);
  Controls.KeyScrollPanel:CalculateSize();
end

--============================================================================
function ShowBuilderLensKey()
  m_KeyStackIM: ResetInstances();

  AddKeyEntry("LOC_TOOLTIP_BUILDER_LENS_IMP", UI.GetColorValue("COLOR_RESOURCE_BUILDER_LENS"));

  AddKeyEntry("LOC_TOOLTIP_RECOMFEATURE_LENS_HILL", UI.GetColorValue("COLOR_RECOMFEATURE_BUILDER_LENS"));

  AddKeyEntry("LOC_TOOLTIP_BUILDER_LENS_HILL", UI.GetColorValue("COLOR_HILL_BUILDER_LENS"));

  AddKeyEntry("LOC_TOOLTIP_BUILDER_LENS_FEATURE", UI.GetColorValue("COLOR_FEATURE_BUILDER_LENS"));

  AddKeyEntry("LOC_TOOLTIP_BUILDER_LENS_GENERIC", UI.GetColorValue("COLOR_GENERIC_BUILDER_LENS"));

  AddKeyEntry("LOC_TOOLTIP_BUILDER_LENS_NOTHING", UI.GetColorValue("COLOR_NOTHING_BUILDER_LENS"));

  Controls.KeyPanel:SetHide(false);
  Controls.KeyScrollPanel:CalculateSize();
end

--============================================================================
function ShowArchaeologistLensKey()
  m_KeyStackIM: ResetInstances();

  -- Antiquity
  AddKeyEntry("LOC_TOOLTIP_ARCHAEOLOGIST_LENS_ARTIFACT", UI.GetColorValue("COLOR_ARTIFACT_ARCH_LENS"));

  -- Shipwreck
  AddKeyEntry("LOC_TOOLTIP_ARCHAEOLOGIST_LENS_SHIPWRECK", UI.GetColorValue("COLOR_SHIPWRECK_ARCH_LENS"));

  Controls.KeyPanel:SetHide(false);
  Controls.KeyScrollPanel:CalculateSize();
end

--============================================================================
function ShowSettlerLensKey()
  m_KeyStackIM: ResetInstances();

  -- Fresh Water
  local FreshWaterBonus:number = GlobalParameters.CITY_POPULATION_RIVER_LAKE - GlobalParameters.CITY_POPULATION_NO_WATER;
  AddKeyEntry("LOC_HUD_UNIT_PANEL_TOOLTIP_FRESH_WATER", UI.GetColorValue("COLOR_BREATHTAKING_APPEAL"), "ICON_HOUSING", "+" .. tostring(FreshWaterBonus));

  -- Coastal Water
  local CoastalWaterBonus:number = GlobalParameters.CITY_POPULATION_COAST - GlobalParameters.CITY_POPULATION_NO_WATER;
  AddKeyEntry("LOC_HUD_UNIT_PANEL_TOOLTIP_COASTAL_WATER", UI.GetColorValue("COLOR_CHARMING_APPEAL"), "ICON_HOUSING", "+" .. tostring(CoastalWaterBonus));

  -- No Water
  AddKeyEntry("LOC_HUD_UNIT_PANEL_TOOLTIP_NO_WATER", UI.GetColorValue("COLOR_AVERAGE_APPEAL"));

  -- Too Close To City
  AddKeyEntry("LOC_HUD_UNIT_PANEL_TOOLTIP_TOO_CLOSE_TO_CITY", UI.GetColorValue("COLOR_DISGUSTING_APPEAL"));

  Controls.KeyPanel:SetHide(false);
  Controls.KeyScrollPanel:CalculateSize();
end

--============================================================================
function ShowReligionLensKey()
  m_KeyStackIM:ResetInstances();

  -- Track which types we've added so we don't add duplicates
  local visibleTypes:table = {};
  local visibleTypesCount:number = 0;

  local numFoundedReligions   :number = 0;
  local pAllReligions         :table = Game.GetReligion():GetReligions();

  for _, religionInfo in ipairs(pAllReligions) do
    local religionType:number = religionInfo.Religion;
    religionData = GameInfo.Religions[religionType];
    if(religionData.Pantheon == false and Game.GetReligion():HasBeenFounded(religionType)) then
      -- Add key entry
      AddKeyEntry(Game.GetReligion():GetName(religionType), UI.GetColorValue(religionData.Color));
      visibleTypesCount = visibleTypesCount + 1;

    end
  end

  if visibleTypesCount > 0 then
    Controls.KeyPanel:SetHide(false);
    Controls.KeyScrollPanel:CalculateSize();
  else
    Controls.KeyPanel:SetHide(true);
  end
end

--============================================================================
function ShowGovernmentLensKey()
  m_KeyStackIM:ResetInstances();

  -- Track which types we've added so we don't add duplicates
  local visibleTypes:table = {};
  local visibleTypesCount:number = 0;

  local localPlayer = Players[Game.GetLocalPlayer()];
  local playerDiplomacy:table = localPlayer:GetDiplomacy();
  if playerDiplomacy then
    local players = Game.GetPlayers();
    for i, player in ipairs(players) do
      -- Only show goverments for players we've met (and ourselves)
      local visiblePlayer = (player == localPlayer) or playerDiplomacy:HasMet(player:GetID());
      if visiblePlayer then
        local culture = player:GetCulture();
        local governmentIndex = culture:GetCurrentGovernment();
        local government = GameInfo.Governments[governmentIndex];
        if government and visibleTypes[governmentIndex] ~= true then
          -- Get government color
          local colorString:string = "COLOR_" .. government.GovernmentType;

          -- Add key entry
          AddKeyEntry(government.Name, UI.GetColorValue(colorString));

          visibleTypes[governmentIndex] = true;
          visibleTypesCount = visibleTypesCount + 1;
        end
      end
    end
  end

  if visibleTypesCount > 0 then
    Controls.KeyPanel:SetHide(false);
    Controls.KeyScrollPanel:CalculateSize();
  else
    Controls.KeyPanel:SetHide(true);
  end
end

--============================================================================
function ShowPoliticalLensKey()
  m_KeyStackIM:ResetInstances();

  local hasAddedCityStateEntry = false;
  local localPlayer = Players[Game.GetLocalPlayer()];
  local playerDiplomacy:table = localPlayer:GetDiplomacy();
  if playerDiplomacy then
    local players = Game.GetPlayers();
    for i, player in ipairs(players) do
      -- Only show civilizations for players we've met
      if playerDiplomacy:HasMet(player:GetID()) and not player:IsBarbarian() then
        local primaryColor, secondaryColor = UI.GetPlayerColors( player:GetID() );
        local playerConfig:table = PlayerConfigurations[player:GetID()];

        if player:IsMajor() then
          -- Add key entry for civilization
          AddKeyEntry(playerConfig:GetPlayerName(), primaryColor);
        elseif hasAddedCityStateEntry == false then -- Only city states can receive influence
          -- Combine all city states into one generic city state entry
          -- Add key entry for city states
          AddKeyEntry("LOC_CITY_STATES_TITLE", primaryColor);

          hasAddedCityStateEntry = true;
        end
      end
    end
  end

  Controls.KeyPanel:SetHide(false);
  Controls.KeyScrollPanel:CalculateSize();
end

--============================================================================
function ShowCityOverlapLensKey()
  m_KeyStackIM: ResetInstances();

  for i = 1, 8 do
    local s = ""

    s = s .. "Cities "

    s = s .. tostring(i);

    if i == 1 then
      s = s .. "-"
    elseif i == 8 then
      s = s .. "+"
    end

    local colorLookup:string = "COLOR_GRADIENT8_" .. tostring(i);
    -- print(colorLookup);
    local color:number = UI.GetColorValue(colorLookup);
    AddKeyEntryAlt(s, color);
  end

  Controls.KeyPanel:SetHide(false);
  Controls.KeyScrollPanel:CalculateSize();
end

--============================================================================
function ShowBarbarianLensKey()
  m_KeyStackIM: ResetInstances();

  local barbColor = UI.GetColorValue("COLOR_BARBARIAN_BARB_LENS");
  AddKeyEntry("LOC_TOOLTIP_BARBARIAN_LENS_ENCAPMENT", barbColor);

  Controls.KeyPanel:SetHide(false);
  Controls.KeyScrollPanel:CalculateSize();
end

--============================================================================
function ShowResourceLensKey()
  m_KeyStackIM: ResetInstances();

  local LuxConnectedColor     :number = UI.GetColorValue("COLOR_LUXCONNECTED_RES_LENS");
  AddKeyEntry("LOC_TOOLTIP_RESOURCE_LENS_LUXURY", LuxConnectedColor);

  local LuxNConnectedColor    :number = UI.GetColorValue("COLOR_LUXNCONNECTED_RES_LENS");
  AddKeyEntry("LOC_TOOLTIP_RESOURCE_LENS_NLUXURY", LuxNConnectedColor);

  local BonusConnectedColor   :number = UI.GetColorValue("COLOR_BONUSCONNECTED_RES_LENS");
  AddKeyEntry("LOC_TOOLTIP_RESOURCE_LENS_BONUS", BonusConnectedColor);

  local BonusNConnectedColor  :number = UI.GetColorValue("COLOR_BONUSNCONNECTED_RES_LENS");
  AddKeyEntry("LOC_TOOLTIP_RESOURCE_LENS_NBONUS", BonusNConnectedColor);

  local StratConnectedColor   :number = UI.GetColorValue("COLOR_STRATCONNECTED_RES_LENS");
  AddKeyEntry("LOC_TOOLTIP_RESOURCE_LENS_STRATEGIC", StratConnectedColor);

  local StratNConnectedColor  :number = UI.GetColorValue("COLOR_STRATNCONNECTED_RES_LENS");
  AddKeyEntry("LOC_TOOLTIP_RESOURCE_LENS_NSTRATEGIC", StratNConnectedColor);

  Controls.KeyPanel:SetHide(false);
  Controls.KeyScrollPanel:CalculateSize();
end

--============================================================================
function ShowWonderLensKey()
  m_KeyStackIM: ResetInstances();

  local NaturalWonderColor    :number = UI.GetColorValue("COLOR_NATURAL_WONDER_LENS");
  AddKeyEntry("LOC_TOOLTIP_WONDER_LENS_NWONDER", NaturalWonderColor);

  local PlayerWonderColor     :number = UI.GetColorValue("COLOR_PLAYER_WONDER_LENS");
  AddKeyEntry("LOC_TOOLTIP_RESOURCE_LENS_PWONDER", PlayerWonderColor);

  Controls.KeyPanel:SetHide(false);
  Controls.KeyScrollPanel:CalculateSize();
end

--============================================================================
function ShowAdjacencyYieldLensKey()
  m_KeyStackIM: ResetInstances();

  for i = 1, 8 do
    local s = ""
    s = s .. "Yield "
    s = s .. tostring(i-1);

    if i == 8 then
      s = s .. " +"
    end

    local colorLookup:string = "COLOR_GRADIENT8_" .. tostring(i);
    -- print(colorLookup);
    local color:number = UI.GetColorValue(colorLookup);
    AddKeyEntryAlt(s, color);
  end

  Controls.KeyPanel:SetHide(false);
  Controls.KeyScrollPanel:CalculateSize();
end

--============================================================================
function ShowScoutLensKey()
  m_KeyStackIM: ResetInstances();

  local GoodyHutColor     :number = UI.GetColorValue("COLOR_GHUT_SCOUT_LENS");
  AddKeyEntry("LOC_TOOLTIP_SCOUT_LENS_GHUT", GoodyHutColor);

  Controls.KeyPanel:SetHide(false);
  Controls.KeyScrollPanel:CalculateSize();
end

--============================================================================
function ShowNaturalistLensKey()
  m_KeyStackIM: ResetInstances();

  local parkNaturalistLens     :number = UI.GetColorValue("COLOR_PARK_NATURALIST_LENS");
  AddKeyEntry("LOC_TOOLTIP_NATURALIST_LENS_NPARK", parkNaturalistLens);
  AddKeyEntry("LOC_TOOLTIP_NATURALIST_LENS_OK", UI.GetColorValue("COLOR_OK_NATURALIST_LENS"));
  AddKeyEntry("LOC_TOOLTIP_NATURALIST_LENS_FIXABLE", UI.GetColorValue("COLOR_FIXABLE_NATURALIST_LENS"));

  Controls.KeyPanel:SetHide(false);
  Controls.KeyScrollPanel:CalculateSize();
end

--============================================================================
function OnAddContinentColorPair( pContinentColors:table )
  m_ContinentColorList = pContinentColors;
end

--============================================================================
function ShowContinentLensKey()
  m_KeyStackIM: ResetInstances();

  for ContinentID,ColorValue in pairs(m_ContinentColorList) do
    local visibleContinentPlots:table = Map.GetVisibleContinentPlots(ContinentID);
    if(table.count(visibleContinentPlots) > 0) then
      local ContinentName =  GameInfo.Continents[ContinentID].Description;
      AddKeyEntry( ContinentName, ColorValue);
    end
  end

  Controls.KeyPanel:SetHide(false);
  Controls.KeyScrollPanel:CalculateSize();
end

-- ===========================================================================
function AddKeyEntry(textString:string, colorValue:number, bonusIcon:string, bonusValue:string)
  local keyEntryInstance:table = m_KeyStackIM:GetInstance();

  -- Update key text
  keyEntryInstance.KeyLabel:SetText(Locale.Lookup(textString));

  -- Update key color
  keyEntryInstance.KeyColorImage:SetColor(colorValue);

  -- If bonus icon or bonus value show the bonus stack
  if bonusIcon or bonusValue then
    keyEntryInstance.KeyBonusStack:SetHide(false);

    -- Show bonus icon if passed in
    if bonusIcon then
      keyEntryInstance.KeyBonusImage:SetHide(false);
      keyEntryInstance.KeyBonusImage:SetIcon(bonusIcon, 16);
    else
      keyEntryInstance.KeyBonusImage:SetHide(true);
    end

    -- Show bonus value if passed in
    if bonusValue then
      keyEntryInstance.KeyBonusLabel:SetHide(false);
      keyEntryInstance.KeyBonusLabel:SetText(bonusValue);
    else
      keyEntryInstance.KeyBonusLabel:SetHide(true);
    end

    keyEntryInstance.KeyBonusStack:CalculateSize();
  else
    keyEntryInstance.KeyBonusStack:SetHide(true);
  end

  keyEntryInstance.KeyInfoStack:CalculateSize();
  keyEntryInstance.KeyInfoStack:ReprocessAnchoring();
end

-- ===========================================================================
function AddKeyEntryAlt(textString:string, colorValue:number, bonusIcon:string, bonusValue:string)
  local keyEntryInstance:table = m_KeyStackIM:GetInstance();

  -- Update key text
  keyEntryInstance.KeyLabel:SetText(textString);

  -- Update key color
  keyEntryInstance.KeyColorImage:SetColor(colorValue);

  -- If bonus icon or bonus value show the bonus stack
  if bonusIcon or bonusValue then
    keyEntryInstance.KeyBonusStack:SetHide(false);

    -- Show bonus icon if passed in
    if bonusIcon then
      keyEntryInstance.KeyBonusImage:SetHide(false);
      keyEntryInstance.KeyBonusImage:SetIcon(bonusIcon, 16);
    else
      keyEntryInstance.KeyBonusImage:SetHide(true);
    end

    -- Show bonus value if passed in
    if bonusValue then
      keyEntryInstance.KeyBonusLabel:SetHide(false);
      keyEntryInstance.KeyBonusLabel:SetText(bonusValue);
    else
      keyEntryInstance.KeyBonusLabel:SetHide(true);
    end

    keyEntryInstance.KeyBonusStack:CalculateSize();
  else
    keyEntryInstance.KeyBonusStack:SetHide(true);
  end

  keyEntryInstance.KeyInfoStack:CalculateSize();
  keyEntryInstance.KeyInfoStack:ReprocessAnchoring();
end

-- ===========================================================================
function OnLensLayerOn( layerNum:number )
  if layerNum == LensLayers.HEX_COLORING_RELIGION then
    Controls.LensText:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_RELIGION_LENS")));
    ShowReligionLensKey();
  elseif layerNum == LensLayers.HEX_COLORING_CONTINENT then
    Controls.LensText:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_CONTINENT_LENS")));
    Controls.KeyPanel:SetHide(true);
    ShowContinentLensKey();
  elseif layerNum == LensLayers.HEX_COLORING_APPEAL_LEVEL then
    -- print("Modded Lens on " .. m_CurrentModdedLensOn);
    if m_CurrentModdedLensOn == MODDED_LENS_ID.APPEAL then
      Controls.LensText:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_APPEAL_LENS")));
      ShowAppealLensKey();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.BUILDER then
      Controls.LensText:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_BUILDER_LENS")));
      ShowBuilderLensKey();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.ARCHAEOLOGIST then
      Controls.LensText:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_ARCHAEOLOGIST_LENS")));
      ShowArchaeologistLensKey();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.CITY_OVERLAP then
      Controls.LensText:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_CITYOVERLAP_LENS")));
      ShowCityOverlapLensKey();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.BARBARIAN then
      Controls.LensText:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_BARBARIAN_LENS")));
      ShowBarbarianLensKey();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.RESOURCE then
      Controls.LensText:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_RESOURCE_LENS")));
      ShowResourceLensKey();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.WONDER then
      Controls.LensText:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_WONDER_LENS")));
      ShowWonderLensKey();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.ADJACENCY_YIELD then
      Controls.LensText:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_ADJYIELD_LENS")));
      ShowAdjacencyYieldLensKey();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.SCOUT then
      Controls.LensText:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_SCOUT_LENS")));
      ShowScoutLensKey();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.NATURALIST then
      Controls.LensText:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_NATURALIST_LENS")));
      ShowNaturalistLensKey();
    elseif m_CurrentModdedLensOn == MODDED_LENS_ID.CUSTOM then
      print_debug("Hiding")
      ContextPtr:SetHide(true);   -- Hide the Modal Panel if custom
    end
  elseif layerNum == LensLayers.HEX_COLORING_GOVERNMENT then
    if m_CurrentAreaLensOn == AREA_LENS_ID.GOVERNMENT then
      Controls.LensText:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_GOVERNMENT_LENS")));
      ShowGovernmentLensKey();
    -- else
      -- Add extra area lenses here
    end
  elseif layerNum == LensLayers.HEX_COLORING_OWING_CIV then
    Controls.LensText:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_OWNER_LENS")));
    ShowPoliticalLensKey();
  elseif layerNum == LensLayers.HEX_COLORING_WATER_AVAILABLITY then
    Controls.LensText:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_WATER_LENS")));
    ShowSettlerLensKey();
  elseif layerNum == LensLayers.TOURIST_TOKENS then
    Controls.LensText:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_TOURISM_LENS")));
    Controls.KeyPanel:SetHide(true);
  end
end

-- ===========================================================================
-- Called from MinimapPanel.lua
function OnModdedLensOn(lensID)
  print_debug("Current modded lens on " .. lensID);
  m_CurrentModdedLensOn = lensID;
end

function OnAreaLensOn(lensID)
  print_debug("Current area lens on " .. lensID);
  m_CurrentAreaLensOn = lensID;
end

-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnInterfaceModeChanged(eOldMode:number, eNewMode:number)
  if eNewMode == InterfaceModeTypes.VIEW_MODAL_LENS then
    ContextPtr:SetHide(false);
  end
  if eOldMode == InterfaceModeTypes.VIEW_MODAL_LENS then
    ContextPtr:SetHide(true);
  end
end

-- ===========================================================================
--  INIT (ModalLensPanel)
-- ===========================================================================
function InitializeModalLensPanel()
  print_debug("Initializing ModalLensPanel")
  if (Game.GetLocalPlayer() == -1) then
    return;
  end

  Controls.CloseButton:RegisterCallback(Mouse.eLClick, Close);

  Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
  Events.LensLayerOn.Add( OnLensLayerOn );

  LuaEvents.MinimapPanel_AddContinentColorPair.Add(OnAddContinentColorPair);
  LuaEvents.MinimapPanel_ModdedLensOn.Add(OnModdedLensOn);
  LuaEvents.MinimapPanel_AreaLensOn.Add(OnAreaLensOn);
end
InitializeModalLensPanel();
