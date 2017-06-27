-- ===========================================================================
--  Notification Panel  
-- ===========================================================================

include( "ToolTipHelper" ); 
include( "InstanceManager" );


-- ===========================================================================
--  DEBUG
-- ===========================================================================
local m_debugStrictRemoval  :boolean = true;  -- (false) Give a warning if a removal occurs and the notification doesn't exist.
local m_debugNotificationNum:number = 0;    -- (0) The # of fake notifications to fill the panel with; great for testing.


-- ===========================================================================
--  CONSTANTS
-- ===========================================================================

local COLOR_PIP_CURRENT           :number = 0xffffffff;
local COLOR_PIP_OTHER           :number = 0xff3c3c3c;
local DEBUG_NOTIFICATION_TYPE       :number = 999999;
local SIZE_TOP_SPACE_Y            :number = 140;
local TIME_PAUSE_FIRST_SHOW_NOTIFICATION  :number = 2;
local TIME_PAUSE_MOUSE_OVER_NOTIFICATION  :number = 1;
local TOPBAR_OFFSET             :number = 50;
local ACTION_CORNER_OFFSET          :number = 300; -- Rail should still visible further down screen even when extended
local DATA_ICON_PREFIX            :string = "ICON_";
local SCROLLBAR_OFFSET            :number = 13;
local MAX_WIDTH_INSTANCE          :number = 500;
local RAIL_OFFSET_ANIM_Y_OFFSET       :number = -72;

-- ===========================================================================
--  VARIABLES
-- ===========================================================================

local m_groupIM     :table = InstanceManager:new( "GroupInstance",  "Top", Controls.Groups );
local m_genericItemIM :table = InstanceManager:new( "ItemInstance", "Top", Controls.Items );

local m_screenX, m_screenY    :number = UIManager:GetScreenSizeVal();
local _, offsetY    :number = 0,0; --Controls.OuterStack:GetOffsetVal();

-- The structure for the handler functions for a notification type.
-- Each notification type can override one or more of these handlers, usually the Active handler
-- to allow for different functionality
hstructure NotificationHandler
  Add             : ifunction;
    Dismiss           : ifunction;
    TryDismiss          : ifunction;
    Activate          : ifunction;
  OnPhaseBegin        : ifunction;
  OnNextSelect        : ifunction;
  OnPreviousSelect      : ifunction;
  AddSound          : string;         -- optional: name of sound to trigger each time it 
end

-- The structure that holds the group data for a set of notifications.
hstructure NotificationGroupType
  m_GroupID         : number;         -- The group ID for all the notifications this group is tracking.
  m_InstanceManager     : table;          -- The instance manager that made the control set for the group.
    m_Instance          : table;          -- The instanced control set for the group UI.   
    m_PlayerID          : number;         -- The player who the notification is for
  m_Notifications       : table;          -- All the notifications that are in the group.
end

-- The structure that holds the UI notification data.
hstructure NotificationType
  m_InstanceManager     : table;          -- The instance manager that made the control set.
    m_Instance          : table;          -- The instanced control set.
  m_kHandlers         : NotificationHandler;    -- The handler set for the notification    
    m_PlayerID          : number;         -- The player who the notification is for
  m_IDs           : table;          -- The IDs related to this type of notificaiton
  m_Group           : NotificationGroupType;  -- The group of the notification, can be nil
  m_TypeName          : string;         -- Key for type of notification
  m_isAuto          : boolean;          -- If the notification auto re-adds based on per logic frame evaluation
  m_Index           : number;         -- Current index of notification being looked at.
  m_maxWidth          : number;         -- Largest width of message for this notification (stack).
  m_wrapWidth         : number;         -- Largest wrap width for this notification (stack). Used to avoid Y bouncing between messages.
end

local m_notifications     : table = {};       -- All the notification instances
local m_notificationGroups    : table = {};       -- The grouped notifications
local m_notificationHandlers  : table = {};
local m_kDebugNotification    : table = {};

local m_lastStackSize     : number = 0;
local m_lastStackDiff     : number = 0;
local m_ActionPanelGearAnim   : table  = ContextPtr:LookUpControl( "/InGame/ActionPanel/TickerAnim" );

local m_isLoadComplete          : boolean = false;

-- =======================================================================================
function GetActiveNotificationFromEntry(notificationEntry : NotificationType)

  if notificationEntry.m_Index >= 1 and notificationEntry.m_Index <= table.count(notificationEntry.m_IDs) then
    local notificationID :number = notificationEntry.m_IDs[ notificationEntry.m_Index ];
    local pNotification :table = NotificationManager.Find( notificationEntry.m_PlayerID, notificationID );
    return pNotification;
  end

  return nil;
end

