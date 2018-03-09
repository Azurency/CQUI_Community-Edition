-- ===========================================================================
--  CityPanel v3
-- ===========================================================================

include( "AdjacencyBonusSupport" );   -- GetAdjacentYieldBonusString()
include( "CitySupport" );
include( "Civ6Common" );        -- GetYieldString()
include( "Colors" );
include( "InstanceManager" );
include( "SupportFunctions" );      -- Round(), Clamp(), DarkenLightenColor()
include( "ToolTipHelper" );
include("GameCapabilities");
-- ===========================================================================
--  DEBUG
--  Toggle these for temporary debugging help.
-- ===========================================================================
local m_debugAllowMultiPanel  :boolean = false;   -- (false default) Let's multiple sub-panels show at one time.


-- ===========================================================================
--  CONSTANTS
-- ===========================================================================
local SIZE_SMALL_RELIGION_ICON    :number = 22;
local SIZE_LEADER_ICON        :number = 32;
local SIZE_PRODUCTION_ICON      :number = 32; -- TODO: Switch this to 38 when the icons go in.
local SIZE_MAIN_ROW_LEFT_WIDE   :number = 270;
local SIZE_MAIN_ROW_LEFT_COLLAPSED  :number = 157;
local TXT_NO_PRODUCTION       :string = Locale.Lookup("LOC_HUD_CITY_PRODUCTION_NOTHING_PRODUCED");
local MAX_BEFORE_TRUNC_TURN_LABELS  :number = 160;
local MAX_BEFORE_TRUNC_STATIC_LABELS:number = 112;
local HEX_GROWTH_TEXT_PADDING   :number = 10;

local UV_CITIZEN_GROWTH_STATUS    :table  = {};
    UV_CITIZEN_GROWTH_STATUS[0] = {u=0, v=0  };   -- revolt
    UV_CITIZEN_GROWTH_STATUS[1] = {u=0, v=0 };    -- unrest
    UV_CITIZEN_GROWTH_STATUS[2] = {u=0, v=0};   -- unhappy
    UV_CITIZEN_GROWTH_STATUS[3] = {u=0, v=50};    -- displeased
    UV_CITIZEN_GROWTH_STATUS[4] = {u=0, v=100};   -- content (normal)
    UV_CITIZEN_GROWTH_STATUS[5] = {u=0, v=150};   -- happy
    UV_CITIZEN_GROWTH_STATUS[6] = {u=0, v=200};   -- ecstatic

local UV_HOUSING_GROWTH_STATUS    :table = {};
    UV_HOUSING_GROWTH_STATUS[0] = {u=0, v=0};   -- slowed
    UV_HOUSING_GROWTH_STATUS[1] = {u=0, v=100};   -- normal

local UV_CITIZEN_STARVING_STATUS    :table = {};
    UV_CITIZEN_STARVING_STATUS[0] = {u=0, v=0};   -- starving
    UV_CITIZEN_STARVING_STATUS[1] = {u=0, v=100};   -- normal


-- ===========================================================================
--  VARIABLES
-- ===========================================================================

local m_kData           :table  = nil;
local m_isInitializing        :boolean= false;
local m_isShowingPanels       :boolean= false;
local m_pCity           :table  = nil;
local m_pPlayer           :table  = nil;
local m_primaryColor        :number = 0xcafef00d;
local m_secondaryColor        :number = 0xf00d1ace;
local m_kTutorialDisabledControls :table  = nil;
local m_GrowthPlot          :number = -1;

local CQUI_HousingFromImprovementsTable :table = {};    -- CQUI real housing from improvements table

-- ====================CQUI Cityview==========================================

local CQUI_cityview = false;
local CQUI_usingStrikeButton = false;
local CQUI_wonderMode = false;
local CQUI_growthTile = true;

function CQUI_CityviewEnableManager()
  CQUI_cityview = true;
  CQUI_wonderMode = false;
  LuaEvents.CQUI_ProductionPanel_CityviewEnable();
  LuaEvents.CQUI_CityPanel_CityviewEnable();
  LuaEvents.CQUI_CityPanelOverview_CityviewEnable();
  LuaEvents.CQUI_WorldInput_CityviewEnable();
end

function CQUI_CityviewDisableManager()
  CQUI_cityview = false;
  CQUI_wonderMode = false;
  LuaEvents.CQUI_ProductionPanel_CityviewDisable();
  LuaEvents.CQUI_CityPanel_CityviewDisable();
  LuaEvents.CQUI_CityPanelOverview_CityviewDisable();
  LuaEvents.CQUI_WorldInput_CityviewDisable();
end

function CQUI_OnCityviewEnabled()
  if ContextPtr:IsHidden() or Controls.CityPanelSlide:IsReversing() then
    ContextPtr:SetHide(false);
    Controls.CityPanelAlpha:SetToBeginning();
    Controls.CityPanelAlpha:Play();
    Controls.CityPanelSlide:SetToBeginning();
    Controls.CityPanelSlide:Play();
  end
    Refresh();
    UILens.ToggleLayerOn(LensLayers.PURCHASE_PLOT);
    UILens.ToggleLayerOn(LensLayers.CITIZEN_MANAGEMENT);
    UI.SetFixedTiltMode(true);
    DisplayGrowthTile();
    UI.SetInterfaceMode(InterfaceModeTypes.CITY_MANAGEMENT);

end

function CQUI_OnCityviewDisabled()
  Close();
  UI.DeselectAllCities();
  UILens.ToggleLayerOff(LensLayers.PURCHASE_PLOT);
  UILens.ToggleLayerOff(LensLayers.CITIZEN_MANAGEMENT);
  UI.SetFixedTiltMode(false);
  UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
end

function CQUI_WonderModeEnabled()
  CQUI_cityview = false;
  CQUI_wonderMode = true;
  Close();
  UILens.ToggleLayerOff(LensLayers.PURCHASE_PLOT);
  UILens.ToggleLayerOff(LensLayers.CITIZEN_MANAGEMENT);
end

-- AZURENCY : CQUI_CityviewDisableManager() call an unwanted UI.SetInterfaceMode(InterfaceModeTypes.SELECTION), this does not
function CQUI_HideCityInterface()
  CQUI_cityview = false;
  CQUI_wonderMode = false;
  LuaEvents.CQUI_ProductionPanel_CityviewDisable();
  Close();
  UILens.ToggleLayerOff(LensLayers.PURCHASE_PLOT);
  UILens.ToggleLayerOff(LensLayers.CITIZEN_MANAGEMENT);
  UI.SetFixedTiltMode(false);
  LuaEvents.CQUI_CityPanelOverview_CityviewDisable();
  LuaEvents.CQUI_WorldInput_CityviewDisable();
  HideGrowthTile(); -- AZURENCY : added the clear ClearGrowthTile() because why might not deselect the city but still want it hidden
end

LuaEvents.CQUI_CityPanel_CityviewEnable.Add( CQUI_OnCityviewEnabled);
LuaEvents.CQUI_CityPanel_CityviewDisable.Add( CQUI_OnCityviewDisabled);
LuaEvents.CQUI_CityviewDisable.Add( CQUI_CityviewDisableManager);
LuaEvents.CQUI_CityviewEnable.Add( CQUI_CityviewEnableManager);
LuaEvents.CQUI_CityviewHide.Add(CQUI_HideCityInterface);
LuaEvents.CQUI_Strike_Enter.Add (function() CQUI_usingStrikeButton = true; end)
LuaEvents.CQUI_Strike_Exit.Add (function() CQUI_usingStrikeButton = false; end)

