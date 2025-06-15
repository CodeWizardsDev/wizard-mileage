---------------- Main data ----------------
--[[
    These variables store the main state for the mileage and wear tracking system.
    They are used throughout the script to keep track of the player's vehicle status,
    UI visibility, wear levels, and cached data for server sync.
    Customers can reference these variables to understand what is being tracked.
--]]


-- UI and vehicle state flags
local mileageVisible = false          -- Is the mileage UI currently visible?
local inVehicle = false               -- Is the player currently in a vehicle?
local waitingForData = false          -- Waiting for server data to load?
local clutchWearDirty = false         -- Is clutch wear data dirty (needs sync)?
local brakeWearDirty = false          -- Is brake wear data dirty (needs sync)?
local allowSmartGearDetect = true     -- Allow smart gear detection for clutch wear?
local mileageUIVisible = true         -- Should the mileage UI be shown?
local lastPos = nil                   -- Last known vehicle position (vector3)
local currentPlate = nil              -- Current vehicle plate being tracked

-- Wear distances (in meters, set by config/unit)
local unitMultiplier = (Config.Unit == "mile") and 1609.34 or 1000
local sparkPlugchangedist   = Config.SparkPlugChangeDistance * unitMultiplier
local oilchangedist         = Config.OilChangeDistance * unitMultiplier
local oilfilterchangedist   = Config.OilFilterDistance * unitMultiplier
local airfilterchangedist   = Config.AirFilterDistance * unitMultiplier
local tirechangedist        = Config.TireWearDistance * unitMultiplier

local isOutdated = nil                -- Script version outdated flag

-- Wear and mileage tracking values
local accDistance = 0.0               -- Accumulated distance driven (meters)
local lastOilChange = 0.0             -- Last oil change mileage
local lastOilFilterChange = 0.0       -- Last oil filter change mileage
local lastAirFilterChange = 0.0       -- Last air filter change mileage
local lastTireChange = 0.0            -- Last tire change mileage
local lastbrakeChange = 0.0           -- Last brake change mileage
local lastbrakeWear = 0.0             -- Current brake wear value
local lastClutchChange = 0.0          -- Last clutch change mileage
local lastClutchWear = 0.0            -- Current clutch wear value
local lastSuspensionChange = 0.0      -- Last suspension change mileage
local suspensionWear = 0.0            -- Current suspension wear value
local lastSparkPlugChange = 0.0       -- Last spark plug change mileage
local sparkPlugWear = 0.0             -- Current spark plug wear value

-- Cached values for syncing with the server
local cachedClutchWear = 0.0
local cachedBrakeWear = 0.0

-- UI customization values
local mileageUIPosX = 0.0
local mileageUIPosY = 0.0
local checkwearUIPosX = 0.0
local checkwearUIPosY = 0.0
local mileageUISize = 1.0
local checkwearUISize = 1.0

-- Engine warning notification timer
local lastEngineCriticalNotify = 0

-- Callback tables for admin and vehicle list requests
local adminCallbacks = {}
local vehicleListCallbacks = {}



---------------- Framework initialize ----------------
--[[
    This section initializes the framework (ESX or QBCore) based on the Config settings.
    It sets up player data and job checks, and registers events for player loading.
    The CheckJob function returns the player's job name and grade for use in service actions.
--]]
if Config.FrameWork == 'esx' then
    ESX = exports["es_extended"]:getSharedObject()

    RegisterNetEvent('esx:playerLoaded')
    AddEventHandler('esx:playerLoaded', function(xPlayer)
        ESX.PlayerData = xPlayer
        ESX.PlayerLoaded = true
        TriggerServerEvent("wizard_vehiclemileage:server:getupdate")
    end)

    -- Returns the player's job name and grade
    function CheckJob()
        ESX = exports["es_extended"]:getSharedObject()
        return ESX.GetPlayerData().job.name, ESX.GetPlayerData().job.grade
    end
else
    QBCore = exports['qb-core']:GetCoreObject()

    RegisterNetEvent("QBCore:Client:OnPlayerLoaded")
    AddEventHandler("QBCore:Client:OnPlayerLoaded", function()
        TriggerServerEvent("wizard_vehiclemileage:server:getupdate")
    end)

    -- Returns the player's job name and grade
    function CheckJob()
        local Player = QBCore.Functions.GetPlayerData()
        return Player.job.name, Player.job.grade.level
    end
end



---------------- Bought vehicles detection ----------------
--[[
    This section checks if a vehicle is owned by the player.
    If Config.BoughtVehiclesOnly is true, it will ask the server for ownership status.
    Otherwise, it will always return true (all vehicles are considered owned).
--]]
if Config.BoughtVehiclesOnly then
    local ownershipCache = {} -- Cache to store ownership results for plates

    -- Checks if the given plate is owned by the player
    -- Returns true/false (cached if possible, otherwise asks the server)
    function IsVehicleOwned(plate)
        -- Use cached result if available for this plate
        if ownershipCache[plate] ~= nil then
            return ownershipCache[plate]
        end

        local p = promise.new() -- Create a promise for async server response

        -- Handler for ownership result from server
        local function ownershipHandler(owned)
            ownershipCache[plate] = owned -- Cache the result
            p:resolve(owned)              -- Resolve the promise with the result
        end

        -- Register a one-time event handler for the ownership result
        RegisterNetEvent('wizard_vehiclemileage:client:ownershipResult')
        local eventHandler = AddEventHandler('wizard_vehiclemileage:client:ownershipResult', ownershipHandler)

        -- Ask server if the vehicle is owned
        TriggerServerEvent('wizard_vehiclemileage:server:checkOwnership', plate)

        -- Wait for the result from the server
        local result = Citizen.Await(p)
        RemoveEventHandler(eventHandler) -- Clean up the event handler
        return result
    end
else
    -- If not checking ownership, always return true (all vehicles are considered owned)
    function IsVehicleOwned()
        local p = promise.new()
        p:resolve(true)
        return Citizen.Await(p)
    end
end


---------------- Functions ----------------
--[[
    Checks for script updates and notifies the player in chat.
    Waits until the isOutdated flag is set, then displays a message
    if the script is outdated or up to date.
    Params:
        isOutdated (bool): Whether the script is outdated (set by server)
        currentVersion (string): Current script version
        latestVersion (string): Latest available version
--]]
local function updateCheck(isOutdated, currentVersion, latestVersion)
    while isOutdated == nil do Wait(100) end -- Wait until the check is complete
    if isOutdated then
        -- Notify player that their script is outdated
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 255},
            args = {
                'Wizard Mileage',
                ("^5Your script version ^2(%s) ^5is outdated. Latest version is ^2%s"):format(currentVersion, latestVersion)
            }
        })
    else
        -- Notify player that their script is up to date
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 255},
            args = {'Wizard Mileage', "^5Script is up to date"}
        })
    end
end

--[[
    Notify function for sending messages to the player using the configured notification system.
    This function supports multiple notification resources (wizard-notify, okokNotify, qbx_core, qb, esx_notify, ox_lib).
    It will automatically use the one selected in your Config.Notify setting.
    Params:
        message (string): The message to display to the player.
        type (string): The type of notification (e.g., "success", "error", "info", "warning").
--]]
local function Notify(message, type)
    if not message or not type then return end -- Don't send empty notifications

    -- Table of supported notification systems and their respective function calls
    local notifyConfig = {
        wizard = function() exports['wizard-notify']:Send('Wizard Mileage', message, 5000, type) end,
        okok = function() exports['okokNotify']:Alert('Wizard Mileage', message, 5000, type, false) end,
        qbx = function() exports.qbx_core:Notify(message, type, 5000) end,
        qb = function() TriggerEvent('QBCore:Notify', source, message, type) end,
        esx = function() exports['esx_notify']:Notify(message, type, 5000, 'Wizard Mileage') end,
        ox = function() lib.notify{title = 'Wizard Mileage', description = message, type = type} end
    }

    -- Select and call the correct notification function based on config
    local notifyFunc = notifyConfig[Config.Notify]
    if notifyFunc then notifyFunc() end
end

--[[
    Triggers an admin callback to check if the current player is an admin.
    This is used for admin-only features, such as opening the database management UI.
    The callback is stored in a table with a unique ID, so when the server responds,
    the correct callback can be executed.
    @param cb (function): The function to call with the admin status (true/false).
--]]
local function TriggerAdminCallback(cb)
    local cbId = math.random(100000, 999999) -- Generate a unique callback ID
    adminCallbacks[cbId] = cb                -- Store the callback for later use
    TriggerServerEvent('wizard_vehiclemileage:server:isAdmin', cbId) -- Ask the server to check admin status
end

--[[
    Triggers a vehicle list callback to retrieve all vehicles from the server.
    This is used for admin/database features that need to display or manage all vehicles.
    The callback is stored in a table with a unique ID, so when the server responds,
    the correct callback can be executed.
    @param cb (function): The function to call with the vehicle list (table).
--]]
local function TriggerVehicleListCallback(cb)
    local cbId = math.random(100000, 999999) -- Generate a unique callback ID
    vehicleListCallbacks[cbId] = cb          -- Store the callback for later use
    TriggerServerEvent('wizard_vehiclemileage:server:getAllVehicles', cbId) -- Ask the server for the vehicle list
end

--[[
    Shows a progress bar to the player using the configured progress bar system.
    Supports both 'qb' and 'ox' progress bar libraries, depending on your Config.ProgressBar setting.
    Params:
        duration (number): How long the progress bar should last (in ms).
        label (string): The text label to show on the progress bar.
        config (table): Additional settings (e.g., Cancelable, FreezePlayer, FreezeCar).
    Returns:
        true if the progress bar was started (qb), or the result of lib.progressBar (ox).
--]]
local function DisplayProgressBar(duration, label, config)
    if Config.ProgressBar == 'qb' then
        -- QBCore progress bar
        QBCore.Functions.Progressbar(
            "vehicle_maintenance",           -- Unique key for this progress bar
            label,                          -- Text to display
            duration,                       -- Duration in ms
            false,                          -- Not a repeating bar
            config.Cancelable,              -- Can the player cancel?
            {
                disableMovement = config.FreezePlayer,
                disableCarMovement = config.FreezeCar,
                disableMouse = false,
                disableCombat = true,
            },
            {}, {}, {},                     -- Animation and prop tables (unused here)
            function() end,                 -- On success (empty)
            function() end                  -- On cancel (empty)
        )
        return true
    elseif Config.ProgressBar == 'ox' then
        -- ox_lib progress bar
        return lib.progressBar({
            duration = duration,
            label = label,
            useWhileDead = false,
            canCancel = config.Cancelable,
            disable = {
                car = config.FreezeCar,
                move = config.FreezePlayer
            }
        })
    end
end

