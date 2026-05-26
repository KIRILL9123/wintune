function renderApply() {
    const view = document.getElementById('view-apply');
    view.innerHTML = `
        <div class="section-header">
            <h1>Apply Progress</h1>
            <p class="subtitle" id="applySubtitle">Ready to apply</p>
        </div>
        <div id="applyError" class="error-banner" style="display:none">
            <div class="error-icon">!</div>
            <div>
                <div class="error-title">Error</div>
                <div class="error-message" id="applyErrorMsg"></div>
            </div>
        </div>
        <div id="applyLoading" class="loading-spinner"><div class="spinner"></div></div>
        <div id="applyContent" style="display:none">
            <div class="card" style="margin-bottom:24px">
                <div class="progress-header">
                    <span class="progress-percent" id="applyPercent">0%</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" id="applyBar" style="width:0%"></div>
                </div>
            </div>
            <div id="applyList"></div>
        </div>
        <div id="applyComplete" style="display:none">
            <div class="complete-state">
                <div class="complete-icon">&#10003;</div>
                <h2>All tweaks applied successfully</h2>
                <p style="color:var(--text-secondary);margin-top:8px">Your system has been optimized</p>
                <button class="btn btn-primary" style="margin-top:20px" onclick="app.loadView('dashboard')">View Dashboard</button>
            </div>
        </div>
    `;
}

async function loadApply() {
    const errorEl = document.getElementById('applyError');
    const loadingEl = document.getElementById('applyLoading');
    const contentEl = document.getElementById('applyContent');
    const completeEl = document.getElementById('applyComplete');
    const subtitleEl = document.getElementById('applySubtitle');

    errorEl.style.display = 'none';
    contentEl.style.display = 'none';
    completeEl.style.display = 'none';
    loadingEl.style.display = 'flex';

    const profile = selectedProfile || 'base';
    subtitleEl.textContent = 'Applying profile: ' + profile;

    try {
        const data = await api.apply(profile);

        const changes = data.Changes || [];
        const bar = document.getElementById('applyBar');
        const pct = document.getElementById('applyPercent');

        contentEl.style.display = 'block';

        document.getElementById('applyList').innerHTML = changes.map((c, i) => {
            const cls = c.Success ? 'green' : 'red';
            const icon = c.Success ? '&#10003;' : '&#10007;';
            return `
                <div class="list-item">
                    <div class="list-item-icon ${cls}">${icon}</div>
                    <div class="list-item-name">${c.TweakId}</div>
                    <div class="list-item-badge">${c.Success ? 'done' : 'failed'}</div>
                </div>
            `;
        }).join('');

        bar.style.width = '100%';
        pct.textContent = '100%';
        loadingEl.style.display = 'none';

        setTimeout(() => {
            contentEl.style.display = 'none';
            completeEl.style.display = 'block';
        }, 1000);

    } catch (e) {
        loadingEl.style.display = 'none';
        errorEl.style.display = 'flex';
        document.getElementById('applyErrorMsg').textContent = e.message || String(e);
    }
}
