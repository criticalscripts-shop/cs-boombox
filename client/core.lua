if (not config) then
    error('[criticalscripts.shop] cs-boombox configuration file has a syntax error, please resolve it otherwise the resource will not work.')
    return
end

local internalVersion = '1.1.3'

local inRangeUUIDs = {}
local inRangeObjects = {}
local configModelToHash = {}
local configHashToModel = {}
local instances = {}

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
local mainThreadMs = 100
local scanThreadMs = 500
local coreUpdateMs = 200
local syncUpdateMs = 250
local timeSyncMs = 3000
local networkSessionWaitMs = 100
local browserWaitMs = 100

function EnumerateEntities(initFunc, moveFunc, disposeFunc)
    return coroutine.wrap(function()
        local iter, id = initFunc()

        if ((not id) or id == 0) then
            disposeFunc(iter)
            return
        end

        local enum = {
            handle = iter,
            destructor = disposeFunc
        }

        setmetatable(enum, {
            __gc = function(enum)
                if enum.destructor and enum.handle then
                    enum.destructor(enum.handle)
                end

                enum.destructor = nil
                enum.handle = nil
            end
        })

        local next = true

        repeat
            coroutine.yield(id)
            next, id = moveFunc(iter)
        until (not next)

        enum.destructor, enum.handle = nil, nil

        disposeFunc(iter)
    end)
end

function RotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(math.min(math.max(rotation.x, -30.0), 30.0))
    local abs = math.abs(math.cos(x))
    return vector3(-math.sin(z) * abs, math.cos(z) * abs, math.sin(x))
end

