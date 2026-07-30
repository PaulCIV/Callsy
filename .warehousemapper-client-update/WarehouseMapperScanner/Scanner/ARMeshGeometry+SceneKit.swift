import ARKit
import Metal
import SceneKit
import simd
import UIKit

enum WarehouseSurfaceStyle: Int, CaseIterable, Hashable {
    case floor
    case wall
    case ceiling
    case opening
    case fixture
    case unknown

    init(classification: ARMeshClassification) {
        switch classification {
        case .floor:
            self = .floor
        case .wall:
            self = .wall
        case .ceiling:
            self = .ceiling
        case .door, .window:
            self = .opening
        case .seat, .table:
            self = .fixture
        case .none:
            self = .unknown
        @unknown default:
            self = .unknown
        }
    }

    func material(live: Bool) -> SCNMaterial {
        let material = SCNMaterial()
        material.name = "warehouse-surface-\(rawValue)"
        material.diffuse.contents = color
        material.roughness.contents = 0.94
        material.metalness.contents = self == .fixture ? 0.12 : 0.03
        material.isDoubleSided = true
        material.lightingModel = .physicallyBased

        if live {
            material.transparency = liveTransparency
            material.blendMode = .alpha
            material.writesToDepthBuffer = false
            material.fillMode = .lines
        } else {
            material.transparency = 1
        }
        return material
    }

    private var liveTransparency: CGFloat {
        switch self {
        case .floor:
            return 0.42
        case .wall:
            return 0.38
        case .ceiling:
            return 0.25
        case .opening:
            return 0.35
        case .fixture:
            return 0.50
        case .unknown:
            return 0.40
        }
    }

    private var color: UIColor {
        switch self {
        case .floor:
            return UIColor(white: 0.20, alpha: 1)
        case .wall:
            return UIColor(white: 0.72, alpha: 1)
        case .ceiling:
            return UIColor(white: 0.36, alpha: 1)
        case .opening:
            return UIColor(red: 0.42, green: 0.49, blue: 0.54, alpha: 1)
        case .fixture:
            return UIColor(white: 0.50, alpha: 1)
        case .unknown:
            return UIColor(white: 0.60, alpha: 1)
        }
    }
}

extension SCNGeometry {
    static func liveMesh(from mesh: ARMeshGeometry) -> SCNGeometry {
        let vertexSource = SCNGeometrySource(
            buffer: mesh.vertices.buffer,
            vertexFormat: mesh.vertices.format,
            semantic: .vertex,
            vertexCount: mesh.vertices.count,
            dataOffset: mesh.vertices.offset,
            dataStride: mesh.vertices.stride
        )

        let normalSource = SCNGeometrySource(
            buffer: mesh.normals.buffer,
            vertexFormat: mesh.normals.format,
            semantic: .normal,
            vertexCount: mesh.normals.count,
            dataOffset: mesh.normals.offset,
            dataStride: mesh.normals.stride
        )

        let indices = mesh.triangleIndices()
        let classifications = (0..<mesh.faces.count).map {
            mesh.classificationOfFace(at: $0).rawValue
        }
        let styled = styledElements(
            triangleIndices: indices,
            classifications: classifications
        )

        let geometry = SCNGeometry(
            sources: [vertexSource, normalSource],
            elements: styled.elements
        )
        geometry.materials = styled.styles.map { $0.material(live: true) }
        return geometry
    }

    static func savedMesh(from snapshot: MeshSnapshot) -> SCNGeometry {
        let vertices = snapshot.vertices.map {
            SCNVector3($0.x, $0.y, $0.z)
        }
        let vertexSource = SCNGeometrySource(vertices: vertices)

        let normals: [SCNVector3]
        if let savedNormals = snapshot.normals,
           savedNormals.count == snapshot.vertices.count {
            normals = savedNormals.map { SCNVector3($0.x, $0.y, $0.z) }
        } else {
            normals = calculatedNormals(
                vertices: snapshot.vertices,
                triangleIndices: snapshot.triangleIndices
            ).map { SCNVector3($0.x, $0.y, $0.z) }
        }
        let normalSource = SCNGeometrySource(normals: normals)

        let styled = styledElements(
            triangleIndices: snapshot.triangleIndices,
            classifications: snapshot.triangleClassifications
        )
        let geometry = SCNGeometry(
            sources: [vertexSource, normalSource],
            elements: styled.elements
        )
        geometry.materials = styled.styles.map { $0.material(live: false) }
        return geometry
    }

