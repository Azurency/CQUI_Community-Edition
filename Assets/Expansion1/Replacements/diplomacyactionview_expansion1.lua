--[[
-- Created by Sam Batista on Aug 02 2017
-- Copyright (c) Firaxis Games
--]]
-- ===========================================================================
-- INCLUDE BASE FILE
-- ===========================================================================
include("DiplomacyActionView");

-- ===========================================================================
--	CONTEXTS
-- ===========================================================================
local m_AllianceRowContext = nil;
local m_EmergencyRowContext = nil;

local m_AllianceTabContext = nil;
local m_EmergencyTabContext = nil;


-- ===========================================================================
--	CACHE BASE FUNCTIONS
-- ===========================================================================
BASE_GetWarType = GetWarType;
BASE_IsWarChoice = IsWarChoice;
BASE_GetStatementButtonTooltip = GetStatementButtonTooltip;
BASE_GetInitialStatementOptions = GetInitialStatementOptions;
BASE_ShouldAddTopLevelStatementOption = ShouldAddTopLevelStatementOption;
BASE_OnSelectInitialDiplomacyStatement = OnSelectInitialDiplomacyStatement;
BASE_OnSelectConversationDiplomacyStatement = OnSelectConversationDiplomacyStatement;
BASE_PopulateLeader = PopulateLeader;

-- ===========================================================================
--	OVERRIDE BASE FUNCTIONS
-- ===========================================================================
function GetWarType(key)
  if key == "CHOICE_DECLARE_GOLDEN_AGE_WAR" then
    return WarTypes.GOLDEN_AGE_WAR;
  elseif key == "CHOICE_DECLARE_WAR_OF_RETRIBUTION" then
    return WarTypes.WAR_OF_RETRIBUTION;
  elseif key == "CHOICE_DECLARE_IDEOLOGICAL_WAR" then
    return WarTypes.IDEOLOGICAL_WAR;
  end
  return BASE_GetWarType(key);
end

-- ===========================================================================
function PopulateLeader(leaderIcon : table, player : table, isUniqueLeader : boolean)
  BASE_PopulateLeader(leaderIcon, player, isUniqueLeader);

  -- Update relationship pip tool with details about our alliance if we're in one
  local localPlayerDiplomacy:table = Players[Game.GetLocalPlayer()]:GetDiplomacy();
  if localPlayerDiplomacy then
    local allianceType = localPlayerDiplomacy:GetAllianceType(player:GetID());
    if allianceType ~= -1 then
      local allianceName = Locale.Lookup(GameInfo.Alliances[allianceType].Name);
      local allianceLevel = localPlayerDiplomacy:GetAllianceLevel(player:GetID());
      leaderIcon.Controls.Relationship:SetToolTipString(Locale.Lookup("LOC_DIPLOMACY_ALLIANCE_FLAG_TT", allianceName, allianceLevel));
    end
  end
end

-- ===========================================================================
function IsWarChoice(key)
  if key == "CHOICE_DECLARE_GOLDEN_AGE_WAR" then
    return true;
  elseif key == "CHOICE_DECLARE_WAR_OF_RETRIBUTION" then
    return true;
  elseif key == "CHOICE_DECLARE_IDEOLOGICAL_WAR" then
    return true;
  end
  return BASE_IsWarChoice(key);
end

-- ===========================================================================
function GetStatementButtonTooltip(pActionDef)
  local tooltip = BASE_GetStatementButtonTooltip(pActionDef);

  if pActionDef and pActionDef.UIGroup == "ALLIANCES" then
    local pActionXPDef:table = GameInfo.DiplomaticActions_XP1[pActionDef.DiplomaticActionType];
    if pActionXPDef then
      tooltip = tooltip .. "[NEWLINE]";
      local allianceLevel:number = ms_LocalPlayer:GetDiplomacy():GetAllianceLevel(ms_SelectedPlayerID);
      local allianceData:table = GameInfo.Alliances[pActionXPDef.AllianceType];
      tooltip = tooltip .. Game.GetGameDiplomacy():GetAllianceBenefitsString(allianceData.Index, allianceLevel, true);
    end
  end
  return tooltip;
end

-- ===========================================================================
function GetInitialStatementOptions(parsedStatements, rootControl)

  local allianceOptions:table = {};
  local topOptions:table = BASE_GetInitialStatementOptions(parsedStatements, rootControl);

  for _, selection in ipairs(parsedStatements) do
    local pActionDef = GameInfo.DiplomaticActions[selection.DiplomaticActionType];
    if pActionDef and pActionDef.UIGroup == "ALLIANCES" then
      table.insert(allianceOptions, selection);
    end
  end
  if table.count(allianceOptions) > 0 then
    table.insert(topOptions, {
      Text = Locale.Lookup("LOC_DIPLOMACY_ALLIANCES").. " [ICON_List]",
      Callback =
        function()
          ShowOptionStack(true);
          PopulateStatementList( allianceOptions, rootControl, true );
        end,
      ToolTip= "LOC_DIPLOMACY_ALLIANCES_TT"
    });
  end
  
  return topOptions;
