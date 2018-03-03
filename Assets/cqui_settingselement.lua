--Custom localizations are temporarily disabled due to reloads breaking them at the moment. Localizations are complete, so remember to enable them once Firaxis fixes this!

include("Civ6Common");

-- Members
local m_tabs; --Add new options tabs to this in Initialize function
local bindings_options = {
  {"LOC_CQUI_BINDINGS_STANDARD", 0},
  {"LOC_CQUI_BINDINGS_CLASSIC", 1},
  {"LOC_CQUI_BINDINGS_ENHANCED", 2}
};

local resource_icon_style_options =
{
  {"LOC_CQUI_GENERAL_SOLID", 0},
  {"LOC_CQUI_GENERAL_TRANSPARENT", 1},
  {"LOC_CQUI_GENERAL_HIDDEN", 2}
};

local boolean_options = {
		{"LOC_OPTIONS_ENABLED", 1},
		{"LOC_OPTIONS_DISABLED", 0},
	};

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

--Populates the status message panel checkboxes with appropriate strings
function InitializeGossipCheckboxes()
  Controls.LOC_GOSSIP_AGENDA_KUDOSCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_AGENDA_KUDOS", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_AGENDA_WARNINGCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_AGENDA_WARNING", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_ALLIEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_ALLIED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_ANARCHY_BEGINSCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_ANARCHY_BEGINS", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_ARTIFACT_EXTRACTEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_ARTIFACT_EXTRACTED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_BARBARIAN_INVASION_STARTEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_BARBARIAN_INVASION_STARTED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_BARBARIAN_RAID_STARTEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_BARBARIAN_RAID_STARTED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_BEACH_RESORT_CREATEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_BEACH_RESORT_CREATED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_CHANGE_GOVERNMENTCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_CHANGE_GOVERNMENT", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_CITY_BESIEGEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_CITY_BESIEGED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_CITY_LIBERATEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_CITY_LIBERATED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_CITY_RAZEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_CITY_RAZED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_CLEAR_CAMPCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_CLEAR_CAMP", "X", "Y", "Z", "1", "2", "3") .. " (" .. Locale.Lookup("LOC_IMPROVEMENT_BARBARIAN_CAMP_NAME") .. ")");
  Controls.LOC_GOSSIP_CITY_STATE_INFLUENCECheckbox:SetText(Locale.Lookup("LOC_GOSSIP_CITY_STATE_INFLUENCE", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_CONQUER_CITYCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_CONQUER_CITY", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_CONSTRUCT_DISTRICTCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_CONSTRUCT_DISTRICT", "X", "Y", "Z", "1", "2", "3") .. "  (" .. Locale.Lookup("LOC_DISTRICT_NAME") .. ")");
  Controls.LOC_GOSSIP_CREATE_PANTHEONCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_CREATE_PANTHEON", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_CULTURVATE_CIVICCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_CULTURVATE_CIVIC", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_DECLARED_FRIENDSHIPCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_DECLARED_FRIENDSHIP", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_DELEGATIONCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_DELEGATION", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_DENOUNCEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_DENOUNCED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_EMBASSYCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_EMBASSY", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_ERA_CHANGEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_ERA_CHANGED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_FIND_NATURAL_WONDERCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_FIND_NATURAL_WONDER", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_FOUND_CITYCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_FOUND_CITY", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_FOUND_RELIGIONCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_FOUND_RELIGION", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_GREATPERSON_CREATEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_GREATPERSON_CREATED", "X", "Y", "Z", "1", "2", "3") .. " (" .. Locale.Lookup("LOC_GREAT_PEOPLE_TAB_GREAT_PEOPLE") .. ")");
  Controls.LOC_GOSSIP_LAUNCHING_ATTACKCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_LAUNCHING_ATTACK", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_WAR_PREPARATIONCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_WAR_PREPARATION", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_INQUISITION_LAUNCHEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_INQUISITION_LAUNCHED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_LAND_UNIT_LEVELCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_LAND_UNIT_LEVEL", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_MAKE_DOWCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_MAKE_DOW", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_NATIONAL_PARK_CREATEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_NATIONAL_PARK_CREATED", "X", "Y", "Z", "1", "2", "3") .. " (" .. Locale.Lookup("LOC_NATIONAL_PARK_NAME", "") .. " )");
  Controls.LOC_GOSSIP_NEW_RELIGIOUS_MAJORITYCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_NEW_RELIGIOUS_MAJORITY", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_PILLAGECheckbox:SetText(Locale.Lookup("LOC_GOSSIP_PILLAGE", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_POLICY_ENACTEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_POLICY_ENACTED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_RECEIVE_DOWCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_RECEIVE_DOW", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_RELIC_RECEIVEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_RELIC_RECEIVED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_RESEARCH_AGREEMENTCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_RESEARCH_AGREEMENT", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_RESEARCH_TECHCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_RESEARCH_TECH", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_SPY_DISRUPT_ROCKETRY_DETECTEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_SPY_DISRUPT_ROCKETRY_DETECTED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_SPY_DISRUPT_ROCKETRY_UNDETECTEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_SPY_DISRUPT_ROCKETRY_UNDETECTED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_SPY_GREAT_WORK_HEIST_DETECTEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_SPY_GREAT_WORK_HEIST_DETECTED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_SPY_GREAT_WORK_HEIST_UNDETECTEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_SPY_GREAT_WORK_HEIST_UNDETECTED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_SPY_RECRUIT_PARTISANS_DETECTEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_SPY_RECRUIT_PARTISANS_DETECTED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_SPY_RECRUIT_PARTISANS_UNDETECTEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_SPY_RECRUIT_PARTISANS_UNDETECTED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_SPY_SABOTAGE_PRODUCTION_DETECTEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_SPY_SABOTAGE_PRODUCTION_DETECTED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_SPY_SABOTAGE_PRODUCTION_UNDETECTEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_SPY_SABOTAGE_PRODUCTION_UNDETECTED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_SPY_SIPHON_FUNDS_DETECTEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_SPY_SIPHON_FUNDS_DETECTED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_SPY_SIPHON_FUNDS_UNDETECTEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_SPY_SIPHON_FUNDS_UNDETECTED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_SPY_STEAL_TECH_BOOST_DETECTEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_SPY_STEAL_TECH_BOOST_DETECTED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_SPY_STEAL_TECH_BOOST_UNDETECTEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_SPY_STEAL_TECH_BOOST_UNDETECTED", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_TRADE_DEALCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_TRADE_DEAL", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_TRADE_RENEGECheckbox:SetText(Locale.Lookup("LOC_GOSSIP_TRADE_RENEGE", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_TRAIN_SETTLERCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_TRAIN_SETTLER", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_TRAIN_UNITCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_TRAIN_UNIT", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_TRAIN_UNIQUE_UNITCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_TRAIN_UNIQUE_UNIT", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_PROJECT_STARTEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_PROJECT_STARTED", "X", "Y", "Z", "1", "2", "3") .. " (" .. Locale.Lookup("LOC_PROJECT_NAME") .. ")");
  Controls.LOC_GOSSIP_START_VICTORY_STRATEGYCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_START_VICTORY_STRATEGY", "X", "Y", "Z", "1", "2", "3") .. " (" .. Locale.Lookup("LOC_VICTORY_DEFAULT_NAME") .. ")");
  Controls.LOC_GOSSIP_STOP_VICTORY_STRATEGYCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_STOP_VICTORY_STRATEGY", "X", "Y", "Z", "1", "2", "3") .. " (" .. Locale.Lookup("LOC_VICTORY_DEFAULT_NAME") .. ")");
  Controls.LOC_GOSSIP_WMD_BUILTCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_WMD_BUILT", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_WMD_STRIKECheckbox:SetText(Locale.Lookup("LOC_GOSSIP_WMD_STRIKE", "X", "Y", "Z", "1", "2", "3"));
  Controls.LOC_GOSSIP_WONDER_STARTEDCheckbox:SetText(Locale.Lookup("LOC_GOSSIP_WONDER_STARTED", "X", "Y", "Z", "1", "2", "3") .. " (" .. Locale.Lookup("LOC_WONDER_NAME") .. ")");

  PopulateCheckBox(Controls.LOC_GOSSIP_AGENDA_KUDOSCheckbox, "CQUI_LOC_GOSSIP_AGENDA_KUDOS");
  PopulateCheckBox(Controls.LOC_GOSSIP_AGENDA_WARNINGCheckbox, "CQUI_LOC_GOSSIP_AGENDA_WARNING");
  PopulateCheckBox(Controls.LOC_GOSSIP_ALLIEDCheckbox, "CQUI_LOC_GOSSIP_ALLIED");
  PopulateCheckBox(Controls.LOC_GOSSIP_ANARCHY_BEGINSCheckbox, "CQUI_LOC_GOSSIP_ANARCHY_BEGINS");
  PopulateCheckBox(Controls.LOC_GOSSIP_ARTIFACT_EXTRACTEDCheckbox, "CQUI_LOC_GOSSIP_ARTIFACT_EXTRACTED");
  PopulateCheckBox(Controls.LOC_GOSSIP_BARBARIAN_INVASION_STARTEDCheckbox, "CQUI_LOC_GOSSIP_BARBARIAN_INVASION_STARTED");
  PopulateCheckBox(Controls.LOC_GOSSIP_BARBARIAN_RAID_STARTEDCheckbox, "CQUI_LOC_GOSSIP_BARBARIAN_RAID_STARTED");
  PopulateCheckBox(Controls.LOC_GOSSIP_BEACH_RESORT_CREATEDCheckbox, "CQUI_LOC_GOSSIP_BEACH_RESORT_CREATED");
  PopulateCheckBox(Controls.LOC_GOSSIP_CHANGE_GOVERNMENTCheckbox, "CQUI_LOC_GOSSIP_CHANGE_GOVERNMENT");
  PopulateCheckBox(Controls.LOC_GOSSIP_CITY_BESIEGEDCheckbox, "CQUI_LOC_GOSSIP_CITY_BESIEGED");
  PopulateCheckBox(Controls.LOC_GOSSIP_CITY_LIBERATEDCheckbox, "CQUI_LOC_GOSSIP_CITY_LIBERATED");
  PopulateCheckBox(Controls.LOC_GOSSIP_CITY_RAZEDCheckbox, "CQUI_LOC_GOSSIP_CITY_RAZED");
  PopulateCheckBox(Controls.LOC_GOSSIP_CLEAR_CAMPCheckbox, "CQUI_LOC_GOSSIP_CLEAR_CAMP");
  PopulateCheckBox(Controls.LOC_GOSSIP_CITY_STATE_INFLUENCECheckbox, "CQUI_LOC_GOSSIP_CITY_STATE_INFLUENCE");
  PopulateCheckBox(Controls.LOC_GOSSIP_CONQUER_CITYCheckbox, "CQUI_LOC_GOSSIP_CONQUER_CITY");
  PopulateCheckBox(Controls.LOC_GOSSIP_CONSTRUCT_DISTRICTCheckbox, "CQUI_LOC_GOSSIP_CONSTRUCT_DISTRICT");
  PopulateCheckBox(Controls.LOC_GOSSIP_CREATE_PANTHEONCheckbox, "CQUI_LOC_GOSSIP_CREATE_PANTHEON");
  PopulateCheckBox(Controls.LOC_GOSSIP_CULTURVATE_CIVICCheckbox, "CQUI_LOC_GOSSIP_CULTURVATE_CIVIC");
  PopulateCheckBox(Controls.LOC_GOSSIP_DECLARED_FRIENDSHIPCheckbox, "CQUI_LOC_GOSSIP_DECLARED_FRIENDSHIP");
  PopulateCheckBox(Controls.LOC_GOSSIP_DELEGATIONCheckbox, "CQUI_LOC_GOSSIP_DELEGATION");
  PopulateCheckBox(Controls.LOC_GOSSIP_DENOUNCEDCheckbox, "CQUI_LOC_GOSSIP_DENOUNCED");
  PopulateCheckBox(Controls.LOC_GOSSIP_EMBASSYCheckbox, "CQUI_LOC_GOSSIP_EMBASSY");
  PopulateCheckBox(Controls.LOC_GOSSIP_ERA_CHANGEDCheckbox, "CQUI_LOC_GOSSIP_ERA_CHANGED");
  PopulateCheckBox(Controls.LOC_GOSSIP_FIND_NATURAL_WONDERCheckbox, "CQUI_LOC_GOSSIP_FIND_NATURAL_WONDER");
  PopulateCheckBox(Controls.LOC_GOSSIP_FOUND_CITYCheckbox, "CQUI_LOC_GOSSIP_FOUND_CITY");
  PopulateCheckBox(Controls.LOC_GOSSIP_FOUND_RELIGIONCheckbox, "CQUI_LOC_GOSSIP_FOUND_RELIGION");
  PopulateCheckBox(Controls.LOC_GOSSIP_GREATPERSON_CREATEDCheckbox, "CQUI_LOC_GOSSIP_GREATPERSON_CREATED");
  PopulateCheckBox(Controls.LOC_GOSSIP_LAUNCHING_ATTACKCheckbox, "CQUI_LOC_GOSSIP_LAUNCHING_ATTACK");
  PopulateCheckBox(Controls.LOC_GOSSIP_WAR_PREPARATIONCheckbox, "CQUI_LOC_GOSSIP_WAR_PREPARATION");
  PopulateCheckBox(Controls.LOC_GOSSIP_INQUISITION_LAUNCHEDCheckbox, "CQUI_LOC_GOSSIP_INQUISITION_LAUNCHED");
  PopulateCheckBox(Controls.LOC_GOSSIP_LAND_UNIT_LEVELCheckbox, "CQUI_LOC_GOSSIP_LAND_UNIT_LEVEL");
  PopulateCheckBox(Controls.LOC_GOSSIP_MAKE_DOWCheckbox, "CQUI_LOC_GOSSIP_MAKE_DOW");
  PopulateCheckBox(Controls.LOC_GOSSIP_NATIONAL_PARK_CREATEDCheckbox, "CQUI_LOC_GOSSIP_NATIONAL_PARK_CREATED");
  PopulateCheckBox(Controls.LOC_GOSSIP_NEW_RELIGIOUS_MAJORITYCheckbox, "CQUI_LOC_GOSSIP_NEW_RELIGIOUS_MAJORITY");
  PopulateCheckBox(Controls.LOC_GOSSIP_PILLAGECheckbox, "CQUI_LOC_GOSSIP_PILLAGE");
  PopulateCheckBox(Controls.LOC_GOSSIP_POLICY_ENACTEDCheckbox, "CQUI_LOC_GOSSIP_POLICY_ENACTED");
  PopulateCheckBox(Controls.LOC_GOSSIP_RECEIVE_DOWCheckbox, "CQUI_LOC_GOSSIP_RECEIVE_DOW");
  PopulateCheckBox(Controls.LOC_GOSSIP_RELIC_RECEIVEDCheckbox, "CQUI_LOC_GOSSIP_RELIC_RECEIVED");
  PopulateCheckBox(Controls.LOC_GOSSIP_RESEARCH_AGREEMENTCheckbox, "CQUI_LOC_GOSSIP_RESEARCH_AGREEMENT");
  PopulateCheckBox(Controls.LOC_GOSSIP_RESEARCH_TECHCheckbox, "CQUI_LOC_GOSSIP_RESEARCH_TECH");
  PopulateCheckBox(Controls.LOC_GOSSIP_SPY_DISRUPT_ROCKETRY_DETECTEDCheckbox, "CQUI_LOC_GOSSIP_SPY_DISRUPT_ROCKETRY_DETECTED");
  PopulateCheckBox(Controls.LOC_GOSSIP_SPY_DISRUPT_ROCKETRY_UNDETECTEDCheckbox, "CQUI_LOC_GOSSIP_SPY_DISRUPT_ROCKETRY_UNDETECTED");
  PopulateCheckBox(Controls.LOC_GOSSIP_SPY_GREAT_WORK_HEIST_DETECTEDCheckbox, "CQUI_LOC_GOSSIP_SPY_GREAT_WORK_HEIST_DETECTED");
  PopulateCheckBox(Controls.LOC_GOSSIP_SPY_GREAT_WORK_HEIST_UNDETECTEDCheckbox, "CQUI_LOC_GOSSIP_SPY_GREAT_WORK_HEIST_UNDETECTED");
  PopulateCheckBox(Controls.LOC_GOSSIP_SPY_RECRUIT_PARTISANS_DETECTEDCheckbox, "CQUI_LOC_GOSSIP_SPY_RECRUIT_PARTISANS_DETECTED");
  PopulateCheckBox(Controls.LOC_GOSSIP_SPY_RECRUIT_PARTISANS_UNDETECTEDCheckbox, "CQUI_LOC_GOSSIP_SPY_RECRUIT_PARTISANS_UNDETECTED");
  PopulateCheckBox(Controls.LOC_GOSSIP_SPY_SABOTAGE_PRODUCTION_DETECTEDCheckbox, "CQUI_LOC_GOSSIP_SPY_SABOTAGE_PRODUCTION_DETECTED");
  PopulateCheckBox(Controls.LOC_GOSSIP_SPY_SABOTAGE_PRODUCTION_UNDETECTEDCheckbox, "CQUI_LOC_GOSSIP_SPY_SABOTAGE_PRODUCTION_UNDETECTED");
  PopulateCheckBox(Controls.LOC_GOSSIP_SPY_SIPHON_FUNDS_DETECTEDCheckbox, "CQUI_LOC_GOSSIP_SPY_SIPHON_FUNDS_DETECTED");
  PopulateCheckBox(Controls.LOC_GOSSIP_SPY_SIPHON_FUNDS_UNDETECTEDCheckbox, "CQUI_LOC_GOSSIP_SPY_SIPHON_FUNDS_UNDETECTED");
  PopulateCheckBox(Controls.LOC_GOSSIP_SPY_STEAL_TECH_BOOST_DETECTEDCheckbox, "CQUI_LOC_GOSSIP_SPY_STEAL_TECH_BOOST_DETECTED");
  PopulateCheckBox(Controls.LOC_GOSSIP_SPY_STEAL_TECH_BOOST_UNDETECTEDCheckbox, "CQUI_LOC_GOSSIP_SPY_STEAL_TECH_BOOST_UNDETECTED");
  PopulateCheckBox(Controls.LOC_GOSSIP_TRADE_DEALCheckbox, "CQUI_LOC_GOSSIP_TRADE_DEAL");
  PopulateCheckBox(Controls.LOC_GOSSIP_TRADE_RENEGECheckbox, "CQUI_LOC_GOSSIP_TRADE_RENEGE");
  PopulateCheckBox(Controls.LOC_GOSSIP_TRAIN_SETTLERCheckbox, "CQUI_LOC_GOSSIP_TRAIN_SETTLER");
  PopulateCheckBox(Controls.LOC_GOSSIP_TRAIN_UNITCheckbox, "CQUI_LOC_GOSSIP_TRAIN_UNIT");
  PopulateCheckBox(Controls.LOC_GOSSIP_TRAIN_UNIQUE_UNITCheckbox, "CQUI_LOC_GOSSIP_TRAIN_UNIQUE_UNIT");
  PopulateCheckBox(Controls.LOC_GOSSIP_PROJECT_STARTEDCheckbox, "CQUI_LOC_GOSSIP_PROJECT_STARTED");
  PopulateCheckBox(Controls.LOC_GOSSIP_START_VICTORY_STRATEGYCheckbox, "CQUI_LOC_GOSSIP_START_VICTORY_STRATEGY");
  PopulateCheckBox(Controls.LOC_GOSSIP_STOP_VICTORY_STRATEGYCheckbox, "CQUI_LOC_GOSSIP_STOP_VICTORY_STRATEGY");
  PopulateCheckBox(Controls.LOC_GOSSIP_WMD_BUILTCheckbox, "CQUI_LOC_GOSSIP_WMD_BUILT");
  PopulateCheckBox(Controls.LOC_GOSSIP_WMD_STRIKECheckbox, "CQUI_LOC_GOSSIP_WMD_STRIKE");
  PopulateCheckBox(Controls.LOC_GOSSIP_WONDER_STARTEDCheckbox, "CQUI_LOC_GOSSIP_WONDER_STARTED");
