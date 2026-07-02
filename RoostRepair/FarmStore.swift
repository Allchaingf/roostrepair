//
//  FarmStore.swift
//  RoostRepair
//
//  The single source of truth (Model layer). Holds every collection, performs
//  all CRUD, persists each change to UserDefaults, seeds sample data and derives
//  dashboard / analytics / risk values. Injected app-wide as an @EnvironmentObject.
//

import SwiftUI
import Combine

// Computed-only risk signal shown on the Dashboard & Risk Flags screen.
struct RiskFlag: Identifiable, Hashable {
    enum Severity: Int { case info = 0, warn = 1, high = 2
        var tint: Color {
            switch self {
            case .info: return Theme.info
            case .warn: return Theme.warn
            case .high: return Theme.danger
            }
        }
        var title: String {
            switch self { case .info: return "Info"; case .warn: return "Watch"; case .high: return "Urgent" }
        }
    }
    var id = UUID()
    var title: String
    var detail: String
    var severity: Severity
    var symbol: String
}

// A single point for the tiny custom charts on Analytics.
struct DayMetric: Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var label: String
    var logs: Int
    var cost: Double
    var completion: Double  // 0...1
}

final class FarmStore: ObservableObject {

    // MARK: Persisted collections
    @Published var groups: [BirdGroup]          { didSet { persist(groups, .groups) } }
    @Published var zones: [Zone]                { didSet { persist(zones, .zones) } }
    @Published var logs: [CareLog]              { didSet { persist(logs, .logs) } }
    @Published var tasks: [FarmTask]            { didSet { persist(tasks, .tasks) } }
    @Published var inventory: [InventoryItem]   { didSet { persist(inventory, .inventory) } }
    @Published var costs: [CostEntry]           { didSet { persist(costs, .costs) } }
    @Published var notes: [FarmNote]            { didSet { persist(notes, .notes) } }
    @Published var reminders: [Reminder]        { didSet { persist(reminders, .reminders) } }
    @Published var routes: [CareRoute]          { didSet { persist(routes, .routes) } }
    @Published var crates: [Crate]              { didSet { persist(crates, .crates) } }
    @Published var capacityResults: [CapacityResult] { didSet { persist(capacityResults, .capacity) } }
    @Published var cleaningTasks: [CleaningTask] { didSet { persist(cleaningTasks, .cleaning) } }
    @Published var checklistDays: [ChecklistDay] { didSet { persist(checklistDays, .checklist) } }
    @Published var photos: [PhotoNote]          { didSet { persist(photos, .photos) } }
    @Published var resolvedFlags: Set<String>   { didSet { persistRaw(Array(resolvedFlags), .resolvedFlags) } }

    private enum Key: String {
        case groups, zones, logs, tasks, inventory, costs, notes, reminders
        case routes, crates, capacity, cleaning, checklist, photos, resolvedFlags, seeded
    }

    private func persist<T: Encodable>(_ value: T, _ key: Key) {
        Persistence.save(value, key: key.rawValue)
    }
    private func persistRaw(_ value: [String], _ key: Key) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    // MARK: Init
    init() {
        groups = Persistence.load([BirdGroup].self, key: Key.groups.rawValue) ?? []
        zones = Persistence.load([Zone].self, key: Key.zones.rawValue) ?? []
        logs = Persistence.load([CareLog].self, key: Key.logs.rawValue) ?? []
        tasks = Persistence.load([FarmTask].self, key: Key.tasks.rawValue) ?? []
        inventory = Persistence.load([InventoryItem].self, key: Key.inventory.rawValue) ?? []
        costs = Persistence.load([CostEntry].self, key: Key.costs.rawValue) ?? []
        notes = Persistence.load([FarmNote].self, key: Key.notes.rawValue) ?? []
        reminders = Persistence.load([Reminder].self, key: Key.reminders.rawValue) ?? []
        routes = Persistence.load([CareRoute].self, key: Key.routes.rawValue) ?? []
        crates = Persistence.load([Crate].self, key: Key.crates.rawValue) ?? []
        capacityResults = Persistence.load([CapacityResult].self, key: Key.capacity.rawValue) ?? []
        cleaningTasks = Persistence.load([CleaningTask].self, key: Key.cleaning.rawValue) ?? []
        checklistDays = Persistence.load([ChecklistDay].self, key: Key.checklist.rawValue) ?? []
        photos = Persistence.load([PhotoNote].self, key: Key.photos.rawValue) ?? []
        resolvedFlags = Set(UserDefaults.standard.stringArray(forKey: Key.resolvedFlags.rawValue) ?? [])

        // Seed a starter farm exactly once so the offline app is never empty on
        // first launch (idempotent — guarded by the "seeded" flag; never
        // overwrites the user's own records afterwards).
        seedSampleDataIfNeeded()
    }

