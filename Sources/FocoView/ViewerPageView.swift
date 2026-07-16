import Foundation
import SwiftUI

struct ViewerBlock: Identifiable {
    enum Kind {
        case heading(Int, String)
        case paragraph(String)
        case quote(String)
        case prompt(String)
        case bullet(String)
        case numbered(String)
        case todo(String)
        case divider
        case code(String)
        case formula(String)
        case table([[String]])
        case structured(ViewerStructuredBlock)
        case asset(UUID)
        case spacer
    }

    let id = UUID()
    let kind: Kind
}

enum ViewerBlockParser {
    static func parse(_ content: String, structuredBlocks: [ViewerStructuredBlock] = []) -> [ViewerBlock] {
        let lines = content.components(separatedBy: "\n")
        let structuredByID = Dictionary(uniqueKeysWithValues: structuredBlocks.map { ($0.id, $0) })
        var blocks: [ViewerBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "```" {
                var code: [String] = []
                index += 1
                while index < lines.count && lines[index].trimmingCharacters(in: .whitespaces) != "```" {
                    code.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                blocks.append(ViewerBlock(kind: .code(code.joined(separator: "\n"))))
                continue
            }

            if trimmed == "$$" {
                var formula: [String] = []
                index += 1
                while index < lines.count && lines[index].trimmingCharacters(in: .whitespaces) != "$$" {
                    formula.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                blocks.append(ViewerBlock(kind: .formula(formula.joined(separator: "\n"))))
                continue
            }

            if line.contains("\t") {
                var rows: [[String]] = []
                while index < lines.count && lines[index].contains("\t") {
                    rows.append(lines[index].components(separatedBy: "\t"))
                    index += 1
                }
                blocks.append(ViewerBlock(kind: .table(rows)))
                continue
            }

            if let blockID = ViewerStructuredBlockSyntax.id(in: trimmed),
               let structured = structuredByID[blockID] {
                blocks.append(ViewerBlock(kind: .structured(structured)))
            } else if let assetID = assetID(in: trimmed) {
                blocks.append(ViewerBlock(kind: .asset(assetID)))
            } else if trimmed == "---" {
                blocks.append(ViewerBlock(kind: .divider))
            } else if line.hasPrefix("### ") {
                blocks.append(ViewerBlock(kind: .heading(3, String(line.dropFirst(4)))))
            } else if line.hasPrefix("## ") {
                blocks.append(ViewerBlock(kind: .heading(2, String(line.dropFirst(3)))))
            } else if line.hasPrefix("# ") {
                blocks.append(ViewerBlock(kind: .heading(1, String(line.dropFirst(2)))))
            } else if line.hasPrefix("> Prompt:") {
                blocks.append(ViewerBlock(kind: .prompt(String(line.dropFirst("> Prompt:".count)).trimmingCharacters(in: .whitespaces))))
            } else if line.hasPrefix("> ") {
                blocks.append(ViewerBlock(kind: .quote(String(line.dropFirst(2)))))
            } else if line.hasPrefix("☐ ") || line.hasPrefix("☑ ") {
                blocks.append(ViewerBlock(kind: .todo(String(line.dropFirst(2)))))
            } else if line.hasPrefix("- ") || line.hasPrefix("• ") {
                blocks.append(ViewerBlock(kind: .bullet(String(line.dropFirst(2)))))
            } else if isNumbered(line) {
                blocks.append(ViewerBlock(kind: .numbered(line)))
            } else if trimmed.isEmpty {
                if blocks.last.map({ if case .spacer = $0.kind { true } else { false } }) != true {
                    blocks.append(ViewerBlock(kind: .spacer))
                }
            } else {
                blocks.append(ViewerBlock(kind: .paragraph(line)))
            }
            index += 1
        }
        return blocks
    }

    private static func assetID(in line: String) -> UUID? {
        guard let regex = try? NSRegularExpression(
            pattern: #"^\[\[asset:([0-9A-Fa-f-]{36})\|[^\]\r\n]*\]\]$"#
        ), let match = regex.firstMatch(
            in: line,
            range: NSRange(location: 0, length: (line as NSString).length)
        ), match.range(at: 1).location != NSNotFound else { return nil }
        return UUID(uuidString: (line as NSString).substring(with: match.range(at: 1)))
    }

    private static func isNumbered(_ line: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: #"^\d+\.\s+.+"#) else { return false }
        return regex.firstMatch(
            in: line,
            range: NSRange(location: 0, length: (line as NSString).length)
        ) != nil
    }
}

struct ViewerPageView: View {
    let page: ViewerLoadedPage
    @ObservedObject var document: ViewerDocument

    private var blocks: [ViewerBlock] {
        ViewerBlockParser.parse(page.content, structuredBlocks: page.blocks)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "eye")
                    Text("READ ONLY")
                }
                .font(.system(size: 9, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 16)

                Text(page.summary.title.isEmpty ? "Untitled" : page.summary.title)
                    .font(.system(size: 40, weight: .bold))
                    .tracking(-1)
                    .padding(.bottom, 26)

                ForEach(blocks) { block in
                    ViewerBlockView(block: block, document: document)
                }

                Spacer().frame(height: 120)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 64)
            .padding(.top, 54)
            .frame(maxWidth: .infinity)
            .textSelection(.enabled)
        }
        .scrollIndicators(.hidden)
    }
}

