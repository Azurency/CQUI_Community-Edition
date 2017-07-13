-- ===========================================================================
--	HUD Launch Bar
--	Controls raising full-screen and "choosers"
-- ===========================================================================

include( "GameCapabilities" );

local m_numTreesOpen:number = 0;
local isTechTreeOpen	:boolean = false;
local isCivicsTreeOpen	:boolean = false;
local isGreatPeopleOpen	:boolean = false;
local isGreatWorksOpen	:boolean = false;
local isReligionOpen	:boolean = false;
local isGovernmentOpen	:boolean = false;

local m_isGreatPeopleUnlocked	:boolean = false;
local m_isGreatWorksUnlocked	:boolean = false;
local m_isReligionUnlocked		:boolean = false;
local m_isGovernmentUnlocked	:boolean = false;

local isDebug			:boolean = false;			-- Set to true to force all hook buttons to show on game start

-- ===========================================================================
--	Callbacks
-- ===========================================================================
function OnGovernmentClick()
  local ePlayer		:number = Game.GetLocalPlayer();
  if ePlayer ~= -1 then
    localPlayer = Players[ePlayer];
    if localPlayer == nil then
      return;
    end
  else
    return;
  end
  local kCulture:table	= localPlayer:GetCulture();
  if isGovernmentOpen then
    LuaEvents.LaunchBar_CloseGovernmentPanel()
  else
    CloseAllPopups();
    if (kCulture:CivicCompletedThisTurn() and kCulture:CivicUnlocksGovernment(kCulture:GetCivicCompletedThisTurn()) and not kCulture:GovernmentChangeConsidered()) then
      -- Blocking notification that NEW GOVERNMENT is available, make sure player takes a look
      LuaEvents.LaunchBar_GovernmentOpenGovernments();
    else
      -- Normal entry to my Government
      LuaEvents.LaunchBar_GovernmentOpenMyGovernment();
    end
  end
end

-- ===========================================================================
function CloseAllPopups()
  LuaEvents.LaunchBar_CloseGreatPeoplePopup();
  LuaEvents.LaunchBar_CloseGreatWorksOverview();
  LuaEvents.LaunchBar_CloseReligionPanel();
  if isGovernmentOpen then
    LuaEvents.LaunchBar_CloseGovernmentPanel();
  end
  LuaEvents.LaunchBar_CloseTechTree();
  LuaEvents.LaunchBar_CloseCivicsTree();
end

-- ===========================================================================
function OnOpenGreatPeople()
  if isGreatPeopleOpen then
    LuaEvents.LaunchBar_CloseGreatPeoplePopup();
  else
    CloseAllPopups();
    LuaEvents.LaunchBar_OpenGreatPeoplePopup();
  end
end

-- ===========================================================================
function OnOpenGreatWorks()
  if isGreatWorksOpen then
    LuaEvents.LaunchBar_CloseGreatWorksOverview();
  else
    CloseAllPopups();
    LuaEvents.LaunchBar_OpenGreatWorksOverview();
  end
end

-- ===========================================================================
function OnOpenReligion()
  if isReligionOpen then
    LuaEvents.LaunchBar_CloseReligionPanel();
  else
    CloseAllPopups();
    LuaEvents.LaunchBar_OpenReligionPanel();
  end
end

-- ===========================================================================
function OnOpenResearch()
  if isTechTreeOpen then
    LuaEvents.LaunchBar_CloseTechTree();
  else
    CloseAllPopups();
    LuaEvents.LaunchBar_RaiseTechTree();
  end
end

-- ===========================================================================
function OnOpenCulture()
  if isCivicsTreeOpen then
    LuaEvents.LaunchBar_CloseCivicsTree();
  else
    CloseAllPopups();
    LuaEvents.LaunchBar_RaiseCivicsTree();
  end
end

