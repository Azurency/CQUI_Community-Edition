-- ===========================================================================
--	Popups when a Tech or Civic are completed
-- ===========================================================================
include("Civ6Common");
include("InstanceManager");

-- ===========================================================================
--	CONSTANTS / MEMBERS
-- ===========================================================================
local m_PromotionListInstanceMgr:table	= InstanceManager:new( "PromotionSelectionInstance",	"PromotionSelection",	Controls.PromotionScrollPanel );
local m_CompletedPromotionListInstanceMgr:table	= InstanceManager:new( "CompletedPromotionSelectionInstance",	"PromotionSelection",	Controls.PromotionScrollPanel );
local m_kLineIM					:table	= InstanceManager:new( "LineImageInstance", 			"LineImage",			Controls.PromotionScrollPanel );

local m_uiNodes				:table = {};
local SIZE_NODE_X				:number = 150;			-- Item node dimensions
local SIZE_NODE_Y				:number = 146;
local SIZE_NODE_X_HALF			:number = 75;			-- Item node dimensions
local SIZE_NODE_Y_HALF			:number = 75;
local SIZE_PATH					:number = 40;
local SIZE_PATH_HALF			:number = 20;
local SIZE_ROW_Y				:number = 106;
local SIZE_COLUMN_X				:number = 212;
local LINE_BEFORE_CURVE			:number = 20;		-- MIN-MAX 40-(SIZE_NODE_Y/3)
local SIZE_BORDER_X				:number = 50;
local SIZE_BORDER_Y				:number = 60;
-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================

-- ===========================================================================
--	Closes the immediate popup, will raise more if queued.
-- ===========================================================================
function Close()
  UIManager:DequeuePopup( ContextPtr );
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnClose()
  Close();
end

-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnInit( isReload:boolean )
  if isReload then
    LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
  end
end

------------------------------------------------------------------------------------------------
function OnLocalPlayerTurnEnd()
  if(GameConfiguration.IsHotseat()) then
    Close();
  end
end

function OnPromoteUnit(ePromotion)
  local pSelectedUnit = UI.GetHeadSelectedUnit();
  if (pSelectedUnit ~= nil) then
    local tParameters = {};
    tParameters[UnitCommandTypes.PARAM_PROMOTION_TYPE] = ePromotion;
    UnitManager.RequestCommand( pSelectedUnit, UnitCommandTypes.PROMOTE, tParameters );
  end
end

