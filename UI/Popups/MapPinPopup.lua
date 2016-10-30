----------------------------------------------------------------  
-- MapPinPopup
--
-- Popup used for creating and editting map pins.
----------------------------------------------------------------  
include( "PlayerTargetLogic" );


----------------------------------------------------------------  
-- Globals
---------------------------------------------------------------- 
local COLOR_YELLOW				:number = 0xFF2DFFF8;
local COLOR_WHITE				:number = 0xFFFFFFFF;
 
local g_editMapPin :table = nil;
local g_iconOptionEntries = {};
local g_visibilityTargetEntries = {};

local g_desiredIconName :string = "";

-- Default player target is self only.
local g_playerTarget = { targetType = ChatTargetTypes.CHATTARGET_PLAYER, targetID = Game.GetLocalPlayer() };

-- When we aren't quite so crunched on time, it would be good to add the map pins table to the database
local g_iconPulldownOptions = 
{	
	{ name = "ICON_MAP_PIN_STRENGTH"},
	{ name = "ICON_MAP_PIN_RANGED"},
	{ name = "ICON_MAP_PIN_BOMBARD"},
	{ name = "ICON_MAP_PIN_DISTRICT"},
	{ name = "ICON_MAP_PIN_CHARGES"},
	{ name = "ICON_MAP_PIN_DEFENSE"},
	{ name = "ICON_MAP_PIN_MOVEMENT"},
	{ name = "ICON_MAP_PIN_NO"},
	{ name = "ICON_MAP_PIN_PLUS"},
	{ name = "ICON_MAP_PIN_CIRCLE"},
	{ name = "ICON_MAP_PIN_TRIANGLE"},
	{ name = "ICON_MAP_PIN_SUN"},
	{ name = "ICON_MAP_PIN_SQUARE"},
	{ name = "ICON_MAP_PIN_DIAMOND"},
	{ name = "ICON_DISTRICT_HOLY_SITE"},
	{ name = "ICON_DISTRICT_CAMPUS"},
	{ name = "ICON_DISTRICT_THEATER"},
	{ name = "ICON_DISTRICT_INDUSTRIAL_ZONE"},
	{ name = "ICON_DISTRICT_AQUEDUCT"},
	{ name = "ICON_DISTRICT_HARBOR"},
	{ name = "ICON_DISTRICT_COMMERCIAL_HUB"},
	{ name = "ICON_DISTRICT_ENTERTAINMENT_COMPLEX"},
	{ name = "ICON_DISTRICT_ENCAMPMENT"},
	{ name = "ICON_DISTRICT_NEIGHBORHOOD"}
};

-------------------------------------------------------------------------------
-- 
-------------------------------------------------------------------------------
function MapPinVisibilityToPlayerTarget(mapPinVisibility :number, playerTargetData :table)
	if(mapPinVisibility == ChatTargetTypes.CHATTARGET_ALL) then
		playerTargetData.targetType = ChatTargetTypes.CHATTARGET_ALL;
		playerTargetData.targetID = GetNoPlayerTargetID();
	elseif(mapPinVisibility == ChatTargetTypes.CHATTARGET_TEAM) then
		local localPlayerID = Game.GetLocalPlayer();
		local localPlayer = PlayerConfigurations[localPlayerID];
		local localTeam = localPlayer:GetTeam();
		playerTargetData.targetType = ChatTargetTypes.CHATTARGET_TEAM;
		playerTargetData.targetID = localTeam;
	elseif(mapPinVisibility >= 0) then
		-- map pin visibility stores individual player targets as a straight positive number
		playerTargetData.targetType = ChatTargetTypes.CHATTARGET_PLAYER;
		playerTargetData.targetID = mapPinVisibility;
	else
		-- Unknown map pin visibility state
		playerTargetData.targetType = ChatTargetTypes.NO_CHATTARGET;
		playerTargetData.targetID = GetNoPlayerTargetID();
	end
end

function PlayerTargetToMapPinVisibility(playerTargetData :table)
	if(playerTargetData.targetType == ChatTargetTypes.CHATTARGET_ALL) then
		return ChatTargetTypes.CHATTARGET_ALL;
	elseif(playerTargetData.targetType == ChatTargetTypes.CHATTARGET_TEAM) then
		return ChatTargetTypes.CHATTARGET_TEAM;
	elseif(playerTargetData.targetType == ChatTargetTypes.CHATTARGET_PLAYER) then
		-- map pin visibility stores individual player targets as a straight positive number
		return playerTargetData.targetID;
	end

	return ChatTargetTypes.NO_CHATTARGET;
end


