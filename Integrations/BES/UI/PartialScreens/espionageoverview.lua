-- ===========================================================================
---- ESPIONAGE OVERVIEW ----
-- ===========================================================================
include( "InstanceManager" );
include( "AnimSidePanelSupport" );
include( "SupportFunctions" );
include( "EspionageSupport" );
include( "TabSupport" );
include( "Colors" );

-- ===========================================================================
-- CONSTANTS
-- ===========================================================================

local RELOAD_CACHE_ID:string = "EspionageOverview"; -- Must be unique (usually the same as the file name)
local MAX_BEFORE_TRUNC_MISSION_NAME     :number = 170;
local MAX_BEFORE_TRUNC_ASK_FOR_TRADE    :number = 135;

local TRAVEL_DEST_TRUNCATE_WIDTH        :number = 170;

local EspionageTabs:table = {
  OPERATIVES      = 0;
  CITY_ACTIVITY   = 1;
  MISSION_HISTORY = 2;
};

-- The maximum number of districts we can show before we have to make them scroll
local NUM_DISTRICTS_WITHOUT_SCROLL      :number = 7;

-- ===========================================================================
--  MEMBERS
-- ===========================================================================

local m_AnimSupport:table; -- AnimSidePanelSupport

local m_OperativeIM:table       = InstanceManager:new("OperativeInstance", "Top", Controls.OperativeStack);
local m_CityIM:table            = InstanceManager:new("CityInstance", "CityGrid", Controls.CityActivityStack);
local m_CityDistrictIM:table    = InstanceManager:new("CityDistrictInstance", "DistrictIcon");
local m_EnemyOperativeIM:table  = InstanceManager:new("EnemyOperativeInstance", "GridButton", Controls.CapturedEnemyOperativeStack);
local m_MissionHistoryIM:table  = InstanceManager:new("MissionHistoryInstance", "Top", Controls.MissionHistoryStack);

-- A table of tabs indexed by EspionageTabs enum
local m_tabs:table = nil;
local m_selectedTab:number = -1;

-- Stores filter list and tracks the currently selected list
local m_filterList:table = {};
local m_filterCount:number = 0;
local m_filterSelected:number = 1;

local m_DistrictFilterChoiceIM:table = InstanceManager:new("DistrictsFilterInstance", "DistrictsFilterButton", Controls.DistrictsFilterStack);
local m_DistrictFilterSelection:table = {}

-- ===========================================================================
function Refresh()
  -- Refresh Tabs
  PopulateTabs();

  if m_selectedTab == EspionageTabs.OPERATIVES then
    Controls.OperativeTabContainer:SetHide(false);
    Controls.CityActivityTabContainer:SetHide(true);
    Controls.MissionHistoryTabContainer:SetHide(true);

    RefreshOperatives();
  elseif m_selectedTab == EspionageTabs.CITY_ACTIVITY then
    Controls.OperativeTabContainer:SetHide(true);
    Controls.CityActivityTabContainer:SetHide(false);
    Controls.MissionHistoryTabContainer:SetHide(true);

    RefreshFilters();
    RefreshCityActivity();
  elseif m_selectedTab == EspionageTabs.MISSION_HISTORY then
    Controls.OperativeTabContainer:SetHide(true);
    Controls.CityActivityTabContainer:SetHide(true);
    Controls.MissionHistoryTabContainer:SetHide(false);

    RefreshMissionHistory();
  end
end

function RefreshOperatives()
  m_OperativeIM:ResetInstances();

  local localPlayerID = Game.GetLocalPlayer();
  if (localPlayerID == -1) then
    return;
  end

  local idleSpies:table = {};
  local activeSpies:table = {};
  local travellingSpies:table = {};

  -- Track the number of spies for display in the header
  local numberOfSpies:number = 0;

  -- Sort spies
  local localPlayerUnits:table = Players[localPlayerID]:GetUnits();
  for i, unit in localPlayerUnits:Members() do
    local unitInfo:table = GameInfo.Units[unit:GetUnitType()];
    if unitInfo.Spy then
      local operationType:number = unit:GetSpyOperation();
      if operationType == -1 then
        table.insert(idleSpies, unit);
      else
        table.insert(activeSpies, unit);
      end

      numberOfSpies = numberOfSpies + 1;
    end
  end

  -- Display idle spies
  for i, spy in ipairs(idleSpies) do
    AddOperative(spy);
  end

  -- Display active spies
  for i, spy in ipairs(activeSpies) do
    AddOperative(spy);
  end

  -- Display captured spies
  -- Loop through all players to see if they have any of our captured spies
  local players:table = Game.GetPlayers();
  for i, player in ipairs(players) do
    local playerDiplomacy:table = player:GetDiplomacy();
    local numCapturedSpies:number = playerDiplomacy:GetNumSpiesCaptured();
    for i=0,numCapturedSpies-1,1 do
      local spyInfo:table = playerDiplomacy:GetNthCapturedSpy(player:GetID(), i);
      if spyInfo and spyInfo.OwningPlayer == Game.GetLocalPlayer() then
        AddCapturedOperative(spyInfo, player:GetID());
        numberOfSpies = numberOfSpies + 1;
      end
    end
  end

  -- Display travelling spies
  local playerDiplomacy:table = Players[Game.GetLocalPlayer()]:GetDiplomacy();
  if playerDiplomacy then
    local numSpiesOffMap:number = playerDiplomacy:GetNumSpiesOffMap();
    for i=0,numSpiesOffMap-1,1 do
      local spyOffMapInfo:table = playerDiplomacy:GetNthOffMapSpy(Game.GetLocalPlayer(), i);
      if spyOffMapInfo and spyOffMapInfo.ReturnTurn ~= -1 then
        AddOffMapOperative(spyOffMapInfo);
        numberOfSpies = numberOfSpies + 1;
      end
    end
  end

  -- Display a messsage if we have no spies
  Controls.NoOperativesLabel:SetHide(numberOfSpies ~= 0);

  -- Update spy count and capcity
  local playerDiplomacy:table = Players[Game.GetLocalPlayer()]:GetDiplomacy();
  Controls.OperativeHeader:SetText(Locale.Lookup("LOC_ESPIONAGEOVERVIEW_OPERATIVES_SUBHEADER", numberOfSpies, playerDiplomacy:GetSpyCapacity()));

  Controls.OperativeStack:CalculateSize();
  Controls.OperativeScrollPanel:CalculateSize();
end

