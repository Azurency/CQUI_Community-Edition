-- ===========================================================================
--	Leader container list on top of the HUD
-- ===========================================================================
include("InstanceManager");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local SCROLL_SPEED			:number = 3;
local SIZE_LEADER			:number = 52;
local PADDING_LEADER		:number = 3;
local BG_PADDING_EDGE		:number = 20;
local OFF_LEFT_ARROW		:number = 20;
local OFF_LEFT_SCREEN		:number = 360;
local RIGHT_HOOKS_INITIAL	:number	= 163;
local MIN_LEFT_HOOKS		:number	= 260;
local MINIMUM_BG_SIZE		:number = 100;
local WORLD_TRACKER_OFFSET	:number	= 40;
local BAR_PADDING			:number	= 50;

local VALID_RELATIONSHIPS	:table = {
	"DIPLO_STATE_ALLIED",
	"DIPLO_STATE_DECLARED_FRIEND",
	"DIPLO_STATE_DENOUNCED",
	"DIPLO_STATE_WAR"
};
  
-- ===========================================================================
--	VARIABLES
-- ===========================================================================
local m_leadersMet			:number = 0; -- Number of leaders in the ribbon
local m_scrollIndex			:number = 0; -- Index of leader that is supposed to be on the far right
local m_scrollPercent		:number = 0; -- Necessary for scroll lerp
local m_maxNumLeaders		:number = 0; -- Number of leaders that can fit in the ribbon
local m_isScrolling			:boolean = false;
local m_uiLeadersByID		:table = {};
local m_uiChatIconsVisible	:table = {};
local m_kLeaderIM			:table = InstanceManager:new("LeaderInstance", "LeaderContainer", Controls.LeaderStack);
local m_PartialScreenHookBar: table;	-- = ContextPtr:LookUpControl( "/InGame/PartialScreenHooks/LaunchBacking" );
local m_LaunchBar			: table;	-- = ContextPtr:LookUpControl( "/InGame/LaunchBar/LaunchBacking" );

-- ===========================================================================
--	Cleanup leaders
-- ===========================================================================
function ResetLeaders()
	m_leadersMet = 0;
	m_uiLeadersByID = {};
	m_kLeaderIM:ResetInstances();
end

-- ===========================================================================
function OnLeaderClicked(playerID : number )
	-- Send an event to open the leader in the diplomacy view (only if they met)

	local localPlayerID:number = Game.GetLocalPlayer();
	if playerID == localPlayerID or Players[localPlayerID]:GetDiplomacy():HasMet(playerID) then
		LuaEvents.DiplomacyRibbon_OpenDiplomacyActionView( playerID );
	end
end

function IsValidRelationship(relationshipType:string)
	for _:number, tmpType:string in ipairs(VALID_RELATIONSHIPS) do
		if relationshipType == tmpType then
			return true;
		end
	end
	return false;
end

