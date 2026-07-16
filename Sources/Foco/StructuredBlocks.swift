import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum FocoStructuredBlockKind: String, Codable, CaseIterable, Hashable, Sendable {
    case table, board, calendar, list, gallery, timeline

    var label: String {
        switch self {
        case .table: "Table"
        case .board: "Board"
        case .calendar: "Calendar"
        case .list: "List"
        case .gallery: "Gallery"
        case .timeline: "Timeline"
        }
    }

    var icon: String {
        switch self {
        case .table: "tablecells"
        case .board: "rectangle.split.3x1"
        case .calendar: "calendar"
        case .list: "list.bullet.rectangle"
        case .gallery: "rectangle.grid.2x2"
        case .timeline: "point.topleft.down.to.point.bottomright.curvepath"
        }
    }
}

struct FocoTableColumn: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
}

struct FocoTableRow: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var cells: [String]
}

struct FocoBoardCard: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var title: String
    var note: String = ""
}

struct FocoBoardColumn: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var title: String
    var cards: [FocoBoardCard] = []
}

struct FocoCalendarEvent: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var date: String
    var time: String = "09:00"
    var title: String
}

struct FocoListItem: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var title: String
    var note: String = ""
    var tag: String = ""
    var isComplete = false
}

struct FocoGalleryItem: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var title: String
    var caption: String = ""
    var assetID: UUID?
}

struct FocoTimelineItem: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var date: String
    var title: String
    var detail: String = ""
}

struct FocoStructuredBlock: Codable, Identifiable, Hashable, Sendable {
    var schemaVersion = 1
    var id: UUID
    var kind: FocoStructuredBlockKind
    var title: String
    var tableColumns: [FocoTableColumn]
    var tableRows: [FocoTableRow]
    var boardColumns: [FocoBoardColumn]
    var calendarMonth: String
    var calendarEvents: [FocoCalendarEvent]
    var listItems: [FocoListItem]
    var galleryItems: [FocoGalleryItem]
    var timelineItems: [FocoTimelineItem]

    init(id: UUID = UUID(), kind: FocoStructuredBlockKind) {
        self.id = id
        self.kind = kind
        title = kind.label
        tableColumns = []
        tableRows = []
        boardColumns = []
        calendarMonth = FocoBlockDate.monthKey(Date())
        calendarEvents = []
        listItems = []
        galleryItems = []
        timelineItems = []

        switch kind {
        case .table:
            tableColumns = ["Name", "Status", "Notes"].map { FocoTableColumn(name: $0) }
            tableRows = [
                FocoTableRow(cells: ["First item", "Not started", ""]),
                FocoTableRow(cells: ["Second item", "In progress", ""])
            ]
        case .board:
            boardColumns = [
                FocoBoardColumn(title: "To do", cards: [FocoBoardCard(title: "New task")]),
                FocoBoardColumn(title: "In progress"),
                FocoBoardColumn(title: "Done")
            ]
        case .calendar:
            title = "Calendar"
        case .list:
            listItems = [
                FocoListItem(title: "First item"),
                FocoListItem(title: "Second item", note: "Add a note or description")
            ]
        case .gallery:
            galleryItems = [FocoGalleryItem(title: "New card", caption: "Choose an image")]
        case .timeline:
            let today = FocoBlockDate.dayKey(Date())
            let tomorrow = FocoBlockDate.dayKey(Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
            timelineItems = [
                FocoTimelineItem(date: today, title: "Project starts"),
                FocoTimelineItem(date: tomorrow, title: "Next milestone")
            ]
        }
    }

    var inlineHeight: CGFloat {
        switch kind {
        case .table: 430
        case .board: 485
        case .calendar: 650
        case .list: 455
        case .gallery: 535
        case .timeline: 500
        }
    }

    var referencedAssetIDs: [UUID] {
        galleryItems.compactMap(\.assetID)
    }
}

struct FocoStructuredBlockMatch: Sendable {
    let id: UUID
    let kind: FocoStructuredBlockKind
    let tokenRange: NSRange
    let lineRange: NSRange
}

enum FocoStructuredBlockSyntax {
    static func token(for block: FocoStructuredBlock) -> String {
        "[[block:\(block.id.uuidString)|\(block.kind.rawValue)]]"
    }

