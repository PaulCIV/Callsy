import ARKit
import Combine
import SceneKit
import SwiftUI
import UIKit

enum ScanPhase: Equatable {
    case ready
    case markerSetup
    case aligning
    case readyToScan
    case scanning
    case saving
    case saved

    var title: String {
        switch self {
        case .ready:
            return "Ready for a local scan"
        case .markerSetup:
            return "Confirming printable location markers"
        case .aligning:
            return "Finding this zone’s saved location"
        case .readyToScan:
            return "Location confirmed"
        case .scanning:
            return "Recording mesh and movement"
        case .saving:
            return "Creating local scan archive"
        case .saved:
            return "Scan saved on this iPhone"
        }
    }
}

struct PendingStorageLocation: Identifiable, Equatable {
    let id: UUID
    let code: String
    let symbology: String
    let x: Float
    let y: Float
    let z: Float
    let capturedAt: Date
}

final class ScanSessionController: NSObject, ObservableObject {
    @Published private(set) var phase: ScanPhase = .ready
    @Published private(set) var trackingStatus = "Not started"
    @Published private(set) var trackingColor: Color = .gray
    @Published private(set) var meshSectionCount = 0
    @Published private(set) var poseSampleCount = 0
    @Published private(set) var distanceMeters: Float = 0
    @Published private(set) var scanDurationSeconds: TimeInterval = 0
    @Published private(set) var guidanceText = "Start with a small, well-lit zone."
    @Published private(set) var guidanceColor: Color = .cyan
    @Published private(set) var scanTargetName: String?
    @Published private(set) var markerProgress = 0
    @Published private(set) var markerTotal = 0
    @Published private(set) var barcodeLocationCount = 0
    @Published private(set) var lastBarcodeValue: String?
    @Published private(set) var savedZoneID: UUID?
    @Published private(set) var pendingLocationCapture: PendingStorageLocation?
    @Published var errorMessage: String?

    private let warehouseStore: WarehouseMapStore
    private weak var sceneView: ARSCNView?
    private let stateLock = NSLock()
    private let trailRootNode = SCNNode()
    private let boundaryRootNode = SCNNode()

    private var isCollecting = false
    private var scanStartedAt: Date?
    private var firstFrameTimestamp: TimeInterval?
    private var lastSampleTimestamp: TimeInterval = 0
    private var lastSamplePosition: SIMD3<Float>?
    private var lastTrailPosition: SIMD3<Float>?
    private var poseSamples: [PoseSample] = []
    private var observedMeshAnchors: Set<UUID> = []
    private var accumulatedDistance: Float = 0
    private var lastMeshUpdateUptime: TimeInterval = 0
    private var scanTargetZoneID: UUID?
    private var markerReferences: Set<ARReferenceImage> = []
    private var detectedMarkerTransforms: [Int: simd_float4x4] = [:]
    private var alignmentMarkerIndices: Set<Int> = []
    private var markerWorkflow: MarkerWorkflow = .none
    private var barcodeObservations: [BarcodeObservation] = []
    private var ignoredBarcodePayloads: Set<String> = []
    private var pendingAction: PendingScannerAction?
    private var scanBoundary: ZoneBoundary?

    private enum MarkerWorkflow {
        case none
        case setup
        case alignment
    }

    private enum PendingScannerAction {
        case capture(UUID)
        case markers(UUID)
    }

    init(warehouseStore: WarehouseMapStore) {
        self.warehouseStore = warehouseStore
        super.init()
    }

    var phaseDescription: String {
        guard let scanTargetName else {
            return phase.title
        }

        switch phase {
        case .ready:
            return phase.title
        case .markerSetup:
            return "Setting up \(scanTargetName)"
        case .aligning:
            return "Aligning \(scanTargetName)"
        case .readyToScan:
            return "\(scanTargetName) is aligned"
        case .scanning:
            return "Scanning \(scanTargetName)"
        case .saving:
            return "Saving a new \(scanTargetName) revision"
        case .saved:
            return "\(scanTargetName) updated"
        }
    }

    var formattedDistance: String {
        if distanceMeters < 10 {
            return String(format: "%.1f m", distanceMeters)
        }
        return String(format: "%.0f m", distanceMeters)
    }