-- =======================================================================================
function RegisterHandlers()

  -- Add the table of function handlers for each type of notification 
  m_notificationHandlers[DEBUG_NOTIFICATION_TYPE]                 = MakeDefaultHandlers();  --DEBUG
  m_notificationHandlers[NotificationTypes.DEFAULT]               = MakeDefaultHandlers();  --DEFAULT
  m_notificationHandlers[NotificationTypes.CHOOSE_ARTIFACT_PLAYER]        = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.CHOOSE_BELIEF]             = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.CHOOSE_CITY_PRODUCTION]        = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.CHOOSE_CIVIC]              = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.CHOOSE_PANTHEON]           = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.CHOOSE_RELIGION]           = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.CHOOSE_TECH]             = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.CITY_LOW_AMENITIES]          = MakeDefaultHandlers();  
  m_notificationHandlers[NotificationTypes.CLAIM_GREAT_PERSON]          = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.COMMAND_UNITS]             = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.CONSIDER_GOVERNMENT_CHANGE]      = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.CONSIDER_RAZE_CITY]          = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.DIPLOMACY_SESSION]                 = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.FILL_CIVIC_SLOT]           = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.GIVE_INFLUENCE_TOKEN]          = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.PLAYER_MET]                      = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.SPY_CHOOSE_DRAGNET_PRIORITY]     = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.SPY_CHOOSE_ESCAPE_ROUTE]       = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.SPY_KILLED]                    = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.TREASURY_BANKRUPT]               = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.HOUSING_PREVENTING_GROWTH]             = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.BARBARIANS_SIGHTED]                    = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.CAPITAL_LOST]              = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.TRADE_ROUTE_PLUNDERED]                 = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.CITY_STARVING]                   = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.CITY_FOOD_FOCUS]                 = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.CITYSTATE_QUEST_COMPLETED]         = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.TRADE_ROUTE_CAPACITY_INCREASED]      = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.RELIC_CREATED]                   = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.REBELLION]                       = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.PLAYER_DEFEATED]               = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.DISCOVER_CONTINENT]          = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.UNIT_PROMOTION_AVAILABLE]              = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.WONDER_COMPLETED]                      = MakeDefaultHandlers();
  m_notificationHandlers[NotificationTypes.ROADS_UPGRADED]            = MakeDefaultHandlers();

    m_notificationHandlers[NotificationTypes.SPY_HEIST_GREAT_WORK]                  = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_RECRUIT_PARTISANS]                 = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_SABOTAGED_PRODUCTION]              = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_SIPHONED_FUNDS]                    = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_STOLE_TECH_BOOST]                  = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_DISRUPTED_ROCKETRY]                = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_MISSION_FAILED]                    = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_CAPTURED]                          = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_MISSION_ABORTED]                   = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_COUNTERSPY_PROMOTED]               = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_CITY_SOURCES_GAINED]               = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_ESCAPED_CAPTURE]                   = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_LISTENING_POST]                    = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_FLED_CITY]                         = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_ENEMY_HEIST_GREAT_WORK]            = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_ENEMY_RECRUIT_PARTISANS]           = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_ENEMY_SABOTAGED_PRODUCTION]        = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_ENEMY_SIPHONED_FUNDS]              = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_ENEMY_STOLE_TECH_BOOST]            = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_ENEMY_DISRUPTED_ROCKETRY]          = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_ENEMY_CAPTURED]                    = MakeDefaultHandlers();
    m_notificationHandlers[NotificationTypes.SPY_ENEMY_KILLED]                      = MakeDefaultHandlers();
    
  -- Custom function handlers for the "Activate" signal:  
  m_notificationHandlers[DEBUG_NOTIFICATION_TYPE].Activate            = OnDebugActivate;
  m_notificationHandlers[NotificationTypes.CHOOSE_ARTIFACT_PLAYER].Activate   = OnChooseArtifactPlayerActivate;
  m_notificationHandlers[NotificationTypes.CHOOSE_BELIEF].Activate        = OnChooseReligionActivate;
  m_notificationHandlers[NotificationTypes.CHOOSE_CITY_PRODUCTION].Activate   = OnChooseCityProductionActivate; 
  m_notificationHandlers[NotificationTypes.CHOOSE_CIVIC].Activate         = OnChooseCivicActivate;  
  m_notificationHandlers[NotificationTypes.CHOOSE_PANTHEON].Activate        = OnChooseReligionActivate; 
  m_notificationHandlers[NotificationTypes.CHOOSE_RELIGION].Activate        = OnChooseReligionActivate; 
  m_notificationHandlers[NotificationTypes.CHOOSE_TECH].Activate          = OnChooseTechActivate; 
  m_notificationHandlers[NotificationTypes.CLAIM_GREAT_PERSON].Activate     = OnClaimGreatPersonActivate; 
  m_notificationHandlers[NotificationTypes.COMMAND_UNITS].Activate        = OnCommandUnitsActivate;
  m_notificationHandlers[NotificationTypes.CONSIDER_GOVERNMENT_CHANGE].Activate = OnConsiderGovernmentChangeActivate; 
  m_notificationHandlers[NotificationTypes.CONSIDER_RAZE_CITY].Activate     = OnConsiderRazeCityActivate; 
  m_notificationHandlers[NotificationTypes.DIPLOMACY_SESSION].Activate            = OnDiplomacySessionActivate;
  m_notificationHandlers[NotificationTypes.FILL_CIVIC_SLOT].Activate        = OnFillCivicSlotActivate;  
  m_notificationHandlers[NotificationTypes.GIVE_INFLUENCE_TOKEN].Activate     = OnGiveInfluenceTokenActivate; 
  m_notificationHandlers[NotificationTypes.SPY_CHOOSE_DRAGNET_PRIORITY].Activate  = OnChooseEscapeRouteActivate;
  m_notificationHandlers[NotificationTypes.SPY_CHOOSE_ESCAPE_ROUTE].Activate    = OnChooseEscapeRouteActivate;  
  m_notificationHandlers[NotificationTypes.PLAYER_DEFEATED].Activate        = OnLookAtAndActivateNotification;
  m_notificationHandlers[NotificationTypes.DISCOVER_CONTINENT].Activate     = OnDiscoverContinentActivateNotification;

  -- Sound to play when added
  m_notificationHandlers[NotificationTypes.SPY_KILLED].AddSound             = "ALERT_NEGATIVE"; 
  m_notificationHandlers[NotificationTypes.TREASURY_BANKRUPT].AddSound            = "ALERT_NEGATIVE"; 
  m_notificationHandlers[NotificationTypes.HOUSING_PREVENTING_GROWTH].AddSound    = "ALERT_NEUTRAL";  
  m_notificationHandlers[NotificationTypes.BARBARIANS_SIGHTED].AddSound           = "ALERT_NEGATIVE";
  m_notificationHandlers[NotificationTypes.CAPITAL_LOST].AddSound         = "ALERT_NEUTRAL";
  m_notificationHandlers[NotificationTypes.TRADE_ROUTE_PLUNDERED].AddSound        = "ALERT_NEGATIVE";
  m_notificationHandlers[NotificationTypes.CITY_STARVING].AddSound          = "ALERT_NEUTRAL";  
  m_notificationHandlers[NotificationTypes.CITY_FOOD_FOCUS].AddSound          = "ALERT_NEUTRAL";  
  m_notificationHandlers[NotificationTypes.CITY_LOW_AMENITIES].AddSound     = "ALERT_NEUTRAL";  
  m_notificationHandlers[NotificationTypes.CITYSTATE_QUEST_COMPLETED].AddSound  = "ALERT_POSITIVE"; 
  m_notificationHandlers[NotificationTypes.TRADE_ROUTE_CAPACITY_INCREASED].AddSound = "ALERT_POSITIVE"; 

  m_notificationHandlers[NotificationTypes.RELIC_CREATED].AddSound = "NOTIFICATION_MISC_POSITIVE";
  m_notificationHandlers[NotificationTypes.REBELLION].AddSound = "NOTIFICATION_REBELLION";
    
    m_notificationHandlers[NotificationTypes.UNIT_PROMOTION_AVAILABLE].AddSound     = "UNIT_PROMOTION_AVAILABLE";
    m_notificationHandlers[NotificationTypes.WONDER_COMPLETED].AddSound             = "NOTIFICATION_OTHER_CIV_BUILD_WONDER";
        
    m_notificationHandlers[NotificationTypes.SPY_HEIST_GREAT_WORK].AddSound         = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
    m_notificationHandlers[NotificationTypes.SPY_RECRUIT_PARTISANS].AddSound        = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
    m_notificationHandlers[NotificationTypes.SPY_SABOTAGED_PRODUCTION].AddSound     = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
    m_notificationHandlers[NotificationTypes.SPY_SIPHONED_FUNDS].AddSound           = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
    m_notificationHandlers[NotificationTypes.SPY_STOLE_TECH_BOOST].AddSound         = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
    m_notificationHandlers[NotificationTypes.SPY_DISRUPTED_ROCKETRY].AddSound       = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
    m_notificationHandlers[NotificationTypes.SPY_MISSION_FAILED].AddSound           = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
    m_notificationHandlers[NotificationTypes.SPY_CAPTURED].AddSound                 = "NOTIFICATION_ESPIONAGE_OP_FAILED";
    m_notificationHandlers[NotificationTypes.SPY_MISSION_ABORTED].AddSound          = "NOTIFICATION_ESPIONAGE_OP_FAILED";
    m_notificationHandlers[NotificationTypes.SPY_COUNTERSPY_PROMOTED].AddSound      = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
    m_notificationHandlers[NotificationTypes.SPY_CITY_SOURCES_GAINED].AddSound      = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
    m_notificationHandlers[NotificationTypes.SPY_ESCAPED_CAPTURE].AddSound          = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
    m_notificationHandlers[NotificationTypes.SPY_LISTENING_POST].AddSound           = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
    m_notificationHandlers[NotificationTypes.SPY_FLED_CITY].AddSound                = "NOTIFICATION_ESPIONAGE_OP_FAILED";
    m_notificationHandlers[NotificationTypes.SPY_ENEMY_HEIST_GREAT_WORK].AddSound   = "NOTIFICATION_ESPIONAGE_OP_FAILED";
    m_notificationHandlers[NotificationTypes.SPY_ENEMY_RECRUIT_PARTISANS].AddSound  = "NOTIFICATION_ESPIONAGE_OP_FAILED";
    m_notificationHandlers[NotificationTypes.SPY_ENEMY_SABOTAGED_PRODUCTION].AddSound = "NOTIFICATION_ESPIONAGE_OP_FAILED";
    m_notificationHandlers[NotificationTypes.SPY_ENEMY_SIPHONED_FUNDS].AddSound     = "NOTIFICATION_ESPIONAGE_OP_FAILED";
    m_notificationHandlers[NotificationTypes.SPY_ENEMY_STOLE_TECH_BOOST].AddSound   = "NOTIFICATION_ESPIONAGE_OP_FAILED";
    m_notificationHandlers[NotificationTypes.SPY_ENEMY_DISRUPTED_ROCKETRY].AddSound = "NOTIFICATION_ESPIONAGE_OP_FAILED";
    m_notificationHandlers[NotificationTypes.SPY_ENEMY_CAPTURED].AddSound           = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
    m_notificationHandlers[NotificationTypes.SPY_ENEMY_KILLED].AddSound             = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
    
  -- Custom function handlers for the "Add" signal:
  m_notificationHandlers[DEBUG_NOTIFICATION_TYPE].Add               = OnDebugAdd;
    m_notificationHandlers[NotificationTypes.PLAYER_MET].Add                        = OnMetCivAddNotification;

  -- Custom function handlers for the "Dismiss" signal:
  m_notificationHandlers[DEBUG_NOTIFICATION_TYPE].Dismiss             = OnDebugDismiss;

  -- Custom function handlers for the "OnPhaseBegin" signal:
  m_notificationHandlers[DEBUG_NOTIFICATION_TYPE].OnPhaseBegin          = OnPhaseBegin;
  

  -- Custom function handlers for the "TryDismiss" signal:
  
  -- Custom function handlers for the "OnNextSelect" callback:
  m_notificationHandlers[NotificationTypes.COMMAND_UNITS].OnNextSelect      = OnCommandUnitsNextSelect;

  -- Custom function handlers for the "OnPreviousSelect" callback:
  m_notificationHandlers[NotificationTypes.COMMAND_UNITS].OnPreviousSelect    = OnCommandUnitsPreviousSelect;
  
