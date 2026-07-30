import SwiftUI

@main
struct WarehouseMapperScannerApp: App {
    @StateObject private var warehouseStore: WarehouseMapStore
    @StateObject private var scanner: ScanSessionController
    @StateObject private var barcodeCatalog: BarcodeCatalogStore
    @StateObject private var accountStore: LocalAccountStore

    init() {
        let store = WarehouseMapStore()
        _warehouseStore = StateObject(wrappedValue: store)
        _accountStore = StateObject(
            wrappedValue: LocalAccountStore()
        )
        _barcodeCatalog = StateObject(
            wrappedValue: BarcodeCatalogStore()
        )
        _scanner = StateObject(
            wrappedValue: ScanSessionController(warehouseStore: store)
        )
    }

    var body: some Scene {
        WindowGroup {
            AccountRootView()
                .environmentObject(scanner)
                .environmentObject(warehouseStore)
                .environmentObject(barcodeCatalog)
                .environmentObject(accountStore)
        }
    }
}
