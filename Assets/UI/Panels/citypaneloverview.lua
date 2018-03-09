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
local SIZE_LEADER_ICON          :number = 32;
local SIZE_CITYSTATE_ICON			  :number = 30;
local SIZE_PRODUCTION_ICON      :number = 32; -- TODO: Switch this to 38 when the icons go in.
local SIZE_PANEL_X              :number = 300;
local TXT_NO_PRODUCTION         :string = Locale.Lookup("LOC_HUD_CITY_PRODUCTION_NOTHING_PRODUCED");

local UV_CITIZEN_GROWTH_STATUS    :table  = {};
    UV_CITIZEN_GROWTH_STATUS[0] = {u=0, v=0};     -- revolt
    UV_CITIZEN_GROWTH_STATUS[1] = {u=0, v=0};     -- unrest
    UV_CITIZEN_GROWTH_STATUS[2] = {u=0, v=0};     -- unhappy
    UV_CITIZEN_GROWTH_STATUS[3] = {u=0, v=50};    -- displeased
    UV_CITIZEN_GROWTH_STATUS[4] = {u=0, v=100};   -- content (normal)
    UV_CITIZEN_GROWTH_STATUS[5] = {u=0, v=150};   -- happy
    UV_CITIZEN_GROWTH_STATUS[6] = {u=0, v=200};   -- ecstatic
    UV_CITIZEN_GROWTH_STATUS[7] = {u=0, v=200};   -- jubilant

local UV_HOUSING_GROWTH_STATUS    :table = {};
    UV_HOUSING_GROWTH_STATUS[0] = {u=0, v=0};     -- halted
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

m_kAmenitiesIM = InstanceManager:new( "CQUI_BubbleInstance",     "Top", Controls.AmenityStack );
local m_kBuildingsIM = InstanceManager:new( "BuildingInstance",      "Top");
local m_kDistrictsIM = InstanceManager:new( "DistrictInstance",      "Top", Controls.BuildingAndDistrictsStack );
local m_kHousingIM = InstanceManager:new( "CQUI_BubbleInstance",     "Top", Controls.HousingStack );
local m_kOtherReligionsIM = InstanceManager:new( "OtherReligionInstance",   "Top", Controls.OtherReligions );
local m_kProductionIM = InstanceManager:new( "ProductionInstance",    "Top", Controls.ProductionQueueStack );
local m_kReligionsBeliefsIM = InstanceManager:new( "ReligionBeliefsInstance", "Top", Controls.ReligionBeliefsStack );
local m_kTradingPostsIM = InstanceManager:new( "TradingPostInstance",   "Top", Controls.TradingPostsStack );
local m_kWondersIM = InstanceManager:new( "WonderInstance",      "Top", Controls.WondersStack );

local m_kData = nil;
local m_isInitializing = false;
local m_isShowingPanels = false;
local m_pCity = nil;
local m_pPlayer = nil;
local m_primaryColor = 0xcafef00d;
local m_secondaryColor = 0xf00d1ace;
-- CQUI : replaced Default by CityManagement
local m_desiredLens = "CityManagement";

local ms_eventID = 0;
local m_isShowingPanel = false;

-- ===========================================================================
--	GLOBALS
-- ===========================================================================
m_kTabButtonIM = InstanceManager:new( "TabButtonInstance", "Button", Controls.TabContainer );
m_tabs = nil;


--CQUI Members
local CQUI_HousingFromImprovementsTable = {};
local CQUI_ShowCityDetailAdvisor :boolean = false;

function CQUI_OnSettingsUpdate()
  CQUI_ShowCityDetailAdvisor = GameConfiguration.GetValue("CQUI_ShowCityDetailAdvisor") == 1
end
LuaEvents.CQUI_SettingsUpdate.Add(CQUI_OnSettingsUpdate);
LuaEvents.CQUI_SettingsInitialized.Add(CQUI_OnSettingsUpdate);

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

