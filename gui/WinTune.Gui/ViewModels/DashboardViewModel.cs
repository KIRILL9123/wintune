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

    private int _removedCount;
    public int RemovedCount
    {
        get => _removedCount;
        set { _removedCount = value; RaisePropertyChanged(); }
    }

    private int _totalCount;
    public int TotalCount
    {
        get => _totalCount;
        set { _totalCount = value; RaisePropertyChanged(); }
    }

    private int _packageCount;
    public int PackageCount
    {
        get => _packageCount;
        set { _packageCount = value; RaisePropertyChanged(); }
    }

    private int _runningServiceCount;
    public int RunningServiceCount
    {
        get => _runningServiceCount;
        set { _runningServiceCount = value; RaisePropertyChanged(); }
    }

    private int _totalServiceCount;
    public int TotalServiceCount
    {
        get => _totalServiceCount;
        set { _totalServiceCount = value; RaisePropertyChanged(); }
    }

    private int _processCount;
    public int ProcessCount
    {
        get => _processCount;
        set { _processCount = value; RaisePropertyChanged(); }
    }

    private long _idleRamMB;
    public long IdleRamMB
    {
        get => _idleRamMB;
        set { _idleRamMB = value; RaisePropertyChanged(); }
    }

    private DateTime? _lastScan;
    public string LastScanText => _lastScan.HasValue
        ? $"Last scan: {_lastScan.Value:g}"
        : "No scan data";

    private bool _isLoaded;
    public bool IsLoaded
    {
        get => _isLoaded;
        set { _isLoaded = value; RaisePropertyChanged(); }
    }

    public bool IsEmpty => !IsLoading && !IsLoaded && string.IsNullOrEmpty(Error);

    public ObservableCollection<string> QuickActions { get; } = new()
    {
        "Audit", "Apply", "Revert"
    };

    public async Task LoadAsync()
    {
        IsLoading = true;
        Error = null;

        try
        {
            var runner = new PsRunner(App.RepoRoot);
            var result = await runner.RunAsync("Audit", profile: "base");

            if (result.ExitCode != 0)
            {
                var doc = JsonDocument.Parse(result.StdOut);
                var root = doc.RootElement;
                if (root.TryGetProperty("error", out var err))
                {
                    Error = err.GetString() ?? $"Exit code {result.ExitCode}";
                }
                else
                {
                    Error = $"Process exited with code {result.ExitCode}";
                }
                return;
            }

            var data = JsonDocument.Parse(result.StdOut);
            var root2 = data.RootElement;

            if (root2.TryGetProperty("Score", out var scoreEl))
            {
                DebloatScore = scoreEl.GetProperty("Score").GetInt32();
                RemovedCount = scoreEl.GetProperty("Removed").GetInt32();
                TotalCount = scoreEl.GetProperty("Total").GetInt32();
            }

            if (root2.TryGetProperty("Snapshot", out var snap))
            {
                PackageCount = snap.TryGetProperty("Packages", out var pkgs)
                    ? pkgs.GetArrayLength() : 0;

                if (snap.TryGetProperty("Services", out var svcs))
                {
                    TotalServiceCount = svcs.GetArrayLength();
                    var running = 0;
                    foreach (var svc in svcs.EnumerateArray())
                    {
                        if (svc.TryGetProperty("Status", out var st) &&
                            st.GetString() == "Running")
                            running++;
                    }
                    RunningServiceCount = running;
                }

                if (snap.TryGetProperty("Metrics", out var met))
                {
                    IdleRamMB = met.TryGetProperty("IdleRamMB", out var ram)
                        ? ram.GetInt64() : 0;
                    ProcessCount = met.TryGetProperty("ProcessCount", out var pc)
                        ? pc.GetInt32() : 0;
                }
            }

            _lastScan = DateTime.Now;
            RaisePropertyChanged(nameof(LastScanText));
            IsLoaded = true;
        }
        catch (JsonException)
        {
            Error = "Audit requires administrator rights. Run as admin.";
        }
        catch (OperationCanceledException)
        {
            Error = "Audit timed out.";
        }
        catch (Exception ex)
        {
            Error = ex.Message;
        }
        finally
        {
            IsLoading = false;
            RaisePropertyChanged(nameof(IsEmpty));
        }
    }
}
