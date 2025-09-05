---------------- Main data ----------------
--[[
    These variables store the main state for the mileage and wear tracking system.
    They are used throughout the script to keep track of the player's vehicle status,
    UI visibility, wear levels, and cached data for server sync.
    Customers can reference these variables to understand what is being tracked.
]]--

-- Importing the required lib
require("@wizard-lib/client/functions")

-- UI and vehicle state flags
local loaded = false                  -- Is vehicle data loaded?
local mileageVisible = false          -- Is the mileage UI currently visible?
local isInVehicle = false               -- Is the player currently in a vehicle?
local waitingForData = false          -- Waiting for server data to load?
local clutchWearDirty = false         -- Is clutch wear data dirty (needs sync)?
local brakeWearDirty = false          -- Is brake wear data dirty (needs sync)?
local allowSmartGearDetect = true     -- Allow smart gear detection for clutch wear?
local mileageUIVisible = true         -- Should the mileage UI be shown?
local lastPos = nil                   -- Last known vehicle position (vector3)
local currentPlate = nil              -- Current vehicle plate being tracked
local CWFT = false                    -- Is checkWear menu openned for targetting script?
local clipboardEntity = nil           -- The clipboard entity for checking vehicle wear
local vehOwned = false                -- Is the vehicle owned by anyone?
local playerPed = PlayerPedId()       -- Get the player's ped id (will update during the script events)

-- Wear distances (in meters, set by config/unit)
local unitMultiplier = (Cfg.Unit == "imperial") and 1609.34 or 1000
local sparkPlugchangedist   = Config.SparkPlugChangeDistance * unitMultiplier
local oilchangedist         = Config.OilChangeDistance * unitMultiplier
local oilfilterchangedist   = Config.OilFilterDistance * unitMultiplier
local airfilterchangedist   = Config.AirFilterDistance * unitMultiplier
local tirechangedist        = Config.TireWearDistance * unitMultiplier

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
local lastSavedMil = 0.0              -- Lastest saved mileage

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

-- Callback tables for vehicle list requests
local vehicleListCallbacks = {}

-- Default wait time invertals for threads
local wTM = 3000
local wTU = 5000
local wTB = 2000
local wTC = 2000


---------------- Bought vehicles detection ----------------
--[[
    This section checks if a vehicle is owned by the player.
    If Config.BoughtVehiclesOnly is true, it will ask the server for ownership status.
    Otherwise, it will always return true (all vehicles are considered owned).
]]--
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
        return true
    end
end

---------------- Functions ----------------
--[[
    Triggers a vehicle list callback to retrieve all vehicles from the server.
    This is used for admin/database features that need to display or manage all vehicles.
    The callback is stored in a table with a unique ID, so when the server responds,
    the correct callback can be executed.
    @param cb (function): The function to call with the vehicle list (table).
]]--
local function TriggerVehicleListCallback(cb)
    local cbId = math.random(100000, 999999) -- Generate a unique callback ID
    vehicleListCallbacks[cbId] = cb          -- Store the callback for later use
    TriggerServerEvent('wizard_vehiclemileage:server:getAllVehicles', cbId) -- Ask the server for the vehicle list
end

--[[
    Updates the spark plug wear for the given vehicle.
    - Calculates how much the spark plugs have worn based on distance driven since last change.
    - Sends the updated wear value to the server for saving.
    - If the spark plugs are fully worn, there is a chance for a misfire (engine RPM drops).
    @param vehicle (entity): The vehicle entity to update.
]]--
local function updateSparkPlugWear(vehicle)
    if not Config.WearTracking.SparkPlugs then return end -- Skip if spark plug wear tracking is disabled

    -- Calculate how far the vehicle has driven since last spark plug change
    local distanceSinceSparkPlugChange = accDistance - lastSparkPlugChange
    -- Calculate wear ratio (0 = new, 1 = fully worn)
    local wearRatio = distanceSinceSparkPlugChange / (Config.SparkPlugChangeDistance * 1000)
    if wearRatio > 1 then wearRatio = 1 end

    sparkPlugWear = wearRatio

    -- If spark plugs are fully worn, chance for a misfire
    if sparkPlugWear >= 1.0 then
        if DoesEntityExist(veh) then
            if math.random() < Config.MissfireChance then
                Notify('Wizard Mileage', locale('warning.spark_plug_misfire'), 'warning')
                SetVehicleCurrentRpm(veh, 0.0)
                Wait(100)
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
]]--
local function updateEngineDamage(vehicle)
    if not Config.WearTracking.Oil then return end

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
                Notify('Wizard Mileage', locale('warning.engine_critical'), 'error')
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
]]--
local function updateAirFilterPerformance(vehicle)
    if not Config.WearTracking.AirFilter then return end

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
]]--
local function updateTireWear(vehicle)
    if not Config.WearTracking.Tires then return end

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
]]--
local function updateBrakeWear(vehicle)
    if not Config.WearTracking.Brakes then return end -- Skip if brake wear tracking is disabled

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
]]--
local function updateSuspensionWear(vehicle)
    if not Config.WearTracking.Suspension then return end -- Skip if suspension wear tracking is disabled

    -- Calculate how far the vehicle has driven since last suspension change
    local distanceSinceSuspensionChange = accDistance - lastSuspensionChange
    -- Calculate wear ratio (0 = new, 1 = fully worn)
    local wearRatio = distanceSinceSuspensionChange / (Config.SuspensionChangeDistance * 1000)
    if wearRatio > 1 then wearRatio = 1 end

    local plate = GetVehiclePlate(vehicle)
    -- Request original suspension values from the server (if not already cached)
    TriggerServerEvent('wizard_vehiclemileage:server:getOriginalSuspensionValue', plate)

    suspensionWear = wearRatio

    -- Get or save original suspension force and raise values
    local originalForce = originalSuspensionForce or GetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionForce")
    local originalRaise = originalSuspensionRaise or GetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionRaise")

    if not originalSuspensionForce or originalSuspensionForce == 0 then
        originalSuspensionForce = originalForce
        TriggerServerEvent('wizard_vehiclemileage:server:saveOriginalSuspensionForce', plate, originalForce)
    end
    if not originalSuspensionRaise then
        originalSuspensionRaise = originalRaise
        TriggerServerEvent('wizard_vehiclemileage:server:saveOriginalSuspensionRaise', plate, originalRaise)
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
]]--
local function updateClutchWear(vehicle)
    -- Calculate clutch efficiency (1.0 = new, decreases as wear increases)
    local efficiency = 1.0 - (math.min(lastClutchWear, Config.MaxClutchWear) / Config.MaxClutchWear * Config.ClutchEfficiencyLoss)

    -- If clutch is very worn, simulate clutch failure and possible stall
    if efficiency <= 0.2 then
        -- Simulate clutch slipping/failure
        InvokeNative(GetHashKey('SET_VEHICLE_CLUTCH') & 0xFFFFFFFF, vehicle, -1.0)
        -- Random chance to stall the engine
        if math.random() < Config.StallChance then
            SetVehicleEngineOn(vehicle, false, true, true)
            Notify('Wizard Mileage', locale('warning.stalled'), 'warning')
        end
    else
        -- You can add logic here for normal clutch operation if needed
        local baseClutchForce = Config.BaseClutchForce
    end
