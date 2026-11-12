import SwiftUI
import UIKit
import CoreText

enum ArcadeTypography {
    static let name = "PressStart2P-Regular"

    static func register() {
        guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
            assertionFailure("Missing bundled arcade font")
            return
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        assert(UIFont(name: name, size: 12) != nil, "Arcade font failed to register")

    }

    static func font(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(name, size: size, relativeTo: style)
    }
}
