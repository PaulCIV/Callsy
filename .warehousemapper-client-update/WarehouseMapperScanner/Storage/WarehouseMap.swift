import Combine
import Foundation
import simd

enum MeasurementUnitPreference: String, Codable, CaseIterable, Identifiable {
    case feet
    case meters

    var id: Self { self }

    var title: String {
        switch self {
        case .feet:
            return "Feet"
        case .meters:
            return "Meters"
        }
    }

    var shortSymbol: String {
        switch self {
        case .feet:
            return "ft"
        case .meters:
            return "m"
        }
    }

    func displayValue(forMeters meters: Float) -> Double {
        switch self {
        case .feet:
            return Double(meters * 3.28084)
        case .meters:
            return Double(meters)
        }
    }

    func meters(fromDisplayValue value: Double) -> Float {
        switch self {
        case .feet:
            return Float(value / 3.28084)
        case .meters:
            return Float(value)
        }
    }
}

enum WarehouseZoneKind: String, Codable, CaseIterable, Identifiable {
    case aisle
    case bulkStorage
    case receiving
    case packing
    case shipping
    case coldStorage
    case equipment
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .aisle:
            return "Rack aisle"
        case .bulkStorage:
            return "Bulk storage"
        case .receiving:
            return "Receiving"
        case .packing:
            return "Packing"
        case .shipping:
            return "Shipping"
        case .coldStorage:
            return "Cold storage"
        case .equipment:
            return "Equipment"
        case .other:
            return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .aisle:
            return "rectangle.split.3x1"
        case .bulkStorage:
            return "shippingbox.fill"
        case .receiving:
            return "arrow.down.to.line.compact"
        case .packing:
            return "shippingbox.and.arrow.backward.fill"
        case .shipping:
            return "truck.box.fill"
        case .coldStorage:
            return "snowflake"
        case .equipment:
            return "wrench.and.screwdriver.fill"
        case .other:
            return "square.dashed"
        }
    }
}

enum StorageLayoutType: String, Codable, CaseIterable, Identifiable {
    case palletPositions
    case rackBays
    case shelfSections
    case floorStacks
    case mixed

    var id: Self { self }

    var title: String {
        switch self {
        case .palletPositions:
            return "Pallet positions"
        case .rackBays:
            return "Rack bays"
        case .shelfSections:
            return "Shelf sections"
        case .floorStacks:
            return "Floor stacks"
        case .mixed:
            return "Mixed positions"
        }
    }

    var singularUnit: String {
        switch self {
        case .palletPositions:
            return "pallet position"
        case .rackBays:
            return "rack bay"
        case .shelfSections:
            return "shelf section"
        case .floorStacks:
            return "floor position"
        case .mixed:
            return "position"
        }
    }

    var symbol: String {
        switch self {
        case .palletPositions:
            return "square.grid.3x3.square"
        case .rackBays:
            return "rectangle.split.3x1"
        case .shelfSections:
            return "cabinet.fill"
        case .floorStacks:
            return "square.stack.3d.up.fill"
        case .mixed:
            return "square.grid.2x2.fill"
        }
    }
}

enum StorageConstraintClass: String, Codable, CaseIterable, Identifiable {
    case standard
    case temperatureControlled
    case secure
    case oversized
    case restricted

    var id: Self { self }

    var title: String {
        switch self {
        case .standard:
            return "Standard"
        case .temperatureControlled:
            return "Temperature controlled"
        case .secure:
            return "Secure"
        case .oversized:
            return "Oversized"
        case .restricted:
            return "Restricted"
        }
    }

    var explanation: String {
        switch self {
        case .standard:
            return "Ordinary stock that can move to another compatible standard zone."
        case .temperatureControlled:
            return "Stock that must remain in a temperature-controlled area."
        case .secure:
            return "Stock that must remain in a controlled-access area."
        case .oversized:
            return "Large stock that requires oversized storage positions."
        case .restricted:
            return "Stock with handling rules that should not be mixed with other classes."
        }
    }
}

struct ZoneCapacityProfile: Codable, Hashable {
    var layout: StorageLayoutType
    var constraintClass: StorageConstraintClass
    var totalPositions: Int
    var occupiedPositions: Int
    var reservedPositions: Int
    var blockedPositions: Int
    var notes: String
    var verifiedAt: Date
    var observedFill: ZoneFillState?

