include("LensSupport")

-- ===========================================================================
-- Builder Lens Support
-- ===========================================================================

local builderGovernorIndex = nil
local builderAquacultureHash = nil
local builderParksRecHash = nil

if GameInfo.Governors ~= nil then
    for row in GameInfo.Governors() do
        if row.GovernorType == "GOVERNOR_THE_BUILDER" then
            builderGovernorIndex = row.Index
            print("Governor Builder Index = " .. builderGovernorIndex)
            break
        end
    end

    for row in GameInfo.GovernorPromotions() do
        if row.GovernorPromotionType == "GOVERNOR_PROMOTION_AQUACULTURE" then
            builderAquacultureHash = row.Hash
            print("Governor Builder Aquaculture hash = " .. builderAquacultureHash)
            break
        end
    end

    for row in GameInfo.GovernorPromotions() do
        if row.GovernorPromotionType == "GOVERNOR_PROMOTION_PARKS_RECREATION" then
            builderParksRecHash = row.Hash
            print("Governor Builder Parks Rec hash = " .. builderParksRecHash)
            break
        end
    end
end

-- From GovernorSupport.lua
function GetAppointedGovernor(playerID:number, governorTypeIndex:number)
    -- Make sure we're looking for a valid governor
    if playerID < 0 or governorTypeIndex < 0 then
        return nil;
    end

    -- Get the player governor list
    local pGovernorDef = GameInfo.Governors[governorTypeIndex];
    local pPlayer:table = Players[playerID];
    local pPlayerGovernors:table = pPlayer:GetGovernors();
    local bHasGovernors, tGovernorList = pPlayerGovernors:GetGovernorList();

    -- Find and return the governor from the governor list
    if pPlayerGovernors:HasGovernor(pGovernorDef.Hash) then
        for i,governor in ipairs(tGovernorList) do
            if governor:GetType() == governorTypeIndex then
                return governor;
            end
        end
    end

    -- Return nil if this player has not appointed that governor
    return nil;
end

local function isAncientClassicalWonder(wonderTypeID:number)
    for row in GameInfo.Buildings() do
        if row.Index == wonderTypeID then
            -- Make hash, and get era
            if row.PrereqTech ~= nil then
                prereqTechHash = DB.MakeHash(row.PrereqTech)
                eraType = GameInfo.Technologies[prereqTechHash].EraType
            elseif row.PrereqCivic ~= nil then
                prereqCivicHash = DB.MakeHash(row.PrereqCivic)
                eraType = GameInfo.Civics[prereqCivicHash].EraType
            else
                -- Wonder has no prereq
                return true
            end

            if eraType == nil then
                return true
            elseif eraType == "ERA_ANCIENT" or eraType == "ERA_CLASSICAL" then
                return true
            end
        end
    end
    return false
end

local function BuilderCanConstruct(improvementInfo)
    for improvementBuildUnits in GameInfo.Improvement_ValidBuildUnits() do
        if improvementBuildUnits ~= nil and improvementBuildUnits.ImprovementType == improvementInfo.ImprovementType and
            improvementBuildUnits.UnitType == "UNIT_BUILDER" then
                return true
        end
    end
    return false
end

local function playerCanRemoveFeature(pPlayer:table, pPlot:table)
    local featureInfo = GameInfo.Features[pPlot:GetFeatureType()]
    if featureInfo ~= nil then
        if not featureInfo.Removable then return false end

        -- Check for remove tech
        if featureInfo.RemoveTech ~= nil then
            local tech = GameInfo.Technologies[featureInfo.RemoveTech]
            local playerTech:table = pPlayer:GetTechs()
            if tech ~= nil  then
                return playerTech:HasTech(tech.Index)
            else
                return false
            end
        else
            return true
        end
    end
    return false
end

local function playerCanImproveFeature(pPlayer:table, pPlot:table)
    local featureInfo = GameInfo.Features[pPlot:GetFeatureType()]
    if featureInfo ~= nil then
        for validFeatureInfo in GameInfo.Improvement_ValidFeatures() do
            if validFeatureInfo ~= nil and validFeatureInfo.FeatureType == featureInfo.FeatureType then
                improvementType = validFeatureInfo.ImprovementType
                improvementInfo = GameInfo.Improvements[improvementType]
                if improvementInfo ~= nil and BuilderCanConstruct(improvementInfo) and playerCanHave(pPlayer, improvementInfo) then
                    -- print("can have " .. improvementType)
                    return true
                end
            end
        end
    end
    return false
