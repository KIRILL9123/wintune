using System.Windows;
using System.Windows.Controls;
using WinTune.Gui.ViewModels;

namespace WinTune.Gui.Views;

public partial class ProfileSelectorView : UserControl
{
    public ProfileSelectorView()
    {
        InitializeComponent();
        Loaded += async (_, _) =>
        {
            var vm = (ProfileSelectorViewModel)DataContext;
            await vm.LoadAsync();
        };
    }

    private void OnSelectProfileClick(object sender, RoutedEventArgs e)
    {
        MainWindow.Instance?.NavigateTo("Audit");
    }
}
