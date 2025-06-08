fx_version 'cerulean'
games { 'gta5' }

author 'The_Hs5'

description 'Display vehicle mileage, Service vehicle parts'
version '1.2.0'
ui_page 'html/index.html'

dependency {'oxmysql', 'ox_lib'}

shared_scripts {
	'@ox_lib/init.lua',
	'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

ox_libs {
	'notify',
	'progressBar',
	'locale',
}

lua54 'yes'
