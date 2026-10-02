import StockCore
import SwiftUI

struct ItemRowView: View {
    let item: Item
    let now: Date
    let onEdit: () -> Void
    let onSetRemaining: (Double) -> Void
    let onRestock: () -> Void
    let onCheck: () -> Void

    // ドラッグ中は手元の値だけ動かし、指を離したときに保存する(並び順が指の下で入れ替わらないように)
    @State private var draft: Double

    init(item: Item, now: Date, onEdit: @escaping () -> Void, onSetRemaining: @escaping (Double) -> Void,
         onRestock: @escaping () -> Void, onCheck: @escaping () -> Void) {
        self.item = item
        self.now = now
        self.onEdit = onEdit
        self.onSetRemaining = onSetRemaining
        self.onRestock = onRestock
        self.onCheck = onCheck
        _draft = State(initialValue: item.remaining)
    }

    private var reasons: [AttentionReason] { item.entry.attention(now: now) }
    private var status: ExpiryStatus { item.entry.expiryStatus(now: now) }
    private var sliderColor: Color { draft <= item.lowThreshold ? .orange : .accentColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.name).font(.headline)
                if !item.tracksRemaining, item.quantity > 1 {
                    Text("×\(item.quantity)").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                ForEach(Array(reasons.enumerated()), id: \.offset) { _, r in
                    let b = Fmt.badge(r)
                    Text(b.text)
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(b.color.opacity(0.18), in: Capsule())
                        .foregroundStyle(b.color)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("タップして編集")

            if item.tracksRemaining {
                HStack(spacing: 10) {
                    Slider(value: $draft, in: 0...1, step: 1.0 / Double(RemainingStep.steps)) { editing in
                        if !editing, abs(draft - item.remaining) > 0.001 { onSetRemaining(draft) }
                    }
                    .tint(sliderColor)
                    .accessibilityLabel("\(item.name)の残量")
                    .accessibilityValue(Fmt.percent(draft))
                    Text(Fmt.percent(draft))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(sliderColor)
                        .frame(width: 48, alignment: .trailing)
                }
                .sensoryFeedback(.selection, trigger: draft)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(caption).font(.caption).foregroundStyle(.secondary)
                if let expiry = item.expiry, status != .none {
                    Text(Fmt.expiry(expiry, status: status))
                        .font(.caption)
                        .foregroundStyle(expiryColor)
                }
            }

            if !reasons.isEmpty {
                Button(item.tracksRemaining ? "買った" : "点検した", action: item.tracksRemaining ? onRestock : onCheck)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier((item.tracksRemaining ? "restock-" : "check-") + item.name)
            }
        }
        .padding(.vertical, 4)
        .onChange(of: item.remaining) { _, new in draft = new }
    }

    private var caption: String {
        if item.tracksRemaining {
            return [Fmt.purchase(item.purchasedAt, now: now), item.category].filter { !$0.isEmpty }.joined(separator: " ・ ")
        }
        let checked = item.lastCheckedAt.map { "最終点検 \(Fmt.date($0))" } ?? "未点検"
        return [item.category, checked].filter { !$0.isEmpty }.joined(separator: " ・ ")
    }

    private var expiryColor: Color {
        switch status {
        case .expired: .red
        case .soon: .orange
        default: .secondary
        }
    }
}
