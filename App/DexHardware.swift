import SwiftUI

enum DexTheme {
  static let red = Color(red: 0.66, green: 0.025, blue: 0.105)
  static let lime = Color(red: 0.65, green: 0.82, blue: 0.32)
  static let ink = Color(red: 0.055, green: 0.12, blue: 0.13)
  static let shell = LinearGradient(colors: [Color(red: 0.90, green: 0.065, blue: 0.16), red, Color(red: 0.48, green: 0.018, blue: 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct ReplicaSensor: View {
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Circle().fill(Color(white: 0.87).gradient).frame(width: 73, height: 73)
        .overlay {
          Circle().fill(RadialGradient(colors: [Color(red: 0.65, green: 0.96, blue: 1), .cyan, Color(red: 0.015, green: 0.37, blue: 0.61)], center: .topLeading, startRadius: 0, endRadius: 66))
            .padding(6)
            .overlay(Circle().stroke(.black.opacity(0.3), lineWidth: 2).padding(6))
            .overlay(alignment: .topLeading) { Ellipse().fill(.white.opacity(0.7)).frame(width: 20, height: 11).rotationEffect(.degrees(-40)).offset(x: 17, y: 15) }
        }
        .shadow(color: .black.opacity(0.65), radius: 2, y: 3)
      HStack(spacing: 10) {
        light(Color(red: 0.58, green: 0.035, blue: 0.04))
        light(.yellow)
        light(.green)
      }.padding(.top, 8)
      Spacer()
    }.padding(.leading, 23).padding(.top, 19).padding(.bottom, 14)
      .background(alignment: .bottom) {
        SensorSeam().stroke(.black.opacity(0.45), lineWidth: 4)
          .shadow(color: .white.opacity(0.2), radius: 0, y: 2)
      }
      .accessibilityElement(children: .ignore).accessibilityLabel("Pokédex sensor lights")
  }
  private func light(_ color: Color) -> some View {
    Circle().fill(color.gradient).frame(width: 13, height: 13)
      .overlay(Circle().stroke(.black.opacity(0.75), lineWidth: 2))
      .overlay(alignment: .topLeading) { Circle().fill(.white.opacity(0.7)).frame(width: 4, height: 4).offset(x: 3, y: 3) }
  }
}

private struct SensorSeam: Shape {
  func path(in r: CGRect) -> Path {
    Path { p in
      p.move(to: CGPoint(x: 0, y: r.maxY))
      p.addLine(to: CGPoint(x: r.width * 0.36, y: r.maxY))
      p.addCurve(to: CGPoint(x: r.width * 0.70, y: r.maxY - 33), control1: CGPoint(x: r.width * 0.52, y: r.maxY), control2: CGPoint(x: r.width * 0.57, y: r.maxY - 33))
      p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 33))
    }
  }
}

struct HingeSpine: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 7)
      .fill(LinearGradient(colors: [Color(red: 0.35, green: 0.015, blue: 0.03), Color(red: 0.94, green: 0.12, blue: 0.20), DexTheme.red, Color(red: 0.31, green: 0.01, blue: 0.03)], startPoint: .leading, endPoint: .trailing))
      .overlay {
        VStack {
          band
          Spacer()
          band
        }.padding(.vertical, 24)
      }.accessibilityHidden(true)
  }
  private var band: some View {
    Rectangle().fill(.black.opacity(0.5)).frame(height: 3)
      .shadow(color: .white.opacity(0.2), radius: 0, y: 3)
  }
}
