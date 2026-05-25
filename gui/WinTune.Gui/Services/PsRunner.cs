using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

namespace WinTune.Gui.Services;

public sealed class PsRunner
{
    private readonly string _repoRoot;
    private static readonly TimeSpan Timeout = TimeSpan.FromMinutes(5);

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

        using var cts = new CancellationTokenSource(Timeout);
        using var proc = Process.Start(psi)!;

        try
        {
            var stdoutTask = proc.StandardOutput.ReadToEndAsync();
            var stderrTask = proc.StandardError.ReadToEndAsync();

            await proc.WaitForExitAsync(cts.Token);

            var stdout = await stdoutTask;
            var stderr = await stderrTask;

            if (!string.IsNullOrWhiteSpace(stderr))
            {
                Console.Error.WriteLine($"[PsRunner] stderr from powershell: {stderr}");
            }

            return new PsResult(proc.ExitCode, stdout, stderr);
        }
        catch (OperationCanceledException)
        {
            if (!proc.HasExited)
            {
                proc.Kill(entireProcessTree: true);
            }

            var partial = proc.ExitCode == 0 ? "" : proc.StandardOutput.ReadToEnd();
            return new PsResult(-1, partial ?? "", "Process timed out and was killed.");
        }
    }
}

public sealed record PsResult(int ExitCode, string StdOut, string StdErr);