end

--[[
    Calculates the remaining life percentage for each tracked vehicle component.
    Updates global variables for spark plugs, oil, filter, air filter, tires, brakes, suspension, and clutch based on current mileage and wear.
    Also updates the displayed mileage value for the UI.
]]--
local function GetData()
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
    displayedMileage = convertDistance(accDistance)
end

--[[
    Cleans up the clipboard entity and animation for the player.
    Deletes the clipboard object if it exists and clears the player's current tasks/animations.
    @param ped (entity): The player ped to clear tasks for.
]]--
local function CleanupClipboardEntity(ped)
    if clipboardEntity then
        DeleteObject(clipboardEntity)
        clipboardEntity = nil
    end
    if ped then
        ClearPedTasks(ped)
    end
end

--[[
    Opens the service menu for the player, using the configured menu system.
    - If Config.Menu is "ox", shows the ox_lib context menu.
    - If Config.Menu is "qb", opens the qb-menu with all available service options.
    Each menu option triggers a client event to perform the selected maintenance action.
]]--
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
    Opens the vehicle wear check menu for a given vehicle.
    Plays clipboard animation, checks for valid vehicle and ownership, and retrieves wear data from the server.
    Displays error notifications if any checks fail, and cleans up the clipboard entity/animation as needed.
    On success, sends wear data to the NUI for display.
    @param vehicle (entity): The vehicle entity to check wear for.
]]--
local function openCheckWearMenu(vehicle)
    Notify('Wizard Mileage', locale('warning.checking_veh'), 'warning')
    
    local coords = GetEntityCoords(playerPed)
    if clipboardEntity then
        CleanupClipboardEntity(playerPed)
        return
    end
    local clipboardHash = RequestProp(Config.CheckVehicle.Object)
    clipboardEntity = CreateObject(clipboardHash, coords.x, coords.y, coords.z, true, true, true)
    AttachEntityToEntity(clipboardEntity, playerPed, GetPedBoneIndex(playerPed, Config.CheckVehicle.Bone), -0.1, 0.0, 0.0, 90.0, 0.0, 0.0, true, true, false, true, 1, true)
    TaskPlayAnim(playerPed, Config.CheckVehicle.AnimDict, Config.CheckVehicle.Animation, 8.0, -8.0, -1, 49, 0, false, false, false)

    if not DoesEntityExist(vehicle) then
        Notify('Wizard Mileage', locale('error.not_found'), 'error')
        -- Clear the animation and remove the clipboard
        CleanupClipboardEntity(playerPed)
        return
    end

    if isInVehicle then
        Notify('Wizard Mileage', locale('error.in_vehicle'), 'error')
        -- Clear the animation and remove the clipboard
        CleanupClipboardEntity(playerPed)
        return
    end

    local plate = GetVehiclePlate(vehicle)
    if not plate or plate == 'UNKNOWN' then
        Notify('Wizard Mileage', locale('error.plate_not_found'), 'error')
        -- Clear the animation and remove the clipboard
        CleanupClipboardEntity(playerPed)
        return
    end
    
    if not IsVehicleOwned(plate) then 
        Notify('Wizard Mileage', locale('error.not_owned'), 'error') 
        -- Clear the animation and remove the clipboard
        CleanupClipboardEntity(playerPed)
        return 
    end

    loaded = false

    TriggerServerEvent('wizard_vehiclemileage:server:retrieveMileage', plate)

    while not loaded do
        Wait(500)
    end

    CWFT = true

    GetData()

    SendNUIMessage({
        type = "closeCustomization"
    })
    SetNuiFocus(true, false)
    local wearDataCache = {
        type = "updateWear",
        showUI = true,
        mileage = displayedMileage,
        unit = (Cfg.Unit == "imperial" and "miles" or "km"),
        sparkPlugPercentage = sparkPlugPercentage,
        oilPercentage = oilPercentage,
        filterPercentage = filterPercentage,
        airFilterPercentage = airFilterPercentage,
        tirePercentage = tirePercentage,
        brakePercentage = brakePercentage,
        suspensionPercentage = suspensionPercentage,
        clutchPercentage = clutchPercentage
    }
    SendNUIMessage(wearDataCache)
