import SwiftUI

struct SavedScansView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var warehouseStore: WarehouseMapStore
    @State private var scans: [SavedScanSummary] = []
    @State private var selectedScan: ScanArchive?
    @State private var assignmentContext: ScanAssignmentContext?
    @State private var shareURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if scans.isEmpty {
                    ContentUnavailableView(
                        "No saved scans",
                        systemImage: "cube.transparent",
                        description: Text(
                            "Complete a local scan and it will appear here."
                        )
                    )
                } else {
                    List(scans) { scan in
                        HStack(spacing: 8) {
                            Button {
                                open(scan)
                            } label: {
                                ScanRow(
                                    scan: scan,
                                    zoneName: warehouseStore
                                        .zone(containingScan: scan.id)?
                                        .name
                                )
                            }
                            .buttonStyle(.plain)

                            Menu {
                                Button {
                                    assignmentContext = ScanAssignmentContext(
                                        scan: scan
                                    )
                                } label: {
                                    Label(
                                        warehouseStore.zone(
                                            containingScan: scan.id
                                        ) == nil
                                            ? "Assign to zone"
                                            : "Reassign zone",
                                        systemImage: "square.3.layers.3d"
                                    )
                                }

                                Button {
                                    export(scan)
                                } label: {
                                    Label(
                                        "Export scan",
                                        systemImage: "square.and.arrow.up"
                                    )
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                                    .frame(width: 34, height: 34)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                export(scan)
                            } label: {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                            .tint(.cyan)

                            Button {
                                assignmentContext = ScanAssignmentContext(
                                    scan: scan
                                )
                            } label: {
                                Label("Assign", systemImage: "link")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Saved scans")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                reload()
            }
            .sheet(item: $selectedScan) { archive in
                SavedScanView(archive: archive)
            }
            .sheet(item: $assignmentContext) { context in
                SavedScanAssignmentView(scan: context.scan)
                    .environmentObject(warehouseStore)
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
                "Unable to open scans",
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

    private func reload() {
        do {
            scans = try ScanStore.list()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func open(_ summary: SavedScanSummary) {
        do {
            selectedScan = try ScanStore.load(from: summary.fileURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func export(_ summary: SavedScanSummary) {
        do {
            let zoneName = warehouseStore
                .zone(containingScan: summary.id)?
                .name ?? "Unassigned"
            let date = summary.startedAt.formatted(
                .iso8601
                    .year()
                    .month()
                    .day()
            )
            shareURL = try ScanStore.exportURL(
                id: summary.id,
                suggestedName: "\(zoneName)-\(date)"
            )
        } catch {
            errorMessage = "The scan could not be exported: \(error.localizedDescription)"
        }
    }
}

private struct ScanRow: View {
    let scan: SavedScanSummary
    let zoneName: String?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "cube.fill")
                .font(.title2)
                .foregroundStyle(.cyan)
                .frame(width: 36, height: 36)
                .background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 4) {
                Text(scan.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)

                Text(
                    "\(scan.meshCount) mesh · \(scan.barcodeCount) code locations · \(scan.distanceMeters, specifier: "%.1f") m"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Label(
                    zoneName ?? "Unassigned",
                    systemImage: zoneName == nil
                        ? "tray"
                        : "square.3.layers.3d"
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(zoneName == nil ? .orange : .green)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}

private struct ScanAssignmentContext: Identifiable {
    let id = UUID()
    let scan: SavedScanSummary
}

private struct SavedScanAssignmentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var warehouseStore: WarehouseMapStore
    let scan: SavedScanSummary

    private var currentZone: WarehouseZone? {
        warehouseStore.zone(containingScan: scan.id)
    }

    var body: some View {
        NavigationStack {
            Group {
                if warehouseStore.plan.zones.isEmpty {
                    ContentUnavailableView(
                        "Create a zone first",
                        systemImage: "square.3.layers.3d",
                        description: Text(
                            "Close Saved Scans, open Map, and create the zone this scan belongs to."
                        )
                    )
                } else {
                    List(warehouseStore.plan.zones) { zone in
                        Button {
                            _ = warehouseStore.assignExistingScan(
                                archiveID: scan.id,
                                capturedAt: scan.startedAt,
                                to: zone.id
                            )
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: zone.kind.symbol)
                                    .foregroundStyle(.cyan)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(zone.name)
                                        .font(.headline)
                                    Text(zone.kind.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if currentZone?.id == zone.id {
                                    Label(
                                        "Assigned",
                                        systemImage: "checkmark.circle.fill"
                                    )
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(
                currentZone == nil ? "Assign to zone" : "Reassign scan"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