end

-- ===========================================================================
function ShouldAddTopLevelStatementOption(pActionDef)
  return pActionDef.UIGroup ~= "ALLIANCES";
end

-- ===========================================================================
function OnSelectInitialDiplomacyStatement(key)
  local handled:boolean = false;
  if CanInitiateDiplomacyStatement() then
    handled = true; -- Assume we handle it, unless we reach else statement

    if key == "CHOICE_DECLARE_GOLDEN_AGE_WAR" then
      DiplomacyManager.RequestSession(ms_LocalPlayerID, ms_SelectedPlayerID, "DECLARE_GOLDEN_WAR");

    elseif key == "CHOICE_DECLARE_WAR_OF_RETRIBUTION" then
      DiplomacyManager.RequestSession(ms_LocalPlayerID, ms_SelectedPlayerID, "DECLARE_WAR_OF_RETRIBUTION");

    elseif key == "CHOICE_DECLARE_IDEOLOGICAL_WAR" then
      DiplomacyManager.RequestSession(ms_LocalPlayerID, ms_SelectedPlayerID, "DECLARE_IDEOLOGICAL_WAR");

    elseif key == "CHOICE_ALLIANCE_RELIGIOUS" then
        -- Clear the outgoing deal, if we have nothing pending, so the user starts out with an empty deal.
        if (not DealManager.HasPendingDeal(ms_LocalPlayerID, ms_SelectedPlayerID)) then
          DealManager.ClearWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayerID, ms_SelectedPlayerID);
          local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayerID, ms_SelectedPlayerID);
          if pDeal then
            pDealItem = pDeal:AddItemOfType(DealItemTypes.AGREEMENTS, ms_LocalPlayerID);
            if pDealItem then
              pDealItem:SetSubType(DealAgreementTypes.ALLIANCE);
              pDealItem:SetValueType(DB.MakeHash("ALLIANCE_RELIGIOUS"));
              pDealItem:SetLocked(true);
            end
            pDeal:Validate();
          end
        end
        DiplomacyManager.RequestSession(ms_LocalPlayerID, ms_SelectedPlayerID, "MAKE_DEAL");

    elseif key == "CHOICE_ALLIANCE_RESEARCH" then
        -- Clear the outgoing deal, if we have nothing pending, so the user starts out with an empty deal.
        if (not DealManager.HasPendingDeal(ms_LocalPlayerID, ms_SelectedPlayerID)) then
          DealManager.ClearWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayerID, ms_SelectedPlayerID);
          local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayerID, ms_SelectedPlayerID);
          if pDeal then
            pDealItem = pDeal:AddItemOfType(DealItemTypes.AGREEMENTS, ms_LocalPlayerID);
            if pDealItem then
              pDealItem:SetSubType(DealAgreementTypes.ALLIANCE);
              pDealItem:SetValueType(DB.MakeHash("ALLIANCE_RESEARCH"));
              pDealItem:SetLocked(true);
            end
            pDeal:Validate();
          end
        end
        DiplomacyManager.RequestSession(ms_LocalPlayerID, ms_SelectedPlayerID, "MAKE_DEAL");

    elseif key == "CHOICE_ALLIANCE_CULTURAL" then
        -- Clear the outgoing deal, if we have nothing pending, so the user starts out with an empty deal.
        if (not DealManager.HasPendingDeal(ms_LocalPlayerID, ms_SelectedPlayerID)) then
          DealManager.ClearWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayerID, ms_SelectedPlayerID);
          local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayerID, ms_SelectedPlayerID);
          if pDeal then
            pDealItem = pDeal:AddItemOfType(DealItemTypes.AGREEMENTS, ms_LocalPlayerID);
            if pDealItem then
              pDealItem:SetSubType(DealAgreementTypes.ALLIANCE);
              pDealItem:SetValueType(DB.MakeHash("ALLIANCE_CULTURAL"));
              pDealItem:SetLocked(true);
            end
            pDeal:Validate();
          end
        end
        DiplomacyManager.RequestSession(ms_LocalPlayerID, ms_SelectedPlayerID, "MAKE_DEAL");

    elseif key == "CHOICE_ALLIANCE_ECONOMIC" then
        -- Clear the outgoing deal, if we have nothing pending, so the user starts out with an empty deal.
        if (not DealManager.HasPendingDeal(ms_LocalPlayerID, ms_SelectedPlayerID)) then
          DealManager.ClearWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayerID, ms_SelectedPlayerID);
          local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayerID, ms_SelectedPlayerID);
          if pDeal then
            pDealItem = pDeal:AddItemOfType(DealItemTypes.AGREEMENTS, ms_LocalPlayerID);
            if pDealItem then
              pDealItem:SetSubType(DealAgreementTypes.ALLIANCE);
              pDealItem:SetValueType(DB.MakeHash("ALLIANCE_ECONOMIC"));
              pDealItem:SetLocked(true);
            end
            pDeal:Validate();
          end
        end
        DiplomacyManager.RequestSession(ms_LocalPlayerID, ms_SelectedPlayerID, "MAKE_DEAL");

    elseif key == "CHOICE_ALLIANCE_MILITARY" then
      -- Clear the outgoing deal, if we have nothing pending, so the user starts out with an empty deal.
      if (not DealManager.HasPendingDeal(ms_LocalPlayerID, ms_SelectedPlayerID)) then
        DealManager.ClearWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayerID, ms_SelectedPlayerID);
        local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayerID, ms_SelectedPlayerID);
        if pDeal then
          pDealItem = pDeal:AddItemOfType(DealItemTypes.AGREEMENTS, ms_LocalPlayerID);
          if pDealItem then
            pDealItem:SetSubType(DealAgreementTypes.ALLIANCE);
            pDealItem:SetValueType(DB.MakeHash("ALLIANCE_MILITARY"));
            pDealItem:SetLocked(true);
          end
          pDeal:Validate();
        end
      end
      DiplomacyManager.RequestSession(ms_LocalPlayerID, ms_SelectedPlayerID, "MAKE_DEAL");

    elseif key == "CHOICE_RENEW_ALLIANCE" then
      DiplomacyManager.RequestSession(ms_LocalPlayerID, ms_SelectedPlayerID, "RENEW_ALLIANCE");

    else
      handled = false;
    end

  end
  if not handled then
    BASE_OnSelectInitialDiplomacyStatement(key);
  end
