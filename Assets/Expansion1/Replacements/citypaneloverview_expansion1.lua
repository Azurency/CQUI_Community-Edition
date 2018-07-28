--[[
-- Created by Tyler Berry, Aug 15 2017
-- Copyright (c) Firaxis Games
--]]
-- ===========================================================================
-- Base File
-- ===========================================================================
include("CityPanelOverview");

-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_HideAll = HideAll;
BASE_PopulateTabs = PopulateTabs;
BASE_ViewPanelCitizensGrowth = ViewPanelCitizensGrowth;
BASE_View = View;
BASE_ViewPanelAmenities = ViewPanelAmenities;

-- ===========================================================================
-- New Members
-- ===========================================================================
local m_CulturePanel = nil;
local m_ButtonInstance = nil;
local m_ButtonColor = "DarkBlue";
local m_ToolTip = "LOC_HUD_CITY_CULTURE_TOOLTIP";

------------------------------------------------------------------------------------------------
-- Code related to the a new tab: Cultural Identity
------------------------------------------------------------------------------------------------
function HideAll()
  BASE_HideAll();
  if m_ButtonInstance then
    m_ButtonInstance.Button:SetSelected(false);
    m_ButtonInstance.Icon:SetColorByName("White");
  end
end

function PopulateTabs()
  BASE_PopulateTabs();
  if m_ButtonInstance == nil then
    m_ButtonInstance = m_kTabButtonIM:GetInstance();
    m_ButtonInstance.Icon:SetIcon("ICON_STAT_GOVERNOR");
    m_ButtonInstance.Button:SetToolTipString(Locale.Lookup(m_ToolTip));

    m_tabs.AddTab(m_ButtonInstance.Button, function()
      HideAll();
      
      -- Context has to be shown before CityPanelTabRefresh to ensure a proper Refresh
      m_CulturePanel:SetHide(false);

      m_ButtonInstance.Button:SetSelected(true);
      m_ButtonInstance.Icon:SetColorByName(m_ButtonColor);
      UI.PlaySound("UI_CityPanel_ButtonClick");
      Controls.PanelDynamicTab:SetHide(false);
      
      RefreshCulturalIdentityPanel();
    end);
    m_tabs.CenterAlignTabs(0);
  end
  m_tabs.SelectTab( Controls.HealthButton );
  m_tabs.AddAnimDeco(Controls.TabAnim, Controls.TabArrow);
end

function ViewPanelCitizensGrowth( data:table )
  BASE_ViewPanelCitizensGrowth(data);

  -- Display growth changes related to Loyalty
  local pCity = UI.GetHeadSelectedCity();
  if (pCity ~= nil) then
    local pCityGrowth = pCity:GetGrowth();
    local loyaltyModifier = (pCityGrowth:GetLoyaltyGrowthModifier() * 100) - 100;
    local cityIdentity = pCity:GetCulturalIdentity();
    local loyaltyLevel = cityIdentity:GetLoyaltyLevel();
    local loyaltyLevelName = GameInfo.LoyaltyLevels[loyaltyLevel].Name;
    Controls.OccupationLabel:LocalizeAndSetText(loyaltyLevelName);
    if (Round(loyaltyModifier, 0) ~= 0) then
      Controls.OccupationMultiplier:LocalizeAndSetText(toPlusMinusString(Round(loyaltyModifier, 0)) .. "%");
    else
      Controls.OccupationMultiplier:LocalizeAndSetText("LOC_CULTURAL_IDENTITY_LOYALTY_NO_GROWTH_PENALTY");
    end
  end

  --Override the occupation penalty (this is mostly redundant code but necessary to recompute the final value)
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
    Controls.TurnsUntilBornLost:SetText( Locale.Lookup("LOC_HUD_CITY_TURNS_UNTIL_CITIZEN_BORN", data.TurnsUntilGrowth));
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
end

function View(data)
  BASE_View(data);
  if m_tabs.selectedControl == m_ButtonInstance.Button then
    RefreshCulturalIdentityPanel();
  end
end

function RefreshCulturalIdentityPanel()
  SetDesiredLens("Loyalty");
  LuaEvents.CityPanelTabRefresh();
end

function OnToggleLoyaltyTab()
  if m_ButtonInstance then
    ToggleOverviewTab(m_ButtonInstance.Button);
  end
end

function ViewPanelAmenities(data:table)
  BASE_ViewPanelAmenities(data);

  --kInstance = m_kAmenitiesIM:GetInstance();
  --kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_LOST_FROM_GOVERNORS") );
  --kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromGovernors) );

  CQUI_BuildAmenityBubbleInstance("ICON_GOVERNOR_THE_EDUCATOR", data.AmenitiesFromGovernors, "LOC_REPORTS_GOVERNOR");
  
  
end

function Initialize()
  m_CulturePanel = ContextPtr:LoadNewContext("CityPanelCulture", Controls.PanelDynamicTab);
  m_CulturePanel:SetSizeX(Controls.PanelDynamicTab:GetSizeX());
  m_CulturePanel:SetSizeY(Controls.PanelDynamicTab:GetSizeY());
  LuaEvents.CityPanel_ToggleOverviewLoyalty.Add( OnToggleLoyaltyTab );
  PopulateTabs();
end
Initialize();
-- ===========================================================================