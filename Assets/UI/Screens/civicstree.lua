-- ===========================================================================
--  CivicsTree
--  Tabs set to 4 spaces retaining tab.
--
--  Items exist in one of 7 "rows" that span horizontally and within a
--  "column" based on the era and cost.
--
--  Rows    Start   Eras->
--  -3               _____        _____
--  -2            /-|_____|----/-|_____|
--  -1            |  _____     |       Nodes
--  0        O----%-|_____|----'
--  1
--  2
--  3
--
-- ===========================================================================

-- Include self contained additional tabs
g_ExtraIconData = {};
include("CivicsTreeIconLoader_", true);

include( "InstanceManager" );
include( "SupportFunctions" );
include( "Civ6Common" );      -- Tutorial check support
include( "TechAndCivicSupport" );
include( "TechFilterFunctions" );
include( "ModalScreen_PlayerYieldsHelper" );
include( "GameCapabilities" );

-- ===========================================================================
--  DEBUG
--  Toggle these for temporary debugging help.
-- ===========================================================================
local m_debugFilterEraMaxIndex  :number = -1;   -- (-1 default) Only load up to a specific ERA (Value less than 1 to disable)
local m_debugOutputCivicInfo		:boolean= false;	-- (false default) Send to console detailed information on tech? 
local m_debugShowIDWithName   :boolean= false;  -- (false default) Show the ID before the name in each node.
local m_debugShowAllMarkers   :boolean= false;  -- (false default) Show all player markers in the timline; even if they haven't been met.


-- ===========================================================================
--  CONSTANTS
-- ===========================================================================

-- Spacing / Positioning Constants
local COLUMN_WIDTH					:number = 250;			-- Space of node and line(s) after it to the next node
local COLUMNS_NODES_SPAN			:number = 2;			-- How many colunms do the nodes span
local PADDING_TIMELINE_LEFT			:number = 225;
local PADDING_FIRST_ERA_INDICATOR	:number = 60;

-- Graphic constants
local PIC_BOLT_OFF        :string = "Controls_BoltOff";
local PIC_BOLT_ON       :string = "Controls_BoltOn";
local PIC_BOOST_OFF       :string = "BoostTech";
local PIC_BOOST_ON        :string = "BoostTechOn";
local PIC_DEFAULT_ERA_BACKGROUND:string = "CivicsTree_BGAncient";
local PIC_MARKER_PLAYER     :string = "Tree_TimePipPlayer";
local PIC_MARKER_OTHER      :string = "Controls_TimePip";
local PIC_METER_BACK      :string = "Tree_Meter_GearBack";
local PIC_METER_BACK_DONE   :string = "TechTree_Meter_Done";
local SIZE_ART_ERA_OFFSET_X   :number = 40;     -- How far to push each era marker
local SIZE_ART_ERA_START_X    :number = 40;     -- How far to set the first era marker
local SIZE_GOVTPANEL_HEIGHT     :number = 220;
local SIZE_MARKER_PLAYER_X    :number = 42;      -- Marker of player
local SIZE_MARKER_PLAYER_Y    :number = 42;     -- "
local SIZE_MARKER_OTHER_X   :number = 34;     -- Marker of other players
local SIZE_MARKER_OTHER_Y   :number = 37;     -- "
local SIZE_NODE_X				:number = 420;			-- Item node dimensions
local SIZE_NODE_Y       :number = 84;
local SIZE_NODE_LARGE_Y     :number = 140;        -- "
local SIZE_OPTIONS_X      :number = 200;
local SIZE_OPTIONS_Y      :number = 150;
local SIZE_PATH         :number = 40;
local SIZE_PATH_HALF      :number = 20;
local SIZE_TIMELINE_AREA_Y    :number = 41;
local SIZE_TOP_AREA_Y     :number = 60;
local SIZE_WIDESCREEN_HEIGHT  :number = 768;

local PATH_MARKER_OFFSET_X      :number = 20;
local PATH_MARKER_OFFSET_Y      :number = 50;
local PATH_MARKER_NUMBER_0_9_OFFSET :number = 20;
local PATH_MARKER_NUMBER_10_OFFSET  :number = 15;

-- Other constants
local DATA_FIELD_GOVERNMENT     :string = "_GOVERNMENT"; --holds players govt and policies
local DATA_FIELD_LIVEDATA   :string = "_LIVEDATA";  -- The current status of an item.
local DATA_FIELD_PLAYERINFO   :string = "_PLAYERINFO";-- Holds a table with summary information on that player.
local DATA_FIELD_UIOPTIONS    :string = "_UIOPTIONS"; -- What options the player has selected for this screen.
local DATA_ICON_PREFIX      :string = "ICON_";
local DATA_ICON_UNAVAILABLE     :string = "_FOW";
local ITEM_STATUS       :table  = {
                  BLOCKED   = 1,
                  READY   = 2,
                  CURRENT   = 3,
                  RESEARCHED  = 4,
                };
local LINE_LENGTH_BEFORE_CURVE    :number = 20;     -- How long to make a line before a node before it curves
local LINE_VERTICAL_OFFSET      :number = 0;
local PADDING_NODE_STACK_Y      :number = 20;
local PARALLAX_SPEED        :number = 1.1;      -- Speed for how much slower background moves (1.0=regular speed, 0.5=half speed)
local PARALLAX_ART_SPEED      :number = 1.2;      -- Speed for how much slower background moves (1.0=regular speed, 0.5=half speed)
local PREREQ_ID_TREE_START      :string = "_TREESTART"; -- Made up, unique value, to mark a non-node tree start
local ROW_MAX           :number = 3;      -- Highest level row above 0
local ROW_MIN           :number = -3;     -- Lowest level row below 0
local STATUS_ART          :table  = {};
local STATUS_ART_LARGE        :table  = {};
local TREE_START_ROW        :number = -999;     -- Which virtual "row" does tree start on? (or -999 for first node)
local TREE_START_COLUMN       :number = 0;      -- Which virtual "column" does tree start on? (Can be negative!)
local TREE_START_NONE_ID      :number = -999;     -- Special, unique value, to mark no special tree start node.
local TXT_BOOSTED         :string = Locale.Lookup("LOC_BOOST_BOOSTED");
local TXT_TO_BOOST          :string = Locale.Lookup("LOC_BOOST_TO_BOOST");
local VERTICAL_CENTER       :number = (SIZE_NODE_Y) / 2;
local MAX_BEFORE_TRUNC_GOV_TITLE  :number = 165;
local MAX_BEFORE_TRUNC_TO_BOOST   :number = 335;

-- CQUI CONSTANTS
local CQUI_STATUS_MESSAGE_CIVIC          :number = 3;    -- Number to distinguish civic messages

STATUS_ART[ITEM_STATUS.BLOCKED]   = { Name="BLOCKED",   TextColor0=0xff202726, TextColor1=0x00000000, FillTexture="CivicsTree_GearButtonTile_Disabled.dds",BGU=0,BGV=(SIZE_NODE_Y*3), HideIcon=true,  IsButton=false, BoltOn=false, IconBacking=PIC_METER_BACK };
STATUS_ART[ITEM_STATUS.READY]   = { Name="READY",   TextColor0=0xaaffffff, TextColor1=0x88000000, FillTexture=nil,                  BGU=0,BGV=0,          HideIcon=true,  IsButton=true,  BoltOn=false, IconBacking=PIC_METER_BACK  };
STATUS_ART[ITEM_STATUS.CURRENT]   = { Name="CURRENT",   TextColor0=0xaaffffff, TextColor1=0x88000000, FillTexture=nil,                  BGU=0,BGV=(SIZE_NODE_Y*4),    HideIcon=false,  IsButton=false,  BoltOn=true,  IconBacking=PIC_METER_BACK };
STATUS_ART[ITEM_STATUS.RESEARCHED]  = { Name="RESEARCHED",  TextColor0=0xaaffffff, TextColor1=0x88000000, FillTexture="CivicsTree_GearButtonTile_Done.dds", BGU=0,BGV=(SIZE_NODE_Y*5),    HideIcon=false,  IsButton=false,  BoltOn=true,  IconBacking=PIC_METER_BACK_DONE  };


STATUS_ART_LARGE[ITEM_STATUS.BLOCKED]   = { Name="LARGEBLOCKED",  TextColor0=0xff202726, TextColor1=0x00000000, FillTexture="CivicsTree_GearButton2Tile_Disabled.dds",BGU=0,BGV=(SIZE_NODE_LARGE_Y*3),  HideIcon=true,  IsButton=false, BoltOn=false, IconBacking=PIC_METER_BACK };
STATUS_ART_LARGE[ITEM_STATUS.READY]     = { Name="LARGEREADY",    TextColor0=0xaaffffff, TextColor1=0x88000000, FillTexture=nil,                    BGU=0,BGV=0,            HideIcon=true,  IsButton=true,  BoltOn=false, IconBacking=PIC_METER_BACK  };
STATUS_ART_LARGE[ITEM_STATUS.CURRENT]   = { Name="LARGECURRENT",  TextColor0=0xaaffffff, TextColor1=0x88000000, FillTexture=nil,                    BGU=0,BGV=(SIZE_NODE_LARGE_Y*4),  HideIcon=false,  IsButton=false,  BoltOn=true,  IconBacking=PIC_METER_BACK };
STATUS_ART_LARGE[ITEM_STATUS.RESEARCHED]  = { Name="LARGERESEARCHED", TextColor0=0xaaffffff, TextColor1=0x88000000, FillTexture="CivicsTree_GearButton2Tile_Completed.dds", BGU=0,BGV=(SIZE_NODE_LARGE_Y*5),HideIcon=false,   IsButton=false, BoltOn=true,  IconBacking=PIC_METER_BACK_DONE  };


-- ===========================================================================
--  MEMBERS / VARIABLES
-- ===========================================================================
local m_kNodeIM       :table = InstanceManager:new( "NodeInstance",       "Top",    Controls.NodeScroller );
local m_kLargeNodeIM    :table = InstanceManager:new( "LargeNodeInstance",    "Top",    Controls.NodeScroller );
local m_kLineIM       :table = InstanceManager:new( "LineImageInstance",    "LineImage",Controls.NodeScroller );
local m_kEraArtIM     :table = InstanceManager:new( "EraArtInstance",     "Top",    Controls.FarBackArtScroller );
local m_kEraLabelIM     :table = InstanceManager:new( "EraLabelInstance",     "Top",    Controls.ArtScroller );
local m_kEraDotIM     :table = InstanceManager:new( "EraDotInstance",     "Dot",    Controls.ScrollbarBackgroundArt );
local m_kMarkerIM     :table = InstanceManager:new( "PlayerMarkerInstance", "Top",    Controls.TimelineScrollbar );
local m_kSearchResultIM   :table = InstanceManager:new( "SearchResultInstance",   "Root",     Controls.SearchResultsStack);

