--CityPanelOverview
--Triggered by selecting a city

include( "AdjacencyBonusSupport" );   -- GetAdjacentYieldBonusString()
include( "Civ6Common" );        -- GetYieldString()
include( "InstanceManager" );
include( "ToolTipHelper" ); 
include( "SupportFunctions" );      -- Round(), Clamp()
include( "TabSupport" );  

-- ===========================================================================
--  CONSTANTS
-- ===========================================================================
local DATA_DOMINANT_RELIGION    :string = "_DOMINANTRELIGION";
local SIZE_LEADER_ICON        :number = 32;
local SIZE_PRODUCTION_ICON      :number = 32; -- TODO: Switch this to 38 when the icons go in.
local SIZE_PANEL_X          :number = 300;
local TXT_NO_PRODUCTION       :string = Locale.Lookup("LOC_HUD_CITY_PRODUCTION_NOTHING_PRODUCED");

local UV_CITIZEN_GROWTH_STATUS    :table  = {};
    UV_CITIZEN_GROWTH_STATUS[0] = {u=0, v=0  };   -- revolt
    UV_CITIZEN_GROWTH_STATUS[1] = {u=0, v=0 };    -- unrest
    UV_CITIZEN_GROWTH_STATUS[2] = {u=0, v=0};   -- unhappy
    UV_CITIZEN_GROWTH_STATUS[3] = {u=0, v=50};    -- displeased
    UV_CITIZEN_GROWTH_STATUS[4] = {u=0, v=100};   -- content (normal)
    UV_CITIZEN_GROWTH_STATUS[5] = {u=0, v=150};   -- happy
    UV_CITIZEN_GROWTH_STATUS[6] = {u=0, v=200};   -- ecstatic

local UV_HOUSING_GROWTH_STATUS    :table = {};
    UV_HOUSING_GROWTH_STATUS[0] = {u=0, v=0};   -- halted
    UV_HOUSING_GROWTH_STATUS[1] = {u=0, v=50};    -- slowed
    UV_HOUSING_GROWTH_STATUS[2] = {u=0, v=100};   -- normal

local UV_CITIZEN_STARVING_STATUS    :table = {};
    UV_CITIZEN_STARVING_STATUS[0] = {u=0, v=0};   -- starving
    UV_CITIZEN_STARVING_STATUS[1] = {u=0, v=100}; -- normal
    UV_CITIZEN_STARVING_STATUS[2] = {u=0, v=150}; -- growing


local YIELD_STATE :table = {
    NORMAL  = 0,
    FAVORED = 1,
    IGNORED = 2
}


-- ===========================================================================
--  VARIABLES
-- ===========================================================================

local m_kAmenitiesIM    :table  = InstanceManager:new( "AmenityInstance",     "Top", Controls.AmenityStack );
local m_kBuildingsIM    :table  = InstanceManager:new( "BuildingInstance",      "Top");
local m_kDistrictsIM    :table  = InstanceManager:new( "DistrictInstance",      "Top", Controls.BuildingAndDistrictsStack );
local m_kHousingIM      :table  = InstanceManager:new( "HousingInstance",     "Top", Controls.HousingStack );
local m_kOtherReligionsIM :table  = InstanceManager:new( "OtherReligionInstance",   "Top", Controls.OtherReligions );
local m_kProductionIM   :table  = InstanceManager:new( "ProductionInstance",    "Top", Controls.ProductionQueueStack );
local m_kReligionsBeliefsIM :table  = InstanceManager:new( "ReligionBeliefsInstance", "Top", Controls.ReligionBeliefsStack );
local m_kTradingPostsIM   :table  = InstanceManager:new( "TradingPostInstance",   "Top", Controls.TradingPostsStack );
local m_kWondersIM      :table  = InstanceManager:new( "WonderInstance",      "Top", Controls.WondersStack );

local m_kData       :table  = nil;
local m_isDirty       :boolean= false;
local m_isInitializing    :boolean= false;    
local m_isShowingPanels   :boolean= false;
local m_pCity       :table  = nil;
local m_pPlayer       :table  = nil;
local m_primaryColor    :number = 0xcafef00d; 
local m_secondaryColor    :number = 0xf00d1ace;

local ms_eventID = 0;
local m_tabs;
local m_isShowingPanel    :boolean = false;

-- ====================CQUI Cityview==========================================
  
  function CQUI_OnCityviewEnabled()
    OnShowOverviewPanel(true)
  end
  
  function CQUI_OnCityviewDisabled()
    OnShowOverviewPanel(false);
  end
  
  LuaEvents.CQUI_CityPanelOverview_CityviewEnable.Add( CQUI_OnCityviewEnabled);
  LuaEvents.CQUI_CityPanelOverview_CityviewDisable.Add( CQUI_OnCityviewDisabled);

-- ===========================================================================

function UpdateYieldData( data:table )
  data.CulturePerTurn       = Round( m_pCity:GetYield( YieldTypes.CULTURE ), 1);
  data.CulturePerTurnToolTip    = m_pCity:GetYieldToolTip(YieldTypes.CULTURE);

  data.FaithPerTurn       = Round( m_pCity:GetYield( YieldTypes.FAITH ), 1);
  data.FaithPerTurnToolTip    = m_pCity:GetYieldToolTip(YieldTypes.FAITH);

  data.FoodPerTurn        = Round( m_pCity:GetYield( YieldTypes.FOOD ), 1);
  data.FoodPerTurnToolTip     = m_pCity:GetYieldToolTip(YieldTypes.FOOD);

  data.GoldPerTurn        = Round( m_pCity:GetYield( YieldTypes.GOLD ), 1);
  data.GoldPerTurnToolTip     = m_pCity:GetYieldToolTip(YieldTypes.GOLD);

  data.ProductionPerTurn      = Round( m_pCity:GetYield( YieldTypes.PRODUCTION ),1);
  data.ProductionPerTurnToolTip = m_pCity:GetYieldToolTip(YieldTypes.PRODUCTION);

  data.SciencePerTurn       = Round( m_pCity:GetYield( YieldTypes.SCIENCE ), 1);
  data.SciencePerTurnToolTip    = m_pCity:GetYieldToolTip(YieldTypes.SCIENCE);

  return data;
end

