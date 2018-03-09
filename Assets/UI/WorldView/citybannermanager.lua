-- ===========================================================================
--  City Banner Manager
-- ===========================================================================

include( "InstanceManager" );
include( "SupportFunctions" );
include( "Civ6Common" );

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

local DATA_FIELD_RELIGION_FOLLOWERS_IM :string = "m_FollowersIM";
local DATA_FIELD_RELIGION_METERS_IM :string = "m_MetersIM";
local DATA_FIELD_RELIGION_PRESSURE_CHANGES :string = "m_PressureChanges";
local DATA_FIELD_RELIGION_PREV_FILL_PERCENT :string = "m_FillPercent";
local DATA_FIELD_RELIGION_ICONS_IM :string = "m_IconsIM";
local DATA_FIELD_RELIGION_FOLLOWER_LIST_IM :string = "m_FollowerListIM";
local DATA_FIELD_RELIGION_POP_CHART_IM :string = "m_PopChartIM";
local DATA_FIELD_RELIGION_INFO_INSTANCE :string = "m_ReligionInfoInst";

local RELIGION_POP_CHART_TOOLTIP_HEADER		:string = Locale.Lookup("LOC_CITY_BANNER_FOLLOWER_PRESSURE_TOOLTIP_HEADER");

local OFFSET_RELIGION_BANNER  :number = 25;
local ICON_HOLY_SITE      :string = "Faith";
local ICON_PRESSURE_DOWN    :string = "PressureDown";
local ICON_PRESSURE_UP      :string = "PressureUp";
local MINIMUM_BANNER_WIDTH    :number = 196;
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
local ZOOM_MULT_DELTA     :number = .01;
local ALPHA_DIM         :number = 0.45;

local m_pDirtyCityComponents  :table = {};
local m_pReligionInfoInstance   :table = nil; -- tracks the most recently opened religion detail panel
local m_isReligionLensActive  :boolean = false;
local m_refreshLocalPlayerRangeStrike:boolean = false;

-- CQUI real housing from improvements tables
local CQUI_HousingFromImprovementsTable :table = {};
local CQUI_HousingUpdated :table = {};

-- The meta table definition that holds the function pointers
hstructure CityBannerMeta
  -- Pointer back to itself.  Required.
  __index             : CityBannerMeta

  new               : ifunction;
  destroy             : ifunction;
  Initialize            : ifunction;
  IsVisible           : ifunction;
  IsTeam              : ifunction;
  GetCity             : ifunction;
  GetDistrict           : ifunction;
  GetImprovementInfo        : ifunction;
  SetColor            : ifunction;
  SetFogState           : ifunction;
  SetHide             : ifunction;
  UpdateVisibility        : ifunction;
  UpdateSelected          : ifunction;
  UpdateName            : ifunction;
  UpdatePosition          : ifunction;
  UpdateRangeStrike       : ifunction;
  UpdateReligion          : ifunction;
  UpdateStats           : ifunction;
  Resize              : ifunction;
  SetHealthBarColor       : ifunction;
  CreateAerodromeBanner     :ifunction;
  UpdateAerodromeBanner     :ifunction;
  CreateWMDBanner         :ifunction;
  UpdateWMDBanner         :ifunction;
  CreateEncampmentBanner      :ifunction;
  UpdateEncampmentBanner      :ifunction;
end

-- The structure that holds the banner instance data
hstructure CityBanner
  meta                    : CityBannerMeta;

  m_InstanceManager       : table;           -- The instance manager that made the control set.
  m_Instance              : table;           -- The instanced control set.

  m_Type                  : number;          -- Full, mini, etc...
  m_Style                 : number;          -- Team or other
  m_IsSelected            : boolean;
  m_IsCurrentlyVisible    : boolean;
  m_IsForceHide           : boolean;
  m_IsDimmed              : boolean;
  m_OverrideDim           : boolean;
  m_FogState              : number;

  m_Player                : table;
  m_CityID                : number;          -- The city ID.  Keeping just the ID, rather than a reference because there will be times when we need the value, but the city instance will not exist.
  m_DistrictID            : number;          -- The district ID.
  m_PlotX                 : number;          -- the X and Y location of the plot associated with the banner. We need this in cases where we need a banner not associated with a district (ex. Airstrip Improvement)
  m_PlotY                 : number;
  m_IsImprovementBanner   : boolean;
  m_eMajorityReligion     : number;
  m_UnitListEnabled				: boolean;         -- if this is an aerodome marks whether the unit dropdown is enabled when fully visible.
end



-- ===========================================================================
--  MEMBERS
-- ===========================================================================

-- CQUI taken from PlotInfo
local CQUI_ShowYieldsOnCityHover = false;
local CQUI_PlotIM        :table = InstanceManager:new( "CQUI_WorkedPlotInstance", "Anchor", Controls.CQUI_WorkedPlotContainer );
local CQUI_uiWorldMap    :table = {};
local CQUI_yieldsOn    :boolean = false;
local CQUI_Hovering :boolean = false;
local CQUI_NextPlot4Away :number = nil;


local m_CityCenterTeamIM  :table  = InstanceManager:new( "TeamCityBanner",  "Anchor", Controls.CityBanners );
local m_CityCenterOtherIM :table  = InstanceManager:new( "OtherCityBanner", "Anchor", Controls.CityBanners );
local m_HolySiteIconsIM   :table  = InstanceManager:new( "HolySiteIcon",    "Anchor", Controls.CityDistrictIcons );
local m_AerodromeBannerIM :table  = InstanceManager:new( "AerodromeBanner", "Anchor", Controls.CityBanners );
local m_WMDBannerIM     :table  = InstanceManager:new( "WMDBanner",     "Anchor", Controls.CityBanners );
local m_EncampmentBannerIM  :table  = InstanceManager:new( "EncampmentBanner",  "Anchor", Controls.CityBanners );


-- Create one instance of the meta object as a global variable with the same name as the data structure portion.
-- This allows us to do a CityBanner:new, so the naming looks consistent.
CityBanner = hmake CityBannerMeta {};

-- Link its __index to itself
CityBanner.__index = CityBanner;

local CityBannerInstances : table = {};
local MiniBannerInstances : table = {};

local BANNERTYPE_CITY_CENTER  = 0;
local BANNERTYPE_ENCAMPMENT   = 1;
local BANNERTYPE_AERODROME    = 2;
local BANNERTYPE_MISSILE_SILO = 3;

local BANNERSTYLE_LOCAL_TEAM  = 0;
local BANNERSTYLE_OTHER_TEAM  = 1;

local m_zoomMultiplier        :number = 1;
local m_prevZoomMultiplier      :number = 1;

local YOFFSET_2DVIEW        :number = 26;
local ZOFFSET_3DVIEW        :number = 36;
local SIZEOFPOPANDPROD        :number = 80; --The amount to add to the city banner to account for the size of the production icon and population number
local SIZEOFPOPANDPRODMETERS    :number = 15; --The amount to add to the city banner backing width to allow for the production and population meters to appear

local CQUI_ShowCitizenIconsOnCityHover:boolean = false;
local CQUI_ShowCityManageAreaOnCityHover:boolean = true;
local CQUI_CityManageAreaShown:boolean = false;
local CQUI_CityManageAreaShouldShow:boolean = false;

-- ===========================================================================
--  QUI
-- ===========================================================================

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
  g_smartbanner_cultural = GameConfiguration.GetValue("CQUI_Smartbanner_Cultural");

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
function CityBanner.new( self : CityBannerMeta, playerID: number, cityID : number, districtID : number, bannerType : number, bannerStyle : number )
    local o = hmake CityBanner { m_eMajorityReligion = -1 }; -- << Assign default values
    setmetatable( o, self );

  if bannerStyle == nil then UI.DataError("Missing bannerStyle: "..tostring(playerID)..", "..tostring(cityID)..", "..tostring(districtID)..", "..tostring(bannerType) ); end

  o:Initialize(playerID, cityID, districtID, bannerType, bannerStyle);

  if (bannerType == BANNERTYPE_CITY_CENTER) then
    if (CityBannerInstances[playerID] == nil) then
      CityBannerInstances[playerID] = {};
    end
    CityBannerInstances[playerID][cityID] = o;
  else
    if (MiniBannerInstances[playerID] == nil) then
      MiniBannerInstances[playerID] = {};
    end
    MiniBannerInstances[playerID][districtID] = o;
  end

  return o;
end

-- ===========================================================================
function CityBanner.destroy( self : CityBanner )
    if ( self.m_InstanceManager ~= nil ) then
        self:UpdateSelected( false );

    if (self.m_Instance ~= nil) then
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
      CQUI_ShowCitizenManagementLens(cityID)
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

      --UILens.ToggleLayerOn( LensLayers.PURCHASE_PLOT );

      for i,plotId in pairs(tPlots) do
        local kPlot :table = Map.GetPlotByIndex(plotId);
        local index:number = kPlot:GetIndex();
        local pInstance :table =  CQUI_GetInstanceAt(index);

        if (index == pNextPlotID ) then
          pInstance.CQUI_NextPlotLabel:SetString("[ICON_Turn]" .. Locale.Lookup("LOC_HUD_CITY_IN_TURNS" , TurnsUntilExpansion ) .. "   ");
          pInstance.CQUI_NextPlotButton:SetHide( false );

          -- Eventually also get the colored hex
  --        local cost:number = pCityCulture:GetNextPlotCultureCost();
  --        local currentCulture:number = pCityCulture:GetCurrentCulture();
  --        local currentYield:number = pCityCulture:GetCultureYield();
  --        local currentGrowth:number = math.max(math.min(currentCulture / cost, 1.0), 0);
  --        local nextTurnGrowth:number = math.max(math.min((currentCulture + currentYield) / cost, 1.0), 0);

          --UILens.SetLayerGrowthHex(LensLayers.PURCHASE_PLOT, kPlayer, pNextPlotID, 1, "GrowthHexBG");
          --UILens.SetLayerGrowthHex(LensLayers.PURCHASE_PLOT, kPlayer, pNextPlotID, nextTurnGrowth, "GrowthHexNext");
          --UILens.SetLayerGrowthHex(LensLayers.PURCHASE_PLOT, kPlayer, pNextPlotID, currentGrowth, "GrowthHexCurrent");
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
    CQUI_ClearCitizenManagementLens()
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

      -- Eventually remove colored hex
