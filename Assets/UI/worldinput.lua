-- ===========================================================================
--  World Input
--  Copyright 2015-2016, Firaxis Games
--
--  Handle input that occurs within the 3D world.
--
--  In-file functions are organized in 3 areas:
--    1) "Operation" functions, occur agnostic of the input device
--    2) "Input State" functions, handle input base on up/down/update/or
--      another state of the input device.
--    3) Event listening, mapping, and pre-processing
--
-- ===========================================================================

include("PopupDialog.lua");
include("civ6common")
-- More interface-specific includes before the initialization

-- ===========================================================================
--  Debug
-- ===========================================================================

local m_isDebuging        :boolean = false; -- Turn on local debug systems

-- ===========================================================================
--  CONSTANTS
-- ===========================================================================


local NORMALIZED_DRAG_THRESHOLD :number = 0.035;      -- How much movement to kick off a drag
local NORMALIZED_DRAG_THRESHOLD_SQR :number = NORMALIZED_DRAG_THRESHOLD*NORMALIZED_DRAG_THRESHOLD;
local MOUSE_SCALAR        :number = 6.0;
local PAN_SPEED         :number = 1;
local ZOOM_SPEED        :number = 0.1;
local DOUBLETAP_THRESHHOLD    :number = 2;


-- ===========================================================================
--  Table of tables of functions for each interface mode & event the mode handles
--  (Must be defined before support functions in includes.)
-- ===========================================================================
InterfaceModeMessageHandler =
{
  [InterfaceModeTypes.DEBUG]        = {},
  [InterfaceModeTypes.SELECTION]      = {},
  [InterfaceModeTypes.MOVE_TO]      = {},
  [InterfaceModeTypes.ROUTE_TO]     = {},
  [InterfaceModeTypes.ATTACK]       = {},
  [InterfaceModeTypes.RANGE_ATTACK]   = {},
  [InterfaceModeTypes.CITY_RANGE_ATTACK]  = {},
  [InterfaceModeTypes.DISTRICT_RANGE_ATTACK] = {},
  [InterfaceModeTypes.AIR_ATTACK]     = {},
  [InterfaceModeTypes.WMD_STRIKE]     = {},
  [InterfaceModeTypes.ICBM_STRIKE]    = {},
  [InterfaceModeTypes.EMBARK]       = {},
  [InterfaceModeTypes.DISEMBARK]      = {},
  [InterfaceModeTypes.DEPLOY]       = {},
  [InterfaceModeTypes.REBASE]       = {},
  [InterfaceModeTypes.BUILDING_PLACEMENT] = {},
  [InterfaceModeTypes.DISTRICT_PLACEMENT] = {},
  [InterfaceModeTypes.MAKE_TRADE_ROUTE] = {},
  [InterfaceModeTypes.TELEPORT_TO_CITY] = {},
  [InterfaceModeTypes.FORM_CORPS]     = {},
  [InterfaceModeTypes.FORM_ARMY]      = {},
  [InterfaceModeTypes.AIRLIFT]      = {},
  [InterfaceModeTypes.COASTAL_RAID]   = {},
  [InterfaceModeTypes.PLACE_MAP_PIN]    = {},
  [InterfaceModeTypes.CITY_MANAGEMENT]  = {},
  [InterfaceModeTypes.WB_SELECT_PLOT]     = {},
  [InterfaceModeTypes.SPY_CHOOSE_MISSION] = {},
  [InterfaceModeTypes.SPY_TRAVEL_TO_CITY] = {},
  [InterfaceModeTypes.NATURAL_WONDER]   = {},
  [InterfaceModeTypes.VIEW_MODAL_LENS]  = {}
}

-- ===========================================================================
--	GLOBALS
-- ===========================================================================
g_isTouchEnabled      = false;
g_isMouseDragging     = false;
g_isMouseDownInWorld  = false;  -- Did mouse-down start here (true), or in some other UI context?
g_targetPlots         = nil;
INTERFACEMODE_ENTER   = "InterfaceModeEnter";
INTERFACEMODE_LEAVE   = "InterfaceModeLeave";

-- ===========================================================================
--  MEMBERS
-- ===========================================================================

local DefaultMessageHandler           :table  = {};
local m_actionHotkeyToggleGrid        :number = Input.GetActionId("ToggleGrid");    --  Hot Key Handling
local m_actionHotkeyOnlinePause       :number = Input.GetActionId("OnlinePause");   --  Hot Key Handling
local m_actionHotkeyToggleYield       :number = Input.GetActionId("ToggleYield");   --  Hot Key Handling
local m_actionHotkeyToggleRes         :number = Input.GetActionId("ToggleResources"); --  Hot Key Handling
local m_actionHotkeyPrevUnit          :number = Input.GetActionId("PrevUnit");    --  Hot Key Handling
local m_actionHotkeyNextUnit          :number = Input.GetActionId("NextUnit");    --  Hot Key Handling
local m_actionHotkeyPrevCity          :number = Input.GetActionId("PrevCity");    --  Hot Key Handling
local m_actionHotkeyNextCity          :number = Input.GetActionId("NextCity");    --  Hot Key Handling
local m_actionHotkeyCapitalCity       :number = Input.GetActionId("CapitalCity"); --  Hot Key Handling
local m_kTouchesDownInWorld           :table  = {};   -- Tracks "down" touches that occurred in this context.
local m_isALTDown                     :boolean= false;
local m_isMouseButtonLDown            :boolean= false;
local m_isMouseButtonMDown            :boolean= false;
local m_isMouseButtonRDown            :boolean= false;
local m_isTouchDragging               :boolean= false;
local m_isTouchZooming                :boolean= false;
local m_isTouchPathing                :boolean= false;
local m_isDoubleTapping               :boolean= false;
local m_touchCount                    :number = 0;    -- # of touches currently occuring
local m_touchStartPlotX               :number = -1;
local m_touchStartPlotY               :number = -1;
local m_touchTotalNum                 :number = 0;    -- # of multiple touches that occurred
local m_mapZoomStart                  :number = 0;
local m_dragStartWorldX               :number = 0;
local m_dragStartWorldY               :number = 0;
local m_dragStartFocusWorldX          :number = 0;
local m_dragStartFocusWorldY          :number = 0;
local m_dragStartX                    :number = 0;    -- Mouse or virtual mouse (of average touch points) X
local m_dragStartY                    :number = 0;    -- Mouse or virtual mouse (of average touch points) Y
local m_dragX                         :number = 0;
local m_dragY                         :number = 0;
local m_edgePanX                      :number = 0;
local m_edgePanY                      :number = 0;
local m_constrainToPlotID             :number = 0;
local ms_bGridOn                      :boolean= true;
local m_isMapDragDisabled             :boolean = false;
local m_isCancelDisabled              :boolean = false; -- Is a cancelable action (e.g., right-click for district placement) been disabled?
local m_debugTrace                    :table = {};    -- debug
local m_cachedPathUnit                :table;
local m_cachedPathPlotId              :number;
local m_previousTurnsCount            :number = 0;
local m_kConfirmWarDialog             :table;
local m_focusedTargetPlot             :number = -1;
local m_WBMouseOverPlot               :number = -1;
local m_kTutorialPermittedHexes       :table = nil;   -- Which hexes are permitted for selection by the tutorial (nil if disabled)
local m_kTutorialUnitHexRestrictions  :table = nil;   -- Any restrictions on where units can move.  (Key=UnitType, Value={restricted plotIds})
local m_isPlotFlaggedRestricted       :boolean = false; -- In a previous operation to determine a move path, was a plot flagged restrticted/bad? (likely due to the tutorial system)
local m_kTutorialUnitMoveRestrictions :table = nil;   -- Restrictions for moving (anywhere) of a selected unit type.
local m_isPauseMenuOpen               :boolean = false;

--CQUI MEMBERS
local CQUI_cityview = false;
local CQUI_hotkeyMode = 1; -- 0: V-Style with enhancements 1: V-Style 2: No changes
local CQUI_isShiftDown :boolean = false;

function CQUI_OnSettingsUpdate()
  CQUI_hotkeyMode = GameConfiguration.GetValue("CQUI_BindingsMode");
end

LuaEvents.CQUI_SettingsUpdate.Add( CQUI_OnSettingsUpdate );
LuaEvents.CQUI_SettingsInitialized.Add( CQUI_OnSettingsUpdate );
-- ===========================================================================
--  FUNCTIONS
-- ===========================================================================


-- ===========================================================================
--  DEBUG:
--  trace(msg)  Add a trace message to be output later (to prevent stalling
--        game while looking at per-frame input).
--  dump()    Send to output all the collected traces
--  clear()   Empties trace buffer
-- ===========================================================================
function trace( msg:string )  m_debugTrace[table.count(m_debugTrace)+1] = msg;  end
function dump()         print("DebugTrace: "..table.concat(m_debugTrace));  end
function clear()        m_debugTrace = {};                  end



-- .,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,
--
--                    OPERATIONS
--
-- .,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,


-- ===========================================================================
--  Empty function (to override default)
-- ===========================================================================
function OnDoNothing()
end


-- ===========================================================================
--  Pan camera
-- ===========================================================================
function ProcessPan( panX :number, panY :number )

  if( panY == 0.0 ) then
    if( m_isUPpressed ) then panY = panY + PAN_SPEED; end
    if( m_isDOWNpressed) then panY = panY - PAN_SPEED; end
  end

  if( panX == 0.0 ) then
    if( m_isRIGHTpressed ) then panX = panX + PAN_SPEED; end
    if( m_isLEFTpressed ) then panX = panX - PAN_SPEED; end
  end

  UI.PanMap( panX, panY );
end


-- ===========================================================================
--  Have world camera focus on a plot
--  plotId, the plot # to look at
-- ===========================================================================
function SnapToPlot( plotId:number )
  if (Map.IsPlot(plotId)) then
    local plot = Map.GetPlotByIndex(plotId);
    UI.LookAtPlot( plot );
  end
end

-- ===========================================================================
function IsCancelAllowed()
  return (not m_isCancelDisabled);
end

-- ===========================================================================
--  Perform a camera zoom based on the native 2-finger gesture
-- ===========================================================================
function RealizeTouchGestureZoom()
  if TouchManager:IsInGesture(Gestures.Stretching) then
    local fDistance:number = TouchManager:GetGestureDistance(Gestures.Stretching);
    local normalizedX   :number, normalizedY:number = UIManager:GetNormalizedMousePos();

    -- If zooming just started, get the starting zoom level.
    if not m_isTouchZooming then
      m_mapZoomStart = UI.GetMapZoom();
      m_isTouchZooming = true;
    end

    local fZoomDelta:number = - (fDistance * 0.5);
    local fZoom:number = m_mapZoomStart + fZoomDelta;   -- Adjust the zoom level.  This speed scalar should be put into the UI configuration.

    if( fZoomDelta < 0.0 ) then
      --UI.SetMapZoom( fZoom, normalizedX, normalizedY );
      UI.SetMapZoom( fZoom, 0.0, 0.0 );
    else
      --UI.SetMapZoom( fZoom, normalizedX, normalizedY );
      UI.SetMapZoom( fZoom, 0.0, 0.0 );
    end

    --LuaEvents.WorldInput_TouchPlotTooltipHide();  -- Once this gestures starts, stop and plot tooltip
  else
    m_isTouchZooming = false;
  end
end

-- ===========================================================================
function GetCurrentlySelectUnitIndex( unitList:table, ePlayer:number )
  local iSelectedUnit :number = -1; -- Which unit index is selected.  This is the unit index for the player's units, not all the units in the list
  local iCount    :number = 0;  -- # of units in the list owned by the player
  for i, pUnit in ipairs(unitList) do
    -- Owned by the local player?
    if (pUnit:GetOwner() == ePlayer) then
      -- Already selected?
      if UI.IsUnitSelected(pUnit) then
        iSelectedUnit = iCount;
      end
      iCount = iCount + 1;
    end
  end

  return iSelectedUnit;
end

-- ===========================================================================
function SelectNextUnit(unitList:table, iCurrentlySelectedUnit:number, ePlayer:number, bWrap:boolean)
  if iCurrentlySelectedUnit == -1 then
    -- Nothing selected yet
    for i, pUnit in ipairs(unitList) do
      -- Owned by the player?
      if (pUnit:GetOwner() == ePlayer) then
        SelectUnit(pUnit);
      end
    end
  else
    local bSelected = false;
    local iCount = 0; -- number of units in the list owned by the player
    for i, pUnit in ipairs(unitList) do
      -- Owned by the player?
      if (pUnit:GetOwner() == ePlayer) then
        if (iCount > iCurrentlySelectedUnit) then
          SelectUnit(pUnit);
          bSelected = true;
          break;
        end
        iCount = iCount + 1;
      end
    end

    if not bSelected and bWrap then
      -- Either the input was wrong or we wrapped, go back and select the first one.
      for i, pUnit in ipairs(unitList) do
        -- Owned by the player?
        if (pUnit:GetOwner() == ePlayer) then
          SelectUnit(pUnit);
          break;
        end
      end
    end
  end
end

-- ===========================================================================
--  Selects a unit but firsts deselect any current unit, thereby forcing
--  a cache refresh.
-- ===========================================================================
function SelectUnit( kUnit:table )
  UI.DeselectUnit(kUnit);
  UI.SelectUnit(kUnit);
end

-- ===========================================================================
--  Returns if a specific plot is allowed to be selected.
--  This is generally always true except when the tutorial is running to lock
--  down some (or all) of the plots.
-- ===========================================================================
function IsSelectionAllowedAt( plotId:number )
  if m_kTutorialPermittedHexes == nil then return true; end
  for i,allowedId:number in ipairs( m_kTutorialPermittedHexes ) do
    if allowedId == plotId then
      return true;
    end
  end
  return false;
end

-- ===========================================================================
--  Selects the unit or city at the plot passed in.
-- ===========================================================================
function SelectInPlot( plotX:number, plotY:number )

  local kUnitList   :table  = Units.GetUnitsInPlotLayerID( plotX, plotY, MapLayers.ANY );
  local tryCity   :boolean= false;
  local eLocalPlayer  :number = Game.GetLocalPlayer();
  local pCity     :table = Cities.GetCityInPlot( plotX, plotY );
  if pCity ~= nil then
    if (pCity:GetOwner() ~= eLocalPlayer) then
      pCity = nil;
    end
  end

  -- If there are units to try selecting...
  if table.count(kUnitList) ~= 0 then
    -- Get any currently selected unit so we can cycle to the next.
    local iSelected:number = GetCurrentlySelectUnitIndex(kUnitList, eLocalPlayer);

    -- Cycle to the next, or select the first one if nothing was selected and there is no city
    SelectNextUnit(kUnitList, iSelected, eLocalPlayer, pCity == nil);

    local iNewSelected = GetCurrentlySelectUnitIndex(kUnitList, eLocalPlayer);
    if (iNewSelected == -1 or (iNewSelected == iSelected and pCity ~= nil)) then
      -- No valid units to select
      UI.DeselectAllUnits();
      tryCity = true;
    else
      if (iNewSelected ~= -1 and iNewSelected ~= iSelected) then
        local pNewSelectedUnit = UI.GetHeadSelectedUnit();
        if (pNewSelectedUnit ~= nil and UI.RebuildSelectionList ~= nil) then    -- Checking UI.RebuildSelectionList, so that if an artist fetches the scripts before the next build, they won't be stuck.  Remove that check ASAP.
          -- The user has manually selected a unit, rebuild the selection list from that unit.
          UI.RebuildSelectionList(pNewSelectedUnit);
        end
      end
    end
  else
    UI.DeselectAllUnits();
    tryCity = true;
  end

  if tryCity then
    if pCity ~= nil then
      UI.SelectCity(pCity);
    end
    -- No else, as this would be the case when click on a city banner,
    -- and so the CityBannerManager will handle the selection.
  end

  return true;
end

-- ===========================================================================
--  Has the player moved a down mouse or touch enough that a drag should be
--  considered?
--  RETURNS: true if a drag is occurring.
-- ===========================================================================
function IsDragThreshholdMet()
  local normalizedX:number, normalizedY:number = UIManager:GetNormalizedMousePos();

  local diffX:number = normalizedX - m_dragStartX;
  local diffY:number = normalizedY - m_dragStartY;

  return ( diffX*diffX + diffY*diffY) > NORMALIZED_DRAG_THRESHOLD_SQR;
end

-- ===========================================================================
--  Setup to start dragging the map.
-- ===========================================================================
function ReadyForDragMap()
  m_dragStartX, m_dragStartY            = UIManager:GetNormalizedMousePos();
  m_dragStartFocusWorldX, m_dragStartFocusWorldY  = UI.GetMapLookAtWorldTarget();
  m_dragStartWorldX, m_dragStartWorldY      = UI.GetWorldFromNormalizedScreenPos_NoWrap( m_dragStartX, m_dragStartY );
  m_dragX = m_dragStartX;
  m_dragY = m_dragStartY;
  LuaEvents.WorldInput_DragMapBegin();
end

function StartDragMap()

  --Don't override m_dragStartX/Y because it is used in rotation, and we ony
  local dragStartX:number, dragStartY:number = UIManager:GetNormalizedMousePos();
  m_dragStartFocusWorldX, m_dragStartFocusWorldY  = UI.GetMapLookAtWorldTarget();
  m_dragStartWorldX, m_dragStartWorldY      = UI.GetWorldFromNormalizedScreenPos_NoWrap( dragStartX, dragStartY );
  m_dragX = dragStartX;
  m_dragY = dragStartY;
end

-- ===========================================================================
--  Drag (or spin) the camera based new position
-- ===========================================================================
function UpdateDragMap()

  -- Obtain either the actual mouse position, or for touch, the virtualized
  -- mouse position based on the "average" of all touches:
  local x:number, y:number= UIManager:GetNormalizedMousePos();
  local dx:number     = m_dragX - x;
  local dy:number     = m_dragY - y;

  -- Early out if no change:
  -- Need m_drag... checks or snap to 0,0 can occur.
  if (dx==0 and dy==0) or (m_dragStartWorldX==0 and m_dragStartFocusWorldX==0) then
    return;
  end
  if m_isMapDragDisabled then
    return;
  end

  if m_isALTDown then
    UI.SpinMap( m_dragStartX - x, m_dragStartY - y  );
  else
    UI.DragMap( x, y, m_dragStartWorldX, m_dragStartWorldY, m_dragStartFocusWorldX, m_dragStartFocusWorldY );
  end

  m_dragX = x;
  m_dragY = y;
end

-- ===========================================================================
--  Reset drag variables for next go around.
-- ===========================================================================
function EndDragMap()
  UI.SpinMap( 0.0, 0.0 );

  LuaEvents.WorldInput_DragMapEnd();
  m_dragX       = 0;
  m_dragY       = 0;
  m_dragStartX    = 0;
  m_dragStartY    = 0;
  m_dragStartFocusWorldX = 0;
  m_dragStartFocusWorldY = 0;
  m_dragStartWorldX = 0;
  m_dragStartWorldY = 0;
end


-- ===========================================================================
--  True if a given unit type is allowed to move to a plot.
-- ===========================================================================
function IsUnitTypeAllowedToMoveToPlot( unitType:string, plotId:number )
  if m_kTutorialUnitHexRestrictions == nil then return true; end
  if m_kTutorialUnitHexRestrictions[unitType] ~= nil then
    for _,restrictedPlotId:number in ipairs(m_kTutorialUnitHexRestrictions[unitType]) do
      if plotId == restrictedPlotId then
        return false; -- Found in restricted list, nope, permission denied to move.
      end
    end
  end
  return true;
end

-- ===========================================================================
--  Returns true if a unit can move to a particular plot.
--  This is after the pathfinder may have returned that it's okay, but another
--  system (such as the tutorial) has locked it down.
-- ===========================================================================
function IsUnitAllowedToMoveToCursorPlot( pUnit:table )
  local unitType	:string = GameInfo.Units[pUnit:GetUnitType()].UnitType;
  local plotId	:number = UI.GetCursorPlotID();

  -- Units cannot move to the plot they are already on
  local unitPlot :number = Map.GetPlot(pUnit:GetX(),pUnit:GetY()):GetIndex();
  if unitPlot == plotId then
    return false;
  end
  if m_kTutorialUnitHexRestrictions == nil then return true; end
  if m_isPlotFlaggedRestricted then return false; end -- Previous call to check path showed player ending on hex that was restricted.

  return (not m_isPlotFlaggedRestricted) and IsUnitTypeAllowedToMoveToPlot( unitType, plotId );
