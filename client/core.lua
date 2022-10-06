if (not config) then
    error('[criticalscripts.shop] cs-boombox configuration file has a syntax error, please resolve it otherwise the resource will not work.')
    return
end

local internalVersion = '1.0.1'

local inRangeUniqueIds = {}
local inRangeObjects = {}
local instances = {}
local syncableObjects = {}

local lastSpeakerUpdateAt = 0
local lastSyncUpdateAt = 0
local lastTimeSyncAt = 0
local duiUrl = nil
local resourceVersion = nil

local serverReady = false
local paramsReady = false
local uiEnabled = false
local uiAccessible = false
local nuiReady = false
local pendingDuiCreation = false
local debugDui = false

local minTriggerValRange = 75
local mainThreadMs = 250
local scanThreadMs = 1000
local coreUpdateMs = 200
local syncUpdateMs = 250
local timeSyncMs = 3000
local networkSessionWaitMs = 100
local browserWaitMs = 100

function ShowUi(uniqueId)
    if (not CanAccessUi()) then
        return
    end

    uiEnabled = uniqueId

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)

    SendNUIMessage({
        ['type'] = 'cs-boombox:show',
        ['uniqueId'] = uniqueId
    })

    TriggerEvent('cs-boombox:onControllerInterfaceOpen')
    TriggerServerEvent('cs-boombox:ui', uniqueId)

    CreateThread(function()
        while (uiEnabled) do
            DisablePlayerFiring(PlayerId())
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            Wait(0)
        end
    end)
end

function HideUi()
    uiEnabled = false

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        ['type'] = 'cs-boombox:hide'
    })

    TriggerEvent('cs-boombox:onControllerInterfaceClose')
end

function CanAccessUi()
    return uiAccessible and nuiReady and serverReady
end

local MediaManagerInstance = {}

MediaManagerInstance.__index = MediaManagerInstance

function MediaManagerInstance:sync(data, temp)
    if ((not self.managerReady) or self.syncing) then
        self.pendingSync = {
            ['data'] = data,
            ['temp'] = temp
        }
    elseif (self.browserHandle) then
        self.syncing = true
        self.pendingSync = nil

        SendDuiMessage(self.browserHandle, json.encode({
            ['type'] = 'cs-boombox:sync',
            ['uniqueId'] = self.uniqueId,
            ['playing'] = data.playing,
            ['stopped'] = data.stopped,
            ['time'] = data.time,
            ['duration'] = data.duration,
            ['volume'] = data.volume,
            ['url'] = data.url,

            ['temp'] = {
                ['force'] = temp.force or self.duiNewlyCreated,
                ['adjust'] = temp.adjust,
                ['seek'] = Ternary(temp.media, temp.media and temp.media.seek, false)
            }
        }))

        if (self.duiNewlyCreated) then
            self.duiNewlyCreated = false
        end
    end
end

function MediaManagerInstance:createDui()
    self.duiCreated = true
    self.duiNewlyCreated = true

    if (not self.recentlyCreated) then
        self:addSpeaker(config.models[self.model].speaker)
    else
        self.recentlyCreated = false
    end

    local creationId = self.duiCreationId

    while (pendingDuiCreation) do  
        Wait(500)
    end

    pendingDuiCreation = true

    CreateThread(function()
        while (not paramsReady) do
            Wait(browserWaitMs)
        end

        self.browserHandle = CreateDui(duiUrl .. '?v=' .. resourceVersion .. '+' .. internalVersion .. (debugDui and '&debug=1' or '') .. '#' .. GetCurrentResourceName() .. '|' .. self.uniqueId, 1280, 720)

        while ((not self.browserHandle) or (not IsDuiAvailable(self.browserHandle)) or (not nuiReady) or (not self.browserReady) or (not serverReady)) do
            if (self.destroyed or creationId ~= self.duiCreationId) then
                break
            end

            Wait(browserWaitMs)
        end

        if ((not self.destroyed) and creationId == self.duiCreationId and self.browserHandle) then
            SendDuiMessage(self.browserHandle, json.encode({
                ['type'] = 'cs-boombox:create',
                ['uniqueId'] = self.uniqueId
            }))
        end

        pendingDuiCreation = false
    end)
