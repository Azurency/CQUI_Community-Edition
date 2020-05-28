include("LensSupport")

local m_NothingColor        = UI.GetColorValue("COLOR_NOTHING_BUILDER_LENS")
local m_ResouceColor        = UI.GetColorValue("COLOR_RESOURCE_BUILDER_LENS")
local m_DamagedColor        = UI.GetColorValue("COLOR_DAMAGED_BUILDER_LENS")
local m_RecommendedColor    = UI.GetColorValue("COLOR_RECOMMENDED_BUILDER_LENS")
local m_FeatureColor        = UI.GetColorValue("COLOR_FEATURE_BUILDER_LENS")
local m_HillColor           = UI.GetColorValue("COLOR_HILL_BUILDER_LENS")
local m_GenericColor        = UI.GetColorValue("COLOR_GENERIC_BUILDER_LENS")

local m_FallbackColor = m_NothingColor

g_ModLenses_Builder_Config = {
  [m_NothingColor] = {},
  [m_DamagedColor] = {},
  [m_ResouceColor] = {},
  [m_RecommendedColor] = {},
  [m_HillColor] = {},
  [m_FeatureColor] = {},
  [m_GenericColor] = {},
}

g_ModLenses_Builder_Priority = {
  m_NothingColor,
  m_DamagedColor,
  m_ResouceColor,
  m_RecommendedColor,
  m_HillColor,
  m_FeatureColor,
  m_GenericColor,
}

-- Import config files for builder lens
include("ModLens_Builder_Config_", true)

local LENS_NAME = "ML_BUILDER"
local ML_LENS_LAYER = UILens.CreateLensLayerHash("Hex_Coloring_Appeal_Level")

-- Should the builder lens auto apply, when a builder is selected.
local AUTO_APPLY_BUILDER_LENS:boolean = true
-- Disables the nothing color being highlted by the builder
local DISABLE_NOTHING_PLOT_COLOR:boolean = false

-- ==== BEGIN CQUI: Integration Modification =================================
local function CQUI_OnSettingsUpdate()
  AUTO_APPLY_BUILDER_LENS = GameConfiguration.GetValue("CQUI_AutoapplyBuilderLens");
end
-- ==== END CQUI: Integration Modification ===================================

-- ===========================================================================
-- Exported functions
-- ===========================================================================

local function OnGetColorPlotTable()
  local mapWidth, mapHeight = Map.GetGridSize()
  local localPlayer:number = Game.GetLocalPlayer()
  local localPlayerVis:table = PlayersVisibility[localPlayer]

  local colorPlot:table = {}
  colorPlot[m_FallbackColor] = {}

  for i = 0, (mapWidth * mapHeight) - 1, 1 do
    local pPlot:table = Map.GetPlotByIndex(i)
    if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) then
      bPlotColored = false
      for _, color in ipairs(g_ModLenses_Builder_Priority) do
        config = g_ModLenses_Builder_Config[color]
        if config ~= nil and table.count(config) > 0 then
          for _, rule in ipairs(config) do
            if rule ~= nil then
              ruleColor = rule(pPlot)
              if ruleColor ~= nil and ruleColor ~= -1 then
                if colorPlot[ruleColor] == nil then
                  colorPlot[ruleColor] = {}
                end

                table.insert(colorPlot[ruleColor], i)
                bPlotColored = true
                break
              end
            end
          end
        end

        if bPlotColored then
          break
        end
      end

      if not bPlotColored and pPlot:GetOwner() == localPlayer then
        table.insert(colorPlot[m_FallbackColor], i)
      end
    end
  end

  if DISABLE_NOTHING_PLOT_COLOR then
    colorPlot[m_NothingColor] = nil
  end

  return colorPlot
end

-- Called when a builder is selected
local function ShowBuilderLens()
  LuaEvents.MinimapPanel_SetActiveModLens(LENS_NAME)
  UILens.ToggleLayerOn(ML_LENS_LAYER)
end

local function ClearBuilderLens()
  -- print("Clearing builder lens")
  if UILens.IsLayerOn(ML_LENS_LAYER) then
    UILens.ToggleLayerOff(ML_LENS_LAYER);
  end
  LuaEvents.MinimapPanel_SetActiveModLens("NONE");
end

