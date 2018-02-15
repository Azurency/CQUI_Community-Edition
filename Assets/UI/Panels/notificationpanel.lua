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
local SIZE_PIP								:number = 12;
local SIZE_TOP_SPACE_Y            :number = 140;
local TOPBAR_OFFSET             :number = 50;
local ACTION_CORNER_OFFSET          :number = 300; -- Rail should still visible further down screen even when extended
local DATA_ICON_PREFIX            :string = "ICON_";
local SCROLLBAR_OFFSET            :number = 13;
local MAX_WIDTH_INSTANCE          :number = 500;
local RAIL_OFFSET_ANIM_Y_OFFSET       :number = -72;
local TITLE_OFFSET_NO_COUNT					:number = 5;
local TITLE_OFFSET_DEFAULT					:number = 1;

-- ===========================================================================
--  VARIABLES
-- ===========================================================================

local m_genericItemIM	:table = InstanceManager:new( "ItemInstance",	"Top", Controls.ScrollStack );

local m_screenX, m_screenY    :number = UIManager:GetScreenSizeVal();
local _, offsetY    :number = 0,0; --Controls.OuterStack:GetOffsetVal();

-- The structure for the handler functions for a notification type.
-- Each notification type can override one or more of these handlers, usually the Active handler
-- to allow for different functionality
hstructure NotificationHandler
  Add             : ifunction;
    Dismiss           : ifunction;
    TryDismiss          : ifunction;
    TryActivate					: ifunction;
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
	m_PipInstanceManager		: table;
  m_kHandlers         : NotificationHandler;    -- The handler set for the notification
    m_PlayerID          : number;         -- The player who the notification is for
  m_IDs           : table;          -- The IDs related to this type of notificaiton
  m_Group           : NotificationGroupType;  -- The group of the notification, can be nil
  m_TypeName          : string;         -- Key for type of notification
  m_IconName          : string;         -- Key for the primary icon of the notification
  m_isAuto          : boolean;          -- If the notification auto re-adds based on per logic frame evaluation
  m_Index           : number;         -- Current index of notification being looked at.
  m_maxWidth          : number;         -- Largest width of message for this notification (stack).
  m_wrapWidth         : number;         -- Largest wrap width for this notification (stack). Used to avoid Y bouncing between messages.
end

local m_notifications     : table = {};       -- All the notification instances
local m_notificationGroups    : table = {};       -- The grouped notifications
-- local m_notificationHandlers  : table = {};
local m_kDebugNotification    : table = {};

local m_lastStackSize     : number = 0;
-- local m_lastStackDiff     : number = 0;
local m_ActionPanelGearAnim   : table  = ContextPtr:LookUpControl( "/InGame/ActionPanel/TickerAnim" );

local m_isLoadComplete          : boolean = false;

g_notificationHandlers = {};

-- =======================================================================================
function GetActiveNotificationFromEntry(notificationEntry : NotificationType, notificationID : number)

  -- Supply a specific ID?
  if notificationID ~= nil then
    local pNotification :table = NotificationManager.Find( notificationEntry.m_PlayerID, notificationID );
    return pNotification;
    
  else
    -- Activate the active index.
    if notificationEntry.m_Index >= 1 and notificationEntry.m_Index <= table.count(notificationEntry.m_IDs) then
      local notificationID :number = notificationEntry.m_IDs[ notificationEntry.m_Index ];
      local pNotification	:table = NotificationManager.Find( notificationEntry.m_PlayerID, notificationID );
      return pNotification;
    end
  end

  return nil;
end

