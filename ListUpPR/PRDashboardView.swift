import Foundation
import SwiftUI

struct PRMainView: View {
    var body: some View {
        TabView {
            PRDashboardView().tabItem { Label("Home", systemImage: "sparkles") }
            EventsView().tabItem { Label("Eventi", systemImage: "calendar") }
            AllGuestsView().tabItem { Label("Clienti", systemImage: "person.3.fill") }
            ReportsView().tabItem { Label("Rendiconto", systemImage: "chart.bar.fill") }
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
                    }.swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { model.deleteEvent(event) } label: { Label("Elimina", systemImage: "trash") }
                        Button { _ = model.duplicateEvent(event) } label: { Label("Duplica", systemImage: "plus.square.on.square") }.tint(.appPurple)
                    }
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


struct ReportsView: View {
    @EnvironmentObject var model: AppModel
    @State private var selectedEventID: UUID?

    private var selectedEvent: PREvent? {
        if let selectedEventID, let event = model.events.first(where: { $0.id == selectedEventID }) { return event }
        return model.events.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let event = selectedEvent {
                    EventReportView(event: event)
                } else {
                    ContentUnavailableView("Nessun rendiconto", systemImage: "chart.bar", description: Text("Crea un evento per visualizzare statistiche e incassi."))
                }
            }
            .navigationTitle("Rendiconto")
            .toolbar {
                if !model.events.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            ForEach(model.events) { event in
                                Button {
                                    selectedEventID = event.id
                                } label: {
                                    if selectedEvent?.id == event.id { Label(event.name, systemImage: "checkmark") }
                                    else { Text(event.name) }
                                }
                            }
                        } label: { Label("Evento", systemImage: "calendar") }
                    }
                }
            }
        }
    }
}

struct EventReportView: View {
    @EnvironmentObject var model: AppModel
    let event: PREvent

    private var guests: [Guest] { model.guestsByEvent[event.id] ?? [] }
    private var entered: [Guest] { guests.filter(\.entered) }
    private var absentCount: Int { max(0, guests.count - entered.count) }
    private var attendance: Double { guests.isEmpty ? 0 : (Double(entered.count) / Double(guests.count)) * 100 }
    private var listValue: Double { guests.reduce(0) { $0 + $1.price } }
    private var collected: Double { guests.reduce(0) { $0 + min($1.deposit, $1.price) } }
    private var remaining: Double { guests.reduce(0) { $0 + $1.remaining } }
    private var packages: [(name: String, guests: [Guest])] {
        Dictionary(grouping: guests) { $0.packageName.isEmpty ? "Senza pacchetto" : $0.packageName }
            .map { (name: $0.key, guests: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PremiumCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.name).font(.title2.bold())
                        Label(event.venue, systemImage: "mappin.and.ellipse")
                        Label(event.date.formatted(date: .long, time: .shortened), systemImage: "calendar")
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ReportMetric(title: "In lista", value: "\(guests.count)", icon: "person.3.fill")
                    ReportMetric(title: "Entrati", value: "\(entered.count)", icon: "checkmark.circle.fill")
                    ReportMetric(title: "Assenti", value: "\(absentCount)", icon: "person.crop.circle.badge.xmark")
                    ReportMetric(title: "Affluenza", value: String(format: "%.0f%%", attendance), icon: "chart.line.uptrend.xyaxis")
                    ReportMetric(title: "Valore lista", value: listValue.formatted(.currency(code: "EUR")), icon: "eurosign.circle.fill")
                    ReportMetric(title: "Incassato", value: collected.formatted(.currency(code: "EUR")), icon: "banknote.fill")
                    ReportMetric(title: "Da riscuotere", value: remaining.formatted(.currency(code: "EUR")), icon: "clock.badge.exclamationmark")
                }

                Text("Riepilogo pacchetti").font(.title2.bold())
                if packages.isEmpty {
                    ContentUnavailableView("Nessun pacchetto", systemImage: "ticket")
                } else {
                    ForEach(packages, id: \.name) { package in
                        PremiumCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(package.name).font(.headline)
                                    Spacer()
                                    Text("\(package.guests.count) clienti").foregroundStyle(.secondary)
                                }
                                Divider()
                                LabeledContent("Entrati", value: "\(package.guests.filter(\.entered).count)")
                                LabeledContent("Valore", value: package.guests.reduce(0) { $0 + $1.price }.formatted(.currency(code: "EUR")))
                                LabeledContent("Incassato", value: package.guests.reduce(0) { $0 + min($1.deposit, $1.price) }.formatted(.currency(code: "EUR")))
                            }
                        }
                    }
                }
            }.padding(20)
        }
    }
}

struct ReportMetric: View {
    let title: String
    let value: String
    let icon: String
    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).font(.title2).foregroundStyle(Color.appPurple)
                Text(value).font(.title2.bold()).minimumScaleFactor(0.7)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
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
