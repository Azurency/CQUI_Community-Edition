-- ===========================================================================
-- Status Message Manager
-- Non-interactive messages that appear in the upper-center of the screen.
-- ===========================================================================
include( "InstanceManager" );
include( "SupportFunctions" );
include( "Civ6Common" );

-- ===========================================================================
--  CONSTANTS
-- ===========================================================================
local DEFAULT_TIME_TO_DISPLAY :number = 10; -- Seconds to display the message

-- CQUI CONSTANTS Trying to make the different messages have unique colors
local CQUI_STATUS_MESSAGE_CIVIC      :number = 3;    -- Number to distinguish civic messages
local CQUI_STATUS_MESSAGE_TECHS      :number = 4;    -- Number to distinguish tech messages

-- Figure out eventually what colors are used by the actual civic and tech trees
local CQUI_CIVIC_COLOR                       = 0xDFFF33CC;
local CQUI_TECHS_COLOR                       = 0xDFFF6600;
local CQUI_BASIC_COLOR                       = 0xFFFFFFFF;


-- ===========================================================================
--  VARIABLES
-- ===========================================================================

local m_statusIM        :table = InstanceManager:new( "StatusMessageInstance", "Root", Controls.StackOfMessages );
local m_gossipIM        :table = InstanceManager:new( "GossipMessageInstance", "Root", Controls.StackOfMessages );

local PlayerConnectedChatStr  :string = Locale.Lookup( "LOC_MP_PLAYER_CONNECTED_CHAT" );
local PlayerDisconnectedChatStr :string = Locale.Lookup( "LOC_MP_PLAYER_DISCONNECTED_CHAT" );
local PlayerKickedChatStr   :string = Locale.Lookup( "LOC_MP_PLAYER_KICKED_CHAT" );

local CQUI_messageType          :number = 0;

local m_kMessages :table = {};

--CQUI Members
local CQUI_trimGossip = true;
local CQUI_ignoredMessages = {};

function CQUI_OnSettingsUpdate()
  CQUI_trimGossip = GameConfiguration.GetValue("CQUI_TrimGossip");
  CQUI_ignoredMessages = CQUI_GetIgnoredGossipMessages();
end

LuaEvents.CQUI_SettingsUpdate.Add( CQUI_OnSettingsUpdate );
LuaEvents.CQUI_SettingsInitialized.Add( CQUI_OnSettingsUpdate );

-- ===========================================================================
--  FUNCTIONS
-- ===========================================================================

