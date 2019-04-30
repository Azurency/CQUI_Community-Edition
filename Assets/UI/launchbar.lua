-- ===========================================================================
--	HUD's "Launch Bar"
--	Copyright (c) 2017-2019 Firaxis Games
--
--	Controls raising full-screen and "choosers" found in upper-left of HUD.
-- ===========================================================================
include( "GameCapabilities" );

-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_numOpen               :number = 0;

local isTechTreeOpen          :boolean = false;
local isCivicsTreeOpen        :boolean = false;
local isGreatPeopleOpen       :boolean = false;
local isGreatWorksOpen        :boolean = false;
local isReligionOpen          :boolean = false;
local isGovernmentOpen        :boolean = false;

local m_isGreatPeopleUnlocked :boolean = false;
local m_isGreatWorksUnlocked  :boolean = false;
local m_isReligionUnlocked    :boolean = false;
local m_isGovernmentUnlocked  :boolean = false;

local m_isTechTreeAvailable    :boolean = false;
local m_isCivicsTreeAvailable  :boolean = false;
local m_isGovernmentAvailable  :boolean = false;
local m_isReligionAvailable    :boolean = false;
local m_isGreatPeopleAvailable :boolean = false;
local m_isGreatWorksAvailable  :boolean = false;

local isDebug:boolean = false;     -- Set to true to force all hook buttons to show on game start

-- Launchbar Extras. Contains the callback and the button text
local m_LaunchbarExtras:table = {};

-- ===========================================================================
--  Callbacks
-- ===========================================================================
function OnOpenGovernment()
  local ePlayer:number = Game.GetLocalPlayer();
  if ePlayer == -1 then
    return; -- Probably autoplay
  end

  local localPlayer:table = Players[ePlayer];
  if localPlayer == nil then
    return;
  end

  local kCulture:table = localPlayer:GetCulture();
  if ( kCulture:IsInAnarchy() ) then -- Anarchy? No gov't for you.
    if isGovernmentOpen then
      LuaEvents.LaunchBar_CloseGovernmentPanel()
    end
    return;
  end

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
function SetCivicsTreeOpen()
  isCivicsTreeOpen = true;
  OnOpen();
end

-- ===========================================================================
function SetTechTreeOpen()
  isTechTreeOpen = true;
  OnOpen();
end

-- ===========================================================================
function SetGreatPeopleOpen()
  isGreatPeopleOpen = true;
  OnOpen();
end

-- ===========================================================================
function SetGreatWorksOpen()
  isGreatWorksOpen = true;
  OnOpen();
end

-- ===========================================================================
function SetReligionOpen()
  isReligionOpen = true;
  OnOpen();
end

-- ===========================================================================
function SetGovernmentOpen()
  isGovernmentOpen = true;
  OnOpen();
end

-- ===========================================================================
function SetCivicsTreeClosed()
  isCivicsTreeOpen = false;
  OnClose();
end

-- ===========================================================================
function SetTechTreeClosed()
  isTechTreeOpen = false;
  OnClose();
end

-- ===========================================================================
function SetGreatPeopleClosed()
  isGreatPeopleOpen = false;
  OnClose();
end

-- ===========================================================================
function SetGreatWorksClosed()
  isGreatWorksOpen = false;
  OnClose();
end

-- ===========================================================================
function SetReligionClosed()
  isReligionOpen = false;
  OnClose();
end

-- ===========================================================================
function SetGovernmentClosed()
  isGovernmentOpen = false;
  OnClose();
end

