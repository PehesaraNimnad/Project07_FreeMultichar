fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'Project07_FreeMultichar'
author 'Project07'
description 'Free multicharacter: cinematic text-only screen, no admin panel, Discord logs'
version '1.0.0'

dependencies { 'ox_lib', 'oxmysql', 'Project7H_Lib' }

shared_scripts {
    '@ox_lib/init.lua',
    '@Project7H_Lib/imports.lua',
    'config.lua',
}

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'sv_config.lua',
    'server/main.lua',
}

ui_page 'web/build/multichar.html'

files {
    'web/build/multichar.html',
    'web/build/assets/*',
}