-- ===========================================================================
-- ===========================================================================
-- Gets a list of ignored gossip messages based on current settings
function CQUI_GetIgnoredGossipMessages() --Yeah... as far as I can tell there's no way to get these programatically, so I just made a script that grepped these from the LOC files
  local ignored :table = {};
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_AGENDA_KUDOS") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_AGENDA_KUDOS", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_AGENDA_WARNING") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_AGENDA_WARNING", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_ALLIED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_ALLIED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_ANARCHY_BEGINS") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_ANARCHY_BEGINS", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_ARTIFACT_EXTRACTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_ARTIFACT_EXTRACTED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_BARBARIAN_INVASION_STARTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_BARBARIAN_INVASION_STARTED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_BARBARIAN_RAID_STARTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_BARBARIAN_RAID_STARTED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_BEACH_RESORT_CREATED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_BEACH_RESORT_CREATED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CHANGE_GOVERNMENT") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CHANGE_GOVERNMENT", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CITY_BESIEGED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CITY_BESIEGED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CITY_LIBERATED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CITY_LIBERATED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CITY_RAZED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CITY_RAZED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CLEAR_CAMP") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CLEAR_CAMP", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CITY_STATE_INFLUENCE") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CITY_STATE_INFLUENCE", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CONQUER_CITY") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CONQUER_CITY", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CONSTRUCT_BUILDING") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CONSTRUCT_BUILDING", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CONSTRUCT_DISTRICT") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CONSTRUCT_DISTRICT", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CREATE_PANTHEON") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CREATE_PANTHEON", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CULTURVATE_CIVIC") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CULTURVATE_CIVIC", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_DECLARED_FRIENDSHIP") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_DECLARED_FRIENDSHIP", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_DELEGATION") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_DELEGATION", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_DENOUNCED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_DENOUNCED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_EMBASSY") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_EMBASSY", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_ERA_CHANGED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_ERA_CHANGED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_FIND_NATURAL_WONDER") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_FIND_NATURAL_WONDER", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_FOUND_CITY") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_FOUND_CITY", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_FOUND_RELIGION") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_FOUND_RELIGION", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_GREATPERSON_CREATED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_GREATPERSON_CREATED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_LAUNCHING_ATTACK") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_LAUNCHING_ATTACK", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_WAR_PREPARATION") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_WAR_PREPARATION", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_INQUISITION_LAUNCHED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_INQUISITION_LAUNCHED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_LAND_UNIT_LEVEL") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_LAND_UNIT_LEVEL", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_MAKE_DOW") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_MAKE_DOW", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_NATIONAL_PARK_CREATED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_NATIONAL_PARK_CREATED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_NEW_RELIGIOUS_MAJORITY") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_NEW_RELIGIOUS_MAJORITY", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_PILLAGE") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_PILLAGE", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_POLICY_ENACTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_POLICY_ENACTED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_RECEIVE_DOW") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_RECEIVE_DOW", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_RELIC_RECEIVED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_RELIC_RECEIVED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_RESEARCH_AGREEMENT") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_RESEARCH_AGREEMENT", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_RESEARCH_TECH") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_RESEARCH_TECH", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_DISRUPT_ROCKETRY_DETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_DISRUPT_ROCKETRY_DETECTED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_DISRUPT_ROCKETRY_UNDETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_DISRUPT_ROCKETRY_UNDETECTED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_GREAT_WORK_HEIST_DETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_GREAT_WORK_HEIST_DETECTED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_GREAT_WORK_HEIST_UNDETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_GREAT_WORK_HEIST_UNDETECTED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_RECRUIT_PARTISANS_DETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_RECRUIT_PARTISANS_DETECTED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_RECRUIT_PARTISANS_UNDETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_RECRUIT_PARTISANS_UNDETECTED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_SABOTAGE_PRODUCTION_DETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_SABOTAGE_PRODUCTION_DETECTED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_SABOTAGE_PRODUCTION_UNDETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_SABOTAGE_PRODUCTION_UNDETECTED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_SIPHON_FUNDS_DETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_SIPHON_FUNDS_DETECTED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_SIPHON_FUNDS_UNDETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_SIPHON_FUNDS_UNDETECTED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_STEAL_TECH_BOOST_DETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_STEAL_TECH_BOOST_DETECTED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_STEAL_TECH_BOOST_UNDETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_STEAL_TECH_BOOST_UNDETECTED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_TRADE_DEAL") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_TRADE_DEAL", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_TRADE_RENEGE") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_TRADE_RENEGE", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_TRAIN_SETTLER") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_TRAIN_SETTLER", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_TRAIN_UNIT") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_TRAIN_UNIT", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_TRAIN_UNIQUE_UNIT") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_TRAIN_UNIQUE_UNIT", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_PROJECT_STARTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_PROJECT_STARTED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_START_VICTORY_STRATEGY") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_START_VICTORY_STRATEGY", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_STOP_VICTORY_STRATEGY") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_STOP_VICTORY_STRATEGY", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_WMD_BUILT") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_WMD_BUILT", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_WMD_STRIKE") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_WMD_STRIKE", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_WONDER_STARTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_WONDER_STARTED", "[]", "[]", "[]", "[]", "[]", "[]");
  end
  return ignored;
end