end

--[[
    Performs a maintenance action on the nearest vehicle.
    Checks job and inventory requirements, plays animation, shows a progress bar, and removes the required item.
    Handles advanced actions (like opening the hood) if specified.
    Returns true and the vehicle entity on success, or false and nil on failure.

    @param item (string): The required inventory item for maintenance.
    @param errorMSG (string): The error message key for missing item.
    @param configData (table): Animation and progress bar configuration.
    @param progressMSG (string): The progress bar message key.
    @param isAdv (boolean): Whether to perform advanced actions (e.g., open hood).
]]--
local function DoMaintenance(item, errorMSG, configData, progressMSG, isAdv)
    if Config.JobRequired then
        local Job, Grade = CheckJob()
        for jobName, minGrade in pairs(Config.MechanicJobs) do
            if Job == jobName then 
                if Grade >= minGrade then 
                    break
                else
                    Notify('Wizard Mileage', locale("error.low_grade"), "error")
                    return
                end
            else
                Notify('Wizard Mileage', locale("error.not_mechanic"), "error")
                return
            end
        end
    end

    if Config.InventoryItems and not checkInventoryItem(item) then
        Notify('Wizard Mileage', locale("error." .. errorMSG), "error")
        return
    end

    local closestVehicle = GetClosestVehicle(5.0)
    if closestVehicle == 0 then
        Notify('Wizard Mileage', locale("error.no_vehicle_nearby"), "error")
        return
    end

    local vehicleClass = GetVehicleClass(closestVehicle)
    if Config.DisabledVehicleClasses[vehicleClass] then
        return
    end

    if isAdv then
        if not IsVehicleDoorFullyOpen(closestVehicle, 4) then
            SetVehicleDoorOpen(closestVehicle, 4, false, true)
            Wait(500)
        end
        local offset = GetOffsetFromEntityInWorldCoords(closestVehicle, 0.0, 2.0, 0.0)
        TaskGoStraightToCoord(playerPed, offset.x, offset.y, offset.z, 1.0, -1, -1, 0.0)
        Wait(1000)
    end

    PlayAnimation(playerPed, configData.AnimationDict, configData.Animation, -1 , 1)

    if DisplayProgressBar(configData.Duration, locale("progress." .. progressMSG), configData) then
        TriggerServerEvent('wizard-lib:server:removeItem', item, 1)
        if isAdv then SetVehicleDoorShut(closestVehicle, 4, false) end
        ClearPedTasks(playerPed)
        return true, closestVehicle
    else
        if isAdv then SetVehicleDoorShut(closestVehicle, 4, false) end
        return false, nil
    end
end

--[[
    Loads vehicle and mileage data when the player enters a vehicle.
    Sets state flags, caches the starting position, resets accumulated distance,
    shows the mileage UI if enabled, and requests the latest mileage data from the server.
    @side-effect: Updates global state variables and UI.
]]--
local function LoadData()
    isInVehicle = true
    lastPos = GetEntityCoords(veh)
    waitingForData = true
    accDistance = 0.0
    if mileageUIVisible then
        SendNUIMessage({ type = "toggleMileage", visible = true })
        mileageVisible = true
    end
    TriggerServerEvent('wizard_vehiclemileage:server:retrieveMileage', currentPlate)
end

--[[
    Clears and saves all vehicle and wear data when the player exits a vehicle or disconnects.
    Hides the mileage UI, sends any unsaved wear and mileage data to the server,
    resets all tracking variables, and clears cached state.
    @side-effect: Triggers server events to persist data and resets local state.
]]--
local function ClearData(ClearType)
    if mileageVisible then
        SendNUIMessage({ type = "toggleMileage", visible = false })
        mileageVisible = false
    end

    if ClearType == "normal" then
        isInVehicle = false
        inAnyVeh = false
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
        loaded = false
        vehOwned = false
    end

    if currentPlate then
        local savedPlate = currentPlate
        local savedMil = accDistance
        local savedPlugWear = sparkPlugWear
        local savedSusWear = suspensionWear
        if clutchWearDirty then
            TriggerServerEvent('wizard_vehiclemileage:server:updateClutchWear', currentPlate, cachedClutchWear)
        clutchWearDirty = false
        end
        if brakeWearDirty then
            TriggerServerEvent('wizard_vehiclemileage:server:updateBrakeWear', currentPlate, cachedBrakeWear)
            brakeWearDirty = false
        end
        TriggerServerEvent('wizard_vehiclemileage:server:updateMileage', currentPlate, savedMil)
        TriggerServerEvent('wizard_vehiclemileage:server:updateSparkPlugWear', currentPlate, savedPlugWear)
        TriggerServerEvent('wizard_vehiclemileage:server:updateSuspensionWear', currentPlate, savedSusWear)
    end
end

