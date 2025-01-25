--[[
Copyright (C) GtX (Andy), 2022

Author: GtX | Andy
Date: 14.02.2022
Revision: FS25-02

Contact:
https://forum.giants-software.com
https://github.com/GtX-Andy/FS25_ExtendedProductionPoint

Important:
Free for use in mods (FS25 Only) - no permission needed.
No modifications may be made to this script, including conversion to other game versions without written permission from GtX | Andy
Copying or removing any part of this code for external use without written permission from GtX | Andy is prohibited.

Frei verwendbar (Nur LS25) - keine erlaubnis nötig
Ohne schriftliche Genehmigung von GtX | Andy dürfen keine Änderungen an diesem Skript vorgenommen werden, einschließlich der Konvertierung in andere Spielversionen
Das Kopieren oder Entfernen irgendeines Teils dieses Codes zur externen Verwendung ohne schriftliche Genehmigung von GtX | Andy ist verboten.
]]

PlaceableExtendedProductionPoint = {}

PlaceableExtendedProductionPoint.MOD_NAME = g_currentModName
PlaceableExtendedProductionPoint.SPEC_NAME = string.format("%s.extendedProductionPoint", g_currentModName)
PlaceableExtendedProductionPoint.SPEC = string.format("spec_%s", PlaceableExtendedProductionPoint.SPEC_NAME)

local specEntryName = PlaceableExtendedProductionPoint.SPEC

function PlaceableExtendedProductionPoint.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(PlaceableInfoTrigger, specializations) and not SpecializationUtil.hasSpecialization(PlaceableProductionPoint, specializations)
end

function PlaceableExtendedProductionPoint.initSpecialization()
    local inputFillTypes = g_storeManager:getSpecTypeByName("prodPointInputFillTypes")

    if inputFillTypes ~= nil and inputFillTypes.loadFunc ~= nil and not inputFillTypes.extendedProductionAdded then
        local oldLoadFunc = inputFillTypes.loadFunc

        inputFillTypes.loadFunc = function(xmlFile, customEnvironment, baseDirectory)
            local fillTypeNames = oldLoadFunc(xmlFile, customEnvironment, baseDirectory)

            if fillTypeNames == nil and xmlFile:hasProperty("placeable.extendedProductionPoint") then
                xmlFile:iterate("placeable.extendedProductionPoint.productions.production", function (_, key)
                    xmlFile:iterate(key .. ".inputs.input", function (_, inputKey)
                        local fillTypeName = xmlFile:getValue(inputKey .. "#fillType")
                        fillTypeNames = fillTypeNames or {}
                        fillTypeNames[fillTypeName] = true
                    end)
                end)
            end

            return fillTypeNames
        end

        inputFillTypes.extendedProductionAdded = true
    end

    local outputFillTypes = g_storeManager:getSpecTypeByName("prodPointOutputFillTypes")

    if outputFillTypes ~= nil and outputFillTypes.loadFunc ~= nil and not outputFillTypes.extendedProductionAdded then
        local oldLoadFunc = outputFillTypes.loadFunc

        outputFillTypes.loadFunc = function(xmlFile, customEnvironment, baseDirectory)
            local fillTypeNames = oldLoadFunc(xmlFile, customEnvironment, baseDirectory)

            if fillTypeNames == nil and xmlFile:hasProperty("placeable.extendedProductionPoint") then
                xmlFile:iterate("placeable.extendedProductionPoint.productions.production", function (_, key)
                    xmlFile:iterate(key .. ".outputs.output", function (_, outputKey)
                        local fillTypeName = xmlFile:getValue(outputKey .. "#fillType")
                        fillTypeNames = fillTypeNames or {}
                        fillTypeNames[fillTypeName] = true
                    end)
                end)
            end

            return fillTypeNames
        end

        outputFillTypes.extendedProductionAdded = true
    end
end

function PlaceableExtendedProductionPoint.registerEvents(placeableType)
    SpecializationUtil.registerEvent(placeableType, "onOutputFillTypesChanged")
    SpecializationUtil.registerEvent(placeableType, "onProductionStatusChanged")
end

function PlaceableExtendedProductionPoint.registerFunctions(placeableType)
    SpecializationUtil.registerFunction(placeableType, "outputsChanged", PlaceableExtendedProductionPoint.outputsChanged)
    SpecializationUtil.registerFunction(placeableType, "productionStatusChanged", PlaceableExtendedProductionPoint.productionStatusChanged)
end

function PlaceableExtendedProductionPoint.registerOverwrittenFunctions(placeableType)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "setOwnerFarmId", PlaceableExtendedProductionPoint.setOwnerFarmId)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "collectPickObjects", PlaceableExtendedProductionPoint.collectPickObjects)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "canBuy", PlaceableExtendedProductionPoint.canBuy)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "updateInfo", PlaceableExtendedProductionPoint.updateInfo)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "getNeedMinuteChanged", PlaceableExtendedProductionPoint.getNeedMinuteChanged)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "getNeedHourChanged", PlaceableExtendedProductionPoint.getNeedHourChanged)
end

function PlaceableExtendedProductionPoint.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", PlaceableExtendedProductionPoint)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", PlaceableExtendedProductionPoint)
    SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", PlaceableExtendedProductionPoint)
    SpecializationUtil.registerEventListener(placeableType, "onWriteStream", PlaceableExtendedProductionPoint)
    SpecializationUtil.registerEventListener(placeableType, "onReadStream", PlaceableExtendedProductionPoint)
    SpecializationUtil.registerEventListener(placeableType, "onMinuteChanged", PlaceableExtendedProductionPoint)
    SpecializationUtil.registerEventListener(placeableType, "onHourChanged", PlaceableExtendedProductionPoint)
    SpecializationUtil.registerEventListener(placeableType, "onPeriodChanged", PlaceableExtendedProductionPoint)
    SpecializationUtil.registerEventListener(placeableType, "onBuy", PlaceableExtendedProductionPoint)
end

function PlaceableExtendedProductionPoint.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("ExtendedProductionPoint")

    ExtendedProductionPoint.registerXMLPaths(schema, basePath .. ".extendedProductionPoint")

    schema:setXMLSpecializationType()
end

function PlaceableExtendedProductionPoint.registerSavegameXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("ExtendedProductionPoint")
    ExtendedProductionPoint.registerSavegameXMLPaths(schema, basePath)
    schema:setXMLSpecializationType()
end

function PlaceableExtendedProductionPoint:onLoad(savegame)
    local spec = self[specEntryName]

    if spec == nil then
        Logging.error("[%s] Specialisation with name 'extendedProductionPoint' was not found in modDesc!", PlaceableExtendedProductionPoint.MOD_NAME)
    end

    local productionPoint = ExtendedProductionPoint.new(self.isServer, self.isClient, self.baseDirectory)

    productionPoint.owningPlaceable = self
    productionPoint.customEnvironment = self.customEnvironment

    productionPoint.storeItem = self.storeItem
    productionPoint.xmlFile = self.xmlFile

    if productionPoint:load(self.components, self.xmlFile, "placeable.extendedProductionPoint", self.customEnvironment, self.i3dMappings) then
        spec.productionPoint = productionPoint

        if not spec.productionPoint.collectRainWater then
            SpecializationUtil.removeEventListener(self, "onMinuteChanged", PlaceableExtendedProductionPoint)
        end

        if not spec.productionPoint.extendedFeaturesNeedHourChanged then
            SpecializationUtil.removeEventListener(self, "onHourChanged", PlaceableExtendedProductionPoint)
        end

        if not spec.productionPoint.extendedFeaturesNeedPeriodChanged then
            SpecializationUtil.removeEventListener(self, "onPeriodChanged", PlaceableExtendedProductionPoint)
        end
    else
        productionPoint:delete()
        self:setLoadingState(Placeable.LOADING_STATE_ERROR)
    end

    self.spec_extendedProductionPoint = spec -- Just for reference
end

function PlaceableExtendedProductionPoint:onDelete()
    local spec = self[specEntryName]

    if spec.productionPoint ~= nil then
        spec.productionPoint:delete()
        spec.productionPoint = nil
    end
end

function PlaceableExtendedProductionPoint:onFinalizePlacement()
    local spec = self[specEntryName]

    if spec.productionPoint ~= nil then
        spec.productionPoint:register(true)
        spec.productionPoint:setOwnerFarmId(self:getOwnerFarmId())
        spec.productionPoint:findStorageExtensions()
        spec.productionPoint:updateFxState()

        if self.isServer and g_currentMission.environment ~= nil then
            if spec.productionPoint.extendedFeaturesActiveSeasons ~= nil then
                spec.productionPoint:onPeriodChanged(g_currentMission.environment.currentPeriod)
            end

            if spec.productionPoint.extendedFeaturesOpeningHours ~= nil then
                spec.productionPoint:onHourChanged(g_currentMission.environment.currentHour)
            end
        end
    end
end

function PlaceableExtendedProductionPoint:onReadStream(streamId, connection)
    local spec = self[specEntryName]

    if spec.productionPoint ~= nil then
        local productionPointId = NetworkUtil.readNodeObjectId(streamId)

        spec.productionPoint:readStream(streamId, connection)
        g_client:finishRegisterObject(spec.productionPoint, productionPointId)
    end
end

function PlaceableExtendedProductionPoint:onWriteStream(streamId, connection)
    local spec = self[specEntryName]

    if spec.productionPoint ~= nil then
        NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(spec.productionPoint))
        spec.productionPoint:writeStream(streamId, connection)
        g_server:registerObjectInStream(connection, spec.productionPoint)
    end
end

function PlaceableExtendedProductionPoint:onMinuteChanged(currentMinute)
    if self.isServer then
        local spec = self[specEntryName]

        if spec.productionPoint ~= nil and spec.productionPoint.isOwned and spec.productionPoint.collectRainWater then
            local lastRainScale = g_currentMission.environment.weather:getRainFallScale(spec.productionPoint.collectSnow)

            if lastRainScale > 0.05 then
                spec.productionPoint:updateRainWaterCollector(lastRainScale)
            end
        end
    end
end

function PlaceableExtendedProductionPoint:onHourChanged(currentHour)
    if self.isServer then
        local spec = self[specEntryName]

        if spec.productionPoint ~= nil and spec.productionPoint.extendedFeaturesNeedHourChanged then
            spec.productionPoint:onHourChanged(currentHour)
        end
    end
end

function PlaceableExtendedProductionPoint:onPeriodChanged(currentPeriod)
    if self.isServer then
        local spec = self[specEntryName]

        if spec.productionPoint ~= nil and spec.productionPoint.extendedFeaturesNeedPeriodChanged then
            spec.productionPoint:onPeriodChanged(currentPeriod)
        end
    end
end

function PlaceableExtendedProductionPoint:onBuy()
    local serverFarmId = g_currentMission:getFarmId()
    local numProductionPoints = 0

    for _, existingPlaceable in ipairs(g_currentMission.placeableSystem.placeables) do
        if existingPlaceable:getOwnerFarmId() == serverFarmId then
            if existingPlaceable.spec_productionPoint ~= nil or existingPlaceable.spec_extendedProductionPoint then
                numProductionPoints += 1
            end
        end
    end

    g_achievementManager:tryUnlock("NumProductionPoints", numProductionPoints)
end

function PlaceableExtendedProductionPoint:outputsChanged(outputs, state)
    SpecializationUtil.raiseEvent(self, "onOutputFillTypesChanged", outputs, state)
end

function PlaceableExtendedProductionPoint:productionStatusChanged(production, status)
    SpecializationUtil.raiseEvent(self, "onProductionStatusChanged", production, status)
end

function PlaceableExtendedProductionPoint:loadFromXMLFile(xmlFile, key)
    local spec = self[specEntryName]

    if spec.productionPoint ~= nil then
        spec.productionPoint:loadFromXMLFile(xmlFile, key)
    end
end

function PlaceableExtendedProductionPoint:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self[specEntryName]

    if spec.productionPoint ~= nil then
        spec.productionPoint:saveToXMLFile(xmlFile, key, usedModNames)
    end
end

function PlaceableExtendedProductionPoint:updateInfo(superFunc, infoTable)
    superFunc(self, infoTable)

    local spec = self[specEntryName]

    if spec.productionPoint ~= nil then
        spec.productionPoint:updateInfo(infoTable)
    end