end

-- ===========================================================================
function OnSelectConversationDiplomacyStatement(key)
  if key == "CHOICE_DECLARE_GOLDEN_AGE_WAR" then
    DiplomacyManager.AddStatement(ms_ActiveSessionID, Game.GetLocalPlayer(), "DECLARE_GOLDEN_WAR");
    return;
  elseif key == "CHOICE_DECLARE_WAR_OF_RETRIBUTION" then
    DiplomacyManager.AddStatement(ms_ActiveSessionID, Game.GetLocalPlayer(), "DECLARE_WAR_OF_RETRIBUTION");
    return;
  elseif key == "CHOICE_DECLARE_IDEOLOGICAL_WAR" then
    DiplomacyManager.AddStatement(ms_ActiveSessionID, Game.GetLocalPlayer(), "DECLARE_IDEOLOGICAL_WAR");
    return;
  end
  BASE_OnSelectConversationDiplomacyStatement(key);
end

-- ===========================================================================
function AddOverviewRow(contextReference:table, contextName:string, parentControl:table)
  -- Use blank anchor instance as a parent for the new context
  local anchorInst:table = GetOverviewAnchor(parentControl);
  if contextReference == nil then
    -- Load the new context and set the reference
    contextReference = ContextPtr:LoadNewContext(contextName, anchorInst.Anchor);
  else
    -- If the context was already created reparent it to ensure it maintains it's correct sort order
    contextReference:ChangeParent(anchorInst.Anchor);
  end

  return contextReference;
end

-- ===========================================================================
function PopulateIntelOverview(overviewInstance:table)
  -- Add overview rows in the order you want them displayed
  AddOverviewGossip(overviewInstance);
  AddIntelOverviewDivider(overviewInstance);
  AddOverviewAccessLevel(overviewInstance);
  AddIntelOverviewDivider(overviewInstance);
  AddOverviewGovernment(overviewInstance);
  AddIntelOverviewDivider(overviewInstance);
  m_AllianceRowContext = AddOverviewRow(m_AllianceRowContext, "DiplomacyActionView_AllianceRow", overviewInstance.IntelOverviewStack);
  AddIntelOverviewDivider(overviewInstance);

  -- Only show the emergency tab is the local player is the target or a member of any emergencies
  if AreThereEmergenciesForPlayer(GetSelectedPlayerID()) then
    m_EmergencyRowContext = AddOverviewRow(m_EmergencyRowContext, "DiplomacyActionView_EmergencyRow", overviewInstance.IntelOverviewStack);
    AddIntelOverviewDivider(overviewInstance);
  end

  if (AddOverviewAgendas(overviewInstance)) then
    -- Only add divider if we're visible
    AddIntelOverviewDivider(overviewInstance);
  end
  if (AddOverviewAgreements(overviewInstance)) then
    -- Only add divider if we're visible
    AddIntelOverviewDivider(overviewInstance);
  end
  if (AddOverviewOurRelationship(overviewInstance)) then
    -- Only add divider if we're visible
    AddIntelOverviewDivider(overviewInstance);
  end
  AddOverviewOtherRelationships(overviewInstance);

  -- Refresh contexts
  LuaEvents.DiploScene_RefreshOverviewRows(GetSelectedPlayerID());

  overviewInstance.IntelOverviewStack:CalculateSize();
  overviewInstance.IntelOverviewStack:ReprocessAnchoring();