-------------------------------------------------------------------------------
-- 
-------------------------------------------------------------------------------
function SetMapPinIcon(imageControl :table, mapPinIconName :string)
	if(imageControl ~= nil and mapPinIconName ~= nil) then
		local iconName = mapPinIconName;
		local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName);
		if (textureSheet ~= nil) then			--Check to make sure that the unknown index is also defined...
			-- Determine icon size
			local isDefaultMapPinIcon = string.find(iconName, "ICON_MAP_PIN") ~= nil; 
			if (isDefaultMapPinIcon == false) then
				-- Adjust icon size for bigger 32px icons
				imageControl:SetSizeX(32);
				imageControl:SetSizeY(32);
			end
			
			imageControl:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
		end
	end
end

-- ===========================================================================
function PopulateIconOptions()
	g_iconOptionEntries = {};
	Controls.IconOptionStack:DestroyAllChildren();

	local controlTable = {};
	local newIconEntry = {};
	for i, pair in ipairs(g_iconPulldownOptions) do
		controlTable = {};
		newIconEntry = {};
		ContextPtr:BuildInstanceForControl( "IconOptionInstance", controlTable, Controls.IconOptionStack );
		SetMapPinIcon(controlTable.Icon, pair.name);
	    controlTable.IconOptionButton:RegisterCallback(Mouse.eLClick, OnIconOption);
		controlTable.IconOptionButton:SetVoids(i, -1);

		newIconEntry.IconName = pair.name;
		newIconEntry.Instance = controlTable;
		g_iconOptionEntries[i] = newIconEntry;

		UpdateIconOptionColor(i);
	end
	
	Controls.IconOptionStack:CalculateSize();
	Controls.IconOptionStack:ReprocessAnchoring();
	Controls.OptionsStack:CalculateSize();
	Controls.OptionsStack:ReprocessAnchoring();
	Controls.WindowContentsStack:CalculateSize();
	Controls.WindowContentsStack:ReprocessAnchoring();
	Controls.WindowStack:CalculateSize();
	Controls.WindowStack:ReprocessAnchoring();
	Controls.WindowContainer:ReprocessAnchoring();
end

-- ===========================================================================
function UpdateIconOptionColors()
	for iconIndex, iconEntry in pairs(g_iconOptionEntries) do
		UpdateIconOptionColor(iconIndex);
	end
end

-- ===========================================================================
function UpdateIconOptionColor(iconEntryIndex :number)
	local iconEntry :table = g_iconOptionEntries[iconEntryIndex];
	if(iconEntry ~= nil) then
		if(iconEntry.IconName == g_desiredIconName) then
			-- Selected icon
			iconEntry.Instance.IconOptionButton:SetSelected(true);
		else
			iconEntry.Instance.IconOptionButton:SetSelected(false);
		end
	end
end

-- ===========================================================================
function RequestMapPin(hexX :number, hexY :number)
	local activePlayerID = Game.GetLocalPlayer();
	local pPlayerCfg = PlayerConfigurations[activePlayerID];
	local pMapPin = pPlayerCfg:GetMapPin(hexX, hexY);
	if(pMapPin ~= nil) then
		g_editMapPin = pMapPin;

		g_desiredIconName = g_editMapPin:GetIconName();
		if GameConfiguration.IsAnyMultiplayer() then
			MapPinVisibilityToPlayerTarget(g_editMapPin:GetVisibility(), g_playerTarget);
			UpdatePlayerTargetPulldown(Controls.VisibilityPull, g_playerTarget);
			Controls.VisibilityContainer:SetHide(false);
		else
			Controls.VisibilityContainer:SetHide(true);
		end

		Controls.PinName:SetText(g_editMapPin:GetName());
		Controls.PinName:TakeFocus();

		UpdateIconOptionColors();
		ShowHideSendToChatButton();

		Controls.IconOptionStack:CalculateSize();
		Controls.IconOptionStack:ReprocessAnchoring();
		Controls.OptionsStack:CalculateSize();
		Controls.OptionsStack:ReprocessAnchoring();
		Controls.WindowContentsStack:CalculateSize();
		Controls.WindowContentsStack:ReprocessAnchoring();
		Controls.WindowStack:CalculateSize();
		Controls.WindowStack:ReprocessAnchoring();
		Controls.WindowContainer:ReprocessAnchoring();

		UIManager:QueuePopup( ContextPtr, PopupPriority.Current);
		Controls.PopupAlphaIn:SetToBeginning();
		Controls.PopupAlphaIn:Play();
		Controls.PopupSlideIn:SetToBeginning();
		Controls.PopupSlideIn:Play();
	end
end

-- Deletes the map pin with the given id
function RequestDeleteMapPin(mapPinID :number)
	if(mapPinID ~= nil) then
		local activePlayerID = Game.GetLocalPlayer();
		local pPlayerCfg = PlayerConfigurations[activePlayerID];
		pPlayerCfg:DeleteMapPin(mapPinID);
		Network.BroadcastPlayerInfo();
        UI.PlaySound("Map_Pin_Remove");
	end
