using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace WinTune.Gui.ViewModels;

public abstract class ViewModelBase : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;

    private bool _isLoading;
    public bool IsLoading
    {
        get => _isLoading;
        set { _isLoading = value; RaisePropertyChanged(); }
    }

    private string? _error;
    public string? Error
    {
        get => _error;
        set { _error = value; RaisePropertyChanged(); }
    }

    public bool HasError => !string.IsNullOrEmpty(Error);

    protected void RaisePropertyChanged([CallerMemberName] string? name = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
