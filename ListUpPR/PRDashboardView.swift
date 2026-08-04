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
    @State private var isRefreshing = false
    @State private var showRefreshConfirmation = false

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
            .overlay(alignment: .top) {
                if showRefreshConfirmation {
                    Label("Dati aggiornati", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(Color.green, in: Capsule())
                        .shadow(radius: 10, y: 5)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
        }
    }

    private func performRefresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            model.refreshFromStorage()
            withAnimation { isRefreshing = false; showRefreshConfirmation = true }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { showRefreshConfirmation = false }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Bentornato").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(model.profile?.name ?? "PR").font(.system(size: 30, weight: .black, design: .rounded))
            }
            Spacer()
            Button { performRefresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.headline)
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(.easeInOut(duration: 0.65), value: isRefreshing)
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)
            .accessibilityLabel("Aggiorna dati")
            Button { model.logout() } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right").font(.headline).frame(width: 44, height: 44)
                    .background(.thinMaterial, in: Circle()).foregroundStyle(.red)
            }.buttonStyle(.plain).accessibilityLabel("Esci")
        }.frame(maxWidth: .infinity)
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
                Label(italianEventDateTime(event.date), systemImage: "calendar.badge.clock")
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
    @State private var editingEvent: PREvent?
    @State private var deletingEvent: PREvent?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Eventi")
                                    .font(.system(size: 31, weight: .black, design: .rounded))
                                Text("Gestisci serate, liste e storico")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { showNewEvent = true } label: {
                                Image(systemName: "plus")
                                    .font(.title3.bold())
                                    .frame(width: 48, height: 48)
                                    .background(Color.appCyan, in: Circle())
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }

                        if !model.upcomingEvents.isEmpty {
                            Text("Eventi attivi")
                                .font(.title2.bold())
                            LazyVStack(spacing: 14) {
                                ForEach(model.upcomingEvents) { event in eventCard(event, past: false) }
                            }
                        }

                        if !model.pastEvents.isEmpty {
                            Text("Eventi passati")
                                .font(.title2.bold())
                                .padding(.top, 6)
                            LazyVStack(spacing: 14) {
                                ForEach(model.pastEvents) { event in eventCard(event, past: true) }
                            }
                        }

                        if model.events.isEmpty {
                            PremiumCard {
                                VStack(spacing: 14) {
                                    Image(systemName: "calendar.badge.plus")
                                        .font(.system(size: 42))
                                        .foregroundStyle(Color.appCyan)
                                    Text("Nessun evento")
                                        .font(.title3.bold())
                                    Text("Crea il primo evento e inizia ad aggiungere i clienti alla lista.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                    Button("Crea evento") { showNewEvent = true }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.appCyan)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 34)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: PREvent.self) { EventDetailView(event: $0, entranceMode: false) }
            .sheet(isPresented: $showNewEvent) { NewEventView() }
            .sheet(item: $editingEvent) { EditEventView(event: $0) }
            .alert("Elimina evento?", isPresented: Binding(
                get: { deletingEvent != nil },
                set: { if !$0 { deletingEvent = nil } }
            )) {
                Button("Annulla", role: .cancel) { deletingEvent = nil }
                Button("Elimina", role: .destructive) {
                    if let event = deletingEvent { model.deleteEvent(event) }
                    deletingEvent = nil
                }
            } message: {
                Text(deletingEvent.map { "Verranno eliminati definitivamente l’evento ‘\($0.name)’ e tutti i clienti collegati. Questa operazione non può essere annullata." } ?? "")
            }
        }
    }

    private func eventCard(_ event: PREvent, past: Bool) -> some View {
        let guests = model.guestsByEvent[event.id] ?? []
        let entered = guests.filter(\.entered).count
        let progress = guests.isEmpty ? 0.0 : Double(entered) / Double(guests.count)

        return ZStack(alignment: .topTrailing) {
            NavigationLink(value: event) {
                PremiumCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(LinearGradient(colors: past ? [.gray, .secondary] : [Color.appCyan, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                                Image(systemName: past ? "clock.arrow.circlepath" : "calendar.badge.clock")
                                    .font(.system(size: 25, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 60, height: 60)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(event.name)
                                    .font(.title3.bold())
                                Text(event.venue)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(italianEventDateTime(event.date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Color.clear.frame(width: 42, height: 42)
                        }

                        ProgressView(value: progress)
                            .tint(past ? .gray : .appCyan)

                        HStack {
                            Label("\(guests.count) in lista", systemImage: "person.2.fill")
                            Spacer()
                            Label("\(entered) entrati", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(past ? Color.secondary : Color.green)
                        }
                        .font(.subheadline.bold())
                    }
                }
            }
            .buttonStyle(.plain)

            Menu {
                Button { editingEvent = event } label: {
                    Label("Modifica evento", systemImage: "pencil")
                }
                Button { _ = model.duplicateEvent(event) } label: {
                    Label("Duplica evento", systemImage: "plus.square.on.square")
                }
                Divider()
                Button(role: .destructive) { deletingEvent = event } label: {
                    Label("Elimina evento", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.appCyan)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
            .padding(.trailing, 14)
        }
        .contextMenu {
            Button { editingEvent = event } label: { Label("Modifica evento", systemImage: "pencil") }
            Button { _ = model.duplicateEvent(event) } label: { Label("Duplica evento", systemImage: "plus.square.on.square") }
            Button(role: .destructive) { deletingEvent = event } label: { Label("Elimina evento", systemImage: "trash") }
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
    @State private var targetEvent: PREvent?
    @State private var isRefreshing = false
    @State private var showRefreshConfirmation = false
    @State private var showNewEvent = false

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
                    LazyVStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Clienti").font(.system(size: 30, weight: .black, design: .rounded))
                                Text(showPast ? "Archivio degli eventi conclusi" : "Gestisci liste e ingressi").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                if let event = model.activeEvent { targetEvent = event } else { showNewEvent = true }
                            } label: {
                                Image(systemName: "plus").font(.headline).frame(width: 44, height: 44)
                                    .background(Color.appCyan, in: Circle()).foregroundStyle(.white)
                            }.buttonStyle(.plain)
                        }

                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            TextField("Cerca nome, telefono o pacchetto", text: $search)
                                .textInputAutocapitalization(.never)
                            if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) } }
                        }
                        .padding(.horizontal, 15).frame(height: 50)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))

                        Picker("Archivio", selection: $showPast) {
                            Text("Eventi attivi").tag(false); Text("Eventi passati").tag(true)
                        }.pickerStyle(.segmented)

                        if filtered.isEmpty {
                            PremiumCard {
                                VStack(spacing: 12) {
                                    Image(systemName: search.isEmpty ? "person.3" : "magnifyingglass").font(.system(size: 32)).foregroundStyle(Color.appCyan)
                                    Text(search.isEmpty ? (showPast ? "Nessun cliente nello storico" : "Nessun cliente") : "Nessun risultato").font(.headline)
                                    Text(search.isEmpty ? "Aggiungi il primo cliente usando il pulsante +." : "Prova con un altro nome, telefono o pacchetto.")
                                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                                }.frame(maxWidth: .infinity).padding(.vertical, 14)
                            }
                        } else {
                            ForEach(filtered) { pair in clientCard(pair) }
                        }
                    }.padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $targetEvent) { event in AddGuestView(eventID: event.id) }
            .sheet(isPresented: $showNewEvent) { NewEventView() }
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
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle().fill((pair.guest.entered ? Color.green : Color.appCyan).opacity(0.16)).frame(width: 48, height: 48)
                        Image(systemName: pair.guest.entered ? "checkmark" : "person.fill").font(.headline).foregroundStyle(pair.guest.entered ? .green : Color.appCyan)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(pair.guest.fullName).font(.headline)
                        Text(pair.event.name).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(pair.guest.entered ? "ENTRATO" : "DA ENTRARE").font(.caption2.bold()).padding(.horizontal, 9).padding(.vertical, 6)
                        .background((pair.guest.entered ? Color.green : Color.orange).opacity(0.14), in: Capsule())
                        .foregroundStyle(pair.guest.entered ? .green : .orange)
                }
                HStack(spacing: 12) {
                    Label(pair.guest.packageName, systemImage: "ticket.fill")
                    Spacer()
                    Text(pair.guest.price <= 0 ? "Omaggio" : pair.guest.price.formatted(.currency(code: "EUR"))).bold()
                }.font(.subheadline)
                HStack(spacing: 10) {
                    Button { qrPair = pair } label: { Label("QR", systemImage: "qrcode") }.buttonStyle(.borderedProminent).tint(.appCyan)
                    Button { editingPair = pair } label: { Label("Modifica", systemImage: "pencil") }.buttonStyle(.bordered)
                    Spacer()
                    Button(role: .destructive) { deletingPair = pair } label: { Label("Elimina", systemImage: "trash") }.buttonStyle(.bordered)
                }.font(.caption.bold())
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
            .navigationBarTitleDisplayMode(.inline)
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
            .navigationBarTitleDisplayMode(.inline)
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
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { name = model.profile?.name ?? "" }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}

