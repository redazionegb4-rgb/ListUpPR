import SwiftUI

struct PRMainView: View {
    var body: some View {
        TabView {
            PRDashboardView().tabItem { Label("Home", systemImage: "sparkles") }
            EventsView().tabItem { Label("Eventi", systemImage: "calendar") }
            AllGuestsView().tabItem { Label("Clienti", systemImage: "person.3.fill") }
            SettingsView().tabItem { Label("Impostazioni", systemImage: "gearshape.fill") }
        }.tint(.appPurple)
    }
}

struct PRDashboardView: View {
    @EnvironmentObject var model: AppModel
    @State private var showNewEvent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Ciao, \(model.profile?.name ?? "PR")").font(.largeTitle.bold())
                            Text("Gestisci la tua prossima serata").foregroundStyle(.secondary)
                        }
                        Spacer()
                        CodeBadge(code: model.profile?.code ?? "---")
                    }

                    HStack(spacing: 12) {
                        SmallMetricCard(title: "Persone in lista", value: "\(model.totalPeople)", icon: "person.3.fill")
                        SmallMetricCard(title: "Entrate", value: "\(model.enteredPeople)", icon: "checkmark.circle.fill")
                    }

                    if let event = model.activeEvent {
                        Text("Prossimo evento").font(.title2.bold())
                        NavigationLink(value: event) { LargeEventCard(event: event, guests: model.guestsByEvent[event.id] ?? []) }.buttonStyle(.plain)
                    } else {
                        EmptyEventCard { showNewEvent = true }
                    }

                    Button { showNewEvent = true } label: { Label("Crea nuovo evento", systemImage: "plus.circle.fill") }
                        .buttonStyle(PrimaryButtonStyle())
                }.padding(20)
            }
            .navigationDestination(for: PREvent.self) { EventDetailView(event: $0, entranceMode: false) }
            .sheet(isPresented: $showNewEvent) { NewEventView() }
        }
    }
}

struct CodeBadge: View {
    let code: String
    var body: some View {
        Button { UIPasteboard.general.string = code } label: {
            VStack(spacing: 3) {
                Text("CODICE PR").font(.caption2.bold()).foregroundStyle(.secondary)
                HStack(spacing: 5) { Text(code).font(.title2.bold().monospacedDigit()); Image(systemName: "doc.on.doc") }
            }.padding(.horizontal, 14).padding(.vertical, 10).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
    }
}

struct LargeEventCard: View {
    let event: PREvent; let guests: [Guest]
    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack { Text(event.name).font(.title2.bold()); Spacer(); Image(systemName: "chevron.right") }
                Label(event.venue, systemImage: "mappin.and.ellipse")
                Label(event.date.formatted(date: .long, time: .shortened), systemImage: "calendar.badge.clock")
                Divider()
                HStack {
                    Label("\(guests.count) in lista", systemImage: "person.2.fill")
                    Spacer()
                    Label("\(guests.filter(\.entered).count) entrati", systemImage: "checkmark.circle.fill")
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
                Image(systemName: "calendar.badge.plus").font(.system(size: 40)).foregroundStyle(Color.appPurple)
                Text("Nessun evento").font(.title3.bold())
                Text("Crea la prima serata e inizia ad aggiungere clienti.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Crea evento", action: action).buttonStyle(.borderedProminent).tint(.appPurple)
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
                ForEach(model.events) { event in
                    NavigationLink(value: event) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(event.name).font(.headline)
                            Text("\(event.venue) • \(event.date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 5)
                    }.swipeActions { Button(role: .destructive) { model.deleteEvent(event) } label: { Label("Elimina", systemImage: "trash") } }
                }
            }.navigationTitle("Eventi")
            .overlay { if model.events.isEmpty { ContentUnavailableView("Nessun evento", systemImage: "calendar", description: Text("Crea il primo evento.")) } }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNewEvent = true } label: { Image(systemName: "plus") } } }
            .navigationDestination(for: PREvent.self) { EventDetailView(event: $0, entranceMode: false) }
            .sheet(isPresented: $showNewEvent) { NewEventView() }
        }
    }
}

struct AllGuestsView: View {
    @EnvironmentObject var model: AppModel
    @State private var search = ""
    var filtered: [(PREvent, Guest)] {
        model.events.flatMap { event in (model.guestsByEvent[event.id] ?? []).map { (event, $0) } }
            .filter { search.isEmpty || $0.1.fullName.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered.indices, id: \.self) { index in
                    let event = filtered[index].0
                    let guest = filtered[index].1
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text(guest.fullName).font(.headline); Spacer(); if guest.entered { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) } }
                    Text("\(event.name) • \(guest.packageName)").font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 4)
                }
            }.navigationTitle("Clienti").searchable(text: $search, prompt: "Cerca cliente")
            .overlay { if filtered.isEmpty { ContentUnavailableView("Nessun cliente", systemImage: "person.3") } }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var showReset = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Profilo PR") {
                    LabeledContent("Nome", value: model.profile?.name ?? "-")
                    LabeledContent("Codice", value: model.profile?.code ?? "-")
                    Button("Copia codice") { UIPasteboard.general.string = model.profile?.code }
                }
                Section("Aspetto") {
                    Picker("Tema", selection: Binding(get: { model.theme }, set: model.updateTheme)) {
                        ForEach(AppModel.AppTheme.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("Sincronizzazione") {
                    Toggle("CloudKit", isOn: Binding(get: { model.syncEnabled }, set: model.updateSync))
                    Text("La sincronizzazione tra dispositivi richiede iCloud attivo e il container CloudKit configurato nel progetto.").font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Button("Esci dall’account", role: .destructive) { model.logout() }
                    Button("Cancella tutti i dati", role: .destructive) { showReset = true }
                }
            }.navigationTitle("Impostazioni")
            .confirmationDialog("Cancellare tutti i dati?", isPresented: $showReset, titleVisibility: .visible) {
                Button("Cancella definitivamente", role: .destructive) { model.resetAllData() }
            }
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
