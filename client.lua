require("@wizard-lib/client/functions")


--==========================================================================
--
--                                VARIABLES
--
--==========================================================================

-- Player / Vehicle state
local playerPed = PlayerPedId()       -- Player ped id (updated during runtime)
local isInVehicle = false             -- Is the player currently inside a vehicle?
local currentPlate = nil              -- Plate of the vehicle currently being tracked
local vehOwned = false                -- Does this vehicle belong to any player?

-- Script state flags
local loaded = false                  -- Has vehicle data been loaded from the server?
local waitingForData = false          -- Waiting for vehicle data response?
local allowSmartGearDetect = true     -- Enable smart gear detection for clutch wear

-- UI state flags
local mileageVisible = false          -- Is the mileage UI currently visible?
local mileageUIVisible = true         -- Should the mileage UI be displayed?
local CWFT = false                    -- Is the wear check menu opened (target script)

-- Clipboard / inspection entities
local clipboardEntity = nil           -- Clipboard prop used for wear inspection

-- Position tracking
local lastVehiclePosition = nil                   -- Last known vehicle position (vector3)

-- Distance unit conversion
local unitMultiplier = (Cfg.Unit == "imperial") and 1609.34 or 1000

-- Wear distance thresholds
local sparkPlugchangedist = Config.SparkPlugChangeDistance * unitMultiplier
local oilchangedist       = Config.OilChangeDistance * unitMultiplier
local oilfilterchangedist = Config.OilFilterDistance * unitMultiplier
local airfilterchangedist = Config.AirFilterDistance * unitMultiplier
local tirechangedist      = Config.TireWearDistance * unitMultiplier

-- Mileage tracking
local accumulatedDistance = 0.0               -- Accumulated driven distance (meters)
local lastSavedMileage = 0.0              -- Last saved mileage value

-- Service history (last replacement mileage)
local lastOilChange = 0.0
local lastOilFilterChange = 0.0
local lastAirFilterChange = 0.0
local lastSparkPlugChange = 0.0
local lastClutchChange = 0.0
local lastSuspensionChange = 0.0

-- Component wear values
local sparkPlugWear = 0.0             -- Current spark plug wear
local suspensionWear = 0.0            -- Current suspension wear
local lastClutchWear = 0.0            -- Current clutch wear value
local lastbrakeWear = 0.0             -- Global brake wear cache

-- Per wheel service tracking
local lastTireChange = {0.0,0.0,0.0,0.0,0.0,0.0}     -- Mileage of last tire replacement
local lastbrakeChange = {0.0,0.0,0.0,0.0,0.0,0.0}    -- Mileage of last brake replacement

-- Per wheel wear values
local tireWear = {0.0,0.0,0.0,0.0,0.0,0.0}           -- Tire wear per wheel (0..1)
local brakeWear = {0.0,0.0,0.0,0.0,0.0,0.0}          -- Brake wear per wheel (0..1)

-- Dirty sync flags (client -> server)
local clutchWearDirty = false        -- Clutch wear changed and needs sync
local brakeWearDirty = false         -- Brake wear changed and needs sync
local tireWearDirty = false          -- Tire wear changed and needs sync

-- Cached values for server sync optimization
local cachedClutchWear = 0.0
local cachedBrakeWear = 0.0
local cachedPassengerCount = 0
local cachedFrontPassenger = false
local cachedPassengerVehTotal = -1

-- Tire burst / wheel state sync
local tireBurstSynced = {}

-- UI customization
local mileageUIPosX = 0.0
local mileageUIPosY = 0.0
local mileageUISize = 1.0

local checkwearUIPosX = 0.0
local checkwearUIPosY = 0.0
local checkwearUISize = 1.0

-- Engine warning system
local lastEngineCriticalNotify = 0    -- Last time critical engine warning was shown

-- Callback system
local vehicleListCallbacks = {}       -- Pending callbacks waiting for vehicle list

-- Thread wait timers (performance tuning)
local waitTimeMain = 3000
local waitTimeClutch = 2000

-- Wear inspection & ownership caching
local ownershipCache = {}             -- Cached ownership per vehicle plate
local wearCheckAccess = {}            -- Temporary inspection access (plate -> expire time)

-- Wheel count cache
local wheelCountCache = {}            -- Cached wheel counts per vehicle model





--==========================================================================
--
--                                FUNCTIONS
--
--==========================================================================

--[[
    Checks whether a vehicle is owned and caches the result temporarily.

    - Normalizes the plate before checking ownership.
    - Uses a temporary cache to avoid repeated server callbacks.
    - Requests ownership data from the server if no valid cache exists.
    - Always returns true when BoughtVehiclesOnly is disabled.

    @param plate (string): The vehicle plate to check.
    @return boolean: Whether the vehicle is considered owned.
]]--
if Config.BoughtVehiclesOnly then
    function IsVehicleOwned(plate)
        if not plate then return false end

        plate = plate:gsub('%s+', '')
        local now = GetGameTimer()

        if ownershipCache[plate] and (now - ownershipCache[plate].time) < 5000 then
            return ownershipCache[plate].value
        end

        local owned = lib.callback.await('wizard_vehiclemileage:server:ownerShipCallBack', false, plate)

        ownershipCache[plate] = {
            value = owned,
            time = now
        }

        return owned
    end
else
    function IsVehicleOwned()
        return true
    end
end

--[[
    Normalizes a vehicle plate string for consistent comparisons.
    - Ensures the provided plate value exists before processing.
    - Removes all whitespace characters from the plate string.
    - Returns a cleaned plate value that can be safely used for lookups or matching.
    @param plate (string): The raw vehicle plate text.
    @return string|nil: The normalized plate without spaces, or nil if the input is invalid.
]]--
local function normalizePlate(plate)
    if not plate then return nil end
    return plate:gsub("%s+", "")
end