end

-- ===========================================================================
--  RETURNS true if the plot is considered a bad move for a unit.
--      Also returns the plotId (if bad)
-- ===========================================================================
function IsPlotPathRestrictedForUnit( kPlotPath:table, kTurnsList:table, pUnit:table )
  local endPlotId:number = kPlotPath[table.count(kPlotPath)];
  if m_constrainToPlotID ~= 0 and endPlotId ~= m_constrainToPlotID then
    return true, m_constrainToPlotID;
  end

  local unitType:string = GameInfo.Units[pUnit:GetUnitType()].UnitType;

  -- Is the unit type just not allowed to be moved at all.
  if m_kTutorialUnitMoveRestrictions ~= nil and m_kTutorialUnitMoveRestrictions[unitType] ~= nil then
    return true, -1;
  end

  -- Is path traveling through a restricted plot?
  -- Ignore the first plot, as a unit may be on a restricted plot and the
  -- goal is just to get it off of it (and never come back.)
  if m_kTutorialUnitHexRestrictions ~= nil then
    if m_kTutorialUnitHexRestrictions[unitType] ~= nil then
      local lastTurn      :number = 1;
      local lastRestrictedPlot:number = -1;
      for i,plotId in ipairs(kPlotPath) do
        -- Past the first plot
        if i > 1 then
          if kTurnsList[i] == lastTurn then
            lastRestrictedPlot = -1;    -- Same turn?  Reset and previously found restricitions (unit is passing through)
            if (not IsUnitTypeAllowedToMoveToPlot( unitType, plotId )) then
              lastTurn = kTurnsList[i];
              lastRestrictedPlot = plotId;
            end
          else
            if lastRestrictedPlot ~= -1 then
              return true, lastRestrictedPlot;
            end
            if (not IsUnitTypeAllowedToMoveToPlot( unitType, plotId )) then
              lastTurn = kTurnsList[i];
              lastRestrictedPlot = plotId;
            end
          end
        end
      end
      if lastRestrictedPlot ~= -1 then
        return true, lastRestrictedPlot;
      end
    end
  end

  m_isPlotFlaggedRestricted = false;
  return false;
end


-- ===========================================================================
--  LUA Event
--  Add plot(s) to the restriction list; units of a certain type may not
--  move to there.
-- ===========================================================================
function OnTutorial_AddUnitHexRestriction( unitType:string, kPlotIds:table )
  if m_kTutorialUnitHexRestrictions == nil then
    m_kTutorialUnitHexRestrictions = {};
  end
  if m_kTutorialUnitHexRestrictions[unitType] == nil then
    m_kTutorialUnitHexRestrictions[unitType] = {};
  end
  for _,plotId:number in ipairs(kPlotIds) do
    table.insert(m_kTutorialUnitHexRestrictions[unitType], plotId );
  end
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnTutorial_RemoveUnitHexRestriction( unitType:string, kPlotIds:table )
  if m_kTutorialUnitHexRestrictions == nil then
    UI.DataError("Cannot RemoveUnitHexRestriction( "..unitType.." ...) as no restrictions are set.");
    return;
  end
  if m_kTutorialUnitHexRestrictions[unitType] == nil then
    UI.DataError("Cannot RemoveUnitHexRestriction( "..unitType.." ...) as a restriction for that unit type is not set.");
    return;
  end

  -- Remove all the items in the restriction list based on what was passed in.
  for _,plotId in ipairs( kPlotIds ) do
    local isRemoved:boolean = false;
    for i=#m_kTutorialUnitHexRestrictions[unitType],1,-1 do
      if m_kTutorialUnitHexRestrictions[unitType][i] == plotId then
        table.remove( m_kTutorialUnitHexRestrictions[unitType], i);
        isRemoved = true;
        break;
      end
    end
    if (not isRemoved) then
      UI.DataError("Cannot remove restriction for the plot "..tostring(plotId)..", it wasn't found in the list for unit "..unitType);
    end
  end
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnTutorial_ClearAllUnitHexRestrictions()
  m_kTutorialUnitHexRestrictions = nil;
end


-- ===========================================================================
--  LUA Event
--  Prevent a unit type from being selected.
-- ===========================================================================
function OnTutorial_AddUnitMoveRestriction( unitType:string )
  if m_kTutorialUnitMoveRestrictions == nil then
    m_kTutorialUnitMoveRestrictions = {};
  end
  if m_kTutorialUnitMoveRestrictions[unitType] then
    UI.DataError("Setting tutorial WorldInput unit selection for '"..unitType.."' but it's already set to restricted!");
  end

  m_kTutorialUnitMoveRestrictions[unitType] = true;
end


-- ===========================================================================
--  LUA Event
--  optionalUnitType  The unit to remove from the restriction list or nil
--            to completely clear the list.
-- ===========================================================================
function OnTutorial_RemoveUnitMoveRestrictions( optionalUnitType:string )
  -- No arg, clear all...
  if optionalUnitType == nil then
    m_kTutorialUnitMoveRestrictions = nil;
  else
    -- Clear a specific type from restriction list.
    if m_kTutorialUnitMoveRestrictions[optionalUnitType] == nil then
      UI.DataError("Tutorial did not reset WorldInput selection for the unit type '"..optionalUnitType.."' since it's not in the restriction list.");
    end
    m_kTutorialUnitMoveRestrictions[optionalUnitType] = nil;
  end
end


-- ===========================================================================
-- Perform a movement path operation (if there is a selected unit).
-- ===========================================================================
function MoveUnitToCursorPlot( pUnit:table )

  -- Clear any paths set for moving the unit and ensure any raised lens
  -- due to the selection, is turned off.
  ClearMovementPath();
  UILens.SetActive("Default");

  local plotID:number = UI.GetCursorPlotID();
  if (not Map.IsPlot(plotID)) then
    return;
  end

  if (m_constrainToPlotID == 0 or plotID == m_constrainToPlotID) and not GameInfo.Units[pUnit:GetUnitType()].IgnoreMoves then
    local plotX:number, plotY:number = UI.GetCursorPlotCoord();
      if m_previousTurnsCount >= 1 then
        UI.PlaySound("UI_Move_Confirm");
      end
    MoveUnitToPlot( pUnit, plotX, plotY );
  end
end

-- ===========================================================================
function UnitMovementCancel()
  ClearMovementPath();
  UILens.SetActive("Default");

  -- If we have a unit selected with queued movement display that path
  if (not UI.IsGameCoreBusy()) then
    local pSelectedUnit :table = UI.GetHeadSelectedUnit();
    if pSelectedUnit then
      local endPlotId = UnitManager.GetQueuedDestination( pSelectedUnit );
      if endPlotId then
        RealizeMovementPath(true);
      end
    end
  end
end

-- ===========================================================================
--  Unit Range Attack
-- ===========================================================================
function UnitRangeAttack( plotID:number )
  local plot        :table        = Map.GetPlotByIndex(plotID);
  local tParameters :table        = {};
  tParameters[UnitOperationTypes.PARAM_X] = plot:GetX();
  tParameters[UnitOperationTypes.PARAM_Y] = plot:GetY();

  local pSelectedUnit :table = UI.GetHeadSelectedUnit();
  if pSelectedUnit == nil then
    UI.DataError("A UnitRangeAttack( "..tostring(plotID).." ) was attempted but there is no selected unit.");
    return;
  end

  if UnitManager.CanStartOperation( pSelectedUnit, UnitOperationTypes.RANGE_ATTACK, nil, tParameters) then
    UnitManager.RequestOperation( pSelectedUnit, UnitOperationTypes.RANGE_ATTACK, tParameters);
  else
    -- LClicking on an empty hex, deselect unit.
    UI.DeselectUnit( pSelectedUnit );
  end
  -- Always leave ranged attack mode after interaction.
  UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
end

-- ===========================================================================
--  Clear the visual representation (and cache) of the movement path
-- ===========================================================================
function ClearMovementPath()
  UILens.ClearLayerHexes( LensLayers.MOVEMENT_PATH );
  UILens.ClearLayerHexes( LensLayers.NUMBERS );
  if (UI.GetInterfaceMode() ~= InterfaceModeTypes.CITY_RANGE_ATTACK) then
    UILens.ClearLayerHexes( LensLayers.ATTACK_RANGE );
  end
  m_cachedPathUnit = nil;
  m_cachedPathPlotId = -1;
end

-- ===========================================================================
function ClearRangeAttackDragging()
  local bWasDragging:boolean = g_isMouseDragging;
  OnMouseEnd( pInputStruct );
  return bWasDragging;
end

-- ===========================================================================
--  Update the 3D displayed path for a unit.
-- ===========================================================================
-- AZURENCY : added unitID to use this function on hover in unitflagmanager
function RealizeMovementPath(showQueuedPath:boolean, unitID:number)

  if not UI.IsMovementPathOn() or UI.IsGameCoreBusy() then
    return;
  end

  -- Bail if no selected unit.
  local kUnit :table = nil;
  if unitID then
    kUnit = Players[Game.GetLocalPlayer()]:GetUnits():FindID(unitID);
  else
    kUnit = UI.GetHeadSelectedUnit();
  end
  if kUnit == nil then
    UILens.SetActive("Default");
    m_cachedPathUnit = nil;
    m_cachedPathPlotId = -1;
    return;
  end

  -- Bail if unit is not a type that allows movement.
  if GameInfo.Units[kUnit:GetUnitType()].IgnoreMoves then
    return;
  end

  -- Bail if end plot is not determined.
  local endPlotId :number = UI.GetCursorPlotID();

  -- Use the queued destinationt o show the queued path
  if (showQueuedPath) then
    local queuedEndPlotId:number = UnitManager.GetQueuedDestination( kUnit );
    if queuedEndPlotId then
      endPlotId = queuedEndPlotId;
    elseif unitID then -- AZURENCY : bail if the unit have no endplot and we wanted to draw its path
      return;
    end
  end

  -- Ensure this is a proper plot ID
  if (not Map.IsPlot(endPlotId)) then
    return;
  end

  -- Only update if a new unit or new plot from the previous update.
  if m_cachedPathUnit ~= kUnit or m_cachedPathPlotId  ~= endPlotId then
    UILens.ClearLayerHexes( LensLayers.MOVEMENT_PATH );
    UILens.ClearLayerHexes( LensLayers.NUMBERS );
    UILens.ClearLayerHexes( LensLayers.ATTACK_RANGE );
    if m_cachedPathPlotId ~= -1 then
      UILens.UnFocusHex( LensLayers.ATTACK_RANGE, m_cachedPathPlotId );
    end

    m_cachedPathUnit  = kUnit;
    m_cachedPathPlotId  = endPlotId;


    -- Obtain ordered list of plots.
    local turnsList   : table;
    local obstacles   : table;
    local variations  : table = {}; -- 2 to 3 values
    local pathPlots   : table = {};
    local eLocalPlayer  : number = Game.GetLocalPlayer();

    --check for unit position swap first
    local startPlotId :number = Map.GetPlot(kUnit:GetX(),kUnit:GetY()):GetIndex();
    if startPlotId ~= endPlotId then
      local plot      :table        = Map.GetPlotByIndex(endPlotId);
      local tParameters :table        = {};
      tParameters[UnitOperationTypes.PARAM_X] = plot:GetX();
      tParameters[UnitOperationTypes.PARAM_Y] = plot:GetY();
      if ( UnitManager.CanStartOperation( kUnit, UnitOperationTypes.SWAP_UNITS, nil, tParameters) ) then
        lensNameBase = "MovementGood";
        if not UILens.IsLensActive(lensNameBase) then
          UILens.SetActive(lensNameBase);
        end
        table.insert(pathPlots, startPlotId);
        table.insert(pathPlots, endPlotId);
        table.insert(variations, {lensNameBase.."_Destination",startPlotId} );
        table.insert(variations, {lensNameBase.."_Counter", startPlotId} ); -- show counter pip
        UI.AddNumberToPath( 1, startPlotId);
        table.insert(variations, {lensNameBase.."_Destination",endPlotId} );
        table.insert(variations, {lensNameBase.."_Counter", endPlotId} ); -- show counter pip
        UI.AddNumberToPath( 1, endPlotId);
        UILens.SetLayerHexesPath(LensLayers.MOVEMENT_PATH, eLocalPlayer, pathPlots, variations);
        return;
      end
    end

    pathPlots, turnsList, obstacles = UnitManager.GetMoveToPath( kUnit, endPlotId );

    if table.count(pathPlots) > 1 then
      -- Start and end art "variations" when drawing path
      local startHexId:number = kUnit:GetPlotId();
      local endHexId  :number = pathPlots[table.count(pathPlots)];

      -- Check if our desired "movement" is actually a ranged attack. Early out if so.
      local isImplicitRangedAttack :boolean = false;

      local pResults = UnitManager.GetOperationTargets(kUnit, UnitOperationTypes.RANGE_ATTACK );
      local pAllPlots = pResults[UnitOperationResults.PLOTS];
      if pAllPlots ~= nil then
        for i, modifier in ipairs( pResults[UnitOperationResults.MODIFIERS] ) do
          if modifier == UnitOperationResults.MODIFIER_IS_TARGET then
            if pAllPlots[i] == endPlotId then
              isImplicitRangedAttack = true;
              break;
            end
          end
        end
      end

      if isImplicitRangedAttack then
        -- Unit can apparently perform a ranged attack on that hex. Show the arrow!
        local kVariations:table = {};
        local kEmpty:table = {};
        table.insert(kVariations, {"EmptyVariant", startHexId, endHexId} );
        UILens.SetLayerHexesArea(LensLayers.ATTACK_RANGE, eLocalPlayer, kEmpty, kVariations);

        -- Focus must be called AFTER the attack range variants are set.
        UILens.FocusHex( LensLayers.ATTACK_RANGE, endHexId );
        return; -- We're done here. Do not show a movement path.
      end

      -- Any plots of path in Fog Of War or midfog?
      local isPathInFog:boolean = false;
      local pPlayerVis :table = PlayersVisibility[eLocalPlayer];
      if pPlayerVis ~= nil then
        for _,plotIds in pairs(pathPlots) do
          isPathInFog = not pPlayerVis:IsVisible(plotIds);
          if isPathInFog then
            break;
          end
        end
      end

      -- If any plots are in Fog Of War (FOW) then switch to the FOW movement lens.
      local lensNameBase              :string = "MovementGood";
      local movePostfix             :string = "";
      local isPathHaveRestriction,restrictedPlotId = IsPlotPathRestrictedForUnit( pathPlots, turnsList, kUnit );

      if showQueuedPath then
        lensNameBase = "MovementQueue";
      elseif isPathHaveRestriction then
        lensNameBase = "MovementBad";
        m_isPlotFlaggedRestricted = true;
        if restrictedPlotId ~= nil and restrictedPlotId ~= -1 then
          table.insert(variations, {"MovementBad_Destination", restrictedPlotId} );
        end
      elseif isPathInFog then
        lensNameBase = "MovementFOW";
        movePostfix = "_FOW";
      end
      -- Turn on lens.
      if not UILens.IsLensActive(lensNameBase) then
        UILens.SetActive(lensNameBase);
      end

      -- is there an enemy unit at the end?
      local bIsEnemyAtEnd:boolean = false;
      local endPlot :table  = Map.GetPlotByIndex(endPlotId);
      if( endPlot ~= nil ) then
        local unitList  = Units.GetUnitsInPlotLayerID( endPlot:GetX(), endPlot:GetY(), MapLayers.ANY );
        for i, pUnit in ipairs(unitList) do
          if( eLocalPlayer ~= pUnit:GetOwner() and pPlayerVis ~= nil and pPlayerVis:IsVisible(endPlot:GetX(), endPlot:GetY()) and pPlayerVis:IsUnitVisible(pUnit) ) then
            bIsEnemyAtEnd = true;
          end
        end
      end

      -- Hide the destination indicator only if the attack is guaranteed this turn.
      -- Regular movements and attacks planned for later turns still get the indicator.
      if not showQueuedPath then
        table.insert(variations, {lensNameBase.."_Origin",startHexId} );
      end
      local nTurnCount :number = turnsList[table.count( turnsList )];
      if not bIsEnemyAtEnd or nTurnCount > 1 then
        table.insert(variations, {lensNameBase.."_Destination",endHexId} );
      end

      -- Since turnsList are matched against plots, this should be the same # as above.
      if table.count(turnsList) > 1 then

        -- Track any "holes" in the path.
        local pathHole:table = {};
        for i=1,table.count(pathPlots),1 do
          pathHole[i] = true;
        end

        local lastTurn:number = 1;
        for i,value in pairs(turnsList) do

          -- If a new turn entry exists, or it's the very last entry of the path... show turn INFO.
          if value > lastTurn then
            if i > 1 then
              table.insert(variations, {lensNameBase.."_Counter", pathPlots[i-1]} );                -- show counter pip
              UI.AddNumberToPath( lastTurn, pathPlots[i-1] );
              pathHole[i-1]=false;
            end
            lastTurn = value;
          end
          if i == table.count(turnsList) and i > 1 then
            table.insert(variations, {lensNameBase.."_Counter", pathPlots[i]} );                -- show counter pip
            UI.AddNumberToPath( lastTurn, pathPlots[i] );
            if lastTurn == 2 then
              if m_previousTurnsCount == 1 then
                UI.PlaySound("UI_Multi_Turn_Movement_Alert");
              end
            end
            m_previousTurnsCount = lastTurn;
            pathHole[i]=false;
          end
        end

        -- Any obstacles? (e.g., rivers)
        if not showQueuedPath then
        local plotIndex:number = 1;
        for i,value in pairs(obstacles) do
          while( pathPlots[plotIndex] ~= value ) do plotIndex = plotIndex + 1; end  -- Get ID to use for river's next plot
          table.insert(variations, {lensNameBase.."_Minus", value, pathPlots[plotIndex+1]} );
        end
        end

        -- Any variations not filled in earlier (holes), are filled in with Pips
        for i,isHole in pairs(pathHole) do
          if isHole then
            table.insert(variations, {lensNameBase.."_Pip", pathPlots[i]} );    -- non-counter pip
          end
        end
      end

    else
      -- No path; is it a bad path or is the player have the cursor on the same hex as the unit?
      local startPlotId :number = Map.GetPlot(kUnit:GetX(),kUnit:GetY()):GetIndex();
      if startPlotId ~= endPlotId then
        if not UILens.IsLensActive("MovementBad") then
          UILens.SetActive("MovementBad");
          lensNameBase = "MovementBad";
        end
        table.insert(pathPlots, endPlotId);
        table.insert(variations, {"MovementBad_Destination", endPlotId} );
      else
        table.insert(pathPlots, endPlotId);
        table.insert(variations, {"MovementGood_Destination", endPlotId} );
      end
    end

    UILens.SetLayerHexesPath(LensLayers.MOVEMENT_PATH, eLocalPlayer, pathPlots, variations);
  end
end

-- ===========================================================================
--	Game Engine Event
-- ===========================================================================
function OnUnitSelectionChanged( playerID:number, unitID:number, hexI:number, hexJ:number, hexK:number, isSelected:boolean, isEditable:boolean )
  if playerID ~= Game.GetLocalPlayer() then
    return;
  end

  -- Show queued path when unit is selected
  if isSelected and not UI.IsGameCoreBusy() then
    local pSelectedUnit:table = UI.GetHeadSelectedUnit();
    if pSelectedUnit and UnitManager.GetQueuedDestination( pSelectedUnit ) then
      RealizeMovementPath(true);
    end
  else
    -- Make sure to hide any path when deselecting a unit
    ClearMovementPath();
  end
end

-- ===========================================================================
-- ===========================================================================
function CQUI_BuildImprovement (unit, improvementHash: number)
  if unit == nil then return end

  local tParameters = {};
  tParameters[UnitOperationTypes.PARAM_X] = unit:GetX();
  tParameters[UnitOperationTypes.PARAM_Y] = unit:GetY();
  tParameters[UnitOperationTypes.PARAM_IMPROVEMENT_TYPE] = improvementHash;

  UnitManager.RequestOperation( unit, UnitOperationTypes.BUILD_IMPROVEMENT, tParameters );
end

