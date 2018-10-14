--[[
-- Original Created by Keaton VanAuken on Nov 29 2017
-- Original Copyright (c) Firaxis Games
--]]

-- ===========================================================================
-- Base File
-- ===========================================================================
include("espionageoverview");

-- ===========================================================================
-- CACHE BASE FUNCTIONS
-- ===========================================================================
BASE_ShouldAddPlayer = ShouldAddPlayer;
BASE_ShouldAddToFilter = ShouldAddToFilter;

-- ===========================================================================
-- Modified conditions (handles free cities, ie not adding them)
-- ===========================================================================
function ShouldAddPlayer(player:table)
  local localPlayer = Players[Game.GetLocalPlayer()];
  if (player:GetID() == localPlayer:GetID() or player:GetTeam() == -1 or localPlayer:GetTeam() == -1 or player:GetTeam() ~= localPlayer:GetTeam()) then
    if (not player:IsFreeCities()) then
      return true
    end
  end
  return false
end

-- ===========================================================================
-- Modified to include city states
-- ===========================================================================
function ShouldAddToFilter(player:table)
  if (not player:IsFreeCities()) and HasMetAndAlive(player) and (not player:IsBarbarian()) then
    return true
  end
  return false
end