end

function PlaceableExtendedProductionPoint:setOwnerFarmId(superFunc, farmId, noEventSend)
    superFunc(self, farmId, noEventSend)

    local spec = self[specEntryName]

    if spec.productionPoint ~= nil then
        spec.productionPoint:setOwnerFarmId(farmId)
    end
end

function PlaceableExtendedProductionPoint:collectPickObjects(superFunc, node)
    local spec = self[specEntryName]

    if spec.productionPoint.loadingStation ~= nil then
        for i = 1, #spec.productionPoint.loadingStation.loadTriggers do
            local loadTrigger = spec.productionPoint.loadingStation.loadTriggers[i]

            if node == loadTrigger.triggerNode then
                return
            end
        end
    end

    for i = 1, #spec.productionPoint.unloadingStation.unloadTriggers do
        local unloadTrigger = spec.productionPoint.unloadingStation.unloadTriggers[i]

        if node == unloadTrigger.exactFillRootNode then
            return
        end
    end

    superFunc(self, node)
end

function PlaceableExtendedProductionPoint:canBuy(superFunc)
    if not g_currentMission.productionChainManager:getHasFreeSlots() then
        return false, g_i18n:getText("warning_maxNumOfProdPointsReached")
    end

    return superFunc(self)
end

function PlaceableExtendedProductionPoint:getNeedMinuteChanged(superFunc)
    local spec = self[specEntryName]

    if self.isServer and spec.productionPoint ~= nil and spec.productionPoint.collectRainWater then
        return true
    end

    return superFunc(self)
end

function PlaceableExtendedProductionPoint:getNeedHourChanged(superFunc)
    local spec = self[specEntryName]

    if self.isServer and spec.productionPoint ~= nil and spec.productionPoint.extendedFeaturesNeedHourChanged then
        return true
    end

    return superFunc(self)
end

------------------------------------------------------------------------------------------------------------------------------------
-- ExtendedProductionPoint (Creating a new class to keep this separate from Base Game factories that make no use of the features) --
------------------------------------------------------------------------------------------------------------------------------------

ExtendedProductionPoint = {}

ExtendedProductionPoint.DISTRIBUTION_NAMES = {
    "keep",
    "directSell",
    "autoDeliver"
}

ExtendedProductionPoint.AUTO_OFF_PROD_STATUS = {
    [ProductionPoint.PROD_STATUS.MISSING_INPUTS] = true,
    [ProductionPoint.PROD_STATUS.NO_OUTPUT_SPACE] = true
}

local ExtendedProductionPoint_mt = Class(ExtendedProductionPoint, ProductionPoint)
InitObjectClass(ExtendedProductionPoint, "ExtendedProductionPoint")

function ExtendedProductionPoint.registerXMLPaths(schema, basePath)
    ProductionPoint.registerXMLPaths(schema, basePath)

    schema:register(XMLValueType.BOOL, basePath .. "#hiddenOnUI", "Future Use", false)
    schema:register(XMLValueType.BOOL, basePath .. ".operatingConditions#alwaysActive", "Maintains the active state for all productions useful for fruit trees etc where turning on/off is strange.", false)

    -- Operating Seasons
    schema:register(XMLValueType.STRING_LIST, basePath .. ".operatingConditions.activeSeasons#seasons", "Seasons the factory can operate separated by a single whitespace. [ SPRING | SUMMER | AUTUMN | WINTER ]")
    schema:register(XMLValueType.STRING, basePath .. ".operatingConditions.activeSeasons.closedTexts#spring", "The closed text that will be displayed in the info box if the factory is closed during Spring")
    schema:register(XMLValueType.STRING, basePath .. ".operatingConditions.activeSeasons.closedTexts#summer", "The closed text that will be displayed in the info box if the factory is closed during Summer")
    schema:register(XMLValueType.STRING, basePath .. ".operatingConditions.activeSeasons.closedTexts#autumn", "The closed text that will be displayed in the info box if the factory is closed during Autumn")
    schema:register(XMLValueType.STRING, basePath .. ".operatingConditions.activeSeasons.closedTexts#winter", "The closed text that will be displayed in the info box if the factory is closed during Winter")

    -- Operating Time
    schema:register(XMLValueType.INT, basePath .. ".operatingConditions.activeHours#startTime", "Start day time")
    schema:register(XMLValueType.INT, basePath .. ".operatingConditions.activeHours#endTime", "End day time")
    schema:register(XMLValueType.BOOL, basePath .. ".operatingConditions.activeHours#displayHours", "The operating hours that will be displayed in the info box", true)
    schema:register(XMLValueType.BOOL, basePath .. ".operatingConditions.activeHours#addHoursToName", "Adds the operating hours to the end of the factory name. This is shown in places such as the production GUI.", true)

    -- Only when included with the mod
    if ExtendedLoadingStation ~= nil and ExtendedLoadingStation.registerXMLPaths ~= nil then
        ExtendedLoadingStation.registerXMLPaths(schema, basePath .. ".extendedLoadingStation")
    end

    schema:register(XMLValueType.BOOL, basePath .. ".productions.production(?)#autoOff", "(Disabled when 'alwaysActive=true') Automatically stops production when materials are missing or no output space, starting will also not be possible", false)
    schema:register(XMLValueType.BOOL, basePath .. ".productions.production(?)#showAutoOffLitres", "When 'true' the ingredient name and minimum fill level or space required will also be displayed when trying to start production", true)

    schema:register(XMLValueType.FLOAT, basePath .. ".rainWaterCollector#rainWaterPerMinute", "The value per minute add to the 'WATER' storage. This value is adjusted when only raining lightly", 0)
    schema:register(XMLValueType.BOOL, basePath .. ".rainWaterCollector#collectSnow", "Add snow and rain to the 'WATER' storage", false)

    ExtendedProductionPoint.registerDisplayXMLPaths(schema, basePath .. ".factoryNameDisplays", false)
    ExtendedProductionPoint.registerDisplayXMLPaths(schema, basePath .. ".productions.production(?).nameDisplays", false)

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".productions.production(?).playerTrigger#node", "Player trigger to toggle the operation state of the production")
    schema:register(XMLValueType.STRING, basePath .. ".productions.production(?).playerTrigger#menuAction", "Optional inputAction name used to open Factory UI")

    ObjectChangeUtil.registerObjectChangeXMLPaths(schema, basePath .. ".productions.production(?).operatingObjectChanges")

    SoundManager.registerSampleXMLPaths(schema, basePath .. ".productions.production(?).operatingSounds", "start(?)")
    SoundManager.registerSampleXMLPaths(schema, basePath .. ".productions.production(?).operatingSounds", "stop(?)")
    SoundManager.registerSampleXMLPaths(schema, basePath .. ".productions.production(?).operatingSounds", "work(?)")

    ExtendedProductionPoint.registerProductionXMLPaths(schema, basePath .. ".productions.production(?).inputs.input(?)")

    -- Input only as it is mainly for animals and these are not supported on OUTPUT as it is not a husbandry ;-)
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".productions.production(?).inputs.input(?).animatedVisibilityNodes.visibilityNode(?)#linkNode", "Link node")
    schema:register(XMLValueType.STRING, basePath .. ".productions.production(?).inputs.input(?).animatedVisibilityNodes.visibilityNode(?)#clipNames", "Animation clip names. If more than one name is given then it will be random each time visibility changes")
    schema:register(XMLValueType.STRING, basePath .. ".productions.production(?).inputs.input(?).animatedVisibilityNodes.visibilityNode(?)#characterFilename", "External mesh or combined file")
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".productions.production(?).inputs.input(?).animatedVisibilityNodes.visibilityNode(?)#skeletonNode", "Skeleton node index to attach animation to. Uses 'characterFilename' i3d if 'animationFilename' i3d is not provided.", "0")
    schema:register(XMLValueType.STRING, basePath .. ".productions.production(?).inputs.input(?).animatedVisibilityNodes.visibilityNode(?)#animationFilename", "External animation file to link with mesh loaded from 'characterFilename'")
    schema:register(XMLValueType.INT, basePath .. ".productions.production(?).inputs.input(?).animatedVisibilityNodes.visibilityNode(?)#clipTrack", "Track index", 0)
    schema:register(XMLValueType.BOOL, basePath .. ".productions.production(?).inputs.input(?).animatedVisibilityNodes.visibilityNode(?)#randomStart", "Use a random starting point", true)
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".productions.production(?).inputs.input(?).animatedVisibilityNodes.visibilityNode(?)#meshNode", "Mesh node parent, all shape nodes will have shader adjusted recursively (tileAndMirrorShader)")
    schema:register(XMLValueType.INT, basePath .. ".productions.production(?).inputs.input(?).animatedVisibilityNodes.visibilityNode(?)#tileU", "Shader tileU (atlasInvSizeAndOffsetUV)")
    schema:register(XMLValueType.INT, basePath .. ".productions.production(?).inputs.input(?).animatedVisibilityNodes.visibilityNode(?)#tileV", "Shader tileV (atlasInvSizeAndOffsetUV)")
    schema:register(XMLValueType.INT, basePath .. ".productions.production(?).inputs.input(?).animatedVisibilityNodes.visibilityNode(?)#numTilesU", "Shader numTilesU (atlasInvSizeAndOffsetUV)", 2)
    schema:register(XMLValueType.INT, basePath .. ".productions.production(?).inputs.input(?).animatedVisibilityNodes.visibilityNode(?)#numTilesV", "Shader numTilesV (atlasInvSizeAndOffsetUV)", 2)
    schema:register(XMLValueType.FLOAT, basePath .. ".productions.production(?).inputs.input(?).animatedVisibilityNodes.visibilityNode(?)#dirtFactor", "Shader dirt factor (dirt)", 0)

    ExtendedProductionPoint.registerProductionXMLPaths(schema, basePath .. ".productions.production(?).outputs.output(?)")

    ObjectChangeUtil.registerObjectChangeXMLPaths(schema, basePath .. ".productions.production(?).outputs.output(?).distributionObjectChanges.keep")
    ObjectChangeUtil.registerObjectChangeXMLPaths(schema, basePath .. ".productions.production(?).outputs.output(?).distributionObjectChanges.directSell")
    ObjectChangeUtil.registerObjectChangeXMLPaths(schema, basePath .. ".productions.production(?).outputs.output(?).distributionObjectChanges.autoDeliver")

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".animalInput#triggerNode", "Animal unloading trigger")

    schema:register(XMLValueType.STRING, basePath .. ".animalInput#animalMinimumAgeText", "Optional minimum age text shown when trying to move animals to the factory", "Recommended English: This animal is too young, a minimum age of %s will be accepted!")
    schema:register(XMLValueType.STRING, basePath .. ".animalInput#animalMaximumAgeText", "Optional maximum age text shown when trying to move animals to the factory", "Recommended English: This animal is too old, a maximum age of %s will be accepted!")
    schema:register(XMLValueType.STRING, basePath .. ".animalInput#unloadConfirmationText", "Optional confirmation text used to confirm animal move", "Recommended English: Do you want to move %d animals (%s) to the %s?")
    schema:register(XMLValueType.STRING, basePath .. ".animalInput#unloadSuccessText", "Optional success text shown after moving animals to factory", "Recommended English: Animals were successfully moved to %s!")
    schema:register(XMLValueType.STRING, basePath .. ".animalInput#moveButtonText", "Optional text displayed on dialogue button", "Recommended English: Move to %s")

    schema:register(XMLValueType.STRING, basePath .. ".animalInput.animal(?)#type", "Animal type name, for example: COW | PIG | SHEEP| CHICKEN")
    schema:register(XMLValueType.STRING, basePath .. ".animalInput.animal(?)#fillType", "Fill type that each animal will be converted to 1 > 1")
    schema:register(XMLValueType.INT, basePath .. ".animalInput.animal(?)#minimumAge", "The minimum age in months that will be accepted. MIN:0 | MAX: 60")
    schema:register(XMLValueType.INT, basePath .. ".animalInput.animal(?)#maximumAge", "The maximum age in months that will be accepted. MIN:1 | MAX: 60")
end

function ExtendedProductionPoint.registerSavegameXMLPaths(schema, basePath)
    ProductionPoint.registerSavegameXMLPaths(schema, basePath)
