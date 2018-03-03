-- ===========================================================================
--  HUD Partial Screen Hooks
-- ===========================================================================
include("GameCapabilities");
include("InstanceManager");

-- ===========================================================================
--  Action Hotkeys
-- ===========================================================================
local m_ToggleCSId    :number = Input.GetActionId("ToggleCityStates");
local m_ToggleEspId   :number = Input.GetActionId("ToggleEspionage");
local m_ToggleRankingsId:number = Input.GetActionId("ToggleRankings");
local m_ToggleTradeId :number = Input.GetActionId("ToggleTradeRoutes");


-- ===========================================================================
--  CONSTANTS
-- ===========================================================================
local MIN_BG_SIZE       : number = 226;   -- Minimum size for the non-tiling component of the launch container
local BG_PADDING        : number = 116;   -- Additional pad the background PAST the size of the hooks
local BG_TILE_PADDING     : number = 20;    -- Inner padding to give the tile of the hook bar so that it does not show behind the hook bar itself
local BG_TOTAL_OFFSCREEN_OFFSET : number = -126;  -- Amount of negative offset to totally remove the partial hook bar from the screen.  Used so that we can add back the size of the hook stack to the bar when we have < 2 hooks visible

local m_kPartialScreens:table = { -- Screens that are considered "partial" and mutually exclusive in showing.
  "CityStates",
  "EspionageOverview",
  "WorldRankings",
  "TradeOverview"
}


-- ===========================================================================
--  VARIABLES
-- ===========================================================================
local m_isEspionageUnlocked   :boolean = false;
local m_isTradeRoutesUnlocked :boolean = false;
local m_isCityStatesUnlocked  :boolean = false;
local m_isDebug               :boolean = false;

local m_ScreenHookIM:table = InstanceManager:new("ScreenHookInstance", "ScreenHookStack", Controls.ButtonStack);


-- ===========================================================================
--  Checks all the screens or if a screen name is checked in, will check that
--  specific one.
--  RETURNS: true if any partial screen is open; false otherwise.
-- ===========================================================================
function IsPartialScreenOpen( optionalScreenName:string )
  local kScreensToCheck:table = m_kPartialScreens;
  if optionalScreenName then
    kScreensToCheck = { optionalScreenName }; -- Override with specific screne
  end
  for _,contextName:string in ipairs( kScreensToCheck ) do
    local pContextControl :table = ContextPtr:LookUpControl("/InGame/" .. contextName );
    if pContextControl == nil then
      UI.DataError("Cannot determine if partial screen \"/InGame/"..contextName.."\" is visible because it wasn't found at that path.");
    elseif not pContextControl:IsHidden() then
      return true;
    end
  end
  return false;
end


-- ===========================================================================
--  UI Control Callback
-- ===========================================================================
function OnToggleEspionage()
  if IsPartialScreenOpen("EspionageOverview") then
    LuaEvents.PartialScreenHooks_CloseEspionage();
  else
    if IsPartialScreenOpen() then       -- Only play open sound if no partial screen is open.
      LuaEvents.PartialScreenHooks_CloseAllExcept("EspionageOverview");
    end
    LuaEvents.PartialScreenHooks_OpenEspionage();
  end
end

-- ===========================================================================
--  UI Control Callback
-- ===========================================================================
function OnToggleCityStates()
  if IsPartialScreenOpen("CityStates") then
    LuaEvents.PartialScreenHooks_CloseCityStates();
  else
    if IsPartialScreenOpen() then       -- Only play open sound if no partial screen is open.
      LuaEvents.PartialScreenHooks_CloseAllExcept("CityStates");
    end
    LuaEvents.PartialScreenHooks_OpenCityStates();
  end
end

-- ===========================================================================
--  UI Control Callback
-- ===========================================================================
function OnToggleTradeOverview()
  if IsPartialScreenOpen("TradeOverview") then
    LuaEvents.PartialScreenHooks_CloseTradeOverview();
  else
    if IsPartialScreenOpen() then       -- Only play open sound if no partial screen is open.
      LuaEvents.PartialScreenHooks_CloseAllExcept("TradeOverview");
    end
    LuaEvents.PartialScreenHooks_OpenTradeOverview();
  end
end

