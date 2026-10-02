import GoogleMobileAds
import SwiftUI
import UIKit

enum AdConfig {
    /// バナーの広告ユニット ID。
    /// Debug は Google 公式のテスト用。Release は、本番の ID を発行して入れるまで nil(広告を出さない)。
    /// テスト用 ID のまま公開しないための安全策。手順は docs/ads-setup.md。
    static var bannerUnitID: String? {
        #if DEBUG
        // スクリーンショット撮影用に、起動引数 -hideAds で広告枠を隠せる(Release には入らない)
        ProcessInfo.processInfo.arguments.contains("-hideAds") ? nil : "ca-app-pub-3940256099942544/2934735716"
        #else
        nil
        #endif
    }

    private static var started = false

    /// 広告を出す人にだけ、SDK を起動する(購入済みの人には起動しない)
    static func startIfNeeded() {
        guard !started else { return }
        started = true
        MobileAds.shared.start(completionHandler: nil)
    }

    /// パーソナライズなし広告(トラッキング許可のダイアログを出さずに済ませる)
    static func makeRequest() -> Request {
        let request = Request()
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        return request
    }
}

/// 一覧の最下部に固定するバナー。購入済み、または確認中のときは何も出さない。
struct AdBannerContainer: View {
    @Environment(PurchaseStore.self) private var store
    var onRemoveAds: () -> Void

    @State private var height: CGFloat = 50

    var body: some View {
        if store.adsRemoved == false, let unitID = AdConfig.bannerUnitID {
            VStack(spacing: 0) {
                HStack {
                    Text("広告").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Button("広告を消す", action: onRemoveAds)
                        .font(.caption)
                        .accessibilityIdentifier("ad-remove-link")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)

                GeometryReader { geo in
                    AdBannerRepresentable(unitID: unitID, width: geo.size.width, height: $height)
                        .frame(width: geo.size.width, height: height)
                        .clipped()
                }
                .frame(height: height)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
            .clipped()
            .onAppear { AdConfig.startIfNeeded() }
        }
    }
}

private struct AdBannerRepresentable: UIViewRepresentable {
    let unitID: String
    let width: CGFloat
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView()
        banner.adUnitID = unitID
        banner.backgroundColor = .clear
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        guard width > 0, context.coordinator.loadedWidth != width else { return }
        context.coordinator.loadedWidth = width
        let size = currentOrientationAnchoredAdaptiveBanner(width: width)
        banner.adSize = size
        DispatchQueue.main.async { height = size.size.height }
        banner.load(AdConfig.makeRequest())
    }

    /// 広告の中身が画面より広くても、枠は画面幅に収める(左右の「広告を消す」を押し出さない)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: BannerView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? width, height: height)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loadedWidth: CGFloat = 0
    }
}
