let translations = {};

async function fetchConfig() {
    try {
        const response = await fetch('../config/ui_config.json');
        const config = await response.json();
        currentLocale = `${config.lang}`;
        initialize();
    } catch (error) {
        console.error('^9WIZARD DEBUG: ^7Error fetching config:', error);
    }
}

async function loadTranslations(locale) {
    if (locale === currentLocale && Object.keys(translations).length > 0) return; // Prevent redundant fetch
    try {
        const response = await fetch(`../locales/${locale}.json`);
        translations = await response.json();
    } catch (error) {
        console.error(`^9WIZARD DEBUG: ^7Failed to load translations for ^6${locale}:^7`, error);
    }
}

function getTranslation(key) {
    if (!translations) return key; // Check if translations are loaded
    const parts = key.split('.');
    let obj = translations;
    for (const part of parts) {
        if (obj && typeof obj === 'object' && part in obj) {
            obj = obj[part];
        } else {
            console.warn(`^9WIZARD DEBUG: ^7Translation key ^6'${key}' ^7not found at part ^6'${part}'^7`);
            return key;
        }
    }
    return typeof obj === 'string' ? obj : key;
}

async function initialize() {
    await loadTranslations(currentLocale);
    
    // Apply CSS variables
    applyCSSVariables();
    const elementsList = {
        mileageElement: document.getElementById('mileage'),
        mileageValue: document.getElementById('mileageValue'),
        unitLabel: document.getElementById('unitLabel'),
        saveVehBtn: document.getElementById('saveVehicleBtn'),
        saveBtn: document.getElementById('saveBtn'),
        deleteVehBtn: document.getElementById('deleteVehicleBtn'),
        cancelEditBtn: document.getElementById('cancelEditBtn'),
        closeBtn: document.getElementById('closeDatabaseMenuBtn'),
        closeBtn2: document.getElementById('closeUIButton'),
        spW: document.getElementById('spw'),
        oW: document.getElementById('ow'),
        fW: document.getElementById('fw'),
        afW: document.getElementById('afw'),
        tW: document.getElementById('tw'),
        bW: document.getElementById('bw'),
        sW: document.getElementById('sw'),
        cW: document.getElementById('cw'),
        mmUI: document.getElementById('mmui'),
        smm: document.getElementById('smm'),
        sz: document.getElementById('sz'),
        sz2: document.getElementById('sz2'),
        posxy: document.getElementById('posxy'),
        posxy2: document.getElementById('posxy2'),
        cwUI: document.getElementById('cwui'),
        vmDB: document.getElementById('vmdb'),
        evD: document.getElementById('evd'),
        pTB: document.getElementById('ptb'),
        mTB: document.getElementById('mtb'),
        aTB: document.getElementById('atb'),
        pOP: document.getElementById('pop'),
        mOP: document.getElementById('mop'),
        loOP: document.getElementById('locop'),
        lfOP: document.getElementById('lfcop'),
        laOP: document.getElementById('lacop'),
        ltOP: document.getElementById('ltcop'),
        lbOP: document.getElementById('lbcop'),
        bwOP: document.getElementById('bwcop'),
        lcOP: document.getElementById('lccop'),
        cwOP: document.getElementById('cwcop'),
        lsOP: document.getElementById('lscop'),
        lpOP: document.getElementById('lpcop'),
    };
    elementsList.mileageElement.innerHTML = `${getTranslation('ui.mileage')}: `;
    elementsList.mileageElement.append(elementsList.mileageValue, elementsList.unitLabel);
    const translations = [
        { key: 'ui.save', elementsList: [elementsList.saveVehBtn, elementsList.saveBtn] },
        { key: 'ui.delete', elementsList: [elementsList.deleteVehBtn] },
        { key: 'ui.cancel', elementsList: [elementsList.cancelEditBtn] },
        { key: 'ui.close', elementsList: [elementsList.closeBtn, elementsList.closeBtn2] },
        { key: 'ui.spark_plug', elementsList: [elementsList.spW] },
        { key: 'ui.oil', elementsList: [elementsList.oW] },
        { key: 'ui.filter', elementsList: [elementsList.fW] },
        { key: 'ui.air_filter', elementsList: [elementsList.afW] },
        { key: 'ui.tire', elementsList: [elementsList.tW] },
        { key: 'ui.brake', elementsList: [elementsList.bW] },
        { key: 'ui.suspension', elementsList: [elementsList.sW] },
        { key: 'ui.clutch', elementsList: [elementsList.cW] },
        { key: 'ui.mileage_meter_ui', elementsList: [elementsList.mmUI] },
        { key: 'ui.show_mileage_meter', elementsList: [elementsList.smm] },
        { key: 'ui.size', elementsList: [elementsList.sz, elementsList.sz2] },
        { key: 'ui.position', elementsList: [elementsList.posxy, elementsList.posxy2] },
        { key: 'ui.checkwear_ui', elementsList: [elementsList.cwUI] },
        { key: 'ui.vehicle_mileage_db', elementsList: [elementsList.vmDB] },
        { key: 'ui.edit_veh_data', elementsList: [elementsList.evD] },
        { key: 'ui.plate', elementsList: [elementsList.pTB, elementsList.pOP] },
        { key: 'ui.mileage', elementsList: [elementsList.mTB, elementsList.mOP] },
        { key: 'ui.last_oil_change', elementsList: [elementsList.loOP] },
        { key: 'ui.last_filter_change', elementsList: [elementsList.lfOP] },
        { key: 'ui.last_air_filter_change', elementsList: [elementsList.laOP] },
        { key: 'ui.last_tire_change', elementsList: [elementsList.ltOP] },
        { key: 'ui.last_brake_change', elementsList: [elementsList.lbOP] },
        { key: 'ui.brake_wear', elementsList: [elementsList.bwOP] },
        { key: 'ui.last_clutch_change', elementsList: [elementsList.lcOP] },
        { key: 'ui.clutch_wear', elementsList: [elementsList.cwOP] },
        { key: 'ui.last_sus_change', elementsList: [elementsList.lsOP] },
        { key: 'ui.last_plugs_change', elementsList: [elementsList.lpOP] },
    ];
    translations.forEach(({ key, elementsList }) => {
        const translation = getTranslation(key);
        elementsList.forEach(el => {
            if (el === elementsList.pOP || el === elementsList.mOP) {
                el.innerHTML = `${translation}: `;
            } else {
                el.textContent = translation;
            }
        });
    });
}