--[[
    Checks if the player has a specific inventory item, depending on the configured inventory system.
    Supports: ox_inventory, codem-inventory, qs-inventory, qb-core, es_extended.
    Returns true if the item is found, false otherwise.
    @param item (string): The item name to check for.
    @return (boolean): True if the player has the item, false otherwise.
--]]
local function checkInventoryItem(item)
    if not Config.InventoryItems then return true end -- If inventory checks are disabled, always return true
    local hasItem = false

    if Config.InventoryScript == 'ox' then
        -- ox_inventory: returns count of the item
        hasItem = exports.ox_inventory:Search('count', item) > 0

    elseif Config.InventoryScript == 'codem' then
        -- codem-inventory: returns true if player has at least 1 of the item
        hasItem = exports['codem-inventory']:HasItem(item, 1)

    elseif Config.InventoryScript == 'quasar' then
        -- qs-inventory: loop through player inventory and check for item
        local PlayerInv = exports['qs-inventory']:getUserInventory()
        for _, itemData in pairs(PlayerInv) do
            if itemData.name == item and itemData.amount > 0 then
                hasItem = true
                break
            end
        end

    elseif Config.InventoryScript == 'qb' then
        -- qb-core: loop through player items and check for item
        local QBCore = exports['qb-core']:GetCoreObject()
        local Player = QBCore.Functions.GetPlayerData()
        for _, v in pairs(Player.items) do
            if v.name == item then
                hasItem = true
                break
            end
        end

    elseif Config.InventoryScript == 'esx' then
        -- es_extended: loop through player inventory and check for item with count > 0
        local ESX = exports['es_extended']:getSharedObject()
        local inventory = ESX.GetPlayerData().inventory
        for _, v in pairs(inventory) do
            if v.name == item and v.count > 0 then
                hasItem = true
                break
            end
        end
    end

    return hasItem
end

--[[
    Calculates the distance between two 3D vectors (positions).
    Used to determine how far a vehicle has traveled between updates.
    @param vec1 (vector3): The first position.
    @param vec2 (vector3): The second position.
    @return (number): The distance between the two positions.
--]]
local function getDistance(vec1, vec2)
    if not vec1 or not vec2 then return 0 end -- Return 0 if either position is missing
    local dx, dy, dz = vec1.x - vec2.x, vec1.y - vec2.y, vec1.z - vec2.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

--[[
    Finds the closest vehicle to the player within a given distance.
    Useful for service actions and part changes.
    @param maxDistance (number): The maximum distance to search for vehicles (default: 5.0).
    @return (vehicle, number): The closest vehicle entity and its distance from the player.
--]]
local function GetClosestVehicle(maxDistance)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local vehicles = GetGamePool("CVehicle")
    local closestDistance = maxDistance or 5.0
    local closestVehicle = 0
    for _, veh in ipairs(vehicles) do
        local distance = #(playerCoords - GetEntityCoords(veh))
        if distance < closestDistance then
            closestDistance = distance
            closestVehicle = veh
        end
    end
    return closestVehicle, closestDistance
end

--[[
    Gets the license plate text of a vehicle entity.
    Returns "UNKNOWN" if the entity does not exist.
    @param vehicle (entity): The vehicle entity to check.
    @return (string): The vehicle's license plate text, or "UNKNOWN" if not found.
--]]
local function GetVehiclePlate(vehicle)
    return DoesEntityExist(vehicle) and GetVehicleNumberPlateText(vehicle) or "UNKNOWN"
end

--[[
    Converts a distance in meters to either miles or kilometers, depending on config.
    Used for displaying mileage in the preferred unit for your server.
    @param meters (number): The distance in meters.
    @return (number): The converted distance (miles or kilometers).
--]]
local function convertDistance(meters)
    -- If Config.Unit is "mile", convert meters to miles. Otherwise, convert to kilometers.
    return Config.Unit == "mile" and meters * 0.000621371 or meters / 1000
end

--[[
    Updates the spark plug wear for the given vehicle.
    - Calculates how much the spark plugs have worn based on distance driven since last change.
    - Sends the updated wear value to the server for saving.
    - If the spark plugs are fully worn, there is a chance for a misfire (engine RPM drops).
    @param vehicle (entity): The vehicle entity to update.
--]]
local function updateSparkPlugWear(vehicle)
    if not Config.WearTracking.SparkPlugs then return end -- Skip if spark plug wear tracking is disabled
    if not DoesEntityExist(vehicle) then return end       -- Skip if vehicle doesn't exist

    -- Calculate how far the vehicle has driven since last spark plug change
    local distanceSinceSparkPlugChange = accDistance - lastSparkPlugChange
    -- Calculate wear ratio (0 = new, 1 = fully worn)
    local wearRatio = distanceSinceSparkPlugChange / (Config.SparkPlugChangeDistance * 1000)
    if wearRatio > 1 then wearRatio = 1 end

    sparkPlugWear = wearRatio

    -- Sync wear value with the server
    TriggerServerEvent('wizard_vehiclemileage:server:updateSparkPlugWear', currentPlate, sparkPlugWear)

    -- If spark plugs are fully worn, chance for a misfire
    if sparkPlugWear >= 1.0 then
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if DoesEntityExist(veh) then
            if math.random() < Config.MissfireChance then
                Notify(locale('warning.spark_plug_misfire'), 'warning')
                SetVehicleCurrentRpm(veh, 0.0)
                Citizen.Wait(100)
                SetVehicleCurrentRpm(veh, 0.0)
            end
        end
    end
end

--[[
    Updates the engine damage based on oil and oil filter wear.
    - If oil or filter is overdue, applies engine damage and drains oil faster.
    - Notifies the player if engine health is critical.
    @param vehicle (entity): The vehicle entity to update.
--]]
local function updateEngineDamage(vehicle)
    if not Config.WearTracking.Oil then return end
    if not DoesEntityExist(vehicle) then return end

    -- Calculate wear ratios for oil and oil filter
    local oilDistanceDriven = accDistance - lastOilChange
    local oilWearRatio = oilDistanceDriven / oilchangedist

    local filterDistanceDriven = accDistance - lastOilFilterChange
    local filterWearRatio = filterDistanceDriven / oilfilterchangedist

    -- If either oil or filter is overdue, apply damage
    if oilWearRatio > 1.0 or filterWearRatio > 1.0 then
        local engineHealth = GetVehicleEngineHealth(vehicle)
        local damage = (math.max(oilWearRatio, filterWearRatio) - 1.0) * Config.EngineDamageRate

        -- Simulate oil draining faster as damage increases
        local oilDrainRate = damage * 0.1
        lastOilChange = lastOilChange - (oilDrainRate * oilchangedist)

        -- If engine is very damaged, reset oil change
        if engineHealth < 400.0 then
            lastOilChange = 0.0
        end

        -- Apply engine damage
        SetVehicleEngineHealth(vehicle, math.max(0.0, engineHealth - damage))

        -- Notify player if engine is critical
        local invertal = Config.WarningsInterval * 1000
        if engineHealth < 200.0 then
            local currentTime = GetGameTimer()
            if (currentTime - lastEngineCriticalNotify) >= invertal then
                Notify(locale('warning.engine_critical'), 'error')
                lastEngineCriticalNotify = currentTime
            end
        end
    end
end

--[[
    Updates the air filter performance for the given vehicle.
    - Reduces acceleration as the air filter wears out.
    - Saves and restores original drive force as needed.
    @param vehicle (entity): The vehicle entity to update.
--]]
local function updateAirFilterPerformance(vehicle)
    if not Config.WearTracking.AirFilter then return end
    if not DoesEntityExist(vehicle) then return end

    -- Calculate air filter wear ratio (0 = new, 1 = fully worn)
    local airFilterDistanceDriven = accDistance - lastAirFilterChange
    local airFilterWearRatio = math.min(1.0, airFilterDistanceDriven / airfilterchangedist)

    -- Get and save original drive force if not already saved
    local plate = GetVehiclePlate(vehicle)
    TriggerServerEvent('wizard_vehiclemileage:server:getOriginalDriveForce', plate)
    local currentAcceleration = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce")
    originalDriveForce = originalDriveForce or currentAcceleration
    TriggerServerEvent('wizard_vehiclemileage:server:saveOriginalDriveForce', plate, originalDriveForce)

    -- Reduce acceleration based on wear
    local reducedAcceleration = originalDriveForce * (1.0 - (Config.AccelerationReduction * airFilterWearRatio))
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce", reducedAcceleration)
end

--[[
    Updates the tire wear for the given vehicle.
    - Reduces tire grip as tires wear out.
    @param vehicle (entity): The vehicle entity to update.
--]]
local function updateTireWear(vehicle)
    if not Config.WearTracking.Tires then return end
    if not DoesEntityExist(vehicle) then return end

    -- Calculate tire wear ratio (0 = new, 1 = fully worn)
    local distanceSinceTireChange = accDistance - lastTireChange
    local wearRatio = distanceSinceTireChange / tirechangedist
    if wearRatio > 1 then 
        wearRatio = 1 
    end

    -- Calculate new grip value based on wear
    local newGrip = Config.BaseTireGrip - ((Config.BaseTireGrip - Config.MinTireGrip) * wearRatio)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax", newGrip)
end

--[[
    Updates the brake wear for the given vehicle.
    - Adjusts the brake force based on the current brake wear value.
    - The more worn the brakes, the less effective they become.
    @param vehicle (entity): The vehicle entity to update.
--]]
local function updateBrakeWear(vehicle)
    if not Config.WearTracking.Brakes then return end -- Skip if brake wear tracking is disabled
    if not DoesEntityExist(vehicle) then return end   -- Skip if vehicle doesn't exist

    -- Get the current brake force (for reference, not used in calculation)
    local currentBrakeForce = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce")

    -- Calculate brake efficiency based on wear (1.0 = new, decreases as wear increases)
    local efficiency = 1.0 - (math.min(lastbrakeWear, Config.MaxBrakeWear) / Config.MaxBrakeWear * Config.BrakeEfficiencyLoss)
    local baseBrakeForce = Config.BaseBrakeForce

    -- Set the new brake force on the vehicle, reduced by wear
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce", baseBrakeForce * efficiency)
end

