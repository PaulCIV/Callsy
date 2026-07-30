import SwiftUI
import UniformTypeIdentifiers

struct WarehouseFootprintEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var warehouseStore: WarehouseMapStore

    @State private var unit: MeasurementUnitPreference = .feet
    @State private var width = 100.0
    @State private var depth = 100.0
    @State private var clearHeight = 20.0
    @State private var loaded = false
    @State private var showingRemoveConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Measurement unit", selection: $unit) {
                        ForEach(MeasurementUnitPreference.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    dimensionField(
                        title: "Inside width",
                        explanation: "Wall-to-wall width of usable warehouse floor.",
                        value: $width
                    )
                    dimensionField(
                        title: "Inside length",
                        explanation: "Wall-to-wall length of usable warehouse floor.",
                        value: $depth
                    )
                    dimensionField(
                        title: "Clear height",
                        explanation: "Floor-to-lowest overhead obstruction, not the roof peak.",
                        value: $clearHeight
                    )
                } header: {
                    Text("Building footprint")
                } footer: {
                    Text(
                        "This creates the fixed outer boundary on the map. Zones are clamped inside it instead of the map guessing its size from whatever zones happen to exist."
                    )
                }

                Section("Calculated footprint") {
                    LabeledContent(
                        "Floor area",
                        value: areaDescription
                    )
                    Text(
                        "These measurements are for layout planning. Do not use phone measurements for rack engineering, fire egress, or structural certification."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if warehouseStore.plan.footprint != nil {
                    Section {
                        Button(
                            "Remove warehouse boundary",
                            role: .destructive
                        ) {
                            showingRemoveConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle("Warehouse dimensions")
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
                    }
                    .disabled(width <= 0 || depth <= 0 || clearHeight <= 0)
                }
            }
            .confirmationDialog(
                "Remove fixed boundary?",
                isPresented: $showingRemoveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    warehouseStore.updateFootprint(nil)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Zones and scans remain saved, but the overview will expand around them again.")
            }
            .onAppear {
                loadOnce()
            }
            .onChange(of: unit) { oldUnit, newUnit in
                width = convert(width, from: oldUnit, to: newUnit)
                depth = convert(depth, from: oldUnit, to: newUnit)
                clearHeight = convert(
                    clearHeight,
                    from: oldUnit,
                    to: newUnit
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    private var areaDescription: String {
        let squareMeters = Double(
            unit.meters(fromDisplayValue: width)
                * unit.meters(fromDisplayValue: depth)
        )
        if unit == .feet {
            return String(format: "%.0f ft²", squareMeters * 10.7639)
        }
        return String(format: "%.0f m²", squareMeters)
    }

    private func dimensionField(
        title: String,
        explanation: String,
        value: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                TextField("0", value: value, format: .number.precision(.fractionLength(1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 95)
                    .font(.body.monospacedDigit().bold())
                Text(unit.shortSymbol)
                    .foregroundStyle(.secondary)
            }
            Text(explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    private func loadOnce() {
        guard !loaded else {
            return
        }
        loaded = true
        unit = warehouseStore.measurementUnit
        guard let footprint = warehouseStore.plan.footprint else {
            return
        }
        width = unit.displayValue(forMeters: footprint.widthMeters)
        depth = unit.displayValue(forMeters: footprint.depthMeters)
        clearHeight = unit.displayValue(
            forMeters: footprint.clearHeightMeters
        )
    }

    private func save() {
        warehouseStore.setMeasurementUnit(unit)
        warehouseStore.updateFootprint(
            WarehouseFootprint(
                widthMeters: unit.meters(fromDisplayValue: width),
                depthMeters: unit.meters(fromDisplayValue: depth),
                clearHeightMeters: unit.meters(
                    fromDisplayValue: clearHeight
                )
            )
        )
        dismiss()
    }

    private func convert(
        _ value: Double,
        from oldUnit: MeasurementUnitPreference,
        to newUnit: MeasurementUnitPreference
    ) -> Double {
        newUnit.displayValue(
            forMeters: oldUnit.meters(fromDisplayValue: value)
        )
    }
}

struct InventoryWorkspaceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var warehouseStore: WarehouseMapStore

    @State private var editingZone: WarehouseZone?
    @State private var showingImporter = false
    @State private var showingSearch = false
    @State private var importMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingImporter = true
                    } label: {
                        Label(
                            "Import inventory CSV",
                            systemImage: "square.and.arrow.down"
                        )
                    }

                    Button {
                        showingSearch = true
                    } label: {
                        Label(
                            "Search captured barcodes",
                            systemImage: "magnifyingglass"
                        )
                    }
                } footer: {
                    Text(
                        "For Excel, export the sheet as CSV first. Required columns: zone, category, quantity. Add positions_used if the file knows how many physical storage positions each category occupies."
                    )
                }

                Section("Inventory by zone") {
                    if warehouseStore.plan.zones.isEmpty {
                        Text("Create a mapped zone before adding inventory.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(warehouseStore.plan.zones) { zone in
                        Button {
                            editingZone = zone
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: zone.kind.symbol)
                                    .foregroundStyle(.cyan)
                                    .frame(width: 38, height: 38)
                                    .background(
                                        .cyan.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 11)
                                    )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(zone.name)
                                        .foregroundStyle(.primary)
                                        .font(.headline)
                                    Text(
                                        "\(zone.recordedInventory.count) categories · \(zone.recordedInventoryQuantity) units · \(zone.recordedPositionsUsed) positions"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Inventory & occupancy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $editingZone) { zone in
                ZoneInventoryEditorView(zoneID: zone.id)
            }
            .sheet(isPresented: $showingSearch) {
                InventorySearchView(showsCloseButton: true)
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [
                    .commaSeparatedText,
                    .tabSeparatedText,
                    .plainText
                ],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert(
                "Inventory import",
                isPresented: Binding(
                    get: { importMessage != nil },
                    set: { if !$0 { importMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    importMessage = nil
                }
            } message: {
                Text(importMessage ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func handleImport(
        _ result: Result<[URL], Error>
    ) {
        do {
            guard let url = try result.get().first else {
                return
            }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let rows = try InventoryImportParser.parse(
                data: Data(contentsOf: url)
            )
            var matchedRows = 0
            var unmatchedZones = Set<String>()
            var synchronizedZoneCount = 0

            let grouped = Dictionary(grouping: rows) {
                $0.zoneName.lowercased()
            }

            for (zoneName, importedRows) in grouped {
                guard let zone = warehouseStore.plan.zones.first(where: {
                    $0.name.lowercased() == zoneName
                }) else {
                    unmatchedZones.insert(
                        importedRows.first?.zoneName ?? zoneName
                    )
                    continue
                }

                var byCategory = Dictionary(
                    uniqueKeysWithValues: zone.recordedInventory.map {
                        ($0.category.lowercased(), $0)
                    }
                )
                for row in importedRows {
                    let key = row.category.lowercased()
                    byCategory[key] = ZoneInventoryEntry(
                        id: byCategory[key]?.id ?? UUID(),
                        category: row.category,
                        quantity: row.quantity,
                        positionsUsed: row.positionsUsed
                            ?? byCategory[key]?.positionsUsed
                            ?? 0
                    )
                    matchedRows += 1
                }

                let hasAllPositionCounts = importedRows.allSatisfy {
                    $0.positionsUsed != nil
                }
                let shouldSynchronize = hasAllPositionCounts
                    && zone.capacityProfile != nil
                warehouseStore.replaceInventory(
                    zoneID: zone.id,
                    entries: Array(byCategory.values).sorted {
                        $0.category < $1.category
                    },
                    synchronizeOccupiedPositions: shouldSynchronize
                )
                if shouldSynchronize {
                    synchronizedZoneCount += 1
                }
            }

            var message = "Imported \(matchedRows) rows."
            if synchronizedZoneCount > 0 {
                message += " Occupied positions were updated in \(synchronizedZoneCount) zones."
            }
            if !unmatchedZones.isEmpty {
                message += " No mapped zone matched: \(unmatchedZones.sorted().joined(separator: ", "))."
            }
            importMessage = message
        } catch {
            importMessage = error.localizedDescription
        }
    }
}

struct ZoneInventoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var warehouseStore: WarehouseMapStore
    let zoneID: UUID

    @State private var entries: [ZoneInventoryEntry] = []
    @State private var synchronizeOccupiedPositions = true
    @State private var loaded = false

    private var zone: WarehouseZone? {
        warehouseStore.zone(id: zoneID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if entries.isEmpty {
                        Text(
                            "Add a category such as boxed parts, tires, returns, or customer stock."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    ForEach($entries) { $entry in
                        VStack(alignment: .leading, spacing: 9) {
                            TextField("Category name", text: $entry.category)
                                .font(.subheadline.weight(.semibold))

                            HStack {
                                numericField(
                                    title: "Units",
                                    value: $entry.quantity
                                )
                                Divider()
                                numericField(
                                    title: "Positions used",
                                    value: $entry.positionsUsed
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        entries.remove(atOffsets: offsets)
                    }

                    Button {
                        entries.append(
                            ZoneInventoryEntry(
                                category: "",
                                quantity: 0,
                                positionsUsed: 0
                            )
                        )
                    } label: {
                        Label("Add category", systemImage: "plus.circle")
                    }
                } header: {
                    Text("What is stored here")
                } footer: {
                    Text(
                        "Units describe inventory quantity. Positions used describe physical space. Ten small boxes may use one shelf position; ten pallets may use ten positions."
                    )
                }

                Section {
                    Toggle(
                        "Use positions as zone occupancy",
                        isOn: $synchronizeOccupiedPositions
                    )
                    .disabled(zone?.capacityProfile == nil)

                    if zone?.capacityProfile == nil {
                        Text(
                            "Configure this zone’s total capacity before inventory positions can update utilization."
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    } else {
                        LabeledContent(
                            "Recorded positions",
                            value: "\(entries.reduce(0) { $0 + $1.positionsUsed })"
                        )
                    }
                } footer: {
                    Text(
                        "Turn this off when the inventory list is incomplete. Otherwise missing categories would make the zone look emptier than it really is."
                    )
                }
            }
            .navigationTitle(zone?.name ?? "Zone inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        warehouseStore.replaceInventory(
                            zoneID: zoneID,
                            entries: entries,
                            synchronizeOccupiedPositions:
                                synchronizeOccupiedPositions
                        )
                        dismiss()
                    }
                }
            }
            .onAppear {
                guard !loaded else {
                    return
                }
                loaded = true
                entries = zone?.recordedInventory ?? []
                synchronizeOccupiedPositions =
                    zone?.capacityProfile != nil
            }
        }
        .preferredColorScheme(.dark)
    }

    private func numericField(
        title: String,
        value: Binding<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .font(.body.monospacedDigit().bold())
        }
        .frame(maxWidth: .infinity)
    }
}

struct ZoneStorageLocationsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var warehouseStore: WarehouseMapStore
    let zoneID: UUID

    private var zone: WarehouseZone? {
        warehouseStore.zone(id: zoneID)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        Text(
                            "Each scanned aisle label becomes one physical storage position. Changing its status immediately updates zone capacity and the colored dot on the warehouse map."
                        )
                    } icon: {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.cyan)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("Mapped locations") {
                    if let zone,
                       zone.recordedStorageLocations.isEmpty {
                        ContentUnavailableView(
                            "No locations scanned",
                            systemImage: "barcode.viewfinder",
                            description: Text(
                                "Capture this zone and point the camera at each aisle or rack location label."
                            )
                        )
                    } else if let zone {
                        ForEach(zone.recordedStorageLocations) { location in
                            HStack(spacing: 12) {
                                Image(systemName: location.occupancy.symbol)
                                    .foregroundStyle(
                                        location.occupancy == .occupied
                                            ? Color.orange
                                            : Color.green
                                    )
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(location.code)
                                        .font(.body.monospaced().weight(.semibold))
                                        .lineLimit(1)

                                    Text(
                                        location.occupancy == .occupied
                                            ? "Currently occupied"
                                            : "Available position"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Menu {
                                    ForEach(LocationOccupancyState.allCases) { state in
                                        Button {
                                            warehouseStore.updateStorageLocation(
                                                zoneID: zoneID,
                                                locationID: location.id,
                                                occupancy: state
                                            )
                                        } label: {
                                            Label(state.title, systemImage: state.symbol)
                                        }
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        warehouseStore.deleteStorageLocation(
                                            zoneID: zoneID,
                                            locationID: location.id
                                        )
                                    } label: {
                                        Label("Remove location", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.title3)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(zone?.name ?? "Locations")
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
}

struct PostScanOccupancyView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var warehouseStore: WarehouseMapStore
    let zoneID: UUID

    @State private var fillState: ZoneFillState = .partial
    @State private var layout: StorageLayoutType = .palletPositions
    @State private var constraintClass: StorageConstraintClass = .standard
    @State private var totalPositions = 0
    @State private var occupiedPositions = 0
    @State private var reservedPositions = 0
    @State private var blockedPositions = 0
    @State private var notes = ""
    @State private var loaded = false

    private var zone: WarehouseZone? {
        warehouseStore.zone(id: zoneID)
    }

    private var usablePositions: Int {
        max(
            0,
            totalPositions - reservedPositions - blockedPositions
        )
    }

    private var effectiveOccupied: Int {
        switch fillState {
        case .empty:
            return 0
        case .partial:
            return min(max(0, occupiedPositions), usablePositions)
        case .full:
            return usablePositions
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("The scan is saved. Record what the operator saw before leaving the zone.")
                        .font(.subheadline)

                    Picker("Observed state", selection: $fillState) {
                        ForEach(ZoneFillState.allCases) { state in
                            Label(state.title, systemImage: state.symbol)
                                .tag(state)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Capacity check") {
                    Picker("Position type", selection: $layout) {
                        ForEach(StorageLayoutType.allCases) {
                            Text($0.title).tag($0)
                        }
                    }
                    Picker("Handling class", selection: $constraintClass) {
                        ForEach(StorageConstraintClass.allCases) {
                            Text($0.title).tag($0)
                        }
                    }

                    numberField(
                        title: "Total positions",
                        value: $totalPositions
                    )
                    numberField(
                        title: "Reserved",
                        value: $reservedPositions
                    )
                    numberField(
                        title: "Blocked",
                        value: $blockedPositions
                    )

                    if fillState == .partial {
                        numberField(
                            title: "Occupied now",
                            value: $occupiedPositions
                        )
                    }

                    LabeledContent(
                        "Will record",
                        value: "\(effectiveOccupied) of \(usablePositions) usable"
                    )
                }

                Section("Operator note") {
                    TextField(
                        "What changed or needs attention?",
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                }
            }
            .navigationTitle(zone?.name ?? "Scan occupancy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save status") {
                        save()
                    }
                    .disabled(
                        totalPositions <= 0
                            || reservedPositions + blockedPositions
                                > totalPositions
                    )
                }
            }
            .onAppear {
                loadOnce()
            }
        }
        .interactiveDismissDisabled()
        .preferredColorScheme(.dark)
    }

    private func numberField(
        title: String,
        value: Binding<Int>
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 85)
                .font(.body.monospacedDigit().bold())
        }
    }

    private func loadOnce() {
        guard !loaded else {
            return
        }
        loaded = true
        guard let profile = zone?.capacityProfile else {
            occupiedPositions = zone?.recordedPositionsUsed ?? 0
            return
        }
        layout = profile.layout
        constraintClass = profile.constraintClass
        totalPositions = profile.totalPositions
        occupiedPositions = profile.normalizedOccupiedPositions
        reservedPositions = profile.reservedPositions
        blockedPositions = profile.blockedPositions
        notes = profile.notes
        fillState = profile.observedFill
            ?? (
                profile.normalizedOccupiedPositions == 0
                    ? .empty
                    : profile.availablePositions == 0
                        ? .full
                        : .partial
            )
    }

    private func save() {
        warehouseStore.updateCapacity(
            zoneID: zoneID,
            profile: ZoneCapacityProfile(
                layout: layout,
                constraintClass: constraintClass,
                totalPositions: totalPositions,
                occupiedPositions: effectiveOccupied,
                reservedPositions: reservedPositions,
                blockedPositions: blockedPositions,
                notes: notes.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                verifiedAt: Date(),
                observedFill: fillState
            )
        )
        dismiss()
    }
}
