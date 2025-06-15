---------------- Main data ----------------
--[[
    These variables define the main Lua files that make up the Wizard Mileage resource.
    They are used for version checking, file integrity, and to ensure all necessary files are present and loaded.
    If you add, remove, or rename Lua files in this resource, update this list accordingly.
    Customers can reference this variable to understand which files are essential for the script to function.
--]]
local luaFileNames = {'client.lua', 'config.lua', 'server.lua'}



---------------- Functions ----------------
--[[
    This function prints debug messages to the server console if debugging is enabled in the config.
    It is used throughout the script to help with troubleshooting and to provide detailed logs
    about script actions, database queries, and server events. Customers can enable or disable
    debug output by setting Config.Debug to true or false in the config file.
--]]
local function debug(data)
    if Config.Debug then print("^7[^6Wizard Mileage^7] ^5" .. data) end
end

--[[
    This function checks if the given player is an admin based on the configured admin rank.
    It is used to restrict access to admin-only features, such as the vehicle database or maintenance overrides.
    Returns true if the player has the required ace permission, otherwise returns false.
    Customers can adjust the required rank in the config file (Config.AdminRank).
--]]
local function isAdmin(source)
    local src = source
    if IsPlayerAceAllowed(src, Config.AdminRank) then
        return true
    end
    return false
end

--[[
    This function loads the player's UI customization settings from the database.
    If settings exist for the given player ID, they are returned via the callback.
    If no settings are found, default UI settings from the config are inserted into the database and returned.
    This ensures every player always has a valid set of UI preferences.
    Customers can reference this function to understand how player-specific UI settings are managed and stored.
--]]
local function loadPlayerSettings(playerId, cb)
    Wait(150)
    debug("Loading mileage UI settings for " .. playerId)
    local query = "SELECT * FROM mileage_settings WHERE player_id = ?"
    exports.oxmysql:execute(query, {playerId}, function(result)
        if result and result[1] then
            cb(result[1])
        else
            local insertQuery = [[
                INSERT INTO mileage_settings (player_id, mileage_visible, mileage_size, checkwear_size, mileage_pos_x, mileage_pos_y, checkwear_pos_x, checkwear_pos_y)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ]]
            exports.oxmysql:execute(insertQuery, {
                playerId,
                Config.DefaultUI.mileage_visible,
                Config.DefaultUI.mileage_size,
                Config.DefaultUI.checkwear_size,
                Config.DefaultUI.mileage_pos_x,
                Config.DefaultUI.mileage_pos_y,
                Config.DefaultUI.checkwear_pos_x,
                Config.DefaultUI.checkwear_pos_y
            }, function(insertResult)
                cb(Config.DefaultUI)
            end)
        end
    end)
end

--[[
    This function saves the player's UI customization settings to the database.
    It updates or inserts the settings based on the player's ID, ensuring that their preferences are stored persistently.
    The function takes a player ID and a settings table containing the UI preferences.
    Customers can use this function to understand how player-specific UI settings are saved and updated in the database.
--]]
local function savePlayerSettings(playerId, settings)
    debug("Updating mileage UI settings for " .. playerId)
    local query = [[
        INSERT INTO mileage_settings (player_id, mileage_visible, mileage_size, checkwear_size, mileage_pos_x, mileage_pos_y, checkwear_pos_x, checkwear_pos_y)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            mileage_visible = VALUES(mileage_visible),
            mileage_size = VALUES(mileage_size),
            checkwear_size = VALUES(checkwear_size),
            mileage_pos_x = VALUES(mileage_pos_x),
            mileage_pos_y = VALUES(mileage_pos_y),
            checkwear_pos_x = VALUES(checkwear_pos_x),
            checkwear_pos_y = VALUES(checkwear_pos_y)
    ]]
    exports.oxmysql:execute(query, {
        playerId,
        settings.mileage_visible,
        settings.mileage_size,
        settings.checkwear_size,
        settings.mileage_pos_x or 0,
        settings.mileage_pos_y or 0,
        settings.checkwear_pos_x or 0,
        settings.checkwear_pos_y or 0
    })
end

--[[
    This function fetches the content of a URL using either cURL or PerformHttpRequest.
    It returns the response body if the request is successful (HTTP status code 200).
    If cURL is enabled via the convar "use_curl", it uses cURL to fetch the URL.
    Otherwise, it falls back to PerformHttpRequest for compatibility with FiveM's HTTP request system.
    Customers can use this function to retrieve external data, such as version information or changelogs.
--]]
local function fetchUrl(url)
    local response = {}
    local res, code = nil, nil
    if GetConvar("use_curl", "false") == "true" then
        local handle = io.popen("curl -s " .. url)
        if handle then
            local result = handle:read("*a")
            handle:close()
            return result
        end
    else
        local done = false
        PerformHttpRequest(url, function(statusCode, body, headers)
            res = statusCode == 200
            code = statusCode
            response[1] = body
            done = true
        end)
        while not done do
            Citizen.Wait(0)
        end
    end
    if res and code == 200 then
        return response[1]
    else
        return nil
    end
end

