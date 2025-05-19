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
local GetEntityCoords = GetEntityCoords
local PlayerPedId = PlayerPedId
local IsPedInAnyVehicle = IsPedInAnyVehicle
local GetVehiclePedIsIn = GetVehiclePedIsIn
local DoesEntityExist = DoesEntityExist
local lastEngineCriticalNotify = 0
local oilchangedist, oilfilterchangedist, airfilterchangedist, tirechangedist = nil, nil, nil, nil

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

CreateThread(function()
    Wait(100)
    SendNUIMessage({
        type = "Configuration",
        location = Config.M_Location
    })
end)

local function Notify(message, type)
    if not message or not type then return end
    
    local notifyConfig = {
        wizard = function() exports['wizard-notify']:Send('Wizard Mileage', message, 5000, type) end,
        okok = function() exports['okokNotify']:Alert('Wizard Mileage', message, 5000, type, false) end,
        qbx = function() exports.qbx_core:Notify(message, type, 5000) end,
        qb = function() TriggerEvent('QBCore:Notify', source, message, type) end,
        esx = function() exports['esx_notify']:Notify(message, type, 5000, 'Wizard Mileage') end,
        ox = function() 
            lib.notify{
                title = 'Wizard Mileage',
                description = message,
                type = type
            }
        end
    }
    
    local notifyFunc = notifyConfig[Config.Notify]
    if notifyFunc then notifyFunc() end
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
local function getDistance(vec1, vec2)
    if not vec1 or not vec2 then return 0 end
    local dx, dy, dz = vec1.x - vec2.x, vec1.y - vec2.y, vec1.z - vec2.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
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
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if inVehicle and currentPlate then
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            if DoesEntityExist(vehicle) and IsControlPressed(0, 72) then
                local speed = GetEntitySpeed(vehicle)
                local gear = GetVehicleCurrentGear(vehicle)
                if speed > 0 and gear > 0 then
                    lastbrakeWear = lastbrakeWear + Config.BrakeWearRate
                    TriggerServerEvent('vehicleMileage:updateBrakeWear', currentPlate, lastbrakeWear)
                    updateBrakeWear(vehicle)
                end
            end
        end
    end
end)
if IsControlPressed(0, 72) then
    local brakeWear = brakeWear + Config.BrakeWearRate
    TriggerServerEvent('vehicleMileage:updateBrakeWear', currentPlate, brakeWear)
    updateBrakeWear(vehicle)
end

RegisterNetEvent('vehicleMileage:setData')
AddEventHandler('vehicleMileage:setData', function(mileage, oilChange, filterChange, AirfilterChange, tireChange, brakeChange, brakeWear)
    accDistance = mileage or 0.0
    lastOilChange = oilChange or 0.0
    lastOilFilterChange = filterChange or 0.0
    lastAirFilterChange = AirfilterChange or 0.0
    lastTireChange = tireChange or 0.0
    lastbrakeChange = brakeChange or 0.0
    lastbrakeWear = brakeWear or 0.0
    waitingForData = false
    local displayedMileage = convertDistance(accDistance)
    SendNUIMessage({
        type = "updateMileage",
        mileage = displayedMileage,
        unit = (Config.Unit == "mile" and "miles" or "km")
    })
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1500)
        local ped = PlayerPedId()
        local isInVehicle = IsPedInAnyVehicle(ped, false)
        if isInVehicle then
            local veh = GetVehiclePedIsIn(ped, false)
            if not inVehicle then
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
                else
                    SendNUIMessage({
                        type = "toggleMileage",
                        visible = false
                    })
                end
            else
                if waitingForData then
                    goto continue_loop
                end
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
        ::continue_loop::
    end
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

local function GetVehiclePlate(vehicle)
    if not DoesEntityExist(vehicle) then return "UNKNOWN" end
    return GetVehicleNumberPlateText(vehicle)
end
local function convertDistance(meters)
    if Config.Unit == "mile" then
        return meters * 0.000621371
    else
        return meters / 1000
    end
end

