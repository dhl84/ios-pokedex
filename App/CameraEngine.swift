import AVFoundation
import SwiftUI

/// The live feed behind the Pokédex display and the still capture taken from it.
final class CameraEngine: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
  static let hasCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
  let session = AVCaptureSession()
  /// AVCapture rotation for the current interface orientation; the preview view keeps it current.
  var rotation: CGFloat = 90
  private let output = AVCapturePhotoOutput()
  private let queue = DispatchQueue(label: "PocketDex.camera")
  private var configured = false
  private var pending: CheckedContinuation<UIImage?, Never>?

  func start() {
    queue.async {
      self.configureIfNeeded()
      if !self.session.isRunning { self.session.startRunning() }
    }
  }

  func stop() {
    queue.async { if self.session.isRunning { self.session.stopRunning() } }
  }

  private func configureIfNeeded() {
    guard !configured else { return }
    configured = true
    session.beginConfiguration()
    session.sessionPreset = .photo
    if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
       let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
      session.addInput(input)
    }
    if session.canAddOutput(output) { session.addOutput(output) }
    session.commitConfiguration()
  }

  func capture() async -> UIImage? {
    await withCheckedContinuation { continuation in
      queue.async {
        guard self.session.isRunning, self.pending == nil else { continuation.resume(returning: nil); return }
        self.pending = continuation
        if let connection = self.output.connection(with: .video), connection.isVideoRotationAngleSupported(self.rotation) {
          connection.videoRotationAngle = self.rotation
        }
        self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
      }
    }
  }

  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
    queue.async {
      self.pending?.resume(returning: image)
      self.pending = nil
    }
  }
}

struct CameraPreview: UIViewRepresentable {
  var engine: CameraEngine

  func makeUIView(context: Context) -> PreviewView {
    let view = PreviewView()
    view.engine = engine
    view.previewLayer.session = engine.session
    view.previewLayer.videoGravity = .resizeAspectFill
    return view
  }

  func updateUIView(_ uiView: PreviewView, context: Context) {}

  final class PreviewView: UIView {
    var engine: CameraEngine?
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    override func layoutSubviews() {
      super.layoutSubviews()
      let angle: CGFloat = switch window?.windowScene?.interfaceOrientation {
      case .landscapeRight: 0
      case .landscapeLeft: 180
      case .portraitUpsideDown: 270
      default: 90
      }
      engine?.rotation = angle
      if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(angle) {
        connection.videoRotationAngle = angle
      }
    }
  }
}
