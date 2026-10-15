import Foundation
import FoundationModels

struct DexEntry: Codable, Identifiable {
  var id = UUID()
  var name: String
  var number: Int
  var type: String
  var summary: String
  var imageName: String?
  var isSample = false
  // Optional for compatibility with discoveries saved before mode selection.
  var removalMode: BackgroundRemovalMode?
  var location: ScanLocation?
  // Set when the entry text comes from the bundled Pokédex data rather than an AI.
  var genus: String?

  static let empty = DexEntry(name: "Ready to capture", number: 0, type: "—", summary: "No Pokémon captured yet.\n\nTake a picture or choose a photo to begin your next discovery.")

  init(name: String, number: Int, type: String, summary: String, removalMode: BackgroundRemovalMode? = nil, genus: String? = nil) {
    self.name = name; self.number = number; self.type = type; self.summary = summary
    self.removalMode = removalMode; self.genus = genus
  }

  init(species: PokemonSpecies, removalMode: BackgroundRemovalMode?) {
    self.init(name: species.name, number: species.number, type: species.typeLabel, summary: species.entry, removalMode: removalMode, genus: species.genus)
  }
}

/// One identification result, whichever model produced it.
struct PokemonMatch {
  var recognized: Bool
  var name: String
  var number: Int
  var type: String
  var summary: String
}

@available(iOS 27.0, *)
@Generable
struct PokemonIdentification {
  @Guide(description: "True only if the image clearly depicts a recognizable Pokémon. Otherwise false; do not guess.")
  var recognized: Bool
  @Guide(description: "The English Pokémon species name, or Unknown.")
  var name: String
  @Guide(description: "National Pokédex number, or 0 if unknown.")
  var number: Int
  @Guide(description: "Pokémon elemental types, separated by a slash.")
  var type: String
  @Guide(description: "Two short factual sentences about this species. If unknown, explain how to take a clearer photo.")
  var summary: String
}