-- ===========================================================================
--	Add a leader (from right to left)
-- ===========================================================================
function AddLeader(iconName : string, playerID : number, isUniqueLeader: boolean)
	m_leadersMet = m_leadersMet + 1;

	local pPlayer:table = Players[playerID];
	local pPlayerConfig:table = PlayerConfigurations[playerID];
	local isHuman:boolean = pPlayerConfig:IsHuman();

	-- Create a new leader instance
	local instance:table = m_kLeaderIM:GetInstance();
	m_uiLeadersByID[playerID] = instance;
	
	-- Display the civ colors/icon for duplicate civs
	if(isUniqueLeader == false) then
		local backColor, frontColor  = UI.GetPlayerColors( playerID );
		instance.CivIndicator:SetHide(false);
		instance.CivIndicator:SetColor(backColor);
		instance.CivIcon:SetColor(frontColor);
		instance.CivIcon:SetIcon("ICON_"..pPlayerConfig:GetCivilizationTypeName());
	end

	-- Set leader portrait
	instance.Portrait:SetIcon(iconName);
	-- Register the click handler
	instance.Button:RegisterCallback( Mouse.eLClick, function() OnLeaderClicked(playerID); end );

	local bShowRelationshipIcon:boolean = false;
	local localPlayerID:number = Game.GetLocalPlayer();

	if(playerID == localPlayerID) then
		instance.YouIndicator:SetHide(false);
	else
		-- Set relationship status (for non-local players)
		local diplomaticAI:table = pPlayer:GetDiplomaticAI();
		local relationshipStateID:number = diplomaticAI:GetDiplomaticStateIndex(localPlayerID);
		if relationshipStateID ~= -1 then
			local relationshipState:table = GameInfo.DiplomaticStates[relationshipStateID];
			-- Always show relationship icon for AIs, only show player triggered states for humans
			if not isHuman or IsValidRelationship(relationshipState.StateType) then
				-- KWG: This is bad, there is a piece of art that is tied to the order of a database entry.  Please fix!
				instance.Relationship:SetVisState(relationshipStateID);
				instance.Relationship:SetToolTipString(Locale.Lookup(relationshipState.Name));
				bShowRelationshipIcon = true;
			end
		end
	end
  
  -- DRS MOD: Set score values for DRS display
  instance.DRSScoreOverall:SetText("[ICON_Capital]"..Players[playerID]:GetScore());
  instance.DRSScienceRate:SetText("[ICON_Science]"..Round(Players[playerID]:GetTechs():GetScienceYield(),0));
  instance.DRSMilitaryStrength:SetText("[ICON_Strength]"..Players[playerID]:GetStats():GetMilitaryStrength());
  
	instance.Relationship:SetHide(not bShowRelationshipIcon);

	-- Set the tooltip
	if(pPlayerConfig ~= nil) then
		local leaderTypeName:string = pPlayerConfig:GetLeaderTypeName();
		if(leaderTypeName ~= nil) then
			local leaderDesc:string = pPlayerConfig:GetLeaderName();
			local civDesc:string = pPlayerConfig:GetCivilizationDescription();
			
			if GameConfiguration.IsAnyMultiplayer() and isHuman then
				if(playerID ~= localPlayerID and not Players[localPlayerID]:GetDiplomacy():HasMet(playerID)) then
					instance.Portrait:SetToolTipString(Locale.Lookup("LOC_DIPLOPANEL_UNMET_PLAYER") .. " (" .. pPlayerConfig:GetPlayerName() .. ")");
				else
					instance.Portrait:SetToolTipString(Locale.Lookup("LOC_DIPLOMACY_DEAL_PLAYER_PANEL_TITLE", leaderDesc, civDesc) .. " (" .. pPlayerConfig:GetPlayerName() .. ")");
				end
			else
				instance.Portrait:LocalizeAndSetToolTip("LOC_DIPLOMACY_DEAL_PLAYER_PANEL_TITLE", leaderDesc, civDesc);
			end
		end
	end
end

-- ===========================================================================
--	Clears leaders and re-adds them to the stack
-- ===========================================================================
function UpdateLeaders()
	-- Clear previous list items
	ResetLeaders();

	-- Add entries for everyone we know (Majors only)
	local aPlayers:table = PlayerManager.GetAliveMajors();
	local localPlayerID:number = Game.GetLocalPlayer();
	if (localPlayerID ~= -1) then		-- It is possible to not have a local player!
		local localPlayer:table = Players[localPlayerID];
		local localDiplomacy:table = localPlayer:GetDiplomacy();

		table.sort(aPlayers, function(a:table,b:table) return localDiplomacy:GetMetTurn(a:GetID()) < localDiplomacy:GetMetTurn(b:GetID()) end);

		--First, add me!
		AddLeader("ICON_"..PlayerConfigurations[localPlayerID]:GetLeaderTypeName(), localPlayerID);

		--Then, let's do a check to see if any of these players are duplicate leaders and track it.
		--		Must go through entire list to detect duplicates (would be lovely if we had an IsUnique from PlayerConfigurations)
		local metPlayers:table = {};
		local isUniqueLeader:table = {};
		for _, pPlayer in ipairs(aPlayers) do
			local playerID:number = pPlayer:GetID();
			if(playerID ~= localPlayerID) then
				local playerMet:boolean = localDiplomacy:HasMet(playerID);
				if (playerMet) then
					local leaderName:string = PlayerConfigurations[playerID]:GetLeaderTypeName();
					if (isUniqueLeader[leaderName] == nil) then
						isUniqueLeader[leaderName] = true;
					else
						isUniqueLeader[leaderName] = false;
					end	
				end
				metPlayers[playerID] = playerMet;
			end
		end

		--Then, add the leader icons.
		for _, pPlayer in ipairs(aPlayers) do
			local playerID:number = pPlayer:GetID();
			if(playerID ~= localPlayerID) then
				local playerMet:boolean = metPlayers[playerID];
				local pPlayerConfig:table = PlayerConfigurations[playerID];
				if (playerMet or (GameConfiguration.IsAnyMultiplayer() and pPlayerConfig:IsHuman())) then
					if playerMet then
						local leaderName:string = pPlayerConfig:GetLeaderTypeName();
						AddLeader("ICON_"..leaderName, playerID, isUniqueLeader[leaderName]);
					else
						AddLeader("ICON_LEADER_DEFAULT", playerID);
					end
				end
			end
		end
	end

	Controls.LeaderStack:CalculateSize();
	RealizeSize();
