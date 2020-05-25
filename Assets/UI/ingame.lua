-- CQUI InGame.lua Replacement
-- CQUI-Specific Changes marked in-line below

-- Copyright 2015-2018, Firaxis Games
-- Root context for ingame (aka: All-the-things)
-- MODs / Expansions cannot use partial replacement as this context is 
-- directly added to the UI Control Tree via engine.

include( "LocalPlayerActionSupport" );
include( "InputSupport" );
-- ==== CQUI CUSTOMIZATION BEGIN  ==================================================================================== --
include( "Civ6Common" )
-- ==== CQUI CUSTOMIZATION END ======================================================================================= --


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local TIME_UNTIL_UPDATE:number = 0.1;	-- time to wait before attempting to release delayshow popups.


-- ===========================================================================
--	VARIABLES
-- ===========================================================================

local DefaultMessageHandler = {};
local m_bulkHideTracker :number = 0;
local m_lastBulkHider:string = "first call";
g_uiAddins = {};

local m_PauseId;
local m_PauseId		:number = Input.GetActionId("PauseMenu");
local m_QuicksaveId;
local m_QuicksaveId :number = Input.GetActionId("QuickSave");

local m_HexColoringReligion : number = UILens.CreateLensLayerHash("Hex_Coloring_Religion");
local m_CulturalIdentityLens: number = UILens.CreateLensLayerHash("Cultural_Identity_Lens");
local m_TouristTokens		: number = UILens.CreateLensLayerHash("Tourist_Tokens");
local m_activeLocalPlayer	: number = -1;
local m_timeUntilPopupCheck	: number = 0;

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================
-- ==== CQUI CUSTOMIZATION BEGIN  ==================================================================================== --
--CQUI Functions
function CQUI_RequestUIAddin( request: string ) --Returns the first context to match the request string. Returns nil if a matching context can't be found
  for _,v in ipairs(g_uiAddins) do
    if(v:GetID() == request) then
      return v;
    end
  end
end
-- ==== CQUI CUSTOMIZATION END ==================================================================================== --

-- ===========================================================================
--	Open up the TopOptionsMenu with the utmost priority.
-- ===========================================================================
function OpenInGameOptionsMenu()
  LuaEvents.InGame_OpenInGameOptionsMenu();
end

-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnTutorialToggleInGameOptionsMenu()
  if Controls.TopOptionsMenu:IsHidden() then
    OpenInGameOptionsMenu();
  else
    LuaEvents.InGame_CloseInGameOptionsMenu();
  end
end

-- ===========================================================================
DefaultMessageHandler[KeyEvents.KeyUp] =
  function( pInputStruct:table )

    local uiKey = pInputStruct:GetKey();

    if( uiKey == Keys.VK_ESCAPE ) then
-- ==== CQUI CUSTOMIZATION BEGIN  ==================================================================================== --
      -- AZURENCY : if a unit or a city is selected, deselect and reset interface mode
      -- instead of showing the option menu immediatly
      if (UI.GetHeadSelectedCity() or UI.GetHeadSelectedUnit()) then
        UI.DeselectAll();
        UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
        return true;
      end
-- ==== CQUI CUSTOMIZATION END ==================================================================================== --
      if( Controls.TopOptionsMenu:IsHidden() ) then
        OpenInGameOptionsMenu();
        return true;
      end

      return false;	-- Already open, let it handle it.
    elseif( uiKey == Keys.B and pInputStruct:IsShiftDown() and pInputStruct:IsAltDown() and (not UI.IsFinalRelease()) ) then
      -- DEBUG: Force unhiding
      local msg:string =  "***PLAYER Force Bulk unhiding SHIFT+ALT+B ***";
      UI.DataError(msg);
      m_bulkHideTracker = 1;
      BulkHide(false, msg);

    elseif( uiKey == Keys.J and pInputStruct:IsShiftDown() and pInputStruct:IsAltDown() and (not UI.IsFinalRelease()) ) then
      if m_bulkHideTracker < 1 then
        BulkHide(true,  "Forced" );
      else
        BulkHide(false, "Forced" );
      end
    end

    return false;
  end

----------------------------------------------------------------
-- LoadGameViewStateDone Event Handler
----------------------------------------------------------------
function OnLoadGameViewStateDone()
  -- show HUD elements that relay on the gamecache being fully initialized.
  if(GameConfiguration.IsNetworkMultiplayer()) then
    Controls.MultiplayerTurnManager:SetHide(false);
  end
