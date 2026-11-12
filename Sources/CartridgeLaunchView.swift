import SwiftUI

/// Uses the selected game's current artwork. Removing this view cancels its launch task.
struct CartridgeLaunchView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let game: Game
    let cancel: () -> Void
    let finish: () -> Void
    @State private var aligned = false
    @State private var inserted = false
    @State private var illuminated = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 22) {
                    Spacer(minLength: 12)
                    scene
                        .scaleEffect(min(1, max(0.65, (geometry.size.height - 150) / 440)))
                        .frame(height: min(440, max(286, geometry.size.height - 150)))
                        .accessibilityHidden(true)
                    VStack(spacing: 8) {
                        Text(game.name).font(.title3.weight(.semibold)).multilineTextAlignment(.center)
                        Text(illuminated ? "Launching…" : "Inserting cartridge…")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    Spacer(minLength: 12)
                    Button("Cancel", action: cancel)
                        .buttonStyle(.bordered).tint(.mint)
                        .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityAddTraits(.isModal)
        .task {
            do {
                if reduceMotion {
                    illuminated = true
                    inserted = true
                    try await Task.sleep(for: .milliseconds(250))
                } else {
                    try await Task.sleep(for: .milliseconds(160))
                    withAnimation(.easeInOut(duration: 0.38)) { aligned = true }
                    try await Task.sleep(for: .milliseconds(440))
                    withAnimation(.timingCurve(0.55, 0.02, 0.35, 1, duration: 0.72)) {
                        inserted = true
                    }
                    try await Task.sleep(for: .milliseconds(760))
                    withAnimation(.easeOut(duration: 0.25)) { illuminated = true }
                    try await Task.sleep(for: .milliseconds(360))
                }
                try Task.checkCancellation()
                finish()
            } catch {
                // Navigation, cancellation, or leaving the app must never trigger a delayed launch.
            }
        }
    }

    private var scene: some View {
        ZStack(alignment: .top) {
            Ellipse()
                .fill(Color.mint.opacity(illuminated ? 0.22 : 0.07))
                .frame(width: 260, height: 310).blur(radius: 30).offset(y: 100)

            // The lane clips the cartridge at the phone's slot, making it disappear inside.
            ZStack(alignment: .top) {
                cartridge
                    .rotation3DEffect(.degrees(-12), axis: (x: 0, y: 1, z: 0))
                    .rotationEffect(.degrees(aligned ? 0 : 9))
                    .offset(y: inserted ? 180 : (aligned ? 26 : 14))
            }
            .frame(width: 280, height: 166, alignment: .top).clipped()
            .rotationEffect(.degrees(-5), anchor: .bottom)

            phone
                .rotation3DEffect(.degrees(-12), axis: (x: 0, y: 1, z: 0))
                .rotation3DEffect(.degrees(8), axis: (x: 1, y: 0, z: 0))
                .rotationEffect(.degrees(-5))
                .offset(y: 164)
        }
        .frame(width: 280, height: 440)
    }

    private var cartridge: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "gamecontroller.fill")
                Text("GAME CARD").tracking(1)
            }
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(.white).frame(height: 19).frame(maxWidth: .infinity)
            .background(Color.red)
            GameArtwork(data: game.artwork).frame(width: 64, height: 63).clipped()
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(red: 0.77, green: 0.64, blue: 0.34))
                        .frame(width: 4, height: 8)
                }
            }.padding(.top, 4)
        }
        .padding(5)
        .background(
            LinearGradient(colors: [.gray, Color(white: 0.16), Color(white: 0.1)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 8, y: 7)
    }

    private var phone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 31)
                .fill(LinearGradient(colors: [.gray, Color(white: 0.2), Color(white: 0.6)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 28).fill(.black).padding(4)
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [Color.mint.opacity(illuminated ? 0.25 : 0.08), .black],
                                     startPoint: .top, endPoint: .bottom))
                .padding(8)
            VStack(spacing: 13) {
                Capsule().fill(.black).frame(width: 48, height: 13).padding(.top, 13)
                Spacer(minLength: 0)
                if illuminated {
                    GameArtwork(data: game.artwork)
                        .frame(width: 85, height: 108).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                } else {
                    Image(systemName: "gamecontroller.fill").font(.system(size: 32)).foregroundStyle(.mint)
                }
                Text(illuminated ? game.name : "PocketLaunch")
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.center).lineLimit(2).padding(.horizontal, 12)
                Spacer(minLength: 0)
                Capsule().fill(.white.opacity(0.75)).frame(width: 44, height: 3).padding(.bottom, 12)
            }
        }
        .frame(width: 154, height: 258)
        .overlay(alignment: .top) {
            Capsule().fill(.black).frame(width: 68, height: 4).offset(y: -2)
        }
        .shadow(color: .black.opacity(0.4), radius: 16, y: 14)
    }
}
