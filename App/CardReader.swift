import Vision
import Foundation

/// Reads the species name printed on a trading card with on-device text recognition.
/// Needs no AI model and no key, so it runs first on every scan.
enum CardReader {
  static func species(in data: Data) -> PokemonSpecies? {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    request.recognitionLanguages = ["en-US", "ja-JP", "ko-KR"]
    request.automaticallyDetectsLanguage = true
    guard (try? VNImageRequestHandler(data: data, orientation: .up).perform([request])) != nil else { return nil }
    // The card title is the largest species name on the card, so taller text wins
    // over an "Evolves from …" line or an attack description.
    var best: (species: PokemonSpecies, height: CGFloat)?
    for observation in request.results ?? [] {
      guard let line = observation.topCandidates(1).first?.string,
            let species = match(line: line),
            observation.boundingBox.height > (best?.height ?? 0) else { continue }
      best = (species, observation.boundingBox.height)
    }
    return best?.species
  }

  /// Latin names must match whole words ("Mew" is not "Mewtwo"); Japanese and Korean
  /// titles carry no spaces, so those names match as substrings. Longest name wins.
  static func match(line: String) -> PokemonSpecies? {
    let folded = fold(line)
    let words = folded.split(whereSeparator: { !$0.isLetter }).map(String.init)
    var candidates: [PokemonSpecies] = []
    var keys = words
    for index in words.indices.dropLast() { keys.append(words[index] + words[index + 1]) }  // "Mr. Mime", "Ho-Oh", "Farfetch'd"
    candidates += keys.compactMap { latinNames[$0] }
    let letters = Array(folded.filter(\.isLetter))
    for (key, species) in cjkNames where nearlyContains(letters, Array(key)) { candidates.append(species) }
    return candidates.max { fold($0.name).count < fold($1.name).count }
  }

  /// Glossy cards make text recognition swap one kana (デカグース read as デカダース),
  /// so a name of four or more characters may differ from the printed text by one.
  private static func nearlyContains(_ text: [Character], _ name: [Character]) -> Bool {
    guard name.count <= text.count else { return false }
    let allowed = name.count >= 4 ? 1 : 0
    for start in 0...(text.count - name.count) {
      var mismatches = 0
      for offset in 0..<name.count where text[start + offset] != name[offset] {
        mismatches += 1
        if mismatches > allowed { break }
      }
      if mismatches <= allowed { return true }
    }
    return false
  }

  private static func fold(_ text: String) -> String {
    text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
  }

  private static let latinNames: [String: PokemonSpecies] = {
    var table: [String: PokemonSpecies] = [:]
    for species in PokemonSpecies.all {
      let key = fold(species.name).filter(\.isLetter)
      if table[key] == nil { table[key] = species }  // Nidoran♀ before Nidoran♂
    }
    return table
  }()

  private static let cjkNames: [String: PokemonSpecies] = {
    var table: [String: PokemonSpecies] = [:]
    for (index, names) in PokemonSpecies.localizedNames.enumerated() {
      for name in [names.0, names.1] where name.count >= 2 {
        let key = fold(name).filter(\.isLetter)
        if table[key] == nil { table[key] = PokemonSpecies.all[index] }
      }
    }
    return table
  }()
}
