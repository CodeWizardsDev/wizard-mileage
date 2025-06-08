---------------- Main data ----------------
local mileageVisible, inVehicle, waitingForData, clutchWearDirty, brakeWearDirty, allowSmartGearDetect, mileageUIVisible, lastPos, currentPlate, oilchangedist, oilfilterchangedist, airfilterchangedist, tirechangedist = false, false, false, false, false, true, true, nil, nil, nil, nil, nil, nil
local accDistance, lastOilChange, lastOilFilterChange, lastAirFilterChange, lastTireChange, lastbrakeChange, lastbrakeWear, lastClutchChange, lastClutchWear, lastSuspensionChange, suspensionWear, lastSparkPlugChange, sparkPlugWear, cachedClutchWear, cachedBrakeWear, mileageUIPosX, mileageUIPosY, checkwearUIPosX, checkwearUIPosY, mileageUISize, checkwearUISize, lastEngineCriticalNotify = 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0
local adminCallbacks, vehicleListCallbacks = {}, {} 


---------------- Framework initialize ----------------
if Config.FrameWork == 'esx' then
    ESX = exports["es_extended"]:getSharedObject()
    RegisterNetEvent('esx:playerLoaded')
    AddEventHandler('esx:playerLoaded', function(xPlayer)
	    ESX.PlayerData = xPlayer
	    ESX.PlayerLoaded = true
    end)
    function ChkJb()
        ESX = exports["es_extended"]:getSharedObject()
        return ESX.GetPlayerData().job.name
    end
    function ChkGr()
        ESX = exports["es_extended"]:getSharedObject()
        return ESX.GetPlayerData().job.grade
    end
else
    QBCore = exports['qb-core']:GetCoreObject()
    function ChkJb()
        local Player = QBCore.Functions.GetPlayerData()
        return Player.job.name
    end
    function ChkGr()
        local Player = QBCore.Functions.GetPlayerData()
        return Player.job.grade.level
    end
end


---------------- Mileage unit initialize ----------------
if Config.Unit == "km" then
    sparkPlugchangedist = Config.SparkPlugChangeDistance * 1000
    oilchangedist = Config.OilChangeDistance * 1000
    oilfilterchangedist = Config.OilFilterDistance * 1000
    airfilterchangedist = Config.AirFilterDistance * 1000
    tirechangedist = Config.TireWearDistance * 1000
elseif Config.Unit == "mile" then
    sparkPlugchangedist = Config.SparkPlugChangeDistance * 1609.34
    oilchangedist = Config.OilChangeDistance * 1609.34
    oilfilterchangedist = Config.OilFilterDistance * 1609.34
    airfilterchangedist = Config.AirFilterDistance * 1609.34
    tirechangedist = Config.TireWearDistance * 1609.34
end


---------------- Bought vehicles detection ----------------
if Config.BoughtVehiclesOnly then
    local ownershipCache = {}
    function IsVehicleOwned(plate)
        if ownershipCache[plate] ~= nil then
            return ownershipCache[plate]
        end
        
        local p = promise.new()
        
        local function ownershipHandler(owned)
            ownershipCache[plate] = owned
            p:resolve(owned)
        end
        
        RegisterNetEvent('wizard_vehiclemileage:client:ownershipResult')
        local eventHandler = AddEventHandler('wizard_vehiclemileage:client:ownershipResult', ownershipHandler)
        
        TriggerServerEvent('wizard_vehiclemileage:server:checkOwnership', plate)
        
        local result = Citizen.Await(p)
        RemoveEventHandler(eventHandler)
        
        return result
    end
else
    function IsVehicleOwned()
        local p = promise.new()
        p:resolve(true)
        return Citizen.Await(p)
    end
end


