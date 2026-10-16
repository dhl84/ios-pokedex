import Foundation

struct PokemonSpecies: Identifiable {
  var number: Int
  var name: String
  var genus: String
  var types: [String]
  var entry: String
  var generation: Int
  /// Decimetres and hectograms, as the games store them.
  var height: Int
  var weight: Int
  var id: Int { number }
  var typeLabel: String { types.joined(separator: "/") }
  var sizeLabel: String {
    "Height \((Double(height) / 10).formatted(.number.precision(.fractionLength(1)))) m · Weight \((Double(weight) / 10).formatted(.number.precision(.fractionLength(1)))) kg"
  }

  /// Every species in National Pokédex order, from the bundled PokeAPI data.
  static let all: [PokemonSpecies] = data.enumerated().map { index, row in
    PokemonSpecies(number: index + 1, name: row.0, genus: row.1, types: row.3.isEmpty ? [row.2] : [row.2, row.3],
                   entry: row.4, generation: row.5, height: row.6, weight: row.7)
  }

  /// The entries the journal tracks and the picker lists: all of them.
  static let catalog: [PokemonSpecies] = all

  static let regions = ["Kanto", "Johto", "Hoenn", "Sinnoh", "Unova", "Kalos", "Alola", "Galar", "Paldea"]
  static let numerals = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"]

  static func number(_ number: Int) -> PokemonSpecies? {
    (1...all.count).contains(number) ? all[number - 1] : nil
  }
}
