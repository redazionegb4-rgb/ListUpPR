import Foundation
import SwiftUI

struct PRMainView: View {
    var body: some View {
        TabView {
            PRDashboardView().tabItem { Label("Home", systemImage: "house.fill") }
            EventsView().tabItem { Label("Eventi", systemImage: "calendar") }
            AllGuestsView().tabItem { Label("Clienti", systemImage: "person.3.fill") }
            SettingsView().tabItem { Label("Impostazioni", systemImage: "gearshape.fill") }
        }.tint(.appCyan)
    }
}

struct PRDashboardView: View {
    @EnvironmentObject var model: AppModel
    @State private var showNewEvent = false
    @State private var targetEvent: PREvent?

    private var waiting: Int { max(0, model.totalPeople - model.enteredPeople) }
    private var progress: Double { model.totalPeople == 0 ? 0 : Double(model.enteredPeople) / Double(model.totalPeople) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        hero
                        quickActions
                        if let event = model.activeEvent {
                            Text("Prossima serata").font(.title2.bold())
                            NavigationLink(value: event) {
                                LargeEventCard(event: event, guests: model.guestsByEvent[event.id] ?? [])
                            }.buttonStyle(.plain)
                        } else {
                            EmptyEventCard { showNewEvent = true }
                        }
                        recentGuests
                    }.padding(20)
                }
            }
            .navigationDestination(for: PREvent.self) { EventDetailView(event: $0, entranceMode: false) }
            .sheet(isPresented: $showNewEvent) { NewEventView() }
            .sheet(item: $targetEvent) { event in AddGuestView(eventID: event.id) }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { model.refreshFromStorage() } label: {
                        Image(systemName: "arrow.clockwise.circle.fill").font(.title3)
                    }.accessibilityLabel("Aggiorna dati")
                    Button { model.logout() } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right").font(.title3)
                    }.accessibilityLabel("Esci")
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bentornato").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Text(model.profile?.name ?? "PR").font(.system(size: 32, weight: .black, design: .rounded))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Panoramica eventi attivi").font(.headline)
                    Text("Gli eventi passati non rientrano nei conteggi").font(.caption).foregroundStyle(.white.opacity(0.78))
                }
                Spacer(); Image(systemName: "sparkles").font(.title2.bold())
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(model.enteredPeople)").font(.system(size: 44, weight: .black, design: .rounded))
                    Text("ingressi confermati").font(.subheadline)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(waiting)").font(.title2.bold())
                    Text("ancora da entrare").font(.caption)
                }
            }
            ProgressView(value: progress).tint(.white)
            HStack {
                Label("\(model.totalPeople) clienti", systemImage: "person.2.fill")
                Spacer(); Text("\(Int(progress * 100))% completato")
            }.font(.caption.bold())
        }
        .foregroundStyle(.white).padding(22)
        .background(LinearGradient(colors: [Color(red: 0.02, green: 0.35, blue: 0.65), .appCyan], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .appCyan.opacity(0.20), radius: 24, y: 12)
    }

    private var quickActions: some View {
        HStack(spacing: 18) {
            DashboardAction(icon: "calendar.badge.plus", title: "Nuovo evento") { showNewEvent = true }
            DashboardAction(icon: "person.badge.plus", title: "Aggiungi cliente") {
                if let event = model.activeEvent { targetEvent = event } else { showNewEvent = true }
            }
        }
    }

    private var recentGuests: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ultimi clienti inseriti").font(.title3.bold())
            PremiumCard {
                if model.allGuests.isEmpty {
                    Text("Nessun cliente negli eventi attivi.").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(model.allGuests.suffix(4).reversed())) { guest in
                            HStack(spacing: 12) {
                                Image(systemName: guest.entered ? "checkmark.circle.fill" : "person.crop.circle")
                                    .foregroundStyle(guest.entered ? .green : Color.appCyan).font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(guest.fullName).font(.headline)
                                    Text(guest.packageName).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }.padding(.vertical, 10)
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

struct DashboardAction: View {
    let icon: String, title: String, action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                GradientIcon(systemName: icon)
                Text(title).font(.caption.bold()).multilineTextAlignment(.center).foregroundStyle(.primary)
            }.frame(maxWidth: .infinity).padding(.vertical, 12)
        }.buttonStyle(.plain)
    }
}