-- ===========================================================================
function RefreshCityActivity()
  m_CityIM:ResetInstances();

  local localPlayer:table = Players[Game.GetLocalPlayer()];
  if not localPlayer then
    return;
  end

  -- Reset all the district icon instances shared between city instances
  m_CityDistrictIM:ResetInstances();

  -- Add player owned cities
  AddPlayerCities(localPlayer);

  -- Add cities for other players
  local players:table = Game.GetPlayers();
  for i, player in ipairs(players) do
    -- Ignore the local player since those cities were already added
    if player:GetID() ~= localPlayer:GetID() then
      -- Only show full civs
      if player:IsMajor() then
        AddPlayerCities(player);
      end
    end
  end

  -- Show a message if we have no cities to display
  Controls.NoCitiesLabel:SetHide(m_CityIM.m_iAllocatedInstances ~= 0);

  Controls.CityActivityScrollPanel:CalculateSize();
end

-- ===========================================================================
function RefreshMissionHistory()
  m_EnemyOperativeIM:ResetInstances();

  local localPlayerID = Game.GetLocalPlayer();
  if (localPlayerID == -1) then
    return;
  end

  -- Update captured enemy operative info
  local haveCapturedEnemyOperative:boolean = false;
  local localPlayer:table = Players[localPlayerID];
  local playerDiplomacy:table = localPlayer:GetDiplomacy();
  local numCapturedSpies:number = playerDiplomacy:GetNumSpiesCaptured();
  for i=0,numCapturedSpies-1,1 do
    local spyInfo:table = playerDiplomacy:GetNthCapturedSpy(localPlayer:GetID(), i);
    if spyInfo then
      haveCapturedEnemyOperative = true;
      AddCapturedEnemyOperative(spyInfo);
    end
  end

  -- Hide captured enemy operative info if we have no captured enemy operatives
  if haveCapturedEnemyOperative then
    Controls.CapturedEnemyOperativeContainer:SetHide(false);
  else
    Controls.CapturedEnemyOperativeContainer:SetHide(true);
  end

  -- Update mission history
  m_MissionHistoryIM:ResetInstances();

  if playerDiplomacy then
    -- Add information for last 10 missions
    local recentMissions:table = playerDiplomacy:GetRecentMissions(Game.GetLocalPlayer(), 10, 0);
    if recentMissions then
      -- Hide no missions label
      Controls.NoRecentMissonsLabel:SetHide(true);

      for i,mission in pairs(recentMissions) do
        AddMissionHistoryInstance(mission);
      end
    else
      -- Show no missions label
      Controls.NoRecentMissonsLabel:SetHide(false);
    end
  end

  -- Show a message if we have no history or enemy operatives to display
  Controls.NoHistoryLabel:SetHide(m_EnemyOperativeIM.m_iAllocatedInstances ~= 0 or m_MissionHistoryIM.m_iAllocatedInstances ~= 0);

  ResizeMissionHistoryScrollPanel();

  Controls.MissionHistoryScrollPanel:CalculateSize();
end

-- ===========================================================================
function ResizeMissionHistoryScrollPanel()
  -- Track size of elements in mission history panel to determine size of the mission history scroll panel
  local desiredScrollPanelSizeY:number = Controls.MissionHistoryTabContainer:GetSizeY();

  if not Controls.CapturedEnemyOperativeContainer:IsHidden() then
    desiredScrollPanelSizeY = desiredScrollPanelSizeY - Controls.CapturedEnemyOperativeContainer:GetSizeY();
  end

  -- Adjust the mission history scroll panel to fill bottom of panel
  desiredScrollPanelSizeY = desiredScrollPanelSizeY - Controls.MissionHistoryScrollPanel:GetOffsetY();

  Controls.MissionHistoryScrollPanel:SetSizeY(desiredScrollPanelSizeY);
end

-- ===========================================================================
function OnCapturedEnemyOperativeContainerSizeChanged()
  ResizeMissionHistoryScrollPanel();
end

-- ===========================================================================
function AddMissionHistoryInstance(mission:table)
  -- Don't show missions where the spy must escape but the player has yet to choose an escape route
  if mission.InitialResult == EspionageResultTypes.SUCCESS_MUST_ESCAPE or mission.InitialResult == EspionageResultTypes.FAIL_MUST_ESCAPE then
    if mission.EscapeResult == EspionageResultTypes.NO_RESULT then
      return;
    end
  end

  local missionHistoryInstance:table = m_MissionHistoryIM:GetInstance();

  -- Update operative name and rank
  missionHistoryInstance.OperativeName:SetText(Locale.ToUpper(mission.Name));
  missionHistoryInstance.OperativeRank:SetText(Locale.Lookup(GetSpyRankNameByLevel(mission.LevelAfter)));

  -- Update name and turns since
  local operationInfo:table = GameInfo.UnitOperations[mission.Operation];
  missionHistoryInstance.MissionName:SetText(Locale.Lookup(operationInfo.Description));
  local turnsSinceMission:number = Game.GetCurrentGameTurn() - mission.CompletionTurn;
  missionHistoryInstance.TurnsSinceMission:SetText(Locale.Lookup("LOC_ESPIONAGEOVERVIEW_TURNS_AGO", turnsSinceMission));

  -- Update outcome and font icon
  local outcomeDetails:table = GetMissionOutcomeDetails(mission);
  if outcomeDetails then
    if outcomeDetails.Success then
      missionHistoryInstance.MissionOutcomeText:SetText(Locale.ToUpper("LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME") .. " " .. Locale.ToUpper("LOC_ESPIONAGEOVERVIEW_SUCCESS"));
    else
      missionHistoryInstance.MissionOutcomeText:SetText(Locale.ToUpper("LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME") .. " " .. Locale.ToUpper("LOC_ESPIONAGEOVERVIEW_FAILURE"));
    end

    SetMissionHistorySuccess(missionHistoryInstance, outcomeDetails.Success);
    missionHistoryInstance.OperationDetails:SetText(outcomeDetails.Description);

    if outcomeDetails.SpyStatus ~= "" then
      missionHistoryInstance.MissionOutcomeSpyStatus:SetText(outcomeDetails.SpyStatus);
      missionHistoryInstance.MissionOutcomeSpyStatus:SetHide(false);
    else
      missionHistoryInstance.MissionOutcomeSpyStatus:SetHide(true);
    end
  end

  -- Update mission and district icons
  local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(operationInfo.Icon,40);
  if textureSheet then
    missionHistoryInstance.OperationIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
    missionHistoryInstance.OperationIcon:SetHide(false);
  else
    UI.DataError("Unable to find icon for spy operation: " .. operationInfo.Icon);
    missionHistoryInstance.OperationIcon:SetHide(true);
  end

  local iconString:string = "ICON_DISTRICT_CITY_CENTER";
  if operationInfo.TargetDistrict then
    iconString = "ICON_" .. operationInfo.TargetDistrict;
  elseif operationInfo.Hash == UnitOperationTypes.SPY_COUNTERSPY then
    local pTargetPlot:table = Map.GetPlotByIndex(mission.PlotIndex);
    local kDistrictInfo:table = GameInfo.Districts[pTargetPlot:GetDistrictType()];
    iconString = "ICON_" .. kDistrictInfo.DistrictType;
  end
  textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconString,32);
  if textureSheet then
    missionHistoryInstance.OperationDistrictIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
  else
    UI.DataError("Unable to find icon for district: " .. iconString);
  end

  -- Scale the operation and district icons to match the operation description
  missionHistoryInstance.OperationIconGrid:SetSizeY(missionHistoryInstance.OperationDetailsContainer:GetSizeY());
  missionHistoryInstance.OperationDistrictIconGrid:SetSizeY(missionHistoryInstance.OperationDetailsContainer:GetSizeY());
