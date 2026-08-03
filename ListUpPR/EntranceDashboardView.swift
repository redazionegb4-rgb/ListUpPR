import SwiftUI

struct EntranceDashboardView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedEventID: UUID?

    private var selectedEvent: PREvent? {
        if let selectedEventID { return model.events.first(where: { $0.id == selectedEventID }) }
        return model.events.first
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                entranceEventList
                    .navigationTitle("Ingresso")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Esci") { model.logout() } } }
            } detail: {
                if let event = selectedEvent {
                    NavigationStack { EventDetailView(event: event, entranceMode: true) }
                } else {
                    ContentUnavailableView("Seleziona un evento", systemImage: "rectangle.split.2x1")
                }
            }
            .onAppear { if selectedEventID == nil { selectedEventID = model.events.first?.id } }
        } else {
            NavigationStack {
                entranceEventList
                    .navigationTitle("Ingresso")
                    .navigationDestination(for: PREvent.self) { EventDetailView(event: $0, entranceMode: true) }
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Esci") { model.logout() } } }
            }
        }
    }

    private var entranceEventList: some View {
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
                    if horizontalSizeClass == .regular {
                        Button { selectedEventID = event.id } label: { eventRow(event) }
                            .buttonStyle(.plain)
                            .listRowBackground(selectedEventID == event.id ? Color.appPurple.opacity(0.12) : Color.clear)
                    } else {
                        NavigationLink(value: event) { eventRow(event) }
                    }
                }
            }
        }
    }

    private func eventRow(_ event: PREvent) -> some View {
        let guests = model.guestsByEvent[event.id] ?? []
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(event.name).font(.headline)
                Spacer()
                Text("\(guests.filter(\.entered).count)/\(guests.count)").font(.caption.bold()).foregroundStyle(Color.appPurple)
            }
            Text("\(event.venue) • \(event.date.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 5)
    }
}
