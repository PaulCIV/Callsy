import SwiftUI

struct InventorySearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var warehouseStore: WarehouseMapStore
    @EnvironmentObject private var barcodeCatalog: BarcodeCatalogStore
    @EnvironmentObject private var accountStore: LocalAccountStore
    @State private var searchText = ""
    @State private var locations: [InventoryLocationIndexEntry] = []
    @State private var focusedLocation: FocusedInventoryLocation?
    @State private var showingScanner = false
    @State private var showingSavedScans = false
    @State private var showingWarehouseMap = false
    @State private var showingAccountSettings = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @FocusState private var searchIsFocused: Bool
    let showsCloseButton: Bool

    init(showsCloseButton: Bool = false) {
        self.showsCloseButton = showsCloseButton
    }

    private var filteredLocations: [InventoryLocationIndexEntry] {
        let query = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !query.isEmpty else {
            return Array(locations.prefix(30))
        }

        return locations.filter { location in
            let record = barcodeCatalog.record(for: location.barcode)
            return location.barcode.localizedCaseInsensitiveContains(query)
                || location.symbology.localizedCaseInsensitiveContains(query)
                || (record?.name.localizedCaseInsensitiveContains(query)
                    ?? false)
                || (record?.sku.localizedCaseInsensitiveContains(query)
                    ?? false)
                || (record?.notes.localizedCaseInsensitiveContains(query)
                    ?? false)
                || (warehouseStore
                    .zone(containingScan: location.archiveID)?
                    .name
                    .localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.025, green: 0.045, blue: 0.075),
                        .black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    homeHeader
                    searchField
                    resultContent
                    secondaryActions
                }
                .padding()
            }
            .preferredColorScheme(.dark)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            reloadInventory()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                searchIsFocused = true
            }
        }
        .fullScreenCover(isPresented: $showingScanner) {
            ScannerWorkspaceView {
                showingScanner = false
                reloadInventory()
            }
        }
        .sheet(isPresented: $showingSavedScans) {
            SavedScansView()
        }
        .sheet(isPresented: $showingWarehouseMap) {
            WarehouseMapView {
                showingWarehouseMap = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    showingScanner = true
                }
            }
        }
        .sheet(isPresented: $showingAccountSettings) {
            LocalAccountSettingsView()
        }
        .sheet(item: $focusedLocation) { destination in
            SavedScanView(
                archive: destination.archive,
                initialFocusedBarcodeID: destination.barcodeID
            )
        }
        .alert(
            "Unable to open inventory",
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

    private var homeHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(warehouseStore.plan.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .textCase(.uppercase)

                Text("Find inventory")
                    .font(.largeTitle.bold())

                Text("Search by item name, SKU, barcode, notes, or zone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if showsCloseButton {
                Button {
                    searchIsFocused = false
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.10), in: Circle())
                }
                .accessibilityLabel("Close inventory search")
            }

            Button {
                searchIsFocused = false
                showingAccountSettings = true
            } label: {
                Text(accountInitials)
                    .font(.subheadline.bold())
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .background(.cyan, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(
                                Color.white.opacity(0.22),
                                lineWidth: 1
                            )
                    }
            }
            .accessibilityLabel("Open account settings")
        }
    }

    private var accountInitials: String {
        let name = accountStore.session?.account.fullName ?? "Account"
        let initials = name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
        return initials.isEmpty
            ? "A"
            : String(initials).uppercased()
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.cyan)

            TextField("What are you looking for?", text: $searchText)
                .font(.title3.weight(.semibold))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($searchIsFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
        .background(
            Color.white.opacity(0.09),
            in: RoundedRectangle(cornerRadius: 17)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 17)
                .stroke(Color.cyan.opacity(0.32), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Building the local inventory index…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if locations.isEmpty {
            ContentUnavailableView {
                Label("No inventory locations yet", systemImage: "barcode")
            } description: {
                Text(
                    "Scan a zone and capture a barcode. New locations will become searchable here automatically."
                )
            }
            .frame(maxHeight: .infinity)
        } else if filteredLocations.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .frame(maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 9) {
                Text(
                    searchText.isEmpty
                        ? "RECENT LOCATIONS"
                        : "\(filteredLocations.count) MATCHES"
                )
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(filteredLocations) { location in
                            Button {
                                openLocation(location)
                            } label: {
                                inventoryRow(location)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 2)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func inventoryRow(
        _ location: InventoryLocationIndexEntry
    ) -> some View {
        let record = barcodeCatalog.record(for: location.barcode)
        let displayName = record?.name.isEmpty == false
            ? record?.name ?? location.barcode
            : location.barcode
        let zoneName = warehouseStore
            .zone(containingScan: location.archiveID)?
            .name ?? "Unassigned zone"

        return HStack(spacing: 13) {
            Image(systemName: "shippingbox.fill")
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 42, height: 42)
                .background(
                    Color.green.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: 12)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                    .lineLimit(1)

                if let sku = record?.sku, !sku.isEmpty {
                    Text("SKU \(sku)")
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                } else if record?.name.isEmpty == false {
                    Text(location.barcode)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Label(zoneName, systemImage: "mappin.and.ellipse")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.cyan)
            }

            Spacer()

            Image(systemName: "viewfinder")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(13)
        .background(
            Color.white.opacity(0.065),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.07))
        }
    }

    private var secondaryActions: some View {
        HStack(spacing: 10) {
            Button {
                searchIsFocused = false
                showingWarehouseMap = true
            } label: {
                Label("Map", systemImage: "square.3.layers.3d")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Button {
                searchIsFocused = false
                showingSavedScans = true
            } label: {
                Label("Scans", systemImage: "archivebox")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Button {
                searchIsFocused = false
                showingScanner = true
            } label: {
                Label("Scan", systemImage: "camera.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
    }

    private func reloadInventory() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let loaded = try ScanStore.inventoryLocations()
                DispatchQueue.main.async {
                    locations = loaded
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func openLocation(_ location: InventoryLocationIndexEntry) {
        searchIsFocused = false
        do {
            let archive = try ScanStore.load(id: location.archiveID)
            focusedLocation = FocusedInventoryLocation(
                archive: archive,
                barcodeID: location.id
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct FocusedInventoryLocation: Identifiable {
    let id = UUID()
    let archive: ScanArchive
    let barcodeID: UUID
}

struct ScannerWorkspaceView: View {
    @EnvironmentObject private var scanner: ScanSessionController
    @EnvironmentObject private var warehouseStore: WarehouseMapStore
    let onClose: () -> Void
    @State private var showingSavedScans = false
    @State private var showingWarehouseMap = false
    @State private var showingScanGuide = false
    @State private var reviewingSavedZoneID: UUID?

    var body: some View {
        ZStack {
            ARScannerView(controller: scanner)
                .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.72), .clear, .black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 16) {
                header
                Spacer()

                if scanner.phase == .ready {
                    instructions
                } else if scanner.phase == .markerSetup
                    || scanner.phase == .aligning
                    || scanner.phase == .readyToScan
                    || scanner.phase == .scanning
                    || scanner.phase == .saved {
                    guidance
                }

                controls
            }
            .padding()

            if let pending = scanner.pendingLocationCapture {
                Color.black.opacity(0.42)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    LocationOccupancyPrompt(
                        location: pending,
                        onSelect: { occupancy in
                            scanner.confirmPendingLocation(
                                occupancy: occupancy
                            )
                        },
                        onDiscard: {
                            scanner.discardPendingLocation()
                        }
                    )
                    .padding()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(
            .snappy(duration: 0.24),
            value: scanner.pendingLocationCapture
        )
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingSavedScans) {
            SavedScansView()
        }
        .sheet(isPresented: $showingWarehouseMap) {
            WarehouseMapView()
        }
        .sheet(isPresented: $showingScanGuide) {
            ScanGuideView()
        }
        .sheet(
            isPresented: Binding(
                get: { reviewingSavedZoneID != nil },
                set: {
                    if !$0 {
                        reviewingSavedZoneID = nil
                    }
                }
            )
        ) {
            if let zoneID = reviewingSavedZoneID {
                PostScanOccupancyView(zoneID: zoneID)
            }
        }
        .onChange(of: scanner.savedZoneID) { _, zoneID in
            if let zoneID,
               warehouseStore
                .zone(id: zoneID)?
                .recordedStorageLocations
                .isEmpty != false {
                reviewingSavedZoneID = zoneID
            }
        }
        .alert(
            "WarehouseMapper Scanner",
            isPresented: Binding(
                get: { scanner.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        scanner.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                scanner.errorMessage = nil
            }
        } message: {
            Text(scanner.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("WarehouseMapper")
                        .font(.headline)

                    Text(scanner.phaseDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !navigationIsDisabled {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 32, height: 32)
                            .background(
                                Color.white.opacity(0.1),
                                in: Circle()
                            )
                    }
                    .accessibilityLabel("Close scanner")
                }

                TrackingBadge(
                    text: scanner.trackingStatus,
                    color: scanner.trackingColor
                )
            }

            HStack(spacing: 10) {
                MetricCard(
                    title: scanner.markerTotal > 0
                        ? scanner.phase == .aligning
                            ? "Boundary"
                            : "Markers"
                        : "Mesh",
                    value: scanner.markerTotal > 0
                        ? "\(scanner.markerProgress)/\(scanner.markerTotal)"
                        : "\(scanner.meshSectionCount)"
                )

                MetricCard(
                    title: "Locations",
                    value: "\(scanner.barcodeLocationCount)"
                )

                MetricCard(
                    title: "Path",
                    value: scanner.formattedDistance
                )

                MetricCard(
                    title: "Zone time",
                    value: scanner.formattedDuration
                )
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Guided zone scan", systemImage: "viewfinder")
                    .font(.headline)

                Spacer()

                Button("How to scan") {
                    showingScanGuide = true
                }
                .font(.caption.weight(.semibold))
            }

            Text(
                "Scan one compact zone at a time. Keep the floor and nearby racks visible together, overlap completed areas, and save after roughly three minutes."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var guidance: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(scanner.guidanceColor)

                Text(scanner.guidanceText)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if scanner.phase == .scanning,
               let lastBarcode = scanner.lastBarcodeValue {
                Label {
                    Text("Captured: \(lastBarcode)")
                        .lineLimit(1)
                        .truncationMode(.middle)
                } icon: {
                    Image(systemName: "barcode.viewfinder")
                }
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(.green)
            }
        }
        .padding(14)
        .background(
            scanner.guidanceColor.opacity(0.16),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                showingWarehouseMap = true
            } label: {
                Label("Map", systemImage: "square.3.layers.3d")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(navigationIsDisabled)

            Button {
                showingSavedScans = true
            } label: {
                Image(systemName: "archivebox")
                    .frame(width: 25)
                    .accessibilityLabel("Saved scans")
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(navigationIsDisabled)

            switch scanner.phase {
            case .scanning:
                Button {
                    scanner.stopAndSave()
                } label: {
                    Label("Stop & Save", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle(color: .red))

            case .markerSetup, .aligning:
                Button {
                    scanner.cancelCurrentOperation()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle(color: .orange))

            case .readyToScan:
                Button {
                    scanner.beginPreparedZoneScan()
                } label: {
                    Label("Scan Zone", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle(color: .green))

            case .ready, .saved, .saving:
                Button {
                    if warehouseStore.plan.zones.isEmpty {
                        scanner.startScan()
                    } else {
                        showingWarehouseMap = true
                    }
                } label: {
                    Label(
                        scanner.phase == .saving
                            ? "Saving…"
                            : warehouseStore.plan.zones.isEmpty
                                ? "Start Scan"
                                : "Choose Zone",
                        systemImage: warehouseStore.plan.zones.isEmpty
                            ? "record.circle"
                            : "viewfinder.circle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle(color: .green))
                .disabled(scanner.phase == .saving)
            }
        }
    }

    private var navigationIsDisabled: Bool {
        scanner.phase == .markerSetup
            || scanner.phase == .aligning
            || scanner.phase == .readyToScan
            || scanner.phase == .scanning
            || scanner.phase == .saving
    }
}

private struct LocationOccupancyPrompt: View {
    let location: PendingStorageLocation
    let onSelect: (LocationOccupancyState) -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "barcode.viewfinder")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                    .frame(width: 46, height: 46)
                    .background(.cyan.opacity(0.14), in: RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Aisle location found")
                        .font(.headline)
                    Text(location.code)
                        .font(.subheadline.monospaced().weight(.semibold))
                        .lineLimit(2)
                }
            }

            Text("Is this storage position currently open or occupied?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                occupancyButton(
                    state: .available,
                    color: .green
                )
                occupancyButton(
                    state: .occupied,
                    color: .orange
                )
            }

            Button("Not a location label", role: .cancel) {
                onDiscard()
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.14))
        }
        .shadow(color: .black.opacity(0.38), radius: 22, y: 10)
    }

    private func occupancyButton(
        state: LocationOccupancyState,
        color: Color
    ) -> some View {
        Button {
            onSelect(state)
        } label: {
            VStack(spacing: 7) {
                Image(systemName: state.symbol)
                    .font(.title2)
                Text(state.title)
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.82), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

private struct TrackingBadge: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(text)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.16), in: Capsule())
    }
}

private struct MetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 15)
            .foregroundStyle(.black)
            .background(
                color.opacity(configuration.isPressed ? 0.72 : 1),
                in: RoundedRectangle(cornerRadius: 15)
            )
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(
                .ultraThinMaterial.opacity(configuration.isPressed ? 0.72 : 1),
                in: RoundedRectangle(cornerRadius: 15)
            )
    }
}

private struct ScanGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    guideStep(
                        number: "1",
                        title: "Start at the entrance",
                        text: "Stand at a repeatable zone entrance and face down the aisle. This makes the temporary coordinate system easier to understand."
                    )

                    guideStep(
                        number: "2",
                        title: "Move slowly with overlap",
                        text: "Keep part of the completed gray mesh in view while introducing new surfaces. Avoid fast turns and sudden phone movement."
                    )

                    guideStep(
                        number: "3",
                        title: "Show floor and structure",
                        text: "Keep the floor, rack edges, labels, and corners visible together. These features help ARKit maintain a stable position."
                    )

                    guideStep(
                        number: "4",
                        title: "Capture multiple angles",
                        text: "Look at rack faces from the front and slight angles. Raise or lower the phone gradually for stacked levels."
                    )

                    guideStep(
                        number: "5",
                        title: "Record aisle locations",
                        text: "Center each aisle, rack, bin, or pallet-location barcode. When the location appears, mark it Open or Occupied. Choose Not a location if the camera catches a product barcode instead."
                    )

                    guideStep(
                        number: "6",
                        title: "Save short zones",
                        text: "Stop and save around three minutes or sooner if the phone becomes hot. Begin a new scan for the next zone."
                    )

                    VStack(alignment: .leading, spacing: 7) {
                        Label("Avoid", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)

                        Text(
                            "Darkness, glossy shrink wrap filling the view, blank walls, repeated fast passes, and scanning an entire warehouse as one session."
                        )
                        .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .navigationTitle("How to scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func guideStep(
        number: String,
        title: String,
        text: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.black)
                .frame(width: 34, height: 34)
                .background(.cyan, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)

                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
