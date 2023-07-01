[![Critical Scripts](https://files.criticalscripts.shop/brand-assets/logo.png)](https://criticalscripts.shop)

# cs-boombox

![cs-boombox](https://i.imgur.com/GhbnoET.gif "cs-boombox")

Looking to push your players' entertainment a step forward?\
Give them boomboxes, stereos and more to enjoy!

This resource is open source and you can customize it to your liking.

It is a standalone resource and works with any framework. The UI is accessed via the `/boombox` command while near an enabled model object for players with Ace permission `cs-boombox.control`.\
Enabled model objects will be detected and will work regardless of their spawn method. Permission check and how the UI is accessed can be changed by modifying **_integration/client.lua_** and **_integration/server.lua_** files.\
There is also an identifier-based check in parallel to Ace permission which can also be edited in integration/server.lua file to add any player identifiers you want.

Out of the box we provide you with configuration for the _`prop_boombox_01`_ object.\
As well as the following commands for boombox model control (using the same control permissions):

 1. `/create-boombox` - create a boombox nearby.
 2. `/destroy-boombox` - destroy the closest boombox if one is nearby.
 3. `/pickup-boombox` - pick up the closest boombox if one is nearby.
 4. `/drop-boombox` - drop your picked up boombox.

Make sure to join our [Discord](https://criticalscripts.shop/discord) where people may choose to share their configurations for other models or even share your own if you create one!

Special thanks to [FildonPrime](https://github.com/FildonPrime) for assisting with the resource and bringing up the idea.

## Features

-  **YouTube** (live or video) and **Twitch** (live, video or clip) supported.
-  Player position and camera-based 3D audio.
-  Minimal UI for full and easy control of what’s happening alongside a queue system.
-  Unlimited number of model objects with their own setup given you can create them.
-  Range synchronization and considerate optimization for a good balance between performance and features.
-  Real-time state synchronization between players for both UI and currently playing media.
-  A wide array of events and exports to check and control the resource.
-  Extensive configuration to change almost all aspects of the resource to your liking without touching code.
-  Lua-based integration for permissions and access control to limit usage of the resource to whoever you like (job-based, permission-based and so on).

## Installation Instructions

1. Download **_cs-boombox_** and place it in your _**resources**_ folder.
2. Add _**ensure cs-boombox**_ to your server's configuration file.
3. Add **_add_ace group.admin cs-boombox.control allow_** to your server's configuration file so Ace admins can access **_/boombox_** command (and by default boombox model control related commands).\
This check can be changed by modifying **_integration/server.lua_** file.
4. Check the **_config.lua_** file inside **_cs-boombox_** for further configuration.
5. Run the command **_refresh_** followed by the command **_ensure cs-boombox_**.

## Important Information

-  The resource is optimized with range synchronization and assets are loaded only when the player is around an active object.
-  Very low-spec computers may experience a more downgraded experience.
-  If you want to ensure the resource, you are advised to stop the playback in all active objects first to avoid crashes.
-  Minor crackling may be audible on certain songs when the camera is moved due to limitations imposed upon spatial audio.
-  Only **YouTube** and **Twitch** content is allowed at this time.
-  **Twitch** may throw alerts in live streams about third-party viewing experience and sync may not be optimal. Mature content warning and audio muted warning will be clicked away automatically.
-  The resource is loading content in every client by using APIs, embeds and inline frames therefore, does not directly violate any copyright laws.
-  If content fails to load or play for any reason for the player who is controlling the UI, it will stop for everyone. If content fails to load or play for any reason for a player who is only viewing / listening, it may attempt to reload for them.
-  There are checks in place in an attempt to verify that the transmitted data (titles, thumbnail URL, icon, etc.) are legitimate and are coming from the within resource itself, however since the client sends it, they cannot be fully trusted.
