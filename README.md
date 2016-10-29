# Civilization 6 - Chao's Quick UI

### CQUI Features:

(New in this release)
* Civ V Style Cityview ![](http://i.imgur.com/NpyJjVr.jpg)
* Great Person panel renovated (no more scrolling!) ![](http://i.imgur.com/FeRTxyh.jpg)
* "My Government" tab removed from Government panel ![](http://i.imgur.com/168ThOx.jpg)
* Tech/Civic Tree and Civilopedia now autofocus the searchbar on open ![](http://i.imgur.com/tPzNnv4.png)
* Minimap is now 2x larger ![](http://i.imgur.com/AyY8HeP.jpg)
* [Minimap expando is easier to click. Minimap now also rolls up when right clicked](https://gfycat.com/ElementaryRectangularGalago)
* Unit actions like sell/delete are no longer hidden behind an expando ![](http://i.imgur.com/x1xZtyY.png)
* Unit XP bars are twice as tall ![](http://i.imgur.com/TeWR0VA.png)
* Tile tooltips spawn nearly instantly

### QUI Features:

(Newly inherited upstream from https://github.com/vans163/civ6_qui)
* Growth/Amenities/Bordergrowth  info baked into city banners ![](http://i.imgur.com/8CUJSB6.png)
* "Smart Banner" Toggleable option to display a green icon indicating non-locked citizens, district icons indicating built districts, and lettered icons representing unbuilt buildings ![](http://i.imgur.com/FEdJQ61.png)
* Luxury resources are displayed in the top bar alongside strategic resources ![](http://i.imgur.com/ebYO8l4.png)
* Food/Hammer progress is numerated in city panel ![](http://i.imgur.com/utZzpqJ.png)
* Additional options in the map options panel ![](http://i.imgur.com/V94t5a9.png)
* "Cowboy" Toggleable option to auto-create Horsemen units whenever production finishes
* "Bad Cowboy" Toggleable option to sell auto-created horsemen automatically
* [Right clicking the action panel (bottom right button) instantly ends turn](https://gfycat.com/PeacefulSpanishAfricanwildcat) even when things like production/research/unit moves have not been decided
* Civic/Tech popups/voiceover are skipped immediately
* Production recommendations removed

### How to use
Download the latest release from
https://github.com/chaorace/cqui/releases/

Find your DLC folder, usually on Windows it is:  
```
C:\Program Files (x86)\Steam\steamapps\common\Sid Meier's Civilization VI\DLC
```

Extract the "cqui" folder to the DLC folder

### KNOWN ISSUES:

* Attacking with cities takes two clicks on the strike button. (This is actually a bug in Civ VI)
* Minimap is too large in large UI mode and GP view is broken 
* None other thus-far!

### TODO:

* Show district adjacency bonuses in cityview or potentially globally
* Buttons for cycling cities in cityview
* Tweaking the minimap further (making it smaller or adding a smallmode?)
* Making the yields in the top panel clickable
* Right clicking ANY item in production view opens Civilopedia (currently doesn't work for disabled buildings/units)
* Hotkeys for things like: Fortify until Heal, Cycle units, etc.
* Change right clicking minimap to toggling the minimap size between small (original size) and large (current)
* Right clicking most UI elements to dismiss them, similar to how ESC behaves (diplo dialog, pop-ups, etc.)
* Condensing the City Details screen and removing tutorial elements from it
* Unit dots, fog of war colors, and other minimap options? (not sure how easy this one will be)
* Adding tooltips to the smart banner letter icons
* Adding settings for existing features (future features too!):
  1. Adding toggle for tech/civiv popup and narration (one toggle for each)
  2. Minimap tweaks
  
### THANKS:
* [Vans163](https://github.com/vans163) for his QUI mod and the active commits he makes that I love to merge <3
* [zgavin](https://github.com/zgavin) for his UI bugfixes in PRs #1/#2
* The lovely folks over at Civfanatics for their guides, knowledge, tools, and resources
* The even lovelier folks over at /r/civ for their input and testing