    // MARK: - Lookups
    func group(_ id: UUID?) -> BirdGroup? { groups.first { $0.id == id } }
    func zone(_ id: UUID?) -> Zone? { zones.first { $0.id == id } }
    func groupName(_ id: UUID?) -> String { group(id)?.name ?? "—" }
    func zoneName(_ id: UUID?) -> String { zone(id)?.name ?? "Unassigned" }

    var totalBirds: Int { groups.reduce(0) { $0 + $1.count } }

    // MARK: - Generic CRUD helpers
    func log(_ entry: CareLog) { logs.insert(entry, at: 0) }
    func deleteLog(_ entry: CareLog) { logs.removeAll { $0.id == entry.id } }

    // MARK: - Groups
    func addGroup(_ g: BirdGroup) { groups.append(g) }
    func updateGroup(_ g: BirdGroup) { if let i = groups.firstIndex(where: { $0.id == g.id }) { groups[i] = g } }
    func deleteGroup(_ g: BirdGroup) {
        groups.removeAll { $0.id == g.id }
        logs.removeAll { $0.groupID == g.id }
    }
    func toggleGroupFlag(_ g: BirdGroup) {
        if let i = groups.firstIndex(where: { $0.id == g.id }) { groups[i].flagged.toggle() }
    }

    // MARK: - Zones
    func addZone(_ z: Zone) {
        var z = z
        z.order = zones.count
        zones.append(z)
    }
    func updateZone(_ z: Zone) { if let i = zones.firstIndex(where: { $0.id == z.id }) { zones[i] = z } }
    func deleteZone(_ z: Zone) { zones.removeAll { $0.id == z.id }; reindexZones() }
    func moveZones(from: IndexSet, to: Int) { zones.move(fromOffsets: from, toOffset: to); reindexZones() }
    private func reindexZones() { for i in zones.indices { zones[i].order = i } }
    var sortedZones: [Zone] { zones.sorted { $0.order < $1.order } }

    // MARK: - Tasks
    func addTask(_ t: FarmTask) { tasks.append(t) }
    func updateTask(_ t: FarmTask) { if let i = tasks.firstIndex(where: { $0.id == t.id }) { tasks[i] = t } }
    func deleteTask(_ t: FarmTask) { tasks.removeAll { $0.id == t.id } }
    func toggleTask(_ t: FarmTask) {
        if let i = tasks.firstIndex(where: { $0.id == t.id }) {
            tasks[i].done.toggle()
            if tasks[i].done {
                log(CareLog(kind: .repair, title: "Task done: \(tasks[i].title)",
                            detail: tasks[i].detail, zoneID: tasks[i].zoneID))
            }
        }
    }
    var openTasks: [FarmTask] { tasks.filter { !$0.done }.sorted { lhs, rhs in
        if lhs.priority.rank != rhs.priority.rank { return lhs.priority.rank < rhs.priority.rank }
        return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
    } }

    // MARK: - Inventory
    func addItem(_ i: InventoryItem) { inventory.append(i) }
    func updateItem(_ i: InventoryItem) { if let idx = inventory.firstIndex(where: { $0.id == i.id }) { inventory[idx] = i } }
    func deleteItem(_ i: InventoryItem) { inventory.removeAll { $0.id == i.id } }
    func adjustStock(_ item: InventoryItem, by delta: Double) {
        if let idx = inventory.firstIndex(where: { $0.id == item.id }) {
            inventory[idx].quantity = max(0, inventory[idx].quantity + delta)
        }
    }
    var lowStock: [InventoryItem] { inventory.filter { $0.isLow } }

    // MARK: - Costs
    func addCost(_ c: CostEntry) { costs.append(c) }
    func deleteCost(_ c: CostEntry) { costs.removeAll { $0.id == c.id } }
    func updateCost(_ c: CostEntry) { if let i = costs.firstIndex(where: { $0.id == c.id }) { costs[i] = c } }
    func costThisMonth() -> Double {
        let cal = Calendar.current
        return costs.filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }
    func costFor(group id: UUID) -> Double {
        costs.filter { $0.groupID == id }.reduce(0) { $0 + $1.amount }
    }

