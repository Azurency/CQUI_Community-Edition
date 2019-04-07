-- ===========================================================================
--  City Banner Manager
-- ===========================================================================

include( "CivilizationIcon" );
include( "InstanceManager" );
include( "SupportFunctions" );
include( "LoyaltySupport" );
include( "Civ6Common" );
include( "Colors" );
include( "LuaClass" );
include( "CitySupport" );

-- ===========================================================================
--	GLOBALS
-- ===========================================================================
CityBanner = {};

BANNERTYPE_CITY_CENTER		= 0;
BANNERTYPE_ENCAMPMENT		= 1;
BANNERTYPE_AERODROME		= 2;
BANNERTYPE_MISSILE_SILO		= 3;
BANNERTYPE_OTHER_DISTRICT	= 4;
BANNERTYPE_MOUNTAIN_TUNNEL	= 5;
BANNERTYPE_QHAPAQ_NAN		= 6;

-- ===========================================================================
--  CONSTANTS
-- ===========================================================================

local ANIM_SPEED_RELIGION_CHANGE      :number = 1;
local COLOR_CITY_GREEN            :number = 0xFF4CE710;
local COLOR_CITY_RED            :number = 0xFF0101F5;
local COLOR_CITY_YELLOW           :number = 0xFF2DFFF8;
local COLOR_HOLY_SITE           :number = 0xFFFFFFFF;
local COLOR_NO_MAJOR_RELIGION       :number = 0x00000000;
local COLOR_RELIGION_DEFAULT        :number = 0x02000000;

-- LOYALTY
local PRESSURE_BREAKDOWN_TYPE_POPULATION_PRESSURE :string = "PopulationPressure";
local PRESSURE_BREAKDOWN_TYPE_GOVERNORS           :string = "Governors";
local PRESSURE_BREAKDOWN_TYPE_HAPPINESS           :string = "Happiness";
local PRESSURE_BREAKDOWN_TYPE_OTHER               :string = "Other";
local PRESSURE_BREAKDOWN_TYPE_CITY_STATE_BONUS    :string = "CityStateBonus";
local PRESSURE_BREAKDOWN_TYPE_FREE_CITY_BONUS     :string = "FreeCityBonus";

-- RELIGION
local DATA_FIELD_RELIGION_FOLLOWERS_IM      :string = "m_FollowersIM";
local DATA_FIELD_RELIGION_METERS_IM         :string = "m_MetersIM";
local DATA_FIELD_RELIGION_PRESSURE_CHANGES  :string = "m_PressureChanges";
local DATA_FIELD_RELIGION_PREV_FILL_PERCENT :string = "m_FillPercent";
local DATA_FIELD_RELIGION_ICONS_IM          :string = "m_IconsIM";
local DATA_FIELD_RELIGION_FOLLOWER_LIST_IM  :string = "m_FollowerListIM";
local DATA_FIELD_RELIGION_POP_CHART_IM      :string = "m_PopChartIM";
local DATA_FIELD_PRODUCTION_CLICK_CALLBACK  :string = "m_ProductionClickCallback";

local RELIGION_POP_CHART_TOOLTIP_HEADER		:string = Locale.Lookup("LOC_CITY_BANNER_FOLLOWER_PRESSURE_TOOLTIP_HEADER");

local ICON_HOLY_SITE      :string = "Faith";
local ICON_PRESSURE_DOWN    :string = "PressureDown";
local ICON_PRESSURE_UP      :string = "PressureUp";
local MINIMUM_BANNER_WIDTH    :number = 186;
local PLOT_HIDDEN       :number = 0;
local PLOT_REVEALED       :number = 1;
local PLOT_VISIBLE        :number = 2;
local PRESSURE_THRESHOLD_HIGH :number = 400;
local PRESSURE_THRESHOLD_MEDIUM :number = 200;
local PADDING_FOLLOWERS_BG    :number = 0;
local RELIGION_PRESSURE     :table = {
  NONE  = 0,
  LOW   = 1,
  MEDIUM  = 2,
  HIGH  = 3
};
local SIZE_HOLY_SITE_ICON   :number = 22;
local SIZE_RELIGION_ICON_LARGE  :number = 100;
local SIZE_RELIGION_ICON_SMALL  :number = 22;
local ALPHA_DIM         :number = 0.45;

local YOFFSET_2DVIEW           :number = 26;
local ZOFFSET_3DVIEW           :number = 36;
local SIZEOFPOPANDPROD         :number = 80;	--The amount to add to the city banner to account for the size of the production icon and population number
local SIZEOFPOPANDPRODMETERS   :number = 15;	--The amount to add to the city banner backing width to allow for the production and population meters to appear

local BANNERSTYLE_LOCAL_TEAM    :number = 0;
local BANNERSTYLE_OTHER_TEAM    :number = 1;

local m_pDirtyCityComponents    :table = {};
local m_preligionInfoance       :table = nil; -- tracks the most recently opened religion detail panel
local m_isReligionLensActive    :boolean = false;
local m_isLoyaltyLensActive     :boolean = false;
local m_isTradeSelectionActive  :boolean = false;

local m_refreshLocalPlayerRangeStrike:boolean = false;
local m_refreshLocalPlayerProduction:boolean = false;

-- ===========================================================================
--  MEMBERS
-- ===========================================================================
local CityBannerInstances  :table = {};
local MiniBannerInstances  :table = {};

local m_CityBannerIM        :table = InstanceManager:new( "CityBanner",       "Anchor", Controls.CityBanners );
local m_AerodromeBannerIM   :table = InstanceManager:new( "AerodromeBanner",  "Anchor", Controls.CityBanners );
local m_WMDBannerIM         :table = InstanceManager:new( "WMDBanner",        "Anchor", Controls.CityBanners );
local m_EncampmentBannerIM  :table = InstanceManager:new( "EncampmentBanner", "Anchor", Controls.CityBanners );
local m_DistrictBannerIM    :table = InstanceManager:new( "DistrictBanner",   "Anchor", Controls.CityBanners );
local m_TunnelBannerIM      :table = InstanceManager:new( "TunnelBanner",     "Anchor", Controls.CityBanners );
local m_QhapaqNanBannerIM   :table = InstanceManager:new( "QhapaqNanBanner",  "Anchor", Controls.CityBanners );
local m_HolySiteIconsIM     :table = InstanceManager:new( "HolySiteIcon",     "Anchor", Controls.CityDistrictIcons );

local m_HexColoringReligion : number = UILens.CreateLensLayerHash("Hex_Coloring_Religion");
local m_LoyaltyFreeCityWarning : number = UILens.CreateLensLayerHash("Loyalty_FreeCity_Warning");
local m_CulturalIdentityLens : number = UILens.CreateLensLayerHash("Cultural_Identity_Lens");
local m_CityDetailsLens : number = UILens.CreateLensLayerHash("City_Details");
local m_EmpireDetailsLens : number = UILens.CreateLensLayerHash("Empire_Details");

-- ===========================================================================
--  CQUI
-- ===========================================================================

-- CQUI real housing from improvements tables
local CQUI_HousingFromImprovementsTable :table = {};
local CQUI_HousingUpdated :table = {};

-- CQUI taken from PlotInfo
local CQUI_ShowYieldsOnCityHover = false;
local CQUI_PlotIM        :table = InstanceManager:new( "CQUI_WorkedPlotInstance", "Anchor", Controls.CQUI_WorkedPlotContainer );
local CQUI_uiWorldMap    :table = {};
local CQUI_yieldsOn    :boolean = false;
local CQUI_Hovering :boolean = false;
local CQUI_NextPlot4Away :number = nil;

local CQUI_ShowCitizenIconsOnCityHover:boolean = false;
local CQUI_ShowCityManageAreaOnCityHover:boolean = true;
local CQUI_CityManageAreaShown:boolean = false;
local CQUI_CityManageAreaShouldShow:boolean = false;

local CQUI_WorkIconSize: number = 48;
local CQUI_WorkIconAlpha = .60;
local CQUI_SmartWorkIcon: boolean = true;
local CQUI_SmartWorkIconSize: number = 64;
local CQUI_SmartWorkIconAlpha = .45;
local g_smartbanner = true;

function CQUI_OnSettingsInitialized()
  CQUI_ShowYieldsOnCityHover = GameConfiguration.GetValue("CQUI_ShowYieldsOnCityHover");
  g_smartbanner = GameConfiguration.GetValue("CQUI_Smartbanner");
  g_smartbanner_unmanaged_citizen = GameConfiguration.GetValue("CQUI_Smartbanner_UnlockedCitizen");
  g_smartbanner_districts = GameConfiguration.GetValue("CQUI_Smartbanner_Districts");
  g_smartbanner_population = GameConfiguration.GetValue("CQUI_Smartbanner_Population");

  CQUI_WorkIconSize = GameConfiguration.GetValue("CQUI_WorkIconSize");
  CQUI_WorkIconAlpha = GameConfiguration.GetValue("CQUI_WorkIconAlpha") / 100;
  CQUI_SmartWorkIcon = GameConfiguration.GetValue("CQUI_SmartWorkIcon");
  CQUI_SmartWorkIconSize = GameConfiguration.GetValue("CQUI_SmartWorkIconSize");
  CQUI_SmartWorkIconAlpha = GameConfiguration.GetValue("CQUI_SmartWorkIconAlpha") / 100;

  CQUI_ShowCitizenIconsOnCityHover = GameConfiguration.GetValue("CQUI_ShowCitizenIconsOnCityHover");
  CQUI_ShowCityManageAreaOnCityHover = GameConfiguration.GetValue("CQUI_ShowCityManageAreaOnCityHover");
  CQUI_ShowCityManageAreaInScreen = GameConfiguration.GetValue("CQUI_ShowCityMangeAreaInScreen")
end

function CQUI_OnSettingsUpdate()
  CQUI_OnSettingsInitialized();
  Reload();
end
LuaEvents.CQUI_SettingsUpdate.Add( CQUI_OnSettingsUpdate );

-- ===========================================================================
--  FUNCTIONS
-- ===========================================================================

-- ===========================================================================
--  Each city has a component ID that is internally 64-bits.
--  The cityID is the lower 32-bits and will likely be the same across players
--  so both the playerID and cityID need to be used together in order to
--  obtain the proper city.
-- ===========================================================================
function GetCityBanner( playerID:number, cityID:number )
  if (CityBannerInstances[playerID] == nil) then
    return;
  end
  return CityBannerInstances[playerID][cityID];
end
-- ===========================================================================
function GetMiniBanner( playerID:number, districtID:number )
  if (MiniBannerInstances[playerID] == nil) then
    return;
  end
  return MiniBannerInstances[playerID][districtID];
end

-- ===========================================================================
-- constructor
-- ===========================================================================
function CityBanner:new( playerID: number, cityID : number, districtID : number, bannerType : number, bannerStyle : number )
  self = LuaClass.new(CityBanner);
  
  self.m_eMajorityReligion = -1; -- << Assign default values
  self.m_eLoyaltyWarningPlayer = -1; -- which player the city might flip to within 20 turns

  if bannerStyle == nil then UI.DataError("Missing bannerStyle: "..tostring(playerID)..", "..tostring(cityID)..", "..tostring(districtID)..", "..tostring(bannerType) ); end

  self:Initialize(playerID, cityID, districtID, bannerType, bannerStyle);

  if (bannerType == BANNERTYPE_CITY_CENTER) then
    if (CityBannerInstances[playerID] == nil) then
      CityBannerInstances[playerID] = {};
    end
    CityBannerInstances[playerID][cityID] = self;
  else
    if (MiniBannerInstances[playerID] == nil) then
      MiniBannerInstances[playerID] = {};
    end
    MiniBannerInstances[playerID][districtID] = self;
  end

  return self;
end

-- ===========================================================================
function CityBanner:destroy()
  if self.m_DetailStatusIM then
    self.m_DetailStatusIM:DestroyInstances();
  end
  if self.m_DetailEffectsIM then
    self.m_DetailEffectsIM:DestroyInstances();
  end
  if self.m_InfoIconIM then
    self.m_InfoIconIM:DestroyInstances();
  end
  if self.m_InfoConditionIM then
    self.m_InfoConditionIM:DestroyInstances();
  end
  if self.m_StatGovernorIM then
    self.m_StatGovernorIM:DestroyInstances();
  end
  if self.m_StatPopulationIM then
    self.m_StatPopulationIM:DestroyInstances();
  end
  if self.m_StatProductionIM then
    self.m_StatProductionIM:DestroyInstances();
  end
  if self.m_LoyaltyBreakdownIM then
    self.m_LoyaltyBreakdownIM:DestroyInstances();
  end
  if self.m_eLoyaltyWarningPlayer ~= -1 then
    local plot = Map.GetPlotIndex(self.m_PlotX, self.m_PlotY);
    UILens.ClearHex( m_LoyaltyFreeCityWarning, plot);
  end

  -- CQUI : Clear CQUI_DistrictBuiltIM
  if self.CQUI_DistrictBuiltIM then
    self.CQUI_DistrictBuiltIM:DestroyInstances();
  end
  
  if self.m_InstanceManager then
    self:UpdateSelected( false );
    if self.m_Instance then
      self.m_InstanceManager:ReleaseInstance( self.m_Instance );
    end
  end
end

-- ===========================================================================
-- CQUI -- When a banner is moused over, display the relevant yields and next culture plot
function CQUI_OnBannerMouseOver(playerID: number, cityID: number)

  if(CQUI_ShowYieldsOnCityHover) then

    CQUI_Hovering = true;

    -- Astog: Fix for lens being shown when other lenses are on.
    -- Astog: Don't show this lens if any unit is selected.
    -- This prevents the need to check if every lens is on or not, like builder, religious lens.
    if CQUI_ShowCityManageAreaOnCityHover and not UILens.IsLayerOn(LensLayers.CITIZEN_MANAGEMENT)
        and UI.GetInterfaceMode() == InterfaceModeTypes.SELECTION
        and UI.GetHeadSelectedUnit() == nil then
      LuaEvents.CQUI_ShowCitizenManagement(cityID);
      CQUI_CityManageAreaShown = true;
    end

    local kPlayer = Players[playerID];
    local kCities = kPlayer:GetCities();
    local kCity = kCities:FindID(cityID);

    local tParameters :table = {};
    tParameters[CityCommandTypes.PARAM_MANAGE_CITIZEN] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_MANAGE_CITIZEN);
    tParameters[CityCommandTypes.PARAM_PLOT_PURCHASE] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_PLOT_PURCHASE);

    local tResults  :table = CityManager.GetCommandTargets( kCity, CityCommandTypes.MANAGE, tParameters );

    if tResults == nil then
      -- Add error message here
      return;
    end

    local tPlots    :table = tResults[CityCommandResults.PLOTS];
    local tUnits    :table = tResults[CityCommandResults.CITIZENS];
    local tMaxUnits   :table = tResults[CityCommandResults.MAX_CITIZENS];
    local tLockedUnits  :table = tResults[CityCommandResults.LOCKED_CITIZENS];

    local pCityCulture          :table  = kCity:GetCulture();
    local pNextPlotID           :number = pCityCulture:GetNextPlot();
    local TurnsUntilExpansion   :number = pCityCulture:GetTurnsUntilExpansion();

    local yields :table = {};
    local yieldsIndex :table = {};

    if (tPlots ~= nil and table.count(tPlots) ~= 0) and UILens.IsLayerOn(LensLayers.CITIZEN_MANAGEMENT) == false then

      CQUI_yieldsOn = UserConfiguration.ShowMapYield();

      for i,plotId in pairs(tPlots) do
        local kPlot :table = Map.GetPlotByIndex(plotId);
        local workerCount = kPlot:GetWorkerCount();
        local index:number = kPlot:GetIndex();
        local pInstance :table =  CQUI_GetInstanceAt(index);
        local numUnits:number = tUnits[i];
        local maxUnits:number = tMaxUnits[i];

        if CQUI_ShowCitizenIconsOnCityHover then
          -- If this plot is getting worked
          if workerCount > 0 and kPlot:IsCity() == false then
            pInstance.CitizenButton:SetHide(false);
            pInstance.CitizenButton:SetTextureOffsetVal(0, 256);
            if(CQUI_SmartWorkIcon) then
              pInstance.CitizenButton:SetSizeVal(CQUI_SmartWorkIconSize, CQUI_SmartWorkIconSize);
              pInstance.CitizenButton:SetAlpha(CQUI_SmartWorkIconAlpha);
            else
              pInstance.CitizenButton:SetSizeVal(CQUI_WorkIconSize, CQUI_WorkIconSize);
              pInstance.CitizenButton:SetAlpha(CQUI_WorkIconAlpha);
            end
          end

          if(tLockedUnits[i] > 0) then
            pInstance.LockedIcon:SetHide(false);
            if(CQUI_SmartWorkIcon) then
              pInstance.LockedIcon:SetAlpha(CQUI_SmartWorkIconAlpha);
            else
              pInstance.LockedIcon:SetAlpha(CQUI_WorkIconAlpha);
            end
          else
            pInstance.LockedIcon:SetHide(true);
          end
        end

        table.insert(yields, plotId);
        yieldsIndex[index] = plotId;

      end

    end

    tResults  = CityManager.GetCommandTargets( kCity, CityCommandTypes.PURCHASE, tParameters );
    if tResults == nil then
      return;
    end

    tPlots    = tResults[CityCommandResults.PLOTS];

    if (tPlots ~= nil and table.count(tPlots) ~= 0) and UILens.IsLayerOn(LensLayers.CITIZEN_MANAGEMENT) == false then

      for i,plotId in pairs(tPlots) do
        local kPlot :table = Map.GetPlotByIndex(plotId);
        local index:number = kPlot:GetIndex();
        local pInstance :table =  CQUI_GetInstanceAt(index);

        if (index == pNextPlotID ) then
          pInstance.CQUI_NextPlotLabel:SetString("[ICON_Turn]" .. Locale.Lookup("LOC_HUD_CITY_IN_TURNS" , TurnsUntilExpansion ) .. "   ");
          pInstance.CQUI_NextPlotButton:SetHide( false );
        end

        table.insert(yields, plotId);
        yieldsIndex[index] = plotId;

      end

      local plotCount = Map.GetPlotCount();

      if (CQUI_yieldsOn == false and not UILens.IsLayerOn(LensLayers.CITIZEN_MANAGEMENT)) then
        UILens.SetLayerHexesArea(LensLayers.CITY_YIELDS, Game.GetLocalPlayer(), yields);
        UILens.ToggleLayerOn( LensLayers.CITY_YIELDS );
      end
    elseif UILens.IsLayerOn(LensLayers.CITIZEN_MANAGEMENT) == false then
      local pInstance :table = CQUI_GetInstanceAt(pNextPlotID);
      if (pInstance ~= nil) then
        pInstance.CQUI_NextPlotLabel:SetString("[ICON_Turn]" .. Locale.Lookup("LOC_HUD_CITY_IN_TURNS" , TurnsUntilExpansion ) .. "   ");
        pInstance.CQUI_NextPlotButton:SetHide( false );
        CQUI_NextPlot4Away = pNextPlotID;
      end
    end
  end
end

-- ===========================================================================
-- CQUI -- When a banner is moused over, and the mouse leaves the banner, remove display of the relevant yields and next culture plot
function CQUI_OnBannerMouseExit(playerID: number, cityID: number)

  if(not CQUI_Hovering) then return; end

  CQUI_yieldsOn = UserConfiguration.ShowMapYield();

  if (CQUI_yieldsOn == false and not UILens.IsLayerOn(LensLayers.CITIZEN_MANAGEMENT)) then
    UILens.ClearLayerHexes( LensLayers.CITY_YIELDS );
  end

  local kPlayer = Players[playerID];
  local kCities = kPlayer:GetCities();
  local kCity = kCities:FindID(cityID);

  local tParameters :table = {};
  tParameters[CityCommandTypes.PARAM_MANAGE_CITIZEN] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_MANAGE_CITIZEN);
  tParameters[CityCommandTypes.PARAM_PLOT_PURCHASE] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_PLOT_PURCHASE);

  local tResults  :table = CityManager.GetCommandTargets( kCity, CityCommandTypes.MANAGE, tParameters );

  if tResults == nil then
    -- Add error message here
    return;
  end

  -- Astog: Fix for lens being cleared when having other lenses on
  if CQUI_ShowCityManageAreaOnCityHover and UI.GetInterfaceMode() ~= InterfaceModeTypes.CITY_MANAGEMENT
      and CQUI_CityManageAreaShown then
    LuaEvents.CQUI_ClearCitizenManagement();
    CQUI_CityManageAreaShown = false;
  end

  local tPlots    :table = tResults[CityCommandResults.PLOTS];

  if (tPlots ~= nil and table.count(tPlots) ~= 0) then

    for i,plotId in pairs(tPlots) do
      local kPlot :table = Map.GetPlotByIndex(plotId);
      local index:number = kPlot:GetIndex();
      pInstance = CQUI_ReleaseInstanceAt(index);
    end

  end

  tResults  = CityManager.GetCommandTargets( kCity, CityCommandTypes.PURCHASE, tParameters );
  tPlots    = tResults[CityCommandResults.PLOTS];

  if (tPlots ~= nil and table.count(tPlots) ~= 0) then

    for i,plotId in pairs(tPlots) do
      local kPlot :table = Map.GetPlotByIndex(plotId);
      local index:number = kPlot:GetIndex();
      pInstance = CQUI_ReleaseInstanceAt(index);
    end

  end

  if (CQUI_NextPlot4Away ~= nil) then
    pInstance = CQUI_ReleaseInstanceAt(CQUI_NextPlot4Away);
    CQUI_NextPlot4Away = nil;
  end

end

-- CQUI taken from PlotInfo
-- ===========================================================================
--  Obtain an existing instance of plot info or allocate one if it doesn't
--  already exist.
--  plotIndex Game engine index of the plot
-- ===========================================================================
function CQUI_GetInstanceAt( plotIndex:number )
  local pInstance:table = CQUI_uiWorldMap[plotIndex];
  if pInstance == nil then
    pInstance = CQUI_PlotIM:GetInstance();
    CQUI_uiWorldMap[plotIndex] = pInstance;
    local worldX:number, worldY:number = UI.GridToWorld( plotIndex );
    pInstance.Anchor:SetWorldPositionVal( worldX, worldY, 20 );
    -- Make it so that the button can't be clicked while it's in this temporary state, this stops it from blocking clicks intended for the citybanner
    pInstance.CitizenButton:SetConsumeMouseButton(false);
    pInstance.Anchor:SetHide( false );
  end
  return pInstance;
end

-- ===========================================================================
function CQUI_ReleaseInstanceAt( plotIndex:number)
  local pInstance :table = CQUI_uiWorldMap[plotIndex];
  if pInstance ~= nil then
    pInstance.Anchor:SetHide( true );
    -- Return the button to normal so that it can be clicked again
    pInstance.CitizenButton:SetConsumeMouseButton(true);
    -- m_AdjacentPlotIconIM:ReleaseInstance( pInstance );
    CQUI_uiWorldMap[plotIndex] = nil;
  end
end

-- ===========================================================================
function CityBanner:Initialize( playerID: number, cityID : number, districtID : number, bannerType : number, bannerStyle : number)

  self.m_Player = Players[playerID];
  self.m_DistrictID = districtID;
  self.m_CityID = cityID;

  self.m_Type = bannerType;
  self.m_Style = bannerStyle;
  self.m_IsSelected = false;
  self.m_IsCurrentlyVisible = false;
  self.m_IsForceHide = false;
  self.m_IsDimmed = false;
  self.m_OverrideDim = false;
  self.m_FogState = 0;
  self.m_UnitListEnabled = false;

  if (bannerType == BANNERTYPE_CITY_CENTER) then
    local pCity = self:GetCity();
    if pCity ~= nil then
      self.m_PlotX = pCity:GetX();
      self.m_PlotY = pCity:GetY();
    end

    -- Instantiate the banner
    self.m_InstanceManager = m_CityBannerIM;
    self.m_Instance = self.m_InstanceManager:GetInstance();

    -- Only create instance managers once, otherwise we can leak instances
    if self.m_DetailStatusIM == nil then
      self.m_DetailStatusIM = InstanceManager:new( "CityDetailStatus", "Icon", self.m_Instance.CityDetailsStatus );
    end
    if self.m_DetailEffectsIM == nil then
      self.m_DetailEffectsIM = InstanceManager:new( "CityDetailEffect", "Button", self.m_Instance.CityDetailsEffects );
    end
    if self.m_InfoIconIM == nil then
      self.m_InfoIconIM = InstanceManager:new( "CityInfoType", "Button", self.m_Instance.CityInfoStack );
    end
    if self.m_InfoConditionIM == nil then
      self.m_InfoConditionIM = InstanceManager:new( "CityInfoCondition", "Button", self.m_Instance.CityInfoStack );
    end
    if self.m_StatGovernorIM == nil then
      self.m_StatGovernorIM = InstanceManager:new( "CityStatGovernor", "Button", self.m_Instance.CityStatusStack );
    end
    if self.m_StatProductionIM == nil then
      self.m_StatProductionIM = InstanceManager:new( "CityStatProduction", "Button", self.m_Instance.CityStatusStack );
    end

    -- CQUI : Create instance manager once for district built
    if self.CQUI_DistrictBuiltIM == nil then
      self.CQUI_DistrictBuiltIM = InstanceManager:new( "CQUI_DistrictBuilt", "Icon", self.m_Instance.CQUI_Districts );
    end
    
    -- If instance managers need to be re-created, you can clean up instances manually
    if self.m_StatPopulationIM then
      self.m_StatPopulationIM:DestroyInstances();
      self.m_StatPopulationIM = nil;
    end

    self.m_Instance.CityBannerButton:RegisterCallback( Mouse.eLClick, OnCityBannerClick );
    self.m_Instance.CityBannerButton:SetVoid1(playerID);
    self.m_Instance.CityBannerButton:SetVoid2(cityID);

    if (bannerStyle == BANNERSTYLE_LOCAL_TEAM and playerID == Game.GetLocalPlayer()) then
      self.m_StatPopulationIM = InstanceManager:new( "CityStatPopulation", "Button", self.m_Instance.CityStatusStack );
      self.m_Instance.CityStrikeButton:RegisterCallback( Mouse.eLClick, OnCityStrikeButtonClick );
      self.m_Instance.CityStrikeButton:SetVoid1(playerID);
      self.m_Instance.CityStrikeButton:SetVoid2(cityID);
      self.m_Instance.CityBannerButton:RegisterCallback( Mouse.eMouseEnter, CQUI_OnBannerMouseOver );
      self.m_Instance.CityBannerButton:RegisterCallback( Mouse.eMouseExit, CQUI_OnBannerMouseExit );
    end

    -- If we're not local player, show limited population info
    if self.m_StatPopulationIM == nil then
      self.m_StatPopulationIM	= InstanceManager:new( "CityStatPopulationLimited", "BG", self.m_Instance.CityStatusStack );
    end

    self:UpdateReligion();

    local loyaltyInfo:table = self.m_Instance.LoyaltyInfo;
    local toggleLoyalty = function(on)
      return function()
        loyaltyInfo.CulturalIdentityButton:SetHide(on);
        loyaltyInfo.CulturalIdentityExpandedButton:SetHide(not on);
      end
    end
    loyaltyInfo.CulturalIdentityButton:RegisterCallback( Mouse.eLClick, toggleLoyalty(true) );
    loyaltyInfo.CulturalIdentityExpandedButton:RegisterCallback( Mouse.eLClick, toggleLoyalty(false) );

    if self.m_LoyaltyBreakdownIM == nil then
      self.m_LoyaltyBreakdownIM = InstanceManager:new("InfluenceLineInstance","Top", self.m_Instance.LoyaltyInfo.IdentityBreakdownStack);
    end

    self:UpdateLoyalty();
  elseif (bannerType == BANNERTYPE_AERODROME) then
    self:CreateAerodromeBanner();
    self:UpdateAerodromeBanner();
  elseif (bannerType == BANNERTYPE_MISSILE_SILO) then
    self:CreateWMDBanner();
    self:UpdateWMDBanner();
  elseif (bannerType == BANNERTYPE_ENCAMPMENT) then
    self:CreateEncampmentBanner();
    self:UpdateEncampmentBanner();
  elseif (bannerType == BANNERTYPE_OTHER_DISTRICT) then
    self:CreateDistrictBanner();
    self:UpdateDistrictBanner();
  elseif (bannerType == BANNERTYPE_MOUNTAIN_TUNNEL) then
    self:CreateTunnelBanner();
  elseif (bannerType == BANNERTYPE_QHAPAQ_NAN) then
    self:CreateQhapaqNanBanner();
  end

  self:UpdateName();
  self:UpdateStats();
  self:UpdatePosition();
  self:UpdateVisibility();
  self:UpdateRangeStrike();
  self:UpdateColor();
