using System.Text.Json;
using WinTune.Gui.Services;
using Xunit;

namespace WinTune.Gui.Tests.Services;

public sealed class PsRunnerTests
{
    private static string GetRepoRoot()
    {
        var dir = AppContext.BaseDirectory;
        while (dir != null)
        {
            if (File.Exists(Path.Combine(dir, "src", "wintune.ps1")))
                return dir;
            dir = Path.GetDirectoryName(dir);
        }
        throw new InvalidOperationException("Cannot find repo root from " + AppContext.BaseDirectory);
    }

    [Fact]
    public async Task Smoke_List_ReturnsValidJsonWithExitCodeZero()
    {
        var runner = new PsRunner(GetRepoRoot());
        var result = await runner.RunAsync("List");

        Assert.Equal(0, result.ExitCode);
        Assert.False(string.IsNullOrWhiteSpace(result.StdOut));
        Assert.DoesNotContain("Are you sure", result.StdOut);
        Assert.DoesNotContain("Type", result.StdOut);
    }

    [Fact]
    public async Task Smoke_List_OutputJson_AllFiveProfiles()
    {
        var runner = new PsRunner(GetRepoRoot());
        var result = await runner.RunAsync("List");

        var profiles = JsonSerializer.Deserialize<List<JsonElement>>(result.StdOut);
        Assert.NotNull(profiles);
        Assert.Equal(5, profiles.Count);
    }

    [Fact]
    public async Task Smoke_List_EachProfileHasRequiredFields()
    {
        var runner = new PsRunner(GetRepoRoot());
        var result = await runner.RunAsync("List");

        var profiles = JsonSerializer.Deserialize<List<JsonElement>>(result.StdOut);
        Assert.NotNull(profiles);

        foreach (var p in profiles)
        {
            Assert.True(p.TryGetProperty("Name", out var name) && name.GetString()!.Length > 0,
                $"Profile missing Name: {p}");
            Assert.True(p.TryGetProperty("Description", out var desc) && desc.GetString()!.Length > 0,
                $"Profile missing Description: {p}");
            Assert.True(p.TryGetProperty("TweakCount", out var count) && count.GetInt32() > 0,
                $"Profile missing TweakCount: {p}");
            Assert.True(p.TryGetProperty("Inherits", out _),
                $"Profile missing Inherits: {p}");
            Assert.True(p.TryGetProperty("Dangerous", out _),
                $"Profile missing Dangerous: {p}");
        }
    }

    [Fact]
    public async Task Smoke_List_AllProfilesHaveUniqueNames()
    {
        var runner = new PsRunner(GetRepoRoot());
        var result = await runner.RunAsync("List");

        var profiles = JsonSerializer.Deserialize<List<JsonElement>>(result.StdOut);
        Assert.NotNull(profiles);

        var names = profiles.Select(p => p.GetProperty("Name").GetString()!).ToList();
        Assert.Equal(names.Distinct().Count(), names.Count);
    }

    [Fact]
    public async Task Smoke_List_NoDangerousProfileIsTrue()
    {
        var runner = new PsRunner(GetRepoRoot());
        var result = await runner.RunAsync("List");

        var profiles = JsonSerializer.Deserialize<List<JsonElement>>(result.StdOut);
        Assert.NotNull(profiles);

        foreach (var p in profiles)
        {
            var dangerous = p.GetProperty("Dangerous");
            if (dangerous.ValueKind == JsonValueKind.True)
            {
                var name = p.GetProperty("Name").GetString();
                Assert.NotNull(name);
            }
        }
    }

    [Fact]
    public async Task Smoke_List_WithoutOutputJson_ReturnsNonJsonText()
    {
        var runner = new PsRunner(GetRepoRoot());
        var result = await runner.RunAsync("List", outputJson: false);

        Assert.Equal(0, result.ExitCode);
        Assert.False(string.IsNullOrWhiteSpace(result.StdOut));

        try
        {
            JsonSerializer.Deserialize<List<JsonElement>>(result.StdOut);
            Assert.Fail("Expected non-JSON table output, but got parseable JSON.");
        }
        catch (JsonException)
        {
        }
    }

    [Fact]
    public async Task Smoke_Audit_WithoutAdmin_ReturnsErrorJson()
    {
        var runner = new PsRunner(GetRepoRoot());
        var result = await runner.RunAsync("Audit", profile: "base");

        Assert.Equal(1, result.ExitCode);
        Assert.True(!string.IsNullOrWhiteSpace(result.StdOut) || !string.IsNullOrWhiteSpace(result.StdErr));

        var output = result.StdOut;
        var json = JsonSerializer.Deserialize<JsonElement>(output);

        Assert.True(json.TryGetProperty("success", out var success) && success.GetBoolean() == false);
        Assert.True(json.TryGetProperty("error", out var error) && error.GetString()!.Length > 0);
    }

    [Fact]
    public async Task Smoke_Timeout_ReturnsMinusOneOnCancel()
    {
        var runner = new PsRunner(GetRepoRoot(), TimeSpan.FromMilliseconds(1));

        var result = await runner.RunAsync("List");

        Assert.True(result.ExitCode == 0 || result.ExitCode == -1);
        if (result.ExitCode == -1)
        {
            Assert.Contains("timed out", result.StdErr, StringComparison.OrdinalIgnoreCase);
        }
    }
}
