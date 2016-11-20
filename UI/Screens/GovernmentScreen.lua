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
include("PopupDialogSupport");
include("ModalScreen_PlayerYieldsHelper");

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

local m_showGovernmentInPolicySelect  :boolean = false; -- If the screen width allows it, let's show the government information while you are selecting policies.

-- LUA based struct (required copy from DragSupport)
hstructure DropAreaStruct
  x   : number
  y   : number
  width : number
  height  : number
  control : table
  id    : number  -- (optional, extra info/ID)
end

local COLOR_BACKING         :number = 0xffbedcdc;       -- Background for governments
local COLOR_BRIGHT          :number = 0xffe9dfc7;       -- Background for selected background (or forground text color on non-selected).
local COLOR_DARK          :number = 0xff261407;       -- Background for selected background (or forground text color on non-selected).
local COLOR_DARKEN_POLICY_ROW   :number = 0xffAAAAAA;
local COLOR_LOCKED_GOVERNMENT   :number = 0xffAAAAAA;
local DATA_FIELD_CURRENT_FILTER   :string = "_CURRENT_FILTER";
local DATA_FIELD_TOTAL_SLOTS    :string = "_TOTAL_SLOTS";     -- Total slots for a government item in the "tree-like" view
local DROP_OVERLAP_REQUIRED     :number = 0.5;
local DROP_ROW_ID :table = {                      -- ID for where cards are dropped (drag'n drop)
    MILITARY = 1,
    ECONOMIC = 2,
    DIPLOMATIC = 3,
    WILDCARD = 4
}
local DROP_ROW_SLOT_TYPES :table = {};
    DROP_ROW_SLOT_TYPES[DROP_ROW_ID.MILITARY] = "SLOT_MILITARY";
    DROP_ROW_SLOT_TYPES[DROP_ROW_ID.ECONOMIC] = "SLOT_ECONOMIC";
    DROP_ROW_SLOT_TYPES[DROP_ROW_ID.DIPLOMATIC] = "SLOT_DIPLOMATIC";
    DROP_ROW_SLOT_TYPES[DROP_ROW_ID.WILDCARD] = "SLOT_WILDCARD";
local EMPTY_POLICY_TYPE       :string = "empty";          -- For a policy slot without a type
local KEY_POLICY_TYPE       :string = "PolicyType";       -- Key on a catalog UI element that holds the PolicyType; so corresponding data can be found
local KEY_ROW_ID          :string = "RowNum";         -- Key on a row UI element to note which row it came from.
local OFF_POLICY_CARD_X       :number = 4;
local OFF_POLICY_CARD_Y       :number = 4;
local MAX_POLICY_COLS       :number = 4;            -- Number of card slot columns in the policy catalog
local MAX_POLICY_ROWS       :number = 3;            --                 ... rows ...
local PADDING_POLICY_ROW_ITEM   :number = 3;
local PADDING_POLICY_LIST_HEADER  :number = 50;
local PADDING_POLICY_LIST_BOTTOM  :number = 20;
local PADDING_POLICY_LIST_ITEM    :number = 20;
local PADDING_POLICY_SCROLL_AREA  :number = 10;
local PERCENT_OVERLAP_TO_SWAP   :number = 0.7;            -- How much overlap (on a drop) to swap a card with another.
local PERCENT_OVERLAP_TO_REPLACE  :number = 0.5;            -- How much overlap (on a drop) to replace another card in the row. (Row to row)
local PIC_CARD_SUFFIX_SMALL     :string = "_Small";
local PIC_CARD_TYPE_DIPLOMACY   :string = "Governments_DiplomacyCard";
local PIC_CARD_TYPE_ECONOMIC    :string = "Governments_EconomicCard";
local PIC_CARD_TYPE_MILITARY    :string = "Governments_MilitaryCard";
local PIC_CARD_TYPE_WILDCARD    :string = "Governments_WildcardCard";
local PIC_PAGE_PIP          :string = "Controls_PagePip";
local PIC_PAGE_PIP_CURRENT      :string = "Controls_PagePip_Filled";
local PIC_PERCENT_BRIGHT      :string = "Governments_PercentWhite";
local PIC_PERCENT_DARK        :string = "Governments_PercentBlue";
local PICS_SLOT_TYPE_CARD_BGS   :table  = {};
    PICS_SLOT_TYPE_CARD_BGS["SLOT_DIPLOMATIC"]  = PIC_CARD_TYPE_DIPLOMACY;
    PICS_SLOT_TYPE_CARD_BGS["SLOT_ECONOMIC"]    = PIC_CARD_TYPE_ECONOMIC;
    PICS_SLOT_TYPE_CARD_BGS["SLOT_MILITARY"]    = PIC_CARD_TYPE_MILITARY;
    PICS_SLOT_TYPE_CARD_BGS["SLOT_WILDCARD"]    = PIC_CARD_TYPE_WILDCARD;
    PICS_SLOT_TYPE_CARD_BGS["SLOT_GREAT_PERSON"]  = PIC_CARD_TYPE_WILDCARD;   -- Great person is also utilized as a wild card.
local SCREEN_ENUMS :table = {
    MY_GOVERNMENT = 1,
    GOVERNMENTS   = 2,
    POLICIES    = 3
}
local SIZE_TAB_BUTTON_TEXT_PADDING      :number = 50;
local SIZE_HERITAGE_BONUS         :number = 48;
local SIZE_GOV_ITEM_WIDTH         :number = 400;
local SIZE_GOV_ITEM_HEIGHT          :number = 152;  -- 238 minus shadow
local SIZE_GOV_DIVIDER_WIDTH        :number = 75;
local SIZE_POLICY_ROW_LARGE         :number = 675;
local SIZE_POLICY_CARD_X          :number = 120;
local SIZE_POLICY_CARD_Y          :number = 135;
local SIZE_MIN_SPEC_X           :number = 1024;
local TXT_GOV_ASSIGN_POLICIES       :string = Locale.Lookup("LOC_GOVT_ASSIGN_ALL_POLICIES");
local TXT_GOV_CONFIRM_POLICIES        :string = Locale.Lookup("LOC_GOVT_CONFIRM_POLICIES");
local TXT_GOV_CONFIRM_GOVERNMENT      :string = Locale.Lookup("LOC_GOVT_CONFIRM_GOVERNMENT");
local TXT_GOV_POPUP_NO            :string = Locale.Lookup("LOC_GOVT_PROMPT_NO");
local TXT_GOV_POPUP_PROMPT_POLICIES_CLOSE :string = Locale.Lookup("LOC_GOVT_POPUP_PROMPT_POLICIES_CLOSE");
local TXT_GOV_POPUP_PROMPT_POLICIES_CONFIRM :string = Locale.Lookup("LOC_GOVT_POPUP_PROMPT_POLICIES_CONFIRM");
local TXT_GOV_POPUP_YES           :string = Locale.Lookup("LOC_GOVT_PROMPT_YES");
local MAX_HEIGHT_POLICIES_LIST        :number = 600;
local MAX_HEIGHT_GOVT_DESC          :number = 25;
local MAX_BEFORE_TRUNC_GOVT_BONUS     :number = 229;
local MAX_BEFORE_TRUNC_BONUS_TEXT     :number = 219;
local MAX_BEFORE_TRUNC_HERITAGE_BONUS   :number = 225;

-- ===========================================================================
--  VARIABLES
-- ===========================================================================

local m_policyCardIM      :table = InstanceManager:new("PolicyCard",          "Content",  Controls.PolicyCatalog);
local m_kGovernmentLabelIM    :table = InstanceManager:new("GovernmentEraLabelInstance",  "Top",    Controls.GovernmentDividers );
local m_kGovernmentItemIM   :table = InstanceManager:new("GovernmentItemInstance",    "Top",    Controls.GovernmentScroller );

local m_activeSlotRowData   :table  = {};
    m_activeSlotRowData["k"..DROP_ROW_ID.DIPLOMATIC]= { Avail=0, Max=0, Policies={}, GameCoreSlotIndexes={} }; 
    m_activeSlotRowData["k"..DROP_ROW_ID.ECONOMIC]  = { Avail=0, Max=0, Policies={}, GameCoreSlotIndexes={} }; 
    m_activeSlotRowData["k"..DROP_ROW_ID.MILITARY]  = { Avail=0, Max=0, Policies={}, GameCoreSlotIndexes={} }; 
    m_activeSlotRowData["k"..DROP_ROW_ID.WILDCARD]  = { Avail=0, Max=0, Policies={}, GameCoreSlotIndexes={} }; 
local m_ePlayer         :number = -1;
local m_kAllPlayerData      :table  = {};   -- Holds copy of player data for all local players
local m_kBonuses        :table  = {}
local m_kCurrentData      :table  = {};   -- Current set of data.
local m_kCurrentGovernment    :table  = nil;
local m_kDropAreasPolicyRows  :table  = {};   -- Used by drag n' drop system
local m_governmentChangeType  :string = "";   -- The government type proposed being changed to.
local m_isPoliciesChanged   :boolean= false;
local m_kPopupDialog      :table;
local m_kGovernments      :table  = {};
local m_kPolicyCatalogData    :table  = {};
local m_kPolicyCatalogOrder   :table  = {};   -- Track order of policies to display
local m_kPolicyFilters      :table  = {};
local m_kPolicyFilterCurrent  :table  = nil;
local m_kUnlockedGovernments  :table  = {};
local m_kUnlockedPolicies   :table;
local m_kNewPoliciesThisTurn  :table;
local m_tabs          :table;
local m_uiActivePolicies    :table  = {};   -- Instances of UI in the "rows"
local m_uiGovernments     :table  = {};
local m_width         :number = SIZE_MIN_SPEC_X;  -- Screen Width (default / min spec)
local m_areaForPolicyRows         :number = 0;  -- This is the area that the policy rows have to display within
local m_SizeChoosePolicyRows        :number = 510;  -- This is the actual size of the policy rows in the Choose Policies tab - now this is a variable which changes based on the size of the screen
local m_currentCivicType    :string = nil;
local m_civicProgress     :number = 0;
local m_civicCost       :number = 0;
-- Used to lerp PolicyRows size and X offset when RowAnim is playing
local m_policyRowAnimData   :table = {
  initialSize = SIZE_POLICY_ROW_LARGE,
  desiredSize = SIZE_POLICY_ROW_LARGE,
  initialOffset = 0,
  desiredOffset = 0, 
}
local m_ToggleGovernmentId    :number = Input.GetActionId("ToggleGovernment");

local m_hasDiplomacySlots   :boolean = false;
local m_hasEconomicSlots  :boolean = false;
local m_hasMilitarySlots  :boolean = false;
local m_hasWildcardSlots  :boolean = false;
-- ===========================================================================
--  FUNCTIONS
-- ===========================================================================


-- ===========================================================================
--  Setup the screen elements for the given resolution.
-- ===========================================================================

function Resize()
  
  m_width, _  = UIManager:GetScreenSizeVal();       -- Cache screen dimensions
  m_showGovernmentInPolicySelect = false;         -- This boolean tracks whether or not we'll show the government card inside the Choose Policies view

  local offsetX = m_width/2 - 1024/2;
  Controls.MainContainer:SetOffsetX(offsetX);
  if(offsetX > Controls.MyGovernment:GetSizeX()) then   -- If we have enough room to accommodate both the Government card and the Choose Policy viewer, then we'll show it
    m_showGovernmentInPolicySelect = true;
  end
  local policiesAreaX = m_width/2 +15;          -- The area that we have to display the policy catalog within
  m_areaForPolicyRows = m_width - policiesAreaX;      -- The area remaining is the area for the policy rows
  local choosePolicyRowsX = (m_width/2) - (((m_width/2) -  SIZE_POLICY_ROW_LARGE)/2);     -- The calculated X area for the policy rows to lerp to
  if (m_showGovernmentInPolicySelect) then        -- If we are showing the government card, reduce the usable policy area to compensate
    m_areaForPolicyRows = m_areaForPolicyRows - Controls.MyGovernment:GetSizeX() - 15;
  end
  
  if ( m_areaForPolicyRows > choosePolicyRowsX ) then   -- If we have more area than we need, we'll lerp to the newly calculated destination
    m_SizeChoosePolicyRows = choosePolicyRowsX;
  else                          -- Otherwise we'll use the entire area for the policy rows
    m_SizeChoosePolicyRows = m_areaForPolicyRows + 15;  
  end
  

  Controls.PoliciesContainer:SetSizeX(policiesAreaX);
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
  Controls.ButtonMyGovernment:SetSizeX( 0 );
  Controls.SelectMyGovernment:SetSizeX( 0 );
end


-- ===========================================================================
--  Realize all the content for the existing government
-- ===========================================================================
function RealizeMyGovernmentPage()
  
  RealizePolicyCatalog();
  RealizeActivePoliciesRows();

  local kPlayer   :table  = Players[m_ePlayer];
  local kPlayerCulture:table  = kPlayer:GetCulture();
  local iBonusIndex :number = -1;
  local bonusName   :string = (m_kCurrentGovernment.Index ~= -1) and GameInfo.Governments[m_kCurrentGovernment.Index].BonusType or "NO_GOVERNMENTBONUS";
  local currentGovernmentName:string = Locale.Lookup(m_kCurrentGovernment.Name);

  m_policyRowAnimData.initialSize = m_policyRowAnimData.desiredSize;
  m_policyRowAnimData.desiredSize = SIZE_POLICY_ROW_LARGE;
  m_policyRowAnimData.initialOffset = 0;
  m_policyRowAnimData.desiredOffset = 0;

  -- Clear heritage bonuses; will rebuild them throughout...
  Controls.HeritageBonusStack:DestroyAllChildren();

  -- If bonus exists for current one. 
  if bonusName ~= "NO_GOVERNMENTBONUS" then
    iBonusIndex = GameInfo.GovernmentBonusNames[bonusName].BonusValue;
  end

  local isHeritageBonusEmpty :boolean = true;

  if iBonusIndex ~= -1 then

    Controls.BonusStack:SetHide( false );

    local iFlatBonus        :number = kPlayerCulture:GetFlatBonus(iBonusIndex);
    local iIncrementingBonus    :number = kPlayerCulture:GetIncrementingBonus(iBonusIndex);
    local iBonusIncrement     :number = kPlayerCulture:GetIncrementingBonusIncrement(iBonusIndex);
    local iTurnsRequiredForBonus  :number = kPlayerCulture:GetIncrementingBonusInterval(iBonusIndex);
    local iTurnsTillNextBonus   :number = kPlayerCulture:GetIncrementingBonusTurnsUntilNext(iBonusIndex);
    local accumulatedBonusText    :string = Locale.ToUpper(Locale.Lookup(m_kCurrentGovernment.BonusAccumulatedText));
    local accumulatedBonusTooltip :string = Locale.Lookup(m_kCurrentGovernment.BonusAccumulatedTooltip);
        
    Controls.BonusPercent:SetText( tostring(iFlatBonus) );
    Controls.BonusText:SetText(accumulatedBonusText );
    if Controls.BonusText:GetSizeY() > MAX_HEIGHT_GOVT_DESC then
      local bonusTextString :string = Controls.BonusText:GetText();
      if TruncateString(Controls.BonusText, MAX_BEFORE_TRUNC_BONUS_TEXT, bonusTextString) then
        Controls.BonusText:SetToolTipString(bonusTextString .. "[NEWLINE]" .. accumulatedBonusTooltip);
      end
    end
    Controls.GovPercentBonusArea:SetToolTipString( accumulatedBonusTooltip );

    -- Add current heritage/incrementing bonus
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

  local inherentBonusDesc :string = Locale.Lookup( m_kCurrentGovernment.BonusInherentText );
  Controls.GovernmentBonus:SetText( Locale.ToUpper( inherentBonusDesc ));
  Controls.GovernmentInfluence:SetText( "[ICON_Envoy]" .. m_kCurrentGovernment.BonusInfluenceNumber );
  Controls.GovernmentInfluence:SetToolTipString( m_kCurrentGovernment.BonusInfluenceText );
  Controls.GovernmentName:SetText( Locale.ToUpper(currentGovernmentName) );
  Controls.GovernmentImage:SetTexture(GameInfo.Governments[m_kCurrentGovernment.Index].GovernmentType);

  -- Fill out remaining heritage/incrementing bonuses (from prior governments that were held by this player)
  for governmentType,government in pairs(m_kGovernments) do
    -- Skip current one (already in list.
    if government.Index ~= m_kCurrentGovernment.Index then
      local iBonusIndex   :number = -1;
      local iIncrementingBonus:number = -1;
      local bonusName     :string = government.BonusType;
      if bonusName ~= "NO_GOVERNMENTBONUS" then
        iBonusIndex     = GameInfo.GovernmentBonusNames[bonusName].BonusValue;
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
  
  Controls.GovernmentContentStack:CalculateSize()
  Controls.GovernmentContentStack:ReprocessAnchoring()
  Controls.GovernmentTop:SetSizeY(Controls.GovernmentContentStack:GetSizeY() + 18);
  Controls.HeritageBonusStack:CalculateSize();
  Controls.HeritageScrollPanel:CalculateSize();
  Controls.HeritageBonusEmpty:SetHide(not isHeritageBonusEmpty);
  Controls.LabelMilitaryStack:ReprocessAnchoring();
  Controls.LabelDiplomaticStack:ReprocessAnchoring();
  Controls.LabelEconomicStack:ReprocessAnchoring();
  Controls.LabelWildcardStack:ReprocessAnchoring();
end


-- ===========================================================================
--  Realize content for viewing/selecting all the governments
-- ===========================================================================
function RealizeGovernmentsPage()
  
  -- This function uses the local player further down, so validate it now.
  if (Game.GetLocalPlayer() == -1) then
    return;
  end

  m_uiGovernments = {};
  m_kGovernmentItemIM:ResetInstances();

  local grid:table = {};
  local width:number=0;

  for governmentType,_ in pairs(m_kGovernments) do
    local government  :table = m_kGovernments[governmentType];
    local inst      :table = m_kGovernmentItemIM:GetInstance();

    inst.Top:RegisterCallback(Mouse.eRClick, function() LuaEvents.OpenCivilopedia(governmentType); end);
    inst.Selected:RegisterCallback(Mouse.eRClick, function() LuaEvents.OpenCivilopedia(governmentType); end);

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

    inst.SlotStack:ReprocessAnchoring();

    -- Special logic if showing all (for ones that haven't been selected).
    if m_kUnlockedGovernments[governmentType] == nil then
      inst.Top:SetColor( COLOR_LOCKED_GOVERNMENT );
      inst.ImageFrame:SetColor( COLOR_LOCKED_GOVERNMENT );
      inst.GovernmentImage:SetHide( true );
      inst.Disabled:SetHide( false );
      inst.ArtLeft:SetColor( COLOR_LOCKED_GOVERNMENT );
      inst.ArtRight:SetColor( COLOR_LOCKED_GOVERNMENT );

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
    local textColor:number = COLOR_BRIGHT ;
    local bonusName   :string = GameInfo.Governments[government.Index].BonusType or "NO_GOVERNMENTBONUS";

    -- Determine selected government by either "really selected" or the one the player
    -- has clicked and is about to select for a change.
    local isSelected:boolean = false;
    if m_governmentChangeType == governmentType then
      isSelected = true;
    elseif m_governmentChangeType == "" and m_kCurrentGovernment ~= nil and m_kCurrentGovernment.Index == government.Index then
      isSelected = true;
    end

    if isSelected then
      -- Selected government
      textColor = COLOR_DARK;
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
      inst.GovernmentBonus:SetText( Locale.ToUpper(Locale.Lookup(government.BonusInherentText )) );
      if inst.GovernmentBonus:GetSizeY() > MAX_HEIGHT_GOVT_DESC then
        TruncateStringWithTooltip(inst.GovernmentBonus, MAX_BEFORE_TRUNC_GOVT_BONUS, inst.GovernmentBonus:GetText());
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
      
    -- If bonus exists for current one. 
    if bonusName ~= "NO_GOVERNMENTBONUS" then
      inst.BonusStack:SetHide( false );
    else
      inst.BonusStack:SetHide( true );
    end
      
    inst.GovernmentContentStack:CalculateSize();
    inst.GovernmentContentStack:ReprocessAnchoring();
    
    inst.Top:SetSizeY(inst.GovernmentContentStack:GetSizeY() + 12);

    inst[DATA_FIELD_TOTAL_SLOTS] = totalSlots;
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
    local num       :number = table.count(column);
    local spaceFree     :number = maxHeight-(num*SIZE_GOV_ITEM_HEIGHT);
    local spaceBetweenEach  :number = spaceFree/ (num+1);
    for y=1,num,1 do
      inst = column[y];
      local posX:number = x * (SIZE_GOV_ITEM_WIDTH + SIZE_GOV_DIVIDER_WIDTH);
      local posY:number = (y * (spaceBetweenEach + SIZE_GOV_ITEM_HEIGHT)) - (SIZE_GOV_ITEM_HEIGHT);
      inst.Top:SetOffsetVal(posX , posY); -- Spread centered
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
  local kPlayer       :table = Players[m_ePlayer];
  local pPlayerCulture    :table = kPlayer:GetCulture();
  local playerTreasury    :table  = Players[Game.GetLocalPlayer()]:GetTreasury();
  local isGovernmentChanged :boolean= pPlayerCulture:GovernmentChangeMade();
  local iPolicyUnlockCost   :number = pPlayerCulture:GetCostToUnlockPolicies();
  local iGoldBalance      :number = playerTreasury:GetGoldBalance();
  if isGovernmentChanged then
    Controls.UnlockGovernmentsContainer:SetHide(true);  
  elseif (table.count(m_kUnlockedGovernments) <= 1) then
    Controls.UnlockGovernmentsContainer:SetHide(true);
  elseif (iPolicyUnlockCost == 0 or m_kCurrentGovernment == nil) then
    Controls.UnlockGovernmentsContainer:SetHide(true);
  elseif (iGoldBalance < iPolicyUnlockCost) then
    Controls.UnlockGovernmentsContainer:SetHide(false);
    Controls.UnlockGovernments:SetText(Locale.Lookup("LOC_GOVT_NEED_GOLD",iPolicyUnlockCost));
    Controls.UnlockGovernments:SetDisabled(true);
    AutoSizeGridButton(Controls.UnlockGovernments,150,41,20,"H");
    --Controls.UnlockGovernmentsContainer:SetSizeX(Controls.UnlockGovernments:GetSizeX() + 50);
  else
    Controls.UnlockGovernmentsContainer:SetHide(false);
    Controls.UnlockGovernments:SetText(Locale.Lookup("LOC_GOVT_UNLOCK_GOLD",iPolicyUnlockCost));
    Controls.UnlockGovernments:SetDisabled(false);
    AutoSizeGridButton(Controls.UnlockGovernments,150,41,20,"H");
    --Controls.UnlockGovernmentsContainer:SetSizeX(Controls.UnlockGovernments:GetSizeX() + 50);
  end

  pPlayerCulture:SetGovernmentChangeConsidered(true);
end


-- ===========================================================================
function RealizePoliciesPage()
  RealizeMyGovernmentPage();
  m_policyRowAnimData.initialSize = m_policyRowAnimData.desiredSize;
  m_policyRowAnimData.initialOffset = m_policyRowAnimData.desiredOffset;
  m_policyRowAnimData.desiredSize = m_SizeChoosePolicyRows;
  m_policyRowAnimData.desiredOffset = SIZE_POLICY_ROW_LARGE - m_SizeChoosePolicyRows;

  local isEditOn:boolean = IsAbleToChangePolicies();
  Controls.PolicyInputShield:SetDisabled( isEditOn );
  Controls.CatalogInputShield:SetHide( isEditOn );
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
     (m_kCurrentGovernment == nil or kPlayerCulture:CivicCompletedThisTurn()) then
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
    local szConfirmString;
    local iAnarchyTurns = kPlayerCulture:GetAnarchyTurns(eGovernmentType);

    if (iAnarchyTurns > 0 and eGovernmentType ~= -1) then
      szConfirmString = Locale.Lookup("LOC_GOVT_CONFIRM_ANARCHY", GameInfo.Governments[governmentType].Name, iAnarchyTurns);
      m_kPopupDialog:AddText(szConfirmString);
      m_kPopupDialog:AddButton(TXT_GOV_POPUP_YES, OnAcceptAnarchyChange);  
    else
      szConfirmString = TXT_GOV_CONFIRM_GOVERNMENT;
      m_kPopupDialog:AddText(szConfirmString);
      m_kPopupDialog:AddButton(TXT_GOV_POPUP_YES, OnAcceptGovernmentChange);  
    end   
    m_kPopupDialog:AddButton(TXT_GOV_POPUP_NO, OnCancelGovernmentChange, "cancel"); 
    m_kPopupDialog:Open();
    Controls.PopupInputBlocker:SetHide(false);

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
  local hash:number = m_kGovernments[m_governmentChangeType].Hash;
  if pPlayerCulture:RequestChangeGovernment( m_kGovernments[m_governmentChangeType].Hash ) then
    m_kCurrentGovernment = m_kGovernments[m_governmentChangeType];
    -- Update tabs and go to policies page.
    RealizeTabs();
    m_tabs.SelectTab( Controls.ButtonPolicies );
  end
  Controls.PopupInputBlocker:SetHide(true);
  m_governmentChangeType = "";
end

-- ===========================================================================
--  UI Callback
-- ===========================================================================
function OnAcceptAnarchyChange()
  UI.PlaySound("UI_Policies_Change_Government");

  local kPlayer   :table = Players[m_ePlayer];
  local kPlayerCulture:table = kPlayer:GetCulture();
  local hash:number = m_kGovernments[m_governmentChangeType].Hash;
  if kPlayerCulture:RequestChangeGovernment( m_kGovernments[m_governmentChangeType].Hash ) then
    m_kCurrentGovernment = nil;
  end
  -- Close screen
  Controls.PopupInputBlocker:SetHide(true);
  m_governmentChangeType = "";
  Close();
end

-- ===========================================================================
--  UI Callback
-- ===========================================================================
function OnCancelGovernmentChange()
  m_governmentChangeType = "";
  RealizeGovernmentsPage();
  Controls.PopupInputBlocker:SetHide(true); 
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
  local rows:table = {}-- , m_activeSlotRowData.Military, m_activeSlotRowData.Wildcard };
  rows[DROP_ROW_ID.DIPLOMATIC]= m_activeSlotRowData["k"..DROP_ROW_ID.DIPLOMATIC].Policies;
  rows[DROP_ROW_ID.ECONOMIC]  = m_activeSlotRowData["k"..DROP_ROW_ID.ECONOMIC].Policies;
  rows[DROP_ROW_ID.MILITARY]  = m_activeSlotRowData["k"..DROP_ROW_ID.MILITARY].Policies;
  rows[DROP_ROW_ID.WILDCARD]  = m_activeSlotRowData["k"..DROP_ROW_ID.WILDCARD].Policies;

  for id,row in ipairs(rows) do
    for policyType,policy in pairs(row) do
      local listInstance:table = {};
      ContextPtr:BuildInstanceForControl( "PolicyListItem", listInstance, Controls.PoliciesListStack );
      listInstance.Title:SetText( policy.Name );
      listInstance.Description:SetText( policy.Description );
      
      listInstance.TypeIcon:SetTexture( PICS_SLOT_TYPE_CARD_BGS[policy.SlotType]..PIC_CARD_SUFFIX_SMALL );
      local height:number = math.max( listInstance.TypeIcon:GetSizeY(), listInstance.Title:GetSizeY() + listInstance.Description:GetSizeY());
      height = height + PADDING_POLICY_LIST_ITEM;
      listInstance.Content:SetSizeY(height);
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
function RealizePolicyCard( cardInstance:table, policyType:string)
  local policy:table = m_kPolicyCatalogData[policyType];
  local cardName:string = m_debugShowPolicyIDs and tostring(policy.UniqueID).." " or "";
  cardName = cardName .. policy.Name;
  cardInstance.Title:SetText( cardName );
  local DescriptionContainerY = cardInstance.Background:GetSizeY() - cardInstance.Title:GetSizeY() -20;
  cardInstance.DescriptionContainer:SetSizeY(DescriptionContainerY);
  local text:string = policy.Description;
  cardInstance.Description:SetText(text);
  cardInstance.DescriptionGrid:ReprocessAnchoring();
  local slotType:string = policy.SlotType;
  cardInstance.Background:SetTexture( PICS_SLOT_TYPE_CARD_BGS[slotType] );
end


-- ===========================================================================
function RealizeTabs()
  
  if not m_tabs then
    m_tabs = CreateTabs( Controls.TabContainer, 42, 34, 0xFF331D05 );
  else
    m_tabs.tabControls = {};
  end

  Controls.ButtonPolicies:SetHide(m_kCurrentGovernment == nil);
  Controls.ButtonMyGovernment:SetHide(true);
  if m_kCurrentGovernment ~= nil then
    m_tabs.AddTab( Controls.ButtonMyGovernment, OnMyGovernmentClick );
    m_tabs.AddTab( Controls.ButtonPolicies,   OnPoliciesClick );
  end
  m_tabs.AddTab( Controls.ButtonGovernments,  OnGovernmentsClick );
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
  
  local createCard:boolean = false;

  m_policyCardIM:DestroyInstances();

  for _,policyType in pairs(m_kPolicyCatalogOrder) do

    local policy:table= m_kPolicyCatalogData[policyType];

    -- Policy unlocked check
    if( m_kUnlockedPolicies[policyType] and 
      -- Filter check 
      (m_kPolicyFilterCurrent == nil or
      m_kPolicyFilterCurrent.Func == nil or 
      m_kPolicyFilterCurrent.Func(policy)) and 
      -- Policy inactive check
      not IsPolicyTypeActive( policyType ) ) then
      
      local cardInstance:table = m_policyCardIM:GetInstance();
      cardInstance[KEY_POLICY_TYPE] = policyType;
      cardInstance.Draggable:RegisterCallback( Drag.eDown, function(dragStruct) OnDownFromCatalog(dragStruct, cardInstance); end );
      cardInstance.Draggable:RegisterCallback( Drag.eDrop, function(dragStruct) OnDropFromCatalog(dragStruct, cardInstance); end );
      cardInstance.Button:RegisterCallback( Mouse.eLDblClick, function() AddToNextAvailRow(cardInstance); end );
      cardInstance.Button:RegisterCallback( Mouse.eRClick, function() LuaEvents.OpenCivilopedia(policyType); end);
      cardInstance.NewIcon:SetHide(not m_kNewPoliciesThisTurn[policyType]);
      RealizePolicyCard( cardInstance, policyType );
    end
  end

  -- Add 3 blank cards to the end of the stack to add some spacing to the scroll area
  for i=1, 3 do
    local cardInstance:table = m_policyCardIM:GetInstance();
    cardInstance.Content:SetSizeX(PADDING_POLICY_SCROLL_AREA);
    cardInstance.Content:SetAlpha(0);
  end

  Controls.PolicyCatalog:CalculateSize();
  Controls.PolicyCatalog:ReprocessAnchoring();
  Controls.PolicyCatalog:SetSizeX(Controls.PolicyCatalog:GetSizeX() + 100);

  Controls.PolicyScroller:CalculateInternalSize();
  Controls.PolicyScroller:ReprocessAnchoring();
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
function RealizeDragAndDropRows( rowSlotType:string )
  -- LUA cascade boolean logic to turn slots a darker color if the dragged type
  -- doesn't support the row or if the row doesn't have any more room in it.

  local hasWildcardSlots:boolean = #m_activeSlotRowData["k"..DROP_ROW_ID.WILDCARD].GameCoreSlotIndexes > 0;

  Controls.MilitaryBlocker:SetHide(
    ((rowSlotType == "SLOT_MILITARY") and
    (#m_activeSlotRowData["k"..DROP_ROW_ID.MILITARY].GameCoreSlotIndexes > 0)) or 
    (hasWildcardSlots and (m_isAllowWildcardsAnywhere and rowSlotType == "SLOT_WILDCARD")));
  
  Controls.DiplomaticBlocker:SetHide(
    (((rowSlotType == "SLOT_DIPLOMATIC") and 
    (#m_activeSlotRowData["k"..DROP_ROW_ID.DIPLOMATIC].GameCoreSlotIndexes > 0))) or
    (hasWildcardSlots and (m_isAllowWildcardsAnywhere and rowSlotType == "SLOT_WILDCARD")));

  Controls.EconomicBlocker:SetHide(
    (((rowSlotType == "SLOT_ECONOMIC") and 
    (#m_activeSlotRowData["k"..DROP_ROW_ID.ECONOMIC].GameCoreSlotIndexes > 0))) or
    (hasWildcardSlots and (m_isAllowWildcardsAnywhere and rowSlotType == "SLOT_WILDCARD")));

  Controls.WildcardBlocker:SetHide(
    hasWildcardSlots and (
    (m_isAllowWildcardsAnywhere and rowSlotType == "SLOT_WILDCARD") or
    (m_isAllowAnythingInWildcardSlot or rowSlotType == "SLOT_WILDCARD")));
end

function MovePolicyItemToTop(item:table)
  if Controls.RowAnim:GetProgress() < 1 then return; end
  local parent:table = item:GetParent();
  local parentID:string = "Top" .. parent:GetID();
  local newParent:table = Controls[parentID];
  if newParent then
    item:ChangeParent(newParent);
  else
    print("Failed to change parent of " .. item:GetID() .. " to " .. parentID);
  end
end
function MovePolicyItemToStack(item:table)
  if Controls.RowAnim:GetProgress() < 1 then return; end
  local parent:table = item:GetParent();
  local parentID:string = parent:GetID():gsub("Top", "");
  local newParent:table = Controls[parentID];
  if newParent then
    item:ChangeParent(newParent);
  else
    print("Failed to change parent of " .. item:GetID() .. " to " .. parentID);
  end
end

-- ===========================================================================
--  Show how many policy cards can be dropped onto rows
-- ===========================================================================
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

  -- Destroy any cards currently sitting in the rows
  -- WARNING: Call this while a snap-back is occuring will lock.
  Controls.StackDiplomatic:DestroyAllChildren();
  Controls.TopStackDiplomatic:DestroyAllChildren();
  Controls.StackEconomic:DestroyAllChildren();
  Controls.TopStackEconomic:DestroyAllChildren();
  Controls.StackMilitary:DestroyAllChildren();
  Controls.TopStackMilitary:DestroyAllChildren();
  Controls.StackWildcard:DestroyAllChildren();
  Controls.TopStackWildcard:DestroyAllChildren();

  -- Build cards in the rows (one of the few places rows does not mean DB rows, but visual "rows" of beautiful felt.)
  local rows:table = {};
  rows[DROP_ROW_ID.DIPLOMATIC]= m_activeSlotRowData["k"..DROP_ROW_ID.DIPLOMATIC].GameCoreSlotIndexes;
  rows[DROP_ROW_ID.ECONOMIC]  = m_activeSlotRowData["k"..DROP_ROW_ID.ECONOMIC].GameCoreSlotIndexes;
  rows[DROP_ROW_ID.MILITARY]  = m_activeSlotRowData["k"..DROP_ROW_ID.MILITARY].GameCoreSlotIndexes;
  rows[DROP_ROW_ID.WILDCARD]  = m_activeSlotRowData["k"..DROP_ROW_ID.WILDCARD].GameCoreSlotIndexes;

  m_uiActivePolicies = {};  -- Empty policies; will be rebuilt below.
  for id,slotDatas in ipairs(rows) do
    local stackControl:table = nil;
    if id == DROP_ROW_ID.DIPLOMATIC then stackControl = Controls.StackDiplomatic; end
    if id == DROP_ROW_ID.ECONOMIC then stackControl = Controls.StackEconomic; end
    if id == DROP_ROW_ID.MILITARY then stackControl = Controls.StackMilitary; end
    if id == DROP_ROW_ID.WILDCARD then stackControl = Controls.StackWildcard; end

    for _,slotData in ipairs(slotDatas) do
      local policyType:string = slotData.PolicyType;
      if policyType ~= EMPTY_POLICY_TYPE then
        local cardInstance:table = {};
        ContextPtr:BuildInstanceForControl( "PolicyCard", cardInstance, stackControl );
        RealizePolicyCard( cardInstance, policyType );
        cardInstance.CardContainer:SetHide(true);
        cardInstance.Draggable:RegisterCallback( Drag.eDown, function(dragStruct) OnDownFromRow(dragStruct, cardInstance ); end );
        cardInstance.Draggable:RegisterCallback( Drag.eDrop, function(dragStruct) OnDropFromRow(dragStruct, cardInstance ); end );
        cardInstance[KEY_ROW_ID] = id;          -- Link the row # with where this card is at (for drag out situations)
        cardInstance[KEY_POLICY_TYPE] = policyType;   -- Link the type of data this card instance is tied to
        cardInstance.Button:RegisterMouseEnterCallback(function() MovePolicyItemToTop(cardInstance.Content); end);
        cardInstance.Button:RegisterMouseExitCallback(function() MovePolicyItemToStack(cardInstance.Content); end);
        cardInstance.Button:RegisterCallback(Mouse.eLDblClick, function() RemoveFromRow( cardInstance ); RealizePolicyCatalog(); RealizeActivePoliciesRows(); end );  -- Double click will instant remove
        cardInstance.Button:RegisterCallback(Mouse.eRClick, function()    RemoveFromRow( cardInstance ); RealizePolicyCatalog(); RealizeActivePoliciesRows(); end );  -- ...as will right click.
        table.insert(m_uiActivePolicies, cardInstance);
      end
    end
  end

  PopulateAvailableIcons(DROP_ROW_ID.DIPLOMATIC, PIC_CARD_TYPE_DIPLOMACY, Controls.StackDiplomatic);
  PopulateAvailableIcons(DROP_ROW_ID.ECONOMIC, PIC_CARD_TYPE_ECONOMIC, Controls.StackEconomic);
  PopulateAvailableIcons(DROP_ROW_ID.MILITARY, PIC_CARD_TYPE_MILITARY, Controls.StackMilitary);
  PopulateAvailableIcons(DROP_ROW_ID.WILDCARD, PIC_CARD_TYPE_WILDCARD, Controls.StackWildcard);

  RealizeActivePolicyRowSize();

  -- Total policies that can be put into this category row
  m_hasDiplomacySlots = m_activeSlotRowData["k"..DROP_ROW_ID.DIPLOMATIC].Max ~= 0;
  m_hasEconomicSlots  = m_activeSlotRowData["k"..DROP_ROW_ID.ECONOMIC].Max ~= 0;
  m_hasMilitarySlots  = m_activeSlotRowData["k"..DROP_ROW_ID.MILITARY].Max ~= 0;
  m_hasWildcardSlots  = m_activeSlotRowData["k"..DROP_ROW_ID.WILDCARD].Max ~= 0;

  Controls.DiplomacyLabelLeft:SetText(  ToSlotAmtString(m_activeSlotRowData["k"..DROP_ROW_ID.DIPLOMATIC].Max) );
  Controls.EconomicLabelLeft:SetText(   ToSlotAmtString(m_activeSlotRowData["k"..DROP_ROW_ID.ECONOMIC].Max) );
  Controls.MilitaryLabelLeft:SetText(   ToSlotAmtString(m_activeSlotRowData["k"..DROP_ROW_ID.MILITARY].Max) );
  Controls.WildcardLabelLeft:SetText(   ToSlotAmtString(m_activeSlotRowData["k"..DROP_ROW_ID.WILDCARD].Max) );

  -- Remaining policies that can be placed into this category row
  if (m_hasDiplomacySlots) then
    Controls.DiplomacyLabelRight:SetText( ToSlotAmtString(m_activeSlotRowData["k"..DROP_ROW_ID.DIPLOMATIC].Avail) );
    Controls.DiplomacyCounter:SetColorByName("Black");
    Controls.DiplomacyLabelRight:SetHide(false);
    Controls.DiplomacyLabelLeft:SetHide(false);
    Controls.DiplomaticEmpty:SetHide(true);
  else
    Controls.DiplomacyCounter:SetColorByName("Clear");
    Controls.DiplomacyLabelRight:SetHide(true);
    Controls.DiplomacyLabelLeft:SetHide(true);
    Controls.DiplomaticEmpty:SetHide(false);
  end
  if (m_hasEconomicSlots) then
    Controls.EconomicLabelRight:SetText(  ToSlotAmtString(m_activeSlotRowData["k"..DROP_ROW_ID.ECONOMIC].Avail) );
    Controls.EconomicCounter:SetColorByName("Black");
    Controls.EconomicLabelRight:SetHide(false);
    Controls.EconomicLabelLeft:SetHide(false);
    Controls.EconomicEmpty:SetHide(true);
  else
    Controls.EconomicCounter:SetColorByName("Clear");
    Controls.EconomicLabelRight:SetHide(true);
    Controls.EconomicLabelLeft:SetHide(true);
    Controls.EconomicEmpty:SetHide(false);
  end
  if (m_hasMilitarySlots) then
    Controls.MilitaryLabelRight:SetText(  ToSlotAmtString(m_activeSlotRowData["k"..DROP_ROW_ID.MILITARY].Avail) );
    Controls.MilitaryCounter:SetColorByName("Black");
    Controls.MilitaryLabelRight:SetHide(false);
    Controls.MilitaryLabelLeft:SetHide(false);
    Controls.MilitaryEmpty:SetHide(true);
  else
    Controls.MilitaryCounter:SetColorByName("Clear");
    Controls.MilitaryLabelRight:SetHide(true);
    Controls.MilitaryLabelLeft:SetHide(true);
    Controls.MilitaryEmpty:SetHide(false);
  end
  if (m_hasWildcardSlots) then
    Controls.WildcardLabelRight:SetText(  ToSlotAmtString(m_activeSlotRowData["k"..DROP_ROW_ID.WILDCARD].Avail) );
    Controls.WildcardCounter:SetColorByName("Black");
    Controls.WildcardLabelRight:SetHide(false);
    Controls.WildcardLabelLeft:SetHide(false);
    Controls.WildcardEmpty:SetHide(true);
  else
    Controls.WildcardCounter:SetColorByName("Clear");
    Controls.WildcardLabelRight:SetHide(true);
    Controls.WildcardLabelLeft:SetHide(true);
    Controls.WildcardEmpty:SetHide(false);
  end


  Controls.DiplomacyIconRing:SetHide(m_activeSlotRowData["k"..DROP_ROW_ID.DIPLOMATIC].Avail <= 0);
  Controls.EconomicIconRing:SetHide(m_activeSlotRowData["k"..DROP_ROW_ID.ECONOMIC].Avail <= 0);
  Controls.MilitaryIconRing:SetHide(m_activeSlotRowData["k"..DROP_ROW_ID.MILITARY].Avail <= 0);
  Controls.WildcardIconRing:SetHide(m_activeSlotRowData["k"..DROP_ROW_ID.WILDCARD].Avail <= 0);

  -- Tooltips
  Controls.DiplomacyIconLeft:SetToolTipString(  ToSlotAmtTotalTooltipString( m_activeSlotRowData["k"..DROP_ROW_ID.DIPLOMATIC].Max, "LOC_GOVT_POLICY_TYPE_DIPLOMATIC" ) );
  Controls.EconomicIconLeft:SetToolTipString(   ToSlotAmtTotalTooltipString( m_activeSlotRowData["k"..DROP_ROW_ID.ECONOMIC].Max, "LOC_GOVT_POLICY_TYPE_ECONOMIC" ) );
  Controls.MilitaryIconLeft:SetToolTipString(   ToSlotAmtTotalTooltipString( m_activeSlotRowData["k"..DROP_ROW_ID.MILITARY].Max, "LOC_GOVT_POLICY_TYPE_MILITARY" ) );
  Controls.WildcardIconLeft:SetToolTipString(   ToSlotAmtTotalTooltipString( m_activeSlotRowData["k"..DROP_ROW_ID.WILDCARD].Max, "LOC_GOVT_POLICY_TYPE_WILDCARD" ) );
  Controls.DiplomacyLabelRight:SetToolTipString(  ToSlotAmtRemainingTooltipString( m_activeSlotRowData["k"..DROP_ROW_ID.DIPLOMATIC].Avail, "LOC_GOVT_POLICY_TYPE_DIPLOMATIC" ) );
  Controls.EconomicLabelRight:SetToolTipString( ToSlotAmtRemainingTooltipString( m_activeSlotRowData["k"..DROP_ROW_ID.ECONOMIC].Avail, "LOC_GOVT_POLICY_TYPE_ECONOMIC" ) );
  Controls.MilitaryLabelRight:SetToolTipString( ToSlotAmtRemainingTooltipString( m_activeSlotRowData["k"..DROP_ROW_ID.MILITARY].Avail, "LOC_GOVT_POLICY_TYPE_MILITARY" ) );
  Controls.WildcardLabelRight:SetToolTipString( ToSlotAmtRemainingTooltipString( m_activeSlotRowData["k"..DROP_ROW_ID.WILDCARD].Avail, "LOC_GOVT_POLICY_TYPE_WILDCARD" ) );

  local playerCulture:table = Players[Game.GetLocalPlayer()]:GetCulture();
  local playerTreasury:table = Players[Game.GetLocalPlayer()]:GetTreasury();
  local bPoliciesChanged = playerCulture:PolicyChangeMade();
  local iPolicyUnlockCost = playerCulture:GetCostToUnlockPolicies();
  local iGoldBalance = playerTreasury:GetGoldBalance();

  -- Update states for Unlock and Confirm buttons at bottom of screen
  if (bPoliciesChanged == true) then
    Controls.ConfirmPolicies:SetHide(true);
    Controls.UnlockPolicies:SetHide(true);  
  elseif (iPolicyUnlockCost == 0) then
    Controls.ConfirmPolicies:SetHide(false);
    Controls.UnlockPolicies:SetHide(true);
    
    local iSlotsOpen = m_activeSlotRowData["k"..DROP_ROW_ID.DIPLOMATIC].Avail + m_activeSlotRowData["k"..DROP_ROW_ID.ECONOMIC].Avail +
               m_activeSlotRowData["k"..DROP_ROW_ID.MILITARY].Avail + m_activeSlotRowData["k"..DROP_ROW_ID.WILDCARD].Avail;
    
    if(not m_isPoliciesChanged or iSlotsOpen > 0) then
      Controls.ConfirmPolicies:SetDisabled(true);
      Controls.ConfirmPolicies:SetText(TXT_GOV_ASSIGN_POLICIES);
    else
      Controls.ConfirmPolicies:SetDisabled(false);
      Controls.ConfirmPolicies:SetText(TXT_GOV_CONFIRM_POLICIES);
    end
  elseif (iGoldBalance < iPolicyUnlockCost) then
    Controls.ConfirmPolicies:SetHide(true);
    Controls.UnlockPolicies:SetHide(false);
    Controls.UnlockPolicies:SetText(Locale.Lookup("LOC_GOVT_NEED_GOLD", iPolicyUnlockCost));
    Controls.UnlockPolicies:SetDisabled(true);
  else
    Controls.ConfirmPolicies:SetHide(true);
    Controls.UnlockPolicies:SetHide(false);
    Controls.UnlockPolicies:SetText(Locale.Lookup("LOC_GOVT_UNLOCK_GOLD", iPolicyUnlockCost));
    Controls.UnlockPolicies:SetDisabled(false);
  end
end

function RealizeActivePolicyRowSize()
  Controls.RowMilitary:ReprocessAnchoring();
  Controls.RowEconomic:ReprocessAnchoring();
  Controls.RowDiplomatic:ReprocessAnchoring();
  Controls.RowWildcard:ReprocessAnchoring();

  EnsureContentsFit(Controls.StackMilitary);
  EnsureContentsFit(Controls.StackEconomic);
  EnsureContentsFit(Controls.StackDiplomatic);
  EnsureContentsFit(Controls.StackWildcard);
end

function EnsureContentsFit(stack:table)

  local width:number = stack:GetSizeX();
  local numItems:number = stack:GetNumChildren();
  local itemPadding:number = (numItems - 1) * PADDING_POLICY_ROW_ITEM;
  local totalSize:number = (SIZE_POLICY_CARD_X * numItems) + (itemPadding > 0 and itemPadding or 0);
  local nextX:number = (width / 2) - (totalSize / 2);
  local step:number = SIZE_POLICY_CARD_X + PADDING_POLICY_ROW_ITEM;

  -- Make items overlap if they don't fit in the stack
  if(numItems > 0 and totalSize > width) then
    nextX = 0;
    local itemOverlap:number = (totalSize - width) / (numItems - 1);
    step = SIZE_POLICY_CARD_X - itemOverlap;
  end
  
  local items:table = stack:GetChildren();
  for i:number=1, numItems do
    local child:table = items[i];
    child:SetOffsetX(nextX);
    nextX = nextX + step;
  end
end

-- ===========================================================================
function PopulateAvailableIcons(rowID:number, pictureType:string, stackControl:table) 
  for i=1,m_activeSlotRowData["k"..rowID].Avail do 
    local slotIconInstance:table = {};
    ContextPtr:BuildInstanceForControl("EmptyCard", slotIconInstance, stackControl);
    slotIconInstance.DragPolicyLabel:SetHide(m_tabs.selectedControl == Controls.ButtonMyGovernment);
    slotIconInstance.TypeIcon:SetTexture(pictureType.."_Empty");
  end
end

-- ===========================================================================
--  Main close function all exit points should call.
-- ===========================================================================
function Close()
  
  if Controls.ConfirmPolicies:IsHidden() == false and Controls.ConfirmPolicies:IsDisabled() == false then
    -- Policies confirmation button is enabled (and showing); warn player changes are not saved!
    m_kPopupDialog:AddText(TXT_GOV_POPUP_PROMPT_POLICIES_CLOSE);
    m_kPopupDialog:AddButton(TXT_GOV_POPUP_YES, function() Controls.ConfirmPolicies:SetDisabled(true); Close() end ); -- Set to disabled and call close again.
    m_kPopupDialog:AddButton(TXT_GOV_POPUP_NO,  function() Controls.PopupInputBlocker:SetHide(true); end, "cancel" );
    m_kPopupDialog:Open();
    Controls.PopupInputBlocker:SetHide(false);
  else
    -- Actual close
    UI.PlaySound("UI_Screen_Close");
    ContextPtr:SetHide(true);
    m_governmentChangeType  = "";
    m_isPoliciesChanged   = false;
    LuaEvents.Government_CloseGovernment();
    Controls.PopupInputBlocker:SetHide(true);     
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

    local clearList = {};   -- table of slots to clear
    local addList = {};     -- table of policies to add, keyed by the slot index

    -- Build the clear list
    -- (A clear first is required for the case of moving a slotted policy from one row to another or the engine will deny the change.)
    for idk:string,slotRow:table in pairs(m_activeSlotRowData) do -- id w/ k    
      for _,value in pairs(slotRow.GameCoreSlotIndexes) do
        table.insert(clearList, value.SlotIndex);
      end
    end

    -- Build the add list
    for idk:string,slotRow:table in pairs(m_activeSlotRowData) do -- id w/ k
      for policyType, policy in pairs(slotRow.Policies) do
        local hash:number = policy.PolicyHash;
        for _,value in pairs(slotRow.GameCoreSlotIndexes) do
          if value.PolicyType == policyType then
            addList[value.SlotIndex] = hash;
          end
        end     
      end 
  
    end

    pPlayerCulture:RequestPolicyChanges(clearList, addList);

    m_isPoliciesChanged = false;
    Controls.PopupInputBlocker:SetHide(true);
    Controls.ConfirmPolicies:SetDisabled( true );
    Close();
  end

  function OnConfirmPolicies_No()
    Controls.PopupInputBlocker:SetHide(true);
  end
  
  m_kPopupDialog:AddText(TXT_GOV_POPUP_PROMPT_POLICIES_CONFIRM);
  m_kPopupDialog:AddButton(TXT_GOV_POPUP_YES, OnConfirmPolicies_Yes );
  m_kPopupDialog:AddButton(TXT_GOV_POPUP_NO,  OnConfirmPolicies_No, "cancel" );
  m_kPopupDialog:Open();
  Controls.PopupInputBlocker:SetHide(false);
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
  if not m_kCurrentGovernment then
    OnOpenGovernmentScreenGovernments();
  else
    OnOpenGovernmentScreen( SCREEN_ENUMS.POLICIES );
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
  OnOpenGovernmentScreen( SCREEN_ENUMS.POLICIES );
end


-- ===========================================================================
--  LUA Event / DEPRECATED To be called directly (use an open that references the specific screen to see)
--  Called to first open the page.
-- ===========================================================================
function OnOpenGovernmentScreen( screenEnum:number )
  if m_ePlayer ~= -1 then

    UI.PlaySound("UI_Screen_Open");
    ContextPtr:SetHide(false);

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
        screenEnum = SCREEN_ENUMS.SCREEN_ENUMS.POLICIES;
      end
    end

    if screenEnum == SCREEN_ENUMS.MY_GOVERNMENT then 
      m_tabs.SelectTab( Controls.ButtonMyGovernment );
    elseif screenEnum == SCREEN_ENUMS.GOVERNMENTS   then 
      m_tabs.SelectTab( Controls.ButtonGovernments );
    else 
      m_tabs.SelectTab( Controls.ButtonPolicies );
    end
    LuaEvents.Government_OpenGovernment();
  end
end


-- ===========================================================================
--  Switch to My Government "tab" area
-- ===========================================================================
function OnMyGovernmentClick()

  local isPlayingAnimation:boolean = true;
  if m_tabs.prevSelectedControl == Controls.ButtonGovernments then
    Controls.SelectGovernments:SetHide( true );
    Controls.PolicyPanelGrid:SetHide( true );
  elseif m_tabs.prevSelectedControl == Controls.ButtonPolicies then
    Controls.SelectPolicies:SetHide( true );
  elseif m_tabs.prevSelectedControl == nil then
    -- Do nothing, initial call.
  else
    isPlayingAnimation = false; -- This tab, already on it.
  end
  
  if isPlayingAnimation then

    Controls.SelectMyGovernment:SetHide( false );
    Controls.SelectMyGovernment:SetToBeginning();
    Controls.SelectMyGovernment:Play();
    UI.PlaySound("UI_Page_Turn");

    -- Fade
    local progress    :number = Controls.AlphaAnim:GetProgress();
    local isReversing :boolean = Controls.AlphaAnim:IsReversing();
    if Controls.AlphaAnim:IsStopped() then
      if progress == 0 or (isReversing and progress==1) then
        -- At start ; do nothing
      else
        -- At end
        Controls.AlphaAnim:Reverse();
      end
    else
      -- Moving, which way? 
      if isReversing then
        -- Moving to start; do nothing
      else
        -- Moving to end
        Controls.AlphaAnim:Reverse();
      end
    end

    -- Move: to start of animation
    progress  = Controls.RowAnim:GetProgress();
    isReversing = Controls.RowAnim:IsReversing();
    if Controls.RowAnim:IsStopped() then
      if (progress == 1 and not isReversing) then
        Controls.RowAnim:Reverse();
      end
    else
      if not isReversing then
        Controls.RowAnim:Reverse();
      end
    end

    -- Government tree fade
    progress  = Controls.GovernmentTree:GetProgress();
    isReversing = Controls.GovernmentTree:IsReversing();
    if Controls.GovernmentTree:IsStopped() then
      if progress == 0 or (isReversing and progress==1) then
        -- At start ; do nothing
      else
        -- At end
        Controls.GovernmentTree:Reverse();
      end
    else
      -- Moving, which way? 
      if isReversing then
        -- Moving to start; do nothing
      else
        -- Moving to end
        Controls.GovernmentTree:Reverse();
      end
    end

    Controls.PolicyInputShield:SetDisabled(false);  -- Block moving policies around
    Controls.MyGovernment:SetHide(false);
    Controls.PolicyCatalog:SetHide(true);
    Controls.PolicyRows:SetHide(false);
    Controls.PoliciesContainer:SetHide(true);
    Controls.CategoryIconsLeft:SetHide(false);
    Controls.MilitaryCounter:SetHide(true);
    Controls.EconomicCounter:SetHide(true);
    Controls.DiplomacyCounter:SetHide(true);
    Controls.WildcardCounter:SetHide(true);
  end

  RealizeMyGovernmentPage();
end


-- ===========================================================================
--  Switch to goverment "tab" area
-- ===========================================================================
function OnGovernmentsClick()

  local isPlayingAnimation:boolean = true;
    local isInitialReload:boolean = false;
  if m_tabs.prevSelectedControl == Controls.ButtonMyGovernment then
    Controls.SelectMyGovernment:SetHide( true );
  elseif m_tabs.prevSelectedControl == Controls.ButtonPolicies then
    Controls.SelectPolicies:SetHide( true );
  elseif m_tabs.prevSelectedControl == nil then
        isInitialReload = true;
    -- Do nothing, initial/reload call.
    else
    isPlayingAnimation = false; -- This tab, already on it.
  end
  
  if isPlayingAnimation then
  
    Controls.GovernmentTree:SetHide(false);
    Controls.GovernmentTree:SetToBeginning();
    Controls.GovernmentTree:Play();

        if not isInitialReload then
            UI.PlaySound("UI_Page_Turn");
        end

    Controls.SelectGovernments:SetHide( false );
    Controls.SelectGovernments:SetToBeginning();
    Controls.SelectGovernments:Play();
    Controls.PolicyPanelGrid:SetHide( false );

    -- Fade
    local progress    :number = Controls.AlphaAnim:GetProgress();
    local isReversing :boolean = Controls.AlphaAnim:IsReversing();
    if Controls.AlphaAnim:IsStopped() then
      if progress == 0 or (isReversing and progress==1) then
        -- At start
        Controls.AlphaAnim:SetToBeginning();
        Controls.AlphaAnim:Play();
      else
        -- At end; do nothing
      end
    else
      -- Moving, which way? 
      if isReversing then
        -- Moving to start, flip it to move back to end.
        Controls.AlphaAnim:Reverse();
      else
        -- Moving to end; let it play out.      
      end
    end

    Controls.PolicyInputShield:SetDisabled(false);    -- Block moving policies around 
  end

  Controls.GovernmentTree:SetHide( false );
  Controls.PoliciesContainer:SetHide(true);

  RealizeGovernmentsPage();
end


-- ===========================================================================
--  Switch to policies "tab" area
-- ===========================================================================
function OnPoliciesClick()

  local isPlayingAnimation:boolean = true;
  if m_tabs.prevSelectedControl == Controls.ButtonMyGovernment then
    Controls.SelectMyGovernment:SetHide( true );
  elseif m_tabs.prevSelectedControl == Controls.ButtonGovernments then
    Controls.SelectGovernments:SetHide( true );
    Controls.PolicyPanelGrid:SetHide( true );
  elseif m_tabs.prevSelectedControl == nil then
    -- Do nothing, initial/reload call.
  else
    isPlayingAnimation = false; -- This tab, already on it.
  end

  if isPlayingAnimation then

    Controls.SelectPolicies:SetHide( false );
    Controls.SelectPolicies:SetToBeginning();
    Controls.SelectPolicies:Play();
    UI.PlaySound("UI_Page_Turn");
  
    -- Fade
    local progress    :number = Controls.AlphaAnim:GetProgress();
    local isReversing :boolean = Controls.AlphaAnim:IsReversing();
    if Controls.AlphaAnim:IsStopped() then
      if progress == 0 or (isReversing and progress==1) then
        -- At start ; do nothing
      else
        -- At end
        Controls.AlphaAnim:SetToEnd();
        Controls.AlphaAnim:Reverse();
      end
    else
      -- Moving, which way? 
      if isReversing then
        -- Moving to start; do nothing
      else
        -- Moving to end
        Controls.AlphaAnim:Reverse();
      end
    end

    -- Move: to start of animation
    progress  = Controls.RowAnim:GetProgress();
    isReversing = Controls.RowAnim:IsReversing();
    if Controls.RowAnim:IsStopped() then
      if progress == 0 or (progress == 1 and isReversing) then
        Controls.RowAnim:SetToBeginning();
        Controls.RowAnim:Play();
      end
    else
      if isReversing then
        Controls.RowAnim:Reverse();
      end
    end

    -- Government tree fade
    progress  = Controls.GovernmentTree:GetProgress();
    isReversing = Controls.GovernmentTree:IsReversing();
    if Controls.GovernmentTree:IsStopped() then
      if progress == 0 or (isReversing and progress==1) then
        -- At start ; do nothing
      else
        -- At end
        Controls.GovernmentTree:Reverse();
      end
    else
      -- Moving, which way? 
      if isReversing then
        -- Moving to start; do nothing
      else
        -- Moving to end
        Controls.GovernmentTree:Reverse();
      end
    end

    if(m_showGovernmentInPolicySelect) then
      Controls.MyGovernment:SetHide(false);
    else
      Controls.MyGovernment:SetHide(true);
    end
    Controls.CategoryIconsLeft:SetHide(true);
    Controls.PoliciesContainer:SetHide(false);
    Controls.PolicyCatalog:SetHide(false);
    Controls.PolicyRows:SetHide(false); 
    Controls.MilitaryCounter:SetHide(false);
    Controls.EconomicCounter:SetHide(false);
    Controls.DiplomacyCounter:SetHide(false);
    Controls.WildcardCounter:SetHide(false);
  end

  RealizePoliciesPage();

  LuaEvents.GovernmentScreen_PolicyTabOpen();
end


-- ===========================================================================
--  
-- ===========================================================================
function RefreshAllData()
  PopulateLivePlayerData( m_ePlayer );
  RealizeTabs();

  -- From ModalScreen_PlayerYieldsHelper
  RefreshYields();
end


-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnGovernmentChanged( playerID:number )
  if playerID == m_ePlayer and m_ePlayer ~= -1 then
    RefreshAllData();
    if m_kCurrentGovernment ~= nil then
      RealizeMyGovernmentPage();
      RealizeGovernmentsPage();
      RealizePoliciesPage();
    elseif not ContextPtr:IsHidden() then
      Close();
    end
  end
end


-- ===========================================================================
--  Game Engine Event
-- ===========================================================================
function OnGovernmentPolicyChanged( playerID:number )
  if playerID == m_ePlayer then
    RefreshAllData();
    RealizeMyGovernmentPage();
    RealizeGovernmentsPage();
    RealizePoliciesPage();
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
  end
end


-- ===========================================================================
--  Allocations that can be made upfront and only need to be done once.
-- ===========================================================================
function AllocateUI()

  -- Popup setup  
  m_kPopupDialog = PopupDialogLogic:new( "GovernmentScreen", Controls.PopupDialog, Controls.PopupStack );
  m_kPopupDialog:SetInstanceNames( "PopupButtonInstance", "Button", "PopupTextInstance", "Text", "RowInstance", "Row");
  m_kPopupDialog:SetOpenAnimationControls( Controls.PopupAlphaIn, Controls.PopupSlideIn );  
  m_kPopupDialog:SetSize(400,200);

  -- Setup drag and drop
  SetDropOverlap( DROP_OVERLAP_REQUIRED );  
  BuildPolicyDropRow( Controls.RowMilitary, DROP_ROW_ID.MILITARY, "LOC_GOVT_POLICY_TYPE_MILITARY")  
  BuildPolicyDropRow( Controls.RowEconomic, DROP_ROW_ID.ECONOMIC, "LOC_GOVT_POLICY_TYPE_ECONOMIC");
  BuildPolicyDropRow( Controls.RowDiplomatic, DROP_ROW_ID.DIPLOMATIC, "LOC_GOVT_POLICY_TYPE_DIPLOMATIC");
  BuildPolicyDropRow( Controls.RowWildcard, DROP_ROW_ID.WILDCARD, "LOC_GOVT_POLICY_TYPE_WILDCARD");

  Controls.LabelMilitary:SetText(Locale.Lookup("{LOC_GOVT_POLICY_TYPE_MILITARY:upper}"));
  Controls.LabelEconomic:SetText(Locale.Lookup("{LOC_GOVT_POLICY_TYPE_ECONOMIC:upper}"));
  Controls.LabelDiplomatic:SetText(Locale.Lookup("{LOC_GOVT_POLICY_TYPE_DIPLOMATIC:upper}"));
  Controls.LabelWildcard:SetText(Locale.Lookup("{LOC_GOVT_POLICY_TYPE_WILDCARD:upper}"));
end


-- ===========================================================================
--  
-- ===========================================================================
function BuildPolicyDropRow( control:table, num:number, label:string )
  AddDropArea( control, num, m_kDropAreasPolicyRows );
end


-- ===========================================================================
--
-- ===========================================================================
function OnDownFromCatalog( dragStruct:table, cardInstance:table )

  local policy    :table = m_kPolicyCatalogData[ cardInstance[KEY_POLICY_TYPE] ];
  local rowSlotType :string = policy.SlotType;
  if rowSlotType == "SLOT_GREAT_PERSON" then rowSlotType = "SLOT_WILDCARD"; end   -- Treat great people like wildcards.

  cardInstance.Shadow:SetHide(false);
  UI.PlaySound("UI_Policies_Card_Take");

  RealizeDragAndDropRows( rowSlotType )
end


-- ===========================================================================
--  Dropping a car from the policy catalog
--  Find the data type from the dropped card and add it to the corresponding
--  row table.  When the table is realized, it will create a card for that type.
-- ===========================================================================
function OnDropFromCatalog( dragStruct:table, cardInstance:table )  

  local dragControl:table     = dragStruct:GetControl();
  local x:number,y:number     = dragControl:GetScreenOffset();
  local width:number,height:number= dragControl:GetSizeVal();
  local dropArea:DropAreaStruct = GetDropArea(x,y,width,height,m_kDropAreasPolicyRows);

  cardInstance.Shadow:SetHide(true);
  UI.PlaySound("UI_Policies_Card_Drop");

  -- Was a valid drop site available?
  if dropArea ~= nil then
    local dropControl :table  = dropArea.control;
    local policyType  :string = cardInstance[KEY_POLICY_TYPE];
    local policy    :table  = m_kPolicyCatalogData[ policyType ];
    local rowSlotType :string = policy.SlotType;
    local isSwapped   :boolean = false;

    if rowSlotType == "SLOT_GREAT_PERSON" then rowSlotType = "SLOT_WILDCARD"; end   -- Treat great people like wildcards.

    -- If no slots are avaiable, look to swap (remove this IF check if always want to swap if a card is over another)
    if m_activeSlotRowData["k"..dropArea.id].Avail < 1 then

      -- First check if drop is on a specific card and if so, swap it out...          
      for _,existingCardInstance in pairs(m_uiActivePolicies) do
        if IsDragAndDropOverlapped( dragControl, existingCardInstance.Content, PERCENT_OVERLAP_TO_SWAP) then
          local existingPolicyType:string = existingCardInstance[KEY_POLICY_TYPE];
          local existingPolicy  :table = m_kPolicyCatalogData[existingPolicyType];

          -- Can card swap here?
          if  DROP_ROW_SLOT_TYPES[dropArea.id] == rowSlotType or 
            (m_isAllowWildcardsAnywhere and rowSlotType == "SLOT_WILDCARD") or
            (m_isAllowAnythingInWildcardSlot and DROP_ROW_SLOT_TYPES[dropArea.id] == "SLOT_WILDCARD")       
          then
            -- Swap policy type in the slot index collection
            for _, slotData in pairs(m_activeSlotRowData["k"..dropArea.id].GameCoreSlotIndexes) do
              if slotData.PolicyType == existingPolicyType then
                slotData.PolicyType = policyType; 
                m_activeSlotRowData["k"..dropArea.id].Policies[existingPolicyType] = nil;
                m_activeSlotRowData["k"..dropArea.id].Policies[policyType] = policy;
                isSwapped = true;
                break;
              end
            end             
          end
        end
        if isSwapped then break; end  -- If a swap occurred, leave outer loop; work here is done.
      end
    end

    local isDropped:boolean = false;
    if isSwapped then
      isDropped = true; -- If swapped, consider this dropped.
    else
      -- Determine the slot and it's availablity to receive a drop:     
      if AddToRowIfMatch(rowSlotType, dropArea.id, policyType) then
        isDropped = true;
      elseif m_isAllowAnythingInWildcardSlot and AddToRowIfMatch("SLOT_WILDCARD", dropArea.id, policyType) then -- Fake card having slot of wildcard
        isDropped = true;
      end
    end

    if isDropped then
      dragControl:StopSnapBack();   -- Get catalog card instance ready for next time it's populated
      m_isPoliciesChanged = true;   -- Mark so button can go active
    end
    
    RealizePolicyCatalog(); 
  end

  RealizeActivePoliciesRows(); -- Turns back dark rows
end

-- ===========================================================================
--  If a row is available, for a certain policy type, then add the policy
--  to that row.
--    cardSlotType, The slot type associated with a card (may be overriden for the wildcard case)
--    id,       target ROW id #
--    policyType,   The policy to drop
--  RETURNS:  true if added
-- ===========================================================================
function AddToRowIfMatch(cardSlotType:string, id:number, policyType:string )

  if m_activeSlotRowData["k"..id].Avail > 0 
    and (cardSlotType == DROP_ROW_SLOT_TYPES[id] 
      or (m_isAllowWildcardsAnywhere and (cardSlotType=="SLOT_WILDCARD" or cardSlotType=="SLOT_GREAT_PERSON") )) then 

    m_activeSlotRowData["k"..id].Avail = m_activeSlotRowData["k"..id].Avail - 1;
    local policy:table  = m_kPolicyCatalogData[ policyType ];
    m_activeSlotRowData["k"..id].Policies[policyType] = policy;

    -- Add which slot this card will go into for the game core.
    for i,value in pairs(m_activeSlotRowData["k"..id].GameCoreSlotIndexes) do
      if value.PolicyType == EMPTY_POLICY_TYPE then
        m_activeSlotRowData["k"..id].GameCoreSlotIndexes[i].PolicyType = policyType;
        return true;
      end
    end

    -- Sanity check: The available slots should mean that if a drop happened this far, it should be good.
    UI.DataError("A policy card was said to successfully be moved/dropped but there are no engine slots for it? type:"..policyType);
    return false;
  end

  return false;
end

-- ===========================================================================
--  Find the next available slot for this card type and add it (if possible)
--  Used when double-clicking a card from the catalog.
-- ===========================================================================
function AddToNextAvailRow( cardInstance:table )
  local policyType  :string = cardInstance[KEY_POLICY_TYPE];
  local policy    :table  = m_kPolicyCatalogData[ policyType ];
  local rowSlotType :string = policy.SlotType;
  if rowSlotType == "SLOT_GREAT_PERSON" then rowSlotType = "SLOT_WILDCARD"; end   -- Treat great people like wildcards.

  local isCardAdded:boolean = true;
  if not AddToRowIfMatch(rowSlotType, DROP_ROW_ID.DIPLOMATIC, policyType) then
    if not AddToRowIfMatch(rowSlotType, DROP_ROW_ID.ECONOMIC, policyType) then
      if not AddToRowIfMatch(rowSlotType, DROP_ROW_ID.MILITARY, policyType) then
        -- If here, and anything can go into the wildcard slot; this card is now wild.
        if m_isAllowAnythingInWildcardSlot then
          rowSlotType = "SLOT_WILDCARD";
        end
        if not AddToRowIfMatch(rowSlotType, DROP_ROW_ID.WILDCARD, policyType) then
          isCardAdded = false;  --  don't add (no space/availablity)
        end
      end
    end
  end 

  if isCardAdded then
    m_isPoliciesChanged = true;
    RealizePolicyCatalog(); 
    RealizeActivePoliciesRows();
  end
end


-- ===========================================================================
--  Start dragging a card that exists in a row.
-- ===========================================================================
function OnDownFromRow( dragStruct:table, cardInstance:table )  
  cardInstance.Shadow:SetHide(false); 
  UI.PlaySound("UI_Policies_Card_Take");

  local policyType  :string = cardInstance[KEY_POLICY_TYPE];
  local policy    :table  = m_kPolicyCatalogData[policyType];
  local rowSlotType :string = policy.SlotType;  
  RealizeDragAndDropRows( rowSlotType );
end


-- ===========================================================================
--  Finish dragging a card out of a row 
--  Will either snap back, replace a card in another row, or go back into
--  the catalog.
-- ===========================================================================
function OnDropFromRow( dragStruct:table, cardInstance:table )  
  
  local dragControl:table     = dragStruct:GetControl();
  local x:number,y:number     = dragControl:GetScreenOffset();
  local width:number,height:number= dragControl:GetSizeVal();
  local dropArea:DropAreaStruct = GetDropArea(x,y,width,height,m_kDropAreasPolicyRows); 
  local fromRowID:number      = cardInstance[KEY_ROW_ID];
  local policyType:string     = cardInstance[KEY_POLICY_TYPE];
  local policy:table        = m_kPolicyCatalogData[policyType];
  local rowSlotType:string    = policy.SlotType;

  if rowSlotType == "SLOT_GREAT_PERSON" then rowSlotType = "SLOT_WILDCARD" end;

  cardInstance.Shadow:SetHide( true );
  UI.PlaySound("UI_Policies_Card_Drop");

  local isSwapped:boolean = false;
  local isRemoved:boolean = false;  

  -- Drag out of the row? 
  if dropArea == nil then
    cardInstance.Draggable:StopSnapBack();
    RemoveFromRow( cardInstance );
    isRemoved = true;
  else
  
    -- Dragged into a different row?
    if dropArea.id ~= fromRowID then

      -- If row has availablitity, do simple check and potentially add.
      if AddToRowIfMatch( policy.SlotType, dropArea.id, policyType) then
        cardInstance.Draggable:StopSnapBack();
        RemoveFromRow( cardInstance );
        isRemoved = true;
      elseif m_isAllowAnythingInWildcardSlot and AddToRowIfMatch("SLOT_WILDCARD", dropArea.id, policyType) then -- Fake card having slot of wildcard
        cardInstance.Draggable:StopSnapBack();
        RemoveFromRow( cardInstance );
        isRemoved = true;
      else
        -- Check if directly dragging onto a card...
        for _,existingCardInstance in pairs(m_uiActivePolicies) do
          if IsDragAndDropOverlapped( dragControl, existingCardInstance.Content, PERCENT_OVERLAP_TO_SWAP) then
            local existingPolicyType:string = existingCardInstance[KEY_POLICY_TYPE];
            local existingPolicy  :table = m_kPolicyCatalogData[existingPolicyType];

            -- Can card swap here?
            if  DROP_ROW_SLOT_TYPES[dropArea.id] == rowSlotType or 
              (m_isAllowWildcardsAnywhere and rowSlotType == "SLOT_WILDCARD") or
              (m_isAllowAnythingInWildcardSlot and DROP_ROW_SLOT_TYPES[dropArea.id] == "SLOT_WILDCARD")
            then

              -- Swap policy type in the slot index collection
              for _, slotData in pairs(m_activeSlotRowData["k"..dropArea.id].GameCoreSlotIndexes) do
                if slotData.PolicyType == existingPolicyType then                                   
                  RemoveFromRow( existingCardInstance );
                  RemoveFromRow( cardInstance );
                  slotData.PolicyType = policyType;
                  m_activeSlotRowData["k"..dropArea.id].Policies[policyType] = policy;
                  m_activeSlotRowData["k"..dropArea.id].Avail = m_activeSlotRowData["k"..dropArea.id].Avail - 1;
                  m_isPoliciesChanged = true;
                  isSwapped = true;
                  break;
                end
              end
              -- Sanity check
              if not isSwapped then
                UI.DataError("A swap occurred with policy card '"..policyType.."' onto existing policy '"..existingPolicyType.."' yet somehow the existing policy could not be found!'.  Happened on row '".. DROP_ROW_SLOT_TYPES[dropArea.id].."'");
              end
            end
            
            if isSwapped then break; end  -- Early out if swap occurred.
          end
        end
      end
    end   
  end

  if isRemoved or isSwapped then    
    RealizePolicyCatalog();
    RealizeActivePoliciesRows();
  else
    -- Still need to reset rows
    Controls.RowDiplomatic:SetColor( 0xffffffff );
    Controls.RowEconomic:SetColor( 0xffffffff );
    Controls.RowMilitary:SetColor( 0xffffffff );
    Controls.RowWildcard:SetColor( 0xffffffff );
  end

end


-- ===========================================================================
--  Remove a policy card that has been placed in a row
-- ===========================================================================
function RemoveFromRow( cardInstance:table)
  local policyType:string = cardInstance[KEY_POLICY_TYPE];
  local policy  :table  = m_kPolicyCatalogData[ policyType ];
  local id    :number = cardInstance[KEY_ROW_ID];
  cardInstance.Draggable:SetHide(true);
  cardInstance[KEY_POLICY_TYPE] = nil;
  cardInstance[KEY_ROW_ID] = nil;
  local parent:table = cardInstance.Content:GetParent();
  parent:DestroyChild(cardInstance.Content);

  -- Wipe it's active data representation; reset row.
  m_activeSlotRowData["k"..id].Policies[policyType] = nil;
  m_activeSlotRowData["k"..id].Avail = m_activeSlotRowData["k"..id].Avail + 1;
  for i=1,table.count(m_activeSlotRowData["k"..id].GameCoreSlotIndexes),1 do
    local info:table = m_activeSlotRowData["k"..id].GameCoreSlotIndexes[i];
    if info ~= nil and info.PolicyType == policyType then
      m_activeSlotRowData["k"..id].GameCoreSlotIndexes[i].PolicyType = EMPTY_POLICY_TYPE;
      break;
    end
  end

  m_isPoliciesChanged = true;
end


-- ===========================================================================
--  Is a policy currently active in the government (e.g., not available in
--  the catalog.)
-- ===========================================================================
function IsPolicyTypeActive( policyType:string )
  if m_activeSlotRowData["k"..DROP_ROW_ID.DIPLOMATIC].Policies[policyType] ~= nil then return true; end
  if m_activeSlotRowData["k"..DROP_ROW_ID.ECONOMIC].Policies[policyType] ~= nil then return true; end
  if m_activeSlotRowData["k"..DROP_ROW_ID.MILITARY].Policies[policyType] ~= nil then return true; end
  if m_activeSlotRowData["k"..DROP_ROW_ID.WILDCARD].Policies[policyType] ~= nil then return true; end
  return false;
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
    m_kCurrentGovernment = m_kGovernments[ GameInfo.Governments[governmentRowId].GovernmentType ];
  else
    m_kCurrentGovernment = nil;
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

  -- Policies data: current, max, and which specific policies are associated
  m_activeSlotRowData["k"..DROP_ROW_ID.DIPLOMATIC]= { Avail = 0, Max = 0, Policies = {}, GameCoreSlotIndexes = {} }; 
  m_activeSlotRowData["k"..DROP_ROW_ID.ECONOMIC]  = { Avail = 0, Max = 0, Policies = {}, GameCoreSlotIndexes = {} }; 
  m_activeSlotRowData["k"..DROP_ROW_ID.MILITARY]  = { Avail = 0, Max = 0, Policies = {}, GameCoreSlotIndexes = {} }; 
  m_activeSlotRowData["k"..DROP_ROW_ID.WILDCARD]  = { Avail = 0, Max = 0, Policies = {}, GameCoreSlotIndexes = {} }; 

  -- Fill in the data for the policies that are active.
  local numSlots:number = kPlayerCulture:GetNumPolicySlots();
  for i = 0, numSlots-1, 1 do
    local iSlotType :number = kPlayerCulture:GetSlotType(i);
    local rowSlotType :string = GameInfo.GovernmentSlots[iSlotType].GovernmentSlotType;       
        
    local id    :number = -1;
    if    rowSlotType == "SLOT_DIPLOMATIC" then id = DROP_ROW_ID.DIPLOMATIC;
    elseif  rowSlotType == "SLOT_ECONOMIC"  then  id = DROP_ROW_ID.ECONOMIC;
    elseif  rowSlotType == "SLOT_MILITARY"  then  id = DROP_ROW_ID.MILITARY;
    elseif  rowSlotType == "SLOT_WILDCARD"  then  id = DROP_ROW_ID.WILDCARD;
    else
      UI.DataError("On initialization; unhandled slot type for a policy '"..rowSlotType.."'");
    end
    
    -- Valid slot, initialize it.
    if id > -1 then     
      m_activeSlotRowData["k"..id].Max   = m_activeSlotRowData["k"..id].Max + 1;
      local iPolicyId :number = kPlayerCulture:GetSlotPolicy(i);
      if iPolicyId ~= -1 then
        local gamePolicy:table  = GameInfo.Policies[iPolicyId];
        local policy  :table  = m_kPolicyCatalogData[ gamePolicy.PolicyType ];
        m_activeSlotRowData["k"..id].Policies[gamePolicy.PolicyType] = policy;
        table.insert(m_activeSlotRowData["k"..id].GameCoreSlotIndexes, { PolicyType = gamePolicy.PolicyType, SlotIndex = i });
      else
        m_activeSlotRowData["k"..id].Avail = m_activeSlotRowData["k"..id].Avail + 1;
        table.insert(m_activeSlotRowData["k"..id].GameCoreSlotIndexes, { PolicyType = EMPTY_POLICY_TYPE, SlotIndex = i });
      end
    end     
  end

  m_kBonuses = {};
  for governmentType, government in pairs(m_kGovernments) do
    local bonusName   :string = (government.Index ~= -1) and GameInfo.Governments[government.Index].BonusType or "NO_GOVERNMENTBONUS";
    local iBonusIndex :number = -1;
    if bonusName ~= "NO_GOVERNMENTBONUS" then
      iBonusIndex = GameInfo.GovernmentBonusNames[bonusName].BonusValue;
    end
    if government.BonusFlatAmountPreview >= 0 then
      m_kBonuses[governmentType] = {
        BonusPercent      = government.BonusFlatAmountPreview
      }
    end 
  end
  
  -- Unlocked governments
  m_kUnlockedGovernments = {};
  for governmentType,government in pairs(m_kGovernments) do
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
    for governmentType, government in pairs(m_kGovernments) do
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
  local v1:number = 0;
  local v2:number = 0;  
  if    a.SlotType == "SLOT_MILITARY" then    v1 = 2;
  elseif  a.SlotType == "SLOT_ECONOMIC" then    v1 = 1;
  elseif  a.SlotType == "SLOT_DIPLOMATIC" then  v1 = 3;
  elseif  a.SlotType == "SLOT_WILDCARD" then    v1 = 4; 
  end
  if    b.SlotType == "SLOT_MILITARY" then    v2 = 2; 
  elseif  b.SlotType == "SLOT_ECONOMIC" then    v2 = 1; 
  elseif  b.SlotType == "SLOT_DIPLOMATIC" then  v2 = 3; 
  elseif  b.SlotType == "SLOT_WILDCARD" then    v2 = 4; 
  end
  if v1 == v2 then
    return a.UniqueID > b.UniqueID;
  end
  return v1 > v2;
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
  m_kGovernments = {};
  for row in GameInfo.Governments() do
    local government    :table  = GameInfo.Types[row.GovernmentType];
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
    local influencePointBonusDescription:string = Locale.Lookup("LOC_GOVT_INFLUENCE_POINTS_TOWARDS_ENVOYS", row.InfluencePointsPerTurn, row.InfluencePointsThreshold, row.InfluenceTokensPerThreshold);

    m_kGovernments[row.GovernmentType] = {
      BonusAccumulatedText  = GameInfo.Governments[row.GovernmentType].AccumulatedBonusShortDesc,
      BonusAccumulatedTooltip = GameInfo.Governments[row.GovernmentType].AccumulatedBonusDesc,
      BonusFlatAmountPreview  = GetGovernmentFlatBonusPreview(row.BonusType),
      BonusInherentText   = GameInfo.Governments[row.GovernmentType].InherentBonusDesc,
      BonusInfluenceNumber  = row.InfluenceTokensPerThreshold,
      BonusInfluenceText    = influencePointBonusDescription,
      BonusType       = row.BonusType,
      Hash          = government.Hash,
      Index         = row.Index,
      Name          = GameInfo.Governments[row.GovernmentType].Name,
      NumSlotMilitary     = slotMilitary,
      NumSlotEconomic     = slotEconomic,
      NumSlotDiplomatic   = slotDiplomatic,
      NumSlotWildcard     = slotWildcard
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
function greatPeopleFilter(policy)  return policy.SlotType == "SLOT_GREAT_PERSON"; end

function PopulatePolicyFilterData()
  m_kPolicyFilters = {};
  table.insert( m_kPolicyFilters, { Func=nil,         Description="LOC_GOVT_FILTER_NONE"    } );
  table.insert( m_kPolicyFilters, { Func=militaryFilter,    Description="LOC_GOVT_FILTER_MILITARY"  } );
  table.insert( m_kPolicyFilters, { Func=economicFilter,    Description="LOC_GOVT_FILTER_ECONOMIC"  } );
  table.insert( m_kPolicyFilters, { Func=diplomaticFilter,  Description="LOC_GOVT_FILTER_DIPLOMATIC"  } );
  table.insert( m_kPolicyFilters, { Func=greatPeopleFilter, Description="LOC_GOVT_FILTER_GREAT_PERSON"  } );
  table.insert( m_kPolicyFilters, { Func=wildcardFilter,    Description="LOC_GOVT_FILTER_GREAT_PERSON"  } );

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
    LuaEvents.GameDebug_GetValues( "GovernmentScreen" );    
  end
end

-- ===========================================================================
--  UI EVENT
-- ===========================================================================
function OnShutdown()
  -- Cache values for hotloading...
  LuaEvents.GameDebug_AddValue("GovernmentScreen", "isHidden",  ContextPtr:IsHidden() );
end

-- ===========================================================================
--  LUA Event
--  Set cached values back after a hotload.
-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
  if context ~= "GovernmentScreen" then
    return;
  end
  local isHidden:boolean = contextTable["isHidden"]; 
  if not isHidden then
    OnOpenGovernmentScreen(1);
  end
end

-- ===========================================================================
function OnRowAnimCallback()
  function lerp(a:number, b:number, t:number)
    return a * (1-t) + (b*t);
  end
  if (m_SizeChoosePolicyRows < SIZE_POLICY_ROW_LARGE) then  -- If the space we have to show the data in is LESS than the width of the element, we'll have to change the size as well as the position.
    Controls.PolicyRows:SetSizeX(lerp(m_policyRowAnimData.initialSize, m_policyRowAnimData.desiredSize, Controls.RowAnim:GetProgress()));
  end
  Controls.PolicyRows:SetOffsetX(lerp(m_policyRowAnimData.initialOffset, m_policyRowAnimData.desiredOffset, Controls.RowAnim:GetProgress()));
  RealizeActivePolicyRowSize();
end

-- ===========================================================================
--  Input
--  UI Event Handler
-- ===========================================================================
function KeyHandler( key:number )
  if key == Keys.VK_ESCAPE then
    if m_kPopupDialog:IsOpen() then
      m_kPopupDialog:ActivateCommand("cancel");
    else
      Close();
    end
    return true;
  end
  if key == Keys.VK_RETURN then
    -- Don't let enter propigate or it will hit action panel which will raise a screen (potentially this one again) tied to the action.
    if not Controls.SelectPolicies:IsHidden() and IsAbleToChangePolicies() then
      OnConfirmPolicies();
    end
    return true;
  end

  return false;
end
function OnInputHandler( pInputStruct:table )
  local uiMsg = pInputStruct:GetMessageType();
  if uiMsg == KeyEvents.KeyUp then return KeyHandler( pInputStruct:GetKey() ); end;
  return false;
end

-- ===========================================================================
--  Input Hotkey Event
-- ===========================================================================
function OnInputActionTriggered( actionId )
  if actionId == m_ToggleGovernmentId then
    local ePlayer:number = Game.GetLocalPlayer();
    if ePlayer == -1 then -- Likely auto playing.     
      return;
    end
    local playerCulture:table = Players[ePlayer]:GetCulture();
    if (playerCulture:GetNumPoliciesUnlocked() > 0) then
      local bInAnarchy = playerCulture:IsInAnarchy();
      if (bInAnarchy == true) then
        return;
      end
    end
        UI.PlaySound("Play_UI_Click");
    if ContextPtr:IsHidden() then
      OnOpenGovernmentScreenMyGovernment();
    else
      OnClose();
    end
  end
end

-- ===========================================================================
--  CTOR
-- ===========================================================================
function Initialize()

  PopulateStaticData();     -- Obtain unchanging, static data from game core
  PopulatePolicyFilterData();   -- Filter support
  AllocateUI();         -- Allocate UI pieces
  Resize();

  m_ePlayer = Game.GetLocalPlayer();

  RealizeTabs();
  
  Controls.MilitaryFilterButton:SetToolTipString(   Locale.Lookup("LOC_GOVT_FILTER_W_DOTS").. "[NEWLINE]" .. Locale.Lookup("LOC_GOVT_FILTER_MILITARY") );
  Controls.EconomicFilterButton:SetToolTipString(   Locale.Lookup("LOC_GOVT_FILTER_W_DOTS").. "[NEWLINE]" .. Locale.Lookup("LOC_GOVT_FILTER_ECONOMIC") );
  Controls.DiplomacyFilterButton:SetToolTipString(  Locale.Lookup("LOC_GOVT_FILTER_W_DOTS").. "[NEWLINE]" .. Locale.Lookup("LOC_GOVT_FILTER_DIPLOMATIC") );
  Controls.GreatPeopleFilterButton:SetToolTipString(  Locale.Lookup("LOC_GOVT_FILTER_W_DOTS").. "[NEWLINE]" .. Locale.Lookup("LOC_CATEGORY_GREAT_PEOPLE_NAME") );
  Controls.WildcardFilterButton:SetToolTipString(   Locale.Lookup("LOC_GOVT_FILTER_W_DOTS").. "[NEWLINE]" .. Locale.Lookup("LOC_GOVT_FILTER_NONE") );
  
  AutoSizeGridButton(Controls.MilitaryFilterButton,120,24,4,"H");
  AutoSizeGridButton(Controls.EconomicFilterButton,120,24,4,"H");
  AutoSizeGridButton(Controls.DiplomacyFilterButton,120,24,4,"H");
  AutoSizeGridButton(Controls.GreatPeopleFilterButton,180,24,4,"H");
  AutoSizeGridButton(Controls.WildcardFilterButton,120,24,4,"H");


  Controls.MilitaryFilterButton:RegisterCallback(   Mouse.eLClick,  function() OnPolicyFilterClicked( {Func=militaryFilter,     Description="LOC_GOVT_FILTER_MILITARY"} ); end );
  Controls.EconomicFilterButton:RegisterCallback(   Mouse.eLClick,  function() OnPolicyFilterClicked( {Func=economicFilter,     Description="LOC_GOVT_FILTER_ECONOMIC"} ); end );
  Controls.DiplomacyFilterButton:RegisterCallback(  Mouse.eLClick,  function() OnPolicyFilterClicked( {Func=diplomaticFilter,     Description="LOC_GOVT_FILTER_DIPLOMATIC"} ); end );
  Controls.WildcardFilterButton:RegisterCallback(   Mouse.eLClick,  function() OnPolicyFilterClicked( {Func=nil,          Description="LOC_GOVT_FILTER_NONE"} ); end );
  Controls.GreatPeopleFilterButton:RegisterCallback(  Mouse.eLClick,  function() OnPolicyFilterClicked( {Func=greatPeopleFilter,    Description="LOC_CATEGORY_GREAT_PEOPLE_NAME"} ); end );


    Controls.ButtonMyGovernment:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
    Controls.ButtonPolicies:RegisterCallback(   Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
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
  Controls.GovernmentTree:RegisterEndCallback( 
    function() 
      -- Hide after full-alpha to prevent input (on invisible items)
      if Controls.GovernmentTree:IsReversing() then
        Controls.GovernmentTree:SetHide(true);
      else
        Controls.PolicyRows:SetHide(true); 
        Controls.PolicyCatalog:SetHide(true);
        Controls.MyGovernment:SetHide(true); 
      end
    end );

  -- Gamecore EVENTS
  Events.CivicsUnlocked.Add( OnCivicsUnlocked );
  Events.GovernmentChanged.Add( OnGovernmentChanged );
  Events.GovernmentPolicyChanged.Add( OnGovernmentPolicyChanged );
  Events.GovernmentPolicyObsoleted.Add( OnGovernmentPolicyChanged );  
  Events.InputActionTriggered.Add( OnInputActionTriggered );
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

  Controls.ModalScreenTitle:SetText(Locale.ToUpper("LOC_GOVT_GOVERNMENT"));
  Controls.ModalScreenClose:RegisterCallback(Mouse.eLClick, OnClose);
  Controls.ModalBG:SetHide(true);
  
  Controls.PolicyPanelHeaderLabel:SetText(Locale.ToUpper("LOC_TREE_OPTIONS"));
end
Initialize();