    init(
        layout: StorageLayoutType = .palletPositions,
        constraintClass: StorageConstraintClass = .standard,
        totalPositions: Int = 0,
        occupiedPositions: Int = 0,
        reservedPositions: Int = 0,
        blockedPositions: Int = 0,
        notes: String = "",
        verifiedAt: Date = Date(),
        observedFill: ZoneFillState? = nil
    ) {
        self.layout = layout
        self.constraintClass = constraintClass
        self.totalPositions = max(0, totalPositions)
        self.occupiedPositions = max(0, occupiedPositions)
        self.reservedPositions = max(0, reservedPositions)
        self.blockedPositions = max(0, blockedPositions)
        self.notes = notes
        self.verifiedAt = verifiedAt
        self.observedFill = observedFill
    }

    var unavailablePositions: Int {
        min(totalPositions, reservedPositions + blockedPositions)
    }

    var usablePositions: Int {
        max(0, totalPositions - unavailablePositions)
    }

    var normalizedOccupiedPositions: Int {
        min(occupiedPositions, usablePositions)
    }

    var availablePositions: Int {
        max(0, usablePositions - normalizedOccupiedPositions)
    }

    var utilization: Double {
        guard usablePositions > 0 else {
            return 0
        }
        return Double(normalizedOccupiedPositions) / Double(usablePositions)
    }

    func isCompatible(with other: ZoneCapacityProfile) -> Bool {
        layout == other.layout
            && constraintClass == other.constraintClass
    }
}

enum ZoneFillState: String, Codable, CaseIterable, Identifiable {
    case empty
    case partial
    case full

    var id: Self { self }

    var title: String {
        switch self {
        case .empty:
            return "Empty"
        case .partial:
            return "Partially full"
        case .full:
            return "Full"
        }
    }

    var symbol: String {
        switch self {
        case .empty:
            return "square.dashed"
        case .partial:
            return "square.lefthalf.filled"
        case .full:
            return "square.fill"
        }
    }
}

struct ZoneInventoryEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var category: String
    var quantity: Int
    var positionsUsed: Int
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        category: String,
        quantity: Int,
        positionsUsed: Int,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.quantity = max(0, quantity)
        self.positionsUsed = max(0, positionsUsed)
        self.updatedAt = updatedAt
    }
}

enum LocationOccupancyState: String, Codable, CaseIterable, Identifiable {
    case available
    case occupied

    var id: Self { self }

    var title: String {
        switch self {
        case .available:
            return "Open"
        case .occupied:
            return "Occupied"
        }
    }

    var symbol: String {
        switch self {
        case .available:
            return "checkmark.circle.fill"
        case .occupied:
            return "shippingbox.fill"
        }
    }
}

struct ZoneStorageLocation: Codable, Identifiable, Hashable {
    let id: UUID
    var code: String
    var symbology: String
    var x: Float
    var y: Float
    var z: Float
    var occupancy: LocationOccupancyState
    var capturedAt: Date

    init(
        id: UUID = UUID(),
        code: String,
        symbology: String,
        x: Float,
        y: Float,
        z: Float,
        occupancy: LocationOccupancyState,
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.code = code
        self.symbology = symbology
        self.x = x
        self.y = y
        self.z = z
        self.occupancy = occupancy
        self.capturedAt = capturedAt
    }
}

struct ZoneBoundaryPoint: Codable, Hashable {
    let markerIndex: Int
    let x: Float
    let z: Float
}

struct ZoneBoundary: Codable, Hashable {
    let points: [ZoneBoundaryPoint]
    let capturedAt: Date

    var orderedPoints: [ZoneBoundaryPoint] {
        points.sorted { $0.markerIndex < $1.markerIndex }
    }

    var minX: Float { points.map(\.x).min() ?? 0 }
    var maxX: Float { points.map(\.x).max() ?? 0 }
    var minZ: Float { points.map(\.z).min() ?? 0 }
    var maxZ: Float { points.map(\.z).max() ?? 0 }
    var measuredWidth: Float { maxX - minX }
    var measuredDepth: Float { maxZ - minZ }

    func contains(
        x: Float,
        z: Float,
        tolerance: Float = 0.35
    ) -> Bool {
        let polygon = orderedPoints
        guard polygon.count >= 3 else {
            return x >= minX - tolerance
                && x <= maxX + tolerance
                && z >= minZ - tolerance
                && z <= maxZ + tolerance
        }

        var isInside = false
        var previous = polygon.count - 1

        for current in polygon.indices {
            let first = polygon[current]
            let second = polygon[previous]
            let crosses = (first.z > z) != (second.z > z)
            if crosses {
                let denominator = second.z - first.z
                let intersectX = (
                    (second.x - first.x)
                        * (z - first.z)
                        / (
                            abs(denominator) < 0.000_1
                                ? 0.000_1
                                : denominator
                        )
                ) + first.x
                if x < intersectX {
                    isInside.toggle()
                }
            }
            previous = current
        }

        if isInside {
            return true
        }

        for index in polygon.indices {
            let start = polygon[index]
            let end = polygon[(index + 1) % polygon.count]
            if distance(
                fromX: x,
                z: z,
                toSegmentFromX: start.x,
                z: start.z,
                endX: end.x,
                z: end.z
            ) <= tolerance {
                return true
            }
        }

        return false
    }

