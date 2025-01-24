--[[
Copyright (C) GtX (Andy), 2019

Author: GtX | Andy
Date: 21.09.2019
Revision: FS25-01

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

ExtendedLoadingStation = {}

local ExtendedLoadingStation_mt = Class(ExtendedLoadingStation, LoadingStation)
InitObjectClass(ExtendedLoadingStation, "ExtendedLoadingStation")

function ExtendedLoadingStation.registerXMLPaths(schema, basePath)
    LoadingStation.registerXMLPaths(schema, basePath)

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".loadTrigger(?).playerTrigger#node", "Player trigger node for external operation")
    schema:register(XMLValueType.BOOL, basePath .. ".loadTrigger(?).playerTrigger#externalActivation", "Start / Stop filling only possible by player in trigger")

    SoundManager.registerSampleXMLPaths(schema, basePath .. ".loadTrigger(?).sounds", "startLoading")
    SoundManager.registerSampleXMLPaths(schema, basePath .. ".loadTrigger(?).sounds", "stopLoading")

    ObjectChangeUtil.registerObjectChangeXMLPaths(schema, basePath .. ".loadTrigger(?)")
end

function ExtendedLoadingStation.new(isServer, isClient, customMt)
    local self = LoadingStation.new(isServer, isClient, customMt or ExtendedLoadingStation_mt)

    self.useOwnerForAccess = false

    self.aiSupportedFillTypes = {}
    self.supportedFillTypes = {}
    self.basicFillTypes = {}

    self.hasStoragePerFarm = false
    self.owningPlaceable = nil

    self.rootNodeName = ""
    self.stationName = nil

    self.supportsExtension = false
    self.storageRadius = 50

    return self
end

function ExtendedLoadingStation:load(components, xmlFile, key, customEnvironment, i3dMappings, rootNode)
    rootNode = xmlFile:getValue(key .. "#node", rootNode, components, i3dMappings)

    if rootNode == nil then
        Logging.xmlError(xmlFile, "Missing node at '%s'", key)

        return false
    end

    local stationName = xmlFile:getValue(key .. "#stationName")

    if stationName ~= nil then
        self.stationName = g_i18n:convertText(stationName, customEnvironment)
    end

    self.rootNode = rootNode
    self.rootNodeName = getName(rootNode)

    self.supportsExtension = xmlFile:getValue(key .. "#supportsExtension", self.supportsExtension)
    self.storageRadius = xmlFile:getValue(key .. "#storageRadius", self.storageRadius)

    local names = xmlFile:getValue(key .. "#fillTypes")

    if names ~= nil then
        local fillTypes = g_fillTypeManager:getFillTypesByNames(names, "Warning: [ExtendedLoadingStation] Failed to load invalid fillType '%s'.")

        for _, fillType in pairs(fillTypes) do
            self.basicFillTypes[fillType] = true
        end
    end

    names = xmlFile:getValue(key .. "#fillTypeCategories")

    if names ~= nil then
        local fillTypes = g_fillTypeManager:getFillTypesByCategoryNames(names, "Warning: [ExtendedLoadingStation] Failed to load invalid fillType category '%s'.")

        for _, fillType in pairs(fillTypes) do
            self.basicFillTypes[fillType] = true
        end
    end

    xmlFile:iterate(key .. ".loadTrigger", function (_, loadTriggerKey)
        local loadTrigger = ExtendedLoadTrigger.new(self.isServer, self.isClient)

        if loadTrigger:load(components, xmlFile, loadTriggerKey, i3dMappings, rootNode) then
            loadTrigger:setSource(self)
            loadTrigger:register(true)

            table.insert(self.loadTriggers, loadTrigger)
        else
            loadTrigger:delete()
        end
    end)

    self:updateSupportedFillTypes()

    return true
end

function ExtendedLoadingStation:hasFarmAccessToStorage(farmId, storage)
    -- Allow storage checks to be ignored instead check the owner farmId
    if self.useOwnerForAccess and self.owningPlaceable then
        return farmId == self.owningPlaceable:getOwnerFarmId()
    end

    return ExtendedLoadingStation:superClass().hasFarmAccessToStorage(self, farmId, storage)
end

-- Can be used separately if 'ExtendedLoadingStation' is not required, 'registerXMLPaths' is included for this reason

ExtendedLoadTrigger = {}

ExtendedLoadTrigger.MOD_NAME = g_currentModName
ExtendedLoadTrigger.MOD_DIRECTORY = g_currentModDirectory

local ExtendedLoadTrigger_mt = Class(ExtendedLoadTrigger, LoadTrigger)
InitObjectClass(ExtendedLoadTrigger, "ExtendedLoadTrigger")

function ExtendedLoadTrigger.registerXMLPaths(schema, basePath)
    LoadTrigger.registerXMLPaths(schema, basePath)

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".playerTrigger#node", "Player trigger node for external operation")

    SoundManager.registerSampleXMLPaths(schema, basePath .. ".loadTrigger(?).sounds", "startLoading")
    SoundManager.registerSampleXMLPaths(schema, basePath .. ".loadTrigger(?).sounds", "stopLoading")

    ObjectChangeUtil.registerObjectChangeXMLPaths(schema, basePath)