if Config.ChangeWarnings then
    local function checkWearLevels()
        if not inVehicle or not currentPlate then return end
    
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

        if oilPercentage <= 1 then
            Notify(locale('warning.remaining_oil').. " 1%! " ..locale('warning.replace_immediately'), 'error')
        elseif oilPercentage <= 2 then
            Notify(locale('warning.remaining_oil').. " 2%! " ..locale('warning.replace_soon'), 'warning')
        elseif oilPercentage <= 3 then
            Notify(locale('warning.remaining_oil').. " 3%! " ..locale('warning.replace_need'), 'warning')
        elseif oilPercentage <= 5 then
            Notify(locale('warning.remaining_oil').. " 5%", 'warning')
        elseif oilPercentage <= 10 then
            Notify(locale('warning.remaining_oil').. " 10%", 'warning')
        elseif oilPercentage <= 25 then
            Notify(locale('warning.remaining_oil').. " 25%", 'info')
        elseif oilPercentage <= 50 then
            Notify(locale('warning.remaining_oil').. " 50%", 'info')
        end

        if filterPercentage <= 1 then
            Notify(locale('warning.remaining_filter') .. " 1%! " .. locale('warning.replace_immediately'), 'error')
        elseif filterPercentage <= 5 then
            Notify(locale('warning.remaining_filter') .. " 5%! " .. locale('warning.replace_soon'), 'warning')
        elseif filterPercentage <= 10 then
            Notify(locale('warning.remaining_filter') .. " 10%", 'warning')
        elseif filterPercentage <= 25 then
            Notify(locale('warning.remaining_filter') .. " 25%", 'info')
        end

        if airFilterPercentage <= 1 then
            Notify(locale('warning.remaining_air_filter') .. " 1%! " .. locale('warning.replace_immediately'), 'error')
        elseif airFilterPercentage <= 5 then
            Notify(locale('warning.remaining_air_filter') .. " 5%! " .. locale('warning.replace_soon'), 'warning')
        elseif airFilterPercentage <= 10 then
            Notify(locale('warning.remaining_air_filter') .. " 10%", 'warning')
        elseif airFilterPercentage <= 25 then
            Notify(locale('warning.remaining_air_filter') .. " 25%", 'info')
        end
        
        if tirePercentage <= 1 then
            Notify(locale('warning.remaining_tire').. " 1%! " ..locale('warning.replace_immediately'), 'error')
        elseif tirePercentage <= 2 then
            Notify(locale('warning.remaining_tire').. " 2%! " ..locale('warning.replace_soon'), 'warning')
        elseif tirePercentage <= 3 then
            Notify(locale('warning.remaining_tire').. " 3%! " ..locale('warning.replace_need'), 'warning')
        elseif tirePercentage <= 5 then
            Notify(locale('warning.remaining_tire').. " 5%! " ..locale('warning.replace_need'), 'warning')
        elseif tirePercentage <= 10 then
            Notify(locale('warning.remaining_tire').. " 10%", 'warning')
        elseif tirePercentage <= 25 then
            Notify(locale('warning.remaining_tire').. " 25%", 'info')
        elseif tirePercentage <= 50 then
            Notify(locale('warning.remaining_tire').. " 50%", 'info')
        end

        if brakePercentage <= 1 then
            Notify(locale('warning.remaining_brakes') .. " 1%! " .. locale('warning.replace_immediately'), 'error')
        elseif brakePercentage <= 5 then
            Notify(locale('warning.remaining_brakes') .. " 5%! " .. locale('warning.replace_soon'), 'warning')
        elseif brakePercentage <= 10 then
            Notify(locale('warning.remaining_brakes') .. " 10%", 'warning')
        elseif brakePercentage <= 25 then
            Notify(locale('warning.remaining_brakes') .. " 25%", 'info')
        end
    end

    local checkinve = Config.WarningsInterval * 1000
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(checkinve)
            if inVehicle and not waitingForData then
                checkWearLevels()
            end
        end
    end)
end

