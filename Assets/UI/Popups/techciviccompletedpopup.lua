-- Copyright 2016-2018, Firaxis Games

-- ===========================================================================
--  Popups when a Tech or Civic are completed
-- ===========================================================================
include("TechAndCivicSupport");      -- (Already includes Civ6Common and InstanceManager) PopulateUnlockablesForTech, PopulateUnlockablesForCivic, GetUnlockablesForCivic, GetUnlockablesForTech
include("LocalPlayerActionSupport");


-- ===========================================================================
--  CONSTANTS / MEMBERS
-- ===========================================================================
local RELOAD_CACHE_ID    :string = "TechCivicCompletedPopup";
local m_unlockIM      :table  = InstanceManager:new( "UnlockInstance", "Top", Controls.UnlockStack );
local m_isDisabledByTutorial:boolean= false;
local m_kCurrentData    :table  = nil;
local m_kPopupData      :table  = {};
local m_isCivicData      :boolean= false;
local m_quote_audio:table;

-- ===========================================================================
-- CQUI Members
-- ===========================================================================
local CQUI_TechPopupVisual = true;
local CQUI_TechPopupAudio = true;

function CQUI_OnSettingsUpdate()
  CQUI_TechPopupVisual = GameConfiguration.GetValue("CQUI_TechPopupVisual");
  CQUI_TechPopupAudio = GameConfiguration.GetValue("CQUI_TechPopupAudio");
end


-- ===========================================================================
--  FUNCTIONS
-- ===========================================================================

-- ===========================================================================
function ShowCivicCompletedPopup( player:number, civic:number, quote:string, audio:string )
  local civicInfo:table = GameInfo.Civics[civic];
  if civicInfo == nil then
    UI.DataError("Cannot show civic popup because GameInfo.Civics["..tostring(civic).."] doesn't have data.");
    return;
  end

  local civicType = civicInfo.CivicType;

  local isCivicUnlockGovernmentType:boolean = false;

  -- Update Header
  Controls.HeaderLabel:SetText(Locale.Lookup("LOC_RESEARCH_COMPLETE_CIVIC_COMPLETE"));

  -- Update Theme Icons
  Controls.TopLeftIcon:SetTexture(0, 0, "CompletedPopup_CivicTheme1");
  Controls.LeftBottomIcon:SetTexture(0, 0, "CompletedPopup_CivicTheme2");
  Controls.RightBottomIcon:SetTexture(0, 0, "CompletedPopup_CivicTheme3");

  -- Update Research Icon
  Controls.ResearchIconFrame:SetTexture(0, 0, "CompletedPopup_CivicFrame");

  local icon = "ICON_" .. civicType;
  local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(icon,160);
  if textureSheet ~= nil then
    Controls.ResearchIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
  end

  -- Update Research Name
  Controls.ResearchName:SetText(Locale.ToUpper(Locale.Lookup(civicInfo.Name)));

  -- Show Free Government Change Label
  Controls.CivicMsgLabel:SetHide(false);
  Controls.CivicMsgLabel:SetText(Locale.Lookup("LOC_UI_CIVIC_PROGRESS_COMPLETE_BLURB", civicInfo.Name));

  -- Update Unlocked Icons
  m_unlockIM:ResetInstances();

  local unlockableTypes = GetUnlockablesForCivic(civicType, player);

  PopulateUnlockablesForCivic( player, civic, m_unlockIM );
  Controls.UnlockCountLabel:SetText(Locale.Lookup("LOC_RESEARCH_COMPLETE_UNLOCKED_BY_CIVIC", m_unlockIM.m_iAllocatedInstances));

  Controls.UnlockStack:CalculateSize();

  -- If there is a quote, display it.
  if quote then
    Controls.QuoteLabel:LocalizeAndSetText(quote);

    if audio then
      Controls.QuoteAudio:SetHide(false);
      Controls.QuoteButton:RegisterCallback(Mouse.eLClick, function()
        UI.PlaySound(audio);
      end);
    else
      Controls.QuoteAudio:SetHide(true);
      Controls.QuoteButton:ClearCallback(Mouse.eLClick);
    end

    Controls.QuoteButton:SetHide(false);
  else
    Controls.QuoteButton:SetHide(true);
  end

  -- Determine if we've unlocked a new government type
  for _,unlockItem in ipairs(unlockableTypes) do
    local typeInfo = GameInfo.Types[unlockItem[1]];
    if(typeInfo and typeInfo.Kind == "KIND_GOVERNMENT") then
      isCivicUnlockGovernmentType = true;
    end
  end

  -- Update Government Button depending on if we unlocked a new government type
  if isCivicUnlockGovernmentType then
    Controls.ChangeGovernmentButton:SetText(Locale.Lookup("LOC_GOVT_GOVERNMENT_UNLOCKED"));
    Controls.ChangeGovernmentButton:ClearCallback( Mouse.eLClick );
    Controls.ChangeGovernmentButton:RegisterCallback( Mouse.eLClick, OnChangeGovernment );
    Controls.ChangeGovernmentButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  else
    Controls.ChangeGovernmentButton:SetText(Locale.Lookup("LOC_GOVT_CHANGE_POLICIES"));
    Controls.ChangeGovernmentButton:ClearCallback( Mouse.eLClick );
    Controls.ChangeGovernmentButton:RegisterCallback( Mouse.eLClick, OnChangePolicy );
    Controls.ChangeGovernmentButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  end

  Controls.ChangeGovernmentButton:SetHide(false);    -- Show Change Government Button