end

-- ===========================================================================
--	Updates size and location of BG and Scroll controls
-- ===========================================================================
-- Optional size argument being passed in through an event.
local BG_TILE_PADDING: number	= 0;
function RealizeSize( barWidth:number )
	local launchBarWidth = MIN_LEFT_HOOKS;
	local partialScreenBarWidth = RIGHT_HOOKS_INITIAL;

	m_PartialScreenHookBar	= ContextPtr:LookUpControl( "/InGame/PartialScreenHooks/ButtonStack" );
	m_LaunchBar				= ContextPtr:LookUpControl( "/InGame/LaunchBar/ButtonStack" );
	
	if (m_LaunchBar ~= nil) then
		launchBarWidth = math.max(m_LaunchBar:GetSizeX() + WORLD_TRACKER_OFFSET + BG_TILE_PADDING, MIN_LEFT_HOOKS);
	end

	if (m_PartialScreenHookBar~=nil) then
		partialScreenBarWidth = m_PartialScreenHookBar:GetSizeX() + BG_TILE_PADDING;
	end

	local screenWidth:number, screenHeight:number = UIManager:GetScreenSizeVal(); -- Cache screen dimensions
	
	local maxSize:number = screenWidth - launchBarWidth - partialScreenBarWidth;
	m_maxNumLeaders = math.floor(maxSize / (SIZE_LEADER + PADDING_LEADER));
	
	local size:number = maxSize;
	if(m_leadersMet == 0) then
		Controls.LeaderBG:SetHide(true);
	else
		Controls.LeaderBG:SetHide(false);
		size = m_maxNumLeaders * (SIZE_LEADER + PADDING_LEADER) - 8;
		local bgSize;
		if (m_leadersMet > m_maxNumLeaders) then
			bgSize = m_maxNumLeaders * (SIZE_LEADER + PADDING_LEADER)+ BG_PADDING_EDGE;
		else
			bgSize = m_leadersMet * (SIZE_LEADER + PADDING_LEADER)+ BG_PADDING_EDGE;
		end
		Controls.LeaderBG:SetSizeX(math.max(bgSize, MINIMUM_BG_SIZE));
		Controls.LeaderBGClip:SetSizeX(math.max(bgSize, MINIMUM_BG_SIZE));
		Controls.RibbonContainer:SetSizeX(math.max(bgSize, MINIMUM_BG_SIZE));
	end
	Controls.LeaderScroll:SetSizeX(size);
	Controls.RibbonContainer:ReprocessAnchoring();
	Controls.RibbonContainer:SetOffsetX(partialScreenBarWidth);
	Controls.LeaderScroll:CalculateSize();
	Controls.LeaderScroll:ReprocessAnchoring();
	Controls.LeaderBG:ReprocessAnchoring();
	RealizeScroll();
end

-- ===========================================================================
--	Updates visibility of previous and next buttons
-- ===========================================================================
function RealizeScroll()
	Controls.NextButtonContainer:SetHide(not CanScroll(-1));
	Controls.PreviousButtonContainer:SetHide(not CanScroll(1));
end

-- ===========================================================================
--	Determines visibility of previous and next buttons
-- ===========================================================================
function CanScroll(direction : number)
	if(direction < 0) then
		return m_scrollIndex > 0;
	else
		return m_leadersMet - m_scrollIndex > m_maxNumLeaders;
	end
