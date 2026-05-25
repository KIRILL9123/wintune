using System.Collections.ObjectModel;

namespace WinTune.Gui.ViewModels;

public sealed class AuditResultsViewModel : ViewModelBase
{
    public ObservableCollection<AuditRow> Rows { get; } = new()
    {
        new AuditRow("remove-bing-news", "package", "low", "present", true),
        new AuditRow("disable-telemetry", "service", "medium", "present", true),
        new AuditRow("remove-copilot", "package", "low", "absent", false)
    };
}

public sealed record AuditRow(string TweakId, string Type, string Risk, string State, bool Include);
