//
//  ContentView.swift
//  ClipDock
//
//  Created by 陈睿 on 2026/6/30.
//

import SwiftUI
import AppKit
import Combine

final class ClipDockStore: ObservableObject {
    private static let userDefaultsKey = "clipDockItems"
    private static let trashRetentionDays = 10
    private static let sampleItems: [SavedItem] = [
        SavedItem(
            title: "SwiftUI Documentation",
            content: "https://developer.apple.com/documentation/swiftui",
            type: .link,
            tags: ["swiftui", "apple", "docs"],
            isPinned: true,
            createdAt: Date()
        ),
        SavedItem(
            title: "Release Notes Template",
            content: "Ship the smallest useful change, call out user impact, and list any known limitations.",
            type: .text,
            tags: ["writing", "release"],
            isPinned: false,
            createdAt: Date()
        ),
        SavedItem(
            title: "Code Review Prompt",
            content: "Review this change for correctness, edge cases, maintainability, and missing tests.",
            type: .prompt,
            tags: ["ai", "review", "engineering"],
            isPinned: true,
            createdAt: Date()
        ),
        SavedItem(
            title: "Git Status Command",
            content: "git status",
            type: .command,
            tags: ["git", "terminal"],
            isPinned: false,
            createdAt: Date()
        ),
        SavedItem(
            title: "Project Board",
            content: "https://github.com/",
            type: .link,
            tags: ["github", "planning"],
            isPinned: false,
            createdAt: Date()
        ),
        SavedItem(
            title: "Support Reply",
            content: "Thanks for the report. I reproduced the issue and will follow up when the fix is ready.",
            type: .text,
            tags: ["support", "reply"],
            isPinned: false,
            createdAt: Date()
        )
    ]

    @Published private(set) var items: [SavedItem]

    init() {
        items = Self.loadItems()
    }

    func addItem(title: String, content: String, type: SavedItemType, tags: [String]) {
        let item = SavedItem(
            title: title,
            content: content,
            type: type,
            tags: tags,
            isPinned: false,
            createdAt: Date()
        )

        items.insert(item, at: 0)
        saveItems()
    }

    func softDeleteItem(_ item: SavedItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        items[index].isDeleted = true
        items[index].deletedAt = Date()
        saveItems()
    }

    func restoreItem(_ item: SavedItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        items[index].isDeleted = false
        items[index].deletedAt = nil
        saveItems()
    }

    func permanentlyDeleteItem(_ item: SavedItem) {
        let originalCount = items.count
        items.removeAll { $0.id == item.id }

        guard items.count != originalCount else {
            return
        }

        saveItems()
    }

    func incrementUsage(for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }

        items[index].usageCount += 1
        saveItems()
    }

    static func isTrashExpired(_ item: SavedItem) -> Bool {
        guard item.isDeleted, let deletedAt = item.deletedAt else {
            return false
        }

        guard let expirationDate = Calendar.current.date(
            byAdding: .day,
            value: trashRetentionDays,
            to: deletedAt
        ) else {
            return false
        }

        return Date() > expirationDate
    }

    private static func loadItems() -> [SavedItem] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let savedItems = try? JSONDecoder().decode([SavedItem].self, from: data) else {
            return sampleItems
        }

        let cleanedItems = cleanupExpiredTrashItems(savedItems)
        if cleanedItems.count != savedItems.count {
            saveItems(cleanedItems)
        }

        return cleanedItems
    }

    private static func cleanupExpiredTrashItems(_ items: [SavedItem]) -> [SavedItem] {
        items.filter { !isTrashExpired($0) }
    }

    private func saveItems() {
        let cleanedItems = Self.cleanupExpiredTrashItems(items)
        if cleanedItems.count != items.count {
            items = cleanedItems
        }

        Self.saveItems(items)
    }

    private static func saveItems(_ items: [SavedItem]) {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }

        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}

struct ContentView: View {
    @ObservedObject var store: ClipDockStore
    @State private var searchText = ""
    @State private var selectedListView: ItemListView = .active
    @State private var selectedTypeFilter: ItemTypeFilter = .all
    @State private var selectedSortOption: SortOption = .newest
    @State private var newTitle = ""
    @State private var newContent = ""
    @State private var newTags = ""
    @State private var newType: SavedItemType = .link

    init(store: ClipDockStore = ClipDockStore()) {
        self.store = store
    }

