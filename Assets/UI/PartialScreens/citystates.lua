-- ===========================================================================
--  CityStates "Rundown" partial-screen
--
--  su·ze·rain (noun)
--  a sovereign or state having some control over another state that is
--  internally autonomous.
-- ===========================================================================

include("AnimSidePanelSupport");
include("InstanceManager");
include("SupportFunctions");
include("GameCapabilities");
include("TeamSupport");

-- ===========================================================================
--  CONSTANTS
-- ===========================================================================
local COLOR_ICON_BONUS_OFF        :number = 0xff606060;
local COLOR_ICON_BONUS_ON        :number = 0xff999900;
local COLOR_TEXT_BONUS_OFF        :number = 0xff606060;
local COLOR_TEXT_BONUS_ON        :number = 0xffb0b0b0;
local FONT_SIZE_SINGLE_DIGIT_ENVOYS    :number = 40;
local FONT_SIZE_TWO_DIGIT_ENVOYS    :number = 26;
local FONT_SIZE_THREE_DIGIT_ENVOYS    :number = 18;
local MIN_ENVOY_TOKENS_SUZERAIN      :number = 3;  --TODO: expose via game core
local NUM_ENVOY_TOKENS_FOR_FIRST_BONUS  :number = 1;
local NUM_ENVOY_TOKENS_FOR_SECOND_BONUS  :number = 3;
local NUM_ENVOY_TOKENS_FOR_THIRD_BONUS  :number = 6;
local MAX_BEFORE_TRUNC_SUZERAIN:number = 310;
local DIPLO_PIP_INFO = {};
    DIPLO_PIP_INFO["DIPLO_STATE_PROTECTOR"]    = { IconName="ICON_RELATIONSHIP_SUZERAIN",  Tooltip="LOC_CITY_STATES_DIPLO_SUZERAIN"};
    DIPLO_PIP_INFO["DIPLO_STATE_PATRON"]    = { IconName="ICON_RELATIONSHIP_GOOD",    Tooltip="LOC_CITY_STATES_DIPLO_GOOD"};
    DIPLO_PIP_INFO["DIPLO_STATE_AWARE"]      = { IconName="ICON_RELATIONSHIP_NEUTRAL",  Tooltip="LOC_CITY_STATES_DIPLO_AWARE"};
    DIPLO_PIP_INFO["DIPLO_STATE_WAR_WITH_MAJOR"]= { IconName="ICON_RELATIONSHIP_WAR",    Tooltip="LOC_CITY_STATES_DIPLO_WAR"};
    DIPLO_PIP_INFO["DIPLO_STATE_WAR_WITH_MINOR"]= { IconName="ICON_RELATIONSHIP_WAR",		Tooltip="LOC_CITY_STATES_DIPLO_WAR"};
    DIPLO_PIP_INFO["DIPLO_STATE_MINOR_MINOR_WAR"]= { IconName="ICON_RELATIONSHIP_WAR",		Tooltip="LOC_CITY_STATES_DIPLO_WAR"};
local RELOAD_CACHE_ID          :string = "CityStates"; -- Must be unique (usually the same as the file name)

local MODE                :table = {
  Overview  = "Overview",
  SendEnvoys  = "SendEnvoys",
  EnvoySent  = "EnvoySent",
  InfluencedBy  = "InfluencedBy",
  Quests		  = "Quests",
  Relationships = "Relationships"
}

local TEAM_RIBBON_PREFIX			:string = "ICON_TEAM_RIBBON_";
local REPORT_CONTAINER_SIZE_PADDING	:number = -18;

-- ===========================================================================
--  MEMBERS
-- ===========================================================================
local m_CityStateRowIM      :table = InstanceManager:new( "CityStateRowInstance",  "CityStateBase",Controls.CityStateStack);
local m_CityStateColumnIM    :table = InstanceManager:new( "CityStateIconInstance",  "Top",      Controls.CityStateIconStack);
local m_BonusCityHeaderIM    :table = InstanceManager:new( "BonusCityHeaderInstance","Top",      Controls.BonusStack);
local m_BonusItemIM        :table = InstanceManager:new( "BonusItemOnInstance",  "Top",      Controls.BonusStack);
local m_EnvoysBonusCityHeaderIM  :table = InstanceManager:new( "BonusCityHeaderInstance","Top",      Controls.EnvoysBonusStack);
local m_EnvoysBonusItemIM    :table = InstanceManager:new( "BonusItemOnInstance",  "Top",      Controls.EnvoysBonusStack);
local m_InfluenceRowIM      :table = InstanceManager:new( "InfluenceRowInstance",  "Top",      Controls.InfluenceStack);
local m_QuestsIM        :table = InstanceManager:new( "QuestInstance",      "Top",      Controls.QuestsStack);
local m_RelationshipsButtonIM		:table = InstanceManager:new( "RelationshipIcon",	"Background",	Controls.RelationshipsButtonStack);
local m_RelationshipsCivsIM			:table = InstanceManager:new( "RelationshipIcon",	"Background",	Controls.RelationshipsCivsStack);
local m_RelationshipsCityStatesIM	:table = InstanceManager:new( "RelationshipIcon",	"Background",	Controls.RelationshipsCityStatesStack);

local m_kScreenSlideAnim    :table;        -- Controls overall look/feel of animation.
local m_kCityStates        :table = {};    -- City states, key is player num of city state
local m_kLastCityStates      :table;        -- Last set before confirming a city state change.
local m_kPlayerData        :table = {};    -- Holds live player data that hasn't been solidifed in the game core.
local m_kEnvoyChanges      :table = {};    -- Table (player,deltas) for envoy tokens about to be given out
local m_uiCityStateRows      :table = {};    -- Instances holding the city state rows
local m_mode          :string;      -- How the screen should act.
local m_iCurrentCityState    :number= -1;    -- Player # of the city state currently active
local m_iTurnsOfPeace      :number= Game.GetGameDiplomacy():GetMinPeaceDuration();
local m_iTurnsOfWar        :number= Game.GetGameDiplomacy():GetMinPeaceDuration();

local m_isLocalPlayerTurn    :boolean = true;

-- ===========================================================================
--  FUNCTIONS
-- ===========================================================================

function GetCityStatesMetNum()
  local total:number = 0;
  for _,kCityState in pairs(m_kCityStates) do
    if kCityState.isHasMet then
      total = total + 1;
    end
  end
  return total;
end


-- ===========================================================================
--  Helper
--  iPlayerID is the city state player to move the camera to point towards.
-- ===========================================================================
function LookAtCityState( iPlayerID:number )
  local pPlayer    :table = Players[iPlayerID];
  local pPlayerCities  :table = pPlayer:GetCities();
  if pPlayerCities:GetCount() > 1 then
    -- Might change in the future; currently city states will just raze
    UI.DataError("The CityState player "..tostring(iPlayerID).." has "..tostring(pPlayerCities:GetCount()).." cities, but should only have 1.");
  end
  for _, pCity in pPlayerCities:Members() do
    local locX      :number = pCity:GetX();
    local locY      :number = pCity:GetY();
    UI.LookAtPlotScreenPosition( locX, locY, 0.33, 0.5 );
  end
end