--      if UILens.IsLayerOn(LensLayers.CITIZEN_MANAGEMENT) == false then
--        UILens.ClearHex(LensLayers.PURCHASE_PLOT, index);
--        UILens.ToggleLayerOff( LensLayers.PURCHASE_PLOT );
--      end

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
function CityBanner.Initialize( self : CityBanner, playerID: number, cityID : number, districtID : number, bannerType : number, bannerStyle : number)

  self.m_Player = Players[playerID];
  self.m_CityID = cityID;
  self.m_DistrictID = districtID;

  if (bannerType == BANNERTYPE_CITY_CENTER) then
    if (bannerStyle == BANNERSTYLE_LOCAL_TEAM) then
      self.m_InstanceManager = m_CityCenterTeamIM;
    else
      self.m_InstanceManager = m_CityCenterOtherIM;
    end

    -- Instantiate the banner
    self.m_Instance = self.m_InstanceManager:GetInstance();

    self.m_Instance.CityBannerButton:RegisterCallback( Mouse.eLClick, OnCityBannerClick );
    self.m_Instance.CityBannerButton:SetVoid1(playerID);
    self.m_Instance.CityBannerButton:SetVoid2(cityID);

    local pCity = self:GetCity();
    if (pCity ~= nil) then
      self.m_PlotX = pCity:GetX();
      self.m_PlotY = pCity:GetY();
    end

    if (bannerStyle == BANNERSTYLE_LOCAL_TEAM) then
      if (playerID == Game.GetLocalPlayer()) then
        self.m_Instance.CityRangeStrikeButton:RegisterCallback( Mouse.eLClick, OnCityRangeStrikeButtonClick );
        self.m_Instance.CityRangeStrikeButton:SetVoid1(playerID);
        self.m_Instance.CityRangeStrikeButton:SetVoid2(cityID);
        self.m_Instance.CityProduction:RegisterCallback( Mouse.eLClick, OnProductionClick );
        self.m_Instance.CityProduction:SetVoid1(playerID);
        self.m_Instance.CityProduction:SetVoid2(cityID);
        self.m_Instance.CityBannerButton:RegisterCallback( Mouse.eMouseEnter, CQUI_OnBannerMouseOver );
        self.m_Instance.CityBannerButton:RegisterCallback( Mouse.eMouseExit, CQUI_OnBannerMouseExit );
      end
    end
  elseif (bannerType == BANNERTYPE_AERODROME) then
    self:CreateAerodromeBanner();
    self:UpdateAerodromeBanner();
  elseif (bannerType == BANNERTYPE_MISSILE_SILO) then
    self:CreateWMDBanner();
    self:UpdateWMDBanner();
  elseif (bannerType == BANNERTYPE_ENCAMPMENT) then
    self:CreateEncampmentBanner();
    self:UpdateEncampmentBanner();
  end

  self.m_Type = bannerType;
  self.m_Style = bannerStyle;
  self.m_IsSelected = false;
  self.m_IsCurrentlyVisible = false;
  self.m_IsForceHide = false;
  self.m_IsDimmed = false;
  self.m_OverrideDim = false;
  self.m_FogState = 0;
  self.m_UnitListEnabled = false;

  self:UpdateName();
  self:UpdatePosition();
  self:UpdateVisibility();

  if(self.m_Instance.CityAttackContainer ~= nil) then self:UpdateRangeStrike(); end

  -- Only call UpdateReligion if we have a religion meter (if we're not a MiniBanner)
  if(self.m_Instance.ReligionInfoAnchor ~= nil) then self:UpdateReligion(); end
  self:UpdateStats();
  self:SetColor();
  self:Resize();
end

-- ===========================================================================
function CityBanner.CreateAerodromeBanner( self : CityBanner )
  -- Set the appropriate instance factory (mini banner one) for this flag...
  self.m_InstanceManager = m_AerodromeBannerIM;
  self.m_Instance = self.m_InstanceManager:GetInstance();

  if (cityID ~= nil) then
    self.m_CityID = cityID;
  end

  self.m_IsImprovementBanner = false;

  local pDistrict = self:GetDistrict();
  if (pDistrict ~= nil) then
    self.m_PlotX = pDistrict:GetX();
    self.m_PlotY = pDistrict:GetY();
  else  -- it's an banner not associated with a district, so the districtID should be a plot index
    self.m_PlotX, self.m_PlotY = Map.GetPlotLocation(self.m_DistrictID);
    self.m_IsImprovementBanner = true;
  end
end

-- ===========================================================================
function CityBanner.UpdateAerodromeBanner( self : CityBanner )
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
function CityBanner.CreateWMDBanner( self : CityBanner )
  -- Set the appropriate instance factory (mini banner one) for this flag...
  self.m_InstanceManager = m_WMDBannerIM;
  self.m_Instance = self.m_InstanceManager:GetInstance();

  if (cityID ~= nil) then
    self.m_CityID = cityID;
  end

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
function CityBanner.UpdateWMDBanner( self : CityBanner )

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
function CityBanner.CreateEncampmentBanner( self : CityBanner )
  -- Set the appropriate instance factory (mini banner one) for this flag...
  self.m_InstanceManager = m_EncampmentBannerIM;
  self.m_Instance = self.m_InstanceManager:GetInstance();

  if (cityID ~= nil) then
    self.m_CityID = cityID;
  end

  self.m_IsImprovementBanner = false;

  local pDistrict = self:GetDistrict();
  if (pDistrict ~= nil) then
    self.m_PlotX = pDistrict:GetX();
    self.m_PlotY = pDistrict:GetY();

    -- Update district strength
    local districtDefense:number = math.floor(pDistrict:GetDefenseStrength() + 0.5);
    self.m_Instance.DistrictDefenseStrengthLabel:SetText(districtDefense);

    -- Setup strike button callback
    self.m_Instance.CityRangeStrikeButton:RegisterCallback( Mouse.eLClick, OnDistrictRangeStrikeButtonClick );
    self.m_Instance.CityRangeStrikeButton:SetVoid1(self.m_Player:GetID());
    self.m_Instance.CityRangeStrikeButton:SetVoid2(self.m_DistrictID);
  end
end

-- ===========================================================================
function CityBanner.UpdateEncampmentBanner( self : CityBanner )
  -- Update wall/district health
  local pDistrict:table = self:GetDistrict();

  local districtDefense:number = math.floor(pDistrict:GetDefenseStrength() + 0.5);
  local districtHitpoints   :number = pDistrict:GetMaxDamage(DefenseTypes.DISTRICT_GARRISON);
  local currentDistrictDamage :number = pDistrict:GetDamage(DefenseTypes.DISTRICT_GARRISON);
  local wallHitpoints     :number = pDistrict:GetMaxDamage(DefenseTypes.DISTRICT_OUTER);
  local currentWallDamage   :number = pDistrict:GetDamage(DefenseTypes.DISTRICT_OUTER);
  local healthTooltip :string = Locale.Lookup("LOC_CITY_BANNER_DISTRICT_HITPOINTS", ((districtHitpoints-currentDistrictDamage) .. "/" .. districtHitpoints));
  local defTooltip = Locale.Lookup("LOC_CITY_BANNER_DISTRICT_DEFENSE_STRENGTH", districtDefense);

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
  local playerUnits:table = Players[Game.GetLocalPlayer()]:GetUnits();
  if playerUnits then
    local selectedUnit:table = playerUnits:FindID(unitID);
    if selectedUnit then
      UI.SelectUnit( selectedUnit );
    end
  end
end

-- ===========================================================================
function CityBanner.IsVisible( self : CityBanner )
  local pLocalPlayerVis:table = PlayersVisibility[Game.GetLocalPlayer()];
  local city:table = self:GetCity();
  local locX:number = city:GetX();
  local locY:number = city:GetY();
  if pLocalPlayerVis:IsVisible(locX, locY) then
    return true;
  elseif pLocalPlayerVis:IsRevealed(locX, locY) then
    return true;
  end
  return false;
end

function CityBanner.IsTeam( self : CityBanner )
  return self.m_Style == BANNERSTYLE_LOCAL_TEAM;
end

-- ===========================================================================
-- Resize and recenter city banner images to accomodate the city name
function CityBanner.Resize( self : CityBanner )
  if (self.m_Type == BANNERTYPE_CITY_CENTER) then
    local pCity : table = self:GetCity();
    if (pCity ~= nil) then
      self.m_Instance.CityNameStack:CalculateSize();
      self.m_Instance.CityNameStack:ReprocessAnchoring();
      local nameContainerSize = self.m_Instance.CityNameStack:GetSizeX();
      self.m_Instance.CityNameContainer:SetSizeX(nameContainerSize);

      self.m_Instance.ContentStack:CalculateSize();
      self.m_Instance.ContentStack:ReprocessAnchoring();
      local newBannerSize = self.m_Instance.ContentStack:GetSizeX();
      if (newBannerSize < MINIMUM_BANNER_WIDTH) then
        nameContainerSize = nameContainerSize + (MINIMUM_BANNER_WIDTH - newBannerSize);
        newBannerSize = MINIMUM_BANNER_WIDTH;
        self.m_Instance.CityNameContainer:SetSizeX(nameContainerSize);
        self.m_Instance.ContentStack:CalculateSize();
        self.m_Instance.ContentStack:ReprocessAnchoring();
      end
      self.m_Instance.CityBannerBackground:SetSizeX(newBannerSize + SIZEOFPOPANDPRODMETERS);
      self.m_Instance.CityBannerButton:SetSizeX(newBannerSize);
      self.m_Instance.CityBannerFill:SetSizeX(newBannerSize);
      self.m_Instance.CityBannerFillOver:SetSizeX(newBannerSize);
      self.m_Instance.CityBannerFillOut:SetSizeX(newBannerSize);

      self.m_Instance.CityNameStack:CalculateSize();
      self.m_Instance.CityNameStack:ReprocessAnchoring();

      -- Inside the city strength indicator (shield) - Recentering the characters that have odd leading
      --if(self.m_Instance.DefenseNumber:GetText() == "4" or self.m_Instance.DefenseNumber:GetText() == "6" or self.m_Instance.DefenseNumber:GetText() == "8") then
      --  self.m_Instance.DefenseNumber:SetOffsetX(-2);
      --end
    end
  end
end

-- ===========================================================================
-- Assign player colors to the appropriate banner elements
function CityBanner.SetColor( self : CityBanner )

  local backColor, frontColor  = UI.GetPlayerColors( self.m_Player:GetID() );
  local darkerBackColor = DarkenLightenColor(backColor,(-85),238);
  local brighterBackColor = DarkenLightenColor(backColor,90,255);
  if (self.m_IsSelected == false or self.m_IsSelected == nil) then
    backColor = DarkenLightenColor(backColor, 0, 80);
  end

  if (self.m_Type == BANNERTYPE_CITY_CENTER) then
    self.m_Instance.CityBannerFill:SetColor( backColor );
    self.m_Instance.CityBannerFill2:SetColor( darkerBackColor );
    self.m_Instance.CityBannerFill3:SetColor( brighterBackColor );
    self.m_Instance.CityBannerFillOver:SetColor( frontColor );
    self.m_Instance.CityBannerFillOut:SetColor( brighterBackColor );
    self.m_Instance.CityName:SetColor( frontColor, 0 );
    self.m_Instance.CityName:SetColor( darkerBackColor, 1 );
    self.m_Instance.CityPopulation:SetColor( frontColor, 0 );
    self.m_Instance.CityPopulation:SetColor( darkerBackColor, 1 );
    if not self:IsTeam() then self.m_Instance.CivIcon:SetColor( frontColor ); end
  elseif (self.m_Type == BANNERTYPE_AERODROME) then
    if self.m_Instance.AerodromeUnitsButton_Base ~= nil then
      self.m_Instance.AerodromeUnitsButton_Base:SetColor( backColor );
      self.m_Instance.AerodromeUnitsButton_Darker:SetColor( darkerBackColor );
      self.m_Instance.AerodromeUnitsButton_Lighter:SetColor( brighterBackColor );
      self.m_Instance.AerodromeUnitsButton_None:SetColor( frontColor );
      self.m_Instance.AerodromeUnitsButtonIcon:SetColor( frontColor );
    end
  elseif (self.m_Type == BANNERTYPE_MISSILE_SILO) then
    if self.m_Instance.Banner_Base ~= nil then
      self.m_Instance.Banner_Base:SetColor( backColor );
      self.m_Instance.Banner_Darker:SetColor( darkerBackColor );
      self.m_Instance.Banner_Lighter:SetColor( brighterBackColor );
      self.m_Instance.Banner_None:SetColor( frontColor );
      self.m_Instance.NukeCountLabel:SetColor( frontColor );
      self.m_Instance.ThermoNukeCountLabel:SetColor( frontColor );
    end
  elseif (self.m_Type == BANNERTYPE_ENCAMPMENT) then
    if self.m_Instance.Banner_Base ~= nil then
      self.m_Instance.Banner_Base:SetColor( backColor );
      self.m_Instance.Banner_Darker:SetColor( darkerBackColor );
      self.m_Instance.Banner_Lighter:SetColor( brighterBackColor );
      self.m_Instance.Banner_None:SetColor( frontColor );
    end
  else
    self.m_Instance.MiniBannerBackground:SetColor( backColor );
  end

  self:SetHealthBarColor();

end

-- ===========================================================================
function CityBanner.SetHealthBarColor( self : CityBanner )
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
-- Non-instance function so it can be overwritten by mods
  function GetPopulationTooltip(self:CityBanner, turnsUntilGrowth:number, currentPopulation:number, foodSurplus:number)
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
  -- Non-instance function so it can be overwritten by mods
  function GetCityPopulationText(self:CityBanner, currentPopulation:number)
    return tostring(currentPopulation);
  end

-- ===========================================================================
function CityBanner.UpdateStats( self : CityBanner)
  self:UpdateName();
  local pDistrict:table = self:GetDistrict();
  local localPlayerID:number = Game.GetLocalPlayer();
  if (pDistrict ~= nil) then

    local districtHitpoints   :number = pDistrict:GetMaxDamage(DefenseTypes.DISTRICT_GARRISON);
    local currentDistrictDamage :number = pDistrict:GetDamage(DefenseTypes.DISTRICT_GARRISON);
    local wallHitpoints     :number = pDistrict:GetMaxDamage(DefenseTypes.DISTRICT_OUTER);
    local currentWallDamage   :number = pDistrict:GetDamage(DefenseTypes.DISTRICT_OUTER);
    local garrisonDefense   :number = math.floor(pDistrict:GetDefenseStrength() + 0.5);

    if self.m_Type == BANNERTYPE_CITY_CENTER then
      local pCity       :table = self:GetCity();
      local currentPopulation :number = pCity:GetPopulation();
      local pCityGrowth   :table  = pCity:GetGrowth();
      local pBuildQueue   :table  = pCity:GetBuildQueue();
      local foodSurplus   :number = pCityGrowth:GetFoodSurplus();
      local isGrowing     :boolean= pCityGrowth:GetTurnsUntilGrowth() ~= -1;
      local isStarving    :boolean= pCityGrowth:GetTurnsUntilStarvation() ~= -1;

      local pCityCulture    :table  = pCity:GetCulture();

      local turnsUntilGrowth :number = 0; -- It is possible for zero... no growth and no starving.
      if isGrowing then
        turnsUntilGrowth = pCityGrowth:GetTurnsUntilGrowth();
      elseif isStarving then
        turnsUntilGrowth = -pCityGrowth:GetTurnsUntilStarvation();  -- Make negative
      end

      self.m_Instance.CityPopulation:SetText(GetCityPopulationText(self, currentPopulation));

      if (self.m_Player == Players[localPlayerID]) then --Only show growth data if the player is you
        local popTurnLeftColor = "";
        if turnsUntilGrowth > 0 then
          popTurnLeftColor = "StatGoodCS";
        elseif turnsUntilGrowth < 0 then
          popTurnLeftColor = "StatBadCS";
        else
          popTurnLeftColor = "StatNormalCS";
        end

        if g_smartbanner and g_smartbanner_cultural then
          local turnsUntilBorderGrowth = pCityCulture:GetTurnsUntilExpansion();
          self.m_Instance.CityCultureTurnsLeft:SetText(turnsUntilBorderGrowth);
          self.m_Instance.CityCultureTurnsLeft:SetHide(false);
        else
          self.m_Instance.CityCultureTurnsLeft:SetHide(true);
        end

        -- CQUI get real housing from improvements value
        local pCityID = pCity:GetID();
        if CQUI_HousingUpdated[pCityID] ~= true then
          CQUI_RealHousingFromImprovements(pCity);
        end

        if g_smartbanner and g_smartbanner_population then
          local CQUI_HousingFromImprovements = CQUI_HousingFromImprovementsTable[pCityID];    -- CQUI real housing from improvements value
          if CQUI_HousingFromImprovements ~= nil then    -- CQUI real housing from improvements fix to show correct values when waiting for the next turn
            local popTooltip:string = GetPopulationTooltip(self, turnsUntilGrowth, currentPopulation, foodSurplus);
            self.m_Instance.CityPopulation:SetToolTipString(popTooltip);
            local housingLeft = pCityGrowth:GetHousing() - pCityGrowth:GetHousingFromImprovements() + CQUI_HousingFromImprovements - currentPopulation;    -- CQUI calculate real housing
            local housingLeftText = housingLeft;
            local housingLeftColor = "Error";
            if housingLeft > 1.5 then
              housingLeftColor = "StatGoodCS";
              housingLeftText = "+"..housingLeft;
              --COLOR: Green
            elseif housingLeft <= 1.5 and housingLeft > 0.5 then
              housingLeftColor = "WarningMinor";
              housingLeftText = "+"..housingLeft;
              --COLOR: Yellow
            elseif housingLeft == 0.5 then
              housingLeftColor = "WarningMajor";
              housingLeftText = "+"..housingLeft;
            elseif housingLeft < 0.5 and housingLeft >= -4.5 then
              housingLeftColor = "WarningMajor";
            end
            local CTLS = "[COLOR:"..popTurnLeftColor.."]"..turnsUntilGrowth.."[ENDCOLOR]  [[COLOR:"..housingLeftColor.."]"..housingLeftText.."[ENDCOLOR]]  ";
            self.m_Instance.CityPopTurnsLeft:SetText(CTLS);
            self.m_Instance.CityPopTurnsLeft:SetHide(false);
          end
        else
          self.m_Instance.CityPopTurnsLeft:SetHide(true);
        end
      end

      local food             :number = pCityGrowth:GetFood();
      local growthThreshold  :number = pCityGrowth:GetGrowthThreshold();
      local foodSurplus      :number = pCityGrowth:GetFoodSurplus();
      local foodpct          :number = Clamp( food / growthThreshold, 0.0, 1.0 );
      local foodpctNextTurn  :number = 0;
      if turnsUntilGrowth > 0 then
        local foodGainNextTurn = foodSurplus * pCityGrowth:GetOverallGrowthModifier();
        foodpctNextTurn = (food + foodGainNextTurn) / growthThreshold;
        foodpctNextTurn = Clamp( foodpctNextTurn, 0.0, 1.0 );
      end

      self.m_Instance.CityPopulationMeter:SetPercent(foodpct);
      self.m_Instance.CityPopulationNextTurn:SetPercent(foodpctNextTurn);

      -- Update insufficient housing icon
      if self.m_Instance.CityHousingInsufficientIcon ~= nil then
        self.m_Instance.CityHousingInsufficientIcon:SetToolTipString(Locale.Lookup("LOC_CITY_BANNER_HOUSING_INSUFFICIENT"));
        if pCityGrowth:GetHousing() < pCity:GetPopulation() then
          self.m_Instance.CityHousingInsufficientIcon:SetHide(false);
        else
          self.m_Instance.CityHousingInsufficientIcon:SetHide(true);
        end
      end

      --- CITY PRODUCTION ---
      if (localPlayerID == pCity:GetOwner()) then
        if (pBuildQueue ~= nil) then
          pct = 0;
          local currentProduction   :string;
          local currentProductionHash :number = pBuildQueue:GetCurrentProductionTypeHash();
          local prodTurnsLeft     :number;
          local progress        :number;
          local prodTypeName      :string;
          local pBuildingDef      :table;
          local pDistrictDef      :table;
          local pUnitDef        :table;
          local pProjectDef     :table;

          -- Attempt to obtain a hash for each item
          if currentProductionHash ~= 0 then
            pBuildingDef = GameInfo.Buildings[currentProductionHash];
            pDistrictDef = GameInfo.Districts[currentProductionHash];
            pUnitDef    = GameInfo.Units[currentProductionHash];
            pProjectDef = GameInfo.Projects[currentProductionHash];
          end

          if( pBuildingDef ~= nil ) then
            currentProduction = pBuildingDef.Name;
            prodTypeName = pBuildingDef.BuildingType;
            prodTurnsLeft = pBuildQueue:GetTurnsLeft(pBuildingDef.BuildingType);
            progress = pBuildQueue:GetBuildingProgress(pBuildingDef.Index);
            pct = progress / pBuildQueue:GetBuildingCost(pBuildingDef.Index);
          elseif ( pDistrictDef ~= nil ) then
            currentProduction = pDistrictDef.Name;
            prodTypeName = pDistrictDef.DistrictType;
            prodTurnsLeft = pBuildQueue:GetTurnsLeft(pDistrictDef.DistrictType);
            progress = pBuildQueue:GetDistrictProgress(pDistrictDef.Index);
            pct = progress / pBuildQueue:GetDistrictCost(pDistrictDef.Index);
          elseif ( pUnitDef ~= nil ) then
            local eMilitaryFormationType = pBuildQueue:GetCurrentProductionTypeModifier();
            currentProduction = pUnitDef.Name;
            prodTypeName = pUnitDef.UnitType;
            prodTurnsLeft = pBuildQueue:GetTurnsLeft(pUnitDef.UnitType, eMilitaryFormationType);
            progress = pBuildQueue:GetUnitProgress(pUnitDef.Index);

            if (eMilitaryFormationType == MilitaryFormationTypes.STANDARD_FORMATION) then
              pct = progress / pBuildQueue:GetUnitCost(pUnitDef.Index);
            elseif (eMilitaryFormationType == MilitaryFormationTypes.CORPS_FORMATION) then
              pct = progress / pBuildQueue:GetUnitCorpsCost(pUnitDef.Index);
              if (pUnitDef.Domain == "DOMAIN_SEA") then
                -- Concatenanting two fragments is not loc friendly.  This needs to change.
                currentProduction = Locale.Lookup(currentProduction) .. " " .. Locale.Lookup("LOC_UNITFLAG_FLEET_SUFFIX");
              else
                -- Concatenanting two fragments is not loc friendly.  This needs to change.
                currentProduction = Locale.Lookup(currentProduction) .. " " .. Locale.Lookup("LOC_UNITFLAG_CORPS_SUFFIX");
              end
            elseif (eMilitaryFormationType == MilitaryFormationTypes.ARMY_FORMATION) then
              pct = progress / pBuildQueue:GetUnitArmyCost(pUnitDef.Index);
              if (pUnitDef.Domain == "DOMAIN_SEA") then
                -- Concatenanting two fragments is not loc friendly.  This needs to change.
                currentProduction = Locale.Lookup(currentProduction) .. " " .. Locale.Lookup("LOC_UNITFLAG_ARMADA_SUFFIX");
              else
                -- Concatenanting two fragments is not loc friendly.  This needs to change.
                currentProduction = Locale.Lookup(currentProduction) .. " " .. Locale.Lookup("LOC_UNITFLAG_ARMY_SUFFIX");
              end
            end

            progress = pBuildQueue:GetUnitProgress(pUnitDef.Index);
            pct = progress / pBuildQueue:GetUnitCost(pUnitDef.Index);
          elseif (pProjectDef ~= nil) then
            currentProduction = pProjectDef.Name;
            prodTypeName = pProjectDef.ProjectType;
            prodTurnsLeft = pBuildQueue:GetTurnsLeft(pProjectDef.ProjectType);
            progress = pBuildQueue:GetProjectProgress(pProjectDef.Index);
            pct = progress / pBuildQueue:GetProjectCost(pProjectDef.Index);
          end

          if(currentProduction ~= nil) then
            pct = math.clamp(pct, 0, 1);
            if prodTurnsLeft <= 0 then
              pctNextTurn = 0;
            else
              pctNextTurn = (1-pct)/prodTurnsLeft;
            end
            pctNextTurn = pct + pctNextTurn;

            self.m_Instance.CityProductionMeter:SetPercent(pct);
            self.m_Instance.CityProductionNextTurn:SetPercent(pctNextTurn);

            local productionTip       :string = Locale.Lookup("LOC_CITY_BANNER_PRODUCING", currentProduction);
            local productionTurnsLeftString :string;
            if prodTurnsLeft <= 0 then
              self.m_Instance.CityProdTurnsLeft:SetText("-");
              productionTurnsLeftString = "  " .. Locale.Lookup("LOC_CITY_BANNER_TURNS_LEFT_UNTIL_COMPLETE", "-");
            else
              productionTurnsLeftString = "  " .. Locale.Lookup("LOC_CITY_BANNER_TURNS_LEFT_UNTIL_COMPLETE", prodTurnsLeft);
              self.m_Instance.CityProdTurnsLeft:SetText(prodTurnsLeft);
            end
            productionTip = productionTip .. "[NEWLINE]" .. productionTurnsLeftString;
            self.m_Instance.CityProduction:SetToolTipString(productionTip);
            self.m_Instance.ProductionIndicator:SetHide(false);
            self.m_Instance.CityProductionProgress:SetHide(false);
            self.m_Instance.CityProduction:SetColor(0x00FFFFFF);

            if(prodTypeName ~= nil) then
              self.m_Instance.CityProductionIcon:SetHide(false);
              self.m_Instance.CityProductionIcon:SetIcon("ICON_"..prodTypeName);
            else
              self.m_Instance.CityProductionIcon:SetHide(true);
            end
          else
            self.m_Instance.CityProduction:SetToolTipString(Locale.Lookup("LOC_CITY_BANNER_NO_PRODUCTION"));
            self.m_Instance.CityProductionIcon:SetHide(true);
            self.m_Instance.CityProduction:SetColor(0xFFFFFFFF);
            self.m_Instance.CityProductionProgress:SetHide(true);
            self.m_Instance.CityProdTurnsLeft:SetText("");
          end

        end
      end

      --- DEFENSE INFO ---
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
      else
        self.m_Instance.CityDefenseBar:SetHide(true)
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
      self.m_Instance.DefenseStack:CalculateSize();
      self.m_Instance.DefenseStack:ReprocessAnchoring();
      self.m_Instance.BannerStrengthBacking:SetSizeX(self.m_Instance.DefenseStack:GetSizeX()+30);
      self.m_Instance.BannerStrengthBacking:SetToolTipString(defTooltip);

      -- Update under siege icon
      if pDistrict:IsUnderSiege() then
        self.m_Instance.CityUnderSiegeIcon:SetHide(false);
      else
        self.m_Instance.CityUnderSiegeIcon:SetHide(true);
      end

      -- Update occupied icon
      if pCity:IsOccupied() then
        self.m_Instance.CityOccupiedIcon:SetHide(false);
      else
        self.m_Instance.CityOccupiedIcon:SetHide(true);
      end

      -- Update insufficient amenities icon
      if self.m_Instance.CityAmenitiesInsufficientIcon ~= nil then
        self.m_Instance.CityAmenitiesInsufficientIcon:SetToolTipString(Locale.Lookup("LOC_CITY_BANNER_AMENITIES_INSUFFICIENT"));
        if pCityGrowth:GetAmenitiesNeeded() > pCityGrowth:GetAmenities() then
          self.m_Instance.CityAmenitiesInsufficientIcon:SetHide(false);
        else
          self.m_Instance.CityAmenitiesInsufficientIcon:SetHide(true);
        end
      end
      --------------------------------------
    else -- it should be a miniBanner

      if (self.m_Type == BANNERTYPE_ENCAMPMENT) then
        self:UpdateEncampmentBanner();
      elseif (self.m_Type == BANNERTYPE_AERODROME) then
        self:UpdateAerodromeBanner();
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
--  Round to X decimal places -- do we have a function for this already?
-- ===========================================================================
function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult;
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

  local localPlayerID;
  if (WorldBuilder.IsActive()) then
    localPlayerID = playerID; -- If WorldBuilder is active, allow the user to select the city
  else
    localPlayerID = Game.GetLocalPlayer();
  end

  if (pPlayer:GetID() == localPlayerID) then
    UI.SelectCity( pCity );
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
function CityBanner.GetCity( self : CityBanner )
  local pCity : table = self.m_Player:GetCities():FindID(self.m_CityID);
  return pCity;
end

-- ===========================================================================
function CityBanner.GetDistrict( self : CityBanner )
  local pDistrict : table = self.m_Player:GetDistricts():FindID(self.m_DistrictID);
  return pDistrict;
end

-- ===========================================================================
function CityBanner.GetImprovementInfo( self : CityBanner )
  local locX = self.m_PlotX;
  local locY = self.m_PlotY;

  local tImprovementInfo = {
    LocX            = self.m_PlotX,
    LocY            = self.m_PlotY,
    ImprovementOwner      = -1,
    AirUnits          = {},
  };

  return tImprovementInfo;
end

-- ===========================================================================
function CityBanner.SetFogState( self : CityBanner, fogState : number )

  if( fogState == PLOT_HIDDEN ) then
    self:SetHide( true );
  else
    self:SetHide( false );

    --If this is an Aerodrome we need to hide the numbers and dropdown if in FOW
    if( self.m_Instance ~= nil ) then
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
  end

  self.m_FogState = fogState;
end

-- ===========================================================================
function CityBanner.SetHide( self : CityBanner, bHide : boolean )
  self.m_IsCurrentlyVisible = not bHide;
  self:UpdateVisibility();
end

-- ===========================================================================
function CityBanner.UpdateVisibility( self : CityBanner )

  local bVisible = self.m_IsCurrentlyVisible and not self.m_IsForceHide;
  self.m_Instance.Anchor:SetHide(not bVisible);

end

-- ===========================================================================
function CityBanner.UpdateName( self : CityBanner )
  if (self.m_Type == BANNERTYPE_CITY_CENTER) then
    local pCity : table = self:GetCity();
    if pCity ~= nil then
      local owner     :number = pCity:GetOwner();
      local pPlayer   :table  = Players[owner];
      local capitalIcon :string = (pPlayer ~= nil and pPlayer:IsMajor() and pCity:IsCapital()) and "[ICON_Capital]" or "";
      local cityName    :string = capitalIcon .. Locale.ToUpper(pCity:GetName());

      if not self:IsTeam() then
        local civType:string = PlayerConfigurations[owner]:GetCivilizationTypeName();
        if civType ~= nil then
          self.m_Instance.CivIcon:SetIcon("ICON_" .. civType);
        else
          UI.DataError("Invalid type name returned by GetCivilizationTypeName");
        end
      end

      local questsManager : table = Game.GetQuestsManager();
      local questTooltip  : string = Locale.Lookup("LOC_CITY_STATES_QUESTS");
      local statusString  : string = "";
      if (questsManager ~= nil) then
        for questInfo in GameInfo.Quests() do
          if (questsManager:HasActiveQuestFromPlayer(Game.GetLocalPlayer(), owner, questInfo.Index)) then
            statusString = "[ICON_CityStateQuest]";
            questTooltip = questTooltip .. "[NEWLINE]" .. questInfo.IconString .. questsManager:GetActiveQuestName(Game.GetLocalPlayer(), owner, questInfo.Index);
          end
        end
      end

      -- Update under siege icon
      local pDistrict:table = self:GetDistrict();
      if pDistrict and pDistrict:IsUnderSiege() then
        self.m_Instance.CityUnderSiegeIcon:SetHide(false);
      else
        self.m_Instance.CityUnderSiegeIcon:SetHide(true);
      end

      -- Update district icons
      -- districtType:number == Index
      function GetDistrictIndexSafe(sDistrict)
        if GameInfo.Districts[sDistrict] == nil then return -1;
        else return GameInfo.Districts[sDistrict].Index; end
      end

      local iAquaduct = GetDistrictIndexSafe("DISTRICT_AQUEDUCT");
      local iBath = GetDistrictIndexSafe("DISTRICT_BATH");
      local iNeighborhood = GetDistrictIndexSafe("DISTRICT_NEIGHBORHOOD");
      local iMbanza = GetDistrictIndexSafe("DISTRICT_MBANZA");
      local iCampus = GetDistrictIndexSafe("DISTRICT_CAMPUS");
      local iTheater = GetDistrictIndexSafe("DISTRICT_THEATER");
      local iAcropolis = GetDistrictIndexSafe("DISTRICT_ACROPOLIS");
      local iIndustrial = GetDistrictIndexSafe("DISTRICT_INDUSTRIAL_ZONE");
      local iHansa = GetDistrictIndexSafe("DISTRICT_HANSA");
      local iCommerce = GetDistrictIndexSafe("DISTRICT_COMMERCIAL_HUB");
      local iEncampment = GetDistrictIndexSafe("DISTRICT_ENCAMPMENT");
      local iHarbor = GetDistrictIndexSafe("DISTRICT_HARBOR");
      local iRoyalNavy = GetDistrictIndexSafe("DISTRICT_ROYAL_NAVY_DOCKYARD");
      local iSpaceport = GetDistrictIndexSafe("DISTRICT_SPACEPORT");
      local iEntertainmentComplex = GetDistrictIndexSafe("DISTRICT_ENTERTAINMENT_COMPLEX");
      local iHolySite = GetDistrictIndexSafe("DISTRICT_HOLY_SITE");
      local iAerodrome = GetDistrictIndexSafe("DISTRICT_AERODROME");
      local iStreetCarnival = GetDistrictIndexSafe("DISTRICT_STREET_CARNIVAL");
      local iLavra = GetDistrictIndexSafe("DISTRICT_LAVRA");

      if self.m_Instance.CityBuiltDistrictAquaduct ~= nil then
        self.m_Instance.CityUnlockedCitizen:SetHide(true);
        self.m_Instance.CityBuiltDistrictAquaduct:SetHide(true);
        self.m_Instance.CityBuiltDistrictBath:SetHide(true);
        self.m_Instance.CityBuiltDistrictNeighborhood:SetHide(true);
        self.m_Instance.CityBuiltDistrictMbanza:SetHide(true);
        self.m_Instance.CityBuiltDistrictCampus:SetHide(true);
        self.m_Instance.CityBuiltDistrictCommercial:SetHide(true);
        self.m_Instance.CityBuiltDistrictEncampment:SetHide(true);
        self.m_Instance.CityBuiltDistrictTheatre:SetHide(true);
        self.m_Instance.CityBuiltDistrictAcropolis:SetHide(true);
        self.m_Instance.CityBuiltDistrictIndustrial:SetHide(true);
        self.m_Instance.CityBuiltDistrictHansa:SetHide(true);
        self.m_Instance.CityBuiltDistrictHarbor:SetHide(true);
        self.m_Instance.CityBuiltDistrictRoyalNavy:SetHide(true);
        self.m_Instance.CityBuiltDistrictSpaceport:SetHide(true);
        self.m_Instance.CityBuiltDistrictEntertainment:SetHide(true);
        self.m_Instance.CityBuiltDistrictHoly:SetHide(true);
        self.m_Instance.CityBuiltDistrictAerodrome:SetHide(true);
        self.m_Instance.CityBuiltDistrictStreetCarnival:SetHide(true);
        self.m_Instance.CityBuiltDistrictLavra:SetHide(true);
      end

      local pCityDistricts:table  = pCity:GetDistricts();
      if g_smartbanner and self.m_Instance.CityBuiltDistrictAquaduct ~= nil then
        --Unlocked citizen check
        if g_smartbanner_unmanaged_citizen then
          local tParameters :table = {};
          tParameters[CityCommandTypes.PARAM_MANAGE_CITIZEN] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_MANAGE_CITIZEN);

          local tResults  :table = CityManager.GetCommandTargets( pCity, CityCommandTypes.MANAGE, tParameters );
          if tResults ~= nil then
            local tPlots    :table = tResults[CityCommandResults.PLOTS];
            local tUnits    :table = tResults[CityCommandResults.CITIZENS];
            local tMaxUnits   :table = tResults[CityCommandResults.MAX_CITIZENS];
            local tLockedUnits  :table = tResults[CityCommandResults.LOCKED_CITIZENS];
            if tPlots ~= nil and (table.count(tPlots) > 0) then
              for i,plotId in pairs(tPlots) do
                local kPlot :table = Map.GetPlotByIndex(plotId);
                if(tMaxUnits[i] >= 1 and tUnits[i] >= 1 and tLockedUnits[i] <= 0) then
                  self.m_Instance.CityUnlockedCitizen:SetHide(false);
                end
              end
            end
          end
        end
        -- End Unlocked Citizen Check

        if g_smartbanner_districts then
          for i, district in pCityDistricts:Members() do
            local districtType = district:GetType();
            local districtInfo:table = GameInfo.Districts[districtType];
            local isBuilt = pCityDistricts:HasDistrict(districtInfo.Index, true);
            if isBuilt then
              if (districtType == iAquaduct) then self.m_Instance.CityBuiltDistrictAquaduct:SetHide(false); end
              if (districtType == iBath) then self.m_Instance.CityBuiltDistrictBath:SetHide(false); end
              if (districtType == iNeighborhood) then self.m_Instance.CityBuiltDistrictNeighborhood:SetHide(false); end
              if (districtType == iMbanza) then self.m_Instance.CityBuiltDistrictMbanza:SetHide(false); end
              if (districtType == iCampus) then self.m_Instance.CityBuiltDistrictCampus:SetHide(false); end
              if (districtType == iCommerce) then self.m_Instance.CityBuiltDistrictCommercial:SetHide(false); end
              if (districtType == iEncampment) then self.m_Instance.CityBuiltDistrictEncampment:SetHide(false); end
              if (districtType == iTheater) then self.m_Instance.CityBuiltDistrictTheatre:SetHide(false); end
              if (districtType == iAcropolis) then self.m_Instance.CityBuiltDistrictAcropolis:SetHide(false); end
              if (districtType == iIndustrial) then self.m_Instance.CityBuiltDistrictIndustrial:SetHide(false); end
              if (districtType == iHansa) then self.m_Instance.CityBuiltDistrictHansa:SetHide(false); end
              if (districtType == iHarbor) then self.m_Instance.CityBuiltDistrictHarbor:SetHide(false); end
              if (districtType == iRoyalNavy) then self.m_Instance.CityBuiltDistrictRoyalNavy:SetHide(false); end
              if (districtType == iSpaceport) then self.m_Instance.CityBuiltDistrictSpaceport:SetHide(false); end
              if (districtType == iEntertainmentComplex) then self.m_Instance.CityBuiltDistrictEntertainment:SetHide(false); end
              if (districtType == iHolySite) then self.m_Instance.CityBuiltDistrictHoly:SetHide(false); end
              if (districtType == iAerodrome) then self.m_Instance.CityBuiltDistrictAerodrome:SetHide(false); end
              if (districtType == iStreetCarnival) then self.m_Instance.CityBuiltDistrictStreetCarnival:SetHide(false); end
              if (districtType == iLavra) then self.m_Instance.CityBuiltDistrictLavra:SetHide(false); end
            end
          end
        end
      end

      -- Update insufficient housing icon
      if self.m_Instance.CityHousingInsufficientIcon ~= nil then
        local pCityGrowth:table = pCity:GetGrowth();
        if pCityGrowth and pCityGrowth:GetHousing() < pCity:GetPopulation() then
          self.m_Instance.CityHousingInsufficientIcon:SetHide(false);
        else
          self.m_Instance.CityHousingInsufficientIcon:SetHide(true);
        end
      end

      -- Update insufficient amenities icon
      if self.m_Instance.CityAmenitiesInsufficientIcon ~= nil then
        local pCityGrowth:table = pCity:GetGrowth();
        if pCityGrowth and pCityGrowth:GetAmenitiesNeeded() > pCityGrowth:GetAmenities() then
          self.m_Instance.CityAmenitiesInsufficientIcon:SetHide(false);
        else
          self.m_Instance.CityAmenitiesInsufficientIcon:SetHide(true);
        end
      end

      -- Update occupied icon
      if self.m_Instance.CityOccupiedIcon ~= nil then
        if pCity:IsOccupied() then
          self.m_Instance.CityOccupiedIcon:SetHide(false);
        else
          self.m_Instance.CityOccupiedIcon:SetHide(true);
        end
      end

      -- CQUI: Show leader icon for the suzerain
      local pPlayerConfig :table = PlayerConfigurations[owner];
      local isMinorCiv :boolean = pPlayerConfig:GetCivilizationLevelTypeID() ~= CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV;
      if isMinorCiv then
        CQUI_UpdateSuzerainIcon(pPlayer, self);
      end

      self.m_Instance.CityQuestIcon:SetToolTipString(questTooltip);
      self.m_Instance.CityQuestIcon:SetText(statusString);
      self.m_Instance.CityName:SetText( cityName );
      self.m_Instance.CityNameStack:ReprocessAnchoring();
      self.m_Instance.ContentStack:ReprocessAnchoring();
      self:Resize();
    end
  end