-- =======================================================================================
function RegisterHandlers()

  -- Add the table of function handlers for each type of notification
  g_notificationHandlers[DEBUG_NOTIFICATION_TYPE]                           = MakeDefaultHandlers();  --DEBUG
  g_notificationHandlers[NotificationTypes.DEFAULT]                         = MakeDefaultHandlers();  --DEFAULT
  g_notificationHandlers[NotificationTypes.CHOOSE_ARTIFACT_PLAYER]          = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.CHOOSE_BELIEF]                   = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.CHOOSE_CITY_PRODUCTION]          = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.CHOOSE_CIVIC]                    = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.CHOOSE_PANTHEON]                 = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.CHOOSE_RELIGION]                 = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.CHOOSE_TECH]                     = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.CITY_LOW_AMENITIES]              = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.CLAIM_GREAT_PERSON]              = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.COMMAND_UNITS]                   = MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.CITY_RANGE_ATTACK]					      = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.CONSIDER_GOVERNMENT_CHANGE]      = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.CONSIDER_RAZE_CITY]              = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.DIPLOMACY_SESSION]               = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.FILL_CIVIC_SLOT]                 = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.GIVE_INFLUENCE_TOKEN]            = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.PLAYER_MET]                      = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_CHOOSE_DRAGNET_PRIORITY]     = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_CHOOSE_ESCAPE_ROUTE]         = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_KILLED]                      = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.TREASURY_BANKRUPT]               = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.HOUSING_PREVENTING_GROWTH]       = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.BARBARIANS_SIGHTED]              = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.CAPITAL_LOST]                    = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.TRADE_ROUTE_PLUNDERED]           = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.CITY_STARVING]                   = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.CITY_FOOD_FOCUS]                 = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.CITYSTATE_QUEST_COMPLETED]       = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.TRADE_ROUTE_CAPACITY_INCREASED]  = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.RELIC_CREATED]                   = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.REBELLION]                       = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.PLAYER_DEFEATED]                 = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.DISCOVER_CONTINENT]              = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.UNIT_PROMOTION_AVAILABLE]        = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.WONDER_COMPLETED]                = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.ROADS_UPGRADED]                  = MakeDefaultHandlers();
  
  g_notificationHandlers[NotificationTypes.SPY_HEIST_GREAT_WORK]            = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_RECRUIT_PARTISANS]           = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_SABOTAGED_PRODUCTION]        = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_SIPHONED_FUNDS]              = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_STOLE_TECH_BOOST]            = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_DISRUPTED_ROCKETRY]          = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_MISSION_FAILED]              = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_CAPTURED]                    = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_MISSION_ABORTED]             = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_COUNTERSPY_PROMOTED]         = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_CITY_SOURCES_GAINED]         = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_ESCAPED_CAPTURE]             = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_LISTENING_POST]              = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_FLED_CITY]                   = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_ENEMY_HEIST_GREAT_WORK]      = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_ENEMY_RECRUIT_PARTISANS]     = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_ENEMY_SABOTAGED_PRODUCTION]  = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_ENEMY_SIPHONED_FUNDS]        = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_ENEMY_STOLE_TECH_BOOST]      = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_ENEMY_DISRUPTED_ROCKETRY]    = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_ENEMY_CAPTURED]              = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.CITY_BESIEGED_BY_OTHER_PLAYER]   = MakeDefaultHandlers();
  g_notificationHandlers[NotificationTypes.SPY_ENEMY_KILLED]                = MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.TECH_BOOST]							        = MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.CIVIC_BOOST]							        = MakeDefaultHandlers();

  -- Custom function handlers for the "Activate" signal:
  g_notificationHandlers[DEBUG_NOTIFICATION_TYPE].Activate            = OnDebugActivate;
  g_notificationHandlers[NotificationTypes.CHOOSE_ARTIFACT_PLAYER].Activate   = OnChooseArtifactPlayerActivate;
  g_notificationHandlers[NotificationTypes.CHOOSE_BELIEF].Activate        = OnChooseReligionActivate;
  g_notificationHandlers[NotificationTypes.CHOOSE_CITY_PRODUCTION].Activate   = OnChooseCityProductionActivate;
  g_notificationHandlers[NotificationTypes.CHOOSE_CIVIC].Activate         = OnChooseCivicActivate;
  g_notificationHandlers[NotificationTypes.CHOOSE_PANTHEON].Activate        = OnChooseReligionActivate;
  g_notificationHandlers[NotificationTypes.CHOOSE_RELIGION].Activate        = OnChooseReligionActivate;
  g_notificationHandlers[NotificationTypes.CHOOSE_TECH].Activate          = OnChooseTechActivate;
  g_notificationHandlers[NotificationTypes.CLAIM_GREAT_PERSON].Activate     = OnClaimGreatPersonActivate;
  g_notificationHandlers[NotificationTypes.COMMAND_UNITS].Activate        = OnCommandUnitsActivate;
	g_notificationHandlers[NotificationTypes.CITY_RANGE_ATTACK].Activate			= OnCityRangeAttack;
  g_notificationHandlers[NotificationTypes.CONSIDER_GOVERNMENT_CHANGE].Activate = OnConsiderGovernmentChangeActivate;
  g_notificationHandlers[NotificationTypes.CONSIDER_RAZE_CITY].Activate     = OnConsiderRazeCityActivate;
  g_notificationHandlers[NotificationTypes.DIPLOMACY_SESSION].Activate            = OnDiplomacySessionActivate;
  g_notificationHandlers[NotificationTypes.FILL_CIVIC_SLOT].Activate        = OnFillCivicSlotActivate;
  g_notificationHandlers[NotificationTypes.GIVE_INFLUENCE_TOKEN].Activate     = OnGiveInfluenceTokenActivate;
  g_notificationHandlers[NotificationTypes.SPY_CHOOSE_DRAGNET_PRIORITY].Activate  = OnChooseEscapeRouteActivate;
  g_notificationHandlers[NotificationTypes.SPY_CHOOSE_ESCAPE_ROUTE].Activate    = OnChooseEscapeRouteActivate;
	g_notificationHandlers[NotificationTypes.PLAYER_DEFEATED].Activate				= OnLookAtActivate;
  g_notificationHandlers[NotificationTypes.DISCOVER_CONTINENT].Activate     = OnDiscoverContinentActivateNotification;
	g_notificationHandlers[NotificationTypes.TECH_BOOST].Activate					= OnTechBoostActivateNotification;
	g_notificationHandlers[NotificationTypes.CIVIC_BOOST].Activate					= OnCivicBoostActivateNotification;

  -- Sound to play when added
  g_notificationHandlers[NotificationTypes.SPY_KILLED].AddSound             = "ALERT_NEGATIVE";
  g_notificationHandlers[NotificationTypes.TREASURY_BANKRUPT].AddSound            = "ALERT_NEGATIVE";
  g_notificationHandlers[NotificationTypes.HOUSING_PREVENTING_GROWTH].AddSound    = "ALERT_NEUTRAL";
  g_notificationHandlers[NotificationTypes.BARBARIANS_SIGHTED].AddSound           = "ALERT_NEGATIVE";
  g_notificationHandlers[NotificationTypes.CITY_BESIEGED_BY_OTHER_PLAYER].AddSound= "ALERT_NEGATIVE";
  g_notificationHandlers[NotificationTypes.CAPITAL_LOST].AddSound         = "ALERT_NEUTRAL";
  g_notificationHandlers[NotificationTypes.TRADE_ROUTE_PLUNDERED].AddSound        = "ALERT_NEGATIVE";
  g_notificationHandlers[NotificationTypes.CITY_STARVING].AddSound          = "ALERT_NEUTRAL";
  g_notificationHandlers[NotificationTypes.CITY_FOOD_FOCUS].AddSound          = "ALERT_NEUTRAL";
  g_notificationHandlers[NotificationTypes.CITY_LOW_AMENITIES].AddSound     = "ALERT_NEUTRAL";
  g_notificationHandlers[NotificationTypes.CITYSTATE_QUEST_COMPLETED].AddSound  = "ALERT_POSITIVE";
  g_notificationHandlers[NotificationTypes.TRADE_ROUTE_CAPACITY_INCREASED].AddSound = "ALERT_POSITIVE";
  
  g_notificationHandlers[NotificationTypes.RELIC_CREATED].AddSound = "NOTIFICATION_MISC_POSITIVE";
  g_notificationHandlers[NotificationTypes.REBELLION].AddSound = "NOTIFICATION_REBELLION";
  
  g_notificationHandlers[NotificationTypes.UNIT_PROMOTION_AVAILABLE].AddSound     = "UNIT_PROMOTION_AVAILABLE";
  g_notificationHandlers[NotificationTypes.WONDER_COMPLETED].AddSound             = "NOTIFICATION_OTHER_CIV_BUILD_WONDER";
  
  g_notificationHandlers[NotificationTypes.SPY_HEIST_GREAT_WORK].AddSound         = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
  g_notificationHandlers[NotificationTypes.SPY_RECRUIT_PARTISANS].AddSound        = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
  g_notificationHandlers[NotificationTypes.SPY_SABOTAGED_PRODUCTION].AddSound     = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
  g_notificationHandlers[NotificationTypes.SPY_SIPHONED_FUNDS].AddSound           = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
  g_notificationHandlers[NotificationTypes.SPY_STOLE_TECH_BOOST].AddSound         = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
  g_notificationHandlers[NotificationTypes.SPY_DISRUPTED_ROCKETRY].AddSound       = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
  g_notificationHandlers[NotificationTypes.SPY_MISSION_FAILED].AddSound           = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
  g_notificationHandlers[NotificationTypes.SPY_CAPTURED].AddSound                 = "NOTIFICATION_ESPIONAGE_OP_FAILED";
  g_notificationHandlers[NotificationTypes.SPY_MISSION_ABORTED].AddSound          = "NOTIFICATION_ESPIONAGE_OP_FAILED";
  g_notificationHandlers[NotificationTypes.SPY_COUNTERSPY_PROMOTED].AddSound      = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
  g_notificationHandlers[NotificationTypes.SPY_CITY_SOURCES_GAINED].AddSound      = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
  g_notificationHandlers[NotificationTypes.SPY_ESCAPED_CAPTURE].AddSound          = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
  g_notificationHandlers[NotificationTypes.SPY_LISTENING_POST].AddSound           = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
  g_notificationHandlers[NotificationTypes.SPY_FLED_CITY].AddSound                = "NOTIFICATION_ESPIONAGE_OP_FAILED";
  g_notificationHandlers[NotificationTypes.SPY_ENEMY_HEIST_GREAT_WORK].AddSound   = "NOTIFICATION_ESPIONAGE_OP_FAILED";
  g_notificationHandlers[NotificationTypes.SPY_ENEMY_RECRUIT_PARTISANS].AddSound  = "NOTIFICATION_ESPIONAGE_OP_FAILED";
  g_notificationHandlers[NotificationTypes.SPY_ENEMY_SABOTAGED_PRODUCTION].AddSound = "NOTIFICATION_ESPIONAGE_OP_FAILED";
  g_notificationHandlers[NotificationTypes.SPY_ENEMY_SIPHONED_FUNDS].AddSound     = "NOTIFICATION_ESPIONAGE_OP_FAILED";
  g_notificationHandlers[NotificationTypes.SPY_ENEMY_STOLE_TECH_BOOST].AddSound   = "NOTIFICATION_ESPIONAGE_OP_FAILED";
  g_notificationHandlers[NotificationTypes.SPY_ENEMY_DISRUPTED_ROCKETRY].AddSound = "NOTIFICATION_ESPIONAGE_OP_FAILED";
  g_notificationHandlers[NotificationTypes.SPY_ENEMY_CAPTURED].AddSound           = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";
  g_notificationHandlers[NotificationTypes.SPY_ENEMY_KILLED].AddSound             = "NOTIFICATION_ESPIONAGE_OP_SUCCESS";

  -- Custom function handlers for the "Add" signal:
  g_notificationHandlers[DEBUG_NOTIFICATION_TYPE].Add           = OnDebugAdd;
  g_notificationHandlers[NotificationTypes.PLAYER_MET].Add      = OnMetCivAddNotification;

  -- Custom function handlers for the "Dismiss" signal:
  g_notificationHandlers[DEBUG_NOTIFICATION_TYPE].Dismiss       = OnDebugDismiss;

  -- Custom function handlers for the "OnPhaseBegin" signal:
  g_notificationHandlers[DEBUG_NOTIFICATION_TYPE].OnPhaseBegin  = OnPhaseBegin;

  -- Custom function handlers for the "TryDismiss" signal:

  -- Custom function handlers for the "OnNextSelect" callback:
  g_notificationHandlers[NotificationTypes.COMMAND_UNITS].OnNextSelect     = OnCommandUnitsNextSelect;

  -- Custom function handlers for the "OnPreviousSelect" callback:
  g_notificationHandlers[NotificationTypes.COMMAND_UNITS].OnPreviousSelect = OnCommandUnitsPreviousSelect;

