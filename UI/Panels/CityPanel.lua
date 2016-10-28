-- ===========================================================================
--	CityPanel v3
-- ===========================================================================

include( "AdjacencyBonusSupport" );		-- GetAdjacentYieldBonusString()
include( "CitySupport" );
include( "Civ6Common" );				-- GetYieldString()
include( "Colors" );
include( "InstanceManager" );
include( "SupportFunctions" );			-- Round(), Clamp(), DarkenLightenColor()
include( "ToolTipHelper" );	

-- ===========================================================================
--	DEBUG
--	Toggle these for temporary debugging help.
-- ===========================================================================
local m_debugAllowMultiPanel	:boolean = false;		-- (false default) Let's multiple sub-panels show at one time.


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local SIZE_SMALL_RELIGION_ICON		:number = 22;
local SIZE_LEADER_ICON				:number = 32;
local SIZE_PRODUCTION_ICON			:number = 32;	-- TODO: Switch this to 38 when the icons go in.
local SIZE_MAIN_ROW_LEFT_WIDE		:number = 270;
local SIZE_MAIN_ROW_LEFT_COLLAPSED	:number = 157;
local TXT_NO_PRODUCTION				:string = Locale.Lookup("LOC_HUD_CITY_PRODUCTION_NOTHING_PRODUCED");
local MAX_BEFORE_TRUNC_TURN_LABELS	:number = 160;
local MAX_BEFORE_TRUNC_STATIC_LABELS:number	= 110;

local UV_CITIZEN_GROWTH_STATUS		:table	= {};
		UV_CITIZEN_GROWTH_STATUS[0] = {u=0, v=0  };		-- revolt
		UV_CITIZEN_GROWTH_STATUS[1] = {u=0, v=0 };		-- unrest
		UV_CITIZEN_GROWTH_STATUS[2] = {u=0, v=0};		-- unhappy
		UV_CITIZEN_GROWTH_STATUS[3] = {u=0, v=50};		-- displeased
		UV_CITIZEN_GROWTH_STATUS[4] = {u=0, v=100};		-- content (normal)
		UV_CITIZEN_GROWTH_STATUS[5] = {u=0, v=150};		-- happy
		UV_CITIZEN_GROWTH_STATUS[6] = {u=0, v=200};		-- ecstatic

local UV_HOUSING_GROWTH_STATUS		:table = {};
		UV_HOUSING_GROWTH_STATUS[0] = {u=0, v=0};		-- slowed
		UV_HOUSING_GROWTH_STATUS[1] = {u=0, v=100};		-- normal

local UV_CITIZEN_STARVING_STATUS		:table = {};
		UV_CITIZEN_STARVING_STATUS[0] = {u=0, v=0};		-- starving
		UV_CITIZEN_STARVING_STATUS[1] = {u=0, v=100};		-- normal


-- ===========================================================================
--	VARIABLES
-- ===========================================================================

local m_kData						:table	= nil;
local m_isInitializing				:boolean= false;		
local m_isShowingPanels				:boolean= false;
local m_pCity						:table	= nil;
local m_pPlayer						:table	= nil;
local m_primaryColor				:number = 0xcafef00d;	
local m_secondaryColor				:number = 0xf00d1ace;
local m_kTutorialDisabledControls	:table	= nil;


-- ===========================================================================
--
-- ===========================================================================
function Close()
	ContextPtr:SetHide( true );
end

