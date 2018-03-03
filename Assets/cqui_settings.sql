/*
    ╔════════════════════════════════════════════════════════════════════════════════════════════╗
    ║                                   CQUI Default settings                                    ║
    ╠════════════════════════════════════════════════════════════════════════════════════════════╣
    ║ Created by LordYanaek for CQUI mod by chaorace.                                            ║
    ║ These are the settings loaded by DEFAULT in CQUI.                                          ║
    ║                                                                                            ║
    ║ !!! Attention: Don't write your custom settings in the original copy of this file !!!      ║
    ║                                                                                            ║
    ║ This file is where all default settings are stored, all changes to this file are lost      ║
    ║ whenever updating to a new CQUI version (particularly if using the Steam Workshop version).║
    ║                                                                                            ║
    ║ To change default settings permanently without the risk of losing them, create a           ║
    ║ copy of this file named "cqui_settings_local.sql" and make your changes there.             ║
    ║ The "cqui_settings_local.sql" file does not need to be a perfect copy and will work as     ║
    ║ long as it's valid SQL.                                                                    ║
    ║                                                                                            ║
    ║ If you discover a broken setting, please report it at the below URL:                       ║
    ║                     https://github.com/CQUI-Org/cqui/issues                                ║
    ╚════════════════════════════════════════════════════════════════════════════════════════════╝
*/


/*
    ┌────────────────────────────────────────────────────────────────────────────────────────────┐
    │                                    Checkbox settings                                       │
    ├────────────────────────────────────────────────────────────────────────────────────────────┤
    │These settings control the default state of the CQUI configuration checkboxes.              │
    │Valid values are 0 (disabled) or 1 (enabled). Don't change the names or the first line!     │
    └────────────────────────────────────────────────────────────────────────────────────────────┘
*/

INSERT OR REPLACE INTO CQUI_Settings -- Don't touch this line!
  VALUES  ("CQUI_AlwaysOpenTechTrees", 0), -- Always opens the full tech trees instead of the civic/research picker panels
      ("CQUI_AutoapplyArchaeologistLens", 1), -- Automatically activates the archaeologist lens when selecting a archaeologist
      ("CQUI_AutoapplyBuilderLens", 1), -- Automatically activates the builder lens when selecting a builder
      ("CQUI_AutoapplyScoutLens", 1), -- Automatically activates the scout lens when selecting a scout
      ("CQUI_ShowNothingToDoBuilderLens", 1), -- Shows nothing to do hexes (red tiles) when in builder lens
      ("CQUI_ShowGenericBuilderLens", 1), -- Shows generic hexes (white tiles) when in builder lens
      ("CQUI_AutoExpandUnitActions", 1), -- Automatically reveals the secondary unit actions normally hidden inside an expando
      ("CQUI_BlockOnCityAttack", 1), -- Block turn from ending if you have a city that can attack
      ("CQUI_ProductionQueue", 1), -- A production queue appears next to the production panel, allowing multiple constructions to be queued at once
      ("CQUI_ShowCultureGrowth", 1), -- Shows cultural growth overlay in cityview
      ("CQUI_ShowPolicyReminder", 1),
	  ("CQUI_ShowLuxuries", 1), -- Luxury resources will show in the top-bar next to strategic resources
      ("CQUI_ShowUnitPaths", 1), -- Shows unit paths on hover and selection
      ("CQUI_ShowYieldsOnCityHover", 1), -- Shows city management info like citizens, tile yields, and tile growth on hover
      ("CQUI_Smartbanner", 1), -- Additional informations such as districts will show in the city banner
      ("CQUI_Smartbanner_UnlockedCitizen", 0), -- Shows if city have Unmanaged citizens in the banner
      ("CQUI_Smartbanner_Districts", 1), -- Shows city districts in the banner
      ("CQUI_Smartbanner_Population", 1), -- Shows turns to city population growth in the banner
      ("CQUI_Smartbanner_Cultural", 1), -- Shows turns to city cultural growth in the banner
      ("CQUI_SmartWorkIcon", 1), -- Applies a different size/transparency to citizen icons if they're currently being worked
      ("CQUI_TechPopupVisual", 0), -- Popups will be displayed when you discover a new tech or civic (this is the normal behavior for the unmoded game)
      ("CQUI_TechPopupAudio", 1), -- Play the voiceovers when you discover a new tech or civic (this is the normal behavior for the unmoded game)
      ("CQUI_WonderBuiltPopupVisual", 1), -- Wonder movies will be displayed when you complete a wonder (this is the normal behavior for the unmoded game)
      ("CQUI_WonderBuiltPopupAudio", 1), -- Wonder quote audio will be played when you complete a wonder (this is the normal behavior for the unmoded game)
      ("CQUI_ToggleYieldsOnLoad", 1), -- Toggles yields immediately on load
      ('CQUI_ShowCitizenIconsOnCityHover', 0), -- Shows citizen icons when hovering over city banner
      ('CQUI_ShowCityManageAreaOnCityHover', 1), -- Shows citizen management area when hovering over city banner
      ('CQUI_ShowCityMangeAreaInScreen', 1), -- Shows citizen management area when in city screen
      ('CQUI_TraderAddDivider', 1), -- Adds a divider between groups in TradeOverview panel
      ('CQUI_TraderShowSortOrder', 0), -- Adds a divider between groups in TradeOverview panel
      ('CQUI_ShowProductionRecommendations', 0), -- Shows the advisor recommendation in the city produciton panel
      ('CQUI_ShowTechCivicRecommendations', 1), -- Shows the advisor recommendation in the techs/civics tree/panel
      ('CQUI_ShowImprovementsRecommendations', 0), -- Shows the advisor recommendation for the builder improvements
      ('CQUI_ShowCityDetailAdvisor', 0), -- Shows the advisor recommendation in the city detail panel
      ('CQUI_ShowDiploBanner', 1), -- Shows the Diplomacy Banner
      ('CQUI_ShowDebugPrint', 0); -- Shows print in the console
