using System;
using System.Collections.ObjectModel;
using System.Text.Json;
using System.Threading.Tasks;
using WinTune.Gui.Services;

namespace WinTune.Gui.ViewModels;

public sealed class ProfileSelectorViewModel : ViewModelBase
{
    public ObservableCollection<ProfileCard> Profiles { get; } = new();

    public async Task LoadAsync()
    {
        IsLoading = true;
        Error = null;

        try
        {
            var runner = new PsRunner(App.RepoRoot);
            var result = await runner.RunAsync("List");

            if (result.ExitCode != 0)
            {
                Error = $"Process exited with code {result.ExitCode}";
                return;
            }

            var doc = JsonDocument.Parse(result.StdOut);

            Profiles.Clear();
            foreach (var p in doc.RootElement.EnumerateArray())
            {
                var name = p.GetProperty("Name").GetString() ?? "?";
                var desc = p.GetProperty("Description").GetString() ?? "";
                var count = p.GetProperty("TweakCount").GetInt32();
                var dangerous = p.GetProperty("Dangerous").GetBoolean();

                Profiles.Add(new ProfileCard(name, desc, count, dangerous));
            }
        }
        catch (OperationCanceledException)
        {
            Error = "Loading profiles timed out.";
        }
        catch (JsonException ex)
        {
            Error = $"Failed to parse output: {ex.Message}";
        }
        catch (Exception ex)
        {
            Error = ex.Message;
        }
        finally
        {
            IsLoading = false;
        }
    }
}

public sealed record ProfileCard(string Name, string Description, int TweakCount, bool Dangerous);
