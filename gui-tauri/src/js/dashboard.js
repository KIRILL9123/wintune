function renderDashboard() {
    const view = document.getElementById('view-dashboard');
    view.innerHTML = `
        <div class="section-header">
            <h1>Dashboard</h1>
            <p class="subtitle" id="dashSubtitle">No scan data</p>
        </div>
        <div id="dashError" class="error-banner" style="display:none">
            <div class="error-icon">!</div>
            <div>
                <div class="error-title">Error</div>
                <div class="error-message" id="dashErrorMsg"></div>
            </div>
        </div>
        <div id="dashLoading" class="loading-spinner"><div class="spinner"></div></div>
        <div id="dashEmpty" class="empty-state" style="display:none">
            <div class="empty-icon" style="background:var(--accent-bg)">&#9724;</div>
            <h2>No data yet</h2>
            <p>Run an audit to analyze your system</p>
            <button class="btn btn-primary btn-lg" onclick="app.loadView('audit')">Run Audit</button>
        </div>
        <div id="dashContent" style="display:none"></div>
    `;
}

async function loadDashboard() {
    const errorEl = document.getElementById('dashError');
    const loadingEl = document.getElementById('dashLoading');
    const emptyEl = document.getElementById('dashEmpty');
    const contentEl = document.getElementById('dashContent');
    const subtitleEl = document.getElementById('dashSubtitle');

    errorEl.style.display = 'none';
    contentEl.style.display = 'none';
    emptyEl.style.display = 'none';
    loadingEl.style.display = 'flex';

    try {
        const data = await api.audit('base');

        const score = data.Score;
        const snap = data.Snapshot;

        const pkgCount = snap.Packages ? snap.Packages.length : 0;
        const svcs = snap.Services || [];
        const running = svcs.filter(s => s.Status === 'Running').length;
        const metrics = snap.Metrics || {};
        const ram = metrics.IdleRamMB || 0;
        const procCount = metrics.ProcessCount || 0;

        const now = new Date();
        subtitleEl.textContent = 'Last scan: ' + now.toLocaleString();

        contentEl.innerHTML = `
            <div class="score-hero">
                <div class="score-circle">
                    <div class="score-value">${score.Score}</div>
                    <div class="score-label">Debloat %</div>
                </div>
                <div class="score-details">
                    <div class="score-title">System Health</div>
                    <div class="score-subtitle">
                        <b>${score.Removed}</b> of <b>${score.Total}</b> bloat items removed
                    </div>
                    <div class="score-actions">
                        <button class="btn btn-sm" onclick="app.loadView('audit')">&#9711; Audit</button>
                        <button class="btn btn-primary btn-sm" onclick="app.loadView('apply')">⚙ Apply</button>
                    </div>
                </div>
            </div>
            <div class="card-grid card-grid-4">
                <div class="card">
                    <div class="stat-icon blue">&#9632;</div>
                    <div class="stat-value">${pkgCount}</div>
                    <div class="stat-label">Packages</div>
                </div>
                <div class="card">
                    <div class="stat-icon purple">&#9679;</div>
                    <div class="stat-value">${running}</div>
                    <div class="stat-label">Services</div>
                    <div class="stat-extra">/ ${svcs.length} total</div>
                </div>
                <div class="card">
                    <div class="stat-icon green">&#9654;</div>
                    <div class="stat-value">${procCount}</div>
                    <div class="stat-label">Processes</div>
                </div>
                <div class="card">
                    <div class="stat-icon orange">&#9830;</div>
                    <div class="stat-value">${ram} MB</div>
                    <div class="stat-label">Idle RAM</div>
                </div>
            </div>
        `;

        loadingEl.style.display = 'none';
        contentEl.style.display = 'block';

    } catch (e) {
        loadingEl.style.display = 'none';
        errorEl.style.display = 'flex';
        document.getElementById('dashErrorMsg').textContent = e.message || String(e);
    }
}
