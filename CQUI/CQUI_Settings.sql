/*  
    ╔════════════════════════════════════════════════════════════════════════════════════════════╗
    ║                                   CQUI Default settings                                    ║
    ╠════════════════════════════════════════════════════════════════════════════════════════════╣
    ║Created by LordYanaek for CQUI mod by chaorace.                                             ║
    ║Those are the settings loaded by default by CQUI.                                           ║
    ║You can change many of those from the in-game GUI but settings changed in this config file  ║
    ║will persist between games (settings changed from the GUI won't affect a new game)          ║
    ╚════════════════════════════════════════════════════════════════════════════════════════════╝
*/
  
  
/*  
    ┌────────────────────────────────────────────────────────────────────────────────────────────┐
    │                                    Checkbox settings                                       │
    ├────────────────────────────────────────────────────────────────────────────────────────────┤
    │These settings control the default state of the CQUI configuration checkboxes.              │
    │Valid values are 0 (disabled) or 1 (unabled). Don't change the names or the first line!     │
    └────────────────────────────────────────────────────────────────────────────────────────────┘
*/

INSERT INTO CQUI_Settings -- Don't touch this line!
  VALUES  ("CQUI_ShowLuxuries", 1), -- Luxury resources will show in the top-bar next to strategic resources
      ("CQUI_Smartbanner", 1), -- Additional informations such as districts will show in the city banner
      ("CQUI_TechPopupVisual", 0), -- Popups will be displayed when you discover a new tech or civic (this is the normal behavior for the unmoded game)
      ("CQUI_TechPopupAudio", 1), -- Play the voiceovers when you discover a new tech or civic (this is the normal behavior for the unmoded game)
      ("CQUI_ToggleYieldsOnLoad", 1); -- Toggles yields immediately on load
      
/*  
    ┌────────────────────────────────────────────────────────────────────────────────────────────┐
    │                                    Combobox settings                                       │
    ├────────────────────────────────────────────────────────────────────────────────────────────┤
    │These settings control the default state of the CQUI configuration comboboxes.              │
    │Different values can be used depending on individual settings.                              │
    │Don't change the names of the settings or the first line!                                   │
    └────────────────────────────────────────────────────────────────────────────────────────────┘
*/

INSERT INTO CQUI_Settings -- Don't touch this line!
  VALUES  ("CQUI_BindingsMode", 1); -- Set of keybindings used │ 0=Civ6 default │ 1=keybinds from Civ5 │ 2=Civ5 with additions such as WASD camera control │

/*  
    ┌────────────────────────────────────────────────────────────────────────────────────────────┐
    │                                    Slider settings                                         │
    ├────────────────────────────────────────────────────────────────────────────────────────────┤
    │These settings control the default value of the CQUI configuration sliders.                 │
    │Different values can be used depending on individual settings.                              │
    │Don't change the names of the settings or the first line!                                   │
    └────────────────────────────────────────────────────────────────────────────────────────────┘
*/

INSERT INTO CQUI_Settings -- Don't touch this line!
  VALUES  ("CQUI_ProductionItemHeight", 32); -- Height used for individual items in the production queue. Recommended values fall between 24 and 128, though any positive could work

/*  
    ┌────────────────────────────────────────────────────────────────────────────────────────────┐
    │                                    Gossip settings                                         │
    ├────────────────────────────────────────────────────────────────────────────────────────────┤
    │These settings control the default state of the Gossip message checkboxes                   │
    │Valid values are 0 (disabled) or 1 (enabled). Don't change the names or the first line!     │
    └────────────────────────────────────────────────────────────────────────────────────────────┘
*/