end

-- ===========================================================================
--	Initialize scroll animation in a particular direction
-- ===========================================================================
function Scroll(direction : number)
 
	m_scrollPercent = 0;
	m_scrollIndex = m_scrollIndex + direction;

	if(m_scrollIndex < 0) then m_scrollIndex = 0; end

	if(not m_isScrolling) then
		ContextPtr:SetUpdate( UpdateScroll );
		m_isScrolling = true;
	end

	RealizeScroll();
end

-- ===========================================================================
--	Update scroll animation (only called while animating)
-- ===========================================================================
function UpdateScroll(deltaTime : number)
	
	local start:number = Controls.LeaderScroll:GetScrollValue();
	local destination:number = 1.0 - (m_scrollIndex / (m_leadersMet - m_maxNumLeaders));

	m_scrollPercent = m_scrollPercent + (SCROLL_SPEED * deltaTime);
	if(m_scrollPercent >= 1) then
		m_scrollPercent = 1
		EndScroll();
	end

	Controls.LeaderScroll:SetScrollValue(start + (destination - start) * m_scrollPercent);
end

-- ===========================================================================
--	Cleans up scroll update callback when done scrollin
-- ===========================================================================
function EndScroll()
	ContextPtr:ClearUpdate();
	m_isScrolling = false;
	RealizeScroll();
end

-- ===========================================================================
--	SystemUpdateUI Callback
-- ===========================================================================
function OnUpdateUI(type:number, tag:string, iData1:number, iData2:number, strData1:string)
	if(type == SystemUpdateUI.ScreenResize) then
		RealizeSize();
	end
end

-- ===========================================================================
--	Diplomacy Callback
-- ===========================================================================
function OnDiplomacyMeet(player1ID:number, player2ID:number)
	
	local localPlayerID:number = Game.GetLocalPlayer();
	-- Have a local player?
	if(localPlayerID ~= -1) then
		-- Was the local player involved?
		if (player1ID == localPlayerID or player2ID == localPlayerID) then
			UpdateLeaders();
		end
	end
end

-- ===========================================================================
--	Diplomacy Callback
-- ===========================================================================
function OnDiplomacyWarStateChange(player1ID:number, player2ID:number)
	
	local localPlayerID:number = Game.GetLocalPlayer();
	-- Have a local player?
	if(localPlayerID ~= -1) then
		-- Was the local player involved?
		if (player1ID == localPlayerID or player2ID == localPlayerID) then
			UpdateLeaders();
		end
	end
end

-- ===========================================================================
--	Diplomacy Callback
-- ===========================================================================
function OnDiplomacySessionClosed(sessionID:number)

	local localPlayerID:number = Game.GetLocalPlayer();
	-- Have a local player?
	if(localPlayerID ~= -1) then
		-- Was the local player involved?
		local diplomacyInfo:table = DiplomacyManager.GetSessionInfo(sessionID);
		if(diplomacyInfo ~= nil and (diplomacyInfo.FromPlayer == localPlayerID or diplomacyInfo.ToPlayer == localPlayerID)) then
			UpdateLeaders();
		end
	end

end

-- ===========================================================================
--	Game Engine Event
-- ===========================================================================
function OnInterfaceModeChanged(eOldMode:number, eNewMode:number)
	if eNewMode == InterfaceModeTypes.VIEW_MODAL_LENS then
		ContextPtr:SetHide(true);
	end
	if eOldMode == InterfaceModeTypes.VIEW_MODAL_LENS then
		ContextPtr:SetHide(false);
	end
end

-- ===========================================================================
--	LocalPlayerTurnBegin / RemotePlayerTurnBegin Callback
-- ===========================================================================
function OnTurnBegin(playerID:number)
	local leader:table = m_uiLeadersByID[playerID];
	if(leader ~= nil) then
		leader.LeaderContainer:SetToBeginning();
		leader.LeaderContainer:Play();
	end
end

function OnTurnEnd(playerID:number)
	if(playerID ~= -1) then
		local leader = m_uiLeadersByID[playerID];
		if(leader ~= nil) then
			leader.LeaderContainer:Reverse();
		end
    UpdateLeaders();
	end
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnScrollLeft()
	if CanScroll(-1) then Scroll(-1); end
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnScrollRight()
	if CanScroll(1) then Scroll(1); end