/*
    ┌────────────────────────────────────────────────────────────────────────────────────────────┐
    │                                    Combobox settings                                       │
    ├────────────────────────────────────────────────────────────────────────────────────────────┤
    │These settings control the default state of the CQUI configuration comboboxes.              │
    │Different values can be used depending on individual settings.                              │
    │Don't change the names of the settings or the first line!                                   │
    └────────────────────────────────────────────────────────────────────────────────────────────┘
*/

INSERT OR REPLACE INTO CQUI_Settings -- Don't touch this line!
  VALUES  ("CQUI_BindingsMode", 2), -- Set of keybindings used │ 0=Civ6 default │ 1=keybinds from Civ5 │ 2=Civ5 with additions such as WASD camera control |
      ("CQUI_ResourceDimmingStyle", 1); -- Affects the way resource icons look when they have been improved  | 0=No Change | 1=Transparent | 2=Hidden |

/*
    ┌────────────────────────────────────────────────────────────────────────────────────────────┐
    │                                    Slider settings                                         │
    ├────────────────────────────────────────────────────────────────────────────────────────────┤
    │These settings control the default value of the CQUI configuration sliders.                 │
    │Different values can be used depending on individual settings.                              │
    │Don't change the names of the settings or the first line!                                   │
    └────────────────────────────────────────────────────────────────────────────────────────────┘
*/

INSERT OR REPLACE INTO CQUI_Settings -- Don't touch this line!
  VALUES  ("CQUI_ProductionItemHeight", 32), -- Height used for individual items in the production queue. Recommended values fall between 24 and 128, though any positive could work
  ("CQUI_SmartWorkIconSize", 64), -- Size used for "smart" work icons. This size is applied to work icons that are currently locked if the smart work icon option is enabled. Recommended values fall between 48 and 128, though any positive multiple of 8 could work (non-multiples are rounded down)
  ("CQUI_SmartWorkIconAlpha", 40), -- Transparency percent used for "smart" work icons. This alpha is applied to work icons that are currently locked if the smart work icon option is enabled. Recommended values fall between 10 and 100, though any value between 0 and 100 could work
  ("CQUI_WorkIconSize", 64), -- Size used for work icons. Applies to all icons that aren't flagged using the "smart" work icon feature. Recommended values fall between 48 and 128, though any positive multiple of 8 could work (non-multiples are rounded down)
  ("CQUI_WorkIconAlpha", 80); -- Size used for work icons. Applies to all icons that aren't flagged using the "smart" work icon feature. Recommended values fall between 10 and 100, though any value between 0 and 100 could work

/*
    ┌────────────────────────────────────────────────────────────────────────────────────────────┐
    │                                    Gossip settings                                         │
    ├────────────────────────────────────────────────────────────────────────────────────────────┤
    │These settings control the default state of the Gossip message checkboxes                   │
    │Valid values are 0 (disabled) or 1 (enabled). Don't change the names or the first line!     │
    └────────────────────────────────────────────────────────────────────────────────────────────┘
*/

INSERT OR REPLACE INTO CQUI_Settings -- Don't touch this line!
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