function HideAll()
  Controls.HealthButton:SetSelected(false);
  Controls.HealthIcon:SetColorByName("White");
  Controls.BuildingsButton:SetSelected(false);
  Controls.BuildingsIcon:SetColorByName("White");
  Controls.ReligionButton:SetSelected(false);
  Controls.ReligionIcon:SetColorByName("White");
  --Controls.QueueButton:SetSelected(false);
  --Controls.QueueIcon:SetColorByName("White");
  --Controls.StrengthButton:SetSelected(false);
  --Controls.StrengthIcon:SetColorByName("White");

  Controls.PanelBreakdown:SetHide(true);
  Controls.PanelReligion:SetHide(true);
  Controls.PanelAmenities:SetHide(true);
  Controls.PanelHousing:SetHide(true);
  Controls.PanelCitizensGrowth:SetHide(true);
  Controls.PanelProductionNow:SetHide(true);
  Controls.PanelQueue:SetHide(true);

  --UILens.ToggleLayerOff(LensLayers.ADJACENCY_BONUS_DISTRICTS);
  --UILens.ToggleLayerOff(LensLayers.DISTRICTS);
end

function CalculateSizeAndAccomodate(scrollPanelControl: table, stackControl: table)
  local adjustedSizeX;
  stackControl:CalculateSize();
  stackControl:ReprocessAnchoring();
  scrollPanelControl:CalculateSize();
  
  if(scrollPanelControl:GetRatio()<1) then
    adjustedSizeX = SIZE_PANEL_X-12;
  else  
    adjustedSizeX = SIZE_PANEL_X;
  end
  scrollPanelControl:SetSizeX(adjustedSizeX);
  stackControl:SetSizeX(adjustedSizeX);

  scrollPanelControl:CalculateSize();
  
  stackControl:CalculateSize();
  stackControl:ReprocessAnchoring();
end

function OnSelectHealthTab()
  HideAll();
  Controls.HealthButton:SetSelected(true);
  Controls.HealthIcon:SetColorByName("DarkBlue");
  
  if(m_kData ~= nil) then
        UI.PlaySound("UI_CityPanel_ButtonClick");
    ViewPanelAmenities( m_kData );
    ViewPanelCitizensGrowth( m_kData );
    ViewPanelHousing( m_kData );
  end

  Controls.PanelAmenities:SetHide(false);
  Controls.PanelHousing:SetHide(false);
  Controls.PanelCitizensGrowth:SetHide(false);
  
  CalculateSizeAndAccomodate(Controls.PanelScrollPanel, Controls.PanelStack);
end

function OnSelectBuildingsTab()
  HideAll();

  Controls.BuildingsButton:SetSelected(true);
  Controls.BuildingsIcon:SetColorByName("DarkBlue");
  UI.PlaySound("UI_CityPanel_ButtonClick");
  
  if(m_kData ~= nil) then
    ViewPanelBreakdown( m_kData );
  end
  Controls.PanelBreakdown:SetHide(false);
  
  --UILens.ToggleLayerOn(LensLayers.ADJACENCY_BONUS_DISTRICTS);
  --UILens.ToggleLayerOn(LensLayers.DISTRICTS);

  CalculateSizeAndAccomodate(Controls.PanelScrollPanel, Controls.PanelStack);
end
function OnSelectReligionTab()
  HideAll();
  Controls.ReligionButton:SetSelected(true);
  Controls.ReligionIcon:SetColorByName("DarkBlue");
  UI.PlaySound("UI_CityPanel_ButtonClick");
  
  if(m_kData ~= nil) then
    ViewPanelReligion( m_kData );
  end
  Controls.PanelReligion:SetHide(false);

  CalculateSizeAndAccomodate(Controls.PanelScrollPanel, Controls.PanelStack);
end

--function OnSelectQueueTab()
--  HideAll();
--  Controls.QueueButton:SetSelected(true);
--  Controls.QueueIcon:SetColorByName("DarkBlue");
--  UI.PlaySound("UI_CityPanel_ButtonClick");

--  if(m_kData ~= nil) then
--    ViewPanelQueue( m_kData );
--  end
--  Controls.PanelQueue:SetHide(false);
--  CalculateSizeAndAccomodate(Controls.PanelScrollPanel, Controls.PanelStack);
--end

--function OnSelectStrengthTab()
--  HideAll();
--  UI.PlaySound("UI_CityPanel_ButtonClick");
--  Controls.StrengthButton:SetSelected(true);
--  Controls.StrengthIcon:SetColorByName("DarkBlue");
--  CalculateSizeAndAccomodate(Controls.PanelScrollPanel, Controls.PanelStack);
--end

-- ===========================================================================
function ViewPanelBreakdown( data:table ) 
  Controls.DistrictsNum:SetText( data.DistrictsNum );
  Controls.DistrictsConstructed:SetText( Locale.Lookup("LOC_HUD_CITY_DISTRICTS_CONSTRUCTED", data.DistrictsNum) );  
  Controls.DistrictsPossibleNum:SetText( data.DistrictsPossibleNum );

  m_kBuildingsIM:ResetInstances();
  m_kDistrictsIM:ResetInstances();  
  m_kTradingPostsIM:ResetInstances();
  m_kWondersIM:ResetInstances();

  -- Add districts (and their buildings)
  for _, district in ipairs(data.BuildingsAndDistricts) do
    if district.isBuilt then
      local kInstanceDistrict:table = m_kDistrictsIM:GetInstance();
      local districtName = district.Name;
      if district.isPillaged then
        districtName = districtName .. "[ICON_Pillaged]";
      end
      kInstanceDistrict.DistrictName:SetText( districtName );
      kInstanceDistrict.DistrictYield:SetText( district.YieldBonus );
      kInstanceDistrict.Icon:SetIcon( district.Icon );
      for _,building in ipairs(district.Buildings) do
        if building.isBuilt then
          local kInstanceBuild:table = m_kBuildingsIM:GetInstance(kInstanceDistrict.BuildingStack);
          local buildingName = building.Name;
          if building.isPillaged then
            buildingName = buildingName .. "[ICON_Pillaged]";
          end
          kInstanceBuild.BuildingName:SetText( buildingName );
          kInstanceBuild.Icon:SetIcon( building.Icon );
          local yieldString:string = "";
          for _,kYield in ipairs(building.Yields) do
            yieldString = yieldString .. GetYieldString(kYield.YieldType,kYield.YieldChange);
          end
          kInstanceBuild.BuildingYield:SetText( yieldString );
        end
      end
      kInstanceDistrict.BuildingStack:CalculateSize();
      kInstanceDistrict.BuildingStack:ReprocessAnchoring();
    end
  end

  -- Add wonders
  local isHasWonders :boolean = (table.count(data.Wonders) > 0)
  Controls.NoWondersArea:SetHide( isHasWonders );
  Controls.WondersArea:SetHide( not isHasWonders );

  for _, wonder in ipairs(data.Wonders) do
    local kInstanceWonder:table = m_kWondersIM:GetInstance();
    kInstanceWonder.WonderName:SetText( wonder.Name );      
    local yieldString:string = "";
    for _,kYield in ipairs(wonder.Yields) do
      yieldString = yieldString .. GetYieldString(kYield.YieldType,kYield.YieldChange);
    end
    kInstanceWonder.WonderYield:SetText( yieldString );
    kInstanceWonder.Icon:SetIcon( wonder.Icon );
  end

  -- Add trading posts
  local isHasTradingPosts :boolean = (table.count(data.TradingPosts) > 0)
  Controls.NoTradingPostsArea:SetHide( isHasTradingPosts );
  Controls.TradingPostsArea:SetHide( not isHasTradingPosts );
  
  if isHasTradingPosts then
    for _, tradePostPlayerId in ipairs(data.TradingPosts) do
      local kInstanceTradingPost  :table = m_kTradingPostsIM:GetInstance();   
      local playerName      :string = Locale.Lookup( PlayerConfigurations[tradePostPlayerId]:GetPlayerName() );
      local iconName        :string = "ICON_"..PlayerConfigurations[tradePostPlayerId]:GetLeaderTypeName();
      local textureOffsetX :number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas(iconName, SIZE_LEADER_ICON);
    
      kInstanceTradingPost.LeaderPortrait:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
      kInstanceTradingPost.LeaderPortrait:SetHide(false);         
      if tradePostPlayerId == m_pPlayer:GetID() then
        playerName = playerName .. " (" .. Locale.Lookup("LOC_HUD_CITY_YOU") .. ")";
      end
      kInstanceTradingPost.TradingPostName:SetText( playerName );
    end
  end

  Controls.PanelBreakdown:ReprocessAnchoring(); 