function DefaultKeyDownHandler( uiKey:number )
  local keyPanChanged :boolean = false;

  if uiKey == Keys.VK_ALT then
    if m_isALTDown == false then
      m_isALTDown = true;
      EndDragMap();
      ReadyForDragMap();
    end
  end
  --CQUI Keybinds

  if uiKey == Keys.VK_SHIFT then
    CQUI_isShiftDown = true;
  end


  if CQUI_hotkeyMode ~= 0 then
    if CQUI_hotkeyMode == 2 then
      if( uiKey == Keys.W ) then
        keyPanChanged = true;
        m_isUPpressed = true;
      end
      if( uiKey == Keys.D ) then
        keyPanChanged = true;
        m_isRIGHTpressed = true;
      end
      if( uiKey == Keys.S ) then
        keyPanChanged = true;
        m_isDOWNpressed = true;
      end
      if( uiKey == Keys.A ) then
        keyPanChanged = true;
        m_isLEFTpressed = true;
      end
    end
  end
  if( uiKey == Keys.VK_UP ) then
    keyPanChanged = true;
    m_isUPpressed = true;
  end
  if( uiKey == Keys.VK_RIGHT ) then
    keyPanChanged = true;
    m_isRIGHTpressed = true;
  end
  if( uiKey == Keys.VK_DOWN ) then
    keyPanChanged = true;
    m_isDOWNpressed = true;
  end
  if( uiKey == Keys.VK_LEFT ) then
    keyPanChanged = true;
    m_isLEFTpressed = true;
  end
  if( keyPanChanged == true ) then
    ProcessPan(m_edgePanX,m_edgePanY);
  end
  return false;
end

-- ===========================================================================
-- ===========================================================================
function DefaultKeyUpHandler( uiKey:number )
  local keyPanChanged :boolean = false;

  --print("Key Up: " .. uiKey);
  local selectedUnit = UI.GetHeadSelectedUnit();
  local unitType = nil;
  local formationClass = nil;
  if selectedUnit then
    unitType = GameInfo.Units[selectedUnit:GetUnitType()].UnitType;
    formationClass = GameInfo.Units[selectedUnit:GetUnitType()].FormationClass;
    --print("Unit Type: " .. unitType .. " Formation Class: " .. formationClass);
  end

  --CQUI Keybinds
  if CQUI_hotkeyMode ~= 0 then
    if CQUI_hotkeyMode == 2 then
      if( uiKey == Keys.W ) then
        m_isUPpressed = false;
        keyPanChanged = true;
      end
      if( uiKey == Keys.D ) then
        m_isRIGHTpressed = false;
        keyPanChanged = true;
      end
      if( uiKey == Keys.S ) then
        m_isDOWNpressed = false;
        keyPanChanged = true;
      end
      if( uiKey == Keys.A ) then
        m_isLEFTpressed = false;
        keyPanChanged = true;
      end
      if( uiKey == Keys.E ) then
        if(CQUI_cityview) then
          LuaEvents.CQUI_GoNextCity();
        else
          UI.SelectNextReadyUnit();
        end
      end
      if( uiKey == Keys.Q ) then
        if(CQUI_cityview) then
          LuaEvents.CQUI_GoPrevCity();
        else
          UI.SelectPrevReadyUnit();
        end
      end
      if( uiKey == Keys.VK_SHIFT and ContextPtr:LookUpControl("/InGame/TechTree"):IsHidden() and ContextPtr:LookUpControl("/InGame/CivicsTree"):IsHidden()) then
        if(CQUI_cityview) then
          UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
          UI.SelectNextReadyUnit();
        else
          LuaEvents.CQUI_GoNextCity();
        end
      end
    else --Classic binds that would overlap with the enhanced binds
      if( uiKey == Keys.Q ) then
        if (unitType == "UNIT_BUILDER") then
        CQUI_BuildImprovement(UI.GetHeadSelectedUnit(), -80493497); --Quarry
        end
      end
      if( uiKey == Keys.S ) then
        UnitManager.RequestCommand(UI.GetHeadSelectedUnit(), UnitOperationTypes.AIR_ATTACK);
      end
    end
    -- Fortify until healed hotkey
    if( uiKey == Keys.H ) then
      if (unitType ~= nil) then -- OPTIMIZATION -- if unit health 100% alert not heal
        UnitManager.RequestOperation(UI.GetHeadSelectedUnit(), 2126026491); -- OH MY GOD IT WAS SO HARD TO FIND THAT ID. WHAT WAS FIRAXIS THINKING
      end
      return;
    end
    -- Focus Capital hotkey
    if( uiKey == Keys.VK_HOME ) then
      UI.SelectCity(Players[Game.GetLocalPlayer()]:GetCities():GetCapitalCity());
    end
    if( uiKey == Keys.VK_BACK ) then
      if (unitType ~= nill) then
        UnitManager.RequestCommand(UI.GetHeadSelectedUnit(), UnitCommandTypes.CANCEL);
      end
    end
    if( uiKey == Keys.I ) then
      if (unitType == "UNIT_BUILDER") then
        CQUI_BuildImprovement(UI.GetHeadSelectedUnit(), 168372657); --Farm
      end
    end
    if( uiKey == Keys.P ) then
      if ( CQUI_isShiftDown) then
        CQUI_isShiftDown = false;
        PlaceMapPin();
      else
        if (unitType == "UNIT_BUILDER") then
          CQUI_BuildImprovement(UI.GetHeadSelectedUnit(), 154488225); --Pasture
          CQUI_BuildImprovement(UI.GetHeadSelectedUnit(), 1523996587); --Plantation
        end
      end
    end
    if( uiKey == Keys.N ) then
      if (unitType == "UNIT_BUILDER") then
        CQUI_BuildImprovement(UI.GetHeadSelectedUnit(), 1001859687); --Mine
      else
        UnitManager.RequestOperation(UI.GetHeadSelectedUnit(), UnitOperationTypes.WMD_STRIKE);
      end
    end
    if( uiKey == Keys.H ) then
      if (unitType == "UNIT_BUILDER") then
        CQUI_BuildImprovement(UI.GetHeadSelectedUnit(), -1819558972); --Camp
      end
    end
    if( uiKey == Keys.L ) then
      CQUI_BuildImprovement(UI.GetHeadSelectedUnit(), 2048582848); --Lumber Mill
    end
    if( uiKey == Keys.R ) then
      if (unitType == "UNIT_MILITARY_ENGINEER") then
        CQUI_BuildImprovement(UI.GetHeadSelectedUnit(), 115772143); --Road
      elseif (formationClass == "FORMATION_CLASS_AIR") then
        UnitManager.RequestOperation(UI.GetHeadSelectedUnit(), UnitOperationTypes.REBASE);
      else
        return false;
      end
    end
    if( uiKey == Keys.F ) then
      if (unitType == "UNIT_BUILDER") then
        CQUI_BuildImprovement(UI.GetHeadSelectedUnit(), 578093457); --Fishing Boats
      elseif (unitType == "UNIT_MILITARY_ENGINEER") then
        CQUI_BuildImprovement(UI.GetHeadSelectedUnit(), 1694280827); --Fort
      else
        UnitManager.RequestOperation(UI.GetHeadSelectedUnit(), -744032280); --Sleep
      end
    end
    if( uiKey == Keys.Z ) then
      UnitManager.RequestOperation(UI.GetHeadSelectedUnit(), -41338758); --Sleep
    end
    if( uiKey == Keys.O ) then
      if (unitType == "UNIT_BUILDER") then
        CQUI_BuildImprovement(UI.GetHeadSelectedUnit(), -1355513600); --Oil Well
        CQUI_BuildImprovement(UI.GetHeadSelectedUnit(), -396628467); --Offshore Platform
      end
    end
    if( m_isALTDown ) then --Overridden classic binds get an alt-version as well as the normal alt-shortcuts
      if( uiKey == Keys.C ) then
        if (unitType == "UNIT_BUILDER") or (unitType == "UNIT_MILITARY_ENGINEER") then
          UnitManager.RequestOperation(UI.GetHeadSelectedUnit(), UnitOperationTypes.HARVEST_RESOURCE);
          UnitManager.RequestOperation(UI.GetHeadSelectedUnit(), UnitOperationTypes.REMOVE_FEATURE);
        end
      end
      if( uiKey == Keys.Q ) then
        CQUI_BuildImprovement(UI.GetHeadSelectedUnit(), -80493497); --Quarry
      end
      if( uiKey == Keys.S ) then
        if (formationClass == "FORMATION_CLASS_AIR") then
          UnitManager.RequestCommand(UI.GetHeadSelectedUnit(), UnitOperationTypes.AIR_ATTACK);
        end
      end
    end
  end

  if uiKey == Keys.VK_ALT then
    if m_isALTDown == true then
      m_isALTDown = false;
      EndDragMap();
      ReadyForDragMap();
    end
  end

  if uiKey == Keys.VK_SHIFT then
    CQUI_isShiftDown = false;
  end

  if( uiKey == Keys.VK_UP ) then
    m_isUPpressed = false;
    keyPanChanged = true;
  end
  if( uiKey == Keys.VK_RIGHT ) then
    m_isRIGHTpressed = false;
    keyPanChanged = true;
  end
  if( uiKey == Keys.VK_DOWN ) then
    m_isDOWNpressed = false;
    keyPanChanged = true;
  end
  if( uiKey == Keys.VK_LEFT ) then
    m_isLEFTpressed = false;
    keyPanChanged = true;
  end
  if( keyPanChanged == true ) then
    ProcessPan(m_edgePanX,m_edgePanY);
  end

  if( uiKey == Keys.VK_ADD or uiKey == Keys.VK_SUBTRACT ) then
    local oldZoom = UI.GetMapZoom();
    if( uiKey == Keys.VK_ADD ) then
      UI.SetMapZoom( oldZoom - ZOOM_SPEED, 0.0, 0.0 );
    elseif( uiKey == Keys.VK_SUBTRACT ) then
      UI.SetMapZoom( oldZoom + ZOOM_SPEED, 0.0, 0.0 );
    end
    return true;
  end

  return false;
end


-- .,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,
--
--                    INPUT STATE
--
-- .,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,


-- ===========================================================================
function OnDefaultKeyDown( pInputStruct:table )
  if m_isPauseMenuOpen then return; end
  local uiKey     :number = pInputStruct:GetKey();
  return DefaultKeyDownHandler( uiKey );
end

-- ===========================================================================
function OnDefaultKeyUp( pInputStruct:table )
  if m_isPauseMenuOpen then return; end
  local uiKey     :number = pInputStruct:GetKey();
  return DefaultKeyUpHandler( uiKey );
end

-- ===========================================================================
--  Placing a building, wonder, or district; ESC to leave
-- ===========================================================================
function OnPlacementKeyUp( pInputStruct:table )
  if m_isPauseMenuOpen then return; end
  local uiKey     :number = pInputStruct:GetKey();
  if uiKey == Keys.VK_ESCAPE then
    UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    return true;
  end
  return DefaultKeyUpHandler( uiKey );
end


-- ===========================================================================
function TogglePause()
  local localPlayerID = Network.GetLocalPlayerID();
  local localPlayerConfig = PlayerConfigurations[localPlayerID];
  local newPause = not localPlayerConfig:GetWantsPause();
  localPlayerConfig:SetWantsPause(newPause);
  Network.BroadcastPlayerInfo();
end

-- ===========================================================================
function OnDefaultChangeToSelectionMode( pInputStruct )
  UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
end

-- ===========================================================================
function OnMouseDebugEnd( pInputStruct:table )
  -- If a drag was occurring, end it; otherwise attempt selection of whatever
  -- is in the plot the mouse is currently at.
  if g_isMouseDragging then
    print_debug("Stopping drag");
    g_isMouseDragging = false;

  else
    print_debug("Debug placing!!!");
    local plotID:number = UI.GetCursorPlotID();
    if (Map.IsPlot(plotID)) then
      local edge = UI.GetCursorNearestPlotEdge();
      DebugPlacement( plotID, edge );
    end
  end
  EndDragMap();         -- Reset any dragging
  g_isMouseDownInWorld = false;
  return true;

end

-- ===========================================================================
function OnDebugCancelPlacement( pInputStruct )
  local plotID:number = UI.GetCursorPlotID();
  if (Map.IsPlot(plotID)) then
    local edge = UI.GetCursorNearestPlotEdge();
    local plot:table = Map.GetPlotByIndex(plotID);
    local normalizedX, normalizedY = UIManager:GetNormalizedMousePos();
    worldX, worldY, worldZ = UI.GetWorldFromNormalizedScreenPos(normalizedX, normalizedY);

    -- Communicate this to the TunerMapPanel handler
    LuaEvents.TunerMapRButtonDown(plot:GetX(), plot:GetY(), worldX, worldY, worldZ, edge);
  end
  return true;
end

-- ===========================================================================
function OnInterfaceModeChange_Debug( eNewMode:number )
  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK);
end


-- ===========================================================================
function OnInterfaceModeEnter_CityManagement( eNewMode:number )
  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK);
  -- AZURENCY : fix the Appeal lens not being applied in city view
	--UILens.SetActive("CityManagement");
end

-- ===========================================================================
function OnInterfaceModeLeave_CityManagement( eNewMode:number )
  UIManager:SetUICursor(CursorTypes.NORMAL);
  UILens.SetActive("Default");
end


-- ===========================================================================
function OnMouseSelectionEnd( pInputStruct:table )
  -- If a drag was occurring, end it; otherwise attempt selection of whatever
  -- is in the plot the mouse is currently at.
  if g_isMouseDragging then
    g_isMouseDragging = false;
  else
    -- If something (such as the tutorial) hasn't disabled mouse deslecting.
    if IsSelectionAllowedAt( UI.GetCursorPlotID() ) then
      local plotX:number, plotY:number = UI.GetCursorPlotCoord();
      SelectInPlot( plotX, plotY );
    end
  end
  EndDragMap();         -- Reset any dragging
  g_isMouseDownInWorld = false;
  return true;
end

-- ===========================================================================
function OnMouseSelectionMove( pInputStruct:table )

  if not g_isMouseDownInWorld then
    return false;
  end

  -- Check for that player who holds the mouse button dwon, drags and releases it over a UI element.
  if g_isMouseDragging then
    UpdateDragMap();
    return true;
  else
    if m_isMouseButtonLDown then
      -- A mouse button is down but isn't currently marked for "dragging",
      -- do some maths to see if this is actually a drag state.
      if not g_isMouseDragging then
        if IsDragThreshholdMet() then
          g_isMouseDragging = true;
          StartDragMap();
        end
      end
    end

    local playerID :number = Game.GetLocalPlayer();
    if playerID == -1 or (not Players[playerID]:IsTurnActive()) then
      return false;
    end

    if m_isMouseButtonRDown then
      RealizeMovementPath();
    end
  end
  return false;
end

-- ===========================================================================
function OnMouseSelectionUnitMoveStart( pInputStruct:table )
  g_isMouseDownInWorld = true;
  RealizeMovementPath();
  return true;
end

-- ===========================================================================
function OnMouseSelectionUnitMoveEnd( pInputStruct:table )
  local pSelectedUnit:table = UI.GetHeadSelectedUnit();
  if pSelectedUnit ~= nil then
    local playerID :number = Game.GetLocalPlayer();
    if playerID ~= -1 and Players[playerID]:IsTurnActive() then
      if IsUnitAllowedToMoveToCursorPlot( pSelectedUnit ) then
        MoveUnitToCursorPlot( pSelectedUnit );
      else
        UnitMovementCancel();
      end
    end
  else
    UnitMovementCancel();
  end
  g_isMouseDownInWorld = false;
  return true;
end

-- ===========================================================================
function OnMouseSelectionSnapToPlot( pInputStruct:table )
  local plotId :number= UI.GetCursorPlotID();
  SnapToPlot( plotId );
end

-- ===========================================================================
function OnMouseMove( pInputStruct:table )

  if not g_isMouseDownInWorld then
    return false;
  end

  -- Check for that player who holds the mouse button dwon, drags and releases it over a UI element.
  if g_isMouseDragging then
    UpdateDragMap();
    return true;
  else
    if m_isMouseButtonLDown then
      -- A mouse button is down but isn't currently marked for "dragging".
      if not g_isMouseDragging then
        if IsDragThreshholdMet() then
          g_isMouseDragging = true;
          StartDragMap();
        end
      end
    end
  end
  return false;
end


-- ===========================================================================
--  Common way for mouse to function with a press start.
-- ===========================================================================
function OnMouseStart( pInputStruct:table )
  ReadyForDragMap();
  g_isMouseDownInWorld = true;
  return true;
end

-- ===========================================================================
function OnMouseEnd( pInputStruct:table )
  -- If a drag was occurring, end it; otherwise attempt selection of whatever
  -- is in the plot the mouse is currently at.
  if g_isMouseDragging then
    g_isMouseDragging = false;
  end
  EndDragMap();         -- Reset any dragging
  g_isMouseDownInWorld = false;
  return true;
end

-- ===========================================================================
--  Zoom
-- ===========================================================================
function OnMouseWheelZoom( pInputStruct:table )
  local wheelValue = pInputStruct:GetWheel() * (-( (1.0/12000.0) * MOUSE_SCALAR));    -- Wheel values come in as multiples of 120, make it so that one 'click' is %1, modified by a speed scalar.
  local normalizedX   :number, normalizedY:number = UIManager:GetNormalizedMousePos();
  local oldZoom = UI.GetMapZoom();
  local newZoom = oldZoom + wheelValue;

  if( wheelValue < 0.0 ) then
    --UI.SetMapZoom( newZoom, normalizedX, normalizedY );
    UI.SetMapZoom( newZoom, 0.0, 0.0 );
  else
    --UI.SetMapZoom( newZoom, normalizedX, normalizedY );
    UI.SetMapZoom( newZoom, 0.0, 0.0 );
  end

  return true;
end

-- ===========================================================================
--  Either Mouse Double-Click or Touch Double-Tap
-- ===========================================================================
function OnSelectionDoubleTap( pInputStruct:table )
  -- Determine if mouse or touch...
  if g_isMouseDownInWorld then
    -- Ignore if mouse.
  else
    local pSelectedUnit:table = UI.GetHeadSelectedUnit();
    if pSelectedUnit ~= nil then
      if IsUnitAllowedToMoveToCursorPlot( pSelectedUnit ) then
        MoveUnitToCursorPlot( pSelectedUnit );
      end
      m_isDoubleTapping = true;
      return true;
    end
  end
  return false;
end

-- ===========================================================================
function OnMouseMakeTradeRouteEnd( pInputStruct:table )
  -- If a drag was occurring, end it; otherwise raise event.
  if g_isMouseDragging then
    g_isMouseDragging = false;
  else
    local plotId:number = UI.GetCursorPlotID();
    if (Map.IsPlot(plotId)) then
      LuaEvents.WorldInput_MakeTradeRouteDestination( plotId );
    end
  end
  EndDragMap();
  g_isMouseDownInWorld = true;
  return true;
end

-- ===========================================================================
function OnMouseMakeTradeRouteSnapToPlot( pInputStruct:table )
  local plotId :number= UI.GetCursorPlotID();
  SnapToPlot( plotId );
end

-- ===========================================================================
function OnMouseTeleportToCityEnd( pInputStruct:table )
  -- If a drag was occurring, end it; otherwise raise event.
  if g_isMouseDragging then
    g_isMouseDragging = false;
  else
    TeleportToCity();
  end
  EndDragMap();
  g_isMouseDownInWorld = true;
  return true;
end

-- ===========================================================================
function OnMouseTeleportToCitySnapToPlot( pInputStruct:table )
  local plotId :number= UI.GetCursorPlotID();
  SnapToPlot( plotId );
end

-- ===========================================================================
function OnMouseBuildingPlacementEnd( pInputStruct:table )
  -- If a drag was occurring, end it; otherwise raise event.
  if g_isMouseDragging then
    g_isMouseDragging = false;
  else
    if IsSelectionAllowedAt( UI.GetCursorPlotID() ) then
      ConfirmPlaceWonder(pInputStruct); -- StrategicView_MapPlacement.lua
    end
  end
  EndDragMap();
  g_isMouseDownInWorld = false;
  return true;
end

-- ===========================================================================
function OnMouseBuildingPlacementCancel( pInputStruct:table )
  if IsCancelAllowed() then
    LuaEvents.CQUI_CityviewEnable();
    --ExitPlacementMode( true );
  end
end

-- ===========================================================================
function OnMouseBuildingPlacementMove( pInputStruct:table)
  OnMouseMove( pInputStruct );
  RealizeCurrentPlaceDistrictOrWonderPlot();
end

-- ===========================================================================
function OnMouseDistrictPlacementEnd( pInputStruct:table )
  -- If a drag was occurring, end it; otherwise raise event.
  if g_isMouseDragging then
    g_isMouseDragging = false;
  else
    if IsSelectionAllowedAt( UI.GetCursorPlotID() ) then
      ConfirmPlaceDistrict(pInputStruct);
    end
  end
  EndDragMap();
  g_isMouseDownInWorld = false;
  return true;