end

-- ===========================================================================
function CityBanner.UpdateReligion( self : CityBanner )

  local cityInst      :table = self.m_Instance;
  local pCity       :table = self:GetCity();
  local pCityReligion   :table = pCity:GetReligion();
  local eMajorityReligion :number = pCityReligion:GetMajorityReligion();
  local religionsInCity	:table = pCityReligion:GetReligionsInCity();
  self.m_eMajorityReligion = eMajorityReligion;

  if (eMajorityReligion > 0) then
    local iconName : string = "ICON_" .. GameInfo.Religions[eMajorityReligion].ReligionType;
    local majorityReligionColor : number = UI.GetColorValue(GameInfo.Religions[eMajorityReligion].Color);
    if (majorityReligionColor ~= nil) then
      self.m_Instance.ReligionBannerIcon:SetColor(majorityReligionColor);
    end
    local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName,22);
    if (textureOffsetX ~= nil) then
      self.m_Instance.ReligionBannerIcon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
    end
    self.m_Instance.ReligionBannerIconContainer:SetHide(false);
    self.m_Instance.ReligionBannerIconContainer:SetToolTipString(Game.GetReligion():GetName(eMajorityReligion));
  elseif (pCityReligion:GetActivePantheon() >= 0) then
    local iconName : string = "ICON_" .. GameInfo.Religions[0].ReligionType;
    local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName,22);
    if (textureOffsetX ~= nil) then
      self.m_Instance.ReligionBannerIcon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
    end
    self.m_Instance.ReligionBannerIconContainer:SetHide(false);
    self.m_Instance.ReligionBannerIconContainer:SetToolTipString(Locale.Lookup("LOC_HUD_CITY_PANTHEON_TT", GameInfo.Beliefs[pCityReligion:GetActivePantheon()].Name));
  else
    self.m_Instance.ReligionBannerIconContainer:SetHide(true);
  end

  self:Resize();

  -- Hide the meter and bail out if the religion lens isn't active
  if(not m_isReligionLensActive or table.count(religionsInCity) == 0) then
    if cityInst[DATA_FIELD_RELIGION_INFO_INSTANCE] then
      cityInst[DATA_FIELD_RELIGION_INFO_INSTANCE].ReligionInfoContainer:SetHide(true);
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
    local localPlayerVis:table = PlayersVisibility[Game.GetLocalPlayer()];
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
        UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_RELIGION, Game.GetLocalPlayer(), plots, majorityReligionColor );
      end
    end
  end

  -- Find or create religion info instance
  local religionInfoInst = {};
  if cityInst.ReligionInfoAnchor and cityInst[DATA_FIELD_RELIGION_INFO_INSTANCE] == nil then
    ContextPtr:BuildInstanceForControl( "ReligionInfoInstance", religionInfoInst, cityInst.ReligionInfoAnchor );
    cityInst[DATA_FIELD_RELIGION_INFO_INSTANCE] = religionInfoInst;
  else
    religionInfoInst = cityInst[DATA_FIELD_RELIGION_INFO_INSTANCE];
  end

  -- Update religion info instance
  if religionInfoInst and religionInfoInst.ReligionInfoContainer then
    -- Create or reset icon instance manager
    local iconIM:table = cityInst[DATA_FIELD_RELIGION_ICONS_IM];
    if(iconIM == nil) then
      iconIM = InstanceManager:new("ReligionIconInstance", "ReligionIconButtonBacking", religionInfoInst.ReligionInfoIconStack);
      cityInst[DATA_FIELD_RELIGION_ICONS_IM] = iconIM;
    else
      iconIM:ResetInstances();
    end

    -- Create or reset follower list instance manager
    local followerListIM:table = cityInst[DATA_FIELD_RELIGION_FOLLOWER_LIST_IM];
    if(followerListIM == nil) then
      followerListIM = InstanceManager:new("ReligionFollowerListInstance", "ReligionFollowerListContainer", religionInfoInst.ReligionFollowerListStack);
      cityInst[DATA_FIELD_RELIGION_FOLLOWER_LIST_IM] = followerListIM;
    else
      followerListIM:ResetInstances();
    end

    -- Create or reset pop chart instance manager
    local popChartIM:table = cityInst[DATA_FIELD_RELIGION_POP_CHART_IM];
    if(popChartIM == nil) then
      popChartIM = InstanceManager:new("ReligionPopChartInstance", "PopChartMeter", religionInfoInst.ReligionPopChartContainer);
      cityInst[DATA_FIELD_RELIGION_POP_CHART_IM] = popChartIM;
    else
      popChartIM:ResetInstances();
    end

    local populationChartTooltip:string = RELIGION_POP_CHART_TOOLTIP_HEADER;

    -- Add religion icons for each active religion
    for i,religionInfo in ipairs(activeReligions) do
      local religionDef:table = GameInfo.Religions[religionInfo.Religion];

      local icon = "ICON_" .. religionDef.ReligionType;
      local religionColor = UI.GetColorValue(religionDef.Color);

      -- The first index is the predominant religion. Label it as such.
      local religionName = "";
      if i == 1 then
        religionName = Locale.Lookup("LOC_CITY_BANNER_PREDOMINANT_RELIGION", Game.GetReligion():GetName(religionDef.Index));
      else
        religionName = Game.GetReligion():GetName(religionDef.Index);
      end

      -- Add icon to main icon list
      local iconInst:table = iconIM:GetInstance();
      iconInst.ReligionIconButton:SetIcon(icon);
      iconInst.ReligionIconButton:SetColor(religionColor);
      iconInst.ReligionIconButtonBacking:SetColor(religionColor);
      iconInst.ReligionIconButtonBacking:SetToolTipString(religionName);

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

    religionInfoInst.ReligionPopChartContainer:SetToolTipString(populationChartTooltip);

    religionInfoInst.ReligionFollowerListStack:CalculateSize();
    religionInfoInst.ReligionFollowerListScrollPanel:CalculateInternalSize();
    religionInfoInst.ReligionFollowerListScrollPanel:ReprocessAnchoring();

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
      religionInfoInst.ReligionPopChartIcon:SetIcon(iconName);
      religionInfoInst.ReligionPopChartIcon:SetHide(false);
    else
      religionInfoInst.ReligionPopChartIcon:SetHide(true);
    end

    -- Show what religion we will eventually turn into
    local nextReligion = pCityReligion:GetNextReligion();
    local turnsTillNextReligion:number = pCityReligion:GetTurnsToNextReligion();
    if nextReligion and nextReligion ~= -1 and turnsTillNextReligion > 0 then
      local pNextReligionDef:table = GameInfo.Religions[nextReligion];

      -- Religion icon
      if religionInfoInst.ConvertingReligionIcon then
        local religionIcon = "ICON_" .. pNextReligionDef.ReligionType;
        religionInfoInst.ConvertingReligionIcon:SetIcon(religionIcon);
        local religionColor = UI.GetColorValue(pNextReligionDef.Color);
        religionInfoInst.ConvertingReligionIcon:SetColor(religionColor);
        religionInfoInst.ConvertingReligionIconBacking:SetColor(religionColor);
        religionInfoInst.ConvertingReligionIconBacking:SetToolTipString(Locale.Lookup(pNextReligionDef.Name));
      end

      -- Converting text
      local convertString = Locale.Lookup("LOC_CITY_BANNER_CONVERTS_IN_X_TURNS", turnsTillNextReligion);
      religionInfoInst.ConvertingReligionLabel:SetText(convertString);
      religionInfoInst.ReligionConversionTurnsStack:SetHide(false);

      -- If the turns till conversion are less than 10 play the warning flash animation
      religionInfoInst.ConvertingSoonAlphaAnim:SetToBeginning();
      if turnsTillNextReligion <= 10 then
        religionInfoInst.ConvertingSoonAlphaAnim:Play();
      else
        religionInfoInst.ConvertingSoonAlphaAnim:Stop();
      end
    else
      religionInfoInst.ReligionConversionTurnsStack:SetHide(true);
    end

    -- Show how much religion this city is exerting outwards
    local outwardReligiousPressure = pCityReligion:GetPressureFromCity();
    religionInfoInst.ExertedReligiousPressure:SetText(Locale.Lookup("LOC_CITY_BANNER_RELIGIOUS_PRESSURE", Round(outwardReligiousPressure)));

    -- Reset buttons to default state
    religionInfoInst.ReligionInfoButton:SetHide(false);
    religionInfoInst.ReligionInfoDetailedButton:SetHide(true);

    -- Register callbacks to open/close detailed info
    religionInfoInst.ReligionInfoButton:RegisterCallback( Mouse.eLClick, function() OnReligionInfoButtonClicked(religionInfoInst, pCity); end);
    religionInfoInst.ReligionInfoDetailedButton:RegisterCallback( Mouse.eLClick, function() OnReligionInfoDetailedButtonClicked(religionInfoInst, pCity); end);

    religionInfoInst.ReligionInfoContainer:SetHide(false);
  end