end

function ExtendedProductionPoint.registerProductionXMLPaths(schema, basePath)
    ExtendedProductionPoint.registerDisplayXMLPaths(schema, basePath .. ".displays", true)

    schema:register(XMLValueType.FLOAT, basePath .. ".fillMovers.fillMover(?)#minScaleY", "Fill plane min scale y")
    schema:register(XMLValueType.FLOAT, basePath .. ".fillMovers.fillMover(?)#maxScaleY", "Fill plane max scale y")

    FillPlane.registerXMLPaths(schema, basePath .. ".fillMovers.fillMover(?)")
    FillPlaneUtil.registerFillPlaneXMLPaths(schema, basePath .. ".dynamicFillPlanes.dynamicFillPlane(?)")

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".visibilityNodeGroups.visibilityNodeGroup(?)#node", "Visibility nodes root node")
end

function ExtendedProductionPoint.registerDisplayXMLPaths(schema, basePath, production)
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".display(?)#node", "Display start node")
    schema:register(XMLValueType.STRING, basePath .. ".display(?)#font", "Display font name")
    schema:register(XMLValueType.BOOL, basePath .. ".display(?)#upperCase", "Display text upper case only", false)
    schema:register(XMLValueType.STRING, basePath .. ".display(?)#alignment", "Display text alignment")
    schema:register(XMLValueType.FLOAT, basePath .. ".display(?)#size", "Display text size", 0.03)
    schema:register(XMLValueType.FLOAT, basePath .. ".display(?)#scaleX", "Display text x scale", 1)
    schema:register(XMLValueType.FLOAT, basePath .. ".display(?)#scaleY", "Display text y scale", 1)
    schema:register(XMLValueType.STRING, basePath .. ".display(?)#mask", "Display text mask. If display type 'TITLE' then optionally 'AUTO_MASK' can be used and the mask will be adjusted to the text length", "0000000")
    schema:register(XMLValueType.FLOAT, basePath .. ".display(?)#emissiveScale", "Display emissive scale", 0.2)
    schema:register(XMLValueType.COLOR, basePath .. ".display(?)#color", "Display text colour", "0.9 0.9 0.9 1")
    schema:register(XMLValueType.COLOR, basePath .. ".display(?)#hiddenColor", "Display text hidden colour")

    if production then
        schema:register(XMLValueType.STRING, basePath .. ".display(?)#fillLevelColorType", "Percent & FillLevel options. NONE: No colour change | STANDARD: Text colour will change from 'green > red' | INVERTED: Text colour will change from 'red > green'", "NONE")
        schema:register(XMLValueType.STRING, basePath .. ".display(?)#type", "Display type. Options: fillLevel | percent | capacity | title")
    end
end

function ExtendedProductionPoint.new(isServer, isClient, baseDirectory, customMt)
    local self = ProductionPoint.new(isServer, isClient, baseDirectory, customMt or ExtendedProductionPoint_mt)

    self.extendedFeaturesByFillType = {}
    self.distributionObjectChanges = {}

    self.extendedFeaturesInteractionTriggers = {}
    self.extendedFeaturesMenuAction = {}

    self.xmlFilename = ""

    self.collectSnow = true
    self.collectRainWater = false

    self.rainWaterCollected = 0
    self.rainWaterPerMinute = 0
    self.rainWaterThreshold = 5

    self.hiddenOnUI = false
    self.extendedFeaturesAlwaysActive = false

    self.extendedFeaturesInfoTables = {
        details = {
            title = g_i18n:getText("ui_details"),
            accentuate = true
        }
    }

    return self
end

