local function debug(data)
    if Config.Debug then print(data) end
end

RegisterNetEvent('vehicleMileage:retrieveMileage')
AddEventHandler('vehicleMileage:retrieveMileage', function(plate)
    local src = source
    if not plate then return end
    local query = [[
        SELECT mileage, last_oil_change, last_oil_filter_change, last_air_filter_change, 
        last_tire_change, last_brakes_change, brake_wear 
        FROM vehicle_mileage WHERE plate = ? LIMIT 1
    ]]
    exports.oxmysql:execute(query, {plate}, function(result)
        local mileage = 0.0
        local lastOil = 0.0
        local lastFilter = 0.0
        local lastAirFilter = 0.0
        local lastTire = 0.0
        local last_brakes_change = 0.0
        local brake_wear = 0.0
        if result and result[1] then
            mileage = tonumber(result[1].mileage) or 0.0
            lastOil = tonumber(result[1].last_oil_change) or 0.0
            lastFilter = tonumber(result[1].last_oil_filter_change) or 0.0
            lastAirFilter = tonumber(result[1].last_air_filter_change) or 0.0
            lastTire = tonumber(result[1].last_tire_change) or 0.0
            lastBrake = tonumber(result[1].last_brakes_change) or 0.0
            brakeWear = tonumber(result[1].brake_wear) or 0.0
        end
        TriggerClientEvent('vehicleMileage:setData', src, mileage, lastOil, lastFilter, lastAirFilter, lastTire, lastBrake, brakeWear)
    end)
end)

