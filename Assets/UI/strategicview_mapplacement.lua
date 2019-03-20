-- ===========================================================================
--	Input for placing items on the world map.
--	Copyright 2015-2016, Firaxis Games
--
--	To hot-reload, save this then re-save the file that imports the file
--	(e.g., WorldInput)
-- ===========================================================================
include("SupportFunctions.lua");
include("AdjacencyBonusSupport.lua");
include("PopupDialog");
include("Civ6Common.lua");


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_hexesDistrictPlacement			:table	= {};	-- Re-usable collection of hexes; what is sent across the wire.
local m_cachedSelectedPlacementPlotId	:number = -1;	-- Hex the cursor is currently focused on

local m_AdjacencyBonusDistricts : number = UILens.CreateLensLayerHash("Adjacency_Bonus_Districts");
local m_Districts : number = UILens.CreateLensLayerHash("Districts");

local bWasCancelled:boolean = true;

-- ===========================================================================
function SetInsertModeParams( tParameters:table )
  tParameters[CityOperationTypes.PARAM_INSERT_MODE] = UI.GetInterfaceModeParameter(CityOperationTypes.PARAM_INSERT_MODE);
  tParameters[CityOperationTypes.PARAM_QUEUE_LOCATION] = UI.GetInterfaceModeParameter(CityOperationTypes.PARAM_QUEUE_LOCATION);
  tParameters[CityOperationTypes.PARAM_QUEUE_SOURCE_LOCATION] = UI.GetInterfaceModeParameter(CityOperationTypes.PARAM_QUEUE_SOURCE_LOCATION);
  tParameters[CityOperationTypes.PARAM_QUEUE_DESTINATION_LOCATION] = UI.GetInterfaceModeParameter(CityOperationTypes.PARAM_QUEUE_DESTINATION_LOCATION);
end

-- ===========================================================================
-- Code related to the Wonder Placement interface mode
-- ===========================================================================
function ConfirmPlaceWonder( pInputStruct:table )
    local plotId = UI.GetCursorPlotID();
    local pSelectedCity = UI.GetHeadSelectedCity();
  if (not Map.IsPlot(plotId) or not GameInfo.Districts['DISTRICT_CITY_CENTER'].IsPlotValid(pSelectedCity, plotId)) then
    return false;
  end

    local kPlot = Map.GetPlotByIndex(plotId);

  local eBuilding = UI.GetInterfaceModeParameter(CityOperationTypes.PARAM_BUILDING_TYPE);

  local tParameters = {};
  tParameters[CityOperationTypes.PARAM_X] = kPlot:GetX();
  tParameters[CityOperationTypes.PARAM_Y] = kPlot:GetY();
  tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = eBuilding;

  SetInsertModeParams(tParameters);
  if (pSelectedCity ~= nil) then
    local pBuildingInfo = GameInfo.Buildings[eBuilding];
    local bCanStart, tResults = CityManager.CanStartOperation( pSelectedCity, CityOperationTypes.BUILD, tParameters, true);
    if pBuildingInfo ~= nil and bCanStart then

      local sConfirmText	:string = Locale.Lookup("LOC_DISTRICT_ZONE_CONFIRM_WONDER_POPUP", pBuildingInfo.Name);

      if (tResults ~= nil and tResults[CityOperationResults.SUCCESS_CONDITIONS] ~= nil) then
        if (table.count(tResults[CityOperationResults.SUCCESS_CONDITIONS]) ~= 0) then
          sConfirmText = sConfirmText .. "[NEWLINE]";
        end
        for i,v in ipairs(tResults[CityOperationResults.SUCCESS_CONDITIONS]) do
          sConfirmText = sConfirmText .. "[NEWLINE]" .. Locale.Lookup(v);
        end
      end
      local pPopupDialog :table = PopupDialogInGame:new("PlaceWonderAt_X" .. kPlot:GetX() .. "_Y" .. kPlot:GetY()); -- unique identifier
      pPopupDialog:AddText(sConfirmText);
      pPopupDialog:AddConfirmButton(Locale.Lookup("LOC_YES"), function()
        --CityManager.RequestOperation(pSelectedCity, CityOperationTypes.BUILD, tParameters);
        local tProductionQueueParameters = { tParameters=tParameters, plotId=plotId, pSelectedCity=pSelectedCity, buildingHash=eBuilding }
        LuaEvents.StrageticView_MapPlacement_ProductionClose(tProductionQueueParameters);
        UI.PlaySound("Build_Wonder");
        ExitPlacementMode();
      end);
      pPopupDialog:AddCancelButton(Locale.Lookup("LOC_NO"), nil);
      pPopupDialog:Open();
    end
  else
    ExitPlacementMode( true );
  end

  return true;
