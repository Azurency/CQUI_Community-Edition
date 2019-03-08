-- Copyright 2016-2018, Firaxis Games

-- ===========================================================================
--  NOTES:
--  Each tech's "Index" is the internal ID the gamecore used to track the tech.
--  This value is essentially the database (db) row id minus 1 since it's 0 based.
--  (e.g., TECH_MINING has a db rowid of 3, so it's gamecore index is 2.)
--
--  ROWS:
--  Items exist in one of 8 "rows" that span horizontally.
--  Rows are defined via 'UITreeRow' attribute in XML
--
--  Row#  Start   Eras->                                . Next Era
--  -3             _____        _____          _____    .  _____      _____
--  -2          /-|_____|----/-|_____|------/-|_____|---.-|_____|-\--|_____|
--  -1          |  _____     |       Nodes  |           .         |
--   0     O----%-|_____|----'              |           .         |   _____
--   1          \---------------------------/           .         \--|_____|
--   2                                                  .
--   3                                                  .
--   4
--
--  COLUMNS:
--  Items are grouped by Eras and each Era can have a different rule as to
--  how nodes are laid out by changing the XML attribute 'TechTreeLayoutMethod'
--
--    TechTreeLayoutMethod values:
--    "Cost"   - (default) Nodes are grouped in columns by increasing cost.
--    "Prereq" - A tech's prerequists determine order of the nodes.
--
-- ===========================================================================
include( "ToolTipHelper" );
include( "SupportFunctions" );
include( "Civ6Common" );      -- Tutorial check support
include( "TechAndCivicSupport");  -- (Already includes Civ6Common and InstanceManager) PopulateUnlockablesForTech
include( "TechFilterFunctions" );
include( "ModalScreen_PlayerYieldsHelper" );
include( "GameCapabilities" );

-- ===========================================================================
--  DEBUG
--  Toggle these for temporary debugging help.
-- ===========================================================================
debugFilterEraMaxIndex  = -1;    -- (-1 default) Only load up to a specific ERA (Value less than 1 to disable)
debugFilterTechMaxIndex  = -1;    -- (-1 default) maximum index to fill the tree with, this is overriden by the debug explicit list.
debugOutputTechInfo    = false;  -- (false default) Send to console detailed information on tech?
debugShowIDWithName    = false;  -- (false default) Show the ID before the name in each node.
debugShowAllMarkers    = false;  -- (false default) Show all player markers in the timline; even if they haven't been met.
debugExplicitList    = {};    -- List of indexes to (only) explicitly show. e.g., {0,1,2,3,4} or {5,11,17}


-- ===========================================================================
--  GLOBALS
--  May be augmented or redefinied in a MOD's replacement file(s).
-- ===========================================================================
DATA_FIELD_LIVEDATA    = "_LIVEDATA";  -- The current status of an item.
DATA_FIELD_PLAYERINFO  = "_PLAYERINFO";-- Holds a table with summary information on that player.
DATA_FIELD_UIOPTIONS  = "_UIOPTIONS";  -- What options the player has selected for this screen.
DATA_ICON_PREFIX    = "ICON_";

PIC_BOLT_OFF      = "Controls_BoltOff";
PIC_BOLT_ON        = "Controls_BoltOn";
PIC_BOOST_OFF      = "BoostTech";
PIC_BOOST_ON      = "BoostTechOn";

PREREQ_ID_TREE_START  = "_TREESTART";  -- Made up, unique value, to mark a non-node tree start

PIC_DEFAULT_ERA_BACKGROUND  = "TechTree_BGAncient";
PIC_MARKER_PLAYER      = "Tree_TimePipPlayer";
PIC_MARKER_OTHER      = "Controls_TimePip";
PIC_METER_BACK        = "Tree_Meter_GearBack";
PIC_METER_BACK_DONE      = "TechTree_Meter_Done";

ITEM_STATUS        = {
              BLOCKED    = 1,
              READY    = 2,
              CURRENT    = 3,
              RESEARCHED  = 4,
              };
ROW_MAX          = 4;      -- Highest level row above 0
ROW_MIN          = -3;      -- Lowest level row below 0
SIZE_NODE_X        = 370;      -- Item node dimensions
SIZE_NODE_Y        = 84;
STATUS_ART        = {};      --
STATUS_ART[ITEM_STATUS.BLOCKED]    = { Name="BLOCKED",    TextColor0=0xff202726, TextColor1=0x00000000, FillTexture="TechTree_GearButtonTile_Disabled.dds",BGU=0,BGV=(SIZE_NODE_Y*3),  IsButton=false,  BoltOn=false,  IconBacking=PIC_METER_BACK };
STATUS_ART[ITEM_STATUS.READY]    = { Name="READY",    TextColor0=0xaaffffff, TextColor1=0x88000000, FillTexture=nil,                  BGU=0,BGV=0,        IsButton=true,  BoltOn=false,  IconBacking=PIC_METER_BACK  };
STATUS_ART[ITEM_STATUS.CURRENT]    = { Name="CURRENT",    TextColor0=0xaaffffff, TextColor1=0x88000000, FillTexture=nil,                  BGU=0,BGV=(SIZE_NODE_Y*4),  IsButton=false,  BoltOn=true,  IconBacking=PIC_METER_BACK };
STATUS_ART[ITEM_STATUS.RESEARCHED]  = { Name="RESEARCHED",  TextColor0=0xaaffffff, TextColor1=0x88000000, FillTexture="TechTree_GearButtonTile_Done.dds",  BGU=0,BGV=(SIZE_NODE_Y*5),  IsButton=false,  BoltOn=true,  IconBacking=PIC_METER_BACK_DONE  };
TXT_BOOSTED        = Locale.Lookup("LOC_BOOST_BOOSTED");
TXT_TO_BOOST      = Locale.Lookup("LOC_BOOST_TO_BOOST");
MAX_BEFORE_TRUNC_TO_BOOST = 310;

g_kEras          = {};        -- type to costs
g_kItemDefaults      = {};        -- Static data about items
g_uiNodes        = {};
g_uiConnectorSets    = {};


-- ===========================================================================
--  CONSTANTS
-- ===========================================================================

-- Spacing / Positioning Constants
local COLUMN_WIDTH          :number = 220;      -- Space of node and line(s) after it to the next node
local COLUMNS_NODES_SPAN      :number = 2;      -- How many colunms do the nodes span
local PADDING_TIMELINE_LEFT      :number = 275;
local PADDING_PAST_ERA_LEFT      :number = 30;
local PADDING_FIRST_ERA_INDICATOR  :number = -300;

-- Graphic constants
local SIZE_ART_ERA_OFFSET_X    :number = 40;      -- How far to push each era marker
local SIZE_ART_ERA_START_X    :number = 40;      -- How far to set the first era marker
local SIZE_MARKER_PLAYER_X    :number = 42;      -- Marker of player
local SIZE_MARKER_PLAYER_Y    :number = 42;      -- "
local SIZE_MARKER_OTHER_X    :number = 34;      -- Marker of other players
local SIZE_MARKER_OTHER_Y    :number = 37;      -- "
local SIZE_OPTIONS_X      :number = 200;
local SIZE_OPTIONS_Y      :number = 150;
local SIZE_PATH          :number = 40;
local SIZE_PATH_HALF      :number = SIZE_PATH / 2;
local SIZE_TIMELINE_AREA_Y    :number = 41;
local SIZE_TOP_AREA_Y      :number = 60;
local SIZE_WIDESCREEN_HEIGHT  :number = 768;

local PATH_MARKER_OFFSET_X      :number = 20;
local PATH_MARKER_OFFSET_Y      :number = 50;
local PATH_MARKER_NUMBER_0_9_OFFSET  :number = 20;
local PATH_MARKER_NUMBER_10_OFFSET  :number = 15;

-- Other constants
local ERA_ART            :table  = {};
local LINE_LENGTH_BEFORE_CURVE    :number = 20;      -- How long to make a line before a node before it curves
local PADDING_NODE_STACK_Y      :number = 0;
local PARALLAX_SPEED        :number = 1.1;      -- Speed for how much slower background moves (1.0=regular speed, 0.5=half speed)
local PARALLAX_ART_SPEED      :number = 1.2;      -- Speed for how much slower background moves (1.0=regular speed, 0.5=half speed)
local TREE_START_ROW        :number = 0;      -- Which virtual "row" does tree start on?
local TREE_START_COLUMN        :number = 0;      -- Which virtual "column" does tree start on? (Can be negative!)
local TREE_START_NONE_ID      :number = -999;      -- Special, unique value, to mark no special tree start node.
local VERTICAL_CENTER        :number = (SIZE_NODE_Y) / 2;
local MAX_BEFORE_TRUNC_KEY_LABEL  :number = 100;

-- CQUI CONSTANTS
local CQUI_STATUS_MESSAGE_TECHS          :number = 4;    -- Number to distinguish tech messages


-- ===========================================================================
--  MEMBERS / VARIABLES
-- ===========================================================================
local m_kNodeIM        :table = InstanceManager:new( "NodeInstance",       "Top",     Controls.NodeScroller );
local m_kLineIM        :table = InstanceManager:new( "LineImageInstance",     "LineImage",Controls.LineScroller );
local m_kEraArtIM      :table = InstanceManager:new( "EraArtInstance",     "Top",     Controls.EraArtScroller );
local m_kEraLabelIM      :table = InstanceManager:new( "EraLabelInstance",     "Top",     Controls.ArtScroller );
local m_kEraDotIM      :table = InstanceManager:new( "EraDotInstance",      "Dot",     Controls.ScrollbarBackgroundArt );
local m_kMarkerIM      :table = InstanceManager:new( "PlayerMarkerInstance",  "Top",    Controls.TimelineScrollbar );
local m_kSearchResultIM    :table = InstanceManager:new( "SearchResultInstance",   "Root",     Controls.SearchResultsStack);
local m_kPathMarkerIM    :table = InstanceManager:new( "TechPathMarker",      "Top",    Controls.LineScroller);

local m_researchHash    :number;

local SIZE_MIN_SPEC_X    :number = 1024;
local SIZE_MIN_SPEC_Y    :number = 768;

local m_width        :number= SIZE_MIN_SPEC_X;  -- Screen Width (default / min spec)
local m_height        :number= SIZE_MIN_SPEC_Y;  -- Screen Height (default / min spec)
local m_previousHeight    :number= SIZE_MIN_SPEC_Y;  -- Screen Height (default / min spec)
local m_scrollWidth      :number= SIZE_MIN_SPEC_X;  -- Width of the scroll bar
local m_kEraCounter      :table = {};        -- counter to determine which eras have techs --TODO Tronster: refactor, is this still necessary?
local m_maxColumns      :number= 0;          -- # of columns (highest column #)
local m_ePlayer        :number= -1;
local m_kAllPlayersTechData  :table = {};        -- All data for local players.
local m_kCurrentData    :table = {};        -- Current set of data.
local m_kFilters      :table = {};

local m_shiftDown      :boolean = false;

local m_lastPercent         :number = 0.1;
local m_FirstEraIndex    :number = -1;
local m_TopPanelConsideredHeight:number = 0;
local m_gameSeed      :number = GameConfiguration.GetValue("GAME_SYNC_RANDOM_SEED");
local m_kScrambledRowLookup  :table  = {-1,-3,2,4,0,1,-2,3};    -- To help scramble modulo rows

-- CQUI variables
local CQUI_halfwayNotified  :table = {};
local CQUI_ShowTechCivicRecommendations = false;

function CQUI_OnSettingsUpdate()
  CQUI_ShowTechCivicRecommendations = GameConfiguration.GetValue("CQUI_ShowTechCivicRecommendations") == 1
end
LuaEvents.CQUI_SettingsUpdate.Add(CQUI_OnSettingsUpdate);
LuaEvents.CQUI_SettingsInitialized.Add(CQUI_OnSettingsUpdate);


-- ===========================================================================
--  FUNCTIONS
-- ===========================================================================

-- ===========================================================================
--  Accessor (for MODs) so current data doesn't need to be made global.
-- ===========================================================================
function GetLiveData()
  if m_kCurrentData then
    return m_kCurrentData[DATA_FIELD_LIVEDATA];
  end
  return nil;
end

-- ===========================================================================
--  If anyone reverse processing needs to be done with the eras tracking
--  the tech, do that here.
-- ===========================================================================
function AddTechToEra( kEntry:table )
  -- Add that another tech belongs to this era
  if m_kEraCounter[kEntry.EraType] == nil then
    m_kEraCounter[kEntry.EraType] = 0;
  end
  m_kEraCounter[kEntry.EraType] = m_kEraCounter[ kEntry.EraType ] + 1;
end

-- ===========================================================================
-- Return string respresenation of a prereq table
-- ===========================================================================
function GetPrereqsString( prereqs:table )
  local out:string = "";
  for _,prereq in pairs(prereqs) do
    if prereq == PREREQ_ID_TREE_START then
      out = "n/a ";
    elseif g_kItemDefaults[prereq] ~= nil then
      out = out .. g_kItemDefaults[prereq].Type .. " ";  -- Add space between techs
    else
      out = out .. "n/a ";
    end
  end
  return "[" .. string.sub(out,1,string.len(out)-1) .. "]";  -- Remove trailing space
end

-- ===========================================================================
function SetCurrentNode( hash:number )
  if hash ~= nil then

    local localPlayerTechs = Players[Game.GetLocalPlayer()]:GetTechs();
    -- Get the complete path to the tech
    local pathToTech = localPlayerTechs:GetResearchPath( hash );

    local tParameters = {};

    -- Azurency : fix future civic not being able to be repeated from the tree
    local tech = GameInfo.Technologies[hash] -- the selected tech
    if next(pathToTech) ~= nil then -- if there is a path
      tParameters[PlayerOperations.PARAM_TECH_TYPE] = pathToTech;
      if m_shiftDown then
        tParameters[PlayerOperations.PARAM_INSERT_MODE] = PlayerOperations.VALUE_APPEND;
      else
        tParameters[PlayerOperations.PARAM_INSERT_MODE] = PlayerOperations.VALUE_EXCLUSIVE;
      end
      UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.RESEARCH, tParameters);
      UI.PlaySound("Confirm_Tech_TechTree");
    elseif tech.Repeatable and localPlayerTechs:CanResearch(tech.Index) then -- if the tech can be researched
      tParameters[PlayerOperations.PARAM_TECH_TYPE] = hash;
      tParameters[PlayerOperations.PARAM_INSERT_MODE] = PlayerOperations.VALUE_EXCLUSIVE;

      UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.RESEARCH, tParameters);
      UI.PlaySound("Confirm_Tech_TechTree");
    end
  else
    UI.DataError("Attempt to change current tree item with NIL hash!");
  end