function CQUI_OnInterfaceModeChanged( eOldMode:number, eNewMode:number )
  if(eNewMode == InterfaceModeTypes.CITY_RANGE_ATTACK or CQUI_usingStrikeButton) then
    LuaEvents.CQUI_CityviewHide(); -- AZURENCY : always hide the cityview if new mode is CITY_RANGE_ATTACK
  elseif(eOldMode == InterfaceModeTypes.CITY_MANAGEMENT or eOldMode == InterfaceModeTypes.DISTRICT_PLACEMENT or eOldMode == InterfaceModeTypes.BUILDING_PLACEMENT) then
    if(eNewMode == InterfaceModeTypes.DISTRICT_PLACEMENT or eNewMode == InterfaceModeTypes.BUILDING_PLACEMENT) then
      CQUI_WonderModeEnabled();
      HideGrowthTile();
      local newGrowthPlot:number = m_pCity:GetCulture():GetNextPlot();	--show the growth tile if the district or wonder can be placed there
      if(newGrowthPlot ~= -1) then
        if (eNewMode == InterfaceModeTypes.DISTRICT_PLACEMENT) then
          local districtHash:number	= UI.GetInterfaceModeParameter(CityOperationTypes.PARAM_DISTRICT_TYPE);
          local district:table		= GameInfo.Districts[districtHash];
          local kPlot		:table			= Map.GetPlotByIndex(newGrowthPlot);
          if kPlot:CanHaveDistrict(district.Index, m_pPlayer, m_pCity:GetID()) then
            DisplayGrowthTile();
          end
        elseif (eNewMode == InterfaceModeTypes.BUILDING_PLACEMENT) then
          local buildingHash :number = UI.GetInterfaceModeParameter(CityOperationTypes.PARAM_BUILDING_TYPE);
          local building = GameInfo.Buildings[buildingHash];
          local kPlot		:table			= Map.GetPlotByIndex(newGrowthPlot);
          if kPlot:CanHaveWonder(building.Index, m_pPlayer, m_pCity:GetID()) then
            DisplayGrowthTile();
          end
        end
      end
    elseif(eNewMode ~= InterfaceModeTypes.CITY_MANAGEMENT) then
      if(CQUI_wonderMode) then
        LuaEvents.CQUI_CityviewEnable();
      else
        LuaEvents.CQUI_CityviewDisable();
      end
    else
      LuaEvents.CQUI_CityviewEnable();
    end
  elseif(eOldMode == InterfaceModeTypes.CITY_RANGE_ATTACK) then
    if(eNewMode == InterfaceModeTypes.CITY_MANAGEMENT) then
      LuaEvents.CQUI_CityviewEnable(); -- AZURENCY : always show the cityview if new mode is CITY_MANAGEMENT
    else
      UI.DeselectAllCities()
    end
  end
end

-- Clear city culture growth tile overlay if one exists
function CQUI_ClearGrowthTile()
  if m_GrowthPlot ~= -1 then
    UILens.ClearHex(LensLayers.PURCHASE_PLOT, m_GrowthPlot);
    m_GrowthPlot = -1;
  end
end

function CQUI_OnCitySelectionChanged( ownerPlayerID:number, cityID:number, i:number, j:number, k:number, isSelected:boolean, isEditable:boolean)
  if (ownerPlayerID == Game.GetLocalPlayer()) then
    if (isSelected) then
      -- Determine if should switch to cityview mode
      local shouldSwitchToCityview:boolean = true;
      if UI.GetInterfaceMode() == InterfaceModeTypes.ICBM_STRIKE then
        -- During ICBM_STRIKE only switch to cityview if we're selecting a city
        -- which doesn't own the active missile silo
        local siloPlotX:number = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_X0);
        local siloPlotY:number = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_Y0);
        local siloPlot:table = Map.GetPlot(siloPlotX, siloPlotY);
        if siloPlot then
          local owningCity = Cities.GetPlotPurchaseCity(siloPlot);
          if owningCity:GetID() == cityID then
            shouldSwitchToCityview = false;
          end
        end
      end
      if (CQUI_usingStrikeButton) then
        shouldSwitchToCityview = false;
        -- AZURENCY : Set the strike mode back to the default value
        CQUI_usingStrikeButton = false;
      end
      if shouldSwitchToCityview then
        LuaEvents.CQUI_CityviewEnable();
        Refresh();
      end
    else
      HideGrowthTile();
    end
  end
end

function CQUI_OnNextCity()
  local kCity:table = UI.GetHeadSelectedCity();
  UI.SelectNextCity(kCity);
  UI.PlaySound("UI_Click_Sweetener_Metal_Button_Small");
end

function CQUI_OnPreviousCity()
  local kCity:table = UI.GetHeadSelectedCity();
  UI.SelectPrevCity(kCity);
  UI.PlaySound("UI_Click_Sweetener_Metal_Button_Small");
end

function CQUI_OnLoadScreenClose()
  CQUI_RecenterCameraGameStart();
end

-- ===========================================================================
--  Recenter camera at start of game
-- ===========================================================================
function CQUI_RecenterCameraGameStart()
  local startX, startY;
  local ePlayer :number = Game.GetLocalPlayer();
  local kPlayer         = Players[ePlayer];
  local cities = kPlayer:GetCities();

  -- If there is a city, center on the capital
  -- Else, center on a unit
  if cities:GetCount() > 0 then
      capital = cities:GetCapitalCity();
      startX = capital:GetX();
      startY = capital:GetY();
  else
      local units = kPlayer:GetUnits();
      local firstUnit = units:FindID(0);
      startX = firstUnit:GetX();
      startY = firstUnit:GetY();
  end
  UI.LookAtPlot( startX, startY );
end


-- Sets the visibility of the tile growth overlay
function CQUI_SetGrowthTile(state)
  GameConfiguration.SetValue("CQUI_ShowCultureGrowth", state);
  LuaEvents.CQUI_SettingsUpdate();
end
-- Toggles the visibility of the tile growth overlay
function CQUI_ToggleGrowthTile()
  CQUI_SetGrowthTile(not CQUI_growthTile);
end
function CQUI_SettingsUpdate()
  CQUI_growthTile = GameConfiguration.GetValue("CQUI_ShowCultureGrowth");
  if(m_GrowthPlot ~= -1 and not CQUI_growthTile) then
    UILens.ClearHex(LensLayers.PURCHASE_PLOT, m_GrowthPlot);
    m_GrowthPlot = -1;
  end
  if(UI.GetInterfaceMode() == InterfaceModeTypes.CITY_MANAGEMENT) then
    DisplayGrowthTile();
  end
end

-- ===========================================================================
--
-- ===========================================================================
function Close()
  Controls.CityPanelAlpha:SetToBeginning();
  Controls.CityPanelAlpha:Play();
  Controls.CityPanelSlide:SetToBeginning();
  Controls.CityPanelSlide:Play();
  ContextPtr:SetHide( true );
end