end

-- ===========================================================================
function OnReligionInfoButtonClicked( religionInfoInstance:table, pCity:table )
  if (m_pReligionInfoInstance ~= nil) then
    m_pReligionInfoInstance.ReligionInfoButton:SetHide(false);
    m_pReligionInfoInstance.ReligionInfoDetailedButton:SetHide(true);
  end

  religionInfoInstance.ReligionInfoButton:SetHide(true);
  religionInfoInstance.ReligionInfoDetailedButton:SetHide(false);
  UILens.FocusCity(LensLayers.HEX_COLORING_RELIGION, pCity);
  m_pReligionInfoInstance = religionInfoInstance;
end

-- ===========================================================================
function OnReligionInfoDetailedButtonClicked( religionInfoInstance:table, pCity:table )
  UI.AssertMsg(m_pReligionInfoInstance == religionInfoInstance, "more than one panel was open");
  religionInfoInstance.ReligionInfoButton:SetHide(false);
  religionInfoInstance.ReligionInfoDetailedButton:SetHide(true);
  UILens.UnFocusCity(LensLayers.HEX_COLORING_RELIGION, pCity);
  m_pReligionInfoInstance = nil;
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
  iconInst.HolySiteIcon:SetTexture(198, 88, "FontIcons");

  iconInst.Anchor:SetSizeX(iconInst.HolySiteIcon:GetSizeX() + iconInst.HolySiteLabel:GetSizeX());
  iconInst.Anchor:SetToolTipString(Locale.Lookup("LOC_UI_RELIGION_HOLY_SITE_BONUS_TT", label));