end

-- ===========================================================================
function ProcessStackSizes()
  ProcessNotificationSizes(Game.GetLocalPlayer());
  Controls.ScrollStack:CalculateSize();
    Controls.ScrollStack:ReprocessAnchoring();
  Controls.ScrollPanel:CalculateSize();
  local stacksize = Controls.ScrollStack:GetSizeY();
  
  -- Play the gear ticking animation
  if m_ActionPanelGearAnim ~= nil then
    m_ActionPanelGearAnim:SetToBeginning();
    m_ActionPanelGearAnim:Play();
  end

  -- If the notifications overflow the stack
  if (stacksize > m_screenY-TOPBAR_OFFSET-ACTION_CORNER_OFFSET) then
    if (Controls.RailOffsetAnim:GetOffsetX() ~= SCROLLBAR_OFFSET) then
      Controls.RailOffsetAnim:SetBeginVal(0,0);
      Controls.RailOffsetAnim:SetEndVal(SCROLLBAR_OFFSET,RAIL_OFFSET_ANIM_Y_OFFSET);
      Controls.RailOffsetAnim:SetToBeginning();
      Controls.RailOffsetAnim:Play();
    end
  else
    if (Controls.RailOffsetAnim:GetOffsetX() ~= 0) then
      Controls.RailOffsetAnim:SetBeginVal(SCROLLBAR_OFFSET,0);
      Controls.RailOffsetAnim:SetEndVal(0,RAIL_OFFSET_ANIM_Y_OFFSET);
      Controls.RailOffsetAnim:SetToBeginning();
      Controls.RailOffsetAnim:Play();
    end
  end

  Controls.ScrollStack:ReprocessAnchoring();

  -- Notifications were added to the stack at the beginning of the turn
  if (m_lastStackSize == 0 and stacksize ~= m_lastStackSize) then
    Controls.RailImage:SetSizeY(stacksize+ ACTION_CORNER_OFFSET);
    Controls.RailAnim:SetSizeY(ACTION_CORNER_OFFSET-stacksize);
    Controls.RailAnim:SetBeginVal(0,0);
    Controls.RailAnim:SetEndVal(0,0);
    Controls.RailAnim:SetToBeginning();
    if m_isLoadComplete then
      UI.PlaySound("UI_Notification_Bar_Notch");
    end
    Controls.RailAnim:Play();
  -- A notification was added or dismissed from the stack during the turn
  elseif (m_lastStackSize ~= 0 and stacksize ~= m_lastStackSize and stacksize ~= 0) then
    Controls.RailImage:SetSizeY(stacksize+ ACTION_CORNER_OFFSET);
    Controls.RailAnim:SetBeginVal(0,m_lastStackDiff);
    Controls.RailAnim:SetEndVal(0,m_lastStackDiff + stacksize-m_lastStackSize);
    Controls.RailAnim:SetToBeginning();
    Controls.RailAnim:Play();
    m_lastStackDiff = m_lastStackDiff + stacksize - m_lastStackSize;
  -- The stack size went from something to zero
  elseif (stacksize ~= m_lastStackSize and stacksize == 0) then
    Controls.RailAnim:SetBeginVal(0,m_lastStackDiff);
    Controls.RailAnim:SetEndVal(0,m_lastStackDiff-ACTION_CORNER_OFFSET);
    Controls.RailAnim:SetToBeginning();
    if m_isLoadComplete then
      UI.PlaySound("UI_Notification_Bar_Latch");
    end
    Controls.RailAnim:Play();
    Controls.RailImage:SetSizeY(100);
  end
  m_lastStackSize = stacksize;
end

-- ===========================================================================
--  Get the handler table for a notification type.  
--  Returns default handler table if one doesn't exist.
-- ===========================================================================
function GetHandler( notificationType:number )
  local handlers = m_notificationHandlers[notificationType];
  if (handlers == nil) then
    handlers = m_notificationHandlers[NotificationTypes.DEFAULT];
  end
  return handlers;
end

-- ===========================================================================
function GetDefaultHandler()
  return m_notificationHandlers[NotificationTypes.DEFAULT];
end

-- ===========================================================================
--  Sets width of notifications in the stack to the largest width.
-- ===========================================================================
function SetWidthNotificationStack( playerID:number, notificationID:number )
  -- Spacing details
  local X_EXTRA     :number = 20; -- Needs to cover right (collapsed) side button too.
  local X_EXTRA_MOUSE_OUT :number = 70;
  local X_AREA      :number = 215;

  -- Set the extends/bounds of the ExpandedArea of the notification stack
  local notificationEntry:NotificationType = GetNotificationEntry( playerID, notificationID );
  if (notificationEntry ~= nil) and (notificationEntry.m_Instance ~= nil) then
    for i,id in ipairs(notificationEntry.m_IDs) do
      local currentEntry :NotificationType = GetNotificationEntry( playerID, id );
      currentEntry.m_Instance.ExpandedArea:SetSizeX( currentEntry.m_maxWidth + X_EXTRA);
      currentEntry.m_Instance.NotificationSlide:SetEndVal( ((currentEntry.m_maxWidth - X_AREA) + X_EXTRA ), 0 );
      currentEntry.m_Instance.MouseOutArea:SetSizeX( currentEntry.m_maxWidth + X_EXTRA_MOUSE_OUT);
    end
  end
end

-- ===========================================================================
-- Does the list contain the specified notification ID?
function HasNotificationID( idList:table, notificationID:number)
  for i,id in ipairs(idList) do
    if id == notificationID then
      return true;
    end
  end
  return false;
end

-- ===========================================================================
-- Add a notification entry to for UI track.  This just adds a structure to track
-- the UI.  The UI itself is not initialized.
-- Ok if it already exists.
-- ===========================================================================
function AddNotificationEntry( playerID:number, typeName:string, notificationID:number, notificationGroupID:number )
  
  -- Obtain existing player table or create one if first time call is made.
  local playerTable :table = m_notifications[playerID];
  if playerTable == nil then
    m_notifications[playerID] = {};
    playerTable = m_notifications[playerID];
  end

  local notificationEntry = playerTable[typeName];
  if notificationEntry == nil then
    playerTable[typeName] = hmake NotificationType { 
      m_IDs   = {notificationID},         -- list with 1 item
      m_PlayerID  = playerID, 
      m_TypeName  = typeName,
      m_isAuto  = false,
      m_Group   = nil,
      m_Index   = 1,
      m_maxWidth  = 0,
      m_wrapWidth = 0,
    };
    notificationEntry = playerTable[typeName];

    -- Add it to its group, unless it is NONE
    if notificationGroupID ~= NotificationGroups.NONE then
      local notificationGroup = m_notificationGroups[notificationGroupID];
      if (m_notificationGroups[notificationGroupID] == nil) then
        m_notificationGroups[notificationGroupID] = hmake NotificationGroupType { 
          m_GroupID   = notificationGroupID; 
          m_PlayerID    = playerID; 
          m_Notifications = {} 
        };
        notificationGroup = m_notificationGroups[notificationGroupID];
      end

      -- Link entry to it's group
      notificationEntry.m_Group = notificationGroup;
      -- Add the entry to the group
      table.insert(notificationGroup.m_Notifications, notificationEntry);
    end

  else
    -- Check if we already have it in there.  There is a case where wee will get notification restoration events on player changed and we may have already received a notification add at turn start.
    if (not HasNotificationID(notificationEntry.m_IDs, notificationID)) then
      -- Add ID to list
      table.insert( notificationEntry.m_IDs, notificationID );

      -- Sanity check matching groups (better be, they are the same type!)
      if notificationEntry.m_Group ~= nil and notificationGroupID ~= notificationEntry.m_Group.m_GroupID then
        error("New notification #"..tostring(notificationID).." ("..typeName.. ")is in group "..notificationGroupID.." but group type already set to "..notificationEntry.m_Group.m_GroupID );
      end
    else
      return nil;   -- Signal that it is already in the list by returning nil
    end
  end
  return notificationEntry;
end

-- ===========================================================================
--  Returns UI entry for the notification or NIL.
-- ===========================================================================
function GetNotificationEntry( playerID:number, notificationID:number )
    
  local kPlayerTable:table = m_notifications[playerID];
  if (kPlayerTable == nil) then
    return nil;
  end

  for _,kNotification in pairs(kPlayerTable) do
    for _,id in ipairs(kNotification.m_IDs) do
      if id == notificationID then
        return kNotification;
      end
    end   
  end

  return nil;
end

-- ===========================================================================
--  Returns UI entry for the notification group or NIL.
-- ===========================================================================
function GetNotificationGroup(groupID)
  return m_notificationGroups[groupID];
