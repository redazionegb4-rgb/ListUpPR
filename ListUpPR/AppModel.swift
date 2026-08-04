import Foundation
import SwiftUI

struct PREvent: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var venue: String
    var date: Date
    var isActive: Bool = true
}

struct Guest: Identifiable, Codable, Hashable {
    var id = UUID()
    var firstName: String
    var lastName: String
    var listName: String
    var packageName: String
    var price: Double
    var deposit: Double
    var notes: String
    var phone: String? = nil
    var qrToken: UUID? = nil
    var entered: Bool = false
    var entryTime: Date? = nil

    var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
    var remaining: Double { max(0, price - deposit) }
    var effectiveQRToken: UUID { qrToken ?? id }
}

struct PRProfile: Codable, Hashable {
    var name: String
    var code: String
    var password: String
}

@MainActor
final class AppModel: ObservableObject {
    enum AppRole: String, Codable { case pr, entrance }
    enum AppTheme: String, CaseIterable, Codable, Identifiable {
        case automatic = "Automatico", light = "Chiaro", dark = "Scuro"
        var id: String { rawValue }
        var colorScheme: ColorScheme? {
            switch self { case .automatic: nil; case .light: .light; case .dark: .dark }
        }
    }

    @Published var profile: PRProfile?
    @Published var selectedRole: AppRole?
    @Published var events: [PREvent] = []
    @Published var guestsByEvent: [UUID: [Guest]] = [:]
    @Published var entranceCode = ""
    @Published var theme: AppTheme = .dark
    @Published var syncEnabled = true
    @Published var lastEntry: (eventID: UUID, guestID: UUID)?
    @Published var lastRefresh = Date()

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        load()
        removeLegacyDemoDataIfNeeded()
    }

    var allGuests: [Guest] { events.flatMap { guestsByEvent[$0.id] ?? [] } }
    var totalPeople: Int { allGuests.count }
    var enteredPeople: Int { allGuests.filter(\.entered).count }
    var activeEvent: PREvent? { events.sorted { $0.date < $1.date }.first(where: { $0.isActive }) }

    func registerPR(name: String, password: String) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, password.count >= 4 else { return false }
        let code = String(format: "%03d", Int.random(in: 100...999))
        profile = PRProfile(name: cleanName, code: code, password: password)
        selectedRole = .pr
        save()
        return true
    }

    func loginAsPR(code: String, password: String) -> Bool {
        guard let profile else { return false }
        let cleanCode = code.filter(\.isNumber)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let codeMatches = !cleanCode.isEmpty && cleanCode == profile.code
        let passwordMatches = !cleanPassword.isEmpty && cleanPassword == profile.password
        guard codeMatches || passwordMatches else { return false }
        selectedRole = .pr
        save()
        return true
    }

    func loginEntrance(code: String) -> Bool {
        let clean = code.filter(\.isNumber)
        guard clean.count == 3, clean == profile?.code else { return false }
        entranceCode = clean
        selectedRole = .entrance
        save()
        return true
    }

    func logout() {
        selectedRole = nil
        entranceCode = ""
        save()
    }

    func addEvent(_ event: PREvent) {
        events.insert(event, at: 0)
        guestsByEvent[event.id] = []
        save()
    }

    func deleteEvent(_ event: PREvent) {
        events.removeAll { $0.id == event.id }
        guestsByEvent[event.id] = nil
        save()
    }

    @discardableResult
    func duplicateEvent(_ event: PREvent) -> PREvent {
        let copy = PREvent(
            name: "\(event.name) - Copia",
            venue: event.venue,
            date: Calendar.current.date(byAdding: .day, value: 7, to: event.date) ?? event.date,
            isActive: event.isActive
        )
        events.insert(copy, at: 0)
        guestsByEvent[copy.id] = (guestsByEvent[event.id] ?? []).map { guest in
            Guest(
                firstName: guest.firstName,
                lastName: guest.lastName,
                listName: guest.listName,
                packageName: guest.packageName,
                price: guest.price,
                deposit: guest.deposit,
                notes: guest.notes,
                phone: guest.phone,
                qrToken: UUID(),
                entered: false,
                entryTime: nil
            )
        }
        save()
        return copy
    }

    func addGuest(_ guest: Guest, to eventID: UUID) {
        var newGuest = guest
        if newGuest.qrToken == nil { newGuest.qrToken = UUID() }
        guestsByEvent[eventID, default: []].append(newGuest)
        save()
    }

    func checkInFromQRCode(_ encoded: String, expectedEventID: UUID) -> String {
        let prefix = "LISTUPPR|2|"
        guard encoded.hasPrefix(prefix),
              let data = Data(base64Encoded: String(encoded.dropFirst(prefix.count))),
              let payload = try? decoder.decode(GuestQRPayload.self, from: data),
              payload.version == 2 else { return "QR non valido o non generato da ListUp PR" }
        guard payload.eventID == expectedEventID else { return "Il QR appartiene a un altro evento" }
        guard payload.prCode == profile?.code else { return "Il QR appartiene a un altro PR" }
        guard var guests = guestsByEvent[payload.eventID],
              let index = guests.firstIndex(where: { $0.id == payload.guestID }) else { return "Cliente non trovato" }
        guard payload.token == guests[index].effectiveQRToken else { return "QR non valido per questo cliente" }
        if guests[index].entered { return "\(guests[index].fullName) risulta già entrato" }
        guests[index].entered = true
        guests[index].entryTime = .now
        guestsByEvent[payload.eventID] = guests
        lastEntry = (payload.eventID, payload.guestID)
        save()
        return "Ingresso confermato: \(guests[index].fullName)"
    }

    func toggleEntry(guestID: UUID, eventID: UUID) {
        guard var guests = guestsByEvent[eventID],
              let index = guests.firstIndex(where: { $0.id == guestID }) else { return }
        guests[index].entered.toggle()
        guests[index].entryTime = guests[index].entered ? .now : nil
        guestsByEvent[eventID] = guests
        lastEntry = guests[index].entered ? (eventID, guestID) : nil
        save()
    }

    func undoLastEntry() {
        guard let lastEntry,
              var guests = guestsByEvent[lastEntry.eventID],
              let index = guests.firstIndex(where: { $0.id == lastEntry.guestID }) else { return }
        guests[index].entered = false
        guests[index].entryTime = nil
        guestsByEvent[lastEntry.eventID] = guests
        self.lastEntry = nil
        save()
    }


    func updateGuest(_ guest: Guest, eventID: UUID) {
        guard var guests = guestsByEvent[eventID],
              let index = guests.firstIndex(where: { $0.id == guest.id }) else { return }
        guests[index] = guest
        guestsByEvent[eventID] = guests
        save()
    }

    func hasDuplicateGuest(firstName: String, lastName: String, eventID: UUID, excluding guestID: UUID? = nil) -> Bool {
        let target = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        guard !target.isEmpty else { return false }
        return (guestsByEvent[eventID] ?? []).contains { guest in
            guard guest.id != guestID else { return false }
            return guest.fullName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) == target
        }
    }

    func copyGuests(from sourceEventID: UUID, to destinationEventID: UUID) {
        let copies = (guestsByEvent[sourceEventID] ?? []).map { guest in
            Guest(firstName: guest.firstName, lastName: guest.lastName, listName: guest.listName, packageName: guest.packageName, price: guest.price, deposit: guest.deposit, notes: guest.notes, phone: guest.phone, qrToken: UUID(), entered: false, entryTime: nil)
        }
        guestsByEvent[destinationEventID, default: []].append(contentsOf: copies)
        save()
    }

    func deleteGuest(_ guest: Guest, eventID: UUID) {
        guestsByEvent[eventID]?.removeAll { $0.id == guest.id }
        save()
    }

    func markBalancePaid(guestID: UUID, eventID: UUID) {
        guard var guests = guestsByEvent[eventID],
              let index = guests.firstIndex(where: { $0.id == guestID }) else { return }
        guests[index].deposit = guests[index].price
        guestsByEvent[eventID] = guests
        save()
    }

    func updateTheme(_ newTheme: AppTheme) { theme = newTheme; save() }

    func refreshFromStorage() {
        load()
        lastRefresh = .now
    }

    func updateProfile(name: String? = nil, password: String? = nil) {
        guard var current = profile else { return }
        if let name {
            let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { current.name = clean }
        }
        if let password, password.count >= 4 { current.password = password }
        profile = current
        save()
    }
    func updateSync(_ enabled: Bool) { syncEnabled = enabled; save() }

    func resetAllData() {
        profile = nil; selectedRole = nil; events = []; guestsByEvent = [:]; entranceCode = ""
        defaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "ListUpPR")
    }

    private func removeLegacyDemoDataIfNeeded() {
        let demoIDs = events.filter {
            $0.name == "Serata inaugurale" && $0.venue == "Nome discoteca" && (guestsByEvent[$0.id] ?? []).isEmpty
        }.map(\.id)
        guard !demoIDs.isEmpty else { return }
        events.removeAll { demoIDs.contains($0.id) }
        demoIDs.forEach { guestsByEvent[$0] = nil }
        save()
    }

    func save() {
        if let profile, let data = try? encoder.encode(profile) { defaults.set(data, forKey: "profile.v2") }
        if let data = try? encoder.encode(events) { defaults.set(data, forKey: "events.v2") }
        let map = guestsByEvent.reduce(into: [String: [Guest]]()) { $0[$1.key.uuidString] = $1.value }
        if let data = try? encoder.encode(map) { defaults.set(data, forKey: "guests.v2") }
        defaults.set(selectedRole?.rawValue, forKey: "role.v2")
        defaults.set(entranceCode, forKey: "entranceCode.v2")
        defaults.set(theme.rawValue, forKey: "theme.v2")
        defaults.set(syncEnabled, forKey: "sync.v2")
    }

    private func load() {
        if let data = defaults.data(forKey: "profile.v2") { profile = try? decoder.decode(PRProfile.self, from: data) }
        if let data = defaults.data(forKey: "events.v2") { events = (try? decoder.decode([PREvent].self, from: data)) ?? [] }
        if let data = defaults.data(forKey: "guests.v2"), let map = try? decoder.decode([String: [Guest]].self, from: data) {
            guestsByEvent = Dictionary(uniqueKeysWithValues: map.compactMap { key, value in UUID(uuidString: key).map { ($0, value) } })
        }
        if let raw = defaults.string(forKey: "role.v2") { selectedRole = AppRole(rawValue: raw) }
        entranceCode = defaults.string(forKey: "entranceCode.v2") ?? ""
        theme = AppTheme(rawValue: defaults.string(forKey: "theme.v2") ?? "") ?? .dark
        syncEnabled = defaults.object(forKey: "sync.v2") as? Bool ?? true
    }
}