end

-- ===========================================================================
--	Find the artdef (texture) for the plots we are considering
-- ===========================================================================
function RealizePlotArtForWonderPlacement()
  -- Reset the master table of hexes, tracking what will be sent to the engine.
  m_hexesDistrictPlacement = {};
  m_cachedSelectedPlacementPlotId = -1;
  local kNonShadowHexes:table = {};		-- Holds plot IDs of hexes to not be shadowed.

  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK);
  UILens.SetActive("DistrictPlacement");	-- turn on all district layers and district adjacency bonus layers

  local pSelectedCity = UI.GetHeadSelectedCity();
  if pSelectedCity ~= nil then

    local buildingHash:number	= UI.GetInterfaceModeParameter(CityOperationTypes.PARAM_BUILDING_TYPE);
    local building:table		= GameInfo.Buildings[buildingHash];
    local tParameters :table	= {};
    tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = buildingHash;

    local tResults :table = CityManager.GetOperationTargets( pSelectedCity, CityOperationTypes.BUILD, tParameters );
    -- Highlight the plots where the city can place the wonder
    if (tResults[CityOperationResults.PLOTS] ~= nil and table.count(tResults[CityOperationResults.PLOTS]) ~= 0) then
      local kPlots		= tResults[CityOperationResults.PLOTS];
      for i, plotId in ipairs(kPlots) do
        if(GameInfo.Districts['DISTRICT_CITY_CENTER'].IsPlotValid(pSelectedCity, plotId)) then
          local kPlot		:table			= Map.GetPlotByIndex(plotId);
          local plotInfo	:table			= GetViewPlotInfo( kPlot, m_hexesDistrictPlacement );
          plotInfo.hexArtdef				= "Placement_Valid";
          plotInfo.selectable				= true;
          m_hexesDistrictPlacement[plotId]= plotInfo;

          table.insert( kNonShadowHexes, plotId );
        else
          -- TODO: Perhaps make it clear that it is reserved by the queue
        end
      end
    end

    -- Plots that aren't owned, but could be (and hence, could be a great spot for that wonder!)
    tParameters = {};
    tParameters[CityCommandTypes.PARAM_PLOT_PURCHASE] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_PLOT_PURCHASE);
    local tResults = CityManager.GetCommandTargets( pSelectedCity, CityCommandTypes.PURCHASE, tParameters );
    if (tResults[CityCommandResults.PLOTS] ~= nil and table.count(tResults[CityCommandResults.PLOTS]) ~= 0) then
      local kPurchasePlots = tResults[CityCommandResults.PLOTS];
      for i, plotId in ipairs(kPurchasePlots) do

        -- Highlight any purchaseable plot the Wonder could go on
        local kPlot		:table			= Map.GetPlotByIndex(plotId);

        if kPlot:CanHaveWonder(building.Index, pSelectedCity:GetOwner(), pSelectedCity:GetID()) then
          local plotInfo  :table      = GetViewPlotInfo( kPlot, m_hexesDistrictPlacement );
          plotInfo.hexArtdef				= "Placement_Purchase";
          plotInfo.selectable				= true;
          plotInfo.purchasable			= true;
          m_hexesDistrictPlacement[plotId]= plotInfo;
        end
      end
    end

    -- Send all the hex information to the engine for visualization.
    for i,plotInfo in pairs(m_hexesDistrictPlacement) do
      UILens.SetAdjacencyBonusDistict( plotInfo.index, plotInfo.hexArtdef, plotInfo.adjacent );
    end

    LuaEvents.StrategicView_MapPlacement_AddDistrictPlacementShadowHexes( kNonShadowHexes );
  end
end

-- ===========================================================================
--	Mode to place a Wonder Building
-- ===========================================================================
function OnInterfaceModeEnter_BuildingPlacement( eNewMode:number )
  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK); --here?
  bWasCancelled = true; -- We assume it was cancelled unless explicitly not cancelled
  RealizePlotArtForWonderPlacement();
