-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_CQUI_AddLeader = AddLeader;

-- ===========================================================================
--	CQUI Members
-- ===========================================================================
-- ARISTOS: Mouse over leader icon to show relations
local m_isCTRLDown       :boolean= false;
local CQUI_hoveringOverPortrait :boolean = false;

-- ===========================================================================
-- ARISTOS: To display key information in leader tooltip inside Diplo Ribbon
function GetExtendedTooltip(playerID:number)
  local govType:string = "";
  local eSelectePlayerGovernment :number = Players[playerID]:GetCulture():GetCurrentGovernment();
  if eSelectePlayerGovernment ~= -1 then
    govType = Locale.Lookup(GameInfo.Governments[eSelectePlayerGovernment].Name);
  else
    govType = Locale.Lookup("LOC_GOVERNMENT_ANARCHY_NAME" );
  end
  local cities = Players[playerID]:GetCities();
  local numCities = 0;
  for i,city in cities:Members() do
    numCities = numCities + 1;
  end
  local playerTreasury:table = Players[playerID]:GetTreasury();
  local goldBalance	:number = math.floor(playerTreasury:GetGoldBalance());
  local goldYield	:number = math.floor((playerTreasury:GetGoldYield() - playerTreasury:GetTotalMaintenance()));

  local civData:string = "[NEWLINE]"..Locale.Lookup("LOC_DIPLOMACY_INTEL_GOVERNMENT").." "..govType
    .."[NEWLINE]"..Locale.Lookup("LOC_PEDIA_CONCEPTS_PAGEGROUP_CITIES_NAME").. ": "..numCities
    .."[NEWLINE][ICON_Capital] "..Locale.Lookup("LOC_WORLD_RANKINGS_OVERVIEW_DOMINATION_SCORE", Players[playerID]:GetScore())
    .."[NEWLINE][ICON_Gold] "..goldBalance.." / " .. (goldYield>0 and "+" or "") .. (goldYield>0 and goldYield or "?")
    .."[NEWLINE]"..Locale.Lookup("LOC_WORLD_RANKINGS_OVERVIEW_SCIENCE_SCIENCE_RATE", Round(Players[playerID]:GetTechs():GetScienceYield(),1))
    .."[NEWLINE][ICON_Science] "..Locale.Lookup("LOC_WORLD_RANKINGS_OVERVIEW_SCIENCE_NUM_TECHS", Players[playerID]:GetStats():GetNumTechsResearched())
    .."[NEWLINE]"..Locale.Lookup("LOC_WORLD_RANKINGS_OVERVIEW_CULTURE_CULTURE_RATE", Round(Players[playerID]:GetCulture():GetCultureYield(),1))
    .."[NEWLINE]"..Locale.Lookup("LOC_WORLD_RANKINGS_OVERVIEW_CULTURE_TOURISM_RATE", Round(Players[playerID]:GetStats():GetTourism(),1))
    .."[NEWLINE]"..Locale.Lookup("LOC_WORLD_RANKINGS_OVERVIEW_RELIGION_FAITH_RATE", Round(Players[playerID]:GetReligion():GetFaithYield(),1))
    .."[NEWLINE][ICON_Strength] "..Locale.Lookup("LOC_WORLD_RANKINGS_OVERVIEW_DOMINATION_MILITARY_STRENGTH", Players[playerID]:GetStats():GetMilitaryStrength())
    ;

  return civData;
end

-- ===========================================================================
function OnLeaderRightClicked(ms_SelectedPlayerID : number )
  local ms_LocalPlayerID:number = Game.GetLocalPlayer();
  if ms_SelectedPlayerID == ms_LocalPlayerID then
    UpdateLeaders();
  end
  local pPlayer = Players[ms_LocalPlayerID];
  local iPlayerDiploState = pPlayer:GetDiplomaticAI():GetDiplomaticStateIndex(ms_SelectedPlayerID);
  local relationshipHash = GameInfo.DiplomaticStates[iPlayerDiploState].Hash;
  --ARISTOS: to check if Peace Deal is valid
  local bValidAction, tResults = pPlayer:GetDiplomacy():IsDiplomaticActionValid("DIPLOACTION_PROPOSE_PEACE_DEAL", ms_SelectedPlayerID, true); --ARISTOS
  if (not (relationshipHash == DiplomaticStates.WAR)) then
    if (not DealManager.HasPendingDeal(ms_LocalPlayerID, ms_SelectedPlayerID)) then
      DealManager.ClearWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayerID, ms_SelectedPlayerID);
    end
    DiplomacyManager.RequestSession(ms_LocalPlayerID, ms_SelectedPlayerID, "MAKE_DEAL");
  --ARISTOS: To make Right Click on leader go directly to peace deal if Peace Deal is valid
  elseif bValidAction then
    if (not DealManager.HasPendingDeal(ms_LocalPlayerID, ms_SelectedPlayerID)) then
      DealManager.ClearWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayerID, ms_SelectedPlayerID);
      local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayerID, ms_SelectedPlayerID);
      if (pDeal ~= nil) then
        pDealItem = pDeal:AddItemOfType(DealItemTypes.AGREEMENTS, ms_LocalPlayerID);
        if (pDealItem ~= nil) then
          pDealItem:SetSubType(DealAgreementTypes.MAKE_PEACE);
          pDealItem:SetLocked(true);
        end
        -- Validate the deal, this will make sure peace is on both sides of the deal.
        pDeal:Validate();
      end
    end
    DiplomacyManager.RequestSession(ms_LocalPlayerID, ms_SelectedPlayerID, "MAKE_DEAL");
  end
  LuaEvents.QuickDealModeActivate();