--[[
    Attempts to detect the number of wheels a vehicle has using bone checks.
    - Iterates through common vehicle wheel bone names and checks if they exist on the entity.
    - Counts how many valid wheel bones are found.
    - Falls back to a default of 4 wheels if no bones are detected.
    - Clamps the maximum detected wheel count to 6 to avoid unexpected values.
    @param veh (entity): The vehicle entity whose wheel bones will be inspected.
    @return number: The detected wheel count (between 4 and 6).
]]--
local function detectWheelCount(veh)
    local bones = {"wheel_lf","wheel_rf","wheel_lr","wheel_rr","wheel_lm","wheel_rm"}
    local count = 0
    for i, b in ipairs(bones) do
        local idx = GetEntityBoneIndexByName(veh, b)
        if idx ~= -1 then count = count + 1 end
    end
    if count == 0 then count = 4 end
    if count > 6 then count = 6 end
    return count
end

local function getCachedWheelCount(veh)
    local model = GetEntityModel(veh)
    if wheelCountCache[model] == nil then
        wheelCountCache[model] = detectWheelCount(veh)
    end
    return wheelCountCache[model]
end

--[[
    Triggers a vehicle list callback to retrieve all vehicles from the server.
    This is used for admin/database features that need to display or manage all vehicles.
    The callback is stored in a table with a unique ID, so when the server responds,
    the correct callback can be executed.
    @param cb (function): The function to call with the vehicle list (table).
]]--
local function TriggerVehicleListCallback(cb)
    -- Limit callback pool size to prevent memory bloat
    local callbackCount = 0
    for _ in pairs(vehicleListCallbacks) do
        callbackCount = callbackCount + 1
    end
    if callbackCount >= 50 then
        vehicleListCallbacks = {}
    end
    local cbId = math.random(100000, 999999) -- Generate a unique callback ID
    vehicleListCallbacks[cbId] = cb          -- Store the callback for later use
    TriggerServerEvent('wizard_vehiclemileage:server:getAllVehicles', cbId) -- Ask the server for the vehicle list
end

--[[
    Checks if the player has permission to use mechanic-related features.
    - Retrieves the player's current job and grade using CheckJob().
    - Compares the job against the configured mechanic jobs list.
    - Ensures the player's grade meets or exceeds the minimum required grade.
    - Returns true if the player has mechanic access, otherwise false.
    @return boolean: Whether the player has mechanic access.
]]--
local function isMechanic()
    if Config.JobRequired then
        local Job, Grade = CheckJob()
        local allowed = false

        for jobName, minGrade in pairs(Config.MechanicJobs) do
            if Job == jobName and Grade >= minGrade then
                allowed = true
                break
            end
        end
        return allowed
    else
        return true
    end
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
    local distanceSinceSparkPlugChange = accumulatedDistance - lastSparkPlugChange
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
    local oilDistanceDriven = accumulatedDistance - lastOilChange
    local oilWearRatio = oilDistanceDriven / oilchangedist

    local filterDistanceDriven = accumulatedDistance - lastOilFilterChange
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
    local airFilterDistanceDriven = accumulatedDistance - lastAirFilterChange
    local airFilterWearRatio = math.min(1.0, airFilterDistanceDriven / airfilterchangedist)

    -- Get and save original drive force if not already saved
    local plate = normalizePlate(GetVehiclePlate(closestVehicle))
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

    -- Determine wheel count (best-effort). Check common wheel bone names.
    local function getCachedWheelCount(veh)
        local bones = {"wheel_lf","wheel_rf","wheel_lr","wheel_rr","wheel_lm","wheel_rm"}
        local count = 0
        for i, b in ipairs(bones) do
            local idx = GetEntityBoneIndexByName(veh, b)
            if idx ~= -1 then count = count + 1 end
        end
        -- Fallback to 4 if detection failed
        if count == 0 then count = 4 end
        -- Cap at 6 (we track 0..5)
        if count > 6 then count = 6 end
        return count
    end

    local wc = getCachedWheelCount(vehicle)
    local mode = Config.TireWearMode or "distance"
    for i = 0, wc - 1 do
        local idx = i + 1 -- Lua array index
        -- distance-based wear (legacy)
        local distWear = 0.0
        if mode == "distance" or mode == "both" then
            local distanceSinceChange = accumulatedDistance - (lastTireChange[idx] or 0.0)
            distWear = distanceSinceChange / tirechangedist
            if distWear > 1 then distWear = 1 end
        end

        -- slip-based wear is accumulated into `tireWear[idx]` by the slip thread
        local slipWear = tireWear[idx] or 0.0

        if mode == "distance" then
            tireWear[idx] = distWear
        elseif mode == "slip" then
            tireWear[idx] = math.min(1.0, slipWear)
        else -- both: choose the larger effect to reflect worst-case wear
            tireWear[idx] = math.min(1.0, math.max(distWear, slipWear))
        end

        -- If tyre is burst, consider it fully worn
        if IsVehicleTyreBurst(vehicle, i, false) then
            tireWear[idx] = 1.0
        end
    end

    -- Apply average grip reduction based on mean tire wear to maintain handling stability
    local sum = 0
    for i = 1, wc do sum = sum + (tireWear[i] or 0) end
    local avgWear = (wc > 0) and (sum / wc) or 0
    local newGrip = Config.BaseTireGrip - ((Config.BaseTireGrip - Config.MinTireGrip) * avgWear)
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
    -- Best-effort: detect wheel count like tires
    local function getCachedWheelCount(veh)
        local bones = {"wheel_lf","wheel_rf","wheel_lr","wheel_rr","wheel_lm","wheel_rm"}
        local count = 0
        for i, b in ipairs(bones) do
            local idx = GetEntityBoneIndexByName(veh, b)
            if idx ~= -1 then count = count + 1 end
        end
        if count == 0 then count = 4 end
        if count > 6 then count = 6 end
        return count
    end

    local wc = getCachedWheelCount(vehicle)
    -- Compute an averaged brake efficiency based on per-wheel wear (brakeWear stores 0..MaxBrakeWear)
    local sum = 0
    for i = 1, wc do
        sum = sum + (brakeWear[i] or 0.0)
    end
    local avgWear = (wc > 0) and (sum / wc) or 0.0 -- avgWear in 0..Config.MaxBrakeWear
    -- update legacy scalar for compatibility and warnings
    lastbrakeWear = avgWear
    -- normalized fraction (0..1)
    local norm = math.min(avgWear, Config.MaxBrakeWear) / Config.MaxBrakeWear
    local efficiency = 1.0 - (norm * Config.BrakeEfficiencyLoss)
    local baseBrakeForce = Config.BaseBrakeForce
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
    local distanceSinceSuspensionChange = accumulatedDistance - lastSuspensionChange
    -- Calculate wear ratio (0 = new, 1 = fully worn)
    local wearRatio = distanceSinceSuspensionChange / (Config.SuspensionChangeDistance * 1000)
    if wearRatio > 1 then wearRatio = 1 end

    local plate = normalizePlate(GetVehiclePlate(closestVehicle))
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
        sparkPlugDistanceDriven = accumulatedDistance - lastSparkPlugChange
        sparkPlugLifeRemaining = math.max(0, sparkPlugchangedist - sparkPlugDistanceDriven)
        sparkPlugPercentage = math.floor((sparkPlugLifeRemaining / sparkPlugchangedist) * 100)
    end
    if Config.WearTracking.Oil then
        oilDistanceDriven = accumulatedDistance - lastOilChange
        oilLifeRemaining = math.max(0, oilchangedist - oilDistanceDriven)
        oilPercentage = math.floor((oilLifeRemaining / oilchangedist) * 100)

        filterDistanceDriven = accumulatedDistance - lastOilFilterChange
        filterLifeRemaining = math.max(0, oilfilterchangedist - filterDistanceDriven)
        filterPercentage = math.floor((filterLifeRemaining / oilfilterchangedist) * 100)
    end
    if Config.WearTracking.AirFilter then
        airFilterDistanceDriven = accumulatedDistance - lastAirFilterChange
        airFilterLifeRemaining = math.max(0, airfilterchangedist - airFilterDistanceDriven)
        airFilterPercentage = math.floor((airFilterLifeRemaining / airfilterchangedist) * 100)
    end
    if Config.WearTracking.Tires then
        -- compute per-tire percentages only for detected wheels
        local wc = 4
        if DoesEntityExist(veh) then
            wc = getCachedWheelCount(veh)
        end
        tirePercentage = {}
        for i = 1, wc do
            local w = tireWear[i] or 0
            tirePercentage[i] = math.floor((1 - w) * 100)
        end
    end
    if Config.WearTracking.Brakes then
        local wc = 4
        if DoesEntityExist(veh) then
            wc = getCachedWheelCount(veh)
        end
        brakePercentage = {}
        for i = 1, wc do
            local w = brakeWear[i] or 0
            brakePercentage[i] = math.floor((1 - (w / Config.MaxBrakeWear)) * 100)
        end
    end
    if Config.WearTracking.Suspension then
        suspensionDistanceDriven = accumulatedDistance - lastSuspensionChange
        suspensionLifeRemaining = math.max(0, Config.SuspensionChangeDistance * 1000 - suspensionDistanceDriven)
        suspensionPercentage = math.floor((suspensionLifeRemaining / (Config.SuspensionChangeDistance * 1000)) * 100)
    end
    if Config.WearTracking.Clutch then
        clutchPercentage = math.floor((1 - (lastClutchWear / Config.MaxClutchWear)) * 100)
    end
    displayedMileage = convertDistance(accumulatedDistance)
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