end

-- ===========================================================================
--  Release the notification entry.
-- ===========================================================================
function ReleaseNotificationEntry( playerID:number, notificationID:number )
  -- Don't try and get the Game Core notification object, it might be gone
  local playerTable = m_notifications[playerID];
  if playerTable == nil then
    return;
  end

  local notificationEntry:NotificationType = GetNotificationEntry( playerID, notificationID );
  if notificationEntry ~= nil then
      
    -- Remove this ID instance. 
    local index :number = 1;
    for _,id in ipairs(notificationEntry.m_IDs) do
      if id == notificationID then
        table.remove( notificationEntry.m_IDs, index );
        break;
      end
      index = index + 1;
    end

    -- UI is blown away if last entry is now gone, or if auto-generating (as there is likely another notification for this in the list).
    if table.count(notificationEntry.m_IDs) == 0 then

      -- Release it's UI (if it has one)
      if notificationEntry.m_Instance ~= nil then
        notificationEntry.m_Instance.ItemButton:ClearMouseOverCallback();
        notificationEntry.m_Instance.MouseOutArea:ClearMouseExitCallback();

        if (notificationEntry.m_InstanceManager ~= nil) then
          notificationEntry.m_InstanceManager:ReleaseInstance( notificationEntry.m_Instance );
        else
          local pParent = notificationEntry.m_Instance.Top:GetParent();
          if (pParent ~= nil) then
            pParent:DestroyChild(notificationEntry.m_Instance.Top);
          else
            ContextPtr:DestroyChild(notificationEntry.m_Instance.Top);
          end
        end
      end

      -- Remove group reference (if any)
      local groupInstance:NotificationGroupType = notificationEntry.m_Group;
      if groupInstance ~= nil then
        notificationEntry.m_Group = nil;
        for i = 1, table.count(groupInstance.m_Notifications), 1 do
          if (groupInstance.m_Notifications[i] == notificationEntry) then
            table.remove(groupInstance.m_Notifications, i);
            break;
          end
        end
      end

      -- Remove empty group
      if (groupInstance ~= nil and table.count(groupInstance.m_Notifications) == 0) then
        if notificationEntry.m_Group ~= nil then
          m_notificationGroups[notificationEntry.m_Group] = nil;      
        end
      end   

      -- Remove this local data reference
      playerTable[notificationEntry.m_TypeName] = nil;
    else

      -- In most situations, since there is more than one ID left, it's safe to
      -- update the UI with the next ID, but there are cases where the engine
      -- is wiping out a bunch of IDs at once 
      -- (e.g., meeting more than 1 leader in a turn)
      -- In which case, more dismiss calls are about to be made... so check the
      -- engine still has a valid notification.

      local nextID      :number = notificationEntry.m_IDs[1];
      local pNotification   :table  = NotificationManager.Find( playerID, nextID );
      if pNotification ~= nil then
        RealizeStandardNotification( playerID, nextID );
        SetWidthNotificationStack(playerID, notificationID);
      end

    end

  else
    error("For player ("..tostring(playerID)..") unable to find notification ("..tostring(notificationID)..") for release.");
  end
end

-- ===========================================================================
--  Release the notification stack
-- ===========================================================================
function TryDismissNotificationStack( playerID:number, notificationID:number )
  local kPlayerTable:table = m_notifications[playerID];
  if (kPlayerTable == nil) then
    return nil;
  end   
  
  local topNotification :NotificationType = GetNotificationEntry( playerID, notificationID );
  if (topNotification == nil) then
    return nil;
  end

  local pNotification :table;
  for _,kNotification in pairs(kPlayerTable) do
    for _,id in ipairs(kNotification.m_IDs) do
      pNotification = NotificationManager.Find( playerID, id );
      if (pNotification ~= nil) then
        if ( topNotification.m_TypeName == pNotification:GetTypeName() ) and ( pNotification:CanUserDismiss() ) then
          NotificationManager.Dismiss( pNotification:GetPlayerID(), pNotification:GetID() );
        end
      end
    end
  end
end

-- ===========================================================================
--  Look at the current focus of a notification
-- ===========================================================================
function LookAtNotification( pNotification:table )
  local isLookedAt :boolean = false;

  if (pNotification == nil) then
    return;
  end

  -- Do we have a valid location?
  if pNotification:IsLocationValid() then     
    local x, y = pNotification:GetLocation(); -- Look at it.
    UI.LookAtPlot(x, y);
    isLookedAt = true;
  end
  
  -- Do we have a valid target?
  if pNotification:IsTargetValid() then     
    local targetPlayerID, targetID, targetType = pNotification:GetTarget();   
    -- Is it a unit?
    if targetType == PlayerComponentTypes.UNIT then
      local pUnit:table = Players[targetPlayerID]:GetUnits():FindID(targetID);
      if (pUnit ~= nil) then
        -- Look at it, if we have not already
        if (not isLookedAt) then 
          UI.LookAtPlot(pUnit:GetX(), pUnit:GetY());
        end
        -- Select it.
        UI.DeselectAllUnits();
        UI.DeselectAllCities();
        UI.SelectUnit(pUnit);
      end
    elseif targetType == PlayerComponentTypes.CITY then
      local pCity = Players[targetPlayerID]:GetCities():FindID(targetID);
      if (pCity ~= nil) then
        -- Look at it, if we have not already
        if (not isLookedAt) then 
          UI.LookAtPlot(pCity:GetX(), pCity:GetY());
        end
        -- Select it.
        UI.SelectCity(pCity);
      end
    end
  end
end

-- ===========================================================================
--  Look at the notification's supplied location, then call Activate on the object
-- ===========================================================================
function OnLookAtAndActivateNotification( notificationEntry : NotificationType )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
    local pNotification :table = GetActiveNotificationFromEntry(notificationEntry);
    if pNotification ~= nil then
      LookAtNotification( pNotification );
      pNotification:Activate();
    end
  end
end

-- ===========================================================================
--  The default handler for activating a notification.  
--  Usually called when the user left clicks the notification
-- ===========================================================================
function OnDefaultActivateNotification( notificationEntry : NotificationType )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
    local pNotification :table = GetActiveNotificationFromEntry(notificationEntry);
    if pNotification ~= nil then
      LookAtNotification( pNotification );
    end
  end
end