async function applyCSSVariables() {
    const response = await fetch('../config/ui_config.json');
    const config = await response.json();
    const cssVariables = config.cssVariables;
    for (const [key, value] of Object.entries(cssVariables)) {
        document.documentElement.style.setProperty(`--${key}`, value);
    }
}

fetchConfig()

let WEAR_COMPONENTS = {
    sparkPlug: {
        id: 'sparkPlugWear',
        label: 'spw',
        icon: 'fas fa-bolt',
        type: 'engine'
    },
    oil: {
        id: 'oilWear',
        label: 'ow',
        icon: 'fas fa-oil-can',
        type: 'engine'
    },
    filter: {
        id: 'filterWear',
        label: 'fw',
        icon: 'fas fa-filter',
        type: 'engine'
    },
    airFilter: {
        id: 'airFilterWear',
        label: 'afw',
        icon: 'fas fa-wind',
        type: 'engine'
    },
    tire: {
        id: 'tireWear',
        label: 'tw',
        icon: 'fa-regular fa-circle',
        type: 'tires'
    },
    brake: {
        id: 'brakeWear',
        label: 'bw',
        icon: 'fas fa-record-vinyl',
        type: 'brakes'
    },
    suspension: {
        id: 'suspensionWear',
        label: 'sw',
        icon: 'fas fa-car-burst',
        type: 'suspension'
    },
    clutch: {
        id: 'clutchWear',
        label: 'cw',
        icon: 'fas fa-cog',
        type: 'transmission'
    }
};

const HEALTH_STATUS = {
    excellent: {
        threshold: 75,
        class: 'health-excellent',
        labelKey: 'ui.excellent'
    },
    good: {
        threshold: 50,
        class: 'health-good',
        labelKey: 'ui.good'
    },
    warning: {
        threshold: 25,
        class: 'health-warning',
        labelKey: 'ui.warning'
    },
    critical: {
        threshold: 0,
        class: 'health-critical pulse',
        labelKey: 'ui.critical'
    },
    disabled: {
        class: 'health-disabled',
        labelKey: 'ui.disabled'
    }
};

function createWearBars() {
    const template = document.getElementById('wearBarTemplate');
    const container = document.getElementById('wearDisplay');

    Object.values(WEAR_COMPONENTS).forEach(({ id, label, icon, type }) => {
        const wearBar = template.content.cloneNode(true).firstElementChild;
        wearBar.classList.add(type);

        const wearIcon = wearBar.querySelector('.wear-icon');
        wearIcon.innerHTML = `<i class="${icon}"></i>`;

        // Use translation for component name
        wearBar.querySelector('.component-name').id = label;
        wearBar.querySelector('.progress').id = id;
        wearBar.querySelector('.percent').id = `${id}Percent`;
        container.appendChild(wearBar);
    });
}

function getHealthStatus(value) {
    for (const [status, { threshold, class: statusClass, labelKey }] of Object.entries(HEALTH_STATUS)) {
        if (typeof threshold !== 'undefined' && value >= threshold) {
            return {
                class: statusClass,
                label: getTranslation(labelKey)
            };
        }
    }
    // Fallback
    return {
        class: HEALTH_STATUS.critical.class,
        label: getTranslation(HEALTH_STATUS.critical.labelKey)
    };
}

function getDisabledHealthStatus() {
    return {
        class: HEALTH_STATUS.disabled.class,
        label: getTranslation(HEALTH_STATUS.disabled.labelKey)
    };
}

function updateProgressBar(barId, value) {
    const bar = document.getElementById(barId);
    const percent = document.getElementById(`${barId}Percent`);
    if (!bar || !percent) return;

    if (value === null || typeof value === 'undefined') {
        bar.style.width = `100%`;
        percent.textContent = getTranslation('ui.disabled');
        const wearBar = bar.closest('.wear-bar');
        const healthStatus = wearBar.querySelector('.health-status');
        const {
            class: statusClass,
            label
        } = getDisabledHealthStatus();
        healthStatus.className = `health-status ${statusClass}`;
        healthStatus.textContent = label;
        wearBar.classList.remove('health-excellent', 'health-good', 'health-warning', 'health-critical', 'pulse');
        wearBar.classList.add(statusClass);
    } else {
        bar.style.width = `${value}%`;
        percent.textContent = `${value}%`;

        const wearBar = bar.closest('.wear-bar');
        const healthStatus = wearBar.querySelector('.health-status');
        const {
            class: statusClass,
            label
        } = getHealthStatus(value);

        healthStatus.className = `health-status ${statusClass}`;
        healthStatus.textContent = label;

        wearBar.classList.remove('health-excellent', 'health-good', 'health-warning', 'health-critical', 'pulse');
        wearBar.classList.add(statusClass.split(' ')[0]);
        if (statusClass.includes('pulse')) {
            wearBar.classList.add('pulse');
        }
    }
}