---------------- Functions ----------------
local function Notify(message, type)
    if not message or not type then return end
    
    local notifyConfig = {
        wizard = function() exports['wizard-notify']:Send('Wizard Mileage', message, 5000, type) end,
        okok = function() exports['okokNotify']:Alert('Wizard Mileage', message, 5000, type, false) end,
        qbx = function() exports.qbx_core:Notify(message, type, 5000) end,
        qb = function() TriggerEvent('QBCore:Notify', source, message, type) end,
        esx = function() exports['esx_notify']:Notify(message, type, 5000, 'Wizard Mileage') end,
        ox = function() lib.notify{title = 'Wizard Mileage', description = message, type = type} end
    }
    
    local notifyFunc = notifyConfig[Config.Notify]
    if notifyFunc then notifyFunc() end
end
local function TriggerAdminCallback(cb)
    local cbId = math.random(100000, 999999)
    adminCallbacks[cbId] = cb
    TriggerServerEvent('wizard_vehiclemileage:server:isAdmin', cbId)
end
local function TriggerVehicleListCallback(cb)
    local cbId = math.random(100000, 999999)
    vehicleListCallbacks[cbId] = cb
    TriggerServerEvent('wizard_vehiclemileage:server:getAllVehicles', cbId)
end
local function DisplayProgressBar(duration, label, config)
    if Config.ProgressBar == 'qb' then
        QBCore.Functions.Progressbar("vehicle_maintenance", label, duration, false, config.Cancelable, {
            disableMovement = config.FreezePlayer,
            disableCarMovement = config.FreezeCar,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function()
        end, function()
        end)
        return true
    elseif Config.ProgressBar == 'ox' then
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
local function checkInventoryItem(item)
    if not Config.InventoryItems then return true end
    local hasItem = false
    if Config.InventoryScript == 'ox' then
        hasItem = exports.ox_inventory:Search('count', item) > 0
    elseif Config.InventoryScript == 'codem' then
        local hasItem = exports['codem-inventory']:HasItem(item, 1)
    elseif Config.InventoryScript == 'quasar' then
        local PlayerInv = exports['qs-inventory']:getUserInventory()
        for itemName, itemData in pairs(inventory) do
            if itemName == item then
                hasItem = true
                break
            end
        end
    elseif Config.InventoryScript == 'qb' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local Player = QBCore.Functions.GetPlayerData()
        for _, v in pairs(Player.items) do
            if v.name == item then
                hasItem = true
                break
            end
        end
    elseif Config.InventoryScript == 'esx' then
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
local function getDistance(vec1, vec2)
    if not vec1 or not vec2 then return 0 end
    local dx, dy, dz = vec1.x - vec2.x, vec1.y - vec2.y, vec1.z - vec2.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end
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
local function GetVehiclePlate(vehicle)
    return DoesEntityExist(vehicle) and GetVehicleNumberPlateText(vehicle) or "UNKNOWN"
end
local function convertDistance(meters)
    return Config.Unit == "mile" and meters * 0.000621371 or meters / 1000
end
local function updateSparkPlugWear(vehicle)
    if not Config.WearTracking.SparkPlugs then return end
    if not DoesEntityExist(vehicle) then return end

    local distanceSinceSparkPlugChange = accDistance - lastSparkPlugChange
    local wearRatio = distanceSinceSparkPlugChange / (Config.SparkPlugChangeDistance * 1000)
    if wearRatio > 1 then wearRatio = 1 end

    sparkPlugWear = wearRatio

    TriggerServerEvent('wizard_vehiclemileage:server:updateSparkPlugWear', currentPlate, sparkPlugWear)

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
local function updateEngineDamage(vehicle)
    if not Config.WearTracking.Oil then return end
    if not DoesEntityExist(vehicle) then return end
    
    local oilDistanceDriven = accDistance - lastOilChange
    local oilWearRatio = oilDistanceDriven / oilchangedist
    
    local filterDistanceDriven = accDistance - lastOilFilterChange
    local filterWearRatio = filterDistanceDriven / oilfilterchangedist
    
    if oilWearRatio > 1.0 or filterWearRatio > 1.0 then
        local engineHealth = GetVehicleEngineHealth(vehicle)
        local damage = (math.max(oilWearRatio, filterWearRatio) - 1.0) * Config.EngineDamageRate
        
        local oilDrainRate = damage * 0.1
        lastOilChange = lastOilChange - (oilDrainRate * oilchangedist)
        
        if engineHealth < 400.0 then
            lastOilChange = 0.0
        end
        
        SetVehicleEngineHealth(vehicle, math.max(0.0, engineHealth - damage))
        
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
local function updateAirFilterPerformance(vehicle)
    if not Config.WearTracking.AirFilter then return end
    if not DoesEntityExist(vehicle) then return end
    
    local airFilterDistanceDriven = accDistance - lastAirFilterChange
    local airFilterWearRatio = math.min(1.0, airFilterDistanceDriven / airfilterchangedist)
    
    local plate = GetVehiclePlate(vehicle)
    TriggerServerEvent('wizard_vehiclemileage:server:getOriginalDriveForce', plate)
    
    local currentAcceleration = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce")
    originalDriveForce = originalDriveForce or currentAcceleration
    TriggerServerEvent('wizard_vehiclemileage:server:saveOriginalDriveForce', plate, originalDriveForce)
    local reducedAcceleration = originalDriveForce * (1.0 - (Config.AccelerationReduction * airFilterWearRatio))
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce", reducedAcceleration)
end
local function updateTireWear(vehicle)
    if not Config.WearTracking.Tires then return end
    if not DoesEntityExist(vehicle) then return end
    local distanceSinceTireChange = accDistance - lastTireChange
    local wearRatio = distanceSinceTireChange / tirechangedist
    if wearRatio > 1 then 
        wearRatio = 1 
    end
    local newGrip = Config.BaseTireGrip - ((Config.BaseTireGrip - Config.MinTireGrip) * wearRatio)
    
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax", newGrip)
end
local function updateBrakeWear(vehicle)
    if not Config.WearTracking.Brakes then return end
    if not DoesEntityExist(vehicle) then return end
    
    local currentBrakeForce = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce")
    
    local efficiency = 1.0 - (math.min(lastbrakeWear, Config.MaxBrakeWear) / Config.MaxBrakeWear * Config.BrakeEfficiencyLoss)
    local baseBrakeForce = Config.BaseBrakeForce
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce", baseBrakeForce * efficiency)
end
local function updateSuspensionWear(vehicle)
    if not Config.WearTracking.Suspension then return end
    if not DoesEntityExist(vehicle) then return end

    local distanceSinceSuspensionChange = accDistance - lastSuspensionChange
    local wearRatio = distanceSinceSuspensionChange / (Config.SuspensionChangeDistance * 1000)
    if wearRatio > 1 then wearRatio = 1 end
    
    local plate = GetVehiclePlate(vehicle)
    TriggerServerEvent('wizard_vehiclemileage:server:getOriginalSuspensionValue', plate)

    suspensionWear = wearRatio

    TriggerServerEvent('wizard_vehiclemileage:server:updateSuspensionWear', currentPlate, suspensionWear)

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

    local newForce = originalForce * (1.0 - suspensionWear)
    local newRaise = originalRaise * (1.0 - suspensionWear)

    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionForce", newForce)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionRaise", newRaise)