end

----------------------------------------------------------------
-- Input handling
----------------------------------------------------------------
function OnInputHandler( pInputStruct )
  local uiMsg = pInputStruct:GetMessageType();

  if DefaultMessageHandler[uiMsg] ~= nil then
    return DefaultMessageHandler[uiMsg]( pInputStruct );
  end
  return false;
end

----------------------------------------------------------------
function OnShow()
  Controls.WorldViewControls:SetHide( false );

  local pFriends = Network.GetFriends();
  if (pFriends ~= nil) then
    if (GameConfiguration.IsAnyMultiplayer()) then
      if GameConfiguration.IsHotseat() then
        pFriends:SetRichPresence("civPresence", "LOC_PRESENCE_IN_GAME_HOTSEAT");
      elseif GameConfiguration.IsLANMultiplayer() then
        pFriends:SetRichPresence("civPresence", "LOC_PRESENCE_IN_GAME_LAN");
      elseif GameConfiguration.IsPlayByCloud() then
        pFriends:SetRichPresence("civPresence", "LOC_PRESENCE_IN_GAME_PLAYBYCLOUD");
      else
        pFriends:SetRichPresence("civPresence", "LOC_PRESENCE_IN_GAME_ONLINE");
      end
    else
      pFriends:SetRichPresence("civPresence", "LOC_PRESENCE_IN_GAME_SP");
    end
  end
end


-- ===========================================================================
--	Hide (or Show) all the contexts part of the BULK group.
-- ===========================================================================
function BulkHide( isHide:boolean, debugWho:string )

  -- Tracking for debugging:
  m_bulkHideTracker = m_bulkHideTracker + (isHide and 1 or -1);
  -- ==== CQUI CUSTOMIZATION BEGIN  ==================================================================================== --
  -- CQUI: Unmodifed file just uses print here (rather than print_debug), rest of line is the same
  print_debug("Request to BulkHide( "..tostring(isHide)..", "..debugWho.." ), Show on 0 = "..tostring(m_bulkHideTracker));
-- ==== CQUI CUSTOMIZATION END ==================================================================================== --

  if m_bulkHideTracker < 0 then
    UI.DataError("Request to bulk show past limit by "..debugWho..". Last bulk shown by "..m_lastBulkHider);
    m_bulkHideTracker = 0;
  end
  m_lastBulkHider = debugWho;

  -- Do the bulk hiding/showing
  local kGroups:table = {"WorldViewControls", "HUD", "PartialScreens", "Screens", "TopLevelHUD" };
  for i,group in ipairs(kGroups) do
    local pContext :table = ContextPtr:LookUpControl("/InGame/"..group);
    if pContext == nil then
      UI.DataError("InGame is unable to BulkHide("..isHide..") '/InGame/"..group.."' because the Context doesn't exist.");
    else
      if m_bulkHideTracker == 1 and isHide then
        pContext:SetHide(true);
      elseif m_bulkHideTracker == 0 and isHide==false then
        pContext:SetHide(false);
        RestartRefreshRequest();
      else
        -- Do nothing
      end
    end
  end
end


-- ===========================================================================
--	Hotkey Event
-- ===========================================================================
function OnInputActionTriggered( actionId )
  if actionId == m_PauseId then
    if(Controls.TopOptionsMenu:IsHidden()) then
      OpenInGameOptionsMenu();
      return true;
    end
  elseif actionId == m_QuicksaveId then
    -- Quick save
    if CanLocalPlayerSaveGame() then
      local gameFile = {};
      gameFile.Name = "quicksave";
      gameFile.Location = SaveLocations.LOCAL_STORAGE;
      gameFile.Type= Network.GetGameConfigurationSaveType();
      gameFile.IsAutosave = false;
      gameFile.IsQuicksave = true;

      Network.SaveGame(gameFile);
      UI.PlaySound("Confirm_Bed_Positive");
    end
  end
end

-- ===========================================================================
--	Gamecore Event
--	Called once per layer that is turned on when a new lens is activated,
--	or when a player explicitly turns off the layer from the "player" lens.
-- ===========================================================================
function OnLensLayerOn( layerHash:number )
  if layerHash == m_HexColoringReligion or layerHash == m_CulturalIdentityLens or
    layerHash == m_TouristTokens then
    Controls.CityBannerManager:ChangeParent(Controls.BannerAndFlags);
  end