end


local function plotCountAdjSeaResource(pPlayer:table, pPlot:table)
    local cnt = 0
    for pAdjPlot in PlotRingIterator(pPlot, 1, SECTOR_NONE, DIRECTION_CLOCKWISE) do
        if pAdjPlot:IsWater() and plotHasResource(pAdjPlot) and playerHasDiscoveredResource(pPlayer, pAdjPlot) then
            cnt = cnt + 1
        end
    end
    return cnt
end

local function plotHasAdjBonusOrLuxury(pPlayer:table, pPlot:table)
    for pAdjPlot in PlotRingIterator(pPlot, 1, SECTOR_NONE, DIRECTION_CLOCKWISE) do
        if plotHasResource(pAdjPlot) and playerHasDiscoveredResource(pPlayer, pAdjPlot) then
            -- Check if the resource is luxury or strategic
            resInfo = GameInfo.Resources[pAdjPlot:GetResourceType()]
            if resInfo ~= nil and (resInfo.ResourceClassType == "RESOURCECLASS_BONUS" or
                    resInfo.ResourceClassType == "RESOURCECLASS_LUXURY") then

                return true
            end
        end
    end
    return false
end

local function plotCountAdjTerrain(pPlayer:table, pPlot:table)
    local playerVis:table = PlayersVisibility[pPlayer:GetID()]
    local cnt:number = 0
    for pAdjPlot in PlotRingIterator(pPlot, 1, SECTOR_NONE, DIRECTION_CLOCKWISE) do
        if playerVis.IsRevealed(pAdjPlot:GetX(), pAdjPlot:GetY()) and not pAdjPlot:IsWater() then
            cnt = cnt + 1
        end
    end
    return cnt
end

