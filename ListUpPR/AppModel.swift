import Foundation
import SwiftUI
import CloudKit

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
    var peopleCount: Int
    var listName: String
    var packageName: String
    var price: Double
    var deposit: Double
    var notes: String
    var entered: Bool = false
    var entryTime: Date? = nil

    var fullName: String { "\(firstName) \(lastName)" }
    var remaining: Double { max(0, price - deposit) }
}

struct PRProfile: Codable, Hashable {
    var name: String
    var code: String
}

@MainActor
final class AppModel: ObservableObject {
    @Published var profile: PRProfile?
    @Published var selectedRole: AppRole?
    @Published var events: [PREvent] = []
    @Published var guestsByEvent: [UUID: [Guest]] = [:]
    @Published var entranceCode: String = ""
    @Published var syncStatus: String = "Solo locale"

    enum AppRole: String, Codable { case pr, entrance }

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        load()
        if events.isEmpty {
            let demo = PREvent(name: "Sabato Night", venue: "Nova Club", date: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)
            events = [demo]
            guestsByEvent[demo.id] = [
                Guest(firstName: "Marco", lastName: "Rossi", peopleCount: 2, listName: "Lista DMB", packageName: "Ingresso + drink", price: 30, deposit: 0, notes: "Arrivo entro 00:30"),
                Guest(firstName: "Giulia", lastName: "Bianchi", peopleCount: 3, listName: "Lista DMB", packageName: "Tavolo Silver", price: 250, deposit: 100, notes: "Compleanno")
            ]
            save()
        }
    }

    func registerPR(name: String) {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        let code = "PR-\(Int.random(in: 100000...999999))"
        profile = PRProfile(name: normalized, code: code)
        selectedRole = .pr
        syncStatus = "CloudKit predisposto"
        save()
    }

    func loginAsPR() {
        selectedRole = .pr
        save()
    }

    func loginEntrance(code: String) -> Bool {
        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty else { return false }
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

    func deleteGuest(at offsets: IndexSet, eventID: UUID) {
        guestsByEvent[eventID]?.remove(atOffsets: offsets)
        save()
    }

    func save() {
        if let profile, let data = try? encoder.encode(profile) { defaults.set(data, forKey: "profile") }
        if let data = try? encoder.encode(events) { defaults.set(data, forKey: "events") }
        let map = guestsByEvent.reduce(into: [String: [Guest]]()) { $0[$1.key.uuidString] = $1.value }
        if let data = try? encoder.encode(map) { defaults.set(data, forKey: "guests") }
        defaults.set(selectedRole?.rawValue, forKey: "role")
        defaults.set(entranceCode, forKey: "entranceCode")
    }

    private func load() {
        if let data = defaults.data(forKey: "profile") { profile = try? decoder.decode(PRProfile.self, from: data) }
        if let data = defaults.data(forKey: "events") { events = (try? decoder.decode([PREvent].self, from: data)) ?? [] }
        if let data = defaults.data(forKey: "guests"), let map = try? decoder.decode([String: [Guest]].self, from: data) {
            guestsByEvent = Dictionary(uniqueKeysWithValues: map.compactMap { key, value in UUID(uuidString: key).map { ($0, value) } })
        }
        if let raw = defaults.string(forKey: "role") { selectedRole = AppRole(rawValue: raw) }
        entranceCode = defaults.string(forKey: "entranceCode") ?? ""
    }
}