end

-- ===========================================================================
function SetMissionHistorySuccess(missionHistoryInstance:table, wasSuccess:boolean)
  if wasSuccess then
    missionHistoryInstance.MissionGradient:SetColorByName("Green");
    missionHistoryInstance.MissionOutcomeText:SetColor(0xFF329600);
    missionHistoryInstance.MissionOutcomeSpyStatus:SetColor(0xFF329600);
    missionHistoryInstance.MissionOutcomeFontIcon:SetText("[ICON_CheckSuccess]");
  else
    missionHistoryInstance.MissionGradient:SetColorByName("Red");
    missionHistoryInstance.MissionOutcomeText:SetColor(0xFF0000C6);
    missionHistoryInstance.MissionOutcomeSpyStatus:SetColor(0xFF0000C6);
    missionHistoryInstance.MissionOutcomeFontIcon:SetText("[ICON_CheckFail]");
  end
end

-- ===========================================================================
function AddPlayerCities(player:table)
  if m_filterList[m_filterSelected].FilterFunction(player) then
    local playerCities:table = player:GetCities();
    for j, city in playerCities:Members() do
      if CheckDistrictFilters(city) then
        -- Check if the city is revealed
        local localPlayerVis:table = PlayersVisibility[Game.GetLocalPlayer()];
        if localPlayerVis:IsRevealed(city:GetX(), city:GetY()) then
          AddCity(city);
        end
      end
    end
  end
end

-- ===========================================================================
function AddCity(city:table)
  local cityInstance:table = m_CityIM:GetInstance();

  -- Update city banner
  local backColor:number, frontColor:number  = UI.GetPlayerColors( city:GetOwner() );

  cityInstance.BannerBase:SetColor( backColor );
  cityInstance.CityName:SetColor( frontColor );
  cityInstance.BannerBase:LocalizeAndSetToolTip("LOC_ESPIONAGEOVERVIEW_VIEW_CITY");
  cityInstance.BannerBase:RegisterCallback( Mouse.eLClick, function() LookAtCity(city:GetOwner(), city:GetID()); end );
  cityInstance.BannerBase:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

  -- Update capital indicator but never show it for city-states
  local cityName:string = "";
  if city:IsCapital() and Players[city:GetOwner()]:IsMajor() then
    cityName = "[ICON_Capital]" .. " " .. Locale.ToUpper(city:GetName());
  else
    cityName = Locale.ToUpper(city:GetName());
  end
  TruncateString(cityInstance.CityName, 220, cityName);

  -- Update district icons
  local pCityDistricts:table = city:GetDistricts();
  if pCityDistricts ~= nil then
    -- Show or hide scroll arrows based on number of districts
    local bNeedsToScroll:boolean = pCityDistricts:GetNumDistricts() > NUM_DISTRICTS_WITHOUT_SCROLL;
    if bNeedsToScroll then
      cityInstance.CurrentScrollPos = 1;
      cityInstance.DistrictsScrollLeftButton:SetHide(false);
      cityInstance.DistrictsScrollLeftButton:SetDisabled(true);
      cityInstance.DistrictsScrollRightButton:SetHide(false);

      cityInstance.DistrictsScrollLeftButton:RegisterCallback( Mouse.eLClick, function() OnDistrictsLeftButton(cityInstance); end );
      cityInstance.DistrictsScrollRightButton:RegisterCallback( Mouse.eLClick, function() OnDistrictsRightButton(cityInstance); end );
    else
      cityInstance.DistrictsScrollLeftButton:SetHide(true);
      cityInstance.DistrictsScrollRightButton:SetHide(true);
    end

    -- Populate districts
    local iNumDistrictsThisCity:number = 0;
    for _, pDistrict in pCityDistricts:Members() do
      local kDistrictIconInst:table = AddDistrictIcon(cityInstance.CityDistrictStack, city, pDistrict);
      if kDistrictIconInst ~= nil then
        iNumDistrictsThisCity = iNumDistrictsThisCity + 1;

        if bNeedsToScroll and iNumDistrictsThisCity > (NUM_DISTRICTS_WITHOUT_SCROLL - 1) then
          kDistrictIconInst.DistrictIcon:SetHide(true);
        end
      end
    end
  end

  -- Update gain sources boost icon
  local player = Players[Game.GetLocalPlayer()];
  local playerDiplomacy:table = player:GetDiplomacy();
  if playerDiplomacy then
    local boostedTurnsRemaining:number = playerDiplomacy:GetSourceTurnsRemaining(city);
    if boostedTurnsRemaining > 0 then
      cityInstance.GainSourcesBoostIcon:SetHide(false);
    else
      cityInstance.GainSourcesBoostIcon:SetHide(true);
    end
  end

  if shouldShowCounterspyIcon then
    cityInstance.CounterspyIconBack:SetHide(false);
    cityInstance.CounterspyIconBack:SetColor( backColor );
    cityInstance.CounterspyIconFront:SetColor( frontColor );
  else
    cityInstance.CounterspyIconBack:SetHide(true);
  end
end

-- ===========================================================================
function OnDistrictsLeftButton( kCityInstance:table )
  kCityInstance.CurrentScrollPos = kCityInstance.CurrentScrollPos - 1;
  local kChildren:table = kCityInstance.CityDistrictStack:GetChildren();

  -- Always enable right button if we scroll left
  kCityInstance.DistrictsScrollRightButton:SetDisabled(false);

  -- Disable left button if we reach the beginning of the list
  if kCityInstance.CurrentScrollPos == 1 then
    kCityInstance.DistrictsScrollLeftButton:SetDisabled(true);
  end

  -- Show/hide children based on the current scroll pos
  -- (NUM_DISTRICTS_WITHOUT_SCROLL - 2) makes room for the 2 scroll buttons
  for i, kChild in ipairs(kChildren) do
    if i < kCityInstance.CurrentScrollPos or i > (kCityInstance.CurrentScrollPos + NUM_DISTRICTS_WITHOUT_SCROLL - 2) then
      kChild:SetHide(true);
    else
      kChild:SetHide(false);
    end
  end