-- ===========================================================================
function BuildExtraEntries()
  -- Clear previous entries
  Controls.LaunchExtraStack:DestroyAllChildren();

  for key, entryInfo in pairs(m_LaunchbarExtras) do
    local tButtonEntry:table = {};

    -- Get Button Info
    local fCallback = function() entryInfo.Callback(); OnCloseExtras(); end;
    local sButtonText = Locale.Lookup(entryInfo.Text)
    ContextPtr:BuildInstanceForControl("LaunchExtraEntry", tButtonEntry, Controls.LaunchExtraStack);

    tButtonEntry.Button:SetText(sButtonText);
    tButtonEntry.Button:RegisterCallback(Mouse.eLClick, fCallback);

    if entryInfo.Tooltip ~= nil then
      local sTooltip = Locale.Lookup(entryInfo.Tooltip)
      tButtonEntry.Button:SetToolTipString(sTooltip);
    else
      tButtonEntry.Button:SetToolTipString("");
    end
  end

  -- Cleanup
  Controls.LaunchExtraStack:CalculateSize();
  Controls.LaunchExtraStack:ReprocessAnchoring();
  Controls.LaunchExtraWrapper:DoAutoSize();
  Controls.LaunchExtraWrapper:ReprocessAnchoring();
end

function OnCloseExtras()
  Controls.LaunchExtraControls:SetHide(true);
  Controls.LaunchExtraShow:SetCheck(false);
end

function OnToggleExtras()
  if Controls.LaunchExtraShow:IsChecked() then
    Controls.LaunchExtraControls:SetHide(true);

    Controls.LaunchExtraAlpha:SetToBeginning();
    Controls.LaunchExtraSlide:SetToBeginning();

    Controls.LaunchExtraAlpha:Play();
    Controls.LaunchExtraSlide:Play();

    Controls.LaunchExtraControls:SetHide(false);

    BuildExtraEntries();
  else
    OnCloseExtras()
  end
end

function OnAddExtraEntry(entryKey:string, entryInfo:table)
  -- Add info at key. Overwrite if they key already exists.
  m_LaunchbarExtras[entryKey] = entryInfo
end

-- ===========================================================================
function OnAddLaunchbarIcon(buttonInfo:table)
  local tButtonEntry:table = {};
  ContextPtr:BuildInstanceForControl("LaunchbarButtonInstance", tButtonEntry, Controls.ButtonStack);

  local textureOffsetX = buttonInfo.IconTexture.OffsetX;
  local textureOffsetY = buttonInfo.IconTexture.OffsetY;
  local textureSheet = buttonInfo.IconTexture.Sheet;

  -- Update Icon Info
  if (textureOffsetX ~= nil and textureOffsetY ~= nil and textureSheet ~= nil) then
    tButtonEntry.Image:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
  end
  if (buttonInfo.IconTexture.Color ~= nil) then
    tButtonEntry.Image:SetColor(buttonInfo.IconTexture.Color);
  end

  if (buttonInfo.Tooltip ~= nil) then
    tButtonEntry.Button:SetToolTipString(buttonInfo.Tooltip);
  end

  textureOffsetX = buttonInfo.BaseTexture.OffsetX;
  textureOffsetY = buttonInfo.BaseTexture.OffsetY;
  textureSheet = buttonInfo.BaseTexture.Sheet;

  local stateOffsetX = buttonInfo.BaseTexture.HoverOffsetX;
  local stateOffsetY = buttonInfo.BaseTexture.HoverOffsetY;

  if (textureOffsetX ~= nil and textureOffsetY ~= nil and textureSheet ~= nil) then
    tButtonEntry.Base:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
    if (buttonInfo.BaseTexture.Color ~= nil) then
      tButtonEntry.Base:SetColor(buttonInfo.BaseTexture.Color);
    end

    -- Setup behaviour on hover
    if (stateOffsetX ~= nil and stateOffsetY ~= nil) then
      local OnMouseOver = function()
        tButtonEntry.Base:SetTextureOffsetVal(stateOffsetX, stateOffsetY);
        UI.PlaySound("Main_Menu_Mouse_Over");
      end

      local OnMouseExit = function()
        tButtonEntry.Base:SetTextureOffsetVal(textureOffsetX, textureOffsetY);
      end

      tButtonEntry.Button:RegisterMouseEnterCallback( OnMouseOver );
      tButtonEntry.Button:RegisterMouseExitCallback( OnMouseExit );
    end
  end

  if (buttonInfo.Callback ~= nil) then
    tButtonEntry.Button:RegisterCallback( Mouse.eLClick, buttonInfo.Callback );
  end

  RefreshView();