-- ===========================================================================
--  Default handler for adding a new notification
--  The input is the Game Core notification instance.
-- ===========================================================================
function OnDefaultAddNotification( pNotification:table )
  
  local typeName        :string       = pNotification:GetTypeName();
  if typeName == nil then
    UI.DataError("NIL notification type name for notifcation ID:"..tostring(pNotification:GetID()));
    return;
  end

  local playerID        :number       = pNotification:GetPlayerID();
  local notificationID    :number       = pNotification:GetID();
  local notificationGroupID :number       = pNotification:GetGroup();
  local notificationEntry   :NotificationType = AddNotificationEntry(playerID, typeName, notificationID, notificationGroupID);
  if (notificationEntry == nil) then
    return; -- Didn't add it for some reason.  It was either filtered out or possibly already in the list.
  end
  local kHandlers       :NotificationHandler= GetHandler( pNotification:GetType() );

  notificationEntry.m_kHandlers = kHandlers;

  -- TODO: If creating custom notification instances based on type:
  --[[
  if (ContextPtr:LookUpControl(typeName) ~= nil) then
    -- We have a custom UI for the notification type 
    ContextPtr:BuildInstanceForControl( typeName, notificationEntry.m_Instance, Controls.ScrollStack );
  else
    -- Make a generic UI
    notificationEntry.m_Instance = m_genericItemIM:GetInstance();
    notificationEntry.m_InstanceManager = m_genericItemIM;
    notificationEntry.m_Instance.Top:ChangeParent( Controls.ScrollStack );
  end
  ]]

  -- Only add a visual entry for this notification if:
  -- It is not a blocking type (otherwise assume the ActionPanel is displaying it)
  -- It is the first notification entry in a group
  if ( table.count(notificationEntry.m_IDs)==1 and pNotification:GetEndTurnBlocking() == EndTurnBlockingTypes.NO_ENDTURN_BLOCKING ) then

    notificationEntry.m_Instance    = m_genericItemIM:GetInstance();
    notificationEntry.m_InstanceManager = m_genericItemIM;
    notificationEntry.m_Instance.Top:ChangeParent( Controls.ScrollStack );
    notificationEntry.m_Instance["POINTER_IN"] = false; -- Manually track since 2 different, overlapping objects are tracking if a pointer is in/out

    if (notificationEntry.m_Instance ~= nil) then
      if (notificationEntry.m_Instance.ItemButton ~= nil and notificationEntry.m_Instance.ItemButtonInvalidPhase ~= nil) then

        -- Use the (collapse) button as the actual mouse-in area, but a larger rectangle will 
        -- track the mouse out, since the player may be interacting with the extended 
        -- information that flew out to the left of the notification.

        notificationEntry.m_Instance.ItemButton:RegisterCallback( Mouse.eLClick, function() kHandlers.Activate(notificationEntry); end );
        notificationEntry.m_Instance.ItemButton:RegisterCallback( Mouse.eRClick, function() kHandlers.TryDismiss(notificationEntry); end );
        notificationEntry.m_Instance.ItemButton:RegisterMouseEnterCallback( function() OnMouseEnterNotification( notificationEntry.m_Instance ); end );
        notificationEntry.m_Instance.MouseOutArea:RegisterMouseExitCallback( function()  OnMouseExitNotification( notificationEntry.m_Instance ); end );

        --Set the notification icon

        if(notificationEntry.m_TypeName ~= nil) then
          local iconName :string = DATA_ICON_PREFIX .. notificationEntry.m_TypeName;
          local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName,40);
          if (textureOffsetX ~= nil) then
            notificationEntry.m_Instance.Icon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
          end
        end

        --A notification in the wrong phase can be dismissed but not activated.
        local messageName:string = Locale.Lookup(pNotification:GetMessage());
        notificationEntry.m_Instance.ItemButtonInvalidPhase:RegisterCallback( Mouse.eLClick, OnDoNothing );
        notificationEntry.m_Instance.ItemButtonInvalidPhase:RegisterCallback( Mouse.eRClick, function() kHandlers.TryDismiss(notificationEntry); end );
        local toolTip:string = messageName .. "[NEWLINE]" .. Locale.Lookup("LOC_NOTIFICATION_WRONG_PHASE_TT", messageName);
        notificationEntry.m_Instance.ItemButtonInvalidPhase:SetToolTipString(toolTip);

        -- If notification is auto generated, it will have an internal count.
        notificationEntry.m_isAuto = pNotification:IsAutoNotify();

        -- Sets current phase state.
        notificationEntry.m_kHandlers.OnPhaseBegin( playerID, notificationID );

        -- Upon creation, animation will automatically reverse and play out after showing.
        local pAnimControl:table = notificationEntry.m_Instance.NotificationSlide;
        pAnimControl:SetPauseTime( 0 );
        pAnimControl:RegisterEndCallback(
          function()
            pAnimControl:ClearEndCallback();
            pAnimControl:SetPauseTime( TIME_PAUSE_FIRST_SHOW_NOTIFICATION );
            pAnimControl:Reverse();         
          end
        );
      end
    end
  end
  RealizeStandardNotification( playerID, notificationID );
end


-- ===========================================================================
-- ===========================================================================
function OnMouseEnterNotification( pInstance:table )
  local pAnimControl:table = pInstance.NotificationSlide;

  if pInstance["POINTER_IN"] or pAnimControl:IsInPause() then
    return;
  end

  pInstance["POINTER_IN"] = true;

  -- Remove any end callbacks and get this out there.
  pAnimControl:ClearEndCallback();
  pAnimControl:SetToBeginning();
  pAnimControl:SetPauseTime( 0 );
  if pAnimControl:IsStopped() then
    pAnimControl:Play();
  else
    if pAnimControl:IsReversing() then
      pAnimControl:Reverse();
    end
  end
end

-- ===========================================================================
--
-- ===========================================================================
function OnMouseExitNotification( pInstance:table )   
  if not pInstance.NotificationSlide:IsStopped() then
    -- If still playing, apply logic once it's done.
    local pAnimControl:table = pInstance.NotificationSlide;
    pAnimControl:RegisterEndCallback(
      function()
        pAnimControl:ClearEndCallback();
        ApplyCollapseLogic( pInstance );
      end
    );    
  else
    -- Done playing, immediately apply collapsing logic.
    ApplyCollapseLogic( pInstance );
  end
  pInstance["POINTER_IN"] = false;
end

-- ===========================================================================
--  Calculate and set the maximum width for a notification
-- ===========================================================================
function RealizeMaxWidth( notificationEntry:NotificationType , pNotification:table )
  local widthTitle      :number = 0; -- Width of the notification title
  local widthSummary      :number = 0; -- Width of the notification summary
  local titleWidthPadding   :number = 0; -- Calculated, adds the width of the arrows and number label
  local summaryWidthPadding :number = 15;

  if notificationEntry ~= nil then
    -- Seeing if the arrow is hidden is a quick way to check that there's more than one notification in this stack
    if notificationEntry.m_Instance.LeftArrow:IsHidden() == false then
      titleWidthPadding = (notificationEntry.m_Instance.TitleCount:GetSizeX() +
                (notificationEntry.m_Instance.LeftArrow:GetSizeX() * 2));
    else 
      -- Don't pad out the stack since there aren't extra buttons or a title count
      summaryWidthPadding = 0;
    end
    widthTitle = notificationEntry.m_Instance.TitleInfo:GetSizeX() + titleWidthPadding;
    widthSummary = notificationEntry.m_Instance.Summary:GetSizeX() + summaryWidthPadding;
    if widthTitle > notificationEntry.m_maxWidth or widthSummary > notificationEntry.m_maxWidth then
      if widthTitle > widthSummary then
        notificationEntry.m_maxWidth = widthTitle;
      else
        notificationEntry.m_maxWidth = widthSummary;
      end
    end
  else
    return;
  end

  -- Check to make sure PipStack doesn't overflow the width
  if notificationEntry.m_maxWidth < notificationEntry.m_Instance.PagePipStack:GetSizeX() then
    notificationEntry.m_maxWidth = notificationEntry.m_Instance.PagePipStack:GetSizeX();
  end

  --  If the max width is larger than the word wrap width, use that for word wrap instead so text will fill
  --    the grid and not clump in the middle.
  if notificationEntry.m_maxWidth > (notificationEntry.m_wrapWidth + summaryWidthPadding) then
    notificationEntry.m_wrapWidth = notificationEntry.m_maxWidth - summaryWidthPadding;
    notificationEntry.m_Instance.Summary:SetWrapWidth(notificationEntry.m_wrapWidth);
  end
end

-- ===========================================================================
--  Assign the notification summary and title to the notification instance, 
--    and set wrap width if needs to be wrapped
-- ===========================================================================
function SetNotificationText( notificationEntry:NotificationType , pNotification:table )
  if (pNotification ~= nil) then    -- Because the notification storage is 'ahead' of the events, the notification may be gone (we will get an event shortly)
    local messageName:string = Locale.Lookup( pNotification:GetMessage() ); 
    local summary:string = Locale.Lookup(pNotification:GetSummary());
    local widthSummary :number = 0;

    notificationEntry.m_Instance.TitleInfo:SetString( Locale.ToUpper(messageName) );
    notificationEntry.m_Instance.Summary:SetString( summary );

    widthSummary = notificationEntry.m_Instance.Summary:GetSizeX();

    if widthSummary > MAX_WIDTH_INSTANCE then
      notificationEntry.m_wrapWidth = widthSummary / 1.9; -- Don't quite halve it so it doesn't wrap last word onto third line.
    else
      notificationEntry.m_wrapWidth = m_screenX; -- Don't wrap at all.
    end
  end
end