-- HACK: Something in the event city selection event chain is overriding the active lens after we open this screen
--       Check lens next frame to ensure we end up with the correct lens active
-- TODO: We need to do figure out why this is happening, having it reactivate the lens every frame does not play well
--       with everywhere else that uses lenses, border growth, minimap panel, religious units, etc.
function SetDesiredLens(desiredLens)
  m_desiredLens = desiredLens;
  -- AZURENCY : don't change interface mode
  --UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
  if m_isShowingPanel then
    if m_desiredLens == "CityManagement" then
      UILens.SetActive("Appeal");
      LuaEvents.CQUI_RefreshCitizenManagement(m_pCity:GetID());
    else
      UILens.SetActive(m_desiredLens);
    end
    ContextPtr:SetUpdate(EnsureDesiredLens);
  else
    UILens.SetActive(m_desiredLens);
  end
end

function EnsureDesiredLens()
  if m_isShowingPanel then
    if m_desiredLens == "CityManagement" then
      UILens.SetActive("Appeal");
      LuaEvents.CQUI_RefreshCitizenManagement(m_pCity:GetID());
    else
      UILens.SetActive(m_desiredLens);
    end
  end
  ContextPtr:ClearUpdate();
end

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

  Controls.PanelBreakdown:SetHide(true);
  Controls.PanelReligion:SetHide(true);
  Controls.PanelAmenities:SetHide(true);
  Controls.PanelHousing:SetHide(true);
  Controls.PanelCitizensGrowth:SetHide(true);
  Controls.PanelProductionNow:SetHide(true);
  Controls.PanelQueue:SetHide(true);
  Controls.PanelDynamicTab:SetHide(true);

  SetDesiredLens("CityManagement");
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
end
function OnSelectReligionTab()
  HideAll();
  Controls.ReligionButton:SetSelected(true);
  Controls.ReligionIcon:SetColorByName("DarkBlue");
  UI.PlaySound("UI_CityPanel_ButtonClick");

  Controls.PanelReligion:SetHide(false);

  if(m_kData ~= nil) then
    ViewPanelReligion( m_kData );
  end
end