end

-- ===========================================================================
function OnDistrictsRightButton( kCityInstance:table )
  kCityInstance.CurrentScrollPos = kCityInstance.CurrentScrollPos + 1;
  local kChildren:table = kCityInstance.CityDistrictStack:GetChildren();

  -- Always enable left button if we scroll right
  kCityInstance.DistrictsScrollLeftButton:SetDisabled(false);

  -- Disable right button if we're at the end of the list
  if (kCityInstance.CurrentScrollPos + NUM_DISTRICTS_WITHOUT_SCROLL - 2) >= #kChildren then
    kCityInstance.DistrictsScrollRightButton:SetDisabled(true);
  end

  -- Show/hide children based on the current scroll pos
  -- (NUM_DISTRICTS_WITHOUT_SCROLL - 2) makes room for the 2 scroll buttons
  for i, kChild in ipairs(kChildren) do
    if i < kCityInstance.CurrentScrollPos or i > (kCityInstance.CurrentScrollPos + NUM_DISTRICTS_WITHOUT_SCROLL - 2) then
      kChild:SetHide(true);
    else
      kChild:SetHide(false);
    end
  end
end

-- ===========================================================================
function AddDistrictIcon(kStackControl:table, pCity:table, pDistrict:table)
  if not pDistrict:IsComplete() then
    return nil;
  end

  local kDistrictDef:table = GameInfo.Districts[pDistrict:GetType()];
  if kDistrictDef == nil or kDistrictDef.DistrictType == "DISTRICT_WONDER" then
    return nil;
  end

  local kInstance:table = m_CityDistrictIM:GetInstance( kStackControl );

  kInstance.DistrictIcon:SetIcon("ICON_" .. kDistrictDef.DistrictType);
  local sToolTip:string = Locale.Lookup(kDistrictDef.Name);

  -- Check if one of our spies is active in this district
  local bShouldShowActiveSpy:boolean = false;
  local pPlayerUnits:table = Players[Game.GetLocalPlayer()]:GetUnits();
  for i, pUnit in pPlayerUnits:Members() do
    local kUnitDef:table = GameInfo.Units[pUnit:GetUnitType()];
    if not bShouldShowActiveSpy and kUnitDef.Spy then
      local eOperationType:number = pUnit:GetSpyOperation();
      local kOperationDef:table = GameInfo.UnitOperations[eOperationType];
      if kOperationDef then
        local pSpyPlot:table = Map.GetPlot(pUnit:GetX(), pUnit:GetY());
        local pTargetCity:table = Cities.GetPlotPurchaseCity(pSpyPlot);
        if pTargetCity:GetOwner() == pCity:GetOwner() and pTargetCity:GetID() == pCity:GetID() then
          local iSpyDistrictID:number = pSpyPlot:GetDistrictID();
          if pDistrict:GetID() == iSpyDistrictID then
            bShouldShowActiveSpy = true;
            sToolTip = sToolTip .. "[NEWLINE]" .. Locale.Lookup(pUnit:GetName()) .. "[NEWLINE]" .. Locale.Lookup(kOperationDef.Description);
          end
        end
      end
    end
  end

  kInstance.DistrictIcon:SetToolTipString( sToolTip );

  if bShouldShowActiveSpy then
    local backColor:number, frontColor:number  = UI.GetPlayerColors( Game.GetLocalPlayer() );
    kInstance.SpyIconBack:SetColor( backColor );
    kInstance.SpyIconFront:SetColor( frontColor );
    kInstance.SpyIconBack:SetHide(false);
  else
    kInstance.SpyIconBack:SetHide(true);
  end

  return kInstance;
end

-- ===========================================================================
--  Called once during Init
-- ===========================================================================
function PopulateTabs()
  local localPlayerID:number = Game.GetLocalPlayer();
  if localPlayerID == -1 then
    return;
  end

  -- Grab player and diplomacy for local player
  local pPlayer:table = Players[localPlayerID];
  local pPlayerDiplomacy:table = nil;
  if pPlayer then
    pPlayerDiplomacy = pPlayer:GetDiplomacy();
  end

  if m_tabs == nil then
    m_tabs = CreateTabs( Controls.TabContainer, 42, 34, 0xFF331D05 );
  end

  -- Operatives Tab
  if not m_tabs.OperativesTabAdded then
    m_tabs.AddTab( Controls.OperativesTabButton,        OnSelectOperativesTab );
    Controls.OperativesTabButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
    m_tabs.OperativesTabAdded = true;
  end

  -- City Activity Tab
  if not m_tabs.CityActivityTabAdded then
    m_tabs.AddTab( Controls.CityActivityTabButton,      OnSelectCityActivityTab );
    Controls.CityActivityTabButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
    m_tabs.CityActivityTabAdded = true;
  end

  -- Mission History Tab
  -- Only show mission history if we have any mission history or captured enemy operatives
  local shouldShowMissionHistory:boolean = false;
  if pPlayerDiplomacy then
    local firstMission = pPlayerDiplomacy:GetMission(localPlayerID, 0);
    if firstMission ~= 0 then
      -- We have a mission so show history
      shouldShowMissionHistory = true;
    end

    local numCapturedSpies:number = pPlayerDiplomacy:GetNumSpiesCaptured();
    if numCapturedSpies > 0 then
      -- Show mission history if we have captured enemy spies
      shouldShowMissionHistory = true;
    end
  end

  if shouldShowMissionHistory then
    if not m_tabs.MissionHistoryTabAdded then
      Controls.MissionHistoryTabButton:SetHide(false);
      m_tabs.AddTab( Controls.MissionHistoryTabButton,    OnSelectMissionHistoryTab );
      Controls.MissionHistoryTabButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
      m_tabs.MissionHistoryTabAdded = true;
    end
  else
    Controls.MissionHistoryTabButton:SetHide(true);
  end

  m_tabs.EvenlySpreadTabs();
  m_tabs.CenterAlignTabs(-25);    -- Use negative to create padding as value represents amount to overlap
end

-- ===========================================================================
function SelectTabByIndex( tabIndex:number )
  if tabIndex == EspionageTabs.CITY_ACTIVITY then
    m_tabs.SelectTab( Controls.CityActivityTabButton );
  elseif tabIndex == EspionageTabs.MISSION_HISTORY then
    m_tabs.SelectTab( Controls.MissionHistoryTabButton );
  else
    m_tabs.SelectTab( Controls.OperativesTabButton );
  end
end

