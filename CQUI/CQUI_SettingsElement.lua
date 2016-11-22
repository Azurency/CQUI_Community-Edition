--Custom localizations are temporarily disabled due to reloads breaking them at the moment. Localizations are complete, so remember to enable them once Firaxis fixes this!

include("Civ6Common");

-- Members
local m_tabs; --Add new options tabs to this in Initialize function
local bindings_options = {
  --{"LOC_CQUI_BINDINGS_STANDARD", 0},
  --{"LOC_CQUI_BINDINGS_CLASSIC", 1},
  --{"LOC_CQUI_BINDINGS_ENHANCED", 2}
  {"Standard", 0},
  {"Classic", 1},
  {"Enhanced", 2}
};

--Used to populate combobox options
function PopulateComboBox(control, values, setting_name, tooltip)
  control:ClearEntries();
  local current_value = GameConfiguration.GetValue(setting_name);
  if(current_value == nil) then
  if(GameInfo.CQUI_Settings[setting_name]) then --LY Checks if this setting has a default state defined in the database
    current_value = GameInfo.CQUI_Settings[setting_name].Value; --reads the default value from the database. Set them in Settings.sql
  else current_value = 0;
  end
    GameConfiguration.SetValue(setting_name, current_value); --/LY
  end
  for i, v in ipairs(values) do
    local instance = {};
    control:BuildEntry( "InstanceOne", instance );
    instance.Button:SetVoid1(i);
        instance.Button:LocalizeAndSetText(v[1]);
    if(v[2] == current_value) then
      local button = control:GetButton();
      button:LocalizeAndSetText(v[1]);
    end
  end
  control:CalculateInternals();
  if(setting_name) then
    control:RegisterSelectionCallback(
      function(voidValue1, voidValue2, control)
        local option = values[voidValue1];
        local button = control:GetButton();
        button:LocalizeAndSetText(option[1]);
        GameConfiguration.SetValue(setting_name, option[2]);
        LuaEvents.CQUI_SettingsUpdate();
      end
    );
  end
  if(tooltip ~= nil)then
    control:SetToolTipString(tooltip);
  end
end

--Used to populate checkboxes
function PopulateCheckBox(control, setting_name, tooltip)
  local current_value = GameConfiguration.GetValue(setting_name);
  if(current_value == nil) then
  if(GameInfo.CQUI_Settings[setting_name]) then --LY Checks if this setting has a default state defined in the database
    if(GameInfo.CQUI_Settings[setting_name].Value == 0) then --because 0 is true in Lua
      current_value = false;
    else
      current_value = true;
    end
  else current_value = false;
  end
    GameConfiguration.SetValue(setting_name, current_value); --/LY
  end
    if(current_value == false) then
        control:SetSelected(false);
    else
        control:SetSelected(true);
    end
  control:RegisterCallback(Mouse.eLClick, 
    function()
      local selected = not control:IsSelected();
      control:SetSelected(selected);
      GameConfiguration.SetValue(setting_name, selected);
      LuaEvents.CQUI_SettingsUpdate();
    end
  );
  if(tooltip ~= nil)then
    control:SetToolTipString(tooltip);
  end
end

--Used to switch active panels/tabs in the settings panel
function ShowTab(button, panel)
  -- Unfocus all tabs and hide panels
  for i, v in ipairs(m_tabs) do
    v[2]:SetHide(true);
    v[1]:SetSelected(false);
  end 
  button:SetSelected(true);
  panel:SetHide(false);   
  --Controls.WindowTitle:SetText(Locale.Lookup("LOC_CQUI_NAME") .. ": " .. Locale.ToUpper(button:GetText()));
  Controls.WindowTitle:SetText("CQUI: " .. Locale.ToUpper(button:GetText()));
end

function Initialize()
  --Adding/binding tabs...
  m_tabs = {
    {Controls.GeneralTab, Controls.GeneralOptions},
    {Controls.BindingsTab, Controls.BindingsOptions},
    {Controls.PopupsTab, Controls.PopupsOptions},
    {Controls.HiddenTab, Controls.HiddenOptions}
  };
  for i, tab in ipairs(m_tabs) do
    local button = tab[1];
    local panel = tab[2];
    button:RegisterCallback(Mouse.eLClick, function() ShowTab(button, panel); end);
  end
  --Populating/binding comboboxes...
  --PopulateComboBox(Controls.BindingsPullDown, bindings_options, "CQUI_BindingsMode", Locale.Lookup("LOC_CQUI_BINDINGS_DROPDOWN_TOOLTIP"));
  PopulateComboBox(Controls.BindingsPullDown, bindings_options, "CQUI_BindingsMode", "Standard: Unchanged[NEWLINE]Classic: Civ V binds[NEWLINE]Enhanced: Civ V Binds with the following changes[NEWLINE]  WASD camera control[NEWLINE]  Q/E unit/city cycling[NEWLINE]  Shift toggles city/unit selection[NEWLINE]  Quarry/Airstrike are moved to alt-key + Q/S[NEWLINE]  NOTE:UNBIND W/E IN SETTINGS OR THINGS WON'T WORK!");
  
  --Populating/binding checkboxes...
  PopulateCheckBox(Controls.ShowLuxuryCheckbox, "CQUI_ShowLuxuries");
  --PopulateCheckBox(Controls.SmartbannerCheckbox, "CQUI_Smartbanner", Locale.Lookup("LOC_CQUI_GENERAL_SMARTBANNER_TOOLTIP"));
  PopulateCheckBox(Controls.SmartbannerCheckbox, "CQUI_Smartbanner", "Displays new icons in the city banner. A food icon is displayed whenever there are unlocked citizens being automatically assigned by the AI city governor. District icons indicate built districts");
  --PopulateCheckBox(Controls.TechVisualCheckbox, "CQUI_TechPopupVisual", Locale.Lookup("LOC_CQUI_POPUPS_TECHVISUAL_TOOLTIP"));
  PopulateCheckBox(Controls.TechVisualCheckbox, "CQUI_TechPopupVisual", "Toggles the popup that appears whenever a new tech or civic is achieved");
  --PopulateCheckBox(Controls.TechAudioCheckbox, "CQUI_TechPopupAudio", Locale.Lookup("LOC_CQUI_POPUPS_TECHAUDIO_TOOLTIP"));
  PopulateCheckBox(Controls.TechAudioCheckbox, "CQUI_TechPopupAudio", "Toggles the popup audio that plays whenever a new tech or civic is achieved. Is fully indepenedent of the visual component and can play even when there is no visible popup");
  
  --Setting up panel controls
  ShowTab(m_tabs[1][1], m_tabs[1][2]); --Show General Settings on start
  LuaEvents.CQUI_SettingsInitialized(); --Tell other elements that the settings have been initialized and it's safe to try accessing settings now
end

Initialize();