end

--- ===========================================================================
function CityBanner:CreateAerodromeBanner()
  -- Set the appropriate instance factory (mini banner one) for this flag...
  self.m_InstanceManager = m_AerodromeBannerIM;
  self.m_Instance = self.m_InstanceManager:GetInstance();

  self.m_IsImprovementBanner = false;

  local pDistrict = self:GetDistrict();
  if (pDistrict ~= nil) then
    self.m_PlotX = pDistrict:GetX();
    self.m_PlotY = pDistrict:GetY();
  else	-- it's an banner not associated with a district, so the districtID should be a plot index
    self.m_PlotX, self.m_PlotY = Map.GetPlotLocation(self.m_DistrictID);
    self.m_IsImprovementBanner = true;
  end
end

-- ===========================================================================
function CityBanner:UpdateAerodromeBanner()
  self.m_Instance.UnitListPopup:ClearEntries();

  local iAirCapacity = 0;
  local iAirUnitCount = 0;

  local pDistrict : table = self:GetDistrict();
  if (pDistrict ~= nil) then
    -- Update minibanner for aerodrome
    iAirCapacity = pDistrict:GetAirSlots();
    local bHasAirUnits, tAirUnits = pDistrict:GetAirUnits();
    if (bHasAirUnits and tAirUnits ~= nil) then
      -- Update unit instances in unit list
      for i,unit in ipairs(tAirUnits) do
        local unitEntry:table = {};
        self.m_Instance.UnitListPopup:BuildEntry( "UnitListEntry", unitEntry );

        -- Update name
        unitEntry.UnitName:SetText( Locale.ToUpper( unit:GetName() ) );

        -- Update icon
        local iconInfo:table = GetUnitIcon(unit, 22);
        if iconInfo.textureSheet then
          unitEntry.UnitTypeIcon:SetTexture( iconInfo.textureOffsetX, iconInfo.textureOffsetY, iconInfo.textureSheet );
        end

        -- Update callback
        unitEntry.Button:RegisterCallback( Mouse.eLClick, OnUnitSelected );
        unitEntry.Button:SetVoid1(playerID);
        unitEntry.Button:SetVoid2(unit:GetID());

        -- Increment count
        iAirUnitCount = iAirUnitCount + 1;

        -- Fade out the button icon and text if the unit is not able to move
        if unit:IsReadyToMove() then
          unitEntry.UnitName:SetAlpha(1.0);
          unitEntry.UnitTypeIcon:SetAlpha(1.0);
        else
          unitEntry.UnitName:SetAlpha(ALPHA_DIM);
          unitEntry.UnitTypeIcon:SetAlpha(ALPHA_DIM);
        end
      end
    end
  else
    -- Update minibanner for airstrip
    local airstripPlot = Map.GetPlotByIndex(self.m_DistrictID);
    local tAirUnits = airstripPlot:GetAirUnits();
    if tAirUnits then
      local eImprovement = airstripPlot:GetImprovementType();
      if (eImprovement ~= -1) then
        iAirCapacity = GameInfo.Improvements[eImprovement].AirSlots;
      end

      -- Update unit instances in unit list
      for i,unit in ipairs(tAirUnits) do
        local unitEntry:table = {};
        self.m_Instance.UnitListPopup:BuildEntry( "UnitListEntry", unitEntry );

        -- Update name
        unitEntry.UnitName:SetText( Locale.ToUpper(unit:GetName()) );

        -- Update icon
        local iconInfo:table = GetUnitIcon(unit, 22, true);
        if iconInfo.textureSheet then
          unitEntry.UnitTypeIcon:SetTexture( iconInfo.textureOffsetX, iconInfo.textureOffsetY, iconInfo.textureSheet );
        end

        -- Update callback
        unitEntry.Button:RegisterCallback( Mouse.eLClick, OnUnitSelected );
        unitEntry.Button:SetVoid1(playerID);
        unitEntry.Button:SetVoid2(unit:GetID());

        -- Increment count
        iAirUnitCount = iAirUnitCount + 1;

        -- Fade out the button icon and text if the unit is not able to move
        if unit:IsReadyToMove() then
          unitEntry.UnitName:SetAlpha(1.0);
          unitEntry.UnitTypeIcon:SetAlpha(1.0);
        else
          unitEntry.UnitName:SetAlpha(ALPHA_DIM);
          unitEntry.UnitTypeIcon:SetAlpha(ALPHA_DIM);
        end
      end
    end
  end

  -- Update current and max air unit capacity
  self.m_Instance.AerodromeCurrentUnitCount:SetText(iAirUnitCount);
  self.m_Instance.AerodromeMaxUnitCount:SetText(iAirCapacity);

  -- Update tooltip to show unit capacity
  self.m_Instance.AerodromeBase:SetToolTipString(Locale.Lookup("LOC_CITY_BANNER_AERODROME_AIRCRAFT_STATIONED", iAirUnitCount, iAirCapacity));

  -- If current air unit count is 0 then disabled popup
  if iAirUnitCount <= 0 then
    self.m_UnitListEnabled = false;
  else
    self.m_UnitListEnabled = true;
  end

  self:SetFogState( self.m_FogState );

  self.m_Instance.UnitListPopup:CalculateInternals();

  -- Adjust the scroll panel offset so stack is centered whether scrollbar is visible or not
  local scrollPanel = self.m_Instance.UnitListPopup:GetScrollPanel();
  if scrollPanel then
    if scrollPanel:GetScrollBar():IsHidden() then
      scrollPanel:SetOffsetX(0);
    else
      scrollPanel:SetOffsetX(7);
    end
  end

  self.m_Instance.UnitListPopup:ReprocessAnchoring();
  self.m_Instance.UnitListPopup:GetGrid():ReprocessAnchoring();
end

-- ===========================================================================
function CityBanner:CreateWMDBanner()
  -- Set the appropriate instance factory (mini banner one) for this flag...
  self.m_InstanceManager = m_WMDBannerIM;
  self.m_Instance = self.m_InstanceManager:GetInstance();

  self.m_IsImprovementBanner = false;

  local pDistrict = self:GetDistrict();
  if (pDistrict ~= nil) then
    self.m_PlotX = pDistrict:GetX();
    self.m_PlotY = pDistrict:GetY();
  else  -- it's an banner not associated with a district, so the districtID should be a plot index
    self.m_PlotX, self.m_PlotY = Map.GetPlotLocation(self.m_DistrictID);
    self.m_IsImprovementBanner = true;
  end

  -- Setup button callbacks
  local plotID = Map.GetPlotIndex(self.m_PlotX, self.m_PlotY);
  local eNuclearDevice = GameInfo.WMDs["WMD_NUCLEAR_DEVICE"].Index;
  self.m_Instance.NukeBombButton:RegisterCallback( Mouse.eLClick, OnICBMStrikeButtonClick );
  self.m_Instance.NukeBombButton:SetVoid1(plotID);
  self.m_Instance.NukeBombButton:SetVoid2(eNuclearDevice);

  local eThermonuclearDevice = GameInfo.WMDs["WMD_THERMONUCLEAR_DEVICE"].Index;
  self.m_Instance.ThermoNukeBombButton:RegisterCallback( Mouse.eLClick, OnICBMStrikeButtonClick );
  self.m_Instance.ThermoNukeBombButton:SetVoid1(plotID);
  self.m_Instance.ThermoNukeBombButton:SetVoid2(eThermonuclearDevice);
end

-- ===========================================================================
function CityBanner:UpdateWMDBanner()

  local pCity:table = self:GetCity();

  -- Don't show the mini banner if this silo doesn't belong to the local player
  if pCity ~= nil and pCity:GetOwner() ~= Game.GetLocalPlayer() then
    self.m_Instance.WMDBannerContainer:SetHide(true);
    return;
  end
  self.m_Instance.WMDBannerContainer:SetHide(false);

  local playerWMDs = self.m_Player:GetWMDs();

  for entry in GameInfo.WMDs() do
    if (entry.WeaponType == "WMD_NUCLEAR_DEVICE") then
      local count = playerWMDs:GetWeaponCount(entry.Index);
      if (count > 0) then
        -- Player has nukes
        self.m_Instance.NukeCountLabel:SetText(count);
        self.m_Instance.NukeBombButtonBackground:SetHide(false);

        -- Check if we're able to fire
        local bSiloCanFire:boolean = false;
        if( pCity ~= nil ) then
          local tParameters = {};
          tParameters[CityCommandTypes.PARAM_WMD_TYPE] = entry.Index;
          tParameters[CityCommandTypes.PARAM_X0] = self.m_PlotX;
          tParameters[CityCommandTypes.PARAM_Y0] = self.m_PlotY;
          local tResults = CityManager.GetCommandTargets(pCity, CityCommandTypes.WMD_STRIKE, tParameters);
          local allPlots = tResults[CityCommandResults.PLOTS];
          if (allPlots ~= nil) then
            bSiloCanFire = true;
          end
        end

        -- Update button state and tooltip
        if( bSiloCanFire) then
          self.m_Instance.NukeBombButton:SetDisabled(false);
          self.m_Instance.NukeBombButton:SetToolTipString(Locale.Lookup("LOC_CITY_BANNER_NUCLEAR_STRIKE_CAPABLE"));
        else
          self.m_Instance.NukeBombButton:SetDisabled(true);
          self.m_Instance.NukeBombButton:SetToolTipString(Locale.Lookup("LOC_CITY_BANNER_WEAPON_UNAVAILABLE"));
        end
      else
        -- Player does not have nukes
        self.m_Instance.NukeCountLabel:SetText("0");
        self.m_Instance.NukeBombButtonBackground:SetHide(true);
      end
    elseif (entry.WeaponType == "WMD_THERMONUCLEAR_DEVICE") then
      local count = playerWMDs:GetWeaponCount(entry.Index);
      if (count > 0) then
        -- Player has thermonuclear bombs
        self.m_Instance.ThermoNukeCountLabel:SetText(count);
        self.m_Instance.ThermoNukeBombButtonBackground:SetHide(false);

        -- Check if we're able to fire
        local bSiloCanFire:boolean = false;
        if( pCity ~= nil ) then
          local tParameters = {};
          tParameters[CityCommandTypes.PARAM_WMD_TYPE] = entry.Index;
          tParameters[CityCommandTypes.PARAM_X0] = self.m_PlotX;
          tParameters[CityCommandTypes.PARAM_Y0] = self.m_PlotY;
          local tResults = CityManager.GetCommandTargets(pCity, CityCommandTypes.WMD_STRIKE, tParameters);
          local allPlots = tResults[CityCommandResults.PLOTS];
          if (allPlots ~= nil) then
            bSiloCanFire = true;
          end
        end

        -- Update button state and tooltip
        if( bSiloCanFire) then
          self.m_Instance.ThermoNukeBombButton:SetDisabled(false);
          self.m_Instance.ThermoNukeBombButton:SetToolTipString(Locale.Lookup("LOC_CITY_BANNER_THERMONUCLEAR_STRIKE_CAPABLE"));
        else
          self.m_Instance.ThermoNukeBombButton:SetDisabled(true);
          self.m_Instance.ThermoNukeBombButton:SetToolTipString(Locale.Lookup("LOC_CITY_BANNER_WEAPON_UNAVAILABLE"));
        end
      else
        -- Player does not have thermonuclear bombs
        self.m_Instance.ThermoNukeCountLabel:SetText("0");
        self.m_Instance.ThermoNukeBombButtonBackground:SetHide(true);
      end
    end
  end
end

-- ===========================================================================
function CityBanner:CreateDistrictBanner()
  -- Set the appropriate instance factory (mini banner one) for this flag...
  self.m_InstanceManager = m_DistrictBannerIM;
  self.m_Instance = self.m_InstanceManager:GetInstance();

  self.m_IsImprovementBanner = false;
  self.m_IsForceHide = true;
end

-- ===========================================================================
function CityBanner:UpdateDistrictBanner()
  local pDistrict:table = self:GetDistrict();
  if (pDistrict ~= nil) then
    self.m_PlotX = pDistrict:GetX();
    self.m_PlotY = pDistrict:GetY();

    local pDistrictDef:table = GameInfo.Districts[pDistrict:GetType()];
    if pDistrictDef ~= nil then
      local districtTypeName:string = pDistrictDef.DistrictType;
      local iconName:string = "ICON_" .. districtTypeName;
      self.m_Instance.DistrictIcon:SetIcon(iconName);

      if districtTypeName == "DISTRICT_WONDER" then
        local eWonderType:number = Map.GetPlot(pDistrict:GetX(), pDistrict:GetY()):GetWonderType();
        if eWonderType and eWonderType ~= -1 then
          local pWonderDef:table = GameInfo.Buildings[eWonderType];
          if pWonderDef then
            local isWonderComplete:boolean = true;
            local kWonderPlot:table = Map.GetPlot(self.m_PlotX, self.m_PlotY);
            if kWonderPlot then
              isWonderComplete = kWonderPlot:IsWonderComplete();
            end
            self.m_Instance.UnderConstructionIcon:SetHide(isWonderComplete);

            local tooltip:string = Locale.Lookup(pWonderDef.Name); 
            if not isWonderComplete then
              tooltip = tooltip .. " " .. Locale.Lookup("LOC_TOOLTIP_PLOT_CONSTRUCTION_TEXT");
            end
            tooltip = tooltip .. "[NEWLINE]" .. Locale.Lookup(pWonderDef.Description);
            self.m_Instance.DistrictIcon:SetToolTipString(tooltip);
          end
        end
      else
        local isDistrictComplete:boolean = pDistrict:IsComplete();
        self.m_Instance.UnderConstructionIcon:SetHide(isDistrictComplete);

        local tooltip:string = Locale.Lookup(pDistrictDef.Name);
        if not isDistrictComplete then
          tooltip = tooltip .. " " .. Locale.Lookup("LOC_TOOLTIP_PLOT_CONSTRUCTION_TEXT");
        end
        tooltip = tooltip .. "[NEWLINE]" .. Locale.Lookup(pDistrictDef.Description);
        self.m_Instance.DistrictIcon:SetToolTipString(tooltip);
      end
    end
  end
end

-- ===========================================================================
function CityBanner:CreateTunnelBanner()
  -- Set the appropriate instance factory (mini banner one) for this flag...
  self.m_InstanceManager = m_TunnelBannerIM;
  self.m_Instance = self.m_InstanceManager:GetInstance();

  self.m_IsImprovementBanner = true;

  -- it's an banner not associated with a district, so the districtID should be a plot index
  self.m_PlotX, self.m_PlotY = Map.GetPlotLocation(self.m_DistrictID);
end

-- ===========================================================================
function CityBanner:CreateQhapaqNanBanner()
  -- Set the appropriate instance factory (mini banner one) for this flag...
  self.m_InstanceManager = m_QhapaqNanBannerIM;
  self.m_Instance = self.m_InstanceManager:GetInstance();

  self.m_IsImprovementBanner = true;

  -- it's an banner not associated with a district, so the districtID should be a plot index
  self.m_PlotX, self.m_PlotY = Map.GetPlotLocation(self.m_DistrictID);
end

-- ===========================================================================
function CityBanner:CreateEncampmentBanner()
  -- Set the appropriate instance factory (mini banner one) for this flag...
  self.m_InstanceManager = m_EncampmentBannerIM;
  self.m_Instance = self.m_InstanceManager:GetInstance();

  self.m_IsImprovementBanner = false;

  local pDistrict = self:GetDistrict();
  if (pDistrict ~= nil) then
    self.m_PlotX = pDistrict:GetX();
    self.m_PlotY = pDistrict:GetY();

    -- Update district strength
    local districtDefense:number = math.floor(pDistrict:GetDefenseStrength() + 0.5);
    self.m_Instance.DistrictDefenseStrengthLabel:SetText(districtDefense);

    -- Setup strike button callback
    self.m_Instance.CityStrikeButton:RegisterCallback( Mouse.eLClick, OnDistrictRangeStrikeButtonClick );
    self.m_Instance.CityStrikeButton:SetVoid1(self.m_Player:GetID());
    self.m_Instance.CityStrikeButton:SetVoid2(self.m_DistrictID);
  end
end

-- ===========================================================================
function CityBanner:UpdateEncampmentBanner()
  -- Update wall/district health
  local pDistrict:table = self:GetDistrict();

  local districtDefense       :number = math.floor(pDistrict:GetDefenseStrength() + 0.5);
  local districtHitpoints     :number = pDistrict:GetMaxDamage(DefenseTypes.DISTRICT_GARRISON);
  local currentDistrictDamage :number = pDistrict:GetDamage(DefenseTypes.DISTRICT_GARRISON);
  local wallHitpoints         :number = pDistrict:GetMaxDamage(DefenseTypes.DISTRICT_OUTER);
  local currentWallDamage     :number = pDistrict:GetDamage(DefenseTypes.DISTRICT_OUTER);
  local healthTooltip         :string = Locale.Lookup("LOC_CITY_BANNER_DISTRICT_HITPOINTS", ((districtHitpoints-currentDistrictDamage) .. "/" .. districtHitpoints));
  local defTooltip            :string = Locale.Lookup("LOC_CITY_BANNER_DISTRICT_DEFENSE_STRENGTH", districtDefense);

  if (wallHitpoints > 0) then
    self.m_Instance.CityDefenseBar:SetHide(false);
    healthTooltip = healthTooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_CITY_BANNER_OUTER_DEFENSE_HITPOINTS", ((wallHitpoints-currentWallDamage) .. "/" .. wallHitpoints));
    self.m_Instance.CityDefenseBar:SetPercent((wallHitpoints-currentWallDamage) / wallHitpoints);
    self:SetHealthBarColor();
  else
    self.m_Instance.CityDefenseBar:SetHide(true);
  end

  if districtHitpoints < 0 or (((districtHitpoints-currentDistrictDamage) / districtHitpoints) == 1 and wallHitpoints == 0) then
    self.m_Instance.CityHealthBar:SetHide(true);
  else
    self.m_Instance.CityHealthBar:SetHide(false);
    self.m_Instance.CityHealthBar:SetPercent((districtHitpoints-currentDistrictDamage) / districtHitpoints);
  end

  self.m_Instance.EncampmentBannerContainer:SetToolTipString(healthTooltip);
  self.m_Instance.DistrictDefenseGrid:SetToolTipString(defTooltip);
end

-- ===========================================================================
function OnUnitSelected( playerID:number, unitID:number )
  if Game.GetLocalPlayer() >= 0 then
    local playerUnits:table = Players[Game.GetLocalPlayer()]:GetUnits();
    if playerUnits then
      local selectedUnit:table = playerUnits:FindID(unitID);
      if selectedUnit then
        UI.SelectUnit( selectedUnit );
      end
    end
  end
end

-- ===========================================================================
function CityBanner:IsVisible()
  if Game.GetLocalPlayer() >= 0 then
    local pLocalPlayerVis:table = PlayersVisibility[Game.GetLocalPlayer()];
    local city:table = self:GetCity();
    local locX:number = city:GetX();
    local locY:number = city:GetY();
    if pLocalPlayerVis:IsVisible(locX, locY) then
      return true;
    elseif pLocalPlayerVis:IsRevealed(locX, locY) then
      return true;
    end
  end
  return false;
end

function CityBanner:IsTeam()
  return self.m_Style == BANNERSTYLE_LOCAL_TEAM;
end

-- ===========================================================================
-- Resize and recenter city banner images to accomodate the city name
function CityBanner:Resize()
  if (self.m_Type == BANNERTYPE_CITY_CENTER) then
    local pCity : table = self:GetCity();
    if (pCity ~= nil) then
      self.m_Instance.CityInfoStack:CalculateSize();
      self.m_Instance.CityStatusStack:CalculateSize();
      local nameContainerSize = self.m_Instance.CityName:GetSizeX();

      self.m_Instance.ContentStack:CalculateSize();
      local newBannerSize:number = self.m_Instance.ContentStack:GetSizeX() + 20;

      self.m_Instance.CityDetailsStack:CalculateSize();
      self.m_Instance.CityDetails:SetSizeX(self.m_Instance.CityDetailsStack:GetSizeX() + 10);

      local topInfoSize:number = self.m_Instance.CityDetails:GetSizeX() + 12;
      if (newBannerSize < topInfoSize) then
        newBannerSize = topInfoSize;
      end
      if (newBannerSize < MINIMUM_BANNER_WIDTH) then
        newBannerSize = MINIMUM_BANNER_WIDTH;
      end
      self.m_Instance.Container:SetSizeX(newBannerSize);

      -- Inside the city strength indicator (shield) - Recentering the characters that have odd leading
      --if(self.m_Instance.DefenseNumber:GetText() == "4" or self.m_Instance.DefenseNumber:GetText() == "6" or self.m_Instance.DefenseNumber:GetText() == "8") then
      --	self.m_Instance.DefenseNumber:SetOffsetX(-2);
      --end
    end
  end
end

-- ===========================================================================
-- Assign player colors to the appropriate banner elements
function CityBanner:UpdateColor()

  local backColor, frontColor  = UI.GetPlayerColors( self.m_Player:GetID() );
  local darkerBackColor = DarkenLightenColor(backColor,(-85),238);

  if (self.m_Type == BANNERTYPE_CITY_CENTER) then
    self.m_Instance.CityBannerFill:SetColor( backColor );
    self.m_Instance.CityBannerFillOver:SetColor( frontColor );
    self.m_Instance.CityBannerFillOut:SetColor( brighterBackColor );
    self.m_Instance.CityName:SetColor( frontColor, 0 );
    self.m_Instance.CityName:SetColor( darkerBackColor, 1 );
    if self.m_CivIconInstance then
      self.m_CivIconInstance.Icon:SetColor( frontColor );
    end
  elseif (self.m_Type == BANNERTYPE_AERODROME) then
    if self.m_Instance.AerodromeUnitsButton_Base ~= nil then
      self.m_Instance.AerodromeUnitsButton_Base:SetColor( backColor );
      self.m_Instance.AerodromeMouseOver:SetColor( frontColor );
      self.m_Instance.AerodromeMouseOut:SetColor( frontColor );
      self.m_Instance.AerodromeUnitsButtonIcon:SetColor( frontColor );
    end
  elseif (self.m_Type == BANNERTYPE_MISSILE_SILO) then
    if self.m_Instance.Banner_Base ~= nil then
      self.m_Instance.Banner_Base:SetColor( backColor );
      self.m_Instance.NukeCountLabel:SetColor( frontColor );
      self.m_Instance.ThermoNukeCountLabel:SetColor( frontColor );
    end
  elseif (self.m_Type == BANNERTYPE_ENCAMPMENT) then
    if self.m_Instance.Banner_Base ~= nil then
      self.m_Instance.Banner_Base:SetColor( backColor );
    end
  elseif (self.m_Type == BANNERTYPE_OTHER_DISTRICT) then
    if self.m_Instance.Banner_Base ~= nil then
      self.m_Instance.Banner_Base:SetColor( backColor );
    end
  elseif (self.m_Type == BANNERTYPE_MOUNTAIN_TUNNEL) then
    if self.m_Instance.Banner_Base ~= nil then
      self.m_Instance.Banner_Base:SetColor( backColor );
    end
  elseif (self.m_Type == BANNERTYPE_QHAPAQ_NAN) then
    if self.m_Instance.Banner_Base ~= nil then
      self.m_Instance.Banner_Base:SetColor( backColor );
    end
  else
    self.m_Instance.MiniBannerBackground:SetColor( backColor );
  end

  self:SetHealthBarColor();
end

-- ===========================================================================
function CityBanner:SetHealthBarColor()
  if self.m_Instance.CityHealthBar == nil then
    -- This normal behaviour in the case of missile silo and aerodrome minibanners
    return;
  end

  local percent = self.m_Instance.CityHealthBar:GetPercent();
  if (percent > .8 ) then
    self.m_Instance.CityHealthBar:SetColor( COLOR_CITY_GREEN );
  elseif ( percent > .4) then
    self.m_Instance.CityHealthBar:SetColor( COLOR_CITY_YELLOW );
  elseif ( percent < .4) then
    self.m_Instance.CityHealthBar:SetColor( COLOR_CITY_RED );
  end
