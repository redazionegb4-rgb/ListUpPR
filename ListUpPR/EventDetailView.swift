import SwiftUI

struct EventDetailView: View {
    @EnvironmentObject var model: AppModel
    let event: PREvent
    let entranceMode: Bool
    @State private var search = ""
    @State private var showAdd = false

    var guests: [Guest] { model.guestsByEvent[event.id] ?? [] }
    var filtered: [Guest] {
        guard !search.isEmpty else { return guests }
        return guests.filter {
            $0.fullName.localizedCaseInsensitiveContains(search) ||
            $0.packageName.localizedCaseInsensitiveContains(search) ||
            $0.listName.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    SummaryPill(value: "\(guests.count)", label: "In lista", icon: "person.3.fill")
                    SummaryPill(value: "\(guests.filter(\.entered).count)", label: "Entrati", icon: "checkmark.circle.fill")
                }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
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
                            Button { model.markBalancePaid(guestID: guest.id, eventID: event.id) } label: { Label("Saldo pagato", systemImage: "eurosign.circle.fill") }.tint(.blue)
                        }
                        if !entranceMode {
                            Button(role: .destructive) { model.deleteGuest(guest, eventID: event.id) } label: { Label("Elimina", systemImage: "trash") }
                        }
                    }
                }
            }
        }
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Cerca nome, lista o pacchetto")
        .overlay { if guests.isEmpty { ContentUnavailableView("Lista vuota", systemImage: "person.badge.plus", description: Text(entranceMode ? "Il PR non ha ancora inserito clienti." : "Aggiungi il primo cliente all’evento.")) } }
        .toolbar {
            if !entranceMode {
                ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "person.badge.plus") } }
            }
        }
        .sheet(isPresented: $showAdd) { AddGuestView(eventID: event.id) }
    }
}

struct SummaryPill: View {
    let value: String, label: String, icon: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Color.appPurple)
            VStack(alignment: .leading, spacing: 1) { Text(value).font(.title3.bold()); Text(label).font(.caption).foregroundStyle(.secondary) }
            Spacer()
        }.padding(14).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18)).frame(maxWidth: .infinity)
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
                    .font(.title2).foregroundStyle(guest.entered ? .green : .secondary)
                VStack(alignment: .leading, spacing: 5) {
                    Text(guest.fullName).font(.headline).foregroundStyle(.primary)
                    Text(guest.packageName).font(.subheadline).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        if !guest.listName.isEmpty { Label(guest.listName, systemImage: "list.bullet") }
                        if guest.remaining > 0 { Label("€\(guest.remaining, specifier: "%.0f") da pagare", systemImage: "eurosign.circle") .foregroundStyle(.orange) }
                    }.font(.caption)
                    if guest.entered, let entryTime = guest.entryTime { Text("Entrato alle \(entryTime.formatted(date: .omitted, time: .shortened))").font(.caption2).foregroundStyle(.green) }
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
    @State private var first = ""; @State private var last = ""
    @State private var listName = ""; @State private var packageName = "Ingresso"
    @State private var price = 0.0; @State private var deposit = 0.0; @State private var notes = ""

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
                    let guest = Guest(firstName: first, lastName: last, listName: listName, packageName: packageName, price: price, deposit: deposit, notes: notes)
                    model.addGuest(guest, to: eventID); dismiss()
                }.disabled(first.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .navigationTitle("Nuovo cliente")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}
