const app = {
    currentView: 'dashboard',

    init() {
        renderDashboard();
        renderProfiles();
        renderAudit();
        renderApply();
        renderRevert();

        document.querySelectorAll('.nav-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const view = btn.dataset.view;
                this.loadView(view);
            });
        });

        this.loadView('dashboard');
    },

    loadView(view) {
        if (this.currentView === view && view !== 'audit') return;
        this.currentView = view;

        document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
        const btn = document.querySelector(`[data-view="${view}"]`);
        if (btn) btn.classList.add('active');

        document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
        const el = document.getElementById('view-' + view);
        if (el) el.classList.add('active');

        switch (view) {
            case 'dashboard': loadDashboard(); break;
            case 'profiles': loadProfiles(); break;
            case 'audit': loadAudit(); break;
            case 'apply': loadApply(); break;
            case 'revert': loadRevert(); break;
        }
    }
};

document.addEventListener('DOMContentLoaded', () => app.init());
