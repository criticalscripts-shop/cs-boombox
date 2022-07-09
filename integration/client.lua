-- Client-side checks and integration of how the boombox UI is accessed.
-- Here you can do any client-side check you want as well as change the way UI is accessed, what happens when it is and so on.
-- You can execute `TriggerEvent('cs-boombox:setUiAccessible', boolean)` to set whether the UI is accessible (client-side), if the UI is open it will be closed and will not open again until its accessible again.

local uiAccessible = false
local cesReady = false
local lastAccessedUniqueId = nil

function CanAccessControllerInterface()
    local playerPed = PlayerPedId()
    return ((not lastAccessedObject) or (DoesEntityExist(lastAccessedObject) and #(GetEntityCoords(lastAccessedObject) - GetEntityCoords(playerPed)) <= 2.0)) and (not IsEntityDead(playerPed))
end

RegisterCommand('boombox', function()
    local closest = {}

    if (uiAccessible) then
        local playerCoords = GetEntityCoords(PlayerPedId())

        for object in EnumerateEntities(FindFirstObject, FindNextObject, EndFindObject) do
            if (DoesEntityExist(object) and (not HasObjectBeenBroken(object))) then
                local model = GetEntityModel(object)

                if (configHashToModel[model] and NetworkGetEntityIsNetworked(object)) then
                    local distance = #(GetEntityCoords(object) - playerCoords)

                    if (distance <= 2.0 and ((not closest.handle) or distance < closest.distance)) then
                        closest.handle = object
                        closest.model = configHashToModel[model]
                        closest.distance = distance
                        closest.uniqueId = tostring(NetworkGetNetworkIdFromEntity(object))
                    end
                end
            end
        end
    end

    if (closest.handle) then
        lastAccessedObject = closest.handle
        TriggerServerEvent('cs-boombox:integration:toggleControllerInterface', closest.uniqueId, closest.model)
    else
        lastAccessedObject = nil
    end
end)

RegisterKeyMapping('boombox', 'Open Interface', 'keyboard', '')

AddEventHandler('cs-boombox:ready', function()
    cesReady = true
end)

CreateThread(function()
    TriggerEvent('cs-boombox:integrationReady')

    while (true) do
        if (cesReady and CanAccessControllerInterface() ~= uiAccessible) then
            uiAccessible = not uiAccessible

            TriggerEvent('cs-boombox:setUiAccessible', uiAccessible)

            if (not uiAccessible) then
                lastAccessedObject = nil
            end
        end

        Wait(500)
    end
end)

-- Performing action animations.

local animDict = 'amb@world_human_seat_wall_tablet@female@idle_a'
local animName = 'idle_c'

AddEventHandler('cs-boombox:onControllerInterfaceOpen', function()
    local playerPed = PlayerPedId()

    if (not IsEntityPlayingAnim(playerPed, animDict, animName, 3)) then
        RequestAnimDict(animDict)

        while (not HasAnimDictLoaded(animDict)) do
            Wait(0)
        end
    
        TaskPlayAnim(playerPed, animDict, animName, 4.0, 4.0, -1, 49, 0, 0, 0, 0)
    end
end)

AddEventHandler('cs-boombox:onControllerInterfaceClose', function()
    local playerPed = PlayerPedId()

    if (IsEntityPlayingAnim(playerPed, animDict, animName, 3)) then
        StopAnimTask(playerPed, animDict, animName, 4.0)
        Wait(75)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if (GetCurrentServerEndpoint() == nil) then
        return
    end
    
    if (resource == GetCurrentResourceName()) then
        local playerPed = PlayerPedId()
    
        if (IsEntityPlayingAnim(playerPed, animDict, animName, 3)) then
            StopAnimTask(playerPed, animDict, animName, 4.0)
        end
    end
end)