-- Returns true if the given message is disabled in settings
function CQUI_IsGossipMessageIgnored(str)
  if (str == nil) then return false; end --str will be nil if the last word from the gossip source string can't be found in message. Generally means the incoming message wasn't gossip at all
  str = string.gsub(str, "%s", "") -- remove spaces to normalize the string
  for _, message in ipairs(CQUI_ignoredMessages) do
    message = string.gsub(message, "%s", "") -- remove spaces to normalize the ignored message
    partsToMatch = Split(message, "%[%]") -- Split the ignored messages into its different parts
    local stringToMatch = "^" -- We'll build a string to match with the differents parts
    for _, part in ipairs(partsToMatch) do
      part = string.gsub(part, "%p", "%%%1") -- Escape all the magic character that each part can contain (to avoid being considered as part of the pattern)
      stringToMatch = stringToMatch .. part .. ".*"
    end
    stringToMatch = stringToMatch .. "$"
    if string.find(str, stringToMatch) then -- If the str match the strToMatch, return true
      return true
    end
  end
  return false
end

function OnStatusMessage( str:string, fDisplayTime:number, type:number )
  if (type == ReportingStatusTypes.DEFAULT or type == ReportingStatusTypes.GOSSIP) then -- A type we handle?
    if (type == ReportingStatusTypes.GOSSIP) then
      local trimmed = CQUI_TrimGossipMessage(str);
      if(trimmed ~= nil) then
        if (CQUI_IsGossipMessageIgnored(trimmed)) then
          return; --If the message is supposed to be ignored, give up!
        elseif(CQUI_trimGossip) then
          str = trimmed
        end
      end
    end

    local kTypeEntry :table = m_kMessages[type];
    if (kTypeEntry == nil) then
      -- New type
      m_kMessages[type] = {
        InstanceManager = nil,
        MessageInstances= {}
      };
      kTypeEntry = m_kMessages[type];

      -- Link to the instance manager and the stack the UI displays in
      if (type == ReportingStatusTypes.GOSSIP) then
        kTypeEntry.InstanceManager  = m_gossipIM;
      else
        kTypeEntry.InstanceManager  = m_statusIM;
      end
    end

    local pInstance:table = kTypeEntry.InstanceManager:GetInstance();
    table.insert( kTypeEntry.MessageInstances, pInstance );

    local timeToDisplay:number = (fDisplayTime > 0) and fDisplayTime or DEFAULT_TIME_TO_DISPLAY;

        -- CQUI Figuring out how to change the color of the status message
        if CQUI_messageType == CQUI_STATUS_MESSAGE_CIVIC then
            pInstance.StatusGrid:SetColor(CQUI_CIVIC_COLOR);
        elseif CQUI_messageType == CQUI_STATUS_MESSAGE_TECHS then
            pInstance.StatusGrid:SetColor(CQUI_TECHS_COLOR);
        elseif type == ReportingStatusTypes.DEFAULT then
          pInstance.StatusGrid:SetColor(CQUI_BASIC_COLOR);
        end

    pInstance.StatusLabel:SetText( str );
    pInstance.Anim:SetEndPauseTime( timeToDisplay );
    pInstance.Anim:RegisterEndCallback( function() OnEndAnim(kTypeEntry,pInstance) end );
    pInstance.StatusButton:RegisterCallback( Mouse.eLClick, function() OnMessageClicked(kTypeEntry,pInstance) end );
    pInstance.Anim:SetToBeginning();
    pInstance.Anim:Play();

    Controls.StackOfMessages:CalculateSize();
    Controls.StackOfMessages:ReprocessAnchoring();
  end
end

-- ===========================================================================
function OnEndAnim( kTypeEntry:table, pInstance:table )
  RemoveMessage( kTypeEntry, pInstance );
end

-- ===========================================================================
function OnMessageClicked( kTypeEntry:table, pInstance:table )
  RemoveMessage( kTypeEntry, pInstance );
end