local m_kDiplomaticPolicyIM :table = InstanceManager:new( "DiplomaticPolicyInstance",   "DiplomaticPolicy",   Controls.DiplomaticStack );
local m_kEconomicPolicyIM :table = InstanceManager:new( "EconomicPolicyInstance",   "EconomicPolicy",   Controls.EconomicStack );
local m_kMilitaryPolicyIM :table = InstanceManager:new( "MilitaryPolicyInstance",   "MilitaryPolicy",   Controls.MilitaryStack );
local m_kWildcardPolicyIM :table = InstanceManager:new( "WildcardPolicyInstance",   "WildcardPolicy",   Controls.WildcardStack );
local m_kPathMarkerIM   :table = InstanceManager:new( "ResearchPathMarker",     "Top",    Controls.NodeScroller);

local m_kUnlocksIM      :table = {};

local m_width       :number= 1024;    -- Screen Width (default / min spec)
local m_height        :number= 768;   -- Screen Height (default / min spec)
local m_scrollWidth     :number= 1024;    -- Width of the scroll bar (default to screen min_spec until set)
local m_kEras       :table = {};    -- type to costs
local m_kEraCounter     :table = {};    -- counter to determine which eras have techs
local m_maxColumns      :number= 0;     -- # of columns (highest column #)
local m_ePlayer       :number= -1;
local m_kAllPlayersTechData :table = {};    -- All data for local players.
local m_kCurrentData    :table = {};    -- Current set of data.
local m_kItemDefaults   :table = {};    -- Static data about items
local m_kNodeGrid     :table = {};    -- Static data about node location once it's laid out
local m_uiNodes       :table = {};
local m_uiConnectorSets   :table = {};
local m_kFilters      :table = {};
local m_kGovernments    :table = {};
local m_kPolicyCatalogData  :table;

local m_shiftDown     :boolean = false;

local m_lastPercent         :number = 0.1;

-- CQUI variables
local CQUI_halfwayNotified  :table = {};
local CQUI_ShowTechCivicRecommendations = false;

function CQUI_OnSettingsUpdate()
  CQUI_ShowTechCivicRecommendations = GameConfiguration.GetValue("CQUI_ShowTechCivicRecommendations") == 1
end
LuaEvents.CQUI_SettingsUpdate.Add(CQUI_OnSettingsUpdate);
LuaEvents.CQUI_SettingsInitialized.Add(CQUI_OnSettingsUpdate);

-- ===========================================================================
-- Return string respresenation of a prereq table
-- ===========================================================================
function GetPrereqsString( prereqs:table )
  local out:string = "";
  for _,prereq in pairs(prereqs) do
    if prereq == PREREQ_ID_TREE_START then
      out = "n/a ";
    else
      out = out .. m_kItemDefaults[prereq].Type .. " "; -- Add space between techs
    end
  end
  return "[" .. string.sub(out,1,string.len(out)-1) .. "]"; -- Remove trailing space
end

-- ===========================================================================
function SetCurrentNode( hash )
  if hash ~= nil then
    local localPlayerCulture = Players[Game.GetLocalPlayer()]:GetCulture();
    -- Get the complete path to the tech
    local pathToCivic = localPlayerCulture:GetCivicPath( hash );
    local tParameters = {};
    tParameters[PlayerOperations.PARAM_CIVIC_TYPE]  = pathToCivic;
    if m_shiftDown then
      tParameters[PlayerOperations.PARAM_INSERT_MODE] = PlayerOperations.VALUE_APPEND;
    else
      tParameters[PlayerOperations.PARAM_INSERT_MODE] = PlayerOperations.VALUE_EXCLUSIVE;
    end
    UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.PROGRESS_CIVIC, tParameters);
        UI.PlaySound("Confirm_Civic_CivicsTree");
  else
    UI.DataError("Attempt to change current tree item with NIL hash!");
  end

end

-- ===========================================================================
--  If the next item isn't immediate, show a path of #s traversing the tree
--  to the desired node.
-- ===========================================================================
function RealizePathMarkers()

  local pCulture  :table = Players[Game.GetLocalPlayer()]:GetCulture();
  local kNodeIds  :table = pCulture:GetCivicQueue();    -- table: index, IDs

  m_kPathMarkerIM:ResetInstances();

  for i,nodeNumber in pairs(kNodeIds) do
    local pathPin = m_kPathMarkerIM:GetInstance();

    if(i < 10) then
      pathPin.NodeNumber:SetOffsetX(PATH_MARKER_NUMBER_0_9_OFFSET);
    else
      pathPin.NodeNumber:SetOffsetX(PATH_MARKER_NUMBER_10_OFFSET);
    end
    pathPin.NodeNumber:SetText(tostring(i));
    for j,node in pairs(m_kItemDefaults) do
      if node.Index == nodeNumber then
        local x:number = m_uiNodes[node.Type].x;
        local y:number = m_uiNodes[node.Type].y;
        pathPin.Top:SetOffsetX(x-PATH_MARKER_OFFSET_X);
        pathPin.Top:SetOffsetY(y-PATH_MARKER_OFFSET_Y);
      end
    end
  end
end

-- ===========================================================================
--  Convert a virtual column # and row # to actual pixels within the
--  scrollable tree area.
-- ===========================================================================
function ColumnRowToPixelXY( column:number, row:number)
  local horizontal    :number = ((column-1) * COLUMNS_NODES_SPAN * COLUMN_WIDTH) + PADDING_TIMELINE_LEFT;
  local vertical      :number = PADDING_NODE_STACK_Y + (SIZE_WIDESCREEN_HEIGHT / 2) + (row * SIZE_NODE_Y);
  return horizontal, vertical;
end

-- ===========================================================================
--  Get the width of the scroll panel
-- ===========================================================================
function GetMaxScrollWidth()
  return m_maxColumns + (m_maxColumns * COLUMN_WIDTH) + PADDING_TIMELINE_LEFT;
end


