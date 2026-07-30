import SceneKit
import SwiftUI

private enum SavedScanViewMode: String, CaseIterable, Identifiable {
    case inside = "Inside"
    case overview = "Model"

    var id: Self { self }
}

private enum ModelCameraTool: String, CaseIterable, Identifiable {
    case orbit = "Rotate"
    case move = "Move"

    var id: Self { self }

    var interactionMode: SCNInteractionMode {
        switch self {
        case .orbit:
            return .orbitTurntable
        case .move:
            return .pan
        }
    }
}

private enum ModelCameraPreset: String, CaseIterable, Identifiable {
    case reset = "Reset"
    case top = "Top"
    case front = "Front"
    case side = "Side"

    var id: Self { self }
}

private enum InsideCameraAction {
    case forward
    case backward
    case left
    case right
    case turnLeft
    case turnRight
    case reset
}

struct SavedScanView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var warehouseStore: WarehouseMapStore
    @EnvironmentObject private var barcodeCatalog: BarcodeCatalogStore
    let archive: ScanArchive

    @State private var viewMode: SavedScanViewMode = .overview
    @State private var modelCameraTool: ModelCameraTool = .orbit
    @State private var modelCameraPreset: ModelCameraPreset = .reset
    @State private var cameraPresetRequestID = UUID()
    @State private var insideCameraAction: InsideCameraAction = .reset
    @State private var insideCameraRequestID = UUID()
    @State private var insidePosition = SIMD2<Float>(0, 0)
    @State private var insideHeading: Float = 0
    @State private var rawScanOpacity = 0.78
    @State private var shareURL: URL?
    @State private var exportError: String?
    @State private var showingInventoryCodes = false
    @State private var detailBarcode: BarcodeObservation?
    @State private var focusedBarcodeID: UUID?
    @State private var focusRequestID = UUID()
    @State private var showWalls = true
    @State private var showFloor = true
    @State private var showCeiling = false

    init(
        archive: ScanArchive,
        initialFocusedBarcodeID: UUID? = nil
    ) {
        self.archive = archive
        _focusedBarcodeID = State(
            initialValue: initialFocusedBarcodeID
        )
        let initialTransform = archive.poses.first?
            .cameraTransform
            .simdValue ?? matrix_identity_float4x4
        _insidePosition = State(
            initialValue: SIMD2<Float>(
                initialTransform.position.x,
                initialTransform.position.z
            )
        )
        _insideHeading = State(
            initialValue: atan2(
                initialTransform.forward.x,
                initialTransform.forward.z
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                SavedScanSceneView(
                    archive: archive,
                    viewMode: viewMode,
                    rawScanOpacity: rawScanOpacity,
                    showWalls: showWalls,
                    showFloor: showFloor,
                    showCeiling: showCeiling,
                    focusedBarcodeID: focusedBarcodeID,
                    focusRequestID: focusRequestID,
                    modelCameraTool: modelCameraTool,
                    modelCameraPreset: modelCameraPreset,
                    cameraPresetRequestID: cameraPresetRequestID,
                    insideCameraAction: insideCameraAction,
                    insideCameraRequestID: insideCameraRequestID,
                    onInsideCameraUpdate: updateInsideCameraStatus,
                    onBarcodeTap: openBarcodeDetails
                )
                .ignoresSafeArea(edges: .bottom)

                if viewMode == .inside {
                    VStack {
                        HStack {
                            Spacer()
                            InsidePositionMiniMap(
                                poses: archive.poses,
                                currentPosition: insidePosition,
                                heading: insideHeading
                            )
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .allowsHitTesting(false)
                }

                controls
            }
            .navigationTitle(
                archive.startedAt.formatted(date: .abbreviated, time: .shortened)
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        exportScan()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Export scan")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
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
            .sheet(isPresented: $showingInventoryCodes) {
                BarcodeInventorySheet(
                    archive: archive,
                    zoneName: warehouseStore
                        .zone(containingScan: archive.id)?
                        .name ?? "Unassigned",
                    onLocate: locateBarcode
                )
            }
            .sheet(item: $detailBarcode) { observation in
                BarcodeDetailSheet(
                    observation: observation,
                    onLocate: {
                        locateBarcode(observation)
                    }
                )
            }
            .alert(
                "Unable to export scan",
                isPresented: Binding(
                    get: { exportError != nil },
                    set: { if !$0 { exportError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    exportError = nil
                }
            } message: {
                Text(exportError ?? "")
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("View", selection: $viewMode) {
                ForEach(SavedScanViewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if viewMode == .inside {
                insideNavigationControls
            } else {
                modelNavigationControls
            }

            HStack(spacing: 10) {
                Label("Raw scan detail", systemImage: "waveform.path.ecg")
                    .font(.caption.weight(.semibold))

                Slider(value: $rawScanOpacity, in: 0.15...1)

                Text("\(Int(rawScanOpacity * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
            }

            HStack {
                Menu {
                    Toggle("Show walls", isOn: $showWalls)
                    Toggle("Show floor", isOn: $showFloor)
                    Toggle("Show ceiling", isOn: $showCeiling)

                    Divider()

                    Button {
                        showWalls = false
                        showFloor = false
                        showCeiling = false
                    } label: {
                        Label(
                            "Stuff only",
                            systemImage: "shippingbox.fill"
                        )
                    }

                    Button {
                        showWalls = true
                        showFloor = true
                        showCeiling = false
                    } label: {
                        Label(
                            "Reset layers",
                            systemImage: "arrow.counterclockwise"
                        )
                    }
                } label: {
                    Label(
                        "Visible layers",
                        systemImage: "square.3.layers.3d"
                    )
                }
                .buttonStyle(.bordered)

                Spacer()

                if !showWalls && !showFloor && !showCeiling {
                    Text("STUFF ONLY")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                }
            }

            Text(
                "\(archive.meshes.count) mesh sections · \(archive.detectedBarcodes.count) code locations · \(archive.distanceMeters, specifier: "%.1f") m"
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            if !archive.detectedBarcodes.isEmpty {
                Button {
                    showingInventoryCodes = true
                } label: {
                    Label(
                        "Open captured codes",
                        systemImage: "barcode.viewfinder"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    private var modelNavigationControls: some View {
        VStack(alignment: .leading, spacing: 9) {
            Picker("Model camera control", selection: $modelCameraTool) {
                ForEach(ModelCameraTool.allCases) { tool in
                    Text(tool.rawValue).tag(tool)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 7) {
                ForEach(ModelCameraPreset.allCases) { preset in
                    Button(preset.rawValue) {
                        modelCameraPreset = preset
                        cameraPresetRequestID = UUID()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                }
            }

            Text(
                modelCameraTool == .orbit
                    ? "Drag to rotate · Pinch to zoom · Switch to Move to reposition the model"
                    : "Drag with one finger to reposition · Pinch to zoom · Use Top, Front, or Side whenever orientation feels unclear"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
    }

    private var insideNavigationControls: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                insideControlButton(
                    "Turn left",
                    systemImage: "arrow.counterclockwise",
                    action: .turnLeft
                )
                insideControlButton(
                    "Forward",
                    systemImage: "arrow.up",
                    action: .forward
                )
                insideControlButton(
                    "Turn right",
                    systemImage: "arrow.clockwise",
                    action: .turnRight
                )
            }

            HStack(spacing: 8) {
                insideControlButton(
                    "Left",
                    systemImage: "arrow.left",
                    action: .left
                )
                insideControlButton(
                    "Back",
                    systemImage: "arrow.down",
                    action: .backward
                )
                insideControlButton(
                    "Right",
                    systemImage: "arrow.right",
                    action: .right
                )
                insideControlButton(
                    "Start",
                    systemImage: "location.fill",
                    action: .reset
                )
            }

            Text(
                "Fixed eye height · Drag the scene to look around · Use the map marker to keep your orientation"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
    }

    private func insideControlButton(
        _ title: String,
        systemImage: String,
        action: InsideCameraAction
    ) -> some View {
        Button {
            insideCameraAction = action
            insideCameraRequestID = UUID()
        } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(title)
    }

    private func updateInsideCameraStatus(
        position: SIMD2<Float>,
        heading: Float
    ) {
        insidePosition = position
        insideHeading = heading
    }

    private func exportScan() {
        do {
            let zoneName = warehouseStore
                .zone(containingScan: archive.id)?
                .name ?? "Unassigned"
            shareURL = try ScanStore.exportURL(
                id: archive.id,
                suggestedName: "\(zoneName)-Scan"
            )
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func openBarcodeDetails(_ id: UUID) {
        detailBarcode = archive.detectedBarcodes.first {
            $0.id == id
        }
    }

    private func locateBarcode(_ observation: BarcodeObservation) {
        detailBarcode = nil
        showingInventoryCodes = false
        viewMode = .overview
        focusedBarcodeID = observation.id
        focusRequestID = UUID()
    }
}

private struct BarcodeDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var barcodeCatalog: BarcodeCatalogStore
    let observation: BarcodeObservation
    let onLocate: () -> Void

    @State private var productName = ""
    @State private var sku = ""
    @State private var notes = ""
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Recognized code") {
                    LabeledContent("Value") {
                        Text(observation.payload)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }

                    LabeledContent(
                        "Format",
                        value: observation.symbology
                    )

                    LabeledContent(
                        "Location quality",
                        value: observation.positionSource.title
                    )
                }

                Section {
                    TextField(
                        "Product or item name",
                        text: $productName
                    )
                    TextField(
                        "SKU / warehouse reference",
                        text: $sku
                    )
                    TextField(
                        "Description, bin, or notes",
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(2...6)
                } header: {
                    Text("What is this?")
                } footer: {
                    Text(
                        "This local catalog is shared across scans, so the same barcode keeps this name and SKU. A future inventory import can fill these fields automatically."
                    )
                }

                Section("3D position") {
                    let position = observation.worldPosition
                    LabeledContent(
                        "X",
                        value: String(format: "%.2f m", position.x)
                    )
                    LabeledContent(
                        "Y",
                        value: String(format: "%.2f m", position.y)
                    )
                    LabeledContent(
                        "Z",
                        value: String(format: "%.2f m", position.z)
                    )
                    LabeledContent(
                        "Confirmations",
                        value: "\(observation.seenCount)"
                    )
                }

                Section {
                    Button {
                        save()
                        onLocate()
                        dismiss()
                    } label: {
                        Label(
                            "Show location in model",
                            systemImage: "scope"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
            .navigationTitle(
                productName.isEmpty
                    ? "Barcode details"
                    : productName
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadRecordOnce()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func loadRecordOnce() {
        guard !didLoad else {
            return
        }
        didLoad = true
        guard let record = barcodeCatalog.record(
            for: observation.payload
        ) else {
            return
        }
        productName = record.name
        sku = record.sku
        notes = record.notes
    }

    private func save() {
        barcodeCatalog.save(
            barcode: observation.payload,
            name: productName,
            sku: sku,
            notes: notes
        )
    }
}

private struct BarcodeInventorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var barcodeCatalog: BarcodeCatalogStore
    let archive: ScanArchive
    let zoneName: String
    let onLocate: (BarcodeObservation) -> Void

    @State private var searchText = ""
    @State private var shareURL: URL?
    @State private var exportError: String?
    @State private var detailObservation: BarcodeObservation?

    private var filteredObservations: [BarcodeObservation] {
        guard !searchText.isEmpty else {
            return archive.detectedBarcodes
        }
        return archive.detectedBarcodes.filter {
            let record = barcodeCatalog.record(for: $0.payload)
            return $0.payload.localizedCaseInsensitiveContains(searchText)
                || $0.symbology.localizedCaseInsensitiveContains(searchText)
                || record?.name.localizedCaseInsensitiveContains(searchText)
                    == true
                || record?.sku.localizedCaseInsensitiveContains(searchText)
                    == true
                || record?.notes.localizedCaseInsensitiveContains(searchText)
                    == true
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredObservations.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(filteredObservations) { observation in
                        HStack(spacing: 10) {
                            Button {
                                onLocate(observation)
                                dismiss()
                            } label: {
                                barcodeSearchRow(observation)
                            }
                            .buttonStyle(.plain)

                            Menu {
                                Button {
                                    UIPasteboard.general.string =
                                        observation.payload
                                } label: {
                                    Label(
                                        "Copy code",
                                        systemImage: "doc.on.doc"
                                    )
                                }

                                Button {
                                    detailObservation = observation
                                } label: {
                                    Label(
                                        "Item details",
                                        systemImage: "info.circle"
                                    )
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Find an item")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                prompt: "Product, SKU, or barcode"
            )
            .safeAreaInset(edge: .bottom) {
                Text(
                    "Tap a result to focus its green pin in the 3D model."
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(.ultraThinMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        exportCSV()
                    } label: {
                        Label(
                            "Export CSV",
                            systemImage: "tablecells"
                        )
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $detailObservation) { observation in
                BarcodeDetailSheet(
                    observation: observation,
                    onLocate: {
                        detailObservation = nil
                        onLocate(observation)
                        dismiss()
                    }
                )
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
            .alert(
                "Unable to export codes",
                isPresented: Binding(
                    get: { exportError != nil },
                    set: { if !$0 { exportError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    exportError = nil
                }
            } message: {
                Text(exportError ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func exportCSV() {
        do {
            shareURL = try ScanStore.exportBarcodesCSV(
                archive: archive,
                zoneName: zoneName,
                catalog: barcodeCatalog.records
            )
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func barcodeSearchRow(
        _ observation: BarcodeObservation
    ) -> some View {
        let record = barcodeCatalog.record(for: observation.payload)
        return HStack(spacing: 12) {
            Image(systemName: "location.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text(barcodeCatalog.displayName(for: observation.payload))
                    .font(.headline)

                if let sku = record?.sku, !sku.isEmpty {
                    Text("SKU \(sku)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.cyan)
                }

                Text(observation.payload)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Image(systemName: "scope")
                .foregroundStyle(.green)
        }
        .contentShape(Rectangle())
    }
}

private struct InsidePositionMiniMap: View {
    let poses: [PoseSample]
    let currentPosition: SIMD2<Float>
    let heading: Float

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("INSIDE POSITION")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            Canvas { context, size in
                guard poses.count > 1 else {
                    return
                }

                let points = poses.map { pose in
                    let position = pose.cameraTransform.position
                    return SIMD2<Float>(position.x, position.z)
                }

                let framedPoints = points + [currentPosition]
                let minX = framedPoints.map(\.x).min() ?? 0
                let maxX = framedPoints.map(\.x).max() ?? 1
                let minY = framedPoints.map(\.y).min() ?? 0
                let maxY = framedPoints.map(\.y).max() ?? 1
                let rangeX = max(0.5, maxX - minX)
                let rangeY = max(0.5, maxY - minY)
                let inset: CGFloat = 9

                func mapPoint(_ point: SIMD2<Float>) -> CGPoint {
                    let normalizedX = CGFloat((point.x - minX) / rangeX)
                    let normalizedY = CGFloat((point.y - minY) / rangeY)
                    return CGPoint(
                        x: inset + normalizedX * (size.width - inset * 2),
                        y: inset + normalizedY * (size.height - inset * 2)
                    )
                }

                var path = Path()
                path.move(to: mapPoint(points[0]))
                for point in points.dropFirst() {
                    path.addLine(to: mapPoint(point))
                }
                context.stroke(
                    path,
                    with: .color(.white.opacity(0.46)),
                    lineWidth: 2
                )

                let start = mapPoint(points[0])
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: start.x - 4,
                        y: start.y - 4,
                        width: 8,
                        height: 8
                    )),
                    with: .color(.green)
                )

                let current = mapPoint(currentPosition)
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: current.x - 6,
                        y: current.y - 6,
                        width: 12,
                        height: 12
                    )),
                    with: .color(.cyan)
                )

                let headingEnd = CGPoint(
                    x: current.x + CGFloat(sin(heading)) * 17,
                    y: current.y + CGFloat(cos(heading)) * 17
                )
                var headingPath = Path()
                headingPath.move(to: current)
                headingPath.addLine(to: headingEnd)
                context.stroke(
                    headingPath,
                    with: .color(.cyan),
                    style: StrokeStyle(
                        lineWidth: 3,
                        lineCap: .round
                    )
                )
            }
            .frame(width: 116, height: 96)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct SavedScanSceneView: UIViewRepresentable {
    let archive: ScanArchive
    let viewMode: SavedScanViewMode
    let rawScanOpacity: Double
    let showWalls: Bool
    let showFloor: Bool
    let showCeiling: Bool
    let focusedBarcodeID: UUID?
    let focusRequestID: UUID
    let modelCameraTool: ModelCameraTool
    let modelCameraPreset: ModelCameraPreset
    let cameraPresetRequestID: UUID
    let insideCameraAction: InsideCameraAction
    let insideCameraRequestID: UUID
    let onInsideCameraUpdate: (SIMD2<Float>, Float) -> Void
    let onBarcodeTap: (UUID) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        let scene = SCNScene()

        view.scene = scene
        view.backgroundColor = .black
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X

        addMesh(to: scene)
        addMovementTrail(to: scene)
        addBarcodePins(to: scene)
        addCleanZoneShell(to: scene)
        addLighting(to: scene)
        addCameras(to: scene)
        updateCamera(
            in: view,
            animated: false,
            focusBarcodeID: focusedBarcodeID,
            selectPointOfView: true
        )
        configureModelCamera(in: view, resetTarget: true)

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tap)

        let insideLook = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleInsideLook(_:))
        )
        insideLook.maximumNumberOfTouches = 1
        insideLook.isEnabled = viewMode == .inside
        view.addGestureRecognizer(insideLook)
        context.coordinator.insideLookGesture = insideLook
        context.coordinator.syncInsideOrientation(from: scene)

        context.coordinator.lastFocusRequestID = focusRequestID
        context.coordinator.lastCameraPresetRequestID =
            cameraPresetRequestID
        context.coordinator.lastInsideCameraRequestID =
            insideCameraRequestID
        context.coordinator.lastViewMode = viewMode

        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.parent = self
        let didChangeViewMode =
            context.coordinator.lastViewMode != viewMode
        let shouldFocus =
            context.coordinator.lastFocusRequestID != focusRequestID
        updateCamera(
            in: view,
            animated: true,
            focusBarcodeID: shouldFocus ? focusedBarcodeID : nil,
            selectPointOfView: didChangeViewMode || shouldFocus
        )
        configureModelCamera(
            in: view,
            resetTarget: didChangeViewMode || shouldFocus
        )
        let shouldApplyPreset =
            context.coordinator.lastCameraPresetRequestID
            != cameraPresetRequestID
        if shouldApplyPreset {
            applyModelCameraPreset(in: view, animated: true)
        }
        let shouldMoveInsideCamera =
            context.coordinator.lastInsideCameraRequestID
            != insideCameraRequestID
        if shouldMoveInsideCamera {
            applyInsideCameraAction(
                insideCameraAction,
                in: view,
                animated: true
            )
            context.coordinator.syncInsideOrientation(
                from: view.scene
            )
        }
        context.coordinator.insideLookGesture?.isEnabled =
            viewMode == .inside
        if didChangeViewMode, viewMode == .inside,
           let camera = view.scene?.rootNode.childNode(
            withName: "inside-camera",
            recursively: true
           ) {
            reportInsideCamera(camera)
        }
        context.coordinator.lastFocusRequestID = focusRequestID
        context.coordinator.lastCameraPresetRequestID =
            cameraPresetRequestID
        context.coordinator.lastInsideCameraRequestID =
            insideCameraRequestID
        context.coordinator.lastViewMode = viewMode
    }

    final class Coordinator: NSObject {
        var parent: SavedScanSceneView
        var lastFocusRequestID: UUID?
        var lastCameraPresetRequestID: UUID?
        var lastInsideCameraRequestID: UUID?
        var lastViewMode: SavedScanViewMode?
        weak var insideLookGesture: UIPanGestureRecognizer?
        private var previousLookTranslation = CGPoint.zero
        private var insideYaw: Float = 0
        private var insidePitch: Float = 0

        init(parent: SavedScanSceneView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? SCNView else {
                return
            }

            let point = gesture.location(in: view)
            for result in view.hitTest(point, options: nil) {
                var candidate: SCNNode? = result.node
                while let node = candidate {
                    if let name = node.name,
                       name.hasPrefix("saved-barcode-"),
                       let id = UUID(
                        uuidString: String(
                            name.dropFirst("saved-barcode-".count)
                        )
                       ) {
                        parent.onBarcodeTap(id)
                        return
                    }
                    candidate = node.parent
                }
            }
        }

        @objc func handleInsideLook(_ gesture: UIPanGestureRecognizer) {
            guard parent.viewMode == .inside,
                  let view = gesture.view as? SCNView,
                  let camera = view.scene?.rootNode.childNode(
                    withName: "inside-camera",
                    recursively: true
                  ) else {
                return
            }

            let translation = gesture.translation(in: view)
            switch gesture.state {
            case .began:
                previousLookTranslation = translation

            case .changed:
                let deltaX = translation.x
                    - previousLookTranslation.x
                let deltaY = translation.y
                    - previousLookTranslation.y
                previousLookTranslation = translation

                insideYaw -= Float(deltaX) * 0.006
                insidePitch = min(
                    1.05,
                    max(-1.05, insidePitch - Float(deltaY) * 0.004)
                )
                camera.eulerAngles = SCNVector3(
                    insidePitch,
                    insideYaw,
                    0
                )
                parent.reportInsideCamera(camera)

            default:
                previousLookTranslation = .zero
            }
        }

        func syncInsideOrientation(from scene: SCNScene?) {
            guard let camera = scene?.rootNode.childNode(
                withName: "inside-camera",
                recursively: true
            ) else {
                return
            }
            insideYaw = camera.eulerAngles.y
            insidePitch = camera.eulerAngles.x
        }
    }

    private func addMesh(to scene: SCNScene) {
        for snapshot in archive.meshes {
            let node = SCNNode(geometry: SCNGeometry.savedMesh(from: snapshot))
            node.name = "saved-raw-mesh-\(snapshot.id.uuidString)"
            node.simdTransform = snapshot.transform.simdValue
            scene.rootNode.addChildNode(node)
        }
    }

    private func addMovementTrail(to scene: SCNScene) {
        let trailRoot = SCNNode()
        trailRoot.name = "movement-trail"

        let step = max(1, archive.poses.count / 350)

        for index in stride(from: 0, to: archive.poses.count, by: step) {
            let sphere = SCNSphere(radius: 0.025)
            sphere.segmentCount = 8

            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemOrange
            material.emission.contents = UIColor.systemOrange.withAlphaComponent(0.25)
            sphere.materials = [material]

            let node = SCNNode(geometry: sphere)
            node.simdPosition = archive.poses[index].cameraTransform.position
            trailRoot.addChildNode(node)
        }

        scene.rootNode.addChildNode(trailRoot)
    }

    private func addBarcodePins(to scene: SCNScene) {
        for (index, observation) in archive.detectedBarcodes.enumerated() {
            let root = SCNNode()
            root.name = "saved-barcode-\(observation.id.uuidString)"
            root.simdPosition = observation.worldPosition.simdValue

            let marker = SCNTorus(
                ringRadius: 0.085,
                pipeRadius: 0.017
            )
            marker.ringSegmentCount = 20
            marker.pipeSegmentCount = 8
            let markerMaterial = SCNMaterial()
            markerMaterial.diffuse.contents = UIColor.systemGreen
            markerMaterial.emission.contents =
                UIColor.systemGreen.withAlphaComponent(0.55)
            marker.materials = [markerMaterial]
            root.addChildNode(SCNNode(geometry: marker))

            let tapTarget = SCNSphere(radius: 0.18)
            let tapMaterial = SCNMaterial()
            tapMaterial.transparency = 0.001
            tapMaterial.writesToDepthBuffer = false
            tapTarget.materials = [tapMaterial]
            root.addChildNode(SCNNode(geometry: tapTarget))

            let label = SCNText(
                string: "\(index + 1)",
                extrusionDepth: 0.02
            )
            label.font = UIFont.monospacedSystemFont(
                ofSize: 1,
                weight: .bold
            )
            label.flatness = 0.15
            let labelMaterial = SCNMaterial()
            labelMaterial.diffuse.contents = UIColor.white
            labelMaterial.emission.contents =
                UIColor.white.withAlphaComponent(0.45)
            label.materials = [labelMaterial]

            let labelNode = SCNNode(geometry: label)
            labelNode.scale = SCNVector3(0.09, 0.09, 0.09)
            labelNode.position = SCNVector3(-0.03, 0.12, 0)
            labelNode.constraints = [SCNBillboardConstraint()]
            root.addChildNode(labelNode)
            scene.rootNode.addChildNode(root)
        }
    }

    private func addCleanZoneShell(to scene: SCNScene) {
        let bounds = scene.rootNode.boundingBox
        let minimum = bounds.min
        let maximum = bounds.max

        guard minimum.x.isFinite,
              minimum.y.isFinite,
              minimum.z.isFinite,
              maximum.x.isFinite,
              maximum.y.isFinite,
              maximum.z.isFinite else {
            return
        }

        let padding: Float = 0.25
        let minX = minimum.x - padding
        let maxX = maximum.x + padding
        let minZ = minimum.z - padding
        let maxZ = maximum.z + padding
        let floorY = minimum.y - 0.012
        let width = max(1, maxX - minX)
        let depth = max(1, maxZ - minZ)
        let centerX = (minX + maxX) / 2
        let centerZ = (minZ + maxZ) / 2

        let shellRoot = SCNNode()
        shellRoot.name = "clean-zone-shell"

        let floorPlane = SCNPlane(width: CGFloat(width), height: CGFloat(depth))
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = UIColor(white: 0.075, alpha: 1)
        floorMaterial.roughness.contents = 1
        floorMaterial.isDoubleSided = true
        floorPlane.materials = [floorMaterial]

        let floorNode = SCNNode(geometry: floorPlane)
        floorNode.name = "clean-zone-floor"
        floorNode.position = SCNVector3(centerX, floorY, centerZ)
        floorNode.eulerAngles.x = -.pi / 2
        shellRoot.addChildNode(floorNode)

        let spacing: Float = max(width, depth) > 35 ? 2 : 1
        var gridVertices: [SCNVector3] = []

        var x = (minX / spacing).rounded(.down) * spacing
        while x <= maxX {
            gridVertices.append(SCNVector3(x, floorY + 0.006, minZ))
            gridVertices.append(SCNVector3(x, floorY + 0.006, maxZ))
            x += spacing
        }

        var z = (minZ / spacing).rounded(.down) * spacing
        while z <= maxZ {
            gridVertices.append(SCNVector3(minX, floorY + 0.006, z))
            gridVertices.append(SCNVector3(maxX, floorY + 0.006, z))
            z += spacing
        }

        if let gridNode = lineNode(
            vertices: gridVertices,
            color: UIColor.white.withAlphaComponent(0.13)
        ) {
            gridNode.name = "clean-zone-grid"
            shellRoot.addChildNode(gridNode)
        }

        let perimeter = [
            SCNVector3(minX, floorY + 0.012, minZ),
            SCNVector3(maxX, floorY + 0.012, minZ),
            SCNVector3(maxX, floorY + 0.012, minZ),
            SCNVector3(maxX, floorY + 0.012, maxZ),
            SCNVector3(maxX, floorY + 0.012, maxZ),
            SCNVector3(minX, floorY + 0.012, maxZ),
            SCNVector3(minX, floorY + 0.012, maxZ),
            SCNVector3(minX, floorY + 0.012, minZ)
        ]

        if let perimeterNode = lineNode(
            vertices: perimeter,
            color: UIColor.systemCyan.withAlphaComponent(0.72)
        ) {
            perimeterNode.name = "clean-zone-boundary"
            shellRoot.addChildNode(perimeterNode)
        }

        if let start = archive.poses.first?.cameraTransform.position {
            let marker = SCNTorus(ringRadius: 0.18, pipeRadius: 0.018)
            let markerMaterial = SCNMaterial()
            markerMaterial.diffuse.contents = UIColor.systemCyan
            markerMaterial.emission.contents = UIColor.systemCyan.withAlphaComponent(0.35)
            marker.materials = [markerMaterial]

            let markerNode = SCNNode(geometry: marker)
            markerNode.name = "scan-start-marker"
            markerNode.simdPosition = SIMD3<Float>(start.x, floorY + 0.025, start.z)
            shellRoot.addChildNode(markerNode)
        }

        scene.rootNode.addChildNode(shellRoot)
    }

    private func lineNode(
        vertices: [SCNVector3],
        color: UIColor
    ) -> SCNNode? {
        guard vertices.count >= 2, vertices.count.isMultiple(of: 2) else {
            return nil
        }

        let indices = (0..<UInt32(vertices.count)).map { $0 }
        let indexData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .line,
            primitiveCount: indices.count / 2,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )

        let geometry = SCNGeometry(sources: [source], elements: [element])
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color
        material.isDoubleSided = true
        geometry.materials = [material]
        return SCNNode(geometry: geometry)
    }

    private func addLighting(to scene: SCNScene) {
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 550
        ambientLight.color = UIColor(white: 0.78, alpha: 1)

        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 900

        let directionalNode = SCNNode()
        directionalNode.light = directionalLight
        directionalNode.eulerAngles = SCNVector3(-0.8, 0.6, 0)
        scene.rootNode.addChildNode(directionalNode)
    }

    private func addCameras(to scene: SCNScene) {
        let bounds = scene.rootNode.boundingBox
        let minimum = bounds.min
        let maximum = bounds.max

        let center = SCNVector3(
            (minimum.x + maximum.x) / 2,
            (minimum.y + maximum.y) / 2,
            (minimum.z + maximum.z) / 2
        )

        let span = max(
            2,
            max(
                maximum.x - minimum.x,
                max(maximum.y - minimum.y, maximum.z - minimum.z)
            )
        )

        let targetNode = SCNNode()
        targetNode.name = "overview-target"
        targetNode.position = center
        scene.rootNode.addChildNode(targetNode)

        let homeTargetNode = SCNNode()
        homeTargetNode.name = "overview-home-target"
        homeTargetNode.position = center
        scene.rootNode.addChildNode(homeTargetNode)

        let overviewCamera = SCNCamera()
        overviewCamera.zNear = 0.01
        overviewCamera.zFar = Double(max(100, span * 15))

        let overviewNode = SCNNode()
        overviewNode.name = "overview-camera"
        overviewNode.camera = overviewCamera
        overviewNode.position = SCNVector3(
            center.x + span * 1.4,
            center.y + span * 1.1,
            center.z + span * 1.4
        )

        let overviewConstraint = SCNLookAtConstraint(target: targetNode)
        overviewConstraint.isGimbalLockEnabled = true
        overviewNode.constraints = [overviewConstraint]
        scene.rootNode.addChildNode(overviewNode)

        let homeCameraNode = SCNNode()
        homeCameraNode.name = "overview-home-camera"
        homeCameraNode.position = overviewNode.position
        scene.rootNode.addChildNode(homeCameraNode)

        let insideCamera = SCNCamera()
        insideCamera.fieldOfView = 68
        insideCamera.zNear = 0.01
        insideCamera.zFar = Double(max(100, span * 15))

        let firstTransform = archive.poses.first?
            .cameraTransform
            .simdValue ?? matrix_identity_float4x4
        let firstPosition = firstTransform.position
        let firstForward = firstTransform.forward
        let eyeHeight = minimum.y + 1.62
        let startPosition = SIMD3<Float>(
            min(max(firstPosition.x, minimum.x + 0.1), maximum.x - 0.1),
            eyeHeight,
            min(max(firstPosition.z, minimum.z + 0.1), maximum.z - 0.1)
        )
        let startYaw = atan2(-firstForward.x, -firstForward.z)

        let insideNode = SCNNode()
        insideNode.name = "inside-camera"
        insideNode.camera = insideCamera
        insideNode.simdPosition = startPosition
        insideNode.eulerAngles = SCNVector3(0, startYaw, 0)
        scene.rootNode.addChildNode(insideNode)

        let insideHomeNode = SCNNode()
        insideHomeNode.name = "inside-home"
        insideHomeNode.simdPosition = startPosition
        insideHomeNode.eulerAngles = insideNode.eulerAngles
        scene.rootNode.addChildNode(insideHomeNode)

        let insideMinimumNode = SCNNode()
        insideMinimumNode.name = "inside-bounds-minimum"
        insideMinimumNode.position = minimum
        scene.rootNode.addChildNode(insideMinimumNode)

        let insideMaximumNode = SCNNode()
        insideMaximumNode.name = "inside-bounds-maximum"
        insideMaximumNode.position = maximum
        scene.rootNode.addChildNode(insideMaximumNode)
    }

    private func updateCamera(
        in view: SCNView,
        animated: Bool,
        focusBarcodeID: UUID?,
        selectPointOfView: Bool
    ) {
        guard let scene = view.scene else {
            return
        }

        let trail = scene.rootNode.childNode(
            withName: "movement-trail",
            recursively: true
        )
        trail?.isHidden = viewMode == .inside
        updateRawMeshAppearance(in: scene)

        switch viewMode {
        case .inside:
            guard let camera = scene.rootNode.childNode(
                withName: "inside-camera",
                recursively: true
            ) else {
                return
            }

            if selectPointOfView {
                view.allowsCameraControl = false
                view.pointOfView = camera
            }

        case .overview:
            guard let camera = scene.rootNode.childNode(
                withName: "overview-camera",
                recursively: true
            ) else {
                return
            }

            if selectPointOfView {
                view.allowsCameraControl = true
                view.pointOfView = camera
            }

            if let focusBarcodeID,
               let observation = archive.detectedBarcodes.first(
                where: { $0.id == focusBarcodeID }
               ),
               let target = scene.rootNode.childNode(
                withName: "overview-target",
                recursively: true
               ) {
                let position = observation.worldPosition.simdValue

                SCNTransaction.begin()
                SCNTransaction.animationDuration = animated ? 0.5 : 0
                target.simdPosition = position
                camera.simdPosition = position + SIMD3<Float>(
                    1.4,
                    0.9,
                    1.4
                )
                SCNTransaction.commit()
                updateFocusPath(
                    in: scene,
                    observation: observation
                )
            }
        }
    }

    private func applyInsideCameraAction(
        _ action: InsideCameraAction,
        in view: SCNView,
        animated: Bool
    ) {
        guard viewMode == .inside,
              let scene = view.scene,
              let camera = scene.rootNode.childNode(
                withName: "inside-camera",
                recursively: true
              ),
              let home = scene.rootNode.childNode(
                withName: "inside-home",
                recursively: true
              ),
              let minimum = scene.rootNode.childNode(
                withName: "inside-bounds-minimum",
                recursively: true
              ),
              let maximum = scene.rootNode.childNode(
                withName: "inside-bounds-maximum",
                recursively: true
              ) else {
            return
        }

        var nextPosition = camera.simdPosition
        var nextAngles = camera.eulerAngles
        let movementStep: Float = 0.65
        let turnStep: Float = .pi / 12

        let transform = camera.presentation.simdWorldTransform
        var forward = -SIMD3<Float>(
            transform.columns.2.x,
            0,
            transform.columns.2.z
        )
        var right = SIMD3<Float>(
            transform.columns.0.x,
            0,
            transform.columns.0.z
        )
        if simd_length(forward) > 0.001 {
            forward = simd_normalize(forward)
        }
        if simd_length(right) > 0.001 {
            right = simd_normalize(right)
        }

        switch action {
        case .forward:
            nextPosition += forward * movementStep
        case .backward:
            nextPosition -= forward * movementStep
        case .left:
            nextPosition -= right * movementStep
        case .right:
            nextPosition += right * movementStep
        case .turnLeft:
            nextAngles.y += turnStep
        case .turnRight:
            nextAngles.y -= turnStep
        case .reset:
            nextPosition = home.simdPosition
            nextAngles = home.eulerAngles
        }

        let margin: Float = 0.08
        let minX = minimum.simdPosition.x + margin
        let maxX = maximum.simdPosition.x - margin
        let minZ = minimum.simdPosition.z + margin
        let maxZ = maximum.simdPosition.z - margin
        if minX <= maxX {
            nextPosition.x = min(max(nextPosition.x, minX), maxX)
        }
        if minZ <= maxZ {
            nextPosition.z = min(max(nextPosition.z, minZ), maxZ)
        }
        nextPosition.y = home.simdPosition.y

        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.16 : 0
        camera.simdPosition = nextPosition
        camera.eulerAngles = nextAngles
        SCNTransaction.commit()
        reportInsideCamera(camera)
    }

    private func reportInsideCamera(_ camera: SCNNode) {
        let transform = camera.presentation.simdWorldTransform
        let position = SIMD2<Float>(
            camera.simdPosition.x,
            camera.simdPosition.z
        )
        let forward = -SIMD3<Float>(
            transform.columns.2.x,
            0,
            transform.columns.2.z
        )
        let heading = atan2(forward.x, forward.z)

        DispatchQueue.main.async {
            onInsideCameraUpdate(position, heading)
        }
    }

    private func configureModelCamera(
        in view: SCNView,
        resetTarget: Bool
    ) {
        guard viewMode == .overview,
              let scene = view.scene else {
            return
        }

        let controller = view.defaultCameraController
        controller.interactionMode = modelCameraTool.interactionMode
        controller.inertiaEnabled = modelCameraTool == .orbit
        controller.inertiaFriction = 0.08
        controller.automaticTarget = false
        controller.worldUp = SCNVector3(0, 1, 0)

        if resetTarget,
           let target = scene.rootNode.childNode(
            withName: "overview-target",
            recursively: true
           ) {
            controller.target = target.presentation.position
        }
    }

    private func applyModelCameraPreset(
        in view: SCNView,
        animated: Bool
    ) {
        guard viewMode == .overview,
              let scene = view.scene,
              let camera = scene.rootNode.childNode(
                withName: "overview-camera",
                recursively: true
              ),
              let target = scene.rootNode.childNode(
                withName: "overview-target",
                recursively: true
              ),
              let homeCamera = scene.rootNode.childNode(
                withName: "overview-home-camera",
                recursively: true
              ),
              let homeTarget = scene.rootNode.childNode(
                withName: "overview-home-target",
                recursively: true
              ) else {
            return
        }

        let center = homeTarget.simdPosition
        let homePosition = homeCamera.simdPosition
        let viewingDistance = max(
            2,
            simd_distance(homePosition, center)
        )
        let nextPosition: SIMD3<Float>

        switch modelCameraPreset {
        case .reset:
            nextPosition = homePosition
        case .top:
            nextPosition = center + SIMD3<Float>(
                0,
                viewingDistance,
                0.001
            )
        case .front:
            nextPosition = center + SIMD3<Float>(
                0,
                viewingDistance * 0.16,
                viewingDistance
            )
        case .side:
            nextPosition = center + SIMD3<Float>(
                viewingDistance,
                viewingDistance * 0.16,
                0
            )
        }

        view.defaultCameraController.stopInertia()
        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.35 : 0
        target.simdPosition = center
        camera.simdPosition = nextPosition
        SCNTransaction.commit()

        view.pointOfView = camera
        view.defaultCameraController.pointOfView = camera
        view.defaultCameraController.target = SCNVector3(center)
    }

    private func updateFocusPath(
        in scene: SCNScene,
        observation: BarcodeObservation
    ) {
        scene.rootNode.childNode(
            withName: "barcode-focus-path",
            recursively: true
        )?.removeFromParentNode()

        guard let start = archive.poses.first?
            .cameraTransform
            .position else {
            return
        }
        let end = observation.worldPosition.simdValue
        let raisedStart = SCNVector3(start.x, start.y + 0.06, start.z)
        let raisedEnd = SCNVector3(end.x, end.y + 0.06, end.z)
        if let route = lineNode(
            vertices: [raisedStart, raisedEnd],
            color: UIColor.systemGreen
        ) {
            route.name = "barcode-focus-path"
            scene.rootNode.addChildNode(route)
        }
    }

    private func updateRawMeshAppearance(in scene: SCNScene) {
        scene.rootNode.childNode(
            withName: "clean-zone-floor",
            recursively: true
        )?.isHidden = !showFloor
        scene.rootNode.childNode(
            withName: "clean-zone-grid",
            recursively: true
        )?.isHidden = !showFloor

        scene.rootNode.enumerateChildNodes { node, _ in
            guard node.name?.hasPrefix("saved-raw-mesh-") == true else {
                return
            }

            node.opacity = CGFloat(rawScanOpacity)

            for material in node.geometry?.materials ?? [] {
                let floorName =
                    "warehouse-surface-\(WarehouseSurfaceStyle.floor.rawValue)"
                let wallName =
                    "warehouse-surface-\(WarehouseSurfaceStyle.wall.rawValue)"
                let ceilingName = "warehouse-surface-\(WarehouseSurfaceStyle.ceiling.rawValue)"
                let isVisible: Bool
                switch material.name {
                case floorName:
                    isVisible = showFloor
                case wallName:
                    isVisible = showWalls
                case ceilingName:
                    isVisible = showCeiling
                default:
                    isVisible = true
                }
                material.transparency = isVisible ? 1 : 0
                material.writesToDepthBuffer = isVisible
            }
        }
    }
}