end

-- ===========================================================================
function OnMouseDistrictPlacementCancel( pInputStruct:table )
  if IsCancelAllowed() then
    LuaEvents.StoreHash(0);
    LuaEvents.CQUI_CityviewEnable();
    --ExitPlacementMode( true );
  end
end

-- ===========================================================================
function OnMouseDistrictPlacementMove( pInputStruct:table)
  OnMouseMove( pInputStruct );
  RealizeCurrentPlaceDistrictOrWonderPlot();
end

-- ===========================================================================
function OnMouseUnitRangeAttack( pInputStruct:table )
  if ClearRangeAttackDragging() then
    return true;
  end

  local plotID:number = UI.GetCursorPlotID();
  if (Map.IsPlot(plotID)) then
    UnitRangeAttack( plotID );
  end
  return true;
end

-- ===========================================================================
function OnMouseMoveRangeAttack( pInputStruct:table )
  OnMouseMove( pInputStruct );

  local plotID:number = UI.GetCursorPlotID();

  if (Map.IsPlot(plotID)) then
    if m_focusedTargetPlot ~= plotID then
      if m_focusedTargetPlot ~= -1 then
        UILens.UnFocusHex(LensLayers.ATTACK_RANGE, m_focusedTargetPlot);
        m_focusedTargetPlot = -1;
      end

      if (g_targetPlots ~= nil) then
        local bPlotIsTarget:boolean = false;
        for i=1,#g_targetPlots do
          if g_targetPlots[i] == plotID then
            bPlotIsTarget = true;
            break;
          end
        end

        if bPlotIsTarget then
          m_focusedTargetPlot = plotID;
          UILens.FocusHex(LensLayers.ATTACK_RANGE, plotID);
        end
      end
    end
  end
  return true;
end

-- ===========================================================================
function OnMouseMoveToStart( pInputStruct:table )
  ReadyForDragMap();
  g_isMouseDownInWorld = true;
  return true;
end

-- ===========================================================================
function OnMouseMoveToEnd( pInputStruct:table )
  -- Stop a dragging or kick off a move selection.
  if g_isMouseDragging then
    g_isMouseDragging = false;
  else
    local pSelectedUnit:table = UI.GetHeadSelectedUnit();
    if pSelectedUnit ~= nil and IsUnitAllowedToMoveToCursorPlot( pSelectedUnit ) then
      MoveUnitToCursorPlot( pSelectedUnit );
    else
      UnitMovementCancel();
    end
    UI.SetInterfaceMode( InterfaceModeTypes.SELECTION );
  end
  EndDragMap();
  g_isMouseDownInWorld = false;
  return true;
end

-- ===========================================================================
function OnMouseMoveToUpdate( pInputStruct:table )

  if g_isMouseDownInWorld then
    -- Check for that player who holds the mouse button dwon, drags and releases it over a UI element.
    if g_isMouseDragging then
      UpdateDragMap();
    else
      if m_isMouseButtonLDown then
        -- A mouse button is down but isn't currently marked for "dragging",
        -- do some maths to see if this is actually a drag state.
        if not g_isMouseDragging then
          if IsDragThreshholdMet() then
            g_isMouseDragging = true;
            StartDragMap();
          end
        end
      end
    end
  end
  RealizeMovementPath();
  return true;
end

-- ===========================================================================
function OnMouseMoveToCancel( pInputStruct:table )
  UnitMovementCancel();
  UI.SetInterfaceMode( InterfaceModeTypes.SELECTION );
  return true;
end


-- ===========================================================================
--  Start touch, until release or move, do not take action.
-- ===========================================================================
function OnTouchDebugEnd( pInputStruct:table )

  -- If last touch in a sequence or double tapping.
  if m_touchCount > 0 then
    return true;
  end

  -- If a drag was occurring, end it; otherwise attempt selection of whatever
  -- is in the plot the mouse is currently at.
  if m_isTouchDragging then
    m_isTouchDragging = false;
  else
    if m_touchTotalNum == 1 then
      print_debug("Debug placing!!!");
      local plotID:number = UI.GetCursorPlotID();
      if (Map.IsPlot(plotID)) then
        local edge = UI.GetCursorNearestPlotEdge();
        DebugPlacement( plotID, edge );
      end
    else
      print_debug("Debug removing!!!");
      OnDebugCancelPlacement( pInputStruct );
    end
  end

  EndDragMap(); -- Reset any dragging
  m_touchTotalNum = 0;
  m_isTouchZooming  = false;
  m_touchStartPlotX = -1;
  m_touchStartPlotY = -1;
  return true;
end

function OnTouchSelectionStart( pInputStruct:table )
  -- Determine maximum # of touches that have occurred.
  if m_touchCount > m_touchTotalNum then
    m_touchTotalNum = m_touchCount;
  end

  -- If the first touch then obtain the plot the touch started in.
  if m_touchTotalNum == 1 then
    local normalizedX, normalizedY      = UIManager:GetNormalizedMousePos();
    m_touchStartPlotX, m_touchStartPlotY  = UI.GetPlotCoordFromNormalizedScreenPos(normalizedX, normalizedY);

    -- Potentially draw path based on if a unit is selected.
    local pSelectedUnit:table = UI.GetHeadSelectedUnit();
    if pSelectedUnit ~= nil and m_touchStartPlotX == pSelectedUnit:GetX() and m_touchStartPlotY == pSelectedUnit:GetY() then
      m_isTouchPathing = true;
      RealizeMovementPath();
    else
      -- No unit selected to draw a path, the player is either about to
      -- start a drag or is just now selecting a unit.
      ReadyForDragMap();
    end
  end
  return true;
end


-- ===========================================================================
function OnTouchSelectionUpdate( pInputStruct:table )

  -- Determine maximum # of touches that have occurred.
  if m_touchCount > m_touchTotalNum then
    m_touchTotalNum = m_touchCount;
  end

  RealizeTouchGestureZoom();

  -- If more than one touch ever occured; take no more actions.
  if m_touchTotalNum > 1 then
    return true;
  end

  -- Drawing a path or dragging?
  if m_isTouchPathing then
    RealizeMovementPath();
  else
    if m_isTouchDragging then
      UpdateDragMap();
    else
      if IsDragThreshholdMet() then
        g_isMouseDragging = true;
        StartDragMap();
      end
    end
  end
  return true;
end

-- ===========================================================================
function OnTouchSelectionEnd( pInputStruct:table )

  -- If last touch in a sequence or double tapping.
  if m_touchCount > 0 then
    return true;
  end

  if m_isDoubleTapping then
    -- If a double tap just happened, clear out.
    m_isDoubleTapping = false;
    m_isTouchPathing  = false;
    m_isTouchDragging = false;
  else
    -- Moving a unit?
    if m_isTouchPathing then
      m_isTouchPathing = false;
      local pSelectedUnit:table = UI.GetHeadSelectedUnit();
      if pSelectedUnit ~= nil then
        if IsUnitAllowedToMoveToCursorPlot( pSelectedUnit ) then
          MoveUnitToCursorPlot( pSelectedUnit );
        else
          UnitMovementCancel();
        end
      else
        UnitMovementCancel();
      end
    else
      -- Selection or Dragging
      if m_isTouchDragging then
        m_isTouchDragging = false;
      else
        local plotX:number, plotY:number = UI.GetCursorPlotCoord();
        if plotX == m_touchStartPlotX and plotY == m_touchStartPlotY then
          SelectInPlot( plotX, plotY );
        end
      end
    end
  end

  EndDragMap();
  m_touchTotalNum   = 0;
  m_isTouchZooming  = false;
  m_touchStartPlotX = -1;
  m_touchStartPlotY = -1;
  return true;
end

-- ===========================================================================
--  Common start for touch
-- ===========================================================================
function OnTouchStart( pInputStruct:table )
  if m_touchCount > m_touchTotalNum then
    m_touchTotalNum = m_touchCount;
  end

  -- If the first touch then obtain the plot the touch started in.
  if m_touchTotalNum == 1 then
    local normalizedX, normalizedY      = UIManager:GetNormalizedMousePos();
    m_touchStartPlotX, m_touchStartPlotY  = UI.GetPlotCoordFromNormalizedScreenPos(normalizedX, normalizedY);
    ReadyForDragMap();
  end
  return true;
end

-- ===========================================================================
--  Common update for touch
-- ===========================================================================
function OnTouchUpdate( pInputStruct:table )
  -- Determine maximum # of touches that have occurred.
  if m_touchCount > m_touchTotalNum then
    m_touchTotalNum = m_touchCount;
  end

  RealizeTouchGestureZoom();

  -- If more than one touch ever occured; take no more actions.
  if m_touchTotalNum > 1 then
    return true;
  end

  if m_isTouchDragging then
    UpdateDragMap();
  else
    if IsDragThreshholdMet() then
      g_isMouseDragging = true;
      StartDragMap();
    end
  end
  return true;
end


-- ===========================================================================
function OnTouchTradeRouteEnd( pInputStruct:table )

  -- If last touch in a sequence or double tapping.
  if m_touchCount > 0 then
    return true;
  end

  -- Selection or Dragging
  if m_isTouchDragging then
    m_isTouchDragging = false;
  else
    local plotId:number = UI.GetCursorPlotID();
    if (Map.IsPlot(plotId)) then
      LuaEvents.WorldInput_MakeTradeRouteDestination( plotId );
    end
  end

  EndDragMap();
  m_touchTotalNum   = 0;
  m_isTouchZooming  = false;
  m_touchStartPlotX = -1;
  m_touchStartPlotY = -1;
  return true;
end

-- ===========================================================================
function OnTouchTeleportToCityEnd( pInputStruct:table )

  -- If last touch in a sequence or double tapping.
  if m_touchCount > 0 then
    return true;
  end

  -- Selection or Dragging
  if m_isTouchDragging then
    m_isTouchDragging = false;
  else
    TeleportToCity();
  end

  EndDragMap();
  m_touchTotalNum   = 0;
  m_isTouchZooming  = false;
  m_touchStartPlotX = -1;
  m_touchStartPlotY = -1;
  return true;
end

-- ===========================================================================
function OnTouchDistrictPlacementEnd( pInputStruct:table )
  ConfirmPlaceDistrict(pInputStruct);
end

-- ===========================================================================
function OnTouchBuildingPlacementEnd( pInputStruct:table )
  ConfirmPlaceWonder(pInputStruct);
end

-- ===========================================================================
function OnTouchMoveToStart( pInputStruct:table )
  return true;
end

-- ===========================================================================
function OnTouchMoveToUpdate( pInputStruct:table )
  -- Determine maximum # of touches that have occurred.
  if m_touchCount > m_touchTotalNum then
    m_touchTotalNum = m_touchCount;
  end

  if m_touchTotalNum == 1 then
    RealizeMovementPath();
  else
    UnitMovementCancel();
  end
  return true;
end

-- ===========================================================================
function OnTouchMoveToEnd( pInputStruct:table )
  -- If last touch in a sequence or double tapping.
  if m_touchCount > 0 then
    return true;
  end

  if m_touchTotalNum == 1 then
    local pSelectedUnit:table = UI.GetHeadSelectedUnit();
    if IsUnitAllowedToMoveToCursorPlot( pSelectedUnit ) then
      MoveUnitToCursorPlot( pSelectedUnit );
    else
      UnitMovementCancel();
    end
  else
    UnitMovementCancel();
  end

  m_touchTotalNum   = 0;
  m_isTouchZooming  = false;
  m_touchStartPlotX = -1;
  m_touchStartPlotY = -1;
  UI.SetInterfaceMode( InterfaceModeTypes.SELECTION );
  return true;
end

-- ===========================================================================
function OnTouchUnitRangeAttack( pInputStruct:table )
  local plotID:number = UI.GetCursorPlotID();
  if (Map.IsPlot(plotID)) then
    UnitRangeAttack( plotID );
  end
  return true;
end


-------------------------------------------------------------------------------
function OnInterfaceModeChange_UnitRangeAttack(eNewMode)
  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK);
  local pSelectedUnit = UI.GetHeadSelectedUnit();
  if (pSelectedUnit ~= nil) then

    if m_focusedTargetPlot ~= -1 then
      UILens.UnFocusHex(LensLayers.ATTACK_RANGE, m_focusedTargetPlot);
      m_focusedTargetPlot = -1;
    end

    local unitPlotID = pSelectedUnit:GetPlotId();
    local tResults = UnitManager.GetOperationTargets(pSelectedUnit, UnitOperationTypes.RANGE_ATTACK );
    local allPlots = tResults[UnitOperationResults.PLOTS];
    if (allPlots ~= nil) then
      g_targetPlots = {};
      for i,modifier in ipairs(tResults[UnitOperationResults.MODIFIERS]) do
        if(modifier == UnitOperationResults.MODIFIER_IS_TARGET) then
          table.insert(g_targetPlots, allPlots[i]);
        end
      end

      -- Highlight the plots available to attack
      if (table.count(g_targetPlots) ~= 0) then
        -- Variation will hold specific targets in range
        local kVariations:table = {};
        for _,targetPlotId in ipairs(g_targetPlots) do
          -- Variant needed to place the attack arc, but we don't want to double-draw the crosshair on the hex.
          table.insert(kVariations, {"EmptyVariant", unitPlotID, targetPlotId} );
        end
        local eLocalPlayer:number = Game.GetLocalPlayer();

        UILens.SetLayerHexesArea(LensLayers.ATTACK_RANGE, eLocalPlayer, allPlots, kVariations);
      end
    end
  end
end

-------------------------------------------------------------------------------
function OnInterfaceModeLeave_UnitRangeAttack(eNewMode)
  UILens.ClearLayerHexes( LensLayers.ATTACK_RANGE );
end

-- ===========================================================================
--  Code related to the Unit Air Attack interface mode
-- ===========================================================================
function UnitAirAttack( pInputStruct )
  local plotID = UI.GetCursorPlotID();
  if (Map.IsPlot(plotID)) then
    local plot = Map.GetPlotByIndex(plotID);
    local plotX = plot:GetX();
    local plotY = plot:GetY();
    local tParameters = {};
    tParameters[UnitOperationTypes.PARAM_X] = plot:GetX();
    tParameters[UnitOperationTypes.PARAM_Y] = plot:GetY();

    local pSelectedUnit = UI.GetHeadSelectedUnit();
    local eAttackingPlayer = pSelectedUnit:GetOwner();
    local eUnitComponentID:table = pSelectedUnit:GetComponentID();

    local bWillStartWar = false;
    local results:table;
    if (PlayersVisibility[eAttackingPlayer]:IsVisible(plotX, plotY)) then
      results = CombatManager.IsAttackChangeWarState(eUnitComponentID, plotX, plotY);
      if (results ~= nil and #results > 0) then
        bWillStartWar = true;
      end
    end

    if (bWillStartWar) then
      local eDefendingPlayer = results[1];
      LuaEvents.Civ6Common_ConfirmWarDialog(eAttackingPlayer, eDefendingPlayer, WarTypes.SURPRISE_WAR);
    else
      if (UnitManager.CanStartOperation( pSelectedUnit, UnitOperationTypes.AIR_ATTACK, nil, tParameters)) then
        UnitManager.RequestOperation( pSelectedUnit, UnitOperationTypes.AIR_ATTACK, tParameters);
        UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
      end
    end
  end
  return true;
end
-------------------------------------------------------------------------------
function OnInterfaceModeChange_Air_Attack(eNewMode)
  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK);
  local pSelectedUnit = UI.GetHeadSelectedUnit();
  if (pSelectedUnit ~= nil) then

    local tResults = UnitManager.GetOperationTargets(pSelectedUnit, UnitOperationTypes.AIR_ATTACK );
    local allPlots = tResults[UnitOperationResults.PLOTS];
    if (allPlots ~= nil) then
      g_targetPlots = {};
      for i,modifier in ipairs(tResults[UnitOperationResults.MODIFIERS]) do
        if(modifier == UnitOperationResults.MODIFIER_IS_TARGET) then
          table.insert(g_targetPlots, allPlots[i]);
        end
      end

      -- Highlight the plots available to attack
      if (table.count(g_targetPlots) ~= 0) then
        local eLocalPlayer:number = Game.GetLocalPlayer();
        UILens.ToggleLayerOn(LensLayers.HEX_COLORING_ATTACK);
        UILens.SetLayerHexesArea(LensLayers.HEX_COLORING_ATTACK, eLocalPlayer, g_targetPlots);
      end
    end
  end
end

---------------------------------------------------------------------------------
function OnInterfaceModeLeave_Air_Attack( eNewMode:number )
  UIManager:SetUICursor(CursorTypes.NORMAL);
  UILens.ToggleLayerOff( LensLayers.HEX_COLORING_ATTACK );
  UILens.ClearLayerHexes( LensLayers.HEX_COLORING_ATTACK );
end

-- ===========================================================================
--  Code related to the WMD Strike interface mode
-- ===========================================================================
function OnWMDStrikeEnd( pInputStruct )
  if ClearRangeAttackDragging() then
    return true;
  end

  local pSelectedUnit = UI.GetHeadSelectedUnit();
  if (pSelectedUnit == nil) then
    return false;
  end

  local plotID = UI.GetCursorPlotID();
  if (Map.IsPlot(plotID)) then
    local plot = Map.GetPlotByIndex(plotID);
    local eWMD = UI.GetInterfaceModeParameter(UnitOperationTypes.PARAM_WMD_TYPE);
    local strikeFn = function() WMDStrike(plot, pSelectedUnit, eWMD); end;
    local tParameters = {};
    tParameters[UnitOperationTypes.PARAM_X] = plot:GetX();
    tParameters[UnitOperationTypes.PARAM_Y] = plot:GetY();
    tParameters[UnitOperationTypes.PARAM_WMD_TYPE] = eWMD;
    if (UnitManager.CanStartOperation( pSelectedUnit, UnitOperationTypes.WMD_STRIKE, nil, tParameters)) then

      local bWillStartWar = false;
      local results:table = CombatManager.IsAttackChangeWarState(pSelectedUnit:GetComponentID(), plot:GetX(), plot:GetY(), eWMD);
      if (results ~= nil and #results > 0) then
        bWillStartWar = true;
      end

      if (bWillStartWar) then
        LuaEvents.WorldInput_ConfirmWarDialog(pSelectedUnit:GetOwner(), results, WarTypes.SURPRISE_WAR, strikeFn);
      else
        local pPopupDialog :table = PopupDialogInGame:new("ConfirmWMDStrike");
        pPopupDialog:AddText(Locale.Lookup("LOC_LAUNCH_WMD_DIALOG_ARE_YOU_SURE"));
        pPopupDialog:AddCancelButton(Locale.Lookup("LOC_LAUNCH_WMD_DIALOG_CANCEL"), nil);
        pPopupDialog:AddConfirmButton(Locale.Lookup("LOC_LAUNCH_WMD_DIALOG_LAUNCH"), strikeFn);
        pPopupDialog:Open();
      end
    end
  end
  return true;
end
-------------------------------------------------------------------------------
function WMDStrike( plot, unit, eWMD )
  local tParameters = {};
  tParameters[UnitOperationTypes.PARAM_X] = plot:GetX();
  tParameters[UnitOperationTypes.PARAM_Y] = plot:GetY();
  tParameters[UnitOperationTypes.PARAM_WMD_TYPE] = eWMD;
  if (UnitManager.CanStartOperation( unit, UnitOperationTypes.WMD_STRIKE, nil, tParameters)) then
    UnitManager.RequestOperation( unit, UnitOperationTypes.WMD_STRIKE, tParameters);
    UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
  end
end
-------------------------------------------------------------------------------
function OnInterfaceModeChange_WMD_Strike(eNewMode)
  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK);
  local pSelectedUnit = UI.GetHeadSelectedUnit();
  if (pSelectedUnit ~= nil) then
    if m_focusedTargetPlot ~= -1 then
      UILens.UnFocusHex(LensLayers.ATTACK_RANGE, m_focusedTargetPlot);
      m_focusedTargetPlot = -1;
    end
    local sourcePlot : number =  Map.GetPlot(pSelectedUnit:GetX(),pSelectedUnit:GetY()):GetIndex();
    local tParameters = {};
    local eWMD = UI.GetInterfaceModeParameter(UnitOperationTypes.PARAM_WMD_TYPE);
    tParameters[UnitOperationTypes.PARAM_WMD_TYPE] = eWMD;

    local tResults = UnitManager.GetOperationTargets(pSelectedUnit, UnitOperationTypes.WMD_STRIKE, tParameters );
    local allPlots = tResults[UnitOperationResults.PLOTS];
    if (allPlots ~= nil) then
      g_targetPlots = {};   -- Used shared list
      for i,modifier in ipairs(tResults[UnitOperationResults.PLOTS]) do
        table.insert(g_targetPlots, allPlots[i]);
      end

      -- Highlight the plots available to attack
      if (table.count(g_targetPlots) ~= 0) then
      -- Variation will hold specific targets in range
        local kVariations:table = {};
        for _,plotId in ipairs(g_targetPlots) do
          table.insert(kVariations, {"AttackRange_Target", sourcePlot, plotId} );
        end
        local eLocalPlayer:number = Game.GetLocalPlayer();
        UILens.ToggleLayerOn(LensLayers.HEX_COLORING_ATTACK);
        UILens.SetLayerHexesArea(LensLayers.HEX_COLORING_ATTACK, eLocalPlayer, g_targetPlots, kVariations);
      end
    end
  end
