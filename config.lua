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
--          Script Wiki: https://github.com/CodeWizardsDev/
--
--          CodeWizards Discord Server: https://discord.gg/ZBvacHyczY
--          CodeWizards Github: https://github.com/CodeWizardsDev
--          CodeWizards WebSite: SOON!






Config = {}
Config.Debug = false                  -- When enabled, prints debug messages to the console for troubleshooting

Config.Notify = 'qbx'                 -- Choose your notification system: "wizard", "qb", "qbx", "okok", or "esx"
Config.Unit = 'km'                    -- Set distance unit: "km" for kilometers or "mile" for miles
Config.M_Location = 'bottom-right'    -- Position of mileage display on screen: "top-left", "top-right", "bottom-left", "bottom-right"

Config.CheckWearCommand = 'checkwear' -- Command to check vehicle parts condition (oil, filters, tires, etc.)
Config.CMCommand = 'clearmileage'     -- Command to reset vehicle mileage to zero

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

Config.UseTarget = true               -- Enable targeting system for vehicle maintenance
Config.Targeting = 'ox'               -- Choose targeting system: 'ox' for ox_target, 'qb' for qb-target

Config.ChangeWarnings = true          -- Enable notifications when vehicle parts need maintenance
Config.WarningsInterval = 30          -- How often to check and warn about vehicle maintenance (in seconds)

Config.OilChangeDistance = 20         -- Distance in km/miles before oil change is needed
Config.OilFilterDistance = 40         -- Distance in km/miles before oil filter change is needed
Config.EngineDamageRate = 0.5         -- How quickly engine takes damage from poor maintenance (0.0 to 1.0)

Config.AirFilterDistance = 50         -- Distance in km/miles before air filter change is needed
Config.MaxSpeedReduction = 0.2        -- Maximum speed reduction when air filter is worn (20%)
Config.AccelerationReduction = 0.3    -- Maximum acceleration reduction when air filter is worn (30%)

Config.TireWearDistance = 10          -- Distance in km/miles before tires need replacement
Config.BaseTireGrip = 2.5             -- Maximum tire grip when new
Config.MinTireGrip = 0.5              -- Minimum tire grip when completely worn

Config.BrakeWearRate = 0.08           -- How quickly brakes wear out
Config.MaxBrakeWear = 100.0           -- Maximum brake wear value
Config.BrakeEfficiencyLoss = 1.0      -- How much braking power is lost when worn
Config.BaseBrakeForce = 1.0           -- Base brake force multiplier


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