end


-- ===========================================================================
function ViewPanelReligion( data:table )  

  -- Precursor to religion:
  Controls.PantheonArea:SetHide( data.PantheonBelief == -1 );
  if data.PantheonBelief > -1 then
    local kPantheonBelief = GameInfo.Beliefs[data.PantheonBelief];
    Controls.PantheonBelief:SetText( Locale.Lookup(kPantheonBelief.Name) );
    Controls.PantheonBelief:SetToolTipString( Locale.Lookup(kPantheonBelief.Description) );
  end

  local isHasReligion :boolean = (table.count(data.Religions) > 0) and (data.PantheonBelief > -1);
  Controls.NoReligionArea:SetHide( isHasReligion );
  Controls.StackReligion:SetHide( not isHasReligion );

  if isHasReligion then

    m_kReligionsBeliefsIM:ResetInstances();
    m_kOtherReligionsIM:ResetInstances();

    for _, beliefIndex in ipairs(data.BeliefsOfDominantReligion) do
      local kBeliefInstance :table = m_kReligionsBeliefsIM:GetInstance();
      local kBelief     :table = GameInfo.Beliefs[beliefIndex];
      kBeliefInstance.Top:SetText( Locale.Lookup(kBelief.Name) );
      kBeliefInstance.Top:SetToolTipString( Locale.Lookup(kBelief.Description) );
    end


    for _,religion in ipairs(data.Religions) do   
      
      local religionName  :string = Game.GetReligion():GetName(religion.ID);
      local iconName    :string = "ICON_" .. religion.ReligionType;
      local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas(iconName);

      Controls.DominantReligionGrid:SetHide(true);
      if textureSheet ~= nil then
        if religion == data.Religions[DATA_DOMINANT_RELIGION] then
          -- Dominant religion
          Controls.DominantReligionGrid:SetHide(false);
          Controls.DominantReligionSymbol:SetHide(false);
          Controls.DominantReligionSymbol:SetTexture( textureSheet );
          Controls.DominantReligionSymbol:SetTextureOffsetVal( textureOffsetX, textureOffsetY );
          Controls.DominantReligionName:SetText( Locale.Lookup("LOC_HUD_CITY_RELIGIOUS_CITIZENS_NUMBER",religion.Followers,religionName) );
        elseif religion.ReligionType ~= "RELIGION_PANTHEON" then
          -- Other religion
          local religionInstance:table = m_kOtherReligionsIM:GetInstance(); 
          religionInstance.ReligionSymbol:SetTexture( textureSheet );
          religionInstance.ReligionSymbol:SetTextureOffsetVal( textureOffsetX, textureOffsetY );
          religionInstance.ReligionName:SetText( Locale.Lookup("LOC_HUD_CITY_RELIGIOUS_CITIZENS_NUMBER",religion.Followers,religionName) );
        end
      else
        error("Unable to find texture "..iconName.." in a texture sheet for a CityPanel's religion symbol.");
      end
      
    end

  else
    
  end
  Controls.PanelReligion:ReprocessAnchoring();  
end

-- ===========================================================================
--  Return ColorSet name
-- ===========================================================================
function GetHappinessColor( eHappiness:number )
  local happinessInfo = GameInfo.Happinesses[eHappiness];
  if (happinessInfo ~= nil) then
    if (happinessInfo.GrowthModifier < 0) then return "StatBadCSGlow"; end
    if (happinessInfo.GrowthModifier > 0) then return "StatGoodCSGlow"; end
  end
  return "StatNormalCSGlow";
end

-- ===========================================================================
--  Return ColorSet name
-- ===========================================================================
function GetTurnsUntilGrowthColor( turns:number )
  if  turns < 1 then return "StatBadCSGlow"; end
  return "StatGoodCSGlow";  
end

function GetPercentGrowthColor( percent:number )
  if percent == 0 then return "Error"; end
  if percent <= 0.25 then return "WarningMajor"; end
  if percent <= 0.5 then return "WarningMinor"; end
  return "StatNormalCSGlow";
end

function GetAmenetiesColor( count:number )
  if count > 0 then return "StatGoodCSGlow" end
  if count < 0 then return "StatBadCSGlow" end
  return "StatNormalCSGlow";
end