end

-- ===========================================================================
--  Lua Event
--  Tutorial system is requesting any screen openned, to be closed.
-- ===========================================================================
function OnTutorialCloseAll()
  CloseAllPopups();
end

-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnInterfaceModeChanged(eOldMode:number, eNewMode:number)
  if eNewMode == InterfaceModeTypes.VIEW_MODAL_LENS then
    ContextPtr:SetHide(true);
  end
  if eNewMode == InterfaceModeTypes.CINEMATIC then
    CloseAllPopups();	--	TODO: Remove this and instead change Popup behavior via new parameter. (TTP 43933)
  end
  
  if eOldMode == InterfaceModeTypes.VIEW_MODAL_LENS then
    ContextPtr:SetHide(false);
  end
end


-- ===========================================================================
--  Refresh Data and View
-- ===========================================================================
function RealizeHookVisibility()
  m_isTechTreeAvailable = isDebug or HasCapability("CAPABILITY_TECH_TREE");
  Controls.ScienceButton:SetShow(m_isTechTreeAvailable);
  Controls.ScienceBolt:SetShow(m_isTechTreeAvailable);

  m_isCivicsTreeAvailable = isDebug or HasCapability("CAPABILITY_CIVICS_TREE");
  Controls.CultureButton:SetShow(m_isCivicsTreeAvailable);
  Controls.CultureBolt:SetShow(m_isCivicsTreeAvailable);

  m_isGreatPeopleAvailable = isDebug or (m_isGreatPeopleUnlocked and HasCapability("CAPABILITY_GREAT_PEOPLE_VIEW"));
  Controls.GreatPeopleButton:SetShow(m_isGreatPeopleAvailable);
  Controls.GreatPeopleBolt:SetShow(m_isGreatPeopleAvailable);

  m_isReligionAvailable = isDebug or (m_isReligionUnlocked and HasCapability("CAPABILITY_RELIGION_VIEW"));
  Controls.ReligionButton:SetShow(m_isReligionAvailable);
  Controls.ReligionBolt:SetShow(m_isReligionAvailable);

  m_isGreatWorksAvailable = isDebug or (m_isGreatWorksUnlocked and HasCapability("CAPABILITY_GREAT_WORKS_VIEW"));
  Controls.GreatWorksButton:SetShow(m_isGreatWorksAvailable);
  Controls.GreatWorksBolt:SetShow(m_isGreatWorksAvailable);

  m_isGovernmentAvailable = isDebug or (m_isGovernmentUnlocked and HasCapability("CAPABILITY_GOVERNMENTS_VIEW"));
  Controls.GovernmentButton:SetShow(m_isGovernmentAvailable);
  Controls.GovernmentBolt:SetShow(m_isGovernmentAvailable);

  RealizeBacking();
end

-- ===========================================================================
function OnFaithChanged()
  if (m_isReligionUnlocked) then
    return;
  end
  m_isReligionUnlocked = true;
  RealizeHookVisibility();
end

-- ===========================================================================
function RefreshReligion()
  local ePlayer:number = Game.GetLocalPlayer();
  if ePlayer == -1 then
    -- Likely auto playing.
    return;
  end
  if m_isReligionUnlocked then
    return;
  end
  local localPlayer   :table = Players[ePlayer];
  local playerReligion:table = localPlayer:GetReligion();

  local hasFaithYield			:boolean = playerReligion:GetFaithYield() > 0;
  local hasFaithBalance		:boolean = playerReligion:GetFaithBalance() > 0;
  if (hasFaithYield or hasFaithBalance) then
    m_isReligionUnlocked = true;
  end
  RealizeHookVisibility();
end

-- ===========================================================================
function OnGreatWorkCreated()
  if (m_isGreatWorksUnlocked) then
    return;
  end
  m_isGreatWorksUnlocked = true;
  RealizeHookVisibility();
end