-- Incomplete handler to check if that plot has a buildable improvement
-- FIXME: Does not check requirements properly so some improvements pass through, example: fishery
local function plotCanHaveImprovement(pPlayer:table, pPlot:table)
    for imprRow in GameInfo.Improvements() do
        if imprRow ~= nil and imprRow.Buildable then

            -- Is it an improvement buildable by a builder
            -- Does the player the prereq techs and civis
            -- Does the land/coast/sea requirement match
            if BuilderCanConstruct(imprRow) and playerCanHave(pPlayer, imprRow) then
                if (imprRow.Coast and pPlot:IsCoastalLand()) or
                        (imprRow.Domain == "DOMAIN_LAND" and (not pPlot:IsWater())) or
                        (imprRow.Domain == "DOMAIN_SEA" and pPlot:IsWater()) then

                    local improvementValid:boolean = false

                    -- Check for valid feature
                    for row in GameInfo.Improvement_ValidFeatures() do
                        if row ~= nil and row.ImprovementType == imprRow.ImprovementType then
                            -- Does this plot have this feature?
                            local featureInfo = GameInfo.Features[row.FeatureType]
                            if featureInfo ~= nil and pPlot:GetFeatureType() == featureInfo.Index then
                                if playerCanHave(pPlayer, featureInfo) and playerCanHave(pPlayer, row) then
                                    -- print("(feature) Plot " .. pPlot:GetIndex() .. " can have " .. imprRow.ImprovementType)
                                    improvementValid = true
                                    break
                                end
                            end
                        end
                    end

                    -- Check for valid terrain
                    if not improvementValid then
                        for row in GameInfo.Improvement_ValidTerrains() do
                            if row ~= nil and row.ImprovementType == imprRow.ImprovementType then
                                -- Does this plot have this terrain?
                                local terrainInfo = GameInfo.Terrains[row.TerrainType]
                                if terrainInfo ~= nil and pPlot:GetTerrainType() == terrainInfo.Index then
                                    if playerCanHave(pPlayer, terrainInfo) and playerCanHave(pPlayer, row)  then
                                        -- print("(terrain) Plot " .. pPlot:GetIndex() .. " can have " .. imprRow.ImprovementType)
                                        improvementValid = true
                                        break
                                    end
                                end
                            end
                        end
                    end

                    -- Check for valid resource
                    if not improvementValid then
                        for row in GameInfo.Improvement_ValidResources() do
                            if row ~= nil and row.ImprovementType == imprRow.ImprovementType then
                                -- Does this plot have this terrain?
                                local resourceInfo = GameInfo.Resources[row.ResourceType]
                                if resourceInfo ~= nil and pPlot:GetResourceType() == resourceInfo.Index then
                                    if playerCanHave(pPlayer, resourceInfo) and playerCanHave(pPlayer, row)  then
                                        -- print("(resource) Plot " .. pPlot:GetIndex() .. " can have " .. imprRow.ImprovementType)
                                        improvementValid = true
                                        break
                                    end
                                end
                            end
                        end
                    end

                    -- Adjacent river (example Chateau)
                    if improvementValid and imprRow.RequiresRiver and not pPlot:IsRiver() then
                        -- print("failed adjacent river")
                        imporvementValid = false
                    end

                    -- astog: Disabled for performance reasons. Some plots will get incorrectly highlited as buildable but the trade-off with speed is significant in bigger maps
                    --[[
                    -- Adjacent Bonus or luxury (example mekewap)
                    if improvementValid and imprRow.RequiresAdjacentBonusOrLuxury and
                            not plotHasAdjBonusOrLuxury(pPlayer, pPlot) then
                        improvementValid = false
                        -- print("failed adjacent bonus or luxury")
                    end

                    -- Adjacent terrain requirement (example polder)
                    if imporvementValid and imprRow.ValidAdjacentTerrainAmount ~= nil and imprRow.ValidAdjacentTerrainAmount > 0 then
                        cnt = plotCountAdjTerrain(pPlayer, pPlot)
                        if cnt < imprRow.ValidAdjacentTerrainAmount then
                            improvementValid = false
                            -- print("failed adjacent terrain")
                        end
                    end

                    -- Same adjacent
                    if improvementValid and not imprRow.SameAdjacentValid then
                        for pAdjPlot in PlotRingIterator(pPlot, 1, SECTOR_NONE, DIRECTION_CLOCKWISE) do
                            if pAdjPlot:GetOwner() == pPlayer:GetID() and imprRow.Index == pAdjPlot:GetImprovementType() then
                                -- print("failed same adjacent")
                                improvementValid = false
                                break
                            end
                        end
                    end
                    ]]

                    -- special handling for city park and fishery
                    -- check if the builder governor has the required promotion
                    if improvementValid and GameInfo.Governors ~= nil and
                            (imprRow.ImprovementType == "IMPROVEMENT_FISHERY" or imprRow.ImprovementType == "IMPROVEMENT_CITY_PARK") then

                        local pGovernor = GetAppointedGovernor(pPlayer:GetID(), builderGovernorIndex)
                        if pGovernor ~= nil then
                            if imprRow.ImprovementType == "IMPROVEMENT_FISHERY" then
                                if not pGovernor:HasPromotion(builderAquacultureHash) then
                                    -- print("Aquaculture promotion not present")
                                    improvementValid = false
                                end
                            elseif imprRow.ImprovementType == "IMPROVEMENT_CITY_PARK" then
                                if not pGovernor:HasPromotion(builderParksRecHash) then
                                    -- print("Parks and Recreation promotion not present")
                                    improvementValid = false
                                end
                            end
                        else
                            -- print("Builder Governor not present")
                            improvementValid = false
                        end
                    end

                    if improvementValid then
                        -- print(pPlot:GetIndex() .. " can have " .. imprRow.ImprovementType)
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function plotHasRemovableFeature(pPlot:table)
    local featureInfo = GameInfo.Features[pPlot:GetFeatureType()]
    if featureInfo ~= nil and featureInfo.Removable then
        return true
    end
    return false
end

local function IsAdjYieldWonder(featureInfo)
    -- List any wonders here that provide yield bonuses, but not mentioned in Features.xml
    local specialWonderList = {
        "FEATURE_TORRES_DEL_PAINE"
    }

    if featureInfo ~= nil and featureInfo.NaturalWonder then
        for adjYieldInfo in GameInfo.Feature_AdjacentYields() do
            if adjYieldInfo ~= nil and adjYieldInfo.FeatureType == featureInfo.FeatureType
                    and adjYieldInfo.YieldChange > 0 then
                return true
            end
        end

        for i, featureType in ipairs(specialWonderList) do
            if featureType == featureInfo.FeatureType then
                return true
            end
        end
    end
    return false
end