-- ===========================================================================
--  UI Control Callback
-- ===========================================================================
function OnToggleWorldRankings()
  if IsPartialScreenOpen("WorldRankings") then
    LuaEvents.PartialScreenHooks_CloseWorldRankings();
  else
    if IsPartialScreenOpen() then       -- Only play open sound if no partial screen is open.
      LuaEvents.PartialScreenHooks_CloseAllExcept("WorldRankings");
    end
    LuaEvents.PartialScreenHooks_OpenWorldRankings();
  end
end

-- ===========================================================================
--  UI Control Callback
-- ===========================================================================
function OnOpenDiplomacy()
  LuaEvents.TopPanel_OpenDiplomacyActionView();
end

-- ===========================================================================
-- ===========================================================================
function Resize()
  -- Reset screen hooks instances
  m_ScreenHookIM:ResetInstances();
 
  AddScreenHooks();
 
  -- The Launch Bar width should accomodate how many hooks are currently in the stack.  
  Controls.ButtonStack:CalculateSize();

  if( MIN_BG_SIZE > Controls.ButtonStack:GetSizeX() + BG_PADDING) then
    Controls.LaunchBacking:SetSizeX(MIN_BG_SIZE);
    Controls.LaunchBacking:SetOffsetX(BG_TOTAL_OFFSCREEN_OFFSET + (Controls.ButtonStack:GetSizeX() + BG_TILE_PADDING));
  else
    Controls.LaunchBacking:SetOffsetX(2);
    Controls.LaunchBacking:SetSizeX(Controls.ButtonStack:GetSizeX() + BG_PADDING);
  end
  Controls.LaunchBackingDropShadow:SetSizeX(Controls.ButtonStack:GetSizeX() + BG_TILE_PADDING);
  Controls.LaunchBackingTile:SetSizeX(Controls.ButtonStack:GetSizeX() - BG_TILE_PADDING);
  LuaEvents.PartialScreenHooks_Resize();
end

-- ===========================================================================
function AddScreenHooks()
  if (m_isCityStatesUnlocked and HasCapability("CAPABILITY_CITY_STATES_VIEW")) then
    AddScreenHook("LaunchBar_Hook_CityStates", "LOC_PARTIALSCREEN_CITYSTATES_TOOLTIP", function() OnToggleCityStates(); end);
  end
  if (m_isTradeRoutesUnlocked and HasCapability("CAPABILITY_TRADE_VIEW")) then
    AddScreenHook("LaunchBar_Hook_Trade", "LOC_PARTIALSCREEN_TRADEROUTES_TOOLTIP", function() OnToggleTradeOverview(); end);
  end
  if (m_isEspionageUnlocked and HasCapability("CAPABILITY_ESPIONAGE_VIEW")) then
    AddScreenHook("LaunchBar_Hook_Espionage", "LOC_PARTIALSCREEN_ESPIONAGE_TOOLTIP", function() OnToggleEspionage(); end);
  end
end

-- ===========================================================================
function AddScreenHook(texture:string, tooltip:string, callback:ifunction)
  local screenHookInst:table = m_ScreenHookIM:GetInstance();
  screenHookInst.ScreenHookImage:SetTexture(texture);
  screenHookInst.ScreenHookButton:SetToolTipString(Locale.Lookup(tooltip));
  screenHookInst.ScreenHookButton:RegisterCallback( Mouse.eLClick, callback );
  screenHookInst.ScreenHookButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
end


-- ===========================================================================
--  Refresh Data and View
-- ===========================================================================
-- Capture the meet civ event to see if we have encountered a city-state
function OnDiplomacyMeet(player1ID:number, player2ID:number)
  if(not m_isCityStatesUnlocked) then
    local localPlayerID:number = Game.GetLocalPlayer();
    -- Have a local player?
    if(localPlayerID ~= -1) then
      -- Was the local player involved, and was it a minor civ that was met?
      local metPlayer = Players[player2ID];
      if (player1ID == localPlayerID and not metPlayer:IsMajor() and not metPlayer:IsBarbarian()) then
        m_isCityStatesUnlocked = true;
        Resize();
      end
    end
  end
end

function CheckTradeCapacity(localPlayer)
  if (not m_isTradeRoutesUnlocked) then
    local playerTrade :table  = localPlayer:GetTrade();
    local routesCapacity:number = playerTrade:GetOutgoingRouteCapacity();
    if (routesCapacity > 0) then
      m_isTradeRoutesUnlocked = true;
    end
  end