-- ===========================================================================
function OnDiplomacyDealEnacted()
  if (not m_isGreatWorksUnlocked) then
    RefreshGreatWorks();
  end
end

-- ===========================================================================
--	Capturing a city can also net us pretty great works
function OnCityCaptured()
  if (not m_isGreatWorksUnlocked) then
    RefreshGreatWorks();
  end
end

-- ===========================================================================
function RefreshGreatWorks()
  local ePlayer:number = Game.GetLocalPlayer();
  if ePlayer == -1 then
    -- Likely auto playing.
    return;
  end
  if m_isGreatWorksUnlocked then
    return;
  end

  local localPlayer  :table = Players[ePlayer];  
  local pCities      :table = localPlayer:GetCities();
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

      if m_isGreatWorksUnlocked then
        break;
      end

    end
  end
  RealizeHookVisibility();
end

-- ===========================================================================
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

-- ===========================================================================
function ShowFreePolicyFlag( isFree:boolean )
  Controls.PoliciesAvailableIndicator:SetShow( isFree );
  Controls.PoliciesAvailableIndicator:SetToolTipString( isFree and Locale.Lookup("LOC_HUD_GOVT_FREE_CHANGES") or nil );
end

-- ===========================================================================
--	Game Event
-- ===========================================================================
function OnCivicCompleted(player:number, civic:number, isCanceled:boolean)
  local ePlayer:number = Game.GetLocalPlayer();
  if ePlayer == -1 then
    return;
  end
  if(not m_isGovernmentUnlocked) then
    local playerCulture:table = Players[ePlayer]:GetCulture();
    if (playerCulture:GetNumPoliciesUnlocked() > 0) then
      m_isGovernmentUnlocked = true;
    end
  end
  RealizeHookVisibility();
end

-- ===========================================================================
function RefreshGovernment()
  local playerID:number = Game.GetLocalPlayer();
  if playerID == -1 then return; end

  local kCulture:table = Players[playerID]:GetCulture();
  if ( kCulture:GetNumPoliciesUnlocked() <= 0 ) then
    Controls.GovernmentButton:SetToolTipString(Locale.Lookup("LOC_GOVERNMENT_DOESNT_UNLOCK"));
    Controls.GovernmentButton:GetTextControl():SetColor(UI.GetColorValueFromHexLiteral(0xFF666666));
  else
    m_isGovernmentUnlocked = true;
    Controls.GovernmentButton:SetHide(false);
    Controls.GovernmentBolt:SetHide(false);
    if ( kCulture:IsInAnarchy() ) then
      Controls.GovernmentButton:SetDisabled(true);
      local iAnarchyTurns = kCulture:GetAnarchyEndTurn() - Game.GetCurrentGameTurn();
      Controls.GovernmentButton.SetDisabled(true);
      Controls.GovernmentIcon:SetColorByName("Civ6Red");
      Controls.GovernmentButton:SetToolTipString("[COLOR_RED]".. Locale.Lookup("LOC_GOVERNMENT_ANARCHY_TURNS", iAnarchyTurns) .. "[ENDCOLOR]");
      ShowFreePolicyFlag(false);
    else
      Controls.GovernmentButton:SetDisabled(false);
      Controls.GovernmentIcon:SetColorByName("White");
      Controls.GovernmentButton:SetToolTipString(Locale.Lookup("LOC_GOVERNMENT_MANAGE_GOVERNMENT_AND_POLICIES"));
      ShowFreePolicyFlag(kCulture:GetCostToUnlockPolicies() == 0 and kCulture:PolicyChangeMade() == false);
    end
  end
  RealizeHookVisibility();
end

-- ===========================================================================
--	Update the background and size of the launchbar itself.
-- ===========================================================================
function RealizeBacking()
  -- The Launch Bar width should accomodate how many hooks are currently in the stack.
  Controls.ButtonStack:CalculateSize();
  Controls.LaunchBacking:SetSizeX(Controls.ButtonStack:GetSizeX()+116);
  Controls.LaunchBackingTile:SetSizeX(Controls.ButtonStack:GetSizeX()-20);
  Controls.LaunchBarDropShadow:SetSizeX(Controls.ButtonStack:GetSizeX());

  -- When we change size of the LaunchBar, we send this LuaEvent to the Diplomacy Ribbon, so that it can change scroll width to accommodate it
  LuaEvents.LaunchBar_Resize(Controls.ButtonStack:GetSizeX());
