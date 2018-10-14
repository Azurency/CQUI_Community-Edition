-- ===========================================================================
--  Unit Panel Screen
-- ===========================================================================
include( "InstanceManager" );
include( "SupportFunctions" );
include( "Colors" );
include( "CombatInfo" );
include( "PopupDialog" );
include( "Civ6Common" );
include( "EspionageSupport" );


-- ===========================================================================
--  CONSTANTS
-- ===========================================================================
local ANIMATION_SPEED       :number = 2;
local SECONDARY_ACTIONS_ART_PADDING :number = -4;
local MAX_BEFORE_TRUNC_STAT_NAME  :number = 170;


--CQUI Members
local CQUI_ShowImprovementsRecommendations :boolean = false;
function CQUI_OnSettingsUpdate()
  CQUI_ShowImprovementsRecommendations = GameConfiguration.GetValue("CQUI_ShowImprovementsRecommendations") == 1
end
LuaEvents.CQUI_SettingsUpdate.Add(CQUI_OnSettingsUpdate);
LuaEvents.CQUI_SettingsInitialized.Add(CQUI_OnSettingsUpdate);

-- ===========================================================================
--  MEMBERS / VARIABLES
-- ===========================================================================

hstructure DisabledByTutorial
  kLockedHashes : table;    -- Action hashes that the tutorial says shouldn't be enabled.
end


local m_standardActionsIM   :table  = InstanceManager:new( "UnitActionInstance",      "UnitActionButton",   Controls.StandardActionsStack );
local m_secondaryActionsIM    :table  = InstanceManager:new( "UnitActionInstance",      "UnitActionButton",   Controls.SecondaryActionsStack );
local m_groupArtIM        :table  = InstanceManager:new( "GroupArtInstance",        "Top",          Controls.PrimaryArtStack );
local m_buildActionsIM      :table  = InstanceManager:new( "BuildActionsColumnInstance",  "Top",          Controls.BuildActionsStack );
local m_earnedPromotionIM   :table  = InstanceManager:new( "EarnedPromotionInstance",   "Top",          Controls.EarnedPromotionsStack);
local m_PromotionListInstanceMgr:table  = InstanceManager:new( "PromotionSelectionInstance",  "PromotionSelection", Controls.PromotionList );
local m_subjectModifierIM   :table  = InstanceManager:new( "ModifierInstance",  "ModifierContainer",  Controls.SubjectModifierStack );
local m_targetModifierIM    :table  = InstanceManager:new( "ModifierInstance",  "ModifierContainer",  Controls.TargetModifierStack );
local m_interceptorModifierIM :table  = InstanceManager:new( "ModifierInstance",  "ModifierContainer",  Controls.InterceptorModifierStack );
local m_antiAirModifierIM   :table  = InstanceManager:new( "ModifierInstance",  "ModifierContainer",  Controls.AntiAirModifierStack );

local m_subjectStatStackIM    :table  = InstanceManager:new( "StatInstance",      "StatGrid",   Controls.SubjectStatStack );
local m_targetStatStackIM   :table  = InstanceManager:new( "TargetStatInstance",  "StatGrid",   Controls.TargetStatStack );

local m_combatResults     :table = nil;
local m_currentIconGroup    :table = nil;       --  Tracks the current icon group as they are built.
local m_isOkayToProcess     :boolean= true;
local m_selectedPlayerId    :number = -1;
local m_primaryColor      :number = 0xdeadbeef;
local m_secondaryColor      :number = 0xbaadf00d;
local m_UnitId          :number = -1;
local m_numIconsInCurrentIconGroup :number = 0;
local m_bestValidImprovement  :number = -1;
local m_kHotkeyActions      :table = {};
local m_kHotkeyCV1        :table = {};
local m_kHotkeyCV2        :table = {};
local m_kSoundCV1               :table = {};
local m_kTutorialDisabled   :table = {};  -- key = Unit Type, value = lockedHashes
local m_kTutorialAllDisabled  :table = {};  -- hashes of actions disabled for all units

local m_DeleteInProgress        :boolean = false;

local m_attackerUnit = nil;
local m_locX = nil;
local m_locY = nil;

local INVALID_PLOT_ID :number = -1;
local m_plotId      :number = INVALID_PLOT_ID;

local m_airAttackTargetPlots	:table = nil; 
local m_targetData        :table;
local m_subjectData       :table;

-- Defines the number of modifiers displayed per page in the combat preview
local m_maxModifiersPerPage   :number = 5;

-- Defines the minimum unit panel size and resize padding used when resizing unit panel to fit action buttons
local m_minUnitPanelWidth   :number = 340;
local m_resizeUnitPanelPadding  :number = 18;

local pSpyInfo = GameInfo.Units["UNIT_SPY"];

local m_AttackHotkeyId      = Input.GetActionId("Attack");
local m_DeleteHotkeyId      = Input.GetActionId("DeleteUnit");

-- ===========================================================================
--  FUNCTIONS
-- ===========================================================================

function InitSubjectData()
  m_subjectData =
  {
    Name            = "",
    Moves           = 0,
    InFormation         = 0,
    FormationMoves        = 0,
    FormationMaxMoves     = 0,
    MaxMoves          = 0,
    Combat            = 0,
    Damage            = 0,
    MaxDamage         = 0,
    PotentialDamage       = 0,
    WallDamage          = 0,
    MaxWallDamage       = 0,
    PotentialWallDamage     = 0,
    RangedCombat        = 0,
    BombardCombat       = 0,
    AntiAirCombat       = 0,
    Range           = 0,
    Owner           = 0,
    BuildCharges        = 0,
    SpreadCharges       = 0,
    HealCharges = 0,
    GreatPersonActionCharges  = 0,
    GreatPersonPassiveName    = "",
    GreatPersonPassiveText    = "",
    ReligiousStrength     = 0,
    HasMovedIntoZOC       = 0,
    MilitaryFormation     = 0,
    UnitType                    = -1,
    UnitID            = 0,
    UnitExperience        = 0,
    MaxExperience       = 0,
    UnitLevel         = 0,
    CurrentPromotions     = {},
    Actions           = {},
    IsSpy           = false,
    SpyOperation        = -1,
    SpyTargetOwnerID      = -1,
    SpyTargetCityName     = "",
    SpyRemainingTurns     = 0,
    SpyTotalTurns       = 0,
    StatData          = nil,
    IsTradeUnit         = false,
    TradeRouteName        = "",
    TradeRouteIcon        = "",
    TradeLandRange        = 0,
    TradeSeaRange       = 0,
    IsSettler         = false;
  };
end

function InitTargetData()
  m_targetData =
  {
    Name            = "",
    Combat            = 0,
    RangedCombat        = 0,
    BombardCombat       = 0,
    ReligiousCombat       = 0,
    Range           = 0,
    Damage            = 0,
    MaxDamage         = 0,
    PotentialDamage       = 0,
    WallDamage          = 0,
    MaxWallDamage       = 0,
    PotentialWallDamage     = 0,
    BuildCharges        = 0,
    SpreadCharges       = 0,
    HealCharges = 0,
    ReligiousStrength     = 0,
    GreatPersonActionCharges  = 0,
    Moves           = 0,
    MaxMoves          = 0,
    InterceptorName       = "",
    InterceptorCombat     = 0,
    InterceptorDamage     = 0,
    InterceptorMaxDamage    = 0,
    InterceptorPotentialDamage  = 0,
    AntiAirName         = "",
    AntiAirCombat       = 0,
    StatData          = nil,
    UnitType                    = -1,
    UnitID            = 0,
    HasDefenses					= false, --Tells is whether we need to display combat data
    HasImprovementOrDistrict	= false -- Only used if the tile does not have defenses
  };
end

-- ===========================================================================
--  An action icon which will shows up immediately above the unit panel
-- ===========================================================================
function AddActionButton( instance:table, action:table )

  instance.UnitActionIcon:SetIcon(action.IconId);
  instance.UnitActionButton:SetDisabled( action.Disabled );
  instance.UnitActionButton:SetAlpha( (action.Disabled and 0.7) or 1 );
  instance.UnitActionButton:SetToolTipString( action.helpString );
  instance.UnitActionButton:RegisterCallback( Mouse.eLClick,
    function(void1,void2)
      if action.Sound ~= nil and action.Sound ~= "" then
        UI.PlaySound(action.Sound);
      end
      action.CallbackFunc(void1,void2);
    end
  );
  instance.UnitActionButton:SetVoid1( action.CallbackVoid1 );
  instance.UnitActionButton:SetVoid2( action.CallbackVoid2 );
  instance.UnitActionButton:SetTag( action.userTag );
    instance.UnitActionButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

  -- Track # of icons added for whatever is the current group
  m_numIconsInCurrentIconGroup = m_numIconsInCurrentIconGroup + 1;
end

-- ===========================================================================
function GetHashFromType( actionType:string )
  local hash:number = 0;
  if GameInfo.UnitCommands[actionType] ~= nil then
    hash = GameInfo.UnitCommands[actionType].Hash;
  elseif GameInfo.UnitOperations[actionType] ~= nil then
    hash = GameInfo.UnitOperations[actionType].Hash;
  end
  return hash;
end

-- ===========================================================================
--  RETURNS true if tutorial is disabling this action.
-- ===========================================================================
function IsDisabledByTutorial( unitType:string, actionHash:number )

  -- Any type of unit
  for i,action in ipairs( m_kTutorialAllDisabled ) do
    hash = GetHashFromType(action);
    if actionHash == hash and hash ~= 0 then
      return true;
    end
  end

  -- Specific to a unit
  if m_kTutorialDisabled[unitType] ~= nil then
    -- In mode where all are enabled except for specific list
    for i,hash in ipairs( m_kTutorialDisabled[unitType].kLockedHashes ) do
      if actionHash == hash then
        return true;
      end
    end
  end

  return false;
end

-- ===========================================================================
--  Add an action for the UI to display.
--  actionsTable  Table holding actions via categories
--  action      A command or operation
--  disabled    Is the action disabled (tutorial may disable even if enabled)
--  toolTipString What the action does
--  actionHash    The hash of the action.
-- ===========================================================================
function AddActionToTable( actionsTable:table, action:table, disabled:boolean, toolTipString:string, actionHash:number, callbackFunc:ifunction, callbackVoid1, callbackVoid2, overrideIcon:string)
  local actionsCategoryTable:table;
  if ( actionsTable[action.CategoryInUI] ~= nil ) then
    actionsCategoryTable = actionsTable[action.CategoryInUI];
  else
    UI.DataError("Operation is in unsupported action category '" .. tostring(action.CategoryInUI) .. "'.");
    actionsCategoryTable = actionsTable["SPECIFIC"];
  end

  -- Wrap every callback function with a call that guarantees the interface
  -- mode is reset.  It prevents issues such as selecting range attack and
  -- then instead of attacking, choosing another action, which would leave
  -- up the range attack lens layer.
  local wrappedCallback:ifunction =
    function(void1,void2)
      currentMode = UI.GetInterfaceMode();
      if currentMode ~= InterfaceModeTypes.SELECTION then
        print_debug("Unit panel forcing interface mode back to selection before performing operation/action"); --Debug
        UI.SetInterfaceMode( InterfaceModeTypes.SELECTION );
      end
      callbackFunc(void1, void2, currentMode);
    end;

  table.insert( actionsCategoryTable, {
    IconId        = (overrideIcon and overrideIcon) or action.Icon,
    Disabled      = disabled,
    helpString      = toolTipString,
    userTag       = actionHash,
    CallbackFunc    = wrappedCallback,
    CallbackVoid1   = callbackVoid1,
    CallbackVoid2   = callbackVoid2,
    IsBestImprovement = action.IsBestImprovement,
    Sound       = action.Sound
    });

  -- Hotkey support
  if (action.HotkeyId~=nil) and disabled==false then
    local actionId = Input.GetActionId( action.HotkeyId );
    if actionId ~= nil then
      m_kHotkeyActions[actionId] = callbackFunc;
      m_kHotkeyCV1[actionId] = callbackVoid1;
      m_kHotkeyCV2[actionId] = callbackVoid2;
            m_kSoundCV1[actionId] = action.Sound;
    else
      UI.DataError("Cannot set hotkey on Unitpanel for action with icon '"..action.IconId.."' because engine doesn't have actionId of '"..action.HotkeyId.."'.");
    end
  end
end


