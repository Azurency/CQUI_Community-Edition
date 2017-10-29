-- ===========================================================================
--
--  Slideout panel that allows the player to move their trade units to other city centers
--
-- ===========================================================================
include("InstanceManager");
include("SupportFunctions");
include("AnimSidePanelSupport");
include("civ6common")

-- ===========================================================================
--  CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID:string = "TradeOriginChooser"; -- Must be unique (usually the same as the file name)

-- ===========================================================================
--  MEMBERS
-- ===========================================================================
local m_AnimSupport:table; --AnimSidePanelSupport

local m_cityIM:table = InstanceManager:new("CityInstance", "CityButton", Controls.CityStack);

local m_originCity = nil;
local m_newOriginCity = nil;

-- ===========================================================================
function Refresh()
  -- Find the selected trade unit
  local selectedUnit:table = UI.GetHeadSelectedUnit();
  if selectedUnit == nil then
    Close();
    return;
  end

  -- Find the current city
  m_originCity = Cities.GetCityInPlot(selectedUnit:GetX(), selectedUnit:GetY());

  if m_originCity == nil then
    Close();
    return;
  end

  RefreshHeader();

  -- Reset Instance Manager
  m_cityIM:ResetInstances();
  local cityIDs:table = {}

  -- Add all other cities to city stack
  local localPlayer = Players[Game.GetLocalPlayer()];
  local playerCities:table = localPlayer:GetCities();
  for _, city in playerCities:Members() do
    if city ~= m_originCity and CanTeleportToCity(city) then
      table.insert(cityIDs, city:GetID())
    end
  end

  -- Sort cities alphabetically
  local function comp(a, b)
    local playerCities = Players[Game.GetLocalPlayer()]:GetCities()
    local city1 = playerCities:FindID(a)
    local city2 = playerCities:FindID(b)
    return Locale.Lookup(city1:GetName()):upper() < Locale.Lookup(city2:GetName()):upper()
  end
  table.sort(cityIDs, comp)

  for _, cityID in ipairs(cityIDs) do
    AddCity(cityID)
  end

  -- Calculate Control Size
  Controls.CityStack:CalculateSize();
  Controls.CityStack:ReprocessAnchoring();
  Controls.CityScrollPanel:CalculateInternalSize();
end

-- ===========================================================================
function RefreshHeader()
  if m_newOriginCity then
    Controls.BannerBase:SetHide(false);
    Controls.ChangeOriginCityButton:SetHide(false);
    Controls.StatusMessage:SetHide(true);
    Controls.CityName:SetText(Locale.ToUpper(m_newOriginCity:GetName()));

    -- Update City Banner
    local backColor:number, frontColor:number  = UI.GetPlayerColors( m_newOriginCity:GetOwner() );
    local darkerBackColor:number = DarkenLightenColor(backColor,(-85),238);
    local brighterBackColor:number = DarkenLightenColor(backColor,90,255);

    Controls.BannerBase:SetColor( backColor );
    Controls.BannerDarker:SetColor( darkerBackColor );
    Controls.BannerLighter:SetColor( brighterBackColor );
    Controls.CityName:SetColor( frontColor );

    -- Update Icon
    local originPlayerConfig:table = PlayerConfigurations[m_newOriginCity:GetOwner()];
    local originPlayerIconString:string = "ICON_" .. originPlayerConfig:GetCivilizationTypeName();
    local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(originPlayerIconString, 22);
    local secondaryColor, primaryColor = UI.GetPlayerColors( m_newOriginCity:GetOwner() );
    local brighterIconColor:number = DarkenLightenColor(primaryColor,90,255);

    Controls.OriginCivIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
    Controls.OriginCivIcon:LocalizeAndSetToolTip( originPlayerConfig:GetCivilizationDescription() );
    Controls.OriginCivIcon:SetColor( primaryColor );
  else
    Controls.BannerBase:SetHide(true);
    Controls.ChangeOriginCityButton:SetHide(true);

    Controls.StatusMessage:SetHide(false);
    Controls.StatusMessage:SetText(Locale.Lookup("LOC_ORIGIN_CHOOSER_HEADER_BACKGROUND_TEXT"));
  end
end

