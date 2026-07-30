import ARKit
import Foundation
import simd

struct Vector3: Codable, Hashable {
    let x: Float
    let y: Float
    let z: Float

    init(_ value: SIMD3<Float>) {
        x = value.x
        y = value.y
        z = value.z
    }

    var simdValue: SIMD3<Float> {
        SIMD3<Float>(x, y, z)
    }
}

struct Matrix4x4: Codable, Hashable {
    let values: [Float]

    init(_ matrix: simd_float4x4) {
        values = [
            matrix.columns.0.x, matrix.columns.0.y,
            matrix.columns.0.z, matrix.columns.0.w,
            matrix.columns.1.x, matrix.columns.1.y,
            matrix.columns.1.z, matrix.columns.1.w,
            matrix.columns.2.x, matrix.columns.2.y,
            matrix.columns.2.z, matrix.columns.2.w,
            matrix.columns.3.x, matrix.columns.3.y,
            matrix.columns.3.z, matrix.columns.3.w
        ]
    }

    var simdValue: simd_float4x4 {
        guard values.count == 16 else {
            return matrix_identity_float4x4
        }

        return simd_float4x4(
            SIMD4<Float>(values[0], values[1], values[2], values[3]),
            SIMD4<Float>(values[4], values[5], values[6], values[7]),
            SIMD4<Float>(values[8], values[9], values[10], values[11]),
            SIMD4<Float>(values[12], values[13], values[14], values[15])
        )
    }

    var position: SIMD3<Float> {
        guard values.count == 16 else {
            return .zero
        }
        return SIMD3<Float>(values[12], values[13], values[14])
    }
}

extension simd_float4x4 {
    var position: SIMD3<Float> {
        SIMD3<Float>(
            columns.3.x,
            columns.3.y,
            columns.3.z
        )
    }

    var forward: SIMD3<Float> {
        simd_normalize(
            -SIMD3<Float>(
                columns.2.x,
                columns.2.y,
                columns.2.z
            )
        )
    }
}

struct PoseSample: Codable, Hashable {
    let elapsedSeconds: TimeInterval
    let cameraTransform: Matrix4x4
}

enum BarcodePositionSource: String, Codable, Hashable {
    case surfaceRaycast
    case cameraEstimate

    var title: String {
        switch self {
        case .surfaceRaycast:
            return "LiDAR surface"
        case .cameraEstimate:
            return "Estimated"
        }
    }
}

struct BarcodeObservation: Codable, Hashable, Identifiable {
    let id: UUID
    let payload: String
    let symbology: String
    let worldPosition: Vector3
    let cameraTransform: Matrix4x4
    let capturedAt: Date
    let positionSource: BarcodePositionSource
    let seenCount: Int

    init(
        id: UUID = UUID(),
        payload: String,
        symbology: String,
        worldPosition: SIMD3<Float>,
        cameraTransform: simd_float4x4,
        capturedAt: Date = Date(),
        positionSource: BarcodePositionSource,
        seenCount: Int = 1
    ) {
        self.id = id
        self.payload = payload
        self.symbology = symbology
        self.worldPosition = Vector3(worldPosition)
        self.cameraTransform = Matrix4x4(cameraTransform)
        self.capturedAt = capturedAt
        self.positionSource = positionSource
        self.seenCount = seenCount
    }

    func confirming(
        worldPosition: SIMD3<Float>,
        cameraTransform: simd_float4x4,
        positionSource: BarcodePositionSource
    ) -> BarcodeObservation {
        BarcodeObservation(
            id: id,
            payload: payload,
            symbology: symbology,
            worldPosition: worldPosition,
            cameraTransform: cameraTransform,
            capturedAt: capturedAt,
            positionSource: positionSource,
            seenCount: seenCount + 1
        )
    }
}

struct MeshSnapshot: Codable, Identifiable {
    let id: UUID
    let transform: Matrix4x4
    let vertices: [Vector3]
    let normals: [Vector3]?
    let triangleIndices: [UInt32]
    let triangleClassifications: [Int]?

    init(anchor: ARMeshAnchor) {
        id = anchor.identifier
        transform = Matrix4x4(anchor.transform)
        vertices = (0..<anchor.geometry.vertices.count).map {
            Vector3(anchor.geometry.vertex(at: $0))
        }
        normals = (0..<anchor.geometry.normals.count).map {
            Vector3(anchor.geometry.normal(at: $0))
        }
        triangleIndices = anchor.geometry.triangleIndices()
        triangleClassifications = (0..<anchor.geometry.faces.count).map {
            anchor.geometry.classificationOfFace(at: $0).rawValue
        }
    }

