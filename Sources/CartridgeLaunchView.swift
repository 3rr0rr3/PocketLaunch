import SwiftUI

/// Fixed-size objects prevent the cartridge from stretching to the width of the screen.
struct CartridgeLaunchView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let game: Game
    let cancel: () -> Void
    let finish: () -> Void
    @State private var cardY: CGFloat = 16
    @State private var cardAngle: Double = 7
    @State private var phoneOffset: CGFloat = 0
    @State private var illuminated = false

    var body: some View {
        GeometryReader { geometry in
            let scale = max(0.1, min(1.15, min((geometry.size.width - 48) / 280,
                                              (geometry.size.height - 48) / 510)))
            ZStack {
                Color.black.ignoresSafeArea()
                scene
                    .scaleEffect(scale)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .accessibilityHidden(true)
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Launching \(game.name)")
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, cancel)
        .task { await animateAndLaunch() }
    }

    @MainActor private func animateAndLaunch() async {
        do {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--preview-cartridge") {
                try await Task.sleep(for: .seconds(3))
            }
            #endif
            if reduceMotion {
                cardY = 163
                cardAngle = 0
                illuminated = true
                try await Task.sleep(for: .milliseconds(250))
            } else {
                try await Task.sleep(for: .milliseconds(100))
                withAnimation(.easeInOut(duration: 0.46)) { cardY = 11; cardAngle = 0 }
                try await Task.sleep(for: .milliseconds(460))
                withAnimation(.easeInOut(duration: 0.28)) { cardY = 22 }
                try await Task.sleep(for: .milliseconds(280))
                withAnimation(.timingCurve(0.55, 0.02, 0.35, 1, duration: 0.97)) { cardY = 147 }
                try await Task.sleep(for: .milliseconds(970))
                withAnimation(.easeOut(duration: 0.14)) { cardY = 144; phoneOffset = 2 }
                try await Task.sleep(for: .milliseconds(140))
                withAnimation(.easeIn(duration: 0.18)) { cardY = 163 }
                withAnimation(.easeOut(duration: 0.25)) { phoneOffset = 0 }
                try await Task.sleep(for: .milliseconds(180))
                withAnimation(.easeOut(duration: 0.28)) { illuminated = true }
                try await Task.sleep(for: .milliseconds(300))
            }
            try Task.checkCancellation()
            finish()
        } catch {
            // Removing the overlay or leaving the app cancels the pending game launch.
        }
    }

    private var scene: some View {
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                cartridge
                    .rotationEffect(.degrees(cardAngle))
                    .offset(x: 106, y: cardY)
            }
            .frame(width: 280, height: 153, alignment: .topLeading)
            .clipped()
            phone.offset(x: 53, y: 150 + phoneOffset)
        }
        .frame(width: 280, height: 510, alignment: .topLeading)
        .rotationEffect(.degrees(-6))
        .rotation3DEffect(.degrees(-10), axis: (x: 0, y: 1, z: 0))
    }

    private var cartridge: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(white: 0.42), Color(white: 0.16), Color(white: 0.09), Color(white: 0.3)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            RoundedRectangle(cornerRadius: 1).fill(.black.opacity(0.8))
                .frame(width: 44, height: 2).offset(x: 6, y: 4)
            CartridgeDisplayArtwork(data: game.artwork)
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

    private var phone: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 35)
                .fill(LinearGradient(colors: [Color(white: 0.7), Color(white: 0.16),
                                             Color(white: 0.38), Color(white: 0.61), Color(white: 0.17)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 174, height: 350)
            RoundedRectangle(cornerRadius: 32).fill(Color(white: 0.015))
                .frame(width: 168, height: 344).offset(x: 3, y: 3)
            phoneScreen.offset(x: 8, y: 8)
            Capsule().fill(.black).frame(width: 49, height: 14).offset(x: 62.5, y: 15)
            Circle().fill(Color(red: 0.04, green: 0.08, blue: 0.12))
                .frame(width: 5, height: 5).offset(x: 101, y: 19.5)
            Capsule().fill(.white.opacity(0.55)).frame(width: 48, height: 3).offset(x: 63, y: 332)
            Capsule().fill(Color(white: 0.3)).frame(width: 3, height: 35).offset(x: -2, y: 71)
            Capsule().fill(Color(white: 0.4)).frame(width: 3, height: 39).offset(x: 173, y: 89)
            Capsule().fill(.black).frame(width: 72, height: 5)
                .overlay(Capsule().stroke(Color(white: 0.4), lineWidth: 0.7))
                .offset(x: 51, y: -3)
        }
        .frame(width: 174, height: 350, alignment: .topLeading)
        .shadow(color: .black.opacity(0.55), radius: 12, x: 6, y: 10)
    }

    private var phoneScreen: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.07, green: 0.1, blue: 0.12), Color(white: 0.02)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            CartridgeDisplayArtwork(data: game.artwork)
                .scaleEffect(illuminated ? 1 : 1.06).opacity(illuminated ? 0.8 : 0)
            LinearGradient(colors: [.black.opacity(0.3), .clear, .black.opacity(0.4)],
                           startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: [.white.opacity(0.035), .clear, .white.opacity(0.012)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .frame(width: 158, height: 334).clipped()
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}

private struct CartridgeDisplayArtwork: View {
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