    var formattedDuration: String {
        let seconds = Int(scanDurationSeconds.rounded(.down))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    var shouldRenderMesh: Bool {
        phase == .scanning
    }

    var shouldDetectBarcodes: Bool {
        phase == .scanning && pendingLocationCapture == nil
    }

    func attach(to sceneView: ARSCNView) {
        self.sceneView = sceneView
        trailRootNode.name = "movement-trail"
        boundaryRootNode.name = "zone-boundary"

        if trailRootNode.parent == nil {
            sceneView.scene.rootNode.addChildNode(trailRootNode)
        }
        if boundaryRootNode.parent == nil {
            sceneView.scene.rootNode.addChildNode(boundaryRootNode)
        }

        guard let pendingAction else {
            return
        }
        self.pendingAction = nil
        DispatchQueue.main.async {
            switch pendingAction {
            case .capture(let zoneID):
                self.startScan(for: zoneID)
            case .markers(let zoneID):
                self.startMarkerSetup(for: zoneID)
            }
        }
    }

    func requestCapture(for zoneID: UUID) {
        if sceneView?.window != nil {
            startScan(for: zoneID)
        } else {
            pendingAction = .capture(zoneID)
            prepareTarget(zoneID: zoneID)
            phase = .ready
            trackingStatus = "Opening camera"
            trackingColor = .yellow
            guidanceText = "Preparing \(scanTargetName ?? "zone")…"
            guidanceColor = .cyan
        }
    }

    func requestMarkerSetup(for zoneID: UUID) {
        if sceneView?.window != nil {
            startMarkerSetup(for: zoneID)
        } else {
            pendingAction = .markers(zoneID)
            prepareTarget(zoneID: zoneID)
            phase = .ready
            trackingStatus = "Opening camera"
            trackingColor = .yellow
            guidanceText = "Preparing boundary markers…"
            guidanceColor = .yellow
        }
    }

    func startScan(for zoneID: UUID? = nil) {
        guard let sceneView else {
            errorMessage = "The AR view is not ready yet. Please try again."
            return
        }

        guard ARWorldTrackingConfiguration.isSupported else {
            errorMessage = "This device does not support ARKit world tracking."
            return
        }

        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(
            .meshWithClassification
        ) else {
            errorMessage = """
            This device can track movement, but it cannot create the LiDAR scene mesh required by this scanner test. Use an iPhone or iPad with a LiDAR scanner.
            """
            return
        }

        if let zoneID {
            warehouseStore.refreshBoundaryFromDimensions(zoneID: zoneID)
        }

        if let zoneID,
           let zone = warehouseStore.zone(id: zoneID) {
            if zone.hasMarkerSetup {
                startAlignment(for: zone, in: sceneView)
            } else {
                startMarkerSetup(for: zoneID)
            }
            return
        }

        prepareTarget(zoneID: zoneID)
        clearPreviousVisualization()
        resetCollectedData()
        markerWorkflow = .none
        markerReferences = []
        detectedMarkerTransforms = [:]
        alignmentMarkerIndices = []
        markerProgress = 0
        markerTotal = 0
        savedZoneID = nil
        pendingLocationCapture = nil
        boundaryRootNode.childNodes.forEach {
            $0.removeFromParentNode()
        }

        let configuration = captureConfiguration(
            detectionImages: []
        )

        stateLock.lock()
        isCollecting = true
        scanStartedAt = Date()
        stateLock.unlock()

        phase = .scanning
        trackingStatus = "Initializing"
        trackingColor = .yellow
        guidanceText = "Move slowly and keep the floor and nearby surfaces visible."
        guidanceColor = .cyan

        sceneView.session.run(
            configuration,
            options: [.resetTracking, .removeExistingAnchors]
        )
    }

    func startMarkerSetup(for zoneID: UUID) {
        guard let sceneView else {
            errorMessage = "The AR view is not ready yet. Please try again."
            return
        }

        guard let zone = warehouseStore.zone(id: zoneID) else {
            errorMessage = "That zone no longer exists."
            return
        }

        let references = MarkerKit.referenceImages(for: zone)
        let expectedMarkerCount = MarkerRecommendation.forZone(
            widthMeters: zone.widthMeters,
            depthMeters: zone.depthMeters
        ).markerCount
        guard references.count == expectedMarkerCount else {
            errorMessage = "The printable markers could not be prepared."
            return
        }

        prepareTarget(zoneID: zoneID)
        clearPreviousVisualization()
        resetCollectedData()
        markerWorkflow = .setup
        markerReferences = references
        detectedMarkerTransforms = [:]
        alignmentMarkerIndices = []
        markerProgress = 0
        markerTotal = expectedMarkerCount
        savedZoneID = nil
        pendingLocationCapture = nil
        boundaryRootNode.childNodes.forEach {
            $0.removeFromParentNode()
        }

        stateLock.lock()
        isCollecting = false
        stateLock.unlock()

        phase = .markerSetup
        trackingStatus = "Looking for marker"
        trackingColor = .yellow
        guidanceText = "Point the camera at the Entrance marker and hold still."
        guidanceColor = .yellow

        let configuration = alignmentConfiguration(
            detectionImages: references,
            initialWorldMap: nil
        )
        sceneView.session.run(
            configuration,
            options: [.resetTracking, .removeExistingAnchors]
        )
    }

    func beginPreparedZoneScan() {
        guard phase == .readyToScan,
              let sceneView else {
            return
        }

        clearPreviousVisualization()
        resetCollectedData()
        savedZoneID = nil
        pendingLocationCapture = nil
        if let zoneID = scanTargetZoneID {
            barcodeLocationCount = warehouseStore
                .zone(id: zoneID)?
                .recordedStorageLocations
                .count ?? 0
        }

        stateLock.lock()
        isCollecting = true
        scanStartedAt = Date()
        stateLock.unlock()

        phase = .scanning
        trackingStatus = "Initializing scan"
        trackingColor = .yellow
        guidanceText = "Location locked. Move slowly and keep completed surfaces in view."
        guidanceColor = .cyan

        let configuration = captureConfiguration(
            detectionImages: markerReferences
        )
        sceneView.session.run(configuration)
    }

    func cancelCurrentOperation() {
        stateLock.lock()
        isCollecting = false
        stateLock.unlock()
        sceneView?.session.pause()
        markerWorkflow = .none
        detectedMarkerTransforms = [:]
        alignmentMarkerIndices = []
        markerProgress = 0
        markerTotal = 0
        savedZoneID = nil
        pendingLocationCapture = nil
        boundaryRootNode.childNodes.forEach {
            $0.removeFromParentNode()
        }
        phase = .ready
        trackingStatus = "Cancelled"
        trackingColor = .gray
        guidanceText = "Choose a zone when you are ready."
        guidanceColor = .cyan
    }

    func noteImageAnchor(_ anchor: ARImageAnchor) {
        guard let name = anchor.referenceImage.name,
              let parsed = MarkerKit.parseIdentifier(name),
              parsed.zoneID == scanTargetZoneID else {
            return
        }

        DispatchQueue.main.async {
            switch self.markerWorkflow {
            case .setup:
                self.handleSetupMarker(
                    index: parsed.index,
                    transform: anchor.transform
                )

            case .alignment:
                self.handleAlignmentMarker(
                    index: parsed.index,
                    transform: anchor.transform
                )

            case .none:
                break
            }
        }
    }

    func confirmPendingLocation(
        occupancy: LocationOccupancyState
    ) {
        guard let pending = pendingLocationCapture,
              let zoneID = scanTargetZoneID,
              let observation = barcodeObservations.first(where: {
                  $0.id == pending.id
              }) else {
            pendingLocationCapture = nil
            return
        }

        warehouseStore.upsertStorageLocation(
            zoneID: zoneID,
            location: ZoneStorageLocation(
                id: pending.id,
                code: pending.code,
                symbology: pending.symbology,
                x: pending.x,
                y: pending.y,
                z: pending.z,
                occupancy: occupancy,
                capturedAt: pending.capturedAt
            )
        )
        pendingLocationCapture = nil
        barcodeLocationCount = warehouseStore
            .zone(id: zoneID)?
            .recordedStorageLocations
            .count ?? 0
        lastBarcodeValue = pending.code
        addOrUpdateBarcodePin(
            observation,
            occupancy: occupancy
        )
        guidanceText = "\(pending.code) saved as \(occupancy.title.lowercased()). Continue to the next location label."
        guidanceColor = occupancy == .occupied ? .orange : .green
    }

    func discardPendingLocation() {
        guard let pending = pendingLocationCapture else {
            return
        }
        ignoredBarcodePayloads.insert(pending.code)
        barcodeObservations.removeAll { $0.id == pending.id }
        removeBarcodePin(id: pending.id)
        pendingLocationCapture = nil
        guidanceText = "Ignored \(pending.code). Continue scanning aisle location labels."
        guidanceColor = .cyan
    }

    func stopAndSave() {
        guard let sceneView else {
            errorMessage = "The AR view is unavailable."
            return
        }

        stateLock.lock()
        guard isCollecting else {
            stateLock.unlock()
            return
        }
        isCollecting = false
        let startedAt = scanStartedAt ?? Date()
        let poses = poseSamples
        let distance = accumulatedDistance
        let barcodes = barcodeObservations
        let targetZoneID = scanTargetZoneID
        let targetZoneName = scanTargetName
        let boundary = scanBoundary
        stateLock.unlock()

        phase = .saving
        sceneView.session.getCurrentWorldMap { worldMap, _ in
            let worldMapData = worldMap.flatMap {
                try? NSKeyedArchiver.archivedData(
                    withRootObject: $0,
                    requiringSecureCoding: true
                )
            }
            let finalFrame = sceneView.session.currentFrame
            sceneView.session.pause()
            let anchors = finalFrame?.anchors
                .compactMap { $0 as? ARMeshAnchor } ?? []
            let meshSnapshots: [MeshSnapshot]
            if let boundary {
                meshSnapshots = anchors.compactMap {
                    MeshSnapshot(
                        anchor: $0,
                        clippingTo: boundary
                    )
                }
            } else {
                meshSnapshots = anchors.map(MeshSnapshot.init)
            }
            let savedBarcodes = boundary.map { boundary in
                barcodes.filter {
                    boundary.contains(
                        x: $0.worldPosition.x,
                        z: $0.worldPosition.z
                    )
                }
            } ?? barcodes
            let archive = ScanArchive(
                id: UUID(),
                startedAt: startedAt,
                endedAt: Date(),
                deviceName: UIDevice.current.name,
                systemVersion: UIDevice.current.systemVersion,
                distanceMeters: distance,
                poses: poses,
                meshes: meshSnapshots,
                zoneID: targetZoneID,
                worldMapData: worldMapData,
                barcodeObservations: savedBarcodes
            )

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    _ = try ScanStore.save(archive)

                    DispatchQueue.main.async {
                        let revision = targetZoneID.flatMap {
                            self.warehouseStore.recordScan(
                                archiveID: archive.id,
                                capturedAt: archive.startedAt,
                                for: $0
                            )
                        }

                        self.markerWorkflow = .none
                        self.savedZoneID = targetZoneID
                        self.phase = .saved
                        self.trackingStatus = "Saved locally"
                        self.trackingColor = .green
                        if let targetZoneName, let revision {
                            self.guidanceText = "\(targetZoneName) revision \(revision.revisionNumber) is now active. The previous version is still in history."
                        } else {
                            self.guidanceText = "Scan saved. Assign it to a zone from Saved Scans."
                        }
                        self.guidanceColor = .green
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.phase = .ready
                        self.errorMessage = "The scan could not be saved: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func consume(frame: ARFrame) {
        stateLock.lock()
        let collecting = isCollecting
        stateLock.unlock()

        guard collecting else {
            DispatchQueue.main.async {
                self.updateTrackingStatusOnly(frame.camera.trackingState)
            }
            return
        }

        stateLock.lock()

        if firstFrameTimestamp == nil {
            firstFrameTimestamp = frame.timestamp
        }

        guard frame.timestamp - lastSampleTimestamp >= 0.1 else {
            stateLock.unlock()
            return
        }

        lastSampleTimestamp = frame.timestamp

        let transform = frame.camera.transform
        let position = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )

        let elapsed = frame.timestamp - (firstFrameTimestamp ?? frame.timestamp)
        poseSamples.append(
            PoseSample(
                elapsedSeconds: elapsed,
                cameraTransform: Matrix4x4(transform)
            )
        )

        if let previousPosition = lastSamplePosition {
            let change = simd_distance(previousPosition, position)
            if change < 1 {
                accumulatedDistance += change
            }
        }

        lastSamplePosition = position

        let shouldDrawTrail: Bool
        if let previousTrailPosition = lastTrailPosition {
            shouldDrawTrail = simd_distance(previousTrailPosition, position) >= 0.12
        } else {
            shouldDrawTrail = true
        }

        if shouldDrawTrail {
            lastTrailPosition = position
        }

        let sampleCount = poseSamples.count
        let distance = accumulatedDistance
        let secondsSinceMeshUpdate = ProcessInfo.processInfo.systemUptime
            - lastMeshUpdateUptime
        let isInsideBoundary = scanBoundary?.contains(
            x: position.x,
            z: position.z
        ) ?? true
        stateLock.unlock()

        if shouldDrawTrail {
            DispatchQueue.main.async {
                self.addTrailPoint(at: position)
            }
        }

        DispatchQueue.main.async {
            self.poseSampleCount = sampleCount
            self.distanceMeters = distance
            self.scanDurationSeconds = elapsed
        }

        publishScanHealth(
            trackingState: frame.camera.trackingState,
            elapsed: elapsed,
            secondsSinceMeshUpdate: secondsSinceMeshUpdate,
            thermalState: ProcessInfo.processInfo.thermalState,
            isInsideBoundary: isInsideBoundary
        )
    }

    func noteMeshAnchor(_ identifier: UUID) {
        stateLock.lock()
        let collecting = isCollecting
        if collecting {
            observedMeshAnchors.insert(identifier)
            lastMeshUpdateUptime = ProcessInfo.processInfo.systemUptime
        }
        let count = observedMeshAnchors.count
        stateLock.unlock()

        guard collecting else {
            return
        }

        DispatchQueue.main.async {
            self.meshSectionCount = count
        }
    }

    func noteBarcode(
        payload: String,
        symbology: String,
        worldPosition: SIMD3<Float>,
        cameraTransform: simd_float4x4,
        positionSource: BarcodePositionSource
    ) {
        let cleanPayload = payload.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !cleanPayload.isEmpty else {
            return
        }
        guard !ignoredBarcodePayloads.contains(cleanPayload),
              pendingLocationCapture == nil else {
            return
        }
        if let scanBoundary,
           !scanBoundary.contains(
                x: worldPosition.x,
                z: worldPosition.z
           ) {
            return
        }

        stateLock.lock()
        guard isCollecting else {
            stateLock.unlock()
            return
        }

        let candidateCameraPosition = cameraTransform.position
        let candidateCameraForward = cameraTransform.forward
        let matchingIndex = barcodeObservations.indices
            .filter {
                barcodeObservations[$0].payload == cleanPayload
            }
            .min { firstIndex, secondIndex in
                barcodeMatchScore(
                    barcodeObservations[firstIndex],
                    candidatePosition: worldPosition,
                    candidateCameraPosition: candidateCameraPosition,
                    candidateCameraForward: candidateCameraForward
                ) < barcodeMatchScore(
                    barcodeObservations[secondIndex],
                    candidatePosition: worldPosition,
                    candidateCameraPosition: candidateCameraPosition,
                    candidateCameraForward: candidateCameraForward
                )
            }
            .flatMap { index in
                barcodeMatchScore(
                    barcodeObservations[index],
                    candidatePosition: worldPosition,
                    candidateCameraPosition: candidateCameraPosition,
                    candidateCameraForward: candidateCameraForward
                ).isFinite ? index : nil
            }

        let observation: BarcodeObservation
        let isNewObservation: Bool
        if let matchingIndex {
            let current = barcodeObservations[matchingIndex]
            let resolved = resolvedBarcodePosition(
                current,
                candidatePosition: worldPosition,
                candidateCameraTransform: cameraTransform,
                candidateSource: positionSource
            )
            observation = current.confirming(
                worldPosition: resolved.position,
                cameraTransform: resolved.cameraTransform,
                positionSource: resolved.source
            )
            barcodeObservations[matchingIndex] = observation
            isNewObservation = false
        } else {
            observation = BarcodeObservation(
                payload: cleanPayload,
                symbology: symbology,
                worldPosition: worldPosition,
                cameraTransform: cameraTransform,
                positionSource: positionSource
            )
            barcodeObservations.append(observation)
            isNewObservation = true
        }
        stateLock.unlock()

        DispatchQueue.main.async {
            self.lastBarcodeValue = cleanPayload
            self.addOrUpdateBarcodePin(
                observation,
                occupancy: nil
            )

            guard isNewObservation else {
                return
            }

            self.pendingLocationCapture = PendingStorageLocation(
                id: observation.id,
                code: observation.payload,
                symbology: observation.symbology,
                x: observation.worldPosition.x,
                y: observation.worldPosition.y,
                z: observation.worldPosition.z,
                capturedAt: observation.capturedAt
            )
            self.guidanceText = "Location label found. Mark whether this position is open or occupied."
            self.guidanceColor = .yellow
        }
    }

    private func barcodeMatchScore(
        _ observation: BarcodeObservation,
        candidatePosition: SIMD3<Float>,
        candidateCameraPosition: SIMD3<Float>,
        candidateCameraForward: SIMD3<Float>
    ) -> Float {
        let positionDistance = simd_distance(
            observation.worldPosition.simdValue,
            candidatePosition
        )
        if positionDistance <= 0.75 {
            return positionDistance
        }

        let previousTransform = observation.cameraTransform.simdValue
        let cameraDistance = simd_distance(
            previousTransform.position,
            candidateCameraPosition
        )
        let facingSimilarity = simd_dot(
            previousTransform.forward,
            candidateCameraForward
        )

        guard cameraDistance <= 1.25, facingSimilarity >= 0.72 else {
            return .infinity
        }

        // A wildly different raycast from nearly the same viewpoint is almost
        // always the surface behind the label, not a second physical barcode.
        return 0.75 + cameraDistance + ((1 - facingSimilarity) * 0.25)
    }

    private func resolvedBarcodePosition(
        _ current: BarcodeObservation,
        candidatePosition: SIMD3<Float>,
        candidateCameraTransform: simd_float4x4,
        candidateSource: BarcodePositionSource
    ) -> (
        position: SIMD3<Float>,
        cameraTransform: simd_float4x4,
        source: BarcodePositionSource
    ) {
        let currentPosition = current.worldPosition.simdValue
        let positionDistance = simd_distance(
            currentPosition,
            candidatePosition
        )

        if positionDistance <= 0.55 {
            if current.positionSource == .surfaceRaycast,
               candidateSource == .cameraEstimate {
                return (
                    currentPosition,
                    current.cameraTransform.simdValue,
                    current.positionSource
                )
            }

            if current.positionSource == .cameraEstimate,
               candidateSource == .surfaceRaycast {
                return (
                    candidatePosition,
                    candidateCameraTransform,
                    candidateSource
                )
            }

            let sampleCount = min(Float(current.seenCount), 5)
            let smoothedPosition = (
                currentPosition * sampleCount + candidatePosition
            ) / (sampleCount + 1)
            return (
                smoothedPosition,
                candidateCameraTransform,
                candidateSource
            )
        }

        let currentCameraPosition =
            current.cameraTransform.simdValue.position
        let currentDistance = simd_distance(
            currentCameraPosition,
            currentPosition
        )
        let candidateDistance = simd_distance(
            candidateCameraTransform.position,
            candidatePosition
        )

        if candidateDistance + 0.2 < currentDistance {
            return (
                candidatePosition,
                candidateCameraTransform,
                candidateSource
            )
        }

        return (
            currentPosition,
            current.cameraTransform.simdValue,
            current.positionSource
        )
    }

    func reportSessionError(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.trackingStatus = "Session error"
            self.trackingColor = .red
        }
    }

    private func publishScanHealth(
        trackingState: ARCamera.TrackingState,
        elapsed: TimeInterval,
        secondsSinceMeshUpdate: TimeInterval,
        thermalState: ProcessInfo.ThermalState,
        isInsideBoundary: Bool
    ) {
        var trackingResult: (String, Color)
        let guidanceResult: (String, Color)

        switch trackingState {
        case .normal:
            trackingResult = ("Tracking good", .green)

            if thermalState == .critical {
                guidanceResult = (
                    "The phone is too hot. Stop and save this zone now.",
                    .red
                )
            } else if !isInsideBoundary {
                trackingResult = ("Outside boundary", .orange)
                guidanceResult = (
                    "Step back inside the cyan marker boundary. Outside mesh will not be saved.",
                    .orange
                )
            } else if thermalState == .serious {
                guidanceResult = (
                    "The phone is getting hot. Finish this section and let it cool.",
                    .orange
                )
            } else if elapsed >= 180 {
                guidanceResult = (
                    "This zone is three minutes long. Stop and save before continuing.",
                    .orange
                )
            } else if secondsSinceMeshUpdate > 4 {
                guidanceResult = (
                    "Aim at an unscanned surface while keeping some completed mesh in view.",
                    .yellow
                )
            } else {
                guidanceResult = (
                    "Good scan. Keep moving slowly with overlapping views.",
                    .green
                )
            }

        case .notAvailable:
            trackingResult = ("Unavailable", .red)
            guidanceResult = (
                "Tracking is unavailable. Stop and restart this zone.",
                .red
            )

        case .limited(let reason):
            switch reason {
            case .initializing:
                trackingResult = ("Initializing", .yellow)
                guidanceResult = (
                    "Move the phone gently from side to side to establish the room.",
                    .yellow
                )
            case .excessiveMotion:
                trackingResult = ("Move slower", .orange)
                guidanceResult = (
                    "Slow down and avoid quickly rotating the phone.",
                    .orange
                )
            case .insufficientFeatures:
                trackingResult = ("Needs visual detail", .orange)
                guidanceResult = (
                    "Point toward corners, labels, rack edges, or other textured surfaces.",
                    .orange
                )
            case .relocalizing:
                trackingResult = ("Relocalizing", .yellow)
                guidanceResult = (
                    "Return to a recently scanned area and move slowly.",
                    .yellow
                )
            @unknown default:
                trackingResult = ("Tracking limited", .orange)
                guidanceResult = (
                    "Pause briefly, then continue with slow overlapping movement.",
                    .orange
                )
            }
        }

        DispatchQueue.main.async {
            self.trackingStatus = trackingResult.0
            self.trackingColor = trackingResult.1
            self.guidanceText = guidanceResult.0
            self.guidanceColor = guidanceResult.1
        }
    }

    private func prepareTarget(zoneID: UUID?) {
        scanTargetZoneID = zoneID
        scanTargetName = zoneID.flatMap {
            warehouseStore.zone(id: $0)?.name
        }
        scanBoundary = zoneID.flatMap {
            warehouseStore.zone(id: $0)?.boundary
        }
    }

    private func startAlignment(
        for zone: WarehouseZone,
        in sceneView: ARSCNView
    ) {
        prepareTarget(zoneID: zone.id)
        clearPreviousVisualization()
        boundaryRootNode.childNodes.forEach {
            $0.removeFromParentNode()
        }
        resetCollectedData()
        markerWorkflow = .alignment
        markerReferences = MarkerKit.referenceImages(for: zone)
        detectedMarkerTransforms = [:]
        alignmentMarkerIndices = []
        markerProgress = 0
        markerTotal = zone.markers?.count ?? markerReferences.count

        stateLock.lock()
        isCollecting = false
        stateLock.unlock()

        phase = .aligning
        trackingStatus = "Checking boundary"
        trackingColor = .yellow
        guidanceText = "Scan the Entrance marker, then confirm every numbered boundary marker."
        guidanceColor = .yellow

        let configuration = alignmentConfiguration(
            detectionImages: markerReferences,
            initialWorldMap: savedWorldMap(for: zone)
        )
        sceneView.session.run(
            configuration,
            options: [.resetTracking, .removeExistingAnchors]
        )
    }

    private func handleSetupMarker(
        index: Int,
        transform: simd_float4x4
    ) {
        guard phase == .markerSetup,
              index >= 1,
              index <= markerTotal else {
            return
        }
        guard detectedMarkerTransforms[index] == nil else {
            return
        }

        let expectedIndex = (1...markerTotal).first(where: {
            detectedMarkerTransforms[$0] == nil
        }) ?? markerTotal
        guard index == expectedIndex else {
            guidanceText = "Boundary order matters. Find Marker \(expectedIndex) before Marker \(index)."
            guidanceColor = .orange
            return
        }

        detectedMarkerTransforms[index] = transform
        markerProgress = detectedMarkerTransforms.count
        trackingStatus = "Marker \(index) found"
        trackingColor = .green

        if markerProgress >= markerTotal {
            completeMarkerSetup()
            return
        }

        let next = (1...markerTotal).first(where: {
            detectedMarkerTransforms[$0] == nil
        }) ?? markerTotal
        guidanceText = next == 1
            ? "Entrance marker not confirmed yet. Point the camera at Marker 1."
            : "Marker \(index) confirmed. Now find Marker \(next) and hold still."
        guidanceColor = .yellow
    }

    private func completeMarkerSetup() {
        guard let zoneID = scanTargetZoneID,
              let origin = detectedMarkerTransforms[1] else {
            errorMessage = "The Entrance marker must be confirmed before setup can finish."
            return
        }
        let requiredIndices = Set(1...markerTotal)
        guard Set(detectedMarkerTransforms.keys) == requiredIndices else {
            let missing = requiredIndices
                .subtracting(detectedMarkerTransforms.keys)
                .sorted()
                .map(String.init)
                .joined(separator: ", ")
            errorMessage = "The boundary is incomplete. Scan Marker \(missing) before continuing."
            return
        }

        let originInverse = simd_inverse(origin)
        let now = Date()
        let markers = detectedMarkerTransforms.map { index, transform in
            ZoneMarker(
                index: index,
                identifier: MarkerKit.identifier(
                    zoneID: zoneID,
                    index: index
                ),
                relativeTransform: Matrix4x4(originInverse * transform),
                confirmedAt: now
            )
        }

        warehouseStore.saveMarkerSetup(
            zoneID: zoneID,
            markers: markers
        )
        guard let boundary = warehouseStore.zone(id: zoneID)?.boundary,
              boundary.orderedPoints.count == 4 else {
            errorMessage = "The full marker perimeter could not be verified. Rescan every numbered marker."
            return
        }
        sceneView?.session.setWorldOrigin(relativeTransform: origin)
        scanBoundary = boundary
        renderBoundary(boundary)
        markerWorkflow = .none
        phase = .readyToScan
        trackingStatus = "All markers confirmed"
        trackingColor = .green
        guidanceText = "All \(markerTotal) markers confirmed. The cyan outline uses the entered \(scanTargetName ?? "zone") dimensions. Stay inside it, then tap Scan Zone."
        guidanceColor = .green
    }

    private func handleAlignmentMarker(
        index: Int,
        transform: simd_float4x4
    ) {
        guard phase == .aligning else {
            return
        }

        detectedMarkerTransforms[index] = transform
        alignmentMarkerIndices.insert(index)
        markerProgress = alignmentMarkerIndices.count
        trackingStatus = "Marker \(index) confirmed"
        trackingColor = .green

        let requiredIndices = Set(1...markerTotal)
        let missingIndices = requiredIndices
            .subtracting(alignmentMarkerIndices)
            .sorted()
        guard missingIndices.isEmpty else {
            guidanceText = "Boundary check \(markerProgress)/\(markerTotal). Find Marker \(missingIndices[0])."
            guidanceColor = .yellow
            return
        }

        guard let origin = detectedMarkerTransforms[1],
              let zoneID = scanTargetZoneID,
              let zone = warehouseStore.zone(id: zoneID) else {
            return
        }

        let secondaryIndices = requiredIndices
            .filter { $0 != 1 }
            .sorted()

        let originInverse = simd_inverse(origin)
        let changedIndices = secondaryIndices.filter { secondaryIndex in
            guard let observed = detectedMarkerTransforms[secondaryIndex],
                  let expected = zone.markers?.first(where: {
                      $0.index == secondaryIndex
                  }) else {
                return true
            }

            let observedPosition = (originInverse * observed).columns.3
            let expectedPosition = expected.relativeTransform.simdValue.columns.3
            let delta = SIMD3<Float>(
                observedPosition.x - expectedPosition.x,
                observedPosition.y - expectedPosition.y,
                observedPosition.z - expectedPosition.z
            )
            return simd_length(delta) > 1.5
        }

        guard changedIndices.isEmpty else {
            trackingStatus = "Marker position changed"
            trackingColor = .red
            guidanceText = "Marker \(changedIndices[0]) moved from its saved position. Rescan the boundary if the layout changed."
            guidanceColor = .red
            return
        }

        sceneView?.session.setWorldOrigin(relativeTransform: origin)
        if let boundary = zone.boundary {
            renderBoundary(boundary)
        }
        markerProgress = markerTotal
        markerWorkflow = .none
        phase = .readyToScan
        trackingStatus = "Full boundary confirmed"
        trackingColor = .green
        guidanceText = "All \(markerTotal) markers agree. The full entered-size boundary is active; tap Scan Zone."
        guidanceColor = .green
    }

    private func updateTrackingStatusOnly(
        _ trackingState: ARCamera.TrackingState
    ) {
        switch trackingState {
        case .normal:
            if phase == .markerSetup || phase == .aligning {
                trackingStatus = "Camera tracking ready"
                trackingColor = .green
            }
        case .notAvailable:
            trackingStatus = "Tracking unavailable"
            trackingColor = .red
        case .limited(let reason):
            switch reason {
            case .initializing:
                trackingStatus = "Initializing"
                trackingColor = .yellow
            case .excessiveMotion:
                trackingStatus = "Move slower"
                trackingColor = .orange
            case .insufficientFeatures:
                trackingStatus = "Needs more detail"
                trackingColor = .orange
            case .relocalizing:
                trackingStatus = "Relocalizing"
                trackingColor = .yellow
            @unknown default:
                trackingStatus = "Tracking limited"
                trackingColor = .orange
            }
        }
    }

    private func alignmentConfiguration(
        detectionImages: Set<ARReferenceImage>,
        initialWorldMap: ARWorldMap?
    ) -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.detectionImages = detectionImages
        configuration.maximumNumberOfTrackedImages = min(
            4,
            detectionImages.count
        )
        configuration.initialWorldMap = initialWorldMap

        if let videoFormat = preferredThirtyFPSFormat() {
            configuration.videoFormat = videoFormat
        }
        return configuration
    }

