import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var warehouseStore: WarehouseMapStore
    @EnvironmentObject private var accountStore: LocalAccountStore

    @State private var showingScanner = false
    @State private var showingSavedScans = false
    @State private var showingWarehouseMap = false
    @State private var showingInventory = false
    @State private var showingAccountSettings = false
    @State private var showingConsolidationPlan = false
    @State private var showingFootprintEditor = false
    @State private var editingCapacityZone: WarehouseZone?

    private var snapshot: WarehouseCapacitySnapshot {
        WarehouseCapacityEngine.analyze(warehouseStore.plan)
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

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        dashboardHeader
                        capacityOverview

                        if warehouseStore.plan.footprint == nil {
                            footprintPrompt
                        }

                        if warehouseStore.plan.zones.isEmpty {
                            noMapCard
                        } else if snapshot.configuredZoneCount == 0 {
                            configurationPrompt
                        } else {
                            opportunityCard

                            if snapshot.unconfiguredZoneCount > 0 {
                                incompleteSetupCard
                            }

                            zoneSection
                        }

                        quickActions
                    }
                    .padding()
                    .padding(.bottom, 10)
                }
            }
            .preferredColorScheme(.dark)
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $showingScanner) {
            ScannerWorkspaceView {
                showingScanner = false
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
        .sheet(isPresented: $showingInventory) {
            InventoryWorkspaceView()
        }
        .sheet(isPresented: $showingAccountSettings) {
            LocalAccountSettingsView()
        }
        .sheet(isPresented: $showingConsolidationPlan) {
            ConsolidationPlanView()
        }
        .sheet(isPresented: $showingFootprintEditor) {
            WarehouseFootprintEditorView()
        }
        .sheet(item: $editingCapacityZone) { zone in
            ZoneCapacityEditorView(zoneID: zone.id)
        }
    }

    private var dashboardHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(warehouseStore.plan.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .textCase(.uppercase)

                Text("Space command center")
                    .font(.largeTitle.bold())

                Text("Find capacity you already have before adding more space.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Button {
                showingAccountSettings = true
            } label: {
                Text(accountInitials)
                    .font(.subheadline.bold())
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .background(.cyan, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
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

    private var capacityOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 18) {
                CapacityRing(
                    progress: snapshot.utilization,
                    isConfigured: snapshot.usablePositions > 0
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text("USABLE CAPACITY")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    Text(
                        snapshot.usablePositions > 0
                            ? "\(snapshot.occupiedPositions) of \(snapshot.usablePositions) positions filled"
                            : "Add capacity to your mapped zones"
                    )
                    .font(.title3.bold())

                    Text(overviewMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 9) {
                SpaceMetric(
                    title: "Open",
                    value: "\(snapshot.availablePositions)",
                    detail: "usable positions",
                    color: .cyan
                )
                SpaceMetric(
                    title: "Unavailable",
                    value: "\(snapshot.unavailablePositions)",
                    detail: "reserved or blocked",
                    color: .orange
                )
                SpaceMetric(
                    title: "Fragmented",
                    value: "\(snapshot.fragmentedOpenPositions)",
                    detail: "open in active zones",
                    color: .purple
                )
            }
        }
        .padding(17)
        .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08))
        }
    }

    private var overviewMessage: String {
        guard snapshot.usablePositions > 0 else {
            return "The map remains the physical source of truth; capacity is recorded per zone."
        }
        if snapshot.utilization >= 0.90 {
            return "Space is tight. Review blocked positions and the consolidation plan before expanding."
        }
        if snapshot.utilization >= 0.70 {
            return "Capacity is healthy, but fragmented openings may still hide usable space."
        }
        return "There is room in the current footprint. Consolidation can turn scattered openings into usable zones."
    }

    private var noMapCard: some View {
        actionCard(
            symbol: "square.3.layers.3d",
            color: .cyan,
            title: "Map the first storage zone",
            message: "Create the physical footprint first. Then record how many storage positions actually fit inside it.",
            buttonTitle: "Build warehouse map"
        ) {
            showingWarehouseMap = true
        }
    }

    private var footprintPrompt: some View {
        actionCard(
            symbol: "ruler",
            color: .orange,
            title: "Set the warehouse boundary",
            message: "Enter the building’s inside width, length, and clear height so zones are placed inside a real footprint instead of an expanding estimate.",
            buttonTitle: "Enter warehouse dimensions"
        ) {
            showingFootprintEditor = true
        }
    }

    private var configurationPrompt: some View {
        actionCard(
            symbol: "ruler.fill",
            color: .orange,
            title: "Define usable capacity",
            message: "Your \(warehouseStore.plan.zones.count) mapped zones are intact. Add total, occupied, reserved, and blocked positions so consolidation can be calculated.",
            buttonTitle: "Configure first zone"
        ) {
            editingCapacityZone = warehouseStore.plan.zones.first
        }
    }

    private var incompleteSetupCard: some View {
        Button {
            editingCapacityZone = warehouseStore.plan.zones.first {
                $0.capacityProfile == nil
                    || $0.capacityProfile?.totalPositions == 0
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(snapshot.unconfiguredZoneCount) zones need capacity")
                        .font(.subheadline.bold())
                    Text("Finish setup to avoid incomplete recommendations.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var opportunityCard: some View {
        Button {
            showingConsolidationPlan = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(
                        "Consolidation scenario",
                        systemImage: "arrow.triangle.merge"
                    )
                    .font(.headline)

                    Spacer()

                    Text(snapshot.recommendations.isEmpty ? "CLEAR" : "REVIEW")
                        .font(.caption2.bold())
                        .foregroundStyle(
                            snapshot.recommendations.isEmpty
                                ? Color.green
                                : Color.yellow
                        )
                }

                if snapshot.recommendations.isEmpty {
                    Text(
                        "No entire zone can be released from the compatible capacity entered so far."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(snapshot.releasableZoneCount)")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                        Text(
                            snapshot.releasableZoneCount == 1
                                ? "zone could be released"
                                : "zones could be released"
                        )
                        .font(.headline)
                    }

                    Text(
                        String(
                            format: "About %.0f ft² of mapped zone footprint becomes available for reassignment.",
                            snapshot.releasableSquareFeet
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Open move plan")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundStyle(.cyan)
            }
            .padding(17)
            .background(
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(0.14),
                        Color.purple.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 20)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.cyan.opacity(0.22))
            }
        }
        .buttonStyle(.plain)
    }

    private var zoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ZONES BY UTILIZATION")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(snapshot.configuredZoneCount) configured")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(snapshot.zones) { zoneSnapshot in
                Button {
                    editingCapacityZone = zoneSnapshot.zone
                } label: {
                    CapacityZoneRow(snapshot: zoneSnapshot)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TOOLS")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 9) {
                DashboardActionButton(
                    title: "Map",
                    symbol: "square.3.layers.3d",
                    color: .cyan
                ) {
                    showingWarehouseMap = true
                }
                DashboardActionButton(
                    title: "Update",
                    symbol: "camera.viewfinder",
                    color: .green
                ) {
                    showingScanner = true
                }
                DashboardActionButton(
                    title: "Inventory",
                    symbol: "magnifyingglass",
                    color: .purple
                ) {
                    showingInventory = true
                }
                DashboardActionButton(
                    title: "Scans",
                    symbol: "archivebox",
                    color: .orange
                ) {
                    showingSavedScans = true
                }
            }
        }
    }

    private func actionCard(
        symbol: String,
        color: Color,
        title: String,
        message: String,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(color)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(buttonTitle, action: action)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.black)
                .background(color, in: RoundedRectangle(cornerRadius: 13))
        }
        .padding(17)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct CapacityRing: View {
    let progress: Double
    let isConfigured: Bool

    private var color: Color {
        if !isConfigured {
            return .secondary
        }
        if progress >= 0.90 {
            return .orange
        }
        if progress >= 0.70 {
            return .yellow
        }
        return .cyan
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.09), lineWidth: 10)

            Circle()
                .trim(from: 0, to: max(0.015, min(1, progress)))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text(
                    isConfigured
                        ? "\(Int((progress * 100).rounded()))%"
                        : "—"
                )
                .font(.title2.monospacedDigit().bold())
                Text("filled")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 104, height: 104)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isConfigured
                ? "\(Int((progress * 100).rounded())) percent filled"
                : "Capacity not configured"
        )
    }
}

