<h1 align="center">Wizard Mileage System</h1>

<p align="center">
    A complete vehicle mileage and maintenance system for FiveM servers. Wizard Mileage System tracks vehicle distance and simulates realistic component wear over time, including oil life, filters, tires, brakes, suspension, clutch, and spark plugs. Regular maintenance is required to keep vehicles performing properly and prevent progressive handling, engine, and performance issues.
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

- Add more maintenance and vehicle behavior features
- Improve existing systems and fix reported issues

## ⛓️ Dependencies <a name = "dependencies"></a>

- Framework: `QBox` or `QBCore` or `ESX` or `ND_Core`
- SQL: [`oxmysql`](https://github.com/overextended/oxmysql)
- Required: [`ox_lib`](https://github.com/overextended/ox_lib) & [`wizard_lib`](https://github.com/CodeWizardsDev/wizard-lib)
- Target: [`ox_target`](https://github.com/overextended/ox_target) or [`qb-target`](https://github.com/qbcore-framework/qb-target)
- Inventory: `ox` or `codem` or `quasar` or `qb` or `esx`
- Menu: `ox` or `QB` or `QBox`
- ProgressBar: `ox` or `QB` or `QBox`
- Notify: `wizard` or `ox` or `qb` or `qbx` or `okok` or `esx`

## 🚀 Features Scope <a name = "feature_scope"></a>

### Vehicle Mileage Tracking

- Tracks vehicle mileage in real time while driving
- Supports both kilometers and miles
- Saves mileage automatically with a configurable autosave interval
- Can be limited to player-owned vehicles only
- Supports configurable vehicle database tables for different frameworks
- Includes commands for mileage reset and mileage database management
- Displays mileage through a configurable in-game UI

### Spark Plug System

- Tracks spark plug wear based on driven distance
- Supports configurable service intervals and warning thresholds
- Can simulate engine misfires when spark plugs are heavily worn
- Includes a mechanic service option for replacing spark plugs
- Uses progress bars and animations during maintenance
- Maintenance actions can be canceled before completion

### Oil System

- Monitors oil life based on vehicle mileage
- Supports configurable oil change intervals
- Can apply engine damage or performance issues when oil is neglected
- Shows warning notifications when oil service is required
- Includes a mechanic oil change interaction
- Uses progress bars, animations, and cancelable service actions

### Oil Filter System

- Tracks oil filter condition separately from engine oil
- Supports independent oil filter service intervals
- Can affect vehicle performance when the filter is worn
- Includes a dedicated oil filter replacement service
- Shows maintenance warnings based on configured thresholds
- Supports progress bars, animations, and cancelable procedures

### Air Filter System

- Monitors air filter condition over time
- Can reduce acceleration and top speed when the filter is dirty
- Includes an air filter replacement interaction
- Supports configurable wear values and warning thresholds
- Uses progress bars and animations for service actions
- Maintenance can be canceled during the process

### Tire System

- Tracks tire wear based on vehicle usage
- Can affect vehicle handling and grip as tires degrade
- Supports configurable tire wear rates and grip impact values
- Includes a tire replacement service
- Provides wear indicators and maintenance warnings
- Supports progress bars, animations, and cancelable service actions

### Brake System

- Simulates progressive brake wear over time
- Can reduce braking efficiency when brakes are worn
- Includes a brake service interaction for mechanics
- Supports configurable wear rates and braking efficiency loss
- Shows warning notifications when brake maintenance is needed
- Uses progress bars, animations, and cancelable procedures

### Suspension System

- Tracks suspension wear and service state
- Can affect vehicle handling when suspension condition drops
- Supports configurable wear rates and maximum wear values
- Includes a suspension replacement service
- Preserves original suspension handling values for proper restoration
- Uses progress bars, animations, and cancelable maintenance actions

### Clutch System

- Tracks clutch wear based on gear changes and vehicle usage
- Can affect vehicle performance when the clutch is worn
- Supports engine stall chance when clutch condition is critical
- Includes a clutch replacement service
- Supports configurable wear rates and performance loss values
- Shows warning notifications and supports cancelable service actions

### Mechanic Interactions

1. Approach a vehicle
2. Use the configured target system, either `ox_target` or `qb-target`
3. Select one of the available maintenance actions:
   - Replace Spark Plugs
   - Change Oil
   - Replace Oil Filter
   - Replace Air Filter
   - Change Tires
   - Service Brakes
   - Service Suspension
   - Replace Clutch
4. Required inventory items are checked before service
5. Progress bars and animations are used during maintenance
6. Service actions can be canceled before completion

### Job Requirements

- Maintenance can be restricted to mechanic jobs
- Supported mechanic jobs and minimum grades are configurable
- Job names can be adjusted from `config.lua`
- Works with supported target systems such as `ox_target` and `qb-target`

### Multiple Menu Support

- Supports multiple menu systems:
  - `ox_lib`
  - `QBCore/QBox` menu

### HUD Features

- Real-time mileage display while driving
- Configurable mileage UI position and size
- Component wear display through the `/checkwear` command
- Warning notifications for components that need maintenance
- Persistent player UI preferences

### Database Integration

- Automatically saves mileage and maintenance values
- Stores persistent vehicle wear and service history
- Supports vehicle ownership verification
- Supports configurable vehicle database structures
- Saves player UI customization settings persistently

### Disabled Vehicle Classes

- Option to disable mileage tracking and maintenance for specific vehicle classes, such as:
  - Cycles
  - Boats
  - Helicopters
  - Planes
  - Trains
  - Military vehicles
  - Commercial vehicles

### Vehicle Mileage Database UI

- In-game panel for managing vehicle mileage records
- Displays registered vehicles with plate numbers and mileage values
- Allows editing of vehicle maintenance data, including:
  - Mileage
  - Last spark plug change
  - Last oil change
  - Last oil filter change
  - Last air filter change
  - Last tire change
  - Last brakes change and brake wear
  - Last suspension change
  - Last clutch change and clutch wear
- Validates values to prevent invalid maintenance data
- Supports vehicle deletion with confirmation
- Provides notifications for successful and failed actions
- Updates database values directly from the UI

### Mileage UI Customizer

- Allows players to toggle mileage and wear display visibility
- Includes size controls for the mileage display and wear UI
- Supports precise X/Y positioning for UI elements
- Saves each player's UI settings persistently
- Helps players adjust the HUD layout to fit their screen and preference

### Localization

- Supports translation files for multiple languages
- Loads the selected language from `ui_config.json`
- Uses locale JSON files for UI labels, notifications, warnings, and errors
- Makes it easy to add or modify supported languages

### Performance

- Uses client-side cached values to reduce unnecessary updates
- Syncs changed wear data efficiently
- Preserves original vehicle handling values where needed
- Keeps NUI updates focused on active UI state
- Designed to run cleanly during normal gameplay

## 🏁 Getting Started <a name = "getting_started"></a>

This guide will help you set up the script easily.

### Setting up

1. Download the folder and remove the `-main` suffix from it.
2. The final folder name should be:
```txt
wizard-mileage
```

3. Place the resource inside your server `resources` folder.

4. Add the resource to your `server.cfg`:

```cfg
ensure oxmysql  
ensure ox_lib  
ensure wizard-lib  
ensure wizard-mileage
```

### Installing

[GUIDE](https://code-wizards.gitbook.io/codewizards/mileage-system/installation)

### Configuration

[GUIDE](https://code-wizards.gitbook.io/codewizards/mileage-system/configuration)

## ✍️ Authors

- @The_Hs5

## 🌐 Translations

- English, Persian: @The_Hs5
- German: @Sascha
- Arabic: @abonan
- French: @junior
- Dutch: @meneer-Duck
- Other Languages: AI

## 🤝 Support

For support, join our Discord server: 
https://discord.gg/ZBvacHyczY

## License

This project is licensed under the GNU General Public License v3.0 
See the LICENSE file for details
