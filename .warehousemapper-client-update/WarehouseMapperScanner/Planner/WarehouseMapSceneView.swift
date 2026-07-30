import SceneKit
import SwiftUI
import UIKit

struct WarehouseMapSceneView: UIViewRepresentable {
    let zones: [WarehouseZone]
    let footprint: WarehouseFootprint?
    let selectedZoneID: UUID?
    let onSelect: (UUID) -> Void
    let onMove: (UUID, Float, Float) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = UIColor(
            red: 0.025,
            green: 0.035,
            blue: 0.055,
            alpha: 1
        )
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        tap.require(toFail: pan)

        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        context.coordinator.view = view

        rebuildScene(in: view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.parent = self
        rebuildScene(in: view)
    }

    private func rebuildScene(in view: SCNView) {
        let previousScale = view.pointOfView?.camera?.orthographicScale
        let scene = SCNScene()
        let bounds = mapBounds()

        addFloor(to: scene, bounds: bounds)
        addWarehouseOutline(to: scene, bounds: bounds)
        addZones(to: scene)
        addLighting(to: scene)
        addCamera(
            to: scene,
            bounds: bounds,
            previousScale: previousScale
        )

        view.scene = scene
        view.pointOfView = scene.rootNode.childNode(
            withName: "planner-camera",
            recursively: true
        )
    }

    private func addFloor(
        to scene: SCNScene,
        bounds: MapBounds
    ) {
        let floor = SCNBox(
            width: CGFloat(bounds.width),
            height: 0.08,
            length: CGFloat(bounds.depth),
            chamferRadius: 0.12
        )
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = UIColor(
            red: 0.055,
            green: 0.07,
            blue: 0.095,
            alpha: 1
        )
        floorMaterial.roughness.contents = 0.94
        floor.materials = [floorMaterial]

        let floorNode = SCNNode(geometry: floor)
        floorNode.name = "planner-floor"
        floorNode.position = SCNVector3(
            bounds.centerX,
            -0.06,
            bounds.centerZ
        )
        scene.rootNode.addChildNode(floorNode)

        let gridSpacing: Float = max(bounds.width, bounds.depth) > 70 ? 5 : 2
        var gridVertices: [SCNVector3] = []

        var x = (bounds.minX / gridSpacing).rounded(.down) * gridSpacing
        while x <= bounds.maxX {
            gridVertices.append(SCNVector3(x, 0.003, bounds.minZ))
            gridVertices.append(SCNVector3(x, 0.003, bounds.maxZ))
            x += gridSpacing
        }

        var z = (bounds.minZ / gridSpacing).rounded(.down) * gridSpacing
        while z <= bounds.maxZ {
            gridVertices.append(SCNVector3(bounds.minX, 0.003, z))
            gridVertices.append(SCNVector3(bounds.maxX, 0.003, z))
            z += gridSpacing
        }

        if let gridNode = lineNode(
            vertices: gridVertices,
            color: UIColor.white.withAlphaComponent(0.10)
        ) {
            gridNode.name = "planner-grid"
            scene.rootNode.addChildNode(gridNode)
        }
    }