private struct SpaceMetric: View {
    let title: String
    let value: String
    let detail: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.monospacedDigit().bold())
                .foregroundStyle(color)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(.black.opacity(0.23), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct CapacityZoneRow: View {
    let snapshot: ZoneCapacitySnapshot

    private var tint: Color {
        if snapshot.utilization >= 0.90 {
            return .orange
        }
        if snapshot.utilization <= 0.40 {
            return .purple
        }
        return .cyan
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                Image(systemName: snapshot.profile.layout.symbol)
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot.zone.name)
                        .font(.headline)
                    Text(
                        "\(snapshot.profile.layout.title) · \(snapshot.profile.constraintClass.title)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int((snapshot.utilization * 100).rounded()))%")
                        .font(.headline.monospacedDigit())
                    Text("\(snapshot.availablePositions) open")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.09))
                    Capsule()
                        .fill(tint)
                        .frame(
                            width: proxy.size.width
                                * max(0.01, min(1, snapshot.utilization))
                        )
                }
            }
            .frame(height: 7)

            HStack {
                Text("\(snapshot.occupiedPositions) occupied")
                Spacer()
                Text("\(snapshot.unavailablePositions) unavailable")
                Image(systemName: "chevron.right")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 17))
        .overlay {
            RoundedRectangle(cornerRadius: 17)
                .stroke(Color.white.opacity(0.07))
        }
    }
}

