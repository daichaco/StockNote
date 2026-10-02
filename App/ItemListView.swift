import StockCore
import SwiftData
import SwiftUI

private enum KindFilter: Hashable, CaseIterable {
    case all, kind(ItemKind)

    static var allCases: [KindFilter] { [.all] + ItemKind.allCases.map { .kind($0) } }

    var title: String {
        switch self {
        case .all: "すべて"
        case .kind(let k): k.title
        }
    }

    func includes(_ k: ItemKind) -> Bool {
        switch self {
        case .all: true
        case .kind(let x): x == k
        }
    }
}

struct ItemListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Item.name) private var items: [Item]
    @AppStorage("expiryNotifications") private var notifyExpiry = true

    @State private var filter: KindFilter = .all
    @State private var search = ""
    @State private var now = Date()
    @State private var authorizationEpoch = 0
    @State private var editing: Item?
    @State private var adding = false
    @State private var showingKit = false
    @State private var showingSettings = false

    private var visible: [Item] {
        let q = search.trimmingCharacters(in: .whitespaces)
        return items.filter { item in
            filter.includes(item.kind)
                && (q.isEmpty || item.name.localizedCaseInsensitiveContains(q)
                    || item.category.localizedCaseInsensitiveContains(q)
                    || item.note.localizedCaseInsensitiveContains(q))
        }
    }

    private var scheduleKey: [String] {
        items.map { "\($0.id)|\($0.name)|\($0.expiry?.timeIntervalSince1970 ?? 0)|\($0.warnDays)" }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("種別", selection: $filter) {
                    ForEach(KindFilter.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                content
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AdBannerContainer { showingSettings = true }
            }
            .navigationTitle("のこりメモ")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "品名・カテゴリで探す")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: { Label("設定", systemImage: "gearshape") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { adding = true } label: { Label("品目を追加", systemImage: "plus") }
                        Button { showingKit = true } label: { Label("防災バッグの定番から追加", systemImage: "backpack") }
                    } label: { Label("追加", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $adding) { ItemEditView(item: nil, initialKind: initialKind) }
            .sheet(item: $editing) { ItemEditView(item: $0, initialKind: $0.kind) }
            .sheet(isPresented: $showingKit) { DisasterKitView() }
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { now = Date() } }
        .onReceive(NotificationCenter.default.publisher(for: .expiryAuthorizationGranted)) { _ in authorizationEpoch += 1 }
        .task(id: scheduleKey + [String(notifyExpiry), String(authorizationEpoch)]) {
            let targets = items.map { ExpiryNotifier.Target(id: $0.id, name: $0.name, expiry: $0.expiry, warnDays: $0.warnDays) }
            await ExpiryNotifier.reschedule(targets, enabled: notifyExpiry)
        }
    }

    private var initialKind: ItemKind {
        if case .kind(let k) = filter { k } else { .daily }
    }

    @ViewBuilder private var content: some View {
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let sections = StockSorter.sections(visible.map(\.entry), now: now)
        if visible.isEmpty {
            emptyState
        } else {
            List {
                if !sections.attention.isEmpty {
                    Section {
                        ForEach(sections.attention.compactMap { byID[$0.id] }) { row($0, highlight: true) }
                    } header: {
                        Label("要確認", systemImage: "exclamationmark.circle.fill").foregroundStyle(.orange)
                    }
                }
                if !sections.others.isEmpty {
                    Section(sections.attention.isEmpty ? "" : "ほかの品") {
                        ForEach(sections.others.compactMap { byID[$0.id] }) { row($0, highlight: false) }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func row(_ item: Item, highlight: Bool) -> some View {
        ItemRowView(
            item: item, now: now,
            onEdit: { editing = item },
            onSetRemaining: { ItemActions.setRemaining(item, to: $0, in: context) },
            onRestock: { withAnimation { ItemActions.restock(item, in: context) } },
            onCheck: { withAnimation { ItemActions.markChecked(item) } }
        )
        .listRowBackground(highlight ? Color.orange.opacity(0.10) : nil)
        .swipeActions(edge: .leading) {
            if item.tracksRemaining {
                Button { withAnimation { ItemActions.restock(item, in: context) } } label: { Label("買った", systemImage: "cart.badge.plus") }
                    .tint(.blue)
            } else {
                Button { withAnimation { ItemActions.markChecked(item) } } label: { Label("点検した", systemImage: "checkmark.circle") }
                    .tint(.green)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { withAnimation { ItemActions.delete(item, in: context) } } label: { Label("削除", systemImage: "trash") }
        }
    }

    @ViewBuilder private var emptyState: some View {
        if items.isEmpty {
            ContentUnavailableView {
                Label("まだ何もありません", systemImage: "cart")
            } description: {
                Text("よく買うものを追加して、残量をスライドで記録しましょう。")
            } actions: {
                Button("品目を追加") { adding = true }.buttonStyle(.borderedProminent)
                Button("防災バッグの定番から追加") { showingKit = true }
            }
        } else if !search.isEmpty {
            ContentUnavailableView.search(text: search)
        } else {
            ContentUnavailableView {
                Label("この種別の品はありません", systemImage: "tray")
            } actions: {
                if case .kind(.disaster) = filter {
                    Button("防災バッグの定番から追加") { showingKit = true }.buttonStyle(.borderedProminent)
                } else {
                    Button("品目を追加") { adding = true }.buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