end


-- ===========================================================================
function ShowTechCompletedPopup( player:number, tech:number, quote:string, audio:string )
  local techInfo:table = GameInfo.Technologies[tech];
  if techInfo == nil then
    UI.DataError("Cannot show popup because GameInfo.Technologies["..tostring(tech).."] doesn't have data.");
    return;
  end

  local techType = techInfo.TechnologyType;

  -- Update Header
  Controls.HeaderLabel:SetText(Locale.Lookup("LOC_RESEARCH_COMPLETE_TECH_COMPLETE"));

  -- Update Theme Icons
  Controls.TopLeftIcon:SetTexture(0, 0, "CompletedPopup_TechTheme1");
  Controls.LeftBottomIcon:SetTexture(0, 0, "CompletedPopup_TechTheme2");
  Controls.RightBottomIcon:SetTexture(0, 0, "CompletedPopup_TechTheme3");

  -- Update Research Icon
  Controls.ResearchIconFrame:SetTexture(0, 0, "CompletedPopup_TechFrame");

  local icon = "ICON_" .. techInfo.TechnologyType;
  local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(icon,160);
  if textureSheet ~= nil then
    Controls.ResearchIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
  end

  -- Update Research Name
  Controls.ResearchName:SetText(Locale.ToUpper(Locale.Lookup(techInfo.Name)));

  -- Hide Free Government Change Label
  Controls.CivicMsgLabel:SetHide(true);

  -- Update Unlocked Icons
  m_unlockIM:ResetInstances();
  PopulateUnlockablesForTech(player, tech, m_unlockIM);
  Controls.UnlockCountLabel:SetText(Locale.Lookup("LOC_RESEARCH_COMPLETE_UNLOCKED_BY_TECH", m_unlockIM.m_iAllocatedInstances));

  Controls.UnlockStack:CalculateSize();

  -- If we have a quote, display it.
  if quote then
    Controls.QuoteLabel:LocalizeAndSetText(quote);

    if audio then
      Controls.QuoteAudio:SetHide(false);
      Controls.QuoteButton:RegisterCallback(Mouse.eLClick, function()
        UI.PlaySound(audio);
      end);
    else
      Controls.QuoteAudio:SetHide(true);
      Controls.QuoteButton:ClearCallback(Mouse.eLClick);
    end

    Controls.QuoteButton:SetHide(false);
  else
    Controls.QuoteButton:SetHide(true);
  end

  Controls.ChangeGovernmentButton:SetHide(true);    -- Hide Change Government Button
end


-- ===========================================================================
function RefreshSize()
  -- Manually adjust the height so that there is minimal space for the image control.
  local PADDING:number = 30;
  local quote_height = math.max(100, Controls.QuoteLabel:GetSizeY() + PADDING);
  Controls.QuoteButton:SetSizeY(quote_height);

  Controls.BottomControlStack:CalculateSize();
  Controls.PopupBackgroundImage:DoAutoSize();
  Controls.PopupDrowShadowGrid:DoAutoSize();
end


