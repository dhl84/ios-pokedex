import SwiftUI
import PhotosUI

struct ContentView: View {
  @State private var model = DexModel()
  @State private var settings = false
  @State private var journal = false
  @State private var picker = false
  @State private var photo: PhotosPickerItem?
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.horizontalSizeClass) private var sizeClass

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        if sizeClass == .regular && geometry.size.width > 580 {
          // iPad, and the larger iPhones in landscape: both halves open side by side.
          HStack(spacing: 0) {
            mainPanel
            HingeSpine().frame(width: 22).padding(.vertical, 10)
            rightPanel
          }
          .padding(.horizontal, 8)
          // Keep the halves near their designed proportions on a tall iPad screen.
          .frame(maxHeight: geometry.size.width * 1.05)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          // iPhone: one half per page; swipe to turn the Pokédex over.
          TabView {
            mainPanel
            rightPanel
          }
          .tabViewStyle(.page(indexDisplayMode: .always))
          .indexViewStyle(.page(backgroundDisplayMode: .never))
          .padding(.horizontal, 4)
        }
      }
      .statusBarHidden()
      .persistentSystemOverlays(.hidden)
      .toolbarVisibility(.hidden, for: .navigationBar)
      .background(DexTheme.shell.ignoresSafeArea())
      .sheet(isPresented: $settings) { SettingsView(model: model) }
      .sheet(isPresented: $journal) { JournalView(model: model) }
      .sheet(isPresented: $picker) { SpeciesPickerView { model.assign($0) } }
      .alert("Capture needs attention", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
        if model.canAssign {
          Button("Name it myself") { model.error = nil; picker = true }
        }
        Button("OK", role: .cancel) { model.error = nil }
      } message: { Text(model.error ?? "") }
      .task(id: photo) {
        guard let photo else { return }
        do {
          guard let data = try await photo.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw DexError.message("Couldn’t open this photo. Please select another image.") }
          model.scan(image)
        } catch { model.error = error.localizedDescription }
        self.photo = nil
      }
      .alert("Narration unavailable", isPresented: Binding(get: { model.narrator.error != nil }, set: { if !$0 { model.narrator.error = nil } })) {
        Button("OK", role: .cancel) { model.narrator.error = nil }
      } message: { Text(model.narrator.error ?? "") }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active {
          if model.liveCamera { Task { await model.startCamera() } }
        } else {
          model.narrator.stop()
          model.stopCamera()
        }
      }
      .sensoryFeedback(.success, trigger: model.history.count)
    }
    .tint(.white)
    .preferredColorScheme(.dark)
  }

  private var mainPanel: some View {
    HardwareFit {
      LeftHardwarePanel(model: model, photo: $photo, camera: { Task { await model.snap() } }, journal: { journal = true })
    }
  }

  private var rightPanel: some View {
    HardwareFit {
      RightHardwarePanel(model: model, settings: { settings = true }, journal: { journal = true }, pick: { picker = true })
    }
  }

}
