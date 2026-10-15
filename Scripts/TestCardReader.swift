// Runs the card reader on macOS against sample photos: swiftc -parse-as-library App/PokemonSpecies.swift App/PokemonData.swift App/PokemonNames.swift App/CardReader.swift Scripts/TestCardReader.swift -o /tmp/cardreader && /tmp/cardreader photo.jpg ...
import Foundation

@main
struct TestCardReader {
  static func main() {
    for path in CommandLine.arguments.dropFirst() {
      guard let data = FileManager.default.contents(atPath: path) else { print("\(path): unreadable"); continue }
      let start = Date()
      let species = CardReader.species(in: data)
      print("\(URL(fileURLWithPath: path).lastPathComponent): \(species.map { "No. \($0.number) \($0.name)" } ?? "no name found") (\(String(format: "%.1f", Date().timeIntervalSince(start))) s)")
    }
  }
}