-- ===========================================================================
function ViewPanelBreakdown( data:table )
  Controls.DistrictsNum:SetText( data.DistrictsNum );
  Controls.DistrictsConstructed:SetText( Locale.Lookup("LOC_HUD_CITY_DISTRICTS_CONSTRUCTED", data.DistrictsNum) );
  Controls.DistrictsPossibleNum:SetText( data.DistrictsPossibleNum );

  m_kBuildingsIM:ResetInstances();
  m_kDistrictsIM:ResetInstances();
  m_kTradingPostsIM:ResetInstances();
  m_kWondersIM:ResetInstances();
  local playerID = Game.GetLocalPlayer();

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
      local sToolTip = ToolTipHelper.GetToolTip(district.Type, playerID)
      kInstanceDistrict.Top:SetToolTipString( sToolTip);
      for _,building in ipairs(district.Buildings) do
        if building.isBuilt then
          local kInstanceBuild:table = m_kBuildingsIM:GetInstance(kInstanceDistrict.BuildingStack);
          local buildingName = building.Name;
          if building.isPillaged then
            buildingName = buildingName .. "[ICON_Pillaged]";
          end
          kInstanceBuild.BuildingName:SetText( buildingName );
          kInstanceBuild.Icon:SetIcon( building.Icon );
          local pRow = GameInfo.Buildings[building.Type];
          local sToolTip = ToolTipHelper.GetBuildingToolTip( pRow.Hash, playerID, m_pCity );
          kInstanceBuild.Top:SetToolTipString( sToolTip);
          local yieldString:string = "";
          for _,kYield in ipairs(building.Yields) do
            yieldString = yieldString .. GetYieldString(kYield.YieldType,kYield.YieldChange);
          end
          kInstanceBuild.BuildingYield:SetText( yieldString );
          kInstanceBuild.BuildingYield:SetTruncateWidth( kInstanceBuild.Top:GetSizeX() - kInstanceBuild.BuildingName:GetSizeX() - 10 );
        end
      end
      kInstanceDistrict.BuildingStack:CalculateSize();
    end
  end

  -- Add wonders
  local hideWondersInfo :boolean = not GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_WONDERS");
  local isHasWonders :boolean = (table.count(data.Wonders) > 0)
  Controls.NoWondersArea:SetHide(hideWondersInfo or isHasWonders);
  Controls.WondersArea:SetHide(hideWondersInfo or not isHasWonders);
  Controls.WondersHeader:SetHide(hideWondersInfo);

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
  local hideTradingPostsInfo :boolean = not GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_TRADING_POSTS");
  local isHasTradingPosts :boolean = (table.count(data.TradingPosts) > 0)
  Controls.NoTradingPostsArea:SetHide(hideTradingPostsInfo or isHasTradingPosts);
  Controls.TradingPostsArea:SetHide(hideTradingPostsInfo or not isHasTradingPosts);
  Controls.TradingPostsHeader:SetHide(hideTradingPostsInfo);

  if isHasTradingPosts then
    for _, tradePostPlayerId in ipairs(data.TradingPosts) do
      local pTradePostPlayer:table = Players[tradePostPlayerId]
      local pTradePostPlayerConfig:table = PlayerConfigurations[tradePostPlayerId];
      local kInstanceTradingPost  :table = m_kTradingPostsIM:GetInstance();
      local playerName			:string = Locale.Lookup( pTradePostPlayerConfig:GetPlayerName() );

      local iconName:string = "";
      local iconSize:number = SIZE_LEADER_ICON;
      local iconColor = 0xFFFFFFFF;
      if pTradePostPlayer:IsMinor() then
        -- If we're a city-state display our city-state icon instead of leader since we don't have one
        local civType:string = pTradePostPlayerConfig:GetCivilizationTypeName();
        local primaryColor, secondaryColor = UI.GetPlayerColors(tradePostPlayerId);
        iconName = "ICON_"..civType;
        iconColor = secondaryColor;
        iconSize = SIZE_CITYSTATE_ICON;
      else
        iconName = "ICON_"..pTradePostPlayerConfig:GetLeaderTypeName();
      end

      local textureOffsetX :number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas(iconName, iconSize);
      kInstanceTradingPost.LeaderPortrait:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
      kInstanceTradingPost.LeaderPortrait:SetColor(iconColor);
      kInstanceTradingPost.LeaderPortrait:SetHide(false);

      if tradePostPlayerId == m_pPlayer:GetID() then
        playerName = playerName .. " (" .. Locale.Lookup("LOC_HUD_CITY_YOU") .. ")";
      end
      kInstanceTradingPost.TradingPostName:SetText( playerName );
    end
  end
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
      kBeliefInstance.BeliefLabel:SetText( Locale.Lookup(kBelief.Name) );
      kBeliefInstance.Top:SetToolTipString( Locale.Lookup(kBelief.Description) );
    end

    -- AZURENCY : fix the DominantReligionGrid being hidden at each turn of the loop
    --            Should not be required after 1.0.0.216
    -- Controls.DominantReligionGrid:SetHide(true);

    -- Dominant religion
    local dominateReligion:table = nil;
    if data.Religions and data.Religions[DATA_DOMINANT_RELIGION] then
      dominateReligion = data.Religions[DATA_DOMINANT_RELIGION];
      local religionName	:string = Game.GetReligion():GetName(dominateReligion.ID);
      local iconName		:string = "ICON_" .. dominateReligion.ReligionType;
      local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas(iconName, 22);

      Controls.DominantReligionGrid:SetHide(false);
      Controls.DominantReligionSymbol:SetHide(false);
      Controls.DominantReligionSymbol:SetTexture( textureSheet );
      Controls.DominantReligionSymbol:SetTextureOffsetVal( textureOffsetX, textureOffsetY );
      Controls.DominantReligionName:SetText( Locale.Lookup("LOC_HUD_CITY_RELIGIOUS_CITIZENS_NUMBER",dominateReligion.Followers,religionName) );
      Controls.DominantReligionGrid:SetHide(false);
    else
      Controls.DominantReligionGrid:SetHide(true);
    end

    -- Other religions
    for _,religion in ipairs(data.Religions) do
      -- Don't show pantheons or dominate religions here. Dominate religion is handled above.
      if religion.ReligionType ~= "RELIGION_PANTHEON" and (dominateReligion == nil or religion.ReligionType ~= dominateReligion.ReligionType) then
        local religionName	:string = Game.GetReligion():GetName(religion.ID);
        local iconName		:string = "ICON_" .. religion.ReligionType;
        local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas(iconName, 22);

        if textureSheet ~= nil then
          local religionInstance:table = m_kOtherReligionsIM:GetInstance();
          religionInstance.ReligionSymbol:SetTexture( textureSheet );
          religionInstance.ReligionSymbol:SetTextureOffsetVal( textureOffsetX, textureOffsetY );
          religionInstance.ReligionName:SetText( Locale.Lookup("LOC_HUD_CITY_RELIGIOUS_CITIZENS_NUMBER",religion.Followers,religionName) );
        else
          error("Unable to find texture "..iconName.." in a texture sheet for a CityPanel's religion symbol.");
        end
      end
    end
  end

  if Controls.PanelReligion:IsVisible() then
    SetDesiredLens("Religion");
  end
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