-- ===========================================================================
-- CQUI: Moved here from toppanel.lua since we moved the reports button here
function OnToggleReportsScreen()
  local pReportsScreen :table = ContextPtr:LookUpControl( "/InGame/ReportScreen" );
  if pReportsScreen == nil then
    UI.DataError("Unable to toggle Reports Screen.  Not found in '/InGame/ReportScreen'.");
    return;
  end
  if pReportsScreen:IsHidden() then
    LuaEvents.TopPanel_OpenReportsScreen();
  else
    LuaEvents.TopPanel_CloseReportsScreen();
  end
end

-- ===========================================================================
function OnOpenOldCityStates()
  LuaEvents.TopPanel_OpenOldCityStatesPopup();
end

function SetCivicsTreeOpen()
  isCivicsTreeOpen = true;
  OpenTree();
end

function SetTechTreeOpen()
  isTechTreeOpen = true;
  OpenTree();
end

function SetGreatPeopleOpen()
  isGreatPeopleOpen = true;
  OpenTree();
end

function SetGreatWorksOpen()
  isGreatWorksOpen = true;
  OpenTree();
end

function SetReligionOpen()
  isReligionOpen = true;
  OpenTree();
end

function SetGovernmentOpen()
  isGovernmentOpen = true;
  OpenTree();
end

function SetCivicsTreeClosed()
  isCivicsTreeOpen = false;
  CloseTree();
end

function SetTechTreeClosed()
  isTechTreeOpen = false;
  CloseTree();
end

function SetGreatPeopleClosed()
  isGreatPeopleOpen = false;
  CloseTree();
end

function SetGreatWorksClosed()
  isGreatWorksOpen = false;
  CloseTree();
end

function SetReligionClosed()
  isReligionOpen = false;
  CloseTree();
end

function SetGovernmentClosed()
  isGovernmentOpen = false;
  CloseTree();
end

-- ===========================================================================
--	Lua Event
--	Tutorial system is requesting any screen openned, to be closed.
-- ===========================================================================
function OnTutorialCloseAll()
  CloseAllPopups();
end

-- ===========================================================================
--	Game Engine Event
-- ===========================================================================
function OnInterfaceModeChanged(eOldMode:number, eNewMode:number)
  if eNewMode == InterfaceModeTypes.VIEW_MODAL_LENS then
    ContextPtr:SetHide(true);
  end
  if eOldMode == InterfaceModeTypes.VIEW_MODAL_LENS then
    ContextPtr:SetHide(false);
  end
end


-- ===========================================================================
--	Refresh Data and View
-- ===========================================================================
function RealizeHookVisibility()

  if (HasCapability("CAPABILITY_TECH_TREE")) then
    Controls.ScienceButton:SetHide(false);
    Controls.ScienceBolt:SetHide(false);
  else
    if (not isDebug) then
      Controls.ScienceButton:SetHide(true);
      Controls.ScienceBolt:SetHide(true);
    end
  end

  if (HasCapability("CAPABILITY_CIVICS_TREE")) then
    Controls.CultureButton:SetHide(false);
    Controls.CultureBolt:SetHide(false);
  else
    if (not isDebug) then
      Controls.CultureButton:SetHide(true);
      Controls.CultureBolt:SetHide(true);
    end
  end

  if (m_isGreatPeopleUnlocked and HasCapability("CAPABILITY_GREAT_PEOPLE_VIEW")) then
    Controls.GreatPeopleButton:SetHide(false);
    Controls.GreatPeopleBolt:SetHide(false);
  else
    if (not isDebug) then
      Controls.GreatPeopleButton:SetHide(true);
      Controls.GreatPeopleBolt:SetHide(true);
    end
  end

  if (m_isReligionUnlocked and HasCapability("CAPABILITY_RELIGION_VIEW")) then
    Controls.ReligionButton:SetHide(false);
    Controls.ReligionBolt:SetHide(false);
  else
    if (not isDebug) then
      Controls.ReligionButton:SetHide(true);
      Controls.ReligionBolt:SetHide(true);
    end
  end

  if (m_isGreatWorksUnlocked and HasCapability("CAPABILITY_GREAT_WORKS_VIEW")) then
    Controls.GreatWorksButton:SetHide(false);
    Controls.GreatWorksBolt:SetHide(false);
  else
    if (not isDebug) then
      Controls.GreatWorksButton:SetHide(true);
      Controls.GreatWorksBolt:SetHide(true);
    end
  end

  if (m_isGovernmentUnlocked and HasCapability("CAPABILITY_GOVERNMENTS_VIEW")) then
    Controls.GovernmentButton:SetHide(false);
    Controls.GovernmentBolt:SetHide(true);
  else
    if (not isDebug) then
      Controls.GovernmentButton:SetHide(true);
      Controls.GovernmentBolt:SetHide(true);
    end
  end

  RefreshView();
