using System.IO;
using System.Windows;
using ModernWpf;

namespace WinTune.Gui;

public partial class App : Application
{
    public static string RepoRoot { get; } = FindRepoRoot();

    private static string FindRepoRoot()
    {
        var dir = AppContext.BaseDirectory;
        while (dir != null)
        {
            if (File.Exists(Path.Combine(dir, "src", "wintune.ps1")))
                return dir;
            dir = Path.GetDirectoryName(dir);
        }
        throw new DirectoryNotFoundException("Cannot find repo root (src/wintune.ps1)");
    }

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        ThemeManager.Current.ApplicationTheme = ApplicationTheme.Dark;
    }
}