---------------- Threads ----------------
--[[
    Main thread for mileage and wear tracking and Targeting script handler.
    This thread constantly checks if the player is in a vehicle, updates mileage, wear, and UI,
    and handles entering/exiting vehicles and syncing data with the server.
    
    also this thread sets up vehicle interaction targets for supported targeting systems (ox_target, qb-target).
    - Adds a "Service Vehicle" option to all vehicles for mechanics (or anyone, if job not required).
    - Checks if the player is not in a vehicle and owns the vehicle before allowing interaction.
    - Handles job and grade checks if required.
    - Opens the service menu when the target is selected.
    - Also registers the ox_lib context menu if using ox as the menu system.
]]--
lib.onCache('vehicle', function(value, oldValue)
    if not value then 
        ClearData("normal")
    else 
        veh = value
        inAnyVeh = true
        local vehicleClass = GetVehicleClass(veh)
        if Config.DisabledVehicleClasses[vehicleClass] then
            return
        end
        currentPlate = GetVehiclePlate(veh)
        if IsVehicleOwned(currentPlate) then
            vehOwned = true
            if GetPedInVehicleSeat(veh, -1) ~= playerPed then
                return
            end
            LoadData()
        else
            vehOwned = false
        end
    end
end)
lib.onCache('seat', function(value, oldValue)
    if oldValue == -1 then
        ClearData("limited")
    end
    if value == -1 and vehOwned then
        LoadData()
    end
end)
lib.onCache('ped', function(value, oldValue)
    playerPed = value
end)
CreateThread(function()
    local lastMileage = -1    
    if Config.Targeting then
        local targetConfig = {
            ox = function()
                exports.ox_target:addGlobalVehicle({
                    {
                        name = "vehicle_service",
                        icon = "fas fa-wrench",
                        label = "Service Vehicle",
                        canInteract = function(entity)
                            if inAnyVeh then
                                return false
                            end
                            local plate = GetVehicleNumberPlateText(entity)
                            if IsVehicleOwned(plate) then
                                local vehicleClass = GetVehicleClass(entity)
                                if Config.DisabledVehicleClasses[vehicleClass] then
                                    return false
                                else
                                    return true
                                end
                            end
                        end,
                        onSelect = function(data)
                            if Config.JobRequired then
                                local Job, Grade = CheckJob()
                                local allowed = false
                                for jobName, minGrade in pairs(Config.MechanicJobs) do
                                    if Job == jobName then 
                                        if Grade >= minGrade then 
                                            break
                                        else
                                            Notify('Wizard Mileage', locale("error.low_grade"), "error")
                                            return
                                        end
                                    else
                                        Notify('Wizard Mileage', locale("error.not_mechanic"), "error")
                                        return
                                    end
                                end
                            end
                            openServiceMenu()
                        end
                    },
                    {
                        name = "vehicle_check",
                        icon = "fas fa-info",
                        label = "Check Vehicle",
                        canInteract = function(entity)
                            if inAnyVeh then
                                return false
                            end
                            local plate = GetVehicleNumberPlateText(entity)
                            if IsVehicleOwned(plate) then
                                local vehicleClass = GetVehicleClass(entity)
                                if Config.DisabledVehicleClasses[vehicleClass] then
                                    return false
                                else
                                    return true
                                end
                            end
                        end,
                        onSelect = function(data)
                            local targetVeh = data.entity
                            openCheckWearMenu(targetVeh)
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
                                if inAnyVeh then
                                    return false
                                end
                                local plate = GetVehicleNumberPlateText(entity)
                                if IsVehicleOwned(plate) then
                                    local vehicleClass = GetVehicleClass(entity)
                                    if Config.DisabledVehicleClasses[vehicleClass] then
                                        return false
                                    else
                                        return true
                                    end
                                end
                            end,
                            action = function()
                            if Config.JobRequired then
                                local Job, Grade = CheckJob()
                                local allowed = false
                                for jobName, minGrade in pairs(Config.MechanicJobs) do
                                    if Job == jobName then 
                                        if Grade >= minGrade then 
                                            break
                                        else
                                            Notify('Wizard Mileage', locale("error.low_grade"), "error")
                                            return
                                        end
                                    else
                                        Notify('Wizard Mileage', locale("error.not_mechanic"), "error")
                                        return
                                    end
                                end
                            end
                                openServiceMenu()
                            end
                        },
                        {
                            type = "client",
                            icon = "fas fa-info",
                            label = "Check Vehicle",
                            canInteract = function(entity)
                                if inAnyVeh then
                                    return false
                                end
                                local plate = GetVehicleNumberPlateText(entity)
                                if IsVehicleOwned(plate) then
                                    local vehicleClass = GetVehicleClass(entity)
                                    if Config.DisabledVehicleClasses[vehicleClass] then
                                        return false
                                    else
                                        return true
                                    end
                                end
                            end,
                            action = function(data)
                                local targetVeh = data.entity
                                openCheckWearMenu(targetVeh)
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
    end
    
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

    while true do
        if isInVehicle then
            wTM = 1000
            if not waitingForData then
                local currentPos = GetEntityCoords(veh)
                local delta = getDistance(lastPos, currentPos)
                accDistance = accDistance + delta
                lastPos = currentPos
                local displayedMileage = convertDistance(accDistance)
                if displayedMileage ~= lastMileage then
                    SendNUIMessage({ type = "updateMileage", mileage = displayedMileage, unit = (Cfg.Unit == "imperial" and "miles" or "km") })
                    lastMileage = displayedMileage
                end
            end
        else
            wTM = 3000
        end
        Wait(wTM)
    end
end)
CreateThread(function()
    while true do
        if isInVehicle then
            wTU = 3000
            if not waitingForData then
                updateSparkPlugWear(veh)
                updateEngineDamage(veh)
                updateAirFilterPerformance(veh)
                updateSuspensionWear(veh)
                updateTireWear(veh)
            end
        else
            wTU = 5000
        end
        Wait(wTU)
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
]]--
CreateThread(function()
    if not Config.WearTracking.Clutch then return end
    local prevGear = 0
    local lastShiftTime = 0
    local shiftCooldown = 500 -- Minimum ms between gear shifts to count as wear
    while true do
        if isInVehicle then
            if currentPlate and allowSmartGearDetect then
                wTC = 1500
                local currentGear = GetVehicleCurrentGear(veh)
                local currentTime = GetGameTimer()
                -- Only count gear changes after cooldown
                if (currentGear ~= prevGear) and ((currentTime - lastShiftTime) > shiftCooldown) then
                    local gearDiff = math.abs(currentGear - prevGear)
                    local wearIncrement = Config.ClutchWearRate * gearDiff
                    -- Extra wear for skipping more than one gear
                    if gearDiff > 1 then
                        wearIncrement = wearIncrement * 1.3
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
        else
            wTC = 2000
        end
        Wait(wTC)
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
]]--
CreateThread(function()
    while true do
        if isInVehicle then
            if currentPlate then
                wTB = 750
                if Config.WearTracking.Brakes then 
                    if IsControlPressed(0, 72) then -- 72 is the brake control
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
        else
            wTB = 2000
        end
        Wait(wTB)
    end
end)

--[[
    UI wear update thread.
    This thread runs every 5 seconds and calculates the remaining life percentage for each tracked vehicle part.
    - For each enabled wear system (spark plugs, oil, filter, air filter, tires, brakes, clutch),
    - it calculates the percentage of life remaining based on distance driven or wear value.
    - The calculated percentages are sent to the NUI (UI) for display.
    - This keeps the UI up to date with the latest wear status for all parts.
]]--
CreateThread(function()
    local lastWear = {}
    while true do
        Wait(5000)
        if isInVehicle and not waitingForData then
            local wearData = {}

            GetData()

            -- Only send NUI message if data changed
            local changed = false
            for k, v in pairs(wearData) do
                if lastWear[k] ~= v then
                    changed = true
                    break
                end
            end
            if changed then
                SendNUIMessage({ type = "updateWear", showUI = false, sparkPlugPercentage = wearData.sparkPlugPercentage, oilPercentage = wearData.oilPercentage, filterPercentage = wearData.filterPercentage, airFilterPercentage = wearData.airFilterPercentage, tirePercentage = wearData.tirePercentage, brakePercentage = wearData.brakePercentage, suspensionPercentage = wearData.suspensionPercentage, clutchPercentage = wearData.clutchPercentage })
                lastWear = wearData
            end
        end
    end
end)


---------------- Net Events ----------------
--[[
    Handles the spark plug change event.
    Checks job/inventory requirements, plays animation, removes item, and updates server and local state.
]]--
RegisterNetEvent('wizard_vehiclemileage:client:changesparkplug')
AddEventHandler('wizard_vehiclemileage:client:changesparkplug', function()
    local Stats, closestVehicle = DoMaintenance(Config.Items.SparkPlug, "no_spark_plug", Config.ChangeSparkPlug, "changingsparkplug")
    if Stats then
        local plate = GetVehicleNumberPlateText(closestVehicle)
        Notify('Wizard Mileage', locale("info.spark_plug_changed"), "success")
        TriggerServerEvent("wizard_vehiclemileage:server:updateSparkPlugChange", plate)
        TriggerServerEvent("wizard_vehiclemileage:server:updateSparkPlugWear", plate, 0)
        sparkPlugWear = 0
        updateSparkPlugWear(closestVehicle)
    end
end)

--[[
    Handles the oil change event.
    Checks job/inventory requirements, plays animation, removes item, and updates server and local state.
]]--
RegisterNetEvent('wizard_vehiclemileage:client:changeoil')
AddEventHandler('wizard_vehiclemileage:client:changeoil', function()
    local Stats, closestVehicle = DoMaintenance(Config.Items.EngineOil, "no_oil", Config.ChangeOil, "changingoil", true)
    if Stats then
        local plate = GetVehicleNumberPlateText(closestVehicle)
        Notify('Wizard Mileage', locale("info.oil_changed"), "success")
        TriggerServerEvent("wizard_vehiclemileage:server:updateOilChange", plate)
    end
end)

--[[
    Handles the oil filter change event.
    Checks job/inventory requirements, plays animation, removes item, and updates server and local state.
]]--
RegisterNetEvent('wizard_vehiclemileage:client:changeoilfilter')
AddEventHandler('wizard_vehiclemileage:client:changeoilfilter', function()
    local Stats, closestVehicle = DoMaintenance(Config.Items.OilFilter, "no_oil_filter", Config.ChangeOilFilter, "changingoilfilter", true)
    if Stats then
        local plate = GetVehicleNumberPlateText(closestVehicle)
        Notify('Wizard Mileage', locale("info.filter_changed"), "success")
        TriggerServerEvent("wizard_vehiclemileage:server:updateOilFilter", plate)
    end
end)

--[[
    Handles the air filter change event.
    Checks job/inventory requirements, plays animation, removes item, and updates server and local state.
]]--
RegisterNetEvent('wizard_vehiclemileage:client:changeairfilter')
AddEventHandler('wizard_vehiclemileage:client:changeairfilter', function()
    local Stats, closestVehicle = DoMaintenance(Config.Items.AirFilter, "no_air_filter", Config.ChangeAirFilter, "changingairfilter", true)
    if Stats then
        local plate = GetVehicleNumberPlateText(closestVehicle)
        Notify('Wizard Mileage', locale("info.air_filter_changed"), "success")
        TriggerServerEvent("wizard_vehiclemileage:server:updateAirFilter", plate)
    end
end)

--[[
    Handles the tire change event.
    Checks job/inventory requirements, plays animation, removes item, and updates server and local state.
]]--
RegisterNetEvent('wizard_vehiclemileage:client:changetires')
AddEventHandler('wizard_vehiclemileage:client:changetires', function()
    local Stats, closestVehicle = DoMaintenance(Config.Items.Tires, "no_tires", Config.ChangeTires, "changingtires")
    if Stats then
        local plate = GetVehicleNumberPlateText(closestVehicle)
        lastTireChange = accDistance
        for i = 0, 5 do
            SetVehicleTyreFixed(closestVehicle, i)
        end
        Notify('Wizard Mileage', locale("info.tire_changed"), "success")
        TriggerServerEvent("wizard_vehiclemileage:server:updateTireChange", plate)
        SetVehicleHandlingFloat(closestVehicle, "CHandlingData", "fTractionCurveMax", Config.BaseTireGrip)
    end
end)

--[[
    Handles the brake change event.
    Checks job/inventory requirements, plays animation, removes item, and updates server and local state.
]]--
RegisterNetEvent('wizard_vehiclemileage:client:changebrakes')
AddEventHandler('wizard_vehiclemileage:client:changebrakes', function()
    local Stats, closestVehicle = DoMaintenance(Config.Items.BrakeParts, "no_brake_parts", Config.ChangeBrakes, "changingbrakes")
    if Stats then
        local plate = GetVehicleNumberPlateText(closestVehicle)
        Notify('Wizard Mileage', locale("info.brakes_changed"), "success")
        TriggerServerEvent("wizard_vehiclemileage:server:updateBrakeChange", plate)
        lastbrakeWear = 0.0
        updateBrakeWear(closestVehicle)
    end
end)

--[[
    Handles the suspension change event.
    Checks job/inventory requirements, plays animation, removes item, and updates server and local state.
]]--
RegisterNetEvent('wizard_vehiclemileage:client:changesuspension')
AddEventHandler('wizard_vehiclemileage:client:changesuspension', function()
    local Stats, closestVehicle = DoMaintenance(Config.Items.SusParts, "no_suspension_parts", Config.ChangeSuspension, "changingsuspension")
    if Stats then
        local plate = GetVehicleNumberPlateText(closestVehicle)
        Notify('Wizard Mileage', locale("info.suspension_changed"), "success")
        TriggerServerEvent("wizard_vehiclemileage:server:updateSuspensionChange", plate)
        TriggerServerEvent("wizard_vehiclemileage:server:updateSuspensionWear", plate, 0)
        suspensionWear = 0
        updateSuspensionWear(closestVehicle)
    end
end)

--[[
    Handles the clutch change event.
    Checks job/inventory requirements, plays animation, removes item, and updates server and local state.
]]--
RegisterNetEvent('wizard_vehiclemileage:client:changeclutch')
AddEventHandler('wizard_vehiclemileage:client:changeclutch', function()
    local Stats, closestVehicle = DoMaintenance(Config.Items.Clutch, "no_clutch", Config.ChangeClutch, "changingclutch")
    if Stats then
        local plate = GetVehicleNumberPlateText(closestVehicle)
        Notify('Wizard Mileage', locale("info.clutch_changed"), "success")
        TriggerServerEvent("wizard_vehiclemileage:server:updateClutchChange", plate)
        TriggerServerEvent("wizard_vehiclemileage:server:updateClutchWear", plate, 0)
        lastClutchWear = 0
        updateClutchWear(closestVehicle)
    end
end)

--[[
    Receives and sets vehicle mileage and wear data from the server.
    Updates local variables and UI.
]]--
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
    loaded = true
    local displayedMileage = convertDistance(accDistance)
    SendNUIMessage({
        type = "updateMileage",
        mileage = displayedMileage,
        unit = (Cfg.Unit == "imperial" and "miles" or "km")
    })
end)

--[[
    Receives notification that vehicle data has been updated and refreshes the vehicle list in the UI.
]]--
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
]]--
RegisterNetEvent('wizard_vehiclemileage:client:getAllVehiclesCallback')
AddEventHandler('wizard_vehiclemileage:client:getAllVehiclesCallback', function(cbId, vehicles)
    if vehicleListCallbacks[cbId] then
        vehicleListCallbacks[cbId](vehicles)
        vehicleListCallbacks[cbId] = nil
    end
end)

