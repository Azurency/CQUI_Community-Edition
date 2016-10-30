----------------------------------------------------------------  
-- Map Pin List Panel
----------------------------------------------------------------  


local m_playerMapPins	:table = {};
local m_MapPinListButtonToPinEntry :table = {}; -- map pin entries keyed to their MapPinListButton object string names.  This is currently just used for sorting, please becareful if you use it for anything else as it is cleared after use.

local PlayerMapPinListTTStr :string = Locale.Lookup( "LOC_MAP_PIN_LIST_REMOTE_PIN_TOOLTIP" ).." "..Locale.Lookup( "LOC_UI_RIGHT_CLICK" ).." ".. Locale.Lookup( "LOC_DELETE_AI" );
local RemoteMapPinListTTStr :string = Locale.Lookup( "LOC_MAP_PIN_LIST_REMOTE_PIN_TOOLTIP" );

------------------------------------------------- 
-- Map Pin List Scripting
-------------------------------------------------
function GetMapPinConfig(iPlayerID :number, mapPinID :number)
	local playerCfg :table = PlayerConfigurations[iPlayerID];
	if(playerCfg ~= nil) then
		local playerMapPins :table = playerCfg:GetMapPins();
		if(playerMapPins ~= nil) then
			return playerMapPins[mapPinID];
		end
	end
	return nil;
end

-------------------------------------------------
-------------------------------------------------
function SetMapPinIcon(imageControl :table, mapPinIconName :string)
	if(imageControl ~= nil and mapPinIconName ~= nil) then
		local iconName = mapPinIconName;
		local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName);

		if (textureSheet == nil) then			--Check to see if the unit has an icon atlas index defined
			print("Could not find icon for " .. iconName);
			textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas("ICON_MAP_PIN_SQUARE");		--If not, resolve the index to be a generic unknown index
		end
		if (textureSheet ~= nil) then			--Check to make sure that the unknown index is also defined...
			imageControl:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
		end
	end
end

-------------------------------------------------
-------------------------------------------------
function SortMapPinEntryStack(a, b)
	local controlStringA = tostring(a);
	local controlStringB = tostring(b);
	local pinEntryA = m_MapPinListButtonToPinEntry[controlStringA];
	local pinEntryB = m_MapPinListButtonToPinEntry[controlStringB];
	if (pinEntryA ~= nil and pinEntryB ~= nil) then
		local pinNameA :string = Locale.ToLower(pinEntryA.MapPinName:GetText());
		local pinNameB :string = Locale.ToLower(pinEntryB.MapPinName:GetText());

		return pinNameA < pinNameB;
	else
		-- This is obviously bad, why are they not in the list? Use the control strings to test against something.
		return controlStringA < controlStringB;
	end
end

-------------------------------------------------
-------------------------------------------------
function UpdateMapPinListEntry(iPlayerID :number, mapPinID :number)
	local mapPinEntry = GetMapPinListEntry(iPlayerID, mapPinID);
	local mapPinCfg = GetMapPinConfig(iPlayerID, mapPinID);
	if(mapPinCfg ~= nil and mapPinEntry ~= nil) then
		-- Determine map pin display name.
		local pinName :string = mapPinCfg:GetName();
		if(pinName == nil) then
			pinName = Locale.Lookup( "LOC_MAP_PIN_DEFAULT_NAME", mapPinCfg:GetID() );
		end
		mapPinEntry.MapPinName:SetText(pinName);

		-- Set pin colors based on owner's player colors.
		--local primaryColor, secondaryColor  = UI.GetPlayerColors(iPlayerID);
		--mapPinEntry.PrimaryColorBox:SetColor(primaryColor);
		--mapPinEntry.SecondaryColorBox:SetColor(secondaryColor);

		-- Determine icon size
		local iconName = mapPinCfg:GetIconName();
		local isDefaultMapPinIcon = string.find(iconName, "ICON_MAP_PIN") ~= nil;
		if (isDefaultMapPinIcon == false) then
			-- Adjust icon size for bigger 32px icons
			mapPinEntry.IconImage:SetSizeX(32);
			mapPinEntry.IconImage:SetSizeY(32);
		else
			-- Adjust offset for smaller 24px icons
			local offsetX = mapPinEntry.IconImage:GetOffsetX();
			mapPinEntry.IconImage:SetOffsetX(offsetX + 4);
		end
		
		-- Set pin icon
		SetMapPinIcon(mapPinEntry.IconImage, iconName);

		-- Is this map pin visible on this list?
		local localPlayerID = Game.GetLocalPlayer();
		local showMapPin = mapPinCfg:IsVisible(localPlayerID);
		mapPinEntry.Root:SetHide(not showMapPin);
	end
end

