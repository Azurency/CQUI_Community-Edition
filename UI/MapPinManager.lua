-- ===========================================================================
--	Map Pin Manager
--	Manages all the map pins on the world map.
-- ===========================================================================

include( "InstanceManager" );
include( "SupportFunctions" );


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

local ALPHA_DIM					:number = 0.45;
local COLOR_RED					:number = 0xFF0101F5;
local COLOR_YELLOW				:number = 0xFF2DFFF8;
local COLOR_GREEN				:number = 0xFF4CE710;
local FLAGSTATE_NORMAL			:number= 0;
local FLAGSTATE_FORTIFIED		:number= 1;
local FLAGSTATE_EMBARKED		:number= 2;
local FLAGSTYLE_MILITARY		:number= 0;
local FLAGSTYLE_CIVILIAN		:number= 1;
local FLAGTYPE_UNIT				:number= 0;
local ZOOM_MULT_DELTA			:number = .01;
local TEXTURE_BASE				:string = "MapPinFlag";
local TEXTURE_MASK_BASE			:string = "MapPinFlagMask";


-- ===========================================================================
--	VARIABLES
-- ===========================================================================

-- A link to a container that is rendered after the Unit/City flags.  This is used
-- so that selected units will always appear above the other objects.
local m_SelectedContainer			:table = ContextPtr:LookUpControl( "../SelectedMapPinContainer" );

local m_InstanceManager		:table = InstanceManager:new( "MapPinFlag",	"Anchor", Controls.MapPinFlags );

local m_cameraFocusX				:number = -1;
local m_cameraFocusY				:number = -1;
local m_zoomMultiplier				:number = 1;
local m_MapPinInstances				:table  = {};

-- The meta table definition that holds the function pointers
hstructure MapPinFlagMeta
	-- Pointer back to itself.  Required.
	__index							: MapPinFlagMeta

	new								: ifunction;
	destroy							: ifunction;			-- Destroys the map pin flag.  This does not delete the map pin data in the player's configuration.
	Initialize						: ifunction;
	GetMapPin						: ifunction;
	SetInteractivity				: ifunction;
	SetFogState						: ifunction;
	SetHide							: ifunction;
	SetForceHide					: ifunction;
	SetFlagUnitEmblem				: ifunction;
	SetColor						: ifunction;
	SetDim							: ifunction;
	Refresh							: ifunction;			-- Retreives data from the map pin configuration and refeashes the visual state.
	OverrideDimmed					: ifunction;
	UpdateDimmedState				: ifunction;
	UpdateFlagType					: ifunction;
	UpdateCurrentlyVisible			: ifunction;			-- Updates the currently visible flag based on map pin visibility.
	UpdateVisibility				: ifunction;			-- Update the map pin icon based on current visibility flags.
	UpdateSelected					: ifunction;
	UpdateName						: ifunction;
	UpdatePosition					: ifunction;
	SetPosition						: ifunction;
end

-- The structure that holds the banner instance data
hstructure MapPinFlag
	meta							: MapPinFlagMeta;

	m_InstanceManager				: table;				-- The instance manager that made the control set.
    m_Instance						: table;				-- The instanced control set.
    
    m_Type							: number;				-- Pin type
    m_IsSelected					: boolean;
    m_IsCurrentlyVisible			: boolean;
	m_IsForceHide					: boolean;
    m_IsDimmed						: boolean;
	m_OverrideDimmed				: boolean;
	m_OverrideDim					: boolean;
    
    m_Player						: table;
    m_pinID							: number;				-- The pin ID.  Keeping just the ID, rather than a reference because there will be times when we need the value, but the pin instance will not exist.
end

-- Create one instance of the meta object as a global variable with the same name as the data structure portion.  
-- This allows us to do a MapPinFlag:new, so the naming looks consistent.
MapPinFlag = hmake MapPinFlagMeta {};

-- Link its __index to itself
MapPinFlag.__index = MapPinFlag;



-- ===========================================================================
--	Obtain the unit flag associate with a player and unit.
--	RETURNS: flag object (if found), nil otherwise
-- ===========================================================================
function GetMapPinFlag(playerID:number, pinID:number)
	if m_MapPinInstances[playerID]==nil then
		return nil;
	end
	return m_MapPinInstances[playerID][pinID];
