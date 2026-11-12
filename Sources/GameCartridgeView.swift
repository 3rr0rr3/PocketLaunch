import SwiftUI

/// The same fixed-proportion game card is used on the shelf and in the launch animation.
struct GameCartridgeView: View {
    let artwork: Data?
    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(white: 0.42), Color(white: 0.16), Color(white: 0.09), Color(white: 0.3)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            RoundedRectangle(cornerRadius: 1).fill(.black.opacity(0.8))
                .frame(width: 44, height: 2).offset(x: 6, y: 4)
            CartridgeDisplayArtwork(data: artwork)
                .frame(width: 54, height: 61)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(.black.opacity(0.6), lineWidth: 1))
                .offset(x: 6, y: 11)
            LinearGradient(colors: [.white.opacity(0.1), .clear, .white.opacity(0.03)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: 54, height: 61).offset(x: 6, y: 11)
            HStack(spacing: 3) {
                ForEach(0..<8, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.42, green: 0.33, blue: 0.15),
                                     Color(red: 0.9, green: 0.81, blue: 0.57),
                                     Color(red: 0.5, green: 0.43, blue: 0.25)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: 4, height: 10)
                }
            }.frame(width: 53, height: 10).offset(x: 7.5, y: 79)
        }
        .frame(width: 68, height: 94, alignment: .topLeading)
        .clipShape(LaunchCartridgeOutline())
        .overlay(LaunchCartridgeOutline().stroke(.white.opacity(0.26), lineWidth: 1))
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

private struct LaunchCartridgeOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 4, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.84, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 4))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 4, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + 4, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - 4), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 4))
        path.addQuadCurve(to: CGPoint(x: rect.minX + 4, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
