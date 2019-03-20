-- ===========================================================================
-- Base File
-- ===========================================================================
include("PlotInfo");

-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_OnClickSwapTile = OnClickSwapTile;
BASE_OnClickPurchasePlot = OnClickPurchasePlot;
BASE_ShowCitizens = ShowCitizens;
BASE_OnDistrictAddedToMap = OnDistrictAddedToMap;
BASE_AggregateLensHexes = AggregateLensHexes;

-- ===========================================================================
-- CQUI Members
-- ===========================================================================
local CQUI_WorkIconSize: number = 48;
local CQUI_WorkIconAlpha = .60;
local CQUI_SmartWorkIcon: boolean = true;
local CQUI_SmartWorkIconSize: number = 64;
local CQUI_SmartWorkIconAlpha = .45;
local CQUI_DragStarted = false;
local CITY_CENTER_DISTRICT_INDEX = GameInfo.Districts["DISTRICT_CITY_CENTER"].Index;

function CQUI_OnSettingsUpdate()
  CQUI_WorkIconSize = GameConfiguration.GetValue("CQUI_WorkIconSize");
  CQUI_WorkIconAlpha = GameConfiguration.GetValue("CQUI_WorkIconAlpha") / 100;
  CQUI_SmartWorkIcon = GameConfiguration.GetValue("CQUI_SmartWorkIcon");
  CQUI_SmartWorkIconSize = GameConfiguration.GetValue("CQUI_SmartWorkIconSize");
  CQUI_SmartWorkIconAlpha = GameConfiguration.GetValue("CQUI_SmartWorkIconAlpha") / 100;
end

-- ===========================================================================
-- CQUI update citizens, data and real housing for both cities when swap tiles
-- ===========================================================================
function CQUI_UpdateCitiesCitizensWhenSwapTiles(pCity)
  CityManager.RequestCommand(pCity, CityCommandTypes.SET_FOCUS, nil);

  local PlayerID = Game.GetLocalPlayer();
  local pCityID = pCity:GetID();
  LuaEvents.CQUI_CityInfoUpdated(PlayerID, pCityID);
end

-- ===========================================================================
-- CQUI update citizens, data and real housing for close cities within 4 tiles when city founded
-- we use it only to update real housing for a city that loses a 3rd radius tile to a city that is founded within 4 tiles
-- ===========================================================================
function CQUI_UpdateCloseCitiesCitizensWhenCityFounded(playerID, cityID)
  local kCity = CityManager.GetCity(playerID, cityID);
  local m_pCity:table = Players[playerID]:GetCities();
  for i, pCity in m_pCity:Members() do
    if Map.GetPlotDistance( kCity:GetX(), kCity:GetY(), pCity:GetX(), pCity:GetY() ) == 4 then
      CityManager.RequestCommand(pCity, CityCommandTypes.SET_FOCUS, nil);

      local pCityID = pCity:GetID();
      LuaEvents.CQUI_CityInfoUpdated(playerID, pCityID);
    end
  end
end