-- ===========================================================================
function AddCompletedPopup( player:number, civic:number, tech:number, isByUser:boolean )
  local isNotBlockedByTutorial:boolean = (not m_isDisabledByTutorial);

  if player == Game.GetLocalPlayer() and isNotBlockedByTutorial and (not GameConfiguration.IsNetworkMultiplayer()) then

    local results  :table;
    local civicType  :string;
    local techType  :string;

    -- Grab quote from appropriate DB table.
    if civic then
      local civicInfo:table = GameInfo.Civics[civic];
      if civicInfo == nil then
        UI.DataError("Cannot show civic popup because GameInfo.Civics["..tostring(civic).."] doesn't have data.");
        return;
      end
      civicType = civicInfo.CivicType;
      results = DB.Query("SELECT Quote, QuoteAudio from CivicQuotes where CivicType = ? ORDER BY RANDOM() LIMIT 1", civicType);
    else
      local techInfo:table = GameInfo.Technologies[tech];
      if techInfo == nil then
        UI.DataError("Cannot add popup because GameInfo.Technologies["..tostring(tech).."] doesn't have data.");
        return;
      end
      techType = techInfo.TechnologyType
      results = DB.Query("SELECT Quote, QuoteAudio from TechnologyQuotes where TechnologyType = ? ORDER BY RANDOM() LIMIT 1", techType);
    end

    -- Update (random) quote
    local quote    :string;
    local audio    :string;
    if results then
      for i, row in ipairs(results) do
        quote = row.Quote;
        audio = row.QuoteAudio;
        break;
      end
    end

    table.insert(m_kPopupData, {
      player    = player,
      civic    = civic,
      civicType  = civicType,
      tech    = tech,
      techType  = techType,
      isByUser  = isByUser,
      quote    = quote,
      audio    = audio
    });

    -- If its the first (or only) popup data added then queue it in Forge.
    if (UIManager:IsInPopupQueue(ContextPtr) == false) then
      UIManager:QueuePopup( ContextPtr, PopupPriority.Low, { DelayShow = true });
    end
  end
end


-- ===========================================================================
--  UI Callback
--  Because this is such a low priority popup, wait until it's triggered to
--  show in the queue before displaying.
-- ===========================================================================
function OnShow()
  RealizeNextPopup();
end


-- ===========================================================================
function RealizeNextPopup()

  -- Only change the current data if it's been cleared out (as this screen
  -- may be re-shown if it was queued back up when showing governments.)
  if m_kCurrentData == nil then
    if (table.count(m_kPopupData) < 1) then
      UI.DataError("Attempt to realize the next WorldBuiltPopup but there is no data.");
      Close();
    end

    for i, v in ipairs(m_kPopupData) do
      m_kCurrentData = v;
      table.remove(m_kPopupData, i);
      break;
    end
  end

  m_isCivicData = (m_kCurrentData.tech == nil);
  if m_isCivicData then
    ShowCivicCompletedPopup(m_kCurrentData.player, m_kCurrentData.civic, m_kCurrentData.quote, m_kCurrentData.audio );
  else
    ShowTechCompletedPopup(m_kCurrentData.player, m_kCurrentData.tech, m_kCurrentData.quote, m_kCurrentData.audio );
  end

  UI.PlaySound("Pause_Advisor_Speech");
  UI.PlaySound("Resume_TechCivic_Speech");
  if(m_kCurrentData and m_kCurrentData.audio and CQUI_TechPopupAudio) then
      UI.PlaySound( m_kCurrentData.audio );
  end

  if not CQUI_TechPopupVisual then
    m_kPopupData = {};
    m_kCurrentData = nil;
    UIManager:DequeuePopup(ContextPtr);
  end

  RefreshSize();
end


-- ===========================================================================
--  Immediate close.
-- ===========================================================================
function Close()
  StopSound();
  m_kPopupData = {};            -- Force no data (e.g., immediate end turn)
  m_kCurrentData = nil;
  UIManager:DequeuePopup( ContextPtr );  -- Triggers hide event
end

-- ===========================================================================
function StopSound()
  UI.PlaySound("Stop_Speech_Civics");
  UI.PlaySound("Stop_Speech_Tech");
end