-- ===========================================================================
--  Helper, display the 3-way state of a yield based on the enum.
--  yieldData,  A YIELD_STATE
--  yieldName,  The name tied used in the check and ignore controls.
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
          checkControl:SetCheck(true);  -- Just visual, no callback!
          checkControl:SetDisabled(false);
          ignoreControl:SetHide(true);

          toolTip = Locale.Lookup("LOC_HUD_CITY_YIELD_FOCUSING", yieldInfo.Name) .. "[NEWLINE][NEWLINE]";
        elseif yieldData == YIELD_STATE.IGNORED then
          checkControl:SetCheck(false); -- Just visual, no callback!
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
--  Set the health meter
-- ===========================================================================
function RealizeHealthMeter( control:table, percent:number )
  if  ( percent > 0.7 ) then
    control:SetColor( COLORS.METER_HP_GOOD );
  elseif ( percent > 0.4 )  then
    control:SetColor( COLORS.METER_HP_OK );
  else
    control:SetColor( COLORS.METER_HP_BAD );
  end

  -- Meter control is half circle, so add enough to start at half point and condense % into the half area
  percent     = (percent * 0.5) + 0.5;
  control:SetPercent( percent );
end

-- ===========================================================================
--  Main city panel
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
    local percent     = (data.CityWallHPPercent * 0.5) + 0.5;
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

  local civType:string = PlayerConfigurations[data.Owner]:GetCivilizationTypeName();
  if civType ~= nil then
    Controls.CivIcon:SetIcon("ICON_" .. civType);
  else
    UI.DataError("Invalid type name returned by GetCivilizationTypeName");
  end

  -- Divine Yuri's Tooltip calculations (Some changes made for CQUI)
  local selectedCity  = UI.GetHeadSelectedCity();
  -- Food yield correction
  local iModifiedFood;
  local totalFood :number;
  if data.TurnsUntilGrowth > -1 then
    local growthModifier =  math.max(1 + (data.HappinessGrowthModifier/100) + data.OtherGrowthModifiers, 0); -- This is unintuitive but it's in parity with the logic in City_Growth.cpp
    iModifiedFood = Round(data.FoodSurplus * growthModifier, 2);
    if data.Occupied then
      totalFood = iModifiedFood * data.OccupationMultiplier;
    else
      totalFood = iModifiedFood * data.HousingMultiplier;
    end
  else
    totalFood = data.FoodSurplus;
  end
  -- Food p/turn tooltip
  local realFoodPerTurnToolTip = data.FoodPerTurnToolTip .."[NEWLINE]"..
    toPlusMinusString(-(data.FoodPerTurn - data.FoodSurplus)).." "..Locale.Lookup("LOC_HUD_CITY_FROM_POPULATION").."[NEWLINE][NEWLINE]"..
    GetColorPercentString(1 + data.HappinessGrowthModifier/100, 2) .. " "..Locale.Lookup("LOC_HUD_CITY_HAPPINESS_GROWTH_BONUS").."[NEWLINE]"..
    GetColorPercentString(1 + data.OtherGrowthModifiers, 2) .. " "..Locale.Lookup("LOC_HUD_CITY_OTHER_GROWTH_BONUSES").."[NEWLINE]"..
    GetColorPercentString(data.HousingMultiplier, 2).." "..Locale.Lookup("LOC_HUD_CITY_HOUSING_MULTIPLIER");
  if data.Occupied then
    realFoodPerTurnToolTip = realFoodPerTurnToolTip.."[NEWLINE]".."x"..data.OccupationMultiplier..Locale.Lookup("LOC_HUD_CITY_OCCUPATION_MULTIPLIER");
  end
  -- Religion tooltip/icon
  local ReligionTooltip :string;
  if ((table.count(data.Religions) > 1) or (data.PantheonBelief > -1)) then
    ReligionTooltip = Locale.Lookup("LOC_BELIEF_CLASS_PANTHEON_NAME") .. ":[NEWLINE]";

    if data.PantheonBelief > -1 then
      local kPantheonBelief = GameInfo.Beliefs[data.PantheonBelief];
      ReligionTooltip = ReligionTooltip..Locale.Lookup(kPantheonBelief.Name).."[NEWLINE]"..Locale.Lookup(kPantheonBelief.Description);
    end
    if (table.count(data.Religions) > 0) then
      local religiousMinorities = "";
      local religiousMinoritiesExist = false;
      for _,religion in ipairs(data.Religions) do
        local religionName  :string = Game.GetReligion():GetName(religion.ID);
        local iconName    :string = "ICON_" .. religion.ReligionType;
        if religion == data.Religions[DATA_DOMINANT_RELIGION] then
          Controls.ReligionIcon:SetIcon("ICON_" .. religion.ReligionType);
          ReligionTooltip = ReligionTooltip.."[NEWLINE][NEWLINE]"..Locale.Lookup("LOC_UI_RELIGION_NUM_FOLLOWERS_TT", religionName, religion.Followers);
        else
          if ( religion.ID > -1 and religion.Followers > 0) then
            religiousMinoritiesExist = true;
            religiousMinorities = religiousMinorities.. "[NEWLINE]"..Locale.Lookup("LOC_UI_RELIGION_NUM_FOLLOWERS_TT", religionName, religion.Followers);
          end
        end
      end
      for _, beliefIndex in ipairs(data.BeliefsOfDominantReligion) do
        local kBelief     :table = GameInfo.Beliefs[beliefIndex];
        ReligionTooltip = ReligionTooltip.."[NEWLINE][NEWLINE]"..Locale.Lookup(kBelief.Name).."[NEWLINE]"..Locale.Lookup(kBelief.Description);
      end
      if religiousMinoritiesExist then
        ReligionTooltip = ReligionTooltip.."[NEWLINE]---------------------[NEWLINE]"..Locale.Lookup("LOC_HUD_CITY_RELIGIOUS_MINORITIES").."[NEWLINE]"..religiousMinorities;
      end
    end
  else
    ReligionTooltip = Locale.Lookup("LOC_RELIGIONPANEL_NO_RELIGION");
  end
  -- District tooltip
  local DistrictTooltip = "";
  for i, district in ipairs(data.BuildingsAndDistricts) do
    if district.isBuilt then
      local districtName = district.Name;
      if district.isPillaged then
        districtName = districtName .. " "..Locale.Lookup("LOC_HUD_CITY_PILLAGED").." "
      end
      if ( i == 1 ) then
        DistrictTooltip = DistrictTooltip..""..districtName;
      else
        DistrictTooltip = DistrictTooltip.."[NEWLINE]"..districtName;
      end
      --district.YieldBonus
      for _,building in ipairs(district.Buildings) do
        if building.isBuilt then
          local buildingName = building.Name;
          if building.isPillaged then
            buildingName = buildingName .. " "..Locale.Lookup("LOC_HUD_CITY_PILLAGED").." "
          end
          DistrictTooltip = DistrictTooltip.."[NEWLINE]".."[ICON_BULLET]"..buildingName;
        end
      end
    end
  end
  -- Amenities tooltip
  local HappinessTooltipString = Locale.Lookup(GameInfo.Happinesses[data.Happiness].Name);
  HappinessTooltipString = HappinessTooltipString.."[NEWLINE]";
  local tableChanges = {};
  tableChanges["Neg"] = {}
  tableChanges["Pos"] = {};
  function repeatAvoidAddNew( TextKey, dataID, isNegative, special)
    local textValue = Locale.Lookup(TextKey, "");
    if (isNegative) then
      if special then
        table.insert(tableChanges["Neg"], {Amenities = Locale.ToNumber(data[dataID]), AmenityType = textValue.." "});
      elseif (data["AmenitiesLostFrom"..dataID] ~= 0) then
        table.insert(tableChanges["Neg"], {Amenities = Locale.ToNumber(data["AmenitiesLostFrom"..dataID]), AmenityType = textValue});
      end
    else
      if( data["AmenitiesFrom"..dataID] > 0) then
        table.insert(tableChanges["Pos"], {Amenities = Locale.ToNumber(data["AmenitiesFrom"..dataID]), AmenityType = textValue});
      end
    end
  end
  repeatAvoidAddNew("LOC_HUD_CITY_AMENITIES_FROM_LUXURIES",       "Luxuries"              );
  repeatAvoidAddNew("LOC_HUD_CITY_AMENITIES_FROM_CIVICS",       "Civics"              );
  repeatAvoidAddNew("LOC_HUD_CITY_AMENITIES_FROM_ENTERTAINMENT",    "Entertainment"           );
  repeatAvoidAddNew("LOC_HUD_CITY_AMENITIES_FROM_GREAT_PEOPLE",     "GreatPeople"           );
  repeatAvoidAddNew("LOC_HUD_CITY_AMENITIES_FROM_RELIGION",       "Religion"              );
  repeatAvoidAddNew("LOC_HUD_CITY_AMENITIES_FROM_NATIONAL_PARKS",   "NationalParks"           );
  repeatAvoidAddNew("LOC_HUD_CITY_AMENITIES_FROM_STARTING_ERA",     "StartingEra"             );
  repeatAvoidAddNew("LOC_HUD_CITY_AMENITIES_LOST_FROM_WAR_WEARINESS", "WarWeariness",     true    );
  repeatAvoidAddNew("LOC_HUD_CITY_AMENITIES_LOST_FROM_BANKRUPTCY",  "Bankruptcy",       true    );
  repeatAvoidAddNew("LOC_HUD_REPORTS_FROM_POPULATION",           "AmenitiesRequiredNum", true, true  );
  function AmenitiesSort(a, b)
    return a["Amenities"] > b["Amenities"];
  end
  table.sort(tableChanges["Neg"], AmenitiesSort);
  table.sort(tableChanges["Pos"], AmenitiesSort);
  for _, aTable in pairs(tableChanges["Pos"])do
    HappinessTooltipString = HappinessTooltipString.."[NEWLINE]+"..aTable.Amenities.." "..aTable.AmenityType:sub(1, -2).."";
  end
  for _, aTable in pairs(tableChanges["Neg"])do
    HappinessTooltipString = HappinessTooltipString.."[NEWLINE]-"..aTable.Amenities.." "..aTable.AmenityType:sub(1, -2).."";
  end
  if data.HappinessGrowthModifier ~= 0 then
    local growthInfo:string =
      GetColorPercentString(Round(1 + (data.HappinessGrowthModifier/100), 2)) .. " " ..
      Locale.Lookup("LOC_HUD_CITY_CITIZEN_GROWTH") .. "[NEWLINE]" ..
      GetColorPercentString(Round(1 + (data.HappinessNonFoodYieldModifier/100), 2)) .. " "..
      Locale.ToUpper( Locale.Lookup("LOC_HUD_CITY_ALL_YIELDS") );
    HappinessTooltipString = HappinessTooltipString.."[NEWLINE][NEWLINE]"..growthInfo;
  end
  -- Housing tooltip
  local HousingTooltip = "";
  if data.HousingMultiplier == 0 then
    HousingTooltip = Locale.Lookup("LOC_HUD_CITY_POPULATION_GROWTH_HALTED");
  else
    if data.HousingMultiplier <= 0.5 then
      HousingTooltip = Locale.Lookup("LOC_HUD_CITY_POPULATION_GROWTH_SLOWED", (1 - data.HousingMultiplier) * 100);
    else
      HousingTooltip = Locale.Lookup("LOC_HUD_CITY_POPULATION_GROWTH_NORMAL");
    end
  end
  -- Production info
  local buildQueue  = selectedCity:GetBuildQueue();
  local currentProductionHash   = buildQueue:GetCurrentProductionTypeHash();
  local productionHash = 0;

  if( currentProductionHash == 0 ) then
    productionHash = buildQueue:GetPreviousProductionTypeHash();
  else
    productionHash = currentProductionHash;
  end
  local currentProductionInfo       :table = GetProductionInfoOfCity( data.City, productionHash );


  -- Set icons and values for the yield checkboxes
  Controls.CultureCheck:GetTextButton():SetText(    "[ICON_Culture]"  ..toPlusMinusString(data.CulturePerTurn) );
  Controls.FoodCheck:GetTextButton():SetText(     "[ICON_Food]"   ..toPlusMinusString(totalFood) );
  Controls.ProductionCheck:GetTextButton():SetText( "[ICON_Production]" ..toPlusMinusString(data.ProductionPerTurn) );
  Controls.ScienceCheck:GetTextButton():SetText(    "[ICON_Science]"  ..toPlusMinusString(data.SciencePerTurn) );
  Controls.FaithCheck:GetTextButton():SetText(    "[ICON_Faith]"    ..toPlusMinusString(data.FaithPerTurn) );
  Controls.GoldCheck:GetTextButton():SetText(     "[ICON_Gold]"   ..toPlusMinusString(data.GoldPerTurn) );

  -- Set the Yield checkboxes based on the game state
  RealizeYield3WayCheck( data.YieldFilters[YieldTypes.CULTURE], YieldTypes.CULTURE, data.CulturePerTurnToolTip);
  RealizeYield3WayCheck( data.YieldFilters[YieldTypes.FAITH], YieldTypes.FAITH, data.FaithPerTurnToolTip);
  RealizeYield3WayCheck( data.YieldFilters[YieldTypes.FOOD], YieldTypes.FOOD, realFoodPerTurnToolTip);
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
  Controls.BreakdownNum:SetText( data.DistrictsNum.."/"..data.DistrictsPossibleNum );
  Controls.BreakdownGrid:SetToolTipString(DistrictTooltip);
  Controls.AmenitiesGrid:SetToolTipString(HappinessTooltipString);
  Controls.ReligionGrid:SetToolTipString(ReligionTooltip);
  Controls.HousingGrid:SetToolTipString(HousingTooltip);

  local amenitiesNumText = data.AmenitiesNetAmount;
  if (data.AmenitiesNetAmount > 0) then
    amenitiesNumText = "+" .. amenitiesNumText;
  end
  Controls.AmenitiesNum:SetText( amenitiesNumText );
  local colorName:string = GetHappinessColor( data.Happiness );
  Controls.AmenitiesNum:SetColorByName( colorName );

  Controls.ReligionNum:SetText( data.ReligionFollowers );

  -- CQUI get real housing from improvements value
  local selectedCityID = selectedCity:GetID();
  local CQUI_HousingFromImprovements = CQUI_HousingFromImprovementsTable[selectedCityID];

  Controls.HousingNum:SetText( data.Population );
  colorName = GetPercentGrowthColor( data.HousingMultiplier );
  Controls.HousingNum:SetColorByName( colorName );
  Controls.HousingMax:SetText( data.Housing - data.HousingFromImprovements + CQUI_HousingFromImprovements );    -- CQUI calculate real housing

  Controls.BreakdownLabel:SetHide( m_isShowingPanels );
  Controls.ReligionLabel:SetHide( m_isShowingPanels );
  Controls.AmenitiesLabel:SetHide( m_isShowingPanels );
  Controls.HousingLabel:SetHide( m_isShowingPanels );
  Controls.PanelStackShadow:SetHide( not m_isShowingPanels );
  Controls.ProductionNowLabel:SetHide( m_isShowingPanels );

  -- Hide Religion / Faith UI in some scenarios
  if not GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_RELIGION_TAB") then
    Controls.ReligionGrid:SetHide(true);
    Controls.ReligionIcon:SetHide(true);
  end
  if not GameCapabilities.HasCapability("CAPABILITY_FAITH") then
    Controls.ProduceWithFaithCheck:SetHide(true);
    Controls.FaithGrid:SetHide(true);
    Controls.ActionStack:ReprocessAnchoring();
    Controls.YieldStack:ReprocessAnchoring();
  end

  -- Determine size of progress bars at the bottom, as well as sub-panel offset.
  local OFF_BOTTOM_Y            :number = 9;
  local OFF_ROOM_FOR_PROGRESS_Y     :number = 36;
  local OFF_GROWTH_BAR_PUSH_RIGHT_X   :number = 2;
  local OFF_GROWTH_BAR_DEFAULT_RIGHT_X  :number = 32;
  local widthNumLabel       :number = 0;

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
  else
    local CurFood = Round(data.CurrentFood, 1);
    local FoodGainNextTurn = Round(data.FoodGainNextTurn, 1);
    local RequiredFood = data.RequiredFood;
    if (data.TurnsUntilGrowth >= 0) then
      Controls.GrowthLabel:SetColorByName("StatGoodCS");
      Controls.GrowthLabel:SetText( "  "..CurFood.." / "..RequiredFood.."  (+"..FoodGainNextTurn.."[ICON_Food])");
    else
      Controls.GrowthLabel:SetColorByName("StatBadCS");
      Controls.GrowthLabel:SetText( "  "..CurFood.." / "..RequiredFood.."  ("..data.FoodSurplus.."[ICON_Food])");
    end
  end

  widthNumLabel = Controls.GrowthNum:GetSizeX();
  TruncateStringWithTooltip(Controls.GrowthLabel, MAX_BEFORE_TRUNC_TURN_LABELS-widthNumLabel, Controls.GrowthLabel:GetText());

  --Production

  --Controls.ProductionTurns:SetHide( m_isShowingPanels );
  Controls.CurrentProductionProgress:SetPercent(data.CurrentProdPercent);
  Controls.CurrentProductionProgress:SetShadowPercent(data.ProdPercentNextTurn);
  Controls.CurrentProductionCost:SetText( data.CurrentTurnsLeft );
  Controls.ProductionLabel:SetText(currentProductionInfo.Progress.."/"..currentProductionInfo.Cost.."  (+"..data.ProductionPerTurn.." [ICON_Production])");
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

  Controls.CurrentProductionCost:SetHide( data.CurrentTurnsLeft < 0 );
  Controls.ProductionLabel:SetHide( data.CurrentTurnsLeft < 0 );

  if data.CurrentTurnsLeft < 0 then
    Controls.ProductionLabel:SetText( Locale.ToUpper( Locale.Lookup("LOC_HUD_CITY_NOTHING_PRODUCED")) );
    widthNumLabel = 0;
  end

  TruncateStringWithTooltip(Controls.ProductionLabel, MAX_BEFORE_TRUNC_TURN_LABELS-widthNumLabel, Controls.ProductionLabel:GetText());
  Controls.CurrentProductionProgress:ReprocessAnchoring();  -- Fixes up children elements inside of the bar.

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
--  Return ColorSet name
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
--  Return ColorSet name
-- ===========================================================================
function GetTurnsUntilGrowthColor( turns:number )
  if  turns < 1 then return "StatBadCS"; end
  return "StatGoodCS";
