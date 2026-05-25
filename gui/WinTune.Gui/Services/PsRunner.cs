using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;

namespace WinTune.Gui.Services;

public sealed class PsRunner
{
    private readonly string _repoRoot;

    public PsRunner(string repoRoot)
    {
        _repoRoot = repoRoot;
    }

    public async Task<PsResult> RunAsync(string action, string? profile = null, string? session = null, bool outputJson = true)
    {
        var scriptPath = Path.Combine(_repoRoot, "src", "wintune.ps1");

        var args = $"-NoProfile -ExecutionPolicy Bypass -File \"{scriptPath}\" -Action {action}";

        if (!string.IsNullOrWhiteSpace(profile))
        {
            args += $" -Profile {profile}";
        }

        if (!string.IsNullOrWhiteSpace(session))
        {
            args += $" -Session {session}";
        }

        if (outputJson)
        {
            args += " -OutputJson";
        }

        var psi = new ProcessStartInfo("powershell.exe")
        {
            Arguments = args,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        using var proc = Process.Start(psi)!;
        var stdout = await proc.StandardOutput.ReadToEndAsync();
        var stderr = await proc.StandardError.ReadToEndAsync();
        await proc.WaitForExitAsync();

        return new PsResult(proc.ExitCode, stdout, stderr);
    }
}

public sealed record PsResult(int ExitCode, string StdOut, string StdErr);