--[[
    Receives and applies player UI customization settings from the server.
]]--
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
]]--
RegisterNetEvent('wizard_vehiclemileage:client:setOriginalDriveForce')
AddEventHandler('wizard_vehiclemileage:client:setOriginalDriveForce', function(driveForce)
    originalDriveForce = driveForce
end)

--[[
    Receives and sets the original suspension raise value for the current vehicle.
]]--
RegisterNetEvent('wizard_vehiclemileage:client:setOriginalSusRaise')
AddEventHandler('wizard_vehiclemileage:client:setOriginalSusRaise', function(susRaise)
    originalSuspensionRaise = susRaise
end)

--[[
    Receives and sets the original suspension force value for the current vehicle.
]]--
RegisterNetEvent('wizard_vehiclemileage:client:setOriginalSusForce')
AddEventHandler('wizard_vehiclemileage:client:setOriginalSusForce', function(susForce)
    originalSuspensionForce = susForce
end)

--[[
    Updates clutch wear for wizard_manualtransmission integration.
]]--
RegisterNetEvent('wizard_vehiclemileage:client:updateClutchWT')
AddEventHandler('wizard_vehiclemileage:client:updateClutchWT', function()
    if not vehOwned then return end
    
    lastClutchWear = lastClutchWear + Config.ClutchWearRate
    if lastClutchWear > Config.MaxClutchWear then
        lastClutchWear = Config.MaxClutchWear
    end
    TriggerServerEvent('wizard_vehiclemileage:server:updateClutchWear', currentPlate, lastClutchWear)
    updateClutchWear(veh)
end)

