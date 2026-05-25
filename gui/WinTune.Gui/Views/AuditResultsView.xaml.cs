using System.Windows;
using System.Windows.Controls;
using WinTune.Gui.ViewModels;

namespace WinTune.Gui.Views;

public partial class AuditResultsView : UserControl
{
    public AuditResultsView()
    {
        InitializeComponent();
        Loaded += async (_, _) =>
        {
            var vm = (AuditResultsViewModel)DataContext;
            await vm.LoadAsync();
        };
    }

    private async void OnRunAuditClick(object sender, RoutedEventArgs e)
    {
        var vm = (AuditResultsViewModel)DataContext;
        await vm.LoadAsync();
    }
}