--[[
    Updates the suspension wear for the given vehicle.
    - Calculates how much the suspension has worn based on distance driven since last change.
    - Saves and restores original suspension force and raise values as needed.
    - Applies new suspension values to the vehicle based on wear.
    @param vehicle (entity): The vehicle entity to update.
--]]
local function updateSuspensionWear(vehicle)
    if not Config.WearTracking.Suspension then return end -- Skip if suspension wear tracking is disabled
    if not DoesEntityExist(vehicle) then return end       -- Skip if vehicle doesn't exist

    -- Calculate how far the vehicle has driven since last suspension change
    local distanceSinceSuspensionChange = accDistance - lastSuspensionChange
    -- Calculate wear ratio (0 = new, 1 = fully worn)
    local wearRatio = distanceSinceSuspensionChange / (Config.SuspensionChangeDistance * 1000)
    if wearRatio > 1 then wearRatio = 1 end

    local plate = GetVehiclePlate(vehicle)
    -- Request original suspension values from the server (if not already cached)
    TriggerServerEvent('wizard_vehiclemileage:server:getOriginalSuspensionValue', plate)

    suspensionWear = wearRatio

    -- Sync wear value with the server
    TriggerServerEvent('wizard_vehiclemileage:server:updateSuspensionWear', currentPlate, suspensionWear)

    -- Get or save original suspension force and raise values
    local originalForce = originalSuspensionForce or GetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionForce")
    local originalRaise = originalSuspensionRaise or GetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionRaise")

    if not originalSuspensionForce or originalSuspensionForce == 0 then
        originalSuspensionForce = originalForce
        TriggerServerEvent('wizard_vehiclemileage:server:saveOriginalSuspensionForce', currentPlate, originalForce)
    end
    if not originalSuspensionRaise then
        originalSuspensionRaise = originalRaise
        TriggerServerEvent('wizard_vehiclemileage:server:saveOriginalSuspensionRaise', currentPlate, originalRaise)
    end

    -- Calculate new suspension values based on wear
    local newForce = originalForce * (1.0 - suspensionWear)
    local newRaise = originalRaise * (1.0 - suspensionWear)

    -- Apply new suspension values to the vehicle
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionForce", newForce)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionRaise", newRaise)
end

--[[
    Updates the clutch wear for the given vehicle.
    - Calculates clutch efficiency based on wear.
    - If the clutch is very worn (efficiency <= 20%), simulates clutch failure and possible engine stall.
    - Notifies the player if the vehicle stalls due to clutch wear.
    @param vehicle (entity): The vehicle entity to update.
--]]
local function updateClutchWear(vehicle)
    if not DoesEntityExist(vehicle) then return end

    -- Calculate clutch efficiency (1.0 = new, decreases as wear increases)
    local efficiency = 1.0 - (math.min(lastClutchWear, Config.MaxClutchWear) / Config.MaxClutchWear * Config.ClutchEfficiencyLoss)

    -- If clutch is very worn, simulate clutch failure and possible stall
    if efficiency <= 0.2 then
        -- Simulate clutch slipping/failure
        Citizen.InvokeNative(GetHashKey('SET_VEHICLE_CLUTCH') & 0xFFFFFFFF, vehicle, -1.0)
        -- Random chance to stall the engine
        if math.random() < Config.StallChance then
            SetVehicleEngineOn(vehicle, false, true, true)
            Notify(locale('warning.stalled'), 'warning')
        end
    else
        -- You can add logic here for normal clutch operation if needed
        local baseClutchForce = Config.BaseClutchForce
    end
end

--[[
    Opens the service menu for the player, using the configured menu system.
    - If Config.Menu is "ox", shows the ox_lib context menu.
    - If Config.Menu is "qb", opens the qb-menu with all available service options.
    Each menu option triggers a client event to perform the selected maintenance action.
--]]
local function openServiceMenu()
    if Config.Menu == "ox" then
        -- Show ox_lib context menu
        lib.showContext("vehicle_service_menu")
    elseif Config.Menu == "qb" then
        -- Open qb-menu with all service options
        exports["qb-menu"]:openMenu({
            {
                header = "Wizard Mileage Service Menu",
                isMenuHeader = true,
            },
            {
                header = locale("target.changeoilfilter"),
                txt = "Change oil filter",
                params = { event = "wizard_vehiclemileage:client:changeoilfilter" }
            },
            {
                header = locale("target.changeairfilter"),
                txt = "Change air filter",
                params = { event = "wizard_vehiclemileage:client:changeairfilter" }
            },
            {
                header = locale("target.changetires"),
                txt = "Change vehicle tires",
                params = { event = "wizard_vehiclemileage:client:changetires" }
            },
            {
                header = locale("target.changebrakes"),
                txt = "Service vehicle brakes",
                params = { event = "wizard_vehiclemileage:client:changebrakes" }
            },
            {
                header = locale("target.changeclutch"),
                txt = "Replace vehicle clutch",
                params = { event = "wizard_vehiclemileage:client:changeclutch" }
            },
            {
                header = locale("target.changesuspension"),
                txt = "Replace vehicle suspension",
                params = { event = "wizard_vehiclemileage:client:changesuspension" }
            },
            {
                header = locale("target.changesparkplug"),
                txt = "Replace spark plugs",
                params = { event = "wizard_vehiclemileage:client:changesparkplug" }
            },
        })
    end
end

--[[
    Sends any cached clutch or brake wear data to the server for saving.
    This function is called when the player exits the vehicle or at certain intervals,
    ensuring that wear data is not lost and is always up to date on the server.
    It only sends data if the player is in a vehicle and a plate is set,
    and only for parts that have been marked as "dirty" (changed since last sync).
--]]
local function sendCachedWearData()
    if inVehicle and currentPlate then
        -- If clutch wear has changed, send it to the server and reset the dirty flag
        if clutchWearDirty then
            TriggerServerEvent('wizard_vehiclemileage:server:updateClutchWear', currentPlate, cachedClutchWear)
            clutchWearDirty = false
        end
        -- If brake wear has changed, send it to the server and reset the dirty flag
        if brakeWearDirty then
            TriggerServerEvent('wizard_vehiclemileage:server:updateBrakeWear', currentPlate, cachedBrakeWear)
            brakeWearDirty = false
        end
    end
end



---------------- Threads ----------------
--[[
    Main thread for mileage and wear tracking.
    This thread constantly checks if the player is in a vehicle, updates mileage, wear, and UI,
    and handles entering/exiting vehicles and syncing data with the server.
--]]
Citizen.CreateThread(function()
    -- Send initial configuration to the NUI (UI)
    SendNUIMessage({
        type = "Configuration",
        maxMil = Config.MaxMileageDisplay,
        language = Config.Language
    })
    local waitTime = 2000 -- Default wait time between checks (ms)
    while true do
        Citizen.Wait(waitTime)
        local ped = PlayerPedId()
        local isInVehicle = IsPedInAnyVehicle(ped, false)
        if isInVehicle then
            local veh = GetVehiclePedIsIn(ped, false)
            local vehicleClass = GetVehicleClass(veh)
            -- Hide UI if vehicle class is disabled
            if Config.DisabledVehicleClasses[vehicleClass] then
                SendNUIMessage({
                    type = "toggleMileage",
                    visible = false
                })
            else
                -- Handle entering a vehicle
                if not inVehicle then
                    inVehicle = true
                    lastPos = GetEntityCoords(veh)
                    currentPlate = GetVehiclePlate(veh)
                    if IsVehicleOwned(currentPlate) then
                        waitingForData = true
                        accDistance = 0.0
                        TriggerServerEvent('wizard_vehiclemileage:server:retrieveMileage', currentPlate)
                        if mileageUIVisible then
                            SendNUIMessage({
                                type = "toggleMileage",
                                visible = true
                            })
                            mileageVisible = true
                        end
                    else
                        SendNUIMessage({
                            type = "toggleMileage",
                            visible = false
                        })
                    end
                    waitTime = 1500 -- Reduce wait time for faster updates while in vehicle
                else
                    -- Handle mileage and wear updates while in vehicle
                    if not waitingForData then
                        local currentPos = GetEntityCoords(veh)
                        local delta = getDistance(lastPos, currentPos)
                        accDistance = accDistance + delta
                        lastPos = currentPos
                        local displayedMileage = convertDistance(accDistance)
                
                        -- Update UI with new mileage
                        SendNUIMessage({
                            type = "updateMileage",
                            mileage = displayedMileage,
                            unit = (Config.Unit == "mile" and "miles" or "km")
                        })
                
                        -- Update all wear systems
                        updateSparkPlugWear(veh)
                        updateEngineDamage(veh)
                        updateAirFilterPerformance(veh)
                        updateSuspensionWear(veh)
                        updateTireWear(veh)
                    end
                end
            end
        else
            -- Handle exiting a vehicle
            if inVehicle then
                if currentPlate and IsVehicleOwned(currentPlate) then
                    local savedPlate = currentPlate
                    local savedDistance = accDistance
                    
                    sendCachedWearData() -- Sync any dirty wear data
                    TriggerServerEvent('wizard_vehiclemileage:server:updateMileage', savedPlate, savedDistance)
                    Wait(100)
                end
                -- Reset all state variables
                inVehicle = false
                lastPos = nil
                accDistance = 0.0
                currentPlate = nil
                waitingForData = false
                lastOilChange = 0.0
                lastOilFilterChange = 0.0
                lastAirFilterChange = 0.0
                lastTireChange = 0.0
                lastbrakeChange = 0.0
                lastbrakeWear = 0.0
                lastClutchChange = 0.0
                lastClutchWear = 0.0
                lastSuspensionChange = 0.0
                suspensionWear = 0.0
                lastSparkPlugChange = 0.0
                sparkPlugWear = 0.0
                cachedClutchWear = 0.0
                cachedBrakeWear = 0.0
                clutchWearDirty = false
                brakeWearDirty = false
                -- Hide the mileage UI
                SendNUIMessage({
                    type = "toggleMileage",
                    visible = false
                })
                waitTime = 2000 -- Restore default wait time
            end
        end
    end
end)

--[[
    Clutch wear tracking thread.
    This thread monitors gear changes while the player is in a vehicle and updates clutch wear accordingly.
    - Only runs if clutch wear tracking is enabled in the config.
    - Increases clutch wear each time the player shifts gears (with a cooldown to prevent rapid wear).
    - Larger gear jumps (e.g., 1st to 3rd) cause more wear.
    - If wear exceeds the maximum, it is capped.
    - Marks clutch wear as "dirty" so it will be synced to the server.
    - Calls updateClutchWear to apply any clutch effects (like stalling).
--]]
Citizen.CreateThread(function()
    if not Config.WearTracking.Clutch then return end
    local prevGear = 0
    local lastShiftTime = 0
    local shiftCooldown = 500 -- Minimum ms between gear shifts to count as wear
    while true do
        Citizen.Wait(1000)
        if inVehicle and currentPlate and allowSmartGearDetect then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if DoesEntityExist(veh) then
                if IsVehicleOwned(currentPlate) then
                    local currentGear = GetVehicleCurrentGear(veh)
                    local currentTime = GetGameTimer()
                    -- Only count gear changes after cooldown
                    if (currentGear ~= prevGear) and ((currentTime - lastShiftTime) > shiftCooldown) then
                        local gearDiff = math.abs(currentGear - prevGear)
                        local wearIncrement = Config.ClutchWearRate * gearDiff
                        -- Extra wear for skipping more than one gear
                        if gearDiff > 1 then
                            wearIncrement = wearIncrement * 1.5
                        end
                        lastClutchWear = lastClutchWear + wearIncrement
                        if lastClutchWear > Config.MaxClutchWear then
                            lastClutchWear = Config.MaxClutchWear
                        end
                        cachedClutchWear = lastClutchWear
                        clutchWearDirty = true
                        updateClutchWear(veh)
                        lastShiftTime = currentTime
                        prevGear = currentGear
                    end
                end
            end
        end
    end
end)