local function plotNextToBuffingWonder(pPlot:table)
    for pAdjPlot in PlotRingIterator(pPlot, 1, SECTOR_NONE, DIRECTION_CLOCKWISE) do
        local featureInfo = GameInfo.Features[pAdjPlot:GetFeatureType()]
        if IsAdjYieldWonder(featureInfo) then
            return true
        end
    end
    return false
end

-- Checks if the resource at this plot has an improvment for it, and the player has tech/civic to build it
local function plotResourceImprovable(pPlayer:table, pPlot:table)
    local resourceInfo = GameInfo.Resources[pPlot:GetResourceType()]
    if resourceInfo ~= nil then
        local improvementType = nil
        for validResourceInfo in GameInfo.Improvement_ValidResources() do
            if validResourceInfo ~= nil and validResourceInfo.ResourceType == resourceInfo.ResourceType then
                improvementType = validResourceInfo.ImprovementType
                if improvementType ~= nil then
                    local improvementInfo = GameInfo.Improvements[improvementType]
                    if playerCanHave(pPlayer, improvementInfo) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function plotHasCorrectImprovement(pPlot:table)
    local resourceInfo = GameInfo.Resources[pPlot:GetResourceType()]
    if resourceInfo ~= nil then
        for validResourceInfo in GameInfo.Improvement_ValidResources() do
            if validResourceInfo ~= nil and validResourceInfo.ResourceType == resourceInfo.ResourceType then
                local improvementType = validResourceInfo.ImprovementType
                if improvementType ~= nil and GameInfo.Improvements[improvementType] ~= nil then
                    local improvementID = GameInfo.Improvements[improvementType].RowId - 1
                    if pPlot:GetImprovementType() == improvementID then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function playerHasBuilderWonderModifier(playerID)
    return playerHasModifier(playerID, "MODIFIER_PLAYER_ADJUST_UNIT_WONDER_PERCENT")
end

local function playerHasBuilderDistrictModifier(playerID)
    return playerHasModifier(playerID, "MODIFIER_PLAYER_ADJUST_UNIT_DISTRICT_PERCENT")
end

-- ===========================================================================
-- Add rules for builder lens
-- ===========================================================================

local localPlayer = Game.GetLocalPlayer()
local pPlayer:table = Players[localPlayer]

local m_NothingColor:number = UI.GetColorValue("COLOR_NOTHING_BUILDER_LENS")
local m_ResourceColor:number = UI.GetColorValue("COLOR_RESOURCE_BUILDER_LENS")
local m_DamagedColor:number = UI.GetColorValue("COLOR_DAMAGED_BUILDER_LENS")
local m_RecommendedColor:number = UI.GetColorValue("COLOR_RECOMMENDED_BUILDER_LENS")
local m_HillColor:number = UI.GetColorValue("COLOR_HILL_BUILDER_LENS")
local m_FeatureColor:number = UI.GetColorValue("COLOR_FEATURE_BUILDER_LENS")
local m_GenericColor:number = UI.GetColorValue("COLOR_GENERIC_BUILDER_LENS")


-- NATIONAL PARK
--------------------------------------
table.insert(g_ModLenses_Builder_Config[m_NothingColor],
    function(pPlot)
        if pPlot:GetOwner() == localPlayer then
            if pPlot:IsNationalPark() then
                return m_NothingColor
            end
        end
        return -1
    end)


-- DAMAGED / PILLAGED
--------------------------------------
table.insert(g_ModLenses_Builder_Config[m_DamagedColor],
    function(pPlot)
        if pPlot:GetOwner() == localPlayer and not plotHasDistrict(pPlot) then
            if plotHasImprovement(pPlot) and pPlot:IsImprovementPillaged() then
                return m_DamagedColor
            end
        end
        return -1
    end)


-- RESOURCE
--------------------------------------
table.insert(g_ModLenses_Builder_Config[m_ResourceColor],
    function(pPlot)
        if pPlot:GetOwner() == localPlayer and not plotHasDistrict(pPlot) then
            if playerHasDiscoveredResource(pPlayer, pPlot) then
                if plotHasImprovement(pPlot) then
                    if plotHasCorrectImprovement(pPlot) then
                        return m_NothingColor
                    end
                end

                if plotResourceImprovable(pPlayer, pPlot) then
                    return m_ResourceColor
                else
                    return m_NothingColor
                end
            else
                -- Check for outside of working range here since we want to ignore any plot that are outside of working range,
                -- except extractable features and resources, since we can gain yields / resources
                -- But if they are withing the working range, then we want to give priority to recommended, hills and then feature
                if not plotWithinWorkingRange(pPlayer, pPlot) then
                    if plotHasFeature(pPlot) and not plotHasImprovement(pPlot) and
                            playerCanRemoveFeature(pPlayer, pPlot) then
                        return m_FeatureColor
                    else
                        return m_NothingColor
                    end
                end
            end
        end
        return -1
    end)