function ExtendedProductionPoint:load(components, xmlFile, key, customEnvironment, i3dMappings)
    self.xmlFilename = xmlFile:getFilename() -- Error protection for things like EffectManager, missing in base code
    self.customEnvironment = customEnvironment -- Required by many things such as AnimationManager, and EffectManager, UnloadingStation and PalletSpawner
    self.i3dMappings = i3dMappings -- Object change requires this to use mappings

    local extendedLoadingStationKey = key .. ".extendedLoadingStation"

    if xmlFile:hasProperty(extendedLoadingStationKey) then
        if not xmlFile:hasProperty(key .. ".loadingStation") then
            if ExtendedLoadingStation ~= nil then
                self.loadingStation = ExtendedLoadingStation.new(self.isServer, self.isClient)

                if self.loadingStation:load(components, xmlFile, extendedLoadingStationKey, customEnvironment, i3dMappings, components[1].node) then
                    self.loadingStation.owningPlaceable = self.owningPlaceable
                    self.loadingStation.useOwnerForAccess = true

                    self.loadingStation:register(true)
                else
                    Logging.xmlError(xmlFile, "Unable to load loading station '%s'", extendedLoadingStationKey)

                    return false
                end
            else
                Logging.xmlError(xmlFile, "Unable to load loading station '%s' ExtendedLoadingStation.lua was not loaded with mod '%s', visit 'www.github.com/GtX-Andy' for latest release.", extendedLoadingStationKey, customEnvironment)

                return false
            end
        else
            Logging.xmlError(xmlFile, "Unable to load extended loading station '%s' when '%s.loadingStation' is used!", extendedLoadingStationKey, key)
        end
    end

    if not ExtendedProductionPoint:superClass().load(self, components, xmlFile, key, customEnvironment, i3dMappings) then
        return false
    end

    local hasExtendedFeatures = false
    local baseDirectory = self.baseDirectory

    local function addExtendedFeatures(fillType, name, extendedFeatures)
        if extendedFeatures ~= nil then
            if self.extendedFeaturesByFillType[fillType] == nil then
                self.extendedFeaturesByFillType[fillType] = {}
            end

            if self.extendedFeaturesByFillType[fillType][name] == nil then
                self.extendedFeaturesByFillType[fillType][name] = extendedFeatures
            else
                for _, extendedFeature in pairs (extendedFeatures) do
                    table.insert(self.extendedFeaturesByFillType[fillType][name], extendedFeature)
                end
            end

            hasExtendedFeatures = true
        end
    end

    self:findStorageExtensions()

    self.hiddenOnUI = xmlFile:getValue(key .. "#hiddenOnUI", false)
    self.extendedFeaturesAlwaysActive = xmlFile:getValue(key .. ".operatingConditions#alwaysActive", false)

    -- Allows seasonal operation using the 4 seasons (SPRING SUMMER AUTUMN WINTER).
    -- Only use a maximum of 3 seasons otherwise there is no need to use the feature.
    local activeSeasonNames = xmlFile:getValue(key .. ".operatingConditions.activeSeasons#seasons")

    if activeSeasonNames ~= nil then
        local numActiveSeasons = 0
        local activeSeasons = {}

        for _, seasonName in ipairs(activeSeasonNames) do
            local season = Season.getByName(seasonName)

            if season ~= nil then
                activeSeasons[season] = seasonName:upper()
                numActiveSeasons += 1
            else
                Logging.xmlWarning(xmlFile, "Invalid season name '%s' given at '%s.openingSeasons#seasons', value will be ignored.", seasonName, key)
                Logging.warning("Possible names: %s", Season.getAllNames())
            end
        end

        -- No need to activate if all 4 seasons are used because it will never turn off
        if numActiveSeasons > 0 and numActiveSeasons < 4 then
            self.extendedFeaturesActiveSeasons = activeSeasons

            for _, seasonName in ipairs ({"spring", "summer", "autumn", "winter"}) do
                local closedText = xmlFile:getValue(string.format("%s.operatingConditions.activeSeasons.closedTexts#%s", key, seasonName))

                if closedText ~= nil then
                    local season = Season.getByName(seasonName)

                    if season ~= nil then
                        if self.extendedFeaturesInfoTables.seasons == nil then
                            self.extendedFeaturesInfoTables.seasons = {}
                        end

                        self.extendedFeaturesInfoTables.seasons[season] = {
                            title = "",
                            text = g_i18n:convertText(closedText, customEnvironment)
                        }
                    end
                end
            end

            self.extendedFeaturesNeedPeriodChanged = true -- Used to unsubscribe to the listener
            self.extendedFeaturesAlwaysActive = true -- No need to turn a factory on / off if using opening times or opening seasons
        end
    end

    -- Allow opening hours only after seasonal operation is evaluated
    local startTime = xmlFile:getValue(key .. ".operatingConditions.activeHours#startTime")

    if startTime ~= nil then
        local endTime = xmlFile:getValue(key .. ".operatingConditions.activeHours#endTime")

        if endTime ~= nil then
            self.extendedFeaturesOpeningHours = {
                startTime = startTime,
                endTime = endTime,
                addHoursToName = xmlFile:getValue(key .. ".operatingConditions.activeHours#addHoursToName", true)
            }

            if xmlFile:getValue(key .. ".operatingConditions.activeHours#displayHours", true) then
                self.extendedFeaturesInfoTables.openingHours = {
                    title = g_i18n:getText("ui_operatingHours"),
                    text = string.format("%02d:00 - %02d:00", startTime, endTime)
                }
            end

            self.extendedFeaturesNeedHourChanged = true -- Check this from the placeable so it can be shared.
            self.extendedFeaturesAlwaysActive = true -- No need to turn a factory on / off if using opening times or opening seasons
        end
    end

    -- This is only for name defined in the XML not for renaming
    if self.isClient and self.name ~= nil then
        self.extendedFeaturesFactoryNameDisplays = self:loadDisplays(xmlFile, key .. ".factoryNameDisplays", components, i3dMappings, self.name, "FACTORY_NAME")
    end

    xmlFile:iterate(key .. ".productions.production", function (productionIndex, productionKey)
        local production = self.productions[productionIndex]

        if production ~= nil then
            local canAddTrigger = false

            production.extendedFeaturesAutoOff = false

            if not self.extendedFeaturesAlwaysActive then
                production.extendedFeaturesAutoOff = xmlFile:getValue(productionKey .. "#autoOff", false)
                production.extendedFeaturesShowAutoOffLitres = xmlFile:getValue(productionKey .. "#showAutoOffLitres", true)
                canAddTrigger = true
            end

            local triggerId = xmlFile:getValue(productionKey .. ".playerTrigger#node", nil, components, i3dMappings)

            if triggerId ~= nil and self.extendedFeaturesInteractionTriggers[triggerId] == nil then
                if not self.hiddenOnUI then
                    local menuAction = xmlFile:getValue(productionKey .. ".playerTrigger#menuAction")

                    if menuAction ~= nil then
                        if InputAction[menuAction] then
                            self.extendedFeaturesMenuAction[triggerId] = menuAction
                            canAddTrigger = true
                        else
                            Logging.xmlWarning("Player trigger menu action '%s' not defined!", menuAction)
                        end
                    end
                end

                if canAddTrigger then
                    if self.extendedActivatable == nil then
                        self.extendedActivatable = ExtendedProductionPointActivatable.new(self)
                    end

                    self.extendedFeaturesInteractionTriggers[triggerId] = production
                    addTrigger(triggerId, "productionInteractionTriggerCallback", self)
                end
            end

            if self.isClient then
                production.extendedFeaturesNameDisplays = self:loadDisplays(xmlFile, productionKey .. ".nameDisplays", components, i3dMappings, production.name, "PRODUCTION_NAME")

                xmlFile:iterate(productionKey .. ".inputs.input", function (inputIndex, inputKey)
                    local input = production.inputs[inputIndex]

                    if input ~= nil then
                        local inputType = input.type
                        local displays, titleDisplays = self:loadDisplays(xmlFile, inputKey .. ".displays", components, i3dMappings, inputType, "INPUT_OUTPUT")

                        addExtendedFeatures(inputType, "displays", displays)
                        addExtendedFeatures(inputType, "titleDisplays", titleDisplays)

                        addExtendedFeatures(inputType, "fillMovers", self:loadFillMovers(xmlFile, inputKey, components, i3dMappings))
                        addExtendedFeatures(inputType, "dynamicFillPlanes", self:loadDynamicFillPlanes(xmlFile, inputKey, components, i3dMappings, inputType))

                        addExtendedFeatures(inputType, "visibilityNodeGroups", self:loadVisibilityNodeGroups(xmlFile, inputKey, components, i3dMappings))
                        addExtendedFeatures(inputType, "animatedVisibilityNodes", self:loadAnimatedVisibilityNodes(xmlFile, inputKey, components, i3dMappings))
                    end
                end)

                xmlFile:iterate(productionKey .. ".outputs.output", function (outputIndex, outputKey)
                    local output = production.outputs[outputIndex]

                    if output ~= nil and not output.sellDirectly then
                        local outputType = output.type
                        local displays, titleDisplays = self:loadDisplays(xmlFile, outputKey .. ".displays", components, i3dMappings, outputType, "INPUT_OUTPUT")

                        addExtendedFeatures(outputType, "displays", displays)
                        addExtendedFeatures(outputType, "titleDisplays", titleDisplays)

                        addExtendedFeatures(outputType, "fillMovers", self:loadFillMovers(xmlFile, outputKey, components, i3dMappings))
                        addExtendedFeatures(outputType, "dynamicFillPlanes", self:loadDynamicFillPlanes(xmlFile, outputKey, components, i3dMappings, outputType))

                        addExtendedFeatures(outputType, "visibilityNodeGroups", self:loadVisibilityNodeGroups(xmlFile, outputKey, components, i3dMappings))

                        local distributionKey = outputKey .. ".distributionObjectChanges"

                        if xmlFile:hasProperty(distributionKey) then
                            self.distributionObjectChanges[outputType] = {}

                            for i, distributionName in ipairs (ExtendedProductionPoint.DISTRIBUTION_NAMES) do
                                local objectChanges = {}

                                ObjectChangeUtil.loadObjectChangeFromXML(xmlFile, distributionKey .. "." .. distributionName, objectChanges, components, self)

                                if distributionName == "keep" then
                                    ObjectChangeUtil.setObjectChanges(objectChanges, true)
                                end

                                self.distributionObjectChanges[outputType][i] = objectChanges
                            end
                        end
                    end
                end)

                if xmlFile:hasProperty(productionKey .. ".operatingObjectChanges") then
                    production.extendedFeaturesObjectChanges = {}

                    ObjectChangeUtil.loadObjectChangeFromXML(xmlFile, productionKey .. ".operatingObjectChanges", production.extendedFeaturesObjectChanges, components, self)
                    ObjectChangeUtil.setObjectChanges(production.extendedFeaturesObjectChanges, false)
                end

                production.extendedFeaturesSamples = {
                    start = g_soundManager:loadSampleFromXML(xmlFile, productionKey .. ".operatingSounds", "start", self.baseDirectory, components, 1, AudioGroup.ENVIRONMENT, i3dMappings, nil),
                    stop = g_soundManager:loadSampleFromXML(xmlFile, productionKey .. ".operatingSounds", "stop", self.baseDirectory, components, 1, AudioGroup.ENVIRONMENT, i3dMappings, nil),
                    work = g_soundManager:loadSampleFromXML(xmlFile, productionKey .. ".operatingSounds", "work", self.baseDirectory, components, 0, AudioGroup.ENVIRONMENT, i3dMappings, nil)
                }
            end
        end
    end)

    if self.extendedFeaturesAlwaysActive then
        self.extendedFeaturesHideActivateButton = true

        -- Adds the ability for the activate button to be removed so there is no confusion for productions that auto start / stop or have seasonal / opening hours.
        if InGameMenuProductionFrame.extendedUpdateMenuButtons == nil then
            InGameMenuProductionFrame.extendedUpdateMenuButtons = function(frame)
                local production, productionPoint = frame:getSelectedProduction()

                if productionPoint ~= nil and productionPoint.extendedFeaturesHideActivateButton then
                    if table.removeElement(frame.menuButtonInfo, frame.activateButtonInfo) then
                        frame:setMenuButtonInfoDirty()
                    end
                end
            end

            InGameMenuProductionFrame.updateMenuButtons = Utils.appendedFunction(InGameMenuProductionFrame.updateMenuButtons, InGameMenuProductionFrame.extendedUpdateMenuButtons)
        end
    end

    local rainWaterPerMinute = xmlFile:getValue(key .. ".rainWaterCollector#rainWaterPerMinute", 0)

    if rainWaterPerMinute > 0 then
        if self.storage:getIsFillTypeSupported(FillType.WATER) then
            self.collectSnow = xmlFile:getValue(key .. ".rainWaterCollector#collectSnow", self.collectSnow)

            self.rainWaterPerMinute = rainWaterPerMinute
            self.collectRainWater = true
        else
            Logging.info("Invalid use of 'rainWaterCollector', Fill type 'WATER' is missing from the storage!")
        end
    end

    local animalLoadingTriggerNode = xmlFile:getValue(key .. ".animalInput#triggerNode", nil, components, i3dMappings)

    if animalLoadingTriggerNode ~= nil then
        local triggerValid = false
        local animalSystem = g_currentMission.animalSystem

        xmlFile:iterate(key .. ".animalInput.animal", function (_, animalTypeKey)
            local animalTypeName = xmlFile:getString(animalTypeKey .. "#type")
            local animalType = animalSystem:getTypeByName(animalTypeName)

            if animalType ~= nil then
                local fillTypeName = xmlFile:getString(animalTypeKey .. "#fillType")
                local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)

                if fillTypeIndex ~= nil and self.unloadingStation:getIsFillTypeSupported(fillTypeIndex) then
                    if self.animalsTypeData == nil then
                        self.animalsTypeData = {}

                        self.animalTypeToFillType = {}
                        self.fillTypeToAnimalType = {}

                        self.animalSubTypeToFillType = {}
                        self.fillTypeToAnimalSubType = {}
                    end

                    for _, subTypeIndex in ipairs (animalType.subTypes) do
                        self.animalSubTypeToFillType[subTypeIndex] = fillTypeIndex
                        self.fillTypeToAnimalSubType[fillTypeIndex] = subTypeIndex
                    end

                    self.maxNumAnimals = (self.maxNumAnimals or 0) + self:getCapacity(fillTypeIndex)

                    self.animalsTypeData[animalType.typeIndex] = {
                        minimumAge = math.clamp(xmlFile:getInt(animalTypeKey .. "#minimumAge", 0), 0, 60),
                        maximumAge = math.clamp(xmlFile:getInt(animalTypeKey .. "#maximumAge", 60), 1, 60),
                        maxNumAnimals = self:getCapacity(fillTypeIndex),
                        fillTypeIndex = fillTypeIndex
                    }

                    self.animalTypeToFillType[animalType.typeIndex] = fillTypeIndex
                    self.fillTypeToAnimalType[fillTypeIndex] = animalType.typeIndex

                    triggerValid = true
                else
                    Logging.xmlError(xmlFile, "Production point unloadingStation does not support fillType with name '%s' or fillType is invalid for 'animalInput' type '%s'.", fillTypeName, animalTypeName)
                end
            else
                Logging.xmlError(xmlFile, "Animal type '%s' invalid!", animalTypeName)
            end
        end)

        if triggerValid then
            local animalLoadingTrigger = AnimalLoadingTrigger.new(self.isServer, self.isClient)

            animalLoadingTrigger.husbandry = self
            animalLoadingTrigger.title = ""

            animalLoadingTrigger.isDealer = false
            animalLoadingTrigger.triggerNode = animalLoadingTriggerNode

            -- EXAMPLE L10N: "This animal is too young, a minimum age of %s will be accepted!"
            local animalMinimumAgeText = xmlFile:getString(key .. ".animalInput#animalMinimumAgeText")

            if animalMinimumAgeText ~= nil then
                animalLoadingTrigger.animalMinimumAgeText = g_i18n:getText(animalMinimumAgeText, customEnvironment)
            end

            -- EXAMPLE L10N: "This animal is too old, a maximum age of %s will be accepted!"
            local animalMaximumAgeText = xmlFile:getString(key .. ".animalInput#animalMaximumAgeText")

            if animalMaximumAgeText ~= nil then
                animalLoadingTrigger.animalMaximumAgeText = g_i18n:getText(animalMaximumAgeText, customEnvironment)
            end

            -- EXAMPLE L10N: "Do you want to move %d animals (%s) to the %s?"
            local unloadConfirmationText = xmlFile:getString(key .. ".animalInput#unloadConfirmationText")

            if unloadConfirmationText ~= nil then
                animalLoadingTrigger.unloadConfirmationText = g_i18n:getText(unloadConfirmationText, customEnvironment)
            end

            -- EXAMPLE L10N: "Animals were successfully moved to %s!"
            local unloadSuccessText = xmlFile:getString(key .. ".animalInput#unloadSuccessText")

            if unloadSuccessText ~= nil then
                animalLoadingTrigger.unloadSuccessText = g_i18n:getText(unloadSuccessText, customEnvironment)
            end

            -- EXAMPLE L10N: "Move to %s"
            local moveButtonText = xmlFile:getString(key .. ".animalInput#moveButtonText")

            if moveButtonText ~= nil then
                animalLoadingTrigger.moveButtonText = g_i18n:getText(moveButtonText, customEnvironment)
            end

            animalLoadingTrigger.openAnimalMenu = function (loadingTrigger)
                if loadingTrigger.husbandry == nil then
                    loadingTrigger:updateActivatableObject()
                end

                local animalScreen = g_animalScreen
                local animalScreenController = AnimalScreenTrailerExtendedProduction.new(loadingTrigger.husbandry, loadingTrigger.loadingVehicle)

                if loadingTrigger.husbandry.setAnimalScreenController ~= nil then
                    loadingTrigger.husbandry:setAnimalScreenController(animalScreenController)
                end

                animalScreenController.husbandryName = loadingTrigger.husbandry.name or loadingTrigger.husbandry.owningPlaceable:getName()
                animalScreenController.moveButtonText = loadingTrigger.moveButtonText
                animalScreenController.unloadConfirmationText = loadingTrigger.unloadConfirmationText
                animalScreenController.unloadSuccessText = loadingTrigger.unloadSuccessText
                animalScreenController.animalMinimumAgeText = loadingTrigger.animalMinimumAgeText
                animalScreenController.animalMaximumAgeText = loadingTrigger.animalMaximumAgeText

                animalScreenController:init()

                animalScreen.isDealer = false
                animalScreen.controller = animalScreenController

                animalScreenController:setAnimalsChangedCallback(animalScreen.onAnimalsChanged, animalScreen)
                animalScreenController:setActionTypeCallback(animalScreen.onActionTypeChanged, animalScreen)
                animalScreenController:setSourceActionFinishedCallback(animalScreen.onSourceActionFinished, animalScreen)
                animalScreenController:setTargetActionFinishedCallback(animalScreen.onTargetActionFinished, animalScreen)
                animalScreenController:setErrorCallback(animalScreen.onError, animalScreen)

                animalScreen.sourceList:reloadData(true)
                g_gui:showGui("AnimalScreen")

                loadingTrigger.activatedTarget = loadingTrigger.loadingVehicle
            end

            animalLoadingTrigger.activatable.getIsActivatable = function (activatable)
                local owner = activatable.owner or animalLoadingTrigger

                if owner.isEnabled and g_gui.currentGui == nil and owner.loadingVehicle ~= nil and owner.loadingVehicle:getNumOfAnimals() > 0 then
                    if owner.isPlayerInRange or owner.loadingVehicle.rootVehicle == g_localPlayer:getCurrentVehicle() then
                        if self.owningPlaceable:getOwnerFarmId() == g_currentMission:getFarmId() then
                            return g_currentMission:getHasPlayerPermission("tradeAnimals")
                        end
                    end
                end

                return false
            end

            self.animalLoadingTrigger = animalLoadingTrigger
            self.clusterSystem = AnimalClusterSystem.new(self.isServer, self) -- Not used, just trying to avoid errors moving forward (i.e Updates, mod scripts etc)

            addTrigger(animalLoadingTrigger.triggerNode, "triggerCallback", animalLoadingTrigger)
            animalLoadingTrigger.isEnabled = true

            if self.isClient then
                local oldGetFillLevel = self.getFillLevel

                self.getFillLevel = function(factory, fillTypeIndex)
                    if not factory.updatingProduction then
                        if factory.fillTypeToAnimalType ~= nil and factory.fillTypeToAnimalType[fillTypeIndex] then
                            return math.ceil(oldGetFillLevel(factory, fillTypeIndex) or 0) + 0.000001 -- Increase above 1 so that a single animal is displayed in the infoHud as it only shows values > 1 not >= 1
                        end
                    end

                    return oldGetFillLevel(factory, fillTypeIndex)
                end

                local oldUpdateProduction = self.updateProduction

                self.updateProduction = function(factory, ...)
                    factory.updatingProduction = true
                    oldUpdateProduction(factory, ...)
                    factory.updatingProduction = false
                end
            end

            self.getClusterSystem = function(factory)
                return self.clusterSystem
            end

            self.getClusters = function(factory)
                return self.clusterSystem:getClusters()
            end

            self.getClusterById = function(factory, id)
                return nil
            end

            self.getAnimalTypeIndex = function(factory)
                return nil
            end

            self.getConditionInfos = function()
                return {}
            end

            self.getFoodInfos = function()
                return {}
            end

            self.getAnimalInfos = function()
                return {}
            end

            self.getAnimalDescription = function()
                return ""
            end

            self.setAnimalScreenController = function(_, controller)
                self.animalScreenController = controller
            end

            self.getMaxNumOfAnimals = function(factory)
                if self.animalScreenController ~= nil and self.animalScreenController.trailer ~= nil then
                    local animalType = self.animalScreenController.trailer:getCurrentAnimalType()

                    if animalType == nil then
                        return 0
                    end

                    local fillType = self.animalTypeToFillType[animalType.typeIndex]

                    if fillType ~= nil then
                        return self:getCapacity(fillType) or 0
                    end
                end

                return factory.maxNumAnimals
            end

            self.getNumOfAnimals = function(factory)
                if self.animalScreenController ~= nil and self.animalScreenController.trailer ~= nil then
                    local animalType = self.animalScreenController.trailer:getCurrentAnimalType()

                    if animalType == nil then
                        return 0
                    end

                    local fillType = self.animalTypeToFillType[animalType.typeIndex]

                    if fillType ~= nil then
                        return math.ceil(ProductionPoint.getFillLevel(factory, fillType) or 0)
                    end
                end

                local numAnimals = 0

                for _, fillType in pairs(factory.animalTypeToFillType) do
                    numAnimals = numAnimals + math.ceil(ProductionPoint.getFillLevel(factory, fillType) or 0)
                end

                return 0
            end

            self.getNumOfFreeAnimalSlots = function(factory, subTypeIndex)
                local fillType = factory.animalSubTypeToFillType[subTypeIndex]

                if fillType ~= nil then
                    return math.max((factory:getCapacity(fillType) or 0) - math.ceil(ProductionPoint.getFillLevel(factory, fillType) or 0), 0)
                end

                return 0
            end

            self.getSupportsAnimalSubType = function(factory, subTypeIndex)
                return factory.animalSubTypeToFillType[subTypeIndex] ~= nil
            end

            self.addCluster = function(factory, cluster)
                if factory.isServer and cluster ~= nil then
                    local fillType = factory.animalSubTypeToFillType[cluster.subTypeIndex]

                    if fillType ~= nil then
                        local movedAnimals = 0
                        local numAnimals = cluster.numAnimals
                        local unloadingStation = factory.unloadingStation

                        if unloadingStation ~= nil then
                            for _, targetStorage in pairs(unloadingStation.targetStorages) do
                                if unloadingStation:hasFarmAccessToStorage(factory.ownerFarmId, targetStorage) then
                                    if targetStorage:getFreeCapacity(fillType) > 0 then
                                        local oldTotalAnimals = targetStorage:getFillLevel(fillType)

                                        targetStorage:setFillLevel(oldTotalAnimals + numAnimals, fillType, nil)

                                        local newTotalAnimals = targetStorage:getFillLevel(fillType)

                                        movedAnimals = movedAnimals + newTotalAnimals - oldTotalAnimals
                                    end

                                    if movedAnimals >= numAnimals - 0.001 then
                                        movedAnimals = numAnimals

                                        break
                                    end
                                end
                            end

                            if movedAnimals > 0 then
                                cluster:changeNumAnimals(-movedAnimals)
                            end
                        end
                    end
                end
            end
        end
    end

    if hasExtendedFeatures then
        self.storage.setFillLevel = Utils.overwrittenFunction(self.storage.setFillLevel, function (storage, superFunc, fillLevel, fillType, fillInfo)
            local oldFillLevel = storage.fillLevels[fillType]

            superFunc(storage, fillLevel, fillType, fillInfo)

            if oldFillLevel ~= nil then
                self:updateExtendedFillLevelFeatures(fillType, storage.fillLevels[fillType], storage:getCapacity(fillType), oldFillLevel)
            end
        end)

        for fillType, fillLevel in pairs(self.storage.fillLevels) do
            self:updateExtendedFillLevelFeatures(fillType, fillLevel, self.storage:getCapacity(fillType), 0)
        end

        self.hasExtendedFeatures = true
    end

    -- Only requires update on load as this is just fill type title displays
    for fillType, extendedFeatures in pairs(self.extendedFeaturesByFillType) do
        if extendedFeatures.titleDisplays ~= nil then
            for _, display in ipairs(extendedFeatures.titleDisplays) do
                if display.func ~= nil then
                    display.func(_, _, fillType)
                end
            end
        end
    end

    return true
