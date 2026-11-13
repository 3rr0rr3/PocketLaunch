import SwiftUI

/// Shared red front-face design for library cards and the launch animation.
struct GameCartridgeView: View {
    let artwork: Data?

    private let brightRed = Color(red: 0.98, green: 0.12, blue: 0.17)
    private let deepRed = Color(red: 0.68, green: 0.01, blue: 0.04)

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [brightRed, Color(red: 0.91, green: 0.025, blue: 0.075), brightRed],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(deepRed, lineWidth: 0.7))
                .overlay(RoundedRectangle(cornerRadius: 7.5).inset(by: 0.7)
                    .stroke(.white.opacity(0.23), lineWidth: 0.4))
            RoundedRectangle(cornerRadius: 0.8)
                .fill(LinearGradient(colors: [deepRed, Color(red: 0.8, green: 0.02, blue: 0.06)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 21, height: 3.5)
                .overlay(RoundedRectangle(cornerRadius: 0.8).stroke(deepRed.opacity(0.7), lineWidth: 0.35))
                .offset(x: 23.5, y: 3.2)
            label
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(deepRed, lineWidth: 0.9))
                .overlay(RoundedRectangle(cornerRadius: 3).inset(by: 0.7)
                    .stroke(.black.opacity(0.28), lineWidth: 0.35))
                .offset(x: 4.5, y: 7)
            CartridgeArrow()
                .fill(LinearGradient(colors: [deepRed, Color(red: 0.87, green: 0.02, blue: 0.07)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(CartridgeArrow().stroke(.white.opacity(0.28), lineWidth: 0.3))
                .frame(width: 12, height: 5.5).offset(x: 28, y: 85)
        }
        .frame(width: 68, height: 94, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.2), radius: 0.7, y: 0.7)
    }

    private var label: some View {
        VStack(spacing: 0) {
            CartridgeDisplayArtwork(data: artwork).frame(width: 59, height: 67.5).clipped()
            Text("LP-XXXXX-XXX-0")
                .font(.system(size: 3.5, weight: .medium, design: .monospaced))
                .tracking(0.35).foregroundStyle(.white)
                .frame(width: 59, height: 6.5).background(.black)
        }
        .frame(width: 59, height: 74)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

}

private struct CartridgeArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct LibraryCartridgeView: View {
    let artwork: Data?
    var body: some View {
        GeometryReader { geometry in
            GameCartridgeView(artwork: artwork)
                .scaleEffect(geometry.size.width / 68, anchor: .topLeading)
        }
        .aspectRatio(68.0 / 94.0, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct CartridgeDisplayArtwork: View {
    let data: Data?
    var body: some View {
        GeometryReader { geometry in
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
            } else {
                Color(white: 0.08)
            }
        }
    }
}

