using System.Windows;
using System.Windows.Controls;
using WinTune.Gui.ViewModels;

namespace WinTune.Gui.Views;

public partial class DashboardView : UserControl
{
    public DashboardView()
    {
        InitializeComponent();
        Loaded += async (_, _) =>
        {
            var vm = (DashboardViewModel)DataContext;
            await vm.LoadAsync();
        };
    }

    private async void OnRefreshClick(object sender, RoutedEventArgs e)
    {
        var vm = (DashboardViewModel)DataContext;
        await vm.LoadAsync();
    }

    private void OnAuditClick(object sender, RoutedEventArgs e)
    {
        MainWindow.Instance?.NavigateTo("Audit");
    }

    private void OnApplyClick(object sender, RoutedEventArgs e)
    {
        MainWindow.Instance?.NavigateTo("Apply");
    }

    private void OnRevertClick(object sender, RoutedEventArgs e)
    {
        MainWindow.Instance?.NavigateTo("Revert");
    }
}
