import SwiftData
import SwiftUI

@main
struct StockNoteApp: App {
    private let container: ModelContainer
    @State private var store = PurchaseStore()

    init() {
        let container = try! ModelContainer(for: Item.self, RemainingLog.self, CustomCategory.self)
        #if DEBUG
        SampleData.prepare(container.mainContext)
        #endif
        self.container = container
    }

    var body: some Scene {
        WindowGroup { ItemListView() }
            .modelContainer(container)
            .environment(store)
    }
}
