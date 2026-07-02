//
//  Models.swift
//  RoostRepair
//
//  All Codable data structures + supporting enums.
//  These are the shared contract used by every screen and the FarmStore.
//

import SwiftUI

// MARK: - Bird types

enum BirdType: String, Codable, CaseIterable, Identifiable {
    case chicken, duck, turkey, quail, goose, guinea

    var id: String { rawValue }
    var title: String {
        switch self {
        case .chicken: return "Chickens"
        case .duck:    return "Ducks"
        case .turkey:  return "Turkeys"
        case .quail:   return "Quail"
        case .goose:   return "Geese"
        case .guinea:  return "Guinea Fowl"
        }
    }
    var symbol: String {
        switch self {
        case .chicken: return "oval.fill"
        case .duck:    return "oval.portrait.fill"
        case .turkey:  return "sparkles"
        case .quail:   return "leaf.fill"
        case .goose:   return "wind"
        case .guinea:  return "circle.grid.cross.fill"
        }
    }
    /// Approximate perch length needed per bird (cm) — used by the capacity tool.
    var perchPerBirdCM: Double {
        switch self {
        case .chicken: return 20
        case .duck:    return 0      // ducks don't perch
        case .turkey:  return 38
        case .quail:   return 10
        case .goose:   return 0
        case .guinea:  return 18
        }
    }
    /// Approximate floor space needed per bird (m²).
    var spacePerBirdM2: Double {
        switch self {
        case .chicken: return 0.37
        case .duck:    return 0.45
        case .turkey:  return 0.75
        case .quail:   return 0.10
        case .goose:   return 0.90
        case .guinea:  return 0.30
        }
    }
}

// MARK: - Care priorities (onboarding 3 + dashboard ranking)

enum CarePriority: String, Codable, CaseIterable, Identifiable {
    case health, feed, cleaning, transport

    var id: String { rawValue }
    var title: String {
        switch self {
        case .health:    return "Health"
        case .feed:      return "Feed"
        case .cleaning:  return "Cleaning"
        case .transport: return "Transport"
        }
    }
    var symbol: String {
        switch self {
        case .health:    return "heart.text.square.fill"
        case .feed:      return "bag.fill"
        case .cleaning:  return "sparkles"
        case .transport: return "shippingbox.fill"
        }
    }
    var tint: Color {
        switch self {
        case .health:    return Theme.barnRed
        case .feed:      return Theme.amberDeep
        case .cleaning:  return Theme.info
        case .transport: return Theme.wood
        }
    }
}

// MARK: - Farm board visual mode (onboarding 1)

enum FarmViewMode: String, Codable, CaseIterable, Identifiable {
    case coopMap, routeList, ledger

    var id: String { rawValue }
    var title: String {
        switch self {
        case .coopMap:   return "Coop Map"
        case .routeList: return "Route List"
        case .ledger:    return "Ledger View"
        }
    }
    var subtitle: String {
        switch self {
        case .coopMap:   return "Zone cards laid out as a board"
        case .routeList: return "An ordered walk-through list"
        case .ledger:    return "Compact rows, record-first"
        }
    }
    var symbol: String {
        switch self {
        case .coopMap:   return "square.grid.2x2.fill"
        case .routeList: return "list.bullet.below.rectangle"
        case .ledger:    return "tablecells.fill"
        }
    }
}

// MARK: - Priorities / status

enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case low, medium, high

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var rank: Int { self == .high ? 0 : (self == .medium ? 1 : 2) }
    var tint: Color {
        switch self {
        case .high:   return Theme.danger
        case .medium: return Theme.warn
        case .low:    return Theme.ok
        }
    }
}

// MARK: - Zones (Screen 23)

enum ZoneKind: String, Codable, CaseIterable, Identifiable {
    case coop, yard, run, quarantine, transport