end

function InitializeTraderScreenCheckboxes()
  PopulateCheckBox(Controls.TraderAddDividerCheckbox, "CQUI_TraderAddDivider", Locale.Lookup("LOC_CQUI_TRADER_ADD_DIVIDER_TOOLTIP"));
  PopulateCheckBox(Controls.TraderShowSortOrderCheckbox, "CQUI_TraderShowSortOrder", Locale.Lookup("LOC_CQUI_TRADER_SHOW_SORT_ORDER_TOOLTIP"));
end

-- ===========================================================================
--  Input
--  UI Event Handler
-- ===========================================================================
function KeyDownHandler( key:number )
  if key == Keys.VK_SHIFT then
    m_shiftDown = true;
    -- let it fall through
  end
  return false;
end
function KeyUpHandler( key:number )
  if key == Keys.VK_SHIFT then
    m_shiftDown = false;
    -- let it fall through
  end
  if key == Keys.VK_ESCAPE then
    Close();
    return true;
  end
  if key == Keys.VK_RETURN then
    return true; -- Don't let enter propigate or it will hit action panel which will raise a screen (potentially this one again) tied to the action.
  end
  return false;
end
function OnInputHandler( pInputStruct:table )
  local uiMsg = pInputStruct:GetMessageType();
  if uiMsg == KeyEvents.KeyDown then return KeyDownHandler( pInputStruct:GetKey() ); end
  if uiMsg == KeyEvents.KeyUp then return KeyUpHandler( pInputStruct:GetKey() ); end
  return false;
