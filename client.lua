local mileageVisible = false
local inVehicle = false
local lastPos = nil
local accDistance = 0.0
local currentPlate = nil
local waitingForData = false
local lastOilChange = 0.0
local lastOilFilterChange = 0.0
local lastAirFilterChange = 0.0
local lastTireChange = 0.0
local lastbrakeChange = 0.0
local lastbrakeWear = 0.0
local lastClutchChange = 0.0
local lastClutchWear = 0.0
local GetEntityCoords = GetEntityCoords
local PlayerPedId = PlayerPedId
local IsPedInAnyVehicle = IsPedInAnyVehicle
local GetVehiclePedIsIn = GetVehiclePedIsIn
local DoesEntityExist = DoesEntityExist
local lastEngineCriticalNotify = 0
local oilchangedist, oilfilterchangedist, airfilterchangedist, tirechangedist = nil, nil, nil, nil

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

if Config.Unit == "km" then
    oilchangedist = Config.OilChangeDistance * 1000
    oilfilterchangedist = Config.OilFilterDistance * 1000
    airfilterchangedist = Config.AirFilterDistance * 1000
    tirechangedist = Config.TireWearDistance * 1000
elseif Config.Unit == "mile" then
    oilchangedist = Config.OilChangeDistance * 1609.34
    oilfilterchangedist = Config.OilFilterDistance * 1609.34
    airfilterchangedist = Config.AirFilterDistance * 1609.34
    tirechangedist = Config.TireWearDistance * 1609.34
end
if Config.BoughtVehiclesOnly then
    function IsVehicleOwned(plate)
        local p = promise.new()
        TriggerServerEvent('vehicleMileage:checkOwnership', plate)
        RegisterNetEvent('vehicleMileage:ownershipResult')
        AddEventHandler('vehicleMileage:ownershipResult', function(owned)
            p:resolve(owned)
        end)
        return Citizen.Await(p)
    end
else
    function IsVehicleOwned()
        local p = promise.new()
        p:resolve(true)
        return Citizen.Await(p)
    end
end

local function checkInventoryItem(item)
    if not Config.InventoryItems then return true end
    
    local hasItem = false
    if Config.InventoryScript == 'ox' then
        -- Check for specific maintenance items
        if item == 'engine_oil' then
            hasItem = exports.ox_inventory:Search('count', 'engine_oil') > 0
        elseif item == 'oil_filter' then
            hasItem = exports.ox_inventory:Search('count', 'oil_filter') > 0
        elseif item == 'air_filter' then
            hasItem = exports.ox_inventory:Search('count', 'air_filter') > 0
        elseif item == 'tires' then
            hasItem = exports.ox_inventory:Search('count', 'tires') > 0
        elseif item == 'brake_parts' then
            hasItem = exports.ox_inventory:Search('count', 'brake_parts') > 0
        elseif item == 'clutch' then
            hasItem = exports.ox_inventory:Search('count', 'clutch') > 0
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
local function updateEngineDamage(vehicle)
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
    if not DoesEntityExist(vehicle) then return end
    
    local airFilterDistanceDriven = accDistance - lastAirFilterChange
    local airFilterWearRatio = math.min(1.0, airFilterDistanceDriven / airfilterchangedist)
    
    local currentTopSpeed = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel")
    local currentAcceleration = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce")
    
    local reducedTopSpeed = currentTopSpeed * (1.0 - (Config.MaxSpeedReduction * airFilterWearRatio))
    local reducedAcceleration = currentAcceleration * (1.0 - (Config.AccelerationReduction * airFilterWearRatio))
    
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel", reducedTopSpeed)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce", reducedAcceleration)
end
local function updateTireWear(vehicle)
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
    if not DoesEntityExist(vehicle) then return end
    
    local currentBrakeForce = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce")
    
    local efficiency = 1.0 - (math.min(lastbrakeWear, Config.MaxBrakeWear) / Config.MaxBrakeWear * Config.BrakeEfficiencyLoss)
    local baseBrakeForce = Config.BaseBrakeForce
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce", baseBrakeForce * efficiency)
end
local function updateClutchWear(vehicle)
    if not DoesEntityExist(vehicle) then return end
    
    local efficiency = 1.0 - (math.min(lastClutchWear, Config.MaxClutchWear) / Config.MaxClutchWear * Config.ClutchEfficiencyLoss)
    
    -- When clutch is completely worn out
    if efficiency <= 0.2 then
        -- Reduce power transfer significantly and affect acceleration
        local currentForce = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce")
        local reducedForce = currentForce * 0.1 -- Only 10% power transfer when clutch is worn
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce", reducedForce)
        
        -- Add random stalling effect when clutch is worn out
        if math.random() < Config.StallChance then -- chance to stall
            SetVehicleEngineOn(vehicle, false, true, true)
            Notify(locale('warning.stalled'), 'warning')
        end
    else
        -- Normal operation with reduced power based on wear
        local baseClutchForce = Config.BaseClutchForce
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce", baseClutchForce * efficiency)
    end