end

-- ===========================================================================
function OnPopulationIconClicked(playerID: number, cityID: number)
  OnCityBannerClick(playerID, cityID);
  if (playerID == Game.GetLocalPlayer()) then
    LuaEvents.CityPanel_ToggleManageCitizens();
  end
end

-- ===========================================================================
-- Non-instance function so it can be overwritten by mods
function CityBanner:UpdateProduction(pCity:table)
  self.m_StatProductionIM:ResetInstances();

  local productionInstance:table = self.m_StatProductionIM:GetInstance();
  if pCity:GetOwner() == Game.GetLocalPlayer() then
    productionInstance.Button:RegisterCallback( Mouse.eLClick, OnProductionClick );
    productionInstance.Button:SetVoid1(pCity:GetOwner());
    productionInstance.Button:SetVoid2(pCity:GetID());
  else
    productionInstance.Button:ClearCallback( Mouse.eLClick );
  end

  local pBuildQueue		:table  = pCity:GetBuildQueue();
  if (pBuildQueue ~= nil) then
    local productionpct			:number = 0;
    local currentProduction		:string;
    local currentProductionHash :number = pBuildQueue:GetCurrentProductionTypeHash();
    local prodTurnsLeft			:number;
    local progress				:number;
    local prodTypeName			:string;
    local pBuildingDef			:table;
    local pDistrictDef			:table;
    local pUnitDef				:table;
    local pProjectDef			:table;

    -- Attempt to obtain a hash for each item
    if currentProductionHash ~= 0 then
      pBuildingDef = GameInfo.Buildings[currentProductionHash];
      pDistrictDef = GameInfo.Districts[currentProductionHash];
      pUnitDef	 = GameInfo.Units[currentProductionHash];
      pProjectDef	 = GameInfo.Projects[currentProductionHash];
    end

    if( pBuildingDef ~= nil ) then
      currentProduction = pBuildingDef.Name;
      prodTypeName = pBuildingDef.BuildingType;
      prodTurnsLeft = pBuildQueue:GetTurnsLeft(pBuildingDef.BuildingType);
      progress = pBuildQueue:GetBuildingProgress(pBuildingDef.Index);
      productionpct = progress / pBuildQueue:GetBuildingCost(pBuildingDef.Index);
    elseif ( pDistrictDef ~= nil ) then
      currentProduction = pDistrictDef.Name;
      prodTypeName = pDistrictDef.DistrictType;
      prodTurnsLeft = pBuildQueue:GetTurnsLeft(pDistrictDef.DistrictType);
      progress = pBuildQueue:GetDistrictProgress(pDistrictDef.Index);
      productionpct = progress / pBuildQueue:GetDistrictCost(pDistrictDef.Index);
    elseif ( pUnitDef ~= nil ) then
      local eMilitaryFormationType = pBuildQueue:GetCurrentProductionTypeModifier();
      currentProduction = pUnitDef.Name;
      prodTypeName = pUnitDef.UnitType;
      prodTurnsLeft = pBuildQueue:GetTurnsLeft(pUnitDef.UnitType, eMilitaryFormationType);
      progress = pBuildQueue:GetUnitProgress(pUnitDef.Index);

      if (eMilitaryFormationType == MilitaryFormationTypes.STANDARD_FORMATION) then
        productionpct = progress / pBuildQueue:GetUnitCost(pUnitDef.Index);	
      elseif (eMilitaryFormationType == MilitaryFormationTypes.CORPS_FORMATION) then
        productionpct = progress / pBuildQueue:GetUnitCorpsCost(pUnitDef.Index);
        if (pUnitDef.Domain == "DOMAIN_SEA") then
          -- Concatenanting two fragments is not loc friendly.  This needs to change.
          currentProduction = Locale.Lookup(currentProduction) .. " " .. Locale.Lookup("LOC_UNITFLAG_FLEET_SUFFIX");
        else
          -- Concatenanting two fragments is not loc friendly.  This needs to change.
          currentProduction = Locale.Lookup(currentProduction) .. " " .. Locale.Lookup("LOC_UNITFLAG_CORPS_SUFFIX");
        end
      elseif (eMilitaryFormationType == MilitaryFormationTypes.ARMY_FORMATION) then
        productionpct = progress / pBuildQueue:GetUnitArmyCost(pUnitDef.Index);
        if (pUnitDef.Domain == "DOMAIN_SEA") then
          -- Concatenanting two fragments is not loc friendly.  This needs to change.
          currentProduction = Locale.Lookup(currentProduction) .. " " .. Locale.Lookup("LOC_UNITFLAG_ARMADA_SUFFIX");
        else
          -- Concatenanting two fragments is not loc friendly.  This needs to change.
          currentProduction = Locale.Lookup(currentProduction) .. " " .. Locale.Lookup("LOC_UNITFLAG_ARMY_SUFFIX");
        end
      end

      progress = pBuildQueue:GetUnitProgress(pUnitDef.Index);
      productionpct = progress / pBuildQueue:GetUnitCost(pUnitDef.Index);
    elseif (pProjectDef ~= nil) then
      currentProduction = pProjectDef.Name;
      prodTypeName = pProjectDef.ProjectType;
      prodTurnsLeft = pBuildQueue:GetTurnsLeft(pProjectDef.ProjectType);
      progress = pBuildQueue:GetProjectProgress(pProjectDef.Index);
      productionpct = progress / pBuildQueue:GetProjectCost(pProjectDef.Index);
    end

    if (currentProduction ~= nil) then
      productionpct = math.clamp(productionpct, 0, 1);

      productionInstance.FillMeter:SetHide(false);
      productionInstance.FillMeter:SetPercent(productionpct);

      productionInstance.IconMeter:SetHide(false);
      productionInstance.IconMeter:SetPercent(productionpct);

      local productionTip				:string = Locale.Lookup("LOC_CITY_BANNER_PRODUCING", currentProduction);
      local productionTurnsLeftString :string;
      if prodTurnsLeft <= 0 then
        productionInstance.TurnsLeft:SetText("-");
        productionTurnsLeftString = "  " .. Locale.Lookup("LOC_CITY_BANNER_TURNS_LEFT_UNTIL_COMPLETE", "-");
      else
        productionTurnsLeftString = "  " .. Locale.Lookup("LOC_CITY_BANNER_TURNS_LEFT_UNTIL_COMPLETE", prodTurnsLeft);
        productionInstance.TurnsLeft:SetText(prodTurnsLeft);
      end
      productionTip = productionTip .. "[NEWLINE]" .. productionTurnsLeftString;
      productionInstance.Button:SetToolTipString(productionTip);
      productionInstance.Button:SetColor(0x00FFFFFF);
            
      if(prodTypeName ~= nil) then
        productionInstance.Slot:SetHide(false);
        productionInstance.Icon:SetHide(false);
        productionInstance.Icon:SetIcon("ICON_"..prodTypeName);
        productionInstance.IconMeter:SetTexture(IconManager:FindIconAtlas("ICON_"..prodTypeName, 32));
      else
        UI.DataError("City has current production, but no prodTypeName");
      end
    else
      productionInstance.Button:SetColor(0xFFFFFFFF);
      productionInstance.Button:SetToolTipString(Locale.Lookup("LOC_CITY_BANNER_NO_PRODUCTION"));
      productionInstance.FillMeter:SetHide(true);
      productionInstance.IconMeter:SetHide(true);
      productionInstance.Icon:SetHide(true);
      productionInstance.Slot:SetHide(true);
    end
  end
end

-- ===========================================================================
-- Non-instance function so it can be overwritten by mods
function CityBanner:UpdatePopulation(isLocalPlayer:boolean, pCity:table, pCityGrowth:table)

  self.m_StatPopulationIM:ResetInstances();

  local currentPopulation:number = pCity:GetPopulation();
  local populationInstance:table = self.m_StatPopulationIM:GetInstance();

  if isLocalPlayer then
    local food				:number = pCityGrowth:GetFood();
    local pCityData   :table  = GetCityData(pCity);
    local isGrowing			:boolean= pCityGrowth:GetTurnsUntilGrowth() ~= -1;
    local isStarving		:boolean= pCityGrowth:GetTurnsUntilStarvation() ~= -1;
    local growthThreshold	:number = pCityGrowth:GetGrowthThreshold();
    local foodpct			:number = Clamp( food / growthThreshold, 0.0, 1.0 );

    local iModifiedFood;
    local total :number;

    if pCityData.TurnsUntilGrowth > -1 then
      local growthModifier =  math.max(1 + (pCityData.HappinessGrowthModifier/100) + pCityData.OtherGrowthModifiers, 0); -- This is unintuitive but it's in parity with the logic in City_Growth.cpp
      iModifiedFood = Round(pCityData.FoodSurplus * growthModifier, 2);
      total = iModifiedFood * pCityData.HousingMultiplier;		
    else
      total = pCityData.FoodSurplus;
    end

    local turnsUntilGrowth:number = 0;	-- It is possible for zero... no growth and no starving.
    if isGrowing then
      turnsUntilGrowth = pCityGrowth:GetTurnsUntilGrowth();
    elseif isStarving then
      turnsUntilGrowth = -pCityGrowth:GetTurnsUntilStarvation();	-- negative
    end

    -- Get real housing from improvements value
    local localPlayerID = Game.GetLocalPlayer();
    local pCityID = pCity:GetID();
    if CQUI_HousingUpdated[localPlayerID] == nil or CQUI_HousingUpdated[localPlayerID][pCityID] ~= true then
      CQUI_RealHousingFromImprovements(pCity, localPlayerID, pCityID);
    end

    local CQUI_housingLeftPopupText = ""
    -- CQUI : housing left
    if g_smartbanner and g_smartbanner_population then

      local CQUI_HousingFromImprovements = CQUI_HousingFromImprovementsTable[localPlayerID][pCityID];    -- CQUI real housing from improvements value
      if CQUI_HousingFromImprovements ~= nil then    -- CQUI real housing from improvements fix to show correct values when waiting for the next turn
        local housingLeft = pCityGrowth:GetHousing() - pCityGrowth:GetHousingFromImprovements() + CQUI_HousingFromImprovements - currentPopulation; -- CQUI calculate real housing
        CQUI_housingLeftPopupText = housingLeft
        local housingLeftColor = "StatNormalCS";
        if housingLeft <= 1.5 and housingLeft > 0.5 then
          housingLeftColor = "WarningMinor";
        elseif housingLeft <= 0.5 then
          housingLeftColor = "WarningMajor";
        end
        if housingLeft >= 0.5 then
          housingLeft = "+"..housingLeft
        end
        local housingText = "[COLOR:"..housingLeftColor.."]"..housingLeft.."[ENDCOLOR]";
        populationInstance.CQUI_CityHousing:SetText(housingText);
        populationInstance.CQUI_CityHousing:SetHide(false);
      end
    else
      populationInstance.CQUI_CityHousing:SetHide(true);
    end
    -- CQUI : End of housing left
    
    local popTooltip:string = Locale.Lookup("LOC_CITY_BANNER_POPULATION") .. ": " .. currentPopulation;
    if turnsUntilGrowth > 0 then
      popTooltip = popTooltip .. "[NEWLINE]  " .. Locale.Lookup("LOC_CITY_BANNER_TURNS_GROWTH", turnsUntilGrowth);
      popTooltip = popTooltip .. "[NEWLINE]  " .. Locale.Lookup("LOC_CITY_BANNER_FOOD_SURPLUS", toPlusMinusString(total));
    elseif turnsUntilGrowth == 0 then
      popTooltip = popTooltip .. "[NEWLINE]  " .. Locale.Lookup("LOC_CITY_BANNER_STAGNATE");
    elseif turnsUntilGrowth < 0 then
      popTooltip = popTooltip .. "[NEWLINE]  " .. Locale.Lookup("LOC_CITY_BANNER_TURNS_STARVATION", -turnsUntilGrowth);
    end

    -- CQUI : add housing left to tooltip
    if g_smartbanner and g_smartbanner_population then
      CQUI_housingLeftPopupText = "[NEWLINE] [ICON_Housing]" .. Locale.Lookup("LOC_HUD_CITY_HOUSING") .. ": " .. CQUI_housingLeftPopupText
      popTooltip = popTooltip .. CQUI_housingLeftPopupText
    end

    populationInstance.FillMeter:SetToolTipString(popTooltip);
    if turnsUntilGrowth ~= 0 then
      populationInstance.CityPopTurnsLeft:SetText(turnsUntilGrowth);
    else
      populationInstance.CityPopTurnsLeft:SetText("-");
    end

    populationInstance.FillMeter:SetPercent(foodpct);
    populationInstance.SlotMeter:SetPercent(1 - foodpct);

    populationInstance.Button:RegisterCallback(Mouse.eLClick, OnPopulationIconClicked);
    populationInstance.Button:SetVoid1(Game.GetLocalPlayer());
    populationInstance.Button:SetVoid2(pCity:GetID());
  else
    populationInstance.BG:SetToolTipString(Locale.Lookup("LOC_CITY_BANNER_POPULATION") .. ": " .. currentPopulation);
  end

  populationInstance.CityPopulation:SetText(tostring(currentPopulation));
end

-- ===========================================================================
function OnGovernorIconClicked(playerID: number, cityID: number)
  if (playerID == Game.GetLocalPlayer()) then
    OnCityBannerClick(playerID, cityID);
  else
    OnCityBannerLookAt(playerID, cityID);
  end
  LuaEvents.GovernorPanel_Toggle();
end

-- ===========================================================================
function OnPowerIconClicked( playerID:number, cityID:number )
  if (playerID == Game.GetLocalPlayer()) then
    OnCityBannerClick(playerID, cityID);
    LuaEvents.CityPanel_ToggleOverviewPower();
  end
end

-- ===========================================================================
-- Non-instance function so it can be overwritten by mods
function CityBanner:UpdateGovernor(pCity:table)
  
  self.m_StatGovernorIM:ResetInstances();

  local localPlayerID:number = Game.GetLocalPlayer();

  if localPlayerID < 0 then
    return;
  end

  local pLocalPlayer:table = Players[localPlayerID];
  local pLocalPlayerDiplomacy:table = pLocalPlayer:GetDiplomacy();

  local isCityState:boolean = false;
  local cityOwner:number = pCity:GetOwner();
  for i, pCityState in ipairs(PlayerManager.GetAliveMinors()) do
    if pCityState:GetID() == cityOwner then
      isCityState = true;
      break;
    end
  end

  -- Always show local players governor first
  local otherGovernors = 0;
  local otherGovernorsTT = Locale.Lookup("LOC_CITY_STATE_PANEL_HAS_AMBASSADOR_TOOLTIP");

  local governors:table = pCity:GetAllAssignedGovernors();
  table.sort(governors, function(a, b) return a:GetOwner() == localPlayerID end);

  for i, pGovernor in ipairs(governors) do
    local playerID:number = pGovernor:GetOwner();
    local visibility:number = DiplomaticVisibilityTypes.TOP_SECRET + 1;

    if playerID ~= localPlayerID then
      visibility = pLocalPlayerDiplomacy:GetVisibilityOn(playerID);
      if visibility <= DiplomaticVisibilityTypes.NONE then
        return; -- Cannot see governor in this city
      end
    end

    -- Always show full icon for local players governors, even on city states
    if not isCityState or playerID == localPlayerID then
      local instance:table = self.m_StatGovernorIM:GetInstance();
      instance.NumOfAmbassadors:SetText("");

      if visibility > DiplomaticVisibilityTypes.LIMITED then
        
        instance.UnknownGovernor:SetHide(true);
        local icon = "ICON_" .. GameInfo.Governors[pGovernor:GetType()].GovernorType;
        instance.SlotMeter:SetTexture(IconManager:FindIconAtlas(icon .. "_SLOT", 32));
        instance.FillMeter:SetTexture(IconManager:FindIconAtlas(icon .. "_FILL", 32));

        if visibility > DiplomaticVisibilityTypes.FULL then
          if (pGovernor:IsEstablished()) then
            instance.TurnsLeft:SetText("");
            instance.FillMeter:SetPercent(1);
            instance.SlotMeter:SetPercent(0);
            instance.FillMeter:SetToolTipString(Locale.Lookup("LOC_HUD_CITY_GOVERNOR_ESTABLISHED_SPECIFIC", pGovernor:GetName()));
          else
            local iTurnsOnSite:number = pGovernor:GetTurnsOnSite();
            local iTurnsToEstablish:number = pGovernor:GetTurnsToEstablish();
            local iTurnsUntilEstablished:number = iTurnsToEstablish - iTurnsOnSite;
            local establishedPct:number = (iTurnsToEstablish - iTurnsUntilEstablished) / iTurnsToEstablish;

            instance.TurnsLeft:SetText(tostring(iTurnsUntilEstablished));
            instance.FillMeter:SetPercent(establishedPct);
            instance.SlotMeter:SetPercent(1 - establishedPct);

            local tooltip:string = Locale.Lookup("LOC_HUD_CITY_GOVERNOR_ASSIGNED_SPECIFIC", pGovernor:GetName());
            tooltip = tooltip .. "[NEWLINE]";
            tooltip = tooltip .. Locale.Lookup("LOC_GOVERNORS_SCREEN_GOVERNOR_TURNS_UNTIL_ESTABLISHED", iTurnsUntilEstablished);
            instance.FillMeter:SetToolTipString(tooltip);
          end
        else -- Open visibility (can see governor, but not whether they are established)
          instance.Button:SetVisState(-1); -- This makes production icon hide
          instance.TurnsLeft:SetText("?");
          instance.FillMeter:SetPercent(0);
          instance.SlotMeter:SetPercent(1);
          instance.FillMeter:SetToolTipString(Locale.Lookup("LOC_HUD_CITY_GOVERNOR_NO_TURNS", pGovernor:GetName()));
        end
      else -- Limited visibility (can see there is a governor, but not who or whether they are established)
        instance.TurnsLeft:SetText("");
        instance.FillMeter:SetPercent(0);
        instance.SlotMeter:SetPercent(0);
        instance.UnknownGovernor:SetHide(false);
        instance.FillMeter:SetToolTipString(Locale.Lookup("LOC_HUD_CITY_GOVERNOR_NO_ID"));
      end
      
      instance.Button:RegisterCallback(Mouse.eLClick, OnGovernorIconClicked);
      instance.Button:SetVoid1(cityOwner);
      instance.Button:SetVoid2(pCity:GetID());

    else -- We must be a city state, multiple diplomats can be slotted here (but only show one icon)
      local playerID:number = pGovernor:GetOwner();
      local visibility:number = DiplomaticVisibilityTypes.TOP_SECRET + 1;

      if playerID ~= localPlayerID then
        otherGovernors = otherGovernors + 1;
        visibility = pLocalPlayerDiplomacy:GetVisibilityOn(playerID);
      end

      local establishInfo;
      if visibility > DiplomaticVisibilityTypes.FULL then
        if (pGovernor:IsEstablished()) then
          establishInfo = Locale.Lookup("LOC_HUD_CITY_GOVERNOR_ESTABLISHED");
        else
          local iTurnsOnSite:number = pGovernor:GetTurnsOnSite();
          local iTurnsToEstablish:number = pGovernor:GetTurnsToEstablish();
          local iTurnsUntilEstablished:number = iTurnsToEstablish - iTurnsOnSite;
          establishInfo = Locale.Lookup("LOC_GOVERNORS_SCREEN_GOVERNOR_TURNS_UNTIL_ESTABLISHED", iTurnsUntilEstablished);
        end
      end

      local playerConfig = PlayerConfigurations[playerID];
      local bHasMet:boolean = pLocalPlayerDiplomacy:HasMet(playerID);
      if establishInfo then
        if (bHasMet) then
          otherGovernorsTT = otherGovernorsTT .. Locale.Lookup("LOC_CITY_BANNER_HAS_AMBASSADOR_TOOLTIP_ENTRY_FULL", Locale.Lookup(playerConfig:GetCivilizationDescription()), Locale.Lookup(playerConfig:GetPlayerName()), establishInfo);
        else
          otherGovernorsTT = Locale.Lookup("LOC_CITY_STATE_PANEL_HAS_AMBASSADOR_TOOLTIP_ENTRY_UNMET", Locale.Lookup(playerConfig:GetCivilizationDescription()), Locale.Lookup(playerConfig:GetPlayerName()));
        end
      else
        if (bHasMet) then
          otherGovernorsTT = otherGovernorsTT .. Locale.Lookup("LOC_CITY_BANNER_HAS_AMBASSADOR_TOOLTIP_ENTRY_LIMITED", Locale.Lookup(playerConfig:GetCivilizationDescription()), Locale.Lookup(playerConfig:GetPlayerName()));
        else
          otherGovernorsTT = otherGovernorsTT .. Locale.Lookup("LOC_CITY_STATE_PANEL_HAS_AMBASSADOR_TOOLTIP_ENTRY_UNMET", Locale.Lookup("LOC_LOYALTY_PANEL_UNMET_CIV"));
        end
      end
    end
  end

  -- We must be a city state, multiple diplomats can be slotted here (but only show one icon)
  if otherGovernors > 0 then
    local instance:table = self.m_StatGovernorIM:GetInstance();
    instance.FillMeter:SetPercent(1.0);
    instance.FillMeter:SetTexture(IconManager:FindIconAtlas("ICON_GOVERNOR_OTHER_AMBASSADORS_FILL", 32));
    instance.SlotMeter:SetPercent(0);
    instance.UnknownGovernor:SetHide(true);
    instance.FillMeter:SetToolTipString(otherGovernorsTT);
    instance.TurnsLeft:SetText("");
    instance.NumOfAmbassadors:SetText(otherGovernors > 1 and tostring(otherGovernors) or "");

    instance.Button:RegisterCallback(Mouse.eLClick, OnGovernorIconClicked);
    instance.Button:SetVoid1(pCity:GetOwner());
    instance.Button:SetVoid2(pCity:GetID());
  end
end

-- CQUI : TODO check if it's still needed
function GetPopulationTooltip(turnsUntilGrowth:number, currentPopulation:number, foodSurplus:number)
  --- POPULATION AND GROWTH INFO ---
  local popTooltip:string = Locale.Lookup("LOC_CITY_BANNER_POPULATION") .. ": " .. currentPopulation;
  if turnsUntilGrowth > 0 then
    popTooltip = popTooltip .. "[NEWLINE]  " .. Locale.Lookup("LOC_CITY_BANNER_TURNS_GROWTH", turnsUntilGrowth);
    popTooltip = popTooltip .. "[NEWLINE]  " .. Locale.Lookup("LOC_CITY_BANNER_FOOD_SURPLUS", round(foodSurplus,1));
  elseif turnsUntilGrowth == 0 then
    popTooltip = popTooltip .. "[NEWLINE]  " .. Locale.Lookup("LOC_CITY_BANNER_STAGNATE");
  elseif turnsUntilGrowth < 0 then
    popTooltip = popTooltip .. "[NEWLINE]  " .. Locale.Lookup("LOC_CITY_BANNER_TURNS_STARVATION", -turnsUntilGrowth);
  end
  return popTooltip;
end

-- ===========================================================================
function CityBanner:UpdateStats()
  local pDistrict:table = self:GetDistrict();
  local localPlayerID:number = Game.GetLocalPlayer();

  if (pDistrict ~= nil) then

    if self.m_Type == BANNERTYPE_CITY_CENTER then

      local pCity				:table = self:GetCity();
      local iCityOwner		:number = pCity:GetOwner();
      local pCityGrowth		:table  = pCity:GetGrowth();
      local populationIM		:table;

      if (localPlayerID == iCityOwner) then
        self:UpdatePopulation(true, pCity, pCityGrowth);
        self:UpdateGovernor(pCity);
        self:UpdateProduction(pCity);

        -- AZURENCY : Update the built districts 
        self.CQUI_DistrictBuiltIM:ResetInstances(); -- CQUI : Reset CQUI_DistrictBuiltIM
        local pCityDistricts:table = pCity:GetDistricts();
        if g_smartbanner_districts then
          for i, district in pCityDistricts:Members() do
            local districtType = district:GetType();
            local districtInfo:table = GameInfo.Districts[districtType];
            local isBuilt = pCityDistricts:HasDistrict(districtInfo.Index, true);
            if isBuilt and districtInfo.Index ~= 0 then
              SetDetailIcon(self.CQUI_DistrictBuiltIM:GetInstance(), "ICON_"..districtInfo.DistrictType);
            end
          end
        end
      else
        self:UpdatePopulation(false, pCity, pCityGrowth);
        self:UpdateGovernor(pCity);

        -- Espionage View should show a cities production if they have the proper diplo visibility
        if HasEspionageView(iCityOwner, pCity:GetID()) then
          self:UpdateProduction(pCity);
        elseif self.m_StatProductionIM ~= nil then
          self.m_StatProductionIM:ResetInstances();
        end
      end

      --- DEFENSE INFO ---
      local districtHitpoints		:number = pDistrict:GetMaxDamage(DefenseTypes.DISTRICT_GARRISON);
      local currentDistrictDamage :number = pDistrict:GetDamage(DefenseTypes.DISTRICT_GARRISON);
      local wallHitpoints			:number = pDistrict:GetMaxDamage(DefenseTypes.DISTRICT_OUTER);
      local currentWallDamage		:number = pDistrict:GetDamage(DefenseTypes.DISTRICT_OUTER);
      local garrisonDefense		:number = math.floor(pDistrict:GetDefenseStrength() + 0.5);

      local garrisonDefString :string = Locale.Lookup("LOC_CITY_BANNER_GARRISON_DEFENSE_STRENGTH");
      local defValue = garrisonDefense;
      local defTooltip = garrisonDefString .. ": " .. garrisonDefense;
      local healthTooltip :string = Locale.Lookup("LOC_CITY_BANNER_GARRISON_HITPOINTS", ((districtHitpoints-currentDistrictDamage) .. "/" .. districtHitpoints));
      if (wallHitpoints > 0) then
        self.m_Instance.DefenseIcon:SetHide(true);
        self.m_Instance.ShieldsIcon:SetHide(false);
        self.m_Instance.CityDefenseBarBacking:SetHide(false);
        self.m_Instance.CityHealthBarBacking:SetHide(false);
        self.m_Instance.CityDefenseBar:SetHide(false);
        healthTooltip = healthTooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_CITY_BANNER_OUTER_DEFENSE_HITPOINTS", ((wallHitpoints-currentWallDamage) .. "/" .. wallHitpoints));
        self.m_Instance.CityDefenseBar:SetPercent((wallHitpoints-currentWallDamage) / wallHitpoints);
        self.m_Instance.CityDefenseBarBacking:SetToolTipString(healthTooltip);
      else
        self.m_Instance.CityDefenseBar:SetHide(true);
        self.m_Instance.CityDefenseBarBacking:SetHide(true);
        self.m_Instance.CityHealthBarBacking:SetHide(true);
      end
      self.m_Instance.DefenseNumber:SetText(defValue);
      self.m_Instance.DefenseNumber:SetToolTipString(defTooltip);
      self.m_Instance.CityHealthBarBacking:SetToolTipString(healthTooltip);
      self.m_Instance.CityHealthBarBacking:SetHide(false);
      if(districtHitpoints > 0) then
        self.m_Instance.CityHealthBar:SetPercent((districtHitpoints-currentDistrictDamage) / districtHitpoints);	
      else
        self.m_Instance.CityHealthBar:SetPercent(0);	
      end
      self:SetHealthBarColor();	
      
      if (((districtHitpoints-currentDistrictDamage) / districtHitpoints) == 1 and wallHitpoints == 0) then
        self.m_Instance.CityHealthBar:SetHide(true);
        self.m_Instance.CityHealthBarBacking:SetHide(true);
      else
        self.m_Instance.CityHealthBar:SetHide(false);
        self.m_Instance.CityHealthBarBacking:SetHide(false);
      end

      self:UpdateDetails();
      --------------------------------------
    else -- it should be a miniBanner
      
      if (self.m_Type == BANNERTYPE_ENCAMPMENT) then 
        self:UpdateEncampmentBanner();
      elseif (self.m_Type == BANNERTYPE_AERODROME) then
        self:UpdateAerodromeBanner();
      elseif (self.m_Type == BANNERTYPE_OTHER_DISTRICT) then
        self:UpdateDistrictBanner();
      end
      
    end

  else  --it's a banner not associated with a district
    if (self.m_IsImprovementBanner) then
      local bannerPlot = Map.GetPlot(self.m_PlotX, self.m_PlotY);
      if (bannerPlot ~= nil) then
        if (self.m_Type == BANNERTYPE_AERODROME) then
          self:UpdateAerodromeBanner();
        elseif (self.m_Type == BANNERTYPE_MISSILE_SILO) then
          self:UpdateWMDBanner();
        end
      end
    end
  end