    private static func styledElements(
        triangleIndices: [UInt32],
        classifications: [Int]?
    ) -> (elements: [SCNGeometryElement], styles: [WarehouseSurfaceStyle]) {
        var grouped: [WarehouseSurfaceStyle: [UInt32]] = [:]
        let triangleCount = triangleIndices.count / 3

        for triangle in 0..<triangleCount {
            let classification: ARMeshClassification
            if let classifications,
               triangle < classifications.count {
                classification = ARMeshClassification(
                    rawValue: classifications[triangle]
                ) ?? .none
            } else {
                classification = .none
            }

            let style = WarehouseSurfaceStyle(classification: classification)
            let start = triangle * 3
            grouped[style, default: []].append(contentsOf: [
                triangleIndices[start],
                triangleIndices[start + 1],
                triangleIndices[start + 2]
            ])
        }

        var elements: [SCNGeometryElement] = []
        var styles: [WarehouseSurfaceStyle] = []

        for style in WarehouseSurfaceStyle.allCases {
            guard let indices = grouped[style], !indices.isEmpty else {
                continue
            }

            let data = indices.withUnsafeBufferPointer { Data(buffer: $0) }
            elements.append(
                SCNGeometryElement(
                    data: data,
                    primitiveType: .triangles,
                    primitiveCount: indices.count / 3,
                    bytesPerIndex: MemoryLayout<UInt32>.size
                )
            )
            styles.append(style)
        }

        return (elements, styles)
    }

    private static func calculatedNormals(
        vertices: [Vector3],
        triangleIndices: [UInt32]
    ) -> [SIMD3<Float>] {
        var result = Array(
            repeating: SIMD3<Float>.zero,
            count: vertices.count
        )

        for triangle in stride(from: 0, to: triangleIndices.count - 2, by: 3) {
            let first = Int(triangleIndices[triangle])
            let second = Int(triangleIndices[triangle + 1])
            let third = Int(triangleIndices[triangle + 2])

            guard first < vertices.count,
                  second < vertices.count,
                  third < vertices.count else {
                continue
            }

            let a = vertices[first].simdValue
            let b = vertices[second].simdValue
            let c = vertices[third].simdValue
            let cross = simd_cross(b - a, c - a)

            guard simd_length_squared(cross) > 0.000_001 else {
                continue
            }

            let normal = simd_normalize(cross)
            result[first] += normal
            result[second] += normal
            result[third] += normal
        }

        return result.map {
            simd_length_squared($0) > 0.000_001
                ? simd_normalize($0)
                : SIMD3<Float>(0, 1, 0)
        }
    }
}

extension ARMeshGeometry {
    func vertex(at index: Int) -> SIMD3<Float> {
        let address = vertices.buffer.contents()
            .advanced(by: vertices.offset + vertices.stride * index)
        return address.assumingMemoryBound(to: SIMD3<Float>.self).pointee
    }

    func normal(at index: Int) -> SIMD3<Float> {
        let address = normals.buffer.contents()
            .advanced(by: normals.offset + normals.stride * index)
        return address.assumingMemoryBound(to: SIMD3<Float>.self).pointee
    }

    func classificationOfFace(at index: Int) -> ARMeshClassification {
        guard let classification else {
            return .none
        }

        let address = classification.buffer.contents()
            .advanced(by: classification.offset + classification.stride * index)
        let rawValue = Int(
            address.assumingMemoryBound(to: UInt8.self).pointee
        )
        return ARMeshClassification(rawValue: rawValue) ?? .none
    }

    func triangleIndices() -> [UInt32] {
        let totalIndexCount = faces.count * faces.indexCountPerPrimitive
        var result: [UInt32] = []
        result.reserveCapacity(totalIndexCount)

        for index in 0..<totalIndexCount {
            let address = faces.buffer.contents()
                .advanced(by: index * faces.bytesPerIndex)

            switch faces.bytesPerIndex {
            case MemoryLayout<UInt16>.size:
                result.append(
                    UInt32(address.assumingMemoryBound(to: UInt16.self).pointee)
                )
            case MemoryLayout<UInt32>.size:
                result.append(
                    address.assumingMemoryBound(to: UInt32.self).pointee
                )
            default:
                assertionFailure("Unsupported mesh index size: \(faces.bytesPerIndex)")
            }
        }

        return result
    }
}
