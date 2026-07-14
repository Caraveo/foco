using System.Text.Json.Serialization;

namespace FocoView.Win11;

public sealed record BulbPage(Guid Id, string Title, string? Content, IReadOnlyList<Guid>? AssetIDs);
public sealed record BulbAsset(Guid Id, string Filename, string MediaType, string StoredFilename, long? ByteSize);
public sealed record BulbManifest(int Version, string Title, IReadOnlyList<BulbPage> Pages, IReadOnlyList<BulbAsset> Assets);

[JsonSourceGenerationOptions(PropertyNameCaseInsensitive = true)]
[JsonSerializable(typeof(BulbManifest))]
internal partial class BulbJsonContext : JsonSerializerContext;

internal enum BlockKind { Heading, Paragraph, Quote, Prompt, Bullet, Numbered, Todo, Divider, Code, Table, Asset, Spacer }
internal sealed record ReaderBlock(BlockKind Kind, string Text = "", int Level = 0, Guid? AssetId = null, IReadOnlyList<string[]>? Rows = null);
