-- ===========================================================================
-- Base File
-- ===========================================================================
include("UnitFlagManager");

-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_CQUI_SetColor = UnitFlag.SetColor;
BASE_CQUI_UpdateStats = UnitFlag.UpdateStats;
BASE_CQUI_OnUnitSelectionChanged = OnUnitSelectionChanged;
BASE_CQUI_OnPlayerTurnActivated = OnPlayerTurnActivated;
BASE_CQUI_OnUnitPromotionChanged = OnUnitPromotionChanged;
BASE_CQUI_UpdateFlagType = UnitFlag.UpdateFlagType;

-- ===========================================================================
-- CQUI Members
-- ===========================================================================
local CQUI_ShowingPath = nil; --unitID for the unit whose path is currently being shown. nil for no unit
local CQUI_SelectionMade = false;
local CQUI_ShowPaths = true; --Toggle for showing the paths
local CQUI_IsFlagHover = false; -- if the path is the flag us currently hover or not

--Hides any currently drawn paths.
function CQUI_HidePath()
  if CQUI_ShowPaths and CQUI_IsFlagHover then
    LuaEvents.CQUI_clearUnitPath();
    CQUI_IsFlagHover = false;
  end
end

function CQUI_OnSettingsUpdate()
  CQUI_HidePath();
  CQUI_ShowPaths = GameConfiguration.GetValue("CQUI_ShowUnitPaths");
end

function CQUI_Refresh()
  -- AZURENCY : update the stats of the flags on refresh
  local unitList = Players[Game.GetLocalPlayer()]:GetUnits();
  if unitList ~= nil then
    for _,pUnit in unitList:Members() do
      local eUnitID = pUnit:GetID();
      local eOwner  = pUnit:GetOwner();

      local pFlag = GetUnitFlag( eOwner, eUnitID );
      if pFlag ~= nil then
        pFlag:UpdateStats();
      end
    end
  end
end

function CQUI_OnUnitFlagPointerEntered(playerID:number, unitID:number)
  if CQUI_ShowPaths and not CQUI_IsFlagHover then
    if not CQUI_SelectionMade then
      LuaEvents.CQUI_showUnitPath(true, unitID);
    end
    CQUI_IsFlagHover = true;
  end
end

function CQUI_OnUnitFlagPointerExited(playerID:number, unitID:number)
  if CQUI_ShowPaths and CQUI_IsFlagHover then
    if not CQUI_SelectionMade then
      LuaEvents.CQUI_clearUnitPath();
    end
    CQUI_IsFlagHover = false;
  end
end

-- ===========================================================================
--  CQUI modified UnitFlag.SetColor functiton
--  Enemy unit flags are red-tinted when at war with you
-- ===========================================================================
function UnitFlag.SetColor( self )
  BASE_CQUI_SetColor(self)

  local instance:table = self.m_Instance;
  instance.FlagBaseDarken:SetHide(true);

  -- War Check
  if Game.GetLocalPlayer() > -1 then
    local pUnit : table = self:GetUnit();
    local localPlayer =  Players[Game.GetLocalPlayer()];
    local ownerPlayer = pUnit:GetOwner();
    --instance.FlagBaseDarken:SetHide(false);

    local isAtWar = localPlayer:GetDiplomacy():IsAtWarWith( ownerPlayer );
    local CQUI_isBarb = Players[ownerPlayer]:IsBarbarian(); --pUnit:GetBarbarianTribeIndex() ~= -1

    if(isAtWar and (not CQUI_isBarb)) then
      instance.FlagBaseDarken:SetColor( RGBAValuesToABGRHex(255,0,0,255) );
      instance.FlagBaseDarken:SetHide(false);
    end
  end
end

-- ===========================================================================
--  CQUI modified UnitFlag.UpdateFlagType functiton
--  Set the right texture for the FlagBaseDarken used on enemy unit during war
-- ===========================================================================
function UnitFlag.UpdateFlagType( self )
  BASE_CQUI_UpdateFlagType(self)

  local pUnit = self:GetUnit();
  if pUnit == nil then
    return;
  end

  local textureName = self.m_Instance.FlagBase:GetTexture():gsub('_Combo', '');
  self.m_Instance.FlagBaseDarken:SetTexture( textureName );
end

