import SwiftUI

/// Decorative only: one bundled wallpaper; live cards and controls stay above it.
struct GamingPatternBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Image("GamingPattern")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