-- ===========================================================================
--  Determine contents of this notification.
--  Assumes this is a "standard" style.
-- ===========================================================================
function RealizeStandardNotification( playerID:number, notificationID:number )

  local notificationEntry :NotificationType = GetNotificationEntry( playerID, notificationID );
  local count       :number       = table.count(notificationEntry.m_IDs);
  local pNotification   :table        = NotificationManager.Find( playerID, notificationID );

  if pNotification == nil then
    if m_debugStrictRemoval then
      alert("NIL Notification: ",playerID, notificationID );
    end
    return;
  end

  -- No instance was generated for this notification, either another notification
  -- is representing it here or another context (e.g., ActionPanel) is showing it
  -- on the HUD.
  if notificationEntry.m_Instance == nil then
    return;
  end

  SetNotificationText(notificationEntry, pNotification);

  -- Auto generated, obtain the actual count...
  if notificationEntry.m_isAuto then
    count = pNotification:GetCount();       
  end

  notificationEntry.m_Instance.CountImage:SetHide( count < 2 );
  notificationEntry.m_Instance.TitleCount:SetHide( count < 2 );
  notificationEntry.m_Instance.LeftArrow:SetHide( count < 2 );
  notificationEntry.m_Instance.RightArrow:SetHide( count < 2 );
  notificationEntry.m_Instance.PagePipStack:SetHide( count < 2 );

  if count > 1 then   
    notificationEntry.m_Instance.Count:SetText( tostring(count) );
    notificationEntry.m_Instance.DismissStackButton:RegisterCallback( Mouse.eRClick,    function() TryDismissNotificationStack(playerID, notificationID); end );
    notificationEntry.m_Instance.TitleCount:SetText( tostring(count) );
    notificationEntry.m_Instance.TitleStack:ReprocessAnchoring();

    notificationEntry.m_Instance.LeftArrow:RegisterCallback( Mouse.eLClick,   function() notificationEntry.m_kHandlers.OnPreviousSelect(pNotification); end );
    notificationEntry.m_Instance.RightArrow:RegisterCallback( Mouse.eLClick,  function() notificationEntry.m_kHandlers.OnNextSelect(pNotification); end );

    -- Prepare the area
    notificationEntry.m_Instance.PagePipStack:DestroyAllChildren();
    
    for i=1,count,1 do
      local pipInstance:table = {};
      ContextPtr:BuildInstanceForControl("PipInstance", pipInstance, notificationEntry.m_Instance.PagePipStack);
      pipInstance.Pip:SetColor( i==notificationEntry.m_Index and COLOR_PIP_CURRENT or COLOR_PIP_OTHER );
    end 

  else
    notificationEntry.m_Instance.LeftArrow:ClearCallback( Mouse.eLClick );
    notificationEntry.m_Instance.RightArrow:ClearCallback( Mouse.eLClick );
  end

  RealizeMaxWidth(notificationEntry, pNotification);
  -- Set text again now that calculations are done, text must always match the current index!!
  SetNotificationText(notificationEntry, NotificationManager.Find(playerID, notificationEntry.m_IDs[ notificationEntry.m_Index ]));
end

-- ===========================================================================
--  Applies collapsing logic onto an instance.
-- ===========================================================================
function ApplyCollapseLogic( pInstance:table )
  if not pInstance.NotificationSlide:IsReversing() then
    pInstance.NotificationSlide:Reverse();
  end
  pInstance.NotificationSlide:SetPauseTime( TIME_PAUSE_MOUSE_OVER_NOTIFICATION );
end


-- ===========================================================================
--  Default handler for removing the UI entry.
-- ===========================================================================
function OnDefaultDismissNotification( playerID:number, notificationID:number )
  -- Don't try and get the Game Core notification object, it might be gone
  ReleaseNotificationEntry( playerID, notificationID );
end 

-- ===========================================================================
--  Default handler for a user request to try and manually dismiss a notification.
-- ===========================================================================
function OnDefaultTryDismissNotification( notificationEntry : NotificationType )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
    local pNotification :table = GetActiveNotificationFromEntry(notificationEntry);
    if (pNotification ~= nil) then
      if (pNotification:CanUserDismiss()) then
        NotificationManager.Dismiss( pNotification:GetPlayerID(), pNotification:GetID() );
      end
    end
  end
end 

-- ===========================================================================
--  Default event handler for a turn phase beginning (Multiplayer)
-- ===========================================================================
function OnDefaultPhaseBeginNotification( playerID:number, notificationID:number )
  local pNotification = NotificationManager.Find( playerID, notificationID );
  local notificationEntry = GetNotificationEntry( playerID, notificationID );
  if (pNotification ~= nil and notificationEntry ~= nil and notificationEntry.m_Instance ~= nil ) then
    local isValidForPhase :boolean = pNotification:IsValidForPhase();
    notificationEntry.m_Instance.ItemButton:SetHide(not isValidForPhase);
    notificationEntry.m_Instance.ItemButtonInvalidPhase:SetHide(isValidForPhase);
  end
end 

-- ===========================================================================
--  Default event handler for the next notification in a "stacking"
-- ===========================================================================
function OnDefaultNextSelectNotification( pNotification:table )
  local playerID        :number       = pNotification:GetPlayerID();
  local notificationID    :number       = pNotification:GetID();
  local notificationEntry   :NotificationType = GetNotificationEntry(playerID, notificationID); 

  notificationEntry.m_Index = notificationEntry.m_Index + 1;
  if notificationEntry.m_Index > table.count(notificationEntry.m_IDs) then  -- Check for wrap around
    notificationEntry.m_Index = 1;
  end
  local nextID        :number = notificationEntry.m_IDs[ notificationEntry.m_Index ];
  local pNextNotification   :table = NotificationManager.Find( playerID, nextID );
  LookAtNotification( pNextNotification );
  RealizeStandardNotification( playerID, nextID );      -- Buttons map with new ID
end

-- ===========================================================================
--  Default event handler for the previous notification in a "stacking"
-- ===========================================================================
function OnDefaultPreviousSelectNotification( pNotification:table )
  local playerID        :number       = pNotification:GetPlayerID();
  local notificationID    :number       = pNotification:GetID();
  local notificationEntry   :NotificationType = GetNotificationEntry(playerID, notificationID); 
  local nextID        :number = -1;

  notificationEntry.m_Index = notificationEntry.m_Index - 1;
  if notificationEntry.m_Index == 0 then  -- Check for wrap around
    notificationEntry.m_Index = table.count(notificationEntry.m_IDs);
  end
  local nextID        :number = notificationEntry.m_IDs[ notificationEntry.m_Index ];
  local pNextNotification   :table = NotificationManager.Find( playerID, nextID );
  LookAtNotification( pNextNotification );
  RealizeStandardNotification( playerID, nextID );      -- Buttons map with new ID
end

-- =======================================================================================
--  Empty event handler.
--  Used by notifications in the wrong phase so the button efx still trigger.
-- =======================================================================================
function OnDoNothing( playerID:number, notificationID:number)
end

-- =======================================================================================
--  Create a table with the default handlers callbacks
-- =======================================================================================
function MakeDefaultHandlers()
  return hmake NotificationHandler 
  {
    Add       = OnDefaultAddNotification,
    Dismiss     = OnDefaultDismissNotification,
    TryDismiss    = OnDefaultTryDismissNotification,
    Activate    = OnDefaultActivateNotification,
    OnPhaseBegin  = OnDefaultPhaseBeginNotification,
    OnNextSelect  = OnDefaultNextSelectNotification,
    OnPreviousSelect= OnDefaultPreviousSelectNotification
  };
end

-- =======================================================================================
-- Choose Tech Handlers
-- =======================================================================================
function OnChooseTechActivate( notificationEntry : NotificationType )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
    LuaEvents.ActionPanel_OpenChooseResearch();
  end
end

-- =======================================================================================
-- Choose City Production Handlers
-- =======================================================================================
function OnChooseCityProductionActivate( notificationEntry : NotificationType )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then

    local pNotification :table = GetActiveNotificationFromEntry(notificationEntry);
    if pNotification ~= nil then
      LookAtNotification( pNotification );
      LuaEvents.NotificationPanel_ChooseProduction();
    end
  end
end

-- =======================================================================================
-- Choose Civic Handlers
-- =======================================================================================
function OnChooseCivicActivate( notificationEntry : NotificationType )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
    LuaEvents.ActionPanel_OpenChooseCivic();
  end
end

-- =======================================================================================
-- Consider Civic Change Handlers
-- =======================================================================================
function OnFillCivicSlotActivate( notificationEntry : NotificationType )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
    LuaEvents.NotificationPanel_GovernmentOpenPolicies();
  end
end

-- =======================================================================================
-- Move or give an operation to a unit
-- =======================================================================================
function OnCommandUnitsActivate( notificationEntry : NotificationType )
  UI.SelectNextReadyUnit(); 
end

-- =======================================================================================
--  Look at the next unit.
-- =======================================================================================
function OnCommandUnitsNextSelect( pNotification:table )
  local playerID        :number       = pNotification:GetPlayerID();
  local notificationID    :number       = pNotification:GetID();
  local notificationEntry   :NotificationType = GetNotificationEntry(playerID, notificationID); 

  notificationEntry.m_Index = notificationEntry.m_Index + 1;
  if notificationEntry.m_Index > pNotification:GetCount() then  -- Check for wrap around
    notificationEntry.m_Index = 1;
  end
  RealizeStandardNotification( playerID, notificationID );  -- Update pips
  UI.SelectNextReadyUnit();                 -- Engine automatically moves camera
end

