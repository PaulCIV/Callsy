import Foundation

struct ZoneCapacitySnapshot: Identifiable, Hashable {
    let zone: WarehouseZone
    let profile: ZoneCapacityProfile

    var id: UUID { zone.id }
    var totalPositions: Int { profile.totalPositions }
    var usablePositions: Int { profile.usablePositions }
    var occupiedPositions: Int { profile.normalizedOccupiedPositions }
    var availablePositions: Int { profile.availablePositions }
    var unavailablePositions: Int { profile.unavailablePositions }
    var utilization: Double { profile.utilization }
}

struct ConsolidationMove: Identifiable, Hashable {
    let id = UUID()
    let targetZoneID: UUID
    let targetZoneName: String
    let positionCount: Int
}

struct ConsolidationRecommendation: Identifiable, Hashable {
    let id = UUID()
    let sourceZoneID: UUID
    let sourceZoneName: String
    let layout: StorageLayoutType
    let constraintClass: StorageConstraintClass
    let moves: [ConsolidationMove]
    let releasedSquareFeet: Double
    let isAlreadyEmpty: Bool

    var movedPositionCount: Int {
        moves.reduce(0) { $0 + $1.positionCount }
    }

    var summary: String {
        if isAlreadyEmpty {
            return "\(sourceZoneName) is already empty and can be reassigned."
        }

        if moves.count == 1, let move = moves.first {
            return "Move \(move.positionCount) positions into \(move.targetZoneName) to empty \(sourceZoneName)."
        }

        return "Split \(movedPositionCount) positions across \(moves.count) compatible zones to empty \(sourceZoneName)."
    }
}

struct WarehouseCapacitySnapshot {
    let zones: [ZoneCapacitySnapshot]
    let recommendations: [ConsolidationRecommendation]
    let unconfiguredZoneCount: Int

    var configuredZoneCount: Int { zones.count }
    var totalPositions: Int { zones.reduce(0) { $0 + $1.totalPositions } }
    var usablePositions: Int { zones.reduce(0) { $0 + $1.usablePositions } }
    var occupiedPositions: Int { zones.reduce(0) { $0 + $1.occupiedPositions } }
    var availablePositions: Int { zones.reduce(0) { $0 + $1.availablePositions } }
    var unavailablePositions: Int { zones.reduce(0) { $0 + $1.unavailablePositions } }

    var utilization: Double {
        guard usablePositions > 0 else {
            return 0
        }
        return Double(occupiedPositions) / Double(usablePositions)
    }

    var releasableZoneCount: Int {
        recommendations.count
    }

    var releasableSquareFeet: Double {
        recommendations.reduce(0) { $0 + $1.releasedSquareFeet }
    }

    var fragmentedOpenPositions: Int {
        zones
            .filter { $0.occupiedPositions > 0 && $0.availablePositions > 0 }
            .reduce(0) { $0 + $1.availablePositions }
    }
}

enum WarehouseCapacityEngine {
    static func analyze(_ plan: WarehousePlan) -> WarehouseCapacitySnapshot {
        let configured = plan.zones.compactMap { zone -> ZoneCapacitySnapshot? in
            guard let profile = zone.capacityProfile,
                  profile.totalPositions > 0 else {
                return nil
            }
            return ZoneCapacitySnapshot(zone: zone, profile: profile)
        }

        return WarehouseCapacitySnapshot(
            zones: configured.sorted {
                if $0.utilization == $1.utilization {
                    return $0.zone.name < $1.zone.name
                }
                return $0.utilization < $1.utilization
            },
            recommendations: buildRecommendations(from: configured),
            unconfiguredZoneCount: max(0, plan.zones.count - configured.count)
        )
    }

    private static func buildRecommendations(
        from zones: [ZoneCapacitySnapshot]
    ) -> [ConsolidationRecommendation] {
        var simulatedOccupied = Dictionary(
            uniqueKeysWithValues: zones.map {
                ($0.id, $0.occupiedPositions)
            }
        )
        var released = Set<UUID>()
        var recommendations: [ConsolidationRecommendation] = []

        let emptyZones = zones
            .filter { $0.occupiedPositions == 0 && $0.usablePositions > 0 }
            .sorted { $0.zone.footprintSquareFeet > $1.zone.footprintSquareFeet }

        for empty in emptyZones {
            released.insert(empty.id)
            recommendations.append(
                ConsolidationRecommendation(
                    sourceZoneID: empty.id,
                    sourceZoneName: empty.zone.name,
                    layout: empty.profile.layout,
                    constraintClass: empty.profile.constraintClass,
                    moves: [],
                    releasedSquareFeet: empty.zone.footprintSquareFeet,
                    isAlreadyEmpty: true
                )
            )
        }

        let donors = zones
            .filter {
                $0.occupiedPositions > 0
                    && $0.availablePositions > 0
                    && $0.utilization <= 0.60
            }
            .sorted {
                if $0.utilization == $1.utilization {
                    return $0.occupiedPositions < $1.occupiedPositions
                }
                return $0.utilization < $1.utilization
            }

        for donor in donors where !released.contains(donor.id) {
            let amountToMove = simulatedOccupied[donor.id] ?? 0
            guard amountToMove > 0 else {
                continue
            }

            var remaining = amountToMove
            var moves: [ConsolidationMove] = []

            let targets = zones
                .filter {
                    $0.id != donor.id
                        && !released.contains($0.id)
                        && $0.profile.isCompatible(with: donor.profile)
                        && (simulatedOccupied[$0.id] ?? 0)
                            < $0.usablePositions
                        && $0.utilization >= donor.utilization
                }
                .sorted {
                    let left = Double(simulatedOccupied[$0.id] ?? 0)
                        / Double(max(1, $0.usablePositions))
                    let right = Double(simulatedOccupied[$1.id] ?? 0)
                        / Double(max(1, $1.usablePositions))
                    return left > right
                }

            let availableCapacity = targets.reduce(0) { partial, target in
                partial + max(
                    0,
                    target.usablePositions
                        - (simulatedOccupied[target.id] ?? 0)
                )
            }

            guard availableCapacity >= amountToMove else {
                continue
            }

            for target in targets where remaining > 0 {
                let targetOccupied = simulatedOccupied[target.id] ?? 0
                let openPositions = max(
                    0,
                    target.usablePositions - targetOccupied
                )
                let moved = min(remaining, openPositions)
                guard moved > 0 else {
                    continue
                }

                moves.append(
                    ConsolidationMove(
                        targetZoneID: target.id,
                        targetZoneName: target.zone.name,
                        positionCount: moved
                    )
                )
                simulatedOccupied[target.id] = targetOccupied + moved
                remaining -= moved
            }

            guard remaining == 0 else {
                continue
            }

            simulatedOccupied[donor.id] = 0
            released.insert(donor.id)
            recommendations.append(
                ConsolidationRecommendation(
                    sourceZoneID: donor.id,
                    sourceZoneName: donor.zone.name,
                    layout: donor.profile.layout,
                    constraintClass: donor.profile.constraintClass,
                    moves: moves,
                    releasedSquareFeet: donor.zone.footprintSquareFeet,
                    isAlreadyEmpty: false
                )
            )
        }

        return recommendations.sorted {
            if $0.isAlreadyEmpty != $1.isAlreadyEmpty {
                return !$0.isAlreadyEmpty
            }
            return $0.releasedSquareFeet > $1.releasedSquareFeet
        }
    }
}
