-- ===========================================================================
--
--	CivicsChooser
--	Slideout panel containing available civic options.
--
-- ===========================================================================
-- Include self contained additional tabs
g_ExtraIconData = {};
include("CivicsTreeIconLoader_", true);

include("ToolTipHelper")
include("TechAndCivicSupport"); -- Already includes Civ6Common and InstanceManager
include("AnimSidePanelSupport");
include("SupportFunctions");
include("Civ6Common");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID			:string = "CivicChooser";	-- Must be unique (usually the same as the file name)
local MAX_BEFORE_TRUNC_BOOST_MSG:number = 210;					-- Size in which boost messages will be truncated and tooltipified
local SIZE_ICON_LARGE			:number = 38;
local SIZE_ICON_SMALL			:number = 38;


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_civicsIM		:table	= InstanceManager:new( "CivicListInstance", "TopContainer",	Controls.CivicStack );
local m_kSlideAnimator	:table; --AnimSidePanelSupport
local m_currentID		:number = -1;
local m_isExpanded		:boolean= false;
local m_lastCompletedID	:number = -1;
local m_needsRefresh	:boolean = false; --used to track whether a given series of events (terminated by GameCoreEventPublishComplete)
local m_CachedModifiers	:table = {};

--CQUI Members
local CQUI_AlwaysOpenTechTrees = false; --Ignores events calling for this to open when true
local CQUI_ShowTechCivicRecommendations = false;

-- ===========================================================================
--	METHODS
-- ===========================================================================


-- ===========================================================================
--	Determine the current data.
-- ===========================================================================
function GetData()
  local kData			:table  = {};
  local ePlayer		:number = Game.GetLocalPlayer();
  if (ePlayer >= 0) then
    local pPlayer		:table  = Players[ePlayer];
    local pPlayerCulture:table	= pPlayer:GetCulture();
    local pResearchQueue:table	= {};

    -- Get recommendations
    local civicRecommendations:table = {};
    local pGrandAI:table = pPlayer:GetGrandStrategicAI();
    if pGrandAI then
      civicRecommendations = pGrandAI:GetCivicsRecommendations();
    end

    pResearchQueue = pPlayerCulture:GetCivicQueue(pResearchQueue);

    -- Fill in the "other" (not-current) items
    for kCivic in GameInfo.Civics() do

      local iCivic	:number = kCivic.Index;
      if	iCivic == m_currentID or
        iCivic == m_lastCompletedID or
        (iCivic ~= m_currentID and pPlayerCulture:CanProgress(iCivic)) then

        local kCivicData :table = GetCivicData( ePlayer, pPlayerCulture, kCivic );
        kCivicData.IsCurrent		= (iCivic == m_currentID);
        kCivicData.IsLastCompleted	= (iCivic == m_lastCompletedID);
        kCivicData.ResearchQueuePosition = -1;
        for i, civicNum in pairs(pResearchQueue) do
          if civicNum == iCivic then
            kCivicData.ResearchQueuePosition = i;
          end
        end

        -- Determine if this civic is recommended
        kCivicData.IsRecommended = false;
        if civicRecommendations ~= nil then
          for i,recommendation in pairs(civicRecommendations) do
            if kCivicData.Hash == recommendation.CivicHash then
              kCivicData.IsRecommended = true;
              kCivicData.AdvisorType = kCivic.AdvisorType;
            end
          end
        end

        table.insert( kData, kCivicData );
      end
    end
  end
  return kData;
end


-- ===========================================================================
--	Populate the list of research options.
-- ===========================================================================
function View( playerID:number, kData:table )

  m_civicsIM:ResetInstances();

  for _,iconData in pairs(g_ExtraIconData) do
    iconData:Reset();
  end
  
  local kActive : table = GetActiveData(kData);
  
  if kActive == nil then
    RealizeCurrentCivic( nil );	-- No research done yet
  end

  table.sort(kData, function(a, b) return Locale.Compare(a.Name, b.Name) == -1; end);
  for i, data in ipairs(kData) do
    if data.IsCurrent or data.IsLastCompleted then
      RealizeCurrentCivic( playerID, data, nil, m_CachedModifiers );
      if (data.Repeatable) then
        AddAvailableCivic( playerID, data );
      end
    else
      AddAvailableCivic( playerID, data );
    end
  end
  
  RealizeSize();
end


-- ===========================================================================
--	Get the latest data and visualize.
-- ===========================================================================
function Refresh()
  local player:number = Game.GetLocalPlayer();
  if (player >= 0) then
    local kData :table	= GetData();
    View( player, kData );
  end
  m_needsRefresh = false;