end

-- ===========================================================================
-- ARISTOS: To show relationship icon of other civs on hovering mouse over a given leader
function OnLeaderMouseOver(playerID : number )
  CQUI_hoveringOverPortrait = true;
  local localPlayerID:number = Game.GetLocalPlayer();
  local playerDiplomacy = Players[playerID]:GetDiplomacy();
  if m_isCTRLDown then
    UI.PlaySound("Main_Menu_Mouse_Over");
    for otherPlayerID, instance in pairs(m_uiLeadersByID) do
      local pPlayer:table = Players[otherPlayerID];
      local pPlayerConfig:table = PlayerConfigurations[otherPlayerID];
      local isHuman:boolean = pPlayerConfig:IsHuman();
      -- Set relationship status (for non-local players)
      local diplomaticAI:table = pPlayer:GetDiplomaticAI();
      local relationshipStateID:number = diplomaticAI:GetDiplomaticStateIndex(playerID);
      if relationshipStateID ~= -1 then
        local relationshipState:table = GameInfo.DiplomaticStates[relationshipStateID];
        -- Always show relationship icon for AIs, only show player triggered states for humans
        if not isHuman or Relationship.IsValidWithAI(relationshipState.StateType) then
          --!! ARISTOS: to extend relationship tooltip to include diplo modifiers!
          local relationshipTooltip:string = Locale.Lookup(relationshipState.Name)
          --!! Extend it only of the selected player is the local player!
          .. (localPlayerID == playerID and ("[NEWLINE][NEWLINE]" .. RelationshipGet(otherPlayerID)) or "");
          -- KWG: This is bad, there is a piece of art that is tied to the order of a database entry.  Please fix!
          instance.Relationship:SetVisState(relationshipStateID);
          --ARISTOS: this shows a ? mark instead of leader portrait if player is unknown to the selected leader
          if (otherPlayerID == playerID or otherPlayerID == localPlayerID) then
            instance.Relationship:SetHide(true);
            instance.Portrait:SetIcon("ICON_"..PlayerConfigurations[otherPlayerID]:GetLeaderTypeName());
          elseif playerDiplomacy:HasMet(otherPlayerID) then
            instance.Relationship:SetToolTipString(relationshipTooltip);
            instance.Relationship:SetHide(false);
            instance.Portrait:SetIcon("ICON_"..PlayerConfigurations[otherPlayerID]:GetLeaderTypeName());
          else
            instance.Portrait:SetIcon("ICON_LEADER_DEFAULT");
            instance.Relationship:LocalizeAndSetToolTip("LOC_DIPLOPANEL_UNMET_PLAYER");
            instance.Relationship:SetHide(false);
          end
        end
      end
      if(playerID == otherPlayerID) then
        instance.YouIndicator:SetHide(false);
      else
        instance.YouIndicator:SetHide(true);
      end
    end
  end
end

-- ===========================================================================
function OnLeaderMouseExit()
  CQUI_hoveringOverPortrait = false;
end

-- ===========================================================================
function AddLeader(iconName : string, playerID : number, kProps: table)
  local oLeaderIcon:object = BASE_CQUI_AddLeader(iconName, playerID, kProps);

  oLeaderIcon:RegisterCallback(Mouse.eRClick,     function() OnLeaderRightClicked(playerID); end);
  oLeaderIcon:RegisterCallback(Mouse.eMouseEnter, function() OnLeaderMouseOver(playerID); end);
  oLeaderIcon:RegisterCallback(Mouse.eMouseExit,  function() OnLeaderMouseExit(); end);
  oLeaderIcon:RegisterCallback(Mouse.eMClick,     function() OnLeaderMouseOver(playerID); end);

  -- Set the tooltip
  local pPlayerConfig:table = PlayerConfigurations[playerID];
  local isHuman:boolean = pPlayerConfig:IsHuman();

  if(pPlayerConfig ~= nil) then
    local leaderTypeName:string = pPlayerConfig:GetLeaderTypeName();
    if(leaderTypeName ~= nil) then
      -- Append GetExtendedTooltip string to the end of the tooltip created by LeaderIcon
      if (not GameConfiguration.IsAnyMultiplayer() or not isHuman) then
        local civData:string = GetExtendedTooltip(playerID);
        oLeaderIcon:AppendTooltip(civData);
      end
    end
  end

  return oLeaderIcon;
end