end
local function updateClutchWear(vehicle)
    if not DoesEntityExist(vehicle) then return end
    
    local efficiency = 1.0 - (math.min(lastClutchWear, Config.MaxClutchWear) / Config.MaxClutchWear * Config.ClutchEfficiencyLoss)
    
    if efficiency <= 0.2 then
        Citizen.InvokeNative(GetHashKey('SET_VEHICLE_CLUTCH') & 0xFFFFFFFF, vehicle, -1.0)
        if math.random() < Config.StallChance then
            SetVehicleEngineOn(vehicle, false, true, true)
            Notify(locale('warning.stalled'), 'warning')
        end
    else
        local baseClutchForce = Config.BaseClutchForce
    end
end
local function openServiceMenu()
    if Config.Menu == "ox" then
        lib.showContext("vehicle_service_menu")
    elseif Config.Menu == "qb" then
        exports["qb-menu"]:openMenu({
            {
                header = "Wizard Mileage Service Menu",
                isMenuHeader = true,
            },
            
            {
                header = locale("target.changeoilfilter"),
                txt = "Change oil filter",
                params = {
                    event = "wizard_vehiclemileage:client:changeoilfilter"
                }
            },
            {
                header = locale("target.changeairfilter"),
                txt = "Change air filter",
                params = {
                    event = "wizard_vehiclemileage:client:changeairfilter"
                }
            },
            {
                header = locale("target.changetires"),
                txt = "Change vehicle tires",
                params = {
                    event = "wizard_vehiclemileage:client:changetires"
                }
            },
            {
                header = locale("target.changebrakes"),
                txt = "Service vehicle brakes",
                params = {
                    event = "wizard_vehiclemileage:client:changebrakes"
                }
            },
            {
                header = locale("target.changeclutch"),
                txt = "Replace vehicle clutch",
                params = {
                    event = "wizard_vehiclemileage:client:changeclutch"
                }
            },
            {
                header = locale("target.changesuspension"),
                txt = "Replace vehicle suspension",
                params = {
                    event = "wizard_vehiclemileage:client:changesuspension"
                }
            },
            {
                header = locale("target.changesparkplug"),
                txt = "Replace spark plugs",
                params = {
                    event = "wizard_vehiclemileage:client:changesparkplug"
                }
            },
        })
    end