end


-- ===========================================================================
--
-- ===========================================================================
function AddAvailableCivic( playerID:number, kData:table )
  local numUnlockables	:number;
  local isDisabled:boolean = (kData.TurnsLeft < 1);	-- No cities, turns will be -1

  -- Create main instance and the Instance Manager for any unlocks.
  local kItemInstance	:table = m_civicsIM:GetInstance();
  local unlockIM	:table = GetUnlockIM(kItemInstance);

  kItemInstance.TechName:SetText(Locale.ToUpper(kData.Name));
  kItemInstance.Top:LocalizeAndSetToolTip(kData.ToolTip);
  kItemInstance.Top:SetTag( UITutorialManager:GetHash(kData.CivicType) );	-- Mark for tutorial dynamic element

  RealizeMeterAndBoosts( kItemInstance, kData );
  RealizeIcon( kItemInstance.Icon, kData.CivicType, SIZE_ICON_SMALL );
  RealizeTurnsLeft( kItemInstance, kData );

  local callback:ifunction = nil;
  if not isDisabled then
    callback = function() ResetOverflowArrow( kItemInstance ); OnChooseCivic(kData.Hash); end;
  end
  
  -- Include extra icons in total unlocks
  local extraUnlocks:table = {};
  local hideDescriptionIcon:boolean = false;
  local cachedModifiers:table = m_CachedModifiers[kData.CivicType];
  if ( cachedModifiers ) then
    for _,tModifier in ipairs(cachedModifiers) do
      local tIconData :table = g_ExtraIconData[tModifier.ModifierType];
      if ( tIconData ) then
        hideDescriptionIcon = hideDescriptionIcon or tIconData.HideDescriptionIcon;
        table.insert(extraUnlocks, {IconData=tIconData, ModifierTable=tModifier});
      end  
  end
  end
  
  -- Handle overflow for unlock icons
  numUnlockables = PopulateUnlockablesForCivic( playerID, kData.ID, unlockIM, nil, callback, hideDescriptionIcon );
  
  -- Initialize extra icons
  for _,tUnlock in pairs(extraUnlocks) do
    tUnlock.IconData:Initialize(kItemInstance.UnlockStack, tUnlock.ModifierTable);
    numUnlockables = numUnlockables + 1;
  end
  
  if numUnlockables ~= nil then
    HandleOverflow(numUnlockables, kItemInstance, 5, 5);
  end

  if kData.ResearchQueuePosition ~= -1 then
    kItemInstance.QueueBadge:SetHide(false);
    kItemInstance.NodeNumber:SetHide(false);
    if(kData.ResearchQueuePosition < 10) then
      kItemInstance.NodeNumber:SetOffsetX(-2);
    else
      kItemInstance.NodeNumber:SetOffsetX(-5);
    end
    kItemInstance.NodeNumber:SetText(tostring(kData.ResearchQueuePosition));
  else
    kItemInstance.QueueBadge:SetHide(true);
    kItemInstance.NodeNumber:SetHide(true);
  end

  -- Set up callback that changes the current research
  kItemInstance.Top:RegisterCallback(Mouse.eLClick, function() ResetOverflowArrow( kItemInstance ); OnChooseCivic(kData.Hash); end);
  kItemInstance.Top:SetDisabled( isDisabled );

  -- Only wire up Civilopedia handlers if not in a on-rails tutorial
  if IsTutorialRunning()==false then
    kItemInstance.Top:RegisterCallback(Mouse.eRClick, function() LuaEvents.OpenCivilopedia(kData.CivicType); end);
  end

  -- Hide/Show Recommendation Icon
  -- CQUI : only if show tech civ enabled in settings
  if kData.IsRecommended and kData.AdvisorType ~= nil and CQUI_ShowTechCivicRecommendations then
    kItemInstance.RecommendedIcon:SetIcon(kData.AdvisorType);
    kItemInstance.RecommendedIcon:SetHide(false);
  else
    kItemInstance.RecommendedIcon:SetHide(true);
  end
end

-- ===========================================================================
function OnChooseCivic( civicHash:number )
  if civicHash == nil then
    UI.DataError("Attempt to choose a civic but a NIL hash!");
    return;
  end

  ResetOverflowArrow( Controls );

  if (Game.GetLocalPlayer() >= 0) then
    local tParameters :table = {};
    tParameters[PlayerOperations.PARAM_CIVIC_TYPE]	= civicHash;
    tParameters[PlayerOperations.PARAM_INSERT_MODE] = PlayerOperations.VALUE_EXCLUSIVE;
    UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.PROGRESS_CIVIC, tParameters);
    UI.PlaySound("Confirm_Civic");
  end

  if m_isExpanded then
    OnClosePanel();
  end
