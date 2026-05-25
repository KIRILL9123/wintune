using System.Linq;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
namespace WinTune.Gui;
public partial class MainWindow : Window
{
    public static MainWindow Instance { get; private set; }
    public MainWindow() { Instance = this; InitializeComponent(); Activated += (s, e) => { ((Window)s).Activated += null; Nav.SelectionChanged += (_, a) => { if (a.SelectedItem is NavigationViewItem i) ShowView(i.Tag?.ToString()); }; ShowView("Dashboard"); }; }
    public void NavigateTo(string tag) { var item = Nav.MenuItems.OfType<NavigationViewItem>().FirstOrDefault(i => i.Tag?.ToString() == tag); if (item != null) Nav.SelectedItem = item; ShowView(tag); }
    void ShowView(string tag) {
        DashboardView.Visibility = ProfileSelectorView.Visibility = AuditResultsView.Visibility = ApplyProgressView.Visibility = RevertView.Visibility = Visibility.Collapsed;
        switch (tag) { case "Profiles": ProfileSelectorView.Visibility = Visibility.Visible; break; case "Audit": AuditResultsView.Visibility = Visibility.Visible; break; case "Apply": ApplyProgressView.Visibility = Visibility.Visible; break; case "Revert": RevertView.Visibility = Visibility.Visible; break; default: DashboardView.Visibility = Visibility.Visible; break; }
    }
}