    static func matches(in content: String) -> [FocoStructuredBlockMatch] {
        guard let regex = try? NSRegularExpression(
            pattern: #"\[\[block:([0-9A-Fa-f-]{36})\|(table|board|calendar|list|gallery|timeline)\]\]"#
        ) else { return [] }
        let source = content as NSString
        return regex.matches(
            in: content,
            range: NSRange(location: 0, length: source.length)
        ).compactMap { match in
            guard let id = UUID(uuidString: source.substring(with: match.range(at: 1))),
                  let kind = FocoStructuredBlockKind(rawValue: source.substring(with: match.range(at: 2))) else {
                return nil
            }
            return FocoStructuredBlockMatch(
                id: id,
                kind: kind,
                tokenRange: match.range,
                lineRange: source.lineRange(for: match.range)
            )
        }
    }

    static func inserting(
        _ block: FocoStructuredBlock,
        into content: String,
        replacing range: NSRange
    ) -> (content: String, cursor: Int) {
        let source = content as NSString
        let location = min(max(0, range.location), source.length)
        let safeRange = NSRange(
            location: location,
            length: min(max(0, range.length), source.length - location)
        )
        let prefix = source.substring(to: safeRange.location)
        let suffix = source.substring(from: NSMaxRange(safeRange))
        var value = token(for: block)
        if !prefix.isEmpty && !prefix.hasSuffix("\n") { value = "\n" + value }
        if suffix.isEmpty || !suffix.hasPrefix("\n") { value += "\n" }
        let updated = source.replacingCharacters(in: safeRange, with: value)
        return (updated, safeRange.location + value.utf16.count)
    }

    static func removing(_ id: UUID, from content: String) -> String {
        guard let match = matches(in: content).first(where: { $0.id == id }) else { return content }
        return (content as NSString).replacingCharacters(in: match.lineRange, with: "")
    }
}

enum FocoBlockDate {
    static func dayKey(_ date: Date) -> String {
        let values = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", values.year ?? 1970, values.month ?? 1, values.day ?? 1)
    }

    static func monthKey(_ date: Date) -> String {
        let values = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", values.year ?? 1970, values.month ?? 1)
    }

    static func date(_ key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return Calendar.current.date(from: DateComponents(
            year: parts[0],
            month: parts[1],
            day: parts.count > 2 ? parts[2] : 1
        ))
    }

    static func monthDays(_ monthKey: String) -> [Date?] {
        guard let start = date(monthKey),
              let dayRange = Calendar.current.range(of: .day, in: .month, for: start) else { return [] }
        let weekday = Calendar.current.component(.weekday, from: start)
        var result = Array<Date?>(repeating: nil, count: max(0, weekday - 1))
        for day in dayRange {
            result.append(Calendar.current.date(bySetting: .day, value: day, of: start))
        }
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    static func shiftedMonth(_ monthKey: String, by amount: Int) -> String {
        guard let date = date(monthKey),
              let shifted = Calendar.current.date(byAdding: .month, value: amount, to: date) else { return monthKey }
        return self.monthKey(shifted)
    }
}

@MainActor
final class FocoStructuredBlockStore: ObservableObject {
    @Published private(set) var block: FocoStructuredBlock
    @Published private(set) var assets: [VaultAsset]

    var materialize: @Sendable (VaultAsset) -> URL?
    var importImage: @MainActor (URL) async -> VaultAsset?
    private let onChange: (FocoStructuredBlock) -> Void
    private let onDeleteBlock: (UUID) -> Void
    private let onMoveBlock: (UUID, Int) -> Void
    private let onDeleteAsset: (UUID) -> Void

    init(
        block: FocoStructuredBlock,
        assets: [VaultAsset],
        materialize: @escaping @Sendable (VaultAsset) -> URL?,
        importImage: @escaping @MainActor (URL) async -> VaultAsset?,
        onChange: @escaping (FocoStructuredBlock) -> Void,
        onDeleteBlock: @escaping (UUID) -> Void,
        onMoveBlock: @escaping (UUID, Int) -> Void,
        onDeleteAsset: @escaping (UUID) -> Void
    ) {
        self.block = block
        self.assets = assets
        self.materialize = materialize
        self.importImage = importImage
        self.onChange = onChange
        self.onDeleteBlock = onDeleteBlock
        self.onMoveBlock = onMoveBlock
        self.onDeleteAsset = onDeleteAsset
    }