-- ===========================================================================
--  Refresh unit actions
--  Returns a table of unit actions.
-- ===========================================================================
function GetUnitActionsTable( pUnit )

  -- Build action table; holds sub-tables of commands & operations based on UI categories set in DB.
  -- Also defines order actions show in panel.
  local actionsTable  = {
    ATTACK      = {},
    BUILD     = {},
    GAMEMODIFY    = {},
    MOVE      = {},
    OFFENSIVESPY  = {},
    INPLACE     = {},
    SECONDARY   = {},
    SPECIFIC    = {},
    displayOrder = {
      primaryArea = {"ATTACK","OFFENSIVESPY","SPECIFIC","MOVE","INPLACE","GAMEMODIFY"}, -- How they appear in the UI
      secondaryArea = {"SECONDARY"}
    }
  };

  m_bestValidImprovement = -1;

  if pUnit == nil then
    UI.DataError("NIL unit when attempting to get action table.");
    return;
  end

  local unitType :string = GameInfo.Units[pUnit:GetUnitType()].UnitType;

    for commandRow in GameInfo.UnitCommands() do
    if ( commandRow.VisibleInUI ) then
      local actionHash  :number   = commandRow.Hash;
      local isDisabled  :boolean  = IsDisabledByTutorial(unitType, actionHash );

      if (actionHash == UnitCommandTypes.ENTER_FORMATION) then
        --Check if there are any units in the same tile that this unit can create a formation with
        --Call CanStartCommand asking for results
        local bCanStart, tResults = UnitManager.CanStartCommand( pUnit, actionHash, nil, true);
        if (bCanStart and tResults) then
          if (tResults[UnitCommandResults.UNITS] ~= nil and #tResults[UnitCommandResults.UNITS] ~= 0) then
            local tUnits = tResults[UnitCommandResults.UNITS];
            for i, unit in ipairs(tUnits) do
              local pUnitInstance = Players[unit.player]:GetUnits():FindID(unit.id);
              if (pUnitInstance ~= nil) then

                local toolTipString :string   = Locale.Lookup(commandRow.Description, GameInfo.Units[pUnitInstance:GetUnitType()].Name);
                local callback    :ifunction  = function() OnUnitActionClicked_EnterFormation(pUnitInstance) end

                AddActionToTable( actionsTable, commandRow, isDisabled, toolTipString, actionHash, callback );
              end
            end
          end
        end
      elseif (actionHash == UnitCommandTypes.PROMOTE) then
        --Call CanStartCommand asking for a list of possible promotions for that unit
        local bCanStart, tResults = UnitManager.CanStartCommand( pUnit, actionHash, true, true);
        if (bCanStart and tResults) then
          if (tResults[UnitCommandResults.PROMOTIONS] ~= nil and #tResults[UnitCommandResults.PROMOTIONS] ~= 0) then
            local tPromotions   = tResults[UnitCommandResults.PROMOTIONS];
            local toolTipString   = Locale.Lookup(commandRow.Description);
            local callback      = function() ShowPromotionsList(tPromotions); end

            AddActionToTable( actionsTable, commandRow, isDisabled, toolTipString, actionHash, callback );
          end
        end
      elseif (actionHash == UnitCommandTypes.NAME_UNIT) then
        local bCanStart = UnitManager.CanStartCommand( pUnit, UnitCommandTypes.NAME_UNIT, true) and GameCapabilities.HasCapability("CAPABILITY_RENAME");
        if (bCanStart) then
          local toolTipString = Locale.Lookup(commandRow.Description);
          AddActionToTable( actionsTable, commandRow, isDisabled, toolTipString, actionHash, OnNameUnit );
        end
      elseif (actionHash == UnitCommandTypes.DELETE) then
        local bCanStart = UnitManager.CanStartCommand( pUnit, UnitCommandTypes.DELETE, true);
        if (bCanStart) then
          local toolTipString = Locale.Lookup(commandRow.Description);
          AddActionToTable( actionsTable, commandRow, isDisabled, toolTipString, actionHash, OnPromptToDeleteUnit );
        end
      elseif (actionHash == UnitCommandTypes.CANCEL and GameInfo.Units[unitType].Spy) then
        -- Route the cancel action for spies to the espionage popup for cancelling a mission
        local bCanStart = UnitManager.CanStartCommand( pUnit, actionHash, true);
        if (bCanStart) then
          local bCanStartNow, tResults = UnitManager.CanStartCommand( pUnit, actionHash, false, true);
          AddActionToTable( actionsTable, commandRow, isDisabled, Locale.Lookup("LOC_UNITPANEL_ESPIONAGE_CANCEL_MISSION"), actionHash, OnUnitActionClicked_CancelSpyMission, UnitCommandTypes.TYPE, actionHash  );
        end
      else
        -- The UI check of an operation is a loose check where it only fails if the unit could never do the command.
        local bCanStart = UnitManager.CanStartCommand( pUnit, actionHash, true);
        if (bCanStart) then
          -- Check again if the operation can occur, this time for real.
          local bCanStartNow, tResults = UnitManager.CanStartCommand( pUnit, actionHash, false, true);
          local bDisabled = not bCanStartNow;
          local toolTipString:string;
          if (actionHash == UnitCommandTypes.UPGRADE) then
            -- if it's a unit upgrade action, add the unit it will upgrade to in the tooltip as well as the upgrade cost
            if (tResults ~= nil) then
              if (tResults[UnitCommandResults.UNIT_TYPE] ~= nil) then
                local upgradeUnitName = GameInfo.Units[tResults[UnitCommandResults.UNIT_TYPE]].Name;
                toolTipString = Locale.Lookup(upgradeUnitName);
                local upgradeCost = pUnit:GetUpgradeCost();
                if (upgradeCost ~= nil) then
                  toolTipString = toolTipString .. ": " .. upgradeCost .. " " .. Locale.Lookup("LOC_TOP_PANEL_GOLD");
                end
                toolTipString = Locale.Lookup("LOC_UNITOPERATION_UPGRADE_INFO", upgradeUnitName, upgradeCost);
              end
            end
          elseif (actionHash == UnitCommandTypes.FORM_CORPS) then
            if (GameInfo.Units[unitType].Domain == "DOMAIN_SEA") then
              toolTipString = Locale.Lookup("LOC_UNITCOMMAND_FORM_FLEET_DESCRIPTION");
            else
              toolTipString = Locale.Lookup(commandRow.Description);
            end
          elseif (actionHash == UnitCommandTypes.FORM_ARMY) then
            if (GameInfo.Units[unitType].Domain == "DOMAIN_SEA") then
              toolTipString = Locale.Lookup("LOC_UNITCOMMAND_FORM_ARMADA_DESCRIPTION");
            else
              toolTipString = Locale.Lookup(commandRow.Description);
            end
          else
            toolTipString = Locale.Lookup(commandRow.Description);
          end
          if (tResults ~= nil) then
            if (tResults[UnitOperationResults.ACTION_NAME] ~= nil and tResults[UnitOperationResults.ACTION_NAME] ~= "") then
              toolTipString = Locale.Lookup(tResults[UnitOperationResults.ACTION_NAME]);
            end

            if (tResults[UnitOperationResults.ADDITIONAL_DESCRIPTION] ~= nil) then
              for i,v in ipairs(tResults[UnitOperationResults.ADDITIONAL_DESCRIPTION]) do
                toolTipString = toolTipString .. "[NEWLINE]" .. Locale.Lookup(v);
              end
            end

            -- Are there any failure reasons?
            if ( bDisabled ) then
              if (tResults[UnitOperationResults.FAILURE_REASONS] ~= nil) then
                -- Add the reason(s) to the tool tip
                for i,v in ipairs(tResults[UnitOperationResults.FAILURE_REASONS]) do
                  toolTipString = toolTipString .. "[NEWLINE]" .. "[COLOR:Red]" .. Locale.Lookup(v) .. "[ENDCOLOR]";
                end
              end
            end
          end
          isDisabled = bDisabled or isDisabled; -- Mix in tutorial disabledness
          AddActionToTable( actionsTable, commandRow, isDisabled, toolTipString, actionHash, OnUnitActionClicked, UnitCommandTypes.TYPE, actionHash  );
        end
      end
    end
  end


  -- Loop over the UnitOperations (like commands but may take 1 to N turns to complete)

  -- Only show the operations if the unit has moves left.
    local isHasMovesLeft = pUnit:GetMovesRemaining() > 0;
  if isHasMovesLeft then

    for operationRow in GameInfo.UnitOperations() do

      local actionHash  :number = operationRow.Hash;
      local isDisabled  :boolean= IsDisabledByTutorial( unitType, actionHash );

      local instance;

      -- if unit can build an improvement, show all the buildable improvements for that tile
      if (actionHash == UnitOperationTypes.BUILD_IMPROVEMENT) then
        local tParameters = {};
        tParameters[UnitOperationTypes.PARAM_X] = pUnit:GetX();
        tParameters[UnitOperationTypes.PARAM_Y] = pUnit:GetY();

        --Call CanStartOperation asking for results
        local bCanStart, tResults = UnitManager.CanStartOperation( pUnit, UnitOperationTypes.BUILD_IMPROVEMENT, nil, tParameters, true);

        if (bCanStart and tResults ~= nil) then
          if (tResults[UnitOperationResults.IMPROVEMENTS] ~= nil and #tResults[UnitOperationResults.IMPROVEMENTS] ~= 0) then

            m_bestValidImprovement = tResults[UnitOperationResults.BEST_IMPROVEMENT];

            local tImprovements = tResults[UnitOperationResults.IMPROVEMENTS];
            for i, eImprovement in ipairs(tImprovements) do

              tParameters[UnitOperationTypes.PARAM_IMPROVEMENT_TYPE] = eImprovement;

              local improvement   = GameInfo.Improvements[eImprovement];

              bCanStart, tResults = UnitManager.CanStartOperation(pUnit, actionHash, nil, tParameters, true);
              local isDisabled    = not bCanStart;
              local toolTipString   = Locale.Lookup(operationRow.Description) .. ": " .. Locale.Lookup(improvement.Name);

              if tResults ~= nil then

                if (tResults[UnitOperationResults.ADDITIONAL_DESCRIPTION] ~= nil) then
                  for i,v in ipairs(tResults[UnitOperationResults.ADDITIONAL_DESCRIPTION]) do
                    toolTipString = toolTipString .. "[NEWLINE]" .. Locale.Lookup(v);
                  end
                end

                -- Are there any failure reasons?
                if isDisabled then
                  if (tResults[UnitOperationResults.FAILURE_REASONS] ~= nil) then
                    -- Add the reason(s) to the tool tip
                    for i,v in ipairs(tResults[UnitOperationResults.FAILURE_REASONS]) do
                      toolTipString = toolTipString .. "[NEWLINE]" .. "[COLOR:Red]" .. Locale.Lookup(v) .. "[ENDCOLOR]";
                    end
                  end
                end
              end

              -- If this improvement is the same enum as what the game marked as "the best" for this plot, set this flag for the UI to use.
              if ( m_bestValidImprovement ~= -1 and m_bestValidImprovement == eImprovement ) then
                improvement["IsBestImprovement"] = true;
              else
                improvement["IsBestImprovement"] = false;
              end

              improvement["CategoryInUI"] = "BUILD";  -- TODO: Force improvement to be a type of "BUILD", this can be removed if CategoryInUI is added to "Improvements" in the database schema. ??TRON
              AddActionToTable( actionsTable, improvement, isDisabled, toolTipString, actionHash, OnUnitActionClicked_BuildImprovement, improvement.Hash );
            end
          end
        end
      elseif (actionHash == UnitOperationTypes.MOVE_TO) then
        local bCanStart   :boolean= UnitManager.CanStartOperation( pUnit,  UnitOperationTypes.MOVE_TO, nil, false, false);  -- No exclusion test, no results
        if (bCanStart) then
          local toolTipString :string = Locale.Lookup(operationRow.Description);
          AddActionToTable( actionsTable, operationRow, isDisabled, toolTipString, actionHash, OnUnitActionClicked_MoveTo );
        end
      elseif (operationRow.CategoryInUI == "OFFENSIVESPY") then
        local bCanStart   :boolean= UnitManager.CanStartOperation( pUnit, actionHash, nil, false, false); -- No exclusion test, no result
        if (bCanStart) then
          ---- We only want a single offensive spy action which opens the EspionageChooser side panel
          if actionsTable[operationRow.CategoryInUI] ~= nil and table.count(actionsTable[operationRow.CategoryInUI]) == 0 then
            local toolTipString :string = Locale.Lookup("LOC_UNITPANEL_ESPIONAGE_CHOOSE_MISSION");
            AddActionToTable( actionsTable, operationRow, isDisabled, toolTipString, actionHash, OnUnitActionClicked, UnitOperationTypes.TYPE, actionHash, "ICON_UNITOPERATION_SPY_MISSIONCHOOSER");
          end
        end
      elseif (actionHash == UnitOperationTypes.SPY_COUNTERSPY) then
        local bCanStart, tResults = UnitManager.CanStartOperation( pUnit, actionHash, nil, true );
        if (bCanStart) then
          local toolTipString = Locale.Lookup(operationRow.Description);
          AddActionToTable( actionsTable, operationRow, isDisabled, toolTipString, actionHash, OnUnitActionClicked, UnitOperationTypes.TYPE, actionHash, "ICON_UNITOPERATION_SPY_COUNTERSPY_ACTION");
        end
      elseif (actionHash == UnitOperationTypes.FOUND_CITY) then
        local bCanStart   :boolean= UnitManager.CanStartOperation( pUnit,  UnitOperationTypes.FOUND_CITY, nil, false, false); -- No exclusion test, no results
        if (bCanStart) then
          local toolTipString :string = Locale.Lookup(operationRow.Description);
          AddActionToTable( actionsTable, operationRow, isDisabled, toolTipString, actionHash, OnUnitActionClicked_FoundCity );
        end
      elseif (actionHash == UnitOperationTypes.WMD_STRIKE) then
        -- if unit can deploy a WMD, create a unit action for each type
        -- first check if the unit is capable of deploying a WMD
        local bCanStart = UnitManager.CanStartOperation( pUnit, UnitOperationTypes.WMD_STRIKE, nil, true);
        if (bCanStart) then
          for entry in GameInfo.WMDs() do
            local tParameters = {};
            tParameters[UnitOperationTypes.PARAM_WMD_TYPE] = entry.Index;
            bCanStart, tResults = UnitManager.CanStartOperation(pUnit, actionHash, nil, tParameters, true);
            local isWMDTypeDisabled:boolean = (not bCanStart) or isDisabled;
            local toolTipString :string = Locale.Lookup(operationRow.Description);
            local wmd = entry.Index;
            toolTipString = toolTipString .. "[NEWLINE]" .. Locale.Lookup(entry.Name);
            local callBack = function() OnUnitActionClicked_WMDStrike(wmd); end

            -- Are there any failure reasons?
            if ( not bCanStart ) then
              if tResults ~= nil and (tResults[UnitOperationResults.FAILURE_REASONS] ~= nil) then
                -- Add the reason(s) to the tool tip
                for i,v in ipairs(tResults[UnitOperationResults.FAILURE_REASONS]) do
                  toolTipString = toolTipString .. "[NEWLINE]" .. "[COLOR:Red]" .. Locale.Lookup(v) .. "[ENDCOLOR]";
                end
              end
            end

            AddActionToTable( actionsTable, operationRow, isWMDTypeDisabled, toolTipString, actionHash, callBack );
          end
        end
      else
        -- Is this operation visible in the UI?
        -- The UI check of an operation is a loose check where it only fails if the unit could never do the operation.
        if ( operationRow.VisibleInUI ) then
          local bCanStart, tResults = UnitManager.CanStartOperation( pUnit, actionHash, nil, true );

          if (bCanStart) then
            -- Check again if the operation can occur, this time for real.
            bCanStart, tResults = UnitManager.CanStartOperation(pUnit, actionHash, nil, false, OperationResultsTypes.NO_TARGETS);		-- Hint that we don't require possibly expensive target results. 
            local bDisabled = not bCanStart;
            local toolTipString = Locale.Lookup(operationRow.Description);

            if (tResults ~= nil) then
              if (tResults[UnitOperationResults.ACTION_NAME] ~= nil and tResults[UnitOperationResults.ACTION_NAME] ~= "") then
                toolTipString = Locale.Lookup(tResults[UnitOperationResults.ACTION_NAME]);
              end

              if (tResults[UnitOperationResults.FEATURE_TYPE] ~= nil) then
                local featureName = GameInfo.Features[tResults[UnitOperationResults.FEATURE_TYPE]].Name;
                toolTipString = toolTipString .. ": " .. Locale.Lookup(featureName);
              end

              if (tResults[UnitOperationResults.ADDITIONAL_DESCRIPTION] ~= nil) then
                for i,v in ipairs(tResults[UnitOperationResults.ADDITIONAL_DESCRIPTION]) do
                  toolTipString = toolTipString .. "[NEWLINE]" .. Locale.Lookup(v);
                end
              end

              -- Are there any failure reasons?
              if ( bDisabled ) then
                if (tResults[UnitOperationResults.FAILURE_REASONS] ~= nil) then
                  -- Add the reason(s) to the tool tip
                  for i,v in ipairs(tResults[UnitOperationResults.FAILURE_REASONS]) do
                    toolTipString = toolTipString .. "[NEWLINE]" .. "[COLOR:Red]" .. Locale.Lookup(v) .. "[ENDCOLOR]";
                  end
                end
              end
            end
            isDisabled = bDisabled or isDisabled;
            AddActionToTable( actionsTable, operationRow, isDisabled, toolTipString, actionHash, OnUnitActionClicked, UnitOperationTypes.TYPE, actionHash  );
          end
        end
      end
    end
  end

  return actionsTable;
end

-- ===========================================================================
function StartIconGroup()
  if m_currentIconGroup ~= nil then
    UI.DataError("Starting an icon group but a prior one wasn't completed!");
  end
  m_currentIconGroup = m_groupArtIM:GetInstance();
  m_numIconsInCurrentIconGroup = 0;
end

-- ===========================================================================
function EndIconGroup()
  if m_currentIconGroup == nil then
    UI.DataError("Attempt to end an icon group, but their are no icons!");
    return;
  end

  local instance  :table = m_standardActionsIM:GetInstance();
  local width   :number = instance.UnitActionButton:GetSizeX();
  m_standardActionsIM:ReleaseInstance( instance );

  m_currentIconGroup.Top:SetSizeX( width * m_numIconsInCurrentIconGroup );

  m_currentIconGroup = nil;
  Controls.PrimaryArtStack:CalculateSize();
  Controls.PrimaryArtStack:ReprocessAnchoring();
end

-- ===========================================================================
function GetPercentFromDamage( damage:number, maxDamage:number )
  if damage > maxDamage then
    damage = maxDamage;
  end
  return (damage / maxDamage);
end


-- ===========================================================================
--  Set the health meter
-- ===========================================================================
function RealizeHealthMeter( control:table, percent:number, controlShadow:table, shadowPercent:number )
  if  ( percent > 0.7 ) then
    control:SetColor( COLORS.METER_HP_GOOD );
    controlShadow:SetColor( COLORS.METER_HP_GOOD_SHADOW );
  elseif ( percent > 0.4 )  then
    control:SetColor( COLORS.METER_HP_OK );
    controlShadow:SetColor( COLORS.METER_HP_OK_SHADOW );
  else
    control:SetColor( COLORS.METER_HP_BAD );
    controlShadow:SetColor( COLORS.METER_HP_BAD_SHADOW );
  end

  -- Meter control is half circle, so add enough to start at half point and condence % into the half area
  percent     = (percent * 0.5) + 0.5;
  shadowPercent = (shadowPercent * 0.5) + 0.5;

  control:SetPercent( percent );
  controlShadow:SetPercent( shadowPercent );
end

-- ===========================================================================
-- View(data)
-- Update the layout based on the view model
-- ===========================================================================
function View(data)

  -- TODO: Explore what (if anything) could be done with prior values so Reset can be utilized instead of destory; this would gain LUA side pooling
  m_buildActionsIM:DestroyInstances();
  m_standardActionsIM:ResetInstances();
  m_secondaryActionsIM:ResetInstances();
  m_groupArtIM:ResetInstances();
  m_buildActionsIM:ResetInstances();

  ---=======[ ACTIONS ]=======---

  HidePromotionPanel();

  -- Reset UnitPanelBaseContainer to minium size
  Controls.UnitPanelBaseContainer:SetSizeX(m_minUnitPanelWidth);

  -- First fill the primary area
  if (table.count(data.Actions) > 0) then
    for _,categoryName in ipairs(data.Actions.displayOrder.primaryArea) do
      local categoryTable = data.Actions[categoryName];
      if (categoryTable == nil ) then
        local allNames :string = "";
        for _,catName in ipairs(data.Actions) do allNames = allNames .. "'" .. catName .. "' "; end
        print("ERROR: Unit panel's primary actions sort reference '"..categoryName.."' but no table of that name.  Tables in actionsTable: " .. allNames);
        Controls.ForceAnAssertDueToAboveCondition();
      else
        StartIconGroup();
        for _,action in ipairs(categoryTable) do
          local instance:table = m_standardActionsIM:GetInstance();
          AddActionButton( instance, action );
        end
        EndIconGroup();
      end
    end


    -- Next fill in secondardy actions area
    local numSecondaryItems:number = 0;
    for _,categoryName in ipairs(data.Actions.displayOrder.secondaryArea) do
      local categoryTable = data.Actions[categoryName];
      if (categoryTable == nil ) then
        local allNames :string = "";
        for _,catName in ipairs(data.Actions) do allNames = allNames .. "'" .. catName .. "' "; end
        print("ERROR: Unit panel's secondary actions sort reference '"..categoryName.."' but no table of that name.  Tables in actionsTable: " .. allNames);
        Controls.ForceAnAssertDueToAboveCondition();
      else
        for _,action in ipairs(categoryTable) do
          local instance:table = m_secondaryActionsIM:GetInstance();
          AddActionButton( instance, action );
          numSecondaryItems = numSecondaryItems + 1;
        end
      end
    end

    Controls.ExpandSecondaryActionGrid:SetHide( numSecondaryItems <=0 );
  end

  -- Build panel options (if any)
  if ( data.Actions["BUILD"] ~= nil and #data.Actions["BUILD"] > 0 ) then

    Controls.BuildActionsPanel:SetHide(false);

    local bestBuildAction :table = nil;

    -- Create columns (each able to hold x3 icons) and fill them top to bottom
    local numBuildCommands = table.count(data.Actions["BUILD"]);
    for i=1,numBuildCommands,3 do
      local buildColumnInstance = m_buildActionsIM:GetInstance();
      for iRow=1,3,1 do
        if ( (i+iRow)-1 <= numBuildCommands ) then
          local slotName  = "Row"..tostring(iRow);
          local action  = data.Actions["BUILD"][(i+iRow)-1];
          local instance  = {};
          ContextPtr:BuildInstanceForControl( "BuildActionInstance", instance, buildColumnInstance[slotName]);

          instance.UnitActionIcon:SetTexture( IconManager:FindIconAtlas(action.IconId, 38) );

          instance.UnitActionButton:SetDisabled( action.Disabled );
          instance.UnitActionButton:SetAlpha( (action.Disabled and 0.4) or 1 );
          instance.UnitActionButton:SetToolTipString( action.helpString );
          instance.UnitActionButton:RegisterCallback( Mouse.eLClick, action.CallbackFunc );
          instance.UnitActionButton:SetVoid1( action.CallbackVoid1 );
          instance.UnitActionButton:SetVoid2( action.CallbackVoid2 );

          -- PLACEHOLDER, currently sets first non-disabled build command; change to best build command.
          if ( action.IsBestImprovement ~= nil and action.IsBestImprovement == true ) then
            bestBuildAction = action;
          end
        end
      end
    end

    local BUILD_PANEL_ART_PADDING_X = 24;
    local BUILD_PANEL_ART_PADDING_Y = 20;
    Controls.BuildActionsStack:CalculateSize();
    Controls.BuildActionsStack:ReprocessAnchoring();
    local buildStackWidth :number = Controls.BuildActionsStack:GetSizeX();
    local buildStackHeight :number = Controls.BuildActionsStack:GetSizeY();
    Controls.BuildActionsPanel:SetSizeX( buildStackWidth + BUILD_PANEL_ART_PADDING_X);
    Controls.RecommendedActionButton:ReprocessAnchoring();
    Controls.RecommendedActionIcon:ReprocessAnchoring();

    Controls.RecommendedActionFrame:SetHide( bestBuildAction == nil );
    if ( bestBuildAction ~= nil and CQUI_ShowImprovementsRecommendations) then -- CQUI : show improvement recommendation only if setting is enabled
      Controls.RecommendedActionButton:SetHide(false);
      Controls.BuildActionsPanel:SetSizeY( buildStackHeight + 20 + BUILD_PANEL_ART_PADDING_Y);
      Controls.BuildActionsStack:SetOffsetY(26);
      Controls.RecommendedActionIcon:SetTexture( IconManager:FindIconAtlas(bestBuildAction.IconId, 38) ); 
      Controls.RecommendedActionButton:SetDisabled( bestBuildAction.Disabled );
      Controls.RecommendedActionIcon:SetAlpha( (bestBuildAction.Disabled and 0.4) or 1 );
      local tooltipString:string = Locale.Lookup("LOC_HUD_UNIT_PANEL_RECOMMENDED") .. ":[NEWLINE]" .. bestBuildAction.helpString;
      Controls.RecommendedActionButton:SetToolTipString( tooltipString );
      Controls.RecommendedActionButton:RegisterCallback( Mouse.eLClick, bestBuildAction.CallbackFunc );
      Controls.RecommendedActionButton:SetVoid1( bestBuildAction.CallbackVoid1 );
      Controls.RecommendedActionButton:SetVoid2( bestBuildAction.CallbackVoid2 );
    else
      Controls.RecommendedActionButton:SetHide(true);
      Controls.BuildActionsPanel:SetSizeY( buildStackHeight + BUILD_PANEL_ART_PADDING_Y);
      Controls.BuildActionsStack:SetOffsetY(0);
    end

  else
    Controls.BuildActionsPanel:SetHide(true);
  end

  Controls.StandardActionsStack:CalculateSize();
  Controls.StandardActionsStack:ReprocessAnchoring();

  Controls.SecondaryActionsStack:CalculateSize();
  Controls.SecondaryActionsStack:ReprocessAnchoring();

  ResizeUnitPanelToFitActionButtons();

  ---=======[ STATS ]=======---
  ReadTargetData();
  ShowSubjectUnitStats(m_combatResults ~= nil);

  TradeUnitView(data);

  EspionageView(data);

  -- Unit Name
  local unitName = Locale.Lookup(data.Name);

  -- Add suffix
  if data.UnitType ~= -1 then
    if (GameInfo.Units[data.UnitType].Domain == "DOMAIN_SEA") then
      if (data.MilitaryFormation == MilitaryFormationTypes.CORPS_FORMATION) then
        unitName = unitName .. " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_FLEET_SUFFIX");
      elseif (data.MilitaryFormation == MilitaryFormationTypes.ARMY_FORMATION) then
        unitName = unitName .. " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_ARMADA_SUFFIX");
      end
    else
      if (data.MilitaryFormation == MilitaryFormationTypes.CORPS_FORMATION) then
        unitName = unitName .. " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_CORPS_SUFFIX");
      elseif (data.MilitaryFormation == MilitaryFormationTypes.ARMY_FORMATION) then
        unitName = unitName .. " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_ARMY_SUFFIX");
      end
    end
  end

  Controls.UnitName:SetText( Locale.ToUpper( unitName ));
  Controls.CombatPreviewUnitName:SetText( Locale.ToUpper( unitName ));

  -- Portrait Icons
  if(data.IconName ~= nil) then
    if not Controls.UnitIcon:SetIcon(data.IconName) then
      Controls.UnitIcon:SetIcon(data.FallbackIconName)
    end
  end
  if(data.CivIconName ~= nil) then
    local darkerBackColor = DarkenLightenColor(m_primaryColor,(-85),238);
    local brighterBackColor = DarkenLightenColor(m_primaryColor,90,255);
    Controls.CircleBacking:SetColor(m_primaryColor);
    Controls.CircleLighter:SetColor(brighterBackColor);
    Controls.CircleDarker:SetColor(darkerBackColor);
    Controls.CivIcon:SetColor(m_secondaryColor);
    Controls.CivIcon:SetIcon(data.CivIconName);
    Controls.CityIconArea:SetHide(false);
    Controls.UnitIcon:SetHide(true);
  else
    Controls.CityIconArea:SetHide(true);
    Controls.UnitIcon:SetHide(false);
  end

  -- Damage meters ---
  if (data.MaxWallDamage > 0) then
    local healthPercent   :number = 1 - GetPercentFromDamage( data.Damage + data.PotentialDamage, data.MaxDamage );
    local healthShadowPercent :number = 1 - GetPercentFromDamage( data.Damage, data.MaxDamage );
    RealizeHealthMeter( Controls.CityHealthMeter, healthPercent, Controls.CityHealthMeterShadow, healthShadowPercent );

    local wallsPercent    :number = 1 - GetPercentFromDamage(data.WallDamage + data.PotentialWallDamage, data.MaxWallDamage);
    local wallsShadowPercent  :number = 1 - GetPercentFromDamage( data.WallDamage, data.MaxWallDamage );
    local wallRealizedPercent     = (wallsPercent * 0.5) + 0.5;
    Controls.WallHealthMeter:SetPercent( wallRealizedPercent )
    local wallShadowRealizedPercent     = (wallsShadowPercent * 0.5) + 0.5;
    Controls.WallHealthMeterShadow:SetPercent( wallShadowRealizedPercent )

    Controls.UnitHealthMeter:SetHide(true);
    Controls.CityHealthMeters:SetHide(false);
    if(wallsPercent == 0) then
      Controls.CityWallHealthMeters:SetHide(true);
    else
      Controls.CityWallHealthMeters:SetHide(false);
    end

    -- Update health tooltip
    local tooltip:string = "";
    if data.UnitType ~= -1 then
      tooltip = Locale.Lookup(data.UnitTypeName);
    end
    tooltip = tooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_HUD_UNIT_PANEL_HEALTH_TOOLTIP", data.MaxDamage - data.Damage, data.MaxDamage);
    if (data.MaxWallDamage > 0) then
      tooltip = tooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_HUD_UNIT_PANEL_WALL_HEALTH_TOOLTIP", data.MaxWallDamage - data.WallDamage, data.MaxWallDamage);
    end
    Controls.CityHealthMeter:SetToolTipString(tooltip);
  else
    local percent   :number = 1 - GetPercentFromDamage( data.Damage, data.MaxDamage );
    RealizeHealthMeter( Controls.UnitHealthMeter, percent, Controls.UnitHealthMeterShadow, percent );
    Controls.UnitHealthMeter:SetHide(false);
    Controls.CityHealthMeters:SetHide(true);

    -- Update health tooltip
    local tooltip:string = Locale.Lookup(data.UnitTypeName);
    tooltip = tooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_HUD_UNIT_PANEL_HEALTH_TOOLTIP", data.MaxDamage - data.Damage, data.MaxDamage);
    Controls.UnitHealthMeter:SetToolTipString(tooltip);
  end

  -- Populate Earned Promotions UI
  if (not UILens.IsLensActive("Religion") and data.Combat > 0 and data.MaxExperience > 0) then
    Controls.XPArea:SetHide(false);
    Controls.XPBar:SetPercent( data.UnitExperience / data.MaxExperience );
    Controls.XPArea:SetToolTipString( Locale.Lookup("LOC_HUD_UNIT_PANEL_XP_TT", data.UnitExperience, data.MaxExperience, data.UnitLevel+1 ) );
  else
    Controls.XPArea:SetHide(true);
  end

  Controls.PromotionBanner:SetColor( m_primaryColor );

  m_earnedPromotionIM:ResetInstances();
  if (table.count(data.CurrentPromotions) > 0) then
    for i, promotion in ipairs(data.CurrentPromotions) do
      local promotionInst = m_earnedPromotionIM:GetInstance();
      if (data.CurrentPromotions[i] ~= nil) then
        local descriptionStr = Locale.Lookup(data.CurrentPromotions[i].Name);
        descriptionStr = descriptionStr .. "[NEWLINE]" .. Locale.Lookup(data.CurrentPromotions[i].Desc);
        promotionInst.Top:SetToolTipString(descriptionStr);
      end
    end
    Controls.PromotionBanner:SetHide(false);
  else
    Controls.PromotionBanner:SetHide(true);
  end

  -- Great Person Passive Ability Info
  if data.GreatPersonPassiveText ~= "" then
    Controls.GreatPersonPassiveGrid:SetHide(false);
    Controls.GreatPersonPassiveGrid:SetToolTipString(Locale.Lookup("LOC_HUD_UNIT_PANEL_GREAT_PERSON_PASSIVE_ABILITY_TOOLTIP", data.GreatPersonPassiveName, data.GreatPersonPassiveText));
  else
    Controls.GreatPersonPassiveGrid:SetHide(true);
  end

  -- Settler Water Availability Info
  if data.IsSettler then
    Controls.SettlementWaterContainer:SetHide(false);
  else
    Controls.SettlementWaterContainer:SetHide(true);
  end

  ContextPtr:SetHide(false);

  -- Hide combat preview unless we have valid combat results
  OnShowCombat(m_combatResults ~= nil); 

  -- Turn off any animation previously occuring on meter, otherwise it will animate up each time a new unit is selected.
  Controls.UnitHealthMeter:SetAnimationSpeed( -1 );