RegisterNetEvent('vehicleMileage:updateMileage')
AddEventHandler('vehicleMileage:updateMileage', function(plate, mileage)
    if not plate or type(mileage) ~= "number" then
        debug("Invalid data provided for mileage update.")
        return
    end
    debug("Updating mileage for plate " .. plate .. " to " .. mileage)
    local query = [[
        INSERT INTO vehicle_mileage (plate, mileage, last_oil_change, last_oil_filter_change, last_air_filter_change, last_tire_change, last_brakes_change, brake_wear)
        VALUES (?, ?, 0, 0, 0, 0, 0, 0)
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

RegisterNetEvent('vehicleMileage:updateOilChange')
AddEventHandler('vehicleMileage:updateOilChange', function(plate)
    if not plate then return end
    
    local query = "SELECT mileage FROM vehicle_mileage WHERE plate = ?"
    exports.oxmysql:execute(query, {plate}, function(result)
        local mileage = 0.0
        if result and result[1] then
            mileage = tonumber(result[1].mileage) or 0.0
            
            local updateQuery = "UPDATE vehicle_mileage SET last_oil_change = ? WHERE plate = ?"
            exports.oxmysql:execute(updateQuery, {mileage, plate}, function(rowsChanged)
                if rowsChanged then
                    debug("Oil change update successful for plate " .. plate .. " at mileage " .. mileage)
                else
                    debug("Oil change update failed for plate " .. plate)
                end
            end)
        else
            debug("No mileage record found for plate " .. plate)
        end
    end)
end)

RegisterNetEvent('vehicleMileage:updateOilFilter')
AddEventHandler('vehicleMileage:updateOilFilter', function(plate)
    if not plate then return end
    
    local query = "SELECT mileage FROM vehicle_mileage WHERE plate = ?"
    exports.oxmysql:execute(query, {plate}, function(result)
        local mileage = 0.0
        if result and result[1] then
            mileage = tonumber(result[1].mileage) or 0.0
            
            local updateQuery = "UPDATE vehicle_mileage SET last_oil_filter_change = ? WHERE plate = ?"
            exports.oxmysql:execute(updateQuery, {mileage, plate}, function(rowsChanged)
                if rowsChanged then
                    debug("Oil filter change update successful for plate " .. plate .. " at mileage " .. mileage)
                else
                    debug("Oil filter change update failed for plate " .. plate)
                end
            end)
        else
            debug("No mileage record found for plate " .. plate)
        end
    end)
end)

RegisterNetEvent('vehicleMileage:updateAirFilter')
AddEventHandler('vehicleMileage:updateAirFilter', function(plate)
    if not plate then return end
    
    local query = "SELECT mileage FROM vehicle_mileage WHERE plate = ?"
    exports.oxmysql:execute(query, {plate}, function(result)
        local mileage = 0.0
        if result and result[1] then
            mileage = tonumber(result[1].mileage) or 0.0
            
            local updateQuery = "UPDATE vehicle_mileage SET last_air_filter_change = ? WHERE plate = ?"
            exports.oxmysql:execute(updateQuery, {mileage, plate}, function(rowsChanged)
                if rowsChanged then
                    debug("Air filter change update successful for plate " .. plate .. " at mileage " .. mileage)
                else
                    debug("Air filter change update failed for plate " .. plate)
                end
            end)
        else
            debug("No mileage record found for plate " .. plate)
        end
    end)
end)

RegisterNetEvent('vehicleMileage:updateTireChange')
AddEventHandler('vehicleMileage:updateTireChange', function(plate)
    if not plate then return end
    
    local query = "SELECT mileage FROM vehicle_mileage WHERE plate = ?"
    exports.oxmysql:execute(query, {plate}, function(result)
        local mileage = 0.0
        if result and result[1] then
            mileage = tonumber(result[1].mileage) or 0.0
            
            local updateQuery = "UPDATE vehicle_mileage SET last_tire_change = ? WHERE plate = ?"
            exports.oxmysql:execute(updateQuery, {mileage, plate}, function(rowsChanged)
                if rowsChanged then
                    debug("Tire change update successful for plate " .. plate .. " at mileage " .. mileage)
                else
                    debug("Tire change update failed for plate " .. plate)
                end
            end)
        else
            debug("No mileage record found for plate " .. plate)
        end
    end)
end)

RegisterNetEvent('vehicleMileage:updateBrakeWear')
AddEventHandler('vehicleMileage:updateBrakeWear', function(plate, brakeWear)
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

RegisterNetEvent('vehicleMileage:updateBrakeChange')
AddEventHandler('vehicleMileage:updateBrakeChange', function(plate)
    if not plate then 
        debug("Invalid plate provided for brake change update")
        return 
    end
    
    local query = "SELECT mileage FROM vehicle_mileage WHERE plate = ?"
    exports.oxmysql:execute(query, {plate}, function(result)
        if result and result[1] then
            local mileage = tonumber(result[1].mileage) or 0.0
            
            local updateQuery = "UPDATE vehicle_mileage SET last_brakes_change = ?, brake_wear = ? WHERE plate = ?"
            exports.oxmysql:execute(updateQuery, {mileage, 0.0, plate}, function(rowsChanged)
                if rowsChanged then
                    debug("Brake change update successful for plate " .. plate .. " at mileage " .. mileage)
                else
                    debug("Brake change update failed for plate " .. plate)
                end
            end)
        else
            debug("No mileage record found for plate " .. plate)
        end
    end)
end)

RegisterNetEvent('vehicleMileage:checkOwnership')
AddEventHandler('vehicleMileage:checkOwnership', function(plate)
    local src = source
    if not plate then return end
    
    local query = "SELECT 1 FROM " .. Config.VehDB .. " WHERE plate = ? LIMIT 1"
    exports.oxmysql:execute(query, {plate}, function(result)
        local isOwned = result and #result > 0
        TriggerClientEvent('vehicleMileage:ownershipResult', src, isOwned)
    end)
end)

RegisterCommand(Config.CMCommand, function(source, args)
    if not args[1] then
        print("No plate provided for mileage clear command")
        return
    end
    local plate = args[1]
    local query = "DELETE FROM vehicle_mileage WHERE plate = ?"
    exports.oxmysql:execute(query, {plate}, function(result)
        if result and result.affectedRows and result.affectedRows > 0 then
            print("Mileage data cleared successfully for plate " .. plate)
        else
            print("No mileage data found for plate " .. plate)
        end
    end)
end, true)
