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

    private var payload: String {
        let value = GuestQRPayload(version: 2, eventID: event.id, guestID: guest.id, token: guest.effectiveQRToken, prCode: prCode)
        guard let data = try? JSONEncoder().encode(value) else { return "" }
        return "LISTUPPR|2|" + data.base64EncodedString()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 22) {
                    Text(guest.fullName).font(.title2.bold())
                    Text(event.name).foregroundStyle(.secondary)
                    QRCodeImage(text: payload)
                        .frame(width: 270, height: 270)
                        .padding(18)
                        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    Text("Mostra questo codice all’addetto all’ingresso")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    ShareLink(item: payload) {
                        Label("Condividi codice", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }.padding(24)
            }
            .navigationTitle("QR ingresso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Chiudi") { dismiss() } } }
        }
    }
}

struct QRCodeImage: View {
    let text: String

    var body: some View {
        if let image = makeImage() {
            Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
        } else {
            Image(systemName: "qrcode").resizable().scaledToFit().foregroundStyle(.black)
        }
    }

    private func makeImage() -> UIImage? {
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
}

struct QRScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCode: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                CameraQRScanner(onCode: { code in
                    onCode(code)
                    dismiss()
                })
                VStack {
                    Spacer()
                    Text("Inquadra il QR del cliente")
                        .font(.headline).padding(.horizontal, 20).padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Scanner ingresso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Chiudi") { dismiss() } } }
        }
    }
}

struct CameraQRScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onCode = onCode
        return controller
    }
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureCamera()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning { DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() } }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    private func configureCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned, let code = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        hasScanned = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        onCode?(code)
    }
}