function OnPromoteUnitPopup()
  local pUnit:table	= UI.GetHeadSelectedUnit();

  local bCanStart, tResults = UnitManager.CanStartCommand( pUnit, UnitCommandTypes.PROMOTE, true, true);
  local tPromotions		= tResults[UnitCommandResults.PROMOTIONS];

  local unitExperience = pUnit:GetExperience();
  local currentPromotionList :table = unitExperience:GetPromotions();
  local promotionClass = GameInfo.Units[pUnit:GetUnitType()].PromotionClass;

  local strengthString:string = "";
  local experienceString:string = "";
  if pUnit:GetCombat() > 0 then
    strengthString = strengthString .. "[ICON_Strength]" ..pUnit:GetCombat()
  end
  if pUnit:GetRangedCombat() > 0 then
    strengthString = strengthString .. "[ICON_Ranged]" ..pUnit:GetRangedCombat()
  end
  if pUnit:GetBombardCombat() > 0 then
    strengthString = strengthString .. "[ICON_Bombard]" ..pUnit:GetBombardCombat()
  end
  if pUnit:GetAntiAirCombat() > 0 then
    strengthString = strengthString .. "[ICON_AntiAir_Large]" ..pUnit:GetAntiAirCombat()
  end
  if pUnit:GetReligiousStrength() > 0 then
    strengthString = strengthString .. "[ICON_Religion]" ..pUnit:GetReligiousStrength()
  end
  if pUnit:GetMaxMoves() > 0 then
    strengthString = strengthString .. "[ICON_Movement]" ..pUnit:GetMaxMoves()
  end

  experienceString = Locale.Lookup("LOC_HUD_UNIT_PANEL_XP") .. " " .. unitExperience:GetExperiencePoints();

  Controls.StrMoveLabel:SetText(Locale.Lookup(strengthString));
  Controls.ExperienceLabel:SetText(Locale.Lookup(experienceString));

  m_PromotionListInstanceMgr:ResetInstances();
  m_CompletedPromotionListInstanceMgr:ResetInstances();
  m_kLineIM:ResetInstances();
  m_uiNodes = {};
  local hasPromotion:boolean;

  for row in GameInfo.UnitPromotions() do

    if row.PromotionClass == promotionClass then
      m_uiNodes[row.UnitPromotionType] = row;
    end
  end

  local numUnlocks = 0;
  for _, i in pairs(m_uiNodes) do
    for row in GameInfo.UnitPromotionPrereqs() do
      hasPromotion = false;
      numUnlocks = 0

      if row.PrereqUnitPromotion == i.UnitPromotionType then
        local previousRow	:number = i.Level;
        local previousColumn:number = i.Column;
        local currentRow:number = m_uiNodes[row.UnitPromotion].Level;
        local currentColumn:number = m_uiNodes[row.UnitPromotion].Column;

        for _, promotion in pairs(currentPromotionList) do
          if row.UnitPromotion == GameInfo.UnitPromotions[promotion].UnitPromotionType or i.UnitPromotionType == GameInfo.UnitPromotions[promotion].UnitPromotionType then
            numUnlocks = numUnlocks+1;
          end
        end
        hasPromotion = numUnlocks >= 2;

        if (currentColumn > previousColumn or currentColumn < previousColumn) and  (currentRow > previousRow or currentRow < previousRow) then
          local inst	:table = m_kLineIM:GetInstance();
          local line1	:table = inst.LineImage;
          inst = m_kLineIM:GetInstance();
          local line2:table = inst.LineImage;
          inst = m_kLineIM:GetInstance();
          local line3:table = inst.LineImage;
          inst = m_kLineIM:GetInstance();
          local line4:table = inst.LineImage;
          inst = m_kLineIM:GetInstance();
          local line5:table = inst.LineImage;

          local PrereqX = currentColumn*SIZE_NODE_X + SIZE_BORDER_X - SIZE_NODE_X_HALF;
          local MyX = previousColumn*SIZE_NODE_X + SIZE_BORDER_X - SIZE_NODE_X_HALF;
          local PrereqY = (math.min(previousRow,currentRow)-1)*SIZE_NODE_Y + SIZE_BORDER_Y + SIZE_ROW_Y;
          local MyY = (math.max(previousRow,currentRow)-1)*SIZE_NODE_Y + SIZE_BORDER_Y;
          local CurveY = PrereqY + LINE_BEFORE_CURVE;

          line1:SetOffsetVal(MyX, PrereqY);
          line1:SetSizeVal(SIZE_PATH, CurveY - PrereqY-SIZE_PATH_HALF);

          line2:SetOffsetVal(MyX, CurveY-SIZE_PATH_HALF);
          line2:SetSizeVal(SIZE_PATH, SIZE_PATH);

          line3:SetOffsetVal(math.min(PrereqX, MyX)+SIZE_PATH, CurveY-SIZE_PATH_HALF);
          line3:SetSizeVal(math.abs(PrereqX - MyX)-SIZE_PATH, SIZE_PATH);

          line4:SetOffsetVal(PrereqX, CurveY-SIZE_PATH_HALF);
          line4:SetSizeVal(SIZE_PATH, SIZE_PATH);

          line5:SetOffsetVal(PrereqX, CurveY + SIZE_PATH_HALF);
          line5:SetSizeVal(SIZE_PATH, MyY - CurveY - SIZE_PATH_HALF);

          if hasPromotion then
            line1:SetTexture("Controls_TreePathNS");
            line3:SetTexture("Controls_TreePathEW");
            line5:SetTexture("Controls_TreePathNS");

            if( PrereqX < MyX) then
              line2:SetTexture("Controls_TreePathEN");
              line4:SetTexture("Controls_TreePathNE");
            else
              line2:SetTexture("Controls_TreePathSE");
              line4:SetTexture("Controls_TreePathES");
            end

            line1:SetColor(0xFF71A2BF);
            line2:SetColor(0xFF71A2BF);
            line3:SetColor(0xFF71A2BF);
            line4:SetColor(0xFF71A2BF);
            line5:SetColor(0xFF71A2BF);
          else
            line1:SetTexture("Controls_TreePathDashNS");
            line3:SetTexture("Controls_TreePathDashEW");
            line5:SetTexture("Controls_TreePathDashNS");

            if( PrereqX < MyX) then
              line2:SetTexture("Controls_TreePathDashEN");
              line4:SetTexture("Controls_TreePathDashNE");
            else
              line2:SetTexture("Controls_TreePathDashSE");
              line4:SetTexture("Controls_TreePathDashES");
            end

            --line1:SetColor(63,83,100,255);
            --line2:SetColor(63,83,100,255);
            --line3:SetColor(63,83,100,255);
            --line4:SetColor(63,83,100,255);
            --line5:SetColor(63,83,100,255);
          end
        else
          local inst:table = m_kLineIM:GetInstance();
          local line:table = inst.LineImage;
          if(currentColumn > previousColumn or currentColumn < previousColumn) then
            local startX:number= (math.min(previousColumn,currentColumn))*SIZE_NODE_X + SIZE_BORDER_X;
            local endX :number = (math.max(previousColumn,currentColumn)-1)*SIZE_NODE_X + SIZE_BORDER_X;
            local yVal:number = (currentRow-1)*SIZE_NODE_Y + SIZE_NODE_Y_HALF;

            line:SetOffsetVal(startX, yVal);
            line:SetSizeVal( endX - startX, SIZE_PATH);
            if hasPromotion then
              line:SetTexture("Controls_TreePathEW");
              line:SetColor(0xFF71A2BF);
            else
              line:SetTexture("Controls_TreePathDashEW");
              --line:SetColor(63,83,100,255);
            end
          else
            local startY:number= (math.min(previousRow,currentRow)-1)*SIZE_NODE_Y + SIZE_BORDER_Y + SIZE_ROW_Y;
            local endY :number = (math.max(previousRow,currentRow)-1)*SIZE_NODE_Y + SIZE_BORDER_Y;
            local XVal:number = currentColumn*SIZE_NODE_X + SIZE_BORDER_X - SIZE_NODE_X_HALF;

            line:SetOffsetVal(XVal, startY);
            line:SetSizeVal(SIZE_PATH,  endY - startY);
            if hasPromotion then
              line:SetTexture("Controls_TreePathNS");
              line:SetColor(0xFF71A2BF);
            else
              line:SetTexture("Controls_TreePathDashNS");
              --line:SetColor(63,83,100,255);
            end
          end
        end
      end
    end
  end

  for row in GameInfo.UnitPromotions() do
    hasPromotion = false;
    for i, promotion in pairs(currentPromotionList) do
      if row == GameInfo.UnitPromotions[promotion] then
        hasPromotion = true;
      end
    end

    if row.PromotionClass == promotionClass then
      local promotionInstance;
      local promotionDefinition = row;
      m_uiNodes[row.UnitPromotionType] = row;

      if hasPromotion then
        promotionInstance = m_CompletedPromotionListInstanceMgr:GetInstance();
      else
        promotionInstance = m_PromotionListInstanceMgr:GetInstance();
      end

      promotionInstance.PromotionSelection:SetOffsetVal((row.Column-1)*SIZE_NODE_X + SIZE_BORDER_X, (row.Level-1)*SIZE_NODE_Y + SIZE_BORDER_Y);
      if (promotionDefinition ~= nil) then
        promotionInstance.PromotionName:SetText(Locale.ToUpper(promotionDefinition.Name));
        promotionInstance.PromotionDescription:SetText(Locale.Lookup(promotionDefinition.Description));
        local iconName = "ICON_" .. promotionDefinition.UnitPromotionType;
        local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName,32);
        if (textureOffsetX ~= nil) then
          promotionInstance.PromotionIcon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
        end
      end

      local bAvailable:boolean = false;
      -- are they available to be clicked?
      for i, item in pairs(tPromotions) do
        if(item == row.Index) then
          bAvailable = true;
          local ePromotion = item;
          promotionInstance.PromotionSlot:RegisterCallback( Mouse.eLClick, OnPromoteUnit );
          promotionInstance.PromotionSlot:SetVoid1( ePromotion );
        end
      end

      if bAvailable then
        promotionInstance.PromotionSlot:SetDisabled(false);
      else
        promotionInstance.PromotionSlot:SetDisabled(true);
      end
    end
  end

  Controls.PromotionScrollPanel:CalculateInternalSize();
  UIManager:QueuePopup(ContextPtr, PopupPriority.Current)
