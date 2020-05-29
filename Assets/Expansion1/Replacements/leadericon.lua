-- Copyright 2017-2019, Firaxis Games
include("TeamSupport");
include("DiplomacyRibbonSupport");

-- ===========================================================================
--	Class Table
-- ===========================================================================
LeaderIcon = {
  playerID = -1,
  TEAM_RIBBON_PREFIX	= "ICON_TEAM_RIBBON_"
}


-- ===========================================================================
function LeaderIcon:GetInstance(instanceManager:table, uiNewParent:table)
  local instance:table = instanceManager:GetInstance(uiNewParent);
  return LeaderIcon:AttachInstance(instance);
end

-- ===========================================================================
--	Essentially the "new"
-- ===========================================================================
function LeaderIcon:AttachInstance( instance:table )
  if instance == nil then
    UI.DataError("NIL instance passed into LeaderIcon:AttachInstance.  Setting the value to the ContextPtr's 'Controls'.");
    instance = Controls;

  end
  setmetatable(instance, {__index = self });
  self.Controls = instance;
  self:Reset();
  return instance;
end


-- ===========================================================================
function LeaderIcon:UpdateIcon(iconName: string, playerID: number, isUniqueLeader: boolean, ttDetails: string)
  
  LeaderIcon.playerID = playerID;

  local pPlayer:table = Players[playerID];
  local pPlayerConfig:table = PlayerConfigurations[playerID];
  local localPlayerID:number = Game.GetLocalPlayer();

  -- Display the civ colors/icon for duplicate civs
  if isUniqueLeader == false and (playerID == localPlayerID or Players[localPlayerID]:GetDiplomacy():HasMet(playerID)) then
    local backColor, frontColor  = UI.GetPlayerColors( playerID );
    self.Controls.CivIndicator:SetHide(false);
    self.Controls.CivIndicator:SetColor(backColor);
    self.Controls.CivIcon:SetHide(false);
    self.Controls.CivIcon:SetColor(frontColor);
    self.Controls.CivIcon:SetIcon("ICON_"..pPlayerConfig:GetCivilizationTypeName());
  else
    self.Controls.CivIcon:SetHide(true);
    self.Controls.CivIndicator:SetHide(true);
  end
  
  -- Set leader portrait and hide overlay if not local player
  self.Controls.Portrait:SetIcon(iconName);
  self.Controls.YouIndicator:SetHide(playerID ~= localPlayerID);

  -- Set the tooltip
  local tooltip:string = self:GetToolTipString(playerID);
  if (ttDetails ~= nil and ttDetails ~= "") then
    tooltip = tooltip .. "[NEWLINE]" .. ttDetails;
  end
  self.Controls.Portrait:SetToolTipString(tooltip);

  self:UpdateTeamAndRelationship(playerID);
end

-- ===========================================================================
function LeaderIcon:UpdateIconSimple(iconName: string, playerID: number, isUniqueLeader: boolean, ttDetails: string)

  LeaderIcon.playerID = playerID;

  local localPlayerID:number = Game.GetLocalPlayer();

  self.Controls.Portrait:SetIcon(iconName);
  self.Controls.YouIndicator:SetHide(playerID ~= localPlayerID);

  -- Display the civ colors/icon for duplicate civs
  if isUniqueLeader == false and (playerID ~= -1 and Players[localPlayerID]:GetDiplomacy():HasMet(playerID)) then
    local backColor, frontColor = UI.GetPlayerColors( playerID );
    self.Controls.CivIndicator:SetHide(false);
    self.Controls.CivIndicator:SetColor(backColor);
    self.Controls.CivIcon:SetHide(false);
    self.Controls.CivIcon:SetColor(frontColor);
    self.Controls.CivIcon:SetIcon("ICON_"..PlayerConfigurations[playerID]:GetCivilizationTypeName());
  else
    self.Controls.CivIcon:SetHide(true);
    self.Controls.CivIndicator:SetHide(true);
  end

  if playerID < 0 then
    self.Controls.TeamRibbon:SetHide(true);
    self.Controls.Relationship:SetHide(true);
    self.Controls.Portrait:SetToolTipString("");
    return;
  end

  -- Set the tooltip
  local tooltip:string = self:GetToolTipString(playerID);
  if (ttDetails ~= nil and ttDetails ~= "") then
    tooltip = tooltip .. "[NEWLINE]" .. ttDetails;
  end
  self.Controls.Portrait:SetToolTipString(tooltip);

  self:UpdateTeamAndRelationship(playerID);
end

