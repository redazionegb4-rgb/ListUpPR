import SwiftUI
import CoreImage.CIFilterBuiltins
import AVFoundation
import AudioToolbox

struct GuestQRPayload: Codable {
    let version: Int
    let eventID: UUID
    let guestID: UUID
    let token: UUID
    let prCode: String
}

struct GuestQRCodeView: View {
    @Environment(\.dismiss) private var dismiss
    let guest: Guest
    let event: PREvent
    let prCode: String
    let prName: String
    @State private var shareItem: ImageShareItem?

    private var payload: String {
        let value = GuestQRPayload(version: 2, eventID: event.id, guestID: guest.id, token: guest.effectiveQRToken, prCode: prCode)
        guard let data = try? JSONEncoder().encode(value) else { return "" }
        return "LISTUPPR|2|" + data.base64EncodedString()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        QRPassCard(guest: guest, event: event, prCode: prCode, prName: prName, payload: payload)
                            .aspectRatio(0.61, contentMode: .fit)
                            .frame(maxWidth: 430)
                            .padding(.horizontal, 18)

                        Text("Questo è il biglietto digitale completo da inviare al cliente.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button { shareCard() } label: {
                            Label("Condividi biglietto", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(.vertical, 18)
                }
            }
            .navigationTitle("Biglietto ingresso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Chiudi") { dismiss() } } }
            .sheet(item: $shareItem) { item in ActivityView(items: [item.image]) }
        }
    }

    @MainActor
    private func shareCard() {
        let card = QRPassCard(guest: guest, event: event, prCode: prCode, prName: prName, payload: payload)
            .frame(width: 828, height: 1357)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        renderer.isOpaque = true
        if let image = renderer.uiImage { shareItem = ImageShareItem(image: image) }
    }
}

struct QRPassCard: View {
    let guest: Guest
    let event: PREvent
    let prCode: String
    let prName: String
    let payload: String