-- ===========================================================================
function OnSelectOperativesTab()
  m_selectedTab = EspionageTabs.OPERATIVES;
  Refresh();
end

-- ===========================================================================
function OnSelectCityActivityTab()
  m_selectedTab = EspionageTabs.CITY_ACTIVITY;
  Refresh();
end

-- ===========================================================================
function OnSelectMissionHistoryTab()
  m_selectedTab = EspionageTabs.MISSION_HISTORY;
  Refresh();
end

-- ===========================================================================
function AddOperative(spy:table)
  local operativeInstance:table = m_OperativeIM:GetInstance();

  local spyInfo:table = GameInfo.Units[spy:GetUnitType()];

  -- Operative Name
  operativeInstance.OperativeName:SetText(Locale.ToUpper(spy:GetName()));

  -- Operative Rank
  local spyExperience:table = spy:GetExperience();
  operativeInstance.OperativeRank:SetText(Locale.Lookup(GetSpyRankNameByLevel(spyExperience:GetLevel())));

  -- City Banner
  local spyPlot = Map.GetPlot(spy:GetX(), spy:GetY());
  local ownerCity = Cities.GetPlotPurchaseCity(spyPlot);
  if ownerCity then
    local backColor:number, frontColor:number  = UI.GetPlayerColors( ownerCity:GetOwner() );
    operativeInstance.CityBanner:SetColor( backColor );
    operativeInstance.LocationPip:SetColor( frontColor );
    operativeInstance.CityName:SetColor( frontColor );
    operativeInstance.CityName:SetText(Locale.ToUpper(ownerCity:GetName()));
    operativeInstance.CityBanner:LocalizeAndSetToolTip("LOC_ESPIONAGEOVERVIEW_VIEW_CITY");
    operativeInstance.CityBanner:RegisterCallback( Mouse.eLClick, function() LookAtCity(ownerCity:GetOwner(), ownerCity:GetID()); end );
    operativeInstance.CityBanner:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
    operativeInstance.CityBanner:SetHide(false);
  else
    operativeInstance.CityBanner:SetHide(true);
  end

  local operationType:number = spy:GetSpyOperation();
  if operationType == -1 then
    -- Awaiting Assignment
    operativeInstance.Top:SetTextureOffsetVal(0, 73);

    operativeInstance.AwaitingAssignmentStack:SetHide(false);
    operativeInstance.ActiveMissionContainer:SetHide(true);
    operativeInstance.TravellingContainer:SetHide(true);
    operativeInstance.CapturedContainer:SetHide(true);
  else
    -- On Active Assignment
    operativeInstance.Top:SetTextureOffsetVal(0, 0);

    -- Operation Name
    local operationInfo:table = GameInfo.UnitOperations[operationType];
    TruncateStringWithTooltip(operativeInstance.OperationName, MAX_BEFORE_TRUNC_MISSION_NAME, Locale.Lookup(operationInfo.Description));

    -- Turns Remaining
    local turnsRemaining:number = spy:GetSpyOperationEndTurn() - Game.GetCurrentGameTurn();
    if turnsRemaining <= 0 then
      turnsRemaining = 0;
    end
    operativeInstance.OperationTurnsRemaining:SetText(Locale.Lookup("LOC_ESPIONAGEOVERVIEW_MORE_TURNS", turnsRemaining));

    -- Percent Complete
    local totalTurns:number = UnitManager.GetTimeToComplete(operationType, spy);
    local percentOperationComplete:number = (totalTurns - turnsRemaining) / totalTurns;
    operativeInstance.OperationPercentComplete:SetPercent(percentOperationComplete);

    -- Operation Icon
    local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(operationInfo.Icon,40);
    if textureSheet then
      operativeInstance.OperationIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
      operativeInstance.OperationIcon:SetHide(false);
    else
      UI.DataError("Unable to find icon for spy operation: " .. operationInfo.Icon);
      operativeInstance.OperationIcon:SetHide(true);
    end

    -- Operation District Icon
    local spyPlot:table = Map.GetPlot(spy:GetX(), spy:GetY());
    local districtType = spyPlot:GetDistrictType();
    local districtInfo = GameInfo.Districts[districtType];
    if districtInfo then
      local iconString:string = "ICON_" .. districtInfo.DistrictType;
      textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconString,32);
      operativeInstance.OperationDistrictIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
    end

    -- Operation Details
    if ownerCity then
      if operationInfo.Hash == UnitOperationTypes.SPY_COUNTERSPY then
        operativeInstance.OperationDetails:SetText(Locale.Lookup("LOC_ESPIONAGECHOOSER_COUNTERSPY", Locale.Lookup(districtInfo.Name)));
      else
        operativeInstance.OperationDetails:SetText(GetFormattedOperationDetailText(operationInfo, spy, ownerCity));
      end
    end

    operativeInstance.AwaitingAssignmentStack:SetHide(true);
    operativeInstance.ActiveMissionContainer:SetHide(false);
    operativeInstance.TravellingContainer:SetHide(true);
    operativeInstance.CapturedContainer:SetHide(true);
  end
end

-- ===========================================================================
function LookAtCity(playerID:number, cityID:number)
  local player = Players[playerID];
  if player then
    city = player:GetCities():FindID(cityID);
    UI.LookAtPlotScreenPosition( city:GetX(), city:GetY(), 0.33, 0.5 );
  end
end

------------------------------------------------------------------------------------------------
function AddOffMapOperative(spy:table)
  local operativeInstance:table = m_OperativeIM:GetInstance();

  -- Adjust texture offset
  operativeInstance.Top:SetTextureOffsetVal(0, 146);

  -- Operative Name
  operativeInstance.OperativeName:SetText(Locale.ToUpper(spy.Name));

  -- Operative Rank
  operativeInstance.OperativeRank:SetText(Locale.Lookup(GetSpyRankNameByLevel(spy.Level)));

  -- Travel Time
  local travelTurnsRemaining:number = spy.ReturnTurn - Game.GetCurrentGameTurn();
  operativeInstance.TravelTurnsRemaining:SetText(Locale.Lookup("LOC_ESPIONAGEOVERVIEW_MORE_TURNS", travelTurnsRemaining));

  -- Travel Percentage Complete
  operativeInstance.TravelPercentComplete:SetPercent(0);

  -- Get city name
  local spyPlot:table = Map.GetPlot(spy.XLocation, spy.YLocation);
  local targetCity:table = Cities.GetPlotPurchaseCity(spyPlot);
  if targetCity then
    TruncateStringWithTooltip(operativeInstance.TravelDestinationName, TRAVEL_DEST_TRUNCATE_WIDTH, Locale.Lookup("LOC_ESPIONAGEOVERVIEW_TRANSIT_TO", targetCity:GetName()));
  end

  operativeInstance.CityBanner:SetHide(true);
  operativeInstance.AwaitingAssignmentStack:SetHide(true);
  operativeInstance.ActiveMissionContainer:SetHide(true);
  operativeInstance.TravellingContainer:SetHide(false);
  operativeInstance.CapturedContainer:SetHide(true);