end

------------------------------------------------------------------
-- constructor
------------------------------------------------------------------
function MapPinFlag.new( self : MapPinFlagMeta, playerID: number, pinID : number, flagType : number )
    local o = hmake MapPinFlag { };
    setmetatable( o, self );

	o:Initialize(playerID, pinID, flagType);

	if (m_MapPinInstances[playerID] == nil) then
		m_MapPinInstances[playerID] = {};
	end
	
	m_MapPinInstances[playerID][pinID] = o;
end

------------------------------------------------------------------
function MapPinFlag.destroy( self : MapPinFlag )
    if ( self.m_InstanceManager ~= nil ) then         
        self:UpdateSelected( false );
                        		    
		if (self.m_Instance ~= nil) then
			self.m_InstanceManager:ReleaseInstance( self.m_Instance );
			m_MapPinInstances[ self.m_Player:GetID() ][ self.m_pinID ] = nil;
		end
    end
end

------------------------------------------------------------------
function MapPinFlag.GetMapPin( self : MapPinFlag )
	local playerCfg :table = PlayerConfigurations[self.m_Player:GetID()];
	local playerMapPins :table = playerCfg:GetMapPins();
	return playerMapPins[self.m_pinID];
end

------------------------------------------------------------------
function MapPinFlag.Initialize( self : MapPinFlag, playerID: number, pinID : number, flagType : number)
	if (flagType == FLAGTYPE_UNIT) then
		self.m_InstanceManager = m_InstanceManager;

		self.m_Instance = self.m_InstanceManager:GetInstance();
		self.m_Type = flagType;

		self.m_IsSelected = false;
		self.m_IsCurrentlyVisible = false;
		self.m_IsForceHide = false;
		self.m_IsDimmed = false;
		self.m_OverrideDimmed = false;
    
		self.m_Player = Players[playerID];
		self.m_pinID = pinID;

		self:Refresh();
	end
end

------------------------------------------------------------------
function MapPinFlag.Refresh( self : MapPinFlag )
	local pMapPin = self:GetMapPin();
	if(pMapPin ~= nil) then

		self:UpdateCurrentlyVisible();
		self:SetFlagUnitEmblem();
		self:SetColor();
		self:SetInteractivity();
		self:UpdateFlagType();
		self:UpdateName();
		self:UpdatePosition();
		self:UpdateVisibility();
		self:UpdateDimmedState();
	else
		self:destroy();
	end
end

-- ===========================================================================
function OnMapPinFlagLeftClick( playerID : number, pinID : number )
	-- If we are the owner of this pin, open up the map pin popup
	if(playerID == Game.GetLocalPlayer()) then
		local flagInstance = GetMapPinFlag( playerID, pinID );
		if (flagInstance ~= nil) then
			local pMapPin = flagInstance:GetMapPin();
			if(pMapPin ~= nil) then		
				LuaEvents.MapPinPopup_RequestMapPin(pMapPin:GetHexX(), pMapPin:GetHexY());
			end
		end
	end
end

------------------------------------------------------------------
function OnMapPinFlagRightClick( playerID : number, pinID : number )
	--[[
	-- If we are the owner of this pin, delete the pin.
	if(playerID == Game.GetLocalPlayer()) then
		local playerCfg = PlayerConfigurations[playerID];
		playerCfg:DeleteMapPin(pinID);
		Network.BroadcastPlayerInfo();
        UI.PlaySound("Map_Pin_Remove");
	end
	--]]
end

------------------------------------------------------------------
-- Set the user interativity for the flag.
function MapPinFlag.SetInteractivity( self : MapPinFlag )

    local localPlayerID :number = Game.GetLocalPlayer();
    local flagPlayerID	:number = self.m_Player:GetID();
	local pinID			:number = self.m_pinID;
        			

    self.m_Instance.NormalButton:SetVoid1( flagPlayerID );
    self.m_Instance.NormalButton:SetVoid2( pinID );
    self.m_Instance.NormalButton:RegisterCallback( Mouse.eLClick, OnMapPinFlagLeftClick );
	self.m_Instance.NormalButton:RegisterCallback( Mouse.eRClick, OnMapPinFlagRightClick );
end