window.addEventListener('load', createWearBars);

document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        fetch(`https://${GetParentResourceName()}/closeMenu`, {
            method: 'POST'
        });
        const customizationUI = document.getElementById('customizationUI');
        if (customizationUI) {
            customizationUI.style.display = 'none';
        }
        document.getElementById('wearDisplay').style.display = 'none';
        document.body.style.background = '#00000000';
        const databaseMenu = document.getElementById('databaseMenu');
        if (databaseMenu) {
            databaseMenu.style.display = 'none';
        }
    }
});

let customConfirmModal, customConfirmMessage, customConfirmOk, customConfirmCancel;

document.addEventListener('DOMContentLoaded', () => {
    customConfirmModal = document.getElementById('customConfirmModal');
    customConfirmMessage = document.getElementById('customConfirmMessage');
    customConfirmOk = document.getElementById('customConfirmOk');
    customConfirmCancel = document.getElementById('customConfirmCancel');
});

function showCustomConfirm(message) {
    return new Promise((resolve) => {
        if (!customConfirmMessage || !customConfirmModal) {
            resolve(false);
            return;
        }
        customConfirmMessage.textContent = message;
        customConfirmModal.style.display = 'flex';

        function onOk() {
            cleanup();
            resolve(true);
        }

        function onCancel() {
            cleanup();
            resolve(false);
        }

        function cleanup() {
            customConfirmOk.removeEventListener('click', onOk);
            customConfirmCancel.removeEventListener('click', onCancel);
            customConfirmModal.style.display = 'none';
        }

        customConfirmOk.addEventListener('click', onOk);
        customConfirmCancel.addEventListener('click', onCancel);
    });
}

