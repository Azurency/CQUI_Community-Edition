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
  tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;

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
          local plotInfo	:table			= GetViewPlotInfo( kPlot );
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
          local plotInfo	:table			= GetViewPlotInfo( kPlot );
          plotInfo.hexArtdef				= "Placement_Purchase";
          plotInfo.selectable				= true;
          plotInfo.purchasable			= true;
          m_hexesDistrictPlacement[plotId]= plotInfo;
        end
      end
    end

    -- Send all the hex information to the engine for visualization.
    local hexIndexes:table = {};
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
  RealizePlotArtForWonderPlacement();
end

-- ===========================================================================
--	Guaranteed to be called when leaving building placement
-- ===========================================================================
function OnInterfaceModeLeave_BuildingPlacement( eNewMode:number )
  LuaEvents.StrategicView_MapPlacement_ClearDistrictPlacementShadowHexes();
end

-- ===========================================================================
--	Explicitly leaving district placement; may not be called if the user
--	is entering another mode by selecting a different UI element which in-turn
--	triggers the exit.
-- ===========================================================================
function ExitPlacementMode( isCancelled:boolean )
  -- UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
  -- if isCancelled then
  -- 	LuaEvents.StrageticView_MapPlacement_ProductionOpen();
  -- end
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
  if (purchaseYield ~= nil and purchaseYield == YieldTypes.GOLD) then
    bIsPurchase = true;
  end

  local tParameters = {};
  tParameters[CityOperationTypes.PARAM_X] = kPlot:GetX();
  tParameters[CityOperationTypes.PARAM_Y] = kPlot:GetY();
  tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtHash;
  tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;

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
--	Adds a plot and all the adjacencent plots, unless already added.
--	ARGS:		plot,			gamecore plot object
--	RETURNS:	A new/updated plotInfo table
-- ===========================================================================
function GetViewPlotInfo( kPlot:table )
  local plotId	:number = kPlot:GetIndex();
  local plotInfo	:table = m_hexesDistrictPlacement[plotId];
  if plotInfo == nil then
    plotInfo = {
      index	= plotId,
      x		= kPlot:GetX(),
      y		= kPlot:GetY(),
      adjacent= {},				-- adjacent edge bonuses
      selectable = false,			-- change state with mouse over?
      purchasable = false
    };
  end
  --print( "   plot: " .. plotInfo.x .. "," .. plotInfo.y..": " .. tostring(plotInfo.iconArtdef) );
  return plotInfo;
end


-- ===========================================================================
--	Obtain a table of adjacency bonuses
-- ===========================================================================
function AddAdjacentPlotBonuses( kPlot:table, districtType:string, pSelectedCity:table )
  local x		:number = kPlot:GetX();
  local y		:number = kPlot:GetY();

  for _,direction in pairs(DirectionTypes) do
    if direction ~= DirectionTypes.NO_DIRECTION and direction ~= DirectionTypes.NUM_DIRECTION_TYPES then
      local adjacentPlot	:table= Map.GetAdjacentPlot( x, y, direction);
      if adjacentPlot ~= nil then
        local artdefIconName:string = GetAdjacentIconArtdefName( districtType, adjacentPlot, pSelectedCity, direction );

        --print( "Checking from: (" .. tostring(x) .. ", " .. tostring(y) .. ") to (" .. tostring(adjacentPlot:GetX()) .. ", " .. tostring(adjacentPlot:GetY()) .. ")  Artdef:'"..artdefIconName.."'");

        if artdefIconName ~= nil and artdefIconName ~= "" then


          local districtViewInfo	:table = GetViewPlotInfo( adjacentPlot );
          local oppositeDirection :number = -1;
          if direction == DirectionTypes.DIRECTION_NORTHEAST	then oppositeDirection = DirectionTypes.DIRECTION_SOUTHWEST; end
          if direction == DirectionTypes.DIRECTION_EAST		then oppositeDirection = DirectionTypes.DIRECTION_WEST; end
          if direction == DirectionTypes.DIRECTION_SOUTHEAST	then oppositeDirection = DirectionTypes.DIRECTION_NORTHWEST; end
          if direction == DirectionTypes.DIRECTION_SOUTHWEST	then oppositeDirection = DirectionTypes.DIRECTION_NORTHEAST; end
          if direction == DirectionTypes.DIRECTION_WEST		then oppositeDirection = DirectionTypes.DIRECTION_EAST; end
          if direction == DirectionTypes.DIRECTION_NORTHWEST	then oppositeDirection = DirectionTypes.DIRECTION_SOUTHEAST; end

          table.insert( districtViewInfo.adjacent, {
            direction	= oppositeDirection,
            iconArtdef	= artdefIconName,
            inBonus		= false,
            outBonus	= true
            }
          );

          m_hexesDistrictPlacement[adjacentPlot:GetIndex()] = districtViewInfo;
        end
      end
    end
  end