end

------------------------------------------------------------------------------------------------
function AddCapturedOperative(spy:table, playerCapturedBy:number)
  local operativeInstance:table = m_OperativeIM:GetInstance();

  -- Adjust texture offset
  operativeInstance.Top:SetTextureOffsetVal(0, 146);

  -- Operative Name
  operativeInstance.OperativeName:SetText(Locale.ToUpper(spy.Name));

  -- Operative Rank
  operativeInstance.OperativeRank:SetText(Locale.Lookup(GetSpyRankNameByLevel(spy.Level)));

  -- Update information about the player who captured the spy
  local capturingPlayerConfig:table = PlayerConfigurations[playerCapturedBy];
  if capturingPlayerConfig then
    local backColor:number, frontColor:number  = UI.GetPlayerColors( playerCapturedBy );
    local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas("ICON_" .. capturingPlayerConfig:GetCivilizationTypeName(),22);
    operativeInstance.CapturingCivIconBack:SetColor(backColor);
    operativeInstance.CapturingCivIconFront:SetColor(frontColor);
    operativeInstance.CapturingCivIconFront:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
    operativeInstance.CapturingCivName:SetText(Locale.Lookup(capturingPlayerConfig:GetPlayerName()));
    TruncateStringWithTooltip(operativeInstance.AskForTradeButton, MAX_BEFORE_TRUNC_ASK_FOR_TRADE, Locale.Lookup("LOC_ESPIONAGEOVERVIEW_ASK_FOR_TRADE"));

    -- Show the ask trade button, if there is no pending deal.
    local localPlayerID:number = Game.GetLocalPlayer();
    local atWarWith:boolean = Players[localPlayerID]:GetDiplomacy():IsAtWarWith(playerCapturedBy);
    if atWarWith then
      operativeInstance.AskForTradeButton:SetDisabled(true);
      operativeInstance.AskForTradeButton:SetToolTipString(Locale.Lookup("LOC_DIPLOPANEL_AT_WAR"));
    elseif DealManager.HasPendingDeal(localPlayerID, playerCapturedBy) then
      operativeInstance.AskForTradeButton:SetDisabled(true);
      operativeInstance.AskForTradeButton:SetToolTipString(Locale.Lookup("LOC_DIPLOMACY_ANOTHER_DEAL_WITH_PLAYER_PENDING"));
    else
      operativeInstance.AskForTradeButton:SetDisabled(false);
      operativeInstance.AskForTradeButton:RegisterCallback( Mouse.eLClick, function() OnAskForOperativeTradeClicked(playerCapturedBy, spy.NameIndex); end );
      operativeInstance.AskForTradeButton:SetToolTipString("");
    end
  else
    UI.DataError("Could not find player configuration for player ID: " .. tostring(playerCapturedBy));
  end

  operativeInstance.CityBanner:SetHide(true);
  operativeInstance.AwaitingAssignmentStack:SetHide(true);
  operativeInstance.ActiveMissionContainer:SetHide(true);
  operativeInstance.TravellingContainer:SetHide(true);
  operativeInstance.CapturedContainer:SetHide(false);
end

------------------------------------------------------------------------------------------------
function OnAskForOperativeTradeClicked(capturingPlayerID:number, capturedSpyID:number)
  -- Can't do this if we already have a pending deal
  if (not DealManager.HasPendingDeal(Game.GetLocalPlayer(), capturingPlayerID)) then
    -- Clear deal
    DealManager.ClearWorkingDeal(DealDirection.OUTGOING, Game.GetLocalPlayer(), capturingPlayerID);

    local bDealValid = false;

    -- Add the spy to the deal
    local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, Game.GetLocalPlayer(), capturingPlayerID);
    if (pDeal ~= nil) then
      local pDealItem = pDeal:AddItemOfType(DealItemTypes.CAPTIVE, capturingPlayerID);
      if (pDealItem ~= nil) then
        -- The value of the deal item holds the spy's index
        pDealItem:SetValueType( capturedSpyID );
        if (pDealItem:IsValid()) then
          pDealItem:SetLocked(true);
          bDealValid = true;
        end
      end
    end

    -- Request the diplomacy session.  This will open the deal screen, with the deal in its current state.
    if (bDealValid) then
      DiplomacyManager.RequestSession(Game.GetLocalPlayer(), capturingPlayerID, "MAKE_DEAL");
    else
      DealManager.ClearWorkingDeal(DealDirection.OUTGOING, Game.GetLocalPlayer(), capturingPlayerID);
    end
  end
end

------------------------------------------------------------------------------------------------
function AddCapturedEnemyOperative(spyInfo:table)
  local enemyOperativeInstance:table = m_EnemyOperativeIM:GetInstance();

  -- Update spy name
  local spyName:string = Locale.ToUpper(spyInfo.Name);
  enemyOperativeInstance.SpyName:SetText(spyName);

  -- Update owning civ spy icon
  local backColor:number, frontColor:number  = UI.GetPlayerColors( spyInfo.OwningPlayer );
  enemyOperativeInstance.SpyIconBack:SetColor(backColor);
  enemyOperativeInstance.SpyIconFront:SetColor(frontColor);

  -- Update owning civ name
  local owningPlayerConfig:table = PlayerConfigurations[spyInfo.OwningPlayer];
  enemyOperativeInstance.CivName:SetText(Locale.Lookup(owningPlayerConfig:GetCivilizationDescription()));

  local pLocalPlayerDiplo:table = Players[Game.GetLocalPlayer()]:GetDiplomacy();
  if pLocalPlayerDiplo and not pLocalPlayerDiplo:IsAtWarWith(spyInfo.OwningPlayer) then
    -- If we're not at war with the spies owner allow trading for that spy
    enemyOperativeInstance.OfferTradeText:SetHide(false);
    enemyOperativeInstance.GridButton:SetDisabled(false);
    enemyOperativeInstance.GridButton:RegisterCallback( Mouse.eLClick, function() OnAskForEnemyOperativeTradeClicked(spyInfo.OwningPlayer, spyInfo.NameIndex); end );
    enemyOperativeInstance.GridButton:SetToolTipString("");
  else
    enemyOperativeInstance.OfferTradeText:SetHide(true);
    enemyOperativeInstance.GridButton:SetDisabled(true);
    enemyOperativeInstance.GridButton:ClearCallback( Mouse.eLClick );
    enemyOperativeInstance.GridButton:SetToolTipString(Locale.Lookup("LOC_ESPIONAGE_SPY_TRADE_DISABLED_AT_WAR", spyName, Locale.Lookup(owningPlayerConfig:GetCivilizationShortDescription())));
  end

  Controls.CapturedEnemyOperativeStack:CalculateSize();