-- ===========================================================================
--	Helper, display the 3-way state of a yield based on the enum.
--	yieldData,	A YIELD_STATE
--	yieldName,	The name tied used in the check and ignore controls.
-- ===========================================================================
function RealizeYield3WayCheck( yieldData:number, yieldType, yieldToolTip )

	local yieldInfo = GameInfo.Yields[yieldType];
	if(yieldInfo) then

		local controlLookup = {
			YIELD_FOOD = "Food",
			YIELD_PRODUCTION = "Production",
			YIELD_GOLD = "Gold",
			YIELD_SCIENCE = "Science",
			YIELD_CULTURE = "Culture",
			YIELD_FAITH = "Faith",
		};

		local yieldName = controlLookup[yieldInfo.YieldType];
		if(yieldName) then
			
			local checkControl = Controls[yieldName.."Check"];
			local ignoreControl = Controls[yieldName.."Ignore"];
			local gridControl = Controls[yieldName.."Grid"];

			if(checkControl and ignoreControl and gridControl) then
		
				local toolTip = "";

				if yieldData == YIELD_STATE.FAVORED then 
					checkControl:SetCheck(true);	-- Just visual, no callback!
					checkControl:SetDisabled(false);
					ignoreControl:SetHide(true);
				
					toolTip = Locale.Lookup("LOC_HUD_CITY_YIELD_FOCUSING", yieldInfo.Name) .. "[NEWLINE][NEWLINE]";		
				elseif yieldData == YIELD_STATE.IGNORED then 
					checkControl:SetCheck(false);	-- Just visual, no callback!
					checkControl:SetDisabled(true);
					ignoreControl:SetHide(false);
								
					toolTip = Locale.Lookup("LOC_HUD_CITY_YIELD_IGNORING", yieldInfo.Name) .. "[NEWLINE][NEWLINE]";
				else
					checkControl:SetCheck(false);
					checkControl:SetDisabled(false);
					ignoreControl:SetHide(true);

					toolTip = Locale.Lookup("LOC_HUD_CITY_YIELD_CITIZENS", yieldInfo.Name) .. "[NEWLINE][NEWLINE]";
				end
			
				if(#yieldToolTip > 0) then
					toolTip = toolTip .. yieldToolTip;
				else
					toolTip = toolTip .. Locale.Lookup("LOC_HUD_CITY_YIELD_NOTHING");
				end
				
				gridControl:SetToolTipString(toolTip);
			end
		end

	end
end

-- ===========================================================================
--	Set the health meter
-- ===========================================================================
function RealizeHealthMeter( control:table, percent:number )
	if	( percent > 0.7 )	then 
		control:SetColor( COLORS.METER_HP_GOOD );	
	elseif ( percent > 0.4 )	then
		control:SetColor( COLORS.METER_HP_OK );
	else						 
		control:SetColor( COLORS.METER_HP_BAD ); 	
	end

	-- Meter control is half circle, so add enough to start at half point and condense % into the half area
	percent			= (percent * 0.5) + 0.5;
	control:SetPercent( percent );
end

-- ===========================================================================
--	Main city panel
-- ===========================================================================
function ViewMain( data:table )
	m_primaryColor, m_secondaryColor  = UI.GetPlayerColors( m_pPlayer:GetID() );
	local darkerBackColor = DarkenLightenColor(m_primaryColor,(-85),100);
	local brighterBackColor = DarkenLightenColor(m_primaryColor,90,255);

	-- Name data
	Controls.CityName:SetText((data.IsCapital and "[ICON_Capital]" or "") .. Locale.ToUpper( Locale.Lookup(data.CityName)));
	Controls.CityName:SetToolTipString(data.IsCapital and Locale.Lookup("LOC_HUD_CITY_IS_CAPITAL") or nil );

	-- Banner and icon colors
	Controls.Banner:SetColor(m_primaryColor);
	Controls.BannerLighter:SetColor(brighterBackColor);
	Controls.BannerDarker:SetColor(darkerBackColor);
	Controls.CircleBacking:SetColor(m_primaryColor);
	Controls.CircleLighter:SetColor(brighterBackColor);
	Controls.CircleDarker:SetColor(darkerBackColor);
	Controls.CityName:SetColor(m_secondaryColor);
	Controls.CivIcon:SetColor(m_secondaryColor);

	-- Set Population --
	Controls.PopulationNumber:SetText(data.Population);
	Controls.PopulationNumber:ReprocessAnchoring();

	-- Damage meters ---
	RealizeHealthMeter( Controls.CityHealthMeter, data.HitpointPercent );
	if(data.CityWallTotalHP > 0) then
		Controls.CityWallHealthMeters:SetHide(false);
		--RealizeHealthMeter( Controls.WallHealthMeter, data.CityWallHPPercent );
		local percent			= (data.CityWallHPPercent * 0.5) + 0.5;
		Controls.WallHealthMeter:SetPercent( percent );
	else
		Controls.CityWallHealthMeters:SetHide(true);
	end

	-- Update city health tooltip
	local tooltip:string = Locale.Lookup("LOC_HUD_UNIT_PANEL_HEALTH_TOOLTIP", data.HitpointsCurrent, data.HitpointsTotal);
	if (data.CityWallTotalHP > 0) then
		tooltip = tooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_HUD_UNIT_PANEL_WALL_HEALTH_TOOLTIP", data.CityWallCurrentHP, data.CityWallTotalHP);
	end
	Controls.CityHealthMeter:SetToolTipString(tooltip);

	local leader:string = PlayerConfigurations[data.Owner]:GetLeaderTypeName();
	local civIconName:string = "ICON_";
	if GameInfo.CivilizationLeaders[leader] == nil then
		UI.DataError("Banners found a leader \""..leader.."\" which is not/no longer in the game; icon may be whack.");
	else
		if(GameInfo.CivilizationLeaders[leader].CivilizationType ~= nil) then
			civIconName = civIconName..GameInfo.CivilizationLeaders[leader].CivilizationType;
			Controls.CivIcon:SetIcon(civIconName);
		end
	end


	-- Set icons and values for the yield checkboxes
	Controls.CultureCheck:GetTextButton():SetText(		"[ICON_Culture]"	..toPlusMinusString(data.CulturePerTurn) );
	Controls.FoodCheck:GetTextButton():SetText(			"[ICON_Food]"		..toPlusMinusString(data.FoodPerTurn) );
	Controls.ProductionCheck:GetTextButton():SetText(	"[ICON_Production]"	..toPlusMinusString(data.ProductionPerTurn) );
	Controls.ScienceCheck:GetTextButton():SetText(		"[ICON_Science]"	..toPlusMinusString(data.SciencePerTurn) );
	Controls.FaithCheck:GetTextButton():SetText(		"[ICON_Faith]"		..toPlusMinusString(data.FaithPerTurn) );
	Controls.GoldCheck:GetTextButton():SetText(			"[ICON_Gold]"		..toPlusMinusString(data.GoldPerTurn) );

	-- Set the Yield checkboxes based on the game state
	RealizeYield3WayCheck( data.YieldFilters[YieldTypes.CULTURE], YieldTypes.CULTURE, data.CulturePerTurnToolTip);
	RealizeYield3WayCheck( data.YieldFilters[YieldTypes.FAITH], YieldTypes.FAITH, data.FaithPerTurnToolTip);
	RealizeYield3WayCheck( data.YieldFilters[YieldTypes.FOOD], YieldTypes.FOOD, data.FoodPerTurnToolTip);
	RealizeYield3WayCheck( data.YieldFilters[YieldTypes.GOLD], YieldTypes.GOLD, data.GoldPerTurnToolTip);
	RealizeYield3WayCheck( data.YieldFilters[YieldTypes.PRODUCTION], YieldTypes.PRODUCTION, data.ProductionPerTurnToolTip);
	RealizeYield3WayCheck( data.YieldFilters[YieldTypes.SCIENCE], YieldTypes.SCIENCE, data.SciencePerTurnToolTip);

	Controls.CultureCheck:ReprocessAnchoring();
	Controls.FoodCheck:ReprocessAnchoring();
	Controls.ProductionCheck:ReprocessAnchoring();
	Controls.ScienceCheck:ReprocessAnchoring();
	Controls.FaithCheck:ReprocessAnchoring();
	Controls.GoldCheck:ReprocessAnchoring();
	Controls.YieldStack:ReprocessAnchoring();
	
	if m_isShowingPanels then
		Controls.LabelButtonRows:SetSizeX( SIZE_MAIN_ROW_LEFT_COLLAPSED );
	else
		Controls.LabelButtonRows:SetSizeX( SIZE_MAIN_ROW_LEFT_WIDE );
	end
	Controls.LabelButtonRows:ReprocessAnchoring();

	-- Custom religion icon:
	if data.Religions[DATA_DOMINANT_RELIGION] ~= nil then
		local kReligion		:table	= GameInfo.Religions[data.Religions[DATA_DOMINANT_RELIGION].ReligionType];
		local iconName		:string = "ICON_" .. kReligion.ReligionType;
		Controls.ReligionIcon:SetIcon(iconName);
	end


	Controls.BreakdownNum:SetText( data.BuildingsNum );

	local amenitiesNumText = data.AmenitiesNetAmount;
	if (data.AmenitiesNetAmount > 0) then
		amenitiesNumText = "+" .. amenitiesNumText;
	end
	Controls.AmenitiesNum:SetText( amenitiesNumText );
	local colorName:string = GetHappinessColor( data.Happiness );
	Controls.AmenitiesNum:SetColorByName( colorName );

	Controls.ReligionNum:SetText( data.ReligionFollowers );

	Controls.HousingNum:SetText( data.Population );
	colorName = GetPercentGrowthColor( data.HousingMultiplier );
	Controls.HousingNum:SetColorByName( colorName );
	Controls.HousingMax:SetText( data.Housing );	

	Controls.BreakdownLabel:SetHide( m_isShowingPanels );
	Controls.ReligionLabel:SetHide( m_isShowingPanels );
	Controls.AmenitiesLabel:SetHide( m_isShowingPanels );
	Controls.HousingLabel:SetHide( m_isShowingPanels );
	Controls.PanelStackShadow:SetHide( not m_isShowingPanels );
	Controls.ProductionNowLabel:SetHide( m_isShowingPanels );	

	-- Determine size of progress bars at the bottom, as well as sub-panel offset.
	local OFF_BOTTOM_Y						:number = 9;
	local OFF_ROOM_FOR_PROGRESS_Y			:number = 36;
	local OFF_GROWTH_BAR_PUSH_RIGHT_X		:number = 2;
	local OFF_GROWTH_BAR_DEFAULT_RIGHT_X	:number = 32;
	local widthNumLabel				:number = 0;

	-- Growth
	Controls.GrowthTurnsSmall:SetHide( not m_isShowingPanels );
	Controls.GrowthTurns:SetHide( m_isShowingPanels );	
	
	Controls.GrowthTurnsBar:SetPercent( data.CurrentFoodPercent );
	Controls.GrowthTurnsBar:SetShadowPercent( data.FoodPercentNextTurn );	
	Controls.GrowthTurnsBarSmall:SetPercent( data.CurrentFoodPercent );
	Controls.GrowthTurnsBarSmall:SetShadowPercent( data.FoodPercentNextTurn );
	Controls.GrowthNum:SetText( math.abs(data.TurnsUntilGrowth) );
	Controls.GrowthNumSmall:SetText( math.abs(data.TurnsUntilGrowth).."[Icon_Turn]" );
	if data.Occupied then
		Controls.GrowthLabel:SetColorByName("StatBadCS");
		Controls.GrowthLabel:SetText( Locale.ToUpper( Locale.Lookup("LOC_HUD_CITY_GROWTH_OCCUPIED") ) );		
	elseif data.TurnsUntilGrowth >= 0 then
		Controls.GrowthLabel:SetColorByName("StatGoodCS");
		local CurFood = Round(data.CurrentFood, 1);
		local FoodGainNextTurn = Round(data.FoodGainNextTurn, 1);
		local RequiredFood = data.RequiredFood;

		Controls.GrowthLabel:SetText( "  "..CurFood.." + "..FoodGainNextTurn.." / "..RequiredFood);		
	else
		Controls.GrowthLabel:SetColorByName("StatBadCS");
		Controls.GrowthLabel:SetText( Locale.ToUpper( Locale.Lookup("LOC_HUD_CITY_TURNS_UNTIL_LOSS", math.abs(data.TurnsUntilGrowth))) );
	end

	widthNumLabel = Controls.GrowthNum:GetSizeX();
	TruncateStringWithTooltip(Controls.GrowthLabel, MAX_BEFORE_TRUNC_TURN_LABELS-widthNumLabel, Controls.GrowthLabel:GetText());

	--Production

	Controls.ProductionTurns:SetHide( m_isShowingPanels );	
	Controls.ProductionTurnsBar:SetPercent(data.CurrentProdPercent);
	Controls.ProductionTurnsBar:SetShadowPercent(data.ProdPercentNextTurn);
	Controls.ProductionNum:SetText( data.CurrentTurnsLeft );
	Controls.ProductionNowLabel:SetText( data.CurrentProductionName );

	Controls.ProductionDescriptionString:SetText( data.CurrentProductionDescription );
	--Controls.ProductionDescription:SetText( "There was a young lady from Venus, who's body was shaped like a, THAT'S ENOUGH DATA." );
	if( data.CurrentProductionStats ~= "") then
		Controls.ProductionStatString:SetText( data.CurrentProductionStats );
	end
	Controls.ProductionDataStack:CalculateSize();
	Controls.ProductionDataStack:ReprocessAnchoring();
	Controls.ProductionDataScroll:CalculateSize();

	if(data.CurrentProductionIcon) then
		Controls.ProductionIcon:SetIcon(data.CurrentProductionIcon);
		Controls.ProductionIcon:SetHide(false);
	else
		Controls.ProductionIcon:SetHide(true);
	end
	
	Controls.ProductionNum:SetHide( data.CurrentTurnsLeft < 0 );

	if data.CurrentTurnsLeft < 0 then	
		Controls.ProductionLabel:SetText( Locale.ToUpper( Locale.Lookup("LOC_HUD_CITY_NOTHING_PRODUCED")) );
		widthNumLabel = 0;
	else
		Controls.ProductionLabel:SetText( data.ProductionProgress .. " / " .. data.ProductionCost );
		widthNumLabel = Controls.ProductionNum:GetSizeX();
	end

	TruncateStringWithTooltip(Controls.ProductionLabel, MAX_BEFORE_TRUNC_TURN_LABELS-widthNumLabel, Controls.ProductionLabel:GetText());
	Controls.ProductionTurnsBar:ReprocessAnchoring();	-- Fixes up children elements inside of the bar.
	
	-- Tutorial lockdown
	if m_kTutorialDisabledControls ~= nil then
		for _,name in ipairs(m_kTutorialDisabledControls) do
			if Controls[name] ~= nil then
				Controls[name]:SetDisabled(true);
			end
		end
	end	

end




-- ===========================================================================
--	Return ColorSet name
-- ===========================================================================
function GetHappinessColor( eHappiness:number )
	local happinessInfo = GameInfo.Happinesses[eHappiness];
	if (happinessInfo ~= nil) then
		if (happinessInfo.GrowthModifier < 0) then return "StatBadCS"; end
		if (happinessInfo.GrowthModifier > 0) then return "StatGoodCS"; end
	end
	return "StatNormalCS";
end

-- ===========================================================================
--	Return ColorSet name
-- ===========================================================================
function GetTurnsUntilGrowthColor( turns:number )
	if	turns < 1	then return "StatBadCS"; end
	return "StatGoodCS";	
end

function GetPercentGrowthColor( percent:number )
	if percent == 0 then return "Error"; end
	if percent <= 0.25 then return "WarningMajor"; end
	if percent <= 0.5 then return "WarningMinor"; end
	return "StatNormalCS";
end


-- ===========================================================================
--	Changes the yield focus.
-- ===========================================================================
function SetYieldFocus( yieldType:number )
	local pCitizens		:table = m_pCity:GetCitizens();
	local tParameters	:table = {};
	tParameters[CityCommandTypes.PARAM_FLAGS]		= 0;			-- Set Favored
	tParameters[CityCommandTypes.PARAM_UNIT0_PLAYER]= yieldType;	-- Yield type 
	if pCitizens:IsFavoredYield(yieldType) then
		tParameters[CityCommandTypes.PARAM_UNIT0_ID]= 0;			-- boolean (1=true, 0=false)
	else
		if pCitizens:IsDisfavoredYield(yieldType) then
			SetYieldIgnore(yieldType);
		end
		tParameters[CityCommandTypes.PARAM_UNIT0_ID] = 1;			-- boolean (1=true, 0=false)
	end
	CityManager.RequestCommand(m_pCity, CityCommandTypes.SET_FOCUS, tParameters);
end

-- ===========================================================================
--	Changes what yield type(s) should be ignored by citizens 
-- ===========================================================================
function SetYieldIgnore( yieldType:number )
	local pCitizens		:table = m_pCity:GetCitizens();
	local tParameters	:table = {};
	tParameters[CityCommandTypes.PARAM_FLAGS]		= 1;			-- Set Ignored
	tParameters[CityCommandTypes.PARAM_UNIT0_PLAYER]= yieldType;	-- Yield type 
	if pCitizens:IsDisfavoredYield(yieldType) then
		tParameters[CityCommandTypes.PARAM_UNIT0_ID]= 0;			-- boolean (1=true, 0=false)
	else
		if ( pCitizens:IsFavoredYield(yieldType) ) then
			SetYieldFocus(yieldType);
		end
		tParameters[CityCommandTypes.PARAM_UNIT0_ID] = 1;			-- boolean (1=true, 0=false)
	end
	CityManager.RequestCommand(m_pCity, CityCommandTypes.SET_FOCUS, tParameters);
end


-- ===========================================================================
--	Update both the data & view for the selected city.
-- ===========================================================================
function Refresh()
	local eLocalPlayer :number = Game.GetLocalPlayer();
	m_pPlayer= Players[eLocalPlayer];
	m_pCity	 = UI.GetHeadSelectedCity();

	if m_pPlayer ~= nil and m_pCity ~= nil then 		
		m_kData = GetCityData( m_pCity );
		if m_kData == nil then
			return;
		end
		
		ViewMain( m_kData );
		
		-- Tell others (e.g., CityPanelOverview) that the selected city data has changed.
		-- Passing this large table across contexts via LuaEvent is *much*
		-- more effecient than recomputing the entire set of yields a second time,
		-- despite the large size.
		LuaEvents.CityPanel_LiveCityDataChanged( m_kData, true );
	end
end


-- ===========================================================================
function RefreshIfMatch( ownerPlayerID:number, cityID:number )
	if m_pCity ~= nil and ownerPlayerID == m_pCity:GetOwner() and cityID == m_pCity:GetID() then
		Refresh();
	end
end

-- ===========================================================================
--	GAME Event
-- ===========================================================================
function OnCityAddedToMap( ownerPlayerID:number, cityID:number )
	if Game.GetLocalPlayer() ~= nil then
		if ownerPlayerID == Game.GetLocalPlayer() then
			local pSelectedCity:table = UI.GetHeadSelectedCity();			
			if pSelectedCity ~= nil then
				Refresh();
			else
				UI.DeselectAllCities();
			end
		end
	end
end

-- ===========================================================================
--	GAME Event
--	Yield changes
-- ===========================================================================
function OnCityFocusChange(ownerPlayerID:number, cityID:number)
	RefreshIfMatch(ownerPlayerID, cityID);
end

-- ===========================================================================
--	GAME Event
-- ===========================================================================
function OnCityWorkerChanged(ownerPlayerID:number, cityID:number)
	RefreshIfMatch(ownerPlayerID, cityID);
end

-- ===========================================================================
--	GAME Event
-- ===========================================================================
function OnCityProductionChanged(ownerPlayerID:number, cityID:number)
	if Controls.ChangeProductionCheck:IsChecked() then
		Controls.ChangeProductionCheck:SetCheck(false);
	end
	RefreshIfMatch(ownerPlayerID, cityID);
end

-- ===========================================================================
--	GAME Event
-- ===========================================================================
function OnCityProductionCompleted(ownerPlayerID:number, cityID:number)
	RefreshIfMatch(ownerPlayerID, cityID);
end

-- ===========================================================================
--	GAME Event
-- ===========================================================================
function OnCityProductionUpdated( ownerPlayerID:number, cityID:number, eProductionType, eProductionObject)
	RefreshIfMatch(ownerPlayerID, cityID);
end

-- ===========================================================================
--	GAME Event
-- ===========================================================================
function OnToggleOverviewPanel()
	if Controls.ToggleOverviewPanel:IsChecked() then
		LuaEvents.CityPanel_ShowOverviewPanel(true);
	else
		LuaEvents.CityPanel_ShowOverviewPanel(false);
	end
end

function OnCitySelectionChanged( ownerPlayerID:number, cityID:number, i:number, j:number, k:number, isSelected:boolean, isEditable:boolean)
	if ownerPlayerID == Game.GetLocalPlayer() then
		if (isSelected) then
			-- Determine if we should switch to the SELECTION interface mode
			local shouldSwitchToSelection:boolean = true;
			if UI.GetInterfaceMode() == InterfaceModeTypes.CITY_MANAGEMENT then
				shouldSwitchToSelection = false;
			end
			if UI.GetInterfaceMode() == InterfaceModeTypes.ICBM_STRIKE then
				-- During ICBM_STRIKE only switch to SELECTION if we're selecting a city
				-- which doesn't own the active missile silo
				local siloPlotX:number = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_X0);
				local siloPlotY:number = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_Y0);
				local siloPlot:table = Map.GetPlot(siloPlotX, siloPlotY);
				if siloPlot then
					local owningCity = Cities.GetPlotPurchaseCity(siloPlot);
					if owningCity:GetID() == cityID then
						shouldSwitchToSelection = false;
					end
				end
			end
			if shouldSwitchToSelection then
				UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
			end

			OnToggleOverviewPanel();
			ContextPtr:SetHide(false);
			Controls.CityPanelAlpha:SetToBeginning();
			Controls.CityPanelAlpha:Play();
			Controls.CityPanelSlide:SetToBeginning();
			Controls.CityPanelSlide:Play();
			Refresh();
		else
			Close();
			-- Tell the CityPanelOverview a city was deselected
			LuaEvents.CityPanel_LiveCityDataChanged( nil, false ); 
		end
	end