function registerDatabaseMenuEventListeners() {
    const vehicleEditForm = document.getElementById('vehicleEditForm');
    const deleteVehicleBtn = document.getElementById('deleteVehicleBtn');
    const cancelEditBtn = document.getElementById('cancelEditBtn');
    const closeDatabaseMenuBtn = document.getElementById('closeDatabaseMenuBtn');

    if (vehicleEditForm) {
        vehicleEditForm.addEventListener('submit', function(event) {
            event.preventDefault();
            const plate = document.getElementById('editPlate').value;
            const mileage = parseFloat(document.getElementById('editMileage').value);
            const lastOilChange = parseFloat(document.getElementById('editLastOilChange').value);
            const lastOilFilterChange = parseFloat(document.getElementById('editLastOilFilterChange').value);
            const lastAirFilterChange = parseFloat(document.getElementById('editLastAirFilterChange').value);
            const lastTireChange = parseFloat(document.getElementById('editLastTireChange').value);
            const lastBrakesChange = parseFloat(document.getElementById('editLastBrakesChange').value);
            const brakeWear = parseFloat(document.getElementById('editBrakeWear').value);
            const lastClutchChange = parseFloat(document.getElementById('editLastClutchChange').value);
            const clutchWear = parseFloat(document.getElementById('editClutchWear').value);
            const lastSuspensionChange = parseFloat(document.getElementById('editLastSuspensionChange').value);
            const lastSparkPlugChange = parseFloat(document.getElementById('editLastSparkPlugChange').value);

            if (!plate || isNaN(mileage) || mileage < 0) {
                fetch(`https://${GetParentResourceName()}/notify`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        message: getTranslation('ui.enter_valid_plate_mileage'),
                        type: 'error'
                    })
                })
                return;
            }

            const validations = [
                { value: lastOilChange, label: getTranslation('ui.last_oil_change') },
                { value: lastOilFilterChange, label: getTranslation('ui.last_oil_filter_change') },
                { value: lastAirFilterChange, label: getTranslation('ui.last_air_filter_change') },
                { value: lastTireChange, label: getTranslation('ui.last_tire_change') },
                { value: lastBrakesChange, label: getTranslation('ui.last_brakes_change') },
                { value: lastClutchChange, label: getTranslation('ui.last_clutch_change') },
                { value: lastSuspensionChange, label: getTranslation('ui.last_suspension_change') },
                { value: lastSparkPlugChange, label: getTranslation('ui.last_spark_plug_change') }
            ];

            for (const { value, label } of validations) {
                if (!isNaN(value) && value > mileage) {
                    fetch(`https://${GetParentResourceName()}/notify`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            message: getTranslation('ui.must_be_equal_or_lower').replace('{label}', label),
                            type: 'error'
                        })
                    });
                    return;
                }
            }

            const vehicleData = {
                plate: plate,
                mileage: mileage,
                last_oil_change: isNaN(lastOilChange) ? 0 : lastOilChange,
                last_oil_filter_change: isNaN(lastOilFilterChange) ? 0 : lastOilFilterChange,
                last_air_filter_change: isNaN(lastAirFilterChange) ? 0 : lastAirFilterChange,
                last_tire_change: isNaN(lastTireChange) ? 0 : lastTireChange,
                last_brakes_change: isNaN(lastBrakesChange) ? 0 : lastBrakesChange,
                brake_wear: isNaN(brakeWear) ? 0 : brakeWear,
                last_clutch_change: isNaN(lastClutchChange) ? 0 : lastClutchChange,
                clutch_wear: isNaN(clutchWear) ? 0 : clutchWear,
                last_suspension_change: isNaN(lastSuspensionChange) ? 0 : lastSuspensionChange,
                last_spark_plug_change: isNaN(lastSparkPlugChange) ? 0 : lastSparkPlugChange
            };
            fetch(`https://${GetParentResourceName()}/updateVehicleData`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    vehicle: vehicleData
                })
            }).then(response => response.json()).then(data => {
                if (data.success) {
                    fetch(`https://${GetParentResourceName()}/notify`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            message: getTranslation('ui.vehicle_data_updated'),
                            type: 'success'
                        })
                    })
                    closeVehicleEdit();
                    fetch(`https://${GetParentResourceName()}/requestVehicleList`, {
                        method: 'POST'
                    }).then(res => res.json()).then(resData => {
                        window.postMessage({
                            type: 'vehicleList',
                            vehicles: resData.vehicles
                        }, '*');
                    });
                } else {
                    fetch(`https://${GetParentResourceName()}/notify`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            message: getTranslation('ui.failed_update_vehicle_data') + (data.error ? ': ' + data.error : ''),
                            type: 'error'
                        })
                    })
                }
            });
        });
    }

    if (deleteVehicleBtn) {
        deleteVehicleBtn.addEventListener('click', async function() {
            const plate = document.getElementById('editPlate').value;
            if (!plate) {
                fetch(`https://${GetParentResourceName()}/notify`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        message: 'Invalid Plate',
                        type: 'error'
                    })
                })
                return;
            }
            const confirmed = await showCustomConfirm(getTranslation('ui.confirm_delete_vehicle'));
            if (!confirmed) {
                return;
            }
            fetch(`https://${GetParentResourceName()}/deleteVehicle`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    plate: plate
                })
            }).then(response => response.json()).then(data => {
                if (data.success) {
                    fetch(`https://${GetParentResourceName()}/notify`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            message: getTranslation('ui.vehicle_deleted_success'),
                            type: 'success'
                        })
                    })
                    closeVehicleEdit();
                    const databaseMenu = document.getElementById('databaseMenu');
                    if (databaseMenu) {
                        databaseMenu.style.display = 'none';
                    }
                    fetch(`https://${GetParentResourceName()}/closeMenu`, {
                        method: 'POST'
                    });
                } else {
                    alert(getTranslation('ui.failed_delete_vehicle') + (data.error ? ': ' + data.error : ''));
                }
            });
        });
    }

    if (cancelEditBtn) {
        cancelEditBtn.addEventListener('click', function() {
            closeVehicleEdit();
        });
    }

    if (closeDatabaseMenuBtn) {
        closeDatabaseMenuBtn.addEventListener('click', function() {
            const databaseMenu = document.getElementById('databaseMenu');
            if (databaseMenu) {
                databaseMenu.style.display = 'none';
            }
            fetch(`https://${GetParentResourceName()}/closeMenu`, {
                method: 'POST'
            });
        });
    }
}

window.addEventListener('DOMContentLoaded', () => {
    registerDatabaseMenuEventListeners();
});

