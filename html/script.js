const WEAR_COMPONENTS = {
    oil: { id: 'oilWear', label: 'Oil Life' },
    filter: { id: 'filterWear', label: 'Oil Filter' },
    airFilter: { id: 'airFilterWear', label: 'Air Filter' },
    tire: { id: 'tireWear', label: 'Tires' },
    brake: { id: 'brakeWear', label: 'Brakes' }
};
function createWearBars() {
    const template = document.getElementById('wearBarTemplate');
    const container = document.getElementById('wearDisplay');
    
    Object.values(WEAR_COMPONENTS).forEach(({ id, label }) => {
        const wearBar = template.content.cloneNode(true).firstElementChild;
        wearBar.querySelector('.wear-label').textContent = label;
        wearBar.querySelector('.progress').id = id;
        wearBar.querySelector('.percent').id = `${id}Percent`;
        container.appendChild(wearBar);
    });
}
function updateProgressBar(barId, value) {
    const bar = document.getElementById(barId);
    const percent = document.getElementById(`${barId}Percent`);
    if (!bar || !percent) return;
    bar.style.width = `${value}%`;
    percent.textContent = `${value}%`;
    
    bar.style.background = value <= 25 ? 'linear-gradient(90deg, #f44336, #ff5252)' :
                          value <= 50 ? 'linear-gradient(90deg, #ff9800, #ffa726)' :
                                      'linear-gradient(90deg, #4CAF50, #8BC34A)';
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
        },
        updateWear: () => {
            const wearDisplay = document.getElementById('wearDisplay');
            wearDisplay.style.display = 'block';
            
            updateProgressBar('oilWear', data.oilPercentage);
            updateProgressBar('filterWear', data.filterPercentage);
            updateProgressBar('airFilterWear', data.airFilterPercentage);
            updateProgressBar('tireWear', data.tirePercentage);
            updateProgressBar('brakeWear', data.brakePercentage);
            
            setTimeout(() => wearDisplay.style.display = 'none', 6000);
        }
    };
    if (handlers[data.type]) {
        handlers[data.type]();
    }
});