end
local function sendCachedWearData()
    if inVehicle and currentPlate then
        if clutchWearDirty then
            TriggerServerEvent('wizard_vehiclemileage:server:updateClutchWear', currentPlate, cachedClutchWear)
            clutchWearDirty = false
        end
        if brakeWearDirty then
            TriggerServerEvent('wizard_vehiclemileage:server:updateBrakeWear', currentPlate, cachedBrakeWear)
            brakeWearDirty = false
        end
    end
end


---------------- Threads ----------------
    -- Main thread
Citizen.CreateThread(function()
    SendNUIMessage({
        type = "Configuration",
        maxMil = Config.MaxMileageDisplay,
        language = Config.Language
    })
    local waitTime = 2000 
    while true do
        Citizen.Wait(waitTime)
        local ped = PlayerPedId()
        local isInVehicle = IsPedInAnyVehicle(ped, false)
        if isInVehicle then
            local veh = GetVehiclePedIsIn(ped, false)
            local vehicleClass = GetVehicleClass(veh)
            if Config.DisabledVehicleClasses[vehicleClass] then
                SendNUIMessage({
                    type = "toggleMileage",
                    visible = false
                })
            else
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
                    waitTime = 1500
                else
                    if not waitingForData then
                        local currentPos = GetEntityCoords(veh)
                        local delta = getDistance(lastPos, currentPos)
                        accDistance = accDistance + delta
                        lastPos = currentPos
                        local displayedMileage = convertDistance(accDistance)
                
                        SendNUIMessage({
                            type = "updateMileage",
                            mileage = displayedMileage,
                            unit = (Config.Unit == "mile" and "miles" or "km")
                        })
                
                        updateSparkPlugWear(veh)
                        updateEngineDamage(veh)
                        updateAirFilterPerformance(veh)
                        updateSuspensionWear(veh)
                        updateTireWear(veh)
                    end
                end
            end
        else
            if inVehicle then
                if currentPlate and IsVehicleOwned(currentPlate) then
                    local savedPlate = currentPlate
                    local savedDistance = accDistance
                    
                    sendCachedWearData()
                    TriggerServerEvent('wizard_vehiclemileage:server:updateMileage', savedPlate, savedDistance)
                    Wait(100)
                end
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
                SendNUIMessage({
                    type = "toggleMileage",
                    visible = false
                })
                waitTime = 2000
            end
        end
    end
end)
    -- Clutch wear tracking