end

-- ===========================================================================
--	Guaranteed to be called when leaving building placement
-- ===========================================================================
function OnInterfaceModeLeave_BuildingPlacement( eNewMode:number )
  LuaEvents.StrategicView_MapPlacement_ClearDistrictPlacementShadowHexes();
  local eCurrentMode:number = UI.GetInterfaceMode();
  if eCurrentMode ~= InterfaceModeTypes.VIEW_MODAL_LENS then
    -- Don't open the production panel if we're going to a modal lens as it will overwrite the modal lens
    LuaEvents.StrageticView_MapPlacement_ProductionOpen(bWasCancelled);
  end
end

-- ===========================================================================
--	Explicitly leaving district placement; may not be called if the user
--	is entering another mode by selecting a different UI element which in-turn
--	triggers the exit.
-- ===========================================================================
function ExitPlacementMode( isCancelled:boolean )
  bWasCancelled = isCancelled ~= nil and isCancelled or false;
  -- UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
end

-- ===========================================================================
--	Confirm before placing a district down
-- ===========================================================================
function ConfirmPlaceDistrict(pInputStruct:table)

  local plotId = UI.GetCursorPlotID();
  local pSelectedCity = UI.GetHeadSelectedCity();
  if (not Map.IsPlot(plotId) or not GameInfo.Districts['DISTRICT_CITY_CENTER'].IsPlotValid(pSelectedCity, plotId)) then
    return;
  end

  local kPlot = Map.GetPlotByIndex(plotId);

  local districtHash:number = UI.GetInterfaceModeParameter(CityOperationTypes.PARAM_DISTRICT_TYPE);
  local purchaseYield = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_YIELD_TYPE);
  local bIsPurchase:boolean = false;
  if (purchaseYield ~= nil and (purchaseYield == YieldTypes.GOLD or purchaseYield == YieldTypes.FAITH)) then
    bIsPurchase = true;
  end

  local tParameters = {};
  tParameters[CityOperationTypes.PARAM_X] = kPlot:GetX();
  tParameters[CityOperationTypes.PARAM_Y] = kPlot:GetY();
  tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtHash;
  tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = purchaseYield;

  SetInsertModeParams(tParameters);

  if (pSelectedCity ~= nil) then
    local pDistrictInfo = GameInfo.Districts[districtHash];
    local bCanStart;
    local tResults;
    if (bIsPurchase) then
      bCanStart, tResults = CityManager.CanStartCommand( pSelectedCity, CityCommandTypes.PURCHASE, tParameters, true);
    else
      bCanStart, tResults = CityManager.CanStartOperation( pSelectedCity, CityOperationTypes.BUILD, tParameters, true);
    end
    if pDistrictInfo ~= nil and bCanStart then

      local sConfirmText	:string = Locale.Lookup("LOC_DISTRICT_ZONE_CONFIRM_DISTRICT_POPUP", pDistrictInfo.Name);

      if (tResults ~= nil and tResults[CityOperationResults.SUCCESS_CONDITIONS] ~= nil) then
        if (table.count(tResults[CityOperationResults.SUCCESS_CONDITIONS]) ~= 0) then
          sConfirmText = sConfirmText .. "[NEWLINE]";
        end
        for i,v in ipairs(tResults[CityOperationResults.SUCCESS_CONDITIONS]) do
          sConfirmText = sConfirmText .. "[NEWLINE]" .. Locale.Lookup(v);
        end
      end
      local pPopupDialog :table = PopupDialogInGame:new("PlaceDistrictAt_X" .. kPlot:GetX() .. "_Y" .. kPlot:GetY()); -- unique identifier
      pPopupDialog:AddText(sConfirmText);
      if (bIsPurchase) then
        if (IsTutorialRunning()) then
          CityManager.RequestCommand(pSelectedCity, CityCommandTypes.PURCHASE, tParameters);
          ExitPlacementMode();
          LuaEvents.CQUI_CityPanel_CityviewEnable();
        else
          pPopupDialog:AddConfirmButton(Locale.Lookup("LOC_YES"), function()
            CityManager.RequestCommand(pSelectedCity, CityCommandTypes.PURCHASE, tParameters);
            ExitPlacementMode();
            LuaEvents.CQUI_CityPanel_CityviewEnable();
          end);
        end  
      else
        if (IsTutorialRunning()) then
          local tProductionQueueParameters = { tParameters=tParameters, plotId=plotId, pSelectedCity=pSelectedCity, buildingHash=districtHash }
          LuaEvents.StrageticView_MapPlacement_ProductionClose(tProductionQueueParameters);
          ExitPlacementMode();
          LuaEvents.CQUI_CityPanel_CityviewEnable();
        else
          pPopupDialog:AddConfirmButton(Locale.Lookup("LOC_YES"), function()
            local tProductionQueueParameters = { tParameters=tParameters, plotId=plotId, pSelectedCity=pSelectedCity, buildingHash=districtHash }
            LuaEvents.StrageticView_MapPlacement_ProductionClose(tProductionQueueParameters);
            ExitPlacementMode();
            LuaEvents.CQUI_CityPanel_CityviewEnable();
          end);
        end
      end

      if (not IsTutorialRunning()) then
        pPopupDialog:AddCancelButton(Locale.Lookup("LOC_NO"), nil);
        pPopupDialog:Open();
      end
    end
  else
    ExitPlacementMode( true );
  end
