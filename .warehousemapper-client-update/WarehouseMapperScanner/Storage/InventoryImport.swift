import Foundation

struct InventoryImportRow: Hashable {
    let zoneName: String
    let category: String
    let quantity: Int
    let positionsUsed: Int?
}

enum InventoryImportError: LocalizedError {
    case unreadableFile
    case missingHeaders
    case noUsableRows

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "The selected file could not be read as CSV or tab-separated text."
        case .missingHeaders:
            return "The file needs zone, category, and quantity columns. positions_used is optional."
        case .noUsableRows:
            return "No rows contained a zone, category, and nonnegative quantity."
        }
    }
}

enum InventoryImportParser {
    static func parse(data: Data) throws -> [InventoryImportRow] {
        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16) else {
            throw InventoryImportError.unreadableFile
        }

        let delimiter: Character = text.contains("\t") ? "\t" : ","
        let records = parseRecords(text, delimiter: delimiter)
            .filter { row in
                row.contains {
                    !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            }

        guard let header = records.first else {
            throw InventoryImportError.noUsableRows
        }

        let normalizedHeaders = header.map(normalizeHeader)
        guard let zoneIndex = index(
            in: normalizedHeaders,
            matching: ["zone", "zone_name", "location", "area"]
        ),
        let categoryIndex = index(
            in: normalizedHeaders,
            matching: ["category", "type", "item", "item_type", "company"]
        ),
        let quantityIndex = index(
            in: normalizedHeaders,
            matching: ["quantity", "qty", "count", "units"]
        ) else {
            throw InventoryImportError.missingHeaders
        }

        let positionsIndex = index(
            in: normalizedHeaders,
            matching: [
                "positions",
                "positions_used",
                "pallet_positions",
                "space_used"
            ]
        )

        let rows = records.dropFirst().compactMap { record -> InventoryImportRow? in
            guard zoneIndex < record.count,
                  categoryIndex < record.count,
                  quantityIndex < record.count else {
                return nil
            }

            let zone = record[zoneIndex].trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let category = record[categoryIndex].trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !zone.isEmpty,
                  !category.isEmpty,
                  let quantity = integer(record[quantityIndex]),
                  quantity >= 0 else {
                return nil
            }

            let positions: Int? = positionsIndex.flatMap { positionIndex -> Int? in
                guard positionIndex < record.count else {
                    return nil
                }
                return integer(record[positionIndex])
            }

            return InventoryImportRow(
                zoneName: zone,
                category: category,
                quantity: quantity,
                positionsUsed: positions.map { max(0, $0) }
            )
        }

        guard !rows.isEmpty else {
            throw InventoryImportError.noUsableRows
        }
        return rows
    }

    private static func parseRecords(
        _ text: String,
        delimiter: Character
    ) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var insideQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if character == "\"" {
                let next = text.index(after: index)
                if insideQuotes,
                   next < text.endIndex,
                   text[next] == "\"" {
                    field.append("\"")
                    index = next
                } else {
                    insideQuotes.toggle()
                }
            } else if character == delimiter && !insideQuotes {
                row.append(field)
                field = ""
            } else if (character == "\n" || character == "\r")
                        && !insideQuotes {
                if character == "\r" {
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\n" {
                        index = next
                    }
                }
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else {
                field.append(character)
            }

            index = text.index(after: index)
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    private static func normalizeHeader(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    private static func index(
        in headers: [String],
        matching aliases: Set<String>
    ) -> Int? {
        headers.firstIndex { aliases.contains($0) }
    }

    private static func integer(_ value: String) -> Int? {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")

        if let integer = Int(cleaned) {
            return integer
        }
        if let decimal = Double(cleaned) {
            return Int(decimal.rounded())
        }
        return nil
    }
}