end

-- ===========================================================================
function ViewTarget(data)

  -- Unit Name
  local targetName = data.Name;

  -- Add suffix
  if (data.UnitType ~= -1) then
    if (GameInfo.Units[data.UnitType].Domain == "DOMAIN_SEA") then
      if (data.MilitaryFormation == MilitaryFormationTypes.CORPS_FORMATION) then
        targetName = targetName .. " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_FLEET_SUFFIX");
      elseif (data.MilitaryFormation == MilitaryFormationTypes.ARMY_FORMATION) then
        targetName = targetName .. " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_ARMADA_SUFFIX");
      end
    else
      if (data.MilitaryFormation == MilitaryFormationTypes.CORPS_FORMATION) then
        targetName = targetName .. " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_CORPS_SUFFIX");
      elseif (data.MilitaryFormation == MilitaryFormationTypes.ARMY_FORMATION) then
        targetName = targetName .. " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_ARMY_SUFFIX");
      end
    end
  end

  Controls.TargetUnitName:SetText( Locale.ToUpper( targetName ));

  ---=======[ STATS ]=======---
  ShowTargetUnitStats();

  -- Portrait Icons
  if(data.IconName ~= nil) then
    Controls.TargetUnitIconArea:SetHide(false); 
    if not Controls.TargetUnitIcon:SetIcon(data.IconName) then
      Controls.TargetUnitIcon:SetIcon(data.FallbackIconName)
    end
  else
    Controls.TargetUnitIconArea:SetHide(true);
  end
  if(data.CivIconName ~= nil) then
    local darkerBackColor = DarkenLightenColor(m_primaryColor,(-85),238);
    local brighterBackColor = DarkenLightenColor(m_primaryColor,90,255);
    Controls.TargetCircleBacking:SetColor(m_primaryColor);
    Controls.TargetCircleLighter:SetColor(brighterBackColor);
    Controls.TargetCircleDarker:SetColor(darkerBackColor);
    Controls.TargetCivIcon:SetColor(m_secondaryColor);
    Controls.TargetCivIcon:SetIcon(data.CivIconName);
    Controls.TargetCityIconArea:SetHide(false);
    Controls.TargetUnitIcon:SetHide(true);
  else
    Controls.TargetCityIconArea:SetHide(true);
    Controls.TargetUnitIcon:SetHide(false);
  end

  -- Damage meters ---
  if (data.MaxWallDamage > 0) then
    local healthPercent   :number = 1 - GetPercentFromDamage( data.Damage + data.PotentialDamage, data.MaxDamage );
    local healthShadowPercent :number = 1 - GetPercentFromDamage( data.Damage, data.MaxDamage );
    RealizeHealthMeter( Controls.TargetCityHealthMeter, healthPercent, Controls.TargetCityHealthMeterShadow, healthShadowPercent );
    local wallsPercent    :number = 1 - GetPercentFromDamage(data.WallDamage + data.PotentialWallDamage, data.MaxWallDamage);
    local wallsShadowPercent  :number = 1 - GetPercentFromDamage( data.WallDamage, data.MaxWallDamage );
    --RealizeHealthMeter( Controls.TargetWallHealthMeter, wallsPercent, Controls.TargetWallHealthMeterShadow, wallsShadowPercent );
    local wallRealizedPercent     = (wallsPercent * 0.5) + 0.5;
    Controls.TargetWallHealthMeter:SetPercent( wallRealizedPercent );
    local wallShadowRealizedPercent     = (wallsShadowPercent * 0.5) + 0.5;
    Controls.TargetWallHealthMeterShadow:SetPercent( wallShadowRealizedPercent );

    Controls.TargetUnitHealthMeters:SetHide(true);
    Controls.TargetCityHealthMeters:SetHide(false);
    if(wallsPercent == 0) then
      Controls.TargetCityWallsHealthMeters:SetHide(true);
    else
      Controls.TargetCityWallsHealthMeters:SetHide(false);
    end

  else
    local percent   :number = 1 - GetPercentFromDamage( data.Damage + data.PotentialDamage, data.MaxDamage );
    local shadowPercent :number = 1 - GetPercentFromDamage( data.Damage, data.MaxDamage );
    RealizeHealthMeter( Controls.TargetHealthMeter, percent, Controls.TargetHealthMeterShadow, shadowPercent );
    Controls.TargetUnitHealthMeters:SetHide(false);
    Controls.TargetCityHealthMeters:SetHide(true);
  end

  OnShowCombat(true);
end

-- ===========================================================================
function ShowDistrictStats(showCombat:boolean)
  m_subjectStatStackIM:ResetInstances();

  -- Make sure we have some subject data
  if m_subjectData == nil then
    return;
  end

  -- Ranged strength is always used as primary stat when attacking so hide stat in combat preview
  if showCombat then
    -- Show melee strength
    AddDistrictStat(m_subjectData.Combat, "", "ICON_STRENGTH", -12);

    Controls.SubjectStatContainer:SetOffsetVal(86,112);
    Controls.SubjectStatContainer:SetSizeX(72);
  else
    -- Show range strength
    AddDistrictStat(m_subjectData.RangedCombat, "LOC_HUD_UNIT_PANEL_RANGED_STRENGTH", "ICON_RANGED_STRENGTH", 0);
    -- Show melee strength
    AddDistrictStat(m_subjectData.Combat, "LOC_HUD_UNIT_PANEL_STRENGTH", "ICON_STRENGTH", -12);

    Controls.SubjectStatContainer:SetOffsetVal(86,56);
    Controls.SubjectStatContainer:SetParentRelativeSizeX(-105);
  end

  Controls.SubjectStatStack:CalculateSize();
  Controls.SubjectStatStack:ReprocessAnchoring();
  Controls.SubjectStatContainer:ReprocessAnchoring();
end

-- ===========================================================================
function ShowSubjectUnitStats(showCombat:boolean)
  m_subjectStatStackIM:ResetInstances();

  -- If we're in city or district attack mode reroute to ShowDistrictStats
  if (UI.GetInterfaceMode() == InterfaceModeTypes.CITY_RANGE_ATTACK) or (UI.GetInterfaceMode() == InterfaceModeTypes.DISTRICT_RANGE_ATTACK) then
    ShowDistrictStats(showCombat);
    return;
  end

  -- If the subject is something like a city then ignore unit stats
  if m_subjectData == nil or m_subjectData.UnitType == -1 then
    return;
  end

  -- Don't display unit stats for these units
  if m_subjectData.IsSpy then
    return;
  end

  -- Show custom stats for trader units
  if m_subjectData.IsTradeUnit then
    -- Add stat for trade route name
    local xOffset:number = 0;
    if m_subjectData.TradeRouteName ~= "" then
      AddCustomUnitStat(m_subjectData.TradeRouteIcon, "", m_subjectData.TradeRouteName, xOffset);
      xOffset = xOffset - 12;
    end

    AddCustomUnitStat("ICON_STATS_LAND_TRADE", tostring(m_subjectData.TradeLandRange), "LOC_HUD_UNIT_PANEL_LAND_ROUTE_RANGE", xOffset);

    -- If offset is still 0 then make sure to adjust it for the next stat
    if xOffset == 0 then
      xOffset = xOffset - 12;
    end

    AddCustomUnitStat("ICON_STATS_SEA_TRADE", tostring(m_subjectData.TradeSeaRange), "LOC_HUD_UNIT_PANEL_SEA_ROUTE_RANGE", xOffset);

    return;
  end

  -- If we showing the combat preview we can only show three stats and
  -- the main combat stat is shown separately above the normal stat stack
  -- Never show combat for civilian units!!
  local isCivilian  :boolean = GameInfo.Units[m_subjectData.UnitType].FormationClass == "FORMATION_CLASS_CIVILIAN";
  local isReligious :boolean = (m_subjectData.ReligiousStrength > 0 );
  if showCombat and m_combatResults ~= nil and ((isCivilian==false) or (isCivilian and isReligious)) then
    m_subjectData.StatData = FilterUnitStatsFromUnitData(m_subjectData, m_combatResults[CombatResultParameters.COMBAT_TYPE]);

    local currentStatIndex:number = 0;
    for i,entry in ipairs(m_subjectData.StatData) do
      if currentStatIndex == 0 then
        AddUnitStat(i, entry, m_subjectData, -12, false);
      elseif currentStatIndex == 1 then
        AddUnitStat(i, entry, m_subjectData, -12, false);
      elseif currentStatIndex == 2 then
        AddUnitStat(i, entry, m_subjectData, 0, false);
      end
      currentStatIndex = currentStatIndex + 1;
    end

    Controls.SubjectStatContainer:SetOffsetVal(86,112);
    Controls.SubjectStatContainer:SetSizeX(72);
  else
    m_subjectData.StatData = FilterUnitStatsFromUnitData(m_subjectData);

    local currentStatIndex:number = 0;
    for i,entry in ipairs(m_subjectData.StatData) do
      if currentStatIndex == 0 then
        AddUnitStat(i, entry, m_subjectData, 0, true);
      elseif currentStatIndex == 1 then
        AddUnitStat(i, entry, m_subjectData, -12, true);
      elseif currentStatIndex == 2 then
        AddUnitStat(i, entry, m_subjectData, -12, true);
      elseif currentStatIndex == 3 then
        AddUnitStat(i, entry, m_subjectData, 0, true);
      end
      currentStatIndex = currentStatIndex + 1;
    end

    Controls.SubjectStatContainer:SetOffsetVal(86,56);
    Controls.SubjectStatContainer:SetParentRelativeSizeX(-105);
  end

  Controls.SubjectStatStack:CalculateSize();
  Controls.SubjectStatStack:ReprocessAnchoring();
  Controls.SubjectStatContainer:ReprocessAnchoring();
end

-- ===========================================================================
function AddDistrictStat(value:number, name:string, icon:string, relativeSizeX:number)
  local statInstance:table = m_subjectStatStackIM:GetInstance();

  -- Set relative size x
  statInstance.StatGrid:SetParentRelativeSizeX(relativeSizeX);

  -- Update name
  TruncateStringWithTooltip(statInstance.StatNameLabel, MAX_BEFORE_TRUNC_STAT_NAME, Locale.ToUpper(name));
  --statInstance.StatNameLabel:SetText(Locale.ToUpper(name));

  -- Update value
  local roundedValue: number = math.floor(value + 0.5);
  statInstance.StatValueLabel:SetText(roundedValue);
  statInstance.StatValueSlash:SetHide(true);
  statInstance.StatMaxValueLabel:SetHide(true);

  -- Update icon
  local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(icon,22);
  statInstance.StatCheckBox:SetCheckTexture(textureSheet);
  statInstance.StatCheckBox:SetCheckTextureOffsetVal(textureOffsetX,textureOffsetY);
  statInstance.StatCheckBox:SetUnCheckTextureOffsetVal(textureOffsetX,textureOffsetY);

  statInstance.StatGrid:ReprocessAnchoring();
end

-- ===========================================================================
function FilterUnitStatsFromUnitData( unitData:table, ignoreStatType:number )
  if unitData == nil then
    UI.DataError("Invalid unit hash passed to FilterUnitStatsFromUnitData");
    return {};
  end


  local data:table = {};

  -- Strength
  if ( unitData.Combat > 0 and (ignoreStatType == nil or ignoreStatType ~= CombatTypes.MELEE)) then
    table.insert(data, {Value = unitData.Combat, Type = "Combat", Label = "LOC_HUD_UNIT_PANEL_STRENGTH",        FontIcon="[ICON_Strength_Large]",   IconName="ICON_STRENGTH"});
  end
  if ( unitData.RangedCombat > 0 and (ignoreStatType == nil or ignoreStatType ~= CombatTypes.RANGED)) then
    table.insert(data, {Value = unitData.RangedCombat,    Label = "LOC_HUD_UNIT_PANEL_RANGED_STRENGTH",   FontIcon="[ICON_RangedStrength_Large]", IconName="ICON_RANGED_STRENGTH"});
  end
  if (unitData.BombardCombat > 0 and (ignoreStatType == nil or ignoreStatType ~= CombatTypes.BOMBARD)) then
    table.insert(data, {Value = unitData.BombardCombat, Label = "LOC_HUD_UNIT_PANEL_BOMBARD_STRENGTH",    FontIcon="[ICON_Bombard_Large]",    IconName="ICON_BOMBARD"});
  end
  if (unitData.ReligiousStrength > 0 and (ignoreStatType == nil or ignoreStatType ~= CombatTypes.RELIGIOUS)) then
    table.insert(data, {Value = unitData.ReligiousStrength, Label = "LOC_HUD_UNIT_PANEL_RELIGIOUS_STRENGTH",  FontIcon="[ICON_ReligionStat_Large]", IconName="ICON_RELIGION"});
  end
  if (unitData.AntiAirCombat > 0 and (ignoreStatType == nil or ignoreStatType ~= CombatTypes.AIR)) then
    table.insert(data, {Value = unitData.AntiAirCombat, Label = "LOC_HUD_UNIT_PANEL_ANTI_AIR_STRENGTH",   FontIcon="[ICON_AntiAir_Large]",    IconName="ICON_STATS_ANTIAIR"});
  end

  -- Movement
  if(unitData.MaxMoves > 0) then
    table.insert(data, {Value = unitData.MaxMoves, Type = "BaseMoves",    Label = "LOC_HUD_UNIT_PANEL_MOVEMENT",        FontIcon="[ICON_Movement_Large]",   IconName="ICON_MOVES"});
  end

  -- Range
  if (unitData.Range > 0) then
    table.insert(data, {Value = unitData.Range;     Label = "LOC_HUD_UNIT_PANEL_ATTACK_RANGE",      FontIcon="[ICON_Range_Large]",      IconName="ICON_RANGE"});
  end

  -- Charges
  if (unitData.SpreadCharges > 0) then
    table.insert(data, {Value = unitData.SpreadCharges, Type = "SpreadCharges", Label = "LOC_HUD_UNIT_PANEL_SPREADS",       FontIcon="[ICON_ReligionStat_Large]", IconName="ICON_RELIGION"});
  end
  if (unitData.BuildCharges > 0) then
    table.insert(data, {Value = unitData.BuildCharges, Type = "BuildCharges",   Label = "LOC_HUD_UNIT_PANEL_BUILDS",        FontIcon="[ICON_Charges_Large]",    IconName="ICON_BUILD_CHARGES"});
  end
  if (unitData.HealCharges > 0) then
    table.insert(data, {Value = unitData.HealCharges, Type = "HealCharges", Label = "LOC_HUD_UNIT_PANEL_HEALS", FontIcon="[ICON_ReligionStat_Large]", IconName="ICON_RELIGION"});
  end
  if (unitData.GreatPersonActionCharges > 0) then
    table.insert(data, {Value = unitData.GreatPersonActionCharges, Type = "ActionCharges",    Label = "LOC_HUD_UNIT_PANEL_GREAT_PERSON_ACTIONS",        FontIcon="[ICON_Charges_Large]",    IconName="ICON_GREAT_PERSON"});
  end

  -- If we have more than 4 stats then try to remove melee strength
  if (table.count(data) > 4) then
    for i,stat in ipairs(data) do
      if stat.Type == "Combat" then
        table.remove(data, i);
      end
    end
  end

  -- If we still have more than 4 stats through a data error
  if (table.count(data) > 4) then
    UI.DataError("More than four stats were picked to display for unit ".. tostring(unitData.UnitType));
  end

  return data;
end

-- ===========================================================================
function AddUnitStat(statType:number, statData:table, unitData:table, relativeSizeX:number, showName:boolean)
  local statInstance:table = m_subjectStatStackIM:GetInstance();

  -- Set relative size x
  statInstance.StatGrid:SetParentRelativeSizeX(relativeSizeX);

  -- Update name
  TruncateStringWithTooltip(statInstance.StatNameLabel, MAX_BEFORE_TRUNC_STAT_NAME, Locale.ToUpper(statData.Label));
  --statInstance.StatNameLabel:SetText(Locale.ToUpper(statData.Label));

  -- Update values
  if statData.Type ~= nil and statData.Type == "BaseMoves" then
    statInstance.StatValueLabel:SetText(unitData.MovementMoves);
    statInstance.StatMaxValueLabel:SetText(statData.Value);
    statInstance.StatValueSlash:SetHide(false);
    statInstance.StatMaxValueLabel:SetHide(false);
    statInstance.StatValueStack:CalculateSize();
  else
    statInstance.StatValueLabel:SetText(statData.Value);
    statInstance.StatValueSlash:SetHide(true);
    statInstance.StatMaxValueLabel:SetHide(true);
  end

  -- Show/Hide stat name
  if showName then
    statInstance.StatNameLabel:SetHide(false);
  else
    statInstance.StatNameLabel:SetHide(true);
  end

  -- Update icon
  local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(statData.IconName,22);
  statInstance.StatCheckBox:SetCheckTexture(textureSheet);
  statInstance.StatCheckBox:SetUnCheckTexture(textureSheet)
  statInstance.StatCheckBox:SetCheckTextureOffsetVal(textureOffsetX,textureOffsetY);
  statInstance.StatCheckBox:SetUnCheckTextureOffsetVal(textureOffsetX,textureOffsetY);

  statInstance.StatGrid:ReprocessAnchoring();
end

-- ===========================================================================
function AddCustomUnitStat(iconName:string, statValue:string, statDesc:string, relativeSizeX:number)
  local statInstance:table = m_subjectStatStackIM:GetInstance();

  -- Set relative size x
  statInstance.StatGrid:SetParentRelativeSizeX(relativeSizeX);

  -- Update name
  TruncateStringWithTooltip(statInstance.StatNameLabel, MAX_BEFORE_TRUNC_STAT_NAME, Locale.ToUpper(statDesc));

  -- Update values
  statInstance.StatValueLabel:SetText(statValue);
  statInstance.StatValueSlash:SetHide(true);
  statInstance.StatMaxValueLabel:SetHide(true);

  -- Update icon
  local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName,22);
  statInstance.StatCheckBox:SetCheckTexture(textureSheet);
  statInstance.StatCheckBox:SetUnCheckTexture(textureSheet);
  statInstance.StatCheckBox:SetCheckTextureOffsetVal(textureOffsetX,textureOffsetY);
  statInstance.StatCheckBox:SetUnCheckTextureOffsetVal(textureOffsetX,textureOffsetY);

  statInstance.StatGrid:ReprocessAnchoring();
end

function AddTargetUnitStat(statData:table, relativeSizeX:number)
  local statInstance:table = m_targetStatStackIM:GetInstance();

  -- Set relative size x
  statInstance.StatGrid:SetParentRelativeSizeX(relativeSizeX);

  -- Update value
  statInstance.StatValueLabel:SetText(statData.Value);

  -- Update icon
  local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(statData.IconName,22);
  statInstance.StatCheckBox:SetCheckTexture(textureSheet);
  statInstance.StatCheckBox:SetCheckTextureOffsetVal(textureOffsetX,textureOffsetY);
  statInstance.StatCheckBox:SetUnCheckTextureOffsetVal(textureOffsetX,textureOffsetY);

  statInstance.StatGrid:ReprocessAnchoring();

  return statInstance;
end

-- ===========================================================================
function ShowTargetUnitStats()
  m_targetStatStackIM:ResetInstances();

  -- If unitType is 0 then we're probably attacking a city so don't show any unit stats
  if m_targetData.UnitType > 0 and m_targetData.HasDefenses then
    -- Since the target unit is defending, the melee combat stat will always be the primary stat (except for Religious units). Show the ranged/bombard as secondary
    if m_combatResults ~= nil and m_combatResults[CombatResultParameters.COMBAT_TYPE] == CombatTypes.RELIGIOUS then
      m_targetData.StatData = FilterUnitStatsFromUnitData(m_targetData, CombatTypes.RELIGIOUS);
    else
      m_targetData.StatData = FilterUnitStatsFromUnitData(m_targetData, CombatTypes.MELEE);
    end

    local currentStatIndex:number = 0;
    for i,entry in ipairs(m_targetData.StatData) do
      if currentStatIndex == 0 then
        AddTargetUnitStat(entry, -14);
      elseif currentStatIndex == 1 then
        AddTargetUnitStat(entry, -14);
      elseif currentStatIndex == 2 then
        AddTargetUnitStat(entry, 0);
      end
      currentStatIndex = currentStatIndex + 1;
    end

    Controls.TargetStatContainer:ReprocessAnchoring();
  end
end