end

Citizen.CreateThread(function()
    SendNUIMessage({
        type = "Configuration",
        location = Config.M_Location
    })
    while true do
        Citizen.Wait(1500)
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
                    -- Player just entered a vehicle
                    inVehicle = true
                    lastPos = GetEntityCoords(veh)
                    currentPlate = GetVehiclePlate(veh)
                    if IsVehicleOwned(currentPlate) then
                        waitingForData = true
                        accDistance = 0.0
                        TriggerServerEvent('vehicleMileage:retrieveMileage', currentPlate)
                        SendNUIMessage({
                            type = "toggleMileage",
                            visible = true
                        })
                        mileageVisible = true
                    else
                        SendNUIMessage({
                            type = "toggleMileage",
                            visible = false
                        })
                    end
                else
                    -- Player continues in the vehicle
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
                
                        updateEngineDamage(veh)
                        updateAirFilterPerformance(veh)
                        updateTireWear(veh)
                    end
                end
            end
        else
            if inVehicle then
                if currentPlate and IsVehicleOwned(currentPlate) then
                    TriggerServerEvent('vehicleMileage:updateMileage', currentPlate, accDistance)
                end
                inVehicle = false
                lastPos = nil
                accDistance = 0.0
                currentPlate = nil
                waitingForData = false
                SendNUIMessage({
                    type = "toggleMileage",
                    visible = false
                })
            end
        end
    end
end)
Citizen.CreateThread(function()
    local prevGear = 0
    local lastShiftTime = 0
    local shiftCooldown = 500 -- 500ms cooldown between gear changes
    while true do
        Citizen.Wait(100) -- Gear detection interval
        if inVehicle and currentPlate then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if DoesEntityExist(veh) then
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
                    TriggerServerEvent('vehicleMileage:updateClutchWear', currentPlate, lastClutchWear)
                    updateClutchWear(veh)
                    lastShiftTime = currentTime
                    prevGear = currentGear
                end
            end
        end
    end
end)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Brake monitoring interval
        if inVehicle and currentPlate then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if DoesEntityExist(veh) and IsControlPressed(0, 72) then
                local speed = GetEntitySpeed(veh)
                local gear = GetVehicleCurrentGear(veh)
                if speed > 0 and gear > 0 then
                    lastbrakeWear = lastbrakeWear + Config.BrakeWearRate
                    TriggerServerEvent('vehicleMileage:updateBrakeWear', currentPlate, lastbrakeWear)
                    updateBrakeWear(veh)
                end
            end
        end
    end
end)