end

-- ===========================================================================
function SetDetailIcon( instance:table, icon:string, tooltip:string )
  instance.Icon:SetHide(icon == nil);
  if icon then instance.Icon:SetIcon(icon); end
  instance.Icon:SetToolTipString(tooltip and tooltip or "");

  -- If we have a button clear the callback incase we were previously doing something else
  if instance.Button ~= nil then
    instance.Button:ClearCallback( Mouse.eLClick );
  end
end

-- ===========================================================================
function CityBanner:UpdateDetails()
  
  local pCity:table = self:GetCity();
  local pDistrict:table = self:GetDistrict();
  if pCity and pDistrict then
    local cityOwner:number = pCity:GetOwner();
    local localPlayerID:number = Game.GetLocalPlayer();

    -- RESET INSTANCES
    self.m_DetailStatusIM:ResetInstances();
    self.m_DetailEffectsIM:ResetInstances();
    
    local bHasQuests: boolean = false;
    local questsManager: table = Game.GetQuestsManager();
    local questTooltip: string = Locale.Lookup("LOC_CITY_STATES_QUESTS");
    if questsManager then
      for questInfo in GameInfo.Quests() do
        if questsManager:HasActiveQuestFromPlayer(localPlayerID, cityOwner, questInfo.Index) then
          bHasQuests = true;
          questTooltip = questTooltip .. "[NEWLINE]" .. questInfo.IconString .. questsManager:GetActiveQuestName(localPlayerID, cityOwner, questInfo.Index);
        end
      end
    end

    if bHasQuests then
      SetDetailIcon(self.m_DetailStatusIM:GetInstance(), "ICON_CITY_STATUS_QUEST", Locale.Lookup(questTooltip));
    end

    if m_isTradeSelectionActive then
      local pCityTrade:table = pCity:GetTrade();
      if pCityTrade:HasActiveTradingPost(localPlayer) then
        SetDetailIcon(self.m_DetailStatusIM:GetInstance(), "ICON_CITY_STATUS_TRADE_ACTIVE", Locale.Lookup("LOC_CITY_BANNER_ACTIVE_TRADING"));
      elseif pCityTrade:HasInactiveTradingPost(localPlayer) then
        SetDetailIcon(self.m_DetailStatusIM:GetInstance(), "ICON_CITY_STATUS_TRADE_INACTIVE", Locale.Lookup("LOC_CITY_BANNER_INACTIVE_TRADING"));
      end
    end

    if pDistrict:CanAttack() then
      SetDetailIcon(self.m_DetailStatusIM:GetInstance(), "ICON_CITY_STATUS_STRIKE", Locale.Lookup("LOC_CITY_BANNER_CAN_STRIKE"));
    end
    
    self.m_Instance.CityDetailsStatus:CalculateSize();

    -- Update under siege icon
    if pDistrict:IsUnderSiege() then
      SetDetailIcon(self.m_DetailEffectsIM:GetInstance(), "ICON_CITY_EFFECTS_SIEGE", Locale.Lookup("LOC_HUD_REPORTS_STATUS_UNDER_SEIGE"));
    end

    if cityOwner == localPlayerID then
      local pCityGrowth:table = pCity:GetGrowth();

      -- Update occupied icon
      if pCity:IsOccupied() then
        local pCityIdentity     :table = pCity:GetCulturalIdentity();		
        local loyaltyLevel      :number = pCityIdentity:GetLoyaltyLevel();
        local loyaltyLevelName  :string = GameInfo.LoyaltyLevels[loyaltyLevel].Name;
        SetDetailIcon(self.m_DetailEffectsIM:GetInstance(), "ICON_CITY_EFFECTS_OCCUPIED", Locale.Lookup("LOC_HUD_CITY_OCCUPIED_LOYALITY_STATUS", loyaltyLevelName));
      end

      -- Update insufficient housing icon
      if pCityGrowth:GetHousing() < pCity:GetPopulation() then
        SetDetailIcon(self.m_DetailEffectsIM:GetInstance(), "ICON_CITY_EFFECTS_HOUSING", Locale.Lookup("LOC_CITY_BANNER_HOUSING_INSUFFICIENT"));
      end

      -- Update insufficient amenities icon
      if pCityGrowth:GetAmenitiesNeeded() > pCityGrowth:GetAmenities() then
        SetDetailIcon(self.m_DetailEffectsIM:GetInstance(), "ICON_CITY_EFFECTS_AMENITIES", Locale.Lookup("LOC_CITY_BANNER_AMENITIES_INSUFFICIENT"));
      end	
    end

    local pCityPower:table = pCity:GetPower();
    local freePower = pCityPower:GetFreePower();
    local temporaryPower = pCityPower:GetTemporaryPower();
    local requiredPower = pCityPower:GetRequiredPower();
    local powerTooltip = "";
    local powerIconKey = "PowerInsufficient";
    if (pCityPower:IsFullyPowered()) then
      powerIconKey = "Power";
      powerTooltip = Locale.Lookup("LOC_CITY_BANNER_POWERED_CITY", requiredPower, freePower, temporaryPower);
      if (pCityPower:IsFullyPoweredByActiveProject()) then
        powerTooltip = powerTooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_CITY_BANNER_POWERED_CITY_FROM_ACTIVE_PROJECT");
      end
    else
      powerTooltip = Locale.Lookup("LOC_CITY_BANNER_UNPOWERED_CITY", requiredPower, freePower, temporaryPower);
    end
    if (freePower > 0 or temporaryPower > 0 or requiredPower > 0) then
      local kPowerDetailEffectInst:table = self.m_DetailEffectsIM:GetInstance();
      SetDetailIcon(kPowerDetailEffectInst, powerIconKey, powerTooltip);
      kPowerDetailEffectInst.Button:RegisterCallback( Mouse.eLClick, function() OnPowerIconClicked(cityOwner, pCity:GetID()); end );
    end

    self.m_Instance.CityDetailsEffects:CalculateSize();
  end

  self:Resize();
end

-- ===========================================================================
--  Round to X decimal places -- do we have a function for this already?
-- ===========================================================================
function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult;
end

function OnCityBannerLookAt( playerID:number, cityID:number )
  local pPlayer = Players[playerID];
  if (pPlayer == nil) then
    return;
  end
  
  local pCity = pPlayer:GetCities():FindID(cityID);
  if (pCity == nil) then
    return;
  end

  UI.LookAtPlotScreenPosition( pCity:GetX(), pCity:GetY(), 0.5, 0.5 );
end

-- ===========================================================================
function OnCityBannerClick( playerID:number, cityID:number )
  local pPlayer = Players[playerID];
  if (pPlayer == nil) then
    return;
  end

  local pCity = pPlayer:GetCities():FindID(cityID);
  if (pCity == nil) then
    return;
  end

  if (pPlayer:IsFreeCities()) then
    UI.LookAtPlotScreenPosition( pCity:GetX(), pCity:GetY(), 0.5, 0.5 );
    return;
  end

  local localPlayerID;
  if (WorldBuilder.IsActive()) then
    localPlayerID = playerID; -- If WorldBuilder is active, allow the user to select the city
  else
    localPlayerID = Game.GetLocalPlayer();
  end

  if (pPlayer:GetID() == localPlayerID) then
    UI.SelectCity( pCity );
    UI.SetCycleAdvanceTimer(0);  -- Cancel any auto-advance timer
    UI.SetInterfaceMode(InterfaceModeTypes.CITY_MANAGEMENT);
  elseif(localPlayerID == PlayerTypes.OBSERVER
      or localPlayerID == PlayerTypes.NONE
      or pPlayer:GetDiplomacy():HasMet(localPlayerID)) then

    LuaEvents.CQUI_CityviewDisable(); -- Make sure the cityview is disable
    local pPlayerConfig :table    = PlayerConfigurations[playerID];
    local isMinorCiv  :boolean  = pPlayerConfig:GetCivilizationLevelTypeID() ~= CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV;
    --print("clicked player " .. playerID .. " city.  IsMinor?: ",isMinorCiv);

    if UI.GetInterfaceMode() == InterfaceModeTypes.MAKE_TRADE_ROUTE then
      local plotID = Map.GetPlotIndex(pCity:GetX(), pCity:GetY());
      LuaEvents.CityBannerManager_MakeTradeRouteDestination( plotID );
    else
      if isMinorCiv then
        if UI.GetInterfaceMode() ~= InterfaceModeTypes.SELECTION then
          UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
        end
        LuaEvents.CityBannerManager_RaiseMinorCivPanel( playerID ); -- Go directly to a city-state
      else
        LuaEvents.CityBannerManager_TalkToLeader( playerID );
      end
    end

  end
end

-- ===========================================================================
function OnMiniBannerClick( playerID, districtID )
  local pPlayer = Players[playerID];
  if (pPlayer == nil) then
    return;
  end

  local pDistrict = pPlayer:GetDistricts():FindID(districtID);
  if (pDistrict == nil) then
    return;
  end

  if (pPlayer:GetID() == Game.GetLocalPlayer()) then
    UI.DeselectAll();
    UI.SelectDistrict( pDistrict );
    --handle air unit menu here
  end
end

-- ===========================================================================
function OnProductionClick( playerID, cityID )
  OnCityBannerClick( playerID, cityID)
end

-- ===========================================================================
function CityBanner:GetCity()
  local pCity : table = self.m_Player:GetCities():FindID(self.m_CityID);
  return pCity;
end

-- ===========================================================================
function CityBanner:GetDistrict()
  local pDistrict : table = self.m_Player:GetDistricts():FindID(self.m_DistrictID);
  return pDistrict;
end

-- ===========================================================================
function CityBanner:GetImprovementInfo()
  local tImprovementInfo = {
    LocX               = self.m_PlotX,
    LocY               = self.m_PlotY,
    ImprovementOwner   = -1,
    AirUnits           = {},
  };
  return tImprovementInfo;
end

-- ===========================================================================
function CityBanner:SetFogState( fogState : number )

  if( fogState == PLOT_HIDDEN ) then
    self:SetHide( true );
  else
    self:SetHide( false );

    --If this is an Aerodrome we need to hide the numbers and dropdown if in FOW
    if( self.m_Type == BANNERTYPE_AERODROME) then
      if( fogState == PLOT_REVEALED ) then
        self.m_Instance.AerodromeBase:SetHide(true);
        self.m_Instance.UnitListPopup:SetDisabled(true);
      else
        self.m_Instance.AerodromeBase:SetHide(false);
        self.m_Instance.UnitListPopup:SetDisabled(not self.m_UnitListEnabled);
      end
    end
  end
  self.m_FogState = fogState;
end

-- ===========================================================================
function CityBanner:SetHide( bHide : boolean )
  self.m_IsCurrentlyVisible = not bHide;
  self:UpdateVisibility();
end

-- ===========================================================================
function CityBanner:UpdateVisibility()

  local bVisible = self.m_IsCurrentlyVisible and not self.m_IsForceHide;
  self.m_Instance.Anchor:SetHide(not bVisible);
  self:UpdateLoyaltyWarning();
end

-- ===========================================================================
function CityBanner:UpdateName()
  if (self.m_Type == BANNERTYPE_CITY_CENTER) then
    local pCity : table = self:GetCity();
    if pCity ~= nil then
      local cityName:string = pCity:GetName();

      local tooltip:string = "";
      local owner:number = pCity:GetOwner();
      local pPlayer:table  = Players[owner];
      if pPlayer and pPlayer:IsMajor() then
        tooltip = Locale.Lookup("LOC_CITY_BANNER_TT", cityName, PlayerConfigurations[owner]:GetCivilizationShortDescription());
      else
        tooltip = Locale.Lookup(cityName);
      end
      
      self.m_Instance.CityName:SetText( Locale.ToUpper(cityName) );
      self.m_Instance.CityBannerButton:SetToolTipString( tooltip );
      self:UpdateInfo( pCity );
      self:Resize();
    end
  end
end

-- ===========================================================================
function OnCapitalIconClicked( playerID:number, cityID:number )
  if (playerID == Game.GetLocalPlayer()) then
    OnCityBannerClick(playerID, cityID);
    LuaEvents.CityBannerManager_CityPanelOverview();
  else
    OnCityBannerLookAt(playerID, cityID);
    if HasEspionageView(playerID, cityID) then
      UI.DeselectAll();
      LuaEvents.CityBannerManager_ShowEnemyCityOverview(playerID, cityID);
    end
  end
end

-- ===========================================================================
function HasEspionageView( ownerID:number, cityID:number )
  local localPlayerID:number = Game.GetLocalPlayer();
  if localPlayerID == -1 then
    return;
  end
  
  -- Determine if the local player has any appropriate diplo visibilty to view this city
  local eVisibility:number = -1;
  local canViewCapital:boolean = false;
  local pLocalPlayer:table = Players[localPlayerID];
  if pLocalPlayer then
    local pLocalPlayerDiplo:table = pLocalPlayer:GetDiplomacy();
    if pLocalPlayerDiplo then
      eVisibility = pLocalPlayerDiplo:GetVisibilityOn(ownerID);
      local kVisDef:table = GameInfo.Visibilities_XP2[eVisibility];
      if kVisDef.EspionageViewAll == true then
        -- We can view all of this players cities
        return true;
      end

      if kVisDef.EspionageViewCapital == true then
        canViewCapital = true;
      end
    end
  end

  -- Check if this city is the capital if we can view the players capital
  if canViewCapital then
    local pOwner:table = Players[ownerID];
    if pOwner then
      local pCity:table = pOwner:GetCities():FindID(cityID);
      if pCity then
        if pCity:IsCapital() then
          return true;
        end
      end
    end
  end

  return false;
end

-- ===========================================================================
function OnCivIconClicked(playerID: number, cityID: number)
  if (playerID == Game.GetLocalPlayer()) then
    OnCityBannerClick(playerID, cityID);
    LuaEvents.CityPanel_ToggleOverviewLoyalty();
  else
    OnCityBannerLookAt(playerID, cityID);
    LuaEvents.OnViewLoyaltyLens();
  end
end

-- ===========================================================================
function OnReligionIconClicked(playerID: number, cityID: number)
  if (playerID == Game.GetLocalPlayer()) then
    OnCityBannerClick(playerID, cityID);
    LuaEvents.CityPanel_ToggleOverviewReligion();
  else
    OnCityBannerLookAt(playerID, cityID);
    LuaEvents.OnViewReligionLens();
  end
end

-- ===========================================================================
function CityBanner:UpdateInfo( pCity : table )
  
  self.m_CivIconInstance = nil;
  self.m_InfoIconIM:ResetInstances();
  self.m_InfoConditionIM:ResetInstances();

  if pCity ~= nil then
    local playerID		:number = pCity:GetOwner();
    local cityID		:number = pCity:GetID();
    local pPlayer		:table	= Players[playerID];
    local pPlayerConfig	:table	= PlayerConfigurations[playerID];

    -- CAPITAL ICON
    if pPlayer then
      local instance:table = self.m_InfoIconIM:GetInstance();
      local tooltip:string = "";

      if pPlayer:IsMajor() then
        if pCity:IsOriginalCapital() and pCity:GetOriginalOwner() == pCity:GetOwner() then
          if pCity:IsCapital() then
            -- Original capitial still owned by original owner
            instance.Icon:SetIcon("ICON_CITY_CAPITAL");
          else
            -- Former original capital
            instance.Icon:SetIcon("ICON_FORMER_CAPITAL");
          end
          tooltip = tooltip .. Locale.Lookup("LOC_CITY_BANNER_ORIGINAL_CAPITAL_TT", pPlayerConfig:GetCivilizationShortDescription());
        elseif pCity:IsCapital() then
          -- New capital
          instance.Icon:SetIcon("ICON_NEW_CAPITAL");
          tooltip = tooltip .. Locale.Lookup("LOC_CITY_BANNER_NEW_CAPITAL_TT", pPlayerConfig:GetCivilizationShortDescription());
        else
          -- Other cities
          instance.Icon:SetIcon("ICON_OTHER_CITIES");
          tooltip = tooltip .. Locale.Lookup("LOC_CITY_BANNER_OTHER_CITY_TT", pPlayerConfig:GetCivilizationShortDescription());
        end

        if GameCapabilities.HasCapability("CAPABILITY_ESPIONAGE") then			
          if Game.GetLocalPlayer() == playerID or HasEspionageView(playerID, cityID) then
            tooltip = tooltip .. Locale.Lookup("LOC_ESPIONAGE_VIEW_ENABLED_TT");
          else
            tooltip = tooltip .. Locale.Lookup("LOC_ESPIONAGE_VIEW_DISABLED_TT");
          end
        end
        
      elseif pPlayer:IsFreeCities() then
        instance.Icon:SetIcon("ICON_CIVILIZATION_FREE_CITIES");
        tooltip = tooltip .. Locale.Lookup("LOC_CITY_BANNER_FREE_CITY_TT");
      else
        instance.Icon:SetIcon("ICON_CITY_STATE");
        tooltip = tooltip .. Locale.Lookup("LOC_CITY_BANNER_CITY_STATE_TT");
      end

      instance.Button:RegisterCallback(Mouse.eLClick, OnCapitalIconClicked);
      instance.Button:SetVoid1(playerID);
      instance.Button:SetVoid2(cityID);
      instance.Button:SetToolTipString(tooltip);

      -- ORIGINAL OWNER CAPITAL ICON
      if pCity:GetOwner() ~= pCity:GetOriginalOwner() and pCity:IsOriginalCapital() then
        local pOriginalOwner:table = Players[pCity:GetOriginalOwner()];
        -- Only show the captured capital icon for major civs
        if pOriginalOwner:IsMajor() then
          local instance:table = self.m_InfoIconIM:GetInstance();
          instance.Icon:SetIcon("ICON_CAPTURED_CAPITAL");
          local pOriginalOwnerConfig:table = PlayerConfigurations[pCity:GetOriginalOwner()];
          instance.Button:SetToolTipString(Locale.Lookup("LOC_CITY_BANNER_CAPTURED_CAPITAL_TT", pOriginalOwnerConfig:GetCivilizationShortDescription()));
          instance.Button:RegisterCallback(Mouse.eLClick, OnCapitalIconClicked);
          instance.Button:SetVoid1(pCity:GetOriginalOwner());
          instance.Button:SetVoid2(cityID);
        end
      end
    end

    -- CIV ICON
    local civType:string = pPlayerConfig:GetCivilizationTypeName();
    if civType ~= nil then
      self.m_CivIconInstance = self.m_InfoConditionIM:GetInstance();
      self.m_CivIconInstance.Icon:SetIcon("ICON_" .. civType);
  
      local tooltip, isLoyaltyRising, isLoyaltyFalling = GetLoyaltyStatusTooltip(pCity);
      -- Add belongs to string at the beginning of the tooltip
      if civType == "CIVILIZATION_FREE_CITIES" then
        tooltip = Locale.Lookup("LOC_CITY_BELONGS_FREECITY_TT") .. "[NEWLINE]" .. tooltip;
      else
        tooltip = Locale.Lookup("LOC_CITY_BELONGS_TT", pPlayerConfig:GetCivilizationShortDescription()) .. "[NEWLINE]" .. tooltip;
      end

      self.m_CivIconInstance.ConditionRising:SetHide(not isLoyaltyRising or isLoyaltyFalling);
      self.m_CivIconInstance.ConditionFalling:SetHide(not isLoyaltyFalling or isLoyaltyRising);
      self.m_CivIconInstance.Button:SetToolTipString(tooltip);
  
      self.m_CivIconInstance.Button:RegisterCallback( Mouse.eLClick, OnCivIconClicked );
      self.m_CivIconInstance.Button:SetVoid1(playerID);
      self.m_CivIconInstance.Button:SetVoid2(cityID);
    else
      UI.DataError("Invalid type name returned by GetCivilizationTypeName");
    end

    -- RELIGION ICON
    local pCityReligion:table = pCity:GetReligion();
    local eMajorityReligion:number = self.m_eMajorityReligion;
    if (eMajorityReligion > 0) then
      local instance:table = self.m_InfoConditionIM:GetInstance();
      local majorityReligionColor:number = UI.GetColorValue(GameInfo.Religions[eMajorityReligion].Color);
      instance.Icon:SetColor(majorityReligionColor and majorityReligionColor or COLOR_HOLY_SITE);
      instance.Icon:SetIcon("ICON_" .. GameInfo.Religions[eMajorityReligion].ReligionType);
      instance.Button:SetToolTipString(Locale.Lookup("LOC_HUD_CITY_RELIGION_TT", Game.GetReligion():GetName(eMajorityReligion)));
      instance.Button:RegisterCallback( Mouse.eLClick, OnReligionIconClicked );
      instance.Button:SetVoid1(playerID);
      instance.Button:SetVoid2(cityID);

      -- Get a list of religions present in this city
      local otherReligionPressure:number = 0;
      local pReligionsInCity:table = pCityReligion:GetReligionsInCity();
      for _, cityReligion in pairs(pReligionsInCity) do
        local religion:number = cityReligion.Religion;
        if religion >= 0 and religion ~= eMajorityReligion then
          otherReligionPressure = otherReligionPressure + pCityReligion:GetTotalPressureOnCity(religion);
        end
      end

      local majorityPressure:number = pCityReligion:GetTotalPressureOnCity(eMajorityReligion);

      local isPressureRising:boolean = majorityPressure > otherReligionPressure;
      local isPressureFalling:boolean = majorityPressure < otherReligionPressure;

      instance.ConditionRising:SetHide(not isPressureRising or isPressureFalling);
      instance.ConditionFalling:SetHide(not isPressureFalling or isPressureRising);
    else
      local activePantheon:number = pCityReligion:GetActivePantheon();
      if (activePantheon >= 0) then
        local instance:table = self.m_InfoIconIM:GetInstance();
        instance.Icon:SetIcon("ICON_" .. GameInfo.Religions[0].ReligionType);
        instance.Icon:SetColor(COLOR_HOLY_SITE);
        instance.Button:SetToolTipString(Locale.Lookup("LOC_HUD_CITY_PANTHEON_TT", GameInfo.Beliefs[activePantheon].Name));
        instance.Button:RegisterCallback( Mouse.eLClick, OnReligionIconClicked );
        instance.Button:SetVoid1(playerID);
        instance.Button:SetVoid2(cityID);
      end
    end

    --CQUI : Unlocked citizen check
    if playerID == Game.GetLocalPlayer() and g_smartbanner and g_smartbanner_unmanaged_citizen then
      local tParameters :table = {};
      tParameters[CityCommandTypes.PARAM_MANAGE_CITIZEN] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_MANAGE_CITIZEN);

      local tResults:table = CityManager.GetCommandTargets( pCity, CityCommandTypes.MANAGE, tParameters );
      if tResults ~= nil then
        local tPlots:table = tResults[CityCommandResults.PLOTS];
        local tUnits:table = tResults[CityCommandResults.CITIZENS];
        local tMaxUnits:table = tResults[CityCommandResults.MAX_CITIZENS];
        local tLockedUnits:table = tResults[CityCommandResults.LOCKED_CITIZENS];
        if tPlots ~= nil and (table.count(tPlots) > 0) then
          for i,plotId in pairs(tPlots) do
            local kPlot :table = Map.GetPlotByIndex(plotId);
            if(tMaxUnits[i] >= 1 and tUnits[i] >= 1 and tLockedUnits[i] <= 0) then
              local instance:table = self.m_InfoIconIM:GetInstance();
              instance.Icon:SetIcon("EXCLAMATION");
              instance.Icon:SetToolTipString(Locale.Lookup("LOC_CQUI_SMARTBANNER_UNLOCKEDCITIZEN_TOOLTIP"));
              instance.Button:RegisterCallback(Mouse.eLClick, OnCityBannerClick);
              instance.Button:SetVoid1(pCity:GetOriginalOwner());
              instance.Button:SetVoid2(cityID);
              break;
            end
          end
        end
      end
    end
    -- CQUI : End Unlocked Citizen Check

    -- LOYALTY WARNING
    self:UpdateLoyaltyWarning();
  end

  self:Resize();
end