end

-- ===========================================================================
function UpdateTechMeter( localPlayer:table )
  if ( localPlayer ~= nil and Controls.ScienceHookWithMeter:IsVisible() ) then
    local playerTechs:table    = localPlayer:GetTechs();
    local currentTechID:number = playerTechs:GetResearchingTech();
    if(currentTechID >= 0) then
      local progress:number = playerTechs:GetResearchProgress(currentTechID);
      local cost:number = playerTechs:GetResearchCost(currentTechID);

      Controls.ScienceMeter:SetPercent(progress/cost);
    else
      Controls.ScienceMeter:SetPercent(0);
    end


    local techInfo:table = GameInfo.Technologies[currentTechID];
    if (techInfo ~= nil) then
      local textureString = "ICON_" .. techInfo.TechnologyType;
      local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(textureString,38);
      if textureSheet ~= nil then
        Controls.ResearchIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
      end
    end
  else
    Controls.ResearchIcon:SetTexture(0, 0, "LaunchBar_Hook_TechTree");
  end
end

-- ===========================================================================
function UpdateCivicMeter( localPlayer:table)
  if ( localPlayer ~= nil and Controls.CultureHookWithMeter:IsVisible() ) then
    local pPlayerCulture  :table	= localPlayer:GetCulture();
    local currentCivicID  :number = pPlayerCulture:GetProgressingCivic();

    if(currentCivicID >= 0) then
      local civicProgress :number = playerCivics:GetCulturalProgress(currentCivicID);
      local civicCost     :number = playerCivics:GetCultureCost(currentCivicID);

      Controls.CultureMeter:SetPercent(civicProgress/civicCost);
    else
      Controls.CultureMeter:SetPercent(0);
    end

    local CivicInfo:table = GameInfo.Civics[currentCivicID];
    if (CivicInfo ~= nil) then
      local civictextureString = "ICON_" .. CivicInfo.CivicType;
      local civictextureOffsetX, civictextureOffsetY, civictextureSheet = IconManager:FindIconAtlas(civictextureString,38);
      if civictextureSheet ~= nil then
        Controls.CultureIcon:SetTexture(civictextureOffsetX, civictextureOffsetY, civictextureSheet);
      end
    end
  else
    Controls.CultureIcon:SetTexture(0, 0, "LaunchBar_Hook_CivicsTree");
  end
end


-- ===========================================================================
--	Main Refresh
-- ===========================================================================
function RefreshView()
  local localPlayerID :number = Game.GetLocalPlayer();
  if localPlayerID  == -1 then
    return;
  end
  local localPlayer = Players[localPlayerID];
  if (localPlayer == nil) then
    return;
  end

  UpdateTechMeter(localPlayer);
  UpdateCivicMeter(localPlayer);

  RefreshGovernment();
  RefreshGreatWorks();
  RefreshGreatPeople();
  RefreshReligion();

  if BASE_RefreshView == nil then		-- No MODs, then wrap this up.
    RealizeBacking();
  end
end

-- ===========================================================================
--	EVENT
function OnLocalPlayerTurnBegin()
  RefreshView();
end

-- ===========================================================================
--	EVENT
function OnVisualStateRestored()
  RefreshView();
end

-- ===========================================================================
--	EVENT
function OnCivicChanged()
  RefreshView();
end

-- ===========================================================================
--	EVENT
function OnResearchChanged()
  RefreshView();
end

-- ===========================================================================
function OnOpen()
  m_numOpen = m_numOpen+1;
  local screenX, screenY:number = UIManager:GetScreenSizeVal();
  if screenY <= 850 then
    Controls.LaunchContainer:SetOffsetY(-35);
    Controls.ScienceHookWithMeter:SetOffsetY(-5);
    Controls.CultureHookWithMeter:SetOffsetY(-5);
  end
  LuaEvents.Launchbar_CloseChoosers();