end

function ExtendedProductionPoint:loadDisplays(xmlFile, key, components, i3dMappings, fillTypeIndex, displaysType)
    local displays, titleDisplays

    xmlFile:iterate(key .. ".display", function (_, displayKey)
        local displayNode = xmlFile:getValue(displayKey .. "#node", nil, components, i3dMappings)

        if displayNode ~= nil then
            local fontName = xmlFile:getValue(displayKey .. "#font", "digit"):upper()
            local fontMaterial = g_materialManager:getFontMaterial(fontName, self.customEnvironment)

            if fontMaterial ~= nil then
                local display = {
                    fillLevelColourType = 0,
                    displayNode = displayNode,
                    fontMaterial = fontMaterial,
                    upperCase = xmlFile:getValue(displayKey .. "#upperCase", false)
                }

                local alignmentStr = xmlFile:getValue(displayKey .. "#alignment", "RIGHT")
                local alignment = RenderText["ALIGN_" .. alignmentStr:upper()] or RenderText.ALIGN_RIGHT

                local size = xmlFile:getValue(displayKey .. "#size", 0.03)
                local scaleX = xmlFile:getValue(displayKey .. "#scaleX", 1)
                local scaleY = xmlFile:getValue(displayKey .. "#scaleY", 1)
                local mask = xmlFile:getValue(displayKey .. "#mask", "0000000")
                local emissiveScale = xmlFile:getValue(displayKey .. "#emissiveScale", 0.2)
                local color = xmlFile:getValue(displayKey .. "#color", {0.9, 0.9, 0.9, 1}, true)
                local hiddenColor = xmlFile:getValue(displayKey .. "#hiddenColor", nil, true)

                if displaysType == "INPUT_OUTPUT" then
                    local fillLevelColourType = xmlFile:getValue(displayKey .. "#fillLevelColorType", "none"):upper()

                    if fillLevelColourType == "STANDARD" then
                        fillLevelColourType = 1
                    elseif fillLevelColourType == "INVERTED" then
                        fillLevelColourType = 2
                    else
                        fillLevelColourType = 0
                    end

                    -- Types: fillLevel | percent | capacity | title
                    local displayType = xmlFile:getValue(displayKey .. "#type", "fillLevel"):upper()

                    if displayType == "PERCENT" then
                        display.func = function(fillLevel, capacity)
                            local percent = capacity > 0 and (math.floor(fillLevel + 0.5) / capacity) or 0

                            if percent ~= display.lastValue then
                                local int, floatPart = math.modf(percent * 100)
                                local value = string.format(display.formatStr, int, math.abs(math.floor((floatPart + 1e-06) * 10 ^ display.formatPrecision)))

                                if display.fillLevelColourType == 0 then
                                    display.characterLine:setText(value)
                                else
                                    local textColor = display.characterLine.textColor

                                    if display.fillLevelColourType == 2 then
                                        textColor[1], textColor[2], textColor[3] = MathUtil.lerp3(0, 1, 0, 1, 0, 0, percent)
                                    else
                                        textColor[1], textColor[2], textColor[3] = MathUtil.lerp3(1, 0, 0, 0, 1, 0, percent)
                                    end

                                    if display.hiddenColor == nil then
                                        display.characterLine:setColor(textColor)
                                    end

                                    display.characterLine:setText(value)
                                end

                                display.lastValue = percent
                            end
                        end
                    elseif displayType == "CAPACITY" then
                        display.func = function(_, capacity)
                            if capacity ~= display.lastValue then
                                local int, floatPart = math.modf(capacity)
                                local value = string.format(display.formatStr, int, math.abs(math.floor((floatPart + 1e-06) * 10 ^ display.formatPrecision)))

                                display.lastValue = capacity
                                display.characterLine:setText(value)
                            end
                        end
                    elseif displayType == "TITLE" then
                        display.func = function(_, _, typeIndex)
                            if typeIndex ~= nil and typeIndex ~= display.lastValue then
                                local fillTypeTitle = g_fillTypeManager:getFillTypeTitleByIndex(typeIndex)

                                display.lastValue = typeIndex

                                if fillTypeTitle ~= nil then
                                    if not display.upperCase then
                                        display.characterLine:setText(fillTypeTitle)
                                    else
                                        display.characterLine:setText(string.upper(fillTypeTitle))
                                    end
                                end
                            end
                        end

                        if mask == "AUTO_MASK" then
                            local fillTypeTitle = g_fillTypeManager:getFillTypeTitleByIndex(fillTypeIndex)

                            if fillTypeTitle ~= nil then
                                mask = ""

                                for i = 1, #fillTypeTitle do
                                    mask = mask .. "0"
                                end
                            else
                                mask = "0000000000"
                            end
                        end
                    else
                        display.func = function(fillLevel, capacity)
                            if fillLevel ~= display.lastValue then
                                local int, floatPart = math.modf(fillLevel)
                                local value = string.format(display.formatStr, int, math.abs(math.floor((floatPart + 1e-06) * 10 ^ display.formatPrecision)))

                                if display.fillLevelColourType == 0 then
                                    display.characterLine:setText(value)
                                else
                                    local textColor = display.characterLine.textColor
                                    local alpha = capacity > 0 and (math.floor(fillLevel + 0.5) / capacity) or 0

                                    if display.fillLevelColourType == 2 then
                                        textColor[1], textColor[2], textColor[3] = MathUtil.lerp3(0, 1, 0, 1, 0, 0, alpha)
                                    else
                                        textColor[1], textColor[2], textColor[3] = MathUtil.lerp3(1, 0, 0, 0, 1, 0, alpha)
                                    end

                                    if display.hiddenColor == nil then
                                        display.characterLine:setColor(textColor)
                                    end

                                    display.characterLine:setText(value)
                                end

                                display.lastValue = fillLevel
                            end
                        end

                        displayType = "FILLEVEL"
                    end

                    -- if mask includes '|' then split and format so $l10n sections can be converted.
                    local maskSections = mask:split("|")

                    if #maskSections > 1 then
                        mask = ""

                        for i = 1, #maskSections do
                            local text = g_i18n:convertText(maskSections[i], self.customEnvironment)

                            if display.upperCase then
                                text = text:upper()
                            end

                            mask = mask .. " " .. text
                        end
                    end

                    display.type = displayType
                    display.hiddenColor = hiddenColor
                    display.fillLevelColourType = fillLevelColourType
                    display.formatStr, display.formatPrecision = Utils.maskToFormat(mask)

                    display.characterLine = CharacterLine.new(display.displayNode, fontMaterial, mask:len())
                    display.characterLine:setSizeAndScale(size, scaleX, scaleY)
                    display.characterLine:setTextAlignment(alignment)
                    display.characterLine:setColor(color, hiddenColor, emissiveScale)

                    if size >= 0.1 then
                        local characters = display.characterLine.characters

                        for i = 1, #characters do
                            setClipDistance(characters[i], 150)
                        end
                    end

                    if displayType ~= "TITLE" then
                        if displays == nil then
                            displays = {}
                        end

                        table.insert(displays, display)
                    else
                        if titleDisplays == nil then
                            titleDisplays = {}
                        end

                        table.insert(titleDisplays, display)
                    end
                else
                    display.func = function(name)
                        name = name or ""

                        if name ~= display.lastValue then
                            display.lastValue = name

                            if not display.upperCase then
                                display.characterLine:setText(tostring(name))
                            else
                                display.characterLine:setText(string.upper(tostring(name)))
                            end
                        end
                    end

                    if mask == "AUTO_MASK" then
                        if fillTypeIndex ~= nil then
                            mask = ""

                            for i = 1, #fillTypeIndex do
                                mask = mask .. "0"
                            end
                        else
                            mask = "0000000000"
                        end
                    end

                    display.characterLine = CharacterLine.new(display.displayNode, fontMaterial, mask:len())
                    display.characterLine:setSizeAndScale(size, scaleX, scaleY)
                    display.characterLine:setTextAlignment(alignment)
                    display.characterLine:setColor(color, hiddenColor, emissiveScale)

                    display.func(fillTypeIndex)

                    if displays == nil then
                        displays = {}
                    end

                    table.insert(displays, display)
                end
            end
        end
    end)

    return displays, titleDisplays
