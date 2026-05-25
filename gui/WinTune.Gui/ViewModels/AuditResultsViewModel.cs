using System.Collections.ObjectModel;
using System.Text.Json;
using System.Threading.Tasks;
using WinTune.Gui.Services;

namespace WinTune.Gui.ViewModels;

public sealed class AuditResultsViewModel : ViewModelBase
{
    public ObservableCollection<AuditRow> Rows { get; } = new();

    private int _score;
    public int Score
    {
        get => _score;
        set { _score = value; RaisePropertyChanged(); }
    }

    private int _present;
    public int Present
    {
        get => _present;
        set { _present = value; RaisePropertyChanged(); }
    }

    private int _total;
    public int Total
    {
        get => _total;
        set { _total = value; RaisePropertyChanged(); }
    }

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
                Error = "Audit requires administrator rights. Run as admin.";
                return;
            }

            var data = JsonDocument.Parse(result.StdOut);
            var root = data.RootElement;

            if (root.TryGetProperty("Score", out var scoreEl))
            {
                Score = scoreEl.GetProperty("Score").GetInt32();
                Present = scoreEl.GetProperty("Present").GetInt32();
                Total = scoreEl.GetProperty("Total").GetInt32();
            }

            Rows.Clear();
            if (root.TryGetProperty("Snapshot", out var snap))
            {
                if (snap.TryGetProperty("Packages", out var pkgs))
                {
                    foreach (var pkg in pkgs.EnumerateArray())
                    {
                        var name = pkg.TryGetProperty("Name", out var n) ? n.GetString() ?? "?" : "?";
                        Rows.Add(new AuditRow(name, "package", "present"));
                    }
                }
                if (snap.TryGetProperty("Services", out var svcs))
                {
                    foreach (var svc in svcs.EnumerateArray())
                    {
                        var name = svc.TryGetProperty("Name", out var n) ? n.GetString() ?? "?" : "?";
                        var status = svc.TryGetProperty("Status", out var s) ? s.GetString() ?? "" : "";
                        Rows.Add(new AuditRow(name, "service", status == "Running" ? "running" : "stopped"));
                    }
                }
                if (snap.TryGetProperty("Tasks", out var tasks))
                {
                    foreach (var t in tasks.EnumerateArray())
                    {
                        var name = t.TryGetProperty("TaskName", out var n) ? n.GetString() ?? "?" : "?";
                        Rows.Add(new AuditRow(name, "task", "present"));
                    }
                }
                if (snap.TryGetProperty("Registry", out var reg))
                {
                    foreach (var prop in reg.EnumerateObject())
                    {
                        Rows.Add(new AuditRow(prop.Name, "registry",
                            prop.Value.ValueKind == JsonValueKind.Null ? "absent" : "present"));
                    }
                }
            }
        }
        catch (JsonException)
        {
            Error = "Audit requires administrator rights. Run as admin.";
        }
        catch (OperationCanceledException)
        {
            Error = "Audit timed out.";
        }
        catch (System.Exception ex)
        {
            Error = ex.Message;
        }
        finally
        {
            IsLoading = false;
        }
    }
}

public sealed record AuditRow(string Name, string Type, string State);
