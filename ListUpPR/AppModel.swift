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
    var entered: Bool = false
    var entryTime: Date? = nil

    var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
    var remaining: Double { max(0, price - deposit) }
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

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() { load() }

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
        seedFirstEventIfNeeded()
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

    func addGuest(_ guest: Guest, to eventID: UUID) {
        guestsByEvent[eventID, default: []].append(guest)
        save()
    }

    func toggleEntry(guestID: UUID, eventID: UUID) {
        guard let index = guestsByEvent[eventID]?.firstIndex(where: { $0.id == guestID }) else { return }
        guestsByEvent[eventID]?[index].entered.toggle()
        guestsByEvent[eventID]?[index].entryTime = guestsByEvent[eventID]?[index].entered == true ? .now : nil
        save()
    }

    func deleteGuest(_ guest: Guest, eventID: UUID) {
        guestsByEvent[eventID]?.removeAll { $0.id == guest.id }
        save()
    }

    func updateTheme(_ newTheme: AppTheme) { theme = newTheme; save() }
    func updateSync(_ enabled: Bool) { syncEnabled = enabled; save() }

    func resetAllData() {
        profile = nil; selectedRole = nil; events = []; guestsByEvent = [:]; entranceCode = ""
        defaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "ListUpPR")
    }

    private func seedFirstEventIfNeeded() {
        guard events.isEmpty else { return }
        let event = PREvent(name: "Serata inaugurale", venue: "Nome discoteca", date: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)
        events = [event]
        guestsByEvent[event.id] = []
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
