using System;
using System.IO;
using System.Threading.Tasks;
using System.Management.Automation;

namespace WinTune.Gui.Services;

public sealed class PsRunner
{
    private readonly string _repoRoot;

    public PsRunner(string repoRoot)
    {
        _repoRoot = repoRoot;
    }

    public Task<PsResult> RunAsync(string action, string? profile = null, string? session = null, bool outputJson = true)
    {
        return Task.Run(() =>
        {
            var scriptPath = Path.Combine(_repoRoot, "src", "wintune.ps1");

            using var ps = PowerShell.Create();
            ps.AddCommand("powershell");
            ps.AddArgument("-NoProfile");
            ps.AddArgument("-ExecutionPolicy");
            ps.AddArgument("Bypass");
            ps.AddArgument("-File");
            ps.AddArgument(scriptPath);
            ps.AddArgument("-Action");
            ps.AddArgument(action);

            if (!string.IsNullOrWhiteSpace(profile))
            {
                ps.AddArgument("-Profile");
                ps.AddArgument(profile);
            }

            if (!string.IsNullOrWhiteSpace(session))
            {
                ps.AddArgument("-Session");
                ps.AddArgument(session);
            }

            if (outputJson)
            {
                ps.AddArgument("-OutputJson");
            }

            var output = ps.Invoke();
            var stderr = string.Join(Environment.NewLine, ps.Streams.Error);
            var stdout = string.Join(Environment.NewLine, output);
            var exitCode = ps.HadErrors ? 1 : 0;

            return new PsResult(exitCode, stdout, stderr);
        });
    }
}

public sealed record PsResult(int ExitCode, string StdOut, string StdErr);