-- ===========================================================================
function AddCity(cityID:number)
  local city = Players[Game.GetLocalPlayer()]:GetCities():FindID(cityID)
  print_debug("Adding city " .. Locale.Lookup(city:GetName()))
  local cityInstance:table = m_cityIM:GetInstance();
  cityInstance.CityButton:SetHide(false);
  cityInstance.CityButton:SetText(Locale.ToUpper(city:GetName()));

  if m_newOriginCity ~= nil and m_newOriginCity:GetID() == cityID then
    cityInstance.CityButton:SetTextureOffsetVal(0, 32*1)
  else
    cityInstance.CityButton:SetTextureOffsetVal(0, 32*0)
  end

  cityInstance.CityButton:RegisterCallback(Mouse.eLClick,
    function()
      m_newOriginCity = city;
      Refresh();
    end);
end

-- ===========================================================================
function OnChangeOriginCityButton()
  if ( m_newOriginCity ~= nil and m_originCity ~= nil ) then
    if ( m_newOriginCity:GetID() ~= m_originCity:GetID() ) then
      TeleportToCity(m_newOriginCity);
    else
      -- print (" cant teleport to the same city")
    end
  else
    print_debug("cities are nil")
  end
end

-- ===========================================================================
function CanTeleportToCity(city:table)
  local tParameters = {};
  tParameters[UnitOperationTypes.PARAM_X] = city:GetX();
  tParameters[UnitOperationTypes.PARAM_Y] = city:GetY();

  -- local eOperation = UI.GetInterfaceModeParameter(UnitOperationTypes.PARAM_OPERATION_TYPE);
  local eOperation = UnitOperationTypes.TELEPORT_TO_CITY

  local pSelectedUnit = UI.GetHeadSelectedUnit();
  if (UnitManager.CanStartOperation( pSelectedUnit, eOperation, nil, tParameters)) then
    return true;
  end

  return false;
end

-- ===========================================================================
function TeleportToCity(city:table)
  local tParameters = {};
  tParameters[UnitOperationTypes.PARAM_X] = city:GetX();
  tParameters[UnitOperationTypes.PARAM_Y] = city:GetY();

  -- local eOperation = UI.GetInterfaceModeParameter(UnitOperationTypes.PARAM_OPERATION_TYPE);
  local eOperation = UnitOperationTypes.TELEPORT_TO_CITY

  local pSelectedUnit = UI.GetHeadSelectedUnit();
  if (UnitManager.CanStartOperation( pSelectedUnit, eOperation, nil, tParameters)) then
    UnitManager.RequestOperation( pSelectedUnit, eOperation, tParameters);
    UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
    UI.PlaySound("Unit_Relocate");
    OnClose();
  end
end

-- ===========================================================================
function OnChangeOriginCityFromOverview( city:table )
  if city ~= nil then
    -- print ("Window opened from Trade Overview with city " .. Locale.Lookup(city:GetName()))
    local selectedUnit:table = UI.GetHeadSelectedUnit();

    m_originCity = Cities.GetCityInPlot(selectedUnit:GetX(), selectedUnit:GetY());
    m_newOriginCity = city

    -- print ("Transfer from " .. Locale.Lookup(m_originCity:GetName()) .. " to " .. Locale.Lookup(m_newOriginCity:GetName()))

    -- Is the screen already open?
    if (m_AnimSupport:IsVisible()) then
      Refresh();
    else
      print_debug("open sesame...")
      OnOpen();
    end
  end
end

-- ===========================================================================
function OnInterfaceModeChanged( oldMode:number, newMode:number )
  if (oldMode == InterfaceModeTypes.TELEPORT_TO_CITY) then
    -- Only close if already open
    if m_AnimSupport:IsVisible() then
      Close();
    end
  end
  if (newMode == InterfaceModeTypes.MAKE_TRADE_ROUTE) then
    -- Only close if already open
    if m_AnimSupport:IsVisible() then
      Close();
    end

    UILens.SetActive("TradeRoute");
  end
  if (newMode == InterfaceModeTypes.TELEPORT_TO_CITY) then
    -- Only open if selected unit is a trade unit
    local pSelectedUnit:table = UI.GetHeadSelectedUnit();
    local pSelectedUnitInfo:table = GameInfo.Units[pSelectedUnit:GetUnitType()];
    if pSelectedUnitInfo.MakeTradeRoute then
      Open();
    end
  end
end

-- ===========================================================================
function OnCitySelectionChanged(owner, ID, i, j, k, bSelected, bEditable)
  -- Close if we select a city
  if m_AnimSupport:IsVisible() and owner == Game.GetLocalPlayer() and owner ~= -1 then
    OnClose();
  end
end