end

-- ===========================================================================
function ProcessStackSizes()
  ProcessNotificationSizes(Game.GetLocalPlayer());
  Controls.ScrollStack:CalculateSize();
  Controls.ScrollPanel:CalculateSize();
  
  -- Play the gear ticking animation
  if m_ActionPanelGearAnim ~= nil then
    m_ActionPanelGearAnim:SetToBeginning();
    m_ActionPanelGearAnim:Play();
  end

  -- If the notifications overflow the stack
  if (Controls.ScrollBar:IsVisible()) then
	Controls.ScrollPanel:SetOffsetY(280);
    if (Controls.RailOffsetAnim:GetOffsetX() ~= SCROLLBAR_OFFSET) then
      Controls.RailOffsetAnim:SetBeginVal(0,0);
      Controls.RailOffsetAnim:SetEndVal(SCROLLBAR_OFFSET,RAIL_OFFSET_ANIM_Y_OFFSET);
      Controls.RailOffsetAnim:SetToBeginning();
      Controls.RailOffsetAnim:Play();
    end
  else
		Controls.ScrollPanel:SetOffsetY(300);
    if (Controls.RailOffsetAnim:GetOffsetX() ~= 0) then
      Controls.RailOffsetAnim:SetBeginVal(SCROLLBAR_OFFSET,0);
      Controls.RailOffsetAnim:SetEndVal(0,RAIL_OFFSET_ANIM_Y_OFFSET);
      Controls.RailOffsetAnim:SetToBeginning();
      Controls.RailOffsetAnim:Play();
    end
  end

  Controls.ScrollStack:ReprocessAnchoring();
