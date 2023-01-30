fx_version 'cerulean'

game 'gta5'

author 'Critical Scripts | https://criticalscripts.shop'
version '2023-01-30.01'

lua54 'yes'

files {
    'client/ui/index.html',
    'client/ui/javascript/**/*.js',
    'client/ui/images/**/*.svg',
    'client/ui/images/**/*.png',
    'client/ui/images/**/*.jpg',
    'client/ui/css/**/*.css',
    'client/ui/fonts/**/*.eot',
    'client/ui/fonts/**/*.svg',
    'client/ui/fonts/**/*.ttf',
    'client/ui/fonts/**/*.woff',
    'client/ui/fonts/**/*.woff2',
    'client/dui/index.html',
    'client/dui/images/**/*.png',
    'client/dui/javascript/**/*.js'
}

ui_page 'client/ui/index.html'

shared_scripts {
    'helpers.lua',
    'config.lua'
}

client_scripts {
    'client/core.lua',
    'integration/client.lua'
}

server_scripts {
    'server/core.lua',
    'integration/server.lua'
}

dependency '/onesync'