end

-- ===========================================================================
function RealizeSize()
  local _, screenY:number = UIManager:GetScreenSizeVal();
  Controls.ChooseCivicList:SetSizeY(screenY - Controls.ChooseCivicList:GetOffsetY() - 30);
  Controls.ChooseCivicList:CalculateInternalSize();

  Controls.CivicStack:CalculateSize();
  Controls.CivicStack:ReprocessAnchoring();

  if(Controls.ChooseCivicList:GetScrollBar():IsHidden()) then
    Controls.ChooseCivicList:SetOffsetX(10);
  else
    Controls.ChooseCivicList:SetOffsetX(20);
  end
end

-- ===========================================================================
function OnOpenPanel()
--CQUI: ignores command and opens the tech tree instead if AlwaysShowTechTrees is true
  if(CQUI_AlwaysOpenTechTrees) then
    LuaEvents.CivicsChooser_RaiseCivicsTree()
  else
    Refresh();
    LuaEvents.ResearchChooser_ForceHideWorldTracker();
    UI.PlaySound("Tech_Tray_Slide_Open");
    m_isExpanded = true;
    m_kSlideAnimator.Show();
  end
end

-- ===========================================================================
function OnClosePanel()
  m_kSlideAnimator.Hide();
end

-- ===========================================================================
--	Callback from Slide Animator
-- ===========================================================================
function OnSlideAnimatorClose()
  LuaEvents.ResearchChooser_RestoreWorldTracker();
    UI.PlaySound("Tech_Tray_Slide_Closed");
  m_isExpanded = false;
end

-- ===========================================================================
function OnUpdateUI(type)
  m_kSlideAnimator.OnUpdateUI();
  if type == SystemUpdateUI.ScreenResize then
    RealizeSize();
  end
end


-- ===========================================================================
--	Game Engine EVENT
--	City added to map, refresh for local player needed if it's the 1st city.
-- ===========================================================================
function OnCityInitialized( owner:number, cityID:number )
  local localPlayer:number = Game.GetLocalPlayer();
  if owner == localPlayer then
    m_needsRefresh = true;
  end
end

-- ===========================================================================
--	Game Engine EVENT
-- ===========================================================================
function OnLocalPlayerTurnBegin()
  local localPlayer:number = Game.GetLocalPlayer();
  if localPlayer >= 0 then
    local pPlayerCulture:table = Players[localPlayer]:GetCulture();
    m_currentID = pPlayerCulture:GetProgressingCivic();

    m_needsRefresh = true;
  end
end

-- ===========================================================================
--	Game Engine EVENT
-- ===========================================================================
function OnPhaseBegin()
  if Game.GetLocalPlayer() >= 0 then
    m_needsRefresh = true;
  end
end

-- ===========================================================================
--	Game Engine EVENT
-- ===========================================================================
function OnCivicChanged( ePlayer:number, eCivic:number )
  local localPlayer = Game.GetLocalPlayer();
  if localPlayer ~= -1 and localPlayer == ePlayer then
    local pPlayerCulture:table = Players[localPlayer]:GetCulture();
    m_currentID			= pPlayerCulture:GetProgressingCivic();
    m_lastCompletedID	= -1;

    m_needsRefresh = true;
  end
end

-- ===========================================================================
function OnCivicCompleted( ePlayer:number, eCivic:number )
  if ePlayer == Game.GetLocalPlayer() then
    m_lastCompletedID	= eCivic;
    m_currentID			= -1;

    m_needsRefresh = true;
  end
end

-- ===========================================================================
function OnCultureYieldChanged( ePlayer:number )
  if ePlayer == Game.GetLocalPlayer() then
    m_needsRefresh = true;
  end
end

-- ===========================================================================
-- This will get called after a series of game events (before any other events or
-- input processing) so we can defer the rebuild until here.
-- ===========================================================================
function FlushChanges()
  if m_needsRefresh and ContextPtr:IsVisible() then
    Refresh();
  end
end


-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnInputHandler( kInputStruct:table )
  return m_kSlideAnimator.OnInputHandler( kInputStruct );
end