end

-- ===========================================================================
function OnStackSizeChanged()
	local stacksize = Controls.ScrollStack:GetSizeY();
  if (m_lastStackSize == 0 and stacksize ~= m_lastStackSize) then
    -- Notifications were added to the stack at the beginning of the turn
    Controls.RailImage:SetSizeY(stacksize+ ACTION_CORNER_OFFSET);
    Controls.RailAnim:SetSizeY(ACTION_CORNER_OFFSET-stacksize);
    Controls.RailAnim:SetBeginVal(0,0);
    Controls.RailAnim:SetEndVal(0,0);
    Controls.RailAnim:SetToBeginning();
    if m_isLoadComplete then
      UI.PlaySound("UI_Notification_Bar_Notch");
    end
    Controls.RailAnim:Play();

  elseif (m_lastStackSize ~= 0 and stacksize ~= m_lastStackSize and stacksize ~= 0) then
    -- A notification was added or dismissed from the stack during the turn
    Controls.RailImage:SetSizeY(stacksize+ ACTION_CORNER_OFFSET);
    Controls.RailAnim:SetSizeY(ACTION_CORNER_OFFSET-stacksize);
    Controls.RailAnim:SetBeginVal(0,m_lastStackSize-stacksize);
    Controls.RailAnim:SetEndVal(0,0);
    Controls.RailAnim:SetToBeginning();
    Controls.RailAnim:Play();
    -- m_lastStackDiff = m_lastStackDiff + stacksize - m_lastStackSize;
  elseif (stacksize ~= m_lastStackSize and stacksize == 0) then
    -- The stack size went from something to zero
    Controls.RailAnim:SetBeginVal(0,0);
    Controls.RailAnim:SetEndVal(0,-ACTION_CORNER_OFFSET-m_lastStackSize);
    Controls.RailAnim:SetToBeginning();
    if m_isLoadComplete then
      UI.PlaySound("UI_Notification_Bar_Latch");
    end
    Controls.RailAnim:Play();
    -- Controls.RailImage:SetSizeY(100);
  end
  m_lastStackSize = stacksize;
end