    private var sortedAndFilteredItems: [SavedItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let filteredItems = store.items.filter { item in
            let matchesListView: Bool
            switch selectedListView {
            case .active:
                matchesListView = !item.isDeleted
            case .trash:
                matchesListView = item.isDeleted && !ClipDockStore.isTrashExpired(item)
            }

            let matchesSearch = query.isEmpty
            || item.title.localizedCaseInsensitiveContains(query)
            || item.content.localizedCaseInsensitiveContains(query)
            || item.tags.contains { $0.localizedCaseInsensitiveContains(query) }

            let matchesType = selectedTypeFilter.itemType == nil
            || selectedTypeFilter.itemType == item.type

            return matchesListView && matchesSearch && matchesType
        }

        return filteredItems.sorted { first, second in
            switch selectedSortOption {
            case .newest:
                return first.createdAt > second.createdAt
            case .oldest:
                return first.createdAt < second.createdAt
            case .mostUsed:
                if first.usageCount == second.usageCount {
                    return first.createdAt > second.createdAt
                }

                return first.usageCount > second.usageCount
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            TextField("Search by title, content, or tag", text: $searchText)
                .textFieldStyle(.roundedBorder)

            organizationControls

            if selectedListView == .active {
                addItemForm
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(sortedAndFilteredItems) { item in
                        SavedItemRow(
                            item: item,
                            listView: selectedListView,
                            onOpen: { open(item) },
                            onCopy: { copy(item) },
                            onDelete: { store.softDeleteItem(item) },
                            onRestore: { restoreItem(item) },
                            onDeleteForever: { store.permanentlyDeleteItem(item) }
                        )
                    }
                }
            }
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 520)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ClipDock")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Save useful links and snippets. Open or copy them when needed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var organizationControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("View", selection: $selectedListView) {
                ForEach(ItemListView.allCases, id: \.self) { listView in
                    Text(listView.rawValue).tag(listView)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Picker("Filter", selection: $selectedTypeFilter) {
                    ForEach(ItemTypeFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                Spacer()

                Picker("Sort", selection: $selectedSortOption) {
                    ForEach(SortOption.allCases, id: \.self) { sortOption in
                        Text(sortOption.rawValue).tag(sortOption)
                    }
                }
                .frame(width: 160)
            }
        }
    }

    private var addItemForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Item")
                .font(.headline)

            TextField("Title", text: $newTitle)
                .textFieldStyle(.roundedBorder)

            TextField("Content or URL", text: $newContent)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Picker("Type", selection: $newType) {
                    ForEach(SavedItemType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Tags, comma-separated", text: $newTags)
                    .textFieldStyle(.roundedBorder)

                Button("Add Item", action: addItem)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAddItem)
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        }
    }

    private var canAddItem: Bool {
        !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !newContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addItem() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = newContent.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty, !content.isEmpty else {
            return
        }

        let tags = newTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        store.addItem(title: title, content: content, type: newType, tags: tags)
        newTitle = ""
        newContent = ""
        newTags = ""
        newType = .link
    }

    private func copy(_ item: SavedItem) {
        guard !item.isDeleted else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content, forType: .string)
        store.incrementUsage(for: item.id)
    }

    private func open(_ item: SavedItem) {
        guard !item.isDeleted,
              item.type == .link,
              let url = URL(string: item.content),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            return
        }

        NSWorkspace.shared.open(url)
        store.incrementUsage(for: item.id)
    }

    private func restoreItem(_ item: SavedItem) {
        store.restoreItem(item)
        selectedListView = .active
    }
}

struct SavedItem: Identifiable, Codable {
    let id: UUID
    let title: String
    let content: String
    let type: SavedItemType
    let tags: [String]
    let isPinned: Bool
    let createdAt: Date
    var usageCount: Int
    var isDeleted: Bool
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        type: SavedItemType,
        tags: [String],
        isPinned: Bool,
        createdAt: Date,
        usageCount: Int = 0,
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.type = type
        self.tags = tags
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.usageCount = usageCount
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case type
        case tags
        case isPinned
        case createdAt
        case usageCount
        case isDeleted
        case deletedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        type = try container.decode(SavedItemType.self, forKey: .type)
        tags = try container.decode([String].self, forKey: .tags)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        usageCount = try container.decodeIfPresent(Int.self, forKey: .usageCount) ?? 0
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

private enum ItemListView: String, CaseIterable {
    case active = "Active"
    case trash = "Trash"
}

enum SavedItemType: String, CaseIterable, Codable {
    case link = "Link"
    case text = "Text"
    case prompt = "Prompt"
    case command = "Command"
}

private enum ItemTypeFilter: String, CaseIterable {
    case all = "All"
    case link = "Link"
    case text = "Text"
    case prompt = "Prompt"
    case command = "Command"