end

function GetPercentGrowthColor( percent:number )
  if percent == 0 then return "Error"; end
  if percent <= 0.25 then return "WarningMajor"; end
  if percent <= 0.5 then return "WarningMinor"; end
  return "StatNormalCS";
end


-- ===========================================================================
--  Changes the yield focus.
-- ===========================================================================
function SetYieldFocus( yieldType:number )
  local pCitizens   :table = m_pCity:GetCitizens();
  local tParameters :table = {};
  tParameters[CityCommandTypes.PARAM_FLAGS]   = 0;      -- Set Favored
  tParameters[CityCommandTypes.PARAM_YIELD_TYPE]= yieldType;  -- Yield type
  if pCitizens:IsFavoredYield(yieldType) then
    tParameters[CityCommandTypes.PARAM_DATA0]= 0;      -- boolean (1=true, 0=false)
  else
    if pCitizens:IsDisfavoredYield(yieldType) then
      SetYieldIgnore(yieldType);
    end
    tParameters[CityCommandTypes.PARAM_DATA0] = 1;     -- boolean (1=true, 0=false)
  end
  CityManager.RequestCommand(m_pCity, CityCommandTypes.SET_FOCUS, tParameters);
end

-- ===========================================================================
--  Changes what yield type(s) should be ignored by citizens
-- ===========================================================================
function SetYieldIgnore( yieldType:number )
  local pCitizens   :table = m_pCity:GetCitizens();
  local tParameters :table = {};
  tParameters[CityCommandTypes.PARAM_FLAGS]   = 1;      -- Set Ignored
  tParameters[CityCommandTypes.PARAM_YIELD_TYPE]= yieldType;  -- Yield type
  if pCitizens:IsDisfavoredYield(yieldType) then
    tParameters[CityCommandTypes.PARAM_DATA0]= 0;      -- boolean (1=true, 0=false)
  else
    if ( pCitizens:IsFavoredYield(yieldType) ) then
      SetYieldFocus(yieldType);
    end
    tParameters[CityCommandTypes.PARAM_DATA0] = 1;     -- boolean (1=true, 0=false)
  end
  CityManager.RequestCommand(m_pCity, CityCommandTypes.SET_FOCUS, tParameters);
