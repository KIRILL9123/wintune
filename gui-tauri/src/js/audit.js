function renderAudit() {
    const view = document.getElementById('view-audit');
    view.innerHTML = `
        <div class="section-header" style="display:flex;justify-content:space-between;align-items:flex-start">
            <div>
                <h1>Audit Results</h1>
                <p class="subtitle">Scan your system for bloatware</p>
            </div>
            <button class="btn btn-primary" onclick="loadAudit()">&#9711; Run Audit</button>
        </div>
        <div id="auditError" class="error-banner" style="display:none">
            <div class="error-icon">!</div>
            <div>
                <div class="error-title">Error</div>
                <div class="error-message" id="auditErrorMsg"></div>
            </div>
        </div>
        <div id="auditLoading" class="loading-spinner"><div class="spinner"></div></div>
        <div id="auditContent" style="display:none"></div>
    `;
}

async function loadAudit() {
    const errorEl = document.getElementById('auditError');
    const loadingEl = document.getElementById('auditLoading');
    const contentEl = document.getElementById('auditContent');

    errorEl.style.display = 'none';
    contentEl.style.display = 'none';
    loadingEl.style.display = 'flex';

    try {
        const data = await api.audit('base');

        const score = data.Score;
        const snap = data.Snapshot;

        let items = [];
        if (snap.Packages) items.push(...snap.Packages.map(p => ({ name: p.Name, type: 'package' })));
        if (snap.Services) items.push(...snap.Services.map(s => ({ name: s.Name, type: s.Status === 'Running' ? 'running' : 'stopped' })));
        if (snap.Tasks) items.push(...snap.Tasks.map(t => ({ name: t.TaskName, type: 'task' })));
        if (snap.Registry) {
            for (const [key, val] of Object.entries(snap.Registry)) {
                items.push({ name: key, type: val === null ? 'absent' : 'present' });
            }
        }

        contentEl.innerHTML = `
            <div class="score-hero" style="padding:24px">
                <div class="score-circle" style="width:100px;height:100px">
                    <div class="score-value" style="font-size:38px">${score.Score}</div>
                    <div class="score-label">%</div>
                </div>
                <div class="score-details">
                    <div class="score-title">Debloat Score</div>
                    <div class="score-subtitle">
                        <b>${score.Present}</b> bloat items detected out of <b>${score.Total}</b>
                    </div>
                </div>
            </div>
            <div id="auditList"></div>
        `;

        const listEl = document.getElementById('auditList');
        listEl.innerHTML = items.map((item, i) => `
            <div class="list-item">
                <div class="list-item-icon blue">&#9679;</div>
                <div class="list-item-name">${item.name}</div>
                <div class="list-item-badge">${item.type}</div>
            </div>
        `).join('');

        loadingEl.style.display = 'none';
        contentEl.style.display = 'block';

    } catch (e) {
        loadingEl.style.display = 'none';
        errorEl.style.display = 'flex';
        document.getElementById('auditErrorMsg').textContent = e.message || String(e);
    }
}