end

function ExtendedProductionPoint:loadFillMovers(xmlFile, key, components, i3dMappings)
    local fillMovers

    xmlFile:iterate(key .. ".fillMovers.fillMover", function (_, fillPlaneKey)
        local fillMover = FillPlane.new()

        if fillMover:load(components, xmlFile, fillPlaneKey, i3dMappings) then
            local scaleMinY = xmlFile:getValue(fillPlaneKey .. "#minScaleY")
            local scaleMaxY = xmlFile:getValue(fillPlaneKey .. "#maxScaleY")

            -- Include a 'scale Y axis' option :-)
            if fillMover.loaded and (scaleMinY ~= nil or scaleMaxY ~= nil) then
                local sx, sy, sz = getScale(fillMover.node)

                fillMover.scaleMinY = scaleMinY or sy
                fillMover.scaleMaxY = scaleMaxY or sy

                setScale(fillMover.node, sx, fillMover.scaleMinY, sz)

                fillMover.setState = Utils.overwrittenFunction(fillMover.setState, function(fillPlane, superFunc, state)
                    if fillMover.scaleMinY ~= nil then
                        local sx, sy, sz = getScale(fillPlane.node)

                        sy = MathUtil.lerp(fillPlane.scaleMinY, fillPlane.scaleMaxY, state)

                        setScale(fillPlane.node, sx, sy, sz)
                    end

                    return superFunc(fillPlane, state)
                end)
            end

            if fillMovers == nil then
                fillMovers = {}
            end

            table.insert(fillMovers, fillMover)
        else
            fillMover:delete()
        end
    end)

    return fillMovers
end

function ExtendedProductionPoint:loadDynamicFillPlanes(xmlFile, key, components, i3dMappings, fillTypeIndex)
    local dynamicFillPlanes

    xmlFile:iterate(key .. ".dynamicFillPlanes.dynamicFillPlane", function (_, dynamicFillPlaneKey)
        local node = xmlFile:getValue(dynamicFillPlaneKey .. "#node", nil, components, i3dMappings)

        if node ~= nil and fillTypeIndex ~= nil then
            local dynamicFillPlane = FillPlaneUtil.createFromXML(xmlFile, dynamicFillPlaneKey, node, self.storage:getCapacity(fillTypeIndex))

            if dynamicFillPlane ~= nil then
                FillPlaneUtil.assignDefaultMaterialsFromTerrain(dynamicFillPlane, g_terrainNode)
                FillPlaneUtil.setFillType(dynamicFillPlane, fillTypeIndex)

                if dynamicFillPlanes == nil then
                    dynamicFillPlanes = {}
                end

                table.insert(dynamicFillPlanes, dynamicFillPlane)
            end
        end
    end)

    return dynamicFillPlanes
end

function ExtendedProductionPoint:loadVisibilityNodeGroups(xmlFile, key, components, i3dMappings)
    local visibilityNodeGroups

    xmlFile:iterate(key .. ".visibilityNodeGroups.visibilityNodeGroup", function (_, groupKey)
        local rootNode = xmlFile:getValue(groupKey .. "#node", nil, components, i3dMappings)

        if rootNode ~= nil then
            local numChildren = getNumOfChildren(rootNode)

            if numChildren > 0 then
                local visibilityNodeGroup = {}

                for i = 0, numChildren - 1 do
                    local node = getChildAt(rootNode, i)

                    local visibilityNode = {
                        rigidBodyType = getRigidBodyType(node),
                        node = node
                    }

                    setVisibility(node, false)
                    setRigidBodyType(node, RigidBodyType.NONE)

                    -- If there is a child node that also has collision then it can be referenced with a 'userAttribute' in the I3D so it is also switched
                    local childId = getUserAttribute(node, "childCollision")

                    if childId ~= nil and tonumber(childId) ~= nil then
                        visibilityNode.childCollision = getChildAt(node, tonumber(childId))
                        setRigidBodyType(childCollision, RigidBodyType.NONE)
                    end

                    table.insert(visibilityNodeGroup, visibilityNode)
                end

                if visibilityNodeGroups == nil then
                    visibilityNodeGroups = {}
                end

                table.insert(visibilityNodeGroups, visibilityNodeGroup)
            end
        end
    end)

    return visibilityNodeGroups
end

function ExtendedProductionPoint:loadAnimatedVisibilityNodes(xmlFile, key, components, i3dMappings)
    local visibilityNodes

    xmlFile:iterate(key .. ".animatedVisibilityNodes.visibilityNode", function (_, visibilityNodeKey)
        local linkNode = xmlFile:getValue(visibilityNodeKey .. "#linkNode", nil, components, i3dMappings)

        local characterFilename = xmlFile:getValue(visibilityNodeKey .. "#characterFilename")
        local animationFilename = xmlFile:getValue(visibilityNodeKey .. "#animationFilename")

        local clipNames = xmlFile:getValue(visibilityNodeKey .. "#clipNames")

        if linkNode ~= nil and characterFilename ~= nil and clipNames ~= nil then
            characterFilename = Utils.getFilename(characterFilename, self.baseDirectory)

            local rootNode, characterSharedLoadRequestId = g_i3DManager:loadSharedI3DFile(characterFilename, false, false)

            if rootNode ~= 0 and rootNode ~= nil then
                local clipTrack = xmlFile:getValue(visibilityNodeKey .. "#clipTrack", 0)
                local skeleton = xmlFile:getValue(visibilityNodeKey .. "#skeletonNode", "0", rootNode)

                if self.sharedAnimatedLoadRequestIds == nil then
                    self.sharedAnimatedLoadRequestIds = {}
                end

                table.insert(self.sharedAnimatedLoadRequestIds, characterSharedLoadRequestId)

                link(linkNode, rootNode)
                clipNames = clipNames:split(" ")

                if animationFilename ~= nil then
                    animationFilename = Utils.getFilename(animationFilename, self.baseDirectory)

                    local i3dNode, animationSharedLoadRequestId = g_i3DManager:loadSharedI3DFile(animationFilename, false, false)

                    if i3dNode ~= 0 and i3dNode ~= nil then
                        cloneAnimCharacterSet(getChildAt(i3dNode, 0), getParent(skeleton))

                        table.insert(self.sharedAnimatedLoadRequestIds, animationSharedLoadRequestId)

                        delete(i3dNode)
                    end
                end

                local clipIndexs = {}
                local characterSet = getAnimCharacterSet(skeleton)

                for _, clipName in pairs (clipNames) do
                    local clipIndex = getAnimClipIndex(characterSet, clipName)

                    if clipIndex >= 0 then
                        table.insert(clipIndexs, clipIndex)
                    else
                        Logging.error("Animation clip with name '%s' does not exist in '%s'", clipName, animationFilename or characterFilename or "XML file")
                    end
                end

                local clipIndex = clipIndexs[1]

                if clipIndex ~= nil then
                    local numClipIndexs = #clipIndexs

                    if numClipIndexs > 1 then
                        clipIndex = clipIndexs[math.random(1, numClipIndexs)]
                    end

                    assignAnimTrackClip(characterSet, clipTrack, clipIndex)

                    setAnimTrackLoopState(characterSet, clipTrack, true)
                    setAnimTrackSpeedScale(characterSet, clipTrack, 1)

                    if xmlFile:getValue(visibilityNodeKey .. "#randomStart", true) then
                        setAnimTrackTime(characterSet, clipTrack, math.random(0, getAnimClipDuration(characterSet, clipIndex)), true)
                    end

                    local meshNode = xmlFile:getValue(visibilityNodeKey .. "#meshNode", nil, rootNode, nil)

                    if meshNode ~= nil then
                        local tileU = xmlFile:getValue(visibilityNodeKey .. "#tileU")
                        local tileV = xmlFile:getValue(visibilityNodeKey .. "#tileV")

                        if tileU ~= nil and tileV ~= nil then
                            local numTilesU = math.max(xmlFile:getValue(visibilityNodeKey .. "#numTilesU", 2), 1)
                            local numTilesV = math.max(xmlFile:getValue(visibilityNodeKey .. "#numTilesV", 2), 1)

                            I3DUtil.setShaderParameterRec(meshNode, "atlasInvSizeAndOffsetUV", 1 / numTilesU, 1 / numTilesV, tileU / numTilesU, tileV / numTilesV)
                            I3DUtil.setShaderParameterRec(meshNode, "atlasInvSizeAndOffsetUV", nil, nil, tileU / numTilesU, tileV / numTilesV, false)
                        end

                        local dirtFactor = math.clamp(xmlFile:getValue(visibilityNodeKey .. "#dirtFactor", 0), 0, 1)
                        I3DUtil.setShaderParameterRec(meshNode, "dirt", dirtFactor, nil, nil, nil)
                    end

                    if visibilityNodes == nil then
                        visibilityNodes = {}
                    end

                    table.insert(visibilityNodes, {
                        characterSet = characterSet,
                        numClipIndexs = numClipIndexs,
                        clipTrack = clipTrack,
                        clipIndexs = clipIndexs,
                        skeleton = skeleton,
                        node = linkNode
                    })
                end
            end
        end
    end)

    return visibilityNodes
end

function ExtendedProductionPoint:findStorageExtensions()
    -- Extensions on factories is buggy so removed until Giants fixes the many issues not allowing updates on add / remove.
    -- For example the silo on the base French map is listed as extension and when removed does not update the factory if it was added.
    -- If I get time I will fix but not needed anyway as a magic silo to allow more lettuce for example is a little dumb :-)

    self.storage.isExtension = false

    if self.unloadingStation ~= nil then
        self.unloadingStation.supportsExtension = false
    end

    if self.loadingStation ~= nil then
        self.loadingStation.supportsExtension = false
    end
end

function ExtendedProductionPoint:delete()
    if self.isClient then
        for _, production in ipairs (self.productions) do
            if production.extendedFeaturesSamples ~= nil then
                local samples = production.extendedFeaturesSamples

                g_soundManager:deleteSample(samples.start)
                g_soundManager:deleteSample(samples.stop)
                g_soundManager:deleteSample(samples.work)
            end
        end
    end

    if self.animalLoadingTrigger ~= nil then
        self.animalLoadingTrigger:delete()
        self.animalLoadingTrigger = nil

        if self.clusterSystem ~= nil and self.clusterSystem.delete ~= nil then
            self.clusterSystem:delete()
        end
    end

    if self.sharedAnimatedLoadRequestIds ~= nil then
        for _, sharedLoadRequestId in ipairs (self.sharedAnimatedLoadRequestIds) do
            g_i3DManager:releaseSharedI3DFile(sharedLoadRequestId)
        end

        self.sharedAnimatedLoadRequestIds = nil
    end

    if self.extendedActivatable ~= nil then
        g_currentMission.activatableObjectsSystem:removeActivatable(self.extendedActivatable)

        self.extendedActivatable = nil
    end

    if self.extendedFeaturesInteractionTriggers ~= nil then
        for triggerId, _ in pairs (self.extendedFeaturesInteractionTriggers) do
            removeTrigger(triggerId)
        end

        self.extendedFeaturesInteractionTriggers = nil
    end

    ExtendedProductionPoint:superClass().delete(self)
