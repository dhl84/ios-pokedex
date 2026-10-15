import SwiftUI
import AVFoundation
import FoundationModels

enum IdentificationMode: String, CaseIterable, Identifiable {
  case automatic, onDevice, claude
  var id: String { rawValue }
  var title: String {
    switch self {
    case .automatic: "Automatic"
    case .onDevice: "On this device"
    case .claude: "Claude"
    }
  }
}

@MainActor @Observable
final class DexModel {
  enum Route { case onDevice, claude }

  var narrator = DexNarrator()
  var entry = DexEntry.empty
  var originalPhoto: UIImage?
  var cutout: UIImage?
  var subjectBounds = CGRect(x: 0, y: 0, width: 1, height: 1)
  var history: [DexEntry] = []
  var phase = "Ready to explore"
  var busy = false
  var error: String?
  var task: Task<Void, Never>?
  var removalMode: BackgroundRemovalMode {
    didSet { UserDefaults.standard.set(removalMode.rawValue, forKey: "backgroundRemovalMode") }
  }
  var identificationMode: IdentificationMode {
    didSet { UserDefaults.standard.set(identificationMode.rawValue, forKey: "identificationMode") }
  }
  /// The display shows the live camera until a scan starts; the camera key re-arms it.
  var liveCamera = true
  var cameraAuthorized: Bool?
  @ObservationIgnored let camera = CameraEngine()
  /// The cutout and location of the most recent scan, kept so the trainer can name it by hand.
  private var lastCutoutData: Data?
  private var lastLocation: ScanLocation?
  private let service = ScanService()
  private let localRemoval = LocalBackgroundRemoval()

  init() {
    let storedMode = UserDefaults.standard.string(forKey: "backgroundRemovalMode")
    removalMode = storedMode.flatMap(BackgroundRemovalMode.init(rawValue:))
      ?? (KeychainStore.read().isEmpty ? .onDevice : .photoroom)
    identificationMode = UserDefaults.standard.string(forKey: "identificationMode").flatMap(IdentificationMode.init(rawValue:)) ?? .automatic
    if let data = UserDefaults.standard.data(forKey: "entries"),
       let entries = try? JSONDecoder().decode([DexEntry].self, from: data) { history = entries }
  }

  var capturedSpecies: Set<Int> {
    Set(history.filter { !$0.isSample && (1...386).contains($0.number) }.map(\.number))
  }

  var latestScans: [Int: DexEntry] {
    history.filter { !$0.isSample }.reduce(into: [:]) { result, entry in
      if result[entry.number] == nil { result[entry.number] = entry }
    }
  }

  var canAssign: Bool { lastCutoutData != nil && !busy }

  var onDeviceAvailable: Bool {
    guard #available(iOS 27.0, *) else { return false }
    return SystemLanguageModel.default.availability == .available
  }

  var hasClaudeKey: Bool { !KeychainStore.read(.anthropic).isEmpty }

  var route: Route? {
    switch identificationMode {
    case .onDevice: onDeviceAvailable ? .onDevice : nil
    case .claude: hasClaudeKey ? .claude : nil
    case .automatic: onDeviceAvailable ? .onDevice : hasClaudeKey ? .claude : nil
    }
  }

  var modelStatus: String {
    switch route {
    case .onDevice: return "Apple’s on-device model is ready."
    case .claude: return "Claude will identify Pokémon over the internet."
    case nil: break
    }
    switch identificationMode {
    case .claude: return "Add a Claude API key below to identify Pokémon."
    case .onDevice, .automatic:
      guard #available(iOS 27.0, *) else { return "On-device identification needs iOS 27. Add a Claude API key instead." }
      switch SystemLanguageModel.default.availability {
      case .unavailable(.appleIntelligenceNotEnabled): return "Turn on Apple Intelligence in system Settings, or add a Claude API key."
      case .unavailable(.modelNotReady): return "Apple’s on-device model is still downloading. Try again later, or add a Claude API key."
      default: return "This device has no Apple Intelligence. Add a Claude API key, or name each Pokémon by hand with the pencil key."
      }
    }
  }

