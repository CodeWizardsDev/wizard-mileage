<h1 align="center">Wizard Mileage  System</h1>

<p align="center"> A comprehensive vehicle maintenance and mileage tracking system for FiveM servers that simulates realistic vehicle wear and tear, including oil life, filters, tires, and brake conditions. The system tracks vehicle mileage and component wear, requiring regular maintenance to maintain optimal vehicle performance.
    <br> 
</p>

## 📝 Table of Contents

- [ShowCase](#showcase)
- [Todo](#todo)
- [Dependencies](#dependencies)
- [Features Scope](#feature_scope)
- [Setting up](#getting_started)
- [Authors](#authors)

## 🖼️ ShowCase <a name = "showcase"></a>
<div style="display: flex; flex-wrap: wrap; gap: 10px; justify-content: center;">
    <img src="https://github.com/user-attachments/assets/7dc20e40-f1bc-4ae3-94fb-d9da5a9dad14" alt="" style="width: 400px; height: auto; object-fit: cover;">
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
- Automatic mileage saving to database
- Command to reset vehicle mileage
### Oil System
- Oil life monitoring based on distance traveled
- Configurable oil change intervals
- Engine damage simulation when oil maintenance is neglected
- Visual warnings for low oil life
- Oil change service interaction for mechanics
### Oil Filter System
- Separate tracking for oil filter life
- Independent oil filter change intervals
- Engine performance impact when filter is worn
- Service option for filter replacement
- Warning system for filter maintenance
### Air Filter System
- Air filter condition monitoring
- Performance impact on vehicle when filter is dirty:
  - Reduced top speed
  - Decreased acceleration
- Air filter replacement service
- Warning notifications for filter maintenance
### Tire System
- Tire wear tracking based on distance
- Impact on vehicle handling and grip
- Configurable tire wear rates
- Tire replacement service
- Visual wear indicators and warnings
### Brake System
- Progressive brake wear simulation
- Impact on braking efficiency
- Brake maintenance service
- Warning system for brake condition
- Configurable wear rates and efficiency loss
### Clutch System
- Clutch wear tracking based on gear changes
- Impact on vehicle performance
- Engine Stalls when clutch is worn out
- Clutch replacement service
- Warning system for clutch condition
- Configurable wear rates and performance loss
### Mechanic Interactions
1. Approach a vehicle
2. Use the target system (ox_target or qb-target)
3. Available maintenance options:
   - Change Oil
   - Replace Oil Filter
   - Replace Air Filter
   - Change Tires
   - Service Brakes
### HUD Features
- Real-time mileage display
- Configurable position (top-left, top-right, bottom-left, bottom-right)
- Component wear display when using /checkwear
- Warning notifications for maintenance needs
### Job Requirements
- If enabled, only players with the mechanic job can perform maintenance
- Job name configurable in config.lua
- Supports both ox_target and qb-target systems
### Maintenance Interface
- Target-based interaction system
- Progress bars for maintenance actions
- Cancelable maintenance procedures
- Animation support for maintenance actions
- Job-based restrictions for mechanics
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

## 🏁 Getting Started <a name = "getting_started"></a>

This guide will help you set up the script easily!

### Setting up
1. Download the folder and remove the -main suffix from it. The folder name should be wizard-mileage

### Installing
1. Copy the folder and paste it into your resources folder.
2. Add the following code to your server.cfg. Make sure to place it at the top of the resources list to ensure it's loaded before other resources:
```
ensure wizard-mileage
```
3. Import the `import.sql` file to your SQL Database

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
