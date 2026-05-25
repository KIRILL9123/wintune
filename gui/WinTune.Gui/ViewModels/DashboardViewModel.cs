using System;
using System.Collections.ObjectModel;
using System.Text.Json;
using System.Threading.Tasks;
using WinTune.Gui.Services;

namespace WinTune.Gui.ViewModels;

public sealed class DashboardViewModel : ViewModelBase
{
    private int _debloatScore;
    public int DebloatScore
    {
        get => _debloatScore;
        set { _debloatScore = value; RaisePropertyChanged(); }
    }

    private string? _selectedProfile;
    public string? SelectedProfile
    {
        get => _selectedProfile;
        set { _selectedProfile = value; RaisePropertyChanged(); }
    }

    private DateTime? _lastScan;
    public string LastScanText => _lastScan?.ToString("g") ?? "Never";

    public ObservableCollection<string> QuickActions { get; } = new()
    {
        "Audit",
        "Apply",
        "Revert"
    };

    public async Task LoadAsync()
    {
        IsLoading = true;
        Error = null;

        try
        {
            var runner = new PsRunner(App.RepoRoot);
            var result = await runner.RunAsync("Audit", profile: SelectedProfile ?? "base");

            if (result.ExitCode != 0)
            {
                Error = $"Process exited with code {result.ExitCode}";
                return;
            }

            var doc = JsonDocument.Parse(result.StdOut);
            var root = doc.RootElement;

            if (root.TryGetProperty("Score", out var scoreEl))
            {
                DebloatScore = scoreEl.GetProperty("Score").GetInt32();
            }

            _lastScan = DateTime.Now;
            RaisePropertyChanged(nameof(LastScanText));
        }
        catch (OperationCanceledException)
        {
            Error = "Audit timed out. Try again or run with admin.";
        }
        catch (JsonException ex)
        {
            Error = $"Failed to parse output: {ex.Message}";
        }
        catch (Exception ex)
        {
            Error = ex.Message;
        }
        finally
        {
            IsLoading = false;
        }
    }
}