end

-- ===========================================================================
--	GAME Event
-- ===========================================================================
function OnUnitSelectionChanged( playerID:number, unitID:number, hexI:number, hexJ:number, hexK:number, isSelected:boolean, isEditable:boolean )	
	if playerID == Game.GetLocalPlayer() then
		if ContextPtr:IsHidden()==false then
			Close();
		end
	end
end

-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnInit( isHotload:boolean )
	if isHotload then
		LuaEvents.GameDebug_GetValues( "CityPanel");
	end
	m_isInitializing = false;
	Refresh();
end


-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string)
	if type == SystemUpdateUI.ScreenResize then
		Resize();
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnShutdown()
	-- Cache values for hotloading...
	LuaEvents.GameDebug_AddValue("CityPanel", "isHidden",				ContextPtr:IsHidden() );
end

-- ===========================================================================
--	LUA Event
--	Set cached values back after a hotload.
-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
	function RunWithNoError()
		if context ~= "CityPanel" or contextTable == nil then 
			return;
		end
		local isHidden:boolean = contextTable["isHidden"]; 
		ContextPtr:SetHide( isHidden ); 
	end
	pcall( RunWithNoError );
end

-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnProductionPanelClose()
	-- If no longer checked, make sure the side Production Panel closes.
	if (not ContextPtr:IsHidden()) then
		Controls.ChangeProductionCheck:SetCheck( false );
		Controls.ProduceWithFaithCheck:SetCheck( false );
		Controls.ProduceWithGoldCheck:SetCheck( false );
	end
