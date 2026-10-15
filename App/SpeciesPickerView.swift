import SwiftUI

/// Lets the trainer name the Pokémon when no model could, or got it wrong.
struct SpeciesPickerView: View {
  var select: (PokemonSpecies) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var query = ""

  var body: some View {
    let search = query.trimmingCharacters(in: .whitespaces)
    let matches = PokemonSpecies.catalog.filter {
      search.isEmpty || $0.name.localizedStandardContains(search) || String(format: "%03d", $0.number).contains(search)
    }
    NavigationStack {
      List(matches) { species in
        Button {
          select(species)
          dismiss()
        } label: {
          HStack(spacing: 14) {
            Image("pokemon-\(species.number)").interpolation(.none).resizable().frame(width: 48, height: 48)
              .background(Color(red: 0.82, green: 0.88, blue: 0.77), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
              Text(String(format: "No. %03d  %@", species.number, species.name)).font(.body.monospaced().weight(.semibold))
              Text("\(species.genus) · \(species.typeLabel)").font(.caption).foregroundStyle(.secondary)
            }
          }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Number \(species.number), \(species.name)")
      }
      .searchable(text: $query, prompt: "Name or number")
      .navigationTitle("Which Pokémon?")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
    }.tint(.red)
  }
}
