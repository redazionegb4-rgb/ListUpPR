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
        return ([event.name, "\(event.venue) — \(italianEventDateTime(event.date))", ""] + rows).joined(separator: "\n")
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
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PremiumCard {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .top, spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(LinearGradient(colors: [Color.appCyan, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 66, height: 66)

                                VStack(alignment: .leading, spacing: 7) {
                                    Text(event.name)
                                        .font(.system(size: 27, weight: .black, design: .rounded))
                                    Label(event.venue, systemImage: "mappin.and.ellipse")
                                    Label(italianEventDateTime(event.date), systemImage: "clock.fill")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                                Spacer()
                                Text("\(Int(progress * 100))%")
                                    .font(.title2.bold().monospacedDigit())
                                    .foregroundStyle(Color.appCyan)
                            }

                            ProgressView(value: progress)
                                .tint(.appCyan)
                                .scaleEffect(x: 1, y: 1.35)

                            HStack(spacing: 10) {
                                SummaryPill(value: "\(guests.count)", label: "In lista", icon: "person.3.fill")
                                SummaryPill(value: "\(guests.filter(\.entered).count)", label: "Entrati", icon: "checkmark.circle.fill")
                                SummaryPill(value: "\(guests.filter { !$0.entered }.count)", label: "Attesi", icon: "clock.fill")
                            }
                        }
                    }

                    Picker("Filtro", selection: $filter) {
                        ForEach(GuestFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(6)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    if let last = model.lastEntry, last.eventID == event.id,
                       let guest = guests.first(where: { $0.id == last.guestID }) {
                        Button { model.undoLastEntry() } label: {
                            Label("Annulla ultimo ingresso: \(guest.fullName)", systemImage: "arrow.uturn.backward.circle.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }

                    Text("Lista clienti")
                        .font(.title2.bold())
                        .padding(.top, 4)

                    if filtered.isEmpty {
                        PremiumCard {
                            VStack(spacing: 12) {
                                Image(systemName: filter == .entered ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.questionmark")
                                    .font(.system(size: 36))
                                    .foregroundStyle(Color.appCyan)
                                Text(emptyTitle).font(.headline)
                                Text(emptyMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                        }
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filtered) { guest in
                                PremiumCard {
                                    GuestRow(
                                        guest: guest,
                                        entranceMode: entranceMode,
                                        toggle: { model.toggleEntry(guestID: guest.id, eventID: event.id) },
                                        edit: { editingGuest = guest },
                                        delete: { model.deleteGuest(guest, eventID: event.id) },
                                        showQR: { qrGuest = guest }
                                    )
                                }
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
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 32)
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
        .sheet(item: $qrGuest) { guest in GuestQRCodeView(guest: guest, event: event, prCode: model.profile?.code ?? "", prName: model.profile?.name ?? "PR") }
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
                    .font(.title2).foregroundStyle(guest.entered ? Color.green : Color.secondary)
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
                        Text("Entrato alle \(italianTicketTime(entryTime))").font(.caption2).foregroundStyle(.green)
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
    @State private var notes = ""
    @State private var duplicateWarning = false

    private var price: Double { Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        FormHero(icon: "person.badge.plus", title: "Nuovo cliente", subtitle: "Inserisci una persona e collegala a questo evento")

                        ModernFormCard(title: "Dati cliente", icon: "person.text.rectangle") {
                            ModernTextField(title: "Nome", placeholder: "Es. Mario", text: $first, icon: "person")
                            ModernTextField(title: "Cognome", placeholder: "Es. Rossi", text: $last, icon: "person.fill")
                            ModernTextField(title: "Telefono", placeholder: "Facoltativo", text: $phone, icon: "phone", keyboard: .phonePad)
                        }

                        ModernFormCard(title: "Prenotazione", icon: "ticket") {
                            ModernTextField(title: "Nome lista", placeholder: "Es. Lista Demetrio", text: $listName, icon: "list.bullet")
                            ModernTextField(title: "Pacchetto", placeholder: "Es. Ingresso + drink", text: $packageName, icon: "ticket.fill")
                            ModernTextField(title: "Prezzo alla cassa", placeholder: "Es. 20,00", text: $priceText, icon: "eurosign.circle", keyboard: .decimalPad)
                            ModernTextField(title: "Note", placeholder: "Richieste o informazioni utili", text: $notes, icon: "note.text")
                        }

                        if duplicateWarning {
                            Label("Esiste già un cliente con questo nome nell’evento.", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                        }

                        Button {
                            if model.hasDuplicateGuest(firstName: first, lastName: last, eventID: eventID) {
                                duplicateWarning = true
                                return
                            }
                            model.addGuest(Guest(firstName: first, lastName: last, listName: listName, packageName: packageName, price: max(0, price), deposit: 0, notes: notes, phone: phone), to: eventID)
                            dismiss()
                        } label: {
                            Label("Aggiungi cliente", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(20)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                FixedModalHeader(title: "", onClose: { dismiss() })
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct FormHero: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(LinearGradient(colors: [Color.appCyan, Color.mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: icon).font(.system(size: 27, weight: .bold)).foregroundStyle(.white)
            }.frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 28, weight: .black, design: .rounded))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct ModernFormCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.icon = icon; self.content = content()
    }
    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(title, systemImage: icon).font(.headline)
                content
            }
        }
    }
}

struct ModernTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    var keyboard: UIKeyboardType = .default
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            HStack(spacing: 11) {
                Image(systemName: icon).foregroundStyle(Color.appCyan).frame(width: 22)
                TextField(placeholder, text: $text).keyboardType(keyboard)
            }
            .padding(14)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
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
    @State private var priceText: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        FormHero(icon: "person.crop.circle.badge.checkmark", title: "Modifica cliente", subtitle: "Aggiorna nominativo, pacchetto e informazioni")

                        ModernFormCard(title: "Dati cliente", icon: "person.text.rectangle") {
                            ModernTextField(title: "Nome", placeholder: "Nome", text: $guest.firstName, icon: "person")
                            ModernTextField(title: "Cognome", placeholder: "Cognome", text: $guest.lastName, icon: "person.fill")
                            ModernTextField(title: "Telefono", placeholder: "Facoltativo", text: Binding(get: { guest.phone ?? "" }, set: { guest.phone = $0 }), icon: "phone", keyboard: .phonePad)
                        }

                        ModernFormCard(title: "Prenotazione", icon: "ticket") {
                            ModernTextField(title: "Nome lista", placeholder: "Nome lista", text: $guest.listName, icon: "list.bullet")
                            ModernTextField(title: "Pacchetto", placeholder: "Pacchetto", text: $guest.packageName, icon: "ticket.fill")
                            ModernTextField(title: "Prezzo alla cassa", placeholder: "Es. 20,00", text: $priceText, icon: "eurosign.circle", keyboard: .decimalPad)
                            ModernTextField(title: "Note", placeholder: "Informazioni utili", text: $guest.notes, icon: "note.text")
                        }

                        Button {
                            guest.price = max(0, Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? guest.price)
                            model.updateGuest(guest, eventID: eventID)
                            dismiss()
                        } label: {
                            Label("Salva modifiche", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(20)
                }
            }
            .onAppear { priceText = String(format: "%.2f", guest.price).replacingOccurrences(of: ".", with: ",") }
            .safeAreaInset(edge: .top, spacing: 0) {
                FixedModalHeader(title: "", onClose: { dismiss() })
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct QuickAddGuestsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    let eventID: UUID
    @State private var names = ""
    @State private var listName = ""
    @State private var packageName = "Ingresso standard"
    @State private var priceText = ""

    private var price: Double { Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var parsedNames: [(String, String)] {
        names.split(whereSeparator: \.isNewline).compactMap { line in
            let clean = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return nil }
            let parts = clean.split(separator: " ", maxSplits: 1).map(String.init)
            return (parts[0], parts.count > 1 ? parts[1] : "")
        }
    }
    private var duplicateCount: Int {
        parsedNames.filter { model.hasDuplicateGuest(firstName: $0.0, lastName: $0.1, eventID: eventID) }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 8) {
                            GradientIcon(systemName: "person.3.sequence.fill")
                            Text("Inserimento rapido").font(.system(size: 30, weight: .black, design: .rounded))
                            Text("Aggiungi più clienti in una sola volta, uno per ogni riga.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }

                        PremiumCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Nominativi", systemImage: "list.bullet.rectangle.fill").font(.headline)
                                TextEditor(text: $names)
                                    .frame(minHeight: 190)
                                    .padding(10)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
                                Text("Esempio:\nMario Rossi\nLuca Bianchi\nSara Verdi")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }

                        PremiumCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("Dati comuni", systemImage: "slider.horizontal.3").font(.headline)
                                labeledField("Nome lista", placeholder: "Es. Lista Demetrio", text: $listName, icon: "text.badge.star")
                                labeledField("Pacchetto", placeholder: "Es. Ingresso gold", text: $packageName, icon: "ticket.fill")
                                labeledField("Prezzo a persona", placeholder: "Es. 20,00", text: $priceText, icon: "eurosign.circle.fill", keyboard: .decimalPad)
                            }
                        }

                        HStack(spacing: 10) {
                            metric("\(parsedNames.count)", "Rilevati", .appCyan)
                            metric("\(duplicateCount)", "Duplicati", .orange)
                            metric("\(max(0, parsedNames.count - duplicateCount))", "Da aggiungere", .green)
                        }

                        Button {
                            for (first, last) in parsedNames where !model.hasDuplicateGuest(firstName: first, lastName: last, eventID: eventID) {
                                model.addGuest(Guest(firstName: first, lastName: last, listName: listName, packageName: packageName, price: price, deposit: 0, notes: ""), to: eventID)
                            }
                            dismiss()
                        } label: {
                            Label("Aggiungi \(max(0, parsedNames.count - duplicateCount)) clienti", systemImage: "person.badge.plus")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(parsedNames.isEmpty || parsedNames.count == duplicateCount)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") } } }
        }
    }

    private func labeledField(_ title: String, placeholder: String, text: Binding<String>, icon: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            HStack {
                Image(systemName: icon).foregroundStyle(Color.appCyan).frame(width: 22)
                TextField(placeholder, text: text).keyboardType(keyboard)
            }.padding(13).background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 15))
        }
    }

    private func metric(_ value: String, _ title: String, _ color: Color) -> some View {
        VStack(spacing: 5) {
            Text(value).font(.title2.bold().monospacedDigit()).foregroundStyle(color)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 13).background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
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
            .navigationBarTitleDisplayMode(.inline)
            .overlay { if model.events.filter({ $0.id != destinationEventID }).isEmpty { ContentUnavailableView("Nessun altro evento", systemImage: "calendar") } }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") } } }
        }
    }
}
