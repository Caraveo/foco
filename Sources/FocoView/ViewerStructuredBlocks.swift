import AppKit
import SwiftUI

enum ViewerStructuredBlockKind: String, Codable, Sendable {
    case table, board, calendar, list, gallery, timeline
}

struct ViewerTableColumn: Codable, Identifiable, Sendable { let id: UUID; let name: String }
struct ViewerTableRow: Codable, Identifiable, Sendable { let id: UUID; let cells: [String] }
struct ViewerBoardCard: Codable, Identifiable, Sendable { let id: UUID; let title: String; let note: String }
struct ViewerBoardColumn: Codable, Identifiable, Sendable { let id: UUID; let title: String; let cards: [ViewerBoardCard] }
struct ViewerCalendarEvent: Codable, Identifiable, Sendable { let id: UUID; let date: String; let time: String; let title: String }
struct ViewerListItem: Codable, Identifiable, Sendable { let id: UUID; let title: String; let note: String; let tag: String; let isComplete: Bool }
struct ViewerGalleryItem: Codable, Identifiable, Sendable { let id: UUID; let title: String; let caption: String; let assetID: UUID? }
struct ViewerTimelineItem: Codable, Identifiable, Sendable { let id: UUID; let date: String; let title: String; let detail: String }

struct ViewerStructuredBlock: Codable, Identifiable, Sendable {
    let schemaVersion: Int
    let id: UUID
    let kind: ViewerStructuredBlockKind
    let title: String
    let tableColumns: [ViewerTableColumn]
    let tableRows: [ViewerTableRow]
    let boardColumns: [ViewerBoardColumn]
    let calendarMonth: String
    let calendarEvents: [ViewerCalendarEvent]
    let listItems: [ViewerListItem]
    let galleryItems: [ViewerGalleryItem]
    let timelineItems: [ViewerTimelineItem]
}

struct ViewerStructuredBlockReference: Sendable {
    let id: UUID
    let kind: ViewerStructuredBlockKind
}

enum ViewerStructuredBlockSyntax {
    static func references(in content: String) -> [ViewerStructuredBlockReference] {
        guard let regex = try? NSRegularExpression(
            pattern: #"\[\[block:([0-9A-Fa-f-]{36})\|(table|board|calendar|list|gallery|timeline)\]\]"#
        ) else { return [] }
        let source = content as NSString
        return regex.matches(
            in: content,
            range: NSRange(location: 0, length: source.length)
        ).compactMap { match in
            guard let id = UUID(uuidString: source.substring(with: match.range(at: 1))),
                  let kind = ViewerStructuredBlockKind(rawValue: source.substring(with: match.range(at: 2))) else { return nil }
            return ViewerStructuredBlockReference(id: id, kind: kind)
        }
    }

    static func id(in line: String) -> UUID? {
        references(in: line).first?.id
    }
}

private enum ViewerBlockDate {
    static func date(_ key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return Calendar.current.date(from: DateComponents(
            year: parts[0], month: parts[1], day: parts.count > 2 ? parts[2] : 1
        ))
    }

    static func dayKey(_ date: Date) -> String {
        let values = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", values.year ?? 1970, values.month ?? 1, values.day ?? 1)
    }

    static func monthKey(_ date: Date) -> String {
        let values = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", values.year ?? 1970, values.month ?? 1)
    }