    private let ink = Color(red: 0.025, green: 0.09, blue: 0.15)
    private let blue = Color(red: 0.02, green: 0.48, blue: 0.92)
    private let aqua = Color(red: 0.00, green: 0.78, blue: 0.72)

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let s = w / 828
            ZStack {
                RoundedRectangle(cornerRadius: 48 * s, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ink, Color(red: 0.02, green: 0.18, blue: 0.29), Color(red: 0.00, green: 0.35, blue: 0.43)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(blue.opacity(0.28))
                    .frame(width: 420 * s, height: 420 * s)
                    .blur(radius: 70 * s)
                    .offset(x: 260 * s, y: -500 * s)

                Circle()
                    .fill(aqua.opacity(0.22))
                    .frame(width: 380 * s, height: 380 * s)
                    .blur(radius: 70 * s)
                    .offset(x: -260 * s, y: 520 * s)

                VStack(spacing: 0) {
                    passHeader(s)
                    passDetails(s)
                    perforation(s)
                    qrArea(s)
                    passFooter(s)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 48 * s, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 48 * s, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: max(1, 2 * s))
            }
            .shadow(color: .black.opacity(0.35), radius: 28 * s, y: 16 * s)
        }
    }

    private func passHeader(_ s: CGFloat) -> some View {
        HStack(spacing: 18 * s) {
            ZStack {
                RoundedRectangle(cornerRadius: 18 * s, style: .continuous)
                    .fill(LinearGradient(colors: [blue, aqua], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 34 * s, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(width: 74 * s, height: 74 * s)

            VStack(alignment: .leading, spacing: 5 * s) {
                Text("LISTUP PR")
                    .font(.system(size: 31 * s, weight: .black, design: .rounded))
                Text("PASS DIGITALE D’INGRESSO")
                    .font(.system(size: 11 * s, weight: .bold))
                    .tracking(2.6 * s)
                    .foregroundStyle(.white.opacity(0.68))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5 * s) {
                Text("DATA")
                    .font(.system(size: 11 * s, weight: .bold))
                    .foregroundStyle(.white.opacity(0.62))
                Text(italianTicketDate(event.date))
                    .font(.system(size: 24 * s, weight: .bold, design: .rounded))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 42 * s)
        .padding(.top, 42 * s)
        .padding(.bottom, 28 * s)
    }

    private func passDetails(_ s: CGFloat) -> some View {
        VStack(spacing: 24 * s) {
            HStack(alignment: .top, spacing: 26 * s) {
                passField("CLIENTE", guest.fullName, .leading, s)
                passField("ORARIO", italianTicketTime(event.date), .trailing, s)
            }
            HStack(alignment: .top, spacing: 26 * s) {
                passField("EVENTO", event.name, .leading, s)
                passField("LOCALE", event.venue, .trailing, s)
            }
            HStack(alignment: .top, spacing: 26 * s) {
                passField("PACCHETTO", guest.packageName, .leading, s)
                passField("PREZZO", guest.price <= 0 ? "OMAGGIO" : guest.price.formatted(.currency(code: "EUR")), .trailing, s)
            }
        }
        .padding(.horizontal, 42 * s)
        .padding(.vertical, 34 * s)
        .background(.white.opacity(0.06))
        .foregroundStyle(.white)
    }

    private func perforation(_ s: CGFloat) -> some View {
        ZStack {
            HStack(spacing: 10 * s) {
                ForEach(0..<34, id: \.self) { _ in
                    Capsule().fill(.white.opacity(0.34)).frame(width: 11 * s, height: 3 * s)
                }
            }
            .clipped()
            HStack {
                Circle().fill(Color.black.opacity(0.92)).frame(width: 38 * s).offset(x: -19 * s)
                Spacer()
                Circle().fill(Color.black.opacity(0.92)).frame(width: 38 * s).offset(x: 19 * s)
            }
        }
        .frame(height: 44 * s)
    }

    private func qrArea(_ s: CGFloat) -> some View {
        VStack(spacing: 18 * s) {
            Text("MOSTRA QUESTO QR ALL’INGRESSO")
                .font(.system(size: 13 * s, weight: .bold))
                .tracking(1.7 * s)
                .foregroundStyle(.white.opacity(0.72))

            QRCodeImage(text: payload)
                .frame(width: 390 * s, height: 390 * s)
                .padding(26 * s)
                .background(.white, in: RoundedRectangle(cornerRadius: 34 * s, style: .continuous))
                .shadow(color: .black.opacity(0.28), radius: 18 * s, y: 8 * s)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34 * s)
    }

    private func passFooter(_ s: CGFloat) -> some View {
        VStack(spacing: 22 * s) {
            HStack(alignment: .top, spacing: 28 * s) {
                passField("PR", prName, .leading, s)
                passField("CODICE PR", prCode, .trailing, s)
            }

            HStack(spacing: 10 * s) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                Text("Personale • valido per un solo ingresso")
                    .font(.system(size: 15 * s, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .padding(.horizontal, 42 * s)
        .padding(.bottom, 40 * s)
    }

    private func passField(_ title: String, _ value: String, _ alignment: TextAlignment, _ s: CGFloat) -> some View {
        VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: 5 * s) {
            Text(title)
                .font(.system(size: 12 * s, weight: .bold))
                .foregroundStyle(.white.opacity(0.58))
            Text(value)
                .font(.system(size: 23 * s, weight: .bold, design: .rounded))
                .multilineTextAlignment(alignment)
                .lineLimit(2)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}

func italianEventDateTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "it_IT")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "d MMMM yyyy 'alle' HH:mm"
    return formatter.string(from: date)
}

func italianTicketDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "it_IT")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "dd/MM/yyyy"
    return formatter.string(from: date)
}

func italianTicketTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "it_IT")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}

struct ImageShareItem: Identifiable { let id = UUID(); let image: UIImage }

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct QRCodeImage: View {
    let text: String
    var body: some View {
        if let image = makeQRCodeImage(text: text) {
            Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
        } else {
            Image(systemName: "qrcode").resizable().scaledToFit().foregroundStyle(.black)
        }
    }
}

func makeQRCodeImage(text: String) -> UIImage? {
    guard !text.isEmpty else { return nil }
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(text.utf8)
    filter.correctionLevel = "M"
    let context = CIContext(options: [.useSoftwareRenderer: false])
    guard let output = filter.outputImage else { return nil }
    let scaled = output.transformed(by: CGAffineTransform(scaleX: 16, y: 16))
    guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
    return UIImage(cgImage: cgImage)
}

struct QRScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCode: (String) -> Void
    var body: some View {
        NavigationStack {
            ZStack {
                CameraQRScanner(onCode: { code in onCode(code); dismiss() })
                VStack {
                    Spacer()
                    Text("Inquadra il QR del cliente").font(.headline).padding(.horizontal, 20).padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule()).padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Scanner ingresso").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Chiudi") { dismiss() } } }
        }
    }
}

struct CameraQRScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    func makeUIViewController(context: Context) -> ScannerViewController { let c = ScannerViewController(); c.onCode = onCode; return c }
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() { super.viewDidLoad(); view.backgroundColor = .black; configureCamera() }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); hasScanned = false; if !session.isRunning { DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() } } }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); if session.isRunning { session.stopRunning() } }

    private func configureCamera() {
        guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput(); guard session.canAddOutput(output) else { return }
        session.addOutput(output); output.setMetadataObjectsDelegate(self, queue: .main); output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session); layer.videoGravity = .resizeAspectFill; layer.frame = view.bounds
        view.layer.addSublayer(layer); previewLayer = layer
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); previewLayer?.frame = view.bounds }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned, let code = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        hasScanned = true; AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate)); onCode?(code)
    }
}