    init?(
        anchor: ARMeshAnchor,
        clippingTo boundary: ZoneBoundary
    ) {
        id = anchor.identifier
        transform = Matrix4x4(anchor.transform)
        let localVertices = (0..<anchor.geometry.vertices.count).map {
            anchor.geometry.vertex(at: $0)
        }
        vertices = localVertices.map(Vector3.init)
        normals = (0..<anchor.geometry.normals.count).map {
            Vector3(anchor.geometry.normal(at: $0))
        }

        let sourceIndices = anchor.geometry.triangleIndices()
        let sourceClassifications = (0..<anchor.geometry.faces.count).map {
            anchor.geometry.classificationOfFace(at: $0).rawValue
        }
        var clippedIndices: [UInt32] = []
        var clippedClassifications: [Int] = []

        for triangle in 0..<(sourceIndices.count / 3) {
            let offset = triangle * 3
            let indices = [
                Int(sourceIndices[offset]),
                Int(sourceIndices[offset + 1]),
                Int(sourceIndices[offset + 2])
            ]
            guard indices.allSatisfy({
                $0 >= 0 && $0 < localVertices.count
            }) else {
                continue
            }

            let worldPoints = indices.map { index -> SIMD3<Float> in
                let local = localVertices[index]
                let world = anchor.transform * SIMD4<Float>(
                    local.x,
                    local.y,
                    local.z,
                    1
                )
                return SIMD3<Float>(world.x, world.y, world.z)
            }
            let centroid = (
                worldPoints[0] + worldPoints[1] + worldPoints[2]
            ) / 3
            let intersectsBoundary = boundary.contains(
                x: centroid.x,
                z: centroid.z
            ) || worldPoints.contains {
                boundary.contains(x: $0.x, z: $0.z)
            }

            guard intersectsBoundary else {
                continue
            }

            clippedIndices.append(contentsOf: [
                sourceIndices[offset],
                sourceIndices[offset + 1],
                sourceIndices[offset + 2]
            ])
            if triangle < sourceClassifications.count {
                clippedClassifications.append(
                    sourceClassifications[triangle]
                )
            }
        }

        guard !clippedIndices.isEmpty else {
            return nil
        }
        triangleIndices = clippedIndices
        triangleClassifications = clippedClassifications
    }
}

struct ScanArchive: Codable, Identifiable {
    let archiveVersion: Int
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let deviceName: String
    let systemVersion: String
    let distanceMeters: Float
    let poses: [PoseSample]
    let meshes: [MeshSnapshot]
    let zoneID: UUID?
    let worldMapData: Data?
    let barcodeObservations: [BarcodeObservation]?

    var detectedBarcodes: [BarcodeObservation] {
        barcodeObservations ?? []
    }

    init(
        id: UUID,
        startedAt: Date,
        endedAt: Date,
        deviceName: String,
        systemVersion: String,
        distanceMeters: Float,
        poses: [PoseSample],
        meshes: [MeshSnapshot],
        zoneID: UUID? = nil,
        worldMapData: Data? = nil,
        barcodeObservations: [BarcodeObservation] = []
    ) {
        archiveVersion = 4
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.deviceName = deviceName
        self.systemVersion = systemVersion
        self.distanceMeters = distanceMeters
        self.poses = poses
        self.meshes = meshes
        self.zoneID = zoneID
        self.worldMapData = worldMapData
        self.barcodeObservations = barcodeObservations
    }
}

struct SavedScanSummary: Identifiable {
    let id: UUID
    let startedAt: Date
    let duration: TimeInterval
    let distanceMeters: Float
    let meshCount: Int
    let poseCount: Int
    let barcodeCount: Int
    let fileURL: URL
}

struct InventoryLocationIndexEntry: Codable, Hashable, Identifiable {
    let id: UUID
    let archiveID: UUID
    let barcode: String
    let symbology: String
    let worldPosition: Vector3
    let capturedAt: Date
    let scanStartedAt: Date
}

private struct InventoryLocationIndex: Codable {
    var indexedArchiveIDs: Set<UUID>
    var locations: [InventoryLocationIndexEntry]
}

enum ScanStore {
    private static let binaryEncoder: PropertyListEncoder = {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return encoder
    }()

    private static let binaryDecoder = PropertyListDecoder()

    private static let legacyJSONDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func save(_ archive: ScanArchive) throws -> URL {
        let fileURL = try fileURL(id: archive.id)

        let data = try binaryEncoder.encode(archive)
        try data.write(to: fileURL, options: .atomic)
        try? updateInventoryIndex(with: archive)
        return fileURL
    }

    static func load(from fileURL: URL) throws -> ScanArchive {
        let data = try Data(contentsOf: fileURL)

        if let archive = try? binaryDecoder.decode(ScanArchive.self, from: data) {
            return archive
        }

        return try legacyJSONDecoder.decode(ScanArchive.self, from: data)
    }

    static func load(id: UUID) throws -> ScanArchive {
        try load(from: fileURL(id: id))
    }

    static func fileURL(id: UUID) throws -> URL {
        try scansDirectory()
            .appendingPathComponent(id.uuidString)
            .appendingPathExtension("warehouse-scan")
    }

