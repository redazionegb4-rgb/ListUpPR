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
                        QRPassCard(guest: guest, event: event, prCode: prCode, prName: prName, payload: payload, compact: true)
                            .frame(width: min(UIScreen.main.bounds.width - 30, 410), height: min((UIScreen.main.bounds.width - 30) * 1.56, 640))

                        Text("Questa è l’anteprima completa della card da inviare al cliente.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)

                        Button { shareCard() } label: {
                            Label("Condividi card QR", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(18)
                }
            }
            .navigationTitle("QR ingresso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Chiudi") { dismiss() } } }
            .sheet(item: $shareItem) { item in ActivityView(items: [item.image]) }
        }
    }

    @MainActor
    private func shareCard() {
        let card = QRPassCard(guest: guest, event: event, prCode: prCode, prName: prName, payload: payload, compact: false)
            .frame(width: 900, height: 1450)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 1
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
    let compact: Bool

    private var ticketColor: Color { Color(red: 0.02, green: 0.36, blue: 0.48) }

    var body: some View {
        ZStack {
            Color(red: 0.94, green: 0.96, blue: 0.98)

            VStack(spacing: 0) {
                ticketHeader
                ticketBody
            }
            .background(ticketColor)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 28 : 48, style: .continuous))
            .overlay(ticketCutouts)
            .shadow(color: .black.opacity(0.18), radius: compact ? 12 : 28, y: compact ? 7 : 16)
            .padding(compact ? 4 : 28)
        }
    }

    private var ticketHeader: some View {
        HStack(alignment: .top, spacing: compact ? 12 : 24) {
            VStack(alignment: .leading, spacing: compact ? 3 : 7) {
                HStack(spacing: compact ? 7 : 14) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: compact ? 17 : 34, weight: .black))
                    Text("LISTUP PR")
                        .font(.system(size: compact ? 18 : 36, weight: .black, design: .rounded))
                }
                Text("BIGLIETTO D’INGRESSO")
                    .font(.system(size: compact ? 8 : 16, weight: .bold))
                    .tracking(compact ? 1.5 : 4)
                    .opacity(0.78)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: compact ? 3 : 7) {
                Text("DATA")
                    .font(.system(size: compact ? 8 : 16, weight: .bold))
                    .opacity(0.72)
                Text(italianTicketDate(event.date))
                    .font(.system(size: compact ? 15 : 30, weight: .bold, design: .rounded))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 20 : 46)
        .padding(.top, compact ? 19 : 42)
        .padding(.bottom, compact ? 15 : 30)
    }

    private var ticketBody: some View {
        VStack(spacing: compact ? 15 : 30) {
            HStack(alignment: .top, spacing: compact ? 15 : 32) {
                ticketField(title: "CLIENTE", value: guest.fullName, alignment: .leading)
                ticketField(title: "ORARIO", value: italianTicketTime(event.date), alignment: .trailing)
            }

            HStack(alignment: .top, spacing: compact ? 15 : 32) {
                ticketField(title: "EVENTO", value: event.name, alignment: .leading)
                ticketField(title: "LOCALE", value: event.venue, alignment: .trailing)
            }

            HStack(alignment: .top, spacing: compact ? 15 : 32) {
                ticketField(title: "PACCHETTO", value: guest.packageName, alignment: .leading)
                ticketField(title: "PREZZO", value: guest.price <= 0 ? "OMAGGIO" : guest.price.formatted(.currency(code: "EUR")), alignment: .trailing)
            }

            perforation

            QRCodeImage(text: payload)
                .frame(width: compact ? 215 : 430, height: compact ? 215 : 430)
                .padding(compact ? 13 : 25)
                .background(.white, in: RoundedRectangle(cornerRadius: compact ? 20 : 34, style: .continuous))

            HStack(alignment: .top, spacing: compact ? 15 : 32) {
                ticketField(title: "PR", value: prName, alignment: .leading)
                ticketField(title: "CODICE PR", value: prCode, alignment: .trailing)
            }

            Text("Mostra questo biglietto all’ingresso. Il QR è personale e utilizzabile una sola volta.")
                .font(.system(size: compact ? 9 : 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.80))
                .multilineTextAlignment(.center)
                .padding(.top, compact ? 2 : 4)
        }
        .padding(.horizontal, compact ? 20 : 46)
        .padding(.bottom, compact ? 22 : 46)
        .foregroundStyle(.white)
    }

    private var perforation: some View {
        HStack(spacing: compact ? 5 : 10) {
            ForEach(0..<(compact ? 26 : 40), id: \.self) { _ in
                Capsule().fill(.white.opacity(0.52)).frame(width: compact ? 6 : 12, height: compact ? 2 : 4)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var ticketCutouts: some View {
        VStack {
            Spacer().frame(height: compact ? 214 : 418)
            HStack {
                Circle().fill(Color(red: 0.94, green: 0.96, blue: 0.98)).frame(width: compact ? 24 : 48).offset(x: compact ? -12 : -24)
                Spacer()
                Circle().fill(Color(red: 0.94, green: 0.96, blue: 0.98)).frame(width: compact ? 24 : 48).offset(x: compact ? 12 : 24)
            }
            Spacer()
        }
    }

    private func ticketField(title: String, value: String, alignment: TextAlignment) -> some View {
        VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: compact ? 3 : 7) {
            Text(title)
                .font(.system(size: compact ? 8 : 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.70))
            Text(value)
                .font(.system(size: compact ? 13 : 25, weight: .bold, design: .rounded))
                .multilineTextAlignment(alignment)
                .lineLimit(2)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}

func italianEventDateTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "it_IT")
    formatter.dateFormat = "d MMMM yyyy 'alle' HH:mm"
    return formatter.string(from: date)
}

func italianTicketDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "it_IT")
    formatter.dateFormat = "dd/MM/yy"
    return formatter.string(from: date)
}

func italianTicketTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "it_IT")
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