function GetColor( count:number )
  if count > 0 then return "StatGoodCSGlow" end
  if count < 0 then return "StatBadCSGlow" end
  return "StatNormalCSGlow";
end
function GetOffset( count:number )
  if count > 0 then return 200; end
  if count < 0 then return 0; end
  return 100;
end
-- ===========================================================================
function CQUI_BuildBubbleInstance(icon, amount, labelLOC, instanceManager)
  local kInstance :table = instanceManager:GetInstance();
  kInstance.BubbleContainer:SetTextureOffsetVal(0, GetOffset(amount));
  kInstance.BubbleIcon:SetIcon( icon );
  kInstance.BubbleIcon:SetColor(0x3fffffff);
  kInstance.BubbleAmount:SetText( Locale.ToNumber(amount) );
  kInstance.BubbleAmount:SetColorByName( GetColor(amount) );
  kInstance.BubbleLabel:SetText( CQUI_SmartWrap(Locale.Lookup(labelLOC), 10) );
  kInstance.BubbleLabel:SetColor(0xffffffff);
end
function CQUI_BuildAmenityBubbleInstance(icon, amount, labelLOC)
  CQUI_BuildBubbleInstance(icon, amount, labelLOC, m_kAmenitiesIM);
end

function CQUI_BuildHousingBubbleInstance(icon, amount, labelLOC)
  CQUI_BuildBubbleInstance(icon, amount, labelLOC, m_kHousingIM);
end