private struct ViewerBlockView: View {
    let block: ViewerBlock
    @ObservedObject var document: ViewerDocument

    @ViewBuilder
    var body: some View {
        switch block.kind {
        case .heading(let level, let value):
            Text(linked(value))
                .font(headingFont(level))
                .padding(.top, level == 1 ? 17 : 12)
                .padding(.bottom, 7)
        case .paragraph(let value):
            Text(linked(value))
                .font(.system(size: 16))
                .lineSpacing(4)
                .padding(.vertical, 4)
        case .quote(let value):
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 3)
                Text(linked(value))
                    .font(.system(size: 16).italic())
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }
            .padding(.vertical, 4)
        case .prompt(let value):
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 1)
                Text(linked(value.isEmpty ? "Prompt" : value))
                    .font(.system(size: 15, weight: .medium))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor)
                    .frame(width: 3)
            }
            .padding(.vertical, 6)
        case .bullet(let value):
            row(marker: "•", value: value)
        case .numbered(let value):
            Text(linked(value))
                .font(.system(size: 16))
                .padding(.leading, 4)
                .padding(.vertical, 3)
        case .todo(let value):
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Image(systemName: "square")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor)
                Text(linked(value)).font(.system(size: 16))
            }
            .padding(.vertical, 3)
        case .divider:
            Divider().padding(.vertical, 15)
        case .code(let value):
            ScrollView(.horizontal) {
                Text(value)
                    .font(.system(size: 14, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(15)
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.primary.opacity(0.08)))
            .padding(.vertical, 7)
        case .formula(let value):
            Text(value.isEmpty ? "E = mc^2" : value)
                .font(.system(size: 20, weight: .regular, design: .serif).italic())
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.accentColor.opacity(0.5))
                        .frame(width: 3)
                }
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08)))
                .padding(.vertical, 7)
        case .table(let rows):
            ViewerTable(rows: rows).padding(.vertical, 8)
        case .structured(let structured):
            ViewerStructuredBlockView(block: structured, document: document)
        case .asset(let id):
            if let asset = document.asset(id) {
                ViewerAssetCard(asset: asset, document: document)
                    .padding(.vertical, 10)
            } else {
                Label("Missing attachment", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                    .padding(14)
            }
        case .spacer:
            Spacer().frame(height: 7)
        }
    }

    private func row(marker: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(marker).frame(width: 12)
            Text(linked(value)).font(.system(size: 16))
        }
        .padding(.vertical, 3)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .system(size: 29, weight: .bold)
        case 2: .system(size: 23, weight: .semibold)
        default: .system(size: 18, weight: .semibold)
        }
    }

    private func linked(_ text: String) -> AttributedString {
        if text.contains("](") && text.contains("http"),
           let markdown = try? AttributedString(markdown: text) {
            return markdown
        }
        var attributed = AttributedString(text)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return attributed
        }
        let matches = detector.matches(
            in: text,
            range: NSRange(location: 0, length: (text as NSString).length)
        )
        for match in matches {
            guard let url = match.url,
                  let stringRange = Range(match.range, in: text),
                  let lower = AttributedString.Index(stringRange.lowerBound, within: attributed),
                  let upper = AttributedString.Index(stringRange.upperBound, within: attributed) else { continue }
            attributed[lower..<upper].link = url
            attributed[lower..<upper].foregroundColor = .accentColor
            attributed[lower..<upper].underlineStyle = .single
        }
        return attributed
    }
}

private struct ViewerTable: View {
    let rows: [[String]]
    private var columnCount: Int { max(1, rows.map(\.count).max() ?? 1) }

    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                GridRow {
                    ForEach(0..<columnCount, id: \.self) { columnIndex in
                        Text(columnIndex < row.count ? row[columnIndex] : "")
                            .font(.system(size: 13, weight: rowIndex == 0 ? .semibold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                            .padding(.horizontal, 10)
                            .background(rowIndex == 0 ? Color.accentColor.opacity(0.07) : .clear)
                            .overlay(Rectangle().stroke(Color.primary.opacity(0.10), lineWidth: 0.5))
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.10)))
    }
}