RegisterNetEvent('vehicleMileage:changeoil')
AddEventHandler('vehicleMileage:changeoil', function()
    if Config.JobRequired then
        local QBCore = exports['qb-core']:GetCoreObject()
        local Player = QBCore.Functions.GetPlayerData()
        local Job = Player.job.name
        local Grade = Player.job.grade.level
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
        
    local animDict = Config.ChangeOilFilter.AnimationDict
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end
        
    local offset = GetOffsetFromEntityInWorldCoords(closestVehicle, 0.0, 2.0, 0.0)
    TaskGoStraightToCoord(playerPed, offset.x, offset.y, offset.z, 1.0, -1, -1, 0.0)
    Wait(1000)
        
    TaskPlayAnim(playerPed, animDict, Config.ChangeOilFilter.Animation, 8.0, -8.0, -1, 1, 0, false, false, false)
    if lib.progressBar({
        duration = Config.ChangeOil.Duration,
        label = locale("progress.changingoil"),
        useWhileDead = false,
        canCancel = Config.ChangeOil.Cancelable,
        disable = {
            car = Config.ChangeOil.FreezeCar,
            move = Config.ChangeOil.FreezePlayer
        }
        }) then
            
        TriggerServerEvent('vehicleMileage:removeItem', 'engine_oil', 1)

        local plate = GetVehicleNumberPlateText(closestVehicle)
        Notify(locale("info.oil_changed"), "success")
        TriggerServerEvent("vehicleMileage:updateOilChange", plate)
        SetVehicleDoorShut(closestVehicle, 4, false)
    else
        SetVehicleDoorShut(closestVehicle, 4, false)
    end
    ClearPedTasks(playerPed)
end)

RegisterNetEvent('vehicleMileage:changeoilfilter')
AddEventHandler('vehicleMileage:changeoilfilter', function()
    if Config.JobRequired then
        local QBCore = exports['qb-core']:GetCoreObject()
        local Player = QBCore.Functions.GetPlayerData()
        local Job = Player.job.name
        local Grade = Player.job.grade.level
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
    if lib.progressBar({
        duration = Config.ChangeOilFilter.Duration,
        label = locale("progress.changingoilfilter"),
        useWhileDead = false,
        canCancel = Config.ChangeOilFilter.Cancelable,
        disable = {
            car = Config.ChangeOilFilter.FreezeCar,
            move = Config.ChangeOilFilter.FreezePlayer
        }
    }) then

        TriggerServerEvent('vehicleMileage:removeItem', 'oil_filter', 1)

        local plate = GetVehicleNumberPlateText(closestVehicle)
        Notify(locale("info.filter_changed"), "success")
        TriggerServerEvent("vehicleMileage:updateOilFilter", plate)
        SetVehicleDoorShut(closestVehicle, 4, false)
    else
        SetVehicleDoorShut(closestVehicle, 4, false)
    end
    ClearPedTasks(playerPed)
end)

RegisterNetEvent('vehicleMileage:changeairfilter')
AddEventHandler('vehicleMileage:changeairfilter', function()
    if Config.JobRequired then
        local QBCore = exports['qb-core']:GetCoreObject()
        local Player = QBCore.Functions.GetPlayerData()
        local Job = Player.job.name
        local Grade = Player.job.grade.level
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
        local animDict = Config.ChangeAirFilter.AnimationDict
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(10)
        end
        local offset = GetOffsetFromEntityInWorldCoords(closestVehicle, 0.0, 2.0, 0.0)
        TaskGoStraightToCoord(playerPed, offset.x, offset.y, offset.z, 1.0, -1, -1, 0.0)
        Wait(1000)
        TaskPlayAnim(playerPed, animDict, Config.ChangeAirFilter.Animation, 8.0, -8.0, -1, 1, 0, false, false, false)
        if lib.progressBar({
            duration = Config.ChangeAirFilter.Duration,
            label = locale("progress.changingairfilter"),
            useWhileDead = false,
            canCancel = Config.ChangeAirFilter.Cancelable,
            disable = {
                car = Config.ChangeAirFilter.FreezeCar,
                move = Config.ChangeAirFilter.FreezePlayer
            }
        }) then

            TriggerServerEvent('vehicleMileage:removeItem', 'air_filter', 1)
            
            local plate = GetVehicleNumberPlateText(closestVehicle)
            Notify(locale("info.air_filter_changed"), "success")
            TriggerServerEvent("vehicleMileage:updateAirFilter", plate)
            SetVehicleHandlingFloat(closestVehicle, "CHandlingData", "fInitialDriveMaxFlatVel", Config.BaseTopSpeed)
            SetVehicleHandlingFloat(closestVehicle, "CHandlingData", "fInitialDriveForce", Config.BaseAcceleration)
            SetVehicleDoorShut(closestVehicle, 4, false)
        else
            SetVehicleDoorShut(closestVehicle, 4, false)
        end
        ClearPedTasks(playerPed)
end)

