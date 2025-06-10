<h1 align="center">Wizard Mileage  System</h1>

<p align="center"> A comprehensive vehicle maintenance and mileage tracking system for FiveM servers that simulates realistic vehicle wear and tear, including oil life, filters, tires, and brake conditions. The system tracks vehicle mileage and component wear, requiring regular maintenance to maintain optimal vehicle performance.
    <br> 
</p>

## 📝 Table of Contents

- [WIKI PAGE](https://code-wizards.gitbook.io/codewizards/mileage-system/informations)
- [ShowCase](#showcase)
- [Todo](#todo)
- [Dependencies](#dependencies)
- [Features Scope](#feature_scope)
- [Setting up](#getting_started)
- [Authors](#authors)
- [Translations](#trans)
- [Support](#support)
- [License](#license)

## 🖼️ ShowCase <a name = "showcase"></a>
<div style="display: flex; flex-wrap: wrap; gap: 10px; justify-content: center;">
    <img src="https://github.com/user-attachments/assets/adfb0ba2-03d6-41e1-87a4-8992d38bb7d0" alt="" style="width: 400px; height: auto; object-fit: cover;">
    <img src="https://github.com/user-attachments/assets/23e2ed14-b2cc-4467-a47f-854aa0e534d2" alt="" style="width: 400px; height: auto; object-fit: cover;">
    <img src="https://github.com/user-attachments/assets/c580684a-5899-4a96-8690-2df41557a31b" alt="" style="width: 400px; height: 200px; object-fit: cover;">
    <img src="https://github.com/user-attachments/assets/5cafe0d7-b996-4aa4-a9a3-78dcdfe872a6" alt="" style="width: 400px; height: 200px; object-fit: cover;">
    <img src="https://github.com/user-attachments/assets/40889768-9da5-47ba-b5eb-a1a521af5510" alt="" style="width: 400px; height: 200px; object-fit: cover;">
    <img src="https://github.com/user-attachments/assets/c26309c4-8f6e-4290-834a-db867d65a83a" alt="" style="width: 400px; height: 200px; object-fit: cover;">
    <img src="https://github.com/user-attachments/assets/a845d78f-b3c0-49b7-b793-2ae4bbbaaec3" alt="" style="width: 400px; height: 200px; object-fit: cover;">
</div>


## 💡 Todo <a name = "todo"></a>

- Introduce more features
- Fix existing bugs

## ⛓️ Dependencie <a name = "dependencies"></a>

- [oxmysql](https://github.com/overextended/oxmysql)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target) or [qb-target](https://github.com/qbcore-framework/qb-target)

## 🚀 Features Scope <a name = "feature_scope"></a>

### Vehicle Mileage Tracking
- Real-time mileage tracking for owned vehicles
- Configurable distance units (kilometers or miles)
- Customizable mileage display position on screen
- Automatic mileage saving to database with configurable autosave interval
- Command to reset vehicle mileage
- Option to track only player-owned vehicles
- Support for multiple vehicle database tables (QBCore, ESX, custom)

### Oil System
- Oil life monitoring based on distance traveled
- Configurable oil change intervals
- Engine damage simulation when oil maintenance is neglected
- Visual warnings for low oil life
- Oil change service interaction for mechanics with progress bar and animation
- Cancelable maintenance procedures

### Spark Plug System
- Spark plug wear tracking based on distance
- Maintenance interval configuration
- Engine misfire simulation when spark plugs are worn
- Spark plug replacement service with progress bar and animation
- Warning notifications for spark plug maintenance
- Cancelable maintenance procedures

### Oil Filter System
- Separate tracking for oil filter life
- Independent oil filter change intervals
- Engine performance impact when filter is worn
- Service option for filter replacement with progress bar and animation
- Warning system for filter maintenance
- Cancelable maintenance procedures

### Air Filter System
- Air filter condition monitoring
- Performance impact on vehicle when filter is dirty:
  - Reduced top speed
  - Decreased acceleration
- Air filter replacement service with progress bar and animation
- Warning notifications for filter maintenance
- Cancelable maintenance procedures

### Tire System
- Tire wear tracking based on distance
- Impact on vehicle handling and grip
- Configurable tire wear rates and grip values
- Tire replacement service with progress bar and animation
- Visual wear indicators and warnings
- Cancelable maintenance procedures

### Brake System
- Progressive brake wear simulation
- Impact on braking efficiency
- Brake maintenance service with progress bar and animation
- Warning system for brake condition
- Configurable wear rates and efficiency loss
- Cancelable maintenance procedures

### Clutch System
- Clutch wear tracking based on gear changes
- Impact on vehicle performance
- Engine stalls chance when clutch is worn out
- Clutch replacement service with progress bar and animation
- Warning system for clutch condition
- Configurable wear rates and performance loss
- Cancelable maintenance procedures

### Suspension System
- Suspension wear tracking and replacement service
- Configurable wear rates and maximum wear values
- Progress bar and animation for suspension service
- Cancelable maintenance procedures

### Mechanic Interactions
1. Approach a vehicle
2. Use the target system (ox_target or qb-target)
3. Available maintenance options:
   - Change Oil
   - Replace Oil Filter
   - Replace Air Filter
   - Change Tires
   - Service Brakes
   - Replace Clutch
   - Service Suspension
4. Each interaction requires appropriate inventory items
5. Progress bars and animations for maintenance actions
6. Cancelable maintenance procedures

### Job Requirements
- Mechanic job required for maintenance (configurable)
- Minimum job grade requirement (configurable)
- Job name configurable in config.lua
- Supports both ox_target and qb-target systems

### Inventory System
- Integrated inventory support for:
  - Spark Plugs
  - Engine Oil
  - Oil Filter
  - Air Filter
  - Tires
  - Brake Parts
  - Suspension Parts
  - Clutch Parts
- Supports multiple inventory systems:
  - ox_inventory
  - qb-inventory
  - Quasar inventory
  - CodeM inventory
  - ESX inventory
- Configurable item weights and descriptions
- Items can be used directly from inventory
- Automatic item removal after use

### Multiple Menu Support
- Supports multiple menu systems:
  - ox_lib
  - QBCore/QBox menu

### HUD Features
- Real-time mileage display
- Configurable position (top-left, top-right, bottom-left, bottom-right)
- Component wear display when using /checkwear command
- Warning notifications for maintenance needs

### Notification System
- Multiple notification system support:
  - QBox
  - QBCore
  - ESX
  - Wizard Notify
  - OkOk Notify
  - ox_lib notify
- Configurable warning intervals
- Multi-language support

### Database Integration
- Automatic mileage saving
- Persistent maintenance history
- Vehicle ownership verification
- Supports multiple vehicle database structures

### Disabled Vehicle Classes
- Option to disable mileage tracking and maintenance for specific vehicle classes such as:
  - Cycles
  - Boats
  - Helicopters
  - Planes
  - Trains
  - Military vehicles
  - Commercial vehicles

### Vehicle Mileage Database UI
- Interactive vehicle mileage database panel accessible in-game
- Displays a list of vehicles with plate numbers and current mileage
- Allows editing of vehicle data including:
  - Mileage
  - Last oil change
  - Last oil filter change
  - Last air filter change
  - Last tire change
  - Last brakes change and brake wear
  - Last clutch change and clutch wear
  - Last suspension change
  - Last spark plug change
- Validation to ensure data consistency (e.g., last change values not exceeding mileage)
- Supports deleting vehicles with user confirmation
- Real-time updates and notifications for successful or failed operations
- Custom confirmation modal for user actions

### Mileage UI Customizer
- Allows players to toggle visibility of mileage and wear displays
- Provides sliders to adjust size of mileage meter and wear bars
- Allows precise positioning of UI elements via X and Y coordinates inputs
- Supports dragging UI elements to reposition them interactively
- Saves player customization settings persistently
- Enhances user experience with customizable and flexible UI layout

## 🏁 Getting Started <a name = "getting_started"></a>

This guide will help you set up the script easily!

### Setting up
1. Download the folder and remove the -main suffix from it. The folder name should be wizard-mileage

### Installing
[GUIDE](https://code-wizards.gitbook.io/codewizards/installation)

### Configuration
1. Open the `config.lua` file in the wizard-mileage folder.
2. Choose your favorite notification system from the list and set it as the default.
3. Choose the preffered distance unit (km or mile).
4. Choose the preffered location for mileage HUD.
5. Change the `Config.VehDB` to your vehicle database table name.
   - `'player_vehicles'` for QBCore & QBox
   - `'owned_vehicles'` for ESX
   - you can change it to your custom table name.
6. Customize other settings as per your preference.
7. Save the `config.lua` file.

## ✍️ Authors <a name = "authors"></a>

- @The_Hs5

## 🌐 Translations <a name = "trans"></a>

- English, Persian: @The_Hs5
- German: @Sascha
- Arabic: @abonan
- French: @junior
- Dutch: @meneer-Duck

## 🤝 Support <a name = "support"></a>
For support, join our Discord server: [CodeWizards Discord](https://discord.gg/ZBvacHyczY)

## License <a name = "license"></a>
This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
