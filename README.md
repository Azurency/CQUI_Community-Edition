# Community Quick User Interface (CQUI)
> CQUI is an open source Civilization 6 mod that is maintened by it's community

CQUI is an UI mod that helps you manage your empire faster and easier. It's an enhancement of the original UI that gives you the informations you need with less clicks. It also have a lot of usefull functionnality that makes the game even better.

This repository is the official repository of the [CQUI steam mod](http://steamcommunity.com/sharedfiles/filedetails/?id=1125169247).

![cquiscreens](https://user-images.githubusercontent.com/8012430/31862026-75c5822e-b737-11e7-9ac3-afe993e26eb6.jpg)

## Installation

_**Note for Mac/Linux users :** as the latest patch is still not avaible to your platform, please follow the manual installation steps with this version of CQUI : https://github.com/Azurency/CQUI_Community-Edition/releases/tag/mac-1.0.0.220_

### Steam Workshop
If you want to install the latest official version, you can go to the [steam workshop page](http://steamcommunity.com/sharedfiles/filedetails/?id=1125169247) of CQUI and add it to your game.

### Manually
If you want to have the cutting edge version (that might not be push on steam workshop) you can download this repository and place the cqui folder into your mod folder : 

```
Windows : Documents\my games\Sid Meier's Civilization VI\Mods
Mac : /Users/[user]/Library/Application Support/Sid Meier's Civilization VI
Linux : ~/.local/share/aspyr-media/Sid Meier's Civilization VI/Mods
```

## Key Features

- Civ V Style Cityview _- [image](https://camo.githubusercontent.com/e39306c882c0f9b95494ea391cee0baa838d3072/687474703a2f2f692e696d6775722e636f6d2f583571427a6a612e6a7067)_
  - Production panel elements compressed and reordered _- [image](http://i.imgur.com/DpZ0kcn.png)_
- Great Person panel revamped _- [image](https://user-images.githubusercontent.com/8012430/31862025-75a4cb88-b737-11e7-9b0f-57129f114f59.jpg)_
  - No more side scrolling
  - Adapts to the screen height
- Policy Reminder Popup _- [image](https://user-images.githubusercontent.com/8012430/31861779-17cd1758-b733-11e7-8b16-b4422999c8af.png)_
- Improved amenities city details screen (Clean Icons) _- [image](http://i.imgur.com/UA1NrR5.png)_
- "My Government" tab removed from Government panel _- [image](http://i.imgur.com/168ThOx.jpg)_
- Diplomatic banner shows the scores of the civilizations _- [image](https://user-images.githubusercontent.com/8012430/31861834-15a1db7a-b734-11e7-91dc-22daaa09653b.png)_
- Leaderheads expanded tooltips _- [image](https://user-images.githubusercontent.com/8012430/31861835-17537960-b734-11e7-8ae4-08e7e3f19cc4.png)_
- Map Pinning system enhanced _- [image](http://i.imgur.com/M11tac6.png)_
  - New pins
  - Long pinlists are now scrollable
  - Right click in pinlist to quickly delete pins
  - Enter key now bound to finalizing a pin in pin creation menu
- Tech/Civic Tree and Civilopedia now autofocus the searchbar
- Civilopedia remembers the last visited page
- Dedicated mod settings menu _- [image](https://user-images.githubusercontent.com/8012430/31861832-13bb16d2-b734-11e7-9524-b7292881f7af.png)_
  - Civic/Tech popups can be disabled. Optionally, the voiceover can still be kept even without the popup.
  - Recommandation UI can be enabled/disabled
  - Minimap size can be changed
- Civic/Tech notifications spawned at 50%/100% research progress
- Citizen management icons are overhauled to make seeing yield info easier _-[ image](http://i.imgur.com/gbA4z3s.png)_
- Growth/Production progress is enumerated in the city panel _- [image](http://i.imgur.com/3kYsEIf.png)_
- Improved resource icons are dimmed to emphasize unutilized resources _- [image](http://i.imgur.com/m32xtQr.png)_
- Civ V keybinding options
  - Classic, a faithful recreation of the Civ V binding scheme
  - Enhanced, Civ V binding scheme with WASD assigned to camera control, Q/E assigned to city/unit cycling, and Shift assigned to shifting focus between city and unit selection modes
- Unit actions like sell/delete are no longer hidden behind an expando _- [image](http://i.imgur.com/x1xZtyY.png)_
- Unit XP bars are twice as tall _- [image](http://i.imgur.com/TeWR0VA.png)_
- Growth/Amenities/Bordergrowth info baked into city banners _- [image](http://i.imgur.com/8CUJSB6.png)_
- "Smart Banner" Toggleable option to display a green icon indicating non-locked citizens and district icons indicating built districts _- [image](http://i.imgur.com/XLVP92n.png)_
- Luxury resources are displayed in the top bar alongside strategic resources _-[ image](http://i.imgur.com/ebYO8l4.png)_
- Right clicking the action panel (bottom right button) instantly ends turn even when things like production/research/unit moves have not been decided

## Integrations

Over the time, some other UI mods were integrated into CQUI.

### Improved Deal Screen
Mod by mironos, from the [steam workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=884220740). It's a totally revamped diplomatic deals screen, with an improved and expanded layout, easier to read and navigate offer area, color-coded icons, and more in-depth information.

![improveddealscreen](https://user-images.githubusercontent.com/8012430/31861685-d060611e-b731-11e7-99ae-e79072d0aa83.jpg)

- All resources a civilization has access to are now listed, including those acquired via trade with other civs and those imported from city states, to avoid trading for resources you already have
- Resource icons have been color-coded and custom sorted _- [image](https://i.imgur.com/PytRc3E.jpg)_
  - Resources you have direct access to are sorted by decreasing quantity
  - Resources you only have 1 of are considered scarce, and are given a red font
  - Resources that both you and your trading partner already have are color-coded with a tan button
  - Resources that you own but that can't be traded (typically, those that are imported from elsewhere) are listed for reference, but cannot be selected
- Cities are now sorted alphabetically
- City details are displayed right on the city buttons for easy reference _- [image](https://i.imgur.com/mSiRY2w.jpg)_
- Additional city information has been added the city tooltips
- When negotiating peace treaties, currently occupied cities are highlighted and sorted to the top
- Great works buttons include a 'type' icon
- All great works with a creator now display that creator
- Artifacts include civ icons so you can tell at a glance what nation or city state the artifact originated from. It also the displays artifact's era.

### Better Trade Screen
Mod by [astog](https://github.com/astog), you can find it [on github](https://github.com/astog/BTS). The goal of this mod is to improve the trade screens in Civilization VI and help manage and monitor running trade routes.

![](http://i.imgur.com/8DXfZx3.png)

- Shows turns to complete a trade route rather than the distance between the cities
- Overhauled Trade Overview screen _- [image](http://i.imgur.com/0IMseO1.png)_
  - Shows all possible routes, even if the trader is not present in the origin city
  - Clicking on a route where a free trade unit is not present in the origin city takes you to a free trade unit and opens the Change City screen
  - Route entry is colored based on destination player
  - Player/City header are also colored
  - Shows origin city and destination city yields in the same screen
  - Added Group and Filter settings
  - My Routes tab tracks active routes, so you know when a trade route completes
- Sort bar in Make Trade Route screen and Trade Overview screen. Sort the routes by left clicking on a button _- [image](http://i.imgur.com/F7ZRUi7.png)_
- Trade Routes can be sorted based on yields, and turns remaining. Queue multiple sorts by holding SHIFT and the left clicking on a sort button. Right click on any sort button to remove it from the sort setting
- When opening Make Trade Route screen, the last destination is automatically picked
- Set a trader to repeat its last route by selecting the Repeat Route checkbox when initiating a trade route
- An additional checkbox is provided that sets the trader to repeat the top route from the sort settings when the trade was initiated. This allows the trade route to always be the best one, hence reducing micromanagent of always checking the trade routes
- Cancel the automated trader from the My Routes tab in Trade Overview screen

### More Lenses
Mod by [astog](https://github.com/astog), you can find it [on github](https://github.com/astog/MoreLenses). The goal of this mod is to add more lenses to the game, that help with empire management and in general quality of life improvements.

![morelenses](https://user-images.githubusercontent.com/8012430/31861684-d04142de-b731-11e7-97c7-6e8359d47f96.jpg)

- Add a Builder Lens to highlight unimproved resources, hills and removable features. This lens auto applies when a builder is selected (can be toggled in the settings)
- Add an Archaeologist Lens to highlight artifacts and shipwrecks.
- Add a City Overlap 6 or 9 to show how many cities a particular hex overlaps with
- Add a Barbarian Lens to highlight barbarian encampments on the map
- Add a Resource Lens to highlight resources on the map based on their category (Bonus vs Strategic vs Luxury) and if they are connected or not
- Add a Wonder Lens to highlights natural and player made wonders
- Add an Adjacency Yield Lens to show the various adjacency bonuses in a gradient, allowing you to relish in your pristine city planning skills
- Add a Scout Lens to highlight goody huts on the map. Automatically applies when a scout/ranger is selected (can be toggled in the settings)

### Better Espionnage Screen
Mod by [astog](https://github.com/astog), you can find it [on github](https://github.com/astog/BES). The Espionage Screens are overhauled to reduce the number of clicks and find the right information quickly.

![](https://camo.githubusercontent.com/763167a1fb61481c0e9a60888d30687f51c3e919/687474703a2f2f692e696d6775722e636f6d2f705435617352652e6a7067)

- Disctrict Filter Options
  - Allows you to filter the cities based on their districts
  - You can also filter based on civilizations
- Mission list is shown as a side screen, rather than replacing the destination list

### Production Queue
Mod by [kblease](https://github.com/kblease), you can find it [on github](https://github.com/kblease/ProductionQueue). It adds production queuing to Civ 6.

![productionqueue](https://user-images.githubusercontent.com/8012430/31861663-7fbc2400-b731-11e7-9a64-fca8e3ef8cfd.jpg)

- Add a production queue to the cityview (can be toggled in the seetings)
- The production queue can be reordered
- Units in a city's queue which become obsolete will be automatically switched to the unit that is replacing it

### Unit Report Screen
Mod by [GMiller7138](https://forums.civfanatics.com/members/gmiller7138.201859/), you can find it [on civfanatics](https://forums.civfanatics.com/resources/unit-report-screen.25396/). This mod enhances the Report Screen.

![reportscreen](https://user-images.githubusercontent.com/8012430/31861662-7f99b9ba-b731-11e7-88de-c24aa4c28b4e.jpg)

- Unit Tab
  - Breaks down all of your units into groups such as Military (separated by Land/Sea/Air), Civilian and Support, Traders, Spies, and Great People
  - Unit stats are listed based on which group they are allocated to. For instance, military units will show Health and Movement, while civilian units will show how many charges they have left
  - You can select and zoom to any unit on the list
  - Promote/upgrade military units without exiting screen
  - Sort units by clicking on header of each stat
- Yields Tab
  - Added a "Hide City Buildings" checkbox which hides building yields in order to better compare yields between cities
  - Sorted Yields. Clicking the header in City Income will allow you to sort by descending/ascending order
  - Building Expenses displays district maintenance costs. These are combined for each city and labeled as "Districts"
  - Units Expenses added. Units are grouped and will show total cost per type. Policies that reduce unit maintenance costs are taken into account
- City Status
  - Sorted Fields
- Current Deals
  - Displays current deals you have with other civilizations. Includes duration, what is being traded, etc.

### Divine Yuri's Custom City Panel
Mod by [Divine Yuri](https://forums.civfanatics.com/members/divine-yuri.263736/), you can find it [on civfanatics](https://forums.civfanatics.com/resources/divine-yuris-custom-city-panel.25430/). The mod add  additional tooltips to the city panel.

![Amenities tooltip](http://i.imgur.com/qHjdmUG.png)

- Hover over the new "Districts" bar show the built districts in the city, and the buildings in each district. As well as telling you when a building or district is pillaged _- [image](http://i.imgur.com/DqwAySq.png)_
- The tool tip for the religions bar shows how many citizens follow each religion, your pantheon belief, and benefits of the dominant religion in the city _- [image](http://i.imgur.com/Vo8ZVGr.png)_
- The tool tip for the Amenities bar shows the current mood of the city the benefit/hindrance of that mood, and the breakdown of what's causing the lost/gains of Amenities
- Hovering over Housing will give the current food modifier from housing _- [image](http://i.imgur.com/h5R3Dhh.png)_
- Added food lost from population, and modifiers to the food tool tip _- [image](http://i.imgur.com/ZGwznFv.png)_
- The production bar on the city panel has been changed to show total production on the right side of the bar
- The Growth bar has been shortened to make room
- Added a Expansion Bar which will show how long until the city expands it's boarders
- Expansion Bar that show total Food and Culture
- Added tooltips to the Growth Bar
- Added info to current production in the form of a tooltip in the same way a tooltip would be displayed in the production panel
- Right clicking the current production icon will links to the civilopedia of what ever's being produced

### Simplified Gossip
Mod by FinalFreak16, from the [steam workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=1126451168). This mod simplifies the gossip history log in the leader diplomacy view.

![gossip](https://user-images.githubusercontent.com/8012430/31861664-7fe2bf8e-b731-11e7-9eae-2ea138b53007.jpg)

- Each message has its own icon to categorise each entry and make it easier to see what happened at a glance

## What's next
This section should not always be up to date, so don't hesitate to check the milestones and the issues.

- [ ] Add custom notification on a new (or revamped) notification system _- [here](https://github.com/Azurency/CQUI_Community-Edition/issues/104)_
- [ ] Finish the beta milestone release _- [here](https://github.com/Azurency/CQUI_Community-Edition/milestone/1)_
- [ ] Plan the next milestone from the multiple enhancement ideas in the issues

## Contributing
> This part still need some love

You want to contribute to the mod ? We're always welcoming new contributors and the pull request are open if you wish to tacle an issue. Some issues are labeled "easy" it should be a great entry point if you want to join the team. A comprehensive [contribution guide](https://github.com/CQUI-Org/cqui/wiki/How-to-contribute-to-CQUI) created for the predecessor of this mod is a good starting point.

### Quick coding style
- Please use 2 spaces for indentation
- When modifying existing game files, prefix newly added functions, events, and members with "CQUI_"
- When commenting, it's a good practice to add your username at the beginning of the comment to know who modified this part of the code
- There should be NO hardcoded strings in CQUI

### Quick git guideline
- When your commit includes a bugfix or implements a feature that's tracked on the issue tracker, include the phrase "Fixes #X" or "Resolves #X", where X is the tracker number of the issue or feature. This will notify everyone participating in the issue of your change when you push it to your fork, as well as automatically close the issue when the change is merged into the main repo.


## Credits
@Vans163 for his original QUI mod, @Chaorace for the Chao's QUI, @Sparrow for this reborn as a Community QUI, @astog, Aristos/@ricanuck, @JHCD, Greg Miller, Ace, Divine Yuri, @ZhouYzzz, @deggesim, @e1ectron, @sejbr, @frytom, @maxap, @lctrs, @wbqd, @jacks0nX, @RatchetJ, @Frozen-In-Ice, @zgavin, @olegbl, @Proustldee, @kblease, @bolbass, @SpaceOgre, @OfekA, @zeyangl, @Remolten, @bestekov, @cpinter, @paavohuhtala, @perseghini, @benjaminjackman, @velit, @the-m4a, @MarkusKV, @apskim, @8h42

Firaxis for eventually delivering mod tools and steam workshop. 

The lovely folks over at Civfanatics for their guides, knowledge, tools, and resources. 

The even lovelier folks over at /r/civ for their input and testing. 

The, arguably, lovely folks back at the Steam Workshop :p