-- ===========================================================================
-- function CityBanner.UpdateName( self : CityBanner )
--   if (self.m_Type == BANNERTYPE_CITY_CENTER) then
--     local pCity : table = self:GetCity();
--     if pCity ~= nil then
--       local owner     :number = pCity:GetOwner();
--       local pPlayer   :table  = Players[owner];
--       local capitalIcon :string = (pPlayer ~= nil and pPlayer:IsMajor() and pCity:IsCapital()) and "[ICON_Capital]" or "";
--       local cityName    :string = capitalIcon .. Locale.ToUpper(pCity:GetName());

--       if not self:IsTeam() then
--         local civType:string = PlayerConfigurations[owner]:GetCivilizationTypeName();
--         if civType ~= nil then
--           self.m_Instance.CivIcon:SetIcon("ICON_" .. civType);
--         else
--           UI.DataError("Invalid type name returned by GetCivilizationTypeName");
--         end
--       end

--       local questsManager : table = Game.GetQuestsManager();
--       local questTooltip  : string = Locale.Lookup("LOC_CITY_STATES_QUESTS");
--       local statusString  : string = "";
--       if (questsManager ~= nil) then
--         for questInfo in GameInfo.Quests() do
--           if (questsManager:HasActiveQuestFromPlayer(Game.GetLocalPlayer(), owner, questInfo.Index)) then
--             statusString = "[ICON_CityStateQuest]";
--             questTooltip = questTooltip .. "[NEWLINE]" .. questInfo.IconString .. questsManager:GetActiveQuestName(Game.GetLocalPlayer(), owner, questInfo.Index);
--           end
--         end
--       end

--       -- Update under siege icon
--       local pDistrict:table = self:GetDistrict();
--       if pDistrict and pDistrict:IsUnderSiege() then
--         self.m_Instance.CityUnderSiegeIcon:SetHide(false);
--       else
--         self.m_Instance.CityUnderSiegeIcon:SetHide(true);
--       end

--       -- Update district icons
--       -- districtType:number == Index
--       function GetDistrictIndexSafe(sDistrict)
--         if GameInfo.Districts[sDistrict] == nil then return -1;
--         else return GameInfo.Districts[sDistrict].Index; end
--       end

--       local iAquaduct = GetDistrictIndexSafe("DISTRICT_AQUEDUCT");
--       local iBath = GetDistrictIndexSafe("DISTRICT_BATH");
--       local iNeighborhood = GetDistrictIndexSafe("DISTRICT_NEIGHBORHOOD");
--       local iMbanza = GetDistrictIndexSafe("DISTRICT_MBANZA");
--       local iCampus = GetDistrictIndexSafe("DISTRICT_CAMPUS");
--       local iTheater = GetDistrictIndexSafe("DISTRICT_THEATER");
--       local iAcropolis = GetDistrictIndexSafe("DISTRICT_ACROPOLIS");
--       local iIndustrial = GetDistrictIndexSafe("DISTRICT_INDUSTRIAL_ZONE");
--       local iHansa = GetDistrictIndexSafe("DISTRICT_HANSA");
--       local iCommerce = GetDistrictIndexSafe("DISTRICT_COMMERCIAL_HUB");
--       local iEncampment = GetDistrictIndexSafe("DISTRICT_ENCAMPMENT");
--       local iHarbor = GetDistrictIndexSafe("DISTRICT_HARBOR");
--       local iRoyalNavy = GetDistrictIndexSafe("DISTRICT_ROYAL_NAVY_DOCKYARD");
--       local iSpaceport = GetDistrictIndexSafe("DISTRICT_SPACEPORT");
--       local iEntertainmentComplex = GetDistrictIndexSafe("DISTRICT_ENTERTAINMENT_COMPLEX");
--       local iHolySite = GetDistrictIndexSafe("DISTRICT_HOLY_SITE");
--       local iAerodrome = GetDistrictIndexSafe("DISTRICT_AERODROME");
--       local iStreetCarnival = GetDistrictIndexSafe("DISTRICT_STREET_CARNIVAL");
--       local iLavra = GetDistrictIndexSafe("DISTRICT_LAVRA");

--       if self.m_Instance.CityBuiltDistrictAquaduct ~= nil then
--         self.m_Instance.CityUnlockedCitizen:SetHide(true);
--         self.m_Instance.CityBuiltDistrictAquaduct:SetHide(true);
--         self.m_Instance.CityBuiltDistrictBath:SetHide(true);
--         self.m_Instance.CityBuiltDistrictNeighborhood:SetHide(true);
--         self.m_Instance.CityBuiltDistrictMbanza:SetHide(true);
--         self.m_Instance.CityBuiltDistrictCampus:SetHide(true);
--         self.m_Instance.CityBuiltDistrictCommercial:SetHide(true);
--         self.m_Instance.CityBuiltDistrictEncampment:SetHide(true);
--         self.m_Instance.CityBuiltDistrictTheatre:SetHide(true);
--         self.m_Instance.CityBuiltDistrictAcropolis:SetHide(true);
--         self.m_Instance.CityBuiltDistrictIndustrial:SetHide(true);
--         self.m_Instance.CityBuiltDistrictHansa:SetHide(true);
--         self.m_Instance.CityBuiltDistrictHarbor:SetHide(true);
--         self.m_Instance.CityBuiltDistrictRoyalNavy:SetHide(true);
--         self.m_Instance.CityBuiltDistrictSpaceport:SetHide(true);
--         self.m_Instance.CityBuiltDistrictEntertainment:SetHide(true);
--         self.m_Instance.CityBuiltDistrictHoly:SetHide(true);
--         self.m_Instance.CityBuiltDistrictAerodrome:SetHide(true);
--         self.m_Instance.CityBuiltDistrictStreetCarnival:SetHide(true);
--         self.m_Instance.CityBuiltDistrictLavra:SetHide(true);
--       end

--       local pCityDistricts:table  = pCity:GetDistricts();
--       if g_smartbanner and self.m_Instance.CityBuiltDistrictAquaduct ~= nil then
--         --Unlocked citizen check
--         if g_smartbanner_unmanaged_citizen then
--           local tParameters :table = {};
--           tParameters[CityCommandTypes.PARAM_MANAGE_CITIZEN] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_MANAGE_CITIZEN);

--           local tResults  :table = CityManager.GetCommandTargets( pCity, CityCommandTypes.MANAGE, tParameters );
--           if tResults ~= nil then
--             local tPlots    :table = tResults[CityCommandResults.PLOTS];
--             local tUnits    :table = tResults[CityCommandResults.CITIZENS];
--             local tMaxUnits   :table = tResults[CityCommandResults.MAX_CITIZENS];
--             local tLockedUnits  :table = tResults[CityCommandResults.LOCKED_CITIZENS];
--             if tPlots ~= nil and (table.count(tPlots) > 0) then
--               for i,plotId in pairs(tPlots) do
--                 local kPlot :table = Map.GetPlotByIndex(plotId);
--                 if(tMaxUnits[i] >= 1 and tUnits[i] >= 1 and tLockedUnits[i] <= 0) then
--                   self.m_Instance.CityUnlockedCitizen:SetHide(false);
--                 end
--               end
--             end
--           end
--         end
--         -- End Unlocked Citizen Check

--         if g_smartbanner_districts then
--           for i, district in pCityDistricts:Members() do
--             local districtType = district:GetType();
--             local districtInfo:table = GameInfo.Districts[districtType];
--             local isBuilt = pCityDistricts:HasDistrict(districtInfo.Index, true);
--             if isBuilt then
--               if (districtType == iAquaduct) then self.m_Instance.CityBuiltDistrictAquaduct:SetHide(false); end
--               if (districtType == iBath) then self.m_Instance.CityBuiltDistrictBath:SetHide(false); end
--               if (districtType == iNeighborhood) then self.m_Instance.CityBuiltDistrictNeighborhood:SetHide(false); end
--               if (districtType == iMbanza) then self.m_Instance.CityBuiltDistrictMbanza:SetHide(false); end
--               if (districtType == iCampus) then self.m_Instance.CityBuiltDistrictCampus:SetHide(false); end
--               if (districtType == iCommerce) then self.m_Instance.CityBuiltDistrictCommercial:SetHide(false); end
--               if (districtType == iEncampment) then self.m_Instance.CityBuiltDistrictEncampment:SetHide(false); end
--               if (districtType == iTheater) then self.m_Instance.CityBuiltDistrictTheatre:SetHide(false); end
--               if (districtType == iAcropolis) then self.m_Instance.CityBuiltDistrictAcropolis:SetHide(false); end
--               if (districtType == iIndustrial) then self.m_Instance.CityBuiltDistrictIndustrial:SetHide(false); end
--               if (districtType == iHansa) then self.m_Instance.CityBuiltDistrictHansa:SetHide(false); end
--               if (districtType == iHarbor) then self.m_Instance.CityBuiltDistrictHarbor:SetHide(false); end
--               if (districtType == iRoyalNavy) then self.m_Instance.CityBuiltDistrictRoyalNavy:SetHide(false); end
--               if (districtType == iSpaceport) then self.m_Instance.CityBuiltDistrictSpaceport:SetHide(false); end
--               if (districtType == iEntertainmentComplex) then self.m_Instance.CityBuiltDistrictEntertainment:SetHide(false); end
--               if (districtType == iHolySite) then self.m_Instance.CityBuiltDistrictHoly:SetHide(false); end
--               if (districtType == iAerodrome) then self.m_Instance.CityBuiltDistrictAerodrome:SetHide(false); end
--               if (districtType == iStreetCarnival) then self.m_Instance.CityBuiltDistrictStreetCarnival:SetHide(false); end
--               if (districtType == iLavra) then self.m_Instance.CityBuiltDistrictLavra:SetHide(false); end
--             end
--           end
--         end
--       end

--       -- Update insufficient housing icon
--       if self.m_Instance.CityHousingInsufficientIcon ~= nil then
--         local pCityGrowth:table = pCity:GetGrowth();
--         if pCityGrowth and pCityGrowth:GetHousing() < pCity:GetPopulation() then
--           self.m_Instance.CityHousingInsufficientIcon:SetHide(false);
--         else
--           self.m_Instance.CityHousingInsufficientIcon:SetHide(true);
--         end
--       end

--       -- Update insufficient amenities icon
--       if self.m_Instance.CityAmenitiesInsufficientIcon ~= nil then
--         local pCityGrowth:table = pCity:GetGrowth();
--         if pCityGrowth and pCityGrowth:GetAmenitiesNeeded() > pCityGrowth:GetAmenities() then
--           self.m_Instance.CityAmenitiesInsufficientIcon:SetHide(false);
--         else
--           self.m_Instance.CityAmenitiesInsufficientIcon:SetHide(true);
--         end
--       end

--       -- Update occupied icon
--       if self.m_Instance.CityOccupiedIcon ~= nil then
--         if pCity:IsOccupied() then
--           self.m_Instance.CityOccupiedIcon:SetHide(false);
--         else
--           self.m_Instance.CityOccupiedIcon:SetHide(true);
--         end
--       end

--       -- CQUI: Show leader icon for the suzerain
--       local pPlayerConfig :table = PlayerConfigurations[owner];
--       local isMinorCiv :boolean = pPlayerConfig:GetCivilizationLevelTypeID() ~= CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV;
--       if isMinorCiv then
--         CQUI_UpdateSuzerainIcon(pPlayer, self);
--       end

--       self.m_Instance.CityQuestIcon:SetToolTipString(questTooltip);
--       self.m_Instance.CityQuestIcon:SetText(statusString);
--       self.m_Instance.CityName:SetText( cityName );
--       self.m_Instance.CityNameStack:ReprocessAnchoring();
--       self.m_Instance.ContentStack:ReprocessAnchoring();
--       self:Resize();
--     end
--   end
-- end

-- ===========================================================================
function CityBanner:UpdateReligion()

  local pCity				:table = self:GetCity();
  local pCityReligion		:table = pCity:GetReligion();
  local localPlayerID		:number = Game.GetLocalPlayer();
  local eMajorityReligion	:number = pCityReligion:GetMajorityReligion();

  self.m_eMajorityReligion = eMajorityReligion;
  self:UpdateInfo(pCity);

  local cityInst			:table = self.m_Instance;
  local religionInfo		:table = cityInst.ReligionInfo;
  local religionsInCity	:table = pCityReligion:GetReligionsInCity();

  -- Hide the meter and bail out if the religion lens isn't active
  if(not m_isReligionLensActive or table.count(religionsInCity) == 0) then
    if religionInfo then
      religionInfo.ReligionInfoContainer:SetHide(true);
    end
    return;
  end

  -- Update religion icon + religious pressure animation
  local majorityReligionColor:number = COLOR_RELIGION_DEFAULT;
  if(eMajorityReligion >= 0) then
    majorityReligionColor = UI.GetColorValue(GameInfo.Religions[eMajorityReligion].Color);
  end
  
  -- Preallocate total fill so we can stagger the meters
  local totalFillPercent:number = 0;
  local iCityPopulation:number = pCity:GetPopulation();

  -- Get a list of religions present in this city
  local activeReligions:table = {};
  local numOfActiveReligions:number = 0;
  local pReligionsInCity:table = pCityReligion:GetReligionsInCity();
  for _, cityReligion in pairs(pReligionsInCity) do
    local religion:number = cityReligion.Religion;
    if(religion >= 0) then
      local followers:number = cityReligion.Followers;
      local fillPercent:number = followers / iCityPopulation;
      totalFillPercent = totalFillPercent + fillPercent;

      table.insert(activeReligions, {
        Religion=religion,
        Followers=followers,
        Pressure=pCityReligion:GetTotalPressureOnCity(religion),
        LifetimePressure=cityReligion.Pressure,
        FillPercent=fillPercent,
        Color=GameInfo.Religions[religion].Color });

      numOfActiveReligions = numOfActiveReligions + 1;
    end
  end
  
  -- Sort religions by largest number of followers
  table.sort(activeReligions, function(a,b) return a.Followers > b.Followers; end);

  -- After sort update accumulative fill percent
  local accumulativeFillPercent = 0.0;
  for i, religion in ipairs(activeReligions) do
    accumulativeFillPercent = accumulativeFillPercent + religion.FillPercent;
    religion.AccumulativeFillPercent = accumulativeFillPercent;
  end

  if(table.count(activeReligions) > 0) then
    local localPlayerVis:table = PlayersVisibility[localPlayerID];
    if (localPlayerVis ~= nil) then
      -- Holy sites get a different color and texture
      local holySitePlotIDs:table = {};
      local cityDistricts:table = pCity:GetDistricts();
      local playerDistricts:table = self.m_Player:GetDistricts();
      for i, district in cityDistricts:Members() do
        local districtType:string = GameInfo.Districts[district:GetType()].DistrictType;
        if(districtType == "DISTRICT_HOLY_SITE") then
          local locX:number = district:GetX();
          local locY:number = district:GetY();
          if localPlayerVis:IsVisible(locX, locY) then
            local plot:table  = Map.GetPlot(locX, locY);
            local holySiteFaithYield:number = district:GetReligionHealRate();
            SpawnHolySiteIconAtLocation(locX, locY, "+" .. holySiteFaithYield);
            holySitePlotIDs[plot:GetIndex()] = true;
          end
          break;
        end
      end

      -- Color hexes in this city the same color as religion
      local plots:table = Map.GetCityPlots():GetPurchasedPlots(pCity);
      if(table.count(plots) > 0) then
        UILens.SetLayerHexesColoredArea( m_HexColoringReligion, localPlayerID, plots, majorityReligionColor );
      end
    end
  end

  if religionInfo then
    -- Create or reset icon instance manager
    local iconIM:table = cityInst[DATA_FIELD_RELIGION_ICONS_IM];
    if(iconIM == nil) then
      iconIM = InstanceManager:new("ReligionIconInstance", "ReligionIconButtonBacking", religionInfo.ReligionInfoIconStack);
      cityInst[DATA_FIELD_RELIGION_ICONS_IM] = iconIM;
    else
      iconIM:ResetInstances();
    end

    -- Create or reset follower list instance manager
    local followerListIM:table = cityInst[DATA_FIELD_RELIGION_FOLLOWER_LIST_IM];
    if(followerListIM == nil) then
      followerListIM = InstanceManager:new("ReligionFollowerListInstance", "ReligionFollowerListContainer", religionInfo.ReligionFollowerListStack);
      cityInst[DATA_FIELD_RELIGION_FOLLOWER_LIST_IM] = followerListIM;
    else
      followerListIM:ResetInstances();
    end

    -- Create or reset pop chart instance manager
    local popChartIM:table = cityInst[DATA_FIELD_RELIGION_POP_CHART_IM];
    if(popChartIM == nil) then
      popChartIM = InstanceManager:new("ReligionPopChartInstance", "PopChartMeter", religionInfo.ReligionPopChartContainer);
      cityInst[DATA_FIELD_RELIGION_POP_CHART_IM] = popChartIM;
    else
      popChartIM:ResetInstances();
    end

    local populationChartTooltip:string = RELIGION_POP_CHART_TOOLTIP_HEADER;

    -- Show what religion we will eventually turn into
    local nextReligion = pCityReligion:GetNextReligion();
    local turnsTillNextReligion:number = pCityReligion:GetTurnsToNextReligion();
    if nextReligion and nextReligion ~= -1 and turnsTillNextReligion > 0 then
      local pNextReligionDef:table = GameInfo.Religions[nextReligion];

      -- Religion icon
      if religionInfo.ConvertingReligionIcon then
        local religionIcon = "ICON_" .. pNextReligionDef.ReligionType;
        religionInfo.ConvertingReligionIcon:SetIcon(religionIcon);
        local religionColor = UI.GetColorValue(pNextReligionDef.Color);
        religionInfo.ConvertingReligionIcon:SetColor(religionColor);
        religionInfo.ConvertingReligionIconBacking:SetColor(religionColor);
        religionInfo.ConvertingReligionIconBacking:SetToolTipString(Locale.Lookup(pNextReligionDef.Name));
      end

      -- Converting text
      local convertString = Locale.Lookup("LOC_CITY_BANNER_CONVERTS_IN_X_TURNS", turnsTillNextReligion);
      religionInfo.ConvertingReligionLabel:SetText(convertString);
      religionInfo.ReligionConversionTurnsStack:SetHide(false);

      -- If the turns till conversion are less than 10 play the warning flash animation
      religionInfo.ConvertingSoonAlphaAnim:SetToBeginning();
      if turnsTillNextReligion <= 10 then
        religionInfo.ConvertingSoonAlphaAnim:Play();
      else
        religionInfo.ConvertingSoonAlphaAnim:Stop();
      end
    else
      religionInfo.ReligionConversionTurnsStack:SetHide(true);
    end

    -- Add religion icons for each active religion
    for i,religionInfo in ipairs(activeReligions) do
      local religionDef:table = GameInfo.Religions[religionInfo.Religion];

      local icon = "ICON_" .. religionDef.ReligionType;
      local religionColor = UI.GetColorValue(religionDef.Color);
    
      -- The first index is the predominant religion. Label it as such.
      local religionName = "";
      if i == 1 and numOfActiveReligions > 1 then
        religionName = Locale.Lookup("LOC_CITY_BANNER_PREDOMINANT_RELIGION", Game.GetReligion():GetName(religionDef.Index));
      else
        religionName = Game.GetReligion():GetName(religionDef.Index);
      end

      -- Add icon to main icon list
      -- If our only active religion is the same religion we're being converted to don't show an icon for it
      if numOfActiveReligions > 1 or nextReligion ~= religionInfo.Religion then
        local iconInst:table = iconIM:GetInstance();
        iconInst.ReligionIconButton:SetIcon(icon);
        iconInst.ReligionIconButton:SetColor(religionColor);
        iconInst.ReligionIconButtonBacking:SetColor(religionColor);
        iconInst.ReligionIconButtonBacking:SetToolTipString(religionName);
      end

      -- Add followers to detailed info list
      local followerListInst:table = followerListIM:GetInstance();
      followerListInst.ReligionFollowerIcon:SetIcon(icon);
      followerListInst.ReligionFollowerIcon:SetColor(religionColor);
      followerListInst.ReligionFollowerIconBacking:SetColor(religionColor);
      followerListInst.ReligionFollowerCount:SetText(religionInfo.Followers);
      followerListInst.ReligionFollowerPressure:SetText(Locale.Lookup("LOC_CITY_BANNER_RELIGIOUS_PRESSURE", Round(religionInfo.Pressure)));

      -- Add the follower tooltip to the population chart tooltip
      local followerTooltip:string = Locale.Lookup("LOC_CITY_BANNER_FOLLOWER_PRESSURE_TOOLTIP", religionName, religionInfo.Followers, Round(religionInfo.LifetimePressure));
      followerListInst.ReligionFollowerIconBacking:SetToolTipString(followerTooltip);
      populationChartTooltip = populationChartTooltip .. "[NEWLINE][NEWLINE]" .. followerTooltip;
    end

    religionInfo.ReligionPopChartContainer:SetToolTipString(populationChartTooltip);
  
    religionInfo.ReligionFollowerListStack:CalculateSize();
    religionInfo.ReligionFollowerListScrollPanel:CalculateInternalSize();
    religionInfo.ReligionFollowerListScrollPanel:ReprocessAnchoring();

    -- Add populations to pie chart in reverse order
    for i = #activeReligions, 1, -1 do
      local religionInfo = activeReligions[i];
      local religionColor = UI.GetColorValue(religionInfo.Color);

      local popChartInst:table = popChartIM:GetInstance();
      popChartInst.PopChartMeter:SetPercent(religionInfo.AccumulativeFillPercent);
      popChartInst.PopChartMeter:SetColor(religionColor);
    end

    -- Update population pie chart majority religion icon
    if (eMajorityReligion > 0) then
      local iconName : string = "ICON_" .. GameInfo.Religions[eMajorityReligion].ReligionType;
      religionInfo.ReligionPopChartIcon:SetIcon(iconName);
      religionInfo.ReligionPopChartIcon:SetHide(false);
    else
      religionInfo.ReligionPopChartIcon:SetHide(true);
    end

    -- Show how much religion this city is exerting outwards
    local outwardReligiousPressure = pCityReligion:GetPressureFromCity();
    religionInfo.ExertedReligiousPressure:SetText(Locale.Lookup("LOC_CITY_BANNER_RELIGIOUS_PRESSURE", Round(outwardReligiousPressure)));

    -- Reset buttons to default state
    religionInfo.ReligionInfoButton:SetHide(false);
    religionInfo.ReligionInfoDetailedButton:SetHide(true);

    -- Register callbacks to open/close detailed info
    religionInfo.ReligionInfoButton:RegisterCallback( Mouse.eLClick, function() OnReligionInfoButtonClicked(religionInfo, pCity); end);
    religionInfo.ReligionInfoDetailedButton:RegisterCallback( Mouse.eLClick, function() OnReligionInfoDetailedButtonClicked(religionInfo, pCity); end);

    religionInfo.ReligionInfoContainer:SetHide(false);
  end
end

-- ===========================================================================
function OnReligionInfoButtonClicked( religionInfoance:table, pCity:table )
  if (m_preligionInfoance ~= nil) then
    m_preligionInfoance.ReligionInfoButton:SetHide(false);
    m_preligionInfoance.ReligionInfoDetailedButton:SetHide(true);
  end

  religionInfoance.ReligionInfoButton:SetHide(true);
  religionInfoance.ReligionInfoDetailedButton:SetHide(false);
  UILens.FocusCity(m_HexColoringReligion, pCity);
  m_preligionInfoance = religionInfoance;
end

-- ===========================================================================
function OnReligionInfoDetailedButtonClicked( religionInfoance:table, pCity:table )
  UI.AssertMsg(m_preligionInfoance == religionInfoance, "more than one panel was open");
  religionInfoance.ReligionInfoButton:SetHide(false);
  religionInfoance.ReligionInfoDetailedButton:SetHide(true);
  UILens.UnFocusCity(m_HexColoringReligion, pCity);
  m_preligionInfoance = nil;
end

-- ===========================================================================
function SpawnHolySiteIconAtLocation( locX : number, locY:number, label:string )
  local iconInst:table = m_HolySiteIconsIM:GetInstance();

  local xOffset:number = -4;	--offset to center UI element on tile
  local yOffset:number = 4;	--offset to center UI element on tile
  local zOffset:number = 10;	--offset for 3D world view
  if (UI.GetWorldRenderView() == WorldRenderView.VIEW_2D) then
    zOffset = 0;
  end

  local worldX:number, worldY:number, worldZ:number = UI.GridToWorld( locX, locY );
  iconInst.Anchor:SetWorldPositionVal( worldX + xOffset, worldY + yOffset, worldZ + zOffset );
  iconInst.HolySiteLabel:SetText("[ICON_FaithLarge]"..label);
  iconInst.Anchor:SetSizeX(iconInst.HolySiteBacking:GetSizeX());

  iconInst.Anchor:SetToolTipString(Locale.Lookup("LOC_UI_RELIGION_HOLY_SITE_BONUS_TT", label));
end