end

------------------------------------------------------------------------------------------------
function OnAskForEnemyOperativeTradeClicked(owningPlayerID:number, capturedSpyID:number)
  -- Clear deal
  DealManager.ClearWorkingDeal(DealDirection.OUTGOING, Game.GetLocalPlayer(), owningPlayerID);

  -- Add the spy to the deal
  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, Game.GetLocalPlayer(), owningPlayerID);
  if (pDeal ~= nil) then
    local pDealItem = pDeal:AddItemOfType(DealItemTypes.CAPTIVE, Game.GetLocalPlayer());
    if (pDealItem ~= nil) then
      ---- The value of the deal item holds the spy's index
      pDealItem:SetLocked(true);
      pDealItem:SetValueType( capturedSpyID );
    end
  end

  -- Request the diplomacy session.  This will open the deal screen, with the deal in its current state.
  DiplomacyManager.RequestSession(Game.GetLocalPlayer(), owningPlayerID, "MAKE_DEAL");
end

------------------------------------------------------------------------------------------------
function Close()
  m_AnimSupport:Hide();
  if not ContextPtr:IsHidden() then
    UI.PlaySound("CityStates_Panel_Close");
  end
end

------------------------------------------------------------------------------------------------
function Open(forceTabIndex:number)
  -- dont show panel if there is no local player
  local localPlayerID = Game.GetLocalPlayer();
  if (localPlayerID == -1) then
    return
  end

  m_AnimSupport:Show();

  if forceTabIndex then
    SelectTabByIndex( forceTabIndex );
  else
    -- Default to Operatives tab
    m_tabs.SelectTab( Controls.OperativesTabButton );
  end
end

------------------------------------------------------------------------------------------------
function OnLocalPlayerTurnEnd()
  if(GameConfiguration.IsHotseat()) then
    Close();
  end
end

-- ---------------------------------------------------------------------------
-- Filter helper functions
-- ---------------------------------------------------------------------------

function HasMetAndAlive(player:table)
  local localPlayerID = Game.GetLocalPlayer()
  if localPlayerID == player:GetID() then
    return true
  end

  local localPlayer = Players[localPlayerID];
  local localPlayerDiplomacy = localPlayer:GetDiplomacy();

  if player:IsAlive() and localPlayerDiplomacy:HasMet(player:GetID()) then
    return true;
  end

  return false;
end

function ShouldAddToFilter(player:table)
  if HasMetAndAlive(player) and (not player:IsBarbarian()) then
    return true
  end
  return false
end

-- ---------------------------------------------------------------------------
-- Filter pulldown functions
-- ---------------------------------------------------------------------------
function RefreshFilters()
  -- Clear current filters
  Controls.DestinationFilterPulldown:ClearEntries();
  m_filterList = {};
  m_filterCount = 0;

  -- Add "All" Filter
  AddFilter(Locale.Lookup("LOC_ESPIONAGECHOOSER_FILTER_ALL"), function(a) return true; end);

  -- Add Players Filter
  local players:table = Game.GetPlayers();
  for i, pPlayer in ipairs(players) do
    if ShouldAddToFilter(pPlayer) then
      if pPlayer:IsMajor() then
        local playerConfig:table = PlayerConfigurations[pPlayer:GetID()];
        local name = Locale.Lookup(GameInfo.Civilizations[playerConfig:GetCivilizationTypeID()].Name);
        AddFilter(name, function(a) return a:GetID() == pPlayer:GetID() end);
      end
    end
  end

  -- Add "City States" Filter
  AddFilter(Locale.Lookup("LOC_HUD_REPORTS_CITY_STATE"), function(a) return a:IsMinor() end);

  -- Add International Filter
  AddFilter(Locale.Lookup("LOC_ESPIONAGECHOOSER_FILTER_INTERNATIONAL"), function(a) return a:GetID() ~= Game.GetLocalPlayer() end);

  -- Add filters to pulldown
  for index, filter in ipairs(m_filterList) do
    AddFilterEntry(index);
  end

  -- Select first filter
  Controls.FilterButton:SetText(m_filterList[m_filterSelected].FilterText);

  -- Calculate Internals
  Controls.DestinationFilterPulldown:CalculateInternals();

  UpdateFilterArrow();
end

function AddFilter( filterName:string, filterFunction )
  -- Make sure we don't add duplicate filters
  for index, filter in ipairs(m_filterList) do
    if filter.FilterText == filterName then
      return;
    end
  end

  m_filterCount = m_filterCount + 1;
  m_filterList[m_filterCount] = {FilterText=filterName, FilterFunction=filterFunction};
end

function AddFilterEntry( filterIndex:number )
  local filterEntry:table = {};
  Controls.DestinationFilterPulldown:BuildEntry( "FilterEntry", filterEntry );
  filterEntry.Button:SetText(m_filterList[filterIndex].FilterText);
  filterEntry.Button:SetVoids(i, filterIndex);
end

function UpdateFilterArrow()
  if Controls.DestinationFilterPulldown:IsOpen() then
    Controls.PulldownOpenedArrow:SetHide(true);
    Controls.PulldownClosedArrow:SetHide(false);
  else
    Controls.PulldownOpenedArrow:SetHide(false);
    Controls.PulldownClosedArrow:SetHide(true);
  end
end

function OnFilterSelected( index:number, filterIndex:number )
  m_filterSelected = filterIndex;
  Controls.FilterButton:SetText(m_filterList[m_filterSelected].FilterText);

  print("selected filter " .. m_filterSelected)
  Refresh();
end

-- ---------------------------------------------------------------------------
-- Disctrict Filter Panel
-- ---------------------------------------------------------------------------
function CheckDistrictFilters(pCity:table)
  if table.count(m_DistrictFilterSelection) > 0 then
    for district, isChecked in pairs(m_DistrictFilterSelection) do
      if isChecked and not hasDistrict(pCity, district) then
        return false
      end
    end
  end
  return true
end