    var itemType: SavedItemType? {
        switch self {
        case .all:
            return nil
        case .link:
            return .link
        case .text:
            return .text
        case .prompt:
            return .prompt
        case .command:
            return .command
        }
    }
}

private enum SortOption: String, CaseIterable {
    case newest = "Newest"
    case oldest = "Oldest"
    case mostUsed = "Most Used"
}

private struct SavedItemRow: View {
    let item: SavedItem
    let listView: ItemListView
    let onOpen: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onRestore: () -> Void
    let onDeleteForever: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(item.title)
                    .font(.headline)

                Text(item.type.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(typeColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(typeColor)

                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Pinned")
                }

                Spacer()

                if listView == .active {
                    Button("Open", action: onOpen)
                        .disabled(!item.hasOpenableURL)

                    Button("Copy", action: onCopy)
                        .buttonStyle(.borderedProminent)

                    Button("Delete", role: .destructive, action: onDelete)
                } else {
                    Button("Restore", action: onRestore)
                        .buttonStyle(.borderedProminent)

                    Button("Delete Forever", role: .destructive, action: onDeleteForever)
                }
            }

            Text(item.content)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                ForEach(item.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                }

                Spacer()

                Text("Used \(item.usageCount) \(item.usageCount == 1 ? "time" : "times")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if listView == .trash, let deletedAt = item.deletedAt {
                    Text("Deleted \(deletedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        }
    }

    private var typeColor: Color {
        switch item.type {
        case .link:
            return .blue
        case .text:
            return .green
        case .prompt:
            return .purple
        case .command:
            return .orange
        }
    }
}

private extension SavedItem {
    var hasOpenableURL: Bool {
        guard type == .link else {
            return false
        }

        guard let url = URL(string: content),
              let scheme = url.scheme?.lowercased() else {
            return false
        }

        return ["http", "https"].contains(scheme) && url.host != nil
    }
}

struct QuickAddView: View {
    @ObservedObject var store: ClipDockStore
    @State private var isExpanded = false
    @State private var title = ""
    @State private var content = ""
    @State private var tagsText = ""
    @State private var type: SavedItemType = .link

    private var canAddItem: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Group {
            if isExpanded {
                quickAddForm
            } else {
                collapsedButton
            }
        }
        .background(FloatingWindowAccessor(isExpanded: isExpanded))
    }

    private var collapsedButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) {
                isExpanded = true
            }
        } label: {
            Text("+ Add")
                .font(.headline)
                .frame(width: 128, height: 50)
        }
        .buttonStyle(.plain)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.quaternary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var quickAddForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Quick Add")
                    .font(.headline)

                Spacer()

                Button("Collapse") {
                    withAnimation(.snappy(duration: 0.18)) {
                        isExpanded = false
                    }
                }
            }

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("Content or URL", text: $content)
                .textFieldStyle(.roundedBorder)

            Picker("Type", selection: $type) {
                ForEach(SavedItemType.allCases, id: \.self) { itemType in
                    Text(itemType.rawValue).tag(itemType)
                }
            }
            .pickerStyle(.segmented)

            TextField("Tags, comma-separated", text: $tagsText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()

                Button("Add Item", action: addItem)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAddItem)
            }
        }
        .padding(14)
        .frame(width: 350)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.quaternary)
        }
    }

    private func addItem() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty, !trimmedContent.isEmpty else {
            return
        }

        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        store.addItem(title: trimmedTitle, content: trimmedContent, type: type, tags: tags)
        title = ""
        content = ""
        tagsText = ""
        type = .link
        isExpanded = false
    }
}

private struct FloatingWindowAccessor: NSViewRepresentable {
    let isExpanded: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            configure(window: view.window)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else {
            return
        }

        let targetSize = isExpanded
            ? NSSize(width: 378, height: 280)
            : NSSize(width: 160, height: 78)
        let currentFrame = window.frame
        let newOrigin = NSPoint(
            x: currentFrame.minX,
            y: currentFrame.maxY - targetSize.height
        )

        window.level = .floating
        window.collectionBehavior.insert(.canJoinAllSpaces)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.styleMask.insert(.fullSizeContentView)
        window.setContentSize(targetSize)
        window.setFrameOrigin(newOrigin)
    }
}

#Preview {
    ContentView(store: ClipDockStore())
}