-- ===========================================================================
function CityBanner:UpdateLoyalty()

  -- Always update the loyalty warning, even if the lens isnt active
  self:UpdateLoyaltyWarning();

  local instance:table = self.m_Instance.LoyaltyInfo;
  if instance then
    if not m_isLoyaltyLensActive then
      instance.Top:SetHide(true);
      return;
    end
    local pCity:table = self:GetCity();
    if pCity then
      local pCityCulturalIdentity:table = pCity:GetCulturalIdentity();
      if pCityCulturalIdentity then
        local ownerID:number = pCity:GetOwner();

        local playerIdentitiesInCity = pCityCulturalIdentity:GetPlayerIdentitiesInCity();
        local cityIdentityPressures = pCityCulturalIdentity:GetCityIdentityPressures();
        local identitySourcesBreakdown = pCityCulturalIdentity:GetIdentitySourcesBreakdown();

        -- Update owner icon
        local pOwnerConfig:table = PlayerConfigurations[ownerID];
        local ownerIcon:string = "ICON_" .. pOwnerConfig:GetCivilizationTypeName();
        local ownerSecondaryColor, ownerPrimaryColor = UI.GetPlayerColors( ownerID );
        local ownerCivIconTooltip:string = Locale.Lookup("LOC_LOYALTY_CITY_IS_LOYAL_TO_TT", pOwnerConfig:GetCivilizationDescription());
        instance.OwnerCivIcon:SetIcon(ownerIcon);
        instance.OwnerCivIcon:SetColor(ownerPrimaryColor);
        instance.OwnerCivIcon:SetToolTipString(ownerCivIconTooltip);
        instance.OwnerCivIconBacking:SetColor(ownerSecondaryColor);
        instance.OwnerCivIconExtended:SetIcon(ownerIcon);
        instance.OwnerCivIconExtended:SetColor(ownerPrimaryColor);
        instance.OwnerCivIconExtended:SetToolTipString(ownerCivIconTooltip);
        instance.OwnerCivIconBackingExtended:SetColor(ownerSecondaryColor);

        -- Update potential transfer player icon
        local transferPlayerID:number = pCityCulturalIdentity:GetPotentialTransferPlayer();
        if transferPlayerID ~= -1 then
          instance.TopCivIconBacking:SetHide(false);
          instance.TopCivIconBackingExtended:SetHide(false);

          local pTopConfig:table = PlayerConfigurations[transferPlayerID];
          local topIcon:string = "ICON_" .. pTopConfig:GetCivilizationTypeName();
          local topSecondaryColor, topPrimaryColor = UI.GetPlayerColors( transferPlayerID );
          local topCivIconTooltip:string = Locale.Lookup("LOC_LOYALTY_CITY_WILL_FALL_TO_TT", pTopConfig:GetCivilizationDescription());
          instance.TopCivIcon:SetIcon(topIcon);
          instance.TopCivIcon:SetColor(topPrimaryColor);
          instance.TopCivIcon:SetToolTipString(topCivIconTooltip);

          instance.TopCivIconBacking:SetColor(topSecondaryColor);
          instance.TopCivIconExtended:SetIcon(topIcon);
          instance.TopCivIconExtended:SetColor(topPrimaryColor);
          instance.TopCivIconBackingExtended:SetColor(topSecondaryColor);
          instance.TopCivIconExtended:SetToolTipString(topCivIconTooltip);
        else
          instance.TopCivIconBacking:SetHide(true);
          instance.TopCivIconBackingExtended:SetHide(false);
        end

        -- Determine which pressure font icon to use
        local loyaltyPerTurn:number = pCityCulturalIdentity:GetLoyaltyPerTurn();
        local loyaltyFontIcon:string = loyaltyPerTurn >= 0 and "[ICON_PressureUp]" or "[ICON_PressureDown]";

        -- Update loyalty precentage
        local currentLoyalty:number = pCityCulturalIdentity:GetLoyalty();
        local maxLoyalty:number = pCityCulturalIdentity:GetMaxLoyalty();
        local loyalPercent:number = currentLoyalty / maxLoyalty;
        instance.LoyaltyFill:SetPercent(loyalPercent);
        instance.LoyaltyFillExtended:SetPercent(loyalPercent);

        local loyalStatusTooltip:string = GetLoyaltyStatusTooltip(pCity);
        local loyaltyFillToolTip:string = Locale.Lookup("LOC_LOYALTY_STATUS_TT", loyaltyFontIcon, Round(currentLoyalty,1), maxLoyalty, loyalStatusTooltip);
        instance.LoyaltyFill:SetToolTipString(loyaltyFillToolTip);
        instance.LoyaltyFillExtended:SetToolTipString(loyaltyFillToolTip);

        -- Update loyalty percentage string
        local loyaltyText:string = Locale.Lookup("LOC_CULTURAL_IDENTITY_LOYALTY_PERCENTAGE", Round(currentLoyalty, 1), maxLoyalty, loyaltyFontIcon, Round(loyaltyPerTurn, 1));
        instance.LoyaltyPercentageLabel:SetText(loyaltyText);
        instance.LoyaltyPercentageLabel:SetToolTipString(loyaltyFillToolTip);
        instance.LoyaltyPressureIcon:SetText(loyaltyFontIcon);
        instance.LoyaltyPressureIcon:SetToolTipString(GetLoyaltyPressureIconTooltip(loyaltyPerTurn, ownerID));

        --Update Loyalty breakdown
        if self.m_LoyaltyBreakdownIM ~= nil then
          self.m_LoyaltyBreakdownIM:ResetInstances();

          --Populate the breakdown
          local localPlayerID = Game.GetLocalPlayer();
          local pCulturalIdentity = pCity:GetCulturalIdentity();
          local identitiesInCity = pCulturalIdentity:GetPlayerIdentitiesInCity();
          local firstIdentityInCity = next(identitiesInCity);
          if firstIdentityInCity == nil then
            --We have no presences, or we are the only one
            self.m_Instance.LoyaltyInfo.IdentityBreakdownStack:SetHide(true);
          else
            self.m_Instance.LoyaltyInfo.IdentityBreakdownStack:SetHide(false);
            table.sort(identitiesInCity, function(left, right)
              return left.IdentityTotal > right.IdentityTotal;
            end);

            local numInfluencers = 0;
            for i, playerPresence in ipairs(identitiesInCity) do
              if playerPresence.IdentityTotal ~= nil and playerPresence.IdentityTotal > 0 then
                if numInfluencers < 2 or playerPresence.Player == localPlayerID then
                  numInfluencers = numInfluencers + 1;
                  local instance = self.m_LoyaltyBreakdownIM:GetInstance();
                  local localPlayer = Players[localPlayerID];
                  local pPlayerConfig = PlayerConfigurations[playerPresence.Player];
                  local civName = Locale.Lookup(pPlayerConfig:GetCivilizationShortDescription());
                  local lineVal = (i == 1 and "[ICON_Bolt] " or "") .. Round(playerPresence.IdentityTotal, 1);
                  local hasBeenMet = localPlayer:GetDiplomacy():HasMet(playerPresence.Player) or localPlayerID == playerPresence.Player;
                  instance.LineTitle:SetText(hasBeenMet and civName or Locale.Lookup("LOC_LOYALTY_PANEL_UNMET_CIV"));
                  instance.LineValue:SetText(lineVal);

                  local civIconManager = CivilizationIcon:AttachInstance(instance.CivilizationIcon);
                  civIconManager:UpdateIconFromPlayerID(playerPresence.Player);
                end
              end
            end
          end
          self.m_Instance.LoyaltyInfo.MainStack:CalculateSize();
        end
        

        -- Update loyalty pressure breakdown
        instance.FreeCityTop:SetHide(true);
        instance.CityStateTop:SetHide(true);
        for i, pressure in ipairs(identitySourcesBreakdown) do
          if pressure[PRESSURE_BREAKDOWN_TYPE_POPULATION_PRESSURE] then
            SetPressureBreakdownColumn(instance.PopulationPressureValue, instance.PopulationPressureFontIcon, Round(pressure[PRESSURE_BREAKDOWN_TYPE_POPULATION_PRESSURE], 1));
            local tooltip:string = Locale.Lookup("LOC_CULTURAL_IDENTITY_POPULATION_PRESSURE_TOOLTIP");
            local ownerPlayer = Players[ownerID];
            if (ownerPlayer ~= nil) then
              if (ownerPlayer:IsMajor()) then
                tooltip = tooltip .. "[NEWLINE][NEWLINE]" .. Locale.Lookup("LOC_CULTURAL_IDENTITY_POPULATION_PRESSURE_TOOLTIP_MAJOR_CIVS");
              else
                tooltip = tooltip .. "[NEWLINE][NEWLINE]" .. Locale.Lookup("LOC_CULTURAL_IDENTITY_POPULATION_PRESSURE_TOOLTIP_MINOR_CIVS");
              end
            end
            instance.PopulationTop:SetToolTipString(tooltip);
          elseif pressure[PRESSURE_BREAKDOWN_TYPE_GOVERNORS] then
            SetPressureBreakdownColumn(instance.GovernorPressureValue, instance.GovernorPressureFontIcon, Round(pressure[PRESSURE_BREAKDOWN_TYPE_GOVERNORS], 1));
          elseif pressure[PRESSURE_BREAKDOWN_TYPE_HAPPINESS] then
            SetPressureBreakdownColumn(instance.HappinessPressureValue, instance.HappinessPressureFontIcon, Round(pressure[PRESSURE_BREAKDOWN_TYPE_HAPPINESS], 1));
          elseif pressure[PRESSURE_BREAKDOWN_TYPE_OTHER] then
            SetPressureBreakdownColumn(instance.OtherPressureValue, instance.OtherPressureFontIcon, Round(pressure[PRESSURE_BREAKDOWN_TYPE_OTHER], 1));
          elseif pressure[PRESSURE_BREAKDOWN_TYPE_CITY_STATE_BONUS] then
            SetPressureBreakdownColumn(instance.CityStatePressureValue, instance.CityStatePressureFontIcon, Round(pressure[PRESSURE_BREAKDOWN_TYPE_CITY_STATE_BONUS], 1));
            instance.CityStateTop:SetHide(false);
          elseif pressure[PRESSURE_BREAKDOWN_TYPE_FREE_CITY_BONUS] then
            SetPressureBreakdownColumn(instance.FreeCityPressureValue, instance.FreeCityPressureFontIcon, Round(pressure[PRESSURE_BREAKDOWN_TYPE_FREE_CITY_BONUS], 1));
            instance.FreeCityTop:SetHide(false);
          end
        end
        self.m_Instance.LoyaltyInfo.MainStack:CalculateSize();
        local newSizeY = self.m_Instance.LoyaltyInfo.MainStack:GetSizeY();
        self.m_Instance.LoyaltyInfo.CulturalIdentityExpandedButton:SetSizeY(newSizeY + 10);
        instance.Top:SetHide(false);
      end
    end
  end
end

function CityBanner:UpdateLoyaltyWarning()
  local pCity : table = self:GetCity();
  if (pCity == nil or self.m_Type ~= BANNERTYPE_CITY_CENTER) then
    return;
  end

  local pCulturalIdentity = pCity:GetCulturalIdentity();
  if (pCulturalIdentity ~= nil) then
    local eNextOwner = -1;
    if (self.m_IsCurrentlyVisible and not self.m_IsForceHide) then
      local nTurns:number = pCulturalIdentity:GetTurnsToConversion();
      local eOutcome:number = pCulturalIdentity:GetConversionOutcome();
      if (eOutcome == IdentityConversionOutcome.LOSING_LOYALTY and nTurns < 20) then
        eNextOwner = pCulturalIdentity:GetPotentialTransferPlayer();
      end
    end

    if (eNextOwner ~= self.m_eLoyaltyWarningPlayer) then
      local plot = Map.GetPlotIndex(self.m_PlotX, self.m_PlotY);

      -- clear the previous warning icon
      if (self.m_eLoyaltyWarningPlayer ~= -1) then
        UILens.ClearHex( m_LoyaltyFreeCityWarning, plot);
      end
        
      -- create the new warning icon
      if (eNextOwner ~= -1) then
        local eLocalPlayer : number = Game.GetLocalPlayer(); 
        local kPlayerType = PlayerConfigurations[eNextOwner]:GetCivilizationTypeName();
        local nSecondaryColor, nPrimaryColor = UI.GetPlayerColors(eNextOwner);
        local nIconColor = (kPlayerType == "CIVILIZATION_FREE_CITIES") and nPrimaryColor or nSecondaryColor;
        local kAssetName = "LoyaltyWarning_" .. kPlayerType;
        -- TODO the lens model system should be expanded so this and the loyalty lens icons can use both civ colors
        UILens.SetLayerHexesColoredArea( m_LoyaltyFreeCityWarning, eLocalPlayer, { plot }, nIconColor, kAssetName);
      end

      self.m_eLoyaltyWarningPlayer = eNextOwner;
    end
  end
end

-- ===========================================================================
function SetPressureBreakdownColumn(valueLabel:table, fontIconLabel:table, pressureValue:number)
  if pressureValue > 0 then
    valueLabel:SetText(Locale.Lookup("LOC_CULTURAL_IDENTITY_POSITIVE_PRESSURE", pressureValue));
    valueLabel:SetColorByName("White");
    fontIconLabel:SetText("[ICON_PressureUp]");
    fontIconLabel:SetHide(false);
  elseif pressureValue < 0 then
    valueLabel:SetText(pressureValue);
    valueLabel:SetColorByName("Red");
    fontIconLabel:SetText("[ICON_PressureDown]");
    fontIconLabel:SetHide(false);
  else
    valueLabel:SetText(Locale.Lookup("LOC_CULTURAL_IDENTITY_POSITIVE_PRESSURE", pressureValue));
    valueLabel:SetColorByName("Gray");
    fontIconLabel:SetHide(true);
  end
end

-- ===========================================================================
function CityBanner:UpdateSelected( state : boolean )
  local pCity : table = self:GetCity();
  if (pCity ~= nil) then
    UI.DeselectCity( pCity );
  end
end

-- ===========================================================================
function CityBanner:UpdatePosition()
  local yOffset = 0;  --offset for 2D strategic view
  local zOffset = 0;  --offset for 3D world view

  if (UI.GetWorldRenderView() == WorldRenderView.VIEW_2D) then
    yOffset = YOFFSET_2DVIEW;
  else
    zOffset = ZOFFSET_3DVIEW;
  end

  local worldX;
  local worldY;
  local worldZ;

  worldX, worldY, worldZ = UI.GridToWorld( self.m_PlotX, self.m_PlotY );
  self.m_Instance.Anchor:SetWorldPositionVal( worldX, worldY+yOffset, worldZ+zOffset );
end

-- ===========================================================================
function OnRefreshBannerPositions()
  --print("Refreshing banner positions");

  local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()];
  if (pLocalPlayerVis ~= nil) then
    local players = Game.GetPlayers();
    for i, player in ipairs(players) do
      local playerID = player:GetID();
      local playerCities = players[i]:GetCities();
      for ii, city in playerCities:Members() do
        local cityID    :number = city:GetID();
        local locX      :number = city:GetX();
        local locY      :number = city:GetY();
        local isVisChange :boolean = false;

        if pLocalPlayerVis:IsVisible(locX, locY) then
          OnCityVisibilityChanged(playerID, cityID, PLOT_VISIBLE);
          isVisChange = true;
        elseif pLocalPlayerVis:IsRevealed(locX, locY) then
          OnCityVisibilityChanged(playerID, cityID, PLOT_REVEALED);
          isVisChange = true;
        end

        local bannerInstance = GetCityBanner( playerID, cityID );
        if (bannerInstance ~= nil) then
          bannerInstance:UpdatePosition( bannerInstance );
        end
      end
      local playerDistricts = players[i]:GetDistricts();
      for ii, district in playerDistricts:Members() do
        local districtID = district:GetID();
        local locX = district:GetX();
        local locY = district:GetY();
        if (pLocalPlayerVis:IsVisible(locX, locY) == true) then
          OnDistrictVisibilityChanged(playerID, districtID, PLOT_VISIBLE);
          local miniBanner:table = GetMiniBanner( playerID, districtID );
          if (miniBanner ~= nil) then
            miniBanner:UpdatePosition();
          end
        end
      end
    end
  end
end

-- ===========================================================================
function CanRangeAttack(pCityOrDistrict : table)

  -- An invalid plot means we want to know if there are any locations that the city can range strike.

  return CityManager.CanStartCommand( pCityOrDistrict, CityCommandTypes.RANGE_ATTACK );
end

-- ===========================================================================
function CityBanner:UpdateRangeStrike()

  local controls:table = self.m_Instance;
  if controls.CityStrike == nil then
    -- This normal behaviour in the case of missile silo and aerodrome minibanners
    return;
  end

  local pDistrict:table = self:GetDistrict();
  if pDistrict ~= nil and self:IsTeam() then
    if (self.m_Player:GetID() == Game.GetLocalPlayer() and CanRangeAttack(pDistrict) ) then
      controls.CityStrike:SetHide(false);
    else
      controls.CityStrike:SetHide(true);
    end

    -- Notify other systems if the local players button changed
    if (self.m_Player:GetID() == Game.GetLocalPlayer()) then
      local iPlotX = pDistrict:GetX();
      local iPlotY = pDistrict:GetY();
      LuaEvents.CityBannerManager_UpdateRangeStrike(iPlotX, iPlotY);
    end
  else
    -- are we looking at an Improvement miniBanner (Airstrip)?
    -- if so, just hide the attack container
    controls.CityStrike:SetHide(true);
  end
end

-- ===========================================================================
function OnCityStrikeButtonClick( playerID, cityID )
  local pPlayer = Players[playerID];
  if (pPlayer == nil) then
    return;
  end

  local pCity = pPlayer:GetCities():FindID(cityID);
  if (pCity == nil) then
    return;
  end;
  -- AZURENCY : Enter the range city mode on click (not on hover of a button, the old workaround)
  LuaEvents.CQUI_Strike_Enter();
  -- AZURENCY : Allow to switch between different city range attack (clicking on the range button of one
  -- city and after on the range button of another city, without having to ESC or right click)
  UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
  --ARISTOS: fix for the range strike not showing odds window
  UI.DeselectAll();
  UI.SelectCity( pCity );
  UI.SetInterfaceMode(InterfaceModeTypes.CITY_RANGE_ATTACK);

end

LuaEvents.CQUI_CityRangeStrike.Add( OnCityStrikeButtonClick ); -- AZURENCY : to acces it in the actionpannel on the city range attack button

-- ===========================================================================
function OnDistrictRangeStrikeButtonClick( playerID, districtID )
  local pPlayer = Players[playerID];
  if (pPlayer == nil) then
    return;
  end

  local pDistrict = pPlayer:GetDistricts():FindID(districtID);
  if (pDistrict == nil) then
    return;
  end;

  UI.DeselectAll();
  UI.SelectDistrict(pDistrict);
  UI.SetInterfaceMode(InterfaceModeTypes.DISTRICT_RANGE_ATTACK);
end

LuaEvents.CQUI_DistrictRangeStrike.Add( OnDistrictRangeStrikeButtonClick ); -- AZURENCY : to acces it in the actionpannel on the district range attack button


-- ===========================================================================
function OnICBMStrikeButtonClick( iPlotID, eWMD )
  local pPlot = Map.GetPlotByIndex(iPlotID);
  if (pPlot ~= nil) then
    local pCity = Cities.GetPlotPurchaseCity(pPlot);
    if (pCity ~= nil) then
      -- force recalculation of reachable area if we're already in strike mode
      if UI.GetInterfaceMode() == InterfaceModeTypes.ICBM_STRIKE then
        UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
      end
      UI.SelectCity(pCity);
      UILens.SetActive("Default");
      local tParameters = {};
      tParameters[CityCommandTypes.PARAM_WMD_TYPE] = eWMD;
      tParameters[CityCommandTypes.PARAM_X0] = pPlot:GetX();
      tParameters[CityCommandTypes.PARAM_Y0] = pPlot:GetY();
      UI.SetInterfaceMode(InterfaceModeTypes.ICBM_STRIKE, tParameters);
    end
  end
end

-- ===========================================================================
function AddCityBannerToMap( playerID: number, cityID : number )
  local idLocalPlayer :number = Game.GetLocalPlayer();
  local pPlayer   :table  = Players[playerID];

  local pCity = pPlayer:GetCities():FindID(cityID);
  if (pCity ~= nil) then
    local idDistrict = pCity:GetDistrictID();
    if (idLocalPlayer == playerID) then
      return CityBanner:new( playerID, cityID, idDistrict, BANNERTYPE_CITY_CENTER, BANNERSTYLE_LOCAL_TEAM );
    else
      return CityBanner:new( playerID, cityID, idDistrict, BANNERTYPE_CITY_CENTER, BANNERSTYLE_OTHER_TEAM );
    end
  end
end

-- ===========================================================================
function DestroyCityBanner( playerID: number, cityID : number )
  local cityBanner:table = GetCityBanner( playerID, cityID );
  if (cityBanner ~= nil) then
    cityBanner:destroy();
    CityBannerInstances[ playerID ][ cityID ] = nil;
  end	
end

-- ===========================================================================
function AddMiniBannerToMap( playerID: number, cityID: number, districtID: number, styleEnum:number )
  local idLocalPlayer :number = Game.GetLocalPlayer();
  local pPlayer   :table  = Players[playerID];

  if (idLocalPlayer == playerID) then
    return CityBanner:new( playerID, cityID, districtID, styleEnum, BANNERSTYLE_LOCAL_TEAM );
  else
    return CityBanner:new( playerID, cityID, districtID, styleEnum, BANNERSTYLE_OTHER_TEAM );
  end
end

-- ===========================================================================
function OnCityAddedToMap( playerID: number, cityID : number, cityX : number, cityY : number )
  if (CityBannerInstances[ playerID ] ~= nil and
      CityBannerInstances[ playerID ][ cityID ] ~= nil) then
      return;
    end
  AddCityBannerToMap( playerID, cityID );
end

-- ===========================================================================
function OnDistrictAddedToMap( playerID: number, districtID : number, cityID :number, districtX : number, districtY : number, districtType:number, percentComplete:number )

  local locX = districtX;
  local locY = districtY;
  local type = districtType;

  local pPlayer = Players[playerID];
  if (pPlayer ~= nil) then
    local pDistrict = pPlayer:GetDistricts():FindID(districtID);
    if (pDistrict ~= nil) then
      local pCity = pDistrict:GetCity();
      local cityID = pCity:GetID();
      -- It is possible that the city is not there yet. e.g. city-center district is placed, the city is placed immediately afterward.
      if (pCity ~= nil) then
        -- Is the district at the city? i.e. its a city-center?
        if (pCity:GetX() == pDistrict:GetX() and pCity:GetY() == pDistrict:GetY()) then
          -- Yes, just update the city banner with the district ID.
          local cityBanner:table = GetCityBanner( playerID, pCity:GetID() );
          if cityBanner then
            cityBanner.m_DistrictID = districtID;
            cityBanner:UpdateRangeStrike();
            cityBanner:UpdateStats();
            cityBanner:UpdateColor();
          end
        else
          -- Create a banner for a district that is not the city-center
          local miniBanner:table = GetMiniBanner( playerID, districtID );
          if (miniBanner == nil) then
            if (pDistrict:IsComplete()) then
              if (GameInfo.Districts[pDistrict:GetType()].AirSlots > 0) then
                if pDistrict:IsComplete() then
                  AddMiniBannerToMap( playerID, cityID, districtID, BANNERTYPE_AERODROME );
                end
              elseif (pDistrict:GetDefenseStrength() > 0) then
                if pDistrict:IsComplete() then
                  AddMiniBannerToMap( playerID, cityID, districtID, BANNERTYPE_ENCAMPMENT );
                end
              else
                AddMiniBannerToMap( playerID, cityID, districtID, BANNERTYPE_OTHER_DISTRICT );
              end

              -- CQUI update city's real housing from improvements when completed a district that triggers a Culture Bomb
              if playerID == Game.GetLocalPlayer() then
                if districtType == GameInfo.Districts["DISTRICT_ENCAMPMENT"].Index then
                  if PlayerConfigurations[playerID]:GetCivilizationTypeName() == "CIVILIZATION_POLAND" then
                    CQUI_OnCityInfoUpdated(playerID, cityID);
                  end
                elseif districtType == GameInfo.Districts["DISTRICT_HOLY_SITE"].Index or districtType == GameInfo.Districts["DISTRICT_LAVRA"].Index then
                  if PlayerConfigurations[playerID]:GetCivilizationTypeName() == "CIVILIZATION_KHMER" then
                    CQUI_OnCityInfoUpdated(playerID, cityID);
                  else
                    local playerReligion :table = pPlayer:GetReligion();
                    local playerReligionType :number = playerReligion:GetReligionTypeCreated();
                    if playerReligionType ~= -1 then
                      local cityReligion :table = pCity:GetReligion();
                      local eDominantReligion :number = cityReligion:GetMajorityReligion();
                      if eDominantReligion == playerReligionType then
                        local pGameReligion :table = Game.GetReligion();
                        local pAllReligions :table = pGameReligion:GetReligions();
                        for _, kFoundReligion in ipairs(pAllReligions) do
                          if kFoundReligion.Religion == eDominantReligion then
                            for _, belief in pairs(kFoundReligion.Beliefs) do
                              if GameInfo.Beliefs[belief].BeliefType == "BELIEF_BURIAL_GROUNDS" then
                                CQUI_OnCityInfoUpdated(playerID, cityID);
                                break;
                              end
                            end
                            break;
                          end
                        end
                      end
                    end
                  end
                elseif districtType == GameInfo.Districts["DISTRICT_HARBOR"].Index then
                  if PlayerConfigurations[playerID]:GetCivilizationTypeName() == "CIVILIZATION_NETHERLANDS" then
                    CQUI_OnCityInfoUpdated(playerID, cityID);
                  end
                elseif districtType == GameInfo.Districts["DISTRICT_INDUSTRIAL_ZONE"].Index or districtType == GameInfo.Districts["DISTRICT_HANSA"].Index then
                  local pGreatPeople :table  = Game.GetGreatPeople();
                  local pTimeline :table = pGreatPeople:GetPastTimeline();
                  for _, kPerson in ipairs(pTimeline) do
                    if GameInfo.GreatPersonIndividuals[kPerson.Individual].GreatPersonIndividualType == "GREAT_PERSON_INDIVIDUAL_MIMAR_SINAN" then
                      if playerID == kPerson.Claimant then
                        CQUI_OnCityInfoUpdated(playerID, cityID);
                      end
                      break;
                    end
                  end
                end
              end
            end
          else
            miniBanner:UpdateStats();
          end
        end
      end
    end
  end

end

