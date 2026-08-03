import SwiftUI

struct EventDetailView: View {
    @EnvironmentObject var model: AppModel
    let event: PREvent
    let entranceMode: Bool
    @State private var search = ""
    @State private var showAdd = false

    var filtered: [Guest] {
        let list = model.guestsByEvent[event.id] ?? []
        guard !search.isEmpty else { return list }
        return list.filter { $0.fullName.localizedCaseInsensitiveContains(search) || $0.packageName.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            Section {
                HStack { Label("\(filtered.filter(\.entered).count) entrati", systemImage: "checkmark.circle.fill"); Spacer(); Label("\(filtered.count) nominativi", systemImage: "person.2.fill") }.font(.subheadline)
            }
            Section("Lista clienti") {
                ForEach(filtered) { guest in
                    Button { model.toggleEntry(guestID: guest.id, eventID: event.id) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: guest.entered ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(guest.entered ? .green : .secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(guest.fullName).font(.headline).strikethrough(guest.entered)
                                Text("\(guest.peopleCount) persone • \(guest.packageName)").font(.caption).foregroundStyle(.secondary)
                                if guest.remaining > 0 { Text("Da pagare: €\(guest.remaining, specifier: "%.2f")").font(.caption2).foregroundStyle(.orange) }
                            }
                            Spacer()
                        }
                    }.buttonStyle(.plain)
                }
                .onDelete { model.deleteGuest(at: $0, eventID: event.id) }
            }
        }
        .navigationTitle(event.name)
        .searchable(text: $search, prompt: "Cerca cliente o pacchetto")
        .toolbar { if !entranceMode { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "person.badge.plus") } } } }
        .sheet(isPresented: $showAdd) { AddGuestView(eventID: event.id) }
    }
}

struct AddGuestView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    let eventID: UUID
    @State private var first = ""; @State private var last = ""; @State private var count = 1
    @State private var list = "Lista PR"; @State private var package = "Ingresso + drink"
    @State private var price = 0.0; @State private var deposit = 0.0; @State private var notes = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Cliente") { TextField("Nome", text: $first); TextField("Cognome", text: $last); Stepper("Persone: \(count)", value: $count, in: 1...20) }
                Section("Prenotazione") { TextField("Nome lista", text: $list); TextField("Pacchetto", text: $package); TextField("Prezzo totale", value: $price, format: .number).keyboardType(.decimalPad); TextField("Acconto", value: $deposit, format: .number).keyboardType(.decimalPad); TextField("Note", text: $notes, axis: .vertical) }
                Button("Aggiungi alla lista") { model.addGuest(Guest(firstName: first, lastName: last, peopleCount: count, listName: list, packageName: package, price: price, deposit: deposit, notes: notes), to: eventID); dismiss() }.disabled(first.isEmpty)
            }.navigationTitle("Nuovo cliente").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}