end


-- ===========================================================================
--  If the next item isn't immediate, show a path of #s traversing the tree
--  to the desired node.
-- ===========================================================================
function RealizePathMarkers()

  local pTechs  :table = Players[Game.GetLocalPlayer()]:GetTechs();
  local kNodeIds  :table = pTechs:GetResearchQueue();    -- table: index, IDs

  m_kPathMarkerIM:ResetInstances();

  for i,nodeNumber in pairs(kNodeIds) do
    local pathPin = m_kPathMarkerIM:GetInstance();

    if(i < 10) then
      pathPin.NodeNumber:SetOffsetX(PATH_MARKER_NUMBER_0_9_OFFSET);
    else
      pathPin.NodeNumber:SetOffsetX(PATH_MARKER_NUMBER_10_OFFSET);
    end
    pathPin.NodeNumber:SetText(tostring(i));
    for j,node in pairs(g_kItemDefaults) do
      if node.Index == nodeNumber then
        local x:number = g_uiNodes[node.Type].x;
        local y:number = g_uiNodes[node.Type].y;
        pathPin.Top:SetOffsetX(x-PATH_MARKER_OFFSET_X);
        pathPin.Top:SetOffsetY(y-PATH_MARKER_OFFSET_Y);
      end
    end
  end
end

-- ===========================================================================
--  Does the era randomize layout?
-- ===========================================================================
function IsEraRandomizingLayout( eraType:string )
  -- TODO: Remove ERA_FUTURE check and instead look for TechTreeLayoutMethod (RandomCost) or (RandomPrereq);
  local hasLayoutMethod  :boolean = g_kEras[eraType].TechTreeLayoutMethod ~= nil;
  local isUsingPrereq    :boolean = g_kEras[eraType].TechTreeLayoutMethod == "Cost";
  local isFutureEra    :boolean = eraType=="ERA_FUTURE";
  return hasLayoutMethod and isUsingPrereq and isFutureEra;
end

-- ===========================================================================
--  Get visual row for tech.
-- ===========================================================================
function GetRandomizedTreeRow( uirow:number )
  local range :number = (ROW_MAX - ROW_MIN);
  local index  :number = ((uirow + m_gameSeed) % range) + 1;
  uirow = m_kScrambledRowLookup[index];
  return uirow;
end


-- ===========================================================================
--  Convert a virtual column # and row # to actual pixels within the
--  scrollable tree area.
-- ===========================================================================
function ColumnRowToPixelXY( column:number, row:number)
  local horizontal    :number = ((column-1) * COLUMNS_NODES_SPAN * COLUMN_WIDTH) + PADDING_TIMELINE_LEFT + PADDING_PAST_ERA_LEFT;
  local vertical      :number = PADDING_NODE_STACK_Y + (SIZE_WIDESCREEN_HEIGHT / 2) + (row * SIZE_NODE_Y);
  return horizontal, vertical;
end

-- ===========================================================================
--  Get the width of the scroll panel
-- ===========================================================================
function GetMaxScrollWidth()
  return m_maxColumns + (m_maxColumns * COLUMN_WIDTH) + PADDING_TIMELINE_LEFT + PADDING_PAST_ERA_LEFT;
end

-- ===========================================================================
--  Get the x offset of an era art instance
-- ===========================================================================
function GetEraArtXOffset(instArt, eraData)
  local centerx      :number = ColumnRowToPixelXY(eraData.MiddleColumn, 0) - PADDING_PAST_ERA_LEFT;
  local startPaddingAmount:number = (eraData.Index == m_FirstEraIndex and PADDING_FIRST_ERA_INDICATOR or 0);
  return (centerx + startPaddingAmount) * (1 / PARALLAX_ART_SPEED);
end