end

-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnTutorialOpen()
	ContextPtr:SetHide(false);
	Refresh();
end



-- ===========================================================================
function OnBreakdown()
	LuaEvents.CityPanel_ShowBreakdownTab();
end

-- ===========================================================================
function OnReligion()
	LuaEvents.CityPanel_ShowReligionTab();
end

-- ===========================================================================
function OnAmenities()
	LuaEvents.CityPanel_ShowAmenitiesTab();
end

-- ===========================================================================
function OnHousing()
	LuaEvents.CityPanel_ShowHousingTab();
end

-- ===========================================================================
--function OnCheckQueue()
--	if m_isInitializing then return; end
--	if not m_debugAllowMultiPanel then	
--		UILens.ToggleLayerOff(LensLayers.ADJACENCY_BONUS_DISTRICTS);
--		UILens.ToggleLayerOff(LensLayers.DISTRICTS);
--	end
--	Refresh();
--end

-- ===========================================================================
function OnCitizensGrowth()
	LuaEvents.CityPanel_ShowCitizensTab();
end


-- ===========================================================================
--	Set a yield to one of 3 check states.
--	yieldType	Enum from game engine on the yield
--	yieldName	Name of the yield used in the UI controls
-- ===========================================================================
function OnCheckYield( yieldType:number, yieldName:string )
	if Controls.YieldsArea:IsDisabled() then return; end	-- Via tutorial event
	if Controls[yieldName.."Check"]:IsChecked() then
		SetYieldFocus( yieldType );
	else
		SetYieldIgnore( yieldType );
		Controls[yieldName.."Ignore"]:SetHide( false );
		Controls[yieldName.."Check"]:SetDisabled( true );
	end
