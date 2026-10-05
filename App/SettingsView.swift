import StockCore
import SwiftData
import SwiftUI

enum AppLinks {
    /// GitHub Pages(リポジトリの docs/privacy-policy.md)
    static let privacyPolicy: URL? = URL(string: "https://daichaco.github.io/StockNote/privacy-policy")
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("expiryNotifications") private var notifyExpiry = true
    @AppStorage("defaultThreshold") private var defaultThreshold = 0.25
    @Environment(PurchaseStore.self) private var store

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if store.adsRemoved == true {
                        Label("広告を消しました。ありがとうございます", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            Task { await store.purchase() }
                        } label: {
                            HStack {
                                Text("広告を消す")
                                Spacer()
                                Text(store.priceText).foregroundStyle(.secondary)
                            }
                        }
                        .disabled(store.isWorking)
                        .accessibilityIdentifier("remove-ads")
                    }
                    Button("購入を復元") { Task { await store.restore() } }
                        .disabled(store.isWorking)
                } header: {
                    Text("広告")
                } footer: {
                    Text("一度の購入で、ずっと広告が表示されなくなります。機能の制限はありません(無料版でも、すべての機能を使えます)。")
                }

                Section {
                    Toggle("期限の通知", isOn: $notifyExpiry)
                } header: {
                    Text("通知")
                } footer: {
                    Text("期限の警告日の朝9時に通知します。通知が届かないときは、iPhone の設定アプリでこのアプリの通知を許可してください。")
                }

                Section("新しい品の初期値") {
                    Picker("「残りわずか」にする目安", selection: $defaultThreshold) {
                        ForEach([0.0, 0.25, 0.5], id: \.self) { Text(Fmt.threshold($0)).tag($0) }
                    }
                }

                Section {
                    NavigationLink("追加したカテゴリ") { CustomCategoryListView() }
                }

                Section("情報") {
                    if let url = AppLinks.privacyPolicy { Link("プライバシーポリシー", destination: url) }
                    LabeledContent("バージョン", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完了") { dismiss() } } }
            .alert("お知らせ", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                Button("OK") { store.message = nil }
            } message: {
                Text(store.message ?? "")
            }
        }
    }
}

struct CustomCategoryListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomCategory.name) private var categories: [CustomCategory]

    var body: some View {
        List {
            if categories.isEmpty {
                Text("追加したカテゴリはありません。品目の追加・編集画面で「カテゴリを追加…」から作れます。")
                    .foregroundStyle(.secondary)
            }
            ForEach(ItemKind.allCases, id: \.self) { kind in
                let list = categories.filter { $0.kind == kind }
                if !list.isEmpty {
                    Section(kind.title) {
                        ForEach(list) { Text($0.name) }
                            .onDelete { offsets in offsets.map { list[$0] }.forEach(context.delete) }
                    }
                }
            }
        }
        .navigationTitle("追加したカテゴリ")
        .navigationBarTitleDisplayMode(.inline)
    }
}