    func mapOffset(
        x: Float,
        z: Float,
        zoneWidth: Float,
        zoneDepth: Float
    ) -> SIMD2<Float>? {
        let polygon = orderedPoints
        guard polygon.count >= 4 else {
            return nil
        }

        let origin = SIMD2<Float>(polygon[0].x, polygon[0].z)
        let widthVector = SIMD2<Float>(
            polygon[1].x - polygon[0].x,
            polygon[1].z - polygon[0].z
        )
        let depthVector = SIMD2<Float>(
            polygon[3].x - polygon[0].x,
            polygon[3].z - polygon[0].z
        )
        let widthLengthSquared = simd_length_squared(widthVector)
        let depthLengthSquared = simd_length_squared(depthVector)
        guard widthLengthSquared > 0.000_1,
              depthLengthSquared > 0.000_1 else {
            return nil
        }

        let relative = SIMD2<Float>(x, z) - origin
        let widthProgress = simd_dot(relative, widthVector)
            / widthLengthSquared
        let depthProgress = simd_dot(relative, depthVector)
            / depthLengthSquared

        return SIMD2<Float>(
            (widthProgress - 0.5) * zoneWidth,
            (depthProgress - 0.5) * zoneDepth
        )
    }

    private func distance(
        fromX x: Float,
        z: Float,
        toSegmentFromX startX: Float,
        z startZ: Float,
        endX: Float,
        z endZ: Float
    ) -> Float {
        let point = SIMD2<Float>(x, z)
        let start = SIMD2<Float>(startX, startZ)
        let end = SIMD2<Float>(endX, endZ)
        let segment = end - start
        let lengthSquared = simd_length_squared(segment)
        guard lengthSquared > 0.000_1 else {
            return simd_distance(point, start)
        }
        let progress = min(
            1,
            max(0, simd_dot(point - start, segment) / lengthSquared)
        )
        return simd_distance(point, start + segment * progress)
    }
}

struct WarehouseFootprint: Codable, Hashable {
    var widthMeters: Float
    var depthMeters: Float
    var clearHeightMeters: Float
    var updatedAt: Date

    init(
        widthMeters: Float,
        depthMeters: Float,
        clearHeightMeters: Float,
        updatedAt: Date = Date()
    ) {
        self.widthMeters = max(1, widthMeters)
        self.depthMeters = max(1, depthMeters)
        self.clearHeightMeters = max(1, clearHeightMeters)
        self.updatedAt = updatedAt
    }

    var squareMeters: Double {
        Double(widthMeters * depthMeters)
    }

    var squareFeet: Double {
        squareMeters * 10.7639
    }
}

struct ZoneMarker: Codable, Identifiable, Hashable {
    let id: UUID
    let index: Int
    let identifier: String
    let relativeTransform: Matrix4x4
    let confirmedAt: Date

    init(
        id: UUID = UUID(),
        index: Int,
        identifier: String,
        relativeTransform: Matrix4x4,
        confirmedAt: Date = Date()
    ) {
        self.id = id
        self.index = index
        self.identifier = identifier
        self.relativeTransform = relativeTransform
        self.confirmedAt = confirmedAt
    }
}

struct ZoneScanRevision: Codable, Identifiable, Hashable {
    let id: UUID
    let revisionNumber: Int
    let scanArchiveID: UUID
    let capturedAt: Date

    init(
        id: UUID = UUID(),
        revisionNumber: Int,
        scanArchiveID: UUID,
        capturedAt: Date
    ) {
        self.id = id
        self.revisionNumber = revisionNumber
        self.scanArchiveID = scanArchiveID
        self.capturedAt = capturedAt
    }
}

