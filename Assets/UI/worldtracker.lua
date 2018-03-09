include("InstanceManager");
include("TechAndCivicSupport");
include("SupportFunctions");
include("GameCapabilities");

g_TrackedItems = {}; -- Populated by WorldTrackerItems_* scripts;
g_TrackedInstances = {};

include("WorldTrackerItem_", true);

-- Include self contained additional tabs
g_ExtraIconData = {};
include("CivicsTreeIconLoader_", true);

--  Hotloading note: The World Tracker button check now positions based on how many hooks are showing.
--  You'll need to save "LaunchBar" to see the tracker button appear.
-- ===========================================================================
--  CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID:string = "WorldTracker"; -- Must be unique (usually the same as the file name)
local MAX_BEFORE_TRUNC_TRACKER      :number = 180;
local MAX_BEFORE_TRUNC_CHECK      :number = 160;
local MAX_BEFORE_TRUNC_TITLE      :number = 225;
local LAUNCH_BAR_PADDING        :number = 50;
local WORLD_TRACKER_PANEL_WIDTH      :number = 300;
local STARTING_TRACKER_OPTIONS_OFFSET  :number = 75;
local LAUNCH_BAR_EXTRA_OFFSET     :number = 361;

-- ===========================================================================
--  VARIABLES
-- ===========================================================================

m_hideAll          = false;
m_prevHideAll      = false;
m_hideChat        = false;
m_hideCivics      = false;
m_hideResearch    = false;
local m_dropdownExpanded    :boolean = false;
local m_unreadChatMsgs      :number  = 0;    -- number of chat messages unseen due to the chat panel being hidden.

local m_researchInstance    :table   = {};    -- Single instance wired up for the currently being researched tech
local m_civicsInstance      :table   = {};    -- Single instance wired up for the currently being researched civic
local m_CachedModifiers      :table   = {};

local m_currentResearchID    :number = -1;
local m_lastResearchCompletedID  :number = -1;
local m_currentCivicID      :number = -1;
local m_lastCivicCompletedID  :number = -1;
local m_TrackerAlwaysVisuallyCollapsed:boolean = false;  -- Once the launch bar extends past the width of the world tracker, we always show the collapsed version of the backing for the tracker element

local m_needsRefresh        :boolean = false;

function RealizeEmptyMessage()
  if(m_hideChat and m_hideCivics and m_hideResearch) then
    -- Controls.EmptyPanel:SetHide(false);
  else
    -- Controls.EmptyPanel:SetHide(true);
  end
end

-- ===========================================================================
function ToggleDropdown()
  if m_dropdownExpanded then
    m_dropdownExpanded = false;
    Controls.DropdownAnim:Reverse();
    Controls.DropdownAnim:Play();
    UI.PlaySound("Tech_Tray_Slide_Closed");
  else
    UI.PlaySound("Tech_Tray_Slide_Open");
    m_dropdownExpanded = true;
    Controls.DropdownAnim:SetToBeginning();
    Controls.DropdownAnim:Play();
  end
end

-- ===========================================================================
function ToggleAll(hideAll:boolean)

  -- Do nothing if value didn't change
  if m_hideAll == hideAll then return; end

  m_hideAll = hideAll;

  if(not hideAll) then
    Controls.PanelStack:SetHide(false);
    UI.PlaySound("Tech_Tray_Slide_Open");
  end

  -- Controls.ToggleAllButton:SetCheck(not m_hideAll);

  if ( not m_TrackerAlwaysVisuallyCollapsed) then
    Controls.TrackerHeading:SetHide(hideAll);
    Controls.TrackerHeadingCollapsed:SetHide(not hideAll);
  else
    Controls.TrackerHeading:SetHide(true);
    Controls.TrackerHeadingCollapsed:SetHide(false);
  end

  if( hideAll ) then
    UI.PlaySound("Tech_Tray_Slide_Closed");
    if( m_dropdownExpanded ) then
      Controls.DropdownAnim:SetToBeginning();
      m_dropdownExpanded = false;
    end
  end

  Controls.WorldTrackerAlpha:Reverse();
  Controls.WorldTrackerSlide:Reverse();
  CheckUnreadChatMessageCount();

  -- CQUI --
  if(not hideAll) then
    LuaEvents.WorldTracker_ToggleResearchPanel(m_hideResearch);
    LuaEvents.WorldTracker_ToggleCivicPanel(m_hideCivics);
  else
    LuaEvents.WorldTracker_ToggleResearchPanel(true);
    LuaEvents.WorldTracker_ToggleCivicPanel(true);
  end
  -- CQUI --
