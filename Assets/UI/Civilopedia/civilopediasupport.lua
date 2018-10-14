-- ===========================================================================
--  Civilopedia Support
--  Includes the main logic to populate the civilopedia.
-- ===========================================================================
include( "InstanceManager" );
include("civ6common");


local LOC_TREE_SEARCH_W_DOTS = Locale.Lookup("LOC_TREE_SEARCH_W_DOTS");

local _SearchResultsManager = InstanceManager:new("SearchResultInstance", "Root", Controls.SearchResultsStack);

local _SectionTabManager = InstanceManager:new("CivilopediaSectionTabInstance", "Root", Controls.CivilopediaSectionTabStack);
local _PageTabManager = InstanceManager:new("CivilopediaPageTabInstance", "Root", Controls.CivilopediaPageTabStack);

local _ChapterManager = InstanceManager:new("CivilopediaChapter", "Root", Controls.PageChaptersStack);
local _ChapterParagraphManager = InstanceManager:new("CivilopediaChapterParagraph", "Paragraph", Controls.PageChaptersStack);

local _LeftColumnChapterManager = InstanceManager:new("CivilopediaLeftColumnChapter", "Root", Controls.LeftColumnStack);
local _LeftColumnChapterParagraphManager = InstanceManager:new("CivilopediaLeftColumnChapterParagraph", "Paragraph", Controls.LeftColumnStack);
local _LeftColumnIconHeaderBodyManager = InstanceManager:new("CivilopediaLeftColumnIconHeaderBody", "Root", Controls.LeftColumnStack);
local _LeftColumnHeaderBodyManager = InstanceManager:new("CivilopediaLeftColumnHeaderBody", "Root", Controls.LeftColumnStack);


local _RightColumnPortraitManager = InstanceManager:new("RightColumnPortrait", "Root", Controls.RightColumnStack);
local _RightColumnTallPortraitManager = InstanceManager:new("RightColumnPortraitTall", "Root", Controls.RightColumnStack);
local _RightColumnTallPortraitNoScalingManager = InstanceManager:new("RightColumnPortraitTallNoScaling", "Root", Controls.RightColumnStack); 

local _RightColumnQuoteManager = InstanceManager:new("RightColumnQuote", "Root", Controls.RightColumnStack);

local _RightColumnStatBoxManager = InstanceManager:new("RightColumnStatBox", "Root", Controls.RightColumnStack);

local _RightColumnStatSeparatorManager = InstanceManager:new("RightColumnStatSeparator", "Root", nil);
local _RightColumnStatHeaderManager = InstanceManager:new("RightColumnStatHeader", "Caption", nil);
local _RightColumnStatLabelManager = InstanceManager:new("RightColumnStatLabel", "Caption", nil);
local _RightColumnStatSmallLabelManager = InstanceManager:new("RightColumnStatSmallLabel", "Caption", nil);
local _RightColumnStatIconLabelManager = InstanceManager:new("RightColumnStatIconLabel", "Root", nil);
local _RightColumnStatIconNumberLabelManager = InstanceManager:new("RightColumnStatIconNumberLabel", "Root", nil);
local _RightColumnStatIconListManager = InstanceManager:new("RightColumnStatIconList", "Root", nil);

_HasSection = {};
_Sections = {};
_PagesBySection = {};
_PagesById = {}; 
_PageGroupsBySection = {};
_ChaptersByPageLayout = {};
_ChapterOverrides = {};
_PageLayoutScriptTemplates = {};

PageLayouts = {};

-- Specifies the layout of content.
_PageContentLayout = nil; -- Possible values are nil, "full" or "two-column".