-- ===========================================================================
function OnImprovementAddedToMap(locX, locY, eImprovementType, eOwner)

  if eImprovementType == -1 then
    UI.DataError("Received -1 eImprovementType for ("..tostring(locX)..","..tostring(locY)..") and owner "..tostring(eOwner));
    return;
  end

  local improvementData:table = GameInfo.Improvements[eImprovementType];

  if improvementData == nil then
    UI.DataError("No database entry for eImprovementType #"..tostring(eImprovementType).." for ("..tostring(locX)..","..tostring(locY)..") and owner "..tostring(eOwner));
    return;
  end

  -- CQUI update city's real housing from improvements when built an improvement that triggers a Culture Bomb
  if eOwner == Game.GetLocalPlayer() then
    if improvementData.ImprovementType == "IMPROVEMENT_FORT" then
      if PlayerConfigurations[eOwner]:GetCivilizationTypeName() == "CIVILIZATION_POLAND" then
        local ownerCity = Cities.GetPlotPurchaseCity(locX, locY);
        local cityID = ownerCity:GetID();
        CQUI_OnCityInfoUpdated(eOwner, cityID);
      end
    end
  end

  if ( improvementData.AirSlots == 0 and improvementData.WeaponSlots == 0 and improvementData.ImprovementType ~= "IMPROVEMENT_MOUNTAIN_TUNNEL" and improvementData.ImprovementType ~= "IMPROVEMENT_MOUNTAIN_ROAD" ) then
    return;
  end

  local pPlayer:table = Players[eOwner];
  local localPlayerID:number = Game.GetLocalPlayer();
  if (pPlayer ~= nil) then
    local plotID = Map.GetPlotIndex(locX, locY);
    if (plotID ~= nil) then
      local miniBanner = GetMiniBanner( eOwner, plotID );
      if (miniBanner == nil) then
        if ( improvementData.AirSlots > 0 ) then
          --we're passing -1 as the cityID and the plotID as the districtID argument since Airstrips aren't associated with a city or a district
          AddMiniBannerToMap( eOwner, -1, plotID, BANNERTYPE_AERODROME );
        elseif ( improvementData.WeaponSlots > 0 ) then
          local ownerCity = Cities.GetPlotPurchaseCity(locX, locY);
          local cityID = ownerCity:GetID();
          -- we're passing the plotID as the districtID argument because we need the location of the improvement
          AddMiniBannerToMap( eOwner, cityID, plotID, BANNERTYPE_MISSILE_SILO );
        elseif ( improvementData.ImprovementType == "IMPROVEMENT_MOUNTAIN_TUNNEL" ) then
          AddMiniBannerToMap( eOwner, -1, plotID, BANNERTYPE_MOUNTAIN_TUNNEL );
        elseif ( improvementData.ImprovementType == "IMPROVEMENT_MOUNTAIN_ROAD" ) then
          AddMiniBannerToMap( eOwner, -1, plotID, BANNERTYPE_QHAPAQ_NAN);
        end
      else
        miniBanner:UpdateStats();
        miniBanner:UpdateColor();
      end
    end
  end
end

-- ===========================================================================
function OnDistrictProgressChanged(playerID: number, districtID : number, districtX : number, districtY : number, districtType:number, percentComplete:number)
  local pPlayer = Players[playerID];
  if (pPlayer ~= nil) then
    local pDistrict = pPlayer:GetDistricts():FindID(districtID);
    if (pDistrict ~= nil) then

    end
  end
end

-- ===========================================================================
function OnCityRemovedFromMap( playerID: number, cityID : number )
  DestroyCityBanner(playerID, cityID);
end

-- ===========================================================================
function OnDistrictRemovedFromMap( playerID : number, districtID : number )
  local bannerInstance = GetMiniBanner(playerID, districtID);
  if (bannerInstance ~= nil) then
    bannerInstance:destroy();
    MiniBannerInstances[playerID][districtID] = nil;
  end
end

-- ===========================================================================
function OnImprovementRemovedFromMap( locX :number, locY :number, eOwner :number )
  local plotID = Map.GetPlotIndex(locX, locY);
  if (plotID > 0) then
    local bannerInstance = GetMiniBanner( eOwner, plotID );
    if (bannerInstance ~= nil) then
      bannerInstance:destroy();
      MiniBannerInstances[eOwner][plotID] = nil;
    end
  end
end

-- ===========================================================================
function OnCityVisibilityChanged( playerID: number, cityID : number, eVisibility : number)
  local bannerInstance:table = GetCityBanner( playerID, cityID );
  if bannerInstance then
    bannerInstance:SetFogState( eVisibility );
  end
end

-- ===========================================================================
function OnCityOccupationChanged( playerID: number, cityID : number )
  RefreshBanner( playerID, cityID );
end

-- ===========================================================================
function OnCityPopulationChanged( playerID: number, cityID : number )
  RefreshBanner( playerID, cityID );
end

-- ===========================================================================
function OnDistrictVisibilityChanged( playerID :number, districtID :number, eVisibility :number )
  local bannerInstance = GetMiniBanner( playerID, districtID );
  if (bannerInstance ~= nil) then
    bannerInstance:SetFogState( eVisibility );
  end
end

-- ===========================================================================
function OnImprovementVisibilityChanged( locX :number, locY :number, eImprovementType :number, eVisibility :number )
  if ( eImprovementType == -1 ) then
    return;
  end
  local data:table = GameInfo.Improvements[eImprovementType];
  -- We're only interested in the Airstrip or Missile Silo improvements
  if (data.ImprovementType == "IMPROVEMENT_MOUNTAIN_TUNNEL" or data.ImprovementType == "IMPROVEMENT_MOUNTAIN_ROAD" or data.AirSlots > 0 or data.WeaponSlots > 0) then
    local plotID = Map.GetPlotIndex(locX, locY);
    if (plotID > 0) then
      local plot = Map.GetPlotByIndex(plotID);
      if (plot ~= nil) then
        local x = plot:GetX();
        local y = plot:GetY();
        local playerID = plot:GetImprovementOwner();
        local bannerInstance = GetMiniBanner( playerID, plotID );
        if (bannerInstance ~= nil) then
          bannerInstance:SetFogState( eVisibility );
        end
      end
    end
  end
end

-- ===========================================================================
function OnBuildingChanged( plotX:number, plotY:number, buildingIndex:number, playerID:number, cityID:number, iPercentComplete:number)
  
  local pPlayer = Players[playerID];
  if (pPlayer ~= nil and pPlayer:GetCities() ~= nil) then
    
    -- Update the capital, since for now capital status is shown in name
    local pCapital = pPlayer:GetCities():GetCapitalCity();
    if (pCapital ~= nil) then
      local cityBanner:table = GetCityBanner( playerID, pCapital:GetID() );
      if cityBanner then
        cityBanner:UpdateName();
      end
    end

    -- Update the city defenses UI if walls were constructed
    if (playerID == Game.GetLocalPlayer()) then
      local pCity = CityManager.GetCityAt(plotX, plotY);
      if (pCity ~= nil) then
        local cityBanner:table = GetCityBanner( playerID, pCity:GetID() );
        if cityBanner then
          cityBanner:UpdateRangeStrike();
        end
      end
    end
  end

end

-- ===========================================================================
function OnCityNameChange( playerID: number, cityID : number)

  local banner:table = GetCityBanner( playerID, cityID );
  if (banner ~= nil ) then
    banner:UpdateName();   
  end

end

-- ===========================================================================
function OnCapitalCityChanged( playerID: number, cityID : number )
  -- Ensure not in autoplay
  if Game.GetLocalPlayer() < 0 then
    return;
  end

  local banner:table = GetCityBanner( playerID, cityID );
  if (banner ~= nil ) then
    banner:UpdateName();   
  end
end

-- ===========================================================================
function OnCityReligionChanged( playerID: number, cityID : number, eVisibility : number, city)

  -- Ensure not in autoplay
  if Game.GetLocalPlayer() < 0 then
    return;
  end

  local banner:table = GetCityBanner( playerID, cityID );
  if (banner ~= nil and banner.m_Instance.ReligionInfo ~= nil and banner:IsVisible()) then
    banner:UpdateReligion();   -- For now religion is shown in name
  end
end

-- ===========================================================================
function OnQuestChanged( fromPlayerID:number, toPlayerID:number)

  -- Update the capital of the player the quest is from
  local pFromPlayer = Players[fromPlayerID];
  if (pFromPlayer ~= nil and pFromPlayer:GetCities() ~= nil) then
    local pCapital = pFromPlayer:GetCities():GetCapitalCity();
    if (pCapital ~= nil) then
      local bannerInstance = GetCityBanner( fromPlayerID, pCapital:GetID() );
      if (bannerInstance ~= nil) then
        bannerInstance:UpdateName();
        bannerInstance:UpdateDetails();
      end
    end
  end
end

-- ===========================================================================
function OnDistrictCombatChanged(eventSubType, playerID, districtID)
  local pPlayer = Players[ playerID ];
  if (pPlayer ~= nil) then
    local pDistrict = pPlayer:GetDistricts():FindID(districtID);
    if (pDistrict ~= nil) then
      local pCity = pDistrict:GetCity();
      local banner = GetCityBanner(playerID, pCity:GetID());
      if (banner ~= nil) then
        banner:UpdateRangeStrike();
        banner:UpdateStats();
      end

      local miniBanner = GetMiniBanner(playerID, districtID);
      if (miniBanner ~= nil) then
        miniBanner:UpdateRangeStrike();
        miniBanner:UpdateStats();
      end
    end
    end
end

-- ===========================================================================
function OnCityDefenseStatusChanged(playerID, iValue)
  local pPlayer = Players[ playerID ];
  if (pPlayer ~= nil) then
    local pPlayerDistricts:table = pPlayer:GetDistricts();
    for _, district in pPlayerDistricts:Members() do
      local pCity = district:GetCity();
      local districtID = district:GetID();
      if (district:GetX() == pCity:GetX() and district:GetY() == pCity:GetY()) then
        local banner = GetCityBanner(playerID, pCity:GetID());
        if (banner ~= nil) then
          banner:UpdateRangeStrike();
          banner:UpdateStats();
        end
      else
        local miniBanner = GetMiniBanner(playerID, districtID);
        if (miniBanner ~= nil) then
          miniBanner:UpdateRangeStrike();
          miniBanner:UpdateStats();
        end
      end
    end
  end
end

-- ===========================================================================
function OnDistrictDamageChanged( playerID:number, districtID:number, damageType:number, newDamage:number, oldDamage:number)
  local pPlayer = Players[ playerID ];
  if (pPlayer ~= nil) then
    local pDistrict = pPlayer:GetDistricts():FindID(districtID);
    if (pDistrict ~= nil) then
      local pCity = pDistrict:GetCity();
      if (pDistrict:GetX() == pCity:GetX() and pDistrict:GetY() == pCity:GetY()) then
        local banner = GetCityBanner(playerID, pCity:GetID());
        if (banner ~= nil) then
          banner:UpdateStats();
        end
      else
        local miniBanner = GetMiniBanner(playerID, districtID);
        if (miniBanner ~= nil) then
          miniBanner:UpdateStats();
        end
      end

      -- Add the world space text to show the delta for the damage.
      -- Can the local team see the plot where the district is?
      local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()];
      if (pLocalPlayerVis ~= nil) then
        if (pLocalPlayerVis:IsVisible(pDistrict:GetX(), pDistrict:GetY())) then

          local iDelta = newDamage - oldDamage;
          local szText;

          if (damageType == DefenseTypes.DISTRICT_GARRISON) then
            if (iDelta < 0) then
              szText = Locale.Lookup("LOC_WORLD_DISTRICT_GARRISON_DAMAGE_DECREASE_FLOATER", -iDelta);
            else
              szText = Locale.Lookup("LOC_WORLD_DISTRICT_GARRISON_DAMAGE_INCREASE_FLOATER", -iDelta);
            end
          elseif (damageType == DefenseTypes.DISTRICT_OUTER) then
            if (iDelta < 0) then
              szText = Locale.Lookup("LOC_WORLD_DISTRICT_DEFENSE_DAMAGE_DECREASE_FLOATER", -iDelta);
            else
              szText = Locale.Lookup("LOC_WORLD_DISTRICT_DEFENSE_DAMAGE_INCREASE_FLOATER", -iDelta);
            end
          end


          UI.AddWorldViewText(EventSubTypes.DAMAGE, szText, pDistrict:GetX(), pDistrict:GetY(), 0);
        end
      end
    end
  end
  -- print("A District has been damaged");
  -- print(playerID, districtID, outerDamage, garrisonDamage);
end

-- ===========================================================================
function OnDistrictPillaged(playerID : number, districtID : number, cityID : number, x : number, y : number, district_type : number, percent_complete : number, is_pillaged : number)

  UpdateDistrictStats( playerID, districtID );

end

-- ===========================================================================
-- Update the stats of a district and its parent city
function UpdateDistrictStats(playerID : number, districtID : number)
  local pPlayer = Players[ playerID ];
  if (pPlayer ~= nil) then
    local pDistrict = pPlayer:GetDistricts():FindID(districtID);
    if (pDistrict ~= nil) then
      local pCity = pDistrict:GetCity();
      if pCity ~= nil then
        -- Update the stats on the parent city banner
        local banner = GetCityBanner(playerID, pCity:GetID());
        if (banner ~= nil) then
          banner:UpdateStats();
        end

        -- And if the district has its own banner, update it too.
        if (pDistrict:GetX() ~= pCity:GetX() or pDistrict:GetY() ~= pCity:GetY()) then
          local miniBanner = GetMiniBanner(playerID, districtID);
          if (miniBanner ~= nil) then
            miniBanner:UpdateStats();
          end
        end
      end
    end
  end
end

-- ===========================================================================
function UpdateStats( playerID:number, cityID:number )
  if (playerID == Game.GetLocalPlayer()) then
    local pPlayer = Players[ playerID ];
    if (pPlayer ~= nil) then
      local pCity = pPlayer:GetCities():FindID(cityID);
      if (pCity ~= nil) then
        local banner = GetCityBanner(playerID, cityID);
        if (banner ~= nil) then
          banner:UpdateStats();
        end
      end
      -- Update minibanners associated with the given city
      local playerMiniBannerInstances = MiniBannerInstances[ playerID ];
      if (playerMiniBannerInstances ~= nil) then
        for id, banner in pairs(playerMiniBannerInstances) do
          if (banner ~= nil and banner.m_CityID == cityID) then
            banner:UpdateStats();
          end
        end
      end
    end
  end
end

-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnCityFocusChange( playerID:number, cityID:number )
  UpdateStats( playerID, cityID );
end

-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnCityProductionChanged( playerID:number, cityID:number)
  UpdateStats( playerID, cityID );
end

-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnCityProductionUpdate( playerID:number, cityID:number)
  UpdateStats( playerID, cityID );
end

-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnCityProductionCompleted( playerID:number, cityID:number)
  UpdateStats( playerID, cityID );
end


-- ===========================================================================
--  Update stats and button to attack on banners
-- ===========================================================================
function RefreshPlayerBanners( playerID:number )
  if playerID == -1 then return; end

  local pPlayer = Players[ playerID ];
  if (pPlayer ~= nil) then

    if (CityBannerInstances[ playerID ] == nil) then
      return;
    end
    local playerCityBannerInstances = CityBannerInstances[ playerID ];
    for id, banner in pairs(playerCityBannerInstances) do
      if (banner ~= nil) then
        banner:UpdateStats();
        banner:UpdateRangeStrike();
      end
    end

    if (MiniBannerInstances[ playerID ] == nil) then
      return;
    end
    local playerMiniBannerInstances = MiniBannerInstances[ playerID ];
    for id, banner in pairs(playerMiniBannerInstances) do
      if (banner ~= nil) then
        banner:UpdateStats();
        banner:UpdateRangeStrike();
      end
    end
  end

end

-- ===========================================================================
function RefreshPlayerProduction( playerID:number )
  if playerID == -1 then return; end

  local pPlayer = Players[ playerID ];
  if (pPlayer ~= nil) then

    if (CityBannerInstances[ playerID ] == nil) then
      return;
    end
    local playerCityBannerInstances = CityBannerInstances[ playerID ];
    for id, banner in pairs(playerCityBannerInstances) do
      if (banner ~= nil) then
        banner:UpdateProduction(banner:GetCity());
      end
    end
  end
end

-- ===========================================================================
function RefreshPlayerRangeStrike( playerID:number )
  if playerID == -1 then return; end

  local pPlayer = Players[ playerID ];
  if (pPlayer ~= nil) then

    if (CityBannerInstances[ playerID ] == nil) then
      return;
    end
    local playerCityBannerInstances = CityBannerInstances[ playerID ];
    for id, banner in pairs(playerCityBannerInstances) do
      if (banner ~= nil) then
        banner:UpdateRangeStrike();
      end
    end

    if (MiniBannerInstances[ playerID ] == nil) then
      return;
    end
    local playerMiniBannerInstances = MiniBannerInstances[ playerID ];
    for id, banner in pairs(playerMiniBannerInstances) do
      if (banner ~= nil) then
        banner:UpdateRangeStrike();
      end
    end
  end

end

-- ===========================================================================
function RefreshBanner( playerID:number, cityID:number )
  local banner = GetCityBanner(playerID, cityID);
  if (banner ~= nil) then
    banner:UpdateStats();
    banner:UpdateRangeStrike();
    banner:UpdateName();
  end
end

-- ===========================================================================
function RefreshMiniBanner( playerID:number, districtID:number )
  local banner = GetMiniBanner(playerID, districtID);
  if (banner ~= nil) then
    banner:UpdateStats();
    banner:UpdateRangeStrike();
  end
end

-- ===========================================================================
function OnCityUnitsChanged( playerID:number, cityID:number )
  if playerID == Game.GetLocalPlayer() then
    RefreshBanner( playerID, cityID );
  end
end

-- ===========================================================================
function OnDistrictUnitsChanged( playerID:number, districtID:number )
  if playerID == Game.GetLocalPlayer() then
    RefreshMiniBanner( playerID, districtID );
  end
end

-- ===========================================================================
function OnSiegeStatusChanged( playerID:number, cityID:number, bIsBesieged:boolean )
  if (playerID == -1) then
    return;
  end

  RefreshBanner( playerID, cityID );
end

-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnUnitMoved( playerID:number, unitID:number )
  local localPlayer = Game.GetLocalPlayer();
  if localPlayer ~= -1 and localPlayer ~= playerID and Players[localPlayer]:IsTurnActive() then
    m_refreshLocalPlayerRangeStrike = true;
  end
end

function FlushChanges()
  if m_refreshLocalPlayerRangeStrike then
    RefreshPlayerRangeStrike( Game.GetLocalPlayer() );
    m_refreshLocalPlayerRangeStrike = false;
  end
  if m_refreshLocalPlayerProduction then
    RefreshPlayerProduction( Game.GetLocalPlayer() );
    m_refreshLocalPlayerProduction = false;
  end
end

-- ===========================================================================
function OnUnitAddedOrUpgraded( playerID:number, unitID:number )
  -- Update city and district garrison strength values if a melee unit has been added or upgraded.
  -- This is done because the base city strength is calculated using the max melee strength for the player.
  local localPlayer = Game.GetLocalPlayer();
  if localPlayer == -1 or Players[localPlayer]:IsTurnActive() then -- Don't do this during end turn times
    local pUnit = Players[ playerID ]:GetUnits():FindID(unitID);
    if pUnit ~= nil then
      local pUnitDef = GameInfo.Units[pUnit:GetUnitType()];
      if pUnitDef ~= nil then
        if pUnitDef.Combat > 0 then -- Only do this for melee units
          RefreshPlayerBanners( playerID );
        end
      end
    end
  end
end

-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnUnitAddedToMap( playerID:number, unitID:number )
  OnUnitMoved( playerID, unitID );
  OnUnitAddedOrUpgraded( playerID, unitID );
end

-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnUnitRemovedFromMap( playerID:number, unitID:number )
  OnUnitMoved( playerID, unitID );
end

-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnUnitUpgraded( playerID:number, unitID:number )
  OnUnitAddedOrUpgraded( playerID, unitID );
end

-- ===========================================================================
--  Game Event
-- ===========================================================================
function OnDiplomacyDeclareWar( firstPlayerID:number, secondPlayerID:number )
  local localPlayer = Game.GetLocalPlayer();
  if firstPlayerID == localPlayer or secondPlayerID == localPlayer then
    m_refreshLocalPlayerRangeStrike = true;
    m_refreshLocalPlayerProduction = true;
  end
end

-- ===========================================================================
--  Game Event
-- ===========================================================================
function OnDiplomacyMakePeace( firstPlayerID:number, secondPlayerID:number )
  local localPlayer = Game.GetLocalPlayer();
  if firstPlayerID == localPlayer or secondPlayerID == localPlayer then
    m_refreshLocalPlayerRangeStrike = true;
    m_refreshLocalPlayerProduction = true;
  end
end

-- ===========================================================================
function OnWMDCountChanged( playerID:number, eWMD:number )
  local pPlayer = Players[ playerID ];
  if (pPlayer ~= nil) then
    if (MiniBannerInstances[ playerID ] == nil) then
      return;
    end
    local playerMiniBannerInstances = MiniBannerInstances[ playerID ];
    for id, banner in pairs(playerMiniBannerInstances) do
      if (banner ~= nil) then
        banner:UpdateStats();
      end
    end
  end
end

-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnTurnActivated( playerID:number )
  local pPlayer = Players[ playerID ];
  if (pPlayer ~= nil) then

    local playerBannerInstances = CityBannerInstances[ playerID ];
    if (playerBannerInstances ~= nil) then
      for id, banner in pairs(playerBannerInstances) do
        if (banner ~= nil) then
          banner:UpdateStats();
        end
      end
    end

    local playerMiniBannerInstances = MiniBannerInstances[ playerID ];
    if (playerMiniBannerInstances ~= nil) then
      for id, banner in pairs(playerMiniBannerInstances) do
        if (banner ~= nil) then
          banner:UpdateStats();
        end
      end
    end
  end
end

-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnPolicyChanged( playerID:number )
  RefreshPlayerBanners( playerID );
end

function OnPlayerAgeChanged ( playerID:number )
  local pPlayer = Players[ playerID ];
  if (pPlayer ~= nil and pPlayer:IsHuman() == true) then
    RefreshPlayerBanners( playerID );
  end
end

-- ===========================================================================
function OnSpyMissionCompleted( playerID:number, missionID:number )
  -- When a spy mission completes update governors of cities with spies in case they've been neutralized
  local pPlayer:table = Players[playerID];
  if pPlayer then
    local pPlayerUnits:table = pPlayer:GetUnits();
    for i, unit in pPlayerUnits:Members() do
      local unitInfo:table = GameInfo.Units[unit:GetUnitType()];
      if unitInfo.Spy then
        local pCity = CityManager.GetCityAt(unit:GetX(), unit:GetY());
        if pCity ~= nil then
          local cityBanner:table = GetCityBanner(pCity:GetOwner(), pCity:GetID());
          if cityBanner then
            cityBanner:UpdateGovernor(pCity);
          end
        end
      end
    end
  end
end

-- ===========================================================================
--  Reload all the content
-- ===========================================================================
function Reload()

  local pLocalPlayerVis:table = PlayersVisibility[Game.GetLocalPlayer()];
  if pLocalPlayerVis ~= nil then
    local players = Game.GetPlayers();
    for i, player in ipairs(players) do
      local playerID    :number = player:GetID();
      local pPlayerCities :table = players[i]:GetCities();

      for _, city in pPlayerCities:Members() do
        local cityID:number = city:GetID();
        local locX  :number = city:GetX();
        local locY  :number = city:GetY();
        OnCityAddedToMap( playerID, cityID, locX, locY );
        if (pLocalPlayerVis:IsVisible(locX, locY) == true) then
          OnCityVisibilityChanged(playerID, cityID, PLOT_VISIBLE);
        end
        RefreshBanner(playerID, cityID) -- CQUI : refresh the banner info
      end

      local pPlayerDistricts:table = players[i]:GetDistricts();
      for _, district in pPlayerDistricts:Members() do
        local districtID = district:GetID();
        local locX = district:GetX();
        local locY = district:GetY();
        OnDistrictAddedToMap( playerID, districtID, locX, locY );
        if (pLocalPlayerVis:IsVisible(locX, locY) == true) then
          OnDistrictVisibilityChanged(playerID, districtID, PLOT_VISIBLE);
        end
      end

      local pPlayerImprovements = players[i]:GetImprovements();
      if (pPlayerImprovements ~= nil) then
        local tImprovementLocations:table = pPlayerImprovements:GetImprovementPlots();
        for _, plotID in ipairs(tImprovementLocations) do
          local pPlot = Map.GetPlotByIndex(plotID);
          if (pPlot ~= nil) then
            local eImprovement = pPlot:GetImprovementType();
            if (eImprovement >= 0) then
              local locX = pPlot:GetX();
              local locY = pPlot:GetY();
              OnImprovementAddedToMap(locX, locY, eImprovement, playerID);
              if (pLocalPlayerVis:IsVisible(locX, locY) == true) then
                OnImprovementVisibilityChanged(locX, locY, eImprovement, PLOT_VISIBLE);
              end
            end
          end
        end
      end
    end
  end
end

-- ===========================================================================
function OnEventPlaybackComplete()

  for playerID, cityID in m_pDirtyCityComponents:Members() do
    local banner = GetCityBanner(playerID, cityID);
    if (banner ~= nil) then
      banner:UpdateStats();
    end
  end

  m_pDirtyCityComponents:Clear();
end

----------------------------------------------------------------
function OnLocalPlayerChanged( localPlayerID:number , prevLocalPlayerID:number )

  -- Hide all the flags, we will get updates later
  for _, playerBannerInstances in pairs(CityBannerInstances) do
    for id, banner in pairs(playerBannerInstances) do
      if (banner ~= nil) then
        banner:SetHide(true);
      end
    end
    end

  for _, playerBannerInstances in pairs(MiniBannerInstances) do
    for id, banner in pairs(playerBannerInstances) do
      if (banner ~= nil) then
        banner:SetHide(true);
      end
    end
  end

  --  Rebuild all city banner instances in the context of the new local player.
  for iPlayer,kCityBanners in pairs(CityBannerInstances) do
    for iCity,kCityBanner in pairs(kCityBanners) do
      DestroyCityBanner( iPlayer, iCity );
      AddCityBannerToMap( iPlayer, iCity );
    end
  end

  for iPlayer,kMiniBanners in pairs(MiniBannerInstances) do
    for iMini,kMiniBanner in pairs(kMiniBanners) do
      local districtID:number = kMiniBanner.m_DistrictID;
      local typeID  :number = kMiniBanner.m_Type;
      local cityID	:number = kMiniBanner.m_CityID;
      kMiniBanner:destroy();
      AddMiniBannerToMap( iPlayer, cityID, districtID, typeID );
    end
  end

end

-- ===========================================================================
--  Game Engine EVENT
-- ===========================================================================
function OnCityWorkerChanged(ownerPlayerID:number, cityID:number)
  if (Game.GetLocalPlayer() == ownerPlayerID) then
    RefreshBanner( ownerPlayerID, cityID )
  end
end

function OnPlayerTurnActivated(player, isFirstTimeThisTurn)
  -- PlayerTurnActivated is post DoTurn processing for the beginning of the turn.
  if (isFirstTimeThisTurn and Game.GetLocalPlayer() == player) then
    OnRefreshBannerPositions();           -- Ensure visibility is correctly set.
    RefreshPlayerBanners( player );
  end