-- ===========================================================================
--  Will attempt to close but will show more popups if there are more.
-- ===========================================================================
function TryClose()

  if m_kCurrentData==nil then
    UI.DataError("Attempting to TryClosing the techcivic completed popup but it appears to have no data in it.");
    Close();
  end

  if m_kCurrentData.civicType and string.len(m_kCurrentData.civicType)>0 then
    LuaEvents.TechCivicCompletedPopup_CivicShown(m_kCurrentData.player, m_kCurrentData.civicType);
  else
    LuaEvents.TechCivicCompletedPopup_TechShown(m_kCurrentData.player, m_kCurrentData.techType );
  end

  m_kCurrentData = nil;
  -- If more left, continue...
  if table.count(m_kPopupData) > 0 then
    RealizeNextPopup();
    return;
  end
  Close();
end

-- ===========================================================================
--  UI Callback
-- ===========================================================================
function OnClose()
  TryClose();
end

-- ===========================================================================
function OnInputHandler( input )
  local msg = input:GetMessageType();
  if (msg == KeyEvents.KeyUp) then
    local key = input:GetKey();
    if key == Keys.VK_ESCAPE then
      TryClose();
      return true;
    end
  end
  return true; -- Consume all input
end

-- ===========================================================================
function OnChangeGovernment()
  LuaEvents.TechCivicCompletedPopup_GovernmentOpenGovernments(); -- Open Government Screen  before closing this popup, otherwise a popup in the queue will be shown and immediately hidden
  Close();
  UI.PlaySound("Stop_Speech_Civics");
end

-- ===========================================================================
function OnChangePolicy()
  LuaEvents.TechCivicCompletedPopup_GovernmentOpenPolicies();  -- Open Government Screen  before closing this popup, otherwise a popup in the queue will be shown and immediately hidden
  Close();
  UI.PlaySound("Stop_Speech_Civics");
end

-- ===========================================================================
--  UI Event
-- ===========================================================================
function OnInit( isReload:boolean )
  if isReload then
    LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
  end
end

-- ===========================================================================
--  UI EVENT
-- ===========================================================================
function OnShutdown()
  -- Cache values for hotloading...
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isHidden",      ContextPtr:IsHidden() );
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_kPopupData",    m_kPopupData );
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_kCurrentData",m_kCurrentData );
end

-- ===========================================================================
function OnLocalPlayerTurnEnd()
  if (GameConfiguration.IsHotseat()) then
    Close();
  end
end

-- ===========================================================================
--  LUA Event
--  Set cached values back after a hotload.
-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
  if context ~= RELOAD_CACHE_ID then
    return;
  end

  m_kCurrentData = contextTable["m_kCurrentData"];
  if m_kCurrentData ~= nil then
    AddCompletedPopup( m_kCurrentData.player, m_kCurrentData.civic, m_kCurrentData.tech, m_kCurrentData.isByUser );
  end
  m_kPopupData = contextTable["m_kPopupData"];
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnDisableTechAndCivicPopups()
  m_isDisabledByTutorial = true;
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnEnableTechAndCivicPopups()
  m_isDisabledByTutorial = false;
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnNotificationPanel_ShowTechDiscovered(ePlayer, techIndex:number, isByUser:boolean)
  AddCompletedPopup( ePlayer, nil, techIndex, isByUser );
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnNotificationPanel_ShowCivicDiscovered(ePlayer, civicIndex, isByUser:boolean)
  AddCompletedPopup( ePlayer, civicIndex, nil, isByUser  );
end

-- ===========================================================================
function Initialize()
  -- Controls Events
  ContextPtr:SetInitHandler( OnInit );
  ContextPtr:SetInputHandler( OnInputHandler, true );
  ContextPtr:SetShutdown( OnShutdown );
    ContextPtr:SetShowHandler( OnShow );

  Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnClose );
  Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

  -- LUA Events
  LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );
  LuaEvents.TutorialUIRoot_DisableTechAndCivicPopups.Add( OnDisableTechAndCivicPopups );
  LuaEvents.TutorialUIRoot_EnableTechAndCivicPopups.Add( OnEnableTechAndCivicPopups );
  LuaEvents.NotificationPanel_ShowTechDiscovered.Add( OnNotificationPanel_ShowTechDiscovered);
  LuaEvents.NotificationPanel_ShowCivicDiscovered.Add( OnNotificationPanel_ShowCivicDiscovered);

  -- Game Events
  Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );

  -- CQUI
  LuaEvents.CQUI_SettingsUpdate.Add( CQUI_OnSettingsUpdate );
  LuaEvents.CQUI_SettingsInitialized.Add( CQUI_OnSettingsUpdate );
end
Initialize();