struct LargeEventCard: View {
    let event: PREvent; let guests: [Guest]
    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.name).font(.title2.bold())
                        Text("Evento programmato").font(.caption.bold()).foregroundStyle(Color.appCyan)
                    }
                    Spacer(); Image(systemName: "chevron.right.circle.fill").font(.title2).foregroundStyle(Color.appCyan)
                }
                Label(event.venue, systemImage: "mappin.and.ellipse")
                Label(event.date.formatted(date: .long, time: .shortened), systemImage: "calendar.badge.clock")
                Divider()
                HStack {
                    Label("\(guests.count) in lista", systemImage: "person.2.fill")
                    Spacer(); Label("\(guests.filter(\.entered).count) entrati", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }.font(.subheadline)
            }
        }
    }
}

struct EmptyEventCard: View {
    let action: () -> Void
    var body: some View {
        PremiumCard {
            VStack(spacing: 12) {
                GradientIcon(systemName: "calendar.badge.plus")
                Text("Nessun evento attivo").font(.title3.bold())
                Text("Crea la prossima serata e inizia ad aggiungere clienti.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Crea evento", action: action).buttonStyle(.borderedProminent).tint(.appCyan)
            }.frame(maxWidth: .infinity)
        }
    }
}

struct EventsView: View {
    @EnvironmentObject var model: AppModel
    @State private var showNewEvent = false
    var body: some View {
        NavigationStack {
            List {
                if !model.upcomingEvents.isEmpty {
                    Section("Eventi attivi") { eventRows(model.upcomingEvents, past: false) }
                }
                if !model.pastEvents.isEmpty {
                    Section("Eventi passati") { eventRows(model.pastEvents, past: true) }
                }
            }
            .navigationTitle("Eventi")
            .overlay { if model.events.isEmpty { ContentUnavailableView("Nessun evento", systemImage: "calendar", description: Text("Crea il primo evento.")) } }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNewEvent = true } label: { Image(systemName: "plus.circle.fill") } } }
            .navigationDestination(for: PREvent.self) { EventDetailView(event: $0, entranceMode: false) }
            .sheet(isPresented: $showNewEvent) { NewEventView() }
        }
    }

    @ViewBuilder private func eventRows(_ events: [PREvent], past: Bool) -> some View {
        ForEach(events) { event in
            NavigationLink(value: event) {
                HStack(spacing: 13) {
                    GradientIcon(systemName: past ? "clock.arrow.circlepath" : "music.note.list")
                    VStack(alignment: .leading, spacing: 5) {
                        Text(event.name).font(.headline)
                        Text("\(event.venue) • \(event.date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                        let guests = model.guestsByEvent[event.id] ?? []
                        Text(past ? "Storico: \(guests.filter(\.entered).count) entrati su \(guests.count)" : "\(guests.filter(\.entered).count) entrati su \(guests.count)")
                            .font(.caption2.bold()).foregroundStyle(past ? .secondary : Color.appCyan)
                    }
                }.padding(.vertical, 5)
            }.swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) { model.deleteEvent(event) } label: { Label("Elimina", systemImage: "trash") }
                Button { _ = model.duplicateEvent(event) } label: { Label("Duplica", systemImage: "plus.square.on.square") }.tint(.appCyan)
            }
        }
    }
}

struct AllGuestsView: View {
    @EnvironmentObject var model: AppModel
    @State private var search = ""
    @State private var editingPair: GuestEventPair?
    @State private var deletingPair: GuestEventPair?
    @State private var qrPair: GuestEventPair?
    @State private var showPast = false