end


-- ===========================================================================
--  Update both the data & view for the selected city.
-- ===========================================================================
function Refresh()
  local eLocalPlayer :number = Game.GetLocalPlayer();
  m_pPlayer= Players[eLocalPlayer];
  m_pCity  = UI.GetHeadSelectedCity();

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
    LuaEvents.UpdateBanner(Game.GetLocalPlayer(), m_pCity:GetID());
  end
end

function RefreshOnTurnRoll()
  --print("Turn Roll City Panel Update");
  local pPlayer = Game.GetLocalPlayer();

  m_pCity  = UI.GetHeadSelectedCity();

  if m_pCity ~= nil then
    local pCitizens   :table = m_pCity:GetCitizens();
    local tParameters :table = {};

    if pCitizens:IsFavoredYield(YieldTypes.CULTURE) then
      tParameters[CityCommandTypes.PARAM_FLAGS]   = 0;      -- Set favoured
      tParameters[CityCommandTypes.PARAM_DATA0] = 1;          -- on
    elseif pCitizens:IsDisfavoredYield(YieldTypes.CULTURE) then
      tParameters[CityCommandTypes.PARAM_FLAGS]   = 1;      -- Set Ignored
      tParameters[CityCommandTypes.PARAM_DATA0] = 1;          -- on
    else
      tParameters[CityCommandTypes.PARAM_FLAGS]   = 0;      -- Set favoured
      tParameters[CityCommandTypes.PARAM_DATA0] = 0;          -- off

    end

    tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = YieldTypes.CULTURE;  -- Yield type
    CityManager.RequestCommand(m_pCity, CityCommandTypes.SET_FOCUS, tParameters);

    m_kData = GetCityData( m_pCity );
    if m_kData == nil then
      return;
    end

    --print("=============================================================");
    --print("Updating City Panel Details Due To Turn Roll");
    --print("=============================================================");

    ViewMain( m_kData );

    -- Tell others (e.g., CityPanelOverview) that the selected city data has changed.
    -- Passing this large table across contexts via LuaEvent is *much*
    -- more effecient than recomputing the entire set of yields a second time,
    -- despite the large size.
    LuaEvents.CityPanel_LiveCityDataChanged( m_kData, true );
    LuaEvents.UpdateBanner(Game.GetLocalPlayer(), m_pCity:GetID());

  end