end

-- ===========================================================================
function OnClose()
  m_numOpen = m_numOpen-1;
  if(m_numOpen < 0 )then
    m_numOpen = 0;
  end
  if m_numOpen == 0 then
    Controls.LaunchContainer:SetOffsetY(-5);
    -- Controls.ScienceHookWithMeter:SetOffsetY(25);
    -- Controls.CultureHookWithMeter:SetOffsetY(25);
  end
end

-- ===========================================================================
function OnToggleResearchPanel(hideResearch)
  Controls.ScienceHookWithMeter:SetHide(not hideResearch);
  UpdateTechMeter(Players[Game.GetLocalPlayer()]);
end

-- ===========================================================================
function OnToggleCivicPanel(hideResearch)
  Controls.CultureHookWithMeter:SetHide(not hideResearch);
  UpdateCivicMeter(Players[Game.GetLocalPlayer()]);
end

-- ===========================================================================
-- Reset the hooks when the player changes for hotseat.
function OnLocalPlayerChanged()
  m_isGreatPeopleUnlocked = false;
  m_isGreatWorksUnlocked = false;
  m_isReligionUnlocked = false;
  m_isGovernmentUnlocked = false;
  RefreshGovernment();
  RefreshGreatPeople();
  RefreshGreatWorks();
  RefreshReligion();
end

-- ===========================================================================
--  Input Hotkey Event (Extended in XP1 to hook extra panels)
-- ===========================================================================
function OnInputActionTriggered( actionId )
  if ( m_isTechTreeAvailable ) then
    if ( actionId == Input.GetActionId("ToggleTechTree") ) then
      OnOpenResearch();
    end
  end

  if ( m_isCivicsTreeAvailable ) then
    if ( actionId == Input.GetActionId("ToggleCivicsTree") ) then
      OnOpenCulture();
    end
  end

  if ( m_isGovernmentAvailable ) then
    if ( actionId == Input.GetActionId("ToggleGovernment") ) then
      OnOpenGovernment();
    end
  end

  if ( m_isReligionAvailable ) then
    if ( actionId == Input.GetActionId("ToggleReligion") ) then
      OnOpenReligion();
    end
  end

  if ( m_isGreatPeopleAvailable ) then
    if ( actionId == Input.GetActionId("ToggleGreatPeople") and UI.QueryGlobalParameterInt("DISABLE_GREAT_PEOPLE_HOTKEY") ~= 1 ) then
      OnOpenGreatPeople();
    end
  end

  if ( m_isGreatWorksAvailable ) then
    if ( actionId == Input.GetActionId("ToggleGreatWorks") and UI.QueryGlobalParameterInt("DISABLE_GREAT_WORKS_HOTKEY") ~= 1 ) then
      OnOpenGreatWorks();
    end
  end
end

-- ===========================================================================
function PlayMouseoverSound()
  UI.PlaySound("Main_Menu_Mouse_Over");
end

-- ===========================================================================
function LateInitialize()
  RefreshView();
end

-- ===========================================================================
--	Called after all contexts (this and replacement contexts) are loaded.
-- ===========================================================================
function OnInit(isReload:boolean)
  LateInitialize();
end

