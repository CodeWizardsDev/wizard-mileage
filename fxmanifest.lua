fx_version 'cerulean'
games { 'gta5' }

author 'The_Hs5'

description 'Display vehicle mileage, Service vehicle'
version '1.2.4'
ui_page 'html/index.html'

dependency {'wizard-lib', 'oxmysql', 'ox_lib'}

shared_scripts {
	'@ox_lib/init.lua',
	'config/config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

files {
    'locales/*.json',
    'config/ui_config.json',
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

lua54 'yes'