end

-- ===========================================================================
function RefreshIfMatch( ownerPlayerID:number, cityID:number )
  if m_pCity ~= nil and ownerPlayerID == m_pCity:GetOwner() and cityID == m_pCity:GetID() then
    Refresh();
  end
end

-- ===========================================================================
function OnTileImproved(x, y)
  --print("A Tile Was Improved!");
  local plot:table = Map.GetPlot(x,y);
  local PlayerID = Game.GetLocalPlayer();

  m_pCity = Cities.GetPlotPurchaseCity(plot);

  if (m_pCity ~= nil) then

    --print("Location: " .. x .."," .. y);
    --print("Player: " .. PlayerID);
    --print("City Owner: " .. m_pCity:GetOwner());

    if (PlayerID == m_pCity:GetOwner()) then
      --print("City: " .. m_pCity:GetID());

      local pCitizens   :table = m_pCity:GetCitizens();
      local tParameters :table = {};

      if pCitizens:IsFavoredYield(YieldTypes.CULTURE) then
        tParameters[CityCommandTypes.PARAM_FLAGS]   = 0;      -- Set favoured
        tParameters[CityCommandTypes.PARAM_DATA0] = 1;          -- on
      elseif pCitizens:IsDisfavoredYield(YieldTypes.CULTURE) then
        tParameters[CityCommandTypes.PARAM_FLAGS]   = 1;      -- Set Ignored
        tParameters[CityCommandTypes.PARAM_DATA0] = 1;          -- on
      else
        tParameters[CityCommandTypes.PARAM_FLAGS]   = 0;      -- Set favoured
        tParameters[CityCommandTypes.PARAM_DATA0] = 0;          -- off
      end

      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = YieldTypes.CULTURE;  -- Yield type
      CityManager.RequestCommand(m_pCity, CityCommandTypes.SET_FOCUS, tParameters);

      m_kData = GetCityData( m_pCity );
      --m_kData = GetCityData( m_pCity );
      if m_kData == nil then
        return;
      end

      --print("=============================================================");
      --print("Updating City Panel Details Due To Yield Change");
      --print("=============================================================");

      --ViewMain( m_kData );

      -- Tell others (e.g., CityPanelOverview) that the selected city data has changed.
      -- Passing this large table across contexts via LuaEvent is *much*
      -- more effecient than recomputing the entire set of yields a second time,
      -- despite the large size.
      LuaEvents.CityPanel_LiveCityDataChanged( m_kData, true );
      --LuaEvents.UpdateBanner(Game.GetLocalPlayer(), m_pCity:GetID());

      -- CQUI update city's real housing
      local pCityID = m_pCity:GetID();
      LuaEvents.CQUI_CityInfoUpdated(pCityID);
    end
  end
end

-- ===========================================================================
--  GAME Event
-- ===========================================================================
function OnPlayerResourceChanged( ownerPlayerID:number, resourceTypeID:number)
  if (Game.GetLocalPlayer() ~= nil and ownerPlayerID == Game.GetLocalPlayer()) then
    Refresh();
  end
end

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

function OnCityNameChanged( playerID:number, cityID:number )
  local city = UI.GetHeadSelectedCity();
  if(city and city:GetOwner() == playerID and city:GetID() == cityID) then
    local name = city:IsCapital() and "[ICON_Capital]" or "";
    name = name .. Locale.ToUpper(Locale.Lookup(city:GetName()));
    Controls.CityName:SetText(name);
  end
end

-- ===========================================================================
--  GAME Event
--  Yield changes
-- ===========================================================================
function OnCityFocusChange(ownerPlayerID:number, cityID:number)
  RefreshIfMatch(ownerPlayerID, cityID);
end

-- ===========================================================================
--  GAME Event
-- ===========================================================================
function OnCityWorkerChanged(ownerPlayerID:number, cityID:number)
  RefreshIfMatch(ownerPlayerID, cityID);
end

-- ===========================================================================
--  GAME Event
-- ===========================================================================
function OnCityProductionChanged(ownerPlayerID:number, cityID:number)
  if Controls.ChangeProductionCheck:IsChecked() then
    Controls.ChangeProductionCheck:SetCheck(false);
  end
  RefreshIfMatch(ownerPlayerID, cityID);
end

-- ===========================================================================
--  GAME Event
-- ===========================================================================
function OnCityProductionCompleted(ownerPlayerID:number, cityID:number)
  RefreshIfMatch(ownerPlayerID, cityID);
end

-- ===========================================================================
--  GAME Event
-- ===========================================================================
function OnCityProductionUpdated( ownerPlayerID:number, cityID:number, eProductionType, eProductionObject)
  RefreshIfMatch(ownerPlayerID, cityID);
end

-- ===========================================================================
--  GAME Event
-- ===========================================================================
function OnToggleOverviewPanel()
  if Controls.ToggleOverviewPanel:IsChecked() then
    LuaEvents.CityPanel_ShowOverviewPanel(true);
  else
    LuaEvents.CityPanel_ShowOverviewPanel(false);
  end
end

-- ===========================================================================
--  GAME Event
-- ===========================================================================
function OnUnitSelectionChanged( playerID:number, unitID:number, hexI:number, hexJ:number, hexK:number, isSelected:boolean, isEditable:boolean )
  if playerID == Game.GetLocalPlayer() then
    if ContextPtr:IsHidden()==false then
      Close();
      Controls.ToggleOverviewPanel:SetAndCall(false);
    end
  end
end

-- ===========================================================================
--  UI Event
-- ===========================================================================
function OnInit( isHotload:boolean )
  if isHotload then
    LuaEvents.GameDebug_GetValues( "CityPanel");
  end
  m_isInitializing = false;
  Refresh();
end


-- ===========================================================================
--  UI EVENT
-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string)
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end

-- ===========================================================================
--  UI EVENT
-- ===========================================================================
function OnShutdown()
  -- Cache values for hotloading...
  LuaEvents.GameDebug_AddValue("CityPanel", "isHidden",       ContextPtr:IsHidden() );
end

-- ===========================================================================
--  LUA Event
--  Set cached values back after a hotload.
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
--  LUA Event
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
--  LUA Event
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
--  if m_isInitializing then return; end
--  if not m_debugAllowMultiPanel then
--    UILens.ToggleLayerOff(LensLayers.ADJACENCY_BONUS_DISTRICTS);
--    UILens.ToggleLayerOff(LensLayers.DISTRICTS);
--  end
--  Refresh();
--end