-- ===========================================================================
--  The rules to determine how nodes are placed on an invisible grid.
--  Override this if you want to use a different algorithm for node placement.
--
--  Rules for Vanilla, XP1, XP2:
--  Each era has it's own set of columns, with the columns being dictated by
--  the different costs per item.
--  e.g., If 5 items in an era cost 10,10,50,50,90 there will exist 3 columns.
--
--  RETURNS: Table which is:  nodeGrid[ row# ][ column# ] = itemType
--
-- ===========================================================================
function LayoutNodeGrid()

  local kNodeGrid :table = {};
  local kPaths  :table = {};  -- TODO: unused currently

  -- Loop items, first put into era columns.
  for _,item in pairs(g_kItemDefaults) do

    local era  :table  = g_kEras[item.EraType];

    if Locale.ToUpper(era.TechTreeLayoutMethod) == "PREREQ" then

      local largestPrereqNum :number  = 0;

      -- Recurse
      -- item, current item to inspect
      -- era, the era being looked at
      -- returns # of prereqs for item in era
      function GetItemsInEraPrereqChain(item, era)
        if (g_kEras[item.EraType] ~= era) then
          return 0;  -- Not in era, exit.
        end

        local largestDepth  :number  = 0;
        for _,prereqId in pairs(item.Prereqs) do
          if prereqId ~= PREREQ_ID_TREE_START then
            local kPrereq    :table  = g_kItemDefaults[prereqId];
            local depth      :number = GetItemsInEraPrereqChain(kPrereq, era);  -- Recurse
            if (largestDepth < depth) then
              largestDepth = depth;
            end
          end
        end

        -- Mark (for later) which column the item should be placed in the node grid.
        if (item["__tempLayoutColumn"] == nil) or (item.__tempLayoutColumn < largestDepth) then
          item.__tempLayoutColumn = largestDepth;
        end

        return largestDepth + 1;
      end

      largestPrereqNum = GetItemsInEraPrereqChain(item, era);

      if era.NumColumns < largestPrereqNum then
        era.NumColumns = largestPrereqNum;
      end
    else
      -- Layout the nodes in columns based on increasing cost within an era.
      -- DEFAULT --elseif  Locale.ToUpper(era.TechTreeLayoutMethod) == "COST" or era.TechTreeLayoutMethod == "" then
      -- Create a column for each different cost in the era.
      if era.Columns[item.Cost] == nil then
        era.Columns[item.Cost] = {};
      end
      table.insert( era.Columns[item.Cost], item.Type );
      era.NumColumns = table.count( era.Columns );
    end
  end

  -- Loop items again to adjust 1 based index and/or set cost columns
  -- Set to a random row (for those using a random one).
  for _,item in pairs(g_kItemDefaults) do
    local era :table  = g_kEras[item.EraType];

    -- Assigning column based off of total columns used
    if Locale.ToUpper(era.TechTreeLayoutMethod) == "PREREQ" then
      item.Column = item.__tempLayoutColumn + 1;
      item.__tempLayoutColumn = nil;

    else  -- DEFAULT --if Locale.ToUpper(era.TechTreeLayoutMethod) == "COST" then
      local i      :number = 0;
      local isFound  :boolean = false;
      for cost,columns in orderedPairs( era.Columns ) do
        if cost ~= "__orderedIndex" then      -- skip temp table used for order
          i = i + 1;
          for _,itemType in ipairs(columns) do
            if itemType == item.Type then
              item.Column = i;
              isFound = true;
              break;
            end
          end
          if isFound then break; end
        end
      end
      era.Columns.__orderedIndex = nil;
    end

    -- Randomize UI tree row (if this game & era does that sort of thing.)
    if IsEraRandomizingLayout(item.EraType) then
      item.UITreeRow = GetRandomizedTreeRow(item.UITreeRow);
    end
  end

  -- Determine total # of columns prior to a given era, and max columns overall.
  local index = 0;
  local priorColumns:number = 0;
  m_maxColumns = 0;
  for row:table in GameInfo.Eras() do
    for era,eraData in pairs(g_kEras) do
      if eraData.Index == index then                  -- Ensure indexed order
        eraData.PriorColumns = priorColumns;
        eraData.MiddleColumn = priorColumns + ((eraData.NumColumns + 1) / 2);
        priorColumns = priorColumns + eraData.NumColumns + 1;  -- Add one for era art between
        m_FirstEraIndex = m_FirstEraIndex < 0 and index or math.min(m_FirstEraIndex, index);
        break;
      end
    end
    index = index + 1;
  end
  m_maxColumns = priorColumns;

  -- Set nodes in the rows specified and columns computed above.
  for i = ROW_MIN,ROW_MAX,1 do
    kNodeGrid[i] = {};
  end
  for _,item in pairs(g_kItemDefaults) do
    local era    :table  = g_kEras[item.EraType];
    local columnNum :number = era.PriorColumns + item.Column;
    kNodeGrid[item.UITreeRow][columnNum] = item.Type;
  end

  return kNodeGrid, kPaths;
end

-- ===========================================================================
--  Create UI controls based on the a node grid and connecting paths.
--
--  kNodeGrid,  A 2D table array of [row][columns]=itemType
--  kPaths,    A table describing paths.  TODO: Describe this format. ??TRON
--
--  No state specific data (e.g., selected node) should be set here in order
--  to reuse the nodes across viewing other players' trees for single seat
--  multiplayer or if a (spy) game rule allows looking at another's tree.
-- ===========================================================================
function AllocateUI( kNodeGrid:table, kPaths:table )

  g_uiNodes = {};
  m_kNodeIM:ResetInstances();

  g_uiConnectorSets = {};
  m_kLineIM:ResetInstances();

  -- Era divider information
  m_kEraArtIM:ResetInstances();
  m_kEraLabelIM:ResetInstances();
  m_kEraDotIM:ResetInstances();

  -- Autoplay check
  local playerId :number = Game.GetLocalPlayer();
  if (playerId == -1) then
    return;
  end

  for era,eraData in pairs(g_kEras) do

    local instArt :table = m_kEraArtIM:GetInstance();
    if eraData.BGTexture ~= nil then
      instArt.BG:SetTexture( eraData.BGTexture );
    else
      UI.DataError("Tech tree is unable to find an EraTechBackgroundTexture entry for era '"..eraData.Description.."'; using a default.");
      instArt.BG:SetTexture(PIC_DEFAULT_ERA_BACKGROUND);
    end

    instArt.Top:SetOffsetX(GetEraArtXOffset(instArt, eraData));
    instArt.Top:SetOffsetY((SIZE_WIDESCREEN_HEIGHT * 0.5) - (instArt.BG:GetSizeY() * 0.5));
    instArt.Top:SetSizeVal(eraData.NumColumns * SIZE_NODE_X, 600);

    local inst:table = m_kEraLabelIM:GetInstance();
    local eraMarkerx, _  = ColumnRowToPixelXY( eraData.PriorColumns + 1, 0) - PADDING_PAST_ERA_LEFT;  -- Need to undo the padding in place that nodes use to get past the era marker column
    inst.Top:SetOffsetX((eraMarkerx - (SIZE_NODE_X * 0.5)) * (1 / PARALLAX_SPEED));
    inst.EraTitle:SetText(Locale.Lookup("LOC_GAME_ERA_DESC",eraData.Description));

    -- Dots on scrollbar
    local markerx:number = (eraData.PriorColumns / m_maxColumns) * Controls.ScrollbarBackgroundArt:GetSizeX();
    if markerx > 0 then
      local inst:table = m_kEraDotIM:GetInstance();
      inst.Dot:SetOffsetX(markerx);
    end
  end

  local playerUnlockables = GetFilteredUnlockableItems(playerId);    -- Expensive to calculate and we are going to call GetUnlockablesForTech_Cached repeatedly, pre-calculate it.

  -- Actually build UI nodes
  for _,item in pairs(g_kItemDefaults) do

    local tech:table    = GameInfo.Technologies[item.Type];
    local techType:string  = tech and tech.TechnologyType;

    local unlockableTypes  = GetUnlockablesForTech_Cached(techType, playerId, playerUnlockables);
    local node        :table;
    local numUnlocks    :number = 0;

    if unlockableTypes ~= nil then
      for _, unlockItem in ipairs(unlockableTypes) do
        local typeInfo = GameInfo.Types[unlockItem[1]];
        numUnlocks = numUnlocks + 1;
      end
    end

    node = m_kNodeIM:GetInstance();
    node.Top:SetTag( item.Hash );  -- Set the hash of the technology to the tag of the node (for tutorial to be able to callout)

    local era:table = g_kEras[item.EraType];

    -- Horizontal # = All prior nodes across all previous eras + node position in current era (based on cost vs. other nodes in that era)
    local horizontal, vertical = ColumnRowToPixelXY(era.PriorColumns + item.Column, item.UITreeRow );

    -- Add data fields to UI component
    node.Type  = techType;            -- Dynamically add "Type" field to UI node for quick look ups in item data table.
    node.x    = horizontal;          -- Granted x,y can be looked up via GetOffset() but caching the values here for
    node.y    = vertical - VERTICAL_CENTER;  -- other LUA functions to use removes the necessity of a slow C++ roundtrip.

    if node["unlockIM"] ~= nil then
      node["unlockIM"]:DestroyInstances()
    end
    node["unlockIM"] = InstanceManager:new( "UnlockInstance", "UnlockIcon", node.UnlockStack );

    if node["unlockGOV"] ~= nil then
      node["unlockGOV"]:DestroyInstances()
    end
    node["unlockGOV"] = InstanceManager:new( "GovernmentIcon", "GovernmentInstanceGrid", node.UnlockStack );

    PopulateUnlockablesForTech(playerId, tech.Index, node["unlockIM"], function() SetCurrentNode(item.Hash); end);

    node.NodeButton:RegisterCallback( Mouse.eLClick, function() SetCurrentNode(item.Hash); end);
    node.OtherStates:RegisterCallback( Mouse.eLClick, function() SetCurrentNode(item.Hash); end);

    -- Set position and save.
    node.Top:SetOffsetVal( horizontal, vertical);
    g_uiNodes[item.Type] = node;
  end

  if Controls.TreeStart ~= nil then
    local h,v = ColumnRowToPixelXY( TREE_START_COLUMN, TREE_START_ROW );
    Controls.TreeStart:SetOffsetVal( h+SIZE_NODE_X-42,v-71 );    -- TODO: Science-out the magic (numbers).
  end

  -- Determine the lines between nodes.
  -- NOTE: Potentially move this to view, since lines are constantly change in look, but
  --     it makes sense to have at least the routes computed here since they are
  --     consistent regardless of the look.
  local previousRow  :number = 0;
  local previousColumn:number = 0;
  for type,item in pairs(g_kItemDefaults) do

    local node:table = g_uiNodes[item.Type];
    for _,prereqId in pairs(item.Prereqs) do

      previousRow     = TREE_START_ROW;
      previousColumn = TREE_START_COLUMN;

      if prereqId ~= PREREQ_ID_TREE_START then
        -- There had better be a preq if there is a prereq ID (unless debugging the tree).
        local prereq :table = g_kItemDefaults[prereqId];
        if (prereq ~= nil) then
          previousRow    = prereq.UITreeRow;
          previousColumn  = g_kEras[prereq.EraType].PriorColumns + prereq.Column;
        else
          if table.count(debugExplicitList) == 0 then
            UI.DataError("Unable to find PREREQ for tech '"..item.Type.."'("..tostring(item.Index)..")");
          end
        end
      end

      local startColumn  :number = g_kEras[item.EraType].PriorColumns + item.Column;
      local column    :number  = startColumn;
      local isEarlyBend  :boolean= false;
      local isAtPrior    :boolean= false;

      while( not isAtPrior ) do
        column = column - 1;  -- Move backwards one

        -- If a node is found, make sure it's the previous node this is looking for.
        if (kNodeGrid[previousRow][column] ~= nil) then
          if kNodeGrid[previousRow][column] == prereqId then
            isAtPrior = true;
          end
        elseif column <= TREE_START_COLUMN then
          isAtPrior = true;
        end

        if (not isAtPrior) and kNodeGrid[item.UITreeRow][column] ~= nil then
          -- Was trying to hold off bend until start, but it looks to cross
          -- another node, so move the bend to the end.
          isEarlyBend = true;
        end

        if column < 0 then
          UI.DataError("Tech tree could not find prior for '"..prereqId.."'");
          break;
        end
      end


      if previousRow == TREE_START_NONE_ID then

        -- Nothing goes before this, not even a fake start area.

      elseif previousRow < item.UITreeRow or previousRow > item.UITreeRow  then

        -- Obtain grid pieces to                            ____________________
        -- use in order to draw                ___ ________|                    |
        -- lines.                             |L2 |L1      |        NODE        |
        --                                    |___|________|                    |
        --   _____________________            |L3 |   x1   |____________________|
        --  |                     |___________|___|
        --  |    PREVIOUS NODE    | L5        |L4 |
        --  |                     |___________|___|
        --  |_____________________|     x2
        --
        local inst  :table = m_kLineIM:GetInstance();
        local line1  :table = inst.LineImage; inst = m_kLineIM:GetInstance();
        local line2  :table = inst.LineImage; inst = m_kLineIM:GetInstance();
        local line3  :table = inst.LineImage; inst = m_kLineIM:GetInstance();
        local line4  :table = inst.LineImage; inst = m_kLineIM:GetInstance();
        local line5  :table = inst.LineImage;

        -- Find all the empty space before the node before to make a bend.
        local LineEndX1:number = 0;
        local LineEndX2:number = 0;
        if isEarlyBend then
          LineEndX1 = (node.x - LINE_LENGTH_BEFORE_CURVE ) ;
          LineEndX2, _ = ColumnRowToPixelXY( column, item.UITreeRow );
          LineEndX2 = LineEndX2 + SIZE_NODE_X;
        else
          LineEndX1, _ = ColumnRowToPixelXY( column, item.UITreeRow );
          LineEndX2, _ = ColumnRowToPixelXY( column, item.UITreeRow );
          LineEndX1 = LineEndX1 + SIZE_NODE_X + LINE_LENGTH_BEFORE_CURVE;
          LineEndX2 = LineEndX2 + SIZE_NODE_X;
        end

        local prevY  :number = 0;  -- y position of the previous node being connected to

        if previousRow < item.UITreeRow  then
          prevY = node.y-((item.UITreeRow-previousRow)*SIZE_NODE_Y);-- above
          line2:SetTexture("Controls_TreePathDashSE");
          line4:SetTexture("Controls_TreePathDashES");
        else
          prevY = node.y+((previousRow-item.UITreeRow)*SIZE_NODE_Y);-- below
          line2:SetTexture("Controls_TreePathDashNE");
          line4:SetTexture("Controls_TreePathDashEN");
        end

        line1:SetOffsetVal(LineEndX1 + SIZE_PATH_HALF, node.y - SIZE_PATH_HALF);
        line1:SetSizeVal( node.x - LineEndX1 - SIZE_PATH_HALF, SIZE_PATH);
        line1:SetTexture("Controls_TreePathDashEW");

        line2:SetOffsetVal(LineEndX1 - SIZE_PATH_HALF, node.y - SIZE_PATH_HALF);
        line2:SetSizeVal( SIZE_PATH, SIZE_PATH);

        line3:SetOffsetVal(LineEndX1 - SIZE_PATH_HALF, math.min(node.y + SIZE_PATH_HALF, prevY + SIZE_PATH_HALF) );
        line3:SetSizeVal( SIZE_PATH, math.abs(node.y - prevY) - SIZE_PATH );
        line3:SetTexture("Controls_TreePathDashNS");

        line4:SetOffsetVal(LineEndX1 - SIZE_PATH_HALF, prevY - SIZE_PATH_HALF);
        line4:SetSizeVal( SIZE_PATH, SIZE_PATH);

        line5:SetSizeVal(  LineEndX1 - LineEndX2 - SIZE_PATH_HALF, SIZE_PATH );
        line5:SetOffsetVal(LineEndX2, prevY - SIZE_PATH_HALF);
        line1:SetTexture("Controls_TreePathDashEW");

        -- Directly store the line (not instance) with a key name made up of this type and the prereq's type.
        g_uiConnectorSets[item.Type..","..prereqId] = {line1,line2,line3,line4,line5};

      else
        -- Prereq is on the same row
        local inst:table = m_kLineIM:GetInstance();
        local line:table = inst.LineImage;
        line:SetTexture("Controls_TreePathDashEW");
        local end1, _ = ColumnRowToPixelXY( column, item.UITreeRow );
        end1 = end1 + SIZE_NODE_X;

        line:SetOffsetVal(end1, node.y - SIZE_PATH_HALF);
        line:SetSizeVal( node.x - end1, SIZE_PATH);

        -- Directly store the line (not instance) with a key name made up of this type and the prereq's type.
        g_uiConnectorSets[item.Type..","..prereqId] = {line};
      end
    end
  end

  Controls.NodeScroller:CalculateSize();
  Controls.ArtScroller:CalculateSize();
  Controls.EraArtScroller:CalculateSize();

  Controls.NodeScroller:RegisterScrollCallback( OnScroll );

  -- We use a separate BG within the PeopleScroller control since it needs to scroll with the contents
  Controls.ModalBG:SetHide(true);
  Controls.ModalScreenClose:RegisterCallback(Mouse.eLClick, OnClose);
  Controls.ModalScreenTitle:SetText(Locale.ToUpper(Locale.Lookup("LOC_TECH_TREE_HEADER")));
end

-- ===========================================================================
--  UI Event
--  Callback when the main scroll panel is scrolled.
-- ===========================================================================
function OnScroll( control:table, percent:number )

  -- Parallax
  Controls.ArtScroller:SetScrollValue( percent );
  Controls.LineScroller:SetScrollValue( percent );
  Controls.EraArtScroller:SetScrollValue( percent );

    -- Audio
  if percent==0 or percent==1.0 then
        if m_lastPercent == percent then
            return;
        end
        UI.PlaySound("UI_TechTree_ScrollTick_End");
  else
    UI.PlaySound("UI_TechTree_ScrollTick");
  end

    m_lastPercent = percent;
end

-- ===========================================================================
--  Now its own function so Mods / Expansions can modify the nodes
-- ===========================================================================
function PopulateNode(uiNode, playerTechData)
  local item    :table = g_kItemDefaults[uiNode.Type];            -- static item data
  local live    :table = playerTechData[DATA_FIELD_LIVEDATA][uiNode.Type];  -- live (changing) data
  local artInfo  :table = STATUS_ART[live.Status];              -- art/styles for this state

  if(live.Status == ITEM_STATUS.RESEARCHED) then
    for _,prereqId in pairs(item.Prereqs) do
      if(prereqId ~= PREREQ_ID_TREE_START) then
        local prereq    :table = g_kItemDefaults[prereqId];
        local previousRow  :number = prereq.UITreeRow;
        local previousColumn:number = g_kEras[prereq.EraType].PriorColumns;

        for lineNum,line in pairs(g_uiConnectorSets[item.Type..","..prereqId]) do
          if(lineNum == 1 or lineNum == 5) then
            line:SetTexture("Controls_TreePathEW");
          end
          if( lineNum == 3) then
            line:SetTexture("Controls_TreePathNS");
          end

          if(lineNum==2)then
            if previousRow < item.UITreeRow  then
              line:SetTexture("Controls_TreePathSE");
            else
              line:SetTexture("Controls_TreePathNE");
            end
          end

          if(lineNum==4)then
            if previousRow < item.UITreeRow  then
              line:SetTexture("Controls_TreePathES");
            else
              line:SetTexture("Controls_TreePathEN");
            end
          end
        end
      end
    end
  end

  uiNode.NodeName:SetColor( artInfo.TextColor0, 0 );
  uiNode.NodeName:SetColor( artInfo.TextColor1, 1 );
  if debugShowIDWithName then
    uiNode.NodeName:SetText( tostring(item.Index).."  "..Locale.Lookup(item.Name) );  -- Debug output
  else
    uiNode.NodeName:SetText( Locale.ToUpper( Locale.Lookup(item.Name) ));        -- Normal output
  end

  if live.Turns > 0 then
    uiNode.Turns:SetHide( false );
    uiNode.Turns:SetColor( artInfo.TextColor0, 0 );
    uiNode.Turns:SetColor( artInfo.TextColor1, 1 );
    uiNode.Turns:SetText( Locale.Lookup("LOC_TECH_TREE_TURNS",live.Turns) );
  else
    uiNode.Turns:SetHide( true );
  end

  if item.IsBoostable and live.Status ~= ITEM_STATUS.RESEARCHED then
    uiNode.BoostIcon:SetHide( false );
    uiNode.BoostText:SetHide( false );
    uiNode.BoostText:SetColor( artInfo.TextColor0, 0 );
    uiNode.BoostText:SetColor( artInfo.TextColor1, 1 );

    local boostText:string;
    if live.IsBoosted then
      boostText = TXT_BOOSTED.." "..item.BoostText;
      uiNode.BoostIcon:SetTexture( PIC_BOOST_ON );
      uiNode.BoostMeter:SetHide( true );
      uiNode.BoostedBack:SetHide( false );
    else
      boostText = TXT_TO_BOOST.." "..item.BoostText;
      uiNode.BoostedBack:SetHide( true );
      uiNode.BoostIcon:SetTexture( PIC_BOOST_OFF );
      uiNode.BoostMeter:SetHide( false );
      local boostAmount = (item.BoostAmount*.01) + (live.Progress/ live.Cost);
      uiNode.BoostMeter:SetPercent( boostAmount );
    end
    TruncateStringWithTooltip(uiNode.BoostText, MAX_BEFORE_TRUNC_TO_BOOST, boostText);
  else
    uiNode.BoostIcon:SetHide( true );
    uiNode.BoostText:SetHide( true );
    uiNode.BoostedBack:SetHide( true );
    uiNode.BoostMeter:SetHide( true );
  end

  if live.Status == ITEM_STATUS.CURRENT then
    uiNode.GearAnim:SetHide( false );
  else
    uiNode.GearAnim:SetHide( true );
  end

  if live.Progress > 0 then
    uiNode.ProgressMeter:SetHide( false );
    uiNode.ProgressMeter:SetPercent(live.Progress / live.Cost);
  else
    uiNode.ProgressMeter:SetHide( true );
  end

  -- Show/Hide Recommended Icon
  -- CQUI : only if show tech civ enabled in settings
  if live.IsRecommended and live.AdvisorType ~= nil and CQUI_ShowTechCivicRecommendations then
    uiNode.RecommendedIcon:SetIcon(live.AdvisorType);
    uiNode.RecommendedIcon:SetHide(false);
  else
    uiNode.RecommendedIcon:SetHide(true);
  end

  -- Set art for icon area
  if(uiNode.Type ~= nil) then
    local iconName :string = DATA_ICON_PREFIX .. uiNode.Type;
    if (artInfo.Name == "BLOCKED") then
      uiNode.IconBacking:SetHide(true);
      iconName = iconName .. "_FOW";
      uiNode.BoostMeter:SetColor(0x66ffffff);
      uiNode.BoostIcon:SetColor(0x66000000);
    else
      uiNode.IconBacking:SetHide(false);
      iconName = iconName;
      uiNode.BoostMeter:SetColor(0xffffffff);
      uiNode.BoostIcon:SetColor(0xffffffff);
    end
    local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName, 42);
    if (textureOffsetX ~= nil) then
      uiNode.Icon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
    end
  end

  if artInfo.IsButton then
    uiNode.OtherStates:SetHide( true );
    uiNode.NodeButton:SetTextureOffsetVal( artInfo.BGU, artInfo.BGV );
  else
    uiNode.OtherStates:SetHide( false );
    uiNode.OtherStates:SetTextureOffsetVal( artInfo.BGU, artInfo.BGV );
  end

  if artInfo.FillTexture ~= nil then
    uiNode.FillTexture:SetHide( false );
    uiNode.FillTexture:SetTexture( artInfo.FillTexture );
  else
    uiNode.FillTexture:SetHide( true );
  end

  if artInfo.BoltOn then
    uiNode.Bolt:SetTexture(PIC_BOLT_ON);
  else
    uiNode.Bolt:SetTexture(PIC_BOLT_OFF);
  end

  uiNode.NodeButton:SetToolTipString(ToolTipHelper.GetToolTip(item.Type, Game.GetLocalPlayer()));
  uiNode.IconBacking:SetTexture(artInfo.IconBacking);

  -- Darken items not making it past filter.
  local currentFilter:table = playerTechData[DATA_FIELD_UIOPTIONS].filter;
  if currentFilter == nil or currentFilter.Func == nil or currentFilter.Func( item.Type ) then
    uiNode.FilteredOut:SetHide( true );
  else
    uiNode.FilteredOut:SetHide( false );
  end

  -- Civilopedia: Only wire up handlers if not in an on-rails tutorial; as clicking it can take a player off the rails...
  function OpenPedia()
    LuaEvents.OpenCivilopedia(uiNode.Type);
  end
  if IsTutorialRunning()==false then
    uiNode.NodeButton:RegisterCallback( Mouse.eRClick, OpenPedia);
    uiNode.OtherStates:RegisterCallback( Mouse.eRClick,OpenPedia);
  end

