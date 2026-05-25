using System;
using System.Collections.ObjectModel;

namespace WinTune.Gui.ViewModels;

public sealed class RevertViewModel : ViewModelBase
{
    public ObservableCollection<RevertSession> Sessions { get; } = new()
    {
        new RevertSession("20260525-154507", DateTime.Now.AddDays(-1)),
        new RevertSession("20260524-102233", DateTime.Now.AddDays(-2))
    };
}

public sealed record RevertSession(string SessionId, DateTime Timestamp);
