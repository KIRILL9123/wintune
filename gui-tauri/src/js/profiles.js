let selectedProfile = null;

function renderProfiles() {
    const view = document.getElementById('view-profiles');
    view.innerHTML = `
        <div class="section-header">
            <h1>Profiles</h1>
            <p class="subtitle">Choose a profile to audit or apply to your system</p>
        </div>
        <div id="profError" class="error-banner" style="display:none">
            <div class="error-icon">!</div>
            <div>
                <div class="error-title">Error</div>
                <div class="error-message" id="profErrorMsg"></div>
            </div>
        </div>
        <div id="profLoading" class="loading-spinner"><div class="spinner"></div></div>
        <div id="profGrid" class="card-grid card-grid-2" style="display:none"></div>
    `;
}

async function loadProfiles() {
    const errorEl = document.getElementById('profError');
    const loadingEl = document.getElementById('profLoading');
    const gridEl = document.getElementById('profGrid');

    errorEl.style.display = 'none';
    gridEl.style.display = 'none';
    loadingEl.style.display = 'flex';

    try {
        const profiles = await api.listProfiles();

        gridEl.innerHTML = profiles.map(p => `
            <div class="profile-card" onclick="selectProfile('${p.Name}')">
                <div class="profile-card-header">
                    <div class="profile-card-icon">▤</div>
                    <div>
                        <div class="profile-card-name">
                            ${p.Name}
                            ${p.Dangerous ? '<span class="badge badge-danger" style="margin-left:8px">Dangerous</span>' : ''}
                        </div>
                    </div>
                </div>
                <div class="profile-card-desc">${p.Description || ''}</div>
                <div class="profile-card-footer">
                    <span><b>${p.TweakCount}</b> tweaks</span>
                </div>
            </div>
        `).join('');

        loadingEl.style.display = 'none';
        gridEl.style.display = 'grid';

    } catch (e) {
        loadingEl.style.display = 'none';
        errorEl.style.display = 'flex';
        document.getElementById('profErrorMsg').textContent = e.message || String(e);
    }
}

function selectProfile(name) {
    selectedProfile = name;
    app.loadView('apply');
}