end

-- ===========================================================================
function CityBanner.UpdateSelected( self : CityBanner, state : boolean )
  local pCity : table = self:GetCity();
  if (pCity ~= nil) then
    UI.DeselectCity( pCity );
  end
end

-- ===========================================================================
function CityBanner.UpdatePosition( self : CityBanner )
  local yOffset = 0;  --offset for 2D strategic view
  local zOffset = 0;  --offset for 3D world view

  if (UI.GetWorldRenderView() == WorldRenderView.VIEW_2D) then
    yOffset = YOFFSET_2DVIEW;
    zOffset = 0;
  else
    yOffset = 0;
    yOffset = -25 + m_zoomMultiplier*25;
    zOffset = ZOFFSET_3DVIEW;
  end

  if(m_isReligionLensActive and self.m_eMajorityReligion >= 0) then
    yOffset = yOffset + OFFSET_RELIGION_BANNER;
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

        --TODO: Re-evaluate if this can be re-enabled and we have sufficient coverage for updates.
        --if isVisChange then
          local bannerInstance = GetCityBanner( playerID, cityID );
          if (bannerInstance ~= nil) then
            bannerInstance:UpdatePosition( bannerInstance );
          end
        --end
      end
      local playerDistricts = players[i]:GetDistricts();
      for ii, district in playerDistricts:Members() do
        local districtID = district:GetID();
        local locX = district:GetX();
        local locY = district:GetY();
        if (pLocalPlayerVis:IsVisible(locX, locY) == true) then
          OnDistrictVisibilityChanged(playerID, districtID, PLOT_VISIBLE);
          local bannerInstance = GetMiniBanner( playerID, districtID );
          if (bannerInstance ~= nil) then
            bannerInstance:UpdatePosition( bannerInstance );
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
function CityBanner.UpdateRangeStrike( self : CityBanner)

  local controls:table  = self.m_Instance;
  if controls.CityAttackContainer == nil then
    -- This normal behaviour in the case of missile silo and aerodrome minibanners
    return;
  end

  local pDistrict:table = self:GetDistrict();
  if pDistrict ~= nil and self:IsTeam() then
    if (self.m_Player:GetID() == Game.GetLocalPlayer() and CanRangeAttack(pDistrict) ) then
      controls.CityAttackContainer:SetHide(false);
    else
      controls.CityAttackContainer:SetHide(true);
    end
  else
    -- are we looking at an Improvement miniBanner (Airstrip)?
    -- if so, just hide the attack container
    controls.CityAttackContainer:SetHide(true);
  end