--[[
    Brake wear tracking thread.
    This thread monitors the player's braking while in a vehicle and increases brake wear accordingly.
    - Only runs if brake wear tracking is enabled in the config.
    - Increases brake wear each time the player presses the brake (default key: S or brake control).
    - Only increases wear if the vehicle is moving and in gear.
    - Caps the wear at the configured maximum.
    - Marks brake wear as "dirty" so it will be synced to the server.
    - Calls updateBrakeWear to apply any brake effects (like reduced braking power).
--]]
Citizen.CreateThread(function()
    if not Config.WearTracking.Brakes then return end
    while true do
        Citizen.Wait(1000)
        if inVehicle and currentPlate then
            if IsVehicleOwned(currentPlate) then
                local ped = PlayerPedId()
                local veh = GetVehiclePedIsIn(ped, false)
                if DoesEntityExist(veh) and IsControlPressed(0, 72) then -- 72 is the brake control
                    local speed = GetEntitySpeed(veh)
                    local gear = GetVehicleCurrentGear(veh)
                    if speed > 0 and gear > 0 then
                        lastbrakeWear = lastbrakeWear + Config.BrakeWearRate
                        if lastbrakeWear > Config.MaxBrakeWear then lastbrakeWear = Config.MaxBrakeWear end
                        cachedBrakeWear = lastbrakeWear
                        brakeWearDirty = true
                        updateBrakeWear(veh)
                    end
                end
            end
        end
    end
end)

--[[
    Targeting script handler.
    This thread sets up vehicle interaction targets for supported targeting systems (ox_target, qb-target).
    - Adds a "Service Vehicle" option to all vehicles for mechanics (or anyone, if job not required).
    - Checks if the player is not in a vehicle and owns the vehicle before allowing interaction.
    - Handles job and grade checks if required.
    - Opens the service menu when the target is selected.
    - Also registers the ox_lib context menu if using ox as the menu system.
--]]
Citizen.CreateThread(function()
    if not Config.UseTarget then
        return
    end
    local targetConfig = {
        ox = function()
            exports.ox_target:addGlobalVehicle({
                {
                    name = "vehicle_service",
                    icon = "fas fa-wrench",
                    label = "Service Vehicle",
                    canInteract = function(entity)
                        local playerPed = PlayerPedId()
                        if IsPedInAnyVehicle(playerPed, false) then
                            return false
                        end
                        local plate = GetVehicleNumberPlateText(entity)
                        return IsVehicleOwned(plate)
                    end,
                    onSelect = function()
                        if Config.JobRequired then
                            local Job, Grade = CheckJob()
                            if Job == Config.MechanicJob then
                                if Grade >= Config.MinimumJobGrade then
                                    Wait(100)
                                else
                                    Notify(locale("error.low_grade"), "error")
                                    return
                                end
                            else
                                Notify(locale("error.not_mechanic"), "error")
                                return
                            end
                        end
                        openServiceMenu()
                    end
                }
            })
        end,
        qb = function()
            exports["qb-target"]:AddGlobalVehicle({
                options = {
                    {
                        type = "client",
                        icon = "fas fa-wrench",
                        label = "Service Vehicle",
                        canInteract = function(entity)
                            local playerPed = PlayerPedId()
                            if IsPedInAnyVehicle(playerPed, false) then
                                return false
                            end
                            local plate = GetVehicleNumberPlateText(entity)
                            return IsVehicleOwned(plate)
                        end,
                        action = function()
                            if Config.JobRequired then
                                local Job, Grade = CheckJob()
                                if Job == Config.MechanicJob then
                                    if Grade >= Config.MinimumJobGrade then
                                        Wait(100)
                                    else
                                        Notify(locale("error.low_grade"), "error")
                                        return
                                    end
                                else
                                    Notify(locale("error.not_mechanic"), "error")
                                    return
                                end
                            end
                            openServiceMenu()
                        end
                    }
                },
                distance = 2.5
            })
        end
    }
    local targetFunc = targetConfig[Config.Targeting]
    if targetFunc then
        targetFunc()
    end
    -- Register ox_lib context menu if using ox as the menu system
    if Config.Menu == "ox" then
        lib.registerContext({
            id = "vehicle_service_menu",
            title = "Wizard Mileage Service Menu",
            options = {
                {
                    title = locale("target.changesparkplug"),
                    description = "Replace spark plugs",
                    icon = "fas fa-bolt",
                    onSelect = function()
                        TriggerEvent('wizard_vehiclemileage:client:changesparkplug')
                    end
                },
                {
                    title = locale("target.changeoil"),
                    description = "Change vehicle oil",
                    icon = "oil-can",
                    onSelect = function()
                        TriggerEvent('wizard_vehiclemileage:client:changeoil')
                    end
                },
                {
                    title = locale("target.changeoilfilter"),
                    description = "Change oil filter",
                    icon = "filter",
                    onSelect = function()
                        TriggerEvent('wizard_vehiclemileage:client:changeoilfilter')
                    end
                },
                {
                    title = locale("target.changeairfilter"),
                    description = "Change air filter",
                    icon = "wind",
                    onSelect = function()
                        TriggerEvent('wizard_vehiclemileage:client:changeairfilter')
                    end
                },
                {
                    title = locale("target.changetires"),
                    description = "Change vehicle tires",
                    icon = "fa-regular fa-circle",
                    onSelect = function()
                        TriggerEvent('wizard_vehiclemileage:client:changetires')
                    end
                },
                {
                    title = locale("target.changebrakes"),
                    description = "Service vehicle brakes",
                    icon = "fas fa-record-vinyl",
                    onSelect = function()
                        TriggerEvent('wizard_vehiclemileage:client:changebrakes')
                    end
                },
                {
                    title = locale("target.changesuspension"),
                    description = "Replace vehicle suspension",
                    icon = "fas fa-car-burst",
                    onSelect = function()
                        TriggerEvent('wizard_vehiclemileage:client:changesuspension')
                    end
                },
                {
                    title = locale("target.changeclutch"),
                    description = "Replace vehicle clutch",
                    icon = "fas fa-cog",
                    onSelect = function()
                        TriggerEvent('wizard_vehiclemileage:client:changeclutch')
                    end
                }
            }
        })
    end
end)

--[[
    UI wear update thread.
    This thread runs every 5 seconds and calculates the remaining life percentage for each tracked vehicle part.
    - For each enabled wear system (spark plugs, oil, filter, air filter, tires, brakes, suspension, clutch),
      it calculates the percentage of life remaining based on distance driven or wear value.
    - The calculated percentages are sent to the NUI (UI) for display.
    - This keeps the UI up to date with the latest wear status for all parts.
--]]
Citizen.CreateThread(function()
    while true do
        Wait(5000)
        if Config.WearTracking.SparkPlugs then
            sparkPlugDistanceDriven = accDistance - lastSparkPlugChange
            sparkPlugLifeRemaining = math.max(0, sparkPlugchangedist - sparkPlugDistanceDriven)
            sparkPlugPercentage = math.floor((sparkPlugLifeRemaining / sparkPlugchangedist) * 100)
        end
        if Config.WearTracking.Oil then
            oilDistanceDriven = accDistance - lastOilChange
            oilLifeRemaining = math.max(0, oilchangedist - oilDistanceDriven)
            oilPercentage = math.floor((oilLifeRemaining / oilchangedist) * 100)
        
            filterDistanceDriven = accDistance - lastOilFilterChange
            filterLifeRemaining = math.max(0, oilfilterchangedist - filterDistanceDriven)
            filterPercentage = math.floor((filterLifeRemaining / oilfilterchangedist) * 100)
        end
        if Config.WearTracking.AirFilter then
            airFilterDistanceDriven = accDistance - lastAirFilterChange
            airFilterLifeRemaining = math.max(0, airfilterchangedist - airFilterDistanceDriven)
            airFilterPercentage = math.floor((airFilterLifeRemaining / airfilterchangedist) * 100)
        end
        if Config.WearTracking.Tires then
            tireDistanceDriven = accDistance - lastTireChange
            tireLifeRemaining = math.max(0, tirechangedist - tireDistanceDriven)
            tirePercentage = math.floor((tireLifeRemaining / tirechangedist) * 100)
        end
        if Config.WearTracking.Brakes then
            brakePercentage = math.floor((1 - (lastbrakeWear / Config.MaxBrakeWear)) * 100)
        end
        if Config.WearTracking.Suspension then
            suspensionDistanceDriven = accDistance - lastSuspensionChange
            suspensionLifeRemaining = math.max(0, Config.SuspensionChangeDistance * 1000 - suspensionDistanceDriven)
            suspensionPercentage = math.floor((suspensionLifeRemaining / (Config.SuspensionChangeDistance * 1000)) * 100)
        end
        if Config.WearTracking.Clutch then
            clutchPercentage = math.floor((1 - (lastClutchWear / Config.MaxClutchWear)) * 100)
        end
        SendNUIMessage({
            type = "updateWear",
            showUI = false,
            sparkPlugPercentage = sparkPlugPercentage,
            oilPercentage = oilPercentage,
            filterPercentage = filterPercentage,
            airFilterPercentage = airFilterPercentage,
            tirePercentage = tirePercentage,
            brakePercentage = brakePercentage,
            suspensionPercentage = suspensionPercentage,
            clutchPercentage = clutchPercentage
        })
    end
end)



---------------- Net Events ----------------
--[[
    Admin checking callback.
    This event is triggered by the server to return the result of an admin check.
    It looks up the callback function by its unique ID and calls it with the admin status (true/false).
    After calling, it removes the callback from the table to prevent memory leaks.
    @param cbId (number): The unique callback ID.
    @param isAdmin (boolean): Whether the player is an admin.
--]]
RegisterNetEvent('wizard_vehiclemileage:client:isAdminCallback')
AddEventHandler('wizard_vehiclemileage:client:isAdminCallback', function(cbId, isAdmin)
    if adminCallbacks[cbId] then
        adminCallbacks[cbId](isAdmin)
        adminCallbacks[cbId] = nil
    end
end)