-- ===========================================================================
--  Get the handler table for a notification type.
--  Returns default handler table if one doesn't exist.
-- ===========================================================================
function GetHandler( notificationType:number )
  local handlers = g_notificationHandlers[notificationType];
  if (handlers == nil) then
    handlers = g_notificationHandlers[NotificationTypes.DEFAULT];
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
function RealizeNotificationSize( playerID:number, notificationID:number )
  -- Spacing details
  local X_EXTRA     :number = 20; -- Needs to cover right (collapsed) side button too.
  local X_EXTRA_MOUSE_OUT :number = 70;
  local X_AREA      :number = 215;

  -- Set the extends/bounds of the ExpandedArea of the notification stack
  local notificationEntry:NotificationType = GetNotificationEntry( playerID, notificationID );
  if (notificationEntry ~= nil) and (notificationEntry.m_Instance ~= nil) then
		notificationEntry.m_Instance.ExpandedArea:SetSizeX( notificationEntry.m_maxWidth + X_EXTRA);
		notificationEntry.m_Instance.NotificationSlide:SetEndVal( ((notificationEntry.m_maxWidth - X_AREA) + X_EXTRA ), 0 );
		notificationEntry.m_Instance.MouseOutArea:SetSizeX(notificationEntry.m_maxWidth + X_EXTRA_MOUSE_OUT);
		if notificationEntry.m_Instance.m_MouseIn and notificationEntry.m_Instance.NotificationSlide:IsStopped() then
			notificationEntry.m_Instance.NotificationSlide:SetToEnd();
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
function AddNotificationEntry( playerID:number, typeName:string, notificationID:number, notificationGroupID:number, iconName:string )

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
      m_IconName  = iconName,
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
function ReleaseNotificationEntry( playerID:number, notificationID:number, isShuttingDown:boolean )
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
				notificationEntry.m_Instance.MouseInArea:ClearMouseOverCallback();
        notificationEntry.m_Instance.MouseOutArea:ClearMouseExitCallback();
				notificationEntry.m_Instance.MouseOutArea:SetHide(true);

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
			if index > 1 then index = index - 1; end
			local nextID:number = notificationEntry.m_IDs[index];
			local pNotification:table = NotificationManager.Find( playerID, nextID );
			local nextEntry:NotificationType = GetNotificationEntry( playerID, nextID );
			if not isShuttingDown and pNotification and nextEntry then
				nextEntry.m_Index = index;
        RealizeStandardNotification( playerID, nextID );
				RealizeNotificationSize(playerID, nextID);
				RealizeMaxWidth(nextEntry, pNotification);
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
function OnLookAtActivate( notificationEntry : NotificationType )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
    local pNotification :table = GetActiveNotificationFromEntry(notificationEntry);
    if pNotification ~= nil then
      LookAtNotification( pNotification );
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
  local notificationPrimaryIconName :string = pNotification:GetIconName();
  local notificationEntry   :NotificationType = AddNotificationEntry(playerID, typeName, notificationID, notificationGroupID, notificationPrimaryIconName);
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
  end
  ]]

  -- Only add a visual entry for this notification if:
  -- It is not a blocking type (otherwise assume the ActionPanel is displaying it)
  -- It is the first notification entry in a group
  if ( table.count(notificationEntry.m_IDs)==1 and pNotification:GetEndTurnBlocking() == EndTurnBlockingTypes.NO_ENDTURN_BLOCKING ) then

    notificationEntry.m_Instance    = m_genericItemIM:GetInstance();
    notificationEntry.m_InstanceManager = m_genericItemIM;
		notificationEntry.m_Instance.m_MouseIn = false;	-- Manually track since 2 different, overlapping objects are tracking if a pointer is in/out

		if notificationEntry.m_Instance then
        -- Use the (collapse) button as the actual mouse-in area, but a larger rectangle will
        -- track the mouse out, since the player may be interacting with the extended
        -- information that flew out to the left of the notification.

			if pNotification:IsValidForPhase() then
				notificationEntry.m_Instance.MouseInArea:RegisterCallback( Mouse.eLClick, function() kHandlers.TryActivate(notificationEntry); end );
				notificationEntry.m_Instance.MouseInArea:RegisterCallback( Mouse.eRClick, function() kHandlers.TryDismiss(notificationEntry); end );
				notificationEntry.m_Instance.MouseOutArea:RegisterCallback( Mouse.eLClick, function() OnClickMouseOutArea(notificationEntry); end );
				notificationEntry.m_Instance.MouseOutArea:RegisterCallback( Mouse.eRClick, function() OnClickMouseOutArea(notificationEntry, true); end );
			else
				--A notification in the wrong phase can be dismissed but not activated.
				local messageName:string = Locale.Lookup(pNotification:GetMessage());
				notificationEntry.m_Instance.MouseInArea:RegisterCallback( Mouse.eLClick, OnDoNothing );
				notificationEntry.m_Instance.MouseInArea:RegisterCallback( Mouse.eRClick, function() kHandlers.TryDismiss(notificationEntry); end );
				notificationEntry.m_Instance.MouseOutArea:RegisterCallback( Mouse.eLClick, OnDoNothing );
				notificationEntry.m_Instance.MouseOutArea:RegisterCallback( Mouse.eRClick, function() kHandlers.TryDismiss(notificationEntry); end );
				local toolTip:string = messageName .. "[NEWLINE]" .. Locale.Lookup("LOC_NOTIFICATION_WRONG_PHASE_TT", messageName);
				notificationEntry.m_Instance.MouseInArea:SetToolTipString(toolTip);
			end
			notificationEntry.m_Instance.MouseInArea:RegisterMouseEnterCallback( function() OnMouseEnterNotification( notificationEntry.m_Instance ); end );
      notificationEntry.m_Instance.MouseOutArea:RegisterMouseExitCallback( function()  OnMouseExitNotification( notificationEntry.m_Instance ); end );

      --Set the notification icon
      if (notificationEntry.m_IconName ~= nil) then
        local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(notificationEntry.m_IconName,40);
        if (textureOffsetX ~= nil) then
            notificationEntry.m_Instance.Icon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
        end
      else
        if (notificationEntry.m_TypeName ~= nil) then
          local iconName :string = DATA_ICON_PREFIX .. notificationEntry.m_TypeName;
          local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName,40);
          if (textureOffsetX ~= nil) then
            notificationEntry.m_Instance.Icon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
          end
        end
      end

      -- If notification is auto generated, it will have an internal count.
      notificationEntry.m_isAuto = pNotification:IsAutoNotify();

      -- Sets current phase state.
      notificationEntry.m_kHandlers.OnPhaseBegin( playerID, notificationID );

			-- Reset animation control
			notificationEntry.m_Instance.NotificationSlide:Stop();
			notificationEntry.m_Instance.NotificationSlide:SetToBeginning();
    end
  end
  -- Update size of notification
  RealizeStandardNotification( playerID, notificationID );