-- ===========================================================================
function ViewPanelAmenities( data:table ) 
  -- Only show the advisor bubbles during the tutorial
  Controls.AmenitiesAdvisorBubble:SetHide( IsTutorialRunning() == false );

  -- new ameneties section
  Controls.AmenityStack:SetHide( true );

  Controls.AmenetiesStatusIconContainerLuxuries:SetTextureOffsetVal(0, 100);
  Controls.AmenetiesStatusYieldLuxuries:SetText( Locale.ToNumber(data.AmenitiesFromLuxuries) );
  Controls.AmenetiesStatusYieldLuxuries:SetColorByName( GetAmenetiesColor(data.AmenitiesFromLuxuries) );
  Controls.AmenetiesStatusYieldLuxuries:SetFontSize(24);
  Controls.AmenetiesStatusIconLuxuries:SetColor(0x3fffffff);
  Controls.AmenetiesStatusLabelLuxuries:SetColor(0xffffffff);

  Controls.AmenetiesStatusIconContainerCivics:SetTextureOffsetVal(0, 100);
  Controls.AmenetiesStatusYieldCivics:SetText( Locale.ToNumber(data.AmenitiesFromCivics) );
  Controls.AmenetiesStatusYieldCivics:SetColorByName( GetAmenetiesColor(data.AmenitiesFromCivics) );
  Controls.AmenetiesStatusYieldCivics:SetFontSize(24);
  Controls.AmenetiesStatusIconCivics:SetColor(0x3fffffff);
  Controls.AmenetiesStatusLabelCivics:SetColor(0xffffffff);

  Controls.AmenetiesStatusIconContainerEntertainment:SetTextureOffsetVal(0, 100);
  Controls.AmenetiesStatusYieldEntertainment:SetText( Locale.ToNumber(data.AmenitiesFromEntertainment) );
  Controls.AmenetiesStatusYieldEntertainment:SetColorByName( GetAmenetiesColor(data.AmenitiesFromEntertainment) );
  Controls.AmenetiesStatusYieldEntertainment:SetFontSize(24);
  Controls.AmenetiesStatusIconEntertainment:SetColor(0x3fffffff);
  Controls.AmenetiesStatusLabelEntertainment:SetColor(0xffffffff);

  Controls.AmenetiesStatusIconContainerGreatPeople:SetTextureOffsetVal(0, 100);
  Controls.AmenetiesStatusYieldGreatPeople:SetText( Locale.ToNumber(data.AmenitiesFromGreatPeople) );
  Controls.AmenetiesStatusYieldGreatPeople:SetColorByName( GetAmenetiesColor(data.AmenitiesFromGreatPeople) );
  Controls.AmenetiesStatusYieldGreatPeople:SetFontSize(24);
  Controls.AmenetiesStatusIconGreatPeople:SetColor(0x3fffffff);
  Controls.AmenetiesStatusLabelGreatPeople:SetColor(0xffffffff);

  Controls.AmenetiesStatusIconContainerReligion:SetTextureOffsetVal(0, 100);
  Controls.AmenetiesStatusYieldReligion:SetText( Locale.ToNumber(data.AmenitiesFromReligion) );
  Controls.AmenetiesStatusYieldReligion:SetColorByName( GetAmenetiesColor(data.AmenitiesFromReligion) );
  Controls.AmenetiesStatusYieldReligion:SetFontSize(24);
  Controls.AmenetiesStatusIconReligion:SetColor(0x3fffffff);
  Controls.AmenetiesStatusLabelReligion:SetColor(0xffffffff);

  Controls.AmenetiesStatusIconContainerNationalParks:SetTextureOffsetVal(0, 100);
  Controls.AmenetiesStatusYieldNationalParks:SetText( Locale.ToNumber(data.AmenitiesFromNationalParks) );
  Controls.AmenetiesStatusYieldNationalParks:SetColorByName( GetAmenetiesColor(data.AmenitiesFromNationalParks) );
  Controls.AmenetiesStatusYieldNationalParks:SetFontSize(24);
  Controls.AmenetiesStatusIconNationalParks:SetColor(0x3fffffff);
  Controls.AmenetiesStatusLabelNationalParks:SetColor(0xffffffff);

  Controls.AmenetiesStatusIconContainerWarWeariness:SetTextureOffsetVal(0, 100);
  Controls.AmenetiesStatusYieldWarWeariness:SetText( Locale.ToNumber(data.AmenitiesLostFromWarWeariness) );
  Controls.AmenetiesStatusYieldWarWeariness:SetColorByName( GetAmenetiesColor(-data.AmenitiesLostFromWarWeariness) );
  Controls.AmenetiesStatusYieldWarWeariness:SetFontSize(24);
  Controls.AmenetiesStatusIconWarWeariness:SetColor(0x3fffffff);
  Controls.AmenetiesStatusLabelWarWeariness:SetColor(0xffffffff);

  Controls.AmenetiesStatusIconContainerBankruptcy:SetTextureOffsetVal(0, 100);
  Controls.AmenetiesStatusYieldBankruptcy:SetText( Locale.ToNumber(data.AmenitiesLostFromBankruptcy) );
  Controls.AmenetiesStatusYieldBankruptcy:SetColorByName( GetAmenetiesColor(-data.AmenitiesLostFromBankruptcy) );
  Controls.AmenetiesStatusYieldBankruptcy:SetFontSize(24);
  Controls.AmenetiesStatusIconBankruptcy:SetColor(0x3fffffff);
  Controls.AmenetiesStatusLabelBankruptcy:SetColor(0xffffffff);
  -- end new ameneties section
  
  local colorName:string = GetHappinessColor(data.Happiness);
  Controls.AmenitiesConstructedLabel:SetText( Locale.Lookup( "LOC_HUD_CITY_AMENITY", data.AmenitiesNum) );
  Controls.AmenitiesConstructedNum:SetText( Locale.ToNumber(data.AmenitiesNum) );
  Controls.AmenityTotalNum:SetText( Locale.ToNumber(data.AmenitiesNum) );
  Controls.AmenitiesConstructedNum:SetColorByName( colorName );
  Controls.Mood:SetText( Locale.Lookup(GameInfo.Happinesses[data.Happiness].Name) );
  Controls.Mood:SetColorByName( colorName );
   
  if data.HappinessGrowthModifier == 0 then
    Controls.CitizenGrowth:SetText( Locale.Lookup("LOC_HUD_CITY_CITIZENS_SATISFIED") );
    Controls.CitizenGrowth:SetFontSize(12);
  else
    Controls.CitizenGrowth:SetFontSize(12);
    local iGrowthPercent = Round(1 + (data.HappinessGrowthModifier/100), 2);
    local iYieldPercent = Round(1 + (data.HappinessNonFoodYieldModifier/100), 2);
    local growthInfo:string = 
      GetColorPercentString(iGrowthPercent) .. 
      " "..
      Locale.Lookup("LOC_HUD_CITY_CITIZEN_GROWTH") .. 
      "[NEWLINE]" ..
      GetColorPercentString(iYieldPercent) .. 
      " "..
      Locale.ToUpper( Locale.Lookup("LOC_HUD_CITY_ALL_YIELDS") );
      
    Controls.CitizenGrowth:SetText( growthInfo );
    --Controls.CitizenYields:SetText( data.HappinessNonFoodYieldModifier );
    --Controls.CitizenYields:SetHide(false);
  end
  
  Controls.AmenityAdvice:SetText(data.AmenityAdvice);

  m_kAmenitiesIM:ResetInstances();
  --[[ TODO: Get specific amenities.
  for i= 1 , data.AmenitiesNum,1 do
    local kAmenityInstance:table = m_kAmenitiesIM:GetInstance();
    kAmenityInstance.Amenity:SetText("$Amenity"..tostring(i).."$");
  end
  ]]
  local kInstance :table = m_kAmenitiesIM:GetInstance();
  kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_LUXURIES") );
  kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromLuxuries) );
  
  kInstance = m_kAmenitiesIM:GetInstance();
  kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_CIVICS") );
  kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromCivics) );
  
  kInstance = m_kAmenitiesIM:GetInstance();
  kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_ENTERTAINMENT") );
  kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromEntertainment) );
    
  kInstance = m_kAmenitiesIM:GetInstance();
  kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_GREAT_PEOPLE") );
  kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromGreatPeople) );

  kInstance = m_kAmenitiesIM:GetInstance();
  kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_CITY_STATES") );
  kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromCityStates) );

  kInstance = m_kAmenitiesIM:GetInstance();
  kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_RELIGION") );
  kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromReligion) );

  kInstance = m_kAmenitiesIM:GetInstance();
  kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_NATIONAL_PARKS") );
  kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromNationalParks) );

  if(data.AmenitiesFromStartingEra > 0) then 
    kInstance = m_kAmenitiesIM:GetInstance();
    kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_STARTING_ERA") );
    kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromStartingEra) );
  end
  
  kInstance = m_kAmenitiesIM:GetInstance();
  kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_LOST_FROM_WAR_WEARINESS") );
  if data.AmenitiesLostFromWarWeariness == 0 then
    kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesLostFromWarWeariness) );
  else
    kInstance.AmenityYield:SetText( Locale.ToNumber(-data.AmenitiesLostFromWarWeariness) );
  end

  kInstance = m_kAmenitiesIM:GetInstance();
  kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_LOST_FROM_BANKRUPTCY") );
  if data.AmenitiesLostFromBankruptcy == 0 then
    kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesLostFromBankruptcy) );
  else
    kInstance.AmenityYield:SetText( Locale.ToNumber(-data.AmenitiesLostFromBankruptcy) );
  end

  Controls.AmenitiesRequiredNum:SetText( Locale.ToNumber(data.AmenitiesRequiredNum) );
  Controls.CitizenGrowthStatus:SetTextureOffsetVal( UV_CITIZEN_GROWTH_STATUS[data.Happiness].u, UV_CITIZEN_GROWTH_STATUS[data.Happiness].v );
  Controls.CitizenGrowthStatusIcon:SetColorByName( colorName );
  Controls.PanelAmenities:ReprocessAnchoring();
