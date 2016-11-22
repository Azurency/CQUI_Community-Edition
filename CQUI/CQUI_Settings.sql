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
      ("CQUI_TechPopupAudio", 1); -- Play the voiceovers when you discover a new tech or civic (this is the normal behavior for the unmoded game)
      
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