-- =======================================================================================
--  Look at the previous unit.
-- =======================================================================================
function OnCommandUnitsPreviousSelect( pNotification:table)
  local playerID        :number       = pNotification:GetPlayerID();
  local notificationID    :number       = pNotification:GetID();
  local notificationEntry   :NotificationType = GetNotificationEntry(playerID, notificationID); 

  notificationEntry.m_Index = notificationEntry.m_Index - 1;
  if notificationEntry.m_Index == 0 then  -- Check for wrap around
    notificationEntry.m_Index = pNotification:GetCount();
  end
  RealizeStandardNotification( playerID, notificationID );  -- Update pips  
  UI.SelectPrevReadyUnit();                 -- Engine automatically moves camera
end


-- =======================================================================================
-- Consider Government Change Handlers
-- =======================================================================================
function OnConsiderGovernmentChangeActivate( notificationEntry : NotificationType )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
    LuaEvents.NotificationPanel_GovernmentOpenGovernments();
  end
end

-- =======================================================================================
-- Consider Raze City Handlers
-- =======================================================================================
function OnConsiderRazeCityActivate( notificationEntry : NotificationType )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then

    local pNotification :table = GetActiveNotificationFromEntry(notificationEntry);
    if pNotification ~= nil then
      LookAtNotification( pNotification );
    end
    LuaEvents.NotificationPanel_OpenRazeCityChooser();
  end
end

-- =======================================================================================
-- Choose Religion Handlers
-- =======================================================================================
function OnChooseReligionActivate( notificationEntry : NotificationType )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
    LuaEvents.NotificationPanel_OpenReligionPanel();
  end
end

-- =======================================================================================
-- Archaeology Handlers
-- =======================================================================================
function OnChooseArtifactPlayerActivate( notificationEntry : NotificationType )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
    LuaEvents.NotificationPanel_OpenArtifactPanel();
  end
end

-- =======================================================================================
-- Give Influence Token Handlers
-- =======================================================================================
function OnGiveInfluenceTokenActivate( notificationEntry : NotificationType )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
    LuaEvents.NotificationPanel_OpenCityStatesSendEnvoys(); 
  end
end

-- =======================================================================================
-- Claim Great Person Handlers
-- =======================================================================================
function OnClaimGreatPersonActivate( notificationEntry : NotificationType )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
    LuaEvents.NotificationPanel_OpenGreatPeoplePopup();
  end
end

-- =======================================================================================
-- Espionage Handlers
-- =======================================================================================
function OnChooseEscapeRouteActivate( notificationEntry : NotificationType )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
    local TEST_PARAM :number = 23;                    --??TRON: existing test parameter?
    LuaEvents.NotificationPanel_OpenEspionageEscape( TEST_PARAM );
  end
end

-- =======================================================================================
-- Diplomacy Handlers
-- =======================================================================================
function OnDiplomacySessionActivate( notificationEntry : NotificationType ) 
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
    local pNotification :table = GetActiveNotificationFromEntry(notificationEntry);
    if pNotification ~= nil then
      pNotification:Activate();
    end
  end
end

-- =======================================================================================
-- Discovered Continent Handlers
-- =======================================================================================
function OnDiscoverContinentActivateNotification( notificationEntry : NotificationType )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
    local pNotification :table = GetActiveNotificationFromEntry(notificationEntry);
        if pNotification ~= nil then
      LookAtNotification( pNotification );
        end
        LuaEvents.NotificationPanel_ShowContinentLens();
  end
end

-- =======================================================================================
function OnMetCivAddNotification( pNotification:table ) 
    if m_isLoadComplete then
        UI.PlaySound("NOTIFICATION_MISC_NEUTRAL"); 
    end
  OnDefaultAddNotification( pNotification );
end

-- =======================================================================================
function OnDebugAdd( name:string, fakeID:number )

  local playerID      :number       = Game.GetLocalPlayer();
  local notificationID  :number       = m_kDebugNotification[table.count(m_kDebugNotification)];
  local notificationEntry :NotificationType = AddNotificationEntry( playerID, name, 1000000 + fakeID, NotificationGroups.NONE  );
  local kHandlers     :NotificationHandler= GetHandler( DEBUG_NOTIFICATION_TYPE );

  notificationEntry.m_Instance    = m_genericItemIM:GetInstance();
  notificationEntry.m_InstanceManager = m_genericItemIM;
  notificationEntry.m_Instance.Top:ChangeParent( Controls.ScrollStack );
  notificationEntry.m_Instance["POINTER_IN"] = false; -- Manually track since 2 different, overlapping objects are tracking if a pointer is in/out

  if notificationEntry.m_Instance ~= nil then
    if (notificationEntry.m_Instance.ItemButton ~= nil and notificationEntry.m_Instance.ItemButtonInvalidPhase ~= nil) then
      notificationEntry.m_Instance.ItemButton:SetVoid1( playerID );
      notificationEntry.m_Instance.ItemButton:SetVoid2( notificationID );

      notificationEntry.m_Instance.ItemButton:RegisterCallback( Mouse.eLClick, kHandlers.Activate );
      notificationEntry.m_Instance.ItemButton:RegisterCallback( Mouse.eRClick, function() kHandlers.Dismiss(playerID, 1000000 + notificationID); end );
      notificationEntry.m_Instance.ItemButton:RegisterMouseEnterCallback( function() OnMouseEnterNotification( notificationEntry.m_Instance ); end );
      notificationEntry.m_Instance.MouseOutArea:RegisterMouseExitCallback( function()  OnMouseExitNotification( notificationEntry.m_Instance ); end );

      notificationEntry.m_Instance.ItemButtonInvalidPhase:RegisterCallback( Mouse.eLClick, OnDoNothing );
      notificationEntry.m_Instance.ItemButtonInvalidPhase:RegisterCallback( Mouse.eRClick, OnDoNothing );
      notificationEntry.m_Instance.ItemButtonInvalidPhase:SetToolTipString("DEBUG");
      notificationEntry.m_isAuto = false;

      --notificationEntry.m_kHandlers.OnPhaseBegin( playerID, notificationID );
      notificationEntry.m_Instance.ItemButton:SetHide(false);
      notificationEntry.m_Instance.ItemButtonInvalidPhase:SetHide(true);

      -- Upon creation, animation will automatically reverse and play out after showing.
      local pAnimControl:table = notificationEntry.m_Instance.NotificationSlide;
      pAnimControl:SetPauseTime( 0 );
      pAnimControl:RegisterEndCallback(
        function()
          pAnimControl:ClearEndCallback();
          pAnimControl:SetPauseTime( TIME_PAUSE_FIRST_SHOW_NOTIFICATION );
          pAnimControl:Reverse();         
        end
      );
      notificationEntry.m_Instance.TitleInfo:SetString( name );
      notificationEntry.m_Instance.Summary:SetString( name );
      notificationEntry.m_Instance.Summary:SetWrapWidth(  notificationEntry.m_Instance.ExpandedArea:GetSizeX() );

      notificationEntry.m_Instance.CountImage:SetHide( true );
      notificationEntry.m_Instance.TitleCount:SetHide( true );
      notificationEntry.m_Instance.LeftArrow:SetHide( true );
      notificationEntry.m_Instance.RightArrow:SetHide( true );
      notificationEntry.m_Instance.PagePipStack:SetHide( true );
    end
  end
end

-- =======================================================================================
function OnDebugActivate()
end

-- =======================================================================================
function OnDebugDismiss(playerID,notificationID)
  ReleaseNotificationEntry( playerID, notificationID );
  ProcessStackSizes();
end

-- =======================================================================================
--  Generate a debug event
-- =======================================================================================
function MakeDebugNotification( name:string, fakeID:number )
  local handler = GetHandler( DEBUG_NOTIFICATION_TYPE );  
  table.insert(m_kDebugNotification, fakeID);
  handler.Add( name, fakeID );  
end


-- ===========================================================================
--  ENGINE Event
--  A notification was added, if it doesn't block the end-turn; add to notification list.
-- ===========================================================================
function OnNotificationAdded( playerID:number, notificationID:number )
  if (playerID == Game.GetLocalPlayer())  then -- Was it for us?
    local pNotification = NotificationManager.Find( playerID, notificationID );
    if pNotification ~= nil then
      --print("    OnNotificationAdded():",notificationID, "for type "..tostring(pNotification:GetMessage()) ); --debug
      local handler = GetHandler( pNotification:GetType() );
      handler.Add(pNotification);
      if handler.AddSound ~= nil and handler.AddSound ~= "" then
                if m_isLoadComplete then
                    UI.PlaySound(handler.AddSound);
                end
      end
      ProcessStackSizes();
      SetWidthNotificationStack(playerID, notificationID);
    else
      -- Sanity check
      UI.DataError("Notification added Event but not found in manager. PlayerID - " .. tostring(playerID) .. " Notification ID - " .. tostring(notificationID));
    end

    if notificationID	== 577 then                   -- CQUI: Notification when a City lost tile by Culture Bomb (Index == 577)
      LuaEvents.CQUI_CityLostTileByCultureBomb();
    end
  end
