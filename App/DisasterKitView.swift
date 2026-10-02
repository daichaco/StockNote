import StockCore
import SwiftData
import SwiftUI

/// 防災バッグの定番から選んで、まとめて追加する
struct DisasterKitView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var items: [Item]
    @State private var selected: Set<String> = []

    private var existing: Set<String> { Set(items.filter { $0.kind == .disaster }.map(\.name)) }
    private var addable: [Presets.KitItem] { Presets.disasterKit.filter { !existing.contains($0.name) } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Presets.disasterKit, id: \.name) { kit in
                        let added = existing.contains(kit.name)
                        Button {
                            if selected.contains(kit.name) { selected.remove(kit.name) } else { selected.insert(kit.name) }
                        } label: {
                            HStack {
                                Image(systemName: added ? "checkmark.circle.fill" : (selected.contains(kit.name) ? "checkmark.circle.fill" : "circle"))
                                    .foregroundStyle(added ? Color.secondary : Color.accentColor)
                                VStack(alignment: .leading) {
                                    Text(kit.name).foregroundStyle(.primary)
                                    Text(kit.category + (kit.hasExpiry ? " ・ 期限あり" : "")).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if added { Text("追加済み").font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                        .disabled(added)
                    }
                } footer: {
                    Text("一般的な備えの目安です。ご家庭に合わせて追加・削除してください。追加したあと、期限がある品は各品を開いて期限を入力できます。")
                }
            }
            .navigationTitle("防災バッグの定番")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .bottomBar) {
                    Button(selected.count == addable.count ? "選択を外す" : "すべて選ぶ") {
                        selected = selected.count == addable.count ? [] : Set(addable.map(\.name))
                    }
                    .disabled(addable.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加(\(selected.count))") { add() }.disabled(selected.isEmpty)
                }
            }
        }
    }

    private func add() {
        for kit in Presets.disasterKit where selected.contains(kit.name) && !existing.contains(kit.name) {
            context.insert(Item(name: kit.name, kind: .disaster, category: kit.category))
        }
        dismiss()
    }
}
