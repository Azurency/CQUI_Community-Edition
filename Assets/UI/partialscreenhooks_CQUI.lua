-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_CQUI_OnWonderCompleted = OnWonderCompleted;

-- ===========================================================================
-- CQUI Members
-- ===========================================================================
BASE_CQUI_LateInitialize = LateInitialize;

-- ===========================================================================
-- "Modular Screen" mod by Astog
-- ===========================================================================
function OnAddScreenHook(hookInfo:table)
  -- print("Build hook")
  local tButtonEntry:table = {};
  ContextPtr:BuildInstanceForControl("HookIconInstance", tButtonEntry, Controls.ButtonStack);

  local textureOffsetX = hookInfo.IconTexture.OffsetX;
  local textureOffsetY = hookInfo.IconTexture.OffsetY;
  local textureSheet = hookInfo.IconTexture.Sheet;

  -- Update Icon Info
  if (textureOffsetX ~= nil and textureOffsetY ~= nil and textureSheet ~= nil) then
    tButtonEntry.Icon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
  end
  if (hookInfo.IconTexture.Color ~= nil) then
    tButtonEntry.Icon:SetColor(hookInfo.IconTexture.Color);
  end

  if (hookInfo.Tooltip ~= nil) then
    tButtonEntry.Button:SetToolTipString(hookInfo.Tooltip);
  end

  textureOffsetX = hookInfo.BaseTexture.OffsetX;
  textureOffsetY = hookInfo.BaseTexture.OffsetY;
  textureSheet = hookInfo.BaseTexture.Sheet;

  local stateOffsetX = hookInfo.BaseTexture.HoverOffsetX;
  local stateOffsetY = hookInfo.BaseTexture.HoverOffsetY;

  if (textureOffsetX ~= nil and textureOffsetY ~= nil and textureSheet ~= nil) then
    tButtonEntry.Base:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
    if (hookInfo.BaseTexture.Color ~= nil) then
      tButtonEntry.Base:SetColor(hookInfo.BaseTexture.Color);
    end

    -- Setup behaviour on hover
    if (stateOffsetX ~= nil and stateOffsetY ~= nil) then
      local OnMouseOver = function()
        tButtonEntry.Base:SetTextureOffsetVal(stateOffsetX, stateOffsetY);
        UI.PlaySound("Main_Menu_Mouse_Over");
      end

      local OnMouseExit = function()
        tButtonEntry.Base:SetTextureOffsetVal(textureOffsetX, textureOffsetY);
      end

      tButtonEntry.Button:RegisterMouseEnterCallback( OnMouseOver );
      tButtonEntry.Button:RegisterMouseExitCallback( OnMouseExit );
    end
  end

  if (hookInfo.Callback ~= nil) then
    tButtonEntry.Button:RegisterCallback( Mouse.eLClick, hookInfo.Callback );
  end

  Realize();
end

function LateInitialize()
  BASE_CQUI_LateInitialize();

  LuaEvents.PartialScreenHooks_AddHook.Add( OnAddScreenHook );

  -- TESTS
  -----------------------------
  --[[
  local hookInfo1:table = {
    -- ICON TEXTURE
    IconTexture = {
      OffsetX = 0;
      OffsetY = 0;
      Sheet = "MapPins24.dds";
      Color = UI.GetColorValue("COLOR_PLAYER_GOLDENROD")
    };

    -- BUTTON TEXTURE
    BaseTexture = {
      OffsetX = 0;
      OffsetY = 0;
      Sheet = "LaunchBar_Hook_ButtonSmall";

      -- Offset to have when hovering
      HoverOffsetX = 0;
      HoverOffsetY = 40;
    };

    Callback = function() print("Damascus steel!") end;
    Tooltip = "ATTACK!";
  };

  LuaEvents.PartialScreenHooks_AddHook(hookInfo1);
  ]]--
end