-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_CQUI_LateInitialize = LateInitialize;
BASE_CQUI_RefreshResources = RefreshResources;

-- ===========================================================================
-- CQUI Members
-- ===========================================================================
local CQUI_showLuxury = true;

function CQUI_OnSettingsUpdate()
  CQUI_showLuxury = GameConfiguration.GetValue("CQUI_ShowLuxuries");
  RefreshResources();
end

-- ===========================================================================
--  CQUI modified RefreshResources functiton
--  Show luxury resources
-- ===========================================================================
function RefreshResources()
  BASE_CQUI_RefreshResources();

  local localPlayerID = Game.GetLocalPlayer();
  if (localPlayerID ~= -1) then
    local pPlayerResources  =  Players[localPlayerID]:GetResources();
    local yieldStackX    = Controls.YieldStack:GetSizeX();
    local infoStackX    = Controls.StaticInfoStack:GetSizeX();
    local metaStackX    = Controls.RightContents:GetSizeX();
    local screenX, _:number = UIManager:GetScreenSizeVal();
    local maxSize = screenX - yieldStackX - infoStackX - metaStackX - META_PADDING;
    if (maxSize < 0) then maxSize = 0; end
    local currSize = 0;
    local isOverflow = false;
    local overflowString = "";
    local plusInstance:table;

    -- CQUI/jhcd: show RESOURCECLASS_LUXURY too, if it is enabled in CQUI settings
    if (CQUI_showLuxury) then
      for resource in GameInfo.Resources() do
        if (resource.ResourceClassType ~= nil and resource.ResourceClassType ~= "RESOURCECLASS_BONUS" and resource.ResourceClassType ~= "RESOURCECLASS_STRATEGIC" and resource.ResourceClassType ~="RESOURCECLASS_ARTIFACT") then
          local amount = pPlayerResources:GetResourceAmount(resource.ResourceType);
          if (amount > 0) then
            local resourceText = "[ICON_"..resource.ResourceType.."] ".. amount;
            local numDigits = 3;
            if (amount >= 10) then
              numDigits = 4;
            end
            local guessinstanceWidth = math.ceil(numDigits * FONT_MULTIPLIER);
            if(currSize + guessinstanceWidth < maxSize and not isOverflow) then
              if (amount ~= 0) then
                local instance:table = m_kResourceIM:GetInstance();
                instance.ResourceText:SetText(resourceText);
                instance.ResourceText:SetToolTipString(Locale.Lookup(resource.Name).."[NEWLINE]"..Locale.Lookup("LOC_TOOLTIP_LUXURY_RESOURCE"));
                instanceWidth = instance.ResourceText:GetSizeX();
                currSize = currSize + instanceWidth;
              end
            else
              if (not isOverflow) then
                overflowString = amount.. "[ICON_"..resource.ResourceType.."]".. Locale.Lookup(resource.Name);
                local instance:table = m_kResourceIM:GetInstance();
                instance.ResourceText:SetText("[ICON_Plus]");
                plusInstance = instance.ResourceText;
              else
                overflowString = overflowString .. "[NEWLINE]".. amount.. "[ICON_"..resource.ResourceType.."]".. Locale.Lookup(resource.Name);
              end
              isOverflow = true;
            end
          end
        end
      end
    end

    if (plusInstance ~= nil) then
      plusInstance:SetToolTipString(overflowString);
    end
    Controls.ResourceStack:CalculateSize();
    if(Controls.ResourceStack:GetSizeX() == 0) then
      Controls.Resources:SetHide(true);
    else
      Controls.Resources:SetHide(false);
    end
  end
end

-- ===========================================================================
--  CQUI modified OnToggleReportsScreen functiton
--  Moved this to launchbar.lua since we moved the button there 
-- ===========================================================================
function OnToggleReportsScreen()
end

function LateInitialize()
  BASE_CQUI_LateInitialize()

  LuaEvents.CQUI_SettingsUpdate.Add(CQUI_OnSettingsUpdate);
  if Controls.ViewReports then
    Controls.ViewReports:SetHide(true); -- CQUI : hide the report button, moved to launchbar
  end
end
