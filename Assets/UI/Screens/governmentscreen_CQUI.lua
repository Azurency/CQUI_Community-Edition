-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_CQUI_Resize = Resize;
BASE_CQUI_RealizeTabs = RealizeTabs;
BASE_CQUI_OnOpenGovernmentScreen = OnOpenGovernmentScreen;
BASE_CQUI_PopulatePolicyFilterData = PopulatePolicyFilterData;
BASE_CQUI_RealizeFilterTabs = RealizeFilterTabs;
BASE_CQUI_LateInitialization = LateInitialization;
BASE_CQUI_OnOpenGovernmentScreenMyGovernment = OnOpenGovernmentScreenMyGovernment

-- ===========================================================================
-- CQUI Members
-- ===========================================================================
CQUI_ShowMyGovtInPolicies = false;
local SIZE_MIN_SPEC_X :number = 1024;
local SCREEN_ENUMS :table = {
  MY_GOVERNMENT = 1,
  GOVERNMENTS   = 2,
  POLICIES      = 3
}

-- CQUI : Great People Filter
function greatPeopleFilter(policy)  return policy.SlotType == "SLOT_GREAT_PERSON"; end

-- ===========================================================================
--  CQUI modified Resize functiton
--  Hide the My Government button if the screen big enough
-- ===========================================================================
function Resize()
  BASE_CQUI_Resize();

  local m_width, _  = UIManager:GetScreenSizeVal();        -- Cache screen dimensions
  local nExtraSpace = m_width - SIZE_MIN_SPEC_X; -- What extra do we have to play with?
  -- Zone widths while in MyGovt screen - pretty fixed.
  local nGovtWidth = Controls.MyGovernment:GetSizeX();

  -- Do we have the extra space to fit MyGovt card onscreen in Catalog tab?
  CQUI_ShowMyGovtInPolicies = (nExtraSpace/2 > nGovtWidth);

  -- CQUI : if MyGovernment is shown in Policy then don't show tab MyGovernment
  if (CQUI_ShowMyGovtInPolicies) then
    Controls.ButtonMyGovernment:SetSizeX( 0 );
    Controls.SelectMyGovernment:SetSizeX( 0 );
  end
end

-- ===========================================================================
--  CQUI modified Resize functiton
--  Hide the My Government button if the screen big enough
-- ===========================================================================
function RealizeTabs()
  BASE_CQUI_RealizeTabs();

  if (CQUI_ShowMyGovtInPolicies) then
    Controls.ButtonMyGovernment:SetHide(true);
  end
end

-- ===========================================================================
--  CQUI modified OnOpenGovernmentScreen functiton
--  If MyGovernment is shown in Policy then open Policies
-- ===========================================================================
function OnOpenGovernmentScreen( screenEnum:number )
  if screenEnum == nil then
    if not IsAbleToChangePolicies() then
      -- CQUI : if MyGovernment is shown in Policy then open Policies
      if (CQUI_ShowMyGovtInPolicies) then
        screenEnum = SCREEN_ENUMS.POLICIES;
      else
        screenEnum = SCREEN_ENUMS.MY_GOVERNMENT;
      end
    end
  end

  BASE_CQUI_OnOpenGovernmentScreen(screenEnum)
end

-- ===========================================================================
--  CQUI modified OnOpenGovernmentScreenMyGovernment functiton
--  If MyGovernment is shown in Policy then open Policies
-- ===========================================================================
function OnOpenGovernmentScreenMyGovernment()
  RefreshAllData();
  -- Open governments screen by default if player has to select a government
  if not g_kCurrentGovernment then
    OnOpenGovernmentScreen( SCREEN_ENUMS.GOVERNMENTS );
  elseif (CQUI_ShowMyGovtInPolicies) then
    OnOpenGovernmentScreen( SCREEN_ENUMS.POLICIES );
  else
    OnOpenGovernmentScreen( SCREEN_ENUMS.MY_GOVERNMENT );
  end
end


-- ===========================================================================
--  CQUI modified PopulatePolicyFilterData functiton
--  Add a Great People filter
-- ===========================================================================
function PopulatePolicyFilterData()
  BASE_CQUI_PopulatePolicyFilterData()

  m_kPolicyFilters = {};
  table.insert( m_kPolicyFilters, { Func=greatPeopleFilter, Description="LOC_GOVT_FILTER_GREAT_PERSON"  } );

  for i,filter in ipairs(m_kPolicyFilters) do
    local filterLabel   :string = Locale.Lookup( filter.Description );
    local controlTable   :table   = {};
    Controls.FilterPolicyPulldown:BuildEntry( "FilterPolicyItemInstance", controlTable );
    controlTable.DescriptionText:SetText( filterLabel );
    controlTable.Button:RegisterCallback( Mouse.eLClick,  function() OnPolicyFilterClicked(filter); end );
  end
  Controls.FilterPolicyPulldown:CalculateInternals();

  RealizePolicyFilterPulldown();
end

-- ===========================================================================
--  CQUI modified PopulatePolicyFilterData functiton
--  Add a Great People filter button
-- ===========================================================================
function RealizeFilterTabs()
  BASE_CQUI_RealizeFilterTabs();

  CreatePolicyTabButton("LOC_CATEGORY_GREAT_PEOPLE_NAME", greatPeopleFilter);
end

-- ===========================================================================
function LateInitialization()
  BASE_CQUI_LateInitialization();

  LuaEvents.LaunchBar_GovernmentOpenMyGovernment.Remove(BASE_CQUI_OnOpenGovernmentScreenMyGovernment);
  LuaEvents.LaunchBar_GovernmentOpenMyGovernment.Add(OnOpenGovernmentScreenMyGovernment);
end