-- ===========================================================================
function TradeUnitView( viewData:table )
  if viewData.IsTradeUnit then
    local hideTradeYields:boolean = true;
    local originPlayer:table = Players[Game.GetLocalPlayer()];
    local originCities:table = originPlayer:GetCities();
    for _, city in originCities:Members() do
      local outgoingRoutes:table = city:GetTrade():GetOutgoingRoutes();
      for i,route in ipairs(outgoingRoutes) do
        if viewData.UnitID == route.TraderUnitID then
          -- Add Origin Yields
          Controls.TradeResourceList:DestroyAllChildren();
          for j,yieldInfo in pairs(route.OriginYields) do
            if yieldInfo.Amount > 0 then
              local yieldDetails:table = GameInfo.Yields[yieldInfo.YieldIndex];
              AddTradeResourceEntry(yieldDetails, yieldInfo.Amount);
              hideTradeYields = false;
            end
          end
        end
      end
    end

    Controls.TradeYieldGrid:SetHide(hideTradeYields);
    Controls.TradeUnitContainer:SetHide(false);
  else
    Controls.TradeUnitContainer:SetHide(true);
  end
end

-- ===========================================================================
function AddTradeResourceEntry(yieldInfo:table, yieldValue:number)
  local entryInstance:table = {};
  ContextPtr:BuildInstanceForControl( "TradeResourceyInstance", entryInstance, Controls.TradeResourceList );

  local icon:string, text:string = FormatTradeYieldText(yieldInfo, yieldValue);
  entryInstance.ResourceEntryIcon:SetText(icon);
  entryInstance.ResourceEntryText:SetText(text);
  entryInstance.ResourceEntryStack:CalculateSize();
  entryInstance.ResourceEntryStack:ReprocessAnchoring();
end

-- ===========================================================================
function FormatTradeYieldText(yieldInfo, yieldAmount)
  local text:string = "";

  local iconString = "";
  if (yieldInfo.YieldType == "YIELD_FOOD") then
    iconString = "[ICON_Food]";
  elseif (yieldInfo.YieldType == "YIELD_PRODUCTION") then
    iconString = "[ICON_Production]";
  elseif (yieldInfo.YieldType == "YIELD_GOLD") then
    iconString = "[ICON_Gold]";
  elseif (yieldInfo.YieldType == "YIELD_SCIENCE") then
    iconString = "[ICON_Science]";
  elseif (yieldInfo.YieldType == "YIELD_CULTURE") then
    iconString = "[ICON_Culture]";
  elseif (yieldInfo.YieldType == "YIELD_FAITH") then
    iconString = "[ICON_Faith]";
  end

  if (yieldAmount >= 0) then
    text = text .. "+";
  end

  text = text .. yieldAmount;
  return iconString, text;
end

-- ===========================================================================
function OnShowCombat( showCombat )
  local bAttackerIsUnit :boolean = false;

  local pAttacker :table;
  if (UI.GetInterfaceMode() == InterfaceModeTypes.CITY_RANGE_ATTACK) then
    local pAttackingCity = UI.GetHeadSelectedCity();
    if (pAttacker == nil) then
      pAttacker = GetDistrictFromCity(pAttackingCity);
      if (pAttacker == nil) then
        return;
      end
    end
  elseif (UI.GetInterfaceMode() == InterfaceModeTypes.DISTRICT_RANGE_ATTACK) then
    pAttacker = UI.GetHeadSelectedDistrict();
    if (pAttacker == nil) then
      return;
    end
  else
    pAttacker = UI.GetHeadSelectedUnit();
    if (pAttacker ~= nil) then
      bAttackerIsUnit = true;
    else
      return;
    end
  end

  if m_combatResults == nil then
    showCombat = false;
  end

  if (showCombat) then

    ShowCombatAssessment();
    --scale the unit panels to accomodate combat details
    Controls.UnitPanelBaseContainer:SetSizeY(190);
    Controls.EnemyUnitPanelExtension:SetSizeY(97);

    --Primary Combat Stat
    --Set the icon
    local combatType = m_combatResults[CombatResultParameters.COMBAT_TYPE];
    local textureOffsetX:number, textureOffsetY:number, textureString:string;

    if combatType == CombatTypes.MELEE then
      textureOffsetX, textureOffsetY, textureString = IconManager:FindIconAtlas("ICON_STRENGTH",22);
    elseif combatType == CombatTypes.RANGED then
      textureOffsetX, textureOffsetY, textureString = IconManager:FindIconAtlas("ICON_RANGED_STRENGTH",22);
    elseif combatType == CombatTypes.BOMBARD then
      textureOffsetX, textureOffsetY, textureString = IconManager:FindIconAtlas("ICON_BOMBARD",22);
    elseif combatType == CombatTypes.AIR then
      textureOffsetX, textureOffsetY, textureString = IconManager:FindIconAtlas("ICON_STATS_ANTIAIR",22);
    elseif combatType == CombatTypes.RELIGIOUS then
      textureOffsetX, textureOffsetY, textureString = IconManager:FindIconAtlas("ICON_RELIGION",22);
    end

    if textureString ~= nil then
      Controls.CombatPreview_CombatStatType:SetTexture(textureOffsetX, textureOffsetY, textureString);
    end

    -- Set Target Icon
    if combatType == CombatTypes.RELIGIOUS then
      textureOffsetX, textureOffsetY, textureString = IconManager:FindIconAtlas("ICON_RELIGION",22);
    else
      textureOffsetX, textureOffsetY, textureString = IconManager:FindIconAtlas("ICON_STRENGTH",22);
    end

    if textureString ~= nil then
      Controls.CombatPreview_CombatStatFoeType:SetTexture(textureOffsetX, textureOffsetY, textureString);
    end

    --Set the numerical value
    local attackerStrength = m_combatResults[CombatResultParameters.ATTACKER][CombatResultParameters.COMBAT_STRENGTH];
    local attackerStrengthModifier = m_combatResults[CombatResultParameters.ATTACKER][CombatResultParameters.STRENGTH_MODIFIER];
    local defenderStrength = m_combatResults[CombatResultParameters.DEFENDER][CombatResultParameters.COMBAT_STRENGTH];
    local defenderStrengthModifier = m_combatResults[CombatResultParameters.DEFENDER][CombatResultParameters.STRENGTH_MODIFIER];
    
    --Don't go below zero for final combat stat
    local attackerTotal = (attackerStrength + attackerStrengthModifier);
    if attackerTotal <= 0 then
      attackerTotal = 0;
    end
    Controls.CombatPreview_CombatStatStrength:SetText(attackerTotal);
    
    --If the target can defend show stats, if the target is passive don't show stats
    if ( m_targetData.HasDefenses ) then
      local defenderTotal = (defenderStrength + defenderStrengthModifier);
      if defenderTotal <= 0 then
        defenderTotal = 0;
      end
      Controls.CombatPreview_CombatStatFoeStrength:SetHide(false);
      Controls.CombatPreview_CombatStatFoeStrength:SetText(defenderTotal);
    else
      Controls.CombatPreview_CombatStatFoeStrength:SetHide(true); 
    end 

    --Attacker's Damage meter
    local attackerCurrentDamage = pAttacker:GetDamage();
    local attackerMaxDamage = pAttacker:GetMaxDamage();
    local attackerCombatDamage = m_combatResults[CombatResultParameters.ATTACKER][CombatResultParameters.DAMAGE_TO];
    local percent   :number = 1 - GetPercentFromDamage( attackerCurrentDamage + attackerCombatDamage, attackerMaxDamage);
    local shadowPercent :number = 1 - GetPercentFromDamage( attackerCurrentDamage, attackerMaxDamage );
    RealizeHealthMeter(Controls.UnitHealthMeter, percent, Controls.UnitHealthMeterShadow, shadowPercent);

    -- Update combat preview panels
    UpdateTargetModifiers(0);
    Controls.CombatBreakdownPanel:SetHide(false);
    UpdateCombatModifiers(0);

    -- Hide Unit Selection Pulldown
    Controls.UnitListPopup:SetHide(true);
  else
    --return unit panels to base sizes
    Controls.UnitPanelBaseContainer:SetSizeY(160);
    Controls.EnemyUnitPanelExtension:SetSizeY(67);

    -- Hide any combat preview specific UI
    Controls.CombatBreakdownPanel:SetHide(true);

    -- Reset unit health when switching away from combat
    local attackerCurrentDamage = pAttacker:GetDamage();
    local attackerMaxDamage = pAttacker:GetMaxDamage();
    local percent:number = 1 - GetPercentFromDamage( attackerCurrentDamage, attackerMaxDamage );
    RealizeHealthMeter( Controls.UnitHealthMeter, percent, Controls.UnitHealthMeterShadow, percent );

    -- Show Unit Selection Pulldown
    Controls.UnitListPopup:SetHide(false);
  end

  ShowSubjectUnitStats(showCombat);

  Controls.CombatPreview_CombatStat:SetHide(not showCombat);
  Controls.CombatPreviewBanners:SetHide(not showCombat);
  Controls.EnemyUnitPanel:SetHide(not showCombat);

  if (bAttackerIsUnit) then
    if (pAttacker:GetExperience():GetLevel() > 1) then
      Controls.PromotionBanner:SetHide(showCombat);
    end
  end
end

-- Show/Hide Espionage Unit Elements
function EspionageView(data:table)
  if (data.IsSpy) then
    local operationType:number = data.SpyOperation;
    if (operationType ~= -1) then
      -- City Banner
      local backColor:number, frontColor:number  = UI.GetPlayerColors( data.SpyTargetOwnerID );
      Controls.EspionageCityBanner:SetColor( backColor );
      Controls.EspionageLocationPip:SetColor( frontColor );
      Controls.EspionageCityName:SetColor( frontColor );
      Controls.EspionageCityName:SetText(Locale.ToUpper(data.SpyTargetCityName));

      -- Mission Name
      local operationInfo:table = GameInfo.UnitOperations[operationType];
      Controls.EspionageUnitStatusLabel:SetText(Locale.Lookup(operationInfo.Description));

      -- Mission Icon
      local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(operationInfo.Icon,40);
      if textureSheet then
        Controls.EspionageMissionIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
        Controls.EspionageMissionIcon:SetHide(false);
      else
        UI.DataError("Unable to find icon for spy operation: " .. operationInfo.Icon);
        Controls.EspionageMissionIcon:SetHide(true);
      end

      -- Turns Remaining
      Controls.EspionageTurnsRemaining:SetText(Locale.Lookup("LOC_UNITPANEL_ESPIONAGE_MORE_TURNS", data.SpyRemainingTurns));

      -- Update Turn Meter
      local percentOperationComplete:number = (data.SpyTotalTurns - data.SpyRemainingTurns) / data.SpyTotalTurns;
      local percentOperationCompleteNextTurn:number = (data.SpyTotalTurns - data.SpyRemainingTurns + 1) / data.SpyTotalTurns;
      Controls.EspionageCompleteMeter:SetPercent(percentOperationComplete);
      Controls.EspionageCompleteMeter_NextTurn:SetPercent(percentOperationCompleteNextTurn);

      Controls.EspionageStack:CalculateSize();
      Controls.EspionageStack:ReprocessAnchoring();

      Controls.EspionageUnitContainer:SetHide(false);
      Controls.EspionageIdleLabel:SetHide(true);
    else
      Controls.EspionageUnitContainer:SetHide(true);
      Controls.EspionageIdleLabel:SetHide(false);
    end
  else
    Controls.EspionageUnitContainer:SetHide(true);
    Controls.EspionageIdleLabel:SetHide(true);
  end
end

-- ===========================================================================
function UpdateInterceptorModifiers(startIndex:number)
  local modifierList:table, modifierListSize:number = GetCombatModifierList(CombatResultParameters.INTERCEPTOR);
  UpdateModifiers(startIndex, Controls.InterceptorModifierStack, Controls.InterceptorModifierStackAnim, UpdateInterceptorModifiers, m_interceptorModifierIM, modifierList, modifierListSize);
end

-- ===========================================================================
function UpdateAntiAirModifiers(startIndex:number)
  local modifierList:table, modifierListSize:number = GetCombatModifierList(CombatResultParameters.ANTI_AIR);
  UpdateModifiers(startIndex, Controls.AntiAirModifierStack, Controls.AntiAirModifierStackAnim, UpdateAntiAirModifiers, m_antiAirModifierIM, modifierList, modifierListSize);
end

-- ===========================================================================
function UpdateTargetModifiers(startIndex:number)
  -- If the target can defend show modifier list.  If the target is passive don't.
  local modifierList:table = {};
  local modifierListSize:number = 0;
  if( m_targetData.HasDefenses ) then
    modifierList, modifierListSize = GetCombatModifierList(CombatResultParameters.DEFENDER);
  end
  UpdateModifiers(startIndex, Controls.TargetModifierStack, Controls.TargetModifierStackAnim, UpdateTargetModifiers, m_targetModifierIM, modifierList, modifierListSize);
end

-- ===========================================================================
function UpdateCombatModifiers(startIndex:number)
  local modifierList:table, modifierListSize:number = GetCombatModifierList(CombatResultParameters.ATTACKER);
  UpdateModifiers(startIndex, Controls.SubjectModifierStack, Controls.SubjectModifierStackAnim, UpdateCombatModifiers, m_subjectModifierIM, modifierList, modifierListSize);
end

-- ===========================================================================
function UpdateModifiers(startIndex:number, stack:table, stackAnim:table, stackAnimCallback:ifunction, stackIM:table, modifierList:table, modifierCount:number)
  -- Reset stack instances
  stackIM:ResetInstances();

  -- Reset anim to make sure the list isn't hidden
  stackAnim:Stop();
  stackAnim:SetToBeginning();

  -- Add modifiers to stack
  local shouldPlayAnim:boolean = false;
  local nextIndex = 0;

  -- Make sure our inputs are valid
  if modifierList ~= nil and modifierCount ~= nil then
    for i=startIndex,modifierCount,1 do
      if modifierList[i] ~= nil then
        local modifierEntry = modifierList[i];
        if not AddModifierToStack(stack, stackIM, modifierEntry["text"], modifierEntry["icon"], stackAnim:GetSizeY()) then
          nextIndex = i;
          break;
        end

        -- If we hit the end of the list then reset the next index
        if i == modifierCount then
          nextIndex = 0;
        end
      end
    end
  end

  -- Calculate size and unhide panel
  stack:CalculateSize();

  -- Determine if we have other stat pages to display
  if startIndex ~= 0 or nextIndex ~= 0 then
    shouldPlayAnim = true;
  end

  -- Play anim if we have multiple pages
  if shouldPlayAnim then
    stackAnim:Play();
    stackAnim:RegisterEndCallback(
      function()
        stackAnimCallback(nextIndex);
      end
    );
  end
end

-- ===========================================================================
function GetCombatModifierList(combatantHash:number)
  if (m_combatResults == nil) then
    return;
  end

  local baseStrengthValue = 0;
  local combatantResults = m_combatResults[combatantHash];

  baseStrengthValue = combatantResults[CombatResultParameters.COMBAT_STRENGTH];

  local baseStrengthText = baseStrengthValue .. " " .. Locale.Lookup("LOC_COMBAT_PREVIEW_BASE_STRENGTH");
  local interceptorModifierText = combatantResults[CombatResultParameters.PREVIEW_TEXT_INTERCEPTOR];
  local antiAirModifierText = combatantResults[CombatResultParameters.PREVIEW_TEXT_ANTI_AIR];
  local healthModifierText = combatantResults[CombatResultParameters.PREVIEW_TEXT_HEALTH];
  local terrainModifierText = combatantResults[CombatResultParameters.PREVIEW_TEXT_TERRAIN];
  local opponentModifierText = combatantResults[CombatResultParameters.PREVIEW_TEXT_OPPONENT];
  local modifierModifierText = combatantResults[CombatResultParameters.PREVIEW_TEXT_MODIFIER];
  local flankingModifierText = combatantResults[CombatResultParameters.PREVIEW_TEXT_ASSIST];
  local promotionModifierText = combatantResults[CombatResultParameters.PREVIEW_TEXT_PROMOTION];
  local defenseModifierText = combatantResults[CombatResultParameters.PREVIEW_TEXT_DEFENSES];

  local modifierList:table = {};
  local modifierListSize:number = 0;
  if (baseStrengthText ~= nil) then
    modifierList, modifierListSize = AddModifierToList(modifierList, modifierListSize, baseStrengthText, "ICON_STRENGTH");
  end
  if (interceptorModifierText ~= nil) then
    for i, item in ipairs(interceptorModifierText) do
      modifierList, modifierListSize = AddModifierToList(modifierList, modifierListSize, Locale.Lookup(item), "ICON_STATS_INTERCEPTOR");
    end
  end
  if (antiAirModifierText ~= nil) then
    for i, item in ipairs(antiAirModifierText) do
      modifierList, modifierListSize = AddModifierToList(modifierList, modifierListSize, Locale.Lookup(item), "ICON_STATS_ANTIAIR");
    end
  end
  if (healthModifierText ~= nil) then
    for i, item in ipairs(healthModifierText) do
      modifierList, modifierListSize = AddModifierToList(modifierList, modifierListSize, Locale.Lookup(item), "ICON_DAMAGE");
    end
  end
  if (terrainModifierText ~= nil) then
    for i, item in ipairs(terrainModifierText) do
      modifierList, modifierListSize = AddModifierToList(modifierList, modifierListSize, Locale.Lookup(item), "ICON_STATS_TERRAIN");
    end
  end
  if (opponentModifierText ~= nil) then
    for i, item in ipairs(opponentModifierText) do
      modifierList, modifierListSize = AddModifierToList(modifierList, modifierListSize, Locale.Lookup(item), "ICON_STRENGTH");
    end
  end
  if (modifierModifierText ~= nil) then
    for i, item in ipairs(modifierModifierText) do
      modifierList, modifierListSize = AddModifierToList(modifierList, modifierListSize, Locale.Lookup(item), "ICON_STRENGTH");
    end
  end
  if (flankingModifierText ~= nil) then
    for i, item in ipairs(flankingModifierText) do
      modifierList, modifierListSize = AddModifierToList(modifierList, modifierListSize, Locale.Lookup(item), "ICON_POSITION");
    end
  end
  if (promotionModifierText ~= nil) then
    for i, item in ipairs(promotionModifierText) do
      modifierList, modifierListSize = AddModifierToList(modifierList, modifierListSize, Locale.Lookup(item), "ICON_PROMOTION");
    end
  end
  if (defenseModifierText ~= nil) then
    for i, item in ipairs(defenseModifierText) do
      modifierList, modifierListSize = AddModifierToList(modifierList, modifierListSize, Locale.Lookup(item), "ICON_DEFENSE");
    end
  end

  return modifierList, modifierListSize;
end

-- ===========================================================================
function AddModifierToList(modifierList, modifierListSize, text, icon)
  local modifierEntry:table = {}
  modifierEntry["text"] = text;
  modifierEntry["icon"] = icon;

  modifierListSize = modifierListSize + 1;
  modifierList[modifierListSize] = modifierEntry;

  return modifierList, modifierListSize;
end

-- ===========================================================================
function AddModifierToStack(stackControl, stackIM, text, icon, maxHeight:number)
  local kStat:table = stackIM:GetInstance();
  kStat.ModifierText:SetText(text);
  local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(icon,16);
  kStat.ModifierIcon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );

  local leadingCharacter:string = string.sub(text, 0, 1);
  if(string.find(text, "COLOR_GREEN") ~= nil) then
    kStat.ModifierIcon:SetColorByName("StatGoodCS");
  elseif(string.find(text, "COLOR_RED") ~= nil) then
    kStat.ModifierIcon:SetColorByName("StatBadCS");
  end

  -- Determine if this instance overflows the container control
  -- If so, remove instance so it can be shown on a different page
  stackControl:CalculateSize();
  if stackControl:GetSizeY() > maxHeight then
    stackIM:ReleaseInstance(kStat);
    return false;
  end

  return true;
end

-- ===========================================================================
function Hide()
  ContextPtr:SetHide(true);
end

-- ===========================================================================
function HidePromotionPanel()
  Controls.PromotionPanel:SetHide(true);
  Controls.VeteranNamePanel:SetHide(true);
  LuaEvents.UnitPanel_HideUnitPromotion();
end

--------------------------------------------------------------------------------
function HideVeteranNamePanel()
  Controls.VeteranNamePanel:SetHide(true);
end

-- ===========================================================================
function OnToggleSecondRow()
  local isHidden:boolean = Controls.SecondaryActionsStack:IsHidden();
  if isHidden then
    Controls.SecondaryActionsStack:SetHide(false);
    Controls.ExpandSecondaryActionsButton:SetTextureOffsetVal(0,29);
  else
    Controls.SecondaryActionsStack:SetHide(true);
    Controls.ExpandSecondaryActionsButton:SetTextureOffsetVal(0,0);
  end

  Controls.ExpandSecondaryActionStack:CalculateSize();
  Controls.ExpandSecondaryActionStack:ReprocessAnchoring();

  ResizeUnitPanelToFitActionButtons();
end
Controls.ExpandSecondaryActionsButton:RegisterCallback( Mouse.eLClick, OnToggleSecondRow );

-- ===========================================================================
function OnSecondaryActionStackMouseEnter()
  Controls.ExpandSecondaryActionGrid:SetAlpha(1.0);
end
Controls.ExpandSecondaryActionsButton:RegisterMouseEnterCallback(OnSecondaryActionStackMouseEnter);

-- ===========================================================================
function OnSecondaryActionStackMouseExit()
  -- If the secondary action stack is hidden then fade out the expand button
  if Controls.SecondaryActionsStack:IsHidden() then
    Controls.ExpandSecondaryActionGrid:SetAlpha(0.75);
  end
end
Controls.ExpandSecondaryActionsButton:RegisterMouseExitCallback(OnSecondaryActionStackMouseExit);

-- ===========================================================================
function ResizeUnitPanelToFitActionButtons()
  -- Resize the unit panel to fit all visible action buttons
  Controls.ActionsStack:CalculateSize();
  if Controls.ActionsStack:GetSizeX() > m_minUnitPanelWidth then
    Controls.UnitPanelBaseContainer:SetSizeX(Controls.ActionsStack:GetSizeX() + m_resizeUnitPanelPadding);
  else
    Controls.UnitPanelBaseContainer:SetSizeX(m_minUnitPanelWidth);
  end

  -- Update unit stat size and anchoring
  Controls.SubjectStatStack:CalculateSize();
  Controls.SubjectStatStack:ReprocessAnchoring();
  Controls.SubjectStatContainer:ReprocessAnchoring();
