using System;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;

namespace WinTune.Gui.ViewModels;

public sealed class RevertViewModel : ViewModelBase
{
    public ObservableCollection<RevertSession> Sessions { get; } = new();

    public bool IsEmpty => !IsLoading && Sessions.Count == 0 && string.IsNullOrEmpty(Error);

    public async Task LoadAsync()
    {
        IsLoading = true;
        Error = null;

        try
        {
            var backupDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "WinTune", "backups");

            if (!Directory.Exists(backupDir))
            {
                RaisePropertyChanged(nameof(IsEmpty));
                return;
            }

            var dirs = Directory.GetDirectories(backupDir)
                .Select(Path.GetFileName)
                .Where(n => n != null)
                .OrderByDescending(n => n)
                .Take(50);

            Sessions.Clear();

            await Task.Run(() =>
            {
                foreach (var dir in dirs)
                {
                    var manifestPath = Path.Combine(backupDir, dir!, "manifest.json");
                    if (!File.Exists(manifestPath))
                        continue;

                    try
                    {
                        var json = File.ReadAllText(manifestPath);
                        var doc = JsonDocument.Parse(json);
                        var root = doc.RootElement;

                        var profile = root.GetProperty("Profile").GetString() ?? "?";
                        var createdAt = root.TryGetProperty("CreatedAt", out var ca)
                            ? ca.GetString()
                            : null;
                        var changeCount = root.TryGetProperty("Changes", out var ch)
                            ? ch.GetArrayLength()
                            : 0;
                        var successCount = root.TryGetProperty("Changes", out var ch2)
                            ? ch2.EnumerateArray().Count(c => c.TryGetProperty("Success", out var s) && s.GetBoolean())
                            : 0;

                        var timestamp = createdAt != null
                            ? DateTime.Parse(createdAt)
                            : DateTime.MinValue;

                        Sessions.Add(new RevertSession(dir!, profile, timestamp, changeCount, successCount));
                    }
                    catch
                    {
                    }
                }
            });
        }
        catch (Exception ex)
        {
            Error = ex.Message;
        }
        finally
        {
            IsLoading = false;
            RaisePropertyChanged(nameof(IsEmpty));
        }
    }
}

public sealed record RevertSession(
    string SessionId,
    string ProfileName,
    DateTime Timestamp,
    int ChangeCount,
    int SuccessCount);
