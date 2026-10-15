import Foundation

struct PokemonSpecies: Identifiable {
  var number: Int
  var name: String
  var genus: String
  var types: [String]
  var entry: String
  var id: Int { number }
  var generation: Int { number <= 151 ? 1 : number <= 251 ? 2 : 3 }
  var typeLabel: String { types.joined(separator: "/") }

  /// Every species in National Pokédex order, from the bundled PokeAPI data.
  static let all: [PokemonSpecies] = data.enumerated().map { index, row in
    PokemonSpecies(number: index + 1, name: row.0, genus: row.1, types: row.3.isEmpty ? [row.2] : [row.2, row.3], entry: row.4)
  }

  /// Generations I–III: the 386 entries the journal tracks and that have bundled sprites.
  static let catalog: [PokemonSpecies] = Array(all.prefix(386))

  static func number(_ number: Int) -> PokemonSpecies? {
    (1...all.count).contains(number) ? all[number - 1] : nil
  }
}
