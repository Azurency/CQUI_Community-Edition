
[![](https://img.shields.io/gitter/room/nwjs/nw.js.svg)](https://gitter.im/Civ6-CQUI/Help)
[![Twitter URL](https://img.shields.io/twitter/url/http/shields.io.svg?style=social)](https://twitter.com/realchaorace)

# Civilization 6 - Chao's Quick UI

# Features:

### CQUI Features:

* Civ V Style Cityview

![](http://i.imgur.com/c9mtii6.jpg)

* Great Person panel renovated (no more scrolling!)

![](http://i.imgur.com/FeRTxyh.jpg)

* Improved amenities city details screen (Clean Icons! No Tutorial UI!)

![](http://i.imgur.com/UA1NrR5.png)

* "My Government" tab removed from Government panel

![](http://i.imgur.com/168ThOx.jpg)

* Map Pinning system enhanced: new pins, long pinlists are now scrollable, right click in pinlist to quickly delete pins, enter key now bound to finalizing a pin in pin creation menu.

![](http://i.imgur.com/IThYZcg.png)

* Tech/Civic Tree and Civilopedia now autofocus the searchbar
* Civilopedia remembers the last visited page
* Civic/Tech popups can be disabled. Optionally, the voiceover can still be kept even without the popup.

* Minimap can be toggled between 2x-Mode and original by rightclicking

![](http://i.imgur.com/AyY8HeP.jpg)

* Dedicated mod settings menu

![](http://i.imgur.com/0WFq7EL.png)

* [Minimap expando is easier to click. Minimap now also rolls up when right clicked](https://gfycat.com/ElementaryRectangularGalago)
* Unit actions like sell/delete are no longer hidden behind an expando

* Civ V keybinds implemented. Two modes: Classic, a faithful recreation of the Civ V binding scheme. Enhanced,  Civ V binding scheme with WASD assigned to camera control, Q/E assigned to city/unit cycling, and Shift assigned to shifting focus between city and unit selection modes.

![](http://i.imgur.com/x1xZtyY.png)

* Unit XP bars are twice as tall

![](http://i.imgur.com/TeWR0VA.png)

* Tile tooltips spawn nearly instantly

### QUI Features:

* Growth/Amenities/Bordergrowth info baked into city banners

![](http://i.imgur.com/8CUJSB6.png)

* "Smart Banner" Toggleable option to display a green icon indicating non-locked citizens and district icons indicating built districts.

![](http://i.imgur.com/FEdJQ61.png)

* Luxury resources are displayed in the top bar alongside strategic resources

![](http://i.imgur.com/ebYO8l4.png)

* Food/Hammer progress is numerated in city panel

![](http://i.imgur.com/utZzpqJ.png)

* [Right clicking the action panel (bottom right button) instantly ends turn](https://gfycat.com/PeacefulSpanishAfricanwildcat) even when things like production/research/unit moves have not been decided
* Production/Worker recommendations removed

### Better Trade Screen Features:

* Overhauled trade menus

![](http://i.imgur.com/0IMseO1.png)![](http://i.imgur.com/F7ZRUi7.png)

* New yield/destination filtering options

![](http://i.imgur.com/8DXfZx3.png)

* Remembers the last used tab
* Available Routes shows all possible routes, even if the trade unit is not present in the origin city
* Clicking on a route where a free trade unit is not present in the origin city takes you to a free trade unit and opens the change city tab
* City States with Trade Quest have an icon showing they have that quest
* Tourism and Visibility bonus is now on each trade route

### Next City Plot Features:

* Shows target and timing of next cultural border growth

![](http://i.imgur.com/PUwoxz3.png)

# How to use
* Download the latest release from
https://github.com/chaorace/cqui/releases/

* Find your DLC folder:

  Windows:
```
C:\Program Files (x86)\Steam\steamapps\common\Sid Meier's Civilization VI\DLC
```
  OSX:
```
Library/Application Support/Steam/steamapps/common/Civilization VI
```
  ... and then right click, "Show Package Contents", then navigate to...
```
Contents/Assets/DLC
```

* Extract the "cqui" folder to the DLC folder

* In-Game: Enable the mod in the "Additional Content" menu

* Start a new game (existing games cannot have new mods added to them!)

* Visit https://github.com/chaorace/cqui occasionally or follow https://twitter.com/realchaorace to be the first to know about new releases and feature additions!

* NOTE: Until this mod is in a less experimental state, the mod will not remember its "enabled" status after restarting the game. This means that every time you plan to start a new game using CQUI, you'll need to explicitly enable it in the "Additional Content" menu first. Once you've created the game using the mod, it will always load when you start the save, regardless of its current status in the "Additional Content Menu" 

### KNOWN ISSUES / SUPPORT:

Please see the [issue tracker](https://github.com/chaorace/cqui/issues) for an up to date list, you can also find help and report bugs at our [Gitter](https://gitter.im/Civ6-CQUI/Help)

# THANKS:
* @Vans163 for his QUI mod and the active commits he makes that I love to merge <3
* astog from the CivFanatics modding community for his [Better Trade Routes mod](http://forums.civfanatics.com/threads/better-trade-screen.602636/)
* Ace from the CivFanatics modding community for his [Next City Plot mod](http://forums.civfanatics.com/resources/next-city-plot-by-ace.25437/)
* @zgavin for UI bugfixes in PRs #1 and #2
* @olegbl for the Amenities overview overhaul in PR #4 and multiple UI bugfixes (PRs #9 and #12)
  1. Additional kudos to /u/mateusarc from the Civilization subreddit for his original concept art
* @jacks0nX for localization in #20 the map pin additions in PR #21 and UI/Civilopedia improvements in #24 and #32
* /u/dli511 @ Reddit for their bug report relating to purchasing buildings
* /u/Nitrium @ Reddit for their bug report relating to broken Gossip notifications
* /u/Hitesh0630 @ Reddit for their bug report relating to production queue not refreshing on changing citizen assignment
* The lovely folks over at Civfanatics for their guides, knowledge, tools, and resources
* The even lovelier folks over at /r/civ for their input and testing