end

-- ===========================================================================
--	Reset a yield to not be favored nor ignored
--	yieldType	Enum from game engine on the yield
--	yieldName	Name of the yield used in the UI controls
-- ===========================================================================
function OnResetYieldToNormal( yieldType:number, yieldName:string )
	if Controls.YieldsArea:IsDisabled() then return; end	-- Via tutorial event
	Controls[yieldName.."Ignore"]:SetHide( true );
	Controls[yieldName.."Check"]:SetDisabled( false );
	SetYieldIgnore( yieldType );		-- One more ignore to flip it off
end

-- ===========================================================================
--	Cycle to the next city
-- ===========================================================================
function OnNextCity()
	local kCity:table = UI.GetHeadSelectedCity();
	UI.SelectNextCity(kCity);
	UI.PlaySound("UI_Click_Sweetener_Metal_Button_Small");
end

-- ===========================================================================
--	Cycle to the previous city
-- ===========================================================================
function OnPreviousCity()
	local kCity:table = UI.GetHeadSelectedCity();
	UI.SelectPrevCity(kCity);
	UI.PlaySound("UI_Click_Sweetener_Metal_Button_Small");
end

-- ===========================================================================
--	Recenter camera on city
-- ===========================================================================
function RecenterCameraOnCity()
	local kCity:table = UI.GetHeadSelectedCity();
	UI.LookAtPlot( kCity:GetX(), kCity:GetY() );
