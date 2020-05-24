------------------------------------------------------------------------------
--  Additional CQUI Common LUA support functions specific to Civilization 6
--  This file is included by the Civ6Common.lua script
--  TODO (2020-05): Is it possible to NOT require this be included by the Civ6Common?
------------------------------------------------------------------------------

-- ===========================================================================
--  VARIABLES
-- ===========================================================================
local CQUI_ShowDebugPrint = false;

-- ===========================================================================
--CQUI setting control support functions
-- ===========================================================================
function print_debug(str)
  print("ENTRY: CQUICommon - print_debug");
  if CQUI_ShowDebugPrint then
    print(str);
  end
end

function CQUI_OnSettingsUpdate()
  print_debug("ENTRY: CQUICommon - CQUI_OnSettingsUpdate");
  CQUI_ShowDebugPrint = GameConfiguration.GetValue("CQUI_ShowDebugPrint") == 1
end

-- Used to register a control to be updated whenever settings update (only necessary for controls that can be updated from multiple places)
function RegisterControl(control, setting_name, update_function, extra_data)
  print_debug("ENTRY: CQUICommon - RegisterControl");
  LuaEvents.CQUI_SettingsUpdate.Add(function() update_function(control, setting_name, extra_data); end);
end

-- Companion functions to RegisterControl
function UpdateComboBox(control, setting_name, values)
  -- TODO (2020-05) - is this required?
end

function UpdateCheckbox(control, setting_name)
  print_debug("ENTRY: CQUICommon - UpdateCheckbox");
  local value = GameConfiguration.GetValue(setting_name);
  if(value == nil) then
    return;
  end

  control:SetSelected(value);
end

function UpdateSlider( control, setting_name, data_converter)
  print_debug("ENTRY: CQUICommon - UpdateSlider");
  local value = GameConfiguration.GetValue(setting_name);
  if(value == nil) then
    return;
  end

  control:SetStep(data_converter.ToSteps(value));
end

--Used to populate combobox options
function PopulateComboBox(control, values, setting_name, tooltip)
  print_debug("ENTRY: CQUICommon - PopulateComboBox");
  control:ClearEntries();
  local current_value = GameConfiguration.GetValue(setting_name);
  if(current_value == nil) then
    --LY Checks if this setting has a default state defined in the database
    if(GameInfo.CQUI_Settings[setting_name]) then
      --reads the default value from the database. Set them in Settings.sql
      current_value = GameInfo.CQUI_Settings[setting_name].Value;
    else
      current_value = 0;
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
  print_debug("ENTRY: CQUICommon - PopulateCheckBox");
  local current_value = GameConfiguration.GetValue(setting_name);
  if(current_value == nil) then
    --LY Checks if this setting has a default state defined in the database
    if(GameInfo.CQUI_Settings[setting_name]) then
      --because 0 is true in Lua
      if(GameInfo.CQUI_Settings[setting_name].Value == 0) then
        current_value = false;
      else
        current_value = true;
      end
    else
      current_value = false;
    end

    GameConfiguration.SetValue(setting_name, current_value);
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

--Used to populate sliders. data_converter is a table containing two functions: ToStep and ToValue, which describe how to hanlde converting from the incremental slider steps to a setting value, think of it as a less elegant inner class
--Optional third function: ToString. When included, this function will handle how the value is converted to a display value, otherwise this defaults to using the value from ToValue
function PopulateSlider(control, label, setting_name, data_converter, tooltip)
  print_debug("ENTRY: CQUICommon - PopulateSlider");
  --This is necessary because RegisterSliderCallback fires twice when releasing the mouse cursor for some reason
  local hasScrolled = false;
  local current_value = GameConfiguration.GetValue(setting_name);
  if(current_value == nil) then
    --LY Checks if this setting has a default state defined in the database
    if(GameInfo.CQUI_Settings[setting_name]) then
      current_value = GameInfo.CQUI_Settings[setting_name].Value;
    else
      current_value = 0;
    end

    GameConfiguration.SetValue(setting_name, current_value); --/LY
  end

  control:SetStep(data_converter.ToSteps(current_value));
  if(data_converter.ToString) then
    label:SetText(data_converter.ToString(current_value));
  else
    label:SetText(current_value);
  end

  control:RegisterSliderCallback(
    function()
      local value = data_converter.ToValue(control:GetStep());
      if(data_converter.ToString) then
        label:SetText(data_converter.ToString(value));
      else
        label:SetText(value);
      end

      if(not control:IsTrackingLeftMouseButton() and hasScrolled == true) then
        GameConfiguration.SetValue(setting_name, value);
        LuaEvents.CQUI_SettingsUpdate();
        hasScrolled = false;
      else
        hasScrolled = true;
      end
    end
  );

  if(tooltip ~= nil)then
    control:SetToolTipString(tooltip);
  end
end

-- Trims source information from gossip messages. Returns nil if the message couldn't be trimmed (this usually means the provided string wasn't a gossip message at all)
function CQUI_TrimGossipMessage(str:string)
  print_debug("ENTRY: CQUICommon - CQUI_TrimGossipMessage");
  -- Get a sample of a gossip source string
  local sourceSample = Locale.Lookup("LOC_GOSSIP_SOURCE_DELEGATE", "XX", "Y", "Z");

  -- Get last word that occurs in the gossip source string. "that" in English.
  -- Assumes the last word is always the same, which it is in English, unsure if this holds true in other languages
  -- AZURENCY : the patterns means : any character 0 or +, XX exactly, any character 0 or +, space, any character other than space 1 or + at the end of the sentence.
  -- AZURENCY : in some languages, there is no space, in that case, take the last character (often it's a ":")
  last = string.match(sourceSample, ".-XX.-(%s%S+)$"); 
  if last == nil then
    last = string.match(sourceSample, ".-(.)$");
  end

  -- AZURENCY : if last is still nill, it's not normal, print an error but still allow the code to run
  if last == nil then
    print_debug("ERROR : LOC_GOSSIP_SOURCE_DELEGATE seems to be empty as last was still nil after the second pattern matching.")
    last = ""
  end

 -- Return the rest of the string after the last word from the gossip source string
  return Split(str, last .. " " , 2)[2];
end


function Initialize()
  print_debug("INITIALZE: CQUICommon.lua");
  LuaEvents.CQUI_SettingsUpdate.Add(CQUI_OnSettingsUpdate);
  LuaEvents.CQUI_SettingsInitialized.Add(CQUI_OnSettingsUpdate);
end
Initialize();