local _SearchQuery = nil;
local _LastSection = nil;
local _LastPage = nil;

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function CacheData_FetchData()

  local exclude = {};

  if(GameInfo.CivilopediaSectionExcludes) then
    for row in GameInfo.CivilopediaSectionExcludes() do
      exclude[row.SectionId] = true;
    end
  end

  if(GameInfo.CivilopediaPageExcludes) then
    for row in GameInfo.CivilopediaPageExcludes() do
      exclude[row.SectionId .. "::" .. row.PageId] = true;
    end
  end
    if(GameInfo.CivilopediaPageGroupExcludes) then
    for row in GameInfo.CivilopediaPageGroupExcludes() do
      exclude[row.SectionId .. "|:" .. row.PageGroupId] = true;
    end
  end

  -- Cache Sections
  if(GameInfo.CivilopediaSections) then
    for row in GameInfo.CivilopediaSections() do
      if(exclude[row.SectionId] ~= true) then
        local section = {
          SectionId = row.SectionId,
          Name = row.Name,
          Tooltip = row.Tooltip,
          Icon = row.Icon,
          SortIndex = row.SortIndex
        };
        _HasSection[row.SectionId] = true;
        table.insert(_Sections, section);
      end
    end
  end

  function AddPage(page)
    if( exclude[page.SectionId] ~= true and
      exclude[page.SectionId .. "::" .. page.PageId] ~= true and
      (page.PageGroupId == nil or exclude[page.SectionId .. "|:" .. page.PageGroupId] ~= true)) then
      local sectionId = page.SectionId;
      if(_HasSection[sectionId]) then
        if(_PagesBySection[sectionId] == nil) then
          _PagesBySection[sectionId] = {};
        end

      table.insert(_PagesBySection[sectionId], page);

      local key = page.SectionId .. "::" .. page.PageId;
      _PagesById[key] = page;
 
      end
    end
  end

  function AddPageGroup(page_group)
    if( exclude[page_group.SectionId] ~= true and
      (page_group.PageGroupId == nil or exclude[page_group.SectionId .. "|:" .. page_group.PageGroupId] ~= true)) then
      local sectionId = page_group.SectionId;
      if(_HasSection[sectionId]) then
        if(_PageGroupsBySection[sectionId] == nil) then
          _PageGroupsBySection[sectionId] = {};
        end

        table.insert(_PageGroupsBySection[sectionId], page_group);
      end
    end
  end

  -- Cache PageGroups and Pages.
  if(GameInfo.CivilopediaPageGroups) then
    for row in GameInfo.CivilopediaPageGroups() do
      local page_group = {
        SectionId = row.SectionId,
        PageGroupId = row.PageGroupId,
        Name = row.Name,
        Tooltip = row.Tooltip,
        VisibleIfEmpty = row.VisibleIfEmpty,
        SortIndex = row.SortIndex
      };
      AddPageGroup(page_group);
    end
  end

  if(GameInfo.CivilopediaPages) then
    for row in GameInfo.CivilopediaPages() do
      local page = {
        SectionId = row.SectionId,
        PageId = row.PageId,
        PageGroupId = row.PageGroupId,
        PageLayoutId = row.PageLayoutId,
        Name = row.Name,
        TextKeyPrefix = row.TextKeyPrefix, 
        Tooltip = row.Tooltip,
        SortIndex = row.SortIndex
      };
      AddPage(page);
    end
  end

  if(GameInfo.CivilopediaPageGroupQueries) then
    for q in GameInfo.CivilopediaPageGroupQueries() do
      for i, row in ipairs(DB.Query(q.SQL)) do
        local page_group = {
          SectionId = q.SectionId,
          PageGroupId = q.PageGroupIdColumn and row[q.PageGroupIdColumn],
          Name = row[q.NameColumn],
          Tooltip = q.TooltipColumn and row[q.TooltipColumn],
          VisibleIfEmpty = q.VisibleIfEmptyColumn and row[q.VisibleIfEmptyColumn] or false,
          SortIndex = q.SortIndexColumn and row[q.SortIndexColumn] or q.SortIndex
        };
        AddPageGroup(page_group);
      end
    end
  end

  if(GameInfo.CivilopediaPageQueries) then
    for q in GameInfo.CivilopediaPageQueries() do
      for i, row in ipairs(DB.Query(q.SQL)) do
        local page = {
          SectionId = q.SectionId,
          PageId = row[q.PageIdColumn],
          PageGroupId = q.PageGroupIdColumn and row[q.PageGroupIdColumn],
          PageLayoutId = row[q.PageLayoutIdColumn],
          Name = row[q.NameColumn],
          Tooltip = q.TooltipColumn and row[q.TooltipColumn],
          TextKeyPrefix = q.TextKeyPrefixColumn and row[q.TextKeyPrefixColumn], 
          SortIndex = q.SortIndexColumn and row[q.SortIndexColumn] or q.SortIndex
        };
        AddPage(page);
      end
    end
  end

  -- Cache Chapters by Page Layout
  if(GameInfo.CivilopediaPageLayoutChapters) then
    for q in GameInfo.CivilopediaPageLayoutChapters() do
      local page_layout = {
        PageLayoutId = q.PageLayoutId,
        ChapterId = q.ChapterId,
        SortIndex = q.SortIndex,
      }

      if(_ChaptersByPageLayout[q.PageLayoutId] == nil) then
        _ChaptersByPageLayout[q.PageLayoutId] = {};
      end
      table.insert(_ChaptersByPageLayout[q.PageLayoutId], page_layout);
    end
  end

  -- Cache Chapter overrides
  if(GameInfo.CivilopediaPageChapterHeaders) then
    for row in GameInfo.CivilopediaPageChapterHeaders() do
      local key = row.SectionId .. "|" .. row.PageId .. "|" .. row.ChapterId;
      local chapter = _ChapterOverrides[key] or {};
      chapter.Header = row.Header;
      _ChapterOverrides[key] = chapter;			
    end
  end

  if(GameInfo.CivilopediaPageChapterParagraphs) then
    -- Index all paragraphs.
    local paragraphs = {};
    for row in GameInfo.CivilopediaPageChapterParagraphs() do
      local key = row.SectionId .. "|" .. row.PageId .. "|" .. row.ChapterId;
      local chapter = paragraphs[key] or {};
      table.insert(chapter, row);
      paragraphs[key] = chapter;
    end

    -- Sort the paragraphs, and add to chapter overrides.
    local sort = function(a,b)	return a.SortIndex < b.SortIndex end;

    for key, v in pairs(paragraphs) do
      table.sort(v, sort);
      local chapter = _ChapterOverrides[key] or {};
      local body = {};

      for i, p in ipairs(v) do
        table.insert(body, p.Paragraph);
      end

      chapter.Body = body;
      _ChapterOverrides[key] = chapter;
    end
  end
  
  -- Cache Layouts
  if(GameInfo.CivilopediaPageLayouts) then
    for q in GameInfo.CivilopediaPageLayouts() do
      _PageLayoutScriptTemplates[q.PageLayoutId] = q.ScriptTemplate;
    end
  end


end


-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function CacheData_ProcessData()
  for i, section in ipairs(_Sections) do
    local sectionId = section.SectionId;
    local tab_key = FindSectionTextKey(sectionId, "TAB_NAME");

    tab_key = tab_key or section.Name;
    tab_key = tab_key or section.PageId;

    section.TabName = Locale.Lookup(tab_key);
  end

  -- Populate Additional Data
  for sectionId, pages in pairs(_PagesBySection) do
    for i, page in ipairs(pages) do

      local sectionId = page.SectionId;
      local pageId = page.PageId;

      local tab_key = FindPageTextKey(sectionId, pageId, "TAB_NAME");
      local title_key = FindPageTextKey(sectionId, pageId, "TITLE");
      local subtitle_key = FindPageTextKey(sectionId, pageId, "SUBTITLE");

      tab_key = tab_key or page.Name;
      tab_key = tab_key or page.PageId;

      title_key = title_key or page.Name;
      title_key = title_key or page.PageId;

      page.TabName = Locale.Lookup(tab_key);
      page.Title = Locale.Lookup(title_key);

      if(subtitle_key) then
        page.SubTitle = Locale.Lookup(subtitle_key);
      end
    end
  end

  for sectionId, groups in pairs(_PageGroupsBySection) do
    for i, group in ipairs(groups) do
      local tab_key = FindPageTextKey(sectionId, group.PageGroupId, "TAB_NAME");
      tab_key = tab_key or group.Name;
      tab_key = tab_key or group.PageGroupId;

      group.TabName = Locale.Lookup(tab_key);
    end
  end
end


