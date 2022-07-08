if (not config) then
    error('[criticalscripts.shop] cs-boombox configuration file has a syntax error, please resolve it otherwise the resource will not work.')
    return
end

if (config.updatesCheck) then
    local version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0)

    PerformHttpRequest('https://updates.criticalscripts.shop/cs-boombox', function(e, b, h)
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

function IsAllowedToUpdate(uuid, source)
    return data[uuid].updater == source
end

function IsAllowedToControl(uuid, source)
    return controllers[source] == uuid
end

function ClearController(uuid)
    if (data[uuid].controller and GetPlayerEndpoint(data[uuid].controller)) then
        TriggerClientEvent('cs-boombox:controller', data[uuid].controller, uuid, false)
    end

    data[uuid].controller = nil
end

function SetController(uuid, source)
    data[uuid].controller = source
    TriggerClientEvent('cs-boombox:controller', data[uuid].controller, uuid, true)
end

function RefreshCurrentUpdater(uuid)
    if (data[uuid].updater and GetPlayerEndpoint(data[uuid].updater)) then
        TriggerClientEvent('cs-boombox:updater', data[uuid].updater, uuid, false)
    end

    data[uuid].updater = nil
 
    if (data[uuid].controller and players[data[uuid].controller] and Contains(uuid, players[data[uuid].controller])) then
        data[uuid].updater = data[uuid].controller
    else
        for k, v in pairs(players) do
            if (Contains(uuid, v)) then
                data[uuid].updater = k
                break
            end
        end
    end

    if (data[uuid].updater) then
        TriggerClientEvent('cs-boombox:updater', data[uuid].updater, uuid, true)
    end
end

function SyncQueue(uuid, target, temp)
    if (not queue[uuid]) then
        queue[uuid] = {}
    end

    if (target) then
        TriggerClientEvent('cs-boombox:queue', target, uuid, queue[uuid])
    else
        for k, v in pairs(players) do
            if (Contains(uuid, v)) then
                TriggerClientEvent('cs-boombox:queue', k, uuid, queue[uuid])
            end
        end
    end
end

function SyncData(uuid, target, temp)
    if (target) then
        TriggerClientEvent('cs-boombox:sync', target, uuid, data[uuid], temp or {})
    else
        for k, v in pairs(players) do
            if (Contains(uuid, v)) then
                TriggerClientEvent('cs-boombox:sync', k, uuid, data[uuid], temp or {})
            end
        end
    end
end

function AdjustTime(uuid)
    for k, v in pairs(players) do
        if (Contains(uuid, v)) then
            TriggerClientEvent('cs-boombox:adjust', k, data[uuid].time)
        end
    end
end

RegisterNetEvent('cs-boombox:play', function(uuid, uiOpen)
    local source = source

    if (data[uuid] and IsAllowedToControl(uuid, source)) then
        SetController(uuid, source)

        if (data[uuid].updater ~= data[uuid].controller) then
            RefreshCurrentUpdater(uuid)
        end

        local force = false

        if ((#queue[uuid] > 0) and (not data[uuid].media.url)) then
            local q = queue[uuid][1]

            table.remove(queue[uuid], 1)

            if (data[uuid].media.url ~= q.url) then
                data[uuid].media.duration = q.duration
            end

            data[uuid].media.url = q.url
            data[uuid].media.thumbnailUrl = q.thumbnailUrl
            data[uuid].media.thumbnailTitle = q.thumbnailTitle
            data[uuid].media.title = q.title
            data[uuid].media.icon = q.icon
            data[uuid].media.time = 0

            force = true
        end

        if (data[uuid].media.url and (not data[uuid].media.playing)) then
            data[uuid].media.playing = true
            data[uuid].media.stopped = false
        end

        TriggerEvent('cs-boombox:onPlay', uuid, source, {
            ['url'] = data[uuid].media.url,
            ['thumbnailUrl'] = data[uuid].media.thumbnailUrl,
            ['thumbnailTitle'] = data[uuid].media.thumbnailTitle,
            ['title'] = data[uuid].media.title,
            ['icon'] = data[uuid].media.icon
        })

        SyncQueue(uuid)

        SyncData(uuid, nil, {
            ['force'] = force
        })
    end
end)

RegisterNetEvent('cs-boombox:pause', function(uuid, uiOpen)
    local source = source

    if (data[uuid] and IsAllowedToControl(uuid, source)) then
        SetController(uuid, source)

        if (data[uuid].updater ~= data[uuid].controller) then
            RefreshCurrentUpdater(uuid)
        end

        if (data[uuid].media.playing) then
            data[uuid].media.playing = false
        end

        TriggerEvent('cs-boombox:onPause', uuid, source, {
            ['url'] = data[uuid].media.url,
            ['thumbnailUrl'] = data[uuid].media.thumbnailUrl,
            ['thumbnailTitle'] = data[uuid].media.thumbnailTitle,
            ['title'] = data[uuid].media.title,
            ['icon'] = data[uuid].media.icon
        })

        SyncData(uuid)
    end
end)

RegisterNetEvent('cs-boombox:stop', function(uuid, uiOpen)
    local source = source

    if (data[uuid] and IsAllowedToControl(uuid, source)) then
        SetController(uuid, source)

        if (data[uuid].updater ~= data[uuid].controller) then
            RefreshCurrentUpdater(uuid)
        end

        if (data[uuid].media.playing) then
            TriggerEvent('cs-boombox:onStop', uuid, source, {
                ['url'] = data[uuid].media.url,
                ['thumbnailUrl'] = data[uuid].media.thumbnailUrl,
                ['thumbnailTitle'] = data[uuid].media.thumbnailTitle,
                ['title'] = data[uuid].media.title,
                ['icon'] = data[uuid].media.icon
            })
        end

        data[uuid].media.playing = false
        data[uuid].media.stopped = true
        data[uuid].media.time = 0
        data[uuid].media.duration = nil

        SyncData(uuid, nil, {
            ['force'] = true
        })
    end
end)

RegisterNetEvent('cs-boombox:seek', function(uuid, time)
    local source = source

    if (data[uuid] and IsAllowedToControl(uuid, source)) then
        if (data[uuid].media.duration and data[uuid].media.duration > 0) then
            SetController(uuid, source)
    
            if (data[uuid].updater ~= data[uuid].controller) then
                RefreshCurrentUpdater(uuid)
            end
    
            if (data[uuid].media.url) then
                data[uuid].media.time = time
    
                SyncData(uuid, nil, {
                    ['media'] = {
                        ['seek'] = true
                    }
                })

                return
            end
        end

        SyncData(uuid)
    end
end)

RegisterNetEvent('cs-boombox:changeVolume', function(uuid, volume)
    local source = source

    if (data[uuid] and IsAllowedToControl(uuid, source)) then
        SetController(uuid, source)

        if (data[uuid].updater ~= data[uuid].controller) then
            RefreshCurrentUpdater(uuid)
        end

        if ((not data[uuid].config.maxVolumePercent) or data[uuid].config.maxVolumePercent >= volume) then
            data[uuid].media.volume = volume / 100
        else
            data[uuid].media.volume = data[uuid].config.maxVolumePercent / 100
        end

        SyncData(uuid)
    end
end)

RegisterNetEvent('cs-boombox:toggleLoop', function(uuid)
    local source = source

    if (data[uuid] and IsAllowedToControl(uuid, source)) then
        SetController(uuid, source)

        if (data[uuid].updater ~= data[uuid].controller) then
            RefreshCurrentUpdater(uuid)
        end

        data[uuid].media.loop = not data[uuid].media.loop

        SyncData(uuid)
    end
end)

RegisterNetEvent('cs-boombox:addToQueue', function(uuid, url, thumbnailUrl, thumbnailTitle, title, icon)
    local source = source

    if (data[uuid] and IsAllowedToControl(uuid, source)) then
        if ((not StartsWith(url, 'https://www.youtube.com/')) and (not StartsWith(url, 'https://www.twitch.tv/')) and (not StartsWith(url, 'https://clips.twitch.tv/'))) then
            return
        end

        SetController(uuid, source)

        if (data[uuid].updater ~= data[uuid].controller) then
            RefreshCurrentUpdater(uuid)
        end

        table.insert(queue[uuid], {
            ['url'] = url,
            ['thumbnailUrl'] = thumbnailUrl,
            ['thumbnailTitle'] = thumbnailTitle,
            ['title'] = title,
            ['icon'] = icon,
            ['duration'] = nil,
            ['manual'] = true
        })

        TriggerEvent('cs-boombox:onEntryQueued', uuid, source, {
            ['url'] = url,
            ['thumbnailUrl'] = thumbnailUrl,
            ['thumbnailTitle'] = thumbnailTitle,
            ['title'] = title,
            ['icon'] = icon,
            ['position'] = #queue[uuid],
            ['duration'] = nil,
            ['manual'] = true
        })

        SyncQueue(uuid)
    end
end)

RegisterNetEvent('cs-boombox:nextQueueSong', function(uuid, uiOpen)
    local source = source

    if (data[uuid] and IsAllowedToControl(uuid, source)) then
        SetController(uuid, source)

        if (data[uuid].updater ~= data[uuid].controller) then
            RefreshCurrentUpdater(uuid)
        end

        if (#queue[uuid] > 0) then
            local q = queue[uuid][1]

            table.remove(queue[uuid], 1)

            if (data[uuid].media.url ~= q.url) then
                data[uuid].media.duration = q.duration
            end

            data[uuid].media.url = q.url
            data[uuid].media.thumbnailUrl = q.thumbnailUrl
            data[uuid].media.thumbnailTitle = q.thumbnailTitle
            data[uuid].media.title = q.title
            data[uuid].media.icon = q.icon
            data[uuid].media.time = 0

            TriggerEvent('cs-boombox:onPlay', uuid, source, {
                ['url'] = data[uuid].media.url,
                ['thumbnailUrl'] = data[uuid].media.thumbnailUrl,
                ['thumbnailTitle'] = data[uuid].media.thumbnailTitle,
                ['title'] = data[uuid].media.title,
                ['icon'] = data[uuid].media.icon
            })
        else
            if (data[uuid].media.playing) then
                TriggerEvent('cs-boombox:onStop', uuid, source, {
                    ['url'] = data[uuid].media.url,
                    ['thumbnailUrl'] = data[uuid].media.thumbnailUrl,
                    ['thumbnailTitle'] = data[uuid].media.thumbnailTitle,
                    ['title'] = data[uuid].media.title,
                    ['icon'] = data[uuid].media.icon
                })
            end

            data[uuid].media.url = nil
            data[uuid].media.thumbnailUrl = nil
            data[uuid].media.thumbnailTitle = nil
            data[uuid].media.title = nil
            data[uuid].media.icon = nil
            data[uuid].media.playing = false
            data[uuid].media.stopped = true
            data[uuid].media.time = 0
            data[uuid].media.duration = nil
        end

        SyncQueue(uuid)

        SyncData(uuid, nil, {
            ['force'] = true
        })
    end
end)

RegisterNetEvent('cs-boombox:queueNow', function(uuid, index)
    local source = source

    if (data[uuid] and IsAllowedToControl(uuid, source)) then
        SetController(uuid, source)

        if (data[uuid].updater ~= data[uuid].controller) then
            RefreshCurrentUpdater(uuid)
        end

        if (queue[uuid][index]) then
            local q = queue[uuid][index]

            table.remove(queue[uuid], index)

            if (data[uuid].media.url ~= q.url) then
                data[uuid].media.duration = q.duration
            end

            data[uuid].media.url = q.url
            data[uuid].media.thumbnailUrl = q.thumbnailUrl
            data[uuid].media.thumbnailTitle = q.thumbnailTitle
            data[uuid].media.title = q.title
            data[uuid].media.icon = q.icon
            data[uuid].media.time = 0

            if (data[uuid].media.playing) then
                TriggerEvent('cs-boombox:onPlay', uuid, source, {
                    ['url'] = data[uuid].media.url,
                    ['thumbnailUrl'] = data[uuid].media.thumbnailUrl,
                    ['thumbnailTitle'] = data[uuid].media.thumbnailTitle,
                    ['title'] = data[uuid].media.title,
                    ['icon'] = data[uuid].media.icon
                })
            end
        end

        SyncQueue(uuid)

        SyncData(uuid, nil, {
            ['force'] = true
        })
    end
end)

RegisterNetEvent('cs-boombox:queueNext', function(uuid, index)
    local source = source

    if (data[uuid] and IsAllowedToControl(uuid, source)) then
        SetController(uuid, source)

        if (data[uuid].updater ~= data[uuid].controller) then
            RefreshCurrentUpdater(uuid)
        end

        if (queue[uuid][index]) then
            local q = queue[uuid][index]

            table.insert(queue[uuid], 1, q)
            table.remove(queue[uuid], index)
        end

        SyncQueue(uuid)
    end
end)

RegisterNetEvent('cs-boombox:queueRemove', function(uuid, index)
    local source = source

    if (data[uuid] and IsAllowedToControl(uuid, source)) then
        SetController(uuid, source)

        if (data[uuid].updater ~= data[uuid].controller) then
            RefreshCurrentUpdater(uuid)
        end

        if (queue[uuid][index]) then
            TriggerEvent('cs-boombox:onEntryRemoved', uuid, source, {
                ['url'] = queue[uuid][index].url,
                ['thumbnailUrl'] = queue[uuid][index].thumbnailUrl,
                ['thumbnailTitle'] = queue[uuid][index].thumbnailTitle,
                ['title'] = queue[uuid][index].title,
                ['icon'] = queue[uuid][index].icon,
                ['position'] = index,
                ['manual'] = queue[uuid][index].manual
            })

            table.remove(queue[uuid], index)
        end

        SyncQueue(uuid)
    end
end)

RegisterNetEvent('cs-boombox:duration', function(uuid, duration)
    local source = source

    if (data[uuid] and IsAllowedToUpdate(uuid, source) and data[uuid].media.playing) then
        data[uuid].media.duration = duration
        TriggerEvent('cs-boombox:onDuration', uuid, source, duration)
    end
end)

RegisterNetEvent('cs-boombox:time', function(uuid, time, force)
    local source = source

    if (data[uuid] and time and IsAllowedToUpdate(uuid, source) and (data[uuid].media.playing or force)) then
        data[uuid].media.time = time
    end
end)

RegisterNetEvent('cs-boombox:controllerEnded', function(uuid)
    local source = source

    if (data[uuid] and IsAllowedToUpdate(uuid, source)) then
        if (data[uuid].media.playing) then
            if (data[uuid].media.loop) then
                data[uuid].media.time = 0

                TriggerEvent('cs-boombox:onPlay', uuid, nil, {
                    ['url'] = data[uuid].media.url,
                    ['thumbnailUrl'] = data[uuid].media.thumbnailUrl,
                    ['thumbnailTitle'] = data[uuid].media.thumbnailTitle,
                    ['title'] = data[uuid].media.title,
                    ['icon'] = data[uuid].media.icon
                })
            elseif (#queue[uuid] > 0) then
                local q = queue[uuid][1]
    
                table.remove(queue[uuid], 1)

                if (data[uuid].media.url ~= q.url) then
                    data[uuid].media.duration = q.duration
                end
    
                data[uuid].media.url = q.url
                data[uuid].media.thumbnailUrl = q.thumbnailUrl
                data[uuid].media.thumbnailTitle = q.thumbnailTitle
                data[uuid].media.title = q.title
                data[uuid].media.icon = q.icon
                data[uuid].media.time = 0

                TriggerEvent('cs-boombox:onPlay', uuid, nil, {
                    ['url'] = data[uuid].media.url,
                    ['thumbnailUrl'] = data[uuid].media.thumbnailUrl,
                    ['thumbnailTitle'] = data[uuid].media.thumbnailTitle,
                    ['title'] = data[uuid].media.title,
                    ['icon'] = data[uuid].media.icon
                })

                SyncQueue(uuid)
            else
                TriggerEvent('cs-boombox:onStop', uuid, nil, {
                    ['url'] = data[uuid].media.url,
                    ['thumbnailUrl'] = data[uuid].media.thumbnailUrl,
                    ['thumbnailTitle'] = data[uuid].media.thumbnailTitle,
                    ['title'] = data[uuid].media.title,
                    ['icon'] = data[uuid].media.icon
                })

                data[uuid].media.url = nil
                data[uuid].media.thumbnailUrl = nil
                data[uuid].media.thumbnailTitle = nil
                data[uuid].media.title = nil
                data[uuid].media.icon = nil
                data[uuid].media.playing = false
                data[uuid].media.stopped = true
                data[uuid].media.time = 0
                data[uuid].media.duration = nil
            end

            SyncData(uuid, nil, {
                ['force'] = true
            })
        end
    end
end)

RegisterNetEvent('cs-boombox:controllerError', function(uuid)
    local source = source

    if (data[uuid] and IsAllowedToUpdate(uuid, source)) then
        if (data[uuid].media.playing) then
            if (#queue[uuid] > 0) then
                local q = queue[uuid][1]
    
                table.remove(queue[uuid], 1)

                if (data[uuid].media.url ~= q.url) then
                    data[uuid].media.duration = q.duration
                end
    
                data[uuid].media.url = q.url
                data[uuid].media.thumbnailUrl = q.thumbnailUrl
                data[uuid].media.thumbnailTitle = q.thumbnailTitle
                data[uuid].media.title = q.title
                data[uuid].media.icon = q.icon
                data[uuid].media.time = 0

                TriggerEvent('cs-boombox:onPlay', uuid, nil, {
                    ['url'] = data[uuid].media.url,
                    ['thumbnailUrl'] = data[uuid].media.thumbnailUrl,
                    ['thumbnailTitle'] = data[uuid].media.thumbnailTitle,
                    ['title'] = data[uuid].media.title,
                    ['icon'] = data[uuid].media.icon
                })

                SyncQueue(uuid)
            else
                TriggerEvent('cs-boombox:onStop', uuid, nil, {
                    ['url'] = data[uuid].media.url,
                    ['thumbnailUrl'] = data[uuid].media.thumbnailUrl,
                    ['thumbnailTitle'] = data[uuid].media.thumbnailTitle,
                    ['title'] = data[uuid].media.title,
                    ['icon'] = data[uuid].media.icon
                })

                data[uuid].media.url = nil
                data[uuid].media.thumbnailUrl = nil
                data[uuid].media.thumbnailTitle = nil
                data[uuid].media.title = nil
                data[uuid].media.icon = nil
                data[uuid].media.playing = false
                data[uuid].media.stopped = true
                data[uuid].media.time = 0
                data[uuid].media.duration = nil
            end
        end

        SyncData(uuid, nil, {
            ['force'] = true
        })
    end
end)

RegisterNetEvent('cs-boombox:enteredSyncUUID', function(uuid, model)
    local source = source

    if (not config.models[model].enabled) then
        return
    end

    if (not data[uuid]) then
        data[uuid] = {
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

    if (data[uuid] and (not Contains(uuid, players[source]))) then
        table.insert(players[source], uuid)

        data[uuid].syncedPlayers = data[uuid].syncedPlayers + 1

        if (not data[uuid].updater) then
            RefreshCurrentUpdater(uuid)
        end

        SyncQueue(uuid, source)

        SyncData(uuid, source, {
            ['force'] = true,
            ['entered'] = true
        })
    end
end)

RegisterNetEvent('cs-boombox:leftSyncUUID', function(uuid)
    local source = source

    if (data[uuid] and players[source] and Contains(uuid, players[source])) then
        for i = 1, #players[source] do
            if (players[source][i] == uuid) then
                table.remove(players[source], i)
                break
            end
        end

        if (data[uuid].controller == source) then
            ClearController(uuid)
        end

        if (data[uuid].updater == source) then
            RefreshCurrentUpdater(uuid)
        end

        data[uuid].syncedPlayers = data[uuid].syncedPlayers - 1

        if (data[uuid].syncedPlayers <= 0) then
            data[uuid] = nil
            queue[uuid] = nil
        end
    end
end)

RegisterNetEvent('cs-boombox:resync', function(uuid, force)
    local source = source

    if (data[uuid] and Contains(uuid, players[source])) then
        SyncData(uuid, source, {
            ['force'] = force,
            ['resync'] = true
        })
    end
end)

RegisterNetEvent('cs-boombox:ui', function(uuid)
    local source = source

    if (data[uuid] and IsAllowedToControl(uuid, source)) then
        if (not data[uuid].updater) then
            RefreshCurrentUpdater(uuid)
        end
        
        SyncQueue(uuid)
        SyncData(uuid)
    end
end)

RegisterNetEvent('cs-boombox:server', function(uuid)
    local source = source
    TriggerClientEvent('cs-boombox:client', source)
end)

RegisterNetEvent('cs-boombox:fetch', function(uuid)
    local source = source
    TriggerClientEvent('cs-boombox:params', source, config.duiUrl, GetResourceMetadata(GetCurrentResourceName(), 'version', 0))
end)

AddEventHandler('cs-boombox:toggleControllerInterface', function(source, uuid)
    if ((not players[source]) or (not Contains(uuid, players[source]))) then
        return
    end

    controllers[source] = uuid

    TriggerClientEvent('cs-boombox:cui', source, uuid, false)
end)

AddEventHandler('cs-boombox:disallowControllerInterface', function(source, uuid)
    if ((not players[source]) or (not Contains(uuid, players[source]))) then
        return
    end

    controllers[source] = nil

    TriggerClientEvent('cs-boombox:cui', source, uuid, true)
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

TriggerClientEvent('cs-boombox:client', -1)
TriggerClientEvent('cs-boombox:params', -1, config.duiUrl, GetResourceMetadata(GetCurrentResourceName(), 'version', 0))

exports('Play', function(uuid)
    if (not data[uuid]) then
        error('[cs-boombox] export Play: Unknown uuid provided.')
        return
    end

    local force = false

    if ((#queue[uuid] > 0) and (not data[uuid].media.url)) then
        local q = queue[uuid][1]

        table.remove(queue[uuid], 1)

        if (data[uuid].media.url ~= q.url) then
            data[uuid].media.duration = q.duration
        end

        data[uuid].media.url = q.url
        data[uuid].media.thumbnailUrl = q.thumbnailUrl
        data[uuid].media.thumbnailTitle = q.thumbnailTitle
        data[uuid].media.title = q.title
        data[uuid].media.icon = q.icon
        data[uuid].media.time = 0

        force = true
    end

    if (data[uuid].media.url and (not data[uuid].media.playing)) then
        data[uuid].media.playing = true
        data[uuid].media.stopped = false
    end

    TriggerEvent('cs-boombox:onPlay', uuid, nil, {
        ['url'] = data[uuid].media.url,
        ['thumbnailUrl'] = data[uuid].media.thumbnailUrl,
        ['thumbnailTitle'] = data[uuid].media.thumbnailTitle,
        ['title'] = data[uuid].media.title,
        ['icon'] = data[uuid].media.icon
    })

    SyncQueue(uuid)

    SyncData(uuid, nil, {
        ['force'] = force
    })
end)

exports('Pause', function(uuid)
    if (not data[uuid]) then
        error('[cs-boombox] export Pause: Unknown uuid provided.')
        return
    end

    if (data[uuid].media.playing) then
        data[uuid].media.playing = false
    end

    TriggerEvent('cs-boombox:onPause', uuid, source, {
        ['url'] = data[uuid].media.url,
        ['thumbnailUrl'] = data[uuid].media.thumbnailUrl,
        ['thumbnailTitle'] = data[uuid].media.thumbnailTitle,
        ['title'] = data[uuid].media.title,
        ['icon'] = data[uuid].media.icon
    })

    SyncData(uuid)
end)

exports('Stop', function(uuid)
    if (not data[uuid]) then
        error('[cs-boombox] export Stop: Unknown uuid provided.')
        return
    end

    if (data[uuid].media.playing) then
        TriggerEvent('cs-boombox:onStop', uuid, source, {
            ['url'] = data[uuid].media.url,
            ['thumbnailUrl'] = data[uuid].media.thumbnailUrl,
            ['thumbnailTitle'] = data[uuid].media.thumbnailTitle,
            ['title'] = data[uuid].media.title,
            ['icon'] = data[uuid].media.icon
        })
    end

    data[uuid].media.playing = false
    data[uuid].media.stopped = true
    data[uuid].media.time = 0
    data[uuid].media.duration = nil

    SyncData(uuid, nil, {
        ['force'] = true
    })
end)

exports('IsPlaying', function(uuid)
    if (not data[uuid]) then
        error('[cs-boombox] export IsPlaying: Unknown uuid provided.')
        return
    end

    return data[uuid].media.playing
end)

exports('SetLoop', function(uuid, state)
    if (not data[uuid]) then
        error('[cs-boombox] export SetLoop: Unknown uuid provided.')
        return
    end

    data[uuid].media.loop = state

    SyncData(uuid)
end)

exports('AddToQueue', function(uuid, url, thumbnailUrl, thumbnailTitle, title, icon, duration)
    if (not data[uuid]) then
        error('[cs-boombox] export AddToQueue: Unknown uuid provided.')
        return
    end

    table.insert(queue[uuid], {
        ['url'] = url,
        ['thumbnailUrl'] = thumbnailUrl,
        ['thumbnailTitle'] = thumbnailTitle,
        ['title'] = title,
        ['icon'] = icon,
        ['duration'] = duration,
        ['manual'] = false
    })

    TriggerEvent('cs-boombox:onEntryQueued', uuid, source, {
        ['url'] = url,
        ['thumbnailUrl'] = thumbnailUrl,
        ['thumbnailTitle'] = thumbnailTitle,
        ['title'] = title,
        ['icon'] = icon,
        ['position'] = #queue[uuid],
        ['duration'] = duration,
        ['manual'] = false
    })

    SyncQueue(uuid)
end)

exports('QueueNow', function(uuid, position)
    if (not data[uuid]) then
        error('[cs-boombox] export QueueNow: Unknown uuid provided.')
        return
    end

    if (queue[uuid][position]) then
        local q = queue[uuid][position]

        table.remove(queue[uuid], position)

        if (data[uuid].media.url ~= q.url) then
            data[uuid].media.duration = q.duration
        end

        data[uuid].media.url = q.url
        data[uuid].media.thumbnailUrl = q.thumbnailUrl
        data[uuid].media.thumbnailTitle = q.thumbnailTitle
        data[uuid].media.title = q.title
        data[uuid].media.icon = q.icon
        data[uuid].media.time = 0

        if (data[uuid].media.playing) then
            TriggerEvent('cs-boombox:onPlay', uuid, source, {
                ['url'] = data[uuid].media.url,
                ['thumbnailUrl'] = data[uuid].media.thumbnailUrl,
                ['thumbnailTitle'] = data[uuid].media.thumbnailTitle,
                ['title'] = data[uuid].media.title,
                ['icon'] = data[uuid].media.icon
            })
        end
    end

    SyncQueue(uuid)

    SyncData(uuid, nil, {
        ['force'] = true
    })
end)

exports('RemoveFromQueue', function(uuid, position)
    if (not data[uuid]) then
        error('[cs-boombox] export RemoveFromQueue: Unknown uuid provided.')
        return
    end
    
    if (queue[uuid][position]) then
        local q = queue[uuid][position]

        TriggerEvent('cs-boombox:onEntryRemoved', uuid, source, {
            ['url'] = q.url,
            ['thumbnailUrl'] = q.thumbnailUrl,
            ['thumbnailTitle'] = q.thumbnailTitle,
            ['title'] = q.title,
            ['icon'] = q.icon,
            ['position'] = position,
            ['manual'] = q.manual
        })

        table.remove(queue[uuid], position)
    end

    SyncQueue(uuid)
end)

exports('GetPlayer', function(uuid)
    if (not data[uuid]) then
        error('[cs-boombox] export GetPlayer: Unknown uuid provided.')
        return
    end

    return data[uuid].media
end)

exports('GetQueue', function(uuid)
    if (not data[uuid]) then
        error('[cs-boombox] export GetQueue: Unknown uuid provided.')
        return
    end
    
    return queue[uuid]
end)
