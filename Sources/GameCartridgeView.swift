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
            header
            CartridgeDisplayArtwork(data: artwork).frame(width: 59, height: 50.5).clipped()
            Text("LP-XXXXX-XXX-0")
                .font(.system(size: 3.5, weight: .medium, design: .monospaced))
                .tracking(0.35).foregroundStyle(.white)
                .frame(width: 59, height: 6.5).background(.black)
        }
        .frame(width: 59, height: 74)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private var header: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.89, green: 0, blue: 0.04),
                                    Color(red: 0.77, green: 0, blue: 0.035)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            CartridgeSwitchMark().frame(width: 19, height: 13).offset(x: 20, y: 1.6)
            Image(systemName: "key.fill")
                .font(.system(size: 6, weight: .medium)).foregroundStyle(.white)
                .rotationEffect(.degrees(-40))
                .frame(width: 8, height: 8).offset(x: 47, y: 3)
        }
        .frame(width: 59, height: 17)
    }
}

private struct CartridgeSwitchMark: View {
    var body: some View {
        VStack(spacing: 0.3) {
            HStack(alignment: .center, spacing: 1.2) {
                ZStack(alignment: .topLeading) {
                    CartridgeJoycon(right: false).stroke(.white, lineWidth: 0.7)
                        .frame(width: 3.7, height: 7.3)
                    Circle().fill(.white).frame(width: 1.1, height: 1.1).offset(x: 1.4, y: 1.6)
                    CartridgeJoycon(right: true).fill(.white)
                        .frame(width: 3.7, height: 7.3).offset(x: 5.1)
                    Circle().fill(Color(red: 0.83, green: 0, blue: 0.04))
                        .frame(width: 1.2, height: 1.2).offset(x: 6.35, y: 4.2)
                }.frame(width: 8.8, height: 7.6)
                Text("2").font(.system(size: 10.2, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }.frame(height: 8.4)
            Text("NINTENDO").font(.system(size: 2.05, weight: .semibold))
                .tracking(0.55).foregroundStyle(.white)
            Text("SWITCH").font(.system(size: 3.5, weight: .bold))
                .tracking(0.2).foregroundStyle(.white)
        }.frame(width: 19, height: 13)
    }
}

private struct CartridgeJoycon: Shape {
    let right: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = rect.width * 0.65
        if right {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + radius), control: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
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

