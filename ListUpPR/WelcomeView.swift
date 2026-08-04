import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var sheet: AccessSheet?

    enum AccessSheet: Identifiable { case login, register, scanner; var id: Int { hashValue } }

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
                    AccessCard(icon: "qrcode.viewfinder", eyebrow: "INGRESSO CLIENTI", title: "Scansiona QR ingresso", tint: .appCyan) { sheet = .scanner }
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
            case .scanner: GlobalEntranceScannerView()
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
                Section("Dati di accesso PR") {
                    TextField("Codice PR di 3 cifre", text: $code)
                        .keyboardType(.numberPad)
                        .onChange(of: code) { _, newValue in
                            code = String(newValue.filter(\.isNumber).prefix(3))
                        }
                    SecureField("Password", text: $password)
                }
                Section {
                    Text("Per evitare accessi al profilo sbagliato sono richiesti sia il codice PR sia la password. Password uguali tra PR diversi non creano conflitti.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if error { Text("Codice PR o password non corretti.").foregroundStyle(.red) }
                Button("Accedi") {
                    if model.loginAsPR(code: code, password: password) { dismiss() } else { error = true }
                }.disabled(code.filter(\.isNumber).count != 3 || password.isEmpty)
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

struct GlobalEntranceScannerView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showScanner = true
    @State private var scanResult: QRCheckInResult?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 22) {
                    Spacer()
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 72, weight: .semibold))
                        .foregroundStyle(Color.appCyan)
                    Text("Scanner ingresso")
                        .font(.largeTitle.bold())
                    Text("Inquadra il QR di qualsiasi cliente. L’app riconosce automaticamente evento, nominativo e profilo PR corretto.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button { showScanner = true } label: {
                        Label("Apri fotocamera", systemImage: "camera.viewfinder")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Ingresso QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Chiudi") { dismiss() } } }
            .sheet(isPresented: $showScanner) {
                QRScannerSheet { code in
                    scanResult = model.checkInFromQRCodeGlobally(code)
                }
            }
            .sheet(item: $scanResult) { result in
                QRScanResultView(result: result) {
                    scanResult = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showScanner = true }
                } onClose: {
                    scanResult = nil
                    dismiss()
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

struct QRScanResultView: View {
    let result: QRCheckInResult
    let onScanAgain: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(result.isValid ? Color.green.opacity(0.18) : Color.red.opacity(0.18))
                        .frame(width: 88, height: 88)
                    Image(systemName: result.isValid ? "checkmark.shield.fill" : "xmark.shield.fill")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(result.isValid ? .green : .red)
                }

                Text(result.title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(result.isValid ? .green : .primary)

                if !result.guestName.isEmpty {
                    Text(result.guestName).font(.title3.bold())
                }

                VStack(spacing: 12) {
                    resultRow(icon: "person.crop.circle.badge.checkmark", title: "Nome PR", value: result.prName.isEmpty ? "—" : result.prName)
                    resultRow(icon: "number", title: "Codice PR", value: result.prCode.isEmpty ? "—" : result.prCode)
                    resultRow(icon: "calendar", title: "Evento", value: result.eventName.isEmpty ? "—" : result.eventName)
                }
                .padding(16)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                if result.isValid && !result.paymentTitle.isEmpty {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: result.amountDue > 0 ? "creditcard.trianglebadge.exclamationmark.fill" : "checkmark.seal.fill")
                                .font(.title2)
                            Text(result.paymentTitle).font(.headline.bold())
                        }
                        .foregroundStyle(result.amountDue > 0 ? .orange : .green)
                        if result.amountDue > 0 {
                            Text(result.amountDue, format: .currency(code: "EUR"))
                                .font(.system(size: 30, weight: .black, design: .rounded))
                        }
                        Text(result.paymentDetail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background((result.amountDue > 0 ? Color.orange : Color.green).opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                Text(result.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button("Chiudi", action: onClose)
                        .buttonStyle(.bordered)
                    Button("Scansiona altro", action: onScanAgain)
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(24)
        }
    }

    private func resultRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color.appCyan).frame(width: 24)
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing)
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