end

function CheckSpyCapacity(localPlayer)
  if (not m_isEspionageUnlocked) then
    local playerDiplo :table = localPlayer:GetDiplomacy();
    local spyCapacity:number = playerDiplo:GetSpyCapacity();
    if (spyCapacity > 0) then
      m_isEspionageUnlocked = true;
    end
  end
end

-- Capture spies or traders becoming unlocked
function OnCivicCompleted( player:number, civic:number, isCanceled:boolean)
  if player == Game.GetLocalPlayer() and (not m_isEspionageUnlocked or not m_isTradeRoutesUnlocked) then
    local localPlayer = Players[Game.GetLocalPlayer()];
    if (localPlayer == nil) then
      return;
    end
    CheckTradeCapacity(localPlayer);
    CheckSpyCapacity(localPlayer);
    Resize();
  end
end

-- Check trade, spy, and partial screen hooks OnTurnBegin
function OnTurnBegin()
  local ePlayer:number = Game.GetLocalPlayer();
  if ePlayer == -1 then
    return;
  end
  localPlayer = Players[ePlayer];

  CheckTradeCapacity(localPlayer);
  CheckSpyCapacity(localPlayer);
  CheckCityStatesUnlocked(localPlayer); 
  
  Resize();
end
 
-- ===========================================================================
function CheckCityStatesUnlocked(localPlayer:table)
  --  Check to see if the player has met any city-states
  --  Note: I'm using not IsMajor and not IsBarbarian to determine the city-state check at this point - though elsewhere we have used CanReceiveInfluencePoints.
  --  For future expansions we should probably create an IsMinor check for the Player object.
  if (not m_isCityStatesUnlocked) then
    local localDiplomacy:table = localPlayer:GetDiplomacy();
    local aPlayers = PlayerManager.GetAliveMinors();
    for _, pPlayer in ipairs(aPlayers) do
      if (not pPlayer:IsMajor() and not pPlayer:IsBarbarian() and localDiplomacy:HasMet(pPlayer:GetID())) then
        m_isCityStatesUnlocked = true;
      end
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
--  Input Hotkey Event
-- ===========================================================================
function OnInputActionTriggered( actionId )
  if m_isCityStatesUnlocked and actionId == m_ToggleCSId then
    OnToggleCityStates();
    UI.PlaySound("Play_UI_Click");
  end
  if m_isCityStatesUnlocked and actionId == m_ToggleEspId and HasCapability("CAPABILITY_ESPIONAGE_VIEW") then
    if UI.QueryGlobalParameterInt("DISABLE_ESPIONAGE_HOTKEY") ~= 1 then
        OnToggleEspionage();
        UI.PlaySound("Play_UI_Click");
    end
  end
  if actionId == m_ToggleRankingsId and HasCapability("CAPABILITY_WORLD_RANKINGS") then
    OnToggleWorldRankings();
    UI.PlaySound("Play_UI_Click");
  end
  if m_isCityStatesUnlocked and actionId == m_ToggleTradeId and HasCapability("CAPABILITY_TRADE_VIEW") then
    OnToggleTradeOverview();
    UI.PlaySound("Play_UI_Click");
  end
end

-- ===========================================================================
--  Reset the hooks that are visible for hotseat
-- ===========================================================================
function OnLocalPlayerChanged()
  m_isEspionageUnlocked = false;
  m_isTradeRoutesUnlocked = false;
  m_isCityStatesUnlocked  = false;
  OnTurnBegin();
end

-- ===========================================================================
--  Lua Event
--  Tutorial system is requesting any partial screens open, to be closed.
-- ===========================================================================
function OnTutorialCloseAll()
  if IsPartialScreenOpen("EspionageOverview") then  LuaEvents.PartialScreenHooks_CloseEspionage(); end
  if IsPartialScreenOpen("CityStates") then    LuaEvents.PartialScreenHooks_CloseCityStates(); end
  if IsPartialScreenOpen("TradeOverview") then    LuaEvents.PartialScreenHooks_CloseTradeOverview(); end
  if IsPartialScreenOpen("WorldRankings") then    LuaEvents.PartialScreenHooks_CloseWorldRankings(); end
end

