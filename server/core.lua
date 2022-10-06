if (not config) then
    error('[criticalscripts.shop] cs-boombox configuration file has a syntax error, please resolve it otherwise the resource will not work.')
    return
end

if (config.updatesCheck) then
    local version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0)

    PerformHttpRequest('https://updates.criticalscripts.com/cs-boombox', function(e, b, h)
        if (e == 200) then
            local data = json.decode(b)

            if (data) then
                if (data.version ~= version) then
                    print('[criticalscripts.shop] Resource "cs-boombox" is outdated, please download the latest version from our GitHub (https://github.com/criticalscripts-shop/cs-boombox).')
                else
                    print('[criticalscripts.shop] Resource "cs-boombox" is up to date.')
                end

                if (data.message) then
                    print('[criticalscripts.shop] ' .. data.message)
                end
            else
                print('[criticalscripts.shop] Resource "cs-boombox" failed to perform update check.')
            end
        else
            print('[criticalscripts.shop] Resource "cs-boombox" failed to perform update check.')
        end
    end, 'GET', '', {})
end

local queue = {}
local players = {}
local controllers = {}
local data = {}
local syncableObjects = {}

function IsAllowedToUpdate(uniqueId, source)
    return data[uniqueId].updater == source
end

function IsAllowedToControl(uniqueId, source)
    return controllers[source] == uniqueId
end

function ClearController(uniqueId)
    if (data[uniqueId].controller and GetPlayerEndpoint(data[uniqueId].controller)) then
        TriggerClientEvent('cs-boombox:controller', data[uniqueId].controller, uniqueId, false)
    end

    data[uniqueId].controller = nil
end

function SetController(uniqueId, source)
    data[uniqueId].controller = source
    TriggerClientEvent('cs-boombox:controller', data[uniqueId].controller, uniqueId, true)
end

function TouchSyncableObject(uniqueId)
    syncableObjects[uniqueId] = GetGameTimer()

    for k, v in pairs(players) do
        TriggerClientEvent('cs-ves:syncableObject', k, uniqueId, true)
    end
end

function ObjectNoLongerSyncable(uniqueId)
    syncableObjects[uniqueId] = nil

    for k, v in pairs(players) do
        TriggerClientEvent('cs-ves:syncableObject', k, uniqueId, false)
    end
end

function RefreshCurrentUpdater(uniqueId)
    if (data[uniqueId].updater and GetPlayerEndpoint(data[uniqueId].updater)) then
        TriggerClientEvent('cs-boombox:updater', data[uniqueId].updater, uniqueId, false)
    end

    data[uniqueId].updater = nil
 
    if (data[uniqueId].controller and players[data[uniqueId].controller] and Contains(uniqueId, players[data[uniqueId].controller])) then
        data[uniqueId].updater = data[uniqueId].controller
    else
        for k, v in pairs(players) do
            if (Contains(uniqueId, v)) then
                data[uniqueId].updater = k
                break
            end
        end
    end

    if (data[uniqueId].updater) then
        TriggerClientEvent('cs-boombox:updater', data[uniqueId].updater, uniqueId, true)
    end
end

function SyncQueue(uniqueId, target, temp)
    if (not queue[uniqueId]) then
        queue[uniqueId] = {}
    end

    if (target) then
        TriggerClientEvent('cs-boombox:queue', target, uniqueId, queue[uniqueId])
    else
        for k, v in pairs(players) do
            if (Contains(uniqueId, v)) then
                TriggerClientEvent('cs-boombox:queue', k, uniqueId, queue[uniqueId])
            end
        end
    end
end

function SyncData(uniqueId, target, temp)
    if (target) then
        TriggerClientEvent('cs-boombox:sync', target, uniqueId, data[uniqueId], temp or {}, syncableObjects)
    else
        for k, v in pairs(players) do
            if (Contains(uniqueId, v)) then
                TriggerClientEvent('cs-boombox:sync', k, uniqueId, data[uniqueId], temp or {}, syncableObjects)
            end
        end
    end
end

function AdjustTime(uniqueId)
    for k, v in pairs(players) do
        if (Contains(uniqueId, v)) then
            TriggerClientEvent('cs-boombox:adjust', k, data[uniqueId].time)
        end
    end
end

