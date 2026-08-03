import SwiftUI

enum GuestFilter: String, CaseIterable, Identifiable {
    case all = "Tutti"
    case waiting = "Da entrare"
    case entered = "Entrati"
    var id: String { rawValue }
}

struct EventDetailView: View {
    @EnvironmentObject var model: AppModel
    let event: PREvent
    let entranceMode: Bool
    @State private var search = ""
    @State private var showAdd = false
    @State private var showQuickAdd = false
    @State private var filter: GuestFilter = .all

    var guests: [Guest] { model.guestsByEvent[event.id] ?? [] }
    var filtered: [Guest] {
        guests
            .filter { guest in
                switch filter {
                case .all: true
                case .waiting: !guest.entered
                case .entered: guest.entered
                }
            }
            .filter {
                search.isEmpty ||
                $0.fullName.localizedCaseInsensitiveContains(search) ||
                $0.packageName.localizedCaseInsensitiveContains(search) ||
                $0.listName.localizedCaseInsensitiveContains(search)
            }
            .sorted {
                if $0.entered != $1.entered { return !$0.entered }
                return $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
            }
    }

    private var shareText: String {
        let rows = guests.sorted { $0.fullName < $1.fullName }.map { guest in
            "\(guest.entered ? "✅" : "⬜️") \(guest.fullName) — \(guest.packageName)"
        }
        return ([event.name, "\(event.venue) — \(event.date.formatted(date: .abbreviated, time: .shortened))", ""] + rows).joined(separator: "\n")
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    SummaryPill(value: "\(guests.count)", label: "In lista", icon: "person.3.fill")
                    SummaryPill(value: "\(guests.filter(\.entered).count)", label: "Entrati", icon: "checkmark.circle.fill")
                    SummaryPill(value: "\(guests.filter { !$0.entered }.count)", label: "Da entrare", icon: "clock.fill")
                }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }

            Section {
                Picker("Filtro", selection: $filter) {
                    ForEach(GuestFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            if let last = model.lastEntry, last.eventID == event.id,
               let guest = guests.first(where: { $0.id == last.guestID }) {
                Section {
                    Button {
                        model.undoLastEntry()
                    } label: {
                        Label("Annulla ultimo ingresso: \(guest.fullName)", systemImage: "arrow.uturn.backward.circle.fill")
                    }
                    .foregroundStyle(.orange)
                }
            }

            Section("Lista clienti") {
                ForEach(filtered) { guest in
                    GuestRow(guest: guest, entranceMode: entranceMode) {
                        model.toggleEntry(guestID: guest.id, eventID: event.id)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button { model.toggleEntry(guestID: guest.id, eventID: event.id) } label: {
                            Label(guest.entered ? "Annulla" : "Entrato", systemImage: guest.entered ? "arrow.uturn.backward" : "checkmark")
                        }.tint(guest.entered ? .orange : .green)
                        if guest.remaining > 0 {
                            Button { model.markBalancePaid(guestID: guest.id, eventID: event.id) } label: {
                                Label("Saldo pagato", systemImage: "eurosign.circle.fill")
                            }.tint(.blue)
                        }
                        if !entranceMode {
                            Button(role: .destructive) { model.deleteGuest(guest, eventID: event.id) } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Cerca nome, lista o pacchetto")
        .overlay {
            if guests.isEmpty {
                ContentUnavailableView("Lista vuota", systemImage: "person.badge.plus", description: Text(entranceMode ? "Il PR non ha ancora inserito clienti." : "Aggiungi il primo cliente all’evento."))
            } else if filtered.isEmpty {
                ContentUnavailableView("Nessun risultato", systemImage: "magnifyingglass")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if !entranceMode {
                        Button { showAdd = true } label: { Label("Aggiungi cliente", systemImage: "person.badge.plus") }
                        Button { showQuickAdd = true } label: { Label("Inserimento rapido", systemImage: "text.badge.plus") }
                    }
                    ShareLink(item: shareText) { Label("Condividi lista", systemImage: "square.and.arrow.up") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showAdd) { AddGuestView(eventID: event.id) }
        .sheet(isPresented: $showQuickAdd) { QuickAddGuestsView(eventID: event.id) }
    }
}

struct SummaryPill: View {
    let value: String, label: String, icon: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Color.appPurple)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.title3.bold())
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: .infinity)
    }
}

struct GuestRow: View {
    let guest: Guest
    let entranceMode: Bool
    let toggle: () -> Void
    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 14) {
                Image(systemName: guest.entered ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(guest.entered ? .green : .secondary)
                VStack(alignment: .leading, spacing: 5) {
                    Text(guest.fullName).font(.headline).foregroundStyle(.primary)
                    Text(guest.packageName).font(.subheadline).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        if !guest.listName.isEmpty { Label(guest.listName, systemImage: "list.bullet") }
                        if guest.remaining > 0 {
                            Label("€\(guest.remaining, specifier: "%.0f") da pagare", systemImage: "eurosign.circle")
                                .foregroundStyle(.orange)
                        }
                    }.font(.caption)
                    if !guest.notes.isEmpty {
                        Text(guest.notes).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    if guest.entered, let entryTime = guest.entryTime {
                        Text("Entrato alle \(entryTime.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2).foregroundStyle(.green)
                    }
                }
                Spacer()
            }.padding(.vertical, 5)
        }.buttonStyle(.plain)
    }
}

struct AddGuestView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    let eventID: UUID
    @State private var first = ""
    @State private var last = ""
    @State private var listName = ""
    @State private var packageName = "Ingresso"
    @State private var price = 0.0
    @State private var deposit = 0.0
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Cliente") {
                    TextField("Nome", text: $first)
                    TextField("Cognome", text: $last)
                }
                Section("Prenotazione") {
                    TextField("Nome lista", text: $listName)
                    TextField("Pacchetto scelto", text: $packageName)
                    TextField("Prezzo totale", value: $price, format: .number).keyboardType(.decimalPad)
                    TextField("Acconto versato", value: $deposit, format: .number).keyboardType(.decimalPad)
                    TextField("Note", text: $notes, axis: .vertical).lineLimit(2...5)
                }
                Button("Aggiungi cliente") {
                    let guest = Guest(firstName: first, lastName: last, listName: listName, packageName: packageName, price: price, deposit: min(deposit, price), notes: notes)
                    model.addGuest(guest, to: eventID)
                    dismiss()
                }.disabled(first.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .navigationTitle("Nuovo cliente")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}

struct QuickAddGuestsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    let eventID: UUID
    @State private var names = ""
    @State private var listName = ""
    @State private var packageName = "Ingresso"
    @State private var price = 0.0
    @State private var deposit = 0.0

    private var parsedNames: [(String, String)] {
        names.split(whereSeparator: \.isNewline).compactMap { line in
            let clean = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return nil }
            let parts = clean.split(separator: " ", maxSplits: 1).map(String.init)
            return (parts[0], parts.count > 1 ? parts[1] : "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nominativi") {
                    TextEditor(text: $names).frame(minHeight: 150)
                    Text("Scrivi una persona per riga, ad esempio:\nMario Rossi\nLuca Bianchi")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Dati comuni") {
                    TextField("Nome lista", text: $listName)
                    TextField("Pacchetto scelto", text: $packageName)
                    TextField("Prezzo per persona", value: $price, format: .number).keyboardType(.decimalPad)
                    TextField("Acconto per persona", value: $deposit, format: .number).keyboardType(.decimalPad)
                }
                Section {
                    Button("Aggiungi \(parsedNames.count) clienti") {
                        for (first, last) in parsedNames {
                            model.addGuest(Guest(firstName: first, lastName: last, listName: listName, packageName: packageName, price: price, deposit: min(deposit, price), notes: ""), to: eventID)
                        }
                        dismiss()
                    }.disabled(parsedNames.isEmpty)
                }
            }
            .navigationTitle("Inserimento rapido")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}