-- ===========================================================================
function Initialize()

  ContextPtr:SetInitHandler( OnInit );

  Controls.CultureButton:RegisterCallback(Mouse.eLClick, OnOpenCulture);
  Controls.CultureButton:RegisterCallback( Mouse.eMouseEnter, PlayMouseoverSound);
  Controls.GovernmentButton:RegisterCallback( Mouse.eLClick, OnOpenGovernment );
  Controls.GovernmentButton:RegisterCallback( Mouse.eMouseEnter, PlayMouseoverSound);
  Controls.GreatPeopleButton:RegisterCallback( Mouse.eLClick, OnOpenGreatPeople );
  Controls.GreatPeopleButton:RegisterCallback( Mouse.eMouseEnter, PlayMouseoverSound);
  Controls.GreatWorksButton:RegisterCallback( Mouse.eLClick, OnOpenGreatWorks );
  Controls.GreatWorksButton:RegisterCallback( Mouse.eMouseEnter, PlayMouseoverSound);
  Controls.ReligionButton:RegisterCallback( Mouse.eLClick, OnOpenReligion );
  Controls.ReligionButton:RegisterCallback( Mouse.eMouseEnter, PlayMouseoverSound);
  Controls.ScienceButton:RegisterCallback(Mouse.eLClick, OnOpenResearch);
  Controls.ScienceButton:RegisterCallback( Mouse.eMouseEnter, PlayMouseoverSound);

  -- CQUI --
  Controls.LaunchExtraShow:RegisterCallback( Mouse.eLClick, OnToggleExtras );

  -- Modular Screens
  LuaEvents.LaunchBar_AddExtra.Add( OnAddExtraEntry );
  LuaEvents.LaunchBar_AddIcon.Add( OnAddLaunchbarIcon );
  -- CQUI --

  Events.LocalPlayerTurnBegin.Add( OnLocalPlayerTurnBegin );
  Events.VisualStateRestored.Add( OnVisualStateRestored );
  Events.CivicCompleted.Add( OnCivicCompleted );        -- To capture when we complete Code of Laws
  Events.CivicChanged.Add( OnCivicChanged );
  Events.ResearchChanged.Add(OnResearchChanged);
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
  Events.CityOccupationChanged.Add( OnCityCaptured ); -- kinda bootleg, but effective

  -- Wrapped in an anonymous function, because OnInputActionTriggered may be overriden elsewhere (like XP1)
  Events.InputActionTriggered.Add( function(actionId) OnInputActionTriggered(actionId) end );

  LuaEvents.CivicsTree_CloseCivicsTree.Add( SetCivicsTreeClosed );
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

  -- TESTS
  --------------------------------
  --[[
  LuaEvents.LaunchBar_AddExtra("Test1", {Text="Test1", Callback=function() print("Test1") end, Tooltip="Test1"})
  LuaEvents.LaunchBar_AddExtra("Test2", {Text="Test2", Callback=function() print("Test2") end})

  local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas("ICON_BUILDING_AGORA", 38);
  local buttonInfo = {
    -- ICON TEXTURE
    IconTexture = {
      OffsetX = textureOffsetX;
      OffsetY = textureOffsetY+3;
      Sheet = textureSheet;
    };

    -- BUTTON TEXTURE
    BaseTexture = {
      OffsetX = 0;
      OffsetY = 0;
      Sheet = "LaunchBar_Hook_ReligionButton";

      -- Offset to have when hovering
      HoverOffsetX = 0;
      HoverOffsetY = 49;
    };

    -- BUTTON INFO
    Callback = function() print("Agora!") end;
    Tooltip = "Agora";
  }

  LuaEvents.LaunchBar_AddIcon(buttonInfo);

  textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas("ICON_UNIT_JAPANESE_SAMURAI", 38);
  local button2Info = {
    -- ICON TEXTURE
    IconTexture = {
      OffsetX = textureOffsetX;
      OffsetY = textureOffsetY+3;
      Sheet = textureSheet;
      Color = UI.GetColorValue("COLOR_PLAYER_BARBARIAN_PRIMARY");
    };

    -- BASE TEXTURE (Treat it as Button Texture)
    BaseTexture = {
      OffsetX = 0;
      OffsetY = 147;
      Sheet = "LaunchBar_Hook_GreatPeopleButton";
      -- Color = UI.GetColorValue("COLOR_BLUE");
      HoverOffsetX = 0;
      HoverOffsetY = 0;
    };

    -- BUTTON INFO
    Callback = function() print("ATTACK!") end;
    -- Tooltip = "barbs...";
  }

  LuaEvents.LaunchBar_AddIcon(button2Info);
  ]]
end
Initialize();