Citizen.CreateThread(function()
    if not Config.WearTracking.Clutch then return end
    local prevGear = 0
    local lastShiftTime = 0
    local shiftCooldown = 500
    while true do
        Citizen.Wait(1000)
        if inVehicle and currentPlate and allowSmartGearDetect then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if DoesEntityExist(veh) then
                if IsVehicleOwned(currentPlate) then
                    local currentGear = GetVehicleCurrentGear(veh)
                    local currentTime = GetGameTimer()
                    if (currentGear ~= prevGear) and ((currentTime - lastShiftTime) > shiftCooldown) then
                        local gearDiff = math.abs(currentGear - prevGear)
                        local wearIncrement = Config.ClutchWearRate * gearDiff
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
    -- Brake wear tracking
Citizen.CreateThread(function()
    if not Config.WearTracking.Brakes then return end
    while true do
        Citizen.Wait(1000)
        if inVehicle and currentPlate then
            if IsVehicleOwned(currentPlate) then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if DoesEntityExist(veh) and IsControlPressed(0, 72) then
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
    -- Targettings script handler
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
                            local Job = ChkJb()
                            local Grade = ChkGr()
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
                            local Job = ChkJb()
                            local Grade = ChkGr()
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
    -- Update CheckWear UI
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
    -- Admin checking
RegisterNetEvent('wizard_vehiclemileage:client:requestAdminCheck')
AddEventHandler('wizard_vehiclemileage:client:requestAdminCheck', function(cbId)
    -- For standalone, check ACE permission 'admin' locally
    local isAdmin = IsPlayerAceAllowed(PlayerId(), "admin")
    TriggerServerEvent('wizard_vehiclemileage:server:isAdmin', cbId)
    -- Also trigger local callback immediately
    TriggerEvent('wizard_vehiclemileage:client:isAdminCallback', cbId, isAdmin)
end)
RegisterNetEvent('wizard_vehiclemileage:client:isAdminCallback')
AddEventHandler('wizard_vehiclemileage:client:isAdminCallback', function(cbId, isAdmin)
    if adminCallbacks[cbId] then
        adminCallbacks[cbId](isAdmin)
        adminCallbacks[cbId] = nil
    end
end)

    -- Change spark plugs
RegisterNetEvent('wizard_vehiclemileage:client:changesparkplug')
AddEventHandler('wizard_vehiclemileage:client:changesparkplug', function()
    if Config.JobRequired then
        local Job = ChkJb()
        local Grade = ChkGr()
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
    -- Change oil
RegisterNetEvent('wizard_vehiclemileage:client:changeoil')
AddEventHandler('wizard_vehiclemileage:client:changeoil', function()
    if Config.JobRequired then
        local Job = ChkJb()
        local Grade = ChkGr()
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
    -- Change oil filter
RegisterNetEvent('wizard_vehiclemileage:client:changeoilfilter')
AddEventHandler('wizard_vehiclemileage:client:changeoilfilter', function()
    if Config.InventoryItems and not checkInventoryItem(Config.Items.OilFilter) then
        Notify(locale("error.no_oil_filter"), "error")
        return
    end
    if Config.JobRequired then
        local Job = ChkJb()
        local Grade = ChkGr()
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
    -- Change air filter
RegisterNetEvent('wizard_vehiclemileage:client:changeairfilter')
AddEventHandler('wizard_vehiclemileage:client:changeairfilter', function()
    if Config.JobRequired then
        local Job = ChkJb()
        local Grade = ChkGr()
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
    -- Change tires
RegisterNetEvent('wizard_vehiclemileage:client:changetires')
AddEventHandler('wizard_vehiclemileage:client:changetires', function()
    if Config.JobRequired then
        local Job = ChkJb()
        local Grade = ChkGr()
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
    -- Change brakes
RegisterNetEvent('wizard_vehiclemileage:client:changebrakes')
AddEventHandler('wizard_vehiclemileage:client:changebrakes', function()
    if Config.JobRequired then
        local Job = ChkJb()
        local Grade = ChkGr()
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
    -- Change suspension
RegisterNetEvent('wizard_vehiclemileage:client:changesuspension')
AddEventHandler('wizard_vehiclemileage:client:changesuspension', function()
    if Config.JobRequired then
        local Job = ChkJb()
        local Grade = ChkGr()
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
    -- Change clutch
RegisterNetEvent('wizard_vehiclemileage:client:changeclutch')
AddEventHandler('wizard_vehiclemileage:client:changeclutch', function()
    if Config.JobRequired then
        local Job = ChkJb()
        local Grade = ChkGr()
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
    -- Get mileage data from database
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
    -- Get vehicle list from database
RegisterNetEvent('wizard_vehiclemileage:client:vehicleDataUpdated')
AddEventHandler('wizard_vehiclemileage:client:vehicleDataUpdated', function()
    TriggerVehicleListCallback(function(vehicles)
        SendNUIMessage({
            type = 'vehicleList',
            vehicles = vehicles
        })
    end)
end)
RegisterNetEvent('wizard_vehiclemileage:client:getAllVehiclesCallback')
AddEventHandler('wizard_vehiclemileage:client:getAllVehiclesCallback', function(cbId, vehicles)
    if vehicleListCallbacks[cbId] then
        vehicleListCallbacks[cbId](vehicles)
        vehicleListCallbacks[cbId] = nil
    end
end)

    -- Get player settings from database
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

    -- Set the original handeling data
RegisterNetEvent('wizard_vehiclemileage:client:setOriginalDriveForce')
AddEventHandler('wizard_vehiclemileage:client:setOriginalDriveForce', function(driveForce)
    originalDriveForce = driveForce
end)
RegisterNetEvent('wizard_vehiclemileage:client:setOriginalSusRaise')
AddEventHandler('wizard_vehiclemileage:client:setOriginalSusRaise', function(susRaise)
    originalSuspensionRaise = susRaise
end)
RegisterNetEvent('wizard_vehiclemileage:client:setOriginalSusForce')
AddEventHandler('wizard_vehiclemileage:client:setOriginalSusForce', function(susForce)
    originalSuspensionForce = susForce
end)

    -- FOR 'wizard_manualtransmission' SCRIPT
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
RegisterNetEvent('wizard_vehiclemileage:client:smartGearDetect')
AddEventHandler('wizard_vehiclemileage:client:smartGearDetect', function(data)
    allowSmartGearDetect = data
end)

    -- Script data synchronize
AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        TriggerServerEvent('wizard_vehiclemileage:server:loadPlayerSettings')
    end
end)
AddEventHandler('playerSpawned', function()
    TriggerServerEvent('wizard_vehiclemileage:server:loadPlayerSettings')
end)

---------------- Autosave system ----------------
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
    -- UI Notifications
RegisterNUICallback('notify', function(data, cb)
    if data and data.message and data.type then
        Notify(data.message, data.type)
        cb({success = true})
    else
        cb({success = false, error = 'Invalid data'})
    end
end)
    -- Request vehicles
RegisterNUICallback('requestVehicleList', function(data, cb)
    TriggerVehicleListCallback(function(vehicles)
        SendNUIMessage({
            type = 'vehicleList',
            vehicles = vehicles
        })
    end)
end) 
    -- Update vehicle data
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
    -- Delete vehicle data
RegisterNUICallback('deleteVehicle', function(data, cb)
    if data and data.plate then
        TriggerServerEvent('wizard_vehiclemileage:server:deleteVehicle', data.plate)
        cb({success = true})
    else
        cb({success = false, error = 'Invalid plate'})
    end
end)
    -- Save player settings
RegisterNUICallback('savePlayerSettings', function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('wizard_vehiclemileage:server:savePlayerSettings', data)
    SendNUIMessage({
        type = "closeCustomization"
    })
    cb({})
end)
    -- Close UI
RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    cb({})
end)


---------------- Commands ----------------
    -- Mileage UI Customization
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
    -- Check parts wear
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
    -- Database management
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
    -- Get vehicle mileage
exports('GetVehicleMileage', function()
    return accDistance
end)
    -- Set vehicle mileage
exports('SetVehicleMileage', function(mileage)
    accDistance = mileage or accDistance
end)
    -- Get vehicle last parts change
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
    -- Set vehicle last parts change
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
    -- Get vehicle parts wear
exports('GetVehiclePartsWear', function()
    return {
        brakeWear = lastbrakeWear,
        clutchWear = lastClutchWear,
        suspensionWear = suspensionWear,
        sparkPlugWear = sparkPlugWear
    }
end)
    -- Set vehicle parts wear
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
