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
                            .frame(maxWidth: 420)
                            .aspectRatio(0.68, contentMode: .fit)

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
            .frame(width: 1080, height: 1600)
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

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / 1080, geo.size.height / 1600)
            ZStack {
                LinearGradient(colors: [Color(red: 0.015, green: 0.06, blue: 0.11), Color(red: 0.00, green: 0.24, blue: 0.28)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(Color.appCyan.opacity(0.22)).frame(width: 520, height: 520).blur(radius: 55).offset(x: 330, y: -520)
                Circle().fill(Color.blue.opacity(0.16)).frame(width: 450, height: 450).blur(radius: 60).offset(x: -360, y: 540)

                VStack(spacing: 34) {
                    VStack(spacing: 10) {
                        HStack(spacing: 13) {
                            Image(systemName: "qrcode.viewfinder").font(.system(size: 40, weight: .bold))
                            Text("LISTUP PR").font(.system(size: 38, weight: .black, design: .rounded))
                        }
                        Text("PASS INGRESSO").font(.system(size: 18, weight: .bold)).tracking(5).foregroundStyle(.white.opacity(0.68))
                    }

                    VStack(spacing: 10) {
                        Text(guest.fullName).font(.system(size: 48, weight: .black, design: .rounded)).multilineTextAlignment(.center).lineLimit(2)
                        Text(event.name).font(.system(size: 30, weight: .bold)).multilineTextAlignment(.center)
                        Text(event.venue).font(.system(size: 22, weight: .medium)).foregroundStyle(.white.opacity(0.76))
                        Text(event.date.formatted(date: .long, time: .shortened)).font(.system(size: 21, weight: .semibold)).foregroundStyle(.white.opacity(0.76))
                    }

                    QRCodeImage(text: payload)
                        .frame(width: 470, height: 470)
                        .padding(26)
                        .background(.white, in: RoundedRectangle(cornerRadius: 40, style: .continuous))

                    HStack(spacing: 18) {
                        passInfo(title: "PACCHETTO", value: guest.packageName)
                        Rectangle().fill(.white.opacity(0.23)).frame(width: 1, height: 82)
                        passInfo(title: "PREZZO", value: guest.price <= 0 ? "OMAGGIO" : guest.price.formatted(.currency(code: "EUR")))
                    }

                    HStack(alignment: .top) {
                        passInfo(title: "PR", value: prName, alignment: .leading)
                        Spacer()
                        passInfo(title: "CODICE PR", value: prCode, alignment: .trailing)
                    }

                    Text("Mostra questa card all’ingresso. Il QR è personale e utilizzabile una sola volta.")
                        .font(.system(size: 18, weight: .medium)).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
                }
                .foregroundStyle(.white)
                .padding(64)
                .frame(width: 1080, height: 1600)
                .scaleEffect(scale)
            }
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: compact ? 34 : 0, style: .continuous))
    }

    private func passInfo(title: String, value: String, alignment: TextAlignment = .center) -> some View {
        VStack(alignment: alignment == .leading ? .leading : alignment == .trailing ? .trailing : .center, spacing: 8) {
            Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(.white.opacity(0.58))
            Text(value).font(.system(size: 23, weight: .bold)).multilineTextAlignment(alignment).lineLimit(2).minimumScaleFactor(0.75)
        }.frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : alignment == .trailing ? .trailing : .center)
    }
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