end

-- ===========================================================================
--  Display the state of the tree (filter, node display, etc...) based on the
--  active player's item data.
-- ===========================================================================
function View( playerTechData:table )

  -- Output the node states for the tree
  for _,uiNode in pairs(g_uiNodes) do
    PopulateNode( uiNode, playerTechData);
  end

  -- Fill in where the markers (representing players) are at:
  m_kMarkerIM:ResetInstances();
  local PADDING    :number = 24;
  local thisPlayerID  :number = Game.GetLocalPlayer();
  local markers    :table  = m_kCurrentData[DATA_FIELD_PLAYERINFO].Markers;
  for _,markerStat in ipairs( markers ) do

    -- Only build a marker if a player has started researching...
    if markerStat.HighestColumn ~= -1 then
      local instance  :table  = m_kMarkerIM:GetInstance();

      if markerStat.IsPlayerHere then
        -- Representing the player viewing the tree
        instance.Portrait:SetHide( true );
        instance.TurnGrid:SetHide( false );
        instance.TurnLabel:SetText( Locale.Lookup("LOC_TECH_TREE_TURN_NUM" ));

        --instance.TurnNumber:SetText( tostring(Game.GetCurrentGameTurn()) );
        local turn = Game.GetCurrentGameTurn();
        instance.TurnNumber:SetText(tostring(turn));

        local turnLabelWidth = PADDING + instance.TurnLabel:GetSizeX() +  instance.TurnNumber:GetSizeX();
        instance.TurnGrid:SetSizeX( turnLabelWidth );
        instance.Marker:SetTexture( PIC_MARKER_PLAYER );
        instance.Marker:SetSizeVal( SIZE_MARKER_PLAYER_X, SIZE_MARKER_PLAYER_Y );
      else
        -- An other player
        instance.TurnGrid:SetHide( true );
        instance.Marker:SetTexture( PIC_MARKER_OTHER );
        instance.Marker:SetSizeVal( SIZE_MARKER_OTHER_X, SIZE_MARKER_OTHER_Y );
      end

      -- Different content in marker based on if there is just 1 player in the column, or more than 1
      local tooltipString        :string = Locale.Lookup("LOC_TREE_ERA", Locale.Lookup(GameInfo.Eras[markerStat.HighestEra].Name) ).."[NEWLINE]";
      local numOfPlayersAtThisColumn  :number = table.count(markerStat.PlayerNums);
      if numOfPlayersAtThisColumn < 2 then
        instance.Num:SetHide( true );
        local playerNum    :number = markerStat.PlayerNums[1];
        local pPlayerConfig :table =  PlayerConfigurations[playerNum];
        tooltipString = tooltipString.. Locale.Lookup(pPlayerConfig:GetPlayerName());  -- ??TRON: Temporary using player name until leaderame is fixed

        if not markerStat.IsPlayerHere then
          local iconName:string = "ICON_"..pPlayerConfig:GetLeaderTypeName();
          local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas(iconName);
          instance.Portrait:SetHide( false );
          instance.Portrait:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
        end
      else
        instance.Portrait:SetHide( true );
        instance.Num:SetHide( false );
        instance.Num:SetText(tostring(numOfPlayersAtThisColumn));
        for i,playerNum in ipairs(markerStat.PlayerNums) do
          local pPlayerConfig :table = PlayerConfigurations[playerNum];
          --tooltipString = tooltipString.. Locale.Lookup(pPlayerConfig:GetLeaderName());
          tooltipString = tooltipString.. Locale.Lookup(pPlayerConfig:GetPlayerName());  -- ??TRON: Temporary using player name until leaderame is fixed
          if i < numOfPlayersAtThisColumn then
            tooltipString = tooltipString.."[NEWLINE]";
          end
        end
      end
      instance.Marker:SetToolTipString( tooltipString );

      local MARKER_OFFSET_START:number = 20;
      local markerPercent :number = math.clamp( markerStat.HighestColumn / m_maxColumns, 0, 1 );
      local markerX    :number = MARKER_OFFSET_START + (markerPercent * m_scrollWidth );
      instance.Top:SetOffsetVal(markerX ,0);
    end
  end

  RealizePathMarkers();
  RealizeFilterPulldown();
  RealizeKeyPanel();
  RealizeTutorialNodes();