    private func addZones(to scene: SCNScene) {
        for zone in zones {
            let selected = zone.id == selectedZoneID
            let root = SCNNode()
            root.name = "zone:\(zone.id.uuidString)"
            root.position = SCNVector3(zone.centerX, 0, zone.centerZ)
            root.eulerAngles.y = -zone.rotationDegrees * .pi / 180

            let base = SCNBox(
                width: CGFloat(zone.widthMeters),
                height: selected ? 0.24 : 0.16,
                length: CGFloat(zone.depthMeters),
                chamferRadius: selected ? 0.12 : 0.07
            )
            let baseMaterial = SCNMaterial()
            baseMaterial.diffuse.contents = selected
                ? UIColor.systemCyan.withAlphaComponent(0.88)
                : zoneColor(zone.kind).withAlphaComponent(0.82)
            baseMaterial.emission.contents = selected
                ? UIColor.systemCyan.withAlphaComponent(0.26)
                : UIColor.black
            baseMaterial.roughness.contents = 0.84
            base.materials = [baseMaterial]

            let baseNode = SCNNode(geometry: base)
            baseNode.name = root.name
            baseNode.position.y = selected ? 0.12 : 0.08
            root.addChildNode(baseNode)

            addZoneStructures(for: zone, to: root)
            addMarkers(for: zone, to: root)
            addStorageLocations(for: zone, to: root)
            addLabel(for: zone, selected: selected, to: root)

            if zone.hasScan {
                let scannedRing = SCNTorus(
                    ringRadius: 0.22,
                    pipeRadius: 0.035
                )
                let scannedMaterial = SCNMaterial()
                scannedMaterial.diffuse.contents = UIColor.systemGreen
                scannedMaterial.emission.contents = UIColor.systemGreen
                    .withAlphaComponent(0.35)
                scannedRing.materials = [scannedMaterial]

                let scannedNode = SCNNode(geometry: scannedRing)
                scannedNode.name = root.name
                scannedNode.position = SCNVector3(
                    -zone.widthMeters / 2 + 0.38,
                    0.30,
                    -zone.depthMeters / 2 + 0.38
                )
                root.addChildNode(scannedNode)
            }

            scene.rootNode.addChildNode(root)
        }
    }

    private func addWarehouseOutline(
        to scene: SCNScene,
        bounds: MapBounds
    ) {
        guard footprint != nil else {
            return
        }

        let vertices = [
            SCNVector3(bounds.minX, 0.08, bounds.minZ),
            SCNVector3(bounds.maxX, 0.08, bounds.minZ),
            SCNVector3(bounds.maxX, 0.08, bounds.minZ),
            SCNVector3(bounds.maxX, 0.08, bounds.maxZ),
            SCNVector3(bounds.maxX, 0.08, bounds.maxZ),
            SCNVector3(bounds.minX, 0.08, bounds.maxZ),
            SCNVector3(bounds.minX, 0.08, bounds.maxZ),
            SCNVector3(bounds.minX, 0.08, bounds.minZ)
        ]
        if let outline = lineNode(
            vertices: vertices,
            color: UIColor.systemCyan.withAlphaComponent(0.88)
        ) {
            outline.name = "warehouse-footprint"
            scene.rootNode.addChildNode(outline)
        }
    }

    private func addZoneStructures(
        for zone: WarehouseZone,
        to root: SCNNode
    ) {
        let structureHeight = min(max(zone.heightMeters * 0.10, 0.35), 1.25)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(
            white: 0.68,
            alpha: 0.80
        )
        material.roughness.contents = 0.88

        switch zone.kind {
        case .aisle:
            let rackWidth = max(0.35, zone.widthMeters * 0.16)
            for x in [-zone.widthMeters * 0.34, zone.widthMeters * 0.34] {
                let rack = SCNBox(
                    width: CGFloat(rackWidth),
                    height: CGFloat(structureHeight),
                    length: CGFloat(max(0.8, zone.depthMeters * 0.86)),
                    chamferRadius: 0.04
                )
                rack.materials = [material]
                let node = SCNNode(geometry: rack)
                node.name = root.name
                node.position = SCNVector3(x, structureHeight / 2 + 0.18, 0)
                root.addChildNode(node)
            }

        case .bulkStorage, .receiving, .shipping:
            let columns = max(2, min(4, Int(zone.widthMeters / 3)))
            let rows = max(2, min(5, Int(zone.depthMeters / 3)))
            let boxWidth = zone.widthMeters / Float(columns) * 0.58
            let boxDepth = zone.depthMeters / Float(rows) * 0.58

            for column in 0..<columns {
                for row in 0..<rows {
                    let pallet = SCNBox(
                        width: CGFloat(boxWidth),
                        height: CGFloat(structureHeight * 0.62),
                        length: CGFloat(boxDepth),
                        chamferRadius: 0.04
                    )
                    pallet.materials = [material]
                    let node = SCNNode(geometry: pallet)
                    node.name = root.name
                    node.position = SCNVector3(
                        -zone.widthMeters / 2
                            + zone.widthMeters
                            * (Float(column) + 0.5)
                            / Float(columns),
                        structureHeight * 0.31 + 0.18,
                        -zone.depthMeters / 2
                            + zone.depthMeters
                            * (Float(row) + 0.5)
                            / Float(rows)
                    )
                    root.addChildNode(node)
                }
            }

        case .packing, .coldStorage, .equipment, .other:
            let structure = SCNBox(
                width: CGFloat(max(0.8, zone.widthMeters * 0.62)),
                height: CGFloat(structureHeight * 0.72),
                length: CGFloat(max(0.8, zone.depthMeters * 0.62)),
                chamferRadius: 0.06
            )
            structure.materials = [material]
            let node = SCNNode(geometry: structure)
            node.name = root.name
            node.position.y = structureHeight * 0.36 + 0.18
            root.addChildNode(node)
        }
    }