end

function OnWorldTrackerAnimationFinished()
  if(m_hideAll) then
    Controls.PanelStack:SetHide(true);
  end
end

-- When the launch bar is resized, make sure that we  adjust the world tracker button position/size to accommodate it
function OnLaunchBarResized( buttonStackSize: number)
  Controls.TrackerHeading:SetSizeX(buttonStackSize + LAUNCH_BAR_PADDING);
  Controls.TrackerHeadingCollapsed:SetSizeX(buttonStackSize + LAUNCH_BAR_PADDING);
  if( buttonStackSize > WORLD_TRACKER_PANEL_WIDTH - LAUNCH_BAR_PADDING) then
    m_TrackerAlwaysVisuallyCollapsed = true;
    Controls.TrackerHeading:SetHide(true);
    Controls.TrackerHeadingCollapsed:SetHide(false);
  else
    m_TrackerAlwaysVisuallyCollapsed = false;
    Controls.TrackerHeading:SetHide(m_hideAll);
    Controls.TrackerHeadingCollapsed:SetHide(not m_hideAll);
  end
  -- Controls.ToggleAllButton:SetOffsetX(buttonStackSize - 7);
end
-- ===========================================================================
function RealizeStack()
  Controls.PanelStack:CalculateSize();
  Controls.PanelStack:ReprocessAnchoring();
  if(m_hideAll) then ToggleAll(true); end
end

-- ===========================================================================
function UpdateResearchPanel( isHideResearch:boolean )

  if not HasCapability("CAPABILITY_TECH_CHOOSER") then
    isHideResearch = true;
    Controls.ResearchCheck:SetHide(true);
  end

  if isHideResearch ~= nil then
    m_hideResearch = isHideResearch;
  end

  m_researchInstance.MainPanel:SetHide( m_hideResearch );
  Controls.ResearchCheck:SetCheck( not m_hideResearch );
  LuaEvents.WorldTracker_ToggleResearchPanel( m_hideResearch or m_hideAll );
  RealizeEmptyMessage();
  RealizeStack();

  -- Set the technology to show (or -1 if none)...
  local iTech      :number = m_currentResearchID;
  if m_currentResearchID == -1 then
    iTech = m_lastResearchCompletedID;
  end
  local ePlayer    :number = Game.GetLocalPlayer();
  local pPlayer    :table  = Players[ePlayer];
  local pPlayerTechs  :table  = pPlayer:GetTechs();
  local kTech      :table  = (iTech ~= -1) and GameInfo.Technologies[ iTech ] or nil;
  local kResearchData :table = GetResearchData( ePlayer, pPlayerTechs, kTech );
  if iTech ~= -1 then
    if m_currentResearchID == iTech then
      kResearchData.IsCurrent = true;
    elseif m_lastResearchCompletedID == iTech then
      kResearchData.IsLastCompleted = true;
    end
  end

  RealizeCurrentResearch( ePlayer, kResearchData, m_researchInstance );

  -- No tech started (or finished)
  if kResearchData == nil then
    m_researchInstance.TitleButton:SetHide( false );
    TruncateStringWithTooltip(m_researchInstance.TitleButton, MAX_BEFORE_TRUNC_TITLE, Locale.ToUpper(Locale.Lookup("LOC_WORLD_TRACKER_CHOOSE_RESEARCH")) );
    m_researchInstance.MainPanel:LocalizeAndSetToolTip(nil); --ARISTOS: to avoid showing last tech tooltip when no tech chosen yet
  else
    -- ARISTOS: to show full tooltip in research panel
    m_researchInstance.MainPanel:LocalizeAndSetToolTip(kResearchData.ToolTip);
  end
end