------------------------------------------------------------------
-- Set the flag color based on the player colors.
function MapPinFlag.SetColor( self : MapPinFlag )
	local primaryColor, secondaryColor  = UI.GetPlayerColors( self.m_Player:GetID() );
	local darkerFlagColor	:number = DarkenLightenColor(primaryColor,(-85),255);
	local brighterFlagColor :number = DarkenLightenColor(primaryColor,90,255);
	local brighterIconColor :number = DarkenLightenColor(secondaryColor,20,255);
	local darkerIconColor	:number = DarkenLightenColor(secondaryColor,-30,255);
	
	local mapPin = self:GetMapPin();
	-- Determine whether the icon is a default map pin icon
	local isDefaultMapPinIcon = string.find(mapPin:GetIconName(), "ICON_MAP_PIN") ~= nil;
	        
	-- Only set the color if it's a default map pin icon
	if (isDefaultMapPinIcon) then
		self.m_Instance.UnitIcon:SetColor( brighterIconColor );
	end
	
	self.m_Instance.FlagBase:SetColor( primaryColor );
	--self.m_Instance.UnitIconShadow:SetColor( darkerIconColor );
	self.m_Instance.FlagBaseOutline:SetColor( primaryColor );
	self.m_Instance.FlagBaseDarken:SetColor( darkerFlagColor );
	self.m_Instance.FlagBaseLighten:SetColor( primaryColor );

	self.m_Instance.FlagOver:SetColor( brighterFlagColor );
	self.m_Instance.NormalSelect:SetColor( brighterFlagColor );
	self.m_Instance.NormalSelectPulse:SetColor( brighterFlagColor );
end

------------------------------------------------------------------
-- Set the flag texture based on the unit's type
function MapPinFlag.SetFlagUnitEmblem( self : MapPinFlag )
	local pMapPin = self:GetMapPin();
    if pMapPin ~= nil then			
		local iconName = pMapPin:GetIconName();
		local iconNameShadow = pMapPin:GetIconName();
		local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName);
		local textureOffsetShadowX, textureOffsetShadowY, textureSheetShadow = IconManager:FindIconAtlas(iconNameShadow);	

		--[[ Unit icon based lookup
		local iconName = "ICON_" .. unitInfo.UnitType .. "_WHITE";
		local iconNameShadow = "ICON_" .. unitInfo.UnitType .. "_BLACK";
		local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName);
		local textureOffsetShadowX, textureOffsetShadowY, textureSheetShadow = IconManager:FindIconAtlas(iconNameShadow);
		--]]

		if (textureSheet == nil) then			--Check to see if the unit has an icon atlas index defined
			print("Could not find icon for " .. iconName);
			textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas("ICON_MAP_PIN_UNKNOWN_WHITE");		--If not, resolve the index to be a generic unknown index
		end
		if (textureSheetShadow == nil) then
			textureOffsetShadowX, textureOffsetShadowY, textureSheetShadow = IconManager:FindIconAtlas("ICON_MAP_PIN_UNKNOWN_BLACK");
		end

		if (textureSheet ~= nil) then			--Check to make sure that the unknown index is also defined...
			-- Determine icon size, adjust based on whether it's a default icon or not
			local isDefaultMapPinIcon = string.find(iconName, "ICON_MAP_PIN") ~= nil; 
			if (isDefaultMapPinIcon == false) then
				self.m_Instance.UnitIcon:SetSizeX(32);
				self.m_Instance.UnitIcon:SetSizeY(32);
			else
				self.m_Instance.UnitIcon:SetSizeX(24);
				self.m_Instance.UnitIcon:SetSizeY(24);
			end
		
			self.m_Instance.UnitIcon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
		end
		--if (textureSheetShadow ~= nil) then
		--	self.m_Instance.UnitIconShadow:SetTexture( textureOffsetShadowX, textureOffsetShadowY, textureSheetShadow );
		--end
	end
end

------------------------------------------------------------------
function MapPinFlag.SetDim( self : MapPinFlag, bDim : boolean )
	if (self.m_IsDimmed ~= bDim) then
		self.m_IsDimmed = bDim;
		self:UpdateDimmedState();
	end
end