--[[
    Handles the spark plug change event.
    Checks job/inventory requirements, plays animation, removes item, and updates server and local state.
--]]
RegisterNetEvent('wizard_vehiclemileage:client:changesparkplug')
AddEventHandler('wizard_vehiclemileage:client:changesparkplug', function()
    if Config.JobRequired then
        local Job, Grade = CheckJob()
        if Job == Config.MechanicJob then
            if Grade >= Config.MinimumJobGrade then
                Wait(100)
            else
                Notify(locale("error.low_grade"), "error")
                return
            end
        else
            Notify(locale("error.not_mechanic"), "error")
            return
        end
    end
    if Config.InventoryItems and not checkInventoryItem(Config.Items.SparkPlug) then
        Notify(locale("error.no_spark_plug"), "error")
        return
    end
    local playerPed = PlayerPedId()
    local closestVehicle = GetClosestVehicle(5.0)
    if closestVehicle == 0 then
        Notify(locale("error.no_vehicle_nearby"), "error")
        return
    end
    local animDict = Config.ChangeSparkPlug.AnimationDict
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end
    TaskPlayAnim(playerPed, animDict, Config.ChangeSparkPlug.Animation, 8.0, -8.0, -1, 1, 0, false, false, false)
    if DisplayProgressBar(Config.ChangeSparkPlug.Duration, locale("progress.changingsparkplug"), Config.ChangeSparkPlug) then
        TriggerServerEvent('wizard_vehiclemileage:server:removeItem', Config.Items.SparkPlug, 1)
        local plate = GetVehicleNumberPlateText(closestVehicle)
        Notify(locale("info.spark_plug_changed"), "success")
        TriggerServerEvent("wizard_vehiclemileage:server:updateSparkPlugChange", plate)
        TriggerServerEvent("wizard_vehiclemileage:server:updateSparkPlugWear", plate, 0)
        sparkPlugWear = 0
        updateSparkPlugWear(closestVehicle)
    end
    ClearPedTasks(playerPed)
end)

--[[
    Handles the oil change event.
    Checks job/inventory requirements, plays animation, removes item, and updates server and local state.
--]]
RegisterNetEvent('wizard_vehiclemileage:client:changeoil')
AddEventHandler('wizard_vehiclemileage:client:changeoil', function()
    if Config.JobRequired then
        local Job, Grade = CheckJob()
        if Job == Config.MechanicJob then
            if Grade >= Config.MinimumJobGrade then
                Wait(100)
            else
                Notify(locale("error.low_grade"), "error")
                return
            end
        else
            Notify(locale("error.not_mechanic"), "error")
            return
        end
    end
    if Config.InventoryItems and not checkInventoryItem(Config.Items.EngineOil) then
        Notify(locale("error.no_oil"), "error")
        return
    end
    local playerPed = PlayerPedId()
    local closestVehicle = GetClosestVehicle(5.0)
    if closestVehicle == 0 then
        Notify(locale("error.no_vehicle_nearby"), "error")
        return
    end
    if not IsVehicleDoorFullyOpen(closestVehicle, 4) then
        SetVehicleDoorOpen(closestVehicle, 4, false, true)
        Wait(500)
    end
    local animDict = Config.ChangeOilFilter.AnimationDict
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end
    local offset = GetOffsetFromEntityInWorldCoords(closestVehicle, 0.0, 2.0, 0.0)
    TaskGoStraightToCoord(playerPed, offset.x, offset.y, offset.z, 1.0, -1, -1, 0.0)
    Wait(1000)
    TaskPlayAnim(playerPed, animDict, Config.ChangeOilFilter.Animation, 8.0, -8.0, -1, 1, 0, false, false, false)
    if DisplayProgressBar(Config.ChangeOil.Duration, locale("progress.changingoil"), Config.ChangeOil) then
        TriggerServerEvent('wizard_vehiclemileage:server:removeItem', Config.Items.EngineOil, 1)
        local plate = GetVehicleNumberPlateText(closestVehicle)
        Notify(locale("info.oil_changed"), "success")
        TriggerServerEvent("wizard_vehiclemileage:server:updateOilChange", plate)
        SetVehicleDoorShut(closestVehicle, 4, false)
    else
        SetVehicleDoorShut(closestVehicle, 4, false)
    end
    ClearPedTasks(playerPed)
end)

--[[
    Handles the oil filter change event.
    Checks job/inventory requirements, plays animation, removes item, and updates server and local state.
--]]
RegisterNetEvent('wizard_vehiclemileage:client:changeoilfilter')
AddEventHandler('wizard_vehiclemileage:client:changeoilfilter', function()
    if Config.InventoryItems and not checkInventoryItem(Config.Items.OilFilter) then
        Notify(locale("error.no_oil_filter"), "error")
        return
    end
    if Config.JobRequired then
        local Job, Grade = CheckJob()
        if Job == Config.MechanicJob then
            if Grade >= Config.MinimumJobGrade then
                Wait(100)
            else
                Notify(locale("error.low_grade"), "error")
                return
            end
        else
            Notify(locale("error.not_mechanic"), "error")
            return
        end
    end
    local playerPed = PlayerPedId()
    local closestVehicle = GetClosestVehicle(5.0)
    if closestVehicle == 0 then
        Notify(locale("error.no_vehicle_nearby"), "error")
        return
    end
    if not IsVehicleDoorFullyOpen(closestVehicle, 4) then
        SetVehicleDoorOpen(closestVehicle, 4, false, true)
        Wait(500)
    end
    local animDict = Config.ChangeOil.AnimationDict
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end
    local offset = GetOffsetFromEntityInWorldCoords(closestVehicle, 0.0, 2.0, 0.0)
    TaskGoStraightToCoord(playerPed, offset.x, offset.y, offset.z, 1.0, -1, -1, 0.0)
    Wait(1000)
    TaskPlayAnim(playerPed, animDict, Config.ChangeOilFilter.Animation, 8.0, -8.0, -1, 1, 0, false, false, false)
    if DisplayProgressBar(Config.ChangeOilFilter.Duration, locale("progress.changingoilfilter"), Config.ChangeOilFilter) then
        TriggerServerEvent('wizard_vehiclemileage:server:removeItem', Config.Items.OilFilter, 1)
        local plate = GetVehicleNumberPlateText(closestVehicle)
        Notify(locale("info.filter_changed"), "success")
        TriggerServerEvent("wizard_vehiclemileage:server:updateOilFilter", plate)
        SetVehicleDoorShut(closestVehicle, 4, false)
    else
        SetVehicleDoorShut(closestVehicle, 4, false)
    end
    ClearPedTasks(playerPed)
end)

--[[
    Handles the air filter change event.
    Checks job/inventory requirements, plays animation, removes item, and updates server and local state.
--]]
RegisterNetEvent('wizard_vehiclemileage:client:changeairfilter')
AddEventHandler('wizard_vehiclemileage:client:changeairfilter', function()
    if Config.JobRequired then
        local Job, Grade = CheckJob()
        if Job == Config.MechanicJob then
            if Grade >= Config.MinimumJobGrade then
                Wait(100)
            else
                Notify(locale("error.low_grade"), "error")
                return
            end
        else
            Notify(locale("error.not_mechanic"), "error")
            return
        end
    end
    if Config.InventoryItems and not checkInventoryItem(Config.Items.AirFilter) then
        Notify(locale("error.no_air_filter"), "error")
        return
    end
    local playerPed = PlayerPedId()
    local closestVehicle = GetClosestVehicle(5.0)
    if closestVehicle == 0 then
            Notify(locale("error.no_vehicle_nearby"), "error")
            return
    end
    if not IsVehicleDoorFullyOpen(closestVehicle, 4) then
        SetVehicleDoorOpen(closestVehicle, 4, false, true)
        Wait(500)
    end
    local animDict = Config.ChangeAirFilter.AnimationDict
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end
    local offset = GetOffsetFromEntityInWorldCoords(closestVehicle, 0.0, 2.0, 0.0)
    TaskGoStraightToCoord(playerPed, offset.x, offset.y, offset.z, 1.0, -1, -1, 0.0)
    Wait(1000)
    TaskPlayAnim(playerPed, animDict, Config.ChangeAirFilter.Animation, 8.0, -8.0, -1, 1, 0, false, false, false)
    if DisplayProgressBar(Config.ChangeAirFilter.Duration, locale("progress.changingairfilter"), Config.ChangeAirFilter) then
        TriggerServerEvent('wizard_vehiclemileage:server:removeItem', Config.Items.AirFilter, 1)
        local plate = GetVehicleNumberPlateText(closestVehicle)
        Notify(locale("info.air_filter_changed"), "success")
        TriggerServerEvent("wizard_vehiclemileage:server:updateAirFilter", plate)
        SetVehicleDoorShut(closestVehicle, 4, false)
    else
        SetVehicleDoorShut(closestVehicle, 4, false)
    end
    ClearPedTasks(playerPed)
end)

--[[
    Handles the tire change event.
    Checks job/inventory requirements, plays animation, removes item, and updates server and local state.
--]]
RegisterNetEvent('wizard_vehiclemileage:client:changetires')
AddEventHandler('wizard_vehiclemileage:client:changetires', function()
    if Config.JobRequired then
        local Job, Grade = CheckJob()
        if Job == Config.MechanicJob then
            if Grade >= Config.MinimumJobGrade then
                Wait(100)
            else
                Notify(locale("error.low_grade"), "error")
                return
            end
        else
            Notify(locale("error.not_mechanic"), "error")
            return
        end
    end
    if Config.InventoryItems and not checkInventoryItem(Config.Items.Tires) then
        Notify(locale("error.no_tires"), "error")
        return
    end
    local playerPed = PlayerPedId()
    local closestVehicle = GetClosestVehicle(5.0)
    if closestVehicle == 0 then
        Notify(locale("error.no_vehicle_nearby"), "error")
        return
    end
    local animDict = Config.ChangeTires.AnimationDict
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end
    TaskPlayAnim(playerPed, animDict, Config.ChangeTires.Animation, 8.0, -8.0, -1, 1, 0, false, false, false)
    if DisplayProgressBar(Config.ChangeTires.Duration, locale("progress.changingtires"), Config.ChangeTires) then
        TriggerServerEvent('wizard_vehiclemileage:server:removeItem', Config.Items.Tires, 1)
        local plate = GetVehicleNumberPlateText(closestVehicle)
        lastTireChange = accDistance
        for i = 0, 5 do
            SetVehicleTyreFixed(closestVehicle, i)
        end
        Notify(locale("info.tire_changed"), "success")
        TriggerServerEvent("wizard_vehiclemileage:server:updateTireChange", plate)
        SetVehicleHandlingFloat(closestVehicle, "CHandlingData", "fTractionCurveMax", Config.BaseTireGrip)
    end
    ClearPedTasks(playerPed)
end)