local function canOpenServiceMenu()
    local closestVehicle, _ = lib.getClosestVehicle(GetEntityCoords(PlayerPedId()), 5.0, true)
    local plate = normalizePlate(GetVehiclePlate(closestVehicle))
    if not plate then return false end

    local expiresAt = wearCheckAccess[plate]
    if not expiresAt then
        return false
    end

    if GetGameTimer() > expiresAt then
        wearCheckAccess[plate] = nil
        return false
    end

    return true
end

--[[
    Opens the service menu for the player, using the configured menu system.
    - If Config.Menu is "ox", shows the ox_lib context menu.
    - If Config.Menu is "qb", opens the qb-menu with all available service options.
    Each menu option triggers a client event to perform the selected maintenance action.
]]--
local function openServiceMenu()
    if not canOpenServiceMenu() then
        Notify('Wizard Mileage', locale('warning.check_veh'), 'error')
    return
end
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

    local plate = normalizePlate(GetVehiclePlate(vehicle))
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
    
    wearCheckAccess[plate] = GetGameTimer() + 120000
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
local function DoMaintenance(item, errorMSG, configData, progressMSG, isAdv, quantity)
    if not isMechanic() then
        Notify('Wizard Mileage', locale("error.not_mechanic"), "error")
        return
    end


    if Config.InventoryItems and not checkInventoryItem(item) then
        Notify('Wizard Mileage', locale("error." .. errorMSG), "error")
        return
    end

    local closestVehicle, _ = lib.getClosestVehicle(GetEntityCoords(PlayerPedId()), 5.0, true)
    if not closestVehicle then
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
        TriggerServerEvent('wizard_vehiclemileage:server:removeItem', item, quantity or 1)
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
    lastVehiclePosition = GetEntityCoords(veh)
    waitingForData = true
    accumulatedDistance = 0.0
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
        lastVehiclePosition = nil
        accumulatedDistance = 0.0
        currentPlate = nil
        waitingForData = false
        lastOilChange = 0.0
        lastOilFilterChange = 0.0
        lastAirFilterChange = 0.0
        lastTireChange = {0.0,0.0,0.0,0.0,0.0,0.0}
        lastbrakeChange = {0.0,0.0,0.0,0.0,0.0,0.0}
        tireWear = {0.0,0.0,0.0,0.0,0.0,0.0}
        brakeWear = {0.0,0.0,0.0,0.0,0.0,0.0}
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
        local savedMil = accumulatedDistance
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
        if tireWearDirty then
            TriggerServerEvent("wizard_vehiclemileage:server:updateTireWearAll", currentPlate, tireWear)
            tireWearDirty = false
        end
        TriggerServerEvent('wizard_vehiclemileage:server:updateMileage', currentPlate, savedMil)
        TriggerServerEvent('wizard_vehiclemileage:server:updateSparkPlugWear', currentPlate, savedPlugWear)
        TriggerServerEvent('wizard_vehiclemileage:server:updateSuspensionWear', currentPlate, savedSusWear)
    end
