import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var sheet: AccessSheet?

    enum AccessSheet: Identifiable {
        case login, appleRegistration, scanner
        var id: Int { hashValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 36)
                BrandMark().padding(.bottom, 4)

                VStack(spacing: 8) {
                    Text("ListUp PR")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                    Text("La tua serata, organizzata bene.")
                        .font(.title3.weight(.medium))
                    Text("Liste, pacchetti e ingressi sincronizzati in un’unica app.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 14) {
                    Button { sheet = .login } label: {
                        Label("Accedi come PR", systemImage: "person.crop.circle.badge.checkmark")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    AccessCard(
                        icon: "apple.logo",
                        eyebrow: "NON SEI ANCORA ISCRITTO?",
                        title: "Registrati con Apple",
                        tint: .primary
                    ) {
                        sheet = .appleRegistration
                    }

                    Text("Accedi con Apple serve solo per creare un nuovo profilo PR. Se sei già registrato, usa “Accedi come PR”.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    AccessCard(
                        icon: "qrcode.viewfinder",
                        eyebrow: "INGRESSO CLIENTI",
                        title: "Scansiona QR ingresso",
                        tint: .green
                    ) {
                        sheet = .scanner
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "icloud.fill")
                    Text("Dati salvati sul dispositivo e predisposti per CloudKit")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 22)
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .login:
                PRLoginView()
            case .appleRegistration:
                ApplePRRegistrationView()
            case .scanner:
                GlobalEntranceScannerView()
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
                .font(.system(size: 45, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

struct AccessCard: View {
    let icon: String
    let eyebrow: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PremiumCard {
                HStack(spacing: 15) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(tint)
                        .frame(width: 48, height: 48)
                        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(eyebrow)
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct PRLoginView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var error = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 22) {
                        accessHero(
                            icon: "person.crop.circle.badge.checkmark",
                            title: "Bentornato",
                            subtitle: "Accedi al tuo profilo PR con username e password"
                        )

                        PremiumCard {
                            VStack(spacing: 16) {
                                ModernAccessField(icon: "at", title: "Username", placeholder: "Il tuo username", text: $username)
                                ModernSecureField(icon: "lock.fill", title: "Password", placeholder: "La tua password", text: $password)
                            }
                        }

                        if error {
                            Label("Username o password non corretti.", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.red)
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

                        Text("Se non hai ancora un profilo, chiudi questa pagina e scegli “Registrati con Apple”.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Accesso PR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}

struct ApplePRRegistrationView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss

    @State private var appleUserID = ""
    @State private var suggestedName = ""
    @State private var name = ""
    @State private var username = ""
    @State private var authError = ""
    @State private var registrationError = false

    private var normalizedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var usernameFormatValid: Bool {
        normalizedUsername.count >= 4 &&
        normalizedUsername.count <= 24 &&
        normalizedUsername.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 22) {
                        accessHero(
                            icon: "apple.logo",
                            title: "Nuovo profilo PR",
                            subtitle: "Usa Apple solo per registrarti in modo sicuro, senza password da ricordare"
                        )

                        if appleUserID.isEmpty {
                            PremiumCard {
                                VStack(spacing: 16) {
                                    Label("Solo per nuovi PR", systemImage: "person.badge.plus")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Text("Se hai già un account ListUp PR, torna indietro e scegli “Accedi come PR”.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    SignInWithAppleButton(.signUp) { request in
                                        request.requestedScopes = [.fullName, .email]
                                    } onCompletion: { result in
                                        handleAppleResult(result)
                                    }
                                    .signInWithAppleButtonStyle(.white)
                                    .frame(height: 54)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                            }
                        } else {
                            PremiumCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    Label("Identità Apple verificata", systemImage: "checkmark.seal.fill")
                                        .font(.headline)
                                        .foregroundStyle(.green)

                                    ModernAccessField(
                                        icon: "person.fill",
                                        title: "Nome PR",
                                        placeholder: "Es. Demetrio o Team White",
                                        text: $name
                                    )
                                    ModernAccessField(
                                        icon: "at",
                                        title: "Username",
                                        placeholder: "Es. demetrio.pr",
                                        text: $username
                                    )
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Label("Username da 4 a 24 caratteri", systemImage: usernameFormatValid ? "checkmark.circle.fill" : "circle")
                                Label("Usa lettere, numeri, punto o trattino basso", systemImage: usernameFormatValid ? "checkmark.circle.fill" : "circle")
                                Label("Non dovrai creare o ricordare una password", systemImage: "checkmark.circle.fill")
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if registrationError {
                                Label("Username già utilizzato oppure profilo Apple già registrato.", systemImage: "exclamationmark.triangle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button {
                                guard model.registerPRWithApple(
                                    name: name,
                                    username: normalizedUsername,
                                    appleUserID: appleUserID
                                ) else {
                                    registrationError = true
                                    return
                                }
                                dismiss()
                            } label: {
                                Label("Crea profilo PR", systemImage: "checkmark.circle.fill")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !usernameFormatValid)
                        }

                        if !authError.isEmpty {
                            Label(authError, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Registrazione con Apple")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        authError = ""
        registrationError = false

        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authError = "Impossibile verificare l’identità Apple."
                return
            }
            appleUserID = credential.user

            if let components = credential.fullName {
                let formatter = PersonNameComponentsFormatter()
                suggestedName = formatter.string(from: components)
                if name.isEmpty { name = suggestedName }
            }

        case .failure(let error):
            let nsError = error as NSError
            if nsError.code != ASAuthorizationError.canceled.rawValue {
                authError = "Registrazione con Apple non riuscita. Riprova."
            }
        }
    }
}

@ViewBuilder
private func accessHero(icon: String, title: String, subtitle: String) -> some View {
    VStack(spacing: 14) {
        ZStack {
            Circle()
                .fill(Color.appCyan.opacity(0.15))
                .frame(width: 86, height: 86)
            Image(systemName: icon)
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(Color.appCyan)
        }
        Text(title)
            .font(.system(size: 31, weight: .black, design: .rounded))
        Text(subtitle)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}

struct ModernAccessField: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

struct ModernSecureField: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            SecureField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .padding(14)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