end


-- ===========================================================================
--  Load all the 'live' data for a player.
-- ===========================================================================
function GetCurrentData( ePlayer:number, eCompletedTech:number )

  -- If first time, initialize player data tables.
  local data  :table = m_kAllPlayersTechData[ePlayer];
  if data == nil then
    -- Initialize player's top level tables:
    data = {};
    data[DATA_FIELD_LIVEDATA]      = {};
    data[DATA_FIELD_PLAYERINFO]      = {};
    data[DATA_FIELD_UIOPTIONS]      = {};

    -- Initialize data, and sub tables within the top tables.
    data[DATA_FIELD_PLAYERINFO].Player  = ePlayer;  -- Number of this player
    data[DATA_FIELD_PLAYERINFO].Markers  = {};    -- Hold a condenced, UI-ready version of stats
    data[DATA_FIELD_PLAYERINFO].Stats  = {};    -- Hold stats on where each player is (based on what this player can see)
  end

  local kPlayer    :table  = Players[ePlayer];
  local playerTechs  :table  = kPlayer:GetTechs();
  local currentTechID  :number = playerTechs:GetResearchingTech();

  -- Get recommendations
  local techRecommendations:table = {};
  local kGrandAI:table = kPlayer:GetGrandStrategicAI();
  if kGrandAI then
    for i,recommendation in pairs(kGrandAI:GetTechRecommendations()) do
      techRecommendations[recommendation.TechHash] = recommendation.TechScore;
    end
  end

  -- DEBUG: Output header to console.
  if debugOutputTechInfo then
    print("                          Item Id  Status      Progress   $ Era              Prereqs");
    print("------------------------------ --- ---------- --------- --- ---------------- --------------------------");
  end

  -- Loop through all items and place in appropriate buckets as well
  -- read in the associated information for it.
  for type,item in pairs(g_kItemDefaults) do
    local techID  :number = GameInfo.Technologies[item.Type].Index;
    local status  :number = ITEM_STATUS.BLOCKED;
    local turnsLeft  :number = playerTechs:GetTurnsToResearch(techID);
    if playerTechs:HasTech(techID) or techID == eCompletedTech then
      status = ITEM_STATUS.RESEARCHED;
      turnsLeft = 0;
    elseif techID == currentTechID then
      status = ITEM_STATUS.CURRENT;
      turnsLeft = playerTechs:GetTurnsLeft();
    elseif playerTechs:CanResearch(techID) then
      status = ITEM_STATUS.READY;
    end

    data[DATA_FIELD_LIVEDATA][type] = {
      Cost    = playerTechs:GetResearchCost(techID),
      IsBoosted  = playerTechs:HasBoostBeenTriggered(techID),
      Progress  = playerTechs:GetResearchProgress(techID),
      Status    = status,
      Turns    = turnsLeft
    }

    -- Determine if tech is recommended
    if techRecommendations[item.Hash] then
      data[DATA_FIELD_LIVEDATA][type].AdvisorType = GameInfo.Technologies[item.Type].AdvisorType;
      data[DATA_FIELD_LIVEDATA][type].IsRecommended = true;
    else
      data[DATA_FIELD_LIVEDATA][type].IsRecommended = false;
    end

    -- DEBUG: Output to console detailed information about the tech.
    if debugOutputTechInfo then
      local this:table = data[DATA_FIELD_LIVEDATA][type];
      print( string.format("%30s %-3d %-10s %4d/%-4d %3d %-16s %s",
        type,item.Index,
        STATUS_ART[status].Name,
        this.Progress,
        this.Cost,
        this.Turns,
        item.EraType,
        GetPrereqsString(item.Prereqs)
      ));
    end
  end

  local players = Game.GetPlayers{Major = true};

  -- Determine where all players are.
  local playerVisibility = PlayersVisibility[ePlayer];
  if playerVisibility ~= nil then
    for i, otherPlayer in ipairs(players) do
      local playerID    :number = otherPlayer:GetID();
      local playerTech  :table  = players[i]:GetTechs();
      local currentTech  :number = playerTech:GetResearchingTech();
      data[DATA_FIELD_PLAYERINFO].Stats[playerID] = {
        CurrentID    = currentTech,    -- tech currently being researched
        HasMet      = kPlayer:GetDiplomacy():HasMet(playerID) or playerID==ePlayer or debugShowAllMarkers;
        HighestColumn  = -1,        -- where they are in the timeline
        HighestEra    = ""
      };

      -- The latest tech a player may be researching may not be the one
      -- furthest along in time; so go through ALL the techs and track
      -- the highest column of all researched tech.
      local highestColumn :number = -1;
      local highestEra  :string = "";
      for _,item in pairs(g_kItemDefaults) do
        local techID:number = GameInfo.Technologies[item.Type].Index;
        if playerTech:HasTech(techID) then
          local column:number = item.Column + g_kEras[item.EraType].PriorColumns;
          if column > highestColumn then
            highestColumn  = column;
            highestEra    = item.EraType;
          end
        end
      end
      data[DATA_FIELD_PLAYERINFO].Stats[playerID].HighestColumn  = highestColumn;
      data[DATA_FIELD_PLAYERINFO].Stats[playerID].HighestEra    = highestEra;
    end
  end

  -- All player data is added.. build markers data based on player data.
  local checkedID:table = {};
  data[DATA_FIELD_PLAYERINFO].Markers  = {};
  for playerID:number, targetPlayer:table in pairs(data[DATA_FIELD_PLAYERINFO].Stats) do
    -- Only look for IDs that haven't already been merged into a marker.
    if checkedID[playerID] == nil and targetPlayer.HasMet then
      checkedID[playerID] = true;
      local markerData:table = {};
      if data[DATA_FIELD_PLAYERINFO].Markers[playerID] ~= nil then
        markerData = data[DATA_FIELD_PLAYERINFO].Markers[playerID];
        markerData.HighestColumn = targetPlayer.HighestColumn;
        markerData.HighestEra    = targetPlayer.HighestEra;
        markerData.IsPlayerHere  = (playerID == ePlayer);
      else
        markerData = {
              HighestColumn  = targetPlayer.HighestColumn,  -- Which column this marker should be placed
              HighestEra    = targetPlayer.HighestEra,
              IsPlayerHere  = (playerID == ePlayer),
              PlayerNums    = {playerID}}                  -- All players who share this marker spot
        table.insert( data[DATA_FIELD_PLAYERINFO].Markers, markerData );
      end

      -- SPECIAL CASE: Current player starts at column 0 so it's immediately visible on timeline:
      if playerID == ePlayer and markerData.HighestColumn == -1 then
        markerData.HighestColumn = 0;
        local firstEra:table = nil;
        for _,era in pairs(g_kEras) do
          if firstEra == nil or era.Index < firstEra.Index then
            firstEra = era;
          end
        end
        if firstEra then
          markerData.HighestEra = firstEra.Index;
        else
          markerData.HighestEra = 0;
        end
      end

      -- Traverse all the IDs and merge them with this one.
      for anotherID:number, anotherPlayer:table in pairs(data[DATA_FIELD_PLAYERINFO].Stats) do
        -- Don't add if: it's ourself, if hasn't researched at least 1 tech, if we haven't met
        if playerID ~= anotherID and anotherPlayer.HighestColumn > -1 and anotherPlayer.HasMet then
          if markerData.HighestColumn == data[DATA_FIELD_PLAYERINFO].Stats[anotherID].HighestColumn then
            checkedID[anotherID] = true;
            -- Need to do this check if player's ID didn't show up first in the list in creating the marker.
            if anotherID == ePlayer then
              markerData.IsPlayerHere  = true;
            end
            local foundAnotherID:boolean = false;

            for _, playernumsID in pairs(markerData.PlayerNums) do
              if not foundAnotherID and playernumsID == anotherID then
                foundAnotherID = true;
              end
            end

            if not foundAnotherID then
              table.insert( markerData.PlayerNums, anotherID );
            end
          end
        end
      end
    end
  end

  return data;
end



