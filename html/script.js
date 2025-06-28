let currentLocale = 'en';
let translations = {};
async function loadTranslations(locale) {
    try {
        const response = await fetch(`../locales/${locale}.json`);
        translations = await response.json();
        updateUITranslations();
    } catch (error) {
        console.error(`Failed to load translations for ${locale}:`, error);
    }
}

function updateUITranslations() {
    document.querySelectorAll('[data-locale]').forEach(element => {
        const key = element.getAttribute('data-locale');
        if (translations[key]) {
            element.textContent = translations[key];
        }
    });
}
loadTranslations(currentLocale);

let WEAR_COMPONENTS = {
    sparkPlug: {
        id: 'sparkPlugWear',
        label: 'Spark Plugs',
        icon: 'fas fa-bolt',
        type: 'engine'
    },
    oil: {
        id: 'oilWear',
        label: 'Oil Life ',
        icon: 'fas fa-oil-can',
        type: 'engine'
    },
    filter: {
        id: 'filterWear',
        label: 'Oil Filter',
        icon: 'fas fa-filter',
        type: 'engine'
    },
    airFilter: {
        id: 'airFilterWear',
        label: 'Air Filter',
        icon: 'fas fa-wind',
        type: 'engine'
    },
    tire: {
        id: 'tireWear',
        label: 'Tires',
        icon: 'fa-regular fa-circle',
        type: 'tires'
    },
    brake: {
        id: 'brakeWear',
        label: 'Brakes',
        icon: 'fas fa-record-vinyl',
        type: 'brakes'
    },
    suspension: {
        id: 'suspensionWear',
        label: 'Suspension',
        icon: 'fas fa-car-burst',
        type: 'suspension'
    },
    clutch: {
        id: 'clutchWear',
        label: 'Clutch',
        icon: 'fas fa-cog',
        type: 'transmission'
    }
};

const HEALTH_STATUS = {
    excellent: {
        threshold: 75,
        class: 'health-excellent',
        label: 'Excellent'
    },
    good: {
        threshold: 50,
        class: 'health-good',
        label: 'Good'
    },
    warning: {
        threshold: 25,
        class: 'health-warning',
        label: 'Warning'
    },
    critical: {
        threshold: 0,
        class: 'health-critical pulse',
        label: 'Critical'
    },
    disabled: {
        class: 'health-disabled',
        label: 'DISABLED'
    }
};

function createWearBars() {
    const template = document.getElementById('wearBarTemplate');
    const container = document.getElementById('wearDisplay');

    Object.values(WEAR_COMPONENTS).forEach(({
        id,
        label,
        icon,
        type
    }) => {
        const wearBar = template.content.cloneNode(true).firstElementChild;
        wearBar.classList.add(type);

        const wearIcon = wearBar.querySelector('.wear-icon');
        wearIcon.innerHTML = `<i class="${icon}"></i>`;

        wearBar.querySelector('.component-name').textContent = label;
        wearBar.querySelector('.progress').id = id;
        wearBar.querySelector('.percent').id = `${id}Percent`;
        container.appendChild(wearBar);
    });
}

function getHealthStatus(value) {
    for (const [status, {
            threshold,
            class: statusClass,
            label
        }] of Object.entries(HEALTH_STATUS)) {
        if (value >= threshold) {
            return {
                class: statusClass,
                label
            };
        }
    }
    return {
        class: 'health-critical pulse',
        label: 'Critical'
    };
}

function getDisabledHealthStatus() {
    return {
        class: 'health-disabled',
        label: 'DISABLED'
    };
}