    static func exportURL(
        id: UUID,
        suggestedName: String
    ) throws -> URL {
        let source = try fileURL(id: id)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WarehouseMapperExports", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let safeName = suggestedName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let destination = directory
            .appendingPathComponent(safeName)
            .appendingPathExtension("warehouse-scan")
        let data = try Data(contentsOf: source)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    static func list() throws -> [SavedScanSummary] {
        let directory = try scansDirectory()
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        return try urls
            .filter { $0.pathExtension == "warehouse-scan" }
            .map { url in
                let archive = try load(from: url)
                return SavedScanSummary(
                    id: archive.id,
                    startedAt: archive.startedAt,
                    duration: archive.endedAt.timeIntervalSince(archive.startedAt),
                    distanceMeters: archive.distanceMeters,
                    meshCount: archive.meshes.count,
                    poseCount: archive.poses.count,
                    barcodeCount: archive.detectedBarcodes.count,
                    fileURL: url
                )
            }
            .sorted { $0.startedAt > $1.startedAt }
    }

    static func inventoryLocations() throws -> [InventoryLocationIndexEntry] {
        let archiveURLs = try scanURLs()
        let archiveIDs = Set(
            archiveURLs.compactMap {
                UUID(uuidString: $0.deletingPathExtension().lastPathComponent)
            }
        )

        if let index = try? loadInventoryIndex(),
           index.indexedArchiveIDs == archiveIDs {
            return index.locations.sorted {
                $0.capturedAt > $1.capturedAt
            }
        }

        var rebuilt = InventoryLocationIndex(
            indexedArchiveIDs: [],
            locations: []
        )
        for url in archiveURLs {
            let archive = try load(from: url)
            rebuilt.indexedArchiveIDs.insert(archive.id)
            rebuilt.locations.append(
                contentsOf: inventoryLocations(in: archive)
            )
        }
        try persistInventoryIndex(rebuilt)
        return rebuilt.locations.sorted {
            $0.capturedAt > $1.capturedAt
        }
    }

    static func exportBarcodesCSV(
        archive: ScanArchive,
        zoneName: String,
        catalog: [String: BarcodeProductRecord] = [:]
    ) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WarehouseMapperExports", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let safeName = zoneName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let destination = directory
            .appendingPathComponent("\(safeName)-Inventory-Locations")
            .appendingPathExtension("csv")

        var rows = [
            "product_name,sku,code,type,x_meters,y_meters,z_meters,position_quality,confirmations,notes,captured_at"
        ]
        let formatter = ISO8601DateFormatter()

        for observation in archive.detectedBarcodes {
            let position = observation.worldPosition
            let record = catalog[observation.payload]
            rows.append([
                csvField(record?.name ?? ""),
                csvField(record?.sku ?? ""),
                csvField(observation.payload),
                csvField(observation.symbology),
                String(format: "%.3f", position.x),
                String(format: "%.3f", position.y),
                String(format: "%.3f", position.z),
                csvField(observation.positionSource.title),
                String(observation.seenCount),
                csvField(record?.notes ?? ""),
                csvField(formatter.string(from: observation.capturedAt))
            ].joined(separator: ","))
        }

        try rows.joined(separator: "\n")
            .appending("\n")
            .write(
                to: destination,
                atomically: true,
                encoding: .utf8
            )
        return destination
    }

    private static func csvField(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func updateInventoryIndex(
        with archive: ScanArchive
    ) throws {
        var index = (try? loadInventoryIndex())
            ?? InventoryLocationIndex(
                indexedArchiveIDs: [],
                locations: []
            )
        index.locations.removeAll {
            $0.archiveID == archive.id
        }
        index.locations.append(
            contentsOf: inventoryLocations(in: archive)
        )
        index.indexedArchiveIDs.insert(archive.id)
        try persistInventoryIndex(index)
    }

    private static func inventoryLocations(
        in archive: ScanArchive
    ) -> [InventoryLocationIndexEntry] {
        archive.detectedBarcodes.map { observation in
            InventoryLocationIndexEntry(
                id: observation.id,
                archiveID: archive.id,
                barcode: observation.payload,
                symbology: observation.symbology,
                worldPosition: observation.worldPosition,
                capturedAt: observation.capturedAt,
                scanStartedAt: archive.startedAt
            )
        }
    }

    private static func loadInventoryIndex() throws -> InventoryLocationIndex {
        let data = try Data(contentsOf: inventoryIndexURL())
        return try binaryDecoder.decode(
            InventoryLocationIndex.self,
            from: data
        )
    }

    private static func persistInventoryIndex(
        _ index: InventoryLocationIndex
    ) throws {
        let data = try binaryEncoder.encode(index)
        try data.write(to: inventoryIndexURL(), options: .atomic)
    }

    private static func inventoryIndexURL() throws -> URL {
        try scansDirectory()
            .appendingPathComponent("InventoryLocationIndex")
            .appendingPathExtension("plist")
    }

    private static func scanURLs() throws -> [URL] {
        let directory = try scansDirectory()
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "warehouse-scan" }
    }

    private static func scansDirectory() throws -> URL {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        let directory = documents.appendingPathComponent(
            "WarehouseMapperScans",
            isDirectory: true
        )

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory
    }
}