    static func monthDays(_ key: String) -> [Date?] {
        guard let start = date(key), let range = Calendar.current.range(of: .day, in: .month, for: start) else { return [] }
        let weekday = Calendar.current.component(.weekday, from: start)
        var result = Array<Date?>(repeating: nil, count: max(0, weekday - 1))
        for day in range { result.append(Calendar.current.date(bySetting: .day, value: day, of: start)) }
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    static func shiftedMonth(_ key: String, _ amount: Int) -> String {
        guard let value = date(key), let shifted = Calendar.current.date(byAdding: .month, value: amount, to: value) else { return key }
        return monthKey(shifted)
    }
}

struct ViewerStructuredBlockView: View {
    let block: ViewerStructuredBlock
    @ObservedObject var document: ViewerDocument

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 7))
                Text(block.title).font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .bold)).tracking(0.7).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .frame(height: 45)
            Divider()
            content.padding(12)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.10)))
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        switch block.kind {
        case .table: table
        case .board: board
        case .calendar: ViewerCalendarBlock(block: block)
        case .list: list
        case .gallery: gallery
        case .timeline: timeline
        }
    }

    private var table: some View {
        ScrollView(.horizontal) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(block.tableColumns) { column in
                        Text(column.name)
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 164, height: 34, alignment: .leading)
                            .padding(.horizontal, 9)
                            .background(Color.accentColor.opacity(0.07))
                            .overlay(Rectangle().stroke(Color.primary.opacity(0.09), lineWidth: 0.5))
                    }
                }
                ForEach(block.tableRows) { row in
                    HStack(spacing: 0) {
                        ForEach(block.tableColumns.indices, id: \.self) { index in
                            Text(row.cells.indices.contains(index) ? row.cells[index] : "")
                                .font(.system(size: 12))
                                .frame(width: 164, height: 36, alignment: .leading)
                                .padding(.horizontal, 9)
                                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                                .overlay(Rectangle().stroke(Color.primary.opacity(0.09), lineWidth: 0.5))
                        }
                    }
                }
            }
        }
    }

    private var board: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(block.boardColumns.enumerated()), id: \.element.id) { index, column in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle().fill(boardColor(index)).frame(width: 7, height: 7)
                            Text(column.title).font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text("\(column.cards.count)").font(.system(size: 9)).foregroundStyle(.tertiary)
                        }
                        ForEach(column.cards) { card in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(card.title).font(.system(size: 12, weight: .medium))
                                if !card.note.isEmpty { Text(card.note).font(.system(size: 10)).foregroundStyle(.secondary) }
                            }
                            .padding(9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(9)
                    .frame(width: 202, alignment: .topLeading)
                    .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 9))
                }
            }
        }
    }

    private var list: some View {
        VStack(spacing: 4) {
            ForEach(block.listItems) { item in
                HStack(spacing: 9) {
                    Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.isComplete ? Color.accentColor : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.system(size: 12, weight: .medium)).strikethrough(item.isComplete)
                        if !item.note.isEmpty { Text(item.note).font(.system(size: 10)).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    if !item.tag.isEmpty {
                        Text(item.tag).font(.system(size: 9, weight: .medium)).padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.08), in: Capsule())
                    }
                }
                .padding(.horizontal, 9)
                .frame(minHeight: 42)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var gallery: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(block.galleryItems) { item in
                VStack(alignment: .leading, spacing: 6) {
                    if let id = item.assetID, let asset = document.asset(id) {
                        ViewerGalleryImage(asset: asset, document: document).frame(height: 130).clipped()
                    } else {
                        Image(systemName: "photo").font(.system(size: 24)).foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity).frame(height: 130)
                            .background(Color.primary.opacity(0.035))
                    }
                    Text(item.title).font(.system(size: 12, weight: .semibold))
                    if !item.caption.isEmpty { Text(item.caption).font(.system(size: 10)).foregroundStyle(.secondary) }
                }
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 9))
            }
        }
    }

    private var timeline: some View {
        VStack(spacing: 0) {
            ForEach(Array(block.timelineItems.sorted { $0.date < $1.date }.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 0) {
                        Circle().fill(Color.accentColor).frame(width: 10, height: 10)
                        if index < block.timelineItems.count - 1 { Rectangle().fill(Color.accentColor.opacity(0.22)).frame(width: 2, height: 48) }
                    }
                    Text(ViewerBlockDate.date(item.date)?.formatted(date: .abbreviated, time: .omitted) ?? item.date)
                        .font(.system(size: 10, weight: .medium)).frame(width: 88, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title).font(.system(size: 12, weight: .semibold))
                        if !item.detail.isEmpty { Text(item.detail).font(.system(size: 10)).foregroundStyle(.secondary) }
                    }
                    Spacer()
                }
                .frame(minHeight: 58, alignment: .top)
            }
        }
    }

    private var label: String { block.kind.rawValue.capitalized }
    private var icon: String {
        switch block.kind {
        case .table: "tablecells"
        case .board: "rectangle.split.3x1"
        case .calendar: "calendar"
        case .list: "list.bullet.rectangle"
        case .gallery: "rectangle.grid.2x2"
        case .timeline: "point.topleft.down.to.point.bottomright.curvepath"
        }
    }
    private func boardColor(_ index: Int) -> Color {
        [Color.secondary, .orange, .green, .blue, .purple][index % 5]
    }
}

private struct ViewerCalendarBlock: View {
    let block: ViewerStructuredBlock
    @State private var month: String

    init(block: ViewerStructuredBlock) {
        self.block = block
        _month = State(initialValue: block.calendarMonth)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button { month = ViewerBlockDate.shiftedMonth(month, -1) } label: { Image(systemName: "chevron.left") }
                Button { month = ViewerBlockDate.shiftedMonth(month, 1) } label: { Image(systemName: "chevron.right") }
                Text(ViewerBlockDate.date(month)?.formatted(.dateTime.month(.wide).year()) ?? month)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }.buttonStyle(.borderless)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) {
                    Text($0).font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
                }
                ForEach(Array(ViewerBlockDate.monthDays(month).enumerated()), id: \.offset) { _, date in
                    let key = date.map(ViewerBlockDate.dayKey)
                    let events = key.map { key in block.calendarEvents.filter { $0.date == key } } ?? []
                    VStack(alignment: .leading, spacing: 3) {
                        Text(date.map { String(Calendar.current.component(.day, from: $0)) } ?? "").font(.system(size: 10))
                        ForEach(events.prefix(2)) { event in
                            Text(event.title).font(.system(size: 7)).lineLimit(1).foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(5)
                    .frame(maxWidth: .infinity, minHeight: 46, alignment: .topLeading)
                    .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}

private struct ViewerGalleryImage: View {
    let asset: ViewerAsset
    @ObservedObject var document: ViewerDocument
    @State private var localURL: URL?

    var body: some View {
        Group {
            if let localURL, let image = NSImage(contentsOf: localURL) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: asset.id) { localURL = await document.materialize(asset) }
    }
}
