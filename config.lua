config = {
    -- Set whether you want to be informed in your server's console about updates regarding this resource.
    ['updatesCheck'] = true,

    -- If you want to host the DUI files yourself you can find the source at https://github.com/criticalscripts-shop/cs-boombox-dui, otherwise leave it as it is.
    ['duiUrl'] = 'https://files.criticalscripts.shop/cs-boombox-dui/dui.html',

    -- Strings through-out the resource to translate them if you wish.
    ['lang'] = {
        ['addToQueue'] = 'Add to Queue',
        ['play'] = 'Play',
        ['queueNow'] = 'Queue Now',
        ['queueNext'] = 'Queue Next',
        ['remove'] = 'Remove',
        ['pause'] = 'Pause',
        ['stop'] = 'Stop',
        ['skip'] = 'Skip',
        ['loop'] = 'Loop',
        ['volume'] = 'Volume',
        ['invalidUrl'] = 'URL invalid.',
        ['invalidYouTubeUrl'] = 'YouTube URL invalid.',
        ['invalidTwitchUrl'] = 'Twitch URL invalid.',
        ['urlPlaceholder'] = 'YouTube / Twitch URL',
        ['sourceError'] = 'Playable media error occured.',
        ['twitchChannelOffline'] = 'Twitch channel offline.',
        ['twitchVodSubOnly'] = 'Twitch video subs-only.',
        ['twitchError'] = 'Twitch error occured.',
        ['youtubeError'] = 'YouTube error occured.',
        ['sourceNotFound'] = 'Playable media not be found.',
        ['liveFeed'] = 'Live Feed',
        ['twitchClip'] = 'Twitch Clip',
        ['queueLimitReached'] = 'The queue has already too many entries.'
    },

    -- Loading related timeouts, default values should work in most servers.
    ['timeouts'] = {
        ['assetLoadMs'] = 5000
    },

    -- Visit our Discord over at https://criticalscripts.shop/discord to get more model entries and share yours too!

    ['models'] = {
        ['boombox1'] = {
            ['enabled'] = true,
            ['range'] = 32.0,
            ['maxVolumePercent'] = 25,

            ['speaker'] = {
                ['soundOffset'] = nil,
                ['distanceOffset'] = nil,
                ['maxDistance'] = 16.0,
                ['refDistance'] = 4.0,
                ['rolloffFactor'] = 1.25,
                ['coneInnerAngle'] = 90,
                ['coneOuterAngle'] = 180,
                ['coneOuterGain'] = 0.5,
                ['fadeDurationMs'] = 250,
                ['volumeMultiplier'] = 1.0,
                ['lowPassGainReductionPercent'] = 0
            }
        },
    }

        -- Below you can find a full model config entry reference.
        
        -- ['model'] = {
        --     ['enabled'] = boolean,
        --     ['range'] = number,
        --     ['maxVolumePercent'] = number,

        --     ['speaker'] = {
        --         ['soundOffset'] = vector3(number, number, number),
        --         ['distanceOffset'] = vector3(number, number, number),
        --         ['maxDistance'] = number,
        --         ['refDistance'] = number,
        --         ['rolloffFactor'] = number,
        --         ['coneInnerAngle'] = number,
        --         ['coneOuterAngle'] = number,
        --         ['coneOuterGain'] = number,
        --         ['fadeDurationMs'] = number,
        --         ['volumeMultiplier'] = number,
        --         ['lowPassGainReductionPercent'] = number
        --         ...
        --     }
        -- }
    }
}