end

-- ===========================================================================
local m_fnBasePopulateIntelPanels = PopulateIntelPanels;
function PopulateIntelPanels(tabContainer:table)
  m_fnBasePopulateIntelPanels( tabContainer );
  AddIntelAlliance(tabContainer);
  AddIntelEmergency(tabContainer);

  -- Refresh contexts
  LuaEvents.DiploScene_RefreshTabs(GetSelectedPlayerID());
end

-- ===========================================================================
function AddIntelAlliance(tabContainer:table)
  -- Don't show the alliance tab if we're in a team with the selected player
  if ms_SelectedPlayer:GetTeam() == ms_LocalPlayer:GetTeam() then
    return;
  end

  -- Create tab
  local tabAnchor = GetTabAnchor(tabContainer);
  if m_AllianceTabContext == nil then
    m_AllianceTabContext = ContextPtr:LoadNewContext("DiplomacyActionView_AllianceTab", tabAnchor.Anchor);
  else
    m_AllianceTabContext:ChangeParent(tabAnchor.Anchor);
  end

  -- Create tab button
  local tabButtonInstance:table = CreateTabButton();
  tabButtonInstance.Button:RegisterCallback( Mouse.eLClick, function() ShowPanel(tabAnchor.Anchor); end );
  tabButtonInstance.Button:SetToolTipString(Locale.Lookup("LOC_DIPLOACTION_ALLIANCE_TAB_TOOLTIP"));
  tabButtonInstance.ButtonIcon:SetIcon("ICON_STAT_ALLIANCES");

  -- Cacahe references to the button instance and header text on the panel instance
  tabAnchor.Anchor.m_ButtonInstance = tabButtonInstance;
  tabAnchor.Anchor.m_HeaderText = Locale.ToUpper("LOC_DIPLOACTION_INTEL_REPORT_ALLIANCE");
end

-- ===========================================================================
function AreThereEmergenciesForPlayer( playerID:number )
  local crisisData = Game.GetEmergencyManager():GetEmergencyInfoTable(playerID);
  for _, crisis in ipairs(crisisData) do
    if crisis.HasBegun then
      -- Are we the target?
      if crisis.TargetID == playerID then
        return true;
      end

      -- Are we a member?
      for i, memberID in ipairs(crisis.MemberIDs) do
        if memberID == playerID then
          return true;
        end
      end
    end
  end

  return false;
end

-- ===========================================================================
function AddIntelEmergency(tabContainer:table)
  -- Only show the emergency tab is the local player is the target or a member of any emergencies
  if not AreThereEmergenciesForPlayer(GetSelectedPlayerID()) then
    return;
  end

  -- Create tab
  local tabAnchor = GetTabAnchor(tabContainer);
  if m_EmergencyTabContext == nil then
    m_EmergencyTabContext = ContextPtr:LoadNewContext("DiplomacyActionView_EmergencyTab", tabAnchor.Anchor);
  else
    m_EmergencyTabContext:ChangeParent(tabAnchor.Anchor);
  end

  -- Create tab button
  local tabButtonInstance:table = CreateTabButton();
  tabButtonInstance.Button:RegisterCallback( Mouse.eLClick, function() ShowPanel(tabAnchor.Anchor); end );
  tabButtonInstance.Button:SetToolTipString(Locale.Lookup("LOC_DIPLOMACY_OVERVIEW_EMERGENCIES"));
  tabButtonInstance.ButtonIcon:SetIcon("ICON_EMERGENCY");

  -- Cacahe references to the button instance and header text on the panel instance
  tabAnchor.Anchor.m_ButtonInstance = tabButtonInstance;
  tabAnchor.Anchor.m_HeaderText = Locale.ToUpper("LOC_DIPLOACTION_INTEL_REPORT_EMERGENCY");
end