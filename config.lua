--  ┍━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┑
--  │                                                                                                     │
--  │     ░█████╗░░█████╗░██████╗░███████╗  ░██╗░░░░░░░██╗██╗███████╗░█████╗░██████╗░██████╗░░██████╗     │
--  │     ██╔══██╗██╔══██╗██╔══██╗██╔════╝  ░██║░░██╗░░██║██║╚════██║██╔══██╗██╔══██╗██╔══██╗██╔════╝     │
--  │     ██║░░╚═╝██║░░██║██║░░██║█████╗░░  ░╚██╗████╗██╔╝██║░░███╔═╝███████║██████╔╝██║░░██║╚█████╗░     │
--  │     ██║░░██╗██║░░██║██║░░██║██╔══╝░░  ░░████╔═████║░██║██╔══╝░░██╔══██║██╔══██╗██║░░██║░╚═══██╗     │
--  │     ╚█████╔╝╚█████╔╝██████╔╝███████╗  ░░╚██╔╝░╚██╔╝░██║███████╗██║░░██║██║░░██║██████╔╝██████╔╝     │
--  │     ░╚════╝░░╚════╝░╚═════╝░╚══════╝  ░░░╚═╝░░░╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═╝░░╚═╝╚═════╝░╚═════╝░     │
--  │                                                                                                     │
--  │                                                                                                     │
--  │                                                                                                     │
--  │                 ░█──░█ █▀▀ █──█ ─▀─ █▀▀ █── █▀▀ 　 ░█▀▄▀█ ─▀─ █── █▀▀ █▀▀█ █▀▀▀ █▀▀                 │
--  │                 ─░█░█─ █▀▀ █▀▀█ ▀█▀ █── █── █▀▀ 　 ░█░█░█ ▀█▀ █── █▀▀ █▄▄█ █─▀█ █▀▀                 │
--  │                 ──▀▄▀─ ▀▀▀ ▀──▀ ▀▀▀ ▀▀▀ ▀▀▀ ▀▀▀ 　 ░█──░█ ▀▀▀ ▀▀▀ ▀▀▀ ▀──▀ ▀▀▀▀ ▀▀▀                 │
--  └─────────────────────────────────────────────────────────────────────────────────────────────────────┘
--
--          Thank you for downloading our script! we're glad to help you to make your server better:)
--          Feel free to contact us if you have any problem/idea for this script! 
--
--          Script Wiki: https://code-wizards.gitbook.io/codewizards/mileage-system/informations
--
--          CodeWizards Discord Server: https://discord.gg/ZBvacHyczY
--          CodeWizards Github: https://github.com/CodeWizardsDev






Config = {}
Config.Language = 'en'                -- Default UI language
Config.Debug = true                   -- When enabled, prints debug messages to the console for troubleshooting
Config.FrameWork = 'qb'               -- Choose your framework: "qb" for QBCore/QBox, "esx" for ESX
Config.InventoryItems = true          -- Enable inventory items for vehicle parts and tools
Config.InventoryScript = 'ox'         -- Choose inventory system: 'ox' for ox_inventory, 'codem', 'quasar', 'qb' for qb-inventory, or 'esx' for esx built in inventory
Config.ProgressBar = 'ox'             -- Choose your progress bar: "qb" for QBCore/QBox and "ox" for ox_lib
Config.Menu = 'ox'                    -- Choose your menu: "ox" for ox_lib, "qb" for QBCore/QBox

Config.Notify = 'ox'                  -- Choose your notification system: "wizard", "ox", "qb", "qbx" "okok", or "esx"
Config.Unit = 'km'                    -- Set distance unit: "km" for kilometers or "mile" for miles

Config.DefaultUI = {                  -- Default UI Settings for players
    mileage_visible = 1,              -- Mileage UI visibility, 1 = visible, 0 = hidden
    mileage_size = 1,                 -- Scale of Mileage UI, 1 = default scale
    checkwear_size = 1,               -- Scale of CheckWear UI, 1 = default scale
    mileage_pos_x = 1660,             -- X position of Mileage UI
    mileage_pos_y = 1012,             -- Y position of Mileage UI
    checkwear_pos_x = 1495.75,        -- X position of CheckWear UI
    checkwear_pos_y = 72.75           -- Y position of CheckWear UI
}

