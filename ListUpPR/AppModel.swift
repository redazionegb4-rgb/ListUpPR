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
    var username: String? = nil

    var loginUsername: String { username ?? code }
}

struct PRAccount: Identifiable, Codable, Hashable {
    var id: UUID
    var profile: PRProfile
    var events: [PREvent]
    var guestsByEvent: [String: [Guest]]
    var createdAt: Date
}

struct QRCheckInResult: Identifiable {
    let id = UUID()
    let isValid: Bool
    let title: String
    let guestName: String
    let eventName: String
    let venueName: String
    let eventDate: String
    let packageName: String
    let prName: String
    let prCode: String
    let paymentTitle: String
    let paymentDetail: String
    let amountDue: Double
    let detail: String
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

    private var accounts: [PRAccount] = []
    private var activeAccountID: UUID?

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        load()
        removeLegacyDemoDataIfNeeded()
    }

    private var todayStart: Date { Calendar.current.startOfDay(for: .now) }
    func isPastEvent(_ event: PREvent) -> Bool { event.date < todayStart }
    var upcomingEvents: [PREvent] { events.filter { !isPastEvent($0) }.sorted { $0.date < $1.date } }
    var pastEvents: [PREvent] { events.filter { isPastEvent($0) }.sorted { $0.date > $1.date } }
    var activeGuests: [Guest] { upcomingEvents.flatMap { guestsByEvent[$0.id] ?? [] } }
    var allGuests: [Guest] { activeGuests }
    var totalPeople: Int { activeGuests.count }
    var enteredPeople: Int { activeGuests.filter(\.entered).count }
    var activeEvent: PREvent? { upcomingEvents.first(where: { $0.isActive }) ?? upcomingEvents.first }

    func registerPR(name: String, username: String, password: String) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanName.isEmpty, isValidUsername(cleanUsername), password.count >= 4 else { return false }
        commitActiveAccount()
        guard !accounts.contains(where: { $0.profile.loginUsername.lowercased() == cleanUsername }) else { return false }
        let usedCodes = Set(accounts.map { $0.profile.code })
        let availableCodes = (100...999).map(String.init).filter { !usedCodes.contains($0) }
        guard let code = availableCodes.randomElement() else { return false }
        let account = PRAccount(
            id: UUID(),
            profile: PRProfile(name: cleanName, code: code, password: password, username: cleanUsername),
            events: [],
            guestsByEvent: [:],
            createdAt: .now
        )
        accounts.append(account)
        activate(account)
        selectedRole = .pr
        save()
        return true
    }

    func loginAsPR(username: String, password: String) -> Bool {
        commitActiveAccount()
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUsername.isEmpty, !cleanPassword.isEmpty,
              let match = accounts.first(where: {
                  $0.profile.loginUsername.lowercased() == cleanUsername && $0.profile.password == cleanPassword
              }) else { return false }
        activate(match)
        selectedRole = .pr
        save()
        return true
    }

    func usernameIsAvailable(_ username: String) -> Bool {
        let clean = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return isValidUsername(clean) && !accounts.contains(where: { $0.profile.loginUsername.lowercased() == clean })
    }

    private func isValidUsername(_ username: String) -> Bool {
        guard username.count >= 4 && username.count <= 24 else { return false }
        return username.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }
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

    func updateEvent(_ event: PREvent) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[index] = event
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

    func checkInFromQRCodeGlobally(_ encoded: String) -> QRCheckInResult {
        let prefix = "LISTUPPR|2|"
        guard encoded.hasPrefix(prefix),
              let data = Data(base64Encoded: String(encoded.dropFirst(prefix.count))),
              let payload = try? decoder.decode(GuestQRPayload.self, from: data),
              payload.version == 2 else {
            return QRCheckInResult(isValid: false, title: "CODICE QR INESISTENTE O NON VALIDO", guestName: "", eventName: "", venueName: "", eventDate: "", packageName: "", prName: "", prCode: "", paymentTitle: "", paymentDetail: "", amountDue: 0, detail: "Il codice scansionato non esiste oppure non è stato generato da ListUp PR.")
        }

        guard let accountIndex = accounts.firstIndex(where: { $0.profile.code == payload.prCode }) else {
            return QRCheckInResult(isValid: false, title: "CODICE QR INESISTENTE O NON VALIDO", guestName: "", eventName: "", venueName: "", eventDate: "", packageName: "", prName: "", prCode: payload.prCode, paymentTitle: "", paymentDetail: "", amountDue: 0, detail: "Il codice scansionato non è associato a nessun profilo PR disponibile.")
        }
        var account = accounts[accountIndex]
        guard let event = account.events.first(where: { $0.id == payload.eventID }) else {
            return QRCheckInResult(isValid: false, title: "CODICE QR INESISTENTE O NON VALIDO", guestName: "", eventName: "", venueName: "", eventDate: "", packageName: "", prName: account.profile.name, prCode: account.profile.code, paymentTitle: "", paymentDetail: "", amountDue: 0, detail: "Il codice scansionato non è associato a un evento disponibile.")
        }
        let key = payload.eventID.uuidString
        guard var guests = account.guestsByEvent[key],
              let index = guests.firstIndex(where: { $0.id == payload.guestID }) else {
            return QRCheckInResult(isValid: false, title: "CODICE QR INESISTENTE O NON VALIDO", guestName: "", eventName: event.name, venueName: event.venue, eventDate: italianEventDateTime(event.date), packageName: "", prName: account.profile.name, prCode: account.profile.code, paymentTitle: "", paymentDetail: "", amountDue: 0, detail: "Il codice scansionato non corrisponde a nessun cliente presente nella lista.")
        }
        guard payload.token == guests[index].effectiveQRToken else {
            return QRCheckInResult(isValid: false, title: "CODICE QR INESISTENTE O NON VALIDO", guestName: guests[index].fullName, eventName: event.name, venueName: event.venue, eventDate: italianEventDateTime(event.date), packageName: guests[index].packageName, prName: account.profile.name, prCode: account.profile.code, paymentTitle: "", paymentDetail: "", amountDue: 0, detail: "Il codice scansionato non è valido per questo cliente.")
        }
        if guests[index].entered {
            return QRCheckInResult(isValid: false, title: "QR GIÀ UTILIZZATO", guestName: guests[index].fullName, eventName: event.name, venueName: event.venue, eventDate: italianEventDateTime(event.date), packageName: guests[index].packageName, prName: account.profile.name, prCode: account.profile.code, paymentTitle: "", paymentDetail: "", amountDue: 0, detail: "Questo biglietto è già stato utilizzato e non può essere riutilizzato.")
        }

        guests[index].entered = true
        guests[index].entryTime = .now
        account.guestsByEvent[key] = guests
        accounts[accountIndex] = account
        if activeAccountID == account.id {
            guestsByEvent[payload.eventID] = guests
            lastEntry = (payload.eventID, payload.guestID)
        }
        persistAccounts()
        let amountDue = guests[index].remaining
        let paymentTitle: String
        let paymentDetail: String
        if guests[index].price <= 0 {
            paymentTitle = "NESSUN PAGAMENTO"
            paymentDetail = "Ingresso omaggio: il cliente può accedere direttamente."
        } else if amountDue <= 0 {
            paymentTitle = "PAGAMENTO COMPLETO"
            paymentDetail = "Il pacchetto risulta già saldato."
        } else if guests[index].deposit <= 0 {
            paymentTitle = "DA PAGARE IN CASSA"
            paymentDetail = "Il cliente deve pagare l’intero importo alla cassa."
        } else {
            paymentTitle = "SALDO IN CASSA"
            paymentDetail = "Il cliente deve completare il pagamento alla cassa."
        }
        return QRCheckInResult(isValid: true, title: "ACCESSO VALIDO", guestName: guests[index].fullName, eventName: event.name, venueName: event.venue, eventDate: italianEventDateTime(event.date), packageName: guests[index].packageName, prName: account.profile.name, prCode: account.profile.code, paymentTitle: paymentTitle, paymentDetail: paymentDetail, amountDue: amountDue, detail: "QR riconosciuto e ingresso registrato correttamente")
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
        if let activeAccountID { accounts.removeAll { $0.id == activeAccountID } }
        profile = nil; selectedRole = nil; events = []; guestsByEvent = [:]; entranceCode = ""; activeAccountID = nil
        persistAccounts()
        savePreferences()
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
        commitActiveAccount()
        persistAccounts()
        savePreferences()
    }

    private func activate(_ account: PRAccount) {
        activeAccountID = account.id
        profile = account.profile
        events = account.events
        guestsByEvent = Dictionary(uniqueKeysWithValues: account.guestsByEvent.compactMap { key, value in
            UUID(uuidString: key).map { ($0, value) }
        })
    }

    private func commitActiveAccount() {
        guard let activeAccountID, let profile,
              let index = accounts.firstIndex(where: { $0.id == activeAccountID }) else { return }
        let map = guestsByEvent.reduce(into: [String: [Guest]]()) { $0[$1.key.uuidString] = $1.value }
        accounts[index].profile = profile
        accounts[index].events = events
        accounts[index].guestsByEvent = map
    }

    private func persistAccounts() {
        if let data = try? encoder.encode(accounts) { defaults.set(data, forKey: "accounts.v3") }
        defaults.set(activeAccountID?.uuidString, forKey: "activeAccount.v3")
    }

    private func savePreferences() {
        defaults.set(selectedRole?.rawValue, forKey: "role.v2")
        defaults.set(entranceCode, forKey: "entranceCode.v2")
        defaults.set(theme.rawValue, forKey: "theme.v2")
        defaults.set(syncEnabled, forKey: "sync.v2")
    }

    private func load() {
        if let data = defaults.data(forKey: "accounts.v3"), let stored = try? decoder.decode([PRAccount].self, from: data) {
            accounts = stored
        } else if let data = defaults.data(forKey: "profile.v2"), let oldProfile = try? decoder.decode(PRProfile.self, from: data) {
            let oldEvents = defaults.data(forKey: "events.v2").flatMap { try? decoder.decode([PREvent].self, from: $0) } ?? []
            let oldMap = defaults.data(forKey: "guests.v2").flatMap { try? decoder.decode([String: [Guest]].self, from: $0) } ?? [:]
            accounts = [PRAccount(id: UUID(), profile: oldProfile, events: oldEvents, guestsByEvent: oldMap, createdAt: .now)]
        }
        if let rawID = defaults.string(forKey: "activeAccount.v3"), let id = UUID(uuidString: rawID), let account = accounts.first(where: { $0.id == id }) {
            activate(account)
        } else if let account = accounts.first {
            activate(account)
        }
        if let raw = defaults.string(forKey: "role.v2") { selectedRole = AppRole(rawValue: raw) }
        entranceCode = defaults.string(forKey: "entranceCode.v2") ?? ""
        theme = AppTheme(rawValue: defaults.string(forKey: "theme.v2") ?? "") ?? .dark
        syncEnabled = defaults.object(forKey: "sync.v2") as? Bool ?? true
    }

}