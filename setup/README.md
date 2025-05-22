# Wizard Mileage System - Installation Guide
## Prerequisites
Before installing the Wizard Mileage System, ensure you have the following dependencies:
- [oxmysql](https://github.com/overextended/oxmysql)
- [ox_lib](https://github.com/overextended/ox_lib)
- One of the following targeting systems:
  - [ox_target](https://github.com/overextended/ox_target)
  - [qb-target](https://github.com/qbcore-framework/qb-target)
## Installation Steps
1. Download the latest release of wizard-mileage
2. Extract the folder and ensure it's named `wizard-mileage`
3. Copy the folder to your server's resources directory
4. Add the following to your `server.cfg`:
```cfg
   ensure oxmysql
   ensure ox_lib
   ensure wizard-mileage
```
## Database Setup
1. Import the required SQL files:
   - Base installation:
```sql
       import 'wizard-mileage/setup/import.sql'
    
```
- For inventory items (choose one based on your framework):
     - ESX with no weight:
```sql
       import 'wizard-mileage/setup/inventory/esx-no-weight.sql'
```
- ESX with realistic weight:
```sql
       import 'wizard-mileage/setup/inventory/esx-realistic-weight.sql'
```

## Configuration
1. Open `config.lua` and configure the following settings:
### Basic Settings
```lua
Config.Debug = false                  -- Enable/disable debug messages
Config.Notify = 'qbx'                 -- Notification system (wizard/qb/qbx/okok/esx/ox_lib)
Config.Unit = 'km'                    -- Distance unit (km/mile)
Config.M_Location = 'bottom-right'    -- HUD position
```
### Framework Settings
```lua
Config.BoughtVehiclesOnly = true      -- Track only owned vehicles
Config.VehDB = 'player_vehicles'      -- Database table name (player_vehicles for QB/QBox, owned_vehicles for ESX)
```
### Job Settings (ONLY FOR QB/QBX) 
```lua
Config.JobRequired = true             -- Require mechanic job for maintenance
Config.MechanicJob = 'mechanic'       -- Mechanic job name
Config.MinimumJobGrade = 2            -- Minimum job grade required
```
### Inventory Settings
```lua
Config.InventoryItems = true          -- Enable inventory items
Config.InventoryScript = 'ox'         -- Inventory system (ox/qb/esx)
```
### Target System
```lua
Config.UseTarget = true               -- Enable targeting system
Config.Targeting = 'ox'               -- Target system (ox/qb)
```

## Inventory Integration
### ox_inventory
Add the items to your `ox_inventory/data/items.lua`:
```lua
['engine_oil'] = {
    label = 'Engine Oil',
    weight = 4000,
    stack = true,
    close = true,
    description = 'Engine oil for vehicle maintenance'
},
-- Add other items from setup/inventory/ox-inventory.lua
```
### QB-Core
Add the items to your `qb-core/shared/items.lua`:
```lua
['engine_oil'] = {
    name = 'engine_oil',
    label = 'Engine Oil',
    weight = 4000,
    type = 'item',
    image = 'engine_oil.png',
    unique = false,
    useable = true,
    shouldClose = true,
    description = 'Engine oil for vehicle maintenance'
},
-- Add other items from setup/inventory/qb-inventory.lua
```

## Verification
1. Start your server
2. Check the console for any errors
3. In-game, use the `/checkwear` command while in a vehicle to verify the installation
## Support
For support, join our Discord server: [CodeWizards Discord](https://discord.gg/ZBvacHyczY)
## License
This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.