-----------------------------------------------------------------
-- Set whether or not the dimmed state for the flag is overridden
function MapPinFlag.OverrideDimmed( self : MapPinFlag, bOverride : boolean )
	self.m_OverrideDimmed = bOverride;
    self:UpdateDimmedState();
end
     
-----------------------------------------------------------------
-- Set the flag's alpha state, based on the current dimming flags.
function MapPinFlag.UpdateDimmedState( self : MapPinFlag )
	if( self.m_IsDimmed and not self.m_OverrideDimmed ) then
        self.m_Instance.FlagRoot:SetAlpha( ALPHA_DIM );
	else
        self.m_Instance.FlagRoot:SetAlpha( 1.0 );         
    end
end

-----------------------------------------------------------------
-- Change the flag's overall visibility
function MapPinFlag.SetHide( self : MapPinFlag, bHide : boolean )
	self.m_IsCurrentlyVisible = not bHide;
	self:UpdateVisibility();
end

------------------------------------------------------------------
-- Change the flag's force hide
function MapPinFlag.SetForceHide( self : MapPinFlag, bHide : boolean )
	self.m_IsForceHide = bHide;
	self:UpdateVisibility();
end

------------------------------------------------------------------
-- Update the flag's type.  This adjust the look of the flag based
-- on the state of the unit.
function MapPinFlag.UpdateFlagType( self : MapPinFlag )
    local textureName:string;
    local maskName:string;
				
    textureName = TEXTURE_BASE;
    maskName	= TEXTURE_MASK_BASE;
     
	self.m_Instance.FlagBaseDarken:SetTexture( textureName );
	self.m_Instance.FlagBaseLighten:SetTexture( textureName );
    self.m_Instance.FlagBase:SetTexture( textureName );
    self.m_Instance.FlagBaseOutline:SetTexture( textureName );
	self.m_Instance.NormalSelectPulse:SetTexture( textureName );
    self.m_Instance.NormalSelect:SetTexture( textureName );
	self.m_Instance.FlagOver:SetTexture( textureName );
    self.m_Instance.LightEffect:SetTexture( textureName );
        
   self.m_Instance.NormalScrollAnim:SetMask( maskName );
end

------------------------------------------------------------------
function MapPinFlag.UpdateCurrentlyVisible( self : MapPinFlag )
	local pMapPin = self:GetMapPin();
	if(pMapPin ~= nil) then
		local localPlayerID = Game.GetLocalPlayer();
		local showMapPin = pMapPin:IsVisible(localPlayerID);
		self:SetHide(not showMapPin);
	end
end

------------------------------------------------------------------
-- Update the visibility of the flag based on the current state.
function MapPinFlag.UpdateVisibility( self : MapPinFlag )

	local bVisible = self.m_IsCurrentlyVisible and not self.m_IsForceHide;
	self.m_Instance.Anchor:SetHide(not bVisible);

end

------------------------------------------------------------------
-- Update the unit name / tooltip
function MapPinFlag.UpdateName( self : MapPinFlag )
	local pMapPin = self:GetMapPin();
	if(pMapPin ~= nil) then
		local nameString = pMapPin:GetName();
		self.m_Instance.UnitIcon:SetToolTipString( nameString );
		self.m_Instance.NameLabel:SetText( nameString );
		if(nameString ~= nil) then
			self.m_Instance.NameContainer:SetHide(false);
		else
			self.m_Instance.NameContainer:SetHide(true);
		end
	end
end

------------------------------------------------------------------
-- The selection state has changed.
function MapPinFlag.UpdateSelected( self : MapPinFlag, isSelected : boolean )
    self.m_IsSelected = isSelected;
        
	self.m_Instance.NormalSelect:SetHide( not self.m_IsSelected );

        
	-- If selected, change our parent to the selection container so we are on top in the drawing order
    if( self.m_IsSelected ) then
        self.m_Instance.Anchor:ChangeParent( m_SelectedContainer );
    else
		-- Re-attach back to the manager parent            			
		self.m_Instance.Anchor:ChangeParent( self.m_InstanceManager.m_ParentControl );			            
    end
        
    self:OverrideDimmed( self.m_IsSelected );
end

------------------------------------------------------------------
-- Update the position of the flag to match the current unit position.
function MapPinFlag.UpdatePosition( self : MapPinFlag )
	local pMapPin : table = self:GetMapPin();
	if (pMapPin ~= nil) then
		self:SetPosition( UI.GridToWorld( pMapPin:GetHexX(), pMapPin:GetHexY() ) );
	end