end

-- ===========================================================================
function OnCityRangeStrikeButtonClick( playerID, cityID )
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

LuaEvents.CQUI_CityRangeStrike.Add( OnCityRangeStrikeButtonClick ); -- AZURENCY : to acces it in the actionpannel on the city range attack button

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
      UI.SelectCity(pCity);
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
  local bannerInstance = GetCityBanner( playerID, cityID );
  if (bannerInstance ~= nil) then
    bannerInstance:destroy();
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
          local cityBanner = GetCityBanner( playerID, pCity:GetID() );
          if (cityBanner ~= nil) then
            cityBanner.m_DistrictID = districtID;
            cityBanner:UpdateRangeStrike();
            cityBanner:UpdateStats();
            cityBanner:SetColor();
          end
        else
          -- Create a banner for a district that is not the city-center
          local miniBanner = GetMiniBanner( playerID, districtID );
          if (miniBanner == nil) then
            if (pDistrict:IsComplete()) then
              --only create district miniBanners for districts that are completed
              if ( GameInfo.Districts[pDistrict:GetType()].AirSlots > 0 ) then
                AddMiniBannerToMap( playerID, cityID, districtID, BANNERTYPE_AERODROME );
              elseif (pDistrict:GetDefenseStrength() > 0 ) then
                AddMiniBannerToMap( playerID, cityID, districtID, BANNERTYPE_ENCAMPMENT );
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

  -- Right now we're only interested in the Airstrip improvement
  if ( improvementData.AirSlots == 0 and improvementData.WeaponSlots == 0) then
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
        end
      else
        miniBanner.UpdateStats();
        miniBanner.SetColor();
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
      bannerInstance:SetFogState( eVisibility );
    end
  end