-- ===========================================================================
function OnCitizensGrowth()
  LuaEvents.CityPanel_ShowCitizensTab();
end

-- ===========================================================================
--  Set a yield to one of 3 check states.
--  yieldType Enum from game engine on the yield
--  yieldName Name of the yield used in the UI controls
-- ===========================================================================
function OnCheckYield( yieldType:number, yieldName:string )
  if Controls.YieldsArea:IsDisabled() then return; end  -- Via tutorial event
  if Controls[yieldName.."Check"]:IsChecked() then
    SetYieldFocus( yieldType );
  else
    SetYieldIgnore( yieldType );
    Controls[yieldName.."Ignore"]:SetHide( false );
    Controls[yieldName.."Check"]:SetDisabled( true );
  end
end

-- ===========================================================================
--  Reset a yield to not be favored nor ignored
--  yieldType Enum from game engine on the yield
--  yieldName Name of the yield used in the UI controls
-- ===========================================================================
function OnResetYieldToNormal( yieldType:number, yieldName:string )
  if Controls.YieldsArea:IsDisabled() then return; end  -- Via tutorial event
  Controls[yieldName.."Ignore"]:SetHide( true );
  Controls[yieldName.."Check"]:SetDisabled( false );
  SetYieldIgnore( yieldType );    -- One more ignore to flip it off
end

-- ===========================================================================
--  Recenter camera on city
-- ===========================================================================
function RecenterCameraOnCity()
  local kCity:table = UI.GetHeadSelectedCity();
  UI.LookAtPlot( kCity:GetX(), kCity:GetY() );
end

-- ===========================================================================
--  Turn on/off layers and switch the interface mode based on what is checked.
--  Interface mode is changed first as the Lens system may inquire as to the
--  current state in deciding what is populate in a lens layer.
-- ===========================================================================
function OnTogglePurchaseTile()
  if Controls.PurchaseTileCheck:IsChecked() then
    if not Controls.ManageCitizensCheck:IsChecked() then
      UI.SetInterfaceMode(InterfaceModeTypes.CITY_MANAGEMENT);  -- Enter mode
    end
    RecenterCameraOnCity();
    UILens.ToggleLayerOn( LensLayers.PURCHASE_PLOT );
  else
    if not Controls.ManageCitizensCheck:IsChecked() and UI.GetInterfaceMode() == InterfaceModeTypes.CITY_MANAGEMENT then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);      -- Exit mode
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
--  Turn on/off layers and switch the interface mode based on what is checked.
--  Interface mode is changed first as the Lens system may inquire as to the
--  current state in deciding what is populate in a lens layer.
-- ===========================================================================
function OnToggleManageCitizens()
end

-- ===========================================================================
function OnLocalPlayerTurnBegin()
  Refresh();
end

-- ===========================================================================
--  Enable a control unless it's in the tutorial lock down list.
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

function OnCameraUpdate( vFocusX:number, vFocusY:number, fZoomLevel:number )
  if m_GrowthPlot ~= -1 then

    if fZoomLevel and fZoomLevel > 0.5 then
      local delta:number = (fZoomLevel - 0.3);
      local alpha:number = delta / 0.7;
      Controls.GrowthHexAlpha:SetProgress(alpha);
    else
      Controls.GrowthHexAlpha:SetProgress(0);
    end

    local plotX:number, plotY:number = Map.GetPlotLocation(m_GrowthPlot);
    local worldX:number, worldY:number, worldZ:number = UI.GridToWorld(plotX, plotY);
    Controls.GrowthHexAnchor:SetWorldPositionVal(worldX, worldY + HEX_GROWTH_TEXT_PADDING, worldZ);
  end
end

function DisplayGrowthTile()
  if m_pCity ~= nil and HasCapability("CAPABILITY_CULTURE") then
    local cityCulture:table = m_pCity:GetCulture();
    if cityCulture ~= nil then
      local newGrowthPlot:number = cityCulture:GetNextPlot();
      if(newGrowthPlot ~= -1 and newGrowthPlot ~= m_GrowthPlot and CQUI_growthTile) then
        m_GrowthPlot = newGrowthPlot;

        local cost:number = cityCulture:GetNextPlotCultureCost();
        local currentCulture:number = cityCulture:GetCurrentCulture();
        local currentYield:number = cityCulture:GetCultureYield();
        local currentGrowth:number = math.max(math.min(currentCulture / cost, 1.0), 0);
        local nextTurnGrowth:number = math.max(math.min((currentCulture + currentYield) / cost, 1.0), 0);

        UILens.SetLayerGrowthHex(LensLayers.PURCHASE_PLOT, Game.GetLocalPlayer(), m_GrowthPlot, 1, "GrowthHexBG");
        UILens.SetLayerGrowthHex(LensLayers.PURCHASE_PLOT, Game.GetLocalPlayer(), m_GrowthPlot, nextTurnGrowth, "GrowthHexNext");
        UILens.SetLayerGrowthHex(LensLayers.PURCHASE_PLOT, Game.GetLocalPlayer(), m_GrowthPlot, currentGrowth, "GrowthHexCurrent");

        local turnsRemaining:number = cityCulture:GetTurnsUntilExpansion();
        Controls.TurnsLeftDescription:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_CITY_TURNS_UNTIL_BORDER_GROWTH", turnsRemaining)));
        Controls.TurnsLeftLabel:SetText(turnsRemaining);
        Controls.GrowthHexStack:CalculateSize();
        m_GrowthHexTextWidth = Controls.GrowthHexStack:GetSizeX();

        Events.Camera_Updated.Add(OnCameraUpdate);
        Controls.GrowthHexAnchor:SetHide(false);
        OnCameraUpdate();
      end
    end
  end
end

function HideGrowthTile()
  if m_GrowthPlot ~= -1 then
    Controls.GrowthHexAnchor:SetHide(true);
    Events.Camera_Updated.Remove(OnCameraUpdate);
    UILens.ClearHex(LensLayers.PURCHASE_PLOT, m_GrowthPlot);
    m_GrowthPlot = -1;
  end
end

-- ===========================================================================
--  Engine EVENT
--  Local player changed; likely a hotseat game
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
--  Show/hide an area based on the status of a checkbox control
--  checkBoxControl   A checkbox control that when selected is open
--  buttonControl   (optional) button control that toggles the state
--  areaControl     The area to be shown/hidden
--  kParentControls   Table of controls to call ReprocessAnchoring on toggle
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
--  LUA Event
--  Tutorial requests controls that should always be locked down.
--  Send nil to clear.
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
-- CQUI get real housing from improvements
function CQUI_HousingFromImprovementsTableInsert (pCityID, CQUI_HousingFromImprovements)
  CQUI_HousingFromImprovementsTable[pCityID] = CQUI_HousingFromImprovements;
end

