-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_OnActivateIntelRelationshipPanel = OnActivateIntelRelationshipPanel

-- ===========================================================================
-- Members
-- ===========================================================================
local ms_IntelGossipHistoryPanelEntryIM	:table	= InstanceManager:new( "IntelGossipHistoryPanelEntry",  "Background" );

-- ===========================================================================
-- CQUI Members
-- ===========================================================================
local CQUI_trimGossip = true;

function CQUI_OnSettingsUpdate()
  CQUI_trimGossip = GameConfiguration.GetValue("CQUI_TrimGossip");
end

LuaEvents.CQUI_SettingsUpdate.Add( CQUI_OnSettingsUpdate );
LuaEvents.CQUI_SettingsInitialized.Add( CQUI_OnSettingsUpdate );

-- ===========================================================================
--  CQUI modified OnActivateIntelGossipHistoryPanel functiton
--  Trim the gossip message
--  Integration of Simplified Gossip mod
-- ===========================================================================
function OnActivateIntelGossipHistoryPanel(gossipInstance : table)
  
  local intelSubPanel = gossipInstance;
  
  -- Get the selected player's Diplomactic AI
  local selectedPlayerDiplomaticAI = ms_SelectedPlayer:GetDiplomaticAI();

  local localPlayerDiplomacy = ms_LocalPlayer:GetDiplomacy();
  
  ms_IntelGossipHistoryPanelEntryIM:ResetInstances();
  
  local bAddedLastTenTurnsItem = false;
  local bAddedOlderItem = false;
  
  local gossipManager = Game.GetGossipManager();
  
  local iCurrentTurn = Game.GetCurrentGameTurn();
  
  --Only show the gossip generated in the last 100 turns.  Otherwise we can end up with a TON of gossip, and everything bogs down.
  local earliestTurn = iCurrentTurn - 100;
  local gossipStringTable = gossipManager:GetRecentVisibleGossipStrings(earliestTurn, ms_LocalPlayerID, ms_SelectedPlayerID);
  
  if(#gossipStringTable > 0) then								 -- FF16~ Neccesary with new loop to prevent trying to reference items in empty gossip tables of civs you just met.
    --for i, currTable:table in pairs(gossipStringTable) do  -- FF16~ The original loop delcaration seems to have a bug, it puts the most recent gossip entry at the bottom instead of the top.
    for i = 0, #gossipStringTable do 						 -- FF16~ I have delcared a simpler loop which seems to resolve the issue and correctly puts the list in the right order.
      
      currTable = gossipStringTable[i];
      local gossipString = currTable[1];
      local gossipTurn = currTable[2];
      
      if (gossipString ~= nil) then
        local item;
        if ((iCurrentTurn - gossipTurn) <= 10) then
          item = ms_IntelGossipHistoryPanelEntryIM:GetInstance(intelSubPanel.LastTenTurnsStack);
          bAddedLastTenTurnsItem = true;
          -- If we received this gossip this turn or last turn mark it as new
          if((iCurrentTurn-1) <= gossipTurn) then
            item.NewIndicator:SetHide(false);
          else
            item.NewIndicator:SetHide(true);
          end
        else
          item = ms_IntelGossipHistoryPanelEntryIM:GetInstance(intelSubPanel.OlderStack);
          item.NewIndicator:SetHide(true);
          bAddedOlderItem = true;
        end
        
        if (item ~= nil) then
          -- AZURENCY : trim the message if the setting is enable
          if(CQUI_trimGossip) then
            trimmed = CQUI_TrimGossipMessage(gossipString);
            if trimmed ~= nil then
              gossipString = trimmed
            end
          end
          item.GossipText:SetText(gossipString);			-- It has already been localized
          AutoSizeGrid(item:GetTopControl(), item.GossipText,25,25);
        end
      else
        break;
      end
    end
  end
  
  if (not bAddedLastTenTurnsItem) then
    local item = ms_IntelGossipHistoryPanelEntryIM:GetInstance(intelSubPanel.LastTenTurnsStack);
    item.GossipText:LocalizeAndSetText("LOC_DIPLOMACY_GOSSIP_ITEM_NO_RECENT");
    item.NewIndicator:SetHide(true);
    AutoSizeGrid(item:GetTopControl(), item.GossipText,25,37);
  end
  
  if (not bAddedOlderItem) then
    intelSubPanel.OlderHeader:SetHide(true);
  else
    intelSubPanel.OlderHeader:SetHide(false);
  end
end

-- ===========================================================================
--  CQUI modified OnActivateIntelRelationshipPanel functiton
--  Added a total row to the relationship detail tab
-- ===========================================================================
function OnActivateIntelRelationshipPanel(relationshipInstance : table)
  local intelSubPanel = relationshipInstance;

  -- Get the selected player's Diplomactic AI
  local selectedPlayerDiplomaticAI = ms_SelectedPlayer:GetDiplomaticAI();
  -- What do they think of us?
  local iState = selectedPlayerDiplomaticAI:GetDiplomaticStateIndex(ms_LocalPlayerID);
  local kStateEntry = GameInfo.DiplomaticStates[iState];

  local relationshipScore = kStateEntry.RelationshipLevel;
  local relationshipScoreText = Locale.Lookup("{1_Score : number #,###.##;#,###.##}", relationshipScore);

  if (relationshipScore > 50) then
    relationshipScoreText = "[COLOR_Civ6Green]" .. relationshipScoreText .. "[ENDCOLOR]";
  elseif (relationshipScore < 50) then
    relationshipScoreText = "[COLOR_Civ6Red]" .. relationshipScoreText .. "[ENDCOLOR]";
  else
    relationshipScoreText = "[COLOR_Grey]" .. relationshipScoreText .. "[ENDCOLOR]";
  end

  intelSubPanel.RelationshipScore:SetText(relationshipScoreText);

  local toolTips = selectedPlayerDiplomaticAI:GetDiplomaticModifiers(ms_LocalPlayerID);
  local reasonsTotalScore = 0;
  local hasReasonEntries = false;

  if(toolTips) then
    table.sort(toolTips, function(a,b) return a.Score > b.Score; end);

    for i, tip in ipairs(toolTips) do
      local score = tip.Score;
      reasonsTotalScore = reasonsTotalScore + score;

      if(score ~= 0) then
        hasReasonEntries = true;
      end
    end
  end

  local reasonsTotalScoreText = Locale.Lookup("{1_Score : number +#,###.##;-#,###.##}", reasonsTotalScore);
  if (reasonsTotalScore > 0) then
    reasonsTotalScoreText = "[COLOR_Civ6Green]" .. reasonsTotalScoreText .. "[ENDCOLOR]";
  elseif (reasonsTotalScore < 0) then
    reasonsTotalScoreText = "[COLOR_Civ6Red]" .. reasonsTotalScoreText .. "[ENDCOLOR]";
  else
    reasonsTotalScoreText = "[COLOR_Grey]" .. reasonsTotalScoreText .. "[ENDCOLOR]";
  end

  if (hasReasonEntries) then
    intelSubPanel.RelationshipReasonsTotal:SetHide(false);
    intelSubPanel.RelationshipReasonsTotalScorePerTurn:SetText(reasonsTotalScoreText);
  else
    intelSubPanel.RelationshipReasonsTotal:SetHide(true);
  end

  BASE_OnActivateIntelRelationshipPanel(intelSubPanel);
end