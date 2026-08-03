import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var sheet: AccessSheet?

    enum AccessSheet: Identifiable { case login, register, entrance; var id: Int { hashValue } }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 36)
                BrandMark().padding(.bottom, 4)
                VStack(spacing: 8) {
                    Text("Guestly PR").font(.system(size: 40, weight: .black, design: .rounded))
                    Text("La tua serata, organizzata bene.").font(.title3.weight(.medium))
                    Text("Liste, pacchetti e ingressi sincronizzati in un’unica app.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                }

                VStack(spacing: 14) {
                    Button { sheet = .login } label: {
                        Label("Accedi come PR", systemImage: "person.crop.circle.badge.checkmark")
                    }.buttonStyle(PrimaryButtonStyle())

                    AccessCard(icon: "sparkles", eyebrow: "PRIMO ACCESSO?", title: "Registrati come PR", tint: .appPurple) { sheet = .register }
                    AccessCard(icon: "checkmark.shield.fill", eyebrow: "ADDETTO ALL’INGRESSO?", title: "Accedi con il codice", tint: .appCyan) { sheet = .entrance }
                }

                HStack(spacing: 8) {
                    Image(systemName: "icloud.fill")
                    Text("Dati salvati sul dispositivo e predisposti per CloudKit")
                }.font(.footnote).foregroundStyle(.secondary)
                Spacer(minLength: 24)
            }.padding(.horizontal, 22)
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .login: PRLoginView()
            case .register: RegisterPRView()
            case .entrance: EntranceLoginView()
            }
        }
    }
}

struct BrandMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [.appPurple, .appPink], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 104, height: 104)
                .shadow(color: .appPurple.opacity(0.35), radius: 28, y: 12)
            Image(systemName: "person.2.badge.gearshape.fill")
                .font(.system(size: 45, weight: .bold)).foregroundStyle(.white)
        }
    }
}

struct AccessCard: View {
    let icon: String, eyebrow: String, title: String, tint: Color, action: () -> Void
    var body: some View {
        Button(action: action) {
            PremiumCard {
                HStack(spacing: 15) {
                    Image(systemName: icon).font(.title2).foregroundStyle(tint)
                        .frame(width: 48, height: 48).background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(eyebrow).font(.caption2.bold()).foregroundStyle(.secondary)
                        Text(title).font(.headline).foregroundStyle(.primary)
                    }
                    Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
            }
        }.buttonStyle(.plain)
    }
}

struct PRLoginView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var code = ""
    @State private var password = ""
    @State private var error = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Accedi con uno dei due dati") {
                    TextField("Codice PR di 3 cifre", text: $code)
                        .keyboardType(.numberPad)
                        .onChange(of: code) { _, newValue in
                            code = String(newValue.filter(\.isNumber).prefix(3))
                        }
                    SecureField("Oppure inserisci la password", text: $password)
                }
                Section {
                    Text("Non è necessario compilare entrambi i campi: puoi entrare usando solamente il codice PR oppure solamente la password.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if error { Text("Codice o password non corretti.").foregroundStyle(.red) }
                Button("Accedi") {
                    if model.loginAsPR(code: code, password: password) { dismiss() } else { error = true }
                }.disabled(code.filter(\.isNumber).count != 3 && password.isEmpty)
            }
            .navigationTitle("Bentornato")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}

struct RegisterPRView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Il tuo profilo") { TextField("Nome PR o nome del gruppo", text: $name) }
                Section("Password di accesso") {
                    SecureField("Minimo 4 caratteri", text: $password)
                    SecureField("Ripeti password", text: $confirm)
                }
                Section {
                    Text("Alla registrazione verrà generato automaticamente un codice numerico di 3 cifre.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if showError { Text("Controlla nome e password.").foregroundStyle(.red) }
                Button("Registrati e genera codice") {
                    guard password == confirm, model.registerPR(name: name, password: password) else { showError = true; return }
                    dismiss()
                }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || password.count < 4 || password != confirm)
            }
            .navigationTitle("Nuovo profilo PR")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}

struct EntranceLoginView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var code = ""
    @State private var error = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "door.left.hand.open").font(.system(size: 58)).foregroundStyle(Color.appCyan)
                Text("Accesso ingresso").font(.largeTitle.bold())
                Text("Inserisci il codice di 3 cifre ricevuto dal PR.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                TextField("000", text: $code).keyboardType(.numberPad).multilineTextAlignment(.center)
                    .font(.system(size: 34, weight: .bold, design: .rounded)).padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                if error { Text("Codice non valido.").foregroundStyle(.red) }
                Button("Apri la lista") {
                    if model.loginEntrance(code: code) { dismiss() } else { error = true }
                }.buttonStyle(PrimaryButtonStyle()).disabled(code.filter(\.isNumber).count != 3)
                Spacer()
            }.padding(24)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}