-- ===========================================================================
function OnLocalPlayerTurnBegin()
  local ePlayer :number = Game.GetLocalPlayer();
  if ePlayer ~= -1 then
      --local kPlayer :table = Players[ePlayer];
      if m_ePlayer ~= ePlayer then
        m_ePlayer = ePlayer;
        m_kCurrentData = GetCurrentData( ePlayer );
      end

        --------------------------------------------------------------------------
        -- CQUI Check for Tech Progress

        -- Get the current tech
        local kPlayer   :table  = Players[ePlayer];
        local playerTechs :table  = kPlayer:GetTechs();
        local currentTechID :number = playerTechs:GetResearchingTech();
        local isCurrentBoosted :boolean = playerTechs:HasBoostBeenTriggered(currentTechID);

        -- Make sure there is a technology selected before continuing with checks
        if currentTechID ~= -1 then
          local techName = GameInfo.Technologies[currentTechID].Name;
          local techType = GameInfo.Technologies[currentTechID].Type;

          local currentCost         = playerTechs:GetResearchCost(currentTechID);
          local currentProgress     = playerTechs:GetResearchProgress(currentTechID);
          local currentYield          = playerTechs:GetScienceYield();
          local percentageToBeDone    = (currentProgress + currentYield) / currentCost;
          local percentageNextTurn    = (currentProgress + currentYield*2) / currentCost;
          local CQUI_halfway:number = 0.5;

          -- Finds boost amount, always 50 in base game, China's +10% modifier is not applied here
          for row in GameInfo.Boosts() do
            if(row.ResearchType == techType) then
              CQUI_halfway = (100 - row.Boost) / 100;
              break;
            end
          end
          --If playing as china, apply boost modifier. Not sure where I can query this value...
          if(PlayerConfigurations[Game.GetLocalPlayer()]:GetCivilizationTypeName() == "CIVILIZATION_CHINA") then
            CQUI_halfway = CQUI_halfway - .1;
          end

          -- Is it greater than 50% and has yet to be displayed?
          if isCurrentBoosted then
            CQUI_halfwayNotified[techName] = true;
          elseif percentageNextTurn >= CQUI_halfway and isCurrentBoosted == false and CQUI_halfwayNotified[techName] ~= true then
              LuaEvents.CQUI_AddStatusMessage(Locale.Lookup("LOC_CQUI_TECH_MESSAGE_S") .. " " .. Locale.Lookup( techName ) .. " " .. Locale.Lookup("LOC_CQUI_HALF_MESSAGE_E"), 10, CQUI_STATUS_MESSAGE_TECHS);
              CQUI_halfwayNotified[techName] = true;
          end

        end -- end of techID check

        --------------------------------------------------------------------------

    end -- end of playerID check

end

-- ===========================================================================
--  EVENT
--  Player turn is ending
-- ===========================================================================
function OnLocalPlayerTurnEnd()
  -- If current data set is for the player, save back any changes into
  -- the table of player tables.
  local ePlayer :number = Game.GetLocalPlayer();
  if ePlayer ~= -1 then
    if m_kCurrentData[DATA_FIELD_PLAYERINFO].Player == ePlayer then
      m_kAllPlayersTechData[ePlayer] = m_kCurrentData;
    end
  end

  if(GameConfiguration.IsHotseat()) then
    Close();
  end
end

-- ===========================================================================
function OnResearchChanged( ePlayer:number, eTech:number )

  if (m_ePlayer == -1) then return;  end      -- Autoplay support.

  -- Always refresh the live data for this tech in case it was boosted
  m_kCurrentData = GetCurrentData( m_ePlayer, -1 );

  if not ContextPtr:IsHidden() and ShouldUpdateWhenResearchChanges( m_ePlayer ) then
    View( m_kCurrentData );
  end
end

-- ===========================================================================
--  This function was separated so behavior can be modified in mods/expasions
-- ===========================================================================
function ShouldUpdateWhenResearchChanges(ePlayer)
  m_ePlayer = Game.GetLocalPlayer();
  return m_ePlayer == ePlayer;
end

-- ===========================================================================
function OnResearchComplete( ePlayer:number, eTech:number)
  if ePlayer == Game.GetLocalPlayer() then
    m_ePlayer = ePlayer;
    m_kCurrentData = GetCurrentData( m_ePlayer, eTech );
    if not ContextPtr:IsHidden() then
      View( m_kCurrentData );
    end


    --------------------------------------------------------------------------
        -- CQUI Completion Notification

        -- Get the current tech
        local kPlayer   :table      = Players[ePlayer];
        local currentTechID :number = eTech;

        -- Make sure there is a technology selected before continuing with checks
        if currentTechID ~= -1 then
          local techName = GameInfo.Technologies[currentTechID].Name;

          LuaEvents.CQUI_AddStatusMessage(Locale.Lookup("LOC_TECH_BOOST_COMPLETE", techName), 10, CQUI_STATUS_MESSAGE_TECHS);

        end -- end of techID check

        --------------------------------------------------------------------------

    -- CQUI update all cities real housing when play as India and researched Sanitation
    if eTech == GameInfo.Technologies["TECH_SANITATION"].Index then    -- Sanitation
      if (PlayerConfigurations[ePlayer]:GetCivilizationTypeName() == "CIVILIZATION_INDIA") then
        LuaEvents.CQUI_AllCitiesInfoUpdated(ePlayer);
      end
    -- CQUI update all cities real housing when play as Indonesia and researched Mass Production
    elseif eTech == GameInfo.Technologies["TECH_MASS_PRODUCTION"].Index then    -- Mass Production
      if (PlayerConfigurations[ePlayer]:GetCivilizationTypeName() == "CIVILIZATION_INDONESIA") then
        LuaEvents.CQUI_AllCitiesInfoUpdated(ePlayer);
      end
    end
  end
end

-- ===========================================================================
--  Initially size static UI elements
--  (or re-size if screen resolution changed)
-- ===========================================================================
function Resize()
  m_width, m_height  = UIManager:GetScreenSizeVal();    -- Cache screen dimensions
  m_scrollWidth    = m_width - 80;            -- Scrollbar area (where markers are placed) slightly smaller than screen width

  -- Determine how far art will span.
  -- First obtain the size of the tree by taking the visible size and multiplying it by the ratio of the full content
  local scrollPanelX:number = (Controls.NodeScroller:GetSizeX() / Controls.NodeScroller:GetRatio());

  local artAndEraScrollWidth:number = math.max( scrollPanelX * (1/PARALLAX_SPEED), m_width )
    + SIZE_ART_ERA_OFFSET_X
    + SIZE_ART_ERA_START_X;

  Controls.ArtParchmentDecoTop:SetSizeX( artAndEraScrollWidth );
  Controls.ArtParchmentDecoBottom:SetSizeX( artAndEraScrollWidth );
  Controls.ArtParchmentRippleTop:SetSizeX( artAndEraScrollWidth );
  Controls.ArtParchmentRippleBottom:SetSizeX( artAndEraScrollWidth );
  Controls.ForceSizeX:SetSizeX( artAndEraScrollWidth );
  Controls.ForceArtSizeX:SetSizeX( scrollPanelX * (1/PARALLAX_ART_SPEED) );
  Controls.LineForceSizeX:SetSizeX( scrollPanelX );
  Controls.LineScroller:CalculateSize();
  Controls.ArtScroller:CalculateSize();

  local backArtScrollWidth:number = scrollPanelX * (1/PARALLAX_ART_SPEED) + 100;
  Controls.Background:SetSizeX( math.max(backArtScrollWidth, m_width) );
  Controls.Background:SetSizeY( SIZE_WIDESCREEN_HEIGHT - (SIZE_TIMELINE_AREA_Y - 8) );
  Controls.EraArtScroller:CalculateSize();
end

-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string)
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end

-- ===========================================================================
--  Obtain the data from the DB that doesn't change
--  Base costs and relationships (prerequisites)
--  RETURN: A table of node data (techs/civics/etc...) with a prereq for each entry.
-- ===========================================================================
function PopulateItemData( tableName:string, tableColumn:string, prereqTableName:string, itemColumn:string, prereqColumn:string)

  local kItemDefaults :table = {};    -- Table to return

  function GetHash(t)
    local r = GameInfo.Types[t];
    if(r) then
      return r.Hash;
    else
      return 0;
    end
  end

  for row:table in GameInfo[tableName]() do

    local kEntry:table  = {};
    kEntry.Type      = row[tableColumn];
    kEntry.Name      = row.Name;
    kEntry.BoostText  = "";
    kEntry.Column    = -1;
    kEntry.Cost      = row.Cost;
    kEntry.Description  = row.Description and Locale.Lookup( row.Description );
    kEntry.EraType    = row.EraType;
    kEntry.Hash      = GetHash(kEntry.Type);
    kEntry.Index    = row.Index;
    kEntry.IsBoostable  = false;
    kEntry.Prereqs    = {};        -- IDs for prerequisite item(s)
    kEntry.UITreeRow  = row.UITreeRow;
    kEntry.Unlocks    = {};        -- Each unlock has: unlockType, iconUnavail, iconAvail, tooltip

    -- Only add if not debugging or in debug range.
    if  (table.count(debugExplicitList) == 0 and debugFilterTechMaxIndex ==-1 ) or
      (table.count(debugExplicitList) == 0 and kEntry.Index < debugFilterTechMaxIndex) or
      (table.count(debugExplicitList) ~= 0 and debugExplicitList[kEntry.Index ] ~= nil)  then

      -- Boost?
      for boostRow in GameInfo.Boosts() do
        if boostRow.TechnologyType == kEntry.Type then
          kEntry.BoostText = Locale.Lookup( boostRow.TriggerDescription );
          kEntry.IsBoostable = true;
          kEntry.BoostAmount = boostRow.Boost;
          break;
        end
      end

      for prereqRow in GameInfo[prereqTableName]() do
        if prereqRow[itemColumn] == kEntry.Type then
          table.insert( kEntry.Prereqs, prereqRow[prereqColumn] );
        end
      end
      -- If no prereqs were found, set item to special tree start value
      if table.count(kEntry.Prereqs) == 0 then
        table.insert(kEntry.Prereqs, PREREQ_ID_TREE_START);
      end

      -- Warn if DB has an out of bounds entry.
      if kEntry.UITreeRow < ROW_MIN or kEntry.UITreeRow > ROW_MAX then
        UI.DataError("UITreeRow for '"..kEntry.Type.."' has an out of bound UITreeRow="..tostring(kEntry.UITreeRow).."  MIN="..tostring(ROW_MIN).."  MAX="..tostring(ROW_MAX));
      end

      AddTechToEra( kEntry );

      -- Save entry into master list.
      kItemDefaults[kEntry.Type] = kEntry;
    end
  end

  return kItemDefaults;
end


-- ===========================================================================
--  Create a hash table of EraType to its chronological index.
-- ===========================================================================
function PopulateEraData()
  g_kEras = {};
  for row:table in GameInfo.Eras() do
    if m_kEraCounter[row.EraType] and m_kEraCounter[row.EraType] > 0 and debugFilterEraMaxIndex < 1 or row.ChronologyIndex <= debugFilterEraMaxIndex then
      table.insert(g_kEras, {
        EraType    = row.EraType,
        BGTexture  = row.EraTechBackgroundTexture,
        Description  = Locale.Lookup(row.Name),
        NumColumns  = 0,
        ChronologyIndex = row.ChronologyIndex,
        Index    = -1,
        PriorColumns= -1,
        Columns    = {},    -- column data
        TechTreeLayoutMethod= (row.TechTreeLayoutMethod ~= nil) and row.TechTreeLayoutMethod or ""    -- how to layout nodes within era: "Cost" (default), "Prereq"
      });
    end
  end

  -- Correctly assign the index to be the index of the era sorted by chronology index.
  -- Also index
  table.sort(g_kEras, function(a,b) return a.ChronologyIndex < b.ChronologyIndex; end);
  for i,v in ipairs(g_kEras) do
    v.Index = i - 1 ; -- 0-based indexing.
    g_kEras[v.EraType] = v;
  end
end