RegisterNetEvent('vehicleMileage:changetires')
AddEventHandler('vehicleMileage:changetires', function()
    if Config.JobRequired then
        local QBCore = exports['qb-core']:GetCoreObject()
        local Player = QBCore.Functions.GetPlayerData()
        local Job = Player.job.name
        local Grade = Player.job.grade.level
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
        local animDict = Config.ChangeTires.AnimationDict
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(10)
        end
        TaskPlayAnim(playerPed, animDict, Config.ChangeTires.Animation, 8.0, -8.0, -1, 1, 0, false, false, false)
        if lib.progressBar({
            duration = Config.ChangeTires.Duration,
            label = locale("progress.changingtires"),
            useWhileDead = false,
            canCancel = Config.ChangeTires.Cancelable,
            disable = {
                car = Config.ChangeTires.FreezeCar,
                move = Config.ChangeTires.FreezePlayer
            }
        }) then

            TriggerServerEvent('vehicleMileage:removeItem', 'tires', 1)
            
            local plate = GetVehicleNumberPlateText(closestVehicle)
            lastTireChange = accDistance
            for i = 0, 5 do
                SetVehicleTyreFixed(closestVehicle, i)
            end
            Notify(locale("info.tire_changed"), "success")
            TriggerServerEvent("vehicleMileage:updateTireChange", plate)
            SetVehicleHandlingFloat(closestVehicle, "CHandlingData", "fTractionCurveMax", Config.BaseTireGrip)
        end
        ClearPedTasks(playerPed)
end)

RegisterNetEvent('vehicleMileage:changebrakes')
AddEventHandler('vehicleMileage:changebrakes', function()
    if Config.JobRequired then
        local QBCore = exports['qb-core']:GetCoreObject()
        local Player = QBCore.Functions.GetPlayerData()
        local Job = Player.job.name
        local Grade = Player.job.grade.level
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
        local animDict = Config.ChangeBrakes.AnimationDict
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(10)
        end
        TaskPlayAnim(playerPed, animDict, Config.ChangeBrakes.Animation, 8.0, -8.0, -1, 1, 0, false, false, false)
        if lib.progressBar({
            duration = Config.ChangeBrakes.Duration,
            label = locale("progress.changingbrakes"),
            useWhileDead = false,
            canCancel = Config.ChangeBrakes.Cancelable,
            disable = {
                car = Config.ChangeBrakes.FreezeCar,
                move = Config.ChangeBrakes.FreezePlayer
            }
        }) then

            TriggerServerEvent('vehicleMileage:removeItem', 'brake_parts', 1)
            
            local plate = GetVehicleNumberPlateText(closestVehicle)
            Notify(locale("info.brakes_changed"), "success")
            TriggerServerEvent("vehicleMileage:updateBrakeChange", plate)
            lastbrakeWear = 0.0
            updateBrakeWear(closestVehicle)
        end
        ClearPedTasks(playerPed)
end)

