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

    private async void OnRefreshClick(object sender, System.Windows.RoutedEventArgs e)
    {
        var vm = (DashboardViewModel)DataContext;
        await vm.LoadAsync();
    }
}