-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function CacheData_SortData()
  -- Sort Cached Data
  function SortNumberOrNil(a, b)
    if(a == nil and b ~= nil) then
      return true;
    elseif(b == nil) then
      return false;
    else
      return a < b;
    end
  end

  function SortPageGroups(a, b)
    if(a == nil and b ~= nil) then
      return true;
    elseif(b == nil) then
      return false;
    elseif(a.SortIndex ~= b.SortIndex) then
      return SortNumberOrNil(a.SortIndex, b.SortIndex);
    else
      return Locale.Compare(a.TabName, b.TabName) == -1;
    end
  end

  -- Sort pages
  function SortPages(sectionId, a, b)
    if(a.PageGroupId ~= b.PageGroupId) then
      local groups = _PageGroupsBySection[sectionId];
      if(groups == nil) then
        error(string.format("Pages have page group id (%s and %s) but there are no registered groups for section (%s)", tostring(a.PageGroupId), tostring(b.PageGroupId), tostring(sectionId)));
      end
      local aGroup, bGroup;
      for i, group in ipairs(groups) do
        if(group.PageGroupId == a.PageGroupId) then
          aGroup = group;
        elseif(group.PageGroupId == b.PageGroupId) then
          bGroup = group;
        end
      end

      return SortPageGroups(aGroup, bGroup);
    elseif(a.SortIndex ~= b.SortIndex) then
      return SortNumberOrNil(a.SortIndex, b.SortIndex);
    else
      return Locale.Compare(a.TabName, b.TabName) == -1;
    end

  end

    -- Sort sections.
  table.sort(_Sections, function(a, b) return SortNumberOrNil(a.SortIndex,b.SortIndex); end);

  for sectionId, v in pairs(_PagesBySection) do
    table.sort(v, function(a, b) return SortPages(sectionId, a, b); end);
  end

  -- Sort chapters.
  for _, v in pairs(_ChaptersByPageLayout) do
    table.sort(v, function(a, b) return SortNumberOrNil(a.SortIndex,b.SortIndex); end);
  end
end


-------------------------------------------------------------------------------
-- Caches all data from the database.  This need only be called once at
-- initialization time.
-------------------------------------------------------------------------------
function CacheData()
  _HasSection = {};
  _Sections = {};
  _PagesBySection = {};
  _PagesById = {}; 
  _PageGroupsBySection = {};
  _ChaptersByPageLayout = {};
  _ChapterOverrides = {};
  _PageLayoutScriptTemplates ={};

  CacheData_FetchData();
  CacheData_ProcessData();
  CacheData_SortData();
end

-------------------------------------------------------------------------------
-- Indexes cached data into a search database.
-------------------------------------------------------------------------------
function PopulateSearchData()
  -- Populate Full Text Search
  local searchContext = "Civilopedia";
  if(Search.CreateContext(searchContext, "[COLOR_LIGHTBLUE]", "[ENDCOLOR]", "...")) then
   
    local additional_search_terms = {};
    if(GameInfo.CivilopediaPageSearchTermQueries) then
      for q in GameInfo.CivilopediaPageSearchTermQueries() do
        for i, row in ipairs(DB.Query(q.SQL)) do
          local search_term = {
            SectionId = q.SectionIdColumn and row[q.SectionIdColumn],
            PageId = q.PageIdColumn and row[q.PageIdColumn],
            Term = q.SearchTermColumn and row[q.SearchTermColumn],
          };
          table.insert(additional_search_terms,search_term);
        end
      end
    end

    for sectionId, v in pairs(_PagesBySection) do
      for i, page in ipairs(v) do
        
        local pageId = page.PageId;
        local terms = {};

        for row in GameInfo.CivilopediaPageSearchTerms() do
          if(row.SectionId == sectionId and row.PageId == pageId) then
            local term = Locale.Lookup(row.Term);
            table.insert(terms, term);
          end
        end
        
        for _, row in ipairs(additional_search_terms) do
          if(row.SectionId == sectionId and row.PageId == pageId) then
            local term = Locale.Lookup(row.Term);
            table.insert(terms, term);
          end
        end
 
        
        Search.AddData(searchContext, sectionId .. "|" .. pageId, page.Title, "", terms);
      end
    end

    Search.Optimize(searchContext);
  end
end

-------------------------------------------------------------------------------
-- Returns left-to-right list of sections w/ information.
-- Returns [SectionId, Name, Tooltip, Icon]
-------------------------------------------------------------------------------
function GetSections()
  return _Sections;
end


-------------------------------------------------------------------------------
-- Returns top-to-bottom list of pages including groups
-- Returns [PageGroupId, PageId, Name, ToolTip]
-- NOTE: If PageId is nil, then this is a group separator.
-------------------------------------------------------------------------------
function GetPages(SectionId)
  return _PagesBySection[SectionId];
end


-------------------------------------------------------------------------------
-- Returns the first page structure with the specified section id and page id.
-------------------------------------------------------------------------------
function GetPage(SectionId, PageId)
  if(SectionId and PageId) then
    local key = SectionId .. "::" .. PageId;
    return _PagesById[key];	
  end
end


-------------------------------------------------------------------------------
-- Returns the first page group structure with the specified section id and
-- page group id.
-------------------------------------------------------------------------------
function GetPageGroup(SectionId, PageGroupId)
  local groups = _PageGroupsBySection[SectionId];
  for i, group in ipairs(groups) do
    if(group.PageGroupId == PageGroupId) then
      return group;
    end
  end
end


-------------------------------------------------------------------------------
-- Returns a list of ChapterIds pre-sorted.
-- Used by page layout functions
-- Returns [ChapterId]
-------------------------------------------------------------------------------
function GetPageChapters(PageLayoutId)
  return _ChaptersByPageLayout[PageLayoutId];
end


-------------------------------------------------------------------------------
-- Returns a single text key representing the heading of the chapter.
-- Will return nil if no text is found.
-------------------------------------------------------------------------------
function GetChapterHeader(SectionId, PageId, ChapterId)
  
  local key = SectionId .. "|" .. PageId .. "|" .. ChapterId;
  local chapter = _ChapterOverrides[key];
  if(chapter and chapter.Header) then
    return chapter.Header;
  else
      return FindChapterTextKey(SectionId, PageId, ChapterId, "TITLE");
  end
end