end
function Close()
  UI.PlaySound("UI_Pause_Menu_On");
  ContextPtr:SetHide(true);
end

--Used to convert between slider steps and production item height
--Minimum value is 24, maximum is 128. This translates to the 0th step and the 104th
local ProductionItemHeightConverter = {
  ToSteps = function(value)
    local out = value - 24;
    if(out < 0) then out = 0;
    elseif(out > 104) then out = 104; end
    return out;
  end,
  ToValue = function(steps)
    local out = steps + 24;
    if(out > 128) then out = 128; end
    return out;
  end
};

--Minimum value is 48, maximum is 128, but only multiples of 8 are allowed. This translates to 10 steps, or 0th step to the 9th
local WorkIconSizeConverter = {
  ToSteps = function(value)
    local out = math.floor((value - 48) / 8);
    if(out < 0) then out = 0; end
    return out;
  end,
  ToValue = function(steps)
    local out = (steps) * 8 + 48;
    if(out > 128) then out = 128; end
    return out;
  end
};

--Minimum value is 0, maximum is 100. This translates to 101 steps, or 0th step to 100th
local WorkIconAlphaConverter = {
  ToSteps = function(value)
    local out = value;
    if(out < 0) then out = 0; end
    return out;
  end,
  ToValue = function(steps)
    local out = steps;
    if(out > 100) then out = 100; end
    return out;
  end,
  ToString = function(value)
    local out = tostring(value) .. "%"
    return out;
  end
};