end

-- ===========================================================================
--	Turn on/off layers and switch the interface mode based on what is checked.
--	Interface mode is changed first as the Lens system may inquire as to the
--	current state in deciding what is populate in a lens layer.
-- ===========================================================================
function OnTogglePurchaseTile()
	if Controls.PurchaseTileCheck:IsChecked() then
		if not Controls.ManageCitizensCheck:IsChecked() then
			UI.SetInterfaceMode(InterfaceModeTypes.CITY_MANAGEMENT);	-- Enter mode
		end
		RecenterCameraOnCity();
		UILens.ToggleLayerOn( LensLayers.PURCHASE_PLOT );
	else		
		if not Controls.ManageCitizensCheck:IsChecked() then
			UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);			-- Exit mode		
		end
		UILens.ToggleLayerOff( LensLayers.PURCHASE_PLOT );			
	end
end

function OnToggleProduction()
	if Controls.ChangeProductionCheck:IsChecked() then
		RecenterCameraOnCity();
		LuaEvents.CityPanel_ProductionOpen();
		--Controls.ProduceWithFaithCheck:SetCheck( false );
		--Controls.ProduceWithGoldCheck:SetCheck( false );
	else
		LuaEvents.CityPanel_ProductionClose();
	end
end

function OnTogglePurchaseWithGold()
	if Controls.ProduceWithGoldCheck:IsChecked() then
		RecenterCameraOnCity();
		LuaEvents.CityPanel_PurchaseGoldOpen();
		Controls.ChangeProductionCheck:SetCheck( false );
		Controls.ProduceWithFaithCheck:SetCheck( false );
	else
		LuaEvents.CityPanel_ProductionClose();
	end
end

function OnTogglePurchaseWithFaith()
	if Controls.ProduceWithFaithCheck:IsChecked() then
		RecenterCameraOnCity();
		LuaEvents.CityPanel_PurchaseFaithOpen();
		Controls.ChangeProductionCheck:SetCheck( false );
		Controls.ProduceWithGoldCheck:SetCheck( false );
	else
		LuaEvents.CityPanel_ProductionClose();
	end
end

function OnCloseOverviewPanel()
	Controls.ToggleOverviewPanel:SetCheck(false);
