const api = {
    async invoke(cmd, args = {}) {
        try {
            return await window.__TAURI__.core.invoke(cmd, args);
        } catch (e) {
            throw new Error(typeof e === 'string' ? e : (e.message || 'Unknown error'));
        }
    },

    async audit(profile) {
        return this.invoke('cmd_audit', { profile });
    },

    async apply(profile) {
        return this.invoke('cmd_apply', { profile });
    },

    async revert(session) {
        return this.invoke('cmd_revert', { session });
    },

    async listProfiles() {
        return this.invoke('cmd_list_profiles');
    },

    async listSessions() {
        return this.invoke('cmd_list_sessions');
    }
};