function formatNumberWithCommas(x) {
    return x.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

window.addEventListener('message', ({
    data
}) => {
    const handlers = {
        updateMileage: () => {
            if (data.mileage < 1000) {
                document.getElementById('mileageValue').textContent = data.mileage.toFixed(2);
            } else {
                document.getElementById('mileageValue').textContent = formatNumberWithCommas(Math.floor(data.mileage));
            }
            let unitKey = '';
            if (data.unit.toLowerCase() === 'km') {
                unitKey = 'ui.unit_km';
            } else if (data.unit.toLowerCase().startsWith('mile')) {
                unitKey = 'ui.unit_miles';
            }
            if (unitKey) {
                document.getElementById('unitLabel').textContent = getTranslation(unitKey);
            } else {
                document.getElementById('unitLabel').textContent = data.unit;
            }
        },
        toggleMileage: () => {
            document.getElementById('mileageDisplay').style.display = data.visible ? 'block' : 'none';
        },
        updateWear: () => {
            if (data.showUI == true) {
                const wearDisplay = document.getElementById('wearDisplay');
                wearDisplay.style.display = 'block';

                // Update the mileage title in the wearDisplay UI
                const wearMileageTitle = document.getElementById('wearMileageTitle');
                if (wearMileageTitle && typeof data.mileage === 'number' && typeof data.unit === 'string') {
                    let unitKey = '';
                    if (data.unit.toLowerCase() === 'km') {
                        unitKey = 'ui.unit_km';
                    } else if (data.unit.toLowerCase().startsWith('mile')) {
                        unitKey = 'ui.unit_miles';
                    }
                    let unitLabel = unitKey ? getTranslation(unitKey) : data.unit;
                    let mileageLabel = getTranslation('ui.mileage');
                    wearMileageTitle.textContent = `${mileageLabel} ${data.mileage.toFixed(2)} ${unitLabel}`;
                }
            }

            const wearTypes = [{
                    key: 'sparkPlugPercentage',
                    id: 'sparkPlugWear'
                },
                {
                    key: 'oilPercentage',
                    id: 'oilWear'
                },
                {
                    key: 'filterPercentage',
                    id: 'filterWear'
                },
                {
                    key: 'airFilterPercentage',
                    id: 'airFilterWear'
                },
                {
                    key: 'tirePercentage',
                    id: 'tireWear'
                },
                {
                    key: 'brakePercentage',
                    id: 'brakeWear'
                },
                {
                    key: 'suspensionPercentage',
                    id: 'suspensionWear'
                },
                {
                    key: 'clutchPercentage',
                    id: 'clutchWear'
                }
            ];

            wearTypes.forEach(({
                key,
                id
            }) => {
                if (typeof data[key] === 'undefined') {
                    const bar = document.getElementById(id);
                    const percent = document.getElementById(`${id}Percent`);
                    const wearBar = bar ? bar.closest('.wear-bar') : null;
                    if (bar) {
                        bar.style.width = `0%`;
                        bar.style.backgroundColor = 'gray';
                    }
                    if (percent) percent.parentNode.removeChild(percent);
                    if (wearBar) {
                        const wearIcon = wearBar.querySelector('.wear-icon');
                        if (wearIcon) {
                            wearIcon.style.backgroundColor = 'gray';
                            wearIcon.style.color = '#888';
                        }
                        const healthStatus = wearBar.querySelector('.health-status');
                        if (healthStatus) {
                            healthStatus.className = 'health-status health-disabled';
                            healthStatus.textContent = getTranslation('ui.disabled');
                            healthStatus.style.color = 'red';
                        }
                        const statusIndicator = wearBar.querySelector('.status-indicator');
                        if (statusIndicator) {
                            statusIndicator.style.background = '#888';
                        }
                    }
                } else {
                    updateProgressBar(id, data[key]);
                }
            });

            const mileageIcon = document.getElementById('mileageIcon');
            if (!mileageIcon) return;

            const wearValues = [
                data.oilPercentage,
                data.filterPercentage,
                data.airFilterPercentage,
                data.tirePercentage,
                data.brakePercentage,
                data.suspensionPercentage,
                data.clutchPercentage
            ].filter(v => typeof v === 'number');

            if (wearValues.length === 0) {
                mileageIcon.className = 'mileage-icon';
                return;
            }

            const minWear = Math.min(...wearValues);

            mileageIcon.className = 'mileage-icon';
            if (minWear <= 5) {
                mileageIcon.classList.add('flashing');
            } else if (minWear <= 10) {
                mileageIcon.classList.add('red');
            } else if (minWear <= 50) {
                mileageIcon.classList.add('yellow');
            }
        },
        updateCustomization: () => {
            const customizationUI = document.getElementById('customizationUI');
            if (!customizationUI) return;

            document.getElementById('mileageVisible').checked = data.mileageVisible;

            document.getElementById('mileageSize').value = data.mileageSize;
            document.getElementById('checkwearSize').value = data.checkwearSize;

            document.getElementById('mileagePosX').value = data.mileagePosX;
            document.getElementById('mileagePosY').value = data.mileagePosY;
            document.getElementById('checkwearPosX').value = data.checkwearPosX;
            document.getElementById('checkwearPosY').value = data.checkwearPosY;

            document.getElementById('mileageDisplay').style.transform = `scale(${data.mileageSize})`;
            document.getElementById('wearDisplay').style.transform = `scale(${data.checkwearSize})`;

            const mileageDisplay = document.getElementById('mileageDisplay');

            const wearDisplay = document.getElementById('wearDisplay');

            mileageDisplay.style.position = 'fixed';
            mileageDisplay.style.left = `${data.mileagePosX}px`;
            mileageDisplay.style.top = `${data.mileagePosY}px`;

            wearDisplay.style.position = 'fixed';
            wearDisplay.style.left = `${data.checkwearPosX}px`;
            wearDisplay.style.top = `${data.checkwearPosY}px`;
        },
        openDatabaseMenu: () => {
            const databaseMenu = document.getElementById('databaseMenu');
            if (databaseMenu) {
                databaseMenu.style.display = 'block';
            }
        },
        vehicleList: () => {
            const vehicleListBody = document.getElementById('vehicleListBody');
            if (!vehicleListBody) return;
            vehicleListBody.innerHTML = '';
            if (!data.vehicles || data.vehicles.length === 0) {
                const row = document.createElement('tr');
                const cell = document.createElement('td');
                cell.colSpan = 3;
                cell.textContent = getTranslation('ui.no_vehicles_found');
                row.appendChild(cell);
                vehicleListBody.appendChild(row);
                return;
            }
            data.vehicles.forEach(vehicle => {
                const row = document.createElement('tr');
                const plateCell = document.createElement('td');
                plateCell.textContent = vehicle.plate || '';
                const mileageCell = document.createElement('td');
                mileageCell.textContent = vehicle.mileage !== undefined ? vehicle.mileage.toFixed(2) : '';
                const actionsCell = document.createElement('td');
                const editBtn = document.createElement('button');
                editBtn.textContent = getTranslation('ui.edit');
                editBtn.classList.add('edit-button');
                editBtn.addEventListener('click', () => {
                    openVehicleEdit(vehicle);
                });
                actionsCell.appendChild(editBtn);
                const deleteBtn = document.createElement('button');
                deleteBtn.textContent = getTranslation('ui.delete');
                deleteBtn.classList.add('delete-button');
                deleteBtn.addEventListener('click', async () => {
                    const confirmed = await showCustomConfirm(getTranslation('ui.confirm_delete_vehicle'));
                    if (!confirmed) {
                        return;
                    }
                    fetch(`https://${GetParentResourceName()}/deleteVehicle`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            plate: vehicle.plate
                        })
                    }).then(response => response.json()).then(data => {
                        if (data.success) {
                            fetch(`https://${GetParentResourceName()}/notify`, {
                                method: 'POST',
                                headers: {
                                    'Content-Type': 'application/json'
                                },
                                body: JSON.stringify({
                                    message: getTranslation('ui.vehicle_deleted_success'),
                                    type: 'success'
                                })
                            });
                            const databaseMenu = document.getElementById('databaseMenu');
                            if (databaseMenu) {
                                databaseMenu.style.display = 'none';
                            }
                            fetch(`https://${GetParentResourceName()}/closeMenu`, {
                                method: 'POST'
                            });
                        } else {
                            alert(getTranslation('ui.failed_delete_vehicle') + (data.error ? ': ' + data.error : ''));
                        }
                    });
                });
                actionsCell.appendChild(deleteBtn);
                row.appendChild(plateCell);
                row.appendChild(mileageCell);
                row.appendChild(actionsCell);
                vehicleListBody.appendChild(row);
            });
        }
    };

    if (handlers[data.type]) {
        handlers[data.type]();
    }
});