end

-- ===========================================================================
--	Gamecore Event
--	Called once per layer that is turned on when a new lens is deactivated,
--	or when a player explicitly turns off the layer from the "player" lens.
-- ===========================================================================
function OnLensLayerOff( layerHash:number )
  if layerHash == m_HexColoringReligion or layerHash == m_CulturalIdentityLens or
      layerHash == m_TouristTokens then
    Controls.UnitFlagManager:ChangeParent(Controls.BannerAndFlags);
  end
end

-- ===========================================================================
--	EVENT
-- ===========================================================================
function OnTurnBegin()
  m_activeLocalPlayer = Game.GetLocalPlayer();
end

-- ===========================================================================
--	EVENT
-- ===========================================================================
function OnTurnEnd()
  m_activeLocalPlayer = -1;
end

-- ===========================================================================
function RestartRefreshRequest()
  -- Increasing this adds a delay, but will make it less likely that lower
  -- priority popups will be shown before all the popups are in added in
  -- the queue.
  m_timeUntilPopupCheck = TIME_UNTIL_UPDATE;
  ContextPtr:SetRefreshHandler( OnRefreshAttemptPopupRelease );
  ContextPtr:RequestRefresh();
end

-- ===========================================================================
--	EVENT
--	Gamecore is done processing events; this may fire multiple times as a
--	turn begins, as well as after player actions.
-- ===========================================================================
function OnGameCoreEventPlaybackComplete()
  -- Gate using this based on whether or not it's firing for a local player
  if m_activeLocalPlayer == -1 then return; end;
  RestartRefreshRequest();
end

-- ===========================================================================
--	UI Manager Callback
-- ===========================================================================
function OnPopupQueueChange( isQueuing:boolean )
  if m_timeUntilPopupCheck <= 0 then
    RestartRefreshRequest();
  end
end

-- ===========================================================================
--	Event
-- ===========================================================================
function OnUIIdle()
  -- If a countdown to check hasn't started, kick one off.
  if m_timeUntilPopupCheck <= 0 then
    RestartRefreshRequest();
  end
end

-- ===========================================================================
function IsAbleToShowDelayedPopups()
  local isBulkHideOkay :boolean = (m_bulkHideTracker == 0);
  local isQueueEnabled :boolean = (UIManager:IsPopupQueueDisabled() == false);
  return isBulkHideOkay and isQueueEnabled;
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnRefreshAttemptPopupRelease( delta:number )
  m_timeUntilPopupCheck = m_timeUntilPopupCheck - delta;
  if m_timeUntilPopupCheck <= 0 then
    -- Only release delayed popups if a bulk hide operation isn't currently happening.
    if IsAbleToShowDelayedPopups() then
      UIManager:ShowDelayedPopups();		-- Show any popups that had been added to Forge waiting to be shown
    end
    ContextPtr:ClearRefreshHandler();
  else
    ContextPtr:RequestRefresh();
  end
end

-- ===========================================================================
function OnDiplomacyHideIngameUI()    BulkHide( true, "Diplomacy" );     Input.PushActiveContext(InputContext.Diplomacy);     end
function OnDiplomacyShowIngameUI()    BulkHide(false, "Diplomacy" );     Input.PopContext();                                  end
function OnEndGameMenuShown()         BulkHide( true, "EndGame" );       Input.PushActiveContext(InputContext.EndGame);       end
function OnEndGameMenuClosed()        BulkHide(false, "EndGame" );       Input.PopContext();                                  end
function OnFullscreenMapShown()       BulkHide( true, "FullscreenMap" ); Input.PushActiveContext(InputContext.FullscreenMap); end
function OnFullscreenMapClosed()      BulkHide(false, "FullscreenMap" ); Input.PopContext();                                  end
function OnNaturalWonderPopupShown()  BulkHide( true, "NaturalWonder" );                                                      end
function OnNaturalWonderPopupClosed() BulkHide(false, "NaturalWonder" );                                                      end
function OnProjectBuiltShown()        BulkHide( true, "Project" );                                                            end
function OnProjectBuiltClosed()       BulkHide(false, "Project" );                                                            end
function OnTutorialEndHide()          BulkHide( true, "TutorialEnd" );                                                        end
function OnWonderBuiltPopupShown()    BulkHide( true, "Wonder" );                                                             end
function OnWonderBuiltPopupClosed()   BulkHide(false, "Wonder" );                                                             end


