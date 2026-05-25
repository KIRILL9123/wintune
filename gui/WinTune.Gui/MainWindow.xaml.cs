using System.Linq;
using System.Windows;
using ModernWpf.Controls;

namespace WinTune.Gui;

public partial class MainWindow : Window
{
    public static MainWindow? Instance { get; private set; }

    public MainWindow()
    {
        Instance = this;
        InitializeComponent();
        Loaded += OnLoaded;
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        Nav.SelectionChanged += (_, args) =>
        {
            if (args.SelectedItem is NavigationViewItem item)
            {
                ShowView(item.Tag?.ToString());
            }
        };
        ShowView("Dashboard");
    }

    public void NavigateTo(string tag)
    {
        var item = Nav.MenuItems
            .OfType<NavigationViewItem>()
            .FirstOrDefault(i => i.Tag?.ToString() == tag);
        if (item != null)
            Nav.SelectedItem = item;
        ShowView(tag);
    }

    private void ShowView(string? tag)
    {
        DashboardView.Visibility = Visibility.Collapsed;
        ProfileSelectorView.Visibility = Visibility.Collapsed;
        AuditResultsView.Visibility = Visibility.Collapsed;
        ApplyProgressView.Visibility = Visibility.Collapsed;
        RevertView.Visibility = Visibility.Collapsed;

        switch (tag)
        {
            case "Profiles":
                ProfileSelectorView.Visibility = Visibility.Visible;
                break;
            case "Audit":
                AuditResultsView.Visibility = Visibility.Visible;
                break;
            case "Apply":
                ApplyProgressView.Visibility = Visibility.Visible;
                break;
            case "Revert":
                RevertView.Visibility = Visibility.Visible;
                break;
            default:
                DashboardView.Visibility = Visibility.Visible;
                break;
        }
    }
}
