-- ===========================================================================
-- Base File
-- ===========================================================================
include("DiplomacyDealView");
include("DiplomacyDealView_CQUI.lua");

g_LocalPlayer = nil;
g_OtherPlayer = nil;

-- ===========================================================================
--	CQUI OnShowMakeDeal to set the g_LocalPlayer and g_OtherPlayer
-- ===========================================================================
function CQUI_OnShowMakeDeal(otherPlayerID)
	g_LocalPlayer = Players[Game.GetLocalPlayer()];
	g_OtherPlayer = Players[otherPlayerID];
	OnShowMakeDeal(otherPlayerID);
end
LuaEvents.DiploPopup_ShowMakeDeal.Add(CQUI_OnShowMakeDeal);
LuaEvents.DiploPopup_ShowMakeDeal.Remove(OnShowMakeDeal);

-- ===========================================================================
--	CQUI OnShowMakeDemand to set the g_LocalPlayer and g_OtherPlayer
-- ===========================================================================
function CQUI_OnShowMakeDemand(otherPlayerID)
    g_LocalPlayer = Players[Game.GetLocalPlayer()];
    g_OtherPlayer = Players[otherPlayerID];
    OnShowMakeDemand(otherPlayerID);
end
LuaEvents.DiploPopup_ShowMakeDemand.Add(CQUI_OnShowMakeDemand);
LuaEvents.DiploPopup_ShowMakeDemand.Remove(OnShowMakeDemand);

-- ===========================================================================
function Initialize()
    print("CQUI Diplomacy Deal View loaded");
end
Initialize();