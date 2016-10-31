-- ===========================================================================
--
--	Slideout panel that allows the player to move their trade units to other city centers
--
-- ===========================================================================
include("InstanceManager");
include("SupportFunctions");
include("AnimSidePanelSupport");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID:string = "TradeOriginChooser"; -- Must be unique (usually the same as the file name)

-- ===========================================================================
--	MEMBERS
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

	-- Add all other cities to city stack
	local localPlayer = Players[Game.GetLocalPlayer()];
	local playerCities:table = localPlayer:GetCities();
	for _, city in playerCities:Members() do
		if city ~= m_originCity and CanTeleportToCity(city) then
			print( "Adding city: " .. Locale.Lookup(city:GetName()) )
			AddCity(city);
		else
			print( "Cannot teleport to " .. Locale.Lookup(city:GetName()))
		end
	end

	-- Calculate Control Size
	Controls.CityScrollPanel:CalculateInternalSize();
	Controls.CityStack:CalculateSize();
	Controls.CityStack:ReprocessAnchoring();
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
		Controls.StatusMessage:SetText("Choose a city");
	end
end

-- ===========================================================================
function AddCity(city:table)
	local cityInstance:table = m_cityIM:GetInstance();
	cityInstance.CityButton:SetText(Locale.ToUpper(city:GetName()));
	cityInstance.CityButton:RegisterCallback(Mouse.eLClick, 
		function()
			m_newOriginCity = city;
			RefreshHeader();
		end);
end

-- ===========================================================================
function OnChangeOriginCityButton()
	if ( m_newOriginCity ~= nil and m_originCity ~= nil ) then
		if ( m_newOriginCity:GetID() ~= m_originCity:GetID() ) then
			TeleportToCity(m_newOriginCity);
		else
			print (" cant teleport to the same city")
		end
	else
		print("cities are nil")
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
		OnClose();
	end
end

-- ===========================================================================
function OnChangeOriginCityFromOverview( city:table )
	if city ~= nil then
		print ("Window opened from Trade Overview with city " .. Locale.Lookup(city:GetName()))
		local selectedUnit:table = UI.GetHeadSelectedUnit();
		
		m_originCity = Cities.GetCityInPlot(selectedUnit:GetX(), selectedUnit:GetY());
		m_newOriginCity = city

		print ("Transfer from " .. Locale.Lookup(m_originCity:GetName()) .. " to " .. Locale.Lookup(m_newOriginCity:GetName()))

		-- Is the screen already open?
		if (m_AnimSupport:IsVisible()) then
			print("Refreshing")
			Refresh();
		else
			print("Opening")
			Open();
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
		Close();
	end
end

-- ===========================================================================
function OnUnitSelectionChanged( playerID : number, unitID : number, hexI : number, hexJ : number, hexK : number, bSelected : boolean, bEditable : boolean)
	-- Close if we select a unit
	if m_AnimSupport:IsVisible() and owner == Game.GetLocalPlayer() and owner ~= -1 then
		Close();
	end
end

------------------------------------------------------------------------------------------------
function OnLocalPlayerTurnEnd()
	if(GameConfiguration.IsHotseat()) then
		Close();
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

	-- Switch to default Lens
	UILens.SetActive("Default");
end

-- ===========================================================================
function OnOpen()
	Open();
end

-- ===========================================================================
function OnClose()
	Close();

	if UI.GetInterfaceMode() == InterfaceModeTypes.TELEPORT_TO_CITY then
		UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
	end
end

-- ===========================================================================
--	HOT-RELOADING EVENTS
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
--	INIT
-- ===========================================================================
function Initialize()
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
	ContextPtr:SetInputHandler(m_AnimSupport.OnInputHandler, true);

	-- Control Events
	Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);
	Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ChangeOriginCityButton:RegisterCallback(Mouse.eLClick, OnChangeOriginCityButton);
	Controls.ChangeOriginCityButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
end
Initialize();