end

-- ===========================================================================
function OnCityVisibilityChanged( playerID: number, cityID : number, eVisibility : number)
  local bannerInstance = GetCityBanner( playerID, cityID );
  if (bannerInstance ~= nil) then
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
  -- We're only interested in the Airstrip or Missile Silo improvements
  if ( GameInfo.Improvements[eImprovementType].AirSlots > 0 or GameInfo.Improvements[eImprovementType].WeaponSlots > 0) then
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
  else
    return;
  end
end

-- ===========================================================================
function OnBuildingChanged( plotX:number, plotY:number, buildingIndex:number, playerID:number, iPercentComplete:number)

  local pPlayer = Players[playerID];
  if (pPlayer ~= nil and pPlayer:GetCities() ~= nil) then

    -- Update the capital, since for now capital status is shown in name
    local pCapital = pPlayer:GetCities():GetCapitalCity();
    if (pCapital ~= nil) then
      local bannerInstance = GetCityBanner( playerID, pCapital:GetID() );
      if (bannerInstance ~= nil) then
        bannerInstance:UpdateName();
      end
    end

    -- Update the city defenses UI if walls were constructed
    if (playerID == Game.GetLocalPlayer()) then
      local pCity = CityManager.GetCityAt(plotX, plotY);
      if (pCity ~= nil) then
        local cityBanner = GetCityBanner( playerID, pCity:GetID() );
        if (cityBanner ~= nil) then
          cityBanner:UpdateRangeStrike();
        end
      end
    end
  end

end

-- ===========================================================================
function OnCityNameChange( playerID: number, cityID : number)

  local banner:CityBanner = GetCityBanner( playerID, cityID );
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

  local banner:CityBanner = GetCityBanner( playerID, cityID );
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

  local banner:CityBanner = GetCityBanner( playerID, cityID );
  if (banner ~= nil and banner.m_Instance.ReligionInfoAnchor ~= nil and banner:IsVisible()) then
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
  end
end

-- ===========================================================================
--  Game Event
-- ===========================================================================
function OnDiplomacyMakePeace( firstPlayerID:number, secondPlayerID:number )
  local localPlayer = Game.GetLocalPlayer();
  if firstPlayerID == localPlayer or secondPlayerID == localPlayer then
    m_refreshLocalPlayerRangeStrike = true;
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
    UILens.ClearLayerHexes( LensLayers.HEX_COLORING_RELIGION );
  end

  for _, playerBannerInstances in pairs(CityBannerInstances) do
    for id, banner in pairs(playerBannerInstances) do
      if (banner ~= nil and banner.m_Instance.ReligionInfoAnchor ~= nil and banner:IsVisible()) then
        banner:UpdateReligion();
        banner:UpdatePosition();
      end
    end
    end
end

-- ===========================================================================
function OnContextInitialize( isHotload : boolean )
  if isHotload then
    Reload();
    LuaEvents.GameDebug_GetValues( "CityBannerManager" );
  end
end

-- ===========================================================================
--  Handle the UI shutting down.
function OnShutdown()
  -- Cache value for hotloading...
  LuaEvents.GameDebug_AddValue("CityBannerManager", "m_isReligionLensActive", m_isReligionLensActive);

  m_CityCenterTeamIM:ResetInstances();
  m_CityCenterOtherIM:ResetInstances();
  DirtyComponentsManager.Destroy( m_pDirtyCityComponents );
  m_pDirtyCityComponents = nil;
  CQUI_PlotIM:DestroyInstances();
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
  if layerNum == LensLayers.HEX_COLORING_RELIGION then
    m_isReligionLensActive = true;
    RealizeReligion();
  end

  -- ASTOG: Hack solution to appeal lens being cleared on entry to city.
  -- it is worse when citizen changes since it causes a complete refresh of lenses including resource icons and yield icons
  -- TODO: Improve this system so it does not cause a complete refresh
  -- if CQUI_ShowCityManageAreaInScreen then
  --   if layerNum == LensLayers.CITIZEN_MANAGEMENT then
  --     local pCity:table = UI.GetHeadSelectedCity()
  --     if pCity ~= nil then
  --       UILens.SetActive("Appeal")
  --       CQUI_ShowCitizenManagementLens(pCity:GetID())
  --     end
  --   end

  --   -- Should we reapply citizen management area because it got cleared?
  --   if layerNum == LensLayers.HEX_COLORING_APPEAL_LEVEL and CQUI_CityManageAreaShouldShow then
  --     local pCity:table = UI.GetHeadSelectedCity()
  --     if pCity ~= nil then
  --       UILens.SetActive("Appeal")
  --       CQUI_ShowCitizenManagementLens(pCity:GetID())
  --       CQUI_CityManageAreaShouldShow = false
  --     end
  --   end
  -- end
end

-- ===========================================================================
--  Gamecore Event
--  Called once per layer that is turned on when a new lens is deactivated,
--  or when a player explicitly turns off the layer from the "player" lens.
-- ===========================================================================
function OnLensLayerOff( layerNum:number )
  if  layerNum == LensLayers.HEX_COLORING_RELIGION then
    m_isReligionLensActive = false;
    RealizeReligion();
  end

  -- Catch uninteded clear of appeal lens because of event chain
  -- if CQUI_ShowCityManageAreaInScreen then
  --   if layerNum == LensLayers.HEX_COLORING_APPEAL_LEVEL and CQUI_CityManageAreaShown then
  --     UILens.SetActive("Appeal")
  --     CQUI_CityManageAreaShouldShow = true
  --     CQUI_CityManageAreaShown = false
  --   end
  -- end
end

-- ===========================================================================
--  LUA Event
--  Set cached values back after a hotload.
-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
  if context == "CityBannerManager" then
    m_isReligionLensActive = contextTable["m_isReligionLensActive"];
    RealizeReligion();
  end
end

-- ===========================================================================
function OnSelectionChanged(owner, ID, i, j, k, bSelected, bEditable)
  banner = GetCityBanner(owner, ID);
  -- OnSelectionChanged event can only change one banner at a time
  if (banner ~= nil and owner == Game.GetLocalPlayer()) then
    banner.m_IsSelected = bSelected;
    banner:SetColor();
  end
end

function OnCameraUpdate( vFocusX:number, vFocusY:number, fZoomLevel:number )

  -- If no change in the zoom, no update necessary.
  if (1-fZoomLevel) == m_zoomMultiplier then
    return;
  end
  m_zoomMultiplier= 1-fZoomLevel;

  if ( math.abs(m_zoomMultiplier-m_prevZoomMultiplier) > ZOOM_MULT_DELTA) then
    OnRefreshBannerPositions();
  end
  m_prevZoomMultiplier = m_zoomMultiplier;
end