end

function OnClickMouseOutArea(notificationEntry, dismiss)
	if notificationEntry.m_Instance.LeftArrow:HasMouseOver() then
		notificationEntry.m_kHandlers.OnPreviousSelect(GetActiveNotificationFromEntry(notificationEntry));
	elseif notificationEntry.m_Instance.RightArrow:HasMouseOver() then
		notificationEntry.m_kHandlers.OnNextSelect(GetActiveNotificationFromEntry(notificationEntry));
	else
		if dismiss then
			notificationEntry.m_kHandlers.TryDismiss(notificationEntry);
		else
			notificationEntry.m_kHandlers.TryActivate(notificationEntry);
    end
  end
end


-- ===========================================================================
-- ===========================================================================
function OnMouseEnterNotification( pInstance:table )
  local pAnimControl:table = pInstance.NotificationSlide;

  -- Make sure all other notifications are in their disabled state
  for _, tmpInstance in ipairs(m_genericItemIM.m_AllocatedInstances) do
    if tmpInstance ~= pInstance then
      OnMouseExitNotification(tmpInstance);
    end
  end
    
	if pInstance.m_MouseIn or pAnimControl:IsInPause() then
    return;
  end

	pInstance.m_MouseIn = true;
	pInstance.MouseOutArea:SetHide(false);

  -- Remove any end callbacks and get this out there.
  pAnimControl:ClearEndCallback();
  pAnimControl:SetToBeginning();
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
	elseif pInstance.m_MouseIn then
    -- Done playing, immediately apply collapsing logic.
    ApplyCollapseLogic( pInstance );
  end
	pInstance.m_MouseIn = false;
end

-- ===========================================================================
--  Calculate and set the maximum width for a notification
-- ===========================================================================
function GetMaxWidth( notificationEntry:NotificationType , pNotification:table )
  local widthTitle      :number = 0; -- Width of the notification title
  local widthSummary      :number = 0; -- Width of the notification summary
  local titleWidthPadding   :number = 0; -- Calculated, adds the width of the arrows and number label
	local summaryWidthPadding	:number = 20;

	if notificationEntry and notificationEntry.m_Instance then
    -- Seeing if the arrow is hidden is a quick way to check that there's more than one notification in this stack
		if notificationEntry.m_Instance.LeftArrow:IsVisible() then
			titleWidthPadding = notificationEntry.m_Instance.TitleCount:GetSizeX();
			summaryWidthPadding = (notificationEntry.m_Instance.LeftArrow:GetSizeX() * 2) + 50;
    else
      -- Don't pad out the stack since there aren't extra buttons or a title count
      summaryWidthPadding = 0;
    end
    widthTitle = notificationEntry.m_Instance.TitleInfo:GetSizeX() + titleWidthPadding;
    widthSummary = notificationEntry.m_Instance.Summary:GetSizeX() + summaryWidthPadding;
      if widthTitle > widthSummary then
			return widthTitle, summaryWidthPadding;
      else
			return widthSummary, summaryWidthPadding;
      end
    end
	return 0, 0;