function BuildDistrictFilterPanel()
  m_DistrictFilterChoiceIM:ResetInstances()

  for row in GameInfo.Districts() do
    -- Skip the following districts
    -- 1. City Center
    -- 2. Wonder
    if row.DistrictType ~= "DISTRICT_CITY_CENTER" and row.DistrictType ~= "DISTRICT_WONDER" then
      -- Ensure that this is not a district that replaces another district
      local validRow:boolean = true
      for replcRow in GameInfo.DistrictReplaces() do
        if replcRow.CivUniqueDistrictType == row.DistrictType then
          validRow = false
          break
        end
      end

      if validRow then
        local kInstance:table = m_DistrictFilterChoiceIM:GetInstance()
        kInstance.DistrictIcon:SetIcon("ICON_" .. row.DistrictType);
        local sLabel:string = Locale.Lookup(row.Name);
        kInstance.DistrictLabel:SetText(sLabel);
        kInstance.DistrictsFilterButton:RegisterCallback(Mouse.eLClick, 
        function()
        print(row.DistrictType)
        if not m_DistrictFilterSelection[row.DistrictType] then
          kInstance.DistrictsFilterButton:SetTextureOffsetVal(0, 24)
          m_DistrictFilterSelection[row.DistrictType] = true
        else
          kInstance.DistrictsFilterButton:SetTextureOffsetVal(0, 0)
          m_DistrictFilterSelection[row.DistrictType] = false
        end

        Refresh();
        end)

        -- If the entry already exits, use the state from history
        if m_DistrictFilterSelection[row.DistrictType] ~= nil then
          if m_DistrictFilterSelection[row.DistrictType] then
            kInstance.DistrictsFilterButton:SetTextureOffsetVal(0, 24)
          else
            kInstance.DistrictsFilterButton:SetTextureOffsetVal(0, 0)
          end
        else
          kInstance.DistrictsFilterButton:SetTextureOffsetVal(0, 0)
          m_DistrictFilterSelection[row.DistrictType] = false
        end
      end
    end
  end

  Controls.DistrictsFilterStack:CalculateSize()
  Controls.DistrictsFilterGrid:DoAutoSize()
end

function OnDistrictFilterPanelOpen()
  Controls.DistrictsFilterGrid:SetHide(false)
  Controls.DistrictsFilterShownButton:SetTextureOffsetVal(0, 40)
  BuildDistrictFilterPanel()
end

function OnDistrictFilterPanelClose()
  Controls.DistrictsFilterGrid:SetHide(true)
  Controls.DistrictsFilterShownButton:SetTextureOffsetVal(0, 0)
end

-- ===========================================================================
--  Game Event
-- ===========================================================================
function OnInterfaceModeChanged(eOldMode:number, eNewMode:number)
  if eNewMode == InterfaceModeTypes.VIEW_MODAL_LENS then
    Close();
  end
end

------------------------------------------------------------------------------------------------
function OnSpyRemoved(spyOwner, counterSpyPlayer)
  if (not ContextPtr:IsHidden()) then
    if (spyOwner == Game.GetLocalPlayer()) then
      if (m_selectedTab == EspionageTabs.OPERATIVES) then
        RefreshOperatives();
      end
    end
  end
end

------------------------------------------------------------------------------------------------
function OnSpyAdded(spyOwner, spyUnitID)
  if (not ContextPtr:IsHidden()) then
    if (spyOwner == Game.GetLocalPlayer()) then
      if (m_selectedTab == EspionageTabs.OPERATIVES) then
        RefreshOperatives();
      end
    end
  end
end

function OnDiplomacyDealEnacted()
  if (not ContextPtr:IsHidden()) then
    if (m_selectedTab == EspionageTabs.MISSION_HISTORY) then
      RefreshMissionHistory();
    end
  end
end

------------------------------------------------------------------------------------------------
function OnClose()
  Close();
end

------------------------------------------------------------------------------------------------
function OnOpen()
  UI.PlaySound("CityStates_Panel_Open");
  Open();
end

------------------------------------------------------------------------------------------------
function OnCloseAllExcept(contextToStayOpen:string)
  if contextToStayOpen ~= ContextPtr:GetID() then
    Close();
  end
end

-- ===========================================================================
function OnUnitOperationStarted(ownerID:number, unitID:number, operationID:number)
  if m_AnimSupport.IsVisible() then
    Refresh();
  end
end

-- ===========================================================================
--  UI EVENT
-- ===========================================================================
function OnInit(isReload:boolean)
  if isReload then
    LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
  end
end

-- ===========================================================================
--  UI EVENT
-- ===========================================================================
function OnShutdown()
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isVisible", m_AnimSupport:IsVisible());
  LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "selectedTab", m_selectedTab);
end

-- ===========================================================================
--  LUA EVENT
--  Reload support
-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
  if context == RELOAD_CACHE_ID then
    if contextTable["isVisible"] ~= nil and contextTable["isVisible"] then
      Open();
    end
    if contextTable["selectedTab"] ~= nil then
      SelectTabByIndex( contextTable["selectedTab"] );
    end
  end
end

-- ===========================================================================
function Initialize()
  Controls.Title:SetText(Locale.Lookup("LOC_ESPIONAGE_TITLE"));

  -- Control Events
  Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);
  Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.CapturedEnemyOperativeContainer:RegisterSizeChanged( OnCapturedEnemyOperativeContainerSizeChanged );

  -- Filter Pulldown
  Controls.FilterButton:RegisterCallback( eLClick, UpdateFilterArrow );
  Controls.DestinationFilterPulldown:RegisterSelectionCallback( OnFilterSelected );

  -- District Filter Panel
  Controls.DistrictsFilterShownButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.DistrictsFilterShownButton:RegisterCallback( Mouse.eLClick,
  function()
    if Controls.DistrictsFilterGrid:IsHidden() then
      OnDistrictFilterPanelOpen()
    else
      OnDistrictFilterPanelClose()
    end
    end);

    -- Lua Events
    LuaEvents.PartialScreenHooks_OpenEspionage.Add( OnOpen );
    LuaEvents.PartialScreenHooks_CloseEspionage.Add( OnClose );
    LuaEvents.PartialScreenHooks_CloseAllExcept.Add( OnCloseAllExcept );

    -- Animation Controller
    m_AnimSupport = CreateScreenAnimation(Controls.SlideAnim);

    -- Rundown / Screen Events
    Events.SystemUpdateUI.Add(m_AnimSupport.OnUpdateUI);
    ContextPtr:SetInputHandler(m_AnimSupport.OnInputHandler, true);

    -- Game Engine Events
    Events.UnitOperationStarted.Add( OnUnitOperationStarted );
    Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );

    Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );

    Events.SpyAdded.Add( OnSpyAdded );
    Events.SpyRemoved.Add( OnSpyRemoved );
    Events.DiplomacyDealEnacted.Add( OnDiplomacyDealEnacted ); -- Folks may be trading captured spies, if they do we must update the panel

    -- Hot-Reload Events
    ContextPtr:SetInitHandler(OnInit);
    ContextPtr:SetShutdown(OnShutdown);
    LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);

    PopulateTabs();
  end
  Initialize();