-- ===========================================================================
function CQUI_ShowCitizenManagementLens(cityID:number)
  local playerID:number = Game.GetLocalPlayer()
  local pCity:table = Players[playerID]:GetCities():FindID(cityID);
  if pCity ~= nil then
    print_debug("Show citizens for " .. Locale.Lookup(pCity:GetName()))

    local tParameters:table = {};
    local cityPlotID = Map.GetPlot(pCity:GetX(), pCity:GetY()):GetIndex()
    tParameters[CityCommandTypes.PARAM_MANAGE_CITIZEN] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_MANAGE_CITIZEN);

    local workingColor:number = UI.GetColorValue("COLOR_CITY_PLOT_WORKING");
    local lockedColor:number = UI.GetColorValue("COLOR_CITY_PLOT_LOCKED");
    local colorPlot:table = {}
    colorPlot[workingColor] = {}
    colorPlot[lockedColor] = {}

    -- Get city plot and citizens info
    local tResults:table = CityManager.GetCommandTargets(pCity, CityCommandTypes.MANAGE, tParameters);
    if tResults == nil then
      print("ERROR : Could not find plots")
      return
    end

    local tPlots:table = tResults[CityCommandResults.PLOTS];
    local tUnits:table = tResults[CityCommandResults.CITIZENS];
    local tLockedUnits:table = tResults[CityCommandResults.LOCKED_CITIZENS];

    if tPlots ~= nil and table.count(tPlots) > 0 then
      for i, plotID in ipairs(tPlots) do
        if (tLockedUnits[i] > 0 or cityPlotID == plotID) then
          table.insert(colorPlot[lockedColor], plotID);
        elseif (tUnits[i] > 0) then
          table.insert(colorPlot[workingColor], plotID);
        end
      end
    end

    -- Next culture expansion plot, show it only if not in city panel
    if UI.GetHeadSelectedCity() == nil then
      local pCityCulture:table  = pCity:GetCulture();
      local culturePlotColor:number = UI.GetColorValue("COLOR_CITY_PLOT_CULTURE")
      if pCityCulture ~= nil then
        local pNextPlotID:number = pCityCulture:GetNextPlot();
        if pNextPlotID ~= nil and Map.IsPlot(pNextPlotID) then
          colorPlot[culturePlotColor] = {pNextPlotID}
        end
      end
    end

    CQUI_CityManageAreaShown = true;
    LuaEvents.MinimapPanel_ApplyCustomLens(colorPlot);
  end
end

-- ===========================================================================
function CQUI_ClearCitizenManagementLens()
  CQUI_CityManageAreaShown = false;
  LuaEvents.MinimapPanel_ClearCustomLens()
end

-- ===========================================================================
function CQUI_RefreshCitizenManagementLens(cityID:number)
  CQUI_ClearCitizenManagementLens()
  CQUI_ShowCitizenManagementLens(cityID)
end

-- ===========================================================================
function CQUI_OnInfluenceGiven()
  for i, pPlayer in ipairs(PlayerManager.GetAliveMinors()) do
    local iPlayer = pPlayer:GetID();
    local iCapital = pPlayer:GetCities():GetCapitalCity():GetID();
    local bannerInstance = GetCityBanner(iPlayer, iCapital);
    CQUI_UpdateSuzerainIcon(pPlayer, bannerInstance);
  end
end

function CQUI_UpdateSuzerainIcon( pPlayer:table, bannerInstance:CityBanner )
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
  if newMode == InterfaceModeTypes.MAKE_TRADE_ROUTE then
    -- Show trading post icons on cities that contain a trading post with the local player
    local localPlayerID:number = Game.GetLocalPlayer();
    for _, playerBannerInstances in pairs(CityBannerInstances) do
      for id, banner in pairs(playerBannerInstances) do
        if banner ~= nil then
          if banner:GetCity():GetTrade():HasActiveTradingPost(localPlayer) then
            banner.m_Instance.TradingPostIcon:SetHide(false);
            banner.m_Instance.TradingPostDisabledIcon:SetHide(true);
          elseif banner:GetCity():GetTrade():HasInactiveTradingPost(localPlayer) then
            banner.m_Instance.TradingPostIcon:SetHide(false);
            banner.m_Instance.TradingPostDisabledIcon:SetHide(false);
          else
            banner.m_Instance.TradingPostIcon:SetHide(true);
          end

          banner.m_Instance.CityNameStack:CalculateSize();
          banner.m_Instance.CityNameStack:ReprocessAnchoring();
        end
      end
    end
  elseif oldMode == InterfaceModeTypes.MAKE_TRADE_ROUTE then
    -- Hide all trading post icons
    for _, playerBannerInstances in pairs(CityBannerInstances) do
      for id, banner in pairs(playerBannerInstances) do
        if banner ~= nil then
          banner.m_Instance.TradingPostIcon:SetHide(true);
          banner.m_Instance.CityNameStack:CalculateSize();
          banner.m_Instance.CityNameStack:ReprocessAnchoring();
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
-- CQUI calculate real housing from improvements
function CQUI_RealHousingFromImprovements(pCity)
  local CQUI_HousingFromImprovements = 0;
  local pCityID = pCity:GetID();
  local tParameters :table = {};
  tParameters[CityCommandTypes.PARAM_MANAGE_CITIZEN] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_MANAGE_CITIZEN);
  local tResults :table = CityManager.GetCommandTargets( pCity, CityCommandTypes.MANAGE, tParameters );
  local tPlots :table = tResults[CityCommandResults.PLOTS];
  if tPlots ~= nil and (table.count(tPlots) > 0) then
    for i, plotId in pairs(tPlots) do
      local kPlot	:table = Map.GetPlotByIndex(plotId);
      local eImprovementType :number = kPlot:GetImprovementType();
      if( eImprovementType ~= -1 ) then
        local kImprovementData = GameInfo.Improvements[eImprovementType].Housing;
        if kImprovementData == 1 then    -- farms, pastures etc.
          CQUI_HousingFromImprovements = CQUI_HousingFromImprovements + 1;
        elseif kImprovementData == 2 then    -- stepwells and kampungs
          if eImprovementType == 23 then    -- stepwells (Index == 23)
            local CQUI_PlayerResearchedSanitation :boolean = Players[Game.GetLocalPlayer()]:GetTechs():HasTech(40);    -- check if a player researched Sanitation (Index == 40)
            if not CQUI_PlayerResearchedSanitation then
              CQUI_HousingFromImprovements = CQUI_HousingFromImprovements + 2;
            else
              CQUI_HousingFromImprovements = CQUI_HousingFromImprovements + 4;
            end
          else    -- kampungs (Index == 26, but after load a game Index == 25)
            local CQUI_PlayerResearchedMassProduction :boolean = Players[Game.GetLocalPlayer()]:GetTechs():HasTech(27);    -- check if a player researched Mass Production (Index == 27)
            if not CQUI_PlayerResearchedMassProduction then
              CQUI_HousingFromImprovements = CQUI_HousingFromImprovements + 2;
            else
              CQUI_HousingFromImprovements = CQUI_HousingFromImprovements + 4;
            end
          end
        end
      end
    end
    CQUI_HousingFromImprovements = CQUI_HousingFromImprovements * 0.5;
    CQUI_HousingFromImprovementsTable[pCityID] = CQUI_HousingFromImprovements;
    CQUI_HousingUpdated[pCityID] = true;
    LuaEvents.CQUI_RealHousingFromImprovementsCalculated(pCityID, CQUI_HousingFromImprovements);
  else
    return;
  end
end

-- ===========================================================================
-- CQUI update city's real housing from improvements
function CQUI_OnCityInfoUpdated(pCityID)
  CQUI_HousingUpdated[pCityID] = false;
end

-- ===========================================================================
-- CQUI update all cities real housing from improvements
function CQUI_OnAllCitiesInfoUpdated()
  local m_pCity:table = Players[Game.GetLocalPlayer()]:GetCities();
  for i, pCity in m_pCity:Members() do
    local pCityID = pCity:GetID();
    CQUI_HousingUpdated[pCityID] = false;
  end
end

-- ===========================================================================
function Initialize()

  RegisterDirtyEvents();

  ContextPtr:SetInitHandler( OnContextInitialize );
  ContextPtr:SetShutdown( OnShutdown );

  Events.BeginWonderReveal.Add(       OnBeginWonderReveal );
  Events.BuildingChanged.Add(         OnBuildingChanged);
  Events.Camera_Updated.Add(          OnCameraUpdate );
  Events.CapitalCityChanged.Add(        OnCapitalCityChanged);
  Events.CityAddedToMap.Add(          OnCityAddedToMap );
  Events.CityDefenseStatusChanged.Add(    OnCityDefenseStatusChanged );
  Events.CityFocusChanged.Add(        OnCityFocusChange );
  Events.CityNameChanged.Add(         OnCityNameChange );
  Events.CityProductionChanged.Add(     OnCityProductionChanged);
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
  Events.CitySiegeStatusChanged.Add(      OnSiegeStatusChanged);
  Events.GameCoreEventPublishComplete.Add(	FlushChanges); --This event is raised directly after a series of gamecore events.
  Events.CityWorkerChanged.Add(           OnCityWorkerChanged );

  LuaEvents.CQUI_CityInfoUpdated.Add( CQUI_OnCityInfoUpdated );    -- CQUI update city's real housing from improvements
  LuaEvents.CQUI_CityLostTileToCultureBomb.Add( CQUI_OnAllCitiesInfoUpdated );    -- CQUI update all cities real housing from improvements
  LuaEvents.CQUI_IndiaPlayerResearchedSanitation.Add( CQUI_OnAllCitiesInfoUpdated );    -- CQUI update all cities real housing from improvements
  LuaEvents.CQUI_IndonesiaPlayerResearchedMassProduction.Add( CQUI_OnAllCitiesInfoUpdated );    -- CQUI update all cities real housing from improvements

  LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);

  LuaEvents.CQUI_SettingsInitialized.Add( CQUI_OnSettingsInitialized );
  Events.CitySelectionChanged.Add( CQUI_OnBannerMouseExit );
  Events.InfluenceGiven.Add( CQUI_OnInfluenceGiven );

  LuaEvents.CQUI_ShowCitizenManagement.Add( CQUI_ShowCitizenManagementLens );
  LuaEvents.CQUI_RefreshCitizenManagement.Add( CQUI_RefreshCitizenManagementLens );
  LuaEvents.CQUI_ClearCitizenManagement.Add( CQUI_ClearCitizenManagementLens );
end
Initialize();

