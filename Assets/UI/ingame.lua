-- ===========================================================================
--	Civ6
--	Root context for ingame (aka: All-the-things)
-- ===========================================================================

include( "LocalPlayerActionSupport" );
include( "InputSupport" );
include( "civ6common" )

-- ===========================================================================
--	VARIABLES
-- ===========================================================================

local DefaultMessageHandler = {};
local m_bulkHideTracker :number = 0;
local m_lastBulkHider:string = "first call";
g_uiAddins = {};

local m_PauseId;
local m_QuicksaveId;

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

--CQUI Functions
function CQUI_RequestUIAddin( request: string ) --Returns the first context to match the request string. Returns nil if a matching context can't be found
  for _,v in ipairs(g_uiAddins) do
    if(v:GetID() == request) then
      return v;
    end
  end
end

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
      -- AZURENCY : if a unit or a city is selected, deselect and reset interface mode
      -- instead of showing the option menu immediatly
      if (UI.GetHeadSelectedCity() or UI.GetHeadSelectedUnit()) then
        UI.DeselectAll();
        UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
        return true;
      end
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
  print_debug("Request to BulkHide( "..tostring(isHide)..", "..debugWho.." ), Show on 0 = "..tostring(m_bulkHideTracker));

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
        if( Controls.TopOptionsMenu:IsHidden() ) then
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
function OnWonderRevealPopupShown()		BulkHide( true, "Wonder" );																end		--	Game Engine Event
function OnWonderRevealPopupClosed()	BulkHide(false, "Wonder" );																end		--	Game Engine Event
function OnNaturalWonderPopupShown()	BulkHide( true, "NaturalWonder" );														end		--	LUA Event
function OnNaturalWonderPopupClosed()	BulkHide(false, "NaturalWonder" );														end		--	LUA Event
function OnEndGameMenuShown()			BulkHide( true, "EndGame" ); 		Input.PushActiveContext(InputContext.EndGame);		end		--	LUA Event
function OnEndGameMenuClosed()			BulkHide(false, "EndGame" );		Input.PopContext();									end		--	LUA Event
function OnDiplomacyHideIngameUI()		BulkHide( true, "Diplomacy" );		Input.PushActiveContext(InputContext.Diplomacy);	end		--	LUA Event
function OnDiplomacyShowIngameUI()		BulkHide(false, "Diplomacy" );		Input.PopContext();									end		--	LUA Event
function OnTutorialEndHide()			BulkHide( true, "TutorialEnd" );														end		--	LUA Event

-- ===========================================================================
function Initialize()

  -- Support for Modded Add-in UI's
  for i, addin in ipairs(Modding.GetUserInterfaces("InGame")) do
    print_debug("Loading InGame UI - " .. addin.ContextPath);
    local newContext:table = ContextPtr:LoadNewContext(addin.ContextPath);
    newContext:ChangeParent(Controls.AdditionalUserInterfaces);
    table.insert(g_uiAddins, newContext);
  end

  ContextPtr:SetInputHandler( OnInputHandler, true );
  ContextPtr:SetShowHandler( OnShow );

  Events.LoadGameViewStateDone.Add(	OnLoadGameViewStateDone );

    m_PauseId = Input.GetActionId("PauseMenu");
    m_QuicksaveId = Input.GetActionId("QuickSave");
    Events.InputActionTriggered.Add( OnInputActionTriggered );

  -- NOTE: Using UI open/closed pairs in the case of end game; where
  --		 the same player receives both a victory and defeat messages
  --		 across the wire.
  LuaEvents.EndGameMenu_Shown.Add( OnEndGameMenuShown );
  LuaEvents.EndGameMenu_Closed.Add( OnEndGameMenuClosed );
  LuaEvents.DiplomacyActionView_HideIngameUI.Add( OnDiplomacyHideIngameUI );
  LuaEvents.DiplomacyActionView_ShowIngameUI.Add( OnDiplomacyShowIngameUI );
  LuaEvents.WonderRevealPopup_Shown.Add( OnWonderRevealPopupShown );
  LuaEvents.WonderRevealPopup_Closed.Add(	OnWonderRevealPopupClosed );
  LuaEvents.NaturalWonderPopup_Shown.Add( OnNaturalWonderPopupShown );
  LuaEvents.NaturalWonderPopup_Closed.Add( OnNaturalWonderPopupClosed );
  LuaEvents.Tutorial_ToggleInGameOptionsMenu.Add( OnTutorialToggleInGameOptionsMenu );
  LuaEvents.Tutorial_TutorialEndHideBulkUI.Add( OnTutorialEndHide );
  --CQUI event handling
  LuaEvents.CQUI_RequestUIAddin.Add(function(request: string, requester: string) LuaEvents.CQUI_PushUIAddIn(CQUI_RequestUIAddin(request), recipient); end); --Responds to an addin request with a PushUIAddIn event containing the requested context. Can return nil

end
Initialize();