end

-- ===========================================================================
function ViewPanelHousing( data:table ) 
  -- Only show the advisor bubbles during the tutorial
  Controls.HousingAdvisorBubble:SetHide( IsTutorialRunning() == false );
  
  -- CQUI new housing section
  Controls.HousingStack:SetHide( true );

  Controls.HousingStatusIconContainerBuildings:SetTextureOffsetVal(0, 100);
  Controls.HousingStatusYieldBuildings:SetText( Locale.ToNumber(data.HousingFromBuildings) );
  --Controls.HousingStatusYieldBuildings:SetColorByName( GetHousingColor(data.HousingFromBuildings) );
  Controls.HousingStatusYieldBuildings:SetFontSize(24);
  Controls.HousingStatusIconBuildings:SetColor(0x3fffffff);
  Controls.HousingStatusLabelBuildings:SetColor(0xffffffff);

  Controls.HousingStatusIconContainerCivics:SetTextureOffsetVal(0, 100);
  Controls.HousingStatusYieldCivics:SetText( Locale.ToNumber(data.HousingFromCivics) );
  --Controls.HousingStatusYieldCivics:SetColorByName( GetHousingColor(data.HousingFromCivics) );
  Controls.HousingStatusYieldCivics:SetFontSize(24);
  Controls.HousingStatusIconCivics:SetColor(0x3fffffff);
  Controls.HousingStatusLabelCivics:SetColor(0xffffffff);

  Controls.HousingStatusIconContainerDistricts:SetTextureOffsetVal(0, 100);
  Controls.HousingStatusYieldDistricts:SetText( Locale.ToNumber(data.HousingFromDistricts) );
  --Controls.HousingStatusYieldDistricts:SetColorByName( GetHousingColor(data.HousingFromDistricts) );
  Controls.HousingStatusYieldDistricts:SetFontSize(24);
  Controls.HousingStatusIconDistricts:SetColor(0x3fffffff);
  Controls.HousingStatusLabelDistricts:SetColor(0xffffffff);

  Controls.HousingStatusIconContainerImprovements:SetTextureOffsetVal(0, 100);
  Controls.HousingStatusYieldImprovements:SetText( Locale.ToNumber(data.HousingFromImprovements) );
  --Controls.HousingStatusYieldImprovements:SetColorByName( GetHousingColor(data.HousingFromImprovements) );
  Controls.HousingStatusYieldImprovements:SetFontSize(24);
  Controls.HousingStatusIconImprovements:SetColor(0x3fffffff);
  Controls.HousingStatusLabelImprovements:SetColor(0xffffffff);

  Controls.HousingStatusIconContainerWater:SetTextureOffsetVal(0, 100);
  Controls.HousingStatusYieldWater:SetText( Locale.ToNumber(data.HousingFromWater) );
  --Controls.HousingStatusYieldWater:SetColorByName( GetHousingColor(data.HousingFromWater) );
  Controls.HousingStatusYieldWater:SetFontSize(24);
  Controls.HousingStatusIconWater:SetColor(0x3fffffff);
  Controls.HousingStatusLabelWater:SetColor(0xffffffff);

  Controls.HousingStatusIconContainerGreatPeople:SetTextureOffsetVal(0, 100);
  Controls.HousingStatusYieldGreatPeople:SetText( Locale.ToNumber(data.HousingFromGreatPeople) );
  --Controls.HousingStatusYieldGreatPeople:SetColorByName( GetHousingColor(data.HousingFromGreatPeople) );
  Controls.HousingStatusYieldGreatPeople:SetFontSize(24);
  Controls.HousingStatusIconGreatPeople:SetColor(0x3fffffff);
  Controls.HousingStatusLabelGreatPeople:SetColor(0xffffffff);

  Controls.HousingStatusIconContainerStartingEra:SetTextureOffsetVal(0, 100);
  Controls.HousingStatusYieldStartingEra:SetText( Locale.ToNumber(data.HousingFromStartingEra) );
  --Controls.HousingStatusYieldStartingEra:SetColorByName( GetHousingColor(data.HousingFromStartingEra) );
  Controls.HousingStatusYieldStartingEra:SetFontSize(24);
  Controls.HousingStatusIconStartingEra:SetColor(0x3fffffff);
  Controls.HousingStatusLabelStartingEra:SetColor(0xffffffff);
  -- end new housing section
  
  local colorName:string = GetPercentGrowthColor( data.HousingMultiplier ) ;
  Controls.HousingTotalNum:SetText( data.Housing ); 
  Controls.HousingTotalNum:SetColorByName( colorName );
  local uv:number;

  if data.HousingMultiplier == 0 then
    Controls.HousingPopulationStatus:SetText(Locale.Lookup("LOC_HUD_CITY_POPULATION_GROWTH_HALTED")); 
    uv = 0; 
  elseif data.HousingMultiplier <= 0.25 then
      local iPercent = (1 - data.HousingMultiplier) * 100;
    Controls.HousingPopulationStatus:SetText(Locale.Lookup("LOC_HUD_CITY_POPULATION_GROWTH_SLOWED", iPercent));   
    uv = 1;
  elseif data.HousingMultiplier <= 0.5 then
      local iPercent = (1 - data.HousingMultiplier) * 100;
    Controls.HousingPopulationStatus:SetText(Locale.Lookup("LOC_HUD_CITY_POPULATION_GROWTH_SLOWED", iPercent));   
    uv = 1;
  else
    Controls.HousingPopulationStatus:SetText(Locale.Lookup("LOC_HUD_CITY_POPULATION_GROWTH_NORMAL"));
    uv = 2;
  end
  Controls.HousingPopulationStatus:SetColorByName( colorName );

  Controls.CitizensNum:SetText( data.Population );
  if data.Population <= 1 then
    Controls.CitizensName:SetText(Locale.Lookup("LOC_HUD_CITY_CITIZEN"));
  elseif data.Population > 1 then
    Controls.CitizensName:SetText(Locale.Lookup("LOC_HUD_CITY_CITIZENS"));
  end
  Controls.HousingTotalNum2:SetText( data.Housing );
  Controls.HousingTotalNum2:SetColorByName( colorName );
    
  --local uv:number = data.TurnsUntilGrowth > 0 and 1 or 0;
  Controls.HousingStatus:SetTextureOffsetVal( UV_HOUSING_GROWTH_STATUS[uv].u, UV_HOUSING_GROWTH_STATUS[uv].v );
  Controls.HousingStatusIcon:SetColorByName( colorName );

  Controls.HousingAdvice:SetText(data.HousingAdvice);

  m_kHousingIM:ResetInstances();
  
  
  
  local kInstance :table = m_kHousingIM:GetInstance();
  kInstance.HousingName:SetText( Locale.Lookup("LOC_HUD_CITY_HOUSING_FROM_BUILDINGS") );
  kInstance.HousingYield:SetText( Locale.ToNumber(data.HousingFromBuildings) );

  kInstance = m_kHousingIM:GetInstance();
  kInstance.HousingName:SetText( Locale.Lookup("LOC_HUD_CITY_HOUSING_FROM_CIVICS") );
  kInstance.HousingYield:SetText( Locale.ToNumber(data.HousingFromCivics) );

  kInstance = m_kHousingIM:GetInstance();
  kInstance.HousingName:SetText( Locale.Lookup("LOC_HUD_CITY_HOUSING_FROM_DISTRICTS") );
  kInstance.HousingYield:SetText( Locale.ToNumber(data.HousingFromDistricts) );

  kInstance = m_kHousingIM:GetInstance();
  kInstance.HousingName:SetText( Locale.Lookup("LOC_HUD_CITY_HOUSING_FROM_IMPROVEMENTS") );
  kInstance.HousingYield:SetText( Locale.ToNumber(data.HousingFromImprovements) );

  kInstance = m_kHousingIM:GetInstance();
  kInstance.HousingName:SetText( Locale.Lookup("LOC_HUD_CITY_HOUSING_FROM_WATER") );
  kInstance.HousingYield:SetText( Locale.ToNumber(data.HousingFromWater) );

  kInstance = m_kHousingIM:GetInstance();
  kInstance.HousingName:SetText( Locale.Lookup("LOC_HUD_CITY_HOUSING_FROM_GREAT_PEOPLE") );
  kInstance.HousingYield:SetText( Locale.ToNumber(data.HousingFromGreatPeople) );

  --Housing from Advanced Starts it is zero in the Ancient Era so we do not want to display it
  if(data.HousingFromStartingEra > 0 ) then
    kInstance = m_kHousingIM:GetInstance();
    kInstance.HousingName:SetText( Locale.Lookup("LOC_HUD_CITY_HOUSING_FROM_STARTING_ERA") );
    kInstance.HousingYield:SetText( Locale.ToNumber(data.HousingFromStartingEra) );
  end

  Controls.PanelHousing:ReprocessAnchoring();