--[[
    Handles the brake change event.
    Checks job/inventory requirements, plays animation, removes item, and updates server and local state.
--]]
RegisterNetEvent('wizard_vehiclemileage:client:changebrakes')
AddEventHandler('wizard_vehiclemileage:client:changebrakes', function()
    if Config.JobRequired then
        local Job, Grade = CheckJob()
        if Job == Config.MechanicJob then
            if Grade >= Config.MinimumJobGrade then
                Wait(100)
            else
                Notify(locale("error.low_grade"), "error")
                return
            end
        else
            Notify(locale("error.not_mechanic"), "error")
            return
        end
    end
    if Config.InventoryItems and not checkInventoryItem(Config.Items.BrakeParts) then
        Notify(locale("error.no_brake_parts"), "error")
        return
    end
    local playerPed = PlayerPedId()
    local closestVehicle = GetClosestVehicle(5.0)
    if closestVehicle == 0 then
        Notify(locale("error.no_vehicle_nearby"), "error")
        return
    end
    local animDict = Config.ChangeBrakes.AnimationDict
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end
    TaskPlayAnim(playerPed, animDict, Config.ChangeBrakes.Animation, 8.0, -8.0, -1, 1, 0, false, false, false)
    if DisplayProgressBar(Config.ChangeBrakes.Duration, locale("progress.changingbrakes"), Config.ChangeBrakes) then
        TriggerServerEvent('wizard_vehiclemileage:server:removeItem', Config.Items.BrakeParts, 1)
        local plate = GetVehicleNumberPlateText(closestVehicle)
        Notify(locale("info.brakes_changed"), "success")
        TriggerServerEvent("wizard_vehiclemileage:server:updateBrakeChange", plate)
        lastbrakeWear = 0.0
        updateBrakeWear(closestVehicle)
    end
    ClearPedTasks(playerPed)
end)

--[[
    Handles the suspension change event.
    Checks job/inventory requirements, plays animation, removes item, and updates server and local state.
--]]
RegisterNetEvent('wizard_vehiclemileage:client:changesuspension')
AddEventHandler('wizard_vehiclemileage:client:changesuspension', function()
    if Config.JobRequired then
        local Job, Grade = CheckJob()
        if Job == Config.MechanicJob then
            if Grade >= Config.MinimumJobGrade then
                Wait(100)
            else
                Notify(locale("error.low_grade"), "error")
                return
            end
        else
            Notify(locale("error.not_mechanic"), "error")
            return
        end
    end
    if Config.InventoryItems and not checkInventoryItem(Config.Items.SusParts) then
        Notify(locale("error.no_suspension_parts"), "error")
        return
    end
    local playerPed = PlayerPedId()
    local closestVehicle = GetClosestVehicle(5.0)
    if closestVehicle == 0 then
        Notify(locale("error.no_vehicle_nearby"), "error")
        return
    end
    local animDict = Config.ChangeSuspension.AnimationDict
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end
    TaskPlayAnim(playerPed, animDict, Config.ChangeSuspension.Animation, 8.0, -8.0, -1, 1, 0, false, false, false)
    if DisplayProgressBar(Config.ChangeSuspension.Duration, locale("progress.changingsuspension"), Config.ChangeSuspension) then
        TriggerServerEvent('wizard_vehiclemileage:server:removeItem', Config.Items.SusParts, 1)
        local plate = GetVehicleNumberPlateText(closestVehicle)
        Notify(locale("info.suspension_changed"), "success")
        TriggerServerEvent("wizard_vehiclemileage:server:updateSuspensionChange", plate)
        TriggerServerEvent("wizard_vehiclemileage:server:updateSuspensionWear", plate, 0)
        suspensionWear = 0
        updateSuspensionWear(closestVehicle)
    end
    ClearPedTasks(playerPed)
end)

--[[
    Handles the clutch change event.
    Checks job/inventory requirements, plays animation, removes item, and updates server and local state.
--]]
RegisterNetEvent('wizard_vehiclemileage:client:changeclutch')
AddEventHandler('wizard_vehiclemileage:client:changeclutch', function()
    if Config.JobRequired then
        local Job, Grade = CheckJob()
        if Job == Config.MechanicJob then
            if Grade >= Config.MinimumJobGrade then
                Wait(100)
            else
                Notify(locale("error.low_grade"), "error")
                return
            end
        else
            Notify(locale("error.not_mechanic"), "error")
            return
        end
    end
    if Config.InventoryItems and not checkInventoryItem(Config.Items.Clutch) then
        Notify(locale("error.no_clutch"), "error")
        return
    end
    local playerPed = PlayerPedId()
        local closestVehicle = GetClosestVehicle(5.0)
        if closestVehicle == 0 then
            Notify(locale("error.no_vehicle_nearby"), "error")
            return
        end
        local animDict = Config.ChangeClutch.AnimationDict
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(10)
        end
        TaskPlayAnim(playerPed, animDict, Config.ChangeClutch.Animation, 8.0, -8.0, -1, 1, 0, false, false, false)
        if DisplayProgressBar(Config.ChangeClutch.Duration, locale("progress.changingclutch"), Config.ChangeClutch) then
            TriggerServerEvent('wizard_vehiclemileage:server:removeItem', Config.Items.Clutch, 1)
            local plate = GetVehicleNumberPlateText(closestVehicle)
            Notify(locale("info.clutch_changed"), "success")
            TriggerServerEvent("wizard_vehiclemileage:server:updateClutchChange", plate)
            TriggerServerEvent("wizard_vehiclemileage:server:updateClutchWear", plate, 0)
            lastClutchWear = 0
            updateClutchWear(closestVehicle)
        end
        ClearPedTasks(playerPed)
end)

--[[
    Receives and sets vehicle mileage and wear data from the server.
    Updates local variables and UI.
--]]
RegisterNetEvent('wizard_vehiclemileage:client:setData')
AddEventHandler('wizard_vehiclemileage:client:setData', function(mileage, oilChange, filterChange, AirfilterChange, tireChange, brakeChange, brakeWear, clutchChange, clutchWear, origDriveForce, lastSuspensionChangeVal, suspensionWearVal, lastSparkPlugChangeVal, sparkPlugWearVal)
    accDistance = mileage or 0.0
    lastOilChange = oilChange or 0.0
    lastOilFilterChange = filterChange or 0.0
    lastAirFilterChange = AirfilterChange or 0.0
    lastTireChange = tireChange or 0.0
    lastbrakeChange = brakeChange or 0.0
    lastbrakeWear = brakeWear or 0.0
    lastClutchChange = clutchChange or 0.0
    lastClutchWear = clutchWear or 0.0
    originalDriveForce = origDriveForce
    lastSuspensionChange = lastSuspensionChangeVal or 0.0
    suspensionWear = suspensionWearVal or 0.0
    lastSparkPlugChange = lastSparkPlugChangeVal or 0.0
    sparkPlugWear = sparkPlugWearVal or 0.0
    waitingForData = false
    local displayedMileage = convertDistance(accDistance)
    SendNUIMessage({
        type = "updateMileage",
        mileage = displayedMileage,
        unit = (Config.Unit == "mile" and "miles" or "km")
    })
end)

--[[
    Receives notification that vehicle data has been updated and refreshes the vehicle list in the UI.
--]]
RegisterNetEvent('wizard_vehiclemileage:client:vehicleDataUpdated')
AddEventHandler('wizard_vehiclemileage:client:vehicleDataUpdated', function()
    TriggerVehicleListCallback(function(vehicles)
        SendNUIMessage({
            type = 'vehicleList',
            vehicles = vehicles
        })
    end)
end)

--[[
    Receives the full vehicle list from the server for admin/database UI.
--]]
RegisterNetEvent('wizard_vehiclemileage:client:getAllVehiclesCallback')
AddEventHandler('wizard_vehiclemileage:client:getAllVehiclesCallback', function(cbId, vehicles)
    if vehicleListCallbacks[cbId] then
        vehicleListCallbacks[cbId](vehicles)
        vehicleListCallbacks[cbId] = nil
    end
end)

--[[
    Receives and applies player UI customization settings from the server.
--]]
RegisterNetEvent('wizard_vehiclemileage:client:setPlayerSettings')
AddEventHandler('wizard_vehiclemileage:client:setPlayerSettings', function(settings)
    if not settings then return end
    mileageUIVisible = settings.mileage_visible
    mileageUISize = settings.mileage_size
    checkwearUISize = settings.checkwear_size
    mileageUIPosX = settings.mileage_pos_x
    mileageUIPosY = settings.mileage_pos_y
    checkwearUIPosX = settings.checkwear_pos_x
    checkwearUIPosY = settings.checkwear_pos_y

    SendNUIMessage({
        type = "updateCustomization",
        mileageVisible = mileageUIVisible,
        mileageSize = mileageUISize,
        checkwearSize = checkwearUISize,
        mileagePosX = mileageUIPosX,
        mileagePosY = mileageUIPosY,
        checkwearPosX = checkwearUIPosX,
        checkwearPosY = checkwearUIPosY,
        removePositionalClass = true
    })
end)

--[[
    Receives and sets the original drive force value for the current vehicle.
--]]
RegisterNetEvent('wizard_vehiclemileage:client:setOriginalDriveForce')
AddEventHandler('wizard_vehiclemileage:client:setOriginalDriveForce', function(driveForce)
    originalDriveForce = driveForce
end)

--[[
    Receives and sets the original suspension raise value for the current vehicle.
--]]
RegisterNetEvent('wizard_vehiclemileage:client:setOriginalSusRaise')
AddEventHandler('wizard_vehiclemileage:client:setOriginalSusRaise', function(susRaise)
    originalSuspensionRaise = susRaise
end)

--[[
    Receives and sets the original suspension force value for the current vehicle.
--]]
RegisterNetEvent('wizard_vehiclemileage:client:setOriginalSusForce')
AddEventHandler('wizard_vehiclemileage:client:setOriginalSusForce', function(susForce)
    originalSuspensionForce = susForce
end)

--[[
    Updates clutch wear for wizard_manualtransmission integration.
--]]
RegisterNetEvent('wizard_vehiclemileage:client:updateClutchWT')
AddEventHandler('wizard_vehiclemileage:client:updateClutchWT', function()
    if not IsVehicleOwned(currentPlate) then return end
    
    lastClutchWear = lastClutchWear + Config.ClutchWearRate
    if lastClutchWear > Config.MaxClutchWear then
        lastClutchWear = Config.MaxClutchWear
    end
    TriggerServerEvent('wizard_vehiclemileage:server:updateClutchWear', currentPlate, lastClutchWear)
    updateClutchWear(veh)
end)