function updateProgressBar(barId, value) {
    const bar = document.getElementById(barId);
    const percent = document.getElementById(`${barId}Percent`);
    if (!bar || !percent) return;

    if (value === null || typeof value === 'undefined') {
        bar.style.width = `100%`;
        percent.textContent = `DISABLED`;
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
                        message: 'Please enter valid plate and mileage.',
                        type: 'error'
                    })
                })
                return;
            }

            const validations = [{
                    value: lastOilChange,
                    label: 'Last Oil Change'
                },
                {
                    value: lastOilFilterChange,
                    label: 'Last Oil Filter Change'
                },
                {
                    value: lastAirFilterChange,
                    label: 'Last Air Filter Change'
                },
                {
                    value: lastTireChange,
                    label: 'Last Tire Change'
                },
                {
                    value: lastBrakesChange,
                    label: 'Last Brakes Change'
                },
                {
                    value: lastClutchChange,
                    label: 'Last Clutch Change'
                },
                {
                    value: lastSuspensionChange,
                    label: 'Last Suspension Change'
                },
                {
                    value: lastSparkPlugChange,
                    label: 'Last Spark Plug Change'
                }
            ];

            for (const {
                    value,
                    label
                }
                of validations) {
                if (!isNaN(value) && value > mileage) {
                    fetch(`https://${GetParentResourceName()}/notify`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            message: `${label} must be equal or lower than Mileage.`,
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
                            message: 'Vehicle data updated successfully',
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
                            message: 'Failed to update vehicle data: ' + (data.error || 'Unknown error'),
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
            const confirmed = await showCustomConfirm('Are you sure you want to delete this vehicle?');
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
                            message: 'Vehicle deleted successfully.',
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
                    alert('Failed to delete vehicle: ' + (data.error || 'Unknown error'));
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
            if (data.unit.toLowerCase() === 'km') {
                document.getElementById('unitLabel').textContent = 'KM';
            } else if (data.unit.toLowerCase().startsWith('mile')) {
                document.getElementById('unitLabel').textContent = 'Mile';
            } else {
                document.getElementById('unitLabel').textContent = data.unit;
            }
        },
        toggleMileage: () => {
            document.getElementById('mileageDisplay').style.display = data.visible ? 'block' : 'none';
        },
        Configuration: () => {
            const display = document.getElementById('mileageDisplay');
            display.style.display = 'none';

            if (data.language) {
                currentLocale = data.language;
                loadTranslations(currentLocale);
            }
        },
        updateWear: () => {
            if (data.showUI == true) {
                const wearDisplay = document.getElementById('wearDisplay');
                wearDisplay.style.display = 'block';

                // Update the mileage title in the wearDisplay UI
                const wearMileageTitle = document.getElementById('wearMileageTitle');
                if (wearMileageTitle && typeof data.mileage === 'number' && typeof data.unit === 'string') {
                    let unitLabel = data.unit.toLowerCase();
                    if (unitLabel === 'km') {
                        unitLabel = 'km';
                    } else if (unitLabel.startsWith('mile')) {
                        unitLabel = 'miles';
                    }
                    wearMileageTitle.textContent = `Mileage: ${data.mileage.toFixed(2)} ${unitLabel}`;
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
                cell.textContent = 'No vehicles found.';
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
                editBtn.textContent = 'Edit';
                editBtn.classList.add('edit-button');
                editBtn.addEventListener('click', () => {
                    openVehicleEdit(vehicle);
                });
                actionsCell.appendChild(editBtn);
                const deleteBtn = document.createElement('button');
                deleteBtn.textContent = 'Delete';
                deleteBtn.classList.add('delete-button');
                deleteBtn.addEventListener('click', async () => {
                    const confirmed = await showCustomConfirm('Are you sure you want to delete this vehicle?');
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
                                    message: 'Vehicle deleted successfully.',
                                    type: 'success'
                                })
                            });
                            fetch(`https://${GetParentResourceName()}/requestVehicleList`, {
                                method: 'POST'
                            }).then(res => res.json()).then(resData => {
                                window.postMessage({
                                    type: 'vehicleList',
                                    vehicles: resData.vehicles
                                }, '*');
                            });
                        } else {
                            alert('Failed to delete vehicle: ' + (data.error || 'Unknown error'));
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
                    label: 'Excellent'
                };
            } else if (value >= 50) {
                return {
                    class: 'health-good',
                    label: 'Good'
                };
            } else if (value >= 25) {
                return {
                    class: 'health-warning',
                    label: 'Warning'
                };
            } else {
                return {
                    class: 'health-critical pulse',
                    label: 'Critical'
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
                healthStatus.textContent = status.label;

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