end

-------------------------------------------------------------------------------
function OnInterfaceModeLeave_WMD_Strike( eNewMode:number )
  UIManager:SetUICursor(CursorTypes.NORMAL);
  UILens.ToggleLayerOff( LensLayers.HEX_COLORING_ATTACK );
  UILens.ClearLayerHexes( LensLayers.HEX_COLORING_ATTACK );
end

-- ===========================================================================
--  Code related to the ICBM Strike interface mode
-- ===========================================================================
function OnICBMStrikeEnd( pInputStruct )
  if ClearRangeAttackDragging() then
    return true;
  end

  local pSelectedCity = UI.GetHeadSelectedCity();
  if (pSelectedCity == nil) then
    return false;
  end

  local targetPlotID = UI.GetCursorPlotID();
  if (Map.IsPlot(targetPlotID)) then
    local targetPlot = Map.GetPlotByIndex(targetPlotID);
    local eWMD = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_WMD_TYPE);
    local sourcePlotX = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_X0);
    local sourcePlotY = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_Y0);
    local strikeFn = function() ICBMStrike(pSelectedCity, sourcePlotX, sourcePlotY, targetPlot, eWMD); end;
    --PlayersVisibility[ pSelectedCity:GetOwner() ]:IsVisible(targetPlot:GetX(), targetPlot:GetY())
    local tParameters = {};
    tParameters[CityCommandTypes.PARAM_X0] = sourcePlotX;
    tParameters[CityCommandTypes.PARAM_Y0] = sourcePlotY;
    tParameters[CityCommandTypes.PARAM_X1] = targetPlot:GetX();
    tParameters[CityCommandTypes.PARAM_Y1] = targetPlot:GetY();
    tParameters[CityCommandTypes.PARAM_WMD_TYPE] = eWMD;
    if (CityManager.CanStartCommand( pSelectedCity, CityCommandTypes.WMD_STRIKE, tParameters)) then

      local bWillStartWar = false;
      local results:table = CombatManager.IsAttackChangeWarState(pSelectedCity:GetComponentID(), targetPlot:GetX(), targetPlot:GetY(), eWMD);
      if (results ~= nil and #results > 0) then
        bWillStartWar = true;
      end

      if (bWillStartWar) then
        LuaEvents.WorldInput_ConfirmWarDialog(pSelectedCity:GetOwner(), results, WarTypes.SURPRISE_WAR, strikeFn);
      else
        local pPopupDialog :table = PopupDialogInGame:new("ConfirmICBMStrike");
        pPopupDialog:AddText(Locale.Lookup("LOC_LAUNCH_ICBM_DIALOG_ARE_YOU_SURE"));
        pPopupDialog:AddCancelButton(Locale.Lookup("LOC_LAUNCH_ICBM_DIALOG_CANCEL"), nil);
        pPopupDialog:AddConfirmButton(Locale.Lookup("LOC_LAUNCH_ICBM_DIALOG_LAUNCH"), strikeFn);
        pPopupDialog:Open();
      end
    end
  end
end
-------------------------------------------------------------------------------
function ICBMStrike( fromCity, sourcePlotX, sourcePlotY, targetPlot, eWMD )
  local tParameters = {};
  tParameters[CityCommandTypes.PARAM_X0] = sourcePlotX;
  tParameters[CityCommandTypes.PARAM_Y0] = sourcePlotY;
  tParameters[CityCommandTypes.PARAM_X1] = targetPlot:GetX();
  tParameters[CityCommandTypes.PARAM_Y1] = targetPlot:GetY();
  tParameters[CityCommandTypes.PARAM_WMD_TYPE] = eWMD;
  if (CityManager.CanStartCommand( fromCity, CityCommandTypes.WMD_STRIKE, tParameters)) then
    CityManager.RequestCommand( fromCity, CityCommandTypes.WMD_STRIKE, tParameters);
    UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
  end
end
-------------------------------------------------------------------------------
function OnInterfaceModeChange_ICBM_Strike(eNewMode)
  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK);
  local pCity = UI.GetHeadSelectedCity();

  if (pCity ~= nil) then
    if m_focusedTargetPlot ~= -1 then
      UILens.UnFocusHex(LensLayers.ATTACK_RANGE, m_focusedTargetPlot);
      m_focusedTargetPlot = -1;
    end
    local eWMD = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_WMD_TYPE);
    local iSourceLocX = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_X0);
    local iSourceLocY = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_Y0);

    local tParameters = {};
    tParameters[CityCommandTypes.PARAM_WMD_TYPE] = eWMD;
    tParameters[CityCommandTypes.PARAM_X0] = iSourceLocX;
    tParameters[CityCommandTypes.PARAM_Y0] = iSourceLocY;

    local sourcePlot : number =  Map.GetPlot(iSourceLocX,iSourceLocY):GetIndex();

    local tResults = CityManager.GetCommandTargets(pCity, CityCommandTypes.WMD_STRIKE, tParameters);
    local allPlots = tResults[CityCommandResults.PLOTS];
    if (allPlots ~= nil) then
      g_targetPlots = {}; -- Use shared list so other functions know our targets
      for i,modifier in ipairs(tResults[CityCommandResults.PLOTS]) do
        table.insert(g_targetPlots, allPlots[i]);
      end

      -- Highlight the plots available to attack
      if (table.count(g_targetPlots) ~= 0) then
        local kVariations:table = {};
        for _,plotId in ipairs(g_targetPlots) do
          table.insert(kVariations, {"AttackRange_Target", sourcePlot , plotId} );
        end
        local eLocalPlayer:number = Game.GetLocalPlayer();
        UILens.ToggleLayerOn(LensLayers.HEX_COLORING_ATTACK);
        UILens.SetLayerHexesArea(LensLayers.HEX_COLORING_ATTACK, eLocalPlayer, g_targetPlots, kVariations);
      end
    else
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
  end
end

---------------------------------------------------------------------------------
function OnInterfaceModeLeave_ICBM_Strike( eNewMode:number )
  UIManager:SetUICursor(CursorTypes.NORMAL);
  UILens.ToggleLayerOff( LensLayers.HEX_COLORING_ATTACK );
  UILens.ClearLayerHexes( LensLayers.HEX_COLORING_ATTACK );
end

-- ===========================================================================
--  Code related to the Coastal Raid interface mode
-- ===========================================================================
function CoastalRaid( pInputStruct )
  local plotID = UI.GetCursorPlotID();
  if (Map.IsPlot(plotID)) then
    local plot = Map.GetPlotByIndex(plotID);

    local tParameters = {};
    tParameters[UnitOperationTypes.PARAM_X] = plot:GetX();
    tParameters[UnitOperationTypes.PARAM_Y] = plot:GetY();

    local pSelectedUnit = UI.GetHeadSelectedUnit();

    local bWillStartWar = false;
    local results:table = CombatManager.IsAttackChangeWarState(pSelectedUnit:GetComponentID(), plot:GetX(), plot:GetY());
    if (results ~= nil and #results > 0) then
      bWillStartWar = true;
    end

    if (bWillStartWar) then
      -- Create the action specific parameters
      LuaEvents.WorldInput_ConfirmWarDialog(pSelectedUnit:GetOwner(), results, WarTypes.SURPRISE_WAR);
    else
      if (UnitManager.CanStartOperation( pSelectedUnit, UnitOperationTypes.COASTAL_RAID, nil, tParameters)) then
        UnitManager.RequestOperation( pSelectedUnit, UnitOperationTypes.COASTAL_RAID, tParameters);
        UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
      end
    end
  end
  return true;
end
-------------------------------------------------------------------------------
function OnInterfaceModeChange_CoastalRaid(eNewMode)
  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK);
  local pSelectedUnit = UI.GetHeadSelectedUnit();
  if (pSelectedUnit ~= nil) then
    local tResults = UnitManager.GetOperationTargets(pSelectedUnit, UnitOperationTypes.COASTAL_RAID );
    local allPlots = tResults[UnitOperationResults.PLOTS];
    if (allPlots ~= nil) then
      g_targetPlots = {};
      for i,modifier in ipairs(tResults[UnitOperationResults.PLOTS]) do
        table.insert(g_targetPlots, allPlots[i]);
      end

      -- Highlight the plots available to attack
      if (table.count(g_targetPlots) ~= 0) then
        local eLocalPlayer:number = Game.GetLocalPlayer();
        UILens.ToggleLayerOn(LensLayers.HEX_COLORING_ATTACK);
        UILens.SetLayerHexesArea(LensLayers.HEX_COLORING_ATTACK, eLocalPlayer, g_targetPlots);
      end
    end
  end
end

---------------------------------------------------------------------------------
function OnInterfaceModeLeave_CoastalRaid( eNewMode:number )
  UIManager:SetUICursor(CursorTypes.NORMAL);
  UILens.ToggleLayerOff( LensLayers.HEX_COLORING_ATTACK );
  UILens.ClearLayerHexes( LensLayers.HEX_COLORING_ATTACK );
end

-- ===========================================================================
--  Code related to the Unit Air Deploy interface mode
-- ===========================================================================
function OnMouseDeployEnd( pInputStruct )
  -- If a drag was occurring, end it; otherwise raise event.
  if g_isMouseDragging then
    g_isMouseDragging = false;
  else
    if IsSelectionAllowedAt( UI.GetCursorPlotID() ) then
      AirUnitDeploy(pInputStruct);
    end
  end
  EndDragMap();
  g_isMouseDownInWorld = false;
  return true;
end
-------------------------------------------------------------------------------
function AirUnitDeploy( pInputStruct )
  local plotID = UI.GetCursorPlotID();
  if (Map.IsPlot(plotID)) then
    local plot = Map.GetPlotByIndex(plotID);

    local tParameters = {};
    tParameters[UnitOperationTypes.PARAM_X] = plot:GetX();
    tParameters[UnitOperationTypes.PARAM_Y] = plot:GetY();

    local pSelectedUnit = UI.GetHeadSelectedUnit();
    -- Assuming that the operation is DEPLOY.  Store this in the InterfaceMode somehow?
    if (UnitManager.CanStartOperation( pSelectedUnit, UnitOperationTypes.DEPLOY, nil, tParameters)) then
      UnitManager.RequestOperation( pSelectedUnit, UnitOperationTypes.DEPLOY, tParameters);
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
  end
  return true;
end
-------------------------------------------------------------------------------
function OnInterfaceModeChange_Deploy(eNewMode)
  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK);
  local pSelectedUnit = UI.GetHeadSelectedUnit();
  if (pSelectedUnit ~= nil) then

    local tResults = UnitManager.GetOperationTargets(pSelectedUnit, UnitOperationTypes.DEPLOY );
    local allPlots = tResults[UnitOperationResults.PLOTS];
    if (allPlots ~= nil) then
      g_targetPlots = {};
      for i,modifier in ipairs(tResults[UnitOperationResults.PLOTS]) do
        --if(modifier == UnitOperationResults.MODIFIER_IS_TARGET) then
          table.insert(g_targetPlots, allPlots[i]);
        --end
      end

      -- Highlight the plots available to deploy to
      if (table.count(g_targetPlots) ~= 0) then
        local eLocalPlayer:number = Game.GetLocalPlayer();
        UILens.ToggleLayerOn(LensLayers.HEX_COLORING_MOVEMENT);
        UILens.SetLayerHexesArea(LensLayers.HEX_COLORING_MOVEMENT, eLocalPlayer, g_targetPlots);
      end
    end
  end
end

---------------------------------------------------------------------------------
function OnInterfaceModeLeave_Deploy( eNewMode:number )
  UIManager:SetUICursor(CursorTypes.NORMAL);
  UILens.ToggleLayerOff( LensLayers.HEX_COLORING_MOVEMENT );
  UILens.ClearLayerHexes( LensLayers.HEX_COLORING_MOVEMENT );
end

-- ===========================================================================
--  Code related to the Unit Air Re-Base interface mode
-- ===========================================================================
function OnMouseRebaseEnd( pInputStruct )
  -- If a drag was occurring, end it; otherwise raise event.
  if g_isMouseDragging then
    g_isMouseDragging = false;
  else
    if IsSelectionAllowedAt( UI.GetCursorPlotID() ) then
      AirUnitReBase(pInputStruct);
    end
  end
  EndDragMap();
  g_isMouseDownInWorld = false;
  return true;
end
-------------------------------------------------------------------------------
function AirUnitReBase( pInputStruct )
  local plotID = UI.GetCursorPlotID();
  if (Map.IsPlot(plotID)) then
    local plot = Map.GetPlotByIndex(plotID);

    local tParameters = {};
    tParameters[UnitOperationTypes.PARAM_X] = plot:GetX();
    tParameters[UnitOperationTypes.PARAM_Y] = plot:GetY();

    local pSelectedUnit = UI.GetHeadSelectedUnit();
    -- Assuming that the operation is DEPLOY.  Store this in the InterfaceMode somehow?
    if (UnitManager.CanStartOperation( pSelectedUnit, UnitOperationTypes.REBASE, nil, tParameters)) then
      UnitManager.RequestOperation( pSelectedUnit, UnitOperationTypes.REBASE, tParameters);
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
  end
  return true;
end
-------------------------------------------------------------------------------
function OnInterfaceModeChange_ReBase(eNewMode)
  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK);
  local pSelectedUnit = UI.GetHeadSelectedUnit();
  if (pSelectedUnit ~= nil) then

    local tResults = UnitManager.GetOperationTargets(pSelectedUnit, UnitOperationTypes.REBASE );
    local allPlots = tResults[UnitOperationResults.PLOTS];
    if (allPlots ~= nil) then
      g_targetPlots = {};
      for i,modifier in ipairs(tResults[UnitOperationResults.PLOTS]) do
        table.insert(g_targetPlots, allPlots[i]);
      end

      -- Highlight the plots available to deploy to
      if (table.count(g_targetPlots) ~= 0) then
        local eLocalPlayer:number = Game.GetLocalPlayer();
        UILens.ToggleLayerOn(LensLayers.HEX_COLORING_MOVEMENT);
        UILens.SetLayerHexesArea(LensLayers.HEX_COLORING_MOVEMENT, eLocalPlayer, g_targetPlots);
      end
    end
  end
end

---------------------------------------------------------------------------------
function OnInterfaceModeLeave_ReBase( eNewMode:number )
  UIManager:SetUICursor(CursorTypes.NORMAL);
  UILens.ToggleLayerOff( LensLayers.HEX_COLORING_MOVEMENT );
  UILens.ClearLayerHexes( LensLayers.HEX_COLORING_MOVEMENT );
end

-- ===========================================================================
--  Code related to the Place Map Pin interface mode
-- ===========================================================================
function PlaceMapPin()
  local plotId = UI.GetCursorPlotID();
  if (Map.IsPlot(plotId)) then
    local kPlot = Map.GetPlotByIndex(plotId);
    UI.SetInterfaceMode(InterfaceModeTypes.SELECTION); -- Revert to default interface mode.
    LuaEvents.MapPinPopup_RequestMapPin(kPlot:GetX(), kPlot:GetY());
  end
  return true;
end

------------------------------------------------------------------------------------------------
-- Code related to the City and District Range Attack interface mode
------------------------------------------------------------------------------------------------
function CityRangeAttack( pInputStruct )
  if ClearRangeAttackDragging() then
    return true;
  end

  local plotID = UI.GetCursorPlotID();
  if (Map.IsPlot(plotID)) then
    local plot = Map.GetPlotByIndex(plotID);

    local tParameters = {};
    tParameters[UnitOperationTypes.PARAM_X] = plot:GetX();
    tParameters[UnitOperationTypes.PARAM_Y] = plot:GetY();

    local pSelectedCity = UI.GetHeadSelectedCity();
    -- Assuming that the command is RANGE_ATTACK.  Store this in the InterfaceMode somehow?
    if (CityManager.CanStartCommand( pSelectedCity, CityCommandTypes.RANGE_ATTACK, tParameters)) then
      CityManager.RequestCommand( pSelectedCity, CityCommandTypes.RANGE_ATTACK, tParameters);
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
  end
  return true;
end

-------------------------------------------------------------------------------
function OnInterfaceModeChange_CityRangeAttack(eNewMode)
  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK);
  local pSelectedCity = UI.GetHeadSelectedCity();
  if (pSelectedCity ~= nil) then

    if m_focusedTargetPlot ~= -1 then
      UILens.UnFocusHex(LensLayers.ATTACK_RANGE, m_focusedTargetPlot);
      m_focusedTargetPlot = -1;
    end

    local tParameters = {};
    tParameters[CityCommandTypes.PARAM_RANGED_ATTACK] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_RANGED_ATTACK);

    local sourcePlotID = Map.GetPlotIndex(pSelectedCity:GetX(), pSelectedCity:GetY());

    local tResults = CityManager.GetCommandTargets(pSelectedCity, CityCommandTypes.RANGE_ATTACK, tParameters );
    local allPlots = tResults[CityCommandResults.PLOTS];
    if (allPlots ~= nil) then
      g_targetPlots = {};
      for i,modifier in ipairs(tResults[CityCommandResults.MODIFIERS]) do
        if(modifier == CityCommandResults.MODIFIER_IS_TARGET) then
          table.insert(g_targetPlots, allPlots[i]);
        end
      end

      -- Highlight the plots available to attack
      if (table.count(g_targetPlots) ~= 0) then
        -- Variation will hold specific targets in range
        local kVariations:table = {};
        for _,plotId in ipairs(g_targetPlots) do
          table.insert(kVariations, {"AttackRange_Target", sourcePlotID, plotId} );
        end
        local eLocalPlayer:number = Game.GetLocalPlayer();

        UILens.SetLayerHexesArea(LensLayers.ATTACK_RANGE, eLocalPlayer, allPlots, kVariations);

      end
    end
  end
end

-------------------------------------------------------------------------------
function OnInterfaceModeLeave_CityRangeAttack(eNewMode)
  UILens.ClearLayerHexes( LensLayers.ATTACK_RANGE );
end

-------------------------------------------------------------------------------
function DistrictRangeAttack( pInputStruct )
  if ClearRangeAttackDragging() then
    return true;
  end

  local plotID = UI.GetCursorPlotID();
  if (Map.IsPlot(plotID)) then
    local plot = Map.GetPlotByIndex(plotID);

    local tParameters = {};
    tParameters[UnitOperationTypes.PARAM_X] = plot:GetX();
    tParameters[UnitOperationTypes.PARAM_Y] = plot:GetY();

    local pSelectedDistrict = UI.GetHeadSelectedDistrict();
    -- Assuming that the command is RANGE_ATTACK.  Store this in the InterfaceMode somehow?
    if (CityManager.CanStartCommand( pSelectedDistrict, CityCommandTypes.RANGE_ATTACK, tParameters)) then
      CityManager.RequestCommand( pSelectedDistrict, CityCommandTypes.RANGE_ATTACK, tParameters);
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
  end
  return true;