RegisterNetEvent('cs-boombox:play', function(uniqueId, uiOpen)
    local source = source

    if (data[uniqueId] and IsAllowedToControl(uniqueId, source)) then
        SetController(uniqueId, source)

        if (data[uniqueId].updater ~= data[uniqueId].controller) then
            RefreshCurrentUpdater(uniqueId)
        end

        local force = false

        if ((#queue[uniqueId] > 0) and (not data[uniqueId].media.url)) then
            local q = queue[uniqueId][1]

            table.remove(queue[uniqueId], 1)

            if (data[uniqueId].media.url ~= q.url) then
                data[uniqueId].media.duration = q.duration
            end

            data[uniqueId].media.url = q.url
            data[uniqueId].media.thumbnailUrl = q.thumbnailUrl
            data[uniqueId].media.thumbnailTitle = q.thumbnailTitle
            data[uniqueId].media.title = q.title
            data[uniqueId].media.icon = q.icon
            data[uniqueId].media.time = 0

            force = true
        end

        if (data[uniqueId].media.url and (not data[uniqueId].media.playing)) then
            data[uniqueId].media.playing = true
            data[uniqueId].media.stopped = false
        end

        TouchSyncableObject(uniqueId)

        TriggerEvent('cs-boombox:onPlay', uniqueId, source, {
            ['url'] = data[uniqueId].media.url,
            ['thumbnailUrl'] = data[uniqueId].media.thumbnailUrl,
            ['thumbnailTitle'] = data[uniqueId].media.thumbnailTitle,
            ['title'] = data[uniqueId].media.title,
            ['icon'] = data[uniqueId].media.icon
        })

        SyncQueue(uniqueId)

        SyncData(uniqueId, nil, {
            ['force'] = force
        })
    end
end)

RegisterNetEvent('cs-boombox:pause', function(uniqueId, uiOpen)
    local source = source

    if (data[uniqueId] and IsAllowedToControl(uniqueId, source)) then
        SetController(uniqueId, source)

        if (data[uniqueId].updater ~= data[uniqueId].controller) then
            RefreshCurrentUpdater(uniqueId)
        end

        if (data[uniqueId].media.playing) then
            data[uniqueId].media.playing = false
        end

        TriggerEvent('cs-boombox:onPause', uniqueId, source, {
            ['url'] = data[uniqueId].media.url,
            ['thumbnailUrl'] = data[uniqueId].media.thumbnailUrl,
            ['thumbnailTitle'] = data[uniqueId].media.thumbnailTitle,
            ['title'] = data[uniqueId].media.title,
            ['icon'] = data[uniqueId].media.icon
        })

        SyncData(uniqueId)
    end
end)

RegisterNetEvent('cs-boombox:stop', function(uniqueId, uiOpen)
    local source = source

    if (data[uniqueId] and IsAllowedToControl(uniqueId, source)) then
        SetController(uniqueId, source)

        if (data[uniqueId].updater ~= data[uniqueId].controller) then
            RefreshCurrentUpdater(uniqueId)
        end

        if (data[uniqueId].media.playing) then
            TriggerEvent('cs-boombox:onStop', uniqueId, source, {
                ['url'] = data[uniqueId].media.url,
                ['thumbnailUrl'] = data[uniqueId].media.thumbnailUrl,
                ['thumbnailTitle'] = data[uniqueId].media.thumbnailTitle,
                ['title'] = data[uniqueId].media.title,
                ['icon'] = data[uniqueId].media.icon
            })
        end

        data[uniqueId].media.playing = false
        data[uniqueId].media.stopped = true
        data[uniqueId].media.time = 0
        data[uniqueId].media.duration = nil

        SyncData(uniqueId, nil, {
            ['force'] = true
        })
    end
end)

RegisterNetEvent('cs-boombox:seek', function(uniqueId, time)
    local source = source

    if (data[uniqueId] and IsAllowedToControl(uniqueId, source)) then
        if (data[uniqueId].media.duration and data[uniqueId].media.duration > 0) then
            SetController(uniqueId, source)
    
            if (data[uniqueId].updater ~= data[uniqueId].controller) then
                RefreshCurrentUpdater(uniqueId)
            end
    
            if (data[uniqueId].media.url) then
                data[uniqueId].media.time = time
    
                SyncData(uniqueId, nil, {
                    ['media'] = {
                        ['seek'] = true
                    }
                })

                return
            end
        end

        SyncData(uniqueId)
    end
end)

RegisterNetEvent('cs-boombox:changeVolume', function(uniqueId, volume)
    local source = source

    if (data[uniqueId] and IsAllowedToControl(uniqueId, source)) then
        SetController(uniqueId, source)

        if (data[uniqueId].updater ~= data[uniqueId].controller) then
            RefreshCurrentUpdater(uniqueId)
        end

        if ((not data[uniqueId].config.maxVolumePercent) or data[uniqueId].config.maxVolumePercent >= volume) then
            data[uniqueId].media.volume = volume / 100
        else
            data[uniqueId].media.volume = data[uniqueId].config.maxVolumePercent / 100
        end

        SyncData(uniqueId)
    end
end)

RegisterNetEvent('cs-boombox:toggleLoop', function(uniqueId)
    local source = source

    if (data[uniqueId] and IsAllowedToControl(uniqueId, source)) then
        SetController(uniqueId, source)

        if (data[uniqueId].updater ~= data[uniqueId].controller) then
            RefreshCurrentUpdater(uniqueId)
        end

        data[uniqueId].media.loop = not data[uniqueId].media.loop

        SyncData(uniqueId)
    end
end)

RegisterNetEvent('cs-boombox:addToQueue', function(uniqueId, url, thumbnailUrl, thumbnailTitle, title, icon)
    local source = source

    if (data[uniqueId] and IsAllowedToControl(uniqueId, source)) then
        if ((not StartsWith(url, 'https://www.youtube.com/')) and (not StartsWith(url, 'https://www.twitch.tv/')) and (not StartsWith(url, 'https://clips.twitch.tv/'))) then
            return
        end

        SetController(uniqueId, source)

        if (data[uniqueId].updater ~= data[uniqueId].controller) then
            RefreshCurrentUpdater(uniqueId)
        end

        table.insert(queue[uniqueId], {
            ['url'] = url,
            ['thumbnailUrl'] = thumbnailUrl,
            ['thumbnailTitle'] = thumbnailTitle,
            ['title'] = title,
            ['icon'] = icon,
            ['duration'] = nil,
            ['manual'] = true
        })

        TriggerEvent('cs-boombox:onEntryQueued', uniqueId, source, {
            ['url'] = url,
            ['thumbnailUrl'] = thumbnailUrl,
            ['thumbnailTitle'] = thumbnailTitle,
            ['title'] = title,
            ['icon'] = icon,
            ['position'] = #queue[uniqueId],
            ['duration'] = nil,
            ['manual'] = true
        })

        SyncQueue(uniqueId)
    end
end)

RegisterNetEvent('cs-boombox:nextQueueSong', function(uniqueId, uiOpen)
    local source = source

    if (data[uniqueId] and IsAllowedToControl(uniqueId, source)) then
        SetController(uniqueId, source)

        if (data[uniqueId].updater ~= data[uniqueId].controller) then
            RefreshCurrentUpdater(uniqueId)
        end

        if (#queue[uniqueId] > 0) then
            local q = queue[uniqueId][1]

            table.remove(queue[uniqueId], 1)

            if (data[uniqueId].media.url ~= q.url) then
                data[uniqueId].media.duration = q.duration
            end

            data[uniqueId].media.url = q.url
            data[uniqueId].media.thumbnailUrl = q.thumbnailUrl
            data[uniqueId].media.thumbnailTitle = q.thumbnailTitle
            data[uniqueId].media.title = q.title
            data[uniqueId].media.icon = q.icon
            data[uniqueId].media.time = 0

            TouchSyncableObject(uniqueId)

            TriggerEvent('cs-boombox:onPlay', uniqueId, source, {
                ['url'] = data[uniqueId].media.url,
                ['thumbnailUrl'] = data[uniqueId].media.thumbnailUrl,
                ['thumbnailTitle'] = data[uniqueId].media.thumbnailTitle,
                ['title'] = data[uniqueId].media.title,
                ['icon'] = data[uniqueId].media.icon
            })
        else
            if (data[uniqueId].media.playing) then
                TriggerEvent('cs-boombox:onStop', uniqueId, source, {
                    ['url'] = data[uniqueId].media.url,
                    ['thumbnailUrl'] = data[uniqueId].media.thumbnailUrl,
                    ['thumbnailTitle'] = data[uniqueId].media.thumbnailTitle,
                    ['title'] = data[uniqueId].media.title,
                    ['icon'] = data[uniqueId].media.icon
                })
            end

            data[uniqueId].media.url = nil
            data[uniqueId].media.thumbnailUrl = nil
            data[uniqueId].media.thumbnailTitle = nil
            data[uniqueId].media.title = nil
            data[uniqueId].media.icon = nil
            data[uniqueId].media.playing = false
            data[uniqueId].media.stopped = true
            data[uniqueId].media.time = 0
            data[uniqueId].media.duration = nil
        end

        SyncQueue(uniqueId)

        SyncData(uniqueId, nil, {
            ['force'] = true
        })
    end
end)

RegisterNetEvent('cs-boombox:queueNow', function(uniqueId, index)
    local source = source

    if (data[uniqueId] and IsAllowedToControl(uniqueId, source)) then
        SetController(uniqueId, source)

        if (data[uniqueId].updater ~= data[uniqueId].controller) then
            RefreshCurrentUpdater(uniqueId)
        end

        if (queue[uniqueId][index]) then
            local q = queue[uniqueId][index]

            table.remove(queue[uniqueId], index)

            if (data[uniqueId].media.url ~= q.url) then
                data[uniqueId].media.duration = q.duration
            end

            data[uniqueId].media.url = q.url
            data[uniqueId].media.thumbnailUrl = q.thumbnailUrl
            data[uniqueId].media.thumbnailTitle = q.thumbnailTitle
            data[uniqueId].media.title = q.title
            data[uniqueId].media.icon = q.icon
            data[uniqueId].media.time = 0

            if (data[uniqueId].media.playing) then
                TouchSyncableObject(uniqueId)

                TriggerEvent('cs-boombox:onPlay', uniqueId, source, {
                    ['url'] = data[uniqueId].media.url,
                    ['thumbnailUrl'] = data[uniqueId].media.thumbnailUrl,
                    ['thumbnailTitle'] = data[uniqueId].media.thumbnailTitle,
                    ['title'] = data[uniqueId].media.title,
                    ['icon'] = data[uniqueId].media.icon
                })
            end
        end

        SyncQueue(uniqueId)

        SyncData(uniqueId, nil, {
            ['force'] = true
        })
    end
end)

RegisterNetEvent('cs-boombox:queueNext', function(uniqueId, index)
    local source = source

    if (data[uniqueId] and IsAllowedToControl(uniqueId, source)) then
        SetController(uniqueId, source)

        if (data[uniqueId].updater ~= data[uniqueId].controller) then
            RefreshCurrentUpdater(uniqueId)
        end

        if (queue[uniqueId][index]) then
            local q = queue[uniqueId][index]

            table.insert(queue[uniqueId], 1, q)
            table.remove(queue[uniqueId], index)
        end

        SyncQueue(uniqueId)
    end
end)

RegisterNetEvent('cs-boombox:queueRemove', function(uniqueId, index)
    local source = source

    if (data[uniqueId] and IsAllowedToControl(uniqueId, source)) then
        SetController(uniqueId, source)

        if (data[uniqueId].updater ~= data[uniqueId].controller) then
            RefreshCurrentUpdater(uniqueId)
        end

        if (queue[uniqueId][index]) then
            TriggerEvent('cs-boombox:onEntryRemoved', uniqueId, source, {
                ['url'] = queue[uniqueId][index].url,
                ['thumbnailUrl'] = queue[uniqueId][index].thumbnailUrl,
                ['thumbnailTitle'] = queue[uniqueId][index].thumbnailTitle,
                ['title'] = queue[uniqueId][index].title,
                ['icon'] = queue[uniqueId][index].icon,
                ['position'] = index,
                ['manual'] = queue[uniqueId][index].manual
            })

            table.remove(queue[uniqueId], index)
        end

        SyncQueue(uniqueId)
    end
end)

RegisterNetEvent('cs-boombox:duration', function(uniqueId, duration)
    local source = source

    if (data[uniqueId] and IsAllowedToUpdate(uniqueId, source) and data[uniqueId].media.playing) then
        data[uniqueId].media.duration = duration
        TriggerEvent('cs-boombox:onDuration', uniqueId, source, duration)
    end
end)

RegisterNetEvent('cs-boombox:time', function(uniqueId, time, force)
    local source = source

    if (data[uniqueId] and time and IsAllowedToUpdate(uniqueId, source) and (data[uniqueId].media.playing or force)) then
        data[uniqueId].media.time = time
    end
end)

RegisterNetEvent('cs-boombox:controllerEnded', function(uniqueId)
    local source = source

    if (data[uniqueId] and IsAllowedToUpdate(uniqueId, source)) then
        if (data[uniqueId].media.playing) then
            if (data[uniqueId].media.loop) then
                data[uniqueId].media.time = 0

                TouchSyncableObject(uniqueId)

                TriggerEvent('cs-boombox:onPlay', uniqueId, nil, {
                    ['url'] = data[uniqueId].media.url,
                    ['thumbnailUrl'] = data[uniqueId].media.thumbnailUrl,
                    ['thumbnailTitle'] = data[uniqueId].media.thumbnailTitle,
                    ['title'] = data[uniqueId].media.title,
                    ['icon'] = data[uniqueId].media.icon
                })
            elseif (#queue[uniqueId] > 0) then
                local q = queue[uniqueId][1]
    
                table.remove(queue[uniqueId], 1)

                if (data[uniqueId].media.url ~= q.url) then
                    data[uniqueId].media.duration = q.duration
                end
    
                data[uniqueId].media.url = q.url
                data[uniqueId].media.thumbnailUrl = q.thumbnailUrl
                data[uniqueId].media.thumbnailTitle = q.thumbnailTitle
                data[uniqueId].media.title = q.title
                data[uniqueId].media.icon = q.icon
                data[uniqueId].media.time = 0

                TouchSyncableObject(uniqueId)

                TriggerEvent('cs-boombox:onPlay', uniqueId, nil, {
                    ['url'] = data[uniqueId].media.url,
                    ['thumbnailUrl'] = data[uniqueId].media.thumbnailUrl,
                    ['thumbnailTitle'] = data[uniqueId].media.thumbnailTitle,
                    ['title'] = data[uniqueId].media.title,
                    ['icon'] = data[uniqueId].media.icon
                })

                SyncQueue(uniqueId)
            else
                TriggerEvent('cs-boombox:onStop', uniqueId, nil, {
                    ['url'] = data[uniqueId].media.url,
                    ['thumbnailUrl'] = data[uniqueId].media.thumbnailUrl,
                    ['thumbnailTitle'] = data[uniqueId].media.thumbnailTitle,
                    ['title'] = data[uniqueId].media.title,
                    ['icon'] = data[uniqueId].media.icon
                })

                data[uniqueId].media.url = nil
                data[uniqueId].media.thumbnailUrl = nil
                data[uniqueId].media.thumbnailTitle = nil
                data[uniqueId].media.title = nil
                data[uniqueId].media.icon = nil
                data[uniqueId].media.playing = false
                data[uniqueId].media.stopped = true
                data[uniqueId].media.time = 0
                data[uniqueId].media.duration = nil
            end

            SyncData(uniqueId, nil, {
                ['force'] = true
            })
        end
    end
end)

RegisterNetEvent('cs-boombox:controllerError', function(uniqueId)
    local source = source

    if (data[uniqueId] and IsAllowedToUpdate(uniqueId, source)) then
        if (data[uniqueId].media.playing) then
            if (#queue[uniqueId] > 0) then
                local q = queue[uniqueId][1]
    
                table.remove(queue[uniqueId], 1)

                if (data[uniqueId].media.url ~= q.url) then
                    data[uniqueId].media.duration = q.duration
                end
    
                data[uniqueId].media.url = q.url
                data[uniqueId].media.thumbnailUrl = q.thumbnailUrl
                data[uniqueId].media.thumbnailTitle = q.thumbnailTitle
                data[uniqueId].media.title = q.title
                data[uniqueId].media.icon = q.icon
                data[uniqueId].media.time = 0

                TouchSyncableObject(uniqueId)

                TriggerEvent('cs-boombox:onPlay', uniqueId, nil, {
                    ['url'] = data[uniqueId].media.url,
                    ['thumbnailUrl'] = data[uniqueId].media.thumbnailUrl,
                    ['thumbnailTitle'] = data[uniqueId].media.thumbnailTitle,
                    ['title'] = data[uniqueId].media.title,
                    ['icon'] = data[uniqueId].media.icon
                })

                SyncQueue(uniqueId)
            else
                TriggerEvent('cs-boombox:onStop', uniqueId, nil, {
                    ['url'] = data[uniqueId].media.url,
                    ['thumbnailUrl'] = data[uniqueId].media.thumbnailUrl,
                    ['thumbnailTitle'] = data[uniqueId].media.thumbnailTitle,
                    ['title'] = data[uniqueId].media.title,
                    ['icon'] = data[uniqueId].media.icon
                })

                data[uniqueId].media.url = nil
                data[uniqueId].media.thumbnailUrl = nil
                data[uniqueId].media.thumbnailTitle = nil
                data[uniqueId].media.title = nil
                data[uniqueId].media.icon = nil
                data[uniqueId].media.playing = false
                data[uniqueId].media.stopped = true
                data[uniqueId].media.time = 0
                data[uniqueId].media.duration = nil
            end
        end

        SyncData(uniqueId, nil, {
            ['force'] = true
        })
    end
end)

RegisterNetEvent('cs-boombox:enteredSyncUniqueId', function(uniqueId, model)
    local source = source

    if (not config.models[model].enabled) then
        return
    end

    if (not data[uniqueId]) then
        data[uniqueId] = {
            ['media'] = {
                ['playing'] = false,
                ['stopped'] = true,
                ['time'] = 0,
                ['volume'] = config.models[model].maxVolumePercent and 0.5 > (config.models[model].maxVolumePercent / 100) and (config.models[model].maxVolumePercent / 100) or 0.5,
                ['loop'] = false,
                ['url'] = nil,
                ['thumbnailUrl'] = nil,
                ['thumbnailTitle'] = nil,
                ['title'] = nil,
                ['icon'] = nil,
                ['duration'] = nil
            },

            ['updater'] = nil,
            ['controller'] = nil,
            ['syncedPlayers'] = 0,
            ['config'] = config.models[model]
        }
    end

    if (not players[source]) then
        players[source] = {}
    end

    if (data[uniqueId] and (not Contains(uniqueId, players[source]))) then
        table.insert(players[source], uniqueId)

        data[uniqueId].syncedPlayers = data[uniqueId].syncedPlayers + 1

        if (not data[uniqueId].updater) then
            RefreshCurrentUpdater(uniqueId)
        end

        SyncQueue(uniqueId, source)

        SyncData(uniqueId, source, {
            ['force'] = true,
            ['entered'] = true
        })
    end
end)

RegisterNetEvent('cs-boombox:leftSyncUniqueId', function(uniqueId)
    local source = source

    if (data[uniqueId] and players[source] and Contains(uniqueId, players[source])) then
        for i = 1, #players[source] do
            if (players[source][i] == uniqueId) then
                table.remove(players[source], i)
                break
            end
        end

        if (data[uniqueId].controller == source) then
            ClearController(uniqueId)
        end

        if (data[uniqueId].updater == source) then
            RefreshCurrentUpdater(uniqueId)
        end

        data[uniqueId].syncedPlayers = data[uniqueId].syncedPlayers - 1

        if (data[uniqueId].syncedPlayers <= 0) then
            ObjectNoLongerSyncable(uniqueId)
            data[uniqueId] = nil
            queue[uniqueId] = nil
        end
    end
end)

RegisterNetEvent('cs-boombox:resync', function(uniqueId, force)
    local source = source

    if (data[uniqueId] and Contains(uniqueId, players[source])) then
        SyncData(uniqueId, source, {
            ['force'] = force,
            ['resync'] = true
        })
    end
end)

RegisterNetEvent('cs-boombox:ui', function(uniqueId)
    local source = source

    if (data[uniqueId] and IsAllowedToControl(uniqueId, source)) then
        if (not data[uniqueId].updater) then
            RefreshCurrentUpdater(uniqueId)
        end
        
        SyncQueue(uniqueId)
        SyncData(uniqueId)
    end
end)

RegisterNetEvent('cs-boombox:server', function(uniqueId)
    local source = source
    TriggerClientEvent('cs-boombox:client', source)
end)

RegisterNetEvent('cs-boombox:fetch', function(uniqueId)
    local source = source
    TriggerClientEvent('cs-boombox:params', source, config.duiUrl, GetResourceMetadata(GetCurrentResourceName(), 'version', 0))
end)

AddEventHandler('cs-boombox:toggleControllerInterface', function(source, uniqueId)
    if ((not players[source]) or (not Contains(uniqueId, players[source]))) then
        return
    end

    controllers[source] = uniqueId
    TriggerClientEvent('cs-boombox:cui', source, uniqueId, false)
end)

AddEventHandler('cs-boombox:disallowControllerInterface', function(source, uniqueId)
    if ((not players[source]) or (not Contains(uniqueId, players[source]))) then
        return
    end

    controllers[source] = nil

    TriggerClientEvent('cs-boombox:cui', source, uniqueId, true)
end)

AddEventHandler('playerDropped', function(reason)
    for k, v in pairs(data) do
        if (data[k].controller == source) then
            ClearController(k)
        end

        if (data[k].updater == source) then
            RefreshCurrentUpdater(k)
        end

        if (players[source]) then
            for i = 1, #players[source] do
                if (players[source][i] == k) then
                    data[k].syncedPlayers = data[k].syncedPlayers - 1

                    if (data[k].syncedPlayers <= 0) then
                        ObjectNoLongerSyncable(k)
                        data[k] = nil
                        queue[k] = nil
                    end
                end
            end
        end
    end

    controllers[source] = nil
    players[source] = nil
end)

CreateThread(function()
    while (true) do
        for k, v in pairs(data) do
            if (data[k] and data[k].media.playing) then
                data[k].media.time = data[k].media.time + 1

                if (data[k].media.duration and data[k].media.duration > 0 and data[k].media.time > (data[k].media.duration + 15)) then
                    data[k].media.playing = false
                    data[k].media.stopped = true
                    data[k].media.time = 0
    
                    if (#queue[k] > 0) then
                        local q = queue[k][1]

                        table.remove(queue[k], 1)

                        if (data[k].media.url ~= q.url) then
                            data[k].media.duration = q.duration
                        end

                        data[k].media.url = q.url
                        data[k].media.thumbnailUrl = q.thumbnailUrl
                        data[k].media.thumbnailTitle = q.thumbnailTitle
                        data[k].media.title = q.title
                        data[k].media.icon = q.icon

                        TouchSyncableObject(k)

                        TriggerEvent('cs-boombox:onPlay', k, nil, {
                            ['url'] = data[k].media.url,
                            ['thumbnailUrl'] = data[k].media.thumbnailUrl,
                            ['thumbnailTitle'] = data[k].media.thumbnailTitle,
                            ['title'] = data[k].media.title,
                            ['icon'] = data[k].media.icon
                        })
                    else
                        TriggerEvent('cs-boombox:onStop', k, nil, {
                            ['url'] = data[k].media.url,
                            ['thumbnailUrl'] = data[k].media.thumbnailUrl,
                            ['thumbnailTitle'] = data[k].media.thumbnailTitle,
                            ['title'] = data[k].media.title,
                            ['icon'] = data[k].media.icon
                        })
    
                        data[k].media.url = nil
                        data[k].media.thumbnailUrl = nil
                        data[k].media.thumbnailTitle = nil
                        data[k].media.title = nil
                        data[k].media.icon = nil
                        data[k].media.duration = nil
                    end
    
                    SyncQueue(k)
    
                    SyncData(k, nil, {
                        ['force'] = true
                    })
                end
            end
        end

        Wait(1000)
    end
end)

CreateThread(function()
    while (true) do
        local timeNow = GetGameTimer()

        for k, v in pairs(syncableObjects) do
            if ((not data[k].media.playing) and timeNow - v > 180000) then
                ObjectNoLongerSyncable(k) 
            end
        end

        Wait(5000)
    end
end)

TriggerClientEvent('cs-boombox:client', -1)
TriggerClientEvent('cs-boombox:params', -1, config.duiUrl, GetResourceMetadata(GetCurrentResourceName(), 'version', 0))

exports('Play', function(uniqueId)
    if (not data[uniqueId]) then
        error('[cs-boombox] export Play: Unknown uniqueId provided.')
        return
    end

    local force = false

    if ((#queue[uniqueId] > 0) and (not data[uniqueId].media.url)) then
        local q = queue[uniqueId][1]

        table.remove(queue[uniqueId], 1)

        if (data[uniqueId].media.url ~= q.url) then
            data[uniqueId].media.duration = q.duration
        end

        data[uniqueId].media.url = q.url
        data[uniqueId].media.thumbnailUrl = q.thumbnailUrl
        data[uniqueId].media.thumbnailTitle = q.thumbnailTitle
        data[uniqueId].media.title = q.title
        data[uniqueId].media.icon = q.icon
        data[uniqueId].media.time = 0

        force = true
    end

    if (data[uniqueId].media.url and (not data[uniqueId].media.playing)) then
        data[uniqueId].media.playing = true
        data[uniqueId].media.stopped = false
    end

    TouchSyncableObject(uniqueId)

    TriggerEvent('cs-boombox:onPlay', uniqueId, nil, {
        ['url'] = data[uniqueId].media.url,
        ['thumbnailUrl'] = data[uniqueId].media.thumbnailUrl,
        ['thumbnailTitle'] = data[uniqueId].media.thumbnailTitle,
        ['title'] = data[uniqueId].media.title,
        ['icon'] = data[uniqueId].media.icon
    })

    SyncQueue(uniqueId)

    SyncData(uniqueId, nil, {
        ['force'] = force
    })
end)

exports('Pause', function(uniqueId)
    if (not data[uniqueId]) then
        error('[cs-boombox] export Pause: Unknown uniqueId provided.')
        return
    end

    if (data[uniqueId].media.playing) then
        data[uniqueId].media.playing = false
    end

    TriggerEvent('cs-boombox:onPause', uniqueId, source, {
        ['url'] = data[uniqueId].media.url,
        ['thumbnailUrl'] = data[uniqueId].media.thumbnailUrl,
        ['thumbnailTitle'] = data[uniqueId].media.thumbnailTitle,
        ['title'] = data[uniqueId].media.title,
        ['icon'] = data[uniqueId].media.icon
    })

    SyncData(uniqueId)
end)

exports('Stop', function(uniqueId)
    if (not data[uniqueId]) then
        error('[cs-boombox] export Stop: Unknown uniqueId provided.')
        return
    end

    if (data[uniqueId].media.playing) then
        TriggerEvent('cs-boombox:onStop', uniqueId, source, {
            ['url'] = data[uniqueId].media.url,
            ['thumbnailUrl'] = data[uniqueId].media.thumbnailUrl,
            ['thumbnailTitle'] = data[uniqueId].media.thumbnailTitle,
            ['title'] = data[uniqueId].media.title,
            ['icon'] = data[uniqueId].media.icon
        })
    end

    data[uniqueId].media.playing = false
    data[uniqueId].media.stopped = true
    data[uniqueId].media.time = 0
    data[uniqueId].media.duration = nil

    SyncData(uniqueId, nil, {
        ['force'] = true
    })
end)

exports('IsPlaying', function(uniqueId)
    if (not data[uniqueId]) then
        error('[cs-boombox] export IsPlaying: Unknown uniqueId provided.')
        return
    end

    return data[uniqueId].media.playing
end)

exports('SetLoop', function(uniqueId, state)
    if (not data[uniqueId]) then
        error('[cs-boombox] export SetLoop: Unknown uniqueId provided.')
        return
    end

    data[uniqueId].media.loop = state

    SyncData(uniqueId)
end)

exports('AddToQueue', function(uniqueId, url, thumbnailUrl, thumbnailTitle, title, icon, duration)
    if (not data[uniqueId]) then
        error('[cs-boombox] export AddToQueue: Unknown uniqueId provided.')
        return
    end

    table.insert(queue[uniqueId], {
        ['url'] = url,
        ['thumbnailUrl'] = thumbnailUrl,
        ['thumbnailTitle'] = thumbnailTitle,
        ['title'] = title,
        ['icon'] = icon,
        ['duration'] = duration,
        ['manual'] = false
    })

    TriggerEvent('cs-boombox:onEntryQueued', uniqueId, source, {
        ['url'] = url,
        ['thumbnailUrl'] = thumbnailUrl,
        ['thumbnailTitle'] = thumbnailTitle,
        ['title'] = title,
        ['icon'] = icon,
        ['position'] = #queue[uniqueId],
        ['duration'] = duration,
        ['manual'] = false
    })

    SyncQueue(uniqueId)
end)

exports('QueueNow', function(uniqueId, position)
    if (not data[uniqueId]) then
        error('[cs-boombox] export QueueNow: Unknown uniqueId provided.')
        return
    end

    if (queue[uniqueId][position]) then
        local q = queue[uniqueId][position]

        table.remove(queue[uniqueId], position)

        if (data[uniqueId].media.url ~= q.url) then
            data[uniqueId].media.duration = q.duration
        end

        data[uniqueId].media.url = q.url
        data[uniqueId].media.thumbnailUrl = q.thumbnailUrl
        data[uniqueId].media.thumbnailTitle = q.thumbnailTitle
        data[uniqueId].media.title = q.title
        data[uniqueId].media.icon = q.icon
        data[uniqueId].media.time = 0

        if (data[uniqueId].media.playing) then
            TouchSyncableObject(uniqueId)

            TriggerEvent('cs-boombox:onPlay', uniqueId, source, {
                ['url'] = data[uniqueId].media.url,
                ['thumbnailUrl'] = data[uniqueId].media.thumbnailUrl,
                ['thumbnailTitle'] = data[uniqueId].media.thumbnailTitle,
                ['title'] = data[uniqueId].media.title,
                ['icon'] = data[uniqueId].media.icon
            })
        end
    end

    SyncQueue(uniqueId)

    SyncData(uniqueId, nil, {
        ['force'] = true
    })
end)

exports('RemoveFromQueue', function(uniqueId, position)
    if (not data[uniqueId]) then
        error('[cs-boombox] export RemoveFromQueue: Unknown uniqueId provided.')
        return
    end
    
    if (queue[uniqueId][position]) then
        local q = queue[uniqueId][position]

        TriggerEvent('cs-boombox:onEntryRemoved', uniqueId, source, {
            ['url'] = q.url,
            ['thumbnailUrl'] = q.thumbnailUrl,
            ['thumbnailTitle'] = q.thumbnailTitle,
            ['title'] = q.title,
            ['icon'] = q.icon,
            ['position'] = position,
            ['manual'] = q.manual
        })

        table.remove(queue[uniqueId], position)
    end

    SyncQueue(uniqueId)
end)

exports('GetPlayer', function(uniqueId)
    if (not data[uniqueId]) then
        error('[cs-boombox] export GetPlayer: Unknown uniqueId provided.')
        return
    end

    return data[uniqueId].media
end)

exports('GetQueue', function(uniqueId)
    if (not data[uniqueId]) then
        error('[cs-boombox] export GetQueue: Unknown uniqueId provided.')
        return
    end
    
    return queue[uniqueId]
end)
