-- Server-side checks and integration of how the boombox UI is accessed.
-- Do whatever checks you want here and execute TriggerEvent('cs-boombox:toggleControllerInterface', source, uniqueId) with source being the player ID and uniqueId being the boombox unique ID to open the boombox UI in a player.
-- If your checks fail, execute TriggerEvent('cs-boombox:disallowControllerInterface', source) to block remove the controller access (e.g. in case of a dynamic check being updated).
-- The default integration triggers this via the client command boombox and does a perform native death check (client-side) and a permission check (server-side).
-- To allow all admins (using Ace group admin) to perform controller duties in all boombox models, add "add_ace group.admin cs-boombox.control allow" in your server's config file.
-- Alternatively to Ace permissions in the default integration, you can add any player identifiers to the array playerIdentifiersAsControllers below to allow specific players to perform controller duties in all boombox models.
-- You can keep the default integration and edit the default CanAccessControllerInterface function and return true / false based on your conditions.
-- Action boombox commands (/create-boombox, /destroy-boombox, /pickup-boombox, /drop-boombox) are also included in the default integration and are also checked against the same function. Feel free to remove them or edit them.

local playerIdentifiersAsControllers = {
    'steam:000000000000000', -- Example Steam player identifier.
    'fivem:000000', -- Example FiveM player identifier.
}

function CanAccessControllerInterface(source, model)
    if (IsPlayerAceAllowed(source, 'cs-boombox.control')) then
        return true
    end

    for i = 1, #playerIdentifiersAsControllers do
        for ii, identifier in ipairs(GetPlayerIdentifiers(source)) do
            if (string.lower(identifier) == string.lower(playerIdentifiersAsControllers[i])) then
                return true
            end
        end
    end

    return false
end

RegisterNetEvent('cs-boombox:integration:toggleControllerInterface', function(uniqueId, model)
    local source = source

    if (CanAccessControllerInterface(source, model)) then
        TriggerEvent('cs-boombox:toggleControllerInterface', source, uniqueId)
    else
        TriggerEvent('cs-boombox:disallowControllerInterface', source, uniqueId)
    end
end)

-- Action Commands

RegisterCommand('create-boombox', function(source, args, raw)
    if (not CanAccessControllerInterface(source, 'prop_boombox_01')) then
        return
    end

    TriggerClientEvent('cs-boombox:create', source, 'prop_boombox_01')
end)

RegisterCommand('pickup-boombox', function(source, args, raw)
    if (not CanAccessControllerInterface(source, 'prop_boombox_01')) then
        return
    end

    TriggerClientEvent('cs-boombox:pickup', source, 'prop_boombox_01')
end)

RegisterCommand('drop-boombox', function(source, args, raw)
    if (not CanAccessControllerInterface(source, 'prop_boombox_01')) then
        return
    end

    TriggerClientEvent('cs-boombox:drop', source, 'prop_boombox_01')
end)

RegisterCommand('destroy-boombox', function(source, args, raw)
    if (not CanAccessControllerInterface(source, 'prop_boombox_01')) then
        return
    end

    TriggerClientEvent('cs-boombox:destroy', source, 'prop_boombox_01')
end)

-- Server Events

AddEventHandler('cs-boombox:onPlay', function(uniqueId, source, data)
    -- Triggered when play is triggered either manually or via an export.
    -- The uniqueId indicates which boombox object the action is triggered for.
    -- If the source is nil then this action was triggered via an export otherwise it is the source player.

    --[[
        data 
            .url                    -- The URL of the entry (as received via a client or an export).
            .thumbnailUrl           -- The URL of the entry's thumbnail (as received via a client or an export).
            .thumbnailTitle         -- The title of the entry's thumbnail (as received via a client or an export).
            .title                  -- The title of the entry (as received via a client or an export).
            .icon                   -- The icon of the entry (as received via a client or an export).
    ]]
end)

AddEventHandler('cs-boombox:onPause', function(uniqueId, source, data)
    -- Triggered when pause is triggered either manually or via an export.
    -- The uniqueId indicates which boombox object the action is triggered for.
    -- If the source is nil then this action was triggered via an export otherwise it is the source player.

    --[[
        data 
            .url                    -- The URL of the entry (as received via a client or an export).
            .thumbnailUrl           -- The URL of the entry's thumbnail (as received via a client or an export).
            .thumbnailTitle         -- The title of the entry's thumbnail (as received via a client or an export).
            .title                  -- The title of the entry (as received via a client or an export).
            .icon                   -- The icon of the entry (as received via a client or an export).
    ]]
end)

AddEventHandler('cs-boombox:onStop', function(uniqueId, source, data)
    -- Triggered when stop is triggered either manually, automatically (stopped due to end / error etc.) or via an export.
    -- The uniqueId indicates which boombox object the action is triggered for.
    -- If the source is nil then this action was triggered via an export otherwise it is the source player.

    --[[
        data 
            .url                    -- The URL of the entry (as received via a client or an export).
            .thumbnailUrl           -- The URL of the entry's thumbnail (as received via a client or an export).
            .thumbnailTitle         -- The title of the entry's thumbnail (as received via a client or an export).
            .title                  -- The title of the entry (as received via a client or an export).
            .icon                   -- The icon of the entry (as received via a client or an export).
    ]]
end)

AddEventHandler('cs-boombox:onDuration', function(uniqueId, source, duration)
    -- Triggered when duration is set for the current entry via a client.
    -- This does not trigger via an export.
    -- The uniqueId indicates which boombox object the action is triggered for.
    -- If the source is nil then this action was triggered via an export otherwise it is the source player.
    -- The duration is in seconds. If this event is not triggered within a timely manner we can assume that the responsible update client failed to retrieve the duration of the entry.
end)

