fx_version("cerulean")
game("gta5")
author("LXFS - Service")
description("An very nice advanced hud with an car hud.")

client_scripts({
    "configuration.lua",
    "script.lua"
})

server_scripts({
    "configuration.lua",
    "script2.lua"
})

ui_page("html/ui.html")

files({
    "html/ui.html"
})

dependencys({
    "es_extended",
    "esx_status"
})