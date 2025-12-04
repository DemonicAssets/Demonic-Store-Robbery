fx_version 'cerulean'
game 'gta5'

name 'Demonic Store Robbery'
author 'Demonic Assets'
version '1.0.4'
description 'Store Robbery System for FiveM using ox_lib, ox_target and ox_inventory'

lua54 'yes'

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/bridge.lua',
    'shared/targets.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/rewards.lua',
    'server/main.lua'
}

files { }

provide 'Demonic_Store_Robbery'
