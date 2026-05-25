using System.Collections.ObjectModel;

namespace WinTune.Gui.ViewModels;

public sealed class ApplyProgressViewModel : ViewModelBase
{
    private int _overallPercent;
    public int OverallPercent
    {
        get => _overallPercent;
        set { _overallPercent = value; RaisePropertyChanged(); }
    }

    private string? _profileName;
    public string StatusText => IsLoading
        ? $"Applying profile: {_profileName ?? "..."}"
        : IsComplete
            ? "All tweaks have been applied."
            : "Ready to apply.";

    public bool IsComplete => !IsLoading && OverallPercent >= 100;

    public ObservableCollection<ApplyRow> Rows { get; } = new();

    public Task StartApplyAsync(string profileName)
    {
        _profileName = profileName;
        IsLoading = true;
        Error = null;
        OverallPercent = 0;
        RaisePropertyChanged(nameof(StatusText));

        // TODO Block B: streaming progress from PsRunner

        IsLoading = false;
        OverallPercent = 100;
        RaisePropertyChanged(nameof(StatusText));
        RaisePropertyChanged(nameof(IsComplete));
        return Task.CompletedTask;
    }
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