--Takes a table with duplicates and returns a new table without duplicates. Credit to vogomatix at stask exchange for the code
function CQUI_RemoveDuplicates(i:table)
  local hash = {};
  local o = {};
  for _,v in ipairs(i) do
    if (not hash[v]) then
        o[#o+1] = v;
        hash[v] = true;
    end
  end
  return o;
end

function CQUI_StartDragMap()
  CQUI_DragStarted = true;
end

-- ===========================================================================
--  CQUI modified OnClickSwapTile function
--  Update citizens, data and real housing for both cities
-- ===========================================================================
function OnClickSwapTile( plotId:number )
  local result = BASE_OnClickSwapTile(plotId);

  local pSelectedCity :table = UI.GetHeadSelectedCity();
  local kPlot :table = Map.GetPlotByIndex(plotId);
  local pCity = Cities.GetPlotPurchaseCity(kPlot);  -- CQUI a city that was a previous tile owner
  CQUI_UpdateCitiesCitizensWhenSwapTiles(pSelectedCity);  -- CQUI update citizens and data for a city that is a new tile owner
  CQUI_UpdateCitiesCitizensWhenSwapTiles(pCity);  -- CQUI update citizens and data for a city that was a previous tile owner
  
  return result;
end

-- ===========================================================================
--  CQUI modified OnClickPurchasePlot function
--  Don't purchase if currently dragging
--  Update the city data
-- ===========================================================================
function OnClickPurchasePlot( plotId:number )
  -- CQUI (Azurency) : if we're dragging, don't purchase
  if CQUI_DragStarted then
    CQUI_DragStarted = false;
    return;
  end

  local result = BASE_OnClickPurchasePlot(plotId);

  OnClickCitizen();  -- CQUI : update selected city citizens and data

  return result;
end

-- ===========================================================================
--  CQUI modified ShowCitizens function : Customize the citizen icon and Hide the city center icon
-- ===========================================================================
function ShowCitizens()
  BASE_ShowCitizens();

  local pSelectedCity :table = UI.GetHeadSelectedCity();
  if pSelectedCity == nil then
    -- Add error message here
    return;
  end

  local tParameters :table = {};
  tParameters[CityCommandTypes.PARAM_MANAGE_CITIZEN] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_MANAGE_CITIZEN);

  local tResults  :table = CityManager.GetCommandTargets( pSelectedCity, CityCommandTypes.MANAGE, tParameters );
  if tResults == nil then
    -- Add error message here
    return;
  end

  local tPlots :table = tResults[CityCommandResults.PLOTS];
  local tUnits :table = tResults[CityCommandResults.CITIZENS];
  if tPlots ~= nil and (table.count(tPlots) > 0) then
    for i,plotId in pairs(tPlots) do
      local kPlot :table = Map.GetPlotByIndex(plotId);
      local index :number = kPlot:GetIndex();
      local pInstance :table = GetInstanceAt( index );

      if pInstance ~= nil then
        local isCityCenterPlot = kPlot:GetDistrictType() == CITY_CENTER_DISTRICT_INDEX;
        pInstance.CitizenButton:SetHide(isCityCenterPlot);
        pInstance.CitizenButton:SetDisabled(isCityCenterPlot);

        local numUnits:number = tUnits[i];

        --CQUI Citizen buttons tweaks
        if(CQUI_SmartWorkIcon and numUnits >= 1) then
          pInstance.CitizenButton:SetSizeVal(CQUI_SmartWorkIconSize, CQUI_SmartWorkIconSize);
          pInstance.CitizenButton:SetAlpha(CQUI_SmartWorkIconAlpha);
        else
          pInstance.CitizenButton:SetSizeVal(CQUI_WorkIconSize, CQUI_WorkIconSize);
          pInstance.CitizenButton:SetAlpha(CQUI_WorkIconAlpha);
        end

        if(numUnits >= 1) then
          pInstance.CitizenButton:SetTextureOffsetVal(0, 256);
        end
      end
    end
  end
end

-- ===========================================================================
--  CQUI modified OnDistrictAddedToMap function
--  Update citizens, data and real housing for close cities within 4 tiles when city founded
--  we use it only to update real housing for a city that loses a 3rd radius tile to a city that is founded within 4 tiles
-- ===========================================================================
function OnDistrictAddedToMap( playerID: number, districtID : number, cityID :number, districtX : number, districtY : number, districtType:number )
  BASE_OnDistrictAddedToMap(playerID, districtID, cityID, districtX, districtY, districtType);
  
  if districtType == CITY_CENTER_DISTRICT_INDEX and playerID == Game.GetLocalPlayer() then
    CQUI_UpdateCloseCitiesCitizensWhenCityFounded(playerID, cityID);
  end
end

-- ===========================================================================
--  CQUI modified AggregateLensHexes function : Remove duplicate entry
-- ===========================================================================
function AggregateLensHexes(keys:table)
  return CQUI_RemoveDuplicates(BASE_AggregateLensHexes(keys));
end

function Initialize()
  Events.DistrictAddedToMap.Remove(BASE_OnDistrictAddedToMap);
  Events.DistrictAddedToMap.Add(OnDistrictAddedToMap);

  LuaEvents.CQUI_SettingsUpdate.Add(CQUI_OnSettingsUpdate);
  LuaEvents.CQUI_SettingsInitialized.Add(CQUI_OnSettingsUpdate);
  LuaEvents.CQUI_StartDragMap.Add(CQUI_StartDragMap);
end
Initialize();