private struct DashboardActionButton: View {
    let title: String
    let symbol: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
    }
}

struct ZoneCapacityEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var warehouseStore: WarehouseMapStore
    let zoneID: UUID

    @State private var layout: StorageLayoutType = .palletPositions
    @State private var constraintClass: StorageConstraintClass = .standard
    @State private var totalPositions = 0
    @State private var occupiedPositions = 0
    @State private var reservedPositions = 0
    @State private var blockedPositions = 0
    @State private var notes = ""
    @State private var hasLoaded = false
    @State private var showingClearConfirmation = false

    private var zone: WarehouseZone? {
        warehouseStore.zone(id: zoneID)
    }

    private var preview: ZoneCapacityProfile {
        ZoneCapacityProfile(
            layout: layout,
            constraintClass: constraintClass,
            totalPositions: totalPositions,
            occupiedPositions: occupiedPositions,
            reservedPositions: reservedPositions,
            blockedPositions: blockedPositions,
            notes: notes
        )
    }

    private var hasInvalidCounts: Bool {
        occupiedPositions + reservedPositions + blockedPositions
            > totalPositions
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Storage position", selection: $layout) {
                        ForEach(StorageLayoutType.allCases) { layout in
                            Label(layout.title, systemImage: layout.symbol)
                                .tag(layout)
                        }
                    }

                    Text(
                        "Choose one repeatable physical unit. Count pallet spots, rack bays, shelf sections, or floor-stack spots—not individual products."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Picker("Handling class", selection: $constraintClass) {
                        ForEach(StorageConstraintClass.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }

                    Text(constraintClass.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("What this zone can hold")
                } footer: {
                    Text(
                        "Consolidation is only suggested between zones with the same storage position and handling class."
                    )
                }

                Section("Position counts") {
                    countField(
                        title: "Total positions",
                        explanation: "Every physical position inside the zone, including occupied, open, reserved, and blocked.",
                        value: $totalPositions
                    )
                    countField(
                        title: "Occupied",
                        explanation: "Positions holding stock right now.",
                        value: $occupiedPositions
                    )
                    countField(
                        title: "Reserved",
                        explanation: "Open positions intentionally held for incoming stock or operating buffer.",
                        value: $reservedPositions
                    )
                    countField(
                        title: "Blocked",
                        explanation: "Positions that exist physically but cannot currently be used because of damage, clearance, or access.",
                        value: $blockedPositions
                    )
                }

                Section("Live check") {
                    LabeledContent(
                        "Usable positions",
                        value: "\(preview.usablePositions)"
                    )
                    LabeledContent(
                        "Open positions",
                        value: "\(preview.availablePositions)"
                    )
                    LabeledContent(
                        "Utilization",
                        value: "\(Int((preview.utilization * 100).rounded()))%"
                    )

                    if hasInvalidCounts {
                        Label(
                            "Occupied + reserved + blocked cannot exceed the total.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    }
                }

                Section("Notes") {
                    TextField(
                        "Example: keep two bays open for inbound overflow",
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                }

                if zone?.capacityProfile != nil {
                    Section {
                        Button("Remove capacity setup", role: .destructive) {
                            showingClearConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(zone?.name ?? "Zone capacity")
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
                    .disabled(totalPositions <= 0 || hasInvalidCounts)
                }
            }
            .confirmationDialog(
                "Remove capacity setup?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    warehouseStore.updateCapacity(
                        zoneID: zoneID,
                        profile: nil
                    )
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The map and every scan stay intact. Only these capacity counts are removed.")
            }
            .onAppear {
                loadOnce()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func countField(
        title: String,
        explanation: String,
        value: Binding<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                TextField("0", value: value, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .font(.body.monospacedDigit().bold())
            }

            Text(explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    private func loadOnce() {
        guard !hasLoaded else {
            return
        }
        hasLoaded = true
        guard let profile = zone?.capacityProfile else {
            return
        }
        layout = profile.layout
        constraintClass = profile.constraintClass
        totalPositions = profile.totalPositions
        occupiedPositions = profile.occupiedPositions
        reservedPositions = profile.reservedPositions
        blockedPositions = profile.blockedPositions
        notes = profile.notes
    }

    private func save() {
        let total = max(1, totalPositions)
        let blocked = min(max(0, blockedPositions), total)
        let reserved = min(
            max(0, reservedPositions),
            max(0, total - blocked)
        )
        let occupied = min(
            max(0, occupiedPositions),
            max(0, total - blocked - reserved)
        )

        warehouseStore.updateCapacity(
            zoneID: zoneID,
            profile: ZoneCapacityProfile(
                layout: layout,
                constraintClass: constraintClass,
                totalPositions: total,
                occupiedPositions: occupied,
                reservedPositions: reserved,
                blockedPositions: blocked,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                verifiedAt: Date(),
                observedFill: zone?.capacityProfile?.observedFill
            )
        )
        dismiss()
    }
}

struct ConsolidationPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var warehouseStore: WarehouseMapStore

    private var snapshot: WarehouseCapacitySnapshot {
        WarehouseCapacityEngine.analyze(warehouseStore.plan)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    scenarioSummary

                    if snapshot.recommendations.isEmpty {
                        ContentUnavailableView {
                            Label(
                                "No full-zone move yet",
                                systemImage: "arrow.triangle.merge"
                            )
                        } description: {
                            Text(
                                "There is not enough compatible open capacity to empty an entire active zone with the current counts."
                            )
                        }
                        .padding(.vertical, 28)
                    } else {
                        ForEach(
                            Array(snapshot.recommendations.enumerated()),
                            id: \.element.id
                        ) { index, recommendation in
                            recommendationCard(
                                recommendation,
                                number: index + 1
                            )
                        }
                    }

                    assumptionsCard
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
            .navigationTitle("Consolidation plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var scenarioSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ONE SAFE SCENARIO")
                .font(.caption2.bold())
                .foregroundStyle(.cyan)
            Text(
                snapshot.recommendations.isEmpty
                    ? "Current layout stays in place"
                    : "\(snapshot.releasableZoneCount) zones · \(String(format: "%.0f", snapshot.releasableSquareFeet)) ft² releasable"
            )
            .font(.title2.bold())
            Text(
                "Moves are simulated in order, so later steps already account for capacity used by earlier steps."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.cyan.opacity(0.11), in: RoundedRectangle(cornerRadius: 19))
    }

    private func recommendationCard(
        _ recommendation: ConsolidationRecommendation,
        number: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                Text("\(number)")
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .frame(width: 28, height: 28)
                    .background(.cyan, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        recommendation.isAlreadyEmpty
                            ? "Reassign \(recommendation.sourceZoneName)"
                            : "Empty \(recommendation.sourceZoneName)"
                    )
                    .font(.headline)
                    Text(
                        "\(recommendation.layout.title) · \(recommendation.constraintClass.title)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(
                    String(
                        format: "%.0f ft²",
                        recommendation.releasedSquareFeet
                    )
                )
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(.cyan)
            }

            Text(recommendation.summary)
                .font(.subheadline)

            ForEach(recommendation.moves) { move in
                HStack {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.cyan)
                    Text("\(move.positionCount) → \(move.targetZoneName)")
                    Spacer()
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(16)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08))
        }
    }

    private var assumptionsCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(
                "Verify before moving stock",
                systemImage: "checklist"
            )
            .font(.headline)

            Text(
                "This is a capacity scenario, not an automatic work order. It assumes positions with the same storage type and handling class are interchangeable. It does not yet know item dimensions, weight limits, pick velocity, lot rules, or rack engineering limits."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(
                "Use reserved positions for inbound buffer. Mark damaged or inaccessible positions as blocked so they are never treated as destinations."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
    }
}
