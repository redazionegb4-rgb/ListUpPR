import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var showRegister = false
    @State private var showEntrance = false

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                Spacer(minLength: 36)
                ZStack {
                    Circle().fill(LinearGradient.club).frame(width: 98, height: 98).blur(radius: 18)
                    Image(systemName: "person.3.sequence.fill").font(.system(size: 45, weight: .bold)).foregroundStyle(.white)
                }
                VStack(spacing: 8) {
                    Text("ListUp PR").font(.system(size: 38, weight: .black, design: .rounded))
                    Text("Liste, ingressi e serate. Tutto sotto controllo.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                }

                VStack(spacing: 14) {
                    if model.profile != nil {
                        Button { model.loginAsPR() } label: { Label("Accedi come PR", systemImage: "person.crop.circle.fill") }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    Button { showRegister = true } label: {
                        GlassCard { HStack { Image(systemName: "sparkles"); VStack(alignment: .leading) { Text("Primo accesso?").font(.caption).foregroundStyle(.secondary); Text("Registrati come PR").font(.headline) }; Spacer(); Image(systemName: "chevron.right") } }
                    }.buttonStyle(.plain)
                    Button { showEntrance = true } label: {
                        GlassCard { HStack { Image(systemName: "checkmark.shield.fill"); VStack(alignment: .leading) { Text("Addetto all’ingresso?").font(.caption).foregroundStyle(.secondary); Text("Accedi con il codice PR").font(.headline) }; Spacer(); Image(systemName: "chevron.right") } }
                    }.buttonStyle(.plain)
                }
                Text("La prima build salva tutto sul dispositivo. La struttura è già predisposta per la sincronizzazione CloudKit tra PR e addetto.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            }.padding(22)
        }
        .sheet(isPresented: $showRegister) { RegisterPRView() }
        .sheet(isPresented: $showEntrance) { EntranceLoginView() }
    }
}

struct RegisterPRView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Il tuo profilo PR") { TextField("Nome e cognome o nome del gruppo", text: $name) }
                Section { Button("Crea profilo e genera codice") { model.registerPR(name: name); dismiss() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
            }.navigationTitle("Registrazione PR").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}

struct EntranceLoginView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var code = ""
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "key.fill").font(.system(size: 52)).foregroundStyle(LinearGradient.club)
                Text("Inserisci il codice ricevuto dal PR").font(.title3.bold())
                TextField("PR-123456", text: $code).textInputAutocapitalization(.characters).textFieldStyle(.roundedBorder)
                Button("Apri lista clienti") { if model.loginEntrance(code: code) { dismiss() } }.buttonStyle(PrimaryButtonStyle()).disabled(code.isEmpty)
                Spacer()
            }.padding().navigationTitle("Accesso ingresso").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}