end
function RealizeMaxWidth( notificationEntry:NotificationType , pNotification:table )

	if notificationEntry == nil or notificationEntry.m_Instance == nil then
    return;
  end

	local maxWidth, summaryWidthPadding = GetMaxWidth(notificationEntry, pNotification);

  -- Check to make sure PipStack doesn't overflow the width
	if maxWidth < notificationEntry.m_Instance.PagePipStack:GetSizeX() then
		maxWidth = notificationEntry.m_Instance.PagePipStack:GetSizeX();
  end

  --  If the max width is larger than the word wrap width, use that for word wrap instead so text will fill
  --    the grid and not clump in the middle.
	if maxWidth > (notificationEntry.m_wrapWidth + summaryWidthPadding) then
		notificationEntry.m_wrapWidth = maxWidth - summaryWidthPadding;
    notificationEntry.m_Instance.Summary:SetWrapWidth(notificationEntry.m_wrapWidth);
  end

	notificationEntry.m_maxWidth = maxWidth;
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
    notificationEntry.m_Instance.Summary:SetWrapWidth(m_screenX);

    widthSummary = notificationEntry.m_Instance.Summary:GetSizeX();

    if widthSummary > MAX_WIDTH_INSTANCE then
      notificationEntry.m_wrapWidth = widthSummary / 1.7; -- Don't quite halve it so it doesn't wrap last word onto third line.
      notificationEntry.m_Instance.Summary:SetWrapWidth(notificationEntry.m_wrapWidth);
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

	local notificationPipIM:table = notificationEntry.m_Instance.m_PipInstanceManager;
	if notificationPipIM then
		notificationPipIM:ResetInstances();
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

	-- TODO: Remove this line and make sure Stack padding only gets applied on the X / Y depending on whether the stack grows Left / Right or Up / Down
	notificationEntry.m_Instance.TitleInfo:SetOffsetY( (count < 2) and TITLE_OFFSET_NO_COUNT or TITLE_OFFSET_DEFAULT);

  if count > 1 then
    notificationEntry.m_Instance.Count:SetText( tostring(count) );
    notificationEntry.m_Instance.DismissStackButton:RegisterCallback( Mouse.eRClick,    function() TryDismissNotificationStack(playerID, notificationID); end );
    notificationEntry.m_Instance.TitleCount:SetText( tostring(count) );
    notificationEntry.m_Instance.TitleStack:ReprocessAnchoring();

    notificationEntry.m_Instance.LeftArrow:RegisterCallback( Mouse.eLClick,   function() notificationEntry.m_kHandlers.OnPreviousSelect(pNotification); end );
    notificationEntry.m_Instance.RightArrow:RegisterCallback( Mouse.eLClick,  function() notificationEntry.m_kHandlers.OnNextSelect(pNotification); end );

		local maxWidth, _ = GetMaxWidth(notificationEntry, pNotification);
		local pipStackWidth = count * SIZE_PIP;

		if pipStackWidth < maxWidth then
			if not notificationPipIM then
				notificationPipIM = InstanceManager:new("PipInstance", "Pip", notificationEntry.m_Instance.PagePipStack);
				notificationEntry.m_Instance.m_PipInstanceManager = notificationPipIM;
			end
    for i=1,count,1 do
				local pipInstance:table = notificationPipIM:GetInstance();
				pipInstance.Pip:SetColor( i == notificationEntry.m_Index and COLOR_PIP_CURRENT or COLOR_PIP_OTHER );
			end
			notificationEntry.m_Instance.PagePipStack:CalculateSize();
			notificationEntry.m_Instance.PagePipStack:SetHide(false);
			notificationEntry.m_Instance.Pages:SetHide(true);
		else
			notificationEntry.m_Instance.Pages:SetText(notificationEntry.m_Index .. "/" .. count);
			notificationEntry.m_Instance.PagePipStack:SetHide(true);
			notificationEntry.m_Instance.Pages:SetHide(false);
    end

  else
    notificationEntry.m_Instance.LeftArrow:ClearCallback( Mouse.eLClick );
    notificationEntry.m_Instance.RightArrow:ClearCallback( Mouse.eLClick );
  end

  -- Set text again now that calculations are done, text must always match the current index!!
  SetNotificationText(notificationEntry, NotificationManager.Find(playerID, notificationEntry.m_IDs[ notificationEntry.m_Index ]));
	RealizeMaxWidth(notificationEntry, pNotification);
	RealizeNotificationSize(playerID, notificationID);
end

-- ===========================================================================
--  Applies collapsing logic onto an instance.
-- ===========================================================================
function ApplyCollapseLogic( pInstance:table )
  if not pInstance.NotificationSlide:IsReversing() then
    pInstance.NotificationSlide:Reverse();
  end
	pInstance.MouseOutArea:SetHide(true);
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
--	Default handler for a user request to try and manually activate a notification.
-- ===========================================================================
function OnDefaultTryActivateNotification( notificationEntry : NotificationType )
	if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
		local pNotification :table = GetActiveNotificationFromEntry(notificationEntry);
		if (pNotification ~= nil) then
			pNotification:Activate(true);	-- Passing true, signals that this is the user trying to do the activation.
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
		notificationEntry.m_Instance.IconBG:SetHide(not isValidForPhase);
		notificationEntry.m_Instance.IconBGInvalidPhase:SetHide(isValidForPhase);
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
		TryActivate		= OnDefaultTryActivateNotification,
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
-- City has ranged attack available.
-- =======================================================================================
function OnCityRangeAttack( notificationEntry : NotificationType )
	if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
		local pPlayer = Players[notificationEntry.m_PlayerID];
		if pPlayer ~= nil then
			local attackCity = pPlayer:GetCities():GetFirstRangedAttackCity();
			if(attackCity ~= nil) then
				LuaEvents.CQUI_Strike_Enter();
        LuaEvents.CQUI_CityRangeStrike(Game.GetLocalPlayer(), attackCity:GetID());
			else
				error( "Unable to find selectable attack city while in OnCityRangeAttack()" );
			end
		end
	end
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
	-- All the activation is handled by the C++ side
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
-- Tech Boost Handlers
-- =======================================================================================
function OnTechBoostActivateNotification( notificationEntry : NotificationType, notificationID : number )
	if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
		local pNotification :table = GetActiveNotificationFromEntry(notificationEntry, notificationID);
		if pNotification ~= nil then
			local techIndex = pNotification:GetValue("TechIndex");
			local techProgress = pNotification:GetValue("TechProgress");
			local techSource = pNotification:GetValue("TechSource"); 
			if(techIndex ~= nil and techProgress ~= nil and techSource ~= nil) then
				LuaEvents.NotificationPanel_ShowTechBoost(notificationEntry.m_PlayerID, techIndex, techProgress, techSource);
			end
    end
  end
end