Config.CustomizeCommand = 'mileageui' -- Command to open UI customizer
Config.CheckWearCommand = 'checkwear' -- Command to check vehicle parts condition (oil, filters, tires, etc.)
Config.CMCommand = 'clearmileage'     -- Command to reset vehicle mileage to zero
Config.DatabaseCommand = 'mileagedb'    -- Command to open saved vehicled list with data

Config.AdminRank = 'admin'

Config.Autosave = true                -- Enable automatic saving of vehicle mileage to database
Config.AutosaveInterval = 10          -- How often to save mileage (in seconds)

Config.BoughtVehiclesOnly = true      -- If true, only tracks mileage for player-owned vehicles
Config.VehDB = 'player_vehicles'      -- Database table name for vehicle ownership
                                        -- Use:
                                        -- 'player_vehicles' for QBCore & QBox
                                        -- 'owned_vehicles' for ESX
                                        -- or any custom vehicle database table name

Config.JobRequired = true             -- If true, only below job can service vehicle parts
Config.MechanicJob = 'mechanic'       -- Job name for mechanics in your server
Config.MinimumJobGrade = 2            -- Minimum job grade required to service vehicle parts

Config.UseTarget = true               -- Enable targeting system for vehicle maintenance
Config.Targeting = 'ox'               -- Choose targeting system: 'ox' for ox_target, 'qb' for qb-target

Config.ChangeWarnings = true          -- Enable notifications when vehicle parts need maintenance
Config.WarningsInterval = 30          -- How often to check and warn about vehicle maintenance (in seconds)


Config.WearTracking = {
    SparkPlugs = true,                -- Track spark plug wear and update Database
    Oil = true,                       -- Track oil/oilfilter wear and update Database
    AirFilter = true,                 -- Track air filter wear and update Database
    Tires = true,                     -- Track tire wear and update Database
    Brakes = true,                    -- Track brake wear and update Database
    Suspension = true,                -- Track suspension wear and update Database
    Clutch = true,                    -- Track clutch wear and update Database
}


Config.SparkPlugChangeDistance = 50   -- Distance in km/miles before spark plug change is needed
Config.MaxSparkPlugWear = 0.02        -- Maximum spark plug wear value
Config.MissfireChance = 0.3           -- Chance of engine missfire when spark plugs are worn out (30%)

Config.OilChangeDistance = 50         -- Distance in km/miles before oil change is needed
Config.OilFilterDistance = 40         -- Distance in km/miles before oil filter change is needed
Config.EngineDamageRate = 0.5         -- How quickly engine takes damage from poor maintenance (0.0 to 1.0)

Config.AirFilterDistance = 100        -- Distance in km/miles before air filter change is needed
Config.MaxSpeedReduction = 0.2        -- Maximum speed reduction when air filter is worn (20%)
Config.AccelerationReduction = 0.3    -- Maximum acceleration reduction when air filter is worn (30%)

Config.TireWearDistance = 250         -- Distance in km/miles before tires need replacement
Config.BaseTireGrip = 2.5             -- Maximum tire grip when new
Config.MinTireGrip = 0.5              -- Minimum tire grip when completely worn

Config.BrakeWearRate = 0.08           -- How quickly brakes wear out
Config.MaxBrakeWear = 100.0           -- Maximum brake wear value
Config.BrakeEfficiencyLoss = 1.0      -- How much braking power is lost when worn
Config.BaseBrakeForce = 1.0           -- Base brake force multiplier

Config.SuspensionChangeDistance = 300 -- Distance in km/miles before suspension needs replacement
Config.MaxSuspensionWear = 1.0        -- Maximum suspension wear value

