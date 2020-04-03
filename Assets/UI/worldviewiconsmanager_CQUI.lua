-- ===========================================================================
-- Base File
-- ===========================================================================
include("WorldViewIconsManager");

-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_SetResourceIcon = SetResourceIcon;

-- ===========================================================================
-- CQUI Members
-- ===========================================================================
local CQUI_ResourceIconStyle = 1;

function CQUI_GetSettingsValues()
  CQUI_ResourceIconStyle = GameConfiguration.GetValue("CQUI_ResourceDimmingStyle");
  if CQUI_ResourceIconStyle == nil then
    print("CQUI_ResourceIconStyle is nil!  Using default value.");
    CQUI_ResourceIconStyle = 1;
  end
end

function CQUI_OnIconStyleSettingsUpdate()
  CQUI_GetSettingsValues();
  Rebuild();
end

LuaEvents.CQUI_SettingsUpdate.Add( CQUI_OnIconStyleSettingsUpdate );
LuaEvents.CQUI_SettingsInitialized.Add(CQUI_GetSettingsValues);

function CQUI_IsResourceOptimalImproved(resourceInfo, pPlot)
  if table.count(resourceInfo.ImprovementCollection) > 0 then
    for _, improvement in ipairs(resourceInfo.ImprovementCollection) do
      local optimalTileImprovement = improvement.ImprovementType; --Represents the tile improvement that utilizes the resource most effectively
      local tileImprovement = GameInfo.Improvements[pPlot:GetImprovementType()]; --Can be nil if there is no tile improvement

      --If the tile improvement isn't nil, find the ImprovementType value
      if (tileImprovement ~= nil) then
        tileImprovement = tileImprovement.ImprovementType;
      end

      if tileImprovement == optimalTileImprovement then
        return true;
      end
    end
  end

  return false;
end

-- ===========================================================================
--  CQUI modified SetResourceIcon functiton : Improved resource icon dimming/hiding
-- ===========================================================================
function SetResourceIcon( pInstance:table, pPlot, type, state)
  BASE_SetResourceIcon(pInstance, pPlot, type, state);

  local resourceInfo = GameInfo.Resources[type];
  if (pPlot and resourceInfo ~= nil) then
    local resourceType:string = resourceInfo.ResourceType;
    local iconName = "ICON_" .. resourceType;
    if (state == RevealedState.REVEALED) then
      iconName = iconName .. "_FOW";
    end

    local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName, 256);
    if (textureSheet ~= nil) then
      if (pPlot:GetOwner() == Game.GetLocalPlayer()) then --Only affects plots we own
        if (CQUI_ResourceIconStyle == 0) then
          pInstance.ResourceIcon:SetColor(1,1,1,1);
        elseif (CQUI_ResourceIconStyle == 1) then
          if (CQUI_IsResourceOptimalImproved(resourceInfo, pPlot)) then
              pInstance.ResourceIcon:SetColor(1,1,1,0.5);
            else
              pInstance.ResourceIcon:SetColor(nil);
            end
        elseif (CQUI_ResourceIconStyle == 2) then
          if (CQUI_IsResourceOptimalImproved(resourceInfo, pPlot)) then
            pInstance.ResourceIcon:SetColor(1,1,1,0);
          else
            pInstance.ResourceIcon:SetColor(nil);
          end
        end
      end
    end
  end
end

-- ===========================================================================
--  CQUI modified AddImprovementRecommendationsForCity functiton
--  Don't show builder recommandation, it's often stupid
-- ===========================================================================
function AddImprovementRecommendationsForCity( pCity:table, pSelectedUnit:table )
  return;
end