    // MARK: - Notes
    func addNote(_ n: FarmNote) { notes.insert(n, at: 0) }
    func updateNote(_ n: FarmNote) { if let i = notes.firstIndex(where: { $0.id == n.id }) { notes[i] = n } }
    func deleteNote(_ n: FarmNote) { notes.removeAll { $0.id == n.id } }

    // MARK: - Reminders
    func addReminder(_ r: Reminder) {
        reminders.append(r)
        NotificationManager.shared.schedule(r)
    }
    func updateReminder(_ r: Reminder) {
        if let i = reminders.firstIndex(where: { $0.id == r.id }) { reminders[i] = r }
        NotificationManager.shared.schedule(r)
    }
    func deleteReminder(_ r: Reminder) {
        NotificationManager.shared.cancel(r)
        reminders.removeAll { $0.id == r.id }
    }
    func toggleReminder(_ r: Reminder) {
        if let i = reminders.firstIndex(where: { $0.id == r.id }) {
            reminders[i].enabled.toggle()
            NotificationManager.shared.schedule(reminders[i])
        }
    }
    func snooze(_ r: Reminder, minutes: Int) {
        if let i = reminders.firstIndex(where: { $0.id == r.id }) {
            var total = reminders[i].hour * 60 + reminders[i].minute + minutes
            total %= (24 * 60)
            reminders[i].hour = total / 60
            reminders[i].minute = total % 60
            NotificationManager.shared.schedule(reminders[i])
        }
    }

    // MARK: - Routes
    func addRoute(_ r: CareRoute) { routes.append(r) }
    func updateRoute(_ r: CareRoute) { if let i = routes.firstIndex(where: { $0.id == r.id }) { routes[i] = r } }
    func deleteRoute(_ r: CareRoute) { routes.removeAll { $0.id == r.id } }

    // MARK: - Crates
    func addCrate(_ c: Crate) { crates.append(c) }
    func updateCrate(_ c: Crate) { if let i = crates.firstIndex(where: { $0.id == c.id }) { crates[i] = c } }
    func deleteCrate(_ c: Crate) { crates.removeAll { $0.id == c.id } }
    func toggleCrate(_ c: Crate) { if let i = crates.firstIndex(where: { $0.id == c.id }) { crates[i].loaded.toggle() } }

    // MARK: - Capacity
    func addCapacity(_ r: CapacityResult) { capacityResults.insert(r, at: 0) }
    func deleteCapacity(_ r: CapacityResult) { capacityResults.removeAll { $0.id == r.id } }

    // MARK: - Cleaning
    func addCleaning(_ c: CleaningTask) { cleaningTasks.append(c) }
    func updateCleaning(_ c: CleaningTask) { if let i = cleaningTasks.firstIndex(where: { $0.id == c.id }) { cleaningTasks[i] = c } }
    func deleteCleaning(_ c: CleaningTask) { cleaningTasks.removeAll { $0.id == c.id } }
    func markCleaned(_ c: CleaningTask) {
        if let i = cleaningTasks.firstIndex(where: { $0.id == c.id }) {
            let cal = Calendar.current
            cleaningTasks[i].lastDone = Date()
            cleaningTasks[i].dueDate = cal.date(byAdding: .day, value: cleaningTasks[i].intervalDays, to: Date()) ?? Date()
            log(CareLog(kind: .cleaning, title: "Cleaned: \(c.title)", zoneID: c.zoneID))
        }
    }
    var overdueCleaning: [CleaningTask] { cleaningTasks.filter { $0.isOverdue } }

    // MARK: - Photos
    func addPhoto(_ p: PhotoNote) { photos.insert(p, at: 0) }
    func updatePhoto(_ p: PhotoNote) { if let i = photos.firstIndex(where: { $0.id == p.id }) { photos[i] = p } }
    func deletePhoto(_ p: PhotoNote) {
        ImageStore.delete(p.fileName)
        photos.removeAll { $0.id == p.id }
    }