-- ===========================================================================
--
-- ===========================================================================
function PopulateFilterData()

  -- Hard coded/special filters:

  -- Load entried into filter table from TechFilters XML data
  --[[ TODO: Only add filters based on what is in the game database. ??TRON
  for row in GameInfo.TechFilters() do
    table.insert( m_kFilters, { row.IconString, row.Description, g_TechFilters[row.Type] });
  end
  ]]
  m_kFilters = {};
  table.insert( m_kFilters, { Func=nil,                    Description="LOC_TECH_FILTER_NONE",      Icon=nil } );
  --table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_RECOMMENDED"],  Description="LOC_TECH_FILTER_RECOMMENDED",  Icon="[ICON_Recommended]" });
  table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_FOOD"],      Description="LOC_TECH_FILTER_FOOD",      Icon="[ICON_Food]" });
  table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_SCIENCE"],    Description="LOC_TECH_FILTER_SCIENCE",    Icon="[ICON_Science]" });
  table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_PRODUCTION"],  Description="LOC_TECH_FILTER_PRODUCTION",  Icon="[ICON_Production]" });
  table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_CULTURE"],    Description="LOC_TECH_FILTER_CULTURE",    Icon="[ICON_Culture]" });
  table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_GOLD"],      Description="LOC_TECH_FILTER_GOLD",      Icon="[ICON_Gold]" });
  table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_FAITH"],      Description="LOC_TECH_FILTER_FAITH",    Icon="[ICON_Faith]" });
  table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_HOUSING"],    Description="LOC_TECH_FILTER_HOUSING",    Icon="[ICON_Housing]" });
  --table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_AMENITIES"],  Description="LOC_TECH_FILTER_AMENITIES",  Icon="[ICON_Amenities]" });
  --table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_HEALTH"],    Description="LOC_TECH_FILTER_HEALTH",    Icon="[ICON_Health]" });
  table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_UNITS"],      Description="LOC_TECH_FILTER_UNITS",    Icon="[ICON_Units]" });
  table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_IMPROVEMENTS"],  Description="LOC_TECH_FILTER_IMPROVEMENTS",  Icon="[ICON_Improvements]" });
  table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_WONDERS"],    Description="LOC_TECH_FILTER_WONDERS",    Icon="[ICON_Wonders]" });

  for i,filter in ipairs(m_kFilters) do
    local filterLabel   = Locale.Lookup( filter.Description );
    local filterIconText = filter.Icon;

    local controlTable   = {};
    Controls.FilterPulldown:BuildEntry( "FilterItemInstance", controlTable );

    -- If a text icon exists, use it and bump the label in the button over.
    --[[ TODO: Uncomment if icons are added.
    if filterIconText ~= nil and filterIconText ~= "" then
      controlTable.IconText:SetText( Locale.Lookup(filterIconText) );
      controlTable.DescriptionText:SetOffsetX(24);
    else
      controlTable.IconText:SetText( "" );
      controlTable.DescriptionText:SetOffsetX(4);
    end
    ]]
    controlTable.DescriptionText:SetOffsetX(8);
    controlTable.DescriptionText:SetText( filterLabel );

    -- Callback
    controlTable.Button:RegisterCallback( Mouse.eLClick,  function() OnFilterClicked(filter); end );

  end
  Controls.FilterPulldown:CalculateInternals();
end

-- ===========================================================================
-- Populate Full Text Search
-- ===========================================================================
function PopulateSearchData()
  -- Populate Full Text Search
  local searchContext = "Technologies";
  if(Search.CreateContext(searchContext, "[COLOR_LIGHTBLUE]", "[ENDCOLOR]", "...")) then

    -- Hash modifier types that grant envoys or spies.
    local envoyModifierTypes = {};
    local spyModifierTypes = {};

    for row in GameInfo.DynamicModifiers() do
      local effect = row.EffectType;
      if(effect == "EFFECT_GRANT_INFLUENCE_TOKEN") then
        envoyModifierTypes[row.ModifierType] = true;
      elseif(effect == "EFFECT_GRANT_SPY") then
        spyModifierTypes[row.ModifierType] = true;
      end
    end

    -- Hash tech types that grant envoys or spies via modifiers.
    local envoyTechs = {};
    local spyTechs = {};
    for row in GameInfo.TechnologyModifiers() do
      local modifier = GameInfo.Modifiers[row.ModifierId];
      if(modifier) then
        local modifierType = modifier.ModifierType;
        if(envoyModifierTypes[modifierType]) then
          envoyTechs[row.TechnologyType] = true;
        end

        if(spyModifierTypes[modifierType]) then
          spyTechs[row.TechnologyType] = true;
        end
      end
    end

    local envoyTypeName = Locale.Lookup("LOC_ENVOY_NAME");
    local spyTypeName = Locale.Lookup("LOC_SPY_NAME");

    for row in GameInfo.Technologies() do
      local techType = row.TechnologyType;
      local description = row.Description and Locale.Lookup(row.Description) or "";
      local tags = {};
      if(envoyTechs[techType]) then
        table.insert(tags, envoyTypeName);
      end

      if(spyTechs[techType]) then
        table.insert(tags, spyTypeName);
      end

      Search.AddData(searchContext, row.TechnologyType, Locale.Lookup(row.Name), description, tags);
    end

    local buildingType = Locale.Lookup("LOC_BUILDING_NAME");
    local wonderTypeName = Locale.Lookup("LOC_WONDER_NAME");
    for row in GameInfo.Buildings() do
      if(row.PrereqTech) then
        local tags = {buildingTypeName};
        if(row.IsWonder) then
          table.insert(tags, wonderTypeName);
        end
        Search.AddData(searchContext, row.PrereqTech, Locale.Lookup(GameInfo.Technologies[row.PrereqTech].Name), Locale.Lookup(row.Name), tags);
      end
    end

    local districtType = Locale.Lookup("LOC_DISTRICT_NAME");
    for row in GameInfo.Districts() do
      if(row.PrereqTech) then
        Search.AddData(searchContext, row.PrereqTech, Locale.Lookup(GameInfo.Technologies[row.PrereqTech].Name), Locale.Lookup(row.Name), { districtType });
      end
    end

    local improvementType = Locale.Lookup("LOC_IMPROVEMENT_NAME");
    for row in GameInfo.Improvements() do
      if(row.PrereqTech) then
        Search.AddData(searchContext, row.PrereqTech, Locale.Lookup(GameInfo.Technologies[row.PrereqTech].Name), Locale.Lookup(row.Name), { improvementType });
      end
    end

    local projectType = Locale.Lookup("LOC_PROJECT_NAME");
    for row in GameInfo.Projects() do
      if(row.PrereqTech) then
        Search.AddData(searchContext, row.PrereqTech, Locale.Lookup(GameInfo.Technologies[row.PrereqTech].Name), Locale.Lookup(row.Name), { projectType });
      end
    end

    local resourceType = Locale.Lookup("LOC_RESOURCE_NAME");
    for row in GameInfo.Resources() do
      if(row.PrereqTech) then
        Search.AddData(searchContext, row.PrereqTech, Locale.Lookup(GameInfo.Technologies[row.PrereqTech].Name), Locale.Lookup(row.Name), { resourceType });
      end
    end

    local unitType = Locale.Lookup("LOC_UNIT_NAME");
    for row in GameInfo.Units() do
      if(row.PrereqTech) then
        Search.AddData(searchContext, row.PrereqTech, Locale.Lookup(GameInfo.Technologies[row.PrereqTech].Name), Locale.Lookup(row.Name), { unitType });
      end
    end

    Search.Optimize(searchContext);
  end
end

-- ===========================================================================
-- Update the Filter text with the current label.
-- ===========================================================================
function RealizeFilterPulldown()
  local pullDownButton = Controls.FilterPulldown:GetButton();
  if m_kCurrentData[DATA_FIELD_UIOPTIONS].filter == nil or m_kCurrentData[DATA_FIELD_UIOPTIONS].filter.Func== nil then
    pullDownButton:SetText( "  "..Locale.Lookup("LOC_TREE_FILTER_W_DOTS"));
  else
    local description:string = m_kCurrentData[DATA_FIELD_UIOPTIONS].filter.Description;
    pullDownButton:SetText( "  "..Locale.Lookup( description ));
  end
end

-- ===========================================================================
--  filterLabel,  Readable lable of the current filter.
--  filterFunc,    The funciton filter to apply to each node as it's built,
--          nil will reset the filters to none.
-- ===========================================================================
function OnFilterClicked( filter )
  m_kCurrentData[DATA_FIELD_UIOPTIONS].filter = filter;
  View( m_kCurrentData )
end

-- ===========================================================================
function OnOpen()
  if (Game.GetLocalPlayer() == -1) then
    return
  end

  UI.PlaySound("UI_Screen_Open");
  View( m_kCurrentData );
  ContextPtr:SetHide(false);

  -- Adjust size of backing using values from ModalScreen_PlayerYieldsHelper
  if not RefreshYields() then
    Controls.Vignette:SetSizeY( m_TopPanelConsideredHeight );
  end

  -- From Civ6_styles: FullScreenVignetteConsumer
  Controls.ScreenAnimIn:SetToBeginning();
  Controls.ScreenAnimIn:Play();

  LuaEvents.TechTree_OpenTechTree();
end

-- ===========================================================================
--  Show the Key panel based on the state
-- ===========================================================================
function RealizeKeyPanel()
  if UserConfiguration.GetShowTechTreeKey() then
    Controls.KeyPanel:SetHide( false );
  else
    if(not ContextPtr:IsHidden()) then
            Controls.KeyPanel:SetHide( true );
        end
  end

  if Controls.KeyPanel:IsHidden() then
    Controls.ToggleKeyButton:SetText(Locale.Lookup("LOC_TREE_SHOW_KEY"));
    Controls.ToggleKeyButton:SetSelected(false);
  else
    Controls.ToggleKeyButton:SetText(Locale.Lookup("LOC_TREE_HIDE_KEY"));
    Controls.ToggleKeyButton:SetSelected(true);
  end
end

-- ===========================================================================
--  Reparents all tutorial controls, guarantee they will be on top of the
--  nodes and lines dynamically added.
-- ===========================================================================
function RealizeTutorialNodes()
  Controls.CompletedTechNodePointer:Reparent();
  Controls.IncompleteTechNodePointer:Reparent();
  Controls.UnavailableTechNodePointer:Reparent();
  Controls.ChooseWritingPointer:Reparent();
  Controls.ActiveTechNodePointer:Reparent();
  Controls.TechUnlocksPointer:Reparent();
end

-- ===========================================================================
--  Show/Hide key panel
-- ===========================================================================
function OnClickToggleKey()
  if Controls.KeyPanel:IsHidden() then
    UserConfiguration.SetShowTechTreeKey(true);
  else
    UserConfiguration.SetShowTechTreeKey(false);
  end
  RealizeKeyPanel();
end

-- ===========================================================================
function OnClickFiltersPulldown()
  if Controls.FilterPulldown:IsOpen() then
    UI.PlaySound("UI_TechTree_Filter_Open");
  else
    UI.PlaySound("UI_TechTree_Filter_Closed");
  end
end

-- ===========================================================================
--  Main close function all exit points should call.
-- ===========================================================================
function Close()
  if not ContextPtr:IsHidden() then
    UI.PlaySound("UI_Screen_Close");
  end

  ContextPtr:SetHide(true);
  LuaEvents.TechTree_CloseTechTree();
  Controls.SearchResultsPanelContainer:SetHide(true);