--[[
    Enables or disables smart gear detection for clutch wear tracking.
]]--
RegisterNetEvent('wizard_vehiclemileage:client:smartGearDetect')
AddEventHandler('wizard_vehiclemileage:client:smartGearDetect', function(data)
    allowSmartGearDetect = data
end)

--[[
    Receives script version check results and triggers update notification.
]]--
RegisterNetEvent('wizard_vehiclemileage:client:setOutdated')
AddEventHandler('wizard_vehiclemileage:client:setOutdated', function(data, currentVersion, latestVersion)
    updateCheck("Wizard Mileage", {255, 0, 255}, data, currentVersion, latestVersion)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        TriggerServerEvent('wizard_vehiclemileage:server:loadPlayerSettings')
        TriggerServerEvent('wizard_vehiclemileage:server:getupdate')
    end
end)
AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        ClearData("normal")
    end
end)
AddEventHandler('playerSpawned', function()
    TriggerServerEvent('wizard_vehiclemileage:server:loadPlayerSettings')
    playerPed = PlayerPedId()
end)

---------------- Autosave system ----------------
--[[ 
    Autosave system.
    If autosave is enabled in the config, this thread will periodically save the current vehicle's mileage to the server.
    - The interval is set by Config.AutosaveInterval (in seconds).
    - Only saves if the player is in a vehicle, the plate is set, the vehicle is owned, and not waiting for data.
    - Helps prevent mileage loss if the player crashes or disconnects unexpectedly.
]]--
if Config.Autosave then
    local autosaveinvl = Config.AutosaveInterval * 1000
    CreateThread(function()
        while true do
            Wait(autosaveinvl)
            if isInVehicle and not waitingForData then
                if accDistance - lastSavedMil > Config.MinDiffToSave then
                    lastSavedMil = accDistance
                    TriggerServerEvent('wizard_vehiclemileage:server:updateMileage', currentPlate, accDistance)
                end
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
]]--
if Config.ChangeWarnings then
    local components = {}

    if Config.WearTracking.SparkPlugs then
        components.sparkPlug = {
            lastChange = function() return lastSparkPlugChange end,
            changedist = sparkPlugchangedist,
            computeDistance = function() return accDistance - lastSparkPlugChange end,
            thresholds = Config.Thresholds.SparkPlugs,
            localeKey = "warning.remaining_spark_plug"
        }
    end
    if Config.WearTracking.Oil then
        components.oil = {
            lastChange = function() return lastOilChange end,
            changedist = oilchangedist,
            computeDistance = function() return accDistance - lastOilChange end,
            thresholds = Config.Thresholds.Oil,
            localeKey = "warning.remaining_oil"
        }
        components.filter = {
            lastChange = function() return lastOilFilterChange end,
            changedist = oilfilterchangedist,
            computeDistance = function() return accDistance - lastOilFilterChange end,
            thresholds = Config.Thresholds.OilFilter,
            localeKey = "warning.remaining_filter"
        }
    end
    if Config.WearTracking.AirFilter then
        components.airFilter = {
            lastChange = function() return lastAirFilterChange end,
            changedist = airfilterchangedist,
            computeDistance = function() return accDistance - lastAirFilterChange end,
            thresholds = Config.Thresholds.AirFilter,
            localeKey = "warning.remaining_air_filter"
        }
    end
    if Config.WearTracking.Tires then
        components.tire = {
            lastChange = function() return lastTireChange end,
            changedist = tirechangedist,
            computeDistance = function() return accDistance - lastTireChange end,
            thresholds = Config.Thresholds.Tires,
            localeKey = "warning.remaining_tire"
        }
    end
    if Config.WearTracking.Suspension then
        components.suspension = {
            lastChange = function() return lastSuspensionChange end,
            changedist = Config.SuspensionChangeDistance * 1000,
            computeDistance = function() return accDistance - lastSuspensionChange end,
            thresholds = Config.Thresholds.Suspension,
            localeKey = "warning.remaining_suspension"
        }
    end

    local staticComponents = {}
    if Config.WearTracking.Brakes then
        staticComponents.brakes = {
            value = function()
                return math.floor((1 - (lastbrakeWear / Config.MaxBrakeWear)) * 100)
            end,
            thresholds = Config.Thresholds.Brakes,
            localeKey = "warning.remaining_brakes"
        }
    end
    if Config.WearTracking.Clutch then
        staticComponents.clutch = {
            value = function()
                return math.floor((1 - (lastClutchWear / Config.MaxClutchWear)) * 100)
            end,
            thresholds = Config.Thresholds.Clutch,
            localeKey = "warning.remaining_clutch"
        }
    end
    
    
    local function checkComponent(componentData, percentage)
        local baseMessage = locale(componentData.localeKey)
        for _, threshold in ipairs(componentData.thresholds) do
            if percentage <= threshold.value then
                local extraMessage = threshold.action and (" " .. locale("warning." .. threshold.action)) or ""
                Notify('Wizard Mileage', baseMessage .. " " .. threshold.value .. "%!" .. extraMessage, threshold.severity)
                break
            end
        end
    end
    local function checkWearLevels()
        if not isInVehicle then 
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
    CreateThread(function()
        while true do
            Wait(checkInterval)
            if isInVehicle and not waitingForData then
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
]]--
RegisterNUICallback('notify', function(data, cb)
    if data and data.message and data.type then
        Notify('Wizard Mileage', data.message, data.type)
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
]]--
RegisterNUICallback('requestVehicleList', function(data, cb)
    TriggerVehicleListCallback(function(vehicles)
        if vehicles then
            SendNUIMessage({ vehicles = vehicles })
            cb({success = true})
        else
            cb({success = false, error = 'No vehicles found'})
        end
    end)
end)