local function OnUnitSelectionChanged( playerID:number, unitID:number, hexI:number, hexJ:number, hexK:number, bSelected:boolean, bEditable:boolean )
  if playerID == Game.GetLocalPlayer() then
    local unitType = GetUnitTypeFromIDs(playerID, unitID);
    if unitType then
      if bSelected then
        if unitType == "UNIT_BUILDER" and AUTO_APPLY_BUILDER_LENS then
          ShowBuilderLens();
        end
        -- Deselection
      else
        if unitType == "UNIT_BUILDER" and AUTO_APPLY_BUILDER_LENS then
          ClearBuilderLens();
        end
      end
    end
  end
end

local function OnUnitChargesChanged( playerID: number, unitID : number, newCharges : number, oldCharges : number )
  local localPlayer = Game.GetLocalPlayer()
  if playerID == localPlayer then
    local unitType = GetUnitTypeFromIDs(playerID, unitID)
    if unitType and unitType == "UNIT_BUILDER" and AUTO_APPLY_BUILDER_LENS then
      if newCharges == 0 then
        ClearBuilderLens();
      end
    end
  end
end

-- Multiplayer support for simultaneous turn captured builder
local function OnUnitCaptured( currentUnitOwner, unit, owningPlayer, capturingPlayer )
  local localPlayer = Game.GetLocalPlayer()
  if owningPlayer == localPlayer then
    local unitType = GetUnitTypeFromIDs(owningPlayer, unitID)
    if unitType and unitType == "UNIT_BUILDER" and AUTO_APPLY_BUILDER_LENS then
      ClearBuilderLens();
    end
  end
end

local function OnUnitRemovedFromMap( playerID: number, unitID : number )
  local localPlayer = Game.GetLocalPlayer()
  local lens = {}
  LuaEvents.MinimapPanel_GetActiveModLens(lens)
  if playerID == localPlayer then
    if lens[1] == LENS_NAME and AUTO_APPLY_BUILDER_LENS then
      ClearBuilderLens();
    end
  end
end

local function OnInitialize()
  Events.UnitSelectionChanged.Add( OnUnitSelectionChanged );
  Events.UnitCaptured.Add( OnUnitCaptured );
  Events.UnitChargesChanged.Add( OnUnitChargesChanged );
  Events.UnitRemovedFromMap.Add( OnUnitRemovedFromMap );

-- ==== BEGIN CQUI: Integration Modification =================================
  -- CQUI Handlers
  LuaEvents.CQUI_SettingsUpdate.Add( CQUI_OnSettingsUpdate );
  Events.LoadScreenClose.Add( CQUI_OnSettingsUpdate ); -- Astog: Update settings when load screen close
-- ==== END CQUI: Integration Modification ===================================
end

local BuilderLensEntry = {
  LensButtonText = "LOC_HUD_BUILDER_LENS",
  LensButtonTooltip = "LOC_HUD_BUILDER_LENS_TOOLTIP",
  Initialize = OnInitialize,
  GetColorPlotTable = OnGetColorPlotTable
}

-- minimappanel.lua
if g_ModLenses ~= nil then
  g_ModLenses[LENS_NAME] = BuilderLensEntry
end

-- modallenspanel.lua
if g_ModLensModalPanel ~= nil then
  g_ModLensModalPanel[LENS_NAME] = {}
  g_ModLensModalPanel[LENS_NAME].LensTextKey = "LOC_HUD_BUILDER_LENS"
  g_ModLensModalPanel[LENS_NAME].Legend = {
    {"LOC_TOOLTIP_BUILDER_LENS_IMP",        UI.GetColorValue("COLOR_RESOURCE_BUILDER_LENS")},
    {"LOC_TOOLTIP_RECOMFEATURE_LENS_HILL",  UI.GetColorValue("COLOR_RECOMMENDED_BUILDER_LENS")},
    {"LOC_TOOLTIP_BUILDER_LENS_HILL",       UI.GetColorValue("COLOR_HILL_BUILDER_LENS")},
    {"LOC_TOOLTIP_BUILDER_LENS_FEATURE",    UI.GetColorValue("COLOR_FEATURE_BUILDER_LENS")},
    {"LOC_TOOLTIP_BUILDER_LENS_GENERIC",    UI.GetColorValue("COLOR_GENERIC_BUILDER_LENS")},
    {"LOC_TOOLTIP_BUILDER_LENS_NOTHING",    UI.GetColorValue("COLOR_NOTHING_BUILDER_LENS")}
  }
end
