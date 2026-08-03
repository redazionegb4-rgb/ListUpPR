import SwiftUI

struct PRDashboardView: View {
    @EnvironmentObject var model: AppModel
    @State private var showNewEvent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        VStack(alignment: .leading) { Text("Ciao, \(model.profile?.name ?? "PR")").font(.title.bold()); Text("Codice: \(model.profile?.code ?? "-")").foregroundStyle(.secondary) }
                        Spacer()
                        Button { UIPasteboard.general.string = model.profile?.code } label: { Image(systemName: "doc.on.doc").padding(12).background(.thinMaterial, in: Circle()) }
                    }

                    let total = model.events.reduce(0) { $0 + (model.guestsByEvent[$1.id]?.reduce(0) { $0 + $1.peopleCount } ?? 0) }
                    let entered = model.events.reduce(0) { $0 + (model.guestsByEvent[$1.id]?.filter(\.entered).reduce(0) { $0 + $1.peopleCount } ?? 0) }
                    HStack(spacing: 12) {
                        StatCard(title: "In lista", value: "\(total)", icon: "person.3.fill")
                        StatCard(title: "Entrati", value: "\(entered)", icon: "checkmark.circle.fill")
                    }

                    HStack { Text("I tuoi eventi").font(.title2.bold()); Spacer(); Button { showNewEvent = true } label: { Label("Nuovo", systemImage: "plus") } }
                    ForEach(model.events) { event in
                        NavigationLink(value: event) { EventCard(event: event, guests: model.guestsByEvent[event.id] ?? []) }.buttonStyle(.plain)
                    }
                }.padding()
            }
            .navigationDestination(for: PREvent.self) { EventDetailView(event: $0, entranceMode: false) }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Menu { Button("Esci", role: .destructive) { model.logout() } } label: { Image(systemName: "gearshape.fill") } } }
            .sheet(isPresented: $showNewEvent) { NewEventView() }
        }
    }
}

struct StatCard: View {
    let title: String; let value: String; let icon: String
    var body: some View { GlassCard { HStack { Image(systemName: icon).font(.title2); VStack(alignment: .leading) { Text(value).font(.title.bold()); Text(title).font(.caption).foregroundStyle(.secondary) }; Spacer() } }.frame(maxWidth: .infinity) }
}

struct EventCard: View {
    let event: PREvent; let guests: [Guest]
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack { VStack(alignment: .leading) { Text(event.name).font(.title3.bold()); Text(event.venue).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right") }
                HStack { Label(event.date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar"); Spacer(); Label("\(guests.reduce(0) { $0 + $1.peopleCount })", systemImage: "person.2.fill") }.font(.caption).foregroundStyle(.secondary)
            }
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
            Form {
                TextField("Nome evento", text: $name)
                TextField("Discoteca", text: $venue)
                DatePicker("Data e ora", selection: $date)
                Button("Crea evento") { model.addEvent(PREvent(name: name, venue: venue, date: date)); dismiss() }.disabled(name.isEmpty || venue.isEmpty)
            }.navigationTitle("Nuovo evento").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}
