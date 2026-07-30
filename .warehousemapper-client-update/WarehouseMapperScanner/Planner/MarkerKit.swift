import ARKit
import ImageIO
import SwiftUI
import UIKit

enum MarkerKit {
    static func identifier(zoneID: UUID, index: Int) -> String {
        "WM:\(zoneID.uuidString):\(index)"
    }

    static func parseIdentifier(
        _ identifier: String
    ) -> (zoneID: UUID, index: Int)? {
        let pieces = identifier.split(separator: ":")
        guard pieces.count == 3,
              pieces[0] == "WM",
              let zoneID = UUID(uuidString: String(pieces[1])),
              let index = Int(pieces[2]) else {
            return nil
        }
        return (zoneID, index)
    }

    static func referenceImages(for zone: WarehouseZone) -> Set<ARReferenceImage> {
        let recommendation = MarkerRecommendation.forZone(
            widthMeters: zone.widthMeters,
            depthMeters: zone.depthMeters
        )
        let physicalWidth = CGFloat(recommendation.edgeCentimeters) / 100

        return Set(
            (1...recommendation.markerCount).compactMap { index in
                guard let cgImage = image(
                    zoneID: zone.id,
                    index: index
                ).cgImage else {
                    return nil
                }

                let reference = ARReferenceImage(
                    cgImage,
                    orientation: .up,
                    physicalWidth: physicalWidth
                )
                reference.name = identifier(zoneID: zone.id, index: index)
                return reference
            }
        )
    }

    static func image(
        zoneID: UUID,
        index: Int,
        pixels: CGFloat = 1_024
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1

        return UIGraphicsImageRenderer(
            size: CGSize(width: pixels, height: pixels),
            format: format
        ).image { context in
            let cg = context.cgContext
            UIColor.white.setFill()
            cg.fill(CGRect(x: 0, y: 0, width: pixels, height: pixels))

            let outerInset = pixels * 0.045
            let borderWidth = pixels * 0.055
            UIColor.black.setStroke()
            cg.setLineWidth(borderWidth)
            cg.stroke(
                CGRect(
                    x: outerInset,
                    y: outerInset,
                    width: pixels - outerInset * 2,
                    height: pixels - outerInset * 2
                )
            )

            let gridCount = 9
            let gridOrigin = pixels * 0.15
            let gridSize = pixels * 0.70
            let cell = gridSize / CGFloat(gridCount)
            var generator = SeededMarkerGenerator(
                zoneID: zoneID,
                markerIndex: index
            )

            for row in 0..<gridCount {
                for column in 0..<gridCount {
                    let isOrientationCell =
                        (row < 2 && column < 2)
                        || (row > 6 && column < 2)
                        || (row < 2 && column > 6)
                    let shouldFill = isOrientationCell
                        ? orientationCell(
                            row: row,
                            column: column,
                            markerIndex: index
                        )
                        : generator.nextBit()

                    if shouldFill {
                        UIColor.black.setFill()
                        cg.fill(
                            CGRect(
                                x: gridOrigin + CGFloat(column) * cell,
                                y: gridOrigin + CGFloat(row) * cell,
                                width: cell + 0.5,
                                height: cell + 0.5
                            )
                        )
                    }
                }
            }

            let numberText = "\(index)"
            let numberFont = UIFont.monospacedSystemFont(
                ofSize: pixels * 0.16,
                weight: .black
            )
            let attributes: [NSAttributedString.Key: Any] = [
                .font: numberFont,
                .foregroundColor: UIColor.black,
                .backgroundColor: UIColor.white
            ]
            let size = numberText.size(withAttributes: attributes)
            numberText.draw(
                at: CGPoint(
                    x: (pixels - size.width) / 2,
                    y: pixels * 0.72
                ),
                withAttributes: attributes
            )
        }
    }

    static func createMarkerPDF(for zone: WarehouseZone) throws -> URL {
        let recommendation = MarkerRecommendation.forZone(
            widthMeters: zone.widthMeters,
            depthMeters: zone.depthMeters
        )
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let markerPoints = CGFloat(recommendation.edgeCentimeters)
            / 2.54
            * 72
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let data = renderer.pdfData { context in
            for index in 1...recommendation.markerCount {
                context.beginPage()

                let title = index == 1
                    ? "\(zone.name) — Entrance marker"
                    : "\(zone.name) — Marker \(index)"
                title.draw(
                    at: CGPoint(x: 42, y: 28),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                        .foregroundColor: UIColor.black
                    ]
                )

                let subtitle = index == 1
                    ? "Install this at the zone entrance. Do not move it after setup."
                    : "Install flat on a fixed rack, wall, or post. Do not move it after setup."
                subtitle.draw(
                    in: CGRect(x: 42, y: 58, width: 528, height: 42),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                        .foregroundColor: UIColor.darkGray
                    ]
                )

                let markerRect = CGRect(
                    x: (page.width - markerPoints) / 2,
                    y: 108,
                    width: markerPoints,
                    height: markerPoints
                )
                image(zoneID: zone.id, index: index).draw(in: markerRect)

                let directions = """
                PRINT AT 100% / ACTUAL SIZE — do not use “Fit to page.”
                Printed square: \(recommendation.edgeCentimeters) cm (\(String(format: "%.1f", Double(recommendation.edgeCentimeters) / 2.54)) in)
                Ordinary white paper or matte cardstock is fine. Tape it flat and avoid glossy covers or glare.
                """
                directions.draw(
                    in: CGRect(
                        x: 42,
                        y: min(page.height - 92, markerRect.maxY + 20),
                        width: 528,
                        height: 72
                    ),
                    withAttributes: [
                        .font: UIFont.monospacedSystemFont(
                            ofSize: 10,
                            weight: .semibold
                        ),
                        .foregroundColor: UIColor.black
                    ]
                )
            }
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WarehouseMapperExports", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let safeName = zone.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = directory.appendingPathComponent(
            "\(safeName)-Location-Markers.pdf"
        )
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func orientationCell(
        row: Int,
        column: Int,
        markerIndex: Int
    ) -> Bool {
        if row < 2 && column < 2 {
            return true
        }
        if row > 6 && column < 2 {
            return row == 8 || column == 0
        }
        if row < 2 && column > 6 {
            return (row + column + markerIndex).isMultiple(of: 2)
        }
        return false
    }
}

private struct SeededMarkerGenerator {
    private var state: UInt64

    init(zoneID: UUID, markerIndex: Int) {
        let bytes = withUnsafeBytes(of: zoneID.uuid) { Array($0) }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in bytes {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        hash ^= UInt64(markerIndex &* 0x45D9F3B)
        state = hash
    }

    mutating func nextBit() -> Bool {
        state = state &* 6_364_136_223_846_793_005 &+ 1
        return ((state >> 32) & 1) == 1
    }
}

struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