-- ===========================================================================
function UpdateCivicsPanel(hideCivics:boolean)

  if not HasCapability("CAPABILITY_CIVICS_CHOOSER") then
    hideCivics = true;
    Controls.CivicsCheck:SetHide(true);
  end

  if hideCivics ~= nil then
    m_hideCivics = hideCivics;
  end

  m_civicsInstance.MainPanel:SetHide(m_hideCivics);
  Controls.CivicsCheck:SetCheck(not m_hideCivics);
  LuaEvents.WorldTracker_ToggleCivicPanel(m_hideCivics or m_hideAll);
  RealizeEmptyMessage();
  RealizeStack();

  -- Set the civic to show (or -1 if none)...
  local iCivic :number = m_currentCivicID;
  if iCivic == -1 then
    iCivic = m_lastCivicCompletedID;
  end
  local ePlayer    :number = Game.GetLocalPlayer();
  local pPlayer    :table  = Players[ePlayer];
  local pPlayerCulture:table  = pPlayer:GetCulture();
  local kCivic    :table  = (iCivic ~= -1) and GameInfo.Civics[ iCivic ] or nil;
  local kCivicData :table = GetCivicData( ePlayer, pPlayerCulture, kCivic );
  if iCivic ~= -1 then
    if m_currentCivicID == iCivic then
      kCivicData.IsCurrent = true;
    elseif m_lastCivicCompletedID == iCivic then
      kCivicData.IsLastCompleted = true;
    end
  end

  for _,iconData in pairs(g_ExtraIconData) do
    iconData:Reset();
  end
  RealizeCurrentCivic( ePlayer, kCivicData, m_civicsInstance, m_CachedModifiers );

  -- No civic started (or finished)
  if kCivicData == nil then
    m_civicsInstance.TitleButton:SetHide( false );
    TruncateStringWithTooltip(m_civicsInstance.TitleButton, MAX_BEFORE_TRUNC_TITLE, Locale.ToUpper(Locale.Lookup("LOC_WORLD_TRACKER_CHOOSE_CIVIC")) );
    m_civicsInstance.MainPanel:LocalizeAndSetToolTip(nil); --ARISTOS: to avoid showing last civic tooltip when no civic chosen yet
  else
    --TruncateStringWithTooltip(m_civicsInstance.TitleButton, MAX_BEFORE_TRUNC_TITLE, m_civicsInstance.TitleButton:GetText() );
    -- ARISTOS: to show full tooltip in civics panel
    m_civicsInstance.MainPanel:LocalizeAndSetToolTip(kCivicData.ToolTip);
  end
end

-- ===========================================================================
function UpdateChatPanel(hideChat:boolean)
  m_hideChat = hideChat;
  Controls.ChatPanel:SetHide(m_hideChat);
  Controls.ChatCheck:SetCheck(not m_hideChat);
  RealizeEmptyMessage();
  RealizeStack();

  CheckUnreadChatMessageCount();
end

-- ===========================================================================
function CheckUnreadChatMessageCount()
  -- Unhiding the chat panel resets the unread chat message count.
  if(not hideAll and not m_hideChat) then
    m_unreadChatMsgs = 0;
    UpdateUnreadChatMsgs();
    LuaEvents.WorldTracker_OnChatShown();
  end
end

-- ===========================================================================
function UpdateUnreadChatMsgs()
  if(m_unreadChatMsgs > 0) then
    Controls.ChatCheck:GetTextButton():SetText(Locale.Lookup("LOC_HIDE_CHAT_PANEL_UNREAD_MESSAGES", m_unreadChatMsgs));
  else
    Controls.ChatCheck:GetTextButton():SetText(Locale.Lookup("LOC_HIDE_CHAT_PANEL"));
  end
  Controls.ChatCheck:ReprocessAnchoring();
end

-- ===========================================================================
--  Obtains full refresh and views most current research and civic IDs.
-- ===========================================================================
function Refresh()
  local localPlayer :number = Game.GetLocalPlayer();
  if localPlayer < 0 then
    ToggleAll(true);
    return;
  else
    -- Fix for the Checkbox bug by ARISTOS
    ToggleAll(m_hideAll);
  end

  local pPlayerTechs :table = Players[localPlayer]:GetTechs();
  m_currentResearchID = pPlayerTechs:GetResearchingTech();

  -- Only reset last completed tech once a new tech has been selected
  if m_currentResearchID >= 0 then
    m_lastResearchCompletedID = -1;
  end

  UpdateResearchPanel();

  local pPlayerCulture:table = Players[localPlayer]:GetCulture();
  m_currentCivicID = pPlayerCulture:GetProgressingCivic();

  -- Only reset last completed civic once a new civic has been selected
  if m_currentCivicID >= 0 then
    m_lastCivicCompletedID = -1;
  end

  UpdateCivicsPanel();

  -- Hide world tracker by default if there are no tracker options enabled
  if( Controls.ChatCheck:IsHidden() and
    Controls.CivicsCheck:IsHidden() and
    Controls.ResearchCheck:IsHidden() ) then
    ToggleAll(true);
  end
