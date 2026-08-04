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
                    VStack(spacing: 22) {
                        QRPassCard(guest: guest, event: event, prCode: prCode, prName: prName, payload: payload)
                            .frame(maxWidth: 430)

                        Text("Invia questa card al cliente. Dovrà mostrarla all’ingresso per la scansione.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)

                        Button {
                            shareCard()
                        } label: {
                            Label("Condividi card QR", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(22)
                }
            }
            .navigationTitle("QR ingresso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Chiudi") { dismiss() } } }
            .sheet(item: $shareItem) { item in
                ActivityView(items: [item.image])
            }
        }
    }

    @MainActor
    private func shareCard() {
        let card = QRPassCard(guest: guest, event: event, prCode: prCode, prName: prName, payload: payload)
            .frame(width: 1080, height: 1350)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 1
        if let image = renderer.uiImage { shareItem = ImageShareItem(image: image) }
    }
}

struct QRPassCard: View {
    let guest: Guest
    let event: PREvent
    let prCode: String
    let prName: String
    let payload: String

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.02, green: 0.08, blue: 0.13), Color(red: 0.01, green: 0.22, blue: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Color.appCyan.opacity(0.20)).frame(width: 430, height: 430).blur(radius: 40).offset(x: 270, y: -420)
            Circle().fill(Color.blue.opacity(0.16)).frame(width: 360, height: 360).blur(radius: 45).offset(x: -300, y: 430)

            VStack(spacing: 30) {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: "qrcode.viewfinder").font(.system(size: 38, weight: .bold))
                        Text("GUESTLY PR").font(.system(size: 34, weight: .black, design: .rounded))
                    }
                    Text("PASS INGRESSO").font(.system(size: 19, weight: .bold)).tracking(4).foregroundStyle(.white.opacity(0.68))
                }

                VStack(spacing: 8) {
                    Text(guest.fullName).font(.system(size: 44, weight: .black, design: .rounded)).multilineTextAlignment(.center)
                    Text(event.name).font(.system(size: 28, weight: .bold))
                    Text(event.venue).font(.system(size: 21, weight: .medium)).foregroundStyle(.white.opacity(0.72))
                    Text(event.date.formatted(date: .long, time: .shortened)).font(.system(size: 19, weight: .semibold)).foregroundStyle(.white.opacity(0.72))
                }

                QRCodeImage(text: payload)
                    .frame(width: 430, height: 430)
                    .padding(28)
                    .background(.white, in: RoundedRectangle(cornerRadius: 38, style: .continuous))

                HStack(spacing: 18) {
                    passInfo(title: "PACCHETTO", value: guest.packageName)
                    Divider().overlay(.white.opacity(0.25)).frame(height: 72)
                    passInfo(title: "PREZZO", value: guest.price <= 0 ? "OMAGGIO" : guest.price.formatted(.currency(code: "EUR")))
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PR").font(.system(size: 15, weight: .bold)).foregroundStyle(.white.opacity(0.58))
                        Text(prName).font(.system(size: 21, weight: .bold))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("CODICE PR").font(.system(size: 15, weight: .bold)).foregroundStyle(.white.opacity(0.58))
                        Text(prCode).font(.system(size: 24, weight: .black, design: .monospaced))
                    }
                }
                .padding(.horizontal, 8)

                Text("Mostra questa card all’ingresso. Il QR è personale e utilizzabile una sola volta.")
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(.white.opacity(0.72)).multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding(54)
        }
        .clipShape(RoundedRectangle(cornerRadius: 52, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 52, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 2))
    }

    private func passInfo(title: String, value: String) -> some View {
        VStack(spacing: 7) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(.white.opacity(0.58))
            Text(value).font(.system(size: 21, weight: .bold)).multilineTextAlignment(.center).lineLimit(2)
        }.frame(maxWidth: .infinity)
    }
}

struct ImageShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
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
    filter.correctionLevel = "Q"
    let context = CIContext(options: [.useSoftwareRenderer: false])
    guard let output = filter.outputImage else { return nil }
    let scaled = output.transformed(by: CGAffineTransform(scaleX: 14, y: 14))
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
    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController(); controller.onCode = onCode; return controller
    }
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() { super.viewDidLoad(); view.backgroundColor = .black; configureCamera() }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated); hasScanned = false
        if !session.isRunning { DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() } }
    }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); if session.isRunning { session.stopRunning() } }

    private func configureCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }
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
