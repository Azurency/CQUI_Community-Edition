-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_CQUI_VIEW = View;
BASE_CQUI_Refresh = Refresh;

-- ===========================================================================
-- CQUI Members
-- ===========================================================================
local CQUI_ShowImprovementsRecommendations :boolean = false;
function CQUI_OnSettingsUpdate()
  CQUI_ShowImprovementsRecommendations = GameConfiguration.GetValue("CQUI_ShowImprovementsRecommendations") == 1
end
LuaEvents.CQUI_SettingsUpdate.Add(CQUI_OnSettingsUpdate);
LuaEvents.CQUI_SettingsInitialized.Add(CQUI_OnSettingsUpdate);

-- ===========================================================================
--  CQUI modified View functiton : check if we should show the recommanded action
-- ===========================================================================
function View(data)
  BASE_CQUI_VIEW(data);

  if ( data.Actions["BUILD"] ~= nil and #data.Actions["BUILD"] > 0 ) then
    local BUILD_PANEL_ART_PADDING_Y = 20;
    local buildStackHeight :number = Controls.BuildActionsStack:GetSizeY();

    if not CQUI_ShowImprovementsRecommendations then
      Controls.RecommendedActionButton:SetHide(true);
      Controls.BuildActionsPanel:SetSizeY( buildStackHeight + BUILD_PANEL_ART_PADDING_Y);
      Controls.BuildActionsStack:SetOffsetY(0);
    end
  end

  -- CQUI (Azurency) : instead of changing the xml, it's easier to do it in code here (bigger XP bar)
  Controls.XPArea:SetSizeY(15);
  Controls.XPBar:SetSizeY(10);
  Controls.XPLabel:SetFontSize(12);
end

-- ===========================================================================
--  CQUI modified Refresh functiton : AutoExpand
-- ===========================================================================
function Refresh(player, unitId)
  BASE_CQUI_Refresh(player, unitId);

  if(player ~= nil and player ~= -1 and unitId ~= nil and unitId ~= -1) then
    local units = Players[player]:GetUnits();
    local unit = units:FindID(unitId);
    if(unit ~= nil) then
      --CQUI auto-expando
      if(GameConfiguration.GetValue("CQUI_AutoExpandUnitActions")) then
        local isHidden:boolean = Controls.SecondaryActionsStack:IsHidden();
        if isHidden then
          Controls.SecondaryActionsStack:SetHide(false);
          Controls.ExpandSecondaryActionsButton:SetTextureOffsetVal(0,29);
          OnSecondaryActionStackMouseEnter();
          Controls.ExpandSecondaryActionStack:CalculateSize();
          Controls.ExpandSecondaryActionStack:ReprocessAnchoring();
        end

        -- AZURENCY : fix for the size not updating correcly (fall 2017), we calculate the size manually, 4 is the StackPadding
        Controls.ExpandSecondaryActionStack:SetSizeX(Controls.ExpandSecondaryActionsButton:GetSizeX() + Controls.SecondaryActionsStack:GetSizeX() + 4);
        ResizeUnitPanelToFitActionButtons();
      end
    end
  end
end