using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
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
        AuditBtn.Click += (_, _) => MainWindow.Instance?.NavigateTo("Audit");
        ApplyBtn.Click += (_, _) => MainWindow.Instance?.NavigateTo("Apply");
        RevertBtn.Click += (_, _) => MainWindow.Instance?.NavigateTo("Revert");
    }
}