end

-- ===========================================================================
--  Find the artdef (texture) for the plot itself as well as the icons
--  that are on the borders signifying why a hex receives a certain bonus.
-- ===========================================================================
function RealizePlotArtForDistrictPlacement()
  -- Reset the master table of hexes, tracking what will be sent to the engine.
  m_hexesDistrictPlacement = {};
  m_cachedSelectedPlacementPlotId = -1;
  local kNonShadowHexes:table = {};		-- Holds plot IDs of hexes to not be shadowed.

  UIManager:SetUICursor(CursorTypes.RANGE_ATTACK);
  UILens.SetActive("DistrictPlacement");	-- turn on all district layers and district adjacency bonus layers

  local pSelectedCity = UI.GetHeadSelectedCity();
  if pSelectedCity ~= nil then

    local districtHash:number	= UI.GetInterfaceModeParameter(CityOperationTypes.PARAM_DISTRICT_TYPE);
    local district:table		= GameInfo.Districts[districtHash];
    local tParameters :table	= {};
    tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtHash;

    local tResults :table = CityManager.GetOperationTargets( pSelectedCity, CityOperationTypes.BUILD, tParameters );
    -- Highlight the plots where the city can place the district
    if (tResults[CityOperationResults.PLOTS] ~= nil and table.count(tResults[CityOperationResults.PLOTS]) ~= 0) then
      local kPlots		= tResults[CityOperationResults.PLOTS];
      for i, plotId in ipairs(kPlots) do
        if(GameInfo.Districts['DISTRICT_CITY_CENTER'].IsPlotValid(pSelectedCity, plotId)) then

          local kPlot		:table			= Map.GetPlotByIndex(plotId);
          local plotInfo  :table      = GetViewPlotInfo( kPlot, m_hexesDistrictPlacement );
          plotInfo.hexArtdef				= "Placement_Valid";
          plotInfo.selectable				= true;
          m_hexesDistrictPlacement[plotId]= plotInfo;

          local kAdjacentPlotBonuses:table = AddAdjacentPlotBonuses( kPlot, district.DistrictType, pSelectedCity, m_hexesDistrictPlacement );
          for plotIndex, districtViewInfo in pairs(kAdjacentPlotBonuses) do
            m_hexesDistrictPlacement[plotIndex] = districtViewInfo;
          end

          table.insert( kNonShadowHexes, plotId );
        end
      end
    end


    -- Plots that arent't owned, but could be (and hence, could be a great spot for that district!)
    tParameters = {};
    tParameters[CityCommandTypes.PARAM_PLOT_PURCHASE] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_PLOT_PURCHASE);
    local tResults = CityManager.GetCommandTargets( pSelectedCity, CityCommandTypes.PURCHASE, tParameters );
    if (tResults[CityCommandResults.PLOTS] ~= nil and table.count(tResults[CityCommandResults.PLOTS]) ~= 0) then
      local kPurchasePlots = tResults[CityCommandResults.PLOTS];
      for i, plotId in ipairs(kPurchasePlots) do

        -- Only highlight certain plots (usually if there is a bonus to be gained).
        local kPlot		:table			= Map.GetPlotByIndex(plotId);

        if kPlot:CanHaveDistrict(district.Index, pSelectedCity:GetOwner(), pSelectedCity:GetID()) then
          local plotInfo  :table      = GetViewPlotInfo( kPlot, m_hexesDistrictPlacement );
          plotInfo.hexArtdef				= "Placement_Purchase";
          plotInfo.selectable				= true;
          plotInfo.purchasable			= true;
          m_hexesDistrictPlacement[plotId]= plotInfo;
        end
      end
    end


    -- Send all the hex information to the engine for visualization.
    for i,plotInfo in pairs(m_hexesDistrictPlacement) do
      UILens.SetAdjacencyBonusDistict( plotInfo.index, plotInfo.hexArtdef, plotInfo.adjacent );
    end

    LuaEvents.StrategicView_MapPlacement_AddDistrictPlacementShadowHexes( kNonShadowHexes );
  end
