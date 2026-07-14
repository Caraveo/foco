using Microsoft.UI.Xaml;

namespace FocoView.Win11;

public partial class App : Application
{
    private MainWindow? _window;

    public App() => InitializeComponent();

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        _window = new MainWindow();
        _window.Activate();

        var file = Environment.GetCommandLineArgs().Skip(1)
            .FirstOrDefault(path => path.EndsWith(".bulb", StringComparison.OrdinalIgnoreCase));
        if (file is not null)
            _ = _window.OpenBulbAsync(file);
    }
}
