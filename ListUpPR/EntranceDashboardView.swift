import SwiftUI

struct EntranceDashboardView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "checkmark.shield.fill").font(.title).foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Modalità ingresso").font(.headline)
                            Text("Codice PR: \(model.entranceCode)").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 6)
                }
                Section("Seleziona evento") {
                    ForEach(model.events) { event in
                        NavigationLink(value: event) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(event.name).font(.headline)
                                Text("\(event.venue) • \(event.date.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("\((model.guestsByEvent[event.id] ?? []).reduce(0) { $0 + $1.peopleCount }) persone")
                                    .font(.caption).foregroundStyle(Color.appPurple)
                            }.padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Ingresso")
            .navigationDestination(for: PREvent.self) { EventDetailView(event: $0, entranceMode: true) }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Esci") { model.logout() } } }
        }
    }
}