end

--	Note on hook show/hide functionality:
--	We do not serialize any of this data, but instead we will check gamestate OnTurnBegin to determine which hooks should be shown.
--	Once the show/hide flags have been set, we return from the function before performing the checks again.
--	For all of the hooks that start in a hidden state, there are two functions needed to correctly capture the event to show/hide the hook:
--	1/2) A function for capturing the event as it happens during a turn of gameplay
--	2/2) A function to check gamestate OnTurnBegin

-- *****************************************************************************
--	Religion Hook
--	1/2) OnFaithChanged - triggered off of the FaithChanged game event
function OnFaithChanged()
  if (m_isReligionUnlocked) then
    return;
  end
  m_isReligionUnlocked = true;
  RealizeHookVisibility();
end

--	2/2) RefreshReligion - this function checks to see if any faith has been earned
function RefreshReligion()
  local ePlayer:number = Game.GetLocalPlayer();
  if ePlayer == -1 then
    -- Likely auto playing.
    return;
  end
  if m_isReligionUnlocked then
    return;
  end
  local localPlayer = Players[ePlayer];
  local playerReligion		:table	= localPlayer:GetReligion();
  local faithYield			:number = playerReligion:GetFaithYield();
  if (faithYield > 0) then
    m_isReligionUnlocked = true;
  end
  RealizeHookVisibility();
end

-- *****************************************************************************
--	Great Works Hook
--	1/2) OnGreatWorkCreated - triggered off of the GreatWorkCreated game event
--	*Note - a great work can be added and then traded away/ moved.  I think we should still allow the hook to stay
--	open in this case.  I think it would be strange behavior to have the hook be made available and then removed.
function OnGreatWorkCreated()
  if (m_isGreatWorksUnlocked) then
    return;
  end
  m_isGreatWorksUnlocked = true;
  RealizeHookVisibility();
end

-- also need to capture when a deal has left us with a great work
function OnDiplomacyDealEnacted()
  if (not m_isGreatWorksUnlocked) then
    RefreshGreatWorks();
  end
end

--	2/2) RefreshGreatWorks - go through each building checking for GW slots, then query that slot for a slotted great work
function RefreshGreatWorks()
  local ePlayer:number = Game.GetLocalPlayer();
  if ePlayer == -1 then
    -- Likely auto playing.
    return;
  end
  if m_isGreatWorksUnlocked then
    return;
  end

  localPlayer = Players[ePlayer];
  local pCities:table = localPlayer:GetCities();
  for i, pCity in pCities:Members() do
    if pCity ~= nil and pCity:GetOwner() == ePlayer then
      local pCityBldgs:table = pCity:GetBuildings();
      for buildingInfo in GameInfo.Buildings() do
        local buildingIndex:number = buildingInfo.Index;
        if(pCityBldgs:HasBuilding(buildingIndex)) then
          local numSlots:number = pCityBldgs:GetNumGreatWorkSlots(buildingIndex);
          if (numSlots ~= nil and numSlots > 0) then
            for slotIndex=0, numSlots - 1 do
              local greatWorkIndex:number = pCityBldgs:GetGreatWorkInSlot(buildingIndex, slotIndex);
              if (greatWorkIndex ~= -1) then
                m_isGreatWorksUnlocked = true;
                break;
              end
            end
          end
        end
      end
    end
  end
  RealizeHookVisibility();
end