    // MARK: - Daily checklist
    static func dayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    func checklist(for date: Date = Date()) -> ChecklistDay {
        let key = Self.dayKey(date)
        return checklistDays.first { $0.dayKey == key } ?? ChecklistDay(dayKey: key)
    }
    func setChecklist(_ itemID: String, done: Bool, for date: Date = Date()) {
        let key = Self.dayKey(date)
        if let i = checklistDays.firstIndex(where: { $0.dayKey == key }) {
            checklistDays[i].items[itemID] = done
        } else {
            var day = ChecklistDay(dayKey: key)
            day.items[itemID] = done
            checklistDays.append(day)
        }
    }
    /// 0...1 ratio of completed items today for `total` expected items.
    func checklistProgress(total: Int, for date: Date = Date()) -> Double {
        guard total > 0 else { return 0 }
        let done = checklist(for: date).items.values.filter { $0 }.count
        return min(1, Double(done) / Double(total))
    }

    // MARK: - Logs helpers
    func logs(on date: Date) -> [CareLog] {
        logs.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    var logsToday: [CareLog] { logs(on: Date()) }

    // MARK: - Analytics
    /// Per-day metrics for the last `days` days (oldest first).
    func recentMetrics(days: Int = 7) -> [DayMetric] {
        let cal = Calendar.current
        let fmt = DateFormatter(); fmt.dateFormat = "EEE"
        return (0..<days).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let dayLogs = logs.filter { cal.isDate($0.date, inSameDayAs: date) }
            let dayCost = costs.filter { cal.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.amount }
            let progress = checklistProgress(total: DailyChecklistCatalog.items.count, for: date)
            return DayMetric(date: date, label: fmt.string(from: date),
                             logs: dayLogs.count, cost: dayCost, completion: progress)
        }
    }

    func costByCategory(days: Int = 30) -> [(CostCategory, Double)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        var totals: [CostCategory: Double] = [:]
        for c in costs where c.date >= cutoff { totals[c.category, default: 0] += c.amount }
        return CostCategory.allCases.compactMap { cat in
            let v = totals[cat] ?? 0
            return v > 0 ? (cat, v) : nil
        }.sorted { $0.1 > $1.1 }
    }

    func logsByKind(days: Int = 7) -> [(CareLogKind, Int)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        var totals: [CareLogKind: Int] = [:]
        for l in logs where l.date >= cutoff { totals[l.kind, default: 0] += 1 }
        return CareLogKind.allCases.compactMap { kind in
            let v = totals[kind] ?? 0
            return v > 0 ? (kind, v) : nil
        }.sorted { $0.1 > $1.1 }
    }

    /// Care consistency over the past week (0...1).
    var weeklyConsistency: Double {
        let m = recentMetrics(days: 7)
        guard !m.isEmpty else { return 0 }
        return m.reduce(0) { $0 + $1.completion } / Double(m.count)
    }

    // MARK: - Risk flags (derived)
    var riskFlags: [RiskFlag] {
        var flags: [RiskFlag] = []

        for t in tasks where t.isOverdue {
            flags.append(RiskFlag(title: "Overdue task: \(t.title)",
                                  detail: "Due \(Self.shortDate(t.dueDate))",
                                  severity: .high, symbol: "exclamationmark.triangle.fill"))
        }
        for c in overdueCleaning {
            flags.append(RiskFlag(title: "Cleaning overdue: \(c.title)",
                                  detail: "Zone \(zoneName(c.zoneID))",
                                  severity: .warn, symbol: "sparkles"))
        }
        for item in lowStock {
            flags.append(RiskFlag(title: "Low stock: \(item.name)",
                                  detail: "\(item.quantity.clean) \(item.unit) left (min \(item.minLevel.clean))",
                                  severity: .warn, symbol: "shippingbox.fill"))
        }
        for g in groups where g.flagged {
            flags.append(RiskFlag(title: "Flagged group: \(g.name)",
                                  detail: "Marked for re-check",
                                  severity: .high, symbol: "flag.fill"))
        }
        // Zone overload from latest capacity results.
        for r in capacityResults where r.load > 0.85 {
            flags.append(RiskFlag(title: "Zone overloaded: \(r.zoneName.isEmpty ? "Capacity" : r.zoneName)",
                                  detail: "Estimated load \(Int(r.load * 100))%",
                                  severity: r.load > 1 ? .high : .warn, symbol: "gauge"))
        }
        return flags.filter { !resolvedFlags.contains($0.title) }
            .sorted { $0.severity.rawValue > $1.severity.rawValue }
    }
    func resolveFlag(_ f: RiskFlag) { resolvedFlags.insert(f.title) }
    func clearResolved() { resolvedFlags.removeAll() }