-- ===========================================================================
--  Take the default item data and build the nodes that work with it.
--  One time creation, any dynamic pieces should be
--
--  No state specific data (e.g., selected node) should be set here in order
--  to reuse the nodes across viewing other players' trees for single seat
--  multiplayer or if a (spy) game rule allows looking at another's tree.
-- ===========================================================================
function AllocateUI()

  m_uiNodes = {};
  m_kNodeIM:ResetInstances();
  m_kLargeNodeIM:ResetInstances();

  m_uiConnectorSets = {};
  m_kLineIM:ResetInstances();

  -- By era, layout all items in single "sort" row
  local eraGrids:table = {};          -- each era has it's own "grid" of items to layout
  for _,item in pairs(m_kItemDefaults) do

    -- Create any data structures related to this era/row that don't exist:
    if eraGrids[item.EraType] == nil then
      eraGrids[item.EraType] = { rows={}, sortRow={ columns={} } };
      for i= ROW_MIN, ROW_MAX, 1 do
        eraGrids[item.EraType].rows[i] = { columns={} };
      end
    end

    -- For first placement, ignore row and place everything in the middle (row 0)
    local pos:number = table.count(eraGrids[item.EraType].sortRow.columns) + 1;
    eraGrids[item.EraType].sortRow.columns[pos] = item.Type;
  end

  -- Manually sort based on prereqs, 2(N log N)
  for eraType,grid in pairs(eraGrids) do
    local numEraItems:number = table.count(grid.sortRow.columns);
    if numEraItems > 1 then
      for pass=1,2,1 do         -- Make 2 passes so the first swapped item is checked.
        for a=1,numEraItems do
          for b=a,numEraItems do
            if a ~= b then
              for _,prereq in ipairs(m_kItemDefaults[grid.sortRow.columns[a] ].Prereqs) do
                if prereq == grid.sortRow.columns[b] then
                  grid.sortRow.columns[a], grid.sortRow.columns[b] = grid.sortRow.columns[b], grid.sortRow.columns[a];  -- swap LUA style
                end
              end
            end
          end
        end
      end
    end
  end

  -- Unflatten single, traversing each era grid from left to right, pushing the item to the right if it hits a prereq
  for eraType,grid in pairs(eraGrids) do
    local maxColumns:number = table.count(grid.sortRow.columns);  -- Worst case, straight line
    while ( table.count(grid.sortRow.columns) > 0 ) do

      local typeName  :string = table.remove( grid.sortRow.columns, 1);       -- Rip off first item in sort row (next item to place)
      local item    :table  = m_kItemDefaults[typeName];
      local pos   :number = 1;

      -- No prereqs? Just put at start, otherwise push forward past them all.
      if item.Prereqs ~= nil then
        for _,prereq in ipairs(item.Prereqs) do             -- For every prereq
          local isPrereqMatched :boolean = false;
          for x=pos,maxColumns,1 do                 -- For every column (from last highest found start position)
            for y=ROW_MIN, ROW_MAX,1 do               -- For every row in the column
              if grid.rows[y].columns[x] ~= nil then        -- Is a prereq in that position of the grid?
                if prereq == grid.rows[y].columns[x] then   -- And is it a prereq for this item?
                  pos = x + 1;                -- If so, this item can only exist at least 1 column further over from the prereq
                  isPrereqMatched = true;
                  break;
                end
              end
            end
            if isPrereqMatched then
              -- Ensuring this node wasn't just placed on top of another:
              while( grid.rows[item.UITreeRow].columns[pos] ~= nil ) do
                pos = pos + 1;
              end
              break;
            end
          end
        end
      end

      grid.rows[item.UITreeRow].columns[pos] = typeName;  -- Set for future lookups.
      item.Column = pos;                  -- Set which column within era item exists.

      if pos > m_kEras[item.EraType].NumColumns then
        m_kEras[item.EraType].NumColumns = pos;
      end
    end
  end

  -- Determine total # of columns prior to a given era, and max columns overall.
  local index = 1;
  local priorColumns:number = 0;
  m_maxColumns = 0;
  for row:table in GameInfo.Eras() do
    for era,eraData in pairs(m_kEras) do
      if eraData.Index == index then                  -- Ensure indexed order
        eraData.PriorColumns = priorColumns;
        priorColumns = priorColumns + eraData.NumColumns + 1; -- Add one for era art between
        break;
      end
    end
    index = index + 1;
  end
  m_maxColumns = priorColumns;


  -- Create grid used to route lines, determine maximum number of columns.
  m_kNodeGrid  = {};
  for i = ROW_MIN,ROW_MAX,1 do
    m_kNodeGrid[i] = {};
  end
  for _,item in pairs(m_kItemDefaults) do
    local era   :table  = m_kEras[item.EraType];
    local columnNum :number = era.PriorColumns + item.Column;
    m_kNodeGrid[item.UITreeRow][columnNum] = true;
  end

  -- Era divider information
  m_kEraArtIM:ResetInstances();
  m_kEraLabelIM:ResetInstances();
  m_kEraDotIM:ResetInstances();

  for era,eraData in pairs(m_kEras) do

    local instArt :table = m_kEraArtIM:GetInstance();
    if eraData.BGTexture ~= nil then
      instArt.BG:SetTexture( eraData.BGTexture );
      instArt.BG:SetOffsetX( eraData.BGTextureOffsetX );
    else
      UI.DataError("Civic tree is unable to find an EraCivicBackgroundTexture entry for era '"..eraData.Description.."'; using a default.");
      instArt.BG:SetTexture(PIC_DEFAULT_ERA_BACKGROUND);
    end

    local startx, _ = ColumnRowToPixelXY( eraData.PriorColumns + 1, 0);
    instArt.Top:SetOffsetX( (startx ) * (1/PARALLAX_ART_SPEED) );
    instArt.Top:SetOffsetY( (SIZE_WIDESCREEN_HEIGHT * 0.5) - (instArt.BG:GetSizeY()*0.5) );
    instArt.Top:SetSizeVal(eraData.NumColumns*SIZE_NODE_X, 600);

    local inst:table = m_kEraLabelIM:GetInstance();
    local eraMarkerx, _ = ColumnRowToPixelXY( eraData.PriorColumns + 1, 0);
    if eraData.Index == 1 then
      eraMarkerx = eraMarkerx + PADDING_FIRST_ERA_INDICATOR;
    end
    inst.Top:SetOffsetX( (eraMarkerx - (SIZE_NODE_X*0.5)) * (1/PARALLAX_SPEED) );
    inst.EraTitle:SetText( Locale.Lookup("LOC_GAME_ERA_DESC",eraData.Description) );

    -- Dots on scrollbar
    local markerx:number = (eraData.PriorColumns / m_maxColumns) * Controls.ScrollbarBackgroundArt:GetSizeX();
    if markerx > 0 then
      local inst:table = m_kEraDotIM:GetInstance();
      inst.Dot:SetOffsetX(markerx);
    end
  end

  local playerId = Game.GetLocalPlayer();
  if (playerId == -1) then
    return;
  end

  local extraIconDataCache:table = {};
  -- Reset extra icon instances
  for _,iconData in pairs(g_ExtraIconData) do
    iconData:Reset();
  end

  -- Actually build UI nodes
  for _,item in pairs(m_kItemDefaults) do
    local civic:table		= GameInfo.Civics[item.Type];
    local civicType:string	= civic and civic.CivicType;

    local unlockableTypes     = GetUnlockablesForCivic_Cached(civicType, playerId);
    local node        :table;
    local numUnlocks    :number = 0;
    local extraUnlocks		:table = {};
    local hideDescriptionIcon:boolean = false;

    if unlockableTypes ~= nil then
      for _, unlockItem in ipairs(unlockableTypes) do
        local typeInfo = GameInfo.Types[unlockItem[1]];

        if typeInfo.Kind == "KIND_GOVERNMENT" then
          numUnlocks = numUnlocks + 4;        -- 4 types of policy slots
        else
          numUnlocks = numUnlocks + 1;
        end
      end
    end

    -- Include extra icons in total unlocks
    if ( item.ModifierList ) then
      for _,tModifier in ipairs(item.ModifierList) do
        local tIconData :table = g_ExtraIconData[tModifier.ModifierType];
        if ( tIconData ) then
          numUnlocks = numUnlocks + 1;
          hideDescriptionIcon = hideDescriptionIcon or tIconData.HideDescriptionIcon;
          table.insert(extraUnlocks, {IconData=tIconData, ModifierTable=tModifier});
        end
      end
    end

    -- Create node based on # of unlocks for this civic.
    if numUnlocks <= 8 then
      node = m_kNodeIM:GetInstance();
    else
      node = m_kLargeNodeIM:GetInstance();
      node.IsLarge = true;
    end
    node.Top:SetTag( item.Hash ); -- Set the hash of the civic to the tag of the node (for tutorial to be able to callout)

    local era:table = m_kEras[item.EraType];

    -- Horizontal # = All prior nodes across all previous eras + node position in current era (based on cost vs. other nodes in that era)
    local horizontal, vertical = ColumnRowToPixelXY(era.PriorColumns + item.Column, item.UITreeRow );

    -- Add data fields to UI component
    node.Type = civicType;  -- Dynamically add "Type" field to UI node for quick look ups in item data table.
    node.x    = horizontal; -- Granted x,y can be looked up via GetOffset() but caching the values here for
    node.y    = vertical - VERTICAL_CENTER;   -- other LUA functions to use removes the necessity of a slow C++ roundtrip.

    if node["unlockIM"] == nil then
      node["unlockIM"] = InstanceManager:new( "UnlockInstance", "UnlockIcon", node.UnlockStack );
    else
      node["unlockIM"]:DestroyInstances()
    end

    if node["unlockGOV"] == nil then
      node["unlockGOV"] = InstanceManager:new( "GovernmentIcon", "GovernmentInstanceGrid", node.UnlockStack );
      node["unlockGOV"]:DestroyInstances()
    end

    item.Callback = function()
      SetCurrentNode(item.Hash);
    end
    PopulateUnlockablesForCivic(playerId, civic.Index, node["unlockIM"], node["unlockGOV"], item.Callback, hideDescriptionIcon);

    -- Initialize extra icons
    for _,tUnlock in pairs(extraUnlocks) do
      tUnlock.IconData:Initialize(node.UnlockStack, tUnlock.ModifierTable);
    end

    node.NodeButton:RegisterCallback( Mouse.eLClick, item.Callback);
    node.OtherStates:RegisterCallback( Mouse.eLClick, item.Callback);

    -- Only wire up Civilopedia handlers if not in a on-rails tutorial.
    if not IsTutorialRunning() then
      -- What happens when clicked
      local OpenPedia = function()	
        LuaEvents.OpenCivilopedia(civicType); 
      end
      node.NodeButton:RegisterCallback( Mouse.eRClick, OpenPedia);
      node.OtherStates:RegisterCallback( Mouse.eRClick, OpenPedia);
    end

    -- Set position and save
    node.Top:SetOffsetVal( horizontal, vertical);
    m_uiNodes[item.Type] = node;
  end

  -- -- Refresh extra icons
  -- LuaEvents.CivicsTreeIconRefresh(extraIconDataCache);

  if Controls.TreeStart ~= nil then
    local h,v = ColumnRowToPixelXY( TREE_START_COLUMN, TREE_START_ROW );
    Controls.TreeStart:SetOffsetVal( h,v );
  end

  -- Determine the lines between nodes.
  -- NOTE: Potentially move this to view, since lines are constantly change in look, but
  --     it makes sense to have at least the routes computed here since they are
  --     consistent regardless of the look.
  local spaceBetweenColumns:number = COLUMN_WIDTH - SIZE_NODE_X;
  for _,item in pairs(m_kItemDefaults) do

    local node:table = m_uiNodes[item.Type];

    for _,prereqId in pairs(item.Prereqs) do

      local previousRow :number = 0;
      local previousColumn:number = 0;
      if prereqId == PREREQ_ID_TREE_START then
        previousRow   = TREE_START_ROW;
        previousColumn  = TREE_START_COLUMN;
      else
        local prereq :table = m_kItemDefaults[prereqId];
        previousRow   = prereq.UITreeRow;
        previousColumn  = m_kEras[prereq.EraType].PriorColumns + prereq.Column;
      end

      local startColumn :number = m_kEras[item.EraType].PriorColumns + item.Column;
      local column    :number = startColumn - 1;                    -- start one back
      while m_kNodeGrid[item.UITreeRow][column] == nil and column > previousColumn do   -- keep working backwards until hitting a node
        column = column - 1;
      end


      if previousRow == TREE_START_NONE_ID then

        -- Nothing goes before this, not even a fake start area.

      elseif previousRow < item.UITreeRow or previousRow > item.UITreeRow  then

        -- Obtain the line objects
        local inst  :table = m_kLineIM:GetInstance();
        local line1 :table = inst.LineImage; inst = m_kLineIM:GetInstance();
        local line2 :table = inst.LineImage; inst = m_kLineIM:GetInstance();
        local line3 :table = inst.LineImage; inst = m_kLineIM:GetInstance();
        local line4 :table = inst.LineImage; inst = m_kLineIM:GetInstance();
        local line5 :table = inst.LineImage;

        -- Find all the empty space before the node before to make a bend.
        local LineStartX:number = node.x;
        local LineEndX1 :number = (node.x - LINE_LENGTH_BEFORE_CURVE ) ;
        local LineEndX2, _ = ColumnRowToPixelXY( column, item.UITreeRow );
        LineEndX2 = LineEndX2 + SIZE_NODE_X;

        local LineY1  :number;
        local LineY2  :number;
        if previousRow < item.UITreeRow  then
          LineY2 = node.y-((item.UITreeRow-previousRow)*SIZE_NODE_Y)+ LINE_VERTICAL_OFFSET;-- above
          LineY1 = node.y -LINE_VERTICAL_OFFSET;
        else
          LineY2 = node.y+((previousRow-item.UITreeRow)*SIZE_NODE_Y)- LINE_VERTICAL_OFFSET;-- below
          LineY1 = node.y +LINE_VERTICAL_OFFSET;
        end

        line1:SetOffsetVal(LineEndX1 + SIZE_PATH_HALF, LineY1 - SIZE_PATH_HALF);
        line1:SetSizeVal( LineStartX - LineEndX1 - SIZE_PATH_HALF, SIZE_PATH);

        line2:SetOffsetVal(LineEndX1 - SIZE_PATH_HALF, LineY1 - SIZE_PATH_HALF);
        line2:SetSizeVal( SIZE_PATH, SIZE_PATH);
        if previousRow < item.UITreeRow  then
          line2:SetTexture("Controls_TreePathDashSE");
        else
          line2:SetTexture("Controls_TreePathDashNE");
        end

        line3:SetOffsetVal(LineEndX1 - SIZE_PATH_HALF, math.min(LineY1 + SIZE_PATH_HALF, LineY2 + SIZE_PATH_HALF) );
        line3:SetSizeVal( SIZE_PATH, math.abs(LineY1 - LineY2) - SIZE_PATH );
        line3:SetTexture("Controls_TreePathDashNS");

        line4:SetOffsetVal(LineEndX1 - SIZE_PATH_HALF, LineY2 - SIZE_PATH_HALF);
        line4:SetSizeVal( SIZE_PATH, SIZE_PATH);
        if previousRow < item.UITreeRow  then
          line4:SetTexture("Controls_TreePathDashES");
        else
          line4:SetTexture("Controls_TreePathDashEN");
        end

        line5:SetSizeVal(  LineEndX1 - LineEndX2 - SIZE_PATH_HALF, SIZE_PATH );
        line5:SetOffsetVal(LineEndX2, LineY2 - SIZE_PATH_HALF);

        -- Directly store the line (not instance) with a key name made up of this type and the prereq's type.
        m_uiConnectorSets[item.Type..","..prereqId] = {line1,line2,line3,line4,line5};

      else
        -- Prereq is on the same row
        local inst:table = m_kLineIM:GetInstance();
        local line:table = inst.LineImage;
        local end1, _ = ColumnRowToPixelXY( column, item.UITreeRow );
        end1 = end1 + SIZE_NODE_X;

        line:SetOffsetVal(end1, node.y - SIZE_PATH_HALF);
        line:SetSizeVal( node.x - end1, SIZE_PATH);

        -- Directly store the line (not instance) with a key name made up of this type and the prereq's type.
        m_uiConnectorSets[item.Type..","..prereqId] = {line};
      end
    end
  end

  Controls.NodeScroller:CalculateSize();
  Controls.NodeScroller:ReprocessAnchoring();
  Controls.ArtScroller:CalculateSize();
  Controls.FarBackArtScroller:CalculateSize();

  Controls.NodeScroller:RegisterScrollCallback( OnScroll );

  -- We use a separate BG within the PeopleScroller control since it needs to scroll with the contents
  Controls.ModalBG:SetHide(true);
  Controls.ModalScreenClose:RegisterCallback(Mouse.eLClick, OnClose);
  Controls.ModalScreenTitle:SetText(Locale.ToUpper(Locale.Lookup("LOC_CIVICS_TREE_HEADER")));