-- ===========================================================================
--  CQUI modified UnitFlag.UpdateStats functiton
--  Also set the color
-- ===========================================================================
function UnitFlag.UpdateStats( self )
  BASE_CQUI_UpdateStats(self);
  if (pUnit ~= nil) then
    self:SetColor();
  end
end

-- ===========================================================================
--  CQUI modified UnitFlag.UpdatePromotions functiton
--  Builder show charges in promotion flag
--  Unit pending a promotion show a "+"
-- ===========================================================================
function UnitFlag.UpdatePromotions( self )
  self.m_Instance.Promotion_Flag:SetHide(true);
  local pUnit : table = self:GetUnit();
  local isLocalPlayerUnit: boolean = pUnit:GetOwner() == Game:GetLocalPlayer(); --ARISTOS: hide promotion/charge info if not local player's unit!
  if pUnit ~= nil then
    -- If this unit is levied (ie. from a city-state), showing that takes precedence
    local iLevyTurnsRemaining = GetLevyTurnsRemaining(pUnit);
    if (iLevyTurnsRemaining >= 0) then
      self.m_Instance.UnitNumPromotions:SetText("[ICON_Turn]");
      self.m_Instance.Promotion_Flag:SetHide(false);
    -- Otherwise, show the experience level
    elseif ((GameInfo.Units[pUnit:GetUnitType()].UnitType == "UNIT_BUILDER") or (GameInfo.Units[pUnit:GetUnitType()].UnitType == "UNIT_MILITARY_ENGINEER")) and isLocalPlayerUnit then
      local uCharges = pUnit:GetBuildCharges();
      self.m_Instance.New_Promotion_Flag:SetHide(true);
      self.m_Instance.UnitNumPromotions:SetText(uCharges);
      self.m_Instance.Promotion_Flag:SetHide(false);
      self.m_Instance.Promotion_Flag:SetOffsetX(-4);
      self.m_Instance.Promotion_Flag:SetOffsetY(12);
    else
      local unitExperience = pUnit:GetExperience();
      if (unitExperience ~= nil) then
        local promotionList :table = unitExperience:GetPromotions();
        self.m_Instance.New_Promotion_Flag:SetHide(true);
        --ARISTOS: to test for available promotions! Previous test using XPs was faulty (Firaxis... :rolleyes:)
        local bCanStart, tResults = UnitManager.CanStartCommand( pUnit, UnitCommandTypes.PROMOTE, true, true);
        -- AZURENCY : CanStartCommand will return false if the unit have no movements left but still can have 
        -- a promotion (maybe not this turn, but it have enough experience, so we'll show it on the flag anyway)
        if not bCanStart then
          bCanStart = unitExperience:GetExperiencePoints() >= unitExperience:GetExperienceForNextLevel()
        end
        -- Nilt: Added check to prevent the promotion flag staying a red + permanently on max XP units.
        if bCanStart and isLocalPlayerUnit and (#promotionList < 7) then
          self.m_Instance.New_Promotion_Flag:SetHide(false);
          self.m_Instance.UnitNumPromotions:SetText("[COLOR:StatBadCS]+[ENDCOLOR]");
          self.m_Instance.Promotion_Flag:SetHide(false);
        --end
        --ARISTOS: if already promoted, or no promotion available, show # of proms
        elseif (#promotionList > 0) then
          --[[
          local tooltipString :string = "";
          for i, promotion in ipairs(promotionList) do
            tooltipString = tooltipString .. Locale.Lookup(GameInfo.UnitPromotions[promotion].Name);
            if (i < #promotionList) then
              tooltipString = tooltipString .. "[NEWLINE]";
            end
          end
          self.m_Instance.Promotion_Flag:SetToolTipString(tooltipString);
          --]]
          self.m_Instance.UnitNumPromotions:SetText(#promotionList);
          self.m_Instance.Promotion_Flag:SetHide(false);
        end
      end
    end
  end
end

-- ===========================================================================
--  CQUI modified OnUnitSelectionChanged functiton
--  Hide unit paths on deselect
-- ===========================================================================
function OnUnitSelectionChanged( playerID : number, unitID : number, hexI : number, hexJ : number, hexK : number, bSelected : boolean, bEditable : boolean )
  BASE_CQUI_OnUnitSelectionChanged(playerID, unitID, hexI, hexJ, hexK, bSelected, bEditable);

  if (bSelected) then
    -- CQUI modifications for tracking unit selection and displaying unit paths
    -- unitID could be nil, if unit is consumed (f.e. settler, worker)
    if (unitID ~= nil) then
      CQUI_SelectionMade = true;
      if(CQUI_ShowingPath ~= unitID) then
        if(CQUI_ShowingPath ~= nil) then
            CQUI_HidePath();
        end
        CQUI_ShowingPath = unitID;
      end
    else
      CQUI_SelectionMade = false;
      CQUI_ShowingPath = nil;
    end
  else
    CQUI_SelectionMade = false;
    CQUI_HidePath();
    CQUI_ShowingPath = nil;
  end
end

function OnDiplomacyWarStateChange(player1ID:number, player2ID:number)
  local localPlayer =  Players[Game.GetLocalPlayer()];

  local playerToUpdate = player1ID;
  if(player1ID ==Game.GetLocalPlayer()) then
    playerToUpdate = player2ID;
  else
    playerToUpdate = player1ID;
  end


  if (playerToUpdate ~= nil) then
    for index,pUnit in Players[playerToUpdate]:GetUnits():Members() do
      if (pUnit ~= nil) then
        local flag = GetUnitFlag(playerToUpdate, pUnit:GetID());
        if (flag ~= nil) then
          flag:UpdateStats();
        end
      end
    end
  end
end

-------------------------------------------------
-- Update charges on units
-------------------------------------------------
function OnUnitChargesChanged(player, unitID)
  local localPlayerID = Game.GetLocalPlayer();
  local pPlayer = Players[ player ];

  if (player == localPlayerID) then
    local pUnit = pPlayer:GetUnits():FindID(unitID);
    if (pUnit ~= nil) then
      local flagInstance = GetUnitFlag( player, unitID );
      if (flagInstance ~= nil) then
        flagInstance:UpdatePromotions();
      end
    end
  end
end

-- ===========================================================================
--  CQUI modified OnPlayerTurnActivated functiton
--  AutoPlay mod compatibility
-- ===========================================================================
function OnPlayerTurnActivated( ePlayer:number, bFirstTimeThisTurn:boolean )

  local idLocalPlayer = Game.GetLocalPlayer();
  if idLocalPlayer < 0 then
    return;
  end

  BASE_CQUI_OnPlayerTurnActivated(ePlayer, bFirstTimeThisTurn);
end

-- ===========================================================================
--  CQUI modified OnUnitPromotionChanged functiton
--  Refresh the flag promotion sign
-- ===========================================================================
function OnUnitPromotionChanged( playerID : number, unitID : number )
  local pPlayer = Players[ playerID ];
  if (pPlayer ~= nil) then
    local pUnit = pPlayer:GetUnits():FindID(unitID);
    if (pUnit ~= nil) then
      local flag = GetUnitFlag(playerID, pUnit:GetID());
      if (flag ~= nil) then
        --flag:UpdateStats();
        -- AZURENCY : request a refresh on the next frame (to update the promotion flag and remove + sign)
        ContextPtr:RequestRefresh()
      end
    end
  end
end

function Initialize()
  ContextPtr:SetRefreshHandler(CQUI_Refresh);

  Events.DiplomacyMakePeace.Add(OnDiplomacyWarStateChange);
  Events.DiplomacyDeclareWar.Add(OnDiplomacyWarStateChange);
  Events.UnitChargesChanged.Add(OnUnitChargesChanged);
  Events.UnitSelectionChanged.Remove(BASE_CQUI_OnUnitSelectionChanged);
  Events.UnitSelectionChanged.Add(OnUnitSelectionChanged);
  Events.PlayerTurnActivated.Remove(BASE_CQUI_OnPlayerTurnActivated);
  Events.PlayerTurnActivated.Add(OnPlayerTurnActivated);
  Events.UnitPromoted.Remove(BASE_CQUI_OnUnitPromotionChanged);
  Events.UnitPromoted.Add(OnUnitPromotionChanged);

  LuaEvents.UnitFlagManager_PointerEntered.Add(CQUI_OnUnitFlagPointerEntered);
  LuaEvents.UnitFlagManager_PointerExited.Add(CQUI_OnUnitFlagPointerExited);

  LuaEvents.CQUI_SettingsUpdate.Add(CQUI_OnSettingsUpdate);
  LuaEvents.CQUI_SettingsInitialized.Add(CQUI_OnSettingsUpdate);
end

Initialize()