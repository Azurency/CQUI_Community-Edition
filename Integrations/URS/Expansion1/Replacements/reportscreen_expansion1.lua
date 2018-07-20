--[[
-- Copyright (c) 2017 Firaxis Games
--]]
-- ===========================================================================
-- INCLUDE BASE FILE
-- ===========================================================================
include("ReportScreen");


function ViewCityStatusPage()
  
  ResetTabForNewPageContent()
  
  -- Remember this tab when report is next opened: ARISTOS
  m_kCurrentTab = 3;
  
  -- ARISTOS: Hide the checkbox if not in Yields tab
  Controls.CityBuildingsCheckbox:SetHide( true );
  
  local instance:table = m_simpleIM:GetInstance()
  instance.Top:DestroyAllChildren()
  
  instance.Children = {}
  instance.Descend = false
  
  local pHeaderInstance:table = {}
  ContextPtr:BuildInstanceForControl( "CityStatusHeaderInstance", pHeaderInstance, instance.Top )
  
  pHeaderInstance.CityNameButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "name", instance ) end )
  pHeaderInstance.CityPopulationButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "pop", instance ) end )
  pHeaderInstance.CityHousingButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "house", instance ) end )
  pHeaderInstance.CityGrowthButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "growth", instance ) end )
  pHeaderInstance.CityAmenitiesButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "amen", instance ) end )
  pHeaderInstance.CityHappinessButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "happy", instance ) end )
  pHeaderInstance.CityWarButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "war", instance ) end )
  pHeaderInstance.CityStatusButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "status", instance ) end )
  pHeaderInstance.CityStrengthButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "str", instance ) end )
  pHeaderInstance.CityDamageButton:RegisterCallback( Mouse.eLClick, function() instance.Descend = not instance.Descend; sort_cities( "dam", instance ) end )
  
  --
  for cityName,kCityData in pairs( m_kCityData ) do
    
    local pCityInstance:table = {}
    
    ContextPtr:BuildInstanceForControl( "CityStatusEntryInstance", pCityInstance, instance.Top )
    table.insert( instance.Children, pCityInstance )
    
    city_fields( kCityData, pCityInstance )
    
  end
  
  Controls.Stack:CalculateSize();
  Controls.Scroll:CalculateSize();
  
  Controls.CollapseAll:SetHide(true);
  Controls.BottomYieldTotals:SetHide( true );
  Controls.BottomResourceTotals:SetHide( true );
  Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - 88);
end

function city_fields( kCityData, pCityInstance )

  TruncateStringWithTooltip(pCityInstance.CityName, 130, Locale.Lookup(kCityData.CityName)); 
  pCityInstance.Population:SetText( tostring(kCityData.Population) .. "/" .. tostring(kCityData.Housing) );

		if kCityData.HousingMultiplier == 0 or kCityData.Occupied then
    status = "LOC_HUD_REPORTS_STATUS_HALTED";
  elseif kCityData.HousingMultiplier <= 0.5 then
    status = "LOC_HUD_REPORTS_STATUS_SLOWED";
  else
    status = "LOC_HUD_REPORTS_STATUS_NORMAL";
  end

  pCityInstance.GrowthRateStatus:SetText( Locale.Lookup(status) );

  -- CQUI get real housing from improvements value
  local kCityID = kCityData.City:GetID();
  local CQUI_HousingFromImprovements = CQUI_HousingFromImprovementsTable[kCityID];
  pCityInstance.Housing:SetText( tostring( kCityData.Housing - kCityData.HousingFromImprovements + CQUI_HousingFromImprovements ) );    -- CQUI calculate real housing
  pCityInstance.Amenities:SetText( tostring(kCityData.AmenitiesNum).." / "..tostring(kCityData.AmenitiesRequiredNum) );

  local happinessText:string = Locale.Lookup( GameInfo.Happinesses[kCityData.Happiness].Name );
  pCityInstance.CitizenHappiness:SetText( happinessText );

  local warWearyValue:number = kCityData.AmenitiesLostFromWarWeariness;
  pCityInstance.WarWeariness:SetText( (warWearyValue==0) and "0" or "-"..tostring(warWearyValue) );

  local statusText:string = kCityData.IsUnderSiege and Locale.Lookup("LOC_HUD_REPORTS_STATUS_UNDER_SEIGE") or Locale.Lookup("LOC_HUD_REPORTS_STATUS_NORMAL");
  TruncateStringWithTooltip(pCityInstance.Status, 80, statusText); 

  -- Loyalty
  local pCulturalIdentity = kCityData.City:GetCulturalIdentity();
  local currentLoyalty = pCulturalIdentity:GetLoyalty();
  local maxLoyalty = pCulturalIdentity:GetMaxLoyalty();
  local loyaltyPerTurn:number = pCulturalIdentity:GetLoyaltyPerTurn();
  local loyaltyFontIcon:string = loyaltyPerTurn >= 0 and "[ICON_PressureUp]" or "[ICON_PressureDown]";
  pCityInstance.Loyalty:SetText(loyaltyFontIcon .. " " .. Round(currentLoyalty, 1) .. "/" .. maxLoyalty);
  
  local pAssignedGovernor = kCityData.City:GetAssignedGovernor();
  if pAssignedGovernor then
    local eGovernorType = pAssignedGovernor:GetType();
    local governorDefinition = GameInfo.Governors[eGovernorType];
    local governorMode = pAssignedGovernor:IsEstablished() and "_FILL" or "_SLOT";
    local governorIcon = "ICON_" .. governorDefinition.GovernorType .. governorMode;
    pCityInstance.Governor:SetText("[" .. governorIcon .. "]");
  else
    pCityInstance.Governor:SetText("");
  end
    
  pCityInstance.Strength:SetText( tostring(kCityData.Defense) );
  pCityInstance.Damage:SetText( tostring(kCityData.HitpointsTotal - kCityData.HitpointsCurrent) );

end

function Initialize()

  Resize();

  m_tabIM:ResetInstances();
  m_tabs = CreateTabs( Controls.TabContainer, 42, 34, 0xFF331D05 );
  AddTabSection( "LOC_HUD_REPORTS_TAB_YIELDS",		ViewYieldsPage );
  AddTabSection( "LOC_HUD_REPORTS_TAB_RESOURCES",	ViewResourcesPage );
  AddTabSection( "LOC_HUD_REPORTS_TAB_CITY_STATUS",	ViewCityStatusPage );
  AddTabSection( "LOC_HUD_REPORTS_TAB_CURRENT_DEALS", ViewDealsPage );
  AddTabSection( "LOC_UNIT_NAME",						ViewUnitsPage );

  m_tabs.SameSizedTabs(0);
  m_tabs.CenterAlignTabs(-10);	
end
Initialize();