end
-- ===========================================================================
--	Turn on/off layers and switch the interface mode based on what is checked.
--	Interface mode is changed first as the Lens system may inquire as to the
--	current state in deciding what is populate in a lens layer.
-- ===========================================================================
function OnToggleManageCitizens()
	if Controls.ManageCitizensCheck:IsChecked() then			
		if not Controls.PurchaseTileCheck:IsChecked() then
			UI.SetInterfaceMode(InterfaceModeTypes.CITY_MANAGEMENT);	-- Enter mode
		end
		RecenterCameraOnCity();
		UILens.ToggleLayerOn( LensLayers.CITIZEN_MANAGEMENT );
	else		
		if not Controls.PurchaseTileCheck:IsChecked() then
			UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);			-- Exit mode
		end
		UILens.ToggleLayerOff( LensLayers.CITIZEN_MANAGEMENT );
	end
end

-- ===========================================================================
function OnLocalPlayerTurnBegin()
	Refresh();
end

-- ===========================================================================
--	Enable a control unless it's in the tutorial lock down list.
-- ===========================================================================
function EnableIfNotTutorialBlocked( controlName:string )
	local isDisabled :boolean = false;
	if m_kTutorialDisabledControls ~= nil then
		for _,name in ipairs(m_kTutorialDisabledControls) do
			if name == controlName then
				isDisabled = true;
				break;
			end
		end
	end
	Controls[ controlName ]:SetDisabled( isDisabled );
end

-- ===========================================================================
--	GAME Event
--	eOldMode, mode the engine was formally in
--	eNewMode, new mode the engine has just changed to
-- ===========================================================================
function OnInterfaceModeChanged( eOldMode:number, eNewMode:number )
	if eOldMode == InterfaceModeTypes.CITY_MANAGEMENT then
		if eNewMode ~= InterfaceModeTypes.DISTRICT_PLACEMENT then
			UI.DeselectAllCities();
		end
		UILens.ToggleLayerOff(LensLayers.PURCHASE_PLOT);
		UILens.ToggleLayerOff(LensLayers.CITIZEN_MANAGEMENT);
		LuaEvents.CityPanel_ProductionClose();
		UI.SetFixedTiltMode( false );
		EnableIfNotTutorialBlocked("PurchaseTileCheck");
		EnableIfNotTutorialBlocked("ManageCitizensCheck");
		EnableIfNotTutorialBlocked("ChangeProductionCheck");
	end
	
	if eNewMode == InterfaceModeTypes.CITY_RANGE_ATTACK or eNewMode == InterfaceModeTypes.DISTRICT_RANGE_ATTACK then
		if ContextPtr:IsHidden()==false then
			Close();
		end
	end

	if not ContextPtr:IsHidden() then
		ViewMain( m_kData );
	end
end


-- ===========================================================================
--	Engine EVENT
--	Local player changed; likely a hotseat game
-- ===========================================================================
function OnLocalPlayerChanged( eLocalPlayer:number , ePrevLocalPlayer:number )
	if eLocalPlayer == -1 then
		m_pPlayer = nil;
		return;
	end	
	m_pPlayer = Players[eLocalPlayer];
	if ContextPtr:IsHidden()==false then
		Close();
	end
end


-- ===========================================================================
--	Show/hide an area based on the status of a checkbox control
--	checkBoxControl		A checkbox control that when selected is open
--	buttonControl		(optional) button control that toggles the state
--	areaControl			The area to be shown/hidden
--	kParentControls		Table of controls to call ReprocessAnchoring on toggle
-- ===========================================================================
function SetupCollapsibleToggle( pCheckBoxControl:table, pButtonControl:table, pAreaControl:table, kParentControls:table )
	pCheckBoxControl:RegisterCheckHandler(
		function()			
			pAreaControl:SetHide( pCheckBoxControl:IsChecked() );
			if kParentControls ~= nil then
				for _,pControl in ipairs(kParentControls) do
					pControl:ReprocessAnchoring();
				end
			end		
		end
	);
	if pButtonControl ~= nil then
		pButtonControl:RegisterCallback( Mouse.eLClick,
			function()
				pCheckBoxControl:SetAndCall( not pCheckBoxControl:IsChecked() );
			end
		);
	end
end


-- ===========================================================================
--	LUA Event
--	Tutorial requests controls that should always be locked down.
--	Send nil to clear.
-- ===========================================================================
function OnTutorial_ContextDisableItems( contextName:string, kIdsToDisable:table )

	if contextName~="CityPanel" then return; end

	-- Enable any existing controls that are disabled
	if m_kTutorialDisabledControls ~= nil then
		for _,name in ipairs(m_kTutorialDisabledControls) do
			if Controls[name] ~= nil then
				Controls[name]:SetDisabled(false);
			end
		end
	end

	m_kTutorialDisabledControls = kIdsToDisable;
	
	-- Immediate set disabled
	if m_kTutorialDisabledControls ~= nil then
		for _,name in ipairs(m_kTutorialDisabledControls) do
			if Controls[name] ~= nil then
				Controls[name]:SetDisabled(true);
			else
				UI.DataError("Tutorial requested the control '"..name.."' be disabled in the city panel, but no such control exists in that context.");
			end
		end
	end
end


