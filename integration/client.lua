-- Client-side checks and integration of how the boombox UI is accessed.
-- Here you can do any client-side check you want as well as change the way UI is accessed, what happens when it is and so on.
-- You can execute `TriggerEvent('cs-boombox:setUiAccessible', boolean)` to set whether the UI is accessible (client-side), if the UI is open it will be closed and will not open again until its accessible again.

local uiAccessible = false
local cesReady = false
local lastAccessedUUID = nil

function CanAccessControllerInterface()
    local uuid = nil -- TODO: Get UUID of closest boombox. (Temporary)
    return (not lastAccessedUUID or uuid == lastAccessedUUID) and not IsEntityDead(PlayerPedId())
end

RegisterCommand('boombox', function ()
    local uuid = nil -- TODO: Get UUID of closest boombox or create a UUID for the closest boombox and open the UI for it. (Temporary)

    if (uiAccessible and uuid) then
        lastAccessedUUID = uuid
        TriggerServerEvent('cs-boombox:integration:toggleControllerInterface', uuid, model) -- TODO: Model: the config entry's key.
    else
        lastAccessedUUID = nil
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
                lastAccessedUUID = nil
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