-- ===========================================================================
function OnShutdown()
  UIManager:ClearPopupChangeHandler();
end

-- ===========================================================================
--	Cannot use LateInitialize patterns as this context is attached via C++
-- ===========================================================================
function Initialize()

  m_activeLocalPlayer = Game.GetLocalPlayer();

  -- Support for Modded Add-in UI's
  for i, addin in ipairs(Modding.GetUserInterfaces("InGame")) do
-- ==== CQUI CUSTOMIZATION BEGIN  ==================================================================================== --
    -- CQUI: Unmodifed version just uses print here rather than print_debug
    print_debug("Loading InGame UI - " .. addin.ContextPath);
-- ==== CQUI CUSTOMIZATION END ==================================================================================== --
    local id        :string = addin.ContextPath:sub(-(string.find(string.reverse(addin.ContextPath), '/') - 1));         -- grab id from end of path
    local isHidden  :boolean = true;
    local newContext:table = ContextPtr:LoadNewContext(addin.ContextPath, Controls.AdditionalUserInterfaces, id, isHidden); -- Content, ID, hidden
    table.insert(g_uiAddins, newContext);
  end

  ContextPtr:SetInputHandler( OnInputHandler, true );
  ContextPtr:SetShowHandler( OnShow );
  ContextPtr:SetRefreshHandler(OnRefreshAttemptPopupRelease);
  ContextPtr:SetShutdown(OnShutdown);
  UIManager:SetPopupChangeHandler(OnPopupQueueChange);

  Events.GameCoreEventPlaybackComplete.Add(OnGameCoreEventPlaybackComplete);
  Events.InputActionTriggered.Add(OnInputActionTriggered);
  Events.LensLayerOff.Add(OnLensLayerOff);
  Events.LensLayerOn.Add(OnLensLayerOn);
  Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone);
  Events.LocalPlayerTurnBegin.Add(OnTurnBegin);
  Events.LocalPlayerTurnEnd.Add(OnTurnEnd);
  Events.UIIdle.Add(OnUIIdle);

  -- NOTE: Using UI open/closed pairs in the case of end game; where
  --		 the same player receives both a victory and defeat messages
  --		 across the wire.
  LuaEvents.DiplomacyActionView_HideIngameUI.Add( OnDiplomacyHideIngameUI );
  LuaEvents.DiplomacyActionView_ShowIngameUI.Add( OnDiplomacyShowIngameUI );
  LuaEvents.EndGameMenu_Shown.Add( OnEndGameMenuShown );
  LuaEvents.EndGameMenu_Closed.Add( OnEndGameMenuClosed );
  LuaEvents.FullscreenMap_Shown.Add( OnFullscreenMapShown );
  LuaEvents.FullscreenMap_Closed.Add(	OnFullscreenMapClosed );
  LuaEvents.NaturalWonderPopup_Shown.Add( OnNaturalWonderPopupShown );
  LuaEvents.NaturalWonderPopup_Closed.Add( OnNaturalWonderPopupClosed );
  LuaEvents.ProjectBuiltPopup_Shown.Add( OnProjectBuiltShown );
  LuaEvents.ProjectBuiltPopup_Closed.Add( OnProjectBuiltClosed );
  LuaEvents.Tutorial_ToggleInGameOptionsMenu.Add( OnTutorialToggleInGameOptionsMenu );
  LuaEvents.Tutorial_TutorialEndHideBulkUI.Add( OnTutorialEndHide );
  LuaEvents.WonderBuiltPopup_Shown.Add( OnWonderBuiltPopupShown );
  LuaEvents.WonderBuiltPopup_Closed.Add(	OnWonderBuiltPopupClosed );

-- ==== CQUI CUSTOMIZATION BEGIN  ==================================================================================== --
  --CQUI event handling
  LuaEvents.CQUI_RequestUIAddin.Add(function(request: string, requester: string) LuaEvents.CQUI_PushUIAddIn(CQUI_RequestUIAddin(request), recipient); end); --Responds to an addin request with a PushUIAddIn event containing the requested context. Can return nil
-- ==== CQUI CUSTOMIZATION END ==================================================================================== --

end
Initialize();