end





--==========================================================================
--
--                                 THREADS
--
--==========================================================================

--[[
    Cache listeners for vehicle, seat, and ped state changes.

    - Detects when the player enters or exits a vehicle.
    - Validates vehicle class and ownership before loading data.
    - Loads wear/mileage data only when the player is the driver.
    - Clears data when leaving the driver seat or vehicle.
    - Keeps the local player ped reference updated.

    These cache hooks ensure vehicle data is loaded and cleared safely
    based on the player’s current context.
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
        currentPlate = normalizePlate(GetVehiclePlate(veh))
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

--[[
    Main interaction and mileage management thread.

    - Handles vehicle interaction validation and ownership checks.
    - Registers target interactions for servicing and inspecting vehicles.
    - Builds and manages the vehicle service menu system.
    - Sends live wear data updates to the NUI interface.
    - Tracks traveled distance and updates the displayed mileage in real time.

    This thread controls the core interaction flow between the player,
    vehicle systems, targeting, UI updates, and mileage calculations.
]]--
CreateThread(function()
    local lastMileage = -1
    local nuiWearCache = nil

    local function canInteractVehicle(entity)
        if inAnyVeh then
            return false
        end

        local plate = normalizePlate(GetVehiclePlate(entity))

        if not IsVehicleOwned(plate) then
            return false
        end

        return not Config.DisabledVehicleClasses[GetVehicleClass(entity)]
    end

    local function calculateAverage(table)
        if not table then
            return 0
        end

        local total = 0
        local count = 0

        for _, value in pairs(table) do
            total += value or 0
            count += 1
        end

        return count > 0 and floor(total / count) or 0
    end

    local function sendWearUpdate()
        if not currentWear then
            return
        end

        nuiWearCache = {
            type = "updateWear",
            showUI = false,

            sparkPlugPercentage = currentWear.sp,
            oilPercentage = currentWear.oil,
            filterPercentage = currentWear.filter,
            airFilterPercentage = currentWear.airFilter,

            tirePercentage = currentWear.tire,
            tirePercentageAvg = calculateAverage(currentWear.tire),

            brakePercentage = currentWear.brake,
            brakePercentageAvg = calculateAverage(currentWear.brake),

            suspensionPercentage = currentWear.suspension,
            clutchPercentage = currentWear.clutch
        }

        SendNUIMessage(nuiWearCache)
    end

    if Config.Targeting then
        if Config.Targeting == "ox" then
            exports.ox_target:addGlobalVehicle({
                {
                    name = "vehicle_service",
                    icon = "fas fa-wrench",
                    label = "Service Vehicle",

                    canInteract = function(entity)
                        local allowed = canInteractVehicle(entity)

                        if allowed then
                            sendWearUpdate()
                        end

                        return allowed
                    end,

                    onSelect = function()
                        if not isMechanic() then
                            Notify('Wizard Mileage', locale("error.not_mechanic"), "error")
                            return
                        end

                        openServiceMenu()
                    end
                },

                {
                    name = "vehicle_check",
                    icon = "fas fa-info",
                    label = "Check Vehicle",

                    canInteract = canInteractVehicle,

                    onSelect = function(data)
                        openCheckWearMenu(data.entity)
                    end
                }
            })

        elseif Config.Targeting == "qb" then
            exports["qb-target"]:AddGlobalVehicle({
                options = {
                    {
                        type = "client",
                        icon = "fas fa-wrench",
                        label = "Service Vehicle",

                        canInteract = canInteractVehicle,

                        action = function()
                            if not isMechanic() then
                                Notify('Wizard Mileage', locale("error.not_mechanic"), "error")
                                return
                            end

                            sendWearUpdate()
                            openServiceMenu()
                        end
                    },

                    {
                        type = "client",
                        icon = "fas fa-info",
                        label = "Check Vehicle",

                        canInteract = canInteractVehicle,

                        action = function(data)
                            openCheckWearMenu(data.entity)
                        end
                    }
                },

                distance = 2.5
            })
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
        Wait(waitTimeMain)

        if isInVehicle and not waitingForData and veh and DoesEntityExist(veh) then
            local currentPos = GetEntityCoords(veh)
            local vehSpeed = GetEntitySpeed(veh)

            if lastVehiclePosition and vehSpeed > 0.1 then
                accumulatedDistance += getDistance(lastVehiclePosition, currentPos)

                local displayedMileage = convertDistance(accumulatedDistance)

                if displayedMileage ~= lastMileage then
                    lastMileage = displayedMileage

                    SendNUIMessage({
                        type = "updateMileage",
                        mileage = displayedMileage,
                        unit = (Cfg.Unit == "imperial" and "miles" or "km")
                    })
                end
            end

            lastVehiclePosition = currentPos
            waitTimeMain = 1000
        else
            waitTimeMain = 3000
        end
    end
end)

--[[
    Main vehicle wear tracking thread.

    - Continuously monitors brake and tire wear while the player is inside a vehicle.
    - Applies brake wear based on speed, braking intensity, vehicle weight, and passenger count.
    - Applies tire wear during drifting and burnouts depending on vehicle behavior.
    - Periodically updates engine-related systems and synchronizes wear data.
    - Detects burst tires and forces tire wear synchronization when needed.

    This thread acts as the core runtime handler for all dynamic vehicle wear calculations.
]]--
CreateThread(function()
    local updateAccum = 0
    
    while true do
        Wait(500)

        local wc = nil
        if DoesEntityExist(veh) then
            wc = getCachedWheelCount(veh)
        end

        if isInVehicle and Config.WearTracking.Brakes and wc then
            local speed = GetEntitySpeed(veh) or 0.0
            local speedKmh = speed * 3.6
            if not _G._wm_prevSpeed then _G._wm_prevSpeed = speed end
            local prev = _G._wm_prevSpeed or speed
            local delta = prev - speed
            local braking = IsControlPressed(0, 72)
            local slamThr = (Config.Brake and Config.Brake.SlamDeltaThreshold) or 5.0
            if braking and delta > 0.01 then
                local brakingFactor = math.max(0.0, math.min(1.0, delta / math.max(0.001, slamThr)))
                local speedFactor = 1.0 + (speedKmh * ((Config.Brake and Config.Brake.SpeedScalingKmh) or 0.02))

                local currentPassengerTotal = GetVehicleNumberOfPassengers(veh)
                if currentPassengerTotal ~= cachedPassengerVehTotal then
                    local passengerCount = 0
                    local frontPassenger = false
                    for seat = -1, 5 do
                        local ped = GetPedInVehicleSeat(veh, seat)
                        if ped and ped ~= 0 and ped ~= PlayerPedId() then
                            passengerCount = passengerCount + 1
                            if seat == 0 then frontPassenger = true end
                        end
                    end
                    cachedPassengerCount = passengerCount
                    cachedFrontPassenger = frontPassenger
                    cachedPassengerVehTotal = currentPassengerTotal
                end
                local passengerCount = cachedPassengerCount
                local frontPassenger = cachedFrontPassenger

                local mass = GetVehicleHandlingFloat(veh, "CHandlingData", "fMass") or 1500.0
                local massFactor = math.max(0.5, math.min(2.0, (mass / 1500.0)))
                local passengerFactor = ((Config.Brake and Config.Brake.PassengerWeightFactor) or 0.25)
                local weightMultiplier = 1.0 + (passengerCount * passengerFactor) + ((massFactor - 1.0) * 0.5)

                local driverSideIsLeft = true
                for i = 1, wc do
                    local isFront = (i == 1 or i == 2)
                    local base = (Config.BrakeWearRate or 0.08)
                    local sideBias = 1.0
                    if isFront then
                        if passengerCount == 0 then
                            if driverSideIsLeft and i == 1 then
                                sideBias = (Config.Brake and Config.Brake.DriverSideBias) or 1.25
                            elseif (not driverSideIsLeft) and i == 2 then
                                sideBias = (Config.Brake and Config.Brake.DriverSideBias) or 1.25
                            end
                        elseif frontPassenger then
                            sideBias = (Config.Brake and Config.Brake.FrontBothBias) or 1.1
                        end
                        local wearAdd = base * (1.0 + brakingFactor * 4.0) * speedFactor * weightMultiplier * sideBias
                        brakeWear[i] = math.min((Config.MaxBrakeWear or 100.0), (brakeWear[i] or 0.0) + wearAdd)
                    else
                        local rearFactor = (Config.Brake and Config.Brake.RearBrakeFactor) or 0.45
                        local wearAdd = base * (1.0 + brakingFactor * 2.0) * speedFactor * weightMultiplier * rearFactor
                        brakeWear[i] = math.min((Config.MaxBrakeWear or 100.0), (brakeWear[i] or 0.0) + wearAdd)
                    end
                end
                brakeWearDirty = true
            end
            _G._wm_prevSpeed = speed
        end

        if isInVehicle and Config.WearTracking.Tires and wc then local vel = GetEntitySpeedVector(veh, true)
            local lateral = math.abs(vel.y or 0.0)
            local speed = GetEntitySpeed(veh)
            local rpm = GetVehicleCurrentRpm(veh) or 0.0
            local driftThr = (Config.Slip and Config.Slip.DriftThreshold) or 3.0
            local driftWear = (Config.Slip and Config.Slip.DriftWear) or 0.003
            local boRpmThr = (Config.Slip and Config.Slip.BurnoutRpmThreshold) or 0.6
            local boSpeedThr = (Config.Slip and Config.Slip.BurnoutSpeedThreshold) or 1.0
            local boWear = (Config.Slip and Config.Slip.BurnoutWear) or 0.01

            if lateral > driftThr then
                local factor = math.min(1.0, (lateral - driftThr) / 8.0)
                for i = 1, wc do
                    local base = (i > 2) and driftWear or (driftWear * 0.5)
                    tireWear[i] = math.min(1.0, (tireWear[i] or 0.0) + base * factor)
                    tireWearDirty = true
                end
            end

            if rpm > boRpmThr and speed < boSpeedThr and IsControlPressed(0, 71) then
                local driveBiasFront = GetVehicleHandlingFloat(veh, "CHandlingData", "fDriveBiasFront") or 0.5
                for i = 1, wc do
                    local isFront = (i == 1 or i == 2)
                    local applies = false
                    if driveBiasFront >= 0.55 then applies = isFront
                    elseif driveBiasFront <= 0.45 then applies = not isFront
                    else applies = true end
                    if applies then
                        local extra = boWear * (1.0 + (rpm - boRpmThr))
                        tireWear[i] = math.min(1.0, (tireWear[i] or 0.0) + extra)
                        tireWearDirty = true
                    end
                end
            end
        end

        updateAccum = updateAccum + 250
        local threshold = isInVehicle and 3000 or 5000
        if updateAccum >= threshold then
            updateAccum = 0
            if isInVehicle and not waitingForData then
                updateSparkPlugWear(veh)
                updateEngineDamage(veh)
                updateAirFilterPerformance(veh)
                updateSuspensionWear(veh)
                updateTireWear(veh)

                if Config.WearTracking.Tires and wc then
                    for i = 1, wc do for i = 1, wc do
                        local tireIndex = i - 1

                        if IsVehicleTyreBurst(veh, tireIndex, false) then
                            if tireWear[i] ~= 1.0 then
                                tireWear[i] = 1.0
                                tireWearDirty = true
                            end

                            if not tireBurstSynced[i] then
                                tireBurstSynced[i] = true

                                if currentPlate then
                                    TriggerServerEvent('wizard_vehiclemileage:server:updateTireWearAll', currentPlate, tireWear, lastTireChange)
                                end
                            end
                        else
                            tireBurstSynced[i] = nil
                        end
                    end
                    end
                end
            end
        end
    end
end)

--[[
    Tracks clutch wear based on vehicle gear changes.

    - Runs only when clutch wear tracking is enabled.
    - Detects valid gear shifts while the player is inside a vehicle.
    - Applies extra wear when multiple gears are skipped.
    - Clamps clutch wear to the configured maximum value.
    - Marks clutch data as dirty and updates the current vehicle wear state.

    This thread keeps clutch wear synced with real driving behavior instead of
    applying wear on a fixed timer.
]]--
CreateThread(function()
    if not Config.WearTracking.Clutch then return end
    local prevGear = 0
    local lastShiftTime = 0
    local shiftCooldown = 500 -- Minimum ms between gear shifts to count as wear
    while true do
        if isInVehicle then
            if currentPlate and allowSmartGearDetect then
                waitTimeClutch = 1500
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
            waitTimeClutch = 2000
        end
        Wait(waitTimeClutch)
    end
end)

--[[
    Periodically updates vehicle wear data for the NUI.

    - Refreshes current vehicle wear information while driving.
    - Compares the latest wear values with the previous state.
    - Sends NUI updates only when wear data has changed.
    - Prevents unnecessary UI refreshes and reduces message spam.

    This thread keeps the wear interface synchronized efficiently.
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





--==========================================================================
--
--                                NET EVENTS
--
--==========================================================================

--[[
    Handles the spark plug change event.
    Checks job/inventory requirements, plays animation, removes item, and updates server and local state.
]]--
RegisterNetEvent('wizard_vehiclemileage:client:changesparkplug')
AddEventHandler('wizard_vehiclemileage:client:changesparkplug', function()
    if isInVehicle then
        Notify('Wizard Mileage', locale("error.in_vehicle"), "error")
        return
    end
    local Stats, closestVehicle = DoMaintenance(Config.Items.SparkPlug, "no_spark_plug", Config.ChangeSparkPlug, "changingsparkplug")
    if Stats then
        local plate = normalizePlate(GetVehiclePlate(closestVehicle))
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
    if isInVehicle then
        Notify('Wizard Mileage', locale("error.in_vehicle"), "error")
        return
    end
    local Stats, closestVehicle = DoMaintenance(Config.Items.EngineOil, "no_oil", Config.ChangeOil, "changingoil", true)
    if Stats then
        local plate = normalizePlate(GetVehiclePlate(closestVehicle))
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
    if isInVehicle then
        Notify('Wizard Mileage', locale("error.in_vehicle"), "error")
        return
    end
    local Stats, closestVehicle = DoMaintenance(Config.Items.OilFilter, "no_oil_filter", Config.ChangeOilFilter, "changingoilfilter", true)
    if Stats then
        local plate = normalizePlate(GetVehiclePlate(closestVehicle))
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
    if isInVehicle then
        Notify('Wizard Mileage', locale("error.in_vehicle"), "error")
        return
    end
    local Stats, closestVehicle = DoMaintenance(Config.Items.AirFilter, "no_air_filter", Config.ChangeAirFilter, "changingairfilter", true)
    if Stats then
        local plate = normalizePlate(GetVehiclePlate(closestVehicle))
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
    if isInVehicle then
        Notify('Wizard Mileage', locale("error.in_vehicle"), "error")
        return
    end
    local closestVehicle, _ = lib.getClosestVehicle(GetEntityCoords(PlayerPedId()), 5.0, true)
    if not closestVehicle then Notify('Wizard Mileage', locale('error.not_found'), 'error') return end
    local wc = getCachedWheelCount(closestVehicle)
    local values = {}
    local labels = {}
    for i = 1, wc do
        local w = tireWear[i] or 0.0
        values[#values+1] = math.floor((1 - w) * 100)
    end
    if wc == 4 then labels = {'FL','FR','RL','RR'} elseif wc == 2 then labels = {'L','R'} else
        for i=1,wc do labels[#labels+1] = 'W'..i end
    end
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openMaintenance', payload = { type = 'tire', values = values, labels = labels } })
end)

--[[
    Handles the brake change event.
    Checks job/inventory requirements, plays animation, removes item, and updates server and local state.
]]--
RegisterNetEvent('wizard_vehiclemileage:client:changebrakes')
AddEventHandler('wizard_vehiclemileage:client:changebrakes', function()
    if isInVehicle then
        Notify('Wizard Mileage', locale("error.in_vehicle"), "error")
        return
    end
    local _, closestVehicle = lib.getClosestVehicle(GetEntityCoords(PlayerPedId()), 5.0, true)
    if not closestVehicle then Notify('Wizard Mileage', locale('error.not_found'), 'error') return end
    local wc = getCachedWheelCount(closestVehicle)
    local values = {}
    local labels = {}
    for i = 1, wc do
        local bw = brakeWear[i] or 0.0
        local maxB = Config.MaxBrakeWear or 100.0
        values[#values+1] = math.floor((1 - (bw / maxB)) * 100)
    end
    if wc == 4 then labels = {'FL','FR','RL','RR'} elseif wc == 2 then labels = {'L','R'} else
        for i=1,wc do labels[#labels+1] = 'W'..i end
    end
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openMaintenance', payload = { type = 'brake', values = values, labels = labels } })
end)

--[[
    Handles the suspension change event.
    Checks job/inventory requirements, plays animation, removes item, and updates server and local state.
]]--
RegisterNetEvent('wizard_vehiclemileage:client:changesuspension')
AddEventHandler('wizard_vehiclemileage:client:changesuspension', function()
    if isInVehicle then
        Notify('Wizard Mileage', locale("error.in_vehicle"), "error")
        return
    end
    local Stats, closestVehicle = DoMaintenance(Config.Items.SusParts, "no_suspension_parts", Config.ChangeSuspension, "changingsuspension")
    if Stats then
        local plate = normalizePlate(GetVehiclePlate(closestVehicle))
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
    if isInVehicle then
        Notify('Wizard Mileage', locale("error.in_vehicle"), "error")
        return
    end
    local Stats, closestVehicle = DoMaintenance(Config.Items.Clutch, "no_clutch", Config.ChangeClutch, "changingclutch")
    if Stats then
        local plate = normalizePlate(GetVehiclePlate(closestVehicle))
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
AddEventHandler('wizard_vehiclemileage:client:setData', function(mileage, oilChange, filterChange, AirfilterChange, tireChange, brakeChange, brakeWearParam, clutchChange, clutchWearParam, origDriveForce, lastSuspensionChangeVal, suspensionWearVal, lastSparkPlugChangeVal, sparkPlugWearVal, tireWearJson, lastTireChangeJson, brakeWearJson, lastBrakeChangeJson)
    accumulatedDistance = mileage or 0.0
    lastOilChange = oilChange or 0.0
    lastOilFilterChange = filterChange or 0.0
    lastAirFilterChange = AirfilterChange or 0.0

    -- Handle tire wear data (JSON or Table fallback)
    -- We ensure values are mapped correctly to show actual health instead of 100% default
    if type(tireWearJson) == 'string' and #tireWearJson > 0 then
        local ok, parsed = pcall(json.decode, tireWearJson)
        if ok and type(parsed) == 'table' then
            for i = 1, 6 do tireWear[i] = tonumber(parsed[i]) or 0.0 end
        end
    elseif type(tireWearJson) == 'table' then
        for i = 1, 6 do tireWear[i] = tonumber(tireWearJson[i]) or 0.0 end
    end

    -- Handle brake wear data (JSON or Table fallback)
    if type(brakeWearJson) == 'string' and #brakeWearJson > 0 then
        local ok, parsed = pcall(json.decode, brakeWearJson)
        if ok and type(parsed) == 'table' then
            for i = 1, 6 do brakeWear[i] = tonumber(parsed[i]) or 0.0 end
        end
    elseif type(brakeWearJson) == 'table' then
        for i = 1, 6 do brakeWear[i] = tonumber(brakeWearJson[i]) or 0.0 end
    elseif type(brakeWearParam) == 'number' then
        for i = 1, 6 do brakeWear[i] = brakeWearParam end
    end


    if type(clutchChange) == 'number' then lastClutchChange = clutchChange end
    if type(clutchWearParam) == 'number' then lastClutchWear = clutchWearParam end
    originalDriveForce = origDriveForce
    lastSuspensionChange = lastSuspensionChangeVal or 0.0
    suspensionWear = suspensionWearVal or 0.0
    lastSparkPlugChange = lastSparkPlugChangeVal or 0.0
    sparkPlugWear = sparkPlugWearVal or 0.0
    waitingForData = false
    loaded = true
    local displayedMileage = convertDistance(accumulatedDistance)
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
        playerPed = PlayerPedId()
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





--==========================================================================
--
--                             AUTOSAVE SYSTEM
--
--==========================================================================

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
                if accumulatedDistance - lastSavedMileage > Config.MinDiffToSave then
                    lastSavedMileage = accumulatedDistance
                    TriggerServerEvent('wizard_vehiclemileage:server:updateMileage', currentPlate, accumulatedDistance)
                end
                -- Persist per-wheel wear if dirty to avoid data loss while in vehicle
                if tireWearDirty and currentPlate then
                    TriggerServerEvent("wizard_vehiclemileage:server:updateTireWearAll", currentPlate, tireWear)
                    TriggerServerEvent("wizard_vehiclemileage:server:updateTireChangeAll", currentPlate, lastTireChange)
                    tireWearDirty = false
                end
                if brakeWearDirty and currentPlate then
                    TriggerServerEvent("wizard_vehiclemileage:server:updateBrakeWearAll", currentPlate, brakeWear)
                    TriggerServerEvent("wizard_vehiclemileage:server:updateBrakeChangeAll", currentPlate, lastbrakeChange)
                    brakeWearDirty = false
                end
            end
        end
    end)
end





--==========================================================================
--
--                             WARNING SYSTEM
--
--==========================================================================

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
            computeDistance = function() return accumulatedDistance - lastSparkPlugChange end,
            thresholds = Config.Thresholds.SparkPlugs,
            localeKey = "warning.remaining_spark_plug"
        }
    end
    if Config.WearTracking.Oil then
        components.oil = {
            lastChange = function() return lastOilChange end,
            changedist = oilchangedist,
            computeDistance = function() return accumulatedDistance - lastOilChange end,
            thresholds = Config.Thresholds.Oil,
            localeKey = "warning.remaining_oil"
        }
        components.filter = {
            lastChange = function() return lastOilFilterChange end,
            changedist = oilfilterchangedist,
            computeDistance = function() return accumulatedDistance - lastOilFilterChange end,
            thresholds = Config.Thresholds.OilFilter,
            localeKey = "warning.remaining_filter"
        }
    end
    if Config.WearTracking.AirFilter then
        components.airFilter = {
            lastChange = function() return lastAirFilterChange end,
            changedist = airfilterchangedist,
            computeDistance = function() return accumulatedDistance - lastAirFilterChange end,
            thresholds = Config.Thresholds.AirFilter,
            localeKey = "warning.remaining_air_filter"
        }
    end
    if Config.WearTracking.Tires then
        components.tire = {
            lastChange = function() return lastTireChange end,
            changedist = tirechangedist,
            computeDistance = function()
                -- compute worst (max) distance driven since last change among tracked wheels
                local wc = 6
                local maxDist = 0
                for i = 1, wc do
                    local lt = tonumber(lastTireChange[i]) or 0.0
                    local d = accumulatedDistance - lt
                    if d > maxDist then maxDist = d end
                end
                return maxDist
            end,
            thresholds = Config.Thresholds.Tires,
            localeKey = "warning.remaining_tire"
        }
    end
    if Config.WearTracking.Suspension then
        components.suspension = {
            lastChange = function() return lastSuspensionChange end,
            changedist = Config.SuspensionChangeDistance * 1000,
            computeDistance = function() return accumulatedDistance - lastSuspensionChange end,
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





--==========================================================================
--
--                              NUI CALLBACKS
--
--==========================================================================

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
    Handles a confirmation request from the NUI and shows a dialog to the player.
    - Receives a confirmation message from the UI through an NUI callback.
    - Displays a centered alert dialog using the UI library.
    - Allows the player to either confirm or cancel the action.
    - Sends the result back to the NUI indicating whether the player confirmed.
]]--
RegisterNUICallback('confirmDialog', function(data, cb)
    local alert = lib.alertDialog({
        header = 'Confirm',
        content = data.message or 'Are you sure?',
        centered = true,
        cancel = true
    })

    cb({
        confirmed = alert == 'confirm'
    })
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

--[[
    Handles the NUI request to replace selected vehicle parts (tires or brake pads).
    - Receives the selected wheel indices and part type from the UI.
    - Validates that at least one part is selected before continuing.
    - Determines the correct item, progress configuration, and error messages.
    - Finds the closest vehicle and normalizes its plate for server synchronization.
    - Runs the maintenance process for each selected part using DoMaintenance().
    - Updates the corresponding wear values and last replacement distance locally.
    - Syncs the updated wear data with the server once replacements are completed.
    - Handles partial failures if maintenance stops midway through the selection.
    - Sends the final result back to the NUI with success state and replacement count.
]]--
RegisterNUICallback('replaceParts', function(data, cb)
    local sel = data.selected or {}
    local partType = data.type or 'tire'

    SetNuiFocus(false, false)

    if #sel == 0 then
        if cb then cb({ success = false, reason = 'no_selection' }) end
        return
    end

    local isTire = (partType == 'tire')
    local itemName = isTire
        and ((Config.Items and Config.Items.Tires) or 'tires')
        or ((Config.Items and (Config.Items.Brakes or Config.Items.BrakeParts)) or 'brake_parts')

    local errorMsg = isTire and 'no_tires' or 'no_brake_parts'
    local progressCfg = isTire and Config.ChangeTires or Config.ChangeBrakes
    local progressMsg = isTire and 'changingtires' or 'changingbrakes'

    local closestVehicle, _ = lib.getClosestVehicle(GetEntityCoords(PlayerPedId()), 5.0, true)
    local plate = normalizePlate(GetVehiclePlate(closestVehicle))

    if not plate or plate == '' then
        if cb then cb({ success = false, reason = 'no_plate' }) end
        return
    end

    local replacedCount = 0

    for _, idx in ipairs(sel) do
        local i = tonumber(idx)
        if i then
            i = i + 1

            local success = DoMaintenance(itemName, errorMsg, progressCfg, progressMsg, false, 1)
            if not success then
                if replacedCount == 0 then
                    if cb then cb({ success = false, reason = 'maintenance_failed' }) end
                else
                    if isTire then
                        tireWearDirty = true
                        TriggerServerEvent('wizard_vehiclemileage:server:updateTireWearAll', plate, tireWear)
                    else
                        brakeWearDirty = true
                        TriggerServerEvent('wizard_vehiclemileage:server:updateBrakeWearAll', plate, brakeWear)
                    end

                    if cb then
                        cb({
                            success = false,
                            reason = 'partial_failure',
                            replaced = replacedCount
                        })
                    end
                end
                return
            end

            if isTire then
                tireWear[i] = 0.0
                lastTireChange[i] = accumulatedDistance

                if closestVehicle and DoesEntityExist(closestVehicle) then
                    local tireIndex = i - 1
                    if IsVehicleTyreBurst(closestVehicle, tireIndex, false) then
                        SetVehicleTyreFixed(closestVehicle, tireIndex)
                    end
                end
            else
                brakeWear[i] = 0.0
                lastbrakeChange[i] = accumulatedDistance
            end

            replacedCount = replacedCount + 1
        end
    end

    if replacedCount > 0 then
        if isTire then
            tireWearDirty = true
            TriggerServerEvent('wizard_vehiclemileage:server:updateTireWearAll', plate, tireWear)
            Notify('Wizard Mileage', locale('info.tire_changed'), 'success')
        else
            brakeWearDirty = true
            TriggerServerEvent('wizard_vehiclemileage:server:updateBrakeWearAll', plate, brakeWear)
            Notify('Wizard Mileage', locale('info.brakes_changed'), 'success')
        end
    end

    if cb then
        cb({
            success = true,
            replaced = replacedCount
        })
    end
end)





--==========================================================================
--
--                                COMMANDS
--
--==========================================================================

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





--==========================================================================
--
--                                 EXPORTS
--
--==========================================================================

--[[
    Exports for other scripts to interact with vehicle mileage and maintenance data.
    Provides functions to get/set mileage, parts change history, and wear levels.
]]--
exports('GetVehicleMileage', function()
    return accumulatedDistance
end)

--[[
    Set vehicle mileage.
    Can be used to set the mileage directly, e.g., for testing or resetting.
    If no mileage is provided, it uses the current accumulated distance.
]]--
exports('SetVehicleMileage', function(mileage)
    accumulatedDistance = mileage or accumulatedDistance
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
    -- Accept either a scalar (apply to all wheels) or a table of per-wheel values
    if partsChange.tireChange ~= nil then
        if type(partsChange.tireChange) == 'number' then
            for i = 1, 6 do lastTireChange[i] = partsChange.tireChange end
        elseif type(partsChange.tireChange) == 'table' then
            for i = 1, 6 do lastTireChange[i] = tonumber(partsChange.tireChange[i]) or lastTireChange[i] end
        end
    end
    if partsChange.brakeChange ~= nil then
        if type(partsChange.brakeChange) == 'number' then
            for i = 1, 6 do lastbrakeChange[i] = partsChange.brakeChange end
        elseif type(partsChange.brakeChange) == 'table' then
            for i = 1, 6 do lastbrakeChange[i] = tonumber(partsChange.brakeChange[i]) or lastbrakeChange[i] end
        end
    end
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
    if partsWear.brakeWear ~= nil then
        if type(partsWear.brakeWear) == 'number' then
            lastbrakeWear = partsWear.brakeWear
            for i = 1, 6 do brakeWear[i] = partsWear.brakeWear end
        elseif type(partsWear.brakeWear) == 'table' then
            for i = 1, 6 do brakeWear[i] = tonumber(partsWear.brakeWear[i]) or brakeWear[i] end
            -- update legacy scalar
            local sum = 0
            for i = 1, 6 do sum = sum + (brakeWear[i] or 0.0) end
            lastbrakeWear = (sum / 6)
        end
    end
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

