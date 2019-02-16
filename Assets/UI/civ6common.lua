------------------------------------------------------------------------------
--  Common LUA support functions specific to Civilization 6
------------------------------------------------------------------------------

include( "ToolTipHelper" );
include( "Colors" );
include( "PortraitSupport" );


-- ===========================================================================
--  CONSTANTS
-- ===========================================================================

local TUTORIAL_UUID :string = "17462E0F-1EE1-4819-AAAA-052B5896B02A";

ProductionType = {
  BUILDING  = "BUILDING",
  DISTRICT  = "DISTRICT",
  PROJECT   = "PROJECT",
  UNIT    = "UNIT"
}

-- ===========================================================================
--  VARIABLES
-- ===========================================================================

local CQUI_ShowDebugPrint = false;

function CQUI_OnSettingsUpdate()
  CQUI_ShowDebugPrint = GameConfiguration.GetValue("CQUI_ShowDebugPrint") == 1
end
LuaEvents.CQUI_SettingsUpdate.Add(CQUI_OnSettingsUpdate);
LuaEvents.CQUI_SettingsInitialized.Add(CQUI_OnSettingsUpdate);


-- ===========================================================================
--  FUNCTIONS
-- ===========================================================================

-- ===========================================================================
--	Return the height of the top panel
-- ===========================================================================
function GetTopBarHeight() 
  return 29;	-- Not height of context but where art/offset should start for content below it.
end

-- ===========================================================================
--  Return the inline text-icon for a given yield
--  yieldType A database YIELD_TYPE
--  returns   The [ICON_yield] string
-- ===========================================================================
function GetYieldTextIcon( yieldType:string )
  local  iconString:string = "";
  if    yieldType == nil or yieldType == "" then
    iconString="Error:NIL";
  elseif  GameInfo.Yields[yieldType] ~= nil and GameInfo.Yields[yieldType].IconString ~= nil and GameInfo.Yields[yieldType].IconString ~= "" then
    iconString=GameInfo.Yields[yieldType].IconString;
  else
    iconString = "Unknown:"..yieldType;
  end
  return iconString;
end


-- ===========================================================================
--  Return the inline entry for a yield's color
-- ===========================================================================
function GetYieldTextColor( yieldType:string )
  if    yieldType == nil or yieldType == "" then return "[COLOR:255,255,255,255]NIL ";
  elseif  yieldType == "YIELD_FOOD"     then return "[COLOR:ResFoodLabelCS]";
  elseif  yieldType == "YIELD_PRODUCTION"   then return "[COLOR:ResProductionLabelCS]";
  elseif  yieldType == "YIELD_GOLD"     then return "[COLOR:ResGoldLabelCS]";
  elseif  yieldType == "YIELD_SCIENCE"    then return "[COLOR:ResScienceLabelCS]";
  elseif  yieldType == "YIELD_CULTURE"    then return "[COLOR:ResCultureLabelCS]";
  elseif  yieldType == "YIELD_FAITH"      then return "[COLOR:ResFaithLabelCS]";
  else                       return "[COLOR:255,255,255,0]ERROR ";
  end
end

-- ===========================================================================
--  Return a string with +/- or 0 based on any value.
-- ===========================================================================
function toPlusMinusString( value:number )
  if(value == 0) then
    return "0";
  else
    return Locale.ToNumber(value, "+#,###.#;-#,###.#");
  end
end

-- ===========================================================================
--  Return a string with +/- or 0 based on any value.
-- ===========================================================================
function toPlusMinusNoneString( value:number )
  if(value == 0) then
    return " ";
  else
    return Locale.ToNumber(value, "+#,###.#;-#,###.#");
  end
end


-- ===========================================================================
--  Return a string with a yield icon and a +/- based on yield amount.
-- ===========================================================================
function GetYieldString( yieldType:string, amount:number )
  return GetYieldTextIcon(yieldType)..GetYieldTextColor(yieldType)..toPlusMinusString(amount).."[ENDCOLOR]";
end