function RefreshGreatPeople()
  local ePlayer:number = Game.GetLocalPlayer();
  if ePlayer == -1 then
    -- Likely auto playing.
    return;
  end
  if m_isGreatPeopleUnlocked then
    return;
  end

  -- Show button if we have any great people in the game
  for greatPerson in GameInfo.GreatPersonIndividuals() do
    m_isGreatPeopleUnlocked = true;
    break;
  end
  RealizeHookVisibility();
end

-- *****************************************************************************
--	Government Hook
--	1/2) OnCivicCompleted - triggered off of the CivicCompleted event - check to see if the unlocked civic unlocked our first policy
function OnCivicCompleted(player:number, civic:number, isCanceled:boolean)
  local ePlayer:number = Game.GetLocalPlayer();
  if ePlayer == -1 then
    return;
  end
  if(not m_isGovernmentUnlocked) then
    local playerCulture:table = Players[ePlayer]:GetCulture();
    if (playerCulture:GetNumPoliciesUnlocked() > 0) then
      m_isGovernmentUnlocked = true;
      RealizeHookVisibility();
    end
  end
end

--	2/2) RefreshGovernment - Check against the number of policies unlocked
function RefreshGovernment()
  local ePlayer:number = Game.GetLocalPlayer();
  if ePlayer == -1 then
    -- Likely auto playing.
    return;
  end

  -- GOVERNMENT BUTTON
  local playerCulture:table = Players[ePlayer]:GetCulture();
  if (playerCulture:GetNumPoliciesUnlocked() <= 0) then
    Controls.GovernmentButton:SetToolTipString(Locale.Lookup("LOC_GOVERNMENT_DOESNT_UNLOCK"));
    Controls.GovernmentButton:GetTextControl():SetColor(0xFF666666);
  else
    m_isGovernmentUnlocked = true;
    Controls.GovernmentButton:SetHide(false);
    Controls.GovernmentBolt:SetHide(false);
    Controls.GovernmentButton:SetToolTipString(Locale.Lookup("LOC_GOVERNMENT_MANAGE_GOVERNMENT_AND_POLICIES"));
    local bPoliciesChanged = playerCulture:PolicyChangeMade();
    local bInAnarchy = playerCulture:IsInAnarchy();
    if (bInAnarchy == true) then
      Controls.GovernmentButton:SetToolTipString("[COLOR_RED]".. Locale.Lookup("LOC_GOVERNMENT_ANARCHY_NAME") .. "[ENDCOLOR]");
      Controls.GovernmentButton:SetDisabled(true);
      Controls.GovernmentIcon:SetColorByName("Civ6Red");
    elseif (bPoliciesChanged == true) then
      Controls.GovernmentButton:SetToolTipString(Locale.Lookup("LOC_GOVERNMENT_MANAGE_GOVERNMENT_AND_POLICIES"));
      Controls.GovernmentButton:SetDisabled(false);
      Controls.GovernmentIcon:SetColorByName("White");
    else
      Controls.GovernmentIcon:SetColorByName("White");
      local iPolicyUnlockCost = playerCulture:GetCostToUnlockPolicies();
      if (iPolicyUnlockCost == 0) then
        Controls.PoliciesAvailableIndicator:SetHide(false);
        Controls.PoliciesAvailableIndicator:SetToolTipString(Locale.Lookup("LOC_HUD_GOVT_FREE_CHANGES"));
      else
        Controls.PoliciesAvailableIndicator:SetHide(true);
        Controls.PoliciesAvailableIndicator:SetToolTipString();
      end
      Controls.GovernmentButton:SetDisabled(false);
    end
  end
  RealizeHookVisibility();
end

-- ===========================================================================
function RefreshView()
  -- The Launch Bar width should accomodate how many hooks are currently in the stack.
  Controls.ButtonStack:CalculateSize();
  Controls.ButtonStack:ReprocessAnchoring();
  Controls.LaunchBacking:SetSizeX(Controls.ButtonStack:GetSizeX()+116);
  Controls.LaunchBackingTile:SetSizeX(Controls.ButtonStack:GetSizeX()-20);
  Controls.LaunchBarDropShadow:SetSizeX(Controls.ButtonStack:GetSizeX());
  -- When we change size of the LaunchBar, we send this LuaEvent to the Diplomacy Ribbon, so that it can change scroll width to accommodate it
  LuaEvents.LaunchBar_Resize(Controls.ButtonStack:GetSizeX());