end

function MediaManagerInstance:adjust(time)
    if (self.managerReady and self.browserHandle) then
        SendDuiMessage(self.browserHandle, json.encode({
            ['type'] = 'cs-boombox:adjust',
            ['uniqueId'] = self.uniqueId,
            ['time'] = time
        }))
    end
end

function MediaManagerInstance:updatePlayer(startPosition, playerUpVector, cameraDirection)
    if ((not self.browserReady) or (not self.browserHandle)) then
        return
    end

    local speakersData = {}

    if (DoesEntityExist(self.object)) then
        local objectForwardVector, objectRightVector, objectUpVector, objectPosition = GetEntityMatrix(self.object)

        for i = 1, #self.speakers do
            local speaker = self.speakers[i]
            local speakerPosition = objectPosition + speaker.soundOffset
            local speakerDirection = (objectForwardVector * -1) * speaker.directionOffset

            table.insert(speakersData, {
                ['id'] = speaker.id,

                ['position'] = {
                    speakerPosition.x,
                    speakerPosition.y,
                    speakerPosition.z
                },

                ['orientation'] = {
                    speakerDirection.x,
                    speakerDirection.y,
                    speakerDirection.z
                },

                ['distance'] = #(startPosition - speakerPosition)
            })
        end
    end

    SendDuiMessage(self.browserHandle, json.encode({
        ['type'] = 'cs-boombox:update',
        ['uniqueId'] = self.uniqueId,

        ['listener'] = {
            ['up'] = {
                playerUpVector.x,
                playerUpVector.y,
                playerUpVector.z
            },

            ['forward'] = {
                cameraDirection.x,
                cameraDirection.y,
                cameraDirection.z
            },

            ['position'] = {
                startPosition.x,
                startPosition.y,
                startPosition.z
            }
        },

        ['speakers'] = speakersData
    }))
end