end

------------------------------------------------------------------
-- Set the position of the flag.
function MapPinFlag.SetPosition( self : MapPinFlag, worldX : number, worldY : number, worldZ : number )

	local mapPinStackXOffset = 0;
	if (self ~= nil ) then
		local pMapPin : table = self:GetMapPin();
		if (pMapPin ~= nil) then
			local pMapPinLocX = pMapPin:GetHexX();
			local pMapPinLocY = pMapPin:GetHexY();
	
			-- If there are multiple map pins sharing a hex, recenter them
			local pinHexCount = 1;
			for pinInstancePlayerID, playerPinInstances in pairs(m_MapPinInstances) do
				for mapPinInstanceID, mapPinInstance in pairs(playerPinInstances) do
					local pCurMapPin : table = mapPinInstance:GetMapPin();
					if(pCurMapPin ~= nil and pCurMapPin ~= pMapPin) then
						if(pCurMapPin:GetHexX() == pMapPinLocX and pCurMapPin:GetHexY() == pMapPinLocY) then
							pinHexCount = pinHexCount + 1;
						end
					end
				end
			end
			if (pinHexCount > 1) then
				mapPinStackXOffset = 5.5*pinHexCount;
			end;
		end
	end

	local yOffset = 0;	--offset for 2D strategic view
	local zOffset = 0;	--offset for 3D world view
	local xOffset = mapPinStackXOffset;
	self.m_Instance.Anchor:SetWorldPositionVal( worldX+xOffset, worldY+yOffset, worldZ+zOffset );
end