function ShowUi(uuid)
    if (not CanAccessUi()) then
        return
    end

    uiEnabled = uuid

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)

    SendNUIMessage({
        ['type'] = 'cs-boombox:show',
        ['uuid'] = uuid
    })

    TriggerEvent('cs-boombox:onControllerInterfaceOpen')
    TriggerServerEvent('cs-boombox:ui', uuid)

    CreateThread(function()
        while (uiEnabled) do
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
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
    else
        self.syncing = true
        self.pendingSync = nil

        SendDuiMessage(self.browserHandle, json.encode({
            ['type'] = 'cs-boombox:sync',
            ['uuid'] = self.uuid,
            ['playing'] = data.playing,
            ['stopped'] = data.stopped,
            ['time'] = data.time,
            ['duration'] = data.duration,
            ['volume'] = data.volume,
            ['url'] = data.url,

            ['temp'] = {
                ['force'] = temp.force,
                ['adjust'] = temp.adjust,
                ['seek'] = Ternary(temp.media, temp.media and temp.media.seek, false)
            }
        }))
    end
end

function MediaManagerInstance:createDui()
    self.duiCreated = true

    local creationId = self.duiCreationId

    while (pendingDuiCreation) do  
        Wait(500)
    end

    pendingDuiCreation = true

    CreateThread(function()
        while (not paramsReady) do
            Wait(browserWaitMs)
        end

        self.browserHandle = CreateDui(duiUrl .. '?v=' .. resourceVersion .. '+' .. internalVersion .. (debugDui and '&debug=1' or '') .. '#' .. GetCurrentResourceName() .. '|' .. self.uuid, 1280, 720)

        CreateRuntimeTextureFromDuiHandle(CreateRuntimeTxd('browser_' .. self.uuid), 'browserTexture_' .. self.uuid, GetDuiHandle(self.browserHandle))

        while ((not self.browserHandle) or (not IsDuiAvailable(self.browserHandle)) or (not nuiReady) or (not self.browserReady) or (not serverReady)) do
            if (self.destroyed or creationId ~= self.duiCreationId) then
                break
            end

            Wait(browserWaitMs)
        end

        if ((not self.destroyed) and creationId == self.duiCreationId) then
            SendDuiMessage(self.browserHandle, json.encode({
                ['type'] = 'cs-boombox:create',
                ['uuid'] = self.uuid
            }))
        end

        pendingDuiCreation = false
    end)
end

function MediaManagerInstance:adjust(time)
    if (self.managerReady) then
        SendDuiMessage(self.browserHandle, json.encode({
            ['type'] = 'cs-boombox:adjust',
            ['uuid'] = self.uuid,
            ['time'] = time
        }))
    end
end

function MediaManagerInstance:updatePlayer(startPosition, playerUpVector, cameraDirection)
    if (not self.browserReady) then
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
        ['uuid'] = self.uuid,

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
    else
        local id = #self.speakers + 1

        table.insert(self.speakers, {
            ['soundOffset'] = Ternary(options.soundOffset, vector3(0.0, 0.0, 0.0)),
            ['directionOffset'] = Ternary(options.directionOffset, vector3(0.0, 0.0, 0.0)),
            ['id'] = id
        })

        SendDuiMessage(self.browserHandle, json.encode({
            ['type'] = 'cs-boombox:addSpeaker',
            ['uuid'] = self.uuid,
            ['speakerId'] = id,
            ['maxDistance'] = Ternary(options.maxDistance, config.models[self.model].range / 5),
            ['refDistance'] = Ternary(options.refDistance, config.models[self.model].range / 8),
            ['rolloffFactor'] = Ternary(options.rolloffFactor, 1.25),
            ['coneInnerAngle'] = Ternary(options.coneInnerAngle, 90),
            ['coneOuterAngle'] = Ternary(options.coneOuterAngle, 180),
            ['coneOuterGain'] = Ternary(options.coneOuterGain, 0.5),
            ['fadeDurationMs'] = Ternary(options.fadeDurationMs, 250),
            ['volumeMultiplier'] = Ternary(options.volumeMultiplier, 1.0)
        }))
    end
end

function MediaManagerInstance:destroyDui()
    self.duiCreated = false
    self.duiCreationId = self.duiCreationId + 1
    
    if (self.browserHandle) then
        DestroyDui(self.browserHandle)
    end
end

function MediaManagerInstance:destroy()
    self.destroyed = true
    self:destroyDui()
end

function MediaManager(uuid, object, model)
    local instance = {}
    
    setmetatable(instance, MediaManagerInstance)

    instance.uuid = uuid
    instance.object = object
    instance.model = model
    instance.serverSynced = false
    instance.browserReady = false
    instance.managerReady = false
    instance.destroyed = false
    instance.syncing = false
    instance.duiCreated = false
    instance.duiCreationId = 0
    instance.pendingSync = nil
    instance.managerQueue = {}
    instance.speakers = {}

    for i = 1, #config.models[instance.model].speakers do
        instance:addSpeaker(config.models[instance.model].speakers[i])
    end

    return instance
end

RegisterNUICallback('browserReady', function(data, callback)
    if (instances[data.uuid]) then
        instances[data.uuid].manager:onBrowserReady()
    end

    callback(true)
end)

RegisterNUICallback('synced', function(data, callback)
    if (instances[data.uuid]) then
        instances[data.uuid].manager:onSynced()
    end

    callback(true)
end)

RegisterNUICallback('managerReady', function(data, callback)
    if (instances[data.uuid]) then
        instances[data.uuid].manager:onManagerReady()
    end

    callback(true)
end)

RegisterNUICallback('controllerError', function(data, callback)
    if (instances[data.uuid]) then
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
                ['uuid'] = data.uuid,
                ['error'] = message
            })
        end

        if (instances[data.uuid].isUpdater) then
            TriggerServerEvent('cs-boombox:controllerError', data.uuid)
        end
    end

    callback(true)
end)

RegisterNUICallback('controllerEnded', function(data, callback)
    if (instances[data.uuid] and instances[data.uuid].isUpdater) then
        TriggerServerEvent('cs-boombox:controllerEnded', data.uuid)
    end

    callback(true)
end)

RegisterNUICallback('controllerResync', function(data, callback)
    if (instances[data.uuid]) then
        TriggerServerEvent('cs-boombox:resync', data.uuid, true)
    end

    callback(true)
end)

