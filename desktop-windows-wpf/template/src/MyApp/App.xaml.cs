using System.IO;
using System.Windows;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using MyApp.Core;
using MyApp.Domain.Data;
using MyApp.Domain.Repositories;
using MyApp.Domain.Services;
using MyApp.Features.Example;
using Serilog;
using Velopack;

namespace MyApp;

/// <summary>Host の組み立てと MainWindow 表示だけ。ロジックを置かない。</summary>
public partial class App : Application
{
    private IHost? _host;

    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        VelopackApp.Build().Run(); // Velopack レーンでなくても害はない（Store では no-op）

        _host = Host.CreateDefaultBuilder(e.Args)
            .UseSerilog((ctx, cfg) => cfg
                .ReadFrom.Configuration(ctx.Configuration)
                .WriteTo.File(Path.Combine(AppPaths.Logs, "app-.log"), rollingInterval: RollingInterval.Day))
            .ConfigureServices((ctx, services) =>
            {
                services.Configure<AppOptions>(ctx.Configuration.GetSection("App"));
                services.AddDbContextFactory<AppDbContext>((sp, opt) =>
                {
                    var o = sp.GetRequiredService<IOptions<AppOptions>>().Value;
                    opt.UseSqlite($"Data Source={Path.Combine(AppPaths.Data, o.DatabaseFileName)}");
                });
                services.AddSingleton<IExampleRepository, EfExampleRepository>();
                services.AddSingleton<ExampleService>();
                services.AddSingleton<IDialogService, DialogService>();
                services.AddTransient<ExampleViewModel>();
                services.AddTransient<MainWindow>();
            })
            .Build();

        await _host.StartAsync();

        // マイグレーションは起動時に適用。手動 `database update` はしない
        var factory = _host.Services.GetRequiredService<IDbContextFactory<AppDbContext>>();
        await using (var db = await factory.CreateDbContextAsync())
        {
            await db.Database.MigrateAsync();
        }

        _host.Services.GetRequiredService<MainWindow>().Show();
    }

    protected override async void OnExit(ExitEventArgs e)
    {
        if (_host is not null)
        {
            await _host.StopAsync();
            _host.Dispose();
        }

        base.OnExit(e);
    }
}

public sealed class AppOptions
{
    public string DatabaseFileName { get; set; } = "myapp.db";
    public bool CheckForUpdates { get; set; } = true;
}