    private func addMarkers(
        for zone: WarehouseZone,
        to root: SCNNode
    ) {
        let positions = MarkerRecommendation.positions(for: zone)

        for (index, position) in positions.enumerated() {
            let post = SCNCylinder(radius: 0.055, height: 0.48)
            post.radialSegmentCount = 8
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemYellow
            material.emission.contents = UIColor.systemYellow
                .withAlphaComponent(0.26)
            post.materials = [material]

            let node = SCNNode(geometry: post)
            node.name = root.name
            node.position = SCNVector3(position.x, 0.40, position.y)
            root.addChildNode(node)

            if index == 0 {
                let start = SCNTorus(ringRadius: 0.16, pipeRadius: 0.025)
                let startMaterial = SCNMaterial()
                startMaterial.diffuse.contents = UIColor.systemGreen
                startMaterial.emission.contents = UIColor.systemGreen
                    .withAlphaComponent(0.32)
                start.materials = [startMaterial]

                let startNode = SCNNode(geometry: start)
                startNode.name = root.name
                startNode.position = SCNVector3(position.x, 0.20, position.y)
                root.addChildNode(startNode)
            }
        }
    }

    private func addStorageLocations(
        for zone: WarehouseZone,
        to root: SCNNode
    ) {
        guard let boundary = zone.boundary else {
            return
        }

        for location in zone.recordedStorageLocations {
            guard let offset = boundary.mapOffset(
                x: location.x,
                z: location.z,
                zoneWidth: zone.widthMeters,
                zoneDepth: zone.depthMeters
            ) else {
                continue
            }

            let color: UIColor = location.occupancy == .occupied
                ? .systemOrange
                : .systemGreen
            let pin = SCNCylinder(radius: 0.13, height: 0.30)
            pin.radialSegmentCount = 14
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.emission.contents = color.withAlphaComponent(0.42)
            pin.materials = [material]

            let node = SCNNode(geometry: pin)
            node.name = root.name
            node.position = SCNVector3(
                min(
                    zone.widthMeters / 2 - 0.16,
                    max(-zone.widthMeters / 2 + 0.16, offset.x)
                ),
                0.34,
                min(
                    zone.depthMeters / 2 - 0.16,
                    max(-zone.depthMeters / 2 + 0.16, offset.y)
                )
            )
            root.addChildNode(node)
        }
    }