end

-- ===========================================================================
function OnTurnBegin()
  local localPlayer				= Players[Game.GetLocalPlayer()];
  if (localPlayer == nil) then
    return;
  end
  local playerTechs				= localPlayer:GetTechs();
  local currentTechID		:number = playerTechs:GetResearchingTech();

  if(currentTechID >= 0) then
    local progress			:number = playerTechs:GetResearchProgress(currentTechID);
    local cost				:number	= playerTechs:GetResearchCost(currentTechID);

    Controls.ScienceMeter:SetPercent(progress/cost);
    Controls.ScienceTurnsLeft:SetText(playerTechs:GetTurnsLeft());
  else
    Controls.ScienceMeter:SetPercent(0);
    Controls.ScienceTurnsLeft:SetText("");
  end

  local techInfo:table = GameInfo.Technologies[currentTechID];
  if (techInfo ~= nil) then
    local textureString = "ICON_" .. techInfo.TechnologyType;
    local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(textureString,38);
    if textureSheet ~= nil then
      Controls.ResearchIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
    end
  end

  local playerCivics				= localPlayer:GetCulture();
  local currentCivicID    :number = playerCivics:GetProgressingCivic();

  if(currentCivicID >= 0) then
    local civicProgress			:number = playerCivics:GetCulturalProgress(currentCivicID);
    local civicCost				:number	= playerCivics:GetCultureCost(currentCivicID);

    Controls.CultureMeter:SetPercent(civicProgress/civicCost);
    Controls.CultureTurnsLeft:SetText(playerCivics:GetTurnsLeft());
  else
    Controls.CultureMeter:SetPercent(0);
    Controls.CultureTurnsLeft:SetText("");
  end

  local CivicInfo:table = GameInfo.Civics[currentCivicID];
  if (CivicInfo ~= nil) then
    local civictextureString = "ICON_" .. CivicInfo.CivicType;
    local civictextureOffsetX, civictextureOffsetY, civictextureSheet = IconManager:FindIconAtlas(civictextureString,38);
    if civictextureSheet ~= nil then
      Controls.CultureIcon:SetTexture(civictextureOffsetX, civictextureOffsetY, civictextureSheet);
    end
  end

  RefreshGovernment();
  RefreshGreatWorks();
  RefreshGreatPeople();
  RefreshReligion();
  RefreshView();
end

function OpenTree()
  m_numTreesOpen = m_numTreesOpen+1;
  local screenX, screenY:number = UIManager:GetScreenSizeVal();
  if screenY <= 850 then
    Controls.LaunchContainer:SetOffsetY(-35);
    Controls.ScienceHookWithMeter:SetOffsetY(-5);
    Controls.CultureHookWithMeter:SetOffsetY(-5);
  end
end

function CloseTree()
  m_numTreesOpen = m_numTreesOpen-1;
  if(m_numTreesOpen < 0 )then
    m_numTreesOpen = 0;
  end
  if m_numTreesOpen == 0 then
    Controls.LaunchContainer:SetOffsetY(-5);
    Controls.ScienceHookWithMeter:SetOffsetY(25);
    Controls.CultureHookWithMeter:SetOffsetY(25);
  end
end

-- ===========================================================================
function OnToggleResearchPanel(hideResearch)
  Controls.ScienceHookWithMeter:SetHide(not hideResearch);
end

function OnToggleCivicPanel(hideResearch)
  Controls.CultureHookWithMeter:SetHide(not hideResearch);
end

-- Reset the hooks when the player changes for hotseat.
function OnLocalPlayerChanged()
  m_isGreatPeopleUnlocked	= false;
  m_isGreatWorksUnlocked	= false;
  m_isReligionUnlocked	= false;
  m_isGovernmentUnlocked	= false;
  RefreshGovernment();
  RefreshGreatPeople();
  RefreshGreatWorks();
  RefreshReligion();
end

