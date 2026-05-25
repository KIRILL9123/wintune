using System.Collections.ObjectModel;

namespace WinTune.Gui.ViewModels;

public sealed class DashboardViewModel : ViewModelBase
{
    private int _debloatScore = 54;
    public int DebloatScore
    {
        get => _debloatScore;
        set { _debloatScore = value; RaisePropertyChanged(); }
    }

    public ObservableCollection<string> QuickActions { get; } = new()
    {
        "Audit",
        "Apply",
        "Revert"
    };
}