end

-- ===========================================================================
function UpdateCitizenGrowthStatusIcon( turnsUntilGrowth:number )

  local color;
  if turnsUntilGrowth < 0 then
    -- Starving
    statusIndex = 0;
    color = "StatBadCSGlow";
  elseif turnsUntilGrowth == 0 then
    -- Neutral
    statusIndex = 1;
    color = "StatNormalCSGlow";
  else
    -- Growing
    statusIndex = 2;
    color = "StatGoodCSGlow";
  end

  Controls.CitizenGrowthStatus2:SetColorByName(color);
  Controls.CitizenGrowthStatusIcon2:SetColorByName(color);

  local uv = UV_CITIZEN_STARVING_STATUS[statusIndex];
  Controls.CitizenGrowthStatus2:SetTextureOffsetVal( uv.u, uv.v );
end

--[[TODO: Going to adapt this function to link directly to the amenities/growth portions of 
-- the Citizen Health tab, if a player clicks one of the stats in the city panel
--function ScrollToNode( typeName:string )
--  local percent:number = 0;
--  local x   = m_uiNodes[typeName].x - ( m_width * 0.5);
--  local size  = (m_width / Controls.NodeScroller:GetRatio()) - m_width;
--  percent = math.clamp( x  / size, 0, 1);
--  Controls.NodeScroller:SetScrollValue(percent);
--end]]--
-- ===========================================================================
function ViewPanelCitizensGrowth( data:table )  

  Controls.FoodPerTurnNum:SetText( toPlusMinusString(data.FoodPerTurn) );
  Controls.FoodConsumption:SetText( toPlusMinusString(-(data.FoodPerTurn - data.FoodSurplus)) );
  Controls.NetFoodPerTurn:SetText( toPlusMinusString(data.FoodSurplus) ); 
  Controls.GrowthLongTurnsBar:SetPercent( data.CurrentFoodPercent );
  Controls.GrowthLongTurnsBar:SetShadowPercent( data.FoodPercentNextTurn );
  Controls.GrowthLongNum:SetText( math.abs(data.TurnsUntilGrowth));
  
  local iModifiedFood;
  local total :number;

  if data.Occupied then
    local iOccupationGrowthPercent = data.OccupationMultiplier * 100;
      Controls.OccupationMultiplier:SetText( Locale.ToNumber(iOccupationGrowthPercent));
  else
      Controls.OccupationMultiplier:LocalizeAndSetText("LOC_HUD_CITY_NOT_APPLICABLE");
  end

  if data.TurnsUntilGrowth > -1 then
    
    -- Set bonuses and multipliers
    local iHappinessPercent = data.HappinessGrowthModifier;
    Controls.HappinessBonus:SetText( toPlusMinusString(Round(iHappinessPercent, 0)) .. "%");
    local iOtherGrowthPercent = data.OtherGrowthModifiers * 100;
    Controls.OtherGrowthBonuses:SetText( toPlusMinusString(Round(iOtherGrowthPercent, 0)) .. "%");
    Controls.HousingMultiplier:SetText( Locale.ToNumber( data.HousingMultiplier));
    local growthModifier =  math.max(1 + (data.HappinessGrowthModifier/100) + data.OtherGrowthModifiers, 0); -- This is unintuitive but it's in parity with the logic in City_Growth.cpp
    iModifiedFood = Round(data.FoodSurplus * growthModifier, 2);
    total = iModifiedFood * data.HousingMultiplier;   
    if data.Occupied then
      total = iModifiedFood * data.OccupationMultiplier;    
      Controls.TurnsUntilBornLost:SetText( Locale.Lookup("LOC_HUD_CITY_GROWTH_OCCUPIED"));
    else
      Controls.TurnsUntilBornLost:SetText( Locale.Lookup("LOC_HUD_CITY_TURNS_UNTIL_CITIZEN_BORN", data.TurnsUntilGrowth));
    end
    Controls.FoodSurplusDeficitLabel:LocalizeAndSetText("LOC_HUD_CITY_TOTAL_FOOD_SURPLUS");
  else
    -- In a deficit, no bonuses or multipliers apply
    Controls.HappinessBonus:LocalizeAndSetText("LOC_HUD_CITY_NOT_APPLICABLE");
    Controls.OtherGrowthBonuses:LocalizeAndSetText("LOC_HUD_CITY_NOT_APPLICABLE");
    Controls.HousingMultiplier:LocalizeAndSetText("LOC_HUD_CITY_NOT_APPLICABLE");
    iModifiedFood = data.FoodSurplus;
    total = iModifiedFood;    

    Controls.TurnsUntilBornLost:SetText( Locale.Lookup("LOC_HUD_CITY_TURNS_UNTIL_CITIZEN_LOST", math.abs(data.TurnsUntilGrowth)));
    Controls.FoodSurplusDeficitLabel:LocalizeAndSetText("LOC_HUD_CITY_TOTAL_FOOD_DEFICIT");
  end 

  Controls.ModifiedGrowthFoodPerTurn:SetText( toPlusMinusString(iModifiedFood) );
  local totalString:string = toPlusMinusString(total) .. (total <= 0 and "[Icon_FoodDeficit]" or "[Icon_FoodSurplus]");
  Controls.TotalFoodSurplus:SetText( totalString );
  Controls.CitizensStarving:SetHide( data.TurnsUntilGrowth > -1);
  UpdateCitizenGrowthStatusIcon( data.TurnsUntilGrowth );

  Controls.PanelCitizensGrowth:ReprocessAnchoring();
