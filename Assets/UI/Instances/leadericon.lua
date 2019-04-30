-- Copyright 2017-2019, Firaxis Games
include("LuaClass");
include("TeamSupport");
include("DiplomacyRibbonSupport");
include("ExtendedRelationship");

------------------------------------------------------------------
-- Class Table
------------------------------------------------------------------
LeaderIcon = LuaClass:Extend();

------------------------------------------------------------------
-- Class Constants
------------------------------------------------------------------
LeaderIcon.DATA_FIELD_CLASS = "LEADER_ICON_CLASS";
LeaderIcon.TEAM_RIBBON_PREFIX = "ICON_TEAM_RIBBON_";
LeaderIcon.TEAM_RIBBON_SIZE = 53;

------------------------------------------------------------------
-- Static-Style allocation functions
------------------------------------------------------------------
function LeaderIcon:GetInstance(instanceManager:table, newParent:table)
  -- Create leader icon class if it has not yet been created for this instance
  local instance:table = instanceManager:GetInstance(newParent);
  return LeaderIcon:AttachInstance(instance);
end

function LeaderIcon:AttachInstance(instance:table)
  self = instance[LeaderIcon.DATA_FIELD_CLASS];
  if not self then
    self = LeaderIcon:new(instance);
    instance[LeaderIcon.DATA_FIELD_CLASS] = self;
  end
  self:Reset();
  return self, instance;
end

------------------------------------------------------------------
-- Constructor
------------------------------------------------------------------
function LeaderIcon:new(instanceOrControls: table)
  self = LuaClass.new(LeaderIcon)
  self.Controls = instanceOrControls or Controls;
  return self;
end



-- ===========================================================================
function LeaderIcon:UpdateIcon(iconName: string, playerID: number, isUniqueLeader: boolean, ttDetails: string)
  local pPlayer:table = Players[playerID];
  local pPlayerConfig:table = PlayerConfigurations[playerID];
  local localPlayerID:number = Game.GetLocalPlayer();

  -- Display the civ colors/icon for duplicate civs
  if (isUniqueLeader == false and (playerID == localPlayerID or Players[localPlayerID]:GetDiplomacy():HasMet(playerID))) then
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

function LeaderIcon:UpdateIconSimple(iconName: string, playerID: number, isUniqueLeader: boolean, ttDetails: string)
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
  
  if playerID < 0 then 
    UI.DataError("Invalid playerID="..tostring(playerID).." to check against for UpdateTeamAndRelationship().");
    return; 
  end	
  
  local localPlayerID	:number = Game.GetLocalPlayer();
  if localPlayerID < 0 then return; end		--  Local player is auto-play.

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
    
    -- CQUI Extended relationship tooltip
    local extendedRelationshipTooltip:string = Locale.Lookup(GameInfo.DiplomaticStates[eRelationship].Name) .. "[NEWLINE][NEWLINE]" .. RelationshipGet(playerID);
    self.Controls.Relationship:SetToolTipString(extendedRelationshipTooltip);
    
    -- if (GameInfo.DiplomaticStates[eRelationship].Hash ~= DiplomaticStates.NEUTRAL) then
    -- 	 self.Controls.Relationship:SetToolTipString(Locale.Lookup(GameInfo.DiplomaticStates[eRelationship].Name));
    -- end
  end
  self.Controls.Relationship:SetHide( not isValid );
end

--Resets instances we retrieve
function LeaderIcon:Reset()
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
    local isHuman:boolean = pPlayerConfig:IsHuman();
    local localPlayerID:number = Game.GetLocalPlayer();
    local leaderDesc:string = pPlayerConfig:GetLeaderName();
    local civDesc:string = pPlayerConfig:GetCivilizationDescription();

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