end

function ExtendedLoadTrigger.new(isServer, isClient, customMt)
    local self = LoadTrigger.new(isServer, isClient, customMt or ExtendedLoadTrigger_mt)

    self.playerCanInteract = false
    self.externalActivation = false

    self.interactionTrigger = nil

    return self
end

function ExtendedLoadTrigger:load(components, xmlFile, xmlNode, i3dMappings, rootNode)
    if not ExtendedLoadTrigger:superClass().load(self, components, xmlFile, xmlNode, i3dMappings, rootNode) then
        return false
    end

    self.interactionTrigger = xmlFile:getValue(xmlNode .. ".playerTrigger#node", nil, components, i3dMappings)

    if self.interactionTrigger ~= nil then
        if not CollisionFlag.getHasMaskFlagSet(self.interactionTrigger, CollisionFlag.PLAYER) then
            Logging.xmlWarning(xmlFile, "Player trigger '%s.playerTrigger' does not have Bit '%d' (CollisionFlag.PLAYER) set!", key, CollisionFlag.getBit(CollisionFlag.PLAYER))
        end

        self.externalActivation = xmlFile:getValue(xmlNode .. ".playerTrigger#externalActivation", false)

        addTrigger(self.interactionTrigger, "interactionTriggerCallback", self)
    end

    if self.isClient then
        self.objectChanges = {}
        self.i3dMappings = i3dMappings

        if self.samples == nil then
            self.samples = {}
        end

        self.samples.startLoading = g_soundManager:loadSampleFromXML(xmlFile, xmlNode .. ".sounds", "startLoading", ExtendedLoadTrigger.MOD_DIRECTORY, components, 1, AudioGroup.ENVIRONMENT, i3dMappings, nil)
        self.samples.stopLoading = g_soundManager:loadSampleFromXML(xmlFile, xmlNode .. ".sounds", "stopLoading", ExtendedLoadTrigger.MOD_DIRECTORY, components, 1,  AudioGroup.ENVIRONMENT, i3dMappings, nil)

        ObjectChangeUtil.loadObjectChangeFromXML(xmlFile, xmlNode, self.objectChanges, components, self)
        ObjectChangeUtil.setObjectChanges(self.objectChanges, false)

        if #self.objectChanges == 0 then
            self.objectChanges = nil
        end

        self.i3dMappings = nil -- Not needed anymore, only used for 'loadObjectChangeFromXML'
    end

    return true
end

function ExtendedLoadTrigger:delete()
    if self.interactionTrigger ~= nil then
        removeTrigger(self.interactionTrigger)

        self.playerCanInteract = false
        self.interactionTrigger = nil
    end

    ExtendedLoadTrigger:superClass().delete(self)
end

function ExtendedLoadTrigger:update(dt)
    ExtendedLoadTrigger:superClass().update(self, dt)

    if self.interactionTrigger ~= nil and self.playerCanInteract then
        if self.source ~= nil then
            -- if g_currentMission.controlPlayer and g_currentMission.accessHandler:canFarmAccess(g_currentMission:getFarmId(), self.source) then
            if (g_localPlayer and not g_localPlayer:getIsInVehicle()) and g_currentMission.accessHandler:canFarmAccess(g_currentMission:getFarmId(), self.source) then
                self:raiseActive()
            else
                self.playerCanInteract = false
            end
        else
            self.playerCanInteract = false
        end
    end
end