-- ===========================================================================
function Initialize()

  local iconName = "ICON_CIVIC_FUTURE_CIVIC";
  local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName,38);
  if (textureOffsetX ~= nil) then
    Controls.ReportsImage:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
  end

  Controls.CultureButton:RegisterCallback(Mouse.eLClick, OnOpenCulture);
  Controls.CultureButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.CultureMeterButton:RegisterCallback(Mouse.eLClick, OnOpenCulture);
  Controls.GovernmentButton:RegisterCallback( Mouse.eLClick, OnGovernmentClick );
  Controls.GovernmentButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.GreatPeopleButton:RegisterCallback( Mouse.eLClick, OnOpenGreatPeople );
  Controls.GreatPeopleButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.GreatWorksButton:RegisterCallback( Mouse.eLClick, OnOpenGreatWorks );
  Controls.GreatWorksButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.ReligionButton:RegisterCallback( Mouse.eLClick, OnOpenReligion );
  Controls.ReligionButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.ScienceButton:RegisterCallback(Mouse.eLClick, OnOpenResearch);
  Controls.ScienceButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.ScienceMeterButton:RegisterCallback(Mouse.eLClick, OnOpenResearch);

  -- CQUI --
  Controls.ReportsButton:RegisterCallback(Mouse.eLClick, OnToggleReportsScreen);
  Controls.ReportsButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  -- CQUI --

  Events.TurnBegin.Add( OnTurnBegin );
  Events.VisualStateRestored.Add( OnTurnBegin );
  Events.CivicCompleted.Add( OnCivicCompleted );				-- To capture when we complete Code of Laws
  Events.CivicChanged.Add(OnTurnBegin);
  Events.ResearchChanged.Add(OnTurnBegin);
  Events.TreasuryChanged.Add( RefreshGovernment );
  Events.GovernmentPolicyChanged.Add( RefreshGovernment );
  Events.GovernmentPolicyObsoleted.Add( RefreshGovernment );
  Events.GovernmentChanged.Add( RefreshGovernment );
  Events.AnarchyBegins.Add( RefreshGovernment );
  Events.AnarchyEnds.Add( RefreshGovernment );
  Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
  Events.GreatWorkCreated.Add( OnGreatWorkCreated );
  Events.FaithChanged.Add( OnFaithChanged );
  Events.LocalPlayerChanged.Add( OnLocalPlayerChanged );
  Events.DiplomacyDealEnacted.Add( OnDiplomacyDealEnacted );

  LuaEvents.CivicsTree_CloseCivicsTree.Add(SetCivicsTreeClosed);
  LuaEvents.CivicsTree_OpenCivicsTree.Add( SetCivicsTreeOpen );
  LuaEvents.Government_CloseGovernment.Add( SetGovernmentClosed );
  LuaEvents.Government_OpenGovernment.Add( SetGovernmentOpen );
  LuaEvents.GreatPeople_CloseGreatPeople.Add( SetGreatPeopleClosed );
  LuaEvents.GreatPeople_OpenGreatPeople.Add( SetGreatPeopleOpen );
  LuaEvents.GreatWorks_CloseGreatWorks.Add( SetGreatWorksClosed );
  LuaEvents.GreatWorks_OpenGreatWorks.Add( SetGreatWorksOpen );
  LuaEvents.Religion_CloseReligion.Add( SetReligionClosed );
  LuaEvents.Religion_OpenReligion.Add( SetReligionOpen );
  LuaEvents.TechTree_CloseTechTree.Add(SetTechTreeClosed);
  LuaEvents.TechTree_OpenTechTree.Add( SetTechTreeOpen );
  LuaEvents.Tutorial_CloseAllLaunchBarScreens.Add( OnTutorialCloseAll );

  if HasCapability("CAPABILITY_TECH_TREE") then
    LuaEvents.WorldTracker_ToggleResearchPanel.Add(OnToggleResearchPanel);
  end
  if HasCapability("CAPABILITY_CIVICS_TREE") then
    LuaEvents.WorldTracker_ToggleCivicPanel.Add(OnToggleCivicPanel);
  end

  OnTurnBegin();
end
Initialize();