-- ===========================================================================
--	Creates a unit flag (if one doesn't exist).
-- ===========================================================================
function CreateMapPinFlag(mapPinCfg : table)
	if(mapPinCfg ~= nil) then
		local playerID: number = mapPinCfg:GetPlayerID();
		local pinID : number = mapPinCfg:GetID();

		-- If a flag already exists for this player/unit combo... just return.
		local flagInstance = GetMapPinFlag( playerID, pinID );
		if(flagInstance ~= nil) then
			-- Flag already exists, we're probably just reusing the pinID, refresh the pin.
			flagInstance:UpdateName();
			flagInstance:UpdatePosition();			
			return;
		end

		-- Allocate a new flag.
		MapPinFlag:new( playerID, pinID, FLAGTYPE_UNIT );
	end
end

-- ===========================================================================
--	Engine Event
-- ===========================================================================
-------------------------------------------------
-- Zoom level calculation
-------------------------------------------------
function OnCameraUpdate( vFocusX:number, vFocusY:number, fZoomLevel:number )
	m_cameraFocusX	= vFocusX;
	m_cameraFocusY	= vFocusY;

	-- If no change in the zoom, no update necessary.
	if( math.abs( (1-fZoomLevel) - m_zoomMultiplier ) < ZOOM_MULT_DELTA ) then
		return;
	end
	m_zoomMultiplier= 1-fZoomLevel;

	Refresh();
end

------------------------------------------------------------------
function OnPlayerConnectChanged(iPlayerID)
	-- When a human player connects/disconnects, their unit flag tooltips need to be updated.
	local pPlayer = Players[ iPlayerID ];
	if (pPlayer ~= nil) then
		if (m_MapPinInstances[ iPlayerID ] == nil) then
			return;
		end

		local playerFlagInstances = m_MapPinInstances[ iPlayerID ];
		for id, flag in pairs(playerFlagInstances) do
			if (flag ~= nil) then
				flag:UpdateName();
			end
		end
    end
end

------------------------------------------------------------------
function SetForceHideForID( id : table, bState : boolean)
	if (id ~= nil) then
		if (id.componentType == ComponentType.UNIT) then
		    local flagInstance = GetMapPinFlag( id.playerID, id.componentID );
			if (flagInstance ~= nil) then
				flagInstance:SetForceHide(bState);
				flagInstance:UpdatePosition();
			end
		end
    end
end
-------------------------------------------------
-- Combat vis is beginning
-------------------------------------------------
function OnCombatVisBegin( kVisData )

	SetForceHideForID( kVisData[CombatVisType.ATTACKER], true );
	SetForceHideForID( kVisData[CombatVisType.DEFENDER], true );
	SetForceHideForID( kVisData[CombatVisType.INTERCEPTOR], true );
	SetForceHideForID( kVisData[CombatVisType.ANTI_AIR], true );

end

-------------------------------------------------
-- Combat vis is ending
-------------------------------------------------
function OnCombatVisEnd( kVisData )

	SetForceHideForID( kVisData[CombatVisType.ATTACKER], false );
	SetForceHideForID( kVisData[CombatVisType.DEFENDER], false );
	SetForceHideForID( kVisData[CombatVisType.INTERCEPTOR], false );
	SetForceHideForID( kVisData[CombatVisType.ANTI_AIR], false );

end

-- ===========================================================================
--	Refresh the contents of the flags.
--	This does not include the flags' positions in world space; those are
--	updated on another event.
-- ===========================================================================
function Refresh()
	local plotsToUpdate	:table = {};
	local players		:table = Game.GetPlayers{Alive = true, Human = true};

	-- Reset all flags.
	m_InstanceManager:ResetInstances();
	m_MapPinInstances = {};

	for i, player in ipairs(players) do
		local playerID		:number = player:GetID();
		local playerCfg		:table  = PlayerConfigurations[playerID];
		local playerPins	:table  = playerCfg:GetMapPins();
		for ii, mapPinCfg in pairs(playerPins) do
			local pinID		:number = mapPinCfg:GetID();

			-- If flag doesn't exist for this combo, create it:
			if ( m_MapPinInstances[ playerID ] == nil or m_MapPinInstances[ playerID ][ pinID ] == nil) then
					CreateMapPinFlag(mapPinCfg);
			end			
		end
	end
end

------------------------------------------------------------------
function OnPlayerInfoChanged(playerID)
	Refresh();
end
-------------------------------------------------
-- Position the flags appropriately in 2D and 3D view
-------------------------------------------------
function PositionFlagsToView()
	local players = Game.GetPlayers{Alive = true, Human = true};
	for i, player in ipairs(players) do
		local playerID = player:GetID();
		local playerCfg = PlayerConfigurations[playerID];
		local playerPins = playerCfg:GetMapPins();
		for ii, pin in pairs(playerPins) do
			local pinID = pin:GetID();
			local flagInstance = GetMapPinFlag( playerID, pinID );
			if (flagInstance ~= nil) then
				local pMapPin : table = flagInstance:GetMapPin();
				flagInstance:SetPosition( UI.GridToWorld( pMapPin:GetHexX(), pMapPin:GetHexY() ) );

			end
		end
	end
end

-- ===========================================================================
function OnContextInitialize(isHotload : boolean)
	-- If hotloading, rebuild from scratch.
	if isHotload then
		Refresh();
	end
end

----------------------------------------------------------------
function OnLocalPlayerChanged()
	Refresh();
end

-- ===========================================================================
function OnBeginWonderReveal()
	ContextPtr:SetHide( true );
end

-- ===========================================================================
function OnEndWonderReveal()
	ContextPtr:SetHide( false );
end

----------------------------------------------------------------
-- Handle the UI shutting down.
function OnShutdown()
	m_InstanceManager:ResetInstances();
end


-- ===========================================================================
function Initialize()
	
	ContextPtr:SetInitHandler( OnContextInitialize );
	ContextPtr:SetShutdown( OnShutdown );

	Events.BeginWonderReveal.Add( OnBeginWonderReveal );
	Events.Camera_Updated.Add( OnCameraUpdate );
	Events.CombatVisBegin.Add( OnCombatVisBegin );		
	Events.CombatVisEnd.Add( OnCombatVisEnd );
	Events.EndWonderReveal.Add( OnEndWonderReveal );
	Events.LocalPlayerChanged.Add(OnLocalPlayerChanged);
	Events.MultiplayerPlayerConnected.Add( OnPlayerConnectChanged );
	Events.MultiplayerPostPlayerDisconnected.Add( OnPlayerConnectChanged );
	Events.WorldRenderViewChanged.Add(PositionFlagsToView);
	Events.PlayerInfoChanged.Add(OnPlayerInfoChanged);
end
Initialize();