    private var sourceEvents: [PREvent] { showPast ? model.pastEvents : model.upcomingEvents }
    private var filtered: [GuestEventPair] {
        sourceEvents.flatMap { event in (model.guestsByEvent[event.id] ?? []).map { GuestEventPair(event: event, guest: $0) } }
            .filter { search.isEmpty || $0.guest.fullName.localizedCaseInsensitiveContains(search) || $0.guest.packageName.localizedCaseInsensitiveContains(search) || $0.guest.phone?.contains(search) == true }
            .sorted { $0.guest.fullName.localizedCaseInsensitiveCompare($1.guest.fullName) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVStack(spacing: 14) {
                        Picker("Archivio", selection: $showPast) {
                            Text("Eventi attivi").tag(false); Text("Eventi passati").tag(true)
                        }.pickerStyle(.segmented)

                        if filtered.isEmpty {
                            ContentUnavailableView(showPast ? "Nessun cliente nello storico" : "Nessun cliente", systemImage: "person.3", description: Text(search.isEmpty ? "I clienti appariranno qui." : "Prova una ricerca diversa."))
                                .padding(.top, 60)
                        } else {
                            ForEach(filtered) { pair in clientCard(pair) }
                        }
                    }.padding(20)
                }
            }
            .navigationTitle("Clienti")
            .searchable(text: $search, prompt: "Cerca nome, telefono o pacchetto")
            .sheet(item: $editingPair) { pair in EditGuestView(eventID: pair.event.id, guest: pair.guest) }
            .sheet(item: $qrPair) { pair in GuestQRCodeView(guest: pair.guest, event: pair.event, prCode: model.profile?.code ?? "", prName: model.profile?.name ?? "PR") }
            .alert("Eliminare il cliente?", isPresented: Binding(get: { deletingPair != nil }, set: { if !$0 { deletingPair = nil } })) {
                Button("Annulla", role: .cancel) { deletingPair = nil }
                Button("Elimina", role: .destructive) { if let pair = deletingPair { model.deleteGuest(pair.guest, eventID: pair.event.id) }; deletingPair = nil }
            } message: { Text(deletingPair.map { "\($0.guest.fullName) verrà eliminato dall’evento \($0.event.name)." } ?? "") }
        }
    }

    private func clientCard(_ pair: GuestEventPair) -> some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle().fill((pair.guest.entered ? Color.green : Color.appCyan).opacity(0.15)).frame(width: 48, height: 48)
                        Image(systemName: pair.guest.entered ? "checkmark.circle.fill" : "person.fill").foregroundStyle(pair.guest.entered ? .green : Color.appCyan)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pair.guest.fullName).font(.title3.bold())
                        Text("\(pair.event.name) • \(pair.guest.packageName)").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(pair.guest.entered ? "ENTRATO" : "DA ENTRARE").font(.caption2.bold()).padding(.horizontal, 9).padding(.vertical, 6)
                        .background((pair.guest.entered ? Color.green : Color.orange).opacity(0.14), in: Capsule())
                        .foregroundStyle(pair.guest.entered ? .green : .orange)
                }
                HStack {
                    Label(pair.guest.price <= 0 ? "Omaggio" : pair.guest.price.formatted(.currency(code: "EUR")), systemImage: "eurosign.circle")
                    Spacer()
                    if let phone = pair.guest.phone, !phone.isEmpty { Label(phone, systemImage: "phone.fill") }
                }.font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button { qrPair = pair } label: { Label("QR", systemImage: "qrcode") }.buttonStyle(.borderedProminent).tint(.appCyan)
                    Button { editingPair = pair } label: { Label("Modifica", systemImage: "pencil") }.buttonStyle(.bordered)
                    Button(role: .destructive) { deletingPair = pair } label: { Image(systemName: "trash") }.buttonStyle(.bordered)
                }
            }
        }
    }
}