function ViewPanelAmenities( data:table )
  -- Only show the advisor bubbles during the tutorial
  -- AZURENCY : or show the advisor if the setting is enabled
  Controls.AmenitiesAdvisorBubble:SetHide( IsTutorialRunning() == false and CQUI_ShowCityDetailAdvisor == false );

  local colorName:string = GetHappinessColor(data.Happiness);
  Controls.AmenitiesConstructedLabel:SetText( Locale.Lookup( "LOC_HUD_CITY_AMENITY", data.AmenitiesNum) );
  Controls.AmenitiesConstructedNum:SetText( Locale.ToNumber(data.AmenitiesNum) );
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

  --Luxuries
  CQUI_BuildAmenityBubbleInstance("ICON_IMPROVEMENT_BEACH_RESORT", data.AmenitiesFromLuxuries, "LOC_PEDIA_RESOURCES_PAGEGROUP_LUXURY_NAME");
  --Civics
  if GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_AMENITIES_CIVICS") then
    CQUI_BuildAmenityBubbleInstance("ICON_NOTIFICATION_CONSIDER_GOVERNMENT_CHANGE", data.AmenitiesFromCivics, "LOC_CATEGORY_CIVICS_NAME");
  end
    --Entertainment
  CQUI_BuildAmenityBubbleInstance("ICON_PROJECT_CARNIVAL", data.AmenitiesFromEntertainment, "LOC_CQUI_CITY_ENTERTAINMENT");
  --Great People
  if GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_AMENITIES_GREAT_PEOPLE") then
    CQUI_BuildAmenityBubbleInstance("ICON_NOTIFICATION_CLAIM_GREAT_PERSON", data.AmenitiesFromGreatPeople, "LOC_PEDIA_CONCEPTS_PAGEGROUP_GREATPEOPLE_NAME");
  end
  --Relgion
  if GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_AMENITIES_RELIGION") then
    CQUI_BuildAmenityBubbleInstance("ICON_UNITOPERATION_FOUND_RELIGION", data.AmenitiesFromReligion, "LOC_UI_RELIGION_TITLE");
  end
    --National Parks
  if GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_AMENITIES_NATIONAL_PARKS") then
    CQUI_BuildAmenityBubbleInstance("ICON_UNITOPERATION_DESIGNATE_PARK", data.AmenitiesFromNationalParks, "LOC_PEDIA_CONCEPTS_PAGE_TOURISM_4_CHAPTER_CONTENT_TITLE");
  end
  --War Weariness
  if GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_AMENITIES_WAR_WEARINESS") then
    CQUI_BuildAmenityBubbleInstance("ICON_UNITOPERATION_FORTIFY", (data.AmenitiesLostFromWarWeariness>0 and -data.AmenitiesLostFromWarWeariness or 0), "LOC_PEDIA_CONCEPTS_PAGE_COMBAT_3_CHAPTER_CONTENT_TITLE");
  end
    --Bankruptcy
  if GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_AMENITIES_BANKRUPTCY") then
    CQUI_BuildAmenityBubbleInstance("ICON_NOTIFICATION_TREASURY_BANKRUPT", (data.AmenitiesLostFromBankruptcy>0 and -data.AmenitiesLostFromBankruptcy or 0), "LOC_PEDIA_CONCEPTS_PAGE_GOLD_4_CHAPTER_CONTENT_TITLE");
  end

  Controls.AmenitiesRequiredNum:SetText( Locale.ToNumber(data.AmenitiesRequiredNum) );
  Controls.CitizenGrowthStatus:SetTextureOffsetVal( UV_CITIZEN_GROWTH_STATUS[data.Happiness].u, UV_CITIZEN_GROWTH_STATUS[data.Happiness].v );
  Controls.CitizenGrowthStatusIcon:SetColorByName( colorName );
end