end

-- ===========================================================================
function ShowHideSendToChatButton()
	local privatePin = g_editMapPin ~= nil and g_editMapPin:IsPrivate();
	local showSendButton = GameConfiguration.IsNetworkMultiplayer() and not privatePin;
	Controls.SendToChatButton:SetHide(not showSendButton);
end

-- ===========================================================================
function OnIconOption( iconPulldownIndex :number, notUsed :number )
	local iconOptions :table = g_iconPulldownOptions[iconPulldownIndex];
	if(iconOptions) then
		local newIconName :string = iconOptions.name;
		g_desiredIconName = newIconName;
		UpdateIconOptionColors();
	end
end

-- ===========================================================================
function OnOk()
	if( not ContextPtr:IsHidden() ) then
		if(g_editMapPin ~= nil) then
			g_editMapPin:SetName(Controls.PinName:GetText());
			g_editMapPin:SetIconName(g_desiredIconName);

			local newMapPinVisibility = PlayerTargetToMapPinVisibility(g_playerTarget);
			g_editMapPin:SetVisibility(newMapPinVisibility);

			Network.BroadcastPlayerInfo();
			UI.PlaySound("Map_Pin_Add");
		end

		UIManager:DequeuePopup( ContextPtr );
	end
end


-- ===========================================================================
function OnSendToChatButton()
	if(g_editMapPin ~= nil) then
		g_editMapPin:SetName(Controls.PinName:GetText());
		LuaEvents.MapPinPopup_SendPinToChat(g_editMapPin:GetPlayerID(), g_editMapPin:GetID());
	end
end

-- ===========================================================================
function OnDelete()
	if(g_editMapPin ~= nil) then
		local activePlayerID = Game.GetLocalPlayer();
		local pPlayerCfg = PlayerConfigurations[activePlayerID];
		local deletePinID = g_editMapPin:GetID();
		pPlayerCfg:DeleteMapPin(deletePinID);
		Network.BroadcastPlayerInfo();
        UI.PlaySound("Map_Pin_Remove");
	end
	UIManager:DequeuePopup( ContextPtr );
end

function OnCancel()
	UIManager:DequeuePopup( ContextPtr );
end
----------------------------------------------------------------  
-- Event Handlers
---------------------------------------------------------------- 
function OnMapPinPlayerInfoChanged( playerID :number )
	PlayerTarget_OnPlayerInfoChanged( playerID, Controls.VisibilityPull, nil, g_visibilityTargetEntries, g_playerTarget, true);
end

function OnLocalPlayerChanged()
	g_playerTarget.targetID = Game.GetLocalPlayer();
	PopulateTargetPull(Controls.VisibilityPull, nil, g_visibilityTargetEntries, g_playerTarget, true, OnVisibilityPull);

	if( not ContextPtr:IsHidden() ) then
		UIManager:DequeuePopup( ContextPtr );
	end
end

-- ===========================================================================
--	Keyboard INPUT Handler
-- ===========================================================================
function KeyHandler( key:number )
	if (key == Keys.VK_ESCAPE) then 
		-- Cancel on escape
		OnCancel(); 
		return true; 
	elseif (key == Keys.VK_RETURN) then
		-- Immediately create pin on return, even when textfield is not focused
		OnOk();
		return true;
	end
	return false;
end
-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then return KeyHandler( pInputStruct:GetKey() ); end;
	return false;
end
-- ===========================================================================
--	INITIALIZE
-- ===========================================================================
function Initialize()
	ContextPtr:SetInputHandler( OnInputHandler, true );

	PopulateIconOptions();
	PopulateTargetPull(Controls.VisibilityPull, nil, g_visibilityTargetEntries, g_playerTarget, true, OnVisibilityPull);
	Controls.DeleteButton:RegisterCallback(Mouse.eLClick, OnDelete);
	Controls.DeleteButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.SendToChatButton:RegisterCallback(Mouse.eLClick, OnSendToChatButton);
	Controls.SendToChatButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.OkButton:RegisterCallback(Mouse.eLClick, OnOk);
	Controls.OkButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.PinName:RegisterCommitCallback( OnOk );

	LuaEvents.MapPinPopup_RequestMapPin.Add(RequestMapPin);
	LuaEvents.MapPinPopup_RequestDeleteMapPin.Add(RequestDeleteMapPin);

	-- When player info is changed, this pulldown needs to know so it can update itself if it becomes invalid.
	Events.PlayerInfoChanged.Add(OnMapPinPlayerInfoChanged);
	Events.LocalPlayerChanged.Add(OnLocalPlayerChanged);
		
end
Initialize();


