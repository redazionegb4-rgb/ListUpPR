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
                    Text("ListUp PR").font(.system(size: 40, weight: .black, design: .rounded))
                    Text("La tua serata, organizzata bene.").font(.title3.weight(.medium))
                    Text("Liste, pacchetti e ingressi sincronizzati in un’unica app.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                }

                VStack(spacing: 14) {
                    Button { sheet = .login } label: {
                        Label("Accedi come PR", systemImage: "person.crop.circle.badge.checkmark")
                    }.buttonStyle(PrimaryButtonStyle())

                    AccessCard(icon: "sparkles", eyebrow: "PRIMO ACCESSO?", title: "Registrati come PR", tint: .appCyan) { sheet = .register }
                    AccessCard(icon: "qrcode.viewfinder", eyebrow: "INGRESSO CLIENTI", title: "Scansiona QR ingresso", tint: .green) { sheet = .scanner }
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
                .fill(LinearGradient(colors: [.blue, .appCyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 104, height: 104)
                .shadow(color: .appCyan.opacity(0.30), radius: 28, y: 12)
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
    @State private var username = ""
    @State private var password = ""
    @State private var error = false
    @State private var showRecovery = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 22) {
                        accessHero(icon: "person.crop.circle.badge.checkmark", title: "Bentornato", subtitle: "Accedi al tuo profilo PR con username e password")

                        PremiumCard {
                            VStack(spacing: 16) {
                                ModernAccessField(icon: "at", title: "Username", placeholder: "Il tuo username", text: $username)
                                ModernSecureField(icon: "lock.fill", title: "Password", placeholder: "La tua password", text: $password)
                            }
                        }

                        if error {
                            Label("Username o password non corretti.", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            error = !model.loginAsPR(username: username, password: password)
                            if !error { dismiss() }
                        } label: {
                            Label("Accedi al profilo", systemImage: "arrow.right.circle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)

                        Button("Hai dimenticato username o password?") { showRecovery = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appCyan)

                        Text("L’username identifica in modo univoco il tuo profilo, anche quando altri PR scelgono la stessa password.")
                            .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Accesso PR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") } } }
            .sheet(isPresented: $showRecovery) { ForgotCredentialsView() }
        }
    }
}

struct RegisterPRView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var recoveryPIN = ""
    @State private var confirmPIN = ""
    @State private var showError = false

    private var normalizedUsername: String { username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    private var usernameFormatValid: Bool {
        normalizedUsername.count >= 4 && normalizedUsername.count <= 24 && normalizedUsername.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 22) {
                        accessHero(icon: "person.badge.plus", title: "Crea il tuo profilo", subtitle: "Organizza eventi e liste in uno spazio personale e separato")

                        PremiumCard {
                            VStack(spacing: 16) {
                                ModernAccessField(icon: "person.fill", title: "Nome PR", placeholder: "Es. Demetrio o Team White", text: $name)
                                ModernAccessField(icon: "at", title: "Username", placeholder: "Es. demetrio.pr", text: $username)
                                ModernSecureField(icon: "lock.fill", title: "Password", placeholder: "Minimo 4 caratteri", text: $password)
                                ModernSecureField(icon: "checkmark.shield.fill", title: "Conferma password", placeholder: "Ripeti la password", text: $confirm)
                                ModernAccessField(icon: "number.square.fill", title: "PIN di recupero", placeholder: "6 cifre", text: $recoveryPIN, keyboard: .numberPad)
                                ModernAccessField(icon: "checkmark.rectangle.fill", title: "Conferma PIN", placeholder: "Ripeti le 6 cifre", text: $confirmPIN, keyboard: .numberPad)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Username da 4 a 24 caratteri", systemImage: usernameFormatValid ? "checkmark.circle.fill" : "circle")
                            Label("Usa lettere, numeri, punto o trattino basso", systemImage: usernameFormatValid ? "checkmark.circle.fill" : "circle")
                            Label("Password uguali tra PR diversi sono consentite", systemImage: "checkmark.circle.fill")
                            Label("Il PIN di 6 cifre serve solo per recuperare l’account", systemImage: recoveryPIN.filter(\.isNumber).count == 6 && recoveryPIN == confirmPIN ? "checkmark.circle.fill" : "circle")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if showError {
                            Label("Username già utilizzato oppure dati non validi.", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            guard password == confirm,
                                  model.registerPR(name: name, username: normalizedUsername, password: password, recoveryPIN: recoveryPIN) else {
                                showError = true
                                return
                            }
                            dismiss()
                        } label: {
                            Label("Crea profilo PR", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !usernameFormatValid || password.count < 4 || password != confirm || recoveryPIN.filter(\.isNumber).count != 6 || recoveryPIN != confirmPIN)
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Registrazione PR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") } } }
        }
    }
}

struct ForgotCredentialsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var mode = 0
    @State private var prName = ""
    @State private var username = ""
    @State private var pin = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var recoveredUsername: String?
    @State private var message = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        accessHero(icon: "key.viewfinder", title: "Recupera account", subtitle: "Usa il PIN di recupero scelto durante la registrazione")
                        Picker("Recupero", selection: $mode) {
                            Text("Username").tag(0)
                            Text("Password").tag(1)
                        }
                        .pickerStyle(.segmented)

                        PremiumCard {
                            VStack(spacing: 16) {
                                if mode == 0 {
                                    ModernAccessField(icon: "person.fill", title: "Nome PR", placeholder: "Nome del profilo", text: $prName)
                                } else {
                                    ModernAccessField(icon: "at", title: "Username", placeholder: "Il tuo username", text: $username)
                                    ModernSecureField(icon: "lock.rotation", title: "Nuova password", placeholder: "Minimo 4 caratteri", text: $newPassword)
                                    ModernSecureField(icon: "checkmark.shield.fill", title: "Conferma password", placeholder: "Ripeti la password", text: $confirmPassword)
                                }
                                ModernAccessField(icon: "number.square.fill", title: "PIN di recupero", placeholder: "6 cifre", text: $pin, keyboard: .numberPad)
                            }
                        }

                        if let recoveredUsername {
                            PremiumCard {
                                VStack(spacing: 6) {
                                    Text("Il tuo username è").foregroundStyle(.secondary)
                                    Text(recoveredUsername).font(.title2.bold()).textSelection(.enabled)
                                }.frame(maxWidth: .infinity)
                            }
                        }
                        if !message.isEmpty {
                            Text(message).font(.subheadline.weight(.semibold)).foregroundStyle(message.contains("corretta") ? .green : .red)
                        }

                        Button {
                            if mode == 0 {
                                recoveredUsername = model.recoverUsername(name: prName, recoveryPIN: pin)
                                message = recoveredUsername == nil ? "Dati di recupero non corretti." : "Username recuperato correttamente."
                            } else {
                                guard newPassword == confirmPassword else { message = "Le password non coincidono."; return }
                                let ok = model.resetForgottenPassword(username: username, recoveryPIN: pin, newPassword: newPassword)
                                message = ok ? "Password aggiornata correttamente." : "Username o PIN non corretti."
                            }
                        } label: {
                            Label(mode == 0 ? "Recupera username" : "Reimposta password", systemImage: "checkmark.shield.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Recupero accesso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") } } }
        }
    }
}

@ViewBuilder
private func accessHero(icon: String, title: String, subtitle: String) -> some View {
    VStack(spacing: 14) {
        ZStack {
            Circle().fill(Color.appCyan.opacity(0.15)).frame(width: 86, height: 86)
            Image(systemName: icon).font(.system(size: 38, weight: .bold)).foregroundStyle(Color.appCyan)
        }
        Text(title).font(.system(size: 31, weight: .black, design: .rounded))
        Text(subtitle).foregroundStyle(.secondary).multilineTextAlignment(.center)
    }
}

struct ModernAccessField: View {
    let icon: String, title: String, placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon).foregroundStyle(Color.appCyan).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                TextField(placeholder, text: $text).keyboardType(keyboard).textInputAutocapitalization(.never).autocorrectionDisabled()
            }
        }
        .padding(14).background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ModernSecureField: View {
    let icon: String, title: String, placeholder: String
    @Binding var text: String
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon).foregroundStyle(Color.appCyan).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                SecureField(placeholder, text: $text).textInputAutocapitalization(.never)
            }
        }
        .padding(14).background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
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
                    Text("Scanner ingresso").font(.largeTitle.bold())
                    Text("Inquadra il QR di qualsiasi cliente. L’app riconosce automaticamente evento, nominativo e profilo PR corretto.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    Button { showScanner = true } label: { Label("Apri fotocamera", systemImage: "camera.viewfinder") }
                        .buttonStyle(PrimaryButtonStyle())
                    Spacer()
                }.padding(24)
            }
            .navigationTitle("Ingresso QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Chiudi") { dismiss() } } }
            .sheet(isPresented: $showScanner) {
                QRScannerSheet { code in scanResult = model.checkInFromQRCodeGlobally(code) }
            }
            .fullScreenCover(item: $scanResult) { result in
                QRScanResultView(result: result) {
                    scanResult = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { showScanner = true }
                } onClose: {
                    scanResult = nil
                    dismiss()
                }
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
            AppBackground().ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    HStack {
                        Text("Esito scansione").font(.headline)
                        Spacer()
                        Button("Chiudi", action: onClose).buttonStyle(.bordered)
                    }

                    ZStack {
                        Circle().fill(result.isValid ? Color.green.opacity(0.16) : Color.red.opacity(0.16)).frame(width: 112, height: 112)
                        Image(systemName: result.isValid ? "checkmark.shield.fill" : "xmark.shield.fill")
                            .font(.system(size: 54, weight: .bold)).foregroundStyle(result.isValid ? .green : .red)
                    }
                    Text(result.title).font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(result.isValid ? .green : .red)
                    if !result.guestName.isEmpty { Text(result.guestName).font(.title.bold()).multilineTextAlignment(.center) }

                    PremiumCard {
                        VStack(spacing: 15) {
                            resultRow(icon: "person.fill", title: "Cliente", value: result.guestName.isEmpty ? "—" : result.guestName)
                            Divider()
                            resultRow(icon: "person.crop.circle.badge.checkmark", title: "Nome PR", value: result.prName.isEmpty ? "—" : result.prName)
                            Divider()
                            resultRow(icon: "number", title: "Codice PR", value: result.prCode.isEmpty ? "—" : result.prCode)
                            Divider()
                            resultRow(icon: "calendar", title: "Evento", value: result.eventName.isEmpty ? "—" : result.eventName)
                            Divider()
                            resultRow(icon: "mappin.and.ellipse", title: "Locale / Discoteca", value: result.venueName.isEmpty ? "—" : result.venueName)
                            Divider()
                            resultRow(icon: "ticket.fill", title: "Pacchetto", value: result.packageName.isEmpty ? "—" : result.packageName)
                            Divider()
                            resultRow(icon: "calendar.badge.clock", title: "Data evento", value: result.eventDate.isEmpty ? "—" : result.eventDate)
                        }
                    }

                    if result.isValid {
                        VStack(spacing: 12) {
                            Label(result.paymentTitle, systemImage: result.amountDue > 0 ? "creditcard.trianglebadge.exclamationmark" : "checkmark.circle.fill")
                                .font(.headline).foregroundStyle(result.amountDue > 0 ? .orange : .green)
                            if result.amountDue > 0 { Text(result.amountDue, format: .currency(code: "EUR")).font(.system(size: 40, weight: .black, design: .rounded)) }
                            Text(result.paymentDetail).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(22)
                        .background((result.amountDue > 0 ? Color.orange : Color.green).opacity(0.10), in: RoundedRectangle(cornerRadius: 24))
                    }

                    Text(result.detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)

                    Button(action: onScanAgain) { Label("Scansiona altro QR", systemImage: "qrcode.viewfinder") }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Chiudi", action: onClose).buttonStyle(.bordered)
                }
                .padding(22).padding(.top, 16)
            }
        }
    }

    private func resultRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color.appCyan).frame(width: 24)
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.headline).multilineTextAlignment(.trailing)
        }
    }
}