end

-- ===========================================================================
function ViewPanelProductionNow( data:table ) 
  Controls.ProductionNowHeader:SetText( data.CurrentProductionName );
  
  -- If a unit is building built; show it's stats before the description: 
  Controls.UnitStatsStack:SetHide( data.UnitStats == nil );
  if data.UnitStats ~= nil then
    Controls.IconStrength:SetHide( data.UnitStats.Combat <= 0 );
    Controls.IconBombardStrength:SetHide( data.UnitStats.Bombard <= 0 );
    Controls.IconRange:SetHide( data.UnitStats.Range <= 0 );
    Controls.IconRangedStrength:SetHide( data.UnitStats.RangedCombat <= 0 );

    Controls.LabelStrength:SetHide( data.UnitStats.Combat <= 0 );
    Controls.LabelRangedStrength:SetHide( data.UnitStats.RangedCombat <= 0 );
    Controls.LabelBombardStrength:SetHide( data.UnitStats.Bombard <= 0 );
    Controls.LabelRange:SetHide( data.UnitStats.Range <= 0 );
        
    Controls.LabelStrength:SetText( Locale.ToNumber(data.UnitStats.Combat ) );
    Controls.LabelRangedStrength:SetText( Locale.ToNumber(data.UnitStats.RangedCombat ) );
    Controls.LabelBombardStrength:SetText( Locale.ToNumber(data.UnitStats.Bombard ) );
    Controls.LabelRange:SetText( Locale.ToNumber(data.UnitStats.Range ) );
  end

  Controls.ProductionDescription:SetText( data.CurrentProductionDescription );
  Controls.PanelProductionNow:ReprocessAnchoring();
end


-- ===========================================================================
function CreateQueueItem( index:number, kProductionInfo:table )
  local kInstance :table = m_kProductionIM:GetInstance();
  kInstance.Index:SetText( tostring(index).."." );
  kInstance.Close:RegisterCallback( Mouse.eLClick,
    function()
      m_kProductionIM:ReleaseInstance( kInstance );     
      Controls.PanelStack:CalculateSize();
      Controls.PanelStack:ReprocessAnchoring();
      Controls.PanelStack:ReprocessAnchoring(); -- Because of all the autosizing, the anchoring must be processed twice.
    end
  );
  if (kProductionInfo.Icon ~= nil) then
    kInstance.Icon:SetHide(false);
    kInstance.Icon:SetIcon( kProductionInfo.Icon);
  else
    kInstance.Icon:SetHide(true);
  end
  kInstance.Name:SetText( kProductionInfo.Name  );
  kInstance.Turns:SetText( Locale.Lookup("LOC_HUD_CITY_IN_TURNS",kProductionInfo.Turns) );
end

-- ===========================================================================
function ViewPanelQueue( data:table ) 
  m_kProductionIM:ResetInstances();
  for i:number,kProductionInfo:table in ipairs( data.ProductionQueue ) do
    CreateQueueItem(i, kProductionInfo );
  end
end

-- ===========================================================================

function RenameCity(city, new_name)
  -- Do nothing if the city names match or new name is blank or invalid.
  local old_name = city:GetName();
  if(new_name == nil or new_name == old_name or new_name == Locale.Lookup(old_name)) then
    return;
  else
    -- Send net message to change name.
    local params = {};
    params[CityCommandTypes.PARAM_NAME] = new_name;
  
    CityManager.RequestCommand(city, CityCommandTypes.NAME_CITY, params);
  end
end

function OnAddToProductionQueue()
  -- LuaEvents.CityPanel_ProductionOpenForQueue(); --??TRON