end

-- ===========================================================================
--  UI Event
--  Callback when the main scroll panel is scrolled.
-- ===========================================================================
function OnScroll( control:table, percent:number )

  -- Parallax
  -- ??TRON re-examine:
  --Controls.ArtScroller:SetScrollValue( percent * PARALLAX_SPEED);
  --Controls.FarBackArtScroller:SetScrollValue( percent * PARALLAX_ART_SPEED);
  Controls.ArtScroller:SetScrollValue( percent );
  Controls.FarBackArtScroller:SetScrollValue( percent );

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
--  Display the state of the tree (filter, node display, etc...) based on the
--  active player's item data.
--  Viewxx
-- ===========================================================================
function View( playerTechData:table )

  -- Output the node states for the tree
  for _,node in pairs(m_uiNodes) do
    local item    :table = m_kItemDefaults[node.Type];            -- static item data
    local live    :table = playerTechData[DATA_FIELD_LIVEDATA][node.Type];  -- live (changing) data
    local artInfo :table = (node.IsLarge) and STATUS_ART_LARGE[live.Status] or STATUS_ART[live.Status];

    if(live.Status == ITEM_STATUS.RESEARCHED) then
      for _,prereqId in pairs(item.Prereqs) do
        if(prereqId ~= PREREQ_ID_TREE_START) then
          local prereq    :table = m_kItemDefaults[prereqId];
          local previousRow :number = prereq.UITreeRow;
          local previousColumn:number = m_kEras[prereq.EraType].PriorColumns;

          for lineNum,line in pairs(m_uiConnectorSets[item.Type..","..prereqId]) do
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

    node.NodeName:SetColor( artInfo.TextColor0, 0 );
    node.NodeName:SetColor( artInfo.TextColor1, 1 );
    if m_debugShowIDWithName then
      node.NodeName:SetText( tostring(item.Index).."  "..Locale.Lookup(item.Name) );  -- Debug output
    else
      node.NodeName:SetText( Locale.ToUpper( Locale.Lookup(item.Name) ));       -- Normal output
    end

    if live.Turns > 0 then
      node.Turns:SetHide( false );
      node.Turns:SetColor( artInfo.TextColor0, 0 );
      node.Turns:SetColor( artInfo.TextColor1, 1 );
      node.Turns:SetText( Locale.Lookup("LOC_TECH_TREE_TURNS",live.Turns) );
    else
      node.Turns:SetHide( true );
    end

    if item.IsBoostable and live.Status ~= ITEM_STATUS.RESEARCHED then
      node.BoostIcon:SetHide( false );
      node.BoostText:SetHide( false );
      node.BoostText:SetColor( artInfo.TextColor0, 0 );
      node.BoostText:SetColor( artInfo.TextColor1, 1 );

      local boostText:string;
      if live.IsBoosted then
        boostText = TXT_BOOSTED.." "..item.BoostText;
        node.BoostIcon:SetTexture( PIC_BOOST_ON );
        node.BoostMeter:SetHide( false );
        node.BoostedBack:SetHide( false );
      else
        boostText = TXT_TO_BOOST.." "..item.BoostText;
        node.BoostedBack:SetHide( true );
        node.BoostIcon:SetTexture( PIC_BOOST_OFF );
        node.BoostMeter:SetHide( false );
        local boostAmount = (item.BoostAmount*.01) + (live.Progress/ live.Cost);
        node.BoostMeter:SetPercent( boostAmount );
      end
      TruncateStringWithTooltip(node.BoostText, MAX_BEFORE_TRUNC_TO_BOOST, boostText);
    else
      node.BoostIcon:SetHide( true );
      node.BoostText:SetHide( true );
      node.BoostedBack:SetHide( true );
      node.BoostMeter:SetHide( true );
    end

    if live.Status == ITEM_STATUS.CURRENT then
      node.GearAnim:SetHide( false );
    else
      node.GearAnim:SetHide( true );
    end

    if live.Progress > 0 then
      node.ProgressMeter:SetHide( false );
      node.ProgressMeter:SetPercent(live.Progress / live.Cost);
    else
      node.ProgressMeter:SetHide( true );
    end

    -- Set art for icon area
    if(item.Type ~= nil) then
      local iconName :string = DATA_ICON_PREFIX .. item.Type;
      if (artInfo.Name == "BLOCKED" or artInfo.Name == "LARGEBLOCKED") then
        node.IconBacking:SetHide(true);
        iconName = iconName .. "_FOW";
        node.BoostMeter:SetColor(0x66ffffff);
        node.BoostIcon:SetColor(0x66000000);
      else
        node.IconBacking:SetHide(false);
        iconName = iconName;
        node.BoostMeter:SetColor(0xffffffff);
        node.BoostIcon:SetColor(0xffffffff);
      end
      local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName,42);
      if (textureOffsetX ~= nil) then
        node.Icon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
      end
    end

    if artInfo.IsButton then
      node.OtherStates:SetHide( true );
      node.NodeButton:SetTextureOffsetVal( artInfo.BGU, artInfo.BGV );
    else
      node.OtherStates:SetHide( false );
      node.OtherStates:SetTextureOffsetVal( artInfo.BGU, artInfo.BGV );
    end

    if artInfo.FillTexture ~= nil then
      node.FillTexture:SetHide( false );
      node.FillTexture:SetTexture( artInfo.FillTexture );
    else
      node.FillTexture:SetHide( true );
    end

    if artInfo.BoltOn then
      node.Bolt:SetTexture(PIC_BOLT_ON);
    else
      node.Bolt:SetTexture(PIC_BOLT_OFF);
    end

    node.NodeButton:SetToolTipString(ToolTipHelper.GetToolTip(item.Type, Game.GetLocalPlayer()));
    node.IconBacking:SetTexture(artInfo.IconBacking);

    -- Darken items not making it past filter.
    local currentFilter:table = playerTechData[DATA_FIELD_UIOPTIONS].filter;
    if currentFilter == nil or currentFilter.Func == nil or currentFilter.Func( item.Type ) then
      node.FilteredOut:SetHide( true );
    else
      node.FilteredOut:SetHide( false );
    end

    -- Show/Hide Recommended Icon
    -- CQUI : only if show tech civ enabled in settings
    if live.IsRecommended and live.AdvisorType ~= nil and CQUI_ShowTechCivicRecommendations then
      node.RecommendedIcon:SetIcon(live.AdvisorType);
      node.RecommendedIcon:SetHide(false);
    else
      node.RecommendedIcon:SetHide(true);
    end
  end

  -- Fill in where the markers (representing players) are at:
  m_kMarkerIM:ResetInstances();
  local PADDING   :number = 24;
  local thisPlayerID  :number = Game.GetLocalPlayer();
  local markers   :table  = m_kCurrentData[DATA_FIELD_PLAYERINFO].Markers;
  for _,markerStat in ipairs( markers ) do

    -- Only build a marker if a player has started researching...
    if markerStat.HighestColumn ~= -1 then
      local instance  :table  = m_kMarkerIM:GetInstance();

      if markerStat.IsPlayerHere then
        -- Representing the player viewing the tree
        instance.Portrait:SetHide( true );
        instance.TurnGrid:SetHide( false );
        instance.TurnLabel:SetText( Locale.Lookup("LOC_TECH_TREE_TURN_NUM" ));
        instance.TurnNumber:SetText( tostring(Game.GetCurrentGameTurn()) );
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
      local higestEraName = "";
      if markerStat.HighestEra ~= nil and GameInfo.Eras[markerStat.HighestEra] ~= nil then
        higestEraName = GameInfo.Eras[markerStat.HighestEra].Name;
      end

      local tooltipString				:string = Locale.Lookup("LOC_TREE_ERA", Locale.Lookup(higestEraName) ).."[NEWLINE]";
      local numOfPlayersAtThisColumn  :number = table.count(markerStat.PlayerNums);
      if numOfPlayersAtThisColumn < 2 then
        instance.Num:SetHide( true );
        local playerNum   :number = markerStat.PlayerNums[1];
        local pPlayerConfig :table = PlayerConfigurations[playerNum];
        tooltipString = tooltipString.. Locale.Lookup(pPlayerConfig:GetPlayerName()); -- TODO: Temporary using player name until leaderame is fixed

        if not markerStat.IsPlayerHere then
          local iconName:string = "ICON_"..pPlayerConfig:GetLeaderTypeName();
          instance.Portrait:SetHide( false );
          instance.Portrait:SetIcon( iconName );
        end
      else
        instance.Portrait:SetHide( true );
        instance.Num:SetHide( false );
        instance.Num:SetText(tostring(numOfPlayersAtThisColumn));
        for i,playerNum in ipairs(markerStat.PlayerNums) do
          local pPlayerConfig :table = PlayerConfigurations[playerNum];
          --[[ TODO: The human player, player 0, has whack values! No leader name coming from engine!
            local name = pPlayerConfig:GetPlayerName();
            local nick = pPlayerConfig:GetNickName();
            local leader = pPlayerConfig:GetLeaderName();
            local civ = pPlayerConfig:GetCivilizationTypeName();
            local isHuman = pPlayerConfig:IsHuman();
            print("debug info:",name,nick,leader,civ,isHuman);
          ]]
          --tooltipString = tooltipString.. Locale.Lookup(pPlayerConfig:GetLeaderName());
          tooltipString = tooltipString.. Locale.Lookup(pPlayerConfig:GetPlayerName()); -- TODO:: Temporary using player name until leaderame is fixed
          if i < numOfPlayersAtThisColumn then
            tooltipString = tooltipString.."[NEWLINE]";
          end
        end
      end
      instance.Marker:SetToolTipString( tooltipString );

      local MARKER_OFFSET_START:number = 20;
      local markerPercent :number = math.clamp( markerStat.HighestColumn / m_maxColumns, 0, 1 );
      local markerX   :number = MARKER_OFFSET_START + (markerPercent * m_scrollWidth );
      instance.Top:SetOffsetVal(markerX ,0);
    end
  end

  RealizePathMarkers();
  RealizeFilterPulldown();
  RealizeKeyPanel();
  RealizeGovernmentPanel();
end