-- ===========================================================================
function OnUnitSelectionChanged( playerID:number, unitID:number, hexI:number, hexJ:number, hexK:number, bSelected:boolean, bEditable:boolean)
  -- Check if the unit selected is a trader. Don't do anything if it is
  local selectedUnit:table = Players[playerID]:GetUnits():FindID(unitID)
  if selectedUnit ~= nil then
    local selectedUnitInfo:table = GameInfo.Units[selectedUnit:GetUnitType()];
    if selectedUnitInfo ~= nil and selectedUnitInfo.MakeTradeRoute == true then
      local activityType:number = UnitManager.GetActivityType(selectedUnit);
      if activityType == ActivityTypes.ACTIVITY_AWAKE and selectedUnit:GetMovesRemaining() > 0 then
        return -- early return here so OnClose() is not called
      end
    end
  end

  -- Close if screen shown
  if m_AnimSupport:IsVisible() and playerID == Game.GetLocalPlayer() and playerID ~= -1 then
    OnClose()
  end
end

------------------------------------------------------------------------------------------------
function OnLocalPlayerTurnEnd()
  if GameConfiguration.IsHotseat() then
    OnClose();
  end
end

-- ===========================================================================
function Open()
  LuaEvents.TradeOriginChooser_SetTradeUnitStatus("LOC_HUD_UNIT_PANEL_CHOOSING_ORIGIN_CITY");
  m_AnimSupport:Show();
  Refresh();
end

-- ===========================================================================
function Close()
  LuaEvents.TradeOriginChooser_SetTradeUnitStatus("");
  m_AnimSupport:Hide();

  m_originCity = nil
  m_newOriginCity = nil

  -- Switch to default Lens
  -- UILens.SetActive("Default"); -- Done when lens is turned off
end

-- ===========================================================================
function OnOpen()
  LuaEvents.TradeRouteChooser_Close()
  Open();
end

-- ===========================================================================
function OnClose()
  if UI.GetInterfaceMode() == InterfaceModeTypes.TELEPORT_TO_CITY then
    UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
  elseif m_AnimSupport:IsVisible() then
    Close()
  end
end

-- ===========================================================================
--  Input
--  UI Event Handler
-- ===========================================================================
function KeyDownHandler( key:number )
  return false;
end

function KeyUpHandler( key:number )
  if key == Keys.VK_RETURN then
    OnChangeOriginCityButton()
    -- Dont let it fall through
    return true;
  end
  if key == Keys.VK_ESCAPE then
    OnClose();
    -- Dont let it fall through
    return true;
  end
  return false;
end

function OnInputHandler( pInputStruct:table )
  local uiMsg = pInputStruct:GetMessageType();
  local catchEvent = false
  if uiMsg == KeyEvents.KeyDown then
    catchEvent = KeyDownHandler( pInputStruct:GetKey() )
  end
  if uiMsg == KeyEvents.KeyUp then
    catchEvent = KeyUpHandler( pInputStruct:GetKey() )
  end

  if not catchEvent then
    return m_AnimSupport.OnInputHandler(pInputStruct)
  end
  return catchEvent
end

-- ===========================================================================
--  HOT-RELOADING EVENTS
-- ===========================================================================
function OnInit(isReload:boolean)
  if isReload then
    LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
  end
end

function OnShutdown()
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isVisible", m_AnimSupport:IsVisible());
end

function OnGameDebugReturn(context:string, contextTable:table)
  if context == RELOAD_CACHE_ID and contextTable["isVisible"] ~= nil and contextTable["isVisible"] then
    OnOpen();
  end
end

-- ===========================================================================
--  INIT
-- ===========================================================================
function Initialize()
  print("Initializing BTS Trade Origin Chooser");

  -- Hot-reload events
  ContextPtr:SetInitHandler(OnInit);
  ContextPtr:SetShutdown(OnShutdown);
  LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);

  LuaEvents.TradeOverview_ChangeOriginCityFromOverview.Add( OnChangeOriginCityFromOverview );

  -- Game Engine Events
  Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
  Events.CitySelectionChanged.Add( OnCitySelectionChanged );
  Events.UnitSelectionChanged.Add( OnUnitSelectionChanged );
  Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );

  -- Animation controller
  m_AnimSupport = CreateScreenAnimation(Controls.SlideAnim);

  -- Animation controller events
  Events.SystemUpdateUI.Add(m_AnimSupport.OnUpdateUI);
  ContextPtr:SetInputHandler( OnInputHandler, true );

  -- Control Events
  Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);
  Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.ChangeOriginCityButton:RegisterCallback(Mouse.eLClick, OnChangeOriginCityButton);
  Controls.ChangeOriginCityButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
end
Initialize();