end

function ExtendedProductionPoint:updateRainWaterCollector(lastRainScale)
    self.rainWaterCollected = self.rainWaterCollected + (self.rainWaterPerMinute * lastRainScale)

    if self.rainWaterCollected >= self.rainWaterThreshold then
        local freeCapacity = self.storage:getFreeCapacity(FillType.WATER)

        if freeCapacity > 0 then
            local fillLevel = self.storage:getFillLevel(FillType.WATER)

            self.storage:setFillLevel(fillLevel + self.rainWaterCollected, FillType.WATER)
            self.rainWaterCollected = 0
        end
    end
end

function ExtendedProductionPoint:updateExtendedFillLevelFeatures(fillType, fillLevel, capacity, oldFillLevel)
    if self.isClient then
        local extendedFeatures = self.extendedFeaturesByFillType[fillType]

        if extendedFeatures ~= nil then
            fillLevel = fillLevel or 0
            capacity = capacity or 0

            if self.fillTypeToAnimalType ~= nil and self.fillTypeToAnimalType[fillType] then
                fillLevel = math.ceil(fillLevel)
            end

            if extendedFeatures.displays ~= nil then
                for _, display in ipairs(extendedFeatures.displays) do
                    if display.func ~= nil then
                        display.func(fillLevel, capacity, fillType)
                    end
                end
            end

            if extendedFeatures.fillMovers ~= nil then
                local factor = capacity > 0 and fillLevel / capacity or 0

                for _, fillMover in ipairs(extendedFeatures.fillMovers) do
                    fillMover:setState(factor)
                end
            end

            if extendedFeatures.dynamicFillPlanes ~= nil then
                local delta = fillLevel - (oldFillLevel or 0)

                for _, dynamicFillPlane in ipairs(extendedFeatures.dynamicFillPlanes) do
                    local refNode = dynamicFillPlane
                    local width, length = 1, 1

                    if fillInfo ~= nil then
                        refNode = fillInfo.node
                        length = fillInfo.length
                        width = fillInfo.width
                    end

                    local x, y, z = localToWorld(refNode, 0, 0, 0)
                    local d1x, d1y, d1z = localDirectionToWorld(refNode, width, 0, 0)
                    local d2x, d2y, d2z = localDirectionToWorld(refNode, 0, 0, length)
                    local steps = math.clamp(math.floor(delta / 400), 1, 25)

                    for _ = 1, steps do
                        fillPlaneAdd(dynamicFillPlane, delta / steps, x, y, z, d1x, d1y, d1z, d2x, d2y, d2z)
                    end
                end
            end

            if extendedFeatures.visibilityNodeGroups ~= nil and capacity > 0 then
                for _, visibilityNodes in ipairs (extendedFeatures.visibilityNodeGroups) do
                    local numVisibilityNodes = #visibilityNodes
                    local visibleNodes = math.ceil((numVisibilityNodes * fillLevel) / capacity)

                    for i = 1, numVisibilityNodes do
                        local visibilityNode = visibilityNodes[i]
                        local active = i <= visibleNodes

                        if active ~= visibilityNode.active then
                            visibilityNode.active = active

                            local rigidBodyType = RigidBodyType.NONE

                            if active then
                                rigidBodyType = visibilityNode.rigidBodyType
                            end

                            setVisibility(visibilityNode.node, active)
                            setRigidBodyType(visibilityNode.node, rigidBodyType)

                            if visibilityNode.childCollision ~= nil then
                                setVisibility(visibilityNode.childCollision, active)
                                setRigidBodyType(visibilityNode.childCollision, rigidBodyType)
                            end
                        end
                    end
                end
            end

            if extendedFeatures.animatedVisibilityNodes ~= nil and capacity > 0 then
                local visibilityNodes = extendedFeatures.animatedVisibilityNodes
                local numVisibilityNodes = #visibilityNodes
                local visibleNodes = math.ceil((numVisibilityNodes * fillLevel) / capacity)

                for i = 1, numVisibilityNodes do
                    local visibilityNode = visibilityNodes[i]
                    local active = i <= visibleNodes

                    if active ~= visibilityNode.active then
                        visibilityNode.active = active

                        if active then
                            if visibilityNode.characterSet ~= nil then
                                if visibilityNode.numClipIndexs > 1 then
                                    local clipIndex = visibilityNode.clipIndexs[math.random(1, visibilityNode.numClipIndexs)]

                                    assignAnimTrackClip(visibilityNode.characterSet, visibilityNode.clipTrack, clipIndex)
                                end

                                enableAnimTrack(visibilityNode.characterSet, visibilityNode.clipTrack)
                            end

                            setVisibility(visibilityNode.node, true)
                        else
                            setVisibility(visibilityNode.node, false)

                            if visibilityNode.characterSet then
                                disableAnimTrack(visibilityNode.characterSet, visibilityNode.clipTrack)
                            end
                        end
                    end
                end
            end
        end
    end
end

function ExtendedProductionPoint:setProductionState(productionId, state, noEventSend)
    local production = self.productionsIdToObj[productionId]

    if production ~= nil then
        if not self.extendedFeaturesAlwaysActive then
            if state and self.isOwned and production.extendedFeaturesAutoOff then
                local numProductionPoints = 1
                local productionChainManager = g_currentMission.productionChainManager

                if productionChainManager ~= nil and productionChainManager.productionPoints ~= nil then
                    numProductionPoints = math.max(#productionChainManager.productionPoints, 1)
                end

                local updateInterval = math.clamp(g_currentDt * numProductionPoints, 0, 30000)
                local timeAdjustment = g_currentMission.environment.timeAdjustment

                local factor = production.cyclesPerMinute * (updateInterval / 60000 * timeAdjustment)

                for _, input in ipairs (production.inputs) do
                    local fillLevel = self:getFillLevel(input.type)
                    local amount = input.amount * factor

                    if fillLevel < amount then
                        if production.extendedFeaturesShowAutoOffLitres then
                            local title = g_fillTypeManager:getFillTypeTitleByIndex(input.type)
                            local required = g_i18n:formatVolume(math.ceil(amount - fillLevel), 0)

                            return string.format("%s\n\n%s: %s", g_i18n:getText("ui_production_status_materialsMissing"), title, required)
                        end

                        return g_i18n:getText("ui_production_status_materialsMissing")
                    end
                end

                factor = production.cyclesPerMinute * (updateInterval * self.minuteFactorTimescaled * timeAdjustment)

                for _, output in ipairs (production.outputs) do
                    local amount = output.amount * factor

                    if not output.sellDirectly and self.storage:getFreeCapacity(output.type) < amount then
                        if production.extendedFeaturesShowAutoOffLitres then
                            local title = g_fillTypeManager:getFillTypeTitleByIndex(output.type)
                            local required = g_i18n:formatVolume(math.ceil(amount), 0)

                            return string.format("%s\n\n%s: %s", g_i18n:getText("ui_production_status_outOfSpace"), title, required)
                        end

                        return g_i18n:getText("ui_production_status_outOfSpace")
                    end
                end
            end
        else
            state = true

            if self.extendedFeaturesActiveSeasons ~= nil then
                local currentSeason = g_currentMission.environment.currentSeason

                if currentSeason ~= nil and self.extendedFeaturesActiveSeasons[currentSeason] == nil then
                    state = false
                end
            end

            if state and self.extendedFeaturesOpeningHours ~= nil then
                local currentHour = g_currentMission.environment.currentHour

                if currentHour ~= nil and MathUtil.getIsOutOfBounds(currentHour, self.extendedFeaturesOpeningHours.startTime, self.extendedFeaturesOpeningHours.endTime - 1) then
                    state = false
                end
            end
        end

        ExtendedProductionPoint:superClass().setProductionState(self, productionId, state, noEventSend)

        if self.isClient then
            local samples = production.extendedFeaturesSamples

            if samples ~= nil then
                if state then
                    g_soundManager:stopSample(samples.start)
                    g_soundManager:stopSample(samples.work)
                    g_soundManager:stopSample(samples.stop)
                    g_soundManager:playSample(samples.start)
                    g_soundManager:playSample(samples.work, 0, samples.start)
                else
                    g_soundManager:stopSample(samples.start)
                    g_soundManager:stopSample(samples.work)
                    g_soundManager:stopSample(samples.stop)
                    g_soundManager:playSample(samples.stop)
                end
            end

            ObjectChangeUtil.setObjectChanges(production.extendedFeaturesObjectChanges, state)
        end
    else
        ExtendedProductionPoint:superClass().setProductionState(self, productionId, state, noEventSend)
    end
end

function ExtendedProductionPoint:setOutputDistributionMode(outputFillTypeId, mode, noEventSend)
    ExtendedProductionPoint:superClass().setOutputDistributionMode(self, outputFillTypeId, mode, noEventSend)

    if self.isClient and self.distributionObjectChanges[outputFillTypeId] ~= nil then
        for _, distributionModes in pairs (self.distributionObjectChanges) do
            for _, objects in pairs (distributionModes) do
                ObjectChangeUtil.setObjectChanges(objects, false)
            end
        end

        ObjectChangeUtil.setObjectChanges(self.distributionObjectChanges[outputFillTypeId][mode + 1], true)
    end
end

function ExtendedProductionPoint:setProductionStatus(productionId, status, noEventSend)
    if self.isServer and self.isOwned and not self.extendedFeaturesAlwaysActive then
        local production = self.productionsIdToObj[productionId]

        if production ~= nil and production.extendedFeaturesAutoOff then
            status = tonumber(status or ProductionPoint.PROD_STATUS.INACTIVE)

            if ExtendedProductionPoint.AUTO_OFF_PROD_STATUS[status] and table.hasElement(self.activeProductions, production) then
                self:setProductionState(productionId, false)

                production.status = status
                ProductionPointProductionStatusEvent.sendEvent(self, productionId, status, noEventSend)

                return
            end
        end
    end

    ExtendedProductionPoint:superClass().setProductionStatus(self, productionId, status, noEventSend)
end

function ExtendedProductionPoint:setOwnerFarmId(farmId, noEventSend)
    ExtendedProductionPoint:superClass().setOwnerFarmId(self, farmId, noEventSend)

    if self.isOwned and self.extendedFeaturesAlwaysActive then
        for _, production in pairs(self.productions) do
            self:setProductionState(production.id, true)
        end
    end
end

function ExtendedProductionPoint:updateInfo(infoTable)
    ExtendedProductionPoint:superClass().updateInfo(self, infoTable)

    local addOpeningHours = self.extendedFeaturesOpeningHours ~= nil

    if self.extendedFeaturesActiveSeasons ~= nil and self.extendedFeaturesInfoTables.seasons ~= nil then
        local currentSeason = g_currentMission.environment.currentSeason

        if currentSeason ~= nil and self.extendedFeaturesActiveSeasons[currentSeason] == nil then
            local seasonInfoTable = self.extendedFeaturesInfoTables.seasons[currentSeason]

            if seasonInfoTable ~= nil then
                table.insert(infoTable, self.extendedFeaturesInfoTables.details)
                table.insert(infoTable, seasonInfoTable)

                addOpeningHours = false
            end
        end
    end

    if addOpeningHours and self.extendedFeaturesInfoTables.openingHours ~= nil then
        table.insert(infoTable, self.extendedFeaturesInfoTables.details)
        table.insert(infoTable, self.extendedFeaturesInfoTables.openingHours)
    end
end

function ExtendedProductionPoint:getName()
    local name = ExtendedProductionPoint:superClass().getName(self)

    if self.extendedFeaturesOpeningHours ~= nil and self.extendedFeaturesOpeningHours.addHoursToName then
        if self.animalLoadingTrigger == nil or g_animalScreen == nil or not g_animalScreen.isOpen then
            return string.format("%s (%02d:00 - %02d:00)", name, self.extendedFeaturesOpeningHours.startTime, self.extendedFeaturesOpeningHours.endTime)
        end
    end

    return name
end

function ExtendedProductionPoint:onHourChanged(currentHour)
    if self.isServer and self.extendedFeaturesOpeningHours ~= nil and currentHour ~= nil then
        local currentSeason = g_currentMission.environment.currentSeason

        if (self.extendedFeaturesActiveSeasons == nil or currentSeason == nil) or self.extendedFeaturesActiveSeasons[currentSeason] ~= nil then
            if not MathUtil.getIsOutOfBounds(currentHour, self.extendedFeaturesOpeningHours.startTime, self.extendedFeaturesOpeningHours.endTime - 1) then
                for _, production in pairs(self.productions) do
                    if not self:getIsProductionEnabled(production.id) then
                        self:setProductionState(production.id, true)
                    end
                end
            else
                for _, production in pairs(self.productions) do
                    if self:getIsProductionEnabled(production.id) then
                        self:setProductionState(production.id, false)
                    end
                end
            end
        else
            for _, production in pairs(self.productions) do
                if self:getIsProductionEnabled(production.id) then
                    self:setProductionState(production.id, false)
                end
            end
        end
    end
end

function ExtendedProductionPoint:onPeriodChanged(currentPeriod)
    if self.isServer and self.extendedFeaturesActiveSeasons ~= nil then
        local currentSeason = g_currentMission.environment.currentSeason

        if currentSeason ~= nil then
            if self.extendedFeaturesActiveSeasons[currentSeason] ~= nil then
                for _, production in pairs(self.productions) do
                    if not self:getIsProductionEnabled(production.id) then
                        self:setProductionState(production.id, true)
                    end
                end
            else
                for _, production in pairs(self.productions) do
                    if self:getIsProductionEnabled(production.id) then
                        self:setProductionState(production.id, false)
                    end
                end
            end
        end
    end
end

function ExtendedProductionPoint:productionInteractionTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if (onEnter or onLeave) and self.isOwned and self.extendedActivatable ~= nil then
        if g_localPlayer and g_localPlayer.rootNode == otherId then
            if onEnter then
                local production = self.extendedFeaturesInteractionTriggers[triggerId]
                local menuAction = self.extendedFeaturesMenuAction[triggerId]

                if self.extendedActivatable:setProduction(production, triggerId, menuAction) then
                    g_currentMission.activatableObjectsSystem:addActivatable(self.extendedActivatable)
                end
            else
                g_currentMission.activatableObjectsSystem:removeActivatable(self.extendedActivatable)
            end
        end
    end
end

----------------------------------------
-- ExtendedProductionPointActivatable --
----------------------------------------

ExtendedProductionPointActivatable = {}

local ExtendedProductionPointActivatable_mt = Class(ExtendedProductionPointActivatable)

function ExtendedProductionPointActivatable.new(productionPoint)
    local self = setmetatable({}, ExtendedProductionPointActivatable_mt)

    self.productionPoint = productionPoint

    self.production = nil
    self.triggerNode = nil
    self.menuAction = nil

    self.activateText = "Toggle"
    self.actionEventProductionState = nil
    self.actionEventProductionMenu = nil

    return self
end

function ExtendedProductionPointActivatable:setProduction(production, triggerNode, menuAction)
    if production == nil or (self.productionPoint.extendedFeaturesAlwaysActive and menuAction == nil) then
        return false
    end

    self.production = production

    self.triggerNode = triggerNode
    self.menuAction = menuAction

    return true
end

function ExtendedProductionPointActivatable:registerCustomInput(inputContext)
    if self.production ~= nil then
        if not self.productionPoint.extendedFeaturesAlwaysActive then
            local _, actionEventId = g_inputBinding:registerActionEvent(InputAction.ACTIVATE_OBJECT, self, self.onInputProductionState, false, true, false, true)

            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_HIGH)
            g_inputBinding:setActionEventTextVisibility(actionEventId, true)

            self.actionEventProductionState = actionEventId
        end

        if self.menuAction ~= nil then
            local valid, actionEventId, collidingAction = g_inputBinding:registerActionEvent(InputAction[self.menuAction], self, self.onInputProductionMenu, false, true, false, true)

            g_inputBinding:setActionEventText(actionEventId, g_i18n:getText("action_manageProductionPoint"))
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_HIGH)
            g_inputBinding:setActionEventTextVisibility(actionEventId, true)

            self.actionEventProductionMenu = actionEventId
        end

        self:updateActionEventTexts()
    end