-- =======================================================================================
-- Civic Boost Handlers
-- =======================================================================================
function OnCivicBoostActivateNotification( notificationEntry : NotificationType, notificationID : number )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
    local pNotification :table = GetActiveNotificationFromEntry(notificationEntry, notificationID);
        if pNotification ~= nil then
			local civicIndex = pNotification:GetValue("CivicIndex");
			local civicProgress = pNotification:GetValue("CivicProgress");
			local civicSource = pNotification:GetValue("CivicSource"); 
			if(civicIndex ~= nil and civicProgress ~= nil and civicSource ~= nil) then
				LuaEvents.NotificationPanel_ShowCivicBoost(notificationEntry.m_PlayerID, civicIndex, civicProgress, civicSource);
			end
        end
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
	notificationEntry.m_Instance.m_MouseIn = false;	-- Manually track since 2 different, overlapping objects are tracking if a pointer is in/out

  if notificationEntry.m_Instance ~= nil then
		if (notificationEntry.m_Instance.MouseInArea ~= nil) then
			notificationEntry.m_Instance.MouseInArea:SetVoid1( playerID );
			notificationEntry.m_Instance.MouseInArea:SetVoid2( notificationID );

			notificationEntry.m_Instance.MouseInArea:RegisterCallback( Mouse.eLClick, kHandlers.TryActivate );
			notificationEntry.m_Instance.MouseInArea:RegisterCallback( Mouse.eRClick, function() kHandlers.Dismiss(playerID, 1000000 + notificationID); end );
			notificationEntry.m_Instance.MouseInArea:RegisterMouseEnterCallback( function() OnMouseEnterNotification( notificationEntry.m_Instance ); end );
      notificationEntry.m_Instance.MouseOutArea:RegisterMouseExitCallback( function()  OnMouseExitNotification( notificationEntry.m_Instance ); end );

      notificationEntry.m_isAuto = false;

			notificationEntry.m_Instance.IconBG:SetHide(false);
			notificationEntry.m_Instance.IconBGInvalidPhase:SetHide(true);

      -- Upon creation, animation will automatically reverse and play out after showing.
      local pAnimControl:table = notificationEntry.m_Instance.NotificationSlide;
      pAnimControl:RegisterEndCallback(
        function()
          pAnimControl:ClearEndCallback();
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
	  if pNotification:IsVisibleInUI() then
      --print("    OnNotificationAdded():",notificationID, "for type "..tostring(pNotification:GetMessage()) ); --debug
      local handler = GetHandler( pNotification:GetType() );
      handler.Add(pNotification);
      if handler.AddSound ~= nil and handler.AddSound ~= "" then
                if m_isLoadComplete then
                    UI.PlaySound(handler.AddSound);
                end
      end
      ProcessStackSizes();
				RealizeNotificationSize(playerID, notificationID);
			end
    else
      -- Sanity check
      UI.DataError("Notification added Event but not found in manager. PlayerID - " .. tostring(playerID) .. " Notification ID - " .. tostring(notificationID));
    end

    if notificationID	== 577 then                   -- CQUI: Notification when a City lost tile to a Culture Bomb (Index == 577)
      LuaEvents.CQUI_CityLostTileToCultureBomb();
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
		RealizeNotificationSize(playerID, notificationID);
	end
end

-- ===========================================================================
--	ENGINE Event
--	A notification was activated.  This asks for a specific notification ID
--  in a notification entry. i.e. might not be the 'active' one.
-- ===========================================================================
function OnNotificationActivated( playerID:number, notificationID:number, activatedByUser:boolean )
	if (playerID == Game.GetLocalPlayer()) then -- one of the ones we track?

		local notificationEntry:NotificationType = GetNotificationEntry( playerID, notificationID );
		if notificationEntry ~= nil then		
			local handler = notificationEntry.m_kHandlers;
			handler.Activate( notificationEntry, notificationID, activatedByUser );
		end
		-- ProcessStackSizes();
		RealizeNotificationSize(playerID, notificationID);
  end
end

-- ===========================================================================
--  ENGINE Event
--  All notifications are about to be refreshed
-- ===========================================================================
function OnNotificationRefreshRequested()
  ClearNotifications();
  Controls.ScrollStack:DestroyAllChildren();
  m_genericItemIM:DestroyInstances();
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
	if playerTable ~= nil then
		for typeName, notification in pairs( playerTable ) do
			RealizeNotificationSize(playerID, notification.m_IDs[notification.m_Index]);
    end
  end
end

-- ===========================================================================
--  Handle a resize
-- ===========================================================================
function Resize()
  m_screenX, m_screenY  = UIManager:GetScreenSizeVal();
  Controls.RailOffsetAnim:ReprocessAnchoring();
  Controls.RailAnim:ReprocessAnchoring();

	-- force an update
	m_lastStackSize = 0;

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
					ReleaseNotificationEntry( playerID, id, true );
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
  -- m_lastStackDiff = 0;
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
  
  Controls.ScrollStack:RegisterSizeChanged( OnStackSizeChanged );

  Events.NotificationAdded.Add(       OnNotificationAdded );
  Events.NotificationDismissed.Add(     OnNotificationDismissed );
  Events.NotificationRefreshRequested.Add(  OnNotificationRefreshRequested );
	Events.NotificationActivated.Add(			OnNotificationActivated );

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
