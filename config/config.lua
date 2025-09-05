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
--          This file controls all settings for the Wizard Mileage System.
--          Adjust these options to fit your server's framework, inventory, UI, maintenance logic, and gameplay needs.

--          📚 Documentation:
--              - Wiki:    https://code-wizards.gitbook.io/codewizards/mileage-system/informations
--              - Discord: https://discord.gg/ZBvacHyczY
--              - GitHub:  https://github.com/CodeWizardsDev

--          🛠️ Quick Reference:
--              - Language, Menu, Units
--              - UI Defaults, Commands, Admin Permission, Autosave, Ownership, Job Requirements
--              - Targeting, Warnings, Wear Tracking, Maintenance Intervals, Items
--              - Animation/Interaction Configs, Disabled Vehicle Classes

--          💡 Tip: 
--              All changes require a server restart or resource restart to take effect.






Config = {}

-- ████████████████ GENERAL SETTINGS ████████████████

Config.Debug            = true      -- Enable debug messages in console
Config.InventoryItems   = true      -- Require inventory items for maintenance
Config.Menu             = 'ox'      -- "ox" or "qb"



-- ████████████████ UI & COMMANDS ████████████████

Config.DefaultUI = {
    mileage_visible     = 1,        -- 1 = visible, 0 = hidden
    mileage_size        = 1,        -- UI scale
    checkwear_size      = 1,        -- CheckWear UI scale
    mileage_pos_x       = 1660,     -- Mileage UI X position
    mileage_pos_y       = 1012,     -- Mileage UI Y position
    checkwear_pos_x     = 1495.75,  -- CheckWear UI X position
    checkwear_pos_y     = 72.75     -- CheckWear UI Y position
}

Config.CustomizeCommand = 'mileageui'   -- Open UI customizer
Config.CheckWearCommand = 'checkwear'   -- Check vehicle part condition
Config.CMCommand        = 'clearmileage'-- Reset vehicle mileage
Config.DatabaseCommand  = 'mileagedb'   -- Open vehicle data list



-- ████████████████ ADMIN SETTINGS ████████████████

Config.AdminPermission  = 'group.admin'       -- Required permission for database access



-- ████████████████ AUTOSAVE & OWNERSHIP ████████████████

Config.Autosave         = true          -- Enable autosave for mileage
Config.AutosaveInterval = 30            -- Autosave interval (seconds)
Config.MinDiffToSave    = 100.0         -- Minimum difference required between current mileage and last saved mileage to update the database
Config.BoughtVehiclesOnly = true        -- Only track owned vehicles
Config.VehDB            = 'player_vehicles' -- Vehicle ownership table



-- ████████████████ JOB & TARGETING ████████████████

Config.JobRequired      = true          -- Only mechanics can service vehicles
Config.MechanicJobs     = {             -- Allowed jobs name
    ['mechanic'] = 0,                   -- Mechanic from grade 0
    ['lsc']      = 2,                   -- LSC from grade 2
}
Config.Targeting        = 'ox'          -- "ox" or "qb", set to false to disable



-- ████████████████ WARNINGS & WEAR TRACKING ████████████████

Config.ChangeWarnings   = true          -- Enable maintenance warnings
Config.WarningsInterval = 30            -- Warning check interval (seconds)

Config.Thresholds = {
    SparkPlugs = {
        { value = 1, severity = 'error', action = 'replace_immediately' },
        { value = 5, severity = 'warning', action = 'replace_soon' },
        { value = 10, severity = 'warning' },
        { value = 25, severity = 'info' }
    },

    Oil = {
        { value = 1, severity = 'error', action = 'replace_immediately' },
        { value = 2, severity = 'warning', action = 'replace_soon' },
        { value = 3, severity = 'warning', action = 'replace_need' },
        { value = 5, severity = 'warning' },
        { value = 10, severity = 'warning' },
        { value = 25, severity = 'info' },
        { value = 50, severity = 'info' }
    },

    OilFilter = {
        { value = 1, severity = 'error', action = 'replace_immediately' },
        { value = 5, severity = 'warning', action = 'replace_soon' },
        { value = 10, severity = 'warning' },
        { value = 25, severity = 'info' }
    },

    AirFilter = {
        { value = 1, severity = 'error', action = 'replace_immediately' },
        { value = 5, severity = 'warning', action = 'replace_soon' },
        { value = 10, severity = 'warning' },
        { value = 25, severity = 'info' }
    },

    Tires = {
        { value = 1, severity = 'error', action = 'replace_immediately' },
        { value = 2, severity = 'warning', action = 'replace_soon' },
        { value = 3, severity = 'warning', action = 'replace_need' },
        { value = 5, severity = 'warning', action = 'replace_need' },
        { value = 10, severity = 'warning' },
        { value = 25, severity = 'info' },
        { value = 50, severity = 'info' }
    },

    Brakes = {
        { value = 1, severity = 'error', action = 'replace_immediately' },
        { value = 5, severity = 'warning', action = 'replace_soon' },
        { value = 10, severity = 'warning' },
        { value = 25, severity = 'info' }
    },

    Suspension = {
        { value = 1, severity = 'error', action = 'replace_immediately' },
        { value = 5, severity = 'warning', action = 'replace_soon' },
        { value = 10, severity = 'warning' },
        { value = 25, severity = 'info' }
    },

    Clutch = {
        { value = 1, severity = 'error', action = 'replace_immediately' },
        { value = 5, severity = 'warning', action = 'replace_soon' },
        { value = 10, severity = 'warning' },
        { value = 25, severity = 'info' }
    },
}