end

function ExtendedProductionPointActivatable:removeCustomInput(inputContext)
    g_inputBinding:removeActionEventsByTarget(self)

    self.actionEventProductionState = nil
    self.actionEventProductionMenu = nil
end

function ExtendedProductionPointActivatable:updateActionEventTexts()
    if self.production ~= nil then
        local state = self.productionPoint:getIsProductionEnabled(self.production.id)

        if state then
            self.activateText = string.format(g_i18n:getText("action_turnOffOBJECT"), self.production.name or "")
        else
            self.activateText = string.format(g_i18n:getText("action_turnOnOBJECT"), self.production.name or "")
        end

        if self.actionEventProductionState ~= nil then
            g_inputBinding:setActionEventText(self.actionEventProductionState, self.activateText)
        end
    else
        g_currentMission.activatableObjectsSystem:removeActivatable(self)
    end
end

function ExtendedProductionPointActivatable:onInputProductionState()
    self:run()
end

function ExtendedProductionPointActivatable:onInputProductionMenu()
    self:updateActionEventTexts()
    self.productionPoint:openMenu()
end

function ExtendedProductionPointActivatable:getIsActivatable()
    return self.productionPoint.isOwned and g_currentMission.accessHandler:canFarmAccess(g_currentMission:getFarmId(), self.productionPoint)
end

function ExtendedProductionPointActivatable:getDistance(x, y, z)
    if self.triggerNode ~= nil then
        local tx, ty, tz = getWorldTranslation(self.triggerNode)

        return MathUtil.vector3Length(x - tx, y - ty, z - tz)
    end

    return math.huge
end

function ExtendedProductionPointActivatable:deactivate()
    self.production = nil
    self.triggerNode = nil
    self.menuAction = nil
    self.activateText = "Toggle"
end

function ExtendedProductionPointActivatable:run()
    if self.production ~= nil then
        local state = self.productionPoint:getIsProductionEnabled(self.production.id)
        local message = self.productionPoint:setProductionState(self.production.id, not state)

        if message ~= nil and self.production.name ~= nil then
            g_currentMission:showBlinkingWarning(string.format("%s: %s", self.production.name, message), 2000)
        end

        self:updateActionEventTexts()
    else
        g_currentMission.activatableObjectsSystem:removeActivatable(self)
    end
end

-------------------------------------------
-- AnimalScreenTrailerExtendedProduction --
-------------------------------------------

AnimalScreenTrailerExtendedProduction = {}

local AnimalScreenTrailerExtendedProduction_mt = Class(AnimalScreenTrailerExtendedProduction, AnimalScreenTrailerFarm)

function AnimalScreenTrailerExtendedProduction.new(productionPoint, trailer)
    return AnimalScreenTrailerFarm.new(productionPoint, trailer, AnimalScreenTrailerExtendedProduction_mt)
end

function AnimalScreenTrailerExtendedProduction:reset()
    if self.husbandry ~= nil and self.husbandry.setAnimalScreenController ~= nil then
        self.husbandry:setAnimalScreenController(nil)
    end

    AnimalScreenTrailerExtendedProduction:superClass().reset(self)
end

function AnimalScreenTrailerExtendedProduction:getSourceAnimalTypes()
    local animalType = self.trailer:getCurrentAnimalType()

    if animalType ~= nil then
        return {g_currentMission.animalSystem:getTypeByIndex(animalType.typeIndex)}
    end

    return {}
end

function AnimalScreenTrailerExtendedProduction:getTargetName()
    local clusters = self.trailer:getClusters()

    if #clusters > 0 and self.husbandry ~= nil then
        local subTypeIndex = clusters[1]:getSubTypeIndex()
        local fillTypeIndex = self.husbandry.animalSubTypeToFillType[subTypeIndex]

        if fillTypeIndex ~= nil then
            local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
            local fillLevel = self.husbandry:getFillLevel(fillTypeIndex) or 0
            local capacity = self.husbandry:getCapacity(fillTypeIndex) or 0

            return string.format("%s (%d / %d)", fillType.title, fillLevel, capacity)
        end
    end

    return ""
end

function AnimalScreenTrailerExtendedProduction:getSourceData()
    return { self.husbandry }, g_i18n:getText("ui_husbandryInformation") -- This makes sure the production is shown so you can see fill levels. Even though it is the target
end

function AnimalScreenTrailerExtendedProduction:getSourceActionText()
    if self.moveButtonText ~= nil and self.husbandryName ~= nil then
        return string.format(self.moveButtonText, self.husbandryName)
    end

    return g_i18n:getText("action_tip")
end

function AnimalScreenTrailerExtendedProduction:getSourceMaxNumAnimals(animalTypeIndex, animalIndex)
    local sourceItems = self.sourceItems

    if sourceItems[animalTypeIndex] == nil then
        return 0
    end

    local item = sourceItems[animalTypeIndex][animalIndex]

    if item == nil or self.husbandry == nil then
        return 0
    end

    return math.min(self:getMaxNumAnimals(), item:getNumAnimals(), self.husbandry:getNumOfFreeAnimalSlots(item:getSubTypeIndex()))
end

function AnimalScreenTrailerExtendedProduction:getApplySourceConfirmationText(animalTypeIndex, animalIndex, numItems)
    if self.unloadConfirmationText == nil or self.husbandryName == nil then
        return AnimalScreenTrailerExtendedProduction:superClass().getApplySourceConfirmationText(self, animalTypeIndex, animalIndex, numItems)
    end

    local item = self.sourceItems[animalTypeIndex][animalIndex]
    local name = string.format("%s, %s", item:getTitle(), item:getName())

    return string.format(self.unloadConfirmationText, numItems, name, self.husbandryName)
end

function AnimalScreenTrailerExtendedProduction:onAnimalMovedToFarm(errorCode)
    if self.unloadSuccessText == nil or self.husbandryName == nil then
        return AnimalScreenTrailerExtendedProduction:superClass().onAnimalMovedToFarm(self, errorCode)
    end

    g_messageCenter:unsubscribe(AnimalMoveEvent, self)
    self.actionTypeCallback(AnimalScreenBase.ACTION_TYPE_NONE, nil)

    if errorCode == AnimalMoveEvent.MOVE_SUCCESS then
        self.sourceActionFinished(false, string.format(self.unloadSuccessText, self.husbandryName))
    else
        local mapping = AnimalScreenTrailerFarm.MOVE_TO_FARM_ERROR_CODE_MAPPING[errorCode]
        self.sourceActionFinished(mapping.isWarning, g_i18n:getText(mapping.text))
    end
end

function AnimalScreenTrailerExtendedProduction:applySource(animalTypeIndex, animalIndex, numItems)
    if self.husbandry ~= nil and self.husbandry.animalsTypeData ~= nil then
        local animalTypeData = self.husbandry.animalsTypeData[animalTypeIndex]

        if animalTypeData ~= nil then
            local minimumAge = animalTypeData.minimumAge or 0
            local maximumAge = animalTypeData.maximumAge or 60

            if minimumAge > 0 or maximumAge < 60 then
                local item = self.sourceItems[animalTypeIndex][animalIndex]

                if item ~= nil and item.cluster ~= nil then
                    if (item.cluster.age or minimumAge) < minimumAge then
                        if self.animalMinimumAgeText == nil then
                            self.errorCallback(string.format("%s\nMinimum %s: %s", g_i18n:getText("shop_messageAnimalTypeNotSupported"), g_i18n:getText("ui_age"), g_i18n:formatNumMonth(minimumAge)))
                        else
                            self.errorCallback(string.format(self.animalMinimumAgeText), minimumAge)
                        end

                        return false
                    elseif (item.cluster.age or maximumAge) > maximumAge then
                        if self.animalMaximumAgeText == nil then
                            self.errorCallback(string.format("%s\nMaximum %s: %s", g_i18n:getText("shop_messageAnimalTypeNotSupported"), g_i18n:getText("ui_age"), g_i18n:formatNumMonth(maximumAge)))
                        else
                            self.errorCallback(string.format(self.animalMaximumAgeText), maximumAge)
                        end

                        return false
                    end
                end
            end
        end
    end

    return AnimalScreenTrailerExtendedProduction:superClass().applySource(self, animalTypeIndex, animalIndex, numItems)
end