-- ===========================================================================
-- "Modular Screen" mod by Astog
-- ===========================================================================
function OnAddScreenHook(hookInfo:table)
  -- print("Build hook")
  local tButtonEntry:table = {};
  ContextPtr:BuildInstanceForControl("HookIconInstance", tButtonEntry, Controls.ButtonStack);

  local textureOffsetX = hookInfo.IconTexture.OffsetX;
  local textureOffsetY = hookInfo.IconTexture.OffsetY;
  local textureSheet = hookInfo.IconTexture.Sheet;

  -- Update Icon Info
  if (textureOffsetX ~= nil and textureOffsetY ~= nil and textureSheet ~= nil) then
    tButtonEntry.Icon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
  end
  if (hookInfo.IconTexture.Color ~= nil) then
    tButtonEntry.Icon:SetColor(hookInfo.IconTexture.Color);
  end

  if (hookInfo.Tooltip ~= nil) then
    tButtonEntry.Button:SetToolTipString(hookInfo.Tooltip);
  end

  textureOffsetX = hookInfo.BaseTexture.OffsetX;
  textureOffsetY = hookInfo.BaseTexture.OffsetY;
  textureSheet = hookInfo.BaseTexture.Sheet;

  local stateOffsetX = hookInfo.BaseTexture.HoverOffsetX;
  local stateOffsetY = hookInfo.BaseTexture.HoverOffsetY;

  if (textureOffsetX ~= nil and textureOffsetY ~= nil and textureSheet ~= nil) then
    tButtonEntry.Base:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
    if (hookInfo.BaseTexture.Color ~= nil) then
      tButtonEntry.Base:SetColor(hookInfo.BaseTexture.Color);
    end

    -- Setup behaviour on hover
    if (stateOffsetX ~= nil and stateOffsetY ~= nil) then
      local OnMouseOver = function()
        tButtonEntry.Base:SetTextureOffsetVal(stateOffsetX, stateOffsetY);
        UI.PlaySound("Main_Menu_Mouse_Over");
      end

      local OnMouseExit = function()
        tButtonEntry.Base:SetTextureOffsetVal(textureOffsetX, textureOffsetY);
      end

      tButtonEntry.Button:RegisterMouseEnterCallback( OnMouseOver );
      tButtonEntry.Button:RegisterMouseExitCallback( OnMouseExit );
    end
  end

  if (hookInfo.Callback ~= nil) then
    tButtonEntry.Button:RegisterCallback( Mouse.eLClick, hookInfo.Callback );
  end

  Resize()
end

-- ===========================================================================
function OnInit()
  OnTurnBegin();
end

-- ===========================================================================
function Initialize()
  Controls.WorldRankingsButton:RegisterCallback( Mouse.eLClick, OnToggleWorldRankings );
  Controls.WorldRankingsButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  
  Events.CivicCompleted.Add(OnCivicCompleted);
  Events.DiplomacyMeet.Add( function() OnDiplomacyMeet(); end);
  Events.InputActionTriggered.Add( OnInputActionTriggered );
  Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
  Events.LocalPlayerChanged.Add( OnLocalPlayerChanged );
  Events.TurnBegin.Add( OnTurnBegin );

  LuaEvents.Tutorial_CloseAllPartialScreens.Add( OnTutorialCloseAll );

  -- CQUI
  LuaEvents.PartialScreenHooks_AddHook.Add( OnAddScreenHook );

  -- TESTS
  -----------------------------
  --[[
  local hookInfo1:table = {
    -- ICON TEXTURE
    IconTexture = {
      OffsetX = 0;
      OffsetY = 0;
      Sheet = "MapPins24.dds";
      Color = UI.GetColorValue("COLOR_PLAYER_GOLDENROD")
    };

    -- BUTTON TEXTURE
    BaseTexture = {
      OffsetX = 0;
      OffsetY = 0;
      Sheet = "LaunchBar_Hook_ButtonSmall";

      -- Offset to have when hovering
      HoverOffsetX = 0;
      HoverOffsetY = 40;
    };

    Callback = function() print("Damascus steel!") end;
    Tooltip = "ATTACK!";
  };

  LuaEvents.PartialScreenHooks_AddHook(hookInfo1);
  ]]

  ContextPtr:SetInitHandler(OnInit);
end

Initialize();