end

-- ===========================================================================
--  ENGINE Event
--  A notification was dismissed
-- ===========================================================================
function OnNotificationDismissed( playerID:number, notificationID:number )
  if (playerID == Game.GetLocalPlayer()) then -- one of the ones we track?
    -- Don't try and get the Game Core notification object, it might be gone
    local notificationEntry:NotificationType = GetNotificationEntry( playerID, notificationID );
    if notificationEntry ~= nil then    
      --print("OnNotificationDismissed():",notificationID); --debug
      local handler = notificationEntry.m_kHandlers;
      handler.Dismiss( playerID, notificationID );
    end
    ProcessStackSizes();
    SetWidthNotificationStack(playerID, notificationID);
  end
end

-- ===========================================================================
--  ENGINE Event
--  All notifications are about to be refreshed
-- ===========================================================================
function OnNotificationRefreshRequested()
  Controls.ScrollStack:DestroyAllChildren();
  m_genericItemIM:DestroyInstances();
  m_groupIM:DestroyInstances();
  m_lastStackSize = 0;

  -- Add debug notifications
  if m_debugNotificationNum > 0 then
    for i=1,m_debugNotificationNum,1 do
      MakeDebugNotification("Debug"..tostring(i), i );
    end
    ProcessStackSizes();
  end
end

-- ===========================================================================
--  New turn phase has begun.
-- ===========================================================================
function OnPhaseBegin()
  for playerID, playerTable in pairs(m_notifications) do
    if playerID == Game.GetLocalPlayer() then
      for typeName, notificationEntry in pairs(playerTable) do
        for _,notificationID in ipairs(notificationEntry.m_IDs) do
          if notificationEntry.m_kHandlers.OnPhaseBegin ~= nil then
            notificationEntry.m_kHandlers.OnPhaseBegin( playerID, notificationID );
          end
        end
      end
    end
  end
end


-- ===========================================================================
--  LUA Event
--  A request to activate a notification from another Lua file.
-- ===========================================================================
function OnLuaActivateNotification( pNotification:table )
  if (pNotification ~= nil and pNotification:IsValidForPhase()) then
    local playerID = pNotification:GetPlayerID();
    local notificationID = pNotification:GetID();
    local notificationEntry = GetNotificationEntry( playerID, notificationID );
    if (notificationEntry ~= nil) then
      local handler = notificationEntry.m_kHandlers;
      handler.Activate( notificationEntry );
    end
  end
end

-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnInterfaceModeChanged(eOldMode:number, eNewMode:number)
  if eNewMode == InterfaceModeTypes.VIEW_MODAL_LENS then
    ContextPtr:SetHide(true);
  end
  if eOldMode == InterfaceModeTypes.VIEW_MODAL_LENS then
    ContextPtr:SetHide(false);
  end
end

-- ===========================================================================
--  Resizes/realigns each notification slide
-- ===========================================================================
function ProcessNotificationSizes( playerID:number )
    
  local kPlayerTable:table = m_notifications[playerID];
  if (kPlayerTable == nil) then
    return;
  end

  for _,kNotification in pairs(kPlayerTable) do
    local currentEntry :NotificationType = kNotification;
    if currentEntry.m_Instance ~= nil then
      currentEntry.m_Instance.Clip:SetSizeX(m_screenX);
      currentEntry.m_Instance.Clip:CalculateSize();
      currentEntry.m_Instance.Clip:ReprocessAnchoring();
      if currentEntry.m_Instance.NotificationSlide ~= nil and (currentEntry.m_Instance.NotificationSlide:GetNumChildren() ~= 0) then
        currentEntry.m_Instance.NotificationSlide:SetToBeginning();
      end
    end
    SetWidthNotificationStack( playerID, id);
  end
  return;
end

-- ===========================================================================
--  Handle a resize
-- ===========================================================================
function Resize()
  m_screenX, m_screenY  = UIManager:GetScreenSizeVal();
  Controls.RailOffsetAnim:ReprocessAnchoring();
  Controls.RailAnim:ReprocessAnchoring();
  
  Controls.RailOffsetAnim:SetToBeginning();
  Controls.RailOffsetAnim:Play();

  Controls.RailAnim:SetBeginVal(0,0);
  Controls.RailAnim:SetEndVal(0,0);
  Controls.RailAnim:SetToBeginning();
  Controls.RailAnim:Play();
  ProcessStackSizes();
end

-- ===========================================================================
--  On update UI - Handle a resize
-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string)
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end

-- ===========================================================================
--  UI Event
-- ===========================================================================
function OnInit( isReload:boolean )
  if isReload then      
    NotificationManager.RestoreVisualState(Game.GetLocalPlayer());  -- Restore the notifications
  end
end

-- ===========================================================================
--  Clear all of the notification UI.
-- ===========================================================================
function ClearNotifications()

  -- Propery destroy instances; especially so callbacks are destroy... 
  -- otherwise hotloading may not hot load.
  for playerID,playerTable in pairs(m_notifications) do
    if playerTable ~= nil then
      for typeName, notification in pairs( playerTable ) do
        for _, id in ipairs( notification.m_IDs ) do
          ReleaseNotificationEntry( playerID, id );
        end       
      end
    end
  end
  
end


-- ===========================================================================
--  UI Event
-- ===========================================================================
function OnShutdown()

  ClearNotifications();
  
end

-- ===========================================================================
--  The local player has changed (hotseat, autoplay)
-- ===========================================================================
function OnLocalPlayerChanged()
  m_lastStackDiff = 0;
  m_lastStackSize = 0;
  Controls.RailImage:SetSizeY(100);
  ClearNotifications();
  NotificationManager.RestoreVisualState(Game.GetLocalPlayer());  -- Restore the notifications
end

-- ===========================================================================
--  The loading screen has completed
-- ===========================================================================
function OnLoadGameViewStateDone()
    m_isLoadComplete = true;
end

-- ===========================================================================
--  Remove notification if the target unit for the notification has been killed
-- ===========================================================================
function OnUnitKilledInCombat( targetUnit )
  local playerID :number = Game.GetLocalPlayer();
  local kPlayerTable:table = m_notifications[playerID];

  if (kPlayerTable == nil) then
    return;
  end

  for _,kNotification in pairs(kPlayerTable) do
    local notificationEntry :NotificationType = kNotification;
    if notificationEntry.m_Instance ~= nil then
      local pNotification :table = GetActiveNotificationFromEntry(notificationEntry);
      if (pNotification ~= nil) then
        local targetPlayerID, targetID, targetType = pNotification:GetTarget();   
        -- Is it a unit?
        if targetType == PlayerComponentTypes.UNIT then
          if pNotification:IsTargetValid() then 
            local pUnit:table = Players[targetPlayerID]:GetUnits():FindID(targetID);
            if (pUnit == nil) then    
              ReleaseNotificationEntry( playerId, notificationEntry.m_IDs[ notificationEntry.m_Index ]);
            end
          end
        end
      end
    end
  end
end

function CQUI_AddNotification(description:string, summary:string)
    local handler = GetHandler( NotificationTypes.DEFAULT );  
  table.insert(m_kDebugNotification);
  handler.Add( summary, table.count(m_kDebugNotificaiton)); 
end

-- ===========================================================================
--  Setup
-- ===========================================================================
function Initialize()
  
  RegisterHandlers();

  ContextPtr:SetInitHandler( OnInit );
  ContextPtr:SetShutdown( OnShutdown );

  Events.NotificationAdded.Add(       OnNotificationAdded );
  Events.NotificationDismissed.Add(     OnNotificationDismissed );
  Events.NotificationRefreshRequested.Add(  OnNotificationRefreshRequested );

  Events.UnitKilledInCombat.Add( OnUnitKilledInCombat );

  Events.SystemUpdateUI.Add( OnUpdateUI );

  Events.PhaseBegin.Add( OnPhaseBegin );

  Events.LocalPlayerChanged.Add( OnLocalPlayerChanged );

  Events.InterfaceModeChanged.Add(    OnInterfaceModeChanged );

    m_isLoadComplete = false;
  Events.LoadGameViewStateDone.Add( OnLoadGameViewStateDone );

  LuaEvents.ActionPanel_ActivateNotification.Add( OnLuaActivateNotification );

    -- CQUI
    LuaEvents.CQUI_AddNotification.Add( CQUI_AddNotification );
end
Initialize();