struct WarehouseZone: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var kind: WarehouseZoneKind
    var centerX: Float
    var centerZ: Float
    var widthMeters: Float
    var depthMeters: Float
    var heightMeters: Float
    var rotationDegrees: Float
    var scanRevisions: [ZoneScanRevision]
    var activeRevisionID: UUID?
    var markers: [ZoneMarker]?
    var markerSetupCompletedAt: Date?
    var capacityProfile: ZoneCapacityProfile?
    var boundary: ZoneBoundary?
    var inventoryEntries: [ZoneInventoryEntry]?
    var storageLocations: [ZoneStorageLocation]?

    init(
        id: UUID = UUID(),
        name: String,
        kind: WarehouseZoneKind,
        centerX: Float,
        centerZ: Float,
        widthMeters: Float,
        depthMeters: Float,
        heightMeters: Float,
        rotationDegrees: Float = 0,
        scanRevisions: [ZoneScanRevision] = [],
        activeRevisionID: UUID? = nil,
        markers: [ZoneMarker]? = nil,
        markerSetupCompletedAt: Date? = nil,
        capacityProfile: ZoneCapacityProfile? = nil,
        boundary: ZoneBoundary? = nil,
        inventoryEntries: [ZoneInventoryEntry]? = nil,
        storageLocations: [ZoneStorageLocation]? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.centerX = centerX
        self.centerZ = centerZ
        self.widthMeters = widthMeters
        self.depthMeters = depthMeters
        self.heightMeters = heightMeters
        self.rotationDegrees = rotationDegrees
        self.scanRevisions = scanRevisions
        self.activeRevisionID = activeRevisionID
        self.markers = markers
        self.markerSetupCompletedAt = markerSetupCompletedAt
        self.capacityProfile = capacityProfile
        self.boundary = boundary
        self.inventoryEntries = inventoryEntries
        self.storageLocations = storageLocations
    }

    var activeRevision: ZoneScanRevision? {
        if let activeRevisionID,
           let selected = scanRevisions.first(where: { $0.id == activeRevisionID }) {
            return selected
        }
        return scanRevisions.max(by: {
            $0.revisionNumber < $1.revisionNumber
        })
    }

    var hasScan: Bool {
        activeRevision != nil
    }

    var hasMarkerSetup: Bool {
        guard let markers else {
            return false
        }
        let expectedCount = MarkerRecommendation.forZone(
            widthMeters: widthMeters,
            depthMeters: depthMeters
        ).markerCount
        let expectedIndices = Set(1...expectedCount)
        return Set(markers.map(\.index)) == expectedIndices
            && boundary?.orderedPoints.count == 4
    }

    var sizeDescription: String {
        String(
            format: "%.1f × %.1f m · %.0f × %.0f ft",
            widthMeters,
            depthMeters,
            widthMeters * 3.28084,
            depthMeters * 3.28084
        )
    }

    var footprintSquareMeters: Double {
        Double(max(0, widthMeters) * max(0, depthMeters))
    }

    var footprintSquareFeet: Double {
        footprintSquareMeters * 10.7639
    }

    var recordedInventory: [ZoneInventoryEntry] {
        inventoryEntries ?? []
    }

    var recordedInventoryQuantity: Int {
        recordedInventory.reduce(0) { $0 + $1.quantity }
    }

    var recordedPositionsUsed: Int {
        recordedInventory.reduce(0) { $0 + $1.positionsUsed }
    }

    var recordedStorageLocations: [ZoneStorageLocation] {
        storageLocations ?? []
    }

    var openStorageLocationCount: Int {
        recordedStorageLocations.filter {
            $0.occupancy == .available
        }.count
    }

    var occupiedStorageLocationCount: Int {
        recordedStorageLocations.filter {
            $0.occupancy == .occupied
        }.count
    }
}

struct WarehousePlan: Codable {
    let formatVersion: Int
    var name: String
    var zones: [WarehouseZone]
    var updatedAt: Date
    var preferredUnit: MeasurementUnitPreference?
    var footprint: WarehouseFootprint?

    init(
        formatVersion: Int = 1,
        name: String,
        zones: [WarehouseZone] = [],
        updatedAt: Date = Date(),
        preferredUnit: MeasurementUnitPreference? = .feet,
        footprint: WarehouseFootprint? = nil
    ) {
        self.formatVersion = formatVersion
        self.name = name
        self.zones = zones
        self.updatedAt = updatedAt
        self.preferredUnit = preferredUnit
        self.footprint = footprint
    }
}

struct MarkerRecommendation {
    let markerCount: Int
    let edgeCentimeters: Int
    let maximumSpacingMeters: Float
    let mountingHeightMeters: Float
    let shouldSplitZone: Bool

    static func forZone(
        widthMeters: Float,
        depthMeters: Float
    ) -> MarkerRecommendation {
        let width = max(2, widthMeters)
        let depth = max(2, depthMeters)
        let longestSightLine = max(width, depth)
        let maximumSpacing: Float = longestSightLine > 20 ? 8 : 7
        let perimeter = 2 * (width + depth)
        let count = max(4, Int(ceil(perimeter / maximumSpacing)))

        let edgeCentimeters = longestSightLine < 12 ? 15 : 18

        return MarkerRecommendation(
            markerCount: count,
            edgeCentimeters: edgeCentimeters,
            maximumSpacingMeters: maximumSpacing,
            mountingHeightMeters: 1.5,
            shouldSplitZone: count > 16 || longestSightLine > 35
        )
    }