RegisterNUICallback('controllerPlayingInfo', function(data, callback)
    if (not instances[data.uuid]) then
        return
    end

    instances[data.uuid].controllerPlayingInfo.time = data.time
    instances[data.uuid].controllerPlayingInfo.duration = data.duration
    instances[data.uuid].controllerPlayingInfo.playing = data.playing

    SendNUIMessage({
        ['type'] = 'cs-boombox:info',
        ['uuid'] = data.uuid,
        ['time'] = instances[data.uuid].controllerPlayingInfo.time,
        ['duration'] = instances[data.uuid].controllerPlayingInfo.duration
    })

    if (instances[data.uuid].controllerPlayingInfo.duration and instances[data.uuid].controllerPlayingInfo.duration ~= instances[data.uuid].lastSeenDuration) then
        instances[data.uuid].lastSeenDuration = instances[data.uuid].controllerPlayingInfo.duration

        if (instances[data.uuid].isUpdater) then
            TriggerServerEvent('cs-boombox:duration', data.uuid, instances[data.uuid].controllerPlayingInfo.duration)
        end
    end

    callback(true)
end)

RegisterNUICallback('controllerSeeked', function(data, callback)
    if (not instances[data.uuid]) then
        return
    end

    SendNUIMessage({
        ['type'] = 'cs-boombox:seeked',
        ['uuid'] = data.uuid
    })

    callback(true)
end)

RegisterNUICallback('urlAdded', function(data, callback)
    TriggerServerEvent('cs-boombox:addToQueue', data.uuid, data.url, data.thumbnailUrl, data.thumbnailTitle or false, data.title, data.icon or false)
    callback(true)
end)

RegisterNUICallback('playerPaused', function (data, callback)
    TriggerServerEvent('cs-boombox:pause', data.uuid)
    callback(true)
end)

RegisterNUICallback('playerPlayed', function (data, callback)
    TriggerServerEvent('cs-boombox:play', data.uuid)
    callback(true)
end)

RegisterNUICallback('playerStopped', function (data, callback)
    TriggerServerEvent('cs-boombox:stop', data.uuid)
    callback(true)
end)

RegisterNUICallback('playerSkipped', function (data, callback)
    TriggerServerEvent('cs-boombox:nextQueueSong', data.uuid)
    callback(true)
end)

RegisterNUICallback('playerLooped', function (data, callback)
    TriggerServerEvent('cs-boombox:toggleLoop', data.uuid)
    callback(true)
end)

RegisterNUICallback('changeVolume', function (data, callback)
    TriggerServerEvent('cs-boombox:changeVolume', data.uuid, data.value)
    callback(true)
end)

RegisterNUICallback('seek', function (data, callback)
    if (instances[data.uuid]) then
        TriggerServerEvent('cs-boombox:seek', data.uuid, Ternary(instances[data.uuid].controllerPlayingInfo.duration and instances[data.uuid].controllerPlayingInfo.duration > 0 and data.value > instances[data.uuid].controllerPlayingInfo.duration, instances[data.uuid].controllerPlayingInfo.duration - 0.5, data.value))
    end

    callback(true)
end)

RegisterNUICallback('queueNow', function (data, callback)
    TriggerServerEvent('cs-boombox:queueNow', data.uuid, data.index)
    callback(true)
end)

RegisterNUICallback('queueNext', function (data, callback)
    TriggerServerEvent('cs-boombox:queueNext', data.uuid, data.index)
    callback(true)
end)

RegisterNUICallback('queueRemove', function (data, callback)
    TriggerServerEvent('cs-boombox:queueRemove', data.uuid, data.index)
    callback(true)
end)