end

-- ===========================================================================
--	Find the artdef (texture) for the plot itself as well as the icons
--	that are on the borders signifying why a hex receives a certain bonus.
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
          local plotInfo	:table			= GetViewPlotInfo( kPlot );
          plotInfo.hexArtdef				= "Placement_Valid";
          plotInfo.selectable				= true;
          m_hexesDistrictPlacement[plotId]= plotInfo;

          AddAdjacentPlotBonuses( kPlot, district.DistrictType, pSelectedCity );
          table.insert( kNonShadowHexes, plotId );
        end
      end
    end

    --[[
    -- antonjs: Removing blocked plots from the UI display. Now that district placement can automatically remove features, resources, and improvements,
    -- as long as the player has the tech, there is not much need to show blocked plots and they end up being confusing.
    -- Plots that can host a district, after some action(s) are first taken.
    if (tResults[CityOperationResults.BLOCKED_PLOTS] ~= nil and table.count(tResults[CityOperationResults.BLOCKED_PLOTS]) ~= 0) then
      local kPlots		= tResults[CityOperationResults.BLOCKED_PLOTS];
      for i, plotId in ipairs(kPlots) do
        local kPlot		:table			= Map.GetPlotByIndex(plotId);
        local plotInfo	:table			= GetViewPlotInfo( kPlot );
        plotInfo.hexArtdef				= "Placement_Blocked";
        m_hexesDistrictPlacement[plotId]= plotInfo;

        AddAdjacentPlotBonuses( kPlot, district.DistrictType, pSelectedCity );
        table.insert( kNonShadowHexes, plotId );
      end
    end
    --]]


    -- Plots that a player will NEVER be able to place a district on
    -- if (tResults[CityOperationResults.MOUNTAIN_PLOTS] ~= nil and table.count(tResults[CityOperationResults.MOUNTAIN_PLOTS]) ~= 0) then
    -- 	local kPlots		= tResults[CityOperationResults.MOUNTAIN_PLOTS];
    -- 	for i, plotId in ipairs(kPlots) do
    -- 		local kPlot		:table			= Map.GetPlotByIndex(plotId);
    --		local plotInfo	:table			= GetViewPlotInfo( kPlot );
    --		plotInfo.hexArtdef				= "Placement_Invalid";
    --		m_hexesDistrictPlacement[plotId]= plotInfo;
    --	end
    -- end

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
          local plotInfo	:table			= GetViewPlotInfo( kPlot );
          plotInfo.hexArtdef				= "Placement_Purchase";
          plotInfo.selectable				= true;
          plotInfo.purchasable			= true;
          m_hexesDistrictPlacement[plotId]= plotInfo;
        end
      end
    end


    -- Send all the hex information to the engine for visualization.
    local hexIndexes:table = {};
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
  UI.SetFixedTiltMode( true );
end

function OnInterfaceModeLeave_DistrictPlacement( eNewMode:number )
  LuaEvents.StrategicView_MapPlacement_ClearDistrictPlacementShadowHexes();
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
      UILens.ClearLayerHexes( LensLayers.ADJACENCY_BONUS_DISTRICTS );
      UILens.ClearLayerHexes( LensLayers.DISTRICTS );
      RealizePlotArtForDistrictPlacement();
    elseif (UI.GetInterfaceMode() == InterfaceModeTypes.BUILDING_PLACEMENT) then
      -- Clear existing art then re-realize
      UILens.ClearLayerHexes( LensLayers.ADJACENCY_BONUS_DISTRICTS );
      UILens.ClearLayerHexes( LensLayers.DISTRICTS );
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
      UILens.UnFocusHex( LensLayers.DISTRICTS, hex.index, hex.hexArtdef );
    end
  end

  m_cachedSelectedPlacementPlotId = currentPlotId;

  -- New HEX update it to the selected form.
  if m_cachedSelectedPlacementPlotId ~= -1 then
    local hex:table = m_hexesDistrictPlacement[m_cachedSelectedPlacementPlotId];
    if hex ~= nil and hex.hexArtdef ~= nil and hex.selectable then
      UILens.FocusHex( LensLayers.DISTRICTS, hex.index, hex.hexArtdef );
    end
  end
end