end

-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnLocalPlayerTurnBegin()
  local localPlayer = Game.GetLocalPlayer();
  if localPlayer ~= -1 then
    m_needsRefresh = true;
  end
end

-- ===========================================================================
function OnCityInitialized( playerID:number, cityID:number )
  if playerID == Game.GetLocalPlayer() then
    m_needsRefresh = true;
  end
end

-- ===========================================================================
function OnBuildingChanged( plotX:number, plotY:number, buildingIndex:number, playerID:number, iPercentComplete:number )
  if playerID == Game.GetLocalPlayer() then
    m_needsRefresh = true; -- Buildings can change culture/science yield which can effect "turns to complete" values
  end
end

-- ===========================================================================
function FlushChanges()
  if m_needsRefresh then
    Refresh();
    m_needsRefresh = false;
  end
end

-- ===========================================================================
--  Game Engine EVENT
--  A civic item has changed, this may not be the current civic item
--  but an item deeper in the tree that was just boosted by a player action.
-- ===========================================================================
function OnCivicChanged( ePlayer:number, eCivic:number )
  local localPlayer = Game.GetLocalPlayer();
  ResetOverflowArrow( m_civicsInstance );
  if localPlayer ~= -1 and localPlayer == ePlayer then
    local pPlayerCulture:table = Players[localPlayer]:GetCulture();
    m_currentCivicID = pPlayerCulture:GetProgressingCivic();
    m_lastCivicCompletedID = -1;
    if eCivic == m_currentCivicID then
      UpdateCivicsPanel();
    end
  end
end

-- ===========================================================================
function OnCivicCompleted( ePlayer:number, eCivic:number )
  local localPlayer = Game.GetLocalPlayer();
  if localPlayer ~= -1 and localPlayer == ePlayer then
    m_currentCivicID = -1;
    m_lastCivicCompletedID = eCivic;
    UpdateCivicsPanel();
  end
end

-- ===========================================================================
function OnCultureYieldChanged( ePlayer:number )
  local localPlayer = Game.GetLocalPlayer();
  if localPlayer ~= -1 and localPlayer == ePlayer then
    UpdateCivicsPanel();
  end
end

-- ===========================================================================
--  Game Engine EVENT
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
--  Game Engine EVENT
--  A research item has changed, this may not be the current researched item
--  but an item deeper in the tree that was just boosted by a player action.
-- ===========================================================================
function OnResearchChanged( ePlayer:number, eTech:number )
  ResetOverflowArrow( m_researchInstance );

  if ShouldUpdateResearchPanel(ePlayer, eTech) then
    UpdateResearchPanel();
  end
end

-- ===========================================================================
--	This function was separated so behavior can be modified in mods/expasions
-- ===========================================================================
function ShouldUpdateResearchPanel(ePlayer:number, eTech:number)
  local localPlayer = Game.GetLocalPlayer();

  if localPlayer ~= -1 and localPlayer == ePlayer then
    local pPlayerTechs :table = Players[localPlayer]:GetTechs();
    m_currentResearchID = pPlayerTechs:GetResearchingTech();

    -- Only reset last completed tech once a new tech has been selected
    if m_currentResearchID >= 0 then
      m_lastResearchCompletedID = -1;
    end

    if eTech == m_currentResearchID then
      return true;
    end
  end
  return false;
end

function OnResearchCompleted( ePlayer:number, eTech:number )
  if (ePlayer == Game.GetLocalPlayer()) then
    m_currentResearchID = -1;
    m_lastResearchCompletedID = eTech;
    UpdateResearchPanel();
  end
end

function OnResearchYieldChanged( ePlayer:number )
  local localPlayer = Game.GetLocalPlayer();
  if localPlayer ~= -1 and localPlayer == ePlayer then
    UpdateResearchPanel();
  end
end


-- ===========================================================================
function OnMultiplayerChat( fromPlayer, toPlayer, text, eTargetType )
  -- If the chat panels are hidden, indicate there are unread messages waiting on the world tracker panel toggler.
  if(m_hideAll or m_hideChat) then
    m_unreadChatMsgs = m_unreadChatMsgs + 1;
    UpdateUnreadChatMsgs();
  end
end