-- ===========================================================================
function ViewPanelHousing( data:table )

  -- CQUI get real housing from improvements value
  local selectedCity  = UI.GetHeadSelectedCity();
  local selectedCityID = selectedCity:GetID();
  local CQUI_HousingFromImprovements = CQUI_HousingFromImprovementsTable[selectedCityID];

  -- Only show the advisor bubbles during the tutorial
  -- AZURENCY : or show the advisor if the setting is enabled
  Controls.HousingAdvisorBubble:SetHide( IsTutorialRunning() == false and CQUI_ShowCityDetailAdvisor == false );

  m_kHousingIM:ResetInstances();

  --Buildings
  CQUI_BuildHousingBubbleInstance("ICON_BUILDING_GRANARY", data.HousingFromBuildings, "LOC_BUILDING_NAME");
  --Civics
  CQUI_BuildHousingBubbleInstance("ICON_NOTIFICATION_CONSIDER_GOVERNMENT_CHANGE", data.HousingFromCivics, "LOC_CATEGORY_CIVICS_NAME");
  --Districts
  CQUI_BuildHousingBubbleInstance("ICON_DISTRICT_CITY_CENTER", data.HousingFromDistricts, "LOC_DISTRICT_NAME");
  --Great People
  CQUI_BuildHousingBubbleInstance("ICON_NOTIFICATION_CLAIM_GREAT_PERSON", data.HousingFromGreatPeople, "LOC_PEDIA_CONCEPTS_PAGEGROUP_GREATPEOPLE_NAME");
  --Water
  CQUI_BuildHousingBubbleInstance("ICON_GREAT_PERSON_CLASS_ADMIRAL", data.HousingFromWater, "LOC_PEDIA_CONCEPTS_PAGE_CITIES_15_CHAPTER_CONTENT_TITLE");
  --Improvements
  CQUI_BuildHousingBubbleInstance("ICON_IMPROVEMENT_PASTURE", CQUI_HousingFromImprovements, "LOC_IMPROVEMENT_NAME");    -- CQUI real housing from improvements value
  --Era
  CQUI_BuildHousingBubbleInstance("ICON_GREAT_PERSON_CLASS_SCIENTIST", data.HousingFromStartingEra, "LOC_ERA_NAME");

  local colorName:string = GetPercentGrowthColor( data.HousingMultiplier ) ;
  Controls.HousingTotalNum:SetText( data.Housing - data.HousingFromImprovements + CQUI_HousingFromImprovements );    -- CQUI calculate real housing
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

  --local uv:number = data.TurnsUntilGrowth > 0 and 1 or 0;
  Controls.HousingStatus:SetTextureOffsetVal( UV_HOUSING_GROWTH_STATUS[uv].u, UV_HOUSING_GROWTH_STATUS[uv].v );
  Controls.HousingStatusIcon:SetColorByName( colorName );

  Controls.HousingAdvice:SetText(data.HousingAdvice);
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
end


