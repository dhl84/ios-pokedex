import SwiftUI

struct SettingsView: View {
  @Bindable var model: DexModel
  @State private var error: String?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Identification", selection: $model.identificationMode) {
            ForEach(IdentificationMode.allCases) { mode in Text(mode.title).tag(mode) }
          }.pickerStyle(.segmented).disabled(model.busy)
          Label(model.modelStatus, systemImage: model.route == nil ? "exclamationmark.triangle" : "viewfinder")
          if model.identificationMode != .onDevice {
            KeyField(title: "Claude API key", account: .anthropic, error: $error)
            Link("Claude API console", destination: URL(string: "https://platform.claude.com/")!)
          }
        } header: { Text("Who identifies the Pokémon") } footer: {
          Text("Automatic uses Apple’s on-device model where Apple Intelligence is available, and Claude elsewhere, such as on an iPhone 12 Pro. Claude receives only the background-removed cutout. If no model can identify a Pokémon, press the pencil key to name it yourself. Keys are stored in this device’s Keychain; clear a field and save to remove it.")
        }
        Section {
          Picker("Background removal", selection: $model.removalMode) {
            ForEach(BackgroundRemovalMode.allCases) { mode in
              Text(mode.title).tag(mode)
            }
          }.pickerStyle(.segmented)
            .disabled(model.busy)
        } header: { Text("Capture processing") } footer: {
          Text(model.removalMode.explanation)
        }
        if model.removalMode == .photoroom {
          Section {
            KeyField(title: "Photoroom API key", account: .photoroom, error: $error)
            Link("Photoroom API dashboard", destination: URL(string: "https://app.photoroom.com/api-dashboard")!)
          } header: { Text("Photoroom & AI Shadows") } footer: {
            Text("Each capture sends your selected photo to Photoroom for background removal and a soft AI shadow. This uses the Image Editing API (Plus plan) and its credits.")
          }
        }
        Section {
          Toggle("Read new discoveries aloud", isOn: $model.narrator.automaticallyNarrates)
          Toggle("Electronic voice effect", isOn: $model.narrator.electronicEffect)
          Picker("US-English voice", selection: $model.narrator.voiceIdentifier) {
            Text("Automatic").tag("")
            ForEach(model.narrator.availableVoices, id: \.identifier) { voice in
              Text(voice.name).tag(voice.identifier)
            }
          }
          Button(model.narrator.isSpeaking ? "Stop narration" : "Preview voice",
                 systemImage: model.narrator.isSpeaking ? "stop.fill" : "speaker.wave.2.fill") {
            if model.narrator.isSpeaking { model.narrator.stop() }
            else { model.narrator.preview() }
          }
        } header: { Text("Pokédex voice") } footer: {
          Text("A US-English system voice with a radio-style filter and subtle electronic doubling. Tap the yellow speaker button to replay an entry.")
        }
        Section("About") {
          LabeledContent("Pocket Dex", value: "1.1")
          Text("An independent fan project. Pokémon and Pokémon character names are trademarks of Nintendo, Creatures, and GAME FREAK. Pokédex entries and sprites come from the Generation III games via PokeAPI.")
            .font(.footnote).foregroundStyle(.secondary)
        }
      }
      .navigationTitle("Settings")
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark") { dismiss() } } }
      .alert("Couldn’t save key", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
        Button("OK", role: .cancel) { error = nil }
      } message: { Text(error ?? "") }
    }.tint(.red)
  }
}

private struct KeyField: View {
  var title: String
  var account: KeychainStore.Account
  @Binding var error: String?
  @State private var key = ""
  @State private var saved = false

  var body: some View {
    SecureField(title, text: $key)
      .textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled()
      .onAppear { key = KeychainStore.read(account) }
      .onChange(of: key) { saved = false }
    Button(saved ? "Key saved" : "Save key", systemImage: "checkmark") {
      do {
        try KeychainStore.save(key.trimmingCharacters(in: .whitespacesAndNewlines), account: account)
        saved = true
      } catch { self.error = error.localizedDescription }
    }
  }
}