-- ===========================================================================
--  HOT-RELOADING EVENTS
-- ===========================================================================
function OnInit(isReload:boolean)
  if isReload then
    LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
  else
    Refresh();  -- Standard refresh.
  end
end
function OnShutdown()
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_currentResearchID",    m_currentResearchID);
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_lastResearchCompletedID",  m_lastResearchCompletedID);
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_currentCivicID",      m_currentCivicID);
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_lastCivicCompletedID",    m_lastCivicCompletedID);
end
function OnGameDebugReturn(context:string, contextTable:table)
  if context == RELOAD_CACHE_ID then
    m_currentResearchID      = contextTable["m_currentResearchID"];
    m_lastResearchCompletedID  = contextTable["m_lastResearchCompletedID"];
    m_currentCivicID      = contextTable["m_currentCivicID"];
    m_lastCivicCompletedID    = contextTable["m_lastCivicCompletedID"];

    if m_currentResearchID == nil    then m_currentResearchID = -1; end
    if m_lastResearchCompletedID == nil then m_lastResearchCompletedID = -1; end
    if m_currentCivicID == nil      then m_currentCivicID = -1; end
    if m_lastCivicCompletedID == nil  then m_lastCivicCompletedID = -1; end

    -- Don't call refresh, use cached data from last hotload.
    UpdateResearchPanel();
    UpdateCivicsPanel();
  end
end

-- ===========================================================================
function OnTutorialGoalsShowing()
  RealizeStack();
end

-- ===========================================================================
function OnTutorialGoalsHiding()
  RealizeStack();
end

-- ===========================================================================
function Tutorial_ShowFullTracker()
  Controls.ToggleAllButton:SetHide(true);
  Controls.ToggleDropdownButton:SetHide(true);
  UpdateCivicsPanel(false);
  UpdateResearchPanel(false);
  ToggleAll(false);
end

-- ===========================================================================
function Tutorial_ShowTrackerOptions()
  Controls.ToggleAllButton:SetHide(false);
  Controls.ToggleDropdownButton:SetHide(false);
end

-- ===========================================================================
function OnLoadScreenClose()
  local callback = function()
    ToggleAll(not m_hideAll)
  end

  local buttonInfo = {
    Text = Locale.Lookup("LOC_WORLDTRACKER_HIDE_TEXT");
    Callback = callback;
    Tooltip = Locale.Lookup("LOC_WORLDTRACKER_HIDE_TEXT");
  }

  LuaEvents.LaunchBar_AddExtra("ToggleWorldTracker", buttonInfo)
end