-- ===========================================================================
function RemoveMessage( kTypeEntry:table, pInstance:table )
  pInstance.Anim:ClearEndCallback();
  Controls.StackOfMessages:CalculateSize();
  Controls.StackOfMessages:ReprocessAnchoring();
  kTypeEntry.InstanceManager:ReleaseInstance( pInstance );
end

----------------------------------------------------------------
function OnMultplayerPlayerConnected( playerID )
  if( ContextPtr:IsHidden() == false and GameConfiguration.IsNetworkMultiplayer() ) then
    local pPlayerConfig = PlayerConfigurations[playerID];
    local statusMessage = Locale.Lookup(pPlayerConfig:GetPlayerName()) .. " " .. PlayerConnectedChatStr;
    OnStatusMessage( statusMessage, DEFAULT_TIME_TO_DISPLAY, ReportingStatusTypes.DEFAULT );
  end
end

----------------------------------------------------------------
function OnMultiplayerPrePlayerDisconnected( playerID )
  if( ContextPtr:IsHidden() == false and GameConfiguration.IsNetworkMultiplayer() ) then
    local pPlayerConfig = PlayerConfigurations[playerID];
    local statusMessage = Locale.Lookup(pPlayerConfig:GetPlayerName());
    if(Network.IsPlayerKicked(playerID)) then
      statusMessage = statusMessage .. " " .. PlayerKickedChatStr;
    else
        statusMessage = statusMessage .. " " .. PlayerDisconnectedChatStr;
    end
    OnStatusMessage(statusMessage, DEFAULT_TIME_TO_DISPLAY, ReportingStatusTypes.DEFAULT);
  end
end

-- ===========================================================================
--  Testing: When on the "G" and "D" keys generate messages.
-- ===========================================================================
function Test()
  OnStatusMessage("Testing out A message", 10, ReportingStatusTypes.GOSSIP );
  OnStatusMessage("Testing out BB message", 10, ReportingStatusTypes.GOSSIP );
  ContextPtr:SetInputHandler(
    function( pInputStruct )
      local uiMsg = pInputStruct:GetMessageType();
      if uiMsg == KeyEvents.KeyUp then
        local key = pInputStruct:GetKey();
        if key == Keys.D then OnStatusMessage("Testing out status message ajsdkl akds dk dkdkj dkdkd ajksaksdkjkjd dkadkj f djkdkjdkj dak sdkjdjkal dkd kd dk adkj dkkadj kdjd kdkjd jkd jd dkj djkd dkdkdjdkdkjdkd djkd dkd dkjd kdjdkj d", 10, ReportingStatusTypes.DEFAULT ); return true; end
        if key == Keys.G then OnStatusMessage("Testing out gossip message", 10, ReportingStatusTypes.GOSSIP ); return true; end
      end
      return false;
    end, true);
end

function CQUI_OnStatusMessage(str:string, fDisplayTime:number, thisType:number)

    if thisType == CQUI_STATUS_MESSAGE_CIVIC then
        CQUI_messageType = CQUI_STATUS_MESSAGE_CIVIC;
    elseif thisType == CQUI_STATUS_MESSAGE_TECHS then
        CQUI_messageType = CQUI_STATUS_MESSAGE_TECHS;
    else
        CQUI_messageType = 0;
    end

    OnStatusMessage(str, fDisplayTime, ReportingStatusTypes.DEFAULT);
    CQUI_messageType = 0;
end

-- ===========================================================================
function Initialize()
  Events.StatusMessage.Add( OnStatusMessage );
  Events.MultiplayerPlayerConnected.Add( OnMultplayerPlayerConnected );
  Events.MultiplayerPrePlayerDisconnected.Add( OnMultiplayerPrePlayerDisconnected );

    -- CQUI
    LuaEvents.CQUI_AddStatusMessage.Add( CQUI_OnStatusMessage );
  --Test();
end
Initialize();