end

-- ===========================================================================
--	Show the different potential district placement areas...
-- ===========================================================================
function OnInterfaceModeEnter_DistrictPlacement( eNewMode:number )
  RealizePlotArtForDistrictPlacement();
  bWasCancelled = true; -- We assume it was cancelled unless explicitly not cancelled
  UI.SetFixedTiltMode( true );
end

function OnInterfaceModeLeave_DistrictPlacement( eNewMode:number )
  LuaEvents.StrategicView_MapPlacement_ClearDistrictPlacementShadowHexes();
  local eCurrentMode:number = UI.GetInterfaceMode();
  if eCurrentMode ~= InterfaceModeTypes.VIEW_MODAL_LENS then
    -- Don't open the production panel if we're going to a modal lens as it will overwrite the modal lens
    LuaEvents.StrageticView_MapPlacement_ProductionOpen(bWasCancelled);
  end
end

-- ===========================================================================
--
-- ===========================================================================
function OnCityMadePurchase_StrategicView_MapPlacement(owner:number, cityID:number, plotX:number, plotY:number, purchaseType, objectType)
  if owner ~= Game.GetLocalPlayer() then
    return;
  end
    if purchaseType == EventSubTypes.PLOT then

    -- Make sure city made purchase and it's the right mode.
    if (UI.GetInterfaceMode() == InterfaceModeTypes.DISTRICT_PLACEMENT) then
      -- Clear existing art then re-realize
      UILens.ClearLayerHexes( m_AdjacencyBonusDistricts );
      UILens.ClearLayerHexes( m_Districts );
      RealizePlotArtForDistrictPlacement();
    elseif (UI.GetInterfaceMode() == InterfaceModeTypes.BUILDING_PLACEMENT) then
      -- Clear existing art then re-realize
      UILens.ClearLayerHexes( m_AdjacencyBonusDistricts );
      UILens.ClearLayerHexes( m_Districts );
      RealizePlotArtForWonderPlacement();
    end
    end
end

-- ===========================================================================
--	Whenever the mouse moves while in district or wonder placement mode.
-- ===========================================================================
function RealizeCurrentPlaceDistrictOrWonderPlot()
  local currentPlotId	:number = UI.GetCursorPlotID();
  if (not Map.IsPlot(currentPlotId)) then
    return;
  end

  if currentPlotId == m_cachedSelectedPlacementPlotId then
    return;
  end

  -- Reset the artdef for the currently selected hex
  if m_cachedSelectedPlacementPlotId ~= nil and m_cachedSelectedPlacementPlotId ~= -1 then
    local hex:table = m_hexesDistrictPlacement[m_cachedSelectedPlacementPlotId];
    if hex ~= nil and hex.hexArtdef ~= nil and hex.selectable then
      UILens.UnFocusHex( m_Districts, hex.index, hex.hexArtdef );
    end
  end

  m_cachedSelectedPlacementPlotId = currentPlotId;

  -- New HEX update it to the selected form.
  if m_cachedSelectedPlacementPlotId ~= -1 then
    local hex:table = m_hexesDistrictPlacement[m_cachedSelectedPlacementPlotId];
    if hex ~= nil and hex.hexArtdef ~= nil and hex.selectable then
      UILens.FocusHex( m_Districts, hex.index, hex.hexArtdef );
    end
  end
end