end

-- ===========================================================================
function OnObjectPairingChanged(eSubType, parentOwner, parentType, parentID, childOwner, childType, childID)
  local pPlayer = Players[ parentOwner ];
  if (pPlayer ~= nil) then

    local bannerInstance = GetCityBanner( parentOwner, parentID );
    if (bannerInstance ~= nil) then
      bannerInstance:UpdateStats( bannerInstance );
    end

    local miniBannerInstance = GetMiniBanner( parentOwner, parentID );
    if (miniBannerInstance ~= nil) then
      miniBannerInstance:UpdateStats( miniBannerInstance );
    end

  end
end

-- ===========================================================================
function RegisterDirtyEvents()
  m_pDirtyCityComponents = DirtyComponentsManager.Create();
  m_pDirtyCityComponents:AddEvent("CITY_POPULATION_CHANGED");
  m_pDirtyCityComponents:AddEvent("CITY_RELIGION_CHANGED");
end

-- ===========================================================================
function RealizeReligion()
  
  m_HolySiteIconsIM:ResetInstances();
  -- Only clear the religion lens if we're turning off lenses altogether, but not if switching to another modal lens. (Turning on another modal lens clears it already)
  if UI.GetInterfaceMode() ~= InterfaceModeTypes.VIEW_MODAL_LENS then
    UILens.ClearLayerHexes( m_HexColoringReligion );
  end
  
  for _, playerBannerInstances in pairs(CityBannerInstances) do
    for id, banner in pairs(playerBannerInstances) do
      if (banner ~= nil and banner.m_Instance.ReligionInfo ~= nil and banner:IsVisible()) then
        banner:UpdateReligion();
        banner:UpdatePosition();
      end
    end
  end

  local bReligionsVisible = UILens.IsLayerOn( m_HexColoringReligion );
end

-- ===========================================================================
function RealizeLoyalty()
  for _, playerBannerInstances in pairs(CityBannerInstances) do
    for id, banner in pairs(playerBannerInstances) do
      if (banner ~= nil and banner.m_Instance.LoyaltyInfo and banner:IsVisible()) then
        banner:UpdateInfo(banner:GetCity());
        banner:UpdateLoyalty();
        banner:UpdatePosition();
      end
    end
  end
end

-- ===========================================================================
function ShowDistrictBanners()
  for iPlayer,kMiniBanners in pairs(MiniBannerInstances) do
    for iMini,kMiniBanner in pairs(kMiniBanners) do
      if kMiniBanner.m_Type == BANNERTYPE_OTHER_DISTRICT and kMiniBanner.m_FogState ~= PLOT_HIDDEN then
        kMiniBanner.m_IsForceHide = false;
        kMiniBanner:SetHide(false);
      end
    end
  end
end

-- ===========================================================================
function HideDistrictBanners()
  for iPlayer,kMiniBanners in pairs(MiniBannerInstances) do
    for iMini,kMiniBanner in pairs(kMiniBanners) do
      if kMiniBanner.m_Type == BANNERTYPE_OTHER_DISTRICT then
        kMiniBanner.m_IsForceHide = true;
        kMiniBanner:SetHide(true);
      end
    end
  end
end

-- ===========================================================================
function OnContextInitialize( isHotload : boolean )
  if isHotload then
    LuaEvents.GameDebug_GetValues( "CityBannerManager" );
    Reload();
  end
end

-- ===========================================================================
--  Handle the UI shutting down.
function OnShutdown()
  -- Cache value for hotloading...
  LuaEvents.GameDebug_AddValue("CityBannerManager", "m_isLoyaltyLensActive", m_isLoyaltyLensActive);
  LuaEvents.GameDebug_AddValue("CityBannerManager", "m_isReligionLensActive", m_isReligionLensActive);

  -- CQUI values
  LuaEvents.GameDebug_AddValue("CityBannerManager", "CQUI_HousingFromImprovementsTable", CQUI_HousingFromImprovementsTable);
  LuaEvents.GameDebug_AddValue("CityBannerManager", "CQUI_HousingUpdated", CQUI_HousingUpdated);

  DirtyComponentsManager.Destroy( m_pDirtyCityComponents );
  m_pDirtyCityComponents = nil;
  CQUI_PlotIM:DestroyInstances();
end

-- ===========================================================================
--	LUA Event
--	Set cached values back after a hotload.
-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
  if context == "CityBannerManager" then
    m_isLoyaltyLensActive = contextTable["m_isLoyaltyLensActive"];
    m_isReligionLensActive = contextTable["m_isReligionLensActive"];

    -- CQUI cached values
    CQUI_HousingFromImprovementsTable = contextTable["CQUI_HousingFromImprovementsTable"]
    CQUI_HousingUpdated = contextTable["CQUI_HousingUpdated"]
    -- CQUI settings
    CQUI_OnSettingsUpdate()

    RealizeReligion();
    RealizeLoyalty();
  end
end

-- ===========================================================================
function OnBeginWonderReveal()
  ContextPtr:SetHide( true );
end

-- ===========================================================================
function OnEndWonderReveal()
  ContextPtr:SetHide( false );
end

-- ===========================================================================
--  Gamecore Event
--  Called once per layer that is turned on when a new lens is activated,
--  or when a player explicitly turns off the layer from the "player" lens.
-- ===========================================================================
function OnLensLayerOn( layerNum:number )
  if layerNum == m_HexColoringReligion then
    m_isReligionLensActive = true;
    RealizeReligion();
  elseif layerNum == m_CulturalIdentityLens then
    m_isLoyaltyLensActive = true;
    RealizeLoyalty();
  elseif layerNum == m_CityDetailsLens then
    ShowDistrictBanners();
  elseif layerNum == m_EmpireDetailsLens then
    ShowDistrictBanners();
  end
end

-- ===========================================================================
--	Gamecore Event
--	Called once per layer that is turned on when a new lens is deactivated,
--	or when a player explicitly turns off the layer from the "player" lens.
-- ===========================================================================
function OnLensLayerOff( layerNum:number )
  if	layerNum == m_HexColoringReligion then
    m_isReligionLensActive = false;
    RealizeReligion();
  elseif layerNum == m_CulturalIdentityLens then
    m_isLoyaltyLensActive = false;
    RealizeLoyalty();
  elseif layerNum == m_CityDetailsLens then
    HideDistrictBanners();
  elseif layerNum == m_EmpireDetailsLens then
    HideDistrictBanners();
  end
end

-- ===========================================================================
function OnSelectionChanged(owner, ID, i, j, k, bSelected, bEditable)
  banner = GetCityBanner(owner, ID);
  -- OnSelectionChanged event can only change one banner at a time
  if banner and owner == Game.GetLocalPlayer() then
    banner.m_IsSelected = bSelected;
    banner:UpdateColor();
  end
end

-- ===========================================================================
function CQUI_OnInfluenceGiven()
  for i, pPlayer in ipairs(PlayerManager.GetAliveMinors()) do
    local iPlayer = pPlayer:GetID();
    -- AZURENCY : check if there's a CapitalCity
    if pPlayer:GetCities():GetCapitalCity() ~= nil then
      local iCapital = pPlayer:GetCities():GetCapitalCity():GetID();
      local bannerInstance = GetCityBanner(iPlayer, iCapital);
      CQUI_UpdateSuzerainIcon(pPlayer, bannerInstance);
    end
  end
end

function CQUI_UpdateSuzerainIcon( pPlayer:table, bannerInstance )
  if bannerInstance == nil then
    return;
  end

  local pPlayerInfluence :table  = pPlayer:GetInfluence();
  local suzerainID       :number = pPlayerInfluence:GetSuzerain();
  if suzerainID ~= -1 then
    local pPlayerConfig :table  = PlayerConfigurations[suzerainID];
    local leader        :string = pPlayerConfig:GetLeaderTypeName();
    if GameInfo.CivilizationLeaders[leader] == nil then
      UI.DataError("Banners found a leader \""..leader.."\" which is not/no longer in the game; icon may be whack.");
    else
      local suzerainTooltip = Locale.Lookup("LOC_CITY_STATES_SUZERAIN_LIST") .. " ";
      if pPlayer:GetDiplomacy():HasMet(suzerainID) then
        bannerInstance.m_Instance.CQUI_CivSuzerainIcon:SetIcon("ICON_" .. leader);
        if(suzerainID == Game.GetLocalPlayer()) then
          bannerInstance.m_Instance.CQUI_CivSuzerainIcon:SetToolTipString(suzerainTooltip .. Locale.Lookup("LOC_CITY_STATES_YOU"));
        else
          bannerInstance.m_Instance.CQUI_CivSuzerainIcon:SetToolTipString(suzerainTooltip .. Locale.Lookup(pPlayerConfig:GetPlayerName()));
        end
      else
        bannerInstance.m_Instance.CQUI_CivSuzerainIcon:SetIcon("ICON_LEADER_DEFAULT");
        bannerInstance.m_Instance.CQUI_CivSuzerainIcon:SetToolTipString(suzerainTooltip .. Locale.Lookup("LOC_DIPLOPANEL_UNMET_PLAYER"));
      end
      bannerInstance:Resize();
      bannerInstance.m_Instance.CQUI_CivSuzerain:SetOffsetX(bannerInstance.m_Instance.ContentStack:GetSizeX()/2 - 5);
      bannerInstance.m_Instance.CQUI_CivSuzerain:SetHide(false);
    end
  else
    bannerInstance.m_Instance.CQUI_CivSuzerain:SetHide(true);
  end
end

-- ===========================================================================
function OnInterfaceModeChanged( oldMode:number, newMode:number )
  if newMode == InterfaceModeTypes.MAKE_TRADE_ROUTE or oldMode == InterfaceModeTypes.MAKE_TRADE_ROUTE then

    m_isTradeSelectionActive = newMode == InterfaceModeTypes.MAKE_TRADE_ROUTE;

    -- Show trading post icons on cities that contain a trading post with the local player
    for _, playerBannerInstances in pairs(CityBannerInstances) do
      for id, banner in pairs(playerBannerInstances) do
        if banner ~= nil then
          banner:UpdateDetails();
        end
      end
    end
  end

  if (newMode == InterfaceModeTypes.DISTRICT_PLACEMENT) then
    CQUI_CityManageAreaShown = false
    CQUI_CityManageAreaShouldShow = false
  end
end

-- ===========================================================================
function OnCityLoyaltyChanged( playerID: number, cityID: number )
  local cityBanner:table = GetCityBanner(playerID, cityID);
  if cityBanner then
    cityBanner:UpdateInfo(cityBanner:GetCity());
    cityBanner:UpdateLoyalty();
  end
end

-- ===========================================================================
function OnCulturalIdentityConversionOutcomeChanged( playerID: number, cityID: number, conversionOutcome:number )
  local cityBanner:table = GetCityBanner(playerID, cityID);
  if cityBanner then
    cityBanner:UpdateInfo(cityBanner:GetCity());
    cityBanner:UpdateLoyalty();
  end
end

-- ===========================================================================
function OnGovernorChanged( playerID: number, governorID: number )
  local pPlayer = Players[playerID];
  local pGovernors = pPlayer:GetGovernors();
  local pGovernor = pGovernors:GetGovernor(GameInfo.Governors[governorID].Hash);

  if pGovernor then
    local pCity:table = pGovernor:GetAssignedCity();
    if pCity then
      local cityBanner:table = GetCityBanner(pCity:GetOwner(), pCity:GetID());
      if cityBanner then
        cityBanner:UpdateStats();
        cityBanner:UpdateLoyalty();
      end
    end
  end
end

-- ===========================================================================
function OnGovernorAssigned( playerID: number, governorID: number, cityOwner: number, cityID: number )
  local cityBanner:table = GetCityBanner(cityOwner, cityID);
  for _, playerBannerInstances in pairs(CityBannerInstances) do
    for id, banner in pairs(playerBannerInstances) do
      if (banner ~= nil and banner:IsVisible()) then
        banner:UpdateStats();
        banner:UpdateLoyalty();
      end
    end
  end
end

-- ===========================================================================
function OnGovernorEjected( cityOwner: number, cityID: number, playerID: number, governorID: number )
  local cityBanner:table = GetCityBanner(cityOwner, cityID);
  if (cityBanner ~= nil) then
		cityBanner:UpdateStats();
		cityBanner:UpdateLoyalty();
	end
end

-- ===========================================================================
-- CQUI calculate real housing from improvements
function CQUI_RealHousingFromImprovements(pCity, PlayerID, pCityID)
  -- CQUI: There is a bug that shares housing from improvements for cities with the same IDs. So this bug is also added to the mod and will be removed after it will be fixed by developers.
  local x, y = pCity:GetX(), pCity:GetY();
  local CQUI_ID_BuggedTable = {};
  for i = -3, 3 do
    if i ~= 0 then
      table.insert( CQUI_ID_BuggedTable, Map.GetPlot(x + i, y) );
    end
    if i ~= 3 then
      table.insert( CQUI_ID_BuggedTable, Map.GetPlot(x + y % 2 + i, y + 1) );
      table.insert( CQUI_ID_BuggedTable, Map.GetPlot(x + y % 2 + i, y - 1) );
    end
    if i ~= -3 and i ~= 3 then
      table.insert( CQUI_ID_BuggedTable, Map.GetPlot(x + i, y + 2) );
      table.insert( CQUI_ID_BuggedTable, Map.GetPlot(x + i, y - 2) );
    end
    if i ~= -3 and i <=1 then
      table.insert( CQUI_ID_BuggedTable, Map.GetPlot(x + y % 2 + i, y + 3) );
      table.insert( CQUI_ID_BuggedTable, Map.GetPlot(x + y % 2 + i, y - 3) );
    end
  end

  local CQUI_HousingFromImprovements = 0;
  for _, kPlot in pairs(CQUI_ID_BuggedTable) do
    local kPlotCity = Cities.GetPlotPurchaseCity(kPlot);
    local kPlotCityID;
    if kPlotCity ~= nil then
      kPlotCityID = kPlotCity:GetID();
    end
    if kPlotCityID == pCityID then
      local eImprovementType :number = kPlot:GetImprovementType();
      if eImprovementType ~= -1 then
        if not kPlot:IsImprovementPillaged() then
          local kImprovementData = GameInfo.Improvements[eImprovementType].Housing;
          if kImprovementData == 1 then    -- Farms, Fishing Boats, Pastures, Plantations, Camps
            CQUI_HousingFromImprovements = CQUI_HousingFromImprovements + 1;
          elseif kImprovementData == 2 then    -- Stepwells, Kampungs, Mekewaps, Cahokia Mounds
            if GameInfo.Improvements[eImprovementType].ImprovementType == "IMPROVEMENT_STEPWELL" then    -- Stepwells
              local CQUI_PlayerResearchedSanitation :boolean = Players[Game.GetLocalPlayer()]:GetTechs():HasTech(GameInfo.Technologies["TECH_SANITATION"].Index);    -- check if a player researched Sanitation
              if not CQUI_PlayerResearchedSanitation then
                CQUI_HousingFromImprovements = CQUI_HousingFromImprovements + 2;
              else
                CQUI_HousingFromImprovements = CQUI_HousingFromImprovements + 4;
              end
            elseif GameInfo.Improvements[eImprovementType].ImprovementType == "IMPROVEMENT_KAMPUNG" then    -- Kampungs
              local CQUI_PlayerResearchedMassProduction :boolean = Players[Game.GetLocalPlayer()]:GetTechs():HasTech(GameInfo.Technologies["TECH_MASS_PRODUCTION"].Index);    -- check if a player researched Mass Production
              if not CQUI_PlayerResearchedMassProduction then
                CQUI_HousingFromImprovements = CQUI_HousingFromImprovements + 2;
              else
                CQUI_HousingFromImprovements = CQUI_HousingFromImprovements + 4;
              end
            elseif GameInfo.Improvements[eImprovementType].ImprovementType == "IMPROVEMENT_MEKEWAP" then    -- Mekewaps
              local CQUI_PlayerResearchedCivilService :boolean = Players[Game.GetLocalPlayer()]:GetCulture():HasCivic(GameInfo.Civics["CIVIC_CIVIL_SERVICE"].Index);    -- check if a player researched Civil Service
              if not CQUI_PlayerResearchedCivilService then
                CQUI_HousingFromImprovements = CQUI_HousingFromImprovements + 2;
              else
                CQUI_HousingFromImprovements = CQUI_HousingFromImprovements + 4;
              end
            else    -- Cahokia Mounds (elseif GameInfo.Improvements[eImprovementType].ImprovementType == "IMPROVEMENT_MOUND" then)
              local CQUI_PlayerResearchedCivilService :boolean = Players[Game.GetLocalPlayer()]:GetCulture():HasCivic(GameInfo.Civics["CIVIC_CULTURAL_HERITAGE"].Index);    -- check if a player researched Cultural Heritage
              if not CQUI_PlayerResearchedCivilService then
                CQUI_HousingFromImprovements = CQUI_HousingFromImprovements + 2;
              else
                CQUI_HousingFromImprovements = CQUI_HousingFromImprovements + 4;
              end
            end
          elseif kImprovementData == 4 then    -- Seasteads
            CQUI_HousingFromImprovements = CQUI_HousingFromImprovements + 4;
          elseif GameInfo.Improvements[eImprovementType].ImprovementType == "IMPROVEMENT_GOLF_COURSE" then    -- Golf Courses (kImprovementData == 0)
            local CQUI_PlayerResearchedGlobalization :boolean = Players[Game.GetLocalPlayer()]:GetCulture():HasCivic(GameInfo.Civics["CIVIC_GLOBALIZATION"].Index);    -- check if a player researched Globalization
            if CQUI_PlayerResearchedGlobalization then
              CQUI_HousingFromImprovements = CQUI_HousingFromImprovements + 2;
            end
          end
        end
      end
    end
  end
  CQUI_HousingFromImprovements = CQUI_HousingFromImprovements * 0.5;
  if CQUI_HousingFromImprovementsTable[PlayerID] == nil then
    CQUI_HousingFromImprovementsTable[PlayerID] = {};
  end
  if CQUI_HousingUpdated[PlayerID] == nil then
    CQUI_HousingUpdated[PlayerID] = {};
  end
  CQUI_HousingFromImprovementsTable[PlayerID][pCityID] = CQUI_HousingFromImprovements;
  CQUI_HousingUpdated[PlayerID][pCityID] = true;
  LuaEvents.CQUI_RealHousingFromImprovementsCalculated(pCityID, CQUI_HousingFromImprovements);
end

-- ===========================================================================
-- CQUI update city's real housing from improvements
function CQUI_OnCityInfoUpdated(PlayerID, pCityID)
  CQUI_HousingUpdated[PlayerID][pCityID] = nil;
end

-- ===========================================================================
-- CQUI update all cities real housing from improvements
function CQUI_OnAllCitiesInfoUpdated(PlayerID)
  local m_pCity:table = Players[PlayerID]:GetCities();
  for i, pCity in m_pCity:Members() do
    local pCityID = pCity:GetID();
    CQUI_OnCityInfoUpdated(PlayerID, pCityID)
  end
end

-- ===========================================================================
-- CQUI update close to a culture bomb cities data and real housing from improvements
function CQUI_OnCityLostTileToCultureBomb(PlayerID, x, y)
  local m_pCity:table = Players[PlayerID]:GetCities();
  for i, pCity in m_pCity:Members() do
    if Map.GetPlotDistance( pCity:GetX(), pCity:GetY(), x, y ) <= 4 then
      local pCityID = pCity:GetID();
      CQUI_OnCityInfoUpdated(PlayerID, pCityID)
      CityManager.RequestCommand(pCity, CityCommandTypes.SET_FOCUS, nil);
    end
  end
end

-- ===========================================================================
-- CQUI erase real housing from improvements data everywhere when a city removed from map
function CQUI_OnCityRemovedFromMap(PlayerID, pCityID)
  if playerID == Game.GetLocalPlayer() then
    CQUI_HousingFromImprovementsTable[PlayerID][pCityID] = nil;
    CQUI_HousingUpdated[PlayerID][pCityID] = nil;
    LuaEvents.CQUI_RealHousingFromImprovementsCalculated(pCityID, nil);
  end
end

-- ===========================================================================
function Initialize()

  print("Initialize CQUI CityBanner Expansion 1")

  RegisterDirtyEvents();

  ContextPtr:SetInitHandler( OnContextInitialize );
  ContextPtr:SetShutdown( OnShutdown );

  Events.BeginWonderReveal.Add(       OnBeginWonderReveal );
  Events.BuildingChanged.Add(         OnBuildingChanged);
  Events.CapitalCityChanged.Add(        OnCapitalCityChanged);
  Events.CityAddedToMap.Add(          OnCityAddedToMap );
  Events.CityDefenseStatusChanged.Add(    OnCityDefenseStatusChanged );
  Events.CityFocusChanged.Add(        OnCityFocusChange );
  Events.CityNameChanged.Add(         OnCityNameChange );
  Events.CityProductionQueueChanged.Add(OnCityProductionChanged);
  Events.CityProductionUpdated.Add(     OnCityProductionUpdate);
  Events.CityProductionCompleted.Add(     OnCityProductionCompleted);
  Events.CityReligionChanged.Add(       OnCityReligionChanged );
  Events.CityReligionFollowersChanged.Add(  OnCityReligionChanged );
  Events.CityRemovedFromMap.Add(        OnCityRemovedFromMap );
  Events.CitySelectionChanged.Add(      OnSelectionChanged );
  Events.CityUnitsChanged.Add(                OnCityUnitsChanged );
  Events.CityVisibilityChanged.Add(     OnCityVisibilityChanged );
  Events.CityOccupationChanged.Add(     OnCityOccupationChanged );
  Events.CityPopulationChanged.Add(			OnCityPopulationChanged );
  Events.DiplomacyDeclareWar.Add(       OnDiplomacyDeclareWar );
  Events.DiplomacyMakePeace.Add(        OnDiplomacyMakePeace );
  Events.DistrictAddedToMap.Add(        OnDistrictAddedToMap );
  Events.DistrictBuildProgressChanged.Add(  OnDistrictAddedToMap);
  --Events.DistrictBuildProgressChanged.Add(  OnDistrictProgressChanged);
  Events.DistrictCombatChanged.Add(     OnDistrictCombatChanged );
  Events.DistrictDamageChanged.Add(     OnDistrictDamageChanged );
  Events.DistrictPillaged.Add(          OnDistrictPillaged );
  Events.DistrictRemovedFromMap.Add(      OnDistrictRemovedFromMap );
  Events.DistrictUnitsChanged.Add(      OnDistrictUnitsChanged );
  Events.DistrictVisibilityChanged.Add(   OnDistrictVisibilityChanged );
  Events.EndWonderReveal.Add(         OnEndWonderReveal );
  Events.GameCoreEventPlaybackComplete.Add( OnEventPlaybackComplete);
  Events.ImprovementAddedToMap.Add(     OnImprovementAddedToMap );
  Events.ImprovementRemovedFromMap.Add(   OnImprovementRemovedFromMap );
  Events.ImprovementVisibilityChanged.Add(  OnImprovementVisibilityChanged );
  Events.InterfaceModeChanged.Add(      OnInterfaceModeChanged );
  Events.LensLayerOff.Add(          OnLensLayerOff );
  Events.LensLayerOn.Add(           OnLensLayerOn );
  Events.LocalPlayerChanged.Add(        OnLocalPlayerChanged);
  Events.PlayerTurnActivated.Add(       OnPlayerTurnActivated);
  Events.ObjectPairing.Add(         OnObjectPairingChanged);
  Events.QuestChanged.Add(          OnQuestChanged );
  Events.UnitAddedToMap.Add(          OnUnitAddedToMap );
  Events.UnitMoved.Add(           OnUnitMoved );
  Events.UnitRemovedFromMap.Add(        OnUnitRemovedFromMap );
  Events.UnitUpgraded.Add(          OnUnitUpgraded );
  Events.UnitVisibilityChanged.Add( OnUnitMoved );
  Events.WorldRenderViewChanged.Add(      OnRefreshBannerPositions);
  Events.WMDCountChanged.Add(         OnWMDCountChanged);
  Events.PlayerTurnActivated.Add(             OnTurnActivated);
  Events.GovernmentPolicyChanged.Add(         OnPolicyChanged );
  Events.GovernmentPolicyObsoleted.Add(       OnPolicyChanged );
  Events.SpyMissionCompleted.Add(				OnSpyMissionCompleted );
  Events.PlayerAgeChanged.Add(         OnPlayerAgeChanged );
  Events.PlayerDarkAgeChanged.Add(       OnPlayerAgeChanged );
  Events.CitySiegeStatusChanged.Add(      OnSiegeStatusChanged);
  Events.GameCoreEventPublishComplete.Add(	FlushChanges); --This event is raised directly after a series of gamecore events.
  Events.CityWorkerChanged.Add(           OnCityWorkerChanged );

  -- Expansion1 related events
  Events.GovernorChanged.Add(         OnGovernorChanged);
  Events.GovernorAssigned.Add(        OnGovernorAssigned);
  Events.GovernorPromoted.Add(        OnGovernorChanged);
  Events.GovernorEjected.Add(         OnGovernorEjected);
  Events.CityLoyaltyChanged.Add(      OnCityLoyaltyChanged);
  Events.CulturalIdentityConversionOutcomeChanged.Add( OnCulturalIdentityConversionOutcomeChanged);

  LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);

  -- CQUI related events
  LuaEvents.CQUI_CityInfoUpdated.Add( CQUI_OnCityInfoUpdated );    -- CQUI update city's real housing from improvements
  LuaEvents.CQUI_AllCitiesInfoUpdated.Add( CQUI_OnAllCitiesInfoUpdated );    -- CQUI update all cities real housing from improvements
  LuaEvents.CQUI_CityLostTileToCultureBomb.Add( CQUI_OnCityLostTileToCultureBomb );    -- CQUI update close to a culture bomb cities data and real housing from improvements
  Events.CityRemovedFromMap.Add( CQUI_OnCityRemovedFromMap );    -- CQUI erase real housing from improvements data everywhere when a city removed from map
  LuaEvents.CQUI_SettingsInitialized.Add( CQUI_OnSettingsInitialized );
  Events.CitySelectionChanged.Add( CQUI_OnBannerMouseExit );
  Events.InfluenceGiven.Add( CQUI_OnInfluenceGiven );
end
Initialize();