RegisterNUICallback('toggleSetting', function (data, callback)
    TriggerServerEvent('cs-boombox:toggleSetting', data.uuid, data.key)
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

RegisterNetEvent('cs-boombox:cui', function(uuid, hideOnly)
    if (uiEnabled) then
        HideUi()
    elseif (not hideOnly) then
        ShowUi(uuid)
    end
end)

RegisterNetEvent('cs-boombox:updater', function(uuid, status)
    if (not instances[uuid]) then
        return
    end

    instances[uuid].isUpdater = status
end)

RegisterNetEvent('cs-boombox:controller', function(uuid, status)
    if (instances[uuid]) then
        instances[uuid].isController = status
    end
end)

RegisterNetEvent('cs-boombox:queue', function(uuid, queue)
    if (instances[uuid]) then
        SendNUIMessage({
            ['type'] = 'cs-boombox:queue',
            ['uuid'] = uuid,
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

RegisterNetEvent('cs-boombox:sync', function(uuid, data, temp)
    if (instances[uuid]) then
        SendNUIMessage({
            ['type'] = 'cs-boombox:sync',
            ['uuid'] = uuid,
            ['media'] = data.media
        })

        if (instances[uuid].isUpdater and data.media.duration and data.media.duration > 0 and Round(data.media.time) ~= Round(instances[uuid].controllerPlayingInfo.time)) then
            instances[uuid].lastUpdatedTime = instances[uuid].controllerPlayingInfo.time
            TriggerServerEvent('cs-boombox:time', uuid, instances[uuid].controllerPlayingInfo.time, true)
        end

        if (data.media.stopped) then
            instances[uuid].lastSeenDuration = nil
        end

        instances[uuid].manager:sync(data.media, temp)
    end
end)

RegisterNetEvent('cs-boombox:adjust', function(uuid, time)
    if (instances[uuid]) then
        instances[uuid].manager:adjust(time)
    end
end)

AddEventHandler('cs-boombox:setUiAccessible', function(state)
    uiAccessible = state
end)

AddEventHandler('cs-boombox:objectInRange', function(object, uuid, model)
    if (instances[uuid]) then
        return
    end

    instances[uuid] = {
        ['lastUpdatedTime'] = nil,
        ['lastSeenDuration'] = nil,

        ['isUpdater'] = false,
        ['isController'] = false,

        ['controllerPlayingInfo'] = {
            ['time'] = 0
        },

        ['model'] = model,
        ['manager'] = MediaManager(uuid, object, model)
    }
end)

AddEventHandler('cs-boombox:objectOutOfRange', function(object, uuid)
    if (not instances[uuid]) then
        return
    end

    instances[uuid].manager:destroy()
    instances[uuid] = nil

    TriggerServerEvent('cs-boombox:leftSyncUUID', uuid)
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
    for k, v in pairs(config.models) do
        configModelToHash[k] = GetHashKey(k)
        configHashToModel[configModelToHash[k]] = k
    end

    while (true) do
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)

        for object in EnumerateEntities(FindFirstObject, FindNextObject, EndFindObject) do
            if (DoesEntityExist(object) and (not HasObjectBeenBroken(object))) then
                -- TODO: Enumerate and create boomboxes
                local uuid = nil -- TODO: Get boombox UUID.

                if (not inRangeUUIDs[uuid]) then
                    if (inRangeObjects[object]) then
                        TriggerEvent('cs-boombox:objectOutOfRange', object, inRangeObjects[object])
                        inRangeObjects[object] = nil
                    else
                        local model = GetEntityModel(object)
                        local position = GetEntityCoords(object)
                        local modelKey = configHashToModel[model]

                        if (config.models[model].enabled and (#(coords - position) <= config.models[model].range)) then
                            inRangeUUIDs[uuid] = object
                            inRangeObjects[object] = uuid
                            TriggerEvent('cs-boombox:objectInRange', object, uuid, modelKey)
                        end
                    end
                elseif (inRangeUUIDs[uuid] ~= object and inRangeObjects[object]) then
                    TriggerEvent('cs-boombox:objectOutOfRange', object, inRangeObjects[object])
                    inRangeObjects[object] = nil
                end
            end
        end

        for k, v in pairs(inRangeUUIDs) do
            if ((not DoesEntityExist(v)) or HasObjectBeenBroken(v, false) or (#(coords - GetEntityCoords(v)) > config.models[model].range)) then
                TriggerEvent('cs-boombox:objectOutOfRange', v, k)
                inRangeUUIDs[k] = nil
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

                    if (not instances[k].manager.duiCreated) then
                        instances[k].manager:createDui()
                    end

                    if (uiAccessible and (not instances[k].manager.serverSynced)) then
                        instances[k].manager.serverSynced = true
                        TriggerServerEvent('cs-boombox:enteredSyncUUID', k, instances[k].model)
                    elseif ((not uiAccessible) and instances[k].manager.serverSynced) then
                        instances[k].manager.serverSynced = false
                        TriggerServerEvent('cs-boombox:leftSyncUUID', k)
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

exports('IsUiEnabled', function()
    return not not uiEnabled
end)