Config.ClutchWearRate = 0.1           -- How quickly clutch wears out during gear shifts
Config.MaxClutchWear = 100.0          -- Maximum clutch wear value
Config.ClutchEfficiencyLoss = 0.8     -- How much power is lost when clutch is worn (80%)
Config.BaseClutchForce = 1.0          -- Base clutch force multiplier
Config.StallChance = 0.4              -- Chance of engine stalling when clutch is worn (40%)

Config.Items = {
    SparkPlug = "spark_plugs",        -- Item name for spark plugs
    EngineOil = "engine_oil",         -- Item name for engine oil
    OilFilter = "oil_filter",         -- Item name for oil filter
    AirFilter = "air_filter",         -- Item name for air filter
    Tires = "tires",                  -- Item name for tires
    BrakeParts = "brake_parts",       -- Item name for brake parts
    SusParts = "suspension_parts",    -- Item name for suspension parts
    Clutch = "clutch",                -- Item name for clutch
}

-- Configuration table for spark plug replacement interaction
Config.ChangeSparkPlug = {
    Animation = "fixing_a_ped",
    AnimationDict = "mini@repair",
    Duration = 5000,

    FreezeCar = true,
    FreezePlayer = true,

    Cancelable = true,
}

-- Configuration table for oil change interaction
Config.ChangeOil  = {
    Animation = "fixing_a_ped",       -- Animation name to play during oil change
    AnimationDict = "mini@repair",    -- Animation dictionary containing the animation
    Duration = 10000,                 -- Duration of oil change animation in milliseconds (10 seconds)

    FreezeCar = true,                 -- If true, prevents vehicle movement during oil change
    FreezePlayer = true,              -- If true, prevents player movement during oil change

    Cancelable = true,                -- If true, allows players to cancel the oil change action
}

-- Configuration table for oil filter change interaction
Config.ChangeOilFilter  = {
    Animation = "fixing_a_player",
    AnimationDict = "mini@repair",
    Duration = 5000,

    FreezeCar = true,
    FreezePlayer = true,

    Cancelable = true,
}

-- Configuration table for air filter change interaction
Config.ChangeAirFilter  = {
    Animation = "work2_base",
    AnimationDict = "missmechanic",
    Duration = 3000,

    FreezeCar = true,
    FreezePlayer = true,

    Cancelable = true,
}

-- Configuration table for tire filter change interaction
Config.ChangeTires = {
    Animation = "car_bomb_mechanic",
    AnimationDict = "mp_car_bomb",
    Duration = 7000,

    FreezeCar = true,
    FreezePlayer = true,

    Cancelable = true,
}

-- Configuration table for brakes service interaction
Config.ChangeBrakes = {
    Animation = "machinic_loop_mechandplayer",
    AnimationDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
    Duration = 5000,

    FreezeCar = true,
    FreezePlayer = true,

    Cancelable = true,
}

-- Configuration table for suspension service interaction
Config.ChangeSuspension = {
    Animation = "car_bomb_mechanic",
    AnimationDict = "mp_car_bomb",
    Duration = 7000,

    FreezeCar = true,
    FreezePlayer = true,

    Cancelable = true,
}

-- Configuration table for clutch change interaction
Config.ChangeClutch = {
    Animation = "fixing_a_ped",
    AnimationDict = "mini@repair",

    Duration = 15000,                   -- 15 seconds for clutch change

    FreezeCar = true,
    FreezePlayer = true,

    Cancelable = true,
}

-- Configuration table for disabled vehicle classes
Config.DisabledVehicleClasses = {
    --[0] = true,   -- Compacts  
    --[1] = true,   -- Sedans  
    --[2] = true,   -- SUVs  
    --[3] = true,   -- Coupes  
    --[4] = true,   -- Muscle  
    --[5] = true,   -- Sports Classics  
    --[6] = true,   -- Sports  
    --[7] = true,   -- Super 
    --[8] = true,   -- Motorcycles
    [13] = true,    -- Cycles
    [14] = true,    -- Boats
    [15] = true,    -- Helicopters
    [16] = true,    -- Planes
    [21] = true,    -- Trains
    [19] = true,    -- Military vehicles
    [20] = true     -- Commercial vehicles
}
