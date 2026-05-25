using Microsoft.UI.Xaml.Controls;
using WinTune.Gui.ViewModels;

namespace WinTune.Gui.Views;

public partial class RevertView : UserControl
{
    public RevertView()
    {
        InitializeComponent();
        Loaded += async (_, _) =>
        {
            var vm = (RevertViewModel)DataContext;
            await vm.LoadAsync();
        };
    }
}
