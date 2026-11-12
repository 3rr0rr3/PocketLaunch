import SwiftUI

/// A compact, wrapping shelf with one selected game and one launch action.
struct CartridgeShelfView<Menu: View>: View {
    let games: [Game]
    let onPlay: (Game) -> Void
    private let menu: (Game) -> Menu
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedID: UUID?

    init(games: [Game], onPlay: @escaping (Game) -> Void,
         @ViewBuilder menu: @escaping (Game) -> Menu) {
        self.games = games
        self.onPlay = onPlay
        self.menu = menu
    }

    private var selectedGame: Game? {
        games.first(where: { $0.id == selectedID }) ?? games.first
    }

    private var slots: [ShelfSlot] {
        guard let selectedGame, let index = games.firstIndex(where: { $0.id == selectedGame.id }) else { return [] }
        var result: [ShelfSlot] = []
        if games.count > 2 {
            result.append(ShelfSlot(game: games[(index + games.count - 1) % games.count], position: -1))
        }
        result.append(ShelfSlot(game: selectedGame, position: 0))
        if games.count > 1 {
            result.append(ShelfSlot(game: games[(index + 1) % games.count], position: 1))
        }
        return result
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if games.isEmpty {
                    ContentUnavailableView("Your games, together", systemImage: "gamecontroller.fill",
                                           description: Text("Add a game or change your search."))
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: max(24, min(100, geometry.size.height * 0.15)))
                        shelf(width: geometry.size.width)
                        Capsule().fill(.mint).frame(width: 22, height: 4).padding(.top, 12)
                        selectedDetails.padding(.top, 22).padding(.horizontal, 24)
                        Color.clear.frame(height: 32)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onChange(of: games.map(\.id), initial: true) { _, ids in
            if let selectedID, ids.contains(selectedID) { return }
            selectedID = ids.first
        }
    }

    private func shelf(width: CGFloat) -> some View {
        let cardWidth = min(112, max(86, width * 0.285))
        return ZStack {
            ForEach(slots) { slot in
                shelfCard(slot, width: cardWidth)
            }
        }
        .frame(width: width, height: 190)
        .contentShape(Rectangle())
        .clipped()
        .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { gesture in
            guard abs(gesture.translation.width) > abs(gesture.translation.height) else { return }
            if gesture.translation.width < -30 { moveSelection(by: 1) }
            if gesture.translation.width > 30 { moveSelection(by: -1) }
        })
        .accessibilityAction(named: "Next game") { moveSelection(by: 1) }
        .accessibilityAction(named: "Previous game") { moveSelection(by: -1) }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.88), value: selectedGame?.id)
    }

    private func shelfCard(_ slot: ShelfSlot, width: CGFloat) -> some View {
        Button { selectedID = slot.game.id } label: {
            ShelfCartridgeFace(game: slot.game, width: width)
        }
        .buttonStyle(.plain)
        .scaleEffect(slot.position == 0 ? 1 : 0.76)
        .opacity(slot.position == 0 ? 1 : 0.82)
        .offset(x: CGFloat(slot.position) * (width + 16))
        .zIndex(slot.position == 0 ? 2 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(slot.game.name)
        .accessibilityValue(slot.position == 0 ? "Selected" : "")
        .accessibilityHint("Select this game, then use Insert")
        .contextMenu { menu(slot.game) }
    }

    @ViewBuilder private var selectedDetails: some View {
        if let game = selectedGame {
            VStack(spacing: 16) {
                Text(game.name)
                    .font(ArcadeTypography.font(14, relativeTo: .title3))
                    .lineSpacing(8)
                    .padding(.vertical, 4)
                    .multilineTextAlignment(.center)
                    .lineLimit(3, reservesSpace: false)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: 320, minHeight: 56)
                if game.artwork == nil {
                    Text("Artwork unavailable").font(.caption).foregroundStyle(.secondary)
                }
                Button("Insert", systemImage: "play.fill") { onPlay(game) }
                    .font(ArcadeTypography.font(14))
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .tint(.mint).foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func moveSelection(by step: Int) {
        guard !games.isEmpty else { return }
        let current = games.firstIndex(where: { $0.id == selectedGame?.id }) ?? 0
        selectedID = games[(current + step + games.count) % games.count].id
    }
}

private struct ShelfSlot: Identifiable {
    let game: Game
    let position: Int
    var id: UUID { game.id }
}

private struct ShelfCartridgeFace: View {
    let game: Game
    let width: CGFloat
    var body: some View {
        ZStack(alignment: .topLeading) {
            GameCartridgeView(artwork: game.artwork)
            if game.artwork == nil {
                Text(game.name).font(.system(size: 6, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
                    .padding(.horizontal, 3)
                    .frame(width: 59, height: 50.5)
                    .offset(x: 4.5, y: 24)
            }
        }
        .frame(width: 68, height: 94)
        .scaleEffect(width / 68)
        .frame(width: width, height: width * 94 / 68)
        .accessibilityHidden(true)
    }
}