function GetPlayerGovernment(ePlayer:number)
  local kPlayer   :table  = Players[ePlayer];
  local playerCulture :table  = kPlayer:GetCulture();
  local kCurrentGovernment:table;
  local kGovernmentInfo:table = {};

  local governmentId :number = playerCulture:GetCurrentGovernment();
  if governmentId ~= -1 then
    kCurrentGovernment = GameInfo.Governments[governmentId];
    kGovernmentInfo["NAMES"] = Locale.Lookup(kCurrentGovernment.Name);
  end

  kGovernmentInfo["DIPLOMATIC"] = 0;
  kGovernmentInfo["ECONOMIC"] = 0;
  kGovernmentInfo["WILDCARD"] = 0;
  kGovernmentInfo["MILITARY"] = 0;
  kGovernmentInfo["DIPLOMATICPOLICIES"] = {};
  kGovernmentInfo["ECONOMICPOLICIES"] = {};
  kGovernmentInfo["MILITARYPOLICIES"] = {};
  kGovernmentInfo["WILDCARDPOLICIES"] = {};

  local numSlots:number = playerCulture:GetNumPolicySlots();
  for i = 0, numSlots-1, 1 do
    local iSlotType :number = playerCulture:GetSlotType(i);
    local iSlotPolicy :number= playerCulture:GetSlotPolicy(i);
    local rowSlotType :string = GameInfo.GovernmentSlots[iSlotType].GovernmentSlotType;

    if  rowSlotType == "SLOT_DIPLOMATIC" then
      kGovernmentInfo["DIPLOMATIC"] = kGovernmentInfo["DIPLOMATIC"]+1;
      table.insert(kGovernmentInfo["DIPLOMATICPOLICIES"], iSlotPolicy);
    elseif  rowSlotType == "SLOT_ECONOMIC"  then
      kGovernmentInfo["ECONOMIC"] = kGovernmentInfo["ECONOMIC"]+1;
      table.insert(kGovernmentInfo["ECONOMICPOLICIES"], iSlotPolicy);
    elseif  rowSlotType == "SLOT_MILITARY"  then
      kGovernmentInfo["MILITARY"] = kGovernmentInfo["MILITARY"]+1;
      table.insert(kGovernmentInfo["MILITARYPOLICIES"], iSlotPolicy);
    elseif  rowSlotType == "SLOT_WILDCARD"  then
      kGovernmentInfo["WILDCARD"] = kGovernmentInfo["WILDCARD"]+1;
      table.insert(kGovernmentInfo["WILDCARDPOLICIES"], iSlotPolicy);
    else
      UI.DataError("On initialization; unhandled slot type for a policy '"..rowSlotType.."'");
    end
  end

  return kGovernmentInfo;
end

-- ===========================================================================
--  Load all the 'live' data for a player.
-- ===========================================================================
function GetLivePlayerData( ePlayer:number )

  -- If first time, initialize player data tables.
  local data  :table = m_kAllPlayersTechData[ePlayer];
  if data == nil then
    -- Initialize player's top level tables:
    data = {};
    data[DATA_FIELD_LIVEDATA]     = {};
    data[DATA_FIELD_PLAYERINFO]     = {};
    data[DATA_FIELD_UIOPTIONS]      = {};
    data[DATA_FIELD_GOVERNMENT]     = {};

    -- Initialize data, and sub tables within the top tables.
    data[DATA_FIELD_PLAYERINFO].Player  = ePlayer;  -- Number of this player
    data[DATA_FIELD_PLAYERINFO].Markers = {};   -- Hold a condenced, UI-ready version of stats
    data[DATA_FIELD_PLAYERINFO].Stats = {};   -- Hold stats on where each player is (based on what this player can see)
  end

  local kPlayer   :table  = Players[ePlayer];
  local playerCulture :table  = kPlayer:GetCulture();
  local currentCivicID:number = playerCulture:GetProgressingCivic();

  -- DEBUG: Output header to console.
  if m_debugOutputCivicInfo then
    print("                          Item Id  Status      Progress   $ Era              Prereqs");
    print("------------------------------ --- ---------- --------- --- ---------------- --------------------------");
  end

  -- Get recommendations
  local civicRecommendations:table = {};
  local kGrandAI:table = kPlayer:GetGrandStrategicAI();
  if kGrandAI then
    for i,recommendation in pairs(kGrandAI:GetCivicsRecommendations()) do
      civicRecommendations[recommendation.CivicHash] = recommendation.CivicScore;
    end
  end

  -- Loop through all items and place in appropriate buckets as well
  -- read in the associated information for it.
  for type,item in pairs(m_kItemDefaults) do
    local civicID	:number = GameInfo.Civics[item.Type].Index;
    local status  :number = ITEM_STATUS.BLOCKED;
    local turnsLeft :number = 0;
    if playerCulture:HasCivic(civicID) then
      status = ITEM_STATUS.RESEARCHED;
    elseif civicID == currentCivicID then
      status = ITEM_STATUS.CURRENT;
      turnsLeft = playerCulture:GetTurnsLeft();
    elseif playerCulture:CanProgress(civicID) then
      status = ITEM_STATUS.READY;
      turnsLeft = playerCulture:GetTurnsToProgressCivic(civicID);
    else
      turnsLeft = playerCulture:GetTurnsToProgressCivic(civicID);
    end

    data[DATA_FIELD_LIVEDATA][type] = {
      Cost		= playerCulture:GetCultureCost(civicID),
      IsBoosted	= playerCulture:HasBoostBeenTriggered(civicID),
      Progress	= playerCulture:GetCulturalProgress(civicID),
      Status    = status,
      Turns   = turnsLeft
    }

    -- Determine if tech is recommended
    if civicRecommendations[item.Hash] then
      data[DATA_FIELD_LIVEDATA][type].AdvisorType = GameInfo.Civics[item.Type].AdvisorType;
      data[DATA_FIELD_LIVEDATA][type].IsRecommended = true;
    else
      data[DATA_FIELD_LIVEDATA][type].IsRecommended = false;
    end

    -- DEBUG: Output to console detailed information about the tech.
    if m_debugOutputCivicInfo then
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
      local playerCulture :table  = players[i]:GetCulture();
      local currentCivic  :number = playerCulture:GetProgressingCivic();

      data[DATA_FIELD_PLAYERINFO].Stats[playerID] = {
        CurrentID   = currentCivic,
        HasMet      = kPlayer:GetDiplomacy():HasMet(playerID) or playerID==ePlayer or m_debugShowAllMarkers;
        HighestColumn = -1,       -- where they are in the timeline
        HighestEra    = ""
      };

      -- The latest tech a player may be researching may not be the one
      -- furthest along in time; so go through ALL the techs and track
      -- the highest column of all researched tech.
      local highestColumn :number = -1;
      local highestEra  :string = "";
      for _,item in pairs(m_kItemDefaults) do
        local civicID:number = GameInfo.Civics[item.Type].Index;
        if playerCulture:HasCivic(civicID) then
          local column:number = item.Column + m_kEras[item.EraType].PriorColumns;
          if column > highestColumn then
            highestColumn = column;
            highestEra    = item.EraType;
          end
        end
      end
      data[DATA_FIELD_PLAYERINFO].Stats[playerID].HighestColumn = highestColumn;
      data[DATA_FIELD_PLAYERINFO].Stats[playerID].HighestEra    = highestEra;
    end
  end


  -- All player data is added.. build markers data based on player data.
  local checkedID:table = {};
  data[DATA_FIELD_PLAYERINFO].Markers = {};
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
              HighestColumn = targetPlayer.HighestColumn, -- Which column this marker should be placed
              HighestEra    = targetPlayer.HighestEra,
              IsPlayerHere  = (playerID == ePlayer),
              PlayerNums    = {playerID}}                 -- All players who share this marker spot
        table.insert( data[DATA_FIELD_PLAYERINFO].Markers, markerData );
      end
      -- SPECIAL CASE: Current player starts at column 0 so it's immediately visible on timeline:
      if playerID == ePlayer and markerData.HighestColumn == -1 then
        markerData.HighestColumn = 0;
        local firstEra:table = nil;
        for _,era in pairs(m_kEras) do
          if firstEra == nil or era.Index < firstEra.Index then
            firstEra = era;
          end
        end
        if firstEra ~= nil then
          markerData.HighestEra = firstEra.Index;
        end
      end

      -- Traverse all the IDs and merge them with this one.
      for anotherID:number, anotherPlayer:table in pairs(data[DATA_FIELD_PLAYERINFO].Stats) do
        -- Don't add if: it's outself, if hasn't researched at least 1 tech, if we haven't met
        if playerID ~= anotherID and anotherPlayer.HighestColumn > -1 and anotherPlayer.HasMet then
          if markerData.HighestColumn == data[DATA_FIELD_PLAYERINFO].Stats[anotherID].HighestColumn then
            checkedID[anotherID] = true;
            -- Need to do this check if player's ID didn't show up first in the list in creating the marker.
            if anotherID == ePlayer then
              markerData.IsPlayerHere = true;
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

  data[DATA_FIELD_GOVERNMENT] = GetPlayerGovernment(ePlayer);

  return data;
end

-- Optional parameter
function RefreshDataIfNeeded( )
  if ContextPtr:IsVisible() then
    m_kCurrentData = GetLivePlayerData( m_ePlayer );
    View( m_kCurrentData );
  end
end

function UpdateLocalPlayer()
  local ePlayer :number = Game.GetLocalPlayer();
  if ePlayer ~= -1 and m_ePlayer ~= ePlayer then
    m_ePlayer = ePlayer;
    RefreshDataIfNeeded( );
  end
end

-- ===========================================================================
function OnGovernmentChanged()
  UpdateLocalPlayer()
end

-- ===========================================================================
function OnGovernmentPolicyChanged()
  UpdateLocalPlayer()
end

-- ===========================================================================
function OnLocalPlayerTurnBegin()
  -- CQUI comment: We do not use UpdateLocalPlayer() here, because of Check for Civic Progress
  local ePlayer :number = Game.GetLocalPlayer();
  if ePlayer ~= -1 and m_ePlayer ~= ePlayer then
    m_ePlayer = ePlayer;
    RefreshDataIfNeeded( );

    --------------------------------------------------------------------------
    -- CQUI Check for Civic Progress

    -- Get the current tech
    local kPlayer       :table  = Players[ePlayer];
    local playerCivics      :table  = kPlayer:GetCulture();
    local currentCivicID  :number = playerCivics:GetProgressingCivic();
    local isCurrentBoosted  :boolean = playerCivics:HasBoostBeenTriggered(currentCivicID);

    -- Make sure there is a civic selected before continuing with checks
    if currentCivicID ~= -1 then
      local civicName = GameInfo.Civics[currentCivicID].Name;
      local civicType = GameInfo.Civics[currentCivicID].Type;

      local currentCost         = playerCivics:GetCultureCost(currentCivicID);
      local currentProgress     = playerCivics:GetCulturalProgress(currentCivicID);
      local currentYield          = playerCivics:GetCultureYield();
      local percentageToBeDone    = (currentProgress + currentYield) / currentCost;
      local percentageNextTurn    = (currentProgress + currentYield*2) / currentCost;
      local CQUI_halfway:number = .5;

      -- Finds boost amount, always 50 in base game, China's +10% modifier is not applied here
      for row in GameInfo.Boosts() do
        if(row.CivicType == civicType) then
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
        CQUI_halfwayNotified[civicName] = true;
      elseif percentageNextTurn >= CQUI_halfway and CQUI_halfwayNotified[civicName] ~= true then
          LuaEvents.CQUI_AddStatusMessage(Locale.Lookup("LOC_CQUI_CIVIC_MESSAGE_S") .. " " .. Locale.Lookup( civicName ) ..  " " .. Locale.Lookup("LOC_CQUI_HALF_MESSAGE_E"), 10, CQUI_STATUS_MESSAGE_CIVIC);
          CQUI_halfwayNotified[civicName] = true;
      end

    end -- end of if currentCivivID ~= -1
    --------------------------------------------------------------------------

  end -- end of ePlayer ~= -1
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
function OnCivicChanged( ePlayer:number, eTech:number )
  if ePlayer == Game.GetLocalPlayer() then
    m_ePlayer = ePlayer;
    RefreshDataIfNeeded( );
  end
