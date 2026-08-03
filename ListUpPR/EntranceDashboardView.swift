import SwiftUI

struct EntranceDashboardView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        NavigationStack {
            List {
                Section { HStack { Image(systemName: "checkmark.shield.fill").foregroundStyle(.green); VStack(alignment: .leading) { Text("Modalità ingresso").font(.headline); Text("Codice: \(model.entranceCode)").font(.caption).foregroundStyle(.secondary) } } }
                Section("Eventi disponibili") {
                    ForEach(model.events) { event in
                        NavigationLink(value: event) { VStack(alignment: .leading) { Text(event.name).font(.headline); Text("\(event.venue) • \(event.date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) } }
                    }
                }
            }
            .navigationTitle("Ingresso")
            .navigationDestination(for: PREvent.self) { EventDetailView(event: $0, entranceMode: true) }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Esci") { model.logout() } } }
        }
    }
}
