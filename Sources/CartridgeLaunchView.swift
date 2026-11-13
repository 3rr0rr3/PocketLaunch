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
    @State private var screenFlash: Double = 0
    @State private var loadingProgress: CGFloat = 0
    private let screenArtwork: UIImage?

    init(game: Game, cancel: @escaping () -> Void, finish: @escaping () -> Void) {
        self.game = game
        self.cancel = cancel
        self.finish = finish
        self.screenArtwork = game.artwork.flatMap { UIImage(data: $0) }
    }

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
            let clock = ContinuousClock()
            let launchDeadline = clock.now.advanced(by: .seconds(3))
            if reduceMotion {
                cardY = 163
                cardAngle = 0
                illuminated = true
                loadingProgress = 1
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
                // The screen wakes after insertion; its camera cutout stays above this layer.
                withAnimation(.easeOut(duration: 0.14)) { screenFlash = 0.27 }
                try await Task.sleep(for: .milliseconds(140))
                withAnimation(.easeOut(duration: 0.28)) {
                    screenFlash = 0
                    illuminated = true
                }
                withAnimation(.linear(duration: 0.65)) { loadingProgress = 1 }
                try await clock.sleep(until: launchDeadline)
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
        GameCartridgeView(artwork: game.artwork)
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
            VStack(spacing: 14) {
                if let image = screenArtwork {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 104, height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Text(game.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(maxWidth: 130)
                ZStack(alignment: .leading) {
                    Capsule().fill(.mint.opacity(0.2))
                    Capsule().fill(.mint)
                        .frame(width: 24 * loadingProgress)
                }
                .frame(width: 24, height: 2)
                .clipShape(Capsule())
            }
            .opacity(illuminated ? 1 : 0)
            Color(red: 0.74, green: 0.92, blue: 1)
                .opacity(screenFlash)
                .allowsHitTesting(false)
        }
        .frame(width: 158, height: 334).clipped()
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}