-- ===========================================================================
--  Helper
--  playerID which player to look up the bonus type for
--  envoyTokenNum  1,3,4,6 for the type of bonus to obtain
--  RETURN type of bonus, the bonus text type for a city
-- ===========================================================================
function GetBonusText( playerID:number, envoyTokenNum:number )
  local leader  :string = PlayerConfigurations[playerID]:GetLeaderTypeName();
  local leaderInfo:table  = GameInfo.Leaders[leader];
  if leaderInfo == nil or leaderInfo.InheritFrom == nil then
    UI.DataError("Cannot determine the type of city state bonus for player #: "..tostring(playerID) );
    return "UNKNOWN";
  end

  local bonusTypeText = "";
  if envoyTokenNum == NUM_ENVOY_TOKENS_FOR_FIRST_BONUS then bonusTypeText = Locale.Lookup("LOC_MINOR_CIV_SMALL_INFLUENCE_ENVOYS");
  elseif envoyTokenNum == NUM_ENVOY_TOKENS_FOR_SECOND_BONUS then bonusTypeText = Locale.Lookup("LOC_MINOR_CIV_MEDIUM_INFLUENCE_ENVOYS");
  elseif envoyTokenNum == NUM_ENVOY_TOKENS_FOR_THIRD_BONUS then bonusTypeText = Locale.Lookup("LOC_MINOR_CIV_LARGE_INFLUENCE_ENVOYS");
  else UI.DataError("Unknown envoy number for city-state type bonus:" .. tostring(envoyTokenNum));
  end

  local bonusDetailsText = "";
  if (leader == "LEADER_MINOR_CIV_SCIENTIFIC" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_SCIENTIFIC") then
    if envoyTokenNum == NUM_ENVOY_TOKENS_FOR_FIRST_BONUS then bonusDetailsText = Locale.Lookup("LOC_MINOR_CIV_SCIENTIFIC_TRAIT_SMALL_INFLUENCE_BONUS");
    elseif envoyTokenNum == NUM_ENVOY_TOKENS_FOR_SECOND_BONUS then bonusDetailsText = Locale.Lookup("LOC_MINOR_CIV_SCIENTIFIC_TRAIT_MEDIUM_INFLUENCE_BONUS");
    elseif envoyTokenNum == NUM_ENVOY_TOKENS_FOR_THIRD_BONUS then bonusDetailsText = Locale.Lookup("LOC_MINOR_CIV_SCIENTIFIC_TRAIT_LARGE_INFLUENCE_BONUS");
    else UI.DataError("Unknown envoy number for city-state type bonus: " .. tostring(envoyTokenNum));
    end
  elseif (leader == "LEADER_MINOR_CIV_RELIGIOUS" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_RELIGIOUS") then
    if envoyTokenNum == NUM_ENVOY_TOKENS_FOR_FIRST_BONUS then bonusDetailsText = Locale.Lookup("LOC_MINOR_CIV_RELIGIOUS_TRAIT_SMALL_INFLUENCE_BONUS");
    elseif envoyTokenNum == NUM_ENVOY_TOKENS_FOR_SECOND_BONUS then bonusDetailsText = Locale.Lookup("LOC_MINOR_CIV_RELIGIOUS_TRAIT_MEDIUM_INFLUENCE_BONUS");
    elseif envoyTokenNum == NUM_ENVOY_TOKENS_FOR_THIRD_BONUS then bonusDetailsText = Locale.Lookup("LOC_MINOR_CIV_RELIGIOUS_TRAIT_LARGE_INFLUENCE_BONUS");
    else UI.DataError("Unknown envoy number for city-state type bonus: " .. tostring(envoyTokenNum));
    end
  elseif (leader == "LEADER_MINOR_CIV_TRADE" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_TRADE") then
    if envoyTokenNum == NUM_ENVOY_TOKENS_FOR_FIRST_BONUS then bonusDetailsText = Locale.Lookup("LOC_MINOR_CIV_TRADE_TRAIT_SMALL_INFLUENCE_BONUS");
    elseif envoyTokenNum == NUM_ENVOY_TOKENS_FOR_SECOND_BONUS then bonusDetailsText = Locale.Lookup("LOC_MINOR_CIV_TRADE_TRAIT_MEDIUM_INFLUENCE_BONUS");
    elseif envoyTokenNum == NUM_ENVOY_TOKENS_FOR_THIRD_BONUS then bonusDetailsText = Locale.Lookup("LOC_MINOR_CIV_TRADE_TRAIT_LARGE_INFLUENCE_BONUS");
    else UI.DataError("Unknown envoy number for city-state type bonus: " .. tostring(envoyTokenNum));
    end
  elseif (leader == "LEADER_MINOR_CIV_CULTURAL" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_CULTURAL") then
    if envoyTokenNum == NUM_ENVOY_TOKENS_FOR_FIRST_BONUS then bonusDetailsText = Locale.Lookup("LOC_MINOR_CIV_CULTURAL_TRAIT_SMALL_INFLUENCE_BONUS");
    elseif envoyTokenNum == NUM_ENVOY_TOKENS_FOR_SECOND_BONUS then bonusDetailsText = Locale.Lookup("LOC_MINOR_CIV_CULTURAL_TRAIT_MEDIUM_INFLUENCE_BONUS");
    elseif envoyTokenNum == NUM_ENVOY_TOKENS_FOR_THIRD_BONUS then bonusDetailsText = Locale.Lookup("LOC_MINOR_CIV_CULTURAL_TRAIT_LARGE_INFLUENCE_BONUS");
    else UI.DataError("Unknown envoy number for city-state type bonus: " .. tostring(envoyTokenNum));
    end
  elseif (leader == "LEADER_MINOR_CIV_MILITARISTIC" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_MILITARISTIC") then
    if envoyTokenNum == NUM_ENVOY_TOKENS_FOR_FIRST_BONUS then bonusDetailsText = Locale.Lookup("LOC_MINOR_CIV_MILITARISTIC_TRAIT_SMALL_INFLUENCE_BONUS");
    elseif envoyTokenNum == NUM_ENVOY_TOKENS_FOR_SECOND_BONUS then bonusDetailsText = Locale.Lookup("LOC_MINOR_CIV_MILITARISTIC_TRAIT_MEDIUM_INFLUENCE_BONUS");
    elseif envoyTokenNum == NUM_ENVOY_TOKENS_FOR_THIRD_BONUS then bonusDetailsText = Locale.Lookup("LOC_MINOR_CIV_MILITARISTIC_TRAIT_LARGE_INFLUENCE_BONUS");
    else UI.DataError("Unknown envoy number for city-state type bonus: " .. tostring(envoyTokenNum));
    end
  elseif (leader == "LEADER_MINOR_CIV_INDUSTRIAL" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_INDUSTRIAL") then
    if envoyTokenNum == NUM_ENVOY_TOKENS_FOR_FIRST_BONUS then bonusDetailsText = Locale.Lookup("LOC_MINOR_CIV_INDUSTRIAL_TRAIT_SMALL_INFLUENCE_BONUS");
    elseif envoyTokenNum == NUM_ENVOY_TOKENS_FOR_SECOND_BONUS then bonusDetailsText = Locale.Lookup("LOC_MINOR_CIV_INDUSTRIAL_TRAIT_MEDIUM_INFLUENCE_BONUS");
    elseif envoyTokenNum == NUM_ENVOY_TOKENS_FOR_THIRD_BONUS then bonusDetailsText = Locale.Lookup("LOC_MINOR_CIV_INDUSTRIAL_TRAIT_LARGE_INFLUENCE_BONUS");
    else UI.DataError("Unknown envoy number for city-state type bonus: " .. tostring(envoyTokenNum));
    end
  else
    UI.DataError("Unknown leader type for city-state type bonus");
  end

  return bonusTypeText, bonusDetailsText;
end


-- ===========================================================================
--  Obtain the bonus text for a Suzerain
--  playerID which player to look up the bonus type for
--  envoyTokenNum  1,3,4,6 for the type of bonus to obtain
--
--  RETURN the full bonus text type for a city, and a short (brief) version
-- ===========================================================================
function GetSuzerainBonusText( playerID:number )

  local leader  :string = PlayerConfigurations[playerID]:GetLeaderTypeName();
  local leaderInfo:table  = GameInfo.Leaders[leader];
  if leaderInfo == nil then
    UI.DataError("GetSuzerainBonusText, cannot determine the type of city state suzerain bonus for player #: "..tostring(playerID) );
    return "UNKNOWN";
  end

  local text    :string = "";

  -- Unique Bonus
  for leaderTraitPairInfo in GameInfo.LeaderTraits() do
    if (leader ~= nil and leader == leaderTraitPairInfo.LeaderType) then
      local traitInfo = GameInfo.Traits[leaderTraitPairInfo.TraitType];
      if (traitInfo ~= nil) then
        local name = PlayerConfigurations[playerID]:GetCivilizationShortDescription();
        text = text .. "[COLOR:SuzerainDark]" .. Locale.Lookup("LOC_CITY_STATES_SUZERAIN_UNIQUE_BONUS", name) .. "[ENDCOLOR] ";
        text = text .. Locale.Lookup(traitInfo.Description);
      end
    end
  end

  -- Diplomatic Bonus
  text = text .. "[NEWLINE][NEWLINE]" .. Locale.Lookup("LOC_CITY_STATES_SUZERAIN_DIPLOMATIC_BONUS");

  local comma_separator = Locale.Lookup("LOC_GRAMMAR_COMMA_SEPARATOR");

  -- Resources Available
  local resourceIcons  :string = "";
  local player = Players[playerID];
  if (player ~= nil) then
    for resourceInfo in GameInfo.Resources() do
      local resource = resourceInfo.Index;
      -- Include exports, so we see what another player is getting if suzerain
      if (player:GetResources():HasResource(resource) or player:GetResources():HasExportedResource(resource)) then
        local amount = player:GetResources():GetResourceAmount(resource) + player:GetResources():GetExportedResourceAmount(resource);
        if (resourceIcons ~= "") then
          resourceIcons = resourceIcons .. comma_separator;
        end
        resourceIcons = resourceIcons .. amount .. " [ICON_" .. resourceInfo.ResourceType .. "] " .. Locale.Lookup(resourceInfo.Name);
      end
    end
  end
  if (resourceIcons ~= "") then
    text = text .. " " .. resourceIcons;
  else
    text = text .. " " .. Locale.Lookup("LOC_CITY_STATES_SUZERAIN_NO_RESOURCES_AVAILABLE");
  end

  return text;
end

-- ===========================================================================
--  RETURN a table of quests for a given CityState
-- ===========================================================================
function GetQuests( playerID:number )
  local kQuests    :table  = {};
  local questsManager  :table = Game.GetQuestsManager();
  local localPlayerID :number = Game.GetLocalPlayer();
  if questsManager ~= nil then
    for questInfo in GameInfo.Quests() do
      if questsManager:HasActiveQuestFromPlayer( localPlayerID, playerID, questInfo.Index) then
        kQuests[questInfo.Index] = {
          Description = questsManager:GetActiveQuestDescription( localPlayerID, playerID, questInfo.Index),
          Name    = questsManager:GetActiveQuestName( localPlayerID, playerID, questInfo.Index),
          Reward    = questsManager:GetActiveQuestReward( localPlayerID, playerID, questInfo.Index),
          Type    = questInfo.QuestType,
          Callout    = questInfo.IconString
        };
      end
    end
  else
    UI.DataError("City-States were unable to obtain the QuestManager.");
  end
  return kQuests;
end

-- ===========================================================================
--	RETURN a table of relationships for a given CityState
-- ===========================================================================
function GetRelationships( cityStateID:number )
  local kRelationships:table  = {};

  -- Civ relationships
  kRelationships.CivRelationships = {};
  for _, playerID in ipairs(PlayerManager.GetAliveMajorIDs()) do
    local pPlayer:table = Players[playerID];
    local diploStateID:number = pPlayer:GetDiplomaticAI():GetDiplomaticStateIndex( cityStateID );
    if diploStateID ~= -1 then
      local civEntry:table = {};
      
      local pPlayerConfig:table = PlayerConfigurations[playerID];
      civEntry.PlayerIcon = "ICON_" .. pPlayerConfig:GetLeaderTypeName();
      civEntry.PlayerName = pPlayerConfig:GetCivilizationShortDescription();
      civEntry.TeamID = pPlayerConfig:GetTeam();
      civEntry.DiploState = GameInfo.DiplomaticStates[diploStateID].StateType;
      civEntry.DiploTooltip = GetRelationshipDiplomaticTooltip(cityStateID, playerID, diploStateID);
      civEntry.HasMet = playerID == Game.GetLocalPlayer() or Players[Game.GetLocalPlayer()]:GetDiplomacy():HasMet( playerID )

      table.insert( kRelationships.CivRelationships, civEntry );
    end
  end

  -- City State relationships
  kRelationships.CityStateRelationships = {};
  for _, playerID in ipairs(PlayerManager.GetAliveMinorIDs()) do
    local pPlayer:table = Players[playerID];
    local diploStateID:number = pPlayer:GetDiplomaticAI():GetDiplomaticStateIndex( cityStateID );
    if diploStateID ~= -1 then
      local cityStateEntry:table = {};
      
      local pPlayerConfig:table = PlayerConfigurations[playerID];
      cityStateEntry.PlayerIcon = "ICON_" .. pPlayerConfig:GetCivilizationTypeName();
      cityStateEntry.PlayerName = pPlayerConfig:GetCivilizationShortDescription();
      cityStateEntry.TeamID = pPlayerConfig:GetTeam();
      cityStateEntry.DiploState = GameInfo.DiplomaticStates[diploStateID].StateType;
      cityStateEntry.DiploTooltip = GetRelationshipDiplomaticTooltip(cityStateID, playerID, diploStateID);
      cityStateEntry.HasMet = playerID == Game.GetLocalPlayer() or Players[Game.GetLocalPlayer()]:GetDiplomacy():HasMet( playerID )

      local primaryColor, secondaryColor = UI.GetPlayerColors( playerID );
      cityStateEntry.Color = secondaryColor;

      table.insert( kRelationships.CityStateRelationships, cityStateEntry );
    end
  end

  return kRelationships;
end

-- ===========================================================================
--	RETURN a tooltip to define a city state relationship
-- ===========================================================================
function GetRelationshipDiplomaticTooltip(cityStateID, playerID, diploStateID)
  local tooltip:string = "";

  -- Right now we don't need to worry about the diplo state as we only at war diplo pip
  -- Once we display other pips this function will need to determine the proper tooltip
  local pCityStateConfig:table = PlayerConfigurations[cityStateID];
  local pPlayerConfig:table = PlayerConfigurations[playerID];
  tooltip = Locale.Lookup("LOC_CITY_STATES_AT_WAR_WTIH", pCityStateConfig:GetCivilizationShortDescription(), pPlayerConfig:GetCivilizationShortDescription());

  return tooltip;
end

-- ===========================================================================
--  Returns the texture name and UV for a bonus icon type.
-- ===========================================================================
function GetBonusIconAtlasPieces( kCityState:table, size:number )
  local iconName:string = "";
  if     kCityState.Type == "SCIENTIFIC"    then  iconName = "ICON_ENVOY_BONUS_SCIENCE";
  elseif kCityState.Type == "RELIGIOUS"    then  iconName = "ICON_ENVOY_BONUS_FAITH";
  elseif kCityState.Type == "TRADE"      then  iconName = "ICON_ENVOY_BONUS_GOLD";
  elseif kCityState.Type == "CULTURE"      then  iconName = "ICON_ENVOY_BONUS_CULTURE";
  elseif kCityState.Type == "MILITARISTIC"  then  iconName = "ICON_ENVOY_BONUS_MILITARY";
  elseif kCityState.Type == "INDUSTRIAL"    then  iconName = "ICON_ENVOY_BONUS_PRODUCTION";
  end
  return IconManager:FindIconAtlas(iconName, size);
end

-- ===========================================================================
--  Obtain art and text related to the relationship status
--  RETURNS: atlas texture info (u, v, and image), as well as a tooltip
-- ===========================================================================
function GetRelationshipPipAtlasPieces( kCityState:table )
  local iconName  :string = DIPLO_PIP_INFO[kCityState.DiplomaticState].IconName;
  local tooltip  :string = Locale.Lookup( DIPLO_PIP_INFO[kCityState.DiplomaticState].Tooltip );
  if iconName == nil or iconName == "" then
    print("WARNING: Unexpected DiplomaticState when obtain PIP art. value:"..kCityState.DiplomaticState);
    iconName = "ICON_RELATIONSHIP_NEUTRAL";
  end
  local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas(iconName, 23);
  return textureOffsetX, textureOffsetY, textureSheet, tooltip;
end

-- ===========================================================================
--  Return the type of city-state this is in a tooltip ready form.
-- ===========================================================================
function GetTypeTooltip( kCityState:table )
  local toolTip    :string;
  if     kCityState.Type == "SCIENTIFIC"    then  toolTip   = "LOC_CITY_STATES_TYPE_SCIENTIFIC";
  elseif kCityState.Type == "RELIGIOUS"    then  toolTip   = "LOC_CITY_STATES_TYPE_RELIGIOUS";
  elseif kCityState.Type == "TRADE"      then  toolTip   = "LOC_CITY_STATES_TYPE_TRADE";
  elseif kCityState.Type == "CULTURE"      then  toolTip   = "LOC_CITY_STATES_TYPE_CULTURAL";
  elseif kCityState.Type == "MILITARISTIC"  then  toolTip   = "LOC_CITY_STATES_TYPE_MILITARISTIC";
  elseif kCityState.Type == "INDUSTRIAL"    then  toolTip   = "LOC_CITY_STATES_TYPE_INDUSTRIAL";
  else
    UI.DataError("WARNING: Unknown type '"..kCityState.Type.."' for getting the City-State tooltip.");
    return 0,0,"","";
  end
  return toolTip;
end

-- ===========================================================================
--  Returns the texture name and UV for a given City-States type, also a
--  tooltip describing that type.
-- ===========================================================================
function GetTypeAtlasPieces( kCityState:table, size:number )
  local iconName    :string;
  if     kCityState.Type == "SCIENTIFIC"    then  iconName = "ICON_CITYSTATE_SCIENCE";
  elseif kCityState.Type == "RELIGIOUS"    then  iconName = "ICON_CITYSTATE_FAITH";
  elseif kCityState.Type == "TRADE"      then  iconName = "ICON_CITYSTATE_TRADE";
  elseif kCityState.Type == "CULTURE"      then  iconName = "ICON_CITYSTATE_CULTURE";
  elseif kCityState.Type == "MILITARISTIC"  then  iconName = "ICON_CITYSTATE_MILITARISTIC";
  elseif kCityState.Type == "INDUSTRIAL"    then  iconName = "ICON_CITYSTATE_INDUSTRIAL";
  else
    UI.DataError("WARNING: Unknown type '"..kCityState.Type.."' for getting the City-State icon (at size "..tostring(size)..")");
    return 0,0,"","";
  end

  local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas(iconName, size);
  return textureOffsetX, textureOffsetY, textureSheet;
end

-- ===========================================================================
--  Returns the texture name and UV for a bonus icon type.
-- ===========================================================================
function GetTypeName( kCityState:table )
  if     kCityState.Type == "SCIENTIFIC"    then  return Locale.Lookup("LOC_CITY_STATES_TYPE_SCIENTIFIC");
  elseif kCityState.Type == "RELIGIOUS"    then  return Locale.Lookup("LOC_CITY_STATES_TYPE_RELIGIOUS");
  elseif kCityState.Type == "TRADE"      then  return Locale.Lookup("LOC_CITY_STATES_TYPE_TRADE");
  elseif kCityState.Type == "CULTURE"      then  return Locale.Lookup("LOC_CITY_STATES_TYPE_CULTURAL");
  elseif kCityState.Type == "MILITARISTIC"  then  return Locale.Lookup("LOC_CITY_STATES_TYPE_MILITARISTIC");
  elseif kCityState.Type == "INDUSTRIAL"    then  return Locale.Lookup("LOC_CITY_STATES_TYPE_INDUSTRIAL");
  end
  return "unknownType'"..kCityState.Type.."'";
end

-- ===========================================================================
--  Sum up the envoy changes the player is proposing to make (but not
--  submitted to the game engine).
--  RETURNS: # of envoy token changes across all City States
-- ===========================================================================
function SumEnvoyChanges()
  local sum:number = 0;
  for _,value in pairs( m_kEnvoyChanges ) do
    sum = sum + value;
  end
  return sum;
end

-- ===========================================================================
function Close()
  m_kEnvoyChanges = {};    -- Zero out any pending envoy choices

    if not ContextPtr:IsHidden() then
        UI.PlaySound("CityStates_Panel_Close");
    end

    local localPlayerID = Game.GetLocalPlayer();
    if (localPlayerID ~= -1) then
      local localPlayer = Players[localPlayerID];
      if (localPlayer ~= nil and localPlayer:GetInfluence() ~= nil and not localPlayer:GetInfluence():IsGivingTokensConsidered()) then
        localPlayer:GetInfluence():SetGivingTokensConsidered(true);
      end
    end

    m_kScreenSlideAnim.Hide();
end

-- ===========================================================================
--  UI Callback
--  Clicking close on interface.
-- ===========================================================================
function OnClose()
  Close();
end

-- ===========================================================================
--  UI Callback
--  Go back to the main list view.
-- ===========================================================================
function OnBackClose()
  if m_kPlayerData.EnvoyTokens ~= nil and m_kPlayerData.EnvoyTokens > 0 then
    m_mode = MODE.SendEnvoys;
  else
    m_mode = MODE.Overview;
  end
  Refresh();
end

-- ===========================================================================
--  LUA Event
--  Explicit close (from partial screen hooks), part of closing everything,
-- ===========================================================================
function OnCloseAllExcept( contextToStayOpen:string )
  if contextToStayOpen == ContextPtr:GetID() then return; end
  Close();
end

-- ===========================================================================
--  LUA Event
--  Explicit close called from else-where.
-- ===========================================================================
function OnCloseCityStates()
  Close();
end


-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnOpenCityStates()
  OpenOverview();
end

-- ===========================================================================
--  LUA Event
--  Open up the screen.
--  iPlayer  (optional) the player number for the city state to focus on, if
--      -1 or nil it will show an overview list.
-- ===========================================================================
function OpenOverview( iPlayer:number )
  -- dont show panel if there is no local player
  local localPlayerID = Game.GetLocalPlayer();
  if (localPlayerID == -1) then
    return
  end

  UI.PlaySound("CityStates_Panel_Open");
  m_mode = MODE.Overview;
  m_kScreenSlideAnim.Show();
  Refresh();
end


-- ===========================================================================
--  LUA Event
--  Open up the screen for envoy sending.
--  iPlayer  (optional) the player number for the city state to focus on, if
--      -1 or nil it will show an overview list.
-- ===========================================================================
function OnOpenSendEnvoys( iPlayer:number )
  -- dont show panel if there is no local player
  local localPlayerID = Game.GetLocalPlayer();
  if (localPlayerID == -1) then
    return
  end

  m_mode = MODE.SendEnvoys;
  UI.PlaySound("CityStates_Panel_Open");
  m_kScreenSlideAnim.Show();
  Refresh();
end


-- ===========================================================================
--  LUA EVENT
--  Open panel pointing to a specific City State
-- ===========================================================================
function OnRaiseMinorCivicsPanel( playerID:number )
  OpenSingleViewCityState( playerID );
end

-- ===========================================================================
--  Open panel pointing to a specific City State
-- ===========================================================================
function OpenSingleViewCityState( playerID:number )
  -- dont show panel if there is no local player
  local localPlayerID = Game.GetLocalPlayer();
  if (localPlayerID == -1) then
    return
  end

  if m_mode == MODE.Overview or m_mode == MODE.SendEnvoys then
    m_mode = MODE.EnvoySent;
  end

  UI.PlaySound("CityStates_Panel_Open");
  m_iCurrentCityState = playerID;
  m_kScreenSlideAnim.Show();
  Refresh();
  LookAtCityState( playerID );
end



-- ===========================================================================
--  Obtain latest data and display it.
-- ===========================================================================
function Refresh()
  GetData();
  if m_mode == MODE.Overview or m_mode == MODE.SendEnvoys then
    ViewList();
  else
    -- If no city state is selected, then change to the overview.
    if m_iCurrentCityState == -1 then
      m_mode = MODE.Overview;
      ViewList();
    else
      ViewCityState( m_iCurrentCityState );
    end
  end
end

-- ===========================================================================
--  Helper to realize an envoy's contents and size of font use
-- ===========================================================================
function RealizeEnvoyToken( total:number, control:table )
  if total < 10 then
    control:SetFontSize(FONT_SIZE_SINGLE_DIGIT_ENVOYS);
  elseif total < 100 then
    control:SetFontSize(FONT_SIZE_TWO_DIGIT_ENVOYS);
  else
    control:SetFontSize(FONT_SIZE_THREE_DIGIT_ENVOYS);  -- So much envoy!
  end
  control:SetText( total );
end

-- ===========================================================================
function RealizeListHeader()
  local sum:number = SumEnvoyChanges();

  if (m_kPlayerData.EnvoyTokens - sum) < 0 then
    UI.DataError("Less envoy tokens than going into the deploy envoy.");
  end

  local header:string = Locale.ToUpper(Locale.Lookup("LOC_CITY_STATES_OVERVIEW"));
  if m_mode == MODE.SendEnvoys then
    header = Locale.ToUpper( Locale.Lookup("LOC_CITY_STATES_SEND_ENVOYS", (m_kPlayerData.EnvoyTokens - sum)) );
    header = header .. " " .. Locale.Lookup("LOC_CITY_STATES_SEND_ENVOY_AMOUNT", (m_kPlayerData.EnvoyTokens - sum)) .. " ";  --HACK: space on end due to textcontrol bug, see below
  end
  --TODO: Space after [ICON..] breaks smallcaps?! ??TRON: header="SEND ENVOYS (2[ICON_Envoy] )";
  --print("Envoy Header:",header);
  Controls.Header:SetText( header );

  local localPlayer = Players[Game.GetLocalPlayer()];
  if (localPlayer == nil) then
    return;
  end

  local playerInfluence  :table  = localPlayer:GetInfluence();
  local influenceBalance  :number  = Round(playerInfluence:GetPointsEarned(), 1);
  local influenceRate    :number = Round(playerInfluence:GetPointsPerTurn(), 1);
  local influenceThreshold:number  = playerInfluence:GetPointsThreshold();
  local envoysPerThreshold:number = playerInfluence:GetTokensPerThreshold();
  local currentEnvoys    :number = playerInfluence:GetTokensToGive();

  local envoyDetails:string = Locale.Lookup("LOC_TOP_PANEL_INFLUENCE_TOOLTIP_POINTS_THRESHOLD", envoysPerThreshold, influenceThreshold);
  Controls.EnvoyDetails:SetText(envoyDetails);

  local sTooltip:string = "";
  if (currentEnvoys > 0) then
    sTooltip = sTooltip .. Locale.Lookup("LOC_TOP_PANEL_INFLUENCE_TOOLTIP_ENVOYS", currentEnvoys);
    sTooltip = sTooltip .. "[NEWLINE][NEWLINE]";
  end
  sTooltip = sTooltip .. Locale.Lookup("LOC_TOP_PANEL_INFLUENCE_TOOLTIP_POINTS_THRESHOLD", envoysPerThreshold, influenceThreshold);
  sTooltip = sTooltip .. "[NEWLINE][NEWLINE]";
  sTooltip = sTooltip .. Locale.Lookup("LOC_TOP_PANEL_INFLUENCE_TOOLTIP_POINTS_BALANCE", influenceBalance);
  sTooltip = sTooltip .. "[NEWLINE]";
  sTooltip = sTooltip .. Locale.Lookup("LOC_TOP_PANEL_INFLUENCE_TOOLTIP_POINTS_RATE", influenceRate);
  sTooltip = sTooltip .. "[NEWLINE][NEWLINE]";
  sTooltip = sTooltip .. Locale.Lookup("LOC_TOP_PANEL_INFLUENCE_TOOLTIP_SOURCES_HELP");

  local meterRatio = influenceBalance / influenceThreshold;
  if (meterRatio < 0) then
    meterRatio = 0;
  elseif (meterRatio > 1) then
    meterRatio = 1;
  end
  Controls.EnvoysMeter:SetPercent(meterRatio);
  Controls.Envoys:SetToolTipString(sTooltip);
  Controls.EnvoysStack:CalculateSize();
  Controls.EnvoysStack:ReprocessAnchoring();
end

-- ===========================================================================
--  Enable/Disable change buttons
-- ===========================================================================
function RealizeEnvoyChangeButtons()
  local sum:number = SumEnvoyChanges();

  -- Enable/disable every button based on if any more tokens can be given out.
  local totalLeft    :number = (m_kPlayerData.EnvoyTokens - sum);
  local isMoreDisabled:boolean = not m_isLocalPlayerTurn or (totalLeft == 0);
  local isLessDisabled:boolean = not m_isLocalPlayerTurn or (sum <= 0);

  -- Likely going away so even if warring envoys can still be sent.
  for iPlayer,inst in pairs( m_uiCityStateRows ) do
    inst.EnvoyMoreButton:SetDisabled( isMoreDisabled or (not m_kCityStates[iPlayer].CanReceiveTokensFrom) );
    inst.EnvoyLessButton:SetDisabled( isLessDisabled or (not m_kCityStates[iPlayer].CanReceiveTokensFrom) );
    local amount:number = m_kEnvoyChanges[iPlayer];
    inst.EnvoyLessButton:SetHide( amount == nil or amount == 0 );
    if m_kCityStates[iPlayer].isAlive then
      -- Also check if we're not at war due to some edge cases where we can't receive tokens but aren't at war
      if m_kCityStates[iPlayer].CanReceiveTokensFrom or not m_kCityStates[iPlayer].isAtWar then
        inst.EnvoyMoreButton:SetToolTipString( Locale.Lookup("LOC_CITY_STATES_ADD_AN_ENVOY") );
        inst.EnvoyLessButton:SetToolTipString( Locale.Lookup("LOC_CITY_STATES_REMOVE_AN_ENVOY") );
        inst.Envoy:SetToolTipString( nil );
      else
        local tooltip:string = Locale.Lookup("LOC_CITY_STATES_CURRENTLY_AT_WAR");
        inst.EnvoyMoreButton:SetToolTipString( tooltip );
        inst.EnvoyLessButton:SetToolTipString( tooltip );
        inst.Envoy:SetToolTipString( tooltip );
      end
    else
      local tooltip:string = Locale.Lookup("LOC_CITY_STATES_DESTROYED_LONG");
      inst.EnvoyMoreButton:SetToolTipString( tooltip );
      inst.EnvoyLessButton:SetToolTipString( tooltip );
      inst.Envoy:SetToolTipString( tooltip );
    end
  end

  Controls.ConfirmButton:SetDisabled(not m_isLocalPlayerTurn or sum == 0);
end

-- ===========================================================================
function OnLessEnvoyTokens( iPlayer:number )

  local amount :number = m_kEnvoyChanges[iPlayer];
  if amount == nil then
    amount = 0;
  end
  amount = amount - 1;
  if amount < 0 then
    -- Do nothing, below the initial value
    m_kEnvoyChanges[iPlayer] = nil;
    return;
  end
  m_kEnvoyChanges[iPlayer] = amount;
  m_uiCityStateRows[iPlayer].EnvoyLessButton:SetDisabled( m_kEnvoyChanges[iPlayer] == 0 );

  UI.PlaySound("UI_Click_Sweetener_Metal_Button_Small");

  RealizeEnvoyChangeButtons();
  RealizeEnvoyToken(m_kCityStates[iPlayer].Tokens + m_kEnvoyChanges[iPlayer], m_uiCityStateRows[iPlayer].EnvoyCount);
  RealizeListHeader();
end

-- ===========================================================================
function OnMoreEnvoyTokens( iPlayer:number )

  local amount :number = m_kEnvoyChanges[iPlayer];
  if amount == nil then
    amount = 1;
  else
    amount = amount + 1;
  end
  m_kEnvoyChanges[iPlayer] = amount;

  UI.PlaySound("UI_Click_Sweetener_Metal_Button_Small");

  RealizeEnvoyChangeButtons();
  RealizeEnvoyToken( m_kCityStates[iPlayer].Tokens + m_kEnvoyChanges[iPlayer], m_uiCityStateRows[iPlayer].EnvoyCount);
  RealizeListHeader();
end

-- ===========================================================================
--  Confirm where Envoy tokens are going
-- ===========================================================================
function OnConfirmPlacement()
  local playerID    :number= Game.GetLocalPlayer();
  local pLocalPlayer  :table = Players[playerID];
  local sum      :number = SumEnvoyChanges();
  local totalLeft    :number = (m_kPlayerData.EnvoyTokens - sum);

  if pLocalPlayer ~= nil then
    for cityStatePlayerID,numTokens in pairs(m_kEnvoyChanges) do
      for i=1,numTokens,1 do
        local parameters:table = {};
        parameters[ PlayerOperations.PARAM_PLAYER_ONE ] = cityStatePlayerID;
        UI.RequestPlayerOperation( playerID, PlayerOperations.GIVE_INFLUENCE_TOKEN, parameters);
      end
    end
    m_kEnvoyChanges    = {};
    m_kLastCityStates  = m_kCityStates;  -- Save last city states to check against once an update occurs
    UI.PlaySound("Click_Confirm");
    if totalLeft < 1 then          -- If no changes are left to be made, we're done here; goodbye.
      Close();
    end
  else
    UI.DataError("Unable to get a valid local player when confirming envoy tokens.");
  end
end

-- ===========================================================================
--  UI Callback
-- ===========================================================================
function OnEnvoySentClick()
  m_mode = MODE.EnvoySent;
  Refresh();
end

-- ===========================================================================
--  UI Callback
-- ===========================================================================
function OnInfluencedByClick()
  m_mode = MODE.InfluencedBy;
  Refresh();
end

-- ===========================================================================
--  UI Callback
-- ===========================================================================
function OnQuestsClick()
  m_mode = MODE.Quests;
  Refresh();
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnRelationshipsClick()
  m_mode = MODE.Relationships;
  Refresh();
end

-- ===========================================================================
--  Change from WAR to peace or peace to WAR with a City-State
-- ===========================================================================
function OnChangeWarPeaceStatus( kCityState:table )
  local iPlayer    :number = kCityState.iPlayer;
  local localPlayerID :number = Game.GetLocalPlayer();
  local pLocalPlayer  :table  = Players[localPlayerID];

  if pLocalPlayer ~= nil then
    if kCityState.isAtWar then
      local parameters :table = {};
      parameters[ PlayerOperations.PARAM_PLAYER_ONE ] = localPlayerID;
      parameters[ PlayerOperations.PARAM_PLAYER_TWO ] = iPlayer;
      UI.RequestPlayerOperation( localPlayerID, PlayerOperations.DIPLOMACY_MAKE_PEACE, parameters);
    else
      LuaEvents.CityStates_ConfirmWarDialog(localPlayerID, iPlayer, WarTypes.SURPRISE_WAR);
    end
  else
    UI.DataError("Could not get local player to declare war on city state '"..kCityState.Name.."'.");
  end
end

-- ===========================================================================
--  Levy the Military of a City-State
-- ===========================================================================
function OnLevyMilitary( kCityState:table)
  local iPlayer    :number = kCityState.iPlayer;
  local localPlayerID :number = Game.GetLocalPlayer();
  local pLocalPlayer  :table  = Players[localPlayerID];

  if pLocalPlayer ~= nil then
    local parameters :table = {};
    parameters[ PlayerOperations.PARAM_PLAYER_ONE ] = iPlayer;
    UI.RequestPlayerOperation(localPlayerID, PlayerOperations.LEVY_MILITARY, parameters);
  else
    UI.DataError("Could not get local player to levy military from city state '"..kCityState.Name.."'.");
  end
end


-- ===========================================================================
function AddCityStateRow( kCityState:table )

  local kInst        :table = m_CityStateRowIM:GetInstance();
  local textureOffsetX  :number;
  local textureOffsetY  :number;
  local textureSheet    :string;
  local questToolTip    :string = Locale.Lookup("LOC_CITY_STATES_QUESTS");
  local numQuests      :number = 0;
  local cityStateName    :string = Locale.ToUpper( Locale.Lookup(kCityState.Name) .. (kCityState.isAlive and "" or "("..Locale.Lookup("LOC_CITY_STATES_DESTROYED")..")") );

  -- Set name, truncate if necessary
  kInst.NameLabel:SetText( cityStateName );
  local targetSize:number = (kInst.NameButton:GetSizeX() - 12);
  TruncateStringWithTooltip(kInst.NameLabel, targetSize, cityStateName);

  kInst.NameLabel:SetColor( kCityState.ColorSecondary );
  kInst.NameButton:SetColor( Mouse.eLClick, function() OpenSingleViewCityState( kCityState.iPlayer ) end );
  kInst.NameButton:RegisterCallback( Mouse.eLClick, function() OpenSingleViewCityState( kCityState.iPlayer ) end );

  textureOffsetX, textureOffsetY, textureSheet, tooltip = GetRelationshipPipAtlasPieces( kCityState );
  kInst.DiplomacyPip:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
  if GameCapabilities.HasCapability("CAPABILITY_MILITARY") then
    kInst.DiplomacyPip:SetToolTipString(tooltip);
  end

  for _,kQuest in pairs( kCityState.Quests ) do
    numQuests = numQuests + 1;
    questToolTip = questToolTip .. "[NEWLINE]" .. kQuest.Callout .. kQuest.Name;
  end
  kInst.QuestIcon:SetHide(numQuests <= 0);
  kInst.QuestIcon:SetToolTipString(questToolTip);

  RealizeEnvoyToken( kCityState.Tokens, kInst.EnvoyCount);
  kInst.EnvoyLessButton:SetDisabled( true );
  kInst.EnvoyLessButton:SetHide( m_mode ~= MODE.SendEnvoys );
  kInst.EnvoyMoreButton:SetHide( m_mode ~= MODE.SendEnvoys );
  kInst.EnvoyLessButton:SetVoid1( kCityState.iPlayer );
  kInst.EnvoyMoreButton:SetVoid1( kCityState.iPlayer );
  kInst.EnvoyLessButton:RegisterCallback( Mouse.eLClick, OnLessEnvoyTokens );
  kInst.EnvoyMoreButton:RegisterCallback( Mouse.eLClick, OnMoreEnvoyTokens );

  -- Get small icons
  textureOffsetX, textureOffsetY, textureSheet = GetBonusIconAtlasPieces( kCityState, 26 );

  kInst.BonusImage1:SetTexture( kCityState.isBonus1 and "CityState_BonusSlotOn" or "CityState_BonusSlotOff" );
  kInst.BonusImage1:SetToolTipString( kCityState.Bonuses[1].Title .."[NEWLINE]".. kCityState.Bonuses[1].Details );

  kInst.BonusIcon1:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
  kInst.BonusIcon1:SetColor( kCityState.isBonus1 and kCityState.ColorSecondary or COLOR_ICON_BONUS_OFF );
  kInst.BonusText1:SetColor( kCityState.isBonus1 and COLOR_TEXT_BONUS_ON or COLOR_TEXT_BONUS_OFF )
  kInst.BonusImage3:SetTexture( kCityState.isBonus3 and "CityState_BonusSlotOn" or "CityState_BonusSlotOff" );
  kInst.BonusImage3:SetToolTipString( kCityState.Bonuses[3].Title .."[NEWLINE]".. kCityState.Bonuses[3].Details );
  kInst.BonusIcon3:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
  kInst.BonusIcon3:SetColor( kCityState.isBonus3 and kCityState.ColorSecondary or COLOR_ICON_BONUS_OFF );
  kInst.BonusText3:SetColor( kCityState.isBonus3 and COLOR_TEXT_BONUS_ON or COLOR_TEXT_BONUS_OFF )
  kInst.BonusImage6:SetTexture( kCityState.isBonus6 and "CityState_BonusSlotOn" or "CityState_BonusSlotOff" );
  kInst.BonusImage6:SetToolTipString( kCityState.Bonuses[6].Title .."[NEWLINE]".. kCityState.Bonuses[6].Details );
  kInst.BonusIcon6:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
  kInst.BonusIcon6:SetColor( kCityState.isBonus6 and kCityState.ColorSecondary or COLOR_ICON_BONUS_OFF );
  kInst.BonusText6:SetColor( kCityState.isBonus6 and COLOR_TEXT_BONUS_ON or COLOR_TEXT_BONUS_OFF )
  kInst.BonusImageSuzerainOff:SetHide( kCityState.isBonusSuzerain );
  kInst.BonusImageSuzerainOff:SetColor( COLOR_ICON_BONUS_OFF );
  kInst.BonusImageSuzerainOn:SetHide( not kCityState.isBonusSuzerain );
  kInst.BonusImageSuzerainOn:SetColor( COLOR_ICON_BONUS_ON );
  kInst.BonusImageSuzerainOff:SetToolTipString( kCityState.Bonuses["Suzerain"].Title .."[NEWLINE]".. kCityState.Bonuses["Suzerain"].Details );
  kInst.BonusImageSuzerainOn:SetToolTipString( kCityState.Bonuses["Suzerain"].Title .."[NEWLINE]".. kCityState.Bonuses["Suzerain"].Details );
  kInst.BonusIconSuzerain:SetColor( kCityState.isBonusSuzerain and kCityState.ColorSecondary or COLOR_ICON_BONUS_OFF );
  kInst.BonusTextSuzerain:SetColor( kCityState.isBonusSuzerain and kCityState.ColorSecondary or COLOR_TEXT_BONUS_OFF );
  kInst.BonusTextSuzerain:SetText( kCityState.SuzerainTokensNeeded );
  kInst.SuzerainLabel:SetColor( kCityState.isBonusSuzerain and kCityState.ColorSecondary or COLOR_ICON_BONUS_OFF );
  kInst.Suzerain:SetColor( kCityState.isBonusSuzerain and kCityState.ColorSecondary or COLOR_ICON_BONUS_OFF );
  kInst.Suzerain:SetText( CQUI_TruncateSuzerainName(kCityState.SuzerainName) );

  -- Begin CQUI Changes Marker
  local localPlayerID = Game.GetLocalPlayer();
  local secondHighestName :string = "";
  local highestEnvoys :number = 0;
  local secondHighestEnvoys :number = 0;
  local secondHighestIsPlayer :boolean = false;

  -- Iterate through all players that have influenced this city state
  for iOtherPlayer,influence in pairs(kCityState.Influence) do
    local pLocalPlayer  :table  = Players[localPlayerID];
    local civName    :string = "LOCAL_CITY_STATES_UNKNOWN";
    if (pLocalPlayer ~= nil) then
      local pPlayerConfig :table = PlayerConfigurations[iOtherPlayer];
      if (localPlayerID == iOtherPlayer) then
        civName = Locale.Lookup("LOC_CITY_STATES_YOU");
      elseif (pLocalPlayer:GetDiplomacy():HasMet(iOtherPlayer)) then
        civName = pPlayerConfig:GetPlayerName();
      end
    end
    -- Grab the second highest number of envoys plus the name of that civ. Prioritizes picking the player if there are ties.
    if (influence > highestEnvoys) then
      highestEnvoys = influence;
    elseif (influence >= secondHighestEnvoys and localPlayerID == iOtherPlayer) then
      secondHighestIsPlayer = true;
      secondHighestEnvoys = influence;
      secondHighestName = Locale.Lookup( civName );
    elseif (influence > secondHighestEnvoys ) then
      secondHighestIsPlayer = false;
      secondHighestEnvoys = influence;
      secondHighestName = Locale.Lookup( civName );
    end
  end

  -- Add changes to the actual UI object placeholders, which are created in the CityStates.xml file
  kInst.SecondHighestLabel:SetColor( secondHighestIsPlayer and kCityState.ColorSecondary or COLOR_ICON_BONUS_OFF );
  -- CQUI Note: SecondHighestLabel needs to be localized, but is hard coded for now
  kInst.SecondHighestLabel:SetText( "2nd" );
  kInst.SecondHighestName:SetColor( secondHighestIsPlayer and kCityState.ColorSecondary or COLOR_ICON_BONUS_OFF );
  kInst.SecondHighestName:SetText( CQUI_TruncateSuzerainName(secondHighestName) );
  kInst.SecondHighestEnvoys:SetColor( secondHighestIsPlayer and kCityState.ColorSecondary or COLOR_ICON_BONUS_OFF );
  kInst.SecondHighestEnvoys:SetText( secondHighestEnvoys );
  -- End CQUI Changes Marker

  kInst.LookAtButton:SetVoid1( kCityState.iPlayer );
  kInst.LookAtButton:RegisterCallback( Mouse.eLClick, LookAtCityState );

  kInst.Icon:SetIcon( "ICON_"..kCityState.CivType );
  kInst.Icon:SetToolTipString( Locale.Lookup( GetTypeTooltip(kCityState) ));
  kInst.Icon:SetColor( kCityState.ColorSecondary );
  kInst.Button:RegisterCallback( Mouse.eLClick, function() OpenSingleViewCityState( kCityState.iPlayer ) end );

  return kInst;
end

function CQUI_TruncateSuzerainName( name:string )
  if(name:len() >= 12) then
    return string.sub(name, 0, 10) .. "...";
  else
    return name;
  end
end

-- ===========================================================================
--  View a list of all the City States that are alive and have been met.
-- ===========================================================================
function ViewList()

  local localPlayerID = Game.GetLocalPlayer();
  if (localPlayerID == -1) then
    return;
  end

  if (m_kPlayerData == nil or m_kPlayerData.EnvoyTokens == nil) then
    return;
  end

  -- Last minute switch; if there are envoy tokens left and at least one City-State has
  -- been met, then allow player to change the # of envoys sent.
  local numMet:number = GetCityStatesMetNum();
  if m_kPlayerData.EnvoyTokens > 0 and numMet > 0 then
    m_mode = MODE.SendEnvoys;
  else
    m_mode = MODE.Overview;
  end
  Controls.NoneMet:SetHide( numMet > 0 );

  Controls.ListOfCityStates:SetHide( false );
  Controls.SingleCityState:SetHide( true );
  RealizeListHeader( m_kPlayerData.EnvoyTokens );

  -- Top list
  m_CityStateRowIM:ResetInstances();
  m_uiCityStateRows = {};
  for iPlayer, kCityState in pairs( m_kCityStates ) do
    if kCityState.isHasMet then
      local kInst :table = AddCityStateRow( kCityState );
      m_uiCityStateRows[iPlayer] = kInst;
    end
  end

  if m_mode == MODE.SendEnvoys then
    Controls.BonusArea:SetHide( false );

    -- Looping again, adding bonuses.
    m_BonusCityHeaderIM:ResetInstances();
    m_BonusItemIM:ResetInstances();
    for iPlayer, kCityState in pairs( m_kCityStates ) do

      -- At least the simplest of bonuses?
      if kCityState.isBonus1 then
        local kHeader  :table = m_BonusCityHeaderIM:GetInstance();
        kHeader.CityName:SetText( Locale.ToUpper(  kCityState.Name ) );

        local kItem    :table = m_BonusItemIM:GetInstance();
        local textureOffsetX, textureOffsetY, textureSheet = GetBonusIconAtlasPieces( kCityState, 50 );
        kItem.Icon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
        kItem.Icon:SetColor( kCityState.ColorSecondary );
        kItem.Title:SetColor( kCityState.ColorSecondary );
        kItem.Title:SetText( kCityState.Bonuses[NUM_ENVOY_TOKENS_FOR_FIRST_BONUS].Title );
        kItem.Details:SetText( kCityState.Bonuses[NUM_ENVOY_TOKENS_FOR_FIRST_BONUS].Details );

        if kCityState.isBonus3 then
          kItem    = m_BonusItemIM:GetInstance();
          kItem.Icon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );  -- Same as above
          kItem.Icon:SetColor( kCityState.ColorSecondary );
          kItem.Title:SetColor( kCityState.ColorSecondary );
          kItem.Title:SetText( kCityState.Bonuses[NUM_ENVOY_TOKENS_FOR_SECOND_BONUS].Title );
          kItem.Details:SetText( kCityState.Bonuses[NUM_ENVOY_TOKENS_FOR_SECOND_BONUS].Details );
        end

        if kCityState.isBonus6 then
          kItem    = m_BonusItemIM:GetInstance();
          kItem.Icon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );  -- Same as above
          kItem.Icon:SetColor( kCityState.ColorSecondary );
          kItem.Title:SetColor( kCityState.ColorSecondary );
          kItem.Title:SetText( kCityState.Bonuses[NUM_ENVOY_TOKENS_FOR_THIRD_BONUS].Title );
          kItem.Details:SetText( kCityState.Bonuses[NUM_ENVOY_TOKENS_FOR_THIRD_BONUS].Details );
        end

        if kCityState.isBonusSuzerain then
          kItem    = m_BonusItemIM:GetInstance();
          textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas("ICON_ENVOY_BONUS_SUZERAIN", 50);
          kItem.Icon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
          kItem.Icon:SetColor( kCityState.ColorSecondary );
          kItem.Title:SetColor( kCityState.ColorSecondary );
          TruncateStringWithTooltip(kItem.Title, MAX_BEFORE_TRUNC_SUZERAIN, Locale.Lookup(kCityState.Bonuses["Suzerain"].Title));
          kItem.Details:SetText( kCityState.Bonuses["Suzerain"].Details );
          local PADDING:number = 40;
          kItem.Top:SetSizeY( kItem.Details:GetSizeY() + PADDING );
        end

      end
    end

    Controls.BonusStack:CalculateSize();
    Controls.BonusScroll:CalculateSize();
    Controls.BonusArea:ReprocessAnchoring();

    local bonusAreaY:number = Controls.BonusArea:GetSizeY();
    Controls.CityStateScroll:SetSizeY( m_height - (264 + bonusAreaY ) );

  else
    Controls.BonusArea:SetHide( true );
    Controls.CityStateScroll:SetSizeY( m_height - 210 );
  end

  Controls.ConfirmFrame:SetHide( m_mode ~= MODE.SendEnvoys );
  Controls.ConfirmButton:SetDisabled( true );

  Controls.CityStateStack:CalculateSize();
  Controls.CityStateScroll:CalculateSize();

  RealizeEnvoyChangeButtons();
end


-- ===========================================================================
function ColorizeBonusItem( isHaveBonus:boolean, pInst:table, kCityState:table)
  pInst.Check:SetHide( not isHaveBonus );
  if isHaveBonus then
    pInst.Icon:SetColor( kCityState.ColorSecondary );
    pInst.Title:SetColor( kCityState.ColorSecondary );
    pInst.Details:SetColorByName("CityStateCS");
  else
    pInst.Icon:SetColorByName("CityStateDisabledCS");
    pInst.Title:SetColorByName("CityStateDisabledCS");
    pInst.Details:SetColorByName("CityStateDisabledCS");
  end
end

-- ===========================================================================
--  View detailed information for a single City State
-- ===========================================================================
function ViewCityState( iPlayer:number )

  local localPlayerID = Game.GetLocalPlayer();
  if (localPlayerID == -1) then
    return;
  end

  local pLocalPlayer:table = Players[localPlayerID];
  local pLocalPlayerDiplomacy:table = pLocalPlayer:GetDiplomacy();
  
  -- Create a column of City-States on the left side so a player can click
  -- and instantly view them.
  m_CityStateColumnIM:ResetInstances();
  m_uiCityStateRows = {};
  for _, kCityState in pairs( m_kCityStates ) do
    if kCityState.isHasMet then
      local kInst :table = m_CityStateColumnIM:GetInstance();
      kInst.Icon:SetIcon( "ICON_"..kCityState.CivType );
      kInst.Icon:SetColor( kCityState.ColorSecondary );
      kInst.Icon:SetToolTipString( Locale.Lookup(kCityState.Name) );

      kInst.IconButton:SetColor( kCityState.ColorPrimary );
      kInst.IconButton:SetVoid1( kCityState.iPlayer );
      kInst.IconButton:RegisterCallback( Mouse.eLClick, OpenSingleViewCityState );

      textureOffsetX, textureOffsetY, textureSheet, tooltip = GetRelationshipPipAtlasPieces( kCityState );
      kInst.DiplomacyPip:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
      if GameCapabilities.HasCapability("CAPABILITY_MILITARY") then
        kInst.DiplomacyPip:SetToolTipString(tooltip);
      end
    end
  end
  Controls.CityStateIconStack:CalculateSize();

  -- Grab city state, and then sanity check.  (We did have an error where a liberated city wasn't updated in the
  -- cache and so if a player clicked the banner it would immediately bail.)
  local kCityState:table= m_kCityStates[iPlayer];
  if kCityState == nil then
    UI.DataError("Attempt to show details for CityState player #"..tostring(iPlayer)..", but that doesn't exist!");

    -- Best attempt to salvage error is to show the list view.
    m_mode = MODE.Overview;
    ViewList();
    return;
  end

  Controls.ListOfCityStates:SetHide( true);
  Controls.SingleCityState:SetHide( false );

  Controls.CityStateTypeIcon:SetIcon("ICON_"..kCityState.CivType);
  Controls.CityStateTypeIcon:SetColor( kCityState.ColorSecondary );
  Controls.CityStateTypeIcon:SetToolTipString( Locale.Lookup( GetTypeTooltip(kCityState) ));
  Controls.CityStateName:SetText( Locale.ToUpper(kCityState.Name) );

  local textureOffsetX, textureOffsetY, textureSheet, tooltip = GetRelationshipPipAtlasPieces( kCityState );
  Controls.DiplomacyPip:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
  if GameCapabilities.HasCapability("CAPABILITY_MILITARY") then
    Controls.DiplomacyPip:SetToolTipString(tooltip);
  end
  
  if GameCapabilities.HasCapability("CAPABILITY_MILITARY") then
    Controls.PeaceWarButton:SetHide(false);
    local warPeaceTooltip:string = "";
    if kCityState.isAtWar then
      Controls.PeaceWarButton:SetText( Locale.Lookup("LOC_CITY_STATES_MAKE_PEACE") );
      Controls.PeaceWarButton:SetDisabled( not kCityState.CanMakePeaceWith );		
      if not kCityState.CanMakePeaceWith then
        if(GlobalParameters.DIPLOMACY_WAR_LAST_FOREVER == 1 or GlobalParameters.DIPLOMACY_WAR_LAST_FOREVER == true) then
          warPeaceTooltip = warPeaceTooltip .. Locale.Lookup("LOC_CITY_STATES_TURNS_WAR_NO_PEACE");
        else
          if kCityState.SuzerainID ~= -1 and pLocalPlayerDiplomacy:IsAtWarWith(kCityState.SuzerainID) then
            warPeaceTooltip = warPeaceTooltip .. Locale.Lookup("LOC_CITY_STATES_SUZERAIN_WAR_NO_PEACE");
          else
            warPeaceTooltip = warPeaceTooltip .. Locale.Lookup("LOC_CITY_STATES_TURNS_WAR", m_iTurnsOfWar + kCityState.iTurnChanged - Game.GetCurrentGameTurn() );
          end
        end
      end
    else
      Controls.PeaceWarButton:SetText( Locale.Lookup("LOC_CITY_STATES_DECLARE_WAR_BUTTON") );
      Controls.PeaceWarButton:SetDisabled( not kCityState.CanDeclareWarOn );
      warPeaceTooltip = warPeaceTooltip .. Locale.Lookup("LOC_CITY_STATES_DECLARE_WAR_DETAILS");
      if not kCityState.CanDeclareWarOn then
        warPeaceTooltip = warPeaceTooltip .. " " .. Locale.Lookup("LOC_CITY_STATES_TURNS_PEACE", m_iTurnsOfPeace + kCityState.iTurnChanged - Game.GetCurrentGameTurn() );
      end
    end
    Controls.PeaceWarButton:SetToolTipString( warPeaceTooltip );
    Controls.PeaceWarButton:RegisterCallback( Mouse.eLClick, function() OnChangeWarPeaceStatus( kCityState ); end );
    Controls.LevyMilitaryButton:SetHide(false);
    Controls.LevyMilitaryButton:SetDisabled(not kCityState.CanLevyMilitary);
    if kCityState.HasLevyActive and kCityState.IsLocalPlayerSuzerain then
      local levyTooltip = Locale.Lookup("LOC_CITY_STATES_MILITARY_ALREADY_LEVIED");
      Controls.LevyMilitaryButton:SetToolTipString(levyTooltip);
    else
      local levyTooltip = Locale.Lookup("LOC_CITY_STATES_LEVY_MILITARY_DETAILS", kCityState.LevyMilitaryCost, kCityState.LevyMilitaryTurnLimit);
      Controls.LevyMilitaryButton:SetToolTipString(levyTooltip);
    end 
    Controls.LevyMilitaryButton:RegisterCallback( Mouse.eLClick, function() OnLevyMilitary( kCityState ); end );
  else
    Controls.LevyMilitaryButton:SetHide(true);
    Controls.PeaceWarButton:SetHide(true);
  end

  Controls.TypeValue:SetText( GetTypeName(kCityState) );
  Controls.PatronValue:SetText( kCityState.SuzerainName );
  Controls.InfluencedByValue:SetText( Locale.Lookup("LOC_CITY_STATES_CIVILIZATIONS",table.count(kCityState.Influence)) );
  Controls.EnvoysSentValue:SetText( tostring(kCityState.Tokens) );
  Controls.QuestsValue:SetText( tostring(table.count(kCityState.Quests)) );

  -- Update the relationship button stack
  RefreshRelationshipStack( kCityState.Relationships.CivRelationships, m_RelationshipsButtonIM );

  -- Refresh AutoSize to update positions correctly
  Controls.ReportArea:DoAutoSize();

  Controls.SingleViewStack:CalculateSize();

  if m_mode == MODE.EnvoySent then
    -- Setup the buttons and what (sub) areas are shown/hidden.
    Controls.EnvoysSentButton:SetSelected( true );
    Controls.InfluencedByButton:SetSelected( false );
    Controls.QuestsButton:SetSelected( false );
    Controls.RelationshipsButton:SetSelected( false );

    Controls.EnvoysSentArea:SetHide( false );
    Controls.InfluenceArea:SetHide( true );
    Controls.QuestsArea:SetHide( true );
    Controls.RelationshipsArea:SetHide( true );

    Controls.EnvoysSentValue2:SetText( tostring(kCityState.Tokens) );

    m_EnvoysBonusCityHeaderIM:ResetInstances();
    m_EnvoysBonusItemIM:ResetInstances();

    local kHeader  :table = m_EnvoysBonusCityHeaderIM:GetInstance();
    kHeader.CityName:SetText( Locale.ToUpper( Locale.Lookup("LOC_CITY_STATES_BONUSES",kCityState.Name)) );

    -- At least the simplest of bonuses?
    local kItem    :table = m_EnvoysBonusItemIM:GetInstance();
    local textureOffsetX, textureOffsetY, textureSheet = GetBonusIconAtlasPieces( kCityState, 50 );
    kItem.Icon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
    kItem.Title:SetText( kCityState.Bonuses[NUM_ENVOY_TOKENS_FOR_FIRST_BONUS].Title );
    kItem.Details:SetText( kCityState.Bonuses[NUM_ENVOY_TOKENS_FOR_FIRST_BONUS].Details );
    ColorizeBonusItem( kCityState.isBonus1, kItem, kCityState );

    kItem    = m_EnvoysBonusItemIM:GetInstance();
    kItem.Icon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );  -- Same as above
    kItem.Title:SetText( kCityState.Bonuses[NUM_ENVOY_TOKENS_FOR_SECOND_BONUS].Title );
    kItem.Details:SetText( kCityState.Bonuses[NUM_ENVOY_TOKENS_FOR_SECOND_BONUS].Details );
    ColorizeBonusItem( kCityState.isBonus3, kItem, kCityState );

    kItem    = m_EnvoysBonusItemIM:GetInstance();
    kItem.Icon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );  -- Same as above
    kItem.Title:SetText( kCityState.Bonuses[NUM_ENVOY_TOKENS_FOR_THIRD_BONUS].Title );
    kItem.Details:SetText( kCityState.Bonuses[NUM_ENVOY_TOKENS_FOR_THIRD_BONUS].Details );
    ColorizeBonusItem( kCityState.isBonus6, kItem, kCityState );

    kItem    = m_EnvoysBonusItemIM:GetInstance();
    textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas("ICON_ENVOY_BONUS_SUZERAIN", 50);
    kItem.Icon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
    TruncateStringWithTooltip(kItem.Title, MAX_BEFORE_TRUNC_SUZERAIN, Locale.Lookup(kCityState.Bonuses["Suzerain"].Title));
    kItem.Details:SetText( kCityState.Bonuses["Suzerain"].Details );

    local PADDING:number = 40;
    kItem.Top:SetSizeY( kItem.Details:GetSizeY() + PADDING );

    Controls.EnvoysBonusStack:CalculateSize();
    Controls.EnvoysBonusScroll:CalculateSize();

    ColorizeBonusItem( kCityState.isBonusSuzerain, kItem, kCityState );

  elseif m_mode == MODE.InfluencedBy then
    -- Setup the buttons and what (sub) areas are shown/hidden.
    Controls.EnvoysSentButton:SetSelected( false );
    Controls.InfluencedByButton:SetSelected( true );
    Controls.QuestsButton:SetSelected( false );
    Controls.RelationshipsButton:SetSelected( false );

    Controls.EnvoysSentArea:SetHide( true );
    Controls.InfluenceArea:SetHide( false );
    Controls.QuestsArea:SetHide( true );
    Controls.RelationshipsArea:SetHide( true );

    m_InfluenceRowIM:ResetInstances();

    -- First determine the large # of envoy tokens given for influence so
    -- there can be a max for the ratio to set the bar.
    local largestAmount:number = 0;
    for iOtherPlayer,influence in pairs(kCityState.Influence) do
      if influence > largestAmount then
        largestAmount = influence;
      end
    end

    -- Ensure highest influenced civilizations are at the top of the list
    local kSortTable:table = {};
    function SortHighestFirst(a, b)
      local aOrder = kSortTable[ tostring( a ) ];
      local bOrder = kSortTable[ tostring( b ) ];
      if aOrder == nil then return false; end
      if bOrder == nil then return true; end
      return aOrder.influence > bOrder.influence;
    end

    -- Generate the information for each City-State
    for iOtherPlayer,influence in pairs(kCityState.Influence) do
      local kItem:table = AddInfluenceRow(kCityState.iPlayer, iOtherPlayer, influence, largestAmount);
      kSortTable[ tostring(kItem.GetTopControl()) ] = { influence = influence };  -- Store for sorting.
    end
    Controls.InfluenceStack:SortChildren( SortHighestFirst )

  elseif m_mode == MODE.Quests then
    -- Setup the buttons and what (sub) areas are shown/hidden.
    Controls.EnvoysSentButton:SetSelected( false );
    Controls.InfluencedByButton:SetSelected( false );
    Controls.QuestsButton:SetSelected( true );
    Controls.RelationshipsButton:SetSelected( false );

    Controls.EnvoysSentArea:SetHide( true );
    Controls.InfluenceArea:SetHide( true );
    Controls.QuestsArea:SetHide( false );
    Controls.RelationshipsArea:SetHide( true );

    m_QuestsIM:ResetInstances();
    for _,kQuest in pairs( kCityState.Quests ) do
      local kItem:table = m_QuestsIM:GetInstance();
      kItem.Title:SetString( kQuest.Name );
      kItem.Description:SetString( kQuest.Description );
      kItem.Reward:SetString( kQuest.Reward );
      kItem.Callout:SetString( kQuest.Callout );
    end

    Controls.QuestsStack:CalculateSize();
    Controls.QuestsScroll:CalculateSize();

  elseif m_mode == MODE.Relationships then
    ViewRelationships( kCityState );
  else
    UI.DataError("City-States in an unhandled mode '"..tostring(m_mode).."' when attempting to view a single City-State.");
    return;
  end
end

-- ===========================================================================
function OnSingleViewStackSizeChanged()
  Controls.ReportTabContainer:SetParentRelativeSizeY(REPORT_CONTAINER_SIZE_PADDING - Controls.SingleViewStack:GetSizeY() - Controls.SingleViewStack:GetOffsetY());
end
  
-- ===========================================================================
function AddInfluenceRow(cityStateID:number, playerID:number, influence:number, largestInfluence:number)
  local kItem :table = m_InfluenceRowIM:GetInstance();

  local localPlayerID:number = Game.GetLocalPlayer();
  local pLocalPlayerDiplomacy:table = Players[localPlayerID]:GetDiplomacy();
  
  local pPlayerConfig :table = PlayerConfigurations[playerID];
  
  local civName :string = "LOCAL_CITY_STATES_UNKNOWN";
  if (localPlayerID == playerID) then
    civName = Locale.Lookup(pPlayerConfig:GetPlayerName()) .. " (" .. Locale.Lookup("LOC_CITY_STATES_YOU") .. ")";
  elseif (pLocalPlayerDiplomacy:HasMet(playerID)) then
    civName = pPlayerConfig:GetPlayerName();
  end
  kItem.CityName:SetText( Locale.ToUpper(civName) );

  kItem.AmountBar:SetPercent( influence / largestInfluence);
  kItem.Amount:SetText( tostring(influence) );
  
  return kItem;
end

-- ===========================================================================
function ViewRelationships( kCityState:table )
  -- Setup the buttons and what (sub) areas are shown/hidden.
  Controls.EnvoysSentButton:SetSelected( false );
  Controls.InfluencedByButton:SetSelected( false );
  Controls.QuestsButton:SetSelected( false );
  Controls.RelationshipsButton:SetSelected( true );

  Controls.EnvoysSentArea:SetHide( true );
  Controls.InfluenceArea:SetHide( true );
  Controls.QuestsArea:SetHide( true );
  Controls.RelationshipsArea:SetHide( false );
    
  RefreshRelationshipStack( kCityState.Relationships.CivRelationships, m_RelationshipsCivsIM );

  RefreshRelationshipStack( kCityState.Relationships.CityStateRelationships, m_RelationshipsCityStatesIM );

  Controls.RelationshipsScroll:CalculateSize();
end

-- ===========================================================================	
function RefreshRelationshipStack( kRelationships:table, StackIM:table )
  
  StackIM:ResetInstances();

  for _, kRelationship in pairs( kRelationships ) do
    if kRelationship.HasMet then
      local instance:table = StackIM:GetInstance();

      -- Update icon
      instance.Icon:SetIcon(kRelationship.PlayerIcon);
      instance.Icon:LocalizeAndSetToolTip(kRelationship.PlayerName);

      -- Update color if it exists in the data
      if kRelationship.Color ~= nil then
        instance.Icon:SetColor( kRelationship.Color );
      end

      -- Update team ribbon
      if #Teams[kRelationship.TeamID] > 1 then
        local teamRibbonName:string = TEAM_RIBBON_PREFIX .. tostring(kRelationship.TeamID);
        instance.TeamRibbon:SetIcon(teamRibbonName);
        instance.TeamRibbon:SetColor(GetTeamColor(kRelationship.TeamID));
        instance.TeamRibbon:SetHide(false);
      else
        -- Hide team ribbon if team only contains one player
        instance.TeamRibbon:SetHide(true);
      end

      -- Update diplomacy pip
      if DIPLO_PIP_INFO[kRelationship.DiploState] ~= nil then
        local iconName	:string = DIPLO_PIP_INFO[kRelationship.DiploState].IconName;
        if iconName == nil or iconName == "" then
          print("WARNING: Unexpected DiplomaticState when obtain PIP art. value:"..kCityState.DiplomaticState);
          iconName = "ICON_RELATIONSHIP_NEUTRAL";
        end	
        local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas(iconName, 23);
    
        instance.DiplomacyPip:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
        if GameCapabilities.HasCapability("CAPABILITY_MILITARY") then
          instance.DiplomacyPip:SetToolTipString(kRelationship.DiploTooltip);
        end
        instance.DiplomacyPip:SetHide(false);
      else
        instance.DiplomacyPip:SetHide(true);
      end
    end
  end

  StackIM.m_ParentControl:CalculateSize();
  StackIM.m_ParentControl:ReprocessAnchoring();
end

-- ===========================================================================
--  Obtain data on city states
-- ===========================================================================
function GetData()

  local localPlayerID = Game.GetLocalPlayer();
  if (localPlayerID == -1) then
    return;
  end

  m_kCityStates = {};    -- Clear any previous data
  m_kPlayerData = {};
  m_kEnvoyChanges = {};

  -- Collect information about current player
  local pLocalPlayer      :table = Players[localPlayerID];
  local isCanGiveInfluence  :boolean = false;
  local pLocalPlayerInfluence  :table = pLocalPlayer:GetInfluence();
  local envoyTokensAvailable  :number = 0;
  if pLocalPlayerInfluence ~= nil then
    envoyTokensAvailable = pLocalPlayerInfluence:GetTokensToGive();
    if pLocalPlayerInfluence:CanGiveInfluence() and envoyTokensAvailable > 0 then
      isCanGiveInfluence = true;
    end
  end

  -- Build player specific data for interacting with CityStates
  m_kPlayerData = {
    EnvoyTokens = envoyTokensAvailable
  }

  local isNewBonusAchieved:boolean = false;

  -- Every player that is in this game...
  for i, pPlayer in ipairs(PlayerManager.GetAliveMinors()) do
    local iPlayer = pPlayer:GetID();
    local isCanReceiveInfluence    :boolean= false;
    local envoyTokens        :number  = 0;
    local envoyTokensMostReceived  :number  = 0;
    local kInfluence        :table  = {};
    local suzerainID        :number  = -1;
    local pPlayerInfluence      :table  = pPlayer:GetInfluence();
    if pPlayerInfluence ~= nil then
      isCanReceiveInfluence  = pPlayerInfluence:CanReceiveInfluence();
      envoyTokens        = pPlayerInfluence:GetTokensReceived(pLocalPlayer:GetID());
      envoyTokensMostReceived = pPlayerInfluence:GetMostTokensReceived();
      suzerainID        = pPlayerInfluence:GetSuzerain();

      -- Take this CityState and compare against others to determine influence information.
      for _, iInfluencePlayer in ipairs(PlayerManager.GetAliveMajorIDs()) do
        local tokensReceived :number = pPlayerInfluence:GetTokensReceived( iInfluencePlayer );
        if tokensReceived > 0 then
          kInfluence[iInfluencePlayer] = tokensReceived;
        end
      end

    end

    -- For all players (other than ourselves) and can receive influence (only CityStates)...
    if iPlayer ~= pLocalPlayer:GetID() and isCanReceiveInfluence then
      local primaryColor, secondaryColor = UI.GetPlayerColors( iPlayer );

      local suzerainName:string = Locale.Lookup("LOC_CITY_STATES_NONE");
      if suzerainID ~=-1 then
        if (suzerainID == localPlayerID) then
          local pPlayerConfig :table = PlayerConfigurations[suzerainID];
          suzerainName = Locale.Lookup("LOC_CITY_STATES_YOU");
        elseif pLocalPlayer:GetDiplomacy():HasMet(suzerainID) then
          local pPlayerConfig :table = PlayerConfigurations[suzerainID];
          suzerainName = Locale.Lookup(pPlayerConfig:GetPlayerName());
        else
          suzerainName = Locale.Lookup("LOCAL_CITY_STATES_UNKNOWN");
        end
      end

      local cityStateType	:string = GetCityStateType( iPlayer );

      local iPlayerDiploState :number = pPlayer:GetDiplomaticAI():GetDiplomaticStateIndex( localPlayerID );
      local diplomaticState  :string = nil;
      if iPlayerDiploState ~= -1 then
        diplomaticState = GameInfo.DiplomaticStates[iPlayerDiploState].StateType;
      end

      local pPlayerConfig:table = PlayerConfigurations[iPlayer];

      local kCityState :table    = {
        iPlayer          = pPlayer:GetID(),
        Bonuses          = {},
        CanDeclareWarOn      = pLocalPlayer:GetDiplomacy():CanDeclareWarOn( iPlayer ),
        CanLevyMilitary      = pLocalPlayer:GetInfluence():CanLevyMilitary( iPlayer ),
        CanMakePeaceWith    = pLocalPlayer:GetDiplomacy():CanMakePeaceWith( iPlayer ),
        CanReceiveTokensFrom  = pLocalPlayer:GetInfluence():CanGiveTokensToPlayer( iPlayer ),
        ColorPrimary      = primaryColor,
        ColorSecondary      = secondaryColor,
        CivType          = pPlayerConfig:GetCivilizationTypeName(),
        DiplomaticState      = diplomaticState,
        Government        = pPlayer:GetCulture():GetCurrentGovernment(),
        Influence        = kInfluence,
        Name          = pPlayerConfig:GetCivilizationShortDescription(),
        isAlive          = pPlayer:IsAlive(),
        isAtWar          = pLocalPlayer:GetDiplomacy():IsAtWarWith( iPlayer ),
        isBonus1        = (envoyTokens >= NUM_ENVOY_TOKENS_FOR_FIRST_BONUS),  -- WARNING: Inferring game rules to set bonus thresholds.
        isBonus3        = (envoyTokens >= NUM_ENVOY_TOKENS_FOR_SECOND_BONUS),  -- WARNING: Inferring game rules to set bonus thresholds.
        isBonus6        = (envoyTokens >= NUM_ENVOY_TOKENS_FOR_THIRD_BONUS),  -- WARNING: Inferring game rules to set bonus thresholds.
        isBonusSuzerain      = (suzerainID == localPlayerID),
        isHasMet        = pLocalPlayer:GetDiplomacy():HasMet( iPlayer ),
        iScore          = pPlayer:GetDiplomaticAI():GetDiplomaticScore( localPlayerID ),
        iState          = iPlayerDiploState,
        iTurnChanged      = pLocalPlayer:GetDiplomacy():GetAtWarChangeTurn( iPlayer ),
        iVisibility        = pLocalPlayer:GetDiplomacy():GetVisibilityOn( iPlayer ),
        iGameScore        = pPlayer:GetScore(),
        LevyMilitaryCost    = pLocalPlayer:GetInfluence():GetLevyMilitaryCost( iPlayer ),
        LevyMilitaryTurnLimit  = pPlayer:GetInfluence():GetLevyTurnLimit(),
        HasLevyActive      = (pPlayer:GetInfluence():GetLevyTurnCounter() >= 0),
        IsLocalPlayerSuzerain  = (pLocalPlayer:GetID() == suzerainID),
        Quests          = GetQuests( iPlayer ),
        Relationships			= GetRelationships( iPlayer ),			
        SuzerainID        = suzerainID,
        SuzerainName      = suzerainName,
        SuzerainTokensNeeded  = envoyTokensMostReceived,
        Tokens          = envoyTokens,
        TokensMostReceived    = envoyTokensMostReceived,
        Type          = cityStateType,
      };

      -- Make and changes to tokens needed based on range and who (if anyone) is Suzerain
      if kCityState.SuzerainTokensNeeded < MIN_ENVOY_TOKENS_SUZERAIN then
        kCityState.SuzerainTokensNeeded = MIN_ENVOY_TOKENS_SUZERAIN
      elseif not kCityState.isBonusSuzerain then
        kCityState.SuzerainTokensNeeded = kCityState.SuzerainTokensNeeded + 1;
      end

      -- Obtain bonus text:
      local title:string, details:string = GetBonusText( iPlayer, NUM_ENVOY_TOKENS_FOR_FIRST_BONUS );
      kCityState.Bonuses[ NUM_ENVOY_TOKENS_FOR_FIRST_BONUS ] = { Title = title, Details = details }
      if kCityState.isBonus1 then
        if m_kLastCityStates ~= nil and not m_kLastCityStates[iPlayer].isBonus1 then
          isNewBonusAchieved = true;
        end
      end
      title, details = GetBonusText( iPlayer, NUM_ENVOY_TOKENS_FOR_SECOND_BONUS );
      kCityState.Bonuses[ NUM_ENVOY_TOKENS_FOR_SECOND_BONUS ] = { Title = title, Details = details }
      if kCityState.isBonus3 then
        if m_kLastCityStates ~= nil and not m_kLastCityStates[iPlayer].isBonus3 then
          isNewBonusAchieved = true;
        end
      end
      title, details = GetBonusText( iPlayer, NUM_ENVOY_TOKENS_FOR_THIRD_BONUS );
      kCityState.Bonuses[ NUM_ENVOY_TOKENS_FOR_THIRD_BONUS ] = { Title = title, Details = details }
      if kCityState.isBonus6 then
        if m_kLastCityStates ~= nil and not m_kLastCityStates[iPlayer].isBonus6 then
          isNewBonusAchieved = true;
        end
      end
      details = GetSuzerainBonusText( iPlayer );
      kCityState.Bonuses["Suzerain"] = {
        Title = Locale.Lookup("LOC_CITY_STATES_SUZERAIN_ENVOYS"),
        Details = details
        }
      if kCityState.isBonusSuzerain then
        if m_kLastCityStates ~= nil and not m_kLastCityStates[iPlayer].isBonusSuzerain then
          isNewBonusAchieved = true;
        end
      end

      -- Save to master table
      m_kCityStates[iPlayer] = kCityState;
    end
  end

  -- Play sound if any city state just achieved a bonus.
  if isNewBonusAchieved then
    UI.PlaySound("Receive_Envoy_Bonus");
  end

  -- Clear previous cached city states items and store currect.
  m_kLastCityStates = nil;
end

-- ===========================================================================
function GetCityStateType( playerID:number )

  local cityStateType	:string = "";
  local leader		:string = PlayerConfigurations[ playerID ]:GetLeaderTypeName();
  local leaderInfo	:table	= GameInfo.Leaders[leader];
  if leaderInfo == nil or leaderInfo.InheritFrom == nil then
    UI.DataError("Cannot determine leader type for player #"..tostring( iPlayer ));
    cityStateType = "unknown";
  elseif (leader == "LEADER_MINOR_CIV_SCIENTIFIC" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_SCIENTIFIC") then				
    cityStateType = "SCIENTIFIC";
  elseif (leader == "LEADER_MINOR_CIV_RELIGIOUS" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_RELIGIOUS") then
    cityStateType = "RELIGIOUS";
  elseif (leader == "LEADER_MINOR_CIV_TRADE" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_TRADE") then
    cityStateType = "TRADE";
  elseif (leader == "LEADER_MINOR_CIV_CULTURAL" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_CULTURAL") then
    cityStateType = "CULTURE";
  elseif (leader == "LEADER_MINOR_CIV_MILITARISTIC" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_MILITARISTIC") then
    cityStateType = "MILITARISTIC";
  elseif (leader == "LEADER_MINOR_CIV_INDUSTRIAL" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_INDUSTRIAL") then
    cityStateType = "INDUSTRIAL";
  end

  return cityStateType;
end

-- ===========================================================================
--  UI EVENT
-- ===========================================================================
function OnInputHandler( input:table )
  --if m_mode == MODE.EnvoySent or m_mode == MODE.InfluencedBy or m_mode == MODE.Quests then
  return m_kScreenSlideAnim.OnInputHandler( input );
end

-- ===========================================================================
--  UI EVENT
-- ===========================================================================
function OnInit(isReload:boolean)
  if isReload then
    LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
  end
end

-- ===========================================================================
--  UI EVENT
-- ===========================================================================
function OnShutdown()
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isHidden", ContextPtr:IsHidden());
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_mode", m_mode);
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_iCurrentCityState", m_iCurrentCityState);
end

-- ===========================================================================
--  LUA EVENT
--  Reload support
-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
  if context == RELOAD_CACHE_ID then
    if contextTable["m_mode"] ~= nil        then m_mode = contextTable["m_mode"]; end
    if contextTable["m_iCurrentCityState"] ~= nil  then m_iCurrentCityState = contextTable["m_iCurrentCityState"]; end
    if contextTable["isHidden"] ~= nil and not contextTable["isHidden"] then
      if    m_mode == MODE.Overview then OpenOverview();
      elseif  m_mode == MODE.SendEnvoys then OnOpenSendEnvoys();
      elseif	m_mode == MODE.EnvoySent or m_mode == MODE.InfluencedBy or m_mode == MODE.Quests or m_mode == MODE.Relationships then 
        m_kScreenSlideAnim.Show();
        Refresh();
      end
    end
  end
end


-- ===========================================================================
--  Game Event
-- ===========================================================================
function OnCityLiberated(playerID:number, cityID:number)
  if not ContextPtr:IsHidden() then
    local localPlayerID = Game.GetLocalPlayer();
    if (localPlayerID == -1) then
      return;
    end
    Refresh();
  end
end

-- ===========================================================================
--  Game Event
-- ===========================================================================
function OnDiplomacyDeclareWar(firstPlayerID, secondPlayerID)
  local localPlayerID = Game.GetLocalPlayer();
  if (localPlayerID ~= nil) then
    if (localPlayerID == firstPlayerID or localPlayerID == secondPlayerID) then
      m_kEnvoyChanges = {}; -- Zero out any pending envoy choices
    end
  end
  if not ContextPtr:IsHidden() then
    Refresh();
  end
end

-- ===========================================================================
--  Game Event
-- ===========================================================================
function OnDiplomacyMakePeace(firstPlayerID, secondPlayerID)
  local localPlayerID = Game.GetLocalPlayer();
  if (localPlayerID ~= nil) then
    if (localPlayerID == firstPlayerID or localPlayerID == secondPlayerID) then
      m_kEnvoyChanges = {}; -- Zero out any pending envoy choices
    end
  end
  if not ContextPtr:IsHidden() then
    Refresh();
  end
end

-- ===========================================================================
--  Game Event
-- ===========================================================================
function OnInfluenceChanged()
  if not ContextPtr:IsHidden() then
    local localPlayerID = Game.GetLocalPlayer();
    if (localPlayerID == -1) then
      return;
    end
    Refresh();
  end
end

-- ===========================================================================
--  Game Event
-- ===========================================================================
function OnInfluenceGiven()
  if not ContextPtr:IsHidden() then
    local localPlayerID = Game.GetLocalPlayer();
    if (localPlayerID == -1) then
      return;
    end
    Refresh();
  end
end

-- ===========================================================================
--  Game Event
-- ===========================================================================
function OnInterfaceModeChanged(eOldMode:number, eNewMode:number)
  if eNewMode == InterfaceModeTypes.VIEW_MODAL_LENS then
    Close();
  end
end

-- ===========================================================================
--  Game Event
-- ===========================================================================
function OnQuestChanged()
  if not ContextPtr:IsHidden() then
    local localPlayerID = Game.GetLocalPlayer();
    if (localPlayerID == -1) then
      return;
    end
    Refresh();
  end
end

-- ===========================================================================
--  Game Event
-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string)
  m_kScreenSlideAnim.OnUpdateUI( type, tag, iData1, iData2, strData1 );
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end

-- ===========================================================================
function Resize()
  _, m_height = UIManager:GetScreenSizeVal();
end

-- ===========================================================================
--  Player Turn Events
-- ===========================================================================
function OnLocalPlayerTurnBegin()
  m_isLocalPlayerTurn = true;
  if not ContextPtr:IsHidden() then
    Refresh();
  end
end
function OnLocalPlayerTurnEnd()
  m_isLocalPlayerTurn = false;
  if not ContextPtr:IsHidden() then
    Refresh();
  end
end

-- ===========================================================================
--  Initialize
-- ===========================================================================
function Initialize()

  if (not HasCapability("CAPABILITY_CITY_STATES_VIEW")) then
    -- City States is off, just exit
    return;
  end

  -- Check:
  if  NUM_ENVOY_TOKENS_FOR_FIRST_BONUS   == NUM_ENVOY_TOKENS_FOR_SECOND_BONUS or
    NUM_ENVOY_TOKENS_FOR_SECOND_BONUS  == NUM_ENVOY_TOKENS_FOR_THIRD_BONUS  or
    NUM_ENVOY_TOKENS_FOR_FIRST_BONUS   == NUM_ENVOY_TOKENS_FOR_THIRD_BONUS then
    alert("At least 2 city state bonuses have the same value, this will cause issues!");
  end

  m_kScreenSlideAnim = CreateScreenAnimation( Controls.SlideAnim );

  -- UI Callbacks
  Controls.CloseListButton:RegisterCallback( Mouse.eLClick, OnClose );
  Controls.CloseBackButton:RegisterCallback( Mouse.eLClick, OnBackClose );
  Controls.Title:SetText(Locale.ToUpper(Locale.Lookup("LOC_CITY_STATES_TITLE")));
  Controls.ConfirmButton:RegisterCallback( Mouse.eLClick, OnConfirmPlacement );
  Controls.EnvoysSentButton:RegisterCallback( Mouse.eLClick, OnEnvoySentClick );
  Controls.InfluencedByButton:RegisterCallback( Mouse.eLClick, OnInfluencedByClick );
  Controls.QuestsButton:RegisterCallback( Mouse.eLClick, OnQuestsClick );
  Controls.RelationshipsButton:RegisterCallback( Mouse.eLClick, OnRelationshipsClick );
  Controls.SingleViewStack:RegisterSizeChanged( OnSingleViewStackSizeChanged );

  -- UI Events
  ContextPtr:SetInitHandler( OnInit );
  ContextPtr:SetInputHandler(OnInputHandler, true);
  ContextPtr:SetShutdown( OnShutdown );

  -- Game Events
  Events.CityLiberated.Add( OnCityLiberated );
  Events.DiplomacyDeclareWar.Add( OnDiplomacyDeclareWar );
  Events.DiplomacyMakePeace.Add( OnDiplomacyMakePeace );
  Events.InfluenceChanged.Add( OnInfluenceChanged );
  Events.InfluenceGiven.Add( OnInfluenceGiven );
  Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
  Events.QuestChanged.Add( OnQuestChanged );
  Events.SystemUpdateUI.Add( OnUpdateUI );
  Events.LocalPlayerTurnBegin.Add(OnLocalPlayerTurnBegin);
  Events.LocalPlayerTurnEnd.Add(OnLocalPlayerTurnEnd);
  Events.LocalPlayerChanged.Add(OnClose);

  -- LUA Events
  LuaEvents.CityBannerManager_RaiseMinorCivPanel.Add( OnRaiseMinorCivicsPanel );
  LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );
  LuaEvents.NotificationPanel_OpenCityStatesSendEnvoys.Add( OnOpenSendEnvoys );
  LuaEvents.PartialScreenHooks_OpenCityStates.Add( OnOpenCityStates );
  LuaEvents.PartialScreenHooks_CloseCityStates.Add( OnCloseCityStates );
  LuaEvents.PartialScreenHooks_CloseAllExcept.Add( OnCloseAllExcept );
  LuaEvents.WorldRankings_CloseCityStates.Add( OnClose );

  Resize();
  m_mode = MODE.Overview;
end
Initialize();