-- ===========================================================================
--	CTOR
-- ===========================================================================
function Initialize()

	LuaEvents.CityPanel_OpenOverview();

	m_isInitializing = true;
	
	-- Context Events
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );

	-- Control Events
	Controls.BreakdownButton:RegisterCallback(		Mouse.eLClick,	OnBreakdown );
	Controls.ReligionButton:RegisterCallback(		Mouse.eLClick,	OnReligion );
	Controls.AmenitiesButton:RegisterCallback(		Mouse.eLClick,	OnAmenities );
	Controls.HousingButton:RegisterCallback(		Mouse.eLClick,	OnHousing );
	Controls.CitizensGrowthButton:RegisterCallback(	Mouse.eLClick,	OnCitizensGrowth );

	Controls.CultureCheck:RegisterCheckHandler(					function() OnCheckYield( YieldTypes.CULTURE,	"Culture"); end );	
	Controls.FaithCheck:RegisterCheckHandler(					function() OnCheckYield( YieldTypes.FAITH,		"Faith"); end );	
	Controls.FoodCheck:RegisterCheckHandler(					function() OnCheckYield( YieldTypes.FOOD,		"Food"); end );	
	Controls.GoldCheck:RegisterCheckHandler(					function() OnCheckYield( YieldTypes.GOLD,		"Gold"); end );	
	Controls.ProductionCheck:RegisterCheckHandler(				function() OnCheckYield( YieldTypes.PRODUCTION, "Production"); end );	
	Controls.ScienceCheck:RegisterCheckHandler(					function() OnCheckYield( YieldTypes.SCIENCE,	"Science"); end );	
	Controls.CultureIgnore:RegisterCallback(	Mouse.eLClick,	function() OnResetYieldToNormal( YieldTypes.CULTURE,	"Culture"); end);
	Controls.FaithIgnore:RegisterCallback(		Mouse.eLClick,	function() OnResetYieldToNormal( YieldTypes.FAITH,		"Faith"); end);
	Controls.FoodIgnore:RegisterCallback(		Mouse.eLClick,	function() OnResetYieldToNormal( YieldTypes.FOOD,		"Food"); end);
	Controls.GoldIgnore:RegisterCallback(		Mouse.eLClick,	function() OnResetYieldToNormal( YieldTypes.GOLD,		"Gold"); end);
	Controls.ProductionIgnore:RegisterCallback(	Mouse.eLClick,	function() OnResetYieldToNormal( YieldTypes.PRODUCTION,	"Production"); end);
	Controls.ScienceIgnore:RegisterCallback(	Mouse.eLClick,	function() OnResetYieldToNormal( YieldTypes.SCIENCE,	"Science"); end);	
	Controls.NextCityButton:RegisterCallback(	Mouse.eLClick,	OnNextCity); 
	Controls.PrevCityButton:RegisterCallback(	Mouse.eLClick,	OnPreviousCity); 
	

	Controls.PurchaseTileCheck:RegisterCheckHandler(	OnTogglePurchaseTile );
	Controls.PurchaseTileCheck:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ManageCitizensCheck:RegisterCheckHandler(	OnToggleManageCitizens );	
	Controls.ManageCitizensCheck:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ChangeProductionCheck:RegisterCheckHandler( OnToggleProduction );
	Controls.ChangeProductionCheck:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	--Controls.ProduceWithFaithCheck:RegisterCheckHandler( OnTogglePurchaseWithFaith );
	--Controls.ProduceWithFaithCheck:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	--Controls.ProduceWithGoldCheck:RegisterCheckHandler( OnTogglePurchaseWithGold );
	--Controls.ProduceWithGoldCheck:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ToggleOverviewPanel:RegisterCheckHandler( OnToggleOverviewPanel );
	Controls.ToggleOverviewPanel:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	-- Game Core Events
	Events.CityAddedToMap.Add(			OnCityAddedToMap );
	Events.CitySelectionChanged.Add(	OnCitySelectionChanged );
	Events.CityFocusChanged.Add(		OnCityFocusChange );
	Events.CityProductionCompleted.Add(	OnCityProductionCompleted );
	Events.CityProductionUpdated.Add(	OnCityProductionUpdated );	
	Events.CityProductionChanged.Add(	OnCityProductionChanged );
	Events.CityWorkerChanged.Add(		OnCityWorkerChanged );
	Events.DistrictDamageChanged.Add(	OnCityProductionChanged );
	Events.LocalPlayerTurnBegin.Add(	OnLocalPlayerTurnBegin );
	Events.ImprovementChanged.Add(		OnCityProductionChanged );
	Events.InterfaceModeChanged.Add(	OnInterfaceModeChanged );
	Events.LocalPlayerChanged.Add(		OnLocalPlayerChanged );
	Events.UnitSelectionChanged.Add(	OnUnitSelectionChanged );

	-- LUA Events
	LuaEvents.CityPanelOverview_CloseButton.Add( OnCloseOverviewPanel );
	LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );			-- hotloading help	
	LuaEvents.ProductionPanel_Close.Add( OnProductionPanelClose );
	LuaEvents.Tutorial_CityPanelOpen.Add( OnTutorialOpen );
	LuaEvents.Tutorial_ContextDisableItems.Add( OnTutorial_ContextDisableItems );

	-- Truncate possible static text overflows
	TruncateStringWithTooltip(Controls.BreakdownLabel,	MAX_BEFORE_TRUNC_STATIC_LABELS,	Controls.BreakdownLabel:GetText());
	TruncateStringWithTooltip(Controls.ReligionLabel,	MAX_BEFORE_TRUNC_STATIC_LABELS,	Controls.ReligionLabel:GetText());
	TruncateStringWithTooltip(Controls.AmenitiesLabel,	MAX_BEFORE_TRUNC_STATIC_LABELS,	Controls.AmenitiesLabel:GetText());
	TruncateStringWithTooltip(Controls.HousingLabel,	MAX_BEFORE_TRUNC_STATIC_LABELS,	Controls.HousingLabel:GetText());
end
Initialize();