Config.WearTracking = {
    SparkPlugs  = true,                 -- Track spark plug wear
    Oil         = true,                 -- Track oil/oil filter wear
    AirFilter   = true,                 -- Track air filter wear
    Tires       = true,                 -- Track tire wear
    Brakes      = true,                 -- Track brake wear
    Suspension  = true,                 -- Track suspension wear
    Clutch      = true                  -- Track clutch wear
}

Config.CheckVehicle = {
    Animation = "base",
    AnimDict  = "amb@world_human_clipboard@male@base",

    Object    = "prop_notepad_01",      -- Object to attach to the player
    Bone      = 60309                   -- Target bone to attach the object to
}



-- ████████████████ MAINTENANCE INTERVALS & EFFECTS ████████████████

Config.SparkPlugChangeDistance = 13000  -- Distance before spark plug change (km/miles)
Config.MaxSparkPlugWear        = 0.02   -- Max spark plug wear value
Config.MissfireChance          = 0.3    -- Chance of misfire when worn (0-1)

Config.OilChangeDistance       = 4300   -- Distance before oil change
Config.OilFilterDistance       = 8600   -- Distance before oil filter change
Config.EngineDamageRate        = 0.5    -- Engine damage rate from poor maintenance

Config.AirFilterDistance       = 13000  -- Distance before air filter change
Config.MaxSpeedReduction       = 0.2    -- Max speed reduction (0-1)
Config.AccelerationReduction   = 0.3    -- Max acceleration reduction (0-1)

Config.TireWearDistance        = 10800  -- Distance before tire change
Config.BaseTireGrip            = 2.5    -- New tire grip
Config.MinTireGrip             = 0.5    -- Worn tire grip

Config.BrakeWearRate           = 0.08   -- Brake wear rate
Config.MaxBrakeWear            = 100.0  -- Max brake wear value
Config.BrakeEfficiencyLoss     = 1.0    -- Braking power loss when worn
Config.BaseBrakeForce          = 1.0    -- Base brake force

Config.SuspensionChangeDistance= 43200  -- Distance before suspension change
Config.MaxSuspensionWear       = 1.0    -- Max suspension wear value

Config.ClutchWearRate          = 0.1    -- Clutch wear rate
Config.MaxClutchWear           = 100.0  -- Max clutch wear value
Config.ClutchEfficiencyLoss    = 0.8    -- Power loss when clutch is worn
Config.BaseClutchForce         = 1.0    -- Base clutch force
Config.StallChance             = 0.4    -- Stall chance when clutch is worn



-- ████████████████ ITEM NAMES (INVENTORY) ████████████████

Config.Items = {
    SparkPlug   = "spark_plugs",
    EngineOil   = "engine_oil",
    OilFilter   = "oil_filter",
    AirFilter   = "air_filter",
    Tires       = "tires",
    BrakeParts  = "brake_parts",
    SusParts    = "suspension_parts",
    Clutch      = "clutch"
}



-- ████████████████ INTERACTION ANIMATION CONFIGS ████████████████

Config.ChangeSparkPlug = {
    Animation       = "fixing_a_ped",
    AnimationDict   = "mini@repair",
    Duration        = 5000,
    FreezeCar       = true,
    FreezePlayer    = true,
    Cancelable      = true
}

Config.ChangeOil = {
    Animation       = "fixing_a_ped",
    AnimationDict   = "mini@repair",
    Duration        = 10000,
    FreezeCar       = true,
    FreezePlayer    = true,
    Cancelable      = true
}

Config.ChangeOilFilter = {
    Animation       = "fixing_a_player",
    AnimationDict   = "mini@repair",
    Duration        = 5000,
    FreezeCar       = true,
    FreezePlayer    = true,
    Cancelable      = true
}

Config.ChangeAirFilter = {
    Animation       = "work2_base",
    AnimationDict   = "missmechanic",
    Duration        = 3000,
    FreezeCar       = true,
    FreezePlayer    = true,
    Cancelable      = true
}

Config.ChangeTires = {
    Animation       = "car_bomb_mechanic",
    AnimationDict   = "mp_car_bomb",
    Duration        = 7000,
    FreezeCar       = true,
    FreezePlayer    = true,
    Cancelable      = true
}

Config.ChangeBrakes = {
    Animation       = "machinic_loop_mechandplayer",
    AnimationDict   = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
    Duration        = 5000,
    FreezeCar       = true,
    FreezePlayer    = true,
    Cancelable      = true
}

Config.ChangeSuspension = {
    Animation       = "car_bomb_mechanic",
    AnimationDict   = "mp_car_bomb",
    Duration        = 7000,
    FreezeCar       = true,
    FreezePlayer    = true,
    Cancelable      = true
}

Config.ChangeClutch = {
    Animation       = "fixing_a_ped",
    AnimationDict   = "mini@repair",
    Duration        = 15000,
    FreezeCar       = true,
    FreezePlayer    = true,
    Cancelable      = true
}

-- ████████████████ DISABLED VEHICLE CLASSES ████████████████
-- Set to true to disable mileage/wear for that class
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
    --[9] = true,   -- OFf-Road
    --[10] = true,  -- Industrial
    --[11] = true,  -- Utility
    --[12] = true,  -- Vans
    [13] = true,    -- Cycles
    [14] = true,    -- Boats
    [15] = true,    -- Helicopters
    [16] = true,    -- Planes
    [21] = true,    -- Trains
    [19] = true,    -- Military vehicles
    [20] = true,    -- Commercial vehicles
    [21] = true,    -- Trains
    [22] = true     -- Open Wheel
}