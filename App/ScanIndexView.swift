import SwiftUI
import CoreLocation

/// Every scan in order, newest first, with when and where it happened. Swipe to delete.
struct ScanIndexView: View {
  var model: DexModel
  @Environment(\.dismiss) private var dismiss
  @State private var mapEntry: DexEntry?
  @State private var pendingDelete: DexEntry?

  var body: some View {
    NavigationStack {
      Group {
        if model.history.isEmpty {
          ContentUnavailableView("No scans yet", systemImage: "list.bullet.rectangle", description: Text("Each Pokémon you capture is listed here with the time and place."))
        } else {
          List {
            ForEach(model.history) { entry in
              ScanRow(entry: entry, showMap: { mapEntry = entry })
                .contentShape(Rectangle())
                .onTapGesture { model.select(entry); dismiss() }
                .swipeActions {
                  Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = entry }
                }
            }
          }
        }
      }
      .navigationTitle("Scan Index")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) { Text("\(model.history.count) scans").font(.headline) }
        ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark") { dismiss() } }
      }
      .sheet(item: $mapEntry) { ScanLocationView(entry: $0) }
      .confirmationDialog("Delete this scan?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible, presenting: pendingDelete) { entry in
        Button("Delete \(entry.name)", role: .destructive) { model.delete(entry); pendingDelete = nil }
        Button("Cancel", role: .cancel) { pendingDelete = nil }
      } message: { _ in Text("The picture and its place are removed from this device.") }
    }.tint(.red)
  }
}

private struct ScanRow: View {
  var entry: DexEntry
  var showMap: () -> Void
  @State private var thumbnail: UIImage?
  @State private var place: String?

  var body: some View {
    HStack(spacing: 14) {
      Group {
        if let thumbnail { Image(uiImage: thumbnail).resizable().scaledToFit() }
        else { Image(systemName: "photo").foregroundStyle(.secondary) }
      }
      .frame(width: 56, height: 56)
      .background(Color(red: 0.82, green: 0.88, blue: 0.77), in: RoundedRectangle(cornerRadius: 10))
      VStack(alignment: .leading, spacing: 4) {
        Text(entry.number > 0 ? String(format: "No. %03d  %@", entry.number, entry.name) : entry.name)
          .font(.body.monospaced().weight(.semibold))
        if let when = entry.when {
          Label(when.formatted(date: .abbreviated, time: .shortened), systemImage: "clock").font(.caption).foregroundStyle(.secondary)
        }
        if let location = entry.location {
          Button { showMap() } label: {
            Label(place ?? location.coordinate.formattedCoordinate, systemImage: "mappin.and.ellipse").font(.caption).lineLimit(1)
          }.buttonStyle(.borderless).tint(.blue)
        } else {
          Label("No location", systemImage: "mappin.slash").font(.caption).foregroundStyle(.tertiary)
        }
      }
    }
    .task(id: entry.imageName) {
      guard let name = entry.imageName else { return }
      thumbnail = await ScanImageStore.thumbnail(named: name)
    }
    .task(id: entry.id) {
      guard let location = entry.location else { return }
      // ponytail: CLGeocoder is deprecated on iOS 26 but still answers; move to MKReverseGeocodingRequest when it stops.
      let marks = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: location.latitude, longitude: location.longitude))
      place = marks?.first.map { [$0.name, $0.locality].compactMap { $0 }.joined(separator: ", ") }
    }
    .accessibilityElement(children: .combine)
  }
}

private extension CLLocationCoordinate2D {
  var formattedCoordinate: String {
    "\(latitude.formatted(.number.precision(.fractionLength(4)))), \(longitude.formatted(.number.precision(.fractionLength(4))))"
  }
}