-- ===========================================================================
--
--	Init/Uninit/Hot-Loading Events
--
-- ===========================================================================
function OnInit( isReload:boolean )
  if isReload then
    LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
  else
    local localPlayer	:number = Game.GetLocalPlayer();
    if (localPlayer >= 0) then
      local pPlayerCulture:table = Players[localPlayer]:GetCulture();
      m_currentID = pPlayerCulture:GetProgressingCivic();
      Refresh();
    end
  end
end

-- ===========================================================================
function OnShow()
  Refresh();
end


-- ===========================================================================
function OnShutdown()
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_currentID", m_currentID);
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_isExpanded", m_isExpanded);
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_lastCompletedID", m_lastCompletedID);
end
-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
  if context == RELOAD_CACHE_ID then
    m_currentID			= contextTable["m_currentID"];
    m_lastCompletedID	= contextTable["m_lastCompletedID"];
    Refresh();
    if contextTable["m_isExpanded"] ~= nil and contextTable["m_isExpanded"] then
      OnOpenPanel();
    else
      LuaEvents.ResearchChooser_RestoreWorldTracker();
    end
  end
end

function CQUI_OnSettingsUpdate()
  CQUI_AlwaysOpenTechTrees = GameConfiguration.GetValue("CQUI_AlwaysOpenTechTrees");
  CQUI_ShowTechCivicRecommendations = GameConfiguration.GetValue("CQUI_ShowTechCivicRecommendations") == 1
end


-- ===========================================================================
--	INIT
-- ===========================================================================
function Initialize()

  -- Cache frequently used / expensive data
  m_CachedModifiers = TechAndCivicSupport_BuildCivicModifierCache(); 
 
  -- Hot-reload events
  ContextPtr:SetInitHandler(OnInit);
  ContextPtr:SetShowHandler(OnShow); 
  ContextPtr:SetShutdown(OnShutdown);
  LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);

  -- Animation controller and events
  m_kSlideAnimator = CreateScreenAnimation(Controls.SlideAnim, OnSlideAnimatorClose );

  -- Screen events
  LuaEvents.ActionPanel_OpenChooseCivic.Add(OnOpenPanel);
  LuaEvents.WorldTracker_OpenChooseCivic.Add(OnOpenPanel);
  LuaEvents.LaunchBar_CloseChoosers.Add(OnClosePanel); 

  -- Game events
  Events.CityInitialized.Add(			OnCityInitialized );
  Events.CivicChanged.Add(			OnCivicChanged );
  Events.CivicCompleted.Add(			OnCivicCompleted );
  Events.CultureYieldChanged.Add(		OnCultureYieldChanged );
  Events.LocalPlayerTurnBegin.Add(	OnLocalPlayerTurnBegin );
  Events.LocalPlayerChanged.Add(		OnLocalPlayerTurnBegin);
  Events.PhaseBegin.Add(				OnPhaseBegin );
  Events.SystemUpdateUI.Add(			OnUpdateUI );
  Events.GameCoreEventPublishComplete.Add( FlushChanges ); --This event is raised directly after a series of gamecore events.

  -- UI Event / Callbacks
  ContextPtr:SetInputHandler( OnInputHandler, true );
  Controls.CloseButton:RegisterCallback(		Mouse.eLClick,		OnClosePanel);
  Controls.CloseButton:RegisterCallback(		Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.TitleButton:RegisterCallback(		Mouse.eLClick,		OnClosePanel);
  Controls.IconButton:RegisterCallback(		Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.IconButton:RegisterCallback(		Mouse.eLClick,		OnClosePanel);
  Controls.OpenTreeButton:RegisterCallback(	Mouse.eLClick,		function() LuaEvents.CivicsChooser_RaiseCivicsTree(); OnClosePanel(); end);
  Controls.OpenTreeButton:RegisterCallback(	Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

-- CQUI events
  LuaEvents.CQUI_SettingsInitialized.Add( CQUI_OnSettingsUpdate );
  LuaEvents.CQUI_SettingsUpdate.Add( CQUI_OnSettingsUpdate );

  -- Populate static controls
  Controls.Title:SetText(Locale.ToUpper(Locale.Lookup("LOC_CIVICS_CHOOSER_CHOOSE_CIVIC")));
  Controls.OpenTreeButton:SetText(Locale.Lookup("LOC_CIVICS_CHOOSER_OPEN_CIVICS_TREE"));

  -- To make it render beneath the banner image
  Controls.MainPanel:SetOffsetX(Controls.Background:GetOffsetX() * -1);
  Controls.MainPanel:ChangeParent(Controls.Background);
end
Initialize();