    func configure(
        block: FocoStructuredBlock,
        assets: [VaultAsset],
        materialize: @escaping @Sendable (VaultAsset) -> URL?,
        importImage: @escaping @MainActor (URL) async -> VaultAsset?
    ) {
        if self.block != block { self.block = block }
        if self.assets != assets { self.assets = assets }
        self.materialize = materialize
        self.importImage = importImage
    }

    func mutate(_ action: (inout FocoStructuredBlock) -> Void) {
        var updated = block
        action(&updated)
        guard updated != block else { return }
        block = updated
        onChange(updated)
    }

    func binding<Value>(
        get: @escaping (FocoStructuredBlock) -> Value,
        set: @escaping (inout FocoStructuredBlock, Value) -> Void
    ) -> Binding<Value> {
        Binding(
            get: { get(self.block) },
            set: { value in self.mutate { set(&$0, value) } }
        )
    }

    func deleteBlock() { onDeleteBlock(block.id) }
    func moveBlock(_ direction: Int) { onMoveBlock(block.id, direction) }
    func deleteAsset(_ id: UUID) { onDeleteAsset(id) }
    func asset(_ id: UUID?) -> VaultAsset? { assets.first { $0.id == id } }
}

struct FocoStructuredBlockEditor: View {
    @ObservedObject var store: FocoStructuredBlockStore
    @State private var showingImageImporter = false
    @State private var pendingGalleryItemID: UUID?
    @State private var selectedCalendarDate = FocoBlockDate.dayKey(Date())
    @State private var calendarDraft = ""
    @State private var listSearch = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider()
            footer
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.11)))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 5)
        .fileImporter(
            isPresented: $showingImageImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            guard let itemID = pendingGalleryItemID,
                  case .success(let urls) = result,
                  let url = urls.first else { return }
            Task { @MainActor in
                guard let asset = await store.importImage(url) else { return }
                let oldAssetID = store.block.galleryItems.first(where: { $0.id == itemID })?.assetID
                store.mutate { block in
                    guard let index = block.galleryItems.firstIndex(where: { $0.id == itemID }) else { return }
                    block.galleryItems[index].assetID = asset.id
                }
                if let oldAssetID, oldAssetID != asset.id { store.deleteAsset(oldAssetID) }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: store.block.kind.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FocoTheme.accent)
                .frame(width: 28, height: 28)
                .background(FocoTheme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 7))
            TextField("Untitled \(store.block.kind.label)", text: titleBinding)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Text(store.block.kind.label.uppercased())
                .font(.system(size: 8, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .frame(height: 45)
    }

    @ViewBuilder
    private var content: some View {
        switch store.block.kind {
        case .table: tableView
        case .board: boardView
        case .calendar: calendarView
        case .list: listView
        case .gallery: galleryView
        case .timeline: timelineView
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .frame(width: 22, height: 24)
                .contentShape(Rectangle())
                .help("Drag to move this block")
                .onDrag { NSItemProvider(object: "foco-block:\(store.block.id.uuidString)" as NSString) }
            Text("Stored locally in this bulb")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Spacer()
            blockButton("arrow.up", "Move up") { store.moveBlock(-1) }
            blockButton("arrow.down", "Move down") { store.moveBlock(1) }
            blockButton("trash", "Delete block", role: .destructive) { store.deleteBlock() }
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
    }

    private var titleBinding: Binding<String> {
        store.binding(get: \.title, set: { $0.title = $1 })
    }

    private var tableView: some View {
        VStack(alignment: .leading, spacing: 9) {
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(Array(store.block.tableColumns.enumerated()), id: \.element.id) { columnIndex, column in
                            HStack(spacing: 4) {
                                TextField("Column", text: tableColumnBinding(column.id))
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11, weight: .semibold))
                                if store.block.tableColumns.count > 1 {
                                    Button { removeTableColumn(columnIndex) } label: {
                                        Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.horizontal, 9)
                            .frame(width: 164, height: 34)
                            .background(FocoTheme.accent.opacity(0.075))
                            .overlay(Rectangle().stroke(Color.primary.opacity(0.09), lineWidth: 0.5))
                        }
                        Color.clear.frame(width: 28, height: 34)
                    }
                    ForEach(store.block.tableRows) { row in
                        HStack(spacing: 0) {
                            ForEach(Array(store.block.tableColumns.enumerated()), id: \.element.id) { columnIndex, _ in
                                TextField("", text: tableCellBinding(row.id, columnIndex))
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 9)
                                    .frame(width: 164, height: 36)
                                    .background(Color(nsColor: .textBackgroundColor).opacity(0.52))
                                    .overlay(Rectangle().stroke(Color.primary.opacity(0.09), lineWidth: 0.5))
                            }
                            Button { removeTableRow(row.id) } label: {
                                Image(systemName: "trash").font(.system(size: 9))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tertiary)
                            .frame(width: 28, height: 36)
                        }
                    }
                }
            }
            .scrollIndicators(.visible)

            HStack {
                Button("New row", systemImage: "plus") { addTableRow() }
                Button("New column", systemImage: "rectangle.split.3x1") { addTableColumn() }
                Spacer()
                Text("\(store.block.tableRows.count) rows")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11, weight: .medium))
        }
        .padding(12)
    }

    private var boardView: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(store.block.boardColumns.enumerated()), id: \.element.id) { columnIndex, column in
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Circle().fill(boardColor(columnIndex)).frame(width: 7, height: 7)
                            TextField("Column", text: boardColumnTitleBinding(column.id))
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, weight: .semibold))
                            Text("\(column.cards.count)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.tertiary)
                            if store.block.boardColumns.count > 1 {
                                Button { removeBoardColumn(column.id) } label: {
                                    Image(systemName: "trash").font(.system(size: 9))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.tertiary)
                            }
                        }
                        ScrollView {
                            LazyVStack(spacing: 7) {
                                ForEach(column.cards) { card in
                                    VStack(alignment: .leading, spacing: 5) {
                                        TextField("Card title", text: boardCardBinding(column.id, card.id, keyPath: \.title))
                                            .textFieldStyle(.plain)
                                            .font(.system(size: 12, weight: .medium))
                                        TextField("Add a note", text: boardCardBinding(column.id, card.id, keyPath: \.note))
                                            .textFieldStyle(.plain)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                        HStack(spacing: 5) {
                                            Button { moveBoardCard(card.id, from: columnIndex, by: -1) } label: {
                                                Image(systemName: "chevron.left")
                                            }.disabled(columnIndex == 0)
                                            Button { moveBoardCard(card.id, from: columnIndex, by: 1) } label: {
                                                Image(systemName: "chevron.right")
                                            }.disabled(columnIndex == store.block.boardColumns.count - 1)
                                            Spacer()
                                            Button { removeBoardCard(card.id, columnID: column.id) } label: {
                                                Image(systemName: "xmark")
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.tertiary)
                                    }
                                    .padding(9)
                                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08)))
                                }
                            }
                        }
                        Button("New card", systemImage: "plus") { addBoardCard(to: column.id) }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(9)
                    .frame(width: 202, height: 355, alignment: .top)
                    .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 9))
                }
                Button { addBoardColumn() } label: {
                    Label("Add column", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 150, height: 38)
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(12)
        }
    }

    private var calendarView: some View {
        VStack(spacing: 9) {
            HStack {
                Button { setCalendarMonth(-1) } label: { Image(systemName: "chevron.left") }
                Button { setCalendarMonth(1) } label: { Image(systemName: "chevron.right") }
                Text(calendarMonthTitle)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("Today") {
                    store.mutate { $0.calendarMonth = FocoBlockDate.monthKey(Date()) }
                    selectedCalendarDate = FocoBlockDate.dayKey(Date())
                }
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day).font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
                }
                ForEach(Array(FocoBlockDate.monthDays(store.block.calendarMonth).enumerated()), id: \.offset) { _, date in
                    calendarDay(date)
                }
            }

            Divider()
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(selectedCalendarTitle)
                        .font(.system(size: 11, weight: .semibold))
                    HStack {
                        TextField("New event", text: $calendarDraft)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                            .onSubmit(addCalendarEvent)
                        Button(action: addCalendarEvent) { Image(systemName: "plus") }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
                .frame(width: 205)
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(calendarEventsForSelection) { event in
                            HStack(spacing: 6) {
                                TextField("Time", text: calendarEventBinding(event.id, keyPath: \.time))
                                    .textFieldStyle(.plain).frame(width: 42)
                                TextField("Event", text: calendarEventBinding(event.id, keyPath: \.title))
                                    .textFieldStyle(.plain)
                                Button { removeCalendarEvent(event.id) } label: { Image(systemName: "trash") }
                                    .buttonStyle(.plain).foregroundStyle(.tertiary)
                            }
                            .font(.system(size: 10))
                            .padding(7)
                            .background(FocoTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
                        }
                    }
                }
            }
            .frame(height: 86)
        }
        .padding(12)
    }

    private var listView: some View {
        VStack(spacing: 9) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                TextField("Filter items", text: $listSearch).textFieldStyle(.plain)
                Spacer()
                Text("\(store.block.listItems.filter(\.isComplete).count)/\(store.block.listItems.count) complete")
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
            }
            .font(.system(size: 11))
            .padding(.horizontal, 9)
            .frame(height: 32)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredListItems) { item in
                        HStack(spacing: 8) {
                            Button { toggleListItem(item.id) } label: {
                                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isComplete ? FocoTheme.accent : .secondary)
                            }
                            .buttonStyle(.plain)
                            VStack(alignment: .leading, spacing: 2) {
                                TextField("Item", text: listItemBinding(item.id, keyPath: \.title))
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12, weight: .medium))
                                    .strikethrough(item.isComplete)
                                TextField("Note", text: listItemBinding(item.id, keyPath: \.note))
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            TextField("Tag", text: listItemBinding(item.id, keyPath: \.tag))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 9))
                                .frame(width: 78)
                            listMoveButtons(item.id)
                            Button { removeListItem(item.id) } label: { Image(systemName: "trash") }
                                .buttonStyle(.plain).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 48)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            Button("New item", systemImage: "plus") { addListItem() }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }

    private var galleryView: some View {
        VStack(spacing: 8) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(store.block.galleryItems) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.035))
                                if let asset = store.asset(item.assetID) {
                                    FocoGalleryImage(asset: asset, materialize: store.materialize)
                                } else {
                                    VStack(spacing: 6) {
                                        Image(systemName: "photo.on.rectangle.angled")
                                            .font(.system(size: 22, weight: .light))
                                        Text("Choose image").font(.system(size: 9))
                                    }.foregroundStyle(.tertiary)
                                }
                            }
                            .frame(height: 120)
                            .clipped()
                            TextField("Card title", text: galleryItemBinding(item.id, keyPath: \.title))
                                .textFieldStyle(.plain).font(.system(size: 12, weight: .semibold))
                            TextField("Caption", text: galleryItemBinding(item.id, keyPath: \.caption))
                                .textFieldStyle(.plain).font(.system(size: 10)).foregroundStyle(.secondary)
                            HStack {
                                Button(item.assetID == nil ? "Choose image" : "Replace") {
                                    pendingGalleryItemID = item.id
                                    showingImageImporter = true
                                }
                                Spacer()
                                Button(role: .destructive) { removeGalleryItem(item.id) } label: {
                                    Image(systemName: "trash")
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.primary.opacity(0.08)))
                    }
                }
            }
            Button("New gallery card", systemImage: "plus") { addGalleryItem() }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }

    private var timelineView: some View {
        VStack(spacing: 8) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(sortedTimelineItems.enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(spacing: 0) {
                                Circle().fill(FocoTheme.accent).frame(width: 10, height: 10)
                                if index < sortedTimelineItems.count - 1 {
                                    Rectangle().fill(FocoTheme.accent.opacity(0.22)).frame(width: 2, height: 58)
                                }
                            }
                            DatePicker(
                                "",
                                selection: timelineDateBinding(item.id),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .controlSize(.small)
                            .frame(width: 112)
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("Milestone", text: timelineItemBinding(item.id, keyPath: \.title))
                                    .textFieldStyle(.plain).font(.system(size: 12, weight: .semibold))
                                TextField("Details", text: timelineItemBinding(item.id, keyPath: \.detail))
                                    .textFieldStyle(.plain).font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { removeTimelineItem(item.id) } label: { Image(systemName: "trash") }
                                .buttonStyle(.plain).foregroundStyle(.tertiary)
                        }
                        .frame(minHeight: 67, alignment: .top)
                    }
                }
            }
            Button("New milestone", systemImage: "plus") { addTimelineItem() }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }

    private func blockButton(
        _ icon: String,
        _ help: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: icon).font(.system(size: 9, weight: .semibold)).frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }

    private func tableColumnBinding(_ id: UUID) -> Binding<String> {
        store.binding(
            get: { $0.tableColumns.first(where: { $0.id == id })?.name ?? "" },
            set: { block, value in
                guard let index = block.tableColumns.firstIndex(where: { $0.id == id }) else { return }
                block.tableColumns[index].name = value
            }
        )
    }

    private func tableCellBinding(_ rowID: UUID, _ column: Int) -> Binding<String> {
        store.binding(
            get: { block in
                guard let row = block.tableRows.first(where: { $0.id == rowID }), row.cells.indices.contains(column) else { return "" }
                return row.cells[column]
            },
            set: { block, value in
                guard let row = block.tableRows.firstIndex(where: { $0.id == rowID }) else { return }
                while block.tableRows[row].cells.count <= column { block.tableRows[row].cells.append("") }
                block.tableRows[row].cells[column] = value
            }
        )
    }

    private func addTableRow() {
        store.mutate { $0.tableRows.append(FocoTableRow(cells: Array(repeating: "", count: $0.tableColumns.count))) }
    }

    private func removeTableRow(_ id: UUID) { store.mutate { $0.tableRows.removeAll { $0.id == id } } }
    private func addTableColumn() {
        store.mutate {
            $0.tableColumns.append(FocoTableColumn(name: "New column"))
            for index in $0.tableRows.indices { $0.tableRows[index].cells.append("") }
        }
    }
    private func removeTableColumn(_ index: Int) {
        store.mutate {
            guard $0.tableColumns.indices.contains(index), $0.tableColumns.count > 1 else { return }
            $0.tableColumns.remove(at: index)
            for row in $0.tableRows.indices where $0.tableRows[row].cells.indices.contains(index) {
                $0.tableRows[row].cells.remove(at: index)
            }
        }
    }

    private func boardColumnTitleBinding(_ id: UUID) -> Binding<String> {
        store.binding(
            get: { $0.boardColumns.first(where: { $0.id == id })?.title ?? "" },
            set: { block, value in
                guard let index = block.boardColumns.firstIndex(where: { $0.id == id }) else { return }
                block.boardColumns[index].title = value
            }
        )
    }

    private func boardCardBinding(
        _ columnID: UUID,
        _ cardID: UUID,
        keyPath: WritableKeyPath<FocoBoardCard, String>
    ) -> Binding<String> {
        store.binding(
            get: { block in
                block.boardColumns.first(where: { $0.id == columnID })?.cards.first(where: { $0.id == cardID })?[keyPath: keyPath] ?? ""
            },
            set: { block, value in
                guard let column = block.boardColumns.firstIndex(where: { $0.id == columnID }),
                      let card = block.boardColumns[column].cards.firstIndex(where: { $0.id == cardID }) else { return }
                block.boardColumns[column].cards[card][keyPath: keyPath] = value
            }
        )
    }

    private func boardColor(_ index: Int) -> Color {
        [Color.secondary, Color.orange, Color.green, Color.blue, Color.purple][index % 5]
    }
    private func addBoardCard(to columnID: UUID) {
        store.mutate {
            guard let index = $0.boardColumns.firstIndex(where: { $0.id == columnID }) else { return }
            $0.boardColumns[index].cards.append(FocoBoardCard(title: "New card"))
        }
    }
    private func removeBoardCard(_ cardID: UUID, columnID: UUID) {
        store.mutate {
            guard let index = $0.boardColumns.firstIndex(where: { $0.id == columnID }) else { return }
            $0.boardColumns[index].cards.removeAll { $0.id == cardID }
        }
    }
    private func moveBoardCard(_ cardID: UUID, from source: Int, by direction: Int) {
        store.mutate {
            let target = source + direction
            guard $0.boardColumns.indices.contains(source), $0.boardColumns.indices.contains(target),
                  let cardIndex = $0.boardColumns[source].cards.firstIndex(where: { $0.id == cardID }) else { return }
            let card = $0.boardColumns[source].cards.remove(at: cardIndex)
            $0.boardColumns[target].cards.append(card)
        }
    }
    private func addBoardColumn() { store.mutate { $0.boardColumns.append(FocoBoardColumn(title: "New column")) } }
    private func removeBoardColumn(_ id: UUID) {
        store.mutate {
            guard $0.boardColumns.count > 1,
                  let index = $0.boardColumns.firstIndex(where: { $0.id == id }) else { return }
            let cards = $0.boardColumns.remove(at: index).cards
            $0.boardColumns[max(0, min(index, $0.boardColumns.count - 1))].cards.append(contentsOf: cards)
        }
    }

    private var calendarMonthTitle: String {
        FocoBlockDate.date(store.block.calendarMonth)?.formatted(.dateTime.month(.wide).year()) ?? store.block.calendarMonth
    }
    private var selectedCalendarTitle: String {
        FocoBlockDate.date(selectedCalendarDate)?.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) ?? selectedCalendarDate
    }
    private var calendarEventsForSelection: [FocoCalendarEvent] {
        store.block.calendarEvents.filter { $0.date == selectedCalendarDate }.sorted { $0.time < $1.time }
    }
    private func calendarDay(_ date: Date?) -> some View {
        let key = date.map(FocoBlockDate.dayKey)
        let events = key.map { value in store.block.calendarEvents.filter { $0.date == value } } ?? []
        return Button {
            if let key { selectedCalendarDate = key }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(date.map { String(Calendar.current.component(.day, from: $0)) } ?? "")
                    .font(.system(size: 10, weight: key == FocoBlockDate.dayKey(Date()) ? .bold : .regular))
                HStack(spacing: 2) {
                    ForEach(events.prefix(3)) { _ in Circle().fill(FocoTheme.accent).frame(width: 4, height: 4) }
                    if events.count > 3 { Text("+\(events.count - 3)").font(.system(size: 7)) }
                }
            }
            .padding(5)
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)
            .background(key == selectedCalendarDate ? FocoTheme.accent.opacity(0.13) : Color.primary.opacity(0.018), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(date == nil)
    }
    private func setCalendarMonth(_ amount: Int) {
        store.mutate { $0.calendarMonth = FocoBlockDate.shiftedMonth($0.calendarMonth, by: amount) }
        if let first = FocoBlockDate.date(store.block.calendarMonth) { selectedCalendarDate = FocoBlockDate.dayKey(first) }
    }
    private func addCalendarEvent() {
        let title = calendarDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        store.mutate { $0.calendarEvents.append(FocoCalendarEvent(date: selectedCalendarDate, title: title)) }
        calendarDraft = ""
    }
    private func removeCalendarEvent(_ id: UUID) { store.mutate { $0.calendarEvents.removeAll { $0.id == id } } }
    private func calendarEventBinding(_ id: UUID, keyPath: WritableKeyPath<FocoCalendarEvent, String>) -> Binding<String> {
        store.binding(
            get: { $0.calendarEvents.first(where: { $0.id == id })?[keyPath: keyPath] ?? "" },
            set: { block, value in
                guard let index = block.calendarEvents.firstIndex(where: { $0.id == id }) else { return }
                block.calendarEvents[index][keyPath: keyPath] = value
            }
        )
    }

    private var filteredListItems: [FocoListItem] {
        guard !listSearch.isEmpty else { return store.block.listItems }
        return store.block.listItems.filter {
            $0.title.localizedCaseInsensitiveContains(listSearch) ||
            $0.note.localizedCaseInsensitiveContains(listSearch) ||
            $0.tag.localizedCaseInsensitiveContains(listSearch)
        }
    }
    private func listItemBinding(_ id: UUID, keyPath: WritableKeyPath<FocoListItem, String>) -> Binding<String> {
        store.binding(
            get: { $0.listItems.first(where: { $0.id == id })?[keyPath: keyPath] ?? "" },
            set: { block, value in
                guard let index = block.listItems.firstIndex(where: { $0.id == id }) else { return }
                block.listItems[index][keyPath: keyPath] = value
            }
        )
    }
    private func toggleListItem(_ id: UUID) { store.mutate { block in if let i = block.listItems.firstIndex(where: { $0.id == id }) { block.listItems[i].isComplete.toggle() } } }
    private func addListItem() { store.mutate { $0.listItems.append(FocoListItem(title: "New item")) } }
    private func removeListItem(_ id: UUID) { store.mutate { $0.listItems.removeAll { $0.id == id } } }
    private func listMoveButtons(_ id: UUID) -> some View {
        HStack(spacing: 3) {
            Button { moveListItem(id, -1) } label: { Image(systemName: "chevron.up") }
            Button { moveListItem(id, 1) } label: { Image(systemName: "chevron.down") }
        }.buttonStyle(.plain).font(.system(size: 8)).foregroundStyle(.tertiary)
    }
    private func moveListItem(_ id: UUID, _ direction: Int) {
        store.mutate {
            guard let source = $0.listItems.firstIndex(where: { $0.id == id }) else { return }
            let target = source + direction
            guard $0.listItems.indices.contains(target) else { return }
            $0.listItems.swapAt(source, target)
        }
    }

    private func galleryItemBinding(_ id: UUID, keyPath: WritableKeyPath<FocoGalleryItem, String>) -> Binding<String> {
        store.binding(
            get: { $0.galleryItems.first(where: { $0.id == id })?[keyPath: keyPath] ?? "" },
            set: { block, value in
                guard let index = block.galleryItems.firstIndex(where: { $0.id == id }) else { return }
                block.galleryItems[index][keyPath: keyPath] = value
            }
        )
    }
    private func addGalleryItem() { store.mutate { $0.galleryItems.append(FocoGalleryItem(title: "New card")) } }
    private func removeGalleryItem(_ id: UUID) {
        let assetID = store.block.galleryItems.first(where: { $0.id == id })?.assetID
        store.mutate { $0.galleryItems.removeAll { $0.id == id } }
        if let assetID { store.deleteAsset(assetID) }
    }

    private var sortedTimelineItems: [FocoTimelineItem] { store.block.timelineItems.sorted { $0.date < $1.date } }
    private func timelineItemBinding(_ id: UUID, keyPath: WritableKeyPath<FocoTimelineItem, String>) -> Binding<String> {
        store.binding(
            get: { $0.timelineItems.first(where: { $0.id == id })?[keyPath: keyPath] ?? "" },
            set: { block, value in
                guard let index = block.timelineItems.firstIndex(where: { $0.id == id }) else { return }
                block.timelineItems[index][keyPath: keyPath] = value
            }
        )
    }
    private func timelineDateBinding(_ id: UUID) -> Binding<Date> {
        Binding(
            get: { FocoBlockDate.date(store.block.timelineItems.first(where: { $0.id == id })?.date ?? "") ?? Date() },
            set: { date in store.mutate { block in if let i = block.timelineItems.firstIndex(where: { $0.id == id }) { block.timelineItems[i].date = FocoBlockDate.dayKey(date) } } }
        )
    }
    private func addTimelineItem() { store.mutate { $0.timelineItems.append(FocoTimelineItem(date: FocoBlockDate.dayKey(Date()), title: "New milestone")) } }
    private func removeTimelineItem(_ id: UUID) { store.mutate { $0.timelineItems.removeAll { $0.id == id } } }
}

private struct FocoGalleryImage: View {
    let asset: VaultAsset
    let materialize: @Sendable (VaultAsset) -> URL?
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
        .task(id: asset.id) {
            let materialize = materialize
            localURL = await Task.detached(priority: .utility) { materialize(asset) }.value
        }
    }
}
