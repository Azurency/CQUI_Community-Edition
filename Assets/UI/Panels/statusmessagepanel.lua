-- ===========================================================================
-- Status Message Manager
-- Non-interactive messages that appear in the upper-center of the screen.
-- ===========================================================================
include( "InstanceManager" );
include( "SupportFunctions" );

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
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_AGENDA_KUDOS", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_AGENDA_WARNING") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_AGENDA_WARNING", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_ALLIED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_ALLIED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_ANARCHY_BEGINS") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_ANARCHY_BEGINS", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_ARTIFACT_EXTRACTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_ARTIFACT_EXTRACTED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_BARBARIAN_INVASION_STARTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_BARBARIAN_INVASION_STARTED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_BARBARIAN_RAID_STARTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_BARBARIAN_RAID_STARTED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_BEACH_RESORT_CREATED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_BEACH_RESORT_CREATED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CHANGE_GOVERNMENT") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CHANGE_GOVERNMENT", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CITY_BESIEGED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CITY_BESIEGED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CITY_LIBERATED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CITY_LIBERATED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CITY_RAZED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CITY_RAZED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CLEAR_CAMP") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CLEAR_CAMP", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CITY_STATE_INFLUENCE") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CITY_STATE_INFLUENCE", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CONQUER_CITY") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CONQUER_CITY", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CONSTRUCT_BUILDING") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CONSTRUCT_BUILDING", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CONSTRUCT_DISTRICT") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CONSTRUCT_DISTRICT", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CREATE_PANTHEON") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CREATE_PANTHEON", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_CULTURVATE_CIVIC") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_CULTURVATE_CIVIC", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_DECLARED_FRIENDSHIP") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_DECLARED_FRIENDSHIP", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_DELEGATION") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_DELEGATION", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_DENOUNCED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_DENOUNCED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_EMBASSY") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_EMBASSY", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_ERA_CHANGED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_ERA_CHANGED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_FIND_NATURAL_WONDER") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_FIND_NATURAL_WONDER", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_FOUND_CITY") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_FOUND_CITY", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_FOUND_RELIGION") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_FOUND_RELIGION", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_GREATPERSON_CREATED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_GREATPERSON_CREATED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_LAUNCHING_ATTACK") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_LAUNCHING_ATTACK", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_WAR_PREPARATION") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_WAR_PREPARATION", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_INQUISITION_LAUNCHED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_INQUISITION_LAUNCHED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_LAND_UNIT_LEVEL") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_LAND_UNIT_LEVEL", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_MAKE_DOW") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_MAKE_DOW", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_NATIONAL_PARK_CREATED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_NATIONAL_PARK_CREATED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_NEW_RELIGIOUS_MAJORITY") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_NEW_RELIGIOUS_MAJORITY", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_PILLAGE") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_PILLAGE", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_POLICY_ENACTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_POLICY_ENACTED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_RECEIVE_DOW") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_RECEIVE_DOW", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_RELIC_RECEIVED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_RELIC_RECEIVED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_RESEARCH_AGREEMENT") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_RESEARCH_AGREEMENT", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_RESEARCH_TECH") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_RESEARCH_TECH", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_DISRUPT_ROCKETRY_DETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_DISRUPT_ROCKETRY_DETECTED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_DISRUPT_ROCKETRY_UNDETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_DISRUPT_ROCKETRY_UNDETECTED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_GREAT_WORK_HEIST_DETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_GREAT_WORK_HEIST_DETECTED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_GREAT_WORK_HEIST_UNDETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_GREAT_WORK_HEIST_UNDETECTED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_RECRUIT_PARTISANS_DETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_RECRUIT_PARTISANS_DETECTED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_RECRUIT_PARTISANS_UNDETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_RECRUIT_PARTISANS_UNDETECTED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_SABOTAGE_PRODUCTION_DETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_SABOTAGE_PRODUCTION_DETECTED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_SABOTAGE_PRODUCTION_UNDETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_SABOTAGE_PRODUCTION_UNDETECTED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_SIPHON_FUNDS_DETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_SIPHON_FUNDS_DETECTED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_SIPHON_FUNDS_UNDETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_SIPHON_FUNDS_UNDETECTED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_STEAL_TECH_BOOST_DETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_STEAL_TECH_BOOST_DETECTED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_SPY_STEAL_TECH_BOOST_UNDETECTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_SPY_STEAL_TECH_BOOST_UNDETECTED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_TRADE_DEAL") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_TRADE_DEAL", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_TRADE_RENEGE") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_TRADE_RENEGE", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_TRAIN_SETTLER") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_TRAIN_SETTLER", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_TRAIN_UNIT") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_TRAIN_UNIT", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_TRAIN_UNIQUE_UNIT") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_TRAIN_UNIQUE_UNIT", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_PROJECT_STARTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_PROJECT_STARTED", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_START_VICTORY_STRATEGY") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_START_VICTORY_STRATEGY", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_STOP_VICTORY_STRATEGY") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_STOP_VICTORY_STRATEGY", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_WMD_BUILT") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_WMD_BUILT", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_WMD_STRIKE") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_WMD_STRIKE", "X", "Y", "Z", "1", "2", "3");
  end
  if(GameConfiguration.GetValue("CQUI_LOC_GOSSIP_WONDER_STARTED") == false) then
    ignored[#ignored+1] = Locale.Lookup("LOC_GOSSIP_WONDER_STARTED", "X", "Y", "Z", "1", "2", "3");
  end
  return ignored;
end

--Trims source information from gossip messages. Returns nil if the message couldn't be trimmed (this usually means the provided string wasn't a gossip message at all)
function CQUI_TrimGossipMessage(str:string)
  local sourceSample = Locale.Lookup("LOC_GOSSIP_SOURCE_DELEGATE", "X", "Y", "Z"); --Get a sample of a gossip source string
  _, last = string.match(sourceSample, "(.-)%s(%S+)$"); --Get last word that occurs in the gossip source string. "that" in English. Assumes the last word is always the same, which it is in English, unsure if this holds true in other languages
  return Split(str, " " .. last .. " " , 2)[2]; --Get the rest of the string after the last word from the gossip source string
end

-- Returns true if the given message is disabled in settings
function CQUI_IsGossipMessageIgnored(str:string) --Heuristics for figuring out if the given message should be ignored
  if (str == nil) then return false; end --str will be nil if the last word from the gossip source string can't be found in message. Generally means the incoming message wasn't gossip at all
  local strwords = Split(str, " "); --Split into component words
  for _, message in ipairs(CQUI_ignoredMessages) do
    message = Split(message, " ");
    for _, strword in ipairs(strwords) do
      local tally = 0; --Tracks how many words from the ignored message were matched in comparison to the real message
      for i, messageword in ipairs(message) do
        if(messageword == strword or string.find(messageword, "X") or string.find(messageword, "Y") or string.find(messageword, "Z")) then --Ignores words containing the given placeholder letters. Has some chance for false positives, but it's very unlikely this will every actually make much difference
          tally = tally + 1;
        end
      end
      if(tally >= #message - 1) then --If every single word from the ignored message matched the real message, return true
        return true;
      end
    end
  end
  return false;
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
