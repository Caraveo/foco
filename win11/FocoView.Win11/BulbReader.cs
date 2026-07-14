using System.IO.Compression;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace FocoView.Win11;

internal sealed partial class BulbReader : IDisposable
{
    private readonly ZipArchive _archive;
    private readonly string _cache = Path.Combine(Path.GetTempPath(), "FocoView", Guid.NewGuid().ToString("N"));
    public BulbManifest Manifest { get; }

    public BulbReader(string path)
    {
        var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
        try
        {
            _archive = new ZipArchive(stream, ZipArchiveMode.Read);
            var entry = _archive.GetEntry("manifest.json") ?? throw new InvalidDataException("manifest.json is missing.");
            using var input = entry.Open();
            Manifest = JsonSerializer.Deserialize(input, BulbJsonContext.Default.BulbManifest)
                ?? throw new InvalidDataException("The bulb manifest is invalid.");
            Directory.CreateDirectory(_cache);
        }
        catch { stream.Dispose(); throw; }
    }

    public async Task<string> ReadPageAsync(Guid id)
    {
        var entry = _archive.GetEntry($"Pages/{id:D}.md") ?? _archive.GetEntry($"Pages/{id.ToString().ToUpperInvariant()}.md")
            ?? throw new InvalidDataException("The selected page is missing.");
        using var reader = new StreamReader(entry.Open());
        return await reader.ReadToEndAsync();
    }

    public async Task<string> ExtractAssetAsync(BulbAsset asset)
    {
        var safeName = Path.GetFileName(asset.StoredFilename);
        if (!StringComparer.Ordinal.Equals(safeName, asset.StoredFilename))
            throw new InvalidDataException("Unsafe asset path.");
        var output = Path.Combine(_cache, safeName);
        if (File.Exists(output)) return output;
        var entry = _archive.GetEntry($"Assets/{safeName}") ?? throw new InvalidDataException("The attachment is missing.");
        await using var input = entry.Open();
        await using var target = new FileStream(output, FileMode.CreateNew, FileAccess.Write, FileShare.Read);
        await input.CopyToAsync(target);
        return output;
    }

    public void Dispose()
    {
        _archive.Dispose();
        try { Directory.Delete(_cache, true); } catch { }
    }

    public static IReadOnlyList<ReaderBlock> Parse(string markdown)
    {
        var lines = markdown.Replace("\r\n", "\n").Split('\n');
        var result = new List<ReaderBlock>();
        for (var i = 0; i < lines.Length; i++)
        {
            var line = lines[i]; var trim = line.Trim();
            if (trim == "```")
            {
                var code = new List<string>();
                while (++i < lines.Length && lines[i].Trim() != "```") code.Add(lines[i]);
                result.Add(new(BlockKind.Code, string.Join('\n', code))); continue;
            }
            if (line.Contains('\t'))
            {
                var rows = new List<string[]>();
                while (i < lines.Length && lines[i].Contains('\t')) rows.Add(lines[i++].Split('\t'));
                i--; result.Add(new(BlockKind.Table, Rows: rows)); continue;
            }
            var match = AssetToken().Match(trim);
            if (match.Success && Guid.TryParse(match.Groups[1].Value, out var assetId)) result.Add(new(BlockKind.Asset, AssetId: assetId));
            else if (trim == "---") result.Add(new(BlockKind.Divider));
            else if (line.StartsWith("### ")) result.Add(new(BlockKind.Heading, line[4..], 3));
            else if (line.StartsWith("## ")) result.Add(new(BlockKind.Heading, line[3..], 2));
            else if (line.StartsWith("# ")) result.Add(new(BlockKind.Heading, line[2..], 1));
            else if (line.StartsWith("> Prompt:")) result.Add(new(BlockKind.Prompt, line[9..].Trim()));
            else if (line.StartsWith("> ")) result.Add(new(BlockKind.Quote, line[2..]));
            else if (line.StartsWith("☐ ") || line.StartsWith("☑ ")) result.Add(new(BlockKind.Todo, line[2..]));
            else if (line.StartsWith("- ") || line.StartsWith("• ")) result.Add(new(BlockKind.Bullet, line[2..]));
            else if (Numbered().IsMatch(line)) result.Add(new(BlockKind.Numbered, line));
            else if (trim.Length == 0) result.Add(new(BlockKind.Spacer));
            else result.Add(new(BlockKind.Paragraph, line));
        }
        return result;
    }

    [GeneratedRegex(@"^\[\[asset:([0-9A-Fa-f-]{36})\|[^\]\r\n]*\]\]$")]
    private static partial Regex AssetToken();
    [GeneratedRegex(@"^\d+\.\s+.+")]
    private static partial Regex Numbered();
}