  func scan(_ image: UIImage) {
    guard !busy else { return }
    let mode = removalMode
    let key = mode == .photoroom ? KeychainStore.read() : ""
    guard mode != .photoroom || !key.isEmpty else { error = "Add your Photoroom API key in Settings before capturing a Pokémon."; return }
    let route = route
    narrator.stop()
    liveCamera = false
    originalPhoto = image
    cutout = nil
    lastCutoutData = nil
    lastLocation = nil
    entry = DexEntry(name: "Capturing…", number: 0, type: "Unknown", summary: "Isolating your Pokémon. Identification will begin as soon as its background is removed.")
    entry.removalMode = mode
    busy = true
    phase = "Capturing…"
    task = Task {
      defer { busy = false; task = nil }
      let locationCapture = ScanLocationCapture()
      async let scanLocation = locationCapture.capture()
      do {
        let scale = min(1, 1600 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let normalized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = normalized.jpegData(compressionQuality: 0.9) else { throw DexError.message("Couldn’t prepare this picture.") }
        // A printed card name is read locally while the background is removed.
        async let printedName = Task.detached(priority: .userInitiated) { CardReader.species(in: data) }.value
        let result: Data
        switch mode {
        case .onDevice:
          result = try await localRemoval.process(data)
        case .photoroom:
          result = try await service.prepareCutout(image: data, key: key)
        }
        try Task.checkCancellation()
        // Publish the cutout before awaiting identification so the reveal and inference overlap.
        let preparedImage = UIImage(data: result)
        subjectBounds = CutoutFraming.visibleBounds(of: preparedImage)
        cutout = preparedImage
        lastCutoutData = result
        entry.name = "Identifying…"
        entry.summary = "Background removed. Reading the card and identifying the Pokémon while it settles into the display."
        phase = "Reading the card…"
        let found: DexEntry
        if let species = await printedName {
          found = DexEntry(species: species, removalMode: mode)
        } else {
          guard let route else { throw DexError.message("No Pokémon name was printed on this picture. " + modelStatus) }
          phase = route == .onDevice ? "Identifying on this device…" : "Asking Claude…"
          let match: PokemonMatch
          switch route {
          case .onDevice:
            guard #available(iOS 27.0, *) else { throw DexError.message(modelStatus) }
            match = try await service.identifyOnDevice(result)
          case .claude:
            match = try await service.identifyWithClaude(result, key: KeychainStore.read(.anthropic))
          }
          guard match.recognized, match.number > 0 else {
            throw DexError.message("No confident match. Try one Pokémon, well lit and filling the picture, or name it yourself with the pencil key.")
          }
          found = PokemonSpecies.number(match.number).map { DexEntry(species: $0, removalMode: mode) }
            ?? DexEntry(name: match.name, number: match.number, type: match.type, summary: match.summary, removalMode: mode)
        }
        try Task.checkCancellation()
        lastLocation = await scanLocation
        try record(found)
      } catch is CancellationError {
        phase = "Capture cancelled"
        entry.name = "Capture cancelled"
      } catch {
        if !Task.isCancelled { self.error = error.localizedDescription }
        phase = "Ready to try again"
        entry.name = "Unidentified"
        entry.summary = "No identification was saved. Try a clear photo of one Pokémon, or press the pencil key to name it yourself."
      }
    }
  }

  /// Saves the most recent scan under a species the trainer chose.
  func assign(_ species: PokemonSpecies) {
    guard canAssign else { return }
    narrator.stop()
    do { try record(DexEntry(species: species, removalMode: removalMode)) }
    catch { self.error = error.localizedDescription }
  }

  private func record(_ newEntry: DexEntry) throws {
    var saved = newEntry
    if let data = lastCutoutData {
      let file = saved.id.uuidString + ".png"
      try ScanImageStore.save(data, named: file)
      saved.imageName = file
      cutout = UIImage(data: data)
    }
    saved.location = lastLocation
    let updatedHistory = [saved] + history
    UserDefaults.standard.set(try JSONEncoder().encode(updatedHistory), forKey: "entries")
    history = updatedHistory
    entry = saved
    phase = "New discovery"
    if narrator.automaticallyNarrates { narrator.narrate(saved) }
  }

  func cancel() { task?.cancel() }

  func startCamera() async {
    if cameraAuthorized == nil { cameraAuthorized = await AVCaptureDevice.requestAccess(for: .video) }
    if cameraAuthorized == true { camera.start() }
  }

  func stopCamera() { camera.stop() }

  /// The camera key: shoot when the live feed is showing, otherwise bring the live feed back.
  func snap() async {
    guard CameraEngine.hasCamera else { error = "A camera isn’t available here. Use PHOTO to capture a Pokémon from your library."; return }
    guard liveCamera, !busy else { rearm(); return }
    if cameraAuthorized == false { error = "Camera access is off. Allow it in system Settings, or choose a photo from your library."; return }
    if let image = await camera.capture() { scan(image) }
    else { error = "Couldn’t take a photo. Try again." }
  }

  func rearm() {
    guard !busy else { return }
    narrator.stop()
    entry = .empty
    originalPhoto = nil
    cutout = nil
    lastCutoutData = nil
    lastLocation = nil
    phase = "Ready to explore"
    liveCamera = true
  }

  func select(_ item: DexEntry) {
    narrator.stop()
    liveCamera = false
    originalPhoto = nil
    lastCutoutData = nil
    lastLocation = nil
    entry = item
    cutout = item.imageName.flatMap { ScanImageStore.image(named: $0) }
    subjectBounds = CutoutFraming.visibleBounds(of: cutout)
    phase = "Saved discovery"
  }
}