    private func captureConfiguration(
        detectionImages: Set<ARReferenceImage>
    ) -> ARWorldTrackingConfiguration {
        let configuration = alignmentConfiguration(
            detectionImages: detectionImages,
            initialWorldMap: nil
        )
        configuration.sceneReconstruction = .meshWithClassification
        return configuration
    }

    private func savedWorldMap(for zone: WarehouseZone) -> ARWorldMap? {
        guard let archiveID = zone.activeRevision?.scanArchiveID,
              let archive = try? ScanStore.load(id: archiveID),
              let data = archive.worldMapData else {
            return nil
        }

        return try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: ARWorldMap.self,
            from: data
        )
    }

    private func resetCollectedData() {
        stateLock.lock()
        firstFrameTimestamp = nil
        lastSampleTimestamp = 0
        lastSamplePosition = nil
        lastTrailPosition = nil
        poseSamples = []
        observedMeshAnchors = []
        accumulatedDistance = 0
        barcodeObservations = []
        ignoredBarcodePayloads = []
        lastMeshUpdateUptime = ProcessInfo.processInfo.systemUptime
        stateLock.unlock()

        meshSectionCount = 0
        poseSampleCount = 0
        distanceMeters = 0
        scanDurationSeconds = 0
        barcodeLocationCount = 0
        lastBarcodeValue = nil
        pendingLocationCapture = nil
    }

    private func clearPreviousVisualization() {
        trailRootNode.childNodes.forEach { $0.removeFromParentNode() }

        sceneView?.scene.rootNode.enumerateChildNodes { node, _ in
            if node.name?.hasPrefix("warehouse-mesh-") == true {
                node.removeFromParentNode()
            }
            if node.name?.hasPrefix("barcode-pin-") == true {
                node.removeFromParentNode()
            }
        }
    }

    private func renderBoundary(_ boundary: ZoneBoundary) {
        boundaryRootNode.childNodes.forEach {
            $0.removeFromParentNode()
        }

        let points = boundary.orderedPoints
        guard points.count >= 3 else {
            return
        }

        let vertices = points.map {
            SCNVector3($0.x, 0, $0.z)
        }
        var lineIndices: [UInt32] = []
        for index in vertices.indices {
            lineIndices.append(UInt32(index))
            lineIndices.append(UInt32((index + 1) % vertices.count))
        }

        let source = SCNGeometrySource(vertices: vertices)
        let data = lineIndices.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let element = SCNGeometryElement(
            data: data,
            primitiveType: .line,
            primitiveCount: lineIndices.count / 2,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )
        let geometry = SCNGeometry(
            sources: [source],
            elements: [element]
        )
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemCyan
        material.emission.contents = UIColor.systemCyan
            .withAlphaComponent(0.72)
        material.isDoubleSided = true
        geometry.materials = [material]
        boundaryRootNode.addChildNode(SCNNode(geometry: geometry))

        for (index, point) in points.enumerated() {
            let marker = SCNSphere(radius: index == 0 ? 0.09 : 0.06)
            marker.segmentCount = 12
            let markerMaterial = SCNMaterial()
            markerMaterial.diffuse.contents = index == 0
                ? UIColor.systemGreen
                : UIColor.systemCyan
            markerMaterial.emission.contents = (
                index == 0
                    ? UIColor.systemGreen
                    : UIColor.systemCyan
            ).withAlphaComponent(0.65)
            marker.materials = [markerMaterial]

            let node = SCNNode(geometry: marker)
            node.position = SCNVector3(point.x, 0, point.z)
            boundaryRootNode.addChildNode(node)
        }
    }

    private func addTrailPoint(at position: SIMD3<Float>) {
        let sphere = SCNSphere(radius: 0.022)
        sphere.segmentCount = 10

        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemOrange
        material.emission.contents = UIColor.systemOrange.withAlphaComponent(0.35)
        sphere.materials = [material]

        let node = SCNNode(geometry: sphere)
        node.simdPosition = position
        trailRootNode.addChildNode(node)
    }

    private func addOrUpdateBarcodePin(
        _ observation: BarcodeObservation,
        occupancy: LocationOccupancyState?
    ) {
        guard let rootNode = sceneView?.scene.rootNode else {
            return
        }

        let nodeName = "barcode-pin-\(observation.id.uuidString)"
        if let existing = rootNode.childNode(
            withName: nodeName,
            recursively: true
        ) {
            existing.simdPosition = observation.worldPosition.simdValue
            updateBarcodePinColor(
                existing,
                occupancy: occupancy
            )
            return
        }

        let root = SCNNode()
        root.name = nodeName
        root.simdPosition = observation.worldPosition.simdValue

        let marker = SCNTorus(ringRadius: 0.075, pipeRadius: 0.014)
        marker.ringSegmentCount = 18
        marker.pipeSegmentCount = 8
        let markerMaterial = SCNMaterial()
        let color = pinColor(for: occupancy)
        markerMaterial.diffuse.contents = color
        markerMaterial.emission.contents = color.withAlphaComponent(0.55)
        marker.materials = [markerMaterial]
        root.addChildNode(SCNNode(geometry: marker))

        let text = SCNText(
            string: String(observation.payload.prefix(18)),
            extrusionDepth: 0.002
        )
        text.font = UIFont.monospacedSystemFont(
            ofSize: 0.11,
            weight: .semibold
        )
        text.flatness = 0.2
        let textMaterial = SCNMaterial()
        textMaterial.diffuse.contents = UIColor.white
        textMaterial.emission.contents = UIColor.white.withAlphaComponent(0.35)
        text.materials = [textMaterial]

        let textNode = SCNNode(geometry: text)
        textNode.position = SCNVector3(-0.09, 0.11, 0)
        textNode.constraints = [SCNBillboardConstraint()]
        root.addChildNode(textNode)
        rootNode.addChildNode(root)
    }

    private func updateBarcodePinColor(
        _ node: SCNNode,
        occupancy: LocationOccupancyState?
    ) {
        let color = pinColor(for: occupancy)
        node.enumerateChildNodes { child, _ in
            guard child.geometry is SCNTorus else {
                return
            }
            child.geometry?.firstMaterial?.diffuse.contents = color
            child.geometry?.firstMaterial?.emission.contents = color
                .withAlphaComponent(0.55)
        }
    }

    private func pinColor(
        for occupancy: LocationOccupancyState?
    ) -> UIColor {
        switch occupancy {
        case .available:
            return .systemGreen
        case .occupied:
            return .systemOrange
        case nil:
            return .systemYellow
        }
    }

    private func removeBarcodePin(id: UUID) {
        sceneView?.scene.rootNode.childNode(
            withName: "barcode-pin-\(id.uuidString)",
            recursively: true
        )?.removeFromParentNode()
    }

    private func preferredThirtyFPSFormat() -> ARConfiguration.VideoFormat? {
        let targetArea = CGFloat(1_920 * 1_080)

        return ARWorldTrackingConfiguration.supportedVideoFormats
            .filter { $0.framesPerSecond == 30 }
            .min {
                abs(
                    $0.imageResolution.width * $0.imageResolution.height
                    - targetArea
                ) < abs(
                    $1.imageResolution.width * $1.imageResolution.height
                    - targetArea
                )
            }
    }
}