RegisterNetEvent('vehicleMileage:changeclutch')
AddEventHandler('vehicleMileage:changeclutch', function()
    if Config.JobRequired then
        local QBCore = exports['qb-core']:GetCoreObject()
        local Player = QBCore.Functions.GetPlayerData()
        local Job = Player.job.name
        local Grade = Player.job.grade.level
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
        local animDict = Config.ChangeClutch.AnimationDict
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(10)
        end
        TaskPlayAnim(playerPed, animDict, Config.ChangeClutch.Animation, 8.0, -8.0, -1, 1, 0, false, false, false)
        if lib.progressBar({
            duration = Config.ChangeClutch.Duration,
            label = locale("progress.changingclutch"),
            useWhileDead = false,
            canCancel = Config.ChangeClutch.Cancelable,
            disable = {
                car = Config.ChangeClutch.FreezeCar,
                move = Config.ChangeClutch.FreezePlayer
            }
        }) then

            TriggerServerEvent('vehicleMileage:removeItem', 'clutch', 1)
            
            local plate = GetVehicleNumberPlateText(closestVehicle)
            Notify(locale("info.clutch_changed"), "success")
            TriggerServerEvent("vehicleMileage:updateClutchChange", plate)
            TriggerServerEvent("vehicleMileage:updateClutchWear", plate, 0)
            lastClutchWear = 0
            updateClutchWear(closestVehicle)
        end
        ClearPedTasks(playerPed)
end)

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
                        lib.showContext("vehicle_service_menu")
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
                            lib.showContext("vehicle_service_menu")
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
    lib.registerContext({
        id = "vehicle_service_menu",
        title = "Vehicle Service Menu",
        options = {
            {
                title = locale("target.changeoil"),
                description = "Change vehicle oil",
                icon = "oil-can",
                onSelect = function()
                    if Config.InventoryItems and not checkInventoryItem('engine_oil') then
                        Notify(locale("error.no_oil"), "error")
                    return
                    end
                    TriggerEvent('vehicleMileage:changeoil')
                end
            },
            {
                title = locale("target.changeoilfilter"),
                description = "Change oil filter",
                icon = "filter",
                onSelect = function()
                    if Config.InventoryItems and not checkInventoryItem('oil_filter') then
                        Notify(locale("error.no_oil_filter"), "error")
                        return
                    end
                    TriggerEvent('vehicleMileage:changeoilfilter')
                end
            },
            {
                title = locale("target.changeairfilter"),
                description = "Change air filter",
                icon = "wind",
                onSelect = function()
                    if Config.InventoryItems and not checkInventoryItem('air_filter') then
                        Notify(locale("error.no_air_filter"), "error")
                        return
                    end
                    TriggerEvent('vehicleMileage:changeairfilter')
                end
            },
            {
                title = locale("target.changetires"),
                description = "Change vehicle tires",
                icon = "fa-regular fa-circle",
                onSelect = function()
                    if Config.InventoryItems and not checkInventoryItem('tires') then
                        Notify(locale("error.no_tires"), "error")
                        return
                    end
                    TriggerEvent('vehicleMileage:changetires')
                end
            },
            {
                title = locale("target.changebrakes"),
                description = "Service vehicle brakes",
                icon = "fas fa-compact-disc",
                onSelect = function()
                    if Config.InventoryItems and not checkInventoryItem('brake_parts') then
                        Notify(locale("error.no_brake_parts"), "error")
                        return
                    end
                    TriggerEvent('vehicleMileage:changebrakes')
                end
            },
            {
                title = locale("target.changeclutch"),
                description = "Replace vehicle clutch",
                icon = "fas fa-cog",
                onSelect = function()
                    if Config.InventoryItems and not checkInventoryItem('clutch') then
                        Notify(locale("error.no_clutch"), "error")
                        return
                    end
                end
            }
        }
    })
end)

RegisterNetEvent('vehicleMileage:setData')
AddEventHandler('vehicleMileage:setData', function(mileage, oilChange, filterChange, AirfilterChange, tireChange, brakeChange, brakeWear, clutchChange, clutchWear)
    accDistance = mileage or 0.0
    lastOilChange = oilChange or 0.0
    lastOilFilterChange = filterChange or 0.0
    lastAirFilterChange = AirfilterChange or 0.0
    lastTireChange = tireChange or 0.0
    lastbrakeChange = brakeChange or 0.0
    lastbrakeWear = brakeWear or 0.0
    lastClutchChange = clutchChange or 0.0
    lastClutchWear = clutchWear or 0.0
    waitingForData = false
    local displayedMileage = convertDistance(accDistance)
    SendNUIMessage({
        type = "updateMileage",
        mileage = displayedMileage,
        unit = (Config.Unit == "mile" and "miles" or "km")
    })
end)
RegisterNetEvent('vehicleMileage:Notify')
AddEventHandler('vehicleMileage:Notify', function(message, type)
    Notify(message, type)
end)

