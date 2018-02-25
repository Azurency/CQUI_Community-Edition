-- ===========================================================================
function GetFormattedOperationDetailText(operation:table, spy:table, city:table)
  local outputString:string = "";
  local eOperation:number = GameInfo.UnitOperations[operation.Hash].Index;
  local sOperationDetails:string = UnitManager.GetOperationDetailText(eOperation, spy, Map.GetPlot(city:GetX(), city:GetY()));
  if operation.OperationType == "UNITOPERATION_SPY_GREAT_WORK_HEIST" then
    outputString = Locale.Lookup("LOC_SPYMISSIONDETAILS_UNITOPERATION_SPY_GREAT_WORK_HEIST", Locale.Lookup(sOperationDetails));
  elseif operation.OperationType == "UNITOPERATION_SPY_SIPHON_FUNDS" then
    outputString = Locale.Lookup("LOC_SPYMISSIONDETAILS_UNITOPERATION_SPY_SIPHON_FUNDS", Locale.ToUpper(city:GetName()), sOperationDetails);
  elseif sOperationDetails ~= "" then
    outputString = sOperationDetails;
  else
    -- Find the loc string by OperationType if this operation doesn't use GetOperationDetailText
    outputString = Locale.Lookup("LOC_SPYMISSIONDETAILS_" .. operation.OperationType);
  end

  return outputString;
end

-- ===========================================================================
function GetSpyRankNameByLevel(level:number)
  local spyRankName:string = "";

  if (level == 4) then
    spyRankName = "LOC_ESPIONAGE_LEVEL_4_NAME";
  elseif (level == 3) then
    spyRankName = "LOC_ESPIONAGE_LEVEL_3_NAME";
  elseif (level == 2) then
    spyRankName = "LOC_ESPIONAGE_LEVEL_2_NAME";
  else
    spyRankName = "LOC_ESPIONAGE_LEVEL_1_NAME";
  end

  return spyRankName;
end