-------------------------------------------------------------------------------
-- Returns a list of text keys representing separate paragraphs of a chapter.
-- Returns nil if no text is found.
-------------------------------------------------------------------------------
function GetChapterBody(SectionId, PageId, ChapterId)

  local key = SectionId .. "|" .. PageId .. "|" .. ChapterId;
  local chapter = _ChapterOverrides[key];
  if(chapter and chapter.Body and #chapter.Body > 0) then
    return chapter.Body;
  else
    local body_key = FindChapterTextKey(SectionId, PageId, ChapterId, "BODY");
    if(body_key ~= nil) then
      return {body_key};
    end
  
    local keys = {};
    local i = 1;
    repeat
      key = FindChapterTextKey(SectionId, PageId, ChapterId, "PARA_" .. i);
      if(key ~= nil) then
        table.insert(keys, key);
      end
      i = i + 1;
  
    until(key == nil);
  
    if(#keys > 0) then
      return keys;
    end
  end
end


-------------------------------------------------------------------------------
-- Returns the first found text key that conforms to the section search patterns.
-------------------------------------------------------------------------------
function FindSectionTextKey(SectionId, Tag)
  local keys = {
    "LOC_PEDIA_" .. SectionId .. "_" .. Tag,
  };

  for i, key in ipairs(keys) do
    if(Locale.HasTextKey(key)) then
      return key;
    end
  end
end


-------------------------------------------------------------------------------
-- Returns the first found text key that conforms to the page search patterns.
-------------------------------------------------------------------------------
function FindPageTextKey(SectionId, PageId, Tag)
  local suffix = "_" .. Tag;
  local keys = {
    "LOC_PEDIA_" .. SectionId .. "_PAGE_" .. PageId .. suffix,
    "LOC_PEDIA_PAGE_" .. PageId .. suffix,
    "LOC_PEDIA_PAGE_" .. suffix
  };

  local page = GetPage(SectionId, PageId);
  if(page) then
    local prefix = page.TextKeyPrefix;
    if(prefix) then
      table.insert(keys, 1, prefix .. PageId .. suffix);
      table.insert(keys, 2, prefix .. suffix);
    end
  end
  
  for i, key in ipairs(keys) do
    if(Locale.HasTextKey(key)) then
      return key;
    end
  end
end


-------------------------------------------------------------------------------
-- Returns the first found text key that conforms to the chapter search
-- patterns.
-------------------------------------------------------------------------------
function FindChapterTextKey(SectionId, PageId, ChapterId, Tag)
  if(SectionId and PageId and ChapterId and Tag) then

    local suffix =  "_CHAPTER_" .. ChapterId .. "_" .. Tag;

     local keys = {
      "LOC_PEDIA_" .. SectionId .. "_PAGE_" .. PageId .. suffix,
      "LOC_PEDIA_" .. SectionId .. "_PAGE" .. suffix,
      "LOC_PEDIA_PAGE_" .. PageId .. suffix,
      "LOC_PEDIA_PAGE" .. suffix,
    };
 
    local page = GetPage(SectionId, PageId);
    if(page) then
      local prefix = page.TextKeyPrefix;
      if(prefix) then
        table.insert(keys, 1, prefix .. "_" .. PageId .. suffix);
        table.insert(keys, 2, prefix .. suffix);
      end
    end

    for i, key in ipairs(keys) do
      if(Locale.HasTextKey(key)) then
        return key;
      end
    end
  end
end


-------------------------------------------------------------------------------
-- Get the current section, page.
-------------------------------------------------------------------------------
function GetCurrentPage()
  return _CurrentSectionId, _CurrentPageId;
end


-------------------------------------------------------------------------------
-- Refreshes all section tabs.
-- This is usually only called once, when the screen is shown.
-------------------------------------------------------------------------------
function RefreshSections()
  _SectionTabManager:ResetInstances();


  local sections = GetSections();
  for i, section in ipairs(sections) do
    local instance = _SectionTabManager:GetInstance();

    local sectionId = section.SectionId;
    local pageId = GetPages(sectionId)[1].PageId;

    section.Instance = instance;

    instance.CivilopediaSectionTabButton:SetToolTipString(section.TabName);
        instance.CivilopediaSectionTabButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
    instance.Icon:SetIcon(section.Icon);

    if(sectionId == _CurrentSectionId) then
      instance.CivilopediaSectionTabButton:ClearCallback(Mouse.eLClick);
      instance.CivilopediaSectionTabButton:SetDisabled(true);
      instance.CivilopediaSectionTabButton:SetVisState(2);
      instance.Selected:SetHide(false);
    else
      instance.CivilopediaSectionTabButton:SetDisabled(false);
      instance.CivilopediaSectionTabButton:RegisterCallback(Mouse.eLClick, function()
        NavigateTo(sectionId, pageId);
      end);
      instance.Selected:SetHide(true);
    end
  end
end


-------------------------------------------------------------------------------
-- Refreshes all page tabs to the section.
-------------------------------------------------------------------------------
function RefreshPageTabs(SectionId, resetScroll)
  _PageTabManager:ResetInstances();
  local pages = GetPages(SectionId);

  local previousPageGroupId;

  local group;
  for i, page in ipairs(pages) do
    if(page.PageGroupId ~= previousPageGroupId) then
      group = GetPageGroup(page.SectionId, page.PageGroupId);
      if(group) then
        local instance = _PageTabManager:GetInstance();
        group.Tab = instance;
        local g = group;
        instance.Caption:LocalizeAndSetText(group.TabName);
        instance.Button:SetSelected(false);
        instance.Button:SetDisabled(false);

        instance.Header:SetHide(false);
        instance.Expand:SetHide(false);

        local offsetY = g.Collapsed and 0 or 22;
        instance.Expand:SetTextureOffsetVal(0, offsetY);

        instance.Button:RegisterCallback(Mouse.eLClick, function()
          g.Collapsed = not g.Collapsed;
          RefreshPageTabs(SectionId, false);
        end);

        previousPageGroupId = page.PageGroupId;

      end
    end

    if(not group or not group.Collapsed) then
      local instance = _PageTabManager:GetInstance();
      local pageId = page.PageId;
      page.Tab = instance;
      instance.Caption:LocalizeAndSetText(page.TabName);
      instance.Header:SetHide(true);
      instance.Expand:SetHide(true);
            instance.Button:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
      if(pageId ~= _CurrentPageId) then
        instance.Button:RegisterCallback(Mouse.eLClick, function()
          NavigateTo(SectionId, pageId);
        end);
        instance.Button:SetSelected(false);
        instance.Button:SetDisabled(false);
      else
        instance.Button:ClearCallback(Mouse.eLClick);
        instance.Button:SetSelected(true);

        instance.Button:SetDisabled(true);
        instance.Button:SetVisState(2);
      end
    end
  end

  Controls.CivilopediaPageTabStack:CalculateSize();
  Controls.CivilopediaPageTabStack:ReprocessAnchoring();
  Controls.PageScrollPanel:CalculateInternalSize();

  if(resetScroll) then
    Controls.PageScrollPanel:SetScrollValue(0);
  end
end


-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function RefreshPageContent(page)

  -- Clean the page
  ResetPageContent();

  local layoutId = page.PageLayoutId;
  local template = _PageLayoutScriptTemplates[layoutId]

  -- Draw the page
  local view = PageLayouts[template];
  if(view) then
    view(page);
  end

  -- Reset the stuff we know about.
  Controls.LeftColumnStack:CalculateSize();
  Controls.LeftColumnStack:ReprocessAnchoring();
  Controls.LeftColumn:SetSizeY(Controls.LeftColumnStack:GetSizeY());

  Controls.RightColumnStack:CalculateSize();
  Controls.RightColumnStack:ReprocessAnchoring();
  Controls.RightColumn:SetSizeY(Controls.RightColumnStack:GetSizeY());

  Controls.TwoColumn:SetSizeY(math.max(Controls.LeftColumn:GetSizeY(), Controls.RightColumn:GetSizeY()));

  Controls.PageChaptersStack:CalculateSize();
  Controls.PageChaptersStack:ReprocessAnchoring();
  Controls.PageContentStack:CalculateSize();
  Controls.PageContentStack:ReprocessAnchoring();

  local height = Controls.PageContentStack:GetSizeY() + Controls.Footer:GetSizeY() + 20;

  Controls.PageContentFrame:SetSizeY(math.max(660, height));
  Controls.PageContentScrollPanel:CalculateInternalSize();
  Controls.PageContentScrollPanel:SetScrollValue(0);
  UI.PlaySound("Civilopedia_Page_Turn");
end

-------------------------------------------------------------------------------
-- Reset all instanced items from page content.
-------------------------------------------------------------------------------
function ResetPageContent()

  -- Reset instances.
  _ChapterManager:ResetInstances();
  _ChapterParagraphManager:ResetInstances();
  _LeftColumnChapterManager:ResetInstances();
  _LeftColumnChapterParagraphManager:ResetInstances();
  _LeftColumnIconHeaderBodyManager:ResetInstances();
  _LeftColumnHeaderBodyManager:ResetInstances();
  _RightColumnPortraitManager:ResetInstances();
  _RightColumnTallPortraitManager:ResetInstances();
  _RightColumnTallPortraitNoScalingManager:ResetInstances(); 
  _RightColumnQuoteManager:ResetInstances();
  _RightColumnStatBoxManager:ResetInstances();
  _RightColumnStatSeparatorManager:ResetInstances();
  _RightColumnStatHeaderManager:ResetInstances();
  _RightColumnStatLabelManager:ResetInstances();
  _RightColumnStatSmallLabelManager:ResetInstances();
  _RightColumnStatIconLabelManager:ResetInstances();
  _RightColumnStatIconNumberLabelManager:ResetInstances();
  _RightColumnStatIconListManager:ResetInstances();

  -- Set UI elements to default hidden
  Controls.FrontPageTitle:SetHide(true);
  Controls.PageHeader:SetHide(true);
  Controls.PageSubHeader:SetHide(true);

  _PageContentLayout = nil;
end

-------------------------------------------------------------------------------
-- Returns a list of results from the search.
-- Returns [SectionId, PageId]
-------------------------------------------------------------------------------
function CivilopediaSearch(term, max_results)

  local results = {};

  local sections = GetSections();

  -- If the search term matches a specific page id, return that section/page.
  -- If the search term matches a specific section id, return the first page
  -- in that section.
  for si, section in ipairs(sections) do
    local sectionId = section.SectionId;
    local pages = GetPages(sectionId);
    if(sectionId == term) then
      table.insert(results, {SectionId = sectionId, PageId = pages[1].PageId});
      if(max_results and #results >= max_results) then
        return results;
      end
    else
      for pi, page in ipairs(pages) do
        local pageId = page.PageId;
        if(pageId == term) then
          table.insert(results, {SectionId = sectionId, PageId = pageId});
          if(max_results and #results >= max_results) then
            return results;
          end
        end
      end
    end
  end

  -- Neither found.  Time to do full text search!
  if _SearchQuery ~= nil and #_SearchQuery > 0 and _SearchQuery ~= LOC_TREE_SEARCH_W_DOTS then
    local search_results = Search.Search("Civilopedia", _SearchQuery);
    if (search_results and #search_results > 0) then
      for i, v in ipairs(search_results) do
        local sectionId, pageId = string.match(v[1], "([^|]+)|([^|]+)");
        table.insert(results, {SectionId = sectionId, PageId = pageId});
        if(max_results and #results >= max_results) then
          return results;
        end
      end
    end
  end

  -- No results found :(
  return results;
end

-------------------------------------------------------------------------------
-- Navigate to a specific section / page.

-------------------------------------------------------------------------------
function NavigateTo(SectionId, PageId)
  print_debug("Navigating to " .. SectionId .. ":" .. PageId);

  local prevSectionId = _CurrentSectionId;
  local prevPageId = _CurrentPageId;

  _CurrentSectionId = SectionId;
  _CurrentPageId = PageId;

  RefreshSections();
  RefreshPageTabs(SectionId, (SectionId ~= prevSectionId));

  if(SectionId ~= prevSectionId or PageId ~= prevPageId) then
    local pages = GetPages(SectionId);

    for i, page in ipairs(pages) do
      local id = page.PageId;
      if(id == PageId) then
        -- Save the currently opened page in order to restore it later
        SaveCurrentPage();
        RefreshPageContent(page);
      end
    end
  end
end


-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function OnToggleCivilopedia()
  if(ContextPtr:IsHidden()) then 
    OnOpenCivilopedia();
    -- Set focus on search bar
    Controls.SearchEditBox:TakeFocus();
  else
    OnClose();
  end
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function OnClose()
  SaveCurrentPage();
  UIManager:DequeuePopup(ContextPtr);
  UI.PlaySound("Civilopedia_Close");
end

function SaveCurrentPage()
  -- Store the currently opened page and section
  _LastSection, _LastPage = GetCurrentPage();
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function OnOpenCivilopedia(sectionId_or_search, pageId)

  print_debug("Received a request to open the Civilopedia");
  if(pageId == nil and sectionId_or_search) then
    print_debug("Searching for " .. sectionId_or_search);
    local results = CivilopediaSearch(sectionId_or_search);
    if(results and #results > 0) then
    print_debug("Found " .. #results .. " results");
    for i,v in ipairs(results) do
      print_debug(v.SectionId .. " - " .. v.PageId);
    end
      NavigateTo(results[1].SectionId, results[1].PageId);
    else
      -- To the front page!
      local sections = GetSections();
      local pages = GetPages(sections[1].SectionId);
      local page = pages[1];
      NavigateTo(page.SectionId, page.PageId);
    end
  elseif(sectionId_or_search and pageId) then
    NavigateTo(sectionId_or_search, pageId);
  elseif(pageId == nil and sectionId_or_search == nil and _LastPage) then
    -- Opened without any query, restore the previously opened page and section instead
    NavigateTo(_LastSection, _LastPage);
  else
    local sections = GetSections();
    local pages = GetPages(sections[1].SectionId);
    local page = pages[1];
    NavigateTo(page.SectionId, page.PageId);
  end

  UIManager:QueuePopup(ContextPtr, PopupPriority.Current);
  UI.PlaySound("Civilopedia_Open");
  Controls.SearchEditBox:TakeFocus();
end

-- ===========================================================================
function OnInputHandler( input )
  local msg = input:GetMessageType();
  if (msg == KeyEvents.KeyUp) then
    local key = input:GetKey();
    if key == Keys.VK_ESCAPE then
      OnClose();
      return true;
    end
  end
  return false;
end

-- ===========================================================================
--  Input Hotkey Event
-- ===========================================================================
function OnInputActionTriggered( actionId )
  if (actionId == m_OpenPediaId) then
    OnToggleCivilopedia();
  end
end

function OnSearchBarGainFocus()
  Controls.SearchEditBox:ClearString();
  Controls.SearchResultsPanelContainer:SetHide(true);
end

function OnSearchCharCallback()
  local str = Controls.SearchEditBox:GetText();
  local has_found = {};
  if str ~= nil and #str > 0 and str ~= LOC_TREE_SEARCH_W_DOTS then
    _SearchQuery = str;
    local results = Search.Search("Civilopedia", str);
    _SearchResultsManager:DestroyInstances();
    if (results and #results > 0) then
      for i, v in ipairs(results) do
        if has_found[v[1]] == nil then
          -- v[1] SectionId | PageId
          -- v[2] Page Name
          -- v[3] Page Content (NYI)
          local instance = _SearchResultsManager:GetInstance();
          local sectionId, pageId = string.match(v[1], "([^|]+)|([^|]+)");
          
          local section;
          local sections = GetSections();
          for i,v in ipairs(sections) do
            if(v.SectionId == sectionId) then
              section = v;
              break;
            end
          end

          if(section) then
            instance.Icon:SetIcon(section.Icon);
          end

          -- Search results already localized.
          instance.Name:SetText(v[2]);
          instance.Button:RegisterCallback(Mouse.eLClick, function()
            Controls.SearchResultsPanelContainer:SetHide(true);
            NavigateTo(sectionId, pageId);
            _SearchQuery = nil;
          end );


          has_found[v[1]] = true;
        end
      end

      Controls.SearchResultsStack:CalculateSize();
      Controls.SearchResultsStack:ReprocessAnchoring();
      Controls.SearchResultsPanel:CalculateSize();
      Controls.SearchResultsPanelContainer:SetHide(false);
    else
      Controls.SearchResultsPanelContainer:SetHide(true);
    end
  elseif(str == nil) then
    Controls.SearchResultsPanelContainer:SetHide(true);
  end
end

function OnSearchCommitCallback()
  if(_SearchQuery and #_SearchQuery > 0 and _SearchQuery ~= LOC_TREE_SEARCH_W_DOTS) then
    Controls.SearchEditBox:SetText(LOC_TREE_SEARCH_W_DOTS);
    OnOpenCivilopedia(_SearchQuery);
    Controls.SearchResultsPanelContainer:SetHide(true);
    _SearchQuery = nil; -- clear query.
  end
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------

function Shutdown()
  Search.DestroyContext("Civilopedia");
end

function Initialize()
  ContextPtr:SetShutdown( Shutdown );
  Controls.WindowCloseButton:RegisterCallback(Mouse.eLClick, OnClose);
  Controls.WindowCloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  LuaEvents.OpenCivilopedia.Add(OnOpenCivilopedia);
  LuaEvents.ToggleCivilopedia.Add(OnToggleCivilopedia);

  -- Hotkey support
  ContextPtr:SetInputHandler( OnInputHandler, true );
  m_OpenPediaId = Input.GetActionId("OpenCivilopedia");
  Events.InputActionTriggered.Add( OnInputActionTriggered );

  -- Search support
  Controls.SearchEditBox:RegisterStringChangedCallback(OnSearchCharCallback);
  Controls.SearchEditBox:RegisterHasFocusCallback(OnSearchBarGainFocus);
  Controls.SearchEditBox:RegisterCommitCallback(OnSearchCommitCallback);

  CacheData();
  RefreshSections();
  PopulateSearchData();
end


-------------------------------------------------------------------------------------
-- Layout Utility Methods
-------------------------------------------------------------------------------------
function Do_AddChapterWithParagraphs(chapter_manager, chapter_para_manager, header, paragraphs)
  if(header ~= nil and paragraphs ~= nil) then
    local t = type(paragraphs);
    if(t == "table" and #t > 0) then
      local instance = chapter_manager:GetInstance();
      instance.Caption:LocalizeAndSetText(header);

      for _, para in ipairs(paragraphs) do
        local para_instance = chapter_para_manager:GetInstance();
        para_instance.Paragraph:LocalizeAndSetText(para);
      end
    elseif(t == "string") then
      local instance = chapter_manager:GetInstance();
      instance.Caption:LocalizeAndSetText(header);

      local para_instance = chapter_para_manager:GetInstance();
      para_instance.Paragraph:LocalizeAndSetText(paragraphs);
    end
  end
end

function Do_AddHeader(manager, caption)
  local c = manager:GetInstance();
  c.Caption:LocalizeAndSetText(caption);
end

function Do_AddParagraph(manager, paragraph)
  local c = manager:GetInstance();
  c.Paragraph:LocalizeAndSetText(paragraph);
end

function Do_AddParagraphs(manager, paragraphs)
  local t = type(paragraphs);
  if(t == "table" and #t > 0) then
    for _, para in ipairs(paragraphs) do
      Do_AddParagraph(manager, para);
    end
  elseif(t == "string") then
    Do_AddParagraph(manager, paragraphs);
  end
end

function Do_AddHeaderBody(manager, header, body)
  local c = manager:GetInstance();

  if(header ~= nil) then
    c.Header:LocalizeAndSetText(header);
    c.Header:SetHide(false);
  else
    c.Header:SetHide(true);
  end

  if(body ~= nil) then
    c.Body:LocalizeAndSetText(body);
    c.Body:SetHide(false);
  else
    c.Body:SetHide(true);
  end

  c.TextStack:CalculateSize();
  c.TextStack:ReprocessAnchoring();

  c.Root:SetSizeY(c.TextStack:GetSizeY());
end

function Do_AddIconHeaderBody(manager, icon, header, body)
  local c = manager:GetInstance();

  HookupIcon(icon, c.Icon, c.Button);

  if(header ~= nil) then
    c.Header:LocalizeAndSetText(header);
    c.Header:SetHide(false);
  else
    c.Header:SetHide(true);
  end

  if(body ~= nil) then
    c.Body:LocalizeAndSetText(body);
    c.Body:SetHide(false);
  else
    c.Body:SetHide(true);
  end

  c.TextStack:CalculateSize();
  c.TextStack:ReprocessAnchoring();
  c.RightStack:CalculateSize();
  c.RightStack:ReprocessAnchoring();

  c.Root:SetSizeY(c.RightStack:GetSizeY());
end

function HookupIcon(icon_data, icon_control, button_control)
  local icon, tooltip, search_term, color;

  if(type(icon_data) == "string") then
    icon = icon_data;

  elseif(type(icon_data) == "table") then
    icon = icon_data[1];
    tooltip = icon_data[2];
    search_term = icon_data[3];
    color = icon_data[4];
  else
    print("Error: Icon data must either be a string or a table");
    return;
  end

  if(icon) then
    local result = icon_control:SetIcon(icon);
    if(not result) then
      print("Error: Couldn't set the icon to " .. tostring(icon));

      -- Closest thing to an error icon we got.
      icon_control:SetIcon("ICON_CIVILIZATION_UNKNOWN");
      icon_control:SetColor(1,1,1);

    else
      if(color) then
        if(type(color) == "string") then
          local c = GameInfo.Colors[color];
          if(c) then
            icon_control:SetColor{r = c.Red, b = c.Blue, g = c.Green};
          else
            icon_control:SetColorByName(color);
          end
        else
          icon_control:SetColor(color);
        end
      else
        icon_control:SetColor(1,1,1);
      end
    end
  end

  if(button_control ~= nil) then
    if(tooltip ~= nil) then
      button_control:LocalizeAndSetToolTip(tooltip);
    else
      button_control:SetToolTipString(nil);
    end

    if(search_term ~= nil) then
      button_control:RegisterCallback(Mouse.eLClick, function()
        local results = CivilopediaSearch(search_term, 1);
        if(results ~= nil and #results > 0) then
          local result = results[1];
          NavigateTo(result.SectionId, result.PageId);
        end
      end);
    else
      button_control:ClearCallback(Mouse.eLClick);
    end
  end
end

-------------------------------------------------------------------------------------
-- Layout Content Methods
-------------------------------------------------------------------------------------
function ShowFrontPageHeader()
  Controls.FrontPageTitle:SetHide(false);
end

function SetPageHeader(caption)
  Controls.PageHeader:SetHide(not caption);
  Controls.PageHeaderCaption:LocalizeAndSetText(Locale.ToUpper(caption or ""));
end

function SetPageSubHeader(caption)
  Controls.PageSubHeader:SetHide(not caption);
  Controls.PageSubHeaderCaption:LocalizeAndSetText(caption or "");
end

-- Full Width (single column)
function AddFullWidthChapter(header, paragraphs)
  return Do_AddChapterWithParagraphs(_ChapterManager, _ChapterParagraphManager, header, paragraphs);
end

function AddFullWidthHeader(caption)
  return Do_AddHeader(_ChapterManager, caption);
end

function AddFullWidthParagraph(paragraph)
  return Do_AddParagraph(_ChapterParagraphManager, paragraph);
end

function AddFullWidthParagraphs(paragraphs)
  return Do_AddParagraphs(_ChapterParagraphManager, paragraphs);
end

function AddFullWidthHeaderBody(header, body)
  error("NYI");
end

function AddFullWidthIconHeaderBody(icon, header, body)
  error("NYI");
end

-- Left Column (2-Column Style)
function AddLeftColumnChapter(header, paragraphs)
  return Do_AddChapterWithParagraphs(_LeftColumnChapterManager, _LeftColumnChapterParagraphManager, header, paragraphs);
end

function AddLeftColumnHeader(caption)
  return Do_AddHeader(_LeftColumnChapterManager, caption);
end

function AddLeftColumnParagraph(paragraph)
  return Do_AddParagraph(_LeftColumnChapterParagraphManager, paragraph);
end

function AddLeftColumnParagraphs(paragraphs)
  return Do_AddParagraphs(_LeftColumnChapterParagraphManager, paragraph);
end

function AddLeftColumnHeaderBody(header, body)
  return Do_AddHeaderBody(_LeftColumnHeaderBodyManager, header, body);
end

function AddLeftColumnIconHeaderBody(icon, header, body)
  return Do_AddIconHeaderBody(_LeftColumnIconHeaderBodyManager, icon, header, body);
end

-- Automatic (determines layout style automatically)
function AddChapter(header, paragraphs)
  if(_PageContentLayout ~= "two-column") then
    AddFullWidthChapter(header, paragraphs);
  else
    AddLeftColumnChapter(header, paragraphs);
  end
end

function AddHeader(caption)
  if(_PageContentLayout ~= "two-column") then
    return AddFullWidthHeader(caption);
  else
    return AddLeftColumnHeader(caption);
  end
end

function AddParagraph(paragraph)
  if(_PageContentLayout ~= "two-column") then
    return AddFullWidthParagraph(paragraph);
  else
    return AddLeftColumnParagraph(paragraph);
  end
end

function AddParagraphs(paragraphs)
  if(_PageContentLayout ~= "two-column") then
    return AddFullWidthParagraphs(paragraphs);
  else
    return AddLeftColumnParagraphs(paragraphs);
  end
end

function AddHeaderBody(header, body)
  if(_PageContentLayout ~= "two-column") then
    return AddFullWidthHeaderBody(header, body);
  else
    return AddLeftColumnHeaderBody(header, body);
  end
end

function AddIconHeaderBody(icon, header, body)
  if(_PageContentLayout ~= "two-column") then
    return AddFullWidthIconHeaderBody(icon, header, body);
  else
    return AddLeftColumnIconHeaderBody(icon, header, body);
  end
end

function AddImage(image)
  if(image ~= nil) then
    local instance = _RightColumnPortraitManager:GetInstance();
    instance.PortraitIcon:SetTexture(image);
    instance.PortraitIcon:SetColor(1,1,1);
    instance.Root:SetHide(false);

    -- Infer two-column layout.
    _PageContentLayout = "two-column";
  end
end

function AddPortrait(icon, color)
  if(icon ~= nil) then
    local instance = _RightColumnPortraitManager:GetInstance();
    local success = instance.PortraitIcon:SetIcon(icon);
    if(color) then
      if(type(color) == "string") then
        instance.PortraitIcon:SetColorByName(color);
      else
        instance.PortraitIcon:SetColor(color);
      end
    else
      instance.PortraitIcon:SetColor(1,1,1);
    end
    instance.Root:SetHide(not success);

    -- Infer two-column layout.
    _PageContentLayout = "two-column";
  end
end

function AddTallImage(image)
  if(image ~= nil) then
    local instance = _RightColumnTallPortraitManager:GetInstance();
    instance.Root:SetTexture(image);
    instance.Root:SetHide(false);

    -- Infer two-column layout.
    _PageContentLayout = "two-column";
  end
end

function AddTallImageNoScale(image)
  if(image ~= nil) then
    local instance = _RightColumnTallPortraitNoScalingManager:GetInstance();
    instance.PortraitIcon:SetTexture(image);
    instance.Root:SetHide(false);

    -- Infer two-column layout.
    _PageContentLayout = "two-column";
  end
end

function AddTallPortrait(icon)
  if(icon ~= nil) then
      local instance = _RightColumnTallPortraitManager:GetInstance();
    local success = instance.Root:SetIcon(icon);
    instance.Root:SetHide(not success);
  end
  -- Infer two-column layout.
  _PageContentLayout = "two-column";
end

function AddQuote(quote, audio)
  if(quote and #quote > 0) then
    local instance = _RightColumnQuoteManager:GetInstance();
    instance.Quote:LocalizeAndSetText(quote);

    local new_height = math.max(100, instance.Quote:GetSizeY() + 40);
    instance.Root:SetSizeY(new_height);

    if(audio and #audio > 0) then
      instance.PlayQuote:SetHide(false);

      instance.PlayQuote:RegisterCallback(Mouse.eLClick, function()
        UI.PlaySound(audio);
      end);
    else
      instance.PlayQuote:SetHide(true);
    end
  end

  -- Infer two-column layout.
  _PageContentLayout = "two-column";
end

function AddRightColumnStatBox(title, populate_method)
  local instance = _RightColumnStatBoxManager:GetInstance();
  instance.Title:LocalizeAndSetText(title);

  -- This tracks whether content has been added.
  -- If no content is actually added, the stat box will be hidden.

  local has_content = false;

  local stat_box = {
    Instance = instance;
  }

  function stat_box:AddSeparator()
    local c = _RightColumnStatSeparatorManager:GetInstance();
    c.Root:ChangeParent(self.Instance.Content);
  end

  function stat_box:AddHeader(caption)
    if(caption == nil) then
      error("Caption must not be nil");
      return;
    end

    local c = _RightColumnStatHeaderManager:GetInstance();
    c.Caption:LocalizeAndSetText(caption);
    c.Caption:ChangeParent(self.Instance.Content);
    has_content = true;
  end

  function stat_box:AddLabel(caption)
    if(caption == nil) then
      error("Caption must not be nil");
      return;
    end

    local c = _RightColumnStatLabelManager:GetInstance();
    c.Caption:LocalizeAndSetText(caption);
    c.Caption:ChangeParent(self.Instance.Content);
    has_content = true;
  end

  function stat_box:AddSmallLabel(caption)
    if(caption == nil) then
      error("Caption must not be nil");
      return;
    end

    local c = _RightColumnStatSmallLabelManager:GetInstance();
    c.Caption:LocalizeAndSetText(caption);
    c.Caption:ChangeParent(self.Instance.Content);
    has_content = true;
  end

  function stat_box:AddIconLabel(icon, caption)
    if(icon == nil) then
      error("Icon must not be nil");
      return;
    end
    if(caption == nil) then
      error("Caption must not be nil");
      return;
    end

    local c = _RightColumnStatIconLabelManager:GetInstance();

    -- If the caption and the tooltip are the same, hide the tooltip.
    if(icon[2] == caption) then
      local new_icon = {
        icon[1],
        nil,
        icon[3],
        icon[4]
      };
      HookupIcon(new_icon, c.Icon, c.Button);
    else
      HookupIcon(icon, c.Icon, c.Button);
    end
    c.Caption:LocalizeAndSetText(caption);
    c.Root:ChangeParent(self.Instance.Content);
    has_content = true;
  end

  function stat_box:AddIconNumberLabel(icon, value, caption)
    if(value == nil) then
      error("Value must not be nil");
      return;
    end

    if(caption == nil) then
      error("Caption must not be nil");
      return;
    end

    local c = _RightColumnStatIconNumberLabelManager:GetInstance();
    HookupIcon(icon, c.Icon, c.Button);
    c.Value:SetText(value);
    c.Caption:LocalizeAndSetText(caption);
    c.Root:ChangeParent(self.Instance.Content);
    has_content = true;
  end

  function stat_box:AddIconList(icon1, icon2, icon3, icon4)
    local c = _RightColumnStatIconListManager:GetInstance();
    if(icon1) then
      HookupIcon(icon1, c.Icon1, c.Button1);
      c.Button1:SetHide(false);
    else
      c.Button1:SetHide(true);
    end

    if(icon2) then
      HookupIcon(icon2, c.Icon2, c.Button2);
      c.Button2:SetHide(false);
    else
      c.Button2:SetHide(true);
    end

    if(icon3) then
      HookupIcon(icon3, c.Icon3, c.Button3);
      c.Button3:SetHide(false);
    else
      c.Button3:SetHide(true);
    end

    if(icon4) then
      HookupIcon(icon4, c.Icon4, c.Button4);
      c.Button4:SetHide(false);
    else
      c.Button4:SetHide(true);
    end

    c.Root:ChangeParent(self.Instance.Content);
    has_content = true;
  end

  if(populate_method) then
    populate_method(stat_box);
  end

  instance.Content:CalculateSize();
  instance.Content:ReprocessAnchoring();

  -- Explicitly pad the height.
  -- This could be done via auto-size but at the moment auto-size handles both width and height and we need the width to remain fixed.
  local new_height = instance.Content:GetSizeY() + 15;
  instance.Root:SetSizeY(new_height);
  instance.Root:SetHide(not has_content);

  if(has_content) then
    -- Infer two-column layout.
    _PageContentLayout = "two-column";
  end
end
