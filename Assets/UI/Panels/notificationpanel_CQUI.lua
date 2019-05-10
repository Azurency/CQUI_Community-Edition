-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_CQUI_OnTechBoostActivateNotification = OnTechBoostActivateNotification;
BASE_CQUI_OnCivicBoostActivateNotification = OnCivicBoostActivateNotification;
BASE_CQUI_OnNotificationAdded = OnNotificationAdded;
BASE_CQUI_LateInitialize = LateInitialize;
BASE_CQUI_RegisterHandlers = RegisterHandlers;

-- =======================================================================================
function OnCityRangeAttack( notificationEntry : NotificationType )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
    local pPlayer = Players[notificationEntry.m_PlayerID];
    if pPlayer ~= nil then
      local attackCity = pPlayer:GetCities():GetFirstRangedAttackCity();
      if(attackCity ~= nil) then
        LuaEvents.CQUI_Strike_Enter();
        LuaEvents.CQUI_CityRangeStrike(Game.GetLocalPlayer(), attackCity:GetID());
      else
        error( "Unable to find selectable attack city while in OnCityRangeAttack()" );
      end
    end
  end
end

-- =======================================================================================
function OnTechBoostActivateNotification( notificationEntry : NotificationType, notificationID : number )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
    local pNotification :table = GetActiveNotificationFromEntry(notificationEntry, notificationID);
    if pNotification ~= nil then
      local techIndex = pNotification:GetValue("TechIndex");
      local techProgress = pNotification:GetValue("TechProgress");
      local techSource = pNotification:GetValue("TechSource");
      if(techIndex ~= nil and techProgress ~= nil and techSource ~= nil) then
        -- CQUI update all cities real housing when play as India and boosted and researched Sanitation
        if techIndex == GameInfo.Technologies["TECH_SANITATION"].Index then    -- Sanitation
          if PlayerConfigurations[notificationEntry.m_PlayerID]:GetCivilizationTypeName() == "CIVILIZATION_INDIA" then
            if Players[notificationEntry.m_PlayerID]:GetTechs():HasTech(techIndex) then
              LuaEvents.CQUI_AllCitiesInfoUpdatedOnTechCivicBoost(notificationEntry.m_PlayerID);
            end
          end
        -- CQUI update all cities real housing when play as Indonesia and boosted and researched Mass Production
        elseif techIndex == GameInfo.Technologies["TECH_MASS_PRODUCTION"].Index then    -- Mass Production
          if PlayerConfigurations[notificationEntry.m_PlayerID]:GetCivilizationTypeName() == "CIVILIZATION_INDONESIA" then
            if Players[notificationEntry.m_PlayerID]:GetTechs():HasTech(techIndex) then
              LuaEvents.CQUI_AllCitiesInfoUpdatedOnTechCivicBoost(notificationEntry.m_PlayerID);
            end
          end
        end
      end
    end
  end

  BASE_CQUI_OnTechBoostActivateNotification(notificationEntry, notificationID);
end

-- =======================================================================================
function OnCivicBoostActivateNotification( notificationEntry : NotificationType, notificationID : number )
  if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
    local pNotification :table = GetActiveNotificationFromEntry(notificationEntry, notificationID);
    if pNotification ~= nil then
      local civicIndex = pNotification:GetValue("CivicIndex");
      local civicProgress = pNotification:GetValue("CivicProgress");
      local civicSource = pNotification:GetValue("CivicSource");
      if(civicIndex ~= nil and civicProgress ~= nil and civicSource ~= nil) then
        -- CQUI update all cities real housing when play as Cree and boosted and researched Civil Service
        if civicIndex == GameInfo.Civics["CIVIC_CIVIL_SERVICE"].Index then    -- Civil Service
          if PlayerConfigurations[notificationEntry.m_PlayerID]:GetCivilizationTypeName() == "CIVILIZATION_CREE" then
            if Players[notificationEntry.m_PlayerID]:GetCulture():HasCivic(civicIndex) then
              LuaEvents.CQUI_AllCitiesInfoUpdatedOnTechCivicBoost(notificationEntry.m_PlayerID);
            end
          end
        -- CQUI update all cities real housing when play as Scotland and boosted and researched Globalization
        elseif civicIndex == GameInfo.Civics["CIVIC_GLOBALIZATION"].Index then    -- Globalization
          if PlayerConfigurations[notificationEntry.m_PlayerID]:GetCivilizationTypeName() == "CIVILIZATION_SCOTLAND" then
            if Players[notificationEntry.m_PlayerID]:GetCulture():HasCivic(civicIndex) then
              LuaEvents.CQUI_AllCitiesInfoUpdatedOnTechCivicBoost(notificationEntry.m_PlayerID);
            end
          end
        end
      end
    end
  end

  BASE_CQUI_OnCivicBoostActivateNotification(notificationEntry, notificationID);
end

-- ===========================================================================
function OnNotificationAdded( playerID:number, notificationID:number )
  if (playerID == Game.GetLocalPlayer())  then -- Was it for us?
    local pNotification = NotificationManager.Find( playerID, notificationID );
    -- CQUI: Notification when a City lost tile to a Culture Bomb. We use it to update real housing.
    if pNotification ~= nil and pNotification:GetType() == GameInfo.Notifications["NOTIFICATION_TILE_LOST_CULTURE_BOMB"].Hash then
      local x, y = pNotification:GetLocation();
      LuaEvents.CQUI_CityLostTileToCultureBomb(playerID, x, y);
    end
  end

  BASE_CQUI_OnNotificationAdded(playerID, notificationID);
end

-- ===========================================================================
function LateInitialize()
  BASE_CQUI_LateInitialize();

  Events.NotificationAdded.Remove(BASE_CQUI_OnNotificationAdded);
  Events.NotificationAdded.Add(OnNotificationAdded);
end

-- ===========================================================================
function RegisterHandlers()
  BASE_CQUI_RegisterHandlers();
  
  g_notificationHandlers[NotificationTypes.CIVIC_BOOST].Activate = OnCivicBoostActivateNotification;
  g_notificationHandlers[NotificationTypes.TECH_BOOST].Activate = OnTechBoostActivateNotification;
end