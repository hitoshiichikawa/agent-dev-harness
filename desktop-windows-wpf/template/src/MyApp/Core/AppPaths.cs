using System.IO;

namespace MyApp.Core;

/// <summary>書き込み先は LocalApplicationData 配下のみ。MSIX でも Velopack でも同じ。</summary>
public static class AppPaths
{
    private static readonly string Root =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "MyApp");

    public static string Data => Ensure(Path.Combine(Root, "data"));
    public static string Logs => Ensure(Path.Combine(Root, "logs"));

    private static string Ensure(string dir)
    {
        Directory.CreateDirectory(dir);
        return dir;
    }
}