end

-- ===========================================================================
function GetUnitPortraitPrefix( playerID:number )
  local iconPrefix:string = "ICON_";

  -- Add civilization ethnicity
  local playerConfig:table = PlayerConfigurations[playerID];
  local civ:table = GameInfo.Civilizations[playerConfig:GetCivilizationTypeID()];
  if civ then
    -- Barbarians don't have an ethnicity field so make sure it exists
    if civ.Ethnicity and civ.Ethnicity ~= "ETHNICITY_EURO" then
      iconPrefix = iconPrefix .. civ.Ethnicity .. "_";
    end
  end

  return iconPrefix;
end

-- ===========================================================================
function ReadUnitData( unit:table )

  local unitExperience = unit:GetExperience();
  local potentialDamage :number = 0;

  InitSubjectData();

  m_subjectData.Name            = unit:GetName();
  m_subjectData.UnitTypeName        = GameInfo.Units[unit:GetUnitType()].Name;
  m_subjectData.IconName          = GetUnitPortraitPrefix(unit:GetOwner())..GameInfo.Units[unit:GetUnitType()].UnitType.."_PORTRAIT";
  m_subjectData.FallbackIconName			= "ICON_"..GameInfo.Units[unit:GetUnitType()].UnitType.."_PORTRAIT";
  m_subjectData.Moves           = unit:GetMovesRemaining();
  m_subjectData.MovementMoves       = unit:GetMovementMovesRemaining();
  m_subjectData.InFormation       = unit:GetFormationUnitCount() > 1;
  m_subjectData.FormationMoves      = unit:GetFormationMovesRemaining();
  m_subjectData.FormationMaxMoves     = unit:GetFormationMaxMoves();
  m_subjectData.MaxMoves          = unit:GetMaxMoves();
  m_subjectData.Combat          = unit:GetCombat();
  m_subjectData.Damage          = unit:GetDamage();
  m_subjectData.MaxDamage         = unit:GetMaxDamage();
  m_subjectData.PotentialDamage     = potentialDamage;
  m_subjectData.RangedCombat        = unit:GetRangedCombat();
  m_subjectData.BombardCombat       = unit:GetBombardCombat();
  m_subjectData.AntiAirCombat       = unit:GetAntiAirCombat();
  m_subjectData.Range           = unit:GetRange();
  m_subjectData.Owner           = unit:GetOwner();
  m_subjectData.BuildCharges        = unit:GetBuildCharges();
  m_subjectData.SpreadCharges       = unit:GetSpreadCharges();
  m_subjectData.HealCharges = unit:GetReligiousHealCharges();
  m_subjectData.ReligiousStrength     = unit:GetReligiousStrength();
  m_subjectData.HasMovedIntoZOC     = unit:HasMovedIntoZOC();
  m_subjectData.MilitaryFormation     = unit:GetMilitaryFormation();
  m_subjectData.UnitType          = unit:GetUnitType();
  m_subjectData.UnitID          = unit:GetID();
  m_subjectData.UnitExperience      = unitExperience:GetExperiencePoints();
  m_subjectData.MaxExperience       = unitExperience:GetExperienceForNextLevel();
  m_subjectData.UnitLevel         = unitExperience:GetLevel();
  m_subjectData.CurrentPromotions     = {};
  m_subjectData.Actions         = GetUnitActionsTable( unit );

  -- Great person data
  local unitGreatPerson = unit:GetGreatPerson();
  if unitGreatPerson then
    local individual = unitGreatPerson:GetIndividual();
    local greatPersonInfo = GameInfo.GreatPersonIndividuals[individual];
    local gpClass = GameInfo.GreatPersonClasses[unitGreatPerson:GetClass()];
    if unitGreatPerson:HasPassiveEffect() then
      m_subjectData.GreatPersonPassiveText = unitGreatPerson:GetPassiveEffectText();
      m_subjectData.GreatPersonPassiveName = unitGreatPerson:GetPassiveNameText();
    end
    m_subjectData.GreatPersonActionCharges = unitGreatPerson:GetActionCharges();
  end

  local promotionList :table = unitExperience:GetPromotions();
  local i=0;
  for i, promotion in ipairs(promotionList) do
    local promotionDef = GameInfo.UnitPromotions[promotion];
    table.insert(m_subjectData.CurrentPromotions, {
      Name = promotionDef.Name,
      Desc = promotionDef.Description,
      Level = promotionDef.Level
      });
  end

  m_subjectData.StatData = FilterUnitStatsFromUnitData(m_subjectData);

  -- Espionage Data
  if (GameInfo.Units[m_subjectData.UnitType].Spy == true) then
    m_subjectData.IsSpy = true;

    local activityType:number = UnitManager.GetActivityType(unit);
    if activityType == ActivityTypes.ACTIVITY_OPERATION then
      m_subjectData.SpyOperation = unit:GetSpyOperation();
      if (m_subjectData.SpyOperation ~= -1) then
        local spyPlot:table = Map.GetPlot(unit:GetX(), unit:GetY());
        local targetCity:table = Cities.GetPlotPurchaseCity(spyPlot);
        if targetCity then
          m_subjectData.SpyTargetCityName = targetCity:GetName();
          m_subjectData.SpyTargetOwnerID = targetCity:GetOwner();
        end

        m_subjectData.SpyRemainingTurns = unit:GetSpyOperationEndTurn() - Game.GetCurrentGameTurn();
        m_subjectData.SpyTotalTurns = UnitManager.GetTimeToComplete(m_subjectData.SpyOperation, unit);
      end
    end
  end

  if (GameInfo.Units[m_subjectData.UnitType].MakeTradeRoute == true) then
    m_subjectData.IsTradeUnit = true;

    -- Get trade route name
    local owningPlayer:table = Players[unit:GetOwner()];
    local cities:table = owningPlayer:GetCities();
    for _, city in cities:Members() do
      local outgoingRoutes:table = city:GetTrade():GetOutgoingRoutes();
      for i,route in ipairs(outgoingRoutes) do
        if m_subjectData.UnitID == route.TraderUnitID then
          -- Find origin city
          local originCity:table = cities:FindID(route.OriginCityID);

          -- Find destination city
          local destinationPlayer:table = Players[route.DestinationCityPlayer];
          local destinationCities:table = destinationPlayer:GetCities();
          local destinationCity:table = destinationCities:FindID(route.DestinationCityID);

          -- Set origin to destination name
          if originCity and destinationCity then
            m_subjectData.TradeRouteName = Locale.Lookup("LOC_HUD_UNIT_PANEL_TRADE_ROUTE_NAME", originCity:GetName(), destinationCity:GetName());

            local civID:number = PlayerConfigurations[destinationCity:GetOwner()]:GetCivilizationTypeID();
            local civ:table = GameInfo.Civilizations[civID];
            if civ then
              m_subjectData.TradeRouteIcon = "ICON_" .. civ.CivilizationType;
            end
          end
        end
      end
    end

    local playerTrade:table = owningPlayer:GetTrade();
    if playerTrade then
      -- Get land range
      m_subjectData.TradeLandRange = playerTrade:GetLandRangeRefuel();

      -- Get sea range
      m_subjectData.TradeSeaRange = playerTrade:GetWaterRangeRefuel();
    end
  end

  -- Check if we're a settler
  if (GameInfo.Units[m_subjectData.UnitType].FoundCity == true) then
    m_subjectData.IsSettler = true;
  end

  View(m_subjectData);
end

-- ===========================================================================
function ReadDistrictData( pDistrict:table )

  if (pDistrict ~= nil) then
    InitSubjectData();

    local parentCity = pDistrict:GetCity();
    local districtName;
    if (parentCity ~= nil) then
      districtName = Locale.Lookup(parentCity:GetName());
    end

    local districtInfo = GameInfo.Districts[pDistrict:GetType()];
    if (not districtInfo.CityCenter) then
      districtName = districtName .. " " .. Locale.Lookup(districtInfo.Name);
    end

    -- district data
    m_subjectData.Name            = districtName;
    m_subjectData.Combat          = pDistrict:GetDefenseStrength();
    m_subjectData.RangedCombat        = pDistrict:GetAttackStrength();
    m_subjectData.Damage          = pDistrict:GetDamage(DefenseTypes.DISTRICT_GARRISON);
    m_subjectData.MaxDamage         = pDistrict:GetMaxDamage(DefenseTypes.DISTRICT_GARRISON);
    m_subjectData.WallDamage        = pDistrict:GetDamage(DefenseTypes.DISTRICT_OUTER);
    m_subjectData.MaxWallDamage       = pDistrict:GetMaxDamage(DefenseTypes.DISTRICT_OUTER);

    m_primaryColor, m_secondaryColor  = UI.GetPlayerColors( pDistrict:GetOwner() );

    local civTypeName:string = PlayerConfigurations[pDistrict:GetOwner()]:GetCivilizationTypeName();
    if civTypeName ~= nil then
      local civIconName = "ICON_"..civTypeName;
      m_subjectData.CivIconName	= civIconName;
    else
      UI.DataError("Invalid type name returned by GetCivilizationTypeName");
    end
    View(m_subjectData);
  end

end

-- ===========================================================================
function Refresh(player, unitId)
  if(player ~= nil and player ~= -1 and unitId ~= nil and unitId ~= -1) then

    m_kHotkeyActions = {};
    m_kHotkeyCV1 = {};
    m_kHotkeyCV2 = {};
        m_kSoundCV1 = {};

    local units = Players[player]:GetUnits();
    local unit = units:FindID(unitId);
    if(unit ~= nil) then
      ReadUnitData( unit, numUnits );
      --CQUI auto-expando
      if(GameConfiguration.GetValue("CQUI_AutoExpandUnitActions")) then
        local isHidden:boolean = Controls.SecondaryActionsStack:IsHidden();
        if isHidden then
          Controls.SecondaryActionsStack:SetHide(false);
          Controls.ExpandSecondaryActionsButton:SetTextureOffsetVal(0,29);
          OnSecondaryActionStackMouseEnter();
          Controls.ExpandSecondaryActionStack:CalculateSize();
          Controls.ExpandSecondaryActionStack:ReprocessAnchoring();
        end
        
        -- AZURENCY : fix for the size not updating correcly (fall 2017), we calculate the size manually, 4 is the StackPadding
        Controls.ExpandSecondaryActionStack:SetSizeX(Controls.ExpandSecondaryActionsButton:GetSizeX() + Controls.SecondaryActionsStack:GetSizeX() + 4);
        ResizeUnitPanelToFitActionButtons();
      end

    else
      Hide();
    end
  else
    Hide();
  end
end


-- ===========================================================================
function OnRefresh()
  ContextPtr:ClearRequestRefresh();   -- Clear the refresh request, in case we got here from some other means.  This cuts down on redundant updates.
  Refresh(m_selectedPlayerId, m_UnitId);
  local pSelectedUnit :table= UI.GetHeadSelectedUnit();
  if pSelectedUnit ~= nil then
    if not ( pSelectedUnit:GetMovesRemaining() > 0 ) then
      UILens.ClearLayerHexes( LensLayers.MOVEMENT_RANGE );
      UILens.ClearLayerHexes( LensLayers.MOVEMENT_ZONE_OF_CONTROL );
    end
  end
end

-- ===========================================================================
function OnBeginWonderReveal()
  Hide();
end

-------------------------------------------------------------------------------
function OnUnitSelectionChanged(player, unitId, locationX, locationY, locationZ, isSelected, isEditable)
  --print("UnitPanel::OnUnitSelectionChanged(): ",player,unitId,isSelected);
  if (isSelected) then
    m_selectedPlayerId = player;
    m_UnitId = unitId;
    m_primaryColor, m_secondaryColor = UI.GetPlayerColors( m_selectedPlayerId );
    m_combatResults = nil;

    Refresh(m_selectedPlayerId, m_UnitId)
    Controls.UnitPanelAlpha:SetToBeginning();
    Controls.UnitPanelAlpha:Play();
    Controls.UnitPanelSlide:SetToBeginning();
    Controls.UnitPanelSlide:Play();
  else
    m_selectedPlayerId  = nil;
    m_UnitId      = nil;
    m_primaryColor    = 0xdeadbeef;
    m_secondaryColor  = 0xbaadf00d;

    -- This event is raised on deselected units too; only hide if there
    -- is no selected units left.
    if (UI.GetHeadSelectedUnit() == nil) then
      Hide();
    end
  end

end

-------------------------------------------------------------------------------
-- Additional events to listen to in order to invalidate the data.
function OnUnitDamageChanged(player, unitId, damage)
  if(player == m_selectedPlayerId and unitId == m_UnitId) then
    Controls.UnitHealthMeter:SetAnimationSpeed( ANIMATION_SPEED );
    ContextPtr:RequestRefresh();    -- Set a refresh request, the UI will update on the next frame.
  end
end

-------------------------------------------------------------------------------
function OnUnitMoveComplete(player, unitId, x, y)
  if(player == m_selectedPlayerId and unitId == m_UnitId) then
    ContextPtr:RequestRefresh();    -- Set a refresh request, the UI will update on the next frame.
  end
end

-------------------------------------------------------------------------------
function OnUnitOperationDeactivated(player, unitId, hOperation, iData1)
  if(player == m_selectedPlayerId and unitId == m_UnitId) then
    ContextPtr:RequestRefresh();    -- Set a refresh request, the UI will update on the next frame.
  end
end

-------------------------------------------------------------------------------
function OnUnitOperationsCleared(player, unitId, hOperation, iData1)
  if(player == m_selectedPlayerId and unitId == m_UnitId) then
    ContextPtr:RequestRefresh();    -- Set a refresh request, the UI will update on the next frame.
  end
end

-------------------------------------------------------------------------------
function OnUnitOperationAdded(player, unitId, hOperation)
  if(player == m_selectedPlayerId and unitId == m_UnitId) then
    ContextPtr:RequestRefresh();    -- Set a refresh request, the UI will update on the next frame.
  end
end

-------------------------------------------------------------------------------
function OnUnitCommandStarted(player, unitId, hCommand, iData1)
  if (hCommand == UnitCommandTypes.CONDEMN_HERETIC) then
    UI.PlaySound("Unit_CondemnHeretic_2D");
  end
  if(player == m_selectedPlayerId and unitId == m_UnitId) then
    ContextPtr:RequestRefresh();    -- Set a refresh request, the UI will update on the next frame.
  end
end

-------------------------------------------------------------------------------
function OnUnitChargesChanged(player, unitId)
  if(player == m_selectedPlayerId and unitId == m_UnitId) then
    ContextPtr:RequestRefresh();    -- Set a refresh request, the UI will update on the next frame.
  end
end

-------------------------------------------------------------------------------
function OnUnitPromotionChanged(player, unitId)
  if(player == m_selectedPlayerId and unitId == m_UnitId) then
    ContextPtr:RequestRefresh();    -- Set a refresh request, the UI will update on the next frame.
  end
end

--------------------------------------------------------------------------------
-- UnitAction<idx> was clicked.
--------------------------------------------------------------------------------
function OnUnitActionClicked( actionType:number, actionHash:number, currentMode:number )

  if m_isOkayToProcess then
    local pSelectedUnit :table= UI.GetHeadSelectedUnit();
    if (pSelectedUnit ~= nil) then
      if (actionType == UnitCommandTypes.TYPE) then
        local eInterfaceMode = InterfaceModeTypes.NONE;
        local interfaceMode = GameInfo.UnitCommands[actionHash].InterfaceMode;
        if (interfaceMode) then
          eInterfaceMode = DB.MakeHash(interfaceMode);
        end

        if (eInterfaceMode ~= InterfaceModeTypes.NONE) then
          -- Must change to the interface mode or if we are already in that mode, the user wants to cancel.
          if (currentMode == eInterfaceMode) then
            UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
          else
            UI.SetInterfaceMode(eInterfaceMode);
          end
        else
          -- No mode needed, just do the operation
          UnitManager.RequestCommand( pSelectedUnit, actionHash );
        end
      else
        if (actionType == UnitOperationTypes.TYPE) then

          local eInterfaceMode = InterfaceModeTypes.NONE;
          local interfaceMode = GameInfo.UnitOperations[actionHash].InterfaceMode;
          if (interfaceMode) then
            eInterfaceMode = DB.MakeHash(interfaceMode);
          end

          if (eInterfaceMode ~= InterfaceModeTypes.NONE) then
            -- Must change to the interface mode or if we are already in that mode, the user wants to cancel.
            if (currentMode == eInterfaceMode) then
              UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
            else
              local tParameters = {};
              tParameters[UnitOperationTypes.PARAM_OPERATION_TYPE] = actionHash;
              UI.SetInterfaceMode(eInterfaceMode, tParameters);
            end
          else
            -- No mode needed, just do the operation
            UnitManager.RequestOperation( pSelectedUnit, actionHash );
          end
        end
      end
    end
  else
    print_debug("OnUnitActionClicked() but it's currently not okay to process. (Which is fine; unless it's the player's turn.)");
  end
end

-- ===========================================================================
-- UnitAction<BuildImprovement> was clicked.
-- ===========================================================================
function OnUnitActionClicked_BuildImprovement( improvementHash, dummy )
  if (m_isOkayToProcess) then
    local pSelectedUnit = UI.GetHeadSelectedUnit();
    if (pSelectedUnit ~= nil) then
      local tParameters = {};
      tParameters[UnitOperationTypes.PARAM_X] = pSelectedUnit:GetX();
      tParameters[UnitOperationTypes.PARAM_Y] = pSelectedUnit:GetY();
      tParameters[UnitOperationTypes.PARAM_IMPROVEMENT_TYPE] = improvementHash;

      UnitManager.RequestOperation( pSelectedUnit, UnitOperationTypes.BUILD_IMPROVEMENT, tParameters );
    end
    ContextPtr:RequestRefresh();
  end
end

-- ===========================================================================
-- UnitAction<WMDStrike> was clicked.
-- ===========================================================================
function OnUnitActionClicked_WMDStrike( eWMD, dummy )
  if (m_isOkayToProcess) then
    local pSelectedUnit = UI.GetHeadSelectedUnit();
    if (pSelectedUnit ~= nil) then
      local tParameters = {};
      tParameters[UnitOperationTypes.PARAM_WMD_TYPE] = eWMD;
      UI.SetInterfaceMode(InterfaceModeTypes.WMD_STRIKE, tParameters);
    end
    ContextPtr:RequestRefresh();
  end
end

-- ===========================================================================
-- Cancel action button was clicked for a spy
-- ===========================================================================
function OnUnitActionClicked_CancelSpyMission( actionHash, dummy )
  if (m_isOkayToProcess) then
    local pSelectedUnit = UI.GetHeadSelectedUnit();
    if (pSelectedUnit ~= nil) then
      LuaEvents.UnitPanel_CancelMission(pSelectedUnit:GetID());
    end
  end
end

-- ===========================================================================
-- UnitAction<EnterFormation> was clicked.
-- ===========================================================================
function OnUnitActionClicked_EnterFormation( unitInstance )
  if (m_isOkayToProcess) then
    local pSelectedUnit = UI.GetHeadSelectedUnit();
    if ( pSelectedUnit ~= nil and unitInstance ~= nil ) then
      local tParameters = {};
      tParameters[UnitCommandTypes.PARAM_UNIT_PLAYER] = unitInstance:GetOwner();
      tParameters[UnitCommandTypes.PARAM_UNIT_ID] = unitInstance:GetID();
      UnitManager.RequestCommand( pSelectedUnit, UnitCommandTypes.ENTER_FORMATION, tParameters );
    end
  end
end

-- ===========================================================================
--  UnitAction<MoveTo> was clicked.
-- ===========================================================================
function OnUnitActionClicked_MoveTo(dummy1, dummy2, currentMode:number)
  if currentMode ~= InterfaceModeTypes.MOVE_TO then
    UI.SetInterfaceMode(InterfaceModeTypes.MOVE_TO);
  end
end

-- ===========================================================================
--  UnitAction<FoundCity> was clicked.
-- ===========================================================================
function OnUnitActionClicked_FoundCity()
  if (m_isOkayToProcess) then
    local pSelectedUnit = UI.GetHeadSelectedUnit();
    if ( pSelectedUnit ~= nil ) then
      UnitManager.RequestOperation( pSelectedUnit, UnitOperationTypes.FOUND_CITY );
    end
  end
  if UILens.IsLayerOn( LensLayers.HEX_COLORING_WATER_AVAILABLITY ) then
    UILens.ToggleLayerOff(LensLayers.HEX_COLORING_WATER_AVAILABLITY);
  end
  UILens.SetActive("Default");
end

-- ===========================================================================
-- UnitAction<Promote> was clicked.
-- ===========================================================================
function ShowPromotionsList(tPromotions)
  local pUnit   :table  = UI.GetHeadSelectedUnit();
  if m_isOkayToProcess then
    local unitType = pUnit:GetUnitType();
    if GameInfo.Units[unitType].NumRandomChoices > 0 then
      m_PromotionListInstanceMgr:ResetInstances();
      for i, item in ipairs(tPromotions) do
        local promotionInstance = m_PromotionListInstanceMgr:GetInstance();
        local promotionDefinition = GameInfo.UnitPromotions[item];
        if (promotionDefinition ~= nil) then
          promotionInstance.PromotionName:SetText(Locale.Lookup(promotionDefinition.Name));
          promotionInstance.PromotionDescription:SetText(Locale.Lookup(promotionDefinition.Description));
          local promotionTierStr :string;
          if (promotionDefinition.Level == 1) then
            promotionTierStr = "I";
          elseif (promotionDefinition.Level == 2) then
            promotionTierStr = "II";
          elseif (promotionDefinition.Level == 3) then
            promotionTierStr = "III";
          elseif (promotionDefinition.Level == 4) then
            promotionTierStr = "IV";
          elseif (promotionDefinition.Level == 5) then
            promotionTierStr = "V";
          end
          promotionInstance.PromotionTier:SetText(promotionTierStr);
        end

        local ePromotion = item;
        promotionInstance.PromotionSlot:RegisterCallback( Mouse.eLClick, OnPromoteUnit );
        promotionInstance.PromotionSlot:SetVoid1( ePromotion );
      end
      Controls.PromotionList:CalculateSize();
      Controls.PromotionScrollPanel:CalculateInternalSize();
      Controls.PromotionList:ReprocessAnchoring();
      Controls.PromotionPanel:SetHide(false);

      local pUnit = UI.GetHeadSelectedUnit();
      if (pUnit ~= nil) then
        local bCanStart = UnitManager.CanStartCommand( pUnit, UnitCommandTypes.NAME_UNIT, true);
        local canChangeName = GameCapabilities.HasCapability("CAPABILITY_RENAME");
        if(bCanStart and canChangeName) then
          local yOffset = Controls.PromotionPanel:GetSizeY();
          Controls.VeteranNamePanel:SetOffsetY(yOffset);
          Controls.VeteranNamePanel:SetHide(false);
          RandomizeName();
        else
          Controls.VeteranNamePanel:SetOffsetY(0);
          Controls.VeteranNamePanel:SetHide(true);
        end
      end
    else
      LuaEvents.UnitPanel_PromoteUnit();
    end
  end