function openVehicleEdit(vehicle) {
    const databaseMenu = document.getElementById('databaseMenu');
    const vehicleEditContainer = document.getElementById('vehicleEditContainer');
    const vehicleListContainer = document.getElementById('vehicleListContainer');
    if (!databaseMenu || !vehicleEditContainer || !vehicleListContainer) return;

    vehicleListContainer.style.display = 'none';
    vehicleEditContainer.style.display = 'block';

    document.getElementById('editPlate').value = vehicle.plate || '';
    document.getElementById('editMileage').value = vehicle.mileage !== undefined ? vehicle.mileage.toFixed(2) : '';

    document.getElementById('editLastOilChange').value = vehicle.last_oil_change !== undefined ? vehicle.last_oil_change.toFixed(2) : '';
    document.getElementById('editLastOilFilterChange').value = vehicle.last_oil_filter_change !== undefined ? vehicle.last_oil_filter_change.toFixed(2) : '';
    document.getElementById('editLastAirFilterChange').value = vehicle.last_air_filter_change !== undefined ? vehicle.last_air_filter_change.toFixed(2) : '';
    document.getElementById('editLastTireChange').value = vehicle.last_tire_change !== undefined ? vehicle.last_tire_change.toFixed(2) : '';
    document.getElementById('editLastBrakesChange').value = vehicle.last_brakes_change !== undefined ? vehicle.last_brakes_change.toFixed(2) : '';
    document.getElementById('editBrakeWear').value = vehicle.brake_wear !== undefined ? vehicle.brake_wear.toFixed(2) : '';
    document.getElementById('editLastClutchChange').value = vehicle.last_clutch_change !== undefined ? vehicle.last_clutch_change.toFixed(2) : '';
    document.getElementById('editClutchWear').value = vehicle.clutch_wear !== undefined ? vehicle.clutch_wear.toFixed(2) : '';
    document.getElementById('editLastSuspensionChange').value = vehicle.last_suspension_change !== undefined ? vehicle.last_suspension_change.toFixed(2) : '';
    document.getElementById('editLastSparkPlugChange').value = vehicle.last_spark_plug_change !== undefined ? vehicle.last_spark_plug_change.toFixed(2) : '';
}


function closeVehicleEdit() {
    const vehicleEditContainer = document.getElementById('vehicleEditContainer');
    const vehicleListContainer = document.getElementById('vehicleListContainer');
    if (!vehicleEditContainer || !vehicleListContainer) return;

    vehicleEditContainer.style.display = 'none';
    vehicleListContainer.style.display = 'block';
}

