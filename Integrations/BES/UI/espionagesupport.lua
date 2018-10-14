-- ===========================================================================
function GetFormattedOperationDetailText(operation:table, spy:table, city:table)
  local outputString:string = "";
  local eOperation:number = GameInfo.UnitOperations[operation.Hash].Index;
  local sOperationDetails:string = UnitManager.GetOperationDetailText(eOperation, spy, Map.GetPlot(city:GetX(), city:GetY()));
  if operation.OperationType == "UNITOPERATION_SPY_GREAT_WORK_HEIST" then
    outputString = Locale.Lookup("LOC_SPYMISSIONDETAILS_UNITOPERATION_SPY_GREAT_WORK_HEIST", sOperationDetails);
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
function GetMissionDescriptionString(mission:table, noloot:string, withloot:string)
  if mission.LootInfo >= 0 then
    return Locale.Lookup(withloot, GetMissionLootString(mission), mission.CityName);
  end

  return Locale.Lookup(noloot, mission.CityName);
end

-- ===========================================================================
function GetMissionOutcomeDetails(mission:table)
  local outcomeDetails:table = {};
  if mission.InitialResult == EspionageResultTypes.SUCCESS_UNDETECTED then
    -- Success and undetected
    outcomeDetails.Success = true;
    outcomeDetails.Description = GetMissionDescriptionString(mission, "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_SUCCESS_UNDETECTED", "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_SUCCESS_UNDETECTED_STOLELOOT");
    outcomeDetails.SpyStatus = "";
  elseif mission.InitialResult == EspionageResultTypes.SUCCESS_MUST_ESCAPE then
    -- Success but detected
    if mission.EscapeResult == EspionageResultTypes.FAIL_MUST_ESCAPE then
      -- Success and escaped
      outcomeDetails.Success = true;
      outcomeDetails.Description = GetMissionDescriptionString(mission, "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_SUCCESS_DETECTED_ESCAPED", "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_SUCCESS_DETECTED_STOLELOOT");
      outcomeDetails.SpyStatus = "";
    elseif mission.EscapeResult == EspionageResultTypes.KILLED then
      -- Success and killed
      outcomeDetails.Success = false;
      outcomeDetails.Description = GetMissionDescriptionString(mission, "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_SUCCESS_DETECTED_KILLED", "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_SUCCESS_DETECTED_KILLED_STOLELOOT");
      outcomeDetails.SpyStatus = Locale.ToUpper("LOC_ESPIONAGEOVERVIEW_SPYKILLED");
    elseif mission.EscapeResult == EspionageResultTypes.CAPTURED then
      -- Success and captured
      outcomeDetails.Success = false;
      outcomeDetails.Description = GetMissionDescriptionString(mission, "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_SUCCESS_DETECTED_CAPTURED", "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_SUCCESS_DETECTED_CAPTURED_STOLELOOT");
      outcomeDetails.SpyStatus = Locale.ToUpper("LOC_ESPIONAGEOVERVIEW_SPYCAUGHT");
    end
  elseif mission.InitialResult == EspionageResultTypes.FAIL_UNDETECTED then
    -- Failure but undetected
    outcomeDetails.Success = false;
    outcomeDetails.Description = GetMissionDescriptionString(mission, "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_FAILURE_UNDETECTED", "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_FAILURE_UNDETECTED_STOLELOOT");
    outcomeDetails.SpyStatus = "";
  elseif mission.InitialResult == EspionageResultTypes.FAIL_MUST_ESCAPE then
    -- Failure and detected
    if mission.EscapeResult == EspionageResultTypes.FAIL_MUST_ESCAPE then
      -- Failure and escaped
      outcomeDetails.Success = false;
      outcomeDetails.Description = GetMissionDescriptionString(mission, "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_FAILURE_DETECTED_ESCAPED", "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_FAILURE_DETECTED_ESCAPED_STOLELOOT");
      outcomeDetails.SpyStatus = "";
    elseif mission.EscapeResult == EspionageResultTypes.KILLED then
      -- Failure and killed
      outcomeDetails.Success = false;
      outcomeDetails.Description = GetMissionDescriptionString(mission, "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_FAILURE_DETECTED_KILLED", "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_FAILURE_DETECTED_KILLED_STOLELOOT");
      outcomeDetails.SpyStatus = Locale.ToUpper("LOC_ESPIONAGEOVERVIEW_SPYKILLED");
    elseif mission.EscapeResult == EspionageResultTypes.CAPTURED then
      -- Failure and captured
      outcomeDetails.Success = false;
      outcomeDetails.Description = GetMissionDescriptionString(mission, "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_FAILURE_DETECTED_CAPTURED", "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_FAILURE_DETECTED_CAPTURED_STOLELOOT");
      outcomeDetails.SpyStatus = Locale.ToUpper("LOC_ESPIONAGEOVERVIEW_SPYCAUGHT");
    end
  elseif mission.InitialResult == EspionageResultTypes.KILLED then
    -- Killed
    outcomeDetails.Success = false;
    outcomeDetails.Description = GetMissionDescriptionString(mission, "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_KILLED", "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_KILLED_STOLELOOT");
    outcomeDetails.SpyStatus = Locale.ToUpper("LOC_ESPIONAGEOVERVIEW_SPYKILLED");
  elseif mission.InitialResult == EspionageResultTypes.CAPTURED then
    -- Captured
    outcomeDetails.Success = false;
    outcomeDetails.Description = GetMissionDescriptionString(mission, "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_CAPTURED", "LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_CAPTURED_STOLELOOT");
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
    lootString = techInfo.Name;
  elseif operationInfo.Hash == UnitOperationTypes.SPY_GREAT_WORK_HEIST then
    local greatWorkType:number = Game.GetGreatWorkTypeFromIndex(mission.LootInfo);
    local greatWorkInfo:table = GameInfo.GreatWorks[greatWorkType];
    lootString = greatWorkInfo.Name;
  elseif operationInfo.Hash == UnitOperationTypes.SPY_SIPHON_FUNDS then
    if mission.LootInfo == 0 then
      lootString = Locale.Lookup("LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_NO_GOLD");
    else
      lootString = Locale.Lookup("LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME_GOLD", mission.LootInfo);
    end
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