end

-- ===========================================================================
function OnCivicComplete( ePlayer:number, eTech:number)
  if ePlayer == Game.GetLocalPlayer() then
    m_ePlayer = ePlayer;
    RefreshDataIfNeeded( );

    --------------------------------------------------------------------------
    -- CQUI Civic Complete

    -- Get the current tech
    local kPlayer       :table  = Players[ePlayer];
    local currentCivicID  :number = eTech;

    -- Make sure there is a civic selected before continuing with checks
    if currentCivicID ~= -1 then
      local civicName = GameInfo.Civics[currentCivicID].Name;
    LuaEvents.CQUI_AddStatusMessage(Locale.Lookup("LOC_CIVIC_BOOST_COMPLETE", civicName), 10, CQUI_STATUS_MESSAGE_CIVIC);
    end -- end of if currentCivivID ~= -1

    --------------------------------------------------------------------------

  end
end

-- ===========================================================================
--  Initially size static UI elements
--  (or re-size if screen resolution changed)
-- ===========================================================================
function Resize()
  m_width, m_height = UIManager:GetScreenSizeVal();   -- Cache screen dimensions
  m_scrollWidth   = m_width - 80;           -- Scrollbar area (where markers are placed) slightly smaller than screen width

  local keyHeight:number = SIZE_WIDESCREEN_HEIGHT - (SIZE_OPTIONS_Y + SIZE_TIMELINE_AREA_Y + SIZE_TOP_AREA_Y);


  if not Controls.GovernmentPanel:IsHidden() then
    keyHeight = keyHeight - SIZE_GOVTPANEL_HEIGHT;
  end

  Controls.KeyPanel:SetSizeY(keyHeight);
  Controls.KeyScroll:SetSizeY(keyHeight-20);
  if(Controls.KeyPanel:IsHidden()) then
    Controls.GovernmentPanel:SetOffsetY(-87);
  else
    Controls.GovernmentPanel:SetOffsetY(keyHeight - 90);
  end

  -- Determine how far art will span.
  -- First obtain the size of the tree by taking the visible size and multiplying it by the ratio of the full content
  local scrollPanelX:number = (Controls.NodeScroller:GetSizeX() / Controls.NodeScroller:GetRatio());

  local artAndEraScrollWidth:number = math.max(scrollPanelX * (1/PARALLAX_SPEED), m_width);
  Controls.ArtParchmentDecoTop:SetSizeX( artAndEraScrollWidth );
  Controls.ArtParchmentDecoBottom:SetSizeX( artAndEraScrollWidth );
  Controls.ArtParchmentRippleTop:SetSizeX( artAndEraScrollWidth );
  Controls.ArtParchmentRippleBottom:SetSizeX( artAndEraScrollWidth );
  Controls.ForceSizeX:SetSizeX( artAndEraScrollWidth  );
  Controls.ArtScroller:CalculateSize();
  Controls.ArtCornerGrungeTR:ReprocessAnchoring();
  Controls.ArtCornerGrungeBR:ReprocessAnchoring();


  local backArtScrollWidth:number = scrollPanelX * (1/PARALLAX_ART_SPEED) + 100;
  Controls.Background:SetSizeX( math.max(backArtScrollWidth, m_width) );
  Controls.Background:SetSizeY( SIZE_WIDESCREEN_HEIGHT - (SIZE_TIMELINE_AREA_Y - 8) );
  Controls.FarBackArtScroller:CalculateSize();

  Controls.KeyScroll:CalculateSize();
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
  -- Build main item table.
  m_kItemDefaults = {};
  local index     :number   = 0;
  function GetHash(t)
    local r = GameInfo.Types[t];
    if(r) then
      return r.Hash;
    else
      return 0;
    end
  end

  local tCivicModCache :table = TechAndCivicSupport_BuildCivicModifierCache();

  for row:table in GameInfo[tableName]() do

    local entry:table = {};
    entry.Type      = row[tableColumn];
    entry.Name      = row.Name;
    entry.BoostText   = "";
    entry.Column    = -1;       -- Dynamically computed during UI layout
    entry.Cost      = row.Cost;
    entry.Description = row.Description and Locale.Lookup( row.Description );
    entry.EraType   = row.EraType;
    entry.Hash      = GetHash(entry.Type);
    entry.Index     = index;
    entry.IsBoostable = false;
    entry.Prereqs   = {};
    entry.UITreeRow   = row.UITreeRow;
    entry.Unlocks   = {};       -- Each unlock has: unlockType, iconUnavail, iconAvail, tooltip

    -- Look up and cache any civic modifiers we reward like envoys awarded
    entry.ModifierList = tCivicModCache[entry.Type];

    -- Boost?
    for boostRow in GameInfo.Boosts() do
      if boostRow.CivicType == entry.Type then
        entry.BoostText = Locale.Lookup( boostRow.TriggerDescription );
        entry.IsBoostable = true;
        entry.BoostAmount = boostRow.Boost;
        break;
      end
    end

    for prereqRow in GameInfo[prereqTableName]() do
      if prereqRow[itemColumn] == entry.Type then
        table.insert( entry.Prereqs, prereqRow[prereqColumn] );
      end
    end
    -- If no prereqs were found, set item to special tree start value
    if table.count(entry.Prereqs) == 0 then
      table.insert(entry.Prereqs, PREREQ_ID_TREE_START);
    end

    -- Warn if DB has an out of bounds entry.
    if entry.UITreeRow < ROW_MIN or entry.UITreeRow > ROW_MAX then
      UI.DataError("UITreeRow for '"..entry.Type.."' has an out of bound UITreeRow="..tostring(entry.UITreeRow).."  MIN="..tostring(ROW_MIN).."  MAX="..tostring(ROW_MAX));
    end

    -- Only build up a limited number of eras if debug information is forcing a subset.
    if m_debugFilterEraMaxIndex < 1 or m_debugFilterEraMaxIndex ~= -1 then
      m_kItemDefaults[entry.Type] = entry;
      index = index + 1;
    end

    if m_kEraCounter[entry.EraType] == nil then
      m_kEraCounter[entry.EraType] = 0;
    end
    m_kEraCounter[entry.EraType] = m_kEraCounter[entry.EraType] + 1;
  end
end


-- ===========================================================================
--  Create a hash table of EraType to its chronological index.
-- ===========================================================================
function PopulateEraData()
  m_kEras = {};
  for row:table in GameInfo.Eras() do
    if m_kEraCounter[row.EraType] and m_kEraCounter[row.EraType] > 0 and m_debugFilterEraMaxIndex < 1 or row.ChronologyIndex <= m_debugFilterEraMaxIndex then
      m_kEras[row.EraType] = {
        BGTexture = row.EraCivicBackgroundTexture,
        BGTextureOffsetX = row.EraCivicBackgroundTextureOffsetX,
        NumColumns  = 0,
        Description = Locale.Lookup(row.Name),
        Index   = row.ChronologyIndex,
        PriorColumns= -1          -- Will not be known until UI is laid out
      }
    end
  end
end


-- ===========================================================================
--
-- ===========================================================================
function PopulateFilterData()

  -- Filters.
  m_kFilters = {};
  table.insert( m_kFilters, { Func=nil,                   Description="LOC_TECH_FILTER_NONE",     Icon=nil } );

  table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_FOOD"],      Description="LOC_TECH_FILTER_FOOD",     Icon="[ICON_FOOD]" });
  table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_SCIENCE"],   Description="LOC_TECH_FILTER_SCIENCE",    Icon="[ICON_SCIENCE]" });
  table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_PRODUCTION"],  Description="LOC_TECH_FILTER_PRODUCTION", Icon="[ICON_PRODUCTION]" });
  table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_CULTURE"],   Description="LOC_TECH_FILTER_CULTURE",    Icon="[ICON_CULTURE]" });
  table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_GOLD"],      Description="LOC_TECH_FILTER_GOLD",     Icon="[ICON_GOLD]" });
  table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_UNITS"],     Description="LOC_TECH_FILTER_UNITS",    Icon="[ICON_UNITS]" });
  table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_IMPROVEMENTS"],  Description="LOC_TECH_FILTER_IMPROVEMENTS", Icon="[ICON_IMPROVEMENTS]" });
  table.insert( m_kFilters, { Func=g_TechFilters["TECHFILTER_WONDERS"],   Description="LOC_TECH_FILTER_WONDERS",    Icon="[ICON_WONDERS]" });

  for i,filter in ipairs(m_kFilters) do
    local filterLabel  = Locale.Lookup( filter.Description );
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
  local searchContext = "Civics";
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

    -- Hash civic types that grant envoys or spies via modifiers.
    local envoyCivics = {};
    local spyCivics = {};
    for row in GameInfo.CivicModifiers() do			
      local modifier = GameInfo.Modifiers[row.ModifierId];
      if(modifier) then
        local modifierType = modifier.ModifierType;
        if(envoyModifierTypes[modifierType]) then
          envoyCivics[row.CivicType] = true;
        end

        if(spyModifierTypes[modifierType]) then
          spyCivics[row.CivicType] = true;
        end
      end
    end

    local envoyTypeName = Locale.Lookup("LOC_ENVOY_NAME");
    local spyTypeName = Locale.Lookup("LOC_SPY_NAME");

    for row in GameInfo.Civics() do
      local civicType = row.CivicType;
      local description = row.Description and Locale.Lookup(row.Description) or "";
      local tags = {};
      if(envoyCivics[civicType]) then
        table.insert(tags, envoyTypeName);
      end

      if(spyCivics[civicType]) then
        table.insert(tags, spyTypeName);
      end

      Search.AddData(searchContext, civicType, Locale.Lookup(row.Name), description, tags);
    end

    local buildingTypeName = Locale.Lookup("LOC_BUILDING_NAME");
    local wonderTypeName = Locale.Lookup("LOC_WONDER_NAME");
    for row in GameInfo.Buildings() do
      if(row.PrereqCivic) then
        local tags = {buildingTypeName};
        if(row.IsWonder) then
          table.insert(tags, wonderTypeName);
        end

        Search.AddData(searchContext, row.PrereqCivic, Locale.Lookup(GameInfo.Civics[row.PrereqCivic].Name), Locale.Lookup(row.Name), tags);
      end
    end

    local districtTypeName = Locale.Lookup("LOC_DISTRICT_NAME");
    for row in GameInfo.Districts() do
      if(row.PrereqCivic) then
        Search.AddData(searchContext, row.PrereqCivic, Locale.Lookup(GameInfo.Civics[row.PrereqCivic].Name), Locale.Lookup(row.Name), { districtTypeName });
      end
    end

    local governmentTypeName = Locale.Lookup("LOC_GOVERNMENT_NAME");
    for row in GameInfo.Governments() do
      if(row.PrereqCivic) then
        Search.AddData(searchContext, row.PrereqCivic, Locale.Lookup(GameInfo.Civics[row.PrereqCivic].Name), Locale.Lookup(row.Name), { governmentTypeName });
      end
    end

    local improvementTypeName = Locale.Lookup("LOC_IMPROVEMENT_NAME");
    for row in GameInfo.Improvements() do
      if(row.PrereqCivic) then
        Search.AddData(searchContext, row.PrereqCivic, Locale.Lookup(GameInfo.Civics[row.PrereqCivic].Name), Locale.Lookup(row.Name), { improvementTypeName });
      end
    end

    local policyTypeName = Locale.Lookup("LOC_POLICY_NAME");
    for row in GameInfo.Policies() do
      if(row.PrereqCivic) then
        Search.AddData(searchContext, row.PrereqCivic, Locale.Lookup(GameInfo.Civics[row.PrereqCivic].Name), Locale.Lookup(row.Name), { policyTypeName });
      end
    end

    local projectTypeName = Locale.Lookup("LOC_PROJECT_NAME");
    for row in GameInfo.Projects() do
      if(row.PrereqCivic) then
        Search.AddData(searchContext, row.PrereqCivic, Locale.Lookup(GameInfo.Civics[row.PrereqCivic].Name), Locale.Lookup(row.Name), { projectTypeName });
      end
    end

    local resourceTypeName = Locale.Lookup("LOC_RESOURCE_NAME");
    for row in GameInfo.Resources() do
      if(row.PrereqCivic) then
        Search.AddData(searchContext, row.PrereqCivic, Locale.Lookup(GameInfo.Civics[row.PrereqCivic].Name), Locale.Lookup(row.Name), { resourceTypeName });
      end
    end

    local unitTypeName = Locale.Lookup("LOC_UNIT_NAME");
    for row in GameInfo.Units() do
      if(row.PrereqCivic) then
        Search.AddData(searchContext, row.PrereqCivic, Locale.Lookup(GameInfo.Civics[row.PrereqCivic].Name), Locale.Lookup(row.Name), { unitTypeName });
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
--  filterFunc,   The funciton filter to apply to each node as it's built,
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
  m_kCurrentData = GetLivePlayerData( m_ePlayer );
  View( m_kCurrentData );
  ContextPtr:SetHide(false);

  -- From ModalScreen_PlayerYieldsHelper
  RefreshYields();

  -- From Civ6_styles: FullScreenVignetteConsumer
  Controls.ScreenAnimIn:SetToBeginning();
  Controls.ScreenAnimIn:Play();

  LuaEvents.CivicsTree_OpenCivicsTree();
  Controls.SearchEditBox:TakeFocus();
