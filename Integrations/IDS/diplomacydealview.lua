-- ===========================================================================
-- Diplomacy Trade View Manager
-- ===========================================================================
include( "InstanceManager" );
include( "CitySupport" );
include( "Civ6Common" ); -- AutoSizeGridButton
include( "SupportFunctions" ); -- DarkenLightenColor
include( "PopupDialog" );
include( "ToolTipHelper_PlayerYields" );
include( "GreatWorksSupport" );

-- ===========================================================================
--	VARIABLES
-- ===========================================================================
local ms_PlayerPanelIM		:table		= InstanceManager:new( "PlayerAvailablePanel",  "Root" );
local ms_IconOnlyIM			:table		= InstanceManager:new( "IconOnly",  "SelectButton", Controls.IconOnlyContainer );
local ms_IconOnly_3IM 		:table		= InstanceManager:new( "IconOnly_3",  "SelectButton", Controls.IconOnlyContainer );
local ms_IconOnly_Resource_ScarceIM			:table		= InstanceManager:new( "IconOnly_Resource_Scarce",  "SelectButton", Controls.IconOnlyContainer );
local ms_IconOnly_Resource_DuplicateIM		:table		= InstanceManager:new( "IconOnly_Resource_Duplicate",  "SelectButton", Controls.IconOnlyContainer );
local ms_IconOnly_Resource_UntradeableIM	:table		= InstanceManager:new( "IconOnly_Resource_Untradeable",  "SelectButton", Controls.IconOnlyContainer );
local ms_IconAndTextIM		:table		= InstanceManager:new( "IconAndText",  "SelectButton", Controls.IconAndTextContainer );
local ms_IconAndTextWithDetailsIM			:table		= InstanceManager:new( "IconAndTextWithDetails",  "SelectButton", Controls.IconAndTextContainer );
local ms_LeftRightListIM	:table		= InstanceManager:new( "LeftRightList",  "List", Controls.LeftRightListContainer );
local ms_TopDownListIM		:table		= InstanceManager:new( "TopDownList",  "List", Controls.TopDownListContainer );
local ms_AgreementOptionIM	:table		= InstanceManager:new( "AgreementOptionInstance",  "AgreementOptionButton", Controls.ValueEditStack );

local ms_DealAgreementTypesResearchAgreement = nil; -- AZURENCY : hold the type of a research agreement (see hack line 1824)

local ms_ValueEditDealItemID = -1;		-- The ID of the deal item that is being value edited.
local ms_ValueEditDealItemControlTable = nil; -- The control table of the deal item that is being edited.

local OTHER_PLAYER = 0;
local LOCAL_PLAYER = 1;

local ms_LocalPlayerPanel = {};
local ms_OtherPlayerPanel = {};

local ms_LocalPlayer =		nil;
local ms_OtherPlayer =		nil;
local ms_OtherPlayerID =	-1;
local ms_OtherPlayerIsHuman = false;

local ms_InitiatedByPlayerID = -1;

local ms_bIsDemand = false;
local ms_bExiting = false;

local ms_LastIncomingDealProposalAction = DealProposalAction.PENDING;

local m_kPopupDialog			:table; -- Will use custom "popup" since in leader mode the Popup stack is disabled.

local AvailableDealItemGroupTypes = {};
AvailableDealItemGroupTypes.GOLD				= 1;
AvailableDealItemGroupTypes.LUXURY_RESOURCES	= 2;
AvailableDealItemGroupTypes.STRATEGIC_RESOURCES	= 3;
AvailableDealItemGroupTypes.AGREEMENTS			= 4;
AvailableDealItemGroupTypes.CITIES				= 5;
AvailableDealItemGroupTypes.OTHER_PLAYERS		= 6;
AvailableDealItemGroupTypes.GREAT_WORKS			= 7;
AvailableDealItemGroupTypes.CAPTIVES			= 8;

AvailableDealItemGroupTypes.COUNT				= 8;

local ms_AvailableGroups = {};

-----------------------

local DealItemGroupTypes = {};
DealItemGroupTypes.GOLD			= 1;
DealItemGroupTypes.LUXURY_RESOURCES	= 2;
DealItemGroupTypes.STRATEGIC_RESOURCES	= 3;
DealItemGroupTypes.AGREEMENTS	= 4;
DealItemGroupTypes.CITIES		= 5;
DealItemGroupTypes.GREAT_WORKS	= 6;
DealItemGroupTypes.CAPTIVES		= 7;

DealItemGroupTypes.COUNT		= 7;


local ms_DealGroups = {};

local ms_DealAgreementsGroup = {};

local ms_DefaultOneTimeGoldAmount = 100;

local ms_DefaultMultiTurnGoldAmount = 10;
local ms_DefaultMultiTurnGoldDuration = 30;

local ms_bForceUpdateOnCommit = false;

--CQUI Addition
-- local YIELD_FONT_ICONS:table = {
--         YIELD_FOOD				= "[ICON_FoodLarge]",
--         YIELD_PRODUCTION	= "[ICON_ProductionLarge]",
--         YIELD_GOLD				= "[ICON_GoldLarge]",
--         YIELD_SCIENCE			= "[ICON_ScienceLarge]",
--         YIELD_CULTURE			= "[ICON_CultureLarge]",
--         YIELD_FAITH				= "[ICON_FaithLarge]",
--         TourismYield			= "[ICON_TourismLarge]"
-- };

-- local CQUI_GreatWork_YieldChanges = {}
-- for row in GameInfo.GreatWork_YieldChanges() do
--   CQUI_GreatWork_YieldChanges[row.GreatWorkType] = row
-- end

-- ===========================================================================
function SetIconToSize(iconControl, iconName, iconSize)
  if iconSize == nil then
    iconSize = 64;
  end
  
  local x, y, szIconName, iconSize = IconManager:FindIconAtlasNearestSize(iconName, iconSize, true);
  iconControl:SetTexture(x, y, szIconName);
  iconControl:SetSizeVal(iconSize, iconSize);
end

-- ===========================================================================
function InitializeDealGroups()

  for i = 1, AvailableDealItemGroupTypes.COUNT, 1 do
    ms_AvailableGroups[i] = {};
  end

  for i = 1, DealItemGroupTypes.COUNT, 1 do
    ms_DealGroups[i] = {};
  end

end

InitializeDealGroups();

-- ===========================================================================
function GetPlayerType(player : table)
  if (player:GetID() == ms_LocalPlayer:GetID()) then
    return LOCAL_PLAYER;
  end

  return OTHER_PLAYER;
end

-- ===========================================================================
function GetPlayerOfType(playerType : number)
  if (playerType == LOCAL_PLAYER) then
    return ms_LocalPlayer;
  end

  return ms_OtherPlayer;
end

-- ===========================================================================
function GetOtherPlayer(player : table)
  if (player ~= nil and player:GetID() == ms_OtherPlayer:GetID()) then
    return ms_LocalPlayer;
  end

  return ms_OtherPlayer;
end

-- ===========================================================================
function SetDefaultLeaderDialogText()
  -- if (ms_bIsDemand == true and ms_InitiatedByPlayerID == ms_OtherPlayerID) then
  -- 	SetLeaderDialog("LOC_DIPLO_DEMAND_INTRO", "");
  -- else
  -- 	SetLeaderDialog("LOC_DIPLO_DEAL_INTRO", "");
  -- end
end