--[[
    This function compares two version strings (v1 and v2) and returns:
    - -1 if v1 < v2
    - 0 if v1 == v2
    - 1 if v1 > v2
    It splits the version strings into numeric components and compares them one by one.
    Customers can use this function to check if their script version is up to date compared to the latest version.
]]
local function compareVersions(v1, v2)
    local function splitVersion(v)
        local t = {}
        for num in string.gmatch(v, "%d+") do
            table.insert(t, tonumber(num))
        end
        return t
    end
    local v1t = splitVersion(v1)
    local v2t = splitVersion(v2)
    for i = 1, math.max(#v1t, #v2t) do
        local n1 = v1t[i] or 0
        local n2 = v2t[i] or 0
        if n1 < n2 then
            return -1
        elseif n1 > n2 then
            return 1
        end
    end
    return 0
end

--[[
    This function checks if the specified Lua files are loaded in the current resource.
    It takes a resource name and a list of Lua file names, and returns a table indicating
    whether each file is loaded (true) or not (false).
    If the resource path cannot be determined, it prints an error message.
    Customers can use this function to verify that all necessary Lua files are loaded correctly.
--]]
local function AreLuaFilesLoaded(resourceName, luaFileNames)
    local resourcePath = GetResourcePath(resourceName)
    if resourcePath then
        local loadedFiles = {}
        for _, luaFileName in ipairs(luaFileNames) do
            local fileExists = LoadResourceFile(resourceName, luaFileName) ~= nil
            loadedFiles[luaFileName] = fileExists
        end
        return loadedFiles
    else
        print("Script name is changed! please use the main script name to support me:(")
        return nil
    end
end

--[[
    This function checks the current script version against the latest version available online.
    It fetches the latest version and changelog from GitHub, compares it with the current version,
    and prints a message to the server console indicating whether the script is up to date or outdated.
    If the script is outdated, it also prints the latest version and changelog.
    Customers can use this function to ensure they are running the latest version of the Wizard Mileage script.
]]
local function checkVersion()
    local currentVersion = GetResourceMetadata(GetCurrentResourceName(), "version", 0)
    local latestVersionUrl = "https://raw.githubusercontent.com/CodeWizardsDev/wizard-mileage/refs/heads/main/version.txt"
    local changelogUrl = "https://raw.githubusercontent.com/CodeWizardsDev/wizard-mileage/refs/heads/main/changelog.txt"
    local latestVersion = fetchUrl(latestVersionUrl)

    local logo = "^3\n\n\n\n░█──░█ ─▀─ ▀▀█ █▀▀█ █▀▀█ █▀▀▄ 　 ░█▀▄▀█ ─▀─ █── █▀▀ █▀▀█ █▀▀▀ █▀▀\n░█░█░█ ▀█▀ ▄▀─ █▄▄█ █▄▄▀ █──█ 　 ░█░█░█ ▀█▀ █── █▀▀ █▄▄█ █─▀█ █▀▀\n░█▄▀▄█ ▀▀▀ ▀▀▀ ▀──▀ ▀─▀▀ ▀▀▀─ 　 ░█──░█ ▀▀▀ ▀▀▀ ▀▀▀ ▀──▀ ▀▀▀▀ ▀▀▀"

    if not latestVersion then
        print(logo .. "\n\n^7[^6Wizard Mileage^7] ^8Failed to fetch latest version info.\n")
        return
    end
    latestVersion = latestVersion:gsub("%s+", "")

    if compareVersions(currentVersion, latestVersion) < 0 then
        print(logo .. "\n\n^7[^6Wizard Mileage^7] ^5Your script version ^2(" .. currentVersion .. ") ^5is outdated. Latest version is ^2" .. latestVersion)
        local changelog = fetchUrl(changelogUrl)
        if changelog then
            print("^7[^6Wizard Mileage^7] ^5Change log:^7\n" .. changelog .. "\n")
        else
            print("^7[^6Wizard Mileage^7] ^8Failed to fetch changelog.\n")
        end
    else
        print(logo .. "\n\n                 ^5Script is up to date. Version: ^2" .. currentVersion .. "\n")
    end
    local results = AreLuaFilesLoaded(GetCurrentResourceName(), luaFileNames)
    if results then
    for luaFileName, isLoaded in pairs(results) do
        if isLoaded then
            print("                   ^5The file '" .. luaFileName .. "' is loaded.^0")
        else
            print("                   ^8The file '" .. luaFileName .. "' is NOT loaded.^0")
        end
    end
    print("\n\n")
    end
end



---------------- Inventory initialize ----------------
--[[
    This section initializes the inventory system based on the configured inventory script.
    It creates usable items for vehicle maintenance parts, allowing players to use these items
    to perform maintenance tasks on their vehicles.
    Customers can modify the item names and behaviors in the config file to suit their server's needs.
--]]
if Config.InventoryScript == 'qb' then
    QBCore = exports['qb-core']:GetCoreObject()
    QBCore.Functions.CreateUseableItem(Config.Items.SparkPlug, function(source, item)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player.Functions.GetItemByName(item.name) then return end
        TriggerClientEvent('wizard_vehiclemileage:client:changesparkplug', source)
    end)
    QBCore.Functions.CreateUseableItem(Config.Items.EngineOil, function(source, item)
		local Player = QBCore.Functions.GetPlayer(source)
		if not Player.Functions.GetItemByName(item.name) then return end
	    TriggerClientEvent('wizard_vehiclemileage:client:changeoil', source)
    end)
    QBCore.Functions.CreateUseableItem(Config.Items.OilFilter, function(source, item)
		local Player = QBCore.Functions.GetPlayer(source)
		if not Player.Functions.GetItemByName(item.name) then return end
	    TriggerClientEvent('wizard_vehiclemileage:client:changeoilfilter', source)
    end)
    QBCore.Functions.CreateUseableItem(Config.Items.AirFilter, function(source, item)
		local Player = QBCore.Functions.GetPlayer(source)
		if not Player.Functions.GetItemByName(item.name) then return end
	    TriggerClientEvent('wizard_vehiclemileage:client:changeairfilter', source)
    end)
    QBCore.Functions.CreateUseableItem(Config.Items.Tires, function(source, item)
		local Player = QBCore.Functions.GetPlayer(source)
		if not Player.Functions.GetItemByName(item.name) then return end
	    TriggerClientEvent('wizard_vehiclemileage:client:changetires', source)
    end)
    QBCore.Functions.CreateUseableItem(Config.Items.BrakeParts, function(source, item)
		local Player = QBCore.Functions.GetPlayer(source)
		if not Player.Functions.GetItemByName(item.name) then return end
	    TriggerClientEvent('wizard_vehiclemileage:client:changebrakes', source)
    end)
    QBCore.Functions.CreateUseableItem(Config.Items.SusParts, function(source, item)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player.Functions.GetItemByName(item.name) then return end
        TriggerClientEvent('wizard_vehiclemileage:client:changesuspension', source)
    end)
    QBCore.Functions.CreateUseableItem(Config.Items.Clutch, function(source, item)
		local Player = QBCore.Functions.GetPlayer(source)
		if not Player.Functions.GetItemByName(item.name) then return end
	    TriggerClientEvent('wizard_vehiclemileage:client:changeclutch', source)
    end)
elseif Config.InventoryScript == 'quasar' then
    exports['qs-inventory']:CreateUsableItem(Config.Items.SparkPlug, function(source, item)
        TriggerClientEvent('wizard_vehiclemileage:client:changesparkplug', source)
    end)
    exports['qs-inventory']:CreateUsableItem(Config.Items.EngineOil, function(source, item)
        TriggerClientEvent('wizard_vehiclemileage:client:changeoil', source)
    end)
    exports['qs-inventory']:CreateUsableItem(Config.Items.OilFilter, function(source, item)
        TriggerClientEvent('wizard_vehiclemileage:client:changeoilfilter', source)
    end)
    exports['qs-inventory']:CreateUsableItem(Config.Items.AirFilter, function(source, item)
        TriggerClientEvent('wizard_vehiclemileage:client:changeairfilter', source)
    end)
    exports['qs-inventory']:CreateUsableItem(Config.Items.Tires, function(source, item)
        TriggerClientEvent('wizard_vehiclemileage:client:changetires', source)
    end)
    exports['qs-inventory']:CreateUsableItem(Config.Items.BrakeParts, function(source, item)
        TriggerClientEvent('wizard_vehiclemileage:client:changebrakes', source)
    end)
    exports['qs-inventory']:CreateUsableItem(Config.Items.SusParts, function(source, item)
        TriggerClientEvent('wizard_vehiclemileage:client:changesuspension', source)
    end)
    exports['qs-inventory']:CreateUsableItem(Config.Items.Clutch, function(source, item)
        TriggerClientEvent('wizard_vehiclemileage:client:changeclutch', source)
    end)
elseif Config.InventoryScript == 'esx' then
    local ESX = exports["es_extended"]:getSharedObject()
    ESX.RegisterUsableItem(Config.Items.SparkPlug, function(source)
        TriggerClientEvent('wizard_vehiclemileage:client:changesparkplug', source)
    end)
    ESX.RegisterUsableItem(Config.Items.EngineOil, function(source)
        TriggerClientEvent('wizard_vehiclemileage:client:changeoil', source)
    end)
    ESX.RegisterUsableItem(Config.Items.OilFilter, function(source)
        TriggerClientEvent('wizard_vehiclemileage:client:changeoilfilter', source)
    end)
    ESX.RegisterUsableItem(Config.Items.AirFilter, function(source)
        TriggerClientEvent('wizard_vehiclemileage:client:changeairfilter', source)
    end)
    ESX.RegisterUsableItem(Config.Items.Tires, function(source)
        TriggerClientEvent('wizard_vehiclemileage:client:changetires', source)
    end)
    ESX.RegisterUsableItem(Config.Items.BrakeParts, function(source)
        TriggerClientEvent('wizard_vehiclemileage:client:changebrakes', source)
    end)
    ESX.RegisterUsableItem(Config.Items.SusParts, function(source)
        TriggerClientEvent('wizard_vehiclemileage:client:changesuspension', source)
    end)
    ESX.RegisterUsableItem(Config.Items.Clutch, function(source)
        TriggerClientEvent('wizard_vehiclemileage:client:changeclutch', source)
    end)
end



---------------- Net Events ----------------
--[[
    This section registers various server-side events that handle different functionalities of the Wizard Mileage script.
    These events include checking for updates, loading and saving player settings, updating vehicle data,
    and handling vehicle maintenance tasks such as oil changes, tire changes, and more.
    Customers can reference these events to understand how to interact with the script and extend its functionality.
--]]
RegisterNetEvent("wizard_vehiclemileage:server:getupdate")
AddEventHandler("wizard_vehiclemileage:server:getupdate", function()
    local src = source
    local currentVersion = GetResourceMetadata(GetCurrentResourceName(), "version", 0)
    local latestVersionUrl = "https://raw.githubusercontent.com/CodeWizardsDev/wizard-mileage/refs/heads/main/version.txt"
    local latestVersion = fetchUrl(latestVersionUrl)
    if compareVersions(currentVersion, latestVersion) < 0 then
        isOutdated = true
    else
        isOutdated = false
    end
    TriggerClientEvent("wizard_vehiclemileage:client:setOutdated", src, isOutdated, currentVersion, latestVersion)
end)

--[[
    This event checks if the player is an admin and returns the result to the client.
    It uses the isAdmin function to determine if the player has the required ace permission.
    Customers can use this event to restrict access to certain features based on admin status.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:isAdmin')
AddEventHandler('wizard_vehiclemileage:server:isAdmin', function(cbId)
    local src = source
    local admin = isAdmin(src)
    TriggerClientEvent('wizard_vehiclemileage:client:isAdminCallback', src, cbId, admin)
end)

--[[
    This event loads the player's UI settings from the database and sends them to the client.
    If no settings are found, it inserts default settings into the database.
    Customers can use this event to manage player-specific UI preferences for the mileage display.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:loadPlayerSettings')
AddEventHandler('wizard_vehiclemileage:server:loadPlayerSettings', function()
    local src = source
    local playerId = GetPlayerIdentifier(src, 0)
    loadPlayerSettings(playerId, function(settings)
        TriggerClientEvent('wizard_vehiclemileage:client:setPlayerSettings', src, settings)
    end)
end)

--[[
    This event saves the player's UI settings to the database.
    It takes a settings table from the client and updates or inserts it into the mileage_settings table.
    Customers can use this event to allow players to customize their UI preferences for the mileage display.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:savePlayerSettings')
AddEventHandler('wizard_vehiclemileage:server:savePlayerSettings', function(settings)
    local src = source
    local playerId = GetPlayerIdentifier(src, 0)
    savePlayerSettings(playerId, settings)
    TriggerClientEvent('wizard_vehiclemileage:client:setPlayerSettings', src, settings)
end)

--[[
    This event retrieves all vehicles' mileage data from the database and sends it to the client.
    It executes a SQL query to select all records from the vehicle_mileage table and returns the result.
    Customers can use this event to display a list of all vehicles and their mileage data in the UI.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:getAllVehicles')
AddEventHandler('wizard_vehiclemileage:server:getAllVehicles', function(cbId)
    local src = source
    local query = "SELECT * FROM vehicle_mileage"
    exports.oxmysql:execute(query, {}, function(result)
        TriggerClientEvent('wizard_vehiclemileage:client:getAllVehiclesCallback', src, cbId, result or {})
    end)
end)

--[[
    This event retrieves the mileage data for a specific vehicle based on its plate number.
    It executes a SQL query to select the record from the vehicle_mileage table where the plate matches.
    The result is sent back to the client for display or further processing.
    Customers can use this event to fetch and display mileage data for individual vehicles.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:updateVehicleData')
AddEventHandler('wizard_vehiclemileage:server:updateVehicleData', function(vehicleData)
    if not vehicleData or not vehicleData.plate then return end
    local plate = vehicleData.plate
    local mileage = vehicleData.mileage or 0
    local src = source
    local query = [[
        INSERT INTO vehicle_mileage (plate, mileage, last_oil_change, last_oil_filter_change, last_air_filter_change, last_tire_change, last_brakes_change, brake_wear, last_clutch_change, clutch_wear, last_suspension_change, suspension_wear, last_spark_plug_change, spark_plug_wear)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            mileage = VALUES(mileage),
            last_oil_change = VALUES(last_oil_change),
            last_oil_filter_change = VALUES(last_oil_filter_change),
            last_air_filter_change = VALUES(last_air_filter_change),
            last_tire_change = VALUES(last_tire_change),
            last_brakes_change = VALUES(last_brakes_change),
            brake_wear = VALUES(brake_wear),
            last_clutch_change = VALUES(last_clutch_change),
            clutch_wear = VALUES(clutch_wear),
            last_suspension_change = VALUES(last_suspension_change),
            suspension_wear = VALUES(suspension_wear),
            last_spark_plug_change = VALUES(last_spark_plug_change),
            spark_plug_wear = VALUES(spark_plug_wear)
    ]]
    exports.oxmysql:execute(query, {
        plate,
        mileage,
        vehicleData.last_oil_change or 0,
        vehicleData.last_oil_filter_change or 0,
        vehicleData.last_air_filter_change or 0,
        vehicleData.last_tire_change or 0,
        vehicleData.last_brakes_change or 0,
        vehicleData.brake_wear or 0,
        vehicleData.last_clutch_change or 0,
        vehicleData.clutch_wear or 0,
        vehicleData.last_suspension_change or 0,
        vehicleData.suspension_wear or 0,
        vehicleData.last_spark_plug_change or 0,
        vehicleData.spark_plug_wear or 0
    }, function(rowsChanged)
        if rowsChanged then
            TriggerClientEvent('wizard_vehiclemileage:client:vehicleDataUpdated', src)
        end
    end)
end)

--[[
    This event deletes a vehicle's mileage data from the database based on its plate number.
    It executes a SQL query to remove the record from the vehicle_mileage table where the plate matches.
    Customers can use this event to allow players or admins to delete vehicle records from the mileage database.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:deleteVehicle')
AddEventHandler('wizard_vehiclemileage:server:deleteVehicle', function(plate)
    if not plate then return end
    local query = "DELETE FROM vehicle_mileage WHERE plate = ?"
    exports.oxmysql:execute(query, {plate})
end)

--[[
    This event adds an item to the player's inventory.
    It checks if the item and amount are valid, then uses the configured inventory script to add the item.
    Customers can use this event to manage vehicle maintenance items in players' inventories.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:removeItem')
AddEventHandler('wizard_vehiclemileage:server:removeItem', function(item, amount)
    local src = source
    if not item then return end
    if not amount then return end
    if Config.InventoryItems then
        if Config.InventoryScript == 'ox' then
            exports.ox_inventory:RemoveItem(src, item, amount)
        elseif Config.InventoryScript == 'codem' then
            exports['codem-inventory']:RemoveItem(src, item, amount)
        elseif Config.InventoryScript == 'quasar' then
            exports['qs-inventory']:RemoveItem(src, item, amount)
        elseif Config.InventoryScript == 'qb' then
            exports['qb-inventory']:RemoveItem(src, item, amount, false, 'wizard-mileage:Vehicle maintenance')
        elseif Config.InventoryScript == 'esx' then
            local ESX = exports["es_extended"]:getSharedObject()
            local xPlayer = ESX.GetPlayerFromId(source)
            xPlayer.removeInventoryItem(item, amount)
        end
    end
end)

--[[
    This event retrieves the original suspension values for a vehicle based on its plate number.
    It executes two SQL queries to get the original suspension raise and force from the vehicle_mileage table.
    The results are sent back to the client to set the original suspension values.
    Customers can use this event to manage vehicle suspension settings in the mileage system.
]]
RegisterNetEvent('wizard_vehiclemileage:server:getOriginalSuspensionValue')
AddEventHandler('wizard_vehiclemileage:server:getOriginalSuspensionValue', function(plate)
    if not plate then return end
    local src = source
    local query = "SELECT original_suspension_raise FROM vehicle_mileage WHERE plate = ?"
    local query2 = "SELECT original_suspension_force FROM vehicle_mileage WHERE plate = ?"
    exports.oxmysql:execute(query, {plate}, function(result)
        if result and result[1] and result[1].original_suspension_raise then
            local susRaise = tonumber(result[1].original_suspension_raise)
            if susRaise then
                TriggerClientEvent('wizard_vehiclemileage:client:setOriginalSusRaise', src, susRaise)
            end
        end
    end)
    exports.oxmysql:execute(query2, {plate}, function(result2)
        if result2 and result2[1] and result2[1].original_suspension_force then
            local susForce = tonumber(result2[1].original_suspension_force)
            if susForce then
                TriggerClientEvent('wizard_vehiclemileage:client:setOriginalSusForce', src, susForce)
            end
        end
    end)
end)

--[[
    This event updates the wear level of the vehicle's brakes in the database.
    It takes the plate number and brake wear value, then executes an SQL update query.
    Customers can use this event to track brake wear and manage vehicle maintenance.
]]
RegisterNetEvent('wizard_vehiclemileage:server:updateSuspensionWear')
AddEventHandler('wizard_vehiclemileage:server:updateSuspensionWear', function(plate, suspensionWear)
    if not plate or type(suspensionWear) ~= "number" then return end
    local query = "UPDATE vehicle_mileage SET suspension_wear = ? WHERE plate = ?"
    exports.oxmysql:execute(query, {suspensionWear, plate}, function(rowsChanged)
    end)
end)

--[[
    This event updates the last suspension change mileage for a vehicle in the database.
    It retrieves the current mileage from the vehicle_mileage table and updates the last_suspension_change field.
    Customers can use this event to track when the suspension was last changed for maintenance records.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:updateSuspensionChange')
AddEventHandler('wizard_vehiclemileage:server:updateSuspensionChange', function(plate)
    if not plate then return end
    local query = "SELECT mileage FROM vehicle_mileage WHERE plate = ?"
    exports.oxmysql:execute(query, {plate}, function(result)
        if result and result[1] then
            local mileage = tonumber(result[1].mileage) or 0.0
            local updateQuery = "UPDATE vehicle_mileage SET last_suspension_change = ? WHERE plate = ?"
            exports.oxmysql:execute(updateQuery, {mileage, plate}, function(rowsChanged)
                if rowsChanged then
                    debug("Suspension change updated for plate " .. plate .. " at mileage " .. mileage)
                else
                    debug("Failed to update suspension change for plate " .. plate)
                end
            end)
        end
    end)
end)

--[[
    This event updates the wear level of the vehicle's spark plugs in the database.
    It takes the plate number and spark plug wear value, then executes an SQL update query.
    Customers can use this event to track spark plug wear and manage vehicle maintenance.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:updateSparkPlugWear')
AddEventHandler('wizard_vehiclemileage:server:updateSparkPlugWear', function(plate, sparkPlugWear)
    if not plate or type(sparkPlugWear) ~= "number" then return end
    local query = "UPDATE vehicle_mileage SET spark_plug_wear = ? WHERE plate = ?"
    exports.oxmysql:execute(query, {sparkPlugWear, plate}, function(rowsChanged)
    end)
end)

--[[
    This event updates the last spark plug change mileage for a vehicle in the database.
    It retrieves the current mileage from the vehicle_mileage table and updates the last_spark_plug_change field.
    Customers can use this event to track when the spark plugs were last changed for maintenance records.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:updateSparkPlugChange')
AddEventHandler('wizard_vehiclemileage:server:updateSparkPlugChange', function(plate)
    if not plate then return end
    local query = "SELECT mileage FROM vehicle_mileage WHERE plate = ?"
    exports.oxmysql:execute(query, {plate}, function(result)
        if result and result[1] then
            local mileage = tonumber(result[1].mileage) or 0.0
            local updateQuery = "UPDATE vehicle_mileage SET last_spark_plug_change = ? WHERE plate = ?"
            exports.oxmysql:execute(updateQuery, {mileage, plate}, function(rowsChanged)
                if rowsChanged then
                    debug("Spark plug change updated for plate " .. plate .. " at mileage " .. mileage)
                else
                    debug("Failed to update spark plug change for plate " .. plate)
                end
            end)
        end
    end)
end)

--[[
    This event saves the original suspension force for a vehicle in the database.
    It updates the original_suspension_force field for the specified plate if it is currently NULL.
    Customers can use this event to store the original suspension settings for vehicles.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:saveOriginalSuspensionForce')
AddEventHandler('wizard_vehiclemileage:server:saveOriginalSuspensionForce', function(plate, force)
    if not plate or not force then return end
    local query = [[
        UPDATE vehicle_mileage
        SET original_suspension_force = ?
        WHERE plate = ? AND original_suspension_force IS NULL
    ]]
    exports.oxmysql:execute(query, {force, plate}, function(rowsChanged)
    end)
end)

--[[
    This event saves the original suspension raise value for a vehicle in the database.
    It updates the original_suspension_raise field for the specified plate.
    Customers can use this event to store the original suspension raise setting for vehicles,
    which can be useful for restoring or comparing suspension modifications.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:saveOriginalSuspensionRaise')
AddEventHandler('wizard_vehiclemileage:server:saveOriginalSuspensionRaise', function(plate, raise)
    if not plate or not raise then return end
    local query = [[
        UPDATE vehicle_mileage
        SET original_suspension_raise = ?
        WHERE plate = ?
    ]]
    exports.oxmysql:execute(query, {raise, plate}, function(rowsChanged)
    end)
end)

--[[
    This event retrieves all mileage and maintenance data for a specific vehicle from the database.
    It queries the vehicle_mileage table using the provided plate number and collects all relevant fields,
    including mileage, last maintenance actions, wear levels, and original drive/suspension values.
    The results are sent back to the client using the 'wizard_vehiclemileage:client:setData' event.
    Customers can reference this event to understand how vehicle data is loaded and synchronized between
    the server and client for accurate UI and gameplay updates.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:retrieveMileage')
AddEventHandler('wizard_vehiclemileage:server:retrieveMileage', function(plate)
    local src = source
    if not plate then return end
    local query = [[
        SELECT mileage, last_oil_change, last_oil_filter_change, last_air_filter_change, 
        last_tire_change, last_brakes_change, brake_wear, last_clutch_change, clutch_wear,
        original_drive_force, last_suspension_change, suspension_wear, last_spark_plug_change, spark_plug_wear
        FROM vehicle_mileage WHERE plate = ? LIMIT 1
    ]]
    exports.oxmysql:execute(query, {plate}, function(result)
        local mileage = 0.0
        local lastOil = 0.0
        local lastFilter = 0.0
        local lastAirFilter = 0.0
        local lastTire = 0.0
        local lastBrake = 0.0
        local brakeWear = 0.0
        local lastClutch = 0.0
        local clutchWear = 0.0
        local original_drive_force = nil
        local lastSuspensionChange = 0.0
        local suspensionWear = 0.0
        local lastSparkPlugChange = 0.0
        local sparkPlugWear = 0.0
        if result and result[1] then
            mileage = tonumber(result[1].mileage) or 0.0
            lastOil = tonumber(result[1].last_oil_change) or 0.0
            lastFilter = tonumber(result[1].last_oil_filter_change) or 0.0
            lastAirFilter = tonumber(result[1].last_air_filter_change) or 0.0
            lastTire = tonumber(result[1].last_tire_change) or 0.0
            lastBrake = tonumber(result[1].last_brakes_change) or 0.0
            brakeWear = tonumber(result[1].brake_wear) or 0.0
            lastClutch = tonumber(result[1].last_clutch_change) or 0.0
            clutchWear = tonumber(result[1].clutch_wear) or 0.0
            original_drive_force = tonumber(result[1].original_drive_force)
            lastSuspensionChange = tonumber(result[1].last_suspension_change) or 0.0
            suspensionWear = tonumber(result[1].suspension_wear) or 0.0
            lastSparkPlugChange = tonumber(result[1].last_spark_plug_change) or 0.0
            sparkPlugWear = tonumber(result[1].spark_plug_wear) or 0.0
        end
        TriggerClientEvent('wizard_vehiclemileage:client:setData', src, mileage, lastOil, lastFilter, lastAirFilter, lastTire, lastBrake, brakeWear, lastClutch, clutchWear, original_drive_force, lastSuspensionChange, suspensionWear, lastSparkPlugChange, sparkPlugWear)
    end)
end)

--[[
    This event saves the original drive force value for a vehicle in the database.
    It updates the original_drive_force field for the specified plate, but only if it is currently NULL.
    Customers can use this event to store the original drive force setting for vehicles,
    which can be useful for restoring or comparing drive force modifications.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:saveOriginalDriveForce')
AddEventHandler('wizard_vehiclemileage:server:saveOriginalDriveForce', function(plate, driveForce)
    if not plate or not driveForce then return end
    
    local query = [[
        UPDATE vehicle_mileage 
        SET original_drive_force = ?
        WHERE plate = ? AND original_drive_force IS NULL
    ]]
    
    exports.oxmysql:execute(query, {driveForce, plate})
end)

--[[
    This event retrieves the original drive force value for a specific vehicle from the database.
    It queries the vehicle_mileage table using the provided plate number and returns the original_drive_force value.
    If a value is found, it is sent back to the client using the 'wizard_vehiclemileage:client:setOriginalDriveForce' event.
    Customers can reference this event to understand how original drive force values are loaded and synchronized
    between the server and client for accurate vehicle performance restoration or comparison.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:getOriginalDriveForce')
AddEventHandler('wizard_vehiclemileage:server:getOriginalDriveForce', function(plate)
    if not plate then return end
    local src = source
    
    local query = "SELECT original_drive_force FROM vehicle_mileage WHERE plate = ?"
    exports.oxmysql:execute(query, {plate}, function(result)
        if result and result[1] and result[1].original_drive_force then
            local driveForce = tonumber(result[1].original_drive_force)
            if driveForce then
                TriggerClientEvent('wizard_vehiclemileage:client:setOriginalDriveForce', src, driveForce)
            end
        end
    end)
end)

--[[
    This event updates the mileage value for a specific vehicle in the database.
    It inserts a new record if the vehicle does not exist, or updates the mileage if it does.
    The function checks for valid input and logs the result for debugging purposes.
    Customers can reference this event to understand how vehicle mileage is stored and updated.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:updateMileage')
AddEventHandler('wizard_vehiclemileage:server:updateMileage', function(plate, mileage)
    if not plate or type(mileage) ~= "number" then
        debug("Invalid data provided for mileage update.")
        return
    end
    debug("Updating mileage for plate " .. plate .. " to " .. mileage)
    local query = [[
        INSERT INTO vehicle_mileage (plate, mileage, last_oil_change, last_oil_filter_change, last_air_filter_change, 
        last_tire_change, last_brakes_change, brake_wear, last_clutch_change, clutch_wear,
        last_suspension_change, suspension_wear, last_spark_plug_change, spark_plug_wear)
        VALUES (?, ?, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        ON DUPLICATE KEY UPDATE mileage = ?
    ]]
    exports.oxmysql:execute(query, {plate, mileage, mileage}, function(rowsChanged)
        if rowsChanged then
            debug("Mileage update successful for plate " .. plate)
        else
            debug("Mileage update failed for plate " .. plate)
        end
    end)
end)

--[[
    This event updates the last oil change mileage for a vehicle in the database.
    It retrieves the current mileage for the specified plate and sets the last_oil_change field to that value.
    Customers can use this event to track when the oil was last changed for maintenance records.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:updateOilChange')
AddEventHandler('wizard_vehiclemileage:server:updateOilChange', function(plate)
    if not plate then return end

    local updateQuery = [[
        UPDATE vehicle_mileage vm
        JOIN (SELECT mileage FROM vehicle_mileage WHERE plate = ?) AS sub ON vm.plate = ?
        SET vm.last_oil_change = sub.mileage
        WHERE vm.plate = ?
    ]]
    exports.oxmysql:execute(updateQuery, {plate, plate, plate}, function(rowsChanged)
        if rowsChanged then
            debug("Oil change update successful for plate " .. plate)
        else
            debug("Oil change update failed for plate " .. plate)
        end
    end)
end)

--[[
    This event updates the last oil filter change mileage for a vehicle in the database.
    It retrieves the current mileage for the specified plate and sets the last_oil_filter_change field to that value.
    Customers can use this event to track when the oil filter was last changed for maintenance records.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:updateOilFilter')
AddEventHandler('wizard_vehiclemileage:server:updateOilFilter', function(plate)
    if not plate then return end

    local updateQuery = [[
        UPDATE vehicle_mileage vm
        JOIN (SELECT mileage FROM vehicle_mileage WHERE plate = ?) AS sub ON vm.plate = ?
        SET vm.last_oil_filter_change = sub.mileage
        WHERE vm.plate = ?
    ]]
    exports.oxmysql:execute(updateQuery, {plate, plate, plate}, function(rowsChanged)
        if rowsChanged then
            debug("Oil filter change update successful for plate " .. plate)
        else
            debug("Oil filter change update failed for plate " .. plate)
        end
    end)
end)

--[[
    This event updates the last air filter change mileage for a vehicle in the database.
    It retrieves the current mileage for the specified plate and sets the last_air_filter_change field to that value.
    Customers can use this event to track when the air filter was last changed for maintenance records.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:updateAirFilter')
AddEventHandler('wizard_vehiclemileage:server:updateAirFilter', function(plate)
    if not plate then return end

    local updateQuery = [[
        UPDATE vehicle_mileage vm
        JOIN (SELECT mileage FROM vehicle_mileage WHERE plate = ?) AS sub ON vm.plate = ?
        SET vm.last_air_filter_change = sub.mileage
        WHERE vm.plate = ?
    ]]
    exports.oxmysql:execute(updateQuery, {plate, plate, plate}, function(rowsChanged)
        if rowsChanged then
            debug("Air filter change update successful for plate " .. plate)
        else
            debug("Air filter change update failed for plate " .. plate)
        end
    end)
end)

--[[
    This event updates the last tire change mileage for a vehicle in the database.
    It retrieves the current mileage for the specified plate and sets the last_tire_change field to that value.
    Customers can use this event to track when the tires were last changed for maintenance records.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:updateTireChange')
AddEventHandler('wizard_vehiclemileage:server:updateTireChange', function(plate)
    if not plate then return end

    local updateQuery = [[
        UPDATE vehicle_mileage vm
        JOIN (SELECT mileage FROM vehicle_mileage WHERE plate = ?) AS sub ON vm.plate = ?
        SET vm.last_tire_change = sub.mileage
        WHERE vm.plate = ?
    ]]
    exports.oxmysql:execute(updateQuery, {plate, plate, plate}, function(rowsChanged)
        if rowsChanged then
            debug("Tire change update successful for plate " .. plate)
        else
            debug("Tire change update failed for plate " .. plate)
        end
    end)
end)

--[[
    This event updates the wear level of the vehicle's brakes in the database.
    It takes the plate number and brake wear value, then executes an SQL update query.
    If the update is successful, a debug message is printed with the new value.
    Customers can use this event to track brake wear and manage vehicle maintenance.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:updateBrakeWear')
AddEventHandler('wizard_vehiclemileage:server:updateBrakeWear', function(plate, brakeWear)
    if not plate or type(brakeWear) ~= "number" then  return  end
    
    local query = "UPDATE vehicle_mileage SET brake_wear = ? WHERE plate = ?"
    exports.oxmysql:execute(query, {brakeWear, plate}, function(rowsChanged)
        if rowsChanged then
            debug("Brake wear updated for plate " .. plate .. " to " .. brakeWear)
        else
            debug("Brake wear update failed for plate " .. plate)
        end
    end)
end)

--[[
    This event updates the last brake change mileage and resets brake wear for a vehicle in the database.
    It retrieves the current mileage for the specified plate and sets the last_brakes_change field to that value,
    while also resetting brake_wear to 0.0. This is used to track when the brakes were last changed and to
    reset their wear level after maintenance. Customers can use this event to maintain accurate brake service records.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:updateBrakeChange')
AddEventHandler('wizard_vehiclemileage:server:updateBrakeChange', function(plate)
    if not plate then 
        debug("Invalid plate provided for brake change update")
        return 
    end

    local updateQuery = [[
        UPDATE vehicle_mileage vm
        JOIN (SELECT mileage FROM vehicle_mileage WHERE plate = ?) AS sub ON vm.plate = ?
        SET vm.last_brakes_change = sub.mileage, vm.brake_wear = 0.0
        WHERE vm.plate = ?
    ]]
    exports.oxmysql:execute(updateQuery, {plate, plate, plate}, function(rowsChanged)
        if rowsChanged then
            debug("Brake change update successful for plate " .. plate)
        else
            debug("Brake change update failed for plate " .. plate)
        end
    end)
end)

--[[
    This event updates the wear level of the vehicle's clutch in the database.
    It takes the plate number and clutch wear value, then executes an SQL update query.
    If the update is successful, a debug message is printed with the new value.
    Customers can use this event to track clutch wear and manage vehicle maintenance.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:updateClutchWear')
AddEventHandler('wizard_vehiclemileage:server:updateClutchWear', function(plate, clutchWear)
    if not plate or type(clutchWear) ~= "number" then return end
    
    local query = "UPDATE vehicle_mileage SET clutch_wear = ? WHERE plate = ?"
    exports.oxmysql:execute(query, {clutchWear, plate}, function(rowsChanged)
        if rowsChanged then
            debug("Clutch wear updated for plate " .. plate .. " to " .. clutchWear)
        else
            debug("Clutch wear update failed for plate " .. plate)
        end
    end)
end)

--[[
    This event updates the last clutch change mileage and resets clutch wear for a vehicle in the database.
    It retrieves the current mileage for the specified plate and sets the last_clutch_change field to that value,
    while also resetting clutch_wear to 0.0. This is used to track when the clutch was last changed and to
    reset its wear level after maintenance. Customers can use this event to maintain accurate clutch service records.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:updateClutchChange')
AddEventHandler('wizard_vehiclemileage:server:updateClutchChange', function(plate)
    if not plate then 
        debug("Invalid plate provided for clutch change update")
        return 
    end

    local updateQuery = [[
        UPDATE vehicle_mileage vm
        JOIN (SELECT mileage FROM vehicle_mileage WHERE plate = ?) AS sub ON vm.plate = ?
        SET vm.last_clutch_change = sub.mileage, vm.clutch_wear = 0.0
        WHERE vm.plate = ?
    ]]
    exports.oxmysql:execute(updateQuery, {plate, plate, plate}, function(rowsChanged)
        if rowsChanged then
            debug("Clutch change update successful for plate " .. plate)
        else
            debug("Clutch change update failed for plate " .. plate)
        end
    end)
end)

--[[
    This event checks if a vehicle with the given plate is owned by a player.
    It queries the ownership table defined in Config.VehDB to see if the plate exists.
    The result is sent back to the client as a boolean value.
    Customers can use this event to verify vehicle ownership for features like mileage tracking or maintenance.
--]]
RegisterNetEvent('wizard_vehiclemileage:server:checkOwnership')
AddEventHandler('wizard_vehiclemileage:server:checkOwnership', function(plate)
    local src = source
    if not plate then return end
    
    local query = "SELECT 1 FROM " .. Config.VehDB .. " WHERE plate = ? LIMIT 1"
    exports.oxmysql:execute(query, {plate}, function(result)
        local isOwned = result and #result > 0
        TriggerClientEvent('wizard_vehiclemileage:client:ownershipResult', src, isOwned)
    end)
end)


AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        checkVersion()
    end
end)



---------------- Exports ----------------
--[[
    Exports for other scripts to interact with vehicle mileage and maintenance data.
    Provides functions to get/set mileage, parts change history, and wear levels.
--]]
exports('GetVehicleMileage', function(plate, cb)
    if not plate or not cb then return end
    local query = [[
        SELECT mileage FROM vehicle_mileage WHERE plate = ? LIMIT 1
    ]]
    exports.oxmysql:execute(query, {plate}, function(result)
        if result and result[1] then
            cb(tonumber(result[1].mileage) or 0.0)
        else
            cb(0.0)
        end
    end)
end)

--[[
    Set vehicle mileage.
    Can be used to set the mileage directly, e.g., for testing or resetting.
    If no mileage is provided, it uses the current accumulated distance.
--]]
exports('SetVehicleMileage', function(plate, mileage)
    if not plate or type(mileage) ~= "number" then return end
    local query = [[
        INSERT INTO vehicle_mileage (plate, mileage)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE mileage = ?
    ]]
    exports.oxmysql:execute(query, {plate, mileage, mileage})
end)

--[[
    Get vehicle last parts change data.
    Returns a table with the last change mileage for each part.
    - sparkPlugChange: Last spark plug change mileage
    - oilChange: Last oil change mileage
    - oilFilterChange: Last oil filter change mileage
    - airFilterChange: Last air filter change mileage
    - tireChange: Last tire change mileage
    - brakeChange: Last brake change mileage
    - suspensionChange: Last suspension change mileage
    - clutchChange: Last clutch change mileage
--]]
exports('GetVehicleLastPartsChange', function(plate, cb)
    if not plate or not cb then return end
    local query = [[
        SELECT last_oil_change, last_oil_filter_change, last_air_filter_change, last_tire_change,
        last_brakes_change, last_clutch_change, last_suspension_change, last_spark_plug_change
        FROM vehicle_mileage WHERE plate = ? LIMIT 1
    ]]
    exports.oxmysql:execute(query, {plate}, function(result)
        if result and result[1] then
            print("xxxx")
            cb({
                oilChange = tonumber(result[1].last_oil_change) or 0.0,
                oilFilterChange = tonumber(result[1].last_oil_filter_change) or 0.0,
                airFilterChange = tonumber(result[1].last_air_filter_change) or 0.0,
                tireChange = tonumber(result[1].last_tire_change) or 0.0,
                brakeChange = tonumber(result[1].last_brakes_change) or 0.0,
                clutchChange = tonumber(result[1].last_clutch_change) or 0.0,
                suspensionChange = tonumber(result[1].last_suspension_change) or 0.0,
                sparkPlugChange = tonumber(result[1].last_spark_plug_change) or 0.0
            })
        else
            cb(nil)
        end
    end)
end)

--[[
    Set vehicle last parts change data.
    Can be used to set the last change mileage for each part, e.g., for testing or resetting.
    If no mileage is provided for a part, it retains the current value.
--]]
exports('SetVehicleLastPartsChange', function(plate, partsChange)
    if not plate or type(partsChange) ~= "table" then return end
    local queries = {}
    local params = {}

    if partsChange.oilChange then
        table.insert(queries, "UPDATE vehicle_mileage SET last_oil_change = ? WHERE plate = ?")
        table.insert(params, partsChange.oilChange)
        table.insert(params, plate)
    end
    if partsChange.oilFilterChange then
        table.insert(queries, "UPDATE vehicle_mileage SET last_oil_filter_change = ? WHERE plate = ?")
        table.insert(params, partsChange.oilFilterChange)
        table.insert(params, plate)
    end
    if partsChange.airFilterChange then
        table.insert(queries, "UPDATE vehicle_mileage SET last_air_filter_change = ? WHERE plate = ?")
        table.insert(params, partsChange.airFilterChange)
        table.insert(params, plate)
    end
    if partsChange.tireChange then
        table.insert(queries, "UPDATE vehicle_mileage SET last_tire_change = ? WHERE plate = ?")
        table.insert(params, partsChange.tireChange)
        table.insert(params, plate)
    end
    if partsChange.brakeChange then
        table.insert(queries, "UPDATE vehicle_mileage SET last_brakes_change = ? WHERE plate = ?")
        table.insert(params, partsChange.brakeChange)
        table.insert(params, plate)
    end
    if partsChange.clutchChange then
        table.insert(queries, "UPDATE vehicle_mileage SET last_clutch_change = ? WHERE plate = ?")
        table.insert(params, partsChange.clutchChange)
        table.insert(params, plate)
    end
    if partsChange.suspensionChange then
        table.insert(queries, "UPDATE vehicle_mileage SET last_suspension_change = ? WHERE plate = ?")
        table.insert(params, partsChange.suspensionChange)
        table.insert(params, plate)
    end
    if partsChange.sparkPlugChange then
        table.insert(queries, "UPDATE vehicle_mileage SET last_spark_plug_change = ? WHERE plate = ?")
        table.insert(params, partsChange.sparkPlugChange)
        table.insert(params, plate)
    end

    for i, query in ipairs(queries) do
        local param1 = params[(i-1)*2 + 1]
        local param2 = params[(i-1)*2 + 2]
        exports.oxmysql:execute(query, {param1, param2})
    end
end)

--[[
    Get vehicle parts wear data.
    Returns a table with the current wear levels for each part.
    - brakeWear: Current brake wear level
    - clutchWear: Current clutch wear level
    - suspensionWear: Current suspension wear level
    - sparkPlugWear: Current spark plug wear level
]]
exports('GetVehiclePartsWear', function(plate, cb)
    if not plate or not cb then return end
    local query = [[
        SELECT brake_wear, clutch_wear, suspension_wear, spark_plug_wear
        FROM vehicle_mileage WHERE plate = ? LIMIT 1
    ]]
    exports.oxmysql:execute(query, {plate}, function(result)
        if result and result[1] then
            cb({
                brakeWear = tonumber(result[1].brake_wear) or 0.0,
                clutchWear = tonumber(result[1].clutch_wear) or 0.0,
                suspensionWear = tonumber(result[1].suspension_wear) or 0.0,
                sparkPlugWear = tonumber(result[1].spark_plug_wear) or 0.0
            })
        else
            cb(nil)
        end
    end)
end)

--[[
    Set vehicle parts wear data.
    Can be used to set the wear levels for each part, e.g., for testing or resetting.
    If no wear level is provided for a part, it retains the current value.
--]]
exports('SetVehiclePartsWear', function(plate, partsWear)
    if not plate or type(partsWear) ~= "table" then return end
    local queries = {}
    local params = {}

    if partsWear.brakeWear then
        table.insert(queries, "UPDATE vehicle_mileage SET brake_wear = ? WHERE plate = ?")
        table.insert(params, partsWear.brakeWear)
        table.insert(params, plate)
    end
    if partsWear.clutchWear then
        table.insert(queries, "UPDATE vehicle_mileage SET clutch_wear = ? WHERE plate = ?")
        table.insert(params, partsWear.clutchWear)
        table.insert(params, plate)
    end

    for i, query in ipairs(queries) do
        local param1 = params[(i-1)*2 + 1]
        local param2 = params[(i-1)*2 + 2]
        exports.oxmysql:execute(query, {param1, param2})
    end
end)



---------------- Exports Examples ----------------
--[[
-- Example: Get vehicle mileage from server export
RegisterCommand('serverGetMileage', function(source, args)
    if not args[1] then
        print("Usage: /serverGetMileage <plate>")
        return
    end

    local plate = args[1]
    exports['wizard-mileage']:GetVehicleMileage(plate, function(mileage)
        print("Mileage for vehicle " .. plate .. ": " .. mileage)
    end)
end)
    -- /serverSetMileage <plate> <mileage>
RegisterCommand('serverSetMileage', function(source, args)
    if not args[1] or not args[2] then
        print("Usage: /serverSetMileage <plate> <mileage>")
        return
    end

    local plate = args[1]
    local mileage = tonumber(args[2])
    exports['wizard-mileage']:SetVehicleMileage(plate, mileage)
    print("Set mileage for vehicle " .. plate .. " to " .. mileage)
end)
    -- /serverGetLastPartsChange <plate> (sp, oil, oilf, airf, tire, brake, sus, clutch)
RegisterCommand('serverGetLastPartsChange', function(source, args)
    if #args < 2 then
        print("Usage: /serverGetLastPartsChange <plate> <part>")
        return
    end

    local plate = args[1]
    local partName = args[2]:lower()

    exports['wizard-mileage']:GetVehicleLastPartsChange(plate, function(partsChange)
        if partsChange then
            if partName == 'sp' then
                print("Last spark plugs change mileage: " .. tostring(partsChange.sparkPlugChange))
            elseif partName == 'oil' then
                print("Last oil change mileage: " .. tostring(partsChange.oilChange))
            elseif partName == 'oilf' then
                print("Last oil filter change mileage: " .. tostring(partsChange.oilFilterChange))
            elseif partName == 'airf' then
                print("Last air filter change mileage: " .. tostring(partsChange.airFilterChange))
            elseif partName == 'tire' then
                print("Last tire change mileage: " .. tostring(partsChange.tireChange))
            elseif partName == 'brake' then
                print("Last brake change mileage: " .. tostring(partsChange.brakeChange))
            elseif partName == 'sus' then
                print("Last suspension change mileage: " .. tostring(partsChange.suspensionChange))
            elseif partName == 'clutch' then
                print("Last clutch change mileage: " .. tostring(partsChange.clutchChange))
            else
                print("Available parts: sp, oil, oilf, airf, tire, brake, sus, clutch")
            end
        else
            print("No data found for vehicle " .. plate)
        end
    end)
end)
    -- /serverSetLastPartsChange <plate> (sp, oil, oilf, airf, tire, brake, sus, clutch) <mileage>
RegisterCommand('serverSetLastPartsChange', function(source, args)
    if #args < 3 then
        print("Usage: /serverSetLastPartsChange <plate> <part> <mileage>")
        return
    end

    local plate = args[1]
    local partName = tostring(args[2]):lower()
    local partMileage = tonumber(args[3])
    if not partMileage then
        print("Invalid mileage value. Please enter a number.")
        return
    end

    local partsChange = {
        sparkPlugChange = nil,
        oilChange = nil,
        oilFilterChange = nil,
        airFilterChange = nil,
        tireChange = nil,
        brakeChange = nil,
        suspensionChange = nil,
        clutchChange = nil,
    }

    if partName == 'sp' then
        partsChange.sparkPlugChange = partMileage
    elseif partName == 'oil' then
        partsChange.oilChange = partMileage
    elseif partName == 'oilf' then
        partsChange.oilFilterChange = partMileage
    elseif partName == 'airf' then
        partsChange.airFilterChange = partMileage
    elseif partName == 'tire' then
        partsChange.tireChange = partMileage
    elseif partName == 'brake' then
        partsChange.brakeChange = partMileage
    elseif partName == 'sus' then
        partsChange.suspensionChange = partMileage
    elseif partName == 'clutch' then
        partsChange.clutchChange = partMileage
    else
        print("Invalid part name. Available parts: sp, oil, oilf, airf, tire, brake, sus, clutch")
        return
    end

    exports['wizard-mileage']:SetVehicleLastPartsChange(plate, partsChange)
    print("Last parts change data of " .. plate .. " updated for " .. partName .. " to mileage " .. partMileage)
end)
    -- /serverGetPartsWear <plate> (sp, oil, oilf, airf, tire, brake, sus, clutch)
RegisterCommand('serverGetPartsWear', function(source, args)
    if #args < 2 then
        print("Usage: /serverGetPartsWear <plate> (sp, oil, oilf, airf, tire, brake, sus, clutch)")
        return
    end

    local plate = args[1]
    local partName = args[2]:lower()

    exports['wizard-mileage']:GetVehiclePartsWear(plate, function(partsWear)
        if partsWear then
            if partName == 'sp' then
                print("Spark plugs wear: " .. tostring(partsWear.sparkPlugWear))
            elseif partName == 'oil' then
                print("Oil wear: " .. tostring(partsWear.oilWear))
            elseif partName == 'oilf' then
                print("Oil filter wear: " .. tostring(partsWear.oilFilterWear))
            elseif partName == 'airf' then
                print("Air filter wear: " .. tostring(partsWear.airFilterWear))
            elseif partName == 'tire' then
                print("Tire wear: " .. tostring(partsWear.tireWear))
            elseif partName == 'brake' then
                print("Brake wear: " .. tostring(partsWear.brakeWear))
            elseif partName == 'sus' then
                print("Suspension wear: " .. tostring(partsWear.suspensionWear))
            elseif partName == 'clutch' then
                print("Clutch wear: " .. tostring(partsWear.clutchWear))
            else
                print("Available parts: sp, oil, oilf, airf, tire, brake, sus, clutch")
            end
        else
            print("No wear data found for vehicle " .. plate)
        end
    end)
end)
    -- /serverSetPartsWear <plate> (brake, clutch) <wear>
RegisterCommand('serverSetPartsWear', function(source, args)
    if #args < 3 then
        print("Usage: /serverSetPartsWear <plate> (brake, clutch) <wear>")
        return
    end

    local plate = args[1]
    local partName = tostring(args[2]):lower()
    local wearValue = tonumber(args[3])
    if not wearValue then
        print("Invalid wear value. Please enter a number.")
        return
    end

    local partsWear = {
        brakeWear = nil,
        clutchWear = nil,
    }

    if partName == 'brake' then
        partsWear.brakeWear = wearValue
    elseif partName == 'clutch' then
        partsWear.clutchWear = wearValue
    else
        print("Invalid part name. Available parts: brake, clutch")
        return
    end

    exports['wizard-mileage']:SetVehiclePartsWear(plate, partsWear)
    print("Updated parts wear data for vehicle " .. plate .. " part " .. partName .. " to wear " .. wearValue)
end)
]]--