function ExtendedLoadTrigger:toggleLoading()
    if not self.isLoading then
        local fillLevels = self.source:getAllFillLevels(g_currentMission:getFarmId())

        local fillableObject = self.validFillableObject
        local fillUnitIndex = self.validFillableFillUnitIndex

        local firstFillType = nil
        local validFillLevels = {}
        local numFillTypes = 0

        for fillTypeIndex, fillLevel in pairs(fillLevels) do
            if self.fillTypes == nil or self.fillTypes[fillTypeIndex] then
                if fillableObject:getFillUnitAllowsFillType(fillUnitIndex, fillTypeIndex) then
                    validFillLevels[fillTypeIndex] = fillLevel

                    if firstFillType == nil then
                        firstFillType = fillTypeIndex
                    end

                    numFillTypes = numFillTypes + 1
                end
            end
        end

        if not self.autoStart and numFillTypes > 1 then
            local startAllowed = true
            local currentVehicle = g_localPlayer:getCurrentVehicle()

            if currentVehicle ~= nil and currentVehicle.getIsActiveForInput ~= nil then
                startAllowed = currentVehicle:getIsActiveForInput(true)
            end

            if startAllowed then
                local title = string.format("%s", self.source:getName())
                SiloDialog.show(self.onFillTypeSelection, self, title, validFillLevels, self.hasInfiniteCapacity)
            end
        else
            self:onFillTypeSelection(firstFillType)
        end
    else
        self:setIsLoading(false)
    end
end

function ExtendedLoadTrigger:startLoading(fillType, fillableObject, fillUnitIndex)
    if not self.isLoading then
        self:raiseActive()

        self.isLoading = true
        self.selectedFillType = fillType
        self.currentFillableObject = fillableObject
        self.fillUnitIndex = fillUnitIndex
        self.activatable:setText(self.stopFillText)

        if self.isClient then
            ObjectChangeUtil.setObjectChanges(self.objectChanges, true)

            if self.effects ~= nil then
                g_effectManager:setEffectTypeInfo(self.effects, self.selectedFillType)
                g_effectManager:startEffects(self.effects)
            end

            g_soundManager:stopSample(self.samples.stopLoading)
            g_soundManager:playSample(self.samples.startLoading)

            g_soundManager:playSample(self.samples.load)
            g_soundManager:playSample(self.samples.loading)

            if self.scroller ~= nil then
                setShaderParameter(self.scroller, self.scrollerShaderParameterName, self.scrollerSpeedX, self.scrollerSpeedY, 0, 0, false)
            end
        end
    end
end

function ExtendedLoadTrigger:stopLoading()
    if self.isLoading then
        self:raiseActive()

        self.isLoading = false
        self.selectedFillType = FillType.UNKNOWN
        self.activatable:setText(self.startFillText)

        if self.currentFillableObject.aiStoppedLoadingFromTrigger ~= nil then
            self.currentFillableObject:aiStoppedLoadingFromTrigger()
        end

        for _, fillableObject in pairs(self.fillableObjects) do
            local lastWasFilled = false

            if fillableObject.object == self.validFillableObject then
                lastWasFilled = fillableObject.fillUnitIndex == self.fillUnitIndex
            end

            fillableObject.lastWasFilled = lastWasFilled
        end

        if self.isClient then
            ObjectChangeUtil.setObjectChanges(self.objectChanges, false)

            if self.effects ~= nil then
                g_effectManager:stopEffects(self.effects)
            end

            g_soundManager:stopSample(self.samples.load)
            g_soundManager:stopSample(self.samples.loading)

            g_soundManager:stopSample(self.samples.startLoading)
            g_soundManager:playSample(self.samples.stopLoading)

            if self.scroller ~= nil then
                setShaderParameter(self.scroller, self.scrollerShaderParameterName, 0, 0, 0, 0, false)
            end
        end
    end
end

function ExtendedLoadTrigger:getAllowsActivation(fillableObject)
    if self.interactionTrigger ~= nil then
        if self.playerCanInteract then
            if self.source ~= nil and g_currentMission.accessHandler:canFarmAccess(g_currentMission:getFarmId(), self.source) then
                return true
            end
        elseif self.externalActivation then
            return false
        end
    end

    return ExtendedLoadTrigger:superClass().getAllowsActivation(self, fillableObject)
end

function ExtendedLoadTrigger:interactionTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if (onEnter or onLeave) and g_localPlayer and g_localPlayer.rootNode == otherId then
        if onEnter then
            self.playerCanInteract = self.source ~= nil
        else
            self.playerCanInteract = false
        end
    end
end
