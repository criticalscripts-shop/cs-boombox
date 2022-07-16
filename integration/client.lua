-- Client-side checks and integration of how the boombox UI is accessed.
-- Here you can do any client-side check you want as well as change the way UI is accessed, what happens when it is and so on.
-- You can execute `TriggerEvent('cs-boombox:setUiAccessible', boolean)` to set whether the UI is accessible (client-side), if the UI is open it will be closed and will not open again until its accessible again.

local uiAccessible = false
local boomboxReady = false
local lastAccessedObject = nil
local lastAttachedObject = nil

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
    boomboxReady = true
end)

CreateThread(function()
    TriggerEvent('cs-boombox:integrationReady')

    while (true) do
        if (boomboxReady and CanAccessControllerInterface() ~= uiAccessible) then
            uiAccessible = not uiAccessible

            TriggerEvent('cs-boombox:setUiAccessible', uiAccessible)

            if (not uiAccessible) then
                if (lastAttachedObject) then
                    local playerPed = PlayerPedId()

                    StopAnimTask(playerPed, pickedUpAnimDict, pickedUpAnimName, 4.0)
                    DetachEntity(lastAttachedObject, false, true)
                    SetEntityCoords(lastAttachedObject, GetEntityCoords(playerPed) + (GetEntityForwardVector(playerPed) * 0.75))
                    PlaceObjectOnGroundProperly(lastAttachedObject)

                    lastAttachedObject = nil
                end

                lastAccessedObject = nil
            end
        end

        Wait(500)
    end
end)


-- Action Commands

local placeAnimDict = 'random@domestic'
local placeAnimName = 'pickup_low'

RegisterNetEvent('cs-boombox:create', function(model)
    if (lastAccessedObject) then
        return
    end

    local playerPed = PlayerPedId()
    local handle = GetClosestObjectOfType(GetEntityCoords(playerPed), 2.0, GetHashKey(model), false, false, false)

    if (handle > 0) then
        return
    end
    
    RequestAnimDict(placeAnimDict)

    while (not HasAnimDictLoaded(placeAnimDict)) do
        Wait(0)
    end

    TaskPlayAnim(playerPed, placeAnimDict, placeAnimName, 4.0, 4.0, -1, 0, 0, 0, 0, 0)

    Wait(750)

    local position = GetEntityCoords(playerPed) + (GetEntityForwardVector(playerPed) * 0.75)
    local rotation = vector3(0.0, 0.0, 0.0)
    local modelHash = GetHashKey(model)

    RequestModel(modelHash)

    while (not HasModelLoaded(modelHash)) do
        Wait(0)
    end

    StopAnimTask(playerPed, placeAnimDict, placeAnimName, 2.0)

    local object = CreateObject(modelHash, position, true, true, false)

    SetEntityCoords(object, position)
    SetEntityHeading(object, 0.0)
    PlaceObjectOnGroundProperly(object)
    FreezeEntityPosition(object, true)
end)

local pickedUpAnimDict = 'impexp_int-0'
local pickedUpAnimName = 'mp_m_waremech_01_dual-0'

RegisterNetEvent('cs-boombox:pickup', function(model)
    if (lastAccessedObject) then
        return
    end

    local playerPed = PlayerPedId()
    local handle = GetClosestObjectOfType(GetEntityCoords(playerPed), 2.0, GetHashKey(model), false, false, false)

    if (handle > 0 and (not HasObjectBeenBroken(handle)) and GetEntityAttachedTo(handle) == 0) then
        lastAttachedObject = handle

        RequestAnimDict(placeAnimDict)
    
        while (not HasAnimDictLoaded(placeAnimDict)) do
            Wait(0)
        end
    
        TaskPlayAnim(playerPed, placeAnimDict, placeAnimName, 4.0, 4.0, -1, 0, 0, 0, 0, 0)
    
        Wait(500)

        StopAnimTask(playerPed, placeAnimDict, placeAnimName, 2.0)
        AttachEntityToEntity(handle, playerPed, GetPedBoneIndex(playerPed, 24817), 0.0, 0.46, -0.016, -180.0, -90.0, 0.0, true, true, false, true, 1, true)

        if (not IsEntityPlayingAnim(playerPed, pickedUpAnimDict, pickedUpAnimName, 3)) then
            RequestAnimDict(pickedUpAnimDict)

            while (not HasAnimDictLoaded(pickedUpAnimDict)) do
                Wait(0)
            end
        
            TaskPlayAnim(playerPed, pickedUpAnimDict, pickedUpAnimName, 4.0, 4.0, -1, 51, 0, 0, 0, 0)
        end
    end
end)

