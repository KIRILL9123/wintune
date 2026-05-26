function renderRevert() {
    const view = document.getElementById('view-revert');
    view.innerHTML = `
        <div class="section-header">
            <h1>Rollback History</h1>
            <p class="subtitle">Restore system state from a previous backup</p>
        </div>
        <div id="revertError" class="error-banner" style="display:none">
            <div class="error-icon">!</div>
            <div>
                <div class="error-title">Error</div>
                <div class="error-message" id="revertErrorMsg"></div>
            </div>
        </div>
        <div id="revertLoading" class="loading-spinner"><div class="spinner"></div></div>
        <div id="revertEmpty" class="empty-state" style="display:none">
            <div class="empty-icon" style="background:var(--warning-bg)">&#8634;</div>
            <h2>No backup sessions found</h2>
            <p>Apply a profile first to create restore points</p>
        </div>
        <div id="revertList" style="display:none"></div>
        <div id="revertSuccess" class="complete-state" style="display:none">
            <div class="complete-icon">&#10003;</div>
            <h2>Revert completed</h2>
        </div>
    `;
}

async function loadRevert() {
    const errorEl = document.getElementById('revertError');
    const loadingEl = document.getElementById('revertLoading');
    const emptyEl = document.getElementById('revertEmpty');
    const listEl = document.getElementById('revertList');
    const successEl = document.getElementById('revertSuccess');

    errorEl.style.display = 'none';
    emptyEl.style.display = 'none';
    listEl.style.display = 'none';
    successEl.style.display = 'none';
    loadingEl.style.display = 'flex';

    try {
        const sessions = await api.listSessions();

        if (sessions.length === 0) {
            loadingEl.style.display = 'none';
            emptyEl.style.display = 'block';
            return;
        }

        listEl.innerHTML = sessions.map(s => `
            <div class="card" style="margin-bottom:10px;display:flex;align-items:center;justify-content:space-between">
                <div>
                    <div style="display:flex;align-items:center;gap:10px;margin-bottom:6px">
                        <span class="badge" style="background:var(--accent-bg);color:var(--accent)">${s.SessionId}</span>
                        <span style="font-weight:600;font-size:14px">${s.ProfileName}</span>
                    </div>
                    <div style="font-size:12px;color:var(--text-secondary)">
                        ${s.Timestamp} &bull; <b style="color:var(--text-primary)">${s.ChangeCount}</b> changes &bull; <b style="color:var(--success)">${s.SuccessCount}</b> succeeded
                    </div>
                </div>
                <button class="btn btn-danger btn-sm" onclick="doRevert('${s.SessionId}')">&#8634; Revert</button>
            </div>
        `).join('');

        loadingEl.style.display = 'none';
        listEl.style.display = 'block';

    } catch (e) {
        loadingEl.style.display = 'none';
        errorEl.style.display = 'flex';
        document.getElementById('revertErrorMsg').textContent = e.message || String(e);
    }
}

async function doRevert(sessionId) {
    const loadingEl = document.getElementById('revertLoading');
    const errorEl = document.getElementById('revertError');
    const listEl = document.getElementById('revertList');
    const successEl = document.getElementById('revertSuccess');

    errorEl.style.display = 'none';
    listEl.style.display = 'none';
    successEl.style.display = 'none';
    loadingEl.style.display = 'flex';

    try {
        await api.revert(sessionId);
        loadingEl.style.display = 'none';
        successEl.style.display = 'block';
        setTimeout(() => loadRevert(), 2000);
    } catch (e) {
        loadingEl.style.display = 'none';
        errorEl.style.display = 'flex';
        document.getElementById('revertErrorMsg').textContent = e.message || String(e);
        listEl.style.display = 'block';
    }
}