    static func positions(for zone: WarehouseZone) -> [SIMD2<Float>] {
        let recommendation = forZone(
            widthMeters: zone.widthMeters,
            depthMeters: zone.depthMeters
        )
        let halfWidth = zone.widthMeters / 2
        let halfDepth = zone.depthMeters / 2
        let perimeter = 2 * (zone.widthMeters + zone.depthMeters)

        guard perimeter > 0 else {
            return []
        }

        return (0..<recommendation.markerCount).map { index in
            var distance = perimeter
                * Float(index)
                / Float(recommendation.markerCount)

            if distance <= zone.widthMeters {
                return SIMD2<Float>(-halfWidth + distance, -halfDepth)
            }

            distance -= zone.widthMeters
            if distance <= zone.depthMeters {
                return SIMD2<Float>(halfWidth, -halfDepth + distance)
            }

            distance -= zone.depthMeters
            if distance <= zone.widthMeters {
                return SIMD2<Float>(halfWidth - distance, halfDepth)
            }

            distance -= zone.widthMeters
            return SIMD2<Float>(-halfWidth, halfDepth - distance)
        }
    }
}

final class WarehouseMapStore: ObservableObject {
    @Published private(set) var plan: WarehousePlan
    @Published var errorMessage: String?

    private static let encoder: PropertyListEncoder = {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return encoder
    }()

    private static let decoder = PropertyListDecoder()

    init() {
        do {
            plan = try Self.load()
        } catch {
            plan = WarehousePlan(name: "My Warehouse")
        }
    }

    func zone(id: UUID) -> WarehouseZone? {
        plan.zones.first(where: { $0.id == id })
    }

    var measurementUnit: MeasurementUnitPreference {
        plan.preferredUnit ?? .feet
    }

    func setMeasurementUnit(_ unit: MeasurementUnitPreference) {
        mutatePlan { plan in
            plan.preferredUnit = unit
        }
    }

    func updateFootprint(_ footprint: WarehouseFootprint?) {
        mutatePlan { plan in
            plan.footprint = footprint
            guard let footprint else {
                return
            }

            for index in plan.zones.indices {
                let clamped = clampedCenter(
                    for: plan.zones[index],
                    requestedX: plan.zones[index].centerX,
                    requestedZ: plan.zones[index].centerZ,
                    inside: footprint
                )
                plan.zones[index].centerX = clamped.x
                plan.zones[index].centerZ = clamped.y
            }
        }
    }

    func zone(containingScan archiveID: UUID) -> WarehouseZone? {
        plan.zones.first(where: { zone in
            zone.scanRevisions.contains(where: {
                $0.scanArchiveID == archiveID
            })
        })
    }

    func renameWarehouse(_ name: String) {
        mutatePlan { plan in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            plan.name = trimmed.isEmpty ? "My Warehouse" : trimmed
        }
    }

    @discardableResult
    func addZone(
        name: String,
        kind: WarehouseZoneKind,
        widthMeters: Float,
        depthMeters: Float,
        heightMeters: Float,
        rotationDegrees: Float
    ) -> UUID {
        let id = UUID()
        let position = nextOpenPosition()

        mutatePlan { plan in
            plan.zones.append(
                WarehouseZone(
                    id: id,
                    name: normalizedZoneName(name, fallbackIndex: plan.zones.count + 1),
                    kind: kind,
                    centerX: position.x,
                    centerZ: position.y,
                    widthMeters: widthMeters,
                    depthMeters: depthMeters,
                    heightMeters: heightMeters,
                    rotationDegrees: rotationDegrees
                )
            )
        }

        return id
    }

    func updateZone(_ zone: WarehouseZone) {
        mutatePlan { plan in
            guard let index = plan.zones.firstIndex(where: { $0.id == zone.id }) else {
                return
            }

            var updated = zone
            updated.name = normalizedZoneName(
                zone.name,
                fallbackIndex: index + 1
            )
            updated.widthMeters = max(2, zone.widthMeters)
            updated.depthMeters = max(2, zone.depthMeters)
            updated.heightMeters = max(2, zone.heightMeters)
            if let footprint = plan.footprint {
                let clamped = clampedCenter(
                    for: updated,
                    requestedX: updated.centerX,
                    requestedZ: updated.centerZ,
                    inside: footprint
                )
                updated.centerX = clamped.x
                updated.centerZ = clamped.y
            }
            plan.zones[index] = updated
        }
    }

