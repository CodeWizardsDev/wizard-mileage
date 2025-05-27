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
// Load default translations
loadTranslations(currentLocale);

const WEAR_COMPONENTS = {
    oil: { id: 'oilWear', label: 'Oil Life ', icon: 'fas fa-oil-can', type: 'engine' },
    filter: { id: 'filterWear', label: 'Oil Filter', icon: 'fas fa-filter', type: 'engine' },
    airFilter: { id: 'airFilterWear', label: 'Air Filter', icon: 'fas fa-wind', type: 'engine' },
    tire: { id: 'tireWear', label: 'Tires', icon: 'fa-regular fa-circle', type: 'tires' },
    brake: { id: 'brakeWear', label: 'Brakes', icon: 'fas fa-compact-disc', type: 'brakes' },
    clutch: { id: 'clutchWear', label: 'Clutch', icon: 'fas fa-cog', type: 'transmission' }
};

const HEALTH_STATUS = {
    excellent: { threshold: 75, class: 'health-excellent', label: 'Excellent' },
    good: { threshold: 50, class: 'health-good', label: 'Good' },
    warning: { threshold: 25, class: 'health-warning', label: 'Warning' },
    critical: { threshold: 0, class: 'health-critical pulse', label: 'Critical' }
};

function createWearBars() {
    const template = document.getElementById('wearBarTemplate');
    const container = document.getElementById('wearDisplay');
    
    Object.values(WEAR_COMPONENTS).forEach(({ id, label, icon, type }) => {
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
    for (const [status, { threshold, class: statusClass, label }] of Object.entries(HEALTH_STATUS)) {
        if (value >= threshold) {
            return { class: statusClass, label };
        }
    }
    return { class: 'health-critical pulse', label: 'Critical' };
}

function updateProgressBar(barId, value) {
    const bar = document.getElementById(barId);
    const percent = document.getElementById(`${barId}Percent`);
    if (!bar || !percent) return;
    
    bar.style.width = `${value}%`;
    percent.textContent = `${value}%`;
    
    const wearBar = bar.closest('.wear-bar');
    const healthStatus = wearBar.querySelector('.health-status');
    const { class: statusClass, label } = getHealthStatus(value);
    
    healthStatus.className = `health-status ${statusClass}`;
    healthStatus.textContent = label;
    
    wearBar.classList.remove('health-excellent', 'health-good', 'health-warning', 'health-critical', 'pulse');
    wearBar.classList.add(statusClass.split(' ')[0]);
    if (statusClass.includes('pulse')) {
        wearBar.classList.add('pulse');
    }
}

window.addEventListener('load', createWearBars);

window.addEventListener('message', ({ data }) => {
    const handlers = {
        updateMileage: () => {
            document.getElementById('mileageValue').textContent = data.mileage.toFixed(2);
            document.getElementById('unitLabel').textContent = data.unit;
        },
        toggleMileage: () => {
            document.getElementById('mileageDisplay').style.display = data.visible ? 'block' : 'none';
        },
        Configuration: () => {
            const display = document.getElementById('mileageDisplay');
            display.className = data.location;
            display.style.display = 'none';

            if (data.language) {
                currentLocale = data.language;
                loadTranslations(currentLocale);
            }
        },
        updateWear: () => {
            const wearDisplay = document.getElementById('wearDisplay');
            wearDisplay.style.display = 'block';
            
            updateProgressBar('oilWear', data.oilPercentage);
            updateProgressBar('filterWear', data.filterPercentage);
            updateProgressBar('airFilterWear', data.airFilterPercentage);
            updateProgressBar('tireWear', data.tirePercentage);
            updateProgressBar('brakeWear', data.brakePercentage);
            updateProgressBar('clutchWear', data.clutchPercentage);
            
            document.addEventListener('keydown', function(event) {
                if (event.key === 'Escape' || event.key === 'Backspace') {
                    wearDisplay.style.display = 'none';
                    fetch(`https://${GetParentResourceName()}/closeWearMenu`, {
                        method: 'POST'
                    });
                }
            });
        }
    };
    
    if (handlers[data.type]) {
        handlers[data.type]();
    }
});