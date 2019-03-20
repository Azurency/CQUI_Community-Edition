-- Copyright 2016-2018, Firaxis Games

include("PopupSupport");


-- ===========================================================================
--  MEMBERS
-- ===========================================================================
local m_kQueuedPopups    :table = {};
local m_kCurrentPopup    :table  = nil;

-- Remolten: CQUI Members (access CQUI settings)
local CQUI_wonderBuiltVisual = true;
local CQUI_wonderBuiltAudio = true;

function CQUI_OnSettingsUpdate()
  CQUI_wonderBuiltVisual = GameConfiguration.GetValue("CQUI_WonderBuiltPopupVisual");
  CQUI_wonderBuiltAudio = GameConfiguration.GetValue("CQUI_WonderBuiltPopupAudio");
end

LuaEvents.CQUI_SettingsUpdate.Add( CQUI_OnSettingsUpdate );
LuaEvents.CQUI_SettingsInitialized.Add( CQUI_OnSettingsUpdate );
-- Remolten: End CQUI Members

-- ===========================================================================
--  FUNCTIONS
-- ===========================================================================


-- ===========================================================================`
--  EVENT
-- ===========================================================================
function OnWonderCompleted( locX:number, locY:number, buildingIndex:number, playerIndex:number, cityId:number, iPercentComplete:number, pillaged:number)

  local localPlayer = Game.GetLocalPlayer();
  if (localPlayer == PlayerTypes.NONE) then
    return;  -- Nobody there to click on it, just exit.
  end

  -- Ignore if wonder isn't for this player.
  if (localPlayer ~= playerIndex ) then
    return;
  end

  -- TEMP (ZBR): Ignore if pause-menu is up; prevents stuck camera bug.
  local uiInGameOptionsMenu:table = ContextPtr:LookUpControl("/InGame/TopOptionsMenu");
  if (uiInGameOptionsMenu and uiInGameOptionsMenu:IsHidden()==false) then
    return;
  end

  local kData:table = nil;

  if (GameInfo.Buildings[buildingIndex].RequiresPlacement and iPercentComplete == 100) then
    local currentBuildingType :string = GameInfo.Buildings[buildingIndex].BuildingType;
    if currentBuildingType ~= nil then

      -- Remolten: Begin CQUI changes (reordered in front of visual code)
      if(GameInfo.Buildings[buildingIndex].QuoteAudio ~= nil and CQUI_wonderBuiltAudio) then
      -- Remolten: End CQUI changes
        UI.PlaySound(GameInfo.Buildings[buildingIndex].QuoteAudio);
      end

      -- Remolten: Begin CQUI changes (just added this if statement and put visual code inside of it)
      if CQUI_wonderBuiltVisual then
      -- Remolten: End CQUI changes

        local kData:table =
        {
          locX = locX,
          locY = locY,
          buildingIndex = buildingIndex,
          currentBuildingType = currentBuildingType
        };

        if not IsLocked() then
          LockPopupSequence( "WonderBuiltPopup", PopupPriority.High );
          ShowPopup( kData );
          LuaEvents.WonderBuiltPopup_Shown();  -- Signal other systems (e.g., bulk hide UI)
        else
          table.insert( m_kQueuedPopups, kData );
        end
      end
    end
  end
end

-- ===========================================================================
function ShowPopup( kData:table )

  if(UI.GetInterfaceMode() ~= InterfaceModeTypes.CINEMATIC) then
    UILens.SaveActiveLens();
    UILens.SetActive("Cinematic");
    UI.SetInterfaceMode(InterfaceModeTypes.CINEMATIC);
  end

  m_kCurrentPopup = kData;

  -- In marketing mode, hide all the UI (temporarly via a timer) but still
  -- play the animation and camera curve.
  if UI.IsInMarketingMode() then
    ContextPtr:SetHide( true );
    Controls.ForceAutoCloseMarketingMode:SetToBeginning();
    Controls.ForceAutoCloseMarketingMode:Play();
    Controls.ForceAutoCloseMarketingMode:RegisterEndCallback( OnClose );
  end

  local locX          :number = m_kCurrentPopup.locX;
  local locY          :number = m_kCurrentPopup.locY;
  local buildingIndex      :number = m_kCurrentPopup.buildingIndex;
  local currentBuildingType  :string = m_kCurrentPopup.currentBuildingType;

  Controls.WonderName:SetText(Locale.ToUpper(Locale.Lookup(GameInfo.Buildings[buildingIndex].Name)));
  Controls.WonderIcon:SetIcon("ICON_"..currentBuildingType);
  Controls.WonderIcon:SetToolTipString(Locale.Lookup(GameInfo.Buildings[buildingIndex].Description));
  if(Locale.Lookup(GameInfo.Buildings[buildingIndex].Quote) ~= nil) then
    Controls.WonderQuote:SetText(Locale.Lookup(GameInfo.Buildings[buildingIndex].Quote));
  else
    UI.DataError("The field 'Quote' has not been initialized for "..GameInfo.Buildings[buildingIndex].BuildingType);
  end

  UI.LookAtPlot(locX, locY);

  Controls.ReplayButton:SetEnabled(UI.GetWorldRenderView() == WorldRenderView.VIEW_3D);
  Controls.ReplayButton:SetHide(not UI.IsWorldRenderViewAvailable(WorldRenderView.VIEW_3D));
end


-- ===========================================================================
function Resize()
  local screenX, screenY:number = UIManager:GetScreenSizeVal()

  Controls.GradientL:SetSizeY(screenY);
  Controls.GradientR:SetSizeY(screenY);
  Controls.GradientT:SetSizeX(screenX);
  Controls.GradientB:SetSizeX(screenX);
  Controls.GradientB2:SetSizeX(screenX);
  Controls.HeaderDropshadow:SetSizeX(screenX);
  Controls.HeaderGrid:SetSizeX(screenX);
end

-- ===========================================================================
--  Closes the immediate popup, will raise more if queued.
-- ===========================================================================
function Close()

  StopSound();

  local isDone:boolean  = true;

  -- Find first entry in table, display that, then remove it from the internal queue
  for i, entry in ipairs(m_kQueuedPopups) do
    ShowPopup(entry);
    table.remove(m_kQueuedPopups, i);
    isDone = false;
    break;
  end

  -- If done, restore engine processing and let the world know.
  if isDone then
    m_kCurrentPopup = nil;
    LuaEvents.WonderBuiltPopup_Closed();  -- Signal other systems (e.g., bulk show UI)
    UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    UILens.RestoreActiveLens();
    UnlockPopupSequence();
  end
end

-- ===========================================================================
function StopSound()
  UI.PlaySound("Stop_Wonder_Tracks");
end

-- ===========================================================================
function OnClose()
  Close();
end

-- ===========================================================================
function OnRestartMovie()
    StopSound()    -- stop the music before beginning another go-round
  Events.RestartWonderMovie();
end

-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end

-- ===========================================================================
--  Input
--  UI Event Handler
-- ===========================================================================
function KeyHandler( key:number )
    if key == Keys.VK_ESCAPE then
    Close();
    return true;
    end
    return false;
end

-- ===========================================================================
function OnInputHandler( pInputStruct:table )
  local uiMsg = pInputStruct:GetMessageType();
  if (uiMsg == KeyEvents.KeyUp) then return KeyHandler( pInputStruct:GetKey() ); end;
  return false;
end

-- ===========================================================================
function OnWorldRenderViewChanged()
  Controls.ReplayButton:SetEnabled(UI.GetWorldRenderView() == WorldRenderView.VIEW_3D);
end

-- ===========================================================================
function Initialize()
  if GameConfiguration.IsAnyMultiplayer() then return; end  -- Do not use if a multiplayer mode.

  ContextPtr:SetInputHandler( OnInputHandler, true );

  Controls.Close:RegisterCallback(Mouse.eLClick, OnClose);
  Controls.ReplayButton:RegisterCallback(Mouse.eLClick, OnRestartMovie);
  Controls.ReplayButton:SetToolTipString(Locale.Lookup("LOC_UI_ENDGAME_REPLAY_MOVIE"));

  Events.WonderCompleted.Add( OnWonderCompleted );
  Events.WorldRenderViewChanged.Add( OnWorldRenderViewChanged );
  Events.SystemUpdateUI.Add( OnUpdateUI );
end
Initialize();