window.addEventListener('message', function(event) {
    if (event.data.type === 'setPlayerSettings') {
        const settings = event.data.settings || {};
        document.getElementById('mileageVisible').checked = settings.mileage_visible !== false;
        document.getElementById('mileageSize').value = settings.mileage_size || 1.0;
        document.getElementById('checkwearSize').value = settings.checkwear_size || 1.0;
        document.getElementById('mileagePosX').value = settings.mileage_pos_x || 0.0;
        document.getElementById('mileagePosY').value = settings.mileage_pos_y || 0.0;
        document.getElementById('checkwearPosX').value = settings.checkwear_pos_x || 0.0;
        document.getElementById('checkwearPosY').value = settings.checkwear_pos_y || 0.0;
    } else if (event.data.type === 'openCustomization') {
        const customizationUI = document.getElementById('customizationUI');
        if (customizationUI) {
            customizationUI.style.display = 'block';
        }
        const wearDisplay = document.getElementById('wearDisplay');
        wearDisplay.style.display = 'block';
        document.body.style.background = '#000000b7';

        const wearTypes = [
            'sparkPlugWear',
            'oilWear',
            'filterWear',
            'airFilterWear',
            'tireWear',
            'brakeWear',
            'suspensionWear',
            'clutchWear'
        ];

        let animationValue = 0;
        let animationDirection = 1;
        let animationFrame = null;

        function getStatusForValue(value) {
            if (value >= 75) {
                return {
                    class: 'health-excellent',
                    label: 'ui.excellent'
                };
            } else if (value >= 50) {
                return {
                    class: 'health-good',
                    label: 'ui.good'
                };
            } else if (value >= 25) {
                return {
                    class: 'health-warning',
                    label: 'ui.warning'
                };
            } else {
                return {
                    class: 'health-critical pulse',
                    label: 'ui.critical'
                };
            }
        }

        function animateWear() {
            if (!window._animationActive) return;

            animationValue += animationDirection * 0.2;
            if (animationValue >= 100) {
                animationValue = 100;
                animationDirection = -1;
            } else if (animationValue <= 0) {
                animationValue = 0;
                animationDirection = 1;
            }

            wearTypes.forEach(id => {
                const bar = document.getElementById(id);
                const percent = document.getElementById(`${id}Percent`);
                if (!bar || !percent) return;

                bar.style.width = `${animationValue}%`;
                percent.textContent = `${Math.floor(animationValue)}%`;

                const wearBar = bar.closest('.wear-bar');
                const healthStatus = wearBar.querySelector('.health-status');

                const status = getStatusForValue(animationValue);
                healthStatus.className = `health-status ${status.class}`;
                healthStatus.textContent = getTranslation(`${status.label}`);

                wearBar.classList.remove('health-excellent', 'health-good', 'health-warning', 'health-critical', 'pulse');
                wearBar.classList.add(status.class.split(' ')[0]);
                if (status.class.includes('pulse')) {
                    wearBar.classList.add('pulse');
                }
            });

            animationFrame = requestAnimationFrame(animateWear);
        }

        animationFrame = requestAnimationFrame(animateWear);

        customizationUI._animationFrame = animationFrame;

        window._customizationAnimationFrame = animationFrame;
        window._animationActive = true;

    } else if (event.data.type === 'closeCustomization') {
        const customizationUI = document.getElementById('customizationUI');
        if (customizationUI) {
            customizationUI.style.display = 'none';
            if (customizationUI._animationFrame) {
                cancelAnimationFrame(customizationUI._animationFrame);
                customizationUI._animationFrame = null;
            }
        }
        window._animationActive = false;
        document.getElementById('wearDisplay').style.display = 'none';
        document.body.style.background = '#00000000';
    } else if (event.data.type === 'updateWearStatic') {
        const wearDisplay = document.getElementById('wearDisplay');
        wearDisplay.style.display = 'block';
        document.body.style.background = '#000000b7';

        const customizationUI = document.getElementById('customizationUI');
        if (customizationUI && customizationUI._animationFrame) {
            cancelAnimationFrame(customizationUI._animationFrame);
            customizationUI._animationFrame = null;
        }
        window._animationActive = false;

        const wearTypes = [{
                key: 'sparkPlugPercentage',
                id: 'sparkPlugWear'
            },
            {
                key: 'oilPercentage',
                id: 'oilWear'
            },
            {
                key: 'filterPercentage',
                id: 'filterWear'
            },
            {
                key: 'airFilterPercentage',
                id: 'airFilterWear'
            },
            {
                key: 'tirePercentage',
                id: 'tireWear'
            },
            {
                key: 'brakePercentage',
                id: 'brakeWear'
            },
            {
                key: 'suspensionPercentage',
                id: 'suspensionWear'
            },
            {
                key: 'clutchPercentage',
                id: 'clutchWear'
            }
        ];

        wearTypes.forEach(({
            key,
            id
        }) => {
            if (typeof data[key] === 'undefined') {
                const bar = document.getElementById(id);
                const percent = document.getElementById(`${id}Percent`);
                const wearBar = bar ? bar.closest('.wear-bar') : null;
                if (bar) {
                    bar.style.width = `0%`;
                    bar.style.backgroundColor = 'gray';
                }
                if (percent) percent.parentNode.removeChild(percent);
                if (wearBar) {
                    const wearIcon = wearBar.querySelector('.wear-icon');
                    if (wearIcon) {
                        wearIcon.style.backgroundColor = 'gray';
                        wearIcon.style.color = '#888';
                    }
                    const healthStatus = wearBar.querySelector('.health-status');
                    if (healthStatus) {
                        healthStatus.className = 'health-status health-disabled';
                        healthStatus.textContent = 'DISABLED';
                        healthStatus.style.color = 'red';
                    }
                    const statusIndicator = wearBar.querySelector('.status-indicator');
                    if (statusIndicator) {
                        statusIndicator.style.background = '#888';
                    }
                }
            } else {
                updateProgressBar(id, data[key]);
            }
        });
    } else if (event.data.type === 'updateWearStatic') {
        const wearDisplay = document.getElementById('wearDisplay');
        wearDisplay.style.display = 'block';
        document.body.style.background = '#000000b7';

        const wearTypes = [{
                key: 'sparkPlugPercentage',
                id: 'sparkPlugWear'
            },
            {
                key: 'oilPercentage',
                id: 'oilWear'
            },
            {
                key: 'filterPercentage',
                id: 'filterWear'
            },
            {
                key: 'airFilterPercentage',
                id: 'airFilterWear'
            },
            {
                key: 'tirePercentage',
                id: 'tireWear'
            },
            {
                key: 'brakePercentage',
                id: 'brakeWear'
            },
            {
                key: 'suspensionPercentage',
                id: 'suspensionWear'
            },
            {
                key: 'clutchPercentage',
                id: 'clutchWear'
            }
        ];

        wearTypes.forEach(({
            key,
            id
        }) => {
            if (typeof data[key] === 'undefined') {
                const bar = document.getElementById(id);
                const percent = document.getElementById(`${id}Percent`);
                const wearBar = bar ? bar.closest('.wear-bar') : null;
                if (bar) {
                    bar.style.width = `0%`;
                    bar.style.backgroundColor = 'gray';
                }
                if (percent) percent.parentNode.removeChild(percent);
                if (wearBar) {
                    const wearIcon = wearBar.querySelector('.wear-icon');
                    if (wearIcon) {
                        wearIcon.style.backgroundColor = 'gray';
                        wearIcon.style.color = '#888';
                    }
                    const healthStatus = wearBar.querySelector('.health-status');
                    if (healthStatus) {
                        healthStatus.className = 'health-status health-disabled';
                        healthStatus.textContent = 'DISABLED';
                        healthStatus.style.color = 'red';
                    }
                    const statusIndicator = wearBar.querySelector('.status-indicator');
                    if (statusIndicator) {
                        statusIndicator.style.background = '#888';
                    }
                }
            } else {
                updateProgressBar(id, data[key]);
            }
        });
    }
});