end

-- ===========================================================================
--  Show the Key panel based on the state
-- ===========================================================================
function RealizeKeyPanel()
  if UserConfiguration.GetShowCivicsTreeKey() then
    Controls.KeyPanel:SetHide( false );
    UI.PlaySound("UI_TechTree_Filter_Open");
  else
    if Controls.KeyPanel:IsHidden() then
      UI.PlaySound("UI_TechTree_Filter_Closed");
    end
    Controls.KeyPanel:SetHide( true );
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
function OnClickCurrentPolicy(clickedPolicy:number)
  local percent:number = 0;
  local prereqCivic:string = GameInfo.Policies[clickedPolicy].PrereqCivic;
  percent = (m_uiNodes[prereqCivic].x - PADDING_TIMELINE_LEFT)/(m_maxColumns * COLUMN_WIDTH);
  Controls.NodeScroller:SetScrollValue(percent);

end

-- ===========================================================================
--  Show the Key panel based on the state
-- ===========================================================================
function RealizeGovernmentPanel()
  m_kDiplomaticPolicyIM:DestroyInstances();
  m_kEconomicPolicyIM:DestroyInstances();
  m_kMilitaryPolicyIM:DestroyInstances();
  m_kWildcardPolicyIM:DestroyInstances();
  -- m_kDiplomaticPolicyIM = InstanceManager:new( "DiplomaticPolicyInstance",  "DiplomaticPolicy",   Controls.DiplomaticStack );
  -- m_kEconomicPolicyIM = InstanceManager:new( "EconomicPolicyInstance",  "EconomicPolicy",   Controls.EconomicStack );
  -- m_kMilitaryPolicyIM = InstanceManager:new( "MilitaryPolicyInstance",  "MilitaryPolicy",   Controls.MilitaryStack );
  -- m_kWildcardPolicyIM = InstanceManager:new( "WildcardPolicyInstance",  "WildcardPolicy",   Controls.WildcardStack );

  if UserConfiguration.GetShowCivicsTreeGovernment() then
    Controls.GovernmentPanel:SetHide( false );
    UI.PlaySound("UI_TechTree_Filter_Open");
  else
    if Controls.GovernmentPanel:IsHidden() then
      UI.PlaySound("UI_TechTree_Filter_Closed");
    end
    Controls.GovernmentPanel:SetHide( true );
  end

  if Controls.GovernmentPanel:IsHidden() then
    Controls.ToggleGovernmentButton:SetText(Locale.Lookup("LOC_TREE_SHOW_GOVERNMENT"));
    Controls.ToggleGovernmentButton:SetSelected(false);
  else
    Controls.ToggleGovernmentButton:SetText(Locale.Lookup("LOC_TREE_HIDE_GOVERNMENT"));
    Controls.ToggleGovernmentButton:SetSelected(true);
  end

  TruncateStringWithTooltip( Controls.GovernmentTitle, MAX_BEFORE_TRUNC_GOV_TITLE, Locale.ToUpper(m_kCurrentData[DATA_FIELD_GOVERNMENT]["NAMES"]));
  Controls.DiplomaticIconCount:SetText(tostring(m_kCurrentData[DATA_FIELD_GOVERNMENT]["DIPLOMATIC"]));
  Controls.EconomicIconCount:SetText(tostring(m_kCurrentData[DATA_FIELD_GOVERNMENT]["ECONOMIC"]));
  Controls.MilitaryIconCount:SetText(tostring(m_kCurrentData[DATA_FIELD_GOVERNMENT]["MILITARY"]));
  Controls.WildcardIconCount:SetText(tostring(m_kCurrentData[DATA_FIELD_GOVERNMENT]["WILDCARD"]));

  local int numDiploResults = #m_kCurrentData[DATA_FIELD_GOVERNMENT]["DIPLOMATICPOLICIES"];
  for i,policy in ipairs(m_kCurrentData[DATA_FIELD_GOVERNMENT]["DIPLOMATICPOLICIES"]) do
    if(policy ~= -1) then
      local diploInst:table = m_kDiplomaticPolicyIM:GetInstance();
      local policyType:string = GameInfo.Policies[policy].Name;
      if numDiploResults > 3 then
        diploInst.DiplomaticPolicy:SetSizeVal(111/numDiploResults, 44 * (3/numDiploResults));
      end
      diploInst.DiplomaticPolicy:SetToolTipString(m_kPolicyCatalogData[policyType].Name .. ": " .. m_kPolicyCatalogData[policyType].Description);
      diploInst.DiplomaticPolicy:RegisterCallback( Mouse.eLClick, function() OnClickCurrentPolicy(policy) end );
    end
  end

  local int numEcoResults = #m_kCurrentData[DATA_FIELD_GOVERNMENT]["ECONOMICPOLICIES"];
  for i,policy in ipairs(m_kCurrentData[DATA_FIELD_GOVERNMENT]["ECONOMICPOLICIES"]) do
    if(policy ~= -1) then
      local ecoInst:table = m_kEconomicPolicyIM:GetInstance();
      local policyType:string = GameInfo.Policies[policy].Name
      if numEcoResults > 3 then
        ecoInst.EconomicPolicy:SetSizeVal(111/numEcoResults, 44 * (3/numEcoResults));
      end
      local description:string = m_kPolicyCatalogData[policyType].Name .. ": " .. m_kPolicyCatalogData[policyType].Description
      ecoInst.EconomicPolicy:SetToolTipString(description);
      ecoInst.EconomicPolicy:RegisterCallback( Mouse.eLClick, function() OnClickCurrentPolicy(policy) end );
    end
  end

  local int numMilResults = #m_kCurrentData[DATA_FIELD_GOVERNMENT]["MILITARYPOLICIES"];
  for i,policy in ipairs(m_kCurrentData[DATA_FIELD_GOVERNMENT]["MILITARYPOLICIES"]) do
    if(policy ~= -1) then
      local milInst:table = m_kMilitaryPolicyIM:GetInstance();
      local policyType:string = GameInfo.Policies[policy].Name
      if numMilResults > 3 then
        milInst.MilitaryPolicy:SetSizeVal(111/numMilResults, 44 * (3/numMilResults));
      end
      milInst.MilitaryPolicy:SetToolTipString(m_kPolicyCatalogData[policyType].Name .. ": " .. m_kPolicyCatalogData[policyType].Description);
      milInst.MilitaryPolicy:RegisterCallback( Mouse.eLClick, function() OnClickCurrentPolicy(policy) end );
    end
  end

  local int numWildResults = #m_kCurrentData[DATA_FIELD_GOVERNMENT]["WILDCARDPOLICIES"];
  for i,policy in ipairs(m_kCurrentData[DATA_FIELD_GOVERNMENT]["WILDCARDPOLICIES"]) do
    if(policy ~= -1) then
      local wildInst:table = m_kWildcardPolicyIM:GetInstance();
      local policyType:string = GameInfo.Policies[policy].Name;
      local slotType:string =  GameInfo.Policies[policy].GovernmentSlotType;
      if slotType == "SLOT_DIPLOMATIC" then
        wildInst.WildcardPolicy:SetTexture("Governments_DiplomacyCard_Small");
      else
        if slotType == "SLOT_ECONOMIC" then
          wildInst.WildcardPolicy:SetTexture("Governments_EconomicCard_Small");
        else
          if slotType == "SLOT_MILITARY" then
            wildInst.WildcardPolicy:SetTexture("Governments_MilitaryCard_Small");
          end
        end
      end
      if numWildResults > 3 then
        wildInst.WildcardPolicy:SetSizeVal(111/numWildResults, 44 * (3/numWildResults));
      end
      wildInst.WildcardPolicy:SetToolTipString(m_kPolicyCatalogData[policyType].Name .. ": " .. m_kPolicyCatalogData[policyType].Description);
      wildInst.WildcardPolicy:RegisterCallback( Mouse.eLClick, function() OnClickCurrentPolicy(policy) end );
    end
  end

end

