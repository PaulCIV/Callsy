import SwiftUI

struct WarehouseMapView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var scanner: ScanSessionController
    @EnvironmentObject private var warehouseStore: WarehouseMapStore
    let onBeginCapture: (() -> Void)?

    @State private var selectedZoneID: UUID?
    @State private var editingContext: ZoneEditorContext?
    @State private var historyContext: ZoneHistoryContext?
    @State private var attachmentContext: ZoneAttachmentContext?
    @State private var selectedArchive: ScanArchive?
    @State private var editingCapacityZone: WarehouseZone?
    @State private var errorMessage: String?
    @State private var showingRename = false
    @State private var warehouseName = ""
    @State private var deletingZone: WarehouseZone?
    @State private var shareURL: URL?
    @State private var showingFootprintEditor = false
    @State private var viewingLocationsZoneID: UUID?

    init(onBeginCapture: (() -> Void)? = nil) {
        self.onBeginCapture = onBeginCapture
    }

    private var selectedZone: WarehouseZone? {
        guard let selectedZoneID else {
            return nil
        }
        return warehouseStore.zone(id: selectedZoneID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    mapHeader
                    warehouseFootprintCard

                    ZStack {
                        WarehouseMapSceneView(
                            zones: warehouseStore.plan.zones,
                            footprint: warehouseStore.plan.footprint,
                            selectedZoneID: selectedZoneID,
                            onSelect: { id in
                                selectedZoneID = id
                            },
                            onMove: { id, x, z in
                                warehouseStore.moveZone(
                                    id: id,
                                    centerX: x,
                                    centerZ: z
                                )
                            }
                        )

                        if warehouseStore.plan.zones.isEmpty {
                            emptyMapPrompt
                        }
                    }
                    .frame(height: 370)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(.white.opacity(0.11))
                    }

                    Label(
                        "Tap a zone to select · Drag to place · Pinch to zoom",
                        systemImage: "hand.draw.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !warehouseStore.plan.zones.isEmpty {
                        zoneStrip
                    }

                    if let selectedZone {
                        selectedZoneCard(selectedZone)
                    } else if !warehouseStore.plan.zones.isEmpty {
                        ContentUnavailableView(
                            "Select a zone",
                            systemImage: "square.3.layers.3d",
                            description: Text(
                                "Tap a zone in the model or the zone list below it."
                            )
                        )
                        .frame(minHeight: 190)
                    }
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.035, green: 0.05, blue: 0.08),
                        .black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Warehouse map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        editingContext = ZoneEditorContext(
                            zone: nil,
                            unit: warehouseStore.measurementUnit
                        )
                    } label: {
                        Label("Add zone", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $editingContext) { context in
                ZoneEditorView(context: context) { result in
                    saveZone(result, existingZone: context.zone)
                }
            }
            .sheet(item: $historyContext) { context in
                ZoneHistoryView(zoneID: context.zoneID)
                    .environmentObject(warehouseStore)
            }
            .sheet(item: $attachmentContext) { context in
                AttachSavedScanView(zoneID: context.zoneID) { summary in
                    _ = warehouseStore.assignExistingScan(
                        archiveID: summary.id,
                        capturedAt: summary.startedAt,
                        to: context.zoneID
                    )
                    selectedZoneID = context.zoneID
                }
            }
            .sheet(item: $selectedArchive) { archive in
                SavedScanView(archive: archive)
            }
            .sheet(item: $editingCapacityZone) { zone in
                ZoneCapacityEditorView(zoneID: zone.id)
            }
            .sheet(isPresented: $showingFootprintEditor) {
                WarehouseFootprintEditorView()
            }
            .sheet(
                isPresented: Binding(
                    get: { viewingLocationsZoneID != nil },
                    set: {
                        if !$0 {
                            viewingLocationsZoneID = nil
                        }
                    }
                )
            ) {
                if let zoneID = viewingLocationsZoneID {
                    ZoneStorageLocationsView(zoneID: zoneID)
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { shareURL != nil },
                    set: { if !$0 { shareURL = nil } }
                )
            ) {
                if let shareURL {
                    ActivityShareView(items: [shareURL])
                }
            }
            .alert("Rename warehouse", isPresented: $showingRename) {
                TextField("Warehouse name", text: $warehouseName)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    warehouseStore.renameWarehouse(warehouseName)
                }
            } message: {
                Text("This name stays with the local warehouse plan.")
            }
            .alert(
                "Warehouse map",
                isPresented: Binding(
                    get: {
                        errorMessage != nil
                            || warehouseStore.errorMessage != nil
                    },
                    set: { isPresented in
                        if !isPresented {
                            errorMessage = nil
                            warehouseStore.errorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                    warehouseStore.errorMessage = nil
                }
            } message: {
                Text(
                    errorMessage
                        ?? warehouseStore.errorMessage
                        ?? "Unknown error"
                )
            }
            .confirmationDialog(
                "Delete \(deletingZone?.name ?? "zone")?",
                isPresented: Binding(
                    get: { deletingZone != nil },
                    set: { if !$0 { deletingZone = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete zone", role: .destructive) {
                    if let deletingZone {
                        warehouseStore.deleteZone(id: deletingZone.id)
                        if selectedZoneID == deletingZone.id {
                            selectedZoneID = nil
                        }
                    }
                    deletingZone = nil
                }
                Button("Cancel", role: .cancel) {
                    deletingZone = nil
                }
            } message: {
                Text(
                    "The zone placement and revision links will be removed. The underlying scan files remain in Saved Scans."
                )
            }
            .onAppear {
                if selectedZoneID == nil {
                    selectedZoneID = warehouseStore.plan.zones.first?.id
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var mapHeader: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(warehouseStore.plan.name)
                    .font(.title2.bold())

                Text(
                    "\(warehouseStore.plan.zones.count) zones · \(scannedZoneCount) scanned"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showingFootprintEditor = true
            } label: {
                Image(systemName: "ruler")
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.bordered)

            Button {
                warehouseName = warehouseStore.plan.name
                showingRename = true
            } label: {
                Image(systemName: "pencil")
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.bordered)

            Button {
                editingContext = ZoneEditorContext(
                    zone: nil,
                    unit: warehouseStore.measurementUnit
                )
            } label: {
                Label("Zone", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
        }
        .padding(16)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18))
    }

    private var warehouseFootprintCard: some View {
        Button {
            showingFootprintEditor = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.dashed.inset.filled")
                    .font(.title3)
                    .foregroundStyle(
                        warehouseStore.plan.footprint == nil
                            ? Color.orange
                            : Color.cyan
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        warehouseStore.plan.footprint == nil
                            ? "Set warehouse dimensions"
                            : "Warehouse boundary"
                    )
                    .font(.subheadline.bold())

                    if let footprint = warehouseStore.plan.footprint {
                        Text(
                            String(
                                format: "%.0f × %.0f ft · %.0f ft clear height · %.0f ft²",
                                footprint.widthMeters * 3.28084,
                                footprint.depthMeters * 3.28084,
                                footprint.clearHeightMeters * 3.28084,
                                footprint.squareFeet
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                        Text(
                            "Without this, the overview expands around zones and cannot represent the actual building."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(13)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var emptyMapPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.3.layers.3d.down.right")
                .font(.system(size: 38))
                .foregroundStyle(.cyan)

            Text("Build the warehouse")
                .font(.headline)

            Text(
                "Create the first named zone, set its size, then drag it into place."
            )
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .frame(maxWidth: 230)

            Button("Add first zone") {
                editingContext = ZoneEditorContext(
                    zone: nil,
                    unit: warehouseStore.measurementUnit
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var zoneStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(warehouseStore.plan.zones) { zone in
                    Button {
                        selectedZoneID = zone.id
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: zone.kind.symbol)

                            Text(zone.name)
                                .lineLimit(1)

                            Circle()
                                .fill(zone.hasScan ? .green : .orange)
                                .frame(width: 7, height: 7)
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            zone.id == selectedZoneID
                                ? Color.cyan.opacity(0.22)
                                : Color.white.opacity(0.055),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .stroke(
                                    zone.id == selectedZoneID
                                        ? Color.cyan.opacity(0.78)
                                        : Color.white.opacity(0.08)
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func selectedZoneCard(_ zone: WarehouseZone) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: zone.kind.symbol)
                    .font(.title2)
                    .foregroundStyle(.cyan)
                    .frame(width: 44, height: 44)
                    .background(.cyan.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(zone.name)
                        .font(.title3.bold())

                    Text("\(zone.kind.title) · \(zone.sizeDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                zoneStatus(zone)

                Menu {
                    Button {
                        editingContext = ZoneEditorContext(
                            zone: zone,
                            unit: warehouseStore.measurementUnit
                        )
                    } label: {
                        Label("Edit zone", systemImage: "slider.horizontal.3")
                    }

                    Button(role: .destructive) {
                        deletingZone = zone
                    } label: {
                        Label("Delete zone", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }

            HStack(spacing: 10) {
                Button {
                    beginCapture(zoneID: zone.id)
                } label: {
                    Label(
                        zone.hasScan ? "Update capture" : "Capture zone",
                        systemImage: zone.hasScan
                            ? "arrow.triangle.2.circlepath.camera"
                            : "camera.viewfinder"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(zone.hasScan ? .orange : .green)

                if zone.hasScan {
                    Button {
                        openCurrentScan(zone)
                    } label: {
                        Label("Open", systemImage: "cube.transparent")
                    }
                    .buttonStyle(.bordered)
                }
            }

            zoneCapacityCard(zone)
            zoneLocationsCard(zone)

            if zone.hasScan {
                HStack(spacing: 10) {
                    Button {
                        historyContext = ZoneHistoryContext(zoneID: zone.id)
                    } label: {
                        Label(
                            "\(zone.scanRevisions.count) revisions",
                            systemImage: "clock.arrow.circlepath"
                        )
                    }
                    .buttonStyle(.bordered)

                    Button {
                        attachmentContext = ZoneAttachmentContext(zoneID: zone.id)
                    } label: {
                        Label("Attach saved", systemImage: "link")
                    }
                    .buttonStyle(.bordered)
                }

                Text(
                    "Updating creates a new active revision for this zone. Its name, dimensions, map position, markers, and every previous scan stay intact."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Button {
                    attachmentContext = ZoneAttachmentContext(zoneID: zone.id)
                } label: {
                    Label(
                        "Attach an existing saved scan",
                        systemImage: "link"
                    )
                }
                .buttonStyle(.bordered)
            }

            MarkerPlanCard(zone: zone)

            HStack(spacing: 10) {
                Button {
                    exportMarkers(for: zone)
                } label: {
                    Label(
                        "Share markers",
                        systemImage: "square.and.arrow.up"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    beginMarkerSetup(zoneID: zone.id)
                } label: {
                    Label(
                        zone.hasMarkerSetup
                            ? "Rescan boundary"
                            : "Scan boundary",
                        systemImage: "viewfinder"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
            }
        }
        .padding(16)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 20))
    }

    private func zoneCapacityCard(_ zone: WarehouseZone) -> some View {
        Button {
            editingCapacityZone = zone
        } label: {
            HStack(spacing: 12) {
                Image(
                    systemName: zone.capacityProfile?.layout.symbol
                        ?? "ruler.fill"
                )
                .font(.title3)
                .foregroundStyle(
                    zone.capacityProfile == nil ? Color.orange : Color.cyan
                )
                .frame(width: 42, height: 42)
                .background(
                    (
                        zone.capacityProfile == nil
                            ? Color.orange
                            : Color.cyan
                    ).opacity(0.13),
                    in: RoundedRectangle(cornerRadius: 12)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        zone.capacityProfile == nil
                            ? "Add usable capacity"
                            : "Space utilization"
                    )
                    .font(.subheadline.bold())

                    if let profile = zone.capacityProfile {
                        Text(
                            "\(profile.normalizedOccupiedPositions) of \(profile.usablePositions) positions filled · \(Int((profile.utilization * 100).rounded()))%"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                        Text(
                            "Record positions so this zone can be included in consolidation."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(13)
            .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
    }

    private func zoneLocationsCard(_ zone: WarehouseZone) -> some View {
        Button {
            viewingLocationsZoneID = zone.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "barcode.viewfinder")
                    .font(.title3)
                    .foregroundStyle(
                        zone.recordedStorageLocations.isEmpty
                            ? Color.yellow
                            : Color.green
                    )
                    .frame(width: 42, height: 42)
                    .background(
                        (
                            zone.recordedStorageLocations.isEmpty
                                ? Color.yellow
                                : Color.green
                        ).opacity(0.13),
                        in: RoundedRectangle(cornerRadius: 12)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        zone.recordedStorageLocations.isEmpty
                            ? "Scan aisle locations"
                            : "\(zone.recordedStorageLocations.count) mapped locations"
                    )
                    .font(.subheadline.bold())

                    Text(
                        zone.recordedStorageLocations.isEmpty
                            ? "During Capture Zone, center each location barcode and mark it open or occupied."
                            : "\(zone.openStorageLocationCount) open · \(zone.occupiedStorageLocationCount) occupied"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(13)
            .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
    }

    private func beginCapture(zoneID: UUID) {
        scanner.requestCapture(for: zoneID)
        dismiss()
        onBeginCapture?()
    }

    private func beginMarkerSetup(zoneID: UUID) {
        scanner.requestMarkerSetup(for: zoneID)
        dismiss()
        onBeginCapture?()
    }

    private func zoneStatus(_ zone: WarehouseZone) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(zone.hasScan ? .green : .orange)
                .frame(width: 7, height: 7)

            Text(
                zone.activeRevision.map {
                    "Rev \($0.revisionNumber)"
                } ?? "Unscanned"
            )
            .font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            (zone.hasScan ? Color.green : Color.orange).opacity(0.13),
            in: Capsule()
        )
    }

    private var scannedZoneCount: Int {
        warehouseStore.plan.zones.filter(\.hasScan).count
    }

    private func saveZone(
        _ result: ZoneEditorResult,
        existingZone: WarehouseZone?
    ) {
        if var existingZone {
            existingZone.name = result.name
            existingZone.kind = result.kind
            existingZone.widthMeters = result.widthMeters
            existingZone.depthMeters = result.depthMeters
            existingZone.heightMeters = result.heightMeters
            existingZone.rotationDegrees = result.rotationDegrees
            warehouseStore.updateZone(existingZone)
            selectedZoneID = existingZone.id
        } else {
            selectedZoneID = warehouseStore.addZone(
                name: result.name,
                kind: result.kind,
                widthMeters: result.widthMeters,
                depthMeters: result.depthMeters,
                heightMeters: result.heightMeters,
                rotationDegrees: result.rotationDegrees
            )
        }
    }

    private func openCurrentScan(_ zone: WarehouseZone) {
        guard let revision = zone.activeRevision else {
            return
        }

        do {
            selectedArchive = try ScanStore.load(id: revision.scanArchiveID)
        } catch {
            errorMessage = "That scan could not be opened: \(error.localizedDescription)"
        }
    }

    private func exportMarkers(for zone: WarehouseZone) {
        do {
            shareURL = try MarkerKit.createMarkerPDF(for: zone)
        } catch {
            errorMessage = "The marker PDF could not be created: \(error.localizedDescription)"
        }
    }
}

struct MarkerPlanCard: View {
    let zone: WarehouseZone

    private var recommendation: MarkerRecommendation {
        MarkerRecommendation.forZone(
            widthMeters: zone.widthMeters,
            depthMeters: zone.depthMeters
        )
    }

    private var markerPrefix: String {
        let letters = zone.name
            .uppercased()
            .filter(\.isLetter)
            .prefix(3)
        let shortID = zone.id.uuidString.prefix(4)
        return "\(letters.isEmpty ? "ZON" : String(letters))-\(shortID)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    "Zone boundary markers",
                    systemImage: "viewfinder.circle.fill"
                )
                    .font(.headline)

                Spacer()

                Text(
                    zone.hasMarkerSetup
                        ? "SET UP"
                        : "\(recommendation.markerCount) TO PRINT"
                )
                    .font(.caption.weight(.bold))
                    .foregroundStyle(zone.hasMarkerSetup ? .green : .yellow)
            }

            Text(
                "These black-and-white pages anchor the zone perimeter. Scan Marker 1 first, then every numbered marker around the edge. Their positions orient the boundary; the width and length you entered keep its real size from shrinking because two markers were close together."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                markerMetric(
                    title: "Paper square",
                    value: "\(recommendation.edgeCentimeters) cm",
                    detail: "\(inches(recommendation.edgeCentimeters)) in wide"
                )
                markerMetric(
                    title: "Maximum gap",
                    value: String(
                        format: "≤ %.0f m",
                        recommendation.maximumSpacingMeters
                    ),
                    detail: String(
                        format: "≈ %.0f ft",
                        recommendation.maximumSpacingMeters * 3.28084
                    )
                )
                markerMetric(
                    title: "Install height",
                    value: String(
                        format: "%.1f m",
                        recommendation.mountingHeightMeters
                    ),
                    detail: String(
                        format: "≈ %.0f ft high",
                        recommendation.mountingHeightMeters * 3.28084
                    )
                )
            }

            Text(
                "Marker 1 is the entrance. Place the remaining markers clockwise around the boundary, with one at every corner and extras along long edges. Label them \(markerPrefix)-01 through \(String(format: "%02d", recommendation.markerCount)). The operator scans them in that numbered order before capturing anything inside."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if recommendation.shouldSplitZone {
                Label(
                    "This footprint is large enough that it should be split into smaller scan zones before installing markers.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            }

            Label(
                "No printer yet? For a temporary recognition test, display each PDF page full-screen on a different fixed laptop, tablet, or spare phone. For a real zone, print at 100% actual size and tape each page flat somewhere permanent.",
                systemImage: "info.circle"
            )
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))
    }

    private func markerMetric(
        title: String,
        value: String,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.bold))
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
    }

    private func inches(_ centimeters: Int) -> Int {
        Int((Double(centimeters) / 2.54).rounded())
    }
}

private struct ZoneEditorContext: Identifiable {
    let id = UUID()
    let zone: WarehouseZone?
    let unit: MeasurementUnitPreference
}

private struct ZoneHistoryContext: Identifiable {
    let id = UUID()
    let zoneID: UUID
}

private struct ZoneAttachmentContext: Identifiable {
    let id = UUID()
    let zoneID: UUID
}

struct ZoneEditorResult {
    var name: String
    var kind: WarehouseZoneKind
    var widthMeters: Float
    var depthMeters: Float
    var heightMeters: Float
    var rotationDegrees: Float
}

private struct ZoneEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let context: ZoneEditorContext
    let onSave: (ZoneEditorResult) -> Void

    @State private var name: String
    @State private var kind: WarehouseZoneKind
    @State private var unit: MeasurementUnitPreference
    @State private var widthInput: Double
    @State private var lengthInput: Double
    @State private var heightInput: Double
    @State private var rotationDegrees: Float

    init(
        context: ZoneEditorContext,
        onSave: @escaping (ZoneEditorResult) -> Void
    ) {
        self.context = context
        self.onSave = onSave

        _name = State(initialValue: context.zone?.name ?? "")
        _kind = State(initialValue: context.zone?.kind ?? .aisle)
        let widthMeters = context.zone?.widthMeters ?? 6
        let lengthMeters = context.zone?.depthMeters ?? 12
        let heightMeters = context.zone?.heightMeters ?? 5
        _unit = State(initialValue: context.unit)
        _widthInput = State(
            initialValue: context.unit.displayValue(forMeters: widthMeters)
        )
        _lengthInput = State(
            initialValue: context.unit.displayValue(forMeters: lengthMeters)
        )
        _heightInput = State(
            initialValue: context.unit.displayValue(forMeters: heightMeters)
        )
        _rotationDegrees = State(
            initialValue: context.zone?.rotationDegrees ?? 0
        )
    }

    private var previewZone: WarehouseZone {
        WarehouseZone(
            id: context.zone?.id ?? context.id,
            name: name.isEmpty ? "New zone" : name,
            kind: kind,
            centerX: 0,
            centerZ: 0,
            widthMeters: unit.meters(fromDisplayValue: widthInput),
            depthMeters: unit.meters(fromDisplayValue: lengthInput),
            heightMeters: unit.meters(fromDisplayValue: heightInput),
            rotationDegrees: rotationDegrees
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Zone name", text: $name)

                    Picker("Zone type", selection: $kind) {
                        ForEach(WarehouseZoneKind.allCases) { kind in
                            Label(kind.title, systemImage: kind.symbol)
                                .tag(kind)
                        }
                    }
                }

                Section {
                    Picker("Measurement unit", selection: $unit) {
                        ForEach(MeasurementUnitPreference.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    measurementField(
                        title: "Zone width",
                        explanation: "The side-to-side distance across the area.",
                        value: $widthInput
                    )
                    measurementField(
                        title: "Zone length",
                        explanation: "The distance from the entrance marker to the far end.",
                        value: $lengthInput
                    )
                    measurementField(
                        title: "Highest scan point",
                        explanation: "The highest shelf, bin, or pallet the scan needs to capture.",
                        value: $heightInput
                    )

                    Stepper(
                        value: $rotationDegrees,
                        in: -180...180,
                        step: 15
                    ) {
                        LabeledContent(
                            "Map rotation",
                            value: String(
                                format: "%.0f°",
                                rotationDegrees
                            )
                        )
                    }

                    Text(
                        "Map rotation only changes how this zone faces on the warehouse overview. It does not change the scan itself."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("Enter the physical size")
                } footer: {
                    Text(
                        "These dimensions control the saved boundary. The numbered marker scan positions and rotates that full-size boundary in the room; it no longer replaces your width and length with the distance between marker readings."
                    )
                }

                Section("Recommended pilot setup") {
                    MarkerPlanCard(zone: previewZone)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(context.zone == nil ? "New zone" : "Edit zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            ZoneEditorResult(
                                name: name,
                                kind: kind,
                                widthMeters: max(
                                    0.6,
                                    unit.meters(
                                        fromDisplayValue: widthInput
                                    )
                                ),
                                depthMeters: max(
                                    0.6,
                                    unit.meters(
                                        fromDisplayValue: lengthInput
                                    )
                                ),
                                heightMeters: max(
                                    0.6,
                                    unit.meters(
                                        fromDisplayValue: heightInput
                                    )
                                ),
                                rotationDegrees: rotationDegrees
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: unit) { oldUnit, newUnit in
            widthInput = convert(
                widthInput,
                from: oldUnit,
                to: newUnit
            )
            lengthInput = convert(
                lengthInput,
                from: oldUnit,
                to: newUnit
            )
            heightInput = convert(
                heightInput,
                from: oldUnit,
                to: newUnit
            )
            warehouseStore.setMeasurementUnit(newUnit)
        }
        .preferredColorScheme(.dark)
    }

    @EnvironmentObject private var warehouseStore: WarehouseMapStore

    private func measurementField(
        title: String,
        explanation: String,
        value: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)

                Spacer()

                TextField(
                    "0",
                    value: value,
                    format: .number.precision(.fractionLength(0...1))
                )
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit().weight(.semibold))
                .frame(width: 84)

                Text(unit.shortSymbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .leading)
            }

            Text(explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func convert(
        _ value: Double,
        from oldUnit: MeasurementUnitPreference,
        to newUnit: MeasurementUnitPreference
    ) -> Double {
        let meters = oldUnit.meters(fromDisplayValue: value)
        return newUnit.displayValue(forMeters: meters)
    }
}

private struct ZoneHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var warehouseStore: WarehouseMapStore
    let zoneID: UUID

    @State private var selectedArchive: ScanArchive?
    @State private var errorMessage: String?

    private var zone: WarehouseZone? {
        warehouseStore.zone(id: zoneID)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let zone, !zone.scanRevisions.isEmpty {
                    List(
                        zone.scanRevisions.sorted {
                            $0.revisionNumber > $1.revisionNumber
                        }
                    ) { revision in
                        revisionRow(revision, zone: zone)
                    }
                } else {
                    ContentUnavailableView(
                        "No scan revisions",
                        systemImage: "clock.arrow.circlepath",
                        description: Text(
                            "The first zone scan will become revision 1."
                        )
                    )
                }
            }
            .navigationTitle(zone.map { "\($0.name) history" } ?? "Scan history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedArchive) { archive in
                SavedScanView(archive: archive)
            }
            .alert(
                "Unable to open revision",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func revisionRow(
        _ revision: ZoneScanRevision,
        zone: WarehouseZone
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Revision \(revision.revisionNumber)")
                        .font(.headline)

                    Text(
                        revision.capturedAt.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if zone.activeRevisionID == revision.id
                    || (
                        zone.activeRevisionID == nil
                            && zone.activeRevision?.id == revision.id
                    ) {
                    Text("ACTIVE")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.green.opacity(0.12), in: Capsule())
                }
            }

            HStack {
                Button("Open") {
                    open(revision)
                }
                .buttonStyle(.bordered)

                if zone.activeRevision?.id != revision.id {
                    Button("Make current") {
                        warehouseStore.activateRevision(
                            zoneID: zone.id,
                            revisionID: revision.id
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                }
            }
        }
        .padding(.vertical, 5)
    }

    private func open(_ revision: ZoneScanRevision) {
        do {
            selectedArchive = try ScanStore.load(id: revision.scanArchiveID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AttachSavedScanView: View {
    @Environment(\.dismiss) private var dismiss
    let zoneID: UUID
    let onAttach: (SavedScanSummary) -> Void

    @State private var scans: [SavedScanSummary] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if scans.isEmpty {
                    ContentUnavailableView(
                        "No saved scans",
                        systemImage: "archivebox",
                        description: Text(
                            "Complete a scan first, then attach it to this zone."
                        )
                    )
                } else {
                    List(scans) { scan in
                        Button {
                            onAttach(scan)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(
                                    scan.startedAt.formatted(
                                        date: .abbreviated,
                                        time: .shortened
                                    )
                                )
                                .font(.headline)

                                Text(
                                    "\(scan.meshCount) mesh sections · \(scan.distanceMeters, specifier: "%.1f") m path"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Attach saved scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                do {
                    scans = try ScanStore.list()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .alert(
                "Unable to load scans",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}