-- ===========================================================================
--	playerID, Index of the player to compare a relationship.  (May be self.)
-- ===========================================================================
function LeaderIcon:UpdateTeamAndRelationship( playerID: number)

  local localPlayerID	:number = Game.GetLocalPlayer();
  if localPlayerID == PlayerTypes.NONE or playerID == PlayerTypes.OBSERVER then return; end		--  Local player is auto-play.

  -- Don't even attempt it, just hide the icon if this game mode doesn't have the capabilitiy.
  if GameCapabilities.HasCapability("CAPABILITY_DISPLAY_HUD_RIBBON_RELATIONSHIPS") == false then
    self.Controls.Relationship:SetHide( true );
    return;
  end
  
  -- Nope, autoplay or observer
  if playerID < 0 then 
    UI.DataError("Invalid playerID="..tostring(playerID).." to check against for UpdateTeamAndRelationship().");
    return; 
  end	

  local pPlayer		:table = Players[playerID];
  local pPlayerConfig	:table = PlayerConfigurations[playerID];	
  local isHuman		:boolean = pPlayerConfig:IsHuman();
  local isSelf		:boolean = (playerID == localPlayerID);
  local isMet			:boolean = Players[localPlayerID]:GetDiplomacy():HasMet(playerID);

  -- Team Ribbon
  local isTeamRibbonHidden:boolean = true;
  if(isSelf or isMet) then
    -- Show team ribbon for ourselves and civs we've met
    local teamID:number = pPlayerConfig:GetTeam();
    if #Teams[teamID] > 1 then
      local teamRibbonName:string = self.TEAM_RIBBON_PREFIX .. tostring(teamID);
      self.Controls.TeamRibbon:SetIcon(teamRibbonName);
      self.Controls.TeamRibbon:SetColor(GetTeamColor(teamID));
      isTeamRibbonHidden = false;
    end
  end
  self.Controls.TeamRibbon:SetHide(isTeamRibbonHidden);

  -- Relationship status (Humans don't show anything, unless we are at war)
  local eRelationship :number = pPlayer:GetDiplomaticAI():GetDiplomaticStateIndex(localPlayerID);
  local relationType	:string = GameInfo.DiplomaticStates[eRelationship].StateType;
  local isValid		:boolean= (isHuman and Relationship.IsValidWithHuman( relationType )) or (not isHuman and Relationship.IsValidWithAI( relationType ));
  if isValid then		
    self.Controls.Relationship:SetVisState(eRelationship);
    if (GameInfo.DiplomaticStates[eRelationship].Hash ~= DiplomaticStates.NEUTRAL) then
      self.Controls.Relationship:SetToolTipString(Locale.Lookup(GameInfo.DiplomaticStates[eRelationship].Name));
    end
  end
  self.Controls.Relationship:SetHide( not isValid );

  -- CQUI Additions
  local gameEras:table = Game.GetEras();
  if gameEras:HasHeroicGoldenAge(playerID) then
    self.Controls.CQUI_Era:SetText("[ICON_GLORY_SUPER_GOLDEN_AGE]");
  elseif gameEras:HasGoldenAge(playerID) then
    self.Controls.CQUI_Era:SetText("[ICON_GLORY_GOLDEN_AGE]");
  elseif gameEras:HasDarkAge(playerID) then
    self.Controls.CQUI_Era:SetText("[ICON_GLORY_DARK_AGE]");
  else
    self.Controls.CQUI_Era:SetText("[ICON_GLORY_NORMAL_AGE]");
  end
  -- CQUI Additions

end

-- ===========================================================================
--	Resets the view of attached controls
-- ===========================================================================
function LeaderIcon:Reset()
  if self.Controls == nil then
    UI.DataError("Attempting to call Reset() on a nil LeaderIcon.");
    return;
  end
  self.Controls.TeamRibbon:SetHide(true);
  self.Controls.Relationship:SetHide(true);
  self.Controls.YouIndicator:SetHide(true);
end

------------------------------------------------------------------
function LeaderIcon:RegisterCallback(event: number, func: ifunction)
  self.Controls.SelectButton:RegisterCallback(event, func);
end

------------------------------------------------------------------
function LeaderIcon:GetToolTipString(playerID:number)

  local result:string = "";
  local pPlayerConfig:table = PlayerConfigurations[playerID];

  if pPlayerConfig and pPlayerConfig:GetLeaderTypeName() then
    local isHuman		:boolean = pPlayerConfig:IsHuman();
    local leaderDesc	:string = pPlayerConfig:GetLeaderName();
    local civDesc		:string = pPlayerConfig:GetCivilizationDescription();
    local localPlayerID	:number = Game.GetLocalPlayer();
    
    if localPlayerID==PlayerTypes.NONE or localPlayerID==PlayerTypes.OBSERVER  then
      return "";
    end		

    if GameConfiguration.IsAnyMultiplayer() and isHuman then
      if(playerID ~= localPlayerID and not Players[localPlayerID]:GetDiplomacy():HasMet(playerID)) then
        result = Locale.Lookup("LOC_DIPLOPANEL_UNMET_PLAYER") .. " (" .. pPlayerConfig:GetPlayerName() .. ")";
      else
        result = Locale.Lookup("LOC_DIPLOMACY_DEAL_PLAYER_PANEL_TITLE", leaderDesc, civDesc) .. " (" .. pPlayerConfig:GetPlayerName() .. ")";
      end
    else
      if(playerID ~= localPlayerID and not Players[localPlayerID]:GetDiplomacy():HasMet(playerID)) then
        result = Locale.Lookup("LOC_DIPLOPANEL_UNMET_PLAYER");
      else
        result = Locale.Lookup("LOC_DIPLOMACY_DEAL_PLAYER_PANEL_TITLE", leaderDesc, civDesc);
      end
    end
  end

  return result;
end

-- ===========================================================================
function LeaderIcon:AppendTooltip( extraText:string )
  if extraText == nil or extraText == "" then return; end		--Ignore blank
  local tooltip:string = self:GetToolTipString(self.playerID) .. "[NEWLINE]" .. extraText;
  self.Controls.Portrait:SetToolTipString(tooltip);
end