end

--------------------------------------------------------------------------------
-- Selected Promotion was clicked.
--------------------------------------------------------------------------------
function OnPromoteUnit(ePromotion)
  if (m_isOkayToProcess) then
    local pSelectedUnit = UI.GetHeadSelectedUnit();
    if (pSelectedUnit ~= nil) then
      local tParameters = {};
      tParameters[UnitCommandTypes.PARAM_PROMOTION_TYPE] = ePromotion;
      UnitManager.RequestCommand( pSelectedUnit, UnitCommandTypes.PROMOTE, tParameters );
    end
  end
end

-- ===========================================================================
--  Prompt if the player really wants to force remove a unit.
-- ===========================================================================
function OnNoDelete()
    m_DeleteInProgress = false;
end

function OnPromptToDeleteUnit()
  local pUnit   :table  = UI.GetHeadSelectedUnit();

    if m_DeleteInProgress then
        return;
    end

  if(pUnit) then
    -- Only show the prompt if it's possible to delete this unit
    local bCanStart = UnitManager.CanStartCommand( pUnit, UnitCommandTypes.DELETE, true);
    if bCanStart then
      local unitName  :string = GameInfo.Units[pUnit:GetUnitType()].Name;
      local msg   :string = Locale.Lookup("LOC_HUD_UNIT_PANEL_ARE_YOU_SURE_DELETE", unitName);
      -- Pass the unit ID through, the user can take their time in the dialog and it is possible that the selected unit will change
      local unitID = pUnit:GetComponentID();
      local popup = PopupDialogInGame:new( "UnitPanelPopup" );
      popup:ShowYesNoDialog( msg, function() OnDeleteUnit(unitID) end, OnNoDelete);
      m_DeleteInProgress = true;
    end
  end
end

-- ===========================================================================
--  Delete the unit
--  Resets lens to turn off any that are for the unit (e.g., settler)
-- ===========================================================================
function OnDeleteUnit(unitID : table)
    m_DeleteInProgress = false;

  local pUnit   :table  = UnitManager.GetUnit(unitID.player, unitID.id);
  if (pUnit ~= nil) then
    UnitManager.RequestCommand( pUnit, UnitCommandTypes.DELETE );
  end

  --  TODO: Re-eval if below is needed, SelectedUnit may now handle this even with kUnit==nil there:
  if UILens.IsLayerOn( LensLayers.HEX_COLORING_WATER_AVAILABLITY ) then
    UILens.ToggleLayerOff( LensLayers.HEX_COLORING_WATER_AVAILABLITY );
  elseif UILens.IsLayerOn( LensLayers.HEX_COLORING_GREAT_PEOPLE ) then
    UILens.ToggleLayerOff( LensLayers.HEX_COLORING_GREAT_PEOPLE );
  end
  UILens.SetActive("Default");
end

--------------------------------------------------------------------------------
-- Unit Veterancy / Unique name
---------------------------------------------------------------------------------
function OnNameUnit()
  local pUnit = UI.GetHeadSelectedUnit();
  if (pUnit ~= nil) then
    Controls.VeteranNamePanel:SetOffsetY(0);
    Controls.VeteranNamePanel:SetHide(false);
    RandomizeName();
  end
end

--------------------------------------------------------------------------------
function RandomizeName()
  local pUnit = UI.GetHeadSelectedUnit();
  if (pUnit ~= nil) then
    m_namePrefix = GetRandomNamePrefix();
    m_nameSuffix = GetRandomNameSuffix();
    m_FullVeteranName = string.format("{LOC_UNITNAME_BASE_TEMPLATE << {%s} << {%s}}", m_namePrefix, m_nameSuffix);
    Controls.VeteranNameField:SetText(Locale.Lookup(m_FullVeteranName));
  end
end

--------------------------------------------------------------------------------
function RandomizeNamePrefix()
  m_namePrefix = GetRandomNamePrefix();
  m_FullVeteranName = string.format("{LOC_UNITNAME_BASE_TEMPLATE << {%s} << {%s}}", m_namePrefix, m_nameSuffix);

  Controls.VeteranNameField:SetText(Locale.Lookup(m_FullVeteranName));
end

--------------------------------------------------------------------------------
function RandomizeNameSuffix()
  local pUnit = UI.GetHeadSelectedUnit();
  if (pUnit ~= nil) then
    m_nameSuffix = GetRandomNameSuffix();
    m_FullVeteranName = string.format("{LOC_UNITNAME_BASE_TEMPLATE << {%s} << {%s}}", m_namePrefix, m_nameSuffix);

    Controls.VeteranNameField:SetText(Locale.Lookup(m_FullVeteranName));
  end
end