--[[
    Update vehicle data callback.
    This NUI callback is triggered by the UI when an admin or user updates a vehicle's maintenance data.
    - Expects `data.vehicle` (table) with all relevant maintenance fields.
    - Triggers a server event to update the vehicle data in the database.
    - Responds to the UI with success or error.
]]--
RegisterNUICallback('updateVehicleData', function(data, cb)
    if data and data.vehicle then
        local vehicleData = data.vehicle
        TriggerServerEvent('wizard_vehiclemileage:server:updateVehicleData', vehicleData)
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
]]--
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
]]--
RegisterNUICallback('savePlayerSettings', function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('wizard_vehiclemileage:server:savePlayerSettings', data)
    SendNUIMessage({ type = "closeCustomization" })
    cb({success = true})
end)

--[[
    Close menu callback.
    This NUI callback is triggered by the UI when the player wants to close the menu.
    - Removes NUI focus from the player.
    - Sends a message to the UI to close the menu.
    - Responds to the UI with an empty callback.
]]--
RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    loaded = false
    if CWFT then
        -- Clear the animation and remove the clipboard
        ClearPedTasks(playerPed)
        DeleteObject(clipboardEntity)
        clipboardEntity = nil
        CWFT = false
    end
    cb({success = true})
end)

---------------- Commands ----------------
--[[
    Command to open the vehicle mileage customization menu.
    Checks if the player is in a vehicle and has a valid plate.
    If the vehicle is owned, it opens the customization UI.
    If not in a vehicle or not owned, it shows an error notification.
]]--
RegisterCommand(Config.CustomizeCommand, function()
    if isInVehicle then
        if not vehOwned then Notify('Wizard Mileage', locale('error.not_owned'), 'error') return end
        TriggerServerEvent('wizard_vehiclemileage:server:loadPlayerSettings')
        SetNuiFocus(true, true)
        SendNUIMessage({
            type = "openCustomization"
        })
    else
        Notify('Wizard Mileage', locale('error.not_in_vehicle'), 'error')
    end
end)


