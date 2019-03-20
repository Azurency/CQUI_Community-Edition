-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_CQUI_LateInitialize = LateInitialize;
BASE_CQUI_PopulateNode = PopulateNode;
BASE_CQUI_OnOpen = OnOpen;
BASE_CQUI_OnCivicComplete = OnCivicComplete;
BASE_CQUI_OnLocalPlayerTurnBegin = OnLocalPlayerTurnBegin;

-- ===========================================================================
-- CQUI Members
-- ===========================================================================
local CQUI_STATUS_MESSAGE_CIVIC :number = 3;    -- Number to distinguish civic messages
local CQUI_halfwayNotified  :table = {};
local CQUI_ShowTechCivicRecommendations = false;

function CQUI_OnSettingsUpdate()
  CQUI_ShowTechCivicRecommendations = GameConfiguration.GetValue("CQUI_ShowTechCivicRecommendations") == 1
end

-- ===========================================================================
--  CQUI modified PopulateNode functiton
--  Show/Hide Recommended Icon if enabled in settings
-- ===========================================================================
function PopulateNode(uiNode, playerTechData)
  BASE_CQUI_PopulateNode(uiNode, playerTechData);

  local live :table = playerTechData[DATA_FIELD_LIVEDATA][uiNode.Type]; 
  if not CQUI_ShowTechCivicRecommendations then
    uiNode.RecommendedIcon:SetHide(true);
  end
end

-- ===========================================================================
--  CQUI modified OnLocalPlayerTurnBegin functiton
--  Check for Civic Progress
-- ===========================================================================
function OnLocalPlayerTurnBegin()
  BASE_CQUI_OnLocalPlayerTurnBegin();

  -- CQUI comment: We do not use UpdateLocalPlayer() here, because of Check for Civic Progress
  local ePlayer :number = Game.GetLocalPlayer();
  if ePlayer ~= -1 then
    -- Get the current tech
    local kPlayer       :table  = Players[ePlayer];
    local playerCivics      :table  = kPlayer:GetCulture();
    local currentCivicID  :number = playerCivics:GetProgressingCivic();
    local isCurrentBoosted  :boolean = playerCivics:HasBoostBeenTriggered(currentCivicID);

    -- Make sure there is a civic selected before continuing with checks
    if currentCivicID ~= -1 then
      local civicName = GameInfo.Civics[currentCivicID].Name;
      local civicType = GameInfo.Civics[currentCivicID].Type;
      local currentCost = playerCivics:GetCultureCost(currentCivicID);
      local currentProgress = playerCivics:GetCulturalProgress(currentCivicID);
      local currentYield = playerCivics:GetCultureYield();
      local percentageToBeDone = (currentProgress + currentYield) / currentCost;
      local percentageNextTurn = (currentProgress + currentYield*2) / currentCost;
      local CQUI_halfway:number = .5;

      -- Finds boost amount, always 50 in base game, China's +10% modifier is not applied here
      for row in GameInfo.Boosts() do
        if(row.CivicType == civicType) then
          CQUI_halfway = (100 - row.Boost) / 100;
          break;
        end
      end
      --If playing as china, apply boost modifier. Not sure where I can query this value...
      if(PlayerConfigurations[Game.GetLocalPlayer()]:GetCivilizationTypeName() == "CIVILIZATION_CHINA") then
        CQUI_halfway = CQUI_halfway - .1;
      end

      -- Is it greater than 50% and has yet to be displayed?
      if isCurrentBoosted then
        CQUI_halfwayNotified[civicName] = true;
      elseif percentageNextTurn >= CQUI_halfway and CQUI_halfwayNotified[civicName] ~= true then
        LuaEvents.CQUI_AddStatusMessage(Locale.Lookup("LOC_CQUI_CIVIC_MESSAGE_S") .. " " .. Locale.Lookup( civicName ) ..  " " .. Locale.Lookup("LOC_CQUI_HALF_MESSAGE_E"), 10, CQUI_STATUS_MESSAGE_CIVIC);
        CQUI_halfwayNotified[civicName] = true;
      end

    end
  end
end

-- ===========================================================================
--  CQUI modified OnCivicComplete functiton
--  Show completion notification
--  Update real housing
-- ===========================================================================
function OnCivicComplete( ePlayer:number, eTech:number)
  BASE_CQUI_OnCivicComplete(ePlayer, eTech);

  if ePlayer == Game.GetLocalPlayer() then
    -- Get the current tech
    local kPlayer       :table  = Players[ePlayer];
    local currentCivicID  :number = eTech;

    -- Make sure there is a civic selected before continuing with checks
    if currentCivicID ~= -1 then
      local civicName = GameInfo.Civics[currentCivicID].Name;
      LuaEvents.CQUI_AddStatusMessage(Locale.Lookup("LOC_CIVIC_BOOST_COMPLETE", civicName), 10, CQUI_STATUS_MESSAGE_CIVIC);
    end

    -- CQUI update all cities real housing when play as Cree and researched Civil Service
    if eTech == GameInfo.Civics["CIVIC_CIVIL_SERVICE"].Index then    -- Civil Service
      if (PlayerConfigurations[ePlayer]:GetCivilizationTypeName() == "CIVILIZATION_CREE") then
        LuaEvents.CQUI_AllCitiesInfoUpdated(ePlayer);
      end
    -- CQUI update all cities real housing when play as Scotland and researched Globalization
    elseif eTech == GameInfo.Civics["CIVIC_GLOBALIZATION"].Index then    -- Globalization
      if (PlayerConfigurations[ePlayer]:GetCivilizationTypeName() == "CIVILIZATION_SCOTLAND") then
        LuaEvents.CQUI_AllCitiesInfoUpdated(ePlayer);
      end
    end

  end
end

-- ===========================================================================
--  CQUI modified OnOpen functiton
--  Search bar autofocus
-- ===========================================================================
function OnOpen()
  if (Game.GetLocalPlayer() == -1) then
    return;
  end

  BASE_CQUI_OnOpen()

  Controls.SearchEditBox:TakeFocus();
end

function LateInitialize()
  BASE_CQUI_LateInitialize();

  LuaEvents.CivicsPanel_RaiseCivicsTree.Remove(BASE_CQUI_OnOpen);
  LuaEvents.LaunchBar_RaiseCivicsTree.Remove(BASE_CQUI_OnOpen);
  LuaEvents.CivicsChooser_RaiseCivicsTree.Add(OnOpen);
  LuaEvents.LaunchBar_RaiseCivicsTree.Add(OnOpen);
  Events.CivicCompleted.Remove(BASE_CQUI_OnCivicComplete);
  Events.CivicCompleted.Add(OnCivicComplete);
  Events.LocalPlayerTurnBegin.Remove(BASE_CQUI_OnLocalPlayerTurnBegin);
  Events.LocalPlayerTurnBegin.Add(OnLocalPlayerTurnBegin);
  
  -- CQUI add exceptions to the 50% notifications by putting civics into the CQUI_halfwayNotified table
  CQUI_halfwayNotified["LOC_CIVIC_CODE_OF_LAWS_NAME"] = true;

  LuaEvents.CQUI_SettingsUpdate.Add(CQUI_OnSettingsUpdate);
  LuaEvents.CQUI_SettingsInitialized.Add(CQUI_OnSettingsUpdate);
end