-- ===========================================================================
--  CTOR
-- ===========================================================================
function Initialize()
  LuaEvents.CityPanel_OpenOverview();

  m_isInitializing = true;

  -- Context Events
  ContextPtr:SetInitHandler( OnInit );
  ContextPtr:SetShutdown( OnShutdown );

  -- Control Events
  Controls.BreakdownButton:RegisterCallback(    Mouse.eLClick,  OnBreakdown );
  Controls.ReligionButton:RegisterCallback(   Mouse.eLClick,  OnReligion );
  Controls.AmenitiesButton:RegisterCallback(    Mouse.eLClick,  OnAmenities );
  Controls.HousingButton:RegisterCallback(    Mouse.eLClick,  OnHousing );
  Controls.CitizensGrowthButton:RegisterCallback( Mouse.eLClick,  OnCitizensGrowth );

  Controls.CultureCheck:RegisterCheckHandler(         function() OnCheckYield( YieldTypes.CULTURE,  "Culture"); end );
  Controls.FaithCheck:RegisterCheckHandler(         function() OnCheckYield( YieldTypes.FAITH,    "Faith"); end );
  Controls.FoodCheck:RegisterCheckHandler(          function() OnCheckYield( YieldTypes.FOOD,   "Food"); end );
  Controls.GoldCheck:RegisterCheckHandler(          function() OnCheckYield( YieldTypes.GOLD,   "Gold"); end );
  Controls.ProductionCheck:RegisterCheckHandler(        function() OnCheckYield( YieldTypes.PRODUCTION, "Production"); end );
  Controls.ScienceCheck:RegisterCheckHandler(         function() OnCheckYield( YieldTypes.SCIENCE,  "Science"); end );
  Controls.CultureIgnore:RegisterCallback(  Mouse.eLClick,  function() OnResetYieldToNormal( YieldTypes.CULTURE,  "Culture"); end);
  Controls.FaithIgnore:RegisterCallback(    Mouse.eLClick,  function() OnResetYieldToNormal( YieldTypes.FAITH,    "Faith"); end);
  Controls.FoodIgnore:RegisterCallback(   Mouse.eLClick,  function() OnResetYieldToNormal( YieldTypes.FOOD,   "Food"); end);
  Controls.GoldIgnore:RegisterCallback(   Mouse.eLClick,  function() OnResetYieldToNormal( YieldTypes.GOLD,   "Gold"); end);
  Controls.ProductionIgnore:RegisterCallback( Mouse.eLClick,  function() OnResetYieldToNormal( YieldTypes.PRODUCTION, "Production"); end);
  Controls.ScienceIgnore:RegisterCallback(  Mouse.eLClick,  function() OnResetYieldToNormal( YieldTypes.SCIENCE,  "Science"); end);
  Controls.NextCityButton:RegisterCallback( Mouse.eLClick,  CQUI_OnNextCity);
  Controls.PrevCityButton:RegisterCallback( Mouse.eLClick,  CQUI_OnPreviousCity);

  -- CQUI recenter on the city when clicking the round icon in the panel
  Controls.CircleBacking:RegisterCallback( Mouse.eLClick,  RecenterCameraOnCity);

  if GameCapabilities.HasCapability("CAPABILITY_GOLD") then
    Controls.PurchaseTileCheck:RegisterCheckHandler(OnTogglePurchaseTile );
    Controls.PurchaseTileCheck:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  else
    Controls.PurchaseTileCheck:SetHide(true);
  end

  Controls.ManageCitizensCheck:RegisterCheckHandler(  OnToggleManageCitizens );
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
  Events.CityAddedToMap.Add(      OnCityAddedToMap );
  Events.CityNameChanged.Add(     OnCityNameChanged );
  Events.CitySelectionChanged.Add(  CQUI_OnCitySelectionChanged );
  Events.CityFocusChanged.Add(    OnCityFocusChange );
  Events.CityProductionCompleted.Add( OnCityProductionCompleted );
  Events.CityProductionUpdated.Add( OnCityProductionUpdated );
  Events.CityProductionChanged.Add( OnCityProductionChanged );
  Events.CityWorkerChanged.Add(   OnCityWorkerChanged );
  Events.DistrictDamageChanged.Add( OnCityProductionChanged );
  Events.LocalPlayerTurnBegin.Add(  OnLocalPlayerTurnBegin );
  Events.ImprovementChanged.Add(    OnCityProductionChanged );
  Events.InterfaceModeChanged.Add(  CQUI_OnInterfaceModeChanged );
  Events.LocalPlayerChanged.Add(    OnLocalPlayerChanged );
  Events.UnitSelectionChanged.Add(  OnUnitSelectionChanged );
  Events.PlayerResourceChanged.Add( OnPlayerResourceChanged );
  Events.LoadScreenClose.Add( CQUI_OnLoadScreenClose );
  Events.PlotYieldChanged.Add(        OnTileImproved );
  Events.PlayerTurnActivated.Add(   RefreshOnTurnRoll );

  -- LUA Events
  LuaEvents.CityPanelOverview_CloseButton.Add( OnCloseOverviewPanel );
  LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );      -- hotloading help
  LuaEvents.ProductionPanel_Close.Add( OnProductionPanelClose );
  LuaEvents.Tutorial_CityPanelOpen.Add( OnTutorialOpen );
  LuaEvents.Tutorial_ContextDisableItems.Add( OnTutorial_ContextDisableItems );
  LuaEvents.CityPanel_SetOverViewState.Add(function(isOpened)
    Controls.ToggleOverviewPanel:SetCheck(isOpened);
  end);
  LuaEvents.CityPanel_ToggleManageCitizens.Add(function()
    Controls.ManageCitizensCheck:SetAndCall(not Controls.ManageCitizensCheck:IsChecked());
  end);

  -- CQUI Events
  LuaEvents.CQUI_GoNextCity.Add( CQUI_OnNextCity );
  LuaEvents.CQUI_GoPrevCity.Add( CQUI_OnPreviousCity );
  LuaEvents.CQUI_ToggleGrowthTile.Add( CQUI_ToggleGrowthTile );
  LuaEvents.CQUI_SettingsUpdate.Add( CQUI_SettingsUpdate );
  LuaEvents.RefreshCityPanel.Add(Refresh);
  LuaEvents.CQUI_RealHousingFromImprovementsCalculated.Add(CQUI_HousingFromImprovementsTableInsert);    -- CQUI get real housing from improvements values
  LuaEvents.CQUI_CityLostTileToCultureBomb.Add( Refresh );    -- CQUI update real housing from improvements when a city lost tile to a Culture Bomb
  LuaEvents.CQUI_IndiaPlayerResearchedSanitation.Add( Refresh );    -- CQUI update real housing from improvements when play as India and researched Sanitation
  LuaEvents.CQUI_IndonesiaPlayerResearchedMassProduction.Add( Refresh );    -- CQUI update real housing from improvements when play as Indonesia and researched Mass Production

  -- Truncate possible static text overflows
  TruncateStringWithTooltip(Controls.BreakdownLabel,  MAX_BEFORE_TRUNC_STATIC_LABELS, Controls.BreakdownLabel:GetText());
  TruncateStringWithTooltip(Controls.ReligionLabel, MAX_BEFORE_TRUNC_STATIC_LABELS, Controls.ReligionLabel:GetText());
  TruncateStringWithTooltip(Controls.AmenitiesLabel,  MAX_BEFORE_TRUNC_STATIC_LABELS, Controls.AmenitiesLabel:GetText());
  TruncateStringWithTooltip(Controls.HousingLabel,  MAX_BEFORE_TRUNC_STATIC_LABELS, Controls.HousingLabel:GetText());
end
Initialize();
