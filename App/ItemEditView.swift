import StockCore
import SwiftData
import SwiftUI

struct ItemEditView: View {
    let item: Item?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var customCategories: [CustomCategory]
    @AppStorage("expiryNotifications") private var notifyExpiry = true
    @AppStorage("defaultThreshold") private var defaultThreshold = 0.25

    @State private var name = ""
    @State private var kind: ItemKind
    @State private var category = ""
    @State private var purchasedAt = Date()
    @State private var tracksRemaining: Bool
    @State private var remaining = 1.0
    @State private var lowThreshold = 0.25
    @State private var hasExpiry = false
    @State private var expiry = Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now
    @State private var warnDays: Int
    @State private var quantity = 1
    @State private var note = ""
    @State private var newCategoryName = ""
    @State private var addingCategory = false
    @State private var confirmDelete = false

    init(item: Item?, initialKind: ItemKind) {
        self.item = item
        _kind = State(initialValue: item?.kind ?? initialKind)
        _tracksRemaining = State(initialValue: item?.tracksRemaining ?? initialKind.tracksRemainingByDefault)
        _warnDays = State(initialValue: item?.warnDays ?? initialKind.defaultWarnDays)
    }

    private var categories: [String] {
        var list = Categories.all(for: kind, custom: customCategories)
        if !category.isEmpty, !list.contains(category) { list.append(category) }
        return list
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("品名", text: $name)
                    Picker("種別", selection: $kind) {
                        ForEach(ItemKind.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { _, new in kindChanged(new) }
                    Picker("カテゴリ", selection: $category) {
                        Text("なし").tag("")
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                    Button("カテゴリを追加…") { addingCategory = true }
                }

                Section("購入") {
                    DatePicker("購入日", selection: $purchasedAt, displayedComponents: .date)
                }

                Section {
                    Toggle("残量を記録する", isOn: $tracksRemaining)
                    if tracksRemaining {
                        VStack(alignment: .leading) {
                            Text("いまの残量 \(Fmt.percent(remaining))")
                            Slider(value: $remaining, in: 0...1, step: 0.25)
                        }
                        Picker("「残りわずか」にする目安", selection: $lowThreshold) {
                            ForEach([0.0, 0.25, 0.5], id: \.self) { Text(Fmt.threshold($0)).tag($0) }
                        }
                    }
                } footer: {
                    if kind == .disaster { Text("防災バッグの品は、期限と点検日を中心に管理します。電池など、使って減るものだけ残量をオンにしてください。") }
                }

                Section {
                    Toggle("期限がある", isOn: $hasExpiry.animation())
                    if hasExpiry {
                        DatePicker("期限", selection: $expiry, displayedComponents: .date)
                        Picker("警告を出す時期", selection: $warnDays) {
                            ForEach(warnChoices, id: \.self) { Text("\($0)日前から").tag($0) }
                        }
                    }
                } footer: {
                    if hasExpiry { Text("警告日の朝9時に通知します(設定でオフにできます)。") }
                }

                if kind == .disaster {
                    Section("数量") { Stepper("\(quantity) 個", value: $quantity, in: 1...99) }
                }

                Section("メモ") { TextField("メモ", text: $note, axis: .vertical).lineLimit(1...4) }

                if item != nil {
                    Section {
                        Button("この品を削除", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(item == nil ? "品目を追加" : "品目を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("カテゴリを追加", isPresented: $addingCategory) {
                TextField("カテゴリ名", text: $newCategoryName)
                Button("追加") { addCategory() }
                Button("キャンセル", role: .cancel) { newCategoryName = "" }
            }
            .confirmationDialog("この品を削除しますか?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    if let item { ItemActions.delete(item, in: context) }
                    dismiss()
                }
            }
            .onAppear(perform: load)
        }
    }

    private var warnChoices: [Int] {
        let base = [7, 14, 30, 60, 90, 180]
        return base.contains(warnDays) ? base : (base + [warnDays]).sorted()
    }

    private func load() {
        guard let item else {
            lowThreshold = defaultThreshold
            category = Presets.categories(for: kind).first ?? ""
            return
        }
        name = item.name
        category = item.category
        purchasedAt = item.purchasedAt
        remaining = item.remaining
        lowThreshold = item.lowThreshold
        if let e = item.expiry { hasExpiry = true; expiry = e }
        quantity = item.quantity
        note = item.note
    }

    /// 種別を変えたときは、その種別に合わせて初期値を入れ直す(追加のときだけ)
    private func kindChanged(_ new: ItemKind) {
        if !categories.contains(category) || item == nil { category = Presets.categories(for: new).first ?? "" }
        if item == nil {
            tracksRemaining = new.tracksRemainingByDefault
            warnDays = new.defaultWarnDays
        }
    }

    private func addCategory() {
        let n = newCategoryName.trimmingCharacters(in: .whitespaces)
        newCategoryName = ""
        guard !n.isEmpty else { return }
        if !Categories.all(for: kind, custom: customCategories).contains(n) {
            context.insert(CustomCategory(name: n, kind: kind))
        }
        category = n
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let exp = hasExpiry ? Calendar.current.startOfDay(for: expiry) : nil
        let target: Item
        if let item {
            target = item
        } else {
            target = Item(name: trimmed, kind: kind, category: category)
            context.insert(target)
        }
        let remainingChanged = item == nil ? tracksRemaining : abs(target.remaining - remaining) > 0.001
        target.name = trimmed
        target.kind = kind
        target.category = category
        target.purchasedAt = purchasedAt
        target.tracksRemaining = tracksRemaining
        target.lowThreshold = lowThreshold
        target.expiry = exp
        target.warnDays = warnDays
        target.quantity = quantity
        target.note = note
        if tracksRemaining, remainingChanged {
            ItemActions.setRemaining(target, to: remaining, in: context)
        } else if item == nil {
            target.remaining = remaining
        }
        if exp != nil, notifyExpiry {
            Task { await ExpiryNotifier.requestAuthorizationIfNeeded() }
        }
        dismiss()
    }
}
