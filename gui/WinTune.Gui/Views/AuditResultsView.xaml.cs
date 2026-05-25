using Microsoft.UI.Xaml.Controls;
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
        RunBtn.Click += async (_, _) =>
        {
            var vm = (AuditResultsViewModel)DataContext;
            await vm.LoadAsync();
        };
    }
}