end
-------------------------------------------------------------------------------
function OnInterfaceModeChange_DistrictRangeAttack(eNewMode)
  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK);
  local pSelectedDistrict = UI.GetHeadSelectedDistrict();
  if (pSelectedDistrict ~= nil) then

    if m_focusedTargetPlot ~= -1 then
      UILens.UnFocusHex(LensLayers.ATTACK_RANGE, m_focusedTargetPlot);
      m_focusedTargetPlot = -1;
    end

    local tParameters = {};
    tParameters[CityCommandTypes.PARAM_RANGED_ATTACK] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_RANGED_ATTACK);

    --The source of the attack is the plot that the district is in
    local sourcePlotID = Map.GetPlotIndex(pSelectedDistrict:GetX(), pSelectedDistrict:GetY());

    local tResults    :table = CityManager.GetCommandTargets(pSelectedDistrict, CityCommandTypes.RANGE_ATTACK, tParameters );
    local allPlots    :table = tResults[CityCommandResults.PLOTS];
    if (allPlots ~= nil) then
      g_targetPlots = {};
      for i,modifier in ipairs(tResults[CityCommandResults.MODIFIERS]) do
        if(modifier == CityCommandResults.MODIFIER_IS_TARGET) then
          table.insert(g_targetPlots, allPlots[i]);
        end
      end

      -- Highlight the plots available to attack
      if (table.count(g_targetPlots) ~= 0) then
        -- Variation will hold specific targets in range
        local kVariations:table = {};
        for _,plotId in ipairs(g_targetPlots) do
          table.insert(kVariations, {"AttackRange_Target", sourcePlotID, plotId} );
        end
        local eLocalPlayer:number = Game.GetLocalPlayer();

        UILens.SetLayerHexesArea(LensLayers.ATTACK_RANGE, eLocalPlayer, allPlots, kVariations);

      end
    end
  end
end

-------------------------------------------------------------------------------
function OnInterfaceModeLeave_DistrictRangeAttack(eNewMode)
  UILens.ClearLayerHexes( LensLayers.ATTACK_RANGE );
end

-------------------------------------------------------------------------------
function OnInterfaceModeLeave_WMDRangeAttack(eNewMode)
  UILens.ClearLayerHexes( LensLayers.ATTACK_RANGE );
end

------------------------------------------------------------------------------------------------
-- Code related to the Unit's Make Trade Route interface mode
-- Some input is handled separately, by TradePanel.lua
------------------------------------------------------------------------------------------------
function OnInterfaceModeChange_MakeTradeRoute(eNewMode)
  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK);
end

------------------------------------------------------------------------------------------------
-- Code related to the Unit's 'Teleport to City' mode
------------------------------------------------------------------------------------------------
function TeleportToCity()
  local plotID = UI.GetCursorPlotID();
  if (Map.IsPlot(plotID)) then
    local plot = Map.GetPlotByIndex(plotID);

    local tParameters = {};
    tParameters[UnitOperationTypes.PARAM_X] = plot:GetX();
    tParameters[UnitOperationTypes.PARAM_Y] = plot:GetY();

    local eOperation = UI.GetInterfaceModeParameter(UnitOperationTypes.PARAM_OPERATION_TYPE);

    local pSelectedUnit = UI.GetHeadSelectedUnit();
    if (UnitManager.CanStartOperation( pSelectedUnit, eOperation, nil, tParameters)) then
      UnitManager.RequestOperation( pSelectedUnit, eOperation, tParameters);
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
      UI.PlaySound("Unit_Relocate");
    end
  end
  return true;
end
-------------------------------------------------------------------------------
function OnInterfaceModeChange_TeleportToCity(eNewMode)
  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK);
  local pSelectedUnit = UI.GetHeadSelectedUnit();
  if (pSelectedUnit ~= nil) then

    local eOperation = UI.GetInterfaceModeParameter(UnitOperationTypes.PARAM_OPERATION_TYPE);
    local tResults = UnitManager.GetOperationTargets(pSelectedUnit, eOperation );
    local allPlots = tResults[UnitOperationResults.PLOTS];
    if (allPlots ~= nil) then
      g_targetPlots = {};
      for i,modifier in ipairs(tResults[UnitOperationResults.PLOTS]) do
        table.insert(g_targetPlots, allPlots[i]);
      end

      -- Highlight the plots available to deploy to
      if (table.count(g_targetPlots) ~= 0) then
        local eLocalPlayer:number = Game.GetLocalPlayer();
        UILens.ToggleLayerOn(LensLayers.HEX_COLORING_MOVEMENT);
        UILens.SetLayerHexesArea(LensLayers.HEX_COLORING_MOVEMENT, eLocalPlayer, g_targetPlots);
      end
    end
  end
end

---------------------------------------------------------------------------------
function OnInterfaceModeLeave_TeleportToCity( eNewMode:number )
  UIManager:SetUICursor(CursorTypes.NORMAL);
  UILens.ToggleLayerOff( LensLayers.HEX_COLORING_MOVEMENT );
  UILens.ClearLayerHexes( LensLayers.HEX_COLORING_MOVEMENT );
end

-- =============================================================================================
function OnInterfaceModeChange_MoveTo( eNewMode:number )
  m_cachedPathUnit  = nil;
  m_cachedPathPlotId  = -1 ;
  RealizeMovementPath();
end

-- =============================================================================================
function OnInterfaceModeChange_MoveToLeave( eOldMode:number )
  ClearMovementPath();
  UILens.SetActive("Default");
end

-- =============================================================================================
function OnInterfaceModeChange_PlaceMapPin( eNewMode:number )
  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK);
end

------------------------------------------------------------------------------------------------
-- Code related to the World Builder's Select Plot Mode
------------------------------------------------------------------------------------------------

-- =============================================================================================
function OnInterfaceModeChange_WBSelectPlot()
  m_WBMouseOverPlot = -1;
end

-- =============================================================================================
function OnInterfaceModeChange_SpyChooseMission()
  UIManager:SetUICursor(CursorTypes.NORMAL);
  UILens.SetActive("Default");
end

-- =============================================================================================
function OnInterfaceModeChange_SpyTravelToCity()
  UIManager:SetUICursor(CursorTypes.NORMAL);
  UILens.SetActive("Default");

end

function OnInterfaceModeChange_NaturalWonder()
  UIManager:SetUICursor(CursorTypes.NORMAL);
  UI.SetFixedTiltMode( true );
end

-- ===========================================================================
function OnInterfaceModeLeave_NaturalWonder( eNewMode:number )
  UIManager:SetUICursor(CursorTypes.NORMAL);
  UI.SetFixedTiltMode( false );
  OnCycleUnitSelectionRequest();
end

-- ===========================================================================
function OnMouseEnd_WBSelectPlot( pInputStruct:table )
  -- If a drag was occurring, end it; otherwise attempt selection of whatever
  -- is in the plot the mouse is currently at.
  if g_isMouseDragging then
    --print("Stopping drag");
    g_isMouseDragging = false;
  else
    --print("World Builder Placement");
    if (Map.IsPlot(UI.GetCursorPlotID())) then
      LuaEvents.WorldInput_WBSelectPlot(UI.GetCursorPlotID(), UI.GetCursorNearestPlotEdge(), true);
    end
  end
  EndDragMap(); -- Reset any dragging
  g_isMouseDownInWorld = false;
  return true;
end

-- ===========================================================================
function OnRButtonUp_WBSelectPlot( pInputStruct )
  if (Map.IsPlot(UI.GetCursorPlotID())) then
    LuaEvents.WorldInput_WBSelectPlot(UI.GetCursorPlotID(), UI.GetCursorNearestPlotEdge(), false);
  end
  return true;
end

-- ===========================================================================
function OnMouseMove_WBSelectPlot( pInputStruct )

  -- Check to see if the plot the mouse is over has changed
  if not g_isMouseDragging then
    local mouseOverPlot = UI.GetCursorPlotID();
    if (Map.IsPlot(mouseOverPlot)) then
      if mouseOverPlot ~= m_WBMouseOverPlot then
        m_WBMouseOverPlot = mouseOverPlot;
        LuaEvents.WorldInput_WBMouseOverPlot(mouseOverPlot);
      end
    end
  end

  return OnMouseMove();
end

------------------------------------------------------------------------------------------------
-- Code related to the Unit's 'Form Corps' mode
------------------------------------------------------------------------------------------------
function FormCorps( pInputStruct )
  local plotID = UI.GetCursorPlotID();
  if (Map.IsPlot(plotID)) then
    local plot = Map.GetPlotByIndex(plotID);
    local unitList  = Units.GetUnitsInPlotLayerID(  plot:GetX(), plot:GetY(), MapLayers.ANY );
    local pSelectedUnit = UI.GetHeadSelectedUnit();

    local tParameters :table = {};
    for i, pUnit in ipairs(unitList) do
      tParameters[UnitCommandTypes.PARAM_UNIT_PLAYER] = pUnit:GetOwner();
      tParameters[UnitCommandTypes.PARAM_UNIT_ID] = pUnit:GetID();
      if (UnitManager.CanStartCommand( pSelectedUnit, UnitCommandTypes.FORM_CORPS, tParameters)) then
        UnitManager.RequestCommand( pSelectedUnit, UnitCommandTypes.FORM_CORPS, tParameters);
        UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
      end
    end
  end
  return true;
end

------------------------------------------------------------------------------------------------
function OnInterfaceModeChange_UnitFormCorps(eNewMode)
  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK);
  local pSelectedUnit = UI.GetHeadSelectedUnit();
  local player = pSelectedUnit:GetOwner();
  local tResults = UnitManager.GetCommandTargets( pSelectedUnit, UnitCommandTypes.FORM_CORPS );
  if (tResults[UnitCommandResults.UNITS] ~= nil and #tResults[UnitCommandResults.UNITS] ~= 0) then
    local tUnits = tResults[UnitCommandResults.UNITS];
    local unitPlots :table = {};
    g_targetPlots = {};
    for i, unitComponentID in ipairs(tUnits) do
      local unit = Players[player]:GetUnits():FindID(unitComponentID.id);
      table.insert(unitPlots, Map.GetPlotIndex(unit:GetX(), unit:GetY()));
    end
    UILens.ToggleLayerOn(LensLayers.HEX_COLORING_PLACEMENT);
    UILens.SetLayerHexesArea(LensLayers.HEX_COLORING_PLACEMENT, player, unitPlots);
    g_targetPlots = unitPlots;
  end
end

--------------------------------------------------------------------------------------------------
function OnInterfaceModeLeave_UnitFormCorps( eNewMode:number )
  UIManager:SetUICursor(CursorTypes.NORMAL);
  UILens.ToggleLayerOff( LensLayers.HEX_COLORING_PLACEMENT );
  UILens.ClearLayerHexes( LensLayers.HEX_COLORING_PLACEMENT );
end

------------------------------------------------------------------------------------------------
-- Code related to the Unit's 'Form Army' mode
------------------------------------------------------------------------------------------------
function FormArmy( pInputStruct )
  local plotID = UI.GetCursorPlotID();
  if (Map.IsPlot(plotID)) then
    local plot = Map.GetPlotByIndex(plotID);
    local unitList  = Units.GetUnitsInPlotLayerID(  plot:GetX(), plot:GetY(), MapLayers.ANY );
    local pSelectedUnit = UI.GetHeadSelectedUnit();

    local tParameters :table = {};
    for i, pUnit in ipairs(unitList) do
      tParameters[UnitCommandTypes.PARAM_UNIT_PLAYER] = pUnit:GetOwner();
      tParameters[UnitCommandTypes.PARAM_UNIT_ID] = pUnit:GetID();
      if (UnitManager.CanStartCommand( pSelectedUnit, UnitCommandTypes.FORM_ARMY, tParameters)) then
        UnitManager.RequestCommand( pSelectedUnit, UnitCommandTypes.FORM_ARMY, tParameters);
        UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
      end
    end
  end

  return true;
end

------------------------------------------------------------------------------------------------
function OnInterfaceModeChange_UnitFormArmy(eNewMode)
  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK);
  local pSelectedUnit = UI.GetHeadSelectedUnit();
  local player = pSelectedUnit:GetOwner();
  local tResults = UnitManager.GetCommandTargets( pSelectedUnit, UnitCommandTypes.FORM_ARMY );
  if (tResults[UnitCommandResults.UNITS] ~= nil and #tResults[UnitCommandResults.UNITS] ~= 0) then
    local tUnits = tResults[UnitCommandResults.UNITS];
    local unitPlots :table = {};
    g_targetPlots = {};
    for i, unitComponentID in ipairs(tUnits) do
      local unit = Players[player]:GetUnits():FindID(unitComponentID.id);
      table.insert(unitPlots, Map.GetPlotIndex(unit:GetX(), unit:GetY()));
    end
    UILens.ToggleLayerOn(LensLayers.HEX_COLORING_PLACEMENT);
    UILens.SetLayerHexesArea(LensLayers.HEX_COLORING_PLACEMENT, player, unitPlots);
    g_targetPlots = unitPlots;
  end
end

--------------------------------------------------------------------------------------------------
function OnInterfaceModeLeave_UnitFormArmy( eNewMode:number )
  UIManager:SetUICursor(CursorTypes.NORMAL);
  UILens.ToggleLayerOff( LensLayers.HEX_COLORING_PLACEMENT );
  UILens.ClearLayerHexes( LensLayers.HEX_COLORING_PLACEMENT );
end

------------------------------------------------------------------------------------------------
-- Code related to the Unit's 'Airlift' mode
------------------------------------------------------------------------------------------------
function OnMouseAirliftEnd( pInputStruct )
  -- If a drag was occurring, end it; otherwise raise event.
  if g_isMouseDragging then
    g_isMouseDragging = false;
  else
    if IsSelectionAllowedAt( UI.GetCursorPlotID() ) then
      UI.PlaySound("Unit_Airlift");
      UnitAirlift(pInputStruct);
    end
  end
  EndDragMap();
  g_isMouseDownInWorld = false;
  return true;
end
------------------------------------------------------------------------------------------------
function UnitAirlift( pInputStruct )
  local plotID = UI.GetCursorPlotID();
  if (Map.IsPlot(plotID)) then
    local plot = Map.GetPlotByIndex(plotID);

    local tParameters = {};
    tParameters[UnitCommandTypes.PARAM_X] = plot:GetX();
    tParameters[UnitCommandTypes.PARAM_Y] = plot:GetY();

    local pSelectedUnit = UI.GetHeadSelectedUnit();
    -- Assuming that the operation is AIRLIFT.  Store this in the InterfaceMode somehow?
    if (UnitManager.CanStartCommand( pSelectedUnit, UnitCommandTypes.AIRLIFT, nil, tParameters)) then
      UnitManager.RequestCommand( pSelectedUnit, UnitCommandTypes.AIRLIFT, tParameters);
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    end
  end
  return true;
end
------------------------------------------------------------------------------------------------
function OnInterfaceModeChange_UnitAirlift(eNewMode)
  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK);
  local pSelectedUnit = UI.GetHeadSelectedUnit();
  local tResults = UnitManager.GetCommandTargets(pSelectedUnit, UnitCommandTypes.AIRLIFT );
  local allPlots = tResults[UnitCommandResults.PLOTS];
  if (allPlots ~= nil) then
    g_targetPlots = {};
    for i,modifier in ipairs(tResults[UnitCommandResults.PLOTS]) do
      table.insert(g_targetPlots, allPlots[i]);
    end

    -- Highlight the plots available to airlift to
    if (table.count(g_targetPlots) ~= 0) then
      local eLocalPlayer:number = Game.GetLocalPlayer();
      UILens.ToggleLayerOn(LensLayers.HEX_COLORING_MOVEMENT);
      UILens.SetLayerHexesArea(LensLayers.HEX_COLORING_MOVEMENT, eLocalPlayer, g_targetPlots);
    end
  end
end
--------------------------------------------------------------------------------------------------
function OnInterfaceModeLeave_UnitAirlift( eNewMode:number )
  UIManager:SetUICursor(CursorTypes.NORMAL);
  UILens.ToggleLayerOff( LensLayers.HEX_COLORING_MOVEMENT );
  UILens.ClearLayerHexes( LensLayers.HEX_COLORING_MOVEMENT );
end


-- ===========================================================================
function OnInterfaceModeChange_Selection(eNewMode)
  UIManager:SetUICursor(CursorTypes.NORMAL);
  UILens.SetActive("Default");
end



