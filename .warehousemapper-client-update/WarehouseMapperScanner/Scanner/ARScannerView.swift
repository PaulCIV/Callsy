import ARKit
import ImageIO
import SceneKit
import SwiftUI
import UIKit
import Vision

struct ARScannerView: UIViewRepresentable {
    let controller: ScanSessionController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView(frame: .zero)
        sceneView.scene = SCNScene()
        sceneView.delegate = context.coordinator
        sceneView.session.delegate = context.coordinator
        sceneView.automaticallyUpdatesLighting = true
        sceneView.rendersCameraGrain = false
        sceneView.preferredFramesPerSecond = 30
        sceneView.antialiasingMode = .multisampling4X

        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = sceneView.session
        coachingOverlay.goal = .tracking
        coachingOverlay.activatesAutomatically = true
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        sceneView.addSubview(coachingOverlay)

        NSLayoutConstraint.activate([
            coachingOverlay.leadingAnchor.constraint(equalTo: sceneView.leadingAnchor),
            coachingOverlay.trailingAnchor.constraint(equalTo: sceneView.trailingAnchor),
            coachingOverlay.topAnchor.constraint(equalTo: sceneView.topAnchor),
            coachingOverlay.bottomAnchor.constraint(equalTo: sceneView.bottomAnchor)
        ])