--[[
    Enables or disables smart gear detection for clutch wear tracking.
--]]
RegisterNetEvent('wizard_vehiclemileage:client:smartGearDetect')
AddEventHandler('wizard_vehiclemileage:client:smartGearDetect', function(data)
    allowSmartGearDetect = data
end)

--[[
    Receives script version check results and triggers update notification.
--]]
RegisterNetEvent('wizard_vehiclemileage:client:setOutdated')
AddEventHandler('wizard_vehiclemileage:client:setOutdated', function(data, currentVersion, latestVersion)
    updateCheck(data, currentVersion, latestVersion)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        TriggerServerEvent('wizard_vehiclemileage:server:loadPlayerSettings')
    end
end)
AddEventHandler('playerSpawned', function()
    TriggerServerEvent('wizard_vehiclemileage:server:loadPlayerSettings')
end)

---------------- Autosave system ----------------
--[[ 
    Autosave system.
    If autosave is enabled in the config, this thread will periodically save the current vehicle's mileage to the server.
    - The interval is set by Config.AutosaveInterval (in seconds).
    - Only saves if the player is in a vehicle, the plate is set, the vehicle is owned, and not waiting for data.
    - Helps prevent mileage loss if the player crashes or disconnects unexpectedly.
--]]
if Config.Autosave then
    local autosaveinvl = Config.AutosaveInterval * 1000
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(autosaveinvl)
            if inVehicle and currentPlate and IsVehicleOwned(currentPlate) and not waitingForData then
                TriggerServerEvent('wizard_vehiclemileage:server:updateMileage', currentPlate, accDistance)
            end
        end
    end)
end


---------------- Warning system ----------------
--[[ 
    Warning system.
    If change warnings are enabled in the config, this thread will periodically check all tracked vehicle components for low life/wear.
    - Each component (oil, filter, air filter, tires, spark plugs, suspension, brakes, clutch) has configurable thresholds for warnings and errors.
    - When a threshold is reached, a notification is sent to the player with the severity and suggested action.
    - The check interval is set by Config.WarningsInterval (in seconds).
    - Only runs if the player is in a vehicle and not waiting for data.
--]]
if Config.ChangeWarnings then
    local components = {
        oil = {
            lastChange = function() return lastOilChange end,
            changedist = oilchangedist,
            computeDistance = function() return accDistance - lastOilChange end,
            thresholds = {
                { value = 1, severity = 'error', action = 'replace_immediately' },
                { value = 2, severity = 'warning', action = 'replace_soon' },
                { value = 3, severity = 'warning', action = 'replace_need' },
                { value = 5, severity = 'warning' },
                { value = 10, severity = 'warning' },
                { value = 25, severity = 'info' },
                { value = 50, severity = 'info' }
            },
            localeKey = "warning.remaining_oil"
        },
        filter = {
            lastChange = function() return lastOilFilterChange end,
            changedist = oilfilterchangedist,
            computeDistance = function() return accDistance - lastOilFilterChange end,
            thresholds = {
                { value = 1, severity = 'error', action = 'replace_immediately' },
                { value = 5, severity = 'warning', action = 'replace_soon' },
                { value = 10, severity = 'warning' },
                { value = 25, severity = 'info' }
            },
            localeKey = "warning.remaining_filter"
        },
        airFilter = {
            lastChange = function() return lastAirFilterChange end,
            changedist = airfilterchangedist,
            computeDistance = function() return accDistance - lastAirFilterChange end,
            thresholds = {
                { value = 1, severity = 'error', action = 'replace_immediately' },
                { value = 5, severity = 'warning', action = 'replace_soon' },
                { value = 10, severity = 'warning' },
                { value = 25, severity = 'info' }
            },
            localeKey = "warning.remaining_air_filter"
        },
        tire = {
            lastChange = function() return lastTireChange end,
            changedist = tirechangedist,
            computeDistance = function() return accDistance - lastTireChange end,
            thresholds = {
                { value = 1, severity = 'error', action = 'replace_immediately' },
                { value = 2, severity = 'warning', action = 'replace_soon' },
                { value = 3, severity = 'warning', action = 'replace_need' },
                { value = 5, severity = 'warning', action = 'replace_need' },
                { value = 10, severity = 'warning' },
                { value = 25, severity = 'info' },
                { value = 50, severity = 'info' }
            },
            localeKey = "warning.remaining_tire"
        },
        sparkPlug = {
            lastChange = function() return lastSparkPlugChange end,
            changedist = sparkPlugchangedist,
            computeDistance = function() return accDistance - lastSparkPlugChange end,
            thresholds = {
                { value = 1, severity = 'error', action = 'replace_immediately' },
                { value = 5, severity = 'warning', action = 'replace_soon' },
                { value = 10, severity = 'warning' },
                { value = 25, severity = 'info' }
            },
            localeKey = "warning.remaining_spark_plug"
        },
        suspension = {
            lastChange = function() return lastSuspensionChange end,
            changedist = Config.SuspensionChangeDistance * 1000,
            computeDistance = function() return accDistance - lastSuspensionChange end,
            thresholds = {
                { value = 1, severity = 'error', action = 'replace_immediately' },
                { value = 5, severity = 'warning', action = 'replace_soon' },
                { value = 10, severity = 'warning' },
                { value = 25, severity = 'info' }
            },
            localeKey = "warning.remaining_suspension"
        }
    }
    local staticComponents = {
        brakes = {
            value = function()
                return math.floor((1 - (lastbrakeWear / Config.MaxBrakeWear)) * 100)
            end,
            thresholds = {
                { value = 1, severity = 'error', action = 'replace_immediately' },
                { value = 5, severity = 'warning', action = 'replace_soon' },
                { value = 10, severity = 'warning' },
                { value = 25, severity = 'info' }
            },
            localeKey = "warning.remaining_brakes"
        },
        clutch = {
            value = function()
                return math.floor((1 - (lastClutchWear / Config.MaxClutchWear)) * 100)
            end,
            thresholds = {
                { value = 1, severity = 'error', action = 'replace_immediately' },
                { value = 5, severity = 'warning', action = 'replace_soon' },
                { value = 10, severity = 'warning' },
                { value = 25, severity = 'info' }
            },
            localeKey = "warning.remaining_clutch"
        }
    }
    local function checkComponent(componentData, percentage)
        local baseMessage = locale(componentData.localeKey)
        for _, threshold in ipairs(componentData.thresholds) do
            if percentage <= threshold.value then
                local extraMessage = threshold.action and (" " .. locale("warning." .. threshold.action)) or ""
                Notify(baseMessage .. " " .. threshold.value .. "%!" .. extraMessage, threshold.severity)
                break
            end
        end
    end
    local function checkWearLevels()
        if not inVehicle or not currentPlate then 
            return 
        end
        for key, data in pairs(components) do
            local distDriven = data.computeDistance()
            local lifeRemaining = math.max(0, data.changedist - distDriven)
            local percentage = math.floor((lifeRemaining / data.changedist) * 100)
            checkComponent(data, percentage)
        end
        for key, data in pairs(staticComponents) do
            local percentage = data.value()
            checkComponent(data, percentage)
        end
    end
    local checkInterval = Config.WarningsInterval * 1000
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(checkInterval)
            if inVehicle and not waitingForData then
                checkWearLevels()
            end
        end
    end)
end



---------------- NUI Callbacks ----------------
--[[ 
    UI Notifications callback.
    This NUI callback receives notification requests from the UI and displays them using the configured notification system.
    - Expects `data.message` (string) and `data.type` (string, e.g., "success", "error", "info", "warning").
    - Calls the Notify function to show the message to the player.
    - Responds to the UI with success or error.
--]]
RegisterNUICallback('notify', function(data, cb)
    if data and data.message and data.type then
        Notify(data.message, data.type)
        cb({success = true})
    else
        cb({success = false, error = 'Invalid data'})
    end
end)

--[[
    Request vehicles callback.
    This NUI callback is triggered by the UI to request the current list of vehicles.
    - Calls TriggerVehicleListCallback, which fetches the vehicle list from the server.
    - Sends the vehicle list back to the UI using SendNUIMessage.
    - No data is expected from the UI for this callback.
--]]
RegisterNUICallback('requestVehicleList', function(data, cb)
    TriggerVehicleListCallback(function(vehicles)
        SendNUIMessage({
            type = 'vehicleList',
            vehicles = vehicles
        })
    end)
end) 

--[[
    Update vehicle data callback.
    This NUI callback is triggered by the UI when an admin or user updates a vehicle's maintenance data.
    - Expects `data.vehicle` (table) with all relevant maintenance fields.
    - Ensures all required fields are set (defaults to 0 if missing).
    - Triggers a server event to update the vehicle data in the database.
    - Responds to the UI with success or error.
--]]
RegisterNUICallback('updateVehicleData', function(data, cb)
    if data and data.vehicle then
        local vehicle = data.vehicle
        vehicle.last_oil_change = vehicle.last_oil_change or 0
        vehicle.last_oil_filter_change = vehicle.last_oil_filter_change or 0
        vehicle.last_air_filter_change = vehicle.last_air_filter_change or 0
        vehicle.last_tire_change = vehicle.last_tire_change or 0
        vehicle.last_brakes_change = vehicle.last_brakes_change or 0
        vehicle.brake_wear = vehicle.brake_wear or 0
        vehicle.last_clutch_change = vehicle.last_clutch_change or 0
        vehicle.clutch_wear = vehicle.clutch_wear or 0
        vehicle.last_suspension_change = vehicle.last_suspension_change or 0
        vehicle.last_spark_plug_change = vehicle.last_spark_plug_change or 0

        TriggerServerEvent('wizard_vehiclemileage:server:updateVehicleData', vehicle)
        cb({success = true})
    else
        cb({success = false, error = 'Invalid data'})
    end
end)

--[[
    Delete vehicle data callback.
    This NUI callback is triggered by the UI when an admin or user requests to delete a vehicle's data.
    - Expects `data.plate` (string): the license plate of the vehicle to delete.
    - Triggers a server event to remove the vehicle data from the database.
    - Responds to the UI with success or error.
--]]
RegisterNUICallback('deleteVehicle', function(data, cb)
    if data and data.plate then
        TriggerServerEvent('wizard_vehiclemileage:server:deleteVehicle', data.plate)
        cb({success = true})
    else
        cb({success = false, error = 'Invalid plate'})
    end
end)

--[[
    Save player settings callback.
    This NUI callback is triggered by the UI when the player saves their customization settings.
    - Expects `data` (table) with the player's UI customization preferences.
    - Removes NUI focus from the player.
    - Triggers a server event to save the settings in the database.
    - Sends a message to the UI to close the customization menu.
    - Responds to the UI with an empty callback.
--]]
RegisterNUICallback('savePlayerSettings', function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('wizard_vehiclemileage:server:savePlayerSettings', data)
    SendNUIMessage({
        type = "closeCustomization"
    })
    cb({})
end)