-- ===========================================================================
function Initialize()

  if not GameCapabilities.HasCapability("CAPABILITY_WORLD_TRACKER") then
    ContextPtr:SetHide(true);
    return;
  end

  m_CachedModifiers = TechAndCivicSupport_BuildCivicModifierCache();

  -- Create semi-dynamic instances; hack: change parent back to self for ordering:
  ContextPtr:BuildInstanceForControl( "ResearchInstance", m_researchInstance, Controls.PanelStack );
  ContextPtr:BuildInstanceForControl( "CivicInstance",  m_civicsInstance,  Controls.PanelStack );

  for i,v in ipairs(g_TrackedItems) do
    local instance = {};
    ContextPtr:BuildInstanceForControl( v.InstanceType, instance, Controls.PanelStack );
    if(instance.IconButton) then
      instance.IconButton:RegisterCallback(Mouse.eLClick, function() v.SelectFunc() end);
      table.insert(g_TrackedInstances, instance);
    end

    if(instance.TitleButton) then
      instance.TitleButton:LocalizeAndSetText(v.Name);
    end
  end


  Controls.ChatPanel:ChangeParent( Controls.PanelStack );
  Controls.TutorialGoals:ChangeParent( Controls.PanelStack );

  -- Handle any text overflows with truncation and tooltip
  local fullString :string = Controls.WorldTracker:GetText();
  Controls.DropdownScroll:SetOffsetY(Controls.WorldTrackerHeader:GetSizeY() + STARTING_TRACKER_OPTIONS_OFFSET);
  Controls.ChatCheck:ReprocessAnchoring();

  -- Hot-reload events
  ContextPtr:SetInitHandler(OnInit);
  ContextPtr:SetShutdown(OnShutdown);
  LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);

  Controls.ChatCheck:SetCheck(true);
  Controls.CivicsCheck:SetCheck(true);
  Controls.ResearchCheck:SetCheck(true);
  -- Controls.ToggleAllButton:SetCheck(true);

  Controls.ChatCheck:RegisterCheckHandler(            function() UpdateChatPanel(not m_hideChat); end);
  Controls.CivicsCheck:RegisterCheckHandler(            function() UpdateCivicsPanel(not m_hideCivics); end);
  Controls.ResearchCheck:RegisterCheckHandler(          function() UpdateResearchPanel(not m_hideResearch); end);
  m_researchInstance.IconButton:RegisterCallback(  Mouse.eLClick,  function() LuaEvents.WorldTracker_OpenChooseResearch(); end);
  m_civicsInstance.IconButton:RegisterCallback(  Mouse.eLClick,  function() LuaEvents.WorldTracker_OpenChooseCivic(); end);
  -- Controls.ToggleAllButton:RegisterCheckHandler(          function() ToggleAll(not Controls.ToggleAllButton:IsChecked()) end);
  Controls.ToggleDropdownButton:RegisterCallback(  Mouse.eLClick, ToggleDropdown);
  Controls.WorldTrackerAlpha:RegisterEndCallback( OnWorldTrackerAnimationFinished );

  Events.CityInitialized.Add(OnCityInitialized);
  Events.BuildingChanged.Add(OnBuildingChanged);
  Events.CivicChanged.Add(OnCivicChanged);
  Events.CivicCompleted.Add(OnCivicCompleted);
  Events.CultureYieldChanged.Add(OnCultureYieldChanged);
  Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
  Events.LocalPlayerTurnBegin.Add(OnLocalPlayerTurnBegin);
  Events.MultiplayerChat.Add( OnMultiplayerChat );
  Events.ResearchChanged.Add(OnResearchChanged);
  Events.ResearchCompleted.Add(OnResearchCompleted);
  Events.ResearchYieldChanged.Add(OnResearchYieldChanged);
  Events.GameCoreEventPublishComplete.Add(FlushChanges); --This event is raised directly after a series of gamecore events.
  LuaEvents.LaunchBar_Resize.Add(OnLaunchBarResized);

  LuaEvents.CivicChooser_ForceHideWorldTracker.Add(  function() ContextPtr:SetHide(true);  end);
  LuaEvents.CivicChooser_RestoreWorldTracker.Add(    function() ContextPtr:SetHide(false); end);
  LuaEvents.ResearchChooser_ForceHideWorldTracker.Add(function() ContextPtr:SetHide(true);  end);
  LuaEvents.ResearchChooser_RestoreWorldTracker.Add(  function() ContextPtr:SetHide(false); end);
  LuaEvents.Tutorial_ForceHideWorldTracker.Add(    function() ContextPtr:SetHide(true);  end);
  LuaEvents.Tutorial_RestoreWorldTracker.Add(      Tutorial_ShowFullTracker);
  LuaEvents.Tutorial_EndTutorialRestrictions.Add(    Tutorial_ShowTrackerOptions);
  LuaEvents.TutorialGoals_Showing.Add(        OnTutorialGoalsShowing );
  LuaEvents.TutorialGoals_Hiding.Add(          OnTutorialGoalsHiding );

    -- InitChatPanel
  if(GameConfiguration.IsNetworkMultiplayer() and UI.HasFeature("Chat")) then
    UpdateChatPanel(false);
  else
    UpdateChatPanel(true);
    Controls.ChatCheck:SetHide(true);
  end

  -- Initialize Unread Chat Messages Count
  UpdateUnreadChatMsgs();
end
Initialize();


--???TRON debug:
--[[
hstructure GoalItem
  Id        : string;    -- Id of item
  Text      : string;    -- Text to always display
  Tooltip      : string;    -- (optional) tooltip text
  IsCompleted    : boolean;    -- Is the goal completed?
  ItemId      : string;    -- For debugging, the id of the item that is setting the goal
  CompletedOnTurn  : number;    -- Which turn # the tutorial goal was completed on (required for auto-remove)
end
local goal1:GoalItem = hmake GoalItem {};
goal1.Id = "foo";
goal1.Text = "Foo!";
OnTutorialGoalsShowing();
LuaEvents.TutorialUIRoot_GoalAdd( goal1 );
LuaEvents.TutorialUIRoot_OpenGoals();
Controls.TutorialGoals:ReprocessAnchoring();
Controls.PanelStack:CalculateSize();
]]
