import Foundation
import SwiftUI

struct PRMainView: View {
    var body: some View {
        TabView {
            PRDashboardView().tabItem { Label("Home", systemImage: "house.fill") }
            EventsView().tabItem { Label("Eventi", systemImage: "calendar") }
            AllGuestsView().tabItem { Label("Clienti", systemImage: "person.3.fill") }
            SettingsView().tabItem { Label("Impostazioni", systemImage: "gearshape.fill") }
        }.tint(.appPurple)
    }
}

struct PRDashboardView: View {
    @EnvironmentObject var model: AppModel
    @State private var showNewEvent = false

    private var waiting: Int { model.totalPeople - model.enteredPeople }
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
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bentornato").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Text(model.profile?.name ?? "PR").font(.system(size: 32, weight: .black, design: .rounded))
            }
            Spacer()
            CodeBadge(code: model.profile?.code ?? "---")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Panoramica liste").font(.headline)
                    Text("Tutto sotto controllo in tempo reale").font(.caption).foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                Image(systemName: "sparkles").font(.title2.bold())
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
                Spacer()
                Text("\(Int(progress * 100))% completato")
            }.font(.caption.bold())
        }
        .foregroundStyle(.white)
        .padding(22)
        .background(LinearGradient(colors: [.appIndigo, .appPurple, .appPink], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .appPurple.opacity(0.28), radius: 24, y: 12)
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            DashboardAction(icon: "calendar.badge.plus", title: "Nuovo evento") { showNewEvent = true }
            DashboardAction(icon: "person.badge.plus", title: "Aggiungi cliente") {
                if model.events.isEmpty { showNewEvent = true }
            }
            DashboardAction(icon: "doc.on.doc", title: "Copia codice") { UIPasteboard.general.string = model.profile?.code }
        }
    }

    private var recentGuests: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ultimi clienti inseriti").font(.title3.bold())
            PremiumCard {
                if model.allGuests.isEmpty {
                    Text("Nessun cliente ancora inserito.").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(model.allGuests.suffix(4).reversed())) { guest in
                            HStack(spacing: 12) {
                                Image(systemName: guest.entered ? "checkmark.circle.fill" : "person.crop.circle")
                                    .foregroundStyle(guest.entered ? .green : Color.appPurple).font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(guest.fullName).font(.headline)
                                    Text(guest.packageName).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }.padding(.vertical, 10)
                            if guest.id != model.allGuests.suffix(4).first?.id { Divider() }
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

struct CodeBadge: View {
    let code: String
    var body: some View {
        Button { UIPasteboard.general.string = code } label: {
            VStack(spacing: 2) {
                Text("CODICE").font(.caption2.bold()).foregroundStyle(.secondary)
                HStack(spacing: 5) { Text(code).font(.title2.bold().monospacedDigit()); Image(systemName: "doc.on.doc") }
            }.padding(.horizontal, 14).padding(.vertical, 9).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
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
                        Text(event.date < .now ? "Evento trascorso" : "Evento programmato").font(.caption.bold()).foregroundStyle(event.date < .now ? Color.gray : Color.appPurple)
                    }
                    Spacer(); Image(systemName: "chevron.right.circle.fill").font(.title2).foregroundStyle(Color.appPurple)
                }
                Label(event.venue, systemImage: "mappin.and.ellipse")
                Label(event.date.formatted(date: .long, time: .shortened), systemImage: "calendar.badge.clock")
                Divider()
                HStack {
                    Label("\(guests.count) in lista", systemImage: "person.2.fill")
                    Spacer()
                    Label("\(guests.filter(\.entered).count) entrati", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
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
                ForEach(model.events.sorted { $0.date > $1.date }) { event in
                    NavigationLink(value: event) {
                        HStack(spacing: 13) {
                            GradientIcon(systemName: "music.note.list")
                            VStack(alignment: .leading, spacing: 5) {
                                Text(event.name).font(.headline)
                                Text("\(event.venue) • \(event.date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                                let guests = model.guestsByEvent[event.id] ?? []
                                Text("\(guests.filter(\.entered).count) entrati su \(guests.count)").font(.caption2.bold()).foregroundStyle(Color.appPurple)
                            }
                        }.padding(.vertical, 5)
                    }.swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { model.deleteEvent(event) } label: { Label("Elimina", systemImage: "trash") }
                        Button { _ = model.duplicateEvent(event) } label: { Label("Duplica", systemImage: "plus.square.on.square") }.tint(.appPurple)
                    }
                }
            }.navigationTitle("Eventi")
            .overlay { if model.events.isEmpty { ContentUnavailableView("Nessun evento", systemImage: "calendar", description: Text("Crea il primo evento.")) } }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNewEvent = true } label: { Image(systemName: "plus.circle.fill") } } }
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
            .filter { search.isEmpty || $0.1.fullName.localizedCaseInsensitiveContains(search) || $0.1.phone?.contains(search) == true }
    }
    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered.indices, id: \.self) { index in
                    let event = filtered[index].0
                    let guest = filtered[index].1
                    HStack(spacing: 12) {
                        Image(systemName: guest.entered ? "checkmark.circle.fill" : "person.crop.circle.fill").font(.title2).foregroundStyle(guest.entered ? .green : Color.appPurple)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(guest.fullName).font(.headline)
                            Text("\(event.name) • \(guest.packageName)").font(.caption).foregroundStyle(.secondary)
                            if let phone = guest.phone, !phone.isEmpty { Text(phone).font(.caption2).foregroundStyle(.secondary) }
                        }
                    }.padding(.vertical, 4)
                }
            }.navigationTitle("Clienti").searchable(text: $search, prompt: "Cerca nome o telefono")
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
                Section("Sicurezza") {
                    Text("Condividi il codice solo con gli addetti autorizzati alla serata.").font(.footnote).foregroundStyle(.secondary)
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