--[[
    Command to check vehicle wear and tear.
    Checks if the player is in a vehicle and has a valid plate.
    If the vehicle is owned, it calculates wear percentages and opens the wear UI.
    If not in a vehicle or not owned, it shows an error notification.
]]--
RegisterCommand(Config.CheckWearCommand, function()
    if isInVehicle then
        if not vehOwned then Notify('Wizard Mileage', locale('error.not_owned'), 'error') return end
        GetData()
        SendNUIMessage({
            type = "closeCustomization"
        })
        SetNuiFocus(true, false)
        SendNUIMessage({
            type = "updateWear",
            showUI = true,
            mileage = displayedMileage,
            unit = (Cfg.Unit == "imperial" and "miles" or "km"),
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
        Notify('Wizard Mileage', locale('error.not_in_vehicle'), 'error')
    end
end, false)

--[[
    Command to open the database menu for admins.
    Checks if the player has permission using the TriggerPermCallback.
    If admin, opens the database UI and requests the vehicle list from the server.
    If not admin, shows an error notification.
]]--
RegisterCommand(Config.DatabaseCommand, function()
    TriggerPermCallback(Config.AdminPermission, function(isAdmin)
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
            Notify('Wizard Mileage', 'You do not have permission to open this menu.', 'error')
        end
    end)
end)



---------------- Exports ----------------
--[[
    Exports for other scripts to interact with vehicle mileage and maintenance data.
    Provides functions to get/set mileage, parts change history, and wear levels.
]]--
exports('GetVehicleMileage', function()
    return accDistance
end)

--[[
    Set vehicle mileage.
    Can be used to set the mileage directly, e.g., for testing or resetting.
    If no mileage is provided, it uses the current accumulated distance.
]]--
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
]]--
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
]]--
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
]]--
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
]]--