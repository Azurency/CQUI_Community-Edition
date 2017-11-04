-- ===========================================================================
--  Popups when policies can still be changed at the end of the turn
-- ===========================================================================
include("TechAndCivicSupport"); -- (Already includes Civ6Common and InstanceManager) PopulateUnlockablesForTech, PopulateUnlockablesForCivic, GetUnlockablesForCivic, GetUnlockablesForTech

-- ===========================================================================
--  CONSTANTS / MEMBERS
-- ===========================================================================
local m_unlockIM :table = InstanceManager:new( "UnlockInstance", "Top", Controls.UnlockStack );

-- ===========================================================================
function RefreshSize()
  Controls.BottomControlStack:CalculateSize();
  Controls.BottomControlStack:ReprocessAnchoring();

  Controls.PopupBackgroundImage:DoAutoSize();
  Controls.PopupDrowShadowGrid:DoAutoSize();
end

-- ===========================================================================
function ShowPolicyReminderPopup(player:number, civic:number)
  local civicInfo:table = GameInfo.Civics[civic];
  if civicInfo ~= nil then
    local civicType = civicInfo.CivicType;

    -- Update Theme Icons
    Controls.TopLeftIcon:SetTexture(0, 0, "CompletedPopup_CivicTheme1");
    Controls.LeftBottomIcon:SetTexture(0, 0, "CompletedPopup_CivicTheme2");
    Controls.RightBottomIcon:SetTexture(0, 0, "CompletedPopup_CivicTheme3");

    -- Update Unlocked Icons
    m_unlockIM:ResetInstances();

    local unlockables = GetUnlockablesForCivic(civicType, player);

    if(unlockables and #unlockables > 0) then
      for i,v in ipairs(unlockables) do
        local typeName = v[1];
        local civilopediaKey = v[3];
        local typeInfo = GameInfo.Types[typeName];

        if(typeInfo and typeInfo.Kind == "KIND_POLICY") then
          local unlockIcon = m_unlockIM:GetInstance();
          local icon = GetUnlockIcon(typeName);	
          unlockIcon.Icon:SetIcon("ICON_"..typeName);
          unlockIcon.Icon:SetHide(false);

          local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(icon,38);
          if textureSheet ~= nil then
            unlockIcon.UnlockIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
          end

          local toolTip = ToolTipHelper.GetToolTip(typeName, player);

          unlockIcon.UnlockIcon:LocalizeAndSetToolTip(toolTip);
        end
      end
    end

    Controls.UnlockStack:CalculateSize();
    Controls.UnlockStack:ReprocessAnchoring();

    Controls.ChangeGovernmentButton:SetText(Locale.Lookup("LOC_GOVT_CHANGE_POLICIES"));
    Controls.ChangeGovernmentButton:ClearCallback( eLClick );
    Controls.ChangeGovernmentButton:RegisterCallback( eLClick, OnChangePolicy );
    Controls.ChangeGovernmentButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

    -- Show Change Government Button
    Controls.ChangeGovernmentButton:SetHide(false);
  end
end

-- ===========================================================================
function OnCQUIShowPolicyReminderPopup( player:number, civic:number)
  if player == Game.GetLocalPlayer() then
    ShowPolicyReminderPopup(player, civic);
    UIManager:QueuePopup( ContextPtr, PopupPriority.Current);
    RefreshSize();
  end
end

-- ===========================================================================
function OnChangePolicy()
  Close();
  LuaEvents.OnCQUIPolicyReminderOpenedChangePolicy()
  LuaEvents.TechCivicCompletedPopup_GovernmentOpenPolicies();   -- Open Government Screen
  UI.PlaySound("Stop_Speech_Civics");
end

function OnClose()
  Close()
  LuaEvents.OnCQUIPolicyReminderClose()
end

-- ===========================================================================
--  Closes the immediate popup, will raise more if queued.
-- ===========================================================================
function Close()
  -- Dequeue popup from UI mananger (will re-queue if another is about to show).
  UIManager:DequeuePopup( ContextPtr );
end

-- ===========================================================================
function OnInputHandler( input )
  local msg = input:GetMessageType();
  if (msg == KeyEvents.KeyUp) then
    local key = input:GetKey();
    if key == Keys.VK_ESCAPE then
      OnClose();
      return true;
    end
  end
  return false;
end

-- ===========================================================================
function Initialize()
  ContextPtr:SetHide(true)
  -- Controls Events
  Controls.CloseButton:RegisterCallback( eLClick, OnClose );
  Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  ContextPtr:SetInputHandler( OnInputHandler, true );
  -- CQUI Events
  LuaEvents.CQUI_ShowPolicyReminderPopup.Add(OnCQUIShowPolicyReminderPopup);
end
Initialize();