    private func addLabel(
        for zone: WarehouseZone,
        selected: Bool,
        to root: SCNNode
    ) {
        let text = SCNText(
            string: zone.name,
            extrusionDepth: selected ? 0.7 : 0.45
        )
        text.font = UIFont.systemFont(
            ofSize: 10,
            weight: selected ? .bold : .semibold
        )
        text.flatness = 0.3
        let material = SCNMaterial()
        material.diffuse.contents = selected
            ? UIColor.white
            : UIColor(white: 0.92, alpha: 1)
        material.emission.contents = selected
            ? UIColor.systemCyan.withAlphaComponent(0.35)
            : UIColor.black
        text.materials = [material]

        let node = SCNNode(geometry: text)
        node.name = root.name
        let bounds = text.boundingBox
        node.pivot = SCNMatrix4MakeTranslation(
            (bounds.max.x - bounds.min.x) / 2,
            bounds.min.y,
            0
        )
        node.scale = SCNVector3(0.09, 0.09, 0.09)
        node.position = SCNVector3(
            0,
            min(max(zone.heightMeters * 0.10, 0.8), 1.7),
            0
        )

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = []
        node.constraints = [billboard]
        root.addChildNode(node)
    }

    private func addLighting(to scene: SCNScene) {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 620
        ambient.color = UIColor(white: 0.76, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let directional = SCNLight()
        directional.type = .directional
        directional.intensity = 1_000
        directional.castsShadow = true
        directional.shadowRadius = 7
        directional.shadowColor = UIColor.black.withAlphaComponent(0.42)
        let directionalNode = SCNNode()
        directionalNode.light = directional
        directionalNode.eulerAngles = SCNVector3(-0.9, 0.7, 0)
        scene.rootNode.addChildNode(directionalNode)
    }

    private func addCamera(
        to scene: SCNScene,
        bounds: MapBounds,
        previousScale: Double?
    ) {
        let target = SCNVector3(bounds.centerX, 0, bounds.centerZ)
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = previousScale
            ?? Double(max(bounds.width, bounds.depth) * 0.72)
        camera.zNear = 0.1
        camera.zFar = 500

        let node = SCNNode()
        node.name = "planner-camera"
        node.camera = camera
        let distance = max(bounds.width, bounds.depth)
        node.position = SCNVector3(
            bounds.centerX + distance * 0.62,
            distance * 0.82,
            bounds.centerZ + distance * 0.78
        )
        node.look(at: target)
        scene.rootNode.addChildNode(node)
    }

    private func mapBounds() -> MapBounds {
        if let footprint {
            return MapBounds(
                minX: -footprint.widthMeters / 2,
                maxX: footprint.widthMeters / 2,
                minZ: -footprint.depthMeters / 2,
                maxZ: footprint.depthMeters / 2
            )
        }

        guard !zones.isEmpty else {
            return MapBounds(
                minX: -12,
                maxX: 12,
                minZ: -9,
                maxZ: 9
            )
        }

        let minX = zones.map {
            $0.centerX - max($0.widthMeters, $0.depthMeters) / 2
        }.min() ?? -6
        let maxX = zones.map {
            $0.centerX + max($0.widthMeters, $0.depthMeters) / 2
        }.max() ?? 6
        let minZ = zones.map {
            $0.centerZ - max($0.widthMeters, $0.depthMeters) / 2
        }.min() ?? -6
        let maxZ = zones.map {
            $0.centerZ + max($0.widthMeters, $0.depthMeters) / 2
        }.max() ?? 6
        let padding: Float = 5

        return MapBounds(
            minX: minX - padding,
            maxX: maxX + padding,
            minZ: minZ - padding,
            maxZ: maxZ + padding
        )
    }

    private func zoneColor(_ kind: WarehouseZoneKind) -> UIColor {
        switch kind {
        case .aisle:
            return UIColor(red: 0.28, green: 0.38, blue: 0.50, alpha: 1)
        case .bulkStorage:
            return UIColor(red: 0.37, green: 0.34, blue: 0.30, alpha: 1)
        case .receiving:
            return UIColor(red: 0.26, green: 0.44, blue: 0.42, alpha: 1)
        case .packing:
            return UIColor(red: 0.42, green: 0.34, blue: 0.47, alpha: 1)
        case .shipping:
            return UIColor(red: 0.32, green: 0.43, blue: 0.34, alpha: 1)
        case .coldStorage:
            return UIColor(red: 0.25, green: 0.43, blue: 0.53, alpha: 1)
        case .equipment:
            return UIColor(red: 0.46, green: 0.37, blue: 0.28, alpha: 1)
        case .other:
            return UIColor(white: 0.36, alpha: 1)
        }
    }

    private func lineNode(
        vertices: [SCNVector3],
        color: UIColor
    ) -> SCNNode? {
        guard vertices.count >= 2, vertices.count.isMultiple(of: 2) else {
            return nil
        }

        let indices = (0..<UInt32(vertices.count)).map { $0 }
        let data = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(
            data: data,
            primitiveType: .line,
            primitiveCount: indices.count / 2,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )
        let geometry = SCNGeometry(sources: [source], elements: [element])
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color
        geometry.materials = [material]
        return SCNNode(geometry: geometry)
    }

    final class Coordinator: NSObject {
        var parent: WarehouseMapSceneView
        weak var view: SCNView?
        private var draggedZoneID: UUID?
        private var initialScale: Double = 20

        init(parent: WarehouseMapSceneView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view,
                  let id = zoneID(at: gesture.location(in: view)) else {
                return
            }
            parent.onSelect(id)
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view else {
                return
            }

            let location = gesture.location(in: view)

            switch gesture.state {
            case .began:
                guard let id = zoneID(at: location) else {
                    return
                }
                draggedZoneID = id
                parent.onSelect(id)

            case .changed:
                guard let id = draggedZoneID,
                      let point = groundPoint(at: location),
                      let node = view.scene?.rootNode.childNode(
                          withName: "zone:\(id.uuidString)",
                          recursively: false
                      ) else {
                    return
                }
                node.position.x = point.x
                node.position.z = point.z

            case .ended, .cancelled:
                guard let id = draggedZoneID,
                      let node = view.scene?.rootNode.childNode(
                          withName: "zone:\(id.uuidString)",
                          recursively: false
                      ) else {
                    draggedZoneID = nil
                    return
                }
                parent.onMove(id, node.position.x, node.position.z)
                draggedZoneID = nil

            default:
                break
            }
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let camera = view?.pointOfView?.camera else {
                return
            }

            if gesture.state == .began {
                initialScale = camera.orthographicScale
            }

            camera.orthographicScale = min(
                140,
                max(6, initialScale / Double(gesture.scale))
            )
        }

        private func zoneID(at point: CGPoint) -> UUID? {
            guard let view else {
                return nil
            }

            for result in view.hitTest(point) {
                var node: SCNNode? = result.node
                while let current = node {
                    if let name = current.name,
                       name.hasPrefix("zone:"),
                       let id = UUID(
                           uuidString: String(name.dropFirst("zone:".count))
                       ) {
                        return id
                    }
                    node = current.parent
                }
            }
            return nil
        }

        private func groundPoint(at point: CGPoint) -> SCNVector3? {
            guard let view else {
                return nil
            }

            let near = view.unprojectPoint(
                SCNVector3(Float(point.x), Float(point.y), 0)
            )
            let far = view.unprojectPoint(
                SCNVector3(Float(point.x), Float(point.y), 1)
            )
            let direction = SCNVector3(
                far.x - near.x,
                far.y - near.y,
                far.z - near.z
            )

            guard abs(direction.y) > 0.0001 else {
                return nil
            }

            let distance = -near.y / direction.y
            guard distance >= 0 else {
                return nil
            }

            return SCNVector3(
                near.x + direction.x * distance,
                0,
                near.z + direction.z * distance
            )
        }
    }
}

private struct MapBounds {
    let minX: Float
    let maxX: Float
    let minZ: Float
    let maxZ: Float

    var width: Float {
        max(18, maxX - minX)
    }

    var depth: Float {
        max(18, maxZ - minZ)
    }

    var centerX: Float {
        (minX + maxX) / 2
    }

    var centerZ: Float {
        (minZ + maxZ) / 2
    }
}