    static func shortDate(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: date)
    }

    // MARK: - Priority ranking for dashboard cards
    /// Cards bubble up based on the user's selected care priorities.
    func priorityScore(for kind: CareLogKind, priorities: Set<CarePriority>) -> Int {
        switch kind {
        case .health where priorities.contains(.health): return 3
        case .feeding, .water:
            return priorities.contains(.feed) ? 3 : 1
        case .cleaning where priorities.contains(.cleaning): return 3
        case .move where priorities.contains(.transport): return 3
        default: return 0
        }
    }

    // MARK: - Sample data
    func seedSampleDataIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Key.seeded.rawValue) else { return }
        seedSampleData()
        UserDefaults.standard.set(true, forKey: Key.seeded.rawValue)
    }

    func seedSampleData() {
        let cal = Calendar.current
        let now = Date()

        let coop = Zone(name: "Main Coop", kind: .coop, notes: "Eight nest boxes, two perches.", order: 0)
        let run = Zone(name: "North Run", kind: .run, notes: "Wire mesh, shade cloth.", order: 1)
        let yard = Zone(name: "Free Yard", kind: .yard, order: 2)
        let quarantine = Zone(name: "Quarantine Pen", kind: .quarantine, order: 3)
        zones = [coop, run, yard, quarantine]

        let layers = BirdGroup(name: "Brown Layers", type: .chicken, count: 12, zoneID: coop.id, colorHex: 0xCE7C24)
        let ducks = BirdGroup(name: "Runner Ducks", type: .duck, count: 6, zoneID: run.id, colorHex: 0x4E8FA8)
        let chicks = BirdGroup(name: "Spring Chicks", type: .chicken, count: 8, zoneID: quarantine.id, colorHex: 0xE8A33D, flagged: true)
        groups = [layers, ducks, chicks]

        inventory = [
            InventoryItem(name: "Layer Pellets", category: .feed, quantity: 18, unit: "kg", minLevel: 10),
            InventoryItem(name: "Pine Shavings", category: .bedding, quantity: 3, unit: "bags", minLevel: 2),
            InventoryItem(name: "Oyster Shell", category: .supplement, quantity: 1.5, unit: "kg", minLevel: 2),
            InventoryItem(name: "Waterer Gaskets", category: .waterer, quantity: 4, unit: "pcs", minLevel: 2),
            InventoryItem(name: "Mesh Staples", category: .hardware, quantity: 40, unit: "pcs", minLevel: 20)
        ]

        costs = [
            CostEntry(title: "Feed sack", amount: 24.5, category: .feed, groupID: layers.id, date: addDays(-2)),
            CostEntry(title: "Door hinge", amount: 6.0, category: .repair, date: addDays(-4)),
            CostEntry(title: "Bedding", amount: 12.0, category: .bedding, date: addDays(-1)),
            CostEntry(title: "Mesh roll", amount: 31.0, category: .repair, date: addDays(-6))
        ]

        tasks = [
            FarmTask(title: "Fix run door latch", detail: "Latch sticks after rain.", priority: .high,
                     zoneID: run.id, dueDate: addDays(-1)),
            FarmTask(title: "Patch coop mesh", detail: "Small tear near nest box 3.", priority: .medium,
                     zoneID: coop.id, dueDate: addDays(1)),
            FarmTask(title: "Order oyster shell", priority: .low, dueDate: addDays(3))
        ]

        cleaningTasks = [
            CleaningTask(title: "Deep clean coop", zoneID: coop.id, dueDate: addDays(-1), intervalDays: 14),
            CleaningTask(title: "Refresh bedding", zoneID: coop.id, dueDate: addDays(2), intervalDays: 7),
            CleaningTask(title: "Scrub waterers", zoneID: run.id, dueDate: addDays(0), intervalDays: 3)
        ]

        logs = [
            CareLog(kind: .feeding, title: "Morning feed", detail: "Full ration", groupID: layers.id, zoneID: coop.id, date: addHours(-3)),
            CareLog(kind: .water, title: "Water topped up", groupID: ducks.id, zoneID: run.id, date: addHours(-3)),
            CareLog(kind: .repair, title: "Tightened perch bracket", zoneID: coop.id, date: addDays(-1)),
            CareLog(kind: .health, title: "Chick looks quiet", detail: "Lower appetite, watching.", groupID: chicks.id, zoneID: quarantine.id, date: addDays(-1)),
            CareLog(kind: .cleaning, title: "Raked run", zoneID: run.id, date: addDays(-2))
        ]

        notes = [
            FarmNote(title: "Mesh supplier", body: "Hardware store on Mill Rd has 1cm welded mesh.", tag: "supply", zoneID: run.id),
            FarmNote(title: "Latch idea", body: "Spring latch keeps door shut in wind.", tag: "repair", zoneID: run.id, groupID: nil)
        ]

        reminders = [
            Reminder(title: "Morning check", kind: .morning, hour: 7, minute: 0),
            Reminder(title: "Evening lock-up", kind: .evening, hour: 19, minute: 30)
        ]

        let route = CareRoute(name: "Daily Round", stops: [
            RouteStop(zoneID: coop.id, label: "Open coop & feed", minutes: 8),
            RouteStop(zoneID: run.id, label: "Check water & mesh", minutes: 6),
            RouteStop(zoneID: yard.id, label: "Free-range release", minutes: 4),
            RouteStop(zoneID: quarantine.id, label: "Observe chicks", minutes: 5)
        ])
        routes = [route]

        crates = [
            Crate(label: "Crate A", birdCount: 4, groupID: layers.id),
            Crate(label: "Crate B", birdCount: 4, groupID: layers.id)
        ]

        // A couple of past-day checklist completions to give analytics shape.
        for offset in 1...4 {
            let d = addDays(-offset)
            var day = ChecklistDay(dayKey: Self.dayKey(d))
            let pick = max(1, DailyChecklistCatalog.items.count - offset)
            for item in DailyChecklistCatalog.items.prefix(pick) { day.items[item.id] = true }
            checklistDays.append(day)
        }
        _ = cal // silence unused in some builds
        _ = now
    }

    func resetSampleData() {
        // Wipe stored photos.
        photos.forEach { ImageStore.delete($0.fileName) }
        groups = []; zones = []; logs = []; tasks = []; inventory = []; costs = []
        notes = []; routes = []; crates = []; capacityResults = []
        cleaningTasks = []; checklistDays = []; photos = []; resolvedFlags = []
        NotificationManager.shared.cancelAll()
        reminders = []
        seedSampleData()
        // Re-arm reminders.
        reminders.forEach { NotificationManager.shared.schedule($0) }
    }

    // Date helpers for seeding.
    private func addDays(_ d: Int) -> Date { Calendar.current.date(byAdding: .day, value: d, to: Date()) ?? Date() }
    private func addHours(_ h: Int) -> Date { Calendar.current.date(byAdding: .hour, value: h, to: Date()) ?? Date() }
}