struct NewEventView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var venue = ""
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        FormHero(icon: "calendar.badge.plus", title: "Nuovo evento", subtitle: "Crea la serata e prepara la lista clienti")

                        ModernFormCard(title: "Informazioni evento", icon: "calendar") {
                            ModernTextField(title: "Nome serata", placeholder: "Es. White Party", text: $name, icon: "sparkles")
                            ModernTextField(title: "Locale", placeholder: "Es. Le Capannine", text: $venue, icon: "mappin.and.ellipse")
                        }

                        ModernFormCard(title: "Data e orario", icon: "clock") {
                            DatePicker("Quando si svolge", selection: $date)
                                .datePickerStyle(.graphical)
                                .environment(\.locale, Locale(identifier: "it_IT"))
                        }

                        PremiumCard {
                            HStack {
                                Image(systemName: "info.circle.fill").foregroundStyle(Color.appCyan)
                                Text("Dopo la mezzanotte del giorno successivo, l’evento verrà spostato automaticamente tra gli eventi passati.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            model.addEvent(PREvent(name: name, venue: venue, date: date))
                            dismiss()
                        } label: {
                            Label("Crea evento", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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


struct EditEventView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    let originalEvent: PREvent

    @State private var name: String
    @State private var venue: String
    @State private var date: Date

    init(event: PREvent) {
        originalEvent = event
        _name = State(initialValue: event.name)
        _venue = State(initialValue: event.venue)
        _date = State(initialValue: event.date)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        FormHero(icon: "pencil.and.list.clipboard", title: "Modifica evento", subtitle: "Aggiorna i dettagli della serata")

                        ModernFormCard(title: "Informazioni evento", icon: "calendar") {
                            ModernTextField(title: "Nome serata", placeholder: "Es. White Party", text: $name, icon: "sparkles")
                            ModernTextField(title: "Locale", placeholder: "Es. Le Capannine", text: $venue, icon: "mappin.and.ellipse")
                        }

                        ModernFormCard(title: "Data e orario", icon: "clock") {
                            DatePicker("Quando si svolge", selection: $date)
                                .datePickerStyle(.graphical)
                                .environment(\.locale, Locale(identifier: "it_IT"))
                        }

                        Button {
                            var updated = originalEvent
                            updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            updated.venue = venue.trimmingCharacters(in: .whitespacesAndNewlines)
                            updated.date = date
                            model.updateEvent(updated)
                            dismiss()
                        } label: {
                            Label("Salva modifiche", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