end

-- ===========================================================================
--	DRS Mod Functions
-- ===========================================================================
function Round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    if num >= 0 then return math.floor(num * mult + 0.5) / mult
    else return math.ceil(num * mult - 0.5) / mult end
end


-- ===========================================================================
--	Debug Helper
-- ===========================================================================
function DebugWorstCase()
	-- Clear previous list items
	ResetLeaders();

	for i=1, 50 do
		AddLeader("ICON_LEADER_DEFAULT", i);
	end

	Controls.LeaderStack:CalculateSize();
	RealizeSize();
end

function OnChatReceived(fromPlayer:number, stayOnScreen:boolean)
	local instance:table= m_uiLeadersByID[fromPlayer];
	if instance == nil then return; end
	if stayOnScreen then
		Controls.ChatIndicatorWaitTimer:Stop();
		instance.ChatIndicatorFade:RegisterEndCallback(function() end);
		table.insert(m_uiChatIconsVisible, instance.ChatIndicatorFade);
	else
		Controls.ChatIndicatorWaitTimer:Stop();

		instance.ChatIndicatorFade:RegisterEndCallback(function() 
			Controls.ChatIndicatorWaitTimer:RegisterEndCallback(function()
				instance.ChatIndicatorFade:RegisterEndCallback(function() instance.ChatIndicatorFade:SetToBeginning(); end);
				instance.ChatIndicatorFade:Reverse();
			end);
			Controls.ChatIndicatorWaitTimer:SetToBeginning();
			Controls.ChatIndicatorWaitTimer:Play();
		end);
	end
	instance.ChatIndicatorFade:Play();
end

function OnChatPanelShown(fromPlayer:number, stayOnScreen:boolean)
	for _, chatIndicatorFade in ipairs(m_uiChatIconsVisible) do
		chatIndicatorFade:RegisterEndCallback(function() chatIndicatorFade:SetToBeginning(); end);
		chatIndicatorFade:Reverse();
	end
	chatIndicatorFade = {};
end

-- ===========================================================================
--	INIT
-- ===========================================================================
function Initialize()
	--DebugWorstCase();
	UpdateLeaders();
	Controls.LeaderScroll:SetScrollValue(1);

	Events.SystemUpdateUI.Add( OnUpdateUI );
	Events.DiplomacyMeet.Add( OnDiplomacyMeet );
	Events.DiplomacySessionClosed.Add( OnDiplomacySessionClosed );
	Events.DiplomacyDeclareWar.Add( OnDiplomacyWarStateChange ); 
	Events.DiplomacyMakePeace.Add( OnDiplomacyWarStateChange ); 
	Events.DiplomacyRelationshipChanged.Add( UpdateLeaders ); 
	Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
	Events.RemotePlayerTurnBegin.Add( OnTurnBegin );
	Events.RemotePlayerTurnEnd.Add( OnTurnEnd );
	Events.LocalPlayerTurnBegin.Add( function() OnTurnBegin(Game.GetLocalPlayer()); end );
	Events.LocalPlayerTurnEnd.Add( function() OnTurnEnd(Game.GetLocalPlayer()); end );
	Events.MultiplayerPlayerConnected.Add(UpdateLeaders);
	Events.MultiplayerPostPlayerDisconnected.Add(UpdateLeaders);
	Events.LocalPlayerChanged.Add(UpdateLeaders);
	Events.PlayerInfoChanged.Add(UpdateLeaders);
	Events.PlayerDefeat.Add(UpdateLeaders);
	Events.PlayerRestored.Add(UpdateLeaders);

	LuaEvents.ChatPanel_OnChatReceived.Add(OnChatReceived);
	LuaEvents.WorldTracker_OnChatShown.Add(OnChatPanelShown);
	LuaEvents.LaunchBar_Resize.Add(RealizeSize);
	LuaEvents.PartialScreenHooks_Resize.Add(RealizeSize);

	Controls.NextButton:RegisterCallback( Mouse.eLClick, OnScrollLeft );
	Controls.PreviousButton:RegisterCallback( Mouse.eLClick, OnScrollRight );
end
Initialize();