CreateThread(function()
    if not Config.UseTarget then return end
    local options = {
        {
            name = 'change_vehicle_oil',
            icon = 'fas fa-oil-can',
            label = locale('target.changeoil'),
            distance = 2.0,
            canInteract = function(entity, distance, coords, name)
                if Config.JobRequired then
                    local PlayerData = exports.qbx_core:GetPlayerData()
                    return PlayerData.job.name == Config.MechanicJob and not IsPedInAnyVehicle(PlayerPedId(), false)
                end
                return not IsPedInAnyVehicle(PlayerPedId(), false)
            end,
            onSelect = function(data)
                local vehicle = data.entity
                local playerPed = PlayerPedId()
                
                local animDict = Config.ChangeOil.AnimationDict
                RequestAnimDict(animDict)
                while not HasAnimDictLoaded(animDict) do
                    Wait(10)
                end
                
                TaskPlayAnim(playerPed, animDict, Config.ChangeOil.Animation, 8.0, -8.0, -1, 1, 0, false, false, false)
                
                if lib.progressBar({
                    duration = Config.ChangeOil.Duration,
                    label = locale('progress.changingoil'),
                    useWhileDead = false,
                    canCancel = Config.ChangeOil.Cancelable,
                    disable = {
                        car = Config.ChangeOil.FreezeCar,
                        move = Config.ChangeOil.FreezePlayer,
                    },
                }) then
                    local plate = GetVehicleNumberPlateText(vehicle)
                    Notify(locale('info.oil_changed'), 'success')
                    TriggerServerEvent('vehicleMileage:updateOilChange', plate)
                end
                
                ClearPedTasks(playerPed)
            end
        },
        {
            name = 'change_vehicle_oil_filter',
            icon = 'fas fa-filter',
            label = locale('target.changeoilfilter'),
            distance = 2.0,
            canInteract = function(entity, distance, coords, name)
                if Config.JobRequired then
                    local PlayerData = exports.qbx_core:GetPlayerData()
                    return PlayerData.job.name == Config.MechanicJob and not IsPedInAnyVehicle(PlayerPedId(), false)
                end
                return not IsPedInAnyVehicle(PlayerPedId(), false)
            end,
            onSelect = function(data)
                local vehicle = data.entity
                local playerPed = PlayerPedId()
                    
                local animDict = Config.ChangeOilFilter.AnimationDict
                RequestAnimDict(animDict)
                while not HasAnimDictLoaded(animDict) do
                    Wait(10)
                end
                
                TaskPlayAnim(playerPed, animDict, Config.ChangeOilFilter.Animation, 8.0, -8.0, -1, 1, 0, false, false, false)
                
                if lib.progressBar({
                    duration = Config.ChangeOilFilter.Duration,
                    label = locale('progress.changingoilfilter'),
                    useWhileDead = false,
                    canCancel = Config.ChangeOilFilter.Cancelable,
                    disable = {
                        car = Config.ChangeOilFilter.FreezeCar,
                        move = Config.ChangeOilFilter.FreezePlayer,
                    },
                }) then
                    local plate = GetVehicleNumberPlateText(vehicle)
                    Notify(locale('info.filter_changed'), 'success')
                    TriggerServerEvent('vehicleMileage:updateOilFilter', plate)
                end
                
                ClearPedTasks(playerPed)
            end
        },
        {
            name = 'change_vehicle_air_filter',
            icon = 'fas fa-wind',
            label = locale('target.changeairfilter'),
            distance = 2.0,
            canInteract = function(entity, distance, coords, name)
                if Config.JobRequired then
                    local PlayerData = exports.qbx_core:GetPlayerData()
                    return PlayerData.job.name == Config.MechanicJob and not IsPedInAnyVehicle(PlayerPedId(), false)
                end
                return not IsPedInAnyVehicle(PlayerPedId(), false)
            end,
            onSelect = function(data)
                local vehicle = data.entity
                local playerPed = PlayerPedId()
                
                local animDict = Config.ChangeAirFilter.AnimationDict
                RequestAnimDict(animDict)
                while not HasAnimDictLoaded(animDict) do
                    Wait(10)
                end
                
                TaskPlayAnim(playerPed, animDict, Config.ChangeAirFilter.Animation, 8.0, -8.0, -1, 1, 0, false, false, false)
                
                if lib.progressBar({
                    duration = Config.ChangeAirFilter.Duration,
                    label = locale('progress.changingairfilter'),
                    useWhileDead = false,
                    canCancel = Config.ChangeAirFilter.Cancelable,
                    disable = {
                        car = Config.ChangeAirFilter.FreezeCar,
                        move = Config.ChangeAirFilter.FreezePlayer,
                    },
                }) then
                    local plate = GetVehicleNumberPlateText(vehicle)
                    Notify(locale('info.air_filter_changed'), 'success')
                    TriggerServerEvent('vehicleMileage:updateAirFilter', plate)

                    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel", Config.BaseTopSpeed)
                    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce", Config.BaseAcceleration)
                end
                
                ClearPedTasks(playerPed)
            end
        },
        {
                name = 'change_vehicle_tires',
                icon = 'fas fa-circle',
                label = locale('target.changetires'),
                distance = 2.0,
                canInteract = function(entity, distance, coords, name)
                    if Config.JobRequired then
                        local PlayerData = exports.qbx_core:GetPlayerData()
                        return PlayerData.job.name == Config.MechanicJob and not IsPedInAnyVehicle(PlayerPedId(), false)
                    end
                    return not IsPedInAnyVehicle(PlayerPedId(), false)
                end,
                onSelect = function(data)
                    local vehicle = data.entity
                    local playerPed = PlayerPedId()
        
                    local hasFlat = false
                    for i = 0, 5 do
                        if IsVehicleTyreBurst(vehicle, i, false) then
                            hasFlat = true
                            break
                        end
                    end
        
                    local animDict = Config.ChangeTires.AnimationDict
                    RequestAnimDict(animDict)
                    while not HasAnimDictLoaded(animDict) do
                        Wait(10)
                    end
        
                    TaskPlayAnim(playerPed, animDict, Config.ChangeTires.Animation, 8.0, -8.0, -1, 1, 0, false, false, false)
        
                    if lib.progressBar({
                        duration = Config.ChangeTires.Duration,
                        label = locale('progress.changingtires'),
                        useWhileDead = false,
                        canCancel = Config.ChangeTires.Cancelable,
                        disable = {
                            car = Config.ChangeTires.FreezeCar,
                            move = Config.ChangeTires.FreezePlayer,
                        },
                    }) then
                        local plate = GetVehicleNumberPlateText(vehicle)
                        lastTireChange = accDistance
            
                        for i = 0, 5 do
                            SetVehicleTyreFixed(vehicle, i)
                        end
            
                        Notify(locale('info.tire_changed'), 'success')
                        TriggerServerEvent('vehicleMileage:updateTireChange', plate)
                        print(plate)
                        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax", Config.BaseTireGrip)
                    end

                    ClearPedTasks(playerPed)
                end
        },
        {
        name = 'change_vehicle_brakes',
        icon = 'fas fa-brake-disc',
        label = locale('target.changebrakes'),
        distance = 2.0,
        canInteract = function(entity, distance, coords, name)
            if Config.JobRequired then
                local PlayerData = exports.qbx_core:GetPlayerData()
                return PlayerData.job.name == Config.MechanicJob and not IsPedInAnyVehicle(PlayerPedId(), false)
            end
            return not IsPedInAnyVehicle(PlayerPedId(), false)
        end,
        onSelect = function(data)
            local vehicle = data.entity
            local playerPed = PlayerPedId()
            
            local animDict = Config.ChangeBrakes.AnimationDict
            RequestAnimDict(animDict)
            while not HasAnimDictLoaded(animDict) do
                Wait(10)
            end
            
            TaskPlayAnim(playerPed, animDict, Config.ChangeBrakes.Animation, 8.0, -8.0, -1, 1, 0, false, false, false)
            
            if lib.progressBar({
                duration = Config.ChangeBrakes.Duration,
                label = locale('progress.changingbrakes'),
                useWhileDead = false,
                canCancel = Config.ChangeBrakes.Cancelable,
                disable = {
                    car = Config.ChangeBrakes.FreezeCar,
                    move = Config.ChangeBrakes.FreezePlayer,
                },
            }) then
                local plate = GetVehicleNumberPlateText(vehicle)
                Notify(locale('info.brakes_changed'), 'success')
                TriggerServerEvent('vehicleMileage:updateBrakeChange', plate)
                lastbrakeWear = 0.0
                updateBrakeWear(vehicle)
            end
            
            ClearPedTasks(playerPed)
        end
        }
    }
    if Config.Targeting == 'ox' then
        exports.ox_target:addGlobalVehicle(options)
    elseif Config.Targeting == 'qb' then
        exports['qb-target']:AddGlobalVehicle({
            options = options,
            distance = 2.5,
        })
    end
end)

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
        
        SendNUIMessage({
            type = "updateWear",
            oilPercentage = oilPercentage,
            filterPercentage = filterPercentage,
            airFilterPercentage = airFilterPercentage,
            tirePercentage = tirePercentage,
            brakePercentage = brakePercentage
        })
    else
        Notify(locale('error.not_in_vehicle'), 'error')
    end
end, false)
