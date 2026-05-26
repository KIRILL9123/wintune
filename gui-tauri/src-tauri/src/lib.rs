mod ps;

use std::fs;
use std::path::PathBuf;

#[tauri::command]
fn cmd_audit(profile: String) -> Result<serde_json::Value, String> {
    let json = ps::run_ps("Audit", Some(&profile), None)?;
    serde_json::from_str(&json).map_err(|e| format!("JSON parse: {}", e))
}

#[tauri::command]
fn cmd_apply(profile: String) -> Result<serde_json::Value, String> {
    let json = ps::run_ps("Apply", Some(&profile), None)?;
    serde_json::from_str(&json).map_err(|e| format!("JSON parse: {}", e))
}

#[tauri::command]
fn cmd_revert(session: String) -> Result<serde_json::Value, String> {
    let json = ps::run_ps("Revert", None, Some(&session))?;
    serde_json::from_str(&json).map_err(|e| format!("JSON parse: {}", e))
}

#[tauri::command]
fn cmd_list_profiles() -> Result<serde_json::Value, String> {
    let json = ps::run_ps("List", None, None)?;
    serde_json::from_str(&json).map_err(|e| format!("JSON parse: {}", e))
}

#[tauri::command]
fn cmd_list_sessions() -> Result<Vec<serde_json::Value>, String> {
    let backup_dir = get_backup_dir()?;

    if !backup_dir.exists() {
        return Ok(vec![]);
    }

    let mut sessions: Vec<serde_json::Value> = vec![];

    let entries = fs::read_dir(&backup_dir).map_err(|e| format!("Cannot read backup dir: {}", e))?;

    for entry in entries.flatten() {
        let path = entry.path();
        if !path.is_dir() {
            continue;
        }

        let manifest = path.join("manifest.json");
        if !manifest.exists() {
            continue;
        }

        if let Ok(json_str) = fs::read_to_string(&manifest) {
            if let Ok(val) = serde_json::from_str::<serde_json::Value>(&json_str) {
                let session_id = path
                    .file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or("?")
                    .to_string();

                let profile = val
                    .get("Profile")
                    .and_then(|p| p.as_str())
                    .unwrap_or("?")
                    .to_string();

                let created = val
                    .get("CreatedAt")
                    .and_then(|c| c.as_str())
                    .unwrap_or("");

                let changes = val
                    .get("Changes")
                    .and_then(|c| c.as_array())
                    .map(|a| a.len())
                    .unwrap_or(0);

                let successes = val
                    .get("Changes")
                    .and_then(|c| c.as_array())
                    .map(|a| a.iter().filter(|ch| ch.get("Success").and_then(|s| s.as_bool()).unwrap_or(false)).count())
                    .unwrap_or(0);

                sessions.push(serde_json::json!({
                    "SessionId": session_id,
                    "ProfileName": profile,
                    "Timestamp": created,
                    "ChangeCount": changes,
                    "SuccessCount": successes
                }));
            }
        }
    }

    sessions.sort_by(|a, b| {
        let a_id = a["SessionId"].as_str().unwrap_or("");
        let b_id = b["SessionId"].as_str().unwrap_or("");
        b_id.cmp(a_id)
    });

    Ok(sessions)
}

fn get_backup_dir() -> Result<PathBuf, String> {
    let local = std::env::var("LOCALAPPDATA")
        .map_err(|_| "LOCALAPPDATA not set".to_string())?;
    Ok(PathBuf::from(local).join("WinTune").join("backups"))
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            cmd_audit,
            cmd_apply,
            cmd_revert,
            cmd_list_profiles,
            cmd_list_sessions
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