    var id: String { rawValue }
    var title: String {
        switch self {
        case .coop:       return "Coop"
        case .yard:       return "Yard"
        case .run:        return "Run / Aviary"
        case .quarantine: return "Quarantine"
        case .transport:  return "Transport Point"
        }
    }
    var symbol: String {
        switch self {
        case .coop:       return "house.fill"
        case .yard:       return "leaf.fill"
        case .run:        return "square.dashed"
        case .quarantine: return "cross.case.fill"
        case .transport:  return "car.fill"
        }
    }
}

struct Zone: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var kind: ZoneKind
    var notes: String = ""
    var order: Int = 0
}

// MARK: - Bird groups (Screen 22)

struct BirdGroup: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var type: BirdType
    var count: Int
    var zoneID: UUID?
    var colorHex: UInt = 0xE8A33D
    var flagged: Bool = false
    var createdAt: Date = Date()

    var color: Color { Color(hex: colorHex) }
}

// MARK: - Care logs (the unified journal)

enum CareLogKind: String, Codable, CaseIterable, Identifiable {
    case feeding, water, cleaning, health, repair, move, note

    var id: String { rawValue }
    var title: String {
        switch self {
        case .feeding:  return "Feeding"
        case .water:    return "Water Check"
        case .cleaning: return "Cleaning"
        case .health:   return "Observation"
        case .repair:   return "Repair"
        case .move:     return "Move / Transport"
        case .note:     return "Note"
        }
    }
    var symbol: String {
        switch self {
        case .feeding:  return "bag.fill"
        case .water:    return "drop.fill"
        case .cleaning: return "sparkles"
        case .health:   return "stethoscope"
        case .repair:   return "wrench.and.screwdriver.fill"
        case .move:     return "arrow.left.arrow.right"
        case .note:     return "note.text"
        }
    }
    var tint: Color {
        switch self {
        case .feeding:  return Theme.amberDeep
        case .water:    return Theme.info
        case .cleaning: return Color(hex: 0x6FA45C)
        case .health:   return Theme.barnRed
        case .repair:   return Theme.wood
        case .move:     return Color(hex: 0x8A6BB0)
        case .note:     return Theme.textSecondary
        }
    }
}

struct CareLog: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var kind: CareLogKind
    var title: String
    var detail: String = ""
    var groupID: UUID?
    var zoneID: UUID?
    var date: Date = Date()
}

// MARK: - Tasks (Screen 12)

struct FarmTask: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var detail: String = ""
    var priority: TaskPriority = .medium
    var zoneID: UUID?
    var dueDate: Date?
    var done: Bool = false
    var createdAt: Date = Date()

    var isOverdue: Bool {
        guard let due = dueDate, !done else { return false }
        return due < Calendar.current.startOfDay(for: Date())
    }
}

// MARK: - Inventory (Screen 10)

enum InventoryCategory: String, Codable, CaseIterable, Identifiable {
    case feed, bedding, supplement, hardware, waterer, other

    var id: String { rawValue }
    var title: String {
        switch self {
        case .feed:       return "Feed"
        case .bedding:    return "Bedding"
        case .supplement: return "Supplement"
        case .hardware:   return "Hardware"
        case .waterer:    return "Waterer Parts"
        case .other:      return "Other"
        }
    }
    var symbol: String {
        switch self {
        case .feed:       return "bag.fill"
        case .bedding:    return "square.stack.3d.up.fill"
        case .supplement: return "pills.fill"
        case .hardware:   return "wrench.and.screwdriver.fill"
        case .waterer:    return "drop.triangle.fill"
        case .other:      return "shippingbox.fill"
        }
    }
}

struct InventoryItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var category: InventoryCategory
    var quantity: Double
    var unit: String = "units"
    var minLevel: Double = 0

    var isLow: Bool { quantity <= minLevel }
}

// MARK: - Costs (Screen 11)

enum CostCategory: String, Codable, CaseIterable, Identifiable {
    case feed, bedding, equipment, repair, transport, vet, other