// MARK: - Number formatting helper

extension Double {
    /// "12" instead of "12.0", but keeps decimals when present.
    var clean: String {
        if self == rounded() { return String(Int(self)) }
        return String(format: "%.1f", self)
    }
    func money(_ symbol: String) -> String { "\(symbol)\(String(format: "%.2f", self))" }
}

// MARK: - Daily checklist catalog (Screen 3)

enum DailyChecklistCatalog {
    struct Item: Identifiable, Hashable {
        let id: String
        let title: String
        let symbol: String
        let period: String   // "Morning" / "Evening"
    }
    static let items: [Item] = [
        Item(id: "feed_am", title: "Morning feed", symbol: "bag.fill", period: "Morning"),
        Item(id: "water_am", title: "Fresh water", symbol: "drop.fill", period: "Morning"),
        Item(id: "doors_am", title: "Open & check doors", symbol: "lock.open.fill", period: "Morning"),
        Item(id: "observe", title: "Observe the flock", symbol: "eye.fill", period: "Morning"),
        Item(id: "bedding", title: "Check bedding", symbol: "square.stack.3d.up.fill", period: "Evening"),
        Item(id: "feed_pm", title: "Evening feed", symbol: "bag.fill", period: "Evening"),
        Item(id: "lockup", title: "Lock up coop", symbol: "lock.fill", period: "Evening")
    ]
    static var morning: [Item] { items.filter { $0.period == "Morning" } }
    static var evening: [Item] { items.filter { $0.period == "Evening" } }
}