-- ===========================================================================
--  Fill the catalog with the static (unchanging) policy data used by
--  all players when viewing the screen.
-- ===========================================================================
function PopulateStaticData()

  -- Fill in the complete catalog of policies.
  m_kPolicyCatalogData = {};
  for row in GameInfo.Policies() do
    local policyTypeRow   :table  = GameInfo.Types[row.PolicyType];
    local policyName    :string = Locale.Lookup(row.Name);
    local policyTypeHash  :number = policyTypeRow.Hash;
    local slotType      :string = row.GovernmentSlotType;
    local description   :string = Locale.Lookup(row.Description);
    --local draftCost     :number = kPlayerCulture:GetEnactPolicyCost(policyTypeHash);  --Move to live data

    m_kPolicyCatalogData[row.Name] = {
      Description = description,
      Name    = policyName,
      PolicyHash  = policyTypeHash,
      SlotType  = slotType,     -- SLOT_MILITARY, SLOT_ECONOMIC, SLOT_DIPLOMATIC, SLOT_WILDCARD, (SLOT_GREAT_PERSON)
      UniqueID  = row.Index     -- the row this policy exists in, is guaranteed to be unique (as-is the house, but these are readable. ;) )
      };
  end

  -- Fill in governments
  m_kGovernments = {};
  for row in GameInfo.Governments() do
    local government    :table  = GameInfo.Types[row.GovernmentType];
    local slotMilitary    :number = 0;
    local slotEconomic    :number = 0;
    local slotDiplomatic  :number = 0;
    local slotWildcard    :number = 0;
    for entry in GameInfo.Government_SlotCounts() do
      if row.GovernmentType == entry.GovernmentType then
        local slotType = entry.GovernmentSlotType;
        for i = 1, entry.NumSlots, 1 do
          if    slotType == "SLOT_MILITARY" then                  slotMilitary  = slotMilitary + 1;
          elseif  slotType == "SLOT_ECONOMIC" then                  slotEconomic  = slotEconomic + 1;
          elseif  slotType == "SLOT_DIPLOMATIC" then                  slotDiplomatic  = slotDiplomatic + 1;
          elseif  slotType == "SLOT_WILDCARD" or slotType=="SLOT_GREAT_PERSON" then slotWildcard  = slotWildcard + 1;
          end
        end
      end
    end

    m_kGovernments[row.Name] = {
      BonusAccumlatedText = row.AccumulatedBonusDesc,
      BonusInherentText = row.InherentBonusDesc,
      BonusType     = row.BonusType,
      Hash        = government.Hash,
      Index       = row.Index,
      Name        = row.Name,
      NumSlotMilitary   = slotMilitary,
      NumSlotEconomic   = slotEconomic,
      NumSlotDiplomatic = slotDiplomatic,
      NumSlotWildcard   = slotWildcard
    }
  end

end

-- ===========================================================================
--  Show/Hide key panel
-- ===========================================================================
function OnClickToggleKey()
  if Controls.KeyPanel:IsHidden() then
    UserConfiguration.SetShowCivicsTreeKey(true);
  else
        UI.PlaySound("UI_TechTree_Filter_Closed");
    UserConfiguration.SetShowCivicsTreeKey(false);
  end
  RealizeKeyPanel();
end
Controls.ToggleKeyButton:RegisterCallback(Mouse.eLClick, OnClickToggleKey);

function OnClickToggleGovernment()
  if Controls.GovernmentPanel:IsHidden() then
    UserConfiguration.SetShowCivicsTreeGovernment(true);
  else
        UI.PlaySound("UI_TechTree_Filter_Closed");
    UserConfiguration.SetShowCivicsTreeGovernment(false);
  end
  RealizeGovernmentPanel();
end
Controls.ToggleGovernmentButton:RegisterCallback(Mouse.eLClick, OnClickToggleGovernment);

function OnClickToggleFilter()
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
  LuaEvents.CivicsTree_CloseCivicsTree();
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
  LuaEvents.CivicsPanel_RaiseCivicsTree.Remove( OnOpen );
  LuaEvents.LaunchBar_RaiseCivicsTree.Remove( OnOpen );
  LuaEvents.LaunchBar_CloseCivicsTree.Remove( OnClose );

  Events.GovernmentChanged.Remove( OnGovernmentChanged );
  Events.GovernmentPolicyChanged.Remove( OnGovernmentPolicyChanged );
  Events.GovernmentPolicyObsoleted.Remove( OnGovernmentPolicyChanged );
  Events.LocalPlayerTurnBegin.Remove( OnLocalPlayerTurnBegin );
  Events.LocalPlayerTurnEnd.Remove( OnLocalPlayerTurnEnd );
  Events.CivicChanged.Remove( OnCivicChanged );
  Events.CivicCompleted.Remove( OnCivicComplete );
  Events.SystemUpdateUI.Remove( OnUpdateUI );

  Search.DestroyContext("Civics");
end

-- ===========================================================================
--  Centers scroll panel (if possible) on a specfic type.
-- ===========================================================================
function ScrollToNode( typeName:string )
  local percent:number = 0;
  local x   = m_uiNodes[typeName].x - ( m_width * 0.5);
  local size  = (m_width / Controls.NodeScroller:GetRatio()) - m_width;
  percent = math.clamp( x  / size, 0, 1);
  Controls.NodeScroller:SetScrollValue(percent);
  m_kSearchResultIM:DestroyInstances();
  Controls.SearchResultsPanelContainer:SetHide(true);
end

-- ===========================================================================
--	Searching
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
    Controls.SearchResultsStack:ReprocessAnchoring();
    Controls.SearchResultsPanel:CalculateSize();
    Controls.SearchResultsPanelContainer:SetHide(true);

  elseif(str and #str > 0) then
    local hasResults = false;
    m_kSearchResultIM:DestroyInstances();
    local results = Search.Search("Civics", str, 100);
    if (results and #results > 0) then
      hasResults = true;
      local has_found = {};
      for i, v in ipairs(results) do
        if has_found[v[1]] == nil then
          -- v[1] == Type
          -- v[2] == Name w/ search term highlighted.
          -- v[3] == Snippet description w/ search term highlighted.
          local instance = m_kSearchResultIM:GetInstance();

          -- Search results already localized.
          local name = v[2];
          instance.Name:SetText(name);
          local iconName = DATA_ICON_PREFIX .. v[1];
          instance.SearchIcon:SetIcon(iconName);

          instance.Button:RegisterCallback(Mouse.eLClick, function() 
            Controls.SearchEditBox:SetText(defaultText);
            ScrollToNode(v[1]); 
          end);

          instance.Button:SetToolTipString(ToolTipHelper.GetToolTip(v[1], Game.GetLocalPlayer()));
          has_found[v[1]] = true;
        end
      end
    end
    
    Controls.SearchResultsStack:CalculateSize();
    Controls.SearchResultsStack:ReprocessAnchoring();
    Controls.SearchResultsPanel:CalculateSize();
    Controls.SearchResultsPanelContainer:SetHide(not hasResults);
  end
end

function OnSearchCommitCallback()
  local str = Controls.SearchEditBox:GetText();

  local defaultText = Locale.Lookup("LOC_TREE_SEARCH_W_DOTS")
  if(str and #str > 0 and str ~= defaultText) then
    local results = Search.Search("Civics", str, 1);
    if (results and #results > 0) then
      local result = results[1];
      if(result) then
        ScrollToNode(result[1]); 
      end
    end

    Controls.SearchEditBox:SetText(defaultText);
  end
end

function OnSearchBarGainFocus()
  Controls.SearchResultsTimer:Stop();
  Controls.SearchEditBox:ClearString();
end

function OnSearchBarLoseFocus()
  Controls.SearchEditBox:SetText(Locale.Lookup("LOC_TREE_SEARCH_W_DOTS"));
end

function OnSearchResultsTimerEnd()
  m_kSearchResultIM:DestroyInstances();
      Controls.SearchResultsStack:CalculateSize();
      Controls.SearchResultsStack:ReprocessAnchoring();
      Controls.SearchResultsPanel:CalculateSize();
      Controls.SearchResultsPanelContainer:SetHide(true);
end

function OnSearchResultsPanelContainerMouseEnter()
  Controls.SearchResultsTimer:Stop();
end

function OnSearchResultsPanelContainerMouseExit()
  if(not Controls.SearchEditBox:HasFocus()) then
    Controls.SearchResultsTimer:SetToBeginning();
    Controls.SearchResultsTimer:Play();
  end
end

-- ===========================================================================
function OnCityInitialized(owner, ID)
  if (owner == m_ePlayer) then
    RefreshDataIfNeeded( );
  end
end

-- ===========================================================================
function OnBuildingChanged( plotX:number, plotY:number, buildingIndex:number, playerID:number, iPercentComplete:number )
  if playerID == m_ePlayer then
    RefreshDataIfNeeded( ); -- Buildings can change culture/science yield which can effect "turns to complete" values
  end
end


-- ===========================================================================
--  Load all static information as well as display information for the
--  current local player.
-- ===========================================================================
function Initialize()

  PopulateStaticData();
  PopulateItemData("Civics","CivicType","CivicPrereqs","Civic","PrereqCivic");
  PopulateEraData();
  PopulateFilterData();
  PopulateSearchData();

  AllocateUI();

  -- May be observation mode.
  m_ePlayer = Game.GetLocalPlayer();
  if (m_ePlayer == -1) then
    return;
  end

  Resize(); -- Now that view has been called once, size of tree is known.

  m_kCurrentData = GetLivePlayerData( m_ePlayer );
  View( m_kCurrentData );


  -- UI Events
  ContextPtr:SetInputHandler( OnInputHandler, true );
  ContextPtr:SetShutdown( OnShutdown );

  Controls.SearchEditBox:RegisterStringChangedCallback(OnSearchCharCallback);
  Controls.SearchEditBox:RegisterHasFocusCallback( OnSearchBarGainFocus);
  Controls.SearchEditBox:RegisterCommitCallback( OnSearchBarLoseFocus);
  Controls.SearchResultsTimer:RegisterEndCallback(OnSearchResultsTimerEnd);
  Controls.SearchResultsPanelContainer:RegisterMouseEnterCallback(OnSearchResultsPanelContainerMouseEnter);
  Controls.SearchResultsPanelContainer:RegisterMouseExitCallback(OnSearchResultsPanelContainerMouseExit);

  local pullDownButton = Controls.FilterPulldown:GetButton();
  pullDownButton:RegisterCallback(Mouse.eLClick, OnClickToggleFilter);

  -- LUA Events
  LuaEvents.CivicsChooser_RaiseCivicsTree.Add( OnOpen );
  LuaEvents.LaunchBar_RaiseCivicsTree.Add( OnOpen );
  LuaEvents.LaunchBar_CloseCivicsTree.Add( OnClose );

  -- Game engine Event
  Events.CityInitialized.Add( OnCityInitialized );
  Events.BuildingChanged.Add( OnBuildingChanged );
  Events.CivicChanged.Add( OnCivicChanged );
  Events.CivicCompleted.Add( OnCivicComplete );
  Events.GovernmentChanged.Add( OnGovernmentChanged );
  Events.GovernmentPolicyChanged.Add( OnGovernmentPolicyChanged );
  Events.GovernmentPolicyObsoleted.Add( OnGovernmentPolicyChanged );
  Events.LocalPlayerTurnBegin.Add( OnLocalPlayerTurnBegin );
  Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );
  Events.LocalPlayerChanged.Add(AllocateUI);
  Events.SystemUpdateUI.Add( OnUpdateUI );

  -- CQUI add exceptions to the 50% notifications by putting civics into the CQUI_halfwayNotified table
  CQUI_halfwayNotified["LOC_CIVIC_CODE_OF_LAWS_NAME"] = true;

end

if HasCapability("CAPABILITY_CIVICS_CHOOSER") then
  Initialize();
end