-------------------------------------------------
-------------------------------------------------
function GetMapPinListEntry(iPlayerID :number, mapPinID :number)
	local playerMapPins = m_playerMapPins[iPlayerID];
	if(playerMapPins == nil) then
		playerMapPins = {};
		m_playerMapPins[iPlayerID] = playerMapPins;
	end

	local mapPinEntry = playerMapPins[mapPinID];
	if(mapPinEntry == nil) then
		mapPinEntry = {};
		ContextPtr:BuildInstanceForControl( "MapPinListEntry", mapPinEntry, Controls.MapPinEntryStack);

		playerMapPins[mapPinID] = mapPinEntry;
		m_MapPinListButtonToPinEntry[tostring(mapPinEntry.Root)] = mapPinEntry;

		mapPinEntry.MapPinListButton:SetVoids(iPlayerID, mapPinID);
		if( iPlayerID == Game.GetLocalPlayer()) then
			mapPinEntry.EditMapPin:SetHide(false);
			mapPinEntry.EditMapPin:SetVoids(iPlayerID, mapPinID);
			mapPinEntry.EditMapPin:RegisterCallback(Mouse.eLClick, OnMapPinEntryEdit);
		else
			mapPinEntry.EditMapPin:SetHide(true);
		end
		
		mapPinEntry.MapPinListButton:RegisterCallback(Mouse.eLClick, OnMapPinEntryLeftClick);
		mapPinEntry.MapPinListButton:RegisterCallback(Mouse.eRClick, OnMapPinEntryRightClick);

		if(iPlayerID == Game.GetLocalPlayer()) then
			mapPinEntry.MapPinListButton:SetToolTipString(PlayerMapPinListTTStr);
		else
			mapPinEntry.MapPinListButton:SetToolTipString(RemoteMapPinListTTStr);
		end

		UpdateMapPinListEntry(iPlayerID, mapPinID);

		Controls.MapPinEntryStack:CalculateSize();
		Controls.MapPinEntryStack:ReprocessAnchoring();

		Controls.MapPinLogPanel:CalculateInternalSize();
		Controls.MapPinLogPanel:ReprocessAnchoring();
	end
	return mapPinEntry;
end

-------------------------------------------------
-------------------------------------------------
function BuildMapPinList()
	m_playerMapPins = {};
	m_MapPinListButtonToPinEntry = {};
	Controls.MapPinEntryStack:DestroyAllChildren();

	-- Call GetMapPinListEntry on every map pin to initially create the entries.
	for iPlayer = 0, GameDefines.MAX_MAJOR_CIVS-1 do
		local pPlayerConfig = PlayerConfigurations[iPlayer];
		if(pPlayerConfig ~= nil) then
			local pPlayerPins	:table  = pPlayerConfig:GetMapPins();
			for ii, mapPinCfg in pairs(pPlayerPins) do
				local pinID		:number = mapPinCfg:GetID();
				GetMapPinListEntry(iPlayer, pinID);
			end
		end
	end
	-- Sort by names when we're done.
	Controls.MapPinEntryStack:SortChildren(SortMapPinEntryStack);

	-- Don't need this anymore, get rid of the references so they can be properly released!
	m_MapPinListButtonToPinEntry = {};
	
	-- Recalc after sorting so the anchoring can account for hidden elements.
	Controls.MapPinEntryStack:CalculateSize();
	Controls.MapPinEntryStack:ReprocessAnchoring();
	Controls.MapPinPanel:ReprocessAnchoring();
end


------------------------------------------------- 
-- Button Event Handlers
-------------------------------------------------
function OnMapPinEntryLeftClick(iPlayerID :number, mapPinID :number)
	local mapPinCfg = GetMapPinConfig(iPlayerID, mapPinID);
	if(mapPinCfg ~= nil) then
		local hexX :number = mapPinCfg:GetHexX();
		local hexY :number = mapPinCfg:GetHexY();
		UI.LookAtPlot(hexX, hexY);
		-- Would love to find a fun effect to play on the map pin when you look at it so that you don't lose it.
		--	UI.OnNaturalWonderRevealed(hexX, hexY);
	end
end

function OnMapPinEntryRightClick(iPlayerID :number, mapPinID :number)
	if(iPlayerID == Game.GetLocalPlayer()) then
		LuaEvents.MapPinPopup_RequestDeleteMapPin(mapPinID);
	end
end

function OnMapPinEntryEdit(iPlayerID :number, mapPinID :number)
	if(iPlayerID == Game.GetLocalPlayer()) then
		-- You're only allowed to edit your own pins.
		local mapPinCfg = GetMapPinConfig(iPlayerID, mapPinID);
		if(mapPinCfg ~= nil) then
			local hexX :number = mapPinCfg:GetHexX();
			local hexY :number = mapPinCfg:GetHexY();
			UI.LookAtPlot(hexX, hexY);
			LuaEvents.MapPinPopup_RequestMapPin(hexX, hexY);
		end
	end
end

-------------------------------------------------
-------------------------------------------------
function OnAddPinButton()
	-- Toggles map pin interface mode
	if (UI.GetInterfaceMode() == InterfaceModeTypes.PLACE_MAP_PIN) then
		UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
	else
		UI.SetInterfaceMode(InterfaceModeTypes.PLACE_MAP_PIN);
	end
end


------------------------------------------------- 
-- External Event Handlers
-------------------------------------------------
function OnPlayerInfoChanged(playerID)
	BuildMapPinList();
end

-------------------------------------------------
-------------------------------------------------
function OnInterfaceModeChanged( eNewMode:number )
	if (UI.GetInterfaceMode() == InterfaceModeTypes.PLACE_MAP_PIN) then
		Controls.AddPinButton:SetText(Locale.Lookup("LOC_GREAT_WORKS_PLACING"));
		Controls.AddPinButton:SetSelected(true);
	else
		Controls.AddPinButton:SetText(Locale.Lookup("LOC_HUD_MAP_PLACE_MAP_PIN"));
		Controls.AddPinButton:SetSelected(false);
	end
end

function OnLocalPlayerChanged( eLocalPlayer:number , ePrevLocalPlayer:number )
	BuildMapPinList();
end

-------------------------------------------------
-- ShowHideHandler
-------------------------------------------------
function ShowHideHandler( bIsHide, bIsInit )
	if(not bIsHide) then 
	end	
end
ContextPtr:SetShowHideHandler( ShowHideHandler );


-- ===========================================================================
function Initialize()
	Controls.AddPinButton:RegisterCallback( Mouse.eLClick, OnAddPinButton );
    Controls.AddPinButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Events.PlayerInfoChanged.Add(OnPlayerInfoChanged);
	Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
	Events.LocalPlayerChanged.Add( OnLocalPlayerChanged );


	BuildMapPinList();
end
Initialize()
