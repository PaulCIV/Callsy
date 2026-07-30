import Combine
import Foundation

struct BarcodeProductRecord: Codable, Hashable, Identifiable {
    var id: String { barcode }

    let barcode: String
    var name: String
    var sku: String
    var notes: String
    var updatedAt: Date
}

final class BarcodeCatalogStore: ObservableObject {
    @Published private(set) var records: [String: BarcodeProductRecord]

    init() {
        records = Self.load()
    }

    func record(for barcode: String) -> BarcodeProductRecord? {
        records[barcode]
    }

    func displayName(for barcode: String) -> String {
        let name = records[barcode]?
            .name
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Unlabeled item" : name
    }

    func save(
        barcode: String,
        name: String,
        sku: String,
        notes: String
    ) {
        records[barcode] = BarcodeProductRecord(
            barcode: barcode,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            sku: sku.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            updatedAt: Date()
        )
        persist()
    }

    private func persist() {
        do {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            let data = try encoder.encode(records)
            try data.write(to: Self.catalogURL(), options: .atomic)
        } catch {
            assertionFailure(
                "Unable to save the local barcode catalog: \(error)"
            )
        }
    }

    private static func load() -> [String: BarcodeProductRecord] {
        do {
            let data = try Data(contentsOf: catalogURL())
            return try PropertyListDecoder().decode(
                [String: BarcodeProductRecord].self,
                from: data
            )
        } catch {
            return [:]
        }
    }

    private static func catalogURL() throws -> URL {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return documents.appendingPathComponent(
            "WarehouseMapperBarcodeCatalog.plist"
        )
    }
}
