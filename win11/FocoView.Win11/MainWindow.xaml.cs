using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using System.Diagnostics;
using Windows.Media.Core;
using Windows.Storage.Pickers;
using Windows.UI;
using WinRT.Interop;

namespace FocoView.Win11;

public sealed partial class MainWindow : Window
{
    private BulbReader? _reader;

    public MainWindow()
    {
        InitializeComponent();
        ExtendsContentIntoTitleBar = true;
        SetTitleBar(AppTitleBar);
        var hwnd = WindowNative.GetWindowHandle(this);
        var id = Win32Interop.GetWindowIdFromWindow(hwnd);
        AppWindow.GetFromWindowId(id).Resize(new Windows.Graphics.SizeInt32(1120, 760));
        Closed += (_, _) => _reader?.Dispose();
    }

    private async void Open_Click(object sender, RoutedEventArgs e)
    {
        var picker = new FileOpenPicker();
        picker.FileTypeFilter.Add(".bulb");
        InitializeWithWindow.Initialize(picker, WindowNative.GetWindowHandle(this));
        var file = await picker.PickSingleFileAsync();
        if (file is not null) await OpenBulbAsync(file.Path);
    }

    public async Task OpenBulbAsync(string path)
    {
        SetLoading(true);
        try
        {
            var opened = await Task.Run(() => new BulbReader(path));
            _reader?.Dispose(); _reader = opened;
            Title = $"{opened.Manifest.Title} — Foco View";
            TitleText.Text = opened.Manifest.Title;
            PagesList.ItemsSource = opened.Manifest.Pages;
            if (opened.Manifest.Pages.Count > 0) PagesList.SelectedIndex = 0;
            else ShowEmpty();
        }
        catch (Exception ex)
        {
            ShowEmpty();
            await new ContentDialog { XamlRoot = Content.XamlRoot, Title = "Couldn’t open bulb", Content = ex.Message, CloseButtonText = "OK" }.ShowAsync();
        }
        finally { LoadingRing.IsActive = false; LoadingRing.Visibility = Visibility.Collapsed; }
    }