AddEventHandler('cs-boombox:onEntryQueued', function(uniqueId, source, data)
    -- Triggered when an entry is added to queue either manually or via an export.
    -- This does not trigger when an entry changes position.
    -- The uniqueId indicates which boombox object the action is triggered for.
    -- If the source is nil then this action was triggered via an export otherwise it is the source player.

    --[[
        data 
            .url                    -- The URL of the entry (as received via a client or an export).
            .thumbnailUrl           -- The URL of the entry's thumbnail (as received via a client or an export).
            .thumbnailTitle         -- The title of the entry's thumbnail (as received via a client or an export).
            .title                  -- The title of the entry (as received via a client or an export).
            .icon                   -- The icon of the entry (as received via a client or an export).
            .position               -- The position of the entry in the queue.
            .manual                 -- Whether this entry was manually added. If this is false it indicates it was added via an export.
    ]]
end)

AddEventHandler('cs-boombox:onEntryRemoved', function(uniqueId, source, data)
    -- Triggered when an entry is removed from queue either manually or via an export.
    -- This does not trigger when an entry is moved from the queue to the player or when an entry changes position.
    -- The uniqueId indicates which boombox object the action is triggered for.
    -- If the source is nil then this action was triggered via an export otherwise it is the source player.

    --[[
        data 
            .url                    -- The URL of the entry (as received via a client or an export).
            .thumbnailUrl           -- The URL of the entry's thumbnail (as received via a client or an export).
            .thumbnailTitle         -- The title of the entry's thumbnail (as received via a client or an export).
            .title                  -- The title of the entry (as received via a client or an export).
            .icon                   -- The icon of the entry (as received via a client or an export).
            .position               -- The position of the entry in the queue.
            .manual                 -- Whether this entry was manually added. If this is false it indicates it was added via an export.
    ]]
end)

-- Server Exports

--[[
    exports['cs-boombox']:Play(uniqueId)                               -- Trigger a play action in the specified by uniqueId boombox. The uniqueId is the config entry's key.
    exports['cs-boombox']:Pause(uniqueId)                              -- Trigger a pause action in the specified by uniqueId boombox. The uniqueId is the config entry's key.
    exports['cs-boombox']:Stop(uniqueId)                               -- Trigger a stop action in the specified by uniqueId boombox. The uniqueId is the config entry's key.
    exports['cs-boombox']:IsPlaying(uniqueId)                          -- Returns whether an entry is playing in the specified by uniqueId boombox. The uniqueId is the config entry's key.
    exports['cs-boombox']:SetLoop(uniqueId, state)                     -- Sets the player loop state of the specified by uniqueId boombox. The uniqueId is the config entry's key. The state is a boolean indicating the loop state.

    exports['cs-boombox']:AddToQueue(                              -- Adds a new entry to the specified by uniqueId boombox's queue.
        uniqueId,               -- The config entry's key.
        url,                -- The URL of the entry.
        thumbnailUrl,       -- The thumbnail URL of the entry.
        thumbnailTitle,     -- The thumbnail title of the entry.
        title,              -- The title of the entry.
        icon,               -- The icon of the entry.
        duration            -- The duration of the entry (in seconds).
    )

    exports['cs-boombox']:QueueNow(uniqueId, position)                 -- Queues an entry to the specified by uniqueId boombox's queue in the specified queue position. The uniqueId is the config entry's key.
    exports['cs-boombox']:RemoveFromQueue(uniqueId, position)          -- Removes an entry from the specified by uniqueId boombox's queue in the specified queue position. The uniqueId is the config entry's key.

    exports['cs-boombox']:GetPlayer(uniqueId)                          -- Returns the entry in the player of the specified by uniqueId boombox in an object with the following data structure.
                                                                {
                                                                    playing,            -- Whether the player is playing or not.
                                                                    stopped,            -- Whether the player is stopped or not.
                                                                    volume,             -- The volume of the player (0.0 to 1.0).
                                                                    loop,               -- The loop state of the player.
                                                                    url,                -- The URL of the entry (as received via a client or an export).
                                                                    thumbnailUrl,       -- The thumbnail URL of the entry (as received via a client or an export).
                                                                    thumbnailTitle,     -- The thumbnail title of the entry (as received via a client or an export).
                                                                    title,              -- The title of the entry (as received via a client or an export).
                                                                    icon,               -- The icon of the entry (as received via a client or an export).
                                                                    time,               -- The current time of the entry (in seconds) (as received via a client or as measured by the server). 
                                                                    duration            -- The duration of the entry (in seconds) (as received via a client or an export). 
                                                                }

    exports['cs-boombox']:GetQueue(uniqueId)                           -- Returns the queue of the specified by uniqueId boombox in an array of objects with the following data structure for each object.
                                                                {
                                                                    url,                -- The URL of the entry (as received via a client or an export).
                                                                    thumbnailUrl,       -- The thumbnail URL of the entry (as received via a client or an export).
                                                                    thumbnailTitle,     -- The thumbnail title of the entry (as received via a client or an export).
                                                                    title,              -- The title of the entry (as received via a client or an export).
                                                                    icon,               -- The icon of the entry (as received via a client or an export).
                                                                    duration,           -- The duration of the entry (in seconds) (as received via an export; nil if received via a client). 
                                                                    manual              -- Whether this entry was manually added. If this is false it indicates it was added via an export.
                                                                }
]]