function OnShow()
  UI.PlaySound("UI_Pause_Menu_On");
  -- From Civ6_styles: FullScreenVignetteConsumer
  Controls.ScreenAnimIn:SetToBeginning();
  Controls.ScreenAnimIn:Play();
end

function Initialize()
  ContextPtr:SetHide(true);
  --Adding/binding tabs...
  m_tabs = {
    {Controls.GeneralTab, Controls.GeneralOptions},
    {Controls.BindingsTab, Controls.BindingsOptions},
    {Controls.PopupsTab, Controls.PopupsOptions},
    {Controls.GossipTab, Controls.GossipOptions},
    {Controls.CityviewTab, Controls.CityviewOptions},
    {Controls.LensesTab, Controls.LensesOptions},
    {Controls.UnitsTab, Controls.UnitsOptions},
    {Controls.TraderScreenTab, Controls.TraderScreenOption},
    {Controls.RecommendationsTab, Controls.RecommendationsOptions},
    {Controls.HiddenTab, Controls.HiddenOptions}
  };
  for i, tab in ipairs(m_tabs) do
    local button = tab[1];
    local panel = tab[2];
    button:RegisterCallback(Mouse.eLClick, function() ShowTab(button, panel); end);
  end

  -- Close callback
  Controls.ConfirmButton:RegisterCallback(Mouse.eLClick, Close);

  --Populating/binding comboboxes...
  PopulateComboBox(Controls.BindingsPullDown, bindings_options, "CQUI_BindingsMode", Locale.Lookup("LOC_CQUI_BINDINGS_DROPDOWN_TOOLTIP"));
  PopulateComboBox(Controls.ResourceIconStyle, resource_icon_style_options, "CQUI_ResourceDimmingStyle", Locale.Lookup("LOC_CQUI_GENERAL_RESOURCEDIMMINGSTYLE_TOOLTIP"));
  PopulateComboBox(Controls.ProductionRecommendationsPullDown, boolean_options, "CQUI_ShowProductionRecommendations");
  PopulateComboBox(Controls.TechRecommendationsPullDown, boolean_options, "CQUI_ShowTechCivicRecommendations");
  PopulateComboBox(Controls.ImprovementsRecommendationsPullDown, boolean_options, "CQUI_ShowImprovementsRecommendations");
  PopulateComboBox(Controls.CityDetailAdvisorPullDown, boolean_options, "CQUI_ShowCityDetailAdvisor");

  --Populating/binding checkboxes...
  PopulateCheckBox(Controls.ProductionQueueCheckbox, "CQUI_ProductionQueue");
  RegisterControl(Controls.ProductionQueueCheckbox, "CQUI_ProductionQueue", UpdateCheckbox);
  PopulateCheckBox(Controls.ShowLuxuryCheckbox, "CQUI_ShowLuxuries");
  PopulateCheckBox(Controls.ShowDiploBannerCheckbox, "CQUI_ShowDiploBanner");
  PopulateCheckBox(Controls.ShowCultureGrowthCheckbox, "CQUI_ShowCultureGrowth", Locale.Lookup("LOC_CQUI_CITYVIEW_SHOWCULTUREGROWTH_TOOLTIP"));
  RegisterControl(Controls.ShowCultureGrowthCheckbox, "CQUI_ShowCultureGrowth", UpdateCheckbox);
  PopulateCheckBox(Controls.SmartbannerCheckbox, "CQUI_Smartbanner", Locale.Lookup("LOC_CQUI_CITYVIEW_SMARTBANNER_TOOLTIP"));
  PopulateCheckBox(Controls.SmartbannerUnlockedCitizenCheckbox, "CQUI_Smartbanner_UnlockedCitizen", Locale.Lookup("LOC_CQUI_CITYVIEW_SMARTBANNER_UNLOCKEDCITIZEN_TOOLTIP"));
  PopulateCheckBox(Controls.SmartbannerDistrictsCheckbox, "CQUI_Smartbanner_Districts", Locale.Lookup("LOC_CQUI_CITYVIEW_SMARTBANNER_DISTRICTS_TOOLTIP"));
  PopulateCheckBox(Controls.SmartbannerPopulationCheckbox, "CQUI_Smartbanner_Population", Locale.Lookup("LOC_CQUI_CITYVIEW_SMARTBANNER_POPULATION_TOOLTIP"));
  PopulateCheckBox(Controls.SmartbannerCulturalCheckbox, "CQUI_Smartbanner_Cultural", Locale.Lookup("LOC_CQUI_CITYVIEW_SMARTBANNER_CULTURAL_TOOLTIP"));
  PopulateCheckBox(Controls.ToggleYieldsOnLoadCheckbox, "CQUI_ToggleYieldsOnLoad");
  PopulateCheckBox(Controls.BlockOnCityAttackCheckbox, "CQUI_BlockOnCityAttack", Locale.Lookup("LOC_CQUI_CITYVIEW_BLOCKONCITYATTACK_TOOLTIP"));
  PopulateCheckBox(Controls.TechVisualCheckbox, "CQUI_TechPopupVisual", Locale.Lookup("LOC_CQUI_POPUPS_TECHVISUAL_TOOLTIP"));
  PopulateCheckBox(Controls.TechAudioCheckbox, "CQUI_TechPopupAudio", Locale.Lookup("LOC_CQUI_POPUPS_TECHAUDIO_TOOLTIP"));
  PopulateCheckBox(Controls.WonderBuiltVisualCheckbox, "CQUI_WonderBuiltPopupVisual", Locale.Lookup("LOC_CQUI_POPUPS_WONDERBUILTVISUAL_TOOLTIP"));
  PopulateCheckBox(Controls.WonderBuiltAudioCheckbox, "CQUI_WonderBuiltPopupAudio", Locale.Lookup("LOC_CQUI_POPUPS_WONDERBUILTAUDIO_TOOLTIP"));
  PopulateCheckBox(Controls.TrimGossipCheckbox, "CQUI_TrimGossip", Locale.Lookup("LOC_CQUI_GOSSIP_TRIMMESSAGE_TOOLTIP"));

  -- Lenses
  PopulateCheckBox(Controls.AutoapplyArchaeologistLensCheckbox, "CQUI_AutoapplyArchaeologistLens");
  PopulateCheckBox(Controls.AutoapplyBuilderLensCheckbox, "CQUI_AutoapplyBuilderLens");
  PopulateCheckBox(Controls.AutoapplyScoutLensCheckbox, "CQUI_AutoapplyScoutLens");
  --PopulateCheckBox(Controls.ShowNothingToDoInBuilderLens, "CQUI_ShowNothingToDoBuilderLens", Locale.Lookup("LOC_CQUI_LENSES_SHOWNOTHINGTODO_BUILDER_TOOLTIP"));
  --PopulateCheckBox(Controls.ShowGenericInBuilderLens, "CQUI_ShowGenericBuilderLens", Locale.Lookup("LOC_CQUI_LENSES_SHOWGENERIC_BUILDER_TOOLTIP"));

  PopulateCheckBox(Controls.ShowYieldsOnCityHoverCheckbox, "CQUI_ShowYieldsOnCityHover", Locale.Lookup("LOC_CQUI_CITYVIEW_SHOWYIELDSONCITYHOVER_TOOLTIP"));
  PopulateCheckBox(Controls.ShowCitizenIconsOnHoverCheckbox, "CQUI_ShowCitizenIconsOnCityHover", Locale.Lookup("LOC_CQUI_CITYVIEW_SHOWCITIZENICONSONHOVER_TOOLTIP"));
  PopulateCheckBox(Controls.ShowCityManageAreaOnHoverCheckbox, "CQUI_ShowCityManageAreaOnCityHover", Locale.Lookup("LOC_CQUI_CITYVIEW_SHOWCITYMANAGEONHOVER_TOOLTIP"));
  PopulateCheckBox(Controls.ShowCityManageAreaInScreenCheckbox, "CQUI_ShowCityMangeAreaInScreen", Locale.Lookup("LOC_CQUI_CITYVIEW_SHOWCITYMANAGEINSCREEN_TOOLTIP"));
  PopulateCheckBox(Controls.ShowUnitPathsCheckbox, "CQUI_ShowUnitPaths");
  PopulateCheckBox(Controls.AutoExpandUnitActionsCheckbox, "CQUI_AutoExpandUnitActions");
  PopulateCheckBox(Controls.AlwaysOpenTechTreesCheckbox, "CQUI_AlwaysOpenTechTrees");
  PopulateCheckBox(Controls.SmartWorkIconCheckbox, "CQUI_SmartWorkIcon", Locale.Lookup("LOC_CQUI_CITYVIEW_SMARTWORKICON_TOOLTIP"));
  PopulateCheckBox(Controls.ShowPolicyReminderCheckbox, "CQUI_ShowPolicyReminder", Locale.Lookup("LOC_CQUI_GENERAL_SHOWPRD_TOOLTIP"));
  PopulateSlider(Controls.ProductionItemHeightSlider, Controls.ProductionItemHeightText, "CQUI_ProductionItemHeight", ProductionItemHeightConverter);
  PopulateSlider(Controls.WorkIconSizeSlider, Controls.WorkIconSizeText, "CQUI_WorkIconSize", WorkIconSizeConverter);
  PopulateSlider(Controls.SmartWorkIconSizeSlider, Controls.SmartWorkIconSizeText, "CQUI_SmartWorkIconSize", WorkIconSizeConverter);
  PopulateSlider(Controls.WorkIconAlphaSlider, Controls.WorkIconAlphaText, "CQUI_WorkIconAlpha", WorkIconAlphaConverter);
  PopulateSlider(Controls.SmartWorkIconAlphaSlider, Controls.SmartWorkIconAlphaText, "CQUI_SmartWorkIconAlpha", WorkIconAlphaConverter);

  InitializeGossipCheckboxes();
  InitializeTraderScreenCheckboxes();

  ContextPtr:SetShowHandler( OnShow );

  --Setting up panel controls
  ShowTab(m_tabs[1][1], m_tabs[1][2]); --Show General Settings on start
  ContextPtr:SetInputHandler( OnInputHandler, true );

  --Bind CQUI events
  LuaEvents.CQUI_ToggleSettings.Add(function() ContextPtr:SetHide(not ContextPtr:IsHidden()); end);
  LuaEvents.CQUI_SettingsUpdate.Add(ToggleSmartbannerCheckboxes);
  LuaEvents.CQUI_SettingsUpdate.Add(ToggleSmartWorkIconSettings);

  LuaEvents.CQUI_SettingsInitialized(); --Tell other elements that the settings have been initialized and it's safe to try accessing settings now
end

function ToggleSmartbannerCheckboxes()
  local selected = Controls.SmartbannerCheckbox:IsSelected();
  Controls.SmartbannerCheckboxes:SetHide(not selected);
  Controls.CityViewStack:ReprocessAnchoring();
end
function ToggleSmartWorkIconSettings()
  local selected = Controls.SmartWorkIconCheckbox:IsSelected();
  Controls.SmartWorkIconSettings:SetHide(not selected);
  Controls.CityViewStack:ReprocessAnchoring();
end

Initialize();
