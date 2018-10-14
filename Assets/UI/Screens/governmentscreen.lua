-- ===========================================================================
--  GovernmentScreen
--  Set Government and the civic policies.
--
--  "k" is for key
--
--  Original Author: Tronster
-- ===========================================================================
include("DragSupport");
include("InstanceManager");
include("SupportFunctions");  -- Clamp
include("TabSupport");
include("Civ6Common");
include("PopupDialog");
include("ModalScreen_PlayerYieldsHelper");
include("GameCapabilities");

-- ===========================================================================
--  DEBUG
--  Toggle these for temporary debugging help.
-- ===========================================================================
local m_debugShowAllPolicies  :boolean = false;   -- (false) When true all policy cards (despite player's progression) will be shown in the catalog
local m_debugShowPolicyIDs    :boolean = false;   -- (false) Show the rowids on policy cards
local m_debugOutputGovInfo    :boolean = false;   -- (false) Output to console information about governments

-- ===========================================================================
--  CONSTANTS / DEFINES
-- ===========================================================================

-- Toggle these based on the game engine rules.
local m_isAllowAnythingInWildcardSlot :boolean = true;  -- Currently engine doesn't allow because on confirmation Culture::CanSlotPolicy() first checks !IsPolicyActive( ePolicy ), which fails.
local m_isAllowWildcardsAnywhere    :boolean = false; -- ...
local m_isLocalPlayerTurn       :boolean = true;

local COLOR_GOVT_UNSELECTED			:number = 0xffe9dfc7;				-- Background for unselected background (or forground text color on non-selected).
local COLOR_GOVT_SELECTED       :number = 0xff261407;				-- Background for selected background (or forground text color on non-selected).
local COLOR_GOVT_LOCKED         :number = 0xffAAAAAA;
local DATA_FIELD_CURRENT_FILTER :string = "_CURRENT_FILTER";
local DATA_FIELD_TOTAL_SLOTS    :string = "_TOTAL_SLOTS";   -- Total slots for a government item in the "tree-like" view

local ROW_INDEX :table = {
  MILITARY = 1,
  ECONOMIC = 2,
  DIPLOMAT = 3, -- yes this is to make the names line up. also required for matching with gamecore.
  WILDCARD = 4
};
local ROW_SLOT_TYPES :table = {};
  ROW_SLOT_TYPES[ROW_INDEX.MILITARY]	= "SLOT_MILITARY";
  ROW_SLOT_TYPES[ROW_INDEX.ECONOMIC]	= "SLOT_ECONOMIC";
  ROW_SLOT_TYPES[ROW_INDEX.DIPLOMAT]	= "SLOT_DIPLOMATIC";
  ROW_SLOT_TYPES[ROW_INDEX.WILDCARD]	= "SLOT_WILDCARD";
local SLOT_ORDER_IN_CATALOG :table = {
  SLOT_MILITARY		= 1,
  SLOT_ECONOMIC		= 2,
  SLOT_DIPLOMATIC		= 3,
  SLOT_GREAT_PERSON	= 4,
  SLOT_WILDCARD		= 5,
};

local EMPTY_POLICY_TYPE           :string = "empty";                -- For a policy slot without a type
local KEY_POLICY_TYPE             :string = "PolicyType";           -- Key on a catalog UI element that holds the PolicyType; so corresponding data can be found
local KEY_POLICY_SLOT				      :string = "PolicySlot";
local KEY_DRAG_TARGET_CONTROL     :string = "DragTargetControl";		-- What control should we be testing against as a drag target?
local KEY_LIFTABLE_CONTROL			  :string = "LiftableControl";		  -- What control is safe to move without futzing up the dragtarget evaluations?
local KEY_ROW_ID                  :string = "RowNum";               -- Key on a row UI element to note which row it came from.
local PADDING_POLICY_ROW_ITEM     :number = 3;
local PADDING_POLICY_LIST_HEADER  :number = 50;
local PADDING_POLICY_LIST_BOTTOM  :number = 20;
local PADDING_POLICY_LIST_ITEM    :number = 20;
local PADDING_POLICY_SCROLL_AREA  :number = 10;
local PIC_CARD_SUFFIX_SMALL       :string = "_Small";
local PIC_CARD_TYPE_DIPLOMACY     :string = "Governments_DiplomacyCard";
local PIC_CARD_TYPE_ECONOMIC      :string = "Governments_EconomicCard";
local PIC_CARD_TYPE_MILITARY      :string = "Governments_MilitaryCard";
local PIC_CARD_TYPE_WILDCARD      :string = "Governments_WildcardCard";
local PIC_PERCENT_BRIGHT          :string = "Governments_PercentWhite";
local PIC_PERCENT_DARK            :string = "Governments_PercentBlue";
local PICS_SLOT_TYPE_CARD_BGS :table = {
  SLOT_MILITARY      = PIC_CARD_TYPE_MILITARY,
  SLOT_ECONOMIC      = PIC_CARD_TYPE_ECONOMIC,
  SLOT_DIPLOMATIC    = PIC_CARD_TYPE_DIPLOMACY,
  SLOT_WILDCARD      = PIC_CARD_TYPE_WILDCARD,
  SLOT_GREAT_PERSON  = PIC_CARD_TYPE_WILDCARD, -- Great person is also utilized as a wild card.
};

local IMG_POLICYCARD_BY_ROWIDX :table = {};
  IMG_POLICYCARD_BY_ROWIDX[ROW_INDEX.MILITARY] = PIC_CARD_TYPE_MILITARY;
  IMG_POLICYCARD_BY_ROWIDX[ROW_INDEX.ECONOMIC] = PIC_CARD_TYPE_ECONOMIC;
  IMG_POLICYCARD_BY_ROWIDX[ROW_INDEX.DIPLOMAT] = PIC_CARD_TYPE_DIPLOMACY;
  IMG_POLICYCARD_BY_ROWIDX[ROW_INDEX.WILDCARD] = PIC_CARD_TYPE_WILDCARD;
local SCREEN_ENUMS :table = {
    MY_GOVERNMENT = 1,
    GOVERNMENTS   = 2,
    POLICIES      = 3
}
local SIZE_TAB_BUTTON_TEXT_PADDING            :number = 50;
local SIZE_HERITAGE_BONUS                     :number = 48;
local SIZE_GOV_ITEM_WIDTH                     :number = 400;
local SIZE_GOV_ITEM_HEIGHT                    :number = 152;  -- 238 minus shadow
local SIZE_GOV_DIVIDER_WIDTH                  :number = 75;
local SIZE_POLICY_ROW_MIN                     :number = 675;
local SIZE_POLICY_ROW_MAX                     :number = 1120; -- Evaluated size when in 1080p. Fits 6 cards nicely.
local SIZE_POLICY_CATALOG_MIN                 :number = 512+15; -- Half minspec screen + some extra
local SIZE_POLICY_CATALOG_MAX                 :number = 1400; -- Selected by me making up a number because unbounded looks goofy in 4k
local SIZE_POLICY_CARD_X                      :number = 130;
local SIZE_POLICY_CARD_Y                      :number = 150;
local SIZE_MIN_SPEC_X                         :number = 1024;
local TXT_GOV_ASSIGN_POLICIES                 :string = Locale.Lookup("LOC_GOVT_ASSIGN_ALL_POLICIES");
local TXT_GOV_CONFIRM_POLICIES                :string = Locale.Lookup("LOC_GOVT_CONFIRM_POLICIES");
local TXT_GOV_CONFIRM_GOVERNMENT              :string = Locale.Lookup("LOC_GOVT_CONFIRM_GOVERNMENT");
local TXT_GOV_POPUP_NO                        :string = Locale.Lookup("LOC_GOVT_PROMPT_NO");
local TXT_GOV_POPUP_PROMPT_POLICIES_CLOSE     :string = Locale.Lookup("LOC_GOVT_POPUP_PROMPT_POLICIES_CLOSE");
local TXT_GOV_POPUP_PROMPT_POLICIES_CONFIRM   :string = Locale.Lookup("LOC_GOVT_POPUP_PROMPT_POLICIES_CONFIRM");
local TXT_GOV_POPUP_YES                       :string = Locale.Lookup("LOC_GOVT_PROMPT_YES");
local MAX_HEIGHT_POLICIES_LIST                :number = 600;
local MAX_HEIGHT_GOVT_DESC                    :number = 25;
local MAX_BEFORE_TRUNC_GOVT_BONUS             :number = 229;
local MAX_BEFORE_TRUNC_BONUS_TEXT             :number = 219;
local MAX_BEFORE_TRUNC_HERITAGE_BONUS         :number = 225;

-- ===========================================================================
--	GLOBALS
-- ===========================================================================
g_kGovernments = {};
g_kCurrentGovernment = nil;
g_isMyGovtTabDirty = false;
g_isGovtTabDirty = false;
g_isPoliciesTabDirty = false;
m_kUnlockedPolicies = nil;
m_kNewPoliciesThisTurn = nil;

-- ===========================================================================
--  VARIABLES
-- ===========================================================================

local m_policyCardIM          :table = InstanceManager:new("PolicyCard",          "Content",  Controls.PolicyCatalog);
local m_kGovernmentLabelIM    :table = InstanceManager:new("GovernmentEraLabelInstance",  "Top",    Controls.GovernmentDividers );
local m_kGovernmentItemIM     :table = InstanceManager:new("GovernmentItemInstance",    "Top",    Controls.GovernmentScroller );

local m_ePlayer                 :number = -1;
local m_kAllPlayerData          :table  = {};   -- Holds copy of player data for all local players
local m_kBonuses                :table  = {}
local m_governmentChangeType    :string = "";   -- The government type proposed being changed to.
local m_isPoliciesChanged       :boolean= false;
local m_kPolicyCatalogData      :table  = {};
local m_kPolicyCatalogOrder     :table  = {};   -- Track order of policies to display
local m_kPolicyFilters          :table  = {};
local m_kPolicyFilterCurrent    :table  = nil;
local m_kUnlockedGovernments    :table  = {};
local m_tabs                    :table;
local m_uiGovernments           :table  = {};
local m_width                   :number = SIZE_MIN_SPEC_X;  -- Screen Width (default / min spec)
local m_currentCivicType        :string = nil;
local m_civicProgress           :number = 0;
local m_civicCost               :number = 0;
local m_bShowMyGovtInPolicies   :boolean = false;

-- Used to lerp PolicyRows and PolicyContainer when sliding between MyGovt and Policy tabs
local m_AnimRowSize :table = {
  mygovt = 0,
  policy = 0,
}
local m_AnimCatalogSize :table = {
  mygovt = 0,
  policy = 0,
}
local m_AnimCatalogOffset :table = {
  mygovt = 0,
  policy = 0,
}
local m_AnimMyGovtOffset :table = {
  mygovt = 0,
  policy = 0,
}

-- An array of arrays of tables. Contains one entry for each member of ROW_INDEX.
-- m_ActivePolicyRows[ROW_INDEX.MILITARY] is an array of all the slots for the Military row.
-- Each slot is a "SlotData" table containing UI_RowIndex, GC_SlotIndex, and GC_PolicyType.
-- UI_RowIndex is a value from ROW_INDEX matching the row this slot is in. This should not change.
-- GC_SlotIndex is the corresponding GameCore slot index for this slot. This should not change.
-- GC_PolicyType is the string type of the policy card currently in the slot. It is EMPTY_POLICY_TYPE by default.
local m_ActivePolicyRows      :table = {};
local m_ActivePoliciesByType  :table = {}; -- PolicyType string -> SlotData table
local m_ActivePoliciesBySlot  :table = {}; -- (GC Slot Index + 1) -> SlotData table

local m_ActiveCardInstanceArray	:table = {}; -- (GC Slot Index + 1) -> Card/EmptyCard Instance

-- We only track slots so as to not keep instance tables hanging around when they shouldn't.
-- Which slot is currently targetted by a drag & drop?
local m_PrevDropTargetSlot :number = -1;
-- Which slot is currently hovered? (Stack because multiple things may be moused over, but only one should be on top)
local m_MouseoverStack :table = {};


-- ===========================================================================
--  FUNCTIONS
-- ===========================================================================
function GetFreeSlotCountForRow( nRowIndex:number )
  local nFree :number = 0;
  for _,tSlotData in ipairs(m_ActivePolicyRows[nRowIndex].SlotArray) do
    if ( tSlotData.GC_PolicyType == EMPTY_POLICY_TYPE ) then
      nFree = nFree + 1;
    end
  end
  return nFree;
end
function IsPolicyTypeActive( strPolicyType:string )
  return m_ActivePoliciesByType[strPolicyType] ~= nil;
end

function RemoveActivePolicyAtSlotIndex( nSlotIndex:number )
  local tSlotData :table = m_ActivePoliciesBySlot[nSlotIndex+1];
  assert( tSlotData );
  m_ActivePoliciesByType[tSlotData.GC_PolicyType] = nil;
  tSlotData.GC_PolicyType = EMPTY_POLICY_TYPE;
  m_isPoliciesChanged = true;
end
function SetActivePolicyAtSlotIndex( nSlotIndex:number, strPolicyType:string )
  local tSlotData :table = m_ActivePoliciesBySlot[nSlotIndex+1];
  assert( tSlotData );
  m_ActivePoliciesByType[strPolicyType] = tSlotData;
  m_ActivePoliciesByType[tSlotData.GC_PolicyType] = nil;
  tSlotData.GC_PolicyType = strPolicyType;
  m_isPoliciesChanged = true;
end
function GetFirstFreeSlotIndex( nRowIndex:number )
  for _,tSlotData in ipairs(m_ActivePolicyRows[nRowIndex].SlotArray) do
    if ( tSlotData.GC_PolicyType == EMPTY_POLICY_TYPE ) then
      return tSlotData.GC_SlotIndex;
    end
  end
  return -1;
end

function IsSlotTypeLegalInRow( nRowIndex:number, strSlotType:string )
  -- Treat great people like wildcards.
  if strSlotType == "SLOT_GREAT_PERSON" then strSlotType = "SLOT_WILDCARD"; end
  return #m_ActivePolicyRows[nRowIndex].SlotArray > 0 and 
    (ROW_SLOT_TYPES[nRowIndex] == strSlotType or 
    (m_isAllowWildcardsAnywhere and strSlotType == "SLOT_WILDCARD") or
    (m_isAllowAnythingInWildcardSlot and nRowIndex == ROW_INDEX.WILDCARD));
end
function IsPolicyTypeLegalInRow( nRowIndex:number, strPolicyType:string )
  return IsSlotTypeLegalInRow( nRowIndex, m_kPolicyCatalogData[strPolicyType].SlotType );
end


-- ===========================================================================
--  Setup the screen elements for the given resolution.
-- ===========================================================================

function Resize()
  m_width, _  = UIManager:GetScreenSizeVal();       -- Cache screen dimensions
  Controls.MainContainer:SetSizeX(m_width);
  local nExtraSpace = m_width - SIZE_MIN_SPEC_X; -- What extra do we have to play with?

  -- Zone widths while in MyGovt screen - pretty fixed.
  local nGovtWidth = Controls.MyGovernment:GetSizeX();
  local nRowsWithGovtWidth = math.min( SIZE_POLICY_ROW_MAX, m_width - nGovtWidth - nExtraSpace/2 );
  local nRowsWithGovtOffset = m_width/2 - (nGovtWidth + nRowsWithGovtWidth)/2 + nGovtWidth;

  -- Zone widths while in Catalogue screen - less fixed. If we have enough space, we may add the MyGovt card.
  local nRowsWithCatalogOffset = 0;
  local nRowsWithCatalogWidth = math.min(SIZE_POLICY_ROW_MIN, m_width - SIZE_POLICY_CATALOG_MIN);
  local nPolicyCatalogWidth = math.max(SIZE_POLICY_CATALOG_MIN, m_width - nRowsWithCatalogWidth);

  -- Do we have the extra space to fit MyGovt card onscreen in Catalog tab?
  m_bShowMyGovtInPolicies = (nExtraSpace/2 > nGovtWidth);
  if (m_bShowMyGovtInPolicies) then
    nPolicyCatalogWidth = nPolicyCatalogWidth - nGovtWidth - 15;
    nRowsWithCatalogOffset = nGovtWidth;
  end

  -- Now that we've evaluated sizes to make sure everything fits, apply size maximums and center as necessary.
  nPolicyCatalogWidth = math.min(nPolicyCatalogWidth, SIZE_POLICY_CATALOG_MAX);
  local nPolicyTotalSize = nRowsWithCatalogOffset + nRowsWithCatalogWidth + nPolicyCatalogWidth;
  local nPolicyScreenPadding = (m_width - nPolicyTotalSize) / 2;
  nRowsWithCatalogOffset = nRowsWithCatalogOffset + nPolicyScreenPadding;

  -- Anim: Policy tab values
  Controls.RowAnim:SetBeginVal( nRowsWithCatalogOffset, 0 );
  m_AnimRowSize.policy = nRowsWithCatalogWidth;
  m_AnimCatalogSize.policy = nPolicyCatalogWidth;
  m_AnimCatalogOffset.policy = 0;
  m_AnimMyGovtOffset.policy = m_bShowMyGovtInPolicies and 0 or nPolicyScreenPadding+50; -- extra 50 causes it to leave the screen slightly but noticeably faster

  -- Anim: MyGovt tab values
  Controls.RowAnim:SetEndVal( nRowsWithGovtOffset, 0 );
  m_AnimRowSize.mygovt = nRowsWithGovtWidth;
  m_AnimCatalogSize.mygovt = nPolicyCatalogWidth;
  m_AnimCatalogOffset.mygovt = m_width - ( nGovtWidth + nRowsWithGovtWidth);
  m_AnimMyGovtOffset.mygovt = 0;


  Controls.PoliciesContainer:SetSizeX(nPolicyCatalogWidth);
  local TAB_PADDING = 50;
  local tabX = Controls.ButtonMyGovernment:GetSizeX() + Controls.ButtonPolicies:GetSizeX() + Controls.ButtonGovernments:GetSizeX() + TAB_PADDING;
  Controls.TabArea:SetSizeX(tabX);

  local textControl :table = Controls.ButtonPolicies:GetTextControl();
  local sizeX     :number = textControl:GetSizeX();
  Controls.ButtonPolicies:SetSizeX( sizeX + SIZE_TAB_BUTTON_TEXT_PADDING );
  Controls.SelectPolicies:SetSizeX( sizeX + SIZE_TAB_BUTTON_TEXT_PADDING + 4 );

  textControl = Controls.ButtonGovernments:GetTextControl();
  sizeX = textControl:GetSizeX();
  Controls.ButtonGovernments:SetSizeX( sizeX + SIZE_TAB_BUTTON_TEXT_PADDING );
  Controls.SelectGovernments:SetSizeX( sizeX + SIZE_TAB_BUTTON_TEXT_PADDING + 4 );

  textControl = Controls.ButtonMyGovernment:GetTextControl();
  sizeX = textControl:GetSizeX();

  -- CQUI : if MyGovernment is shown in Policy then don't show tab MyGovernment
  if (m_bShowMyGovtInPolicies) then
    Controls.ButtonMyGovernment:SetSizeX( 0 );
    Controls.SelectMyGovernment:SetSizeX( 0 );
  else
    Controls.ButtonMyGovernment:SetSizeX( sizeX + SIZE_TAB_BUTTON_TEXT_PADDING );
    Controls.SelectMyGovernment:SetSizeX( sizeX + SIZE_TAB_BUTTON_TEXT_PADDING + 4 );
  end

  -- Screen size changing means we need to rejigger all the UI elements
  RefreshAllData();
  -- If said UI elements are CURRENTLY visible, we need to do that now.
  if ContextPtr:IsVisible() then
    RealizeMyGovernmentPage();
    RealizeGovernmentsPage();
    RealizePoliciesPage();
  end
end


-- ===========================================================================
--  Realize all the content for the existing government
-- ===========================================================================
function RealizeMyGovernmentPage()
  if not g_isMyGovtTabDirty then
    return;
  end
  g_isMyGovtTabDirty = false;

  RealizePolicyCatalog();
  RealizeActivePoliciesRows();

  local kPlayer   :table  = Players[m_ePlayer];
  local kPlayerCulture:table  = kPlayer:GetCulture();
  local iBonusIndex :number = -1;
  local bonusName   :string = (g_kCurrentGovernment.Index ~= -1) and GameInfo.Governments[g_kCurrentGovernment.Index].BonusType or "NO_GOVERNMENTBONUS";
  local currentGovernmentName:string = Locale.Lookup(g_kCurrentGovernment.Name);

  -- Clear heritage bonuses; will rebuild them throughout...
  Controls.HeritageBonusStack:DestroyAllChildren();

  -- If bonus exists for current one.
  if bonusName ~= "NO_GOVERNMENTBONUS" then
    iBonusIndex = GameInfo.GovernmentBonusNames[bonusName].Index;
  end

  local isHeritageBonusEmpty :boolean = true;

  if iBonusIndex ~= -1 then

    Controls.BonusStack:SetHide( false );

    local iFlatBonus				:number = kPlayerCulture:GetFlatBonus(iBonusIndex);
    local iIncrementingBonus		:number = kPlayerCulture:GetIncrementingBonus(iBonusIndex);
    local iBonusIncrement			:number = kPlayerCulture:GetIncrementingBonusIncrement(iBonusIndex);
    local iTurnsRequiredForBonus	:number = kPlayerCulture:GetIncrementingBonusInterval(iBonusIndex);
    local iTurnsTillNextBonus		:number = kPlayerCulture:GetIncrementingBonusTurnsUntilNext(iBonusIndex);
    local accumulatedBonusText		:string = Locale.ToUpper(Locale.Lookup(g_kCurrentGovernment.BonusAccumulatedText));
    local accumulatedBonusTooltip	:string = Locale.Lookup(g_kCurrentGovernment.BonusAccumulatedTooltip);

    Controls.BonusPercent:SetText( tostring(iFlatBonus) );
    Controls.BonusText:SetText(accumulatedBonusText );
    if Controls.BonusText:GetSizeY() > MAX_HEIGHT_GOVT_DESC then
      local bonusTextString :string = Controls.BonusText:GetText();
      if TruncateString(Controls.BonusText, MAX_BEFORE_TRUNC_BONUS_TEXT, bonusTextString) then
        Controls.BonusText:SetToolTipString(bonusTextString .. "[NEWLINE]" .. accumulatedBonusTooltip);
      end
    end
    Controls.GovPercentBonusArea:SetToolTipString( accumulatedBonusTooltip );

    if not HasCapability("CAPABILITY_GOVERNMENTS_LEGACY_BONUSES") then
      Controls.BonusPercent:SetHide(true);
      Controls.QuillImage:SetHide(true);
      Controls.PercentBubble:SetHide(true);
      Controls.DescriptionContainer:SetOffsetX(40);
      Controls.BonusText:SetWrapWidth(275);
    end

    ------------------------------------------------------------
    --Create Instances
    ------------------------------------------------------------
    -- Add current heritage/incrementing bonus or extra bonuses
    local heritageInstance  :table = {};
    ContextPtr:BuildInstanceForControl( "HeritageBonusInstance", heritageInstance, Controls.HeritageBonusStack );
    isHeritageBonusEmpty = false;
    if TruncateString(heritageInstance.Text, MAX_BEFORE_TRUNC_HERITAGE_BONUS, accumulatedBonusText) then
      heritageInstance.Text:SetToolTipString(accumulatedBonusText);
    end
    local description:string = Locale.Lookup("LOC_GOVT_HERITAGE_BONUS_NEXT", iTurnsTillNextBonus, currentGovernmentName);
    if TruncateString(heritageInstance.Desc, MAX_BEFORE_TRUNC_HERITAGE_BONUS, description) then
      heritageInstance.Desc:SetToolTipString(description);
    end

    heritageInstance.Num:SetText( "+" .. tostring(iBonusIncrement) );
    heritageInstance.PolicyIcon:SetHide( false );
    heritageInstance.Fade:SetHide(false);
    heritageInstance.PolicyMeter:SetPercent((iTurnsRequiredForBonus - iTurnsTillNextBonus) / iTurnsRequiredForBonus);

    ------------------------------------------------------------
    --set visuals and text
    ------------------------------------------------------------
    if iIncrementingBonus > 0 then
      heritageInstance.BG:SetSizeY((SIZE_HERITAGE_BONUS * 2) + 2);
      local heritageInstanceCurrent:table = {};
      ContextPtr:BuildInstanceForControl( "HeritageBonusInstance", heritageInstanceCurrent, Controls.HeritageBonusStack );
      if TruncateString(heritageInstanceCurrent.Text, MAX_BEFORE_TRUNC_HERITAGE_BONUS, accumulatedBonusText) then
        heritageInstanceCurrent.Text:SetToolTipString(accumulatedBonusText);
      end
      local description:string = Locale.Lookup("LOC_GOVT_HERITAGE_BONUS_PREV", currentGovernmentName);
      if TruncateString(heritageInstanceCurrent.Desc, MAX_BEFORE_TRUNC_HERITAGE_BONUS, description) then
        heritageInstanceCurrent.Desc:SetToolTipString(description);
      end
      heritageInstanceCurrent.Num:SetText( tostring(iIncrementingBonus) );
      heritageInstanceCurrent.PolicyIcon:SetHide(true);
      heritageInstanceCurrent.Fade:SetHide(true);
      heritageInstanceCurrent.BG:SetHide(true);
    else
      heritageInstance.BG:SetSizeY(SIZE_HERITAGE_BONUS);
      heritageInstance.BG:SetHide(false);
    end
  else
    Controls.BonusStack:SetHide( true );
  end

  local inherentBonusDesc :string = Locale.Lookup( g_kCurrentGovernment.BonusInherentText );
  Controls.GovernmentBonus:SetText( Locale.ToUpper( inherentBonusDesc ));
  Controls.GovernmentInfluence:SetText( "[ICON_Envoy]" .. g_kCurrentGovernment.BonusInfluenceNumber );
  Controls.GovernmentInfluence:SetToolTipString( g_kCurrentGovernment.BonusInfluenceText );
  Controls.GovernmentName:SetText( Locale.ToUpper(currentGovernmentName) );
  Controls.GovernmentImage:SetTexture(GameInfo.Governments[g_kCurrentGovernment.Index].GovernmentType);

  -- Fill out remaining heritage/incrementing bonuses (from prior governments that were held by this player)
  for governmentType,government in pairs(g_kGovernments) do
    -- Skip current one (already in list.
    if government.Index ~= g_kCurrentGovernment.Index then
      local iBonusIndex   :number = -1;
      local iIncrementingBonus:number = -1;
      local bonusName     :string = government.BonusType;
      if bonusName ~= "NO_GOVERNMENTBONUS" then
        iBonusIndex     = GameInfo.GovernmentBonusNames[bonusName].Index;
        iIncrementingBonus  = kPlayerCulture:GetIncrementingBonus(iBonusIndex);
      end
      if iIncrementingBonus > 0 then
        local heritageInstance:table = {};
        ContextPtr:BuildInstanceForControl( "HeritageBonusInstance", heritageInstance, Controls.HeritageBonusStack );
        isHeritageBonusEmpty = false;
        local accumulatedBonusText:string = Locale.ToUpper(Locale.Lookup(government.BonusAccumulatedText));
        if TruncateString(heritageInstance.Text, MAX_BEFORE_TRUNC_HERITAGE_BONUS, accumulatedBonusText) then
          heritageInstance.Text:SetToolTipString(accumulatedBonusText);
        end
        local description:string = Locale.Lookup("LOC_GOVT_HERITAGE_BONUS_PREV", Locale.Lookup(government.Name));
        if TruncateString(heritageInstance.Desc, MAX_BEFORE_TRUNC_HERITAGE_BONUS, description) then
          heritageInstance.Desc:SetToolTipString(description);
        end
        heritageInstance.Num:SetText( tostring(iIncrementingBonus) );
        heritageInstance.PolicyIcon:SetHide(true);
        heritageInstance.Fade:SetHide(true);
        heritageInstance.BG:SetHide(false);
      end
    end
  end

  if HasCapability("CAPABILITY_GOVERNMENTS_LEGACY_BONUSES") then
    Controls.HeritageBonusArea:SetHide(false);
    Controls.GovernmentTop:SetOffsetY(0);
  else
    Controls.HeritageBonusArea:SetHide(true);
    Controls.GovernmentTop:SetOffsetY(120);
  end

  Controls.GovernmentContentStack:CalculateSize()
  Controls.GovernmentTop:SetSizeY(Controls.GovernmentContentStack:GetSizeY() + 18);
  Controls.HeritageBonusStack:CalculateSize();
  Controls.HeritageScrollPanel:CalculateSize();
  Controls.HeritageBonusEmpty:SetHide(not isHeritageBonusEmpty);
end


-- ===========================================================================
--  Realize content for viewing/selecting all the governments
-- ===========================================================================
function RealizeGovernmentsPage()
  if not g_isGovtTabDirty then
    return;
  end
  g_isGovtTabDirty = false;

  -- This function uses the local player further down, so validate it now.
  if (Game.GetLocalPlayer() == -1) then
    return;
  end

  m_uiGovernments = {};
  m_kGovernmentItemIM:ResetInstances();

  local grid:table = {};
  local width:number=0;

  local isCivilopediaAvailable:boolean = not IsTutorialRunning();
  for governmentType,_ in pairs(g_kGovernments) do
    local inst :table = m_kGovernmentItemIM:GetInstance();
    inst[DATA_FIELD_TOTAL_SLOTS] = RealizeGovernmentInstance(governmentType, inst, isCivilopediaAvailable);
    table.insert(m_uiGovernments, inst);
  end

  -- Sort in temporary grid by # of items
  local grid:table = {};
  for _,inst in ipairs(m_uiGovernments) do
    if grid[ inst[DATA_FIELD_TOTAL_SLOTS] ] == nil then
      grid[ inst[DATA_FIELD_TOTAL_SLOTS] ] = {};
    end
    table.insert(grid[ inst[DATA_FIELD_TOTAL_SLOTS] ], inst);
  end

  m_kGovernmentLabelIM:ResetInstances();

  -- Layout based on grid
  local x:number = 0;
  local count:number = table.count(grid);
  local maxHeight:number = Controls.GovernmentTree:GetSizeY();
  for _,column in orderedPairs(grid) do
    local num				:number = table.count(column);
    local spaceFree			:number = maxHeight-(num*SIZE_GOV_ITEM_HEIGHT);
    local spaceBetweenEach	:number = spaceFree/ (num+1);
    for y=1,num,1 do
      inst = column[y];
      local posX:number = x * (SIZE_GOV_ITEM_WIDTH + SIZE_GOV_DIVIDER_WIDTH);
      local posY:number = (y * (spaceBetweenEach + SIZE_GOV_ITEM_HEIGHT)) - (SIZE_GOV_ITEM_HEIGHT);
      inst.Top:SetOffsetVal(posX , posY);	-- Spread centered
    end
    x = x + 1;
    if x < count then
      local dividerInst:table = m_kGovernmentLabelIM:GetInstance();
      dividerInst.EraTitle:SetText(Locale.ToRomanNumeral(x));
      dividerInst.Top:SetOffsetX(x * (SIZE_GOV_ITEM_WIDTH + SIZE_GOV_DIVIDER_WIDTH) - SIZE_GOV_DIVIDER_WIDTH);
    end
  end

  Controls.GovernmentBackground:SetSizeX(math.max( x * (SIZE_GOV_ITEM_WIDTH + SIZE_GOV_DIVIDER_WIDTH) - SIZE_GOV_DIVIDER_WIDTH, m_width ));
  Controls.GovernmentScroller:CalculateSize();

  RealizePoliciesList();

  -- Update states for Unlock button at bottom left of screen
  local kPlayer				:table = Players[m_ePlayer];
  local pPlayerCulture		:table = kPlayer:GetCulture();
  local playerTreasury		:table  = Players[Game.GetLocalPlayer()]:GetTreasury();
  local playerReligion		:table  = Players[Game.GetLocalPlayer()]:GetReligion();
  local isGovernmentChanged	:boolean= pPlayerCulture:GovernmentChangeMade();
  local iPolicyUnlockCost		:number = pPlayerCulture:GetCostToUnlockPolicies();
  local iGoldBalance			:number = playerTreasury:GetGoldBalance();
  local iFaithBalance			:number = playerReligion:GetFaithBalance();
  local bUnlockByFaith		:boolean= (GlobalParameters.GOVERNMENT_UNLOCK_WITH_FAITH ~= 0);

  if isGovernmentChanged then
    Controls.UnlockGovernmentsContainer:SetHide(true);
  elseif (table.count(m_kUnlockedGovernments) <= 1) then
    Controls.UnlockGovernmentsContainer:SetHide(true);
  elseif (iPolicyUnlockCost == 0 or g_kCurrentGovernment == nil) then
    Controls.UnlockGovernmentsContainer:SetHide(true);
  elseif (not bUnlockByFaith and iGoldBalance < iPolicyUnlockCost) then
    Controls.UnlockGovernmentsContainer:SetHide(false);
    Controls.UnlockGovernments:SetText(Locale.Lookup("LOC_GOVT_NEED_GOLD",iPolicyUnlockCost));
    Controls.UnlockGovernments:SetDisabled(true);
    AutoSizeGridButton(Controls.UnlockGovernments,150,41,20,"H");
    --Controls.UnlockGovernmentsContainer:SetSizeX(Controls.UnlockGovernments:GetSizeX() + 50);
  elseif (bUnlockByFaith and iFaithBalance < iPolicyUnlockCost) then
    Controls.UnlockGovernmentsContainer:SetHide(false);
    Controls.UnlockGovernments:SetText(Locale.Lookup("LOC_GOVT_NEED_FAITH",iPolicyUnlockCost));
    Controls.UnlockGovernments:SetDisabled(true);
    AutoSizeGridButton(Controls.UnlockGovernments,150,41,20,"H");
    --Controls.UnlockGovernmentsContainer:SetSizeX(Controls.UnlockGovernments:GetSizeX() + 50);
  else
    Controls.UnlockGovernmentsContainer:SetHide(false);
    if (bUnlockByFaith) then
      Controls.UnlockGovernments:SetText(Locale.Lookup("LOC_GOVT_UNLOCK_FAITH",iPolicyUnlockCost));
    else
      Controls.UnlockGovernments:SetText(Locale.Lookup("LOC_GOVT_UNLOCK_GOLD",iPolicyUnlockCost));
    end
    Controls.UnlockGovernments:SetDisabled(false);
    AutoSizeGridButton(Controls.UnlockGovernments,150,41,20,"H");
    --Controls.UnlockGovernmentsContainer:SetSizeX(Controls.UnlockGovernments:GetSizeX() + 50);
  end

  pPlayerCulture:SetGovernmentChangeConsidered(true);
end

-- ===========================================================================
--	By separating this function from RealizeGovernmentsPage we can extend
--	its behavior.
-- ===========================================================================
function RealizeGovernmentInstance(governmentType:string, inst:table, isCivilopediaAvailable:boolean)
  local government:table = g_kGovernments[governmentType];

  if(isCivilopediaAvailable) then
    inst.Top:RegisterCallback(Mouse.eRClick, function() LuaEvents.OpenCivilopedia(governmentType); end);
    inst.Selected:RegisterCallback(Mouse.eRClick, function() LuaEvents.OpenCivilopedia(governmentType); end);
  end

  local totalSlots  :number = 0;
  inst.SlotStack:DestroyAllChildren();
  for i=1,government.NumSlotMilitary,1 do
    local slotTypeInstance:table = {};
    ContextPtr:BuildInstanceForControl( "MiniSlotType", slotTypeInstance, inst.SlotStack );
    slotTypeInstance.TypeIcon:SetTexture(PIC_CARD_TYPE_MILITARY..PIC_CARD_SUFFIX_SMALL);
  end
  totalSlots = totalSlots + government.NumSlotMilitary;

  for i=1,government.NumSlotEconomic,1 do
    local slotTypeInstance:table = {};
    ContextPtr:BuildInstanceForControl( "MiniSlotType", slotTypeInstance, inst.SlotStack );
    slotTypeInstance.TypeIcon:SetTexture(PIC_CARD_TYPE_ECONOMIC..PIC_CARD_SUFFIX_SMALL);
  end
  totalSlots = totalSlots + government.NumSlotEconomic;

  for i=1,government.NumSlotDiplomatic,1 do
    local slotTypeInstance:table = {};
    ContextPtr:BuildInstanceForControl( "MiniSlotType", slotTypeInstance, inst.SlotStack );
    slotTypeInstance.TypeIcon:SetTexture(PIC_CARD_TYPE_DIPLOMACY..PIC_CARD_SUFFIX_SMALL);
  end
  totalSlots = totalSlots + government.NumSlotDiplomatic;

  for i=1,government.NumSlotWildcard,1 do
    local slotTypeInstance:table = {};
    ContextPtr:BuildInstanceForControl( "MiniSlotType", slotTypeInstance, inst.SlotStack );
    slotTypeInstance.TypeIcon:SetTexture(PIC_CARD_TYPE_WILDCARD..PIC_CARD_SUFFIX_SMALL);
  end
  totalSlots = totalSlots + government.NumSlotWildcard;

  -- Special logic if showing all (for ones that haven't been selected).
  if m_kUnlockedGovernments[governmentType] == nil then
    inst.Top:SetColor( COLOR_GOVT_LOCKED );
    inst.ImageFrame:SetColor( COLOR_GOVT_LOCKED );
    inst.GovernmentImage:SetHide( true );
    inst.Disabled:SetHide( false );
    inst.ArtLeft:SetColor( COLOR_GOVT_LOCKED );
    inst.ArtRight:SetColor( COLOR_GOVT_LOCKED );

    local prereqCivic = GameInfo.Governments[governmentType].PrereqCivic;
    if prereqCivic ~= nil then
      inst.PrereqCivicIcon:SetIcon("ICON_".. prereqCivic);
      inst.UnlockedIcon:SetToolTipString(Locale.Lookup("LOC_GOVT_CIVIC_REQUIRED", Locale.Lookup(GameInfo.Civics[prereqCivic].Name)));
      inst.PrereqCivicIcon:SetHide(false);
      inst.UnlockedIcon:SetHide(false);
      if (m_currentCivicType == prereqCivic) then
        inst.CultureMeter:SetPercent(m_civicProgress/m_civicCost);
        inst.CultureMeter:SetHide(false);
        inst.CultureBacking:SetHide(false);
      else
        inst.CultureMeter:SetHide(true);
        inst.CultureBacking:SetHide(true);
      end
    else
      inst.PrereqCivicIcon:SetHide(true);
      inst.UnlockedIcon:SetHide(true);
      inst.CultureMeter:SetHide(true);
      inst.CultureBacking:SetHide(true);
    end

    inst.Top:ClearCallback(Mouse.eLClick);
    inst.UnlockedIcon:SetHide( false );
  else
    inst.Top:SetColor( 0xffffffff );
    inst.ImageFrame:SetColor( 0xffffffff );
    inst.ArtLeft:SetColor( 0xffffffff );
    inst.ArtRight:SetColor( 0xffffffff );
    inst.Top:RegisterCallback(Mouse.eLClick, function() OnGovernmentSelected( governmentType ) end );
    inst.UnlockedIcon:SetHide( true );
    inst.Disabled:SetHide( true );
    inst.GovernmentImage:SetHide( false );
  end

  inst.GovernmentName :SetText( Locale.ToUpper( Locale.Lookup(government.Name) ));
  inst.GovernmentImage:SetTexture(GameInfo.Governments[government.Index].GovernmentType);
  local textColor:number = GetGovernmentTextColor(governmentType);
  local bonusName:string = GameInfo.Governments[government.Index].BonusType or "NO_GOVERNMENTBONUS";

  if IsGovernmentSelected(governmentType) then
    -- Selected government
    inst.Selected:SetHide( false );
    inst.PercentImage:SetTexture( PIC_PERCENT_BRIGHT );
    inst.GovernmentBonusBacking:SetColorByName( "GovBonusSelected" );
    inst.GovPercentBonusArea:SetColorByName( "GovBonusSelected" );
  else
    -- Non-selected government
    inst.Selected:SetHide( true );
    inst.PercentImage:SetTexture( PIC_PERCENT_DARK );
    inst.GovernmentBonusBacking:SetColorByName( "GovBonusDark" );
    inst.GovPercentBonusArea:SetColorByName( "GovBonusDark" );
  end
  inst.GovernmentName:SetColor( textColor );

  if m_kBonuses[governmentType] ~= nil then
    inst.GovPercentBonusArea:SetHide( false );
    inst.BonusPercent:SetText( m_kBonuses[governmentType].BonusPercent );
    inst.BonusText:SetText( Locale.ToUpper(Locale.Lookup(government.BonusAccumulatedText)) );

    local governmentBonusText = Locale.Lookup(government.BonusInherentText);
    inst.GovernmentBonus:SetText( Locale.ToUpper(governmentBonusText) );
    if inst.GovernmentBonus:GetSizeY() > MAX_HEIGHT_GOVT_DESC then
      if(TruncateString(inst.GovernmentBonus, MAX_BEFORE_TRUNC_GOVT_BONUS, Locale.ToUpper(governmentBonusText))) then
        inst.GovernmentBonus:SetToolTipString(governmentBonusText);
      end
    end

    inst.GovernmentInfluence:SetText( "[ICON_Envoy]" .. government.BonusInfluenceNumber );
    inst.GovernmentInfluence:SetToolTipString( government.BonusInfluenceText );
    inst.BonusPercent:SetColor( textColor );
    inst.BonusText:SetColor( textColor );
    inst.GovernmentInfluence:SetColor( textColor );
    inst.GovernmentBonus:SetColor( textColor );
    inst.GovPercentBonusArea:SetToolTipString( Locale.Lookup(government.BonusAccumulatedTooltip) );
  else
    if government.BonusAccumulatedText ~= nil and government.BonusAccumulatedText ~= "" then
      inst.GovPercentBonusArea:SetHide( false );
      inst.GovernmentBonus:SetText( Locale.ToUpper(Locale.Lookup(government.BonusAccumulatedText)) );
      inst.GovernmentInfluence:SetText( "[ICON_Envoy]" .. government.BonusInfluenceNumber );
      inst.GovernmentInfluence:SetToolTipString( government.BonusInfluenceText );
      inst.BonusPercent:SetText("0");
      inst.BonusText:SetText( "" );
      inst.BonusPercent:SetColor( textColor );
      inst.BonusText:SetColor( textColor );
      inst.GovernmentInfluence:SetColor( textColor );
      inst.GovernmentBonus:SetColor( textColor );
      inst.GovPercentBonusArea:SetToolTipString( Locale.Lookup(government.BonusAccumulatedTooltip) );
    else
      inst.GovPercentBonusArea:SetHide( true );
    end
  end

  --If we don't have legacy enabled, allow for multiple lines of passives that look like
  --passives, not accumulations
  if not HasCapability("CAPABILITY_GOVERNMENTS_LEGACY_BONUSES") then
    inst.PercentImage:SetHide(true);
    inst.QuillImage:SetHide(true);
    inst.BonusText:SetWrapWidth(265);
    inst.BonusText:SetOffsetX(-5);
  end

  -- If bonus exists for current one.
  if bonusName ~= "NO_GOVERNMENTBONUS" then
    inst.BonusStack:SetHide( false );
  else
    inst.BonusStack:SetHide( true );
  end

  inst.GovernmentContentStack:CalculateSize();

  inst.Top:SetSizeY(inst.GovernmentContentStack:GetSizeY() + 12);
  return totalSlots;
end
-- ===========================================================================
-- Determine selected government by either "really selected" or the one the player
-- has clicked and is about to select for a change.
-- ===========================================================================
function IsGovernmentSelected(governmentType:string)
  if m_governmentChangeType == governmentType then
    return true;
  elseif m_governmentChangeType == "" and g_kCurrentGovernment and g_kCurrentGovernment.Index == g_kGovernments[governmentType].Index then
    return true;
  end
  return false;
end

-- ===========================================================================
function GetGovernmentTextColor(governmentType:string)
  if IsGovernmentSelected(governmentType) then
    return COLOR_GOVT_SELECTED;
  else
    return COLOR_GOVT_UNSELECTED;
  end
end


-- ===========================================================================
function RealizePoliciesPage()
  if not g_isPoliciesTabDirty then
    return;
  end
  g_isPoliciesTabDirty = false;
  RealizeMyGovernmentPage();
end


-- ===========================================================================
--  Whether or not a player can swap policies around for the current government
--  RETURNS:  true/false
-- ===========================================================================
function IsAbleToChangePolicies()
  if m_ePlayer == -1 then
    return false;
  end
  local kPlayer   :table = Players[m_ePlayer];
  local kPlayerCulture:table = kPlayer:GetCulture();
  if (kPlayerCulture:CivicCompletedThisTurn() or kPlayerCulture:GetNumPolicySlotsOpen() > 0) and Game.IsAllowStrategicCommands(m_ePlayer) and kPlayerCulture:PolicyChangeMade() == false then
    return true;
  end
  return false;
end


-- ===========================================================================
--  Whether or not a player can switch to a certain government.
--  RETURNS:  true/false
-- ===========================================================================
function IsAbleToChangeGovernment()
  if m_ePlayer == -1 or not m_isLocalPlayerTurn then
    return false;
  end
  local kPlayer   :table = Players[m_ePlayer];
  local kPlayerCulture:table = kPlayer:GetCulture();

  if kPlayerCulture:CanChangeGovernmentAtAll() and
    not kPlayerCulture:GovernmentChangeMade() and
    Game.IsAllowStrategicCommands(m_ePlayer) and
    (g_kCurrentGovernment == nil or kPlayerCulture:CivicCompletedThisTurn()) then
    return true;
  end
  return false;
end


-- ===========================================================================
--  Make request to change the government
-- ===========================================================================
function OnGovernmentSelected( governmentType:string )
  if IsAbleToChangeGovernment() then
    m_governmentChangeType = governmentType;

    local kPlayer   :table = Players[m_ePlayer];
    local kPlayerCulture:table = kPlayer:GetCulture();
    local eGovernmentType = GameInfo.Governments[governmentType].Index;
    local iAnarchyTurns = kPlayerCulture:GetAnarchyTurns(eGovernmentType);

    local popup:table = PopupDialogInGame:new( "ConfirmGovtChange" );
    if (iAnarchyTurns > 0 and eGovernmentType ~= -1) then
      popup:AddText(Locale.Lookup("LOC_GOVT_CONFIRM_ANARCHY", GameInfo.Governments[governmentType].Name, iAnarchyTurns));
      popup:AddConfirmButton(TXT_GOV_POPUP_YES, OnAcceptAnarchyChange);
    else
      popup:AddText(TXT_GOV_CONFIRM_GOVERNMENT);
      popup:AddConfirmButton(TXT_GOV_POPUP_YES, OnAcceptGovernmentChange);
    end
    popup:AddCancelButton(TXT_GOV_POPUP_NO, OnCancelGovernmentChange);
    popup:Open();

    RealizeGovernmentsPage();
    UI.PlaySound("UI_Policies_Click_Government");
  end
end

-- ===========================================================================
--  UI Callback
-- ===========================================================================
function OnAcceptGovernmentChange()
  UI.PlaySound("UI_Policies_Change_Government");

  local pPlayer   :table = Players[m_ePlayer];
  local pPlayerCulture:table = pPlayer:GetCulture();
  if pPlayerCulture:RequestChangeGovernment( g_kGovernments[m_governmentChangeType].Hash ) then
    g_kCurrentGovernment = g_kGovernments[m_governmentChangeType];
    -- Update tabs and go to policies page.
    RealizeTabs();
    m_tabs.SelectTab( Controls.ButtonPolicies );
  end
  m_governmentChangeType = "";
end

-- ===========================================================================
--  UI Callback
-- ===========================================================================
function OnAcceptAnarchyChange()
  UI.PlaySound("UI_Policies_Change_Government");

  local kPlayer   :table = Players[m_ePlayer];
  local kPlayerCulture:table = kPlayer:GetCulture();
  if kPlayerCulture:RequestChangeGovernment( g_kGovernments[m_governmentChangeType].Hash ) then
    g_kCurrentGovernment = nil;
  end
  m_governmentChangeType = "";
  Close();
end

-- ===========================================================================
--  UI Callback
-- ===========================================================================
function OnCancelGovernmentChange()
  m_governmentChangeType = "";
  RealizeGovernmentsPage();
end

-- ===========================================================================
-- Separated into its own function so we wan modify icons in DLC / Expansions
-- ===========================================================================
function GetPolicyBGTexture(policyType)
  return PICS_SLOT_TYPE_CARD_BGS[GameInfo.Policies[policyType].GovernmentSlotType];
end

-- ===========================================================================
function RealizePoliciesList()
  Controls.PoliciesListStack:DestroyAllChildren();

  if m_isPoliciesChanged then
    Controls.PoliciesListLabel:SetText( Locale.ToUpper(Locale.Lookup("LOC_GOVT_PENDING_POLICIES_LIST")) );
  else
    Controls.PoliciesListLabel:SetText( Locale.ToUpper(Locale.Lookup("LOC_GOVT_POLICIES_LIST")) );
  end

  -- Build cards in the rows (one of the few places rows does not mean DB rows, but visual "rows" of beautiful felt.)
  for nRowIndex,tRow in ipairs(m_ActivePolicyRows) do
    for nRowSlotIndex,tSlotData in ipairs(tRow.SlotArray) do
      if ( tSlotData.GC_PolicyType ~= EMPTY_POLICY_TYPE ) then
        local tPolicy :table = m_kPolicyCatalogData[ tSlotData.GC_PolicyType ]
        local listInstance:table = {};
        ContextPtr:BuildInstanceForControl( "PolicyListItem", listInstance, Controls.PoliciesListStack );
        listInstance.Title:SetText( tPolicy.Name );
        listInstance.Description:SetText( tPolicy.Description );

        listInstance.TypeIcon:SetTexture( GetPolicyBGTexture(tSlotData.GC_PolicyType)..PIC_CARD_SUFFIX_SMALL );
        local height:number = math.max( listInstance.TypeIcon:GetSizeY(), listInstance.Title:GetSizeY() + listInstance.Description:GetSizeY());
        height = height + PADDING_POLICY_LIST_ITEM;
        listInstance.Content:SetSizeY(height);
      end
    end
  end
  local height:number = Controls.PoliciesListStack:GetSizeY() + PADDING_POLICY_LIST_HEADER;
  if height > MAX_HEIGHT_POLICIES_LIST then
    height = MAX_HEIGHT_POLICIES_LIST;
  end

  Controls.PolicyListPanel:SetSizeY(height + PADDING_POLICY_LIST_BOTTOM);
  Controls.PolicyListScroller:SetSizeY(height - PADDING_POLICY_LIST_HEADER);
  Controls.PolicyListScroller:CalculateSize();
end

-- ===========================================================================
function OnTogglePolicyListPanel()
  local isChecked = Controls.PolicyPanelCheckbox:IsSelected();
  Controls.PolicyPanelCheckbox:SetSelected(not isChecked);
  Controls.PolicyListScroller:CalculateSize();
  Controls.PolicyListPanel:SetHide(isChecked);
  Controls.PolicyListScroller:SetHide(isChecked);
end

-- ===========================================================================
--  Set the contents on a card
-- ===========================================================================
function RealizePolicyCard( cardInstance:table, policyType:string )
  local policy :table = m_kPolicyCatalogData[policyType];
  local cardName:string = m_debugShowPolicyIDs and tostring(policy.UniqueID).." " or "";
  cardName = cardName .. policy.Name;
  cardInstance.Title:SetText( cardName );
  -- Offset to below the card title, sans the shadow padding
  local nMinOffsetY = cardInstance.TitleContainer:GetSizeY() - 5;

  -- Remaining space, with a -15 to account for the fact that the card image is alpha bordered by ~5 pixels, and that we want some offset from the card bottom.
  cardInstance.DescriptionContainer:SetSizeY(cardInstance.Background:GetSizeY() - nMinOffsetY - 15);
  cardInstance.DescriptionContainer:SetOffsetY(nMinOffsetY);
  cardInstance.Description:SetText(policy.Description);
  cardInstance.Background:SetTexture(GetPolicyBGTexture(policyType));
  if ( cardInstance.Description:IsTextTruncated() ) then
    cardInstance.Draggable:SetToolTipString(cardName .. "[NEWLINE][NEWLINE]" .. policy.Description);
  else
    cardInstance.Draggable:SetToolTipString(cardName);
  end
end


-- ===========================================================================
function RealizeTabs()

  if not m_tabs then
    m_tabs = CreateTabs( Controls.TabContainer, 42, 34, 0xFF331D05 );
  else
    m_tabs.tabControls = {};
  end

  Controls.ButtonPolicies:SetHide(g_kCurrentGovernment == nil);
  -- CQUI : if MyGovernment is shown in Policy then don't show tab MyGovernment
  if (m_bShowMyGovtInPolicies) then
    Controls.ButtonMyGovernment:SetHide(true);
  else
    Controls.ButtonMyGovernment:SetHide(g_kCurrentGovernment == nil);
  end
  if g_kCurrentGovernment ~= nil then
    m_tabs.AddTab( Controls.ButtonMyGovernment, SwitchTabToMyGovernment );
    m_tabs.AddTab( Controls.ButtonPolicies, SwitchTabToPolicies );
  end
  m_tabs.AddTab( Controls.ButtonGovernments, SwitchTabToGovernments );
  m_tabs.CenterAlignTabs(0);  -- Use negative to create padding as value represents amount to overlap
  m_tabs.AddAnimDeco(Controls.TabAnim, Controls.TabArrow);

  if IsAbleToChangeGovernment() then
    Controls.ButtonGovernments:SetText( Locale.Lookup("LOC_GOVT_CHANGE_GOVERNMENTS") );
  else
    Controls.ButtonGovernments:SetText( Locale.Lookup("LOC_GOVT_VIEW_GOVERNMENTS") );
  end

  if IsAbleToChangePolicies() then
    Controls.ButtonPolicies:SetText( Locale.Lookup("LOC_GOVT_CHANGE_POLICIES") );
  else
    Controls.ButtonPolicies:SetText( Locale.Lookup("LOC_GOVT_VIEW_POLICIES") );
  end
end

-- ===========================================================================
--  Show the appropriate cards based on which page of the policy catalog
--  is displayed and which filter is active.
-- ===========================================================================
function RealizePolicyCatalog()
  m_policyCardIM:ResetInstances();

  local isCivilopediaAvailable:boolean = not IsTutorialRunning();
  local isAbleToChangePolicies:boolean = IsAbleToChangePolicies();

  for _,policyType in pairs(m_kPolicyCatalogOrder) do

    -- Policy unlocked check and Policy inactive check
    if (m_kUnlockedPolicies[policyType] and not IsPolicyTypeActive(policyType) )
    then
      local policy:table= m_kPolicyCatalogData[policyType];

      -- Filter check
      if (m_kPolicyFilterCurrent == nil or
          m_kPolicyFilterCurrent.Func == nil or
          m_kPolicyFilterCurrent.Func(policy) )
      then

        local cardInstance:table = m_policyCardIM:GetInstance();

        cardInstance[KEY_POLICY_TYPE] = policyType;
        cardInstance[KEY_POLICY_SLOT] = -1;
        cardInstance.Draggable:RegisterCallback( Drag.eDown, function(dragStruct) OnStartDragFromCatalog(dragStruct, cardInstance); end );
        cardInstance.Draggable:RegisterCallback( Drag.eDrop, function(dragStruct) OnDropFromCatalog(dragStruct, cardInstance); end );
        cardInstance.Draggable:RegisterCallback( Drag.eDrag, function(dragStruct) OnDragFromCatalog(dragStruct, cardInstance); end );
        cardInstance.Button:RegisterCallback( Mouse.eLDblClick, function() AddToNextAvailRow(cardInstance); end );

        if(isCivilopediaAvailable) then
          cardInstance.Button:RegisterCallback( Mouse.eRClick, function() LuaEvents.OpenCivilopedia(policyType); end);
        end

        cardInstance.NewIcon:SetHide(not m_kNewPoliciesThisTurn[policyType]);
        RealizePolicyCard( cardInstance, policyType );

        -- Reset values that may have been changed by the 'padding' instances
        cardInstance.Content:SetAlpha(1);
        cardInstance.Content:SetSizeX(130);

        -- Give policy cards feedback when hovered, but only if editable
        if isAbleToChangePolicies then
          cardInstance.Button:RegisterMouseEnterCallback(function() cardInstance.Background:SetOffsetY(-5); end);
          cardInstance.Button:RegisterMouseExitCallback(function() cardInstance.Background:SetOffsetY(0); end);
        end
      end
    end
  end

  -- Add 4 blank cards to the end of the stack to add some spacing to the scroll area
  for i=1, 4 do
    local cardInstance:table = m_policyCardIM:GetInstance();
    cardInstance.Content:SetSizeX(PADDING_POLICY_SCROLL_AREA);
    cardInstance.Content:SetAlpha(0);
  end

  Controls.PolicyCatalog:CalculateSize();

  Controls.PolicyScroller:CalculateInternalSize();
  Controls.PolicyScrollbar:SetSizeX(Controls.PolicyScrollbar:GetSizeX() - 10);
end


-- ===========================================================================
--  Take a value and convert it to a slot amount string; where 0 is empty ""
-- ===========================================================================
function ToSlotAmtString( value:number )
  --if value < 1 then return ""; else return tostring(value); end
  if value < 1 then
    return "[ICON_CHECKMARK]";
  else
    return tostring(value);
  end
end

-- ===========================================================================
function ToSlotAmtTotalTooltipString( value:number, slotName:string )
  if value < 1 then
    return Locale.Lookup("LOC_GOVT_POLICIES_NO_TOTAL_PLACED", Locale.Lookup(slotName) );
  else
    return Locale.Lookup("LOC_GOVT_POLICIES_TOTAL_PLACED", value, Locale.Lookup(slotName) );
  end
end

-- ===========================================================================
function ToSlotAmtRemainingTooltipString( value:number, slotName:string )
  if value < 1 then
    return Locale.Lookup("LOC_GOVT_POLICIES_NO_REMAINING_PLACED", Locale.Lookup(slotName) );
  else
    return Locale.Lookup("LOC_GOVT_POLICIES_REMAINING_PLACED", value, Locale.Lookup(slotName) );
  end
end


-- ===========================================================================
--
-- ===========================================================================
function BlockRowsUnableToAccept( rowSlotType:string )
  -- LUA cascade boolean logic to turn slots a darker color if the dragged type
  -- doesn't support the row or if the row doesn't have any more room in it.

  -- Undo darkening if no type is given.
  if ( strSlotType == nil ) then
    Controls.MilitaryBlocker:SetHide(true);
    Controls.DiplomaticBlocker:SetHide(true);
    Controls.EconomicBlocker:SetHide(true);
    Controls.WildcardBlocker:SetHide(true);
    return;
  end
  
  Controls.MilitaryBlocker:SetHide(IsSlotTypeLegalInRow( ROW_INDEX.MILITARY, strSlotType ));
  Controls.DiplomaticBlocker:SetHide(IsSlotTypeLegalInRow( ROW_INDEX.DIPLOMAT, strSlotType ));
  Controls.EconomicBlocker:SetHide(IsSlotTypeLegalInRow( ROW_INDEX.ECONOMIC, strSlotType ));
  Controls.WildcardBlocker:SetHide(IsSlotTypeLegalInRow( ROW_INDEX.WILDCARD, strSlotType ));
end

function ChangeActiveCardMouseover( nPrevSlot:number, nNextSlot:number )
  -- Don't highlight cards if they're shuffling around to their next location.
  if Controls.RowAnim:GetProgress() < 1 then return; end
  -- mouseover highlight is:
  --		moving the entire instance to the 'Top' stack of whatever row it's in
  --		Lifting the card contents slightly above its companions
  if ( nPrevSlot ) then
    local tPrevInst :table = m_ActiveCardInstanceArray[nPrevSlot+1];
    local tContent :table = tPrevInst[KEY_DRAG_TARGET_CONTROL];
    local strNewParentID:string = tContent:GetParent():GetID():gsub("Top", "");
    local tNewParentCtrl:table = Controls[strNewParentID];
    tPrevInst[KEY_LIFTABLE_CONTROL]:SetOffsetY( 0 );
    if tNewParentCtrl then
       tContent:ChangeParent(tNewParentCtrl);
      -- Rebuild the row we just put this into to prevent overlap sadness.
      EnsureRowContentsOverlapProperly( m_ActivePoliciesBySlot[nPrevSlot+1].UI_RowIndex, tNewParentCtrl );
    else
      assert("Failed to change parent of " .. tContent:GetID() .. " to " .. strNewParentID);
    end
  end
  if ( nNextSlot ) then
    local tNextInst :table = m_ActiveCardInstanceArray[nNextSlot+1];
    local tContent :table = tNextInst[KEY_DRAG_TARGET_CONTROL];
    local strNewParentID:string = "Top" .. tContent:GetParent():GetID();
    local tNewParentCtrl:table = Controls[strNewParentID];
    tNextInst[KEY_LIFTABLE_CONTROL]:SetOffsetY( -5 );
    if tNewParentCtrl then
       tContent:ChangeParent(tNewParentCtrl);
    else
      assert("Failed to change parent of " .. tContent:GetID() .. " to " .. strNewParentID);
    end
  end
end
function PushActiveCardMouseover( tTargetInstance:table )
  local nPrevSlot :number = m_MouseoverStack[#m_MouseoverStack];
  local nThisSlot :number = tTargetInstance[KEY_POLICY_SLOT];
  if ( nPrevSlot ) then
    table.insert( m_MouseoverStack, 1, nThisSlot );
  else
    table.insert( m_MouseoverStack, nThisSlot );
    ChangeActiveCardMouseover( nPrevSlot, nThisSlot );
  end
end
function PopActiveCardMouseover( tTargetInstance:table )
  local nThisSlot :number = tTargetInstance[KEY_POLICY_SLOT];
  local nCurrSlot :number = m_MouseoverStack[#m_MouseoverStack];

  if ( nThisSlot == m_MouseoverStack[#m_MouseoverStack] ) then -- This is at the top of the stack!
    table.remove( m_MouseoverStack );
    ChangeActiveCardMouseover( nThisSlot, m_MouseoverStack[#m_MouseoverStack] );

  else
    -- Ya'll just... somewhere in the list. Not relevant to top. Find and remove, preserving order.
    for idx,nSlot in ipairs(m_MouseoverStack) do
      if ( nThisSlot == nSlot ) then
        table.remove( m_MouseoverStack, idx );
        break;
      end
    end
  end
end

function HighlightActiveCard_DropTarget( tTargetInstance:table )
  local nTargetSlot :number = tTargetInstance and tTargetInstance[KEY_POLICY_SLOT] or -1;
  if ( nTargetSlot ~= m_PrevDropTargetSlot ) then
    if ( m_PrevDropTargetSlot ~= -1 ) then
      local tInst :table = m_ActiveCardInstanceArray[m_PrevDropTargetSlot+1];
      tInst.DropTargetGlow:SetShow( false );
      PopActiveCardMouseover( tInst );
    end
    if ( tTargetInstance ) then
      tTargetInstance.DropTargetGlow:SetShow( true );
      PushActiveCardMouseover( tTargetInstance );
    end
    m_PrevDropTargetSlot = nTargetSlot;
  end
end

function RealizeActivePoliciesRows()

  -- This function uses the local player further down, so validate it now.
  if (Game.GetLocalPlayer() == -1) then
    return;
  end

  -- Reset rows
  Controls.MilitaryBlocker:SetHide(true);
  Controls.DiplomaticBlocker:SetHide(true);
  Controls.EconomicBlocker:SetHide(true);
  Controls.WildcardBlocker:SetHide(true);

  m_MouseoverStack = {}; -- Clear the hover stack, we're about to reset all the controls anyway.

  -- Destroy any cards currently sitting in the rows
  -- WARNING: Call this while a snap-back is occuring will lock.
  Controls.StackMilitary:DestroyAllChildren();
  Controls.TopStackMilitary:DestroyAllChildren();
  Controls.StackEconomic:DestroyAllChildren();
  Controls.TopStackEconomic:DestroyAllChildren();
  Controls.StackDiplomatic:DestroyAllChildren();
  Controls.TopStackDiplomatic:DestroyAllChildren();
  Controls.StackWildcard:DestroyAllChildren();
  Controls.TopStackWildcard:DestroyAllChildren();

  local tStackControls :table = {}; -- Simple map to go from ROW_INDEX to the appropriate stack (Do not make global, Control.* makes no guarantees)
  tStackControls[ROW_INDEX.MILITARY] = Controls.StackMilitary;
  tStackControls[ROW_INDEX.ECONOMIC] = Controls.StackEconomic;
  tStackControls[ROW_INDEX.DIPLOMAT] = Controls.StackDiplomatic;
  tStackControls[ROW_INDEX.WILDCARD] = Controls.StackWildcard;

  m_ActiveCardInstanceArray = {};	-- Empty policies; will be rebuilt below.
  for nRowIndex,tRow in ipairs(m_ActivePolicyRows) do
    local stackControl:table = tStackControls[nRowIndex];
    for nRowSlotIndex,tSlotData in ipairs(tRow.SlotArray) do
      local cardInst:table = {};
      cardInst[KEY_POLICY_SLOT]	= tSlotData.GC_SlotIndex;
      cardInst[KEY_POLICY_TYPE]	= tSlotData.GC_PolicyType;
      cardInst[KEY_ROW_ID]		= nRowIndex;

      if ( tSlotData.GC_PolicyType ~= EMPTY_POLICY_TYPE ) then
         -- Policy is in this slot, show policy card
        ContextPtr:BuildInstanceForControl( "PolicyCard", cardInst, stackControl );
        RealizePolicyCard( cardInst, tSlotData.GC_PolicyType );
        cardInst.CardContainer:SetHide(true);
        cardInst.Draggable:RegisterCallback( Drag.eDown, function(dragStruct) OnStartDragFromRow(dragStruct, cardInst ); end );
        cardInst.Draggable:RegisterCallback( Drag.eDrop, function(dragStruct) OnDropFromRow(dragStruct, cardInst ); end );
        cardInst.Button:RegisterMouseEnterCallback( function() PushActiveCardMouseover( cardInst ); end);
        cardInst.Button:RegisterMouseExitCallback( function() PopActiveCardMouseover( cardInst ); end);
        
        
        local fnRemoveCard = function( )
            RemoveActivePolicyAtSlotIndex( tSlotData.GC_SlotIndex );
            RealizePolicyCatalog();
            RealizeActivePoliciesRows();
          end
        cardInst.Button:RegisterCallback(Mouse.eLDblClick, fnRemoveCard ); -- Double click and right click removes cards
        cardInst.Button:RegisterCallback(Mouse.eRClick, fnRemoveCard );
        cardInst[KEY_DRAG_TARGET_CONTROL]	= cardInst.Content;
        cardInst[KEY_LIFTABLE_CONTROL]		= cardInst.Background; -- Really anything below the drag target is fine
      else
        -- No policy is in this slot, show empty card
        ContextPtr:BuildInstanceForControl("EmptyCard", cardInst, stackControl);
        cardInst.DragPolicyLabel:SetHide(m_tabs.selectedControl == Controls.ButtonMyGovernment);
        cardInst.TypeIcon:SetTexture(IMG_POLICYCARD_BY_ROWIDX[nRowIndex] .. "_Empty");
        cardInst[KEY_DRAG_TARGET_CONTROL]	= cardInst.Content;
        cardInst[KEY_LIFTABLE_CONTROL]		= cardInst.LiftableContainer;
      end
      m_ActiveCardInstanceArray[tSlotData.GC_SlotIndex+1] = cardInst;
    end
  end

  RealizeActivePolicyRowSize();

  -- Update row decorations (counters, tooltips, labels)
  local tRowCtrlPrefix :table = {};
  tRowCtrlPrefix[ROW_INDEX.MILITARY] = "Military";
  tRowCtrlPrefix[ROW_INDEX.ECONOMIC] = "Economic";
  tRowCtrlPrefix[ROW_INDEX.DIPLOMAT] = "Diplomacy";
  tRowCtrlPrefix[ROW_INDEX.WILDCARD] = "Wildcard";

  local tRowTooltip :table = {};
  tRowTooltip[ROW_INDEX.MILITARY] = "LOC_GOVT_POLICY_TYPE_MILITARY";
  tRowTooltip[ROW_INDEX.ECONOMIC] = "LOC_GOVT_POLICY_TYPE_ECONOMIC";
  tRowTooltip[ROW_INDEX.DIPLOMAT] = "LOC_GOVT_POLICY_TYPE_DIPLOMATIC";
  tRowTooltip[ROW_INDEX.WILDCARD] = "LOC_GOVT_POLICY_TYPE_WILDCARD";

  -- This is used much later in the function
  local bAnySlotsFree :boolean = false;

  for nRowIndex,tRow in ipairs(m_ActivePolicyRows) do
    local nSlots = #m_ActivePolicyRows[nRowIndex].SlotArray;
    local hasSlots = nSlots > 0;
    local nFreeSlots = GetFreeSlotCountForRow(nRowIndex);
    local strTooltip :string = tRowTooltip[nRowIndex];

    bAnySlotsFree = bAnySlotsFree or nFreeSlots > 0;

    local strCtrlPrefix = tRowCtrlPrefix[nRowIndex];
    local ctrlLabelRight	:table = Controls[strCtrlPrefix .. "LabelRight"];
    local ctrlLabelLeft		:table = Controls[strCtrlPrefix .. "LabelLeft"];
    local ctrlCounter		:table = Controls[strCtrlPrefix .. "Counter"];
    local ctrlIconRing		:table = Controls[strCtrlPrefix .. "IconRing"];
    local ctrlIconLeft		:table = Controls[strCtrlPrefix .. "IconLeft"];

    ctrlLabelLeft:SetText(ToSlotAmtString(nSlots));
    ctrlLabelLeft:SetShow(hasSlots);
    ctrlLabelRight:SetShow(hasSlots);
    ctrlIconRing:SetShow(hasSlots);
    ctrlCounter:SetColorByName(hasSlots and "Black" or "Clear"); -- Ternary. (hasSlots ? "Black" : "Clear")
    
    ctrlLabelRight:SetText(ToSlotAmtString(nFreeSlots));
    ctrlLabelRight:SetToolTipString(ToSlotAmtRemainingTooltipString(nFreeSlots, strTooltip));
    ctrlIconLeft:SetToolTipString(ToSlotAmtTotalTooltipString(nSlots, strTooltip));
  end
  
  -- Had to set these manually because Controls.DiplomaticEmpty is off doing its own thing wrt naming
  Controls.MilitaryEmpty:SetHide(#m_ActivePolicyRows[ROW_INDEX.MILITARY].SlotArray > 0);
  Controls.EconomicEmpty:SetHide(#m_ActivePolicyRows[ROW_INDEX.ECONOMIC].SlotArray > 0);
  Controls.DiplomaticEmpty:SetHide(#m_ActivePolicyRows[ROW_INDEX.DIPLOMAT].SlotArray > 0); -- BRUH. bruh. cmon.
  Controls.WildcardEmpty:SetHide(#m_ActivePolicyRows[ROW_INDEX.WILDCARD].SlotArray > 0);

  local playerCulture:table = Players[Game.GetLocalPlayer()]:GetCulture();
  local playerTreasury:table = Players[Game.GetLocalPlayer()]:GetTreasury();
  local playerReligion:table = Players[Game.GetLocalPlayer()]:GetReligion();
  local bPoliciesChanged = playerCulture:PolicyChangeMade();
  local iPolicyUnlockCost = playerCulture:GetCostToUnlockPolicies();
  local iGoldBalance = playerTreasury:GetGoldBalance();
  local iFaithBalance = playerReligion:GetFaithBalance();
  local bUnlockByFaith = (GlobalParameters.GOVERNMENT_UNLOCK_WITH_FAITH ~= 0);

  -- Update states for Unlock and Confirm buttons at bottom of screen
  if (bPoliciesChanged == true) then
    Controls.ConfirmPolicies:SetHide(true);
    Controls.UnlockPolicies:SetHide(true);
  elseif (iPolicyUnlockCost == 0) then
    Controls.ConfirmPolicies:SetHide(false);
    Controls.UnlockPolicies:SetHide(true);

    if(not m_isPoliciesChanged or bAnySlotsFree) then
      Controls.ConfirmPolicies:SetDisabled(true);
      Controls.ConfirmPolicies:SetText(TXT_GOV_ASSIGN_POLICIES);
    else
      Controls.ConfirmPolicies:SetDisabled(false);
      Controls.ConfirmPolicies:SetText(TXT_GOV_CONFIRM_POLICIES);
    end
  elseif (not bUnlockByFaith and iGoldBalance < iPolicyUnlockCost) then
    Controls.ConfirmPolicies:SetHide(true);
    Controls.UnlockPolicies:SetHide(false);
    Controls.UnlockPolicies:SetText(Locale.Lookup("LOC_GOVT_NEED_GOLD", iPolicyUnlockCost));
    Controls.UnlockPolicies:SetDisabled(true);
  elseif (bUnlockByFaith and iFaithBalance < iPolicyUnlockCost) then
    Controls.ConfirmPolicies:SetHide(true);
    Controls.UnlockPolicies:SetHide(false);
    Controls.UnlockPolicies:SetText(Locale.Lookup("LOC_GOVT_NEED_FAITH", iPolicyUnlockCost));
    Controls.UnlockPolicies:SetDisabled(true);
  else
    Controls.ConfirmPolicies:SetHide(true);
    Controls.UnlockPolicies:SetHide(false);
    if (bUnlockByFaith) then
      Controls.UnlockPolicies:SetText(Locale.Lookup("LOC_GOVT_UNLOCK_FAITH", iPolicyUnlockCost));
    else
      Controls.UnlockPolicies:SetText(Locale.Lookup("LOC_GOVT_UNLOCK_GOLD", iPolicyUnlockCost));
    end
    Controls.UnlockPolicies:SetDisabled(false);
  end
end

function RealizeActivePolicyRowSize()
  --EnsureRowContentsOverlapProperly(ROW_INDEX.MILITARY, Controls.StackMilitary);
  EnsureRowContentsFit(ROW_INDEX.MILITARY, Controls.StackMilitary);
  --EnsureRowContentsOverlapProperly(ROW_INDEX.ECONOMIC, Controls.StackEconomic);
  EnsureRowContentsFit(ROW_INDEX.ECONOMIC, Controls.StackEconomic);
  --EnsureRowContentsOverlapProperly(ROW_INDEX.DIPLOMAT, Controls.StackDiplomatic);
  EnsureRowContentsFit(ROW_INDEX.DIPLOMAT, Controls.StackDiplomatic);
  --EnsureRowContentsOverlapProperly(ROW_INDEX.WILDCARD, Controls.StackWildcard);
  EnsureRowContentsFit(ROW_INDEX.WILDCARD, Controls.StackWildcard);
end

function EnsureRowContentsFit( nRowIndex:number, tStack:table )
  local tSlotArray :table = m_ActivePolicyRows[nRowIndex].SlotArray;
  local nSlots :number = #tSlotArray;
  if ( nSlots == 0 ) then
    return; -- that was easy
  end

  local width:number = tStack:GetSizeX();
  local itemPadding:number = (nSlots - 1) * PADDING_POLICY_ROW_ITEM;
  local totalSize:number = (SIZE_POLICY_CARD_X * nSlots) + itemPadding;
  local nextX:number = (width / 2) - (totalSize / 2);
  local step:number = SIZE_POLICY_CARD_X + PADDING_POLICY_ROW_ITEM;
  
  -- Make items overlap if they don't fit in the stack
  if(totalSize > width) then
    nextX = 0;
    local itemOverlap:number = (totalSize - itemPadding - width) / (nSlots - 1);
    step = SIZE_POLICY_CARD_X - itemOverlap;
  end

  for _,tSlotData in ipairs(tSlotArray) do
    local inst :table = m_ActiveCardInstanceArray[tSlotData.GC_SlotIndex+1];
    inst.Content:SetOffsetX( nextX );
    nextX = nextX + step;
  end
end
function EnsureRowContentsOverlapProperly( nRowIndex:number, tStack:table )
  for _,tSlotData in ipairs(m_ActivePolicyRows[nRowIndex].SlotArray) do
    local inst :table = m_ActiveCardInstanceArray[tSlotData.GC_SlotIndex+1];
    inst.Content:ChangeParent( inst.Content:GetParent() );
  end
end

-- ===========================================================================
--  Main close function all exit points should call.
-- ===========================================================================
function Close()

  if ContextPtr:IsHidden() then return; end

  if Controls.ConfirmPolicies:IsVisible() and Controls.ConfirmPolicies:IsEnabled() then
    -- Policies confirmation button is enabled (and showing); warn player changes are not saved!
    local popup:table = PopupDialogInGame:new( "WarnUnsavedChanges" );
    popup:ShowYesNoDialog( TXT_GOV_POPUP_PROMPT_POLICIES_CLOSE,
      function() Controls.ConfirmPolicies:SetDisabled(true); Close() end ); -- no-op on cancel
  else
    -- Actual close
    if not ContextPtr:IsHidden() then
      UI.PlaySound("UI_Screen_Close");
    end
    UIManager:DequeuePopup(ContextPtr);
    m_governmentChangeType  = "";
    m_isPoliciesChanged   = false;
    LuaEvents.Government_CloseGovernment();
  end
end

-- ===========================================================================
--  Control close via click
-- ===========================================================================
function OnClose()
  Close();
end

-- ===========================================================================
--  LUA Event
--  Close from launchbar control
-- ===========================================================================
function OnCloseFromLaunchBar()
  Close();
end

-- ===========================================================================
--  Pulse an animation twice in a control
-- ===========================================================================
function PulseAnim(control)
  control:SetToBeginning();
  control:RegisterEndCallback(function()
    control:SetToBeginning();
    control:RegisterEndCallback(function() end);
    control:Play();
  end);
  control:Play();
end

-- ===========================================================================
--  UI Button Callback
--  Solidify the policies which are slotted.
-- ===========================================================================
function OnConfirmPolicies()

  if Controls.ConfirmPolicies:IsDisabled() then
    UI.PlaySound("Play_Mouse_Click_Negative");
    PulseAnim(Controls.MilitaryIconRingAnim);
    PulseAnim(Controls.EconomicIconRingAnim);
    PulseAnim(Controls.DiplomacyIconRingAnim);
    PulseAnim(Controls.WildcardIconRingAnim);
    return;
  end

  function OnConfirmPolicies_Yes()
    UI.PlaySound("Confirm_Civic");

    local kPlayer   :table = Players[Game.GetLocalPlayer()];
    local pPlayerCulture:table = kPlayer:GetCulture();

    -- Preform in two passes, with removals done first, otherwise "swapping"
    -- may fail between rows becaues the engine will think a policy is still
    -- active in its slot.

    local clearList :table = {};   -- table of slots to clear
    local addList :table = {};     -- table of policies to add, keyed by the slot index

    -- Build the lists
    for nSlotIndexPlusOne,tSlotData in pairs( m_ActivePoliciesBySlot ) do
      table.insert( clearList, nSlotIndexPlusOne-1 );
      addList[nSlotIndexPlusOne-1] = m_kPolicyCatalogData[tSlotData.GC_PolicyType].PolicyHash;
    end

    pPlayerCulture:RequestPolicyChanges(clearList, addList);

    m_isPoliciesChanged = false;
    Controls.ConfirmPolicies:SetDisabled( true );
    Close();
  end

  local popup:table = PopupDialogInGame:new( "ConfirmPolicies" );
  popup:ShowYesNoDialog(TXT_GOV_POPUP_PROMPT_POLICIES_CONFIRM, OnConfirmPolicies_Yes);
end

-- ===========================================================================
--  UI Button Callback
--  Pay gold to unlock the ability to change policies
-- ===========================================================================
function OnUnlockPolicies()

  local tParameters = {};
  UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.UNLOCK_POLICIES, tParameters);
  RefreshAllData();
  Controls.ButtonPolicies:SetText( Locale.Lookup("LOC_GOVT_CHANGE_POLICIES") );
  UI.PlaySound("UI_Unlock_Government");
end

-- ===========================================================================
--  UI Button Callback
--  Pay gold to unlock the ability to change governments
-- ===========================================================================
function OnUnlockGovernments()

  local tParameters = {};
  UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.UNLOCK_POLICIES, tParameters);
  RefreshAllData();
  Controls.ButtonPolicies:SetText( Locale.Lookup("LOC_GOVT_CHANGE_POLICIES") );
  UI.PlaySound("UI_Unlock_Government");
end

-- ===========================================================================
--  LUA Event
--  Called to first open the page.
-- ===========================================================================
function OnOpenGovernmentScreenMyGovernment()
  RefreshAllData();
  -- Open governments screen by default if player has to select a government
  if not g_kCurrentGovernment then
    OnOpenGovernmentScreen( SCREEN_ENUMS.GOVERNMENTS );
  else
    -- CQUI : if MyGovernment is shown in Policy then open Policies
    if (m_bShowMyGovtInPolicies) then
      OnOpenGovernmentScreen( SCREEN_ENUMS.POLICIES );
    else
      OnOpenGovernmentScreen( SCREEN_ENUMS.MY_GOVERNMENT );
    end
  end
end

-- ===========================================================================
--  LUA Event
--  Called to first open the page.
-- ===========================================================================
function OnOpenGovernmentScreenGovernments()
  RefreshAllData();
  OnOpenGovernmentScreen( SCREEN_ENUMS.GOVERNMENTS );
end

-- ===========================================================================
--  LUA Event
--  Called to first open the page.
-- ===========================================================================
function OnOpenGovernmentScreenPolicies()
  RefreshAllData();
  if not g_kCurrentGovernment then
    OnOpenGovernmentScreen( SCREEN_ENUMS.GOVERNMENTS );
  else
    OnOpenGovernmentScreen( SCREEN_ENUMS.POLICIES );
  end
end


-- ===========================================================================
--  LUA Event / DEPRECATED To be called directly (use an open that references the specific screen to see)
--  Called to first open the page.
-- ===========================================================================
function OnOpenGovernmentScreen( screenEnum:number )
  if m_ePlayer ~= -1 then

    UI.PlaySound("UI_Screen_Open");

    -- Cache the civics data
    local localPlayer         = Players[Game.GetLocalPlayer()];
    local playerCivics          = localPlayer:GetCulture();
    local currentCivicID    :number = playerCivics:GetProgressingCivic();
    if(currentCivicID >= 0) then
      m_currentCivicType = GameInfo.Civics[currentCivicID].CivicType;
      m_civicProgress = playerCivics:GetCulturalProgress(currentCivicID);
      m_civicCost   = playerCivics:GetCultureCost(currentCivicID);
    else
      m_currentCivicType = nil;
    end

    -- From Civ6_styles: FullScreenVignetteConsumer
    Controls.ScreenAnimIn:SetToBeginning();
    Controls.ScreenAnimIn:Play();

    -- If not explicity screenEnumeration is passed in, use smart logic.
    if screenEnum == nil then
      if IsAbleToChangePolicies() then
        if table.count(m_kUnlockedGovernments) > 0 then
          screenEnum = SCREEN_ENUMS.GOVERNMENTS;
        else
          screenEnum = SCREEN_ENUMS.POLICIES;
        end
      else
        -- CQUI : if MyGovernment is shown in Policy then open Policies
        if (m_bShowMyGovtInPolicies) then
          screenEnum = SCREEN_ENUMS.SCREEN_ENUMS.POLICIES;
        else
          screenEnum = SCREEN_ENUMS.MY_GOVERNMENT;
        end
      end
    end

    if screenEnum == SCREEN_ENUMS.MY_GOVERNMENT then
      m_tabs.SelectTab( Controls.ButtonMyGovernment );
    elseif screenEnum == SCREEN_ENUMS.GOVERNMENTS   then
      m_tabs.SelectTab( Controls.ButtonGovernments );
    else
      m_tabs.SelectTab( Controls.ButtonPolicies );
    end

    -- Queue the screen as a popup, but we want it to render at a desired location in the hierarchy, not on top of everything.
    local kParameters = {};
    kParameters.RenderAtCurrentParent = true;
    kParameters.InputAtCurrentParent = true;
    kParameters.AlwaysVisibleInQueue = true;
    UIManager:QueuePopup(ContextPtr, PopupPriority.Low, kParameters);
    
    LuaEvents.Government_OpenGovernment();
  end
end

function SwitchTab( tabFrom, tabTo, bForce )
  local isToPolicies = (tabTo == Controls.ButtonPolicies);

  local isEditOn:boolean = IsAbleToChangePolicies();
  Controls.PolicyInputShield:SetDisabled( isEditOn and isToPolicies ); -- No poking active rows when not in the policies tab!
  Controls.CatalogInputShield:SetHide( isEditOn );
  -- For visible EmptyCards, add the drag instruction text!
  for _,tCardInst in ipairs(m_ActiveCardInstanceArray) do
    if ( tCardInst.DragPolicyLabel ~= nil ) then
      tCardInst.DragPolicyLabel:SetShow(isToPolicies and isEditOn);
    end
  end

  if ( tabFrom == tabTo and (bForce == nil or not bForce) ) then
    return; -- No change, we don't care.
  end
  
  -- If this "switch" is actually someone straight opening the window, jump directly to what they want
  local isDirectOpen:boolean = ContextPtr:IsHidden()

  -- Let's get some musical accompaniment, but only as long as the window's already up
  if ( not isDirectOpen ) then
    UI.PlaySound("UI_Page_Turn");
  end

  local isToMyGovt = (tabTo == Controls.ButtonMyGovernment);
  local isToGovts = (tabTo == Controls.ButtonGovernments);
  local isFromGovts = (tabFrom == Controls.ButtonGovernments);
  
  -- Thingy that appears, but only on govts tab
  Controls.PolicyPanelGrid:SetHide( not isToGovts );
  
  -- Animation: Make sure 'selected' overlay on the correct tab button is visible and fade it in.
  Controls.SelectMyGovernment:SetHide( not isToMyGovt );
  Controls.SelectPolicies:SetHide( not isToPolicies );
  Controls.SelectGovernments:SetHide( not isToGovts );
  if ( isToMyGovt ) then
    Controls.SelectMyGovernment:SetToBeginning();
    Controls.SelectMyGovernment:Play();
  end
  if ( isToPolicies ) then
    Controls.SelectPolicies:SetToBeginning();
    Controls.SelectPolicies:Play();
  end
  if ( isToGovts ) then
    Controls.SelectGovernments:SetToBeginning();
    Controls.SelectGovernments:Play();
  end
  
  -- Animation: Alpha blend between policystuff and govts
  if ( isFromGovts or isToGovts ) then
    -- Fade for govts. isToGovts wants to reveal this. Reverse-mode is hiding. So therefore...
    if ( isToGovts == Controls.GovernmentTree:IsReversing() ) then
      Controls.GovernmentTree:Reverse();
    end

    -- Fade for policystuff. isToGovts wants to hide this. Reverse-mode is hiding. So therefore...
    if ( isToGovts ~= not Controls.AlphaAnim:IsReversing() ) then -- "CAN'T TOUCH XML" note: AlphaAnim goes from 1 to 0, thus the "not" here.
      Controls.AlphaAnim:Reverse();
    end

    -- Play away! These do nothing if they're already where they need to be.
    Controls.GovernmentTree:Play();
    Controls.AlphaAnim:Play();
    
    -- Also, uh, make sure we can see what's going on.
    -- If we're in this section, it's guaranteed that we're going between policystuff and govts.
    Controls.GovernmentTree:SetHide(false);
    Controls.AlphaAnim:SetHide(false);
    
    -- Short circuit for timely presentation!
    if ( isDirectOpen ) then
      Controls.GovernmentTree:SetProgress(1);
      Controls.AlphaAnim:SetProgress(1);
    end
  end

  -- Animation: Slide policystuff around to show appropriate things
  if ( isToMyGovt or isToPolicies ) then
    Controls.AlphaAnim:SetHide(false); -- This should definitely be visible.
    Controls.AlphaAnim:Stop(); -- And probably not animating
    Controls.AlphaAnim:SetToBeginning(); -- "CAN'T TOUCH XML" note: AlphaAnim goes from 1 to 0, thus begins visible (unlike GovernmentTree)
    
    -- Slide to catalog. isToMyGovt wants no catalog. Reversing shows catalog. So therefore...
    if ( isToMyGovt == Controls.RowAnim:IsReversing() ) then
      Controls.RowAnim:Reverse();
    end
    Controls.RowAnim:Play();

    -- Short circuit for timely presentation!
    if ( isDirectOpen ) then
      Controls.RowAnim:SetProgress(1);
    end
  end
  
  Controls.MilitaryCounter:SetHide( not isToPolicies );
  Controls.EconomicCounter:SetHide( not isToPolicies );
  Controls.DiplomacyCounter:SetHide( not isToPolicies );
  Controls.WildcardCounter:SetHide( not isToPolicies );
  Controls.CategoryIconsLeft:SetHide( false );
end

-- ===========================================================================
--	Switch to My Government "tab" area
-- ===========================================================================
function SwitchTabToMyGovernment()
  SwitchTab( m_tabs.prevSelectedControl, Controls.ButtonMyGovernment );

  RealizeMyGovernmentPage();
end
-- ===========================================================================
--	Switch to policies "tab" area
-- ===========================================================================
function SwitchTabToPolicies()
  SwitchTab( m_tabs.prevSelectedControl, Controls.ButtonPolicies );

  RealizePoliciesPage();

  LuaEvents.GovernmentScreen_PolicyTabOpen();
end
-- ===========================================================================
--	Switch to goverment "tab" area
-- ===========================================================================
function SwitchTabToGovernments()
  SwitchTab( m_tabs.prevSelectedControl, Controls.ButtonGovernments );
  
  RealizeGovernmentsPage();
end

-- ===========================================================================
--
-- ===========================================================================
function RefreshAllData()
  PopulateLivePlayerData( m_ePlayer );
  RealizeTabs();

  -- From ModalScreen_PlayerYieldsHelper
  RefreshYields();

  g_isMyGovtTabDirty = true;
  g_isGovtTabDirty = true;
  g_isPoliciesTabDirty = true;
end


-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnGovernmentChanged( playerID:number )
  if playerID == m_ePlayer and m_ePlayer ~= -1 then
    RefreshAllData();
    if ContextPtr:IsVisible() then -- Player is seeing things, we need to update immediately
      RealizeMyGovernmentPage();
      RealizeGovernmentsPage();
      RealizePoliciesPage();
    end
    if g_kCurrentGovernment == nil and ContextPtr:IsVisible() then
      Close();
    end
  end
end


-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnGovernmentPolicyChanged( playerID:number )
  if ContextPtr:IsVisible() and playerID == m_ePlayer then
    RefreshAllData();
  end
end


-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnLocalPlayerTurnBegin()
  m_isLocalPlayerTurn = true;
  local ePlayer:number = Game.GetLocalPlayer();
  if ePlayer ~= m_ePlayer and m_ePlayer ~= -1 then
    SaveLivePlayerData( m_ePlayer );
  end

  m_ePlayer = ePlayer;
  if m_ePlayer ~= -1 then
    RefreshAllData();
  end
end

function OnLocalPlayerTurnEnd()
  m_isLocalPlayerTurn = false;

  if(GameConfiguration.IsHotseat()) then
    Close();
  end
end

-- ===========================================================================
function OnCivicsUnlocked()
  if (Controls.SelectPolicies:IsHidden()) then
    m_tabs.SelectTab( Controls.ButtonGovernments );
  else
    m_tabs.SelectTab( Controls.ButtonPolicies );
  end
end

-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnPhaseBegin()
  local ePlayer:number = Game.GetLocalPlayer();
  if ePlayer ~= m_ePlayer and m_ePlayer ~= -1 then
    SaveLivePlayerData( m_ePlayer );
  end

  m_ePlayer = ePlayer;
  if m_ePlayer ~= -1 then
    RefreshAllData();
  end
end


-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string)
  if type == SystemUpdateUI.ScreenResize then
    Resize();
    SwitchTab( m_tabs.selectedControl, m_tabs.selectedControl, true );
  end
end


-- ===========================================================================
--
-- ===========================================================================
function GetCurrentDragTargetRowIndex( tDraggedControl:table, strPolicyType:string )
  local tViableDragTargets :table = {};
  if ( IsPolicyTypeLegalInRow( ROW_INDEX.MILITARY, strPolicyType ) ) then
    table.insert( tViableDragTargets, Controls.RowMilitary );
    tViableDragTargets[Controls.RowMilitary] = ROW_INDEX.MILITARY;
  end
  if ( IsPolicyTypeLegalInRow( ROW_INDEX.ECONOMIC, strPolicyType ) ) then
    table.insert( tViableDragTargets, Controls.RowEconomic );
    tViableDragTargets[Controls.RowEconomic] = ROW_INDEX.ECONOMIC;
  end
  if ( IsPolicyTypeLegalInRow( ROW_INDEX.DIPLOMAT, strPolicyType ) ) then
    table.insert( tViableDragTargets, Controls.RowDiplomatic );
    tViableDragTargets[Controls.RowDiplomatic] = ROW_INDEX.DIPLOMAT;
  end
  if ( IsPolicyTypeLegalInRow( ROW_INDEX.WILDCARD, strPolicyType ) ) then
    table.insert( tViableDragTargets, Controls.RowWildcard );
    tViableDragTargets[Controls.RowWildcard] = ROW_INDEX.WILDCARD;
  end

  local tBest :table = DragSupport_GetBestOverlappingControl( tDraggedControl, tViableDragTargets );
  return tBest ~= nil and tViableDragTargets[tBest] or -1;
end
function IsDragOverRow( tDraggedControl:table )
  local tTargets :table = {};
  table.insert( tTargets, Controls.RowMilitary );
  table.insert( tTargets, Controls.RowEconomic );
  table.insert( tTargets, Controls.RowDiplomatic );
  table.insert( tTargets, Controls.RowWildcard );

  local tBest :table = DragSupport_GetBestOverlappingControl( tDraggedControl, tTargets );
  return tBest ~= nil;
end
function GetCurrentDragTargetInst( nDropRow:number, tDraggedControl:table, strDraggedCardPolicyType:string )
  -- Row can't accept card? Don't bother checking anything else, the answer is no.
  if not IsPolicyTypeLegalInRow( nDropRow, strDraggedCardPolicyType ) then
    return nil;
  end
  
  -- If know there's space in the row, just pick an open slot!
  local nFreeSlot :number = GetFirstFreeSlotIndex( nDropRow );
  if nFreeSlot ~= -1 then
    return m_ActiveCardInstanceArray[nFreeSlot + 1];
  end

  -- Check all the active card controls to see if we're targetting any with our drag.
  local tViableDragTargets :table = {}; -- also is its own map to get parent table from specific control.
  for _,tSlotData in ipairs(m_ActivePolicyRows[nDropRow].SlotArray) do
    local inst :table = m_ActiveCardInstanceArray[tSlotData.GC_SlotIndex+1];
    table.insert( tViableDragTargets, inst[KEY_DRAG_TARGET_CONTROL] );
    tViableDragTargets[inst[KEY_DRAG_TARGET_CONTROL]] = inst;
  end
  local tBestTarget :table = DragSupport_GetBestOverlappingControl( tDraggedControl, tViableDragTargets );

  return tBestTarget and tViableDragTargets[tBestTarget] or nil;
end

function OnStartDragFromCatalog( dragStruct:table, cardInstance:table )
  local policy		:table = m_kPolicyCatalogData[ cardInstance[KEY_POLICY_TYPE] ];

  cardInstance.Shadow:SetHide(false);
  UI.PlaySound("UI_Policies_Card_Take");

  BlockRowsUnableToAccept( policy.SlotType );
  HighlightActiveCard_DropTarget( nil );
end

function OnDragFromCatalog(dragStruct:table, cardInstance:table )
  local dragControl:table  = dragStruct:GetControl();
  local policyType :string = cardInstance[KEY_POLICY_TYPE];
  local nTargetRow :number = GetCurrentDragTargetRowIndex( dragControl, policyType );
  
  local tAcceptableTarget	 :table = nil;

  if nTargetRow ~= -1 then
    tAcceptableTarget = GetCurrentDragTargetInst( nTargetRow, dragControl, policyType );
  end
  HighlightActiveCard_DropTarget( tAcceptableTarget );
end

-- ===========================================================================
--	Dropping a card from the policy catalog
--	Find the data type from the dropped card and add it to the corresponding
--	row table.  When the table is realized, it will create a card for that type.
-- ===========================================================================
function OnDropFromCatalog( dragStruct:table, cardInstance:table )
  local dragControl:table  = dragStruct:GetControl();
  local policyType :string = cardInstance[KEY_POLICY_TYPE];
  local nTargetRow :number = GetCurrentDragTargetRowIndex( dragControl, policyType );

  cardInstance.Shadow:SetHide(true);
  UI.PlaySound("UI_Policies_Card_Drop");
  local bDropAccepted	:boolean = false;

  -- Was a valid drop site available?
  if nTargetRow ~= -1 then
    local tTargetCardInst :table = GetCurrentDragTargetInst( nTargetRow, dragControl, policyType );
    if ( tTargetCardInst ~= nil ) then
      SetActivePolicyAtSlotIndex( tTargetCardInst[KEY_POLICY_SLOT], policyType );
      bDropAccepted = true;
    end

    if not bDropAccepted then -- Not taken by a specific card, but maybe the row itself has an opening?
      -- Get a free slot if there is one and stick this guy in there
      local nFreeSlot :number = GetFirstFreeSlotIndex( nTargetRow );
      if nFreeSlot ~= -1 then
        SetActivePolicyAtSlotIndex( nFreeSlot, policyType );
        bDropAccepted = true;
      end
    end
  end
  
  HighlightActiveCard_DropTarget( nil );
  BlockRowsUnableToAccept( nil ); -- Turns back dark rows

  if bDropAccepted then
    dragControl:StopSnapBack();		-- Get catalog card instance ready for next time it's populated
    m_isPoliciesChanged = true;		-- Mark so button can go active

    RealizePolicyCatalog();
    RealizeActivePoliciesRows();
  end
end

-- ===========================================================================
--  Find the next available slot for this card type and add it (if possible)
--  Used when double-clicking a card from the catalog.
-- ===========================================================================
function AddToNextAvailRow( cardInstance:table )
  local policyType	:string = cardInstance[KEY_POLICY_TYPE];
  local cardSlotType	:string = m_kPolicyCatalogData[ policyType ].SlotType;

  local TryToAddToRow = function( nRowIndex:number, strSlotType:string, strPolicyType:string )
      if IsSlotTypeLegalInRow( nRowIndex, strSlotType ) then
        local nSlot :number = GetFirstFreeSlotIndex( nRowIndex );
        if ( nSlot ~= -1 ) then
          SetActivePolicyAtSlotIndex( nSlot, strPolicyType );
          return true;
        end
      end
      return false;
    end

  if not TryToAddToRow( ROW_INDEX.MILITARY, cardSlotType, policyType ) then
    if not TryToAddToRow( ROW_INDEX.ECONOMIC, cardSlotType, policyType ) then
      if not TryToAddToRow( ROW_INDEX.DIPLOMAT, cardSlotType, policyType ) then
        if not TryToAddToRow( ROW_INDEX.WILDCARD, cardSlotType, policyType ) then
          return; -- i give up
        end
      end
    end
  end
  -- This hits only if SOMEONE in the above stack resolved true.
  m_isPoliciesChanged = true;
  RealizePolicyCatalog();	
  RealizeActivePoliciesRows();
end


-- ===========================================================================
--  Start dragging a card that exists in a row.
-- ===========================================================================
function OnStartDragFromRow( dragStruct:table, cardInstance:table )	
  cardInstance.Shadow:SetHide(false);	
  UI.PlaySound("UI_Policies_Card_Take");

  local policyType :string = cardInstance[KEY_POLICY_TYPE];
  BlockRowsUnableToAccept( m_kPolicyCatalogData[policyType].SlotType );
end


-- ===========================================================================
--  Finish dragging a card out of a row
--  Will either snap back, replace a card in another row, or go back into
--  the catalog.
-- ===========================================================================
function OnDropFromRow( dragStruct:table, cardInstance:table )	
  local dragControl:table  = dragStruct:GetControl();
  local policyType :string = cardInstance[KEY_POLICY_TYPE];
  local nTargetRow :number = GetCurrentDragTargetRowIndex( dragControl, policyType );

  cardInstance.Shadow:SetHide( true );
  UI.PlaySound("UI_Policies_Card_Drop");

  local bCardMoved:boolean = false;	

  -- If we weren't dragged to a row that accepts this card type...
  if nTargetRow == -1 then
    -- ...then were we dragged to any row at all? Illegal rows snap back, elsewhere removed policy.
    if ( not IsDragOverRow( dragControl ) ) then
      RemoveActivePolicyAtSlotIndex( cardInstance[KEY_POLICY_SLOT] );
      bCardMoved = true;
    end
  else
    -- Dragged into a different row?
    if nTargetRow ~= cardInstance[KEY_ROW_ID] then

      -- If there's space, just add to the row! No swapping!
      local nFirstFreeSlot :number = GetFirstFreeSlotIndex( nTargetRow );
      if nFirstFreeSlot ~= -1 then
        RemoveActivePolicyAtSlotIndex( cardInstance[KEY_POLICY_SLOT] );
        SetActivePolicyAtSlotIndex( nFirstFreeSlot, policyType );
        bCardMoved = true;
      else
        -- no space, gotta swap with someone
        local tTargetCardInst :table = GetCurrentDragTargetInst( nTargetRow, dragControl, policyType );
        if ( tTargetCardInst ~= nil ) then
          RemoveActivePolicyAtSlotIndex( cardInstance[KEY_POLICY_SLOT] );
          SetActivePolicyAtSlotIndex( tTargetCardInst[KEY_POLICY_SLOT], policyType );
          bCardMoved = true;
        end
      end
    end		
  end

  if bCardMoved then
    cardInstance.Draggable:StopSnapBack();
    RealizePolicyCatalog();
    RealizeActivePoliciesRows();
  else
    BlockRowsUnableToAccept( nil ); -- Clear blockers from over active policy rows
  end

end

-- ===========================================================================
--  Update the member data for the active, local player.
-- ===========================================================================
function PopulateLivePlayerData( ePlayer:number )

  if ePlayer == -1 then
    return;
  end

  local kPlayer   :table = Players[ePlayer];
  local kPlayerCulture:table = kPlayer:GetCulture();

  -- Restore data from prior turn (likely only necessary in hot-seat)
  if m_kAllPlayerData[ ePlayer ] ~= nil then
    local playerData:table = m_kAllPlayerData[ ePlayer ];
    m_kPolicyFilterCurrent = playerData[DATA_FIELD_CURRENT_FILTER];
  end

  local governmentRowId :number = kPlayerCulture:GetCurrentGovernment();
  if governmentRowId ~= -1 then
    g_kCurrentGovernment = g_kGovernments[ GameInfo.Governments[governmentRowId].GovernmentType ];
  else
    g_kCurrentGovernment = nil;
  end

  -- Cache which civic was unlocked this turn, so we can determine whether to display new policy icons
  local civicCompletedThisTurn:string;
  if kPlayerCulture:CivicCompletedThisTurn() then
    -- Check for nil, it is possible that we do not have a valid civic completed!
    local civicInfo = GameInfo.Civics[kPlayerCulture:GetCivicCompletedThisTurn()];
    if civicInfo ~= nil then
      civicCompletedThisTurn = civicInfo.CivicType;
    end
  end

  -- Policies: populate unlocked (and not obsolete) ones for the catalog
  m_kUnlockedPolicies = {};
  m_kNewPoliciesThisTurn = {};
  for row in GameInfo.Policies() do
    local policyType    :string = row.PolicyType;
    local policyTypeRow   :table  = GameInfo.Types[policyType];
    local policyTypeHash  :number = policyTypeRow.Hash;
    local bPolicyAvailable  :boolean = kPlayerCulture:IsPolicyUnlocked(policyTypeHash) and not kPlayerCulture:IsPolicyObsolete(policyTypeHash);

    m_kUnlockedPolicies[policyType] = bPolicyAvailable or m_debugShowAllPolicies;
    m_kNewPoliciesThisTurn[policyType] = civicCompletedThisTurn and civicCompletedThisTurn == row.PrereqCivic;
  end

  m_ActivePoliciesByType = {};
  m_ActivePoliciesBySlot = {};
  m_ActivePolicyRows[ROW_INDEX.MILITARY] = { SlotArray={} };
  m_ActivePolicyRows[ROW_INDEX.ECONOMIC] = { SlotArray={} };
  m_ActivePolicyRows[ROW_INDEX.DIPLOMAT] = { SlotArray={} };
  m_ActivePolicyRows[ROW_INDEX.WILDCARD] = { SlotArray={} };
  
  local nPolicySlots:number = kPlayerCulture:GetNumPolicySlots();
  for i = 0, nPolicySlots-1, 1 do
    local iSlotType :number = kPlayerCulture:GetSlotType(i);
    local iPolicyID :number = kPlayerCulture:GetSlotPolicy(i);

    local strSlotType :string = GameInfo.GovernmentSlots[iSlotType].GovernmentSlotType
    -- strSlotType is of the form SLOT_##NAME##, and we want only the first 8 chars of ##NAME##
    local strRowKey :string = string.sub( strSlotType, 6, 13 );
    local nRowIndex :number = ROW_INDEX[strRowKey];
    
    if ( nRowIndex == nil ) then
        assert( false );
      UI.DataError("On initialization; slot type '"..strSlotType.."' requires key '"..strRowKey.."'");
    end

    local tSlotData :table = {
      -- Static members
      UI_RowIndex   = nRowIndex,
      GC_SlotIndex  = i,

      -- Dynamic members
      GC_PolicyType	= EMPTY_POLICY_TYPE
    };

    if ( iPolicyID ~= -1 ) then
      tSlotData.GC_PolicyType = GameInfo.Policies[iPolicyID].PolicyType;
      m_ActivePoliciesByType[tSlotData.GC_PolicyType] = tSlotData;
    end

    table.insert( m_ActivePolicyRows[nRowIndex].SlotArray, tSlotData );
    m_ActivePoliciesBySlot[i+1] = tSlotData;
  end

  m_kBonuses = {};
  for governmentType, government in pairs(g_kGovernments) do
    local bonusName   :string = (government.Index ~= -1) and GameInfo.Governments[government.Index].BonusType or "NO_GOVERNMENTBONUS";
    local iBonusIndex :number = -1;
    if bonusName ~= "NO_GOVERNMENTBONUS" then
      iBonusIndex = GameInfo.GovernmentBonusNames[bonusName].Index;
    end
    if government.BonusFlatAmountPreview >= 0 then
      m_kBonuses[governmentType] = {
        BonusPercent      = government.BonusFlatAmountPreview
      }
    end
  end

  -- Unlocked governments
  m_kUnlockedGovernments = {};
  for governmentType,government in pairs(g_kGovernments) do
    if kPlayerCulture:IsGovernmentUnlocked(government.Hash) then
      m_kUnlockedGovernments[governmentType] = true;
    end
  end

  -- DEBUG:
  if m_debugOutputGovInfo then
    DebugOutput();
  end

end

-- ===========================================================================
--  Debug output to console
-- ===========================================================================
function DebugOutput()
  if m_debugOutputGovInfo then
    print("                    Government Index Hash");
    print("------------------------------ ----- ----------");
    for governmentType, government in pairs(g_kGovernments) do
      print( string.format("%30s %-5d %-10s",
        governmentType,
        government.Index,
        government.Hash
      ));
    end
  end
end


-- ===========================================================================
--  Save the current data of a player (values that are UI specific that
--  can't be queried and (re-)populated from the game engine when this
--  player's next turn starts.
--  Mostly (only?) valid for local multiplayer hotseat.
-- ===========================================================================
function SaveLivePlayerData( ePlayer:number )
  local playerData:table = {};
  playerData[DATA_FIELD_CURRENT_FILTER] = m_kPolicyFilterCurrent;
  m_kAllPlayerData[ ePlayer ] = playerData;
end


-- ===========================================================================
--  Sort function used on policy catalog
-- ===========================================================================
function SortPolicies( typeA:string, typeB:string )
  local a :table = m_kPolicyCatalogData[typeA];
  local b :table = m_kPolicyCatalogData[typeB];
  local v1:number = SLOT_ORDER_IN_CATALOG[a.SlotType];
  local v2:number = SLOT_ORDER_IN_CATALOG[b.SlotType];
  if v1 == v2 then
    return typeA < typeB;
  end
  return v1 < v2;
end

-- ===========================================================================
--  Fill the catalog with the static (unchanging) policy data used by
--  all players when viewing the screen.
-- ===========================================================================
function PopulateStaticData()

  -- Fill in the complete catalog of policies.
  for row in GameInfo.Policies() do
    local policyTypeRow   :table  = GameInfo.Types[row.PolicyType];
    local policyName    :string = Locale.Lookup(row.Name);
    local policyTypeHash  :number = policyTypeRow.Hash;
    local slotType      :string = row.GovernmentSlotType;
    local description   :string = Locale.Lookup(row.Description);
    --local draftCost     :number = kPlayerCulture:GetEnactPolicyCost(policyTypeHash);  --Move to live data

    m_kPolicyCatalogData[row.PolicyType] = {
      Description = description,
      Name    = policyName,
      PolicyHash  = policyTypeHash,
      SlotType  = slotType,     -- SLOT_MILITARY, SLOT_ECONOMIC, SLOT_DIPLOMATIC, SLOT_WILDCARD, (SLOT_GREAT_PERSON)
      UniqueID  = row.Index     -- the row this policy exists in, is guaranteed to be unique (as-is the house, but these are readable. ;) )
      };

    table.insert(m_kPolicyCatalogOrder, row.PolicyType);
  end

  table.sort(m_kPolicyCatalogOrder, SortPolicies );

  -- Fill in governments
  g_kGovernments = {};
  for row in GameInfo.Governments() do
    local slotMilitary    :number = 0;
    local slotEconomic    :number = 0;
    local slotDiplomatic  :number = 0;
    local slotWildcard    :number = 0;

    for entry in GameInfo.Government_SlotCounts() do
      if row.GovernmentType == entry.GovernmentType then
        local slotType = entry.GovernmentSlotType;
        for i = 1, entry.NumSlots, 1 do
          if    slotType == "SLOT_MILITARY" then                  slotMilitary  = slotMilitary + 1;
          elseif  slotType == "SLOT_ECONOMIC" then                  slotEconomic  = slotEconomic + 1;
          elseif  slotType == "SLOT_DIPLOMATIC" then                  slotDiplomatic  = slotDiplomatic + 1;
          elseif  slotType == "SLOT_WILDCARD" or slotType=="SLOT_GREAT_PERSON" then slotWildcard  = slotWildcard + 1;
          end
        end
      end
    end

    g_kGovernments[row.GovernmentType] = {
      BonusAccumulatedText    = row.AccumulatedBonusShortDesc,
      BonusAccumulatedTooltip = row.AccumulatedBonusDesc,
      BonusFlatAmountPreview  = GetGovernmentFlatBonusPreview(row.BonusType),
      BonusInherentText       = row.InherentBonusDesc,
      BonusInfluenceNumber    = row.InfluenceTokensPerThreshold,
      BonusInfluenceText      = Locale.Lookup("LOC_GOVT_INFLUENCE_POINTS_TOWARDS_ENVOYS", row.InfluencePointsPerTurn, row.InfluencePointsThreshold, row.InfluenceTokensPerThreshold),
      BonusType               = row.BonusType,
      Hash                    = GameInfo.Types[row.GovernmentType].Hash,
      Index                   = row.Index,
      Name                    = row.Name,
      NumSlotMilitary         = slotMilitary,
      NumSlotEconomic         = slotEconomic,
      NumSlotDiplomatic       = slotDiplomatic,
      NumSlotWildcard         = slotWildcard
    }
  end
end

-- ===========================================================================
--  Preview a government's flat bonus independently of any particular player.
--  Because this looks at a government that may not be active, use a hacky
--  database lookup instead of asking the game what the active bonus amount is.
--  This is expensive and silly, so do it once on initialization and store it.
-- ===========================================================================
function GetGovernmentFlatBonusPreview(governmentBonusType:string)
  if (governmentBonusType == nil or governmentBonusType == "") then
    return 0;
  end
  local governmentType:string = nil;
  for row in GameInfo.Governments() do
    if (row.BonusType == governmentBonusType) then
      governmentType = row.GovernmentType;
      break;
    end
  end
  if (governmentType == nil) then
    return 0;
  end
  local flatBonusModifierId:string = nil;
  for row in GameInfo.GovernmentModifiers() do
    if (row.GovernmentType == governmentType) then
      local modifierId:string = row.ModifierId;
      local modifierArgs:table = {};
      for argRow in GameInfo.ModifierArguments() do
        if (argRow.ModifierId == modifierId) then
          table.insert(modifierArgs, argRow);
        end
      end
      local bonusType:string = nil;
      local amount:number = nil;
      for i,modifierArg in ipairs(modifierArgs) do
        if (modifierArg.Name == "BonusType") then
          bonusType = modifierArg.Value;
        elseif (modifierArg.Name == "Amount") then
          amount = tonumber(modifierArg.Value) or modifierArg.Value;
        end
      end
      if (bonusType ~= nil and bonusType == governmentBonusType and amount ~= nil) then
        return amount;
      end
    end
  end
  return 0;
end


-- ===========================================================================
--  Fill filters used for policies
-- ===========================================================================
function militaryFilter(policy)   return policy.SlotType == "SLOT_MILITARY";  end
function economicFilter(policy)   return policy.SlotType == "SLOT_ECONOMIC";  end
function diplomaticFilter(policy) return policy.SlotType == "SLOT_DIPLOMATIC"; end
function wildcardFilter(policy)   return policy.SlotType == "SLOT_WILDCARD"; end
-- CQUI : Great People Filter
function greatPeopleFilter(policy)  return policy.SlotType == "SLOT_GREAT_PERSON"; end

function PopulatePolicyFilterData()
  m_kPolicyFilters = {};
  table.insert( m_kPolicyFilters, { Func=nil,         Description="LOC_GOVT_FILTER_NONE"    } );
  table.insert( m_kPolicyFilters, { Func=militaryFilter,    Description="LOC_GOVT_FILTER_MILITARY"  } );
  table.insert( m_kPolicyFilters, { Func=economicFilter,    Description="LOC_GOVT_FILTER_ECONOMIC"  } );
  table.insert( m_kPolicyFilters, { Func=diplomaticFilter,  Description="LOC_GOVT_FILTER_DIPLOMATIC"  } );
  table.insert( m_kPolicyFilters, { Func=wildcardFilter,    Description="LOC_GOVT_FILTER_GREAT_PERSON"  } );
  -- CQUI : Great People Filter
  table.insert( m_kPolicyFilters, { Func=greatPeopleFilter, Description="LOC_GOVT_FILTER_GREAT_PERSON"  } );

  for i,filter in ipairs(m_kPolicyFilters) do
    local filterLabel  :string = Locale.Lookup( filter.Description );
    local controlTable   :table  = {};
    Controls.FilterPolicyPulldown:BuildEntry( "FilterPolicyItemInstance", controlTable );
    controlTable.DescriptionText:SetText( filterLabel );
    controlTable.Button:RegisterCallback( Mouse.eLClick,  function() OnPolicyFilterClicked(filter); end );
  end
  Controls.FilterPolicyPulldown:CalculateInternals();

  m_kPolicyFilterCurrent = m_kPolicyFilters[1];
  RealizePolicyFilterPulldown();
end


-- ===========================================================================
-- Update the Policy Filter text with the current label.
-- ===========================================================================
function RealizePolicyFilterPulldown()
  local pullDownButton :table = Controls.FilterPolicyPulldown:GetButton();
  if m_kPolicyFilterCurrent == nil or m_kPolicyFilterCurrent.Func== nil then
    pullDownButton:SetText( "  "..Locale.Lookup("LOC_GOVT_FILTER_W_DOTS"));
  else
    local description:string = Locale.Lookup( m_kPolicyFilterCurrent.Description);
    pullDownButton:SetText( description );
  end

end

-- ===========================================================================
--  filter, the filter object to use (or NIL for none)
-- ===========================================================================
function OnPolicyFilterClicked( filter:table )
  m_kPolicyFilterCurrent = filter;
  RealizePolicyFilterPulldown();
  RealizePolicyCatalog();
end


-- ===========================================================================
--  UI Event
-- ===========================================================================
function OnInit( isReload:boolean )
  if isReload then
    m_ePlayer = Game.GetLocalPlayer();
    RefreshAllData();
    LuaEvents.GameDebug_GetValues( "GovernmentScreen" );
  end
end

-- ===========================================================================
--  UI EVENT
-- ===========================================================================
function OnShutdown()
  -- Cache values for hotloading...
  local eOpenTabAtInit = nil;
  if ( ContextPtr:IsVisible() ) then
    if m_tabs.selectedControl == Controls.ButtonMyGovernment then
      eOpenTabAtInit = SCREEN_ENUMS.MY_GOVERNMENT;
    elseif m_tabs.selectedControl == Controls.ButtonGovernments then
      eOpenTabAtInit = SCREEN_ENUMS.GOVERNMENTS;
    else
      eOpenTabAtInit = SCREEN_ENUMS.POLICIES;
    end
  end
  LuaEvents.GameDebug_AddValue("GovernmentScreen", "eOpenTabAtInit", eOpenTabAtInit );
end

-- ===========================================================================
--  LUA Event
--  Set cached values back after a hotload.
-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
  if context == "GovernmentScreen" and contextTable then
    local eOpenTabAtInit:number = contextTable["eOpenTabAtInit"]; 
    if eOpenTabAtInit ~= nil and OnOpenGovernmentScreen ~= nil then
      OnOpenGovernmentScreen(eOpenTabAtInit);
    end
  end
end

-- ===========================================================================
function OnRowAnimCallback()
  function lerp(a:number, b:number, t:number)
    return a * (1-t) + (b*t);
  end

  local nProgress = Controls.RowAnim:GetProgress();
  if ( Controls.RowAnim:IsReversing() ) then
    nProgress = 1 - nProgress;
  end

  Controls.PolicyRows:SetSizeX(lerp(m_AnimRowSize.policy, m_AnimRowSize.mygovt, nProgress));
  Controls.PoliciesContainer:SetSizeX(lerp(m_AnimCatalogSize.policy, m_AnimCatalogSize.mygovt, nProgress));
  Controls.PoliciesContainer:SetOffsetX(lerp(m_AnimCatalogOffset.policy, m_AnimCatalogOffset.mygovt, nProgress));
  Controls.MyGovernment:SetOffsetX(lerp(m_AnimMyGovtOffset.policy, m_AnimMyGovtOffset.mygovt, nProgress));
  Controls.CategoryIconsLeft:SetOffsetX(-lerp(m_AnimMyGovtOffset.policy, m_AnimMyGovtOffset.mygovt, nProgress));
  RealizeActivePolicyRowSize();
end

-- ===========================================================================
--  Input
--  UI Event Handler
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
  if ( pInputStruct:GetMessageType() == KeyEvents.KeyUp ) then
    local key:number = pInputStruct:GetKey();
    if ( key == Keys.VK_ESCAPE ) then
      Close();
      return true;
    elseif ( key == Keys.VK_RETURN ) then
      -- Don't let enter propagate or it will hit action panel which will raise a screen (potentially this one again) tied to the action.

      if not Controls.SelectPolicies:IsHidden() and IsAbleToChangePolicies() then
        OnConfirmPolicies();
      end
      return true;
    end
  end
  return false;
end

-- ===========================================================================
--  CTOR
-- ===========================================================================
function Initialize()

  if (not HasCapability("CAPABILITY_GOVERNMENTS_VIEW")) then
    -- Governments is off, just exit
    return;
  end

  PopulateStaticData();     -- Obtain unchanging, static data from game core
  PopulatePolicyFilterData();   -- Filter support

  m_ePlayer = Game.GetLocalPlayer();

  RealizeTabs();
  Resize();

  Controls.LabelMilitary:SetText(Locale.Lookup("{LOC_GOVT_POLICY_TYPE_MILITARY:upper}"));
  Controls.LabelEconomic:SetText(Locale.Lookup("{LOC_GOVT_POLICY_TYPE_ECONOMIC:upper}"));
  Controls.LabelDiplomatic:SetText(Locale.Lookup("{LOC_GOVT_POLICY_TYPE_DIPLOMATIC:upper}"));
  Controls.LabelWildcard:SetText(Locale.Lookup("{LOC_GOVT_POLICY_TYPE_WILDCARD:upper}"));

  local sFilterPrefix:string = Locale.Lookup("LOC_GOVT_FILTER_W_DOTS") .. "[NEWLINE]";
  Controls.NoFilterButton:SetToolTipString(sFilterPrefix .. Locale.Lookup("LOC_GOVT_FILTER_NONE") );
  Controls.MilitaryFilterButton:SetToolTipString(sFilterPrefix .. Locale.Lookup("LOC_GOVT_FILTER_MILITARY") );
  Controls.EconomicFilterButton:SetToolTipString(sFilterPrefix .. Locale.Lookup("LOC_GOVT_FILTER_ECONOMIC") );
  Controls.DiplomacyFilterButton:SetToolTipString(sFilterPrefix .. Locale.Lookup("LOC_GOVT_FILTER_DIPLOMATIC") );
  Controls.WildcardFilterButton:SetToolTipString(sFilterPrefix .. Locale.Lookup("LOC_GOVT_FILTER_WILDCARD") );
  -- CQUI: Added great people filter button (after summer patch)
  Controls.GreatPeopleFilterButton:SetToolTipString(sFilterPrefix .. Locale.Lookup("LOC_CATEGORY_GREAT_PEOPLE_NAME") );
  
  Controls.NoFilterButton:RegisterCallback(		Mouse.eLClick,	function() OnPolicyFilterClicked( {Func=nil,				Description="LOC_GOVT_FILTER_NONE"} ); end );
  Controls.MilitaryFilterButton:RegisterCallback(	Mouse.eLClick,	function() OnPolicyFilterClicked( {Func=militaryFilter,		Description="LOC_GOVT_FILTER_MILITARY"} ); end );
  Controls.EconomicFilterButton:RegisterCallback(	Mouse.eLClick,	function() OnPolicyFilterClicked( {Func=economicFilter,		Description="LOC_GOVT_FILTER_ECONOMIC"} ); end );
  Controls.DiplomacyFilterButton:RegisterCallback(Mouse.eLClick,	function() OnPolicyFilterClicked( {Func=diplomaticFilter,	Description="LOC_GOVT_FILTER_DIPLOMATIC"} ); end );
  Controls.WildcardFilterButton:RegisterCallback(	Mouse.eLClick,	function() OnPolicyFilterClicked( {Func=wildcardFilter,		Description="LOC_GOVT_FILTER_WILDCARD"} ); end );
  -- CQUI: Added great people filter button (after summer patch)
  Controls.GreatPeopleFilterButton:RegisterCallback(Mouse.eLClick,  function() OnPolicyFilterClicked( {Func=greatPeopleFilter, Description="LOC_CATEGORY_GREAT_PEOPLE_NAME"} ); end );

  Controls.MilitaryFilterButton:SetHide(not GameCapabilities.HasCapability("CAPABILITY_GOVERNMENT_SCREEN_MILITARY_FILTER"));
  Controls.DiplomacyFilterButton:SetHide(not GameCapabilities.HasCapability("CAPABILITY_GOVERNMENT_SCREEN_DIPLOMACY_FILTER"));
  Controls.FilterStack:CalculateSize();

  Controls.ButtonMyGovernment:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.ButtonPolicies:RegisterCallback(     Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.ButtonGovernments:RegisterCallback(  Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

  Controls.CompletedRibbon:SetText( Locale.Lookup("LOC_GOVT_COMPLETED_THIS_TURN","$SomeCivic$") );

  -- Static controls:
  ContextPtr:SetInitHandler( OnInit );
  ContextPtr:SetInputHandler( OnInputHandler, true );
  ContextPtr:SetShutdown( OnShutdown );

  Controls.ConfirmPolicies:RegisterCallback(    Mouse.eLClick,  OnConfirmPolicies);
  Controls.ConfirmPolicies:RegisterCallback(    Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.PolicyPanelCheckbox:RegisterCallback(  Mouse.eLClick,  OnTogglePolicyListPanel );
  Controls.PolicyPanelCheckbox:RegisterCallback(  Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.RowAnim:RegisterAnimCallback(              OnRowAnimCallback);
  Controls.UnlockPolicies:RegisterCallback(   Mouse.eLClick,  OnUnlockPolicies);
  Controls.UnlockPolicies:RegisterCallback(   Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.UnlockGovernments:RegisterCallback(  Mouse.eLClick,  OnUnlockGovernments);
  Controls.UnlockGovernments:RegisterCallback(  Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

  -- Hide these after going invisible to prevent input
  Controls.GovernmentTree:RegisterEndCallback( function()
    if Controls.GovernmentTree:IsReversing() then
      Controls.GovernmentTree:SetHide(true);
    end end );
  Controls.AlphaAnim:RegisterEndCallback( function()
      if not Controls.AlphaAnim:IsReversing() then -- "CAN'T TOUCH XML" note: AlphaAnim goes from 1 to 0, thus the "not" here.
        Controls.AlphaAnim:SetHide(true);
      end end );
  Controls.RowAnim:RegisterEndCallback( function()
      if Controls.RowAnim:IsReversing() then
        Controls.CategoryIconsLeft:SetHide( true );
      end end );

  -- Gamecore EVENTS
  Events.CivicsUnlocked.Add( OnCivicsUnlocked );
  Events.GovernmentChanged.Add( OnGovernmentChanged );
  Events.GovernmentPolicyChanged.Add( OnGovernmentPolicyChanged );
  Events.GovernmentPolicyObsoleted.Add( OnGovernmentPolicyChanged );
  Events.PhaseBegin.Add(OnPhaseBegin);
  Events.LocalPlayerTurnBegin.Add( OnLocalPlayerTurnBegin );
  Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );
  Events.SystemUpdateUI.Add( OnUpdateUI );

  -- Lua Events
  LuaEvents.LaunchBar_CloseGovernmentPanel.Add( OnCloseFromLaunchBar );
  LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );
  LuaEvents.NotificationPanel_GovernmentOpenGovernments.Add( OnOpenGovernmentScreenGovernments );
  LuaEvents.NotificationPanel_GovernmentOpenPolicies.Add( OnOpenGovernmentScreenPolicies );
  LuaEvents.LaunchBar_GovernmentOpenMyGovernment.Add( OnOpenGovernmentScreenMyGovernment );
  LuaEvents.LaunchBar_GovernmentOpenGovernments.Add( OnOpenGovernmentScreenGovernments );
  LuaEvents.TechCivicCompletedPopup_GovernmentOpenGovernments.Add( OnOpenGovernmentScreenGovernments );
  LuaEvents.TechCivicCompletedPopup_GovernmentOpenPolicies.Add( OnOpenGovernmentScreenPolicies );
  LuaEvents.Advisor_GovernmentOpenPolicies.Add( OnOpenGovernmentScreenPolicies );

  Controls.ModalScreenTitle:SetText(Locale.ToUpper("LOC_GOVT_GOVERNMENT"));
  Controls.ModalScreenClose:RegisterCallback(Mouse.eLClick, OnClose);
  Controls.ModalBG:SetHide(true);

  Controls.PolicyPanelHeaderLabel:SetText(Locale.ToUpper("LOC_TREE_OPTIONS"));
end
Initialize();
