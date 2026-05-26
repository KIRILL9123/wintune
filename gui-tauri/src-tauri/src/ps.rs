use std::path::PathBuf;
use std::process::Command;

pub fn find_repo_root() -> Result<PathBuf, String> {
    let exe =
        std::env::current_exe().map_err(|e| format!("Cannot get exe path: {}", e))?;
    let mut dir = exe
        .parent()
        .ok_or("Cannot get exe directory")?
        .to_path_buf();

    loop {
        if dir.join("src").join("wintune.ps1").exists() {
            return Ok(dir);
        }
        if !dir.pop() {
            return Err("Cannot find repo root (src/wintune.ps1)".into());
        }
    }
}

pub fn run_ps(action: &str, profile: Option<&str>, session: Option<&str>) -> Result<String, String> {
    let repo = find_repo_root()?;
    let script = repo.join("src").join("wintune.ps1");

    let mut args = vec![
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
    ];
    let script_str = script.to_str().ok_or("Invalid script path")?;
    args.push(script_str);
    args.push("-Action");
    args.push(action);

    if let Some(p) = profile {
        args.push("-Profile");
        args.push(p);
    }
    if let Some(s) = session {
        args.push("-Session");
        args.push(s);
    }
    args.push("-OutputJson");

    let output = Command::new("powershell.exe")
        .args(&args)
        .output()
        .map_err(|e| format!("Failed to run PowerShell: {}", e))?;

    let stdout = String::from_utf8_lossy(&output.stdout).to_string();

    if !output.status.success() {
        let code = output.status.code().unwrap_or(-1);
        let stderr = String::from_utf8_lossy(&output.stderr);
        if let Some(err) = try_extract_error(&stdout) {
            return Err(err);
        }
        return Err(format!(
            "PowerShell exited with code {}\n{}",
            code,
            stderr.trim()
        ));
    }

    Ok(extract_json(&stdout))
}

fn try_extract_error(stdout: &str) -> Option<String> {
    let trimmed = stdout.trim();
    if let Ok(v) = serde_json::from_str::<serde_json::Value>(trimmed) {
        if let Some(err) = v.get("error").and_then(|e| e.as_str()) {
            return Some(err.to_string());
        }
    }
    None
}

fn extract_json(raw: &str) -> String {
    let trimmed = raw.trim();
    if let Some(pos) = trimmed.rfind('}') {
        trimmed[..=pos].to_string()
    } else {
        trimmed.to_string()
    }
}