-- ===========================================================================
function CreateQueueItem( index:number, kProductionInfo:table )
  local kInstance :table = m_kProductionIM:GetInstance();
  kInstance.Index:SetText( tostring(index).."." );
  kInstance.Close:RegisterCallback( Mouse.eLClick,
    function()
      m_kProductionIM:ReleaseInstance( kInstance );
      Controls.PanelStack:CalculateSize();
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
    if GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_RELIGION_TAB") then
      m_tabs.AddTab( Controls.ReligionButton,		OnSelectReligionTab );
    else
      Controls.ReligionButton:SetHide(true);
    end

    m_tabs.CenterAlignTabs(0);
  end
  m_tabs.SelectTab( Controls.HealthButton );
  m_tabs.AddAnimDeco(Controls.TabAnim, Controls.TabArrow);
end

function AutoSizeControls()
  local screenX, screenY:number = UIManager:GetScreenSizeVal()
end

function Close()
  m_isShowingPanel = false;
  --local offsetx = Controls.OverviewSlide:GetOffsetX();
  --if(offsetx == 0) then
  -- AZURENCY : only check if it's not already reversing
  if not Controls.OverviewSlide:IsReversing() then
    Controls.OverviewSlide:Reverse();
    UI.PlaySound("UI_CityPanel_Closed");
    SetDesiredLens("Default");
  end
end

function OnClose()
  Close();
end

function OnCloseButtonClicked()
  LuaEvents.CQUI_CityPanel_CityviewDisable();
end

function ViewBase(data)
  Controls.OverviewSubheader:SetText(Locale.ToUpper(Locale.Lookup(data.CityName)));

  local canChangeName = GameCapabilities.HasCapability("CAPABILITY_RENAME");
  if(canChangeName) then
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
    Controls.RenameCityButton:SetDisabled(false);
  else
    Controls.RenameCityButton:SetDisabled(true);
  end
end

function Refresh()
  -- Only refresh if panel is visible
  if m_isShowingPanel then
    m_pPlayer = Players[Game.GetLocalPlayer()];
    m_pCity	  = UI.GetHeadSelectedCity();

    if m_kData == nil then
      return;
    end

    if m_pPlayer ~= nil and m_pCity ~= nil then
      -- Trigger selection callback
      ViewBase( m_kData );
      if m_tabs.selectedControl then
        m_tabs.SelectTab(m_tabs.selectedControl);
      end
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
  if (isShowing) then
    m_isShowingPanel = true;
    if ContextPtr:IsHidden() or Controls.OverviewSlide:IsReversing() then
      Controls.PauseDismissWindow:SetToBeginning();
      ContextPtr:SetHide(false);
      Refresh();
      Controls.OverviewSlide:SetToBeginning();
      Controls.OverviewSlide:Play();
      UI.PlaySound("UI_CityPanel_Open");
    end
  else
    --local offsetx = Controls.OverviewSlide:GetOffsetX();
    --if(offsetx == 0 and not Controls.OverviewSlide:IsReversing()) then
    -- AZURENCY : only check if it's not already reversing
    if not Controls.OverviewSlide:IsReversing() then
      Controls.PauseDismissWindow:Play();
      Close();
    end
  end
  -- Ensure button state in CityPanel is correct
  LuaEvents.CityPanel_SetOverViewState(m_isShowingPanel);
end

function ToggleOverviewTab(tabButton:table)
  if m_isShowingPanel and m_tabs.selectedControl == tabButton then
   OnCloseButtonClicked();
 else
   if not m_isShowingPanel then
     OnShowOverviewPanel(true);
   end
   if m_tabs.selectedControl ~= tabButton then
     m_tabs.SelectTab( tabButton );
   end
 end
end

function OnToggleCitizensTab()
 ToggleOverviewTab( Controls.HealthButton );
end

function OnToggleBuildingsTab()
 ToggleOverviewTab( Controls.BuildingsButton );
end

function OnToggleReligionTab()
 ToggleOverviewTab( Controls.ReligionButton );
end

-- ===========================================================================
function OnHide()
  ContextPtr:SetHide(true);
  Controls.PauseDismissWindow:SetToBeginning();
end

-- ===========================================================================
--CQUI get real housing from improvements
function CQUI_HousingFromImprovementsTableInsert (pCityID, CQUI_HousingFromImprovements)
  CQUI_HousingFromImprovementsTable[pCityID] = CQUI_HousingFromImprovements;
end

-- ===========================================================================
function Initialize()
  ContextPtr:SetHide(true);

  PopulateTabs();
  Controls.PauseDismissWindow:Stop();

  ContextPtr:SetInputHandler( OnInputHandler, true );
  Controls.Close:RegisterCallback(Mouse.eLClick, OnCloseButtonClicked);
  Controls.Close:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.PauseDismissWindow:RegisterEndCallback( OnHide );

  LuaEvents.Tutorial_ResearchOpen.Add(OnClose);
  LuaEvents.ActionPanel_OpenChooseResearch.Add(OnClose);
  LuaEvents.ActionPanel_OpenChooseCivic.Add(OnClose);
  Events.SystemUpdateUI.Add( OnUpdateUI );
  LuaEvents.CityPanel_ShowOverviewPanel.Add( OnShowOverviewPanel );
  LuaEvents.CityPanel_ToggleOverviewCitizens.Add( OnToggleCitizensTab );
  LuaEvents.CityPanel_ToggleOverviewBuildings.Add( OnToggleBuildingsTab );
  LuaEvents.CityPanel_ToggleOverviewReligion.Add( OnToggleReligionTab );
  LuaEvents.CityPanel_LiveCityDataChanged.Add( OnLiveCityDataChanged )
  LuaEvents.CQUI_RealHousingFromImprovementsCalculated.Add(CQUI_HousingFromImprovementsTableInsert);    --CQUI get real housing from improvements values

  Events.SystemUpdateUI.Add( OnUpdateUI );
  Events.CityNameChanged.Add(OnCityNameChanged);
  Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );
  Events.ResearchCompleted.Add( OnResearchCompleted );
  Events.GovernmentPolicyChanged.Add( OnPolicyChanged );
  Events.GovernmentPolicyObsoleted.Add( OnPolicyChanged );
end
Initialize();