-- RECOMMENDED PLOTS
--------------------------------------
table.insert(g_ModLenses_Builder_Config[m_RecommendedColor],
    function(pPlot)
        if pPlot:GetOwner() == localPlayer and not plotHasDistrict(pPlot) and not plotHasImprovement(pPlot) then
            if plotHasFeature(pPlot) then
                local featureInfo = GameInfo.Features[pPlot:GetFeatureType()]
                if featureInfo.NaturalWonder then
                    return m_NothingColor
                end

                local terrainInfo = GameInfo.Terrains[pPlot:GetTerrainType()]

                -- 1. Non-hill woods next to river (lumbermill)
                local lumberImprovInfo = GameInfo.Improvements["IMPROVEMENT_LUMBER_MILL"]
                if not terrainInfo.Hills and featureInfo.FeatureType == "FEATURE_FOREST" and pPlot:IsRiver() and
                        playerCanHave(pPlayer, lumberImprovInfo) then

                    return m_RecommendedColor
                end

                -- 2. Floodplains
                local farmImprovInfo = GameInfo.Improvements["IMPROVEMENT_FARM"]
                local spitResult = Split(featureInfo.FeatureType, "_")
                if #spitResult > 1 and spitResult[2] == "FLOODPLAINS" and playerCanHave(pPlayer, farmImprovInfo) then
                    return m_RecommendedColor
                end

                local canHaveImpr:boolean = plotCanHaveImprovement(pPlayer, pPlot)

                -- 3. Volconic soil
                if featureInfo.FeatureType == "FEATURE_VOLCANIC_SOIL" and canHaveImpr then
                    return m_RecommendedColor
                end

                -- 3. Tile next to buffing wonder
                if plotNextToBuffingWonder(pPlot) and canHaveImpr then
                    return m_RecommendedColor
                end
            end
        end
        return -1
    end)


-- HILLS
--------------------------------------
table.insert(g_ModLenses_Builder_Config[m_RecommendedColor],
    function(pPlot)
        if pPlot:GetOwner() == localPlayer and not plotHasDistrict(pPlot) and not plotHasImprovement(pPlot) then
            -- If the plot has a feature, and we cannot extract it then ignore it
            if plotHasFeature(pPlot) and not playerCanRemoveFeature(pPlayer, pPlot) then
                return -1
            end

            local mineInfo = GameInfo.Improvements["IMPROVEMENT_MINE"]
            if pPlot:IsHills() and playerCanHave(pPlayer, mineInfo) then
                return m_HillColor
            end
        end
        return -1
    end)


-- FEATURE
--------------------------------------
table.insert(g_ModLenses_Builder_Config[m_FeatureColor],
    function(pPlot)
        if pPlot:GetOwner() == localPlayer and not plotHasDistrict(pPlot) and plotHasFeature(pPlot) and not plotHasImprovement(pPlot) then
            if playerCanRemoveFeature(pPlayer, pPlot) then
                return m_FeatureColor
            elseif playerCanImproveFeature(pPlayer, pPlot) then
                return m_FeatureColor
            else
                return m_NothingColor
            end
        end
        return -1
    end)


-- PRE-GENERIC (fallback)
--------------------------------------
table.insert(g_ModLenses_Builder_Config[m_GenericColor],
    function(pPlot)
        if pPlot:GetOwner() == localPlayer and not plotHasImprovement(pPlot) then

            -- Mountains, natural wonders, etec
            if plotHasDistrict(pPlot) then
                return m_NothingColor
            end

            -- Mountains, natural wonders, etec
            if pPlot:IsImpassable() then
                return m_NothingColor
            end

            -- Assume at this point if there is an improvement, don't color anything
            if plotHasImprovement(pPlot) then
                return m_NothingColor
            end

            if plotCanHaveImprovement(pPlayer, pPlot) then
                return m_GenericColor
            end
        end
        return -1
    end)