end
-- ===========================================================================
--  Close via click
-- ===========================================================================
function OnClose()
  Close();
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
    -- Don't let enter propigate or it will hit action panel which will raise a screen (potentially this one again) tied to the action.
    return true;
  end
    return false;
end
function OnInputHandler( pInputStruct:table )
  local uiMsg = pInputStruct:GetMessageType();
  if uiMsg == KeyEvents.KeyDown then return KeyDownHandler( pInputStruct:GetKey() ); end
  if uiMsg == KeyEvents.KeyUp then return KeyUpHandler( pInputStruct:GetKey() ); end
  return false;
end

-- ===========================================================================
--  UI Event Handler
-- ===========================================================================
function OnShutdown()
  -- Clean up events
  LuaEvents.LaunchBar_CloseTechTree.Remove( OnClose );
  LuaEvents.LaunchBar_RaiseTechTree.Remove( OnOpen );
  LuaEvents.ResearchChooser_RaiseTechTree.Remove( OnOpen );
  LuaEvents.Tutorial_TechTreeScrollToNode.Remove( OnTutorialScrollToNode );

  Events.LocalPlayerTurnBegin.Remove( OnLocalPlayerTurnBegin );
  Events.LocalPlayerTurnEnd.Remove( OnLocalPlayerTurnEnd );
  Events.ResearchChanged.Remove( OnResearchChanged );
  Events.ResearchQueueChanged.Remove( OnResearchChanged );
  Events.ResearchCompleted.Remove( OnResearchComplete );
  Events.SystemUpdateUI.Remove( OnUpdateUI );

  Search.DestroyContext("Technologies");
end

-- ===========================================================================
--  Centers scroll panel (if possible) on a specfic type.
-- ===========================================================================
function ScrollToNode( typeName:string )
  local percent:number = 0;
  local x    = g_uiNodes[typeName].x - ( m_width * 0.5);
  local size  = (m_width / Controls.NodeScroller:GetRatio()) - m_width;
  percent = math.clamp( x  / size, 0, 1);
  Controls.NodeScroller:SetScrollValue(percent);
  m_kSearchResultIM:DestroyInstances();
  Controls.SearchResultsPanelContainer:SetHide(true);
end

-- ===========================================================================
--  LuaEvent
-- ===========================================================================
function OnTutorialScrollToNode( typeName:string )
  ScrollToNode( typeName );
end

-- ===========================================================================
--  Searching
-- ===========================================================================
function OnSearchCharCallback()
  local str = Controls.SearchEditBox:GetText();

  local defaultText = Locale.Lookup("LOC_TREE_SEARCH_W_DOTS")
  if(str == defaultText) then
    -- We cannot immediately clear the results..
    -- When the edit box loses focus, it resets the text which triggers this call back.
    -- if the user is in the process of clicking a result, wiping the results in this callback will make the user
    -- click whatever was underneath.
    -- Instead, trigger a timer will wipe the results.
    Controls.SearchResultsTimer:SetToBeginning();
    Controls.SearchResultsTimer:Play();

  elseif(str == nil or #str == 0) then
    -- Clear results.
    m_kSearchResultIM:DestroyInstances();
    Controls.SearchResultsStack:CalculateSize();
    Controls.SearchResultsPanel:CalculateSize();
    Controls.SearchResultsPanelContainer:SetHide(true);

  elseif(str and #str > 0) then
    local hasResults :boolean = false;
    m_kSearchResultIM:DestroyInstances();
    local results = Search.Search("Technologies", str, 100);
    if (results and #results > 0) then
      hasResults = true;
      local has_found = {};
      for i, v in ipairs(results) do
        -- v[1] == Type
        -- v[2] == Name w/ search term highlighted.
        -- v[3] == Snippet description w/ search term highlighted.
        local techType = v[1];
        if has_found[techType] == nil and IsSearchable(techType) then
          local instance = m_kSearchResultIM:GetInstance();

          -- Search results already localized.
          local name = v[2];
          instance.Name:SetText(name);
          local iconName = DATA_ICON_PREFIX .. techType;
          instance.SearchIcon:SetIcon(iconName);

          instance.Button:RegisterCallback(Mouse.eLClick, function()
            Controls.SearchEditBox:SetText(defaultText);
            ScrollToNode(techType);
          end);

          instance.Button:SetToolTipString(ToolTipHelper.GetToolTip(techType, Game.GetLocalPlayer()));

          has_found[techType] = true;
        end
      end
    end

    Controls.SearchResultsStack:CalculateSize();
    Controls.SearchResultsPanel:CalculateSize();
    Controls.SearchResultsPanelContainer:SetHide(not hasResults);
  end
end

-- ===========================================================================
--  Can a tech be searched.
--  Always true in base game, but may be overridden by a MOD.
-- ===========================================================================
function IsSearchable(techType)
  return true;
end

function OnSearchCommitCallback()
  local str = Controls.SearchEditBox:GetText();

  local defaultText = Locale.Lookup("LOC_TREE_SEARCH_W_DOTS")
  if(str and #str > 0 and str ~= defaultText) then
    local results = Search.Search("Technologies", str, 1);
    if (results and #results > 0) then
      local result = results[1];
      if(result) then
        ScrollToNode(result[1]);
      end
    end

    Controls.SearchEditBox:SetText(defaultText);
  end
end

-- ===========================================================================
function OnSearchBarGainFocus()
  Controls.SearchResultsTimer:Stop();
  Controls.SearchEditBox:ClearString();
end

-- ===========================================================================
function OnSearchBarLoseFocus()
  Controls.SearchEditBox:SetText(Locale.Lookup("LOC_TREE_SEARCH_W_DOTS"));
end

-- ===========================================================================
function OnSearchResultsTimerEnd()
  m_kSearchResultIM:DestroyInstances();
  Controls.SearchResultsStack:CalculateSize();
  Controls.SearchResultsPanel:CalculateSize();
  Controls.SearchResultsPanelContainer:SetHide(true);
end

-- ===========================================================================
function OnSearchResultsPanelContainerMouseEnter()
  Controls.SearchResultsTimer:Stop();
end

-- ===========================================================================
function OnSearchResultsPanelContainerMouseExit()
  if(not Controls.SearchEditBox:HasFocus()) then
    Controls.SearchResultsTimer:SetToBeginning();
    Controls.SearchResultsTimer:Play();
  end
end


-- ===========================================================================
function BuildTree()
  local kNodeGrid  :table = nil;
  local kPaths  :table = nil;      -- Recommended line pathing
  kNodeGrid, kPaths = LayoutNodeGrid();  -- Layout nodes.
  AllocateUI( kNodeGrid, kPaths );
end


-- ===========================================================================
--  Initialize after the context is loaded
--  MODDERS:  If you need to change how the tech tree inits, this is a great
--        place to do it.
-- ===========================================================================
function LateInitialize()
  -- Obtain the data
  g_kItemDefaults = PopulateItemData("Technologies","TechnologyType","TechnologyPrereqs","Technology","PrereqTech");
  PopulateEraData();
  PopulateFilterData();
  PopulateSearchData();
  BuildTree();

  -- May be observation mode.
  m_ePlayer = Game.GetLocalPlayer();
  if (m_ePlayer == -1) then
    return;
  end

  -- Realize dynamic UI.
  Resize();
  m_kCurrentData = GetCurrentData( m_ePlayer );
  View( m_kCurrentData );
end


-- ===========================================================================
--  Load all static information as well as display information for the
--  current local player.
-- ===========================================================================
function OnInit( isReload:boolean )
  LateInitialize();
end


-- ===========================================================================
--  Setup callbacks, do NOT setup static information until the context is
--  loaded so that any replacement files get a
-- ===========================================================================
function Initialize()
  --profile.runtime("start");

  -- Debug: convert numbered list above to key indexes.
  if debugExplicitList == nil then debugExplicitList = {} end
  if table.count(debugExplicitList) ~= 0 then
    local temp:table = {};
    for i,v in ipairs(debugExplicitList) do
      temp[v] = true;
    end
    debugExplicitList = temp;
  end

  -- UI Events
  ContextPtr:SetInitHandler( OnInit );
  ContextPtr:SetInputHandler( OnInputHandler, true );
  ContextPtr:SetShutdown( OnShutdown );
  Controls.FilterPulldown:GetButton():RegisterCallback( Mouse.eLClick, OnClickFiltersPulldown );
  Controls.FilterPulldown:RegisterSelectionCallback( OnClickFiltersPulldown );
  Controls.SearchEditBox:RegisterStringChangedCallback(OnSearchCharCallback);
  Controls.SearchEditBox:RegisterHasFocusCallback( OnSearchBarGainFocus);
  Controls.SearchEditBox:RegisterCommitCallback( OnSearchBarLoseFocus);
  Controls.SearchResultsTimer:RegisterEndCallback(OnSearchResultsTimerEnd);
  Controls.SearchResultsPanelContainer:RegisterMouseEnterCallback(OnSearchResultsPanelContainerMouseEnter);
  Controls.SearchResultsPanelContainer:RegisterMouseExitCallback(OnSearchResultsPanelContainerMouseExit);
  Controls.ToggleKeyButton:RegisterCallback(Mouse.eLClick, OnClickToggleKey);

  -- LUA Events
  LuaEvents.LaunchBar_CloseTechTree.Add( OnClose );
  LuaEvents.LaunchBar_RaiseTechTree.Add( OnOpen );
  LuaEvents.ResearchChooser_RaiseTechTree.Add( OnOpen );
  LuaEvents.Tutorial_TechTreeScrollToNode.Add( OnTutorialScrollToNode );

  -- Game engine Event
  Events.LocalPlayerTurnBegin.Add( OnLocalPlayerTurnBegin );
  Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );
  Events.LocalPlayerChanged.Add( BuildTree );
  Events.ResearchChanged.Add( OnResearchChanged );
  Events.ResearchQueueChanged.Add( OnResearchChanged );
  Events.ResearchCompleted.Add( OnResearchComplete );
  Events.SystemUpdateUI.Add( OnUpdateUI );

  -- Key Label Truncation to Tooltip
  TruncateStringWithTooltip(Controls.AvailableLabelKey, MAX_BEFORE_TRUNC_KEY_LABEL, Controls.AvailableLabelKey:GetText());
  TruncateStringWithTooltip(Controls.UnavailableLabelKey, MAX_BEFORE_TRUNC_KEY_LABEL, Controls.UnavailableLabelKey:GetText());
  TruncateStringWithTooltip(Controls.ResearchingLabelKey, MAX_BEFORE_TRUNC_KEY_LABEL, Controls.ResearchingLabelKey:GetText());
  TruncateStringWithTooltip(Controls.CompletedLabelKey, MAX_BEFORE_TRUNC_KEY_LABEL, Controls.CompletedLabelKey:GetText());

  m_TopPanelConsideredHeight = Controls.Vignette:GetSizeY() - TOP_PANEL_OFFSET;

  -- CQUI add exceptions to the 50% notifications by putting techs into the CQUI_halfwayNotified table
  CQUI_halfwayNotified["LOC_TECH_POTTERY_NAME"] = true;
  CQUI_halfwayNotified["LOC_TECH_MINING_NAME"] = true;
  CQUI_halfwayNotified["LOC_TECH_ANIMAL_HUSBANDRY_NAME"] = true;
end

if HasCapability("CAPABILITY_TECH_TREE") then
  Initialize();
end