-- ===========================================================================
function GetMissionOutcomeDetails(mission:table)
  local outcomeDetails:table = {};
  if mission.InitialResult == EspionageResultTypes.SUCCESS_UNDETECTED then
    -- Success and undetected
    if mission.LootInfo >= 0 then
      outcomeDetails.Description = Locale.Lookup("LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_SUCCESS_UNDETECTED_STOLELOOT", GetMissionLootString(mission), Locale.Lookup(mission.CityName));
    else
      outcomeDetails.Description = Locale.Lookup("LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_SUCCESS_UNDETECTED", Locale.Lookup(mission.CityName));
    end
    outcomeDetails.Success = true;
    outcomeDetails.SpyStatus = "";
  elseif mission.InitialResult == EspionageResultTypes.SUCCESS_MUST_ESCAPE then
    -- Success but detected
    if mission.EscapeResult == EspionageResultTypes.FAIL_MUST_ESCAPE then
      -- Success and escaped
      if mission.LootInfo >= 0 then
        outcomeDetails.Description = Locale.Lookup("LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_SUCCESS_DETECTED_STOLELOOT", GetMissionLootString(mission), Locale.Lookup(mission.CityName));
      else
        outcomeDetails.Description = Locale.Lookup("LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_SUCCESS_DETECTED_ESCAPED", Locale.Lookup(mission.CityName));
      end
      outcomeDetails.Success = true;
      outcomeDetails.SpyStatus = "";
    elseif mission.EscapeResult == EspionageResultTypes.KILLED then
      -- Success and killed
      outcomeDetails.Success = false;
      outcomeDetails.Description = Locale.Lookup("LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_SUCCESS_DETECTED_KILLED", Locale.Lookup(mission.CityName));
      outcomeDetails.SpyStatus = Locale.ToUpper("LOC_ESPIONAGEOVERVIEW_SPYKILLED");
    elseif mission.EscapeResult == EspionageResultTypes.CAPTURED then
      -- Success and captured
      outcomeDetails.Success = false;
      outcomeDetails.Description = Locale.Lookup("LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_SUCCESS_DETECTED_CAPTURED", Locale.Lookup(mission.CityName));
      outcomeDetails.SpyStatus = Locale.ToUpper("LOC_ESPIONAGEOVERVIEW_SPYCAUGHT");
    end
  elseif mission.InitialResult == EspionageResultTypes.FAIL_UNDETECTED then
    -- Failure but undetected
    outcomeDetails.Success = false;
    outcomeDetails.Description = Locale.Lookup("LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_FAILURE_UNDETECTED", Locale.Lookup(mission.CityName));
    outcomeDetails.SpyStatus = "";
  elseif mission.InitialResult == EspionageResultTypes.FAIL_MUST_ESCAPE then
    -- Failure and detected
    if mission.EscapeResult == EspionageResultTypes.FAIL_MUST_ESCAPE then
      -- Failure and escaped
      outcomeDetails.Success = false;
      outcomeDetails.Description = Locale.Lookup("LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_FAILURE_DETECTED_ESCAPED", Locale.Lookup(mission.CityName));
      outcomeDetails.SpyStatus = "";
    elseif mission.EscapeResult == EspionageResultTypes.KILLED then
      -- Failure and killed
      outcomeDetails.Success = false;
      outcomeDetails.Description = Locale.Lookup("LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_FAILURE_DETECTED_KILLED", Locale.Lookup(mission.CityName));
      outcomeDetails.SpyStatus = Locale.ToUpper("LOC_ESPIONAGEOVERVIEW_SPYKILLED");
    elseif mission.EscapeResult == EspionageResultTypes.CAPTURED then
      -- Failure and captured
      outcomeDetails.Success = false;
      outcomeDetails.Description = Locale.Lookup("LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_FAILURE_DETECTED_CAPTURED", Locale.Lookup(mission.CityName));
      outcomeDetails.SpyStatus = Locale.ToUpper("LOC_ESPIONAGEOVERVIEW_SPYCAUGHT");
    end
  elseif mission.InitialResult == EspionageResultTypes.KILLED then
    -- Killed
    outcomeDetails.Success = false;
    outcomeDetails.Description = Locale.Lookup("LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_KILLED", Locale.Lookup(mission.CityName));
    outcomeDetails.SpyStatus = Locale.ToUpper("LOC_ESPIONAGEOVERVIEW_SPYKILLED");
  elseif mission.InitialResult == EspionageResultTypes.CAPTURED then
    -- Captured
    outcomeDetails.Success = false;
    outcomeDetails.Description = Locale.Lookup("LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_CAPTURED", Locale.Lookup(mission.CityName));
    outcomeDetails.SpyStatus = Locale.ToUpper("LOC_ESPIONAGEOVERVIEW_SPYCAUGHT");
  end

  return outcomeDetails;
end

-- ===========================================================================
function GetMissionLootString(mission:table)
  local lootString:string = "";

  local operationInfo:table = GameInfo.UnitOperations[mission.Operation];
  if operationInfo.Hash == UnitOperationTypes.SPY_STEAL_TECH_BOOST then
    local techInfo:table = GameInfo.Technologies[mission.LootInfo];
    lootString = Locale.Lookup(techInfo.Name);
  elseif operationInfo.Hash == UnitOperationTypes.SPY_GREAT_WORK_HEIST then
    local greatWorkType:number = Game.GetGreatWorkTypeFromIndex(mission.LootInfo);
    local greatWorkInfo:table = GameInfo.GreatWorks[greatWorkType];
    lootString = Locale.Lookup(greatWorkInfo.Name);
  elseif operationInfo.Hash == UnitOperationTypes.SPY_SIPHON_FUNDS then
    lootString = Locale.Lookup("LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_GOLD", mission.LootInfo);
  end

  return lootString;
end

function hasDistrict(city:table, districtType:string)
  local hasDistrict:boolean = false;
  local cityDistricts:table = city:GetDistricts();
  for i, district in cityDistricts:Members() do
    if district:IsComplete() and not district:IsPillaged() then --ARISTOS: to only show available and valid targets in each city, both for espionage overview and selector
      --gets the district type of the currently selected district
      local districtInfo:table = GameInfo.Districts[district:GetType()];
      local currentDistrictType = districtInfo.DistrictType

      --assigns currentDistrictType to be the general type of district (i.e. DISTRICT_HANSA becomes DISTRICT_INDUSTRIAL_ZONE)
      local replaces = GameInfo.DistrictReplaces[districtInfo.Hash];
      if replaces then
        currentDistrictType = GameInfo.Districts[replaces.ReplacesDistrictType].DistrictType
      end

      if currentDistrictType == districtType then
        return true
      end
    end
  end

  return false
end
