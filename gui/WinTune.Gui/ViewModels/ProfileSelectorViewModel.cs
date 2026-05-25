using System.Collections.ObjectModel;

namespace WinTune.Gui.ViewModels;

public sealed class ProfileSelectorViewModel : ViewModelBase
{
    public ObservableCollection<ProfileCard> Profiles { get; } = new()
    {
        new ProfileCard("Gaming", "Optimized for gaming. Keeps Xbox services, removes telemetry."),
        new ProfileCard("Workstation", "Balanced profile for productivity and stability."),
        new ProfileCard("Laptop", "Battery-friendly tweaks with reduced background tasks."),
        new ProfileCard("Minimal", "Maximum debloat, removes most non-essential components.")
    };
}

public sealed record ProfileCard(string Name, string Description);