    var id: String { rawValue }
    var title: String { self == .vet ? "Vet / Care" : rawValue.capitalized }
    var symbol: String {
        switch self {
        case .feed:      return "bag.fill"
        case .bedding:   return "square.stack.3d.up.fill"
        case .equipment: return "hammer.fill"
        case .repair:    return "wrench.and.screwdriver.fill"
        case .transport: return "car.fill"
        case .vet:       return "cross.case.fill"
        case .other:     return "tag.fill"
        }
    }
    var tint: Color {
        switch self {
        case .feed:      return Theme.amberDeep
        case .bedding:   return Theme.wood
        case .equipment: return Theme.info
        case .repair:    return Theme.rust
        case .transport: return Color(hex: 0x8A6BB0)
        case .vet:       return Theme.barnRed
        case .other:     return Theme.textSecondary
        }
    }
}

struct CostEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var amount: Double
    var category: CostCategory
    var groupID: UUID?
    var date: Date = Date()
}

// MARK: - Notes (Screen 14)

struct FarmNote: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var body: String = ""
    var tag: String = ""
    var zoneID: UUID?
    var groupID: UUID?
    var date: Date = Date()
}

// MARK: - Reminders (Screen 13)

enum ReminderKind: String, Codable, CaseIterable, Identifiable {
    case morning, evening, transport, cleaning, custom

    var id: String { rawValue }
    var title: String {
        switch self {
        case .morning:   return "Morning Round"
        case .evening:   return "Evening Round"
        case .transport: return "Transport"
        case .cleaning:  return "Cleaning"
        case .custom:    return "Custom"
        }
    }
    var symbol: String {
        switch self {
        case .morning:   return "sunrise.fill"
        case .evening:   return "moon.stars.fill"
        case .transport: return "car.fill"
        case .cleaning:  return "sparkles"
        case .custom:    return "bell.fill"
        }
    }
}

struct Reminder: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var kind: ReminderKind
    var hour: Int = 7
    var minute: Int = 0
    var enabled: Bool = true

    var notificationID: String { "roost-reminder-\(id.uuidString)" }

    var timeText: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

// MARK: - Routes (Screen 8)

struct RouteStop: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var zoneID: UUID?
    var label: String
    var minutes: Int = 5
    var checked: Bool = false
}

struct CareRoute: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var stops: [RouteStop] = []
    var createdAt: Date = Date()

    var totalMinutes: Int { stops.reduce(0) { $0 + $1.minutes } }
}

// MARK: - Transport crates (Screen 9)

struct Crate: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var label: String
    var birdCount: Int
    var groupID: UUID?
    var loaded: Bool = false
}

// MARK: - Capacity results (Screen 2)

struct CapacityResult: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var area: Double          // m²
    var perchLength: Double    // cm
    var birds: Int
    var buffer: Double         // % extra space wanted
    var zoneName: String = ""
    var date: Date = Date()
    /// 0 = comfortable ... 1 = overloaded
    var load: Double
    var verdict: String
}

// MARK: - Cleaning tasks (Screen 7)

struct CleaningTask: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var zoneID: UUID?
    var dueDate: Date
    var intervalDays: Int = 7
    var lastDone: Date?

    var isOverdue: Bool { dueDate < Calendar.current.startOfDay(for: Date()) }
}

// MARK: - Daily checklist (Screen 3) — stored per-day

struct ChecklistDay: Codable, Hashable {
    var dayKey: String                     // yyyy-MM-dd
    var items: [String: Bool] = [:]        // itemID -> done
}

// MARK: - Photo notes (Screen 15)

struct PhotoNote: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var fileName: String                   // stored in Documents
    var caption: String = ""
    var zoneID: UUID?
    // Normalised marker position (0...1) on the image.
    var markerX: Double = 0.5
    var markerY: Double = 0.5
    var hasMarker: Bool = false
    var date: Date = Date()
}