-- ===========================================================================
--  Move a unit to X,Y
-- ===========================================================================
function MoveUnitToPlot( kUnit:table, plotX:number, plotY:number )
  if kUnit ~= nil then
    local tParameters:table = {};
    tParameters[UnitOperationTypes.PARAM_X] = plotX;
    tParameters[UnitOperationTypes.PARAM_Y] = plotY;

    -- Will this start a war?  Note, we are ignoring destinations in the for that will start a war, the unit will be allowed to move until they are adjacent.
    -- We may want to also skip the war check if the move will take more than one turn to get to the destination.
    local eAttackingPlayer:number = kUnit:GetOwner();
    local eUnitComponentID:table = kUnit:GetComponentID();
    local bWillStartWar = false;
    
    local results:table;
    if (PlayersVisibility[eAttackingPlayer]:IsVisible(plotX, plotY)) then
      results = CombatManager.IsAttackChangeWarState(eUnitComponentID, plotX, plotY);
      if (results ~= nil and #results > 0) then
        bWillStartWar = true;
      end
    end
 
    if (bWillStartWar) then
      local eDefendingPlayer = results[1];
      -- Create the action specific parameters
      if (eDefendingPlayer ~= nil and eDefendingPlayer ~= -1) then
        LuaEvents.Civ6Common_ConfirmWarDialog(eAttackingPlayer, eDefendingPlayer, WarTypes.SURPRISE_WAR);
      end
    else
      RequestMoveOperation(kUnit, tParameters, plotX, plotY);
    end
  end
end

-- ===========================================================================
--  Requests an operation based on the type of unit and parameters
-- ===========================================================================
function RequestMoveOperation( kUnit:table, tParameters:table, plotX:number, plotY:number )
  -- Air units move and attack slightly differently than land and naval units
  if ( GameInfo.Units[kUnit:GetUnitType()].Domain == "DOMAIN_AIR" ) then
    tParameters[UnitOperationTypes.PARAM_MODIFIERS] = UnitOperationMoveModifiers.ATTACK;
    if (UnitManager.CanStartOperation( kUnit, UnitOperationTypes.AIR_ATTACK, nil, tParameters) ) then
      UnitManager.RequestOperation(kUnit, UnitOperationTypes.AIR_ATTACK, tParameters);
    elseif (UnitManager.CanStartOperation( kUnit, UnitOperationTypes.DEPLOY, nil, tParameters) ) then
      UnitManager.RequestOperation(kUnit, UnitOperationTypes.DEPLOY, tParameters);
    end
  else
    tParameters[UnitOperationTypes.PARAM_MODIFIERS] = UnitOperationMoveModifiers.NONE;
    if (UnitManager.CanStartOperation( kUnit, UnitOperationTypes.RANGE_ATTACK, nil, tParameters) and (kUnit:GetRangedCombat() > kUnit:GetCombat() or kUnit:GetBombardCombat() > kUnit:GetCombat() ) ) then
      UnitManager.RequestOperation(kUnit, UnitOperationTypes.RANGE_ATTACK, tParameters);
    else
      -- Allow for attacking and don't early out if the destination is blocked, etc., but is in the fog.
      tParameters[UnitOperationTypes.PARAM_MODIFIERS] = UnitOperationMoveModifiers.ATTACK + UnitOperationMoveModifiers.MOVE_IGNORE_UNEXPLORED_DESTINATION;
      if (UnitManager.CanStartOperation( kUnit, UnitOperationTypes.COASTAL_RAID, nil, tParameters) ) then
        UnitManager.RequestOperation( kUnit, UnitOperationTypes.COASTAL_RAID, tParameters);
      else
        -- Check that unit isn't already in the plot (essentially canceling the move),
        -- otherwise the operation will complete, and while no move is made, the next
        -- unit will auto seltect.
        if plotX ~= kUnit:GetX() or plotY ~= kUnit:GetY() then
          if (UnitManager.CanStartOperation( kUnit, UnitOperationTypes.SWAP_UNITS, nil, tParameters) ) then
            UnitManager.RequestOperation(kUnit, UnitOperationTypes.SWAP_UNITS, tParameters);
          else
            UnitManager.RequestOperation(kUnit, UnitOperationTypes.MOVE_TO, tParameters);
          end
        end
      end
    end
  end
end

-- ===========================================================================
--  Multiplier value
--  Return a string with a colorized # and a +/- based on 1.0 based percent.
-- ===========================================================================
function GetColorPercentString( multiplier:number )
  if    multiplier > 1 then return "[COLOR:StatGoodCS]+"..tostring((multiplier-1)*100).."%[ENDCOLOR]";
  elseif  multiplier < 1 then return "[COLOR:StatBadCS]-"..tostring((1-multiplier)*100).."%[ENDCOLOR]";
  else          return "[COLOR:StatNormalCS]100%[ENDCOLOR]";
  end
end

-- ===========================================================================
--  Obtain the stats for a unit, given it's hash or type string
--  RETURNS: nil if not found, or table o' stats
-- ===========================================================================
function GetUnitStats( hashOrType )
  local info:table= GameInfo.Units[hashOrType];
  if info == nil then
    --error("Was unable to find a Unit to get it's stats with the value \""..tostring(hashOrType).."\"");
    return nil;
  end
  return {
    Bombard   = info.Bombard,
    Combat    = info.Combat,
    Moves   = info.BaseMoves,
    RangedCombat= info.RangedCombat,
    Range   = info.Range
  }
end

-- ===========================================================================
--  Returns the icon info and shadow icon info for the passed in unit or returns default icons if those can't be found
--  RETURN 1: iconInfo - table containing textureSheet, textureOffsetX, and textureOffsetY
--  RETURN 2: iconShadowInfo - table containing textureSheetShadow, textureOffsetShadowX, and textureOffsetShadowY
-- ===========================================================================
function GetUnitIcon( pUnit:table, iconSize:number )	

  local iconInfo:table = {};
  if pUnit then

    local unitIcon:string = nil;

    local individual:number = pUnit:GetGreatPerson():GetIndividual();
    if individual >= 0 then
      local individualType:string = GameInfo.GreatPersonIndividuals[individual].GreatPersonIndividualType;
      local iconModifier:table = GameInfo.GreatPersonIndividualIconModifiers[individualType];
      if iconModifier then
        unitIcon = iconModifier.OverrideUnitIcon;
      end
    end

    if not unitIcon then
      local unit:table = GameInfo.Units[pUnit:GetUnitType()];
      unitIcon = "ICON_" .. unit.UnitType;
    end

    iconInfo.textureOffsetX, iconInfo.textureOffsetY, iconInfo.textureSheet = IconManager:FindIconAtlas(unitIcon, iconSize);
    if (iconInfo.textureSheet == nil) then      --Check to see if the unit has an icon atlas index defined
      print("UIWARNING: Could not find icon for " .. unitIcon);
      iconInfo.textureOffsetX, iconInfo.textureOffsetY, iconInfo.textureSheet = IconManager:FindIconAtlas("ICON_UNIT_UNKNOWN", iconSize);		--If not, resolve the index to be a generic unknown index
      end
    end
  return iconInfo;
end

-- ===========================================================================
--  A helper function to size a GridButton to its string contents
--  ARG 1: gridButton (table) - expects a control of type GridButton to be resized
--  ARG 4: minX (number) - the minimum width of the button
--  ARG 5: minY (number) - the minimum height of the button
--  ARG 2: OPTIONAL padding (number) - the amount of padding which should be inserted around the text string
--  ARG 3: OPTIONAL sizeOption (string) - expects V or H - to specifiy if the button should only be sized vertically or horizontally
-- ===========================================================================
function AutoSizeGridButton(gridButton:table,minX: number, minY: number, padding:number, sizeOption:string)
  if (sizeOption == nil) then
    sizeOption = "1";
  end
  if (padding == nil) then
    padding = 0;
  end
  local labelControl =  gridButton:GetTextControl();
  local labelX = labelControl:GetSizeX() + padding*2;
  local labelY = labelControl:GetSizeY() + padding*2;
  if (minX ~= nil) then
    labelX = math.max(minX, labelX);
  end
  if (minY ~= nil) then
    labelY = math.max(minY, labelY);
  end
  if(sizeOption == "V" or sizeOption == "1") then
    gridButton:SetSizeY(labelY);
  end
  if(sizeOption == "H" or sizeOption == "1") then
    gridButton:SetSizeX(labelX);
  end
  return labelX, labelY;
end

-- ===========================================================================
function GetLeaderUniqueTraits( leaderType:string, useFullDescriptions:boolean )

  -- Gather info.
    local base_leader = GameInfo.Leaders[leaderType];
    if(base_leader == nil) then
        return;
    end

  function AddInheritedLeaders(leaders, leader)
    local inherit = leader.InheritFrom;
        if(inherit ~= nil) then
            local parent = GameInfo.Leaders[inherit];
            if(parent) then
                table.insert(leaders, parent);
                AddInheritedLeaders(leaders, parent);
            end
        end
    end

  local leaders = {};
    table.insert(leaders, base_leader);
  AddInheritedLeaders(leaders, base_leader);

  -- Enumerate final list and index.
  local has_leader = {};
  for i,leader in ipairs(leaders) do
    has_leader[leader.LeaderType] = true;
  end

  -- Unique Abilities
  -- We're considering a unique ability to be a trait which does
  -- not have a unique unit, building, district, or improvement associated with it.
  -- While we scrub for unique units and infrastructure, mark traits that match
  -- so we can filter them later.
    local traits = {};
  local has_trait = {};
  local not_ability = {};
    for row in GameInfo.LeaderTraits() do
        if(has_leader[row.LeaderType] == true) then
      local trait = GameInfo.Traits[row.TraitType];
      if(trait) then
        table.insert(traits, trait);
      end
      has_trait[row.TraitType] = true;
        end
    end

    -- Unique Units
    local uu = {};
    for row in GameInfo.Units() do
        local trait = row.TraitType;
        if(trait) then
      not_ability[trait] = true;
      if(has_trait[trait] == true) then
        local description :string = Locale.Lookup("LOC_LOADING_"..row.Domain);
        if m_isTraitsFullDescriptions or useFullDescriptions then
          description = Locale.Lookup(GameInfo.Units[row.UnitType].Description);
        end
        table.insert(uu, { Type = row.UnitType, Name = row.Name, Description = description });
      end
        end
    end

    -- Unique Buildings/Districts/Improvements
    local ub = {};
    for row in GameInfo.Buildings() do
        local trait = row.TraitType;
        if(trait) then
      not_ability[trait] = true;
      if(has_trait[trait] == true) then
        local districtName:string = GameInfo.Districts[row.PrereqDistrict].Name;
        local description :string = Locale.Lookup("LOC_LOADING_UNIQUE_BUILDING");
        if m_isTraitsFullDescriptions or useFullDescriptions then
          description = Locale.Lookup(GameInfo.Buildings[row.BuildingType].Description);
        end
        table.insert(ub, {Type = row.BuildingType, Name = row.Name, Description = description});
      end
        end
    end

    for row in GameInfo.Districts() do
        local trait = row.TraitType;
        if(trait) then
      not_ability[trait] = true;
      if(has_trait[trait] == true) then
        local description :string = Locale.Lookup("LOC_LOADING_UNIQUE_DISTRICT");
        if m_isTraitsFullDescriptions or useFullDescriptions then
          description = Locale.Lookup(GameInfo.Districts[row.DistrictType].Description);
        end
        table.insert(ub, {Type = row.DistrictType, Name = row.Name, Description = description});
      end
        end
    end

    for row in GameInfo.Improvements() do
        local trait = row.TraitType;
        if(trait) then
      not_ability[trait] = true;
      if(has_trait[trait] == true) then
        local description :string = Locale.Lookup("LOC_LOADING_UNIQUE_IMPROVEMENT");
        if m_isTraitsFullDescriptions or useFullDescriptions then
          description = Locale.Lookup(GameInfo.Improvements[row.ImprovementType].Description);
        end
        table.insert(ub, {Type = row.ImprovementType, Name = row.Name, Description = description});
      end
        end
    end

  local unique_abilities = {};
  for i, trait in ipairs(traits) do
    if(not_ability[trait.TraitType] ~= true and not trait.InternalOnly) then
      table.insert(unique_abilities, trait);
    end
  end

  return unique_abilities,uu,ub;
end


-- ===========================================================================
function GetCivilizationUniqueTraits( civType:string, useFullDescriptions:boolean )

  local traits = {};
    for row in GameInfo.CivilizationTraits() do
        if(row.CivilizationType == civType) then
            traits[row.TraitType] = true;
        end
    end

  -- Unique Abilities
  -- We're considering a unique ability to be a trait which does
  -- not have a unique unit, building, district, or improvement associated with it.
  -- While we scrub for unique units and infrastructure, mark traits that match
  -- so we can filter them later.
  local not_abilities = {};

    -- Unique Units
    local uu = {};
    for row in GameInfo.Units() do
        local trait = row.TraitType;
        if(trait) then
      not_abilities[trait] = true;
      if(traits[trait] == true) then
        local description :string = Locale.Lookup("LOC_LOADING_"..row.Domain);
        if m_isTraitsFullDescriptions or useFullDescriptions then
          description = Locale.Lookup(GameInfo.Units[row.UnitType].Description);
        end
        table.insert(uu, { Type = row.UnitType, Name = row.Name, Description = description });
      end
        end
    end

    -- Unique Buildings/Districts/Improvements
    local ub = {};
    for row in GameInfo.Buildings() do
        local trait = row.TraitType;
        if(trait) then
      not_abilities[trait] = true;
      if(traits[trait] == true) then
        local building    :table  = GameInfo.Buildings[row.BuildingType];
        local description :string = Locale.Lookup("LOC_LOADING_UNIQUE_BUILDING");
        if m_isTraitsFullDescriptions or useFullDescriptions then
          if building == nil then
            UI.DataError("Could not get CIV trait as GameInfo.Buildings["..row.BuildingType.."] does not exist.");
          elseif building.Description == nil then
            UI.DataError("Could not get CIV trait description for GameInfo.Buildings["..row.BuildingType.."].  None supplied.");
          else
            description = Locale.Lookup(building.Description);
          end
        end
        table.insert(ub, {Type = row.BuildingType, Name = row.Name, Description = description});
      end
        end
    end

    for row in GameInfo.Districts() do
        local trait = row.TraitType;
        if(trait) then
      not_abilities[trait] = true;
      if(traits[trait] == true) then
        local description :string = Locale.Lookup("LOC_LOADING_UNIQUE_DISTRICT");
        if m_isTraitsFullDescriptions or useFullDescriptions then
          description = Locale.Lookup(GameInfo.Districts[row.DistrictType].Description);
        end
        table.insert(ub, {Type = row.DistrictType, Name = row.Name, Description = description});
      end
        end
    end

    for row in GameInfo.Improvements() do
        local trait = row.TraitType;
        if(trait) then
      not_abilities[trait] = true;
      if(traits[trait] == true) then
        local description :string = Locale.Lookup("LOC_LOADING_UNIQUE_IMPROVEMENT");
        if m_isTraitsFullDescriptions or useFullDescriptions then
          description = Locale.Lookup(GameInfo.Improvements[row.ImprovementType].Description);
        end
        table.insert(ub, {Type = row.ImprovementType, Name = row.Name, Description = description});
      end
        end
    end

  local unique_abilities = {};
  for row in GameInfo.CivilizationTraits() do
    if(row.CivilizationType == civType and not_abilities[row.TraitType] ~= true) then
      local trait = GameInfo.Traits[row.TraitType];
      if(trait) then
        table.insert(unique_abilities, trait);
      end
    end
  end

  return unique_abilities, uu, ub;
end


-- ===========================================================================
--  Is the on-rails tutorial active?
-- ===========================================================================
function IsTutorialRunning()
  return Modding.IsModActive(TUTORIAL_UUID); 
end

-- ===========================================================================
--  DifferentiateCiv
-- ===========================================================================
--  This is a fix for duplicate civs.  If you feed it a control, it will generate a tooltip which lists the cities for that civ, to help differentiate which civ you are currently viewing.
--  Note: This function does NOT contain the IsDuplicate? check.  Use this function once you have already determined whether or not you wish to differentiate the civ.
--  Additionally, you can pass icon backing/icon controls to be colored with the civ's colors.
--  ARG1 playerID (number)            The player id of the civ in question
--  ARG2 tooltipControl (table)     OPTIONAL  This is the control that should receive the tooltip
--  ARG3 icon (table)         OPTIONAL  The icon control which will receive the foreground color for the civ
--  ARG4 iconBacking (table)      OPTIONAL  The image behind the icon which will receive the background color for the civ
--  ARG5 iconBackingDarker (table)    OPTIONAL  If you are making a fancy icon with more depth, you can additionally pass the layer to be darkened
--  ARG6 iconBackingLighter (table)   OPTIONAL  .. and also the layer to be lightened
--  ARG7 observerPlayerID (number)    OPTIONAL  Checks if the players met
--  RETURNS (string)                String to be used as a tooltip which lists Civ name, Leader/Player name, list of cities
function DifferentiateCiv(playerID:number, tooltipControl:table, icon:table, iconBacking:table, iconBackingDarker:table, iconBackingLighter:table, observerPlayerID:number)

  local player:table = Players[playerID];
  local playerConfig:table = PlayerConfigurations[playerID];

  local hasMet:boolean = true;
  if player ~= nil and observerPlayerID ~= nil and playerID ~= observerPlayerID then
    hasMet = player:GetDiplomacy():HasMet(observerPlayerID);
  end

  if (player ~= nil and hasMet and iconBacking ~= nil and icon ~= nil) then
    m_primaryColor, m_secondaryColor  = UI.GetPlayerColors( playerID );
    iconBacking:SetColor(m_primaryColor);
    if(iconBackingLighter ~= nil and iconBackingDarker ~= nil) then
      local darkerBackColor = DarkenLightenColor(m_primaryColor,(-85),100);
      local brighterBackColor = DarkenLightenColor(m_primaryColor,90,255);
      iconBackingLighter:SetColor(brighterBackColor);
      iconBackingDarker:SetColor(darkerBackColor);
    end
    icon:SetColor(m_secondaryColor);
  end

  -- Set the leader name, civ name, and civ icon data
  local civTypeName = playerConfig:GetCivilizationTypeName();
  if civTypeName ~= nil then
    local civIcon:string;
    local civTooltip:string;
    if hasMet then
      civIcon = "ICON_"..civTypeName;

      local leaderTypeName:string = playerConfig:GetLeaderTypeName();
      if leaderTypeName ~= nil then
        local leaderName = Locale.Lookup(GameInfo.Leaders[leaderTypeName].Name);
        if GameConfiguration.IsAnyMultiplayer() and player:IsHuman() then
          local playerName = Locale.Lookup(playerConfig:GetPlayerName());
          leaderName = leaderName .. " ("..Locale.Lookup(playerName)..")"
        end

        --Create a tooltip which shows a list of this Civ's cities
        local civName = Locale.Lookup(GameInfo.Civilizations[civTypeName].Name);
        civTooltip = civName .. "[NEWLINE]".. leaderName;
        local playerCities = player:GetCities();
        if(playerCities ~= nil) then
          civTooltip = civTooltip .. "[NEWLINE]"..Locale.Lookup("LOC_PEDIA_CONCEPTS_PAGEGROUP_CITIES_NAME").. ":";
          for i,city in playerCities:Members() do
            civTooltip = civTooltip.. "[NEWLINE]".. Locale.Lookup(city:GetName());
          end
        end
      else
        UI.DataError("Invalid type name returned by GetLeaderTypeName");
      end
    else
      civIcon = "ICON_LEADER_DEFAULT";
      civTooltip = Locale.Lookup("LOC_DIPLOPANEL_UNMET_PLAYER");
      if GameConfiguration.IsAnyMultiplayer() and player:IsHuman() then
        local playerName = Locale.Lookup(playerConfig:GetPlayerName());
        civTooltip = civTooltip .. " ("..Locale.Lookup(playerName)..")";
      end
    end

    if (icon ~= nil) then
      icon:SetIcon(civIcon);
    end
    if (tooltipControl ~= nil) then
      tooltipControl:SetToolTipString(Locale.Lookup(civTooltip));
    end
    return civTooltip;
  else
    UI.DataError("Invalid type name returned by GetCivilizationTypeName");
  end
end


-- ===========================================================================
function GetGreatWorksForCity( pCity:table )
  local result:table = {};
  if pCity then
    local pCityBldgs:table = pCity:GetBuildings();
    for buildingInfo in GameInfo.Buildings() do
      local buildingIndex:number = buildingInfo.Index;
      local buildingType:string = buildingInfo.BuildingType;
      if(pCityBldgs:HasBuilding(buildingIndex)) then
        local numSlots:number = pCityBldgs:GetNumGreatWorkSlots(buildingIndex);
        if (numSlots ~= nil and numSlots > 0) then
          local greatWorksInBuilding:table = {};

          -- populate great works
          for index:number=0, numSlots - 1 do
            local greatWorkIndex:number = pCityBldgs:GetGreatWorkInSlot(buildingIndex, index);
            if greatWorkIndex ~= -1 then
              local greatWorkType:number = pCityBldgs:GetGreatWorkTypeFromIndex(greatWorkIndex);
              table.insert(greatWorksInBuilding, GameInfo.GreatWorks[greatWorkType]);
            end
          end

          -- create association between building type and great works
          if table.count(greatWorksInBuilding) > 0 then
            result[buildingType] = greatWorksInBuilding;
          end
        end
      end
    end
  end
  return result;
end

-- ===========================================================================
--	Is a diplomacy for the local player.
-- ===========================================================================
function IsDiplomacyPending()
  local localPlayerId:number = Game.GetLocalPlayer();
  if localPlayerId == -1 then
    return false;
  end
  if (DiplomacyManager.HasQueuedSession(localPlayerId) ) then
    return true;
  end
  return false;
end

-- ===========================================================================
--	Is diplomacy open for thelocal player.
-- ===========================================================================
function IsDiplomacyOpen()
  local localPlayerId:number = Game.GetLocalPlayer();
  if localPlayerId == -1 then
    return false;
  end
  
  local localPlayer :table = Players[localPlayerId];
  local pOtherPlayer:table = nil;
  
  -- Loop through all the players whom could have 
  for iPlayer = 0,63,1 do
    local pPlayerConfig = PlayerConfigurations[iPlayer];

    pOtherPlayer = Players[iPlayer];
    if pOtherPlayer then
      local sessionID :number = DiplomacyManager.FindOpenSessionID( localPlayerId, pOtherPlayer:GetID());
      if sessionID ~= nil then
        return true;
      end
    end
  end
  return false;
end

-- ===========================================================================
--	RETURNS: true if a player does not have any cities.
-- ===========================================================================
function IsPlayerCityless( playerID:number )
  if playerID < 0 then return true; end
  local pPlayer		:table = Players[playerID];
  local pPlayerCities	:table = pPlayer:GetCities();
  for i, pCity in pPlayerCities:Members() do
    return false;
  end
  return true;
end

-- ===========================================================================
--	Serialize custom data in the custom data table.
--	key		must be a string
--	value	can be anything
-- ===========================================================================
function WriteCustomData( key:string, value )
  local pParameters :table = UI.GetGameParameters():Add("CustomData");
  if pParameters ~= nil then
    pParameters:Remove( key );
    local pData:table = pParameters:Add( key );
    pData:AppendValue( value );
  else
    UI.DataError("Could not write CustomData: ",key,value);
  end
end

-- ===========================================================================
--	Read back custom data, returns NIL if not found.
--	key		must be a string
--	RETURNS: all values from the associated key (or nil if key isn't found)
-- ===========================================================================
function ReadCustomData( key:string )
  local pParameters	:table = UI.GetGameParameters():Get("CustomData");
  local kReturn		:table = {};
  if pParameters ~= nil then
    local pValues:table = pParameters:Get( key );		
    -- No key or empty key?  Return nil...
    if pValues == nil then
      return nil;
    end
    local count:number = pValues:GetCount();
    if count == 0 then
      return nil;
    end
    for i = 1, count, 1 do
      local value = pValues:GetValueAt(i-1);
      table.insert(kReturn, value);
    end
  else
    return nil;
  end
  return unpack(kReturn);
end

--CQUI setting control support functions

--Used to register a control to be updated whenever settings update (only necessary for controls that can be updated from multiple places)
function RegisterControl(control, setting_name, update_function, extra_data)
  LuaEvents.CQUI_SettingsUpdate.Add(function() update_function(control, setting_name, extra_data); end);
end

--Companion functions to RegisterControl
function UpdateComboBox(control, setting_name, values)
  --This is a tough one! TODO for later
end

function UpdateCheckbox(control, setting_name)
  local value = GameConfiguration.GetValue(setting_name);
  if(value == nil) then return; end
  control:SetSelected(value);
end

function UpdateSlider( control, setting_name, data_converter)
  local value = GameConfiguration.GetValue(setting_name);
  if(value == nil) then return; end
  control:SetStep(data_converter.ToSteps(value));
end

--Used to populate combobox options
function PopulateComboBox(control, values, setting_name, tooltip)
  control:ClearEntries();
  local current_value = GameConfiguration.GetValue(setting_name);
  if(current_value == nil) then
  if(GameInfo.CQUI_Settings[setting_name]) then --LY Checks if this setting has a default state defined in the database
    current_value = GameInfo.CQUI_Settings[setting_name].Value; --reads the default value from the database. Set them in Settings.sql
  else current_value = 0;
  end
    GameConfiguration.SetValue(setting_name, current_value); --/LY
  end
  for i, v in ipairs(values) do
    local instance = {};
    control:BuildEntry( "InstanceOne", instance );
    instance.Button:SetVoid1(i);
        instance.Button:LocalizeAndSetText(v[1]);
    if(v[2] == current_value) then
      local button = control:GetButton();
      button:LocalizeAndSetText(v[1]);
    end
  end
  control:CalculateInternals();
  if(setting_name) then
    control:RegisterSelectionCallback(
      function(voidValue1, voidValue2, control)
        local option = values[voidValue1];
        local button = control:GetButton();
        button:LocalizeAndSetText(option[1]);
        GameConfiguration.SetValue(setting_name, option[2]);
        LuaEvents.CQUI_SettingsUpdate();
      end
    );
  end
  if(tooltip ~= nil)then
    control:SetToolTipString(tooltip);
  end
end

--Used to populate checkboxes
function PopulateCheckBox(control, setting_name, tooltip)
  local current_value = GameConfiguration.GetValue(setting_name);
  if(current_value == nil) then
    if(GameInfo.CQUI_Settings[setting_name]) then --LY Checks if this setting has a default state defined in the database
      if(GameInfo.CQUI_Settings[setting_name].Value == 0) then --because 0 is true in Lua
        current_value = false;
      else
        current_value = true;
      end
    else current_value = false;
    end
    GameConfiguration.SetValue(setting_name, current_value); --/LY
  end
  if(current_value == false) then
    control:SetSelected(false);
  else
    control:SetSelected(true);
  end
  control:RegisterCallback(Mouse.eLClick,
    function()
      local selected = not control:IsSelected();
      control:SetSelected(selected);
      GameConfiguration.SetValue(setting_name, selected);
      LuaEvents.CQUI_SettingsUpdate();
    end
  );
  if(tooltip ~= nil)then
    control:SetToolTipString(tooltip);
  end
end

--Used to populate sliders. data_converter is a table containing two functions: ToStep and ToValue, which describe how to hanlde converting from the incremental slider steps to a setting value, think of it as a less elegant inner class
--Optional third function: ToString. When included, this function will handle how the value is converted to a display value, otherwise this defaults to using the value from ToValue
function PopulateSlider(control, label, setting_name, data_converter, tooltip)
  local hasScrolled = false; --Necessary because RegisterSliderCallback fires twice when releasing the mouse cursor for some reason
  local current_value = GameConfiguration.GetValue(setting_name);
  if(current_value == nil) then
    if(GameInfo.CQUI_Settings[setting_name]) then --LY Checks if this setting has a default state defined in the database
      current_value = GameInfo.CQUI_Settings[setting_name].Value;
    else current_value = 0; end
    GameConfiguration.SetValue(setting_name, current_value); --/LY
  end
  control:SetStep(data_converter.ToSteps(current_value));
  if(data_converter.ToString) then
    label:SetText(data_converter.ToString(current_value));
  else
    label:SetText(current_value);
  end
  control:RegisterSliderCallback(
    function()
      local value = data_converter.ToValue(control:GetStep());
      if(data_converter.ToString) then
        label:SetText(data_converter.ToString(value));
      else
        label:SetText(value);
      end
      if(not control:IsTrackingLeftMouseButton() and hasScrolled == true) then
        GameConfiguration.SetValue(setting_name, value);
        LuaEvents.CQUI_SettingsUpdate();
        hasScrolled = false;
      else hasScrolled = true; end
    end
  );
  if(tooltip ~= nil)then
    control:SetToolTipString(tooltip);
  end
end

--Trims source information from gossip messages. Returns nil if the message couldn't be trimmed (this usually means the provided string wasn't a gossip message at all)
function CQUI_TrimGossipMessage(str:string)
  local sourceSample = Locale.Lookup("LOC_GOSSIP_SOURCE_DELEGATE", "XX", "Y", "Z"); --Get a sample of a gossip source string
  last = string.match(sourceSample, ".-XX.-(%s%S+)$"); --Get last word that occurs in the gossip source string. "that" in English. Assumes the last word is always the same, which it is in English, unsure if this holds true in other languages
  -- AZURENCY : the patterns means : any character 0 or +, XX exactly, any character 0 or +, space, any character other than space 1 or + at the end of the sentence.
  -- AZURENCY : in some languages, there is no space, in that case, take the last character (often it's a ":")
  if last == nil then
    last = string.match(sourceSample, ".-(.)$");
  end
  -- AZURENCY : if last is still nill, it's not normal, print an error but still allow the code to run
  if last == nil then
    print("ERROR : LOC_GOSSIP_SOURCE_DELEGATE seems to be empty as last was still nil after the second pattern matching.")
    last = ""
  end
  return Split(str, last .. " " , 2)[2]; --Get the rest of the string after the last word from the gossip source string
end

function print_debug(str)
  if CQUI_ShowDebugPrint then
    print(str)
  end
end