end

function OnPromoteUnitPopupReport( unit )
  local pUnit:table	= unit

  local bCanStart, tResults = UnitManager.CanStartCommand( pUnit, UnitCommandTypes.PROMOTE, true, true);
  local tPromotions		= tResults[UnitCommandResults.PROMOTIONS];

  local unitExperience = pUnit:GetExperience();
  local currentPromotionList :table = unitExperience:GetPromotions();
  local promotionClass = GameInfo.Units[pUnit:GetUnitType()].PromotionClass;

  local strengthString:string = "";
  local experienceString:string = "";
  if pUnit:GetCombat() > 0 then
    strengthString = strengthString .. "[ICON_Strength]" ..pUnit:GetCombat()
  end
  if pUnit:GetRangedCombat() > 0 then
    strengthString = strengthString .. "[ICON_Ranged]" ..pUnit:GetRangedCombat()
  end
  if pUnit:GetBombardCombat() > 0 then
    strengthString = strengthString .. "[ICON_Bombard]" ..pUnit:GetBombardCombat()
  end
  if pUnit:GetAntiAirCombat() > 0 then
    strengthString = strengthString .. "[ICON_AntiAir_Large]" ..pUnit:GetAntiAirCombat()
  end
  if pUnit:GetReligiousStrength() > 0 then
    strengthString = strengthString .. "[ICON_Religion]" ..pUnit:GetReligiousStrength()
  end
  if pUnit:GetMaxMoves() > 0 then
    strengthString = strengthString .. "[ICON_Movement]" ..pUnit:GetMaxMoves()
  end

  experienceString = Locale.Lookup("LOC_HUD_UNIT_PANEL_XP") .. " " .. unitExperience:GetExperiencePoints();

  Controls.StrMoveLabel:SetText(Locale.Lookup(strengthString));
  Controls.ExperienceLabel:SetText(Locale.Lookup(experienceString));

  m_PromotionListInstanceMgr:ResetInstances();
  m_CompletedPromotionListInstanceMgr:ResetInstances();
  m_kLineIM:ResetInstances();
  m_uiNodes = {};
  local hasPromotion:boolean;

  for row in GameInfo.UnitPromotions() do

    if row.PromotionClass == promotionClass then
      m_uiNodes[row.UnitPromotionType] = row;
    end
  end

  local numUnlocks = 0;
  for _, i in pairs(m_uiNodes) do
    for row in GameInfo.UnitPromotionPrereqs() do
      hasPromotion = false;
      numUnlocks = 0

      if row.PrereqUnitPromotion == i.UnitPromotionType then
        local previousRow	:number = i.Level;
        local previousColumn:number = i.Column;
        local currentRow:number = m_uiNodes[row.UnitPromotion].Level;
        local currentColumn:number = m_uiNodes[row.UnitPromotion].Column;

        for _, promotion in pairs(currentPromotionList) do
          if row.UnitPromotion == GameInfo.UnitPromotions[promotion].UnitPromotionType or i.UnitPromotionType == GameInfo.UnitPromotions[promotion].UnitPromotionType then
            numUnlocks = numUnlocks+1;
          end
        end
        hasPromotion = numUnlocks >= 2;

        if (currentColumn > previousColumn or currentColumn < previousColumn) and  (currentRow > previousRow or currentRow < previousRow) then
          local inst	:table = m_kLineIM:GetInstance();
          local line1	:table = inst.LineImage;
          inst = m_kLineIM:GetInstance();
          local line2:table = inst.LineImage;
          inst = m_kLineIM:GetInstance();
          local line3:table = inst.LineImage;
          inst = m_kLineIM:GetInstance();
          local line4:table = inst.LineImage;
          inst = m_kLineIM:GetInstance();
          local line5:table = inst.LineImage;

          local PrereqX = currentColumn*SIZE_NODE_X + SIZE_BORDER_X - SIZE_NODE_X_HALF;
          local MyX = previousColumn*SIZE_NODE_X + SIZE_BORDER_X - SIZE_NODE_X_HALF;
          local PrereqY = (math.min(previousRow,currentRow)-1)*SIZE_NODE_Y + SIZE_BORDER_Y + SIZE_ROW_Y;
          local MyY = (math.max(previousRow,currentRow)-1)*SIZE_NODE_Y + SIZE_BORDER_Y;
          local CurveY = PrereqY + LINE_BEFORE_CURVE;

          line1:SetOffsetVal(MyX, PrereqY);
          line1:SetSizeVal(SIZE_PATH, CurveY - PrereqY-SIZE_PATH_HALF);

          line2:SetOffsetVal(MyX, CurveY-SIZE_PATH_HALF);
          line2:SetSizeVal(SIZE_PATH, SIZE_PATH);

          line3:SetOffsetVal(math.min(PrereqX, MyX)+SIZE_PATH, CurveY-SIZE_PATH_HALF);
          line3:SetSizeVal(math.abs(PrereqX - MyX)-SIZE_PATH, SIZE_PATH);

          line4:SetOffsetVal(PrereqX, CurveY-SIZE_PATH_HALF);
          line4:SetSizeVal(SIZE_PATH, SIZE_PATH);

          line5:SetOffsetVal(PrereqX, CurveY + SIZE_PATH_HALF);
          line5:SetSizeVal(SIZE_PATH, MyY - CurveY - SIZE_PATH_HALF);

          if hasPromotion then
            line1:SetTexture("Controls_TreePathNS");
            line3:SetTexture("Controls_TreePathEW");
            line5:SetTexture("Controls_TreePathNS");

            if( PrereqX < MyX) then
              line2:SetTexture("Controls_TreePathEN");
              line4:SetTexture("Controls_TreePathNE");
            else
              line2:SetTexture("Controls_TreePathSE");
              line4:SetTexture("Controls_TreePathES");
            end

            line1:SetColor(0xFF71A2BF);
            line2:SetColor(0xFF71A2BF);
            line3:SetColor(0xFF71A2BF);
            line4:SetColor(0xFF71A2BF);
            line5:SetColor(0xFF71A2BF);
          else
            line1:SetTexture("Controls_TreePathDashNS");
            line3:SetTexture("Controls_TreePathDashEW");
            line5:SetTexture("Controls_TreePathDashNS");

            if( PrereqX < MyX) then
              line2:SetTexture("Controls_TreePathDashEN");
              line4:SetTexture("Controls_TreePathDashNE");
            else
              line2:SetTexture("Controls_TreePathDashSE");
              line4:SetTexture("Controls_TreePathDashES");
            end

            --line1:SetColor(63,83,100,255);
            --line2:SetColor(63,83,100,255);
            --line3:SetColor(63,83,100,255);
            --line4:SetColor(63,83,100,255);
            --line5:SetColor(63,83,100,255);
          end
        else
          local inst:table = m_kLineIM:GetInstance();
          local line:table = inst.LineImage;
          if(currentColumn > previousColumn or currentColumn < previousColumn) then
            local startX:number= (math.min(previousColumn,currentColumn))*SIZE_NODE_X + SIZE_BORDER_X;
            local endX :number = (math.max(previousColumn,currentColumn)-1)*SIZE_NODE_X + SIZE_BORDER_X;
            local yVal:number = (currentRow-1)*SIZE_NODE_Y + SIZE_NODE_Y_HALF;

            line:SetOffsetVal(startX, yVal);
            line:SetSizeVal( endX - startX, SIZE_PATH);
            if hasPromotion then
              line:SetTexture("Controls_TreePathEW");
              line:SetColor(0xFF71A2BF);
            else
              line:SetTexture("Controls_TreePathDashEW");
              --line:SetColor(63,83,100,255);
            end
          else
            local startY:number= (math.min(previousRow,currentRow)-1)*SIZE_NODE_Y + SIZE_BORDER_Y + SIZE_ROW_Y;
            local endY :number = (math.max(previousRow,currentRow)-1)*SIZE_NODE_Y + SIZE_BORDER_Y;
            local XVal:number = currentColumn*SIZE_NODE_X + SIZE_BORDER_X - SIZE_NODE_X_HALF;

            line:SetOffsetVal(XVal, startY);
            line:SetSizeVal(SIZE_PATH,  endY - startY);
            if hasPromotion then
              line:SetTexture("Controls_TreePathNS");
              line:SetColor(0xFF71A2BF);
            else
              line:SetTexture("Controls_TreePathDashNS");
              --line:SetColor(63,83,100,255);
            end
          end
        end
      end
    end
  end

  for row in GameInfo.UnitPromotions() do
    hasPromotion = false;
    for i, promotion in pairs(currentPromotionList) do
      if row == GameInfo.UnitPromotions[promotion] then
        hasPromotion = true;
      end
    end

    if row.PromotionClass == promotionClass then
      local promotionInstance;
      local promotionDefinition = row;
      m_uiNodes[row.UnitPromotionType] = row;

      if hasPromotion then
        promotionInstance = m_CompletedPromotionListInstanceMgr:GetInstance();
      else
        promotionInstance = m_PromotionListInstanceMgr:GetInstance();
      end

      promotionInstance.PromotionSelection:SetOffsetVal((row.Column-1)*SIZE_NODE_X + SIZE_BORDER_X, (row.Level-1)*SIZE_NODE_Y + SIZE_BORDER_Y);
      if (promotionDefinition ~= nil) then
        promotionInstance.PromotionName:SetText(Locale.ToUpper(promotionDefinition.Name));
        promotionInstance.PromotionDescription:SetText(Locale.Lookup(promotionDefinition.Description));
        local iconName = "ICON_" .. promotionDefinition.UnitPromotionType;
        local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName,32);
        if (textureOffsetX ~= nil) then
          promotionInstance.PromotionIcon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
        end
      end

      local bAvailable:boolean = false;
      -- are they available to be clicked?
      for i, item in pairs(tPromotions) do
        if(item == row.Index) then
          bAvailable = true;
          local ePromotion = item;
          promotionInstance.PromotionSlot:RegisterCallback( Mouse.eLClick, function() local tParameters = {}; tParameters[UnitCommandTypes.PARAM_PROMOTION_TYPE] = ePromotion; UnitManager.RequestCommand( pUnit, UnitCommandTypes.PROMOTE, tParameters ) end )

        end
      end

      if bAvailable then
        promotionInstance.PromotionSlot:SetDisabled(false);
      else
        promotionInstance.PromotionSlot:SetDisabled(true);
      end
    end
  end

  Controls.PromotionScrollPanel:CalculateInternalSize();
  UIManager:QueuePopup(ContextPtr, PopupPriority.Current)
end


-- ===========================================================================
function Initialize()
  -- Controls Events
  Controls.CloseButton:RegisterCallback( eLClick, OnClose );
  ContextPtr:SetInitHandler( OnInit );

  LuaEvents.UnitPanel_PromoteUnit.Add(OnPromoteUnitPopup);
  LuaEvents.UnitPanel_HideUnitPromotion.Add(OnClose);
  LuaEvents.Report_PromoteUnit.Add(function( unit ) OnPromoteUnitPopupReport( unit ) end);
end
Initialize();