RegisterNetEvent('cs-boombox:drop', function(model)
    local playerPed = PlayerPedId()
    local handle = GetClosestObjectOfType(GetEntityCoords(playerPed), 2.0, GetHashKey(model), false, false, false)

    if (handle > 0 and GetEntityAttachedTo(handle) == playerPed) then
        lastAttachedObject = nil

        RequestAnimDict(placeAnimDict)
    
        while (not HasAnimDictLoaded(placeAnimDict)) do
            Wait(0)
        end
    
        TaskPlayAnim(playerPed, placeAnimDict, placeAnimName, 4.0, 4.0, -1, 0, 0, 0, 0, 0)
    
        Wait(500)

        StopAnimTask(playerPed, pickedUpAnimDict, pickedUpAnimName, 4.0)
        StopAnimTask(playerPed, placeAnimDict, placeAnimName, 2.0)
        DetachEntity(handle, false, true)
        SetEntityCoords(handle, GetEntityCoords(playerPed) + (GetEntityForwardVector(playerPed) * 0.75))
        PlaceObjectOnGroundProperly(handle)
    end
end)

RegisterNetEvent('cs-boombox:destroy', function(model)
    local playerPed = PlayerPedId()
    local handle = GetClosestObjectOfType(GetEntityCoords(playerPed), 2.0, GetHashKey(model), false, false, false)

    if (handle > 0 and (GetEntityAttachedTo(handle) == 0 or GetEntityAttachedTo(handle) == playerPed)) then
        lastAttachedObject = nil

        RequestAnimDict(placeAnimDict)
    
        while (not HasAnimDictLoaded(placeAnimDict)) do
            Wait(0)
        end
    
        TaskPlayAnim(playerPed, placeAnimDict, placeAnimName, 4.0, 4.0, -1, 0, 0, 0, 0, 0)
    
        Wait(750)

        local controlRequestedAt = GetGameTimer()
        
        while (not NetworkHasControlOfEntity(handle)) do
            if (GetGameTimer() - controlRequestedAt >= 5000) then
                break
            end
            
            Wait(0)
        end

        controlRequestedAt = GetGameTimer()

        SetEntityAsMissionEntity(handle)

        while (not IsEntityAMissionEntity(handle)) do
            if (GetGameTimer() - controlRequestedAt >= 5000) then
                break
            end

            Wait(0)
        end

        StopAnimTask(playerPed, pickedUpAnimDict, pickedUpAnimName, 4.0)
        StopAnimTask(playerPed, placeAnimDict, placeAnimName, 2.0)
        DeleteEntity(handle)
    end
end)

-- Action Animations

local animDict = 'rcmextreme3'
local animName = 'idle'

AddEventHandler('cs-boombox:onControllerInterfaceOpen', function()
    local playerPed = PlayerPedId()

    if ((not IsEntityPlayingAnim(playerPed, animDict, animName, 3)) and (not IsEntityPlayingAnim(playerPed, pickedUpAnimDict, pickedUpAnimName, 3))) then
        RequestAnimDict(animDict)

        while (not HasAnimDictLoaded(animDict)) do
            Wait(0)
        end
    
        TaskPlayAnim(playerPed, animDict, animName, 4.0, 4.0, -1, 1, 0, 0, 0, 0)
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