INSERT INTO CQUI_Settings -- Don't touch this line!
  VALUES  ("CQUI_TrimGossip", 1), --Trims the source from the start of gossip messages
    --Values controlling individual gossip messages
    ("CQUI_LOC_GOSSIP_AGENDA_KUDOS", 0),
    ("CQUI_LOC_GOSSIP_AGENDA_WARNING", 1),
    ("CQUI_LOC_GOSSIP_ALLIED", 1),
    ("CQUI_LOC_GOSSIP_ANARCHY_BEGINS", 1),
    ("CQUI_LOC_GOSSIP_ARTIFACT_EXTRACTED", 0),
    ("CQUI_LOC_GOSSIP_BARBARIAN_INVASION_STARTED", 1),
    ("CQUI_LOC_GOSSIP_BARBARIAN_RAID_STARTED", 1),
    ("CQUI_LOC_GOSSIP_BEACH_RESORT_CREATED", 0),
    ("CQUI_LOC_GOSSIP_CHANGE_GOVERNMENT", 1),
    ("CQUI_LOC_GOSSIP_CITY_BESIEGED", 1),
    ("CQUI_LOC_GOSSIP_CITY_LIBERATED", 1),
    ("CQUI_LOC_GOSSIP_CITY_RAZED", 1),
    ("CQUI_LOC_GOSSIP_CLEAR_CAMP", 0),
    ("CQUI_LOC_GOSSIP_CITY_STATE_INFLUENCE", 1),
    ("CQUI_LOC_GOSSIP_CONQUER_CITY", 1),
    ("CQUI_LOC_GOSSIP_CONSTRUCT_DISTRICT", 1),
    ("CQUI_LOC_GOSSIP_CREATE_PANTHEON", 1),
    ("CQUI_LOC_GOSSIP_CULTURVATE_CIVIC", 1), --Civic researched
    ("CQUI_LOC_GOSSIP_DECLARED_FRIENDSHIP", 1),
    ("CQUI_LOC_GOSSIP_DELEGATION", 0),
    ("CQUI_LOC_GOSSIP_DENOUNCED", 1),
    ("CQUI_LOC_GOSSIP_EMBASSY", 0),
    ("CQUI_LOC_GOSSIP_ERA_CHANGED", 1),
    ("CQUI_LOC_GOSSIP_FIND_NATURAL_WONDER", 0),
    ("CQUI_LOC_GOSSIP_FOUND_CITY", 1),
    ("CQUI_LOC_GOSSIP_FOUND_RELIGION", 1),
    ("CQUI_LOC_GOSSIP_GREATPERSON_CREATED", 1),
    ("CQUI_LOC_GOSSIP_LAUNCHING_ATTACK", 1),
    ("CQUI_LOC_GOSSIP_WAR_PREPARATION", 1),
    ("CQUI_LOC_GOSSIP_INQUISITION_LAUNCHED", 0),
    ("CQUI_LOC_GOSSIP_LAND_UNIT_LEVEL", 0),
    ("CQUI_LOC_GOSSIP_MAKE_DOW", 1),
    ("CQUI_LOC_GOSSIP_NATIONAL_PARK_CREATED", 0),
    ("CQUI_LOC_GOSSIP_NEW_RELIGIOUS_MAJORITY", 1),
    ("CQUI_LOC_GOSSIP_PILLAGE", 0),
    ("CQUI_LOC_GOSSIP_POLICY_ENACTED", 1),
    ("CQUI_LOC_GOSSIP_RECEIVE_DOW", 1),
    ("CQUI_LOC_GOSSIP_RELIC_RECEIVED", 0),
    ("CQUI_LOC_GOSSIP_RESEARCH_AGREEMENT", 0),
    ("CQUI_LOC_GOSSIP_RESEARCH_TECH", 1),
    ("CQUI_LOC_GOSSIP_SPY_DISRUPT_ROCKETRY_DETECTED", 1),
    ("CQUI_LOC_GOSSIP_SPY_DISRUPT_ROCKETRY_UNDETECTED", 1),
    ("CQUI_LOC_GOSSIP_SPY_GREAT_WORK_HEIST_DETECTED", 0),
    ("CQUI_LOC_GOSSIP_SPY_GREAT_WORK_HEIST_UNDETECTED", 0),
    ("CQUI_LOC_GOSSIP_SPY_RECRUIT_PARTISANS_DETECTED", 1),
    ("CQUI_LOC_GOSSIP_SPY_RECRUIT_PARTISANS_UNDETECTED", 1),
    ("CQUI_LOC_GOSSIP_SPY_SABOTAGE_PRODUCTION_DETECTED", 1),
    ("CQUI_LOC_GOSSIP_SPY_SABOTAGE_PRODUCTION_UNDETECTED", 1),
    ("CQUI_LOC_GOSSIP_SPY_SIPHON_FUNDS_DETECTED", 1),
    ("CQUI_LOC_GOSSIP_SPY_SIPHON_FUNDS_UNDETECTED", 1),
    ("CQUI_LOC_GOSSIP_SPY_STEAL_TECH_BOOST_DETECTED", 1),
    ("CQUI_LOC_GOSSIP_SPY_STEAL_TECH_BOOST_UNDETECTED", 1),
    ("CQUI_LOC_GOSSIP_TRADE_DEAL", 0),
    ("CQUI_LOC_GOSSIP_TRADE_RENEGE", 0),
    ("CQUI_LOC_GOSSIP_TRAIN_SETTLER", 1),
    ("CQUI_LOC_GOSSIP_TRAIN_UNIT", 1),
    ("CQUI_LOC_GOSSIP_TRAIN_UNIQUE_UNIT", 1),
    ("CQUI_LOC_GOSSIP_PROJECT_STARTED", 0),
    ("CQUI_LOC_GOSSIP_START_VICTORY_STRATEGY", 1),
    ("CQUI_LOC_GOSSIP_STOP_VICTORY_STRATEGY", 1),
    ("CQUI_LOC_GOSSIP_WMD_BUILT", 1),
    ("CQUI_LOC_GOSSIP_WMD_STRIKE", 1),
    ("CQUI_LOC_GOSSIP_WONDER_STARTED", 1);