--------------------------------------------------------------------------------
function GetRandomNamePrefix()
  if (m_PrefixNames == nil) then
    m_PrefixNames = MakeUnitNameTable( "PREFIX_ALL" );
  end

  local prefixIndex = math.random(#m_PrefixNames);
  local prefixTextKey = m_PrefixNames[prefixIndex];
  
  local pUnit = UI.GetHeadSelectedUnit();
  if (pUnit ~= nil) then
    local unitClass = GameInfo.Units[pUnit:GetUnitType()].PromotionClass;
    local unitDomain = GameInfo.Units[pUnit:GetUnitType()].Domain;
    if (unitDomain == "DOMAIN_LAND") then
      if (unitClass == "PROMOTION_CLASS_MONK") then
        if (m_PrefixNamesMonk == nil) then
          m_PrefixNamesMonk = MakeUnitNameTable( "PREFIX_MONK" );
        end
        prefixIndex = math.random(#m_PrefixNamesMonk);
        prefixTextKey = m_PrefixNamesMonk[prefixIndex];
      end
    end
  end
 
  return prefixTextKey;
end

--------------------------------------------------------------------------------
function GetRandomNameSuffix()

  if (m_SuffixNames == nil) then
    m_SuffixNames = MakeUnitNameTable( "SUFFIX_ALL" );
  end

  local suffixIndex = math.random(#m_SuffixNames);
  local suffixTextKey = m_SuffixNames[suffixIndex];

  local pUnit = UI.GetHeadSelectedUnit();
  if (pUnit ~= nil) then
    local unitClass = GameInfo.Units[pUnit:GetUnitType()].PromotionClass;
    local unitDomain = GameInfo.Units[pUnit:GetUnitType()].Domain;
    if (unitDomain == "DOMAIN_LAND") then
      if    (unitClass == "PROMOTION_CLASS_RECON") then
        if (m_SuffixNamesRecon == nil) then
          m_SuffixNamesRecon = MakeUnitNameTable( "SUFFIX_RECON" );
        end
        suffixIndex = math.random(#m_SuffixNamesRecon);
        suffixTextKey = m_SuffixNamesRecon[suffixIndex];
      elseif  (unitClass == "PROMOTION_CLASS_LIGHT_CAVALRY" or unitClass == "PROMOTION_CLASS_HEAVY_CAVALRY") then
        if (m_SuffixNamesCavalry == nil) then
          m_SuffixNamesCavalry = MakeUnitNameTable( "SUFFIX_CAVALRY" );
        end
        suffixIndex = math.random(#m_SuffixNamesCavalry);
        suffixTextKey = m_SuffixNamesCavalry[suffixIndex];
      elseif  (unitClass == "PROMOTION_CLASS_RANGED" or unitClass == "PROMOTION_CLASS_SIEGE") then
        if (m_SuffixNamesRanged == nil) then
          m_SuffixNamesRanged = MakeUnitNameTable( "SUFFIX_RANGED" );
        end
        suffixIndex = math.random(#m_SuffixNamesRanged);
        suffixTextKey = m_SuffixNamesRanged[suffixIndex];
      elseif (unitClass == "PROMOTION_CLASS_MONK") then
        if (m_SuffixNamesMonk == nil) then
          m_SuffixNamesMonk = MakeUnitNameTable( "SUFFIX_MONK" );
        end
        suffixIndex = math.random(#m_SuffixNamesMonk);
        suffixTextKey = m_SuffixNamesMonk[suffixIndex];
      end
    elseif (unitDomain == "DOMAIN_SEA") then
      if (m_SuffixNamesNaval == nil) then
        m_SuffixNamesNaval = MakeUnitNameTable( "SUFFIX_NAVAL" );
      end
      suffixIndex = math.random(#m_SuffixNamesNaval);
      suffixTextKey = m_SuffixNamesNaval[suffixIndex];
    elseif (unitDomain == "DOMAIN_AIR") then
      if (m_SuffixNamesAir == nil) then
        m_SuffixNamesAir = MakeUnitNameTable( "SUFFIX_AIR" );
      end
      suffixIndex = math.random(#m_SuffixNamesAir);
      suffixTextKey = m_SuffixNamesAir[suffixIndex];
    end
  end

  return suffixTextKey;
end

--------------------------------------------------------------------------------
function ConfirmVeteranName()
  local pSelectedUnit = UI.GetHeadSelectedUnit();
  if (pSelectedUnit ~= nil) then
    local tParameters = {};
    tParameters[UnitCommandTypes.PARAM_NAME] = m_FullVeteranName;

    if (m_FullVeteranName ~= "") then
      UnitManager.RequestCommand( pSelectedUnit, UnitCommandTypes.NAME_UNIT, tParameters );
    end
  end
  Controls.VeteranNamePanel:SetHide(true);
  UI.PlaySound("Receive_Map_Boost");
end

--------------------------------------------------------------------------------
function EditCustomVeteranName()
  m_FullVeteranName = Controls.VeteranNameField:GetText();
end

--------------------------------------------------------------------------------
function MakeUnitNameTable( nameType :string )
  local unitNameTable :table = {};
  for row in GameInfo.UnitNames() do
    if ( row.NameType == nameType ) then
      table.insert( unitNameTable, row.TextKey );
    end
  end

  return unitNameTable;
end

-- ===========================================================================
function OnPlayerTurnDeactivated( ePlayer:number )
  if ePlayer == Game.GetLocalPlayer() then
    m_isOkayToProcess = false;
  end
end

-- ===========================================================================
function OnPlayerTurnActivated( ePlayer:number, isFirstTime:boolean )
  if ePlayer == Game.GetLocalPlayer() then
    ShowHideSelectedUnit();
  end
end

-- ===========================================================================
function OnPlayerChangeClose( ePlayer:number )

  local isPaused:boolean = GameConfiguration.IsPaused();
  print_debug("OnPlayerChangeClose: " .. ePlayer .. ", GameConfiguration.IsPaused()=" .. tostring(isPaused));
  if(isPaused) then
    Events.GameConfigChanged.Add(OnGameConfigChanged_Hotseat_Paused);
  end
end

-- ===========================================================================
function OnGameConfigChanged_Hotseat_Paused()
  Events.GameConfigChanged.Remove(OnGameConfigChanged_Hotseat_Paused);
  if(not GameConfiguration.IsPaused()) then
    ShowHideSelectedUnit();
  end
end

-- ===========================================================================
function ShowHideSelectedUnit()
  m_isOkayToProcess = true;
  local pSelectedUnit :table = UI.GetHeadSelectedUnit();
  if pSelectedUnit ~= nil then
    m_selectedPlayerId        = pSelectedUnit:GetOwner();
    m_UnitId            = pSelectedUnit:GetID();
    m_primaryColor, m_secondaryColor= UI.GetPlayerColors( m_selectedPlayerId );
    Refresh( m_selectedPlayerId, m_UnitId );
  else
    Hide();
  end
end

-- ===========================================================================
function OnPantheonFounded( ePlayer:number )
  if(ePlayer == m_selectedPlayerId) then
    ContextPtr:RequestRefresh();    -- Set a refresh request, the UI will update on the next frame.
  end
end

-- ===========================================================================
function OnPhaseBegin()
  ContextPtr:RequestRefresh();
end

-- ===========================================================================
function OnContextInitialize( isHotload : boolean)
  if isHotload then
    OnPlayerTurnActivated( Game.GetLocalPlayer(), true ) ;  -- Fake player activated call.
  end
end

-- ===========================================================================
function OnCitySelectionChanged(owner, ID, i, j, k, bSelected, bEditable)
  Hide();
end

-- ===========================================================================
--  Game Engine Event
--  Called in response to when a religion unit activates a charge.
-- ===========================================================================
function OnCityReligionFollowersChanged( playerID: number, cityID : number, eVisibility : number, city)
  --print("OnCityReligionFollowersChanged",playerID, cityID , eVisibility , city);
end

-- ===========================================================================
--  Game Engine Event
--  Called in response to when a Great Work is moved.
-- ===========================================================================
function OnGreatWorkMoved(fromCityOwner, fromCityID, toCityOwner, toCityID, buildingID, greatWorkType)
  if(fromCityOwner == m_selectedPlayerId or toCityOwner == m_selectedPlayerId) then
    ContextPtr:RequestRefresh();    -- Set a refresh request, the UI will update on the next frame.
  end
end

-- ===========================================================================
--  Input Hotkey Event
-- ===========================================================================
function OnInputActionTriggered( actionId )
  if ( not m_isOkayToProcess or ContextPtr:IsHidden() ) then
    return;
  end
  -- If an entry with this actionId exists, call the function associated with it.
  if m_kHotkeyActions[actionId] ~= nil then
        UI.PlaySound("Play_UI_Click");
        if m_kSoundCV1[actionId] ~= nil and m_kSoundCV1[actionId] ~= "" then
            UI.PlaySound(m_kSoundCV1[actionId]);
        end
    m_kHotkeyActions[actionId](m_kHotkeyCV1[actionId], m_kHotkeyCV2[actionId]);
  end
    -- "Delete" Hotkey doesn't appear in UnitOperations.xml, we need to hotwire it here
    if m_DeleteHotkeyId ~= nil and (actionId == m_DeleteHotkeyId) then
        OnPromptToDeleteUnit();
    end
  -- "Attack" Hotkey is pressed; should only work if combat evaluation is displayed. There is no action for basic attacks, necissitating this special case.
  if m_combatResults ~= nil and m_AttackHotkeyId ~= nil and (actionId == m_AttackHotkeyId) then
    MoveUnitToPlot( UI.GetHeadSelectedUnit(), m_locX, m_locY );
  end
end

-- ===========================================================================
function OnUnitRemovedFromMap( playerID: number, unitID : number )
  if(playerID == m_selectedPlayerId and unitID == m_UnitId) then
    Hide();
  end
end

-- ===========================================================================
function ShowCombatAssessment( )

  --visualize the combat differences
  if (m_combatResults ~= nil) then
    local attacker = m_combatResults[CombatResultParameters.ATTACKER];
    local defender = m_combatResults[CombatResultParameters.DEFENDER];

    local iAttackerCombatStrength = attacker[CombatResultParameters.COMBAT_STRENGTH];
    local iDefenderCombatStrength = defender[CombatResultParameters.COMBAT_STRENGTH];
    local iAttackerBonus      = attacker[CombatResultParameters.STRENGTH_MODIFIER];
    local iDefenderBonus      = defender[CombatResultParameters.STRENGTH_MODIFIER];
    local iAttackerStrength = iAttackerCombatStrength + iAttackerBonus;
    local iDefenderStrength = iDefenderCombatStrength + iDefenderBonus;
    local extraDamage;
    local isSafe = false;
    for row in GameInfo.GlobalParameters() do
      if(row.Name == "COMBAT_MAX_EXTRA_DAMAGE") then
        extraDamage = row.Value;
        break;
      end
    end
    if (attacker[CombatResultParameters.FINAL_DAMAGE_TO] + (extraDamage/2) < attacker[CombatResultParameters.MAX_HIT_POINTS]) then
      if (iDefenderStrength > 0) then
      isSafe = true;
    end
    end

    local combatAssessmentStr :string = "";
    local damageToDefender = defender[CombatResultParameters.DAMAGE_TO];
    local defenseDamageToDefender = defender[CombatResultParameters.DEFENSE_DAMAGE_TO];
    local defenderHitpoints = defender[CombatResultParameters.MAX_HIT_POINTS];
    local damagePercentToDefender = (damageToDefender / defenderHitpoints) * 100;
    local damageToAttacker = attacker[CombatResultParameters.DAMAGE_TO];
    local attackerHitpoints = attacker[CombatResultParameters.MAX_HIT_POINTS];
    local damagePercentToAttacker = (damageToAttacker / attackerHitpoints) * 100;
    local combatType = m_combatResults[CombatResultParameters.COMBAT_TYPE];

    --WND status is actually not piped through correctly yet since hashes are not generated.
    --local wndStatus = m_combatResults[CombatResultParameters.WMD_STATUS];
 
    if (m_targetData.HasDefenses == false ) then
      if( m_targetData.HasImprovementOrDistrict ) then
 
        --If this was an attempted pillage base outcome text on whether the pillage succeeded and the amount of damage to the attacker
        local bPillaged = m_combatResults[CombatResultParameters.LOCATION_PILLAGED];
        if( bPillaged ) then
          if( damageToAttacker > 0 ) then
            combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_MINOR_VICTORY");
          else
            combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_DECISIVE_VICTORY");
          end
        else
          combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_MAJOR_DEFEAT");	
        end
      else
        --This was an attack on a tile without anything to pillage. Base outcome text on damage to attacker alone.
        if( damageToAttacker > 0 ) then
          combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_STALEMATE");
        else
          combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_DECISIVE_VICTORY");
        end
      end
      
      ShowCombatVictoryBanner();
      
 
    elseif (damageToDefender > 0 ) then
    -- BPF: if it's a ranged attack we want to display the outcome differently because there is no reciprocal attack
      if ( combatType == CombatTypes.RANGED or combatType == CombatTypes.BOMBARD ) then
        -- if attacking a defensible district, show a different outcome
        if (defender[CombatResultParameters.MAX_DEFENSE_HIT_POINTS] > 0) then
          if (damageToDefender > defenseDamageToDefender) then
            if (defender[CombatResultParameters.FINAL_DAMAGE_TO] >= defenderHitpoints) then
              combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_TOTAL_CITY_DAMAGE");
              ShowCombatVictoryBanner();
            else
              if (damagePercentToDefender < 25) then
                combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_MINOR_CITY_DAMAGE");
                ShowCombatStalemateBanner();
              else
                combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_MAJOR_CITY_DAMAGE");
                ShowCombatVictoryBanner();
              end
            end
          else
            local defenseHitpoints = defender[CombatResultParameters.MAX_DEFENSE_HIT_POINTS];
            local damagePercentToDefenses = (defenseDamageToDefender / defenseHitpoints) * 100;
            if (defender[CombatResultParameters.FINAL_DEFENSE_DAMAGE_TO] >= defenseHitpoints) then
              combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_TOTAL_WALL_DAMAGE");
              ShowCombatVictoryBanner();
            else
              if (damagePercentToDefenses < 25) then
                combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_MINOR_WALL_DAMAGE");
                ShowCombatStalemateBanner();
              else
                combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_MAJOR_WALL_DAMAGE");
                ShowCombatVictoryBanner();
              end
            end
          end
        else
          if (damageToDefender >= defenderHitpoints) then
            combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_DECISIVE_VICTORY");
            ShowCombatVictoryBanner();
          else
            if (damagePercentToDefender < 25) then
              combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_MINOR_VICTORY");
              ShowCombatStalemateBanner();
            else
              combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_MAJOR_VICTORY");
              ShowCombatVictoryBanner();
            end
          end
        end
      else  --non ranged attacks
        if (damageToDefender >= defenderHitpoints) then
          combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_DECISIVE_VICTORY");
          ShowCombatVictoryBanner();
        else
          -- if the defender is a defensible district
          if (defender[CombatResultParameters.MAX_DEFENSE_HIT_POINTS] > 0) then
            local attackingDamage = math.max(damageToDefender, defenseDamageToDefender);
            local combatDifference = attackingDamage - damageToAttacker;
            if (combatDifference > 0 ) then
              if (combatDifference < 3) then
                combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_STALEMATE");
                ShowCombatStalemateBanner();
              else
                if (combatDifference < 10) then
                  combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_MINOR_VICTORY");
                  ShowCombatVictoryBanner();
                else
                  combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_MAJOR_VICTORY");
                  ShowCombatVictoryBanner();
                end
              end
            else
              if (combatDifference > -3) then
                combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_STALEMATE");
                ShowCombatStalemateBanner();
              else
                if (combatDifference > -10) then
                  combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_MINOR_DEFEAT");
                  ShowCombatDefeatBanner();
                else
                  combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_MAJOR_DEFEAT");
                  ShowCombatDefeatBanner();
                end
              end
            end
          else  --it's a unit
            local combatDifference = damageToDefender - damageToAttacker;
            if (combatDifference > 0 ) then
              if (combatDifference < 3) then
                combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_STALEMATE");
                ShowCombatStalemateBanner();
              else
                if (combatDifference < 10) then
                  combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_MINOR_VICTORY");
                  ShowCombatVictoryBanner();
                else
                  combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_MAJOR_VICTORY");
                  ShowCombatVictoryBanner();
                end
              end
            else
              if (combatDifference > -3) then
                combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_STALEMATE");
                ShowCombatStalemateBanner();
              else
                if (combatDifference > -10) then
                  combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_MINOR_DEFEAT");
                  ShowCombatDefeatBanner();
                else
                  combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_MAJOR_DEFEAT");
                  ShowCombatDefeatBanner();
                end
              end
            end
          end
        end
      end
    else
      if (iDefenderStrength > 0) then
      combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_INEFFECTIVE");
      ShowCombatStalemateBanner();
      else
        combatAssessmentStr = Locale.Lookup("LOC_HUD_UNIT_PANEL_OUTCOME_DECISIVE_VICTORY");
        ShowCombatVictoryBanner();
      end
    end

    Controls.CombatAssessmentText:SetText(Locale.ToUpper(combatAssessmentStr));

    -- Show interceptor information
    local interceptorData = m_combatResults[CombatResultParameters.INTERCEPTOR];
    local interceptorID = interceptorData[CombatResultParameters.ID];
    local defenderID = defender[CombatResultParameters.ID];
    local pkInterceptor = UnitManager.GetUnit(interceptorID.player, interceptorID.id);
    if (pkInterceptor ~= nil and interceptorID.id ~= defenderID.id) then
      local interceptorStrength = interceptorData[CombatResultParameters.COMBAT_STRENGTH];
      local interceptorStrengthModifier = interceptorData[CombatResultParameters.STRENGTH_MODIFIER];
      local modifiedStrength = interceptorStrength + interceptorStrengthModifier;
      Controls.InterceptorName:SetText(m_targetData.InterceptorName);
      Controls.InterceptorStrength:SetText(modifiedStrength);

      UpdateInterceptorModifiers(0);

      -- Update interceptor health meters
      local percent   :number = 1 - GetPercentFromDamage( m_targetData.InterceptorDamage + m_targetData.InterceptorPotentialDamage, m_targetData.InterceptorMaxDamage);
      local shadowPercent :number = 1 - GetPercentFromDamage( m_targetData.InterceptorDamage, m_targetData.InterceptorMaxDamage );
      RealizeHealthMeter( Controls.InterceptorHealthMeter, percent, Controls.InterceptorHealthMeterShadow, shadowPercent );

      Controls.InterceptorGrid:SetHide(false);
    else
      Controls.InterceptorGrid:SetHide(true);
    end

    -- Show anti-air information if the anti-air unit is not the same as the defender
    local antiAirData = m_combatResults[CombatResultParameters.ANTI_AIR];
    local antiAirID = antiAirData[CombatResultParameters.ID];
    local pkAntiAir = UnitManager.GetUnit(antiAirID.player, antiAirID.id);
    if (pkAntiAir ~= nil and antiAirID.id ~= defenderID.id) then
      local antiAirStrength = m_combatResults[CombatResultParameters.ANTI_AIR][CombatResultParameters.COMBAT_STRENGTH];
      local antiAirStrengthModifier = m_combatResults[CombatResultParameters.ANTI_AIR][CombatResultParameters.STRENGTH_MODIFIER];
      Controls.AAName:SetText(m_targetData.AntiAirName);
      local modifiedStrength = antiAirStrength + antiAirStrengthModifier;
      Controls.AAStrength:SetText(modifiedStrength);

      UpdateAntiAirModifiers(0);

      Controls.AAGrid:SetHide(false);
    else
      Controls.AAGrid:SetHide(true);
    end
  end
end

-- ===========================================================================
function ShowCombatStalemateBanner()
  Controls.BannerDefeat:SetHide(true);
  Controls.BannerStalemate:SetHide(false);
  Controls.BannerVictory:SetHide(true);
end

function ShowCombatVictoryBanner()
  Controls.BannerDefeat:SetHide(true);
  Controls.BannerStalemate:SetHide(true);
  Controls.BannerVictory:SetHide(false);
end

function ShowCombatDefeatBanner()
  Controls.BannerDefeat:SetHide(false);
  Controls.BannerStalemate:SetHide(true);
  Controls.BannerVictory:SetHide(true);
end

-- ===========================================================================
function OnHideCombat()
  Refresh(m_selectedPlayerId, m_UnitId);
  Controls.UnitPanelBaseContainer:SetHide(true);
end

-- ===========================================================================
function InspectWhatsBelowTheCursor()
  local localPlayerID     :number = Game.GetLocalPlayer();
  if (localPlayerID == -1) then
    return;
  end

  local pPlayerVis  = PlayersVisibility[localPlayerID];
  if (pPlayerVis == nil) then
    return false;
  end

  -- do not show the combat preview for non-combat units
  local selectedPlayerUnit  :table  = UI.GetHeadSelectedUnit();
  if (selectedPlayerUnit ~= nil) then
    if (selectedPlayerUnit:GetCombat() == 0 and selectedPlayerUnit:GetReligiousStrength() == 0) then
      return;
    end
  end

  local plotId = UI.GetCursorPlotID();
  if (plotId ~= m_plotId) then
    m_plotId = plotId;
    local plot = Map.GetPlotByIndex(plotId);
    if plot ~= nil then
      local bIsVisible  = pPlayerVis:IsVisible(m_plotId);
      if (bIsVisible) then
        InspectPlot(plot);
      else
        OnShowCombat(false);
      end
    end
  end
end

-- ===========================================================================
function GetDistrictFromCity( pCity:table )
  if (pCity ~= nil) then
    local cityOwner = pCity:GetOwner();
    local districtId = pCity:GetDistrictID();
    local pPlayer = Players[cityOwner];
    if (pPlayer ~= nil) then
      local pDistrict = pPlayer:GetDistricts():FindID(districtId);
      if (pDistrict ~= nil) then
        return pDistrict;
      end
    end
  end
  return nil;
end

-- ===========================================================================
function ReInspectWhatsBelowTheCursor()
  m_plotId = INVALID_PLOT_ID;
  InspectWhatsBelowTheCursor();
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
--  If mouse/touch is giving focus to a unit flag, that takes precedence over
--  the hex which may be behind the flag (likey a hex "above" the current one)
function OnUnitFlagPointerEntered( playerID:number, unitID:number )

  m_isFlagFocused = true;   -- Some flag (could be own) is focused.

  --make sure it's not one of our units
  -- And Game Core is not busy, the simulation currently needs to run on the Game Core side for accurate results.
  local isValidToShow :boolean = (playerID ~= Game.GetLocalPlayer() and not UI.IsGameCoreBusy());

  if (isValidToShow) then

    if (UI.GetInterfaceMode() == InterfaceModeTypes.CITY_RANGE_ATTACK) then
      local attackingCity = UI.GetHeadSelectedCity();
      if (attackingCity ~= nil) then
        local pDistrict = GetDistrictFromCity(attackingCity);
        if (pDistrict ~= nil) then
          local pDefender = UnitManager.GetUnit(playerID, unitID);
          if (pDefender ~= nil) then
            m_combatResults = CombatManager.SimulateAttackVersus( pDistrict:GetComponentID(), pDefender:GetComponentID() );
            isValidToShow = ReadTargetData(attackingCity);		
          end
        end
      end
    elseif (UI.GetInterfaceMode() == InterfaceModeTypes.DISTRICT_RANGE_ATTACK) then
      local pDistrict = UI.GetHeadSelectedDistrict();
      if (pDistrict ~= nil) then
        local pDefender = UnitManager.GetUnit(playerID, unitID);
        if (pDefender ~= nil) then
          m_combatResults = CombatManager.SimulateAttackVersus( pDistrict:GetComponentID(), pDefender:GetComponentID() );
          isValidToShow = ReadTargetData(pDistrict);		
        end
      end
    else
      local attackerUnit = UI.GetHeadSelectedUnit();
      if (attackerUnit ~= nil) then

        -- do not show the combat preview for non-combat or embarked units
        if (attackerUnit:GetCombat() == 0 and attackerUnit:GetReligiousStrength() == 0) then
          return;
        end

        local eCombatType = nil;
        if (UI.GetInterfaceMode() == InterfaceModeTypes.RANGE_ATTACK) then
          eCombatType = CombatTypes.RANGED;
          if (attackerUnit:GetBombardCombat() > attackerUnit:GetRangedCombat()) then
            eCombatType = CombatTypes.BOMBARD;
          end
        end

        local pDefender = UnitManager.GetUnit(playerID, unitID);
        if (pDefender ~= nil) then
          m_combatResults = CombatManager.SimulateAttackVersus( attackerUnit:GetComponentID(), pDefender:GetComponentID(), eCombatType );
          isValidToShow = ReadTargetData(attackerUnit);
        end
      end
    end
  end

  OnShowCombat( isValidToShow );

end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnUnitFlagPointerExited( playerID:number, unitID:number )
  m_isFlagFocused = false;
  ReInspectWhatsBelowTheCursor();
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnCityRangeStrikeClicked( playerID:number, unitID:number )

end

-- ===========================================================================
--  plot  The plot to inspect.
--  RETURNS tree if there is something to be shown.
function InspectPlot( plot:table )

  local isValidToShow = false;

  local localPlayerID = Game.GetLocalPlayer();
  if (localPlayerID == -1) then
    return;
  end

  if (UI.GetInterfaceMode() == InterfaceModeTypes.CITY_RANGE_ATTACK) then
    local pCity = UI.GetHeadSelectedCity();
    if (pCity == nil) then
      return false;
    end
    local pDistrict = GetDistrictFromCity(pCity);
    if (pDistrict == nil) then
      return false;
    end
    GetCombatResults( pDistrict:GetComponentID(), plot:GetX(), plot:GetY() )
    isValidToShow = ReadTargetData(pDistrict);

  elseif (UI.GetInterfaceMode() == InterfaceModeTypes.DISTRICT_RANGE_ATTACK) then
    local pDistrict = UI.GetHeadSelectedDistrict();
    if (pDistrict == nil) then
      return false;
    end
    GetCombatResults( pDistrict:GetComponentID(), plot:GetX(), plot:GetY() )
    isValidToShow = ReadTargetData(pDistrict);

  else
    local pUnit = UI.GetHeadSelectedUnit();
    if (pUnit == nil) then
      return false;
    end

    GetCombatResults( pUnit:GetComponentID(), plot:GetX(), plot:GetY() )
    isValidToShow = ReadTargetData(pUnit);
  end

  OnShowCombat( isValidToShow );

end

function IsTargetCombat(targetData)
  if
  (
    (targetData.Combat > 0)
  or  (targetData.RangedCombat > 0)
  or  (targetData.BombardCombat > 0)
  ) then
    return true;
  end
  return false;
end

function IsTargetReligiousCombat(targetData)
  if ( targetData.ReligiousCombat > 0 ) then
    return true;
  end
  return false;
end

function IsAttackerReligiousCombat(attacker)
  if ( attacker:GetReligiousStrength() > 0 ) then
    return true;
  end
  return false;
end

-- ===========================================================================

--Populate the target data for a unit
function ReadTargetData_Unit(pkDefender)
  -- Build target data for a unit
  local potentialDamage = m_combatResults[CombatResultParameters.DEFENDER][CombatResultParameters.DAMAGE_TO];
  local unitGreatPerson = pkDefender:GetGreatPerson();
  m_targetData.Name               = Locale.Lookup( pkDefender:GetName() );
  m_targetData.IconName           = GetUnitPortraitPrefix( pkDefender:GetOwner() )..GameInfo.Units[pkDefender:GetUnitType()].UnitType.."_PORTRAIT";
  m_targetData.FallbackIconName   = "ICON_"..GameInfo.Units[pkDefender:GetUnitType()].UnitType.."_PORTRAIT";
  m_targetData.Combat             = pkDefender:GetCombat();
  m_targetData.RangedCombat       = pkDefender:GetRangedCombat();
  m_targetData.BombardCombat      = pkDefender:GetBombardCombat();
  m_targetData.AntiAirCombat      = pkDefender:GetAntiAirCombat();
  m_targetData.ReligiousCombat    = pkDefender:GetReligiousStrength();
  m_targetData.Range              = pkDefender:GetRange();
  m_targetData.Damage             = pkDefender:GetDamage();
  m_targetData.MaxDamage          = pkDefender:GetMaxDamage();
  m_targetData.PotentialDamage    = potentialDamage;
  m_targetData.BuildCharges       = pkDefender:GetBuildCharges();
  m_targetData.SpreadCharges      = pkDefender:GetSpreadCharges();
  m_targetData.HealCharges        = pkDefender:GetReligiousHealCharges();
  m_targetData.ReligiousStrength  = pkDefender:GetReligiousStrength();
  m_targetData.GreatPersonActionCharges = unitGreatPerson:GetActionCharges();
  m_targetData.Moves              = pkDefender:GetMovesRemaining();
  m_targetData.MaxMoves           = pkDefender:GetMaxMoves();
  m_targetData.UnitType           = pkDefender:GetUnitType();
  m_targetData.UnitID             = pkDefender:GetID();
  m_targetData.HasDefenses        = true;
end

-- Populate the target data for a district that is the defender (it can defend it's self)
function ReadTargetData_District(pDistrict)
  --Build the target data for a district that can defend its self
  local targetName = "";
  local owningCity = pDistrict:GetCity();
  local districtOwner = pDistrict:GetOwner();
  local districtInfo = GameInfo.Districts[pDistrict:GetType()];

  if (not districtInfo.CityCenter) then
    targetName = Locale.Lookup(districtInfo.Name);
  elseif (owningCity ~= nil) then
    targetName = owningCity:GetName();
  else
    UI.DataError("Failed to find target name for district.");
  end

  local combat        :number = pDistrict:GetBaseDefenseStrength();
  local damage        :number = pDistrict:GetDamage(DefenseTypes.DISTRICT_GARRISON);
  local maxDamage        :number = pDistrict:GetMaxDamage(DefenseTypes.DISTRICT_GARRISON);
  local wallDamage      :number = pDistrict:GetDamage(DefenseTypes.DISTRICT_OUTER)
  local wallMaxDamage      :number = pDistrict:GetMaxDamage(DefenseTypes.DISTRICT_OUTER);
  local potentialDamage    :number = m_combatResults[CombatResultParameters.DEFENDER][CombatResultParameters.DAMAGE_TO];
  local potentialWallDamage  :number = m_combatResults[CombatResultParameters.DEFENDER][CombatResultParameters.DEFENSE_DAMAGE_TO];

  -- populate the target data table
  m_targetData.Name            = targetName;
  m_targetData.Combat            = combat;
  m_targetData.RangedCombat        = pDistrict:GetAttackStrength();
  m_targetData.Damage            = damage;
  m_targetData.MaxDamage          = maxDamage;
  m_targetData.WallDamage          = wallDamage;
  m_targetData.MaxWallDamage        = wallMaxDamage;
  m_targetData.PotentialDamage      = potentialDamage;
  m_targetData.PotentialWallDamage    = potentialWallDamage;
  m_targetData.ShowCombatData        = true;
  m_targetData.HasDefenses        = true;

  m_primaryColor, m_secondaryColor = UI.GetPlayerColors(districtOwner);

  local civTypeName:string = PlayerConfigurations[districtOwner]:GetCivilizationTypeName();
  if civTypeName ~= nil then
    local civIconName = "ICON_"..civTypeName;
    m_targetData.CivIconName = civIconName;
  else
    UI.DataError("Invalid type name returned by GetCivilizationTypeName");
  end
end

-- Populate the target data for a generic plot
function ReadTargetData_Plot(pkPlot)

  -- if the plot is now owned at all I am not sure what to show...
  if( pkPlot:IsOwned() == false) then
    return;
  end

  local owner = pkPlot:GetOwner();
  m_primaryColor, m_secondaryColor = UI.GetPlayerColors(owner);

  local impType = pkPlot:GetImprovementType();
  local districtType = pkPlot:GetDistrictType();

  if( impType ~= -1 ) then

    -- Set the improvement target info
    local improvementInfo = GameInfo.Improvements[impType];
    m_targetData.Name = Locale.Lookup(improvementInfo.Name);
    m_targetData.IconName = improvementInfo.Icon;
    m_targetData.HasImprovementOrDistrict = true;

  elseif( districtType ~= -1 ) then 

    -- Set the district target info
    local districtInfo = GameInfo.Districts[districtType];

    if (not districtInfo.CityCenter) then
      m_targetData.Name = Locale.Lookup(districtInfo.Name); 
    elseif (owningCity ~= nil) then
      m_targetData.Name = owningCity:GetName();
    else
      UI.DataError("Failed to find target name for district.");
    end

    --For now we are using the civ icon instead of the district icon since the district icon doesn't fit into the window very well
    --m_targetData.IconName = "ICON_"..districtInfo.DistrictType;
    local civTypeName:string = PlayerConfigurations[owner]:GetCivilizationTypeName();
    if civTypeName ~= nil then
      local civIconName = "ICON_"..civTypeName;
      m_targetData.CivIconName = civIconName;
    else
      UI.DataError("Invalid type name returned by GetCivilizationTypeName");
    end

    m_targetData.HasImprovementOrDistrict = true;
  else
    -- Set the owning player civ icon
    local civTypeName:string = PlayerConfigurations[owner]:GetCivilizationTypeName();
    if civTypeName ~= nil then
      local civIconName = "ICON_"..civTypeName;
      m_targetData.CivIconName = civIconName;
    else
      UI.DataError("Invalid type name returned by GetCivilizationTypeName");
    end
  end
end

function ReadTargetData(attacker)
  if (m_combatResults ~= nil) then
    -- initialize the target object data table
    InitTargetData();
    local bShowTarget = false;
    -- grab the defender from the combat solution table
    local targetObject = m_combatResults[CombatResultParameters.DEFENDER];
    if (targetObject == nil) then
      return false;
    end

    local interceptorCombatResults = m_combatResults[CombatResultParameters.INTERCEPTOR];
    local interceptorID = interceptorCombatResults[CombatResultParameters.ID];
    local pkInterceptor = UnitManager.GetUnit(interceptorID.player, interceptorID.id);

    local antiAirCombatResults = m_combatResults[CombatResultParameters.ANTI_AIR];
    local antiAirID = nil;
    local pkAntiAir = nil;
    if(antiAirCombatResults ~= nil) then
      antiAirID = antiAirCombatResults [CombatResultParameters.ID];
      pkAntiAir = UnitManager.GetUnit(antiAirID.player, antiAirID.id);
    end

    local defenderID = targetObject[CombatResultParameters.ID];
    if (defenderID.type == ComponentType.UNIT) then
      local pkDefender = UnitManager.GetUnit(defenderID.player, defenderID.id);
      if (pkDefender ~= nil) then
        
        ReadTargetData_Unit(pkDefender);

        -- Only display target data if the combat type of the attacker and target match
        if (attacker ~= nil) then
          local eCombatType = m_combatResults[CombatResultParameters.COMBAT_TYPE];
          if (eCombatType ~= nil) then
            bShowTarget = CombatManager.CanAttackTarget(attacker:GetComponentID(), pkDefender:GetComponentID(), eCombatType);
          end
        end
        
      end
    elseif (defenderID.type == ComponentType.DISTRICT) then
      local pDefendingPlayer = Players[defenderID.player];
      if (pDefendingPlayer ~= nil) then
        local pDistrict = pDefendingPlayer:GetDistricts():FindID(defenderID.id);
        if (pDistrict ~= nil) then

          ReadTargetData_District(pDistrict);

          bShowTarget = true;
        end
      end
    else

      local location = m_combatResults[CombatResultParameters.LOCATION];
      local pkPlot = Map.GetPlot( location.x, location.y );
      if( pkPlot ~= nil ) then
        local plotID = Map.GetPlotIndex(location.x, location.y);

        local bShowCombatPreview = false;
        
        -- Always show the combat preview if this attack will trigger intercept or anti-air defences
        if( pkInterceptor ~= nil or pkAntiAir ~= nil ) then
          bShowCombatPreview = true;
        end

        -- If there is an explicit list of air-attach plots, show the combat preview if this plot in on the list.
        -- This means the user is in air-attack interface mode and wants to see all plots they can attack (including air-pillage)
        if (bShowCombatPreview == false) then
          if ( m_airAttackTargetPlots ~= nil ) then
            for i=1,#m_airAttackTargetPlots do
              if m_airAttackTargetPlots[i] == plotID then  
                bShowCombatPreview = true;
                break;
              end
            end
          end
        end
        if (bShowCombatPreview ) then  
          ReadTargetData_Plot( pkPlot );
         
          bShowTarget = true; 
        end
      end
    end

    if (pkInterceptor ~= nil) then
      m_targetData.InterceptorName      = Locale.Lookup(pkInterceptor:GetName());
      m_targetData.InterceptorCombat      = pkInterceptor:GetCombat();
      m_targetData.InterceptorDamage      = pkInterceptor:GetDamage();
      m_targetData.InterceptorMaxDamage    = pkInterceptor:GetMaxDamage();
      m_targetData.InterceptorPotentialDamage  = m_combatResults[CombatResultParameters.INTERCEPTOR][CombatResultParameters.DAMAGE_TO];
    end

    if (pkAntiAir ~= nil) then
      m_targetData.AntiAirName      = Locale.Lookup(pkAntiAir:GetName());
      m_targetData.AntiAirCombat      = pkAntiAir:GetAntiAirCombat();
    end

    if (bShowTarget) then
      ViewTarget(m_targetData);
      return true;
    end
  end

  return false;
end

-- ===========================================================================
function OnInterfaceModeChanged( eOldMode:number, eNewMode:number )

  m_airAttackTargetPlots = {}; 

  if (eNewMode == InterfaceModeTypes.CITY_RANGE_ATTACK) then
    ContextPtr:SetHide(false);

    local isValidToShow :boolean = (playerID ~= Game.GetLocalPlayer());

    if (isValidToShow) then
      local attackingCity = UI.GetHeadSelectedCity();
      if (attackingCity ~= nil) then
        local attackingDistrict = GetDistrictFromCity(attackingCity);
        ReadDistrictData(attackingDistrict);
      end
    end

    OnShowCombat( isValidToShow );
  elseif (eNewMode == InterfaceModeTypes.DISTRICT_RANGE_ATTACK) then
    ContextPtr:SetHide(false);

    local isValidToShow :boolean = (playerID ~= Game.GetLocalPlayer());

    if (isValidToShow) then
      local attackingDistrict = UI.GetHeadSelectedDistrict();
      if (attackingDistrict ~= nil) then
        ReadDistrictData(attackingDistrict);
      end
    end
  end

  -- Set Make Trade Route Button Selected
  if (eNewMode == InterfaceModeTypes.MAKE_TRADE_ROUTE) then
    SetStandardActionButtonSelected("INTERFACEMODE_MAKE_TRADE_ROUTE", true);
  elseif (eOldMode == InterfaceModeTypes.MAKE_TRADE_ROUTE) then
    SetStandardActionButtonSelected("INTERFACEMODE_MAKE_TRADE_ROUTE", false);
  end

  -- Set Teleport To City Button Selected
  if (eNewMode == InterfaceModeTypes.TELEPORT_TO_CITY) then
    SetStandardActionButtonSelected("INTERFACEMODE_TELEPORT_TO_CITY", true);
  elseif (eOldMode == InterfaceModeTypes.TELEPORT_TO_CITY) then
    SetStandardActionButtonSelected("INTERFACEMODE_TELEPORT_TO_CITY", false);
  end

  -- Set SPY_TRAVEL_TO_CITY Selected
  if (eNewMode == InterfaceModeTypes.SPY_TRAVEL_TO_CITY) then
    SetStandardActionButtonSelected("INTERFACEMODE_SPY_TRAVEL_TO_CITY", true);
  elseif (eOldMode == InterfaceModeTypes.SPY_TRAVEL_TO_CITY) then
    SetStandardActionButtonSelected("INTERFACEMODE_SPY_TRAVEL_TO_CITY", false);
  end

  -- Set SPY_CHOOSE_MISSION Selected
  if (eNewMode == InterfaceModeTypes.SPY_CHOOSE_MISSION) then
    SetStandardActionButtonSelected("INTERFACEMODE_SPY_CHOOSE_MISSION", true);
  elseif (eOldMode == InterfaceModeTypes.SPY_CHOOSE_MISSION) then
    SetStandardActionButtonSelected("INTERFACEMODE_SPY_CHOOSE_MISSION", false);
  end

  -- Set REBASE Selected
  if (eNewMode == InterfaceModeTypes.REBASE) then
    SetStandardActionButtonSelected("INTERFACEMODE_REBASE", true);
  elseif (eOldMode == InterfaceModeTypes.REBASE) then
    SetStandardActionButtonSelected("INTERFACEMODE_REBASE", false);
  end

  -- Set DEPLOY Selected
  if (eNewMode == InterfaceModeTypes.DEPLOY) then
    SetStandardActionButtonSelectedByOperation("UNITOPERATION_DEPLOY", true);
  elseif (eOldMode == InterfaceModeTypes.DEPLOY) then
    SetStandardActionButtonSelectedByOperation("UNITOPERATION_DEPLOY", false);
  end

  -- Set MOVE_TO Selected
  if (eNewMode == InterfaceModeTypes.MOVE_TO) then
    SetStandardActionButtonSelectedByOperation("UNITOPERATION_MOVE_TO", true);
  elseif (eOldMode == InterfaceModeTypes.MOVE_TO) then
    SetStandardActionButtonSelectedByOperation("UNITOPERATION_MOVE_TO", false);
  end

  -- Set RANGE_ATTACK Selected
  if (eNewMode == InterfaceModeTypes.RANGE_ATTACK) then
    SetStandardActionButtonSelectedByOperation("UNITOPERATION_RANGE_ATTACK", true);
  elseif (eOldMode == InterfaceModeTypes.RANGE_ATTACK) then
    SetStandardActionButtonSelectedByOperation("UNITOPERATION_RANGE_ATTACK", false);
  end

  -- Set AIR_ATTACK Selected
  if (eNewMode == InterfaceModeTypes.AIR_ATTACK) then
  
    local pSelectedUnit = UI.GetHeadSelectedUnit();
    if (pSelectedUnit ~= nil) then
      local tResults = UnitManager.GetOperationTargets(pSelectedUnit, UnitOperationTypes.AIR_ATTACK );
      local allPlots = tResults[UnitOperationResults.PLOTS];
      if (allPlots ~= nil) then
        for i,modifier in ipairs(tResults[UnitOperationResults.MODIFIERS]) do
          if(modifier == UnitOperationResults.MODIFIER_IS_TARGET) then	
            table.insert(m_airAttackTargetPlots, allPlots[i]);
          end
        end 
      end
    end
 
    SetStandardActionButtonSelectedByOperation("UNITOPERATION_AIR_ATTACK", true);
  elseif (eOldMode == InterfaceModeTypes.AIR_ATTACK) then
    SetStandardActionButtonSelectedByOperation("UNITOPERATION_AIR_ATTACK", false);
  end

  if (eOldMode == InterfaceModeTypes.CITY_RANGE_ATTACK or eOldMode == InterfaceModeTypes.DISTRICT_RANGE_ATTACK) then
    ContextPtr:SetHide(true);
  end
end

-- ===========================================================================
function SetStandardActionButtonSelected( interfaceModeString:string, isSelected:boolean )
  for i=1,m_standardActionsIM.m_iCount,1 do
    local instance:table = m_standardActionsIM:GetAllocatedInstance(i);
    if instance then
      local actionHash = instance.UnitActionButton:GetVoid2();
      local unitOperation = GameInfo.UnitOperations[actionHash];
      if unitOperation then
        local interfaceMode = unitOperation.InterfaceMode;
        if interfaceMode == interfaceModeString then
          instance.UnitActionButton:SetSelected(isSelected);
        end
      end
    end
  end
end

-- ===========================================================================
function SetStandardActionButtonSelectedByOperation( operationString:string, isSelected:boolean )
  for i=1,m_standardActionsIM.m_iCount,1 do
    local instance:table = m_standardActionsIM:GetAllocatedInstance(i);
    if instance then
      local actionHash = instance.UnitActionButton:GetTag();
      local unitOperation = GameInfo.UnitOperations[actionHash];
      if unitOperation then
        local operation = unitOperation.OperationType;
        if operation == operationString then
          instance.UnitActionButton:SetSelected(isSelected);
        end
      end
    end
  end
end

-- ===========================================================================
function GetCombatResults ( attacker, locX, locY )
  -- We have to ask Game Core to do an evaluation, is it busy?
  if (UI.IsGameCoreBusy() == true) then
    return;
  end

  if ( attacker == m_attackerUnit and locX == m_locX and locY == m_locY) then
    return;
  end

  m_attackerUnit  = attacker;
  m_locX = locX;
  m_locY = locY;

  if (locX ~= nil and locY ~= nil) then
    local eCombatType = nil;
    if (UI.GetInterfaceMode() == InterfaceModeTypes.RANGE_ATTACK) then
      local pPlayer:table = Players[Game:GetLocalPlayer()]; 
      local pUnit = UnitManager.GetUnit(attacker.player, attacker.id);
      local pDistrict:table = pPlayer:GetDistricts():FindID( attacker ); 
      if (pUnit ~= nil) then
        eCombatType = CombatTypes.RANGED;
        if (pUnit:GetBombardCombat() > pUnit:GetRangedCombat()) then
          eCombatType = CombatTypes.BOMBARD;
        end
      elseif (pDistrict ~= nil) then
        eCombatType = CombatTypes.RANGED;
      end
    end

    local interfaceMode = UI.GetInterfaceMode();
    if( interfaceMode == InterfaceModeTypes.PRIORITY_TARGET ) then
      m_combatResults	= CombatManager.SimulatePriorityAttackInto( attacker, eCombatType, locX, locY );
    else
      m_combatResults	= CombatManager.SimulateAttackInto( attacker, eCombatType, locX, locY );
    end
  end

end

-- ===========================================================================
--  Input Processing
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
  local uiMsg = pInputStruct:GetMessageType();

  -- If not the current turn or current unit is dictated by cursor/touch
  -- hanging over a flag
  if ( not m_isOkayToProcess or m_isFlagFocused ) then
    return false;
  end

  -- If moved, there is a possibility of moving into a new hex.
  if( uiMsg == MouseEvents.MouseMove ) then
    InspectWhatsBelowTheCursor();
  end

    return false;

end

-- ===========================================================================
function OnUnitListPopupClicked()
  -- Only refresht the unit list when it's being opened
  if Controls.UnitListPopup:IsOpen() then
    RefreshUnitListPopup();
  end
end

-- ===========================================================================
function RefreshUnitListPopup()
  Controls.UnitListPopup:ClearEntries();

  local pPlayer:table = Players[Game.GetLocalPlayer()];
  local pPlayerUnits:table = pPlayer:GetUnits();

  -- Sort units
  local militaryUnits:table = {};
  local navalUnits:table = {};
  local airUnits:table = {};
  local supportUnits:table = {};
  local civilianUnits:table = {};
  local tradeUnits:table = {};

  for i, pUnit in pPlayerUnits:Members() do
    local unitInfo:table = GameInfo.Units[pUnit:GetUnitType()];

    if unitInfo.MakeTradeRoute == true then
      table.insert(tradeUnits, pUnit);
    elseif pUnit:GetCombat() == 0 and pUnit:GetRangedCombat() == 0 then
      -- if we have no attack strength we must be civilian
      table.insert(civilianUnits, pUnit);
    elseif unitInfo.Domain == "DOMAIN_LAND" then
      table.insert(militaryUnits, pUnit);
    elseif unitInfo.Domain == "DOMAIN_SEA" then
      table.insert(navalUnits, pUnit);
    elseif unitInfo.Domain == "DOMAIN_AIR" then
      table.insert(airUnits, pUnit);
    end
  end

  -- Alphabetize groups
  local sortFunc = function(a, b)
    local aType:string = GameInfo.Units[a:GetUnitType()].UnitType;
    local bType:string = GameInfo.Units[b:GetUnitType()].UnitType;
    return aType < bType;
  end
  table.sort(militaryUnits, sortFunc);
  table.sort(navalUnits, sortFunc);
  table.sort(airUnits, sortFunc);
  table.sort(civilianUnits, sortFunc);
  table.sort(tradeUnits, sortFunc);

  -- Add units by sorted groups
  for _, pUnit in ipairs(militaryUnits) do  AddUnitToUnitList( pUnit ); end
  for _, pUnit in ipairs(navalUnits) do     AddUnitToUnitList( pUnit ); end
  for _, pUnit in ipairs(airUnits) do     AddUnitToUnitList( pUnit ); end
  for _, pUnit in ipairs(supportUnits) do   AddUnitToUnitList( pUnit ); end
  for _, pUnit in ipairs(civilianUnits) do  AddUnitToUnitList( pUnit ); end
  for _, pUnit in ipairs(tradeUnits) do   AddUnitToUnitList( pUnit ); end

  Controls.UnitListPopup:CalculateInternals();
end

-- ===========================================================================
function AddUnitToUnitList(pUnit:table)
  -- Create entry
  local unitEntry:table = {};
  Controls.UnitListPopup:BuildEntry( "UnitListEntry", unitEntry );

  local formation = pUnit:GetMilitaryFormation();
  local suffix:string = "";
  local unitInfo:table = GameInfo.Units[pUnit:GetUnitType()];
  if (unitInfo.Domain == "DOMAIN_SEA") then
    if (formation == MilitaryFormationTypes.CORPS_FORMATION) then
      suffix = " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_FLEET_SUFFIX");
    elseif (formation == MilitaryFormationTypes.ARMY_FORMATION) then
      suffix = " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_ARMADA_SUFFIX");
    end
  else
    if (formation == MilitaryFormationTypes.CORPS_FORMATION) then
      suffix = " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_CORPS_SUFFIX");
    elseif (formation == MilitaryFormationTypes.ARMY_FORMATION) then
      suffix = " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_ARMY_SUFFIX");
    end
  end
 
  local uniqueName = Locale.Lookup( pUnit:GetName() ) .. suffix;
  unitEntry.Button:SetText( Locale.ToUpper(uniqueName) );
  unitEntry.Button:SetVoids(i, pUnit:GetID());

  -- Update unit icon
  local iconInfo:table, iconShadowInfo:table = GetUnitIcon(pUnit, 22, true);
  if iconInfo.textureSheet then
    unitEntry.UnitTypeIcon:SetTexture( iconInfo.textureOffsetX, iconInfo.textureOffsetY, iconInfo.textureSheet );
  end

  -- Update status icon
  local activityType:number = UnitManager.GetActivityType(pUnit);
  if activityType == ActivityTypes.ACTIVITY_SLEEP then
    SetUnitEntryStatusIcon(unitEntry, "ICON_STATS_SLEEP");
  elseif activityType == ActivityTypes.ACTIVITY_HOLD then
    SetUnitEntryStatusIcon(unitEntry, "ICON_STATS_SKIP");
  elseif activityType ~= ActivityTypes.ACTIVITY_AWAKE and pUnit:GetFortifyTurns() > 0 then
    SetUnitEntryStatusIcon(unitEntry, "ICON_DEFENSE");
  else
    unitEntry.UnitStatusIcon:SetHide(true);
  end

  -- Update entry color if unit cannot take any action
  if pUnit:IsReadyToMove() then
    unitEntry.Button:GetTextControl():SetColorByName("UnitPanelTextCS");
    unitEntry.UnitTypeIcon:SetColorByName("UnitPanelTextCS");
  else
    unitEntry.Button:GetTextControl():SetColorByName("UnitPanelTextDisabledCS");
    unitEntry.UnitTypeIcon:SetColorByName("UnitPanelTextDisabledCS");
  end
end

-- ===========================================================================
function SetUnitEntryStatusIcon(unitEntry:table, icon:string)
  local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas(icon,22);
  unitEntry.UnitStatusIcon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
  unitEntry.UnitStatusIcon:SetHide(false);
end

-- ===========================================================================
function OnUnitListSelection(index:number, unitID:number)
  local unit:table = Players[Game.GetLocalPlayer()]:GetUnits():FindID(unitID);
  if unit ~= nil then
    UI.SelectUnit(unit);
    local plot = Map.GetPlot( unit:GetX(), unit:GetY() );
    UI.LookAtPlot( plot );
  end
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnSetTradeUnitStatus( text:string )
  Controls.TradeUnitStatusLabel:SetText( Locale.Lookup(text) );
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnTutorialDisableActionForAll( actionType:string )
  table.insert(m_kTutorialAllDisabled, actionType)
end

-- ===========================================================================
--  LUA Event
-- ===========================================================================
function OnTutorialEnableActionForAll( actionType:string )
  local count :number = #m_kTutorialAllDisabled;
  for i=count,1,-1 do
    if v==actionType then
      table.remove(m_kTutorialAllDisabled, i)
    end
  end
end

-- ===========================================================================
--  LUA Event
--  Set action/operation to not be enabled for a certain unit type.
--  actionType  String of the CommandType, or OperationType
--  unitType  String of the "UnitType"
-- ===========================================================================
function OnTutorialDisableActions( actionType:string, unitType:string  )

  if m_kTutorialDisabled[unitType] == nil then
    m_kTutorialDisabled[unitType] = hmake DisabledByTutorial
    {
      kLockedHashes = {}
    };
  end

  local hash:number = GetHashFromType(actionType);
  if hash ~= 0 then
    table.insert(m_kTutorialDisabled[unitType].kLockedHashes, hash );
  else
    UI.DataError("Tutorial could not disable on the UnitPanel '"..actionType.."' as it wasn't found as a command or an operation.");
  end
end

-- ===========================================================================
--  LUA Event
--  Set action/operation to be re-enabled for a certain unit type.
--  actionType  String of the CommandType, or OperationType
--  unitType  String of the "UnitType"
-- ===========================================================================
function OnTutorialEnableActions( actionType:string, unitType:string  )

  if m_kTutorialDisabled[unitType] == nil then
    UI.DataError("There is no spoon, '"..unitType.."' never had a disable call.");
    return;
  end

  local hash:number = GetHashFromType(actionType);
  if hash ~= 0 then
    local count:number = table.count(m_kTutorialDisabled[unitType].kLockedHashes);
    for n = count,1,-1 do
      if hash == m_kTutorialDisabled[unitType].kLockedHashes[n] then
        table.remove( m_kTutorialDisabled[unitType].kLockedHashes, n );
      end
    end
  else
    UI.DataError("Tutorial could not re-enable on the UnitPanel '"..actionType.."' as it wasn't found as a command or an operation.");
  end
end

function OnPortraitClick()
  if m_selectedPlayerId ~= nil then
    local pUnits  :table = Players[m_selectedPlayerId]:GetUnits( );
    local pUnit   :table = pUnits:FindID( m_UnitId );
    if pUnit ~= nil then
      UI.LookAtPlot( pUnit:GetX( ), pUnit:GetY( ) );
    end
  end
end

function OnPortraitRightClick()
  if m_selectedPlayerId ~= nil then
    local pUnits  :table = Players[m_selectedPlayerId]:GetUnits( );
    local pUnit   :table = pUnits:FindID( m_UnitId );
    if (pUnit ~= nil) then
      local unitType = GameInfo.Units[pUnit:GetUnitType()];
      if(unitType) then
        LuaEvents.OpenCivilopedia(unitType.UnitType);
      end
    end
  end
end


-- ===========================================================================
function Initialize()

  -- Events
  ContextPtr:SetInitHandler( OnContextInitialize );
  ContextPtr:SetInputHandler( OnInputHandler, true );
  ContextPtr:SetRefreshHandler( OnRefresh );

  --
  Controls.RandomNameButton:RegisterCallback( Mouse.eLClick, RandomizeName );
  Controls.RandomPrefixButton:RegisterCallback( Mouse.eLClick, RandomizeNamePrefix );
  Controls.RandomSuffixButton:RegisterCallback( Mouse.eLClick, RandomizeNameSuffix );
  Controls.ConfirmVeteranName:RegisterCallback( Mouse.eLClick, ConfirmVeteranName );
  Controls.VeteranNameField:RegisterStringChangedCallback( EditCustomVeteranName ) ;
  Controls.VeteranNameField:RegisterCommitCallback( ConfirmVeteranName );
  Controls.VeteranNamingCancelButton:RegisterCallback( Mouse.eLClick, HideVeteranNamePanel );
  Controls.PromotionCancelButton:RegisterCallback( Mouse.eLClick, HidePromotionPanel );
  Controls.UnitName:RegisterCallback( Mouse.eLClick, OnUnitListPopupClicked );
  Controls.UnitListPopup:RegisterSelectionCallback( OnUnitListSelection );
  Controls.SelectionPanelUnitPortrait:RegisterCallback( Mouse.eLClick, OnPortraitClick );
  Controls.SelectionPanelUnitPortrait:RegisterCallback( Mouse.eRClick, OnPortraitRightClick);

  Events.BeginWonderReveal.Add( OnBeginWonderReveal );
  Events.CitySelectionChanged.Add( OnCitySelectionChanged );
  Events.CityReligionFollowersChanged.Add( OnCityReligionFollowersChanged );
  Events.GreatWorkMoved.Add( OnGreatWorkMoved );
  Events.InputActionTriggered.Add( OnInputActionTriggered );
  Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
  Events.PantheonFounded.Add( OnPantheonFounded );
  Events.PhaseBegin.Add( OnPhaseBegin );
  Events.PlayerTurnActivated.Add( OnPlayerTurnActivated );
  Events.PlayerTurnDeactivated.Add( OnPlayerTurnDeactivated );
  Events.UnitCommandStarted.Add( OnUnitCommandStarted );
  Events.UnitDamageChanged.Add( OnUnitDamageChanged );
  Events.UnitMoveComplete.Add( OnUnitMoveComplete );
  Events.UnitChargesChanged.Add( OnUnitChargesChanged );
  Events.UnitPromoted.Add( OnUnitPromotionChanged );
  Events.UnitOperationsCleared.Add( OnUnitOperationsCleared );
  Events.UnitOperationAdded.Add( OnUnitOperationAdded );
  Events.UnitOperationDeactivated.Add( OnUnitOperationDeactivated );
  Events.UnitRemovedFromMap.Add( OnUnitRemovedFromMap );
  Events.UnitSelectionChanged.Add( OnUnitSelectionChanged );

  LuaEvents.TradeOriginChooser_SetTradeUnitStatus.Add(OnSetTradeUnitStatus );
  LuaEvents.TradeRouteChooser_SetTradeUnitStatus.Add( OnSetTradeUnitStatus );
  LuaEvents.TutorialUIRoot_DisableActions.Add(    OnTutorialDisableActions );
  LuaEvents.TutorialUIRoot_DisableActionForAll.Add( OnTutorialDisableActionForAll );
  LuaEvents.TutorialUIRoot_EnableActions.Add(     OnTutorialEnableActions );
  LuaEvents.TutorialUIRoot_EnableActionForAll.Add(  OnTutorialEnableActionForAll );
  LuaEvents.UnitFlagManager_PointerEntered.Add(   OnUnitFlagPointerEntered );
  LuaEvents.UnitFlagManager_PointerExited.Add(    OnUnitFlagPointerExited );
  LuaEvents.PlayerChange_Close.Add(         OnPlayerChangeClose );

  -- Setup settlement water guide colors
  local FreshWaterColor:number = UI.GetColorValue("COLOR_BREATHTAKING_APPEAL");
  Controls.SettlementWaterGrid_FreshWater:SetColor(FreshWaterColor);
  local FreshWaterBonus:number = GlobalParameters.CITY_POPULATION_RIVER_LAKE - GlobalParameters.CITY_POPULATION_NO_WATER;
  Controls.CapacityBonus_FreshWater:SetText("+" .. tostring(FreshWaterBonus));
  local CoastalWaterColor:number = UI.GetColorValue("COLOR_CHARMING_APPEAL");
  Controls.SettlementWaterGrid_CoastalWater:SetColor(CoastalWaterColor);
  local CoastalWaterBonus:number = GlobalParameters.CITY_POPULATION_COAST - GlobalParameters.CITY_POPULATION_NO_WATER;
  Controls.CapacityBonus_CoastalWater:SetText("+" .. tostring(CoastalWaterBonus));
  local NoWaterColor:number = UI.GetColorValue("COLOR_AVERAGE_APPEAL");
  Controls.SettlementWaterGrid_NoWater:SetColor(NoWaterColor);
  local SettlementBlockedColor:number = UI.GetColorValue("COLOR_DISGUSTING_APPEAL");
  Controls.SettlementWaterGrid_SettlementBlocked:SetColor(SettlementBlockedColor);
end
Initialize();
