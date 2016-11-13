-- =========================================================================== 
-- Status Message Manager
-- Non-interactive messages that appear in the upper-center of the screen.
-- =========================================================================== 
include( "InstanceManager" );

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


-- =========================================================================== 
--  FUNCTIONS
-- =========================================================================== 

-- =========================================================================== 
-- =========================================================================== 
function OnStatusMessage( str:string, fDisplayTime:number, type:number )
  if (type == ReportingStatusTypes.DEFAULT or
    type == ReportingStatusTypes.GOSSIP) then -- A type we handle?

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
    pInstance.Anim:SetToBeginning();
    pInstance.Anim:Play();

    Controls.StackOfMessages:CalculateSize();
    Controls.StackOfMessages:ReprocessAnchoring();
  end
end

-- ===========================================================================
function OnEndAnim( kTypeEntry:table, pInstance:table )
  pInstance.Anim:ClearEndCallback();
  Controls.StackOfMessages:CalculateSize();
  Controls.StackOfMessages:ReprocessAnchoring();
  kTypeEntry.InstanceManager:ReleaseInstance( pInstance )   
end


----------------------------------------------------------------  
function OnMultplayerPlayerConnected( playerID )
  if( ContextPtr:IsHidden() == false and GameConfiguration.IsNetworkMultiplayer() ) then
    local pPlayerConfig = PlayerConfigurations[playerID];
    local statusMessage = pPlayerConfig:GetPlayerName() .. " " .. PlayerConnectedChatStr;
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