if Config.Autosave then
    local autosaveinvl = Config.AutosaveInterval * 1000
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(autosaveinvl)
            if inVehicle and currentPlate and IsVehicleOwned(currentPlate) and not waitingForData then
                TriggerServerEvent('vehicleMileage:updateMileage', currentPlate, accDistance)
            end
        end
    end)
end
if Config.ChangeWarnings then
    -- Data definitions for each component with its details.
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
        }
    }
    -- Separate easy computed percentages for brakes and clutch
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
    -- Helper function to check one component
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
        -- Check dynamic components: oil, filter, airFilter, tire.
        for key, data in pairs(components) do
            local distDriven = data.computeDistance()
            local lifeRemaining = math.max(0, data.changedist - distDriven)
            local percentage = math.floor((lifeRemaining / data.changedist) * 100)
            checkComponent(data, percentage)
        end
        -- Check static components: brakes and clutch.
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
if IsControlPressed(0, 72) then
    local brakeWear = brakeWear + Config.BrakeWearRate
    TriggerServerEvent('vehicleMileage:updateBrakeWear', currentPlate, brakeWear)
    updateBrakeWear(vehicle)
end

RegisterCommand(Config.CheckWearCommand, function()
    if inVehicle and currentPlate then
        if not IsVehicleOwned(currentPlate) then Notify(locale('error.not_owned'), 'error') return end
        
        local oilDistanceDriven = accDistance - lastOilChange
        local oilLifeRemaining = math.max(0, oilchangedist - oilDistanceDriven)
        local oilPercentage = math.floor((oilLifeRemaining / oilchangedist) * 100)
        
        local filterDistanceDriven = accDistance - lastOilFilterChange
        local filterLifeRemaining = math.max(0, oilfilterchangedist - filterDistanceDriven)
        local filterPercentage = math.floor((filterLifeRemaining / oilfilterchangedist) * 100)
        
        local airFilterDistanceDriven = accDistance - lastAirFilterChange
        local airFilterLifeRemaining = math.max(0, airfilterchangedist - airFilterDistanceDriven)
        local airFilterPercentage = math.floor((airFilterLifeRemaining / airfilterchangedist) * 100)
        
        local tireDistanceDriven = accDistance - lastTireChange
        local tireLifeRemaining = math.max(0, tirechangedist - tireDistanceDriven)
        local tirePercentage = math.floor((tireLifeRemaining / tirechangedist) * 100)
        
        local brakePercentage = math.floor((1 - (lastbrakeWear / Config.MaxBrakeWear)) * 100)

        local clutchPercentage = math.floor((1 - (lastClutchWear / Config.MaxClutchWear)) * 100)
        
        SendNUIMessage({
            type = "updateWear",
            oilPercentage = oilPercentage,
            filterPercentage = filterPercentage,
            airFilterPercentage = airFilterPercentage,
            tirePercentage = tirePercentage,
            brakePercentage = brakePercentage,
            clutchPercentage = clutchPercentage
        })
    else
        Notify(locale('error.not_in_vehicle'), 'error')
    end
end, false)
RegisterCommand(Config.ToggleCommand, function()
    if inVehicle and currentPlate then
        if mileageVisible then
            SendNUIMessage({
                type = "toggleMileage",
                visible = false
            })
            mileageVisible = false
        else
            SendNUIMessage({
                type = "toggleMileage",
                visible = true
            })
            mileageVisible = true
        end
    else
        Notify(locale('error.not_in_vehicle'), 'error')
    end
end, false)