-- ===========================================================================
function ProposeWorkingDeal(bIsAutoPropose : boolean)
  if (bIsAutoPropose == nil) then
    bIsAutoPropose = false;
  end

  if (not DealManager.HasPendingDeal(ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID())) then
    if (ms_bIsDemand) then
      DealManager.SendWorkingDeal(DealProposalAction.DEMANDED, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
    else
      if (bIsAutoPropose) then
        DealManager.SendWorkingDeal(DealProposalAction.INSPECT, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
      else
        DealManager.SendWorkingDeal(DealProposalAction.PROPOSED, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
      end
    end
  end
end

-- ===========================================================================
function RequestEqualizeWorkingDeal()
  if (not DealManager.HasPendingDeal(ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID())) then
    DealManager.SendWorkingDeal(DealProposalAction.EQUALIZE, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  end
end

-- ===========================================================================
function DealIsEmpty()
  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  if (pDeal == nil or pDeal:GetItemCount() == 0) then
    return true;
  end

  return false;
end

-- ===========================================================================
-- Update the proposed working deal.  This is called as items are changed in the deal.
-- It is primarily used to 'auto-propose' the deal when working with an AI.
function UpdateProposedWorkingDeal()
  if (ms_LastIncomingDealProposalAction ~= DealProposalAction.PENDING or IsAutoPropose()) then

    local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
    if (pDeal == nil or pDeal:GetItemCount() == 0 or ms_bIsDemand) then
      -- Is a demand or no items, restart
      ms_LastIncomingDealProposalAction = DealProposalAction.PENDING;
      UpdateDealStatus();
    else
      if (IsAutoPropose()) then
        ProposeWorkingDeal(true);
      end
    end
  end
end

-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--	Displays the leader's name (with screen name if you are a human in a multiplayer game), along with the civ name,
--	and the icon of the civ with civ colors.  When you mouse over the civ icon, you should see a full list of all cities.
--	This should help players differentiate between duplicate civs.
function PopulateSignatureArea(player:table)
  -- Set colors for the Civ icon
  if (player ~= nil) then
    m_primaryColor, m_secondaryColor  = UI.GetPlayerColors( player:GetID() );
    local darkerBackColor = DarkenLightenColor(m_primaryColor,(-85),100);
    local brighterBackColor = DarkenLightenColor(m_primaryColor,90,255);
    local panelBannerBackColor = DarkenLightenColor(m_primaryColor,0,245);

    if(player == ms_LocalPlayer) then
      Controls.PlayerCivBacking_Base:SetColor(m_primaryColor);
      Controls.PlayerCivBacking_Lighter:SetColor(brighterBackColor);
      Controls.PlayerCivBacking_Darker:SetColor(darkerBackColor);
      Controls.PlayerCivIcon:SetColor(m_secondaryColor);
      Controls.PlayerBackground:SetColor(panelBannerBackColor);
      Controls.PlayerBackgroundBarRight:SetColor(panelBannerBackColor);
      Controls.MyOfferLabel:SetColor(brighterBackColor);
    else
      Controls.PartnerCivBacking_Base:SetColor(m_primaryColor);
      Controls.PartnerCivBacking_Lighter:SetColor(brighterBackColor);
      Controls.PartnerCivBacking_Darker:SetColor(darkerBackColor);
      Controls.PartnerCivIcon:SetColor(m_secondaryColor);
      Controls.PartnerBackground:SetColor(panelBannerBackColor);
      Controls.PartnerBackgroundBarRight:SetColor(panelBannerBackColor);
      Controls.TheirOfferLabel:SetColor(brighterBackColor);
    end
  end

  -- Set the leader name, civ name, and civ icon data
  local playerConfig = PlayerConfigurations[player:GetID()]
  local civTypeName = playerConfig:GetCivilizationTypeName();
  if civTypeName == nil then
    UI.DataError("Invalid type name returned by GetCivilizationTypeName");
  else
    local civIconName = "ICON_"..civTypeName;

    local leaderName = Locale.ToUpper(Locale.Lookup(playerConfig:GetLeaderName()))
    local playerName = PlayerConfigurations[player:GetID()]:GetPlayerName();
    if GameConfiguration.IsAnyMultiplayer() and player:IsHuman() then
      leaderName = leaderName .. " ("..Locale.ToUpper(playerName)..")"
    end

    --Create a tooltip which shows a list of this Civ's cities
    local civTooltip = Locale.Lookup(GameInfo.Civilizations[civTypeName].Name);
    local pPlayerConfig = PlayerConfigurations[player:GetID()];
    local playerName = pPlayerConfig:GetPlayerName();
    local playerCities = player:GetCities();
    if(playerCities ~= nil) then
      civTooltip = civTooltip .. "[NEWLINE]"..Locale.Lookup("LOC_PEDIA_CONCEPTS_PAGEGROUP_CITIES_NAME").. ":[NEWLINE]----------";
      for i,city in playerCities:Members() do
        civTooltip = civTooltip.. "[NEWLINE]".. Locale.Lookup(city:GetName());
      end
    end


    -- Populate relevant controls
    if(player == ms_LocalPlayer) then

      Controls.PlayerCivIcon:SetIcon(civIconName);
      Controls.PlayerCivName:SetText(Locale.ToUpper(Locale.Lookup(GameInfo.Civilizations[civTypeName].Name)));
      Controls.PlayerCivName:SetColor(m_primaryColor);
      Controls.PlayerLeaderName:SetText(leaderName);
      Controls.PlayerLeaderName:SetColor(m_secondaryColor);

      Controls.PlayerCivIcon:SetToolTipString(Locale.Lookup(civTooltip));
      Controls.PlayerSignatureStack:CalculateSize();
      Controls.PlayerSignatureStack:ReprocessAnchoring();
    else


      Controls.PartnerCivIcon:SetIcon(civIconName);
      Controls.PartnerCivName:SetText(Locale.ToUpper(Locale.Lookup(GameInfo.Civilizations[civTypeName].Name)));
      Controls.PartnerCivName:SetColor(m_primaryColor);
      Controls.PartnerLeaderName:SetText(leaderName);
      Controls.PartnerLeaderName:SetColor(m_secondaryColor);

      Controls.PartnerCivIcon:SetToolTipString(Locale.Lookup(civTooltip));
      Controls.PartnerSignatureStack:CalculateSize();
      Controls.PartnerSignatureStack:ReprocessAnchoring();
    end
  end

end

-- ===========================================================================
function UpdateOtherPlayerText(otherPlayerSays)
  local bHide = true;
  if (ms_OtherPlayer ~= nil and otherPlayerSays ~= nil) then
    local playerConfig = PlayerConfigurations[ms_OtherPlayer:GetID()];
    if (playerConfig ~= nil) then
      -- Set the leader name
      local leaderDesc = playerConfig:GetLeaderName();
      Controls.PartnerLeaderName:SetText(Locale.ToUpper(Locale.Lookup("LOC_DIPLOMACY_DEAL_OTHER_PLAYER_SAYS", leaderDesc)));
    end
  end
  -- When we get dialog for what the leaders say during a trade, we can add it here!
end

-- ===========================================================================
function OnToggleCollapseGroup(iconList : table)
  if (iconList.ListStack:IsHidden()) then
    iconList.ListStack:SetHide(false);
  else
    iconList.ListStack:SetHide(true);
  end

  iconList.List:CalculateSize();
  iconList.List:ReprocessAnchoring();
end
-- ===========================================================================
function CreateHorizontalGroup(rootStack : table, title : string)
  local iconList = ms_LeftRightListIM:GetInstance(rootStack);
  if (title == nil or title == "") then
    iconList.Title:SetHide(true);		-- No title
  else
    iconList.TitleText:LocalizeAndSetText(title);
  end
  iconList.List:CalculateSize();
  iconList.List:ReprocessAnchoring();

  return iconList;
end

-- ===========================================================================
function CreateVerticalGroup(rootStack : table, title : string)
  local iconList = ms_TopDownListIM:GetInstance(rootStack);
  if (title == nil or title == "") then
    iconList.Title:SetHide(true);		-- No title
  else
    iconList.TitleText:LocalizeAndSetText(title);
  end
  iconList.List:CalculateSize();
  iconList.List:ReprocessAnchoring();

  return iconList;
end


-- ===========================================================================
function CreatePlayerAvailablePanel(playerType : number, rootControl : table)

  --local playerPanel = ms_PlayerPanelIM:GetInstance(rootControl);

  ms_AvailableGroups[AvailableDealItemGroupTypes.GOLD][playerType]				= CreateHorizontalGroup(rootControl);
  ms_AvailableGroups[AvailableDealItemGroupTypes.LUXURY_RESOURCES][playerType]	= CreateHorizontalGroup(rootControl, "LOC_DIPLOMACY_DEAL_LUXURY_RESOURCES");
  ms_AvailableGroups[AvailableDealItemGroupTypes.STRATEGIC_RESOURCES][playerType] = CreateHorizontalGroup(rootControl, "LOC_DIPLOMACY_DEAL_STRATEGIC_RESOURCES");
  ms_AvailableGroups[AvailableDealItemGroupTypes.AGREEMENTS][playerType]			= CreateVerticalGroup(rootControl, "LOC_DIPLOMACY_DEAL_AGREEMENTS");
  ms_AvailableGroups[AvailableDealItemGroupTypes.CITIES][playerType]				= CreateVerticalGroup(rootControl, "LOC_DIPLOMACY_DEAL_CITIES");
  ms_AvailableGroups[AvailableDealItemGroupTypes.OTHER_PLAYERS][playerType]		= CreateVerticalGroup(rootControl, "LOC_DIPLOMACY_DEAL_OTHER_PLAYERS");
  ms_AvailableGroups[AvailableDealItemGroupTypes.GREAT_WORKS][playerType]			= CreateVerticalGroup(rootControl, "LOC_DIPLOMACY_DEAL_GREAT_WORKS");
  ms_AvailableGroups[AvailableDealItemGroupTypes.CAPTIVES][playerType]			= CreateVerticalGroup(rootControl, "LOC_DIPLOMACY_DEAL_CAPTIVES");

  rootControl:CalculateSize();
  rootControl:ReprocessAnchoring();

  return playerPanel;
end

-- ===========================================================================
function CreatePlayerDealPanel(playerType : number, rootControl : table)
--This creates the containers for the offer area...
  ms_DealGroups[DealItemGroupTypes.GOLD][playerType]	= CreateHorizontalGroup(rootControl);
  ms_DealGroups[DealItemGroupTypes.LUXURY_RESOURCES][playerType]	= CreateHorizontalGroup(rootControl);
  ms_DealGroups[DealItemGroupTypes.STRATEGIC_RESOURCES][playerType]	= CreateHorizontalGroup(rootControl);
  ms_DealGroups[DealItemGroupTypes.AGREEMENTS][playerType] = CreateVerticalGroup(rootControl);
  ms_DealGroups[DealItemGroupTypes.CITIES][playerType] = CreateVerticalGroup(rootControl);
  ms_DealGroups[DealItemGroupTypes.GREAT_WORKS][playerType] = CreateVerticalGroup(rootControl);
  ms_DealGroups[DealItemGroupTypes.CAPTIVES][playerType] = CreateVerticalGroup(rootControl);

  --**********************************************************************
  -- Currently putting them all in the same control.
  --[[ms_DealGroups[DealItemGroupTypes.GOLD][playerType] = rootControl;
  ms_DealGroups[DealItemGroupTypes.RESOURCES][playerType] = rootControl;
  ms_DealGroups[DealItemGroupTypes.AGREEMENTS][playerType] = rootControl;
  ms_DealGroups[DealItemGroupTypes.CITIES][playerType] = rootControl;
  ms_DealGroups[DealItemGroupTypes.GREAT_WORKS][playerType] = rootControl;
  ms_DealGroups[DealItemGroupTypes.CAPTIVES][playerType] = rootControl;]]--

end

-- ===========================================================================
function CreateValueAmountEditOverlay()
  Controls.ValueAmountEditLeft:RegisterCallback( Mouse.eLClick, function() OnValueAmountEditDelta(-1); end );
  Controls.ValueAmountEditRight:RegisterCallback( Mouse.eLClick, function() OnValueAmountEditDelta(1); end );
  Controls.ValueAmountEdit:RegisterCommitCallback( OnValueAmountEditCommit );
  Controls.ConfirmValueEdit:RegisterCallback( Mouse.eLClick, OnValueAmountEditCommit );
end

-- ===========================================================================
function OnValuePulldownCommit(forType)

  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  if (pDeal ~= nil) then

      local pDealItem = pDeal:FindItemByID(ms_ValueEditDealItemID);
      if (pDealItem ~= nil) then
        pDealItem:SetValueType( forType );

        local valueName = pDealItem:GetValueTypeNameID();
        Controls.ValueTypeEditPulldown:GetButton():LocalizeAndSetText(valueName);
        if (ms_ValueEditDealItemControlTable ~= nil) then
          -- Keep the text on the icon, that is currently hidden, up to date too.
          ms_ValueEditDealItemControlTable.ValueText:LocalizeAndSetText(pDealItem:GetValueTypeNameID(valueName));
        end

        UpdateDealStatus();
        UpdateProposedWorkingDeal();
      end
    end

end

-- ===========================================================================
function PopulateValuePulldown(pullDown, pDealItem)
  
  local possibleValues = DealManager.GetPossibleDealItems(pDealItem:GetFromPlayerID(), pDealItem:GetToPlayerID(), pDealItem:GetType(), pDealItem:GetSubType());
  if (possibleValues ~= nil) then
    pullDown:ClearEntries();
    for i, entry in ipairs(possibleValues) do

      entryControlTable = {};
      pullDown:BuildEntry( "InstanceOne", entryControlTable );

      local szItemName = Locale.Lookup(entry.ForTypeDisplayName);
      if (entry.Duration == -1) then
        local eTech = GameInfo.Technologies[entry.ForType].Index;
        local iTurns = 	ms_LocalPlayer:GetDiplomacy():ComputeResearchAgreementTurns(ms_OtherPlayer, eTech);
        szDisplayName = Locale.Lookup("LOC_DIPLOMACY_DEAL_PARAMETER_WITH_TURNS", szItemName, iTurns);
      else
        szDisplayName = szItemName;
      end

      entryControlTable.Button:LocalizeAndSetText(szDisplayName);						
      local eType = entry.ForType;
      entryControlTable.Button:RegisterCallback(Mouse.eLClick, function()
        OnValuePulldownCommit(eType);
      end);
    end
    local valueName = pDealItem:GetValueTypeNameID();
    if (valueName ~= nil) then
      pullDown:GetButton():LocalizeAndSetText(valueName);
    else
      pullDown:GetButton():LocalizeAndSetText("LOC_DIPLOMACY_DEAL_SELECT_DEAL_PARAMETER");
    end

    pullDown:SetHide(false);
    pullDown:CalculateInternals();
  end	
end

-- ===========================================================================
function SetValueText(icon, pDealItem)

  if (icon.ValueText ~= nil) then
    local valueName = pDealItem:GetValueTypeNameID();
    if (valueName == nil) then
      if (pDealItem:HasPossibleValues()) then
        valueName = "LOC_DIPLOMACY_DEAL_CLICK_TO_CHANGE_DEAL_PARAMETER";
      end
    end
    if (valueName ~= nil) then
      icon.ValueText:LocalizeAndSetText(valueName);
      icon.ValueText:SetHide(false);
    else
      icon.ValueText:SetHide(true);
    end
  end
end

-- ===========================================================================
function CreatePanels()

  CreateValueAmountEditOverlay();
  -- Create the Other Player Panels
  CreatePlayerAvailablePanel(OTHER_PLAYER, Controls.TheirInventoryStack);

  -- Create the Local Player Panels
  CreatePlayerAvailablePanel(LOCAL_PLAYER, Controls.MyInventoryStack);

  CreatePlayerDealPanel(OTHER_PLAYER, Controls.TheirOfferStack);
  CreatePlayerDealPanel(LOCAL_PLAYER, Controls.MyOfferStack);

  Controls.EqualizeDeal:RegisterCallback( Mouse.eLClick, OnEqualizeDeal );
  Controls.EqualizeDeal:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.AcceptDeal:RegisterCallback( Mouse.eLClick, OnProposeOrAcceptDeal );
  Controls.AcceptDeal:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.DemandDeal:RegisterCallback( Mouse.eLClick, OnProposeOrAcceptDeal );
  Controls.DemandDeal:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.RefuseDeal:RegisterCallback(Mouse.eLClick, OnRefuseDeal);
  Controls.RefuseDeal:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.ResumeGame:RegisterCallback(Mouse.eLClick, OnResumeGame);
  Controls.ResumeGame:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.WhatWouldItTakeButton:RegisterCallback(Mouse.eLClick, OnEqualizeDeal);
  Controls.WhatWouldItTakeButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.WhatWouldYouGiveMe:RegisterCallback(Mouse.eLClick, OnEqualizeDeal);
  Controls.WhatWouldYouGiveMe:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

end

-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Find the 'instance' table from the control
function FindIconInstanceFromControl(rootControl : table)
  if (rootControl ~= nil) then
    -- Should just pass the appropriate control into the function rather than groping around for one that exists, but I don't want to go back and change all these references
    local controlTable = ms_IconOnlyIM:FindInstanceByControl(rootControl);
    if (controlTable ~= nil) then
      return controlTable;
    end

    controlTable = ms_IconAndTextIM:FindInstanceByControl(rootControl);
    if (controlTable ~= nil) then
      return controlTable;
    end

    controlTable = ms_IconOnly_3IM:FindInstanceByControl(rootControl);
    if (controlTable ~= nil) then
      return controlTable;
    end

    controlTable = ms_IconAndTextWithDetailsIM:FindInstanceByControl(rootControl);
    if (controlTable ~= nil) then
      return controlTable;
    end

    controlTable = ms_IconOnly_Resource_ScarceIM:FindInstanceByControl(rootControl);
    if (controlTable ~= nil) then
      return controlTable;
    end

    controlTable = ms_IconOnly_Resource_DuplicateIM:FindInstanceByControl(rootControl);
    if (controlTable ~= nil) then
      return controlTable;
    end

    controlTable = ms_IconOnly_Resource_UntradeableIM:FindInstanceByControl(rootControl);
    if (controlTable ~= nil) then
      return controlTable;
    end
  end
  return nil;
end

-- ===========================================================================
-- Show or hide the "amount text" or the "Value Text" sub-control of the supplied control instance
function SetHideValueText(controlTable : table, bHide : boolean)

  if (controlTable ~= nil) then
    if (controlTable.AmountText ~= nil) then
      controlTable.AmountText:SetHide(bHide);
    end
    if (controlTable.ValueText ~= nil) then
      controlTable.ValueText:SetHide(bHide);
    end
  end
end

-- ===========================================================================
-- Detach the value edit overlay from anything it is attached to.
function ClearValueEdit()

  SetHideValueText(ms_ValueEditDealItemControlTable, false);

  ms_ValueEditDealItemControlTable = nil
  ms_ValueEditDealItemID = -1;

  Controls.ValueAmountEditOverlay:SetHide(true);
  Controls.ValueTypeEditOverlay:SetHide(true);
  Controls.ValueAmountEditOverlayContainer:SetHide(true);

end

-- ===========================================================================
-- Is the deal a gift to the other player?
function IsGiftToOtherPlayer()
  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  if (pDeal ~= nil and not ms_bIsDemand and pDeal:IsValid()) then
    local iItemsFromLocal = pDeal:GetItemCount(ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
    local iItemsFromOther = pDeal:GetItemCount(ms_OtherPlayer:GetID(), ms_LocalPlayer:GetID());

    if (iItemsFromLocal > 0 and iItemsFromOther == 0) then
      return true;

    end
  end

  return false;
end

-- ===========================================================================
function UpdateDealStatus()
  local bDealValid = false;
  ClearValueEdit();
  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  if (pDeal ~= nil) then
    if (pDeal:GetItemCount() > 0) then
      bDealValid = true;
    end
  end

  if (bDealValid) then
    if pDeal:Validate() ~= DealValidationResult.VALID then
      bDealValid = false;
    end
  end

  Controls.EqualizeDeal:SetHide(ms_bIsDemand);

  -- Have we sent out a deal?
  local bHasPendingDeal = DealManager.HasPendingDeal(ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());

  if (not bHasPendingDeal and ms_LastIncomingDealProposalAction == DealProposalAction.PENDING) then
    -- We have yet to send out a deal.
    Controls.AcceptDeal:SetHide(true);
    local showDemand = bDealValid and ms_bIsDemand;
    Controls.DemandDeal:SetHide(not showDemand);
  else
    local cantAccept = (ms_LastIncomingDealProposalAction ~= DealProposalAction.ACCEPTED and ms_LastIncomingDealProposalAction ~= DealProposalAction.PROPOSED and ms_LastIncomingDealProposalAction ~= DealProposalAction.ADJUSTED) or not bDealValid or bHasPendingDeal;
    Controls.AcceptDeal:SetHide(cantAccept);
    if (ms_bIsDemand) then
      if (ms_LocalPlayer:GetID() == ms_InitiatedByPlayerID) then
        -- Local human is making a demand
        if (ms_LastIncomingDealProposalAction == DealProposalAction.ACCEPTED) then
          Controls.DemandDeal:SetHide(cantAccept);
          -- The other player has accepted the demand, but we must enact it.
          -- We won't have the human need to press the accept button, just do it and exit.
          OnProposeOrAcceptDeal();
          return;
        else
          Controls.AcceptDeal:SetHide(true);
          Controls.DemandDeal:SetHide(false);
        end
      else
        Controls.DemandDeal:SetHide(true);
      end
    else
      Controls.DemandDeal:SetHide(true);
    end
  end

  UpdateProposalButtons(bDealValid);
  AutoSizeGridButton(Controls.WhatWouldYouGiveMe,100,20,10,"1");
  AutoSizeGridButton(Controls.WhatWouldItTakeButton,100,20,10,"1");
  AutoSizeGridButton(Controls.RefuseDeal,200,32,10,"1");
  AutoSizeGridButton(Controls.EqualizeDeal,200,32,10,"1");
  AutoSizeGridButton(Controls.AcceptDeal,200,41,10,"1");
  Controls.DealOptionsStack:CalculateSize();
  Controls.DealOptionsStack:ReprocessAnchoring();

end

-- ===========================================================================
-- The Human has ask to have the deal equalized.  Well, what the AI is
-- willing to take.
function OnEqualizeDeal()
  ClearValueEdit();
  RequestEqualizeWorkingDeal();
end

-- ===========================================================================
-- Propose the deal, if this is the first time, or accept it, if the other player has
-- accepted it.
function OnProposeOrAcceptDeal()

  ClearValueEdit();

  if (ms_LastIncomingDealProposalAction == DealProposalAction.PENDING or 
        ms_LastIncomingDealProposalAction == DealProposalAction.REJECTED or 
        ms_LastIncomingDealProposalAction == DealProposalAction.EQUALIZE_FAILED) then
    ProposeWorkingDeal();
    UpdateDealStatus();
    UI.PlaySound("Confirm_Bed_Positive");
  else
    if (ms_LastIncomingDealProposalAction == DealProposalAction.ACCEPTED or ms_LastIncomingDealProposalAction == DealProposalAction.PROPOSED or ms_LastIncomingDealProposalAction == DealProposalAction.ADJUSTED) then
      -- Any adjustments?
      if (DealManager.AreWorkingDealsEqual(ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID())) then
        -- Yes, we can accept
        -- if deal will trigger war, prompt user before confirming deal
        local sendDealAndContinue = function()
          -- Send the deal.  This will also send out a POSITIVE response statement
          DealManager.SendWorkingDeal(DealProposalAction.ACCEPTED, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
          OnContinue();
          UI.PlaySound("Confirm_Bed_Positive");
        end;

        local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
        local pJointWarItem = pDeal:FindItemByType(DealItemTypes.AGREEMENTS, DealAgreementTypes.JOINT_WAR);
        if DealAgreementTypes.JOINT_WAR and pJointWarItem then
          local iWarType = pJointWarItem:GetParameterValue("WarType");

          if (iWarType == nil) then iWarType = WarTypes.FORMAL_WAR; end

          local targetPlayerID = pJointWarItem:GetValueType();
          if (targetPlayerID >= 0) then
            LuaEvents.DiplomacyActionView_ConfirmWarDialog(ms_LocalPlayer:GetID(), targetPlayerID, iWarType, sendDealAndContinue);
          else
            UI.DataError("Invalid Player ID to declare Joint War to: " .. targetPlayerID);
          end
        else
          local pThirdPartyWarItem = pDeal:FindItemByType(DealItemTypes.AGREEMENTS, DealAgreementTypes.THIRD_PARTY_WAR);
          if (DealAgreementTypes.THIRD_PARTY_WAR and pThirdPartyWarItem) then
            local iWarType = pThirdPartyWarItem:GetParameterValue("WarType");

            if (iWarType == nil) then iWarType = WarTypes.FORMAL_WAR; end

            local targetPlayerID = pThirdPartyWarItem:GetValueType();
            if (targetPlayerID >= 0) then
              LuaEvents.DiplomacyActionView_ConfirmWarDialog(ms_LocalPlayer:GetID(), targetPlayerID, iWarType, sendDealAndContinue);
            else
              UI.DataError("Invalid Player ID to declare Third Party War to: " .. targetPlayerID);
            end
          else
            sendDealAndContinue();
          end			
        end
      else
        -- No, send an adjustment and stay in the deal view.
        DealManager.SendWorkingDeal(DealProposalAction.ADJUSTED, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
        UpdateDealStatus();
      end
    end
  end
end

-- ===========================================================================
function OnRefuseDeal(bForceClose)

  if (bForceClose == nil) then
    bForceClose = false;
  end

  local bHasPendingDeal = DealManager.HasPendingDeal(ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());

  local sessionID = DiplomacyManager.FindOpenSessionID(Game.GetLocalPlayer(), ms_OtherPlayer:GetID());
  if (sessionID ~= nil) then
    if (not ms_OtherPlayerIsHuman and not bHasPendingDeal) then
      -- Refusing an AI's deal
      ClearValueEdit();

      if (ms_InitiatedByPlayerID == ms_OtherPlayerID) then
        -- AI started this, so tell them that we don't want the deal
        if (bForceClose == true) then
          -- Forcing the close, usually because the turn timer expired
          DealManager.SendWorkingDeal(DealProposalAction.REJECTED, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
          DiplomacyManager.CloseSession(sessionID);
          StartExitAnimation();
        else
          DiplomacyManager.AddResponse(sessionID, Game.GetLocalPlayer(), "NEGATIVE");
        end
      else
        -- Else close the session
        DiplomacyManager.CloseSession(sessionID);
        StartExitAnimation();
      end
    else
      if (ms_OtherPlayerIsHuman) then
        if (bHasPendingDeal) then
          -- Canceling the deal with the other player.
          DealManager.SendWorkingDeal(DealProposalAction.CLOSED, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
        else
          if (ms_InitiatedByPlayerID ~= Game.GetLocalPlayer()) then
            -- Refusing the deal with the other player.
            DealManager.SendWorkingDeal(DealProposalAction.REJECTED, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
          end
        end

        DiplomacyManager.CloseSession(sessionID);
        StartExitAnimation();
      end
    end
  else
    -- We have lost our session!
    if (not ContextPtr:IsHidden()) then
      if (not ms_bExiting) then
        OnResumeGame();
      end
    end
  end

end

-- ===========================================================================
function OnResumeGame()

  -- Exiting back to wait for a response
  ClearValueEdit();

  local sessionID = DiplomacyManager.FindOpenSessionID(Game.GetLocalPlayer(), ms_OtherPlayer:GetID());
  if (sessionID ~= nil) then
    DiplomacyManager.CloseSession(sessionID);
  end

  -- Start the exit animation, it will call OnContinue when complete
  StartExitAnimation();
end

-- ===========================================================================
function OnExitFadeComplete()
  -- if(Controls.TradePanelFade:IsReversing()) then
  -- 	Controls.TradePanelFade:SetSpeed(2);
  -- 	Controls.TradePanelSlide:SetSpeed(2);

  -- 	OnContinue();
  -- end
end
--Controls.TradePanelFade:RegisterEndCallback(OnExitFadeComplete);
-- ===========================================================================
-- Change the value number edit by a delta
function OnValueAmountEditDelta(delta : number)

  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  if (pDeal ~= nil) then

    local pDealItem = pDeal:FindItemByID(ms_ValueEditDealItemID);
    if (pDealItem ~= nil) then
      local iNewAmount = tonumber(Controls.ValueAmountEdit:GetText() or 0) + delta;
      iNewAmount = clip(iNewAmount, 1, pDealItem:GetMaxAmount());

      if (iNewAmount ~= pDealItem:GetAmount()) then
        pDealItem:SetAmount(iNewAmount);
        ms_bForceUpdateOnCommit = true;
      end

      local newAmountStr = tostring(pDealItem:GetAmount());
      Controls.ValueAmountEdit:SetText(newAmountStr);
      if (ms_ValueEditDealItemControlTable ~= nil) then
        -- Keep the amount on the icon, that is currently hidden, up to date too.
        ms_ValueEditDealItemControlTable.AmountText:SetText(newAmountStr);
      end
    end
  end
end

-- ===========================================================================
-- Commit the value in the edit control to the deal item
function OnValueAmountEditCommit()

  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  if (pDeal ~= nil) then

    local pDealItem = pDeal:FindItemByID(ms_ValueEditDealItemID);
    if (pDealItem ~= nil) then
      local iNewAmount = tonumber(Controls.ValueAmountEdit:GetText());
      iNewAmount = clip(iNewAmount, 1, pDealItem:GetMaxAmount());
      Controls.ValueAmountEdit:SetText(tostring(iNewAmount));

      if (iNewAmount ~= pDealItem:GetAmount() or ms_bForceUpdateOnCommit) then
        pDealItem:SetAmount(iNewAmount);
        ms_bForceUpdateOnCommit = false;
        UpdateProposedWorkingDeal();
      end
      local newAmountStr = tostring(pDealItem:GetAmount());
      Controls.ValueAmountEdit:SetText(newAmountStr);
      if (ms_ValueEditDealItemControlTable ~= nil) then
        -- Keep the amount on the icon, that is currently hidden, up to date too.
        ms_ValueEditDealItemControlTable.AmountText:SetText(newAmountStr);
      end
      UpdateDealStatus();
    end
  end
end

-- ===========================================================================
-- Detach the value edit if it is attached to the control
function DetachValueEdit(itemID: number)

  if (itemID == ms_ValueEditDealItemID) then
    ClearValueEdit();
  end

end

-- ===========================================================================
-- Reattach the value edit overlay to the control set it is editing.
function ReAttachValueEdit()

  if (ms_ValueEditDealItemControlTable ~= nil) then

    local rootControl = ms_ValueEditDealItemControlTable.SelectButton;

    -- Position over the deal item.  We do this, rather than attaching to the item as a child, because we want to always be on top over everything.
    local x, y = rootControl:GetScreenOffset();
    local w, h = rootControl:GetSizeVal();

    SetHideValueText(ms_ValueEditDealItemControlTable, true);

    -- Display the number in the value edit field
    local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
    if (pDeal ~= nil) then

      local pDealItem = pDeal:FindItemByID(ms_ValueEditDealItemID);
      if (pDealItem ~= nil) then

        local itemID = pDealItem:GetID();
        local itemType = pDealItem:GetType();
        if (itemType == DealItemTypes.GOLD or itemType == DealItemTypes.RESOURCES) then
          -- Hide/show everything for GOLD and RESOURCE options
          ms_AgreementOptionIM:ResetInstances();
          Controls.ValueAmountEditOverlay:SetOffsetVal(x + (w/2), y + h);
          Controls.ValueAmountEditOverlay:SetHide(false);
          Controls.ValueAmountEditOverlayContainer:SetHide(false);

          Controls.ValueAmountEdit:SetText(tonumber(pDealItem:GetAmount()));
        else
          if (itemType == DealItemTypes.AGREEMENTS) then
            Controls.ValueTypeEditOverlay:SetOffsetVal(x + (w/2), y + h);
            Controls.ValueTypeEditOverlay:SetHide(false);

            PopulateValuePulldown(Controls.ValueTypeEditPulldown, pDealItem);
          end
        end

      end
    end

    rootControl:ReprocessAnchoring();
  end

end

-- ===========================================================================
-- Attach the value edit overlay to a control set.
function AttachValueEdit(rootControl : table, dealItemID : number)

  ClearValueEdit();

  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  if (pDeal ~= nil) then

    local pDealItem = pDeal:FindItemByID(dealItemID);
    if (pDealItem ~= nil) then
      -- Do we have something to edit?
      if (pDealItem:HasPossibleValues() or pDealItem:HasPossibleAmounts()) then
        -- Yes
        ms_ValueEditDealItemControlTable = FindIconInstanceFromControl(rootControl);
        ms_ValueEditDealItemID = dealItemID;

        ReAttachValueEdit();
      end
    end
  end

end

-- ===========================================================================
-- Update the deal panel for a player
function UpdateDealPanel(player)

  -- If we modify the deal without sending it to the AI then reset the status to PENDING
  ms_LastIncomingDealProposalAction = DealProposalAction.PENDING;

  UpdateDealStatus();

  PopulatePlayerDealPanel(Controls.TheirOfferStack, ms_OtherPlayer);
  PopulatePlayerDealPanel(Controls.MyOfferStack, ms_LocalPlayer);
end

-- ===========================================================================
function OnClickAvailableOneTimeGold(player, iAddAmount : number)

  if (ms_bIsDemand == true and ms_InitiatedByPlayerID == ms_OtherPlayerID) then
    -- Can't modifiy demand that is not ours
    return;
  end

  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  if (pDeal ~= nil) then

    local pPlayerTreasury = player:GetTreasury();
    local bFound = false;

    -- Already there?
    local dealItems = pDeal:FindItemsByType(DealItemTypes.GOLD, DealItemSubTypes.NONE, player:GetID());
    local pDealItem;
    if (dealItems ~= nil) then
      for i, pDealItem in ipairs(dealItems) do
        if (pDealItem:GetDuration() == 0) then
          -- Already have a one time gold.  Up the amount
          iAddAmount = pDealItem:GetAmount() + iAddAmount;
          iAddAmount = clip(iAddAmount, nil, pDealItem:GetMaxAmount());
          if (iAddAmount ~= pDealItem:GetAmount()) then
            pDealItem:SetAmount(iAddAmount);
            bFound = true;
            break;
          else
            return;		-- No change, just exit
          end
        end
      end
    end

    -- Doesn't exist yet, add it.
    if (not bFound) then

      -- Going to add anything?
      pDealItem = pDeal:AddItemOfType(DealItemTypes.GOLD, player:GetID());
      if (pDealItem ~= nil) then

        -- Set the duration, so the max amount calculation knows what we are doing
        pDealItem:SetDuration(0);

        -- Adjust the gold to our max
        iAddAmount = clip(iAddAmount, nil, pDealItem:GetMaxAmount());
        if (iAddAmount > 0) then
          pDealItem:SetAmount(iAddAmount);
          bFound = true;
        else
          -- It is empty, remove it.
          local itemID = pDealItem:GetID();
          pDeal:RemoveItemByID(itemID);
        end
      end
    end


    if (bFound) then
      UpdateProposedWorkingDeal();
      UpdateDealPanel(player);
    end
  end
end

-- ===========================================================================
function OnClickAvailableMultiTurnGold(player, iAddAmount : number, iDuration : number)

  if (ms_bIsDemand == true and ms_InitiatedByPlayerID == ms_OtherPlayerID) then
    -- Can't modifiy demand that is not ours
    return;
  end

  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  if (pDeal ~= nil) then

    local pPlayerTreasury = player:GetTreasury();

    local bFound = false;
    UI.PlaySound("UI_GreatWorks_Put_Down");

    -- Already there?
    local dealItems = pDeal:FindItemsByType(DealItemTypes.GOLD, DealItemSubTypes.NONE, player:GetID());
    local pDealItem;
    if (dealItems ~= nil) then
      for i, pDealItem in ipairs(dealItems) do
        if (pDealItem:GetDuration() ~= 0) then
          -- Already have a multi-turn gold.  Up the amount
          iAddAmount = pDealItem:GetAmount() + iAddAmount;
          iAddAmount = clip(iAddAmount, nil, pDealItem:GetMaxAmount());
          if (iAddAmount ~= pDealItem:GetAmount()) then
            pDealItem:SetAmount(iAddAmount);
            bFound = true;
            break;
          else
            return;		-- No change, just exit
          end
        end
      end
    end

    -- Doesn't exist yet, add it.
    if (not bFound) then
      -- Going to add anything?
      pDealItem = pDeal:AddItemOfType(DealItemTypes.GOLD, player:GetID());
      if (pDealItem ~= nil) then

        -- Set the duration, so the max amount calculation knows what we are doing
        pDealItem:SetDuration(iDuration);

        -- Adjust the gold to our max
        iAddAmount = clip(iAddAmount, nil, pDealItem:GetMaxAmount());

        if (iAddAmount > 0) then
          pDealItem:SetAmount(iAddAmount);
          bFound = true;
        else
          -- It is empty, remove it.
          local itemID = pDealItem:GetID();
          pDeal:RemoveItemByID(itemID);
        end
      end
    end

    if (bFound) then
      UpdateProposedWorkingDeal();
      UpdateDealPanel(player);
    end
  end
end

-- ===========================================================================
-- Clip val to be within the range of min and max
function clip(val: number, min: number, max: number)
  if min and val < min then
    val = min;
  elseif max and val > max then
    val = max;
  end
  return val;
end

-- ===========================================================================
-- Check to see if the deal should be auto-proposed.
function IsAutoPropose()
  if (not ms_OtherPlayerIsHuman) then
    local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
    pDeal:Validate();
    if (pDeal ~= nil and not ms_bIsDemand and pDeal:IsValid() and not DealManager.HasPendingDeal(ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID())) then
      local iItemsFromLocal = pDeal:GetItemCount(ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
      local iItemsFromOther = pDeal:GetItemCount(ms_OtherPlayer:GetID(), ms_LocalPlayer:GetID());

      if (iItemsFromLocal > 0 or iItemsFromOther > 0) then
        return true;
      end
    end
  end
  return false;
end

-- ===========================================================================
-- Check the state of the deal and show/hide the special proposal buttons
function UpdateProposalButtons(bDealValid)

  local bDealIsPending = DealManager.HasPendingDeal(ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());

  if (bDealValid and (not bDealIsPending or not ms_OtherPlayerIsHuman)) then
    Controls.ResumeGame:SetHide(true);
    local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
    Controls.EqualizeDeal:SetHide(ms_bIsDemand);
    if (pDeal ~= nil) then

      local iItemsFromLocal = pDeal:GetItemCount(ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
      local iItemsFromOther = pDeal:GetItemCount(ms_OtherPlayer:GetID(), ms_LocalPlayer:GetID());

      -- Hide/show directions if either side has no items
      Controls.MyDirections:SetHide( iItemsFromLocal > 0);
      Controls.TheirDirections:SetHide( iItemsFromOther > 0);

      if (not ms_bIsDemand) then
        if (not ms_OtherPlayerIsHuman) then
          -- Dealing with an AI
          if (pDeal:HasUnacceptableItems()) then
            Controls.EqualizeDeal:SetHide(true);
            Controls.AcceptDeal:SetHide(true);
          elseif (iItemsFromLocal > 0 and iItemsFromOther == 0) then
            -- One way gift?
            Controls.WhatWouldYouGiveMe:SetHide(false);
            Controls.WhatWouldItTakeButton:SetHide(true);
            -- If the AI rejects after trying to equalize a gift then hide equalize button
            if ms_LastIncomingDealProposalAction == DealProposalAction.EQUALIZE_FAILED then
              -- Equalize failed, hide the button, and we can't accept now!
              -- Except... not.
              -- The AI will yield EQUALIZE_FAILED if it would have accepted the gift without modifications.
              -- The AI does not distinguish between 'this gift is fine as is' and 'i would not give you anything for that'.
              Controls.AcceptDeal:SetShow(false);
              Controls.EqualizeDeal:SetShow(false);
            elseif ms_LastIncomingDealProposalAction == DealProposalAction.REJECTED then
              -- Most likely autoproposed, there's a chance for an equalize. No accept, again.
              Controls.AcceptDeal:SetShow(false);
              Controls.EqualizeDeal:SetShow(true);
              Controls.EqualizeDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_WHAT_WOULD_IT_TAKE");
              Controls.EqualizeDeal:LocalizeAndSetToolTip("LOC_DIPLOMACY_DEAL_WHAT_IT_WILL_TAKE_TOOLTIP");
            else
              -- No immediate complaints, I guess we can show both equalize and accept.
              Controls.AcceptDeal:SetShow(true);
              Controls.AcceptDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_GIFT_DEAL");
              Controls.EqualizeDeal:SetShow(true);
              Controls.EqualizeDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_WHAT_WOULD_YOU_GIVE_ME");
              Controls.EqualizeDeal:LocalizeAndSetToolTip("LOC_DIPLO_DEAL_WHAT_WOULD_YOU_GIVE_ME_TOOLTIP");
            end
          else
            if (iItemsFromLocal == 0 and iItemsFromOther > 0) then
              Controls.WhatWouldYouGiveMe:SetHide(true);
              Controls.WhatWouldItTakeButton:SetHide(false);
              -- AI was unable to equalize for the requested items so hide the equalize button
              if ms_LastIncomingDealProposalAction == DealProposalAction.EQUALIZE_FAILED then
                Controls.EqualizeDeal:SetHide(true);
              else
                Controls.EqualizeDeal:SetHide(false);
              end
              Controls.AcceptDeal:SetHide(true); --If either of the above buttons are showing, disable the main accept button
            else --Something is being offered on both sides
              -- Show equalize button if the accept button is hidden and the AI already hasn't attempted to equalize the deal
              if Controls.AcceptDeal:IsHidden() and ms_LastIncomingDealProposalAction ~= DealProposalAction.EQUALIZE_FAILED then
                Controls.EqualizeDeal:SetHide(false);
              else
                Controls.EqualizeDeal:SetHide(true);
              end
              Controls.WhatWouldYouGiveMe:SetHide(true);
              Controls.WhatWouldItTakeButton:SetHide(true);
              Controls.AcceptDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_ACCEPT_DEAL");
            end
          end
        else
          -- Dealing with another human

          Controls.EqualizeDeal:SetHide(true);
          Controls.AcceptDeal:SetHide(false);

          if (ms_LastIncomingDealProposalAction == DealProposalAction.PENDING) then
            -- Just starting the deal
            if (iItemsFromLocal > 0 and iItemsFromOther == 0) then
              -- Is this one way to them?
              Controls.MyDirections:SetHide(true);
              Controls.TheirDirections:SetHide(false);
              Controls.WhatWouldYouGiveMe:SetHide(false);
              Controls.WhatWouldItTakeButton:SetHide(true);
              Controls.AcceptDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_GIFT_DEAL");
            else
              -- Everything else is a proposal to another human
              Controls.MyDirections:SetHide(true);
              Controls.TheirDirections:SetHide(true);
              Controls.WhatWouldYouGiveMe:SetHide(true);
              Controls.WhatWouldItTakeButton:SetHide(true);
              Controls.AcceptDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_PROPOSE_DEAL");
            end
            -- Make sure the leader text is set to something appropriate.
            --SetDefaultLeaderDialogText();
          else
            Controls.MyDirections:SetHide(true);
            Controls.TheirDirections:SetHide(true);
            Controls.WhatWouldYouGiveMe:SetHide(true);
            Controls.WhatWouldItTakeButton:SetHide(true);
            -- Are the incoming and outgoing deals the same?
            if (DealManager.AreWorkingDealsEqual(ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID())) then
              Controls.AcceptDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_ACCEPT_DEAL");
            else
              Controls.AcceptDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_PROPOSE_DEAL");
            end
          end
        end
      else
        -- Is a Demand
        if (ms_InitiatedByPlayerID == ms_OtherPlayerID) then
          Controls.MyDirections:SetHide(true);
          Controls.TheirDirections:SetHide(true);
          --SetDefaultLeaderDialogText();
        else
          if (iItemsFromOther == 0) then
            Controls.TheirDirections:SetHide(false);
          else
            Controls.TheirDirections:SetHide(true);
          end
          -- Demand against another player
          --SetLeaderDialog("LOC_DIPLO_DEAL_LEADER_DEMAND", "LOC_DIPLO_DEAL_LEADER_DEMAND_EFFECT");
        end
        Controls.WhatWouldYouGiveMe:SetHide(true);
        Controls.WhatWouldItTakeButton:SetHide(true);
      end
    else
      -- Make sure the leader text is set to something appropriate.
      --SetDefaultLeaderDialogText();
    end
  else
    --There isn't a valid deal, or we are just viewing a pending deal.
    local bIsViewing = (bDealIsPending and ms_OtherPlayerIsHuman);

    local iItemsFromLocal = 0;
    local iItemsFromOther = 0;

    local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
    if (pDeal ~= nil) then
      iItemsFromLocal = pDeal:GetItemCount(ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
      iItemsFromOther = pDeal:GetItemCount(ms_OtherPlayer:GetID(), ms_LocalPlayer:GetID());
    end

    Controls.WhatWouldYouGiveMe:SetHide(true);
    Controls.WhatWouldItTakeButton:SetHide(true);
    Controls.MyDirections:SetHide( bIsViewing or iItemsFromLocal > 0);
    Controls.TheirDirections:SetHide( bIsViewing or iItemsFromOther > 0);
    Controls.EqualizeDeal:SetHide(true);
    Controls.AcceptDeal:SetHide(true);
    Controls.DemandDeal:SetHide(true);

    if (not DealIsEmpty() and not bDealValid) then
      -- Set have the other leader tell them that the deal has invalid items.
      --SetLeaderDialog("LOC_DIPLOMACY_DEAL_INVALID", "");
    else
      --SetDefaultLeaderDialogText();
    end

    Controls.ResumeGame:SetHide(not bIsViewing);
  end

  if (not Controls.AcceptDeal:IsHidden()) then
    Controls.EqualizeDeal:SetHide(true);
  end

  if (bDealIsPending and ms_OtherPlayerIsHuman) then
    if (ms_bIsDemand) then
      Controls.RefuseDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_CANCEL_DEMAND");
    else
      Controls.RefuseDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_CANCEL_DEAL");
    end
  else
    -- Did the other player start this or the local player?
    if (ms_InitiatedByPlayerID == ms_OtherPlayerID) then
      if (not bDealValid) then
        -- Our changes have made the deal invalid, say cancel instead
        Controls.RefuseDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_CANCEL_DEAL");
      else
        if (ms_bIsDemand) then
          Controls.AcceptDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_ACCEPT_DEMAND");
          Controls.RefuseDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_REFUSE_DEMAND");
        else
          Controls.RefuseDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_REFUSE_DEAL");
        end
      end
    else
      Controls.RefuseDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_EXIT_DEAL");
    end
  end
  Controls.DealOptionsStack:CalculateSize();
  Controls.DealOptionsStack:ReprocessAnchoring();

  if (ms_bIsDemand) then
    if (ms_InitiatedByPlayerID == ms_OtherPlayerID) then
      -- Demand from the other player and we are responding
      Controls.MyOfferBracket:SetHide(false);
      Controls.MyOfferLabel:SetHide(false);
      Controls.TheirOfferLabel:SetHide(true);
      Controls.TheirOfferBracket:SetHide(true);
    else
      -- Demand from us, to the other player
      Controls.MyOfferBracket:SetHide(true);
      Controls.MyOfferLabel:SetHide(true);
      Controls.TheirOfferLabel:SetHide(false);
      Controls.TheirOfferBracket:SetHide(false);
    end
  else
    Controls.MyOfferLabel:SetHide(false);
    Controls.MyOfferBracket:SetHide(false);
    Controls.TheirOfferLabel:SetHide(false);
    Controls.TheirOfferBracket:SetHide(false);
  end

  Controls.CenterDealOffersStack:CalculateSize();
  Controls.CenterDealOffersStack:ReprocessAnchoring();

  Controls.TheirOfferStack:CalculateSize();
  --Controls.TheirOfferStack:ReprocessAnchoring();
  Controls.TheirOfferBracket:DoAutoSize();
  --Controls.TheirOfferBracket:ReprocessAnchoring();
  Controls.TheirOfferLabel:ReprocessAnchoring();
  --Controls.TheirOfferScroll:CalculateSize();
  --Controls.TheirOfferBracket:ReprocessAnchoring();	-- Because the bracket is centered inside the scroll box, we have to reprocess this again.

  Controls.MyOfferStack:CalculateSize();
  --Controls.MyOfferStack:ReprocessAnchoring();
  Controls.MyOfferBracket:DoAutoSize();
  --Controls.MyOfferBracket:ReprocessAnchoring();
  Controls.MyOfferLabel:ReprocessAnchoring();
  --Controls.MyOfferScroll:CalculateSize();
  --Controls.MyOfferBracket:ReprocessAnchoring();		-- Because the bracket is centered inside the scroll box, we have to reprocess this again.

end

-- ===========================================================================
function PopulateAvailableGold(player : table, iconList : table)

  local iAvailableItemCount = 0;

  local eFromPlayerID = player:GetID();
  local eToPlayerID = GetOtherPlayer(player):GetID();

  local pForDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  local possibleResources = DealManager.GetPossibleDealItems(eFromPlayerID, eToPlayerID, DealItemTypes.GOLD, pForDeal);
  if (possibleResources ~= nil) then
    for i, entry in ipairs(possibleResources) do
      if (entry.Duration == 0) then
        -- One time gold
        local playerTreasury:table	= player:GetTreasury();
        local goldBalance	:number = math.floor(playerTreasury:GetGoldBalance());

        if (not ms_bIsDemand) then
          -- One time gold
          local icon = ms_IconOnlyIM:GetInstance(iconList.ListStack);
          icon.AmountText:SetText(goldBalance);
          icon.SelectButton:SetToolTipString(nil);		-- We recycle the entries, so make sure this is clear.
          SetIconToSize(icon.Icon, "ICON_YIELD_GOLD_5");
          icon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableOneTimeGold(player, ms_DefaultOneTimeGoldAmount); end );

          iAvailableItemCount = iAvailableItemCount + 1;
        end
      else
        -- ARISTOS: to display available GPT on top of button
        local playerTreasury:table	= player:GetTreasury();
        local goldYield		:number = math.floor((playerTreasury:GetGoldYield() - playerTreasury:GetTotalMaintenance()));
        -- Multi-turn gold
        icon = ms_IconOnly_3IM:GetInstance(iconList.ListStack);
        icon.AmountText:SetText(FormatValuePerTurn(goldYield));
        icon.AmountText:SetHide(false);
        SetIconToSize(icon.Icon1, "ICON_YIELD_GOLD_1");
        SetIconToSize(icon.Icon2, "ICON_YIELD_GOLD_1");
        SetIconToSize(icon.Icon3, "ICON_YIELD_GOLD_1");

        icon.SelectButton:SetToolTipString(nil);		-- We recycle the entries, so make sure this is clear.
        icon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableMultiTurnGold(player, ms_DefaultMultiTurnGoldAmount, ms_DefaultMultiTurnGoldDuration); end );
        --icon.ValueText:SetHide(true);

        --iconList.ListStack:CalculateSize();
        --iconList.List:ReprocessAnchoring();

        iAvailableItemCount = iAvailableItemCount + 1;
      end
    end
  end

  return iAvailableItemCount;
end

-- ===========================================================================
function OnClickAvailableBasic(itemType, player, valueType)

  if (ms_bIsDemand == true and ms_InitiatedByPlayerID == ms_OtherPlayerID) then
    -- Can't modifiy demand that is not ours
    return;
  end

  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  if (pDeal ~= nil) then

    -- Already there?
    local pDealItem = pDeal:FindItemByValueType(itemType, DealItemSubTypes.NONE, valueType, player:GetID());
    if (pDealItem == nil) then
      -- No
      pDealItem = pDeal:AddItemOfType(itemType, player:GetID());
      if (pDealItem ~= nil) then
        pDealItem:SetValueType(valueType);
        UpdateDealPanel(player);
        UpdateProposedWorkingDeal();
      end
    end
  end
end

-- ===========================================================================
function OnClickAvailableResource(player, resourceType)

  if (ms_bIsDemand == true and ms_InitiatedByPlayerID == ms_OtherPlayerID) then
    -- Can't modifiy demand that is not ours
    return;
  end

  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  if (pDeal ~= nil) then

    -- Already there?
    local dealItems = pDeal:FindItemsByType(DealItemTypes.RESOURCES, DealItemSubTypes.NONE, player:GetID());
    local pDealItem;
    if (dealItems ~= nil) then
      for i, pDealItem in ipairs(dealItems) do
        if pDealItem:GetValueType() == resourceType then
          -- Check for non-zero duration.  There may already be a one-time transfer of the resource if a city is in the deal.
          if (pDealItem:GetDuration() ~= 0) then
            return;	-- Already in there.
          end
        end
      end
    end

    local pPlayerResources = player:GetResources();
    -- Get the total amount of the resource we have. This does not take into account anything already in the deal.
    local iAmount = pPlayerResources:GetResourceAmount( resourceType );
    if (iAmount > 0) then
      pDealItem = pDeal:AddItemOfType(DealItemTypes.RESOURCES, player:GetID());
      if (pDealItem ~= nil) then
        -- Add one
        pDealItem:SetValueType(resourceType);
        pDealItem:SetAmount(1);
        pDealItem:SetDuration(30);	-- Default to this many turns		

        -- After we add the item, test to see if the item is valid, it is possible that we have exceeded the amount of resources we can trade.
        if not pDealItem:IsValid() then
          pDeal:RemoveItemByID(pDealItem:GetID());
          pDealItem = nil;
        else
          UI.PlaySound("UI_GreatWorks_Put_Down");
        end

        UpdateDealPanel(player);
        UpdateProposedWorkingDeal();
      end
    end
  end
end

-- ===========================================================================
function OnClickAvailableAgreement(player, agreementType, agreementTurns)

  if (ms_bIsDemand == true and ms_InitiatedByPlayerID == ms_OtherPlayerID) then
    -- Can't modifiy demand that is not ours
    return;
  end

  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  if (pDeal ~= nil) then

    -- Already there?
    local pDealItem = pDeal:FindItemByType(DealItemTypes.AGREEMENTS, agreementType, player:GetID());
    if (pDealItem == nil) then
      -- No
      -- AZURENCY : Joint War and Research Agreements need special treatment (can be only modified on the player side)
      if (agreementType == DealAgreementTypes.JOINT_WAR or agreementType == DealAgreementTypes.THIRD_PARTY_WAR or agreementType == DealAgreementTypes.RESEARCH_AGREEMENT) then
        pDealItem = pDeal:AddItemOfType(DealItemTypes.AGREEMENTS, ms_LocalPlayer:GetID());
      else
        pDealItem = pDeal:AddItemOfType(DealItemTypes.AGREEMENTS, player:GetID());
      end

      if (pDealItem ~= nil) then
        pDealItem:SetSubType(agreementType);
        pDealItem:SetDuration(agreementTurns);

        UpdateDealPanel(player);
        UpdateProposedWorkingDeal();
        UI.PlaySound("UI_GreatWorks_Put_Down");
      end
    end
  end
end

-- ===========================================================================
function OnClickAvailableGreatWork(player, type)

  OnClickAvailableBasic(DealItemTypes.GREATWORK, player, type);
  UI.PlaySound("UI_GreatWorks_Put_Down");

end

-- ===========================================================================
function OnClickAvailableCaptive(player, type)

  OnClickAvailableBasic(DealItemTypes.CAPTIVE, player, type);
  UI.PlaySound("UI_GreatWorks_Put_Down");

end

-- ===========================================================================
function OnClickAvailableCity(player, valueType, subType)

  if (ms_bIsDemand == true and ms_InitiatedByPlayerID == ms_OtherPlayerID) then
    -- Can't modifiy demand that is not ours
    return;
  end

  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  if (pDeal ~= nil) then

    -- Since we're ceding this city make sure to look for this city in the current owners city list
    local cityName;
    if subType == 1 then -- CitySubTypes:CEDE_OCCUPIED
      cityName = GetCityData(GetOtherPlayer(player):GetCities():FindID(valueType)).CityName
    else
      cityName = GetCityData(player:GetCities():FindID(valueType)).CityName
    end

    -- Already there?
    local pDealItem = pDeal:FindItemByValueType(DealItemTypes.CITIES, subType, valueType, player:GetID());
    if (pDealItem == nil or pDealItem:GetValueTypeNameID() ~= cityName) then --ARISTOS

      -- No
      pDealItem = pDeal:AddItemOfType(DealItemTypes.CITIES, player:GetID());
      if (pDealItem ~= nil) then
        pDealItem:SetSubType(subType);
        pDealItem:SetValueType(valueType);

        if (not pDealItem:IsValid(pDeal)) then
          pDeal:RemoveItemByID(pDealItem:GetID());
        end
        UpdateDealPanel(player);
        UpdateProposedWorkingDeal();
      end
    end
  end

  UI.PlaySound("UI_GreatWorks_Put_Down");

end

-- ===========================================================================
function OnRemoveDealItem(player, itemID)
  if (ms_bIsDemand == true and ms_InitiatedByPlayerID == ms_OtherPlayerID) then
    -- Can't remove it
    return;
  end

  DetachValueEdit(itemID);

  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  if (pDeal ~= nil) then

    local pDealItem = pDeal:FindItemByID(itemID);
    if (pDealItem ~= nil) then
      if (not pDealItem:IsLocked()) then
        if (pDeal:RemoveItemByID(itemID)) then
          UpdateDealPanel(player);
          UpdateProposedWorkingDeal();
          UI.PlaySound("UI_GreatWorks_Pick_Up");
        end
      end
    end
  end
end

-- ===========================================================================
function OnSelectValueDealItem(player, itemID, controlInstance)

  if (ms_bIsDemand == true and ms_InitiatedByPlayerID == ms_OtherPlayerID) then
    -- Can't edit it
    return;
  end

  if (controlInstance ~= nil) then
    AttachValueEdit(controlInstance, itemID);
  end
end

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
function getImportedResources(playerID)
  local importedResources :table = {};
  local kPlayers          :table = PlayerManager.GetAliveMajors();

  for _, pOtherPlayer in ipairs(kPlayers) do
    local otherID:number = pOtherPlayer:GetID();
    if ( otherID ~= playerID ) then
      local pPlayerConfig :table = PlayerConfigurations[otherID];
      local pDeals        :table = DealManager.GetPlayerDeals(playerID, otherID); -- ARISTOS: double filter Resources!
      local isNotCheat	:boolean = (playerID == Game.GetLocalPlayer()) or (otherID == Game.GetLocalPlayer()); -- ARISTOS: non-cheat CQUI policy

      if ( pDeals ~= nil and isNotCheat) then --ARISTOS: show only if local player is the importer or the exporter!!!
        for i,pDeal in ipairs(pDeals) do
          --if ( pDeal:IsValid() ) then --!! ARISTOS: Bug??? deal:IsValid() not always returns true even if the deal IS valid!!!
            -- Add incoming resource deals
            local pDealResources = pDeal:FindItemsByType(DealItemTypes.RESOURCES, DealItemSubTypes.NONE, otherID);
            if ( pDealResources ~= nil ) then
              for j,pDealResource in ipairs(pDealResources) do
                local pClassType = GameInfo.Resources[pDealResource:GetValueType()].ResourceClassType;
                local ending:number = pDealResource:GetEndTurn() - Game.GetCurrentGameTurn();
                local convertedResources = {
                  Name = tostring(pDealResource:GetValueType());
                  ForType = pDealResource:GetValueType();
                  MaxAmount = pDealResource:GetAmount();
                  ClassType = pClassType;
                  -- ARISTOS: Show the deal's other civ's identity only if it is the local player.
                  ImportString = Locale.Lookup("LOC_IDS_DEAL_TRADE") .. " " .. ((otherID == Game.GetLocalPlayer() or playerID == Game.GetLocalPlayer())
                    and Locale.Lookup(PlayerConfigurations[otherID]:GetPlayerName()) or "another civ") .. " (" .. ending .. "[ICON_Turn])" .. " : " .. pDealResource:GetAmount();
                };
                -- !!ARISTOS: To group resources imported from different sources into a single icon!!!
                local isIncluded:boolean = false;
                local isIndex:number = 0;
                for k,impResource in ipairs(importedResources) do
                  if (impResource.Name == convertedResources.Name) then
                    isIncluded = true;
                    isIndex = k;
                    break;
                  end
                end
                if (isIncluded) then
                  local existingResource = importedResources[isIndex];
                  local newResource = {
                    Name = existingResource.Name;
                    ForType = existingResource.ForType;
                    MaxAmount  = existingResource.MaxAmount + convertedResources.MaxAmount;
                    ClassType = existingResource.ClassType;
                    ImportString = existingResource.ImportString .. "[NEWLINE]" .. convertedResources.ImportString;
                  };
                  importedResources[isIndex] = newResource;
                else
                  table.insert(importedResources, convertedResources);
                end
                -- END ARISTOS grouping of imported resources
                --table.insert(importedResources, convertedResources);
              end
            end
          --end
        end
      end
    end
  end

  -- Add resources provided by city states
  for i, pMinorPlayer in ipairs(PlayerManager.GetAliveMinors()) do
    local pMinorPlayerInfluence:table = pMinorPlayer:GetInfluence();
    local hasMetLocalPlayer: boolean = Players[Game.GetLocalPlayer()]:GetDiplomacy():HasMet( pMinorPlayer:GetID() ); --ARISTOS: CQUI anti-cheat policy
    if (pMinorPlayerInfluence ~= nil and hasMetLocalPlayer) then --ARISTOS: show only if local player has met the City State!!!
      local suzerainID:number = pMinorPlayerInfluence:GetSuzerain();
      if suzerainID == playerID then
        for row in GameInfo.Resources() do

          local resourceAmount:number =  pMinorPlayer:GetResources():GetExportedResourceAmount(row.Index);

          if resourceAmount > 0 then
            local kResource :table = GameInfo.Resources[row.Index];
            local cityStateResources = {
              Name = tostring(row.Index);--kResource.ResourceType);
              ForType = kResource.ResourceType;
              MaxAmount = resourceAmount;
              ClassType = kResource.ResourceClassType;
              ImportString = Locale.Lookup("LOC_IDS_DEAL_SUZERAIN").." " .. Locale.Lookup(PlayerConfigurations[pMinorPlayer:GetID()]:GetPlayerName()) .. " : " .. resourceAmount;
              };
            -- !!ARISTOS: To group resources imported from different sources into a single icon!!!
            local isIncluded:boolean = false;
            local isIndex:number = 0;
            for k,impResource in ipairs(importedResources) do
              if (impResource.Name == cityStateResources.Name) then
                isIncluded = true;
                isIndex = k;
                break;
              end
            end
            if isIncluded then
              local existingResource = importedResources[isIndex];
              local newResource = {
                Name = existingResource.Name;
                ForType = existingResource.ForType;
                MaxAmount  = existingResource.MaxAmount + cityStateResources.MaxAmount;
                ClassType = existingResource.ClassType;
                ImportString = existingResource.ImportString .. "[NEWLINE]" .. cityStateResources.ImportString;
              };
              importedResources[isIndex] = newResource;
            else
              table.insert(importedResources, cityStateResources);
            end
            -- END ARISTOS grouping of imported resources
            --table.insert(importedResources, cityStateResources);
          end
        end
      end
    end
  end

  return importedResources;
end

-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

function MatchesPartnerResource(partnerResourceTable, targetResourceType)
  for j, partnerEntry in ipairs(partnerResourceTable) do
    local partnerResourceDesc =  GameInfo.Resources[partnerEntry.ForType];
    if (partnerResourceDesc.ResourceType == targetResourceType) then
      return j;
    end
  end

  return -1;
end

-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
function PopulateAvailableResources(player : table, iconList : table, className : string)

  local iAvailableItemCount = 0;
  local pForDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  local playerResources = DealManager.GetPossibleDealItems(player:GetID(), GetOtherPlayer(player):GetID(), DealItemTypes.RESOURCES, pForDeal);
  local playerDuplicateResources = {};
  local playerUntradeableResources = {};
  local playerImportedResources = getImportedResources(player:GetID());
  local partnerResources = DealManager.GetPossibleDealItems(GetOtherPlayer(player):GetID(), player:GetID(), DealItemTypes.RESOURCES);
  local partnerImportedResources = getImportedResources(GetOtherPlayer(player):GetID());
  local icon;

  if (playerResources ~= nil) then

  -- sort by quantity
  local sort_func = function( a,b ) return tonumber(a.MaxAmount) > tonumber(b.MaxAmount) end;
  table.sort( playerResources, sort_func );

    for i, entry in ipairs(playerResources) do
      local resourceDesc = GameInfo.Resources[entry.ForType];
      local resourceType = entry.ForType;

      if (resourceDesc ~= nil and resourceDesc.ResourceClassType == className) then -- correct resource class
        --playerResources[resourceType] = nil;
      --else
        -- Check if all copies have been traded away
        if (entry.MaxAmount == 0) then
          table.insert(playerUntradeableResources, playerResources[i]);
          --playerResources[resourceType] = nil;

        -- Check if partner already has the resource
        elseif (MatchesPartnerResource(partnerResources, resourceDesc.ResourceType) > -1 or MatchesPartnerResource(partnerImportedResources, resourceDesc.ResourceType) > -1) then
          table.insert(playerDuplicateResources, playerResources[i]);
          --playerResources[resourceType] = nil;

        -- Tradeable item
        else
          local tradeableType;
          if(entry.MaxAmount == 1) then
            tradeableType = 'scarce';
          else
            tradeableType =	'default';
          end

          icon = RenderResourceButton(entry, tradeableType, iconList);
          -- What to do when double clicked/tapped.
          icon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableResource(player, resourceType); end );
          iAvailableItemCount = iAvailableItemCount + 1;
        end
      end
    end

    iconList.ListStack:CalculateSize();
    iconList.List:ReprocessAnchoring();
  end

  if (playerDuplicateResources ~= nil) then
    for z, entry in ipairs(playerDuplicateResources) do
      tradeableType = 'duplicate';
      icon = RenderResourceButton(entry, tradeableType, iconList);
      icon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableResource(player, entry.ForType); end );
      iAvailableItemCount = iAvailableItemCount + 1;
    end
  end

  if (playerUntradeableResources ~= nil) then
    for x, entry in ipairs(playerUntradeableResources) do
      tradeableType = 'none';
      icon = RenderResourceButton(entry, tradeableType, iconList, entry.ImportString);
      icon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableResource(player, entry.ForType); end );
      iAvailableItemCount = iAvailableItemCount + 1;
    end
  end

  if(playerImportedResources ~= nil) then
    for y, entry in ipairs(playerImportedResources) do
      if (entry.ClassType == className) then
        tradeableType = 'imported';
        icon = RenderResourceButton(entry, tradeableType, iconList, entry.ImportString);
        icon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableResource(player, entry.ForType); end );
        iAvailableItemCount = iAvailableItemCount + 1;
      end
    end
  end

  iconList.ListStack:CalculateSize();
  iconList.List:ReprocessAnchoring();

  -- Hide if empty
  iconList.GetTopControl():SetHide( iconList.ListStack:GetSizeX()==0 );

  return iAvailableItemCount;
end

-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
function RenderResourceButton(resource, resourceCategory, iconList, howAcquired)
  resourceDesc = GameInfo.Resources[resource.ForType];
  local icon;
  local tooltipAddedText = '';
  local buttonDisabled = false;

  if(resourceCategory == 'scarce') then
    icon = ms_IconOnly_Resource_ScarceIM:GetInstance(iconList.ListStack);
  elseif(resourceCategory == 'duplicate') then
    icon = ms_IconOnly_Resource_DuplicateIM:GetInstance(iconList.ListStack);
    tooltipAddedText = ' (' .. Locale.Lookup("LOC_IDS_DEAL_DUPLICATE") .. ')';
  elseif(resourceCategory == 'none' or resourceCategory == 'imported') then
    icon = ms_IconOnly_Resource_UntradeableIM:GetInstance(iconList.ListStack);
    tooltipAddedText = ' (' .. Locale.Lookup("LOC_IDS_DEAL_UNTRADEABLE") .. ')';
    buttonDisabled = true;
  else
    icon = ms_IconOnlyIM:GetInstance(iconList.ListStack);
  end

  SetIconToSize(icon.Icon, "ICON_" .. resourceDesc.ResourceType, icon.Icon:GetSizeX());
  icon.AmountText:SetText(tostring(resource.MaxAmount));
  icon.SelectButton:SetDisabled( buttonDisabled );

  local tooltipString = Locale.Lookup(resourceDesc.Name) .. tooltipAddedText;
  if (howAcquired ~= nil) then
    tooltipString = tooltipString .. '[NEWLINE]' .. howAcquired;
  end

  icon.SelectButton:SetToolTipString(tooltipString);
  icon.SelectButton:ReprocessAnchoring();

  return icon;

end

-- ===========================================================================
function PopulateAvailableLuxuryResources(player : table, iconList : table)
  local iAvailableItemCount = 0;
  iAvailableItemCount = iAvailableItemCount + PopulateAvailableResources(player, iconList, "RESOURCECLASS_LUXURY");
  return iAvailableItemCount;
end

-- ===========================================================================
function PopulateAvailableStrategicResources(player : table, iconList : table)

  local iAvailableItemCount = 0;
  iAvailableItemCount = iAvailableItemCount + PopulateAvailableResources(player, iconList, "RESOURCECLASS_STRATEGIC");
  return iAvailableItemCount;
end

-- ===========================================================================
function PopulateAvailableAgreements(player : table, iconList : table)

  local iAvailableItemCount = 0;
  local pForDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  local possibleAgreements = DealManager.GetPossibleDealItems(player:GetID(), GetOtherPlayer(player):GetID(), DealItemTypes.AGREEMENTS, pForDeal);

  -- sort alpha
  local sort_func = function( a,b ) return a.SubTypeName < b.SubTypeName end;
  table.sort( possibleAgreements, sort_func );

  if (possibleAgreements ~= nil) then
    for i, entry in ipairs(possibleAgreements) do
      local agreementType = entry.SubType;

      local agreementDuration = entry.Duration;
      local icon = ms_IconAndTextIM:GetInstance(iconList.ListStack);

      local info: table = GameInfo.DiplomaticActions[ agreementType ];
      if (info ~= nil) then
        -- AZURENCY : Hack to get the agreementType of RESEARCH_AGREEMENT (seems to be a bug ? it's not in DealAgreementTypes)
        if (ms_DealAgreementTypesResearchAgreement == nil and info.DiplomaticActionType == "DIPLOACTION_RESEARCH_AGREEMENT") then
          ms_DealAgreementTypesResearchAgreement = agreementType;
        end
        SetIconToSize(icon.Icon, "ICON_".. info.DiplomaticActionType, 38);
      end
      icon.AmountText:SetHide(true);
      icon.IconText:LocalizeAndSetText(entry.SubTypeName);
      icon.SelectButton:SetDisabled( not entry.IsValid and entry.ValidationResult ~= DealValidationResult.MISSING_DEPENDENCY );	-- Hide if invalid, unless it is just missing a dependency, the user will update that when it is added to the deal.
      icon.ValueText:SetHide(true);

      -- What to do when double clicked/tapped.
      icon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableAgreement(player, agreementType, agreementDuration); end );
      -- Set a tool tip if their is a duration
      if (entry.Duration > 0) then
        local szTooltip = Locale.Lookup("LOC_DIPLOMACY_DEAL_PARAMETER_WITH_TURNS", entry.SubTypeName, entry.Duration);
        icon.SelectButton:SetToolTipString(szTooltip);
      else
        icon.SelectButton:SetToolTipString(nil);
      end

      -- icon.SelectButton:LocalizeAndSetToolTip( );
      icon.SelectButton:ReprocessAnchoring();

      iAvailableItemCount = iAvailableItemCount + 1;
    end

    iconList.ListStack:CalculateSize();
    iconList.List:ReprocessAnchoring();
  end

  -- Hide if empty
  iconList.GetTopControl():SetHide( iconList.ListStack:GetSizeX()==0 );

  return iAvailableItemCount;
end

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
function MakeCityToolTip(pCity : table)
  local cityData = GetCityData(pCity);
  local isLocalPlayerCity = pCity:GetOwner() == Game.GetLocalPlayer();
  if (pCity ~= nil) then
    local szToolTip = Locale.ToUpper( Locale.Lookup(cityData.CityName)) .. "[NEWLINE]";
    szToolTip = szToolTip .. Locale.Lookup("LOC_DEAL_CITY_POPULATION_TOOLTIP", pCity:GetPopulation()) .. "[NEWLINE]";
    if isLocalPlayerCity then --ARISTOS: only show detailed info for cities owned or occupied by local player! CQUI non-cheat policy
      szToolTip = szToolTip .. "[ICON_Food]" .. toPlusMinusString(cityData.FoodPerTurn) .. " ";
      szToolTip = szToolTip .. "[ICON_Production]" .. toPlusMinusString(cityData.ProductionPerTurn) .. " ";
      szToolTip = szToolTip .. "[ICON_Science]" .. toPlusMinusString(cityData.SciencePerTurn) .. " ";
      szToolTip = szToolTip .. "[ICON_Culture]" .. toPlusMinusString(cityData.CulturePerTurn) .. " ";
      szToolTip = szToolTip .. "[ICON_Faith]" .. toPlusMinusString(cityData.FaithPerTurn) .. " ";
      szToolTip = szToolTip .. "[ICON_Gold]" .. toPlusMinusString(cityData.GoldPerTurn);
    end
    local districtNames = {};
    local pCityDistricts = pCity:GetDistricts();
    if (pCityDistricts ~= nil) then

      for i, pDistrict in pCityDistricts:Members() do
        local pDistrictDef = GameInfo.Districts[ pDistrict:GetType() ];
        if (pDistrictDef ~= nil) then
          local districtType:string = pDistrictDef.DistrictType;
          -- Skip the city center and any wonder districts
          if (districtType ~= "DISTRICT_CITY_CENTER" and districtType ~= "DISTRICT_WONDER") then
            table.insert(districtNames, pDistrictDef.Name);
          end
        end
      end
    end

    if (#districtNames > 0) then
      szToolTip = szToolTip .. "[NEWLINE]" .. Locale.Lookup("LOC_DEAL_CITY_DISTRICTS_TOOLTIP");
      for i, name in ipairs(districtNames) do
        szToolTip = szToolTip .. "[NEWLINE]" .. Locale.Lookup(name);
      end
    end

    local player = Players[pCity:GetOwner()];
    local cityID = pCity:GetID();

    -- Add Resources
    local extractedResources = player:GetResources():GetResourcesExtractedByCity( cityID, ResultFormat.SUMMARY );
    if extractedResources ~= nil and #extractedResources > 0 then
      szToolTip = szToolTip .. "[NEWLINE]" .. Locale.Lookup("LOC_DEAL_CITY_RESOURCES_TOOLTIP");
      for i, entry in ipairs(extractedResources) do
        local resourceDesc = GameInfo.Resources[entry.ResourceType];
        if resourceDesc ~= nil then
          szToolTip = szToolTip .. "[NEWLINE]" .. Locale.Lookup(resourceDesc.Name) .. " : " .. tostring(entry.Amount);
        end
      end
    end

    -- Add Great Works
    local cityGreatWorks = player:GetCulture():GetGreatWorksInCity( cityID );
    if cityGreatWorks ~= nil and #cityGreatWorks > 0 then
      szToolTip = szToolTip .. "[NEWLINE]" .. Locale.Lookup("LOC_DEAL_CITY_GREAT_WORKS_TOOLTIP");
      for i, entry in ipairs(cityGreatWorks) do
        local greatWorksDesc = GameInfo.GreatWorks[entry.GreatWorksType];
        if greatWorksDesc ~= nil then
          szToolTip = szToolTip .. "[NEWLINE]" .. Locale.Lookup(greatWorksDesc.Name);
        end
      end
    end

    return szToolTip;
  end

  return "";
end

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
function renderCity(pCity : table, player : table, targetContainer : table)
  local button = ms_IconAndTextWithDetailsIM:GetInstance(targetContainer);
  local cityData = GetCityData(pCity);
  local otherPlayer = GetOtherPlayer(player);

  SetIconToSize(button.Icon, "ICON_BUILDINGS", 30);
  button.IconText:LocalizeAndSetText(cityData.CityName);
  --button.SelectButton:SetDisabled( not entry.IsValid and entry.ValidationResult ~= DealValidationResult.MISSING_DEPENDENCY );	-- Hide if invalid, unless it is just missing a dependency, the user will update that when it is added to the deal.

  if pCity:IsOccupied() then
    -- Cede
    if pCity:GetOwner() == otherPlayer:GetID() then
      button.IconText:SetText(button.IconText:GetText() .. '[COLOR_Civ6Green] - ' .. Locale.Lookup("LOC_IDS_DEAL_CEDE") .. '[ENDCOLOR]'); 
      button.SelectButton:SetTextureOffsetVal(0, 64);
    -- Return
    else
      if pCity:GetOriginalOwner() == otherPlayer:GetID() then
        button.IconText:SetText(button.IconText:GetText() .. '[COLOR_Civ6Red] - ' .. Locale.Lookup("LOC_IDS_DEAL_RETURN") .. '[ENDCOLOR]'); 
        button.SelectButton:SetTextureOffsetVal(0, 96);
      end
    end
  else
    button.SelectButton:SetTextureOffsetVal(0, 0);
  end

  button.PopulationLabel:SetText(tostring(cityData.Population));
  --ARISTOS: only show detailed info for cities owned or occupied by local player! CQUI non-cheat policy
  if pCity:GetOwner() == Game.GetLocalPlayer() then
    button.FoodLabel:SetText("[ICON_FOOD]" .. toPlusMinusString(cityData.FoodPerTurn));
    button.ProductionLabel:SetText("[ICON_PRODUCTION]" .. toPlusMinusString(cityData.ProductionPerTurn));
    button.ScienceLabel:SetText("[ICON_SCIENCE]" .. toPlusMinusString(cityData.SciencePerTurn));
  else
    button.FoodLabel:SetText("");
    button.ProductionLabel:SetText("");
    button.ScienceLabel:SetText("");
  end
  button.SelectButton:SetToolTipString( MakeCityToolTip(pCity) );
  button.UnacceptableIcon:SetHide(true); -- AZURENCY : Sometime the icon is shown so always hide it

  return button;
end

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
function PopulateAvailableCities(player : table, iconList : table)
  local iAvailableItemCount = 0;
  local pForDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  local possibleItems = DealManager.GetPossibleDealItems(player:GetID(), GetOtherPlayer(player):GetID(), DealItemTypes.CITIES, pForDeal);
  local otherPlayer = GetOtherPlayer(player);
  local occupiedCities = {};

  if (possibleItems ~= nil) then
    local sort_func = function( a,b ) return a.ForTypeName < b.ForTypeName end;
    local sort_func_reverse = function( a,b ) return b.ForTypeName < a.ForTypeName end;

  -- Sort items as follows: Occupied cities alphabetically, then non-occupied cities alphabetically
    for i, entry in ipairs(possibleItems) do
      local type = entry.ForType;
      local pCity = player:GetCities():FindID( type );
      -- Handle occupied cities
      if pCity == nil then
        pCity = otherPlayer:GetCities():FindID( type );
      end

      -- Move occupied cities to their own table temporarily so they can be sorted alpha separately
      if player:GetDiplomacy():IsAtWarWith(otherPlayer) or otherPlayer:GetDiplomacy():IsAtWarWith(player) then
        if pCity:IsOccupied() then
          table.insert(occupiedCities, possibleItems[i]);
          table.remove(possibleItems, i);
        end
      end
    end

    -- sort remaining (non-occupied) alpha
    table.sort(possibleItems, sort_func);

    if occupiedCities ~= nil then
      -- sort occupied reverse alpha, so when we resert at top of possible items, they are in correct order
      table.sort(occupiedCities, sort_func_reverse);

      -- re-insert occupied at top
      for j, entry in ipairs(occupiedCities) do
        table.insert(possibleItems, 1, occupiedCities[j]);
      end

      occupiedCities = nil;
    end
  -- End Sorting

    for i, entry in ipairs(possibleItems) do

      local type = entry.ForType;
      local subType = entry.SubType;
      local pCity = player:GetCities():FindID( type );
      -- Handle occupied cities
      if pCity == nil or (entry.ForTypeName ~= GetCityData(pCity).CityName and not pCity:IsOccupied()) then --ARISTOS
        pCity = otherPlayer:GetCities():FindID( type );
        -- AZURENCY : fix for persia not having occupation penalties
        if pCity == nil then
          pCity = player:GetCities():FindID(valueType);
        end
      end

      local icon = renderCity(pCity, player, iconList.ListStack);

      icon.SelectButton:ReprocessAnchoring();
      iAvailableItemCount = iAvailableItemCount + 1;

      -- What to do when double clicked/tapped.
      icon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableCity(player, type, subType); end );
    end

    iconList.ListStack:CalculateSize();
    iconList.List:ReprocessAnchoring();
  end

  -- Hide if empty
  iconList.GetTopControl():SetHide( iconList.ListStack:GetSizeX()==0 );

  return iAvailableItemCount;
end

-- ===========================================================================
function PopulateAvailableOtherPlayers(player : table, iconList : table)

  local iAvailableItemCount = 0;
  -- Hide if empty
  iconList.GetTopControl():SetHide( iconList.ListStack:GetSizeX()==0 );

  return iAvailableItemCount;
end

-- ===========================================================================
function PopulateAvailableGreatWorks(player : table, iconList : table)

  local iAvailableItemCount = 0;
  local pForDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  local possibleItems = DealManager.GetPossibleDealItems(player:GetID(), GetOtherPlayer(player):GetID(), DealItemTypes.GREATWORK, pForDeal);
  if (possibleItems ~= nil) then
    -- Sort by great work type
    local sort_func = function( a,b ) return a.ForTypeDescriptionID < b.ForTypeDescriptionID end;
    table.sort( possibleItems, sort_func );

    for i, entry in ipairs(possibleItems) do

      local greatWorkDesc = GameInfo.GreatWorks[entry.ForTypeDescriptionID];
      if (greatWorkDesc ~= nil) then
        local type = entry.ForType;
        local icon = ms_IconAndTextIM:GetInstance(iconList.ListStack);
        SetIconToSize(icon.Icon, "ICON_" .. greatWorkDesc.GreatWorkType, 42);
        icon.AmountText:SetHide(true);
        if (entry.ForTypeName ~= nil ) then
                    icon.IconText:LocalizeAndSetText(entry.ForTypeName);
        end
        icon.SelectButton:SetDisabled( not entry.IsValid and entry.ValidationResult ~= DealValidationResult.MISSING_DEPENDENCY );	-- Hide if invalid, unless it is just missing a dependency, the user will update that when it is added to the deal.
        icon.ValueText:SetHide(true);

        -- What to do when double clicked/tapped.
        icon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableGreatWork(player, type); end );
        -- Set a tool tip


        --CQUI Changes
        -- local yieldType:string = CQUI_GreatWork_YieldChanges[greatWorkDesc.GreatWorkType].YieldType;
        -- local yieldValue:number = CQUI_GreatWork_YieldChanges[greatWorkDesc.GreatWorkType].YieldChange;
        -- local greatWorkYields:string = YIELD_FONT_ICONS[yieldType] .. yieldValue .. " [ICON_TourismLarge]" .. greatWorkDesc.Tourism;
        -- local tooltipText:string;
        -- local greatWorkTypeName:string;

        -- if (greatWorkDesc.EraType ~= nil) then
        --   greatWorkTypeName = Locale.Lookup("LOC_" .. greatWorkDesc.GreatWorkObjectType .. "_" .. greatWorkDesc.EraType);
        -- else
        --   greatWorkTypeName = Locale.Lookup("LOC_" .. greatWorkDesc.GreatWorkObjectType);
        -- end
        -- tooltipText = Locale.Lookup(greatWorkDesc.Name) .. " (" .. greatWorkTypeName .. ")[NEWLINE]" .. greatWorkYields;
        local tooltipText = GreatWorksSupport_GetBasicTooltip(entry.ForType, false);
        icon.SelectButton:SetToolTipString(tooltipText);
        --end CQUI Changes

        icon.SelectButton:ReprocessAnchoring();

        iAvailableItemCount = iAvailableItemCount + 1;
      end
    end

    iconList.ListStack:CalculateSize();
    iconList.List:ReprocessAnchoring();
  end

  -- Hide if empty
  iconList.GetTopControl():SetHide( iconList.ListStack:GetSizeX()==0 );

  return iAvailableItemCount;

end

-- ===========================================================================
function PopulateAvailableCaptives(player : table, iconList : table)

  local iAvailableItemCount = 0;

  local pForDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  local possibleItems = DealManager.GetPossibleDealItems(player:GetID(), GetOtherPlayer(player):GetID(), DealItemTypes.CAPTIVE, pForDeal);
  if (possibleItems ~= nil) then
    -- Sort by cpative name
    local sort_func = function( a,b ) return a.ForTypeName < b.ForTypeName end;
    table.sort( possibleItems, sort_func );

    for i, entry in ipairs(possibleItems) do

      local type = entry.ForType;
      local icon = ms_IconAndTextIM:GetInstance(iconList.ListStack);
      SetIconToSize(icon.Icon, "ICON_UNIT_SPY", 38);
      icon.AmountText:SetHide(true);
      icon.IconText:LocalizeAndSetText(entry.ForTypeName);
      icon.SelectButton:SetDisabled( not entry.IsValid and entry.ValidationResult ~= DealValidationResult.MISSING_DEPENDENCY );	-- Hide if invalid, unless it is just missing a dependency, the user will update that when it is added to the deal.
      icon.ValueText:SetHide(true);

      -- What to do when double clicked/tapped.
      icon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableCaptive(player, type); end );
      icon.SelectButton:SetToolTipString(nil);		-- We recycle the entries, so make sure this is clear.
      icon.SelectButton:ReprocessAnchoring();

      iAvailableItemCount = iAvailableItemCount + 1;
    end

    iconList.ListStack:CalculateSize();
    iconList.List:ReprocessAnchoring();
  end

  -- Hide if empty
  iconList.GetTopControl():SetHide( iconList.ListStack:GetSizeX()==0 );

  return iAvailableItemCount;
end

-- ===========================================================================
function PopulatePlayerAvailablePanel(rootControl : table, player : table)

  local iAvailableItemCount = 0;

  if (player ~= nil) then

    local playerType = GetPlayerType(player);
    if (ms_bIsDemand and player:GetID() == ms_InitiatedByPlayerID) then
      -- This is a demand, so hide all the demanding player's items
      for i = 1, AvailableDealItemGroupTypes.COUNT, 1 do
        ms_AvailableGroups[i][playerType].GetTopControl():SetHide(true);
      end
    else
      ms_AvailableGroups[AvailableDealItemGroupTypes.GOLD][playerType].GetTopControl():SetHide(false);

      iAvailableItemCount = iAvailableItemCount + PopulateAvailableGold(player, ms_AvailableGroups[AvailableDealItemGroupTypes.GOLD][playerType]);
      iAvailableItemCount = iAvailableItemCount + PopulateAvailableLuxuryResources(player, ms_AvailableGroups[AvailableDealItemGroupTypes.LUXURY_RESOURCES][playerType]);
      iAvailableItemCount = iAvailableItemCount + PopulateAvailableStrategicResources(player, ms_AvailableGroups[AvailableDealItemGroupTypes.STRATEGIC_RESOURCES][playerType]);

      if (not ms_bIsDemand) then
        iAvailableItemCount = iAvailableItemCount + PopulateAvailableAgreements(player, ms_AvailableGroups[AvailableDealItemGroupTypes.AGREEMENTS][playerType]);
      else
        ms_AvailableGroups[AvailableDealItemGroupTypes.AGREEMENTS][playerType].GetTopControl():SetHide(true);
      end

      iAvailableItemCount = iAvailableItemCount + PopulateAvailableCities(player, ms_AvailableGroups[AvailableDealItemGroupTypes.CITIES][playerType]);

      if (not ms_bIsDemand) then
        iAvailableItemCount = iAvailableItemCount + PopulateAvailableOtherPlayers(player, ms_AvailableGroups[AvailableDealItemGroupTypes.OTHER_PLAYERS][playerType]);
      else
        ms_AvailableGroups[AvailableDealItemGroupTypes.OTHER_PLAYERS][playerType].GetTopControl():SetHide(false);
      end

      iAvailableItemCount = iAvailableItemCount + PopulateAvailableGreatWorks(player, ms_AvailableGroups[AvailableDealItemGroupTypes.GREAT_WORKS][playerType]);
      iAvailableItemCount = iAvailableItemCount + PopulateAvailableCaptives(player, ms_AvailableGroups[AvailableDealItemGroupTypes.CAPTIVES][playerType]);

    end

    rootControl:CalculateSize();
    rootControl:ReprocessAnchoring();

  end

  return iAvailableItemCount;
end

-- ===========================================================================
function PopulateDealBasic(player : table, iconList : table, populateType : number, iconName : string)

  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  local playerType = GetPlayerType(player);
  if (pDeal ~= nil) then

    local pDealItem;
    for pDealItem in pDeal:Items() do
      local type = pDealItem:GetType();
      if (pDealItem:GetFromPlayerID() == player:GetID()) then
        local iDuration = pDealItem:GetDuration();
        local dealItemID = pDealItem:GetID();

        if (type == populateType) then
          local icon = ms_IconAndTextIM:GetInstance(iconList.ListStack);
          SetIconToSize(icon.Icon, iconName, 38);
          icon.AmountText:SetHide(true);
          local typeName = pDealItem:GetValueTypeNameID();
          if (typeName ~= nil) then
            icon.IconText:LocalizeAndSetText(typeName);
          end

          -- Show/hide unacceptable item notification
          icon.UnacceptableIcon:SetHide(not pDealItem:IsUnacceptable());

          icon.SelectButton:RegisterCallback(Mouse.eRClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);
          icon.SelectButton:RegisterCallback( Mouse.eLClick, function(void1, void2, self) OnSelectValueDealItem(player, dealItemID, self); end );

          icon.SelectButton:SetToolTipString(nil);		-- We recycle the entries, so make sure this is clear.
        end
      end
    end

    iconList.ListStack:CalculateSize();
    iconList.ListStack:ReprocessAnchoring();

  end

end

-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
function PopulateDealGold(player : table, iconList : table)
  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  local playerType = GetPlayerType(player);
  if (pDeal ~= nil) then
    ms_IconOnlyIM:ReleaseInstanceByParent(iconList.ListStack);
    ms_IconOnly_3IM:ReleaseInstanceByParent(iconList.ListStack);

    local pDealItem;
    for pDealItem in pDeal:Items() do
      local type = pDealItem:GetType();
      if (pDealItem:GetFromPlayerID() == player:GetID()) then
        local iDuration = pDealItem:GetDuration();
        local dealItemID = pDealItem:GetID();
        if (type == DealItemTypes.GOLD) then
          local icon;

          if (iDuration == 0) then
            -- One time
            icon = ms_IconOnlyIM:GetInstance(iconList.ListStack);
            SetIconToSize(icon.Icon, "ICON_YIELD_GOLD_5");
          else
            -- Multi-turn
            icon = ms_IconOnly_3IM:GetInstance(iconList.ListStack);
            SetIconToSize(icon.Icon1, "ICON_YIELD_GOLD_1");
            SetIconToSize(icon.Icon2, "ICON_YIELD_GOLD_1");
            SetIconToSize(icon.Icon3, "ICON_YIELD_GOLD_1");
          end

          icon.AmountText:SetText(tostring(pDealItem:GetAmount()));
          icon.AmountText:SetHide(false);

          -- Show/hide unacceptable item notification
          icon.UnacceptableIcon:SetHide(not pDealItem:IsUnacceptable());

          icon.SelectButton:RegisterCallback(Mouse.eRClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);
          icon.SelectButton:RegisterCallback( Mouse.eLClick, function(void1, void2, self) OnSelectValueDealItem(player, dealItemID, self); end );
          icon.SelectButton:SetToolTipString(nil);		-- We recycle the entries, so make sure this is clear.
          if (dealItemID == ms_ValueEditDealItemID) then
            ms_ValueEditDealItemControlTable = icon;
          end
        end
      end
    end

    iconList.ListStack:CalculateSize();
    iconList.ListStack:ReprocessAnchoring();

    ReAttachValueEdit();
  end
end

-- ===========================================================================
function GetParentItemTransferToolTip(parentDealItem)
  local szToolTip = "";

  -- If it is from a city, put the city name in the tool tip.
  if (parentDealItem:GetType() == DealItemTypes.CITIES) then

    local cityTypeName = parentDealItem:GetValueTypeNameID();
    if (cityTypeName ~= nil) then
      local cityName = Locale.Lookup(cityTypeName);
      local szTransfer = Locale.Lookup("LOC_DEAL_ITEM_TRANSFERRED_WITH_CITY_TOOLTIP", cityName);

      szToolTip = "[NEWLINE]" .. szTransfer;
    end
  end

  return szToolTip;
end

-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
function PopulateDealResources(player : table, iconList : table, className)

  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  local playerType = GetPlayerType(player);
  if (pDeal ~= nil) then
    ms_IconOnlyIM:ReleaseInstanceByParent(iconList.ListStack);
    ms_IconOnly_Resource_ScarceIM:ReleaseInstanceByParent(iconList.ListStack);
    ms_IconOnly_Resource_DuplicateIM:ReleaseInstanceByParent(iconList.ListStack);
    ms_IconOnly_Resource_UntradeableIM:ReleaseInstanceByParent(iconList.ListStack);
    local pDealItem;
    for pDealItem in pDeal:Items() do
      local type = pDealItem:GetType();
      if (pDealItem:GetFromPlayerID() == player:GetID()) then
        local iDuration = pDealItem:GetDuration();
        local dealItemID = pDealItem:GetID();

        if (type == DealItemTypes.RESOURCES) then
          local resourceType = pDealItem:GetValueType();
          local resourceDesc = GameInfo.Resources[resourceType];

          if (resourceDesc.ResourceClassType ~= className) then -- wrong resource type; null
            pDeal[resourceType] = nil;
          else
            local icon = ms_IconOnlyIM:GetInstance(iconList.ListStack);
            SetIconToSize(icon.Icon, "ICON_" .. resourceDesc.ResourceType);
            icon.AmountText:SetText(tostring(pDealItem:GetAmount()));
            icon.AmountText:SetHide(false);

            -- Show/hide unacceptable item notification
            icon.UnacceptableIcon:SetHide(not pDealItem:IsUnacceptable());

            icon.SelectButton:RegisterCallback(Mouse.eRClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);
            icon.SelectButton:RegisterCallback( Mouse.eLClick, function(void1, void2, self) OnSelectValueDealItem(player, dealItemID, self); end );
            -- Set a tool tip
            icon.SelectButton:LocalizeAndSetToolTip(resourceDesc.Name);

            -- KWG: Make a way for the icon manager to have categories, so the API is like this
            -- icon.Icon:SetTexture(IconManager:FindIconAtlasForType(IconTypes.RESOURCE, resourceType));

            if (dealItemID == ms_ValueEditDealItemID) then
              ms_ValueEditDealItemControlTable = icon;
            end
          end
        end
      end -- end for each item in dael
    end -- end if deal

    iconList.ListStack:CalculateSize();
    iconList.ListStack:ReprocessAnchoring();

  end

end


-- ===========================================================================
function PopulateDealAgreements(player : table, iconList : table)

  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  local playerType = GetPlayerType(player);
  if (pDeal ~= nil) then
    ms_IconAndTextIM:ReleaseInstanceByParent(iconList.ListStack);

    local pDealItem;
    for pDealItem in pDeal:Items() do
      local type = pDealItem:GetType();
      if (pDealItem:GetFromPlayerID() == player:GetID()) then
        local dealItemID = pDealItem:GetID();
        -- Agreement?
        if (type == DealItemTypes.AGREEMENTS) then
          local icon = ms_IconAndTextIM:GetInstance(iconList.ListStack);
          local info: table = GameInfo.DiplomaticActions[ pDealItem:GetSubType() ];
          if (info ~= nil) then
            SetIconToSize(icon.Icon, "ICON_".. info.DiplomaticActionType, 38);
          end

          icon.AmountText:SetHide(true);
          local subTypeDisplayName = pDealItem:GetSubTypeNameID();
          if (subTypeDisplayName ~= nil) then
            icon.IconText:LocalizeAndSetText(subTypeDisplayName);
          end
          icon.SelectButton:SetToolTipString(nil);		-- We recycle the entries, so make sure this is clear.

          -- Show/hide unacceptable item notification
          icon.UnacceptableIcon:SetHide(not pDealItem:IsUnacceptable());

          -- Populate the value pulldown
          SetValueText(icon, pDealItem);

          icon.SelectButton:RegisterCallback(Mouse.eRClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);

          if(info.DiplomaticActionType == "DIPLOACTION_JOINT_WAR" and pDealItem:GetFromPlayerID() == ms_OtherPlayer:GetID()) then
            icon.SelectButton:SetDisabled(true);
            icon.SelectButton:SetToolTipString(Locale.Lookup("LOC_JOINT_WAR_CANNOT_EDIT_THEIRS_TOOLTIP"));
          elseif(info.DiplomaticActionType == "DIPLOACTION_RESEARCH_AGREEMENT" and pDealItem:GetFromPlayerID() == ms_OtherPlayer:GetID()) then
            icon.SelectButton:SetDisabled(true);
            --icon.SelectButton:SetToolTipString(Locale.Lookup("LOC_JOINT_WAR_CANNOT_EDIT_THEIRS_TOOLTIP"));
          else
            icon.SelectButton:SetDisabled(false);
            icon.SelectButton:RegisterCallback( Mouse.eLClick, function(void1, void2, self) OnSelectValueDealItem(player, dealItemID, self); end );
          end
        end
      end
    end

    iconList.ListStack:CalculateSize();
    iconList.ListStack:ReprocessAnchoring();

  end

end

-- ===========================================================================
function PopulateDealGreatWorks(player : table, iconList : table)

  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  local playerType = GetPlayerType(player);
  if (pDeal ~= nil) then
    ms_IconAndTextIM:ReleaseInstanceByParent(iconList.ListStack);

    local pDealItem;
    for pDealItem in pDeal:Items() do
      local type = pDealItem:GetType();
      if (pDealItem:GetFromPlayerID() == player:GetID()) then
        local iDuration = pDealItem:GetDuration();
        local dealItemID = pDealItem:GetID();

        if (type == DealItemTypes.GREATWORK) then
          local icon = ms_IconAndTextIM:GetInstance(iconList.ListStack);

          local typeID = pDealItem:GetValueTypeID();
          SetIconToSize(icon.Icon, "ICON_" .. typeID, 42);
          icon.AmountText:SetHide(true);
          local typeName = pDealItem:GetValueTypeNameID();
          if (typeName ~= nil) then
            icon.IconText:LocalizeAndSetText(typeName);
            local strTooltip :string = GreatWorksSupport_GetBasicTooltip(pDealItem:GetValueType(), false);
            icon.SelectButton:LocalizeAndSetToolTip(strTooltip);
          else
            icon.IconText:SetText(nil);
            icon.SelectButton:SetToolTipString(nil);
          end
          icon.ValueText:SetHide(true);

          -- Show/hide unacceptable item notification
          icon.UnacceptableIcon:SetHide(not pDealItem:IsUnacceptable());

          icon.SelectButton:RegisterCallback(Mouse.eRClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);
          icon.SelectButton:RegisterCallback( Mouse.eLClick, function(void1, void2, self) OnSelectValueDealItem(player, dealItemID, self); end );
        end
      end
    end

    iconList.ListStack:CalculateSize();
    iconList.ListStack:ReprocessAnchoring();

  end

end

-- ===========================================================================
function PopulateDealCaptives(player : table, iconList : table)
  ms_IconAndTextIM:ReleaseInstanceByParent(iconList.ListStack);
  PopulateDealBasic(player, iconList, DealItemTypes.CAPTIVE, "ICON_UNIT_SPY");

end

-- ===========================================================================
function PopulateDealCities(player : table, iconList : table)

  local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  local playerType = GetPlayerType(player);
  local otherPlayer = GetOtherPlayer(player);
  if (pDeal ~= nil) then
    ms_IconAndTextWithDetailsIM:ReleaseInstanceByParent(iconList.ListStack);

    local pDealItem;
    for pDealItem in pDeal:Items() do
      local type = pDealItem:GetType();
      local valueType = pDealItem:GetValueType(); --ARISTOS
      local valueName = pDealItem:GetValueTypeNameID(); --ARISTOS
      if (pDealItem:GetFromPlayerID() == player:GetID()) then
        local dealItemID = pDealItem:GetID();

        if (type == DealItemTypes.CITIES) then
          local pCity = player:GetCities():FindID(valueType);
          -- Handle occupied cities
          if pCity == nil or (valueName ~= GetCityData(pCity).CityName and not pCity:IsOccupied()) then --ARISTOS
            pCity = otherPlayer:GetCities():FindID(valueType);
            -- AZURENCY : fix for persia not having occupation penalties
            if pCity == nil then
              pCity = player:GetCities():FindID(valueType);
            end
          end

          local icon = renderCity(pCity, player, iconList.ListStack);

          -- Show/hide unacceptable item notification
          icon.UnacceptableIcon:SetHide(not pDealItem:IsUnacceptable());

          icon.SelectButton:RegisterCallback(Mouse.eRClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);
          icon.SelectButton:RegisterCallback( Mouse.eLClick, function(void1, void2, self) OnSelectValueDealItem(player, dealItemID, self); end );

        end
      end
    end

    iconList.ListStack:CalculateSize();
    iconList.ListStack:ReprocessAnchoring();

  end


end

-- ===========================================================================
function PopulatePlayerDealPanel(rootControl : table, player : table)

  if (player ~= nil) then
    local playerType = GetPlayerType(player);
    PopulateDealGold(player, ms_DealGroups[DealItemGroupTypes.GOLD][playerType]);
    PopulateDealResources(player, ms_DealGroups[DealItemGroupTypes.LUXURY_RESOURCES][playerType], 'RESOURCECLASS_LUXURY');
    PopulateDealResources(player, ms_DealGroups[DealItemGroupTypes.STRATEGIC_RESOURCES][playerType], 'RESOURCECLASS_STRATEGIC');
    PopulateDealAgreements(player, ms_DealGroups[DealItemGroupTypes.AGREEMENTS][playerType]);
    PopulateDealCaptives(player, ms_DealGroups[DealItemGroupTypes.CAPTIVES][playerType]);
    PopulateDealGreatWorks(player, ms_DealGroups[DealItemGroupTypes.GREAT_WORKS][playerType]);
    PopulateDealCities(player, ms_DealGroups[DealItemGroupTypes.CITIES][playerType]);

    rootControl:CalculateSize();
    rootControl:ReprocessAnchoring();
  end
end

-- ===========================================================================
function HandleESC()
  -- Were we just viewing the deal?
  if ( m_kPopupDialog:IsOpen()) then
    m_kPopupDialog:Close();
  elseif (not Controls.ResumeGame:IsHidden()) then
    OnResumeGame();
  else
    OnRefuseDeal();
  end
end

-- ===========================================================================
--	INPUT Handlings
--	If this context is visible, it will get a crack at the input.
-- ===========================================================================
function KeyHandler( key:number )
  if (key == Keys.VK_ESCAPE) then
    HandleESC();
    return true;
  end

  return false;
end

-- ===========================================================================
function InputHandler( pInputStruct:table )
  local uiMsg = pInputStruct:GetMessageType();
  if uiMsg == KeyEvents.KeyUp then
    return KeyHandler( pInputStruct:GetKey() );
  end
  if (uiMsg == MouseEvents.LButtonUp or
    uiMsg == MouseEvents.RButtonUp or
    uiMsg == MouseEvents.MButtonUp or
    uiMsg == MouseEvents.PointerUp) then
    ClearValueEdit();
  end

  return false;
end

-- ===========================================================================
--	Handle a request to be shown, this should only be called by
--  the diplomacy statement handler.
-- ===========================================================================

function OnShowMakeDeal(otherPlayerID)
  ms_OtherPlayerID = otherPlayerID;
  ms_bIsDemand = false;
  ContextPtr:SetHide( false );
end
LuaEvents.DiploPopup_ShowMakeDeal.Add(OnShowMakeDeal);

-- ===========================================================================
--	Handle a request to be shown, this should only be called by
--  the diplomacy statement handler.
-- ===========================================================================

function OnShowMakeDemand(otherPlayerID)
  ms_OtherPlayerID = otherPlayerID;
  ms_bIsDemand = true;
  ContextPtr:SetHide( false );
end
LuaEvents.DiploPopup_ShowMakeDemand.Add(OnShowMakeDemand);

-- ===========================================================================
--	Handle a request to be hidden, this should only be called by
--  the diplomacy statement handler.
-- ===========================================================================

function OnHideDeal(otherPlayerID)
  OnContinue();
end
LuaEvents.DiploPopup_HideDeal.Add(OnHideDeal);

-- ===========================================================================
-- The other player has updated the deal
function OnDiplomacyIncomingDeal(eFromPlayer, eToPlayer, eAction)

  if (eFromPlayer == ms_OtherPlayerID) then
    local pDeal = DealManager.GetWorkingDeal(DealDirection.INCOMING, ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
    if (pDeal ~= nil) then
      -- Copy the deal to our OUTGOING deal back to the other player, in case we want to make modifications
      DealManager.CopyIncomingToOutgoingWorkingDeal(ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
      ms_LastIncomingDealProposalAction = eAction;

      PopulatePlayerDealPanel(Controls.TheirOfferStack, ms_OtherPlayer);
      PopulatePlayerDealPanel(Controls.MyOfferStack, ms_LocalPlayer);
      UpdateDealStatus();

    end
  end

end
Events.DiplomacyIncomingDeal.Add(OnDiplomacyIncomingDeal);

-- ===========================================================================
--	Handle a deal changing, usually from an incoming statement.
-- ===========================================================================

function OnDealUpdated(otherPlayerID, eAction, szText)
  if (not ContextPtr:IsHidden()) then
    -- Display some updated text.
    if (szText ~= nil and szText ~= "") then
      --SetLeaderDialog(szText, "");
    end
    -- Update deal and possible override text from szText
    OnDiplomacyIncomingDeal( otherPlayerID, Game.GetLocalPlayer(), eAction);
  end
end
LuaEvents.DiploPopup_DealUpdated.Add(OnDealUpdated);

-- ===========================================================================
function SetLeaderDialog(leaderDialog:string, leaderEffect:string)
  -- Update dialog
  Controls.LeaderDialog:LocalizeAndSetText(leaderDialog);

  -- Add parentheses to the effect text unless the text is ""
  if leaderEffect ~= "" then
    leaderEffect = "(" .. Locale.Lookup(leaderEffect) .. ")";
  end
  Controls.LeaderEffect:SetText(leaderEffect);

  -- Recenter text
  Controls.LeaderDialogStack:CalculateSize();
  Controls.LeaderDialogStack:ReprocessAnchoring();
end

-- ===========================================================================
function StartExitAnimation()
  -- Start the exit animation, it will call OnContinue when complete
  ms_bExiting = true;
  -- Controls.YieldSlide:Reverse();
  -- Controls.YieldAlpha:Reverse();
  -- Controls.TradePanelFade:Reverse();
  -- Controls.TradePanelSlide:Reverse();
  -- Controls.TradePanelFade:SetSpeed(5);
  -- Controls.TradePanelSlide:SetSpeed(5);
  UI.PlaySound("UI_Diplomacy_Menu_Change");
end

-- ===========================================================================
function OnContinue()
  ContextPtr:SetHide( true );
end

-- ===========================================================================
--	Functions for setting the data in the yield area
-- ===========================================================================

function FormatValuePerTurn( value:number )
  return Locale.ToNumber(value, "+#,###.#;-#,###.#");
end

function RefreshYields()

  local ePlayer		:number = Game.GetLocalPlayer();
  local localPlayer	:table= nil;
  if ePlayer ~= -1 then
    localPlayer = Players[ePlayer];
    if localPlayer == nil then
      return;
    end
  else
    return;
  end

  ---- SCIENCE ----
  local playerTechnology		:table	= localPlayer:GetTechs();
  local currentScienceYield	:number = playerTechnology:GetScienceYield();
  Controls.SciencePerTurn:SetText( FormatValuePerTurn(currentScienceYield) );
  Controls.ScienceBacking:SetToolTipString( GetScienceTooltip() );
  Controls.ScienceStack:CalculateSize();

  ---- CULTURE----
  local playerCulture			:table	= localPlayer:GetCulture();
  local currentCultureYield	:number = playerCulture:GetCultureYield();
  Controls.CulturePerTurn:SetText( FormatValuePerTurn(currentCultureYield) );
  Controls.CultureBacking:SetToolTipString( GetCultureTooltip() );
  Controls.CultureStack:CalculateSize();

  ---- GOLD ----
  local playerTreasury:table	= localPlayer:GetTreasury();
  local goldYield		:number = playerTreasury:GetGoldYield() - playerTreasury:GetTotalMaintenance();
  local goldBalance	:number = math.floor(playerTreasury:GetGoldBalance());
  Controls.GoldBalance:SetText( Locale.ToNumber(goldBalance, "#,###.#"));
  Controls.GoldPerTurn:SetText( FormatValuePerTurn(goldYield) );
  Controls.GoldBacking:SetToolTipString(GetGoldTooltip());
  Controls.GoldStack:CalculateSize();

  ---- FAITH ----
  local playerReligion		:table	= localPlayer:GetReligion();
  local faithYield			:number = playerReligion:GetFaithYield();
  local faithBalance			:number = playerReligion:GetFaithBalance();
  Controls.FaithBalance:SetText( Locale.ToNumber(faithBalance, "#,###.#"));
  Controls.FaithPerTurn:SetText( FormatValuePerTurn(faithYield) );
  Controls.FaithBacking:SetToolTipString( GetFaithTooltip() );
  Controls.FaithStack:CalculateSize();
  if (faithYield == 0) then
    Controls.FaithBacking:SetHide(true);
  else
    Controls.FaithBacking:SetHide(false);
  end

  Controls.YieldStack:CalculateSize();
  Controls.YieldStack:ReprocessAnchoring();
end
-- ===========================================================================

-- ===========================================================================
function OnShow()
  RefreshYields();
  -- Controls.Signature_Slide:SetToBeginning();
  -- Controls.Signature_Alpha:SetToBeginning();
  -- Controls.Signature_Slide:Play();
  -- Controls.Signature_Alpha:Play();
  Controls.YieldAlpha:SetToBeginning();
  Controls.YieldAlpha:Play();
  Controls.YieldSlide:SetToBeginning();
  Controls.YieldSlide:Play();
  Controls.TradePanelFade:SetToBeginning();
  Controls.TradePanelFade:Play();
  -- Controls.TradePanelSlide:SetToBeginning();
  -- Controls.TradePanelSlide:Play();
  -- Controls.LeaderDialogFade:SetToBeginning();
  -- Controls.LeaderDialogFade:Play();
  -- Controls.LeaderDialogSlide:SetToBeginning();
  -- Controls.LeaderDialogSlide:Play();

  ms_IconOnlyIM:ResetInstances();
  ms_IconOnly_3IM:ResetInstances();
  ms_IconAndTextIM:ResetInstances();
  ms_IconAndTextWithDetailsIM:ResetInstances();
  ms_IconOnly_Resource_ScarceIM:ResetInstances();
  ms_IconOnly_Resource_DuplicateIM:ResetInstances();
  ms_IconOnly_Resource_UntradeableIM:ResetInstances();

  ms_bExiting = false;

  if (Game.GetLocalPlayer() == -1) then
    return;
  end

  -- For hotload testing, force the other player to be valid
  if (ms_OtherPlayerID == -1) then
    local playerID = 0
    for playerID = 0, GameDefines.MAX_PLAYERS-1, 1 do
      if (playerID ~= Game.GetLocalPlayer() and Players[playerID]:IsAlive()) then
        ms_OtherPlayerID = playerID;
        break;
      end
    end
  end

  -- Set up some globals for easy access
  ms_LocalPlayer = Players[Game.GetLocalPlayer()];
  ms_OtherPlayer = Players[ms_OtherPlayerID];
  ms_OtherPlayerIsHuman = ms_OtherPlayer:IsHuman();

  local sessionID = DiplomacyManager.FindOpenSessionID(Game.GetLocalPlayer(), ms_OtherPlayer:GetID());
  if (sessionID ~= nil) then
    local sessionInfo = DiplomacyManager.GetSessionInfo(sessionID);
    ms_InitiatedByPlayerID = sessionInfo.FromPlayer;
  end

  -- Did the AI start this or the human?
  if (ms_InitiatedByPlayerID == ms_OtherPlayerID) then
    ms_LastIncomingDealProposalAction = DealProposalAction.PROPOSED;
    DealManager.CopyIncomingToOutgoingWorkingDeal(ms_LocalPlayer:GetID(), ms_OtherPlayer:GetID());
  else
    ms_LastIncomingDealProposalAction = DealProposalAction.PENDING;
    -- We are NOT clearing the current outgoing deal. This allows other screens to pre-populate the deal.
  end

  --UpdateOtherPlayerText(1);
  PopulateSignatureArea(ms_LocalPlayer);
  PopulateSignatureArea(ms_OtherPlayer);
  --SetDefaultLeaderDialogText();

  local iAvailableItemCount = 0;
  -- Available content to trade.  Shouldn't change during the session, but it might, especially in multiplayer.
  iAvailableItemCount = iAvailableItemCount + PopulatePlayerAvailablePanel(Controls.MyInventoryStack, ms_LocalPlayer);
  iAvailableItemCount = iAvailableItemCount + PopulatePlayerAvailablePanel(Controls.TheirInventoryStack, ms_OtherPlayer);

  Controls.MyInventoryScroll:CalculateSize();
  Controls.TheirInventoryScroll:CalculateSize();

  m_kPopupDialog:Close(); -- Close and reset the popup in case it's open

  if (iAvailableItemCount == 0) then
    if (ms_bIsDemand) then
      m_kPopupDialog:AddText(Locale.Lookup("LOC_DIPLO_DEMAND_NO_AVAILABLE_ITEMS"));
      m_kPopupDialog:AddTitle( Locale.ToUpper(Locale.Lookup("LOC_DIPLO_CHOICE_MAKE_DEMAND")))
      m_kPopupDialog:AddButton( Locale.Lookup("LOC_OK_BUTTON"), OnRefuseDeal);
    else
      m_kPopupDialog:AddText(	  Locale.Lookup("LOC_DIPLO_DEAL_NO_AVAILABLE_ITEMS"));
      m_kPopupDialog:AddTitle( Locale.ToUpper(Locale.Lookup("LOC_DIPLO_CHOICE_MAKE_DEAL")))
      m_kPopupDialog:AddButton( Locale.Lookup("LOC_OK_BUTTON"), OnRefuseDeal);
    end
    m_kPopupDialog:Open();
  else
    if m_kPopupDialog:IsOpen() then
      m_kPopupDialog:Close();
    end
  end

  PopulatePlayerDealPanel(Controls.TheirOfferStack, ms_OtherPlayer);
  PopulatePlayerDealPanel(Controls.MyOfferStack, ms_LocalPlayer);
  UpdateDealStatus();

  -- We may be coming into this screen with a deal already set, which needs to be sent to the AI for inspection. Check that.
  -- Don't send AI proposals for inspection or they will think the player was the creator of the deal
  if (IsAutoPropose() and (ms_InitiatedByPlayerID ~= ms_OtherPlayerID or ms_OtherPlayerIsHuman)) then
    ProposeWorkingDeal(true);
  end

  --Controls.MyOfferScroll:CalculateSize();
  --Controls.TheirOfferScroll:CalculateSize();

  LuaEvents.DiploBasePopup_HideUI(true);
  TTManager:ClearCurrent();	-- Clear any tool tips raised;

  Controls.DealOptionsStack:CalculateSize();
  Controls.DealOptionsStack:ReprocessAnchoring();
end

----------------------------------------------------------------
function OnHide()
  LuaEvents.DiploBasePopup_HideUI(false);
end

-- ===========================================================================
--	Context CTOR
-- ===========================================================================
function OnInit( isHotload )
  CreatePanels();

  if (isHotload and not ContextPtr:IsHidden()) then
    OnShow();
  end
end

-- ===========================================================================
--	Context DESTRUCTOR
--	Not called when screen is dismissed, only if the whole context is removed!
-- ===========================================================================
function OnShutdown()

end

-- ===========================================================================
function OnLocalPlayerTurnEnd()
  if (not ContextPtr:IsHidden()) then
    -- Were we just viewing the deal?
    if (not Controls.ResumeGame:IsHidden()) then
      OnResumeGame();
    else
      OnRefuseDeal(true);
    end
    OnContinue();
  end
end

-- ===========================================================================
function OnPlayerDefeat( player, defeat, eventID)
  local localPlayer = Game.GetLocalPlayer();
  if (localPlayer and localPlayer >= 0) then		-- Check to see if there is any local player
    -- Was it the local player?
    if (localPlayer == player) then
      OnLocalPlayerTurnEnd();
    end
  end
end

-- ===========================================================================
function OnTeamVictory(team, victory, eventID)

  local localPlayer = Game.GetLocalPlayer();
  if (localPlayer and localPlayer >= 0) then		-- Check to see if there is any local player
    OnLocalPlayerTurnEnd();
  end
end

-- ===========================================================================
--	Engine Event
-- ===========================================================================
function OnUserRequestClose()
  -- Is this showing; if so then it needs to raise dialog to handle close
  if (not ContextPtr:IsHidden()) then
    m_kPopupDialog:Reset();
    m_kPopupDialog:AddText(Locale.Lookup("LOC_CONFIRM_EXIT_TXT"));
    m_kPopupDialog:AddButton(Locale.Lookup("LOC_NO"), nil);
    m_kPopupDialog:AddButton(Locale.Lookup("LOC_YES"), OnQuitYes, nil, nil, "PopupButtonInstanceRed");
    m_kPopupDialog:Open();
  end
end
function OnQuitYes()
  Events.UserConfirmedClose();
end

-- ===========================================================================
function Initialize()

  ContextPtr:SetInitHandler( OnInit );
  ContextPtr:SetInputHandler( InputHandler, true );
  ContextPtr:SetShutdown( OnShutdown );
  ContextPtr:SetShowHandler( OnShow );
  ContextPtr:SetHideHandler( OnHide );

  Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );
  Events.PlayerDefeat.Add( OnPlayerDefeat );
  Events.TeamVictory.Add( OnTeamVictory );

  Events.UserRequestClose.Add( OnUserRequestClose );

  m_kPopupDialog = PopupDialog:new( "DiplomacyDealView" );
end

Initialize();