-- .,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,
--
--            EVENT MAPPINGS, PRE-PROCESSING & HANDLING
--
-- .,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,.,;/^`'^\:,


-- ===========================================================================
--  ENGINE Event
--  Will only be called once the animation from the previous player is
--  complete or will be skipped if a player has no selection or explicitly
--  selected another unit/city.
-- ===========================================================================
function OnCycleUnitSelectionRequest()

  -- If the right button is (still) down, do not select a new unit otherwise
  -- a long path may be created if there is a long camera pan.
  --if m_isMouseButtonRDown then
  --  return;
  --end

  if(UI.GetInterfaceMode() ~= InterfaceModeTypes.NATURAL_WONDER or m_isMouseButtonRDown) then

    -- AZURENCY : OnCycleUnitSelectionRequest is called by UI.SetCycleAdvanceTimer()
    -- in SelectedUnit.lua causing a conflict with the auto-cyling of unit
    -- (not the same given by UI.SelectNextReadyUnit() and player:GetUnits():GetFirstReadyUnit())
    local pPlayer :table = Players[Game.GetLocalPlayer()];
    if pPlayer ~= nil then
      if pPlayer:IsTurnActive() then
        local unit:table = pPlayer:GetUnits():GetFirstReadyUnit();
        -- AZURENCY : we also check if there is not already a unit selected,
        -- bacause UI.SetCycleAdvanceTimer() is always called after deselecting a unit
        if unit ~= nil and not UI.GetHeadSelectedUnit() then
          UI.DeselectAllUnits();
          UI.DeselectAllCities();
          UI.SelectUnit(unit);
          UI.LookAtPlot(unit:GetX(), unit:GetY());
        end
      end
    end
    -- Auto-advance selection to the next unit.
    -- if not UI.SelectNextReadyUnit() then
    --   UI.DeselectAllUnits();
    -- end
  end
end


-- ===========================================================================
--  ENGINE Event
--  eOldMode, mode the engine was formally in
--  eNewMode, new mode the engine has just changed to
-- ===========================================================================
function OnInterfaceModeChanged( eOldMode:number, eNewMode:number )

  -- Optional: function run before a mode is exited.
  local pOldModeHandler :table = InterfaceModeMessageHandler[eOldMode];
  if pOldModeHandler then
    local pModeLeaveFunc :ifunction = pOldModeHandler[INTERFACEMODE_LEAVE];
    if pModeLeaveFunc ~= nil then
      pModeLeaveFunc(eOldMode);
    end
  end

  -- Required: function to setup next interface mode in world input
  local pNewModeHandler :table = InterfaceModeMessageHandler[eNewMode];
  if pNewModeHandler then
    local pModeChangeFunc :ifunction = pNewModeHandler[INTERFACEMODE_ENTER];
    if pModeChangeFunc ~= nil then
      pModeChangeFunc(eNewMode);
    end
  else
    local msg:string = string.format("Change requested an unhandled interface mode of value '0x%x'.  (Previous mode '0x%x')",eNewMode,eOldMode);
    --print(msg);
    UIManager:SetUICursor(CursorTypes.NORMAL);
    UILens.SetActive("Default");
  end
end

-- ===========================================================================
--  ENGINE Event
-- ===========================================================================
function IsEndGameMenuShown()
  local endGameShown = false;
  local endGameContext = ContextPtr:LookUpControl("/InGame/EndGameMenu");
  if(endGameContext) then
    endGameShown = not endGameContext:IsHidden();
  end
  return endGameShown;
end

function OnMultiplayerGameLastPlayer()
  -- Only show the last player popup in multiplayer games where the session is a going concern
  if(GameConfiguration.IsNetworkMultiplayer()
  and not Network.IsSessionInCloseState()
  -- suppress popup when the end game screen is up.
  -- This specifically prevents a turn spinning issue that can occur if the host migrates to a dead human player on the defeated screen. TTP 18902
  and not IsEndGameMenuShown()) then
    local lastPlayerStr = Locale.Lookup( "TXT_KEY_MP_LAST_PLAYER" );
    local lastPlayerTitleStr = Locale.Lookup( "TXT_KEY_MP_LAST_PLAYER_TITLE" );
    local okStr = Locale.Lookup( "LOC_OK_BUTTON" );
    local pPopupDialog :table = PopupDialogInGame:new("LastPlayer");
    pPopupDialog:AddTitle(lastPlayerTitleStr);
    pPopupDialog:AddText(lastPlayerStr);
    pPopupDialog:AddDefaultButton(okStr, nil );
    pPopupDialog:Open();
  end
end

-- ===========================================================================
--  ENGINE Event
-- ===========================================================================
function OnMultiplayerGameAbandoned(eReason)
  if(GameConfiguration.IsNetworkMultiplayer()) then
    local errorStr = Locale.Lookup( "LOC_GAME_ABANDONED_CONNECTION_LOST" );
    local exitStr = Locale.Lookup( "LOC_GAME_MENU_EXIT_TO_MAIN" );

    -- Select error message based on KickReason.
    -- Not all of these should be possible while in game but we include them anyway.
    if (eReason == KickReason.KICK_HOST) then
      errorStr = Locale.Lookup( "LOC_GAME_ABANDONED_KICKED" );
    elseif (eReason == KickReason.KICK_NO_HOST) then
      errorStr = Locale.Lookup( "LOC_GAME_ABANDONED_HOST_LOSTED" );
    elseif (eReason == KickReason.KICK_NO_ROOM) then
      errorStr = Locale.Lookup( "LOC_GAME_ABANDONED_ROOM_FULL" );
    elseif (eReason == KickReason.KICK_VERSION_MISMATCH) then
      errorStr = Locale.Lookup( "LOC_GAME_ABANDONED_VERSION_MISMATCH" );
    elseif (eReason == KickReason.KICK_MOD_ERROR) then
      errorStr = Locale.Lookup( "LOC_GAME_ABANDONED_MOD_ERROR" );
    end

    local pPopupDialog :table = PopupDialogInGame:new("PlayerKicked");
    pPopupDialog:AddText(errorStr);
    pPopupDialog:AddDefaultButton(exitStr,
      function()
        Events.ExitToMainMenu();
      end);
    pPopupDialog:Open();
  end
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnTutorial_ConstrainMovement( plotID:number )
  m_constrainToPlotID = plotID;
end

-- ===========================================================================
--  LUA Event
--  Effectively turns on/off ability to drag pan the map.
-- ===========================================================================
function OnTutorial_DisableMapDrag( isDisabled:boolean )
  m_isMapDragDisabled = isDisabled;
end

-- ===========================================================================
--  LUA Event
--  Turns off canceling an event via a cancel action
--  (e.g., right click for district placement)
-- ===========================================================================
function OnTutorial_DisableMapCancel( isDisabled:boolean )
  m_isCancelDisabled = isDisabled;
end

-- ===========================================================================
--  LUA Event
--  Effectively turns on/off ability to deselect unit.
--  exceptionHexIds (optional) a list of hex Ids that are still permitted to
--          be selected even in this state.
-- ===========================================================================
function OnTutorial_DisableMapSelect( isDisabled:boolean, kExceptionHexIds:table )
  if isDisabled then
    -- Set to either an empty table or the table of exception Ids if one was passed in.
    m_kTutorialPermittedHexes = (kExceptionHexIds ~= nil) and kExceptionHexIds or {};
  else
    m_kTutorialPermittedHexes = nil;  -- Disabling
  end
end

-- ===========================================================================
--  TEST
-- ===========================================================================
function Test()
  if (UI.GetHeadSelectedUnit() == nil) then
    print("Need head unit!");
    return false;
  end
  local kUnit     :table = UI.GetHeadSelectedUnit();
--  local startPlotId :table  = Map.GetPlot(sx, sy);
--  local endPlotId   :number = UI.GetCursorPlotID();

  local plots:table = UnitManager.GetReachableZonesOfControl( kUnit );
  if plots == nil then
    print("NIL plots return");
  else
    for k,v in pairs(plots) do
      print("LENSTest Plot: " .. tostring(k) .. " = " .. tostring(v) );
    end
  end
  return true;
end


-- ===========================================================================
--  UI Event
--  Input Event Processing
-- ===========================================================================
function OnInputHandler( pInputStruct:table )

  local uiMsg :number = pInputStruct:GetMessageType();
  local mode  :number = UI.GetInterfaceMode();

  if uiMsg == MouseEvents.PointerLeave then
    ClearAllCachedInputState();
    ProcessPan(0,0);
    return;
  end


  -- DEBUG: T for Test (remove eventually; or at least comment out)
  --if pInputStruct:GetKey() == Keys.T and pInputStruct:IsControlDown() and pInputStruct:IsShiftDown() then
  if pInputStruct:GetKey() == Keys.T and pInputStruct:IsAltDown() and pInputStruct:IsControlDown() then
    return Test();  --??TRON
  end

  -- Set internal represenation of inputs.
  m_isMouseButtonLDown = pInputStruct:IsLButtonDown();
  m_isMouseButtonRDown = pInputStruct:IsRButtonDown();
  m_isMouseButtonMDown = pInputStruct:IsMButtonDown();

  -- Prevent "sticky" button down issues where a mouse release occurs else-where in UI so this context is unaware.
  g_isMouseDownInWorld = m_isMouseButtonLDown or m_isMouseButtonRDown or m_isMouseButtonMDown;

  -- TODO:  Below is test showing endPlot is not updating fast enough via event system
  --      (even with ImmediatePublish) and a direct/alternative way into the pathfinder
  --      needs to be added.  Remove once new update paradigm is added. --??TRON debug:
  --local endPlotId :number = UI.GetCursorPlotID();
  --print("endPlotId, ",endPlotId,uiMsg);

  -- Only except touch "up" or "move", if a mouse "down" occurred in the world.
  if g_isTouchEnabled then
    m_touchCount = TouchManager:GetTouchPointCount();

    -- Show touch ID in squares
    if m_isDebuging then
      local kTouchIds:table = {};
      if m_touchCount > 0 then
        Controls.a1:SetToBeginning();
        Controls.a1:Play();
        local index:number = next(m_kTouchesDownInWorld,nil);
        table.insert(kTouchIds, index);
        if m_touchCount > 1 then
          Controls.a2:SetToBeginning();
          Controls.a2:Play();
          index = next(m_kTouchesDownInWorld,index);
          table.insert(kTouchIds, index);
          if m_touchCount > 2 then
            Controls.a3:SetToBeginning();
            Controls.a3:Play();
            index = next(m_kTouchesDownInWorld,index);
            table.insert(kTouchIds, index);
          end
        end
      end
      table.sort(kTouchIds);
      if m_touchCount > 0 then Controls.t1:SetText(tostring(kTouchIds[1])); end
      if m_touchCount > 1 then Controls.t2:SetText(tostring(kTouchIds[2])); end
      if m_touchCount > 2 then Controls.t3:SetText(tostring(kTouchIds[3])); end
    end

    if uiMsg == MouseEvents.PointerUpdate then
      if m_kTouchesDownInWorld[ pInputStruct:GetTouchID() ] == nil then
        return false; -- Touch "down" did not occur in this context; ignore related touch sequence input.
      end
    elseif uiMsg == MouseEvents.PointerUp then
      -- Stop plot tool tippin' if more or less than 2 digits
      if m_touchCount < 2 then
        LuaEvents.WorldInput_TouchPlotTooltipHide();
      end
      if m_kTouchesDownInWorld[ pInputStruct:GetTouchID() ] == nil then
        return false; -- Touch "down" did not occur in this context; ignore related touch sequence input.
      end
      m_kTouchesDownInWorld[ pInputStruct:GetTouchID() ] = nil;
    elseif uiMsg == MouseEvents.PointerDown then
      m_kTouchesDownInWorld[ pInputStruct:GetTouchID() ] = true;
      -- If the 2nd touch occurs in the world (first one doesn't) then use it
      -- like a mouse for plot tool tips.
      if m_touchCount == 2 and not TouchManager:IsTouchToolTipDisabled() then
        LuaEvents.WorldInput_TouchPlotTooltipShow( pInputStruct:GetTouchID() );
      end
    end
  end

  local isHandled:boolean = false;

  -- Get the handler for the mode
  local modeHandler = InterfaceModeMessageHandler[mode];

  -- Is it valid and is able to handle this message?
  if modeHandler and modeHandler[uiMsg] then
    isHandled = modeHandler[uiMsg]( pInputStruct );
  elseif DefaultMessageHandler[uiMsg] then
    isHandled = DefaultMessageHandler[uiMsg]( pInputStruct );
  end

  -- Do this after the handler has completed as it may be making decisions based on if mouse dragging occurred.
  if not g_isMouseDownInWorld and g_isMouseDragging then
    --print("Forced mouse dragging false!");
    g_isMouseDragging = false;  -- No mouse down, no dragging is occuring!
  end


  return isHandled;
end


-- ===========================================================================
--  UI Event
--  Per-frame (e.g., expensive) event.
-- ===========================================================================
function OnRefresh()
  -- If there is a panning delta, and screen can pan, do the pan and request
  -- this is refreshed again.
  --if (m_edgePanX ~= 0 or m_edgePanY ~= 0) and IsAbleToEdgePan() then
  --  RealizePan();
  --  ContextPtr:RequestRefresh()
  --end
end


-- ===========================================================================
--
-- ===========================================================================
function ClearAllCachedInputState()
  m_isALTDown     = false;
  m_isUPpressed       = false;
  m_isDOWNpressed     = false;
  m_isLEFTpressed     = false;
  m_isRIGHTpressed    = false;

  m_isDoubleTapping = false;
  g_isMouseDownInWorld= false;
  m_isMouseButtonLDown= false;
  m_isMouseButtonMDown= false;
  m_isMouseButtonRDown= false;
  g_isMouseDragging = false;
  m_isTouchDragging = false;
  m_isTouchZooming  = false;
  m_isTouchPathing  = false;
  m_mapZoomStart    = 0;
  m_dragStartFocusWorldX = 0;
  m_dragStartFocusWorldY = 0;
  m_dragStartWorldX = 0;
  m_dragStartWorldY = 0;
  m_dragStartX    = 0;
  m_dragStartY    = 0;
  m_dragX       = 0;
  m_dragY       = 0;
  m_edgePanX      = 0.0;
  m_edgePanY      = 0.0;
  m_touchTotalNum   = 0;
  m_touchStartPlotX = -1;
  m_touchStartPlotY = -1;
  ms_bGridOn      = true;

  CQUI_isShiftDown = false;
end


-- ===========================================================================
--  UI Event
--  Called whenever the application regains focus.
-- ===========================================================================
function OnAppRegainedFocusHandler()
  ClearAllCachedInputState();
  ProcessPan(m_edgePanX,m_edgePanY);
end


-- ===========================================================================
--  UI Event
--  Called whenever the application loses focus.
-- ===========================================================================
function OnAppLostFocusHandler()
  ClearAllCachedInputState();
  ProcessPan(0,0);
end


-- ===========================================================================
--  UI Event
-- ===========================================================================
function OnShutdown()
  -- Clean up events
  Events.CycleUnitSelectionRequest.Remove( OnCycleUnitSelectionRequest );
  Events.InterfaceModeChanged.Remove( OnInterfaceModeChanged );

  LuaEvents.Tutorial_ConstrainMovement.Remove( OnTutorial_ConstrainMovement );
  LuaEvents.Tutorial_DisableMapDrag.Remove( OnTutorial_DisableMapDrag );
  LuaEvents.Tutorial_DisableMapSelect.Remove( OnTutorial_DisableMapSelect );
end

-- ===========================================================================
--  Hotkey Event
-- ===========================================================================
function OnInputActionTriggered( actionId )
  if actionId == m_actionHotkeyToggleGrid then
    LuaEvents.MinimapPanel_ToggleGrid();
    LuaEvents.MinimapPanel_RefreshMinimapOptions();
    UI.PlaySound("Play_UI_Click");
  elseif actionId == m_actionHotkeyToggleRes then
    if UserConfiguration.ShowMapResources() then
      UserConfiguration.ShowMapResources( false );
    else
      UserConfiguration.ShowMapResources( true );
    end
    UI.PlaySound("Play_UI_Click");
    LuaEvents.MinimapPanel_RefreshMinimapOptions();
  elseif actionId == m_actionHotkeyToggleYield then
    if UserConfiguration.ShowMapYield() then    -- yield already visible, hide
      LuaEvents.MinimapPanel_HideYieldIcons();
      UserConfiguration.ShowMapYield( false );
    else
      LuaEvents.MinimapPanel_ShowYieldIcons();
      UserConfiguration.ShowMapYield( true );
    end
    LuaEvents.MinimapPanel_RefreshMinimapOptions();
    UI.PlaySound("Play_UI_Click");
  elseif actionId == m_actionHotkeyPrevUnit then
    UI.SelectPrevReadyUnit();
    UI.PlaySound("Play_UI_Click");
  elseif actionId == m_actionHotkeyNextUnit then
    UI.SelectNextReadyUnit();
    UI.PlaySound("Play_UI_Click");
  elseif actionId == m_actionHotkeyPrevCity then
    LuaEvents.CQUI_GoPrevCity();
    UI.PlaySound("Play_UI_Click");
  elseif actionId == m_actionHotkeyNextCity then
    LuaEvents.CQUI_GoNextCity();
    UI.PlaySound("Play_UI_Click");
  elseif actionId == m_actionHotkeyCapitalCity then
    local capital;
    local ePlayer = Game.GetLocalPlayer();
    local player = Players[ePlayer];
    if(player) then
      local cities = player:GetCities();
      for i, city in cities:Members() do
        if(city:IsCapital()) then
          capital = city;
          break;
        end
      end
    end

    if(capital) then
      UI.SelectNextCity(capital);
      UI.PlaySound("Play_UI_Click");
    end
  elseif actionId == m_actionHotkeyOnlinePause then
    if GameConfiguration.IsNetworkMultiplayer() then
      TogglePause();
    end
  end
end

-- ===========================================================================
--  INCLUDES
--  Other handlers & helpers that may utilze functionality defined in here
-- ===========================================================================

include ("StrategicView_MapPlacement"); -- handlers for: BUILDING_PLACEMENT, DISTRICT_PLACEMENT
include ("StrategicView_DebugSupport"); -- the Debug interface mode


-- ===========================================================================
--  Assign callbacks
-- ===========================================================================
function Initialize()

  g_isTouchEnabled = Options.GetAppOption("UI", "IsTouchScreenEnabled") ~= 0;

  -- Input assignments.

  -- Default handlers:
  DefaultMessageHandler[KeyEvents.KeyDown] = OnDefaultKeyDown;
  DefaultMessageHandler[KeyEvents.KeyUp] = OnDefaultKeyUp;
  DefaultMessageHandler[MouseEvents.LButtonDown] = OnMouseStart;
  DefaultMessageHandler[MouseEvents.LButtonUp] = OnMouseEnd;
  DefaultMessageHandler[MouseEvents.MouseMove] = OnMouseMove;
  DefaultMessageHandler[MouseEvents.RButtonUp] = OnDefaultChangeToSelectionMode;
  DefaultMessageHandler[MouseEvents.PointerUp] = OnDefaultChangeToSelectionMode;
  DefaultMessageHandler[MouseEvents.MouseWheel] = OnMouseWheelZoom;
  DefaultMessageHandler[MouseEvents.MButtonDown] = OnMouseSelectionSnapToPlot;

  -- Interface Mode ENTERING :
  InterfaceModeMessageHandler[InterfaceModeTypes.AIR_ATTACK]      [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_Air_Attack;
  InterfaceModeMessageHandler[InterfaceModeTypes.DEBUG]       [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_Debug;
  InterfaceModeMessageHandler[InterfaceModeTypes.CITY_MANAGEMENT]   [INTERFACEMODE_ENTER]   = OnInterfaceModeEnter_CityManagement;
  InterfaceModeMessageHandler[InterfaceModeTypes.WMD_STRIKE]      [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_WMD_Strike;
  InterfaceModeMessageHandler[InterfaceModeTypes.ICBM_STRIKE]     [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_ICBM_Strike;
  InterfaceModeMessageHandler[InterfaceModeTypes.COASTAL_RAID]    [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_CoastalRaid;
  InterfaceModeMessageHandler[InterfaceModeTypes.BUILDING_PLACEMENT]  [INTERFACEMODE_ENTER]   = OnInterfaceModeEnter_BuildingPlacement; -- StrategicView_MapPlacement.lua
  InterfaceModeMessageHandler[InterfaceModeTypes.CITY_RANGE_ATTACK] [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_CityRangeAttack;
  InterfaceModeMessageHandler[InterfaceModeTypes.DEPLOY]        [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_Deploy;
  InterfaceModeMessageHandler[InterfaceModeTypes.DISTRICT_PLACEMENT]  [INTERFACEMODE_ENTER]   = OnInterfaceModeEnter_DistrictPlacement; -- StrategicView_MapPlacement.lua
  InterfaceModeMessageHandler[InterfaceModeTypes.DISTRICT_RANGE_ATTACK][INTERFACEMODE_ENTER]    = OnInterfaceModeChange_DistrictRangeAttack;
  InterfaceModeMessageHandler[InterfaceModeTypes.FORM_ARMY]     [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_UnitFormArmy;
  InterfaceModeMessageHandler[InterfaceModeTypes.FORM_CORPS]      [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_UnitFormCorps;
  InterfaceModeMessageHandler[InterfaceModeTypes.AIRLIFT]       [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_UnitAirlift;
  InterfaceModeMessageHandler[InterfaceModeTypes.MAKE_TRADE_ROUTE]  [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_MakeTradeRoute;
  InterfaceModeMessageHandler[InterfaceModeTypes.TELEPORT_TO_CITY]  [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_TeleportToCity;
  InterfaceModeMessageHandler[InterfaceModeTypes.MOVE_TO]       [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_MoveTo;
  InterfaceModeMessageHandler[InterfaceModeTypes.RANGE_ATTACK]    [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_UnitRangeAttack;
  InterfaceModeMessageHandler[InterfaceModeTypes.REBASE]        [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_ReBase;
  InterfaceModeMessageHandler[InterfaceModeTypes.SELECTION]     [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_Selection;
  InterfaceModeMessageHandler[InterfaceModeTypes.MOVE_TO]       [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_MoveTo;
  InterfaceModeMessageHandler[InterfaceModeTypes.PLACE_MAP_PIN]   [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_PlaceMapPin;
  InterfaceModeMessageHandler[InterfaceModeTypes.WB_SELECT_PLOT]    [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_WBSelectPlot;
  InterfaceModeMessageHandler[InterfaceModeTypes.SPY_CHOOSE_MISSION]  [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_SpyChooseMission;
  InterfaceModeMessageHandler[InterfaceModeTypes.SPY_TRAVEL_TO_CITY]  [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_SpyTravelToCity;
  InterfaceModeMessageHandler[InterfaceModeTypes.NATURAL_WONDER]    [INTERFACEMODE_ENTER]   = OnInterfaceModeChange_NaturalWonder;

  -- Interface Mode LEAVING (optional):
  InterfaceModeMessageHandler[InterfaceModeTypes.BUILDING_PLACEMENT]    [INTERFACEMODE_LEAVE]   = OnInterfaceModeLeave_BuildingPlacement; -- StrategicView_MapPlacement.lua
  InterfaceModeMessageHandler[InterfaceModeTypes.CITY_MANAGEMENT]     [INTERFACEMODE_LEAVE]   = OnInterfaceModeLeave_CityManagement;
  InterfaceModeMessageHandler[InterfaceModeTypes.DISTRICT_PLACEMENT]    [INTERFACEMODE_LEAVE]   = OnInterfaceModeLeave_DistrictPlacement; -- StrategicView_MapPlacement.lua
  InterfaceModeMessageHandler[InterfaceModeTypes.MOVE_TO]         [INTERFACEMODE_LEAVE]   = OnInterfaceModeChange_MoveToLeave;
  InterfaceModeMessageHandler[InterfaceModeTypes.RANGE_ATTACK]      [INTERFACEMODE_LEAVE]   = OnInterfaceModeLeave_UnitRangeAttack;
  InterfaceModeMessageHandler[InterfaceModeTypes.NATURAL_WONDER]      [INTERFACEMODE_LEAVE]   = OnInterfaceModeLeave_NaturalWonder;
  InterfaceModeMessageHandler[InterfaceModeTypes.CITY_RANGE_ATTACK]   [INTERFACEMODE_LEAVE]   = OnInterfaceModeLeave_CityRangeAttack;
  InterfaceModeMessageHandler[InterfaceModeTypes.DISTRICT_RANGE_ATTACK] [INTERFACEMODE_LEAVE]   = OnInterfaceModeLeave_DistrictRangeAttack;
  InterfaceModeMessageHandler[InterfaceModeTypes.AIR_ATTACK]        [INTERFACEMODE_LEAVE]   = OnInterfaceModeLeave_Air_Attack;
  InterfaceModeMessageHandler[InterfaceModeTypes.WMD_STRIKE]        [INTERFACEMODE_LEAVE]   = OnInterfaceModeLeave_WMD_Strike;
  InterfaceModeMessageHandler[InterfaceModeTypes.ICBM_STRIKE]       [INTERFACEMODE_LEAVE]   = OnInterfaceModeLeave_ICBM_Strike;
  InterfaceModeMessageHandler[InterfaceModeTypes.COASTAL_RAID]      [INTERFACEMODE_LEAVE]   = OnInterfaceModeLeave_CoastalRaid;
  InterfaceModeMessageHandler[InterfaceModeTypes.DEPLOY]          [INTERFACEMODE_LEAVE]   = OnInterfaceModeLeave_Deploy;
  InterfaceModeMessageHandler[InterfaceModeTypes.REBASE]          [INTERFACEMODE_LEAVE]   = OnInterfaceModeLeave_ReBase;
  InterfaceModeMessageHandler[InterfaceModeTypes.TELEPORT_TO_CITY]    [INTERFACEMODE_LEAVE]   = OnInterfaceModeLeave_TeleportToCity;
  InterfaceModeMessageHandler[InterfaceModeTypes.FORM_CORPS]        [INTERFACEMODE_LEAVE]   = OnInterfaceModeLeave_UnitFormCorps;
  InterfaceModeMessageHandler[InterfaceModeTypes.FORM_ARMY]       [INTERFACEMODE_LEAVE]   = OnInterfaceModeLeave_UnitFormArmy;
  InterfaceModeMessageHandler[InterfaceModeTypes.AIRLIFT]         [INTERFACEMODE_LEAVE]   = OnInterfaceModeLeave_UnitAirlift;

  -- Keyboard Events (all happen on up!)
  InterfaceModeMessageHandler[InterfaceModeTypes.BUILDING_PLACEMENT]    [KeyEvents.KeyUp] = OnPlacementKeyUp;
  InterfaceModeMessageHandler[InterfaceModeTypes.CITY_MANAGEMENT]       [KeyEvents.KeyUp] = OnPlacementKeyUp;
  InterfaceModeMessageHandler[InterfaceModeTypes.DISTRICT_PLACEMENT]    [KeyEvents.KeyUp] = OnPlacementKeyUp;
  InterfaceModeMessageHandler[InterfaceModeTypes.MOVE_TO]               [KeyEvents.KeyUp] = OnPlacementKeyUp;
  InterfaceModeMessageHandler[InterfaceModeTypes.RANGE_ATTACK]          [KeyEvents.KeyUp] = OnPlacementKeyUp;
  InterfaceModeMessageHandler[InterfaceModeTypes.NATURAL_WONDER]        [KeyEvents.KeyUp] = OnPlacementKeyUp;
  InterfaceModeMessageHandler[InterfaceModeTypes.CITY_RANGE_ATTACK]     [KeyEvents.KeyUp] = OnPlacementKeyUp;
  InterfaceModeMessageHandler[InterfaceModeTypes.DISTRICT_RANGE_ATTACK] [KeyEvents.KeyUp] = OnPlacementKeyUp;
  InterfaceModeMessageHandler[InterfaceModeTypes.WMD_STRIKE]            [KeyEvents.KeyUp] = OnPlacementKeyUp;
  InterfaceModeMessageHandler[InterfaceModeTypes.ICBM_STRIKE]           [KeyEvents.KeyUp] = OnPlacementKeyUp;
  InterfaceModeMessageHandler[InterfaceModeTypes.AIR_ATTACK]            [KeyEvents.KeyUp] = OnPlacementKeyUp;
  InterfaceModeMessageHandler[InterfaceModeTypes.COASTAL_RAID]          [KeyEvents.KeyUp] = OnPlacementKeyUp;
  InterfaceModeMessageHandler[InterfaceModeTypes.DEPLOY]                [KeyEvents.KeyUp] = OnPlacementKeyUp;
  InterfaceModeMessageHandler[InterfaceModeTypes.REBASE]                [KeyEvents.KeyUp] = OnPlacementKeyUp;
  InterfaceModeMessageHandler[InterfaceModeTypes.TELEPORT_TO_CITY]      [KeyEvents.KeyUp] = OnPlacementKeyUp;
  InterfaceModeMessageHandler[InterfaceModeTypes.FORM_CORPS]            [KeyEvents.KeyUp] = OnPlacementKeyUp;
  InterfaceModeMessageHandler[InterfaceModeTypes.FORM_ARMY]             [KeyEvents.KeyUp] = OnPlacementKeyUp;
  InterfaceModeMessageHandler[InterfaceModeTypes.AIRLIFT]               [KeyEvents.KeyUp] = OnPlacementKeyUp;




  -- Mouse Events
  InterfaceModeMessageHandler[InterfaceModeTypes.DEBUG]       [MouseEvents.LButtonUp]   = OnMouseDebugEnd;
  InterfaceModeMessageHandler[InterfaceModeTypes.DEBUG]       [MouseEvents.RButtonUp]   = OnDebugCancelPlacement;
  InterfaceModeMessageHandler[InterfaceModeTypes.SELECTION]     [MouseEvents.LButtonUp]   = OnMouseSelectionEnd;
  InterfaceModeMessageHandler[InterfaceModeTypes.SELECTION]     [MouseEvents.RButtonDown] = OnMouseSelectionUnitMoveStart;
  InterfaceModeMessageHandler[InterfaceModeTypes.SELECTION]     [MouseEvents.RButtonUp]   = OnMouseSelectionUnitMoveEnd;
  InterfaceModeMessageHandler[InterfaceModeTypes.SELECTION]     [MouseEvents.MButtonDown] = OnMouseSelectionSnapToPlot;
  InterfaceModeMessageHandler[InterfaceModeTypes.SELECTION]     [MouseEvents.MouseMove]   = OnMouseSelectionMove;
  InterfaceModeMessageHandler[InterfaceModeTypes.SELECTION]     [MouseEvents.LButtonDoubleClick] = OnSelectionDoubleTap;
  InterfaceModeMessageHandler[InterfaceModeTypes.VIEW_MODAL_LENS]   [MouseEvents.LButtonUp]   = OnMouseSelectionEnd;
  InterfaceModeMessageHandler[InterfaceModeTypes.MAKE_TRADE_ROUTE]  [MouseEvents.LButtonUp]   = OnMouseMakeTradeRouteEnd;
  InterfaceModeMessageHandler[InterfaceModeTypes.MAKE_TRADE_ROUTE]  [MouseEvents.MButtonDown] = OnMouseMakeTradeRouteSnapToPlot;
  InterfaceModeMessageHandler[InterfaceModeTypes.TELEPORT_TO_CITY]  [MouseEvents.LButtonUp]   = OnMouseTeleportToCityEnd;
  InterfaceModeMessageHandler[InterfaceModeTypes.TELEPORT_TO_CITY]  [MouseEvents.MButtonDown] = OnMouseTeleportToCitySnapToPlot;
  InterfaceModeMessageHandler[InterfaceModeTypes.DISTRICT_PLACEMENT]  [MouseEvents.LButtonUp]   = OnMouseDistrictPlacementEnd;
  InterfaceModeMessageHandler[InterfaceModeTypes.DISTRICT_PLACEMENT]  [MouseEvents.RButtonUp]   = OnMouseDistrictPlacementCancel;
  InterfaceModeMessageHandler[InterfaceModeTypes.DISTRICT_PLACEMENT]  [MouseEvents.MouseMove]   = OnMouseDistrictPlacementMove;
  InterfaceModeMessageHandler[InterfaceModeTypes.MOVE_TO]       [MouseEvents.LButtonDown] = OnMouseMoveToStart;
  InterfaceModeMessageHandler[InterfaceModeTypes.MOVE_TO]       [MouseEvents.LButtonUp]   = OnMouseMoveToEnd;
  InterfaceModeMessageHandler[InterfaceModeTypes.MOVE_TO]       [MouseEvents.MouseMove]   = OnMouseMoveToUpdate;
  InterfaceModeMessageHandler[InterfaceModeTypes.MOVE_TO]       [MouseEvents.RButtonUp]   = OnMouseMoveToCancel;
  InterfaceModeMessageHandler[InterfaceModeTypes.RANGE_ATTACK]    [MouseEvents.LButtonUp]   = OnMouseUnitRangeAttack;
  InterfaceModeMessageHandler[InterfaceModeTypes.RANGE_ATTACK]    [MouseEvents.MouseMove]   = OnMouseMoveRangeAttack;
  InterfaceModeMessageHandler[InterfaceModeTypes.DISTRICT_RANGE_ATTACK][MouseEvents.MouseMove]  = OnMouseMoveRangeAttack;
  InterfaceModeMessageHandler[InterfaceModeTypes.DISTRICT_RANGE_ATTACK][MouseEvents.LButtonUp]  = DistrictRangeAttack;
  InterfaceModeMessageHandler[InterfaceModeTypes.BUILDING_PLACEMENT]  [MouseEvents.LButtonUp]   = OnMouseBuildingPlacementEnd;
  InterfaceModeMessageHandler[InterfaceModeTypes.BUILDING_PLACEMENT]  [MouseEvents.RButtonUp]   = OnMouseBuildingPlacementCancel;
  InterfaceModeMessageHandler[InterfaceModeTypes.BUILDING_PLACEMENT]  [MouseEvents.MouseMove]   = OnMouseBuildingPlacementMove;
  InterfaceModeMessageHandler[InterfaceModeTypes.CITY_RANGE_ATTACK] [MouseEvents.LButtonUp]   = CityRangeAttack;
  InterfaceModeMessageHandler[InterfaceModeTypes.CITY_RANGE_ATTACK] [MouseEvents.MouseMove]   = OnMouseMoveRangeAttack;
  InterfaceModeMessageHandler[InterfaceModeTypes.FORM_CORPS]      [MouseEvents.LButtonUp]   = FormCorps;
  InterfaceModeMessageHandler[InterfaceModeTypes.FORM_ARMY]     [MouseEvents.LButtonUp]   = FormArmy;
  InterfaceModeMessageHandler[InterfaceModeTypes.AIRLIFT]       [MouseEvents.LButtonUp]   = OnMouseAirliftEnd;
  InterfaceModeMessageHandler[InterfaceModeTypes.AIR_ATTACK]      [MouseEvents.LButtonUp]   = UnitAirAttack;
  InterfaceModeMessageHandler[InterfaceModeTypes.WMD_STRIKE]      [MouseEvents.LButtonUp]   = OnWMDStrikeEnd;
  InterfaceModeMessageHandler[InterfaceModeTypes.WMD_STRIKE]      [MouseEvents.MouseMove]   = OnMouseMoveRangeAttack;
  InterfaceModeMessageHandler[InterfaceModeTypes.ICBM_STRIKE]     [MouseEvents.LButtonUp]   = OnICBMStrikeEnd;
  InterfaceModeMessageHandler[InterfaceModeTypes.ICBM_STRIKE]     [MouseEvents.MouseMove]   = OnMouseMoveRangeAttack;
  InterfaceModeMessageHandler[InterfaceModeTypes.DEPLOY]        [MouseEvents.LButtonUp]   = OnMouseDeployEnd;
  InterfaceModeMessageHandler[InterfaceModeTypes.REBASE]        [MouseEvents.LButtonUp]   = OnMouseRebaseEnd;
  InterfaceModeMessageHandler[InterfaceModeTypes.COASTAL_RAID]    [MouseEvents.LButtonUp]   = CoastalRaid;
  InterfaceModeMessageHandler[InterfaceModeTypes.PLACE_MAP_PIN]   [MouseEvents.LButtonUp]   = PlaceMapPin;
  InterfaceModeMessageHandler[InterfaceModeTypes.WB_SELECT_PLOT]    [MouseEvents.LButtonUp]   = OnMouseEnd_WBSelectPlot;
  InterfaceModeMessageHandler[InterfaceModeTypes.WB_SELECT_PLOT]    [MouseEvents.RButtonUp]   = OnRButtonUp_WBSelectPlot;
  InterfaceModeMessageHandler[InterfaceModeTypes.WB_SELECT_PLOT]    [MouseEvents.MouseMove]   = OnMouseMove_WBSelectPlot;

  -- Touch Events (if a touch system)
  if g_isTouchEnabled then
    InterfaceModeMessageHandler[InterfaceModeTypes.DEBUG]       [MouseEvents.PointerDown] = OnTouchStart;
    InterfaceModeMessageHandler[InterfaceModeTypes.DEBUG]       [MouseEvents.PointerUpdate] = OnTouchUpdate;
    InterfaceModeMessageHandler[InterfaceModeTypes.DEBUG]       [MouseEvents.PointerUp]   = OnTouchDebugEnd;
    InterfaceModeMessageHandler[InterfaceModeTypes.SELECTION]     [MouseEvents.PointerDown] = OnTouchSelectionStart;
    InterfaceModeMessageHandler[InterfaceModeTypes.SELECTION]     [MouseEvents.PointerUpdate] = OnTouchSelectionUpdate;
    InterfaceModeMessageHandler[InterfaceModeTypes.SELECTION]     [MouseEvents.PointerUp]   = OnTouchSelectionEnd;
    InterfaceModeMessageHandler[InterfaceModeTypes.MAKE_TRADE_ROUTE]  [MouseEvents.PointerDown] = OnTouchStart;
    InterfaceModeMessageHandler[InterfaceModeTypes.MAKE_TRADE_ROUTE]  [MouseEvents.PointerUpdate] = OnTouchUpdate;
    InterfaceModeMessageHandler[InterfaceModeTypes.MAKE_TRADE_ROUTE]  [MouseEvents.PointerUp]   = OnTouchTradeRouteEnd;
    InterfaceModeMessageHandler[InterfaceModeTypes.TELEPORT_TO_CITY]  [MouseEvents.PointerDown] = OnTouchStart;
    InterfaceModeMessageHandler[InterfaceModeTypes.TELEPORT_TO_CITY]  [MouseEvents.PointerUpdate] = OnTouchUpdate;
    InterfaceModeMessageHandler[InterfaceModeTypes.TELEPORT_TO_CITY]  [MouseEvents.PointerUp]   = OnTouchTeleportToCityEnd;
    InterfaceModeMessageHandler[InterfaceModeTypes.DISTRICT_PLACEMENT]  [MouseEvents.PointerDown] = OnTouchStart;
    InterfaceModeMessageHandler[InterfaceModeTypes.DISTRICT_PLACEMENT]  [MouseEvents.PointerUpdate] = OnTouchUpdate;
    InterfaceModeMessageHandler[InterfaceModeTypes.DISTRICT_PLACEMENT]  [MouseEvents.PointerUp]   = OnTouchDistrictPlacementEnd;
    InterfaceModeMessageHandler[InterfaceModeTypes.MOVE_TO]       [MouseEvents.PointerDown] = OnTouchMoveToStart;
    InterfaceModeMessageHandler[InterfaceModeTypes.MOVE_TO]       [MouseEvents.PointerUpdate] = OnTouchMoveToUpdate;
    InterfaceModeMessageHandler[InterfaceModeTypes.MOVE_TO]       [MouseEvents.PointerUp]   = OnTouchMoveToEnd;
    InterfaceModeMessageHandler[InterfaceModeTypes.BUILDING_PLACEMENT]  [MouseEvents.PointerDown] = OnTouchStart;
    InterfaceModeMessageHandler[InterfaceModeTypes.BUILDING_PLACEMENT]  [MouseEvents.PointerUpdate] = OnTouchUpdate;
    InterfaceModeMessageHandler[InterfaceModeTypes.BUILDING_PLACEMENT]  [MouseEvents.PointerUp]   = OnTouchBuildingPlacementEnd;
    InterfaceModeMessageHandler[InterfaceModeTypes.CITY_RANGE_ATTACK] [MouseEvents.PointerUp]   = CityRangeAttack;
    InterfaceModeMessageHandler[InterfaceModeTypes.DISTRICT_RANGE_ATTACK][MouseEvents.PointerUp]  = DistrictRangeAttack;
    InterfaceModeMessageHandler[InterfaceModeTypes.FORM_ARMY]     [MouseEvents.PointerUp]   = FormArmy;
    InterfaceModeMessageHandler[InterfaceModeTypes.FORM_CORPS]      [MouseEvents.PointerUp]   = FormCorps;
    InterfaceModeMessageHandler[InterfaceModeTypes.AIRLIFT]       [MouseEvents.PointerUp]   = Airlift;
    InterfaceModeMessageHandler[InterfaceModeTypes.RANGE_ATTACK]    [MouseEvents.PointerUp]   = OnTouchUnitRangeAttack;
    InterfaceModeMessageHandler[InterfaceModeTypes.AIR_ATTACK]      [MouseEvents.PointerUp]   = UnitAirAttack;
    InterfaceModeMessageHandler[InterfaceModeTypes.WMD_STRIKE]      [MouseEvents.PointerUp]   = OnWMDStrikeEnd;
    InterfaceModeMessageHandler[InterfaceModeTypes.ICBM_STRIKE]     [MouseEvents.PointerUp]   = OnICBMStrikeEnd;
    InterfaceModeMessageHandler[InterfaceModeTypes.DEPLOY]        [MouseEvents.PointerUp]   = AirUnitDeploy;
    InterfaceModeMessageHandler[InterfaceModeTypes.REBASE]        [MouseEvents.PointerUp]   = AirUnitReBase;
    InterfaceModeMessageHandler[InterfaceModeTypes.COASTAL_RAID]    [MouseEvents.PointerUp]   = CoastalRaid;
    InterfaceModeMessageHandler[InterfaceModeTypes.PLACE_MAP_PIN]   [MouseEvents.PointerUp]   = PlaceMapPin;
    InterfaceModeMessageHandler[InterfaceModeTypes.CITY_MANAGEMENT]   [MouseEvents.PointerUp]   = OnDoNothing;
  end


  -- ===== EVENTS =====

  -- Game Engine Events
  Events.CityMadePurchase.Add( OnCityMadePurchase_StrategicView_MapPlacement );
  Events.CycleUnitSelectionRequest.Add( OnCycleUnitSelectionRequest );
  Events.InputActionTriggered.Add( OnInputActionTriggered );
  Events.InterfaceModeChanged.Add(OnInterfaceModeChanged);
  Events.MultiplayerGameLastPlayer.Add(OnMultiplayerGameLastPlayer);
  Events.MultiplayerGameAbandoned.Add(OnMultiplayerGameAbandoned);
  Events.UnitSelectionChanged.Add( OnUnitSelectionChanged );

  -- LUA Events
  LuaEvents.Tutorial_ConstrainMovement.Add( OnTutorial_ConstrainMovement );
  LuaEvents.Tutorial_DisableMapDrag.Add( OnTutorial_DisableMapDrag );
  LuaEvents.Tutorial_DisableMapSelect.Add( OnTutorial_DisableMapSelect );
  LuaEvents.Tutorial_DisableMapCancel.Add( OnTutorial_DisableMapCancel );

  LuaEvents.Tutorial_AddUnitHexRestriction.Add( OnTutorial_AddUnitHexRestriction );
  LuaEvents.Tutorial_RemoveUnitHexRestriction.Add( OnTutorial_RemoveUnitHexRestriction );
  LuaEvents.Tutorial_ClearAllHexMoveRestrictions.Add( OnTutorial_ClearAllUnitHexRestrictions );

  LuaEvents.Tutorial_AddUnitMoveRestriction.Add( OnTutorial_AddUnitMoveRestriction );
  LuaEvents.Tutorial_RemoveUnitMoveRestrictions.Add( OnTutorial_RemoveUnitMoveRestrictions );

  LuaEvents.InGameTopOptionsMenu_Show.Add(function() m_isPauseMenuOpen = true; end);
  LuaEvents.InGameTopOptionsMenu_Close.Add(function() m_isPauseMenuOpen = false; ClearAllCachedInputState(); end);


  -- UI Events
  ContextPtr:SetInputHandler( OnInputHandler, true );
  ContextPtr:SetRefreshHandler( OnRefresh );
  ContextPtr:SetAppRegainedFocusHandler( OnAppRegainedFocusHandler );
  ContextPtr:SetAppLostFocusHandler( OnAppLostFocusHandler );
  ContextPtr:SetShutdown( OnShutdown );

  -- CQUI Events
  LuaEvents.CQUI_WorldInput_CityviewEnable.Add( function() CQUI_cityview = true; end );
  LuaEvents.CQUI_WorldInput_CityviewDisable.Add( function() CQUI_cityview = false; end );
  LuaEvents.CQUI_showUnitPath.Add(RealizeMovementPath);
  LuaEvents.CQUI_clearUnitPath.Add(ClearMovementPath);

  Controls.DebugStuff:SetHide(not m_isDebuging);
  -- Popup setup
  m_kConfirmWarDialog = PopupDialogInGame:new( "ConfirmWarPopup" );

end
Initialize();