struct GuestEventPair: Identifiable {
    let event: PREvent
    let guest: Guest
    var id: UUID { guest.id }
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var showReset = false
    @State private var showPassword = false
    @State private var showName = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        profileCard
                        appearanceCard
                        syncCard
                        statsCard
                        securityCard
                        accountCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPassword) { ChangePasswordView() }
            .sheet(isPresented: $showName) { ChangePRNameView() }
            .alert("Cancellare tutti i dati?", isPresented: $showReset) {
                Button("Annulla", role: .cancel) {}
                Button("Cancella", role: .destructive) { model.resetAllData() }
            } message: {
                Text("Verranno eliminati profilo, eventi e clienti salvati su questo dispositivo.")
            }
        }
    }

    private var profileCard: some View {
        PremiumCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [.appPurple, .appPink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text(String((model.profile?.name ?? "P").prefix(1)).uppercased()).font(.title.bold()).foregroundStyle(.white)
                }.frame(width: 62, height: 62)
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.profile?.name ?? "PR").font(.title3.bold())
                    Text("Profilo PR").font(.caption).foregroundStyle(.secondary)
                    Text("Codice: \(model.profile?.code ?? "---")").font(.subheadline.bold().monospacedDigit()).foregroundStyle(Color.appCyan)
                }
                Spacer()
                Menu {
                    Button { showName = true } label: { Label("Modifica nome", systemImage: "pencil") }
                } label: {
                    Image(systemName: "ellipsis.circle.fill").font(.title2).foregroundStyle(Color.appPurple)
                }
            }
        }
    }

    private var appearanceCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Aspetto", systemImage: "paintpalette.fill").font(.headline)
                Text("Scegli tema automatico, chiaro o scuro. Tutte le schermate si adattano completamente.").font(.caption).foregroundStyle(.secondary)
                Picker("Tema", selection: Binding(get: { model.theme }, set: model.updateTheme)) {
                    ForEach(AppModel.AppTheme.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
            }
        }
    }

    private var syncCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Sincronizzazione", systemImage: "icloud.fill").font(.headline)
                    Spacer()
                    Circle().fill(model.syncEnabled ? Color.green : Color.gray).frame(width: 9, height: 9)
                    Text(model.syncEnabled ? "Attiva" : "Disattiva").font(.caption.bold()).foregroundStyle(.secondary)
                }
                Toggle("CloudKit", isOn: Binding(get: { model.syncEnabled }, set: model.updateSync))
                Button {
                    model.refreshFromStorage()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Aggiorna adesso")
                        Spacer()
                        Text(model.lastRefresh.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.borderedProminent).tint(.appPurple)
                Text("Aggiorna manualmente le liste per visualizzare gli ingressi registrati dagli altri dispositivi.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var statsCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Riepilogo app", systemImage: "chart.bar.fill").font(.headline)
                HStack(spacing: 10) {
                    settingMetric("\(model.events.count)", "Eventi", "calendar")
                    settingMetric("\(model.totalPeople)", "Clienti", "person.2.fill")
                    settingMetric("\(model.enteredPeople)", "Entrati", "checkmark.circle.fill")
                }
            }
        }
    }

    private func settingMetric(_ value: String, _ title: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(Color.appCyan)
            Text(value).font(.title2.bold().monospacedDigit())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 12).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
    }

    private var securityCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Sicurezza", systemImage: "lock.shield.fill").font(.headline)
                Button { showPassword = true } label: {
                    Label("Cambia password di accesso", systemImage: "key.fill").frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                Text("Usa username e password per accedere in modo sicuro al tuo profilo PR.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var accountCard: some View {
        PremiumCard {
            VStack(spacing: 12) {
                Button { model.logout() } label: { Label("Esci dall’account", systemImage: "rectangle.portrait.and.arrow.right") }
                    .buttonStyle(.bordered).tint(.orange).frame(maxWidth: .infinity)
                Button(role: .destructive) { showReset = true } label: { Label("Cancella tutti i dati", systemImage: "trash.fill") }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity)
            }
        }
    }
}

struct ChangePasswordView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var password = ""
    @State private var confirmation = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Nuova password") {
                    SecureField("Almeno 4 caratteri", text: $password)
                    SecureField("Ripeti password", text: $confirmation)
                }
                Button("Salva password") {
                    model.updateProfile(password: password)
                    dismiss()
                }.disabled(password.count < 4 || password != confirmation)
            }.navigationTitle("Cambia password")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}

struct ChangePRNameView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    var body: some View {
        NavigationStack {
            Form {
                TextField("Nome PR", text: $name)
                Button("Salva nome") { model.updateProfile(name: name); dismiss() }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.navigationTitle("Modifica nome")
            .onAppear { name = model.profile?.name ?? "" }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}

struct NewEventView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""; @State private var venue = ""; @State private var date = Date()
    var body: some View {
        NavigationStack {
            Form {
                Section("Evento") { TextField("Nome serata", text: $name); TextField("Discoteca", text: $venue); DatePicker("Data e ora", selection: $date) }
                Button("Crea evento") { model.addEvent(PREvent(name: name, venue: venue, date: date)); dismiss() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || venue.trimmingCharacters(in: .whitespaces).isEmpty)
            }.navigationTitle("Nuovo evento")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}