    func updateCapacity(
        zoneID: UUID,
        profile: ZoneCapacityProfile?
    ) {
        mutatePlan { plan in
            guard let index = plan.zones.firstIndex(where: {
                $0.id == zoneID
            }) else {
                return
            }
            plan.zones[index].capacityProfile = profile
        }
    }

    func replaceInventory(
        zoneID: UUID,
        entries: [ZoneInventoryEntry],
        synchronizeOccupiedPositions: Bool
    ) {
        mutatePlan { plan in
            guard let index = plan.zones.firstIndex(where: {
                $0.id == zoneID
            }) else {
                return
            }

            let cleaned = entries
                .filter {
                    !$0.category.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                }
                .map {
                    ZoneInventoryEntry(
                        id: $0.id,
                        category: $0.category.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ),
                        quantity: $0.quantity,
                        positionsUsed: $0.positionsUsed,
                        updatedAt: Date()
                    )
                }
            plan.zones[index].inventoryEntries = cleaned

            guard synchronizeOccupiedPositions,
                  var profile = plan.zones[index].capacityProfile else {
                return
            }

            profile.occupiedPositions = min(
                cleaned.reduce(0) { $0 + $1.positionsUsed },
                profile.usablePositions
            )
            profile.observedFill = fillState(
                occupied: profile.occupiedPositions,
                usable: profile.usablePositions
            )
            profile.verifiedAt = Date()
            plan.zones[index].capacityProfile = profile
        }
    }

    func upsertStorageLocation(
        zoneID: UUID,
        location: ZoneStorageLocation
    ) {
        mutatePlan { plan in
            guard let zoneIndex = plan.zones.firstIndex(where: {
                $0.id == zoneID
            }) else {
                return
            }

            var locations = plan.zones[zoneIndex].storageLocations ?? []
            let matchingIndex = locations.firstIndex { existing in
                existing.code.caseInsensitiveCompare(location.code)
                    == .orderedSame
                    && simd_distance(
                        SIMD3<Float>(existing.x, existing.y, existing.z),
                        SIMD3<Float>(location.x, location.y, location.z)
                    ) <= 0.9
            }

            if let matchingIndex {
                let existingID = locations[matchingIndex].id
                locations[matchingIndex] = ZoneStorageLocation(
                    id: existingID,
                    code: location.code,
                    symbology: location.symbology,
                    x: location.x,
                    y: location.y,
                    z: location.z,
                    occupancy: location.occupancy,
                    capturedAt: location.capturedAt
                )
            } else {
                locations.append(location)
            }

            plan.zones[zoneIndex].storageLocations = locations
            synchronizeCapacity(
                for: &plan.zones[zoneIndex],
                from: locations
            )
        }
    }

    func updateStorageLocation(
        zoneID: UUID,
        locationID: UUID,
        occupancy: LocationOccupancyState
    ) {
        mutatePlan { plan in
            guard let zoneIndex = plan.zones.firstIndex(where: {
                $0.id == zoneID
            }),
            var locations = plan.zones[zoneIndex].storageLocations,
            let locationIndex = locations.firstIndex(where: {
                $0.id == locationID
            }) else {
                return
            }

            locations[locationIndex].occupancy = occupancy
            locations[locationIndex].capturedAt = Date()
            plan.zones[zoneIndex].storageLocations = locations
            synchronizeCapacity(
                for: &plan.zones[zoneIndex],
                from: locations
            )
        }
    }

    func deleteStorageLocation(
        zoneID: UUID,
        locationID: UUID
    ) {
        mutatePlan { plan in
            guard let zoneIndex = plan.zones.firstIndex(where: {
                $0.id == zoneID
            }) else {
                return
            }
            var locations = plan.zones[zoneIndex].storageLocations ?? []
            locations.removeAll { $0.id == locationID }
            plan.zones[zoneIndex].storageLocations = locations
            synchronizeCapacity(
                for: &plan.zones[zoneIndex],
                from: locations
            )
        }
    }

    func refreshBoundaryFromDimensions(zoneID: UUID) {
        mutatePlan { plan in
            guard let index = plan.zones.firstIndex(where: {
                $0.id == zoneID
            }),
            let markers = plan.zones[index].markers,
            let boundary = dimensionBoundary(
                for: plan.zones[index],
                markers: markers
            ) else {
                return
            }
            plan.zones[index].boundary = boundary
        }
    }

    func moveZone(id: UUID, centerX: Float, centerZ: Float) {
        mutatePlan { plan in
            guard let index = plan.zones.firstIndex(where: { $0.id == id }) else {
                return
            }
            let snappedX = (centerX * 2).rounded() / 2
            let snappedZ = (centerZ * 2).rounded() / 2
            if let footprint = plan.footprint {
                let clamped = clampedCenter(
                    for: plan.zones[index],
                    requestedX: snappedX,
                    requestedZ: snappedZ,
                    inside: footprint
                )
                plan.zones[index].centerX = clamped.x
                plan.zones[index].centerZ = clamped.y
            } else {
                plan.zones[index].centerX = snappedX
                plan.zones[index].centerZ = snappedZ
            }
        }
    }

    func deleteZone(id: UUID) {
        mutatePlan { plan in
            plan.zones.removeAll(where: { $0.id == id })
        }
    }

    @discardableResult
    func recordScan(
        archiveID: UUID,
        capturedAt: Date,
        for zoneID: UUID
    ) -> ZoneScanRevision? {
        var createdRevision: ZoneScanRevision?

        mutatePlan { plan in
            guard let index = plan.zones.firstIndex(where: { $0.id == zoneID }) else {
                return
            }

            let nextNumber = (
                plan.zones[index].scanRevisions
                    .map(\.revisionNumber)
                    .max() ?? 0
            ) + 1
            let revision = ZoneScanRevision(
                revisionNumber: nextNumber,
                scanArchiveID: archiveID,
                capturedAt: capturedAt
            )

            plan.zones[index].scanRevisions.append(revision)
            plan.zones[index].activeRevisionID = revision.id
            createdRevision = revision
        }

        return createdRevision
    }

    func activateRevision(zoneID: UUID, revisionID: UUID) {
        mutatePlan { plan in
            guard let index = plan.zones.firstIndex(where: { $0.id == zoneID }),
                  plan.zones[index].scanRevisions.contains(where: {
                      $0.id == revisionID
                  }) else {
                return
            }
            plan.zones[index].activeRevisionID = revisionID
        }
    }

    @discardableResult
    func assignExistingScan(
        archiveID: UUID,
        capturedAt: Date,
        to zoneID: UUID
    ) -> ZoneScanRevision? {
        if let existingZone = zone(containingScan: archiveID),
           existingZone.id == zoneID,
           let existingRevision = existingZone.scanRevisions.first(where: {
               $0.scanArchiveID == archiveID
           }) {
            activateRevision(
                zoneID: zoneID,
                revisionID: existingRevision.id
            )
            return existingRevision
        }

        mutatePlan { plan in
            for index in plan.zones.indices {
                let removedActive = plan.zones[index].scanRevisions.contains {
                    $0.scanArchiveID == archiveID
                        && $0.id == plan.zones[index].activeRevisionID
                }
                plan.zones[index].scanRevisions.removeAll(where: {
                    $0.scanArchiveID == archiveID
                })
                if removedActive {
                    plan.zones[index].activeRevisionID = plan.zones[index]
                        .scanRevisions
                        .max(by: {
                            $0.revisionNumber < $1.revisionNumber
                        })?
                        .id
                }
            }
        }

        return recordScan(
            archiveID: archiveID,
            capturedAt: capturedAt,
            for: zoneID
        )
    }

    func saveMarkerSetup(
        zoneID: UUID,
        markers: [ZoneMarker]
    ) {
        mutatePlan { plan in
            guard let index = plan.zones.firstIndex(where: {
                $0.id == zoneID
            }),
            let boundary = dimensionBoundary(
                for: plan.zones[index],
                markers: markers
            ) else {
                return
            }
            plan.zones[index].markers = markers.sorted {
                $0.index < $1.index
            }
            plan.zones[index].markerSetupCompletedAt = Date()
            plan.zones[index].boundary = boundary
        }
    }

    func clearMarkerSetup(zoneID: UUID) {
        mutatePlan { plan in
            guard let index = plan.zones.firstIndex(where: {
                $0.id == zoneID
            }) else {
                return
            }
            plan.zones[index].markers = nil
            plan.zones[index].markerSetupCompletedAt = nil
            plan.zones[index].boundary = nil
        }
    }

    private func fillState(
        occupied: Int,
        usable: Int
    ) -> ZoneFillState {
        guard occupied > 0 else {
            return .empty
        }
        return occupied >= usable ? .full : .partial
    }

    private func synchronizeCapacity(
        for zone: inout WarehouseZone,
        from locations: [ZoneStorageLocation]
    ) {
        var profile = zone.capacityProfile ?? ZoneCapacityProfile(
            layout: zone.kind == .aisle ? .rackBays : .mixed
        )
        profile.totalPositions = locations.count
        profile.occupiedPositions = locations.filter {
            $0.occupancy == .occupied
        }.count
        profile.reservedPositions = 0
        profile.blockedPositions = 0
        profile.observedFill = fillState(
            occupied: profile.occupiedPositions,
            usable: profile.totalPositions
        )
        profile.verifiedAt = Date()
        zone.capacityProfile = profile
    }

    private func dimensionBoundary(
        for zone: WarehouseZone,
        markers: [ZoneMarker]
    ) -> ZoneBoundary? {
        let expectedPositions = MarkerRecommendation.positions(for: zone)
        guard expectedPositions.count >= 4 else {
            return nil
        }

        let expectedIndices = Set(1...expectedPositions.count)
        let markerByIndex = Dictionary(
            uniqueKeysWithValues: markers.map { ($0.index, $0) }
        )
        guard Set(markerByIndex.keys) == expectedIndices else {
            return nil
        }

        let expectedOrigin = expectedPositions[0]
        var dotSum: Float = 0
        var crossSum: Float = 0

        for markerIndex in expectedIndices {
            guard let marker = markerByIndex[markerIndex] else {
                continue
            }
            let expected = expectedPositions[markerIndex - 1]
                - expectedOrigin
            let observedPosition = marker.relativeTransform.position
            let observed = SIMD2<Float>(
                observedPosition.x,
                observedPosition.z
            )
            dotSum += expected.x * observed.x
                + expected.y * observed.y
            crossSum += expected.x * observed.y
                - expected.y * observed.x
        }

        let angle = abs(dotSum) + abs(crossSum) > 0.000_1
            ? atan2(crossSum, dotSum)
            : 0
        let cosine = cos(angle)
        let sine = sin(angle)

        func rotated(_ point: SIMD2<Float>) -> SIMD2<Float> {
            SIMD2<Float>(
                point.x * cosine - point.y * sine,
                point.x * sine + point.y * cosine
            )
        }

        let corners = [
            SIMD2<Float>(0, 0),
            SIMD2<Float>(zone.widthMeters, 0),
            SIMD2<Float>(zone.widthMeters, zone.depthMeters),
            SIMD2<Float>(0, zone.depthMeters)
        ].map(rotated)
        let points = corners.enumerated().map { index, point in
            ZoneBoundaryPoint(
                markerIndex: index + 1,
                x: point.x,
                z: point.y
            )
        }

        return ZoneBoundary(points: points, capturedAt: Date())
    }

    private func clampedCenter(
        for zone: WarehouseZone,
        requestedX: Float,
        requestedZ: Float,
        inside footprint: WarehouseFootprint
    ) -> SIMD2<Float> {
        let radians = abs(zone.rotationDegrees) * .pi / 180
        let cosine = abs(cos(radians))
        let sine = abs(sin(radians))
        let halfWidth = (
            zone.widthMeters * cosine
                + zone.depthMeters * sine
        ) / 2
        let halfDepth = (
            zone.widthMeters * sine
                + zone.depthMeters * cosine
        ) / 2
        let warehouseHalfWidth = footprint.widthMeters / 2
        let warehouseHalfDepth = footprint.depthMeters / 2

        let minimumX = -warehouseHalfWidth + min(
            halfWidth,
            warehouseHalfWidth
        )
        let maximumX = warehouseHalfWidth - min(
            halfWidth,
            warehouseHalfWidth
        )
        let minimumZ = -warehouseHalfDepth + min(
            halfDepth,
            warehouseHalfDepth
        )
        let maximumZ = warehouseHalfDepth - min(
            halfDepth,
            warehouseHalfDepth
        )

        return SIMD2<Float>(
            min(max(requestedX, minimumX), maximumX),
            min(max(requestedZ, minimumZ), maximumZ)
        )
    }

    private func mutatePlan(_ mutation: (inout WarehousePlan) -> Void) {
        mutation(&plan)
        plan.updatedAt = Date()

        do {
            try save()
        } catch {
            errorMessage = "The warehouse map could not be saved: \(error.localizedDescription)"
        }
    }

    private func nextOpenPosition() -> SIMD2<Float> {
        guard let last = plan.zones.last else {
            return .zero
        }

        let column = plan.zones.count % 3
        let row = plan.zones.count / 3
        return SIMD2<Float>(
            Float(column * 9),
            Float(row * 12) + last.depthMeters / 2
        )
    }

    private func normalizedZoneName(
        _ name: String,
        fallbackIndex: Int
    ) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Zone \(fallbackIndex)" : trimmed
    }

    private func save() throws {
        let url = try Self.planURL()
        let data = try Self.encoder.encode(plan)
        try data.write(to: url, options: .atomic)
    }

    private static func load() throws -> WarehousePlan {
        let url = try planURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return WarehousePlan(name: "My Warehouse")
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(WarehousePlan.self, from: data)
    }

    private static func planURL() throws -> URL {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        let directory = documents.appendingPathComponent(
            "WarehouseMapper",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent("WarehousePlan.plist")
    }
}