const closeUIButton = document.getElementById('closeUIButton');
if (closeUIButton) {
    closeUIButton.addEventListener('click', () => {
        const customizationUI = document.getElementById('customizationUI');
        if (customizationUI) {
            customizationUI.style.display = 'none';
        }
        document.getElementById('wearDisplay').style.display = 'none';
        document.body.style.background = '#00000000';
        fetch(`https://${GetParentResourceName()}/closeMenu`, {
            method: 'POST'
        });
    });
}

document.getElementById('saveBtn').addEventListener('click', function() {
    const settings = {
        mileage_visible: document.getElementById('mileageVisible').checked,
        mileage_size: parseFloat(document.getElementById('mileageSize').value),
        checkwear_size: parseFloat(document.getElementById('checkwearSize').value),
        mileage_pos_x: parseFloat(document.getElementById('mileagePosX').value),
        mileage_pos_y: parseFloat(document.getElementById('mileagePosY').value),
        checkwear_pos_x: parseFloat(document.getElementById('checkwearPosX').value),
        checkwear_pos_y: parseFloat(document.getElementById('checkwearPosY').value),
    };
    fetch(`https://${GetParentResourceName()}/savePlayerSettings`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify(settings),
    });
    const customizationUI = document.getElementById('customizationUI');
    if (customizationUI) {
        customizationUI.style.display = 'none';
    }
    document.body.style.background = '#00000000';
    document.getElementById('wearDisplay').style.display = 'none';
});


function makeDraggable(element) {
    let isDragging = false;
    let startX, startY, initialX, initialY;
    let animationFrameId = null;

    element.addEventListener('mousedown', function(e) {
        e.preventDefault();
        isDragging = true;
        startX = e.clientX;
        startY = e.clientY;
        const rect = element.getBoundingClientRect();
        initialX = rect.left;
        initialY = rect.top;
        document.body.style.userSelect = 'none';
    });

    function updatePosition(dx, dy) {
        element.style.position = 'fixed';
        element.style.left = (initialX + dx) + 'px';
        element.style.top = (initialY + dy) + 'px';

        if (element.id === 'mileageDisplay') {
            const posXInput = document.getElementById('mileagePosX');
            const posYInput = document.getElementById('mileagePosY');
            posXInput.value = initialX + dx;
            posYInput.value = initialY + dy;
            posXInput.dispatchEvent(new Event('input'));
            posYInput.dispatchEvent(new Event('input'));
        } else if (element.id === 'wearDisplay') {
            const posXInput = document.getElementById('checkwearPosX');
            const posYInput = document.getElementById('checkwearPosY');
            posXInput.value = initialX + dx;
            posYInput.value = initialY + dy;
            posXInput.dispatchEvent(new Event('input'));
            posYInput.dispatchEvent(new Event('input'));
        }
    }

    document.addEventListener('mousemove', function(e) {
        if (!isDragging) return;
        e.preventDefault();
        const dx = e.clientX - startX;
        const dy = e.clientY - startY;

        if (animationFrameId) {
            cancelAnimationFrame(animationFrameId);
        }
        animationFrameId = requestAnimationFrame(() => {
            updatePosition(dx, dy);
        });
    });

    document.addEventListener('mouseup', function(e) {
        if (isDragging) {
            e.preventDefault();
            isDragging = false;
            document.body.style.userSelect = 'auto';
            if (animationFrameId) {
                cancelAnimationFrame(animationFrameId);
                animationFrameId = null;
            }
        }
    });
}

window.addEventListener('load', function() {
    makeDraggable(document.getElementById('mileageDisplay'));
    makeDraggable(document.getElementById('wearDisplay'));
});

document.getElementById('mileageVisible').addEventListener('change', function() {
    document.getElementById('mileageDisplay').style.display = this.checked ? 'block' : 'none';
});
document.getElementById('mileageSize').addEventListener('input', function() {
    const scale = parseFloat(this.value);
    const display = document.getElementById('mileageDisplay');
    display.style.transform = `scale(${scale})`;
});
document.getElementById('checkwearSize').addEventListener('input', function() {
    const scale = parseFloat(this.value);
    const display = document.getElementById('wearDisplay');
    display.style.transform = `scale(${scale})`;
});