--[[
    Close menu callback.
    This NUI callback is triggered by the UI when the player wants to close the menu.
    - Removes NUI focus from the player.
    - Sends a message to the UI to close the menu.
    - Responds to the UI with an empty callback.
--]]
RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    cb({})
end)


---------------- Commands ----------------
--[[
    Command to open the vehicle mileage customization menu.
    Checks if the player is in a vehicle and has a valid plate.
    If the vehicle is owned, it opens the customization UI.
    If not in a vehicle or not owned, it shows an error notification.
--]]
RegisterCommand(Config.CustomizeCommand, function()
    if inVehicle and currentPlate then
        if not IsVehicleOwned(currentPlate) then Notify(locale('error.not_owned'), 'error') return end
        TriggerServerEvent('wizard_vehiclemileage:server:loadPlayerSettings')
        SetNuiFocus(true, true)
        SendNUIMessage({
            type = "openCustomization"
        })
    else
        Notify(locale('error.not_in_vehicle'), 'error')
    end
end)

--[[
    Command to check vehicle wear and tear.
    Checks if the player is in a vehicle and has a valid plate.
    If the vehicle is owned, it calculates wear percentages and opens the wear UI.
    If not in a vehicle or not owned, it shows an error notification.
--]]
RegisterCommand(Config.CheckWearCommand, function()
    if inVehicle and currentPlate then
        if not IsVehicleOwned(currentPlate) then Notify(locale('error.not_owned'), 'error') return end
        if Config.WearTracking.SparkPlugs then
            sparkPlugDistanceDriven = accDistance - lastSparkPlugChange
            sparkPlugLifeRemaining = math.max(0, sparkPlugchangedist - sparkPlugDistanceDriven)
            sparkPlugPercentage = math.floor((sparkPlugLifeRemaining / sparkPlugchangedist) * 100)
        end
        if Config.WearTracking.Oil then
            oilDistanceDriven = accDistance - lastOilChange
            oilLifeRemaining = math.max(0, oilchangedist - oilDistanceDriven)
            oilPercentage = math.floor((oilLifeRemaining / oilchangedist) * 100)
        
            filterDistanceDriven = accDistance - lastOilFilterChange
            filterLifeRemaining = math.max(0, oilfilterchangedist - filterDistanceDriven)
            filterPercentage = math.floor((filterLifeRemaining / oilfilterchangedist) * 100)
        end
        if Config.WearTracking.AirFilter then
            airFilterDistanceDriven = accDistance - lastAirFilterChange
            airFilterLifeRemaining = math.max(0, airfilterchangedist - airFilterDistanceDriven)
            airFilterPercentage = math.floor((airFilterLifeRemaining / airfilterchangedist) * 100)
        end
        if Config.WearTracking.Tires then
            tireDistanceDriven = accDistance - lastTireChange
            tireLifeRemaining = math.max(0, tirechangedist - tireDistanceDriven)
            tirePercentage = math.floor((tireLifeRemaining / tirechangedist) * 100)
        end
        if Config.WearTracking.Brakes then
            brakePercentage = math.floor((1 - (lastbrakeWear / Config.MaxBrakeWear)) * 100)
        end
        if Config.WearTracking.Suspension then
            suspensionDistanceDriven = accDistance - lastSuspensionChange
            suspensionLifeRemaining = math.max(0, Config.SuspensionChangeDistance * 1000 - suspensionDistanceDriven)
            suspensionPercentage = math.floor((suspensionLifeRemaining / (Config.SuspensionChangeDistance * 1000)) * 100)
        end
        if Config.WearTracking.Clutch then
            clutchPercentage = math.floor((1 - (lastClutchWear / Config.MaxClutchWear)) * 100)
        end
        SendNUIMessage({
            type = "closeCustomization"
        })
        SetNuiFocus(true, false)
        SendNUIMessage({
            type = "updateWear",
            showUI = true,
            sparkPlugPercentage = sparkPlugPercentage,
            oilPercentage = oilPercentage,
            filterPercentage = filterPercentage,
            airFilterPercentage = airFilterPercentage,
            tirePercentage = tirePercentage,
            brakePercentage = brakePercentage,
            suspensionPercentage = suspensionPercentage,
            clutchPercentage = clutchPercentage
        })
    else
        Notify(locale('error.not_in_vehicle'), 'error')
    end
end, false)

--[[
    Command to open the database menu for admins.
    Checks if the player is an admin using the TriggerAdminCallback.
    If admin, opens the database UI and requests the vehicle list from the server.
    If not admin, shows an error notification.
--]]
RegisterCommand(Config.DatabaseCommand, function()
    TriggerAdminCallback(function(isAdmin)
        if isAdmin then
            SetNuiFocus(true, true)
            SendNUIMessage({
                type = 'openDatabaseMenu'
            })
            -- Request vehicle list from server
            TriggerVehicleListCallback(function(vehicles)
                SendNUIMessage({
                    type = 'vehicleList',
                    vehicles = vehicles
                })
            end)
        else
            Notify('You do not have permission to open this menu.', 'error')
        end
    end)
end)



---------------- Exports ----------------
--[[
    Exports for other scripts to interact with vehicle mileage and maintenance data.
    Provides functions to get/set mileage, parts change history, and wear levels.
--]]
exports('GetVehicleMileage', function()
    return accDistance
end)

--[[
    Set vehicle mileage.
    Can be used to set the mileage directly, e.g., for testing or resetting.
    If no mileage is provided, it uses the current accumulated distance.
--]]
exports('SetVehicleMileage', function(mileage)
    accDistance = mileage or accDistance
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
exports('GetVehicleLastPartsChange', function()
    return {
        sparkPlugChange = lastSparkPlugChange,
        oilChange = lastOilChange,
        oilFilterChange = lastOilFilterChange,
        airFilterChange = lastAirFilterChange,
        tireChange = lastTireChange,
        brakeChange = lastbrakeChange,
        suspensionChange = lastSuspensionChange,
        clutchChange = lastClutchChange,
    }
end)

--[[
    Set vehicle last parts change data.
    Can be used to set the last change mileage for each part, e.g., for testing or resetting.
    If no mileage is provided for a part, it retains the current value.
--]]
exports('SetVehicleLastPartsChange', function(partsChange)
    lastOilChange = partsChange.oilChange or lastOilChange
    lastOilFilterChange = partsChange.oilFilterChange or lastOilFilterChange
    lastAirFilterChange = partsChange.airFilterChange or lastAirFilterChange
    lastTireChange = partsChange.tireChange or lastTireChange
    lastbrakeChange = partsChange.brakeChange or lastbrakeChange
    lastClutchChange = partsChange.clutchChange or lastClutchChange
    lastSuspensionChange = partsChange.suspensionChange or lastSuspensionChange
    lastSparkPlugChange = partsChange.sparkPlugChange or lastSparkPlugChange
end)

--[[
    Get vehicle parts wear data.
    Returns a table with the current wear levels for each part.
    - brakeWear: Current brake wear level
    - clutchWear: Current clutch wear level
    - suspensionWear: Current suspension wear level
    - sparkPlugWear: Current spark plug wear level
]]
exports('GetVehiclePartsWear', function()
    return {
        brakeWear = lastbrakeWear,
        clutchWear = lastClutchWear,
        suspensionWear = suspensionWear,
        sparkPlugWear = sparkPlugWear
    }
end)

--[[
    Set vehicle parts wear data.
    Can be used to set the wear levels for each part, e.g., for testing or resetting.
    If no wear level is provided for a part, it retains the current value.
--]]
exports('SetVehiclePartsWear', function(partsWear)
    lastbrakeWear = partsWear.brakeWear or lastbrakeWear
    lastClutchWear = partsWear.clutchWear or lastClutchWear
end)


---------------- Exports Examples ----------------
--[[
    -- /getMileage
RegisterCommand('getMileage', function()
    local mileage = exports['wizard-mileage']:GetVehicleMileage()
    print("Current vehicle mileage: " .. mileage)
end)
    -- /setMileage <number>
RegisterCommand('setMileage', function(source, args)
    local mileage = tonumber(args[1])
    if mileage then
        exports['wizard-mileage']:SetVehicleMileage(mileage)
        print("Vehicle mileage set to: " .. mileage)
    else
        print("Usage: /setMileage <number>")
    end
end)
    -- /getLastPartsChange (sp, oil, oilf, airf, tire, brake, sus, clutch)
RegisterCommand('getLastPartsChange', function(source, args)
    if not args[1] then
        print("Usage: /getLastPartsChange <part>")
        return
    end

    local partName = tostring(args[1])
    local partsChange = exports['wizard-mileage']:GetVehicleLastPartsChange()
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
end)
    -- /setLastPartsChange (sp, oil, oilf, airf, tire, brake, sus, clutch) <mileage>
RegisterCommand('setLastPartsChange', function(source, args)
    if #args ~= 2 then
        print("Usage: /setLastPartsChange (sp, oil, oilf, airf, tire, brake, sus, clutch) <mileage>")
        return
    end

    local partName = tostring(args[1]):lower()
    local partMileage = tonumber(args[2])
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

    exports['wizard-mileage']:SetVehicleLastPartsChange(partsChange)
    print("Last parts change data updated for " .. partName .. " to mileage " .. partMileage)
end)
    -- /getPartsWear (sp, oil, oilf, airf, tire, brake, sus, clutch)
RegisterCommand('getPartsWear', function(source, args)
    if not args[1] then
        print("Usage: /getPartsWear <part>")
        return
    end

    local partName = tostring(args[1])
    local partsWear = exports['wizard-mileage']:GetVehiclePartsWear()
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
end)
    -- /setPartsWear (brake, clutch) <wear>
RegisterCommand('setPartsWear', function(source, args)
    if #args ~= 2 then
        print("Usage: /setPartsWear (brake, clutch) <wear>")
        return
    end

    local partName = tostring(args[1]):lower()
    local wearValue = tonumber(args[2])
    if not wearValue then
        print("Invalid wear value. Please enter a number.")
        return
    end

    local partsWear = {
        brakeWear = nil,
        clutchWear = nil,
    }

    if partName == 'brake' then
        partsWear.brakeWear = math.min(wearValue, Config.MaxBrakeWear)
    elseif partName == 'clutch' then
        partsWear.clutchWear = math.min(wearValue, Config.MaxClutchWear)
    else
        print("Invalid part name. Available parts: brake, clutch")
        return
    end

    exports['wizard-mileage']:SetVehiclePartsWear(partsWear)
    print("Parts wear data updated for " .. partName .. " to wear value " .. wearValue)
end)
]]
