import SwiftUI

struct EntranceDashboardView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedEventID: UUID?

    private var selectedEvent: PREvent? {
        if let selectedEventID {
            return model.events.first(where: { $0.id == selectedEventID })
        }
        return model.events.first
    }

    private var totalGuests: Int {
        model.events.reduce(0) { $0 + (model.guestsByEvent[$1.id]?.count ?? 0) }
    }

    private var enteredGuests: Int {
        model.events.reduce(0) { partial, event in
            partial + (model.guestsByEvent[event.id]?.filter(\.entered).count ?? 0)
        }
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                entranceEventList
                    .navigationTitle("Ingresso")
                    .toolbar { toolbarContent }
            } detail: {
                if let event = selectedEvent {
                    NavigationStack { EventDetailView(event: event, entranceMode: true) }
                } else {
                    ContentUnavailableView("Seleziona un evento", systemImage: "rectangle.split.2x1")
                }
            }
            .onAppear {
                if selectedEventID == nil { selectedEventID = model.events.first?.id }
            }
        } else {
            NavigationStack {
                entranceEventList
                    .navigationTitle("Ingresso")
                    .navigationDestination(for: PREvent.self) { EventDetailView(event: $0, entranceMode: true) }
                    .toolbar { toolbarContent }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                model.refreshFromStorage()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Aggiorna liste")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Esci") { model.logout() }
        }
    }

    private var entranceEventList: some View {
        List {
            Section {
                entranceProfileCard
                    .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                    .listRowBackground(Color.clear)
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
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .refreshable { model.refreshFromStorage() }
    }

    private var entranceProfileCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.appPurple, .appPink], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Image(systemName: "person.badge.key.fill")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                    .frame(width: 58, height: 58)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Profilo ingresso")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(model.profile?.name ?? "PR")
                            .font(.title3.bold())
                        Text("Accesso autorizzato alle liste")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.shield.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }

                Divider()

                HStack(spacing: 10) {
                    entranceMetric(title: "Codice PR", value: model.entranceCode.isEmpty ? (model.profile?.code ?? "---") : model.entranceCode, icon: "number")
                    entranceMetric(title: "Eventi", value: "\(model.events.count)", icon: "calendar")
                    entranceMetric(title: "Ingressi", value: "\(enteredGuests)/\(totalGuests)", icon: "person.fill.checkmark")
                }

                Button {
                    model.refreshFromStorage()
                } label: {
                    Label("Aggiorna liste e ingressi", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.appPurple)
            }
        }
    }

    private func entranceMetric(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(Color.appCyan)
            Text(value)
                .font(.headline.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func eventRow(_ event: PREvent) -> some View {
        let guests = model.guestsByEvent[event.id] ?? []
        let entered = guests.filter(\.entered).count

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.name).font(.headline)
                    Text(event.venue).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(entered)/\(guests.count)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(Color.appPurple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appPurple.opacity(0.10), in: Capsule())
            }

            HStack {
                Label(event.date.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                Spacer()
                Text(guests.isEmpty ? "Nessun cliente" : "\(guests.count - entered) attesi")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
