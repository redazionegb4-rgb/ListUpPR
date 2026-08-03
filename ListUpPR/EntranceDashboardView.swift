import SwiftUI

struct EntranceDashboardView: View {
    @EnvironmentObject var model: AppModel
    @State private var selectedEvent: PREvent?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedEvent) {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "checkmark.shield.fill").font(.title).foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Modalità ingresso").font(.headline)
                            Text("Codice: \(model.entranceCode)").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 6)
                }
                Section("Eventi") {
                    ForEach(model.events) { event in
                        NavigationLink(value: event) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(event.name).font(.headline)
                                Text("\(event.venue) • \(event.date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                                let guests = model.guestsByEvent[event.id] ?? []
                                Text("\(guests.filter(\.entered).count)/\(guests.count) entrati").font(.caption).foregroundStyle(Color.appPurple)
                            }.padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Ingresso")
            .navigationDestination(for: PREvent.self) { EventDetailView(event: $0, entranceMode: true) }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Esci") { model.logout() } } }
        } detail: {
            if let selectedEvent { EventDetailView(event: selectedEvent, entranceMode: true) }
            else { ContentUnavailableView("Seleziona un evento", systemImage: "door.left.hand.open") }
        }
    }
}