    private async void PagesList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_reader is null || PagesList.SelectedItem is not BulbPage page) return;
        SetLoading(true);
        try
        {
            var markdown = await _reader.ReadPageAsync(page.Id);
            ReaderPanel.Children.Clear();
            ReaderPanel.Children.Add(new TextBlock { Text = "◉  READ ONLY", FontSize = 10, CharacterSpacing = 70, Opacity = .55, Margin = new(0, 0, 0, 16) });
            ReaderPanel.Children.Add(new TextBlock { Text = string.IsNullOrWhiteSpace(page.Title) ? "Untitled" : page.Title, FontSize = 40, FontWeight = Microsoft.UI.Text.FontWeights.Bold, TextWrapping = TextWrapping.Wrap, Margin = new(0, 0, 0, 26) });
            foreach (var block in BulbReader.Parse(markdown)) ReaderPanel.Children.Add(await MakeBlockAsync(block));
            EmptyState.Visibility = Visibility.Collapsed; ReaderScroll.Visibility = Visibility.Visible;
            ReaderScroll.ChangeView(null, 0, null, true);
        }
        catch (Exception ex)
        {
            await new ContentDialog { XamlRoot = Content.XamlRoot, Title = "Couldn’t read page", Content = ex.Message, CloseButtonText = "OK" }.ShowAsync();
        }
        finally { LoadingRing.IsActive = false; LoadingRing.Visibility = Visibility.Collapsed; }
    }

    private async Task<UIElement> MakeBlockAsync(ReaderBlock block)
    {
        var text = new TextBlock { Text = block.Text, TextWrapping = TextWrapping.Wrap, IsTextSelectionEnabled = true, FontSize = 16, LineHeight = 25, Margin = new(0, 3, 0, 3) };
        switch (block.Kind)
        {
            case BlockKind.Heading:
                text.FontSize = block.Level == 1 ? 29 : block.Level == 2 ? 23 : 18;
                text.FontWeight = block.Level == 1 ? Microsoft.UI.Text.FontWeights.Bold : Microsoft.UI.Text.FontWeights.SemiBold;
                text.Margin = new(0, 14, 0, 7); return text;
            case BlockKind.Quote:
                text.FontStyle = Windows.UI.Text.FontStyle.Italic; text.Opacity = .7;
                return Box(text, new Thickness(15, 7, 12, 7), leftAccent: true);
            case BlockKind.Prompt:
                text.Text = "✦  " + (string.IsNullOrWhiteSpace(block.Text) ? "Prompt" : block.Text);
                return new Border { Child = text, Padding = new(14), Margin = new(0, 6, 0, 6), CornerRadius = new(8), Background = AccentBrush(.09), BorderBrush = AccentBrush(.65), BorderThickness = new(3, 0, 0, 0) };
            case BlockKind.Bullet: text.Text = "•    " + block.Text; return text;
            case BlockKind.Todo: text.Text = "☐    " + block.Text; return text;
            case BlockKind.Numbered: case BlockKind.Paragraph: return text;
            case BlockKind.Divider: return new Border { Height = 1, Background = new SolidColorBrush(Colors.Gray), Opacity = .25, Margin = new(0, 15, 0, 15) };
            case BlockKind.Spacer: return new Border { Height = 7 };
            case BlockKind.Code:
                text.FontFamily = new FontFamily("Cascadia Mono"); text.FontSize = 14;
                return Box(text, new Thickness(15), false);
            case BlockKind.Table: return MakeTable(block.Rows ?? []);
            case BlockKind.Asset: return await MakeAssetAsync(block.AssetId);
            default: return text;
        }
    }

    private async Task<UIElement> MakeAssetAsync(Guid? id)
    {
        var asset = _reader?.Manifest.Assets.FirstOrDefault(a => a.Id == id);
        if (asset is null) return new InfoBar { Severity = InfoBarSeverity.Warning, IsOpen = true, Message = "Missing attachment" };
        var path = await _reader!.ExtractAssetAsync(asset);
        FrameworkElement preview;
        if (asset.MediaType.Equals("image", StringComparison.OrdinalIgnoreCase))
            preview = new Image { Source = new BitmapImage(new Uri(path)), MaxHeight = 430, Stretch = Stretch.Uniform };
        else if (asset.MediaType.Equals("video", StringComparison.OrdinalIgnoreCase) || asset.MediaType.Equals("audio", StringComparison.OrdinalIgnoreCase))
            preview = new MediaPlayerElement { Source = MediaSource.CreateFromUri(new Uri(path)), AreTransportControlsEnabled = true, Height = asset.MediaType.Equals("audio", StringComparison.OrdinalIgnoreCase) ? 88 : 400 };
        else
            preview = new Button { Content = $"Open {asset.Filename}", HorizontalAlignment = HorizontalAlignment.Left, Margin = new(18), CommandParameter = path };
        if (preview is Button button) button.Click += (_, _) => Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
        var panel = new StackPanel(); panel.Children.Add(preview);
        panel.Children.Add(new TextBlock { Text = asset.ByteSize is long bytes ? $"{asset.Filename}  ·  {FormatBytes(bytes)}" : asset.Filename, FontSize = 12, Opacity = .65, Margin = new(12, 10, 12, 10) });
        return new Border { Child = panel, BorderBrush = new SolidColorBrush(Colors.Gray), BorderThickness = new(1), CornerRadius = new(9), Margin = new(0, 10, 0, 10) };
    }

    private static UIElement MakeTable(IReadOnlyList<string[]> rows)
    {
        var grid = new Grid { Margin = new(0, 8, 0, 8) };
        var columns = rows.Count == 0 ? 0 : rows.Max(r => r.Length);
        for (var c = 0; c < columns; c++) grid.ColumnDefinitions.Add(new() { Width = new GridLength(1, GridUnitType.Star) });
        for (var r = 0; r < rows.Count; r++)
        {
            grid.RowDefinitions.Add(new() { Height = GridLength.Auto });
            for (var c = 0; c < rows[r].Length; c++)
            {
                var cell = new Border { BorderBrush = new SolidColorBrush(Colors.Gray), BorderThickness = new(1), Padding = new(10, 7, 10, 7), Child = new TextBlock { Text = rows[r][c], TextWrapping = TextWrapping.Wrap } };
                Grid.SetRow(cell, r); Grid.SetColumn(cell, c); grid.Children.Add(cell);
            }
        }
        return grid;
    }

    private static Border Box(UIElement child, Thickness padding, bool leftAccent) => new() { Child = child, Padding = padding, Margin = new(0, 5, 0, 5), CornerRadius = new(8), Background = new SolidColorBrush(Color.FromArgb(14, 128, 128, 128)), BorderBrush = new SolidColorBrush(Color.FromArgb(70, 128, 128, 128)), BorderThickness = leftAccent ? new(3, 0, 0, 0) : new(1) };
    private static SolidColorBrush AccentBrush(double opacity) { var b = new SolidColorBrush(Colors.DodgerBlue) { Opacity = opacity }; return b; }
    private static string FormatBytes(long bytes) => bytes < 1024 * 1024 ? $"{bytes / 1024d:0.#} KB" : $"{bytes / 1024d / 1024d:0.#} MB";
    private void SetLoading(bool value) { EmptyState.Visibility = Visibility.Collapsed; ReaderScroll.Visibility = Visibility.Collapsed; LoadingRing.Visibility = value ? Visibility.Visible : Visibility.Collapsed; LoadingRing.IsActive = value; }
    private void ShowEmpty() { ReaderScroll.Visibility = Visibility.Collapsed; LoadingRing.Visibility = Visibility.Collapsed; EmptyState.Visibility = Visibility.Visible; }
}
