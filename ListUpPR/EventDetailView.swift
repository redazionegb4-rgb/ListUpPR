import SwiftUI
import UIKit


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
    @State private var showCopy = false
    @State private var editingGuest: Guest?
    @State private var qrGuest: Guest?
    @State private var showScanner = false
    @State private var scanMessage = ""
    @State private var showScanResult = false
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
                $0.listName.localizedCaseInsensitiveContains(search) ||
                $0.phone?.localizedCaseInsensitiveContains(search) == true
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

    private var progress: Double { guests.isEmpty ? 0 : Double(guests.filter(\.entered).count) / Double(guests.count) }

    private var emptyTitle: String {
        if !search.isEmpty { return "Nessun cliente trovato" }
        switch filter {
        case .all: return "Lista ancora vuota"
        case .waiting: return "Nessun cliente in attesa"
        case .entered: return "Nessun ingresso registrato"
        }
    }

    private var emptyMessage: String {
        if !search.isEmpty { return "Prova a modificare la ricerca o il filtro selezionato." }
        switch filter {
        case .all: return entranceMode ? "Il PR non ha ancora inserito clienti per questo evento." : "Aggiungi il primo cliente dal menu in alto."
        case .waiting: return "Tutti i clienti presenti in lista risultano già entrati."
        case .entered: return "Gli ingressi confermati appariranno qui."
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.venue).font(.headline)
                            Text(event.date.formatted(date: .long, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(progress * 100))%").font(.title2.bold().monospacedDigit()).foregroundStyle(Color.appPurple)
                    }
                    ProgressView(value: progress).tint(.appPurple)
                    HStack(spacing: 10) {
                        SummaryPill(value: "\(guests.count)", label: "In lista", icon: "person.3.fill")
                        SummaryPill(value: "\(guests.filter(\.entered).count)", label: "Entrati", icon: "checkmark.circle.fill")
                        SummaryPill(value: "\(guests.filter { !$0.entered }.count)", label: "Attesi", icon: "clock.fill")
                    }
                }.listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            }

            Section {
                Picker("Filtro", selection: $filter) {
                    ForEach(GuestFilter.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
            }

            if let last = model.lastEntry, last.eventID == event.id,
               let guest = guests.first(where: { $0.id == last.guestID }) {
                Section {
                    Button { model.undoLastEntry() } label: {
                        Label("Annulla ultimo ingresso: \(guest.fullName)", systemImage: "arrow.uturn.backward.circle.fill")
                    }.foregroundStyle(.orange)
                }
            }

            Section("Lista clienti") {
                if filtered.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: filter == .entered ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.questionmark")
                            .font(.system(size: 30))
                            .foregroundStyle(.secondary)
                        Text(emptyTitle)
                            .font(.headline)
                        Text(emptyMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .listRowBackground(Color.clear)
                }
                ForEach(filtered) { guest in
                    GuestRow(
                        guest: guest,
                        entranceMode: entranceMode,
                        toggle: { model.toggleEntry(guestID: guest.id, eventID: event.id) },
                        edit: { editingGuest = guest },
                        delete: { model.deleteGuest(guest, eventID: event.id) },
                        showQR: { qrGuest = guest }
                    )
                    .contextMenu {
                        if !entranceMode {
                            Button { editingGuest = guest } label: { Label("Modifica cliente", systemImage: "pencil") }
                            Button { qrGuest = guest } label: { Label("Mostra QR ingresso", systemImage: "qrcode") }
                        }
                        if let phone = guest.phone, !phone.isEmpty {
                            Button { openPhone(phone) } label: { Label("Chiama", systemImage: "phone.fill") }
                            Button { openMessage(phone) } label: { Label("Messaggio", systemImage: "message.fill") }
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button { model.toggleEntry(guestID: guest.id, eventID: event.id) } label: {
                            Label(guest.entered ? "Annulla" : "Entrato", systemImage: guest.entered ? "arrow.uturn.backward" : "checkmark")
                        }.tint(guest.entered ? .orange : .green)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !entranceMode { Button { editingGuest = guest } label: { Label("Modifica", systemImage: "pencil") }.tint(.appPurple) }
                        if guest.remaining > 0 {
                            Button { model.markBalancePaid(guestID: guest.id, eventID: event.id) } label: { Label("Saldo", systemImage: "eurosign.circle.fill") }.tint(.blue)
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
        .searchable(text: $search, prompt: "Cerca nome, telefono, lista o pacchetto")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if entranceMode {
                    Button { showScanner = true } label: { Image(systemName: "qrcode.viewfinder") }
                        .accessibilityLabel("Scansiona QR")
                }
                Button {
                    model.refreshFromStorage()
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                }
                .accessibilityLabel("Aggiorna lista")

                Menu {
                    if !entranceMode {
                        Button { showAdd = true } label: { Label("Aggiungi cliente", systemImage: "person.badge.plus") }
                        Button { showQuickAdd = true } label: { Label("Inserimento rapido", systemImage: "text.badge.plus") }
                        Button { showCopy = true } label: { Label("Copia clienti da evento", systemImage: "person.2.badge.plus") }
                    }
                    ShareLink(item: shareText) { Label("Condividi lista", systemImage: "square.and.arrow.up") }
                } label: { Image(systemName: "ellipsis.circle.fill") }
            }
        }
        .sheet(isPresented: $showAdd) { AddGuestView(eventID: event.id) }
        .sheet(isPresented: $showQuickAdd) { QuickAddGuestsView(eventID: event.id) }
        .sheet(isPresented: $showCopy) { CopyGuestsView(destinationEventID: event.id) }
        .sheet(item: $editingGuest) { guest in EditGuestView(eventID: event.id, guest: guest) }
        .sheet(item: $qrGuest) { guest in GuestQRCodeView(guest: guest, event: event, prCode: model.profile?.code ?? "") }
        .sheet(isPresented: $showScanner) {
            QRScannerSheet { code in
                scanMessage = model.checkInFromQRCode(code, expectedEventID: event.id)
                showScanResult = true
            }
        }
        .alert("Scanner ingresso", isPresented: $showScanResult) { Button("OK", role: .cancel) {} } message: { Text(scanMessage) }
    }

    private func openPhone(_ phone: String) {
        let clean = phone.filter { $0.isNumber || $0 == "+" }
        if let url = URL(string: "tel:\(clean)") { UIApplication.shared.open(url) }
    }
    private func openMessage(_ phone: String) {
        let clean = phone.filter { $0.isNumber || $0 == "+" }
        if let url = URL(string: "sms:\(clean)") { UIApplication.shared.open(url) }
    }
}

struct SummaryPill: View {
    let value: String, label: String, icon: String
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(Color.appPurple)
            Text(value).font(.title3.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 10).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct GuestRow: View {
    let guest: Guest
    let entranceMode: Bool
    let toggle: () -> Void
    let edit: () -> Void
    let delete: () -> Void
    let showQR: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: toggle) {
                Image(systemName: guest.entered ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundStyle(guest.entered ? .green : .secondary)
            }.buttonStyle(.plain)

            Button(action: toggle) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(guest.fullName).font(.headline).foregroundStyle(.primary)
                    HStack(spacing: 7) {
                        Text(guest.packageName).font(.subheadline).foregroundStyle(.secondary)
                        if guest.remaining == 0 && guest.price > 0 { Text("PAGATO").font(.caption2.bold()).foregroundStyle(.green) }
                    }
                    HStack(spacing: 10) {
                        if !guest.listName.isEmpty { Label(guest.listName, systemImage: "list.bullet") }
                        if guest.remaining > 0 { Label("€\(guest.remaining, specifier: "%.0f")", systemImage: "eurosign.circle").foregroundStyle(.orange) }
                        if let phone = guest.phone, !phone.isEmpty { Label(phone, systemImage: "phone") }
                    }.font(.caption)
                    if !guest.notes.isEmpty { Text(guest.notes).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                    if guest.entered, let entryTime = guest.entryTime {
                        Text("Entrato alle \(entryTime.formatted(date: .omitted, time: .shortened))").font(.caption2).foregroundStyle(.green)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)

            if !entranceMode {
                Menu {
                    Button(action: edit) { Label("Modifica cliente", systemImage: "pencil") }
                    Button(action: showQR) { Label("Mostra QR ingresso", systemImage: "qrcode") }
                    Button(role: .destructive, action: delete) { Label("Elimina cliente", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.appPurple)
                        .padding(5)
                }
            }
        }.padding(.vertical, 6)
    }
}

struct AddGuestView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    let eventID: UUID
    @State private var first = ""
    @State private var last = ""
    @State private var phone = ""
    @State private var listName = ""
    @State private var packageName = "Ingresso standard"
    @State private var priceText = ""
    @State private var depositText = ""
    @State private var notes = ""
    @State private var duplicateWarning = false

    private var price: Double { Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var deposit: Double { Double(depositText.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome", text: $first)
                    TextField("Cognome", text: $last)
                    TextField("Numero di telefono (facoltativo)", text: $phone).keyboardType(.phonePad)
                } header: {
                    Text("Cliente")
                } footer: {
                    Text("Ogni nominativo corrisponde a una sola persona.")
                }

                Section {
                    TextField("Esempio: Lista Marco", text: $listName)
                    TextField("Esempio: Ingresso + drink", text: $packageName)
                    BookingAmountField(
                        title: "Prezzo totale",
                        explanation: "Costo completo dell’ingresso o del pacchetto",
                        placeholder: "Es. 20,00",
                        text: $priceText
                    )
                    BookingAmountField(
                        title: "Acconto già versato",
                        explanation: "Lascia vuoto se il cliente non ha pagato nulla",
                        placeholder: "Es. 10,00",
                        text: $depositText
                    )
                    TextField("Note: tavolo, accompagnatore, richieste…", text: $notes, axis: .vertical).lineLimit(2...5)
                } header: {
                    Text("Prenotazione")
                } footer: {
                    Text("Il saldo rimanente viene calcolato automaticamente: prezzo totale meno acconto.")
                }

                if duplicateWarning {
                    Label("Esiste già un cliente con questo nome nell’evento.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }

                Button("Aggiungi cliente") {
                    if model.hasDuplicateGuest(firstName: first, lastName: last, eventID: eventID) {
                        duplicateWarning = true
                        return
                    }
                    let guest = Guest(
                        firstName: first,
                        lastName: last,
                        listName: listName,
                        packageName: packageName,
                        price: max(0, price),
                        deposit: min(max(0, deposit), max(0, price)),
                        notes: notes,
                        phone: phone
                    )
                    model.addGuest(guest, to: eventID)
                    dismiss()
                }
                .disabled(first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationTitle("Nuovo cliente")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}

struct BookingAmountField: View {
    let title: String
    let explanation: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(explanation).font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("€").foregroundStyle(Color.appPurple).font(.headline)
                TextField(placeholder, text: $text).keyboardType(.decimalPad)
            }
        }.padding(.vertical, 4)
    }
}

struct EditGuestView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    let eventID: UUID
    @State var guest: Guest

    var body: some View {
        NavigationStack {
            Form {
                Section("Cliente") {
                    TextField("Nome", text: $guest.firstName)
                    TextField("Cognome", text: $guest.lastName)
                    TextField("Telefono", text: Binding(get: { guest.phone ?? "" }, set: { guest.phone = $0 })).keyboardType(.phonePad)
                }
                Section("Prenotazione") {
                    TextField("Nome lista", text: $guest.listName)
                    TextField("Pacchetto", text: $guest.packageName)
                    TextField("Prezzo", value: $guest.price, format: .number).keyboardType(.decimalPad)
                    TextField("Acconto", value: $guest.deposit, format: .number).keyboardType(.decimalPad)
                    TextField("Note", text: $guest.notes, axis: .vertical)
                }
                Button("Salva modifiche") { guest.deposit = min(guest.deposit, guest.price); model.updateGuest(guest, eventID: eventID); dismiss() }
            }.navigationTitle("Modifica cliente")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}

struct QuickAddGuestsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    let eventID: UUID
    @State private var names = ""; @State private var listName = ""; @State private var packageName = "Ingresso"
    @State private var price = 0.0; @State private var deposit = 0.0

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
                    Text("Scrivi una persona per riga.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Dati comuni") {
                    TextField("Nome lista", text: $listName)
                    TextField("Pacchetto scelto", text: $packageName)
                    TextField("Prezzo per persona", value: $price, format: .number).keyboardType(.decimalPad)
                    TextField("Acconto per persona", value: $deposit, format: .number).keyboardType(.decimalPad)
                }
                Button("Aggiungi \(parsedNames.count) clienti") {
                    for (first, last) in parsedNames where !model.hasDuplicateGuest(firstName: first, lastName: last, eventID: eventID) {
                        model.addGuest(Guest(firstName: first, lastName: last, listName: listName, packageName: packageName, price: price, deposit: min(deposit, price), notes: ""), to: eventID)
                    }
                    dismiss()
                }.disabled(parsedNames.isEmpty)
            }.navigationTitle("Inserimento rapido")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}

struct CopyGuestsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    let destinationEventID: UUID

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.events.filter { $0.id != destinationEventID }) { source in
                    Button {
                        model.copyGuests(from: source.id, to: destinationEventID); dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(source.name).font(.headline).foregroundStyle(.primary)
                                Text("\(model.guestsByEvent[source.id]?.count ?? 0) clienti").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(); Image(systemName: "plus.circle.fill").foregroundStyle(Color.appPurple)
                        }
                    }
                }
            }.navigationTitle("Copia clienti")
            .overlay { if model.events.filter({ $0.id != destinationEventID }).isEmpty { ContentUnavailableView("Nessun altro evento", systemImage: "calendar") } }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}