function MediaManagerInstance:onManagerReady()
    self.managerReady = true

    while (#self.managerQueue > 0) do
        self.managerQueue[1]()
        table.remove(self.managerQueue, 1)
    end

    if (self.pendingSync) then
        self:sync(self.pendingSync.data, self.pendingSync.temp)
    end
end

function MediaManagerInstance:onSynced()
    self.syncing = false

    if (self.pendingSync) then
        self:sync(self.pendingSync.data, self.pendingSync.temp)
    end
end

function MediaManagerInstance:onBrowserReady()
    self.browserReady = true
end

function MediaManagerInstance:addSpeaker(options)
    if (not self.managerReady) then
        table.insert(self.managerQueue, function()
            self:addSpeaker(options)
        end)
    elseif (self.browserHandle) then
        local id = #self.speakers + 1

        table.insert(self.speakers, {
            ['soundOffset'] = Ternary(options.soundOffset, vector3(0.0, 0.0, 0.0)),
            ['directionOffset'] = Ternary(options.directionOffset, vector3(1.0, 1.0, 1.0)),
            ['id'] = id
        })

        local maxDistance = Ternary(options.maxDistance, config.models[self.model].range / 4)
        local refDistance = Ternary(options.refDistance, config.models[self.model].range / 8)

        SendDuiMessage(self.browserHandle, json.encode({
            ['type'] = 'cs-boombox:addSpeaker',
            ['uniqueId'] = self.uniqueId,
            ['speakerId'] = id,
            ['maxDistance'] = Ternary(refDistance > maxDistance, refDistance + (refDistance / 2), maxDistance),
            ['refDistance'] = refDistance,
            ['rolloffFactor'] = Ternary(options.rolloffFactor, 1.25),
            ['coneInnerAngle'] = Ternary(options.coneInnerAngle, 45),
            ['coneOuterAngle'] = Ternary(options.coneOuterAngle, 180),
            ['coneOuterGain'] = Ternary(options.coneOuterGain, 0.5),
            ['fadeDurationMs'] = Ternary(options.fadeDurationMs, 250),
            ['volumeMultiplier'] = Ternary(options.volumeMultiplier, 1.0)
        }))
    end
end

function MediaManagerInstance:destroyDui()
    self.managerReady = false
    self.browserReady = false
    self.duiCreated = false
    self.duiCreationId = self.duiCreationId + 1
    
    if (self.browserHandle) then
        DestroyDui(self.browserHandle)
        self.browserHandle = nil
    end
end

function MediaManagerInstance:destroy()
    self.destroyed = true
    self:destroyDui()
end

function MediaManager(uniqueId, object, model)
    local instance = {}
    
    setmetatable(instance, MediaManagerInstance)

    instance.uniqueId = uniqueId
    instance.object = object
    instance.model = model
    instance.serverSynced = false
    instance.browserReady = false
    instance.managerReady = false
    instance.destroyed = false
    instance.syncing = false
    instance.duiCreated = false
    instance.duiNewlyCreated = false
    instance.duiCreationId = 0
    instance.recentlyCreated = true
    instance.pendingSync = nil
    instance.managerQueue = {}
    instance.speakers = {}

    instance:addSpeaker(config.models[instance.model].speaker)

    return instance
end

RegisterNUICallback('browserReady', function(data, callback)
    if (instances[data.uniqueId]) then
        instances[data.uniqueId].manager:onBrowserReady()
    end

    callback(true)
end)

RegisterNUICallback('synced', function(data, callback)
    if (instances[data.uniqueId]) then
        instances[data.uniqueId].manager:onSynced()
    end

    callback(true)
end)

RegisterNUICallback('managerReady', function(data, callback)
    if (instances[data.uniqueId]) then
        instances[data.uniqueId].manager:onManagerReady()
    end

    callback(true)
end)

RegisterNUICallback('controllerError', function(data, callback)
    if (instances[data.uniqueId]) then
        if (uiEnabled) then
            local message = data.error

            if (data.error == 'E_SOURCE_ERROR') then
                message = config.lang.sourceError
            elseif (data.error == 'E_TWITCH_CHANNEL_OFFLINE') then
                message = config.lang.twitchChannelOffline
            elseif (data.error == 'E_TWITCH_VOD_SUB_ONLY') then
                message = config.lang.twitchVodSubOnly
            elseif (data.error == 'E_TWITCH_PLAYBACK_BLOCKED') then
                message = config.lang.twitchError
            elseif (data.error == 'E_YOUTUBE_ERROR') then
                message = config.lang.youtubeError
            elseif (data.error == 'E_SOURCE_NOT_FOUND') then
                message = config.lang.sourceNotFound
            end

            SendNUIMessage({
                ['type'] = 'cs-boombox:error',
                ['uniqueId'] = data.uniqueId,
                ['error'] = message
            })
        end

        if (instances[data.uniqueId].isUpdater) then
            TriggerServerEvent('cs-boombox:controllerError', data.uniqueId)
        end
    end

    callback(true)
end)

RegisterNUICallback('controllerEnded', function(data, callback)
    if (instances[data.uniqueId] and instances[data.uniqueId].isUpdater) then
        TriggerServerEvent('cs-boombox:controllerEnded', data.uniqueId)
    end

    callback(true)
end)

RegisterNUICallback('controllerResync', function(data, callback)
    if (instances[data.uniqueId]) then
        TriggerServerEvent('cs-boombox:resync', data.uniqueId, true)
    end

    callback(true)
end)

RegisterNUICallback('controllerPlayingInfo', function(data, callback)
    if (not instances[data.uniqueId]) then
        return
    end

    instances[data.uniqueId].controllerPlayingInfo.time = data.time
    instances[data.uniqueId].controllerPlayingInfo.duration = data.duration
    instances[data.uniqueId].controllerPlayingInfo.playing = data.playing

    SendNUIMessage({
        ['type'] = 'cs-boombox:info',
        ['uniqueId'] = data.uniqueId,
        ['time'] = instances[data.uniqueId].controllerPlayingInfo.time,
        ['playing'] = instances[data.uniqueId].controllerPlayingInfo.playing,
        ['duration'] = instances[data.uniqueId].controllerPlayingInfo.duration
    })

    if (instances[data.uniqueId].controllerPlayingInfo.duration and instances[data.uniqueId].controllerPlayingInfo.duration ~= instances[data.uniqueId].lastSeenDuration) then
        instances[data.uniqueId].lastSeenDuration = instances[data.uniqueId].controllerPlayingInfo.duration

        if (instances[data.uniqueId].isUpdater) then
            TriggerServerEvent('cs-boombox:duration', data.uniqueId, instances[data.uniqueId].controllerPlayingInfo.duration)
        end
    end

    callback(true)
end)

RegisterNUICallback('controllerSeeked', function(data, callback)
    if (not instances[data.uniqueId]) then
        return
    end

    SendNUIMessage({
        ['type'] = 'cs-boombox:seeked',
        ['uniqueId'] = data.uniqueId
    })

    callback(true)
end)

RegisterNUICallback('urlAdded', function(data, callback)
    TriggerServerEvent('cs-boombox:addToQueue', data.uniqueId, data.url, data.thumbnailUrl, data.thumbnailTitle or false, data.title, data.icon or false)
    callback(true)
end)

RegisterNUICallback('playerPaused', function (data, callback)
    TriggerServerEvent('cs-boombox:pause', data.uniqueId)
    callback(true)
end)

RegisterNUICallback('playerPlayed', function (data, callback)
    TriggerServerEvent('cs-boombox:play', data.uniqueId)
    callback(true)
end)

RegisterNUICallback('playerStopped', function (data, callback)
    TriggerServerEvent('cs-boombox:stop', data.uniqueId)
    callback(true)
end)

RegisterNUICallback('playerSkipped', function (data, callback)
    TriggerServerEvent('cs-boombox:nextQueueSong', data.uniqueId)
    callback(true)
end)

RegisterNUICallback('playerLooped', function (data, callback)
    TriggerServerEvent('cs-boombox:toggleLoop', data.uniqueId)
    callback(true)
end)

RegisterNUICallback('changeVolume', function (data, callback)
    TriggerServerEvent('cs-boombox:changeVolume', data.uniqueId, data.value)
    callback(true)
end)

RegisterNUICallback('seek', function (data, callback)
    if (instances[data.uniqueId]) then
        TriggerServerEvent('cs-boombox:seek', data.uniqueId, Ternary(instances[data.uniqueId].controllerPlayingInfo.duration and instances[data.uniqueId].controllerPlayingInfo.duration > 0 and data.value > instances[data.uniqueId].controllerPlayingInfo.duration, instances[data.uniqueId].controllerPlayingInfo.duration - 0.5, data.value))
    end

    callback(true)
end)

RegisterNUICallback('queueNow', function (data, callback)
    TriggerServerEvent('cs-boombox:queueNow', data.uniqueId, data.index)
    callback(true)
end)

RegisterNUICallback('queueNext', function (data, callback)
    TriggerServerEvent('cs-boombox:queueNext', data.uniqueId, data.index)
    callback(true)
end)

RegisterNUICallback('queueRemove', function (data, callback)
    TriggerServerEvent('cs-boombox:queueRemove', data.uniqueId, data.index)
    callback(true)
end)

RegisterNUICallback('toggleSetting', function (data, callback)
    TriggerServerEvent('cs-boombox:toggleSetting', data.uniqueId, data.key)
    callback(true)
end)

RegisterNUICallback('inputBlur', function(data, callback)
    if (uiEnabled) then
        SetNuiFocusKeepInput(true)
    end

    callback(true)
end)

RegisterNUICallback('inputFocus', function(data, callback)
    Wait(250)
    SetNuiFocusKeepInput(false)
    callback(true)
end)

RegisterNUICallback('hideUi', function(data, callback)
    if (uiEnabled) then
        HideUi()
    end

    callback(true)
end)

RegisterNUICallback('nuiReady', function(data, callback)
    nuiReady = true

    SendNUIMessage({
        ['type'] = 'cs-boombox:ready',
        ['lang'] = config.lang
    })

    callback(true)
end)

RegisterNetEvent('cs-boombox:cui', function(uniqueId, hideOnly)
    if (uiEnabled) then
        HideUi()
    elseif (not hideOnly) then
        ShowUi(uniqueId)
    end
end)

RegisterNetEvent('cs-boombox:updater', function(uniqueId, status)
    if (not instances[uniqueId]) then
        return
    end

    instances[uniqueId].isUpdater = status
end)

RegisterNetEvent('cs-boombox:controller', function(uniqueId, status)
    if (instances[uniqueId]) then
        instances[uniqueId].isController = status
    end
end)

RegisterNetEvent('cs-boombox:syncableObject', function(uniqueId, status)
    if (status) then
        syncableObjects[uniqueId] = GetGameTimer()
    else
        syncableObjects[uniqueId] = nil
    end
end)

RegisterNetEvent('cs-boombox:queue', function(uniqueId, queue)
    if (instances[uniqueId]) then
        SendNUIMessage({
            ['type'] = 'cs-boombox:queue',
            ['uniqueId'] = uniqueId,
            ['queue'] = queue
        })
    end
end)

RegisterNetEvent('cs-boombox:client', function()
    serverReady = true
end)

RegisterNetEvent('cs-boombox:params', function(url, version)
    duiUrl = url
    resourceVersion = version
    paramsReady = true
end)

RegisterNetEvent('cs-boombox:sync', function(uniqueId, data, temp, syncable)
    syncableObjects = syncable

    if (instances[uniqueId]) then
        SendNUIMessage({
            ['type'] = 'cs-boombox:sync',
            ['uniqueId'] = uniqueId,
            ['media'] = data.media
        })

        if (instances[uniqueId].isUpdater and data.media.duration and data.media.duration > 0 and Round(data.media.time) ~= Round(instances[uniqueId].controllerPlayingInfo.time)) then
            instances[uniqueId].lastUpdatedTime = instances[uniqueId].controllerPlayingInfo.time
            TriggerServerEvent('cs-boombox:time', uniqueId, instances[uniqueId].controllerPlayingInfo.time, true)
        end

        if (data.media.stopped) then
            instances[uniqueId].lastSeenDuration = nil
        end

        instances[uniqueId].manager:sync(data.media, temp)
    end
end)

RegisterNetEvent('cs-boombox:adjust', function(uniqueId, time)
    if (instances[uniqueId]) then
        instances[uniqueId].manager:adjust(time)
    end
end)

AddEventHandler('cs-boombox:setUiAccessible', function(state)
    uiAccessible = state
end)

AddEventHandler('cs-boombox:objectInRange', function(object, uniqueId, model)
    if (instances[uniqueId]) then
        return
    end

    instances[uniqueId] = {
        ['lastUpdatedTime'] = nil,
        ['lastSeenDuration'] = nil,

        ['isUpdater'] = false,
        ['isController'] = false,

        ['controllerPlayingInfo'] = {
            ['time'] = 0
        },

        ['model'] = model,
        ['manager'] = MediaManager(uniqueId, object, model)
    }
end)

AddEventHandler('cs-boombox:objectOutOfRange', function(object, uniqueId)
    if (not instances[uniqueId]) then
        return
    end

    instances[uniqueId].manager:destroy()
    instances[uniqueId] = nil

    TriggerServerEvent('cs-boombox:leftSyncUniqueId', uniqueId)
end)

AddEventHandler('onResourceStop', function(resource)
    if (GetCurrentResourceName() ~= resource or GetCurrentServerEndpoint() == nil) then
        return
    end

    for k, v in pairs(instances) do
        instances[k].manager:destroy()
    end
end)

CreateThread(function()
    while (true) do
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local objects = GetGamePool('CObject')

        for i = 0, #objects do
            local object = objects[i]

            if (DoesEntityExist(object) and (not HasObjectBeenBroken(object))) then
                local model = GetEntityModel(object)

                if (configHashToModel[model] and NetworkGetEntityIsNetworked(object)) then
                    local uniqueId = tostring(NetworkGetNetworkIdFromEntity(object))

                    if (not inRangeUniqueIds[uniqueId]) then
                        if (inRangeObjects[object]) then
                            TriggerEvent('cs-boombox:objectOutOfRange', object, inRangeObjects[object])
                            inRangeObjects[object] = nil
                        else
                            local position = GetEntityCoords(object)
                            local modelKey = configHashToModel[model]

                            if (config.models[modelKey] and config.models[modelKey].enabled and (#(coords - position) <= config.models[modelKey].range)) then
                                inRangeUniqueIds[uniqueId] = object
                                inRangeObjects[object] = uniqueId
                                TriggerEvent('cs-boombox:objectInRange', object, uniqueId, modelKey)
                            end
                        end
                    elseif (inRangeUniqueIds[uniqueId] ~= object and inRangeObjects[object]) then
                        TriggerEvent('cs-boombox:objectOutOfRange', object, inRangeObjects[object])
                        inRangeObjects[object] = nil
                    end
                end
            end
        end

        for k, v in pairs(inRangeUniqueIds) do
            local modelKey = configHashToModel[GetEntityModel(v)]

            if ((not DoesEntityExist(v)) or HasObjectBeenBroken(v, false) or (#(coords - GetEntityCoords(v)) > config.models[modelKey].range)) then
                TriggerEvent('cs-boombox:objectOutOfRange', v, k)
                inRangeUniqueIds[k] = nil
                inRangeObjects[v] = nil
            end
        end

        Wait(scanThreadMs)
    end
end)

CreateThread(function()
    while (not NetworkIsSessionStarted()) do
        Wait(networkSessionWaitMs)
    end

    TriggerServerEvent('cs-boombox:fetch')

    while ((not nuiReady) or (not paramsReady)) do
        Wait(networkSessionWaitMs)
    end

    TriggerServerEvent('cs-boombox:server')

    AddEventHandler('cs-boombox:integrationReady', function()
        TriggerEvent('cs-boombox:ready')
    end)

    TriggerEvent('cs-boombox:ready')

    while (true) do
        if (nuiReady and serverReady) then
            local timeNow = GetGameTimer()

            if ((timeNow - lastSpeakerUpdateAt) > coreUpdateMs) then
                lastSpeakerUpdateAt = timeNow

                local playerPed = PlayerPedId()
                local camRot = GetGameplayCamRot(2)
                local playerForwardVector, playerRightVector, playerUpVector, playerPosition = GetEntityMatrix(playerPed)
                local cameraDirection = RotationToDirection(camRot)
                local boneIndex = GetEntityBoneIndexByName(playerPed, 'BONETAG_HEAD')
                local startPosition = Ternary(boneIndex ~= -1, GetWorldPositionOfEntityBone(playerPed, boneIndex), playerPosition)

                for k, v in pairs(instances) do
                    if (instances[k].controllerPlayingInfo.playing) then
                        instances[k].manager:updatePlayer(startPosition, playerUpVector, cameraDirection)
                    end

                    if (syncableObjects[k] and (not instances[k].manager.duiCreated)) then
                        instances[k].manager:createDui()
                    elseif ((not syncableObjects[k]) and instances[k].manager.duiCreated) then
                        instances[k].manager:destroyDui()
                    end

                    if (not instances[k].manager.serverSynced) then
                        instances[k].manager.serverSynced = true
                        TriggerServerEvent('cs-boombox:enteredSyncUniqueId', k, instances[k].model)
                    end
                end
            end

            if ((timeNow - lastSyncUpdateAt) > syncUpdateMs) then
                lastSyncUpdateAt = timeNow

                if (uiEnabled and (not CanAccessUi())) then
                    HideUi()
                end
            end

            if ((timeNow - lastTimeSyncAt) > timeSyncMs) then
                lastTimeSyncAt = timeNow

                for k, v in pairs(instances) do
                    if (instances[k].isUpdater and instances[k].controllerPlayingInfo.playing and instances[k].controllerPlayingInfo.duration and instances[k].controllerPlayingInfo.duration > 0 and instances[k].controllerPlayingInfo.time > 0 and instances[k].lastUpdatedTime ~= instances[k].controllerPlayingInfo.time) then
                        instances[k].lastUpdatedTime = instances[k].controllerPlayingInfo.time
                        TriggerServerEvent('cs-boombox:time', k, instances[k].controllerPlayingInfo.time, false)
                    end
                end
            end
        end

        Wait(mainThreadMs)
    end
end)