end

-- ===========================================================================
--  Called once during Init
-- ===========================================================================
function PopulateTabs()
  if m_tabs == nil then
    m_tabs = CreateTabs( Controls.TabContainer,44,44);
    m_tabs.AddTab( Controls.HealthButton,   OnSelectHealthTab );
    m_tabs.AddTab( Controls.BuildingsButton,  OnSelectBuildingsTab );
    m_tabs.AddTab( Controls.ReligionButton,   OnSelectReligionTab );
    --m_tabs.AddTab( Controls.QueueButton,    OnSelectQueueTab );
    --m_tabs.AddTab( Controls.StrengthButton,   OnSelectStrengthTab );
    m_tabs.CenterAlignTabs(0);
  end
  m_tabs.SelectTab( Controls.HealthButton );
  m_tabs.AddAnimDeco(Controls.TabAnim, Controls.TabArrow);
end


function AutoSizeControls()
  local screenX, screenY:number = UIManager:GetScreenSizeVal()
end

function Resize()

end

function Close()
  m_isShowingPanel = false;
  local offsetx = Controls.OverviewSlide:GetOffsetX();
  if(offsetx == 0) then
    Controls.OverviewSlide:Reverse();
    UI.PlaySound("UI_CityPanel_Closed");
  end
end

function OnClose()
  Close();
end

function OnCloseButtonClicked()
  LuaEvents.CQUI_CityPanel_CityviewDisable();
end

function View(data)
  if (m_isDirty) then
    Controls.OverviewSubheader:SetText(Locale.ToUpper(Locale.Lookup(data.CityName)));
    Controls.RenameCityButton:RegisterCallback(Mouse.eLClick, function()
      Controls.OverviewSubheader:SetHide(true);

      Controls.EditCityName:SetText(Controls.OverviewSubheader:GetText());
      Controls.EditCityName:SetHide(false);
      Controls.EditCityName:TakeFocus();
    end);
    local city = data.City;
    Controls.EditCityName:RegisterCommitCallback(function(editBox)
      local userInput:string = Controls.EditCityName:GetText();
      RenameCity(city, userInput);
      Controls.EditCityName:SetHide(true);
      Controls.OverviewSubheader:SetHide(false);
    end);
    ViewPanelAmenities( data );
    ViewPanelCitizensGrowth( data );
    ViewPanelHousing( data );
    ViewPanelBreakdown( data );
    ViewPanelReligion( data );
    ViewPanelQueue( data );
    CalculateSizeAndAccomodate(Controls.PanelScrollPanel, Controls.PanelStack);
    m_isDirty = false;
  end
end

function Refresh()
  -- Only refresh if panel is visible
  if (m_isShowingPanel) then
    local eLocalPlayer :number = Game.GetLocalPlayer();
    m_pPlayer= Players[eLocalPlayer];
    m_pCity  = UI.GetHeadSelectedCity();

    if m_pPlayer ~= nil and m_pCity ~= nil then
      if m_kData == nil then
        return;
      end
      View( m_kData );
    end
  end
end
-- ===========================================================================
--  Input
--  UI Event Handler
-- ===========================================================================
function KeyHandler( key:number )
    if key == Keys.VK_ESCAPE then
    if ( m_isShowingPanel ) then
      UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
      return true;
    else
      return false;
    end
    end
    return false;
end

function OnInputHandler( pInputStruct:table )
  local uiMsg = pInputStruct:GetMessageType();
  if (uiMsg == KeyEvents.KeyUp) then return KeyHandler( pInputStruct:GetKey() ); end;
  return false;
end 

-- Resize Handler
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end

-- Called whenever CityPanel is refreshed
function OnLiveCityDataChanged( data:table, isSelected:boolean) 
  if (not isSelected) then
    Close();
  else
    m_kData = data;
    m_isDirty = true;
    ContextPtr:SetHide(false);
    Refresh();
  end
end

function OnCityNameChanged( playerID: number, cityID : number )
  if(m_pCity and playerID == m_pCity:GetOwner() and cityID == m_pCity:GetID()) then
    Controls.OverviewSubheader:SetText(Locale.ToUpper(Locale.Lookup(m_pCity:GetName())));
  end
end

function OnLocalPlayerTurnEnd()
  if(GameConfiguration.IsHotseat()) then
    Close();
  end
end

function OnResearchCompleted( ePlayer:number )
  if m_pPlayer ~= nil and ePlayer == m_pPlayer:GetID() then
    Refresh();
  end
end

function OnPolicyChanged( ePlayer:number )
  if m_pPlayer ~= nil and ePlayer == m_pPlayer:GetID() then
    Refresh();
  end
end

function Resize()
  CalculateSizeAndAccomodate(Controls.PanelScrollPanel, Controls.PanelStack);
  local screenX, screenY:number = UIManager:GetScreenSizeVal();
  Controls.OverviewSlide:SetSizeY(screenY);
  Controls.PanelScrollPanel:SetSizeY(screenY-120);
end

function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end

function OnShowOverviewPanel( isShowing: boolean )
  m_isShowingPanel = isShowing;
  if (isShowing) then
    Refresh();
    Controls.OverviewSlide:SetToBeginning();
    Controls.OverviewSlide:Play();
    UI.PlaySound("UI_CityPanel_Open");
  else
    local offsetx = Controls.OverviewSlide:GetOffsetX();
    if(offsetx == 0) then
      Controls.OverviewSlide:Reverse();
    end
  end
end

function OnShowBreakdownTab()
  m_tabs.SelectTab( Controls.BuildingsButton );
end

function Initialize() 
  PopulateTabs();

  ContextPtr:SetInputHandler( OnInputHandler, true );
  Controls.Close:RegisterCallback(Mouse.eLClick, OnCloseButtonClicked);
  Controls.Close:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  
  LuaEvents.Tutorial_ResearchOpen.Add(OnClose);
  LuaEvents.ActionPanel_OpenChooseResearch.Add(OnClose);
  LuaEvents.ActionPanel_OpenChooseCivic.Add(OnClose);
  Events.SystemUpdateUI.Add( OnUpdateUI );
  LuaEvents.CityPanel_ShowOverviewPanel.Add( OnShowOverviewPanel );
  LuaEvents.CityPanel_LiveCityDataChanged.Add( OnLiveCityDataChanged )

  Events.SystemUpdateUI.Add( OnUpdateUI );
  Events.CityNameChanged.Add(OnCityNameChanged);
  Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );
  Events.ResearchCompleted.Add( OnResearchCompleted );
  Events.GovernmentPolicyChanged.Add( OnPolicyChanged );
  Events.GovernmentPolicyObsoleted.Add( OnPolicyChanged );
end
Initialize();