        controller.attach(to: sceneView)
        context.coordinator.sceneView = sceneView
        return sceneView
    }

    func updateUIView(_ sceneView: ARSCNView, context: Context) {
        // ARKit owns the live view. State changes are applied by the controller.
    }

    static func dismantleUIView(_ sceneView: ARSCNView, coordinator: Coordinator) {
        sceneView.session.pause()
        sceneView.delegate = nil
        sceneView.session.delegate = nil
        coordinator.sceneView = nil
    }

    final class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        private let controller: ScanSessionController
        private var lastMeshRenderTime: [UUID: TimeInterval] = [:]
        private let visionQueue = DispatchQueue(
            label: "com.warehousemapper.barcode-vision",
            qos: .userInitiated
        )
        private let detectionLock = NSLock()
        private var isDetectingBarcode = false
        private var lastBarcodeDetectionTimestamp: TimeInterval = 0
        weak var sceneView: ARSCNView?

        private struct BarcodeCandidate {
            let payload: String
            let symbology: String
            let normalizedCenter: CGPoint
            let normalizedExtent: CGFloat
        }

        init(controller: ScanSessionController) {
            self.controller = controller
        }

        func renderer(
            _ renderer: SCNSceneRenderer,
            didAdd node: SCNNode,
            for anchor: ARAnchor
        ) {
            if let imageAnchor = anchor as? ARImageAnchor {
                controller.noteImageAnchor(imageAnchor)
                return
            }

            guard let meshAnchor = anchor as? ARMeshAnchor else {
                return
            }

            guard controller.shouldRenderMesh else {
                return
            }

            lastMeshRenderTime[meshAnchor.identifier] = ProcessInfo
                .processInfo.systemUptime
            node.name = "warehouse-mesh-\(meshAnchor.identifier.uuidString)"
            node.geometry = SCNGeometry.liveMesh(from: meshAnchor.geometry)
            controller.noteMeshAnchor(meshAnchor.identifier)
        }

        func renderer(
            _ renderer: SCNSceneRenderer,
            didUpdate node: SCNNode,
            for anchor: ARAnchor
        ) {
            if let imageAnchor = anchor as? ARImageAnchor {
                controller.noteImageAnchor(imageAnchor)
                return
            }

            guard let meshAnchor = anchor as? ARMeshAnchor else {
                return
            }

            guard controller.shouldRenderMesh else {
                return
            }

            controller.noteMeshAnchor(meshAnchor.identifier)

            let now = ProcessInfo.processInfo.systemUptime
            let previous = lastMeshRenderTime[meshAnchor.identifier] ?? 0
            guard now - previous >= 0.2 else {
                return
            }
            lastMeshRenderTime[meshAnchor.identifier] = now

            node.name = "warehouse-mesh-\(meshAnchor.identifier.uuidString)"
            node.geometry = SCNGeometry.liveMesh(from: meshAnchor.geometry)
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            controller.consume(frame: frame)
            detectBarcodesIfNeeded(in: frame)
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            controller.reportSessionError(
                "ARKit stopped because of an error: \(error.localizedDescription)"
            )
        }

        func sessionWasInterrupted(_ session: ARSession) {
            controller.reportSessionError(
                "The AR session was interrupted. Start a fresh scan when the app becomes active again."
            )
        }

        private func detectBarcodesIfNeeded(in frame: ARFrame) {
            guard controller.shouldDetectBarcodes else {
                return
            }

            detectionLock.lock()
            guard !isDetectingBarcode,
                  frame.timestamp - lastBarcodeDetectionTimestamp >= 0.6 else {
                detectionLock.unlock()
                return
            }
            isDetectingBarcode = true
            lastBarcodeDetectionTimestamp = frame.timestamp
            detectionLock.unlock()

            DispatchQueue.main.async {
                guard let sceneView = self.sceneView,
                      sceneView.bounds.width > 0,
                      sceneView.bounds.height > 0 else {
                    self.finishBarcodeDetection()
                    return
                }

                let orientation = sceneView.window?
                    .windowScene?
                    .interfaceOrientation ?? .portrait
                let viewportSize = sceneView.bounds.size
                let displayTransform = frame.displayTransform(
                    for: orientation,
                    viewportSize: viewportSize
                )
                let imageOrientation = self.imageOrientation(
                    for: orientation
                )

                self.visionQueue.async {
                    let request = VNDetectBarcodesRequest()
                    request.symbologies = [
                        .qr,
                        .code128,
                        .code39,
                        .code93,
                        .ean13,
                        .ean8,
                        .upce,
                        .dataMatrix,
                        .pdf417,
                        .aztec
                    ]

                    do {
                        let handler = VNImageRequestHandler(
                            cvPixelBuffer: frame.capturedImage,
                            orientation: imageOrientation,
                            options: [:]
                        )
                        try handler.perform([request])

                        let candidates = (request.results ?? []).compactMap {
                            observation -> BarcodeCandidate? in
                            guard let payload =
                                observation.payloadStringValue else {
                                return nil
                            }
                            return BarcodeCandidate(
                                payload: payload,
                                symbology: observation.symbology.rawValue,
                                normalizedCenter: CGPoint(
                                    x: observation.boundingBox.midX,
                                    y: observation.boundingBox.midY
                                ),
                                normalizedExtent: max(
                                    observation.boundingBox.width,
                                    observation.boundingBox.height
                                )
                            )
                        }

                        DispatchQueue.main.async {
                            for candidate in candidates {
                                self.position(
                                    candidate,
                                    in: sceneView,
                                    frame: frame,
                                    displayTransform: displayTransform,
                                    viewportSize: viewportSize
                                )
                            }
                            self.finishBarcodeDetection()
                        }
                    } catch {
                        self.finishBarcodeDetection()
                    }
                }
            }
        }

        private func position(
            _ candidate: BarcodeCandidate,
            in sceneView: ARSCNView,
            frame: ARFrame,
            displayTransform: CGAffineTransform,
            viewportSize: CGSize
        ) {
            let normalizedImagePoint = CGPoint(
                x: candidate.normalizedCenter.x,
                y: 1 - candidate.normalizedCenter.y
            )
            let normalizedViewPoint = normalizedImagePoint.applying(
                displayTransform
            )
            let viewPoint = CGPoint(
                x: normalizedViewPoint.x * viewportSize.width,
                y: normalizedViewPoint.y * viewportSize.height
            )

            let camera = frame.camera.transform
            let cameraPosition = SIMD3<Float>(
                camera.columns.3.x,
                camera.columns.3.y,
                camera.columns.3.z
            )

            let raycastResults: [ARRaycastResult]
            if let surfaceQuery = sceneView.raycastQuery(
                from: viewPoint,
                allowing: .existingPlaneGeometry,
                alignment: .any
            ) {
                let surfaceResults = sceneView.session.raycast(surfaceQuery)
                if surfaceResults.isEmpty,
                   let estimatedQuery = sceneView.raycastQuery(
                    from: viewPoint,
                    allowing: .estimatedPlane,
                    alignment: .any
                   ) {
                    raycastResults = sceneView.session.raycast(
                        estimatedQuery
                    )
                } else {
                    raycastResults = surfaceResults
                }
            } else {
                raycastResults = []
            }

            let position: SIMD3<Float>
            let positionSource: BarcodePositionSource
            let maximumSurfaceDistance = maximumPlausibleDistance(
                for: candidate.normalizedExtent
            )
            let plausibleSurface = raycastResults.first { result in
                let candidatePosition = SIMD3<Float>(
                    result.worldTransform.columns.3.x,
                    result.worldTransform.columns.3.y,
                    result.worldTransform.columns.3.z
                )
                let distance = simd_distance(
                    cameraPosition,
                    candidatePosition
                )
                return distance >= 0.12 && distance <= maximumSurfaceDistance
            }

            if let result = plausibleSurface {
                position = SIMD3<Float>(
                    result.worldTransform.columns.3.x,
                    result.worldTransform.columns.3.y,
                    result.worldTransform.columns.3.z
                )
                positionSource = .surfaceRaycast
            } else {
                let forward = -SIMD3<Float>(
                    camera.columns.2.x,
                    camera.columns.2.y,
                    camera.columns.2.z
                )
                let estimatedDistance = estimatedBarcodeDistance(
                    for: candidate.normalizedExtent
                )
                position = cameraPosition
                    + simd_normalize(forward) * estimatedDistance
                positionSource = .cameraEstimate
            }

            controller.noteBarcode(
                payload: candidate.payload,
                symbology: candidate.symbology,
                worldPosition: position,
                cameraTransform: frame.camera.transform,
                positionSource: positionSource
            )
        }

        private func maximumPlausibleDistance(
            for normalizedExtent: CGFloat
        ) -> Float {
            let visibleSize = max(Float(normalizedExtent), 0.06)
            return min(7, max(1, 0.55 / visibleSize))
        }

        private func estimatedBarcodeDistance(
            for normalizedExtent: CGFloat
        ) -> Float {
            let visibleSize = max(Float(normalizedExtent), 0.05)
            return min(3.5, max(0.35, 0.14 / visibleSize))
        }

        private func imageOrientation(
            for orientation: UIInterfaceOrientation
        ) -> CGImagePropertyOrientation {
            switch orientation {
            case .portrait:
                return .right
            case .portraitUpsideDown:
                return .left
            case .landscapeLeft:
                return .up
            case .landscapeRight:
                return .down
            default:
                return .right
            }
        }

        private func finishBarcodeDetection() {
            detectionLock.lock()
            isDetectingBarcode = false
            detectionLock.unlock()
        }
    }
}
