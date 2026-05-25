using System.Collections.ObjectModel;

namespace WinTune.Gui.ViewModels;

public sealed class ApplyProgressViewModel : ViewModelBase
{
    private int _overallPercent = 35;
    public int OverallPercent
    {
        get => _overallPercent;
        set { _overallPercent = value; RaisePropertyChanged(); }
    }

    public ObservableCollection<ApplyRow> Rows { get; } = new()
    {
        new ApplyRow("remove-bing-news", "pending"),
        new ApplyRow("disable-telemetry", "running"),
        new ApplyRow("remove-copilot", "done")
    };
}

public sealed record ApplyRow(string TweakId, string Status)
{
    public string StatusGlyph => Status switch
    {
        "done" => "\uE73E",
        "running" => "\uE768",
        "failed" => "\uEA39",
        _ => "\uE71D"
    };
}
